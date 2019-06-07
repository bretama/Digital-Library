###########################################################################
#
# UnknownPlugin.pm -- Plugin for files you know about but Greenstone doesn't
#
# A component of the Greenstone digital library software from the New
# Zealand Digital Library Project at the University of Waikato, New
# Zealand.
#
# Copyright (C) 2001 Gordon W. Paynter
# Copyright (C) 2001 New Zealand Digital Library Project
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

# UnknownPlugin - a plugin for unknown files

# This is a simple Plugin for importing files in formats that
# Greenstone doesn't know anything about.  A fictional document will
# be created for every such file, and the file itself will be passed
# to Greenstone as the "associated file" of the document.

# Here's an example where it is useful: I have a collection of
# pictures that include a couple of quicktime movie files with names
# like DCP_0163.MOV.  Rather than write a new plugin for quicktime
# movies, I add this line to the collection configuration file:

# plugin UnknownPlugin -process_exp "*.MOV" -assoc_field "movie"

# A document is created for each movie, with the associated movie
# file's name in the "movie" metadata field.  In the collection's
# format strings, I use the {If} macro to output different text for
# each type of file, like this:

# {If}{[movie],<HTML for displaying movie>}{If}{[Image],<HTML for displaying image>}

# You can also add extra metadata, such as the Title, Subject, and
# Duration, with metadata.xml files and RecPlug.  (If you want to use
# UnknownPlugin with more than one type of file, you will have to add
# some sort of distinguishing metadata in this way.)



package UnknownPlugin;

use BaseImporter;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @UnknownPlugin::ISA = ('BaseImporter');
}

my $arguments =
    [ { 'name' => "assoc_field",
	'desc' => "{UnknownPlugin.assoc_field}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "file_format",
	'desc' => "{UnknownPlugin.file_format}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "mime_type",
	'desc' => "{UnknownPlugin.mime_type}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "srcicon",
	'desc' => "{UnknownPlugin.srcicon}",
	'type' => "string",
	'deft' => "iconunknown",
	'reqd' => "no" },
      { 'name' => "process_extension",
	'desc' => "{UnknownPlugin.process_extension}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" } ];

my $options = { 'name'     => "UnknownPlugin",
		'desc'     => "{UnknownPlugin.desc}",
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

    # "-process_extension" is a simpler alternative to -process_exp for non-regexp people
    if (!$self->{'process_exp'} && $self->{'process_extension'}) {
	$self->{'process_exp'} = "\\." . $self->{'process_extension'} . "\$";
    }

    return bless $self, $class;
}


sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    # check the filename is okay - do we need this??
    if ($filename_full_path eq "" || $filename_no_path eq "") {
	print $outhandle "UnknownPlugin: couldn't process \"$filename_no_path\"\n";
	return undef;
    }

    # Add the file as an associated file ...
    my $section = $doc_obj->get_top_section();
    my $file_format = $self->{'file_format'} || "unknown";
    my $mime_type = $self->{'mime_type'} || "unknown/unknown";
    my $assoc_field = $self->{'assoc_field'} || "unknown_file";

    # The assocfilename is the url-encoded version of the utf8 filename
    my $assoc_file = $doc_obj->get_assocfile_from_sourcefile();

    $doc_obj->associate_file($filename_full_path, $assoc_file, $mime_type, $section);
    $doc_obj->add_metadata ($section, "FileFormat", $file_format);
    $doc_obj->add_metadata ($section, "MimeType", $mime_type);
    $doc_obj->add_utf8_metadata ($section, $assoc_field, $doc_obj->get_source()); # Source metadata is already in utf8 
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($section, "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($section, "srclinkFile", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($section, "srcicon", "_".$self->{'srcicon'}."_");
    
    # we have no text - add dummy text and NoText metadata
    $self->add_dummy_text($doc_obj, $section);

    return 1;
}


1;











