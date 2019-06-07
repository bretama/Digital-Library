###########################################################################
#
# PowerPointPlugin.pm -- plugin for importing Microsoft PowerPoint files.
#  (basic version supports versions 95 and 97)
#  (through OpenOffice extension, supports all contemporary formats)
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2002 New Zealand Digital Library Project
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

package PowerPointPlugin;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

use gsprintf 'gsprintf';

use AutoLoadConverters;
use ConvertBinaryFile;

sub BEGIN {
    @PowerPointPlugin::ISA = ('ConvertBinaryFile', 'AutoLoadConverters');
}

my $openoffice_available = 0;

my $windows_convert_to_list =
    [ {	'name' => "auto",
	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
      {	'name' => "html",
	'desc' => "{ConvertBinaryFile.convert_to.html}" },
      {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      { 'name' => "pagedimg_jpg",
	'desc' => "{PowerPointPlugin.convert_to.pagedimg_jpg}" },
      { 'name' => "pagedimg_gif",
	'desc' => "{PowerPointPlugin.convert_to.pagedimg_gif}" },
      { 'name' => "pagedimg_png",
	'desc' => "{PowerPointPlugin.convert_to.pagedimg_png}" }
      ];

my $openoffice_convert_to_list = 
    [ {	'name' => "auto",
	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
      {	'name' => "html_multi",
	'desc' => "{PowerPointPlugin.convert_to.html_multi}" },
      {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      { 'name' => "pagedimg",
	'desc' => "{PowerPointPlugin.convert_to.pagedimg}" }
      ];

my $openoffice_extra_convert_to_list = 
    [ {	'name' => "html_multi",
	'desc' => "{PowerPointPlugin.convert_to.html_multi}" },
      { 'name' => "pagedimg",
	'desc' => "{PowerPointPlugin.convert_to.pagedimg}" }
      ];

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => "&get_default_process_exp()",  # delayed (see below)
	}
      ];

my $opt_windows_args = 
    [ { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $windows_convert_to_list, 
	'deft' => "html" },
      { 'name' => "windows_scripting",
	'desc' => "{PowerPointPlugin.windows_scripting}",
	'type' => "flag",
	'reqd' => "no" }
      ];

my $opt_office_args = 
    [ { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $openoffice_convert_to_list, 
	'deft' => "html" }
      ];

my $options = { 'name'     => "PowerPointPlugin",
		'desc'     => "{PowerPointPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in PPT format can be replaced with GS-generated html
	        'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    # this bit needs to happen later after the arguments array has been 
    # finished - used for parsing the input args.
    # push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    # this one needs to go in first, to get the print info in the right order
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $auto_converter_self = new AutoLoadConverters($pluginlist,$inputargs,$hashArgOptLists,["OpenOfficeConverter"],1);

    if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
 	if ($auto_converter_self->{'openoffice_available'}) {
	    # add openoffice convert_to options into list
	    push (@$windows_convert_to_list, @$openoffice_extra_convert_to_list);
	    $openoffice_available = 1;
	}
	push(@$arguments,@$opt_windows_args);
    }
    elsif ($auto_converter_self->{'openoffice_available'}) {
	push (@$arguments,@$opt_office_args);
	$openoffice_available = 1;
    }
    # TODO need to do the case where they are both enabled!!! what will the convert to list be???

    # evaluate the default for process_exp  - it needs to be delayed till here so we know if openoffice is available or not. But needs to be done before parsing the args.
    foreach my $a (@$arguments) {
	if ($a->{'name'} eq "process_exp") {
	    my $eval_expr = $a->{'deft'};
	    $a->{'deft'} = eval "$eval_expr";
	    last;
	}
    }

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});

    my $cbf_self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);
    my $self = BaseImporter::merge_inheritance($auto_converter_self, $cbf_self);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    $self = bless $self, $class;
    $self->{'file_type'} = "PPT";

    if ($self->{'convert_to'} eq "auto") {
	if ($self->{'windows_scripting'}) {
	    $self->{'convert_to'} = "pagedimg_jpg";
	}
	else {
	    $self->{'convert_to'} = "html";
	}
    }

   my $outhandle = $self->{'outhandle'};

    # can't have windows_scripting and openoffice_conversion at the same time
    if ($self->{'windows_scripting'} && $self->{'openoffice_conversion'}) {
	print $outhandle "Warning: Cannot have -windows_scripting and -openoffice_conversion\n";
	print $outhandle "         on at the same time.  Defaulting to -windows_scripting\n";
	$self->{'openoffice_conversion'} = 0;
    }
    
    #these are passed through to gsConvert.pl by ConvertBinaryFile.pm
    $self->{'convert_options'} = "-windows_scripting" if $self->{'windows_scripting'};

    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();

    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    push(@$specific_options, "-file_rename_method", "none");
    push(@$specific_options, "-extract_language") if $self->{'extract_language'};

    if ($secondary_plugin_name eq "HTMLPlugin") {
	push(@$specific_options, "-processing_tmp_files");
	push(@$specific_options,"-metadata_fields","Title,GENERATOR,date,author<Creator>");
    }
    elsif ($secondary_plugin_name eq "PagedImagePlugin") {
	push(@$specific_options, "-processing_tmp_files");
	#is this true??
	push(@$specific_options,"-input_encoding", "utf8");
	if ($self->{'openoffice_conversion'}) {
	    push(@$specific_options, "-create_thumbnail", "false", "-create_screenview", "false");
	}
    }

    $self = bless $self, $class;

    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);
    return $self;
}

