###########################################################################
#
# util.pm -- various useful utilities
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

package util;

use strict;
no strict 'refs'; # make an exception so we can use variables as filehandles
use FileUtils;

use Encode;
use Unicode::Normalize 'normalize';

use File::Copy;
use File::Basename;
# Config for getting the perlpath in the recommended way, though it uses paths that are
# hard-coded into the Config file that's generated upon configuring and compiling perl.
# $^X works better in some cases to return the path to perl used to launch the script,
# but if launched with plain "perl" (no full-path), that will be just what it returns.
use Config;
# New module for file related utility functions - intended as a
# placeholder for an extension that allows a variety of different
# filesystems (FTP, HTTP, SAMBA, WEBDav, HDFS etc)
use FileUtils;

if ($ENV{'GSDLOS'} =~ /^windows$/i) {
    require Win32; # for working out Windows Long Filenames from Win 8.3 short filenames
}

# removes files (but not directories)
sub rm {
  warnings::warnif("deprecated", "util::rm() is deprecated, using FileUtils::removeFiles() instead");
  return &FileUtils::removeFiles(@_);
}

# recursive removal
sub filtered_rm_r {
  warnings::warnif("deprecated", "util::filtered_rm_r() is deprecated, using FileUtils::removeFilesFiltered() instead");
  return &FileUtils::removeFilesFiltered(@_);
}

# recursive removal
sub rm_r {
  warnings::warnif("deprecated", "util::rm_r() is deprecated, using FileUtils::removeFilesRecursive() instead");
  return &FileUtils::removeFilesRecursive(@_);
}

# moves a file or a group of files
sub mv {
  warnings::warnif("deprecated", "util::mv() is deprecated, using FileUtils::moveFiles() instead");
  return &FileUtils::moveFiles(@_);
}

# Move the contents of source directory into target directory
# (as opposed to merely replacing target dir with the src dir)
# This can overwrite any files with duplicate names in the target
# but other files and folders in the target will continue to exist
sub mv_dir_contents {
  warnings::warnif("deprecated", "util::mv_dir_contents() is deprecated, using FileUtils::moveDirectoryContents() instead");
  return &FileUtils::moveDirectoryContents(@_);
}

# copies a file or a group of files
sub cp {
  warnings::warnif("deprecated", "util::cp() is deprecated, using FileUtils::copyFiles() instead");
  return &FileUtils::copyFiles(@_);
}

# recursively copies a file or group of files
# syntax: cp_r (sourcefiles, destination directory)
# destination must be a directory - to copy one file to
# another use cp instead
sub cp_r {
  warnings::warnif("deprecated", "util::cp_r() is deprecated, using FileUtils::copyFilesrecursive() instead");
  return &FileUtils::copyFilesRecursive(@_);
}

# recursively copies a file or group of files
# syntax: cp_r (sourcefiles, destination directory)
# destination must be a directory - to copy one file to
# another use cp instead
sub cp_r_nosvn {
  warnings::warnif("deprecated", "util::cp_r_nosvn() is deprecated, using FileUtils::copyFilesRecursiveNoSVN() instead");
  return &FileUtils::copyFilesRecursiveNoSVN(@_);
}

# copies a directory and its contents, excluding subdirectories, into a new directory
sub cp_r_toplevel {
  warnings::warnif("deprecated", "util::cp_r_toplevel() is deprecated, using FileUtils::recursiveCopyTopLevel() instead");
  return &FileUtils::recursiveCopyTopLevel(@_);
}

sub mk_dir {
  warnings::warnif("deprecated", "util::mk_dir() is deprecated, using FileUtils::makeDirectory() instead");
  return &FileUtils::makeDirectory(@_);
}

# in case anyone cares - I did some testing (using perls Benchmark module)
# on this subroutine against File::Path::mkpath (). mk_all_dir() is apparently
# slightly faster (surprisingly) - Stefan.
sub mk_all_dir {
  warnings::warnif("deprecated", "util::mk_all_dir() is deprecated, using FileUtils::makeAllDirectories() instead");
  return &FileUtils::makeAllDirectories(@_);
}

# make hard link to file if supported by OS, otherwise copy the file
sub hard_link {
  warnings::warnif("deprecated", "util::hard_link() is deprecated, using FileUtils::hardLink() instead");
  return &FileUtils::hardLink(@_);
}

# make soft link to file if supported by OS, otherwise copy file
sub soft_link {
  warnings::warnif("deprecated", "util::soft_link() is deprecated, using FileUtils::softLink() instead");
  return &FileUtils::softLink(@_);
}

# Primarily for filenames generated by processing
# content of HTML files (which are mapped to UTF-8 internally)
#
# To turn this into an octet string that really exists on the file
# system:
# 1. don't need to do anything special for Unix-based systems
#   (as underlying file system is byte-code)
# 2. need to map to short DOS filenames for Windows

sub utf8_to_real_filename
{
    my ($utf8_filename) = @_;

    my $real_filename;

    if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	require Win32;

	my $unicode_filename = decode("utf8",$utf8_filename);
	$real_filename = Win32::GetShortPathName($unicode_filename);
    }
    else {
	$real_filename = $utf8_filename;
    }

    return $real_filename;
}

sub raw_filename_to_unicode
{
	my ($directory, $raw_file, $filename_encoding ) = @_;
		
	my $unicode_filename = $raw_file;
	if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	    # Try turning a short version to the long version
	    # If there are "funny" characters in the file name, that can't be represented in the ANSI code, then we will have a short weird version, eg E74~1.txt
	    $unicode_filename = &util::get_dirsep_tail(&util::upgrade_if_dos_filename(&FileUtils::filenameConcatenate($directory, $raw_file), 0));
	    
	    
	    if ($unicode_filename eq $raw_file) {
		# This means the original filename *was* able to be encoded in the local ANSI file encoding (eg windows_1252), so now we turn it back to perl's unicode
		
		$unicode_filename = &Encode::decode(locale_fs => $unicode_filename);
	    }
	    # else This means we did have one of the funny filenames. the getLongPathName (used in upgrade_if_dos_filename) will return unicode, so we don't need to do anything more.
	    
					
	} else {
	    # we had a utf-8 string, turn it into perl internal unicode
	    $unicode_filename = &Encode::decode("utf-8", $unicode_filename);
	
		
	}
	#Does the filename have url encoded chars in it?
	if (&unicode::is_url_encoded($unicode_filename)) {
	    $unicode_filename = &unicode::url_decode($unicode_filename);
	}
	
	# Normalise the filename to canonical composition - on mac, filenames use decopmposed form for accented chars
	if ($ENV{'GSDLOS'} =~ m/^darwin$/i) {
	    $unicode_filename = normalize('C', $unicode_filename); # Composed form 'C'
	}
	return $unicode_filename;

}
sub fd_exists {
  warnings::warnif("deprecated", "util::fd_exists() is deprecated, using FileUtils::fileTest() instead");
  return &FileUtils::fileTest(@_);
}

sub file_exists {
  warnings::warnif("deprecated", "util::file_exists() is deprecated, using FileUtils::fileExists() instead");
  return &FileUtils::fileExists(@_);
}

sub dir_exists {
  warnings::warnif("deprecated", "util::dir_exists() is deprecated, using FileUtils::directoryExists() instead");
  return &FileUtils::directoryExists(@_);
}

# updates a copy of a directory in some other part of the filesystem
# verbosity settings are: 0=low, 1=normal, 2=high
# both $fromdir and $todir should be absolute paths
sub cachedir {
  warnings::warnif("deprecated", "util::cachedir() is deprecated, using FileUtils::synchronizeDirectories() instead");
  return &FileUtils::synchronizeDirectories(@_);
}

# this function returns -1 if either file is not found
# assumes that $file1 and $file2 are absolute file names or
# in the current directory
# $file2 is allowed to be newer than $file1
sub differentfiles {
  warnings::warnif("deprecated", "util::differentfiles() is deprecated, using FileUtils::differentFiles() instead");
  return &FileUtils::differentFiles(@_);
}


