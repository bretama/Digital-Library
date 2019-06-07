###########################################################################
#
# HathiTrustMETSPlugin.pm -- plugin for sets of HathiTrust METS OCR'd 
#   text that make up a document
#
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

# HathiTrustMETSPlugin
# processes HathiTrust METS files that are accompanied with page-by-page
#  OCR'd txt files
#
# All the supplemetary text files should be in a subfolder of the same
#  name as the METS file
#
# As usual, running 
# 'perl -S pluginfo.pl HathiTrustMETSPlugin' will list all the options.


package HathiTrustMETSPlugin;

use Encode;
use ReadXMLFile;
use ReadTextFile;
# We don't currently work with the scanned image from HathiTrust METS
# but leave it in for future proofing
use ImageConverter;
use MetadataRead;

use JSON;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @HathiTrustMETSPlugin::ISA = ('MetadataRead', 'ReadXMLFile', 'ReadTextFile', 'ImageConverter'
	);
}

# One day HathiTrust might give more than page structure
my $gs2_type_list =
    [ 
#      { 'name' => "auto",
#	'desc' => "{PagedImagePlugin.documenttype.auto2}" },
#      { 'name' => "paged",
#        'desc' => "{PagedImagePlugin.documenttype.paged2}" },
      { 'name' => "hierarchy",
        'desc' => "{PagedImagePlugin.documenttype.hierarchy}" }
    ];

my $gs3_type_list =     
    [ 
#      { 'name' => "auto",
#	'desc' => "{PagedImagePlugin.documenttype.auto3}" },
#      { 'name' => "paged",
#        'desc' => "{PagedImagePlugin.documenttype.paged3}" },
      { 'name' => "hierarchy",
        'desc' => "{PagedImagePlugin.documenttype.hierarchy}" }
#      { 'name' => "pagedhierarchy",
#        'desc' => "{PagedImagePlugin.documenttype.pagedhierarchy}" }
    ];

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "string",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "title_sub",
	'desc' => "{HTMLPlugin.title_sub}",
	'type' => "string", 
	'deft' => "" },
      { 'name' => "headerpage",
	'desc' => "{HathiTrustMETSPlugin.headerpage}",
	'type' => "flag",
	'reqd' => "no" },
#      { 'name' => "documenttype",
#	'desc' => "{HathiTrustMETSPlugin.documenttype}",
#	'type' => "enum",
#	'list' => $type_list,
#	'deft' => "auto",
#	'reqd' => "no" },
      {'name' => "processing_tmp_files",
       'desc' => "{BaseImporter.processing_tmp_files}",
       'type' => "flag",
       'hiddengli' => "yes"}
    ];

my $doc_type_opt = { 'name' => "documenttype",
		     'desc' => "{HathiTrustMETSPlugin.documenttype}",
		     'type' => "enum",
		     'deft' => "auto",
		     'reqd' => "no" };

my $options = { 'name'     => "HathiTrustMETSPlugin",
		'desc'     => "{HathiTrustMETSPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"OptList"}},$options);
   
    my $imc_self = new ImageConverter($pluginlist, $inputargs, $hashArgOptLists);
    
    # we can use this plugin to check gs3 version
    if ($imc_self->{'gs_version'} eq "3") {
	$doc_type_opt->{'list'} = $gs3_type_list;
    }
    else {
	$doc_type_opt->{'list'} = $gs2_type_list;
    }
    push(@$arguments,$doc_type_opt);
    # now we add the args to the list for parsing
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    
    my $rtf_self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists, 1);
    my $rxf_self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);

    my $self = BaseImporter::merge_inheritance($imc_self,$rtf_self,$rxf_self);

    # Update $self used by XML::Parser so it finds callback functions 
    # such as start_document here and not in ReadXMLFile (which is what
    # $self was when new XML::Parser was done)
    #
    # If the $self returned by this constructor is the same as the one
    # used in ReadXMLFile (e.g. in the GreenstoneXMLPlugin) then this step isn't necessary
    #
    # Consider embedding this type of assignment into merge_inheritance
    # to help catch all cases?

    $rxf_self->{'parser'}->{'PluginObj'} = $self;

    return bless $self, $class;
}


sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    $self->SUPER::init(@_);
    $self->ImageConverter::init();
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    $self->SUPER::begin(@_);
    $self->ImageConverter::begin(@_);
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^\.mets.xml$^;
}

sub get_doctype {
    my $self = shift(@_);
    
    return "METS:mets";
}


# want to use BaseImporter's version of this, not ReadXMLFile's
sub can_process_this_file {
    my $self = shift(@_);
    return $self->BaseImporter::can_process_this_file(@_);
}

