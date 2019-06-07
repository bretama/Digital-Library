###########################################################################
#
# CONTENTdmPlugin.pm -- reasonably with-it pdf plugin
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2001 New Zealand Digital Library Project
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
package CONTENTdmPlugin;

use ConvertBinaryFile;
use ReadXMLFile;

use unicode;
use ghtml;

use strict;
no strict 'refs'; # so we can use a var for filehandles (eg STDERR)


use XMLParser;

# inherit ReadXMLFile for the apply_xslt method
sub BEGIN {
    @CONTENTdmPlugin::ISA = ('ConvertBinaryFile', 'ReadXMLFile');
}


my $convert_to_list =
    [ 
#      {	'name' => "auto",
#	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
#      {	'name' => "html",
#	'desc' => "{ConvertBinaryFile.convert_to.html}" },
#      {	'name' => "text",
#	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      { 'name' => "pagedimg",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg}"},
      ];



my $arguments = 
      [
       { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $convert_to_list, 
	'deft' => "html" },	 
      { 'name' => "xslt",
	'desc' => "{ReadXMLFile.xslt}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
       { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'deft' => &get_default_block_exp() }
];

my $options = { 'name'     => "CONTENTdmPlugin",
		'desc'     => "{CONTENTdmPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		# CONTENTdmPlugin is one of the few ConvertBinaryFile subclasses whose source doc can't be replaced by a GS-generated html
		'srcreplaceable' => "no",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@$inputargs,"-title_sub");
    push(@$inputargs,'^(Page\s+\d+)?(\s*1\s+)?');

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my @arg_array = @$inputargs;
    my $self = new ConvertBinaryFile($pluginlist,$inputargs,$hashArgOptLists);
    
    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    my $parser = new XML::Parser('Style' => 'Stream',
				 'Pkg' => 'ReadXMLFile',
				 'PluginObj' => $self,
				 'Handlers' => {'Char' => \&ReadXMLFile::Char,
						'XMLDecl' => \&ReadXMLFile::XMLDecl,
						'Entity'  => \&ReadXMLFile::Entity,
						'Doctype' => \&ReadXMLFile::Doctype,
						'Default' => \&ReadXMLFile::Default
						});  
    $self->{'parser'} = $parser;


    $self->{'rdf_desc'} = undef;
    $self->{'about_key'} = undef;
    $self->{'metadata_name'} = undef;
    $self->{'metadata_value'} = undef;

    # do we only allow one option??
    $self->{'convert_to'} = "pagedimg";
    $self->{'convert_to_plugin'} = "PagedImagePlugin";
    $self->{'convert_to_ext'} = "jpg";
    
    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    push(@$specific_options, "-title_sub", '^(Page\s+\d+)?(\s*1\s+)?');
    push(@$specific_options, "-create_thumbnail", "true", "-create_screenview", "true");
    push(@$specific_options, "-file_rename_method", "none");
    push(@$specific_options, "-processing_tmp_files");

#    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

#    if (!defined $secondary_plugin_options->{'PagedImagePlugin'}){
#	$secondary_plugin_options->{'PagedImagePlugin'} = [];
#    }
#    my $pagedimg_options = $secondary_plugin_options->{'PagedImagePlugin'}; 
#    push(@$pagedimg_options, "-title_sub", '^(Page\s+\d+)?(\s*1\s+)?');
#    push(@$pagedimg_options, "-create_thumbnail", "true", "-create_screenview", "true");
#    push(@$pagedimg_options, "-file_rename_method", "none");
#    push(@$pagedimg_options, "-processing_tmp_files");
    $self = bless $self, $class;
    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);
    return $self;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.rdf$^;
}

sub get_default_block_exp {
    return q^(?i)\.(jpg|jpeg|gif)$^;
}



