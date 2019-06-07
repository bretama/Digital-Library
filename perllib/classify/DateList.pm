###########################################################################
#
# DateList.pm --
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

# classifier plugin for sorting by date

# date is assumed to be in the form yyyymmdd

# at present dates are split by year - this should change
# jrm21 - added option "bymonth", which splits by year and month.

# 23/09/03 Added some more options -kjdon.
# these include:
# -nogroup, which makes each year (or year+month) an individual entry in 
# the horizontal list and prevents compaction
# -metadata, use a different metadata for the date (instead of Date), still expects yyyymmdd format. this affects display cos greenstone displays Date metadata as dd month yyyy, whereas any other date metadata is displayed as yyyymmdd - this needs fixing
# -sort specifies an additional metadata to use in sorting, will take affect when two docs have the same date.

package DateList;

use BaseClassifier;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @DateList::ISA = ('BaseClassifier');
}

my $arguments =
    [ { 'name' => "metadata",
        'desc' => "{DateList.metadata}",
        'type' => "metadata",
	'deft' => "Date",
        'reqd' => "yes" } ,
      { 'name' => "sort",
        'desc' => "{DateList.sort}",
        'type' => "metadata",
	'reqd' => "no" } ,
      { 'name' => "reverse_sort",
	'desc' => "{DateList.reverse_sort}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "bymonth",
	'desc' => "{DateList.bymonth}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "nogroup",
	'desc' => "{DateList.nogroup}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "no_special_formatting",
	'desc' => "{DateList.no_special_formatting}",
	'type' => "flag",
	'reqd' => "no" }
      
      ];

my $options = { 'name'     => "DateList",
		'desc'     => "{DateList.desc}",
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

    # Manually set $self parameters.
    $self->{'list'} = {};

    if (!defined $self->{"metadata"} || $self->{"metadata"} eq "") {
	$self->{'metadata'} = "Date";
    }
    # remove any ex.s
    $self->{'metadata'} = $self->strip_ex_from_metadata($self->{'metadata'});
    $self->{'sort'} = $self->strip_ex_from_metadata($self->{'sort'});
 
    # now can have comma separated list of Dates - we just use the first one (for now)
    my @meta_list = split(/,/, $self->{"metadata"});
    $self->{'meta_list'} = \@meta_list;
 
    $self->{'buttonname'} = $self->generate_title_from_metadata($self->{'metadata'}) unless ($self->{'buttonname'});

    $self->{'childtype'} = "DateList";
    if ($self->{'no_special_formatting'}) {
	$self->{'childtype'} = "VList";
    }
    
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    $self->{'list'} = {};
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();

    # find the first available metadata
    my $date;
    foreach my $m (@{$self->{'meta_list'}}) {
	$date = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $m);
	last if defined $date;
    } 
    
    if (!defined $date || $date eq "") {
	# if this document doesn't contain Date element we won't 
	# include it in this classification
	return;
    }

    my $sort_other = "";
    if (defined $self->{'sort'} && $self->{'sort'} ne "") {
	$sort_other = $doc_obj->get_metadata_element ($doc_obj->get_top_section(), $self->{'sort'});
	$sort_other = &sorttools::format_metadata_for_sorting($self->{'sort'}, $sort_other, $doc_obj) unless $self->{'no_metadata_formatting'};
    }
    
    if (defined $self->{'list'}->{$doc_OID}) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "WARNING: DateList::classify called multiple times for $doc_OID\n";
    } 
        
    $self->{'list'}->{$doc_OID} = "$date$sort_other";

}


sub get_classify_info {
    my $self = shift (@_);

    my @classlist = sort {$self->{'list'}->{$a} cmp $self->{'list'}->{$b};} keys %{$self->{'list'}};

    if ($self->{'reverse_sort'}) {
	@classlist = reverse @classlist;
    }


    return $self->splitlist (\@classlist);
}


sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $thistype) = @_;
    
    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
			'Title'=>$title,
			'contains'=>[],
			'mdtype'=>$self->{'metadata'});
    $classifyinfo{'thistype'} = $thistype 
	if defined $thistype && $thistype =~ /\w/;

    return \%classifyinfo;
}

# splitlist takes an ordered list of classifications (@$classlistref) and
# splits it up into sub-sections by date
sub splitlist {
    my $self = shift (@_);
    my ($classlistref) = @_;
    my $classhash = {};

    # top level
    my $childtype = "HList";

    if (scalar (@$classlistref) <= 39 &&
	!$self->{'nogroup'}) {$childtype = $self->{'childtype'};}

    my $classifyinfo = $self->get_entry ($self->{'buttonname'}, $childtype, "Invisible");
    # don't need to do any splitting if there are less than 39 (max + min -1)
    # classifications, unless nogroup is specified
    if ((scalar @$classlistref) <= 39 && !$self->{'nogroup'}) {
	foreach my $subOID (@$classlistref) {
	    push (@{$classifyinfo->{'contains'}}, {'OID'=>$subOID});
	}
	return $classifyinfo;
    }


    if ($self->{'bymonth'}) {
	# first split up the list into separate year+month classifications

	if (!$self->{'nogroup'}) { # hlist of year+month pairs
	    # single level of classifications
	    foreach my $classification (@$classlistref) {
		my $date = $self->{'list'}->{$classification};
		$date =~ s/^(\d\d\d\d)-?(\d\d).*$/$1&nbsp;_textmonth$2_/;
		# sanity check if month is zero
		if ($date =~ /00_$/) {
		    $date =~ s/^(\d\d\d\d).*$/$1/g;
		}
		$classhash->{$date} = [] unless defined $classhash->{$date};
		push (@{$classhash->{$date}}, $classification);
	    }
	    
	} else { # -nogroup - individual years and months
	    foreach my $classification (@$classlistref) {
		my $date = $self->{'list'}->{$classification};
		$date =~ s/^(\d\d\d\d)-?(\d\d).*$/$1&nbsp;_textmonth$2_/;
		my ($year, $month)=($1,$2);
		# sanity check if month is zero
		if ($date =~ /00_$/) {
		    $date =~ s/^(\d\d\d\d).*$/$1/g;
		}
		# create subclass if it doesn't already exist
		$classhash->{$year} = () unless defined $classhash->{$year};
	          
		$classhash->{$year}->{$month} = []
		    unless defined $classhash->{$year}->{$month};
		push (@{$classhash->{$year}->{$month}}, $classification);

	    }
	    # create hlist of years containing hlists of months

	    my @subclasslist = sort {$a <=> $b} (keys %$classhash);
	    if ($self->{'reverse_sort'}) {
		@subclasslist = reverse @subclasslist;
	    }
	    
	    foreach my $subclass (@subclasslist) {
		  my $yearclassify = $self->get_entry($subclass, "HList");
		  my @subsubclasslist = sort {$a <=> $b} (keys %{$classhash->{$subclass}});
		  if ($self->{'reverse_sort'}) {
		      @subsubclasslist = reverse @subsubclasslist;
		  }

		  foreach my $subsubclass (@subsubclasslist) {
		      my $monthname=$subsubclass;
		      if ($monthname >= 1 && $monthname <= 12) {
			  $monthname="_textmonth" . $monthname . "_";
		      }
		      my $monthclassify=$self->get_entry($monthname, $self->{'childtype'});
		      push (@{$yearclassify->{'contains'}}, $monthclassify);
		      
		      foreach my $subsubOID 
			  (@{$classhash->{$subclass}->{$subsubclass}}) {
			      push (@{$monthclassify->{'contains'}},
				  {'OID'=>$subsubOID});
			  }
		  }
		  push (@{$classifyinfo->{'contains'}}, $yearclassify);
	    }
	    
	    return $classifyinfo;
	} # nogroup
    } else {
	# not by month
	# first split up the list into separate year classifications
	foreach my $classification (@$classlistref) {
	    my $date = $self->{'list'}->{$classification};
	    $date =~ s/^(\d\d\d\d).*$/$1/;
	    $classhash->{$date} = [] unless defined $classhash->{$date};
	    push (@{$classhash->{$date}}, $classification);
	}
          
    }
    
    # only compact the list if nogroup not specified
    if (!$self->{'nogroup'}) {
	$classhash = $self->compactlist ($classhash);
    }
    my @subclasslist = sort keys %$classhash;
    if ($self->{'reverse_sort'}) {
	@subclasslist = reverse @subclasslist;
    }
    foreach my $subclass (@subclasslist) {
	my $tempclassify = $self->get_entry($subclass, $self->{'childtype'});
	foreach my $subsubOID (@{$classhash->{$subclass}}) {
	    push (@{$tempclassify->{'contains'}}, {'OID'=>$subsubOID});
	}
	push (@{$classifyinfo->{'contains'}}, $tempclassify);
    }
  
    return $classifyinfo;
}

