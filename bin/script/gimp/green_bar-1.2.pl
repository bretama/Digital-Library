#!/usr/bin/perl -w

###########################################################################
#
# green_bar.pl 
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

# green_bar.pl generates all the black on green gradient background
# images used by Greenstone. 
# these are the icons described in macro files as:
# green version of nav_bar_button
# green_bar_left_aligned

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

my ($cfg_file, $width, $height, $text, $filename, $width_space, 
    $dont_center, $bgcolor, $fontcolor, $fontsize, $foundry, $fontname, 
    $fontweight, $fontslant, $fontwidth, $fontspacing, $fontregistry, $fontencoding, $image_dir);

sub print_usage {
    print STDERR "\n  usage: $0 [options] macrofile\n\n";
    print STDERR "  options:\n";
    print STDERR "   -cfg_file file        configuration file containing one or more\n";
    print STDERR "                         sets of the following options - use to create\n";
    print STDERR "                         batches of images\n";
    print STDERR "   -image_dir directory  directory to create images in [`pwd`]\n";
    print STDERR "                         this should be full path to existing directory\n";
    print STDERR "   -width number         width of bar [87]\n";
    print STDERR "   -height number        height of bar [17]\n";
    print STDERR "   -text string          icon text\n";
    print STDERR "   -filename string      filename of resulting image\n";
    print STDERR "   -width_space number   width in pixels of blank space to leave at left\n";
    print STDERR "                         and right edges of text [1]\n";
    print STDERR "   -dont_center          don't center text horizontally\n";
    print STDERR "   -bgcolor hex_value    background color of bar [$gsdl_green]\n";
    print STDERR "   -fontcolor hex_value  text color [$black]\n";
    print STDERR "   -fontsize number      font point size [17]\n";
    print STDERR "   -foundry string       [*]\n";
    print STDERR "   -fontname string      [lucida]\n";
    print STDERR "   -fontweight string    [medium]\n";
    print STDERR "   -fontslant            [r]\n";
    print STDERR "   -fontwidth            [*]\n";
    print STDERR "   -fontspacing          [*]\n";
    print STDERR "   -fontregistry         [*]\n";
    print STDERR "   -fontencoding         [*]\n\n";
}

sub reset_options {
    $image_dir = "./";
    $width = 87;
    $height = 17;
    $text = "";
    $filename = "";
    $width_space = 1;
    $dont_center = 0;
    $bgcolor = $gsdl_green;
    $fontcolor = $black;
    $fontsize = 17;
    $foundry = "*";
    $fontname = "lucida";
    $fontweight = "medium";
    $fontslant = "r";
    $fontwidth = "*";
    $fontspacing = "*";
    $fontregistry = "*";
    $fontencoding = "*";
}

