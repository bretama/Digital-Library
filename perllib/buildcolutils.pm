##############################################################################
#
# buildcolutils.pm -- index and build the collection. The buildtime counterpart
#                    of inexport.pl
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
###############################################################################

package buildcolutils;

#use strict; 
#no strict 'refs';

use File::Basename;

use colcfg;
use dbutil;
use util;
use FileUtils;
use scriptutil;
use servercontrol;
use gsprintf;
use printusage;
use parse2;

## @method new()
#
#  Parses up and validates the arguments to the build process before creating
#  the appropriate build process to do the actual work
#
#  @note Added true incremental support - John Thompson, DL Consulting Ltd.
#  @note There were several bugs regarding using directories other than
#        "import" or "archives" during import and build quashed. - John
#        Thompson, DL Consulting Ltd.
#
#  @param  $incremental If true indicates this build should not regenerate all
#                       the index and metadata files, and should instead just
#                       append the information found in the archives directory
#                       to the existing files. If this requires some complex
#                       work so as to correctly insert into a classifier so be
#                       it. Of course none of this is done here - instead the
#                       incremental argument is passed to the document
#                       processor.
#
sub new
{
  my $class = shift(@_);
  my ($argv, $options, $opt_listall_options) = @_;

  my $self = {'builddir' => undef,
              'buildtype' => undef,
              'close_faillog' => 0,
              'close_out' => 0,
              'mode' => '',
              'orthogonalbuildtypes' => undef,
              'realbuilddir' => undef,
              'textindex' => '',
              'xml' => 0
             };

  # general options available to all plugins
  my $arguments = $options->{'args'};
  my $intArgLeftinAfterParsing = &parse2::parse($argv, $arguments, $self, "allow_extra_options");
  # If parse returns -1 then something has gone wrong
  if ($intArgLeftinAfterParsing == -1)
  {
    &PrintUsage::print_txt_usage($options, "{buildcol.params}",1);
    print STDERR "Something went wrong during parsing the arguments. Scroll up for details.\n";
    die "\n";
  }

  # If $language has been specified, load the appropriate resource bundle
  # (Otherwise, the default resource bundle will be loaded automatically)
  if ($self->{'language'} && $self->{'language'} =~ /\S/)
  {
    &gsprintf::load_language_specific_resource_bundle($self->{'language'});
  }

  # Do we need 'listall' support in buildcol? If so, copy code from inexport
  # later [jmt12]

  # <insert explanation here>
  if ($self->{'xml'})
  {
    &PrintUsage::print_xml_usage($options);
    print "\n";
    return bless($self, $class);
  }

  # the gli wants strings to be in UTF-8
  if ($gli)
  {
    &gsprintf::output_strings_in_UTF8;
  }
  
  # If the user specified -h, then we output the usage
  if (@$argv && $argv->[0] =~ /^\-+h/) {
      &PrintUsage::print_txt_usage($options, "{buildcol.params}");
      die "\n";
  }
  
  # now check that we had exactly one leftover arg, which should be
  # the collection name. We don't want to do this earlier, cos
  # -xml arg doesn't need a collection name
  if ($intArgLeftinAfterParsing != 1)
  {
    &PrintUsage::print_txt_usage($options, "{buildcol.params}", 1);
    print STDERR "There should be one argument left after parsing the script args: the collection name.\n";
    die "\n";
  }

  my $out = $self->{'out'};
  if ($out !~ /^(STDERR|STDOUT)$/i)
  {
    open (OUT, ">$out") || (&gsprintf::gsprintf(STDERR, "{common.cannot_open_output_file}\n", $out) && die);
    $out = "buildcolutils::OUT";
    $self->{'close_out'} = 1;
  }
  $out->autoflush(1);
  $self->{'out'} = $out;

  # @ARGV should be only one item, the name of the collection
  $self->{'collection'} = shift(@{$argv});

  return bless($self, $class);
}
# new()

# newCGI()?

# @function get_collection
#
sub get_collection
{
  my $self = shift @_;
  return $self->{'collection'};
}
# get_collection()

