###########################################################################
#
# lucenebuildproc.pm -- perl wrapper for building index with Lucene
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
###########################################################################

package lucenebuildproc;

# This document processor outputs a document
# for lucene to process

# Use same basic XML structure setup by mgppbuilder/mgppbuildproc

use mgppbuildproc;
use ghtml;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


use IncrementalBuildUtils;
use FileUtils;

sub BEGIN {
    @lucenebuildproc::ISA = ('mgppbuildproc');
}


sub new {
    my $class = shift @_;
    my $self = new mgppbuildproc (@_);

    $self->{'numincdocs'} = 0;
    $self->{'specified_fields'} = (); # list of fields actually specified in the index, in a map
    $self->{'allfields_index'} = 0; # do we need allfields index?
    $self->{'all_metadata_specified'} = 0; # are we indexing all metadata?
    $self->{'actualsortfields'} = {}; # sort fields that have actually been used
    $self->{'sortfieldnamemap'} = {}; # mapping between field name and field shortname, eg dc.Title->byTI
    return bless $self, $class;
}

sub set_index {
    my $self = shift (@_);
    my ($index, $indexexparr) = @_;

    $self->mgppbuildproc::set_index($index, $indexexparr);
    
    # just get the list of index fields without any subcoll stuff
    my ($fields) = split (/:/, $self->{'index'});

    foreach my $field (split (/;/, $fields)) {
	if ($field eq "allfields") {
	    $self->{'allfields_index'} = 1;
	} elsif ($field eq "metadata") {
	    $self->{'all_metadata_specified'} = 1;
	} else {
	    $field =~ s/^top//;
	    $self->{'specified_fields'} ->{$field} = 1;
	}
    }   
}

sub set_sections_sort_on_document_metadata {
    my $self= shift (@_);
    my ($index_type) = @_;
    
    $self->{'sections_sort_on_document_metadata'} = $index_type;
}

sub set_sortfields {
    my $self = shift (@_);
 
    my ($sortfields) = @_;
    $self->{'sortfields'} = ();
    # lets just go through and check for text, allfields, metadata which are only valid for indexes, not for sortfields
    foreach my $s (@$sortfields) {
	if ($s !~ /^(text|allfields|metadata)$/) {
	    push (@{$self->{'sortfields'}}, $s);
	}
    }
}

sub is_incremental_capable
{
    my $self = shift (@_);

    # Unlike MG and MGPP, Lucene supports incremental building
    return 1;
}


