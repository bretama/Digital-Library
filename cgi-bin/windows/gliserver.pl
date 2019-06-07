#!C:\Users\brhane\Greenstone\bin\windows\perl\bin\perl.exe -w
# Need to specify the full path of Perl above

# This file merges Michael Dewsnip's gliserver.pl for GS2 and Quan Qiu's gliserver4gs3.pl (GS3)

use strict;
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

BEGIN {

    # Line to stop annoying child DOS CMD windows from appearing
    Win32::SetChildShowWindow(0) 
	if defined &Win32::SetChildShowWindow;

}


# Set this to 1 to work around IIS 6 craziness
my $iis6_mode = 0;

##
# IIS 6: for some reason, IIS runs this script with the working directory set to the Greenstone
#   directory rather than the cgi-bin directory, causing lots of stuff to fail
if ($iis6_mode)
{
    # Change into cgi-bin\<OS> directory - need to ensure it exists, since gliserver deals with both GS2 and GS3
    if(-e "cgi-bin" && -d "cgi-bin") { # GS2
	chdir("cgi-bin");
	if(defined $ENV{'GSDLARCH'}) {
	    chdir($ENV{'GSDLOS'}.$ENV{'GSDLARCH'});
	} else {
	    chdir($ENV{'GSDLOS'});
	}
    } else { # iis6_mode is not applicable for Greenstone 3
	$iis6_mode = 0;
    }
}


# We use require and an eval here (instead of "use package") to catch any errors loading the module (for IIS)
eval("require \"gsdlCGI.pm\"");
if ($@)
{
    print STDOUT "Content-type:text/plain\n\n";
    print STDOUT "ERROR: $@\n";
    exit 0;
}


#my $authentication_enabled = 0;
my $debugging_enabled = 0; # if 1, debugging is enabled and unlinking intermediate files (deleting files) will not happen

my $mail_enabled = 0;
my $mail_to_address = "user\@server";  # Set this appropriately
my $mail_from_address = "user\@server";  # Set this appropriately
my $mail_smtp_server = "smtp.server";  # Set this appropriately

