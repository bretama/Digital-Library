###########################################################################
#
# mgppbuildproc.pm -- 
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
# for mgpp to process


package mgppbuildproc;

use basebuildproc;
use cnseg;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


BEGIN {
    @mgppbuildproc::ISA = ('basebuildproc');
}

#this must be the same as in mgppbuilder
our %level_map = ('document'=>'Doc',
		  'section'=>'Sec',
		  'paragraph'=>'Para');

# change this so a user can add their own ones in via a file or cfg
#add AND, OR, NOT NEAR to this list - these cannot be used as field names
#also add the level names (Doc, Sec, Para)
our %static_indexfield_map = ('Title'=>'TI',
			  'TI'=>1,
			  'Subject'=>'SU',
			  'SU'=>1,
			  'Creator'=>'CR',
			  'CR'=>1,
			  'Organization'=>'ORG',
			  'ORG'=>1,
			  'Source'=>'SO',
			  'SO'=>1,
			  'Howto'=>'HT',
			  'HT'=>1,
			  'ItemTitle'=>'IT',
			  'IT'=>1,
			  'ProgNumber'=>'PN',
			  'PN'=>1,
			  'People'=>'PE',
			  'PE'=>1,
			  'Coverage'=>'CO',
			  'CO'=>1,
			  'allfields'=>'ZZ',
			  'ZZ'=>1,
			  'text'=>'TX',
			  'TX'=>1,
			  'AND'=>1,
			  'OR'=>1,
			  'NOT'=>1,
			  'NEAR'=>1,
			  'Doc'=>1,
			  'Sec'=>1,
			  'Para'=>1);


sub new {
    my $class = shift @_;
    my $self = new basebuildproc (@_);

    # use a different index specification to the default
    $self->{'index'} = "text";

    $self->{'dontindex'} = {};
    $self->{'allindexfields'} = {}; # list of all actually indexed fields
    $self->{'extraindexfields'} = {}; # indexed fields not specfied in original index list - ie if 'metadata' was specified.
    $self->{'fieldnamemap'} = {'allfields'=>'ZZ',
			  'ZZ'=>1,
			  'text'=>'TX',
			  'TX'=>1}; # mapping between index full names and short names. Once we have decided on a mapping it goes in here, whether we have indexed something or not.
    $self->{'strip_html'}=1;
    
    return bless $self, $class;
}

sub set_levels {
    my $self = shift (@_);
    my ($levels) = @_;

    $self->{'levels'} = $levels;
}

sub set_strip_html {
    my $self = shift (@_);
    my ($strip) = @_;
    $self->{'strip_html'}=$strip;
}

#sub find_paragraphs {
#    $_[1] =~ s/(<p\b)/<Paragraph>$1/gi;
#}

sub remove_gtlt {
    my $self =shift(@_);
    my ($text, $para) = @_;
    $text =~s/[<>]//g;
    return "$para$text$para";
}

sub process_tags {
    my $self = shift(@_);
    my ($text, $para) = @_;
    if ($text =~ /^p\b/i) {
	return $para;
    }
    return "";
}

sub preprocess_text {
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
	$new_text =~ s/<[^>]*>//gs;
    } else {
	# strip all tags except <p> tags which get turned into $para
	$new_text =~ s/<([^>]*)>/$self->process_tags($1, $para)/gse;
	
    }
    return $new_text;
}
#this function strips the html tags from the doc if ($strip_html) and
# if ($para) replaces <p> with <Paragraph> tags.
# if both are false, the original text is returned
#assumes that <pre> and </pre> have no spaces, and removes all < and > inside
#these tags
sub preprocess_text_old_and_slow {
    my $self = shift (@_);
    my ($text, $strip_html, $para) = @_;
    my ($outtext) = "";
    if ($strip_html) { 
	while ($text =~ /<([^>]*)>/ && $text ne "") {
	    
	    my $tag = $1;
	    $outtext .= $`." "; #add everything before the matched tag
	    $text = $'; #'everything after the matched tag
	    if ($para && $tag =~ /^\s*p\s/i) {
		$outtext .= $para;
	    }
	    elsif ($tag =~ /^pre$/) { # a pre tag
		$text =~ /<\/pre>/; # find the closing pre tag
		my $tmp_text = $`; #everything before the closing pre tag
		$text = $'; #'everything after the </pre>
		$tmp_text =~ s/[<>]//g; # remove all < and >
		$outtext.= $tmp_text . " ";
	    }
	}
    
	$outtext .= $text; # add any remaining text
	return $outtext;
    } #if strip_html

    #if ($para) {
	#$text =~ s/(<p\b)/$para$1/gi;
	#return $text;
   # }
    return $text;
}
	
