#!/usr/bin/perl -w

###########################################################################
#
# jdb2txt.pl -- convenience script to access JDBM datbases produced by Greenstone
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2012 New Zealand Digital Library Project
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


# Wrapper script that gives similar command-line functionality to the 
# db2txt and txt2db scripts available for GDBM databases

# This script complements jdb2txt.pl by performing the reverse

# Save you having to type in the mouthful:
#  (cat file.txt |) java -cp $GSDLHOME/lib/java/jdbm.jar:$GSDLHOME/bin/java/JDBMWrapper.jar Txt2Jdb jdbm-file.jdb
#
# for Unix, or
#
#  (type file.txt |) java -cp %GSDLHOME%\lib\java\jdbm.jar;$GSDLHOME\bin\java/\DBMWrapper.jar Txt2Jdb jdbm-file.jdb
#
# for Windows.



BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
use util;

use File::Basename;

if (scalar(@ARGV) != 1) {
    my ($progname,$dir) = &File::Basename::fileparse($0);

    print STDERR "Usage: $progname infile.txt outfile.jdb\n";
    exit -1;
}

my $jdbm_jar = &util::filename_cat($ENV{'GSDLHOME'},"lib","java","jdbm.jar");
my $jdbmwrapper_jar = &util::filename_cat($ENV{'GSDLHOME'},"bin","java","JDBMWrapper.jar");


my $classpath = &util::pathname_cat($jdbmwrapper_jar,$jdbm_jar);

if ($^O eq "cygwin") {
    # Away to run a java program, using a binary that is native to Windows, so need
    # Windows directory and path separators
    
    $classpath = `cygpath -wp "$classpath"`;
    chomp($classpath);
    $classpath =~ s%\\%\\\\%g;    
}

my $cmd = "java -cp \"$classpath\" Txt2Jdb ".$ARGV[0];

if (system($cmd)!=0) {
    print STDERR "Error: Failed to run cmd\n  $cmd\n";
    print STDERR "  $!\n";
    exit -1;
}