sub main
{	
    my $gsdl_cgi = new gsdlCGI();

    # Load the Greenstone modules that we need to use
    $gsdl_cgi->setup_gsdl();
    my $gsdlhome = $ENV{'GSDLHOME'};

    $gsdl_cgi->checked_chdir($gsdlhome);

    # Encrypt the password
    $gsdl_cgi->encrypt_password();

    $gsdl_cgi->parse_cgi_args();

    # We don't want the gsdlCGI module to return errors and warnings in XML
    $gsdl_cgi->{'xml'} = 0;

    # Retrieve the (required) command CGI argument
    my $cmd = $gsdl_cgi->clean_param("cmd");
    if (!defined $cmd) {
	$gsdl_cgi->generate_error("No command specified.");
    }
    $gsdl_cgi->delete("cmd");

    # The check-installation, greenstone-server-version and get-library-url commands have no arguments
    if ($cmd eq "check-installation") {
	&check_installation($gsdl_cgi);
	return;
    }
    elsif ($cmd eq "greenstone-server-version") {
	&greenstone_server_version($gsdl_cgi);
	return;
    }
    elsif ($cmd eq "get-library-url-suffix") {
	&get_library_url_suffix($gsdl_cgi);
	return;
    }

    # All other commands require a username, for locking and authentication
    my $username = $gsdl_cgi->clean_param("un");
    if ((!defined $username) || ($username =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No username specified.");
    }
    $gsdl_cgi->delete("un");

    # Get then remove the ts (timestamp) argument (since this can mess up other scripts)
    my $timestamp = $gsdl_cgi->clean_param("ts");
    if ((!defined $timestamp) || ($timestamp =~ m/^\s*$/)) {
	$timestamp = time();  # Fall back to using the Perl time() function to generate a timestamp
    }
    $gsdl_cgi->delete("ts");

    my $site; # undefined on declaration, see http://perldoc.perl.org/perlsyn.html
    if($gsdl_cgi->greenstone_version() != 2) { # all GS versions after 2 may define site
	$site = $gsdl_cgi->clean_param("site");   
	if (!defined $site) {
	    $gsdl_cgi->generate_error("No site specified.");
	}
	$gsdl_cgi->delete("site");
    }


    if ($cmd eq "delete-collection") {
	&delete_collection($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "download-collection") {
	&download_collection($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "download-collection-archives") {
	&download_collection_archives($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "download-collection-configurations") {
	&download_collection_configurations($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "download-collection-file") {
	&download_collection_file($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "delete-collection-file") {
	&delete_collection_file($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "get-script-options") {
	&get_script_options($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "move-collection-file") {
	&move_collection_file($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "new-collection-directory") {
	&new_collection_directory($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "run-script") {
	&run_script($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "timeout-test") {
	while (1) { }
    }
    elsif ($cmd eq "upload-collection-file") {
	&upload_collection_file($gsdl_cgi, $username, $timestamp, $site);
    }
    elsif ($cmd eq "file-exists") { 
	&file_exists($gsdl_cgi, $site);
    }
    # cmds not in Greenstone 2:
    elsif ($gsdl_cgi->greenstone_version() != 2) { 	
	if ($cmd eq "download-web-xml-file") {
	    &download_web_xml_file($gsdl_cgi, $username, $timestamp, $site);
	} 
	elsif ($cmd eq "user-validation") {
	    &user_validation($gsdl_cgi, $username, $timestamp, $site);
	}
	elsif ($cmd eq "get-site-names") {
	    &get_site_names($gsdl_cgi, $username, $timestamp, $site);
	}
    }
    else {
	$gsdl_cgi->generate_error("Unrecognised command: '$cmd'");
    }
        
}


sub authenticate_user
{
    my $gsdl_cgi = shift(@_);
    my $username = shift(@_);
    my $collection = shift(@_);
    my $site = shift(@_);

    # Even if we're not authenticating remove the un and pw arguments, since these can mess up other scripts
    my $user_password = $gsdl_cgi->clean_param("pw");
    $gsdl_cgi->delete("pw");

    # Only authenticate if it is enabled
    # return "all-collections-editor" if (!$authentication_enabled);

    if ((!defined $user_password) || ($user_password =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("Authentication failed: no password specified.");
    }

    if($gsdl_cgi->greenstone_version() == 2) {
	my $users_db_content;
	my $etc_directory = &util::filename_cat($ENV{'GSDLHOME'}, "etc");
	my $users_db_file_path = &util::filename_cat($etc_directory, "users.gdb");
	
	# Use db2txt instead of GDBM_File to get the user accounts information
	$users_db_content = "";
	open(USERS_DB, "db2txt \"$users_db_file_path\" |");
	while (<USERS_DB>) {
	    $users_db_content .= $_;
	}
	close(USERS_DB);
    
    # Get the user account information from the usersDB database
    my %users_db_data = ();

    # a line dividing one user entry from another is made up of 70 hyphens for GS2 (37 hyphens for GS3)
    my $horizontal_divider = q/-{70}/;
    foreach my $users_db_entry (split($horizontal_divider, $users_db_content)) {	
	if ($users_db_entry =~ m/\n?\[(.+)\]\n/ || $users_db_entry =~ m/\n?USERNAME = ([^\n]*)\n/) { # GS2 and GS3 formats
	    $users_db_data{$1} = $users_db_entry;
	}
    }

    # Check username
    my $user_data = $users_db_data{$username};
    if (!defined $user_data) {
	$gsdl_cgi->generate_error("Authentication failed: no account for user '$username'.");
    }

    # Check password
    my $pwdLine = q/\<password\>(.*)/;
    my ($valid_user_password) = ($user_data =~ m/$pwdLine/);
    if ($user_password ne $valid_user_password) {
	$gsdl_cgi->generate_error("Authentication failed: incorrect password.");
    }

    # Check group
    my $groupLine = q/\<groups\>(.*)/;
    my ($user_groups) = ($user_data =~ m/$groupLine/);

    if ($collection eq "") {
	# If we're not editing a collection then the user doesn't need to be in a particular group
	return $user_groups;  # Authentication successful
    }

    foreach my $user_group (split(/\,/, $user_groups)) {
	# Does this user have access to all collections?
	if ($user_group eq "all-collections-editor") {
	    return $user_groups;  # Authentication successful
	}
	# Does this user have access to personal collections, and is this one?
	if ($user_group eq "personal-collections-editor" && $collection =~ m/^$username\-/) {
	    return $user_groups;  # Authentication successful
	}
	# Does this user have access to this collection
	if ($user_group eq "$collection-collection-editor") {
	    return $user_groups;  # Authentication successful
	}
    }
    $gsdl_cgi->generate_error("Authentication failed: user is not in the required group.");
	}
	
	# "GS3\web\WEB-INF\lib\gsdl3.jar;GS3\web\WEB-INF\lib\derby.jar" 
	# org.greenstone.gsdl3.util.usersDBRealm2txt "GSDL3SRCHOME" username pwd <col> 2>&1
	elsif($gsdl_cgi->greenstone_version() == 3) {
		my $gsdl3srchome = $ENV{'GSDL3SRCHOME'};

		my $java = $gsdl_cgi->get_java_path();
		my $java_gsdl3_classpath = &util::filename_cat($gsdl3srchome, "web", "WEB-INF", "lib", "gsdl3.jar");
		my $java_derby_classpath = &util::filename_cat($gsdl3srchome, "web", "WEB-INF", "lib", "derby.jar");
		my $java_classpath;
		my $gsdlos = $ENV{'GSDLOS'};
		if ($gsdlos !~ m/windows/){
			$java_classpath = $java_gsdl3_classpath . ":" . $java_derby_classpath;
		}else{
			$java_classpath = $java_gsdl3_classpath . ";" . $java_derby_classpath;
		}		
		my $java_args = "\"$gsdl3srchome\" \"$username\" \"$user_password\"";
		if ($collection ne "") {
			$java_args += " \"$collection\"";
		}
		
		$gsdl_cgi->checked_chdir($gsdl3srchome);	
		my $java_command="\"$java\" -classpath \"$java_classpath\" org.greenstone.gsdl3.util.ServletRealmCheck $java_args 2>&1"; # call it ServletRealmCheck
		my $java_output = `$java_command`;
		if ($java_output =~ m/^Authentication failed:/) { # $java_output contains the error message
			$gsdl_cgi->generate_error($java_output); # "\nJAVA_COMMAND: $java_command\n"
		}
		else { # success, $java_output is the user_groups list			
			return $java_output; 
		}
    }
}


sub lock_collection
{
    my $gsdl_cgi = shift(@_);
    my $username = shift(@_);
    my $collection = shift(@_);
    my $site = shift(@_);

    my $steal_lock = $gsdl_cgi->clean_param("steal_lock");
    $gsdl_cgi->delete("steal_lock");

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory);

    # Check if a lock file already exists for this collection
    my $lock_file_name = "gli.lck";
    if (-e $lock_file_name) {
	# A lock file already exists... check if it's ours
	my $lock_file_content = "";
	open(LOCK_FILE, "<$lock_file_name");
	while (<LOCK_FILE>) {
	    $lock_file_content .= $_;
	}
	close(LOCK_FILE);

	# Pick out the owner of the lock file
	$lock_file_content =~ m/\<User\>(.*?)\<\/User\>/;
	my $lock_file_owner = $1;

	# The lock file is ours, so there is no problem
	if ($lock_file_owner eq $username) {
	    return;
	}

	# The lock file is not ours, so throw an error unless "steal_lock" is set
	unless (defined $steal_lock) {
	    $gsdl_cgi->generate_error("Collection is locked by: $lock_file_owner");
	}
    }

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
    my $current_time = sprintf("%02d/%02d/%d %02d:%02d:%02d", $mday, $mon + 1, $year + 1900, $hour, $min, $sec);

    # Create a lock file for us (in the same format as the GLI) and we're done
    open(LOCK_FILE, ">$lock_file_name");
    print LOCK_FILE "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print LOCK_FILE "<LockFile>\n";
    print LOCK_FILE "    <User>" . $username . "</User>\n";
    print LOCK_FILE "    <Machine>(Remote)</Machine>\n";
    print LOCK_FILE "    <Date>" . $current_time . "</Date>\n";
    print LOCK_FILE "</LockFile>\n";
    close(LOCK_FILE);
}


# ----------------------------------------------------------------------------------------------------
#   ACTIONS
# ----------------------------------------------------------------------------------------------------
# This routine, which uses the variable site, won't get called by GS2, 
sub user_validation{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;
   
    # Users can be in any group to perform this action
    my $user_err = &authenticate_user($gsdl_cgi, $username, "", $site);
     if (defined $user_err && $user_err!~ m/ERROR/){
	 if ($user_err!~ m/ERROR/){
	     #$gsdl_cgi->generate_error("Authentication failed: $username is not valid");
	     $gsdl_cgi->generate_ok($user_err);
	     #print $user_err;
	 }else{
	     $gsdl_cgi->generate_error($user_err);
	     #print "not valid" . $user_err;
	 }
     }else{
	 $gsdl_cgi->generate_error("Authentication failed: $username is not valid");	 
     }
}

sub check_installation
{
    my ($gsdl_cgi) = @_;

    my $installation_ok = 1;
    my $installation_status = "";

    # Check that Java is installed and accessible
    my $java = $gsdl_cgi->get_java_path();
    my $java_command = "\"$java\" -version 2>&1";
    
    # IIS 6: redirecting output from STDERR to STDOUT just doesn't work, so we have to let it go
    #   directly out to the page
    if($iis6_mode && $gsdl_cgi->greenstone_version() == 2) { ##
	print STDOUT "Content-type:text/plain\n\n";
	$java_command = "\"$java\" -version";
    }

    my $java_output = `$java_command`;
        
    my $java_status = $?;
    if ($java_status < 0) {
	# The Java command failed
	$installation_status = "Java failed -- do you have the Java run-time installed?\n" . $gsdl_cgi->check_java_home() . "\n";
	$installation_ok = 0;
    }
    else {
	$installation_status = "Java found: $java_output";
    }

    # Show the values of some important environment variables
    $installation_status .= "\n";
    if($gsdl_cgi->greenstone_version() != 2) {
	$installation_status .= "GSDL3SRCHOME: " . $ENV{'GSDL3SRCHOME'} . "\n";
	$installation_status .= "GSDL3HOME: " . $ENV{'GSDL3HOME'} . "\n";
    }
    $installation_status .= "GSDLHOME: " . $ENV{'GSDLHOME'} . "\n";
    $installation_status .= "GSDLOS: " . $ENV{'GSDLOS'} . "\n";
    $installation_status .= "JAVA_HOME: " . $ENV{'JAVA_HOME'} . "\n" if defined($ENV{'JAVA_HOME'}); # on GS2, Java's only on the PATH
    $installation_status .= "PATH: " . $ENV{'PATH'} . "\n";
    if(defined $ENV{'FEDORA_VERSION'}) { # not using FLI unless version set
	$installation_status .= "FEDORA_HOME: ".$ENV{'FEDORA_HOME'} . "\n";
	$installation_status .= "FEDORA_VERSION: ".$ENV{'FEDORA_VERSION'};
    }
    
    if ($installation_ok) { ## M. Dewsnip's svn log comment stated that for iis6_mode output needs to go to STDOUT
	if($iis6_mode && $gsdl_cgi->greenstone_version() == 2) {
	    print STDOUT $installation_status . "\nInstallation OK!";
	} else {
	    $gsdl_cgi->generate_ok_message($installation_status . "\nInstallation OK!");
	}
    }
    else {
	if($iis6_mode && $gsdl_cgi->greenstone_version() == 2) {
	    print STDOUT $installation_status;
	} else {
	    $gsdl_cgi->generate_error($installation_status);
	}
    }
}


sub delete_collection
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);


    my $collect_directory = $gsdl_cgi->get_collection_dir($site);
    $gsdl_cgi->checked_chdir($collect_directory);

    # Check that the collection exists
    if (!-d $collection) {
	$gsdl_cgi->generate_error("Collection $collection does not exist.");
    }

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    $gsdl_cgi->checked_chdir($collect_directory);
    $gsdl_cgi->local_rm_r("$collection");

    # Check that the collection was deleted
    if (-e $collection) {
	$gsdl_cgi->generate_error("Could not delete collection $collection.");
    }

    $gsdl_cgi->generate_ok_message("Collection $collection deleted successfully.");
}


sub delete_collection_file
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    my $file = $gsdl_cgi->clean_param("file");
    if ((!defined $file) || ($file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No file specified.");
    }
    $file = $gsdl_cgi->decode($file);
    $file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Make sure we don't try to delete anything outside the collection
    if ($file =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal file specified.");
    }

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    if (!-d $collection_directory){ ## wasn't there in gs2, ok_msg or error_msg?
	$gsdl_cgi->generate_ok_message("Directory $collection_directory does not exist."); 
	die;
    }

    $gsdl_cgi->checked_chdir($collection_directory);

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    # Check that the collection file exists
    if (!-e $file) { ## original didn't have 'die', but it was an ok message
	$gsdl_cgi->generate_ok_message("Collection file $file does not exist.");
	die;
    }
    $gsdl_cgi->local_rm_r("$file");

    # Check that the collection file was deleted
    if (-e $file) {
	$gsdl_cgi->generate_error("Could not delete collection file $file.");
    }

    $gsdl_cgi->generate_ok_message("Collection file $file deleted successfully.");
}


sub download_collection
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS
    
    # language and region Environment Variable setting on the client side that was used to zip files.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collect_directory = $gsdl_cgi->get_collection_dir($site);
    $gsdl_cgi->checked_chdir($collect_directory);

    # Check that the collection exists
    if (!-d $collection) {
	$gsdl_cgi->generate_ok_message("Collection $collection does not exist."); ## original had an error msg (from where it would die)
	die;
    }

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    # Zip up the collection
    my $java = $gsdl_cgi->get_java_path();
    my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
    my $zip_file_path = &util::filename_cat($collect_directory, $collection . "-" . $timestamp . ".zip");
    my $java_args = "\"$zip_file_path\" \"$collect_directory\" \"$collection\"";
    if($gsdl_cgi->greenstone_version() != 2) {
	$java_args .= " gsdl3"; ## must this be done elsewhere as well?
    }

    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipCollectionShell $java_args"; 

    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("Collection zip file $zip_file_path could not be created.");
    }

    &put_file($gsdl_cgi, $zip_file_path, "application/zip"); # file is transferred to client
    unlink("$zip_file_path") unless $debugging_enabled;      # deletes the local intermediate zip file
}


sub download_collection_archives
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # language and region Environment Variable setting on the client side that was used to zip files.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");
   
    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collect_directory = $gsdl_cgi->get_collection_dir($site);
    $gsdl_cgi->checked_chdir($collect_directory);

    # Check that the collection archives exist
    if (!-d &util::filename_cat($collection, "archives")) {
	$gsdl_cgi->generate_error("Collection archives do not exist.");
    }

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    # Zip up the collection archives
    my $java = $gsdl_cgi->get_java_path();
    my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
    my $zip_file_path = &util::filename_cat($collect_directory, $collection . "-archives-" . $timestamp . ".zip");
    my $java_args = "\"$zip_file_path\" \"$collect_directory\" \"$collection\"";
    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipCollectionArchives $java_args"; 

    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("Collection archives zip file $zip_file_path could not be created.");
    }

    &put_file($gsdl_cgi, $zip_file_path, "application/zip");
    unlink("$zip_file_path") unless $debugging_enabled;
}


# Collection locking unnecessary because this action isn't related to a particular collection
sub download_collection_configurations
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    # language and region Environment Variable setting on the client side that was used to zip files.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");
   
    # Users can be in any group to perform this action
    my $user_groups = &authenticate_user($gsdl_cgi, $username, "", $site);

    my $collect_directory = $gsdl_cgi->get_collection_dir($site);
    $gsdl_cgi->checked_chdir($collect_directory);

    # Zip up the collection configurations
    my $java = $gsdl_cgi->get_java_path();
    my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
    my $zip_file_path = &util::filename_cat($collect_directory, "collection-configurations-" . $timestamp . ".zip");
    my $java_args = "\"$zip_file_path\" \"$collect_directory\" \"$username\" \"$user_groups\"";
    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipCollectionConfigurations $java_args"; 
    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("Collection configurations zip file $zip_file_path could not be created.");
    }
    
    &put_file($gsdl_cgi, $zip_file_path, "application/zip");
    unlink("$zip_file_path") unless $debugging_enabled;
}

# Method that will check if the given file exists
# No error message: all messages generated are OK messages
# This method will simply state whether the file exists or does not exist.
sub file_exists
{
    my ($gsdl_cgi, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    my $file = $gsdl_cgi->clean_param("file");
    if ((!defined $file) || ($file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No file specified.");
    }
    $file = "\"$file\"";   # Windows: bookend the relative filepath with quotes in case it contains spaces
    $file = $gsdl_cgi->decode($file);
    $file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Not necessary: checking whether the user is authenticated to query existence of the file
    #&authenticate_user($gsdl_cgi, $username, $collection);

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory); # cd into the directory of that collection

    # Check that the collection file exists
    if (-e $file) {
	$gsdl_cgi->generate_ok_message("File $file exists.");
    } else {
	$gsdl_cgi->generate_ok_message("File $file does not exist.");
    }
}

sub download_collection_file
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    my $collection_tail_name = $collection;
    $collection_tail_name =~ s/^(.*\|)//;
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # language and region Environment Variable setting on the client side that was used to zip files.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");
    my $file = $gsdl_cgi->clean_param("file");
    if ((!defined $file) || ($file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No file specified.");
    }
    $file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Make sure we don't try to download anything outside the collection
    if ($file =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal file specified.");
    }

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory);

    # Check that the collection file exists
    if (!-e $file) {
	$gsdl_cgi->generate_ok_message("Collection file $file does not exist.");
	die;
    }

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    # Zip up the collection file
    my $java = $gsdl_cgi->get_java_path();
    my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
    my $zip_file_path = &util::filename_cat($collection_directory, $collection_tail_name . "-file-" . $timestamp . ".zip");
    my $java_args = "\"$zip_file_path\" \"$collection_directory\" \"$file\" servlets.xml";
    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipFiles $java_args"; 

    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("Collection archives zip file $zip_file_path could not be created.");
    }

    &put_file($gsdl_cgi, $zip_file_path, "application/zip");
    unlink("$zip_file_path") unless $debugging_enabled;
}

# download web.xml from the server
sub download_web_xml_file
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    # Users can be in any group to perform this action
    my $user_groups = &authenticate_user($gsdl_cgi, $username, "", $site);

    # language and region Environment Variable setting on the client side that was used to zip files.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");
    my $file = $gsdl_cgi->clean_param("file");
    if ((!defined $file) || ($file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No file specified.");
    }
    $file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Make sure we don't try to download anything else
    if ($file =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal file specified.");
    }

    my $web_inf_directory = &util::filename_cat($ENV{'GSDL3HOME'}, "WEB-INF");
    $gsdl_cgi->checked_chdir($web_inf_directory);

    # Check that the collection file exists
    if (!-e $file) {
	$gsdl_cgi->generate_error("file $file does not exist.");
    }

    # Zip up the collection file
    my $java = $gsdl_cgi->get_java_path();
    my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
    my $zip_file_path = &util::filename_cat($web_inf_directory, "webxml" . $timestamp . ".zip");
    my $java_args = "\"$zip_file_path\" \"$web_inf_directory\" \"$file\" servlets.xml";
    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipFiles $java_args"; 
    my $java_output = `$java_command`;

    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("web.xml zip file $zip_file_path could not be created.");
    }

    &put_file($gsdl_cgi, $zip_file_path, "application/zip");

    unlink("$zip_file_path") unless $debugging_enabled;
}

# Collection locking unnecessary because this action isn't related to a particular collection
sub get_script_options
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $script = $gsdl_cgi->clean_param("script");
    if ((!defined $script) || ($script =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No script specified.");
    }
    $gsdl_cgi->delete("script");

    # Users can be in any group to perform this action
    &authenticate_user($gsdl_cgi, $username, "", $site);
    $gsdl_cgi->delete("ts"); ## two lines from GS3 version, doesn't seem to harm GS2
    $gsdl_cgi->delete("pw"); 
    

    my $perl_args = "";
    if ($script eq "classinfo.pl") {
	$perl_args = $gsdl_cgi->clean_param("classifier") || "";
	$gsdl_cgi->delete("classifier");
    }
    if ($script eq "pluginfo.pl") {
	$perl_args = $gsdl_cgi->clean_param("plugin") || "";
	$perl_args = "-gs_version ".$gsdl_cgi->greenstone_version()." ".$perl_args;
	$gsdl_cgi->delete("plugin");
    }
    if ($script eq "downloadinfo.pl") {
	$perl_args = $gsdl_cgi->clean_param("downloader") || "";
	$gsdl_cgi->delete("downloader");
    }

    foreach my $cgi_arg_name ($gsdl_cgi->param) {
	my $cgi_arg_value = $gsdl_cgi->clean_param($cgi_arg_name) || "";
	
	# When get_script_options is to launch classinfo.pl or pluginfo.pl, one of the args to be passed to the script
	# is the collection name. This may be a (collectgroup/)coltailname coming in here as (collectgroup|)coltailname.
	# Since calling safe_val() below on the collection name value will get rid of \ and |, but preserves /, need to
	# first replace the | with /, then run safe_val, then convert the / to the OS dependent File separator.
	$cgi_arg_value =~ s@\|@\/@g if ($cgi_arg_name =~ m/^collection/);
	$cgi_arg_value = $gsdl_cgi->safe_val($cgi_arg_value);
	$cgi_arg_value =~ s@\/@&util::get_dirsep()@eg if($cgi_arg_name =~ m/^collection/);
	if ($cgi_arg_value eq "") {
	    $perl_args = "-$cgi_arg_name " . $perl_args;
	}
	else {
	    $perl_args = "-$cgi_arg_name \"$cgi_arg_value\" " . $perl_args;
	}
    }


    # IIS 6: redirecting output from STDERR to STDOUT just doesn't work, so we have to let it go
    #   directly out to the page
    print STDOUT "Content-type:text/plain\n\n";
    my $perl_command;
    if($iis6_mode && $gsdl_cgi->greenstone_version() == 2)
    {
	$perl_command = "perl -S $script $perl_args";
    } else {
	$perl_command = "perl -S $script $perl_args 2>&1";
    }

    my $perl_output = `$perl_command`;
    my $perl_status = $?;
    if ($perl_status > 0) {
	$gsdl_cgi->generate_error("Perl failed: $perl_command\n--\n$perl_output\nExit status: " . ($perl_status / 256));
    }

    if (defined($perl_output))
    {
	print STDOUT $perl_output;
    }
}

# get the names of all sites available on the server
sub get_site_names
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;
    my $sites_directory = &util::filename_cat($ENV{'GSDL3SRCHOME'}, "web", "sites");

    my @sites_dir;
    my @site_dir;
    
    $gsdl_cgi->checked_chdir($sites_directory);
    opendir(DIR, $sites_directory);
    @sites_dir= readdir(DIR);
    my $sites_dir;
    my $sub_dir_file;

    print STDOUT "Content-type:text/plain\n\n";
    foreach $sites_dir(@sites_dir)
    {
	if (!(($sites_dir eq ".") || ($sites_dir eq "..") || ($sites_dir eq "CVS") || ($sites_dir eq ".DS_Store") || ($sites_dir eq "ADDING-A-SITE.txt")))
	{
	    my $site_dir_path= &util::filename_cat($sites_directory,$sites_dir);
	    $gsdl_cgi->checked_chdir($site_dir_path);
	    opendir(DIR,$site_dir_path);
	    @site_dir=readdir(DIR);
	    closedir(DIR);
	    
	    foreach $sub_dir_file(@site_dir)
	    {
		if ($sub_dir_file eq "siteConfig.xml"){
		    print STDOUT "$sites_dir" . "-----";
		}
	    }
	}
    }

}

