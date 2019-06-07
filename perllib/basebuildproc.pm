##########################################################################
#
# basebuildproc.pm -- 
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

# This document processor outputs a document for indexing (should be 
# implemented by subclass) and storing in the database

package basebuildproc;

eval {require bytes};

use classify;
use dbutil;
use doc;
use docproc;
use strict; 
no strict 'subs';
no strict 'refs';
use util;
use FileUtils;

BEGIN {
    @basebuildproc::ISA = ('docproc');
}

sub new()
  {
    my ($class, $collection, $source_dir, $build_dir, $keepold, $verbosity, $outhandle) = @_;
    my $self = new docproc ();

    # outhandle is where all the debugging info goes
    # output_handle is where the output of the plugins is piped
    # to (i.e. mg, database etc.)
    $outhandle = STDERR unless defined $outhandle;

    $self->{'collection'} = $collection;
    $self->{'source_dir'} = $source_dir;
    $self->{'build_dir'}  = $build_dir;
    $self->{'keepold'}    = $keepold;
    $self->{'verbosity'}  = $verbosity;
    $self->{'outhandle'}  = $outhandle;

    $self->{'classifiers'} = [];
    $self->{'mode'} = "text";
    $self->{'assocdir'} = $build_dir;
    $self->{'dontdb'} = {};
    $self->{'store_metadata_coverage'} = "false";

    $self->{'index'} = "section:text";
    $self->{'indexexparr'} = [];

    $self->{'separate_cjk'} = 0;

    my $found_num_data = 0;
    my $buildconfigfile = undef;

    if ($keepold) {
	# For incremental building need to seed num_docs etc from values
	# stored in build.cfg (if present)
	$buildconfigfile = &FileUtils::filenameConcatenate($build_dir, "build.cfg");
	if (-e $buildconfigfile) {
	    $found_num_data = 1;
	}
	else {
	    # try the index dir
	    $buildconfigfile = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 
						   "index", "build.cfg");
	    if (-e $buildconfigfile) {
		$found_num_data = 1;
	    }
	}

    }

    if ($found_num_data)
      {
        #print STDERR "Found_Num_Data!\n";
	my $buildcfg = &colcfg::read_build_cfg($buildconfigfile);
	$self->{'starting_num_docs'}     = $buildcfg->{'numdocs'};
        #print STDERR "- num_docs:     $self->{'starting_num_docs'}\n";
	$self->{'starting_num_sections'} = $buildcfg->{'numsections'};
        #print STDERR "- num_sections: $self->{'starting_num_sections'}\n";
	$self->{'starting_num_bytes'}    = $buildcfg->{'numbytes'};
        #print STDERR "- num_bytes:    $self->{'starting_num_bytes'}\n";
    }
    else
      {
        #print STDERR "NOT Found_Num_Data!\n";
        $self->{'starting_num_docs'}     = 0;
	$self->{'starting_num_sections'} = 0;
	$self->{'starting_num_bytes'}    = 0;
      }

    $self->{'output_handle'} = "STDOUT";
    $self->{'num_docs'}      = $self->{'starting_num_docs'};
    $self->{'num_sections'}  = $self->{'starting_num_sections'};
    $self->{'num_bytes'}     = $self->{'starting_num_bytes'};

    $self->{'num_processed_bytes'} = 0;
    $self->{'store_text'} = 1;

    # what level (section/document) the database - indexer intersection is
    $self->{'db_level'} = "section";
    #used by browse interface
    $self->{'doclist'} = [];

    $self->{'indexing_text'} = 0;

    return bless $self, $class;

}

sub reset {
    my $self = shift (@_);

    $self->{'num_docs'}      = $self->{'starting_num_docs'};
    $self->{'num_sections'}  = $self->{'starting_num_sections'};
    $self->{'num_bytes'}     = $self->{'starting_num_bytes'};
    
    $self->{'num_processed_bytes'} = 0;
}

sub zero_reset {
    my $self = shift (@_);

    $self->{'num_docs'}      = 0;
    $self->{'num_sections'}  = 0;
    # reconstructed docs have no text, just metadata, so we need to 
    # remember how many bytes we had initially
    #$self->{'num_bytes'}     = $self->{'starting_num_bytes'};
    $self->{'num_bytes'} = 0; # we'll store num bytes in db for reconstructed docs.
    $self->{'num_processed_bytes'} = 0;
}

