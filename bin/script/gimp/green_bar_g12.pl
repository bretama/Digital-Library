#!/usr/bin/perl -w

###########################################################################
#
# green_bar.pl 
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

# green_bar.pl 
#
# This script generates the black on green gradient background images
# used by Greenstone.  these are the icons described in macro files as:
# green version of nav_bar_button green_bar_left_aligned
#
# This version has been rewritten for the GIMP Version 1.2.  You
# should be able to run it if you install gimp 1.2 with perl support.
# In Debian this means running "apt-get install gimp1.2 gimp1.2perl"


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use Gimp ":auto";
use Gimp::Fu; 

use util;
use unicode;

# set trace level to watch functions as they are executed
#Gimp::set_trace(TRACE_ALL);
#Gimp::set_trace(TRACE_CALL);

my $gsdl_green = "#96c19b";
my $black      = "#000000";
my $white      = "#FFFFFF";

my ($current_dir) = `pwd`;
chomp($current_dir);

my ($cfg_file, $width, $height, $text, $filename, $width_space, 
    $alignment, $fgcolor, $bgcolor, $fontcolor, $fontsize, $foundry, $fontname, 
    $fontweight, $fontslant, $fontwidth, $fontspacing, $image_dir);

sub reset_options {
    $image_dir = "./";
    $width = 87;
    $height = 17;
    $text = "";
    $filename = "";
    $width_space = 1;
    $alignment = "eft";
    $fgcolor = $white;
    $bgcolor = $gsdl_green;
    $fontcolor = $black;
    $fontsize = 17;
    $foundry = "*";
    $fontname = "lucida";
    $fontweight = "medium";
    $fontslant = "r";
    $fontwidth = "*";
    $fontspacing = "*";
}

sub gsdl_green_bar {

    ($text, $filename, $image_dir, $width, $height, $fgcolor, $bgcolor,
    $fontcolor, $fontsize, $alignment, , $width_space, $foundry,
    $fontname, $fontweight, $fontslant, $fontwidth, $fontspacing,
    $cfg_file) = @_;

    # Read a configuration file
    if ($cfg_file =~ /\w/) {
	
	open (CONF, $cfg_file) || die "couldn't open cfg_file $cfg_file\n";
	while (1) {

	    &reset_options ();
	
	    # read image configuration entry
	    my $status = &read_config_entry (CONF);
	    if ($filename !~ /\w/) {
		if ($status) {last;}
		else {next;}
	    }

	    &produce_image ();
	    if ($status) {last;}
	}

	close CONF;

    }

    # Produce an image based onlyon command-line parameters
    else {

	&produce_image ();

    }
}


sub produce_image {

    # Create background image
    my ($image, $backlayer) = &create_image ();

    # set the text if there is any
    if (length($text)) {

	my $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1, 
				   $fontsize, PIXELS, $foundry, $fontname, $fontweight, 
				   $fontslant, $fontwidth, $fontspacing, "*", "*");
	

	my $textwidth = gimp_drawable_width($textlayer);
	my $textheight = gimp_drawable_height($textlayer);

	# check that text fits within image
	if ($textheight > $height) {
	    die "'$text' at fontsize of $fontsize pixels does not fit within image\n" . 
		"$height pixels high. Decrease fontsize or increase image height\n";
	}

	my $spacers = $width_space * 2;

	if ($textwidth > $width) {

	    print STDERR "WARNING (green_bar.pl): '$text' does not fit within $width pixel fixed width ";
	    print STDERR "image. Image width was increased to ",$textwidth + $spacers, " pixels\n";
	
	    $width = $textwidth + $spacers;

	    # recreate image in new size
	    ($image, $backlayer) = &create_image ();
	    $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1,
				    $fontsize, PIXELS, $foundry, $fontname, $fontweight,
				    $fontslant, $fontwidth, $fontspacing, "*", "*");
	
	}

	my $y_offset = ($height-$textheight)-int($fontsize/5);

	my $descenders = "";

	# russian descenders (KOI8-R)
	# $descenders .= chr(0xD2);
	# $descenders .= chr(0xD5);

	if ($text =~ /[gjpqyJ$descenders]/) { ## capital J is a descender in lucida font
	    # descenders - put text at bottom of image, otherwise 
	    # go for fontsize/5 pixels above bottom. This is kind of hacky 
	    # and may need some playing with for different fonts/fontsizes
	    $y_offset = $height-$textheight;
	}

	if ($alignment =~ /^l/i) {
	    # align text to the left
	    my $x_offset = $width_space;
	    gimp_layer_set_offsets ($textlayer, $x_offset, $y_offset);
	} elsif ($alignment =~ /^r/i) {
	    # right alignment
	    gimp_layer_set_offsets ($textlayer, ($width-($textwidth+$width_space)), $y_offset);
	} else {
	    # center alignment (the default)
	    gimp_layer_set_offsets ($textlayer, ($width-$textwidth)/2, $y_offset);
	}
    }

    # flatten the image
    my $finishedlayer = gimp_image_flatten ($image);

    # make indexed colour 
    if ($filename =~ /\.gif$/i) {
        # make indexed colour (may need to do this for 
        # other formats as well as gif)
        gimp_convert_indexed ($image, 0, MAKE_PALETTE, 256, 0, 0, "");
    }

    # save image
    $filename = &util::filename_cat ($image_dir, $filename);
    gimp_file_save (RUN_NONINTERACTIVE, $image, $finishedlayer, $filename, $filename);
}