# @function read_collection_cfg
#
sub read_collection_cfg
{
  my $self = shift(@_);
  my ($collection, $options) = @_;

  my $collectdir = $self->{'collectdir'};
  my $site       = $self->{'site'};
  my $out        = $self->{'out'};

  # get and check the collection
  if (($collection = &colcfg::use_collection($site, $collection, $collectdir)) eq "")
  {
    #&PrintUsage::print_txt_usage($options, "{buildcol.params}", 1);
    die "\n";
  }

  # set gs_version 2/3
  $self->{'gs_version'} = "2";
  if ((defined $site) && ($site ne ""))
  {
    # gs3
    $self->{'gs_version'} = "3";
  }

  # add collection's perllib dir into include path in case we have collection
  # specific modules
  &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib'));
  &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib', 'classify'));
  &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib', 'plugins'));

  # check that we can open the faillog
  my $faillog = $self->{'faillog'};
  if ($faillog eq "")
  {
    $faillog = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "etc", "fail.log");
  }
  # note that we're appending to the faillog here (import.pl clears it each time)
  # this could potentially create a situation where the faillog keeps being added
  # to over multiple builds (if the import process is being skipped)
  open (FAILLOG, ">>$faillog") || (&gsprintf::gsprintf(STDERR, "{common.cannot_open_fail_log}\n", $faillog) && die);
  $faillog = 'buildcolutils::FAILLOG';
  $faillog->autoflush(1);
  $self->{'faillog'} = $faillog;
  $self->{'faillogname'} = $faillog;
  $self->{'close_faillog'} = 1;

  # Read in the collection configuration file.
  my $gs_mode = "gs".$self->{'gs_version'}; #gs2 or gs3
  my $config_filename = &colcfg::get_collect_cfg_name($out, $gs_mode);
  my $collect_cfg = &colcfg::read_collection_cfg($config_filename, $gs_mode);

  return ($config_filename, $collect_cfg);
}
# read_collection_cfg()

