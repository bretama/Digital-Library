#!/usr/bin/perl -w

###########################################################################
#
# flash_button.pl 
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

# flash_button.pl generates all the flashy javascript type
# buttons used by Greenstone
# these are the buttons described in macro files as:
# top_nav_button
# nav_bar_button
# document_button

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use Gimp;
use parsargv;
use util;
use unicode;


# set trace level to watch functions as they are executed
#Gimp::set_trace(TRACE_ALL);
#Gimp::set_trace(TRACE_CALL);

my $gsdl_yellow = "#D2B464";
my $black = "#000000";

my ($cfg_file, $width, $height, $text, $filenamestem, $fixed_width,
    $width_space, $whitespace, $dont_center, $bgcolor, $fontcolor, 
    $fontsize, $foundry, $fontname, $fontweight, $fontslant, $fontwidth, 
    $fontspacing, $image_dir);

sub print_usage {
    print STDERR "\n  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -cfg_file file        configuration file containing one or more\n";
    print STDERR "                         sets of the following options - use to create\n";
    print STDERR "                         batches of images\n";
    print STDERR "   -image_dir directory  directory to create images in [`pwd`]\n";
    print STDERR "                         this should be full path to existing directory\n";
    print STDERR "   -width number         width of button [65]\n";
    print STDERR "   -height number        height of button [30]\n";
    print STDERR "   -text string          button text\n";
    print STDERR "   -filenamestem string  filename - two images will be produced -\n";
    print STDERR "                         filenamestemon.gif and filenamestemof.gif\n";
    print STDERR "   -fixed_width          fix width of image - if this isn't set\n";
    print STDERR "                         image will be cropped with with width_space\n";
    print STDERR "                         space at each side of text\n";
    print STDERR "   -width_space number   width in pixels of blank space to leave at left\n";
    print STDERR "                         and right edges of text [1]\n";
    print STDERR "   -whitespace           add 1 pixel of white space at left and right edges\n";
    print STDERR "                         of image\n";
    print STDERR "   -dont_center          don't center text horizontally (only applicable if\n";
    print STDERR "                         image is fixed width\n";
    print STDERR "   -bgcolor hex_value    background color of button [$gsdl_yellow]\n";
    print STDERR "   -fontcolor hex_value  text color [$black]\n";
    print STDERR "   -fontsize number      font point size [10]\n";
    print STDERR "   -foundry string       [*]\n";
    print STDERR "   -fontname string      [lucida]\n";
    print STDERR "   -fontweight string    [medium]\n";
    print STDERR "   -fontslant            [r]\n";
    print STDERR "   -fontwidth            [*]\n";
    print STDERR "   -fontspacing          [*]\n\n";
}

sub reset_options {
    $image_dir = "./";
    $width = 65;
    $height = 30;
    $text = "";
    $filenamestem = "";
    $fixed_width = 0;
    $width_space = 1;
    $whitespace = 0;
    $dont_center = 0;
    $bgcolor = $gsdl_yellow;
    $fontcolor = $black;
    $fontsize = 10;
    $foundry = "*";
    $fontname = "lucida";
    $fontweight = "medium";
    $fontslant = "r";
    $fontwidth = "*";
    $fontspacing = "*";
}

sub gsdl_flash_button {

    if (!parsargv::parse(\@ARGV, 
			 'cfg_file/.*/', \$cfg_file,
			 'image_dir/.*/./', \$image_dir,
			 'width/^\d+$/65', \$width,
			 'height/^\d+$/30', \$height,
			 'text/.*/', \$text,
			 'filenamestem/.*', \$filenamestem,
			 'fixed_width', \$fixed_width,
			 'width_space/^\d+$/1', \$width_space,
			 'whitespace', \$whitespace,
			 'dont_center', \$dont_center,
			 "bgcolor/#[0-9A-Fa-f]{6}/$gsdl_yellow", \$bgcolor,
			 "fontcolor/#[0-9A-Fa-f]{6}/$black", \$fontcolor,
			 'fontsize/^\d+$/10', \$fontsize,
			 'foundry/.*/*', \$foundry,
			 'fontname/.*/lucida', \$fontname,
			 'fontweight/.*/medium', \$fontweight,
			 'fontslant/.*/r', \$fontslant,
			 'fontwidth/.*/*', \$fontwidth,
			 'fontspacing/.*/*', \$fontspacing)) {
	&print_usage();
	die "flash_button.pl: incorrect options\n";
    }

    # will create wherever gimp was started up from if we don't do this
    if ($image_dir eq "./") {
	$image_dir = `pwd`;
	chomp $image_dir;
    }

    # replace any '\n' occurring in text with carriage return
    $text =~ s/\\n/\n/gi;

    if ($cfg_file =~ /\w/) {
	
	open (CONF, $cfg_file) || die "couldn't open cfg_file $cfg_file\n";
	while (1) {

	    &reset_options ();
	
	    # read image configuration entry
	    my $status = &read_config_entry (CONF);
	    if ($filenamestem !~ /\w/) {
		if ($status) {last;}
		else {next;}
	    }

	    &produce_images (0);
	    if ($status) {last;}
	}

	close CONF;

    } else {

	&produce_images (0);

    }
}

