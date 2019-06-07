#!/usr/bin/perl -w

###########################################################################
#
# translate.pl 
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

# translate.pl takes a translated macro file (filename passed in on command
# line) and generates any images required by it. Check out english.dm for
# an example of the format translate.pl expects

# translate.pl uses gimp to generate images so needs gimp installed and set
# up for scripting with perl

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use Gimp qw/:auto :DEFAULT/;
use parsargv;
use util;
use unicode;

# these html entities will be translated correctly when occurring in 
# images. Any entities not in this list will not.
my %rmap = ('auml' => chr (228),
	    'euml' => chr (235),
	    'iuml' => chr (239),
	    'ouml' => chr (246),
	    'uuml' => chr (252),
	    'Auml' => chr (196),
	    'Euml' => chr (203),
	    'Iuml' => chr (207),
	    'Ouml' => chr (214),
	    'Uuml' => chr (220),
	    'szlig' => chr (223),
	    'aacute' => chr (225),
	    'eacute' => chr (233),
	    'iacute' => chr (237),
	    'oacute' => chr (243),
	    'uacute' => chr (250),
	    'Aacute' => chr (193),
	    'Eacute' => chr (201),
	    'Iacute' => chr (205),
	    'Oacute' => chr (211),
	    'Uacute' => chr (218),
	    'agrave' => chr (224),
	    'egrave' => chr (232),
	    'igrave' => chr (236),
	    'ograve' => chr (242),
	    'ugrave' => chr (249),
	    'Agrave' => chr (192),
	    'Egrave' => chr (200),
	    'Igrave' => chr (204),
	    'Ograve' => chr (210),
	    'Ugrave' => chr (217),
	    'ntilde' => chr (241),
	    'Ntilde' => chr (209),
	    'atilde' => chr (227),
	    'Atilde' => chr (195),
	    'otilde' => chr (245),
	    'Otilde' => chr (213),
	    'ccedil' => chr (231),
	    'Ccedil' => chr (199),
	    'ecirc' => chr (234),
	    'Ecirc' => chr (202),
	    'acirc' => chr (226),
	    'Acirc' => chr (194),
	    );

my $hand_made = 0;

sub print_usage {
    print STDERR "\n";
    print STDERR "translate.pl: Uses gimp to generate any images required by a\n";
    print STDERR "              Greenstone macro file.\n\n";
    print STDERR "  usage: $0 [options] macrofile\n\n";
    print STDERR "  options:\n";
    print STDERR "   -save_orig_file       edited macrofile will be written to\n";
    print STDERR "                         macrofile.new leaving macrofile unchanged\n";
    print STDERR "   -language_symbol      ISO abbreviation of language (e.g. German=de,\n";
    print STDERR "                         French=fr, Maori=mi)\n";
    print STDERR "   -image_dir directory  full path to directory in which to create images\n";
    print STDERR "                         (defaults to `pwd`/images)\n\n";
}

sub gsdl_translate {

    if (!parsargv::parse(\@ARGV, 
			 'save_orig_file', \$save_orig_file,
			 'language_symbol/[A-Za-z]{2}', \$language_symbol,
			 'image_dir/.*/images', \$image_dir)) {
	&print_usage();
	die "\n";
    }

    if ($image_dir eq "images") {
	$image_dir = `pwd`;
	chomp $image_dir;
	$image_dir = &util::filename_cat ($image_dir, "images");
    }

    if (!defined $ARGV[0]) {
	print STDERR "no macro file supplied\n\n";
	&print_usage();
	die "\n";
    }
    my $macrofile = $ARGV[0];
    die "\nmacrofile $macrofile does not exist\n\n" unless -e $macrofile;

    if (!-e $image_dir) {
	mkdir ($image_dir, 511) || die "\ncouldn't create image_dir $image_dir\n\n";
    }

    open (INPUT, $macrofile) || die "\ncouldn't open $macrofile for reading\n\n";
    open (OUTPUT, ">$macrofile.new") || die "\ncouldn't open temporary file $macrofile.new for writing\n\n";

    &parse_file (INPUT, OUTPUT);

    close OUTPUT;
    close INPUT;

    if (!$save_orig_file) {
	`mv $macrofile.new $macrofile`;
    }

    print STDERR "\n\n";
    print STDERR "translation of macro file $macrofile completed\n";
    print STDERR "the translated macro file is $macrofile.new\n" if $save_orig_file;
    print STDERR "\n";
    if ($hand_made) {
	print STDERR "$hand_made hand made images were found within $macrofile,\n";
	print STDERR "these will need to be made by hand (grep $macrofile for 'hand_made'\n\n";
    }
    print STDERR "To add your new interface translation to Greenstone you'll need to:\n";
    print STDERR "  1. Copy your new macro file to your GSDLHOME/macros directory\n";
    print STDERR "  2. Add your new macro file to the macrofiles list in your\n";
    print STDERR "     GSDLHOME/etc/main.cfg configuration file\n";
    print STDERR "  3. Copy your newly created images from $image_dir to \n";
    print STDERR "     GSDLHOME/images/$language_symbol/\n\n";
    print STDERR "Access your new interface language by setting the language (l) cgi\n";
    print STDERR "argument to '$language_symbol'\n\n";

}

