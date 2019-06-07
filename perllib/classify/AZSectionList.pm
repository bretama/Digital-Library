###########################################################################
#
# AZSectionList.pm --
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

# classifier plugin for sorting sections alphabetically

# this is very similar to AZList except it sorts by
# section level metadata (excluding the top level)
# instead of just top level metadata

# the only change is to the classify() subroutine which 
# must now iterate through each section, adding each
# to the classification

# 12/05/02 Added usage datastructure - John Thompson

package AZSectionList;

use AZList;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @AZSectionList::ISA = ('AZList');
}

my $arguments = [
		 ];
my $options = { 'name'     => "AZSectionList",
		'desc'     => "{AZSectionList.desc}",
		'abstract' => "no",
		'inherits' => "yes" }; 


sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new AZList($classifierslist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();
    my $thissection = $doc_obj->get_next_section ($doc_obj->get_top_section());

    while (defined $thissection) {
	$self->classify_section ($thissection, $doc_obj);
	$thissection = $doc_obj->get_next_section ($thissection);
    }
}

sub classify_section {
    my $self = shift (@_);
    my ($section, $doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();

    my $metavalue;
    my $metaname;

    if (!defined $self->{'meta_list'}) {
	# just in case
	return;
    }

    # find the first available metadata
    foreach my $m (@{$self->{'meta_list'}}) {
	$metavalue = $doc_obj->get_metadata_element($section, $m);
	$metaname = $m;
	last if defined $metavalue;
    } 

    # if this section doesn't contain the metadata element we're
    # sorting by we won't include it in this classification

    if (defined $metavalue && $metavalue ne "") {
	if ($self->{'removeprefix'}) {
	    $metavalue =~ s/^$self->{'removeprefix'}//;
	}
	
	$metavalue = &sorttools::format_metadata_for_sorting($metaname, $metavalue, $doc_obj) unless $self->{'no_metadata_formatting'};
	if (defined $self->{'list'}->{"$doc_OID.$section"}) {
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "WARNING: AZSectionList::classify called multiple times " .
		"for $doc_OID.$section\n";
	} 
	$self->{'list'}->{"$doc_OID.$section"} = $metavalue;
    }
}


1;
