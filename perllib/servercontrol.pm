#############################################################################
#
# activate.pm -- functions to get the GS library URL, ping the library URL, 
# activate and deactivate a collection.
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
###############################################################################

package servercontrol;


use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

# Greenstone includes
use printusage;
use parse2;


# The perl library imports below are used by deprecated methods config_old(), is_URL_active() and pingHost()
# If the following library imports are not supported by your perl installation, comment out these
# imports and move the methods config_old(), is_URL_active() and pingHost() out to a temporary file.
use HTTP::Response;
use LWP::Simple qw($ua !head); # import useragent object as $ua from the full LWP to use along with LWP::Simple
		# don't import LWP::Simple's head function by name since it can conflict with CGI:head())
#use CGI qw(:standard);  # then only CGI.pm defines a head()
use Net::Ping;
use URI;


sub new
{
  my $class = shift(@_);

  my ($qualified_collection, $site, $verbosity, $build_dir, $index_dir, $collect_dir, $library_url, $library_name) = @_;

  # library_url: to be specified on the cmdline if not using a GS-included web server
  # the GSDL_LIBRARY_URL env var is useful when running cmdline buildcol.pl in the linux package manager versions of GS3

  my $self = {'build_dir' => $build_dir,
              'index_dir' => $index_dir,
              'collect_dir' => $collect_dir,
              'site' => $site,
              'qualified_collection' => $qualified_collection,
	      #'is_persistent_server' => undef,
              'library_url' => $library_url || $ENV{'GSDL_LIBRARY_URL'} || undef, # to be specified on the cmdline if not using a GS-included web server
              'library_name' => $library_name,
	      #'gs_mode' => "gs2",
	      'verbosity' => $verbosity || 2
             };

  if ((defined $site) && ($site ne "")) { # GS3
      $self->{'gs_mode'} = "gs3";
  } else {
      $self->{'gs_mode'} = "gs2";
  }

  return bless($self, $class);
}

## TODO: gsprintf to $self->{'out'} in these 2 print functions
## See buildcolutils.pm new() for setting up $out

sub print_task_msg {
    my $self = shift(@_);
    my ($task_msg, $verbosity_setting) = @_;
    
    $verbosity_setting = $self->{'verbosity'} unless $verbosity_setting;
    #$verbosity_setting = 1 unless defined $verbosity;
    if($verbosity_setting >= 1) {
	print STDERR "\n";
	print STDERR "************************\n";
	print STDERR "* $task_msg\n";
	print STDERR "************************\n";
    }
}

# Prints messages if the verbosity is right. Does not add new lines.
sub print_msg {
    my $self = shift(@_);
    my ($msg, $min_verbosity, $verbosity_setting) = @_;

    # only display error messages if the current 
    # verbosity setting >= the minimum verbosity level
    # needed for that message to be displayed.
	
    $verbosity_setting = $self->{'verbosity'} unless defined $verbosity_setting;
    $min_verbosity = 1 unless defined $min_verbosity;
    if($verbosity_setting >= $min_verbosity) { # by default display all 1 messages
	print STDERR "$msg";
    }
}