sub is_incremental_capable
{
    # By default we return 'no' as the answer
    # Safer to assume non-incremental to start with, and then override in
    # inherited classes that are.

    return 0;
}

sub get_num_docs {
    my $self = shift (@_);

    return $self->{'num_docs'};
}

sub get_num_sections {
    my $self = shift (@_);

    return $self->{'num_sections'};
}

# num_bytes is the actual number of bytes in the collection
# this is normally the same as what's processed during text compression
sub get_num_bytes {
    my $self = shift (@_);

    return $self->{'num_bytes'};
}

# num_processed_bytes is the number of bytes actually passed
# to mg for the current index
sub get_num_processed_bytes {
    my $self = shift (@_);

    return $self->{'num_processed_bytes'};
}

sub set_output_handle {
    my $self = shift (@_);
    my ($handle) = @_;

    $self->{'output_handle'} = $handle;
    # The output handle isn't always an actual handle. In a couple of the
    # database drivers (MSSQL and GDBMServer) it's actually a reference
    # to an object. Thus we need to test the type before setting binmode.
    # [jmt12]
    if (ref $handle eq "GLOB")
    {
      binmode($handle,":utf8");
    }
}


sub set_mode {
    my $self = shift (@_);
    my ($mode) = @_;

    $self->{'mode'} = $mode;
}

sub get_mode {
    my $self = shift (@_);

    return $self->{'mode'};
}

sub set_assocdir {
    my $self = shift (@_);
    my ($assocdir) = @_;

    $self->{'assocdir'} = $assocdir;
}

sub set_dontdb {
    my $self = shift (@_);
    my ($dontdb) = @_;

    $self->{'dontdb'} = $dontdb;
}

sub set_infodbtype
{
    my $self = shift(@_);
    my $infodbtype = shift(@_);
    $self->{'infodbtype'} = $infodbtype;
}

sub set_index {
    my $self = shift (@_);
    my ($index, $indexexparr) = @_;

    $self->{'index'} = $index;
    $self->{'indexexparr'} = $indexexparr if defined $indexexparr;
}

sub set_index_languages {
    my $self = shift (@_);
    my ($lang_meta, $langarr) = @_;
    $lang_meta =~ s/^ex\.([^.]+)$/$1/; # strip any ex. namespace iff it's the only namespace prefix (will leave ex.dc.* intact)

    $self->{'lang_meta'} = $lang_meta;
    $self->{'langarr'} = $langarr;
}

sub get_index {
    my $self = shift (@_);

    return $self->{'index'};
}

sub set_classifiers {
    my $self = shift (@_);
    my ($classifiers) = @_;

    $self->{'classifiers'} = $classifiers;
}

sub set_indexing_text {
    my $self = shift (@_);
    my ($indexing_text) = @_;

    $self->{'indexing_text'} = $indexing_text;
}

sub get_indexing_text {
    my $self = shift (@_);

    return $self->{'indexing_text'};
}

sub set_store_text {
    my $self = shift (@_);
    my ($store_text) = @_;

    $self->{'store_text'} = $store_text;
}

sub set_store_metadata_coverage {
    my $self = shift (@_);
    my ($store_metadata_coverage) = @_;

    $self->{'store_metadata_coverage'} = $store_metadata_coverage || "";
}

sub get_doc_list {
    my $self = shift(@_);
    
    return @{$self->{'doclist'}};
}

# the standard database level is section, but you may want to change it to document
sub set_db_level {
    my $self= shift (@_);
    my ($db_level) = @_;

    $self->{'db_level'} = $db_level;
}

sub set_sections_index_document_metadata {
    my $self= shift (@_);
    my ($index_type) = @_;
    
    $self->{'sections_index_document_metadata'} = $index_type;
}

sub set_separate_cjk {
    my $self = shift (@_);
    my ($sep_cjk) = @_;

    $self->{'separate_cjk'} = $sep_cjk;
}

sub process {
    my $self = shift (@_);
    my $method = $self->{'mode'};

    $self->$method(@_);
}

# post process text depending on field. Currently don't do anything here
# except cjk separation, and only for indexing
# should only do this for indexed text (if $self->{'indexing_text'}), 
# but currently search term highlighting doesn't work if you do that.
# once thats fixed up, then fix this.
sub filter_text {
    my $self = shift (@_);
    my ($field, $text) = @_;

    # lets do cjk seg here
    my $new_text =$text;
    if ($self->{'separate_cjk'}) {
	$new_text = &cnseg::segment($text);
    }
    return $new_text;
}


