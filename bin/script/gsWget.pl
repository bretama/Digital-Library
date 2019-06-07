#!/usr/bin/perl -w

###########################################################################
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


# This program will download the specified urls (http:, ftp: and file:)


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use util;
use FileUtils;

# wget should live in the Greenstone directory structure
# we'll bail if we can't find it
my $exe = &util::get_os_exe ();
my $cmd = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wget");
$cmd .= $exe;
if (! -e "$cmd") {
    die "gsWget.pl failed: $cmd doesn't exist\n";
}

# if on windows we expect wget to already be on the path -
# this allows us to avoid problems when GSDLHOME contains spaces
# (double quoting the call doesn't work on win2000)
if ($ENV{'GSDLOS'} =~ /^windows$/) {
    $cmd = "wget";
}

# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

# command-line parameters
my @quoted_argv = map { "\"$_\"" } @ARGV;
my $args = join(' ', @quoted_argv);
$cmd .= " $args";

# run the command
my $status = system($cmd);

# We should check the error status of wget; unfortunately this
# is set to 1 even when we exit successfully, so we ignore it.
#
#$status /= 256;
#if ($status != 0) {
#    print STDERR "Error executing $cmd: $!\n";
#    exit($status);
#}

print "\nDone: $cmd\n";
