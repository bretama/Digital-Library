#!/usr/bin/perl -w

###########################################################################
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009 New Zealand Digital Library Project
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


# wvware.pl: Script to set the environment for wvware and then run it
# Setting the env vars necessary for wvware here locally, won't interfere
# with the normal environment if they had been set in setup.bash/setup.bat


BEGIN {
    die "GSDLHOME not set - run the (gs3-)setup script\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set - run (gs3-)setup script\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}


use strict;
use util;
use FileUtils;

# Are we running on WinNT or Win2000 (or later)?
my $is_winnt_2000=eval {require Win32; return (Win32::IsWinNT()); return 0;};
if (!defined($is_winnt_2000)) {$is_winnt_2000=0;}

sub main
{
    my ($argc,@argv) = @_;

    if (($argc<2 || $argc>5)  || (($argc==1) && ($argv[0] =~ m/^--?h(elp)?$/))) {
	my ($progname) = ($0 =~ m/^.*[\/|\\](.*?)$/);

	print STDERR "\n";
	print STDERR "Usage: $progname <input-filename> <output-filestem> [<fail-log-file>] [<verbosity>] [<timeout>]\n";
	print STDERR "\n";

	exit(-1);
    }	

    my $input_filename = $argv[0];
    my $output_filestem = $argv[1];
    my $faillogfile="";
    my $verbosity=0;
	my $timeout=0;
	
    if($argc >= 3) {
	$faillogfile= $argv[2];
    }
	if($argc >= 4) {
	$verbosity = $argv[3];
    }
    if($argc >= 5) {
	$timeout = $argv[4];
    }

    ## SET THE ENVIRONMENT AS DONE IN SETUP.BASH/BAT OF GNOME-LIB

    if (!defined $ENV{'GEXTGNOME'}) {
	# my $extdesc = "the GNOME support library extension";

	my $extdir = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"ext");
	my $gnome_dir = &FileUtils::filenameConcatenate($extdir, "gnome-lib-minimal");
	if(-d $gnome_dir) {
	    $ENV{'GEXTGNOME'} = $gnome_dir;
	} else {
	    $gnome_dir = &FileUtils::filenameConcatenate($extdir, "gnome-lib");
	    if(-d $gnome_dir) {
		$ENV{'GEXTGNOME'} = $gnome_dir;
	    } elsif ($verbosity > 2) {
		print STDERR "No gnome-lib(-minimal) ext folder detected. Trying to run wvware without its libraries....\n";
	    }	    
	}
    
	# now set other the related env vars, 
	# IF we've found the gnome-lib dir installed in the ext folder

	if (defined $ENV{'GEXTGNOME'}) {
	    $ENV{'GEXTGNOME_INSTALLED'}=&FileUtils::filenameConcatenate($ENV{'GEXTGNOME'}, $ENV{'GSDLOS'});
	    
	    &util::envvar_prepend("PATH", &FileUtils::filenameConcatenate($ENV{'GEXTGNOME_INSTALLED'}, "bin"));
	    
	    # util's prepend will create LD/DYLD_LIB_PATH if it doesn't exist yet
	    my $gextlib = &FileUtils::filenameConcatenate($ENV{'GEXTGNOME_INSTALLED'}, "lib");
	    if($ENV{'GSDLOS'} eq "linux") {
		&util::envvar_prepend("LD_LIBRARY_PATH", $gextlib);
	    } elsif ($ENV{'GSDLOS'} eq "darwin") {
		&util::envvar_prepend("DYLD_LIBRARY_PATH", $gextlib);
	    }
	}
	
	# Above largely mimics the setup.bash of the gnome-lib-minimal.
	# Not doing the devel-srcpack that gnome-lib-minimal's setup.bash used to set
	# Not exporting GSDLEXTS variable either
    }

#    print STDERR "@@@@@ GEXTGNOME: ".$ENV{'GEXTGNOME'}."\n\tINSTALL".$ENV{'GEXTGNOME_INSTALLED'}."\n";
#    print STDERR "\tPATH".$ENV{'PATH'}."\n\tLD_PATH".$ENV{'LD_LIBRARY_PATH'}."\n";


    # if no GEXTGNOME, maybe they do not need gnome-lib to run wvware
    # RUN WVWARE

    my $wvWare = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wvWare");

    my $wvware_folder = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wv");
    if ( -d $wvware_folder && $ENV{'GSDLOS'} eq "linux" ) {
	&util::envvar_prepend("PATH", &FileUtils::filenameConcatenate($wvware_folder, "bin"));

	my $wvwarelib = &FileUtils::filenameConcatenate($wvware_folder, "lib");
	if($ENV{'GSDLOS'} eq "linux") {
	    &util::envvar_prepend("LD_LIBRARY_PATH", $wvwarelib);
	} #else if ($ENV{'GSDLOS'} eq "darwin") {
	   # &util::envvar_prepend("DYLD_LIBRARY_PATH", $wvwarelib);
	#}
        $wvWare = &FileUtils::filenameConcatenate($wvware_folder, "bin", "wvWare");
    }

    # don't include path on windows (to avoid having to play about
    # with quoting when GSDLHOME might contain spaces) but assume
    # that the PATH is set up correctly
    $wvWare = "wvWare" if ($ENV{'GSDLOS'} =~ m/^windows$/i);

    my $wv_conf = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "etc", 
				      "packages", "wv", "wvHtml.xml");
    
    # Added the following to work with replace_srcdoc_with_html.pl:
    # Make wvWare put any associated (image) files of the word doc into
    # folder docname-without-extention_files. This folder should be at
    # the same level as the html file generated from the doc. 
    # wvWare will take care of proper interlinking. 

    # This step is necessary for replace_srcdoc_with_html.pl which will 
    # move the html and associated files into the import folder. We
    # want to ensure that the associated files won't overwrite similarly
    # named items already in import. Hence we put them in a folder first
    # (to which the html links properly) and that will allow
    # replace_srcdoc_with_html.pl to move them safely to /import.

    # To do all this, we need to use wvWare's --dir and --basename options
    # where dir is the full path to the image folder directory and
    # basename is the full path to the image folder appended to the name 
    # which is to be prepended to every image file:
    # eg. if the images were to have names like sample0.jpg to sampleN.jpg,
    # then the basename is "/full/path/to/imgdir/sample". 
    # In this case, basename is the full path to and name of the document.
    # HOWEVER: basename always takes full path, not relative url, so
    # the greenstone browser is unable to display the images (absolute paths
    # cause it to give an "external link" message)
    # See http://osdir.com/ml/lib.wvware.devel/2002-11/msg00014.html
    # and http://rpmfind.net/linux/RPM/freshmeat/rpms/wv/wv-0.5.44-1.i386.html
    # "added --dir option to wvHtml so that pictures can be placed in
    # a seperate directory"
    # "running wvWare through IMP to view word documents as html. It gets
    # invoked like this:
    # wvWare --dir=/tmp-wvWare --basename=/tmp-wvWare/img$$- $tmp_word >$tmp_output"
    
    # toppath is the folder where html is generated
    # docname is the name (without extension) of the html to be generated
    # suffix (extension) is thrown away
    my ($docname, $toppath) 
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    # We want the image folder generated to have the same name as windows
    # would generate ($windows_scripting) when it converts from word to html.
    # That is, foldername=docname_files
    my $assoc_dir = &FileUtils::filenameConcatenate($toppath, $docname."_files");
    #print "assoc_dir: ".$assoc_dir."\n";  # same as "$output_filestem._files"
    
    # ensure this image directory exists
    # if it exists already, just delete and recreate
    if(-e $assoc_dir) { 
	&FileUtils::removeFilesRecursive($assoc_dir);
    }  
    &FileUtils::makeDirectory($assoc_dir);

    # the images are all going to be called image0, image1,..., imageN
    my $img_basenames = &FileUtils::filenameConcatenate($assoc_dir, $docname);
    
    #print STDERR "****toppath: $toppath\n****docname: $docname\n;
    #print STDERR "****img_basenames: $img_basenames\n" if($img_basenames);
    #print STDERR "****assoc_dir: $assoc_dir\n" if($assoc_dir);

    my $cmd = "";
    
    if ($timeout) {$cmd = "ulimit -t $timeout;";}
    # wvWare's --dir and --basename options for image directory. 
    # Replaced the next line with the *2 lines* following it:
               # $cmd .= "$wvWare --charset utf-8 --config \"$wv_conf\"";
    $cmd .= "$wvWare --dir \"$assoc_dir\" --basename \"$img_basenames\""; 
    $cmd .= " --charset utf-8 --config \"$wv_conf\"";
    $cmd .= " \"$input_filename\" > \"$output_filestem.html\"";

    # redirecting STDERR is a bad idea on windows 95/98
    $cmd .= " 2> \"$output_filestem.err\""
	if ($ENV{'GSDLOS'} !~ m/^windows$/i || $is_winnt_2000);

