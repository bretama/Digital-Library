###########################################################################
#
# gflock.pm - an attempt to use flock only on those platforms
# on which it's supported (i.e. everything but Windows 95/98)
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

package gflock;

use Fcntl ':flock';
use strict;

# returns true if successful (or if OS is a form of windows other than NT)
sub lock {
    my ($handle) = @_;

    if ($ENV{'GSDLOS'} eq "windows" && !Win32::IsWinNT()) {
	return 1;
    } else {
	return flock($handle, LOCK_EX);
    }
}

# returns true if successful (or if OS is a form of windows other than NT)
sub unlock {
    my ($handle) = @_;

    if ($ENV{'GSDLOS'} eq "windows" && !Win32::IsWinNT()) {
	return 1;
    } else {
	return flock($handle, LOCK_UN);
    }
}

1;
