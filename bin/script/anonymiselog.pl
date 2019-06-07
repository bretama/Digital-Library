#!/usr/bin/perl -w

###########################################################################
#
# anonymiselog.pl -- anonymise a log file by MD5 hashing all IP addresses
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


use MD5;


sub main
{
    # Get the name of the log file to process
    local $logfilename = shift(@_);

    # Check that the necessary arguments were supplied
    if (!$logfilename) {
	print STDERR "Usage: anonymiselog.pl <logfile-name>\n";
	die "Error: Required argument missing.\n";
    }

    # Open the log file
    open(LOG_FILE, "<$logfilename") or die "Error: Could not open log file $logfilename.\n";

    # Open the output file
    local $outfilename = $logfilename . ".anon";
    open(OUT_FILE, ">$outfilename") or die "Error: Could not write file $outfilename.\n"; 

    # Create a new MD5 (RSA Data Security Inc. MD5 Message Digest) object
    local $md5 = new MD5;

    # Process the log, one line at a time
    local $entry = "";
    while (<LOG_FILE>) {
	local $line = $_;
	# print "Line: $line";

	# If this line starts a new entry, process the previous one
	if ($line =~ /^\//) {
	    print OUT_FILE &anonymise_log_entry($entry);
	    $entry = "";
	}

	# Remove trailing whitespace, and skip blank lines
	$line =~ s/(\s*)$//;
	next if ($line =~ /^$/);

	$entry = $entry . $line;
    }

    # Process the last entry
    print OUT_FILE &anonymise_log_entry($entry);

    # All done
    close(LOG_FILE);
    close(OUT_FILE);
}


sub anonymise_log_entry
{
    local $entry = shift(@_);
    return "" if ($entry eq "");

    # Parse the IP address from the entry
    $entry =~ /^\S+\s((\w|-|\.)+)\s\[/;
    if (!defined($1)) {
	print STDERR "Could not extract IP address from entry: $entry\n";
	return "";
    }

    # Casefold the IP address, hash using MD5, and take the last 16 characters
    local $ipaddress = $1;
    $ipaddress =~ tr/A-Z/a-z/;
    local $hashedaddress = substr($md5->hexhash($ipaddress), -16);

    # Replace the IP address with the hashed value
    $entry =~ s/$ipaddress/$hashedaddress/ig;

    # Parse the Greenstone user identifier (z variable) from the entry
    $entry =~ /\sz=((\w|-|\.)+)/;
    if (!defined($1)) {
	print STDERR "No z variable in entry: $entry\n";
	return "";
    }

    # Casefold the Greenstone user ID, hash using MD5, and take the last 16 characters
    local $gsuserid = $1;
    $gsuserid =~ tr/A-Z/a-z/;
    local $hasheduserid = substr($md5->hexhash($gsuserid), -16);

    # Replace the Greenstone user ID with the hashed value
    $entry =~ s/$gsuserid/$hasheduserid/ig;
    return $entry . "\n";
}


&main(@ARGV);
