###########################################################################
#
# docprint.pm --
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

# This is used to output an XML representation of a doc_obj - this will be 
# Greenstone XML format.
# This is used by GreenstoneXMLPlugout and doc.pm

package docprint;

use strict;

sub get_section_xml {
    
    my ($doc_obj, $section) = @_;

    my $section_ptr = $doc_obj->_lookup_section ($section);
    return "" unless defined $section_ptr;

    my $all_text = "<Section>\n";
    $all_text .= "  <Description>\n";
    
    # output metadata
    foreach my $data (@{$section_ptr->{'metadata'}}) {
	my $escaped_value = &escape_text($data->[1]);
	$all_text .= '    <Metadata name="' . $data->[0] . '">' . $escaped_value . "</Metadata>\n";
    }

    $all_text .= "  </Description>\n";

    # output the text
    $all_text .= "  <Content>";
    $all_text .= &escape_text($section_ptr->{'text'});
    $all_text .= "</Content>\n";
    
    # output all the subsections
    foreach my $subsection (@{$section_ptr->{'subsection_order'}}) {
	$all_text .= &get_section_xml($doc_obj, "$section.$subsection");
    }
    
    $all_text .=  "</Section>\n";

    # make sure no nasty control characters have snuck through
    # (XML::Parser will barf on anything it doesn't consider to be
    # valid UTF-8 text, including things like \c@, \cC etc.)
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}

sub escape_text {
    my ($text) = @_;
    # special characters in the xml encoding
    $text =~ s/&&/& &/g;
    $text =~ s/&/&amp;/g; # this has to be first...
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\"/&quot;/g;

    return $text;
}

1;