# @function set_collection_options
# This function copies across values for arguments from the collection
# configuration file if they are not already provided by the user, then
# sets reasonable defaults for any required arguments that remains without
# a value.
sub set_collection_options
{
  my $self = shift @_;
  my ($collectcfg) = @_;
  my ($buildtype, $orthogonalbuildtypes);

  # If the infodbtype value wasn't defined in the collect.cfg file, use the default
  if (!defined($collectcfg->{'infodbtype'}))
  {
    $collectcfg->{'infodbtype'} = &dbutil::get_default_infodb_type();
  }
  # - just so I don't have to pass collectcfg around as well
  $self->{'infodbtype'} = $collectcfg->{'infodbtype'};

  if ($self->{'verbosity'} !~ /\d+/)
  {
    if (defined $collectcfg->{'verbosity'} && $collectcfg->{'verbosity'} =~ /\d+/)
    {
      $self->{'verbosity'} = $collectcfg->{'verbosity'};
    }
    else
    {
      $self->{'verbosity'} = 2; # the default
    }
  }

  # we use searchtype for determining buildtype, but for old versions, use buildtype
  if (defined $collectcfg->{'buildtype'})
  {
    $self->{'buildtype'} = $collectcfg->{'buildtype'};
  }
  elsif (defined $collectcfg->{'searchtypes'} || defined $collectcfg->{'searchtype'})
  {
    $self->{'buildtype'} = "mgpp";
  }
  else
  {
    $self->{'buildtype'} = "mg"; #mg is the default
  }

  if ($self->{'buildtype'} eq "mgpp" && defined $collectcfg->{'textcompress'})
  {
    $self->{'textindex'} = $collectcfg->{'textcompress'};
  }

  # is it okay to always clobber or possible remain undefined? [jmt12]
  if (defined $collectcfg->{'orthogonalbuildtypes'})
  {
    $self->{'orthogonalbuildtypes'} = $collectcfg->{'orthogonalbuildtypes'};
  }

  # - resolve (and possibly set to default) builddir
  if (defined $collectcfg->{'archivedir'} && $self->{'archivedir'} eq "")
  {
    $self->{'archivedir'} = $collectcfg->{'archivedir'};
  }
  # Modified so that the archivedir, if provided as an argument, is made
  # absolute if it isn't already
  if ($self->{'archivedir'} eq "")
  {
    $self->{'archivedir'} = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "archives");
  }
  else
  {
    $self->{'archivedir'} = &util::make_absolute($ENV{'GSDLCOLLECTDIR'}, $self->{'archivedir'});
  }
  # End Mod
  $self->{'archivedir'} = &FileUtils::sanitizePath($self->{'archivedir'});
  #$self->{'archivedir'} =~ s/[\\\/]+/\//g;
  #$self->{'archivedir'} =~ s/\/$//;

  # - resolve (and possibly set to default) builddir
  if (defined $collectcfg->{'builddir'} && $self->{'builddir'} eq "")
  {
    $self->{'builddir'} = $collectcfg->{'builddir'};
  }
  if ($self->{'builddir'} eq "")
  {
    $self->{'builddir'} = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'building');
    if ($incremental)
    {
      &gsprintf::gsprintf($out, "{buildcol.incremental_default_builddir}\n");
    }
  } else {
      # make absolute if not already
      $self->{'builddir'} = &util::make_absolute($ENV{'GSDLCOLLECTDIR'}, $self->{'builddir'});
  }
  
  $self->{'builddir'} = &FileUtils::sanitizePath($self->{'builddir'});
  #$self->{'builddir'} =~ s/[\\\/]+/\//g;
  #$self->{'builddir'} =~ s/\/$//;

  if (defined $collectcfg->{'cachedir'} && $self->{'cachedir'} eq "")
  {
    $self->{'cachedir'} = $collectcfg->{'cachedir'};
  }

  if ($self->{'maxdocs'} !~ /\-?\d+/)
  {
    if (defined $collectcfg->{'maxdocs'} && $collectcfg->{'maxdocs'} =~ /\-?\d+/)
    {
      $self->{'maxdocs'} = $collectcfg->{'maxdocs'};
    }
    else
    {
      $self->{'maxdocs'} = -1; # the default
    }
  }

  # always clobbers? [jmt12]
  if (defined $collectcfg->{'maxnumeric'} && $collectcfg->{'maxnumeric'} =~ /\d+/)
  {
    $self->{'maxnumeric'} = $collectcfg->{'maxnumeric'};
  }
  if ($self->{'maxnumeric'} < 4 || $self->{'maxnumeric'} > 512)
  {
    $self->{'maxnumeric'} = 4;
  }

  if (defined $collectcfg->{'debug'} && $collectcfg->{'debug'} =~ /^true$/i)
  {
    $self->{'debug'} = 1;
  }

  if ($self->{'mode'} !~ /^(all|compress_text|build_index|infodb|extra)$/)
  {
    if (defined $collectcfg->{'mode'} && $collectcfg->{'mode'} =~ /^(all|compress_text|build_index|infodb|extra)$/)
    {
      $self->{'mode'} = $collectcfg->{'mode'};
    }
    else
    {
      $self->{'mode'} = "all"; # the default
    }
  }

  # Presumably 'index' from the collect.cfg still works [jmt12]
  if (defined $collectcfg->{'index'} && $self->{'indexname'} eq "")
  {
    $self->{'indexname'} = $collectcfg->{'index'};
  }
  # - 'index' from the command line doesn't make it through parsing so I
  # renamed this option 'indexname' [jmt12]
  if (defined $collectcfg->{'indexname'} && $self->{'indexname'} eq "")
  {
    $self->{'indexname'} = $collectcfg->{'indexname'};
  }
  # - we may also define the index level to build now [jmt12]
  if (defined $collectcfg->{'indexlevel'} && $self->{'indexlevel'} eq "")
  {
    $self->{'indexlevel'} = $collectcfg->{'indexlevel'};
  }

  if (defined $collectcfg->{'no_text'} && $self->{'no_text'} == 0)
  {
    if ($collectcfg->{'no_text'} =~ /^true$/i)
    {
      $self->{'no_text'} = 1;
    }
  }

  if (defined $collectcfg->{'no_strip_html'} && $self->{'no_strip_html'} == 0)
  {
    if ($collectcfg->{'no_strip_html'} =~ /^true$/i)
    {
      $self->{'no_strip_html'} = 1;
    }
  }

  if (defined $collectcfg->{'store_metadata_coverage'} && $self->{'store_metadata_coverage'} == 0)
  {
    if ($collectcfg->{'store_metadata_coverage'} =~ /^true$/i)
    {
      $self->{'store_metadata_coverage'} = 1;
    }
  }

  if (defined $collectcfg->{'remove_empty_classifications'} && $self->{'remove_empty_classifications'} == 0)
  {
    if ($collectcfg->{'remove_empty_classifications'} =~ /^true$/i)
    {
      $self->{'remove_empty_classifications'} = 1;
    }
  }

  if (defined $collectcfg->{'gli'} && $collectcfg->{'gli'} =~ /^true$/i)
  {
    $self->{'gli'} = 1;
  }
  if (!defined $self->{'gli'})
  {
    $self->{'gli'} = 0;
  }

  if ($self->{'sections_index_document_metadata'} !~ /\S/ && defined $collectcfg->{'sections_index_document_metadata'})
  {
    $self->{'sections_index_document_metadata'} = $collectcfg->{'sections_index_document_metadata'};
  }

  if ($self->{'sections_index_document_metadata'} !~ /^(never|always|unless_section_metadata_exists)$/) {
    $self->{'sections_index_document_metadata'} = 'never';
  }

  if ($self->{'sections_sort_on_document_metadata'} !~ /\S/ && defined $collectcfg->{'sections_sort_on_document_metadata'})
  {
    $self->{'sections_sort_on_document_metadata'} = $collectcfg->{'sections_sort_on_document_metadata'};
  }

  if ($self->{'sections_sort_on_document_metadata'} !~ /^(never|always|unless_section_metadata_exists)$/) {
    $self->{'sections_sort_on_document_metadata'} = 'never';
  }

  my ($removeold, $keepold, $incremental, $incremental_mode)
      = &scriptutil::check_removeold_and_keepold($self->{'removeold'}, $self->{'keepold'},
                                                 $self->{'incremental'}, 'building',
                                                 $collectcfg);
  $self->{'removeold'}        = $removeold;
  $self->{'keepold'}          = $keepold;
  $self->{'incremental'}      = $incremental;
  $self->{'incremental_mode'} = $incremental_mode;

  # New argument to track whether build is incremental
  if (!defined $self->{'incremental'})
  {
    $self->{'incremental'} = 0;
  }

  #set the text index
  if (($self->{'buildtype'} eq 'mgpp') || ($self->{'buildtype'} eq 'lucene') || ($self->{'buildtype'} eq 'solr'))
  {
    if ($self->{'textindex'} eq '')
    {
      $self->{'textindex'} = 'text';
    }
  }
  else
  {
    $self->{'textindex'} = 'section:text';
  }
}
# set_collection_options()