# Method to send a command to a GS2 or GS3 library_URL
# the commands used in this script can be activate, deactivate, ping, 
# and is-persistent (is-persistent only implemented for GS2).
sub config {
    my $self = shift(@_);
    my ($command, $check_message_against_regex, $expected_error_code, $silent) = @_;

    my $library_url = $self->get_library_URL(); #$self->{'library_url'};


    # Gatherer.java's configGS3Server doesn't use the site variable
    # so we don't have to either
    
    # for GS2, getting the HTTP status isn't enough, we need to read the output
    # since this is what CollectionManager.config() stipulates.
    # Using LWP::UserAgent::get($url) for this	
    
    if(!defined $library_url) {
	return 0;
    }
    else {
	# ampersands need to be escaped 
	# - with single quotes around it for linux for the cmd to run in bash subshell
	# - with a ^ before it on windows for the cmd to run in a DOS prompt subshell
	# - or the entire wget command should be nested in double quotes (single quotes don't work on windows)
	my $wgetCommand = $command;

	my $wget_file_path = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wget");
	my $tmpfilename = &util::get_tmp_filename(".html"); # random file name with html extension in tmp location in which we'll store the HTML page retrieved by wget
	
	# https://www.gnu.org/software/wget/manual/wget.html
	# output-document set to - (STDOUT), so page is streamed to STDOUT
	# timeout: 5 seconds, tries: 1
	# wget sends status information and response code to STDERR, so redirect it to STDOUT
	# Searching for "perl backtick operator redirect stderr to stdout":
	# http://www.perlmonks.org/?node=How%20can%20I%20capture%20STDERR%20from%20an%20external%20command%3F
	##$wgetCommand = "\"$wget_file_path\" --spider -T 5 -t 1 \"$library_url$wgetCommand\" 2>&1"; # won't save page
	#$wgetCommand = "\"$wget_file_path\" --output-document=- -T 5 -t 1 \"$library_url$wgetCommand\" 2>&1"; # THIS CAN MIX UP STDERR WITH STDOUT IN THE VERY LINE WE REGEX TEST AGAINST EXPECTED OUTPUT!!
	$wgetCommand = "\"$wget_file_path\" --output-document=\"$tmpfilename\" -T 5 -t 1 \"$library_url$wgetCommand\" 2>&1"; # keep stderr (response code, response_content) separate from html page content
	
	##print STDERR "@@@@ $wgetCommand\n";
	
	my $response_content;
	my $response_code = undef;
	#my $response_content = `$wgetCommand`; # Dr Bainbridge advises against using backticks for running a process. If capturing std output, use open():
	if (open(PIN, "$wgetCommand |")) {
	    while (defined (my $perl_output_line = <PIN>)) {
			$response_content = $response_content . $perl_output_line;
	    }
	    close(PIN);
	} else {
	    print STDERR "servercontrol.pm::config() failed to run $wgetCommand\n";
	}
	
	
	my @lines = split( /\n/, $response_content );
	foreach my $line (@lines) {
	    #print STDERR "@@@@ LINE: $line\n";
	    if($line =~ m@failed: Connection timed out.$@) { # linux
		$response_code = "failed: Connection timed out.";
		last; # break keyword in perl = last
	    }
		elsif($line =~ m@Giving up.$@) { # windows (unless -T 5 -t 1 is not passed in)
		$response_code = "failed: Giving up.";
		last; # break keyword in perl = last
	    }
	    elsif($line =~ m@failed: Connection refused.$@) {
		$response_code = "failed: Connection refused.";
		last; # break keyword in perl = last
	    }
	    elsif($line =~ m@HTTP request sent, @) {
		$response_code = $line;
		$response_code =~ s@[^\d]*(.*)$@$1@;
		last;
	    }
	}

	if($command =~ m@ping@ && $response_code =~ m@failed: (Connection refused|Giving up)@) {
	    # server not running
	    $self->print_msg("*** Server not running. $library_url$command\n", 3);
		&FileUtils::removeFiles($tmpfilename); # get rid of the ping response's temporary html file we downloaded
	    return 0;
	}
	if($response_code && $response_code eq "200 OK") {
	    $self->print_msg("*** Command $library_url$command\n", 3);
	    $self->print_msg("*** HTTP Response Status: $response_code - Complete.", 3);
	    
	    # check the page content is as expected
	    #my $resultstr = $response_content;
		
		open(FIN,"<$tmpfilename") or die "servercontrol.pm: Unable to open $tmpfilename to read ping response page...ERROR: $!\n";
		my $resultstr;
		# Read in the entire contents of the file in one hit
		sysread(FIN, $resultstr, -s FIN);		
		close(FIN);
		&FileUtils::removeFiles($tmpfilename); # get rid of the ping response's temporary html file we downloaded
		
		
	    #$resultstr =~ s@.*gs_content\"\>@@s;	## only true for default library servlet	
	    #$resultstr =~ s@</div>.*@@s;
	    if($resultstr =~ m/$check_message_against_regex/) {
		$self->print_msg(" Response as expected.\n", 3);
		$self->print_msg("@@@@@@ Got result:\n$resultstr\n", 4);
		return 1;
	    } else {
		# if we expect the collection to be inactive, then we'd be in silent mode: if so,
		# don't print out the "ping did not succeed" response, but print out any other messages
		
		# So we only suppress the ping col "did not succeed" response if we're in silent mode
		# But if any message other than ping "did not succeed" is returned, we always print it
		if($resultstr !~ m/did not succeed/ || !$silent) {
		    $self->print_msg("\n\tBUT: command $library_url$command response UNEXPECTED.\n", 3);
		    $self->print_msg("*** Got message:\n$response_content.\n", 4);
		    $self->print_msg("*** Got result:\n$resultstr\n", 3);
		}
		return 0; # ping on a collection may "not succeed."
	    }
	}
	elsif($response_code && $response_code =~ m@^(4|5)\d\d@) { # client side errors start with 4xx, server side with 5xx
	    # check the page content is as expected
	    if(defined $expected_error_code && $response_code =~ m@^$expected_error_code@) {
		$self->print_msg(" Response status $response_code as expected.\n", 3);
	    } else {
		$self->print_msg("*** Command $library_url$command\n");
		$self->print_msg("*** Unexpected error type 1. HTTP Response Status: $response_code - Failed.\n");
	    }
	    return 0; # return false, since the response_code was an error, expected or not
	}	
	else {  # also if response_code is still undefined, as can happen with connection timing out
	    $self->print_msg("*** Command $library_url$command\n");
	    if(defined $response_code) {
		$self->print_msg("*** Unexpected error type 2. HTTP Response Status: $response_code - Failed.\n");
	    } else {
		$self->print_msg("*** Unexpected error type 3. Failed:\n\n$response_content\n\n");
	    }
	    return 0;
	}
	#print STDERR "********** WgetCommand: $wgetCommand\n\n";
	#print STDERR "********** Response_content:\n$response_content\n\n";
	#print STDERR "********** Response_CODE: $response_code\n";

    }	
}

