#!/usr/bin/perl -w

###########################################################################
#
# update.pl
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


# This program updates any collections that are based on mirrors of
# web sites after a certain interval.  It first checks that the
# collection is a mirrored collection and whether it is time to 
# update the collection.  If so, it updates the mirror with 
# mirror.pl; then imports the collection with import.pl; then 
# builds the collection with buildcol.pl; then replaces the 
# existing index directory with the new building directory.
# The etc/mirror.log file stores the STDOUT output.


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
    print STDERR "update.pl: Updates a collection if it has been set up to mirror\n";
    print STDERR "           a website. Calls mirror.pl to do the mirroring.\n\n";
    print STDERR "  usage: $0 [options] collection-name\n\n";
    print STDERR "  options:\n";
    print STDERR "   -verbosity number      0=none, 3=lots\n";
    print STDERR "   -importdir directory   Where to place the mirrored material\n";
    print STDERR "   -archivedir directory  Where the converted material ends up\n";
}


&main ();

sub main {
    my ($verbosity, $importdir, $archivedir, $builddir, $indexdir, $etcdir, 
	$mirror, $interval, $logfile,
        $collection, $configfilename, $collectcfg);

    if (!parsargv::parse(\@ARGV, 
			 'verbosity/\d+/2', \$verbosity,
			 'importdir/.*/', \$importdir,
			 'archivedir/.*/', \$archivedir )) {
	&print_usage();
	die "\n";
    }

    # get and check the collection name
    if (($collection = &util::use_collection(@ARGV)) eq "") {
	&print_usage();
	die "\n";
    }

    # check the configuration file for options
    $configfilename = &util::filename_cat ($ENV{'GSDLCOLLECTDIR'}, "etc/collect.cfg");
    if (-e $configfilename) {
	$collectcfg = &colcfg::read_collect_cfg ($configfilename);
	if (defined $collectcfg->{'importdir'} && $importdir eq "") {
	    $importdir = $collectcfg->{'importdir'};
	}
	if (defined $collectcfg->{'archivedir'} && $archivedir eq "") {
	    $archivedir = $collectcfg->{'archivedir'};
	}
	if (defined $collectcfg->{'mirror'}) {
	    $mirror = $collectcfg->{'mirror'};
	}
    } else {
	die "Couldn't find the configuration file $configfilename\n";
    }
    
    # fill in the default import and archives directories if none
    # were supplied, turn all \ into / and remove trailing /
    $importdir = "$ENV{'GSDLCOLLECTDIR'}/import" if $importdir eq "";
    $importdir =~ s/[\\\/]+/\//g;
    $importdir =~ s/\/$//;
    $archivedir = "$ENV{'GSDLCOLLECTDIR'}/archives" if $archivedir eq "";
    $archivedir =~ s/[\\\/]+/\//g;
    $archivedir =~ s/\/$//;

    $indexdir = "$ENV{'GSDLCOLLECTDIR'}/index";
    $builddir = "$ENV{'GSDLCOLLECTDIR'}/building";
    $etcdir = "$ENV{'GSDLCOLLECTDIR'}/etc";
    $logfile = "$etcdir/mirror.log";

    # if there is no mirror information, we're all done
    if (!defined($mirror)) {
	print "No mirror command in $configfilename\n";
	exit;
    }

    # read the mirror interval
    if (($#$mirror == 1) && ($$mirror[0] =~ /interval/)){
	$interval = $$mirror[1];
    } else {
	die "Malformed mirror information: use \"mirror interval N\"\n" .
	    "where N is the number of days between mirrors.\n";
    }

    # make sure there is an import directory
    if (! -e "$importdir") {
	&util::mk_dir($importdir);
    }

    print "archives directory: $archivedir\n";
    print "  import directory: $importdir\n";
    print "     etc directory: $etcdir\n";
    print "          interval: $interval days\n";

    # how many days is it since the last mirror
    my $seconds = 0;
    if (-e "$logfile") {
	my $now = time;
	my @stats = stat("$logfile");
	my $then = $stats[9];
	# calculate the number of days since the last mirror
	$seconds = $now - $then;
    }
    my $days = (($seconds / 3600) / 24);

    # Is it too soon to start mirroring?
    if (($seconds > 0) && ($interval > $days)) {
	printf "Mirror not started: only %.1f days have passed\n", $days;
	exit;
    }
    
    # Mirror the remote site
    open(WLOG, ">$logfile");
    print WLOG "Starting mirror at " . time . "\n\n";
    
    my $command = "mirror.pl $collection";
    print WLOG "Executing: $command\n";
    print WLOG `$command`;
    
    # Import the collection
    print WLOG "\n\nStarting import at " . time . "\n\n";
    $command = "import.pl -removeold $collection";
    print WLOG "Executing: $command\n";
    print WLOG `$command`;

    # Build the collection
    print WLOG "\n\nStarting buildcol.pl at " . time . "\n\n";
    $command = "buildcol.pl $collection";
    print WLOG "Executing: $command\n";
    print WLOG `$command`;

    # Renaming the building directory to index
    print WLOG "\n\nRenaming building directory at " . time . "\n\n";
    if (-e $indexdir) {
	&util::mv($indexdir, "$indexdir.old");
	&util::mv($builddir, $indexdir);
	&util::rm_r ("$indexdir.old");
    } else {
	&util::mv($builddir, $indexdir);
    }


    close WLOG;
    
}





