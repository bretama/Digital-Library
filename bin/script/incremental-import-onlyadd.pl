#!/usr/bin/perl -w

###########################################################################
#
# full-import.pl -- runs import.pl with -incremental option on
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
# Runs:        import.pl -incremental ...


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
use dbutil;
use util;
use colcfg;

sub main
{
    my ($argc,@argv) = @_;

    if (($argc==0)  || (($argc==1) && ($argv[0] =~ m/^--?h(elp)?$/))) {
	my ($progname) = ($0 =~ m/^.*[\/|\\](.*?)$/);


	print STDERR "\n";
	print STDERR "Usage: $progname [import.pl options] collection\n";
	print STDERR "\n";

	exit(-1);
    }

    my $collection = pop @argv;

    my @filtered_argv = ();

    my $collect_dir = undef;
    my $archive_dir  = undef;
    my $site = undef;

    while (my $arg = shift @argv) {
	# No actual filtering happens at the moment (@filterd_argv == @argv)
	# Useful to do it this way if we want incremental-import.pl
	# to start accepting its own arguments that are different to import.pl
	
	if ($arg eq "-collectdir") {
	    $collect_dir = shift @argv;
	    push(@filtered_argv,$arg,$collect_dir);
	}
	elsif ($arg eq "-archivedir") {
	    $archive_dir = shift @argv;
	    push(@filtered_argv,$arg,$archive_dir);
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

    if (!defined $archive_dir) {
	$archive_dir = &util::filename_cat ($ENV{'GSDLCOLLECTDIR'}, "archives")
    }

    # BACKWARDS COMPATIBILITY: Just in case there are old .ldb/.bdb files (won't do anything for other infodbtypes)
    &util::rename_ldb_or_bdb_file(&util::filename_cat($archive_dir, "archiveinf-doc"));
    
    my $archiveinf_doc = &dbutil::get_infodb_file_path("gdbm", "archiveinf-doc", $archive_dir);

    my $quoted_argv = join(" ", map { "\"$_\"" } @filtered_argv);
    
	# need to ensure that the path to perl is quoted (in case there's spaces in it)
    my $import_cmd = "\"".&util::get_perl_exec()."\" -S import.pl";

    if (-e $archiveinf_doc) {
	$import_cmd .= " -keepold";	
    }
    else {
	print STDERR "*****\n";
	print STDERR "First time import. Switching to full import.pl.\n";
	print STDERR "*****\n";
	$import_cmd .= " -removeold";
    }

    $import_cmd .= " $quoted_argv \"$collection\"";
    
    my $import_status = system($import_cmd)/256;
    
    if ($import_status != 0) {
	print STDERR "Error: Failed to run: $import_cmd\n";
	print STDERR "       $!\n" if ($! ne "");
	exit(-1);
    }
}

&main(scalar(@ARGV),@ARGV);
