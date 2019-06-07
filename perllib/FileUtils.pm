###########################################################################
#
# FileUtils.pm -- functions for dealing with files. Skeleton for more
# advanced system using dynamic class cloading available in extensions.
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the
# University of Waikato, New Zealand.
#
# Copyright (C) 2013 New Zealand Digital Library Project
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

package FileUtils;

# Pragma
use strict;
use warnings;

use FileHandle;

# Greenstone modules
use util;

################################################################################
# util::cachedir()             => FileUtils::synchronizeDirectory()
# util::cp()                   => FileUtils::copyFiles()
# util::cp_r()                 => FileUtils::copyFilesRecursive()
# util::cp_r_nosvn()           => FileUtils::copyFilesRecursiveNoSVN()
# util::cp_r_toplevel()        => FileUtils::copyFilesRecursiveTopLevel()
# util::differentfiles()       => FileUtils::differentFiles()
# util::dir_exists()           => FileUtils::directoryExists()
# util::fd_exists()            => FileUtils::fileTest()
# util::file_exists()          => FileUtils::fileExists()
# util::filename_cat()         => FileUtils::filenameConcatenate()
# util::filename_is_absolute() => FileUtils::isFilenameAbsolute()
# util::filtered_rm_r()        => FileUtils::removeFilesFiltered()
# util::hard_link()            => FileUtils::hardLink()
# util::is_dir_empty()         => FileUtils::isDirectoryEmpty()
# util::mk_all_dir()           => FileUtils::makeAllDirectories()
# util::mk_dir()               => FileUtils::makeDirectory()
# util::mv()                   => FileUtils::moveFiles()
# util::mv_dir_contents()      => FileUtils::moveDirectoryContents()
# util::rm()                   => FileUtils::removeFiles()
# util::rm_r()                 => FileUtils::removeFilesRecursive()
# util::soft_link()            => FileUtils::softLink()

# Other functions in this file (perhaps some of these may have counterparts in util.pm too):

#canRead
#isSymbolicLink
#modificationTime
#readDirectory
#removeFilesDebug
#sanitizePath
#openFileHandle
#closeFileHandle
#differentFiles
#filePutContents
#fileSize
#readDirectory

################################################################################
# Note: there are lots of functions involving files/directories/paths
# etc found in utils.pm that are not represented here. My intention
# was to just have those functions that need to be dynamic based on
# filesystem, or need some rejigging to be filesystem aware. There is
# an argument, I guess, for moving some of the other functions here so
# that they are nicely encapsulated - but the question is what to do
# with functions like filename_within_directory_url_format() which is
# more URL based than file based.
################################################################################


## @function canRead()
#
sub canRead
{
  my ($filename_full_path) = @_;
  return &fileTest($filename_full_path, '-R');
}
## canRead()


## @function closeFileHandle
#
sub closeFileHandle
{
  my ($path, $fh_ref) = @_;
  close($$fh_ref);
}
## closeFileHandle()


