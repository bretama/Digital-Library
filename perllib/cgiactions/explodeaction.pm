###########################################################################
#
# explodeaction.pm -- 
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

package explodeaction;

use strict;

use cgiactions::baseaction;

use dbutil;
use ghtml;
use util;
use FileUtils;

use JSON;

use File::Basename;

BEGIN {
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
    require XML::Rules;
}


@explodeaction::ISA = ('baseaction');


# 'a' for action, and 'c' for collection are also compulsorary, and
# added in automatically by baseaction

my $action_table =
{ 
    "explode-document"          => { 'compulsory-args' => ["d"],
			    'optional-args'   => [] },
	"delete-document"           => { 'compulsory-args' => ["d"],
			    'optional-args'   => [ "onlyadd" ] },
	"delete-document-array"     => { 'compulsory-args' => ["json"],
			    'optional-args'   => [ "onlyadd" ] }
				
				
};


sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}


sub get_infodb_type
{
    my ($opt_site,$collect_home,$collect) = @_;

    my $out = "STDERR";

    $collect = &colcfg::use_collection($opt_site, $collect, $collect_home);

    if ($collect eq "") {
	print STDERR "Error: failed to find collection $collect in $collect_home\n";
	print STDOUT "Content-type:text/plain\n\n";
	print STDOUT "ERROR: Failed to find collection $collect\n";
	exit 0;
	
    }

    # Read in the collection configuration file.
    my $gs_mode = "gs2";
    if ((defined $site) && ($site ne "")) { # GS3
	$gs_mode = "gs3";
    }
    my $config_filename = &colcfg::get_collect_cfg_name($out, $gs_mode);
    my $collectcfg = &colcfg::read_collection_cfg ($config_filename, $gs_mode);

    return $collectcfg->{'infodbtype'};
}


sub docid_to_import_filenames
{
    my $self = shift @_;

    my @docids = @_;

	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $infodb_type = $self->{'infodbtype'};

    # Derive the archives dir    
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");
    ##my $archive_dir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"archives");

    my $arcinfo_doc_filename 
	= &dbutil::get_infodb_file_path($infodb_type, "archiveinf-doc", 
					$archive_dir);

    my %all_import_file_keys = ();
    
    foreach my $docid (@docids) {
	# Obtain the src and associated files specified docID
	
	my $doc_rec
	    = &dbutil::read_infodb_entry($infodb_type, $arcinfo_doc_filename, 
					 $docid);
	
	my $src_files = $doc_rec->{'src-file'};
	my $assoc_files = $doc_rec->{'assoc-file'};
	
	if (defined $src_files) {
	    foreach my $ifile (@$src_files) {
		$ifile = &util::placeholders_to_abspath($ifile);
		$all_import_file_keys{$ifile} = 1;
	    }
	}

	if (defined $assoc_files) {
	    foreach my $ifile (@$assoc_files) {
		$ifile = &util::placeholders_to_abspath($ifile);
		$all_import_file_keys{$ifile} = 1;
	    }
	}
    }

    my @all_import_files = keys %all_import_file_keys;

    return \@all_import_files;
}


sub import_filenames_to_docids
{
    my $self = shift @_;
    my ($import_filenames) = @_;

	my $collect   = $self->{'collect'};   
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $infodb_type = $self->{'infodbtype'};

    # Derive the archives dir    
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");
    ##my $archive_dir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"archives");

    # Obtain the oids for the specified import filenames
    my $arcinfo_src_filename 
	= &dbutil::get_infodb_file_path($infodb_type, "archiveinf-src", 
				 	$archive_dir);

    my %all_oid_keys = ();

    foreach my $ifile (@$import_filenames) {
	$ifile = &util::upgrade_if_dos_filename($ifile);
	$ifile = &util::abspath_to_placeholders($ifile);

	print STDERR "*** looking up import filename key \"$ifile\"\n";
	
	my $src_rec
	    = &dbutil::read_infodb_entry($infodb_type, $arcinfo_src_filename, 
					 $ifile);

	my $oids = $src_rec->{'oid'};

	foreach my $o (@$oids) {
	    $all_oid_keys{$o} = 1;
	}
    }

    my @all_oids = keys %all_oid_keys;

    return \@all_oids;
}