sub rdf_desc_to_id
{
    my $self = shift (@_);
    my ($rdf_desc) = @_;

    my $rdf_id = {};

    # initialise any .cpd (=complex multi page) structures 

    foreach my $about_key (keys %{$rdf_desc}) {
	if ($about_key =~ m/\.cpd$/) {
	    my $about = $rdf_desc->{$about_key};
	    my $id    = $about->{'dc:identifier'};

	    if ($id =~ m/^\s*$/) {
		# missing id, make one up based on about attribute

		my ($tailname, $dirname, $suffix)
		    = &File::Basename::fileparse($about_key, "\\.[^\\.]+\$");

		$id = "about:$tailname";
	    }

	    $rdf_id->{$id} = $about;
	    $rdf_id->{$id}->{'ex:filename'} = $about_key;
	    $rdf_id->{$id}->{'ex:type'} = "complex";
	    $rdf_id->{$id}->{'pages'} = [];
	}

    }

    # now add in *non* .cpd items

    foreach my $about_key (keys %{$rdf_desc}) {
	if ($about_key !~ m/\.cpd$/) {
	    my $about = $rdf_desc->{$about_key};	    
	    my $id    = $about->{'dc:identifier'};


	    if ($id =~ m/^\s*$/) {
		# missing id, make one up based on about attribute

		my ($tailname, $dirname, $suffix)
		    = &File::Basename::fileparse($about_key, "\\.[^\\.]+\$");

		$id = "about:$tailname";
	    }

	    if (defined $rdf_id->{$id}) {
		$about->{'ex:filename'} = $about_key;

		# dealing with complex multi-page situation
		# Add to existing structure

		my $pages = $rdf_id->{$id}->{'pages'};
		push(@$pages,$about)
	    }
	    else {
		# New entry

		$rdf_id->{$id} = $about;
		$rdf_id->{$id}->{'ex:type'} = "simple";	    
		$rdf_id->{$id}->{'ex:filename'} = $about_key;
	    }
	}
	
    }

    return $rdf_id;
}


sub metadata_table_txt_file
{
    my $self = shift (@_);
    my ($output_root,$page_num) = @_;

    my $txt_filename = $output_root."_page_$page_num.txt";

    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($txt_filename, "\\.[^\\.]+\$");

    my $txt_file = "$tailname$suffix";

    return $txt_file;
}


sub output_metadata_table 
{
    my $self = shift (@_);
    my ($page,$page_num,$tmp_dirname,$txt_file) = @_;
    
    my $txt_filename = &FileUtils::filenameConcatenate($tmp_dirname,$txt_file);

    open(TOUT,">$txt_filename") 
	|| die "Error: unable to write metadata data out as txt file $txt_filename: $!\n";
    
    print TOUT $page->{'MetadataTable'};
    delete $page->{'MetadataTable'};

    close (TOUT);
}


sub rdf_id_to_item_file
{
    my $self = shift (@_);
    my ($rdf_id,$tmp_dirname,$output_root) = @_;

    my $item_file_list = [];
    
    foreach my $id (keys %{$rdf_id}) {

	my $id_safe = $id;
	$id_safe =~ s/ /-/g;

	my $output_filename = $output_root."_$id_safe.item";
	open(FOUT,">$output_filename") 
	    || die "Unable to open $output_filename: $!\n";
	

	print FOUT "<PagedDocument>\n";

	my $rdf_doc = $rdf_id->{$id};
	foreach my $metadata_name (keys %$rdf_doc) {


	    next if ($metadata_name eq "pages");

	    my $metadata_value = $rdf_doc->{$metadata_name};

	    # convert ns:name to ns.Name
	    $metadata_name =~ s/^(.*?):(.*)/$1\.\u$2/; 

	    print FOUT "  <Metadata name=\"$metadata_name\">$metadata_value</Metadata>\n";
	}

	if ($rdf_doc->{'ex:type'} eq "complex") {
	    my $pages = $rdf_doc->{'pages'};
	    my $page_num = 1;

	    foreach my $page (@$pages) {

		my $imgfile = $page->{'ex:filename'};
		if ($imgfile =~ m/(http|ftp):/) {
		    $imgfile = "empty.jpg";
		}
		else {
		    $imgfile = &FileUtils::filenameConcatenate("..","import",$imgfile);
		}
		
		my $txt_file 
		    = $self->metadata_table_txt_file($output_root,$page_num);

		$self->output_metadata_table($page,$page_num,
					     $tmp_dirname,$txt_file);


		print FOUT "  <Page pagenum=\"$page_num\" imgfile=\"$imgfile\" txtfile=\"$txt_file\">\n";

		foreach my $metadata_name (keys %$page) {
		
		    my $metadata_value = $rdf_doc->{$metadata_name};
		    # convert ns:name to ns.Name
		    $metadata_name =~ s/^(.*?):(.*)/$1\.\u$2/; 

		    print FOUT "  <Metadata name=\"$metadata_name\">$metadata_value</Metadata>\n";
		}
		

		$page_num++;


		print FOUT "  </Page>\n";
	    }
	}
	else {
	    # simple
	    # duplicate top-level metadata for now plus image to bind to

	    my $imgfile = $rdf_doc->{'ex:filename'};
	    if ($imgfile =~ m/(http|ftp):/) {
		$imgfile = "empty.jpg";
	    }
	    else {
		$imgfile = &FileUtils::filenameConcatenate("..","import",$imgfile);
	    }


	    my $txt_file = $self->metadata_table_txt_file($output_root,1);
	    $self->output_metadata_table($rdf_doc,1,$tmp_dirname,$txt_file);

	    print FOUT "  <Page pagenum=\"1\" imgfile=\"$imgfile\" txtfile=\"$txt_file\">\n";	    
	    foreach my $metadata_name (keys %$rdf_doc) {

		my $metadata_value = $rdf_doc->{$metadata_name};
		
		# convert ns:name to ns.Name
		$metadata_name =~ s/^(.*?):(.*)/$1\.\u$2/; 

		print FOUT "  <Metadata name=\"$metadata_name\">$metadata_value</Metadata>\n";
	    }
	    print FOUT "  </Page>\n";

	}

	print FOUT "</PagedDocument>\n";
	close(FOUT);

	push(@$item_file_list,$output_filename);

    }
    

    return $item_file_list;
}



