###########################################################################
#
# buildaction.pm -- 
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

package buildaction;

use strict;

use JSON;

use cgiactions::baseaction;

use dbutil;
use ghtml;

use util;
use FileUtils;

BEGIN {
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
    require XML::Rules;
}


@buildaction::ISA = ('baseaction');


# 'a' for action, and 'c' for collection are also compulsorary, and
# added in automatically by baseaction

my $action_table =
{ 
    "full-import"          => { 'compulsory-args' => [],
				'optional-args'   => [] }, 
    
    "full-buildcol"        => { 'compulsory-args' => [],
				'optional-args'   => [] },
    
    "full-rebuild"         => { 'compulsory-args' => [],
				'optional-args'   => [] },
    
    
    "incremental-import"   => { 'compulsory-args' => [],
				'optional-args'   => [] }, 

    "incremental-buildcol" => { 'compulsory-args' => [],
				'optional-args'   => [] },
    
    "incremental-rebuild" => { 'compulsory-args' => [],
			       'optional-args'   => [] },
				   
    "build-by-manifest" => { 'compulsory-args' => [],
			       'optional-args'   => ["index-files", "reindex-files", "delete-OIDs"] }
				   
};


sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}


sub run_build_cmd
{
    my $self = shift @_;
    my ($cmd) = @_;

    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    my $output = `$cmd 2>&1`;
    my $status = $?;
    my $report = undef;

    if ($status == 0) {
	$report = "Perl build successful: $cmd\n--\n";
	$report .= "$output\n";
    }
    else {
	$report = "Perl rebuild failed: $cmd\n--\n";
	$report .= "$output\n";
	$report .= "Exit status: " . ($status / 256) . "\n";
##	$report .= $gsdl_cgi->check_perl_home();

#	$report .= "PATH = ". $ENV{'PATH'}. "\n";
    }

    return($status,$report);
}

sub full_import
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
	
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S full-import.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }

}


sub full_buildcol
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
    
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S full-buildcol.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
}


sub full_rebuild
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
	
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);
	
    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S full-rebuild.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
}



sub incremental_import
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
	
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);


    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S incremental-import.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
}


sub incremental_buildcol
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
    
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);


    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S incremental-buildcol.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
}


sub incremental_rebuild
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
	
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);


    my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
    my $cmd = "\"".&util::get_perl_exec()."\" -S incremental-rebuild.pl \"$collect\"";

    my ($status,$report) = $self->run_build_cmd($cmd);
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
}

sub build_by_manifest
{
	my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdl_home  = $self->{'gsdlhome'};

    # Authenticate user if it is enabled
    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }
	
    # Obtain the collect dir
    my $collect_dir = &FileUtils::filenameConcatenate($gsdl_home, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

	my $if_json_str   = $self->{'index-files'};
	my $rf_json_str   = $self->{'reindex-files'};
	my $df_json_str   = $self->{'delete-OIDs'};
	
		
	my $index_files   = (defined $if_json_str) ? decode_json $if_json_str : [];
	my $reindex_files = (defined $rf_json_str) ? decode_json $rf_json_str : [];
	my $delete_files  = (defined $df_json_str) ? decode_json $df_json_str : [];
	
	my $index_files_xml   = join("\n", map { "    <Filename>$_</Filename>" } @$index_files);
	my $reindex_files_xml = join("\n", map { "    <Filename>$_</Filename>" } @$reindex_files);
	my $delete_files_xml  = join("\n", map { "    <OID>$_</OID>" } @$delete_files);
	
	my $manifest_filename = &util::get_tmp_filename(".xml");
	my ($status,$report);
			
	if (open(MOUT,">$manifest_filename")) {
		binmode(MOUT,":utf8");
		print MOUT <<MOUTRAW;
<Manifest>
  <Index>
$index_files_xml
  </Index>
  <Reindex>
$reindex_files_xml
  </Reindex>
  <Delete>
$delete_files_xml
  </Delete>
</Manifest>
MOUTRAW
		close(MOUT);
		
		## my $bin_script = &FileUtils::filenameConcatenate($gsdl_home,"bin","script");
		my $cmd = "\"".&util::get_perl_exec()."\" -S incremental-rebuild.pl -manifest \"$manifest_filename\" \"$collect\"";

		($status,$report) = $self->run_build_cmd($cmd);
		
		if ($status==0) {
			&FileUtils::removeFiles($manifest_filename);
		}
	}
	else {
		$status = -1;
		$report = "Failed to open '$manifest_filename' for output\n$!\n";
	}
	
   
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    if ($status==0) {
	$gsdl_cgi->generate_ok_message($report);
    }
    else {
	$gsdl_cgi->generate_error($report);
    }
	
	# incremental-rebuild.pl -manifest manifest.xml \"" + _greenstoneCollectionName  + "\"";
 }



1;