sub parse_file {
    my ($input, $output) = @_;

    undef $/;
    my $dmfile = <$input>;
    $/ = "\n";

    # process all the images

    $dmfile =~ s/(?:^|\n)\#\#\s*\"([^\"]*)\"\s*\#\#\s*([^\s\#]*)\s*\#\#\s*([^\s\#]*)\s*\#\#(.*?)(?=(\n\#|\s*\Z))/&process_image ($1, $2, $3, $4)/esg;

    # add language parameter to each macro
    $dmfile =~ s/(\n\s*)(_[^_]*_)\s*(\[[^\]]*\])?\s*\{/$1 . &add_language_param ($2, $3)/esg;
    
    print $output $dmfile;
}

sub process_image {
    my ($text, $image_type, $image_name, $image_macros) = @_;

    my $origtext = $text;

    $text =~ s/&(\d{3,4});/chr($1)/ge;
    $text =~ s/&([^;]*);/$rmap{$1}/g;

    # Default font is set by the individual scripts (flash_button-1.2.pl etc), usually lucida
    my $fontchoice = "";

    # special case for Kazakh images (can also handle Russian) - encode to match Kazakh font
    if ($language_symbol eq "kz") {  # || $language_symbol eq "ru") {
	$text = &unicode::unicode2singlebyte(&unicode::utf82unicode($text), "kazakh");
	$fontchoice = " -foundry 2rebels -fontname \"helv kaz\"";
    }
    # special case for Russian images - font is koi8-r encoded
    elsif ($language_symbol eq "ru") {
	$text = &unicode::unicode2singlebyte(&unicode::utf82unicode($text), "koi8_r");
	$fontchoice = " -foundry cronyx -fontname helvetica";
    }
    # special case for Thai images
    elsif ($language_symbol eq "th") {
	$text = &unicode::unicode2singlebyte(&unicode::utf82unicode($text), "windows_874");
	$fontchoice = " -foundry monotype -fontname BrowalliaUPC -fontregistry tis620";
    }
    # special case for Ukrainian images - font is windows_1251 encoded 
    elsif ($language_symbol eq "uk") {
	$text = &unicode::unicode2singlebyte(&unicode::utf82unicode($text), "windows_1251");
	$fontchoice = " -foundry rfx -fontname serene";
    }

    # edit image macros
    $image_macros =~ s/(_httpimg_\/)(?:[^\/\}]*\/)?([^\}]*\.(?:gif|jpe?g|png))/$1$language_symbol\/$2/gs;

    if ($image_type eq "top_nav_button") {

	# generate images
	my $options = "-text \"$text\" -filenamestem $image_name -image_dir $image_dir";
	$options .= " -height 20 -whitespace";
	$options .= $fontchoice;

	# special case for Kazakh images (can also handle Russian)
	if ($language_symbol eq "kz") {  # || $language_symbol eq "ru") {
	    $options .= " -fontsize 10 -fontweight bold";
	}
	# special case for Russian images
	elsif ($language_symbol eq "ru") {
	    $options .= " -fontsize 10 -fontweight bold";
	}
	# special case for Thai images
	elsif ($language_symbol eq "th") {
	    $options .= " -fontsize 20 -fontweight bold";  # Browallia
	}
	# special case for Ukrainian images
	elsif ($language_symbol eq "uk") {
	    $options .= " -fontsize 10";
	}
	else {
	    $options .= " -fontsize 12";
	}
	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# get width of new images and edit width macro
	# my $fullfilename = &util::filename_cat ($image_dir, "${image_name}on.gif");
	# &process_width_macro ($fullfilename, $image_name, \$image_macros);

    }
    elsif ($image_type eq "nav_bar_button") {

	# generate on and off images
	my $options = "-text \"$text\" -filenamestem $image_name -image_dir $image_dir";
	$options .= " -height 17 -fixed_width -width 87";
	$options .= $fontchoice;

	# special case for Thai images
	if ($language_symbol eq "th") {
	    $options .= " -fontsize 18 -fontweight bold";  # Browallia
	}
	else {
	    $options .= " -fontsize 17";
	}

	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# generate green image
	$options = "-text \"$text\" -filenamestem ${image_name}gr -image_dir $image_dir";
	$options .= " -height 17 -fixed_width -width 87";
	$options .= " -bgcolor \"#96c19b\"";
	$options .= $fontchoice;

	# special case for Thai images
	if ($language_symbol eq "th") {
	    $options .= " -fontsize 18 -fontweight bold";  # Browallia
	}
	else {
	    $options .= " -fontsize 17";
	}

	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# delete the unused light image
	unlink(util::filename_cat($image_dir, "${image_name}gr" . "of.gif"));

	# rename the dark image
	&util::mv(util::filename_cat($image_dir, "${image_name}gr" . "on.gif"),
		util::filename_cat($image_dir, "$image_name" . "gr.gif"));

	# get width of new images and edit width macro
	my $fullfilename = &util::filename_cat ($image_dir, "${image_name}on.gif");
	&process_width_macro ($fullfilename, $image_name, \$image_macros);

    }
    elsif ($image_type eq "document_button") {

	# generate on and off images
	my $options = "-text \"$text\" -filenamestem $image_name -image_dir $image_dir";
	$options .= " -fixed_width -whitespace";
	$options .= $fontchoice;

	# special case for Kazakh images (can also handle Russian)
	if ($language_symbol eq "kz") {  # || $language_symbol eq "ru") {
	    $options .= " -fontsize 8";
	}
	# special case for Russian images
	elsif ($language_symbol eq "ru") {
	    $options .= " -fontsize 8";
	}
	# special case for Thai images
	elsif ($language_symbol eq "th") {
	    $options .= " -fontsize 22 -fontweight bold";  # Browallia
	}
	# special case for Ukrainian images
	elsif ($language_symbol eq "uk") {
	    $options .= " -fontsize 8";
	}
	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# get width of new images and edit width macro
	# my $fullfilename = &util::filename_cat ($image_dir, "${image_name}on.gif");
	# &process_width_macro ($fullfilename, $image_name, \$image_macros);

    }
    elsif ($image_type eq "collector_bar_button") {

	$text =~ s/\\n/\n/g;
	if ($text !~ /\n/) {
	    # Format the text so it is centered, one word per line
	    local @textparts = split(/[ \t\n]+/, $text);
	    local $maxlength = 0;
	    for ($i = 0; $i < scalar(@textparts); $i++) {
		if (length($textparts[$i]) > $maxlength) {
		    $maxlength = length($textparts[$i]);
		}
	    }
	    $text = "";
	    for ($i = 0; $i < scalar(@textparts); $i++) {
		if (length($textparts[$i]) < $maxlength) {
		    $text .= ' ' x ((($maxlength - length($textparts[$i])) / 2) + 1);
		}
		$text .= $textparts[$i] . "\n";
	    }
	}

	# generate on and off images (yellow)
	my $options = "-text \"$text\" -filenamestem yc$image_name -image_dir $image_dir";
	$options .= " -width 77 -height 26 -fixed_width -whitespace -fontsize 13";
	$options .= $fontchoice;

	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# generate on and off images (green)
	$options = "-text \"$text\" -filenamestem gc$image_name -image_dir $image_dir";
	$options .= " -width 77 -height 26 -fixed_width -whitespace -fontsize 13";
	$options .= " -bgcolor \"#96c19b\"";
	$options .= $fontchoice;

	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# generate on and off images (grey) - only the light image (off) is used
	$options = "-text \"$text\" -filenamestem nc$image_name -image_dir $image_dir";
	$options .= " -width 77 -height 26 -fixed_width -whitespace -fontsize 13";
	$options .= " -bgcolor \"#7E7E7E\" -fontcolor \"#a0a0a0\"";
	$options .= $fontchoice;

	`$ENV{'GSDLHOME'}/bin/script/gimp/flash_button-1.2.pl $options`;

	# delete the unused dark image
	unlink(util::filename_cat($image_dir, "nc$image_name" . "on.gif"));

    }
    elsif ($image_type eq "green_bar_left_aligned") {

	# generate green bar image (we're assuming these bars are always 537
	# pixels and are never stretched by excess text
	my $options = "-text \"$text\" -filename ${image_name}.gif -image_dir $image_dir";
	$options .= " -dont_center -width 537 -width_space 15";
	$options .= $fontchoice;

	# special case for Thai images
	if ($language_symbol eq "th") {
	    $options .= " -fontsize 18 -fontweight bold";  # Browallia
	}

	`$ENV{'GSDLHOME'}/bin/script/gimp/green_bar-1.2.pl $options`;

    }
    elsif ($image_type eq "green_title") {
	
	# read the width if it is specified in $image_macros
        my ($width) = $image_macros =~ /_width${image_name}x?_\s*[^\{]*\{(\d+)\}/;
        $width = 200 unless ($width);

        # generate green title image
	my $options = "-text \"$text\" -filename ${image_name}.gif -image_dir $image_dir";
	$options .= " -width $width -height 57 -stripe_alignment right -text_alignment right";
        $options .= $fontchoice;

        # special case for Thai images
        if ($language_symbol eq "th") {
	    $options .= " -fontsize 50 -fontweight bold";  # Browallia
	}
        else {
	    $options .= " -fontsize 26 -fontweight bold";
	}

	`$ENV{'GSDLHOME'}/bin/script/gimp/title_icon-1.2.pl $options`;

	# get width of resulting image and edit _width..._ macro in $image_macros
        # (no longer needed since we always resize to the width read from $image_macros.)
        # my $fullfilename = &util::filename_cat ($image_dir, "${image_name}.gif");
	# &process_width_macro ($fullfilename, $image_name, \$image_macros);

    }
    elsif ($image_type eq "hand_made") {

	$hand_made ++;

    }
    else {
	
	print STDERR "WARNING (translate.pl): unknown image type found ($image_type)\n";

    }

    return "\n\#\# \"$origtext\" \#\# $image_type \#\# $image_name \#\#$image_macros";
}

