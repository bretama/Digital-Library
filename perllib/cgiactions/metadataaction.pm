##########################################################################
#
# metadataaction.pm -- 
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

package metadataaction;

use strict;

use cgiactions::baseaction;

use dbutil;
use ghtml;

use JSON;

# This class is conditionally expanded with set-metadata, remove-metadata and insert-metadata subroutines
# defined in modmetadataaction.pm. The BEGIN code block determines whether the condition holds.
# See
# http://stackoverflow.com/questions/3998619/what-is-the-role-of-the-begin-block-in-perl
# http://www.perlmonks.org/?node_id=881761 - splitting module into multiple files
# http://www.perlmonks.org/?node_id=524456 - merging hashes

our $modmeta_action_table; # don't init to empty hash here, else it will overwrite whatever BEGIN sets this to
                  # see http://stackoverflow.com/questions/3998619/what-is-the-role-of-the-begin-block-in-perl

BEGIN {
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
    require XML::Rules;

    # if we're GS3, then GS3_AUTHENTICATED must be defined and set to true
    # in order to have access to subroutines that modify metadata (the set- 
    # and remove- metadata subroutines).
    # TODO: if we're GS2, then we continue to behave as before?

    if(!defined $ENV{'GSDL3HOME'} || (defined $ENV{'GS3_AUTHENTICATED'} && $ENV{'GS3_AUTHENTICATED'} eq "true")) {
	require modmetadataaction;
    }
    else {
	$modmeta_action_table = {};
    }
}

@metadataaction::ISA = ('baseaction');


my $getmeta_action_table =
{
	#GET METHODS
	"get-import-metadata" => { 
		'compulsory-args' => [ "d", "metaname" ],
		'optional-args'   => [ "metapos" ] },

	"get-archives-metadata" => { 
		'compulsory-args' => [ "d", "metaname" ],
		'optional-args'   => [ "metapos" ] },
	
	"get-index-metadata" => { 
		'compulsory-args' => [ "d", "metaname" ],
		'optional-args'   => [ "metapos" ] }, 

	"get-metadata" => { # alias for get-index-metadata
	    'compulsory-args' => [ "d", "metaname" ],
	    'optional-args'   => [ "metapos" ] },

	"get-live-metadata" => { 
		'compulsory-args' => [ "d", "metaname" ],
		'optional-args'   => [ ] }, 

	"get-metadata-array" => { # where param can be ONE of: index (default), import, archives, live
	    'compulsory-args' => [ "json" ],
	    'optional-args'   => [ "where" ],
	    'help-string' => [
		'metadata-server.pl?a=get-metadata-array&c=demo&where=index&json=[{"docid":"HASHc5bce2d6d3e5b04e470ec9","metatable":[{"metaname":"username","metapos":"all"},{"metaname":"usertimestamp","metapos":"all"}, {"metaname":"usercomment","metapos":"all"}]}]'
	    ]}
};

# To get the final action_table of all available subroutines in this class,
# merge the get- and mod-metadata hashes. See http://www.perlmonks.org/?node_id=524456
# Note that modmeta_action_table will be empty of subroutines if the user does not have permissions
# to modify metadata.
my $action_table = { %$getmeta_action_table, %$modmeta_action_table };


sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    # Treat metavalue specially.  To transmit this through a GET request
    # the Javascript side has url-encoded it, so here we need to decode
    # it before proceeding

    my $url_encoded_metavalue = $gsdl_cgi->param("metavalue");
    my $url_decoded_metavalue = &unicode::url_decode($url_encoded_metavalue,1);
    my $unicode_array = &unicode::utf82unicode($url_decoded_metavalue);

    $url_decoded_metavalue = join("",map(chr($_),@$unicode_array));
    $gsdl_cgi->param("metavalue",$url_decoded_metavalue);

    # need to do the same with prevmetavalue
    my $url_encoded_prevmetavalue = $gsdl_cgi->param("prevmetavalue");
    my $url_decoded_prevmetavalue = &unicode::url_decode($url_encoded_prevmetavalue,1);
    my $prevunicode_array = &unicode::utf82unicode($url_decoded_prevmetavalue);

    $url_decoded_prevmetavalue = join("",map(chr($_),@$prevunicode_array));
    $gsdl_cgi->param("prevmetavalue",$url_decoded_prevmetavalue);

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}


