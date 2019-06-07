#!/usr/bin/perl -w

###########################################################################
#
# import.pl --
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


# This program will import a number of files into a particular collection

package parallel_import;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugouts");

    if (defined $ENV{'GSDLEXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDLHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/plugins");
	    unshift (@INC, "$ext_prefix/perllib/plugouts");
	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDL3SRCHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	    unshift (@INC, "$ext_prefix/perllib/plugins");
	    unshift (@INC, "$ext_prefix/perllib/plugouts");
	}
    }
}

use strict;

use inexport;

my $oidtype_list = 
    [ { 'name' => "hash",
        'desc' => "{import.OIDtype.hash}" },
      { 'name' => "assigned",
        'desc' => "{import.OIDtype.assigned}" },
      { 'name' => "incremental",
        'desc' => "{import.OIDtype.incremental}" },
      { 'name' => "dirname",
        'desc' => "{import.OIDtype.dirname}" } ];


# used to control output file format
my $saveas_list = 
    [ { 'name' => "GreenstoneXML",
        'desc' => "{export.saveas.GreenstoneXML}"},
      { 'name' => "GreenstoneMETS",
        'desc' => "{export.saveas.GreenstoneMETS}"},
      ];


# Possible attributes for each argument
# name: The name of the argument
# desc: A description (or more likely a reference to a description) for this argument
# type: The type of control used to represent the argument. Options include: string, int, flag, regexp, metadata, language, enum etc
# reqd: Is this argument required?
# hiddengli: Is this argument hidden in GLI?
# modegli: The lowest detail mode this argument is visible at in GLI

my $saveas_argument
    = { 'name' => "saveas",
	'desc' => "{import.saveas}",
	'type' => "enum",
	'list' => $saveas_list,
	'deft' => "GreenstoneXML",
	'reqd' => "no",
	'modegli' => "3" };


my $arguments = 
    [ 
      $saveas_argument,
      { 'name' => "archivedir",
	'desc' => "{import.archivedir}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "importdir",
	'desc' => "{import.importdir}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "collectdir",
	'desc' => "{import.collectdir}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &util::filename_cat ($ENV{'GSDLHOME'}, "collect"),
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "site",
	'desc' => "{import.site}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "manifest",
	'desc' => "{import.manifest}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "debug",
	'desc' => "{import.debug}",
	'type' => "flag",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "faillog",
	'desc' => "{import.faillog}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &util::filename_cat("&lt;collectdir&gt;", "colname", "etc", "fail.log"),
	'deft' => "",
	'reqd' => "no",
        'modegli' => "3" },
      { 'name' => "incremental",
	'desc' => "{import.incremental}",
	'type' => "flag",
	'hiddengli' => "yes" },
      { 'name' => "keepold",
	'desc' => "{import.keepold}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "removeold",
	'desc' => "{import.removeold}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "maxdocs",
	'desc' => "{import.maxdocs}",
	'type' => "int",
	'reqd' => "no",
	# parsearg left "" as default
	#'deft' => "-1",
	'range' => "1,",
	'modegli' => "1" },
      # don't set the default to hash - want to allow this to come from
      # entry in collect.cfg but want to override it here 
      { 'name' => "OIDtype",
	'desc' => "{import.OIDtype}",
	'type' => "enum",
	'list' => $oidtype_list,
	# parsearg left "" as default
	#'deft' => "hash",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "OIDmetadata",
	'desc' => "{import.OIDmetadata}",
	'type' => "string",
	 #'type' => "metadata", #doesn't work properly in GLI
	# parsearg left "" as default
	#'deft' => "dc.Identifier",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "out",
	'desc' => "{import.out}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "sortmeta",
	'desc' => "{import.sortmeta}",
	'type' => "string",
	#'type' => "metadata", #doesn't work properly in GLI
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "removeprefix",
	'desc' => "{BasClas.removeprefix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no", 
	'modegli' => "3" },
      { 'name' => "removesuffix",
	'desc' => "{BasClas.removesuffix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no",
	'modegli' => "3" }, 
      { 'name' => "groupsize",
	'desc' => "{import.groupsize}",
	'type' => "int",
	'deft' => "1",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "gzip",
	'desc' => "{import.gzip}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "statsfile",
	'desc' => "{import.statsfile}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "verbosity",
	'desc' => "{import.verbosity}",
	'type' => "int",
	'range' => "0,",
	# parsearg left "" as default
	#'deft' => "2",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "gli",
	'desc' => "{scripts.gli}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
# jobs and epoch added for parallel processing
# [hs, 1 july 2010]
      { 'name' => "epoch",
	'desc' => "{import.epoch}",
	'type' => "int",
	'range' => "1,",
	'deft' => "1",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "jobs",
	'desc' => "{import.jobs}",
	'type' => "int",
	'range' => "1,",
	'deft' => "1",
	'reqd' => "no",
	'hiddengli' => "yes" }];

my $options = { 'name' => "import.pl",
		'desc' => "{import.desc}",
		'args' => $arguments };





sub main 
{
    my $inexport = new inexport("import",\@ARGV,$options);   

    my $collection = $inexport->get_collection();
    my ($config_filename,$collect_cfg) = $inexport->read_collection_cfg($collection,$options);    
    $inexport->set_collection_options($collect_cfg);
    
    my $pluginfo = $inexport->process_files($config_filename,$collect_cfg);

    $inexport->generate_statistics($pluginfo);
}

&main();
