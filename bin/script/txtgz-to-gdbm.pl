#!/usr/bin/perl -w

###########################################################################
#
# txtgz-to-gdbm --
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


# This script invokes gzip to unzip the textual database. It is necessary, 
# since the C++ code that directly invokes it fails on Windows. The added
# benefit of doing this via the perl script here is that if an external
# webserver was used (such as Apache), it will probably still work.



use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

my $txtgz_filename = $ARGV[0];
my $gdbm_filename = $ARGV[1];

	
if (scalar(@ARGV)!=2) {
    my ($prog_name) = ($0 =~ m/^.*\/(.*?)$/);

    print STDERR "Usage: $prog_name txtgz_filename gdbm_filename\n";
    exit -1;
}

my $cmd = "gzip --decompress --to-stdout \"$txtgz_filename\" | txt2db \"$gdbm_filename\"";

my $ret_status = system($cmd);

#print STDERR "***## system error message $!\n";
#print STDERR "***## ret status = $ret_status\n";

#return $ret_status;

