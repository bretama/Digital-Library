#!/usr/bin/perl -w


###########################################################################
#
# pdfpstoimg.pl -- convert PDF or PS documents to various types of Image format
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
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
# pdfpstoimg.pl is a wrapper for running the ImageMagick 'convert' utility 
# which converts PDF and PS documents to various types of image (e.g. PNG, 
# GIF, JPEG format). We then create an item file to join the images together
# into a document. The item file will be processed by PagedImagePlugin

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use parsargv;
use util;
use FileUtils;
use Cwd;
use File::Basename;

sub print_usage {
    print STDERR  
	("pdfpstoimg.pl wrapper for converting PDF or PS files to a series of images.\n",
	 "Usage: pdfpstoimg.pl [options] <PDF/PS-file> <output-filestem>>\n",
	 "Options:\n",
	 "\t-convert_to\toutput image type (gif, jpg, png) \n"
	 );
    exit (1);
}

sub main {
    my (@ARGV) = @_;
    my ($convert_to);
    
    # read command-line arguments so that
    # you can change the command in this script
    if (!parsargv::parse(\@ARGV,
			 'convert_to/.*/^', \$convert_to,
			 )) {
    	print_usage();
    }
    
    # Make sure the user has specified both input and output files
    if (scalar(@ARGV) != 2) {
	print_usage();
    }
    
    my $input_filename = $ARGV[0];
    my $output_filestem = $ARGV[1];
    
    # test that the directories exist to create the output file, or
    # we should exit immediately. 
    &FileUtils::makeDirectory($output_filestem) if (!-e $output_filestem);
	    
    my @dir = split (/(\/|\\)/, $input_filename);
    my $input_basename = pop(@dir);
    $input_basename =~ s/\.(pdf|ps)$//i;
    my $dir = join ("", @dir);

    if (!-r $input_filename) {
	print STDERR "Error: unable to open $input_filename for reading\n";
	exit(1);
    }
    # don't include path on windows (to avoid having to play about
    # with quoting when GSDLHOME might contain spaces) but assume
    # that the PATH is set up correctly.
    $cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl convert";

    my $output_filename = &FileUtils::filenameConcatenate($output_filestem, $input_basename);
    if ($convert_to eq "gif") {
	$cmd .= " \"$input_filename\" \"$output_filename-%02d.$convert_to\"";
    } else {
	$cmd .= " \"$input_filename\" \"$output_filename.$convert_to\"";
    }	
 
    # system() returns -1 if it can't run, otherwise it's $cmds ret val.
    # note we return 0 if the file is "encrypted"
    $!=0;
    my $status = system($cmd);
    if ($status != 0) {
	print STDERR "Convert error for $input_filename $!\n";
	# leave these for gsConvert.pl...
	#&FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");
	#&FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
	return 1;
    } else {
	# command execute successfully
	&util::create_itemfile($output_filestem, $input_basename, $convert_to);
    }
    return 0;
}

# indicate our error status, 0 = success
exit (&main(@ARGV));



