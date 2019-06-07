###########################################################################
#
# RTFPlugin.pm -- plugin for importing Rich Text Format files.
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
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

package RTFPlugin;

use ConvertBinaryFile;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @RTFPlugin::ISA = ('ConvertBinaryFile');
}

# currently only converts to HTML
my $convert_to_list =
    [ {	'name' => "html",
	'desc' => "{ConvertBinaryFile.convert_to.html}" } ];

my $arguments =
    [ { 'name' => "convert_to",
	'desc' => "{ConvertBinaryFile.convert_to}",
	'type' => "enum",
	'reqd' => "yes",
	'list' => $convert_to_list, 
	'deft' => "html" },
      { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "description_tags",
	'desc' => "{HTMLPlugin.description_tags}",
	'type' => "flag" }
];

my $options = { 'name'     => "RTFPlugin",
		'desc'     => "{RTFPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in rtf can be replaced with GS-generated html
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
 
    my $self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    $self->{'file_type'} = "RTF";

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
    if ($secondary_plugin_name eq "TextPlugin") {
	push(@$specific_options, "-input_encoding", "utf8");
    }
    elsif ($secondary_plugin_name eq "HTMLPlugin") {
	push(@$specific_options, "-description_tags") if $self->{'description_tags'};
	push(@$specific_options, "-processing_tmp_files");
    }

    $self = bless $self, $class;

    $self->load_secondary_plugins($class,$secondary_plugin_options, $hashArgOptLists);

    return $self;
}

sub get_default_process_exp {
    my $self = shift (@_);
    return q^(?i)\.rtf$^;
}

1;
