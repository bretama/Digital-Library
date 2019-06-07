###########################################################################
#
# PagedImagePlugin.pm -- plugin for sets of images and OCR text that
#  make up a document
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

# PagedImagePlugin
# processes sequences of images, with optional OCR text
#
# This plugin takes *.item files, which contain metadata and lists of image 
# files, and produces a document containing sections, one for each page.
# The files should be named something.item, then you can have more than one 
# book in a directory. You will need to create these files, one for each
# document/book.
#
#There are two formats for the item files: a plain text format, and an xml 
#format. You can use either format, and can have both formats in the same 
#collection if you like. If you use the plain format, you must not start the 
#file off with <PagedDocument>

#### PLAIN FORMAT
# The format of the xxx.item file is as follows:
# The first lines contain any metadata for the whole document
# <metadata-name>metadata-value
# eg.
# <Title>Snail farming
# <Date>19230102
# Then comes a list of pages, one page per line, each line has the format
#
# pagenum:imagefile:textfile:r
#
# page num and imagefile are required. pagenum is used for the Title 
# of the section, and in the display is shown as page <pagenum>. 
# imagefile is the image for the page. textfile is an optional text 
# file containing the OCR (or any) text for the page - this gets added 
# as the text for the section. r is optional, and signals that the image 
# should be rotated 180deg. Eg use this if the image has been made upside down.
# So an example item file looks like:
# <Title>Snail farming
# <Date>19960403
# 1:p1.gif:p1.txt:
# 2:p2.gif::
# 3:p3.gif:p3.txt:
# 3b:p3b.gif:p3b.txt:r
# The second page has no text, the fourth page is a back page, and 
# should be rotated.
# 

#### XML FORMAT
# The xml format looks like the following
#<PagedDocument>
#<Metadata name="Title">The Title of the entire document</Metadata>
#<Page pagenum="1" imgfile="xxx.jpg" txtfile="yyy.txt">
#<Metadata name="Title">The Title of this page</Metadata>
#</Page>
#... more pages
#</PagedDocument>
#PagedDocument contains a list of Pages, Metadata and PageGroups. Any metadata 
#that is not inside another tag will belong to the document.
#Each Page has a pagenum (not used at the moment), an imgfile and/or a txtfile.
#These are both optional - if neither is used, the section will have no content.
#Pages can also have metadata associated with them.
#PageGroups can be introduced at any point - they can contain Metadata and Pages and other PageGroups. They are used to introduce hierarchical structure into the document.
#For example
#<PagedDocument>
#<PageGroup>
#<Page>
#<Page>
#</PageGroup>
#<Page>
#</PagedDocument>
#would generate a structure like
#X
#--X
#  --X
#  --X
#--X
#PageGroup tags can also have imgfile/textfile metadata if you like - this way they get some content themselves.

#Currently the XML structure doesn't work very well with the paged document type, unless you use numerical Titles for each section.
#There is still a bit of work to do on this format:
#* enable other text file types, eg html, pdf etc
#* make the document paging work properly
#* add pagenum as Title unless a Title is present?

# All the supplemetary image amd text files should be in the same folder as 
# the .item file.
#
# To display the images instead of the document text, you can use [srcicon] 
# in the DocumentText format statement.
# For example, 
#
# format DocumentText "<center><table width=_pagewidth_><tr><td>[srcicon]</td></tr></table></center>"
#
# To have it create thumbnail size images, use the '-create_thumbnail' option.
# To have it create medium size images for display, use the '-create_screenview'
# option. As usual, running 
# 'perl -S pluginfo.pl PagedImagePlugin' will list all the options.

# If you want the resulting documents to be presented with a table of 
# contents, use '-documenttype hierarchy', otherwise they will have 
# next and previous arrows, and a goto page X box. 

# If you have used -create_screenview, you can also use [screenicon] in the format
# statement to display the smaller image.  Here is an example  that switches 
# between the two: 
#
# format DocumentText "<center><table width=_pagewidth_><tr><td>{If}{_cgiargp_ eq full,<a href='_httpdocument_&d=_cgiargd_&p=small'>Switch to small version.</a>,<a href='_httpdocument_&d=_cgiargd_&p=full'>Switch to fullsize version</a>}</td></tr><tr><td>{If}{_cgiargp_ eq full,<a href='_httpdocument_&d=_cgiargd_&p=small' title='Switch to small version'>[srcicon]</a>,<a href='_httpdocument_&d=_cgiargd_&p=full' title='Switch to fullsize version'>[screenicon]</a>}</td></tr></table></center>"
#
# Additional metadata can be added into the .item files, alternatively you can 
# use normal metadata.xml files, with the name of the xxx.item file as the 
# FileName (only for document level metadata).

