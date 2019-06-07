#!/usr/bin/perl -w

###########################################################################
#
# buildcol.pl --
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

# This program will build a particular collection.
package buildcol;

# Environment
BEGIN
{
  die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
  die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};

  # Order is important. With unshift want our XMLParser to be 
  # found ahead of XML/XPath

  unshift (@INC, $ENV{'GSDLHOME'} . '/perllib/cpan/XML/XPath');
  unshift (@INC, $ENV{'GSDLHOME'} . '/perllib/classify');
  unshift (@INC, $ENV{'GSDLHOME'} . '/perllib/plugins');
  unshift (@INC, $ENV{'GSDLHOME'} . '/perllib/cpan');
  unshift (@INC, $ENV{'GSDLHOME'} . '/perllib');

  if (defined $ENV{'GSDL-RUN-SETUP'})
  {
    require util;
    &util::setup_greenstone_env($ENV{'GSDLHOME'}, $ENV{'GSDLOS'});
  }

  if (defined $ENV{'GSDLEXTS'})
  {
    my @extensions = split(/:/, $ENV{'GSDLEXTS'});
    foreach my $e (@extensions)
    {
      my $ext_prefix = $ENV{'GSDLHOME'} . '/ext/' . $e;

      unshift(@INC, $ext_prefix . '/perllib');
      unshift(@INC, $ext_prefix . '/perllib/cpan');
      unshift(@INC, $ext_prefix . '/perllib/plugins');
      unshift(@INC, $ext_prefix . '/perllib/classify');
    }
  }
  if (defined $ENV{'GSDL3EXTS'})
  {
    my @extensions = split(/:/, $ENV{'GSDL3EXTS'});
    foreach my $e (@extensions)
    {
      my $ext_prefix = $ENV{'GSDL3SRCHOME'} . '/ext/' . $e;

      unshift(@INC, $ext_prefix . '/perllib');
      unshift(@INC, $ext_prefix . '/perllib/cpan');
      unshift(@INC, $ext_prefix . '/perllib/plugins');
      unshift(@INC, $ext_prefix . '/perllib/classify');
    }
  }
}

# Pragma
use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

# Modules
use Symbol qw<qualify>; # Needed for runtime loading of modules [jmt12]

# Greenstone Modules
use buildcolutils;
use FileUtils;
use util;

# Globals
# - build up arguments list/control
my $mode_list =
    [ { 'name' => "all",
        'desc' => "{buildcol.mode.all}" },
      { 'name' => "compress_text",
        'desc' => "{buildcol.mode.compress_text}" },
      { 'name' => "build_index",
        'desc' => "{buildcol.mode.build_index}" },
      { 'name' => "infodb",
        'desc' => "{buildcol.mode.infodb}" },
      { 'name' => "extra",
        'desc' => "{buildcol.mode.extra}" } ];

my $sec_index_list =
    [ {'name' => "never",
       'desc' => "{buildcol.sections_index_document_metadata.never}" },
      {'name' => "always",
       'desc' => "{buildcol.sections_index_document_metadata.always}" },
      {'name' => "unless_section_metadata_exists",
       'desc' => "{buildcol.sections_index_document_metadata.unless_section_metadata_exists}" }
      ];

my $arguments =
    [ { 'name' => "remove_empty_classifications",
	'desc' => "{buildcol.remove_empty_classifications}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "archivedir",
	'desc' => "{buildcol.archivedir}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "builddir",
	'desc' => "{buildcol.builddir}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
#     { 'name' => "cachedir",
#	'desc' => "{buildcol.cachedir}",
#	'type' => "string",
#	'reqd' => "no" },
      { 'name' => "collectdir",
	'desc' => "{buildcol.collectdir}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect"),
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "site",
	'desc' => "{buildcol.site}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "debug",
	'desc' => "{buildcol.debug}",
	'type' => "flag",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "faillog",
	'desc' => "{buildcol.faillog}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate("<collectdir>", "colname", "etc", "fail.log"),
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "index",
	'desc' => "{buildcol.index}",
	'type' => "string",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "incremental",
	'desc' => "{buildcol.incremental}",
	'type' => "flag",
	'hiddengli' => "yes" },
      { 'name' => "keepold",
	'desc' => "{buildcol.keepold}",
	'type' => "flag",
	'reqd' => "no",
        #'modegli' => "3",
	'hiddengli' => "yes" },
      { 'name' => "removeold",
	'desc' => "{buildcol.removeold}",
	'type' => "flag",
	'reqd' => "no",
	#'modegli' => "3",
	'hiddengli' => "yes"  },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "maxdocs",
	'desc' => "{buildcol.maxdocs}",
	'type' => "int",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "maxnumeric",
	'desc' => "{buildcol.maxnumeric}",
	'type' => "int",
	'reqd' => "no",
	'deft' => "4",
	'range' => "4,512",
	'modegli' => "3" },
      { 'name' => "mode",
	'desc' => "{buildcol.mode}",
	'type' => "enum",
	'list' => $mode_list,
	# parsearg left "" as default
#	'deft' => "all",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "no_strip_html",
	'desc' => "{buildcol.no_strip_html}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "store_metadata_coverage",
	'desc' => "{buildcol.store_metadata_coverage}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "no_text",
	'desc' => "{buildcol.no_text}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "sections_index_document_metadata",
	'desc' => "{buildcol.sections_index_document_metadata}",
	'type' => "enum",
	'list' => $sec_index_list,
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "sections_sort_on_document_metadata",
	'desc' => "{buildcol.sections_sort_on_document_metadata}",
	'type' => "enum",
	'list' => $sec_index_list,
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "out",
	'desc' => "{buildcol.out}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "verbosity",
	'desc' => "{buildcol.verbosity}",
	'type' => "int",
	# parsearg left "" as default
	#'deft' => "2",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "gli",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "activate",
	'desc' => "{buildcol.activate}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "skipactivation",
	'desc' => "{buildcol.skipactivation}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "library_url",
	'desc' => "{buildcol.library_url}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "library_name",
	'desc' => "{buildcol.library_name}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "indexname",
	'desc' => "{buildcol.index}",
	'type' => "string",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "indexlevel",
	'desc' => "{buildcol.indexlevel}",
	'type' => "string",
	'reqd' => "no",
	'modegli' => "3" },
      ];

