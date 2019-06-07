##########################################################################
#
# docextractaction.pm -- 
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

package docextractaction;

use strict;

use cgiactions::baseaction;

use dbutil;
use ghtml;

use JSON;


BEGIN {
    require XML::Rules;
}

@docextractaction::ISA = ('baseaction');

my $action_table =
{
	"extract-archives-doc" => { # where param can be ONE of: index (default), import, archives, live
	    'compulsory-args' => [ "d", "json-sections" ],
	    'optional-args'   => [ "json-metadata", "newd", 
				   "keep-parent-metadata", "keep-parent-content" ],
#	    'optional-args'   => [ "where" ],
	    'help-string' => [
		'document-extract.pl?a=extract-archives-doc&c=demo&d=HASH0123456789ABC&json-sections=["1.2","1.3.2","2.1","2.2"]&json-metadata=[{"metaname":"dc.Title","metavalue":"All Black Rugy Success","metamode":"accumulate"]'
		."\n\n Add site=xxxx if a Greenstone3 installation"
	    ]}

};


sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    # Treat metavalue specially.  To transmit this through a GET request
    # the Javascript side has url-encoded it, so here we need to decode
    # it before proceeding

#    my $url_encoded_metavalue = $gsdl_cgi->param("metavalue");
#    my $url_decoded_metavalue = &unicode::url_decode($url_encoded_metavalue,1);
#    my $unicode_array = &unicode::utf82unicode($url_decoded_metavalue);

#    $url_decoded_metavalue = join("",map(chr($_),@$unicode_array));
#    $gsdl_cgi->param("metavalue",$url_decoded_metavalue);

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}



sub dxml_start_section
{
    my ($tagname, $attrHash, $contextArray, $parentDataArray, $parser) = @_;

    my $new_depth = scalar(@$contextArray);

    if ($new_depth == 1) {
	$parser->{'parameters'}->{'curr_section_depth'} = 1;
	$parser->{'parameters'}->{'curr_section_num'}   = "";
    }

    my $old_depth  = $parser->{'parameters'}->{'curr_section_depth'};
    my $old_secnum = $parser->{'parameters'}->{'curr_section_num'};

    my $new_secnum;

    if ($new_depth > $old_depth) {
	# first child subsection
	$new_secnum = "$old_secnum.1";
    }
    elsif ($new_depth == $old_depth) {
	# sibling section => increase it's value by 1
	my ($tail_num) = ($old_secnum =~ m/\.(\d+)$/);
	$tail_num++;
	$new_secnum = $old_secnum;
	$new_secnum =~ s/\.(\d+)$/\.$tail_num/;
    }
    else {
	# back up to parent section => lopp off tail
#	$new_secnum = $old_secnum;
#	$new_secnum =~ s/\.\d+$//;
    }

    $parser->{'parameters'}->{'curr_section_depth'} = $new_depth;
    $parser->{'parameters'}->{'curr_section_num'}   = $new_secnum;
	
    1;
}



sub dxml_metadata
{
	my ($tagname, $attrHash, $contextArray, $parentDataArray, $parser) = @_;

	my $parent_sec_num_hash = $parser->{'parameters'}->{'parent_sec_num_hash'};
	
	my $keep_parent_metadata = $parser->{'parameters'}->{'keep_parent_metadata'};
	my $keep_parent_content  = $parser->{'parameters'}->{'keep_parent_content'};

	my $mode = $parser->{'parameters'}->{'mode'};

	if ($mode eq "extract") {

	    my $new_docid = $parser->{'parameters'}->{'new_docid'};
	    if ($attrHash->{'name'} eq "Identifier") {
		$attrHash->{'_content'} = $new_docid;
	    }
	}

	return [ $tagname => $attrHash ];
}


