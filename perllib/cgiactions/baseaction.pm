###########################################################################
#
# baseaction.pm -- 
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009 New Zealand Digital Library Project
#
# This program is free software; you can redistr   te it and/or modify
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


package baseaction;

use strict;
use util;
use inexport;

# for time conversion and formatting functions
use Time::Local;
use POSIX;

our $authentication_enabled = 1; # debugging flag (can debug without authentication when set to 0)
our $mail_enabled = 0;


# change this to get these values from a config file
my $mail_to_address = "user\@server";  # Set this appropriately
my $mail_from_address = "user\@server";  # Set this appropriately
my $mail_smtp_server = "smtp.server";  # Set this appropriately



# Required CGI arguments: "a" for action
#                         "c" for collection
# Optional CGI arguemnts: "ts" for timestamp (auto generated is missing)
#                         "site" (used by Greenstone3)

# allow "un" for username to be optional for now

sub new 
{
    my $class = shift (@_);
    my ($action_table,$gsdl_cgi,$iis6_mode) = @_;

    my $self = { 'gsdl_cgi' => $gsdl_cgi, 
		 'iis6_mode' => $iis6_mode,
		 'gsdlhome' => $ENV{'GSDLHOME'} };

    # Retrieve the (required) command CGI argument
    my $action = $gsdl_cgi->clean_param("a");

    if (!defined $action) {
	my $err_mess = "No action (a=...) specified.\n";
	$err_mess .= "\nPossible actions are:\n";

	$err_mess .= "  check-installation\n\n";

	foreach my $a (sort keys %$action_table) {
	    $err_mess .= "  $a:\n";
	    $err_mess .= "    Compulsory args: ";
	    my @comp_args = ("c");
	    push(@comp_args,"un") if ($authentication_enabled);
	    push(@comp_args,@{$action_table->{$a}->{'compulsory-args'}});
	    $err_mess .= join(", ", @comp_args);

	    $err_mess .= "\n";

	    my @opt_args = ();
	    push(@opt_args,"un") if (!$authentication_enabled);
	    push(@opt_args,@{$action_table->{$a}->{'optional-args'}});

	    if (scalar(@opt_args)>0) {

		$err_mess .= "    Optional args  : ";
		$err_mess .= join(", ", @opt_args);
		$err_mess .= "\n";
	    }

	    my @help_examples = ();
	    if(defined $action_table->{$a}->{'help-string'}) {
		push(@help_examples, @{$action_table->{$a}->{'help-string'}});
	    }
	    if (scalar(@help_examples)>0) {

		if (scalar(@help_examples)>1) {
		    $err_mess .= "    Example(s)  :\n";
		} else {
		    $err_mess .= "    Example  :\n";
		}
		$err_mess .= join(", \n\n", @help_examples);
		$err_mess .= "\n\nTo be strictly CGI-compliant special chars like double-quotes,&,?,<,> must be URL encoded.\n";
	    }

	    $err_mess .= "\n";
	}

	$gsdl_cgi->generate_message($err_mess);
	exit(-1);
	    
    }
    $gsdl_cgi->delete("a");

	$self = bless $self, $class;

    # The check-installation command has no arguments
    if ($action eq "check-installation") {
	$self->check_installation($gsdl_cgi,$iis6_mode);
	exit 0;
    }

	
    if (!defined $action_table->{$action}) {
	my $valid_actions = join(", ", keys %$action_table);

	my $err_mess = "Unrecognised action (a=$action) specified.\n";
	$err_mess .= "Valid actions are: $valid_actions\n";

	$gsdl_cgi->generate_error($err_mess);		
    }

    
    my $collect = $gsdl_cgi->clean_param("c");
    if ((!defined $collect) || ($collect =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No collection specified.");
    }
    $gsdl_cgi->delete("c");

    # allow un to be optional for now
    my $username = $gsdl_cgi->clean_param("un");


    # Get then remove the ts (timestamp) argument (since this can mess up 
    #  other scripts)
    my $timestamp = $gsdl_cgi->clean_param("ts");
    if ((!defined $timestamp) || ($timestamp =~ m/^\s*$/)) {
	# Fall back to using the Perl time() function to generate a timestamp
	$timestamp = time();  
    }
    $gsdl_cgi->delete("ts");

    my $site = undef; 
    if($gsdl_cgi->greenstone_version() != 2) { 
	# all GS versions after 2 may define site
	$site = $gsdl_cgi->clean_param("site");   
	if (!defined $site) {
	    $gsdl_cgi->generate_error("No site specified.");
	}
	$gsdl_cgi->delete("site");
    }
    

    $self->{'action'} = $action;
    $self->{'collect'} = $collect;
    $self->{'username'} = $username;
    $self->{'timestamp'} = $timestamp;
    $self->{'site'} = $site;
	  
    # Locate and store compulsory arguments
    my $comp_args = $action_table->{$action}->{'compulsory-args'};
    foreach my $ca (@$comp_args) {
	if (!defined $gsdl_cgi->param($ca)) {
	    $gsdl_cgi->generate_error("Compulsory argument '$ca' missing");
	}
	else {
	    $self->{$ca} = $gsdl_cgi->clean_param($ca);
	    $gsdl_cgi->delete($ca);
	}
    }

    # Locate and store optional args if present
    my $opt_args = $action_table->{$action}->{'optional-args'};
    foreach my $oa (@$opt_args) {
	if (defined $gsdl_cgi->param($oa)) {
	    $self->{$oa} = $gsdl_cgi->clean_param($oa);
	    $gsdl_cgi->delete($oa);
	}
    }

	
	
    # Retrieve infodb-type
    if (defined $collect) {
	
	my $opt_site = $self->{'site'} || "";
	
	my $inexport = newCGI inexport(ref $self,$collect,$gsdl_cgi,$opt_site);
	my ($config_filename,$collect_cfg) = $inexport->read_collection_cfg($collect);   
	$self->{'infodbtype'} = $collect_cfg->{'infodbtype'};

    }
    
	
    return $self;
}


sub do_action
{
    my $self = shift @_;
    my $action = $self->{'action'};

    $action =~ s/-/_/g;

    
    $self->$action();

}


sub authenticate_user
{
    my $self = shift @_;

    my $gsdl_cgi = $self->{'gsdl_cgi'};

    # For now, we don't authenticate for GS3 as this still needs to be implemented for it.
    if($gsdl_cgi->greenstone_version() == 3) { 
	#$gsdl_cgi->generate_message("**** To do: still need to authenticate for GS3.");
	return;
    }   

    my $username = shift(@_);
    my $collection = shift(@_);

    my $keydecay = 1800; # 30 mins same as in runtime-src/recpt/authentication.cpp


    # Remove the pw argument (since this can mess up other scripts)
    my $user_password = $gsdl_cgi->clean_param("pw");
    my $user_key = $gsdl_cgi->clean_param("ky");

    $gsdl_cgi->delete("pw");
    $gsdl_cgi->delete("ky");

    if ((!defined $user_password || $user_password =~ m/^\s*$/) && (!defined $user_key || $user_key =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("Authentication failed: no password or key specified.");
    }

    my $gsdlhome = $ENV{'GSDLHOME'};
    my $etc_directory = &util::filename_cat($gsdlhome, "etc");
    my $users_db_file_path = &util::filename_cat($etc_directory, "users.gdb");

    # Use dbutil to get the user accounts information
    # infodbtype can be different for different collections, but the userDB and keyDB are gdbm

    my $user_rec = &dbutil::read_infodb_entry("gdbm", $users_db_file_path, $username);
    # Check username
    if (!defined $user_rec) {
	$gsdl_cgi->generate_error("Authentication failed: no account for user '$username'.");
    }
    
    # Check password
    if(defined $user_password) {
	my $valid_user_password = $user_rec->{"password"}->[0];
	if ($user_password ne $valid_user_password) {
	    $gsdl_cgi->generate_error("Authentication failed: incorrect password.");
	}
    } 
    else { # check $user_key #if(!defined $user_password && defined $user_key) {
	
	# check to see if there is a key for this particular user in the database that hasn't decayed.
	# if the key validates, refresh the key again by setting its timestamp to the present time.

	# Use dbutil to get the key accounts information
	my $key_db_file_path = &util::filename_cat($etc_directory, "key.gdb");
	my $key_rec = &dbutil::read_infodb_entry("gdbm", $key_db_file_path, $user_key);

	if (!defined $key_rec) {
	    
	    #$gsdl_cgi->generate_error("Authentication failed: invalid key $user_key. Does not exist.");
	    $gsdl_cgi->generate_error("Authentication failed: invalid key. No entry for the given key.");
	}
	else {
	    my $valid_username = $key_rec->{"user"}->[0];
	    if ($username ne $valid_username) {
		$gsdl_cgi->generate_error("Authentication failed: key does not belong to user.");
	    }
	    
	    # http://stackoverflow.com/questions/12644322/how-to-write-the-current-timestamp-in-a-file-perl
	    # http://stackoverflow.com/questions/2149532/how-can-i-format-a-timestamp-in-perl
	    # http://stackoverflow.com/questions/7726514/how-to-convert-text-date-to-timestamp
	    
	    my $current_timestamp = time; #localtime(time);
	    
	    my $keycreation_time = $key_rec->{"time"}->[0]; # of the form: 2013/05/06 14:39:23
	    if ($keycreation_time !~ m/^\s*$/) { # not empty
		
		my ($year,$mon,$mday,$hour,$min,$sec) = split(/[\s\/:]+/, $keycreation_time); # split by space, /, :
		                   # (also ensures whitespace surrounding keycreateion_time is trimmed)
		my $key_timestamp = timelocal($sec,$min,$hour,$mday,$mon-1,$year);
		
		if(($current_timestamp - $key_timestamp) > $keydecay) {
		    $gsdl_cgi->generate_error("Authentication failed: key has expired.");
		} else {
		    # succeeded, update the key's time in the database
		    
		    # beware http://community.activestate.com/forum/posixstrftime-problem-e-numeric-day-month
		    my $current_time = strftime("%Y/%m/%d %H:%M:%S", localtime($current_timestamp)); # POSIX
		    
		    # infodbtype can be different for different collections, but the key DB is gdbm
		    my $key_rec = &dbutil::read_infodb_entry("gdbm", $key_db_file_path, $user_key);
		    $key_rec->{"time"}->[0] = $current_time;
		    my $status = &dbutil::set_infodb_entry("gdbm", $key_db_file_path, $user_key, $key_rec);
		    
		    if ($status != 0) {
			$gsdl_cgi->generate_error("Error updating authentication key.");
		    }
		}
	    } else {
		$gsdl_cgi->generate_error("Authentication failed: Invalid key entry. No time stored for key.");
	    }	    
	}
    }

    # The following code which tests whether the user is in the required group 
    # seems to have been copied over from gliserver.pl.
    # But when user comments are added through the set-metadata functions for metadata-server.pl
    # (which is the first feature for which baseaction::authenticate_user() is actually used)
    # the user doesn't need to be a specific collection's editor in order to add comments to that collection.
    # So we no longer check the user is in the group here.
#    $self->check_group($collection, $username, $user_data);
}


sub check_group
{
    my $self = shift @_;
    my $collection = shift @_;
    my $username = shift @_;
    my $user_data = shift @_;


    my $gsdl_cgi = $self->{'gsdl_cgi'};

    # Check group
    my ($user_groups) = ($user_data =~ /\<groups\>(.*)/);
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
	if ($user_group eq "personal-collections-editor" && $collection =~ /^$username\-/) {
	    return $user_groups;  # Authentication successful
	}
	# Does this user have access to this collection
	if ($user_group eq "$collection-collection-editor") {
	    return $user_groups;  # Authentication successful
	}
    }
    
    $gsdl_cgi->generate_error("Authentication failed: user is not in the required group.");
}

sub check_installation
{
    my $self = shift @_;
    my $iis6_mode = shift(@_);

    my $gsdl_cgi = $self->{'gsdl_cgi'};

    my $installation_ok = 1;
    my $installation_status = "";

    print STDOUT "Content-type:text/plain\n\n";

    # Check that Java is installed and accessible
    my $java = $gsdl_cgi->get_java_path();
    my $java_command = "$java -version 2>&1";

    # IIS 6: redirecting output from STDERR to STDOUT just doesn't work, so we have to let it go
    #   directly out to the page
    if ($iis6_mode)
    {
	$java_command = "java -version";
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
    $installation_status .= "GSDLHOME: " . $ENV{'GSDLHOME'} . "\n";
    $installation_status .= "GSDLOS: " . $ENV{'GSDLOS'} . "\n";
    $installation_status .= "PATH: " . $ENV{'PATH'} . "\n";

    if ($installation_ok) {
	print STDOUT $installation_status . "\nInstallation OK!";
    }
    else {
	print STDOUT $installation_status;
    }
}

sub lock_collection
{
    my $self = shift @_;
    my $username = shift(@_);
    my $collection = shift(@_);

    my $gsdl_cgi = $self->{'gsdl_cgi'};

    my $steal_lock = $gsdl_cgi->clean_param("steal_lock");
    $gsdl_cgi->delete("steal_lock");

    if (!defined $username) {
	# don't have any user details for current user to compare with
	# even if there is a lock file
	# For now, allow the current user access.  Might want to
	# revisit this in the future.
	return;
    }

    #my $gsdlhome = $ENV{'GSDLHOME'};
    #my $collection_directory = &util::filename_cat($gsdlhome, "collect", $collection);
    my $site = $self->{'site'};
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
	$lock_file_content =~ /\<User\>(.*?)\<\/User\>/;
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


# Release the gli.lck otherwise no one else will be able to use the collection again.
sub unlock_collection
{
    my $self = shift @_;
    my ($username, $collection) = @_;
    my $gsdl_cgi = $self->{'gsdl_cgi'};

    # Obtain the path to the collection GLI lock file
    my $lock_file_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "gli.lck");

    # If the lock file does exist, check if it is ours
    if (-e $lock_file_path)
    {
	my $lock_file_content = "";
	open(LOCK_FILE, "<$lock_file_path");
	while (<LOCK_FILE>) {
	    $lock_file_content .= $_;
	}
	close(LOCK_FILE);

	# Pick out the owner of the lock file
	$lock_file_content =~ /\<User\>(.*?)\<\/User\>/;
	my $lock_file_owner = $1;

	# If we are the owner of this lock, we have the right to delete it
	if ($lock_file_owner eq $username) {
            unlink($lock_file_path );
	}
        else {
	    $gsdl_cgi->generate_error("Collection is locked by: $lock_file_owner. Cannot be unlocked");
        }
    }
}


sub send_mail
{
    my $self = shift @_;

    my ($mail_subject,$mail_content) = @_;

    my $gsdl_cgi = $self->{'gsdl_cgi'};

    my $sendmail_command = "\"".&util::get_perl_exec()."\" -S sendmail.pl";
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


sub run_script
{
    my $self = shift @_;

    my ($collect, $site, $script) = @_;

    my $gsdl_cgi = $self->{'gsdl_cgi'};

    my $perl_args = $collect;

    my $collect_dir = $gsdl_cgi->get_collection_dir($site); 
    $perl_args = "-collectdir \"$collect_dir\" " . $perl_args;

    my $perl_command = "\"".&util::get_perl_exec()."\" -S $script $perl_args";


    # IIS 6: redirecting output from STDERR to STDOUT just doesn't work, so
    # we have to let it go directly out to the page

    if (!$self->{'iis6_mode'})
    {
	$perl_command .= " 2>&1";
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
}

1;