sub move_collection_file
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    my $source_file = $gsdl_cgi->clean_param("source");
    if ((!defined $source_file) || ($source_file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No source file specified.");
    }
    $source_file = $gsdl_cgi->decode($source_file);
    $source_file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS
    my $target_file = $gsdl_cgi->clean_param("target");
    if ((!defined $target_file) || ($target_file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No target file specified.");
    }
    $target_file = $gsdl_cgi->decode($target_file);
    $target_file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Make sure we don't try to move anything outside the collection
    if ($source_file =~ m/\.\./ || $target_file =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal file specified.");
    }

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory);

    # Check that the collection source file exists
    if (!-e $source_file) {
	$gsdl_cgi->generate_error("Collection file $source_file does not exist.");
    }

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    &util::mv($source_file, $target_file);

    # Check that the collection source file was moved
    if (-e $source_file || !-e $target_file) {
	$gsdl_cgi->generate_error("Could not move collection file $source_file to $target_file."); # dies
    }

    $gsdl_cgi->generate_ok_message("Collection file $source_file moved to $target_file successfully.");
}


sub new_collection_directory
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    my $directory = $gsdl_cgi->clean_param("directory");
    if ((!defined $directory) || ($directory =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No directory specified.");
    }
    $directory =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    # Make sure we don't try to create anything outside the collection
    if ($directory =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal directory specified.");
    }

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory);

    # Check that the collection directory doesn't already exist
    # ZipTools doesn't zip up empty directories, so this causes an error when downloading a new collection as we explicitly
    # try to create the import directory
