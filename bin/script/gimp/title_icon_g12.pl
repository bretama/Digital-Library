#!/usr/bin/perl -w

###########################################################################
#
# title_icon.pl
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2001 New Zealand Digital Library Project
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

# title_icon.pl
#
# This script generates collection title icons for greenstone.
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
my $black = "#000000";
my $white      = "#FFFFFF";

my ($current_dir) = `pwd`;
chomp($current_dir);


my ($text, $filename, $image_dir, $size, $width, $height,
    $stripecolor, $stripewidth, $stripe_alignment, $textspace_x,
    $textspace_y, $dont_wrap, $imagefile, $imageheight, $i_transparency,
    $bgcolor, $fontcolor, $fontsize, $minfontsize, $text_alignment,
    $foundry, $fontname, $fontweight, $fontslant, $fontwidth,
    $fontspacing, $cfg_file);

sub reset_options {
    $image_dir = "./";
    $imagefile = "";
    $width = int (150 * $size);
    $height = int (44 * $size);
    $imageheight = int (110 * $size);
    $stripecolor = $gsdl_green;
    $stripewidth = int (40 * $size);
    $stripe_alignment = "left";
    $i_transparency = 60;
    $text = "";
    $text_alignment = "left";
    $filename = "";
    $textspace_x = int (3 * $size);
    $textspace_y = int (3 * $size);
    $bgcolor = $gsdl_green;
    $fontcolor = $black;
    $fontsize = int (17 * $size);
    $minfontsize = int (10 * $size);
    $foundry = "*";
    $fontname = "lucida";
    $fontweight = "medium";
    $fontslant = "r";
    $fontwidth = "*";
    $fontspacing = "*";
}

sub gsdl_title_icon {

    ($text, $filename, $image_dir, $size, $width, $height,
     $stripecolor, $stripewidth, $stripe_alignment, $textspace_x,
     $textspace_y, $dont_wrap, $imagefile, $imageheight, $i_transparency,
     $bgcolor, $fontcolor, $fontsize, $minfontsize, $text_alignment,
     $foundry, $fontname, $fontweight, $fontslant, $fontwidth,
     $fontspacing, $cfg_file) = @_;

    # Create images using a configuration file
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

    # Create a single image from the parameters we have
    else {
	&produce_image ();
    }

}

sub produce_image {

    &adjust_args ();
    &wrap_text () unless $dont_wrap;

    my $use_image = 0;
    if ($imagefile =~ /\w/) {
	if (!-r $imagefile) {
	    print STDERR "WARNING (title_icon.pl): imagefile '$imagefile cannot be ";
	    print STDERR "read - $filename will be created without the use of an image file\n";
	} else {
	    $use_image = 1;
	    $height = $imageheight;
	}
    }

    # create the image
    my $image = gimp_image_new ($width, $height, RGB_IMAGE);
	
    # create and add the background layer
    my $backlayer = gimp_layer_new ($image, $width, $height, RGB_IMAGE, 
				    "BGLayer", 100, NORMAL_MODE);
    gimp_image_add_layer ($image, $backlayer, 0);
	
    # clear the background
    gimp_selection_all ($image);
    gimp_edit_clear ($backlayer);
    gimp_selection_none ($image);
	
    # fill in stripe
    if ($stripewidth > 0) {
        gimp_palette_set_foreground ($stripecolor);
	if ($stripe_alignment eq "left") {
	  gimp_rect_select ($image, 0, 0, $stripewidth, $height, 0, 0, 0);
	} else {
	  gimp_rect_select ($image, $width-$stripewidth, 0, $stripewidth, $height, 0, 0, 0);
	}
	gimp_bucket_fill ($backlayer, FG_BUCKET_FILL, NORMAL_MODE, 100, 0, 1, 0, 0);
	gimp_selection_none ($image);
    }

    # get image file (image goes on opposite side to stripe)
    if ($use_image) {
	my $rimage = gimp_file_load (RUN_NONINTERACTIVE, $imagefile, $imagefile);
	my $rdraw = gimp_image_active_drawable ($rimage);
	gimp_scale ($rdraw, 1, 0, 0, $width-$stripewidth, $height);
	gimp_edit_copy ($rdraw);
	
	# add the background image layer
	my $imagelayer = gimp_layer_new ($image, $width, $height, RGB_IMAGE, 
					 "ImageLayer", $i_transparency, NORMAL_MODE);
	gimp_image_add_layer ($image, $imagelayer, 0);
	
	# clear the new layer
	gimp_selection_all ($image);
	gimp_edit_clear ($imagelayer);
	gimp_selection_none ($image);
	
	my $flayer = gimp_edit_paste ($imagelayer, 1); 
	if ($stripe_alignment eq "left") {
	    gimp_layer_set_offsets($flayer, $stripewidth, 0);
	    gimp_layer_set_offsets($imagelayer, $stripewidth, 0);
	} else {
	    gimp_layer_set_offsets($flayer, 0, 0);
	    gimp_layer_set_offsets($imagelayer, 0, 0);
	}
    }

    # flatten the image (otherwise the text will be "behind" the image)
    $backlayer = gimp_image_flatten ($image);

    # set colour of text
    gimp_palette_set_foreground ($fontcolor);
	
    # set the text if there is any
    my ($textlayer, $textheight, $textwidth);
    my $fsize = $fontsize;
    if (length($text)) {
	$text =~ s/\\n/\n/gi;

	while (1) {
	    $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1, $fsize, 
				    PIXELS, $foundry, $fontname, $fontweight, $fontslant, 
				    $fontwidth, $fontspacing, "*", "*");
	
	    # check that text fits within image
	    $textwidth = gimp_drawable_width($textlayer);
	    $textheight = gimp_drawable_height($textlayer);
	    if ((($textwidth + $textspace_x) > $width) || 
		(($textheight + $textspace_y) > $height)) {
		if ($fsize < $minfontsize) {
		    die "Error (title_icon.pl): text '$text' doesn't fit on ${width}x${height} image " .
			"(minimum font size tried: $minfontsize\n";
		} else {
		    gimp_selection_all ($image);
		    gimp_edit_clear ($image, $textlayer);
		    gimp_selection_none ($image);
		    $fsize --;
		    print STDERR "WARNING (title_icon.pl): '$text' doesn't fit: reducing font size to $fsize\n";
		}
	    } else {
		last;
	    }
	}
	
	# align text
	if ($text_alignment eq "left") {
	    gimp_layer_set_offsets ($textlayer, $textspace_x, $textspace_y);
	} else {
	    gimp_layer_set_offsets ($textlayer, ($width-$textwidth)-$textspace_x, $textspace_y);
	}
    }

    # flatten the image
    my $finishedlayer = gimp_image_flatten ($image);
	
    if ($filename =~ /\.gif$/i) {
	# make indexed colour (may need to do this for 
	# other formats as well as gif)
	gimp_convert_indexed ($image, 0, 256);
    }
	
    # save image
    my $filename = &util::filename_cat ($image_dir, $filename);
    gimp_file_save (RUN_NONINTERACTIVE, $image, $finishedlayer, $filename, $filename);
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

