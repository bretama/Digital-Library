###########################################################################
#
# scriptutil.pm -- various useful utilities for the scripts
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

package scriptutil;

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments
no strict 'refs'; # ...but allow filehandles to be variables and vice versa

use gsprintf 'gsprintf';

# returns $removeold, $keepold
sub check_removeold_and_keepold {

    my ($removeold, $keepold, $incremental, $dir, $collectcfg) = @_;    

    if (($keepold && $removeold) || ($incremental && $removeold) ) {
	gsprintf(STDERR, "{scripts.both_old_options}\n", $dir);
	sleep(3); #just in case
	return (1,0,0,"none"); 
	
    } 

    # Incremental mode may be set to "none", "onlyadd" or "all"
    # depending on status of -keepold and -incremental flags
    my $incremental_mode = "none";
    if ($incremental) {
	$incremental_mode = "all";
    } elsif ($keepold) {
	$incremental_mode = "onlyadd";
    }

    if (!$keepold && !$removeold && !$incremental && defined $collectcfg) {
	# we only look at config file options if we dont have these on the command line
	if (defined $collectcfg->{'removeold'} && $collectcfg->{'removeold'} =~ /^true$/i ) {
	    $removeold = 1;
	} elsif (defined $collectcfg->{'keepold'} && $collectcfg->{'keepold'} =~ /^true$/i) {
	    $keepold = 1;
	    $incremental_mode = "onlyadd";
	} elsif (defined $collectcfg->{'incremental'} && $collectcfg->{'incremental'} =~ /^true$/i) {
	    $incremental = 1;
	    $incremental_mode = "all";
	}
    }

    if (!$keepold && !$removeold && !$incremental) {
	gsprintf(STDERR, "{scripts.no_old_options} \n", $dir);
	sleep(3); #just in case
	return (1,0,0,"none");
    }
    
    # incremental implies keepold
    if ($incremental) {
	$keepold = 1;
    }
    return ($removeold, $keepold, $incremental, $incremental_mode);

}

1;
