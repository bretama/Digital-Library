###########################################################################
#
# RealMediaPlugin.pm -- Extract metadata from Real Media files
#
# Original code by Xin Gao
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005 New Zealand Digital Library Project
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

package RealMediaPlugin;


use BaseImporter;
use rm::Header::PurePerl;

use strict;
no strict 'refs'; # make an exception so we can use variables as filehandles
no strict 'subs';

sub BEGIN {
    @RealMediaPlugin::ISA = ('BaseImporter');
}


my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ];

my $options = { 'name'     => "RealMediaPlugin",
		'desc'     => "{RealMediaPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


# This plugin processes Real Media files with the suffixes ".rm" and ".rmvb"
sub get_default_process_exp
{
    return q^(?i)(\.rm|rmvb)$^;
}


sub new
{
    my ($class) = shift(@_);
    my ($pluginlist, $inputargs, $hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}}, @{$arguments}); 
    push(@{$hashArgOptLists->{"OptList"}}, $options); 

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);
    
    return bless $self, $class;
}

# we don't want to hash on the file
sub get_oid_hash_type {
    my $self = shift (@_);
    return "hash_on_ga_xml";
}

sub process
{
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    my $top_section = $doc_obj->get_top_section();

    my $text = "";
    my $real_media = rm::Header::PurePerl->new($filename_full_path);
    if (!defined $real_media || !defined $real_media->info) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "RealMediaPlugin: $filename_no_path is not a real media file\n";
	return undef;
    }
    foreach my $key (keys %{$real_media->info})
    {
	my $value = $real_media->info->{$key};
	$doc_obj->add_metadata($top_section, $key, $value);
	$text .= "$key: $value\n";
    }
    
    $doc_obj->add_utf8_text($top_section, "<pre>\n$text\n</pre>");
    $doc_obj->add_metadata($top_section, "FileFormat", "RealMedia");

    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($top_section, "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($top_section, "srclinkFile", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata($top_section, "srcicon", "_iconrmvideo_");

    # Add the actual filename as it exists on the file system (URL-encoded) as an 
    # associated file by making sure we undo any escaped URL-encoding there may be
    my $assoc_file = $doc_obj->get_assocfile_from_sourcefile(); # just url-encoded filename, no path
    $doc_obj->associate_file($filename_full_path, $assoc_file, "RealMedia", $top_section);

}

1;
