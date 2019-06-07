###########################################################################
#
# ConvertBinaryFile.pm -- plugin that facilitates conversion of binary files
# through gsConvert.pl 
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

# This plugin is inherited by such plugins as WordPlugin, PowerPointPlugin, 
# PostScriptPlugin, 
# RTFPlugin and PDFPlugin. It facilitates the conversion of these document types 
# to either HTML, Text or a series of images. It works by dynamically loading 
# an appropriate secondary plugin (HTMLPlug, StructuredHTMLPlug, 
# PagedImagePlugin or TextPlugin) based on the plugin argument 'convert_to'. 

package ConvertBinaryFile;

use AutoExtractMetadata;
use ghtml;
use HTMLPlugin;
use TextPlugin;
use PagedImagePlugin;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';
use util;
use FileUtils;


sub BEGIN {
    @ConvertBinaryFile::ISA = ('AutoExtractMetadata');
}

my $convert_to_list =
    [ {	'name' => "auto",
	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
      {	'name' => "html",
	'desc' => "{ConvertBinaryFile.convert_to.html}" },
      {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" }
      ];

my $arguments =
    [ { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $convert_to_list, 
	'deft' => "auto" },
      { 'name' => "keep_original_filename",
	'desc' => "{ConvertBinaryFile.keep_original_filename}",
	'type' => "flag" },
      { 'name' => "title_sub",
	'desc' => "{HTMLPlugin.title_sub}",
	'type' => "string", 
	#'type' => "regexp",
	'deft' => "" },
      { 'name' => "apply_fribidi",
	'desc' => "{ConvertBinaryFile.apply_fribidi}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "use_strings",
	'desc' => "{ConvertBinaryFile.use_strings}",
	'type' => "flag",
	'reqd' => "no" },
      ];

my $options = { 'name'     => "ConvertBinaryFile",
		'desc'     => "{ConvertBinaryFile.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub load_secondary_plugins
{
    my $self = shift (@_);
    my ($class,$input_args,$hashArgOptLists) = @_;

    my @convert_to_list = split(",",$self->{'convert_to_plugin'});
    my $secondary_plugins = {};
    # find the plugin

    foreach my $convert_to (@convert_to_list) {
	# load in "convert_to" plugin package
	my $plugin_class = $convert_to;
	my $plugin_package = $plugin_class.".pm";

	my $colplugname = undef;
	if (defined $ENV{'GSDLCOLLECTDIR'}) {
	    $colplugname = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},
					       "perllib","plugins", 
					       $plugin_package);
	}

	my $mainplugname = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},
					       "perllib","plugins", 
					       $plugin_package);

	if ((defined $colplugname) && (-e $colplugname)) { require $colplugname;}
	elsif (-e $mainplugname) { require $mainplugname; }
	else {
	    &gsprintf(STDERR, "{plugin.could_not_find_plugin}\n",
		      $plugin_class);
	    die "\n";
	}

	# call its constructor with extra options that we've worked out!
	my $arglist = $input_args->{$plugin_class};

	my ($secondary_plugin);
	eval("\$secondary_plugin = new $plugin_class([],\$arglist)");
	die "$@" if $@;
	$secondary_plugins->{$plugin_class} = $secondary_plugin;
    }
    $self->{'secondary_plugins'} = $secondary_plugins;
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    my $classPluginName = (defined $pluginlist->[0]) ? $pluginlist->[0] : $class;
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new AutoExtractMetadata($pluginlist, $inputargs, $hashArgOptLists);
   
    return bless $self, $class;
}

# should be called by subclasses after checking and setting 
# $self->{'convert_to'}
sub set_standard_convert_settings {
    my $self =shift (@_);
    
    my $convert_to = $self->{'convert_to'};
    if ($convert_to eq "auto") {
	$convert_to = "html";
	$self->{'convert_to'} = "html";
    }

    if ($convert_to =~ /^html/) { # may be html or html_multi
	$self->{'convert_to_plugin'} = "HTMLPlugin";
	$self->{'convert_to_ext'} = "html";
    } elsif ($convert_to eq "text") {
	$self->{'convert_to_plugin'} = "TextPlugin";
	$self->{'convert_to_ext'} = "txt";
    } elsif ($convert_to eq "structuredhtml") {
	$self->{'convert_to_plugin'} = "StructuredHTMLPlugin";
	$self->{'convert_to_ext'} = "html";
    } elsif ($convert_to =~ /^pagedimg/) {
	$self->{'convert_to_plugin'} = "PagedImagePlugin";
	my ($convert_to_ext) = $convert_to =~ /pagedimg\_(jpg|gif|png)/i;
	$convert_to_ext = 'jpg' unless defined $convert_to_ext;
	$self->{'convert_to_ext'} = $convert_to_ext;
    }
}
sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    $self->SUPER::init($verbosity,$outhandle,$failhandle);

    my $secondary_plugins =  $self->{'secondary_plugins'};

    foreach my $plug_name (keys %$secondary_plugins) {
	my $plugin = $secondary_plugins->{$plug_name};
	$plugin->init($verbosity,$outhandle,$failhandle);
    }
}

