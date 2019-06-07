###########################################################################
#
# AZList.pm --
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

# classifier plugin for sorting alphabetically

package AZList;

use BaseClassifier;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @AZList::ISA = ('BaseClassifier');
}


my $arguments =
    [ { 'name' => "metadata",
	'desc' => "{AZList.metadata}",
	'type' => "metadata",
	'reqd' => "yes" } ,
      { 'name' => "removeprefix",
	'desc' => "{BasClas.removeprefix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" } ,
      { 'name' => "removesuffix",
	'desc' => "{BasClas.removesuffix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" } 
      ];

my $options = { 'name'     => "AZList",
		'desc'     => "{AZList.desc}",
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

    if (!$self->{"metadata"}) {
	print STDERR "AZList Error: required option -metadata not supplied \n";
	$self->print_txt_usage("");  # Use default resource bundle
	
	die "AZList Error: required option -metadata not supplied\n";
    }
        
    # Manually set $self parameters.
    $self->{'list'} = {};

    # Transfer value from Auto Parsing to the variable name that used in previous GreenStone.
    my $metadata = $self->{"metadata"};
    $metadata = $self->strip_ex_from_metadata($metadata);
    my @meta_list = split(/,/, $metadata);
    $self->{'meta_list'} = \@meta_list;

    $self->{'buttonname'} = $self->generate_title_from_metadata($metadata) unless ($self->{'buttonname'});

    # Further setup 
    if (defined($self->{"removeprefix"}) && $self->{"removeprefix"}) {
	$self->{"removeprefix"} =~ s/^\^//; # don't need a leading ^
    }
    if (defined($self->{"removesuffix"}) && $self->{"removesuffix"}) {
	$self->{"removesuffix"} =~ s/\$$//; # don't need a trailing $
    }

    # Clean out the unused keys
    delete $self->{"metadata"}; # Delete this key

    if($self->{"removeprefix"} eq "") {delete $self->{"removeprefix"};}
    if($self->{"removesuffix"} eq "") {delete $self->{"removesuffix"};}

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
    my $outhandle = $self->{'outhandle'};

    my $metavalue;
    my $metaname;
    # should we extend this to use all available metadata not just the first?
    if (!defined $self->{'meta_list'}) {
	# just in case
	return;
    }

    # find the first available metadata
    foreach my $m (@{$self->{'meta_list'}}) {
	$metavalue = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $m);
	$metaname = $m;
	last if defined $metavalue;
    } 
    
    #if we haven't found a metavalue here, then the doc shouldn't be included
    if (!defined $metavalue || $metavalue eq "") {
	print $outhandle "WARNING: AZList: $doc_OID metadata is empty - not classifying\n";
	return;
    }

    if (defined($self->{'removeprefix'}) &&
	length($self->{'removeprefix'})) {
	$metavalue =~ s/^$self->{'removeprefix'}//;
    }
    if (defined($self->{'removesuffix'}) &&
	length($self->{'removesuffix'})) {
	$metavalue =~ s/$self->{'removesuffix'}$//;
    }
    
    
    $metavalue = &sorttools::format_metadata_for_sorting($metaname, $metavalue, $doc_obj) unless $self->{'no_metadata_formatting'};
	
    if (defined $self->{'list'}->{$doc_OID}) {
	print $outhandle "WARNING: AZList::classify called multiple times for $doc_OID\n";
    } 
    if ($metavalue) {
	$self->{'list'}->{$doc_OID} = $metavalue;
    } else {
	# the formatting has made it empty
	my $outhandle = $self->{'outhandle'};
	print $outhandle "WARNING: AZList: $doc_OID metadata has become empty - not classifying\n";
    }
    
}

sub alpha_numeric_cmp
{
    my ($self,$a,$b) = @_;

    my $title_a = $self->{'list'}->{$a};
    my $title_b = $self->{'list'}->{$b};

    if ($title_a =~ m/^(\d+(\.\d+)?)/)
    {
	my $val_a = $1;
	if ($title_b =~ m/^(\d+(\.\d+)?)/)
	{
	    my $val_b = $1;
	    if ($val_a != $val_b)
	    {
		return ($val_a <=> $val_b);
	    }
	}
    }
    
    return ($title_a cmp $title_b);
}

sub get_classify_info {
    my $self = shift (@_);

    my @classlist 
	= sort { $self->alpha_numeric_cmp($a,$b) } keys %{$self->{'list'}};

    return $self->splitlist (\@classlist);
}

sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $thistype) = @_;
    
    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
			'Title'=>$title,
			'contains'=>[]);
    $classifyinfo{'thistype'} = $thistype 
	if defined $thistype && $thistype =~ /\w/;

    return \%classifyinfo;
}