# works out the temporary directory, including in the case where Greenstone is not writable
# In that case, gs3-setup.bat would already have set the GS_TMP_OUTPUT_DIR temp variable
sub determine_tmp_dir
{
	my $try_collect_dir = shift(@_) || 0;

	my $tmp_dirname;
	if(defined $ENV{'GS_TMP_OUTPUT_DIR'}) {
		$tmp_dirname = $ENV{'GS_TMP_OUTPUT_DIR'};
	} elsif($try_collect_dir && defined $ENV{'GSDLCOLLECTDIR'}) {
		$tmp_dirname = $ENV{'GSDLCOLLECTDIR'};
    } elsif(defined $ENV{'GSDLHOME'}) {
		$tmp_dirname = $ENV{'GSDLHOME'};
    } else {
		return undef;
    }
	
	if(!defined $ENV{'GS_TMP_OUTPUT_DIR'}) {
		# test the tmp_dirname folder is writable, by trying to write out a file
		# Unfortunately, cound not get if(-w $dirname) to work on directories on Windows
			## http://alvinalexander.com/blog/post/perl/perl-file-test-operators-reference-cheat-sheet (test file/dir writable)
			## http://www.makelinux.net/alp/083 (real and effective user IDs)
		
		my $tmp_test_file = &FileUtils::filenameConcatenate($tmp_dirname, "writability_test.tmp");
		if (open (FOUT, ">$tmp_test_file")) {
			close(FOUT);
			&FileUtils::removeFiles($tmp_test_file);
	    } else { # location not writable, use TMP location
		if (defined $ENV{'TMP'}) {
		    $tmp_dirname = $ENV{'TMP'};
		} else {
		    $tmp_dirname = "/tmp";
		}
		$tmp_dirname = &FileUtils::filenameConcatenate($tmp_dirname, "greenstone");
			$ENV{'GS_TMP_OUTPUT_DIR'} = $tmp_dirname; # store for next time
		}
	}
	
	$tmp_dirname = &FileUtils::filenameConcatenate($tmp_dirname, "tmp");
	&FileUtils::makeAllDirectories ($tmp_dirname) unless -e $tmp_dirname;

	return $tmp_dirname;
}

sub get_tmp_filename 
{
    my $file_ext = shift(@_) || undef;

    my $opt_dot_file_ext = "";
    if (defined $file_ext) {
	if ($file_ext !~ m/\./) {
	    # no dot, so needs one added in at start
	    $opt_dot_file_ext = ".$file_ext"
	}
	else {
	    # allow for "extensions" such as _metadata.txt to be handled
	    # gracefully
	    $opt_dot_file_ext = $file_ext;
	}
    }

	my $tmpdir = &util::determine_tmp_dir(0);

    my $count = 1000;
    my $rand = int(rand $count);
    my $full_tmp_filename = &FileUtils::filenameConcatenate($tmpdir, "F$rand$opt_dot_file_ext");

    while (-e $full_tmp_filename) {
	$rand = int(rand $count);
	$full_tmp_filename = &FileUtils::filenameConcatenate($tmpdir, "F$rand$opt_dot_file_ext");
	$count++;
    }
    
    return $full_tmp_filename;
}

# These 2 are "static" variables used by the get_timestamped_tmp_folder() subroutine below and
# belong with that function. They help ensure the timestamped tmp folders generated are unique.
my $previous_timestamp = undef;
my $previous_timestamp_f = 0; # frequency

sub get_timestamped_tmp_folder
{
	my $tmp_dirname = &util::determine_tmp_dir(1);
	
    # add the timestamp into the path otherwise we can run into problems 
    # if documents have the same name
    my $timestamp = time;	
	
	if (!defined $previous_timestamp || ($timestamp > $previous_timestamp)) {
		$previous_timestamp_f = 0;
		$previous_timestamp = $timestamp;
	} else {
		$previous_timestamp_f++;
	} 
	
    my $time_tmp_dirname = &FileUtils::filenameConcatenate($tmp_dirname, $timestamp);
    $tmp_dirname = $time_tmp_dirname;	
    my $i = $previous_timestamp_f;
	
	if($previous_timestamp_f > 0) {
		$tmp_dirname = $time_tmp_dirname."_".$i;
		$i++;
	}
    while (-e $tmp_dirname) {
	$tmp_dirname = $time_tmp_dirname."_".$i;
	$i++;
    }
    &FileUtils::makeDirectory($tmp_dirname); 

    return $tmp_dirname;
}

sub get_timestamped_tmp_filename_in_collection
{

    my ($input_filename, $output_ext) = @_;
    # derive tmp filename from input filename
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    # softlink to collection tmp dir
    my $tmp_dirname = &util::get_timestamped_tmp_folder();
    $tmp_dirname = $dirname unless defined $tmp_dirname;

    # following two steps copied from ConvertBinaryFile
    # do we need them?? can't use them as is, as they use plugin methods.

    #$tailname = $self->SUPER::filepath_to_utf8($tailname) unless &unicode::check_is_utf8($tailname);

    # URLEncode this since htmls with images where the html filename is utf8 don't seem
    # to work on Windows (IE or Firefox), as browsers are looking for filesystem-encoded
    # files on the filesystem.
    #$tailname = &util::rename_file($tailname, $self->{'file_rename_method'}, "without_suffix");
    if (defined $output_ext) {
	$output_ext = ".$output_ext"; # add the dot
    } else {
	$output_ext = $suffix;
    }
    $output_ext= lc($output_ext);
    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$output_ext");
    
    return $tmp_filename;
}

sub get_toplevel_tmp_dir
{
    return &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "tmp");
}


sub get_collectlevel_tmp_dir
{
    my $tmp_dirname = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);

    return $tmp_dirname;
}

sub get_parent_folder
{
    my ($path) = @_;
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($path, "\\.[^\\.]+\$");

    return &FileUtils::sanitizePath($dirname);
}

sub filename_to_regex {
    my $filename = shift (@_);

    # need to make single backslashes double so that regex works
    $filename =~ s/\\/\\\\/g; # if ($ENV{'GSDLOS'} =~ /^windows$/i);    
	
    # note that the first part of a substitution is a regex, so RE chars need to be escaped,
    # the second part of a substitution is not a regex, so for e.g. full-stop can be specified literally
	$filename =~ s/\./\\./g; # in case there are extensions/other full stops, escape them
	$filename =~ s@\(@\\(@g; # escape brackets
	$filename =~ s@\)@\\)@g; # escape brackets
	$filename =~ s@\[@\\[@g; # escape brackets
	$filename =~ s@\]@\\]@g; # escape brackets
	
    return $filename;
}

sub unregex_filename {
    my $filename = shift (@_);

    # need to put doubled backslashes for regex back to single
	$filename =~ s/\\\./\./g; # remove RE syntax for .
	$filename =~ s@\\\(@(@g; # remove RE syntax for ( => "\(" turns into "("
	$filename =~ s@\\\)@)@g; # remove RE syntax for ) => "\)" turns into ")"
	$filename =~ s@\\\[@[@g; # remove RE syntax for [ => "\[" turns into "["
	$filename =~ s@\\\]@]@g; # remove RE syntax for ] => "\]" turns into "]"
	
	# \\ goes to \
	# This is the last step in reverse mirroring the order of steps in filename_to_regex()
	$filename =~ s/\\\\/\\/g; # remove RE syntax for \    
    return $filename;
}

sub filename_cat {
  # I've disabled this warning for now, as every Greenstone perl
  # script seems to make use of this function and so you drown in a
  # sea of deprecated warnings [jmt12]
#  warnings::warnif("deprecated", "util::filename_cat() is deprecated, using FileUtils::filenameConcatenate() instead");
  return &FileUtils::filenameConcatenate(@_);
}


sub _pathname_cat {
    my $join_char  = shift(@_);
    my $first_path = shift(@_); 
    my (@pathnames) = @_;

    # If first_path is not null or empty, then add it back into the list
    if (defined $first_path && $first_path =~ /\S/) {
	unshift(@pathnames, $first_path);
    }

    my $pathname = join($join_char, @pathnames);

    # remove duplicate slashes
    if ($join_char eq ";") {
	$pathname =~ s/[\\\/]+/\\/g;
	if ($^O eq "cygwin") {
	    # Once we've collapsed muliple (potentialy > 2) slashes
	    # For cygwin, actually want things double-backslahed 
	    $pathname =~ s/\\/\\\\/g;
	}

    } else {
	$pathname =~ s/[\/]+/\//g; 
	# DB: want a pathname abc\de.html to remain like this
    }

    return $pathname;
}


sub pathname_cat {
    my (@pathnames) = @_;

    my $join_char;
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$join_char = ";";
    } else {
	$join_char = ":";
    }
    return _pathname_cat($join_char,@pathnames);
}


sub javapathname_cat {
    my (@pathnames) = @_;

    my $join_char;

    # Unlike pathname_cat() above, not interested if running in a Cygwin environment
    # This is because the java we run is actually a native Windows executable

    if (($ENV{'GSDLOS'} =~ /^windows$/i)) {
	$join_char = ";";
    } else {
	$join_char = ":";
    }
    return _pathname_cat($join_char,@pathnames);
}


