#!/usr/bin/perl -w

###########################################################################
#
# downloadinfo.pl -- prints out information about a download module
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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


use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/downloaders");
}

use download;
use util;
use gsprintf;
use printusage;
use parse2;

my $arguments =
    [ { 'name' => "collection",
	'desc' => "{downloadinfo.collection}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no"},
      { 'name' => "listall",
	'desc' => "{scripts.listall}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "describeall",
	'desc' => "{scripts.describeall}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no" } ];

my $options = { 'name' => "downloadinfo.pl",
		'desc' => "{downloadinfo.desc}",
		'args' => $arguments };

sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}


sub main {
	
    my $collection = "";
    my $xml = 0;
    my $listall = 0;
    my $describeall = 0;
    my ($language, $encoding);
    my $hashParsingResult = {};
    my $unparsed_args = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");

    # parse returns -1 on error
    if ($unparsed_args == -1) {
	PrintUsage::print_txt_usage($options, "{downloadinfo.params}");
	die "\n";
    }

    foreach my $strVariable (keys %$hashParsingResult)
    {
	my $value = $hashParsingResult->{$strVariable};
	# test to make sure the variable name is 'safe'
	if ($strVariable !~ /^\w+$/) {
 	    die "variable name '$strVariable' isn't safe!";
	}
	eval "\$$strVariable = \$value";
    }
    
    # if language wasn't specified, see if it is set in the environment
    # (LC_ALL or LANG)
    if (!$language && ($_=$ENV{'LC_ALL'} or $_=$ENV{'LANG'})) {
	m/^([^\.]+)\.?(.*)/;
	$language=$1;
	$encoding=$2; # might be undef...
# gsprintf::load_language* thinks "fr" is completely different to "fr_FR"...
	$language =~ s/_.*$//;
    }

    # If $language has been set, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language) {
	gsprintf::load_language_specific_resource_bundle($language);
	if ($encoding) {
	    $encoding =~ tr/-/_/;
	    $encoding = lc($encoding);
	    $encoding =~ s/utf_8/utf8/; # special
	    $gsprintf::specialoutputencoding=$encoding;
	}
    }
    
    # If there is not exactly one argument left (download name), then the arguments were wrong
    # Or if the user specified -h, then we output the usage also

    if((@ARGV && $ARGV[0] =~ /^\-+h/) )
    {
	PrintUsage::print_txt_usage($options, "{downloadinfo.params}");
	die "\n";
    }
    
    # If there is not exactly 1 argument left (download name), then the arguments were wrong (apart from if we had listall or describeall set)
    if ($listall == 0 && $describeall ==0 && $unparsed_args == 0) {
	gsprintf(STDERR, "{downloadinfo.no_download_name}\n\n");
	PrintUsage::print_txt_usage($options, "{downloadinfo.params}", 1);
	die "\n";
    }

    # we had some arguments that we weren't expecting
    if ($unparsed_args > 1) {
	pop(@ARGV); # assume that the last arg is the download name
	gsprintf(STDERR, "{common.invalid_options}\n\n", join (',', @ARGV));
	PrintUsage::print_txt_usage($options, "{downloadinfo.params}", 1);
	die "\n";
    }
    my $download_name = shift (@ARGV);
    if (defined $download_name) {
	$download_name =~ s/\.pm$//; # allow xxx.pm as the argument
    }

    if ($collection ne "") {
	$ENV{'GSDLCOLLECTDIR'} = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", $collection);
    } else {
	$ENV{'GSDLCOLLECTDIR'} = $ENV{'GSDLHOME'};
    }

    if ($listall || $describeall) {
	my $downloaders_dir = &util::filename_cat($ENV{'GSDLCOLLECTDIR'}, "perllib", "downloaders");
	my @downloader_list = ();
	if (opendir (INDIR, $downloaders_dir)) {
	    @downloader_list = grep (/Download\.pm$/, sort(readdir (INDIR)));
	    closedir (INDIR);
	}

	print STDERR "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print STDERR "<DownloadList length=\"" . scalar(@downloader_list) . "\">\n";
	foreach my $downloader (@downloader_list) {
	    $downloader =~ s/\.pm$//;
	    my $downloaderobj = &download::load_download ($downloader);
	    if ($describeall) {
		$downloaderobj->print_xml_usage(0);
	    }
	    else {
		$downloaderobj->print_xml_usage(0, 1);
	    }
	}
	print STDERR "</DownloadList>\n";
    }
    else {
	&print_single_download($download_name, $xml, 1);
    }
}


sub print_single_download {
    my ($download, $xml, $header) = @_;
    my @options  = ("-gsdlinfo");
    my $downloadobj = &download::load_download ($download, \@options );
    if ($xml) {
	$downloadobj->print_xml_usage($header);
    }
    else {
	gsprintf(STDERR, "{downloadinfo.option_types}:\n\n");
	gsprintf(STDERR, "{downloadinfo.specific_options}\n\n");
	gsprintf(STDERR, "{downloadinfo.general_options}\n\n");
	gsprintf(STDERR, "$download {common.info}:\n\n");
	
	$downloadobj->print_txt_usage();
    }
    
}

&main ();
