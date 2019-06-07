#!/usr/bin/perl -w

###########################################################################
#
# cancel_build.pl --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2000 New Zealand Digital Library Project
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


# This program will create a .kill file within the GSDLCOLLECTDIR/collect-name
# directory which will cause any import.pl or buildcol.pl processes running
# on that collection to abort.
# It then cleans any mess left laying around the collection (including the
# import directory !!).
# cancel_build.pl is really only intended to be called from within the 
# library's collectoraction and isn't much use for anything else. As such it
# should be rewritten in C++ one day and included in the collectoraction 
# itself.

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use util;
use parsargv;
use File::Copy;

sub print_usage {
    print STDERR "\n";
    print STDERR "cancel_build.pl: Cancel a build in progress. This script is\n";
    print STDERR "                 called from the collector and is not intended\n";
    print STDERR "                 for general use.\n\n";
    print STDERR "  usage: $0 [options] collection-name\n\n";
    print STDERR "  options:\n";
    print STDERR "   -collectdir directory  Collection directory (defaults to " .
	&util::filename_cat ($ENV{'GSDLHOME'}, "collect") . ")\n\n";
}

&main();

sub main {
    if (!parsargv::parse(\@ARGV, 'collectdir/.*/', \$collectdir)) {
	&print_usage();
	die "\n";
    }

    my $collection = pop @ARGV;
    if (!defined $collection || $collection !~ /\w/) {
	print STDERR "no collection specified\n";
	&print_usage();
	die "\n";
    }

    my $cdir = &util::filename_cat ($collectdir, $collection);
    if ($collectdir eq "") {
	$collectdir = &util::filename_cat ($ENV{'GSDLHOME'}, "collect");
	$cdir = &util::filename_cat ($collectdir, $collection);
    } elsif (!-d $cdir) {
	$cdir = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", $collection);
    }

    if (! -d $cdir) {
	print STDERR "Collection does not exist ($cdir)\n";
	exit (1);
    }

    # create .kill file
    my $killfile = &util::filename_cat ($cdir, ".kill");
    if (!open (KILLFILE, ">$killfile")) {
	print STDERR "Couldn't create .kill file ($killfile)\n";
	exit (1);
    }
    print KILLFILE "kill $collection\n";
    close KILLFILE;

    sleep (2); # just give it a chance to die gracefully;

    # remove archives, building, and import directories
    &util::rm_r (&util::filename_cat ($cdir, "import"));
    &util::rm_r (&util::filename_cat ($cdir, "building"));
    &util::rm_r (&util::filename_cat ($cdir, "archives"));

    # remove any other temporary files that may have been left laying around
    # by the build
    my $buildfile = &util::filename_cat ($collectdir, ".build");
    &util::rm ($buildfile) if -e $buildfile;
    my $bldfile = &util::filename_cat ($collectdir, "$collection.bld");
    &util::rm ($bldfile) if -e $bldfile;
    my $bldfile_d = &util::filename_cat ($collectdir, "$collection.bld.download");
    &util::rm ($bldfile_d) if -e $bldfile_d;
    my $bldfile_i = &util::filename_cat ($collectdir, "$collection.bld.import");
    &util::rm ($bldfile_i) if -e $bldfile_i;
    my $bldfile_b = &util::filename_cat ($collectdir, "$collection.bld.build");
    &util::rm ($bldfile_b) if -e $bldfile_b;
    my $bldfile_f = &util::filename_cat ($collectdir, "$collection.bld.final");
    &util::rm ($bldfile_f) if -e $bldfile_f;
    
    # if there's an archives.org directory, rename it back to archives
    if (-d &util::filename_cat ($cdir, "archives.org")) {
	&File::Copy::move (&util::filename_cat ($cdir, "archives.org"),
			   &util::filename_cat ($cdir, "archives"));
    }
}