sub xml_area_convert_file
{
    my $self = shift (@_);
    my ($input_filename, $tmp_dirname, $output_root) = @_;

    eval {
	# Build up hash table/tree of all records

	my $xslt = $self->{'xslt'};
	if (defined $xslt && ($xslt ne "")) {
	    # perform xslt
	    my $transformed_xml = $self->apply_xslt($xslt,$input_filename);

	    open(TOUT,">/tmp/tout.xml") 
		|| die "Unable to open /tmp/tout.xml: $!\n";
	    print TOUT $transformed_xml;
	    close(TOUT);


	    # feed transformed file (now in memory as string) into XML parser
	    $self->{'parser'}->parse($transformed_xml);
	}
	else {
	    $self->{'parser'}->parsefile($input_filename);
	}
    };
  
    if ($@) {

	# parsefile may either croak somewhere in XML::Parser (e.g. because
	# the document is not well formed) or die somewhere in XMLPlug or a
	# derived plugin (e.g. because we're attempting to process a
	# document whose DOCTYPE is not meant for this plugin). For the
	# first case we'll print a warning and continue, for the second
	# we'll just continue quietly

	print STDERR "**** Error is: $@\n";

	my $file = $self->{'file'};

	my ($msg) = $@ =~ /Carp::croak\(\'(.*?)\'\)/;
	if (defined $msg) {	
	    my $outhandle = $self->{'outhandle'};
	    my $plugin_name = ref ($self);
	    print $outhandle "$plugin_name failed to process $file ($msg)\n";
	}

	my $gli = $self->{'gli'};

	# reset ourself for the next document
	$self->{'section_level'}=0;
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return ("fail",undef); # error during processing
    }

    my $rdf_desc = $self->{'rdf_desc'};    

#    foreach my $about_key (keys %{$rdf_desc}) {
#	my $about = $rdf_desc->{$about_key};
#	foreach my $metadata_name (keys %{$about}) {
#
#	    my $metadata_value = $about->{$metadata_name};
##	    print STDERR " $metadata_name: $metadata_value\n";
#	}
#    }


    # Merge entries with same name


    my $merged_rdf_id = $self->rdf_desc_to_id($rdf_desc);

#    foreach my $about_key (keys %{$merged_rdf_id}) {
#	my $about = $merged_rdf_id->{$about_key};
#	foreach my $metadata_name (keys %{$about}) {
#
#	    my $metadata_value = $about->{$metadata_name};
##	    print STDERR " $metadata_name: $metadata_value\n";
#	}
#    }



    my $item_files = $self->rdf_id_to_item_file($merged_rdf_id,$tmp_dirname, 
						$output_root);

    return ("item",$item_files);
}


# Override ConvertBinaryFile tmp_area_convert_file() to provide solution specific 
# to CONTENTdm
#
# A better (i.e. in the future) solution would be to see if this can be
# shifted into gsConvert.pl so there is no need to override the
# default tmp_area_convert_file()


sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename, $textref) = @_;

    # is textref ever used?!?

    my $outhandle = $self->{'outhandle'};
    my $convert_to = $self->{'convert_to'};
    my $failhandle = $self->{'failhandle'};
    my $convert_to_ext = $self->{'convert_to_ext'};
    
    # softlink to collection tmp dir
    my $tmp_dirname 
	= &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);

    # derive tmp filename from input filename
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    # Remove any white space from filename -- no risk of name collision, and
    # makes later conversion by utils simpler. Leave spaces in path...
    # tidy up the filename with space, dot, hyphen between
    $tailname =~ s/\s+//g; 
    $tailname =~ s/\.+//g;
    $tailname =~ s/\-+//g;

    $tailname = $self->SUPER::filepath_to_utf8($tailname) unless &unicode::check_is_utf8($tailname);
    $suffix = lc($suffix);
    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix");

    &FileUtils::softLink($input_filename, $tmp_filename);
    my $verbosity = $self->{'verbosity'};
    if ($verbosity > 0) {
	print $outhandle "Converting $tailname$suffix to $convert_to format\n";
    }

    my $errlog = &FileUtils::filenameConcatenate($tmp_dirname, "err.log");
    
    # call xml_area_convert_file rather than gsConvert.pl

    my $output_root = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname");

    my ($output_type,$item_files) 
	= $self->xml_area_convert_file($tmp_filename,$tmp_dirname,$output_root);


    my $fakeimg_filename = &FileUtils::filenameConcatenate($dirname, "empty.jpg");
    my $fakeimg_tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "empty.jpg");

    print STDERR "***** No source image identified with item\n";

    print STDERR "***** Using default \"no image available\" $fakeimg_filename -> $fakeimg_tmp_filename\n";

    &FileUtils::softLink($fakeimg_filename, $fakeimg_tmp_filename);
   
    # continue as before ...

    # remove symbolic link to original file
    &FileUtils::removeFiles($tmp_filename);

    # Check STDERR here
    chomp $output_type;
    if ($output_type eq "fail") {
	print $outhandle "Could not convert $tailname$suffix to $convert_to format\n";
	print $failhandle "$tailname$suffix: " . ref($self) . " failed to convert to $convert_to\n";
	$self->{'num_not_processed'} ++;
	if (-s "$errlog") {
	    open(ERRLOG, "$errlog");
	    while (<ERRLOG>) {
		print $outhandle "$_";
	    }
	    print $outhandle "\n";
	    close ERRLOG;
	}
	&FileUtils::removeFiles("$errlog") if (-e "$errlog");
	return [];
    }

    # store the *actual* output type and return the output filename
    # it's possible we requested conversion to html, but only to text succeeded
    #$self->{'convert_to_ext'} = $output_type;
    if ($output_type =~ /html/i) {
	$self->{'converted_to'} = "HTML";
    } elsif ($output_type =~ /te?xt/i) {
	$self->{'converted_to'} = "Text";
    } elsif ($output_type =~ /item/i){
	$self->{'converted_to'} = "PagedImage";
    }

    
    return $item_files;
}




