#!/usr/bin/perl -w

###########################################################################
#
# mkcol.pl --
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


# This program will setup a new collection from a model one. It does this by
# copying the model, moving files to have the correct names, and replacing
# text within the files to match the parameters.

package mkcol;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use parse2;
use util;
use cfgread;
use gsprintf 'gsprintf';
use printusage;

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

my $public_list = 
    [ { 'name' => "true",
	'desc' => "{mkcol.public.true}"},
      { 'name' => "false",
	'desc' => "{mkcol.public.false}"} 
      ];

my $win31compat_list = 
    [ { 'name' => "true",
	'desc' => "{mkcol.win31compat.true}"},
      { 'name' => "false",
	'desc' => "{mkcol.win31compat.false}"} 
      ];

my $buildtype_list = 
    [ { 'name' => "mgpp",
	'desc' => "{mkcol.buildtype.mgpp}"},
      { 'name' => "lucene",
	'desc' => "{mkcol.buildtype.lucene}"},
      { 'name' => "mg",
	'desc' => "{mkcol.buildtype.mg}"}
      ];

my $infodbtype_list = 
    [ { 'name' => "gdbm",
	'desc' => "{mkcol.infodbtype.gdbm}"},
      { 'name' => "sqlite",
	'desc' => "{mkcol.infodbtype.sqlite}"},
      { 'name' => "jdbm",
	'desc' => "{mkcol.infodbtype.jdbm}"},
      { 'name' => "mssql",
	'desc' => "{mkcol.infodbtype.mssql}"},
      { 'name' => "gdbm-txtgz",
	'desc' => "{mkcol.infodbtype.gdbm-txtgz}"}
      ];

