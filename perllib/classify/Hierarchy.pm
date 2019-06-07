###########################################################################
#
# Hierarchy.pm -- classifier that enables a Hierarchy to beformed without 
#                 the need for a hierarchy file (like HFileHierarchy). Used
#                 to be called AutoHierarchy.  Inherits from HFileHierarchy
#                 so can also do everything that does as well.
#                 Created by Imene, modified by Katherine and David.
#
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

# An advanced Hierarchical classifier
# to see the options, run "perl -S classinfo.pl Hierarchy"

package Hierarchy;

use HFileHierarchy;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @Hierarchy::ISA = ('HFileHierarchy');
}

my $arguments = 
    [ { 'name' => "separator",
	'desc' => "{Hierarchy.separator}",
	'type' => "regexp",
	'deft' => "[\\\\\\\/|\\\\\\\|]",
	'reqd' => "no" },
      { 'name' => "suppresslastlevel",
	'desc' => "{Hierarchy.suppresslastlevel}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "suppressfirstlevel",
	'desc' => "{Hierarchy.suppressfirstlevel}",
	'type' => "flag",
	'reqd' => "no" }
      ];

my $options = { 'name'     => "Hierarchy",
		'desc'     => "{Hierarchy.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new HFileHierarchy($classifierslist, $inputargs, $hashArgOptLists);
    
    # the hash that we use to build up the hierarchy
    $self->{'path_hash'}= {};
    
    return bless $self, $class;
}


sub auto_classify {
    my $self = shift (@_);
    my ($doc_obj,$nosort,$sortmeta,$metavalues) = @_;

    my $doc_OID = $doc_obj->get_OID();

    #Add all the metadata values to the hash
    my $path_hash;
    my $current_pos;
    
    
    foreach my $metavalue (@$metavalues) {
	$path_hash = $self->{'path_hash'};
	my @chunks = split (/$self->{'separator'}/, $metavalue);
	if ($self->{'suppresslastlevel'}) {
	    pop(@chunks); # remove the last element from the end
	}
	if ($self->{'suppressfirstlevel'}) {
	    shift(@chunks);
	}
	foreach my $folderName (@chunks) 
	{
	    # Removing leading and trailing spaces
	    $folderName =~ s/^(\s+)//;
	    $folderName =~ s/(\s+)$//;
	    if ($folderName ne ""){ #sometimes the tokens are empty
		$current_pos = $self->add_To_Hash($path_hash, $folderName, $nosort);
		$path_hash = $current_pos->{'nodes'};
	    } 
	}
	# now add the document, with sort meta if needed
	if ($nosort) {
	    push(@{$current_pos->{'docs'}}, $doc_OID);
	} else {
	    $current_pos->{'docs'}->{$doc_OID} = $sortmeta;
	    
	    #if (defined $sortmeta) {
	#	# can you ever get the same doc twice in one classification??
	#	$current_pos->{'docs'}->{$doc_OID} = $sortmeta;
	#    } else {
	#	$current_pos->{'docs'}->{$doc_OID} = $metavalue;
	#    }
	}
    } # foreach metadata

}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();

    # are we sorting the list??
    my $nosort = 0;
    if (!defined $self->{'sort'}) {
	$nosort = 1;
    }
    
    my $metavalues = [];
    # find all the metadata values
    foreach my $m (@{$self->{'meta_list'}}) {
	my $mvalues = $doc_obj->get_metadata($doc_obj->get_top_section(), $m);
	next unless (@{$mvalues});
	if ($self->{'firstvalueonly'}) {
	    # we only want the first metadata value
	    push (@$metavalues, $mvalues->[0]);
	    last;
	}
	push (@$metavalues, @$mvalues);
	last if (!$self->{'allvalues'}); # we don't want to try other elements
 	                                 # cos we have already found some 
    } 
    
    return unless (@$metavalues);

    #check for a sort element other than our metadata
    my $sortmeta = undef;
    if (!$nosort) {
	if ($self->{'sort'} =~ /^filename$/i) {
	    $sortmeta = $doc_obj->get_source_filename();
	} else {
	    $sortmeta = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $self->{'sort'});
	    if (defined $sortmeta && !$self->{'no_metadata_formatting'}) {
		$sortmeta = &sorttools::format_metadata_for_sorting($self->{'sort'}, $sortmeta, $doc_obj);
	    }
	}
	$sortmeta = "" unless defined $sortmeta;
    }

    if (defined $self->{'subjectfile'}) {
	$self->hfile_classify($doc_obj,$sortmeta,$metavalues);
    }
    else {
	$self->auto_classify($doc_obj,$nosort,$sortmeta,$metavalues);
    }
}

