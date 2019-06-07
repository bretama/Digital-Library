###########################################################################
#
# WgetDownload.pm -- Download base module that handles calling Wget
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

package WgetDownload;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use BaseDownload;
use strict;
no strict 'subs'; # make an exception so we can use variables as filehandles to pass STDERR/STDOUT to functions, needed for gsprintf()
use Cwd;
use util;
use IPC::Open3;
use IO::Select;
use IO::Socket;
use Text::ParseWords; # part of Core modules. Needed to use quotewords() subroutine

#use IO::Select qw( );
#use IPC::Open3 qw( open3 );
use Socket     qw( AF_UNIX SOCK_STREAM PF_UNSPEC ); # http://perlmeme.org/howtos/perlfunc/qw_function.html


sub BEGIN {
    @WgetDownload::ISA = ('BaseDownload');
}

my $arguments = 
     [ { 'name' => "proxy_on", 
	'desc' => "{WgetDownload.proxy_on}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "http_proxy_host",
	'desc' => "{WgetDownload.http_proxy_host}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "http_proxy_port",
	'desc' => "{WgetDownload.http_proxy_port}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "https_proxy_host",  
	'desc' => "{WgetDownload.https_proxy_host}",         
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "https_proxy_port", 
	'desc' => "{WgetDownload.https_proxy_port}",         
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "ftp_proxy_host",  
	'desc' => "{WgetDownload.ftp_proxy_host}",         
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "ftp_proxy_port", 
	'desc' => "{WgetDownload.ftp_proxy_port}",         
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "user_name",  
	'desc' => "{WgetDownload.user_name}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "user_password", 
	'desc' => "{WgetDownload.user_password}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "no_check_certificate", 
	'desc' => "{WgetDownload.no_check_certificate}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes"}
     ];

