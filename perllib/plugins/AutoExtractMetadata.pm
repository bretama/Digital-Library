###########################################################################
#
# AutoExtractMetadata.pm -- base plugin for all plugins that want to do metadata extraction from text and/or metadata 
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

# This plugin uses the supporting Extractors to add metadata extraction 
# functionality to BaseImporter.


package AutoExtractMetadata;

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use BaseImporter;
use AcronymExtractor;
use KeyphraseExtractor;
use EmailAddressExtractor;
use DateExtractor;
use GISExtractor;

sub BEGIN {
    @AutoExtractMetadata::ISA = ( 'BaseImporter', 'AcronymExtractor', 'KeyphraseExtractor', 'EmailAddressExtractor', 'DateExtractor','GISExtractor' );
}

my $arguments = [
		 {'name' => "first",
		  'desc' => "{AutoExtractMetadata.first}",
		  'type' => "string",
		  'reqd' => "no" }
		 ];


my $options = { 'name'     => "AutoExtractMetadata",
		'desc'     => "{AutoExtractMetadata.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {

    # Start the AutoExtractMetadata Constructor
    my $class = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$auxiliary) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    # load up the options and args for the supporting plugins
    new AcronymExtractor($pluginlist, $inputargs, $hashArgOptLists);
    new KeyphraseExtractor($pluginlist, $inputargs, $hashArgOptLists);
    new EmailAddressExtractor($pluginlist, $inputargs, $hashArgOptLists);
    new DateExtractor($pluginlist, $inputargs, $hashArgOptLists);
    new GISExtractor($pluginlist, $inputargs, $hashArgOptLists);
    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists,$auxiliary);

    return bless $self, $class;
    
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    $self->SUPER::begin(@_);

    #initialise those extractors that need initialisation
    $self->initialise_acronym_extractor();
    $self->initialise_gis_extractor();

}

sub end {
    # potentially called at the end of each plugin pass 
    # import.pl only has one plugin pass, but buildcol.pl has multiple ones

    my ($self) = @_;
    # finalise those extractors that need finalisation
    $self->finalise_acronym_extractor();
}

# here is where we call methods from the supporting extractor plugins 
sub auto_extract_metadata {
    my $self = shift(@_);
    my ($doc_obj) = @_;

    if ($self->{'first'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $self->extract_first_NNNN_characters (\$text, $doc_obj, $thissection) if $text =~ /./;
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }
    $self->extract_acronym_metadata($doc_obj);
    $self->extract_keyphrase_metadata($doc_obj);
    $self->extract_email_metadata($doc_obj);
    $self->extract_date_metadata($doc_obj);
    $self->extract_gis_metadata($doc_obj);

}


# FIRSTNNN: extract the first NNN characters as metadata
sub extract_first_NNNN_characters {
    my $self = shift (@_);
    my ($textref, $doc_obj, $thissection) = @_;
    
    foreach my $size (split /,/, $self->{'first'}) {
	my $tmptext =  $$textref;
	$tmptext =~ s/^\s+//;
	$tmptext =~ s/\s+$//;
	$tmptext =~ s/\s+/ /gs;
	$tmptext = substr ($tmptext, 0, $size);
	$tmptext =~ s/\s\S*$/&#8230;/;
	$doc_obj->add_utf8_metadata ($thissection, "First$size", $tmptext);
    }
}

sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);

    $self->SUPER::clean_up_after_doc_obj_processing();
    $self->GISExtractor::clean_up_temp_files();
}

1;
