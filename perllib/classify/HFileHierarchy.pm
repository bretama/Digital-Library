###########################################################################
#
# HFileHierarchy.pm --
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

# classifier plugin for generating hierarchical classifications


package HFileHierarchy;

use BaseClassifier;
use util;
use cfgread;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @HFileHierarchy::ISA = ('BaseClassifier');
}

my $arguments =
    [ { 'name' => "metadata",
	'desc' => "{AZCompactList.metadata}",
	'type' => "metadata",
	'reqd' => "yes" },
      { 'name' => "firstvalueonly",
	'desc' => "{AZCompactList.firstvalueonly}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "allvalues",
	'desc' => "{AZCompactList.allvalues}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "hfile",
	'desc' => "{Hierarchy.hfile}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "sort",
	'desc' => "{Hierarchy.sort}",
	'type' => "metadata",
	'reqd' => "no" },
      { 'name' => "reverse_sort",
	'desc' => "{Hierarchy.reverse_sort}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "hlist_at_top",
	'desc' => "{Hierarchy.hlist_at_top}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "documents_last",
	'desc' => "{Hierarchy.documents_last}",
	'type' => "flag",
	'reqd' => "no"}
      ];

my $options = 
{ 	'name'     => "HFileHierarchy",
	'desc'     => "{HFileHierarchy.desc}",
	'abstract' => "yes",
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

    my $metadata = $self->{'metadata'};
    if (!$metadata) {
	print STDERR "$class Error: required option -metadata not supplied\n";
	$self->print_txt_usage("");  # Use default resource bundle
	
	die "$class Error: required option -metadata not supplied\n";
    }
    
    $self->{'buttonname'} = $self->generate_title_from_metadata($metadata) unless ($self->{'buttonname'});
    # strip ex from metadata
    $metadata = $self->strip_ex_from_metadata($metadata);

    my @meta_list = split(/,/, $metadata);
    $self->{'meta_list'} = \@meta_list;

    # sort = undef in this case is the same as sort=nosort
    if ($self->{'sort'} eq "nosort") {
	$self->{'sort'} = undef;
    }
    if (defined $self->{'sort'}) { # remove ex. namespace
	$self->{'sort'} = $self->strip_ex_from_metadata($self->{'sort'});
    }
	
    if ($self->{'hfile'}) {
	my $hfile = $self->{'hfile'};
	my $subjectfile;  
	$subjectfile = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"etc", $hfile);
	if (!-e $subjectfile) {
	    my $collfile = $subjectfile;
	    $subjectfile = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"etc", $hfile);
	    if (!-e $subjectfile) {
		my $outhandle = $self->{'outhandle'};
		print STDERR "\nHFileHierarchy Error: Can't locate subject file $hfile\n";
		print STDERR "This file should be in $collfile or $subjectfile\n";
		$self->print_txt_usage("");  # Use default resource bundle
		print STDERR "\nHFileHierarchy Error: Can't locate subject file $hfile\n";
		print STDERR "This file should be in $collfile or $subjectfile\n";
		die "\n";
	    }
	}
	$self->{'descriptorlist'} = {}; # first field in subject file
	$self->{'locatorlist'} = {}; # second field in subject file
	$self->{'subjectfile'} = $subjectfile;
    }
    

   # $self->{'firstvalueonly'} = $firstvalueonly;
   # $self->{'allvalues'} = $allvalues;

    #$self->{'hlist_at_top'} = $hlist_at_top;

    # Clean out the unused keys
    delete $self->{'metadata'};
    delete $self->{'hfile'};
    
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    my $subjectfile = $self->{'subjectfile'};
    if (defined $subjectfile) {
	# read in the subject file, but read in unicode mode to preserve special characters
	my $list = &cfgread::read_cfg_file_unicode ($self->{'subjectfile'}, undef, '^[^#]?\S');
	# $list is a hash that is indexed by the descriptor. The contents of this
	# hash is a list of two items. The first item is the OID and the second item
	# is the title
	foreach my $descriptor (keys (%$list)) {
	    $self->{'descriptorlist'}->{$descriptor} = $list->{$descriptor}->[0];
	    unless (defined $self->{'locatorlist'}->{$list->{$descriptor}->[0]}) {
		$self->{'locatorlist'}->{$list->{$descriptor}->[0]}->{'title'} = $list->{$descriptor}->[1];
		$self->{'locatorlist'}->{$list->{$descriptor}->[0]}->{'contents'} = [];
	    }
	}
    }
}

