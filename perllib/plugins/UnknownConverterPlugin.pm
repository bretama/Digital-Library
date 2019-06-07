###########################################################################
#
# UnknownConverterPlugin.pm -- plugin that runs the provided cmdline cmd 
# to launch an custom unknown external conversion application that will
# convert from some custom unknown format to one of txt, html or xml.
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2005 New Zealand Digital Library Project
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

package UnknownConverterPlugin;

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use ConvertBinaryFile;
use UnknownPlugin;

# TO DO:
# - error messages and other display strings need to go into strings.properties
# - Have a TEMPDIR placeholder in the command, which, if present, gets replaced with the usual tempdir location
# of a collection, and in which case we have to clean up intermediate files generated in there at the end?
# Add a check that the generated file or files generated in the output dir match the convert_to option selected
# before trying to process them
# Add option that says where output comes from: stdout of the process, file that gets generated, folder.
# At present, a file or folder of files is assumed.
# Need to look in there for files with extension process_ext.
# Do we also need a html_multi option to convert_to? If supporting html_multi as output, 
# see PowerPointPlugin::read(), and revision 31764 of UnknownConverterPlugin.pm
# Then a folder of html files is generated per document? 
# OR Flag that indicates whether an html file + associated folder (such as of images) gets generated. And name of assoc folder. Such output gets generated for instance when a doc file is replaced by its html version.

sub BEGIN {
    @UnknownConverterPlugin::ISA = ('UnknownPlugin', 'ConvertBinaryFile');
}

my $convert_to_list =
    [ {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      {	'name' => "html",
	'desc' => "{ConvertBinaryFile.convert_to.html}" },
      { 'name' => "pagedimg_jpg",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_jpg}" },
      { 'name' => "pagedimg_gif",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_gif}" },
      { 'name' => "pagedimg_png",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_png}" }
      ];

my $arguments =
    [ { 'name' => "exec_cmd",
	'desc' => "{UnknownConverterPlugin.exec_cmd}",
	'type' => "string",
	'deft' => "",
	'reqd' => "yes" },
      { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $convert_to_list, 
	'deft' => "text" } ];

my $options = { 'name'     => "UnknownConverterPlugin",
		'desc'     => "{UnknownConverterPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $unknown_converter_self = new UnknownPlugin($pluginlist, $inputargs, $hashArgOptLists);
    my $cbf_self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);
    
    # Need to feed the superclass plugins to merge_inheritance() below in the order that the
    # superclass plugins were declared in the ISA listing earlier in this file:
    my $self = BaseImporter::merge_inheritance($unknown_converter_self, $cbf_self);

    $self = bless $self, $class;

my $outhandle = $self->{'outhandle'};
    if(!defined $self->{'convert_to'}) {
	$self->{'convert_to'} = "text"; # why do I have to set a value for convert_to here, when a default's already set in $convert_to_list declaration????
    }
    #print STDERR "\n\n**** convert_to is |" . $self->{'convert_to'} . "|\n\n";

    # Convert_To set up, including secondary_plugins for processing the text or html generated
    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();

    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    # using defaults for secondary plugins, taken from RTFPlugin
    push(@$specific_options, "-file_rename_method", "none");
    push(@$specific_options, "-extract_language") if $self->{'extract_language'};
    if ($secondary_plugin_name eq "TextPlugin") {
	push(@$specific_options, "-input_encoding", "utf8");
    }
    elsif ($secondary_plugin_name eq "HTMLPlugin") {
	push(@$specific_options, "-description_tags") if $self->{'description_tags'};
	push(@$specific_options, "-processing_tmp_files");
    }
    elsif ($secondary_plugin_name eq "PagedImagePlugin") {
	push(@$specific_options, "-screenviewsize", "1000");
	push(@$specific_options, "-enable_cache");
	push(@$specific_options, "-processing_tmp_files");
    }

    # bless again, copied from PDFPlugin, PowerPointPlugin
    $self = bless $self, $class;
    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);
    return $self;
}

# Called by UnknownPlugin::process()
# Overriding here to ensure that the NoText flag (metadata) and dummy text are not set,
# since, unlike UnknownPlugin, this plugin has a chance of extracting text from the unknown file format
sub add_dummy_text {
    my $self = shift(@_);
}

# Are init, begin and deinit necessary (will they not get called automatically)?
# Dr Bainbridge says it doesn't hurt for these to be explicitly defined here.
# Copied here from PDFPlugin, PowerPointPlugin
# https://stackoverflow.com/questions/42885207/why-doesnt-class-supernew-call-the-constructors-of-all-parent-classes-when
# "$class->SUPER::new always calls A::new because A comes before B in @ISA. See method resolution order in perlobj: ..."
# https://stackoverflow.com/questions/15414696/when-using-multiple-inheritance-in-perl-is-there-a-way-to-indicate-which-super-f
sub init {
    my $self = shift (@_);

    # ConvertBinaryFile init
    $self->ConvertBinaryFile::init(@_);
}

sub begin {
    my $self = shift (@_);

    $self->ConvertBinaryFile::begin(@_);

}

sub deinit {
    my $self = shift (@_);
    
    $self->ConvertBinaryFile::deinit(@_);

}