sub infodb_metadata_stats
{
    my $self = shift (@_);
    my ($field,$edit_mode) = @_;

    # Keep some statistics relating to metadata sets used and
    # frequency of particular metadata fields within each set

    # Union of metadata prefixes and frequency of fields
    # (both scoped for this document alone, and across whole collection)
    
    if ($field =~ m/^(.+)\.(.*)$/) {
	my $prefix = $1;
	my $core_field = $2;

	if (($edit_mode eq "add") || ($edit_mode eq "update")) {
	    $self->{'doc_mdprefix_fields'}->{$prefix}->{$core_field}++;
	    $self->{'mdprefix_fields'}->{$prefix}->{$core_field}++;
	}
	else {
	    # delete
	    $self->{'doc_mdprefix_fields'}->{$prefix}->{$core_field}--;
	    $self->{'mdprefix_fields'}->{$prefix}->{$core_field}--;
	}

    }
    elsif ($field =~ m/^[[:upper:]]/) {
	# implicit 'ex' metadata set

	if (($edit_mode eq "add") || ($edit_mode eq "update")) {

	    $self->{'doc_mdprefix_fields'}->{'ex'}->{$field}++;
	    $self->{'mdprefix_fields'}->{'ex'}->{$field}++;
	}
	else {
	    # delete
	    $self->{'doc_mdprefix_fields'}->{'ex'}->{$field}--;
	    $self->{'mdprefix_fields'}->{'ex'}->{$field}--;
	}
    }

}


