###########################################################################
#
# cnseg.pm --
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


# this package segments a chinese UTF-8 encoded Unicode
# string into words.

package cnseg;

use strict;
use unicode;


# 'segment' takes a UTF-8 encoded Unicode Chinese-language
# string and places U-200B between words -- the ZERO
# WIDTH SPACE. Each line is treated as a separate 
# paragraph, so lines in one paragraph should
# be joined before using this method (normally a single
# word might span more than one line within a paragraph).
#
# 'segment' is currently written in Perl, however, I (Rodger)
# plan to use C++ (via pipes) once a more complex (and useful!)
# algorithm is being used. Currently, each Chinese character
# is treated as a seperate word.

sub segment {
    my ($in) = @_;
    my ($c);
    my ($cl);
    my $len = length($in);
    my $i = 0;
    my $out = "";
    my $space = 1; # start doesn't need a space
    while ($i < $len) {
	$c = substr ($in, $i, 1);
	$cl = ord($c);
	if (($cl >= 0x2e80 && $cl <= 0xd7a3) ||
	    ( $cl >= 0xf900 && $cl <= 0xfa6a)) { # main east asian codes
	    # currently c++ receptionist code can't handle these large numbers
	    # search terms need to be segmented the same way. Add these back
	    # in when fix up c++
	    # ($cl >= 0x20000 && $cl <= 0x2a6d6) || # cjk unified ideographs ext B
	    # ($cl >= 0x2f800 && $cl <= 0x2fa1d)) { #cjk compatibility ideographs supplement
	    # CJK character
	    $out .= chr(0x200b) unless $space;
	    $out .= $c;
	    $out .= chr(0x200b);
	    $space = 1;
	} else {
	    $out .=$c;
	    $space = 0;
	}
	$i++;
    }
    return $out;
}
    
sub segment_old {
    my ($in) = @_;
    my ($c);
    my $uniin = &unicode::utf82unicode($in);
    my $out = [];

    my $space = 1; # start doesn't need a space
    foreach $c (@$uniin) {
	if (($c >= 0x2e80 && $c <= 0xd7a3) ||
	    ( $c >= 0xf900 && $c <= 0xfa6a)) { # main east asian codes
	    # currently c++ receptionist code can't handle these large numbers
	    # search terms need to be segmented the same way. Add these back
	    # in when fix up c++
	   # ($c >= 0x20000 && $c <= 0x2a6d6) || # cjk unified ideographs ext B
	   # ($c >= 0x2f800 && $c <= 0x2fa1d)) { #cjk compatibility ideographs supplement
	    # CJK character
	    push (@$out, 0x200b) unless $space;
	    push (@$out, $c);
	    push (@$out, 0x200b);
	    $space = 1;

	} else {
	    # non-Chinese character
	    push (@$out, $c);
	    $space = 0;
	}
    }

    return &unicode::unicode2utf8($out);
}

1;