# Called by ConvertBinaryFile::tmp_area_convert_file() to do the actual conversion
# In order to call the custom conversion command, UnknownConverterPlugin needs to know the actual 
# input filename (which is the tmp_filename parameter) and the output file name, which this subroutine
# will work out. Then it will run the conversion command.
sub run_conversion_command {
    my $self = shift (@_);
    my ($tmp_dirname, $tmp_filename, $utf8_tailname, $lc_suffix, $tailname, $suffix) = @_;    
    
    my $outhandle = $self->{'outhandle'};
    my $convert_to = $self->{'convert_to'};
    my $failhandle = $self->{'failhandle'};
    my $verbosity = $self->{'verbosity'};
    
    my $convert_to_ext = $self->{'convert_to_ext'};
    if ($verbosity > 0) {
	print $outhandle "Converting $tailname$suffix to $convert_to format with extension $convert_to_ext\n";
    }

    # The command to be executed must be provided the input filename and output file/dir name
    # input filename = tmp_filename
    # 1. We now work out the output filename. Code for it comes from
    # ConvertBinaryFile::tmp_area_convert_file(), but slightly modified

    my $output_type=$self->{'convert_to'};

    # store the *actual* output type and return the output filename
    # it's possible we requested conversion to html, but only to text succeeded
    #$self->{'convert_to_ext'} = $output_type;
    if ($output_type =~ /html/i) {
	$self->{'converted_to'} = "HTML";
    } elsif ($output_type =~ /te?xt/i) {
	$self->{'converted_to'} = "Text";
    } elsif ($output_type =~ /item/i || $output_type =~ /^pagedimg/){
	$self->{'converted_to'} = "PagedImage";
    }
    
    my $output_filename = $tmp_filename;
    my $output_dirname;
    if ($output_type =~ /item/i || $output_type =~ /^pagedimg/) {
	# running under windows
	if ($ENV{'GSDLOS'} =~ /^windows$/i) {
	    $output_dirname = $tmp_dirname . "\\$utf8_tailname\\";
	} else {
	    $output_dirname = $tmp_dirname . "\/$utf8_tailname\/";
	}
	$output_filename = $output_dirname . $utf8_tailname . ".item";
    } else {
	$output_filename =~ s/$lc_suffix$/.$output_type/;
    }


    # 2. Execute the conversion command and get the type of the result,
    # making sure the converter gives us the appropriate output type

    # On Linux: if the program isn't installed, $? tends to come back with 127, in any case neither 0 nor 1.
    # On Windows: echo %ERRORLEVEL% ends up as 9009 if the program is not installed.
    # If running the command returns 0, let's assume success and so the act of running the command
    # should produce either a text file or output to stdout.

    my $plugin_name = $self->{'plugin_type'}; # inherited from BaseImporter

    my $cmd = $self->{'exec_cmd'};
    if(!$cmd) { # empty string for instance
	print $outhandle "$plugin_name Conversion error: a command to execute is required, cmd provided is |$cmd|\n";
	return "";
    }

    # replace occurrences of placeholders in cmd string
    #$cmd =~ s@\"@\\"@g;
    $cmd =~ s@%INPUT_FILE@\"$tmp_filename\"@g; # refer to the softlink
    if(defined $output_dirname) {
	$cmd =~ s@%OUTPUT@\"$output_dirname\"@g;
    } else {
	$cmd =~ s@%OUTPUT@\"$output_filename\"@g;
    }

    # Some debugging
    if ($self->{'verbosity'} > 2) {
	print STDERR "$plugin_name: executing conversion cmd \n|$cmd|\n";
	print STDERR "   on infile |$tmp_filename|\n";
	print STDERR "   to produce expected $output_filename\n";
    }

    # Run the command at last
    my $status = system($cmd);

    if($status == 127 || $status == 9009) { # means the cmd isn't recognised on Unix and Windows, respectively
	print $outhandle "$plugin_name Conversion error: cmd unrecognised, may not be installed (got $status when running $cmd)\n";
	return "";
    }

    if($status != 0) {
	print $outhandle "$plugin_name Conversion error: conversion failed with exit value $status\n";
	return "";
    }

    # remove symbolic link to original file
    &FileUtils::removeFiles($tmp_filename);


    if(defined $output_dirname && ! -d $output_dirname) {
	print $outhandle "$plugin_name Conversion error: Output directory $output_dirname doesn't exist\n";
	return "";
    }
    elsif (! -f $output_filename) {
	print $outhandle "$plugin_name Conversion error: Output file $output_filename doesn't exist\n";
	return "";
    }

    # else, conversion success
    
    # if multiple images were generated by running the conversion
    if ($self->{'convert_to'} =~ /^pagedimg/) {
	my $item_filename = $self->generate_item_file($output_filename);

	if (!-e $item_filename) {
	    print $outhandle "$plugin_name Conversion error: Item file $item_filename was not generated\n";
	    return "";
	}	
	$output_filename = $item_filename;
    }

    $self->{'output_dirname'} = $output_dirname;
    $self->{'output_filename'} = $output_filename;
    
    return $output_filename;

}


# use the read_into_doc_obj inherited from ConvertBinaryFile "to call secondary plugin stuff"
sub read_into_doc_obj {
    my $self = shift (@_);
    $self->ConvertBinaryFile::read_into_doc_obj(@_);
}

sub process {
    my $self = shift (@_);
    $self->UnknownPlugin::process(@_);
}


1;