sub makeFilenameJavaCygwinCompatible
{
    my ($java_filename) = @_;

    if ($^O eq "cygwin") {
	# To be used with a Java program, but under Cygwin
	# Because the java binary that is native to Windows, need to
	# convert the Cygwin paths (i.e. Unix style) to be Windows
	# compatible
	
	$java_filename = `cygpath -wp "$java_filename"`;
	chomp($java_filename);
	$java_filename =~ s%\\%\\\\%g;
    }

    return $java_filename;
}

sub tidy_up_oid {
    my ($OID) = @_;
    if ($OID =~ /[\.\/\\]/) {
	print STDERR "Warning, identifier $OID contains periods or slashes(.\\\/), replacing them with _\n";
	$OID =~ s/[\.\\\/]/_/g; #remove any periods
    }
    if ($OID =~ /^\s.*\s$/) {
	print STDERR "Warning, identifier $OID starts or ends with whitespace. Removing it\n";
	# remove starting and trailing whitespace
	$OID =~ s/^\s+//;
	$OID =~ s/\s+$//;
    }
    if ($OID =~ /^[\d]*$/) {
	print STDERR "Warning, identifier $OID contains only digits. Prepending 'D'.\n";
	$OID = "D" . $OID;
    }		
    
    return $OID;
}

sub envvar_prepend {
    my ($var,$val) = @_;

    # 64 bit linux can't handle ";" as path separator, so make sure to set this to the right one for the OS
##    my $pathsep = (defined $ENV{'GSDLOS'} && $ENV{'GSDLOS'} !~ m/windows/) ? ":" : ";";

    # Rewritten above to make ":" the default (Windows is the special
    # case, anything else 'unusual' such as Solaris etc is Unix)
    my $pathsep = (defined $ENV{'GSDLOS'} && (($ENV{'GSDLOS'} =~ m/windows/) && ($^O ne "cygwin"))) ? ";" : ":";

    # do not prepend any value/path that's already in the environment variable
    
    my $escaped_val = &filename_to_regex($val); # escape any backslashes and brackets for upcoming regex
    if (!defined($ENV{$var})) {
	$ENV{$var} = "$val";
    }
    elsif($ENV{$var} !~ m/$escaped_val/) { 
	$ENV{$var} = "$val".$pathsep.$ENV{$var};
    }
}

sub envvar_append {
    my ($var,$val) = @_;

    # 64 bit linux can't handle ";" as path separator, so make sure to set this to the right one for the OS
    my $pathsep = (defined $ENV{'GSDLOS'} && $ENV{'GSDLOS'} !~ m/windows/) ? ":" : ";";
    
    # do not append any value/path that's already in the environment variable

    my $escaped_val = &filename_to_regex($val); # escape any backslashes and brackets for upcoming regex
    if (!defined($ENV{$var})) {
	$ENV{$var} = "$val";
    }
    elsif($ENV{$var} !~ m/$escaped_val/) { 
	$ENV{$var} = $ENV{$var}.$pathsep."$val";
    }
}

# debug aid
sub print_env {
    my ($handle, @envvars) = @_; # print to $handle, which can be STDERR/STDOUT/file, etc.
    
    if (scalar(@envvars) == 0) {
	#print $handle "@@@ All env vars requested\n";    
	
	my $output = "";
	
	print $handle "@@@ Environment was:\n********\n";		
	foreach my $envvar (sort keys(%ENV)) {
	    if(defined $ENV{$envvar}) {
		print $handle "\t$envvar = $ENV{$envvar}\n";
	    } else {
		print $handle "\t$envvar = \n";
	    }	
	}
	print $handle "********\n";	
    } else {
	print $handle "@@@ Environment was:\n********\n";
	foreach my $envvar (@envvars) {
	    if(defined $ENV{$envvar}) {
		print $handle "\t$envvar = ".$ENV{$envvar}."\n";
	    } else {		
		print $handle "Env var '$envvar' was not set\n";		
	    }
	}
	print $handle "********\n";
    }
}


# splits a filename into a prefix and a tail extension using the tail_re, or 
# if that fails, splits on the file_extension . (dot) 
sub get_prefix_and_tail_by_regex {

    my ($filename,$tail_re) = @_;
    
    my ($file_prefix,$file_ext) = ($filename =~ m/^(.*?)($tail_re)$/);
    if ((!defined $file_prefix) || (!defined $file_ext)) {
	($file_prefix,$file_ext) = ($filename =~ m/^(.*)(\..*?)$/);
    }

    return ($file_prefix,$file_ext);
}

# get full path and file only path from a base_dir (which may be empty) and 
# file (which may contain directories)
sub get_full_filenames {
    my ($base_dir, $file) = @_;
    
#    my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(0);
#    my ($lcfilename) = ($cfilename =~ m/([^\\\/]*)$/);
#    print STDERR "** Calling method: $lcfilename:$cline $cpackage->$csubr\n";


    my $filename_full_path = $file;
    # add on directory if present
    $filename_full_path = &FileUtils::filenameConcatenate($base_dir, $file) if $base_dir =~ /\S/;
    
    my $filename_no_path = $file;

    # remove directory if present
    $filename_no_path =~ s/^.*[\/\\]//;
    return ($filename_full_path, $filename_no_path);
}

# returns the path of a file without the filename -- ie. the directory the file is in
sub filename_head {
    my $filename = shift(@_);

    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$filename =~ s/[^\\\\]*$//;
    }
    else {
	$filename =~ s/[^\\\/]*$//;
    }

    return $filename;
}



# returns 1 if filename1 and filename2 point to the same
# file or directory
sub filenames_equal {
    my ($filename1, $filename2) = @_;

    # use filename_cat to clean up trailing slashes and 
    # multiple slashes
    $filename1 = &FileUtils::filenameConcatenate($filename1);
    $filename2 = &FileUtils::filenameConcatenate($filename2);

    # filenames not case sensitive on windows
    if ($ENV{'GSDLOS'} =~ /^windows$/i) {
	$filename1 =~ tr/[A-Z]/[a-z]/;
	$filename2 =~ tr/[A-Z]/[a-z]/;
    }
    return 1 if $filename1 eq $filename2;
    return 0;
}

# If filename is relative to within_dir, returns the relative path of filename to that directory
# with slashes in the filename returned as they were in the original (absolute) filename.
sub filename_within_directory
{
    my ($filename,$within_dir) = @_;
    
    if ($within_dir !~ m/[\/\\]$/) {
	my $dirsep = &util::get_dirsep();
	$within_dir .= $dirsep;
    }
	
	$within_dir = &filename_to_regex($within_dir); # escape DOS style file separator and brackets	
    if ($filename =~ m/^$within_dir(.*)$/) {
	$filename = $1;
    }
    
    return $filename;
}

# If filename is relative to within_dir, returns the relative path of filename to that directory in URL format.
# Filename and within_dir can be any type of slashes, but will be compared as URLs (i.e. unix-style slashes).
# The subpath returned will also be a URL type filename.
sub filename_within_directory_url_format
{
    my ($filename,$within_dir) = @_;
	
	# convert parameters only to / slashes if Windows
    
	my $filename_urlformat = &filepath_to_url_format($filename);
	my $within_dir_urlformat = &filepath_to_url_format($within_dir);

	#if ($within_dir_urlformat !~ m/\/$/) {
		# make sure directory ends with a slash
		#$within_dir_urlformat .= "/";
    #}
	
	my $within_dir_urlformat_re = &filename_to_regex($within_dir_urlformat); # escape any special RE characters, such as brackets
	
	#print STDERR "@@@@@ $filename_urlformat =~ $within_dir_urlformat_re\n";
	
	# dir prefix may or may not end with a slash (this is discarded when extracting the sub-filepath)
    if ($filename_urlformat =~ m/^$within_dir_urlformat_re(?:\/)*(.*)$/) {
		$filename_urlformat = $1;
    }
    
    return $filename_urlformat;
}

# Convert parameter to use / slashes if Windows (if on Linux leave any \ as is,
# since on Linux it doesn't represent a file separator but an escape char).
sub filepath_to_url_format
{
	my ($filepath) = @_;
	if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
		# Only need to worry about Windows, as Unix style directories already in url-format
		# Convert Windows style \ => /
		$filepath =~ s@\\@/@g;		
	}
	return $filepath;
}

# regex filepaths on windows may include \\ as path separator. Convert \\ to /
sub filepath_regex_to_url_format
{
    my ($filepath) = @_;
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	# Only need to worry about Windows, as Unix style directories already in url-format
	# Convert Windows style \\ => /
	$filepath =~ s@\\\\@/@g;		
    }
    return $filepath;
    
}