sub text {
    my $self = shift (@_);
    my ($doc_obj) = @_;
    my $handle = $self->{'output_handle'};
    my $outhandle = $self->{'outhandle'};

    # only output this document if it is one to be indexed
    return if ($doc_obj->get_doc_type() ne "indexed_doc");
    
    my $indexed_doc = $self->is_subcollection_doc($doc_obj);
    
    # this is another document
    $self->{'num_docs'} += 1;

    # get the parameters for the output
    # split on : just in case there is subcoll and lang stuff
    my ($fields) = split (/:/, $self->{'index'});

    # we always do text and index on Doc and Sec levels
    my ($documenttag) = "\n<". $level_map{'document'} . ">\n";
    my ($documentendtag) = "\n</". $level_map{'document'} . ">\n";
    my ($sectiontag) = "\n<". $level_map{'section'} . ">\n";
    my ($sectionendtag) = "\n</". $level_map{'section'} . ">\n";

    my ($paratag) = "";
    
    # paragraph tags will only be used for indexing (can't retrieve 
    # paragraphs), and can ony be used if we are stripping HTML tags
    if ($self->{'indexing_text'} && $self->{'levels'}->{'paragraph'}) {
	if ($self->{'strip_html'}) {
	    $paratag = "<". $level_map{'paragraph'} . ">";
	} else {
	    print $outhandle "Paragraph level can not be used with no_strip_html!. Not indexing Paragraphs.\n";
	}
    }

    my $doc_section = 0; # just for this document
    
    my $text = $documenttag;
   
    # get the text for this document
    my $section = $doc_obj->get_top_section();
    
    while (defined $section) {
	# update a few statistics
	$doc_section++;
	$self->{'num_sections'} += 1;
	$text .= "$sectiontag";
	
	my $indexed_section = $doc_obj->get_metadata_element($section, "gsdldoctype") || "indexed_section";
	if (($indexed_doc == 0) || ($indexed_section ne "indexed_section" && $indexed_section ne "indexed_doc")) {
	    # we are not actually indexing anything for this document,
	    # but we want to keep the section numbers the same, so we just
	    # output section tags for each section (which is done above)
	    $text .= "$sectionendtag";
	    $section = $doc_obj->get_next_section($section);
	    next;
	}
	
	$self->{'num_bytes'} += $doc_obj->get_text_length ($section);

	# has the user added a 'metadata' index?
	my $all_metadata_specified = 0; 
	# which fields have already been indexed? (same as fields, but in a map)
	my $specified_fields = {};
	foreach my $field (split (/;/, $fields)) {
	    # only deal with this field if it doesn't start with top or
	    # this is the first section
	    my $real_field = $field;
	    next if (($real_field =~ s/^top//) && ($doc_section != 1));
	    
	    my $new_text = ""; 

	    # we get allfields by default 
	    next if ($real_field eq "allfields"); 
	    
	    # metadata - output all metadata we know about except gsdl stuff
	    # each metadata is in a separate index field
	    if ($real_field eq "metadata") { 
		# we will process this later, so we are not reindexing metadata already indexed
		$all_metadata_specified = 1;
		next;
	    }
	    
		#individual metadata and or text specified - could be 
		# a comma separated list
		$specified_fields->{$real_field} = 1;
		my $shortname="";

	    if (defined $self->{'fieldnamemap'}->{$real_field}) {
		$shortname = $self->{'fieldnamemap'}->{$real_field};
	    } else {
		$shortname = $self->create_shortname($real_field);
		$self->{'fieldnamemap'}->{$real_field} = $shortname;
		$self->{'fieldnamemap'}->{$shortname} = 1;
	    }

		my @metadata_list = (); # put any meta values in here
		my $section_text = ""; # put any text in here
		foreach my $submeta (split /,/, $real_field) {
		    if ($submeta eq "text") { 
			# no point in indexing text more than once
			if ($section_text eq "") {
			    $section_text = $doc_obj->get_text($section);
			    if ($self->{'indexing_text'}) {
				if ($paratag ne "") {
				    # we fiddle around with splitting text into paragraphs
				    $section_text = $self->preprocess_text($section_text, $self->{'strip_html'}, "</$shortname>$paratag<$shortname>");
				}
				else {
				    $section_text = $self->preprocess_text($section_text, $self->{'strip_html'}, "");
				}
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
		} # for each field in index


		# now we add the text and/or the metadata into new_text
		if ($section_text ne "" || scalar(@metadata_list)) {
		    if ($self->{'indexing_text'}) {
			# only add tags in if indexing
			$new_text .= "$paratag<$shortname>";
		    }
		    if ($section_text ne "") {
			$new_text .= "$section_text ";
			if ($self->{'indexing_text'} && $paratag ne "" && scalar(@metadata_list)) {
			    $new_text .= "</$shortname>$paratag<$shortname>";
			}
		    }
		    foreach my $item (@metadata_list) {
			$new_text .= "$item ";
		    }
		    if ($self->{'indexing_text'}) {
			# only add tags in if indexing
			$new_text .= "</$shortname>";
			$self->{'allindexfields'}->{$real_field} = 1;
		    }
		}

	    # filter the text
	    $new_text = $self->filter_text ($field, $new_text);
	    
	    $self->{'num_processed_bytes'} += length ($new_text);
	    $text .= "$new_text";
	} # foreach field
	
   	if ($all_metadata_specified) {
	    my $new_text = "";
	    my $shortname = "";
	    my $metadata = $doc_obj->get_all_metadata ($section);
	    foreach my $pair (@$metadata) {
		my ($mfield, $mvalue) = (@$pair);
		# no value
		next unless defined $mvalue && $mvalue ne "";
		# we have already indexed this
		next if defined ($specified_fields->{$mfield});
		# check fields here, maybe others dont want - change to use dontindex!!
		next if ($mfield eq "Identifier" || $mfield eq "classifytype" || $mfield eq "assocfilepath");
		next if ($mfield =~ /^gsdl/);
		
		if (defined $self->{'fieldnamemap'}->{$mfield}) {
		    $shortname = $self->{'fieldnamemap'}->{$mfield};
		} else {
		    $shortname = $self->create_shortname($mfield);
		    $self->{'fieldnamemap'}->{$mfield} = $shortname;
		    $self->{'fieldnamemap'}->{$shortname} = 1;
		}
		$self->{'allindexfields'}->{$mfield} = 1;
		$new_text .= "$paratag<$shortname>$mvalue</$shortname>\n";
		if (!defined $self->{'extraindexfields'}->{$mfield}) {
		    $self->{'extraindexfields'}->{$mfield} = 1;
		}				    
	    
	    }
	    # filter the text
	    $new_text = $self->filter_text ("metadata", $new_text);
	    
	    $self->{'num_processed_bytes'} += length ($new_text);
	    $text .= "$new_text";

	    
	}
    
	$text .= "$sectionendtag";
	$section = $doc_obj->get_next_section($section);
    } # while defined section
    print $handle "$text\n$documentendtag"; 
    #print STDERR "***********\n$text\n***************\n";
    
}

#chooses the first two letters or digits for the shortname
#now ignores non-letdig characters
sub create_shortname {
    my $self = shift(@_);
    
    my ($realname) = @_;
    my @realnamelist = split(",", $realname);
    map {$_=~ s/^[a-zA-Z]+\.//;} @realnamelist; #remove namespaces
    my ($singlename) = $realnamelist[0];

    # try our predefined static mapping
    my $name;
    if (defined ($name = $static_indexfield_map{$singlename})) {
	if (! defined $self->{'fieldnamemap'}->{$name}) {
	    # has this shortname already been used??
	    return $static_indexfield_map{$singlename};
	}
    }
    # we can't use the quick map, so join all fields back together (without namespaces), and try sets of two characters.
    $realname = join ("", @realnamelist);
    #try the first two chars
    my $shortname;
    if ($realname =~ /^[^\w]*(\w)[^\w]*(\w)/) {
	$shortname = "$1$2";
    } else {
	# there aren't two letdig's in the field - try arbitrary combinations
	$realname = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	$shortname = "AB";
    }
    $shortname =~ tr/a-z/A-Z/;

    #if already used, take the first and third letdigs and so on
    my $count = 1;
    while (defined $self->{'fieldnamemap'}->{$shortname} || defined $static_indexfield_map{$shortname}) {
	if ($realname =~ /^[^\w]*(\w)([^\w]*\w){$count}[^\w]*(\w)/) {
	    $shortname = "$1$3";
	    $count++;
	    $shortname =~ tr/a-z/A-Z/;
	
	}
	else {
	    #remove up to and incl the first letdig
	    $realname =~ s/^[^\w]*\w//;
	    $count = 0;
	}
    }

    return $shortname;
}

1;

