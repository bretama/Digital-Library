###########################################################################
#
# KeyphraseExtractor - helper plugin to extract key phrases
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

package KeyphraseExtractor;

use Kea;
use PrintInfo;
use gsprintf 'gsprintf';

use strict;
no strict 'subs';

BEGIN {
    @KeyphraseExtractor::ISA = ('PrintInfo');
}

my $arguments = [
      { 'name' => "extract_keyphrases",
	'desc' => "{KeyphraseExtractor.extract_keyphrases}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "extract_keyphrases_kea4",
	'desc' => "{KeyphraseExtractor.extract_keyphrases_kea4}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "extract_keyphrase_options",
	'desc' => "{KeyphraseExtractor.extract_keyphrase_options}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" }
		 ];

my $options = { 'name'     => "KeyphraseExtractor",
		'desc'     => "{KeyphraseExtractor.desc}",
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
sub extract_keyphrase_metadata {

    my $self = shift (@_);
    my ($doc_obj) = @_;

    if ($self->{'extract_keyphrases'} || $self->{'extract_keyphrases_kea4'}) {
	$self->extract_keyphrases($doc_obj);
    }

}


#adding kea keyphrases
sub extract_keyphrases
{
    my $self = shift(@_);
    my $doc_obj = shift(@_);

    # Use Kea 3.0 unless 4.0 has been specified
    my $kea_version = "3.0";
    if ($self->{'extract_keyphrases_kea4'}) {
	$kea_version = "4.0";
    }

    # Check that Kea exists, and tell the user where to get it if not
    my $keahome = &Kea::get_Kea_directory($kea_version);
    if (!-e $keahome) {
	gsprintf(STDERR, "{KeyphraseExtractor.missing_kea}\n", $keahome, $kea_version);
	return;
    }

    my $thissection = $doc_obj->get_top_section();
    my $text = "";
    my $list;

    #loop through sections to gather whole doc
    while (defined $thissection) { 
	my $sectiontext = $doc_obj->get_text($thissection);   
	$text = $text.$sectiontext;
	$thissection = $doc_obj->get_next_section ($thissection);
    } 
   
    if($self->{'extract_keyphrase_options'}) { #if kea options flag is set, call Kea with specified options 
	$list = &Kea::extract_KeyPhrases ($kea_version, $text, $self->{'extract_keyphrase_options'});
    } else { #otherwise call Kea with no options
	$list = &Kea::extract_KeyPhrases ($kea_version, $text);
    }
 
    if ($list){
	# if a list of kea keyphrases was returned (ie not empty)
	if ($self->{'verbosity'}) {
	    gsprintf(STDERR, "{KeyphraseExtractor.keyphrases}: $list\n");
	}

	#add metadata to top section
	$thissection = $doc_obj->get_top_section(); 

	# add all key phrases as one metadata
	$doc_obj->add_metadata($thissection, "Keyphrases", $list);

	# add individual key phrases as multiple metadata
	foreach my $keyphrase (split(',', $list)) {
	    $keyphrase =~ s/^\s+|\s+$//g;
	    $doc_obj->add_metadata($thissection, "Keyphrase", $keyphrase);
	}
    }
}

1;
