#!/usr/bin/perl -w

###########################################################################
#
# gsConvert.pl -- convert documents to HTML or TEXT format
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2002 New Zealand Digital Library Project
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

# gsConvert.pl converts documents in a range of formats to HTML or TEXT
# by exploiting third-party programs.  The sources of these are usually found
# in the $GSDLHOME/packages directory, and the executables should live in
# $GSDLHOME/bin/$GSDLOS (which is on the search path).
#
# Currently, we can convert the following formats by using external
# conversion utilities:
# Microsoft Word (versions 2,6,7 [==95?], 8[==97?], 9[==2000?]), RTF,
# Adobe PDF, PostScript, MS PowerPoint (95 and 97), and MS Excel (95 and 97).
#
# We can try to convert any file to text with a perl implementation of the
# UNIX strings command.
#
# We try to convert Postscript files to text using "gs" which is often on
# *nix machines. We fall back to performing weak text extraction by using
# regular expressions.

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;

use parsargv;
use util;
use FileUtils;
use Cwd;

# Are we running on WinNT or Win2000 (or later)?
my $is_winnt_2000=eval {require Win32; return (Win32::IsWinNT()); return 0;};
if (!defined($is_winnt_2000)) {$is_winnt_2000=0;}

my $use_strings;
my $pdf_complex;
my $pdf_nohidden;
my $pdf_zoom;
my $pdf_ignore_images;
my $pdf_allow_images_only;
my $windows_scripting;

sub print_usage
{
    print STDERR "\n";
    print STDERR "gsConvert.pl: Converts documents in a range of formats to html\n";
    print STDERR "              or text using third-party programs.\n\n";
    print STDERR "  usage: $0 [options] filename\n";
    print STDERR "  options:\n\t-type\tdoc|dot|pdf|ps|ppt|rtf|xls\t(input file type)\n";
    print STDERR "\t-errlog\t<filename>\t(append err messages)\n";
    print STDERR "\t-output\tauto|html|text|pagedimg_jpg|pagedimg_gif|pagedimg_png\t(output file type)\n";
    print STDERR "\t-timeout\t<max cpu seconds>\t(ulimit on unix systems)\n";
    print STDERR "\t-use_strings\tuse strings to extract text if conversion fails\n";
    print STDERR "\t-windows_scripting\tuse windows VB script (if available) to convert Microsoft Word and PPT documents\n";
    print STDERR "\t-pdf_complex\tuse complex output when converting PDF to HTML\n";
    print STDERR "\t-pdf_nohidden\tDon't attempt to extract hidden text from PDF files\n";
    print STDERR "\t-pdf_ignore_images\tdon't attempt to extract images when\n";
    print STDERR "\t\tconverting PDF to HTML\n";
    print STDERR "\t-pdf_allow_images_only\tallow images only (continue even if no text is present when converting to HTML)\n";
    print STDERR "\t-pdf_zoom\tfactor by which to zoom PDF (only useful if\n";
    print STDERR "\t\t-pdf_complex is set\n";
    exit(1);
}

my $faillogfile="";
my $timeout=0;
my $verbosity=0;