# @function prepare_builders
#
sub prepare_builders
{
  my $self = shift @_;
  my ($config_filename,$collectcfg) = @_;

  my $archivedir  = $self->{'archivedir'};
  my $builddir    = $self->{'builddir'};
  my $buildtype   = $self->{'buildtype'};
  my $cachedir    = $self->{'cachedir'};
  my $collectdir  = $self->{'collectdir'};
  my $collection  = $self->{'collection'};
  my $debug       = $self->{'debug'};
  my $faillog     = $self->{'faillog'};
  my $gli         = $self->{'gli'};
  my $incremental = $self->{'incremental'};
  my $incremental_mode = $self->{'incremental_mode'};
  my $keepold     = $self->{'keepold'};
  my $maxdocs     = $self->{'maxdocs'};
  my $maxnumeric  = $self->{'maxnumeric'};
  my $no_strip_html = $self->{'no_strip_html'};
  my $no_text     = $self->{'no_text'};
  my $orthogonalbuildtypes = $self->{'orthogonalbuildtypes'};
  my $out         = $self->{'out'};
  my $remove_empty_classifications = $self->{'remove_empty_classifications'};
  my $sections_index_document_metadata = $self->{'sections_index_document_metadata'};
  my $sections_sort_on_document_metadata = $self->{'sections_sort_on_document_metadata'};
  my $site        = $self->{'site'};
  my $store_metadata_coverage = $self->{'store_metadata_coverage'};
  my $verbosity   = $self->{'verbosity'};

  if ($gli)
  {
    print STDERR "<Build>\n";
  }

  # fill in the default archives and building directories if none
  # were supplied, turn all \ into / and remove trailing /

  my ($realarchivedir, $realbuilddir);
  # update the archive cache if needed
  if ($cachedir)
  {
    if ($verbosity >= 1)
    {
      &gsprintf::gsprintf($out, "{buildcol.updating_archive_cache}\n")
    }

    $cachedir =~ s/[\\\/]+$//;
    if ($cachedir !~ /collect[\/\\]$collection/)
    {
      $cachedir = &FileUtils::filenameConcatenate($cachedir, 'collect', $collection);
    }

    $realarchivedir = &FileUtils::filenameConcatenate($cachedir, 'archives');
    $realbuilddir = &FileUtils::filenameConcatenate($cachedir, 'building');
    &FileUtils::makeAllDirectories($realarchivedir);
    &FileUtils::makeAllDirectories($realbuilddir);
    &FileUtils::synchronizeDirectory($archivedir, $realarchivedir, $verbosity);
  }
  else
  {
    $realarchivedir = $archivedir;
    $realbuilddir = $builddir;
  }
  $self->{'realarchivedir'} = $realarchivedir;
  $self->{'realbuilddir'} = $realbuilddir;

  # build it in realbuilddir
  &FileUtils::makeAllDirectories($realbuilddir);

  my ($buildertype, $builderdir,  $builder);
  # if a builder class has been created for this collection, use it
  # otherwise, use the mg or mgpp builder
  if (-e "$ENV{'GSDLCOLLECTDIR'}/custom/${collection}/perllib/custombuilder.pm")
  {
    $builderdir = "$ENV{'GSDLCOLLECTDIR'}/custom/${collection}/perllib";
    $buildertype = "custombuilder";
  }
  elsif (-e "$ENV{'GSDLCOLLECTDIR'}/perllib/custombuilder.pm")
  {
    $builderdir = "$ENV{'GSDLCOLLECTDIR'}/perllib";
    $buildertype = "custombuilder";
  }
  elsif (-e "$ENV{'GSDLCOLLECTDIR'}/perllib/${collection}builder.pm")
  {
    $builderdir = "$ENV{'GSDLCOLLECTDIR'}/perllib";
    $buildertype = $collection . 'builder';
  }
  else
  {
    $builderdir = undef;
    if ($buildtype ne '')
    {
      # caters for extension-based build types, such as 'solr'
      $buildertype = $buildtype . 'builder';
    }
    else
    {
      # Default to mgpp
      $buildertype = 'mgppbuilder';
    }
  }
  # check for extension specific builders
  # (that will then be run after main builder.pm
  my @builderdir_list = ($builderdir);
  my @buildertype_list = ($buildertype);

  my $mode = $self->{'mode'};

  if ($mode eq "extra") {
      # knock out the main builder type, by reseting the lists to be empty
      @builderdir_list = ();
      @buildertype_list = ();
  }

  if (defined $orthogonalbuildtypes)
  {
    foreach my $obt (@$orthogonalbuildtypes)
    {
      push(@builderdir_list,undef); # rely on @INC to find it
      push(@buildertype_list,$obt."Builder");
    }
  }

  # Set up array of the main builder.pm, followed by any ones
  # from the extension folders

  my $num_builders = scalar(@buildertype_list);
  my @builders = ();

  for (my $i=0; $i<$num_builders; $i++)
  {
    my $this_builder;
    my $this_buildertype = $buildertype_list[$i];
    my $this_builderdir  = $builderdir_list[$i];

    if ((defined $this_builderdir) && ($this_builderdir ne ""))
    {
      require "$this_builderdir/$this_buildertype.pm";
    }
    else
    {
      require "$this_buildertype.pm";
    }

    eval("\$this_builder = new $this_buildertype(\$site, \$collection, " .
         "\$realarchivedir, \$realbuilddir, \$verbosity, " .
         "\$maxdocs, \$debug, \$keepold, \$incremental, \$incremental_mode, " .
         "\$remove_empty_classifications, " .
         "\$out, \$no_text, \$faillog, \$gli)");
    die "$@" if $@;

    push(@builders,$this_builder);
  }

  # Init phase for builders
  for (my $i=0; $i<$num_builders; $i++)
  {
    my $this_buildertype = $buildertype_list[$i];
    my $this_builderdir  = $builderdir_list[$i];
    my $this_builder     = $builders[$i];

    $this_builder->init();
    $this_builder->set_maxnumeric($maxnumeric);

    if (($this_buildertype eq "mgppbuilder") && $no_strip_html)
    {
      $this_builder->set_strip_html(0);
    }

    if ($sections_index_document_metadata ne "never")
    {
      $this_builder->set_sections_index_document_metadata($sections_index_document_metadata);
    }
    if (($this_buildertype eq "lucenebuilder" || $this_buildertype eq "solrbuilder") && $sections_sort_on_document_metadata ne "never")
    {
      $this_builder->set_sections_sort_on_document_metadata($sections_sort_on_document_metadata);
    }

    if ($store_metadata_coverage)
    {
      $this_builder->set_store_metadata_coverage(1);
    }
  }
  return \@builders;
}