# Like File::Basename::fileparse, but expects filepath in url format (ie only / slash for dirsep)
# and ignores trailing /
# returns (file, dirs) dirs will be empty if no subdirs
sub url_fileparse
{
    my ($filepath) = @_;
    # remove trailing /
    $filepath =~ s@/$@@;
    if ($filepath !~ m@/@) {
	return ($filepath, "");
    } 
    my ($dirs, $file) = $filepath =~ m@(.+/)([^/]+)@;
    return ($file, $dirs);
	
}


sub filename_within_collection
{
    my ($filename) = @_;

    my $collect_dir = $ENV{'GSDLCOLLECTDIR'};
    
    if (defined $collect_dir) {

	# if from within GSDLCOLLECTDIR, then remove directory prefix
	# so source_filename is realative to it.  This is done to aid
	# portability, i.e. the collection can be moved to somewhere
	# else on the file system and the archives directory will still
	# work.  This is needed, for example in the applet version of
	# GLI where GSDLHOME/collect on the server will be different to
	# the collect directory of the remove user.  Of course,
	# GSDLCOLLECTDIR subsequently needs to be put back on to turn
	# it back into a full pathname.

	$filename = filename_within_directory($filename,$collect_dir);
    }
    
    return $filename;
}

sub prettyprint_file
{
    my ($base_dir,$file,$gli) = @_;

    my $filename_full_path = &FileUtils::filenameConcatenate($base_dir,$file);

    if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	require Win32;

	# For some reason base_dir in the form c:/a/b/c
	# This leads to confusion later on, so turn it back into
	# the more usual Windows form
	$base_dir =~ s/\//\\/g; 
	my $long_base_dir = Win32::GetLongPathName($base_dir);
	my $long_full_path = Win32::GetLongPathName($filename_full_path);

	$file = filename_within_directory($long_full_path,$long_base_dir);
	$file = encode("utf8",$file) if ($gli);
    }

    return $file;
}


sub upgrade_if_dos_filename
{
    my ($filename_full_path,$and_encode) = @_;

    if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	# Ensure any DOS-like filename, such as test~1.txt, has been upgraded
	# to its long (Windows) version
	my $long_filename = Win32::GetLongPathName($filename_full_path);
	if (defined $long_filename) {
		
	    $filename_full_path = $long_filename;
	}
	# Make sure initial drive letter is lower-case (to fit in with rest of Greenstone)
	$filename_full_path =~ s/^(.):/\u$1:/;
	
	if ((defined $and_encode) && ($and_encode)) {
	    $filename_full_path = encode("utf8",$filename_full_path);
	}
    }

    return $filename_full_path;
}


sub downgrade_if_dos_filename
{
    my ($filename_full_path) = @_;

    if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	require Win32;

	# Ensure the given long Windows filename is in a form that can
	# be opened by Perl => convert it to a short DOS-like filename

	my $short_filename = Win32::GetShortPathName($filename_full_path);
	if (defined $short_filename) {
	    $filename_full_path = $short_filename;
	}
	# Make sure initial drive letter is lower-case (to fit in
	# with rest of Greenstone)
	$filename_full_path =~ s/^(.):/\u$1:/;
    }

    return $filename_full_path;
}


sub filename_is_absolute
{
  warnings::warnif("deprecated", "util::filename_is_absolute() is deprecated, using FileUtils::isFilenameAbsolute() instead");
  return &FileUtils::isFilenameAbsolute(@_);
}


## @method make_absolute()
#
#  Ensure the given file path is absolute in respect to the given base path.
#
#  @param  $base_dir A string denoting the base path the given dir must be
#                    absolute to.
#  @param  $dir The directory to be made absolute as a string. Note that the
#               dir may already be absolute, in which case it will remain
#               unchanged.
#  @return The now absolute form of the directory as a string.
#
#  @author John Thompson, DL Consulting Ltd.
#  @copy 2006 DL Consulting Ltd.
#
#used in buildcol.pl, doesn't work for all cases --kjdon
sub make_absolute {
    
    my ($base_dir, $dir) = @_;
###    print STDERR "dir = $dir\n";
    $dir =~ s/[\\\/]+/\//g;
    $dir = $base_dir . "/$dir" unless ($dir =~ m|^(\w:)?/|); 
    $dir =~ s|^/tmp_mnt||;
    1 while($dir =~ s|/[^/]*/\.\./|/|g);
    $dir =~ s|/[.][.]?/|/|g;
    $dir =~ tr|/|/|s;
###    print STDERR "dir = $dir\n";
    
    return $dir;
}
## make_absolute() ##

sub get_dirsep {

    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	return "\\";
    } else {
	return "\/";
    }
}

sub get_os_dirsep {

    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	return "\\\\";
    } else {
	return "\\\/";
    }
}

sub get_re_dirsep {

    return "\\\\|\\\/";
}


sub get_dirsep_tail {
    my ($filename) = @_;
    
    # returns last part of directory or filename
    # On unix e.g. a/b.d => b.d
    #              a/b/c => c

    my $dirsep = get_re_dirsep();
    my @dirs = split (/$dirsep/, $filename);
    my $tail = pop @dirs;

    # - caused problems under windows
    #my ($tail) = ($filename =~ m/^(?:.*?$dirsep)?(.*?)$/); 

    return $tail;
}


# if this is running on windows we want binaries to end in
# .exe, otherwise they don't have to end in any extension
sub get_os_exe {
    return ".exe" if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin"));
    return "";
}


# test to see whether this is a big or little endian machine
sub is_little_endian
{
    # To determine the name of the operating system, the variable $^O is a cheap alternative to pulling it out of the Config module;
    # If it is a Macintosh machine (i.e. the Darwin operating system), regardless if it's running on the IBM power-pc cpu or the x86 Intel-based chip with a power-pc emulator running on top of it, it's big-endian
    # Otherwise, it's little endian

    #return 0 if $^O =~ /^darwin$/i;
    #return 0 if $ENV{'GSDLOS'} =~ /^darwin$/i;
    
    # Going back to stating exactly whether the machine is little endian
    # or big endian, without any special case for Macs. Since for rata it comes
    # back with little endian and for shuttle with bigendian.
    return (ord(substr(pack("s",1), 0, 1)) == 1);
}


# will return the collection name if successful, "" otherwise
sub use_collection {
    my ($collection, $collectdir) = @_;

    if (!defined $collectdir || $collectdir eq "") {
	$collectdir = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect");
    }

    if (!defined $ENV{'GREENSTONEHOME'}) { # for GS3, would have been defined in use_site_collection, to GSDL3HOME
	 $ENV{'GREENSTONEHOME'} = $ENV{'GSDLHOME'}; 
    }

    # get and check the collection
    if (!defined($collection) || $collection eq "") {
	if (defined $ENV{'GSDLCOLLECTION'}) {
	    $collection = $ENV{'GSDLCOLLECTION'};
	} else {
	    print STDOUT "No collection specified\n";
	    return "";
	}
    }
    
    if ($collection eq "modelcol") {
	print STDOUT "You can't use modelcol.\n";
	return "";
    }

    # make sure the environment variables GSDLCOLLECTION and GSDLCOLLECTDIR
    # are defined
    $ENV{'GSDLCOLLECTION'} = $collection;
    $ENV{'GSDLCOLLECTHOME'} = $collectdir;
    $ENV{'GSDLCOLLECTDIR'} = &FileUtils::filenameConcatenate($collectdir, $collection);

    # make sure this collection exists
    if (!-e $ENV{'GSDLCOLLECTDIR'}) {
	print STDOUT "Invalid collection ($collection).\n";
	return "";
    }

    # everything is ready to go
    return $collection;
}

sub get_current_collection_name {
    return $ENV{'GSDLCOLLECTION'};
}


# will return the collection name if successful, "" otherwise.  
# Like use_collection (above) but for greenstone 3 (taking account of site level)

sub use_site_collection {
    my ($site, $collection, $collectdir) = @_;

    if (!defined $collectdir || $collectdir eq "") {
	die "GSDL3HOME not set.\n" unless defined $ENV{'GSDL3HOME'};
	$collectdir = &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'}, "sites", $site, "collect");
    }

    if (defined $ENV{'GSDL3HOME'}) {
	$ENV{'GREENSTONEHOME'} = $ENV{'GSDL3HOME'}; 	
	$ENV{'SITEHOME'} = &FileUtils::filenameConcatenate($ENV{'GREENSTONEHOME'}, "sites", $site);
    } elsif (defined $ENV{'GSDL3SRCHOME'}) {
	$ENV{'GREENSTONEHOME'} = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "web");	
	$ENV{'SITEHOME'} = &FileUtils::filenameConcatenate($ENV{'GREENSTONEHOME'}, "sites", $site);
    } else {
	print STDERR "*** util::use_site_collection(). Warning: Neither GSDL3HOME nor GSDL3SRCHOME set.\n";
    }

    # collectdir explicitly set by this point (using $site variable if required).
    # Can call "old" gsdl2 use_collection now.

    return use_collection($collection,$collectdir);
}



