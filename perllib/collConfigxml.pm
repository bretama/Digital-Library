###########################################################################
#
# collConfigxml.pm --
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

# reads in configuration files of xml form

package collConfigxml;
use strict;
no strict 'refs';
no strict 'subs';

use XMLParser;

# A mapping hash to resolve name discrepancy between gs2 and gs3.
# the first item is the gs3 element name from collectionConfig, the second one
# is the internal name for the option
my $nameMap = {"key" => "value",
	       "creator" => "creator",
	       "maintainer" => "maintainer",
	       "public" => "public",
	       "infodb" => "infodbtype",
	       "defaultIndex" => "defaultindex",
	       "defaultLevel" => "defaultlevel",
	       "name" => "collectionname",
	       "description" => "collectionextra",
	       "smallicon" => "iconcollectionsmall",
	       "icon" => "iconcollection",
	       "level" => "levels",
	       "classifier" => "classify",
	       "indexSubcollection" => "indexsubcollections",
	       "indexLanguage" => "languages",
	       "defaultIndexLanguage" => "defaultlanguage",
	       "index" => "indexes",
	       "indexfieldoptions" => "indexfieldoptions",
	       "sort" => "sortfields",
	       "defaultSort" => "defaultsort",
	       "facet" => "facetfields", 
	       "plugin" => "plugin",
	       "plugout" => "plugout",
	       "indexOption" => "indexoptions",
	       "searchType" => "searchtype",
	       "languageMetadata" => "languagemetadata",
	       "buildType" => "buildtype",
	       "orthogonalBuildTypes" => "orthogonalbuildtypes",
	       };
# A hash structure which is returned by sub read_cfg_file.
my $data = {};

my $repeatedBlock = q/^(browse|pluginList)$/; 

# use those unique attribute values to locate the text within the elements
# creator, public, maintainer and within a displayItem.
my $currentLocation = "";
my $stringexp = q/^(creator|maintainer|public|buildType)$/;
my $displayItemNames = q/^(name|description)$/;
  
# these options get set at top level
my $topleveloptionexp = q/^(importOption|buildOption)$/;

# For storing the attributes during the StartTag subroutine, so that 
# we can use it later in Text (or EndTag) subroutines
my $currentAttrRef = undef; 

my $currentLevel = "";

# Count the elements with same name within the same block
# ("plugin", "option")
my $currentIndex = 0;

my $structexp = q/^(index)$/;
# structexp contains a hashmap of option(name, value) pairs per index name like allfields/ZZ or titles/TI
# e.g. <index name="allfields">
#	 <displayItem ... />
#	 <option name="solrfieldtype" value="text_ja" />
#      </index>

my $arrayexp = q/^(sort|facet|level|indexOption|indexSubcollection|indexLanguage|orthogonalBuildTypes)$/; 
#my $arrayexp = q/^(index|sort|facet|level|indexOption|indexSubcollection|indexLanguage|orthogonalBuildTypes)$/; 
my $arrayarrayexp = q/^(plugin|classifier)$/; #|buildOption)$/;
my $hashexp = q/^(subcollection)$/; # add other element names that should be represented by hash expressions here
my $hashhashexp = q/^(displayItem)$/; # add other (collectionmeta) element names that should be represented by hashes of hashes here.

my $defaults = q/^(defaultIndex|defaultLevel|defaultSort|defaultIndexLanguage|languageMetadata)$/;

# Reads in the model collection configuration file, collectionConfig.xml,
# into a structure which complies with the one used by gs2 (i.e. one read
# in by &cfgread::read_cfg_file).
sub read_cfg_file {
    my ($filename) = @_;
    $data = {};
    if ($filename !~ /collectionConfig\.xml$/ || !-f $filename) {
        return undef;
    }

    # Removed ProtocolEncoding (see MetadataXMLPlugin for details)

    # create XML::Parser object for parsing metadata.xml files
    my $parser = new XML::Parser('Style' => 'Stream',
				 'Pkg' => 'collConfigxml',
				 'Handlers' => {'Char' => \&Char,
						 'Doctype' => \&Doctype
						 });
    if (!open (COLCFG, $filename)) {
	print STDERR "cfgread::read_cfg_file couldn't read the cfg file $filename\n";
    } else {

      $parser->parsefile ($filename);# (COLCFG);
      close (COLCFG);
    }

    #&Display; 
    return $data;
}