sub process_width_macro {
    my ($filename, $image_name, $image_macros) = @_;

    my $img_info = &get_img_info ($filename);
    $$image_macros =~ s/(_width${image_name}x?_\s*(?:\[[^\]]*\])?\s*\{)(\d+)(\})/$1$img_info->{'width'}$3/s;
}

sub add_language_param {
    my ($macroname, $paramlist) = @_;

    my $first = 1;
    if (defined $paramlist) {
	$paramlist =~ s/^\[//;
	$paramlist =~ s/\]$//;
	my @params = split /\,/, $paramlist;
	$paramlist = "";
	foreach $param (@params) {
	    # remove any existing language parameter
	    if ($param !~ /^l=/) {
		$paramlist .= "," unless $first;
		$paramlist .= $param;
		$first = 0;
	    }
	}
    }
    $paramlist .= "," unless $first;
    $paramlist .= "l=" . $language_symbol;
    return "$macroname [$paramlist] {";
}

sub get_img_info {
    my ($imagefile) = @_;
    my %info = ();

    if (!-r $imagefile) {
	print STDERR "ERROR (translate.pl): couldn't open $imagefile to get dimensions\n";
	$info{'width'} = 0;
	$info{'height'} = 0;
    } else {
	my $image = gimp_file_load (RUN_NONINTERACTIVE, $imagefile, $imagefile);
	$info{'width'} = gimp_image_width ($image);
	$info{'height'} = gimp_image_height ($image);
    }

    return \%info;
}

sub query {

  gimp_install_procedure("gsdl_translate", "translate macro files and create images",
                        "", "Stefan Boddie", "Stefan Boddie", "2000-03-14",
                        "<Toolbox>/Xtns/gsdl_translate", "*", &PROC_EXTENSION,
                        [[PARAM_INT32, "run_mode", "Interactive, [non-interactive]"]], []);
}

Gimp::on_net {   gsdl_translate; };
exit main;