sub locate_config_file
{
    my ($file) = @_;

    my $locations = locate_config_files($file);

    return shift @$locations; # returns undef if 'locations' is empty
}


sub locate_config_files
{
    my ($file) = @_;

    my @locations = ();

    if (-e $file) {
	# Clearly specified (most likely full filename)
	# No need to hunt in 'etc' directories, return value unchanged
	push(@locations,$file);
    }
    else {
	# Check for collection specific one before looking in global GSDL 'etc'
	if (defined $ENV{'GSDLCOLLECTDIR'} && $ENV{'GSDLCOLLECTDIR'} ne "") {
	    my $test_collect_etc_filename 
		= &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"etc", $file);
	    
	    if (-e $test_collect_etc_filename) {
		push(@locations,$test_collect_etc_filename);
	    }
	}
	my $test_main_etc_filename 
	    = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"etc", $file);
	if (-e $test_main_etc_filename) {
	    push(@locations,$test_main_etc_filename);
	}
    }

    return \@locations;
}


sub hyperlink_text
{
    my ($text) = @_;
    
    $text =~ s/(http:\/\/[^\s]+)/<a href=\"$1\">$1<\/a>/mg;
    $text =~ s/(^|\s+)(www\.(\w|\.)+)/<a href=\"http:\/\/$2\">$2<\/a>/mg;

    return $text;
}


# A method to check if a directory is empty (note that an empty directory still has non-zero size!!!) 
# Code is from http://episteme.arstechnica.com/eve/forums/a/tpc/f/6330927813/m/436007700831
sub is_dir_empty {
  warnings::warnif("deprecated", "util::is_dir_empty() is deprecated, using FileUtils::isDirectoryEmpty() instead");
  return &FileUtils::isDirectoryEmpty(@_);
}

# Returns the given filename converted using either URL encoding or base64
# encoding, as specified by $rename_method. If the given filename has no suffix
# (if it is just the tailname), then $no_suffix should be some defined value.
# rename_method can be url, none, base64 
sub rename_file {
    my ($filename, $rename_method, $no_suffix)  = @_;

    if(!$filename) { # undefined or empty string
	return $filename;
    }

    if (!$rename_method) {
	print STDERR "WARNING: no file renaming method specified. Defaulting to using URL encoding...\n";
	# Debugging information
	# my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(1);
	# print STDERR "Called from method: $cfilename:$cline $cpackage->$csubr\n";
	$rename_method = "url";
    } elsif($rename_method eq "none") {
	return $filename; # would have already been renamed
    }

    # No longer replace spaces with underscores, since underscores mess with incremental rebuild
    ### Replace spaces with underscore. Do this first else it can go wrong below when getting tailname
    ###$filename =~ s/ /_/g;

    my ($tailname,$dirname,$suffix); 
    if($no_suffix) { # given a tailname, no suffix
	($tailname,$dirname) = File::Basename::fileparse($filename);
    } 
    else {
	($tailname,$dirname,$suffix) = File::Basename::fileparse($filename, "\\.(?:[^\\.]+?)\$");
    }
    if (!$suffix) {
	$suffix = "";
    }
    # This breaks GLI matching extracted metadata to files in Enrich panel, as
    # original is eg .JPG while gsdlsourcefilename ends up .jpg
    # Not sure why it was done in first place...
    #else {
	#$suffix = lc($suffix);
    #}

    if ($rename_method eq "url") {
	$tailname = &unicode::url_encode($tailname);
    }
    elsif ($rename_method eq "base64") {
	$tailname = &unicode::base64_encode($tailname);
	$tailname =~ s/\s*//sg;      # for some reason it adds spaces not just at end but also in middle
    }

    $filename = "$tailname$suffix";
    $filename = "$dirname$filename" if ($dirname ne "./" && $dirname ne ".\\");

    return $filename;
}


# BACKWARDS COMPATIBILITY: Just in case there are old .ldb/.bdb files
sub rename_ldb_or_bdb_file {
    my ($filename_no_ext) = @_;

    my $new_filename = "$filename_no_ext.gdb";
    return if (-f $new_filename); # if the file has the right extension, don't need to do anything
    # try ldb
    my $old_filename = "$filename_no_ext.ldb";
    
    if (-f $old_filename) {
	print STDERR "Renaming $old_filename to $new_filename\n";
	rename ($old_filename, $new_filename)
	    || print STDERR "Rename failed: $!\n";
	return;
    }
    # try bdb
    $old_filename = "$filename_no_ext.bdb";
    if (-f $old_filename) {
	print STDERR "Renaming $old_filename to $new_filename\n";	
	rename ($old_filename, $new_filename)
	    || print STDERR "Rename failed: $!\n";
	return;
    }
}

sub os_dir() {
    
    my $gsdlarch = "";
    if(defined $ENV{'GSDLARCH'}) {
	$gsdlarch = $ENV{'GSDLARCH'};
    }
    return $ENV{'GSDLOS'}.$gsdlarch;
}

# returns 1 if this (GS server) is a GS3 installation, returns 0 if it's GS2.
sub is_gs3() {
    if($ENV{'GSDL3SRCHOME'}) {
	return 1;
    } else {
	return 0;
    }
}

# Returns the greenstone URL prefix extracted from the appropriate GS2/GS3 config file. 
# By default, /greenstone3 for GS3 or /greenstone for GS2.
sub get_greenstone_url_prefix() {
    # if already set on a previous occasion, just return that
    # (Don't want to keep repeating this: cost of re-opening and scanning files.)
    return $ENV{'GREENSTONE_URL_PREFIX'} if($ENV{'GREENSTONE_URL_PREFIX'});

    my ($configfile, $urlprefix, $defaultUrlprefix); 
    my @propertynames = ();

    if($ENV{'GSDL3SRCHOME'}) {
	$defaultUrlprefix = "/greenstone3";
	$configfile = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "packages", "tomcat", "conf", "Catalina", "localhost", "greenstone3.xml");
	push(@propertynames, qw/path\s*\=/);
    } else {
	$defaultUrlprefix = "/greenstone";
	$configfile = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "cgi-bin", &os_dir(), "gsdlsite.cfg");
	push(@propertynames, (qw/\nhttpprefix/, qw/\ngwcgi/)); # inspect one property then the other 
    }

    $urlprefix = &extract_propvalue_from_file($configfile, \@propertynames);

    if(!$urlprefix) { # no values found for URL prefix, use default values
	$urlprefix = $defaultUrlprefix;
    } else {
	#gwcgi can contain more than the wanted prefix, we split on / to get the first "directory" level
	$urlprefix =~ s/^\///; # remove the starting slash
	my @dirs = split(/(\\|\/)/, $urlprefix); 
	$urlprefix = shift(@dirs);

	if($urlprefix !~ m/^\//) { # in all cases: ensure the required forward slash is at the front
	    $urlprefix = "/$urlprefix";
	}
    }

    # set for the future
    $ENV{'GREENSTONE_URL_PREFIX'} = $urlprefix;
#    print STDERR "*** in get_greenstone_url_prefix(): $urlprefix\n\n";
    return $urlprefix;
}



#
# The following comes from activate.pl
#
# Designed to work with a server included with GS.
#  - For GS3, we ask ant for the library URL.
#  - For GS2, we derive the URL from the llssite.cfg file.

