#!/usr/bin/perl -w

###########################################################################
#
# title_icon.pl 
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

# Modified by Rachid Ben Kaddour <qben@oce.nl> for gimp1.2

# title_icon.pl generates all the green_title type icons and 
# collection icons for Greenstone

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use Gimp qw/:auto :DEFAULT/;
use parsargv;
use util;
use unicode;

# set trace level to watch functions as they are executed
#Gimp::set_trace(TRACE_ALL);
#Gimp::set_trace(TRACE_CALL);

my $gsdl_green = "#96c19b";
my $black = "#000000";


local ($cfg_file, $size, $imagefile, $width, $height, $imageheight, $stripecolor, $stripewidth, 
       $stripe_alignment, $i_transparency, $text, $text_alignment, $filename, $textspace_x, 
       $textspace_y, $bgcolor, $fontcolor, $fontsize, $minfontsize, $foundry, $fontname, 
       $fontweight, $fontslant, $fontwidth, $fontspacing, $fontregistry, $fontencoding, $image_dir, $dont_wrap);

sub print_usage {
    print STDERR "\n  usage: $0 [options] macrofile\n\n";
    print STDERR "  options:\n";
    print STDERR "   -cfg_file file         configuration file containing one or more\n";
    print STDERR "                          sets of the following options - use to create\n";
    print STDERR "                          batches of images\n";
    print STDERR "   -size number           the overall size ratio of the image (i.e. a size\n";
    print STDERR "                          of 2 will create an image twice the default size)\n";
    print STDERR "   -image_dir directory   directory to create images in [`pwd`]\n";
    print STDERR "                          this should be full path to existing directory\n";
    print STDERR "   -imagefile             filename of image to embed within new icon\n";
    print STDERR "   -width number          width of icon [150]\n";
    print STDERR "   -height number         height of icon [44]\n";
    print STDERR "   -imageheight number    this is the height of the image if the image contains\n";
    print STDERR "                          an image (like collection icons) [110]\n";
    print STDERR "   -stripecolor hex_value color of vertical stripe [$gsdl_green]\n";
    print STDERR "   -stripewidth           width of vertical stripe [40]\n";
    print STDERR "   -stripe_alignment      alignment of vertical stripe (left or right) [left]\n";
    print STDERR "   -i_transparency number transparency of image within icon (0 > transparent > 100) [60]\n"; 
    print STDERR "   -text string           image text\n";
    print STDERR "   -text_alignment        alignment of text (left or right) [left]\n";
    print STDERR "   -filename string       filename of resulting image\n";
    print STDERR "   -textspace_x number    space in pixels between left/right edge of image and\n";
    print STDERR "                          left/right edge of text [3]\n";
    print STDERR "   -textspace_y number    space in pixels between top of image and top of\n";
    print STDERR "                          text [3]\n";
    print STDERR "   -bgcolor hex_value     background color of icon [$gsdl_green]\n";
    print STDERR "   -fontcolor hex_value   text color [$black]\n";
    print STDERR "   -fontsize number       font point size [17]\n";
    print STDERR "   -minfontsize number    minimum point size font will be reduced to fit image [10]\n";
    print STDERR "   -foundry string        [*]\n";
    print STDERR "   -fontname string       [lucida]\n";
    print STDERR "   -fontweight string     [medium]\n";
    print STDERR "   -fontslant             [r]\n";
    print STDERR "   -fontwidth             [*]\n";
    print STDERR "   -fontspacing           [*]\n";
    print STDERR "   -fontregistry          [*]\n";
    print STDERR "   -fontencoding          [*]\n";
    print STDERR "   -dont_wrap             don't attempt to wrap text\n\n";
}

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
    $fontregistry = "*";
    $fontencoding = "*";
}

