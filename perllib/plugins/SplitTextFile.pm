###########################################################################
#
# SplitTextFile.pm - a plugin for splitting input files into segments that
#                will then be individually processed.
#
#
# Copyright 2000 Gordon W. Paynter (gwp@cs.waikato.ac.nz)
# Copyright 2000 The New Zealand Digital Library Project
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
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


# SplitTextFile is a plugin for splitting input files into segments that will
# then be individually processed.  

# This plugin should not be called directly.  Instead, if you need to
# process input files that contain several documents, you should write a
# plugin with a process function that will handle one of those documents
# and have it inherit from SplitTextFile.  See ReferPlug for an example.


package SplitTextFile;

use ReadTextFile;
use gsprintf 'gsprintf';
use util;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# SplitTextFile is a sub-class of ReadTextFile
sub BEGIN {
    @SplitTextFile::ISA = ('ReadTextFile');
}


my $arguments =
    [ { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	#'deft' => &get_default_split_exp(),
	'deft' => "",
	'reqd' => "no" } ];

my $options = { 'name'     => "SplitTextFile",
		'desc'     => "{SplitTextFile.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
	        'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'textcat_store'} = {};
    $self->{'metapass_srcdoc'} = {}; # which segments have valid metadata_srcdoc
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    $self->ReadTextFile::init($verbosity, $outhandle, $failhandle);

    # why is this is init and not in new??
    if ((!defined $self->{'process_exp'}) || ($self->{'process_exp'} eq "")) {

	$self->{'process_exp'} = $self->get_default_process_exp ();
	if ($self->{'process_exp'} eq "") {
	    warn ref($self) . " Warning: plugin has no process_exp\n";
	}
    }


    # set split_exp to default unless explicitly set
    if (!$self->{'split_exp'}) {
	$self->{'split_exp'} = $self->get_default_split_exp ();
    }

}

# This plugin recurs over the segments it finds
sub is_recursive {
    return 1;
}

# By default, we split the input text at blank lines
sub get_default_split_exp {
    return q^\n\s*\n^;
}

sub metadata_read {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;
    
    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

        my $outhandle = $self->{'outhandle'};
        my $filename = &util::filename_cat($base_dir, $file);

	my $plugin_name = ref ($self);
	$file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up

	$self->{'metapass_srcdoc'}->{$file} = {};

	# Do encoding stuff
	my ($language, $encoding) = $self->textcat_get_language_encoding ($filename);
	my $le_rec = { 'language' => $language, 'encoding' => $encoding };
	$self->{'textcat_store'}->{$file} = $le_rec;

	# Read in file ($text will be in utf8)
	my $text = "";
	$self->read_file ($filename, $encoding, $language, \$text);

 
	if ($text !~ /\w/) {
	    gsprintf($outhandle, "$plugin_name: {ReadTextFile.file_has_no_text}\n",
		     $file)
		if $self->{'verbosity'};
	    
	    my $failhandle = $self->{'failhandle'};
	    print $failhandle "$file: " . ref($self) . ": file contains no text\n";
	    $self->{'num_not_processed'} ++;

	    $self->{'textcat_store'}->{$file} = undef;

	    return 0; 
	}
    
    
	# Split the text into several smaller segments
	my $split_exp = $self->{'split_exp'};
        my @tmp  = split(/$split_exp/i, $text);
	my @segments =();
	## get rid of empty segments
	foreach my $seg (@tmp){
	    if ($seg ne ""){
		push @segments, $seg;
	    }
	}

	print $outhandle "SplitTextFile found " . (scalar @segments) . " documents in $filename\n" 
	    if $self->{'verbosity'};
	
	$self->{'split_segments'}->{$file} = \@segments;
    
    return  scalar(@segments);
}



# The read function opens a file and splits it into parts. 
# Each part is sent to the process function
#
# Returns: Number of document objects created (or undef if it fails)

sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up

    my $le_rec = $self->{'textcat_store'}->{$file};
    if (!defined $le_rec) {
	# means no text was found;
	return 0; # not processed but no point in passing it on
    }

    print STDERR "<Processing n='$file' p='$self->{'plugin_type'}'>\n" if ($gli);
    print $outhandle "$self->{'plugin_type'} processing $file\n"
	    if $self->{'verbosity'} > 1;    

    my $language = $le_rec->{'language'};
    my $encoding = $le_rec->{'encoding'};
    $self->{'textcat_store'}->{$file} = undef;

    my $segments = $self->{'split_segments'}->{$file};
    $self->{'split_segments'}->{$file} = undef;

    # Process each segment in turn
    my ($count, $segment, $segtext, $status, $id);
    $segment = 0;
    $count = 0;
    foreach $segtext (@$segments) {
     	$segment++;

	if (defined $self->{'metapass_srcdoc'}->{$file}->{$segment}) {
	    # metadata is attached to a srcdoc
	    next;
	}

	# create a new document
	my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Language", $language);
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Encoding", $encoding);

	my ($filemeta) = $file =~ /([^\\\/]+)$/;
	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);

	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "SourceSegment", "$segment");
	if ($self->{'cover_image'}) {
	    $self->associate_cover_image($doc_obj, $filename_full_path);
	}
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
	#$doc_obj->add_metadata($doc_obj->get_top_section(), "FileFormat", "Split");

	# Calculate a "base" document ID.
	if (!defined $id) {
	    $id = $self->get_base_OID($doc_obj);
	}
    
	# include any metadata passed in from previous plugins 
	# note that this metadata is associated with the top level section
	$self->extra_metadata ($doc_obj, $doc_obj->get_top_section(), $metadata);

	# do plugin specific processing of doc_obj
	print $outhandle "segment $segment\n" if ($self->{'verbosity'});
	print STDERR "<Processing s='$segment' n='$file' p='$self->{'plugin_type'}'>\n" if ($gli);
	$status = $self->process (\$segtext, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli);
	if (!defined $status) {
	    print $outhandle "WARNING: no plugin could process segment $segment of $file\n" 
		if ($verbosity >= 2);
	    print STDERR "<ProcessingError s='$segment' n='$file'>\n" if $gli;
	    next;
	}
	# If the plugin returned 0, it threw away this part
	if ($status == 0) {
	    next;
	}
	$count += $status;

	# do any automatic metadata extraction
	$self->auto_extract_metadata ($doc_obj);

	# add an OID
	$self->add_OID($doc_obj, $id, $segment);

	# process the document
	$processor->process($doc_obj);

	$self->{'num_processed'} ++;
    }

    delete $self->{'metapass_srcdoc'}->{$file};

    # Return number of document objects produced
    return $count; 
}

sub get_base_OID {
    my $self = shift(@_);
    my ($doc_obj) = @_;

    $self->SUPER::add_OID($doc_obj);
    return $doc_obj->get_OID();
}

sub add_OID {
    my $self = shift (@_);
    my ($doc_obj, $id, $segment) = @_;

    my $full_id = $id . "s" . $segment;
    if ($self->{'OIDtype'} eq "assigned") {
	my $identifier = $doc_obj->get_metadata_element ($doc_obj->get_top_section(), $self->{'OIDmetadata'});
	if (defined $identifier && $identifier ne "") {
	    $full_id = $identifier;
	    $full_id = &util::tidy_up_oid($full_id);
	}
    }
    $doc_obj->set_OID($full_id);
}


1;