sub get_live_metadata
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdlhome  = $self->{'gsdlhome'};
    my $infodbtype = $self->{'infodbtype'};
    
    # live metadata gets/saves value scoped (prefixed) by the current usename 
    # so (for now) let's not bother to enforce authentication

    # Obtain the collect dir
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
    ## my $collect_dir = &util::filename_cat($gsdlhome, "collect");

    # No locking collection when getting metadata, only when setting it
#    $self->lock_collection($username, $collect); # Make sure the collection isn't locked by someone else

    # look up additional args
    my $docid  = $self->{'d'};
    if ((!defined $docid) || ($docid =~ m/^\s*$/)) {
       $gsdl_cgi->generate_error("No docid (d=...) specified.");
    }

    # Generate the dbkey
    my $metaname  = $self->{'metaname'};
    my $dbkey = "$docid.$metaname";

    # To people who know $collect_tail please add some comments
    # Obtain path to the database
    my $collect_tail = $collect;
    $collect_tail =~ s/^.*[\/|\\]//;
    my $index_text_directory = &util::filename_cat($collect_dir,$collect,"index","text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($infodbtype, "live-$collect_tail", $index_text_directory);
    
    # Obtain the content of the key
    my $cmd = "gdbmget $infodb_file_path $dbkey";
    if (open(GIN,"$cmd |") == 0) {
        # Catch error if gdbmget failed
	my $mess = "Failed to get metadata key: $metaname\n";
	$mess .= "$!\n";

	$gsdl_cgi->generate_error($mess);
    }
    else {
	binmode(GIN,":utf8");
        # Read everything in and concatenate them into $metavalue
	my $metavalue = "";
	my $line;
	while (defined ($line=<GIN>)) {
	    $metavalue .= $line;
	}
	close(GIN);
	chomp($metavalue); # Get rid off the tailing newlines
	$gsdl_cgi->generate_ok_message("$metavalue");
    }

    # Release the lock once it is done
#    $self->unlock_collection($username, $collect);
}

# just calls the index version
sub get_metadata
{
    my $self = shift @_;
    $self->get_index_metadata(@_);
}

# JSON version that will get the requested metadata values 
# from the requested source (index, import, archives or live)
# One of the params is a JSON string and the return value is JSON too
# http://forums.asp.net/t/1844684.aspx/1 - Web api method return json in string
sub get_metadata_array
{
    my $self = shift @_;

    my $where = $self->{'where'};
    if (!$where || ($where =~ m/^\s*$/)) { # 0, "0", "" and undef are all false. All else is true.
	# What is truth in perl: http://www.berkeleyinternet.com/perl/node11.html
	# and http://www.perlmonks.org/?node_id=33638

	$where = "index"; # default behaviour is to get the values from index
    }

    # Only when setting metadata do we perform authentication and do we lock the collection,
    # not when getting metadata

    # for get_meta_array, the where param can only be ONE of import, archives, index, live
    if($where =~ m/index/) {
	$self->_get_index_metadata_array(@_);
    }
    elsif($where =~ m/archives/) {
	$self->_get_archives_metadata_array(@_);
    }
    elsif($where =~ m/import/) {
	$self->_get_import_metadata_array(@_);
    }
    elsif($where =~ m/live/) {
    	$self->_get_live_metadata_array(@_);
    }
}

