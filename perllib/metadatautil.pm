###########################################################################
#
# metadatautil.pm -- various useful utilities for dealing with metadata
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

package metadatautil;

use strict;

sub combine_metadata_structures { 
    my ($mdref1, $mdref2) = @_;
    my ($key, $value1, $value2);

    foreach $key (keys %$mdref2) {

	$value1 = $mdref1->{$key};
	$value2 = $mdref2->{$key};
	
	# If there is no existing value for this metadata field in 
	# $mdref1, so we simply copy the value from $mdref2 over.
	if (!defined $value1) {
	    $mdref1->{$key} = &clonedata($value2);
	} 
	# Otherwise we have to add the new values to the existing ones.
	# If the second structure is accumulated, then acculate all the
	# values into the first structure
	elsif ((ref $value2) eq "ARRAY") {
	    # If the first metadata element is a scalar we have to 
	    # convert it into an array before we add anything more.
	    if ((ref $value1) ne 'ARRAY') {
		$mdref1->{$key} = [$value1];
		$value1 = $mdref1->{$key};
	    }
	    # Now add the value(s) from the second array to the first
	    $value2 = &clonedata($value2);
	    push @$value1, @$value2;
	} 
	# Finally, If the second structure is not an array reference, we
	# know it is in override mode, so override the first structure.
	else {
	    $mdref1->{$key} = &clonedata($value2);
	}
    }
}


# Make a "cloned" copy of a metadata value.  
# This is trivial for a simple scalar value,
# but not for an array reference.

sub clonedata {
    my ($value) = @_;
    my $result;

    if ((ref $value) eq 'ARRAY') {
	$result = [];
	foreach my $item (@$value) {
	    push @$result, $item;
	}
    } else {
	$result = $value;
    }
    return $result;
}

sub format_metadata_as_table {
    my ($metadata, $remove_namespace) = @_;
    
    my $text = "<table cellpadding=\"4\" cellspacing=\"0\">\n";
    
    foreach my $field (sort keys(%$metadata)) {
	# $metadata->{$field} may be an array reference
	if ($field eq "gsdlassocfile_tobe") {
	    # ignore
	} else {
	    my $no_ns = $field;
	    if ($remove_namespace) {
		$no_ns =~ s/^\w+\.//;
	    }
	    if (ref ($metadata->{$field}) eq "ARRAY") {
		map { 
		    $text .= "<tr><td valign=top><nobr><b>$no_ns</b></nobr></td><td>".$_."</td></tr>";
		} @{$metadata->{$field}};
	    } else {
		$text .= "<tr><td valign=top><nobr><b>$no_ns</b></nobr></td><td valign=top>$metadata->{$field}</td></tr>\n";
	    }
	}

    }
    $text .= "</table>\n";
    return $text;
}


sub store_saved_metadata
{
    my ($plug,$mname,$mvalue,$md_accumulate) = @_;

    if (defined $plug->{'saved_metadata'}->{$mname}) {
	if ($md_accumulate) {
	    # accumulate mode - add value to existing value(s)
	    if (ref ($plug->{'saved_metadata'}->{$mname}) eq "ARRAY") {
		push (@{$plug->{'saved_metadata'}->{$mname}}, $mvalue);
	    } else {
		$plug->{'saved_metadata'}->{$mname} = 
		    [$plug->{'saved_metadata'}->{$mname}, $mvalue];
	    }
	} else {
	    # override mode
	    $plug->{'saved_metadata'}->{$mname} = $mvalue;
	}
    } else {
	if ($md_accumulate) {
	    # accumulate mode - add value into (currently empty) array
	    $plug->{'saved_metadata'}->{$mname} = [$mvalue];
	} else {
	    # override mode
	    $plug->{'saved_metadata'}->{$mname} = $mvalue;
	}
    }
}


1;
