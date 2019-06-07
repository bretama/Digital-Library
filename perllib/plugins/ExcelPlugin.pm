###########################################################################
#
# ExcelPlugin.pm -- plugin for importing Microsoft Excel files.
#  (basic version supports versions 95 and 97)
#  (through OpenOffice extension, supports all contempoary formats)
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

package ExcelPlugin;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';
use gsprintf 'gsprintf';

use AutoLoadConverters;
use ConvertBinaryFile;

sub BEGIN {
    @ExcelPlugin::ISA = ('ConvertBinaryFile', 'AutoLoadConverters');
}

my $openoffice_available = 0;

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => "&get_default_process_exp()"  # delayed (see below)
	}
      ];

my $options = { 'name'     => "ExcelPlugin",
		'desc'     => "{ExcelPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in Excel format can be replaced with GS-generated html
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

    if ($auto_converter_self->{'openoffice_available'}) {
	$openoffice_available = 1;
    } 

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
    $self->{'file_type'} = "Excel";

    my $outhandle = $self->{'outhandle'};

    # check convert_to
    if ($self->{'convert_to'} eq "auto") {
	$self->{'convert_to'} = "html";
    }

    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();

    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    push(@$specific_options,"-extract_language") if $self->{'extract_language'};
    push(@$specific_options, "-file_rename_method", "none");

    if ($secondary_plugin_name eq "HTMLPlugin") {
	push(@$specific_options, "-processing_tmp_files");
    }
    
    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);
    return $self;    
}


sub get_default_process_exp {
    my $self = shift (@_);

    if ($openoffice_available) {
	return q^(?i)\.(xls|xlsx|ods)$^;
    }

    return q^(?i)\.xls$^;
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

sub tmp_area_convert_file {

    my $self = shift (@_);
    return $self->AutoLoadConverters::tmp_area_convert_file(@_);

}
   
sub convert_post_process_old
{
    my $self = shift (@_);
    my ($conv_filename) = @_;
    
    my $outhandle=$self->{'outhandle'};
    
    my ($language, $encoding) = $self->textcat_get_language_encoding ($conv_filename);
    
    # read in file ($text will be in utf8)
    my $text = "";
    $self->read_file ($conv_filename, $encoding, $language, \$text);
    
    # turn any high bytes that aren't valid utf-8 into utf-8.
    #unicode::ensure_utf8(\$text);
    
    # Write it out again!
    #$self->utf8_write_file (\$text, $conv_filename);
}

1;
