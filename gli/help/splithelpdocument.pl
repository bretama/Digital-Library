#!/usr/bin/perl -w

###########################################################################
#
# splithelpdocument.pl
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


sub main
{
    local @lines = <STDIN>;

    local $filestart = 0;
    local $filename = "";
    for ($i = 0; $i < scalar(@lines); $i++) {
	local $line = $lines[$i];

	if ($line =~ /\<a name=\"([^\"]+)\"\>/ && $filename eq "") {
	    $filename = $1;
	}

	if ($line =~ /^\<html\>/ && $i > $filestart) {
	    open(FILE_OUT, ">$filename.htm") or die "Error: Could not write $filename.htm.\n";
	    for ($j = $filestart; $j < $i; $j++) {
		print FILE_OUT $lines[$j];
	    }
	    close(FILE_OUT);

	    $filestart = $i;
	    $filename = "";
	}
    }

    # Deal with the last file
    if ($filename ne "") {
	open(FILE_OUT, ">$filename.htm") or die "Error: Could not write $filename.htm.\n";
	for ($j = $filestart; $j < $i; $j++) {
	    print FILE_OUT $lines[$j];
	}
	close(FILE_OUT);
    }
}


&main(@ARGV);
