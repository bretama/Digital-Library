#!/usr/bin/perl -w

###########################################################################
#
# gsdlinfo.pl --
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

# This program will look to see what collections are installed
# under this file system

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use parsargv;
use colcfg;

if (scalar(@ARGV) && ($ARGV[0] eq "--help" || $ARGV[0] eq "-h")) {
    print STDERR "\n";
    print STDERR "gsdlinfo.pl: Prints information on any Greenstone collections\n";
    print STDERR "             found on the local file system.\n\n";
    exit;
}


# the collection information is stored as an array of hashes
# (one hash for each collection). The hash contains all the 
# information in the collect and build configuration files


# read in all the collection configuration information

opendir (DIR, "$ENV{'GSDLHOME'}/collect") ||
    die "ERROR - couldn't read the directory $ENV{'GSDLHOME'}/collect\n";
@dir = readdir (DIR);
closedir (DIR);

@collections = ();
foreach $dir (@dir) {
    if ($dir =~ /^(\..*|modelcol|CVS)$/) {
	# do nothing

    } else {
	# read in the collection configuration file
	my $collectcfg = {};
	if (-e "$ENV{'GSDLHOME'}/collect/$dir/etc/collect.cfg") {
	    $collectcfg = &colcfg::read_collect_cfg ("$ENV{'GSDLHOME'}/collect/$dir/etc/collect.cfg");
	}
	$collectcfg->{'collection'} = $dir;

	# read in the build configuration file
	my $buildcfg = {};
	if (-e "$ENV{'GSDLHOME'}/collect/$dir/index/build.cfg") {
	    $buildcfg = &colcfg::read_build_cfg ("$ENV{'GSDLHOME'}/collect/$dir/index/build.cfg");
	}

	# add the merged configuration files to the current list of collections
	push (@collections, {%$collectcfg, %$buildcfg});
    }
}


# do any sorting requested


# print out the collection information

# {'creator'}->string
# {'maintainer'}->array of strings
# {'public'}->string
# {'beta'}->string
# {'key'}->string
# {'indexes'}->array of strings
# {'defaultindex'}->string
# {'builddate'}->string
# {'metadata'}->array of strings
# {'languages'}->array of strings
# {'numdocs'}->string
# {'numwords'}->string
# {'numbytes'}->string

print "\n";
foreach $info (@collections) {
    if (defined $info->{'collection'}) {
	$collection = $info->{'collection'};
	if (defined $info->{'public'}) {
	    $public = $info->{'public'};
	} else {
	    $public = "?";
	}
	if (defined $info->{'beta'}) {
	    $beta = $info->{'beta'};
	} else {
	    $beta = "?";
	}
	if (defined $info->{'numdocs'}) {
	    $numdocs = $info->{'numdocs'};
	} else {
	    $numdocs = "?";
	}
	if (defined $info->{'numbytes'}) {
	    $numMbytes = int(($info->{'numbytes'}/1024.0/1024.0)*1000)/1000.0;
	} else {
	    $numMbytes = "?";
	}
	write;
    }
}
print "\n";

exit;

format STDOUT_TOP = 
  name   public  beta   documents  size (Mbytes)
-------- ------ ------ ----------- -------------
.

format STDOUT = 
@>>>>>>> @>>>>> @>>>>> @>>>>>>>>>> @>>>>>>>>>>>>
$collection, $public, $beta, $numdocs, $numMbytes
.
