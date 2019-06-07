###########################################################################
#
# GISExtractor.pm -- extension base class to enhance plugins with GIS capabilities
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

package GISExtractor;

use PrintInfo;

use util;

use gsprintf 'gsprintf';
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

#field categories in DataBase files
#$LAT = 3;
#$LONG = 4;
my $FC = 9;
my $DSG = 10;
#$CC1 = 12;
my $FULL_NAME = 22;

BEGIN {
    @GISExtractor::ISA = ('PrintInfo');
}


my $arguments = 
    [ { 'name' => "extract_placenames",
	'desc' => "{GISExtractor.extract_placenames}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "gazetteer",
	'desc' => "{GISExtractor.gazetteer}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "place_list",
	'desc' => "{GISExtractor.place_list}",
	'type' => "flag",
	'reqd' => "no" } ];


my $options = { 'name'     => "GISExtractor",
		'desc'     => "{GISExtractor.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args' => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    # can we indicate that these are not available if the map data is not there??
    #if (has_mapdata()) {
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    #}

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists, 1);

    return bless $self, $class;

}

sub initialise_gis_extractor {
    my $self = shift (@_);

    if ($self->{'extract_placenames'}) {
	
	my $outhandle = $self->{'outhandle'};
	
	my $places_ref 
	    = $self->loadGISDatabase($outhandle,$self->{'gazetteer'});
	
	if (!defined $places_ref) {
	    print $outhandle "Warning: Error loading mapdata gazetteer \"$self->{'gazetteer'}\"\n";
	    print $outhandle "         No placename extraction will take place.\n";
	    $self->{'extract_placenames'} = undef;
	}
	else {
	    $self->{'places'} = $places_ref;
	}
    }
    
    
}

