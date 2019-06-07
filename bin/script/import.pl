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

package import;

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

    if ((defined $ENV{'DEBUG_UNICODE'}) && (defined $ENV{'DEBUG_UNICODE'})) {
	binmode(STDERR,":utf8");
    }
}

# Pragma
use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments
use warnings;

# Modules
use Symbol qw<qualify>; # Needed for runtime loading of modules [jmt12]

# Greenstone Modules
use FileUtils;
use inexport;
use util;
use gsprintf 'gsprintf';


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
      { 'name' => "saveas_options",
	'desc' => "{import.saveas_options}",
	'type' => "string",
	'reqd' => "no" },
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
      { 'name' => "archivedir",
	'desc' => "{import.archivedir}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "archives",
        'hiddengli' => "yes" },
      @$inexport::directory_arguments,
      { 'name' => "gzip",
	'desc' => "{import.gzip}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3" },
     @$inexport::arguments,
      { 'name' => "NO_IMPORT",
	'desc' => "{import.NO_IMPORT}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3"}
];

my $options = { 'name' => "import.pl",
		'desc' => "{import.desc}",
		'args' => $arguments };

my $function_to_inexport_subclass_mappings = {};

sub main
{
  # Dynamically include arguments from any subclasses of inexport we find
  # in the extensions directory
  if (defined $ENV{'GSDLEXTS'})
  {
    &_scanForSubclasses($ENV{'GSDLHOME'}, $ENV{'GSDLEXTS'});
  }
  if (defined $ENV{'GSDL3EXTS'})
  {
    &_scanForSubclasses($ENV{'GSDL3SRCHOME'}, $ENV{'GSDL3EXTS'});
  }

  # Loop through arguments, checking to see if any depend on a specific
  # subclass of InExport. Note that we load the first subclass we encounter
  # so only support a single 'override' ATM.
  my $inexport_subclass;
  foreach my $argument (@ARGV)
  {
      if ($argument eq "-NO_IMPORT") {
	  &gsprintf(STDERR, "{import.NO_IMPORT_set}\n\n");	
	  exit 0;
      }
    # proper arguments start with a hyphen
    if ($argument =~ /^-/ && defined $function_to_inexport_subclass_mappings->{$argument})
    {
      my $required_inexport_subclass = $function_to_inexport_subclass_mappings->{$argument};
      if (!defined $inexport_subclass)
      {
        $inexport_subclass = $required_inexport_subclass;
      }
      # Oh noes! The user has included specific arguments from two different
      # inexport subclasses... this isn't supported
      elsif ($inexport_subclass ne $required_inexport_subclass)
      {
        print STDERR "Error! You cannot specify arguments from two different extention specific inexport modules: " . $inexport_subclass . " != " . $required_inexport_subclass . "\n";
        exit;
      }
    }
  }
 
  my $inexport;
  if (defined $inexport_subclass)
  {
    print "* Loading Overriding InExport Module: " . $inexport_subclass . "\n";
    require $inexport_subclass . '.pm';
    $inexport = new $inexport_subclass("import",\@ARGV,$options);
  }
 
  # We don't have a overridden inexport, or the above command failed somehow
  # so load the base inexport class
  if (!defined $inexport)
  {
    $inexport = new inexport("import",\@ARGV,$options);
  }

  my $collection = $inexport->get_collection();
  
  if (defined $collection)
  {
    my ($config_filename,$collect_cfg) = $inexport->read_collection_cfg($collection,$options);
    if ($collect_cfg->{'NO_IMPORT'}) {
	&gsprintf(STDERR, "{import.NO_IMPORT_set}\n\n");	
	exit 0;
    }
    #$inexport->set_collection_options($collect_cfg);
    &set_collection_options($inexport, $collect_cfg);

    
    my $pluginfo = $inexport->process_files($config_filename,$collect_cfg);

    $inexport->generate_statistics($pluginfo);
  } 

  $inexport->deinit();
}
# main()