sub build_collection
{
  my $self = shift(@_);
  my @builders = @{shift(@_)};

  my $indexlevel  = $self->{'indexlevel'};
  my $indexname   = $self->{'indexname'};
  my $mode        = $self->{'mode'};
  my $textindex   = $self->{'textindex'};

  # Run the requested passes
  if ($mode =~ /^(all|extra)$/i)
  {
    # 'map' modifies the elements of the original array, so calling
    # methods -- as done below -- will cause (by default) @builders
    # to be changed to whatever these functions return (which is *not*
    # what we want -- we want to leave the values unchanged)
    # => Use 'local' (dynamic scoping) to give each 'map' call its
    #    own local copy This could also be done with:
    #      (my $new =$_)->method(); $new
    #    but is a bit more cumbersome to write
    map { local $_=$_; $_->compress_text($textindex); } @builders;
    # - we pass the required indexname and indexlevel (if specified) to the
    #   processor [jmt12]
    map { local $_=$_; $_->build_indexes($indexname, $indexlevel); } @builders;

    # If incremental, need to deactivate the collection for collections whose db don't support concurrent R+W
    # All except the collection (1st parameter) can be empty. For GS3, also set the site parameter
    my $gsserver = new servercontrol( $self->get_collection(), $self->{'site'}, $self->{'verbosity'}, $self->{'builddir'}, $self->{'indexdir'}, $self->{'collectdir'}, $self->{'library_url'}, $self->{'library_name'});

    # when *incrementally* rebuilding a collection using any db that *doesn't* support concurrent
    # read and write (e.g. gdbm), need to deactivate the collection before make_infodatabase()    
    map { 
	local $_=$_; 

	if($_->supports_make_infodatabase()) {
	    my $infodbtype = $_->{'infodbtype'};
	    my $dbSupportsConcurrentRW = &dbutil::supportsConcurrentReadAndWrite($infodbtype);
	
	    if(!$dbSupportsConcurrentRW && $self->{'incremental'}) {
		$gsserver->print_task_msg("About to deactivate collection ".$self->get_collection());
		$gsserver->do_deactivate();		
	    }
	    $_->make_infodatabase();	    
	}

    }  @builders;

    map { local $_=$_; $_->collect_specific(); } @builders;
  }
  elsif ($mode =~ /^compress_text$/i)
  {
    map { local $_=$_; $_->compress_text($textindex); } @builders;
  }
  elsif ($mode =~ /^build_index$/i)
  {
    map { local $_=$_; $_->build_indexes($indexname, $indexlevel); } @builders;
  }
  elsif ($mode =~ /^infodb$/i)
  {
    map { 
	local $_=$_;

	# when *incrementally* rebuilding a collection using any db that *doesn't* support concurrent
	# read and write (e.g. gdbm), need to deactivate the collection before make_infodatabase()

	if($_->supports_make_infodatabase()) {
	    my $infodbtype = $_->{'infodbtype'};
	    my $dbSupportsConcurrentRW = &dbutil::supportsConcurrentReadAndWrite($infodbtype);
	
	    if(!$dbSupportsConcurrentRW && $self->{'incremental'}) {
		$gsserver->print_task_msg("About to deactivate collection ".$self->get_collection());
		$gsserver->do_deactivate();
	    }
	    $_->make_infodatabase(); 
	}
    } @builders;
  }
  else
  {
    (&gsprintf::gsprintf(STDERR, "{buildcol.unknown_mode}\n", $mode) && die);
  }
}
# build_collection()