sub get_default_process_exp {
    my $self = shift (@_);

    if ($openoffice_available) {
	return q^(?i)\.(ppt|pptx|odp)$^;
    }

    return q^(?i)\.ppt$^;
}

sub init {
    my $self = shift (@_);

    # ConvertBinaryFile init
    $self->SUPER::init(@_);
    $self->AutoLoadConverters::init(@_);

}

sub begin {
    my $self = shift (@_);

    $self->AutoLoadConverters::begin(@_);
    $self->SUPER::begin(@_);

}

sub deinit {
    my $self = shift (@_);
    
    $self->AutoLoadConverters::deinit(@_);
    $self->SUPER::deinit(@_);

}

# override AutoLoadConverters version, as we need to do more stuff once its converted if we are converting to item file
sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename, $textref) = @_;

    if ($self->{'openoffice_conversion'}) {
	if ($self->{'convert_to'} eq "pagedimg") {
	    $output_ext = "html"; # first convert to html
	}
	my ($result, $result_str, $new_filename) = $self->OpenOfficeConverter::convert($input_filename, $output_ext);
	if ($result == 0) {
	    my $outhandle=$self->{'outhandle'};
	    print $outhandle "OpenOfficeConverter Conversion error\n";
	    print $outhandle $result_str;
	    return "";

	}
	#print STDERR "result = $result\n";
	if ($self->{'convert_to'} eq "pagedimg") {
	    my $item_filename = $self->generate_item_file($new_filename);
	    return $item_filename;
	}
	return $new_filename;

    }
    else {
	return $self->ConvertBinaryFile::tmp_area_convert_file(@_);
    }
    # get tmp filename
}

