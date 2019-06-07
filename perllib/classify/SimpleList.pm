###########################################################################
#
# SimpleList.pm --
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
# to see the options, run "perl -S classinfo.pl SimpleList"

use BaseClassifier;
package SimpleList;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use sorttools;

sub BEGIN {
    @SimpleList::ISA = ('BaseClassifier');
}

my $arguments = 
    [ { 'name' => "metadata",
	'desc' => "{SimpleList.metadata}",
	'type' => "metadata",
	'reqd' => "no" },
      { 'name' => "sort",
	'desc' => "{SimpleList.sort}",
	'type' => "metadata",
	'reqd' => "no" } ];

my $options = { 'name'     => "SimpleList",
		'desc'     => "{SimpleList.desc}",
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

    # Transfer value from Auto Parsing to the variable name that used in previous GreenStone.
    my (@meta_list,$meta1);
    if ($self->{"metadata"}) {
	# strip off ex.
	$self->{"metadata"} = $self->strip_ex_from_metadata($self->{'metadata'});
	@meta_list = split(/,|;/, $self->{"metadata"});
	$meta1 = $meta_list[0];
	$self->{'meta_list'} = \@meta_list;
    } else {
	$meta1=undef;
	@meta_list = undef;
    }

    if (!$self->{"buttonname"}) {
	if (defined ($self->{'metadata'})) {
	    $self->{"buttonname"} = $self->generate_title_from_metadata($self->{'metadata'});
	} else {
	    $self->{"buttonname"} = 'List';
	}
    }

    # Further setup
    # $self->{"sort"} is handled a bit differently - kjdon
    # undef means to sort, but use the metadata value from -metadata
    # because there is no one metadata value to get for sorting when 
    # we have a list of possible metadata
    # to get no sorting, set $self->{"sort"} = 'nosort'
    if (!$self->{"sort"}) {
	if (defined ($self->{"metadata"})) {
	    $self->{"sort"} = undef;
	} else {
	    $self->{"sort"} = "nosort";
	}
    }    
    if (defined $self->{'sort'}) {
	$self->{'sort'} = $self->strip_ex_from_metadata($self->{'sort'});
    }
    if (defined  $self->{"sort"} &&  $self->{"sort"} eq "nosort") {
	$self->{'list'} = [];
    } else {
	$self->{'list'} = {};
    }
        
    # Clean out the unused keys
    delete $self->{"metadata"}; # Delete this key
    
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();


    # are we sorting the list??
    my $nosort = 0;
    if (defined $self->{'sort'} && $self->{'sort'} eq "nosort") {
	$nosort = 1;
    }
    
    my $metavalue;
    my $metaname;
    if (defined $self->{'meta_list'}) {
	my $topsection=$doc_obj->get_top_section();

	# find the correct bit of metadata, if multi-valued metadata field
	if (exists $doc_obj->{'mdoffset'}) { # set by AZCompactList

	    my $mdoffset=$doc_obj->{'mdoffset'} - 1;
	    
	    foreach my $m (@{$self->{'meta_list'}}) {
		my $values_listref=
		    $doc_obj->get_metadata($topsection, $m);
		my $array_size = scalar(@{$values_listref});
		if ($array_size==0 || $array_size < $mdoffset+1) {
		    $mdoffset = $mdoffset - $array_size;
		} else {
		    $metaname = $m;
		    # get the correct value using the offset
		    $metavalue=@$values_listref[$mdoffset];
                    # use a special format for docOID...
		    $doc_OID .= ".offset$mdoffset";
		    last;
		}
	    }
	} else {
	    # use the first available metadata
	    foreach my $m (@{$self->{'meta_list'}}) {
		$metavalue = $doc_obj->
		    get_metadata_element($topsection, $m);
		$metaname = $m;
		last if defined $metavalue;
	    }
	} 
	# if we haven't found a metavalue, then the doc shouldn't be included
	return unless defined $metavalue;
    }
    
    # we know the doc should be included, add it now if we are not sorting
    if ($nosort) {
	push (@{$self->{'list'}}, $doc_OID);
	return;
    }

    #check for a sort element other than our metadata
    if (defined $self->{'sort'}) {
	my $sortmeta;
	if ($self->{'sort'} =~ /^filename$/i) {
	    $sortmeta = $doc_obj->get_source_filename();
	} else {
	    $sortmeta = $doc_obj->get_metadata_element($doc_obj->get_top_section(), $self->{'sort'});
	    if (defined $sortmeta && !$self->{'no_metadata_formatting'}) {
		$sortmeta = &sorttools::format_metadata_for_sorting($self->{'sort'}, $sortmeta, $doc_obj);
	    }
	}
	$sortmeta = "" unless defined $sortmeta;
	$self->{'list'}->{$doc_OID} = $sortmeta;
    } else {
	# we add to the list based on metadata value
	# but we need to do the same formatting as for sort value
	($metavalue) = &sorttools::format_metadata_for_sorting($metaname, $metavalue, $doc_obj) unless $self->{'no_metadata_formatting'};
	$self->{'list'}->{$doc_OID} = $metavalue;
    }
    my $id = $self->get_number();
    $doc_obj->add_metadata($doc_obj->get_top_section(), "memberof", "CL$id");
}


sub get_classify_info {
    my $self = shift (@_);
    my ($gli, $no_thistype) = @_;
    $no_thistype = 0 unless defined $no_thistype;
    my $memberof = &supports_memberof();

    my @list = ();
    if (defined $self->{'sort'} && $self->{'sort'} eq "nosort") {
	@list = @{$self->{'list'}};
    } else {
	if (keys %{$self->{'list'}}) {
	    @list = sort {$self->{'list'}->{$a} 
			  cmp $self->{'list'}->{$b};} keys %{$self->{'list'}};
	}	
    }
    # organise into classification structure
    my %classifyinfo = ('childtype'=>'VList',
			'Title'=>$self->{'buttonname'},
			'contains'=>[]);
    $classifyinfo{'thistype'} = 'Invisible' unless $no_thistype;
    # always supports memberof
    $classifyinfo{'supportsmemberof'} = $memberof;

    foreach my $OID (@list) {
	my $hashref={};
	# special oid format, if using offsets (from AZCompactList)
	if ($OID =~ s/\.offset(\d+)$//) {
	    $hashref->{'offset'}=$1;
	}
	$hashref->{'OID'}=$OID;

	push (@{$classifyinfo{'contains'}}, $hashref);
    }

    return \%classifyinfo;
}

sub supports_memberof {
    my $self = shift(@_);

    return "true";
}

1;




