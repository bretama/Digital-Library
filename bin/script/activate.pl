#!/usr/bin/perl -w

###########################################################################
#
# activate.pl -- to be called after building a collection to activate it.
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009 New Zealand Digital Library Project
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


# This program is designed to support the building process of Greenstone.
# It deactivates the collection just built, if the web server is running
# and is a persistent web server (or if the library_URL provided as 
# parameter to this script is of a currently running web server). It then 
# moves building to index, before activating the collection on the GS2 or 
# GS3 web server again if necessary.

use Config;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
	
    # Adding cpan in, adds in its auto subfolder which conflicts with ActivePerl on Windows
    # The auto folder has been moved into a perl-5.8 folder, and this will now be included 
    # only if the current version of perl is 5.8 (and not ActivePerl).
    my $perl_dir;

    # Note: $] encodes the version number of perl
    if ($]>=5.010) { 
        $perl_dir="perl-5.".substr($],3,2);
    }
    elsif ($]>5.008) { 
	# perl 5.8.1 or above
	$perl_dir = "perl-5.8";
    }
    elsif ($]>=5.008) { 
	# perl 5.8.1 or above
	$perl_dir = "perl-5.8";
    }
    elsif ($]<5.008) {
	# assume perl 5.6
	$perl_dir = "perl-5.6";
    }
    else {
	print STDERR "Warning: Perl 5.8.0 is not a maintained release.\n";
	print STDERR "         Please upgrade to a newer version of Perl.\n";
	$perl_dir = "perl-5.8";
    }
    
    #if ($ENV{'GSDLOS'} !~ /^windows$/i) {
    # Use push to put this on the end, so an existing XML::Parser will be used by default
		if (-d "$ENV{'GSDLHOME'}/perllib/cpan/$perl_dir-mt" && $Config{usethreads}){
			push (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/$perl_dir-mt");
		}
		else{
			push (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/$perl_dir");
		}
    #}
	
}


use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

use File::Basename;
use File::Find;

# Greenstone modules
use colcfg;
use oaiinfo;
use scriptutil;
use servercontrol;
use util;


# Most of the arguments are familiar from the building scripts like buildcol.pl
# The special optional argument -library_url is for when we're dealing with a web 
# library server such as an apache that's separate from any included with GS2. 
# In such a case, this script's caller should pass in -library_url <URL>.
#
# $site argument must be specified in the cmdline for collectionConfig.xml to get 
# generated which makes $gs_mode=gs3, else collect.cfg gets generated and $gs_mode=gs2
sub main
{
    my ($argc,@argv) = @_;

    if (($argc==0)  || (($argc==1) && ($argv[0] =~ m/^--?h(elp)?$/))) {
	my ($progname) = ($0 =~ m/^.*[\/|\\](.*?)$/);
	
	
	print STDERR "\n";
	print STDERR "Usage: $progname [-collectdir c -builddir b -indexdir i -site s -skipactivation -removeold -keepold -incremental -verbosity v\n";
	print STDERR "\t-library_url URL -library_name n] <[colgroup/]collection>\n";
	print STDERR "\n";
	
	exit(-1);
    }
    
    # http://stackoverflow.com/questions/6156742/how-can-i-capture-the-complete-commandline-in-perl
    #print STDERR "@@@@@@@@@ ACTIVATE CMD: " . join " ", $0, @ARGV . "\n";
	
    # get the collection details
    my $qualified_collection = pop @argv; # qualified collection
    
    my $collect_dir = undef; #"collect"; # can't be "collect" when only -site is provided for GS3
    my $build_dir = undef;
    my $index_dir = undef;
    my $site = undef;
    
    # if run from server (java code), it will handle deactivation and activation to prevent open file handles when java launches this script and exits:
    my $skipactivation = 0;
    my $removeold = 0;
    my $keepold = 0;
    my $incremental = 0; # used by solr

    my $default_verbosity = 2;

    my $library_url = undef; # to be specified on the cmdline if not using a GS-included web server
    # the GSDL_LIBRARY_URL env var is useful when running cmdline buildcol.pl in the linux package manager versions of GS3
    
    my $library_name = undef;
    
    while (my $arg = shift @argv) {
	if ($arg eq "-collectdir") {
	    $collect_dir = shift @argv;
	}
	elsif ($arg eq "-builddir") {
	    $build_dir = shift @argv;
	}
	elsif ($arg eq "-indexdir") {
	    $index_dir = shift @argv;
	}
	elsif ($arg eq "-site") {
	    $site = shift @argv;
	}
	elsif ($arg eq "-skipactivation") {
	    $skipactivation = 1;
	}
	elsif ($arg eq "-removeold") {
	    $removeold = 1;
	}
	elsif ($arg eq "-keepold") {
	    $keepold = 1;
	}
	elsif ($arg eq "-incremental") {
	    $incremental = 1;
	}
	elsif ($arg eq "-library_url") {
	    $library_url = shift @argv;
	}
	elsif ($arg eq "-library_name") {
	    $library_name = shift @argv;
	}
	elsif ($arg eq "-verbosity") { 
	    $default_verbosity = shift @argv; # global variable
	    
	    # ensure we're working with ints not strings (int context not str context), in case verbosity=0
	    # http://stackoverflow.com/questions/288900/how-can-i-convert-a-string-to-a-number-in-perl
	    $default_verbosity = int($default_verbosity || 0); ### is this the best way?
	}
    }
    
    # work out the building and index dirs
    my $collection_dir = &util::resolve_collection_dir($collect_dir, $qualified_collection, $site);
    $build_dir = &FileUtils::filenameConcatenate($collection_dir, "building") unless (defined $build_dir);
    $index_dir = &FileUtils::filenameConcatenate($collection_dir, "index") unless (defined $index_dir);

    my $gsserver = new servercontrol($qualified_collection, $site, $default_verbosity, $build_dir, $index_dir, $collect_dir, $library_url, $library_name);

    $gsserver->print_task_msg("Running  Collection  Activation  Stage");
    
    # get and check the collection name
    if ((&colcfg::use_collection($site, $qualified_collection, $collect_dir)) eq "") {
	$gsserver->print_msg("Unable to use collection \"$qualified_collection\" within \"$collect_dir\"\n");
	exit -1;
    }
    
    # Read in the collection configuration file.
    # Beware: Only if $site is specified in the cmdline does collectionConfig.xml get 
    # generated and does $gs_mode=gs3, else collect.cfg gets generated and $gs_mode=gs2
    my $gs_mode = $gsserver->{'gs_mode'}; # "gs2" or "gs3", based on $site variable

    my $collect_cfg_filename = &colcfg::get_collect_cfg_name(STDERR, $gs_mode);
    my $collectcfg = &colcfg::read_collection_cfg ($collect_cfg_filename,$gs_mode);
    
    # look for build.cfg/buildConfig.xml
    my $build_cfg_filename ="";	
    
    if ($gs_mode eq "gs2") {
	$build_cfg_filename = &FileUtils::filenameConcatenate($build_dir,"build.cfg");
    } else {
	$build_cfg_filename = &FileUtils::filenameConcatenate($build_dir, "buildConfig.xml");
	# gs_mode is GS3. Set the site now if this was not specified as cmdline argument
	#$site = "localsite" unless defined $site;
    }
    
    # We need to know the buildtype for Solr.
    # Any change of indexers is already detected and handled by the calling code (buildcol or 
    # full-rebuild), so that at this stage the config file's buildtype reflects the actual buildtype.
    
    # From buildcol.pl we use searchtype for determining buildtype, but for old versions, use buildtype
    my $buildtype;
    if (defined $collectcfg->{'buildtype'}) {
	$buildtype = $collectcfg->{'buildtype'};
    } elsif (defined $collectcfg->{'searchtypes'} || defined $collectcfg->{'searchtype'}) {
	$buildtype = "mgpp";
    } else {
	$buildtype = "mg"; #mg is the default
    }
	
    # can't do anything without a build directory with something in it to move into index
    # Except if we're (doing incremental) building for solr, where we want to still
    # activate and deactivate collections including for the incremental case

    if(!$incremental) { # if (!($incremental && ($build_dir eq $index_dir)))
	
	if(!&FileUtils::directoryExists($build_dir)) {
	    $gsserver->print_msg("No building folder at $build_dir to move to index.\n");
	    exit -1 unless ($buildtype eq "solr"); #&& $incremental);
	} elsif (&FileUtils::isDirectoryEmpty($build_dir)) {
	    $gsserver->print_msg("Nothing in building folder $build_dir to move into index folder.\n");
	    exit -1 unless ($buildtype eq "solr"); #&& $incremental);
	}
    }

    # Now the logic in GLI's CollectionManager.java	(processComplete() 
    # and installCollection()) and Gatherer.configGS3Server().
    
    # 1. Get library URL
    # CollectionManager's installCollection phase in GLI:
    # 2. Ping the library URL, and if it's a persistent server and running, release the collection   
    $gsserver->do_deactivate() unless $skipactivation;    

    # 2b. If we're working with a solr collection, then start up the solrserver now.
    my $solr_server;
    my @corenames = ();
    if($buildtype eq "solr") { # start up the jetty server	
	my $solr_ext = $ENV{'GEXT_SOLR'}; # from solr_passes.pl
	unshift (@INC, "$solr_ext/perllib");
	require solrserver;

	# Solr cores are named without taking the collection-group name into account, since solr
	# is used for GS3 and GS3 doesn't use collection groups but has the site concept instead
	my ($colname, $colgroup) = &util::get_collection_parts($qualified_collection);

	# See solrbuilder.pm to get the indexing levels (document, section) from the collectcfg file
	# Used to generate core names from them and remove cores by name
	foreach my $level ( @{$collectcfg->{'levels'}} ){
	    my ($pindex) = $level =~ /^(.)/;
	    my $indexname = $pindex."idx";
	    push(@corenames, "$site-$colname-$indexname"); #"$site-$colname-didx", "$site-$colname-sidx"
        }
	
	# If the Solr/Jetty server is not already running, the following starts
	# it up, and only returns when the server is "reading and listening"	
	$solr_server = new solrserver($build_dir);
	$solr_server->start();
	
	# We'll be moving building to index. For solr collection, there's further 
	# special processing to make a corresponding change to the solr.xml
	# by removing the temporary building cores and (re)creating the index cores
    }


    # 3. Do all the moving building to index stuff now	
    
    # If removeold: replace index dir with building dir.
    # If keepold: move building's contents into index, where only duplicates will get deleted.
    # removeold and keepold can't both be on at the same time
    # incremental becomes relevant for solr, though it was irrelevant to what activate.pl does (moving building to index)
    my $incremental_mode;
    ($removeold, $keepold, $incremental, $incremental_mode) = &scriptutil::check_removeold_and_keepold($removeold, $keepold, 
						   $incremental,
						   $index_dir, # checkdir. Usually archives or export to be deleted. activate.pl deletes index
						   $collectcfg);
	
    if($removeold) {
	
	if(&FileUtils::directoryExists($index_dir)) {
	    $gsserver->print_task_msg("Removing \"index\"");
	    
	    if ($buildtype eq "solr") {
		# if solr, remove any cores that are using the index_dir before deleting this dir
		foreach my $corename (@corenames) {
		    $solr_server->admin_unload_core($corename);
		}
	    }	
	    
	    &FileUtils::removeFilesRecursive($index_dir);
	    
	    # Wait for a couple of seconds, just for luck
	    sleep 2;
	    
	    if (&FileUtils::directoryExists($index_dir)) {
		$gsserver->print_msg("The index directory $index_dir could not be deleted.\n"); # CollectionManager.Index_Not_Deleted
	    }
	}
	
	# if remote GS server: gliserver.pl would call activate.pl to activate 
	# the collection at this point since activate.pl lives on the server side
	
	if ($buildtype eq "solr") {
	    # if solr, remove any cores that are using the building_dir before moving this dir onto index
	    foreach my $corename (@corenames) {
		$solr_server->admin_unload_core("building-$corename");
	    }
	}
	
	# Move the building directory to become the new index directory
	$gsserver->print_task_msg("Moving \"building\" -> \"index\"");
	&FileUtils::moveFiles($build_dir, $index_dir);
	if(&FileUtils::directoryExists($build_dir) || !&FileUtils::directoryExists($index_dir)) {			
	    $gsserver->print_msg("Could not move $build_dir to $index_dir.\n"); # CollectionManager.Build_Not_Moved
	}
    }
    elsif ($keepold || $incremental) {
	if ($buildtype eq "solr" && $build_dir ne $index_dir) {
	    # if solr, remove any cores that may be using the building_dir before moving this dir onto index
	    foreach my $corename (@corenames) {			
		$solr_server->admin_unload_core("building-$corename") if $solr_server->admin_ping_core("building-$corename");
	    }
	}
	
	if($build_dir eq $index_dir) { # building_dir can have been set to "index" folder, see incremental-buildcol.pl
	    $gsserver->print_task_msg("building folder is index folder, not moving");
	} else {
	    # Copy just the contents of building dir into the index dir, overwriting 
	    # existing files, but don't replace index with building.
	    $gsserver->print_task_msg("Moving \"building\" -> \"index\"");		
	    &FileUtils::moveDirectoryContents($build_dir, $index_dir);
	}
    }


    # now we've moved building to index, move tmp oaidb to live oaidb in parallel
    my $oai_info = new oaiinfo($collect_cfg_filename, $collectcfg->{'infodbtype'}, $default_verbosity);
    $oai_info->activate_collection();

    
    if ($buildtype eq "solr") {
	# Call CREATE action to get the old cores pointing to the index folder
	foreach my $corename (@corenames) {
	    if($removeold) {
		# Call CREATE action to get all cores pointing to the index folder, since building is now index
		$solr_server->admin_create_core($corename, $index_dir);
		
	    } elsif ($keepold || $incremental) { 
		# Call RELOAD core. Should already be using the index_dir directory for $keepold and $incremental case
		
		# Ping to see if corename exists, if it does, reload, else create
		if ($solr_server->admin_ping_core($corename)) {
		    $solr_server->admin_reload_core($corename); 
		} else {
		    $solr_server->admin_create_core($corename, $index_dir);
		}
	    }
	}
	
	# regenerate the solr.xml.in from solr.xml in case we are working off a dvd. 
	$solr_server->solr_xml_to_solr_xml_in();
    }

    
    # 4. Ping the library URL, and if it's a persistent server and running, activate the collection again
    
    # Check for success: if building does not exist OR is empty OR if building is index (in which case there was no move)	
    if($build_dir eq $index_dir || !&FileUtils::directoryExists($build_dir) || &FileUtils::isDirectoryEmpty($build_dir)) {
	
	$gsserver->do_activate() unless $skipactivation;
	
    } else { # installcollection failed		
	#CollectionManager.Preview_Ready_Failed
	$gsserver->print_msg("Building directory is not empty or still exists. Failed to properly move $build_dir to $index_dir.\n");
    }
    
    $gsserver->print_msg("\n");
    
    if($buildtype eq "solr") {
	if ($solr_server->explicitly_started()) {
	    $solr_server->stop();
	}
    }
}

&main(scalar(@ARGV),@ARGV);