sub add_To_Hash {
    my $self = shift (@_);
    my ($myhash, $k, $nosort) = @_;
    
    if (!defined $myhash->{$k}){
	$myhash->{$k}={};
	$myhash->{$k}->{'nodes'}={};
	if ($nosort) {
	    $myhash->{$k}->{'docs'}=[];
	} else {
	    $myhash->{$k}->{'docs'} = {};
	}
    }
    return $myhash->{$k}; 
}

sub print_Hash{
    my $self = shift (@_); 
    my ($myHash, $num_spaces) = @_;

    foreach my $key (keys %{$myHash}){
	print "\n";
	$self->print_spaces($num_spaces);
	print STDERR "$key*";
	$self->print_Hash($myHash->{$key}, $num_spaces + 2);
    }    
}

sub print_spaces{
    my $self = shift (@_);
    my ($num_spaces) = @_;
    
    for (my $i = 0; $i < $num_spaces; $i++){
	print STDERR " ";
    }
}

sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $thistype) = @_;
    
    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
			'Title'=>$title,
			'contains'=>[],);
    $classifyinfo{'thistype'} = $thistype 
	if defined $thistype && $thistype =~ /\w/;
    
    return \%classifyinfo;
}

sub process_hash {
    my $self = shift (@_);
    my ($top_hash, $top_entry) = @_;   
    my ($entry);
    
    my $hash = {};
    foreach my $key (sort keys %{$top_hash}) {
	$entry = $self->get_entry($key,"VList","VList");
	my $has_content = 0;
	my @doc_list;
	# generate a sorted list of doc ids
	if (not (defined ($self->{'sort'})) && scalar(@{$top_hash->{$key}->{'docs'}})) {
	    @doc_list = @{$top_hash->{$key}->{'docs'}};
	} elsif (defined ($self->{'sort'}) && (keys %{$top_hash->{$key}->{'docs'}})) {
	    @doc_list = sort {$top_hash->{$key}->{'docs'}->{$a} 
			      cmp $top_hash->{$key}->{'docs'}->{$b};} keys %{$top_hash->{$key}->{'docs'}};
	    
	}

	if ($self->{'documents_last'}) {
	    # add nodes, then documents
	    # if this key has nodes, add them
	    if (scalar(keys %{$top_hash->{$key}->{'nodes'}})) {
		$has_content = 1;
		$self->process_hash($top_hash->{$key}->{'nodes'}, $entry); 
	    }

	    # if this key has documents, add them
	    if (@doc_list) {
		$has_content = 1;
		foreach my $d (@doc_list) {
		    push (@{$entry->{'contains'}}, {'OID'=>$d});
		}    
	    }

	} else {
	    # add documents then nodes
	    # if this key has documents, add them
	    if (@doc_list) {
		$has_content = 1;
		foreach my $d (@doc_list) {
		    push (@{$entry->{'contains'}}, {'OID'=>$d});
		}    
	    }
	    # if this key has nodes, add them
	    if (scalar(keys %{$top_hash->{$key}->{'nodes'}})) {
		$has_content = 1;
		$self->process_hash($top_hash->{$key}->{'nodes'}, $entry); 
	    }
	}
	
	# if we have found some content, add the new entry for this key into the parent node
	if ($has_content) {
	    push (@{$top_entry->{'contains'}}, $entry);
	}

    }    
}

sub auto_get_classify_info {
    my $self = shift (@_);
    my ($no_thistype) = @_;
    $no_thistype = 0 unless defined $no_thistype;

    my ($classification);
    my $top_h = $self->{'path_hash'};

    if ($self->{'path_hash'}) {
	if ($self->{'hlist_at_top'}) {
	    $classification = $self->get_entry ($self->{'buttonname'}, "HList", "Invisible");
	}
	else {
	    $classification = $self->get_entry ($self->{'buttonname'}, "VList", "Invisible");
	}
    }

    $self->process_hash($top_h, $classification);
   
    return  $classification;

}

sub auto_get_classify_info
{
    my $self = shift (@_);
    my ($classifyinfo) = @_;

    $self->process_hash($self->{'path_hash'}, $classifyinfo);

    return $classifyinfo;
}


sub get_classify_info {
    my $self = shift (@_);

    my ($classifyinfo);

    if ($self->{'hlist_at_top'}) {
	$classifyinfo = $self->get_entry ($self->{'buttonname'}, "HList", "Invisible");
    }
    else {
	$classifyinfo = $self->get_entry ($self->{'buttonname'}, "VList", "Invisible");
    }

    if (defined $self->{'subjectfile'}) {
	return $self->hfile_get_classify_info($classifyinfo);
    }
    else {
	return $self->auto_get_classify_info($classifyinfo);
    }
}


1;



