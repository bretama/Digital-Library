#!/usr/bin/perl -w

###########################################################################
#
# classinfo.pl -- provide information about classifiers
#
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

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/classify");

    if (defined $ENV{'GSDLEXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDLHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/classify");
	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDL3SRCHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/classify");

	}
    }

}

use classify;
use util;
use gsprintf;
use printusage;

use parse2;

my $arguments =
    [ { 'name' => "collection",
	'desc' => "{classinfo.collection}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
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

my $options = { 'name' => "classinfo.pl",
		'desc' => "{classinfo.desc}",
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
    my $language;

    my $hashParsingResult = {};
    # general options available to all classifiers
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");
    # parse returns -1 if an error occurred
    if($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{classinfo.params}");
	die "\n";
    }

    foreach my $strVariable (keys %$hashParsingResult)
    {
	eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }
    # If $language has been specified, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language) {
	&gsprintf::load_language_specific_resource_bundle($language);
    }
    
    # If there is not exactly 1 argument left (classifier name), then the arguments were wrong
    # If the user specified -h, then we output the usage also
    if((@ARGV && $ARGV[0] =~ /^\-+h/) )
    {
	PrintUsage::print_txt_usage($options, "{classinfo.params}");  
        die "\n";
    }

    # If there is not exactly 1 argument left (classifier name), then the arguments were wrong (apart from if we had listall or describeall set)
    if ($listall == 0 && $describeall ==0 && $intArgLeftinAfterParsing == 0) {
	gsprintf(STDERR, "{classinfo.no_classifier_name}\n\n");
	PrintUsage::print_txt_usage($options, "{classinfo.params}", 1);
	die "\n";
    }
	
    # we had some arguments that we weren't expecting
    if ($intArgLeftinAfterParsing > 1) {
	pop(@ARGV); # assume that the last arg is the classifier name
	gsprintf(STDERR, "{common.invalid_options}\n\n", join (',', @ARGV));
	PrintUsage::print_txt_usage($options, "{classinfo.params}", 1);
	die "\n";
    }

    # Get classifier
    my $classifier = shift (@ARGV);
    if (defined $classifier) {
	$classifier =~ s/\.pm$//; # allow xxx.pm as the argument
    }

    # make sure the classifier is loaded from the correct location - a hack.
    if ($collection ne "") {
	$ENV{'GSDLCOLLECTDIR'} = &util::filename_cat ($ENV{'GSDLHOME'}, "collect", $collection);
    } else {
	$ENV{'GSDLCOLLECTDIR'} = $ENV{'GSDLHOME'};
    }
 
    if ($listall || $describeall) {
	my $classify_dir = &util::filename_cat($ENV{'GSDLCOLLECTDIR'}, "perllib", "classify");
	my @classifier_list = ();
	if (opendir (INDIR, $classify_dir)) {
	    @classifier_list = grep (/\.pm$/, readdir (INDIR));
	    closedir (INDIR);
	}

	if ((defined $ENV{'GSDLEXTS'}) && ($collection eq "")) {
	    my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	    foreach my $e (@extensions) {
		my $ext_prefix = &util::filename_cat($ENV{'GSDLHOME'},"ext",$e);
		my $ext_classify_dir = &util::filename_cat($ext_prefix, "perllib", "classify");

		if (opendir (INDIR, $ext_classify_dir)) {
		    my @ext_classifier_list = grep (/\.pm$/, readdir (INDIR));
		    closedir (INDIR);

		    push(@classifier_list,@ext_classifier_list);
		}

	    }
	}

	print STDERR "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print STDERR "<ClassifyList length=\"" . scalar(@classifier_list) . "\">\n";
	foreach my $classifier (@classifier_list) {
	    $classifier =~ s/\.pm$//;
	    my $classifierobj = &classify::load_classifier_for_info ($classifier);
	    if ($describeall) {
		$classifierobj->print_xml_usage(0);
	    }
	    else {
		$classifierobj->print_xml_usage(0, 1);
	    }
	}
	print STDERR "</ClassifyList>\n";
    }
    else {
	&print_single_classifier($classifier, $xml, 1);
    }
}


sub print_single_classifier {
    my ($classifier, $xml, $header) = @_;
    my $classobj = &classify::load_classifier_for_info ($classifier);
    if ($xml) {
	$classobj->print_xml_usage($header);
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

	&gsprintf(STDERR, "\n{classinfo.passing_options}\n\n");
	&gsprintf(STDERR, "{classinfo.option_types}:\n\n");
	&gsprintf(STDERR, "{classinfo.specific_options}\n\n");
	&gsprintf(STDERR, "{classinfo.general_options}\n\n");
	&gsprintf(STDERR, "$classifier {classinfo.info}:\n\n");
	
	$classobj->print_txt_usage();
    }
    
}


&main ();
