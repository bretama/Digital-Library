###########################################################################
#
# Browse.pm --
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

package Browse;

use BaseClassifier;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @Browse::ISA = ('BaseClassifier');
}

my $arguments = [
		 ];
my $options = { 'name'     => "Browse",
		'desc'     => "{Browse.desc}",
		'abstract' => "yes",
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
    $self->{'collection'} = $ENV{'GSDLCOLLECTION'}; # classifier information
    $self->{'buttonname'} = "Browse";

    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    
}

sub classify {
    my $self = shift (@_);
   
}

sub get_classify_info {
    my $self = shift (@_);
  

    # Return the information about the classifier that we'll later want to
    # use to create macros when the Phind classifier document is displayed.
    my %classifyinfo = ('thistype'=>'Invisible', 
                        'Title'=>$self->{'buttonname'},
			'contains'=>[]);
    
    my $collection = $self->{'collection'};
    my $url = "library?a=br&c=collection";
    push (@{$classifyinfo{'contains'}}, {'OID'=>$url});
   
    return \%classifyinfo;

 
}


1;