# Unused at present. Added for completion. Tested.
sub _get_import_metadata_array {
    
    my $self = shift @_;

    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $site = $self->{'site'};
    my $collect_dir = $gsdl_cgi->get_collection_dir($site);
    
    # look up additional args
    my $infodbtype = $self->{'infodbtype'};
    
    my $archive_dir = &util::filename_cat($collect_dir, $collect, "archives");
    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archive_dir);
    my $json_str      = $self->{'json'};
    my $doc_array = decode_json $json_str;

    my $json_result_str = "[";
    my $first_doc_rec = 1;
    foreach my $doc_array_rec ( @$doc_array ) {
	
	my $docid = $doc_array_rec->{'docid'}; # no subsection metadata support in metadata.xml, only toplevel meta
	
	if($first_doc_rec) {
	    $first_doc_rec = 0;
	} else {
	    $json_result_str .= ",";
	}
	$json_result_str = $json_result_str . "{\"docid\":\"" . $docid . "\"";	

	my $metatable = $doc_array_rec->{'metatable'}; # a subarray, or need to generate an error saying JSON structure is wrong
	$json_result_str = $json_result_str . ",\"metatable\":[";

	my $first_rec = 1;
	foreach my $metatable_rec ( @$metatable ) { # the subarray metatable is an array of hashmaps	    

	    # Read the docid entry	    
	    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid);
	    # This now stores the full pathname
	    my $import_filename = $doc_rec->{'src-file'}->[0];
	    $import_filename = &util::placeholders_to_abspath($import_filename);

	    # figure out correct metadata.xml file [?]
	    # Assuming the metadata.xml file is next to the source file
	    # Note: This will not work if it is using the inherited metadata from the parent folder
	    my ($import_tailname, $import_dirname) = File::Basename::fileparse($import_filename);
	    my $metadata_xml_filename = &util::filename_cat($import_dirname, "metadata.xml");


	    if($first_rec) {
		$first_rec = 0;
	    } else {
		$json_result_str .= ",";		
	    }
	    
	    my $metaname  = $metatable_rec->{'metaname'};
	    $json_result_str .= "{\"metaname\":\"$metaname\",\"metavals\":[";

	    my $metapos   = $metatable_rec->{'metapos'}; # 0... 1|all|undefined
	    if(!defined $metapos) {
		$metapos = 0;
	    }

	    # Obtain the specified metadata value(s)
	    my $metavalue;

	    if($metapos ne "all") { # get the value at a single metapos
		$metavalue = $self->get_metadata_from_metadata_xml($gsdl_cgi, $metadata_xml_filename, $metaname, $metapos, $import_tailname);

		#print STDERR "**** Metafilename, metaname, metapos, sec_num: $metadata_xml_filename, $metaname, $metapos, $import_tailname\n"; 
		
		$json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

	    } else {
		my $first_metaval = 1;
		$metapos = 0;
		$metavalue = $self->get_metadata_from_metadata_xml($gsdl_cgi, $metadata_xml_filename, $metaname, $metapos, $import_tailname);

		while (defined $metavalue && $metavalue ne "") {
		    if($first_metaval) {		
			$first_metaval = 0;
		    } else {
			$json_result_str .= ",";
		    }
	    
		    $json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

		    $metapos++;
		    $metavalue = $self->get_metadata_from_metadata_xml($gsdl_cgi, $metadata_xml_filename, $metaname, $metapos, $import_tailname);
		}
	    }

	    $json_result_str .= "]}"; # close metavals array and metatable record
	}
	
	$json_result_str .= "]}"; # close metatable array and docid record
    }

    $json_result_str .= "]"; # close array of docids
    $gsdl_cgi->generate_ok_message($json_result_str."\n");
}

