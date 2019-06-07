#!/usr/bin/perl -w

###########################################################################
#
# filecopy.pl --
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


# This program will "download" the specified files/directories

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use util;
use parsargv;
use File::stat;
use File::Basename;
use FileHandle;

sub print_usage {
    print STDERR "\n";
    print STDERR "filecopy.pl: Recursively copies files into a collections import directory.\n\n";
    print STDERR "\n  usage: $0 [options] [directories] collection-name\n\n";

    print STDERR "  options:\n";
    print STDERR "   -follow_links           Follow symbolic links when recursing directory\n";
    print STDERR "                           structure\n";
    print STDOUT "   -collectdir directory   Collection directory (defaults to " .
	&util::filename_cat($ENV{'GSDLHOME'}). "collect for Greenstone2;\n";
    print STDOUT"                            for Greenstone3 use -site option and then collectdir default will be\n";
    print STDOUT "                            set to the collect folder within that site.)\n";
    print STDOUT "   -site                   Specify the site within a Greenstone3 installation to use.\n";
    print STDERR "   -out                    Filename or handle to print output status to.\n";
    print STDERR "                           The default is STDERR\n\n";
}

sub get_file_list {
    my $dirhash = shift @_;
    my $filehash = shift @_;
    my $dirname = shift @_;

    my $full_importname 
	= &util::filename_cat($collectdir, $dirname, "import");

    # check for .kill file
    if (-e &util::filename_cat($collectdir, $dirname, ".kill")) {
	print $out "filecopy.pl killed by .kill file\n";
	die "\n";
    }

    foreach my $file (@_) {

	$file =~ s/^\"//;
	$file =~ s/\"$//;

	if (!$follow_links && -l $file) {
	    # do nothing as we don't want to follow symbolic links

	} elsif (-d $file) {
	    my $dst_dir = &get_dst_dir ($full_importname, $file);
	    # add this directory to the list to be created
	    $dirhash->{$dst_dir} = 1;

	    # read in dir
            if (!opendir (DIR, $file)) {
                print $out "Error: Could not open directory $file\n";
            } else {
                my @sub_files = grep (!/^\.\.?$/, readdir (DIR));
                closedir DIR;
		map { $_ = &util::filename_cat($file, $_); } @sub_files;
		&get_file_list($dirhash, $filehash, $dirname, @sub_files);
	    }

	} else {
	    my $dst_file = &get_dst_dir ($full_importname, $file);

	    # make sure files directory is included in dirhash
	    $dirhash->{File::Basename::dirname($dst_file)} = 1;

	    if (-e $dst_file) {
		# if destination file exists already we'll only copy it if
		# the source file is newer
		my $src_stat = stat($file);
		my $dst_stat = stat($dst_file);
		$filehash->{$file} = $dst_file if ($src_stat->mtime > $dst_stat->mtime);
	    } else {
		$filehash->{$file} = $dst_file;
	    }
	}
    }
}


sub main {

    if (!parsargv::parse(\@ARGV, 
			 'follow_links', \$follow_links,
			 'collectdir/.*/', \$collectdir,
			 'site/.*/', \$site,
			 'out/.*/STDERR', \$out)) {
	&print_usage();
	die "\n";
    }


    if (defined $site && $site =~ /\w/ )
    {
	die "GSDL3HOME not set." unless $ENV{'GSDL3HOME'};
	$collectdir = &util::filename_cat ($ENV{'GSDL3HOME'}, "sites", $site, "collect") unless $collectdir =~ /\w/;
    }
    else
    {
	$collectdir = &util::filename_cat ($ENV{'GSDLHOME'}, "collect") unless $collectdir =~ /\w/;
    }

    my $collection = pop @ARGV;

    my $close_out = 0;
    if ($out !~ /^(STDERR|STDOUT)$/i) {
	open (OUT, ">$out") || die "Couldn't open output file $out\n";
	$out = OUT;
	$close_out = 1;
    }
    $out->autoflush(1);

    # first compile a list of all the files we want to copy (we do it this
    # way rather than simply copying the files as we recurse the directory
    # structure to avoid nasty infinite recursion if the directory we're
    # copying to happens to be a subdirectory of one of the directories
    # we're copying from)
    my $dirhash = {};
    my $filehash = {};
    &get_file_list($dirhash, $filehash, $collection, @ARGV);

    # create all the required destination directories
    my $count = 0;
    foreach my $dir (keys %$dirhash) {
	# check for .kill file
	if (($count ++ % 20 == 0) &&
	    (-e &util::filename_cat($collectdir, $collection, ".kill"))) {
	    print $out "filecopy.pl killed by .kill file\n";
	    die "\n";
	}
	&util::mk_all_dir($dir);
    }

    # copy all the files
    foreach my $file (keys %$filehash) {
	# check for .kill file
	if (($count ++ % 20 == 0) &&
	    (-e &util::filename_cat($collectdir, $collection, ".kill"))) {
	    print $out "filecopy.pl killed by .kill file\n";
	    die "\n";
	}
	print $out "copying $file --> $filehash->{$file}\n";
	&util::cp($file, $filehash->{$file});
    }

    close OUT if $close_out;
    return 0;
}

sub get_dst_dir {
    my ($full_importname, $dir) = @_;

    if ($ENV{'GSDLOS'} eq "windows") {
	# don't want windows filenames like c:\gsdl\...\import\c:\dir
	$dir =~ s/^[a-z]:[\\\/]//i;
    }
    return &util::filename_cat($full_importname, $dir);
}

&main();