package PagedImagePlugin;

use Encode;
use ReadXMLFile;
use ReadTextFile;
use ImageConverter;
use MetadataRead;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @PagedImagePlugin::ISA = ('MetadataRead', 'ReadXMLFile', 'ReadTextFile', 'ImageConverter');
}

my $gs2_type_list =
    [ { 'name' => "auto",
	'desc' => "{PagedImagePlugin.documenttype.auto2}" },
      { 'name' => "paged",
        'desc' => "{PagedImagePlugin.documenttype.paged2}" },
      { 'name' => "hierarchy",
        'desc' => "{PagedImagePlugin.documenttype.hierarchy}" }
    ];

my $gs3_type_list =     
    [ { 'name' => "auto",
	'desc' => "{PagedImagePlugin.documenttype.auto3}" },
      { 'name' => "paged",
        'desc' => "{PagedImagePlugin.documenttype.paged3}" },
      { 'name' => "hierarchy",
        'desc' => "{PagedImagePlugin.documenttype.hierarchy}" }, 
      { 'name' => "pagedhierarchy",
        'desc' => "{PagedImagePlugin.documenttype.pagedhierarchy}" }
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
	'desc' => "{PagedImagePlugin.headerpage}",
	'type' => "flag",
	'reqd' => "no" },
#      { 'name' => "documenttype",
#	'desc' => "{PagedImagePlugin.documenttype}",
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
		     'desc' => "{PagedImagePlugin.documenttype}",
		     'type' => "enum",
		     'deft' => "auto",
		     'reqd' => "no" };

my $options = { 'name'     => "PagedImagePlugin",
		'desc'     => "{PagedImagePlugin.desc}",
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

    return q^\.item$^;
}