sub produce_images {
    my ($off_img) = @_;
    
    # create image, set background color etc.
    my ($image, $backlayer) = &create_image ($off_img);
    
    # set the text if there is any
    if (length($text)) {

	my $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1, 
				   $fontsize, PIXELS, $foundry, $fontname, $fontweight, 
				   $fontslant, $fontwidth, $fontspacing);
	

	my $textwidth = gimp_drawable_width($textlayer);
	my $textheight = gimp_drawable_height($textlayer);

	# check that text fits within image
	if ($textheight > $height) {
	    die "'$text' at fontsize of $fontsize pixels does not fit within image\n" . 
		"$height pixels high. Decrease fontsize or increase image height\n";
	}

	my $spacers = $width_space * 2;
	$spacers += 2 if $whitespace;

	if (!$fixed_width || $textwidth > $width) {

	    if ($fixed_width) {
		print STDERR "WARNING (flash_button.pl): '$text' does not fit within $width pixel fixed width ";
		print STDERR "image. Image width was increased to ",$textwidth + $spacers, " pixels\n";
	    }
	    
	    $width = $textwidth + $spacers;

	    # recreate image in new size
	    ($image, $backlayer) = &create_image ($off_img);
	    $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1, 
				    $fontsize, PIXELS, $foundry, $fontname, $fontweight, 
				    $fontslant, $fontwidth, $fontspacing);
	    
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

	if ($fixed_width) {
	    if ($dont_center) {
		# don't center text horizontally (start it width_space pixels from left edge)
		my $x_offset = $width_space;
		$x_offset += 1 if $whitespace;
		gimp_layer_set_offsets ($textlayer, $x_offset, $y_offset);
	    } else {
		gimp_layer_set_offsets ($textlayer, ($width-$textwidth)/2, $y_offset);
	    }
	} else {
	    gimp_layer_set_offsets ($textlayer, $spacers / 2, $y_offset); 
	}
    }
    
    # add pixel of whitespace to each edge if required
    if ($whitespace) {
	gimp_rect_select ($image, 0, 0, 1, $height, 0, 0, 0);
	gimp_edit_clear ($image, $backlayer);
	gimp_selection_none ($image);
	gimp_rect_select ($image, $width-1, 0, 1, $height, 0, 0, 0);
	gimp_edit_clear ($image, $backlayer);
	gimp_selection_none ($image);
    }
    
    # flatten the image
    my $finishedlayer = gimp_image_flatten ($image);
    
    # make indexed colour 
    gimp_convert_indexed ($image, 0, 256);
    
    # save image
    my $filename = $filenamestem . "on.gif";
    $filename = $filenamestem . "of.gif" if $off_img;
    $filename = &util::filename_cat ($image_dir, $filename);

    gimp_file_save (RUN_NONINTERACTIVE, $image, $finishedlayer, $filename, $filename);

    &produce_images (1) unless $off_img;    
}

sub create_image {
    my ($off_img) = @_;

    # create the image
    my $image = gimp_image_new ($width, $height, RGB_IMAGE);
    
    # background layer
    my $backlayer = gimp_layer_new ($image, $width, $height, RGB_IMAGE, 
				    "BGLayer", 100, NORMAL_MODE);
    
    # add the background layer
    gimp_image_add_layer ($image, $backlayer, 0);
    
    # set colour of background
    gimp_palette_set_foreground ($bgcolor);
    
    # clear the background
    gimp_selection_all ($image);
    gimp_edit_clear ($image, $backlayer);
    gimp_selection_none ($image);
    
    # create the gradient background
    gimp_blend ($image, $backlayer, 0, NORMAL_MODE, LINEAR, 70, 0, REPEAT_NONE, 0, 0, 0, 5, $height-3, 5, 0);
    
    # adjust lightness of "off" gif
    gimp_hue_saturation ($image, $backlayer, 0, 0, 100, 0) if $off_img;

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
    
sub query {

  gimp_install_procedure("gsdl_flash_button", "create flashy javascript buttons for gsdl",
                        "", "Stefan Boddie", "Stefan Boddie", "2000-03-10",
                        "<Toolbox>/Xtns/gsdl_flash_button", "*", &PROC_EXTENSION,
                        [[PARAM_INT32, "run_mode", "Interactive, [non-interactive]"]], []);
}

sub net {
  gsdl_flash_button;
}

exit main;
