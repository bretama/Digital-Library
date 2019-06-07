#!/usr/bin/perl -w

###########################################################################
#
# nightly.pl
#
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


# This program will find all the collections under $GSDLHOME/collect
# and use the update.pl script to update them all.  It should be run
# every night to keep mirror collections up-to-date.


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/classify");
}

use arcinfo;
use colcfg;
use util;
use parsargv;

sub print_usage {
    print STDERR "\n";
    print STDERR "nightly.pl: Attempts to update all Greenstone collections found on\n";
    print STDERR "            the local filesystem by calling update.pl for each of\n";
    print STDERR "            them.\n\n";
    print STDERR "  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -verbosity number      0=none, 3=lots\n";
    print STDERR "   -importdir directory   Where to place the mirrored material\n";
    print STDERR "   -archivedir directory  Where the converted material ends up\n";
}


&main ();

sub main {
    my ($verbosity, $collectdir, $name, $collection);

    if (!parsargv::parse(\@ARGV, 
			 'verbosity/\d+/2', \$verbosity )) {
	&print_usage();
	die "\n";
    }


    # get the contents of the collect directory
    $collectdir =  &util::filename_cat($ENV{'GSDLHOME'}, "collect");
    opendir(CDIR, $collectdir) || die "Cannot open $collectdir: $!";
    my @files = readdir(CDIR);
    closedir CDIR;


    # update each collection
    foreach $name (@files) {

	$collection = &util::filename_cat($collectdir, $name);

	# igore entries for "." and ".."
	next unless ($name =~ /[^\.]/);

	# ignore modelcol
	next if ($name eq "modelcol");

	# ignore entries that are not directories
	next unless (-d $collection);

	# ignore directories that do not have a subdir called etc
	next unless (-d &util::filename_cat($collection, "etc"));

	print "Updating: $name\n";
	print `update.pl $name`;
	
    }

}