#    print STDERR "***** wvware.pl launching wvware with CMD:\n\t$cmd\n";

    # execute the command
    $!=0;
    if (system($cmd)!=0)
    {
	print STDERR "Error executing wv converter:|$!|\n";
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
	exit(0); # we can try any_to_text
    }

    # Was the conversion successful?

    if (-s "$output_filestem.html") { # if file has non-zero size (i.e. it has contents)
	open(TMP, "$output_filestem.html");
	my $line = <TMP>;
	close(TMP);
	if ($line && $line =~ m/DOCTYPE HTML/) {
	    &FileUtils::removeFiles("$output_filestem.err") if -e "$output_filestem.err";    

	    # Inserted this code to remove the images directory if it was still empty after 
	    # the html was generated (in case there were no images in the word document)
	    if (&FileUtils::isDirectoryEmpty($assoc_dir)) {
		#print STDERR "***gsConvert.pl: Image dir $assoc_dir is empty, removing***\n";
		&FileUtils::removeFilesRecursive($assoc_dir);
	    } else { # there was an image folder (it was generated)
		# Therefore, the html file generated contains absolute links to the images
		# Replace them with relative links instead, so the folder can be moved elsewhere
		&make_links_to_assocdir_relative($toppath, $docname, "$output_filestem.html", $assoc_dir, $docname."_files");	
	    }
	    exit(1);
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
    
    exit(0);
}

&main(scalar(@ARGV),@ARGV);


# Method to work with doc_to_html - Word docs might contain images.
# When such word docs are converted with wvWare, we make it generate a 
# <filename>_files folder with the associated images, while the html file
# <filename> refers to the images using absolute paths to <filename>_files.
# This method reads in that html file and replaces all the absolute paths to 
# the images in <filename>_files with the relative paths to the images from
# that folder. (I.e. with <filename>_files/<imagename.ext>).
sub make_links_to_assocdir_relative{
    # toppath is the top-level folder in which the html file we're going to be fixing resides
    # docname is just the name (without extension) of the html file
    # html_file is the full path to the html file: /full/path/docname.html
    # assoc_dir_path is toppath/docname_files
    # assoc_dirname is the directory name of the folder with associated imgs: docname_files
    my ($toppath, $docname, $html_file, $assoc_dir_path, $assoc_dirname) = @_;

    # 1. Read all the contents of the html into a string
    # open the original file for reading
    unless(open(FIN, "<$html_file")) { 
	print STDERR "gsConvert.pl: Unable to open $html_file for reading absolute urls...ERROR: $!\n";
	return 0;
    }
    # From http://perl.plover.com/local.html
    # "It's cheaper to read the file all at once, without all the splitting and reassembling. 
    # (Some people call this slurping the file.) Perl has a special feature to support this: 
    # If the $/ variable is undefined, the <...> operator will read the entire file all at once"
    my $html_contents;
    {
	local $/ = undef;        # Read entire file at once
	$html_contents = <FIN>;  # Now file is read in as one single 'line'
    }
    close(FIN); # close the file
    #print STDERR $html_contents;
   
    # 2. Replace (substitute) *all* ocurrences of the assoc_dir_path in a hrefs and img src
    # values with assoc_dirname
    # At the end: g means substitute all occurrences (global), while s at the end means treat 
    # all new lines as a regular space. This interacts with g to consider all the lines 
    # together as a single line so that multi-occurrences can be replaced.

    # we can't just replace $assoc_dir_path with $assoc_dir
    # $assoc_dir_path represents a regular expression that needs to be replaced
    # if it contains ., -, [, ], or Windows style backslashes in paths  -- which all have special
    # meaning in Perl regular expressions -- we need to escape these first
    my $safe_reg_expression = $assoc_dir_path;
    $safe_reg_expression =~ s/\\/\\\\/g;
	$safe_reg_expression =~ s@\(@\\(@g; # escape brackets
	$safe_reg_expression =~ s@\)@\\)@g; # escape brackets
    $safe_reg_expression =~ s/\./\\./g;
    $safe_reg_expression =~ s/\-/\\-/g;
    $safe_reg_expression =~ s/\[/\\[/g;
    $safe_reg_expression =~ s/\]/\\]/g;
    $safe_reg_expression =~ s/ /%20/g; # wvWare put %20 in place of space, so we need to change our prefix to match

    # The following regular expression substitution looks for <a or <image, followed by any other 
    # attributes and values until it comes to the FIRST (indicated by ?) href= or src= 
    # followed by " or ' no quotes at all around path, followed by the associated folder's pathname 
    # followed by characters (for the img filename), then finally the optional closing quotes 
    # in " or ' form, followed by any other attributes and values until the first > to end the tag.
    # The substitution: all the parts preceding associated folder's pathname are retained,
    # the associated folder path name is replaced by associated folder directory name
    # and the rest upto and including the closing > tag is retained.
    # The sg at the end of the pattern match treats all of html_contents as a single line (s) 
    # and performs a global replace (g) meaning that all occurrences that match in that single line
    # are substituted.
    $html_contents =~ s/(<(a|img).*?(href|src)=(\"|\')?)$safe_reg_expression(.*?(\"|\')?.*?>)/$1$assoc_dirname$5/sg;
               #$html_contents =~ s/$safe_reg_expression/$assoc_dirname/gs; # this works, used as fall-back
    # now replace any %20 chars in filenames of href or src attributes to use literal space ' '. Calls a function for this
    $html_contents =~ s/(<(a|img).*?(href|src)=(\"|\')?)(.*)(.*?(\"|\')?.*?>)/&post_process_assocfile_urls($1, $5, $6)/sge;

    #print STDERR "****assoc_dirname: $assoc_dirname***\n";
    #print STDERR "****safe_reg_expression: $safe_reg_expression***\n";
   
    # delete the original file and recreate it
    my $copy_of_filename = $html_file;
    &FileUtils::removeFiles($copy_of_filename); # deleted the file

    # Recreate the original file for writing the updated contents
    unless(open(FOUT, ">$html_file")) {  # open it as a new file for writing
	print STDERR "gsConvert.pl: Unable to open $html_file for writing relative links...ERROR: $!\n";
	return 0;
    }

    # write out the updated contents and close the file
    print FOUT $html_contents;
    close(FOUT);
    return 1;
}


# Utility routine to make sure HTML plugin gets img src/href link pathnames that contain 
# url slashes (/) instead of windows-style backwards slashes, and to convert all %20 
# introduced in link pathnames by wvWare into space again. Converts all percent signs
# introduced by URL encoding filenames generated into %25 in these url links referencing them
sub post_process_assocfile_urls
{
    my ($pre, $text, $post) = @_;

    $text =~ s/%20/ /g; # Convert %20s to space and not underscore since underscores mess with incremental rebuild 
    # $text =~ s/%20/_/g; # reinstated this line, since we no longer replace spaces with %20. We replace them with underscores
    $text =~ s/\\/\//g;
    $text =~ s/%/%25/g;

    return "$pre$text$post";
}