sub StartTag {
# Those marked with #@ will not be executed at the same time when this sub is being called
# so that if/elsif is used to avoid unnecessary tests
    my ($expat, $element) = @_;
    
    # See http://search.cpan.org/~msergeant/XML-Parser-2.36/Parser.pm#Stream
    # %_ is a hash of all the attributes of this element, we want to store them so we can use the attributes
    # when the textnode contents of the element are parsed in the subroutine Text (that's the handler for Text). 
    $currentAttrRef = \%_; 

    my $name = $_{'name'};
    my $value = $_{'value'};
    my $type = $_{'type'};
    my $orthogonal = $_{'orthogonal'};

    # for subcollections
    my $filter = $_{'filter'};
    
    # was this just a flax thing??
    my $assigned = $_{'assigned'};
    
    #@ Marking repeated block
    if ($element =~ /$repeatedBlock/) {
	$currentIndex = 0;
    }

    #@ handling block metadataList
    elsif (defined $name and $name =~ /$stringexp/){
      $currentLocation = $name;
    }
    #@ handling default search index/level/indexLanguage and languageMetadata
    elsif ($element =~ /$defaults/) {
      if (defined $name and $name =~ /\w/) {
	$data->{$nameMap->{$element}} = $name;
      }
    }

    #@ handling the displayItems name and description (known as collectionname and collectionextra in GS2)
    elsif($element eq "displayItemList") {
	$currentLevel = "displayItemList"; # storing the parent if it is displayItemList
    } 
    elsif($element =~ /$hashhashexp/) { # can expand on this to check for other collectionmeta elements
	if((!defined $assigned) || (defined $assigned and $assigned =~ /\w/ and $assigned eq "true")) {
	    # either when there is no "assigned" attribute, or when assigned=true (for displayItems):
	    $currentLocation = $name;
	}
    }

    #@ Handling database type: gdbm or gdbm-txtgz, later jdbm.
    elsif ($element eq "infodb") {
      $data->{'infodbtype'} = $type;
    }
    
    #@ Handling indexer: mgpp/mg/lucene; stringexp
    #@ Handling orthogonal indexers: audioDB; arrayexp
    elsif ($element eq "search") {
	if ((defined $orthogonal) && ($orthogonal =~ m/^(true|on|1)$/i)) {
	    push(@{$data->{'orthogonalbuildtypes'}},$type);
	}
	else {
	    $data->{'buildtype'} = $type;
	}
    }
	
    elsif ($element eq "store_metadata_coverage")
    {
##	print STDERR "*&*&*&*&*& HERE &*&*&*&*&*&*";
	$data->{'store_metadata_coverage'} = $value;
    }

    #@ Handling searchtype: plain,form; arrayexp
    #elsif ($element eq "format" and defined $name and $name =~ /searchType/) {
	#@ Handling searchtype: plain, form
	#$currentLocation = $name;	
    #}
 
    #@ Handle sort|facet|level|indexOption|indexSubcollection|indexLanguage 
    elsif ($element =~ /$arrayexp/) {
      my $key = $nameMap->{$element};	# 
      if (!defined $data->{$key}) {
	$data->{$key} = [];
      }

      if (defined $name) {
	  push (@{$data->{$key}},$name);
      }
    }

    #@ Handle index which can have options as children to be put in a map: <option name="name" value="value" />
    elsif ($element =~ /$structexp/) {
	# find the gs2 mapping name
        $currentLevel = $element;
	
	# for GS2, 'indexes' should be an arrayexp, so maintain that part of the code as it is	
	my $key = $nameMap->{$element};	# 'indexes'
	if (!defined $data->{$key}) {
	    $data->{$key} = [];	    
	}
	
	if (defined $name) {
	    push (@{$data->{$key}},$name);	    
	}
    }

    #@ Handling the option elements in each index structure, if any, only for GS2
    elsif ($currentLevel =~ /$structexp/ && $element eq "option") {
	# find the gs2 mapping name for classifier and plugin
	my $key = $nameMap->{$currentLevel."fieldoptions"}; # my $key = $currentLevel."fieldoptions"; # indexfieldoptions 

	# The last element of the 'indexes' array contains the name of the index currently being processed
	# e.g. "allfields"
	my $indexKey = $nameMap->{$currentLevel}; # 'indexes'
	my $arrSize = scalar( @{$data->{$indexKey}} ); # length of 'indexes' array
	my $indexName = @{$data->{$indexKey}}[$arrSize-1]; # name of index currently being processed in prev elsif

	if (!defined $data->{$key}) {
	    $data->{$key} = {}; # 'indexoptions' is a new hashmap
	}   
	if (defined $name and $name =~ /\w/ && defined $value and $value =~ /\w/) {
	    # we have a name and value to this option, add them as options associated with the current index
	    
	    if (!defined $data->{$key}->{$indexName}) {
		$data->{$key}->{$indexName} = {}; # indexoptions -> allfields is a new hashmap
	    }
	    
	    $data->{$key}->{$indexName}->{$name} = $value;
	    
	    #print STDERR "@@@ Found: Value: data->{'indexfieldoptions'}->{$indexName}->{$name}: " . $data->{'indexfieldoptions'}->{$indexName}->{$name} . "\n";	    
	}
    }

    # importOption and buildOption, just stored at top level, name=value, 
    # as per gs2 version
    elsif ($element =~ /$topleveloptionexp/) {
	if (defined $name) {
	    if (!defined $value) {
		# flag option, set to true
		$value = "true";
	    }
	    $data->{$name} = $value;
	}
    }

    #@ plugout options
    elsif ($element eq "plugout") {
	$currentLevel = "plugout";
	my $key = $nameMap->{$currentLevel};	
	if (!defined $data->{$key}) {
	    $data->{$key} = [];
	}
	if(defined $name and $name ne ""){
	    push (@{$data->{$key}},$name);
	}
	else{
	   push (@{$data->{$key}},"GreenstoneXMLPlugout"); 
	}
    }
    if ($currentLevel eq "plugout" and $element eq "option") {     
	my $key = $nameMap->{$currentLevel};
	if (defined $name and $name ne ""){
	    push (@{$data->{$key}},$name);
	}
	if (defined $value and $value ne  ""){
	    push (@{$data->{$key}},$value);
	}
    }

    #@ use hash of hash of strings: hashexp
    elsif ($element =~ /$hashexp/) {
      if (!defined $data->{$element}) {
	$data->{$element} = {};
      }
      if (defined $name and $name =~ /\w/) {
	if (defined $filter and $filter =~ /\w/) {
	  $data->{$element}->{$name} = $filter;

	}
      }
    }

    #@ Handling each classifier/plugin element
    elsif ($element =~ /$arrayarrayexp/) {
	# find the gs2 mapping name
        $currentLevel = $element;
        my $key = $nameMap->{$element};
	
	# define an array of array of strings	foreach $k (@{$data->{$key}}) {
	if (!defined $data->{$key}) {
	    $data->{$key} = [];
	}
	
	# Push classifier/plugin name (e.g. AZList) into $data as the first string
	push (@{$data->{$key}->[$currentIndex]},$name);
	if (defined $value and $value =~ /\w/) {
	    push (@{$data->{$key}->[$currentIndex]}, $value);
	    print "$value\n";
	}	
	#print $currentIndex."indexup\n";
    }

    #@ Handling the option elements in each classifier/plugin element (as the following strings)
    elsif ($currentLevel =~ /$arrayarrayexp/ and $element eq "option") {
	# find the gs2 mapping name for classifier and plugin
        my $key = $nameMap->{$currentLevel};	

	if (defined $name and $name =~ /\w/) {
	    push (@{$data->{$key}->[$currentIndex]}, $name);
	}
	if (defined $value and $value !~ /^\s*$/) {
            push (@{$data->{$key}->[$currentIndex]}, $value);
	}

    }


}