sub deactivate_collection {
    my $self = shift(@_);

    my $gs_mode = $self->{'gs_mode'};
    my $qualified_collection = $self->{'qualified_collection'};
    
    if($gs_mode eq "gs2") {
	my $DEACTIVATE_COMMAND = "?a=config&cmd=release-collection&c=";
	my $check_message_against_regex = q/configured release-collection/;
	$self->config($DEACTIVATE_COMMAND.$qualified_collection, $check_message_against_regex);
    }
    elsif ($gs_mode eq "gs3") {
	my $DEACTIVATE_COMMAND = "?a=s&sa=d&st=collection&sn=";
	my $check_message_against_regex = "collection: $qualified_collection deactivated";
	$self->config($DEACTIVATE_COMMAND.$qualified_collection, $check_message_against_regex);
    }	
}

sub activate_collection {
    my $self = shift(@_);

    my $gs_mode = $self->{'gs_mode'};
    my $qualified_collection = $self->{'qualified_collection'};

    if($gs_mode eq "gs2") {
	my $ACTIVATE_COMMAND = "?a=config&cmd=add-collection&c=";
	my $check_message_against_regex = q/configured add-collection/;
	$self->config($ACTIVATE_COMMAND.$qualified_collection, $check_message_against_regex);
    }
    elsif ($gs_mode eq "gs3") {
	my $ACTIVATE_COMMAND = "?a=s&sa=a&st=collection&sn=";
	my $check_message_against_regex = "collection: $qualified_collection activated";
	$self->config($ACTIVATE_COMMAND.$qualified_collection, $check_message_against_regex);
    }	
}

sub ping {
    my $self = shift(@_);
    my $command = shift(@_);
    my $silent = shift(@_);
    
    # If the GS server is not running, we *expect* to see a "500" status code.
    # If the GS server is running, then "Ping" ... "succeeded" is expected on success. 
    # When pinging an inactive collection, it will say it did "not succeed". This is
    # a message of interest to return.
    my $check_responsemsg_against_regex = q/(succeeded)/;
    my $expected_error_code = 500;
    
    $self->print_msg("*** COMMAND WAS: |$command| ***\n", 4);
    
    return $self->config($command, $check_responsemsg_against_regex, $expected_error_code, $silent);
}

# send a pingaction to the GS library. General server-level ping.
sub ping_library {
    my $self = shift(@_);

    my $gs_mode = $self->{'gs_mode'};

    my $command = "";
    if($gs_mode eq "gs2") {		
	$command = "?a=ping";		
    }
    elsif ($gs_mode eq "gs3") {		
	$command = "?a=s&sa=ping";
    }
    return $self->ping($command);
}