## log -r13497 for GS2's gliserver.pl, Katherine Don explains:
# "commented out checking for existence of a directory in new_collection_directory 
# as it throws an error which we don't want"
    #if($gsdl_cgi->greenstone_version() != 2 && -d $directory) {
	#$gsdl_cgi->generate_error("Collection directory $directory already exists.");
    #}

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    &util::mk_dir($directory);

    # Check that the collection directory was created
    if (!-d $directory) {
	$gsdl_cgi->generate_error("Could not create collection directory $directory.");
    }

    $gsdl_cgi->generate_ok_message("Collection directory $directory created successfully.");
}


sub run_script
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;

    my $script = $gsdl_cgi->clean_param("script");
    if ((!defined $script) || ($script =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No script specified.");
    }
    $gsdl_cgi->delete("script");
 
    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS
    $gsdl_cgi->delete("c");

    # confuse other, so delete timestamp
    $gsdl_cgi->delete("ts");

    # Ensure the user is allowed to edit this collection
    &authenticate_user($gsdl_cgi, $username, $collection, $site);

    # Make sure the collection isn't locked by someone else (unless we're running mkcol.pl, of course)
    &lock_collection($gsdl_cgi, $username, $collection, $site) unless ($script eq "mkcol.pl");

    # Last argument is the collection name, except for explode_metadata_database.pl and
    # replace_srcdoc_with_html (where there's a "file" option followed by the filename. These two preceed the collection name)
    my $perl_args = $collection;
    if ($script eq "explode_metadata_database.pl" || $script eq "replace_srcdoc_with_html.pl") {
	# Last argument is the file to be exploded or it is the file to be replaced with its html version
	my $file = $gsdl_cgi->clean_param("file");
	if ((!defined $file) || ($file =~ m/^\s*$/)) {
	    $gsdl_cgi->generate_error("No file specified.");
	}
	$gsdl_cgi->delete("file");	
	$file = $gsdl_cgi->decode($file);
	$file = "\"$file\""; # Windows: bookend the relative filepath with quotes in case it contains spaces 
	$file =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS
	$perl_args = $file;
    }

    foreach my $cgi_arg_name ($gsdl_cgi->param) {
	my $cgi_arg_value = $gsdl_cgi->safe_val($gsdl_cgi->clean_param($cgi_arg_name));
	if ($cgi_arg_value eq "") {
	    $perl_args = "-$cgi_arg_name " . $perl_args;
	}
	else {
	    $perl_args = "-$cgi_arg_name \"$cgi_arg_value\" " . $perl_args;
	}
    }

    # mkcol.pl and import.pl, buildcol.pl, g2f-import.pl, g2f-buildcol.pl all need the -collectdir option passed
    my $import_pl = "import.pl"; # import is a reserved word, need to put it in quotes
    
    if (($script =~ m/$import_pl|buildcol.pl/) || ($script eq "mkcol.pl") || ($script eq "activate.pl")) { # || ($script eq "schedule.pl")
	my $collect_directory = $gsdl_cgi->get_collection_dir($site);	
	$perl_args = "-collectdir \"$collect_directory\" " . $perl_args;

	if($gsdl_cgi->greenstone_version() == 3) {
	    $perl_args = "-site $site $perl_args";
	}
    }

    my $perl_command = "perl -S $script $perl_args 2>&1";
    # IIS 6: redirecting output from STDERR to STDOUT just doesn't work, so we have to let it go
    #   directly out to the page
    if($gsdl_cgi->greenstone_version() == 2 && $iis6_mode)
    {
	$perl_command = "perl -S $script $perl_args";
    }
    if (!open(PIN, "$perl_command |")) {
	$gsdl_cgi->generate_error("Unable to execute command: $perl_command");
    }

    print STDOUT "Content-type:text/plain\n\n";
    print "$perl_command  \n";

    while (defined (my $perl_output_line = <PIN>)) {
	print STDOUT $perl_output_line;
    }
    close(PIN);

    my $perl_status = $?;
    if ($perl_status > 0) {
	$gsdl_cgi->generate_error("Perl failed: $perl_command\n--\nExit status: " . ($perl_status / 256));
    }
    elsif ($mail_enabled) {
	if ($script eq "buildcol.pl") {
	    &send_mail($gsdl_cgi, "Remote Greenstone building event", "Build of collection '$collection' complete.");
	}
    }
}