# @function build_auxiliary_files
#
sub build_auxiliary_files
{
  my $self = shift(@_);
  my @builders = @{shift(@_)};
  if (!$self->{'debug'})
  {
    map {local $_=$_; $_->make_auxiliary_files(); } @builders;
  }
}
# build_auxiliary_files()

# @function complete_builders
#
sub complete_builders
{
  my $self = shift(@_);
  my @builders = @{shift(@_)};

  map {local $_=$_; $_->deinit(); } @builders;

  if (($self->{'realbuilddir'} ne $self->{'builddir'}) && !$self->{'debug'})
  {
    if ($self->{'verbosity'} >= 1)
    {
      &gsprintf::gsprintf($out, "{buildcol.copying_back_cached_build}\n");
    }
    &FileUtils::removeFilesRecursive($self->{'builddir'});
    &FileUtils::copyFilesRecursive($self->{'realbuilddir'}, $self->{'builddir'});
  }

  # for RSS support: Need rss-items.rdf file in index folder
  #  check if a file called rss-items.rdf exists in archives, then copy it into the building folder
  #  so that when building is moved to index, this file will then also be in index as desired
  my $collection_dir = &util::resolve_collection_dir($self->{'collectdir'},
                                                     $self->{'collection'},
                                                     $self->{'site'});
  my $rss_items_rdf_file = &FileUtils::filenameConcatenate($self->{'archivedir'}, 'rss-items.rdf');
  # @todo FileUtils
  if(defined $self->{'builddir'} && &FileUtils::directoryExists($self->{'builddir'}) && &FileUtils::fileExists($rss_items_rdf_file))
  {
    if ($self->{'verbosity'} >= 1)
    {
	my $archivedir_tail = "'".basename($self->{'archivedir'})."'";
	my $builddir_tail =  "'".basename($self->{'builddir'})."'";

	&gsprintf::gsprintf($self->{'out'}, "{buildcol.copying_rss_items_rdf}\n", $archivedir_tail, $builddir_tail);
    }
    &FileUtils::copyFiles($rss_items_rdf_file, $self->{'builddir'});
  }

  if ($self->{'gli'})
  {
    print STDERR "</Build>\n";
  }
}
# complete_builders()

