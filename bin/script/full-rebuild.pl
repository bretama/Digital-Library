#!/usr/bin/perl -w

###########################################################################
#
# full-rebuild.pl --
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


# This program will rebuild a collection from scratch
# Runs:        full-import.pl -removeold [args]
# Followed by: full-buildcol.pl -removeold [args]
# Followed by: activate.pl -removeold [args]
# (assumming import.pl/buildcol.pl did not end with an error)

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
	my ($progname) = ($0 =~ m/^.*\/(.*?)$/);

	print STDERR "\n";
	print STDERR "This program runs full-import.pl, full-buildcol.pl, activate.pl (in each case removing any previously generated files in 'archives', 'building','index')\n";
	print STDERR "\n";
	print STDERR "Usage: $progname [options]| collection\n";
	print STDERR "\n";
	print STDERR "       If a minus option is shared between import.pl and buildcol.pl then it can appear\n";
        print STDERR "         as is, such as -verbosity 5.  This value will be passed to both programs.\n";
	print STDERR "       If a minus option is specific to one of the programs in particular, then prefix\n";
	print STDERR "         it with 'import:', 'buildcol:', or 'activate:' respectively, \n";
	print STDERR "         as in '-import:OIDtype hash_on_full_filename'\n";
	print STDERR "       Run '(full-)import.pl -h', '(full-)buildcol.pl -h', 'activate.pl -h' from the \n";
	print STDERR "         command line to see the specific values they take.\n";
	print STDERR "\n";

	exit(-1);
    }

    my @import_argv = ();
    my @buildcol_argv = ();
    my @activate_argv = ();

    my $site        = undef;
    my $collect_dir = undef;
    my $build_dir   = undef;
    my $index_dir   = undef;
    my $verbosity   = 2; # same as the default in buildcol.pl

    while (my $arg = shift @argv) {
	if ($arg eq "-site") {
	    $site = shift @argv;
	    push(@import_argv,$arg,$site);
	    push(@buildcol_argv,$arg,$site);
	    push(@activate_argv,$arg,$site);
	}
	elsif ($arg eq "-collectdir") {
	    $collect_dir = shift @argv;
	    push(@import_argv,$arg,$collect_dir);
	    push(@buildcol_argv,$arg,$collect_dir);
	    push(@activate_argv,$arg,$collect_dir);
	}
	elsif ($arg eq "-importdir") {
	    # only makes sense in import.pl
	    my $import_dir = shift @argv;
	    push(@import_argv,$arg,$import_dir);
	}
	elsif ($arg eq "-builddir") {
	    # only makes sense in buildcol.pl and activate.pl
	    $build_dir = shift @argv;
	    push(@buildcol_argv,$arg,$build_dir);
	    push(@activate_argv,$arg,$build_dir);
	}
	elsif ($arg eq "-indexdir") {
	    # only makes sense in buildcol.pl and activate.pl
	    $index_dir = shift @argv;
	    push(@buildcol_argv,$arg,$index_dir);
	    push(@activate_argv,$arg,$index_dir);
	}
	elsif ($arg eq "-verbosity") {	    
	    $verbosity = shift @argv;
	    push(@import_argv,$arg,$verbosity);
	    push(@buildcol_argv,$arg,$verbosity);
	    push(@activate_argv,$arg,$verbosity);
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
	elsif ($arg =~ /-activate:(.*)$/) {	    
	    my $activate_arg = "-".$1;
	    my $activate_val = shift @argv;
	    push(@activate_argv,$activate_arg,$activate_val);
	}
	elsif ($arg =~ "-OIDtype") {
		shift @argv; # skip OIDtype (don't pass OIDtype to buildcol.pl. It's not currently accepted.)
			# this allows us to run full-rebuild.pl -OIDtype filename for instance
	}
	else {
	    push(@import_argv,$arg);
	    push(@buildcol_argv,$arg);
	    push(@activate_argv,$arg);
	}
    }
    
    my $quoted_import_argv = join(" ", map { "\"$_\"" } @import_argv);
    my $quoted_buildcol_argv = join(" ", map { "\"$_\"" } @buildcol_argv);
    my $quoted_activate_argv = join(" ", map { "\"$_\"" } @activate_argv);
    
    my $final_status = 0;

    # need to ensure that the path to perl is quoted (in case there's spaces in it)
    my $launch_cmd = "\"".&util::get_perl_exec()."\" -S ";    
    
    print "\n";
    print "************************\n";
    print "* Running  Import  Stage\n";
    print "************************\n";

    my $import_cmd = $launch_cmd . "full-import.pl $quoted_import_argv";

    my $import_status = system($import_cmd)/256;
    
    if ($import_status == 0) {
	print "\n";
	print "************************\n";
	print "* Running Buildcol Stage\n";
	print "************************\n";
	
	my $buildcol_cmd = $launch_cmd . "full-buildcol.pl $quoted_buildcol_argv";
	my $buildcol_status = system($buildcol_cmd)/256;

	if ($buildcol_status == 0) {

	    # run activate with -removeold, just like full-buildcol.pl called above runs buildcol.pl
	    my $activatecol_cmd = $launch_cmd . "activate.pl -removeold $quoted_activate_argv";
	    my $activatecol_status = system($activatecol_cmd)/256;
	}
	else {
	    $final_status = $buildcol_status;
	}
    }
    else {
	$final_status = $import_status;
    }
    
    exit($final_status);
}

&main(scalar(@ARGV),@ARGV);