sub remove_import_filenames
{
    my $self = shift @_;
    my ($expanded_import_filenames) = @_;

    foreach my $f (@$expanded_import_filenames) {
	# If this document has been exploded before then
	# its original source files will have already been removed	
	if (-e $f) {
	    &FileUtils::removeFiles($f);
	}
    }
}

sub move_docoids_to_import
{
    my $self = shift @_;
    my ($docids) = @_;

	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $infodb_type = $self->{'infodbtype'};

    # Derive the archives and import directories
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
    my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");
    my $import_dir  = &FileUtils::filenameConcatenate($collect_dir,$collect,"import");

    # Obtain the doc.xml path for the specified docID
    my $arcinfo_doc_filename 
	= &dbutil::get_infodb_file_path($infodb_type, "archiveinf-doc", 
				 	$archive_dir);

    foreach my $docid (@$docids) {

	my $doc_rec
	    = &dbutil::read_infodb_entry($infodb_type, $arcinfo_doc_filename, 
					 $docid);

	my $doc_xml_file = $doc_rec->{'doc-file'}->[0];

	# The $doc_xml_file is relative to the archives, so need to do
	# a bit more work to make sure the right folder containing this
	# is moved to the right place in the import folder

	my $assoc_path = dirname($doc_xml_file);
	my $import_assoc_dir = &FileUtils::filenameConcatenate($import_dir,$assoc_path);
	my $archive_assoc_dir = &FileUtils::filenameConcatenate($archive_dir,$assoc_path);

	# If assoc_path involves more than one sub directory, then need to make
	# sure the necessary directories exist in the import area also.
	# For example, if assoc_path is "a/b/c.dir" then need "import/a/b" to
	# exists before moving "archives/a/b/c.dir" -> "import/a/b"
	my $import_target_parent_dir = dirname($import_assoc_dir);

	if (-d $import_assoc_dir) {
	    # detected version from previous explode => remove it
	    &FileUtils::removeFilesRecursive($import_assoc_dir);
	}
	else {
	    # First time => make sure parent directory exists to move 
	    # "c.dir" (see above) into
	    
	    &FileUtils::makeAllDirectories($import_target_parent_dir);
	}

	&FileUtils::copyFilesRecursive($archive_assoc_dir,$import_target_parent_dir)
    }
}


sub remove_docoids
{
    my $self = shift @_;
    my ($docids) = @_;

	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $infodb_type = $self->{'infodbtype'};

    # Derive the archives and import directories
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
    my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");

    # Obtain the doc.xml path for the specified docID
    my $arcinfo_doc_filename 
	= &dbutil::get_infodb_file_path($infodb_type, "archiveinf-doc", 
				 	$archive_dir);

    foreach my $docid (@$docids) {

		my $doc_rec
			= &dbutil::read_infodb_entry($infodb_type, $arcinfo_doc_filename, 
					 $docid);

		my $doc_xml_file = $doc_rec->{'doc-file'}->[0];

		# The $doc_xml_file is relative to the archives, so need to do
		# a bit more work to make sure the right folder containing this
		# is moved to the right place in the import folder

		my $assoc_path = dirname($doc_xml_file);
		my $archive_assoc_dir = &FileUtils::filenameConcatenate($archive_dir,$assoc_path);

		&FileUtils::removeFilesRecursive($archive_assoc_dir)
    }
}


sub explode_document 
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
	
    # Derive the archives dir    
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
	my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");
    ##my $archive_dir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"archives");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

    # look up additional args
    my $docid  = $self->{'d'};
    if ((!defined $docid) || ($docid =~ m/^\s*$/)) {
	$self->unlock_collection($username, $collect);
	$gsdl_cgi->generate_error("No docid (d=...) specified.");
    }

    my ($docid_root,$docid_secnum) = ($docid =~ m/^(.*?)(\..*)?$/);

    my $orig_import_filenames = $self->docid_to_import_filenames($docid_root);
    my $docid_keys = $self->import_filenames_to_docids($orig_import_filenames);
    my $expanded_import_filenames = $self->docid_to_import_filenames(@$docid_keys);

    $self->remove_import_filenames($expanded_import_filenames);
    $self->move_docoids_to_import($docid_keys);

    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

    my $mess = "Base Doc ID: $docid_root\n-----\n";
    $mess .= join("\n",@$expanded_import_filenames);

    $gsdl_cgi->generate_ok_message($mess);

}