sub infodbedit {
    my $self = shift (@_);
    my ($doc_obj, $filename, $edit_mode) = @_;
    
    # only output this document if it is a "indexed_doc" or "info_doc" (database only) document
    my $doctype = $doc_obj->get_doc_type();
    return if ($doctype ne "indexed_doc" && $doctype ne "info_doc");
    
    my $archivedir = "";
    if (defined $filename)
    {
	# doc_obj derived directly from file
	my ($dir) = $filename =~ /^(.*?)(?:\/|\\)[^\/\\]*$/;
	$dir = "" unless defined $dir;
	$dir =~ s/\\/\//g;
	$dir =~ s/^\/+//;
	$dir =~ s/\/+$//;

	$archivedir = $dir;

	if ($edit_mode eq "delete") {
	    # record this doc so we don't process the reconstructed doc later
	    $self->{'dont_process_reconstructed'}->{$doc_obj->get_OID()} = 1;
	    # we don't need to do anything else for the info database for a deleted document. The infodb starts from scratch each time, so no deletion is necessary
	    $self->delete_assoc_files ($archivedir, "delete");
	    return;
	}
	if ($edit_mode eq "update") {
	    # we don't want to process the reconstructed doc later, but we will process this version now.
	    $self->{'dont_process_reconstructed'}->{$doc_obj->get_OID()} = 1;
	    # delete the old assoc files as they may have changed
	    $self->delete_assoc_files ($archivedir, "update");
	}
	
	# resolve the final filenames of the files associated with this document
	# now save the new assoc files for an update/new doc.
	$self->assoc_files ($doc_obj, $archivedir);
    }
    else
    {
	# doc_obj reconstructed from database (has metadata, doc structure but no text)
	my $top_section = $doc_obj->get_top_section();
	$archivedir = $doc_obj->get_metadata_element($top_section,"archivedir");
    }

    # rest of code used for add and update. In both cases, we add to the classifiers and to the info database. 

    #add this document to the browse structure
    push(@{$self->{'doclist'}},$doc_obj->get_OID()) 
	unless ($doctype eq "classification");
    $self->{'num_docs'} += 1 unless ($doctype eq "classification");
	
    if (!defined $filename) {
	# a reconstructed doc
	my $num_reconstructed_bytes = $doc_obj->get_metadata_element ($doc_obj->get_top_section (), "total_numbytes");
	if (defined $num_reconstructed_bytes) {
	    $self->{'num_bytes'} += $num_reconstructed_bytes;
	}
    }
    # classify the document
    &classify::classify_doc ($self->{'classifiers'}, $doc_obj);
    
    # now add all the sections to the infodb.
    
    # is this a paged or a hierarchical document
    my ($thistype, $childtype) = $self->get_document_type ($doc_obj);

    my $section = $doc_obj->get_top_section ();
    my $doc_OID = $doc_obj->get_OID();
    my $first = 1;
    my $infodb_handle = $self->{'output_handle'};

    $self->{'doc_mdprefix_fields'} = {};

    while (defined $section)
    {
	my $section_OID = $doc_OID;
	if ($section ne "")
	{
	    $section_OID = $doc_OID . "." . $section;
	}
	my %section_infodb = ();

	# update a few statistics 
	$self->{'num_bytes'} += $doc_obj->get_text_length ($section);
	$self->{'num_sections'} += 1 unless ($doctype eq "classification");
	
	# output the fact that this document is a document (unless doctype
	# has been set to something else from within a plugin
	my $dtype = $doc_obj->get_metadata_element ($section, "doctype");
	if (!defined $dtype || $dtype !~ /\w/) {
	    $section_infodb{"doctype"} = [ "doc" ];
	}

	if ($first && defined $filename) {
	    # if we are at the top level of the document, and we are not a reconstructed document, set the total_text_length - used to count bytes when we reconstruct later
	    my $length = $doc_obj->get_total_text_length();
	    $section_infodb{"total_numbytes"} = [ $length ];
	}
	# Output whether this node contains text
	#
	# If doc_obj reconstructed from database file then no need to 
	# explicitly add <hastxt> as this is preserved as metadata when
	# the database file is loaded in
	if (defined $filename)
	{
	    # doc_obj derived directly from file
	    if ($doc_obj->get_text_length($section) > 0) {
		$section_infodb{"hastxt"} = [ "1" ];
	    } else {
		$section_infodb{"hastxt"} = [ "0" ];
	    }
	}

	# output all the section metadata
	my $metadata = $doc_obj->get_all_metadata ($section);
	foreach my $pair (@$metadata) {
	    my ($field, $value) = (@$pair);

	    if ($field ne "Identifier" && $field !~ /^gsdl/ && 
		defined $value && $value ne "") {	    

		# escape problematic stuff
		$value =~ s/([^\\])\\([^\\])/$1\\\\$2/g;
		$value =~ s/\n/\\n/g;
		$value =~ s/\r/\\r/g;
		# remove any ex. iff it's the only namespace prefix (will leave ex.dc.* intact)
		$field =~ s/^ex\.([^.]+)$/$1/; # $field =~ s/^ex\.//; 

		# special case for UTF8URL metadata
		if ($field =~ m/^UTF8URL$/i) {
		    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, 
						$value, { 'section' => [ $section_OID ] });
		}
		
		if (!defined $self->{'dontdb'}->{$field}) {
		    push(@{$section_infodb{$field}}, $value);

		    if ($section eq "" 
			&& (($self->{'store_metadata_coverage'} =~ /^true$/i)
			    || $self->{'store_metadata_coverage'} eq "1"))
		    {
			$self->infodb_metadata_stats($field,$edit_mode);
		    }
		}
	    }
	}

	if ($section eq "")
	{
	    my $doc_mdprefix_fields = $self->{'doc_mdprefix_fields'};

	    foreach my $prefix (keys %$doc_mdprefix_fields)
	    {
		push(@{$section_infodb{"metadataset"}}, $prefix);

		foreach my $field (keys %{$doc_mdprefix_fields->{$prefix}})
		{
		    push(@{$section_infodb{"metadatalist-$prefix"}}, $field);

		    my $val = $doc_mdprefix_fields->{$prefix}->{$field};
		    push(@{$section_infodb{"metadatafreq-$prefix-$field"}}, $val);
		}
	    }
	}

	# If doc_obj reconstructed from database file then no need to 
	# explicitly add <archivedir> as this is preserved as metadata when
	# the database file is loaded in
	if (defined $filename)
	{
	    # output archivedir if at top level
	    if ($section eq $doc_obj->get_top_section()) {
		$section_infodb{"archivedir"} = [ $archivedir ];
	    }
	}

	# output document display type
	if ($first) {
	    $section_infodb{"thistype"} = [ $thistype ];
	}

	if ($self->{'db_level'} eq "document") {
	    # doc num is num_docs not num_sections
	    # output the matching document number
	    $section_infodb{"docnum"} = [ $self->{'num_docs'} ];
	}
	else {
	    # output a list of children
	    my $children = $doc_obj->get_children ($section);
	    if (scalar(@$children) > 0) {
		$section_infodb{"childtype"} = [ $childtype ];
		my $contains = "";
		foreach my $child (@$children)
		{
		    $contains .= ";" unless ($contains eq "");
		    if ($child =~ /^.*?\.(\d+)$/)
		    {
			$contains .= "\".$1";
		    }
		    else
		    {
			$contains .= "\".$child";
		    }
		}
		$section_infodb{"contains"} = [ $contains ];
	    }
	    # output the matching doc number
	    $section_infodb{"docnum"} = [ $self->{'num_sections'} ];
	} 
	
	if(defined $section_infodb{'assocfilepath'})
	{
		&dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, $section_infodb{'assocfilepath'}[0], { 'contains' => [ $section_OID ]});
	}
	&dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, $section_OID, \%section_infodb);
		
	# output a database entry for the document number, unless we are incremental
	unless ($self->is_incremental_capable())
	{
	    if ($self->{'db_level'} eq "document") {
		&dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, $self->{'num_docs'}, { 'section' => [ $doc_OID ] });
	    }
	    else {
		&dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, $self->{'num_sections'}, { 'section' => [ $section_OID ] });
	    }
	}
	    
	$first = 0;
	$section = $doc_obj->get_next_section($section);
	last if ($self->{'db_level'} eq "document"); # if no sections wanted, only add the docs
    } # while defined section

}




