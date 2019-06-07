###########################################################################
#
# ReferPlugin.pm - a plugin for bibliography records in Refer format
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 2000 Gordon W. Paynter
# Copyright 1999-2000 New Zealand Digital Library Project
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

# ReferPlugin reads bibliography files in Refer format.
#
# by Gordon W. Paynter (gwp@cs.waikato.ac.nz), November 2000
#
# Loosely based on hcibib2Plug by Steve Jones (stevej@cs.waikato.ac.nz).
# Which was based on EMAILPlug by Gordon Paynter (gwp@cs.waikato.ac.nz).
# Which was based on old versions of HTMLplug and HCIBIBPlugby by Stefan
# Boddie and others -- it's hard to tell what came from where, now.
#
#
# ReferPlugin creates a document object for every reference in the file.
# It is a subclass of SplitTextFile, so if there are multiple records, all
# are read.
#
# Document text:
#   The document text consists of the reference in Refer format
#
# Metadata:
#	$Creator	%A	Author name
#	$Title		%T	Title of article of book
#	$Journal	%J	Title of Journal
#	$Booktitle	%B	Title of book containing the publication
#	$Report		%R	Type of Report, paper or thesis
#	$Volume		%V	Volume Number of Journal
#	$Number		%N	Number of Journal within Volume
#	$Editor		%E	Editor name
#	$Pages		%P	Page Number of article
#	$Publisher	%I	Name of Publisher
#	$Publisheraddr	%C	Publisher's address
#	$Date		%D	Date of publication
#	$Keywords	%K	Keywords associated with publication 
#	$Abstract	%X	Abstract of publication
#	$Copyright	%*	Copyright information for the article
#

package ReferPlugin;

use SplitTextFile;
use MetadataRead;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# ReferPlugin is a sub-class of BaseImporter.
sub BEGIN {
    @ReferPlugin::ISA = ('MetadataRead', 'SplitTextFile');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_split_exp() } 
      ];

