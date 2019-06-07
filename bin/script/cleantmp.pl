#!/usr/bin/perl

###########################################################################
#
# cleantmp.pl
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


# cleantmp.pl cleans up the gsdl/tmp directory
# it's intended mainly for use by the collectoraction

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use parsargv;
use util;

sub print_usage {
    print STDERR "\n";
    print STDERR "cleantmp.pl: Cleans up the Greenstone tmp directory by deleting anything\n";
    print STDERR "             more than -expire_days days old.\n\n";
    print STDERR "\n  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -expire_days number   The number of days old information in the tmp\n";
    print STDERR "                         directory must be before it is removed (defaults\n";
    print STDERR "                         to 7 days)\n\n";
}

&main ();

sub main {
    
    if (!parsargv::parse(\@ARGV, 'expire_days/\d/7', \$expire_days)) {
	&print_usage();
	die "\n";
    }

    my $current_time = time;
    my $expire_time = ($current_time - ($expire_days*60*60*24));

    my $tmpdir = &util::filename_cat ($ENV{'GSDLHOME'}, "tmp");

    opendir (TMP, $tmpdir) || die "cleantmp.pl: couldn't open $tmpdir\n";
    my @files = readdir TMP;
    closedir TMP;

    foreach $file (@files) {
	next if ($file =~ /^\.\.$/);

	if ($file =~ /^tbuild/) {
	    my $thisfile = &util::filename_cat ($tmpdir, $file);
	    my @stats = stat ($thisfile);
	    if ($stats[9] < $expire_time) {
		&util::rm_r ($thisfile);
	    }
	}
    }
}
