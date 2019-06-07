###########################################################################
#
# AllList.pm -- Creates a single list of all documents. Use by the oaiserver.
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005 New Zealand Digital Library Project
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

package AllList;

use BaseClassifier;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @AllList::ISA = ('BaseClassifier');
}

my $arguments = 
    [
     ];

my $options = { 'name'     => "AllList",
		'desc' => "{AllList.desc}",
	        'abstract' => "yes", # hide from gli
	        'inherits' => "yes" };

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
    $self->{'list'} = [];
    $self->{'buttonname'} = "All Documents";

    return bless $self, $class;
}

sub init {
    my $self = shift (@_);
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    my $doc_OID = $doc_obj->get_OID();
   
    push (@{$self->{'list'}}, $doc_OID);
    
    return;
}


sub get_classify_info {
    my $self = shift(@_);
    my ($no_thistype) = @_;

    my %classifyinfo = ('childtype'   =>'VList',
			'Title'       =>$self->{'buttonname'},
			'contains'    =>[],
			'classifyOID' =>"oai");
    $classifyinfo{'thistype'} = 'Invisible';
    my @list = @{$self->{'list'}};

    my $seqNo = 0;
    foreach my $OID (@list) {
	my $hashref={};
	$hashref->{'OID'}=$OID;
       
	my %tempinfo=('childtype'=>'VList',
		      'Title'=>$self->{'buttonname'},
		      'classifyOID' =>"oai.$seqNo",
		      'contains'    =>[]);

	push (@{$tempinfo{'contains'}}, $hashref);

	push (@{$classifyinfo{'contains'}}, \%tempinfo);
	$seqNo ++;
    }

    return \%classifyinfo;
}