sub get_full_greenstone_url_prefix
{	
	my ($gs_mode, $lib_name) = @_;
	
    # if already set on a previous occasion, just return that
    # (Don't want to keep repeating this: cost of re-opening and scanning files.)
    return $ENV{'FULL_GREENSTONE_URL_PREFIX'} if($ENV{'FULL_GREENSTONE_URL_PREFIX'});

	# set gs_mode if it was not passed in (servercontrol.pm would pass it in, any other callers won't)
    $gs_mode = ($ENV{'GSDL3SRCHOME'}) ? "gs3" : "gs2" unless defined $gs_mode;
	
    my $url = undef;	
    
    if($gs_mode eq "gs2") {		
	my $llssite_cfg = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "llssite.cfg");
	
	if(-f $llssite_cfg) {
	    # check llssite.cfg for line with url property
	    # for server.exe also need to use portnumber and enterlib properties			
	    
	    # Read in the entire contents of the file in one hit
	    if (!open (FIN, $llssite_cfg)) {
		print STDERR "util::get_full_greenstone_url_prefix() failed to open $llssite_cfg ($!)\n";
		return undef;
	    }
	    
	    my $contents;
	    sysread(FIN, $contents, -s FIN);			
	    close(FIN);
	    
	    my @lines = split(/[\n\r]+/, $contents); # split on carriage-returns and/or linefeeds
	    my $enterlib = "";
	    my $portnumber = "8282"; # will remain empty (implicit port 80) unless it's specifically been assigned
	    
	    foreach my $line (@lines) {				
		if($line =~ m/^url=(.*)$/) {
		    $url = $1;					
		} elsif($line =~ m/^enterlib=(.*)$/) {
		    $enterlib = $1;					
		} elsif($line =~ m/^portnumber=(.*)$/) {
		    $portnumber = $1;					
		}	
	    }
	    
	    if(!$url) {
		return undef;
	    }
	    elsif($url eq "URL_pending") { # library is not running
		# do not process url=URL_pending in the file, since for server.exe 
		# this just means the Enter Library button hasn't been pressed yet				
		$url = undef;
	    }
	    else { 
		# In the case of server.exe, need to do extra work to get the proper URL
		# But first, need to know whether we're indeed dealing with server.exe:
		
		# compare the URL's domain to the full URL
		# E.g. for http://localhost:8383/greenstone3/cgi-bin, the domain is localhost:8383
		my $uri = URI->new( $url );
		my $host = $uri->host;
		#print STDERR "@@@@@ host: $host\n";
		if($url =~ m/https?:\/\/$host(\/)?$/) {
		    #if($url !~ m/https?:\/\/$host:$portnumber(\/)?/ || $url =~ m/https?:\/\/$host(\/)?$/) {
		    # (if the URL does not contain the portnumber, OR if the port is implicitly 80 and)					
		    # If the domain with http:// prefix is completely the same as the URL, assume server.exe
		    # then the actual URL is the result of suffixing the port and enterlib properties in llssite.cfg
		    $url = $url.":".$portnumber.$enterlib;			
		} # else, apache web server			
		
	    }			
	}
    } elsif($gs_mode eq "gs3") {
	# Either check build.properties for tomcat.server, tomcat.port and app.name (and default servlet name).
	# app.name is stored in app.path by build.xml. Need to move app.name in build.properties from build.xml
	
	# Or, run the new target get-default-servlet-url
	# the output can look like:
	#
	# Buildfile: build.xml
	# 	[echo] os.name: Windows Vista
	#
	# get-default-servlet-url:
	#	[echo] http://localhost:8383/greenstone3/library
	# BUILD SUCCESSFUL
	# Total time: 0 seconds
	
	#my $output = qx/ant get-default-servlet-url/; # backtick operator, to get STDOUT (else 2>&1)
	# - see http://stackoverflow.com/questions/799968/whats-the-difference-between-perls-backticks-system-and-exec
	
	# The get-default-servlet-url ant target can be run from anywhere by specifying the
	# location of GS3's ant build.xml buildfile. Activate.pl can be run from anywhere for GS3
	# GSDL3SRCHOME will be set for GS3 by gs3-setup.sh, a step that would have been necessary
	# to run the activate.pl script in the first place
	
	my $full_build_xml = &FileUtils::javaFilenameConcatenate($ENV{'GSDL3SRCHOME'},"build.xml");

	my $perl_command = "ant -buildfile \"$full_build_xml\" get-default-servlet-url";
	
	if (open(PIN, "$perl_command |")) {
	    while (defined (my $perl_output_line = <PIN>)) {

		if($perl_output_line =~ m@(https?):\/\/(\S*)@) { # grab all the non-whitespace chars
		    $url="$1://".$2; # preserve the http protocol #$url="http://".$1;
		}
	    }
	    close(PIN);
		
		if (defined $lib_name) { # url won't be undef now
			# replace the servlet_name portion of the url found, with the given library_name
			$url =~ s@/[^/]*$@/$lib_name@;
		}
	} else {
	    print STDERR "util::get_full_greenstone_url_prefix() failed to run $perl_command to work out library URL for $gs_mode\n";
	}
    }
    
    # either the url is still undef or it is now set
    #print STDERR "\n@@@@@ final URL:|$url|\n" if $url;		
    #print STDERR "\n@@@@@ URL still undef\n" if !$url;

    $ENV{'FULL_GREENSTONE_URL_PREFIX'} = $url;

    return $url;
}


# Given a config file (xml or java properties file) and a list/array of regular expressions
# that represent property names to match on, this function will return the value for the 1st
# matching property name. If the return value is undefined, no matching property was found.
sub extract_propvalue_from_file() {
    my ($configfile, $propertynames) = @_;

    my $value;
    unless(open(FIN, "<$configfile")) { 
	print STDERR "extract_propvalue_from_file(): Unable to open $configfile. $!\n";
	return $value; # not initialised
    }

    # Read the entire file at once, as one single line, then close it
    my $filecontents;
    {
	local $/ = undef;        
	$filecontents = <FIN>;
    }
    close(FIN);

    foreach my $regex (@$propertynames) {
        ($value) = $filecontents=~ m/$regex\s*(\S*)/s; # read value of the property given by regex up to the 1st space
	if($value) { 
            $value =~ s/^\"//;     # remove any startquotes
	    $value =~ s/\".*$//;   # remove the 1st endquotes (if any) followed by any xml
	    last;		       # found value for a matching property, break from loop
	}
    }

    return $value;
}

# Subroutine that sources setup.bash, given GSDLHOME and GSDLOS and
# given that perllib is in @INC in order to invoke this subroutine.
# Call as follows -- after setting up INC to include perllib and 
# after setting up GSDLHOME and GSDLOS:
#
# require util;
# &util::setup_greenstone_env($ENV{'GSDLHOME'}, $ENV{'GSDLOS'});
#
sub setup_greenstone_env() {
	my ($GSDLHOME, $GSDLOS) = @_;

	#my %env_map = ();
	# Get the localised ENV settings of running a localised source setup.bash 
	# and put it into the ENV here. Need to clear GSDLHOME before running setup
	#my $perl_command = "(cd $GSDLHOME; export GSDLHOME=; . ./setup.bash > /dev/null; env)";
	my $perl_command = "(cd $GSDLHOME; /bin/bash -c \"export GSDLHOME=; source setup.bash > /dev/null; env\")";		
	if (($GSDLOS =~ m/windows/i) && ($^O ne "cygwin"))  {
		#$perl_command = "cmd /C \"cd $GSDLHOME&& set GSDLHOME=&& setup.bat > nul&& set\"";
		$perl_command = "(cd $GSDLHOME&& set GSDLHOME=&& setup.bat > nul&& set)";
	}
	if (!open(PIN, "$perl_command |")) {
		print STDERR ("Unable to execute command: $perl_command. $!\n");
	}

	my $lastkey;
	while (defined (my $perl_output_line = <PIN>)) {
		my($key,$value) = ($perl_output_line =~ m/^([^=]*)[=](.*)$/);
		if(defined $key) {
		    #$env_map{$key}=$value;		
		    $ENV{$key}=$value;
		    $lastkey = $key;
		} elsif($lastkey && $perl_output_line !~ m/^\s*$/) { 
		    # there was no equals sign in $perl_output_line, so this 
		    # $perl_output_line may be a spillover from the previous
		    $ENV{$lastkey} = $ENV{$lastkey}."\n".$perl_output_line;
		}
	}
	close (PIN);

	# If any keys in $ENV don't occur in Greenstone's localised env 
	# (stored in $env_map), delete those entries from $ENV
	#foreach $key (keys %ENV) {	
	#	if(!defined $env_map{$key}) { 
	#		print STDOUT "**** DELETING ENV KEY: $key\tVALUE: $ENV{$key}\n";
	#		delete $ENV{$key}; # del $ENV(key, value) pair
	#	}
	#}
	#undef %env_map;
}

sub get_perl_exec() {	
	my $perl_exec = $^X; # may return just "perl"
	
	if($ENV{'PERLPATH'}) {
		# OR: # $perl_exec = &FileUtils::filenameConcatenate($ENV{'PERLPATH'},"perl");
		if (($ENV{'GSDLOS'} =~ m/windows/) && ($^O ne "cygwin")) {
			$perl_exec = "$ENV{'PERLPATH'}\\Perl.exe";
		} else {
			$perl_exec = "$ENV{'PERLPATH'}/perl";
		}
	} else { # no PERLPATH, use Config{perlpath} else $^X: special variables
		# containing the full path to the current perl executable we're using
		$perl_exec = $Config{perlpath}; # configured path for perl
		if (!-e $perl_exec) { # may not point to location on this machine
			$perl_exec = $^X; # may return just "perl"
			if($perl_exec =~ m/^perl/i) { # warn if just perl or Perl.exe
				print STDERR "**** WARNING: Perl exec found contains no path: $perl_exec";				
			}
		}
    }
	
	return $perl_exec;
}

