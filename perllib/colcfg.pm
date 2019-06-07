###########################################################################
#
# colcfg.pm --
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

# reads/writes the collection configuration files:
# collect.cfg/collectionConfig.xml and build.cfg/buildConfig.xml

package colcfg;

use cfgread;
use gsprintf 'gsprintf';
use util;
use FileUtils;

use strict;

# the collection configuration file data is stored in the form
#
# {'infodbtype'}->string
# {'creator'}->string
# {'public'}->string
# {'complexmeta'}->string (true, false)
# {'defaultindex'}->string
# {'importdir'}->string
# {'archivedir'}->string
# {'cachedir'}->string
# {'builddir'}->string
# {'removeold'}->string
# {'textcompress'}->string
# {'buildtype'}->string
# {'orthogonalbuildtypes'}->array of strings
# {'maxnumeric'}->string
# {'separate_cjk'}->string
# {'sections_index_document_metadata'}->string (never, always, unless_section_metadata_exists)
# {'sections_sort_on_document_metadata'}->string (never, always, unless_section_metadata_exists)
# {'languagemetadata'} -> string
# {'maintainer'}->array of strings
# {'languages'}->array of strings
# {'indexsubcollections'}->array of strings
# {'indexes'}->array of strings
# {'indexoptions'}->array of strings (stem, casefold, accentfold, separate_cjk)
# {'dontbuild'}->array of strings
# {'dontgdbm'}->array of strings
# {'mirror'}->array of strings
# {'phind'}->array of strings
# {'plugout'}->array of strings
# {'levels'}->array of strings (for mgpp eg Section, Paragraph)
# {'searchtype'}->array of strings (for mgpp, form or plain)
# {'sortfields'}->array of strings (for lucene)
# {'subcollection'}->hash of key-value pairs

# {'acquire'}->array of arrays of strings
# {'plugin'}->array of arrays of strings
# {'classify'}->array of arrays of strings

# {'collectionmeta'}->hash of key->hash of param-value -used 
# for language specification
#    for example, collectionmeta->collectionname->default->demo
#                                               ->mi->maori demo

# convenience method for reading in either collect.cfg/collectionConfig.xml
sub read_collection_cfg {
    my ($filename,$gs_mode) = @_;
    
    my $collectcfg = undef;

    if ($gs_mode eq "gs2") {
	$collectcfg = &colcfg::read_collect_cfg ($filename);
    } elsif ($gs_mode eq "gs3") {
	$collectcfg = &colcfg::read_collection_cfg_xml ($filename);
    }
    else {
	print STDERR "Failed to read collection configuration file\n";
	print STDERR "  Unrecognized mode: $gs_mode\n";
    }

    return $collectcfg;
}

# convenience method for writing out either collect.cfg/collectionConfig.xml
# is this ever used??
sub write_collection_cfg {
     my ($filename, $collectcfg_data, $gs_mode) = @_;
    
    if ($gs_mode eq "gs2") {
	&colcfg::write_collect_cfg ($filename, $collectcfg_data );
    } elsif ($gs_mode eq "gs3") {
	&colcfg::write_collection_cfg_xml ($filename, $collectcfg_data);
    }
    else {
	print STDERR "Failed to write collection configuration file\n";
	print STDERR "  Unrecognized mode: $gs_mode\n";
    }
}
   
# the build configuration file data is stored in the form
#
# {'infodbtype'}->string
# {'builddate'}->string
# {'buildtype'}->string
# {'orthogonalbuildtypes'}->array of strings
# {'metadata'}->array of strings
# {'languages'}->array of strings
# {'numdocs'}->string
# {'numsections'}->string
# {'numwords'}->string
# {'numbytes'}->string
# {'maxnumeric'}->string
# {'indexfields'}->array of strings
# {'indexfieldmap'}->array of strings in the form "field->FI"
# {'indexmap'} -> array of strings
# {'indexlevels'} -> array of strings
# {'indexsortfields'} -> array of strings
# {'indexsortfieldmap'} -> array of strings in the form "field->byFI"
# {'stemindexes'} -> string (int)
# {'textlevel'}->string
# {'levelmap'} -> array of strings in the form "level->shortname"

