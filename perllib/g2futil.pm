package g2futil;


BEGIN 
{
    if (!defined $ENV{'FEDORA_HOME'}) {
	print STDERR "Error: Environment variable FEDORA_HOME not set.\n";
	exit 1;
    }

    my $fedora_client_bin = &FileUtils::filenameConcatenate($ENV{'FEDORA_HOME'},"client","bin");
    &util::envvar_append("PATH",$fedora_client_bin);
}

use strict;
use util;
use FileUtils;

sub run_cmd_old
{
    my ($cmd,$verbosity,$tolerate_error) = @_;

    if (($verbosity == 0) 
	|| (defined $tolerate_error && ($tolerate_error eq "tolerate_error"))) {
	if($ENV{'GSDLOS'} =~ /^windows$/i) {
	    $cmd .= " > nul";
	} else {
	    $cmd .= " > /dev/null";
	}
    }
    
    if ($verbosity >= 2) {
	print "Running command:\n";
	print "$cmd\n";
    }

    my $status = system($cmd);

    if ($verbosity >= 2) {
	print "Exit status = ", $status/256, "\n";
    }

    if ((!defined $tolerate_error) || ($tolerate_error ne "tolerate_error")) {
	if ($status>0) {
	    print STDERR "Error executing:\n$cmd\n";
	    print STDERR "$!\n";
	}
    }

    return $status;
}


sub run_cmd
{
    my ($prog,$arguments,$verbosity,$tolerate_error) = @_;

    my $cmd_status = undef;

    my $script_ext = ($ENV{'GSDLOS'} =~ m/^windows/) ? ".bat" : ".sh";

    if ($prog =~ m/^fedora-/ || $prog =~ m/^run[A-Z]*Client/) { # fedora or fedoragsearch script
	$prog .= $script_ext;
    }
    if (($prog =~ m/.pl$/i) && ($ENV{'GSDLOS'} =~ m/^windows/)) {
	$prog ="\"".&util::get_perl_exec()."\" -S $prog";
    }
 
    my $cmd = "$prog $arguments";

###    print "*** cmd = $cmd\n";

    if (open(CMD,"$cmd 2>&1 |"))
    {
	my $result = "";
	my $line;
	while (defined ($line = <CMD>))
	{	
	    $result .= $line;	    

	    if ((!defined $tolerate_error) || ($tolerate_error ne "tolerate_error"))
	    {
		print $line;
	    }


	}
	
	close(CMD);
	
	$cmd_status = $?;

	if ($cmd_status == 0) {
	    # Check for any lines in result begining 'Error:'
	    
	    if ($result =~ m/^Error\s*:/m) {
		# Fedora script generated an error, but did not exit
		# with an error status => artificially raise one

		$cmd_status = -1;
	    }
	}

	if ($cmd_status != 0) {

	    if ((!defined $tolerate_error) || ($tolerate_error ne "tolerate_error"))
	    {
		print STDERR "Error: processing command failed.  Exit status $cmd_status\n";
		
		if ($verbosity >= 2) {
		    print STDERR "  Command was: $cmd\n";
		}
		if ($verbosity >= 3) {
		    print STDERR "result: $result\n";
		}

	    }
	}
    }
    else 
    {
	print STDERR "Error: failed to execute $cmd\n";
    }


    return $cmd_status;
}


sub run_datastore_info
{
    my ($pid,$options) = @_;

    my $verbosity = $options->{'verbosity'};

    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $username = $options->{'username'};
    my $password = $options->{'password'};
    my $protocol = $options->{'protocol'};

    my $prog = "fedora-dsinfo";
    my $arguments = "$hostname $port $username $password $pid $protocol";
    my $status = run_cmd($prog,$arguments,$verbosity,"tolerate_error");

    return $status;
}

sub run_purge
{
    my ($pid,$options) = @_;

    my $verbosity = $options->{'verbosity'};

    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $username = $options->{'username'};
    my $password = $options->{'password'};
    my $protocol = $options->{'protocol'};

    my $server = "$hostname:$port";

    my $prog = "fedora-purge";
    my $arguments = "$server $username $password $pid $protocol";
    $arguments .= " \\\n \"Automated_purge_by_g2f_script\"";

    my $status = run_cmd($prog,$arguments,$verbosity);

    return $status;
}

