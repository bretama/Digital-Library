#!/usr/bin/perl -w

###########################################################################
#
# ping.pl --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
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
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/Ping");
}


require LWP::UserAgent;
use parsargv;

&main();

sub print_usage {
    print STDERR "\n";
    print STDERR "ping.pl: Ping http or ftp URL to see if it's accessable.\n\n";
    print STDERR "  usage: $0 [options] URL\n\n";
    print STDERR "  options:\n";
    print STDERR "   -quiet   Quiet operation\n\n";
}

sub main {

    my ($quiet);
    if (!parsargv::parse(\@ARGV, 'quiet', \$quiet)) {
	&print_usage();
	die "\n";
    }

    if (!scalar(@ARGV)) {
	print STDERR "ERROR: no URL was provided\n";
	die "\n";
    }

    $ua = new LWP::UserAgent;
    $ua->timeout(60);
    $request = new HTTP::Request('HEAD', $ARGV[0]);
    $response = $ua->request($request);
    
    if ($response->is_success) {
	print STDERR "$ARGV[0] ping succeeded\n" unless $quiet;
	exit 0;
    } else {
	print STDERR "$ARGV[0] ping failed\n" unless $quiet;
	exit 1;
    }
}