# send a pingaction to a collection in GS library to check if it's active
sub ping_library_collection {
    my $self = shift(@_);
    my $silent = shift(@_);

    my $gs_mode = $self->{'gs_mode'};
    my $qualified_collection = $self->{'qualified_collection'};

    my $command = "";
    if($gs_mode eq "gs2") {		
	$command = "?a=ping&c=$qualified_collection";
    }
    elsif ($gs_mode eq "gs3") {		
	$command = "?a=s&sa=ping&st=collection&sn=$qualified_collection";		
    }
    return $self->ping($command, $silent);
}

# return true if server is persistent, by calling is-persistent on library_url
# this is only for GS2, since the GS3 server is always persistent
sub is_persistent {
    my $self = shift(@_);
    
    if($self->{'gs_mode'} eq "gs3") { # GS3 server is always persistent
	return 1;
    }
    
    my $command = "?a=is-persistent";	
    my $check_responsemsg_against_regex = q/true/;	# isPersistent: true versus isPersistent: false 	
    return $self->config($command, $check_responsemsg_against_regex);
}

sub set_library_URL {
    my $self = shift(@_);
    my $library_url = shift(@_);
    $self->{'library_url'} = $library_url;
}

sub get_library_URL {
    my $self = shift(@_);
    
    # For web servers that are external to a Greenstone installation, 
    # the user can pass in their web server's library URL.
    if($self->{'library_url'}) {
	return $self->{'library_url'};
    }
    
    # For web servers included with GS (like tomcat for GS3 and server.exe 
    # and apache for GS2), we work out the library URL:
    my ($gs_mode, $lib_name); # gs_mode can be gs3 or gs2, lib_name is the custom servlet name
    $gs_mode = $self->{'gs_mode'};
    $lib_name = $self->{'library_name'};
	
    # If we get here, we are dealing with a server included with GS.
    # For GS3, we ask ant for the library URL.
    # For GS2, we derive the URL from the llssite.cfg file.

	my $url = &util::get_full_greenstone_url_prefix($gs_mode, $lib_name); # found largely identical method copied
			# into util. Don't want duplicates, so calling that from here.
	
	# either the url is still undef or it is now set
    #print STDERR "\n@@@@@ final URL:|$url|\n" if $url;		
    #print STDERR "\n@@@@@ URL still undef\n" if !$url;
	
	if (defined $url) {
		$self->{'library_url'} = $url;
	}

    return $url;
}

sub do_deactivate {
    my $self = shift(@_);

    # 1. Get library URL
    
    # For web servers that are external to a Greenstone installation, 
    # the user can pass in their web server's library URL.
    # For web servers included with GS (like tomcat for GS3 and server.exe 
    # and apache for GS2), we work out the library URL:

    # Can't do $self->{'library_url'}, because it may not yet be set
    my $library_url = $self->get_library_URL(); # returns undef if no valid server URL

    if(!defined $library_url) { # undef if no valid server URL
	return; # can't do any deactivation without a valid server URL
    }

    my $is_persistent_server = $self->{'is_persistent_server'};
    my $qualified_collection = $self->{'qualified_collection'};

    # CollectionManager's installCollection phase in GLI
    # 2. Ping the library URL, and if it's a persistent server and running, release the collection

    $self->print_msg("Pinging $library_url\n");		
    if ($self->ping_library()) { # server running
	
	# server is running, so release the collection if 
	# the server is persistent and the collection is active	

	# don't need to work out persistency of server more than once, since the libraryURL hasn't changed
	if (!defined $is_persistent_server) {
	    $self->print_msg("Checking if Greenstone server is persistent\n");
	    $is_persistent_server = $self->is_persistent();
	    $self->{'is_persistent_server'} = $is_persistent_server;
	}
	
	if ($is_persistent_server) { # only makes sense to issue activate and deactivate cmds to a persistent server
	    
	    $self->print_msg("Checking if the collection $qualified_collection is already active\n");
	    my $collection_active = $self->ping_library_collection();
	    
	    if ($collection_active) {
		$self->print_msg("De-activating collection $qualified_collection\n");
		$self->deactivate_collection();
	    }
	    else {
		$self->print_msg("Collection is not active => No need to deactivate\n");
	    }
	}
	else {
	    $self->print_msg("Server is not persistent => No need to deactivate collection\n");
	}
    }
    else {
	$self->print_msg("No response to Ping => Taken to mean server is not running\n");
    }
    
    return $is_persistent_server;
}