# returns the path to the java command in the JRE included with GS (if any),
# quoted to safeguard any spaces in this path, otherwise a simple java
# command is returned which assumes and will try for a system java.
sub get_java_command {
    my $java = "java";
    if(defined $ENV{'GSDLHOME'}) { # should be, as this script would be launched from the cmd line 
	                           # after running setup.bat or from GLI which also runs setup.bat
	my $java_bin = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"packages","jre","bin");
	if(-d $java_bin) {
	    $java = &FileUtils::filenameConcatenate($java_bin,"java");
	    $java = "\"".$java."\""; # quoted to preserve spaces in path
	}
    }
    return $java;
}


# Given the qualified collection name (colgroup/collection), 
# returns the collection and colgroup parts
sub get_collection_parts {
	# http://perldoc.perl.org/File/Basename.html
	# my($filename, $directories, $suffix) = fileparse($path);
	# "$directories contains everything up to and including the last directory separator in the $path 
	# including the volume (if applicable). The remainder of the $path is the $filename."
	#my ($collection, $colgroup) = &File::Basename::fileparse($qualified_collection);	

	my $qualified_collection = shift(@_); 

	# Since activate.pl can be launched from the command-line, including by a user, 
	# best not to assume colgroup uses URL-style slashes as would be the case with GLI
	# Also allow for the accidental inclusion of multiple slashes
	my ($colgroup, $collection) = split(/[\/\\]+/, $qualified_collection); #split('/', $qualified_collection);
	
	if(!defined $collection) {
		$collection = $colgroup;
		$colgroup = "";
	}
	return ($collection, $colgroup);
}

# work out the "collectdir/collection" location
sub resolve_collection_dir {
	my ($collect_dir, $qualified_collection, $site) = @_; #, $gs_mode
	
	if (defined $ENV{'GSDLCOLLECTDIR'}) { # a predefined collection dir exists
	    return $ENV{'GSDLCOLLECTDIR'};
	}

	my ($colgroup, $collection) = &util::get_collection_parts($qualified_collection);	
	
	if (!defined $collect_dir || !$collect_dir) { # if undefined or empty string
	    $collect_dir = &util::get_working_collect_dir($site);
	}

	return &FileUtils::filenameConcatenate($collect_dir,$colgroup,$collection);
}

# work out the full path to "collect" of this greenstone 2/3 installation
sub get_working_collect_dir {
    my ($site) = @_;    

    if (defined $ENV{'GSDLCOLLECTHOME'}) { # a predefined collect dir exists
	return $ENV{'GSDLCOLLECTHOME'};
    }

    if (defined $site && $site) { # site non-empty, so get default collect dir for GS3
	
	if (defined $ENV{'GSDL3HOME'}) {
	    return &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'},"sites",$site,"collect"); # web folder
	} 
	elsif (defined $ENV{'GSDL3SRCHOME'}) {
	    return &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'},"web","sites",$site,"collect");
	}
    } 

    elsif (defined $ENV{'SITEHOME'}) {
	return &FileUtils::filenameConcatenate($ENV{'SITEHOME'},"collect");
    }
    
    else { # get default collect dir for GS2
	return &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"collect");
    }
}

sub is_abs_path_any_os {
    my ($path) = @_;

    # We can have filenames in our DBs that were produced on other OS, so this method exists
    # to help identify absolute paths in such cases.

    return 1 if($path =~ m@^/@); # full paths begin with forward slash on linux/mac
    return 1 if($path =~ m@^([a-zA-Z]\:|\\)@); # full paths begin with drive letter colon for Win or \ for volume, http://stackoverflow.com/questions/13011013/get-only-volume-name-from-filepath

    return 0;
}


# This subroutine is for improving portability of Greenstone collections from one OS to another,
# to be used to convert absolute paths going into db files into paths with placeholders instead.
# This sub works with util::get_common_gs_paths and takes a path to a greenstone file and, if it's
# an absolute path, then it will replace the longest matching greenstone-path prefix of the given 
# path with a placeholder to match.
# The Greenstone-path prefixes that can be matched are the following common Greenstone paths: 
# the path to the current (specific) collection, the path to the general GS collect directory, 
# the path to the site directory if GS3, else the path to the GSDLHOME/GSDL3HOME folder.
# The longest matching prefix will be replaced with the equivalent placeholder: 
# @THISCOLLECTPATH@, else @COLLECTHOME@, else @SITEHOME@, else @GSDLHOME@.
sub abspath_to_placeholders {
    my $path = shift(@_); # path to convert from absolute to one with placeholders
    my $opt_long_or_short_winfilenames = shift(@_) || "short"; # whether we want to force use of long file names even on windows, default uses short

    return $path unless is_abs_path_any_os($path); # path is relative

    if ($opt_long_or_short_winfilenames eq "long") {
	$path = &util::upgrade_if_dos_filename($path); # will only do something on windows
    }
	
    # now we know we're dealing with absolute paths and have to replace gs prefixes with placeholders
    my @gs_paths = ($ENV{'GSDLCOLLECTDIR'}, $ENV{'GSDLCOLLECTHOME'}, $ENV{'SITEHOME'}, $ENV{'GREENSTONEHOME'}); # list in this order: from longest to shortest path

    my %placeholder_map = ($ENV{'GREENSTONEHOME'} => '@GSDLHOME@', # can't use double-quotes around at-sign, else perl tries to evaluate it as referring to an array
			   $ENV{'GSDLCOLLECTHOME'} => '@COLLECTHOME@',
			   $ENV{'GSDLCOLLECTDIR'} => '@THISCOLLECTPATH@'
	);
    $placeholder_map{$ENV{'SITEHOME'}} = '@SITEHOME@' if defined $ENV{'SITEHOME'};

    $path = &util::_abspath_to_placeholders($path, \@gs_paths, \%placeholder_map);

    if ($ENV{'GSDLOS'} =~ /^windows$/i && $opt_long_or_short_winfilenames eq "short") {
	# for windows need to look for matches on short file names too
	# matched paths are again to be replaced with the usual placeholders

	my $gsdlcollectdir = &util::downgrade_if_dos_filename($ENV{'GSDLCOLLECTDIR'});
	my $gsdlcollecthome = &util::downgrade_if_dos_filename($ENV{'GSDLCOLLECTHOME'});
	my $sitehome = (defined $ENV{'SITEHOME'}) ? &util::downgrade_if_dos_filename($ENV{'SITEHOME'}) : undef;
	my $greenstonehome =  &util::downgrade_if_dos_filename($ENV{'GREENSTONEHOME'});

	@gs_paths = ($gsdlcollectdir, $gsdlcollecthome, $sitehome, $greenstonehome); # order matters

	%placeholder_map = ($greenstonehome => '@GSDLHOME@', # can't use double-quotes around at-sign, else perl tries to evaluate it as referring to an array
			    $gsdlcollecthome => '@COLLECTHOME@',
			    $gsdlcollectdir => '@THISCOLLECTPATH@'
	    );
	$placeholder_map{$sitehome} = '@SITEHOME@' if defined $sitehome;

	$path = &util::_abspath_to_placeholders($path, \@gs_paths, \%placeholder_map);
    }

    return $path;
}

sub _abspath_to_placeholders {
    my ($path, $gs_paths_ref, $placeholder_map_ref) = @_;

    # The sequence of elements in @gs_paths matters    
    # Need to loop starting from the *longest* matching path (the path to the specific collection) 
    # to the shortest matching path (the path to gsdlhome/gsdl3home folder):

    foreach my $gs_path (@$gs_paths_ref) { 
	next if(!defined $gs_path); # site undefined for GS2

	my $re_path =  &util::filename_to_regex($gs_path); # escape for regex

	if($path =~ m/^$re_path/i) { # case sensitive or not for OS?

	    my $placeholder = $placeholder_map_ref->{$gs_path}; # get the placeholder to replace the matched path with

	    $path =~ s/^$re_path/$placeholder/; #case sensitive or not?
	    #$path =~ s/^[\\\/]//; # remove gs_path's trailing separator left behind at the start of the path
		# lowercase file extension, This is needed when shortfilenames are used, as case affects alphetical ordering, which affects diffcol		
		$path =~ s/\.([A-Z]+)$/".".lc($1)/e;
	    last; # done
	}
    }
    
    return $path;
}