sub delete_document_entry
{
	my $self = shift @_;
	my ($docid_root,$opt_onlyadd) = @_;
	
	my $docid_keys = [];
	if ((defined $opt_onlyadd) && ($opt_onlyadd==1)) {
		# delete docoid archive folder
		push(@$docid_keys,$docid_root);
	}
	else {
		print STDERR "**** Not currently implemented for the general case!!\nDeleting 'archive' version only.";
		
		push(@$docid_keys,$docid_root);
		
		#my $orig_import_filenames = $self->docid_to_import_filenames($docid_root);
		#$docid_keys = $self->import_filenames_to_docids($orig_import_filenames);
		#my $expanded_import_filenames = $self->docid_to_import_filenames(@$docid_keys);
		
		# need to remove only the files that are not 
		
		#$self->remove_import_filenames($expanded_import_filenames);
	}
   
	$self->remove_docoids($docid_keys);
}
	

sub delete_document
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
	
    # Derive the archives dir    
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
	my $archive_dir = &FileUtils::filenameConcatenate($collect_dir,$collect,"archives");
    ##my $archive_dir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"archives");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

    # look up additional args
    my $docid  = $self->{'d'};
    if ((!defined $docid) || ($docid =~ m/^\s*$/)) {
	$self->unlock_collection($username, $collect);
	$gsdl_cgi->generate_error("No docid (d=...) specified.");
    }

    my ($docid_root,$docid_secnum) = ($docid =~ m/^(.*?)(\..*)?$/);

	my $onlyadd = $self->{'onlyadd'};

	my $status = $self->delete_document_entry($docid_root,$onlyadd);	

    # Release the lock once it is done
    $self->unlock_collection($username, $collect);

	my $mess = "delete-document successful: Key[$docid_root]\n";
    $gsdl_cgi->generate_ok_message($mess);

}


sub delete_document_array
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdlhome  = $self->{'gsdlhome'};

    if ($baseaction::authentication_enabled) {
	# Ensure the user is allowed to edit this collection
	&authenticate_user($gsdl_cgi, $username, $collect);
    }

	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
    $gsdl_cgi->checked_chdir($collect_dir);

    # Obtain the collect dir
    ## my $collect_dir = &FileUtils::filenameConcatenate($gsdlhome, "collect");

    # Make sure the collection isn't locked by someone else
    $self->lock_collection($username, $collect);

    # look up additional args
	
	my $json_str      = $self->{'json'};
	my $doc_array = decode_json $json_str;

	my $onlyadd = $self->{'onlyadd'};
	
	
	my $global_status = 0;
	my $global_mess = "";
	
	my @all_docids = ();
	
	foreach my $doc_array_rec ( @$doc_array ) {
		
		my $docid     = $doc_array_rec->{'docid'};
		
		push(@all_docids,$docid);
		
		my ($docid_root,$docid_secnum) = ($docid =~ m/^(.*?)(\..*)?$/);
		  
		my $status = $self->delete_document_entry($docid_root,$onlyadd);	
		
		if ($status != 0) {
			# Catch error if set infodb entry failed
			$global_status = $status;
			$global_mess .= "Failed to delete document key: $docid\n";
			$global_mess .= "Exit status: $status\n";
			$global_mess .= "System Error Message: $!\n";
			$global_mess .= "-" x 20;
		}
	}

	if ($global_status != 0) {
		$global_mess .= "PATH: $ENV{'PATH'}\n";
		$gsdl_cgi->generate_error($global_mess);
    }
    else {
		my $mess = "delete-document-array successful: Keys[ ".join(", ",@all_docids)."]\n";
		$gsdl_cgi->generate_ok_message($mess);
    }
    
    # Release the lock once it is done
    $self->unlock_collection($username, $collect);
}



1;