my $options = { 'name' => "buildcol.pl",
		'desc' => "{buildcol.desc}",
		'args' => $arguments };

# The hash maps between argument and the buildcolutils subclass supporting that
# argument - allowing for extensions to override the normal buildcolutils as
# necessary
my $function_to_subclass_mappings = {};

# Lets get the party rolling... or ball started... hmmm
&main();

exit;

sub main
{
  # Dynamically include arguments from any subclasses of buildcolutils we find
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
  # subclass of buildcolutils. Note that we load the first subclass we
  # encounter so only support a single 'override' ATM.
  my $subclass;
  foreach my $argument (@ARGV)
  {
    # proper arguments start with a hyphen
    if ($argument =~ /^-/ && defined $function_to_subclass_mappings->{$argument})
    {
      my $required_subclass = $function_to_subclass_mappings->{$argument};
      if (!defined $subclass)
      {
        $subclass = $required_subclass;
      }
      # Oh noes! The user has included specific arguments from two different
      # subclasses... this isn't supported
      elsif ($subclass ne $required_subclass)
      {
        print STDERR "Error! You cannot specify arguments from two different extension specific buildcolutils modules: " . $subclass . " != " . $required_subclass . "\n";
        exit;
      }
    }
  }

  my $buildcolutils;
  if (defined $subclass)
  {
    print "* Loading overriding buildcolutils module: " . $subclass . "\n";
    require $subclass . '.pm';
    $buildcolutils = new $subclass(\@ARGV, $options);
  }
  # We don't have an overridden buildcolutils, or the above command failed
  # somehow so load the base class
  if (!defined $buildcolutils)
  {
    $buildcolutils = new buildcolutils(\@ARGV, $options);
  }

  my $collection = $buildcolutils->get_collection();
  if (defined $collection)
  {
    my ($config_filename,$collect_cfg) = $buildcolutils->read_collection_cfg($collection, $options);
    $buildcolutils->set_collection_options($collect_cfg);

    my $builders_ref = $buildcolutils->prepare_builders($config_filename, $collect_cfg);
    $buildcolutils->build_collection($builders_ref);
    $buildcolutils->build_auxiliary_files($builders_ref);
    $buildcolutils->complete_builders($builders_ref);

    # The user may have requested the collection be activated
    $buildcolutils->activate_collection();
  }

  # Cleanup
  $buildcolutils->deinit();
}
# main()

# @function _scanForSubclasses()
# @param $dir The extension directory to look within
# @param $exts A list of the available extensions (as a colon separated string)
# @return The number of subclasses of buildcolutils found as an Integer
sub _scanForSubclasses
{
  my ($dir, $exts) = @_;
  my $class_count = 0;
  my $ext_prefix = &FileUtils::filenameConcatenate($dir, "ext");
  my @extensions = split(/:/, $exts);
  foreach my $e (@extensions)
  {
    # - any subclass must be prefixed with the name of the ext
    my $package_name = $e . 'buildcolutils';
    $package_name =~ s/[^a-z]//gi; # package names have limited characters
    my $file_name = $package_name . '.pm';
    my $file_path = &FileUtils::filenameConcatenate($ext_prefix, $e, 'perllib', $file_name);
    # see if we have a subclass lurking in that extension folder
    if (&FileUtils::fileExists($file_path))
    {
      # - note we load the filename (with pm) unlike normal modules
      require $file_name;
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
          # - record a mapping from each extra arguments to the subclass
          #   that supports it. We put the hyphen on here to make comparing
          #   with command line arguments even easier
          $function_to_subclass_mappings->{'-' . $argument->{'name'}} = $package_name;
          # - and them add them as acceptable arguments to import.pl
          push(@{$options->{'args'}}, $argument);
        }
        $class_count++;
      }
      else
      {
        print "Warning! A subclass of buildcolutils module (named '" . $file_name . "') does not implement the required getSupportedArguments() function - ignoring. Found in: " . $file_path . "\n";
      }
    }
  }
  return $class_count;
}
# _scanForSubclasses()
