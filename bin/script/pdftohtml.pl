#!/usr/bin/perl -w


###########################################################################
#
# pdftohtml.pl -- convert PDF documents to HTML format
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

# pdftohtml.pl is a wrapper for running pdftohtml utility which converts
# PDF documents to HTML, and converts images to PNG format for display in
# the HTML pages generated

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
# note - we don't actually ever use most of these options...
print STDERR  
    ("pdftohtml.pl wrapper for pdftohtml.\n",
     "Usage: pdftohtml [options] <PDF-file> <html-file>\n",
     "Options:\n",
     "\t-i\tignore images (don't extract)\n",
     "\t-a\tallow images only (continue even if no text is present)\n",
     "\t-c\tproduce complex output (requires ghostscript)\n",
     "\t-hidden\tExtract hidden text\n",
     "\t-zoom\tfactor by which to zoom the PDF (only useful if -c is set)\n"
     );
exit (1);
}

sub main {
    my (@ARGV) = @_;
    my ($allow_no_text, $ignore_images, $complex, $zoom, $hidden);
    
    # read command-line arguments so that
    # you can change the command in this script
    if (!parsargv::parse(\@ARGV,
			 'a', \$allow_no_text,
			 'i', \$ignore_images,
			 'c', \$complex,
			 'hidden', \$hidden,
			 'zoom/\d+/2', \$zoom,
			 ))
    {
	print_usage();
    }

    # Make sure the input file exists and can be opened for reading
    if (scalar(@ARGV) != 2) {
	print_usage();
    }

    my $input_filename = $ARGV[0];
    my $output_filestem = $ARGV[1];

    $output_filestem =~ s/\.html$//i; # pdftohtml adds this suffix

    # test that the directories exist to create the output file, or
    # we should exit immediately. (File:: is included by util.pm)
    my $output_dir =  File::Basename::dirname($output_filestem);
    if (! -d $output_dir || ! -w $output_dir) {
	die "pdftohtml.pl: cannot write to directory $output_dir\n";
    }

    my @dir = split (/(\/|\\)/, $input_filename);
    my $input_basename = pop(@dir);
    $input_basename =~ s/\.pdf//i;
    my $dir = join ("", @dir);

    if (!-r $input_filename) {
	print STDERR "Error: unable to open $input_filename for reading\n";
	exit(1);
    }

    # Heuristical code removed due to pdftohtml being "fixed" to not
    # create bitmaps for each char in some pdfs. However, this means we
    # now create .html files even if we can't extract any text. We should
    # check for that now instead someday...


    # formulate the command
    my $cmd = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "pdftohtml");

    # don't include path on windows (to avoid having to play about
    # with quoting when GSDLHOME might contain spaces) but assume
    # that the PATH is set up correctly.
    $cmd = "pdftohtml" if ($ENV{'GSDLOS'} =~ /^windows$/);

    $cmd .= " -i" if ($ignore_images);
    $cmd .= " -c" if ($complex);
    $cmd .= " -hidden" if ($hidden);
    $cmd .= " -zoom $zoom";
    $cmd .= " -noframes -p -enc UTF-8 \"$input_filename\" \"$output_filestem.html\"";

# system() returns -1 if it can't run, otherwise it's $cmds ret val.
    # note we return 0 if the file is "encrypted"
    $!=0;
    if (system($cmd)!=0) {
	print STDERR "pdftohtml error for $input_filename $!\n";
	# leave these for gsConvert.pl...
	#&FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");
	#&FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
	return 1;
    }

    if (! -e "$output_filestem.html") {
	return 1;
    }