# Unused method, but included for completion. Tested, works. Takes a JSON string and returns a JSON string.
# For more information on the format of the output, see _get_index_metadata_array, which is in use.
sub _get_archives_metadata_array {

    my $self = shift @_;

    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $site = $self->{'site'};
    my $collect_dir = $gsdl_cgi->get_collection_dir($site);

    # look up additional args    
    my $infodbtype = $self->{'infodbtype'};

    my $archive_dir = &util::filename_cat($collect_dir, $collect, "archives");
    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archive_dir);

    my $json_str      = $self->{'json'};
    my $doc_array = decode_json $json_str;

    my $json_result_str = "[";
    my $first_doc_rec = 1;
    foreach my $doc_array_rec ( @$doc_array ) {
	
	my $docid     = $doc_array_rec->{'docid'};
	
	if($first_doc_rec) {
	    $first_doc_rec = 0;
	} else {
	    $json_result_str .= ",";
	}
	$json_result_str = $json_result_str . "{\"docid\":\"" . $docid . "\"";	

	my $metatable = $doc_array_rec->{'metatable'}; # a subarray, or need to generate an error saying JSON structure is wrong
	$json_result_str = $json_result_str . ",\"metatable\":[";

	my $first_rec = 1;
	foreach my $metatable_rec ( @$metatable ) { # the subarray metatable is an array of hashmaps	    

	    my ($docid, $docid_secnum) = ($doc_array_rec->{'docid'} =~ m/^(.*?)(\..*)?$/);
	    $docid_secnum = "" if (!defined $docid_secnum);

	    # Read the docid entry	    
	    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid);
	    # This now stores the full pathname
	    my $doc_filename = $doc_rec->{'doc-file'}->[0];
	    $doc_filename = &util::filename_cat($archive_dir, $doc_filename);

	    if($first_rec) {
		$first_rec = 0;
	    } else {
		$json_result_str .= ",";		
	    }
	    
	    my $metaname  = $metatable_rec->{'metaname'};
	    $json_result_str .= "{\"metaname\":\"$metaname\",\"metavals\":[";

	    my $metapos   = $metatable_rec->{'metapos'}; # 0... 1|all|undefined
	    if(!defined $metapos) {
		$metapos = 0;
	    }


	    # Obtain the specified metadata value(s)
	    my $metavalue;

	    if($metapos ne "all") { # get the value at a single metapos

		$metavalue = $self->get_metadata_from_archive_xml($gsdl_cgi, $doc_filename, $metaname, $metapos, $docid_secnum);
		#print STDERR "**** Docname, metaname, metapos, sec_num: $doc_filename, $metaname, $metapos, $docid_secnum\n"; 
		
		$json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

	    } else {
		my $first_metaval = 1;
		$metapos = 0;
		$metavalue = $self->get_metadata_from_archive_xml($gsdl_cgi, $doc_filename, $metaname, $metapos, $docid_secnum);

		while (defined $metavalue && $metavalue ne "") {
		    if($first_metaval) {		
			$first_metaval = 0;
		    } else {
			$json_result_str .= ",";
		    }
	    
		    $json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

		    $metapos++;
		    $metavalue = $self->get_metadata_from_archive_xml($gsdl_cgi, $doc_filename, $metaname, $metapos, $docid_secnum);
		}
	    }

	    $json_result_str .= "]}"; # close metavals array and metatable record
	}
	
	$json_result_str .= "]}"; # close metatable array and docid record
    }

    $json_result_str .= "]"; # close array of docids
    $gsdl_cgi->generate_ok_message($json_result_str."\n");
}