my $options = { 'name'     => "WgetDownload",
		'desc'     => "{WgetDownload.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


# Declaring file global variables related to the wget child process so that 
# the termination signal handler for SIGTERM can close the streams and tidy
# up before ending the child process.
my $childpid;
my ($chld_out, $chld_in);
my ($serverSocket, $read_set);

my $TIMEOUT = 1; # seconds
my $NUM_TRIES = 10;

# The port this script's server socket will be listening on, to handle 
# incoming signals from GLI to terminate wget. This is also file global, 
# since OAIDownload.pm will make several calls on wget using the same 
# instance of this script and we want to reuse whatever port GLI gave us.
my $port; 

# When this script is called from the command line, this handler will be called
# if this process is killed or abruptly ends due to receiving one of the
# terminating signals that this handler is registered to deal with.
sub abrupt_end_handler {
    my $termination_signal = shift (@_);

    if(defined $childpid) {
	close($chld_out);
	close($chld_in);
	
	print STDOUT "Received termination signal: $termination_signal\n";

	# Send TERM signal to child process to terminate it. Sending the INT signal doesn't work
	# See http://perldoc.perl.org/perlipc.html#Signals 
	# Warning on using kill at http://perldoc.perl.org/perlfork.html
	kill("TERM", $childpid); # prefix - to signal to kill process group

	# If the SIGTERM sent on Linux calls this handler, we want to make
	# sure any socket connection is closed.
	# Otherwise sockets are only used when this script is run from GLI
	# in which case the handlers don't really get called.
	if(defined $serverSocket) {
	    $read_set->remove($serverSocket) if defined $read_set;
	    close($serverSocket);
	}
    }

    exit(0);
}

# Registering a handler for when termination signals SIGINT and SIGTERM are received to stop
# the wget child process. SIGTERM--generated by Java's Process.destroy()--is the default kill
# signal (kill -15) on Linux, while SIGINT is generated upon Ctrl-C (also on Windows). 
# Note that SIGKILL can't be handled as the handler won't get called for it. More information: 
# http://affy.blogspot.com/p5be/ch13.htm
# http://perldoc.perl.org/perlipc.html#Signals
$SIG{'INT'} = \&abrupt_end_handler;
$SIG{'TERM'} = \&abrupt_end_handler;

sub new {
    my ($class) = shift (@_);
    my ($getlist,$inputargs,$hashArgOptLists) = @_;
    push(@$getlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseDownload($getlist,$inputargs,$hashArgOptLists);

    # the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
    &util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

    return bless $self, $class;
}

sub checkWgetSetup
{
    my ($self,$blnGliCall) = @_;
    #TODO: proxy detection??
    
    if((!$blnGliCall) && $self->{'proxy_on'})
    {
	&checkProxySetup($self);
    }
    &checkURL($self); 
}

# Not using this. On Windows, we used to pass proxying settings as flags to wget. But, as that can be
# seen with Task Manager, we now have the proxy settings set in the environment and are no longer passing it
sub addProxySettingsAsWgetFlags
{
    my ($self) = @_;
    my $strOptions = "";

    if($self->{'http_proxy_host'} && $self->{'http_proxy_port'}) {
	$strOptions .= " -e http_proxy=$self->{'http_proxy_host'}:$self->{'http_proxy_port'} ";
    }
    if($self->{'https_proxy_host'} && $self->{'https_proxy_port'}) {
	$strOptions .= " -e https_proxy=$self->{'https_proxy_host'}:$self->{'https_proxy_port'} ";
    }
    if($self->{'ftp_proxy_host'} && $self->{'ftp_proxy_port'}) {
	$strOptions .= " -e ftp_proxy=$self->{'ftp_proxy_host'}:$self->{'ftp_proxy_port'} ";
    }
    
    # For wget, there is only one set pair of proxy-user and proxy-passwd, so wget seems to assume
    # that all 3 proxy protocols (http|https|ftp) will use the same username and pwd combination?
    # Note that this only matters when passing the proxying details as flags to wget, not when
    # the proxies are setup as environment variables.
    if ($self->{'user_name'} && $self->{'user_password'})
    {
	$strOptions .= "--proxy-user=$self->{'user_name'}"." --proxy-passwd=$self->{'user_password'}";	    
	# how is "--proxy-passwd" instead of "--proxy-password" even working????	    
	# see https://www.gnu.org/software/wget/manual/html_node/Proxies.html
	# and https://www.gnu.org/software/wget/manual/wget.html
	# Not touching this, in case the manual is simply wrong. Since our code works in 
	# practice (when we were still using wget proxy username/pwd flags for windows).
    }   
    
    return $strOptions;
}

sub getWgetOptions
{
    my ($self) = @_;
    my $strOptions = "";
    
    # If proxy settings are set up in the environment, wget is ready to use them. More secure.
    # But if proxy settings are not set up in the environment, pass them as flags to wget
    # This is less secure, as pwd etc visible in task manager, but it was the original way in
    # which wget was run on windows.
    # Truth in Perl: https://home.ubalt.edu/abento/452/perl/perltruth.html
    # http://www.perlmonks.org/?node=what%20is%20true%20and%20false%20in%20Perl%3F
    
    if ($self->{'proxy_on'}) {
	if(!$ENV{'http_proxy'} && !$ENV{'https_proxy'} && !$ENV{'ftp_proxy'}) {
	    $strOptions .= $self->addProxySettingsAsWgetFlags();
	} # else wget will use proxy settings in environment, assume enough settings have been provided
	# either way, we're using the proxy
	$strOptions .= " --proxy ";
    }
    
    if($self->{'no_check_certificate'}) { # URL may be http that gets redirected to https, so if no_check_certificate is on, turn it on even if URL is http
	
	$strOptions .= " --no-check-certificate ";
    }
    
    return $strOptions;
}

# Checking for proxy setup: proxy server, proxy port, proxy username and password.
sub checkProxySetup
{
    my ($self) = @_;
    ($self->{'proxy_on'}) || &error("checkProxySetup","The proxy is not on? How could that be happening?");
    # Setup .wgetrc by using $self->{'proxy_host'} and $self->{'proxy_port'}
    # Test if the connection is successful. If the connection wasn't successful then ask user to supply username and password.

}

# Returns true if the wget status needs to be monitored through sockets
# (if a socket is used to communicate with the Java program on when to
# terminate wget). True if we are running gli, or if the particular type
# of WgetDownload is *not* OAIDownload (in that case, the original way of 
# terminating the perl script from Java would terminate wget as well).
sub dealingWithSockets() {
    my ($self) = @_;
    return (defined $self->{'gli'} && $self->{'gli'} && !defined $port && ref($self) ne "OAIDownload");
                       # use ref($self) to find the classname of an object
}

# On Windows, we can only use IO::Select's can_read() with Sockets, not with the usual handles to a child process' iostreams
# However, we can use Sockets as the handles to connect to a child process' streams, which then allows us to use can_read()
# not just on Unix but Windows too. The 2 subroutines below to use Sockets to connect to a child process' iostreams come from
# http://www.perlmonks.org/?node_id=869942
# http://www.perlmonks.org/?node_id=811650
# It was suggested that IPC::Run will take care of all this or circumvent the need for all this,
# but IPC::Run has limitations on Windows, see http://search.cpan.org/~toddr/IPC-Run-0.96/lib/IPC/Run.pm#Win32_LIMITATIONS

# Create a unidirectional pipe to an iostream of a process that is actually a socket
sub _pipe {
    socketpair($_[0], $_[1], AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or return undef;
    shutdown($_[0], 1);  # No more writing for reader. See http://www.perlmonks.org/?node=108244
    shutdown($_[1], 0);  # No more reading for writer
    return 1;
}

sub _open3 {
    local (*TO_CHLD_R,     *TO_CHLD_W);
    local (*FR_CHLD_R,     *FR_CHLD_W);
    #local (*FR_CHLD_ERR_R, *FR_CHLD_ERR_W);

    if ($^O =~ /Win32/) {
        _pipe(*TO_CHLD_R,     *TO_CHLD_W    ) or die $^E;
        _pipe(*FR_CHLD_R,     *FR_CHLD_W    ) or die $^E;
        #_pipe(*FR_CHLD_ERR_R, *FR_CHLD_ERR_W) or die $^E;
    } else {
        pipe(*TO_CHLD_R,     *TO_CHLD_W    ) or die $!;
        pipe(*FR_CHLD_R,     *FR_CHLD_W    ) or die $!;
        #pipe(*FR_CHLD_ERR_R, *FR_CHLD_ERR_W) or die $!;
    }

    #my $pid = open3('>&TO_CHLD_R', '<&FR_CHLD_W', '<&FR_CHLD_ERR_W', @_);
	my $pid = open3('>&TO_CHLD_R', '<&FR_CHLD_W', '<&FR_CHLD_W', @_); # use one handle, chldout, for both stdout and stderr of child proc,
																	  # see http://blog.0x1fff.com/2009/09/howto-execute-system-commands-in-perl.html
	
	#return ( $pid, *TO_CHLD_W, *FR_CHLD_R, *FR_CHLD_ERR_R );
    return ( $pid, *TO_CHLD_W, *FR_CHLD_R);
}

# useWget and useWgetMonitored are very similar and, when updating, will probably need updating in tandem
# useWget(Monitored) runs the wget command using open3 and then sits in a loop doing two things per iteration:
# - processing a set buffer size of the wget (child) process' stdout/stderr streams, if anything has appeared there
# - followed by checking the socket connection to Java GLI, to see if GLI is trying to cancel the wget process we're running.
# Then the loop of these two things repeats.
sub useWget
{
    #local $| = 1; # autoflush stdout buffer
    #print STDOUT "*** Start of subroutine useWget in $0\n";

    my ($self, $cmdWget,$blnShow, $working_dir) = @_;

    my ($strReadIn,$strLine,$command);
    $strReadIn = "" unless defined $strReadIn;

    my $current_dir = cwd();
    my $changed_dir = 0;
    if (defined $working_dir && -e $working_dir) {
	chdir "$working_dir";
	$changed_dir = 1;
    }

    # When we are running this script through GLI, the SIGTERM signal handler 
    # won't get called on Windows when wget is to be prematurely terminated. 
    # Instead, when wget has to be terminated in the middle of execution, GLI will
    # connect to a serverSocket here to communicate when it's time to stop wget.
    if($self->dealingWithSockets()) {

	$port = <STDIN>; # gets a port on localhost that's not yet in use
	chomp($port);
	
	$serverSocket = IO::Socket::INET->new( Proto     => 'tcp',
					       LocalPort => $port,
					       Listen    => 1,
					       Reuse     => 1);
    
	die "can't setup server" unless $serverSocket;
	#print STDOUT "[Serversocket $0 accepting clients at port $port]\n";

	$read_set = new IO::Select();         # create handle set for reading
	$read_set->add($serverSocket);        # add the main socket to the set
    }

    my $wget_file_path = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wget");
	
	# Shouldn't use double quotes around wget path after all? See final comment at
	# http://www.perlmonks.org/?node_id=394709
	# http://coldattic.info/shvedsky/pro/blogs/a-foo-walks-into-a-bar/posts/63
    # Therefore, compose the command as an array rather than as a string, to preserve spaces in the filepath
    # because single/double quotes using open3 seem to launch a subshell, see also final comment at 
    # http://www.perlmonks.org/?node_id=394709 and that ends up causing problems in terminating wget, as 2 processes
    # got launched then which don't have parent-child pid relationship (so that terminating one doesn't terminate the other).

    # remove leading and trailing spaces, https://stackoverflow.com/questions/4597937/perl-function-to-trim-string-leading-and-trailing-whitespace
    $cmdWget =~ s/^\s+//;
    $cmdWget =~ s/\s+$//;

    # split on "words"
    #my @commandargs = split(' ', $cmdWget);
    # quotewords: to split on spaces except within quotes, then removes quotes and unescapes double backslash too 
      # https://stackoverflow.com/questions/19762412/regex-to-split-key-value-pairs-ignoring-space-in-double-quotes
      # https://docstore.mik.ua/orelly/perl/perlnut/c08_389.htm
    my @commandargs = quotewords('\s+', 0, $cmdWget);
    unshift(@commandargs, $wget_file_path); # prepend the wget cmd
    #print STDERR "Command is: ".join(",", @commandargs) . "\n"; # goes into ServerInfoDialog
    
    # Wget's output needs to be monitored to find out when it has naturally terminated.
    # Wget's output is sent to its STDERR so we can't use open2 without doing 2>&1.
    # On linux, 2>&1 launches a subshell which then launches wget, meaning that killing
    # the childpid does not kill wget on Linux but the subshell that launched it instead. 
    # Therefore, we use open3. Though the child process wget sends output only to its stdout [is this meant to be "stderr"?], 
    # using open3 says chld_err is undefined and the output of wget only comes in chld_out(!)
    # However that may be, it works with open3. But to avoid the confusion of managing and
    # closing an extra unused handle, a single handle is used instead for both the child's
    # stderr and stdout.
    # See http://blog.0x1fff.com/2009/09/howto-execute-system-commands-in-perl.html
    # for why this is the right thing to do.

    # Both open2 and open3 don't return on failure, but raise an exception. The handling
    # of the exception is described on p.568 of the Perl Cookbook
    eval {
	#$childpid = open3($chld_in, $chld_out, $chld_out, $command); # There should be no double quotes in command, like around filepaths to wget, else need to use array version of command as below
	#$childpid = open3($chld_in, $chld_out, $chld_out, @commandargs);
	
	# instead of calling open3 directly, call wrapper _open3() subroutine that will use sockets to
	# connect to the child process' iostreams, because we can then use IO::Select's can_read() even on Windows
	($childpid, $chld_in, $chld_out) = _open3(@commandargs);
    };
    if ($@) {
	if($@ =~ m/^open3/) {
	    die "open3 failed in $0: $!\n$@\n";	    
	}
	die "Tried to launch open3 in $0, got unexpected exception: $@";
    }

    # Switching to use IO::Select, which allows timeouts, instead of doing the potentially blocking
    #     if defined(my $strLine=<$chld_out>)
    # Google: perl open3 read timeout
    # Google: perl open3 select() example
    # https://stackoverflow.com/questions/10029406/why-does-ipcopen3-get-deadlocked
    # https://codereview.stackexchange.com/questions/84496/the-right-way-to-use-ipcopen3-in-perl
    # https://gist.github.com/shalk/6988937
    # https://stackoverflow.com/questions/18373500/how-to-check-if-command-executed-with-ipcopen3-is-hung
    # http://perldoc.perl.org/IO/Select.html
    # http://perldoc.perl.org/IPC/Open3.html - explains the need for select()/IO::Select with open3
    # http://www.perlmonks.org/?node_id=951554
    # http://search.cpan.org/~dmuey/IPC-Open3-Utils-0.91/lib/IPC/Open3/Utils.pm
    # https://stackoverflow.com/questions/3000907/wget-not-behaving-via-ipcopen3-vs-bash?rq=1

    # create the select object and add our streamhandle(s)
    my $sel = new IO::Select;
    $sel->add($chld_out);

    my $num_consecutive_timedouts = 0;
    my $error = 0;
    my $loop = 1;
    
    while($loop)
    {
	# assume we're going to timeout trying to read from child process
	$num_consecutive_timedouts++;

	
	# block until data is available on the registered filehandles or until the timeout specified	
	if(my @readyhandles = $sel->can_read($TIMEOUT)) {

	    $num_consecutive_timedouts = 0; # re-zero, as we didn't timeout reading from child process after all
	    # since we're in this if statement
	    
	    # now there's a list of registered filehandles we can read from to loop through reading from.
	    # though we've registered only one, chld_out
	    foreach my $fh (@readyhandles) {
		my $strLine;
		#sleep 3;
		
		# read up to 4096 bytes from this filehandle fh.
		# if there is less than 4096 bytes, we'll only get
		# those available bytes and won't block.  If there 
		# is more than 4096 bytes, we'll only read 4096 and
		# wait for the next iteration through the loop to 
		# read the rest.
		my $len = sysread($fh, $strLine, 4096);
		
		if($len) { # read something
		    if($blnShow) {
			print STDERR "$strLine\n";
		    }
		    $strReadIn .= $strLine;
		}
		else { # error or EOF: (!defined $len || $len == 0)		    
		    
		    if(!defined $len) { # could be an error reading	
			  # On Windows, the socket ends up forcibly closed on the "other" side. It's just the way it's implemented 
			  # on Windows when using sockets to our child process' iostreams. So $len not being defined is not an error in that case. Refer to
			  # https://stackoverflow.com/questions/16675950/perl-select-returning-undef-on-sysread-when-using-windows-ipcopen3-and-ios/16676271
			  if(!$!{ECONNRESET}) { # anything other ECONNRESET error means it's a real case of undefined $len being an error
				print STDERR "WgetDownload: Error reading from child stream: $!\n";
				# SHOULD THIS 'die "errmsg";' instead? - no, sockets may need closing
				$error = 1;
			  } else { # $! contains message "An existing connection was forcibly closed by remote host" where "remote" is a reference to the sockets to our wget child process,
					# NOT to the remote web server we're downloading from. In such a case, the error code is ECONNRESET, and it's not an error, despite $len being undefined.
				#print STDERR "WgetDownload: wget finished\n";
			  }
		    }
		    elsif ($len == 0) { # EOF
			# Finished reading from this filehandle $fh because we read 0 bytes.
			# wget finished, terminate naturally
			#print STDERR "WgetDownload: wget finished\n"; #print STDOUT "\nPerl: open3 command, input streams closed. Wget terminated naturally.\n";
		    }

		    $loop = 0; # error or EOF, either way will need to clean up and break out of outer loop
		    
		    # last; # if we have more than one filehandle registered with IO::Select
		    
		    $sel->remove($fh); # if more than one filehandle registered, we should unregister all of them here on error		    
		    
		} # end else error or EOF
		
	    } # end foreach on readyhandles
	} # end if on can_read
	
	if($num_consecutive_timedouts >= $NUM_TRIES) {
	    $error = 1;
	    $loop = 0;                          # to break out of outer while loop

	    $num_consecutive_timedouts = 0;

		&gsprintf::gsprintf(STDERR, "{WgetDownload.wget_timed_out_warning}\n", $NUM_TRIES);
	}

	if($loop == 0) { # error or EOF, either way, clean up
	    if($error) {
		$self->{'forced_quit'} = 1;         # subclasses need to know we're quitting
		
		if(kill(0, $childpid)) { 
		    # If kill(0, $childpid) returns true, then the process is running
		    # and we need to kill it.
		    close($chld_in);
		    close($chld_out);
		    kill('TERM', $childpid); # kill the process group by prefixing - to signal

		    # https://coderwall.com/p/q-ovnw/killing-all-child-processes-in-a-shell-script
		    # https://stackoverflow.com/questions/392022/best-way-to-kill-all-child-processes
		    #print STDERR "SENT SIGTERM TO CHILD PID: $childpid\n";		    
		    #print STDERR "Perl terminated wget after timing out repeatedly and is about to exit\n";
		}
	    }
	    else { # wget finished (no errors), terminate naturally
		#print STDOUT "\nPerl: open2 command, input stream closed. Wget terminated naturally.\n";
		close($chld_in);
		close($chld_out);
		waitpid $childpid, 0;		
	    }

	    # error or not
	    $childpid = undef;
	    # Stop monitoring the read_handle and close the serverSocket 
	    # (the Java end will close the client socket that Java opened)
	    if(defined $port) {
		$read_set->remove($serverSocket);
		close($serverSocket);
	    }
	}

	# If we've already terminated, either naturally or on error, we can get out of the while loop
	next if($loop == 0);
	
	# Otherwise check for whether Java GLI has attempted to connect to this perl script via socket
	
	# if we run this script from the command-line (as opposed to from GLI), 
	# then we're not working with sockets and can therefore skip the next bits
	next unless(defined $port);
	
	# http://www.perlfect.com/articles/select.shtml
	# "multiplex between several filehandles within a single thread of control, 
	# thus creating the effect of parallelism in the handling of I/O."
	my @rh_set = $read_set->can_read(0.002); # every 2 ms check if there's a client socket connecting

	# take all readable handles in turn
	foreach my $rh (@rh_set) {
	    if($rh == $serverSocket) {
		my $client = $rh->accept();
		#$client->autoflush(1); # autoflush output buffer - don't put this back in: output split irregularly over lines
		print $client "Talked to ServerSocket (port $port). Connection accepted\n";
		
		# Read from the client (getting rid of the trailing newline)
		# Has the client sent the <<STOP>> signal?
		my $signal = <$client>;
		chomp($signal); 
		if($signal eq "<<STOP>>") {
		    print $client "Perl received STOP signal (on port $port): stopping wget\n";
		    $loop = 0;                          # out of outer while loop
		    $self->{'forced_quit'} = 1;         # subclasses need to know we're quitting
		    
		    # Sometimes the wget process takes some time to start up. If the STOP signal
		    # was sent, don't try to terminate the process until we know it is running. 
		    # Otherwise wget may start running after we tried to kill it. Wait 5 seconds
		    # for it to start up, checking for whether it is running in order to kill it.
		    for(my $seconds = 1; $seconds <= 5; $seconds++) {
			if(kill(0, $childpid)) {
			    # If kill(0, $childpid) returns true, then the process is running
			    # and we need to kill it.
			    close($chld_in);
			    close($chld_out);
			    kill("TERM", $childpid); # prefix - to signal to kill process group
			    
			    $childpid = undef;
			    
			    # Stop monitoring the read_handle and close the serverSocket 
			    # (the Java end will close the client socket that Java opened)
			    $read_set->remove($rh);     #$read_set->remove($serverSocket);
			    close($rh); 	        #close($serverSocket);
			    print $client "Perl terminated wget and is about to exit\n";
			    last;                           # out of inner for loop
			}
			else { # the process may just be starting up, wait
			    sleep(1);
			}
		    }
		    last;                               # out of foreach loop
		}
	    }
	}
    }

    if ($changed_dir) {
	chdir $current_dir;
    }
    
    return $strReadIn;
}


sub useWgetMonitored
{
    #local $| = 1; # autoflush stdout buffer
    #print STDOUT "*** Start of subroutine useWgetMonitored in $0\n";

    my ($self, $cmdWget,$blnShow, $working_dir) = @_;


    my $current_dir = cwd();
    my $changed_dir = 0;
    if (defined $working_dir && -e $working_dir) {
	chdir "$working_dir";
	$changed_dir = 1;
    }

    # When we are running this script through GLI, the SIGTERM signal handler 
    # won't get called on Windows when wget is to be prematurely terminated. 
    # Instead, when wget has to be terminated in the middle of execution, GLI will
    # connect to a serverSocket here to communicate when it's time to stop wget.
    if($self->dealingWithSockets()) {

	$port = <STDIN>; # gets a port on localhost that's not yet in use
	chomp($port);
	
	$serverSocket = IO::Socket::INET->new( Proto     => 'tcp',
					       LocalPort => $port,
					       Listen    => 1,
					       Reuse     => 1);
    
	die "can't setup server" unless $serverSocket;
	#print STDOUT "[Serversocket $0 accepting clients at port $port]\n";

	$read_set = new IO::Select();         # create handle set for reading
	$read_set->add($serverSocket);        # add the main socket to the set
    }

    my $wget_file_path = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "wget");
    # compose the command as an array for open3, to preserve spaces in any filepath
    # Do so by removing leading and trailing spaces, then splitting on "words" (preserving spaces in quoted words and removing quotes)
    $cmdWget =~ s/^\s+//;
    $cmdWget =~ s/\s+$//;
    my @commandargs = quotewords('\s+', 0, $cmdWget);
    unshift(@commandargs, $wget_file_path); # prepend wget cmd to the command array 
    #print STDOUT "Command is: ".join(",", @commandargs) . "\n";

    eval {     # see p.568 of Perl Cookbook
	#$childpid = open3($chld_in, $chld_out, $chld_out, @commandargs);
	($childpid, $chld_in, $chld_out) = _open3(@commandargs);
    };
    if ($@) {
	if($@ =~ m/^open3/) {
	    die "open3 failed in $0: $!\n$@\n";	    
	}
	die "Tried to launch open3 in $0, got unexpected exception: $@";
    }

    my $full_text = "";
    my $error_text = "";
    my @follow_list = ();
    my $line;

    # create the select object and add our streamhandle(s)
    my $sel = new IO::Select;
    $sel->add($chld_out);
    
    my $num_consecutive_timedouts = 0;
    my $error = 0;
    my $loop = 1;
    while($loop)
    {
	# assume we're going to timeout trying to read from child process
	$num_consecutive_timedouts++;

	# block until data is available on the registered filehandles or until the timeout specified	
	if(my @readyhandles = $sel->can_read($TIMEOUT)) {
	    $num_consecutive_timedouts = 0; # re-zero, as we didn't timeout reading from child process after all
	    # since we're in this if statement
	    
	    foreach my $fh (@readyhandles) {
		my $len = sysread($fh, $line, 4096); # read up to 4k from current ready filehandle
		if($len) { # read something
		
		    
		    if((defined $blnShow) && $blnShow)
		    {
			print STDERR "$line";
		    }
		    
		    if ($line =~ m/^Location:\s*(.*?)\s*\[following\]\s*$/i) {
			my $follow_url = $1;
			push(@follow_list,$follow_url);
		    }
		    
		    if ($line =~ m/ERROR\s+\d+/) {
			$error_text .= $line;
		    }
		    
		    $full_text .= $line;
		} else { # error or EOF
		    if(!defined $len) { # error reading
			#print STDERR "WgetDownload: Error reading from child stream: $!\n";
			$error = 1;
		    }
			 if(!defined $len) {
			  if(!$!{ECONNRESET}) { # anything other ECONNRESET error means it's a real case of undefined $len being an error
				#print STDERR "WgetDownload: Error reading from child stream: $!\n";				
				$error = 1;
			  } else { # the error code is ECONNRESET, and it's not an error, despite $len being undefined. 
				       # Happens on Windows when using sockets to a child process' iostreams
				#print STDERR "WgetDownload: wget finished\n";
			  }
		    }
		    elsif ($len == 0) { # EOF, finished with this filehandle because 0 bytes read
			#print STDERR "WgetDownload: wget finished\n"; # wget terminated naturally
		    }

		    $loop = 0; # error or EOF, either way will need to clean up and break out of outer loop
		    
		    # last; # if we have more than one filehandle registered with IO::Select
		    
		    $sel->remove($fh); # if more than one filehandle registered, we should unregister all of them here on error		    
		} # end else error or EOF
		
	    } # end foreach on readyhandles
	}  # end if on can_read

	if($num_consecutive_timedouts >= $NUM_TRIES) {
	    $error = 1;
	    $loop = 0;                          # to break out of outer while loop

	    $num_consecutive_timedouts = 0;

	    #&gsprintf::gsprintf(STDERR, "{WgetDownload.wget_timed_out_warning}\n", $NUM_TRIES);
	}

	if($loop == 0) { # error or EOF, either way, clean up
	    
	    if($error) {
		$self->{'forced_quit'} = 1;         # subclasses need to know we're quitting
		
		if(kill(0, $childpid)) {
		    # If kill(0, $childpid) returns true, then the process is running
		    # and we need to kill it.
		    close($chld_in);
		    close($chld_out);
		    kill("TERM", $childpid); # prefix - to signal to kill process group
		    
		    #print STDERR "Perl terminated wget after timing out repeatedly and is about to exit\n";
		}
	    }
	    else { # wget finished, terminate naturally
		close($chld_in);
		close($chld_out);
		# Program terminates only when the following line is included 
		# http://perldoc.perl.org/IPC/Open2.html explains why this is necessary
		# it prevents the child from turning into a "zombie process".
		# While the wget process terminates without it, this perl script does not: 
		# the DOS prompt is not returned without it.
		waitpid $childpid, 0;
	    }
	    
	    # error or not:
	    $childpid = undef;	    
	    if(defined $port) {
		$read_set->remove($serverSocket);
		close($serverSocket);
	    }
	}
	
	# If we've already terminated, either naturally or on error, we can get out of the while loop
	next if($loop == 0);

	# Otherwise check for whether Java GLI has attempted to connect to this perl script via socket
	
	# if we run this script from the command-line (as opposed to from GLI), 
	# then we're not working with sockets and can therefore skip the next bits
	next unless(defined $port);

	# http://www.perlfect.com/articles/select.shtml
	# "multiplex between several filehandles within a single thread of control, 
	# thus creating the effect of parallelism in the handling of I/O."
	my @rh_set = $read_set->can_read(0.002); # every 2 ms check if there's a client socket connecting

	# take all readable handles in turn
	foreach my $rh (@rh_set) {
	    if($rh == $serverSocket) {
		my $client = $rh->accept();
		#$client->autoflush(1); # autoflush output buffer - don't put this back in: splits output irregularly over multilines
		print $client "Talked to ServerSocket (port $port). Connection accepted\n";
		
		# Read from the client (getting rid of trailing newline)
		# Has the client sent the <<STOP>> signal?
		my $signal = <$client>;
		chomp($signal); 
		if($signal eq "<<STOP>>") {
		    print $client "Perl received STOP signal (on port $port): stopping wget\n";
		    $loop = 0;                          # out of outer while loop
		    $self->{'forced_quit'} = 1;         # subclasses need to know we're quitting
		    
		    # Sometimes the wget process takes some time to start up. If the STOP signal
		    # was sent, don't try to terminate the process until we know it is running. 
		    # Otherwise wget may start running after we tried to kill it. Wait 5 seconds
		    # for it to start up, checking for whether it is running in order to kill it.
		    for(my $seconds = 1; $seconds <= 5; $seconds++) {
			if(kill(0, $childpid)) {
			    # If kill(0, $childpid) returns true, then the process is running
			    # and we need to kill it.
			    close($chld_in);
			    close($chld_out);
			    kill("TERM", $childpid); # prefix - to signal to kill process group
			    
			    $childpid = undef;
			    
			    # Stop monitoring the read_handle and close the serverSocket 
			    # (the Java end will close the client socket that Java opened)
			    $read_set->remove($rh);     #$read_set->remove($serverSocket);
			    close($rh); 	        #close($serverSocket);
			    print $client "Perl terminated wget and is about to exit\n";
			    last;                           # out of inner for loop
			}
			else { # the process may just be starting up, wait
			    sleep(1);
			}
		    }
		    last;                               # out of foreach loop
		}
	    }
	}
    }

    my $command_status = $?;
    if ($command_status != 0) {
	$error_text .= "Exit error: $command_status";
    }

    if ($changed_dir) {
	chdir $current_dir;
    }
    
    my $final_follow = pop(@follow_list); # might be undefined, but that's OK
    
    return ($full_text,$error_text,$final_follow);
}


# TODO: Check if the URL is valid?? Not sure what should be in this function yet!!
sub checkURL
{
    my ($self) = @_;
    if ($self->{'url'} eq "")
    {
	&error("checkURL","no URL is specified!! Please specifies the URL for downloading.");
    }
}

sub error
{
    my ($strFunctionName,$strError) = @_;
    {
	print "Error occoured in WgetDownload.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}

1;