sub infodb {
    my $self = shift (@_);
    my ($doc_obj, $filename) = @_;

    $self->infodbedit($doc_obj,$filename,"add");
}

sub infodbreindex {
    my $self = shift (@_);
    my ($doc_obj, $filename) = @_;

    $self->infodbedit($doc_obj,$filename,"update");
}

sub infodbdelete {
    my $self = shift (@_);
    my ($doc_obj, $filename) = @_;

    $self->infodbedit($doc_obj,$filename,"delete");
}


sub text {
    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    my $handle = $self->{'outhandle'};
    print $handle "basebuildproc::text function must be implemented in sub classes\n";
    die "\n";
}

sub textreindex
{
    my $self = shift @_;

    my $outhandle = $self->{'outhandle'};
    print $outhandle "basebuildproc::textreindex function must be implemented in sub classes\n";
    if (!$self->is_incremental_capable()) {

	print $outhandle "  This operation is only possible with indexing tools with that support\n";
	print $outhandle "  incremental building\n";
    }
    die "\n";
}

sub textdelete
{
    my $self = shift @_;

    my $outhandle = $self->{'outhandle'};
    print $outhandle "basebuildproc::textdelete function must be implemented in sub classes\n";
    if (!$self->is_incremental_capable()) {

	print $outhandle "  This operation is only possible with indexing tools with that support\n";
	print $outhandle "  incremental building\n";
    }
    die "\n";
}


# should the document be indexed - according to the subcollection and language
# specification.
sub is_subcollection_doc {
    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    my $indexed_doc = 1;
    foreach my $indexexp (@{$self->{'indexexparr'}}) {
	$indexed_doc = 0;
	my ($field, $exp, $options) = split /\//, $indexexp;
	if (defined ($field) && defined ($exp)) {
	    my ($bool) = $field =~ /^(.)/;
	    $field =~ s/^.// if $bool eq '!';
	    my @metadata_values;
	    if ($field =~ /^filename$/i) {
		push(@metadata_values, $doc_obj->get_source_filename());
	    }
	    else {
		$field =~ s/^ex\.([^.]+)$/$1/; # remove any ex. iff it's the only namespace prefix (will leave ex.dc.* intact)
		@metadata_values = @{$doc_obj->get_metadata($doc_obj->get_top_section(), $field)};
	    }
	    next unless @metadata_values;
	    foreach my $metadata_value (@metadata_values) {
		if ($bool eq '!') {
		    if (defined $options && $options =~ /^i$/i) {
			if ($metadata_value !~ /$exp/i) {$indexed_doc = 1; last;}
		    } else {
			if ($metadata_value !~ /$exp/) {$indexed_doc = 1; last;}
		    }
		} else {
		    if (defined $options && $options =~ /^i$/i) {
			if ($metadata_value =~ /$exp/i) {$indexed_doc = 1; last;}
		    } else {
			if ($metadata_value =~ /$exp/) {$indexed_doc = 1; last;}
		    }
		}
	    }

	    last if ($indexed_doc == 1);
	}
    }
    
    # if this doc is so far in the sub collection, and we have lang info, 
    # now we check the languages to see if it matches
    if($indexed_doc && defined $self->{'lang_meta'}) {
	$indexed_doc = 0;
	my $field = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $self->{'lang_meta'});
	if (defined $field) {
	    foreach my $lang (@{$self->{'langarr'}}) {
		my ($bool) = $lang =~ /^(.)/;
		if ($bool eq '!') {
		    $lang =~ s/^.//;
		    if ($field !~ /$lang/) {
			$indexed_doc = 1; last;
		    }
		} else {
		    if ($field =~ /$lang/) {
			$indexed_doc = 1; last;
		    }
		}
	    }
	} 
    }
    return $indexed_doc;
    
}