# runs fedora gsearch's runRESTClient.sh: updateIndex deletePID <PID>
sub run_delete_from_index
{
    my ($fedoragsearch_webapp,$pid,$options) = @_;

    my $verbosity = $options->{'verbosity'};

    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $username = $options->{'username'};
    my $password = $options->{'password'};
    my $protocol = $options->{'protocol'};

    my $server = "$hostname:$port";
    #$ENV{'fgsUserName'} = $options->{'username'};
    #$ENV{'fgsPassword'} = $options->{'password'};    

    #my $prog = &FileUtils::filenameConcatenate($ENV{'FEDORA_GSEARCH'}, "runRESTClient.sh");
    my $prog = &FileUtils::filenameConcatenate($fedoragsearch_webapp, "client", "runRESTClient.sh");

    my $gsearch_commands = "updateIndex deletePid"; # deletePID
    my $arguments = "$server $gsearch_commands $pid";    

    my $status = run_cmd($prog,$arguments,$verbosity);

    return $status;
}

# runs fedora gsearch's runRESTClient.sh: updateIndex fromPID <PID>
sub run_update_index
{
    my ($fedoragsearch_webapp,$pid,$options) = @_;

    my $verbosity = $options->{'verbosity'};

    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $username = $options->{'username'};
    my $password = $options->{'password'};
    my $protocol = $options->{'protocol'};

    my $server = "$hostname:$port";
    #$ENV{'fgsUserName'} = $options->{'username'};
    #$ENV{'fgsPassword'} = $options->{'password'};    

    #my $prog = &FileUtils::filenameConcatenate($ENV{'FEDORA_GSEARCH'}, "runRESTClient.sh");
    my $prog = &FileUtils::filenameConcatenate($fedoragsearch_webapp, "client", "runRESTClient.sh");
    
    my $gsearch_commands = "updateIndex fromPid"; # fromPID
    my $arguments = "$server $gsearch_commands $pid";    

    my $status = run_cmd($prog,$arguments,$verbosity);

    return $status;
}

sub gsearch_webapp_folder
{   
    my $fedoragsearch_webapp = undef;
    
    # if GS3, first look for a fedoragsearch webapp installed in Greenstone's tomcat
    if(defined $ENV{'GSDL3SRCHOME'}) {
	$fedoragsearch_webapp = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'},"packages","tomcat","webapps","fedoragsearch");	
	return $fedoragsearch_webapp if (&FileUtils::directoryExists($fedoragsearch_webapp));
    }

    # next look for a fedoragsearch webapp installed in Fedora's tomcat
    if(defined $ENV{'FEDORA_HOME'}) {
	$fedoragsearch_webapp =  &FileUtils::filenameConcatenate($ENV{'FEDORA_HOME'},"tomcat","webapps","fedoragsearch");
	return $fedoragsearch_webapp if (&FileUtils::directoryExists($fedoragsearch_webapp));
    }

    ## check for a user-defined $ENV{'FEDORA_GSEARCH'} variable first, which points to a gsearch webapp folder??

    # assume no fedoragsearch
    return $fedoragsearch_webapp; # undef
}


sub run_ingest
{
    my ($docmets_filename,$options) = @_;

    my $verbosity = $options->{'verbosity'};

    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $username = $options->{'username'};
    my $password = $options->{'password'};
    my $protocol = $options->{'protocol'};

    my $server = "$hostname:$port";

    my $prog = "fedora-ingest";

    my $type = undef;
    
    if ($ENV{'FEDORA_VERSION'} =~ m/^2/) { # checking if major version is 2
    	$type = "metslikefedora1";
    }
    else {
	$type = "info:fedora/fedora-system:METSFedoraExt-1.1";
    }

    my $arguments = "file \"$docmets_filename\" $type $server $username $password $protocol";
    $arguments .= " \\\n \"Automated_purge_by_g2f_script\"";

    my $status = run_cmd($prog,$arguments,$verbosity);

    return $status;
}


sub rec_get_all_hash_dirs
{
    my ($full_dir,$all_dirs) = @_;

    if (opendir(DIR, $full_dir)) {
	my @sub_dirs = grep { ($_ !~ /^\./) && (-d &FileUtils::filenameConcatenate($full_dir,$_)) } readdir(DIR);
	closedir DIR;

	my @hash_dirs = grep { $_ =~ m/\.dir$/ } @sub_dirs;
	my @rec_dirs = grep { $_ !~ m/\.dir$/ } @sub_dirs;
	
	foreach my $hd (@hash_dirs) {
	    my $full_hash_dir = &FileUtils::filenameConcatenate($full_dir,$hd);
	    push(@$all_dirs,$full_hash_dir);
	}

	foreach my $rd (@rec_dirs) {
	    my $full_rec_dir = &FileUtils::filenameConcatenate($full_dir,$rd);
	    rec_get_all_hash_dirs($full_rec_dir,$all_dirs);
	}	    
    }
}

