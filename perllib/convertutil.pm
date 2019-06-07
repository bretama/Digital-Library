###########################################################################
#
# convertutil.pm -- utility to help convert files using external applications
#
# Copyright (C) 1999 DigiLib Systems Limited, NZ
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


package convertutil;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


use File::Basename;


sub monitor_init
{
    # do nothing
    return {};
}

sub monitor_deinit
{
    my ($saved_rec) = @_;
    
    # nothing to do
}

sub monitor_init_unbuffered
{
    my $saved_buffer_len = $|;
    $| = 1;

    my $saved_rec = { 'saved_buffer_len' => $saved_buffer_len };

    return $saved_rec;
}

sub monitor_deinit_unbuffered
{
    my ($saved_rec) = @_;

    my $saved_buffer_len = $saved_rec->{'saved_buffer_len'};

    $| = $saved_buffer_len;
}

sub monitor_line
{
    my ($line) = @_;

    my $had_error = 0;
    my $generate_dot = 0;

    return ($had_error,$generate_dot);
}

sub monitor_line_with_dot
{
    my ($line) = @_;

    my $had_error = 0;
    my $generate_dot = 1;

    return ($had_error,$generate_dot);
}


sub run_general_cmd
{
    my ($command,$options) = @_;


    # $options points to a hashtable that must have fields for:
    #  'verbosity', 'outhandle', 'message_prefix' and 'message'
    #
    # it can also include functions for monitoring
    #  'monitor_init'   => takes no input arguments and returns a hashtable for saved data values
    #  'monitor_line'   => takes $line as input argument, return tuple (had_error,generate_dot)
    #  'monitor_deinit' => takes the saved data values as input, restores saved values
    #
    # Default are provided for these monitor functions if none specified


    my $verbosity = $options->{'verbosity'};
    my $outhandle = $options->{'outhandle'};

    my $message_prefix = $options->{'message_prefix'};
    my $message = $options->{'message'};
	
    my $monitor_init   = $options->{'monitor_init'};
    my $monitor_line   = $options->{'monitor_line'};
    my $monitor_deinit = $options->{'monitor_deinit'};

    if (!defined $monitor_init) {
	$monitor_init = "monitor_init";
    }
    if (!defined $monitor_line) {
	$monitor_line = "monitor_line";
    }
    if (!defined $monitor_deinit) {
	$monitor_deinit = "monitor_deinit";
    }

#   my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(4);
#   print STDERR "Calling method: $cfilename:$cline $cpackage->$csubr:$cline\n";

    print $outhandle "$message_prefix: $command\n" if ($verbosity > 3);
    print $outhandle "  $message ..." if ($verbosity >= 1);

    my $command_status = undef;
    my $result = "";
    my $had_error = 0;

    my $saved_rec = &$monitor_init();

    if (open(CMD,"$command 2>&1 |"))
    {
	my $line;

	my $linecount = 0;
	my $dot_count = 0;


	while (defined ($line = <CMD>))
	{
	    $linecount++;

	    my ($had_local_error,$generate_dot) = &$monitor_line($line);
	    
	    if ($had_local_error) {
		# set general flag, but allow loop to continue to end building up the $result line
		print $outhandle "$line\n";
		$had_error = 1;
	    }

	
		if ($generate_dot)
		{
			if ($dot_count == 0) { print $outhandle "\n  "; }
			print $outhandle ".";
			$dot_count++;
				if (($dot_count%76)==0) 
			{
				print $outhandle "\n  ";
			}
		}
		
	    $result .= $line;
	    
	}
	print $outhandle "\n";

	
	close(CMD);

	$command_status = $?;
	if ($command_status != 0) {
	    $had_error = 1;
	    
	    # for commands that go via an intermediate layer (like commands to imagemagick go 
	    # through gs-magick.pl), need to shift exit code by 8 and then convert to its 
	    # signed value to get the actual exit code that imagemagick had emitted.
	    $command_status >>= 8;
	    $command_status = (($command_status & 0x80) ? -(0x100 - ($command_status & 0xFF)) : $command_status);	

	    print $outhandle "Error: processing command failed.  Exit status $command_status\n";

	    if ($verbosity >= 3) {
		print $outhandle "  Command was: $command\n";
	    }
	    if ($verbosity >= 4) {
		print $outhandle "$message_prefix result: $result\n";
	    }
	}
    }
    else 
    {
	$had_error = 1;
	print STDERR "Error: failed to execute $command\n";
    }

    &$monitor_deinit($saved_rec);

    if ($verbosity >= 1) {
	if ($had_error) {
	    print $outhandle "  ...error encountered\n";
	}
	else {
	    print $outhandle "  ...done\n";
	}
    }

    if (defined $command_status && ($command_status == 0))
    {
	# only want to print the following out if verbosity is high enough
	# and we haven't already printed it out as a detected error above
	print $outhandle "$message_prefix result: $result\n" if ($verbosity > 5);
    }

    return ($result,$had_error);
}