sub do_activate {
    my $self = shift @_;

    my $library_url = $self->get_library_URL(); # Can't do $self->{'library_url'}; as it may not be set yet

    if(!defined $library_url) { # undef if no valid server URL
	return; # nothing to activate if without valid server URL
    }

    my $is_persistent_server = $self->{'is_persistent_server'};
    my $qualified_collection = $self->{'qualified_collection'};

    $self->print_msg("Pinging $library_url\n");
    if ($self->ping_library()) { # server running
	
	# don't need to work out persistency of server more than once, since the libraryURL hasn't changed
	if (!defined $is_persistent_server) {
	    $self->print_msg("Checking if Greenstone server is persistent\n");
	    $is_persistent_server = $self->is_persistent();
	    $self->{'is_persistent_server'} = $is_persistent_server;
	}
	
	if ($is_persistent_server) { # persistent server, so can try activating collection
	    
	    $self->print_msg("Checking if the collection $qualified_collection is not already active\n");
	    
	    # Since we could have deactivated the collection at this point,
	    # it is likely that it is not yet active. When pinging the collection
	    # a "ping did not succeed" message is expected, therefore tell the ping
	    # to proceed silently
	    my $silent = 1;
	    my $collection_active = $self->ping_library_collection($silent);
	    
	    if (!$collection_active) {
		$self->print_msg(" Collection is not active.\n");
		$self->print_msg("Activating collection $qualified_collection\n");
		$self->activate_collection();
		
		# unless an error occurred, the collection should now be active:
		$collection_active = $self->ping_library_collection(); # not silent if ping did not succeed
		if(!$collection_active) {
		    $self->print_msg("ERROR: collection $qualified_collection did not get activated\n");
		}
	    }
	    else {
		$self->print_msg("Collection is already active => No need to activate\n");
	    }
	}
	else {
	    $self->print_msg("Server is not persistent => No need to activate collection\n");
	}
    }
    else {
	$self->print_msg("No response to Ping => Taken to mean server is not running\n");
    }
    
    return $is_persistent_server;
}


#########################################################
### UNUSED METHODS - CAN BE HANDY