# instead of a block exp, now we scan the file and record all text and img files mentioned there for blocking.
sub store_block_files
{
    my $self = shift (@_);
    my ($filename_full_path, $block_hash) = @_;

    # do we need to do this? 
    # does BOM interfere just with XML parsing? In that case don't need it here
    # if we do it here, we are modifying the file before we have worked out if
    # its new or not, so it will always be reimported.
    #$self->tidy_item_file($filename_full_path);

    my ($dir, $file) = $filename_full_path =~ /^(.*?)([^\/\\]*)$/;

    # do something
    $self->scan_xml_for_files_to_block($filename_full_path, $dir, $block_hash);
	
}

# we want to use BaseImporter's read, not ReadXMLFile's
sub read
{
    my $self = shift (@_);

    $self->BaseImporter::read(@_);
}



sub read_into_doc_obj {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};
    
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    print $outhandle "HathiTrustMETSPlugin processing \"$filename_full_path\"\n"
	if $verbosity > 1;
    print STDERR "<Processing n='$file' p='HathiTrustMETSPlugin'>\n" if ($gli);
    
##    $self->{'MaxImageWidth'} = 0;
##    $self->{'MaxImageHeight'} = 0;
    

    ##$self->tidy_item_file($filename_full_path);
    
    # careful checking needed here!! are we using local xml handlers or super ones
    $self->ReadXMLFile::read($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli);
    my $doc_obj = $self->{'doc_obj'};


    my $section = $doc_obj->get_top_section();
        
    $doc_obj->add_utf8_metadata($section, "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_metadata($section, "FileFormat", "HathiTrustMETS");

    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    $self->add_associated_files($doc_obj, $filename_full_path);
    $self->extra_metadata ($doc_obj, $section, $metadata);
    $self->auto_extract_metadata ($doc_obj);
    $self->plugin_specific_process($base_dir, $file, $doc_obj, $gli);
    # if we haven't found any Title so far, assign one
    $self->title_fallback($doc_obj,$section,$filename_no_path);

    $self->add_OID($doc_obj);
    return (1,$doc_obj);
}


sub parse_aux_json_metadata {
    my $self = shift(@_);
    my ($base_dir, $file, $doc_obj, $gli) = @_;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    my $topsection = $doc_obj->get_top_section();

    my $json_metadata_filename = $filename_full_path;
    $json_metadata_filename =~ s/\.mets.xml$/.json/;
    
    my $json_text = "";
    $self->ReadTextFile::read_file($json_metadata_filename,"utf8",undef,\$json_text);

    my $json_rec = decode_json $json_text;
    my $records = $json_rec->{'records'};
    my @keys = keys %{$records};

    my $key = shift @keys; # there should only be one
    my $record = $records->{$key};

    my @md_fields = ( "recordURL", "titles", "isbns", "issns", "oclcs", "lccns", "publishDates" );

    foreach my $md_field (@md_fields) {
	my $value_array = $record->{$md_field};

	my $md_name = $md_field;
	$md_name =~ s/s$//;

	foreach my $md_value (@$value_array) {

	    if ($md_name eq "title") {
		$doc_obj->set_utf8_metadata_element ($topsection, "Title", $md_value);
		$doc_obj->set_utf8_metadata_element ($topsection, "dc.Title", $md_value);
	    }
	    else {
		$doc_obj->set_utf8_metadata_element ($topsection, $md_name, $md_value);
	    }
	}
    }

    my $htid = $json_rec->{'items'}->[0]->{'htid'};
    my $docName = $htid;
    my $docNameIE = $htid;
    $docNameIE =~ s/^.*?\.//;

    $doc_obj->set_utf8_metadata_element ($topsection, "docName", $docName);
    $doc_obj->set_utf8_metadata_element ($topsection, "docNameIE", $docNameIE);

}


# override this for an inheriting plugin to add extra metadata etc
sub plugin_specific_process {
    my $self = shift(@_);
    my ($base_dir, $file, $doc_obj, $gli) = @_;
    
    $self->parse_aux_json_metadata($base_dir,$file,$doc_obj,$gli);
}

# sub tidy_item_file {
#   ... see PagedImagePlugin
# }

# sub rotate_image {
#   ... see PagedImagePlugin
# }

# sub process_image {
#   ... see PagedImagePlugin
# }



sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    $self->{'element'} = $element;
    
    my $doc_obj = $self->{'doc_obj'};
    if ($element eq "METS:mets") {
	$self->{'current_section'} = $doc_obj->get_top_section();
#    } elsif ($element eq "PageGroup" || $element eq "Page") {
##	if ($element eq "PageGroup") {
##	    $self->{'has_internal_structure'} = 1;
    }
    elsif (($element eq "METS:FLocat") && ($_{'xlink:href'} =~ m/\.txt$/)) {
	# e.g. <METS:FLocat LOCTYPE="OTHER" OTHERLOCTYPE="SYSTEM" xlink:href="00000000.txt"/>
		  
	# create a new section as a child
	$self->{'current_section'} = $doc_obj->insert_section($doc_obj->get_end_child($self->{'current_section'}));
	$self->{'num_pages'}++;
	# assign pagenum as ... what?? => use page sequence number
	my $txtfile = $_{'xlink:href'};
	my ($pagenum) = ($txtfile =~ m/^(\d+)/);

	if (defined $pagenum) {
	    my $pagenum_int = int($pagenum);
	    $doc_obj->set_utf8_metadata_element($self->{'current_section'}, "Title", "Page $pagenum_int");
	}
##	my ($imgfile) = $_{'imgfile'};
##	if (defined $imgfile) {
##	    # *****
##	    # What about support for rotate image (e.g. old ':r' notation)? 
##	    $self->process_image($self->{'xml_file_dir'}.$imgfile, $imgfile, $doc_obj, $self->{'current_section'});
##	}

##	my ($txtfile) = $_{'txtfile'};
	if (defined($txtfile)&& $txtfile ne "") {
	    my $full_txt_filename = &FileUtils::filenameConcatenate($self->{'xml_file_dir'},$txtfile);
	    $self->process_text ($full_txt_filename, $txtfile, $doc_obj, $self->{'current_section'});
  	} else {
	    $self->add_dummy_text($doc_obj, $self->{'current_section'});
	}
    }
##    elsif ($element eq "Metadata") {
##	$self->{'metadata_name'} = $_{'name'};
##    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    
    my $doc_obj = $self->{'doc_obj'};
##    if ($element eq "Page" || $element eq "PageGroup") {
    if (($element eq "METS:FLocat") && ($_{'xlink:href'} =~ m/\.txt$/)) {
	# if Title hasn't been assigned, set PageNum as Title
	if (!defined $doc_obj->get_metadata_element ($self->{'current_section'}, "Title") && defined $doc_obj->get_metadata_element ($self->{'current_section'}, "PageNum" )) {
	    $doc_obj->add_utf8_metadata ($self->{'current_section'}, "Title", $doc_obj->get_metadata_element ($self->{'current_section'}, "PageNum" ));
	}
	# move the current section back to the parent
	$self->{'current_section'} = $doc_obj->get_parent_section($self->{'current_section'});
    } elsif ($element eq "Metadata") {
	
	# text read in by XML::Parser is in Perl's binary byte value
	# form ... need to explicitly make it UTF-8		
	my $meta_name = decode("utf-8",$self->{'metadata_name'});
	my $metadata_value = decode("utf-8",$self->{'metadata_value'});
	
	if ($meta_name =~ /\./) {
	    $meta_name = "ex.$meta_name";
	}
	
	$doc_obj->add_utf8_metadata ($self->{'current_section'}, $meta_name, $metadata_value);
	$self->{'metadata_name'} = "";
	$self->{'metadata_value'} = "";

    }
    # otherwise we ignore the end tag
}


sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_; 

    if ($self->{'element'} eq "Metadata" && $self->{'metadata_name'}) {
   	$self->{'metadata_value'} .= $_;
    }
}

sub xml_doctype {
}

sub open_document {
    my $self = shift(@_);
    
    # create a new document
    $self->{'doc_obj'} = new doc ($self->{'filename'}, "indexed_doc", $self->{'file_rename_method'});
    # TODO is file filenmae_no_path??
    $self->set_initial_doc_fields($self->{'doc_obj'}, $self->{'filename'}, $self->{'processor'}, $self->{'metadata'});

##    my ($dir, $file) = $self->{'filename'} =~ /^(.*?)([^\/\\]*)$/;
    my ($dir, $file_ext) = $self->{'filename'} =~ /^(.*?)(\.mets\.xml)$/;

    $self->{'xml_file_dir'} = $dir;
    $self->{'num_pages'} = 0;
##    $self->{'has_internal_structure'} = 0;

}

sub close_document {
    my $self = shift(@_);
    my $doc_obj = $self->{'doc_obj'};
    
    my $topsection = $doc_obj->get_top_section();

    # add numpages metadata
    $doc_obj->set_utf8_metadata_element ($topsection, 'NumPages', $self->{'num_pages'}); # ##### !!!!

    # set the document type
    my $final_doc_type = "";
##    if ($self->{'documenttype'} eq "auto") {
###	if ($self->{'has_internal_structure'}) {
###	    if ($self->{'gs_version'} eq "3") {
###		$final_doc_type = "pagedhierarchy";
###	    }
###	    else {
###		$final_doc_type = "hierarchy";
###	    }
###	} else {
###	    $final_doc_type = "paged";
###	}
###    } else {
##	# set to what doc type option was set to
##	$final_doc_type = $self->{'documenttype'};
##    }
#    $doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", $final_doc_type); # #### !!!!!
    ### capiatalisation????
#    if ($self->{'documenttype'} eq 'paged') {
	# set the gsdlthistype metadata to Paged - this ensures this document will
	# be treated as a Paged doc, even if Titles are not numeric
#	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", "Paged");
#    } else {
#	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", "Hierarchy");
#    }

##    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageWidth",$self->{'MaxImageWidth'});
##    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageHeight",$self->{'MaxImageHeight'});
##    $self->{'MaxImageWidth'} = undef;
##    $self->{'MaxImageHeight'} = undef;
    
}