# Override ConvertBinaryFile (ie BaseImporter) read
# Needed so multiple .item files generated are sent down secondary plugin 
# and the resulting doc_objs all processed.

sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;


    $self->{'gli'} = $gli;
    $self->{'file'} = $file;

    my $successful_rv = -1;

    my $outhandle = $self->{'outhandle'};
    
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up

    # read() deviates at this point from ConvertBinaryFile
    # Need to work with list of filename returned

    my $output_ext = $self->{'convert_to_ext'};
    my $conv_filename_list = [];

    $conv_filename_list = $self->tmp_area_convert_file($output_ext, $filename_full_path);

    if (scalar(@$conv_filename_list)==0) {
	return -1;
    } # had an error, will be passed down pipeline 

    foreach my $conv_filename ( @$conv_filename_list ) {
	if (! -e "$conv_filename") {return -1;} 
	$self->{'conv_filename'} = $conv_filename; # is this used anywhere?
	$self->convert_post_process($conv_filename);
    
	my $secondary_plugins =  $self->{'secondary_plugins'};
	my $num_secondary_plugins = scalar(keys %$secondary_plugins);

	if ($num_secondary_plugins == 0) {
	    print $outhandle "Warning: No secondary plugin to use in conversion.  Skipping $file\n";
	    return 0; # effectively block it
	}

	my @plugin_names = keys %$secondary_plugins;
	my $plugin_name = shift @plugin_names;
	
	if ($num_secondary_plugins > 1) {
	    print $outhandle "Warning: Multiple secondary plugins not supported yet!  Choosing $plugin_name\n.";
	}
	
	my $secondary_plugin = $secondary_plugins->{$plugin_name};

	# note: metadata is not carried on to the next level
	my ($rv,$doc_obj) 
	    = $secondary_plugin->read_into_doc_obj ($pluginfo,"", $conv_filename, 
						    $block_hash, $metadata, $processor, $maxdocs, $total_count,
						    $gli);

	print STDERR "**** $conv_filename => returned rv = $rv\n";

	if ((defined $rv) && ($rv>=0)) {
	    $successful_rv = 1;
	}

	# Override previous gsdlsourcefilename set by secondary plugin
	my $collect_file = &util::filename_within_collection($filename_full_path);
	my $collect_conv_file = &util::filename_within_collection($conv_filename);
	$doc_obj->set_source_filename ($collect_file, $self->{'file_rename_method'}); 
	$doc_obj->set_converted_filename($collect_conv_file);
	
	my ($filemeta) = $file =~ /([^\\\/]+)$/;
	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);
	$doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
	$doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "FileSize", (-s $filename_full_path));
	
	if ($self->{'cover_image'}) {
	    $self->associate_cover_image($doc_obj, $filename_full_path);
	}
	
	# do plugin specific processing of doc_obj
	unless (defined ($self->process(undef, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli))) {
	    print STDERR "***** process returned undef: $base_dir $file\n";
	    print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	    return -1;
	}
	# do any automatic metadata extraction
	$self->auto_extract_metadata ($doc_obj);

	# have we found a Title??
	$self->title_fallback($doc_obj,$doc_obj->get_top_section(),$filemeta);

	# add an OID
	$self->add_OID($doc_obj);
	# process the document
	$processor->process($doc_obj);

	$self->{'num_processed'} ++;
    }

    return $successful_rv;
}