sub dxml_section
{
	my ($tagname, $attrHash, $contextArray, $parentDataArray, $parser) = @_;

	my $curr_sec_num = $parser->{'parameters'}->{'curr_section_num'} || undef;

	my $sec_num_hash = $parser->{'parameters'}->{'sec_num_hash'};
	my $parent_sec_num_hash = $parser->{'parameters'}->{'parent_sec_num_hash'};
	
	my $keep_parent_metadata = $parser->{'parameters'}->{'keep_parent_metadata'};
	my $keep_parent_content  = $parser->{'parameters'}->{'keep_parent_content'};

	my $mode = $parser->{'parameters'}->{'mode'};

	my $prev_depth = $parser->{'parameters'}->{'curr_section_depth'};
	my $live_depth = scalar(@$contextArray);

	if ($live_depth < $prev_depth) {
	    # In a closing-sections poping off situation:
	    #   </Section>
	    # </Section>

	    # => Back up to parent section => lopp off tail

	    $curr_sec_num =~ s/\.\d+$//;
	    $parser->{'parameters'}->{'curr_section_depth'} = $live_depth;
	    $parser->{'parameters'}->{'curr_section_num'}   = $curr_sec_num;
	}


	if ($live_depth == 1) {
	    # root sectin tag, which must always exist
	    return [$tagname => $attrHash];
	}
	elsif ($mode eq "delete") {
	    if (defined $sec_num_hash->{$curr_sec_num}) {
		# remove it
		return undef
	    }
	    else {
		# keep it
		return [$tagname => $attrHash];
	    }
	}
	else {
	    # mode is extract

	    if (defined $sec_num_hash->{$curr_sec_num}) {
		# keep it
##		print STDERR "**** Asked to keep: sec num = $curr_sec_num\n";

		return [$tagname => $attrHash];
	    }
	    elsif (defined $parent_sec_num_hash->{$curr_sec_num}) {
		# want this element, but cut down to just the child <Section>
		
		my $section_child = undef;

##		print STDERR "**** Parent match: sec num = $curr_sec_num\n";

		my $filtered_elems = [];
		
		foreach my $elem ( @{$attrHash->{'_content'}}) {
		    if (ref $elem eq "ARRAY") {
			my $child_tagname = $elem->[0];
##			print STDERR "***## elem name $child_tagname\n";

			
			if ($child_tagname eq "Description") {
			    if ($keep_parent_metadata) {
				push(@$filtered_elems,$elem);
			    }
			}
			elsif ($child_tagname eq "Content") {
			    if ($keep_parent_content) {
				push(@$filtered_elems,$elem);
			    }
			}
			else {
			    push(@$filtered_elems,$elem);
			}
		    }
		    else {
			push(@$filtered_elems,$elem);
		    }
		}

		$attrHash->{'_content'} = $filtered_elems;

		return [$tagname => $attrHash];

	    }
	    else {
		# not in our list => remove it
		return undef;
	    }
	}
}


sub remove_from_doc_xml
{
	my $self = shift @_;
	my ($gsdl_cgi, $doc_xml_filename, $newdoc_xml_filename, 
	    $sec_num_hash, $parent_sec_num_hash, $mode) = @_;
	
	my @start_rules = ('Section' => \&dxml_start_section);
	
	# Set the call-back functions for the metadata tags
	my @rules = 
	( 
		_default => 'raw',
		'Section' => \&dxml_section,
	        'Metadata' => \&dxml_metadata
	);
	    
	my $parser = XML::Rules->new
	(
		start_rules => \@start_rules,
		rules => \@rules, 
		style => 'filter',
		output_encoding => 'utf8',
##	 normalisespaces => 1, # http://search.cpan.org/~jenda/XML-Rules-1.16/lib/XML/Rules.pm
#	 	stripspaces => 2|0|0 # ineffectual
	);
	
	my $status = 0;
	my $xml_in = "";
	if (!open(MIN,"<$doc_xml_filename")) 
	{
		$gsdl_cgi->generate_error("Unable to read in $doc_xml_filename: $!");
		$status = 1;
	}
	else 
	{
		# Read them in
		my $line;
		while (defined ($line=<MIN>)) {
			$xml_in .= $line;
		}
		close(MIN);	

		# Filter with the call-back functions
		my $xml_out = "";

		my $MOUT;
		if (!open($MOUT,">$newdoc_xml_filename")) {
			$gsdl_cgi->generate_error("Unable to write out to $newdoc_xml_filename: $!");
			$status = 1;
		}
		else {
			binmode($MOUT,":utf8");

			my $options = { sec_num_hash         => $sec_num_hash, 
					parent_sec_num_hash  => $parent_sec_num_hash,
					keep_parent_metadata => $self->{'keep-parent-metadata'},
					keep_parent_content  => $self->{'keep-parent-content'},
					new_docid            => $self->{'new_docid'},
				        mode => $mode };

			$parser->filter($xml_in, $MOUT, $options);
			close($MOUT);	    
		}
	}
	return $status;
}

sub sections_as_hash
{
    my $self = shift @_;
    
    my ($json_sections_array) = @_;

    my $sec_num_hash = {};

    foreach my $sn ( @$json_sections_array ) {

	# our XML parser curr_sec_num puts '.' at the root
	# Need to do the same here, so things can be matched up
	$sec_num_hash->{".$sn"} = 1; 
    }

    return $sec_num_hash;
}


sub parent_sections_as_hash
{
    my $self = shift @_;

    my ($json_sections_array) = @_;

    my $sec_num_hash = {};

    foreach my $sn ( @$json_sections_array ) {

	# needs to make a copy, otherwise version stored in json_sections gets changed
	my $sn_copy = $sn; 
	while ($sn_copy =~ s/\.\d+$//) {
	    # our XML parser curr_sec_num puts '.' at the root
	    # Need to do the same here, so things can be matched up

	    $sec_num_hash->{".$sn_copy"} = 1; 
	}
    }

    return $sec_num_hash;
}

