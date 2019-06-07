#!/usr/bin/perl -w

###########################################################################
#
# full-buildcol.pl -- runs buildcol.pl with -removeold option on
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


# This program will "buildcol" (or re-"buildcol") a collection from scratch
# Runs:        buildcol.pl -removeold ...

BEGIN {
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
	unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
use util;

my $quoted_argv = join(" ", map { "\"$_\"" } @ARGV);

my $buildcol_cmd = "\"".&util::get_perl_exec()."\" -S buildcol.pl -removeold $quoted_argv";

my $buildcol_status = system($buildcol_cmd)/256;

if ($buildcol_status != 0) {
    print STDERR "Error: Failed to run: $buildcol_cmd\n";
    print STDERR "       $!\n" if ($! ne "");
    exit(-1);
}




