#!/usr/bin/perl -w

###########################################################################
#
# pluginfo.pl --
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

# This program will print info about a plugin

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");

    if (defined $ENV{'GSDLEXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDLHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/plugins");
	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDL3SRCHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/plugins");
	}
    }

}

use plugin;
use util;
use gsprintf;
use printusage;
use parse2;

my $arguments =
    [ { 'name' => "site",
	'desc' => "{pluginfo.site}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "collection",
	'desc' => "{pluginfo.collection}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "gs_version",
	'desc' => "{pluginfo.gs_version}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no" },
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

my $options = { 'name' => "pluginfo.pl",
		'desc' => "{pluginfo.desc}",
		'args' => $arguments };

sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}


sub main {
    my $site = "";
    my $collection = "";
    my $gs_version = "";
    my $xml = 0;
    my $listall = 0;
    my $describeall = 0;
    my ($language, $encoding);

    my $hashParsingResult = {};
    # general options available to all plugins
    my $unparsed_args = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");
    # parse returns -1 if an error occurred
    if ($unparsed_args == -1) {
	
	PrintUsage::print_txt_usage($options, "{pluginfo.params}");
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

    if ($xml) {
	&gsprintf::set_print_freetext_for_xml();
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

    # If there is not exactly 1 argument left (plugin name), then the arguments were wrong
    # If the user specified -h, then we output the usage also
    if((@ARGV && $ARGV[0] =~ /^\-+h/) )
    {
	PrintUsage::print_txt_usage($options, "{pluginfo.params}");  
        die "\n";
    }

    # If there is not exactly 1 argument left (plugin name), then the arguments were wrong (apart from if we had listall or describeall set)
    if ($listall == 0 && $describeall ==0 && $unparsed_args == 0) {
	gsprintf(STDERR, "{pluginfo.no_plugin_name}\n\n");
	PrintUsage::print_txt_usage($options, "{pluginfo.params}", 1);
	die "\n";
    }

    # we had some arguments that we weren't expecting
    if ($unparsed_args > 1) {
	pop(@ARGV); # assume that the last arg is the plugin name
	gsprintf(STDERR, "{common.invalid_options}\n\n", join (',', @ARGV));
	PrintUsage::print_txt_usage($options, "{pluginfo.params}", 1);
	die "\n";
    }
	
    my $plugin = shift (@ARGV);
    if (defined $plugin) {
	$plugin =~ s/\.pm$//; # allow xxxPlugin.pm as the argument
    }

    if ($site ne "") {
	# assume Greenstone 3
	$gs_version = "3" if $gs_version eq "";
	if ($collection ne "") {
	    $ENV{'GSDLCOLLECTDIR'} = &util::filename_cat ($ENV{'GSDL3HOME'}, "sites", $site, "collect", $collection);
	} else {
	    # Probably more useful to default to GS2 area for plugins
	    $ENV{'GSDLCOLLECTDIR'} = $ENV{'GSDLHOME'};
	}
    }
    else {
	$gs_version = "2" if $gs_version eq "";
	if ($collection ne "") {
	    $ENV{'GSDLCOLLECTDIR'} = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", $collection);
	} else {
	    $ENV{'GSDLCOLLECTDIR'} = $ENV{'GSDLHOME'};
	}
    }

    if ($listall || $describeall) {
	my $plugins_dir = &util::filename_cat($ENV{'GSDLCOLLECTDIR'}, "perllib", "plugins");
	my @plugin_list = ();
	if (opendir (INDIR, $plugins_dir)) {
	    @plugin_list = grep (/Plugin\.pm$/, readdir (INDIR));
	    closedir (INDIR);
	}

	if ((defined $ENV{'GSDLEXTS'}) && ($collection eq "")) {
	    my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	    foreach my $e (@extensions) {
		my $ext_prefix = &util::filename_cat($ENV{'GSDLHOME'},"ext",$e);
		my $ext_plugins_dir = &util::filename_cat($ext_prefix, "perllib", "plugins");

		if (opendir (INDIR, $ext_plugins_dir)) {
		    my @ext_plugin_list = grep (/Plugin\.pm$/, readdir (INDIR));
		    closedir (INDIR);

		    push(@plugin_list,@ext_plugin_list);
		}

	    }
	}
	if ((defined $ENV{'GSDL3EXTS'}) && ($collection eq "")) {
	    my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	    foreach my $e (@extensions) {
		my $ext_prefix = &util::filename_cat($ENV{'GSDL3SRCHOME'},"ext",$e);
		my $ext_plugins_dir = &util::filename_cat($ext_prefix, "perllib", "plugins");

		if (opendir (INDIR, $ext_plugins_dir)) {
		    my @ext_plugin_list = grep (/Plugin\.pm$/, readdir (INDIR));
		    closedir (INDIR);

		    push(@plugin_list,@ext_plugin_list);
		}

	    }
	}

	# load up the plugins before writing out the xml so that any error
	# messages are not inside the XML output (can cause parsing to fail)
	my @plugobj_list;
	foreach my $plugin (@plugin_list) {
	    $plugin =~ s/\.pm$//;
	    my $plugobj = &plugin::load_plugin_for_info ($plugin, $gs_version);
	    push (@plugobj_list, $plugobj);
	}

	&gsprintf::set_print_xml_tags();
	print STDERR "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print STDERR "<PluginList length=\"" . scalar(@plugin_list) . "\">\n";
	foreach my $plugobj (@plugobj_list) {
	    if ($describeall) {
		$plugobj->print_xml_usage(0);
	    }
	    else {
		$plugobj->print_xml_usage(0, 1);
	    }
	}
	print STDERR "</PluginList>\n";


    }
    else {
	&print_single_plugin($plugin, $gs_version, $xml, 1);
    }
}


sub print_single_plugin {
    my ($plugin, $gs_version, $xml, $header) = @_;
    my $plugobj = &plugin::load_plugin_for_info ($plugin, $gs_version);
    if ($xml) {
	&gsprintf::set_print_xml_tags();
	$plugobj->print_xml_usage($header);
    }
    else {

	# this causes us to automatically send output to a pager, if one is
	# set, AND our output is going to a terminal
	# active state perl on windows doesn't do open(handle, "-|");
	if ($ENV{'GSDLOS'} !~ /windows/ && -t STDOUT) {
	    my $pager = $ENV{"PAGER"};
	    if (! $pager) {$pager="(less || more)"}
	    my $pid = open(STDIN, "-|"); # this does a fork... see man perlipc(1)
	    if (!defined $pid) {
		gsprintf(STDERR, "pluginfo.pl - can't fork: $!");
	    } else {
		if ($pid != 0) { # parent (ie forking) process. child gets 0
		    exec ($pager);
		}
	    }
	    open(STDERR,">&STDOUT"); # so it's easier to pipe output
	}

	gsprintf(STDERR, "\n{pluginfo.passing_options}\n\n");
	gsprintf(STDERR, "{pluginfo.option_types}:\n\n");
	gsprintf(STDERR, "{pluginfo.specific_options}\n\n");
	gsprintf(STDERR, "{pluginfo.general_options}\n\n");
	gsprintf(STDERR, "$plugin {pluginfo.info}:\n\n");
	
	$plugobj->print_txt_usage();
    }
    
}

&main ();