sub EndTag {
    my ($expat, $element) = @_;
    my $endTags = q/^(browse|pluginList|displayItemList|indexOption)$/; #|buildOptionList)$/;   
    if ($element =~ /$endTags/) {
		$currentIndex = 0;
		$currentLevel = "";
    }

    # $arrayarrayexp contains classifier|plugin
    elsif($element =~ /$arrayarrayexp/ ){
     	$currentIndex = $currentIndex + 1;
    }
}

sub Text {
    if (defined $currentLocation) { 
	#@ Handling block metadataList(creator, maintainer, public)
	if($currentLocation =~ /$stringexp/){
	    #print $currentLocation;
	    my $key = $nameMap->{$currentLocation};	
	    $data->{$key} = $_;
	    undef $currentLocation;
	}
	
	#@ Handling displayItem metadata that are children of displayItemList
	# that means we will be getting the collection's name and possibly description ('collectionextra' in GS2).
	elsif($currentLevel eq "displayItemList" && $currentLocation =~ /$displayItemNames/) {
	    my $lang = $currentAttrRef->{'lang'};
	    my $name = $currentAttrRef->{'name'};
	    
	    # this is how data->collectionmeta's language is set in Greenstone 2. 
	    # Need to be consistent, since export.pl accesses these values all in the same way
	    if(!defined $lang) {
		$lang = 'default';
	    } else {
		$lang = "[l=$lang]"; 
	    }
	    
	    if(defined $name and $name =~ /$displayItemNames/) { # attribute name = 'name' || 'description'
		# using $nameMap->$name resolves to 'collectionname' if $name='name' and 'collectionextra' if $name='description'
		$data->{'collectionmeta'}->{$nameMap->{$name}}->{$lang} = $_; # the value is the Text parsed
		#print STDERR "***Found: $nameMap->{$name} collectionmeta, lang is $lang. Value: $data->{'collectionmeta'}->{$nameMap->{$name}}->{$lang}\n";
	    }
	    undef $currentLocation;
	}
  
	#@ Handling searchtype: plain,form; arrayexp
	elsif (defined $currentLocation and $currentLocation =~ /searchType/) {
	    # map 'searchType' into 'searchtype'
	    my $key = $nameMap->{$currentLocation};
	    # split it by ','
	    my ($plain, $form) = split (",", $_);
	    
	    if (!defined $data->{$key}) {
		$data->{$key} = [];
	    }
	    if (defined $plain and $plain =~ /\w/) {
		push @{ $data->{$key} }, $plain;
	    }
	    if (defined $form and $form =~ /\w/) {
		push @{ $data->{$key} }, $form;
	    }
	}
    }	
}