# This method uses the perl libraries we're advised to use in place of wget for pinging and retrieving web 
# pages. The problem is that not all perl installations may support these libraries. So we now use the new
# config() method further above, which uses the wget included in Greenstone binary installations.
# If the library imports at page top conflict, comment out those imports and move the methods config_old(),
# is_URL_active() and pingHost() out to a temporary file.
# 
# If for some reason you can't use wget, then rename the config() method to config_old(), and rename the
# method below to config() and things should work as before.
sub config_old {
    my $self = shift(@_);
    my ($command, $check_message_against_regex, $expected_error_code, $silent) = @_;

    my $library_url = $self->get_library_URL(); #$self->{'library_url'};


    # Gatherer.java's configGS3Server doesn't use the site variable
    # so we don't have to either
    
    # for GS2, getting the HTTP status isn't enough, we need to read the output
    # since this is what CollectionManager.config() stipulates.
    # Using LWP::UserAgent::get($url) for this	
    
    if(!defined $library_url) {
	return 0;
    }
    else {
	$ua->timeout(5); # set LWP useragent to 5s max timeout for testing the URL
	# Need to set this, else it takes I don't know how long to timeout 
	# http://www.perlmonks.org/?node_id=618534
	
	# http://search.cpan.org/~gaas/libwww-perl-6.04/lib/LWP/UserAgent.pm
	# use LWP::UserAgent's get($url) since it returns an HTTP::Response code
	
	my $response_obj = $ua->get($library_url.$command);
	
	# $response_obj->content stores the content and $response_obj->code the HTTP response code
	my $response_code = $response_obj->code();
	
	if(LWP::Simple::is_success($response_code)) {# $response_code eq RC_OK) { # LWP::Simple::is_success($response_code)
	    $self->print_msg("*** Command $library_url$command\n", 3);
	    $self->print_msg("*** HTTP Response Status: $response_code - Complete.", 3);
	    
	    # check the page content is as expected
	    my $response_content = $response_obj->content;
	    my $resultstr = $response_content;
	    $resultstr =~ s@.*gs_content\"\>@@s;		
	    $resultstr =~ s@</div>.*@@s;
	    
	    if($resultstr =~ m/$check_message_against_regex/) {#if($response_content =~ m/$check_message_against_regex/) {
		$self->print_msg(" Response as expected.\n", 3);
		$self->print_msg("@@@@@@ Got result:\n$resultstr\n", 4);
		return 1;
	    } else {
		# if we expect the collection to be inactive, then we'd be in silent mode: if so,
		# don't print out the "ping did not succeed" response, but print out any other messages
		
		# So we only suppress the ping col "did not succeed" response if we're in silent mode
		# But if any message other than ping "did not succeed" is returned, we always print it
		if($resultstr !~ m/did not succeed/ || !$silent) {#if($response_content !~ m/did not succeed/ || !$silent) {
		    $self->print_msg("\n\tBUT: command $library_url$command response UNEXPECTED.\n", 3);
		    $self->print_msg("*** Got message:\n$response_content.\n", 4);
		    $self->print_msg("*** Got result:\n$resultstr\n", 3);
		}
		return 0; # ping on a collection may "not succeed."
	    }
	} 
	elsif(LWP::Simple::is_error($response_code)) { # method exported by LWP::Simple, along with HTTP::Status constants
	    # check the page content is as expected
	    if(defined $expected_error_code && $response_code == $expected_error_code) {
		$self->print_msg(" Response status $response_code as expected.\n", 3);
	    } else {
		$self->print_msg("*** Command $library_url$command\n");
		$self->print_msg("*** Unexpected error. HTTP Response Status: $response_code - Failed.\n");
	    }
	    return 0; # return false, since the response_code was an error, expected or not
	}
	else {
	    $self->print_msg("*** Command $library_url$command\n");
	    $self->print_msg("*** Unexpected error. HTTP Response Status: $response_code - Failed.\n");
	    return 0;
	}
    }	
}

# This method is now unused. Using ping_library instead to send the ping action to a
# GS2/GS3 server. This method can be used more generally to test whether a URL is alive.
# http://search.cpan.org/dist/libwww-perl/lib/LWP/Simple.pm
# and http://www.perlmonks.org/?node_id=618534
sub is_URL_active {
    my $url = shift(@_); # gs3 or gs2 URL	
    
    my $status = 0;
    if(defined $url) {
	$ua->timeout(10); # set LWP useragent to 5s max timeout for testing the URL
	# Need to set this, else it takes I don't know how long to timeout 
	# http://www.perlmonks.org/?node_id=618534
	
	$status = LWP::Simple::head($url); # returns empty list of headers if it fails
	# LWP::Simple::get($url) is more intensive, so don't need to do that
	#print STDERR "**** $url is alive.\n" if $status;
    }
    return $status;
}

# Pinging seems to always return true, so this method doesn't work
sub pingHost {
    my $url = shift(@_); # gs3 or gs2 URL
    
    my $status = 0;
    if(defined $url) {
	# Get just the domain. "http://localhost/gsdl?uq=332033495" becomes "localhost"
	# "http://localhost/greenstone/cgi-bin/library.cgi" becomes "localhost" too	
	
	#my $host = $url;		
	#$host =~ s@^https?:\/\/(www.)?@@;		
	#$host =~ s@\/.*@@;
	#print STDERR "**** HOST: $host\n";
	
	# More robust way
	# http://stackoverflow.com/questions/827024/how-do-i-extract-the-domain-out-of-an-url
	my $uri = URI->new( $url );
	my $host = $uri->host; 
	
	# Ping the host. http://perldoc.perl.org/Net/Ping.html	
	my $p = Net::Ping->new();		
	$status = $p->ping($host); # || 0. Appears to set to undef rather than 0
	print STDERR "**** $host is alive.\n" if $status; #print "$host is alive.\n" if $p->ping($host);
	$p->close();		
    } 
    # return whether pinging was a success or failure
    return $status;
}

1;