sub process {

    return 1;
}

# do we need this? sec pluginn process would have already been called as part of read_into_doc_obj??
sub process_old {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    
    my $secondary_plugins =  $self->{'secondary_plugins'};
    my @plugin_names = keys %$secondary_plugins;
    my $plugin_name = shift @plugin_names; # already checked there is only one
	
    my $secondary_plugin = $secondary_plugins->{$plugin_name};
	
    my $result = $secondary_plugin->process(@_);

    return $result;
}


# Called at the beginning of the XML document.
sub xml_start_document {
    my $self = shift(@_);
    my ($expat) = @_;

    $self->{'rdf_desc'} = {};
}


# Called for DOCTYPE declarations - use die to bail out if this doctype
# is not meant for this plugin
sub xml_doctype {
    my $self = shift(@_);
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    die "" if ($name !~ /^rdf:RDF$/);

    my $outhandle = $self->{'outhandle'};
    print $outhandle "CONTENTdmPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;

}

# Called for every start tag. The $_ variable will contain a copy of the
# tag and the %_ variable will contain the element's attributes.
sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    if ($element eq "rdf:Description") {

	my $about_key = $_{'about'};

	my $rdf_desc = $self->{'rdf_desc'};
	$rdf_desc->{$about_key} = {};

	$self->{'about_key'}  = $about_key;
	$self->{'index_text'} = "";
	$self->{'pp_text'}    = "<table width=\"100%\">\n";


    }
    elsif (defined $self->{'about_key'}) {	
	$self->{'metadata_name'} = $element;
	$self->{'metadata_value'} = "";
    }

}

# Called for every end tag. The $_ variable will contain a copy of the tag.
sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    if ($element eq "rdf:Description") {
	$self->{'pp_text'} .= "</table>\n";
	## ghtml::htmlsafe($self->{'pp_text'});


	my $about_key = $self->{'about_key'};
	my $about = $self->{'rdf_desc'}->{$about_key};
	$about->{'IndexText'}     = $self->{'index_text'};
	$about->{'MetadataTable'} = $self->{'pp_text'};


	$self->{'about_key'}   = undef;
	$self->{'index_text'}  = undef;
	$self->{'pp_text'}     = undef;

    }
    elsif (defined $self->{'metadata_name'}) {
	my $metadata_name = $self->{'metadata_name'};
	if ($element eq $metadata_name) {
	    my $metadata_value = $self->{'metadata_value'};

	    my $about_key = $self->{'about_key'};
	    my $about = $self->{'rdf_desc'}->{$about_key};
	    $about->{$metadata_name} = $metadata_value;

	    $self->{'index_text'} .= "$metadata_value\n";
	    $self->{'pp_text'} .= "  <tr><td>$metadata_name</td><td>$metadata_value</td></tr>\n";

	    $self->{'metadata_name'}  = undef;
	    $self->{'metadata_value'} = undef;
	}
    }
}

# Called just before start or end tags with accumulated non-markup text in
# the $_ variable.
sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;

    if (defined $self->{'metadata_name'}) {
	$self->{'metadata_value'} .= $_;
    }
}

# Called at the end of the XML document.
sub xml_end_document {
    my $self = shift(@_);
    my ($expat) = @_;
}


1;
