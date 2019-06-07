###########################################################################
#
# WordPlugin.pm -- plugin for importing Microsoft Word documents
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
package WordPlugin;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

use gsprintf 'gsprintf';

use AutoLoadConverters;
use ConvertBinaryFile;

sub BEGIN {
    @WordPlugin::ISA = ('ConvertBinaryFile', 'AutoLoadConverters');
}

my $openoffice_available = 0;

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => "&get_default_process_exp()", # delayed (see below)
	'reqd' => "no" },
      { 'name' => "description_tags",
	'desc' => "{HTMLPlugin.description_tags}",
	'type' => "flag" }
      ];


my $opt_windows_args = [ { 'name' => "windows_scripting",
			   'desc' => "{WordPlugin.windows_scripting}",
			   'type' => "flag",

			   'reqd' => "no" } ];

my $opt_office_args = [ { 'name' => "metadata_fields",
			  'desc' => "{WordPlugin.metadata_fields}",
			  'type' => "string",
			  'deft' => "Title" },
			{ 'name' => "level1_header",
			  'desc' => "{StructuredHTMLPlugin.level1_header}",
			  'type' => "regexp",
			  'reqd' => "no",
			  'deft' => "" },
			{ 'name' => "level2_header",
			  'desc' => "{StructuredHTMLPlugin.level2_header}",
			  'type' => "regexp",
			  'reqd' => "no",
			  'deft' => "" },
			{ 'name' => "level3_header",
			  'desc' => "{StructuredHTMLPlugin.level3_header}",
			  'type' => "regexp",
			  'reqd' => "no",
			  'deft' => "" },
			{ 'name' => "title_header",
			  'desc' => "{StructuredHTMLPlugin.title_header}",
			  'type' => "regexp",
			  'reqd' => "no",
			  'deft' => "" },
			{ 'name' => "delete_toc",
			  'desc' => "{StructuredHTMLPlugin.delete_toc}",
			  'type' => "flag",
			  'reqd' => "no" },
			{ 'name' => "toc_header",
			  'desc' => "{StructuredHTMLPlugin.toc_header}",
			  'type' => "regexp",
			  'reqd' => "no",
			  'deft' => "" } ];


