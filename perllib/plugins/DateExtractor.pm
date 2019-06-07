###########################################################################
#
# DateExtractor - helper plugin that extracts historical dates from text
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2008 New Zealand Digital Library Project
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

package DateExtractor;

use DateExtract;
use PrintInfo;
use strict;

BEGIN {
    @DateExtractor::ISA = ('PrintInfo');
}

my $arguments = [
      { 'name' => "extract_historical_years",
	'desc' => "{DateExtractor.extract_historical_years}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "maximum_year",
	'desc' => "{DateExtractor.maximum_year}",
	'type' => "int",
	'deft' => (localtime)[5]+1900,
	'char_length' => "4",
	#'range' => "2,100",
	'reqd' => "no"},
      { 'name' => "maximum_century",
	'desc' => "{DateExtractor.maximum_century}",
	'type' => "string",
	'deft' => "-1",
	'reqd' => "no" },
      { 'name' => "no_bibliography",
	'desc' => "{DateExtractor.no_bibliography}",
	'type' => "flag",
	'reqd' => "no"},
		 ];

my $options = { 'name'     => "DateExtractor",
		'desc'     => "{DateExtractor.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists, 1);

    return bless $self, $class;

}


# extract metadata
sub extract_date_metadata {

    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    if($self->{'extract_historical_years'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {

	    my $text = $doc_obj->get_text($thissection);
	    &DateExtract::get_date_metadata($text, $doc_obj, 
					    $thissection, 
					    $self->{'no_bibliography'}, 
					    $self->{'maximum_year'}, 
					    $self->{'maximum_century'});
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }
}


1;
