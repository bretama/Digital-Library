#!/usr/bin/perl -w

###########################################################################
#
# exportcol.pl --
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

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

use util;
use FileUtils;
use parse2;
use printusage;

my $arguments = 
    [ 
      { 'name' => "cdname",
	'desc' => "{exportcol.cdname}",
	'type' => "string",
	'deft' => "Greenstone Collections",
	'reqd' => "no" }, 
      { 'name' => "cddir",
	'desc' => "{exportcol.cddir}",
	'type' => "string",
	'deft' => "exported_collections",
	'reqd' => "no" },
      { 'name' => "collectdir",
	'desc' => "{exportcol.collectdir}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "collect"),
	'deft' => "",
	'reqd' => "no",
	'hiddengli' => "yes" },	
      { 'name' => "noinstall",
	'desc' => "{exportcol.noinstall}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "out",
	'desc' => "{exportcol.out}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "gli",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },

      ];

my $options = { 'name' => "exportcol.pl",
		'desc' => "{exportcol.desc}",
		'args' => $arguments };

sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}


&main();

sub main {
    my ($language, $out, $cdname, $cddir);
    
    my $noinstall = 0;
    my $xml = 0;
    my $gli = 0;
    my $collectdir;

    my $hashParsingResult = {};

    # parse options
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");

    # If parse returns -1 then something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{exportcol.params}");
	die "\n";
    }
    
    foreach my $strVariable (keys %$hashParsingResult)
    {
	eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }

    # the default/fallback for collect directory if none is provided
    # (no -collectdir option given) is the standard Greenstone collect directory
    if(!$collectdir) {
	$collectdir = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "collect");
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
    
	# var collectdir (dir from where selected collections are exported to the CD) 
	# may have been set at this point if it was specified with -collectdir
	
    # can have more than one collection name,  
    # if the first extra option is -h, then output the help
    if (scalar(@ARGV) == 0 || (@ARGV && $ARGV[0] =~ /^\-+h/)) {
	&PrintUsage::print_txt_usage($options, "{exportcol.params}");
	die "\n";
    }

    my @coll_list = @ARGV;

    my $close_out = 0;
    if ($out !~ /^(STDERR|STDOUT)$/i) {
	open (OUT, ">$out") || 
	    (&gsprintf(STDERR, "{common.cannot_open_output_file}\n", $out) && die);
	$out = 'main::OUT';
	$close_out = 1;
    }

    # first we do a quick check to see if the export coll function has been 
    # installed
    my $gssetupexe = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "bin", "windows", "gssetup.exe"); 
    if (!-e $gssetupexe) {
	&gsprintf($out, "{exportcol.fail} {exportcol.export_coll_not_installed}\n");
	die "\n";
    }

    # check each collection
    my @valid_coll_list = ();
    foreach my $c (@coll_list) {
	my $colldir = &FileUtils::filenameConcatenate ($collectdir, $c);
	if (! -d $colldir) {
	    &gsprintf($out, "{exportcol.coll_not_found}\n", $c, $colldir);
	    next;
	}
	my $colindexdir = &FileUtils::filenameConcatenate ($colldir, "index");
	my $coletcdir = &FileUtils::filenameConcatenate ($colldir, "etc");
	if ((!-d $colindexdir) || (!-d $coletcdir)) {
	    &gsprintf($out, "{exportcol.coll_dirs_not_found}\n", $c);
	    &gsprintf($out, "  $colindexdir\n");
	    &gsprintf($out, "  $coletcdir\n");
	    next;
	}
	# the collection seems ok, we add it to the valid coll list
	push @valid_coll_list, $c;
    }

    if (not @valid_coll_list) {
	# no valid colls left
	&gsprintf($out, "{exportcol.fail} {exportcol.no_valid_colls}\n");
	die "\n";
    }

    # create exported directory
    my $topdir = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "tmp", $cddir);
    &FileUtils::makeAllDirectories ($topdir);
    if (!-d $topdir) {
	&gsprintf($out, "{exportcol.fail} {exportcol.couldnt_create_dir}\n", $topdir);
	die "\n";
    }

    # we create either a self installing cd, or one that runs off the cd (and
    # doesn't install anything

    # create all the directories - we assume that if we created the top dir ok,
    # then all the other mkdirs will go ok
    my $gsdldir;
    if ($noinstall) {
	$gsdldir = $topdir;
    } 
    else {
	$gsdldir = &FileUtils::filenameConcatenate ($topdir, "gsdl");
	&FileUtils::makeAllDirectories ($gsdldir);
    }
    
    my $newcollectdir = &FileUtils::filenameConcatenate ($gsdldir, "collect");
    &FileUtils::makeAllDirectories ($newcollectdir);
    my $etcdir = &FileUtils::filenameConcatenate ($gsdldir, "etc");
    &FileUtils::makeAllDirectories ($etcdir);

    #create the config files
    if (!$noinstall) {
	# create the install.cfg file
	my $installcfg = &FileUtils::filenameConcatenate ($topdir, "install.cfg");
	if (!open (INSTALLCFG, ">$installcfg")) {
	    &gsprintf($out, "{exportcol.fail} {exportcol.couldnt_create_file}\n", $installcfg);
	    die "\n";
	}
	print INSTALLCFG "CompanyName:New Zealand Digital Library\n";
	print INSTALLCFG "CollectionName:$cdname\n";
	print INSTALLCFG "CollectionDirName:$cdname\n";
	print INSTALLCFG "CollectionVersion:1.0\n";
	print INSTALLCFG "CollectionVolume:1\n";
	print INSTALLCFG "ProgramGroupName:Greenstone\n";
	close INSTALLCFG;
	
	# create the manifest.cfg file
	my $manifestcfg = &FileUtils::filenameConcatenate ($topdir, "manifest.cfg");
	if (!open (MANIFESTCFG, ">$manifestcfg")) {
	    &gsprintf($out, "{exportcol.fail} {exportcol.couldnt_create_file}\n", $manifestcfg);
	    die "\n";
	}
	print MANIFESTCFG "all:\n";
	print MANIFESTCFG "  {library} {collection}\n\n";
	print MANIFESTCFG "library:\n";
	print MANIFESTCFG "  server.exe\n\n";
	print MANIFESTCFG "database:\n";
	print MANIFESTCFG '  etc ';
	foreach my $c (@valid_coll_list) {
	    print MANIFESTCFG "collect\\$c\\index\\text\\$c.gdb ";
	}
	print MANIFESTCFG "\n\n";
	print MANIFESTCFG "collection:\n";
	print MANIFESTCFG "  collect etc macros mappings web\n";
	close MANIFESTCFG;
	
    }	

    #create the autorun.inf file
    my $autoruninf = &FileUtils::filenameConcatenate ($topdir, "Autorun.inf");
    if (!open (AUTORUNINF, ">$autoruninf")) {
	&gsprintf($out, "{exportcol.fail} {exportcol.couldnt_create_file}\n", $autoruninf);
	die "\n";
    }
    
    print AUTORUNINF "[autorun]\n";
    if ($noinstall) {
	print AUTORUNINF "OPEN=server.exe\n";
    } else {
	print AUTORUNINF "OPEN=gssetup.exe\n"; # no longer autorun Setup.exe, since it fails on Win 7 64 bit
    }
    close AUTORUNINF;
    
    # copy the necessary stuff from GSDLHOME
    my $webdir = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "web");
    my $macrosdir = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "macros");
    my $mappingsdir = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "mappings");
    my $maincfg = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "etc", "main.cfg");
    my $serverexe = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "bin", "windows", "server.exe");
    my $setupexe = &FileUtils::filenameConcatenate ($ENV{'GSDLHOME'}, "bin", "windows", "Setup.exe");

    if ((!-d $webdir) || (!-d $macrosdir) || (!-d $mappingsdir) || (!-e $maincfg) ||
	(!-e $serverexe) || (!-e $gssetupexe) || (!-e $setupexe)) {
	&gsprintf($out, "{exportcol.fail} {exportcol.non_exist_files}\n");
	&gsprintf($out, "  $webdir\n");
	&gsprintf($out, "  $macrosdir\n");
	&gsprintf($out, "  $mappingsdir\n");
	&gsprintf($out, "  $maincfg\n");
	&gsprintf($out, "  $serverexe\n");
	&gsprintf($out, "  $gssetupexe\n");
	&gsprintf($out, "  $setupexe\n");
	die "\n";
    }

    &FileUtils::copyFilesRecursiveNoSVN ($webdir, $gsdldir);
    &FileUtils::copyFilesRecursiveNoSVN ($macrosdir, $gsdldir);
    &FileUtils::copyFilesRecursiveNoSVN ($mappingsdir, $gsdldir);
    &FileUtils::copyFiles ($maincfg, $etcdir);
    &FileUtils::copyFiles ($serverexe, $gsdldir);

    if (!$noinstall) {
	&FileUtils::copyFiles ($gssetupexe, $topdir);
	&FileUtils::copyFiles ($setupexe, $topdir); # unused, since Setup.exe does not work on Win 7 64-bit
    }	
    
    # now change the home.dm macro file to a simple version
    my $newmacrodir = &FileUtils::filenameConcatenate ($gsdldir, "macros");
    my $exporthome = &FileUtils::filenameConcatenate ($newmacrodir, "exported_home.dm");
    my $oldhome = &FileUtils::filenameConcatenate ($newmacrodir, "home.dm");
    if (-e $exporthome) {
	&FileUtils::removeFiles($oldhome);
	&FileUtils::moveFiles($exporthome, $oldhome);
    }

    # copy the collections over 
    foreach my $c (@valid_coll_list) {
	#old directories
	my $colldir = &FileUtils::filenameConcatenate ($collectdir, $c);
	my $colindexdir = &FileUtils::filenameConcatenate ($colldir, "index");
	my $coletcdir = &FileUtils::filenameConcatenate ($colldir, "etc");
	my $colmacrosdir = &FileUtils::filenameConcatenate ($colldir, "macros");
	my $colimagesdir = &FileUtils::filenameConcatenate ($colldir, "images");
	my $colscriptdir = &FileUtils::filenameConcatenate ($colldir, "script");
	my $coljavadir = &FileUtils::filenameConcatenate ($colldir, "java");
	my $colstyledir = &FileUtils::filenameConcatenate ($colldir, "style");
	my $colflashdir = &FileUtils::filenameConcatenate ($colldir, "flash");

	# new collection directory
	# $c might be in a group, for now, copy to the top level.
	my $new_c = $c;
	$new_c =~ s/^.*[\/\\]//; # remove any folder info
	my $newcoldir = &FileUtils::filenameConcatenate ($newcollectdir, $new_c);

	&FileUtils::makeAllDirectories ($newcoldir);
	&FileUtils::copyFilesRecursiveNoSVN ($colindexdir, $newcoldir);
	&util::rename_ldb_or_bdb_file(&FileUtils::filenameConcatenate ($newcoldir, "index", "text", $c));
	&FileUtils::copyFilesRecursiveNoSVN ($coletcdir, $newcoldir);
	&FileUtils::copyFilesRecursiveNoSVN ($colmacrosdir, $newcoldir) if (-e $colmacrosdir);
	&FileUtils::copyFilesRecursiveNoSVN ($colimagesdir, $newcoldir) if (-e $colimagesdir);
	&FileUtils::copyFilesRecursiveNoSVN ($colscriptdir, $newcoldir) if (-e $colscriptdir);
	&FileUtils::copyFilesRecursiveNoSVN ($coljavadir, $newcoldir) if (-e $coljavadir);
	&FileUtils::copyFilesRecursiveNoSVN ($colstyledir, $newcoldir) if (-e $colstyledir);
	&FileUtils::copyFilesRecursiveNoSVN ($colflashdir, $newcoldir) if (-e $colflashdir);

	# now we need to check the collect.cfg file to make sure it's public
	my $collectcfg = &FileUtils::filenameConcatenate ($newcoldir, "etc", "collect.cfg");
	open INFILE, "<$collectcfg";
	open OUTFILE, ">$collectcfg.tmp";
	my $line;
	while ($line = <INFILE>) {
	    if ($line =~ /^\s*public\s+false/) {
		print OUTFILE "public\ttrue\n";
		last; # stop matching once we have found the line
	    } else {
		print OUTFILE "$line";
	    }
	}
	# continue with no checking
	while ($line = <INFILE>) {
	    print OUTFILE "$line";
	}
	close INFILE;
	close OUTFILE;
	&FileUtils::moveFiles("$collectcfg.tmp", $collectcfg);
    }
    &gsprintf($out, "{exportcol.success}");

    my $successcolls = "";
    my $first = 1;
    foreach my $c (@valid_coll_list) {
	if ($first) {
	    $first=0;
	} else {
	    $successcolls .=", ";
	}
	$successcolls .= "$c";
    }

    my $gsdl_home = $ENV{'GSDLHOME'};
    my $portable_topdir = $topdir;
    # Disabled this because it isn't currently useful (the GLI applet doesn't do exporting)
    # It doesn't work on Windows, either
    # $portable_topdir =~ s/$gsdl_home/\$GSDLHOME/g;

    &gsprintf($out, "{exportcol.output_dir}\n", $successcolls, $portable_topdir);
    &gsprintf($out, "exportcol.pl succeeded:{exportcol.instructions}\n");
    close OUT if $close_out;
}