# Unused at present. Added for completion. Tested, but not sure if it retrieves metadata in the manner it's expected to.
sub _get_live_metadata_array
{
    my $self = shift @_;

    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $site = $self->{'site'};
    my $collect_dir = $gsdl_cgi->get_collection_dir($site);

    # look up additional args    
    my $infodbtype = $self->{'infodbtype'};
    
    # To people who know $collect_tail please add some comments
    # Obtain the path to the database
    my $collect_tail = $collect;
    $collect_tail =~ s/^.*[\/|\\]//;
    my $index_text_directory = &util::filename_cat($collect_dir,$collect,"index","text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($infodbtype, "live-$collect_tail", $index_text_directory);

    my $json_str      = $self->{'json'};
    my $doc_array = decode_json $json_str;

    my $json_result_str = "[";
    my $first_doc_rec = 1;

    foreach my $doc_array_rec ( @$doc_array ) {
	
	my $docid     = $doc_array_rec->{'docid'};
	
	if($first_doc_rec) {
	    $first_doc_rec = 0;
	} else {
	    $json_result_str .= ",";
	}
	$json_result_str = $json_result_str . "{\"docid\":\"" . $docid . "\"";	
	
	my $metatable = $doc_array_rec->{'metatable'}; # a subarray, or need to generate an error saying JSON structure is wrong
	$json_result_str = $json_result_str . ",\"metatable\":[";
	
	my $first_rec = 1;
	foreach my $metatable_rec ( @$metatable ) { # the subarray metatable is an array of hashmaps	    
	    if($first_rec) {
		$first_rec = 0;
	    } else {
		$json_result_str .= ",";		
	    }
	    
	    my $metaname  = $metatable_rec->{'metaname'};
	    $json_result_str .= "{\"metaname\":\"$metaname\",\"metavals\":[";
	    
	    # Generate the dbkey
	    my $dbkey = "$docid.$metaname";
	    
	    # metapos for get_live_metadata is always assumed to be "all". 
	    # It's always going to get all the lines of metavalues associated with a metaname
	    # (It's the metaname itself that should contain an increment number, if there are to be multiple values).
	    #my $metapos = "all";
	    my $metapos = $metatable_rec->{'metapos'} || 0; # Can be 0... 1|all|undefined. Defaults to 0 if undefined/false
	    my $metavalue = "";
	    
	    # Obtain the content of the key
	    my $cmd = "gdbmget $infodb_file_path $dbkey";
	    if (open(GIN,"$cmd |") != 0) { # Success. 
		
		binmode(GIN,":utf8");
		# Read everything in and concatenate them into $metavalue		
		my $line;
		my $first_metaval = 1;
		my $pos = 0;
		while (defined ($line=<GIN>)) {
		    chomp($line); # Get rid off the tailing newlines
		    
		    if($metapos eq "all") {
			if($first_metaval) {		
			    $first_metaval = 0;
			} else {
			    $json_result_str .= ",";
			}			
			$metavalue = $line;
			$json_result_str .= "{\"metapos\":\"$pos\",\"metavalue\":\"$metavalue\"}";
		    } elsif($metapos == $pos) {
			$metavalue = $line;
			$json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";
			last;
		    } # else, the current $pos is not the required $metapos
		    $pos += 1;
		}
		close(GIN);
	    } # else open cmd == 0 (failed) and metavals array will be empty [] for this metaname
	    
	    $json_result_str .= "]}"; # close metavals array and metatable record
	}
	
	$json_result_str .= "]}"; # close metatable array and docid record
    }

    $json_result_str .= "]"; # close array of docids
    
    $gsdl_cgi->generate_ok_message($json_result_str."\n");    
}


# Takes a JSON string and returns a JSON string
# Request string is of the form:
# http://localhost:8283/greenstone/cgi-bin/metadata-server.pl?a=get-metadata-array&c=demo&where=index&json=[{"docid":"HASHc5bce2d6d3e5b04e470ec9","metatable":[{"metaname":"username","metapos":"all"},{"metaname":"usertimestamp","metapos":"all"}, {"metaname":"usercomment","metapos":"all"}]}]
# Resulting string is of the form:
# [{"docid":"HASHc5bce2d6d3e5b04e470ec9","metatable":[{"metaname":"username","metavals":[{"metapos":"0","metavalue":"me"},{"metapos":"1","metavalue":"admin"}]},{"metaname":"usertimestamp","metavals":[{"metapos":"0","metavalue":"1367900586888"},{"metapos":"1","metavalue":"1367900616574"}]},{"metaname":"usercomment","metavals":[{"metapos":"0","metavalue":"Hi"},{"metapos":"1","metavalue":"Hello"}]}]}]
sub _get_index_metadata_array
{
    my $self = shift @_;

    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $site = $self->{'site'};
    my $collect_dir = $gsdl_cgi->get_collection_dir($site);

    # look up additional args    
    my $infodbtype = $self->{'infodbtype'};
    
    # To people who know $collect_tail please add some comments
    # Obtain the path to the database
    my $collect_tail = $collect;
    $collect_tail =~ s/^.*[\/|\\]//;
    my $index_text_directory = &util::filename_cat($collect_dir,$collect,"index","text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($infodbtype, $collect_tail, $index_text_directory);

    my $json_str      = $self->{'json'};
    my $doc_array = decode_json $json_str;

    my $json_result_str = "[";
    my $first_doc_rec = 1;

    foreach my $doc_array_rec ( @$doc_array ) {
	
	my $docid     = $doc_array_rec->{'docid'};
	
	if($first_doc_rec) {
	    $first_doc_rec = 0;
	} else {
	    $json_result_str .= ",";
	}
	$json_result_str = $json_result_str . "{\"docid\":\"" . $docid . "\"";	

	my $metatable = $doc_array_rec->{'metatable'}; # a subarray, or need to generate an error saying JSON structure is wrong
	$json_result_str = $json_result_str . ",\"metatable\":[";

	my $first_rec = 1;
	foreach my $metatable_rec ( @$metatable ) { # the subarray metatable is an array of hashmaps	    
	    if($first_rec) {
		$first_rec = 0;
	    } else {
		$json_result_str .= ",";		
	    }
	    
	    my $metaname  = $metatable_rec->{'metaname'};
	    $json_result_str .= "{\"metaname\":\"$metaname\",\"metavals\":[";

	    my $metapos   = $metatable_rec->{'metapos'}; # 0... 1|all|undefined
	    if(!defined $metapos) {
		$metapos = 0;
	    }

	     # Read the docid entry
	    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $infodb_file_path, $docid);
  
	    # Basically loop through and unescape_html the values
	    foreach my $k (keys %$doc_rec) {
		my @escaped_v = ();
		foreach my $v (@{$doc_rec->{$k}}) {
		    my $ev = &ghtml::unescape_html($v);
		    push(@escaped_v, $ev);
		}
		$doc_rec->{$k} = \@escaped_v;
	    }

	    # Obtain the specified metadata value(s)
	    my $metavalue;

	    if($metapos ne "all") { # get the value at a single metapos

		$metavalue = $doc_rec->{$metaname}->[$metapos];

		# protect any double quotes and colons in the metavalue before putting it into JSON
		$metavalue =~ s/\"/&quot;/g if defined $metavalue;
		$metavalue =~ s/\:/&58;/g if defined $metavalue;

		$json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

	    } else {
		my $first_metaval = 1;
		$metapos = 0;
		$metavalue = $doc_rec->{$metaname}->[$metapos];

		while (defined $metavalue) {

		    # protect any double quotes and colons in the metavalue before putting it into JSON
		    $metavalue =~ s/\"/&quot;/g;
		    $metavalue =~ s/\:/&58;/g;

		    if($first_metaval) {		
			$first_metaval = 0;
		    } else {
			$json_result_str .= ",";
		    }
	    
		    $json_result_str .= "{\"metapos\":\"$metapos\",\"metavalue\":\"$metavalue\"}";

		    $metapos++;
		    $metavalue = $doc_rec->{$metaname}->[$metapos];
		}
	    }

	    $json_result_str .= "]}"; # close metavals array and metatable record
	}
	
	$json_result_str .= "]}"; # close metatable array and docid record
    }

    $json_result_str .= "]"; # close array of docids

    $gsdl_cgi->generate_ok_message($json_result_str."\n");    
}


sub get_index_metadata
{
    my $self = shift @_;

    my $username  = $self->{'username'};
    my $collect   = $self->{'collect'};
    my $gsdl_cgi  = $self->{'gsdl_cgi'};
    my $gsdlhome  = $self->{'gsdlhome'};

    # Obtain the collect dir
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
    ##my $collect_dir = &util::filename_cat($gsdlhome, "collect");

    # look up additional args
    my $docid     = $self->{'d'};
    my $metaname  = $self->{'metaname'};
    my $metapos   = $self->{'metapos'};
    my $infodbtype = $self->{'infodbtype'};

    # To people who know $collect_tail please add some comments
    # Obtain path to the database
    my $collect_tail = $collect;
    $collect_tail =~ s/^.*[\/|\\]//;
    my $index_text_directory = &util::filename_cat($collect_dir,$collect,"index","text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($infodbtype, $collect_tail, $index_text_directory);

    # Read the docid entry
    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $infodb_file_path, $docid);
  
    # Basically loop through and unescape_html the values
    foreach my $k (keys %$doc_rec) {
	my @escaped_v = ();
	foreach my $v (@{$doc_rec->{$k}}) {
	    my $ev = &ghtml::unescape_html($v);
	    push(@escaped_v, $ev);
	}
	$doc_rec->{$k} = \@escaped_v;
    }

    # Obtain the specified metadata value
    $metapos = 0 if (!defined $metapos || ($metapos =~ m/^\s*$/));
    my $metavalue = $doc_rec->{$metaname}->[$metapos];
    $gsdl_cgi->generate_ok_message("$metavalue");
    
}


sub get_import_metadata
{
	my $self = shift @_;

	my $username  = $self->{'username'};
	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
	my $gsdlhome  = $self->{'gsdlhome'};

	# Obtain the collect dir
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	##my $collect_dir = &util::filename_cat($gsdlhome, "collect");

	# look up additional args
	my $docid     = $self->{'d'};
	my $metaname  = $self->{'metaname'};
	my $metapos = $self->{'metapos'};
	$metapos = 0 if (!defined $metapos || ($metapos =~ m/^\s*$/)); # gets the first value by default since metapos defaults to 0

	my $infodbtype = $self->{'infodbtype'};
	if (!defined $docid) 
	{
		$gsdl_cgi->generate_error("No docid (d=...) specified.\n");
	} 

	# Obtain where the metadata.xml is from the archiveinfo-doc.gdb file
	# If the doc oid is not specified, we assume the metadata.xml is next to the specified "f"
	my $metadata_xml_file;
	my $import_filename = undef;
	

	my $archive_dir = &util::filename_cat($collect_dir, $collect, "archives");
	my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archive_dir);
	my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid);

	# This now stores the full pathname
	$import_filename = $doc_rec->{'src-file'}->[0];
	$import_filename = &util::placeholders_to_abspath($import_filename);

	# figure out correct metadata.xml file [?]
	# Assuming the metadata.xml file is next to the source file
	# Note: This will not work if it is using the inherited metadata from the parent folder
	my ($import_tailname, $import_dirname) = File::Basename::fileparse($import_filename);
	my $metadata_xml_filename = &util::filename_cat($import_dirname, "metadata.xml");

	$gsdl_cgi->generate_ok_message($self->get_metadata_from_metadata_xml($gsdl_cgi, $metadata_xml_filename, $metaname, $metapos, $import_tailname));

}