sub hfile_classify
{
    my $self = shift (@_);
    my ($doc_obj,$sortmeta,$metavalues) = @_;

    my $outhandle = $self->{'outhandle'};

    my $doc_OID = $doc_obj->get_OID();

    foreach my $metaelement (@$metavalues) {
	if ((defined $self->{'descriptorlist'}->{$metaelement}) &&
	    (defined $self->{'locatorlist'}->{$self->{'descriptorlist'}->{$metaelement}})) {

	    push (@{$self->{'locatorlist'}->{$self->{'descriptorlist'}->{$metaelement}}->{'contents'}}, 
		  [$doc_OID, $sortmeta]);
	    my $localid = $self->{'descriptorlist'}->{$metaelement};
	    my $classid = $self->get_number();
	    
	    $doc_obj->add_metadata($doc_obj->get_top_section(), "memberof", "CL$classid.$localid");
	    
	}
    }
}




sub hfile_get_classify_info {
    my $self = shift (@_);
    
    my ($classifyinfo) = @_;

    my $list = $self->{'locatorlist'};

    my $classifier_num = "CL".$self->get_number();
    # sorted the keys - otherwise funny things happen - kjdon 03/01/03
    foreach my $OID (sort keys (%$list)) {
	my $tempinfo = $self->get_OID_entry ($OID, $classifyinfo, "$classifier_num.$OID", $list->{$OID}->{'title'}, "VList");
	if (not defined ($tempinfo)) {
	    print STDERR "Error occurred for node $OID. Not creating the classifier \n";
	    return undef;
	}
	if (defined $self->{'sort'}) {
	    if ($self->{'reverse_sort'}) {
		foreach my $subOID (sort {$b->[1] cmp $a->[1];} @{$list->{$OID}->{'contents'}}) {
		    push (@{$tempinfo->{'contains'}}, {'OID'=>$subOID->[0]});
		}
	    }
	    else {
		foreach my $subOID (sort {$a->[1] cmp $b->[1];} @{$list->{$OID}->{'contents'}}) {
		    push (@{$tempinfo->{'contains'}}, {'OID'=>$subOID->[0]});
		}
	    }
	}
	else {
	    foreach my $subOID (@{$list->{$OID}->{'contents'}}) {
		push (@{$tempinfo->{'contains'}}, {'OID'=>$subOID->[0]});
	    }
	}
    }
    
    return $classifyinfo;
}


sub supports_memberof {
    my $self = shift(@_);

    return "true";
}

sub get_OID_entry {
    my $self = shift (@_);
    my ($OID, $classifyinfo, $classifyOID, $title, $classifytype) = @_;

    $OID = "" unless defined $OID;
    $OID =~ s/^\.+//;

    my ($headOID, $tailOID) = $OID =~ /^(\d+)(.*)$/;
    $tailOID = "" unless defined $tailOID;

    if (!defined $headOID) {
	$classifyinfo->{'Title'} = $title;
	$classifyinfo->{'classifyOID'} = $classifyOID;
	$classifyinfo->{'classifytype'} = $classifytype;
	return $classifyinfo;
    }
    if ($headOID eq "0") {
	print STDERR "Error: Hierarchy numbering must not contain 0\n";
	return undef;
    }
    $classifyinfo->{'contains'} = [] unless defined $classifyinfo->{'contains'};
    if ($self->{'documents_last'}) {
	# documents should come after nodes in the classifier

	my $doc_pos = 0;
	foreach my $thing (@{$classifyinfo->{'contains'}}) {
	    last if defined $thing->{'OID'};
	    $doc_pos++;
	}
	
	while ($doc_pos < $headOID) {
	    splice(@{$classifyinfo->{'contains'}}, $doc_pos, 0, $self->get_entry("", $classifytype));
	    $doc_pos++;
	}

	return $self->get_OID_entry ($tailOID, $classifyinfo->{'contains'}->[($headOID-1)], $classifyOID, $title, $classifytype);

    }
    
    # else, documents come before nodes
    my $offset = 0;
    foreach my $thing (@{$classifyinfo->{'contains'}}) {
	$offset ++ if defined $thing->{'OID'};
    }

    while (scalar(@{$classifyinfo->{'contains'}}) < ($headOID+$offset)) { 
	push (@{$classifyinfo->{'contains'}}, $self->get_entry("", $classifytype));
    }

    return $self->get_OID_entry ($tailOID, $classifyinfo->{'contains'}->[($headOID+$offset-1)], $classifyOID, $title, $classifytype);
}

sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $thistype) = @_;
    my $memberof = &supports_memberof();
    
    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
			'Title'=>$title,
			'supportsmemberof'=>$memberof,
			'contains'=>[]);
    $classifyinfo{'thistype'} = $thistype 
	if defined $thistype && $thistype =~ /\w/;

    return \%classifyinfo;
}


1;