# @function _scanForSubclasses()
# @param $dir The extension directory to look within
# @param $exts A list of the available extensions (as a colon separated string)
# @return The number of subclasses of InExport found as an Integer
sub _scanForSubclasses
{
  my ($dir, $exts) = @_;
  my $inexport_class_count = 0;
  my $ext_prefix = &FileUtils::filenameConcatenate($dir, "ext");
  my @extensions = split(/:/, $exts);
  foreach my $e (@extensions)
  {
    # - any subclass of InExport must be prefixed with the name of the ext
    my $package_name = $e . 'inexport';
    $package_name =~ s/[^a-z]//gi; # package names have limited characters
    my $inexport_filename = $package_name . '.pm';
    my $inexport_path = &FileUtils::filenameConcatenate($ext_prefix, $e, 'perllib', $inexport_filename);
    # see if we have a subclass of InExport lurking in that extension folder
    if (-f $inexport_path)
    {
      # - note we load the filename (with pm) unlike normal modules
      require $inexport_filename;
      # - make call to the newly created package
      my $symbol = qualify('getSupportedArguments', $package_name);
      # - strict prevents strings being used as function calls, so temporarily
      #   disable that pragma
      no strict;
      # - lets check that the function we are about to call actually exists
      if ( defined &{$symbol} )
      {
        my $extra_arguments = &{$symbol}();
        foreach my $argument (@{$extra_arguments})
        {
          # - record a mapping from each extra arguments to the inexport class
          #   that supports it. We put the hyphen on here to make comparing
          #   with command line arguments even easier
          $function_to_inexport_subclass_mappings->{'-' . $argument->{'name'}} = $package_name;
          # - and them add them as acceptable arguments to import.pl
          push(@{$options->{'args'}}, $argument);
        }
        $inexport_class_count++;
      }
      else
      {
        print "Warning! A subclass of InExport module (named '" . $inexport_filename . "') does not implement the required getSupportedArguments() function - ignoring. Found in: " . $inexport_path . "\n";
      }
    }
  }
  return $inexport_class_count;
}
# _scanForInExportModules()

# look up collect.cfg for import options, then all inexport version for the 
# common ones
sub set_collection_options
{

    my ($inexport, $collectcfg) = @_;
    my $out        = $inexport->{'out'};

    # check all options for default_optname - this will be set if the parsing
    # code has just set the value based on the arg default. In this case,
    # check in collect.cfg for the option
    
    # groupsize can only be defined for import, not export, and actually only
    # applies to GreenstoneXML format.
    if (defined $inexport->{'default_groupsize'}) {
	if (defined $collectcfg->{'groupsize'} && $collectcfg->{'groupsize'} =~ /\d+/) {
	    $inexport->{'groupsize'} = $collectcfg->{'groupsize'};
	}

    }
    if (defined $inexport->{'default_saveas'}) {
	if (defined $collectcfg->{'saveas'} 
	    && $collectcfg->{'saveas'} =~ /^(GreenstoneXML|GreenstoneMETS)$/) {
	    $inexport->{'saveas'} = $collectcfg->{'saveas'};
	} else {
	    $inexport->{'saveas'} = "GreenstoneXML"; # the default
	}
    }
    if (!defined $inexport->{'saveas_options'} || $inexport->{'saveas_options'} eq "") {
	if (defined $collectcfg->{'saveas_options'} ){
	    $inexport->{'saveas_options'} = $collectcfg->{'saveas_options'};
	}
    }
    
    my $sortmeta = $inexport->{'sortmeta'};
    if (defined $collectcfg->{'sortmeta'} && $sortmeta eq "") {
	$sortmeta = $collectcfg->{'sortmeta'};
    }
    # sortmeta cannot be used with group size
    $sortmeta = undef unless defined $sortmeta && $sortmeta =~ /\S/;
    if (defined $sortmeta && $inexport->{'groupsize'} > 1) {
	&gsprintf($out, "{import.cannot_sort}\n\n");
	$sortmeta = undef;
    }
    if (defined $sortmeta) {
	&gsprintf($out, "{import.sortmeta_paired_with_ArchivesInfPlugin}\n\n");	
    }
    $inexport->{'sortmeta'} = $sortmeta;

    if (defined $collectcfg->{'removeprefix'} && $inexport->{'removeprefix'} eq "") {
	$inexport->{'removeprefix'} = $collectcfg->{'removeprefix'};
    }
    
    if (defined $collectcfg->{'removesuffix'} && $inexport->{'removesuffix'} eq "") {
	$inexport->{'removesuffix'} = $collectcfg->{'removesuffix'};
    }

    $inexport->set_collection_options($collectcfg);
 
}
&main();