sub extract_gis_metadata
{
    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    if ($self->{'extract_placenames'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $self->extract_placenames (\$text, $doc_obj, $thissection) if $text =~ /./;
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    } 

}

sub has_mapdata
{
    my $db_dir = &util::filename_cat($ENV{'GSDLHOME'}, "lamp", "data");
    return ( -d $db_dir );
}


#returns a hash table of names from database files (specified in collect.cfg). 
sub loadGISDatabase {
    my $self = shift (@_);
    my ($outhandle,$datasets) = @_;
    my @dbase = map{$_ = $_ . ".txt";} split(/,/, $datasets);
    if(scalar(@dbase)==0) { #default is to include all databases
	@dbase=("UK.txt", "NZ.txt", "NF.txt", "CA.txt", "AS.txt", "GM.txt", "BE.txt", "IN.txt", "JA.txt", "USA.txt");
    }
    my $counter=0;
    my %places = ();
    my @cats = ();	
    while($counter <= $#dbase){ #loop through all the databases
	my $folder = $dbase[$counter];
	$folder =~ s/(.*?)\.txt/$1/;
####		my $dbName = &util::filename_cat($ENV{'GSDLHOME'}, "etc", "mapdata", "data", $folder, $dbase[$counter]);
	my $dbName = &util::filename_cat($ENV{'GSDLHOME'}, "lamp", "data", $folder, $dbase[$counter]);
	if (!open(FILEIN, "<$dbName")) {
	    print $outhandle "Unable to open database $dbName: $!\n";
	    return undef;
	}
	
	my $line = <FILEIN>; #database category details.
	my @catdetails = split("\t", $line);
	
	while ( defined($line = <FILEIN>)){ #stores all place names in file as keys in hash array %places
	    @cats = split("\t", $line);
	    if( #eliminating "bad" place names without missing real ones
		($cats[$FC] eq "A" && !($cats[$DSG] =~ /ADMD|ADM2|PRSH/))
		||($cats[$FC] eq "P" && ($cats[$DSG] =~ /PPLA|PPLC|PPLS/)) 
		||($cats[$FC] eq "H" && ($cats[$DSG] =~ /BAY|LK/)) 
		||($cats[$FC] eq "L" && !($cats[$DSG] =~ /LCTY|RGN/)) 
		||($cats[$FC] eq "T" && ($cats[$DSG] =~ /CAPE|ISL|GRGE/))
		||($dbase[$counter] eq "USA.txt" && ($cats[$DSG] =~ /ppl|island/))
		){$places{$cats[$FULL_NAME]} = [@cats];}
			@cats = ();	
	}	
	close(FILEIN);
	$counter++;	
    }	
    return \%places;
}

#returns a unique hash array of all the places found in a document, along with coordinates, description and country data
sub getPlaces {
    my $self = shift @_;

    my ($textref, $places) = @_;
	my %tempPlaces = ();	
	
	foreach my $plc (%$places){ #search for an occurrence of each place in the text
		if($$textref =~ m/(\W)$plc(\W)/){
			$tempPlaces{$plc} = $places->{$plc};
		}
	}
	#make sure each place is only there once
	my %uniquePlaces = ();
	foreach my $p (keys %tempPlaces) {	
		if(!defined($uniquePlaces{$p})){
			$uniquePlaces{$p} = $tempPlaces{$p};
		}
	}
	return \%uniquePlaces;
}




#returns a lowercase version of the place, with no spaces
sub placename_to_anchorname {
    my $self = shift (@_);
    my ($placename) = @_;
    my $p_tag = lc($placename);
    $p_tag =~ s/\s+//g;
    return $p_tag;
}

#takes a place from the text and wraps an anchor tag, a hyperlink tag and an image tag around it
sub anchor_wrapper {
	my ($p, $p_counter_ref, $path) = @_;
	my $image = "/gsdlgis/gisimages/nextplace.gif";
	my $endTag = "</a>";
	my $hrefTag = "<a href=";
	$$p_counter_ref++;
	my $next = $$p_counter_ref + 1;
	my $p_tag = placename_to_anchorname($p);
	my $place_anchor = "<a name=\"" . $p_tag . $$p_counter_ref . "\">" . $endTag; 
	my $popup_anchor = $hrefTag . "'" . $path . "'>" . $p . $endTag;
	my $image_anchor = $hrefTag . "#" . $p_tag . $next . "><img src=\"" . $image . "\" name=\"img" . $p_tag . $$p_counter_ref . "\" border=\"0\">" . $endTag;
	return $place_anchor . $popup_anchor . $image_anchor;
}

#takes dangerous place names and checks if they are part of another placename or not.
sub place_name_check {
	my ($pre, $preSpace, $p, $postSpace, $post, $p_counter_ref, $path, $y) = @_;
	if($pre =~ /$y/ || $post =~ /$y/) {return $pre . $preSpace . $p . $postSpace . $post;}
	$pre = $pre . $preSpace;
	$post = $postSpace . $post;
	return $pre . &anchor_wrapper("", $p, "", $p_counter_ref, $path) . $post;
}

sub extract_placenames {
    my $self = shift (@_);
    my ($textref, $doc_obj, $thissection) = @_;
    my $outhandle = $self->{'outhandle'};

    my $GSDLHOME = $ENV{'GSDLHOME'};
    #field categories in DataBase file for extract_placenames.
    my $LAT = 3;
    my $LONG = 4;
    my $CC1 = 12;

    
    &gsprintf($outhandle, " {GISExtractor.extracting_placenames}...\n")
	if ($self->{'verbosity'} > 2);

    #get all the places found in the document	
    my $uniquePlaces = $self->getPlaces($textref, $self->{'places'});
       
    #finds 'dangerous' placenames (eg York and New York). Dangerous because program will find "York" within "New York"  
    my %danger = ();    
    foreach my $x (keys %$uniquePlaces){
	foreach my $y (keys %$uniquePlaces){
		if(($y =~ m/ /) && ($y =~ m/$x/) && ($y ne $x)){
			$y =~ s/($x\s)|(\s$x)//;
			$danger{$x} = $y;
		}
	}
    }  
      
    #creates a list of clickable placenames at top of page, linked to first occurrence of name, and reads them into a file 
    my $tempfname = $doc_obj;
    $tempfname =~ s/.*\(0x(.*)\)/$1/;
    my $names = "";
    my $filename = "tmpfile" . $tempfname;
    my $tempfile = &util::filename_cat($GSDLHOME, "tmp", $filename);
    open(FOUT, ">$tempfile") || die "Unable to create a temp file: $!";	
    foreach my $name (sort (keys %$uniquePlaces)){
	if(!defined($danger{$name})){
		my $name_tag = placename_to_anchorname($name);
		print FOUT "$name\t" . $uniquePlaces->{$name}->[$LONG] . "\t" . $uniquePlaces->{$name}->[$LAT] . "\n";
		if($self->{'place_list'}) {$names = $names . "<a href=\"#" . $name_tag . "1\">" . $name . "</a>" . "\n";}
	}
    }
    close(FOUT);
    $doc_obj->associate_file($tempfile, "places.txt", "text/plain");
    $self->{'places_filename'} = $tempfile;
    
    my %countries = ();
    
    foreach my $p (keys %$uniquePlaces){
	my $place = $p;
	$place =~ s/\s+|\n+|\r+|\t+/(\\s+)/g;
	my $cap_place = uc($place);	
	my $long = $uniquePlaces->{$p}->[$LONG];
	my $lat = $uniquePlaces->{$p}->[$LAT];
	my $country = $uniquePlaces->{$p}->[$CC1];
	my $path = "javascript:popUp(\"$long\",\"$lat\",\"$p\",\"$country\")";
	my $p_counter = 0;
	
	if(!defined($danger{$p})){	
		#adds html tags to each place name
		$$textref =~ s/\b($place|$cap_place)\b/&anchor_wrapper($1,\$p_counter,$path)/sge;
	} 
	#else {
	#$y = $danger{$p};
	#$$textref =~ s/(\w+)(\s+?)($place|$cap_place)(\s+?)(\w+)/&place_name_check($1,$2,$3,$4,$5,\$p_counter,$path, $y)/sge;  
	#}
	
	#edits the last place's image, and removes image if place only occurres once.
	my $p_tag = placename_to_anchorname($p);
	$p_counter++;
	$$textref =~ s/#$p_tag$p_counter(><img src="\/gsdl\/images\/)nextplace.gif/#${p_tag}1$1firstplace.gif/;
	$$textref =~ s/<img src="\/gsdl\/images\/firstplace.gif" name="img$p_tag(1)" border="0">//;
	
	#this line removes apostrophes from placenames (they break the javascript function)
	$$textref =~ s/(javascript:popUp.*?)(\w)'(\w)/$1$2$3/g; #' (to get emacs colours back)
		
	#for displaying map of document, count num of places from each country
	if(defined($countries{$country})){$countries{$country}++;}
	else{$countries{$country} = 1;}

	#adds placename to metadata
	$doc_obj->add_utf8_metadata ($thissection, "Placename", $p);	
	&gsprintf($outhandle, "  {AutoExtractMetadata.extracting} $p\n")
		if ($self->{'verbosity'} > 3); 
    }
    #finding the country that most places are from, in order to display map of the document
    my $max = 0;
    my $CNTRY = "";
    foreach my $c_key (keys %countries){
	if($countries{$c_key} > $max){
		$max = $countries{$c_key};
		$CNTRY = $c_key;
	}
    }
    #allows user to view map with all places from the document on it
####    my $places_filename = &util::filename_cat($GSDLHOME, "collect", "_cgiargc_", "index", "assoc", "_thisOID_", "places.txt");
    my $places_filename = &util::filename_cat("collect", "_cgiargc_", "index", "assoc", "_thisOID_", "places.txt");
    my $docmap = "<a href='javascript:popUp(\"$CNTRY\",\"$places_filename\")'>View map for this document<\/a><br><br>\n";
    $$textref = $docmap . $names . "<br>" . $$textref;
    
    $doc_obj->delete_text($thissection);
    $doc_obj->add_utf8_text($thissection, $$textref);
    &gsprintf($outhandle, " {GISExtractor.done_places_extract}\n")
	if ($self->{'verbosity'} > 2);
}

sub clean_up_temp_files {
    my $self = shift(@_);
    
    if(defined($self->{'places_filename'}) && -e $self->{'places_filename'}){
	&util::rm($self->{'places_filename'});
    }
    $self->{'places_filename'} = undef;

}
