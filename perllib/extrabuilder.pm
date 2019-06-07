###########################################################################
#
# extrauilder.pm -- inherited from basebuilder, to provide a netural
#                   layer upon which to base extra extension buliders.
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

# With Greenstone extensions increasingly working with multimedia indexing
# this package has been devised to provide a layer that is more neutral to
# the indexing steps performed.  It does this by overriding several methods
# in basebulider.pm that as specific to text-indexing


package extrabuilder;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use basebuilder;

sub BEGIN {
    @extrabuilder::ISA = ('basebuilder');
}


sub new {
    my $class = shift(@_);

    my $self = new basebuilder (@_);
    $self = bless $self, $class;

    return $self;

}

# stuff has been moved here from new, so we can use subclass methods
sub initXX {
    my $self = shift(@_);

    # Override base method to be null to neutral about builderproc indexing
    return;    
}

sub deinitXX {
    my $self = shift (@_);

    # Override base method to be null to be neutral about builderproc indexing
    return;    
}

sub generate_index_list {
    my $self = shift (@_);

    # needs to be defined, due to being called from basebuilder->init()

    return;
}

sub set_sections_index_document_metadata {
    my $self = shift (@_);
    my ($index) = @_;

    # Override base method to null to be neutral about builderproc indexing
    return;    
}


sub set_strip_html {
    my $self = shift (@_);
    my ($strip) = @_;

    # Override base method to be neutral about builderproc indexing
    
    $self->{'strip_html'} = $strip;
    return;    
}

sub compress_text {
    my $self = shift (@_);
    my ($textindex) = @_;

    # Override base method to null to be neutral about builderproc indexing
    return;    
}


sub build_indexes {
    my $self = shift (@_);
    my ($indexname) = @_;
    my $outhandle = $self->{'outhandle'};

    # Override base method to null to be neutral about builderproc indexing
    return;    
}

# for now, orthogonalbuilder subclasses don't support/require make_infodatabase()
sub supports_make_infodatabase {
    return 0;
}

sub make_infodatabase {
    my $self = shift (@_);
    my $outhandle = $self->{'outhandle'};

    # Override base method to null to be neutral about builderproc indexing
    return;    
}

sub make_auxiliary_files {
    my $self = shift (@_);
    my ($index);
    my $build_cfg = {};

    # Override base method to null to be neutral about builderproc indexing
    return;    
}

  
1;

