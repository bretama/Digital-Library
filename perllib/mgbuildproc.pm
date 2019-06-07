###########################################################################
#
# mgbuildproc.pm -- 
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

# This document processor outputs a document
# for mg to process

package mgbuildproc;


use basebuildproc;
use strict;


BEGIN {
    @mgbuildproc::ISA = ('basebuildproc');
}

sub new {
    my $class = shift @_;
    my $self = new basebuildproc (@_);
    return bless $self, $class;
}


sub find_paragraphs {
    $_[1] =~ s/(<p\b)/\cC$1/gi;
}

sub text {
    my $self = shift (@_);
    my ($doc_obj) = @_;
    my $handle = $self->{'output_handle'};
    
    # only output this document if it is one to be indexed
    return if ($doc_obj->get_doc_type() ne "indexed_doc");
    
    # see if this document belongs to this subcollection
    my $indexed_doc = $self->is_subcollection_doc($doc_obj);

    # this is another document
    $self->{'num_docs'} += 1;

    # get the parameters for the output
    my ($level, $fields) = split (/:/, $self->{'index'});
    $fields =~ s/\ball\b/Title,Creator,text/;
    $fields =~ s/\btopall\b/topTitle,topCreator,toptext/;

    my $doc_section = 0; # just for this document
    my $text = "";
    my $text_extra = "";

    # get the text for this document
    my $section = $doc_obj->get_top_section();
    while (defined $section) {
	# update a few statistics
	$doc_section++;
	$self->{'num_sections'} += 1;

	my $indexed_section = $doc_obj->get_metadata_element($section, "gsdldoctype") || "indexed_section";
	if (($indexed_doc) && ($indexed_section eq "indexed_section" || $indexed_section eq "indexed_doc")) {
	    $self->{'num_bytes'} += $doc_obj->get_text_length ($section);
	    foreach my $field (split (/,/, $fields)) {
		# only deal with this field if it doesn't start with top or
		# this is the first section
		my $real_field = $field;
		if (!($real_field =~ s/^top//) || ($doc_section == 1)) {
		    my $new_text = "";
		    if ($level eq "dummy") {
			# a dummy index is a special case used when no
			# indexes are specified (since there must always be
			# at least one index or we can't retrieve the
			# compressed text) - we add a small amount of text
			# to these dummy indexes which will never be seen
			# but will overcome mg's problems with building
			# empty indexes
			$new_text = "this is dummy text to stop mg barfing";
			$self->{'num_processed_bytes'} += length ($new_text);

		    } elsif ($real_field eq "text") {
			$new_text = $doc_obj->get_text ($section) if $self->{'store_text'};
			$self->{'num_processed_bytes'} += length ($new_text);
			$new_text =~ s/[\cB\cC]//g;
			$self->find_paragraphs($new_text);
			
		    } else {
			my $first = 1;
			$real_field =~ s/^ex\.([^.]+)$/$1/; # remove ex. namespace iff it's the only namespace prefix (will leave ex.dc.* intact)
			my @section_metadata = @{$doc_obj->get_metadata ($section, $real_field)};
			if ($level eq "section" && $section ne $doc_obj->get_top_section() && $self->{'indexing_text'} && defined ($self->{'sections_index_document_metadata'})) {
			    if ($self->{'sections_index_document_metadata'} eq "always" || ( scalar(@section_metadata) == 0 && $self->{'sections_index_document_metadata'} eq "unless_section_metadata_exists")) {
				push (@section_metadata, @{$doc_obj->get_metadata ($doc_obj->get_top_section(), $real_field)});
			    }
			}
			foreach my $meta (@section_metadata) {
			    $meta =~ s/[\cB\cC]//g;
			    $self->{'num_processed_bytes'} += length ($meta);
			    $new_text .= "\cC" unless $first;
			    $new_text .= $meta if $self->{'store_text'};
			    $first = 0;
			}
		    }
		    
		    # filter the text
		    $new_text = $self->filter_text ($field, $new_text);

		    $text .= "$new_text\cC";
		}
	    }
	}
	
	if ($level eq "document") { $text_extra .= "\cB"; }
	else { $text .= "\cB"; }
	
	$section = $doc_obj->get_next_section($section);
    }

    print $handle "$text$text_extra";
}

1;

