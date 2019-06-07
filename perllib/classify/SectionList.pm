###########################################################################
#
# SectionList.pm --
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

# Same as SimpleList classifier but includes all sections of document
# (excluding top level) rather than just top level document 
# itself


package SectionList;

use SimpleList;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @SectionList::ISA = ('SimpleList');
}

my $arguments = [];
my $options = { 'name'     => "SectionList",
		'desc'     => "{SectionList.desc}",
		'abstract' => "no",
		'inherits' => "yes" };


sub new { 
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SimpleList($classifierslist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj, @options) = @_;
    
    # @options used by AZCompactList when is uses SectionList internally
    # are we sorting the list??
    my $nosort = 0;
    if (defined $self->{'sort'} && $self->{'sort'} eq "nosort") {
	$nosort = 1;
    }

    my $thissection = undef;

    foreach my $option (@options)
    {
	if ($option =~ m/^section=(\d+)$/i) 
	{
	    $thissection = $1;
	}
    }

    my $sortmeta = "";
    if (!$nosort && defined $self->{'sort'}) {
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

    if (defined $thissection) {
	# just classify the one section
	$self->classify_section($thissection, $doc_obj, $sortmeta, $nosort);
    } else    
    {
	$thissection = $doc_obj->get_next_section ($doc_obj->get_top_section());
	while (defined $thissection) {
	    $self->classify_section($thissection, $doc_obj, $sortmeta, $nosort);
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }
}

sub classify_section {
    my $self = shift (@_);
    my ($section, $doc_obj, $sortmeta, $nosort) = @_;

    my $doc_OID = $doc_obj->get_OID();
    $nosort = 0 unless defined $nosort;
    $sortmeta = "" unless defined $sortmeta;

    my $metavalue;
    my $metaname;
    if (defined $self->{'meta_list'}) {
	# find the first available metadata
	foreach my $m (@{$self->{'meta_list'}}) {
	    $metavalue = $doc_obj->get_metadata_element($section, $m);
	    $metaname = $m;
	    last if defined $metavalue;
	} 
	#if we haven't found a metavalue here, then the section shouldn't be included
	return unless defined $metavalue;
    }
    
    # we know the section should be included, add it now if we are not sorting
    if ($nosort) {
	push (@{$self->{'list'}}, "$doc_OID.$section");
	return;
    }
    # check that it hasn't been added already
    if (defined $self->{'list'}->{"$doc_OID.$section"}) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "WARNING: SectionList::classify called multiple times for $doc_OID.$section\n";
    } 

    if (defined $self->{'sort'}) {
	# sorting on alternative metadata
	$self->{'list'}->{"$doc_OID.$section"} = $sortmeta;
    } else {
	# sorting on the classification metadata
	# do the same formatting on the meta value as for sort meta
	$metavalue = &sorttools::format_metadata_for_sorting($metaname, $metavalue, $doc_obj) unless $self->{'no_metadata_formatting'};
	$self->{'list'}->{"$doc_OID.$section"} = $metavalue;
    }
}
1;
