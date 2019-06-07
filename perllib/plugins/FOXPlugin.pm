###########################################################################
#
# FOXPlugin.pm
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
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

# plugin to process a Foxbase dbt file. This plugin provides the basic
# functionality to read in the dbt and dbf files and process each record.
# This general plugin should be overridden for a particular database to process
# the appropriate fields in the file.

package FOXPlugin;

use BaseImporter;
use util;
use doc;
use unicode;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


sub BEGIN {
    @FOXPlugin::ISA = ('BaseImporter');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_block_exp() } ];

my $options = { 'name'     => "FOXPlugin",
		'desc'     => "{FOXPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.dbf$^;
}

#dbt files are processed at the same time as dbf files
sub get_default_block_exp {
    my $self = shift (@_);

    return q^(?i)\.dbt$^;
}

# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
 
    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

    print STDERR "<Processing n='$file' p='FOXPlugin'>\n" if ($gli);
    print STDERR "FOXPlugin: processing $file\n" if $self->{'verbosity'} > 1;

    my ($parent_dir) = $filename_full_path =~ /^(.*)\/[^\/]+\.dbf$/i;

    # open the file
    if (!open (FOXBASEIN, $filename_full_path)) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='Could not read $filename_full_path'>\n";
	}
	print STDERR "FOXPlugin::read - couldn't read $filename_full_path\n";
	return -1; # error in processing
    }

    # read in the database header
    my ($temp, %dbf);
    
    # read in information about dbt file
    if (read (FOXBASEIN, $temp, 32) < 32) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='EOF while reading database header'>\n";
	}
	print STDERR "FOXPlugin::read - eof while reading database header\n";
	close (FOXBASEIN);
	return -1;
    }
    
    # unpack the header
    ($dbf{'hasdbt'},
     $dbf{'modyear'}, $dbf{'modmonth'}, $dbf{'modday'},
     $dbf{'numrecords'}, $dbf{'headerlen'}, 
     $dbf{'recordlen'}) = unpack ("CCCCVvv", $temp);
    
    # process hasdbt
    if ($dbf{'hasdbt'} == 131) {
	$dbf{'hasdbt'} = 1;
    } elsif ($dbf{'hasdbt'} == 3 || $dbf{'hasdbt'} == 48) {
	$dbf{'hasdbt'} = 0;
    } else {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='Does not seem to be a Foxbase file'>\n";
	}
	print STDERR "FOXPlugin:read - $filename_full_path doesn't seem to be a Foxbase file\n";
	return -1;
    }

    # read in the field description
    $dbf{'numfields'} = 0;
    $dbf{'fieldinfo'} = [];
    while (read (FOXBASEIN, $temp, 1) > 0) {
	last if ($temp eq "\x0d");
	last if (read (FOXBASEIN, $temp, 31, 1) < 31);

	my %field = ();
	$field{'name'} = $self->extracttext($temp, 11);
	($field{'type'}, $field{'pos'}, $field{'len'}, $field{'dp'}) 
	    = unpack ("x11a1VCC", $temp);

	push (@{$dbf{'fieldinfo'}}, \%field);

	$dbf{'numfields'} ++;
    }

    # open the dbt file if we need to
    my $dbtfullname = $filename_full_path;
    if ($filename_full_path =~ /f$/) {
	$dbtfullname =~ s/f$/t/;
    } else {
	$dbtfullname =~ s/F$/T/;
    }
    if ($dbf{'hasdbt'} && !open (DBTIN, $dbtfullname)) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='Could not read $dbtfullname'>\n";
	}
	print STDERR "FOXPlugin::read - couldn't read $dbtfullname\n";
	close (FOXBASEIN);
	return -1;
    }

    # read in and process each record in the database
    my $numrecords = 0;
    while (($numrecords < $dbf{'numrecords'}) && 
	   (read (FOXBASEIN, $temp, $dbf{'recordlen'}) == $dbf{'recordlen'})) {

	# create a new record
	my $record = [];
	
	foreach my $field (@{$dbf{'fieldinfo'}}) {
	    my $fieldvalue = "";
	    
	    if ($field->{'type'} eq "M" && $dbf{'hasdbt'}) {
		# a memo field, look up this field in the dbt file
		my $seekpos = substr ($temp, $field->{'pos'}, $field->{'len'});

		$seekpos =~ s/^\s*//;
		$seekpos = 0 unless $seekpos =~ /^\d+$/;
		
		$seekpos = $seekpos * 512;

		if ($seekpos == 0) {
		    # there is no memo field

		} elsif (seek (DBTIN, $seekpos, 0)) {
		    while (read (DBTIN, $fieldvalue, 512, length($fieldvalue)) > 0) {
			last if ($fieldvalue =~ /\cZ/);
		    }

		    # remove everything after the control-Z
		    substr($fieldvalue, index($fieldvalue, "\cZ")) = "";

		} else {
		    print STDERR "\nERROR - seek (to $seekpos) failed\n";
		}

	    } else {
		# a normal field
		$fieldvalue = substr ($temp, $field->{'pos'}, $field->{'len'});
	    }

	    push (@$record, {%$field, 'value'=>$fieldvalue});
	}

	# process this record
	$self->process_record ($pluginfo, $base_dir, $file, $metadata, $processor, 
			       $numrecords, $record);
	
	# finished another record...
	$numrecords++;
    }

    # close the dbt file if we need to
    if ($dbf{'hasdbt'}) {
	close (DBTIN);
    }

    # close the dbf file
    close (FOXBASEIN);

    # finished processing
    return 1;
}


# will extract a string from some larger string, making it
# conform to a number of constraints
sub extracttext {
    my $self = shift (@_);
    my ($text, $maxlen, $offset, $stopstr) = @_;
    $offset = 0 unless defined $offset;
    $stopstr = "\x00" unless defined $stopstr;
    
    # decide where the string finishes
    my $end = index ($text, $stopstr, $offset);
    $end = length ($text) if $end < 0;
    $end = $offset+$maxlen if (defined $maxlen) && ($end-$offset > $maxlen);
    
    return "" if ($end <= $offset);
    return substr ($text, $offset, $end-$offset);
}


# process_record should be overriden for a particular type
# of database. This default version outputs an html document
# containing all the fields in the record as a table.
# It also assumes that the text is in utf-8.
sub process_record {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $processor, $numrecords, $record) = @_;

    # create a new document
    my $doc_obj = new doc ($file, "indexed_doc", $self->{'file_rename_method'});

    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
    my $section = $doc_obj->get_top_section();

    $doc_obj->add_metadata($section, "FileFormat", "FOX");
    $doc_obj->add_metadata($section, "FileSize",   (-s $file));

    # start of document
    $doc_obj->add_utf8_text($section, "<table>\n");

    # add each field
    foreach my $field (@$record) {
	if (defined ($field->{'name'}) && defined ($field->{'value'})) {
	    $doc_obj->add_utf8_text($section, "  <tr>\n");
	    $doc_obj->add_utf8_text($section, "    <td>$field->{'name'}</td>\n");
	    $doc_obj->add_utf8_text($section, "    <td>$field->{'value'}</td>\n");
	    $doc_obj->add_utf8_text($section, "  </tr>\n");
	}
    }

    # end of document
    $doc_obj->add_utf8_text($section, "</table>\n");

    # add an object id
    $self->add_OID($doc_obj);

    # process the document
    $processor->process($doc_obj);
}


1;