# override default read in some situations, as the conversion of ppt to html results in many files, and we want them all to be processed.
sub read {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    return undef unless $self->can_process_this_file($filename_full_path);
    
    # we are only doing something special for html_multi
    if (!($self->{'openoffice_conversion'} && $self->{'convert_to'} eq "html_multi")) {
	return $self->BaseImporter::read(@_);
    }
    my $outhandle = $self->{'outhandle'};
    print STDERR "<Processing n='$file' p='$self->{'plugin_type'}'>\n" if ($gli);
    print $outhandle "$self->{'plugin_type'} processing $file\n"
	    if $self->{'verbosity'} > 1;

    my $conv_filename = $self->tmp_area_convert_file("html", $filename_full_path);
    if ("$conv_filename" eq "") {return -1;} # had an error, will be passed down pipeline 
    if (! -e "$conv_filename") {return -1;} 

    my ($tailname, $html_dirname, $suffix)
	= &File::Basename::fileparse($conv_filename, "\\.[^\\.]+\$");

    my $collect_file = &util::filename_within_collection($filename_full_path);
    my $dirname_within_collection = &util::filename_within_collection($html_dirname);
    my $secondary_plugin = $self->{'secondary_plugins'}->{"HTMLPlugin"};

    my @dir;
    if (!opendir (DIR, $html_dirname)) {
	print $outhandle "PowerPointPlugin: Couldn't read directory $html_dirname\n";
	# just process the original file
	@dir = ("$tailname.$suffix");
	
    } else {
	@dir = readdir (DIR);
	closedir (DIR);
    }

    foreach my $file (@dir) {
	next unless $file =~ /\.html$/;
	
	my ($rv, $doc_obj) = 
	    $secondary_plugin->read_into_doc_obj ($pluginfo,"", &util::filename_cat($html_dirname,$file), $block_hash, {}, $processor, $maxdocs, $total_count, $gli);
	if ((!defined $rv) || ($rv<1)) {
	    # wasn't processed
	    return $rv;
	}

	# next block copied from ConvertBinaryFile
	# from here ...
	# Override previous gsdlsourcefilename set by secondary plugin
	
	$doc_obj->set_source_filename ($collect_file, $self->{'file_rename_method'}); 
	## set_source_filename does not set the doc_obj source_path which is used in archives dbs for incremental
	# build. so set it manually.
	$doc_obj->set_source_path($filename_full_path);
	$doc_obj->set_converted_filename(&util::filename_cat($dirname_within_collection, $file));
	
	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename_full_path,$filename_encoding);
        
	$doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
	$doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "FileSize", (-s $filename_full_path));

	
	my ($tailname, $dirname, $suffix)
	    = &File::Basename::fileparse($filename_full_path, "\\.[^\\.]+\$");
	$doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "FilenameRoot", $tailname);
	

	my $topsection = $doc_obj->get_top_section();
	$self->add_associated_files($doc_obj, $filename_full_path);
	
	# extra_metadata is already called by sec plugin in process??
	$self->extra_metadata($doc_obj, $topsection, $metadata); # do we need this here??
	# do any automatic metadata extraction
	$self->auto_extract_metadata ($doc_obj);
	
	# have we found a Title??
	$self->title_fallback($doc_obj,$topsection,$filename_no_path);
	
	# use the one generated by HTMLPlugin, otherwise they all end up with same id.
	#$self->add_OID($doc_obj);
	# to here...

	# process it
	$processor->process($doc_obj);
	undef $doc_obj;
    }
    $self->{'num_processed'} ++;

#    my ($process_status,$doc_obj) = $self->read_into_doc_obj(@_);
    
#    if ((defined $process_status) && ($process_status == 1)) {
	
	# process the document
#	$processor->process($doc_obj);

#	$self->{'num_processed'} ++;
#	undef $doc_obj; 
#    }
    # delete any temp files that we may have created
    $self->clean_up_after_doc_obj_processing();


    # if process_status == 1, then the file has been processed.
    return 1;

}

# want to sort img1, img2, ...img10, img11 etc.
sub alphanum_sort {
    
    my ($a_txt, $a_num) = $a =~ /^([^\d]*)(\d*)/;
    my ($b_txt, $b_num) = $b =~ /^([^\d]*)(\d*)/;
    
    if ($a_txt ne $b_txt) { return ($a cmp $b) };
    return ($a_num <=> $b_num);
}

# Want to remove the line that links to first page, last page, next page, text etc.
sub tidy_up_html {

    my $self = shift(@_);
    my ($filename) = @_;
    return unless (-f $filename);
    my $backup_filename = "$filename.bak";

    &File::Copy::copy($filename, $backup_filename);

    open (ORIGINAL, $backup_filename) || return;
    open(HTMLFILE, ">$filename") || return;

    my $line ="";
    while ($line = <ORIGINAL>) {
	if ($line =~ /\<body\>/) {
	    print HTMLFILE $line;
	    $line = <ORIGINAL>;
	    next if $line =~ /\<center\>/;
	}
	next if $line =~ /First page/;
	print HTMLFILE ($line);
    }

    close HTMLFILE;
    close ORIGINAL;
}
1;