sub set_initial_doc_fields {
    my $self = shift(@_);
    my ($doc_obj, $filename_full_path, $processor, $metadata) = @_;

    my $topsection = $doc_obj->get_top_section();

    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($filename_full_path,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);
   
    # if we want a header page, we need to add some text into the top section, otherwise this section will become invisible
    if ($self->{'headerpage'}) {
	$self->add_dummy_text($doc_obj, $topsection);
    }
}

sub scan_xml_for_files_to_block
{
    my $self = shift (@_);
    my ($filename_full_path, $dir, $block_hash) = @_;

    my ($file_root) = ($filename_full_path =~ m/^(.*)\.mets\.xml$/);

    $self->block_raw_filename($block_hash,"$file_root.zip");
    $self->block_raw_filename($block_hash,"$file_root.json");

    my $page_dir = $file_root;

    open (METSFILE, $filename_full_path) || die "couldn't open $filename_full_path to work out which files to block\n";
    my $line = "";
    while (defined ($line = <METSFILE>)) {
	next unless $line =~ /\w/;

        # Exaple of what we are looking for 
	#    <METS:FLocat LOCTYPE="OTHER" OTHERLOCTYPE="SYSTEM" xlink:href="00000000.txt"/>

	if ($line =~ /xlink:href=\"([^\"]+)\"/) {
	    my $txt_filename = &FileUtils::filenameConcatenate($page_dir,$1);
	    my $topics_filename = $txt_filename . ".topics";
	    $self->block_raw_filename($block_hash,$txt_filename);
	    $self->block_raw_filename($block_hash,$topics_filename);
	}
    }
    close METSFILE;
    
}


sub process_text {
    my $self = shift (@_);
    my ($filename_full_path, $file, $doc_obj, $cursection) = @_;
    
    # check that the text file exists!!
    if (!-f $filename_full_path) {
	print "HathiTrustMETSPlugin: ERROR: File $filename_full_path does not exist, skipping\n";
	return 0;
    }

    # remember that this text file was one of our source files, but only 
    # if we are not processing a tmp file
    if (!$self->{'processing_tmp_files'} ) {
	$doc_obj->associate_source_file($filename_full_path);
    }
    # Do encoding stuff
    my ($language, $encoding) = $self->textcat_get_language_encoding ($filename_full_path);

    my $text="";
    if ( -s $filename_full_path > 0 ) {
	&ReadTextFile::read_file($self, $filename_full_path, $encoding, $language, \$text); # already decoded as utf8
    }

# HathiTrust often has empty files
##    if (!length ($text)) {
##	# It's a bit unusual but not out of the question to have no text, so just give a warning
##        print "HathiTrustMETSPlugin: WARNING: $filename_full_path contains no text\n";
##    }

    # we need to escape the escape character, or else mg will convert into
    # eg literal newlines, instead of leaving the text as '\n'
    $text =~ s/\\/\\\\/g; # macro language
    $text =~ s/_/\\_/g; # macro language


    if ($text =~ m/<html.*?>\s*<head.*?>.*<\/head>\s*<body.*?>(.*)<\/body>\s*<\/html>\s*$/is) {
	# looks like HTML input
	# no need to escape < and > or put in <pre> tags

	$text = $1;

	# add text to document object
	$doc_obj->add_utf8_text($cursection, "$text");
    }
    else {
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;

	# insert preformat tags and add text to document object
	$doc_obj->add_utf8_text($cursection, "<pre>\n$text\n</pre>");
    }

    my $topics_filename = $filename_full_path . ".topics";
    if ( -s $topics_filename > 0 ) {
	
	my $topics_text = "";
	$self->ReadTextFile::read_file($topics_filename,"utf8",undef,\$topics_text);
	
	my @topics_array = split(/\|/,$topics_text);
	foreach my $topic (@topics_array) {
	    if ($topic ne "") {
		$doc_obj->set_utf8_metadata_element ($cursection, "concept", $topic);
	    }
	}
    }
    
    return 1;
}


sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);
    
    $self->ImageConverter::clean_up_temporary_files();
}

1;