sub deinit {
    # called only once, after all plugin passes have been done

    my ($self) = @_;

    my $secondary_plugins =  $self->{'secondary_plugins'};

    foreach my $plug_name (keys %$secondary_plugins) {
	my $plugin = $secondary_plugins->{$plug_name};
	$plugin->deinit();
    }
}

sub convert_post_process
{
    # by default do no post processing
    return;
}


# Run conversion utility on the input file.  
#
# The conversion takes place in a collection specific 'tmp' directory so 
# that we don't accidentally damage the input.
#
# The desired output type is indicated by $output_ext.  This is usually
# something like "html" or "word", but can be "best" (or the empty string)
# to indicate that the conversion utility should do the best it can.
sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename, $textref) = @_;
    
    my $outhandle = $self->{'outhandle'};
    my $convert_to = $self->{'convert_to'};
    my $failhandle = $self->{'failhandle'};
    my $convert_to_ext = $self->{'convert_to_ext'};
    

    my $upgraded_input_filename = &util::upgrade_if_dos_filename($input_filename);

    # derive tmp filename from input filename
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($upgraded_input_filename, "\\.[^\\.]+\$");

    # softlink to collection tmp dir
    my $tmp_dirname = &util::get_timestamped_tmp_folder();
    if (defined $tmp_dirname) {
	$self->{'tmp_dir'} = $tmp_dirname;
    } else {
	$tmp_dirname = $dirname;
    }
    
#    # convert to utf-8 otherwise we have problems with the doc.xml file later on
#    my $utf8_tailname = (&unicode::check_is_utf8($tailname)) ? $tailname : $self->filepath_to_utf8($tailname);

    # make sure filename to be used can be stored OK in a UTF-8 compliant doc.xml file
     my $utf8_tailname = &unicode::raw_filename_to_utf8_url_encoded($tailname);


    # URLEncode this since htmls with images where the html filename is utf8 don't seem
    # to work on Windows (IE or Firefox), as browsers are looking for filesystem-encoded
    # files on the filesystem.
    $utf8_tailname = &util::rename_file($utf8_tailname, $self->{'file_rename_method'}, "without_suffix");

    my $lc_suffix = lc($suffix);
    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$utf8_tailname$lc_suffix");
    
    # If gsdl is remote, we're given relative path to input file, of the form import/utf8_tailname.suffix
    # But we can't softlink to relative paths. Therefore, we need to ensure that
    # the input_filename is the absolute path, see http://perldoc.perl.org/File/Spec.html
    my $ensure_path_absolute = 1; # true
    &FileUtils::softLink($input_filename, $tmp_filename, $ensure_path_absolute);

    my $output_filename = $self->run_conversion_command($tmp_dirname, $tmp_filename,
							$utf8_tailname, $lc_suffix, $tailname, $suffix);

    return $output_filename;
}