sub get_doctype {
    my $self = shift(@_);
    
    return "PagedDocument";
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

    my $xml_version = $self->is_xml_item_file($filename_full_path);
    
    # do we need to do this? 
    # does BOM interfere just with XML parsing? In that case don't need it here
    # if we do it here, we are modifying the file before we have worked out if
    # its new or not, so it will always be reimported.
    #$self->tidy_item_file($filename_full_path);

    my ($dir, $file) = $filename_full_path =~ /^(.*?)([^\/\\]*)$/;
    if ($xml_version) {

	# do something
	$self->scan_xml_for_files_to_block($filename_full_path, $dir, $block_hash);
    } else {
	
	$self->scan_item_for_files_to_block($filename_full_path, $dir, $block_hash);
    }
	
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

    print $outhandle "PagedImagePlugin processing \"$filename_full_path\"\n"
	if $verbosity > 1;
    print STDERR "<Processing n='$file' p='PagedImagePlugin'>\n" if ($gli);
    
    $self->{'MaxImageWidth'} = 0;
    $self->{'MaxImageHeight'} = 0;
    
    # here we need to decide if we have an old text .item file, or a new xml 
    # .item file
    my $xml_version = $self->is_xml_item_file($filename_full_path);

    $self->tidy_item_file($filename_full_path);
    
    my $doc_obj;
    if ($xml_version) {
	# careful checking needed here!! are we using local xml handlers or super ones
	$self->ReadXMLFile::read($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli);
	$doc_obj = $self->{'doc_obj'};
    } else {
	my ($dir, $item_file);
	($dir, $item_file) = $filename_full_path =~ /^(.*?)([^\/\\]*)$/;

	#process the .item file
	$doc_obj = $self->process_item($filename_full_path, $dir, $item_file, $processor, $metadata);
	
    }

    my $section = $doc_obj->get_top_section();
        
    $doc_obj->add_utf8_metadata($section, "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_metadata($section, "FileFormat", "PagedImage");

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
# override this for an inheriting plugin to add extra metadata etc
sub plugin_specific_process {
    my $self = shift(@_);
    my ($base_dir, $file, $doc_obj, $gli) = @_;

}

# for now, the test is if the first non-empty line is <PagedDocument>, then its xml
sub is_xml_item_file {
    my $self = shift(@_);
    my ($filename) = @_;

    my $xml_version = 0;
    open (ITEMFILE, $filename) || die "couldn't open $filename\n";

    my $line = "";
    my $num = 0;

    $line = <ITEMFILE>;
    while (defined ($line) && ($line !~ /\w/)) {
	$line = <ITEMFILE>;
    }

    if (defined $line) {
	chomp $line;
	if ($line =~ /<PagedDocument/) {
	    $xml_version = 1;
	}
    } 

    close ITEMFILE; 
    return $xml_version;
}

sub tidy_item_file {
    my $self = shift(@_);
    my ($filename) = @_;

    open (ITEMFILE, "<:encoding(UTF-8)", $filename) || die "couldn't open $filename\n";
    my $backup_filename = "backup.item";
    open (BACKUP,">$backup_filename")|| die "couldn't write to $backup_filename\n";
    binmode(BACKUP, ":utf8");
    my $line = "";
    $line = <ITEMFILE>;
    #$line =~ s/^\xEF\xBB\xBF//; # strip BOM in text file read in as a sequence of bytes (not unicode aware strings)
    $line =~ s/^\x{FEFF}//; # strip BOM in file opened *as UTF-8*. Strings in the file just read in are now unicode-aware,
                            # this means the BOM is now a unicode codepoint instead of a byte sequence
                            # See http://en.wikipedia.org/wiki/Byte_order_mark and http://perldoc.perl.org/5.14.0/perlunicode.html 
    $line =~ s/\x{0B}+//ig; # removing \vt-vertical tabs using the unicode codepoint for \vt
    $line =~ s/&/&amp;/g;
    print BACKUP ($line);
    #Tidy up the item file some metadata title contains \vt-vertical tab
    while ($line = <ITEMFILE>) {
	$line =~ s/\x{0B}+//ig; # removing \vt-vertical tabs using the unicode codepoint for \vt
	$line =~ s/&/&amp;/g;
	print BACKUP ($line);
    }
    close ITEMFILE;
    close BACKUP;
    &File::Copy::copy ($backup_filename, $filename);
    &FileUtils::removeFiles($backup_filename);

}

sub rotate_image {
    my $self = shift (@_);
    my ($filename_full_path) = @_;
    
    my ($this_filetype) = $filename_full_path =~ /\.([^\.]*)$/;
    my $result = $self->convert($filename_full_path, $this_filetype, "-rotate 180", "ROTATE");
    my ($new_filename) = ($result =~ /=>(.*\.$this_filetype)/);
    if (-e "$new_filename") {
	return $new_filename;
    }
    # somethings gone wrong
    return $filename_full_path;

}

sub process_image {
    my $self = shift(@_);
    my ($filename_full_path, $filename_no_path, $doc_obj, $section, $rotate) = @_;
    # check the filenames
    return 0 if ($filename_no_path eq "" || !-f $filename_full_path);
 
    # remember that this image file was one of our source files, but only 
    # if we are not processing a tmp file
    if (!$self->{'processing_tmp_files'} ) {
	$doc_obj->associate_source_file($filename_full_path);
    }
    # do rotation
    if  ((defined $rotate) && ($rotate eq "r")) {
	# we get a new temporary file which is rotated
	$filename_full_path = $self->rotate_image($filename_full_path);
    }
    
    # do generate images
    my $result = 0;
    if ($self->{'image_conversion_available'} == 1) {
	# do we need to convert $filename_no_path to utf8/url encoded? 
	# We are already reading in from a file, what encoding is it in???
	my $url_encoded_full_filename 
	    = &unicode::raw_filename_to_url_encoded($filename_full_path);
	$result = $self->generate_images($filename_full_path, $url_encoded_full_filename, $doc_obj, $section);
    }
    #overwrite one set in ImageConverter
    $doc_obj->set_metadata_element ($section, "FileFormat", "PagedImage");
    return $result;
}


sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    $self->{'element'} = $element;
    
    my $doc_obj = $self->{'doc_obj'};
    if ($element eq "PagedDocument") {
	$self->{'current_section'} = $doc_obj->get_top_section();
    } elsif ($element eq "PageGroup" || $element eq "Page") {
	if ($element eq "PageGroup") {
	    $self->{'has_internal_structure'} = 1;
	}
	# create a new section as a child
	$self->{'current_section'} = $doc_obj->insert_section($doc_obj->get_end_child($self->{'current_section'}));
	$self->{'num_pages'}++;
	# assign pagenum as  what??
	my $pagenum = $_{'pagenum'}; #TODO!!
	if (defined $pagenum) {
	    $doc_obj->set_utf8_metadata_element($self->{'current_section'}, 'PageNum', $pagenum);
	}
	my ($imgfile) = $_{'imgfile'};
	if (defined $imgfile) {
	    # *****
	    # What about support for rotate image (e.g. old ':r' notation)? 
	    $self->process_image($self->{'xml_file_dir'}.$imgfile, $imgfile, $doc_obj, $self->{'current_section'});
	}
	my ($txtfile) = $_{'txtfile'};
	if (defined($txtfile)&& $txtfile ne "") {
	    $self->process_text ($self->{'xml_file_dir'}.$txtfile, $txtfile, $doc_obj, $self->{'current_section'});
  	} else {
	    $self->add_dummy_text($doc_obj, $self->{'current_section'});
	}
    } elsif ($element eq "Metadata") {
	$self->{'metadata_name'} = $_{'name'};
    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    
    my $doc_obj = $self->{'doc_obj'};
    if ($element eq "Page" || $element eq "PageGroup") {
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

    my ($dir, $file) = $self->{'filename'} =~ /^(.*?)([^\/\\]*)$/;
    $self->{'xml_file_dir'} = $dir;
    $self->{'num_pages'} = 0;
    $self->{'has_internal_structure'} = 0;

}

sub close_document {
    my $self = shift(@_);
    my $doc_obj = $self->{'doc_obj'};
    
    my $topsection = $doc_obj->get_top_section();

    # add numpages metadata
    $doc_obj->set_utf8_metadata_element ($topsection, 'NumPages', $self->{'num_pages'});

    # set the document type
    my $final_doc_type = "";
    if ($self->{'documenttype'} eq "auto") {
	if ($self->{'has_internal_structure'}) {
	    if ($self->{'gs_version'} eq "3") {
		$final_doc_type = "pagedhierarchy";
	    }
	    else {
		$final_doc_type = "hierarchy";
	    }
	} else {
	    $final_doc_type = "paged";
	}
    } else {
	# set to what doc type option was set to
	$final_doc_type = $self->{'documenttype'};
    }
    $doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", $final_doc_type);
    ### capiatalisation????
#    if ($self->{'documenttype'} eq 'paged') {
	# set the gsdlthistype metadata to Paged - this ensures this document will
	# be treated as a Paged doc, even if Titles are not numeric
#	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", "Paged");
#    } else {
#	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", "Hierarchy");
#    }

    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageWidth",$self->{'MaxImageWidth'});
    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageHeight",$self->{'MaxImageHeight'});
    $self->{'MaxImageWidth'} = undef;
    $self->{'MaxImageHeight'} = undef;
    
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

    open (ITEMFILE, $filename_full_path) || die "couldn't open $filename_full_path to work out which files to block\n";
    my $line = "";
    while (defined ($line = <ITEMFILE>)) {
	next unless $line =~ /\w/;

	if ($line =~ /imgfile=\"([^\"]+)\"/) {
	    $self->block_raw_filename($block_hash,&FileUtils::filenameConcatenate($dir,$1));
	}
	if ($line =~ /txtfile=\"([^\"]+)\"/) {
	    $self->block_raw_filename($block_hash,&FileUtils::filenameConcatenate($dir,$1));
	}
    }
    close ITEMFILE;
    
}

sub scan_item_for_files_to_block
{
    my $self = shift (@_);
    my ($filename_full_path, $dir, $block_hash) = @_;


    open (ITEMFILE, $filename_full_path) || die "couldn't open $filename_full_path to work out which files to block\n";
    my $line = "";
    while (defined ($line = <ITEMFILE>)) {
	next unless $line =~ /\w/;
	chomp $line;
	next if $line =~ /^#/; # ignore comment lines
	next if ($line =~ /^<([^>]*)>\s*(.*?)\s*$/); # ignore metadata lines 
	# line should be like page:imagefilename:textfilename:r 
	$line =~ s/^\s+//; #remove space at the front
	$line =~ s/\s+$//; #remove space at the end
	my ($pagenum, $imgname, $txtname, $rotate) = split /:/, $line;
	    
	# find the image file if there is one
	if (defined $imgname && $imgname ne "") {
	    $self->block_raw_filename($block_hash, &FileUtils::filenameConcatenate( $dir,$imgname));
	}
	# find the text file if there is one
	if (defined $txtname && $txtname ne "") {
	    $self->block_raw_filename($block_hash, &FileUtils::filenameConcatenate($dir,$txtname));
	}
    }
    close ITEMFILE;

}

sub process_item {
    my $self = shift (@_);
    my ($filename_full_path, $dir, $filename_no_path, $processor, $metadata) = @_;

    my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});
    $self->set_initial_doc_fields($doc_obj, $filename_full_path, $processor, $metadata);
    my $topsection = $doc_obj->get_top_section();
    # simple item files are always paged unless user specified
    if ($self->{'documenttype'} eq "auto") {
	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", "paged");
    } else {
	$doc_obj->set_utf8_metadata_element ($topsection, "gsdlthistype", $self->{'documenttype'});
    }
    open (ITEMFILE, "<:encoding(UTF-8)", $filename_full_path) || die "couldn't open $filename_full_path\n";
    my $line = "";
    my $num = 0;
    while (defined ($line = <ITEMFILE>)) {
	
	next unless $line =~ /\w/;
	chomp $line;
	next if $line =~ /^#/; # ignore comment lines
	if ($line =~ /^<([^>]*)>\s*(.*?)\s*$/) {
	    my $meta_name = $1;
	    my $meta_value = $2;
	    if ($meta_name =~ /\./) {
		$meta_name = "ex.$meta_name";
	    }
	    $doc_obj->set_utf8_metadata_element ($topsection, $meta_name, $meta_value);
	    #$meta->{$1} = $2;
	} else {
	    $num++;
	    # line should be like page:imagefilename:textfilename:r - the r is optional -> means rotate the image 180 deg
	    $line =~ s/^\s+//; #remove space at the front
	    $line =~ s/\s+$//; #remove space at the end
	    my ($pagenum, $imgname, $txtname, $rotate) = split /:/, $line;
	    
	    # create a new section for each image file
	    my $cursection = $doc_obj->insert_section($doc_obj->get_end_child($topsection));
	    # the page number becomes the Title
	    $doc_obj->set_utf8_metadata_element($cursection, 'Title', $pagenum);
	 
	    # process the image for this page if there is one
	    if (defined $imgname && $imgname ne "") {
		my $result1 = $self->process_image($dir.$imgname, $imgname, $doc_obj, $cursection, $rotate);
		if (!defined $result1)
		{
		    print "PagedImagePlugin: couldn't process image \"$dir$imgname\" for item \"$filename_full_path\"\n";
		}
	    }
	    # process the text file if one is there
	    if (defined $txtname && $txtname ne "") {
		my $result2 = $self->process_text ($dir.$txtname, $txtname, $doc_obj, $cursection);
               
		if (!defined $result2) {
		    print "PagedImagePlugin: couldn't process text file \"$dir.$txtname\" for item \"$filename_full_path\"\n";
		    $self->add_dummy_text($doc_obj, $cursection);
		}
	    } else {
		# otherwise add in some dummy text 
		$self->add_dummy_text($doc_obj, $cursection);
	    }
	}
    }
    
    close ITEMFILE;

    # add numpages metadata
    $doc_obj->set_utf8_metadata_element ($topsection, 'NumPages', "$num");

    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageWidth",$self->{'MaxImageWidth'});
    $doc_obj->set_utf8_metadata_element($topsection,"MaxImageHeight",$self->{'MaxImageHeight'});
    $self->{'MaxImageWidth'} = undef;
    $self->{'MaxImageHeight'} = undef;


    return $doc_obj;
}

sub process_text {
    my $self = shift (@_);
    my ($filename_full_path, $file, $doc_obj, $cursection) = @_;
    
    # check that the text file exists!!
    if (!-f $filename_full_path) {
	print "PagedImagePlugin: ERROR: File $filename_full_path does not exist, skipping\n";
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
    &ReadTextFile::read_file($self, $filename_full_path, $encoding, $language, \$text); # already decoded as utf8
    if (!length ($text)) {
	# It's a bit unusual but not out of the question to have no text, so just give a warning
        print "PagedImagePlugin: WARNING: $filename_full_path contains no text\n";
    }

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

    
    return 1;
}


sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);
    
    $self->ImageConverter::clean_up_temporary_files();
}

1;