sub main
{
    my (@ARGV) = @_;
    my ($input_type,$output_type,$verbose);

	# Dynamically figure out what the --type option can support, based on whether -windows_scripting 
	# is in use or not
	my $default_type_re = "(doc|dot|pdf|ps|ppt|rtf|xls)";
	#my $enhanced_type_re = "(docx?|dot|pdf|ps|pptx?|rtf|xlsx?)";
	#my $enhanced_type_re = "(docx?|dot|pdf|ps|pptx?|rtf|xlsx?)";
	# Currently only have VBA for Word and PPT(but no XLS)
	my $enhanced_type_re = "(docx?|dot|pdf|ps|pptx?|rtf|xls)";

	my $type_re = $default_type_re;
	
    foreach my $a (@ARGV) {
		if ($a =~ m/^windows_scripting$/i) {
			$type_re = $enhanced_type_re;
		}
	}
	
    # read command-line arguments
    if (!parsargv::parse(\@ARGV,
			 "type/$type_re/", \$input_type,
			 '/errlog/.*/', \$faillogfile,
			 'output/(auto|html|text|pagedimg).*/', \$output_type,
			 'timeout/\d+/0',\$timeout,
			 'verbose/\d+/0', \$verbose,
			 'windows_scripting',\$windows_scripting,
			 'use_strings', \$use_strings,
			 'pdf_complex', \$pdf_complex,
			 'pdf_ignore_images', \$pdf_ignore_images,
			 'pdf_allow_images_only', \$pdf_allow_images_only,
			 'pdf_nohidden', \$pdf_nohidden,
			 'pdf_zoom/\d+/2', \$pdf_zoom
			 ))
    {
	print_usage();
    }

	$verbosity=$verbose if defined $verbose;
	 
    # Make sure the input file exists and can be opened for reading
    if (scalar(@ARGV!=1)) {
	print_usage();
    }

    my $input_filename = $ARGV[0];
    if (!-r $input_filename) {
	print STDERR "Error: unable to open $input_filename for reading\n";
	exit(1);
    }

    # Deduce filenames
    my ($tailname,$dirname,$suffix) 
	= File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");
    my $output_filestem = &FileUtils::filenameConcatenate($dirname, "$tailname");

    if ($input_type eq "")
    {
	$input_type = lc (substr($suffix,1,length($suffix)-1));
    }
    
    # Change to temporary working directory
    my $stored_dir = cwd();
    chdir ($dirname) || die "Unable to change to directory $dirname";

    # Select convert utility
    if (!defined $input_type) {
	print STDERR "Error: No filename extension or input type defined\n";
	exit(1);
    } 
    elsif ($input_type =~ m/^docx?$/ || $input_type eq "dot") {
	print &convertDOC($input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    elsif ($input_type eq "rtf") {
	print &convertRTF($input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    elsif ($input_type eq "pdf") {
	print &convertPDF($dirname, $input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    elsif ($input_type eq "ps") {
	print &convertPS($dirname, $input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    elsif ($input_type =~ m/pptx?$/) {
	print &convertPPT($input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    elsif ($input_type =~ m/xlsx?$/) {
	print &convertXLS($input_filename, $output_filestem, $output_type);
	print "\n";
    } 
    else {
	print STDERR "Error: Unable to convert type '$input_type'\n";
	exit(1);
    }
    
    # restore to original working directory
    chdir ($stored_dir) || die "Unable to return to directory $stored_dir";

}

&main(@ARGV);



# Document-type conversion functions
#
# The following functions attempt to convert documents from their
# input type to the specified output type.  If no output type was
# given, then they first attempt HTML, and then TEXT.
#
# Each returns the output type ("html" or "text") or "fail" if no 
# conversion is possible.

# Convert a Microsoft word document

sub convertDOC {
    my ($input_filename, $output_filestem, $output_type) = @_;

    # Many .doc files are not in fact word documents!
    my $realtype = &find_docfile_type($input_filename);

    if ($realtype eq "word6" || $realtype eq "word7" 
		|| $realtype eq "word8" || $realtype eq "docx") {
	return &convertWord678($input_filename, $output_filestem, $output_type);
    } elsif ($realtype eq "rtf") {
	return &convertRTF($input_filename, $output_filestem, $output_type);
    } else {
	return &convertAnything($input_filename, $output_filestem, $output_type);
    }
}

# Convert a Microsoft word 6/7/8 document

sub convertWord678 {
    my ($input_filename, $output_filestem, $output_type) = @_;

    my $success = 0;
    if (!$output_type || ($output_type =~ m/html/i)){
	if ($windows_scripting) {
	    $success = &native_doc_to_html($input_filename, $output_filestem);
	}
	else {
	    $success = &doc_to_html($input_filename, $output_filestem);	   
	}
	if ($success) {
	   return "html";
	}
    }
    return &convertAnything($input_filename, $output_filestem, $output_type);
}


# Convert a Rich Text Format (RTF) file

sub convertRTF {
    my ($input_filename, $output_filestem, $output_type) = @_;

    my $success = 0;

    # Attempt specialised conversion to HTML
    if (!$output_type || ($output_type =~ m/html/i)) {

	if ($windows_scripting) {
	    $success = &native_doc_to_html($input_filename, $output_filestem);
	}
	else {
	    $success = &rtf_to_html($input_filename, $output_filestem);
	}
	if ($success) {
	    return "html";
	}
    }

# rtf is so ugly that's it's not worth running strings over.
# One day I'll write some quick'n'dirty regexps to try to extract text - jrm21
#    return &convertAnything($input_filename, $output_filestem, $output_type);
    return "fail";
}


# Convert an unidentified file

sub convertAnything {
    my ($input_filename, $output_filestem, $output_type) = @_;
    
    my $success = 0;
  
    # Attempt simple conversion to HTML
    if (!$output_type || ($output_type =~ m/html/i)) {
	$success = &any_to_html($input_filename, $output_filestem);
	if ($success) {
	    return "html";
	}
    }

    # Convert to text
    if (!$output_type || ($output_type =~ m/text/i)) {
	$success = &any_to_text($input_filename, $output_filestem);
	if ($success) {
	    return "text";
	}
    }
    return "fail";
}



# Convert an Adobe PDF document

sub convertPDF {
    my ($dirname, $input_filename, $output_filestem, $output_type) = @_;

    my $success = 0;
    $output_type =~ s/.*\-(.*)/$1/i;
    # Attempt coversion to Image
    if ($output_type =~ m/jp?g|gif|png/i) {
	$success = &pdfps_to_img($dirname, $input_filename, $output_filestem, $output_type);
	if ($success){
	    return "item";
	}
    }

    # Attempt conversion to HTML
    if (!$output_type || ($output_type =~ m/html/i)) {
	$success = &pdf_to_html($dirname, $input_filename, $output_filestem);
	if ($success) {
	    return "html";
	}
    }

    # Attempt conversion to TEXT
    if (!$output_type || ($output_type =~ m/text/i)) {
	$success = &pdf_to_text($dirname, $input_filename, $output_filestem);
	if ($success) {
	    return "text";
	}
    }

    return "fail";

}


# Convert an Adobe PostScript document

sub convertPS {
    my ($dirname,$input_filename, $output_filestem, $output_type) = @_;

    my $success = 0;
    $output_type =~ s/.*\-(.*)/$1/i;
    # Attempt coversion to Image
    if ($output_type =~ m/jp?g|gif|png/i) {
	$success = &pdfps_to_img($dirname, $input_filename, $output_filestem, $output_type);
	if ($success){
	    return "item";
	}
    }

    # Attempt conversion to TEXT
    if (!$output_type || ($output_type =~ m/text/i)) {
	$success = &ps_to_text($input_filename, $output_filestem);
	if ($success) {
	    return "text";
	}
    }
    return "fail";
}


sub convertPPT {
    my ($input_filename, $output_filestem, $output_type) = @_;
    my $success = 0;

    my $ppt_convert_type = "";

    #if (!$output_type || $windows_scripting || ($output_type !~ m/html/i) || ($output_type !~ m/text/i)){
    if ($windows_scripting && ($output_type !~ m/html/i) && ($output_type !~ m/text/i)){
	if ($output_type =~ m/gif/i) {
	    $ppt_convert_type = "-g";
	} elsif ($output_type =~ m/jp?g/i){
	    $ppt_convert_type = "-j";
	} elsif ($output_type =~ m/png/i){
	    $ppt_convert_type = "-p";
	}
	my $vbScript = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin",
					   $ENV{'GSDLOS'}, "pptextract");
	$vbScript = "CScript //Nologo \"".$vbScript.".vbs\"" if ($ENV{'GSDLOS'} =~ m/^windows$/i); # now we use the .vbs VBScript
	# $vbScript = "pptextract" if ($ENV{'GSDLOS'} =~ m/^windows$/i); # back when the pptextract.exe VB executable was used
			
	my $cmd = "";
	if ($timeout) {$cmd = "ulimit -t $timeout;";}
	# if the converting directory already exists
	if (-d $output_filestem) {
	    print STDERR "**The conversion directory already exists\n";
	    return "item";
	} else {
	    $cmd .=  "$vbScript $ppt_convert_type \"$input_filename\" \"$output_filestem\"";
	    $cmd .= " 2>\"$output_filestem.err\""
		if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);

	    if (system($cmd) !=0) {
		print STDERR "Powerpoint VB Scripting convert failed\n";
	    } else {
		return "item";
	    }
	}
    } elsif (!$output_type || ($output_type =~ m/html/i)) {
	# Attempt conversion to HTML
	#if (!$output_type || ($output_type =~ m/html/i)) {
	# formulate the command
	my $cmd = "";
	my $full_perl_path = &util::get_perl_exec();
	$cmd .= "\"$full_perl_path\" -S ppttohtml.pl ";
	$cmd .= " \"$input_filename\" \"$output_filestem.html\"";
	$cmd .= " 2>\"$output_filestem.err\""
	    if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);

	# execute the command
	$!=0;
	if (system($cmd)!=0)
	{
	    print STDERR "Powerpoint 95/97 converter failed $!\n";
	} else {
	    return "html";
	}
    } 

    $success = &any_to_text($input_filename, $output_filestem);
    if ($success) {
	return "text";
    }
    
    return "fail";
}


sub convertXLS {
    my ($input_filename, $output_filestem, $output_type) = @_;

    my $success = 0;

    # Attempt conversion to HTML
    if (!$output_type || ($output_type =~ m/html/i)) {
	# formulate the command
	my $cmd = "";
	my $full_perl_path = &util::get_perl_exec();
	$cmd .= "\"$full_perl_path\" -S xlstohtml.pl ";
	$cmd .= " \"$input_filename\" \"$output_filestem.html\"";
	$cmd .= " 2>\"$output_filestem.err\""
	    if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);
	
	
	# execute the command
	$!=0;
	if (system($cmd)!=0)
	{
	    print STDERR "Excel 95/97 converter failed $!\n";
	} else {
	    return "html";
	}
    }

    $success = &any_to_text($input_filename, $output_filestem);
    if ($success) {
	return "text";
    }

    return "fail";
}



# Find the real type of a .doc file
#
# We seem to have a lot of files with a .doc extension that are .rtf 
# files or Word 5 files.  This function attempts to tell the difference.
sub find_docfile_type {
    my ($input_filename) = @_;
	
	if (($windows_scripting) && ($input_filename =~ m/\.docx$/)) {
		return "docx";
	}
	
    open(CHK, "<$input_filename");
    binmode(CHK);
    my $line = "";
    my $first = 1;

    while (<CHK>) {
    
	$line = $_;

	if ($first) {
	    # check to see if this is an rtf file
	    if ($line =~ m/^\{\\rtf/) {
		close(CHK);
		return "rtf";
	    }
	    $first = 0;
	}
	
	# is this is a word 6/7/8 document?
	if ($line =~ m/Word\.Document\.([678])/) {
	    close(CHK);

	    return "word$1";
	}

    }

    return "unknown";
}


# Specific type-to-type conversions
#
# Each of the following functions attempts to convert a document from 
# a specific format to another.  If they succeed they return 1 and leave 
# the output document(s) in the appropriate place; if they fail they 
# return 0 and delete any working files.


# Attempt to convert a word document to html with the wv program
sub doc_to_html {
    my ($input_filename, $output_filestem) = @_;

    my $wvware_status = 0;
	
    # need to ensure that the path to perl is quoted (in case there's spaces in it)
    my $launch_cmd = "\"".&util::get_perl_exec()."\" -S wvware.pl \"$input_filename\" \"$output_filestem\" \"$faillogfile\" $verbosity $timeout";    

#    print STDERR "***** wvware launch cmd = $launch_cmd\n";

    $wvware_status = system($launch_cmd)/256;
    return $wvware_status;
}

# Attempt to convert a word document to html with the word2html scripting program
sub native_doc_to_html {
    my ($input_filename, $output_filestem) = @_;

	# build up the path to the doc-to-html conversion tool we're going to use
	my $vbScript = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'});

    if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
		# if windows scripting with docx input, use new VBscript to get the local Word install (if
		# any) to do the conversion, since docX can't be processed by word2html's windows_scripting
		
		if($input_filename =~ m/docx$/i) {	# need to use full path to docx2html script, 
											# else script launch fails when there are error msgs
			$vbScript = &FileUtils::filenameConcatenate($vbScript, "docx2html.vbs"); 
			$vbScript = "CScript //Nologo \"$vbScript\"";	# launch with CScript for error output in STDERR
									# //Nologo flag avoids Microsoft's opening/logo msgs
			print STDERR "About to use windows scripting to process docx file $input_filename.\n";
			print STDERR "   This may take some time. Please wait...\n";
		} 
		else {	# old doc versions. use the usual VB executable word2html for the
				# conversion. Doesn't need full path, since bin\windows is on PATH			
			$vbScript = "word2html"; #$vbScript = "\"".&FileUtils::filenameConcatenate($vbScript, "word2html")."\"";
		}
    } 
	else { # not windows
		$vbScript = "\"".&FileUtils::filenameConcatenate($vbScript, "word2html")."\"";
	}

    if (-e "$output_filestem.html") {
	print STDERR "    The conversion file:\n";
	print STDERR "      $output_filestem.html\n";
	print STDERR "    ... already exists.  Skipping\n";
	return 1;
    }

    my $cmd = "";
    if ($timeout) {$cmd = "ulimit -t $timeout;";}
    #$cmd .= "$vbScript \"$input_filename\" \"$output_filestem.html\"";
    #$cmd .=  "$vbScript $input_filename $output_filestem.html";
    $cmd .=  "$vbScript \"$input_filename\" \"$output_filestem.html\"";

    # redirecting STDERR
	
	$cmd .= " 2> \"$output_filestem.err\""
		if ($ENV {'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);    
	#print STDERR "@@@@@@@@@ cmd=$cmd\n";
	
    # execute the command
    $!=0;
    if (system($cmd)!=0)
    {
	print STDERR "Error executing $vbScript converter:$!\n";
	if (-s "$output_filestem.err") {
	    open (ERRFILE, "<$output_filestem.err");
		
	    my $write_to_fail_log=0;
	    if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile")))
	    {$write_to_fail_log=1;}

	    my $line;
	    while ($line=<ERRFILE>) {
		if ($line =~ m/\w/) {
		    print STDERR "$line";
		    print FAILLOG "$line" if ($write_to_fail_log);
		}
		if ($line !~ m/startup error/) {next;}
		print STDERR " (given an invalid .DOC file?)\n";
		print FAILLOG " (given an invalid .DOC file?)\n"
		if ($write_to_fail_log);
		
	    } # while ERRFILE
	    close FAILLOG if ($write_to_fail_log);
	}
	return 0; # we can try any_to_text
    }

    # Was the conversion successful?
    if (-s "$output_filestem.html") {
	open(TMP, "$output_filestem.html");
	my $line = <TMP>;
	close(TMP);
	if ($line && $line =~ m/html/i) {
	    &FileUtils::removeFiles("$output_filestem.err") if -e "$output_filestem.err";
	    return 1;
	}
    }
	
    # If here, an error of some sort occurred
    &FileUtils::removeFiles("$output_filestem.html") if -e "$output_filestem.html";
    if (-e "$output_filestem.err") {
	if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile"))) {
	    open (ERRLOG,"$output_filestem.err");
	    while (<ERRLOG>) {print FAILLOG $_;}
	    close FAILLOG;
	    close ERRLOG;
	}
	&FileUtils::removeFiles("$output_filestem.err");
    }
    return 0;
}

# Attempt to convert an RTF document to html with rtftohtml
sub rtf_to_html {
    my ($input_filename, $output_filestem) = @_;

    # formulate the command
    my $cmd = "";
    if ($timeout) {$cmd = "ulimit -t $timeout;";}
    $cmd .= "rtftohtml";
    #$cmd .= "rtf-converter";

    $cmd .= " -o \"$output_filestem.html\" \"$input_filename\"";

    $cmd .= " 2>\"$output_filestem.err\""
        if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);


    # execute the command
    $!=0;
    if (system($cmd)!=0)
    {
	print STDERR "Error executing rtf converter $!\n";
	# don't currently bother printing out error log...
	# keep going, in case it still created an HTML file...
    }

    # Was the conversion successful?
    my $was_successful=0;
    if (-s "$output_filestem.html") {
	# make sure we have some content other than header
	open (HTML, "$output_filestem.html"); # what to do if fail?
	my $line;
	my $past_header=0;
	while ($line=<HTML>) {

	    if ($past_header == 0) {
		if ($line =~ m/<body>/) {$past_header=1;}
		next;
	    }

	    $line =~ s/<[^>]+>//g;
	    if ($line =~ m/\w/ && $past_header) {  # we found some content...
		$was_successful=1;
		last;
	    }
	}
	close HTML;
    }

    if ($was_successful) {
	&FileUtils::removeFiles("$output_filestem.err")
	    if (-e "$output_filestem.err");
	# insert the (modified) table of contents, if it exists.
	if (-e "${output_filestem}_ToC.html") {
	    &FileUtils::moveFiles("$output_filestem.html","$output_filestem.src");
	    my $open_failed=0;
	    open HTMLSRC, "$output_filestem.src" || ++$open_failed;
	    open TOC, "${output_filestem}_ToC.html" || ++$open_failed;
	    open HTML, ">$output_filestem.html" || ++$open_failed;
	    
	    if ($open_failed) {
		close HTMLSRC;
		close TOC;
		close HTML;
		&FileUtils::moveFiles("$output_filestem.src","$output_filestem.html");
		return 1;
	    }

	    # print out header info from src html.
	    while (defined($_ = <HTMLSRC>) && $_ =~ m/\w/) {
		print HTML "$_";
	    }

	    # print out table of contents, making links relative
	    <TOC>; <TOC>; # ignore first 2 lines
	    print HTML scalar(<TOC>); # line 3 = "<ol>\n"
	    my $line;
	    while ($line=<TOC>) {
		$line =~ s@</body></html>$@@i ; # only last line has this
		# make link relative
		$line =~ s@href=\"[^\#]+@href=\"@i;
		print HTML $line;
	    }
	    close TOC;

	    # rest of html src
	    while (<HTMLSRC>) {
		print HTML $_;
	    }
	    close HTMLSRC;
	    close HTML;

	    &FileUtils::removeFiles("${output_filestem}_ToC.html");
	    &FileUtils::removeFiles("${output_filestem}.src");
	}
	# we don't yet do anything with footnotes ($output_filestem_fn.html) :(
	return 1; # success
    }

    if (-e "$output_filestem.err") {
	if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile")))
	{
	    print FAILLOG "Error - rtftohtml - couldn't extract text\n";
	    #print FAILLOG "Error - rtf-converter - couldn't extract text\n";
	    print FAILLOG " (rtf file might be too recent):\n";
	    open (ERRLOG, "$output_filestem.err");
	    while (<ERRLOG>) {print FAILLOG $_;}
	    close ERRLOG;
	    close FAILLOG;
	}
	&FileUtils::removeFiles("$output_filestem.err");
    }

    &FileUtils::removeFiles("$output_filestem.html") if (-e "$output_filestem.html");

    return 0;
}


# Convert a pdf file to html with the pdftohtml command

sub pdf_to_html {
    my ($dirname, $input_filename, $output_filestem) = @_;

    my $cmd = "";
    if ($timeout) {$cmd = "ulimit -t $timeout;";}
    my $full_perl_path = &util::get_perl_exec();
    $cmd .= "\"$full_perl_path\" -S pdftohtml.pl -zoom $pdf_zoom";
    $cmd .= " -c" if ($pdf_complex);
    $cmd .= " -i" if ($pdf_ignore_images);
    $cmd .= " -a" if ($pdf_allow_images_only);
    $cmd .= " -hidden" unless ($pdf_nohidden);
    $cmd .= " \"$input_filename\" \"$output_filestem\"";
    
    if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000) {
	$cmd .= " > \"$output_filestem.out\" 2> \"$output_filestem.err\"";
    } else {
	$cmd .= " > \"$output_filestem.err\"";
    }

    $!=0;

    my $retval=system($cmd);
    if ($retval!=0)
    {
	print STDERR "Error executing pdftohtml.pl";
	if ($!) {print STDERR ": $!";} 
	print STDERR "\n";
    }

    # make sure the converter made something
    if ($retval!=0 || ! -s "$output_filestem.html")
    {
	&FileUtils::removeFiles("$output_filestem.out") if (-e "$output_filestem.out");
	# print out the converter's std err, if any
	if (-s "$output_filestem.err") {
	    open (ERRLOG, "$output_filestem.err") || die "$!";
	    print STDERR "pdftohtml error log:\n";
	    while (<ERRLOG>) {
		print STDERR "$_";
	    }
	    close ERRLOG;
	}
	#print STDERR "***********output filestem $output_filestem.html\n";
	&FileUtils::removeFiles("$output_filestem.html") if (-e "$output_filestem.html");
	if (-e "$output_filestem.err") {
	    if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile")))
	    {
		open (ERRLOG, "$output_filestem.err");
		while (<ERRLOG>) {print FAILLOG $_;}
		close ERRLOG;
		close FAILLOG;
	    }	
	    &FileUtils::removeFiles("$output_filestem.err");
	}
	return 0;
    }

    &FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
    &FileUtils::removeFiles("$output_filestem.out") if (-e "$output_filestem.out");
    return 1;
}

# Convert a pdf file to various types of image with the convert command

sub pdfps_to_img {
    my ($dirname, $input_filename, $output_filestem, $output_type) = @_;

    # Check that ImageMagick is installed and available on the path (except for Windows 95/98)
    if (!($ENV{'GSDLOS'} eq "windows" && !Win32::IsWinNT())) {
	my $imagick_cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl";
	$imagick_cmd = $imagick_cmd." --verbosity=$verbosity" if defined $verbosity;
	my $result = `$imagick_cmd identify 2>&1`;

	# Linux and Windows return different values for "program not found".
	# Linux returns -1 and Windows 256 for "program not found". But once they're
	# converted to signed values, it will be -1 for Linux and 1 for Windows.
	# Whenever we test for return values other than 0, shift by 8 and perform 
	# unsigned to signed status conversion on $? to get expected range of return vals
	# Although gs-magick.pl already shifts its $? by 8, converts it to a signed value
	# and then exits on that, by the time we get here, we need to do it again
	my $status = $?;
	$status >>= 8;
	$status = (($status & 0x80) ? -(0x100 - ($status & 0xFF)) : $status);	
	if (($ENV{'GSDLOS'} ne "windows" && $status == -1) || ($ENV{'GSDLOS'} eq "windows" && $status == 1)) { 
	    # if ($status == -1 || $status == 1) #if ($status == -1 || $status == 256) {
	    #ImageMagick is not installed, thus the convert utility is not available. 
	    print STDERR "*** ImageMagick is not installed, the convert utility is not available. Unable to convert PDF/PS to images. Status: $status\n";
	    return 0;
	}
    }

    my $cmd = "";
    if ($timeout) {$cmd = "ulimit -t $timeout;";}
    $output_type =~ s/.*\_(.*)/$1/i;
    my $full_perl_path = &util::get_perl_exec();
    $cmd .= "\"$full_perl_path\" -S pdfpstoimg.pl -convert_to $output_type \"$input_filename\" \"$output_filestem\"";
    if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000) {
	$cmd .= " > \"$output_filestem.out\" 2> \"$output_filestem.err\"";
    } else {
	$cmd .= " > \"$output_filestem.err\"";
    }

    # don't include path on windows (to avoid having to play about
    # with quoting when GSDLHOME might contain spaces) but assume
    # that the PATH is set up correctly
    $!=0;
    my $retval=system($cmd);
    if ($retval!=0)
    {
	print STDERR "Error executing pdfpstoimg.pl";
	if ($!) {print STDERR ": $!";} 
	print STDERR "\n";
    }

    #make sure the converter made something
    #if ($retval !=0) || ! -s "$output_filestem")
    if ($retval !=0) 
    {
	&FileUtils::removeFiles("$output_filestem.out") if (-e "$output_filestem.out");
	#print out the converter's std err, if any
	if (-s "$output_filestem.err") {
	    open (ERRLOG, "$output_filestem.err") || die "$!";
	    print STDERR "pdfpstoimg error log:\n";
	    while (<ERRLOG>) {
		print STDERR "$_";
	    }
	    close ERRLOG;
	}
	#&FileUtils::removeFiles("$output_filestem.html") if (-e "$output_filestem.html");
	if (-e "$output_filestem.err") {
	    if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile")))
	    {
		open (ERRLOG, "$output_filestem.err");
		while (<ERRLOG>) {print FAILLOG $_;}
		close ERRLOG;
		close FAILLOG;
	   }	
	    &FileUtils::removeFiles("$output_filestem.err");
	}
	return 0;
    }
    &FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
    &FileUtils::removeFiles("$output_filestem.out") if (-e "$output_filestem.out");
    return 1;
}

# Convert a PDF file to text with the pdftotext command

sub pdf_to_text {
    my ($dirname, $input_filename, $output_filestem) = @_;

    my $cmd = "pdftotext \"$input_filename\" \"$output_filestem.text\"";

    if ($ENV{'GSDLOS'} !~ m/^windows$/i) {
	$cmd .= " > \"$output_filestem.out\" 2> \"$output_filestem.err\"";
    } else {
	$cmd .= " > \"$output_filestem.err\"";
    }
    
    if (system($cmd)!=0)
    {
	print STDERR "Error executing $cmd: $!\n";
	&FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");
    }

    # make sure there is some extracted text.
    if (-e "$output_filestem.text") {
	open (EXTR_TEXT, "$output_filestem.text") || warn "open: $!";
	binmode(EXTR_TEXT); # just in case...
	my $line="";
	my $seen_text=0;
	while (($seen_text==0) && ($line=<EXTR_TEXT>)) {
	    if ($line=~ m/\w/) {$seen_text=1;}
	}
	close EXTR_TEXT;
	if ($seen_text==0) { # no text was extracted
	    print STDERR "Error: pdftotext found no text\n";
	    &FileUtils::removeFiles("$output_filestem.text");
	}
    }

    # make sure the converter made something
    if (! -s "$output_filestem.text")
    {
	# print out the converters std err, if any
	if (-s "$output_filestem.err") {
	    open (ERRLOG, "$output_filestem.err") || die "$!";
	    print STDERR "pdftotext error log:\n";
	    while (<ERRLOG>) {
		print STDERR "$_";
	    }
	    close ERRLOG;
	}
	# does this converter create a .out file?
	&FileUtils::removeFiles("$output_filestem.out") if (-e "$output_filestem.out");
	&FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");
	if (-e "$output_filestem.err") {
	    if ($faillogfile ne "" && defined(open(FAILLOG,">>$faillogfile")))
	    {
		open (ERRLOG,"$output_filestem.err");
		while (<ERRLOG>) {print FAILLOG $_;}
		close ERRLOG;
		close FAILLOG;
	    }
	    &FileUtils::removeFiles("$output_filestem.err");
	}
	return 0;
    }
    &FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
    return 1;
}

# Convert a PostScript document to text
# note - just using "ps2ascii" isn't good enough, as it
# returns 0 for a postscript interpreter error. ps2ascii is just
# a wrapper to "gs" anyway, so we use that cmd here.

sub ps_to_text {
    my ($input_filename, $output_filestem) = @_;

    my $error = "";

    # if we're on windows we'll fall straight through without attempting
    # to use gs
    if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
	$error = "Windows does not support gs";

    } else {
	my $cmd = "";
	if ($timeout) {$cmd = "ulimit -t $timeout; ";}
	$cmd .= "gs -q -dNODISPLAY -dNOBIND -dWRITESYSTEMDICT -dSIMPLE -c save ";
	$cmd .= "-f ps2ascii.ps \"$input_filename\" -c quit > \"$output_filestem.text\"";
	#$cmd .= "pstotext -output \"$output_filestem.text\" $input_filename\"";
	$cmd .= " 2> $output_filestem.err";
	$!=0;

	my $retcode=system($cmd);
	$retcode = $? >> 8;  # see man perlfunc - system for this...
	# if system returns -1 | 127 (couldn't start program), look at $! for message

	if ($retcode!=0) {if ($!) {$error=$!;} else {$error="couldn't run.\n";}}
	elsif (! -e "$output_filestem.text") {
	    $error="did not create output file.\n";
	}
	else 
	{   # make sure the interpreter didn't get an error. It is technically
	    # possible for the actual text to start with this, but....
	    open PSOUT, "$output_filestem.text";
	    if (<PSOUT> =~ m/^Error: (.*)/) {
		$error="interpreter error - \"$1\"";
	    }
	    close PSOUT;
	}
    }

    if ($error ne "")
    {
	print STDERR "Warning: Error executing gs: $error\n";
	print STDERR "Resorting to Perl regular expressions to extract text from PostScript...\n";
	&FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");

	if ("$faillogfile" ne "" && defined(open (FAILLOG, ">>$faillogfile")))
	{
	    print FAILLOG "gs - $error\n";
	    if (-e "$output_filestem.err") {
		open(ERRLOG, "$output_filestem.err");
		while (<ERRLOG>) {print FAILLOG $_;}
		close ERRLOG;
	    }
	    close FAILLOG;
	}
	&FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");


	# Fine then. We'll just do a lousy job by ourselves...
	# Based on 5-line regexp sed script found at:
	# http://snark.ptc.spbu.ru/mail-archives/lout/brown/msg00003.html
	# 
	print STDERR "Stripping text from postscript\n";
	my $errorcode=0;
	open (IN, "$input_filename") 
	    ||  ($errorcode=1, warn "Couldn't read file: $!");
	open (OUT, ">$output_filestem.text") 
	    ||  ($errorcode=1, warn "Couldn't write file: $!");
	if ($errorcode) {print STDERR "errors\n";return 0;}
	
	my $text="";  # this is for whole .ps file...
	$text = join('', <IN>); # see man perlport, under "System Resources"
	close IN;

	# Make sure this is a ps file...
	if ($text !~ m/^%!/) {
	    print STDERR "Bad postscript header: not '%!'\n";
	    if ($faillogfile ne "" && defined(open(FAILLOG, ">>$faillogfile")))
	    {
		print FAILLOG "Bad postscript header: not '%!'\n";
		close FAILLOG;
	    }
	    return 0;
	}

	# if ps has Page data, then use it to delete all stuff before it.
	$text =~ s/^.*?%%Page:.*?\n//s; # treat string as single line
	
	# remove all leading non-data stuff
	$text =~ s/^.*?\(//s;

	# remove all newline chars for easier processing
	$text =~ s/\n//g;
	
	# Big assumption here - assume that if any co-ordinates are
	# given, then we are at the end of a sentence.
	$text =~ s/\)-?\d+\ -?\d+/\) \(\n\)/g;

	# special characters--
	$text =~ s/\(\|\)/\(\ - \)/g; # j -> em-dash?

	# ? ps text formatting (eg italics?) ?
	$text =~ s/Fn\(f\)/\(\{\)/g; # f -> {
	$text =~ s/Fn\(g\)/\(\}\)/g; # g -> }
	$text =~ s/Fn\(j\)/\(\|\)/g; # j -> |
	# default - remove the rest
	$text =~ s/\ ?F.\((.+?)\)/\($1\)/g;

	# attempt to add whitespace between words... 
	# this is based purely on observation, and may be completely wrong...
	$text =~ s/([^F])[defghijkuy]\(/$1 \( /g;
	# eg I notice "b(" is sometimes NOT a space if preceded by a 
	# negative number.
	$text =~ s/\)\d+ ?b\(/\) \( /g;

	# change quoted braces to brackets
	$text =~ s/([^\\])\\\(/$1\{/g;
	$text =~ s/([^\\])\\\)/$1\}/g ;

	# remove everything that is not between braces
	$text =~ s/\)([^\(\)])+?\(//sg ;
	
	# remove any Trailer eof stuff.
	$text =~ s/\)[^\)]*$//sg;

	### ligatures have special characters...
	$text =~ s/\\013/ff/g;
	$text =~ s/\\014/fi/g;
	$text =~ s/\\015/fl/g;
	$text =~ s/\\016/ffi/g;
	$text =~ s/\\214/fi/g;
	$text =~ s/\\215/fl/g;
	$text =~ s/\\017/\n\* /g; # asterisk?
	$text =~ s/\\023/\023/g;  # e acute ('e)
	$text =~ s/\\177/\252/g;  # u"
#	$text =~ s/ ?? /\344/g;  # a"

	print OUT "$text";
	close OUT;
    }
    # wrap the text - use a minimum length. ie, first space after this length.
    my $wrap_length=72;
    &FileUtils::moveFiles("$output_filestem.text", "$output_filestem.text.tmp");
    open INFILE, "$output_filestem.text.tmp" ||
	die "Couldn't open file: $!";
    open OUTFILE, ">$output_filestem.text" ||
	die "Couldn't open file for writing: $!";
    my $line="";
    while ($line=<INFILE>) {
	while (length($line)>0) {
	    if (length($line)>$wrap_length) {
		$line =~ s/^(.{$wrap_length}[^\s]*)\s*//;
		print OUTFILE "$1\n";
	    } else {
		print OUTFILE "$line";
		$line="";
	    }
	}
    }
    close INFILE;
    close OUTFILE;
    &FileUtils::removeFiles("$output_filestem.text.tmp");

    &FileUtils::removeFiles("$output_filestem.err") if (-e "$output_filestem.err");
    return 1;
}


# Convert any file to HTML with a crude perl implementation of the
# UNIX strings command.

sub any_to_html {
    my ($input_filename, $output_filestem) = @_;

    # First generate a text file
    return 0 unless (&any_to_text($input_filename, $output_filestem));

    # create an HTML file from the text file
    open(TEXT, "<$output_filestem.text");
    open(HTML, ">$output_filestem.html");

    print HTML "<html><head>\n";
    print HTML "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html\">\n";
    print HTML "<META NAME=\"GENERATOR\" CONTENT=\"Greenstone any_to_html\">\n";
    print HTML "</head><body>\n\n";

    my $line;
    while ($line=<TEXT>) { 
	$line =~ s/</&lt;/g;
	$line =~ s/>/&gt;/g;
	if ($line =~ m/^\s*$/) {
	    print HTML "<p>";
	} else {
	    print HTML "<br> ", $line;
	}
    }
    print HTML "\n</body></html>\n";

    close HTML;
    close TEXT;

    &FileUtils::removeFiles("$output_filestem.text") if (-e "$output_filestem.text");
    return 1;
}

# Convert any file to TEXT with a crude perl implementation of the
# UNIX strings command.
# Note - this assumes ascii charsets :(		(jrm21)

sub any_to_text {
    my ($input_filename, $output_filestem) = @_;

    if (!$use_strings) {
      return 0;
    }

    print STDERR "\n**** In any to text****\n\n";
    open(IN, "<$input_filename") || return 0;
    binmode(IN);
    open(OUT, ">$output_filestem.text") || return 0;

    my ($line);
    my $output_line_count = 0;
    while (<IN>) { 
	$line = $_;

	# delete anything that isn't a printable character
	$line =~ s/[^\040-\176]+/\n/sg;

	# delete any string less than 10 characters long
	$line =~ s/^.{0,9}$/\n/mg;
	while ($line =~ m/^.{1,9}$/m) {
	    $line =~ s/^.{0,9}$/\n/mg;
	    $line =~ s/\n+/\n/sg;
	}

	# remove extraneous whitespace
	$line =~ s/\n+/\n/gs;
	$line =~ s/^\n//gs;

	# output whatever is left
	if ($line =~ m/[^\n ]/) {
	    print OUT $line;
	    ++$output_line_count;
	}
    }

    close OUT;
    close IN;

    if ($output_line_count) { # try to protect against binary only formats
	return 1;
    }

    &FileUtils::removeFiles("$output_filestem.text");
    return 0;

}