# use 'Paged' if document has no more than 2 levels
# and each section at second level has a number for
# Title metadata
# also use Paged if gsdlthistype metadata is set to Paged
sub get_document_type {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $thistype = "VList";
    my $childtype = "VList";
    my $title;
    my @tmp = ();
    
    my $section = $doc_obj->get_top_section ();
    
    my $gsdlthistype = $doc_obj->get_metadata_element ($section, "gsdlthistype");
    if (defined $gsdlthistype) {
	if ($gsdlthistype =~ /^paged$/i) {
	    $childtype = "Paged";
	    if ($doc_obj->get_text_length ($doc_obj->get_top_section())) {
		$thistype = "Paged";
	    } else {
		$thistype = "Invisible";
	    }
	    
	    return ($thistype, $childtype);
	}
	    # gs3 pagedhierarchy option
	elsif ($gsdlthistype =~ /^pagedhierarchy$/i) {
	    $childtype = "PagedHierarchy";
	    if ($doc_obj->get_text_length ($doc_obj->get_top_section())) {
		$thistype = "PagedHierarchy";
	    } else {
		$thistype = "Invisible";
	    }
	    
	    return ($thistype, $childtype);
	} elsif ($gsdlthistype =~ /^hierarchy$/i) {
	    return ($thistype, $childtype); # use VList, VList
	}
    }
    my $first = 1;
    while (defined $section) {
	@tmp = split /\./, $section;
	if (scalar(@tmp) > 1) {
	    return ($thistype, $childtype);
	}
	if (!$first) {
	    $title = $doc_obj->get_metadata_element ($section, "Title");
	    if (!defined $title || $title !~ /^\d+$/) {
		return ($thistype, $childtype);
	    }
	}
	$first = 0;
	$section = $doc_obj->get_next_section($section);
    }
    if ($doc_obj->get_text_length ($doc_obj->get_top_section())) {
	$thistype = "Paged";
    } else {
	$thistype = "Invisible";
    }
    $childtype = "Paged";
    return ($thistype, $childtype);
}

sub assoc_files 
{
    my $self = shift (@_);
    my ($doc_obj, $archivedir) = @_;
    my ($afile);
    
    foreach my $assoc_file (@{$doc_obj->get_assoc_files()}) {
      #rint STDERR "Processing associated file - copy " . $assoc_file->[0] . " to " . $assoc_file->[1] . "\n";
	# if assoc file starts with a slash, we put it relative to the assoc
	# dir, otherwise it is relative to the HASH... directory
	if ($assoc_file->[1] =~ m@^[/\\]@) {
	    $afile = &FileUtils::filenameConcatenate($self->{'assocdir'}, $assoc_file->[1]);
	} else {
	    $afile = &FileUtils::filenameConcatenate($self->{'assocdir'}, $archivedir, $assoc_file->[1]);
	}
	
	&FileUtils::hardLink($assoc_file->[0], $afile, $self->{'verbosity'});
    }
}

sub delete_assoc_files 
{
    my $self = shift (@_);
    my ($archivedir, $edit_mode) = @_;

    my $assoc_dir = &FileUtils::filenameConcatenate($self->{'assocdir'}, $archivedir);
    if (-d $assoc_dir) {
	&FileUtils::removeFilesRecursive($assoc_dir);
    }
}