# convenience method for reading in either build.cfg/buildConfig.xml
sub read_building_cfg {
    my ($filename,$gs_mode) = @_;
    
    my $buildcfg = undef;

    if ($gs_mode eq "gs2") {
	$buildcfg = &colcfg::read_build_cfg ($filename);
    } elsif ($gs_mode eq "gs3") {
	$buildcfg = &colcfg::read_build_cfg_xml ($filename);
    }
    else {
	print STDERR "Failed to read building configuration file\n";
	print STDERR "  Unrecognized mode: $gs_mode\n";
    }

    return $buildcfg;
}

# convenience method for writing out either build.cfg/buildConfig.xml
# haven't got one, as gs3 version needs extra parameters
#sub write_building_cfg {}

##############################
### gs2/gs3 specific methods
###############################

#####################################
### collect.cfg/collectionConfig.xml
#####################################

# gs2 read in collect.cfg
sub read_collect_cfg {
    my ($filename) = @_;

    return &cfgread::read_cfg_file_unicode ($filename, 
				    q/^(infodbtype|creator|public|complexmeta|defaultindex|importdir|/ .
					q/archivedir|exportdir|cachedir|builddir|removeold|/ .
					q/textcompress|buildtype|othogonalbuildtypes|no_text|keepold|NO_IMPORT|gzip|/ .
					q/verbosity|remove_empty_classifications|OIDtype|OIDmetadata|oidtype|oidmetadata|/ .
					q/groupsize|maxdocs|debug|mode|saveas|saveas_options|/ .
					q/sortmeta|removesuffix|removeprefix|create_images|/ .
					q/maxnumeric|languagemetadata|/ .
					q/no_strip_html|index|sections_index_document_metadata|sections_sort_on_document_metadata|/ .
					q/store_metadata_coverage|indexname|indexlevel)$/,
				    q/(maintainer|languages|indexsubcollections|orthogonalbuildtypes|/ .
				       q/indexes|indexoptions|dontbuild|dontgdbm|mirror|levels|sortfields|plugout|/ .
				       q/searchtype|searchtypes)$/,
				    q/^(subcollection|format)$/,
				    q/^(acquire|plugin|classify)$/,
				    q/^(collectionmeta)$/);
}

# gs2 write out collect.cfg
sub write_collect_cfg {
    my ($filename, $data) = @_;
    
    &cfgread::write_cfg_file($filename, $data,
			     q/^(infodbtype|creator|public|complexmeta|defaultindex|importdir|/ .
				 q/archivedir|cachedir|builddir|removeold|/ .
				 q/textcompress|buildtype|no_text|keepold|NO_IMPORT|gzip|/ .
				 q/verbosity|remove_empty_classifications|OIDtype|OIDmetadata|/.
				 q/groupsize|maxdocs|debug|mode|saveas|/ .
				 q/sortmeta|removesuffix|removeprefix|create_images|/ .
				 q/maxnumeric|languagemetadata/ .
				 q/no_strip_html|index|sections_index_document_metadata|sections_sort_on_document_metadata)$/.
			         q/store_metadata_coverage)$/,
			     q/^(maintainer|languages|indexsubcollections|orthogonalbuildtypes|/ .
				 q/indexes|indexoptions|dontbuild|dontgdbm|mirror|levels|/.
				 q/searchtype|searchtypes)$/,
			     q/^(subcollection|format)$/,
			     q/^(acquire|plugin|classify)$/,
			     q/^(collectionmeta)$/);
}

# gs3 read in collectionConfig.xml
sub read_collection_cfg_xml {
    my ($filename) = @_;

    require collConfigxml;
    return &collConfigxml::read_cfg_file ($filename);
}

# gs3 write out collectionConfig.xml
sub write_collection_cfg_xml {
 
}

#####################################
### build.cfg/buildConfig.xml
######################################

# gs2 read build.cfg
sub read_build_cfg {
    my ($filename) = @_;

    return &cfgread::read_cfg_file ($filename, 
		   q/^(earliestdatestamp|infodbtype|builddate|buildtype|numdocs|numsections|numwords|numbytes|maxnumeric|textlevel|indexstem|stemindexes|separate_cjk)$/,
		   q/^(indexmap|subcollectionmap|languagemap|orthogonalbuildtypes|notbuilt|indexfields|indexfieldmap|indexlevels|levelmap|indexsortfields|indexsortfieldmap)$/);
				    
}