## @function copyFiles()
#
# copies a file or a group of files
#
sub copyFiles
{
  my $dest = pop (@_);
  my (@srcfiles) = @_;

  # remove trailing slashes from source and destination files
  $dest =~ s/[\\\/]+$//;
  map {$_ =~ s/[\\\/]+$//;} @srcfiles;

  # a few sanity checks
  if (scalar (@srcfiles) == 0)
  {
    print STDERR "FileUtils::copyFiles() no destination directory given\n";
    return;
  }
  elsif ((scalar (@srcfiles) > 1) && (!-d $dest))
  {
    print STDERR "FileUtils::copyFiles() if multiple source files are given the destination must be a directory\n";
    return;
  }

  # copy the files
  foreach my $file (@srcfiles)
  {
    my $tempdest = $dest;
    if (-d $tempdest)
    {
      my ($filename) = $file =~ /([^\\\/]+)$/;
      $tempdest .= "/$filename";
    }
    if (!-e $file)
    {
      print STDERR "FileUtils::copyFiles() $file does not exist\n";
    }
    elsif (!-f $file)
    {
      print STDERR "FileUtils::copyFiles() $file is not a plain file\n";
    }
    else
    {
      &File::Copy::copy ($file, $tempdest);
    }
  }
}
## copyFiles()


## @function copyFilesRecursive()
#
# recursively copies a file or group of files syntax: cp_r
# (sourcefiles, destination directory) destination must be a directory
# to copy one file to another use cp instead
#
sub copyFilesRecursive
{
  my $dest = pop (@_);
  my (@srcfiles) = @_;

  # a few sanity checks
  if (scalar (@srcfiles) == 0)
  {
    print STDERR "FileUtils::copyFilesRecursive() no destination directory given\n";
    return;
  }
  elsif (-f $dest)
  {
    print STDERR "FileUtils::copyFilesRecursive() destination must be a directory\n";
    return;
  }

  # create destination directory if it doesn't exist already
  if (! -d $dest)
  {
    my $store_umask = umask(0002);
    mkdir ($dest, 0777);
    umask($store_umask);
  }

  # copy the files
  foreach my $file (@srcfiles)
  {

    if (!-e $file)
    {
      print STDERR "FileUtils::copyFilesRecursive() $file does not exist\n";
    }
    elsif (-d $file)
    {
      # make the new directory
      my ($filename) = $file =~ /([^\\\/]*)$/;
      $dest = &filenameConcatenate($dest, $filename);
      my $store_umask = umask(0002);
      mkdir ($dest, 0777);
      umask($store_umask);

      # get the contents of this directory
      if (!opendir (INDIR, $file))
      {
        print STDERR "FileUtils::copyFilesRecursive() could not open directory $file\n";
      }
      else
      {
        my @filedir = readdir (INDIR);
        closedir (INDIR);
        foreach my $f (@filedir)
        {
          next if $f =~ /^\.\.?$/;
          # copy all the files in this directory
          my $ff = &filenameConcatenate($file, $f);
          &copyFilesRecursive($ff, $dest);
        }
      }

    }
    else
    {
      &copyFiles($file, $dest);
    }
  }
}
## copyFilesRecursive()


## @function copyFilesRecursiveNoSVN()
#
# recursively copies a file or group of files, excluding SVN
# directories, with syntax: cp_r (sourcefiles, destination directory)
# destination must be a directory - to copy one file to another use cp
# instead
#
# this should be merged with copyFilesRecursive() at some stage - jmt12
#
sub copyFilesRecursiveNoSVN
{
  my $dest = pop (@_);
  my (@srcfiles) = @_;

  # a few sanity checks
  if (scalar (@srcfiles) == 0)
  {
    print STDERR "FileUtils::copyFilesRecursiveNoSVN() no destination directory given\n";
    return;
  }
  elsif (-f $dest)
  {
    print STDERR "FileUtils::copyFilesRecursiveNoSVN() destination must be a directory\n";
    return;
  }

  # create destination directory if it doesn't exist already
  if (! -d $dest)
  {
    my $store_umask = umask(0002);
    mkdir ($dest, 0777);
    umask($store_umask);
  }

  # copy the files
  foreach my $file (@srcfiles)
  {
    if (!-e $file)
    {
      print STDERR "copyFilesRecursiveNoSVN() $file does not exist\n";
    }
    elsif (-d $file)
    {
      # make the new directory
      my ($filename) = $file =~ /([^\\\/]*)$/;
      $dest = &filenameConcatenate($dest, $filename);
      my $store_umask = umask(0002);
      mkdir ($dest, 0777);
      umask($store_umask);

      # get the contents of this directory
      if (!opendir (INDIR, $file))
      {
        print STDERR "copyFilesRecursiveNoSVN() could not open directory $file\n";
      }
      else
      {
        my @filedir = readdir (INDIR);
        closedir (INDIR);
        foreach my $f (@filedir)
        {
          next if $f =~ /^\.\.?$/;
          next if $f =~ /^\.svn$/;
          # copy all the files in this directory
          my $ff = &filenameConcatenate($file, $f);
          # util.pm version incorrectly called cp_r here - jmt12
          &copyFilesRecursiveNoSVN($ff, $dest);
        }
      }
    }
    else
    {
      &copyFiles($file, $dest);
    }
  }
}
## copyFilesRecursiveNoSVN()


## @function copyFilesRecursiveTopLevel()
#
# copies a directory and its contents, excluding subdirectories, into a new directory
#
# another candidate for merging in with copyFilesRecursive() - jmt12
#
sub copyFilesRecursiveTopLevel
{
  my $dest = pop (@_);
  my (@srcfiles) = @_;

  # a few sanity checks
  if (scalar (@srcfiles) == 0)
  {
    print STDERR "FileUtils::copyFilesRecursiveTopLevel() no destination directory given\n";
    return;
  }
  elsif (-f $dest)
  {
    print STDERR "FileUtils::copyFilesRecursiveTopLevel() destination must be a directory\n";
    return;
  }

  # create destination directory if it doesn't exist already
  if (! -d $dest)
  {
    my $store_umask = umask(0002);
    mkdir ($dest, 0777);
    umask($store_umask);
  }

  # copy the files
  foreach my $file (@srcfiles)
  {
    if (!-e $file)
    {
      print STDERR "FileUtils::copyFilesRecursiveTopLevel() $file does not exist\n";
    }
    elsif (-d $file)
    {
      # make the new directory
      my ($filename) = $file =~ /([^\\\/]*)$/;
      $dest = &filenameConcatenate($dest, $filename);
      my $store_umask = umask(0002);
      mkdir ($dest, 0777);
      umask($store_umask);

      # get the contents of this directory
      if (!opendir (INDIR, $file))
      {
        print STDERR "FileUtils::copyFilesRecursiveTopLevel() could not open directory $file\n";
      }
      else
      {
        my @filedir = readdir (INDIR);
        closedir (INDIR);
        foreach my $f (@filedir)
        {
          next if $f =~ /^\.\.?$/;

          # copy all the files in this directory, but not directories
          my $ff = &filenameConcatenate($file, $f);
          if (-f $ff)
          {
            &copyFiles($ff, $dest);
            #&cp_r ($ff, $dest);
          }
        }
      }
    }
    else
    {
      &copyFiles($file, $dest);
    }
  }
}
## copyFilesRecursiveTopLevel()


## @function differentFiles()
#
# this function returns -1 if either file is not found assumes that
# $file1 and $file2 are absolute file names or in the current
# directory $file2 is allowed to be newer than $file1
#
sub differentFiles
{
  my ($file1, $file2, $verbosity) = @_;
  $verbosity = 1 unless defined $verbosity;

  $file1 =~ s/\/+$//;
  $file2 =~ s/\/+$//;

  my ($file1name) = $file1 =~ /\/([^\/]*)$/;
  my ($file2name) = $file2 =~ /\/([^\/]*)$/;

  return -1 unless (-e $file1 && -e $file2);
  if ($file1name ne $file2name)
  {
    print STDERR "filenames are not the same\n" if ($verbosity >= 2);
    return 1;
  }

  my @file1stat = stat ($file1);
  my @file2stat = stat ($file2);

  if (-d $file1)
  {
    if (! -d $file2)
    {
      print STDERR "one file is a directory\n" if ($verbosity >= 2);
      return 1;
    }
    return 0;
  }

  # both must be regular files
  unless (-f $file1 && -f $file2)
  {
    print STDERR "one file is not a regular file\n" if ($verbosity >= 2);
    return 1;
  }

  # the size of the files must be the same
  if ($file1stat[7] != $file2stat[7])
  {
    print STDERR "different sized files\n" if ($verbosity >= 2);
    return 1;
  }

  # the second file cannot be older than the first
  if ($file1stat[9] > $file2stat[9])
  {
    print STDERR "file is older\n" if ($verbosity >= 2);
    return 1;
  }

  return 0;
}
## differentFiles()


## @function directoryExists()
#
sub directoryExists
{
  my ($filename_full_path) = @_;
  return &fileTest($filename_full_path, '-d');
}
## directoryExists()


## @function fileExists()
#
sub fileExists
{
  my ($filename_full_path) = @_;
  return &fileTest($filename_full_path, '-f');
}
## fileExists()

## @function filenameConcatenate()
#
sub filenameConcatenate
{
  my $first_file = shift(@_);
  my (@filenames) = @_;

  #   Useful for debugging
  #     -- might make sense to call caller(0) rather than (1)??
  #   my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(1);
  #   print STDERR "Calling method: $cfilename:$cline $cpackage->$csubr\n";

  # If first_file is not null or empty, then add it back into the list
  if (defined $first_file && $first_file =~ /\S/)
  {
    unshift(@filenames, $first_file);
  }

  my $filename = join("/", @filenames);

  # remove duplicate slashes and remove the last slash
  if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin"))
  {
    $filename =~ s/[\\\/]+/\\/g;
  }
  else
  {
    $filename =~ s/[\/]+/\//g;
    # DB: want a filename abc\de.html to remain like this
  }
  $filename =~ s/[\\\/]$//;

  return $filename;
}
## filenameConcatenate()



## @function javaFilenameConcatenate()
#
# Same as filenameConcatenate(), except because on Cygwin
# the java we run is still Windows native, then this means
# we want the generate filename to be in native Windows format
sub javaFilenameConcatenate
{
  my (@filenames) = @_;

  my $filename_cat = filenameConcatenate(@filenames);

  if ($^O eq "cygwin") {
      # java program, using a binary that is native to Windows, so need
      # Windows directory and path separators

      $filename_cat = `cygpath -wp "$filename_cat"`;
      chomp($filename_cat);
      $filename_cat =~ s%\\%\\\\%g;
  }

  return $filename_cat;
}
## javaFilenameConcatenate()


## @function filePutContents()
#
# Create a file and write the given string directly to it
# @param $path the full path of the file to write as a String
# @param $content the String to be written to the file
#
sub filePutContents
{
  my ($path, $content) = @_;
  if (open(FOUT, '>:utf8', $path))
  {
    print FOUT $content;
    close(FOUT);
  }
  else
  {
    die('Error! Failed to open file for writing: ' . $path . "\n");
  }
}
## filePutContents()

## @function fileSize()
#
sub fileSize
{
  my $path = shift(@_);
  my $file_size = -s $path;
  return $file_size;
}
## fileSize()

## @function fileTest()
#
sub fileTest
{
  my $filename_full_path = shift @_;
  my $test_op = shift @_ || "-e";

  # By default tests for existance of file or directory (-e)
  # Can be made more specific by providing second parameter (e.g. -f or -d)

  my $exists = 0;

  if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin"))
  {
    require Win32;
    my $filename_short_path = Win32::GetShortPathName($filename_full_path);
    if (!defined $filename_short_path)
    {
      # Was probably still in UTF8 form (not what is needed on Windows)
      my $unicode_filename_full_path = eval "decode(\"utf8\",\$filename_full_path)";
      if (defined $unicode_filename_full_path)
      {
        $filename_short_path = Win32::GetShortPathName($unicode_filename_full_path);
      }
    }
    $filename_full_path = $filename_short_path;
  }

  if (defined $filename_full_path)
  {
    $exists = eval "($test_op \$filename_full_path)";
  }

  return $exists || 0;
}
## fileTest()

## @function hardLink()
# make hard link to file if supported by OS, otherwise copy the file
#
sub hardLink
{
  my ($src, $dest, $verbosity) = @_;

  # remove trailing slashes from source and destination files
  $src =~ s/[\\\/]+$//;
  $dest =~ s/[\\\/]+$//;

  ##    print STDERR "**** src = ", unicode::debug_unicode_string($src),"\n";
  # a few sanity checks
  if (-e $dest)
  {
    # destination file already exists
    return;
  }
  elsif (!-e $src)
  {
    print STDERR "FileUtils::hardLink() source file \"" . $src . "\" does not exist\n";
    return 1;
  }
  elsif (-d $src)
  {
    print STDERR "FileUtils::hardLink() source \"" . $src . "\" is a directory\n";
    return 1;
  }

  my $dest_dir = &File::Basename::dirname($dest);
  if (!-e $dest_dir)
  {
    &makeAllDirectories($dest_dir);
  }

  if (!link($src, $dest))
  {
    if ((!defined $verbosity) || ($verbosity>2))
    {
      print STDERR "FileUtils::hardLink(): unable to create hard link. ";
      print STDERR " Copying file: $src -> $dest\n";
    }
    &File::Copy::copy ($src, $dest);
  }
  return 0;
}
## hardLink()

## @function isDirectoryEmpty()
#
# A method to check if a directory is empty (note that an empty
# directory still has non-zero size!!!).  Code is from
# http://episteme.arstechnica.com/eve/forums/a/tpc/f/6330927813/m/436007700831
#
sub isDirectoryEmpty
{
  my ($path) = @_;
  opendir DIR, $path;
  while(my $entry = readdir DIR)
  {
    next if($entry =~ /^\.\.?$/);
    closedir DIR;
    return 0;
  }
  closedir DIR;
  return 1;
}
## isDirectoryEmpty()

## @function isFilenameAbsolute()
#
sub isFilenameAbsolute
{
  my ($filename) = @_;
  if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin"))
  {
    return ($filename =~ m/^(\w:)?\\/);
  }
  return ($filename =~ m/^\//);
}
# isFilenameAbsolute()

## @function isSymbolicLink
#
# Determine if a given path is a symbolic link (soft link)
#
sub isSymbolicLink
{
  my $path = shift(@_);
  my $is_soft_link = -l $path;
  return $is_soft_link;
}
## isSymbolicLink()

## @function makeAllDirectories()
#
# in case anyone cares - I did some testing (using perls Benchmark module)
# on this subroutine against File::Path::mkpath (). mk_all_dir() is apparently
# slightly faster (surprisingly) - Stefan.
#
sub makeAllDirectories
{
  my ($dir) = @_;

  # use / for the directory separator, remove duplicate and
  # trailing slashes
  $dir=~s/[\\\/]+/\//g;
  $dir=~s/[\\\/]+$//;

  # make sure the cache directory exists
  my $dirsofar = "";
  my $first = 1;
  foreach my $dirname (split ("/", $dir))
  {
    $dirsofar .= "/" unless $first;
    $first = 0;

    $dirsofar .= $dirname;

    next if $dirname =~ /^(|[a-z]:)$/i;
    if (!-e $dirsofar)
    {
      my $store_umask = umask(0002);
      my $mkdir_ok = mkdir ($dirsofar, 0777);
      umask($store_umask);
      if (!$mkdir_ok)
      {
        print STDERR "FileUtils::makeAllDirectories() could not create directory $dirsofar\n";
        return;
      }
    }
  }
 return 1;
}
## makeAllDirectories()

## @function makeDirectory()
#
sub makeDirectory
{
  my ($dir) = @_;

  my $store_umask = umask(0002);
  my $mkdir_ok = mkdir ($dir, 0777);
  umask($store_umask);

  if (!$mkdir_ok)
  {
    print STDERR "FileUtils::makeDirectory() could not create directory $dir\n";
    return;
  }
}
## makeDirectory()

## @function modificationTime()
#
sub modificationTime
{
  my $path = shift(@_);
  my @file_status = stat($path);
  return $file_status[9];
}
## modificationTime()

## @function moveDirectoryContents()
#
# Move the contents of source directory into target directory (as
# opposed to merely replacing target dir with the src dir) This can
# overwrite any files with duplicate names in the target but other
# files and folders in the target will continue to exist
#
sub moveDirectoryContents
{
  my ($src_dir, $dest_dir) = @_;

  # Obtain listing of all files within src_dir
  # Note that readdir lists relative paths, as well as . and ..
  opendir(DIR, "$src_dir");
  my @files= readdir(DIR);
  close(DIR);

  my @full_path_files = ();
  foreach my $file (@files)
  {
    # process all except . and ..
    unless($file eq "." || $file eq "..")
    {
      my $dest_subdir = &filenameConcatenate($dest_dir, $file); # $file is still a relative path

      # construct absolute paths
      $file = &filenameConcatenate($src_dir, $file); # $file is now an absolute path

      # Recurse on directories which have an equivalent in target dest_dir
      # If $file is a directory that already exists in target $dest_dir,
      # then a simple move operation will fail (definitely on Windows).
      if(-d $file && -d $dest_subdir)
      {
        #print STDERR "**** $file is a directory also existing in target, its contents to be copied to $dest_subdir\n";
        &moveDirectoryContents($file, $dest_subdir);

        # now all content is moved across, delete empty dir in source folder
        if(&isDirectoryEmpty($file))
        {
          if (!rmdir $file)
          {
            print STDERR "ERROR. FileUtils::moveDirectoryContents() couldn't remove directory $file\n";
          }
        }
        # error
        else
        {
          print STDERR "ERROR. FileUtils::moveDirectoryContents(): subfolder $file still non-empty after moving contents to $dest_subdir\n";
        }
      }
      # process files and any directories that don't already exist with a simple move
      else
      {
        push(@full_path_files, $file);
      }
    }
  }

  # create target toplevel folder or subfolders if they don't exist
  if(!&directoryExists($dest_dir))
  {
    &makeDirectory($dest_dir);
  }

  #print STDERR "@@@@@ Copying files |".join(",", @full_path_files)."| to: $dest_dir\n";

  # if non-empty, there's something to copy across
  if(@full_path_files)
  {
    &moveFiles(@full_path_files, $dest_dir);
  }
}
## moveDirectoryContents()

## @function moveFiles()
#
# moves a file or a group of files
#
sub moveFiles
{
  my $dest = pop (@_);
  my (@srcfiles) = @_;

  # remove trailing slashes from source and destination files
  $dest =~ s/[\\\/]+$//;
  map {$_ =~ s/[\\\/]+$//;} @srcfiles;

  # a few sanity checks
  if (scalar (@srcfiles) == 0)
  {
    print STDERR "FileUtils::moveFiles() no destination directory given\n";
    return;
  }
  elsif ((scalar (@srcfiles) > 1) && (!-d $dest))
  {
    print STDERR "FileUtils::moveFiles() if multiple source files are given the destination must be a directory\n";
    return;
  }

  # move the files
  foreach my $file (@srcfiles)
  {
    my $tempdest = $dest;
    if (-d $tempdest)
    {
      my ($filename) = $file =~ /([^\\\/]+)$/;
      $tempdest .= "/$filename";
    }
    if (!-e $file)
    {
      print STDERR "FileUtils::moveFiles() $file does not exist\n";
    }
    else
    {
      if(!rename ($file, $tempdest))
      {
        print STDERR "**** Failed to rename $file to $tempdest\n";
        &File::Copy::copy($file, $tempdest);
        &removeFiles($file);
      }
      # rename (partially) succeeded) but srcfile still exists after rename
      elsif(-e $file)
      {
        #print STDERR "*** srcfile $file still exists after rename to $tempdest\n";
        if(!-e $tempdest)
        {
          print STDERR "@@@@ ERROR: $tempdest does not exist\n";
        }
        # Sometimes the rename operation fails (as does
        # File::Copy::move).  This turns out to be because the files
        # are hardlinked.  Need to do a copy-delete in this case,
        # however, the copy step is not necessary: the srcfile got
        # renamed into tempdest, but srcfile itself still exists,
        # delete it.  &File::Copy::copy($file, $tempdest);
        &removeFiles($file);
      }
    }
  }
}
## moveFiles()

## @function openFileHandle()
#
sub openFileHandle
{
  my $path = shift(@_);
  my $mode = shift(@_);
  my $fh_ref = shift(@_);
  my $encoding = shift(@_);
  my $mode_symbol;
  if ($mode eq 'w' || $mode eq '>')
  {
    $mode_symbol = '>';
    $mode = 'writing';
  }
  elsif ($mode eq 'a' || $mode eq '>>')
  {
    $mode_symbol = '>>';
    $mode = 'appending';
  }
  else
  {
    $mode_symbol = '<';
    $mode = 'reading';
  }
  if (defined $encoding)
  {
    $mode_symbol .= ':' . $encoding;
  }
  return open($$fh_ref, $mode_symbol, $path);
}
## openFileHandle()


## @function readDirectory()
#
sub readDirectory
{
  my $path = shift(@_);
  my @files;
  if (opendir(DH, $path))
  {
    @files = readdir(DH);
    close(DH);
  }
  else
  {
    die("Error! Failed to open directory to list files: " . $path . "\n");
  }
  return \@files;
}
## readDirectory()

## @function removeFiles()
#
# removes files (but not directories)
#
sub removeFiles
{
  my (@files) = @_;
  my @filefiles = ();

  # make sure the files we want to delete exist
  # and are regular files
  foreach my $file (@files)
  {
    if (!-e $file)
    {
      print STDERR "FileUtils::removeFiles() $file does not exist\n";
    }
    elsif ((!-f $file) && (!-l $file))
    {
      print STDERR "FileUtils::removeFiles() $file is not a regular (or symbolic) file\n";
    }
    else
    {
      push (@filefiles, $file);
    }
  }

  # remove the files
  my $numremoved = unlink @filefiles;

  # check to make sure all of them were removed
  if ($numremoved != scalar(@filefiles))
  {
    print STDERR "FileUtils::removeFiles() Not all files were removed\n";
  }
}
## removeFiles()

## @function removeFilesDebug()
#
# removes files (but not directories) - can rename this to the default
# "rm" subroutine when debugging the deletion of individual files.
# Unused?
#
sub removeFilesDebug
{
  my (@files) = @_;
  my @filefiles = ();

  # make sure the files we want to delete exist
  # and are regular files
  foreach my $file (@files)
  {
    if (!-e $file)
    {
      print STDERR "FileUtils::removeFilesDebug() " . $file . " does not exist\n";
    }
    elsif ((!-f $file) && (!-l $file))
    {
      print STDERR "FileUtils::removeFilesDebug() " . $file . " is not a regular (or symbolic) file\n";
    }
    # debug message
    else
    {
      unlink($file) or warn "Could not delete file " . $file . ": " . $! . "\n";
    }
  }
}
## removeFilesDebug()

## @function removeFilesFiltered()
#
sub removeFilesFiltered
{
  my ($files,$file_accept_re,$file_reject_re) = @_;

  #   my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(2);
  #   my ($lcfilename) = ($cfilename =~ m/([^\\\/]*)$/);
  #   print STDERR "** Calling method (2): $lcfilename:$cline $cpackage->$csubr\n";

  my @files_array = (ref $files eq "ARRAY") ? @$files : ($files);

  # recursively remove the files
  foreach my $file (@files_array)
  {
    $file =~ s/[\/\\]+$//; # remove trailing slashes

    if (!-e $file)
    {
      print STDERR "FileUtils::removeFilesFiltered() $file does not exist\n";
    }
    # don't recurse down symbolic link
    elsif ((-d $file) && (!-l $file))
    {
      # get the contents of this directory
      if (!opendir (INDIR, $file))
      {
        print STDERR "FileUtils::removeFilesFiltered() could not open directory $file\n";
      }
      else
      {
        my @filedir = grep (!/^\.\.?$/, readdir (INDIR));
        closedir (INDIR);

        # remove all the files in this directory
        map {$_="$file/$_";} @filedir;
        &removeFilesFiltered(\@filedir,$file_accept_re,$file_reject_re);

        if (!defined $file_accept_re && !defined $file_reject_re)
        {
          # remove this directory
          if (!rmdir $file)
          {
            print STDERR "FileUtils::removeFilesFiltered() couldn't remove directory $file\n";
          }
        }
      }
    }
    else
    {
      next if (defined $file_reject_re && ($file =~ m/$file_reject_re/));

      if ((!defined $file_accept_re) || ($file =~ m/$file_accept_re/))
      {
        # remove this file
        &removeFiles($file);
      }
    }
  }
}
## removeFilesFiltered()

## @function removeFilesRecursive()
#
# The equivalent of "rm -rf" with all the dangers therein
#
sub removeFilesRecursive
{
  my (@files) = @_;

  # use the more general (but reterospectively written) function
  # filtered_rm_r function() with no accept or reject expressions
  &removeFilesFiltered(\@files,undef,undef);
}
## removeFilesRecursive()

## @function sanitizePath()
#
sub sanitizePath
{
  my ($path) = @_;

  # fortunately filename concatenate will perform all the double slash
  # removal and end slash removal we need, and in a protocol aware
  # fashion
  return &filenameConcatenate($path);
}
## sanitizePath()

## @function softLink()
#
# make soft link to file if supported by OS, otherwise copy file
#
sub softLink
{
  my ($src, $dest, $ensure_paths_absolute) = @_;

  # remove trailing slashes from source and destination files
  $src =~ s/[\\\/]+$//;
  $dest =~ s/[\\\/]+$//;

  # Ensure file paths are absolute IF requested to do so
  # Soft_linking didn't work for relative paths
  if(defined $ensure_paths_absolute && $ensure_paths_absolute)
  {
    # We need to ensure that the src file is the absolute path
    # See http://perldoc.perl.org/File/Spec.html
    # it's relative
    if(!File::Spec->file_name_is_absolute( $src ))
    {
      $src = File::Spec->rel2abs($src); # make absolute
    }
    # Might as well ensure that the destination file's absolute path is used
    if(!File::Spec->file_name_is_absolute( $dest ))
    {
      $dest = File::Spec->rel2abs($dest); # make absolute
    }
  }

  # a few sanity checks
  if (!-e $src)
  {
    print STDERR "FileUtils::softLink() source file $src does not exist\n";
    return 0;
  }

  my $dest_dir = &File::Basename::dirname($dest);
  if (!-e $dest_dir)
  {
    &makeAllDirectories($dest_dir);
  }

  if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin"))
  {
    # symlink not supported on windows
    &File::Copy::copy ($src, $dest);
  }
  elsif (!eval {symlink($src, $dest)})
  {
    print STDERR "FileUtils::softLink(): unable to create soft link.\n";
    return 0;
  }
  return 1;
}
## softLink()

## @function synchronizeDirectory()
#
# updates a copy of a directory in some other part of the filesystem
# verbosity settings are: 0=low, 1=normal, 2=high
# both $fromdir and $todir should be absolute paths
#
sub synchronizeDirectory
{
  my ($fromdir, $todir, $verbosity) = @_;
  $verbosity = 1 unless defined $verbosity;

  # use / for the directory separator, remove duplicate and
  # trailing slashes
  $fromdir=~s/[\\\/]+/\//g;
  $fromdir=~s/[\\\/]+$//;
  $todir=~s/[\\\/]+/\//g;
  $todir=~s/[\\\/]+$//;

  &makeAllDirectories($todir);

  # get the directories in ascending order
  if (!opendir (FROMDIR, $fromdir))
  {
    print STDERR "FileUtils::synchronizeDirectory() could not read directory $fromdir\n";
    return;
  }
  my @fromdir = grep (!/^\.\.?$/, sort(readdir (FROMDIR)));
  closedir (FROMDIR);

  if (!opendir (TODIR, $todir))
  {
    print STDERR "FileUtils::synchronizeDirectory() could not read directory $todir\n";
    return;
  }
  my @todir = grep (!/^\.\.?$/, sort(readdir (TODIR)));
  closedir (TODIR);

  my $fromi = 0;
  my $toi = 0;

  while ($fromi < scalar(@fromdir) || $toi < scalar(@todir))
  {
    #	print "fromi: $fromi toi: $toi\n";

    # see if we should delete a file/directory
    # this should happen if the file/directory
    # is not in the from list or if its a different
    # size, or has an older timestamp
    if ($toi < scalar(@todir))
    {
      if (($fromi >= scalar(@fromdir)) || ($todir[$toi] lt $fromdir[$fromi] || ($todir[$toi] eq $fromdir[$fromi] && &differentFiles("$fromdir/$fromdir[$fromi]","$todir/$todir[$toi]", $verbosity))))
      {

        # the files are different
        &removeFilesRecursive("$todir/$todir[$toi]");
        splice(@todir, $toi, 1); # $toi stays the same

      }
      elsif ($todir[$toi] eq $fromdir[$fromi])
      {
        # the files are the same
        # if it is a directory, check its contents
        if (-d "$todir/$todir[$toi]")
        {
          &synchronizeDirectory("$fromdir/$fromdir[$fromi]", "$todir/$todir[$toi]", $verbosity);
        }

        $toi++;
        $fromi++;
        next;
      }
    }

    # see if we should insert a file/directory
    # we should insert a file/directory if there
    # is no tofiles left or if the tofile does not exist
    if ($fromi < scalar(@fromdir) && ($toi >= scalar(@todir) || $todir[$toi] gt $fromdir[$fromi]))
    {
      &cp_r ("$fromdir/$fromdir[$fromi]", "$todir/$fromdir[$fromi]");
      splice (@todir, $toi, 0, $fromdir[$fromi]);

      $toi++;
      $fromi++;
    }
  }
}
## synchronizeDirectory()

1;
