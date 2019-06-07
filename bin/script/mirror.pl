#!/usr/bin/perl -w

###########################################################################
#
# mirror.pl
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


# This program uses w3mirror to mirror a web site.  It looks for a
# mirror program configuration files in etc, and if it finds them then
# it runs the mirroring software using this configuration file, and placing
# the mirror in the import directory.
#
# mirror.pl can use the w3mirror program or the wget program if they are
# installed.
#
# To use w3mirror, the configuration file must be in etc/w3mir.cfg.
# To use GNU wget, the configuration file (i.e. a wgetrc file) must
# be in etc/wget.cfg and a file of the URLs to read in etc/wget.url

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/classify");
}

use arcinfo;
use colcfg;
use util;
use parsargv;

sub print_usage {
    print STDERR "\n";
    print STDERR "mirror.pl: Uses w3mir or wget to sync a collections import data\n";
    print STDERR "           with a website.\n\n";
    print STDERR "  usage: $0 [options] collection-name\n\n";
    print STDERR "  options:\n";
    print STDERR "   -verbosity number      0=none, 3=lots\n";
    print STDERR "   -importdir directory   Where to place the mirrored material\n";
}


&main ();

sub main {
    my ($verbosity, $importdir, $etcdir, 
        $collection, $configfilename, $collectcfg);

    if (!parsargv::parse(\@ARGV, 
			 'verbosity/\d+/2', \$verbosity,
			 'importdir/.*/', \$importdir )) {
	&print_usage();
	die "\n";
    }

    # get and check the collection name
    if (($collection = &util::use_collection(@ARGV)) eq "") {
	&print_usage();
	die "\n";
    }

    # get the etc directory
    $etcdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "etc");
    
    # check the collection configuration file for options
    my $interval = 0;
    $configfilename = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 
					   "etc", "collect.cfg");
    if (-e $configfilename) {
	$collectcfg = &colcfg::read_collect_cfg ($configfilename);
	if (defined $collectcfg->{'importdir'} && $importdir eq "") {
	    $importdir = $collectcfg->{'importdir'};
	}
    } else {
	die "Couldn't find the configuration file $configfilename\n";
    }
    
    # fill in the default import directories if none
    # were supplied, turn all \ into / and remove trailing /
    $importdir = "$ENV{'GSDLCOLLECTDIR'}/import" if $importdir eq "";
    $importdir =~ s/[\\\/]+/\//g;
    $importdir =~ s/\/$//;

    # make sure there is an import directory
    if (! -e "$importdir") {
	&FileUtils::makeDirectory($importdir);
    }

    # if w3mir.cfg exists, 
    # then we are using w3mirror to mirror the remote site
    if (-e "$etcdir/w3mir.cfg") {

	# run the mirror program from the import directory
	my  $cmd = "cd $importdir; ";
	# need to ensure that the path to perl is quoted (in case there's spaces in it)
	$cmd .= "\"".&util::get_perl_exec()."\" -S gsw3mir.pl -cfgfile $etcdir/w3mir.cfg";
	# print "\n$cmd\n";
	`$cmd`;

    } 

    # if wget.cfg and wget.url both exist, 
    # then we are using GNU wget to mirror the remote site
    elsif ((-e "$etcdir/wget.cfg") && (-e "$etcdir/wget.url")) {
	$ENV{WGETRC} = "$etcdir/wget.cfg";
	my $cmd = "\"".&util::get_perl_exec()."\" -S gsWget.pl --input-file=$etcdir/wget.url --directory-prefix=$importdir";
	system($cmd);
    }

    # otherwise, there are no mirror copnfiguration files
    else {
	die "Couldn't find the mirror configuration files in $etcdir\n";
    }


}