sub gsdl_title_icon {

    if (!parsargv::parse(\@ARGV, 
			 'cfg_file/.*/', \$cfg_file,
			 'size/\d+/1', \$size,
			 'image_dir/.*/./', \$image_dir,
			 'imagefile/.*/', \$imagefile,
			 'width/^\d+$/150', \$width,
			 'height/^\d+$/44', \$height,
			 'imageheight/^\d+$/110', \$imageheight,
			 "stripecolor/#[0-9A-Fa-f]{6}/$gsdl_green", \$stripecolor,
			 'stripewidth/^\d+$/40', \$stripewidth,
			 'stripe_alignment/^(left|right)$/left', \$stripe_alignment,
			 'i_transparency/^\d+$/60', \$i_transparency,
			 'text/.*/', \$text,
			 'text_alignment/^(left|right)$/left', \$text_alignment,
			 'filename/.*', \$filename,
			 'textspace_x/^\d+$/3', \$textspace_x,
			 'textspace_y/^\d+$/3', \$textspace_y,
			 "bgcolor/#[0-9A-Fa-f]{6}/$gsdl_green", \$bgcolor,
			 "fontcolor/#[0-9A-Fa-f]{6}/$black", \$fontcolor,
			 'fontsize/^\d+$/17', \$fontsize,
			 'minfontsize/^\d+$/10', \$minfontsize,
			 'foundry/.*/*', \$foundry,
			 'fontname/.*/lucida', \$fontname,
			 'fontweight/.*/medium', \$fontweight,
			 'fontslant/.*/r', \$fontslant,
			 'fontwidth/.*/*', \$fontwidth,
			 'fontspacing/.*/*', \$fontspacing,
			 'fontregistry/.*/*', \$fontregistry,
			 'fontencoding/.*/*', \$fontencoding,
			 'dont_wrap', \$dont_wrap)) {
	&print_usage();
	die "title_icon.pl: incorrect options\n";
    }

    # will create wherever gimp was started up from if we don't do this
    if ($image_dir eq "./") {
	$image_dir = `pwd`;
	chomp $image_dir;
    }

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

    } else {

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
	
    # background layer
    my $backlayer = gimp_layer_new ($image, $width, $height, RGB_IMAGE, 
				    "BGLayer", 100, NORMAL_MODE);
	
    # add the background layer
    gimp_image_add_layer ($image, $backlayer, 0);
	
    # set colour of stripe
    gimp_palette_set_foreground ($stripecolor);
	
    # clear the background
    gimp_selection_all ($image);
    gimp_edit_clear ($backlayer);
    gimp_selection_none ($image);
	
    # fill in stripe
    if ($stripe_alignment eq "left") {
	gimp_rect_select ($image, 0, 0, $stripewidth, $height, 0, 0, 0);
    } else {
	gimp_rect_select ($image, $width-$stripewidth, 0, $stripewidth, $height, 0, 0, 0);
    }
    gimp_bucket_fill ($backlayer, FG_BUCKET_FILL, NORMAL_MODE, 100, 0, 1, 0, 0);
    gimp_selection_none ($image);

    # get image file (image goes on opposite side to stripe)
    if ($use_image) {
	my $rimage = gimp_file_load (RUN_NONINTERACTIVE, $imagefile, $imagefile);
	my $rdraw = gimp_image_active_drawable ($rimage);
	gimp_scale ($rdraw, 1, 0, 0, $width-$stripewidth, $height);
	gimp_edit_copy ($rdraw);
	
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

	$backlayer = gimp_image_flatten ($image);
    }
	
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
				    $fontwidth, $fontspacing, $fontregistry, $fontencoding);
	    
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
		    gimp_edit_clear ($textlayer);
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
	gimp_convert_indexed ($image, NO_DITHER, MAKE_PALETTE, 256, 0, 1, "");
    }
	
    # save image
    my $filename = &util::filename_cat ($image_dir, $filename);
    if ($filename =~ /\.jpe?g$/i) {
	# gimp_file_save doesn't appear to work properly for jpegs
	file_jpeg_save (RUN_NONINTERACTIVE, $image, $finishedlayer, 
			$filename, $filename, 0.8, 0, 1);
    } else {
	gimp_file_save (RUN_NONINTERACTIVE, $image, $finishedlayer, 
			$filename, $filename);
    }
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
	my @size_args = ('width', 'height', 'imageheight', 'stripewidth',
			 'textspace_x', 'textspace_y', 'fontsize', 'minfontsize');
	foreach $arg (@size_args) {
	    $$arg = int ($$arg * $size);
	}
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
	$text =~ s/^\Q$line\E//;
	$line =~ s/\s([^\s]*)$/\n/;
	$text = $1 . $text;
	$new_text .= $line;
    }
    $new_text .= $text;
    $text = $new_text;
}
    
sub query {

  gimp_install_procedure("gsdl_title_icon", "create title icons for gsdl",
                        "", "Stefan Boddie", "Stefan Boddie", "2000-03-10",
                        "<Toolbox>/Xtns/gsdl_title_icon", "*", &PROC_EXTENSION,
                        [[PARAM_INT32, "run_mode", "Interactive, [non-interactive]"]], []);
}

Gimp::on_net { gsdl_title_icon; };
exit main;