sub parse_flag
{
    	my $self = shift @_;

	my ($arg_name) = @_;

	my $flag = $self->{$arg_name} || 0;

	$flag =~ s/^true/1/i;
	$flag =~ s/^false/0/i;

	return $flag;
}

sub _extract_archives_doc
{
	my $self = shift @_;

	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
	my $infodbtype = $self->{'infodbtype'};
	
	my $site = $self->{'site'};
		
	# Obtain the collect and archive dir   
	my $collect_dir = $gsdl_cgi->get_collection_dir($site);	
	
	my $archive_dir = &util::filename_cat($collect_dir,$collect,"archives");

	# look up additional args
	my $docid = $self->{'d'};

	my $timestamp = time();
	my $new_docid = $self->{'newd'} || "HASH$timestamp";
	$self->{'new_docid'} = $new_docid;

	$self->{'keep-parent-metadata'} = $self->parse_flag("keep-parent-metadata");
	$self->{'keep-parent-content'}  = $self->parse_flag("keep-parent-content");

	my $json_sections_str = $self->{'json-sections'};
	my $json_sections_array = decode_json($json_sections_str);


	my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archive_dir);
	my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid);

	my $doc_file = $doc_rec->{'doc-file'}->[0];	
	my $doc_filename = &util::filename_cat($archive_dir, $doc_file);

	my $new_doc_file = $doc_file;
	$new_doc_file =~ s/doc(-\d+)?.xml$/doc-$timestamp.xml/;

	my $newdoc_filename = &util::filename_cat($archive_dir, $new_doc_file);

	my $sec_num_hash = $self->sections_as_hash($json_sections_array);
	my $parent_sec_num_hash = $self->parent_sections_as_hash($json_sections_array);

	my $extract_status = $self->remove_from_doc_xml($gsdl_cgi, $doc_filename ,$newdoc_filename, $sec_num_hash, $parent_sec_num_hash, "extract");
	
	if ($extract_status == 0) 
	{
	    my $delete_sec_num_hash = $self->sections_as_hash($json_sections_array,"no-parents");

	    my $delete_status = $self->remove_from_doc_xml($gsdl_cgi, $doc_filename ,$doc_filename, $sec_num_hash, undef, "delete");

	    if ($delete_status == 0) {

		# Existing doc record needs to be reindexed
		$doc_rec->{'index-status'} = ["R"];
		&dbutil::set_infodb_entry($infodbtype, $arcinfo_doc_filename, $docid, $doc_rec);

		# Create doc-record entry for the newly extracted document

		my $new_doc_rec = $doc_rec;
		$new_doc_rec->{'index-status'} = ["I"];
		#### Need to cut this down to just the assoc files the new document references

		$new_doc_rec->{'doc-file'} = [$new_doc_file];

		&dbutil::set_infodb_entry($infodbtype, $arcinfo_doc_filename, $new_docid, $new_doc_rec);

		#### Also need to update the archivesinf-src database!!!!
		# For all the assoc and src files, retrieve record, and add in new_docid

		my $mess = "document-extract successful: Key[$docid]\n";

		$gsdl_cgi->generate_ok_message($mess);	
	    }
	    else {
		my $mess .= "Failed to extract identified section numbers for key: $docid\n";
		$mess .= "Exit status: $delete_status\n";
		$mess .= "System Error Message: $!\n";
		$mess .= "-" x 20 . "\n";
		
		$gsdl_cgi->generate_error($mess);
	    }
	}
	else 
	{
		my $mess .= "Failed to remove identified section numbers for key: $docid\n";
		$mess .= "Exit status: $extract_status\n";
		$mess .= "System Error Message: $!\n";
		$mess .= "-" x 20 . "\n";
		
		$gsdl_cgi->generate_error($mess);
	}
	
	#return $status; # in case calling functions have a use for this
}



# JSON version that will get the requested metadata values 
# from the requested source (index, import, archives or live)
# One of the params is a JSON string and the return value is JSON too
# http://forums.asp.net/t/1844684.aspx/1 - Web api method return json in string
sub extract_archives_doc
{
	my $self = shift @_;

	my $username  = $self->{'username'};
	my $collect   = $self->{'collect'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
	
	if ($baseaction::authentication_enabled) 
	{
	    # Ensure the user is allowed to edit this collection		
	    $self->authenticate_user($username, $collect); 
	}

	# Make sure the collection isn't locked by someone else
	$self->lock_collection($username, $collect);

	$self->_extract_archives_doc(@_);

	# Release the lock once it is done
	$self->unlock_collection($username, $collect);


}


1;
