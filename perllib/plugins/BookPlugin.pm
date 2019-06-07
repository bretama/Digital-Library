###########################################################################
#
# BookPlugin.pm (formally called HBSPlug) -- plugin for processing simple
# html (or text) books
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

# creates multi-level document from document containing 
# <<TOC>> level tags. Metadata for each section is taken from any
# other tags on the same line as the <<TOC>>. e.g. <<Title>>xxxx<</Title>>
# sets Title metadata.

# Everything else between TOC tags is treated as simple html (i.e. no 
# processing of html links or any other HTMLPlug type stuff is done).

# expects input files to have a .hb file extension by default (this can be 
# changed by adding a -process_exp option

# a file with the same name as the hb file but a .jpg extension is
# taken as the cover image (jpg files are blocked by this plugin)

# BookPlugin is a simplification (and extension) of the HBPlug used
# by the Humanity Library collections. BookPlugin is faster as it expects
# the input files to be cleaner (The input to the HDL collections
# contains lots of excess html tags around <<TOC>> tags, uses <<I>>
# tags to specify images, and simply takes all text between <<TOC>>
# tags and start of text to be Title metadata). If you're marking up
# documents to be displayed in the same way as the HDL collections,
# use this plugin instead of HBPlug.

package BookPlugin;

use AutoExtractMetadata;
use util;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @BookPlugin::ISA = ('AutoExtractMetadata');
}

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_block_exp() } ];

my $options = { 'name'     => "BookPlugin",
		'desc'     => "{BookPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new AutoExtractMetadata($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub get_default_block_exp {
    my $self = shift (@_);

    return q^\.jpg$^;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.hb$^;
}

# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    print STDERR "<Processing n='$file' p='BookPlugin'>\n" if ($gli);
    print $outhandle "BookPlugin: processing $file\n" 
	if $self->{'verbosity'} > 1;
    
    my $cursection = $doc_obj->get_top_section();

    # Add FileFormat as the metadata
    $doc_obj->add_metadata($doc_obj->get_top_section(),"FileFormat", "Book");

    my $filename = &util::filename_cat($base_dir, $file);
    my $absdir = $filename;
    $absdir =~ s/[^\/\\]*$//;

    # add the cover image
    my $coverimage = $filename;
    $coverimage =~ s/\.[^\.]*$/\.jpg/i;
    $doc_obj->associate_file($coverimage, "cover.jpg", "image/jpeg");

    my $title = "";

    # remove any leading rubbish
    $$textref =~ s/^.*?(<<TOC)/$1/ios;
    
    my $curtoclevel = 1;
    my $firstsection = 1;
    my $toccount = 0;
    while ($$textref =~ /\w/) {
	$$textref =~ s/^<<TOC(\d+)>>([^\n]*)\n(.*?)(<<TOC|\Z)/$4/ios;
	my $toclevel = $1;
	my $metadata = $2;
	my $sectiontext = $3;

	if ($toclevel == 2) {
	    $toccount ++;
	}
	
	# close any sections below the current level and
	# create a new section (special case for the firstsection)
	while (($curtoclevel > $toclevel) ||
	       (!$firstsection && $curtoclevel == $toclevel)) {
	    $cursection = $doc_obj->get_parent_section ($cursection);
	    $curtoclevel--;
	}
	if ($curtoclevel+1 < $toclevel) {
	    print $outhandle "WARNING - jump in toc levels in $filename " . 
		"from $curtoclevel to $toclevel\n";
	}
	while ($curtoclevel < $toclevel) {
	    $curtoclevel++;
	    $cursection = 
		$doc_obj->insert_section($doc_obj->get_end_child($cursection));
	}

	# sort out metadata
	while ($metadata =~ s/^.*?<<([^>]*)>>(.*?)<<[^>]*>>//) {
	    my $metakey = $1;
	    my $metavalue = $2;

	    if ($metavalue ne "" && $metakey ne "") {
		# make sure key fits in with gsdl naming scheme 
		$metakey =~ tr/[A-Z]/[a-z]/;
		$metakey = ucfirst ($metakey);
		$doc_obj->add_utf8_metadata ($cursection, $metakey, $metavalue);
	    }
	}

	# remove header rubbish
	$sectiontext =~ s/^.*?<body[^>]*>//ios;

	# and any other unwanted tags
	$sectiontext =~ s/<(\/p|\/html|\/body)>//isg;

	# fix up the image links
	$sectiontext =~ s/(<img[^>]*?src\s*=\s*\"?)([^\">]+)(\"?[^>]*>)/
	    &replace_image_links($absdir, $doc_obj, $1, $2, $3)/isge;

	# add the text
	$doc_obj->add_utf8_text($cursection, $sectiontext);

	$firstsection = 0;

	$$textref =~ s/^\s+//s;
    }

    return 1;
}

sub replace_image_links {
    my $self = shift (@_);
    my ($dir, $doc_obj, $front, $link, $back) = @_;
    my $outhandle = $self->{'outhandle'};

    my ($filename, $error);
    my $foundimage = 0;
    
    $link =~ s/\/\///;
    my ($imagetype) = $link =~ /([^\.]*)$/;
    $imagetype =~ tr/[A-Z]/[a-z]/;
    if ($imagetype eq "jpg") {$imagetype = "jpeg";}
    if ($imagetype !~ /^(jpeg|gif|png)$/) {
	print $outhandle "BookPlugin: Warning - unknown image type ($imagetype)\n";
    }
    my ($imagefile) = $link =~ /([^\/]*)$/;
    my ($imagepath) = $link =~ /^[^\/]*(.*)$/;

    if (defined $imagepath && $imagepath =~ /\w/) {
	# relative link
	$filename = &util::filename_cat ($dir, $imagepath);
	if (-e $filename) {
	    $doc_obj->associate_file ($filename, $imagefile, "image/$imagetype");
	    $foundimage = 1;
	} else {
	    $error = "BookPlugin: Warning - couldn't find image file $imagefile in either $filename or";
	}
    }

    if (!$foundimage) {
	$filename = &util::filename_cat ($dir, $imagefile);
	if (-e $filename) {
	    $doc_obj->associate_file ($filename, $imagefile, "image/$imagetype");    
	    $foundimage = 1;
	} elsif (defined $error) {
	    print $outhandle "$error $filename\n";
	} else {
	    print $outhandle "BookPlugin: Warning - couldn't find image file $imagefile in $filename\n";
	}
    }

    if ($foundimage) {
	return "${front}_httpdocimg_/${imagefile}${back}";
    } else {
	return "";
    }
}

1;