sub textedit {
    my $self = shift (@_);
    my ($doc_obj,$file,$edit_mode) = @_;

    my $lucenehandle = $self->{'output_handle'};
    my $outhandle = $self->{'outhandle'};

    # only output this document if it is one to be indexed
    return if ($doc_obj->get_doc_type() ne "indexed_doc");

    # skip this document if in "compress-text" mode and asked to delete it
    return if (!$self->get_indexing_text() && ($edit_mode eq "delete"));

    # 0/1 to indicate whether this doc is part of the specified subcollection
    my $indexed_doc = $self->is_subcollection_doc($doc_obj);

    # this is another document
    if (($edit_mode eq "add") || ($edit_mode eq "update")) {
	$self->{'num_docs'} += 1;
    }
    else {
	$self->{'num_docs'} -= 1;
    }


    # get the parameters for the output
    # split on : just in case there is subcoll and lang stuff
    my ($fields) = split (/:/, $self->{'index'});

    my $doc_tag_name = $mgppbuildproc::level_map{'document'};

    my $levels = $self->{'levels'};
    my $ldoc_level = $levels->{'document'};
    my $lsec_level = $levels->{'section'};

    my $gs2_docOID = $doc_obj->get_OID();
    my $documenttag = undef;
    my $documentendtag = undef;

    $documenttag = "<$doc_tag_name xmlns:gs2=\"http://www.greenstone.org/gs2\" file=\"$file\"  gs2:docOID=\"$gs2_docOID\" gs2:mode=\"$edit_mode\">\n";
    $documentendtag = "\n</$doc_tag_name>\n";

    my $sec_tag_name = "";
    if ($lsec_level)
    {
	$sec_tag_name = $mgppbuildproc::level_map{'section'};
    }

    my $doc_section = 0; # just for this document

    my $text = "";
    $text .= $documenttag;
    # get the text for this document
    my $section = $doc_obj->get_top_section();
    while (defined $section)
    {
	# update a few statistics
	$doc_section++;
	$self->{'num_sections'}++;

	my $sec_gs2_id = $self->{'num_sections'};
	my $sec_gs2_docOID = $gs2_docOID;
	$sec_gs2_docOID .= ".$section" if ($section ne "");

	# if we are doing subcollections, then some docs shouldn't be indexed.
	# but we need to put the section tag placeholders in there so the
	# sections match up with database
	my $indexed_section = $doc_obj->get_metadata_element($section, "gsdldoctype") || "indexed_section";
	if (($indexed_doc == 0) || ($indexed_section ne "indexed_section" && $indexed_section ne "indexed_doc")) {
	    if ($sec_tag_name ne "") {
		$text .= "\n<$sec_tag_name  gs2:docOID=\"$sec_gs2_docOID\" gs2:mode=\"ignore\">\n";
		$text .= "\n</$sec_tag_name>\n" 
	    }
            $section = $doc_obj->get_next_section($section);
	    next;
          }

	if ($sec_tag_name ne "")
	{
	    $text .= "\n<$sec_tag_name  gs2:docOID=\"$sec_gs2_docOID\" gs2:mode=\"$edit_mode\">\n";
	}

	if (($edit_mode eq "add") || ($edit_mode eq "update")) {
	    $self->{'num_bytes'} += $doc_obj->get_text_length ($section);
	}
	else {
	    # delete
	    $self->{'num_bytes'} -= $doc_obj->get_text_length ($section);
	}


	# collect up all the text for allfields index in here (if there is one)
	my $allfields_text = "";

	foreach my $field (split (/;/, $fields)) {
	    
	    # only deal with this field if it doesn't start with top or
	    # this is the first section
	    my $real_field = $field;
	    next if (($real_field =~ s/^top//) && ($doc_section != 1));
	    
	    # process these two later
	    next if ($real_field eq "allfields" || $real_field eq "metadata");
	    
	    #individual metadata and or text specified - could be a comma separated list
	    #$specified_fields->{$real_field} = 1;
	    my $shortname="";
	    my $new_field = 0; # have we found a new field name?
	    if (defined $self->{'fieldnamemap'}->{$real_field}) {
		$shortname = $self->{'fieldnamemap'}->{$real_field};
	    } else {
		$shortname = $self->create_shortname($real_field);
		$self->{'fieldnamemap'}->{$real_field} = $shortname;
		$self->{'fieldnamemap'}->{$shortname} = 1;
	    }
	    my @metadata_list = (); # put any metadata values in here
	    my $section_text = ""; # put the text in here
	    foreach my $submeta (split /,/, $real_field) {
		if ($submeta eq "text") {
		    # no point in indexing text more than once
		    if ($section_text eq "") {
			$section_text = $doc_obj->get_text($section);
			if ($self->{'indexing_text'}) {
			    # we always strip html
			    $section_text = $self->preprocess_text($section_text, 1, "");
			}
			else { 
			    # leave html stuff in, but escape the tags
			    &ghtml::htmlsafe($section_text);
			}
		    }
		}
		else {
		    $submeta =~ s/^ex\.([^.]+)$/$1/; #strip off ex. iff it's the only metadata set prefix (will leave ex.dc.* intact)

		    # its a metadata element
		    my @section_metadata = @{$doc_obj->get_metadata ($section, $submeta)};
		    if ($section ne $doc_obj->get_top_section() && $self->{'indexing_text'} && defined ($self->{'sections_index_document_metadata'})) {
			if ($self->{'sections_index_document_metadata'} eq "always" || ( scalar(@section_metadata) == 0 && $self->{'sections_index_document_metadata'} eq "unless_section_metadata_exists")) {
			    push (@section_metadata, @{$doc_obj->get_metadata ($doc_obj->get_top_section(), $submeta)});
			}
		    }
		    push (@metadata_list, @section_metadata);
		}
	    } # for each field in this one index
	    

	    # now we add the text and/or metadata into new_text
	    if ($section_text ne "" || scalar(@metadata_list)) {
		my $new_text = "";
		
		if ($section_text ne "") {
		    $new_text .= "$section_text ";
		}
		
		foreach my $item (@metadata_list) {
		    &ghtml::htmlsafe($item);
		    $new_text .= "$item ";
		}

		if ($self->{'allfields_index'}) {
		    $allfields_text .= $new_text;
		}

		if ($self->{'indexing_text'}) {
		    # add the tag
		    $new_text = "<$shortname index=\"1\">$new_text</$shortname>";
		    $self->{'allindexfields'}->{$real_field} = 1;
		}
		# filter the text
		$new_text = $self->filter_text ($field, $new_text);

		if (($edit_mode eq "add") || ($edit_mode eq "update")) {
		    $self->{'num_processed_bytes'} += length ($new_text);
		    $text .= "$new_text";
		}
		else {
		    # delete
		    $self->{'num_processed_bytes'} -= length ($new_text);
		}		
	    }
	    
	} # foreach field

   	if ($self->{'all_metadata_specified'}) {
	    
	    my $new_text = "";
	    my $shortname = "";
	    my $metadata = $doc_obj->get_all_metadata ($section);
	    foreach my $pair (@$metadata) {
		my ($mfield, $mvalue) = (@$pair);
		# no value
		next unless defined $mvalue && $mvalue ne "";
		# we have already indexed this
		next if defined ($self->{'specified_fields'}->{$mfield});
		# check fields here, maybe others dont want - change to use dontindex!!
		next if ($mfield eq "Identifier" || $mfield eq "classifytype" || $mfield eq "assocfilepath");
		next if ($mfield =~ /^gsdl/);
		
		&ghtml::htmlsafe($mvalue);
		
		if (defined $self->{'fieldnamemap'}->{$mfield}) {
		    $shortname = $self->{'fieldnamemap'}->{$mfield};
		}
		else {
		    $shortname = $self->create_shortname($mfield);
		    $self->{'fieldnamemap'}->{$mfield} = $shortname;
		    $self->{'fieldnamemap'}->{$shortname} = 1;
		}
		$self->{'allindexfields'}->{$mfield} = 1;
		$new_text .= "<$shortname index=\"1\">$mvalue</$shortname>\n";
		if ($self->{'allfields_index'}) {
		    $allfields_text .= "$mvalue ";
		}

		if (!defined $self->{'extraindexfields'}->{$mfield}) {
		    $self->{'extraindexfields'}->{$mfield} = 1;
		}				    
	    
	    }
	    # filter the text
	    $new_text = $self->filter_text ("metadata", $new_text);
	    
	    if (($edit_mode eq "add") || ($edit_mode eq "update")) {
		$self->{'num_processed_bytes'} += length ($new_text);
		$text .= "$new_text";
	    }
	    else {
		# delete
		$self->{'num_processed_bytes'} -= length ($new_text);
	    }	    
	}

	if ($self->{'allfields_index'}) {
	    
	    my $new_text = "<ZZ index=\"1\">$allfields_text</ZZ>\n";
	    # filter the text
	    $new_text = $self->filter_text ("allfields", $new_text);
	    
	    if (($edit_mode eq "add") || ($edit_mode eq "update")) {
		$self->{'num_processed_bytes'} += length ($new_text);
		$text .= "$new_text";
	    }
	    else {
		# delete
		$self->{'num_processed_bytes'} -= length ($new_text);
	    }
	}
	# only add sort fields for this section if we are indexing this section, we are doing section level indexing or this is the top section
	if ($self->{'indexing_text'} && ($sec_tag_name ne "" || $doc_section == 1 )) {
	# add sort fields if there are any
	    
	foreach my $sfield (@{$self->{'sortfields'}}) {
	    # ignore special field rank
	    next if ($sfield eq "rank" || $sfield eq "none");
	    my $sf_shortname;
	    if (defined $self->{'sortfieldnamemap'}->{$sfield}) {
		$sf_shortname = $self->{'sortfieldnamemap'}->{$sfield};
	    }
	    else {
		$sf_shortname = $self->create_sortfield_shortname($sfield);
		$self->{'sortfieldnamemap'}->{$sfield} = $sf_shortname;
		$self->{'sortfieldnamemap'}->{$sf_shortname} = 1;
	    }
	    my @metadata_list = (); # put any metadata values in here
	    foreach my $submeta (split /,/, $sfield) {
		$submeta =~ s/^ex\.([^.]+)$/$1/; #strip off ex. iff it's the only metadata set prefix (will leave ex.dc.* intact)
	    
		my @section_metadata = @{$doc_obj->get_metadata ($section, $submeta)};
		    if ($section ne $doc_obj->get_top_section() && defined ($self->{'sections_sort_on_document_metadata'})) {
			if ($self->{'sections_sort_on_document_metadata'} eq "always" || ( scalar(@section_metadata) == 0 && $self->{'sections_sort_on_document_metadata'} eq "unless_section_metadata_exists")) {
			    push (@section_metadata, @{$doc_obj->get_metadata ($doc_obj->get_top_section(), $submeta)});
			}
		    }
		push (@metadata_list, @section_metadata);
	    }
	    my $new_text = "";
	    foreach my $item (@metadata_list) {
		&ghtml::htmlsafe($item);
		$new_text .= "$item";
	    }
	    if ($new_text =~ /\S/) {
		$new_text = "<$sf_shortname index=\"1\" tokenize=\"0\">$new_text</$sf_shortname>";
		# filter the text???
		$text .= "$new_text"; # add it to the main text block
		$self->{'actualsortfields'}->{$sfield} = 1;
	    }
	}
	}
	$text .= "\n</$sec_tag_name>\n" if ($sec_tag_name ne "");

        $section = $doc_obj->get_next_section($section);
    } # for each section
    
    #open (TEXTOUT, ">text.out");
    #print TEXTOUT "$text\n$documentendtag";
    #close TEXTOUT;

    print $lucenehandle "$text\n$documentendtag";

##    if ($edit_mode eq "delete") {	
##       print STDERR "$text\n$documentendtag";
##    }

}

sub text {
    my $self = shift (@_);
    my ($doc_obj,$file) = @_;

    $self->textedit($doc_obj,$file,"add");
}

sub textreindex
{
    my $self = shift (@_);
    my ($doc_obj,$file) = @_;

    $self->textedit($doc_obj,$file,"update");
}

sub textdelete
{
    my $self = shift (@_);
    my ($doc_obj,$file) = @_;

    $self->textedit($doc_obj,$file,"delete");
}





# /** We make this builder pretend to be a document processor so we can get
#  *  information back from the plugins.
#  *
#  *  @param  $self    A reference to this Lucene builder
#  *  @param  $doc_obj A reference to a document object representing what was
#  *                   parsed by the GAPlug
#  *  @param  $file    The name of the file parsed as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd
#  */
sub process()
  {
    my $self = shift (@_);
    my ($doc_obj, $file) = @_;

    # If this is called from any stage other than an incremental infodb we want
    # to pass through to the superclass of build
    if ($self->get_mode() eq "incinfodb")
      {
        print STDERR "*** Processing a document added using INCINFODB ***\n" if ($self->{'verbosity'} > 3);
        my ($archivedir) = $file =~ /^(.*?)(?:\/|\\)[^\/\\]*$/;
        $archivedir = "" unless defined $archivedir;
        $archivedir =~ s/\\/\//g;
        $archivedir =~ s/^\/+//;
        $archivedir =~ s/\/+$//;

        # Number of files
        print STDERR "There are " . scalar(@{$doc_obj->get_assoc_files()}) . " associated documents...\n" if ($self->{'verbosity'} > 3);

        # resolve the final filenames of the files associated with this document
        $self->assoc_files ($doc_obj, $archivedir);

        # is this a paged or a hierarchical document
        my ($thistype, $childtype) = $self->get_document_type ($doc_obj);

        # Determine the actual docnum by checking if we've processed any
        # previous incrementally added documents. If so, carry on from there.
        # Otherwise we set the counter to be the same as the number of
        # sections encountered during the previous build
        if ($self->{'numincdocs'} == 0)
          {
            $self->{'numincdocs'} = $self->{'starting_num_sections'} + 1;
          }

        my $section = $doc_obj->get_top_section ();
        print STDERR "+ top section: '$section'\n" if ($self->{'verbosity'} > 3);
        my $doc_OID = $doc_obj->get_OID();
        my $url = "";
        while (defined $section)
          {
            print STDERR "+ processing section: '$section'\n" if ($self->{'verbosity'} > 3);
            # Attach all the other metadata to this document
            # output the fact that this document is a document (unless doctype
            # has been set to something else from within a plugin
            my $dtype = $doc_obj->get_metadata_element ($section, "doctype");
            if (!defined $dtype || $dtype !~ /\w/)
              {
                #$doc_obj->add_utf8_metadata($section, "doctype", $dtype);
		  $doc_obj->add_utf8_metadata($section, "doctype", "doc");
              }
            # output whether this node contains text
            if ($doc_obj->get_text_length($section) > 0)
              {
                $doc_obj->add_utf8_metadata($section, "hastxt", 1);
              }
            else
              {
                $doc_obj->add_utf8_metadata($section, "hastxt", 0);
              }

            # output archivedir if at top level
            if ($section eq $doc_obj->get_top_section())
              {
                $doc_obj->add_utf8_metadata($section, "archivedir", $archivedir);
		$doc_obj->add_utf8_metadata($section, "thistype", $thistype);
              }

            # output a list of children
            my $children = $doc_obj->get_children ($section);
            if (scalar(@$children) > 0)
              {
                $doc_obj->add_utf8_metadata($section, "childtype", $childtype);
                my @contains = ();
                foreach my $child (@$children)
                  {
                    if ($child =~ /^.*?\.(\d+)$/)
                      {
                        push (@contains, "\".$1");
                      }
                    else
                      {
                        push (@contains, "\".$child");
                      }
                  }
                $doc_obj->add_utf8_metadata($section, "contains", join(";", @contains));
              }
            #output the matching doc number
            print STDERR "+ docnum=" . $self->{'numincdocs'} . "\n" if ($self->{'verbosity'} > 3);
            $doc_obj->add_utf8_metadata($section, "docnum", $self->{'numincdocs'});

            $self->{'numincdocs'}++;
            $section = $doc_obj->get_next_section($section);
            # if no sections wanted, only add the docs
            last if ($self->{'db_level'} eq "document");
          }
        print STDERR "\n*** incrementally add metadata from document at: " . $file . "\n" if ($self->{'verbosity'} > 3);
        &IncrementalBuildUtils::addDocument($self->{'collection'}, $self->{'infodbtype'}, $doc_obj, $doc_obj->get_top_section());
      }
    else
      {
        $self->mgppbuildproc::process(@_);
      }
  }
# /** process() **/


# Following methods seem to be no different to those defined in basebuildproc.pm
# From inspection, it looks like these ones can be removed


sub get_num_docs {
    my $self = shift (@_);
    #rint STDERR "get_num_docs(): $self->{'num_docs'}\n";
    return $self->{'num_docs'};
}

sub get_num_sections {
    my $self = shift (@_);
    #rint STDERR "get_num_sections(): $self->{'num_sections'}\n";
    return $self->{'num_sections'};
}

# num_bytes is the actual number of bytes in the collection
# this is normally the same as what's processed during text compression
sub get_num_bytes {
    my $self = shift (@_);
    #rint STDERR "get_num_bytes(): $self->{'num_bytes'}\n";
    return $self->{'num_bytes'};
}


# This is similar to mgppbuildproc's preprocess_text but adds extra spaces
# Otherwise the removal of tags below might lead to Lucene turning
#   "...farming</p>\n<p>EDWARD.." into "farmingedward"
#     (example from demo collection b20cre)
# Many thanks to John Thompson, DL Consulting Ltd. (www.dlconsulting.com)
sub preprocess_text
{
    my $self = shift (@_);
    my ($text, $strip_html, $para) = @_;
    # at this stage, we do not do paragraph tags unless have strip_html -
    # it will result in a huge mess of non-xml
    return unless $strip_html;

    my $new_text = $text;

    # if we have <pre> tags, we can have < > inside them, need to delete
    # the <> before stripping tags
    $new_text =~ s/<pre>(.*?)<\/pre>/$self->remove_gtlt($1,$para)/gse;

    if ($para eq "") {
       # just remove all tags
       $new_text =~ s/<[^>]*>/ /gs;
    } else {
       # strip all tags except <p> tags which get turned into $para
       $new_text =~ s/<([^>]*)>/$self->process_tags($1, $para)/gse;
    }

    # It's important that we remove name entities because otherwise the text passed to Lucene for indexing
    #   may not be valid XML (eg. if HTML-only entities like &nbsp; are used)
    $new_text =~ s/&\w{1,10};//g;
    # Remove stray '&' characters, except in &#nnnn; or &#xhhhh; entities (which are valid XML)
    $new_text =~ s/&([^\#])/ $1/g;

    return $new_text;
}

sub delete_assoc_files 
{
    my $self = shift (@_);
    my ($archivedir, $edit_mode) = @_;

    $self->basebuildproc::delete_assoc_files(@_);
    
    if ($edit_mode eq "delete") {
	# if we are deleting the doc, then also delete the lucene text  version
	my $assoc_dir = &FileUtils::filenameConcatenate($self->{'build_dir'},"text", $archivedir);
	if (-d $assoc_dir) {
	    &FileUtils::removeFilesRecursive($assoc_dir);
	} 
    }
}

sub create_sortfield_shortname {
    my $self = shift(@_);

    my ($realname) = @_;

    my $index_shortname;
    # if we have created a shortname for an index on this field, then use it.
    if (defined $self->{'fieldnamemap'}->{$realname}) {
	$index_shortname = $self->{'fieldnamemap'}->{$realname};
    } else {
	$index_shortname = $self->create_shortname($realname);
    }
    return "by".$index_shortname;
}
  

1;


