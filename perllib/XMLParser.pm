###########################################################################
#
# XMLParser.pm -- Wrapper that ensures the right version of XML::Parser
#                 is loaded given the version of Perl being used.  Need
#                 to distinguish between Perl 5.6 and Perl 5.8
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005-2010 New Zealand Digital Library Project
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

use strict;
use Config;

sub BEGIN {
    my $perl_dir;

    # Note: $] encodes the version number of perl
    if ($]>=5.010) { 
        $perl_dir="perl-5.".substr($],3,2);
    }
    elsif ($]>=5.008) { 
	# perl 5.8.1 or above
	$perl_dir = "perl-5.8";
    }
#    elsif ($]>=5.008) { 
#	# perl 5.8.1 or above
#	$perl_dir = "perl-5.8";
#    }
#    elsif ($]<5.008) {
    else {
	# assume perl 5.6
	$perl_dir = "perl-5.6";
    }
#    else {
#	print STDERR "Warning: Perl 5.8.0 is not a maintained release.\n";
#	print STDERR "         Please upgrade to a newer version of Perl.\n";
#	$perl_dir = "perl-5.8";
#    }


    my $opt_bin_dir = "";
    if (-e "$ENV{'GSDLHOME'}/perllib/cpan/XML-Parser") {
	# Where the files end up with the Greenstone3 release-kit/installer

	$opt_bin_dir = "/XML-Parser";
    }

    # Use push to put this on the end, so an existing XML::Parser will be 
    # used by default

    if (-d "$ENV{'GSDLHOME'}/perllib/cpan$opt_bin_dir/$perl_dir-mt" && $Config{usethreads}){
	push (@INC, "$ENV{'GSDLHOME'}/perllib/cpan$opt_bin_dir/$perl_dir-mt");
    }
    else{
	push (@INC, "$ENV{'GSDLHOME'}/perllib/cpan$opt_bin_dir/$perl_dir");
    }
}

use XML::Parser;

1;
