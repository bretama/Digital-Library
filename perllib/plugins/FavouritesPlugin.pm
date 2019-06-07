###########################################################################
#
# FavouritesPlug.pm -- Plugin for Internet Explorer Favourites files
#                      By Stephen De Gabrielle
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
# hacked together by Stephen De Gabrielle from various plugins 
# especially SRCPlug by John McPherson Nov 2000

package FavouritesPlugin;

use ReadTextFile;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @FavouritesPlugin::ISA = ('ReadTextFile');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ];

my $options = { 'name'     => "FavouritesPlugin",
		'desc'     => "{FavouritesPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift(@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}


sub get_default_process_exp
{
    # URL is extension for single bookmarks under windows.
    return q^(?i)\.URL$^;
}


# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $section = $doc_obj->get_top_section();

    # don't want mg to turn escape chars into actual values
    $$textref =~ s/\\/\\\\/g;

    # use filename (minus the .url extension) as the title
    my $title = $file;
    $title =~ s/.url$//i;
    $doc_obj->add_utf8_metadata($section, "Title", $title);

    # get the URL from the file
    my ($url) = ($$textref =~ m/^URL=(http.+)/mg);
    $doc_obj->add_metadata($section, "URL", $url);

    # Add weblink metadata for an automatic link to the webpage
    $doc_obj->add_utf8_metadata($section, "weblink", "<a href=\"$url\">");
    $doc_obj->add_utf8_metadata($section, "webicon", "_iconworld_");
    $doc_obj->add_utf8_metadata($section, "/weblink", "</a>");

    # Tidy up the favourite text to look a bit nicer
    $$textref =~ s/^\\n/<p>/g;
    $$textref =~ s/\[/<p><strong>/g;
    $$textref =~ s/\]/<\/strong><p>/g;
    $$textref =~ s/^Modified=(.+)$/<strong>Modified<\/strong>$1<p>/g;
    $doc_obj->add_utf8_text($section, "$$textref");

    $doc_obj->add_metadata($section, "FileFormat", "Favourite");
    return 1;
}

1;