# Function that does the reverse of the util::abspath_to_placeholders subroutine
# Once again, call this with the values returned from util::get_common_gs_paths
sub placeholders_to_abspath {
    my $path = shift(@_); # path that can contain placeholders to convert to resolved absolute path
    my $opt_long_or_short_winfilenames = shift(@_) || "short"; # whether we want to force use of long file names even on windows, default uses short

    return $path if($path !~ m/@/); # path contains no placeholders
    
    # replace placeholders with gs prefixes
    my @placeholders = ('@THISCOLLECTPATH@', '@COLLECTHOME@', '@SITEHOME@', '@GSDLHOME@'); # order of paths not crucial in this case, 
                       # but listed here from longest to shortest once placeholders are have been resolved

    # can't use double-quotes around at-sign, else perl tries to evaluate it as referring to an array
    my %placeholder_to_gspath_map;
    if ($ENV{'GSDLOS'} =~ /^windows$/i && $opt_long_or_short_winfilenames eq "short") {
	# always replace placeholders with short file names of the absolute paths on windows?
	%placeholder_to_gspath_map = ('@GSDLHOME@' => &util::downgrade_if_dos_filename($ENV{'GREENSTONEHOME'}),
				     '@COLLECTHOME@' => &util::downgrade_if_dos_filename($ENV{'GSDLCOLLECTHOME'}),
				     '@THISCOLLECTPATH@' => &util::downgrade_if_dos_filename($ENV{'GSDLCOLLECTDIR'})
	);
	$placeholder_to_gspath_map{'@SITEHOME@'} =  &util::downgrade_if_dos_filename($ENV{'SITEHOME'}) if defined $ENV{'SITEHOME'};
    } else {
	%placeholder_to_gspath_map = ('@GSDLHOME@' => $ENV{'GREENSTONEHOME'},
				      '@SITEHOME@' => $ENV{'SITEHOME'}, # can be undef
				      '@COLLECTHOME@' => $ENV{'GSDLCOLLECTHOME'},
				      '@THISCOLLECTPATH@' => $ENV{'GSDLCOLLECTDIR'}
	    ); # $placeholder_to_gspath_map{'@SITEHOME@'} = $ENV{'SITEHOME'} if defined $ENV{'SITEHOME'};
    }

    foreach my $placeholder (@placeholders) { 
	my $gs_path = $placeholder_to_gspath_map{$placeholder};

	next if(!defined $gs_path); # sitehome for GS2 is undefined

	if($path =~ m/^$placeholder/) {
	    $path =~ s/^$placeholder/$gs_path/;
	    last; # done
	}
    }
    
    return $path;
}

# Used by pdfpstoimg.pl and PDFBoxConverter to create a .item file from
# a directory containing sequentially numbered images.
sub create_itemfile
{
    my ($output_dir, $convert_basename, $convert_to) = @_;
    my $page_num = "";

    opendir(DIR, $output_dir) || die "can't opendir $output_dir: $!";
    my @dir_files = grep {-f "$output_dir/$_"} readdir(DIR);
    closedir DIR;

    # Sort files in the directory by page_num
    sub page_number {
	my ($dir) = @_;
	my ($pagenum) =($dir =~ m/^.*?[-\.]?(\d+)(\.(jpg|gif|png))?$/i);
#	my ($pagenum) =($dir =~ m/(\d+)(\.(jpg|gif|png))?$/i); # this works but is not as safe/strict about input filepatterns as the above

	$pagenum = 1 unless defined $pagenum;
	return $pagenum;
    }

    # sort the files in the directory in the order of page_num rather than lexically.
    @dir_files = sort { page_number($a) <=> page_number($b) } @dir_files;

    # work out if the numbering of the now sorted image files starts at 0 or not
    # by checking the number of the first _image_ file (skipping item files)
    my $starts_at_0 = 0;
    my $firstfile = ($dir_files[0] !~ /\.item$/i) ? $dir_files[0] : $dir_files[1];
    if(page_number($firstfile) == 0) { # 00 will evaluate to 0 too in this condition
	$starts_at_0 = 1;
    }

    my $item_file = &FileUtils::filenameConcatenate($output_dir, $convert_basename.".item");
    my $item_fh;
    &FileUtils::openFileHandle($item_file, 'w', \$item_fh);
    print $item_fh "<PagedDocument>\n";

    foreach my $file (@dir_files){
	if ($file !~ /\.item/i){
	    $page_num = page_number($file);
	    $page_num++ if $starts_at_0; # image numbers start at 0, so add 1
	    print $item_fh "   <Page pagenum=\"$page_num\" imgfile=\"$file\" txtfile=\"\"/>\n";
	}
    }

    print $item_fh "</PagedDocument>\n";
    &FileUtils::closeFileHandle($item_file, \$item_fh);
    return $item_file;
}

# Sets the gnomelib_env. Based on the logic in wvware.pl which can perhaps be replaced with a call to this function in future
sub set_gnomelib_env
{
    ## SET THE ENVIRONMENT AS DONE IN SETUP.BASH/BAT OF GNOME-LIB
    # Though this is only needed for darwin Lion at this point (and android, though that is untested)

    my $libext = "so";
    if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
	return;
    } elsif ($ENV{'GSDLOS'} =~ m/^darwin$/i) {
	$libext = "dylib";
    }

    if (!defined $ENV{'GEXTGNOME'}) {
        ##print STDERR "@@@ Setting GEXTGNOME env\n";

	my $gnome_dir = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"ext","gnome-lib-minimal");

	if(! -d $gnome_dir) {
	    $gnome_dir = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"ext","gnome-lib");

	    if(! -d $gnome_dir) {
		$gnome_dir = "";
	    }
	}
    
	# now set other the related env vars, 
	# IF we've found the gnome-lib dir installed in the ext folder	

	if ($gnome_dir ne "" && -f &FileUtils::filenameConcatenate($gnome_dir, $ENV{'GSDLOS'}, "lib", "libiconv.$libext")) {
	    $ENV{'GEXTGNOME'} = $gnome_dir;
	    $ENV{'GEXTGNOME_INSTALLED'}=&FileUtils::filenameConcatenate($ENV{'GEXTGNOME'}, $ENV{'GSDLOS'});
	   
	    my $gnomelib_bin = &FileUtils::filenameConcatenate($ENV{'GEXTGNOME_INSTALLED'}, "bin");
	    if(-d $gnomelib_bin) { # no bin subfolder in GS binary's cutdown gnome-lib-minimal folder
		&util::envvar_prepend("PATH", $gnomelib_bin);
	    }

	    # util's prepend will create LD/DYLD_LIB_PATH if it doesn't exist yet
	    my $gextlib = &FileUtils::filenameConcatenate($ENV{'GEXTGNOME_INSTALLED'}, "lib");

	    if($ENV{'GSDLOS'} eq "linux") {
		&util::envvar_prepend("LD_LIBRARY_PATH", $gextlib);
	    } 
	    elsif ($ENV{'GSDLOS'} eq "darwin") {
		#&util::envvar_prepend("DYLD_LIBRARY_PATH", $gextlib);
		&util::envvar_prepend("DYLD_FALLBACK_LIBRARY_PATH", $gextlib);
	    }
	}
	
	# Above largely mimics the setup.bash of the gnome-lib-minimal.
	# Not doing the devel-srcpack that gnome-lib-minimal's setup.bash used to set
	# Not exporting GSDLEXTS variable either
    }

#    print STDERR "@@@@@ GEXTGNOME: ".$ENV{'GEXTGNOME'}."\n\tINSTALL".$ENV{'GEXTGNOME_INSTALLED'}."\n";
#    print STDERR "\tPATH".$ENV{'PATH'}."\n";
#    print STDERR "\tLD_LIB_PATH".$ENV{'LD_LIBRARY_PATH'}."\n" if $ENV{'LD_LIBRARY_PATH};
#    print STDERR "\tDYLD_FALLBACK_LIB_PATH".$ENV{'DYLD_FALLBACK_LIBRARY_PATH'}."\n" if $ENV{'DYLD_FALLBACK_LIBRARY_PATH};

    # if no GEXTGNOME, maybe users didn't need gnome-lib to run gnomelib/libiconv dependent binaries like hashfile, suffix, wget 
    # (wvware is launched in a gnomelib env from its own script, but could possibly go through this script in future)
}



## @function augmentINC()
#
#  Prepend a path (if it exists) onto INC but only if it isn't already in INC
#  @param $new_path The path to add
#  @author jmt12
#
sub augmentINC
{
  my ($new_path) = @_;
  my $did_add_path = 0;
  # might need to be replaced with FileUtils::directoryExists() call eventually
  if (-d $new_path)
  {
    my $did_find_path = 0;
    foreach my $existing_path (@INC)
    {
      if ($existing_path eq $new_path)
      {
        $did_find_path = 1;
        last;
      }
    }
    if (!$did_find_path)
    {
      unshift(@INC, $new_path);
      $did_add_path = 1;
    }
  }
  return $did_add_path;
}
## augmentINC()


1;