# @function activate_collection
#
sub activate_collection
{
  my $self = shift(@_);

  # if buildcol.pl was run with -activate, need to run activate.pl
  # now that building's complete
  if ($self->{'activate'})
  {
    #my $quoted_argv = join(" ", map { "\"$_\"" } @ARGV);
    my @activate_argv = ();
    push(@activate_argv, '-library_url', $self->{'library_url'}) if ($self->{'library_url'});
    push(@activate_argv, '-library_name', $self->{'library_name'}) if ($self->{'library_name'});
    push(@activate_argv, '-collectdir', $self->{'collectdir'}) if ($self->{'collectdir'});
    push(@activate_argv, '-builddir', $self->{'builddir'}) if ($self->{'builddir'});
    push(@activate_argv, '-indexdir', $self->{'indexdir'}) if ($self->{'indexdir'});
    push(@activate_argv, '-site', $self->{'site'}) if ($self->{'site'});
    push(@activate_argv, '-verbosity', $self->{'verbosity'}) if ($self->{'verbosity'});
    push(@activate_argv, '-removeold') if ($self->{'removeold'});
    push(@activate_argv, '-keepold') if ($self->{'keepold'});
    push(@activate_argv, '-incremental') if ($self->{'incremental'});
    push(@activate_argv, '-skipactivation', $self->{'skipactivation'}) if ($self->{'skipactivation'});

    my $quoted_argv = join(' ', map { "\"$_\"" } @activate_argv);
    my $activatecol_cmd = '"' . &util::get_perl_exec(). '" -S activate.pl ' . $quoted_argv . ' "' . $self->get_collection() . '"';
    my $activatecol_status = system($activatecol_cmd)/256;

    if ($activatecol_status != 0)
    {
      print STDERR "Error: Failed to run: $activatecol_cmd\n";
      print STDERR "       $!\n" if ($! ne '');
      exit(-1);
    }
  }
}

# @function deinit()
#
sub deinit
{
  my $self = shift(@_);

  if ($self->{'close_out'})
  {
    close OUT;
  }
  if ($self->{'close_faillog'})
  {
    close FAILLOG;
  }
}
# deinit()

1;