sub regenerate_general_cmd
{
    my ($command,$ifilename,$ofilename,$options) = @_;

    my $regenerated = 1;
    my $result = "";
    my $had_error = 0;

    ($result,$had_error) = run_general_cmd($command,$options);

    # store command args so can be compared with subsequent runs of the command
    my $args_filename = "$ofilename.args";

    if (open(ARGSOUT,">$args_filename")) {
	print ARGSOUT $command;
	print ARGSOUT "\n";
	close(ARGSOUT);
    }
    else {
	my $outhandle = $options->{'outhandle'};
	print $outhandle "Warning: Unable to write out caching information to file $args_filename\n";
	print $outhandle "         This means $ofilename will be regenerated on next build whether\n";
	print $outhandle "         processing args have changed or not.\n";
    }

    # Store the result, since ImageConverter.pm extracts the image height and width from the processed result
    my $result_filename = "$ofilename.result";
    if (open(RESOUT, ">$result_filename"))
    {
	print RESOUT $result;
	close(RESOUT);
    }
    else
    {
	my $outhandle = $options->{'outhandle'};
	print $outhandle "Warning: Unable to write out cached process result to file $result_filename.\n";
    }

    return ($regenerated,$result,$had_error);
}



sub run_cached_general_cmd
{
    my ($command,$ifilename,$ofilename,$options) = @_;

    my $outhandle = $options->{'outhandle'};
    my $verbosity = $options->{'verbosity'};
    my $message_prefix = $options->{'message_prefix'};

    my $regenerated = 0;
    my $result = "";
    my $had_error = 0;

    my $args_filename = "$ofilename.args";

    if ((!-e $ofilename) || (!-e $args_filename)) {
	($regenerated,$result,$had_error) 
	    = regenerate_general_cmd($command,$ifilename,$ofilename,$options);
    }
    elsif (-M $ifilename < -M $args_filename) {
	# Source files has been updated/changed in some way
	# => regenerate
	print $outhandle "$ifilename modified more recently than cached version\n";

	($regenerated,$result,$had_error) 
	    = regenerate_general_cmd($command,$ifilename,$ofilename,$options);
    }
    else {
	# file exists => check to see if command to generate it has changed

	if (open (ARGSIN,"<$args_filename")) {
	    my $prev_command = <ARGSIN>;
	    chomp($prev_command);

	    close(ARGSIN);

	    if (defined $prev_command) {
		# if commands are different
		if ($prev_command ne $command) {
		    # need to rerun command
		    ($regenerated,$result,$had_error) 
			= regenerate_general_cmd($command,$ifilename,$ofilename,$options);
		}
		else {
		    my ($ofile) = ($ofilename =~ m/^.*(cached.*)$/);

		    my $ofile_no_dir = basename($ofile);
		    print $outhandle "  $message_prefix: Cached file $ofile_no_dir already exists.\n";
		    print $outhandle "  $message_prefix: No need to regenerate $ofile\n" if ($verbosity > 2);
           
		    if ((defined $options->{'cache_mode'}) 
			&& $options->{'cache_mode'} eq "without_result") {
			$result = "";			
		    }
		    else {
			# Read in the cached result lines and join them into a single string
			my $result_filename = "$ofilename.result";
			if (open(RESIN, "<$result_filename"))
			{
			    my @result_lines = <RESIN>;
			    $result = join("\n", @result_lines);
			    close(RESIN);
			}
			else
			{
			    print $outhandle "  $message_prefix: Error, failed to obtain cached result from $result_filename.\n";
			}
		    }
		}
		    
	    }
	}
	else {
	    print $outhandle "  $message_prefix: No cached previous args found.  Regenerating $ofilename\n";

	    ($regenerated,$result,$had_error) 
		= regenerate_general_cmd($command,$ifilename,$ofilename,$options);
	}
    }

    return ($regenerated,$result,$had_error);
}


1;