# This sub is for debugging purposes
sub Display {
    # metadataList
    foreach my $k (keys %{$data}) {
	print STDERR "*** metadatalist key $k\n"; 
    }
  
    print STDERR "*** creator: ".$data->{'creator'}."\n" if (defined $data->{'creator'});
    print STDERR "*** maintainer: ".$data->{"maintainer"}."\n" if (defined $data->{"maintainer"});
    print STDERR "*** public: ".$data->{"public"}."\n" if (defined $data->{"public"});
    print STDERR "*** default index: ".$data->{"defaultindex"}."\n" if (defined $data->{"defaultindex"});
    print STDERR "*** default level: ".$data->{"defaultlevel"}."\n" if (defined $data->{"defaultlevel"});
    print STDERR "*** build type: ".$data->{"buildtype"}."\n" if (defined $data->{"buildtype"});
    print STDERR "*** orthogonal build types: ".join(",",$data->{"orthogonalbuildtypes"})."\n" if (defined $data->{"orthogonalbuildtypes"});
    print STDERR "*** search types: \n";
    print STDERR join(",",@{$data->{"searchtype"}})."\n" if (defined $data->{"searchtype"});
    print STDERR "*** levels: \n";
    print STDERR join(",",@{$data->{'levels'}})."\n" if (defined $data->{'levels'});
    print STDERR "*** index subcollections: \n";
    print STDERR join(",",@{$data->{'indexsubcollections'}})."\n" if (defined $data->{'indexsubcollections'});
    print STDERR "*** indexes: \n";
    print STDERR join(",",@{$data->{'indexes'}})."\n" if (defined $data->{'indexes'});
    print STDERR "*** index options: \n";
    print STDERR join(",",@{$data->{'indexoptions'}})."\n" if (defined $data->{'indexoptions'});
    print STDERR "*** languages: \n";
    print STDERR join(",",@{$data->{'languages'}})."\n" if (defined $data->{'languages'});
    print STDERR "*** language metadata: \n";
    print STDERR join(",",@{$data->{'languagemetadata'}})."\n" if (defined $data->{'languagemetadata'});
 
    print STDERR "*** Plugins: \n";
    if (defined $data->{'plugin'}) {
	foreach $a (@{$data->{'plugin'}}) {
	    print join(",",@$a);
	    print "\n";
	}
    }

    #print STDERR "*** Build options: \n";
    #if (defined $data->{'store_metadata_coverage'}) {
    #foreach $a (@{$data->{'store_metadata_coverage'}}) {
    #    print join(",",@$a,@$_);
    #    print "\n";
    #}
    #}

    if (defined $data->{'classify'}) {
	print STDERR "*** Classifiers: \n";
	map { print join(",",@$_)."\n"; } @{$data->{'classify'}};
    }
    
    if (defined $data->{'subcollection'}) {
	foreach my $key (keys %{$data->{'subcollection'}}) {
	    print "subcollection ".$key." ".$data->{'subcollection'}->{$key}."\n";
	}
    }
}
# is this actually used??
sub Doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    die if ($name !~ /^CollectionConfig$/);
}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
    if ($]<5.008) {
	use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+ and Perl 5.6
    }
    $_[0]->{'Text'} .= $_[1];
    return undef;
}




#########################################################

1;
