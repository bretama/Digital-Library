###########################################################################
#
# RecentDocumentsList.pm --
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

# simple list classifier plugin 
# to see the options, run "perl -S classinfo.pl RecentDocumentsList"

package RecentDocumentsList;

use BaseClassifier;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
use sorttools;
use Time::Local;

sub BEGIN {
    @RecentDocumentsList::ISA = ('BaseClassifier');
}

my $arguments =   
    [ { 'name' => "include_docs_added_since",
	'desc' => "{RecentDocumentsList.include_docs_added_since}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "include_most_recently_added", 
	'desc' => "{RecentDocumentsList.include_most_recently_added}",
	'type' => "int",
	'deft' => "20",
        'reqd' => "no"},
      { 'name' => "sort",
	'desc' => "{RecentDocumentsList.sort}",
	'type' => "metadata",
	'reqd' => "no"}
      ];

my $options = { 'name'     => "RecentDocumentsList",
		'desc'     => "{RecentDocumentsList.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);

    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseClassifier($classifierslist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }
    # check the arguments
    
    if (!$self->{"buttonname"}) {
	$self->{"buttonname"} = 'RecentDocuments';
    }

    # we want either include_docs_added_since, or include_most_recently_added, but not both.
    if (defined $self->{'include_docs_added_since'} && !($self->{'include_docs_added_since'} eq "")){
	$self->{'classify_by_date'} = 1;
	my ($year, $month, $day) = $self->{'include_docs_added_since'} =~ 
	    /^(\d\d\d\d)-?(\d\d)?-?(\d\d)?$/;
	if (!defined $year) {
	    &gsprintf($self->{'outhandle'}, "RecentDocumentsList::init {RecentDocumentsList.date_wrong_format}\n");
	    die "\n";
	}
	if (!defined $month || $month < 1 || $month > 12) {
	    $month = "01";
	    $day = "01";
	} elsif (!defined $day || $day < 1 || $day > 31) {
	    $day = "01";
	}
	
	$self->{'classification_date'} = timelocal(0,0,0,$day,$month-1, $year);

    } else {
	$self->{'classify_by_date'} = 0;
    }	
    if ($self->{'sort'} eq "") {
	undef $self->{'sort'};
    }
    $self->{'sort'} = $self->strip_ex_from_metadata($self->{'sort'});

    # Further setup 
    $self->{'list'} = {};
    # if we are getting top X docs, and sorting by meta, we need to store the 
    # date and the metadata
    if (!$self->{'classify_by_date'} && $self->{'sort'}) {
	$self->{'meta_list'} = {};
    }
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();
    my $lastmodified = $doc_obj->get_metadata_element($doc_obj->get_top_section(), "lastmodified");
    if (!defined $lastmodified || $lastmodified eq "") {
	print $self->{'outhandle'}, "RecentDocumentsList: $doc_OID has no lastmodified metadata, not classifying\n";
	return;
    }

    # doc goes into classification if we are not classifying by date, or the date is after the cutoff date.
    if ($self->{'classify_by_date'}) {
	if ($lastmodified > $self->{'classification_date'}) {
	    my $sort_meta = $lastmodified;
	    if (defined $self->{'sort'}) {
		$sort_meta = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $self->{'sort'});
	    }
	    $self->{'list'}->{$doc_OID} = $sort_meta;
	    $doc_obj->add_metadata($doc_obj->get_top_section(), "memberof", "CL".$self->get_number());
	}	    
    } else {

	# need to store metadata as well...
	$self->{'list'}->{$doc_OID} = $lastmodified;
	if (defined $self->{'sort'}) {
	    my $sort_meta = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $self->{'sort'});
	    $self->{'meta_list'}->{$doc_OID} = $sort_meta;
	}
    }
    
}


sub get_classify_info {
    my $self = shift (@_);
    my $return_doc_size=0;

    my $list = $self->{'list'};


    # organise into classification structure
    my %classifyinfo = ('thistype'=>'Invisible',
			'childtype'=>'VList',
 			'Title'=>$self->{'buttonname'},
 			'contains'=>[]);
    

    # may or may not support memberof, depending on options set
    $classifyinfo{'supportsmemberof'} = $self->supports_memberof();

    # get either all documents (sorted by date), or the top X docs
    my @sorted_docs = sort {$self->date_or_metadata_sort($a,$b)} keys %{$self->{'list'}};
    my $numdocs = $self->{'include_most_recently_added'};
    if ($self->{'classify_by_date'}) { 
	# just include all docs in the list
	$numdocs = scalar  (@sorted_docs);
    } else {
	if ($numdocs > scalar  (@sorted_docs)) {
	    $numdocs = scalar  (@sorted_docs);
	}
	if ($self->{'sort'}) {
	    # we need to sort further by metadata
	    # cut off the list
	    @sorted_docs = @sorted_docs[0..$numdocs-1];
	    # sort again
	    @sorted_docs = sort {$self->external_meta_sort($a,$b)}@sorted_docs;
	}
    }
    for (my $i=0; $i<$numdocs; $i++) {
	push (@{$classifyinfo{'contains'}}, {'OID'=> $sorted_docs[$i]});
    }
	
	
    return \%classifyinfo;
}

# we can only support memberof if we have the include_docs_added_since option, otherwise we don't know at the time of classification of a document if it will be in the classifier or not.
sub supports_memberof {
    my $self = shift(@_);
    if ($self->{'classify_by_date'}) {
	return "true";
    }
    return "false";
}

sub date_or_metadata_sort {
    my ($self,$a,$b) = @_;
    # make it do metadata too
    my $date_a = $self->{'list'}->{$a};
    my $date_b = $self->{'list'}->{$b};
    if (!$self->{'sort'} || !$self->{'classify_by_date'}) {
	# want reverse order (latest to earliest)
	return ($date_b <=> $date_a);
    }
    # meta sorting, use string cmp
    return ($date_a cmp $date_b);
}

sub external_meta_sort {
    my ($self,$a,$b) = @_;
    
    my $meta_a = $self->{'meta_list'}->{$a};
    my $meta_b = $self->{'meta_list'}->{$b};

    $meta_a = "" unless defined $meta_a;
    $meta_b = "" unless defined $meta_b;

    return ($meta_a cmp $meta_b);

}

    
1;




