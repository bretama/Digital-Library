#!/usr/bin/perl -w

###########################################################################
#
# incremental-buildcol.pl -- runs buildcol.pl with -incremental on
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009 New Zealand Digital Library Project
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


# This program is designed to support incremental building of Greenstone
# Runs:        buildcol.pl -incremental -builddir GSDLHOME/collect/$collect/index ...


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}


use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

use util;
use colcfg;

sub main
{
    my ($argc,@argv) = @_;

    if (($argc==0)  || (($argc==1) && ($argv[0] =~ m/^--?h(elp)?$/))) {
	my ($progname) = ($0 =~ m/^.*[\/|\\](.*?)$/);


	print STDERR "\n";
	print STDERR "Usage: $progname [buildcol.pl options] collection\n";
	print STDERR "\n";

	exit(-1);
    }


    my $collection = pop @argv;

    my @filtered_argv = ();

    my $collect_dir = undef;
    my $build_dir  = undef;
    my $site = undef;

    while (my $arg = shift @argv) {
	if ($arg eq "-collectdir") {
	    $collect_dir = shift @argv;
	    push(@filtered_argv,$arg,$collect_dir);
	}
	elsif ($arg eq "-builddir") {
	    $build_dir = shift @argv;
	    push(@filtered_argv,$arg,$build_dir);
	}
	elsif ($arg eq "-site") {
	    $site = shift @argv;
	    push(@filtered_argv,$arg,$site);
	}
	else {
	    push(@filtered_argv,$arg);
	}
    }

    # get and check the collection name
    if ((&colcfg::use_collection($site, $collection, $collect_dir)) eq "") {
	print STDERR "Unable to use collection \"$collection\" within \"$collect_dir\"\n";
	exit -1;
    }

    if (!defined $build_dir) {
	# Yes this is intentional that 'build_dir' points to "index"
	$build_dir = &util::filename_cat ($ENV{'GSDLCOLLECTDIR'},"index");
	push(@filtered_argv,"-builddir",$build_dir);
    }

    my $quoted_argv = join(" ", map { "\"$_\"" } @filtered_argv);
    
    my $buildcol_cmd = "\"".&util::get_perl_exec()."\" -S buildcol.pl";

    # Read in the collection configuration file.
    my $gs_mode = "gs2";
    if ((defined $site) && ($site ne "")) { # GS3
	$gs_mode = "gs3";
    }
    my $collect_cfg_filename = &colcfg::get_collect_cfg_name(STDERR, $gs_mode);
	
    my $collectcfg = &colcfg::read_collection_cfg ($collect_cfg_filename,$gs_mode);

    # look for build.cfg/buildConfig.xml
    my $build_cfg_filename ="";

    if ($gs_mode eq "gs2") {
	$build_cfg_filename = &util::filename_cat($build_dir,"build.cfg");
    } else {
	$build_cfg_filename = &util::filename_cat($build_dir, "buildConfig.xml");
    }
    
    if (-e $build_cfg_filename) {

	# figure out if there has been a change of indexer 
	# (e.g. collect.cfg now says lucene, but build.cfg says mgpp)

	my $buildcfg = &colcfg::read_building_cfg ($build_cfg_filename, $gs_mode);
	if ($buildcfg->{'buildtype'} ne $collectcfg->{'buildtype'}) {
	    print STDERR "*****\n";
	    print STDERR "* Change of indexer detected. Switching to buildcol.pl with -removeold.\n";
	    print STDERR "*****\n";
	    $buildcol_cmd .= " -removeold";
	}
	else {

	    $buildcol_cmd .= " -incremental";
	}
    }
    else {
	# build.cfg doesn't exit
	print STDERR "*****\n";
	print STDERR "* First time built. Switching to buildcol.pl with -removeold.\n";
	print STDERR "*****\n";
	$buildcol_cmd .= " -removeold";
    }

    
    $buildcol_cmd .= " $quoted_argv \"$collection\"";
    
    my $buildcol_status = system($buildcol_cmd)/256;
    
    if ($buildcol_status != 0) {
	print STDERR "Error: Failed to run: $buildcol_cmd\n";
	print STDERR "       $!\n" if ($! ne "");
	exit(-1);
    }
}

&main(scalar(@ARGV),@ARGV);