# The latter half of tmp_area_convert_file: runs the conversion command and returns the output file name
# Split from tmp_area_convert_file because UnknownConverterPlugin can then inherit all of 
# tmp_area_convert_file and only needs to override this part:
sub run_conversion_command {
    my $self = shift (@_);
    my ($tmp_dirname, $tmp_filename, $utf8_tailname, $lc_suffix, $tailname, $suffix) = @_;    

    my $outhandle = $self->{'outhandle'};
    my $convert_to = $self->{'convert_to'};
    my $failhandle = $self->{'failhandle'};

    my $verbosity = $self->{'verbosity'};
    if ($verbosity > 0) {
	print $outhandle "Converting $tailname$suffix to $convert_to format\n";
    }

    my $errlog = &FileUtils::filenameConcatenate($tmp_dirname, "err.log");
    
    # Execute the conversion command and get the type of the result,
    # making sure the converter gives us the appropriate output type
    my $output_type=$self->{'convert_to'};
#    if ($convert_to =~ m/PagedImage/i) {
#	$output_type = lc($convert_to)."_".lc($convert_to_ext);
#    } else {
#	$output_type = lc($convert_to);
#    }

    my $cmd = "\"".&util::get_perl_exec()."\" -S gsConvert.pl -verbose $verbosity ";
    if (defined $self->{'convert_options'}) {
	$cmd .= $self->{'convert_options'} . " ";
    }
    if ($self->{'use_strings'}) {
      $cmd .= "-use_strings ";
    }
    $cmd .= "-errlog \"$errlog\" -output $output_type \"$tmp_filename\"";
    print STDERR "calling cmd $cmd\n";
    $output_type = `$cmd`;
	
    # remove symbolic link to original file
    &FileUtils::removeFiles($tmp_filename);
    
    # Check STDERR here
    chomp $output_type;
    if ($output_type eq "fail") {
	print $outhandle "Could not convert $tailname$suffix to $convert_to format\n";
	print $failhandle "$tailname$suffix: " . ref($self) . " failed to convert to $convert_to\n";
	# The following  meant that if a conversion failed, the document would be counted twice - do we need it for anything?
	#$self->{'num_not_processed'} ++;
	if (-s "$errlog") {
	    open(ERRLOG, "$errlog");
	    while (<ERRLOG>) {
		print $outhandle "$_";
	    }
	    print $outhandle "\n";
	    close ERRLOG;
	}
	&FileUtils::removeFiles("$errlog") if (-e "$errlog");
	return "";
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
    
    my $output_filename = $tmp_filename;
    if ($output_type =~ /item/i) {
	# running under windows
	if ($ENV{'GSDLOS'} =~ /^windows$/i) {
	    $output_filename = $tmp_dirname . "\\$utf8_tailname\\" . $utf8_tailname . ".$output_type";
	} else {
	    $output_filename = $tmp_dirname . "\/$utf8_tailname\/" . $utf8_tailname . ".$output_type";
	}
    } else {
	$output_filename =~ s/$lc_suffix$/.$output_type/;
    }
    
    return $output_filename;
}


# Override BasPlug read_into_doc_obj - we need to call secondary plugin stuff
sub read_into_doc_obj {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    my $output_ext = $self->{'convert_to_ext'};
    my $conv_filename = "";
    $conv_filename = $self->tmp_area_convert_file($output_ext, $filename_full_path);
        
    if ("$conv_filename" eq "") {return -1;} # had an error, will be passed down pipeline 
    if (! -e "$conv_filename") {return -1;} 
    $self->{'conv_filename'} = $conv_filename;
    $self->convert_post_process($conv_filename);

    # Run the "fribidi" (http://fribidi.org) Unicode Bidirectional Algorithm program over the converted file
    # Added for fixing up Persian PDFs after being processed by pdftohtml, but may be useful in other cases too
    if ($self->{'apply_fribidi'} && $self->{'converted_to'} =~ /(HTML|Text)/) {
	my $fribidi_command = "fribidi \"$conv_filename\" >\"${conv_filename}.tmp\"";
	if (system($fribidi_command) != 0) {
	    print STDERR "ERROR: Cannot run fribidi on \"$conv_filename\".\n";
	}
	else {
	    &FileUtils::moveFiles("${conv_filename}.tmp", $conv_filename);
	}	
    }
	
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
## **** I just replaced $metadata with {} in following
    my ($rv,$doc_obj) 
	= $secondary_plugin->read_into_doc_obj ($pluginfo,"", $conv_filename, $block_hash, {}, $processor, $maxdocs, $total_count, $gli);

    if ((!defined $rv) || ($rv<1)) {
	# wasn't processed
	return $rv;
    }
    
    # Override previous gsdlsourcefilename set by secondary plugin
    my $collect_file = &util::filename_within_collection($filename_full_path);
    my $collect_conv_file = &util::filename_within_collection($conv_filename);
    $doc_obj->set_source_filename ($collect_file, $self->{'file_rename_method'}); 
    ## set_source_filename does not set the doc_obj source_path which is used in archives dbs for incremental
    # build. so set it manually.
    $doc_obj->set_source_path($filename_full_path);
    $doc_obj->set_converted_filename($collect_conv_file);

    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);
        
    $doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
    $doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "FileSize", (-s $filename_full_path));

    # ****
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($filename_full_path, "\\.[^\\.]+\$");
    $doc_obj->set_utf8_metadata_element($doc_obj->get_top_section(), "FilenameRoot", $tailname);

    # do plugin specific processing of doc_obj
    unless (defined ($self->process($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli))) {
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1;
    }

    my $topsection = $doc_obj->get_top_section();
    $self->add_associated_files($doc_obj, $filename_full_path);

    # extra_metadata is already called by sec plugin in process??
    $self->extra_metadata($doc_obj, $topsection, $metadata); # do we need this here??
    # do any automatic metadata extraction
    $self->auto_extract_metadata ($doc_obj);

    # have we found a Title??
    $self->title_fallback($doc_obj,$topsection,$filename_no_path);

    # force a new OID - this will use OIDtype option set for this plugin.
    $self->add_OID($doc_obj, 1);

    return (1, $doc_obj);

}

sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    return $self->process_type($base_dir, $file, $doc_obj);
}

# do plugin specific processing of doc_obj for doc_ext type
sub process_type {
    my $self = shift (@_);
    my ($base_dir, $file, $doc_obj) = @_;
    
    # need to check that not empty
    my ($doc_ext) = $file =~ /\.(\w+)$/;
    $doc_ext = lc($doc_ext);
    my $file_type = "unknown";
    $file_type = $self->{'file_type'} if defined $self->{'file_type'};
    
    # associate original file with doc object
    my $cursection = $doc_obj->get_top_section();
    my $filename = &FileUtils::filenameConcatenate($base_dir, $file);
    my $assocfilename = "doc.$doc_ext";
    if ($self->{'keep_original_filename'} == 1) {
	# this should be the same filename that was used for the Source and SourceFile metadata, 
	# as we will use SourceFile in the srclink (below)
	$assocfilename = $doc_obj->get_assocfile_from_sourcefile();
    }

    $doc_obj->associate_file($filename, $assocfilename, undef, $cursection);

    # We use set instead of add here because we only want one value
    $doc_obj->set_utf8_metadata_element($cursection, "FileFormat", $file_type);
    my $srclink_filename = "doc.$doc_ext";
    if ($self->{'keep_original_filename'} == 1) {
	$srclink_filename = $doc_obj->get_sourcefile();
    }
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_utf8_metadata ($cursection, "srcicon",  "_icon".$doc_ext."_"); 
    $doc_obj->add_utf8_metadata ($cursection, "srclink_file", $srclink_filename);
    $doc_obj->add_utf8_metadata ($cursection, "srclinkFile", $srclink_filename);
    return 1;
}

sub clean_up_after_doc_obj_processing {
     my $self = shift(@_);

     my $tmp_dir = $self->{'tmp_dir'};
     if (defined $tmp_dir && -d $tmp_dir) {
	 ##print STDERR "**** Suppressing clean up of tmp dir\n";
	 &FileUtils::removeFilesRecursive($tmp_dir);
	 $self->{'tmp_dir'} = undef;
     }
     

}

# This sub is shared across PowerPointPlugin and UnknownConverterPlugin,
# so it's been copied into here from the former.
sub generate_item_file {
    my $self = shift(@_);
    my ($input_filename) = @_;
    my $outhandle = $self->{'outhandle'};
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    my $plugin_name = $self->{'plugin_type'}; # inherited from BaseImporter

    # find all the files in the directory
    if (!opendir (DIR, $dirname)) {
	print $outhandle "$plugin_name: Couldn't read directory $dirname\n";
	return $input_filename;
    }

    my @dir = readdir (DIR);
    closedir (DIR);

    # start the item file
    my $itemfile_name = &util::filename_cat($dirname, "$tailname.item");

    # encoding specification????
    if (!open (ITEMFILE, ">$itemfile_name")) {
	print $outhandle "$plugin_name: Couldn't open $itemfile_name for writing\n";
    }
    print ITEMFILE "<GeneratedBy>$plugin_name\n";
    # print the first page
    my @sorted_dir = sort alphanum_sort @dir;
    for (my $i = 0; $i < scalar(@sorted_dir); $i++) {
	my $file = $sorted_dir[$i];
	if ($file =~ /^img(\d+)\.jpg$/) {
	    my $num = $1;
	    $self->tidy_up_html(&util::filename_cat($dirname, "text$num.html"));
	    print ITEMFILE "$num:img$num.jpg:text$num.html:\n";
	}
    }
    close ITEMFILE;
    return $itemfile_name;

}

1;







