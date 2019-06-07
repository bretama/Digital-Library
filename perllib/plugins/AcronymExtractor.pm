###########################################################################
#
# AcronymExtractor - helper plugin that extacts acronyms from text 
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

package AcronymExtractor;

use acronym;
use PrintInfo;
use strict;

use gsprintf 'gsprintf';

BEGIN {
    @AcronymExtractor::ISA = ('PrintInfo');
}

my $arguments = [
      { 'name' => "extract_acronyms",
	'desc' => "{AcronymExtractor.extract_acronyms}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "markup_acronyms",
	'desc' => "{AcronymExtractor.markup_acronyms}",
	'type' => "flag",
	'reqd' => "no" } ];

my $options = { 'name'     => "AcronymExtractor",
		'desc'     => "{AcronymExtractor.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists,1);

    return bless $self, $class;

}


# initialise metadata extractors
sub initialise_acronym_extractor {
    my $self = shift (@_);

    if ($self->{'extract_acronyms'} || $self->{'markup_acronyms'}) {
	&acronym::initialise_acronyms();
    }
}

# finalise metadata extractors
sub finalise_acronym_extractor {
    my $self = shift (@_);

    if ($self->{'extract_acronyms'} || $self->{'markup_acronyms'}) {
	&acronym::finalise_acronyms();
    }
}

# extract metadata
sub extract_acronym_metadata {

    my $self = shift (@_);
    my ($doc_obj) = @_;
    

    if ($self->{'extract_acronyms'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $self->extract_acronyms (\$text, $doc_obj, $thissection) if $text =~ /./;
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }
    
    if ($self->{'markup_acronyms'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $text = $self->markup_acronyms ($text, $doc_obj, $thissection);
	    $doc_obj->delete_text($thissection);
	    $doc_obj->add_text($thissection, $text);
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }

}



# extract acronyms from a section in a document. progress is 
# reported to outhandle based on the verbosity. both the Acronym
# and the AcronymKWIC metadata items are created. 

sub extract_acronyms {
    my $self = shift (@_);
    my ($textref, $doc_obj, $thissection) = @_;
    my $outhandle = $self->{'outhandle'};

    # print $outhandle " extracting acronyms ...\n" 
    gsprintf($outhandle, " {AcronymExtractor.extracting_acronyms}...\n")
	if ($self->{'verbosity'} > 2);

    my $acro_array =  &acronym::acronyms($textref);
    
    foreach my $acro (@$acro_array) {

	#check that this is the first time ...
	my $seen_before = "false";
	my $previous_data = $doc_obj->get_metadata($thissection, "Acronym");
	foreach my $thisAcro (@$previous_data) {
	    if ($thisAcro eq $acro->to_string()) {
		$seen_before = "true";
		if ($self->{'verbosity'} >= 4) {
		    gsprintf($outhandle, " {AcronymExtractor.already_seen} " .
			     $acro->to_string() . "\n");
		}
	    }
	}

	if ($seen_before eq "false") {
	    #write it to the file ...
	    $acro->write_to_file();

	    #do the normal acronym
	    $doc_obj->add_utf8_metadata($thissection, "Acronym",  $acro->to_string());
	    gsprintf($outhandle, " {AcronymExtractor.adding} ".$acro->to_string()."\n")
		if ($self->{'verbosity'} > 3);
	}
    }

    gsprintf($outhandle, " {AcronymExtractor.done_acronym_extract}\n")
	if ($self->{'verbosity'} > 2);
}

sub markup_acronyms {
    my $self = shift (@_);
    my ($text, $doc_obj, $thissection) = @_;
    my $outhandle = $self->{'outhandle'};

    gsprintf($outhandle, " {AcronymExtractor.marking_up_acronyms}...\n")
	if ($self->{'verbosity'} > 2);

    #self is passed in to check for verbosity ...
    $text = &acronym::markup_acronyms($text, $self);

    gsprintf($outhandle, " {AcronymExtractor.done_acronym_markup}\n")
	if ($self->{'verbosity'} > 2);

    return $text;
}

1;