sub get_metadata_from_metadata_xml
{
	my $self = shift @_;
	my ($gsdl_cgi, $metadata_xml_filename, $metaname, $metapos, $src_file) = @_;
	
	my @rules = 
	( 
		_default => 'raw',
		'Metadata' => \&gfmxml_metadata,
		'FileName' => \&mxml_filename
	);
	    
	my $parser = XML::Rules->new
	(
		rules => \@rules,
		output_encoding => 'utf8'
	);
	
	my $xml_in = "";
	if (!open(MIN,"<$metadata_xml_filename")) 
	{
		$gsdl_cgi->generate_error("Unable to read in $metadata_xml_filename: $!");
	}
	else 
	{
		# Read them in
		my $line;
		while (defined ($line=<MIN>)) {
			$xml_in .= $line;
		}
		close(MIN);	

		$parser->parse($xml_in, {metaname => $metaname, metapos => $metapos, src_file => $src_file});
		
		if(defined $parser->{'pad'}->{'metavalue'})
		{
			return $parser->{'pad'}->{'metavalue'};
		}
		else
		{
			return "";
		}
	}
}

sub gfmxml_metadata
{
	my ($tagname, $attrHash, $contextArray, $parentDataArray, $parser) = @_;

	# no subsection support yet in metadata.xml

	if (($parser->{'parameters'}->{'src_file'} eq $parser->{'parameters'}->{'current_file'}) && $parser->{'parameters'}->{'metaname'} eq $attrHash->{'name'})
	{
		if (!defined $parser->{'parameters'}->{'poscount'})
		{
			$parser->{'parameters'}->{'poscount'} = 0;
		}
		else
		{
			$parser->{'parameters'}->{'poscount'}++;
		}
	
		# gets the first value by default, since metapos defaults to 0
		if (($parser->{'parameters'}->{'poscount'} == $parser->{'parameters'}->{'metapos'}))
		{
		    if($parser->{'parameters'}->{'metapos'} > 0) {
			print STDERR "@@@@ WARNING: non-zero metapos.\n";
			print STDERR "@@@@ Assuming SIMPLE collection and proceeding to retrieve the import meta at position: ".$parser->{'parameters'}->{'metapos'}.".\n";
		    }
		    $parser->{'pad'}->{'metavalue'} = $attrHash->{'_content'};
		}
	}
}