sub upload_collection_file
{
    my ($gsdl_cgi, $username, $timestamp, $site) = @_;
   
    my $collection = $gsdl_cgi->clean_param("c");
    if ((!defined $collection) || ($collection =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $collection =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS

    my $file = $gsdl_cgi->clean_param("file");
    if ((!defined $file) || ($file =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No file specified.");
    }
    my $directory = $gsdl_cgi->clean_param("directory") || "";
    $directory =~ s/\|/&util::get_dirsep()/eg;  # Convert the '|' characters into whatever is right for this OS
    my $zip = $gsdl_cgi->clean_param("zip");

    # language and region Environment Variable setting on the client side that was used to
    # zip files. This needs to be consistent on both client and server sides, otherwise zip 
    # and unzip seem to produce different values.
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";
    $gsdl_cgi->delete("lr");

    # Make sure we don't try to upload anything outside the collection
    if ($file =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal file specified.");
    }
    if ($directory =~ m/\.\./) {
	$gsdl_cgi->generate_error("Illegal directory specified.");
    }

    # Ensure the user is allowed to edit this collection
    if($gsdl_cgi->greenstone_version() == 2) { ## Quan commented this out for GS3 in r14325
	&authenticate_user($gsdl_cgi, $username, $collection, $site); # site will be undefined for GS2, of course
    }

    my $collection_directory = $gsdl_cgi->get_collection_dir($site, $collection);
    $gsdl_cgi->checked_chdir($collection_directory);

    # Make sure the collection isn't locked by someone else
    &lock_collection($gsdl_cgi, $username, $collection, $site);

    my $directory_path = &util::filename_cat($collection_directory, $directory);
    if (!-d $directory_path) {
	&util::mk_dir($directory_path);
	if (!-d $directory_path) {
	    $gsdl_cgi->generate_error("Could not create directory $directory_path.");
	}
    }

    #my $file_path = &util::filename_cat($directory_path, $file . "-" . $timestamp); 
    my $file_path = "";
    if($gsdl_cgi->greenstone_version() == 2) {
	$file_path = &util::filename_cat($directory_path, $file . "-" . $timestamp); 
    } else {
	$file_path = &util::filename_cat($directory_path, $file); 
    }
   
    if (!open(FOUT, ">$file_path")) {
	print STDERR "Unable to write file $file_path\n";
	$gsdl_cgi->generate_error("Unable to write file $file_path");
    }

    # Read the uploaded data and write it out to file
    my $buf;
    my $num_bytes = 0;
    binmode(FOUT);
    if($gsdl_cgi->greenstone_version() == 2) { ##
	# We have to pass the size of the uploaded data in the "fs" argument because IIS 6 seems to be
	#   completely incapable of working this out otherwise (causing the old code to crash)
	my $num_bytes_remaining = $gsdl_cgi->clean_param("fs");
	my $bytes_to_read = $num_bytes_remaining;
	if ($bytes_to_read > 1024) { $bytes_to_read = 1024; }

	while (read(STDIN, $buf, $bytes_to_read) > 0) {
	    print FOUT $buf;
	    $num_bytes += length($buf);
	    $num_bytes_remaining -= length($buf);
	    $bytes_to_read = $num_bytes_remaining;
	    if ($bytes_to_read > 1024) { $bytes_to_read = 1024; }
	}
    } else { # GS3 and later
    	my $bread;
	my $fh = $gsdl_cgi->clean_param("uploaded_file");

	if (!defined $fh) {
	    print STDERR "ERROR. Filehandle undefined. No file uploaded onto GS3 server.\n";
	    $gsdl_cgi->generate_error("ERROR. Filehandle undefined. No file uploaded (GS3 server).");
	} else {
	    while ($bread=read($fh, $buf, 1024)) {
		print FOUT $buf;
	    }
	}
    }
    close(FOUT);
       
    # If we have downloaded a zip file, unzip it
    if (defined $zip) {
	my $java = $gsdl_cgi->get_java_path();
	my $java_classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "GLIServer.jar");
	my $java_args = "\"$file_path\" \"$directory_path\"";
	$ENV{'LANG'} = $lang_env;
	my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.Unzip $java_args"; 
	my $java_output = `$java_command`;
	my $java_status = $?;

	# Remove the zip file once we have unzipped it, since it is an intermediate file only
	unlink("$file_path") unless $debugging_enabled;
	
	if ($java_status > 0) {
	    $gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home()); # dies
	}
    }

    $gsdl_cgi->generate_ok_message("Collection file $file uploaded successfully.");
}

sub put_file
{
    my $gsdl_cgi = shift(@_);
    my $file_path = shift(@_);
    my $content_type = shift(@_);

    if(!defined $content_type) { ##
	$content_type = "application/zip";
    }
	
    if (open(PIN, "<$file_path")) {
	print STDOUT "Content-type:$content_type\n\n"; ## For GS3: "Content-type:application/zip\n\n";
 	my $buf;
 	my $num_bytes = 0;
 	binmode(PIN);
 	while (read(PIN, $buf, 1024) > 0) {
 	    print STDOUT $buf;
 	    $num_bytes += length($buf);
 	}

 	close(PIN);
    }
    else {
	$gsdl_cgi->generate_error("Unable to read file $file_path\n  $!");
    }
}

sub send_mail
{
    my $gsdl_cgi = shift(@_);
    my $mail_subject = shift(@_);
    my $mail_content = shift(@_);

    my $sendmail_command = "perl -S sendmail.pl";
    $sendmail_command .= " -to \"" . $mail_to_address . "\"";
    $sendmail_command .= " -from \"" . $mail_from_address . "\"";
    $sendmail_command .= " -smtp \"" . $mail_smtp_server . "\"";
    $sendmail_command .= " -subject \"" . $mail_subject . "\"";

    if (!open(POUT, "| $sendmail_command")) {
	$gsdl_cgi->generate_error("Unable to execute command: $sendmail_command");
    }
    print POUT $mail_content . "\n";
    close(POUT);
}

sub greenstone_server_version
{	
    my $gsdl_cgi = shift(@_);
    my $version = $gsdl_cgi->greenstone_version();
    $gsdl_cgi->generate_ok_message("Greenstone server version is: $version\n");
}

sub get_library_url_suffix
{
    my $gsdl_cgi = shift(@_);
    my $library_url = $gsdl_cgi->library_url_suffix();
    $gsdl_cgi->generate_ok_message("Greenstone library URL suffix is: $library_url\n");
}

&main();