# gs2 write build.cfg
sub write_build_cfg {
    my ($filename, $data) = @_;

    &cfgread::write_cfg_file($filename, $data,
	       q/^(earliestdatestamp|infodbtype|builddate|buildtype|numdocs|numsections|numwords|numbytes|maxnumeric|textlevel|indexstem|stemindexes|separate_cjk)$/,
	       q/^(indexmap|subcollectionmap|languagemap|orthogonalbuildtypes|notbuilt|indexfields|indexfieldmap|indexlevels|levelmap|indexsortfields|indexsortfieldmap)$/);		     
}

# gs3 read buildConfig.xml
sub read_build_cfg_xml {

    my ($filename) = @_;

    require buildConfigxml;
    return &buildConfigxml::read_cfg_file($filename);
}

# gs3 write buildConfig.xml
sub write_build_cfg_xml {
    my ($buildoutfile, $buildcfg, $collectcfg) = @_;

    require buildConfigxml;
    return &buildConfigxml::write_cfg_file ($buildoutfile, $buildcfg, $collectcfg);
}


# method to check for filename of collect.cfg, and gs mode.
sub get_collect_cfg_name_old {
    my ($out) = @_;

    # First check if there's a
    # gsdl/collect/COLLECTION/custom/COLLECTION/etc/custom.cfg file. This
    # customization was added for DLC by Stefan, 30/6/2007.
    my $configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "custom", $ENV{'GSDLCOLLECTION'}, "etc", "custom.cfg");

    if (-e $configfilename) {
        return ($configfilename, "gs2");
    }

    # Check if there is a collectionConfig.xml file. If there is one, it's gs3
    $configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "etc", "collectionConfig.xml");    
    if (-e $configfilename) {
        return ($configfilename, "gs3");
    }

    # If we get to here we check if there is a collect.cfg file in the usual place, i.e. it is gs2.
    $configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "etc", "collect.cfg");
    if (-e $configfilename) {
        return ($configfilename, "gs2");
    }

    # Error. No collection configuration file.
    (&gsprintf($out, "{common.cannot_find_cfg_file}\n", $configfilename) && die);
}

# method to check for filename of collect.cfg
# needs to be given gs_version, since we can have a GS2 collection ported into
# GS3 which could potentially have collect.cfg AND collectionConfig.xml
# in which case the older version of this subroutine (get_collect_cfg_name_old)
# will return the wrong answer for the gs version we're using.
sub get_collect_cfg_name {
    my ($out, $gs_version) = @_;

    # First check if there's a
    # gsdl/collect/COLLECTION/custom/COLLECTION/etc/custom.cfg file. This
    # customization was added for DLC by Stefan, 30/6/2007.
    my $configfilename; 

    if($gs_version eq "gs2") {
	$configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "custom", $ENV{'GSDLCOLLECTION'}, "etc", "custom.cfg");
    
	if (-e $configfilename) {
	    return $configfilename;
	}
    }

    # Check if there is a collectionConfig.xml file if it's gs3
    if($gs_version eq "gs3") {
	$configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "etc", "collectionConfig.xml");    
	if (-e $configfilename) {
	    return $configfilename;
	}
    }

    # Check if there is a collect.cfg file in the usual place for gs2.
    if($gs_version eq "gs2") {
	$configfilename = &FileUtils::filenameConcatenate ($ENV{'GSDLCOLLECTDIR'}, "etc", "collect.cfg");
	if (-e $configfilename) {
	    return $configfilename;
	}
    }

    # Error. No collection configuration file.
    (&gsprintf($out, "{common.cannot_find_cfg_file}\n", $configfilename) && die);
}



sub use_collection {
   my ($site, $collection, $collectdir) = @_;

   if ((defined $site) && ($site ne ""))
   {
       return &util::use_site_collection($site, $collection, $collectdir);
   }
   else
   {
       return &util::use_collection($collection, $collectdir);
   }
}


1;


