#!/usr/bin/perl -w

###########################################################################
#
# delcol.pl --
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

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use util;
use parsargv;

sub print_usage {
    print STDERR "\n";
    print STDERR "delcol.pl: Deletes (forever) a collection.\n\n";
    print STDERR "  usage: $0 [options] collection-name\n\n";
    print STDERR "  options:\n";
    print STDERR "   -f                     Force deletion of collection without prompting\n\n";
}

&main();

sub main {
    my $force = 0;
    if (!parsargv::parse(\@ARGV, 'f', \$force)) {
	&print_usage();
	die "\n";
    }

    # get and check the collection name
    if (($collection = &util::use_collection(@ARGV)) eq "") {
	&print_usage();
	exit (1);
    }

    if (!$force) {
	print STDOUT "Are you sure you want to completely remove the $collection collection?\n";
	print STDOUT "(the $ENV{'GSDLCOLLECTDIR'} directory will be deleted). [y/n]\n";
	my $in = <STDIN>;
	if ($in !~ /^y(es)?$/i) {
	    print STDOUT "Deletion of $collection collection cancelled\n";
	    exit (0);
	}
    }
    # delete any temporary files that are laying around
    my $tmpdir = &util::filename_cat ($ENV{'GSDLHOME'}, "tmp");
    if (opendir (TMPDIR, $tmpdir)) {
	my @tmpfiles = readdir (TMPDIR);
	closedir TMPDIR;
	map { &util::rm(&util::filename_cat($tmpdir, $_)) if $_ =~ /^$collection/; } @tmpfiles;
    }

    &util::rm_r ($ENV{'GSDLCOLLECTDIR'});

    # check if everything was deleted successfully
    if (-d $ENV{'GSDLCOLLECTDIR'}) {
	print STDERR "\ndelcol.pl WARNING: Not all files in $ENV{'GSDLCOLLECTDIR'} could\n";
	print STDERR "be deleted\n";
	exit (2);
    }

    print STDERR "$collection collection successfully deleted\n";
    exit (0);
}
