###########################################################################
#
# DatabasePlugin.pm -- plugin to import records from a database
# 
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2003 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

# A plugin that imports records from a database. This uses perl's DBI module, 
# which includes back-ends for mysql, postgresql, comma separated values (CSV),
# MS Excel, ODBC, sybase, etc... Extra modules may need to be installed to 
# use this. See <GSDLHOME>/etc/packages/example.dbi for an example config file.
#

# Written by John McPherson for the NZDL project
# Mar, Apr 2003

package DatabasePlugin;

use strict;
no strict 'refs'; # allow variable as a filehandle

use AutoExtractMetadata;
use MetadataRead;
use unicode;

sub BEGIN {
    @DatabasePlugin::ISA = ('MetadataRead', 'AutoExtractMetadata');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" }];

my $options = { 'name'     => "DatabasePlugin",
		'desc'     => "{DatabasePlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new AutoExtractMetadata($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.dbi$^;
}

sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs,$total_count,$gli) = @_;
        
     #see if we can handle the passed file...
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);
    
    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    print STDERR "<Processing n='$file' p='DatabasePlugin'>\n" if ($gli);
    print $outhandle "DatabasePlugin: processing $file\n" 
	if $self->{'verbosity'} > 1;
   
    require DBI; # database independent stuff

    # calculate the document hash, for document ids
    my $hash="0";

   
    # default options - may be overridden by config file
    my $language=undef;
    my $encoding=undef;
    my $dbplug_debug=0;
    my $username='';
    my $password='';

    # these settings must be set by the config file:
    my $db=undef;

    # get id of pages from "nonempty", get latest version number from 
    # "recent", and then get pagename from "page" and content from "version" !

    my $sql_query_prime = undef ;
    my $sql_query = undef ;

    my %db_to_greenstone_fields=();
    my %callbacks=();


    # read in config file.
    if (!open (CONF, $filename_full_path)) {
	    print $outhandle "DatabasePlugin: can't read $filename_full_path: $!\n";
	    return 0;
    } 
   
    my $line;
    my $statement="";
    my $callback="";
    while (defined($line=<CONF>)) {
	chomp $line;
	$line .= " "; # for multi-line statements - don't conjoin!
	$line =~ s/\s*\#.*$//mg; # remove comments
	$statement .= $line;

	if ($line =~ /^\}\s*$/ && $callback) { # ends the callback
	    $callback .= $statement ; $statement = "";
	    # try to check that the function is "safe"
	    if ($callback  =~ /\b(?:system|open|pipe|readpipe|qx|kill|eval|do|use|require|exec|fork)\b/ ||
		$callback =~ /[\`]|\|\-/) {
		# no backticks or functions that start new processes allowed
		print $outhandle "DatabasePlugin: bad function in callback\n";
		return 0;
	    }
	    $callback =~ s/sub (\w+?)_callback/sub/;
	    my $fieldname = $1;
	    my $ret = eval "\$callbacks{'$fieldname'} = $callback ; 1";
	    if (!defined($ret)) {
		print $outhandle "DatabasePlugin: error eval'ing callback: $@\n";
		exit(1);
	    }
	    $callback="";
	    print $outhandle "DatabasePlugin: callback registered for '$fieldname'\n"
	        if $dbplug_debug;
	} elsif ($callback) {
	    # add this line to the callback function
	    $callback .= $statement;
	    $statement = "";
	} elsif ($statement =~ m/;\s*$/) { # ends with ";"
	    # check that it is safe
	    # assignment
	    if ($statement =~ m~(\$\w+)\s* = \s*
		(\d		# digits
		 | ".*?(?<!\\)" # " up to the next " not preceded by a \
		 | '.*?(?<!\\)' # ' up to the next ' not preceded by a \
		)\s*;~x ||      # /x means ignore comments and whitespace in rx
		$statement =~ m~(\%\w+)\s*=\s*(\([\w\s\"\',:=>]+\))\s*;~ ) {   
		# evaluate the assignment, return 1 on success "
		if (!eval "$1=$2; 1") {
		    my $err=$@;
		    chomp $err;
		    $err =~ s/\.$//; # remove a trailing .
		    print $outhandle "DatabasePlugin: error evaluating `$statement'\n";
		    print $outhandle " $err (in $filename_full_path)\n";
		    return 0; # there was an error reading the config file
		}
	    } elsif ($statement =~ /sub \w+_callback/) {
		# this is the start of a callback function definition
		$callback = $statement;
		$statement = "";
	    } else {
		print $outhandle "DatabasePlugin: skipping statement `$statement'\n";
	    }
	    $statement = "";
	}
    }
    close CONF;

    
    if (!defined($db)) {
	print $outhandle "DatabasePlugin: error: $filename_full_path does not specify a db!\n";
	return 0;
    }
    if (!defined($sql_query)) {
    	print $outhandle "DatabasePlugin: error: no SQL query specified!\n";
	return 0;
    }
    # connect to database
    my $dbhandle=DBI->connect($db, $username, $password);

    if (!defined($dbhandle)) {
	die "DatabasePlugin: could not connect to database, exiting.\n";
    }
    if (defined($dbplug_debug) && $dbplug_debug==1) {
	print $outhandle "DatabasePlugin (debug): connected ok\n";
    }

    my $statement_hand;

    # The user gave 2 sql statements to execute?
    if ($sql_query_prime) {
	    $statement_hand=$dbhandle->prepare($sql_query_prime);
	    $statement_hand->execute;
	    if ($statement_hand->err) {
		    print $outhandle "Error: " . $statement_hand->errstr . "\n";
		    return undef;
	    }
    }

  
    $statement_hand=$dbhandle->prepare($sql_query);
    $statement_hand->execute;
    if ($statement_hand->err) {
    	print $outhandle "Error:" . $statement_hand->errstr . "\n";
	return undef;
    }

    # get the array-ref for the field names and cast it to array
    my @field_names;
    @field_names=@{ $statement_hand->{NAME} };

    foreach my $fieldname (@field_names) {
	if (defined($db_to_greenstone_fields{$fieldname})) {
	    if (defined($dbplug_debug) && $dbplug_debug==1) {
		print $outhandle "DatabasePlugin (debug): mapping db field "
		    . "'$fieldname' to "
			. $db_to_greenstone_fields{$fieldname} . "\n";
	    }
	    $fieldname=$db_to_greenstone_fields{$fieldname};
	}
    }

    # get rows

    my $count = 0;
    my @row_array;

    @row_array=$statement_hand->fetchrow_array; # fetchrow_hashref?

    my $base_oid = undef;
    while (scalar(@row_array)) {
	if (defined($dbplug_debug) && $dbplug_debug==1) {
	    print $outhandle "DatabasePlugin (debug): retrieved a row from query\n";
	}

	# create a new document
	my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});

	my $cursection = $doc_obj->get_top_section();

	# if $language not set in config file, will use BaseImporter's default
	if (defined($language)) {
	    $doc_obj->add_utf8_metadata($cursection, "Language", $language);
	}
	# if $encoding not set in config file, will use BaseImporter's default
	if (defined($encoding)) {
	    # allow some common aliases
	    if ($encoding =~ m/^utf[-_]8$/i) {$encoding="utf8"}
	    $encoding =~ s/-/_/g; # greenstone uses eg iso_8859_1
	    $doc_obj->add_utf8_metadata($cursection, "Encoding", $encoding);
	}

	my $plugin_filename_encoding = $self->{'filename_encoding'};
	my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);

	if ($self->{'cover_image'}) {
	    $self->associate_cover_image($doc_obj, $filename_full_path);
	}
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");

	$doc_obj->add_metadata($doc_obj->get_top_section(), "FileFormat", "DB");

	# include any metadata passed in from previous plugins 
	# note that this metadata is associated with the top level section
	$self->extra_metadata ($doc_obj, $cursection,
			       $metadata);

	# do any automatic metadata extraction
	$self->auto_extract_metadata ($doc_obj);

	my $unique_id=undef;

	foreach my $fieldname (@field_names) {
	    my $fielddata=shift @row_array;

	    if (! defined($fielddata) ) {
	    	next; # this field was "" or NULL
	    }
	    # use the specified encoding, defaulting to utf-8
	    if (defined($encoding) && $encoding ne "ascii"
	    	&& $encoding ne "utf8") {
	      $fielddata=&unicode::unicode2utf8(
	      	&unicode::convert2unicode($encoding, \$fielddata)
					       );
	    }
	    # see if we have a ****_callback() function defined
	    if (exists $callbacks{$fieldname}) {
		my $funcptr = $callbacks{$fieldname};
		$fielddata = &$funcptr($fielddata);
	    }

	    if ($fieldname eq "text") {
		# add as document text
		$fielddata=~s@<@&lt;@g;
		$fielddata=~s@>@&gt;@g; # for xml protection...
		$fielddata=~s@_@\\_@g; # for macro language protection...
		$doc_obj->add_utf8_text($cursection, $fielddata);
	    } elsif ($fieldname eq "Identifier") {
		# use as greenstone's unique record id
		if ($fielddata =~ /^\d+$/) {
		    # don't allow IDs that are completely numeric
		    $unique_id="id" . $fielddata;
		} else {
		    $unique_id=$fielddata;
		}
	    } else {
		# add as document metadata
		$fielddata=~s/\[/&#91;/g;
		$fielddata=~s/\]/&#93;/g;
		$doc_obj->add_utf8_metadata($cursection,
					    $fieldname, $fielddata);

	    }
	}


	if (!defined $unique_id) {
	    if (!defined $base_oid) {
		$self->add_OID($doc_obj);
		$base_oid = $doc_obj->get_OID(); 
	    }
	    $doc_obj->set_OID($base_oid."s$count");
	} else {
	    # use our id from the database...
	    $doc_obj->set_OID($unique_id);
	}


        # process the document
	$processor->process($doc_obj);

	$count++;

	# get next row
	@row_array=$statement_hand->fetchrow_array; # fetchrow_hashref?
    } # end of row_array is not empty

    # check "$sth->err" if empty array for error
    if ($statement_hand->err) {
	print $outhandle "DatabasePlugin: received error: \"" .
	    $statement_hand->errstr . "\"\n";
    }

    # clean up connection to database
    $statement_hand->finish();
    $dbhandle->disconnect();

    # num of input files, rather than documents created?
    $self->{'num_processed'}++;

    if (defined($dbplug_debug) && $dbplug_debug==1) {
        print $outhandle "DatabasePlugin: imported $count DB records as documents.\n";
    }
    $count;
}

1;
