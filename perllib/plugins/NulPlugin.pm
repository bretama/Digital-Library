###########################################################################
#
# NulPlugin.pm -- Plugin for dummy (.nul) files
#
# A component of the Greenstone digital library software from the New
# Zealand Digital Library Project at the University of Waikato, New
# Zealand.
#
# Copyright (C) 2005 Katherine Don
# Copyright (C) 2005 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

# NulPlugin - a plugin for dummy files

# This is a simple Plugin for importing dummy files, along with
# their metadata.  A fictional document will
# be created for every such file, and the metadata added to it.

# This is used mainly for the null files resulting from exploding metadata
# databases

package NulPlugin;

use BaseImporter;
use MetadataRead;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @NulPlugin::ISA = ('MetadataRead', 'BaseImporter');
}

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "assoc_field",
	'desc' => "{NulPlugin.assoc_field}",
	'type' => "string",
	'deft' => "null_file",
	'reqd' => "no" },
      { 'name' => "add_metadata_as_text",
	'desc' => "{NulPlugin.add_metadata_as_text}",
	'type' => "flag" },
      { 'name' => "remove_namespace_for_text",
	'desc' => "{NulPlugin.remove_namespace_for_text}",
	'type' => "flag" }
      ];

my $options = { 'name'     => "NulPlugin",
		'desc'     => "{NulPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
                 'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);
    
    return bless $self, $class;
}

sub get_default_process_exp {
    return '(?i)\.nul$';
}

# NulPlugin specific processing of doc_obj. 
sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    
    my $topsection = $doc_obj->get_top_section();
       
    my $assoc_field = $self->{'assoc_field'}; # || "null_file"; TODO, check this
    $doc_obj->add_metadata ($topsection, $assoc_field, $file);

    # format the metadata passed in (presumably from metadata.xml)
    my $text = "";
    if ($self->{'add_metadata_as_text'}) {
	$text = &metadatautil::format_metadata_as_table($metadata, $self->{'remove_namespace_for_text'});
	$doc_obj->add_utf8_text($topsection, $text);
    } else {
	$self->add_dummy_text($doc_obj, $topsection);
    }
    
    return 1;
}


1;