sub gsdl_green_bar {

    if (!parsargv::parse(\@ARGV, 
			 'cfg_file/.*/', \$cfg_file,
			 'image_dir/.*/./', \$image_dir,
			 'width/^\d+$/87', \$width,
			 'height/^\d+$/17', \$height,
			 'text/.*/', \$text,
			 'filename/.*', \$filename,
			 'width_space/^\d+$/1', \$width_space,
			 'dont_center', \$dont_center,
			 "bgcolor/#[0-9A-Fa-f]{6}/$gsdl_green", \$bgcolor,
			 "fontcolor/#[0-9A-Fa-f]{6}/$black", \$fontcolor,
			 'fontsize/^\d+$/17', \$fontsize,
			 'foundry/.*/*', \$foundry,
			 'fontname/.*/lucida', \$fontname,
			 'fontweight/.*/medium', \$fontweight,
			 'fontslant/.*/r', \$fontslant,
			 'fontwidth/.*/*', \$fontwidth,
			 'fontregistry/.*/*', \$fontregistry,
			 'fontencoding/.*/*', \$fontencoding,
			 'fontspacing/.*/*', \$fontspacing)) {
	&print_usage();
	die "green_bar.pl: incorrect options\n";
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
    
    # create image, set background color etc.
    my ($image, $backlayer) = &create_image ();
    
    # set the text if there is any
    if (length($text)) {

	my $textlayer = gimp_text ($image, $backlayer, 0, 0, $text, 0, 1, 
				   $fontsize, PIXELS, $foundry, $fontname, $fontweight, 
				   $fontslant, $fontwidth, $fontspacing, $fontregistry, $fontencoding);
	

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
				    $fontslant, $fontwidth, $fontspacing, $fontregistry, $fontencoding);
	    
	}

	my $y_offset = ($height-$textheight)-int($fontsize/5);

	my $halfdescenders = "";

	# Russian half descenders (KOI8-R)
	# -- Uncomment if generating Russian images using KOI8-R encoded text --
	# $halfdescenders .= chr(195) . chr(253);  # Checked
	# $halfdescenders .= chr(196) . chr(198) . chr(221) . chr(227) . chr(228); # Unchecked

	# Kazakh (and Russian) half descenders (Helvetica Kazakh font)
	# -- Uncomment if generating Kazakh or Russian images using text encoded to match
	#      a Kazakh Helvetica font:
        #        http://www.unesco.kz/ci/projects/greenstone/kazakh_fonts/helv_k.ttf
	#    Mapping for this encoding is: mapping/from_uc/kazakh.ump --
	# $halfdescenders .= chr(178) . chr(179) . chr(187);             # Kazakh specific
	# $halfdescenders .= chr(196) . chr(214) . chr(217) . chr(228);  # Generic Russian
	# $halfdescenders .= chr(244) . chr(246) . chr(249);

	# -- Uncomment if generating images using a font with half descenders --
	# if ($text =~ /[$halfdescenders]/) {
	    # half descenders - put text at fontsize/10 pixels above bottom
	    # $y_offset = ($height-$textheight)-int($fontsize/10);
	# }

	my $descenders = "";

	# Russian descenders (KOI8-R)
	# -- Uncomment if generating Russian images using KOI8-R encoded text --
	# $descenders .= chr(210) . chr(213);

	# Kazakh (and Russian) descenders (Helvetica Kazakh font)
	# -- Uncomment if generating Kazakh or Russian images using text encoded to match
	#      a Kazakh Helvetica font:
        #        http://www.unesco.kz/ci/projects/greenstone/kazakh_fonts/helv_k.ttf
	#    Mapping for this encoding is: mapping/from_uc/kazakh.ump --
	# $descenders .= chr(189) . chr(190);  # Kazakh specific
	# $descenders .= chr(240) . chr(243);  # Generic Russian

	if ($text =~ /[gjpqyJ$descenders]/) { ## capital J is a descender in lucida font
	    # descenders - put text at bottom of image, otherwise 
	    # go for fontsize/5 pixels above bottom. This is kind of hacky 
	    # and may need some playing with for different fonts/fontsizes
	    $y_offset = $height-$textheight;
	}

	if ($dont_center) {
	    # don't center text horizontally (start it width_space pixels from left edge)
	    my $x_offset = $width_space;
	    gimp_layer_set_offsets ($textlayer, $x_offset, $y_offset);
	} else {
	    gimp_layer_set_offsets ($textlayer, ($width-$textwidth)/2, $y_offset);
	}
    }
    
    # flatten the image
    my $finishedlayer = gimp_image_flatten ($image);
    
    # make indexed colour 
    gimp_convert_indexed ($image, NO_DITHER, MAKE_PALETTE, 256, 0, 1,"");
    
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
    
sub query {

  gimp_install_procedure("gsdl_green_bar", "create green bar icons for gsdl",
                        "", "Stefan Boddie", "Stefan Boddie", "2000-03-10",
                        "<Toolbox>/Xtns/gsdl_green_bar", "*", &PROC_EXTENSION,
                        [[PARAM_INT32, "run_mode", "Interactive, [non-interactive]"]], []);
}

Gimp::on_net { gsdl_green_bar; };
exit main;