my $arguments =
    [ { 'name' => "creator",
	'desc' => "{mkcol.creator}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "optionfile",
	'desc' => "{mkcol.optionfile}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "maintainer",
	'desc' => "{mkcol.maintainer}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "group",
	'desc' => "{mkcol.group}",
	'type' => "flag",
	'reqd' => "no" },
      # For gs3, either -collectdir and -gs3mode (deprecated), or -site must be provided in order to locate the right collect directory and create a gs3 collection.
      { 'name' => "gs3mode",
	'desc' => "{mkcol.gs3mode}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "collectdir",
	'desc' => "{mkcol.collectdir}",
	'type' => "string",
	'reqd' => "no" }, 
      { 'name' => "site",
	'desc' => "{mkcol.site}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "public",
	'desc' => "{mkcol.public}",
	'type' => "enum",
	'deft' => "true",
	'list' => $public_list,
	'reqd' => "no" },
      { 'name' => "title",
	'desc' => "{mkcol.title}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "about",
	'desc' => "{mkcol.about}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "buildtype",
	'desc' => "{mkcol.buildtype}",
	'type' => "enum",
	'deft' => "mgpp",
	'list' => $buildtype_list,
	'reqd' => "no" },
      { 'name' => "infodbtype",
	'desc' => "{mkcol.infodbtype}",
	'type' => "enum",
	'deft' => "gdbm",
	'list' => $infodbtype_list,
	'reqd' => "no" },
      { 'name' => "plugin",
	'desc' => "{mkcol.plugin}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "quiet",
	'desc' => "{mkcol.quiet}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "win31compat",
	'desc' => "{mkcol.win31compat}",
	'type' => "enum",
	'deft' => "false",
	'list' => $win31compat_list,
	'reqd' => "no" },
      { 'name' => "gli",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" }
      ];

my $options = { 'name' => "mkcol.pl",
		'desc' => "{mkcol.desc}",
		'args' => $arguments };

# options
my ($creator, $optionfile, $maintainer, $gs3mode, $group, $collectdir, $site, 
    $public, $title, $about, $buildtype, $infodbtype, $plugin, $quiet, 
    $language, $win31compat, $gli);

#other variables
my ($collection, $capcollection, 
    $collection_tail, $capcollection_tail, 
    $pluginstring, @plugin);

&main();


sub traverse_dir
{
    my ($modeldir, $coldir) = @_;
    my ($newfile, @filetext);

    if (!(-e $coldir)) {
	

	my $store_umask = umask(0002);
	my $mkdir_ok = mkdir ($coldir, 0777);
	umask($store_umask);

	if (!$mkdir_ok) 
	{
	    die "$!";
	}
    }

    opendir(DIR, $modeldir) ||
	(&gsprintf(STDERR, "{common.cannot_read}\n", $modeldir) && die);
    my @files = grep(!/^(\.\.?|CVS|\.svn)$/, readdir(DIR));
    closedir(DIR);

    foreach my $file (@files)
    {
	if ($file =~ /^macros$/) {
	    
	    # don't want macros folder for gs3mode
	    next if $gs3mode;
	}
	if ($file =~ /^import$/) {
	    # don't want import for group
	    next if $group;
	}
	
	my $thisfile = &util::filename_cat ($modeldir, $file);

	if (-d $thisfile) {
	    my $colfiledir = &util::filename_cat ($coldir, $file);
	    traverse_dir ($thisfile, $colfiledir);

	} else {

	    next if ($file =~ /~$/);

	    my $destfile = $file;
	    $destfile =~ s/^modelcol/$collection/;
	    $destfile =~ s/^MODELCOL/$capcollection/;

	    # There are three configuration files in modelcol directory:
	    # collect.cfg, group.cfg and collectionConfig.xml.
	    # If it is gs2, copy relevant collect.cfg or group.cfg file; if gs3, copy collectionConfig.xml.
	    
	    if ($file =~ /^collect\.cfg$/) {
		next if ($gs3mode || $group);
	    }
	    elsif ($file =~ /^group\.cfg$/) {
		next unless $group;
		$destfile =~ s/group\.cfg/collect\.cfg/;
	    }
	    elsif ($file =~ /^collectionConfig\.xml$/) {
		next unless $gs3mode;
	    }
	    
	    &gsprintf(STDOUT, "{mkcol.doing_replacements}\n", $destfile)
		unless $quiet;
	    $destfile = &util::filename_cat ($coldir, $destfile);

	    open (INFILE, $thisfile) || 
		(&gsprintf(STDERR, "{common.cannot_read_file}\n", $thisfile) && die);
	    open (OUTFILE, ">$destfile") ||
		(&gsprintf(STDERR, "{common.cannot_create_file}\n", $destfile) && die);

	    while (defined (my $line = <INFILE>)) {
		$line =~ s/\*\*collection\*\*/$collection_tail/g;
		$line =~ s/\*\*COLLECTION\*\*/$capcollection_tail/g;
		$line =~ s/\*\*creator\*\*/$creator/g;
		$line =~ s/\*\*maintainer\*\*/$maintainer/g;
		$line =~ s/\*\*public\*\*/$public/g;
		$line =~ s/\*\*title\*\*/$title/g;
		$line =~ s/\*\*about\*\*/$about/g;
		$line =~ s/\*\*buildtype\*\*/$buildtype/g;
		$line =~ s/\*\*infodbtype\*\*/$infodbtype/g;
		if (!$gs3mode) {
		   $line =~ s/\*\*plugins\*\*/$pluginstring/g;
		 }

		print OUTFILE $line;
	    }
	    
	    close (OUTFILE);
	    close (INFILE);
	}
    }
}


sub main {
    
    my $xml = 0;
    

    my $hashParsingResult = {};
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");
    
    # If parse returns -1 then something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{mkcol.params}");
	die "\n";
    }
    
    foreach my $strVariable (keys %$hashParsingResult)
    {
	eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }

    # If $language has been specified, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language && $language =~ /\S/) {
	&gsprintf::load_language_specific_resource_bundle($language);
    }

    if ($xml) {
	&PrintUsage::print_xml_usage($options);
	print "\n";
	return;
    }

    if ($gli) { # the gli wants strings to be in UTF-8
	&gsprintf::output_strings_in_UTF8; 
    }

    # now check that we had exactly one leftover arg, which should be 
    # the collection name. We don't want to do this earlier, cos 
    # -xml arg doesn't need a collection name
    # Or if the user specified -h, then we output the usage also
    if ($intArgLeftinAfterParsing != 1 || (@ARGV && $ARGV[0] =~ /^\-+h/))
    {
	&PrintUsage::print_txt_usage($options, "{mkcol.params}");
	die "\n";
    }

    if ($optionfile =~ /\w/) {
	open (OPTIONS, $optionfile) ||
	    (&gsprintf(STDERR, "{common.cannot_open}\n", $optionfile) && die);
	my $line = [];
	my $options = [];
	while (defined ($line = &cfgread::read_cfg_line ('mkcol::OPTIONS'))) {
	    push (@$options, @$line);
	}
	close OPTIONS;
	my $optionsParsingResult = {};
	if (parse2::parse($options,$arguments,$optionsParsingResult) == -1) {
	    &PrintUsage::print_txt_usage($options, "{mkcol.params}");
	    die "\n";
	}
	    
	foreach my $strVariable (keys %$optionsParsingResult)
	{
	    eval "\$$strVariable = \$optionsParsingResult->{\"\$strVariable\"}";
	}
    }
    
    # load default plugins if none were on command line
    if (!scalar(@plugin)) {
	@plugin = (ZIPPlugin,GreenstoneXMLPlugin,TextPlugin,HTMLPlugin,EmailPlugin,
		   PDFPlugin,RTFPlugin,WordPlugin,PostScriptPlugin,PowerPointPlugin,ExcelPlugin,ImagePlugin,ISISPlugin,NulPlugin,EmbeddedMetadataPlugin,MetadataXMLPlugin,ArchivesInfPlugin,DirectoryPlugin);
    }

    # get and check the collection name
    ($collection) = @ARGV;

    # get capitalised version of the collection
    $capcollection = $collection;
    $capcollection =~ tr/a-z/A-Z/;

    $collection_tail = &util::get_dirsep_tail($collection);
    $capcollection_tail = &util::get_dirsep_tail($capcollection);


    if (!defined($collection)) {
	&gsprintf(STDOUT, "{mkcol.no_colname}\n");
	&PrintUsage::print_txt_usage($options, "{mkcol.params}");
	die "\n";
    }

    if (($win31compat eq "true") && (length($collection_tail)) > 8) {
	&gsprintf(STDOUT, "{mkcol.long_colname}\n");
	die "\n";
    }

    if ($collection eq "modelcol") {
	&gsprintf(STDOUT, "{mkcol.bad_name_modelcol}\n");
	die "\n";
    }

    if ($collection_tail eq "CVS") {
	&gsprintf(STDOUT, "{mkcol.bad_name_cvs}\n");
	die "\n";
    }

    if ($collection_tail eq ".svn") {
	&gsprintf(STDOUT, "{mkcol.bad_name_svn}\n");
	die "\n";
    }

    if (defined($creator) && (!defined($maintainer) || $maintainer eq "")) {
	$maintainer = $creator;
    }

    $public = "true" unless defined $public;

    if (!defined($title) || $title eq "") {
	$title = $collection_tail;
    }

    if ($gs3mode && $group) {
	&gsprintf(STDERR,"{mkcol.group_not_valid_in_gs3}\n");
	die "\n";
    }

    # get the strings to include.
    $pluginstring = "";
    foreach my $plug (@plugin) {
	$pluginstring .= "plugin         $plug\n";
    }

    if ($gs3mode) {
	if (!defined $site) {
	    print STDERR "Warning: -gs3mode is deprecated.\n";
	    print STDERR "Use -site <name> instead to create a Greenstone 3 collection\n";
	}
    }
    else {
	# gs3mode not set
	if (defined $site && $site =~ /\w/) {
	    # Using -site, so -gs3mode implicitly is true
	    $gs3mode = 1;
	}
    }

    my $mdir = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", "modelcol");
    my $cdir;
    if (defined $collectdir && $collectdir =~ /\w/) {
	if (!-d $collectdir) {
	    &gsprintf(STDOUT, "{mkcol.no_collectdir}\n", $collectdir);
	    die "\n";
	}
	$cdir = &util::filename_cat ($collectdir, $collection);
    } else {
      if (!$gs3mode) {
	$cdir = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", $collection);
      }else {
	  if (defined $site && $site =~ /\w/) {
	      die "GSDL3HOME not set\n" unless defined $ENV{'GSDL3HOME'};

	      $cdir  = &util::filename_cat($ENV{'GSDL3HOME'}, "sites", $site, "collect");
	      if (!-d $cdir) {
		  &gsprintf(STDOUT, "{mkcol.no_collectdir}\n", $cdir);
		  die "\n";
	      }
	      $cdir = &util::filename_cat ($cdir, $collection);
	  } else {
	    &gsprintf(STDOUT, "{mkcol.no_collectdir_specified}\n");
	    die "\n";
	}
      }
    }

    # make sure the model collection exists
    (&gsprintf(STDERR, "{mkcol.cannot_find_modelcol}\n", $mdir) && die) unless (-d $mdir);

    # make sure this collection does not already exist
    if (-e $cdir) {
	&gsprintf(STDOUT, "{mkcol.col_already_exists}\n");
	die "\n";
    }

    # start creating the collection
    &gsprintf(STDOUT, "\n{mkcol.creating_col}...\n", $collection)
	unless $quiet;

    &traverse_dir ($mdir, $cdir);
    &gsprintf(STDOUT, "\n{mkcol.success}\n", $cdir)
	unless $quiet;
}


