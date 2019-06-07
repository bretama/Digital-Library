#!/usr/bin/perl -w

###########################################################################
#
# export.pl --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2004 New Zealand Digital Library Project
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


# This program will export a particular collection into a specific Format (e.g. METS or DSpace) by importing then saving as a different format.

package export;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
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
#no strict 'refs'; # allow filehandles to be variables and vice versa
#no strict 'subs'; # allow barewords (eg STDERR) as function arguments
use inexport;



# what format to export as
my $saveas_list = 
    [ { 'name' => "GreenstoneXML",
	'desc' => "{export.saveas.GreenstoneXML}"},
      { 'name' => "GreenstoneMETS",
        'desc' => "{export.saveas.GreenstoneMETS}"},
      { 'name' => "FedoraMETS",
        'desc' => "{export.saveas.FedoraMETS}"},
      { 'name' => "MARCXML",
        'desc' => "{export.saveas.MARCXML}"},
      { 'name' => "DSpace",
        'desc' => "{export.saveas.DSpace}" }
     ];


# Possible attributes for each argument
# name: The name of the argument
# desc: A description (or more likely a reference to a description) for this argument
# type: The type of control used to represent the argument. Options include: string, int, flag, regexp, metadata, language, enum etc
# reqd: Is this argument required?
# hiddengli: Is this argument hidden in GLI?
# modegli: The lowest detail mode this argument is visible at in GLI

my $saveas_argument =
      { 'name' => "saveas",
	'desc' => "{export.saveas}",
	'type' => "enum",
	'list' => $saveas_list,
	'deft' => "GreenstoneMETS",
	'reqd' => "no",
	'modegli' => "3" };


my $arguments = 
    [ 
      $saveas_argument,
      { 'name' => "saveas_options",
	'desc' => "{import.saveas_options}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "include_auxiliary_database_files",
	'desc' => "{export.include_auxiliary_database_files}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "exportdir",
	'desc' => "{export.exportdir}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "export",
        'hiddengli' => "yes" },
      @$inexport::directory_arguments,
      { 'name' => "xsltfile",
	'desc' => "{BasPlugout.xslt_file}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "listall",
	'desc' => "{export.listall}",
	'type' => "flag",
	'reqd' => "no" },
      @$inexport::arguments
      ];

my $options = { 'name' => "export.pl",
		'desc' => "{export.desc}",
		'args' => $arguments };

my $listall_options = { 'name' => "export.pl",
		        'desc' => "{export.desc}",
		        'args' => [ $saveas_argument ] };



sub main 
{
    my $inexport = new inexport("export",\@ARGV,$options,$listall_options);
    
    my $collection = $inexport->get_collection();

    if (defined $collection) {
	my ($config_filename,$collect_cfg) 
	    = $inexport->read_collection_cfg($collection,$options);    

	&set_collection_options($inexport, $collect_cfg);
    
	my $pluginfo = $inexport->process_files($config_filename,$collect_cfg);
	
	$inexport->generate_statistics($pluginfo);
    }
    
    $inexport->deinit();
}

sub set_collection_options
{
    my ($inexport, $collectcfg) = @_;

    if (defined $inexport->{'default_saveas'}) {
	# we had set the value from the arg default, not from the user
	if (defined $collectcfg->{'saveas'} 
	    && $collectcfg->{'saveas'} =~ /^(GreenstoneXML|GreenstoneMETS|FedoraMETS|MARCXML|DSPace)$/) {
	    $inexport->{'saveas'} = $collectcfg->{'saveas'};
	} else {
	    $inexport->{'saveas'} = "GreenstoneMETS"; # the default
	}
    }

    if (!defined $inexport->{'saveas_options'} || $inexport->{'saveas_options'} eq "") {
	if (defined $collectcfg->{'saveas_options'} ){
	    $inexport->{'saveas_options'} = $collectcfg->{'saveas_options'};
	}
    }

    $inexport->set_collection_options($collectcfg);
}
&main();



 