# splitlist takes an ordered list of classifications (@$classlistref) and splits it
# up into alphabetical sub-sections.
sub splitlist {
    my $self = shift (@_);
    my ($classlistref) = @_;
    my $classhash = {};

    # top level
    my $childtype = "HList";
    if (scalar (@$classlistref) <= 39) {$childtype = "VList";}
    my $classifyinfo = $self->get_entry ($self->{'buttonname'}, $childtype, "Invisible");

    # don't need to do any splitting if there are less than 39 (max + min -1) classifications
    if ((scalar @$classlistref) <= 39) {
	foreach my $subOID (@$classlistref) {
	    push (@{$classifyinfo->{'contains'}}, {'OID'=>$subOID});
	}
	return $classifyinfo;
    }
	
    # first split up the list into separate A-Z and 0-9 classifications
    foreach my $classification (@$classlistref) {
	my $title = $self->{'list'}->{$classification};

	$title =~ s/^(&.{1,6};|<[^>]>|[^a-zA-Z0-9])//g; # remove any unwanted stuff
	# only need first char for classification
	$title =~ m/^(.)/; $title=$1;
	$title =~ tr/[a-z]/[A-Z]/;
	if ($title =~ /^[0-9]$/) {$title = '0-9';}
	elsif ($title !~ /^[A-Z]$/) {
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "AZList: WARNING $classification has badly formatted title ($title)\n";
	}
	$classhash->{$title} = [] unless defined $classhash->{$title};
	push (@{$classhash->{$title}}, $classification);
    }
    $classhash = $self->compactlist ($classhash);

    my @tmparr = ();
    foreach my $subsection (sort keys (%$classhash)) {
	push (@tmparr, $subsection);
    }
    #if there is only one entry here, we suppress the buckets
    if ((scalar @tmparr) == 1) {
	$classifyinfo->{'childtype'} = "VList";
	foreach my $OID (@{$classhash->{$tmparr[0]}}) {
	    push (@{$classifyinfo->{'contains'}}, {'OID'=>$OID});
	}
	return $classifyinfo;
    }
    
    # if there's a 0-9 section it will have been sorted to the beginning
    # but we want it at the end
    if ($tmparr[0] eq '0-9') {
	shift @tmparr;
	push (@tmparr, '0-9');
    }

    foreach my $subclass (@tmparr) {
	my $tempclassify = $self->get_entry($subclass, "VList");
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
    my $currentfirstletter = "";  # start of working bin
    my $currentlastletter = "";   # end of working bin
    my $lastkey = "";             # the name of the last completed key

    # minimum and maximum documents to be displayed per page.
    # the actual maximum will be max + (min-1).
    # the smallest sub-section is a single letter at present
    # so in this case there may be many times max documents
    # displayed on a page.
    my $min = 10; 
    my $max = 30;

    foreach my $subsection (sort keys %$classhashref) {
	if ($subsection eq '0-9') {
	    # leave this bin as-is... copy it straight across
	    @{$compactedhash->{$subsection}} = @{$classhashref->{$subsection}};
	    next;
	}
	$currentfirstletter = $subsection if $currentfirstletter eq "";
	if ((scalar (@currentOIDs) < $min) ||
	    ((scalar (@currentOIDs) + scalar (@{$classhashref->{$subsection}})) <= $max)) {
	    # add this letter to the bin and continue
	    push (@currentOIDs, @{$classhashref->{$subsection}});
	    $currentlastletter = $subsection;
	} else {
	    # too many or too few for a separate bin
	    if ($currentfirstletter eq $currentlastletter) {
		@{$compactedhash->{$currentfirstletter}} = @currentOIDs;
		$lastkey = $currentfirstletter;
	    } else {
		@{$compactedhash->{"$currentfirstletter-$currentlastletter"}} = @currentOIDs;
		$lastkey = "$currentfirstletter-$currentlastletter";
	    } 
	    if (scalar (@{$classhashref->{$subsection}}) >= $max) {
		# this key is now complete. Start a new one
		$compactedhash->{$subsection} = $classhashref->{$subsection};
		@currentOIDs = ();
		$currentfirstletter = "";
		$lastkey = $subsection;
	    } else {
		@currentOIDs = @{$classhashref->{$subsection}};
		$currentfirstletter = $subsection;
		$currentlastletter = $subsection;
	    }
	}
    }

    # add final OIDs to last sub-classification if there aren't many otherwise
    # add final sub-classification
    # BUG FIX: don't add anything if there are no currentOIDs (thanks to Don Gourley)
    if (! scalar(@currentOIDs)) {return $compactedhash;}

    if (scalar (@currentOIDs) < $min) {
	my ($newkey) = $lastkey =~ /^(.)/;
	@currentOIDs = (@{$compactedhash->{$lastkey}}, @currentOIDs);
	delete $compactedhash->{$lastkey};
	@{$compactedhash->{"$newkey-$currentlastletter"}} = @currentOIDs;
    } else {
	if ($currentfirstletter eq $currentlastletter) {
	    @{$compactedhash->{$currentfirstletter}} = @currentOIDs;
	}
	else {
	    @{$compactedhash->{"$currentfirstletter-$currentlastletter"}} =
		@currentOIDs;
	}
    }

    return $compactedhash;
}

1;
