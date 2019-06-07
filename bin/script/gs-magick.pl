#!/usr/bin/perl -w

###########################################################################
#
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


# gs-magick.pl:
# Script to set the environment for imagemagick and then run it, returning
# both the exit code and printing the output to STDOUT.
# Setting the env vars necessary for imagemagick here locally means 
# they won't interfere with the normal environment it would have 
# if the environment had been set in setup.bash/setup.bat instead


BEGIN {
    die "GSDLHOME not set - run the (gs3-)setup script\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set - run (gs3-)setup script\n" unless defined $ENV{'GSDLOS'};
    $ENV{'GSDLARCH'} = "" unless defined $ENV{'GSDLARCH'}; # GSDLARCH will be set only on some Linux systems
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}


use strict;
no strict 'refs'; # make an exception so we can use variables as filehandles
use util;


sub main
{
    my ($argc,@argv) = @_;

    my $usage = "Usage: $0 [--usage|--help|--verbosity <num>] <imagick-command> <arguments to imagick command>";

    my $verbosity = 0;
    my $magick_cmd = "";


    # Construct the imagemagick cmd string from all the arguments, 
    # embedding any arguments that contain spaces in quotes.
    # We'll remove the --options afterwards. 
    my $count = 0;
    for ($count = 0; $count < scalar(@argv); $count++) {
	if($argv[$count] =~ m/ /) { 
	    $argv[$count] = "\"".$argv[$count]."\"";
	}
	$magick_cmd = "$magick_cmd $argv[$count]"; 
    }

    # process the --options in the imagemagick command
    # Tried using the official GetOptions module to parse options, except that
    # the --verbosity|--v option to gs-magick.pl interfered with the -verbose 
    # option that image-magick accepts.

    if($magick_cmd =~ m/--usage|--help/) {
	print STDERR "$usage\n";
	exit(0);
    }

    $magick_cmd =~ s/\s*--verbosity(\s+|=)(\d*)\s*/ /; # --verbosity=4 or --verbosity   4
    $verbosity = $2 if defined $2; # print STDERR "subst 2 is : $2\n" if defined $2; 

    if(!defined $magick_cmd || $magick_cmd eq "" || $magick_cmd =~ m/^\s*$/) {
	print STDERR "No command provided for imagemagick.\n$usage\n";
	exit(0);
    }

    if($verbosity > 2) {
	print STDERR "***** Running MAGICK_CMD: $magick_cmd\n";
	#print STDERR "***** verbosity: $verbosity\n";
    }

    ## SET THE ENVIRONMENT AS USED TO BE DONE IN SETUP.BASH/BAT
    
    my $magick_home = &util::filename_cat($ENV{'GSDLHOME'},"bin",$ENV{'GSDLOS'}.$ENV{'GSDLARCH'},"imagemagick");
    if (-d $magick_home) { # "$GSDLHOME/bin/$GSDLOS$GSDLARCH/imagemagick"
	$ENV{'MAGICK_HOME'} = $magick_home;
    }
    
    # if Greenstone came with imagick, or if the user otherwise has an 
    # imagick to fall back on (and set MAGICK_HOME that way) we use that
    if(defined $ENV{'MAGICK_HOME'} && -d $ENV{'MAGICK_HOME'}) {
	if($ENV{'GSDLOS'} =~ m/windows/) {
	    &util::envvar_prepend("PATH", $ENV{'MAGICK_HOME'}); # the imagemagick folder (no bin therein)
	}
 
	else { # linux and mac
	    &util::envvar_prepend("PATH", &util::filename_cat($ENV{'MAGICK_HOME'}, "bin"));
	
	    my $magick_lib = &util::filename_cat($ENV{'MAGICK_HOME'}, "lib");
	    if($ENV{'GSDLOS'} eq "linux") {
		&util::envvar_prepend("LD_LIBRARY_PATH", $magick_lib);
	    } elsif ($ENV{'GSDLOS'} eq "darwin") {
		&util::envvar_prepend("DYLD_LIBRARY_PATH", $magick_lib);
	    }
	}

	if($verbosity > 2) {
	    print STDERR "\t*** MAGICK_HOME: ".$ENV{'MAGICK_HOME'}."\n";
	    print STDERR "\t*** LD_LIB_PATH: ".$ENV{'LD_LIBRARY_PATH'}."\n" if defined $ENV{'LD_LIBRARY_PATH'};
	    print STDERR "\t*** DYLD_LIB_PATH: ".$ENV{'DYLD_LIBRARY_PATH'}."\n" if defined $ENV{'DYLD_LIBRARY_PATH'};
	    print STDERR "\t*** PATH: ".$ENV{'PATH'}."\n\n";
	}
    }

    # if no MAGICK_HOME, maybe they want to run with the system imagemagick
    elsif($verbosity > 2) {
	print STDERR "**** No ImageMagick in Greenstone. Will try to use any imagemagick on the system.\n\n";
    }

    # RUN THE IMAGEMAGICK COMMAND
    
    # John Thompson's manner of using backticks to preserve the output of
    # running imagemagick. 
    # $? contains the exit code of running the imagemagick command. 
    # This needs to be shifted by 8 and then converted to be a signed value
    # to work out the actual exit code value.

    #my $result = `$magick_cmd`; # This way will trap STDOUT into local variable

    my $result = "";
    if (!open(PIN, "$magick_cmd |")) {
	print STDERR "*** Can't run $magick_cmd. Error was: $!.\n\n";
    } else {
	while (defined (my $imagick_output_line = <PIN>)) {
	    $result = $result.$imagick_output_line;
	}
	close(PIN);
    }
   
    # Perl Special Variables http://www.kichwa.com/quik_ref/spec_variables.html
    # $? The status returned by the last pipe close, backtick(``) command or system operator. 
    # Note that this is the status word returned by the wait() system call, so the exit value 
    # of the subprocess is actually ($? >>*). $? & 255 gives which signal, if any, the process
    # died from, and whether there was a core dump. 

    # Shift by 8 to get a value between 0 and 255, then work out if it is signed or unsigned
    # http://stackoverflow.com/questions/2726447/why-is-the-exit-code-255-instead-of-1-in-perl    
    my $status = $?;
    $status >>= 8;
    $status = (($status & 0x80) ? -(0x100 - ($status & 0xFF)) : $status);

    # send the output to STDOUT, since calling functions may call gs-magick.pl with backticks
    print STDOUT $result;
    exit($status);
}

&main(scalar(@ARGV),@ARGV);
