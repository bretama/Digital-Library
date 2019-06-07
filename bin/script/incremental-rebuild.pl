#!/usr/bin/perl -w

###########################################################################
#
# incremental-rebuild.pl --
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


# This program will incrementally rebuild a collection 
# Runs:        incremental-import.pl -incremental ...
# Followed by: incremental-buildcol.pl -activate -incremental -builddir index ...
# (assumming import.pl did not end with an error)


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
use util;

sub main
{
    my ($argc,@argv) = @_;

    if (($argc==0)  || (($argc==1) && ($argv[0] =~ m/^--?h(elp)?$/))) {
	my ($progname) = ($0 =~ m/^.*[\/|\\](.*?)$/);

	print STDERR "\n";
	print STDERR "This program runs -- incrementally where possible -- import.pl followed by buildcol.pl (retaining any\n";
	print STDERR "  previously generated files in 'archives' or 'index').  The import.pl script can always be run\n";
        print STDERR "  incrementally in Greenstone, however buildcol.pl will default to a full rebuild if the indexer\n";
        print STDERR "  the collection uses (such as mg, or mgpp) does not support incremental indexing.\n";
	print STDERR "\n";
	print STDERR "Usage: $progname [options]| collection\n";
	print STDERR "       If a minus option is shared between import.pl and buildcol.pl then it can appear\n";
        print STDERR "         as is, such as -verbosity 5.  This value will be passed to both programs.\n";
	print STDERR "       If a minus option is specific to one of the programs in particular, then prefix\n";
	print STDERR "         it with 'import:' or 'buildcol:' respectively, as in '-import:OIDtype hash_on_full_filename'\n";
	print STDERR "       Run 'import.pl' or 'buildcol.pl' from the command line with no arguments to see the\n";
        print STDERR "         specific values they take.\n";
	print STDERR "\n";

	exit(-1);
    }
	

    my $collect = pop @argv;

    my @import_argv = ();
    my @buildcol_argv = ();

    while (my $arg = shift @argv) {

	if ($arg eq "-manifest") {
	    # only makes sense in import.pl
	    my $manifest = shift(@argv);
	    push(@import_argv,$arg,$manifest);
	}
	elsif ($arg eq "-importdir") {
	    # only makes sense in import.pl
	    my $import_dir = shift @argv;
	    push(@import_argv,$arg,$import_dir);
	}
	elsif ($arg eq "-builddir") {
	    # only makes sense in build.pl
	    my $build_dir = shift @argv;
	    push(@buildcol_argv,$arg,$build_dir);
	}
	elsif ($arg eq "-indexdir") {
	    # only makes sense in build.pl
	    my $index_dir = shift @argv;
	    push(@buildcol_argv,$arg,$index_dir);
	}
	elsif ($arg =~ /-import:(.*)$/) {	    
	    my $import_arg = "-".$1;
	    my $import_val = shift @argv;
	    push(@import_argv,$import_arg,$import_val);
	}
	elsif ($arg =~ /-buildcol:(.*)$/) {	    
	    my $buildcol_arg = "-".$1;
	    my $buildcol_val = shift @argv;
	    push(@buildcol_argv,$buildcol_arg,$buildcol_val);
	}
	elsif ($arg =~ "-OIDtype") {
		shift @argv; # skip OIDtype (don't pass OIDtype to buildcol.pl. It's not currently accepted.)
			# this allows us to run full-rebuild.pl -OIDtype filename for instance
	}
	else {
	    push(@import_argv,$arg);
	    push(@buildcol_argv,$arg);
	}

    }

    my $quoted_import_argv = join(" ", map { "\"$_\"" } @import_argv);
    my $quoted_buildcol_argv = join(" ", map { "\"$_\"" } @buildcol_argv);
    
    my $final_status = 0;
    
	# need to ensure that the path to perl is quoted (in case there's spaces in it)
    my $launch_cmd = "\"".&util::get_perl_exec()."\" -S ";    

    print STDERR "\n";
    print STDERR "************************\n";
    print STDERR "* Running  Import  Stage\n";
    print STDERR "************************\n";
    
    my $import_cmd = $launch_cmd . "incremental-import.pl $quoted_import_argv \"$collect\"";

    my $import_status = system($import_cmd)/256;
    
    if ($import_status == 0) {
	print STDERR "\n";
	print STDERR "************************\n";
	print STDERR "* Running Buildcol Stage\n";
	print STDERR "************************\n";

	# run incremental buildcol with activate flag
	my $buildcol_cmd = $launch_cmd . "incremental-buildcol.pl -activate $quoted_buildcol_argv \"$collect\"";
	my $buildcol_status = system($buildcol_cmd)/256;
	if ($buildcol_status != 0) {
	    $final_status = $buildcol_status;
	}
    }
    else {
	$final_status = $import_status;
    }
    
    exit($final_status);
}

&main(scalar(@ARGV),@ARGV);