# adjust arguments that are effected by the size argument
sub adjust_args {

    if ($size != 1) {
        $width *= $size;
        $height *= $size;
	$imageheight *= $size;
	$stripewidth *= $size;
	$textspace_x *= $size;
	$textspace_y *= $size;
	$fontsize *= $size;
	$minfontsize *= $size;
    }
}

sub wrap_text {

    # don't wrap text if it already contains carriage returns
    return if $text =~ /\n/;

    # the following assumes that all words are less than $wrap_length long
    my $wrap_length = 14;

    my $new_text = "";
    while (length ($text) >= $wrap_length) {
	my $line = substr ($text, 0, $wrap_length);
	$text =~ s/^$line//;
	$line =~ s/\s([^\s]*)$/\n/;
	$text = $1 . $text;
	$new_text .= $line;
    }
    $new_text .= $text;
    $text = $new_text;
}


register("gsdl_title_icon", 
	 "Create title icons for gsdl (gimp version 1.2)",
	 "", 
	 "Stefan Boddie (1.0) and Gordon Paynter (1.2)",
	 "Copyright 1999-2001 The New Zealand Digital Library Project",
	 "2000-03-10",
	 "<Toolbox>/Xtns/gsdl_title_icon", 
	 "*",
	 [
           [PF_STRING, "text",      "Text appearing on icon", "greenstone collection"],

           [PF_STRING, "filename",  "Output file", "title_icon.png"],
           [PF_STRING, "image_dir", "Directory to create images in", $current_dir],

           [PF_INT,    "size_ratio", "Size factor: a factor of 2 doulbles image size",  1],
           [PF_INT,    "width",      "Width of the icon",  150],
           [PF_INT,    "height",     "Height of the icon", 44],

           [PF_STRING, "stripecolor", "Colour of the stripe", $gsdl_green],
           [PF_INT,    "stripewidth", "Width of the stripe",  40],
           [PF_STRING, "stripealign", "Alignment of stripe (left or right)", "left"],

           [PF_INT,    "text_x_offset",    "Distance from left of image to text", 3],
           [PF_INT,    "text_y_offset",    "Distance from top of image to text",  3],
           [PF_STRING, "dont_wrap",        "don't attempt to wrap text", ""],

           [PF_STRING, "imagefile",   "Filename of background image", ""],
           [PF_INT,    "imageheight", "Height of background image", 110],
           [PF_INT,    "imagetransp", "Transparency of background image (1-100)", 60],

#           [PF_STRING, "fgcolor",     "Foreground colour (top) of bar", $white],
           [PF_STRING, "bgcolor",     "Background colour (bottom) of bar", $gsdl_green],
           [PF_STRING, "fontcolor",   "Colour of text on bar", $black],
           [PF_INT,    "fontsize",    "Font size",    17],
           [PF_INT,    "minfontsize", "Minimum font size if scaling required",    10],

           [PF_STRING, "alignment",     "Alignment of text on the icon (left or right)", "left"],

           [PF_STRING, "foundry",     "Font foundry", "*"],
           [PF_STRING, "fontname",    "Font name",    "lucida"],
           [PF_STRING, "fontweight",  "Font weight",  "medium"],
           [PF_STRING, "fontslant",   "Font slant",   "r"],
           [PF_STRING, "fontwidth",   "Font width",   "*"],
           [PF_STRING, "fontspacing", "Font spacing", "*"],

           [PF_STRING, "cfg_file",    "Configuration file", ""]

         ], 
         \&gsdl_title_icon);


exit main;


