#!/usr/bin/perl -w

###########################################################################
#
# urldownload.pl --
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
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");

    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/lib");
    $ENV{'PATH'} = "$ENV{'GSDLHOME'}/perllib/cpan/bin:$ENV{'PATH'}";
}

my @quoted_argv = map { "\"$_\"" } @ARGV;

my $args = join(' ', @quoted_argv);
$cmd = "w3mir $args";

my $status = system($cmd);
$status /= 256;
if ($status != 0)
{
    print STDERR "Error: failed to execute $cmd\n";
    exit($status);
}