my $options = { 'name'     => "ReferPlugin",
		'desc'     => "{ReferPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };

# This plugin processes files with the suffix ".bib"
sub get_default_process_exp {
    return q^(?i)\.bib$^;
}

# This plugin splits the input text at blank lines
sub get_default_split_exp {
    return q^\n\s*\n^;
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

# The process function reads a single bibliographic record and stores
# it as a new document.

sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    # Check that we're dealing with a valid Refer file
    return undef unless ($$textref =~ /^\s*%/);

    my $cursection = $doc_obj->get_top_section();

    my %field = ('H', 'Header',
		 'A', 'Creator',
		 'T', 'Title',
		 'J', 'Journal',
		 'B', 'Booktitle',
		 'R', 'Report',
		 'V', 'Volume',
		 'N', 'Number',
		 'E', 'Editor',
		 'P', 'Pages',
		 'I', 'Publisher',
		 'C', 'PublisherAddress',
		 'D', 'Date',
		 'O', 'OtherInformation',
		 'K', 'Keywords',
		 'X', 'Abstract',
		 '*', 'Copyright');

    # Metadata fields 
    my %metadata;
    my ($id, $Creator, $Keywords, $text);
    my @lines = split(/\n+/, $$textref);

    
    # Read and process each line in the bib file.
    # Each file consists of a set of metadata items, one to each line
    # with the Refer key followed by a space then the associated data
    foreach my $line (@lines) {
	
	# Add each line.  Most lines consist of a field identifer and
	# then data, and we simply store them, though we treat some
	# of the fields a bit differently.

	$line =~ s/\s+/ /g;
	$text .= "$line\n";
	# $ReferFormat .= "$line\n"; # what is this???
	
	next unless ($line =~ /^%[A-Z\*]/);
	$id = substr($line,1,1);
	$line =~ s/^%. //;
   	
	# Add individual authors in "Lastname, Firstname" format.
	# (The full set of authors will be added below as "Creator".)
	if ($id eq "A") {

	    # Reformat and add author name
	    my @words = split(/ /, $line);
	    my $lastname = pop @words;
	    my $firstname = join(" ",  @words);
	    my $fullname = $lastname . ", " . $firstname;
	    
	    # Add each name to set of Authors
	    if ($fullname =~ /\w/) {
		$fullname = &text_into_html($fullname);
		$doc_obj->add_metadata ($cursection, "Author", $fullname);
	    }
	}

	# Add individual keywords.
	# (The full set of authors will be added below as "Keywords".)
	if ($id eq "K") {
	    my @keywordlist = split(/,/, $line);
	    foreach my $k (@keywordlist) {
		$k = lc($k);
		$k =~ s/\s*$//; 
		$k =~ s/^\s*//; 
		if ($k =~ /\w/) {
		    $k = &text_into_html($k);
		    $doc_obj->add_metadata ($cursection, "Keyword", $k);
		}
	    } 
	}
	
	# Add this line of metadata
	$metadata{$id} .= "$line\n";
    }



    # Add the various field as metadata
    my ($f, $name, $value);
    foreach $f (keys %metadata) {
	
	next unless (defined $field{$f});
	next unless (defined $metadata{$f});	

	$name = $field{$f};
	$value = $metadata{$f};

	# Add the various field as metadata	
	
	# The Creator metadata is found by concatenating authors.
	if ($f eq "A") {

	    my @authorlist = split(/\n/, $value);
	    my $lastauthor = pop @authorlist;
	    my $Creator = "";
	    if (scalar @authorlist) {
		$Creator = join(", ", @authorlist) . " and $lastauthor";
	    } else {
		$Creator = $lastauthor;
	    }

	    if ($Creator =~ /\w/) {
		$Creator = &text_into_html($Creator);
		$doc_obj->add_metadata ($cursection, "Creator", $Creator);
	    }
	}

	# The rest are added in a standard way
	else {
	    $value = &text_into_html($value);
	    $doc_obj->add_metadata ($cursection, $name, $value);
	}

	# Books and Journals are additionally marked for display purposes
	if ($f eq "B") {
	    $doc_obj->add_metadata($cursection, "BookConfOnly", 1);
	} elsif ($f eq "J") {
	    $doc_obj->add_metadata($cursection, "JournalsOnly", 1); 
	}


    }

    # Add the text in refer format(all fields)
    if ($text =~ /\w/) {
	$text = &text_into_html($text);
	$doc_obj->add_text ($cursection, $text);
    }
    # Add FileFormat as the metadata
    $doc_obj->add_metadata($cursection,"FileFormat","Refer");

    return 1; # processed the file
}

1;
#
# Convert a text string into HTML.
#
# The HTML is going to be inserted into a GML file, so 
# we have to be careful not to use symbols like ">",
# which ocurs frequently in email messages (and use
# &gt instead.
#
# This function also turns links and email addresses into hyperlinks,
# and replaces carriage returns with <BR> tags (and multiple carriage
# returns with <P> tags).
#

sub text_into_html {
    my ($text) = @_;


    # Convert problem charaters into HTML symbols
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\"/&quot;/g;
    $text =~ s/\'/ /g;
    $text =~ s/\+/ /g;
    $text =~ s/\(/ /g;
    $text =~ s/\)/ /g;

    # convert email addresses and URLs into links
    $text =~ s/([\w\d\.\-]+@[\w\d\.\-]+)/<a href=\"mailto:$1\">$1<\/a>/g;
    $text =~ s/(http:\/\/[\w\d\.\-]+[\/\w\d\.\-]*)/<a href=\"$1">$1<\/a>/g;

    # Clean up whitespace and convert \n charaters to <BR> or <P>
    $text =~ s/ +/ /g;
    $text =~ s/\s*$//; 
    $text =~ s/^\s*//; 
    $text =~ s/\n/\n<BR>/g;
    $text =~ s/<BR>\s*<BR>/<P>/g;

    return $text;
}


