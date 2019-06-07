###########################################################################
#
# OggVorbisPlug.pm -- A plugin for Ogg Vorbis audio files
#
# Original code by Christy Kuo
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 1999-2004 New Zealand Digital Library Project
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

package OggVorbisPlugin;


use BaseImporter;
use Ogg::Vorbis::Header::PurePerl;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

sub BEGIN {
    @OggVorbisPlugin::ISA = ('BaseImporter');
}


my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "string",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "add_technical_metadata",
	'desc' => "{OggVorbisPlugin.add_technical_metadata}",
	'type' => "flag",
	'deft' => "" }, 
      { 'name' => "file_rename_method",
	'desc' => "{BaseImporter.file_rename_method}",
	'type' => "enum",
	'deft' => &get_default_file_rename_method(), # by default rename imported files and assoc files using this encoding
	'list' => $BaseImporter::file_rename_method_list,
	'reqd' => "no"
      } ];

my $options = { 'name'     => "OggVorbisPlugin",
		'desc'     => "{OggVorbisPlugin.desc}",
		'inherits' => "yes",
		'abstract' => "no",
		'args'     => $arguments };


# This plugin processes exported Ogg Vorbis files with the suffix ".ogg"
sub get_default_process_exp
{
    return q^(?i)(\.ogg)$^;
}

# rename imported media files using base64 encoding by default
# so that the urls generated will always work with external apps
sub get_default_file_rename_method() {
    return "base64";
}

sub new
{
    my ($class) = shift(@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
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
    # Extract metadata
    my $ogg = Ogg::Vorbis::Header::PurePerl->new($filename_full_path);

    # Comments added to the file
    foreach my $key ($ogg->comment_tags())
    {
	# Convert key to title case
	my $keytc = uc(substr($key, 0, 1)) . substr($key, 1, length($key));
	foreach my $value ($ogg->comment($key))
	{
	    if (defined $value && $value ne "") {
		$doc_obj->add_metadata($top_section, $keytc, $value);
	    }
	}
    }

    # Technical data (optional)
    if ($self->{'add_technical_metadata'}) {
	foreach my $key (keys %{$ogg->info})
	{
	    # Convert key to title case
	    my $keytc = uc(substr($key, 0, 1)) . substr($key, 1, length($key));
	    my $value = $ogg->info->{$key};
	    if (defined $value && $value ne "") {
		$doc_obj->add_metadata($top_section, $keytc, $value);
	    }
	}
    }

    $doc_obj->add_metadata ($top_section, "FileFormat", "OggVorbis");
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($top_section, "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($top_section, "srclinkFile", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($top_section, "srcicon", "_iconogg_");

    # add dummy text and NoText metadata which can be used to suppress the dummy text
    $self->add_dummy_text($doc_obj, $top_section);

    # Add the actual file as an associated file
    my $assoc_file = $doc_obj->get_assocfile_from_sourcefile();
    $doc_obj->associate_file($filename_full_path, $assoc_file, "VORBIS", $top_section);

}


1;