sub get_archives_metadata
{
	my $self = shift @_;

	my $username  = $self->{'username'};
	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
#	my $gsdlhome  = $self->{'gsdlhome'};
	my $infodbtype = $self->{'infodbtype'};

	# Obtain the collect dir
	my $site = $self->{'site'};
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);
	
	my $archive_dir = &util::filename_cat($collect_dir, $collect, "archives");

	# look up additional args
	my ($docid, $docid_secnum) = ($self->{'d'} =~ m/^(.*?)(\..*)?$/);
	$docid_secnum = "" if (!defined $docid_secnum);
	
	my $metaname = $self->{'metaname'};
	my $metapos = $self->{'metapos'};
	$metapos = 0 if (!defined $metapos || ($metapos =~ m/^\s*$/));
	
	my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archive_dir);
	my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid);

	# This now stores the full pathname
	my $doc_filename = $doc_rec->{'doc-file'}->[0];	

	$gsdl_cgi->generate_ok_message($self->get_metadata_from_archive_xml($gsdl_cgi, &util::filename_cat($archive_dir, $doc_filename), $metaname, $metapos, $docid_secnum));

}

sub get_metadata_from_archive_xml
{
	my $self = shift @_;
	my ($gsdl_cgi, $doc_xml_filename, $metaname, $metapos, $secid) = @_;
	
	my @start_rules = ('Section' => \&dxml_start_section);
	
	my @rules = 
	( 
		_default => 'raw',
		'Metadata' => \&gfdxml_metadata
	);
	    
	my $parser = XML::Rules->new
	(
		start_rules => \@start_rules,
		rules => \@rules,
		output_encoding => 'utf8'
	);
	
	my $xml_in = "";
	if (!open(MIN,"<$doc_xml_filename")) 
	{
		$gsdl_cgi->generate_error("Unable to read in $doc_xml_filename: $!");
	}
	else 
	{
		# Read them in
		my $line;
		while (defined ($line=<MIN>)) {
			$xml_in .= $line;
		}
		close(MIN);	

		$parser->parse($xml_in, {metaname => $metaname, metapos => $metapos, secid => $secid});
		
		if(defined $parser->{'pad'}->{'metavalue'})
		{
			return $parser->{'pad'}->{'metavalue'};
		}
		else
		{
			return "";
		}
	}
}

sub gfdxml_metadata
{
	my ($tagname, $attrHash, $contextArray, $parentDataArray, $parser) = @_;
	
	if(!($parser->{'parameters'}->{'secid'} eq $parser->{'parameters'}->{'curr_section_num'}))
	{
		return;
	}

	if ($parser->{'parameters'}->{'metaname'} eq $attrHash->{'name'})
	{
		if (!defined $parser->{'parameters'}->{'poscount'})
		{
			$parser->{'parameters'}->{'poscount'} = 0;
		}
		else
		{
			$parser->{'parameters'}->{'poscount'}++;
		}
	}

	if (($parser->{'parameters'}->{'metaname'} eq $attrHash->{'name'}) && ($parser->{'parameters'}->{'poscount'} == $parser->{'parameters'}->{'metapos'}))
	{	
		$parser->{'pad'}->{'metavalue'} = $attrHash->{'_content'};
	}
}

1;