sub get_all_hash_dirs
{
    my ($start_dir,$maxdocs) = @_;
    
    my @all_dirs = ();
    rec_get_all_hash_dirs($start_dir,\@all_dirs);

    if ((defined $maxdocs) && ($maxdocs ne "")) {
	my @maxdoc_dirs = ();
	for (my $i=0; $i<$maxdocs; $i++) {
	    push(@maxdoc_dirs,shift(@all_dirs));
	}
	@all_dirs = @maxdoc_dirs;
    }

    return @all_dirs;
}

sub get_hash_id
{
    my ($hash_dir) = @_;

    my $hash_id = undef;

    my $docmets_filename = &FileUtils::filenameConcatenate($hash_dir,"docmets.xml");

    if (open(DIN,"<$docmets_filename"))
    {
	while (defined (my $line = <DIN>))
	{
	    if ($line =~ m/<dc:identifier>(.*?)<\/dc:identifier>/)
	    {
		$hash_id = $1;
		last;
	    }
	}
    
	close(DIN);
    }
    else
    {
	print STDERR "Warning: Unable to open \"$docmets_filename\"\n";
    }

    return $hash_id;

}


# Subroutine to write the gsdl.xml file in FEDORA_HOME/tomcat/conf/Catalina/<host/localhost>/
# This xml file will tell Fedora where to find the parent folder of the GS collect dir
# so that it can obtain the FedoraMETS files for ingestion. 
# It depends on the Fedora server being on the same machine as the Greenstone server that 
# this code is part of.
sub write_gsdl_xml_file
{
    my ($fedora_host, $collect_dir, $options) = @_;
    my $verbosity = $options->{'verbosity'};
    my $hostname = $options->{'hostname'};
    my $port     = $options->{'port'};
    my $protocol = $options->{'protocol'};

    print STDERR "Ensuring that a correct gsdl.xml file exists on the Fedora server end\n";
    # The top of this file has already made sure that FEDORA_HOME is set, but for GS3
    # CATALINA_HOME is set to GS' own tomcat. Since we'll be working with fedora, we need
    # to temporarily set CATALINA_HOME to fedora's tomcat. (Catalina is undefined for GS2.)
    my $gs_catalina_home = $ENV{'CATALINA_HOME'} if defined $ENV{'CATALINA_HOME'};
    $ENV{'CATALINA_HOME'} = &FileUtils::filenameConcatenate($ENV{'FEDORA_HOME'}, "tomcat");
    
    # 1. Find out which folder to write to: fedora_host or localhost 
    # whichever contains fedora.xml is the one we want (if none, exit with error value?)
    my $fedora_home = $ENV{'FEDORA_HOME'};
    my $base_path = &FileUtils::filenameConcatenate($fedora_home, "tomcat", "conf", "Catalina");

    my $host_path = &FileUtils::filenameConcatenate($base_path, $fedora_host);
    my $xmlFile = &FileUtils::filenameConcatenate($host_path, "fedora.xml");
    if (!-e $xmlFile) {
	# check if the folder localhost contains fedoraXML
	$host_path = &FileUtils::filenameConcatenate($base_path, "localhost");
	$xmlFile = &FileUtils::filenameConcatenate($host_path, "fedora.xml");
	if(!-e $xmlFile) {
	    # try putting gsdl in this folder, but still print a warning
	    print STDERR "$host_path does not contain file fedora.xml. Hoping gsdl.xml belongs there anyway\n";
	}
    }

    # 2. Construct the string we are going write to the gsdl.xml file
    # a. get the parent directory of collect_dir by removinbg the word 
    # "collect" from it and any optional OS-type slash at the end. 
    # (Path slash direction does not matter here.)
    my $collectParentDir = $collect_dir;
    $collectParentDir =~ s/collect(\/|\\)?//;
  
    # b. Use the collectParentDir to create the contents of gsdl.xml
    my $greenstone_url_prefix = &util::get_greenstone_url_prefix(); # would have the required slash at front
    my $gsdlXMLcontents = "<?xml version='1.0' encoding='utf-8'?>\n<Context docBase=\"";
    $gsdlXMLcontents = $gsdlXMLcontents.$collectParentDir."\" path=\"$greenstone_url_prefix\"></Context>";
    
    # 3. If there is already a gsdl.xml file in host_path, compare the string we
    # want to write with what is already in there. If they're the same, we can return
    $xmlFile = &FileUtils::filenameConcatenate($host_path, "gsdl.xml");
    if(-e $xmlFile) {
	# such a file exists, so read the contents
	unless(open(FIN, "<$xmlFile")) { 
	    print STDERR "g2f-import.pl: Unable to open existing $xmlFile for comparing...Recoverable. $!\n";
	    # doesn't matter, we'll just overwrite it then
	}    
	my $xml_contents;
	{
	    local $/ = undef;        # Read entire file at once
	    $xml_contents = <FIN>;   # Now file is read in as one single 'line'
	}
	close(FIN); # close the file
	if($xml_contents eq $gsdlXMLcontents) { 
	    print STDERR "Fedora links to the FLI import folder through gsdl.xml.\n";
	    # it already contains what we want, we're done
	    return "gsdl.xml";
	}
    }

    # 4. If we're here, the contents of gsdl.xml need to be updated:
    # a. First stop the fedora server
    my $script_ext = ($ENV{'GSDLOS'} =~ m/^windows/) ? ".bat" : ".sh";
    my $stop_tomcat = &FileUtils::filenameConcatenate($fedora_home, "tomcat", "bin", "shutdown".$script_ext);
    # execute the command 
    $! = 0; # does this initialise the return value?
    my $status = system($stop_tomcat);
    if ($status!=0) { # to get the actual exit value, divide by 256, but not useful here
	# possible tomcat was already stopped - it's not the end of the world
	print STDERR "Failed to stop Fedora server. Perhaps it was not running. $!\n";
	print "Exit status = ", $status/256, "\n";
    }

    # b. overwrite the file that has outdated contents with the contents we just constructed
    unless(open(FOUT, ">$xmlFile")) {  # create or overwrite gsdl.xml file
	die "g2f-import.pl: Unable to open $xmlFile for telling Fedora where the collect dir is...ERROR: $!\n";
    }
    # write out the updated contents and close the file
    print FOUT $gsdlXMLcontents;
    close(FOUT);

    # c. Restart the fedora server
    my $start_tomcat = &FileUtils::filenameConcatenate($fedora_home, "tomcat", "bin", "startup".$script_ext);
    $! = 0;
    $status = system($start_tomcat);
    if ($status!=0) { 
	print STDERR "Failed to restart the Fedora server... ERROR: $!\n";
	print "Exit status = ", $status/256, "\n";
    }

    # reset CATALINA_HOME to GS' Tomcat (it is undefined for GS2 since GS2 has no tomcat):
    $ENV{'CATALINA_HOME'} = $gs_catalina_home if defined $gs_catalina_home;
    
    # the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
    &util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

    # Starting up the Fedora server takes a long time. We need to wait for the server to be
    # ready before import can continue, because g2f-import relies on an up-and-running Fedora
    # server to purge the collection from it while g2f-build.pl needs a ready Fedora server 
    # in order to make it ingest the FedoraMETS. Sleeping is not sufficient (#sleep 10;) since
    # the subsequent steps depend on a proper server restart.
    # Dr Bainbridge's suggestion: test the server is ready with a call to wget.
    
    # Wget tries to retrieve the fedora search page (protocol://host:port/fedora/search)
    # 20 times, waiting 3 seconds between each failed attempt. If it ultimately fails, we
    # print a message to the user.
    # The wget --spider option makes it check that the page is merely there rather than 
    # downloading it (see http://www.gnu.org/software/wget/manual/wget.html#Download-Options)
    # -q is for quiet, --tries for the number of retries, --waitretry is the number of seconds
    # between each attempt. Usually wget returns the contents of the page, but in our case it
    # will return 0 for success since we are not downloading.

    print STDERR "Fedora server restarted. Waiting for it to become ready...\n";
    #print STDERR "****$protocol://$hostname:$port/fedora/search\n";
    $! = 0;
    #my $fedoraServerReady = system("wget -q --spider --waitretry=10 --tries=20 $protocol://$hostname:$port/fedora/search");

    # The retries above won't work if the server isn't running: 
    # http://www.gnu.org/software/wget/manual/wget.html
    #'--tries=number'
    # Set number of retries to number. Specify 0 or 'inf' for infinite retrying. The default is to retry 20 times, 
    # with the exception of fatal errors like "connection refused" or "not found" (404), which ARE NOT RETRIED.

    # retry fedora server every second for a total of 20 times until the server is ready
    my $fedoraServerReady = 0;
    my $count = 0;
    do {
	$fedoraServerReady = system("wget -q --spider $protocol://$hostname:$port/fedora/search");
	if($fedoraServerReady != 0) {
	    sleep(1);
	    $count++;
	    #print STDERR "$count second(s)\n";
	}
    } while($fedoraServerReady != 0 && $count < 20);

    if($fedoraServerReady != 0) {
	print STDERR "Fedora server is still not ready... ERROR: $!\n";
	print "Exit status = ", $fedoraServerReady/256, "\n";
	die "Exiting....\n";
    }

    # return some indication that things went well
    return "gsdl.xml";
}


1;
