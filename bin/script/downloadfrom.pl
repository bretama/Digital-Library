#!/usr/bin/perl -w

###########################################################################
#
# downloadfrom.pl -- program to download files from an external server
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

package downloadfrom;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/downloaders");         
}

use strict;
no strict 'subs';
use parse2;
use download;
use gsprintf 'gsprintf';
use printusage;

my $download_mode_list = 
    [ { 'name' => "Web",
        'desc' => "{downloadfrom.download_mode.Web}",
	'downloadname' => "WebDownload" },
	  { 'name' => "MediaWiki",
	  	'desc' => "{downloadfrom.download_mode.MediaWiki}",
	  	'downloadname' => "MediaWikiDownload" },
      { 'name' => "OAI",
        'desc' => "{downloadfrom.download_mode.OAI}",
	'downloadname' => "OAIDownload" },
      { 'name' => "Z3950",
        'desc' => "{downloadfrom.download_mode.Z3950}",
	'downloadname' => "Z3950Download" },
      { 'name' => "SRW",
        'desc' => "{downloadfrom.download_mode.SRW}",
	'downloadname' => "SRWDownload" } ];

my $arguments = 
    [ { 'name' => "download_mode",
	'desc' => "{downloadfrom.download_mode}",
	'type' => "enum",
	'list' => $download_mode_list,
	'reqd' => "yes" },
      { 'name' => "cache_dir",
	'desc' => "{downloadfrom.cache_dir}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "gli",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "info", ,  
	'desc' => "{downloadfrom.info}",  
	'type' => "flag",
	'reqd' => "no"}
      ];

my $options = { 'name' => "downloadfrom.pl",
		'desc' => "{downloadfrom.desc}",
		'args' => $arguments };


# This function return the coresponding mode with a given mode string.
sub findMode
{
    my ($strInput) = @_;

    foreach my $hashMode (@$download_mode_list)
    {
	if($strInput eq $hashMode->{'name'})
	{
	    return $hashMode->{'downloadname'};
	}
    }
    return "";
}

# main program
sub main
{
    
   my $hashOptions = {};
   my ($strMode,$objMode,$pntArg);
   $pntArg = \@ARGV;

   # Parsing the General options for downloadfrom.pl, 
   # this parsing operation will allow extra options, 
   # since there might be some arguments for Download.
   # extra arguments will be detected by the Downloads
   parse2::parse(\@ARGV,$arguments,$hashOptions,"allow_extra_options");
   # hashOptions: This is a hash map which maps to 
   #              downloadfrom's arguments
   #              $hashOptions->{'cache_dir'}
   #              $hashOptions->{'download_mode'}
   #              $hashOptions->{'gli'}
   #              $hashOptions->{'info'}

   $strMode = &findMode($hashOptions->{'download_mode'});
  
    if ($strMode eq "") {
       &gsprintf(STDERR, "{downloadfrom.incorrect_mode}\n");
       &PrintUsage::print_txt_usage($options, "{downloadfrom.params}");
       die "\n";

   }
   $objMode = &download::load_download($strMode, $pntArg);
   
   if($hashOptions->{'info'})
    {
    
	my $blnResult = &download::get_information($objMode);
    }
    else
    {
	print "downloadfrom.pl start gathering data by using $strMode...\n\n";
	
	# need to remove trailing slash from cache dir
	if (defined $hashOptions->{'cache_dir'}) {
	    $hashOptions->{'cache_dir'} =~ s/[\/\\]$//;
	}
	my $blnResult = &download::process($objMode,$hashOptions);
	
	($blnResult eq "true")?
	    print  "\ndownloadfrom.pl has completed data gathering\n":
	    print "\ndownloadfrom.pl has failed to gather data\n";
    } 

     
}


&main();