sub compactlist {
    my $self = shift (@_);
    my ($classhashref) = @_;
    my $compactedhash = {};
    my @currentOIDs = ();
    my $currentfirstdate = "";
    my $currentlastdate = "";
    my $lastkey = "";

    # minimum and maximum documents to be displayed per page.
    # the actual maximum will be max + (min-1).
    # the smallest sub-section is a single letter at present
    # so in this case there may be many times max documents
    # displayed on a page.
    my $min = 10; 
    my $max = 30;
    my @subsectionlist = sort keys %$classhashref;
    if ($self->{'reverse_sort'}) {
	@subsectionlist = reverse @subsectionlist;
    } 
    foreach my $subsection (@subsectionlist) {
	$currentfirstdate = $subsection if $currentfirstdate eq "";
	if ((scalar (@currentOIDs) < $min) ||
	    ((scalar (@currentOIDs) + scalar (@{$classhashref->{$subsection}})) <= $max)) {
	    push (@currentOIDs, @{$classhashref->{$subsection}});
	    $currentlastdate = $subsection;
	} else {
	    if ($currentfirstdate eq $currentlastdate) {
		@{$compactedhash->{$currentfirstdate}} = @currentOIDs;
		$lastkey = $currentfirstdate;
	    } else {
		@{$compactedhash->{"$currentfirstdate-$currentlastdate"}} = @currentOIDs;
		$lastkey = "$currentfirstdate-$currentlastdate";
	    } 
	    if (scalar (@{$classhashref->{$subsection}}) >= $max) {
		$compactedhash->{$subsection} = $classhashref->{$subsection};
		@currentOIDs = ();
		$currentfirstdate = "";
		$lastkey = $subsection;
	    } else {
		@currentOIDs = @{$classhashref->{$subsection}};
		$currentfirstdate = $subsection;
		$currentlastdate = $subsection;
	    }
	}
    }

    # add final OIDs to last sub-classification if there aren't many otherwise
    # add final sub-classification
    if (scalar (@currentOIDs) > 0) {
	if ((scalar (@currentOIDs) < $min)) {
	    
	    # want every thing in previous up to the dash
	    my ($newkey) = $lastkey =~ /^([^\-]+)/;
	    @currentOIDs = (@{$compactedhash->{$lastkey}}, @currentOIDs);
	    delete $compactedhash->{$lastkey};
	    @{$compactedhash->{"$newkey-$currentlastdate"}} = @currentOIDs;	
	} else {
	    if ($currentfirstdate eq $currentlastdate) {
		@{$compactedhash->{$currentfirstdate}} = @currentOIDs;
	    } else {
		@{$compactedhash->{"$currentfirstdate-$currentlastdate"}} = @currentOIDs;
	    } 
	}
    }
    
    return $compactedhash;
}

1;