# post-process to remove </b><b> and </i><i>, as these break up
# words, screwing up indexing and searching.
# At the same time, check that our .html file has some textual content.
    &FileUtils::moveFiles("$output_filestem.html","$output_filestem.html.tmp");
    $!=0;
    open INFILE, "$output_filestem.html.tmp" ||
	die "Couldn't open file: $!";
    open OUTFILE, ">$output_filestem.html" ||
	die "Couldn't open file for writing: $!";
    my $line;
    my $seen_textual_content=$allow_no_text;
    # check for unicode byte-order marker at the start of the file
    $line = <INFILE>;
    $line =~ s#\376\377##g;
    while ($line) {
	$line =~ s#</b><b>##g;
	$line =~ s#</i><i>##g;
	$line =~ s#\\#\\\\#g; # until macro language parsing is fixed...
# check for any extracted text
	if ($seen_textual_content == 0) {
	    my $tmp_line=$line;
	    $tmp_line =~ s/<[^>]*>//g;
	    $tmp_line =~ s/Page\s\d+//;
	    $tmp_line =~ s/\s*//g;
	    if ($tmp_line ne "") {
		$seen_textual_content=1;
	    }
	    # special - added to remove the filename from the title
	    # this should be in the header, before we see "textual content"
	    if ($line =~ m@<title>(.*?)</title>@i) {
		my $title=$1;
		
		# is this title the name of a filename?
		if (-r "$title.pdf" || -r "$title.html") {
		    # remove the title
		    $line =~ s@<title>.*?</title>@<title></title>\n<META NAME=\"filename\" CONTENT=\"$title\">@i;
		}
	    }
	}

	# relative hrefs to own document...
	$line =~ s@href=\"$input_basename\.html\#@href=\"\#@go;
# escape underscores, but not if they're inside tags (eg img/href names)
	my $inatag = 0; # allow multi-line tags
	if ($line =~ /_/) {
	    my @parts=split('_',$line);
	    my $lastpart=pop @parts;
	    foreach my $part (@parts) {
		if ($part =~ /<[^>]*$/) { # if we're starting a tag...
		    $inatag=1;
		} elsif ($part =~ />[^<]*$/) { # closing a tag
		    $inatag=0;
		}
		if ($inatag) {
		    $part.='_';
		} else {
		    $part.="&#95;";
		}
	    }
	    $line=join('',@parts,$lastpart);
	}

	print OUTFILE $line;
	$line = <INFILE>;
    }
    close INFILE;
    close OUTFILE;
    &FileUtils::removeFiles("$output_filestem.html.tmp");

    # Need to convert images from PPM format to PNG format
    my @images;

    my $directory=$output_filestem;
    $directory =~ s@[^\/]*$@@;    # assume filename has no embedded slashes...
    # newer versions of pdftohtml don't seem to do images this way anymore?
    if (open (IMAGES, "${directory}images.log") || 
	open (IMAGES, "${directory}image.log")) {
	while (<IMAGES>) {
	    push (@images, $_);
	}
	close IMAGES;
	&FileUtils::removeFiles("${directory}image.log") if (-e "${directory}image.log");

    }

    # no need to go any further if there is no text extracted from pdf.
    if ($seen_textual_content == 0) {
	print STDERR "Error: PDF contains no extractable text\n";
	# remove images...
	for $image (@images) {
	    chomp($image);
	    &FileUtils::removeFiles("${directory}$image");
	}
	return 1;
    }



    for $image (@images) {
	chomp($image);
	my $cmd = "";
	if ($ENV{'GSDLOS'} =~ /^windows/i) {
	    $cmd = "pnmtopng \"${directory}$image\"";
	    if (system($cmd)!=0) {
		print STDERR "Error executing $cmd\n";
		#return 1; # not sure about whether to leave this one in or take it out
		next;
	    }
	} else {
	    my @nameparts = split(/\./, $image);
	    my $image_base = shift(@nameparts);
	    $cmd = "pnmtopng \"${directory}$image\" > \"${directory}$image_base.png\" 2>/dev/null";
	    if (system($cmd)!=0) {
		$cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl convert \"${directory}$image\" \"${directory}$image_base.png\" 2>/dev/null";
		if (system($cmd)!=0) {
		    print STDERR "Cannot convert $image into PNG format (tried `pnmtopng' and `convert')...\n";
		    #return 1; # not sure about whether to leave this one in or take it out
		    next;
		}
	    }
	}
	&FileUtils::removeFiles($image);
    }

    return 0;
}

# indicate our error status, 0 = success
exit (&main(@ARGV));