sub create_image {
    # create the image
    my $image = gimp_image_new ($width, $height, RGB_IMAGE);

    # background layer
    my $backlayer = gimp_layer_new ($image, $width, $height, RGB_IMAGE, 
				    "BGLayer", 100, NORMAL_MODE);

    # add the background layer
    gimp_image_add_layer ($image, $backlayer, 0);

    # set colour of background
    gimp_palette_set_foreground ($bgcolor);
    gimp_palette_set_background ($fgcolor);

    # clear the background
    gimp_selection_all ($image);
    gimp_edit_clear ($backlayer);
    gimp_selection_none ($image);

    # create the gradient background
    gimp_blend ($backlayer, 0, NORMAL_MODE, LINEAR, 70, 0, REPEAT_NONE, 0, 0, 0, 5, $height-3, 5, 0);

    # set colour of text
    gimp_palette_set_foreground ($fontcolor);

    return ($image, $backlayer);
}

# returns 1 if this is the last entry,
sub read_config_entry {
    my ($handle) = @_;

    my $line = "";
    while (defined ($line = <$handle>)) {
	next unless $line =~ /\w/;
	my @line = ();
	if ($line =~ /^\-+/) {return 0;}
	$line =~ s/^\#.*$//;   # remove comments
	$line =~ s/\cM|\cJ//g; # remove end-of-line characters
	$line =~ s/^\s+//;     # remove initial white space
	while ($line =~ s/\s*(\"[^\"]*\"|\'[^\']*\'|\S+)\s*//) {
	    if (defined $1) {
		# remove any enclosing quotes
		my $entry = $1;
		$entry =~ s/^([\"\'])(.*)\1$/$2/;

		# substitute any environment variables
		$entry =~ s/\$(\w+)/$ENV{$1}/g;
		$entry =~ s/\$\{(\w+)\}/$ENV{$1}/g;
		
		push (@line, $entry);
	    } else {
		push (@line, "");
	    }
	}
	if (scalar (@line) == 2 && defined ${$line[0]}) {
	    ${$line[0]} = $line[1];
	}
    }
    return 1;
}


register("gsdl_green_bar", 
	 "Create green bar icons for gsdl (gimp version 1.2)",
	 "",
	 "Stefan Boddie (1.0) and Gordon Paynter (1.2)",
	 "Copyright 2000 Stefan Boddie and The New Zealand Digital Library Project",
	 "2000-07-05",
	 "<Toolbox>/Xtns/gsdl_green_bar", 
	 "*",
	 [
           [PF_STRING, "text",        "Text appearing on bar", "greenstone"],

           [PF_STRING, "filename",    "Output file", "green_bar.png"],
           [PF_STRING, "image_dir",   "Directory to create images in", $current_dir],

           [PF_INT,    "width",      "Width of the bar",  640],
           [PF_INT,    "height",     "Height of the bar", 17],
           [PF_STRING, "fgcolor",   "Foreground colour (top) of bar", $white],
           [PF_STRING, "bgcolor",   "Background colour (bottom) of bar", $gsdl_green],
           [PF_STRING, "fontcolor", "Colour of text on bar", $black],
           [PF_INT,    "fontsize",  "Font size",    17],

           [PF_STRING, "alignment",     "Alignment of text on the bar (left, center or right)", "left"],
           [PF_INT,    "padding_space", "Space around the text",                   5],

           [PF_STRING, "foundry",     "Font foundry", "*"],
           [PF_STRING, "fontname",    "Font name",    "lucida"],
           [PF_STRING, "fontweight",  "Font weight",  "medium"],
           [PF_STRING, "fontslant",   "Font slant",   "r"],
           [PF_STRING, "fontwidth",   "Font width",   "*"],
           [PF_STRING, "fontspacing", "Font spacing", "*"],

           [PF_STRING, "cfg_file",    "Configuration file", ""]

         ], 
         \&gsdl_green_bar);


exit main;
