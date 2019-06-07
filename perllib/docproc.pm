###########################################################################
#
# docproc.pm --
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

# document processors are used by the document reader plugins
# to do some processing on some documents

package docproc;

use strict;


sub new {
    my ($class) = @_;
    my $self = {};

    $self->{'OIDtype'} = "hash";
    $self->{'saveas'} = "GreenstoneXML";  # default

    return bless $self, $class;
}

sub process {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    die "docproc::process function must be implemented in sub classes\n";
}

# OIDtype may be "hash" or "incremental" or "dirname" or "assigned"
sub set_OIDtype {
    my $self = shift (@_);
    my ($type, $metadata) = @_;

    if ($type =~ /^(hash|hash_on_full_filename|incremental|filename|dirname|full_filename|assigned)$/) {
	$self->{'OIDtype'} = $type;
    } else {
	$self->{'OIDtype'} = "hash";
    }
    if ($type =~ /^assigned$/) {
	if (defined $metadata) {
	    $self->{'OIDmetadata'} = $metadata;
	} else {
	    $self->{'OIDmetadata'} = "dc.Identifier";
	}
    }
}

sub set_saveas {
    my $self = shift (@_);
    my ($saveas) = @_;

    $self->{'saveas'} = $saveas;

}

sub set_saveas_version {
    my $self = shift (@_);
    my ($saveas_version) = @_;

    $self->{'saveas_version'} = $saveas_version;

}


1;