my $options = { 'name'     => "WordPlugin",
		'desc'     => "{WordPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in Word can be replaced with GS-generated html
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

    my $office_capable = 0;
    if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
	push(@$arguments,@$opt_windows_args);
	$office_capable = 1;
    } 

    my $auto_converter_self = new AutoLoadConverters($pluginlist,$inputargs,$hashArgOptLists,["OpenOfficeConverter"],1);

   if ($auto_converter_self->{'openoffice_available'}) {
	$office_capable = 1;
	$openoffice_available = 1;
    } 

    # these office args apply to windows scripting or to openoffice conversion
    if ($office_capable) {
	push(@$arguments,@$opt_office_args);
    }
    
    # evaluate the default for process_exp  - it needs to be delayed till here so we know if openoffice is available or not. But needs to be done before parsing the args.
    foreach my $a (@$arguments) {
	if ($a->{'name'} eq "process_exp") {
	    my $eval_expr = $a->{'deft'};
	    $a->{'deft'} = eval "$eval_expr";
	    last;
	}
    }
    
    # have finished modifying our arguments, add them to ArgList
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});

    my $cbf_self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);
    my $self = BaseImporter::merge_inheritance($auto_converter_self, $cbf_self);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    $self = bless $self, $class;
    $self->{'file_type'} = "Word";

    my $outhandle = $self->{'outhandle'};

    if ($self->{'windows_scripting'}) {
	$self->{'convert_options'} = "-windows_scripting";
	$self->{'office_scripting'} = 1;
    }    
    if ($self->{'openoffice_conversion'}) {
	if ($self->{'windows_scripting'}) {
	    print $outhandle "Warning: Cannot have -windows_scripting and -openoffice_conversion\n";
	    print $outhandle "         on at the same time.  Defaulting to -windows_scripting\n";
	    $self->{'openoffice_conversion'} = 0;
	}
	else {
	    $self->{'office_scripting'} = 1;
	}
    }

    # check convert_to
    if ($self->{'convert_to'} eq "auto") {
	$self->{'convert_to'} = "html";
    }
    # windows or open office scripting, outputs structuredHTML
    if (defined $self->{'office_scripting'}) {
	$self->{'convert_to'} = "structuredhtml";
    } 

    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();
 
    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    # following title_sub removes "Page 1" and a leading
    # "1", which is often the page number at the top of the page. Bad Luck
    # if your document title actually starts with "1 " - is there a better way?
    push(@$specific_options , "-title_sub", '^(Page\s+\d+)?(\s*1\s+)?');

    my $associate_tail_re = $self->{'associate_tail_re'};
    if ((defined $associate_tail_re) && ($associate_tail_re ne "")) {
	push(@$specific_options, "-associate_tail_re", $associate_tail_re);
    }
    push(@$specific_options, "-file_rename_method", "none");

    if ($secondary_plugin_name eq "StructuredHTMLPlugin") {
	# Instruct HTMLPlugin (when eventually accessed through read_into_doc_obj)
	# to extract these metadata fields from the HEAD META fields
	push (@$specific_options, "-metadata_fields","Title,GENERATOR,date,author<Creator>");
	push (@$specific_options, "-description_tags") if $self->{'office_scripting'}; 
	push (@$specific_options, "-extract_language") if $self->{'extract_language'};
	push (@$specific_options, "-delete_toc") if $self->{'delete_toc'};
	push (@$specific_options, "-toc_header", $self->{'toc_header'}) if $self->{'toc_header'};
	push (@$specific_options, "-title_header", $self->{'title_header'}) if $self->{'title_header'};
	push (@$specific_options, "-level1_header", $self->{'level1_header'}) if $self->{'level1_header'};
	push (@$specific_options, "-level2_header", $self->{'level2_header'})if $self->{'level2_header'};
	push (@$specific_options, "-level3_header", $self->{'level3_header'}) if $self->{'level3_header'};
	push (@$specific_options, "-metadata_fields", $self->{'metadata_fields'}) if $self->{'metadata_fields'};
	push (@$specific_options, "-metadata_field_separator", $self->{'metadata_field_separator'}) if $self->{'metadata_field_separator'};
	push(@$specific_options, "-processing_tmp_files");
	
    }
	
    elsif ($secondary_plugin_name eq "HTMLPlugin") {
	push(@$specific_options, "-processing_tmp_files");
	push(@$specific_options,"-input_encoding", "utf8");
	push(@$specific_options,"-extract_language") if $self->{'extract_language'};
	push(@$specific_options, "-description_tags") if $self->{'description_tags'};
	# Instruct HTMLPlugin (when eventually accessed through read_into_doc_obj)
	# to extract these metadata fields from the HEAD META fields
	push(@$specific_options,"-metadata_fields","Title,GENERATOR,date,author<Creator>");
    }

    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);

    return $self;
}

sub get_default_process_exp {
    my $self = shift (@_);

    if ($openoffice_available) {
	return q^(?i)\.(doc|dot|docx|odt|wpd)$^;
    } elsif ($ENV{'GSDLOS'} =~ m/^windows$/i) { 
		# if OS is windows, can try using docx2html vbs script to see if they have Word 2007
		# if the user turns windows_scripting on
		return q^(?i)\.(docx?|dot)$^;
	}
    return q^(?i)\.(doc|dot)$^;
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

# Modified to cache HTML files for efficieny reasons rather
# than delete all.  HTML is modified not to use IE's VML.
# VML uses WML files, so these can be deleted.
sub cleanup_tmp_area {
    my ($self) = @_;
    if (defined $self->{'files_dir'}) {
	my $html_files_dir = $self->{'files_dir'};

	if (opendir(DIN,$html_files_dir)) {
	    my @wmz_files = grep( /\.wmz$/, readdir(DIN));
	    foreach my $f (@wmz_files) {
		my $full_f = &FileUtils::filenameConcatenate($html_files_dir,$f);
		&FileUtils::removeFiles($full_f);
	    }
	    closedir(DIN);
	}
	else {
	    # if HTML file has no supporting images, then no _files dir made
	    # => do nothing
	}
    }
}


1;

