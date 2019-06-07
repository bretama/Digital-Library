###########################################################################
#
# buildConfigxml.pm --
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

# reads in buildConfig.xml 
# Note, only implemented the bits that are currently used, eg by incremental 
# build code.
# The resulting data is not a full representation on buildConfig.xml.

package buildConfigxml;

use strict;
no strict 'refs';
no strict 'subs';

use XMLParser;


# A mapping hash to resolve name discrepancy between gs2 and gs3.
my $nameMap = {"numDocs" => "numdocs",
	       "buildType" => "buildtype",
	       "orthogonalBuildTypes" => "orthogonalbuildtypes"
	       };


# A hash structure which is returned by sub read_cfg_file.
my $data = {};

# use those unique attribute values to locate the text within the elements
my $currentLocation = "";
my $stringexp = q/^(buildType|numDocs)$/;
my $arrayexp = q/^(orthogonalBuildTypes)$/;

my $indexmap_name = "";
my $haveindexfields = 0;

# Reads in the model collection configuration file, collectionConfig.xml,
# into a structure which complies with the one used by gs2 (i.e. one read
# in by &cfgread::read_cfg_file).
sub read_cfg_file {
    my ($filename) = @_;
    $data = {};
    if ($filename !~ /buildConfig\.xml$/ || !-f $filename) {
        return undef;
    }

    # Removed ProtocolEncoding (see MetadataXMLPlugin for details)

    # create XML::Parser object for parsing metadata.xml files
    my $parser = new XML::Parser('Style' => 'Stream',
				 'Pkg' => 'buildConfigxml',
				 'Handlers' => {'Char' => \&Char,
						 'Doctype' => \&Doctype
						 });

    if (!open (COLCFG, $filename)) {
	print STDERR "buildConfigxml::read_cfg_file couldn't read the cfg file $filename\n";
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
    
    my $name = $_{'name'};
    my $shortname = $_{'shortname'};

    
    #@ handling block metadataList
    if (defined $name && (($name =~ m/$stringexp/) || ($name =~ m/$arrayexp/))) {
      $currentLocation = $name;
      # the value will be retrieved later in Text sub
    }

    #@ handle indexes - store indexmap (mg) or indexfields and indexfieldmap (mgpp/lucene/solr)
    elsif ($element =~ /^indexList$/) {
	# set up the data arrays
	# this assumes that the build type has been read already, which is
	# currently the order we save the file in.
	if ($data->{'buildtype'} eq "mg") {
	    $indexmap_name = "indexmap";
	    if (!defined $data->{"indexmap"}) {
		$data->{"indexmap"} = [];
	    }
	}
	else {
	    # mgpp, lucene or solr
	    $indexmap_name = "indexfieldmap";
	    $haveindexfields = 1;
	    if (!defined $data->{"indexfieldmap"}) {
		$data->{"indexfieldmap"} = [];
	    }
	    if (!defined $data->{"indexfields"}) {
		$data->{"indexfields"} = [];
	    }

	}
	
    }
    
    elsif ($element =~ /index/) {
	# store each index in the map
	if (defined $name && defined $shortname) {
	    push @{$data->{$indexmap_name}}, "$name->$shortname";
	    if ($haveindexfields) {
		push @{$data->{'indexfields'}}, $name;
	    }
	}
    }


}

sub EndTag {
    my ($expat, $element) = @_;
}

sub Text {
    if (defined $currentLocation) { 
	#@ Handling block metadataList(numDocs, buildType)
	if ($currentLocation =~ /$stringexp/) {
	    #print $currentLocation;
	    my $key = $nameMap->{$currentLocation};	
	    $data->{$key} = $_;
	    undef $currentLocation;
	}	
	elsif ($currentLocation =~ /$arrayexp/) {
	    #print $currentLocation;
	    my $key = $nameMap->{$currentLocation};	
	    push(@{$data->{$key}},$_);
	    undef $currentLocation;
	}	

    }	
}

# This sub is for debugging purposes
sub Display {

    print "NumDocs = ".$data->{'numdocs'}."\n" if (defined $data->{'numdocs'});
    print "BuildType = ".$data->{'buildtype'}."\n" if (defined $data->{'buildtype'});
    print "OrthogonalBuildTypes = ".join(",",@{$data->{'orthogonalbuildtypes'}})."\n" if (defined $data->{'orthogonalbuildtypes'});
    print  "IndexMap = ". join(" ",@{$data->{'indexmap'}})."\n" if (defined $data->{'indexmap'});
    print  "IndexFieldMap = ". join(" ",@{$data->{'indexfieldmap'}})."\n" if (defined $data->{'indexfieldmap'});
    print  "IndexFields = ". join(" ",@{$data->{'indexfields'}})."\n" if (defined $data->{'indexfields'});

}

# is this actually used??
sub Doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    die if ($name !~ /^buildConfig$/);
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



sub write_line {
    my ($filehandle, $line) = @_;
    print $filehandle join ("", @$line), "\n";
}

sub search_and_retrieve_settings
{
    my ($buildcfg,$collectcfg) = @_;

    my $settings = {};

    if (defined $buildcfg->{"buildtype"}) {
	$settings->{'buildtype'} = $buildcfg->{"buildtype"};
    } else {
	$settings->{'buildtype'} = "mgpp";
    }
    my $buildtype = $settings->{'buildtype'};

    if (defined $collectcfg->{"orthogonalbuildtypes"}) {
	# Note the use of collectcfg, not bulidcfg
	$settings->{'orthogonalbuildtypes'} = $collectcfg->{"orthogonalbuildtypes"};
    } else {
	$settings->{'orthogonalbuildtypes '}= [];
    }

    if (defined $buildcfg->{"numdocs"}) {
	$settings->{'numdocs'} = $buildcfg->{"numdocs"};
    }
    else {
	$settings->{'numdocs'} = 0;
    }

    my $service_type = "MGPP";
    if ($buildtype eq "mg") {
	$service_type = "MG";
    } elsif ($buildtype eq "lucene") {
	$service_type = "Lucene";
    } elsif ($buildtype eq "solr") {
	$service_type = "Solr";
    }
    $settings->{'service_type'} = $service_type;


    if (defined $buildcfg->{"infodbtype"}) {
	$settings->{'infodbtype'} = $buildcfg->{'infodbtype'};
    }
    else {
	$settings->{'infodbtype'} = "gdbm";
    }


    #--
    # indexes
    #--
    
    my $indexmap = {};  # maps index name to shortname
    my $indexlist = []; # keeps the order for indexes
    my $defaultindex = "";
    my $maptype = ($buildtype eq "mg")  ? "indexmap" : "indexfieldmap";

    if (defined $buildcfg->{$maptype}) {
	my $first = 1;
	my $indexmap_t = $buildcfg->{$maptype};
	foreach my $i (@$indexmap_t) {
	    my ($k, $v) = $i =~ /^(.*)\-\>(.*)$/;
	    $indexmap->{$k} = $v;
	    push @$indexlist, $k;
	    if ($first) {
		$defaultindex = $v;
		$first = 0;
	    }
	}
       # now if the user has assigned a default index, we use it
	if (defined $collectcfg->{"defaultindex"}) {
	    $defaultindex = $indexmap->{$collectcfg->{"defaultindex"}};
	}
    } else {
	print STDERR "$maptype not defined\n";
    }

	$settings->{'num_indexes'} = $buildcfg->{'num_indexes'};
    $settings->{'defaultindex'} = $defaultindex;
    $settings->{'indexmap'} = $indexmap;
    $settings->{'indexlist'} = $indexlist;

    #--
    # default lang
    #--
    $settings->{'default_lang'} = "";
    $settings->{'default_lang_short'} = "";

    if (defined $buildcfg->{"languagemap"}) {
      my $langmap_t = $buildcfg->{"languagemap"};
      if ((defined $langmap_t) && (scalar(@$langmap_t)>=1)) {
	  my $l = $langmap_t->[0];
	  my ($k, $v) = $l =~ m/^(.*)\-\>(.*)$/; 
	  $settings->{'default_lang'} = $k; #name
	  $settings->{'default_lang_short'} = $v; #short name
      }

      # now if the user has assigned a default language (as "en", "ru" etc.)
      if (defined $collectcfg->{"defaultlanguage"}) {
	$settings->{'default_lang'} = $collectcfg->{"defaultlanguage"};
	# what about default_lang_short ?? ####
      }
    }

    # default subcol
    $settings->{'default_subcol'} = "";
    if (defined $buildcfg->{'subcollectionmap'}) {
	my $subcolmap_t = $buildcfg->{'subcollectionmap'};
	if ((defined $subcolmap_t) && (scalar(@$subcolmap_t)>=1)) {
	    my $l = $subcolmap_t->[0];
	    my ($k, $v) = $l =~ m/^(.*)\-\>(.*)$/;

	    $settings->{'default_subcol'} = $v;
	}
    }


    #--
    # indexstem
    #--
    if (defined $buildcfg->{'indexstem'}) {
	$settings->{'indexstem'} = $buildcfg->{'indexstem'};
    }

    #--
    # levelList
    #--

    my $levelmap = {};
    my $levellist = [];
    my $default_search_level = "Doc";
    my $default_retrieve_level = "Doc";
    my $default_db_level = "Doc";

    if ($buildtype eq "mgpp" || $buildtype eq "lucene" || $buildtype eq "solr") {
	if (defined $buildcfg->{'levelmap'}) {
	    my $first = 1;

	    my $levelmap_t = $buildcfg->{'levelmap'};
	    foreach my $l (@$levelmap_t) {
		my ($key, $val) = $l =~ /^(.*)\-\>(.*)$/;
		$levelmap->{$key} = $val;
		push @$levellist, $key;
		if ($first) {
		    # let default search level follow the first level in the level list
		    $default_search_level = $val;
		    # retrieve/database levels may get modified later if text level is defined
		    $default_retrieve_level = $val;
		    $default_db_level = $val;
		    $first = 0;
		}
	    }
	}
	# the default level assigned by the user is no longer ignored [Shaoqun], but the retrievel level stays the same. 
    if (defined $collectcfg->{"defaultlevel"}) {
		$default_search_level = $levelmap->{$collectcfg->{"defaultlevel"}};
        #  $default_retrieve_level = $default_search_level;
	}
	
	if (defined $buildcfg->{'textlevel'}) {
	   # let the retrieve/database levels always follow the textlevel
           $default_retrieve_level = $buildcfg->{'textlevel'};
	   $default_db_level = $buildcfg->{'textlevel'};
		 
	}
    }
    $settings->{'levelmap'} = $levelmap;
    $settings->{'levellist'} = $levellist;
    $settings->{'default_search_level'} = $default_search_level if $default_search_level;
    $settings->{'default_retrieve_level'} = $default_retrieve_level;
    $settings->{'default_db_level'} = $default_db_level;

    # sort field list
    ######

    my $sortmap = {};  # maps index name to shortname
    my $sortlist = []; # keeps the order for indexes
    my $defaultsort = "";

    if (defined ($buildcfg->{"indexsortfieldmap"})) {
	my $first = 1;

	my $sortmap_t = $buildcfg->{"indexsortfieldmap"};
	foreach my $s (@$sortmap_t) {
	    my ($k, $v) = $s =~ /^(.*)\-\>(.*)$/;
	    $sortmap->{$k} = $v;
	    $sortmap->{$v} = $k;
	    if ($first) {
		$defaultsort = $v;
		$first = 0;
	    }
	}
    }
    if (defined ($buildcfg->{"indexsortfields"})) {
	$sortlist = $buildcfg->{"indexsortfields"};
    }

    if (defined $collectcfg->{"defaultsort"}) {
	$defaultsort = $sortmap->{$collectcfg->{"defaultsort"}};
    }
    $settings->{'sortlist'} = $sortlist;
    $settings->{'sortmap'} = $sortmap;
    $settings->{'defaultsort'} = $defaultsort;

    # facet field list
    ######

    my $facetmap = {};  # maps index name to shortname
    my $facetlist = []; # keeps the order for indexes

    if (defined ($buildcfg->{"indexfacetfieldmap"})) {
	my $facetmap_t = $buildcfg->{"indexfacetfieldmap"};
	foreach my $s (@$facetmap_t) {
	    my ($k, $v) = $s =~ /^(.*)\-\>(.*)$/;
	    $facetmap->{$v} = $k;
	}
    }
    if (defined ($buildcfg->{"indexfacetfields"})) {
	$facetlist = $buildcfg->{"indexfacetfields"};
    }

    $settings->{'facetlist'} = $facetlist;
    $settings->{'facetmap'} = $facetmap;


    return $settings;
}


sub write_search_servicerack
{
    my ($buildcfg,$settings) = @_;

    my $buildtype    = $settings->{'buildtype'};
    my $infodbtype   = $settings->{'infodbtype'};
    my $service_type = $settings->{'service_type'};

	# there's no searching and therefore no search services if there are no indexes
	return if($settings->{'num_indexes'} <= 0);
	
    # do the search service 
    &write_line('COLCFG', ["<serviceRack name=\"GS2", $service_type, "Search\">"]);
    if (defined $buildcfg->{'indexstem'}) {
      my $indexstem = $buildcfg->{'indexstem'};
      &write_line('COLCFG', ["<indexStem name=\"", $indexstem, "\" />"]);     
    }
    if (defined $buildcfg->{'infodbtype'}) {
        &write_line('COLCFG', ["<databaseType name=\"", $infodbtype, "\" />"]);     
    }

    #indexes
    my $indexmap = $settings->{'indexmap'};
    my $indexlist = $settings->{'indexlist'};
    my $defaultindex = $settings->{'defaultindex'};

    #for each index in indexList, write them out
    &write_line('COLCFG', ["<indexList>"]);
    foreach my $i (@$indexlist) {
	my $index = $indexmap->{$i};
	&write_line('COLCFG', ["<index name=\"", $i, "\" ", "shortname=\"", $index, "\" />"]);
    }	
    &write_line('COLCFG', ["</indexList>"]);

    
    #$defaultindex = "ZZ" if (!$defaultindex); # index allfields by default
    if ($defaultindex) {
	&write_line('COLCFG', ["<defaultIndex shortname=\"", $defaultindex, "\" />"]);
    }


    # do indexOptionList
    if ($buildtype eq "mg" || $buildtype eq "mgpp") {
        &write_line('COLCFG', ["<indexOptionList>"]);
	my $stemindexes = 3; # default is stem and casefold
	if (defined $buildcfg->{'stemindexes'} && $buildcfg->{'stemindexes'} =~ /^\d+$/ ) {
	    $stemindexes = $buildcfg->{'stemindexes'};
	}
	&write_line('COLCFG', ["<indexOption name=\"stemIndexes\" value=\"", $stemindexes, "\" />"]);
	
	my $maxnumeric = 4; # default
	if (defined $buildcfg->{'maxnumeric'} && $buildcfg->{'maxnumeric'} =~ /^\d+$/) {
	    $maxnumeric = $buildcfg->{'maxnumeric'};
	}
	&write_line('COLCFG', ["<indexOption name=\"maxnumeric\" value=\"", $maxnumeric, "\" />"]);
        &write_line('COLCFG', ["</indexOptionList>"]);
    }

    #--
    # levelList
    #--
    my $levelmap = $settings->{'levelmap'};
    my $levellist = $settings->{'levellist'};
    my $default_search_level = $settings->{'default_search_level'};
    my $default_retrieve_level = $settings->{'default_retrieve_level'};
    my $default_db_level = $settings->{'default_db_level'};

    #for each level in levelList, write them out
    if ($buildtype ne "mg") {
	&write_line('COLCFG', ["<levelList>"]);
	foreach my $lv (@$levellist) {
	    my $level = $levelmap->{$lv};
	    &write_line('COLCFG', ["<level name=\"", $lv, "\" shortname=\"", $level, "\" />"]);
	}	
	&write_line('COLCFG', ["</levelList>"]);
    }
    # add in defaultLevel as the same level as indexLevelList, making the reading job easier
    if ($buildtype eq "lucene" || $buildtype eq "mgpp" || $buildtype eq "solr") {
	&write_line('COLCFG', ["<defaultLevel shortname=\"", $default_search_level, "\" />"]);
    }
    if ($buildtype eq "lucene" || $buildtype eq "mgpp" || $buildtype eq "solr") {
        &write_line('COLCFG', ["<defaultDBLevel shortname=\"", $default_db_level, "\" />"]);
    }

    # do sort list
    if ($buildtype eq "lucene" || $buildtype eq "solr") {
	my $sortlist = $settings->{'sortlist'};
	my $sortmap = $settings->{'sortmap'};
	&write_line('COLCFG', ["<sortList>"]);
	foreach my $sf (@$sortlist) {
	    my $sortf;
	    if ($sf eq "rank" || $sf eq "none") {
		$sortf = $sf;
	    } else {
		$sortf = $sortmap->{$sf};
	    }
	    &write_line('COLCFG', ["<sort name=\"", $sortf, "\" shortname=\"", $sf, "\" />"]);
	    
	}
	&write_line('COLCFG', ["</sortList>"]);
	&write_line('COLCFG', ["<defaultSort shortname=\"", $settings->{'defaultsort'}, "\" />"]);
    }

    # do facet list
    if ($buildtype eq "solr") {
	&write_line('COLCFG', ["<facetList>"]);
	my $facetlist = $settings->{'facetlist'};
	my $facetmap = $settings->{'facetmap'};
	foreach my $ff (@$facetlist) {
	    my $facetf = $facetmap->{$ff};
	    &write_line('COLCFG', ["<facet name=\"", $facetf, "\" shortname=\"", $ff, "\" />"]);
	}
	&write_line('COLCFG', ["</facetList>"]);
    }
    # do searchTypeList
    if ($buildtype eq "mgpp" || $buildtype eq "lucene" || $buildtype eq "solr") {
	  &write_line('COLCFG', ["<searchTypeList>"]);
      
      if (defined $buildcfg->{"searchtype"}) {
	  my $searchtype_t = $buildcfg->{"searchtype"};
	  foreach my $s (@$searchtype_t) {
	  &write_line('COLCFG', ["<searchType name=\"", $s, "\" />"]);
	}
      } else {
	  &write_line('COLCFG', ["<searchType name=\"plain\" />"]);
	  &write_line('COLCFG', ["<searchType name=\"form\" />"]);
      }
	  &write_line('COLCFG', ["</searchTypeList>"]);
    }

    # do indexLanguageList [in collect.cfg: languages; in build.cfg: languagemap]
    my $default_lang = $settings->{'default_lang'};
    my $default_lang_short = $settings->{'default_lang_short'};
    if (defined $buildcfg->{"languagemap"}) {
      &write_line('COLCFG', ["<indexLanguageList>"]);

      my $langmap_t = $buildcfg->{"languagemap"};
      foreach my $l (@$langmap_t) {
	my ($k, $v) = $l =~ /^(.*)\-\>(.*)$/; 

	&write_line('COLCFG', ["<indexLanguage name=\"", $k, "\" shortname=\"", $v, "\" />"]);
      }

      &write_line('COLCFG', ["</indexLanguageList>"]);

      &write_line('COLCFG', ["<defaultIndexLanguage name=\"", $default_lang, "\" shortname=\"", $default_lang_short, "\" />"]);
    }

    # do indexSubcollectionList
    my $default_subcol = $settings->{'default_subcol'};

    if (defined $buildcfg->{'subcollectionmap'}) {
      &write_line('COLCFG', ["<indexSubcollectionList>"]);
      my $subcolmap = {};
      my @subcollist = ();

      my $subcolmap_t = $buildcfg->{'subcollectionmap'};
      foreach my $l (@$subcolmap_t) {
	my ($k, $v) = $l =~ /^(.*)\-\>(.*)$/;
	$subcolmap->{$k} = $v;
	push @subcollist, $k;
      }

      foreach my $sl (@subcollist) {
	my $subcol = $subcolmap->{$sl};
	&write_line('COLCFG', ["<indexSubcollection name=\"", $sl, "\" shortname=\"", $subcol, "\" />"]);
      }	

      &write_line('COLCFG', ["</indexSubcollectionList>"]);
      &write_line('COLCFG', ["<defaultIndexSubcollection shortname=\"", $default_subcol, "\" />"]);
    }
      
    # close off search service 
    &write_line('COLCFG', ["</serviceRack>"]);

}


sub write_orthogonalsearch_serviceracks
{
    my ($buildcfg,$settings) = @_;

	#return if($settings->{'num_indexes'} <= 0);	# no search if no indexes
	
    my $infodbtype   = $settings->{'infodbtype'};

    my $orthogonalbuildtypes = $settings->{'orthogonalbuildtypes'};

    foreach my $obt (@$orthogonalbuildtypes) {
	$obt =~ s/^(.)/\u$1/; # capitialize initial letter
	$obt =~ s/-(.)/\u$1/g; # change any hyphenated words to cap next letter

	&write_line('COLCFG', ["<serviceRack name=\"GS2", $obt, "Search\">"]);

	&write_line('COLCFG',["<databaseType name=\"",$infodbtype,"\" />"]);  
	&write_line('COLCFG', ["</serviceRack>"]);
    }
}



sub write_retrieve_servicerack
{
    my ($buildcfg,$settings) = @_;

    my $buildtype      = $settings->{'buildtype'};
    my $infodbtype     = $settings->{'infodbtype'};
    
    my $service_type   = $settings->{'service_type'};

    # do the retrieve service
    &write_line('COLCFG', ["<serviceRack name=\"GS2", $service_type, "Retrieve\">"]);

    # do default index 
    if (defined $buildcfg->{"languagemap"}) {
	my $default_lang   = $settings->{'default_lang'};
	&write_line('COLCFG', ["<defaultIndexLanguage shortname=\"", $default_lang, "\" />"]);
    }
    if (defined $buildcfg->{'subcollectionmap'}) {
	my $default_subcol = $settings->{'default_subcol'};
	&write_line('COLCFG', ["<defaultIndexSubcollection shortname=\"", $default_subcol, "\" />"]);
    }
    if ($buildtype eq "mg") {
	my $defaultindex   = $settings->{'defaultindex'};
      &write_line('COLCFG', ["<defaultIndex shortname=\"", $defaultindex, "\" />"]);
    }

    if (defined $buildcfg->{'indexstem'}) {
      my $indexstem = $buildcfg->{'indexstem'};
      &write_line('COLCFG', ["<indexStem name=\"", $indexstem, "\" />"]);     
    }
    if ($buildtype eq "mgpp" || $buildtype eq "lucene" || $buildtype eq "solr") {
	my $default_retrieve_level = $settings->{'default_retrieve_level'};
      &write_line('COLCFG', ["<defaultLevel shortname=\"", $default_retrieve_level, "\" />"]);
    }
    if (defined $buildcfg->{'infodbtype'}) {
        &write_line('COLCFG', ["<databaseType name=\"", $infodbtype, "\" />"]);     
    }

    &write_line('COLCFG', ["</serviceRack>"]);

}


# Create the buildConfig.xml file for a specific collection
sub write_cfg_file {
    # this sub is called in make_auxiliary_files() in basebuilder.pm
    # the received args: $buildoutfile - destination file: buildConfig.xml
    #                    $buildcfg - all build options, 
    #                    $collectcfg - contents of collectionConfig.xml read in by read_cfg_file sub in buildConfigxml.pm.
    my ($buildoutfile, $buildcfg, $collectcfg) = @_;
    my $line = [];

    if (!open (COLCFG, ">$buildoutfile")) {
	print STDERR "buildConfigxml::write_cfg_file couldn't write the build config file $buildoutfile\n";
	die;
    }

    my $settings = search_and_retrieve_settings($buildcfg,$collectcfg);

    my $buildtype = $settings->{'buildtype'};
    my $orthogonalbuildtypes = $settings->{'orthogonalbuildtypes'};
    my $numdocs = $settings->{'numdocs'};

    &write_line('COLCFG', ["<buildConfig xmlns:gsf=\"http://www.greenstone.org/greenstone3/schema/ConfigFormat\">"]);  

    # output building metadata to build config file 
    &write_line('COLCFG', ["<metadataList>"]);
    &write_line('COLCFG', ["<metadata name=\"numDocs\">", $numdocs, "</metadata>"]);
    &write_line('COLCFG', ["<metadata name=\"buildType\">", $buildtype, "</metadata>"]);
    foreach my $obt (@$orthogonalbuildtypes) {
	&write_line('COLCFG', ["<metadata name=\"orthogonalBuildTypes\">", $obt, "</metadata>"]);
    }

    if (defined $buildcfg->{'indexstem'}) {
	&write_line('COLCFG', ["<metadata name=\"indexStem\">", $buildcfg->{"indexstem"}, "</metadata>"]);
    }
    if (defined $buildcfg->{'infodbtype'}) {
	&write_line('COLCFG', ["<metadata name=\"infodbType\">", $buildcfg->{"infodbtype"}, "</metadata>"]);
    }
    if (defined $buildcfg->{'builddate'}) {
	&write_line('COLCFG', ["<metadata name=\"buildDate\">", $buildcfg->{"builddate"}, "</metadata>"]);
    }
    if (defined $buildcfg->{'earliestdatestamp'}) {
	&write_line('COLCFG', ["<metadata name=\"earliestDatestamp\">", $buildcfg->{"earliestdatestamp"}, "</metadata>"]);
    }

    &write_line('COLCFG', ["</metadataList>"]);

    # output serviceRackList
    &write_line('COLCFG', ["<serviceRackList>"]);

    write_search_servicerack($buildcfg,$settings);

    # add in orthogonalbuildtypes
    write_orthogonalsearch_serviceracks($buildcfg,$settings);

    write_retrieve_servicerack($buildcfg,$settings);

    # do the browse service
    my $count = 1;
    my $phind = 0;
    my $started_classifiers = 0;

    my $classifiers = $collectcfg->{"classify"};
    foreach my $cl (@$classifiers) {
      my $name = "CL$count";
      $count++;
      my ($classname) = @$cl[0];
      if ($classname =~ /^phind$/i) {
	$phind=1;
	#should add it into coll config classifiers
	next;
      }
      
      if (not $started_classifiers) {
	&write_line('COLCFG', ["<serviceRack name=\"GS2Browse\">"]);
	if (defined $buildcfg->{'indexstem'}) {
	  my $indexstem = $buildcfg->{'indexstem'};
	  &write_line('COLCFG', ["<indexStem name=\"", $indexstem, "\" />"]);     
	}
	if (defined $buildcfg->{'infodbtype'}) {
	    my $infodbtype = $buildcfg->{'infodbtype'};
	    &write_line('COLCFG', ["<databaseType name=\"", $infodbtype, "\" />"]);     
	}
	&write_line('COLCFG', ["<classifierList>"]);		
	$started_classifiers = 1;
      }
      my $content = ''; #use buttonname first, then metadata
      my $hfilename = '';
      my $metadataname = '';
      if ($classname eq "DateList") {
	$content = "Date";
      } else {
	for (my $j=0; $j<scalar(@$cl); $j++) {
	  my $arg = @$cl[$j];
	  if ($classname eq "Hierarchy")  
	  {
          	if ($arg eq "-hfile")
                {
                	$hfilename = @$cl[$j+1];
                } 
                elsif ($arg eq "-metadata") 
                {
                      	$metadataname = @$cl[$j+1];
                }
          }
	  if ($arg eq "-buttonname"){
	    $content = @$cl[$j+1];
	    last;
	  } elsif ($arg eq "-metadata") {
	    $content = @$cl[$j+1];
	  }
	  
	}
      }
      if ($classname eq "Hierarchy")
      {
	&write_line('COLCFG', ["<classifier name=\"", $name, "\" content=\"", $content, "\" metadata=\"", $metadataname, "\" hfile=\"", $hfilename, "\" />"]);
      } else 
      {	
     	&write_line('COLCFG', ["<classifier name=\"", $name, "\" content=\"", $content, "\" />"]);
      }     
    }
    if ($started_classifiers) {
      # end the classifiers
      &write_line('COLCFG', ["</classifierList>"]);
      # close off the Browse service
      &write_line('COLCFG', ["</serviceRack>"]);
    }
    
    # the phind classifier is a separate service
    if ($phind) {
	# if phind classifier
	&write_line('COLCFG', ["<serviceRack name=\"PhindPhraseBrowse\" />"]);
    }

    
    &write_line('COLCFG', ["</serviceRackList>"]);
    &write_line('COLCFG', ["</buildConfig>"]);

    close (COLCFG);
  }


#########################################################

1;
