###########################################################################
#
# inexport.pm -- useful class to support import.pl and export.pl
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

package inexport;

use strict;

no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

use arcinfo;
use colcfg;
use dbutil;
use doc;
use oaiinfo;
use plugin;
use plugout;
use manifest;
use inexport;
use util;
use scriptutil;
use FileHandle;
use gsprintf 'gsprintf';
use printusage;
use parse2;

use File::Basename;

my $oidtype_list =
    [ { 'name' => "hash",
        'desc' => "{import.OIDtype.hash}" },
      { 'name' => "hash_on_full_filename",
        'desc' => "{import.OIDtype.hash_on_full_filename}" },
      { 'name' => "assigned",
        'desc' => "{import.OIDtype.assigned}" },
      { 'name' => "incremental",
        'desc' => "{import.OIDtype.incremental}" },
      { 'name' => "filename",
        'desc' => "{import.OIDtype.filename}" },
      { 'name' => "dirname",
        'desc' => "{import.OIDtype.dirname}" },
      { 'name' => "full_filename",
        'desc' => "{import.OIDtype.full_filename}" } ];

$inexport::directory_arguments = 
[
      { 'name' => "importdir",
	'desc' => "{import.importdir}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "import",
        'hiddengli' => "yes" },
      { 'name' => "collectdir",
	'desc' => "{import.collectdir}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect"),
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
 
];
$inexport::arguments = 
[
      # don't set the default to hash - want to allow this to come from
      # entry in collect.cfg but want to override it here 
      { 'name' => "OIDtype",
	'desc' => "{import.OIDtype}",
	'type' => "enum",
	'list' => $oidtype_list,
	'deft' => "hash_on_full_filename",
	'reqd' => "no",
	'modegli' => "2" },
      { 'name' => "OIDmetadata",
	'desc' => "{import.OIDmetadata}",
	'type' => "string",
	'deft' => "dc.Identifier",
	'reqd' => "no",
	'modegli' => "2" },
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
        'hiddengli' => "yes" } ,
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
	'deft' => "-1",
	'range' => "-1,",
	'modegli' => "1" },
       { 'name' => "debug",
	'desc' => "{import.debug}",
	'type' => "flag",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "faillog",
	'desc' => "{import.faillog}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate("&lt;collectdir&gt;", "colname", "etc", "fail.log"),
	'deft' => "",
	'reqd' => "no",
        'modegli' => "3" },
       { 'name' => "out",
	'desc' => "{import.out}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no",
        'hiddengli' => "yes" },
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
	'deft' => "2",
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

];

sub new 
{
    my $class = shift (@_);
    my ($mode,$argv,$options,$opt_listall_options) = @_;

    my $self = { 'xml' => 0, 'mode' => $mode };

    # general options available to all plugins
    my $arguments = $options->{'args'};
    my $intArgLeftinAfterParsing = parse2::parse($argv,$arguments,$self,"allow_extra_options");
    # Parse returns -1 if something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{import.params}",1);
	print STDERR "Something went wrong during parsing the arguments. Scroll up for details.\n";
	die "\n";
    }

    my $language = $self->{'language'};
    # If $language has been specified, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language && $language =~ /\S/) {
	&gsprintf::load_language_specific_resource_bundle($language);
    }

    if ($self->{'listall'}) {
	if ($self->{'xml'}) {
	    &PrintUsage::print_xml_usage($opt_listall_options);
	}
	else
	{
	    &PrintUsage::print_txt_usage($opt_listall_options,"{export.params}");
	}
	die "\n";
    }

    if ($self->{'xml'}) {
        &PrintUsage::print_xml_usage($options);
	print "\n";
	return bless $self, $class;
    }

    if ($self->{'gli'}) { # the gli wants strings to be in UTF-8
	&gsprintf::output_strings_in_UTF8; 
    }

    # If the user specified -h, then we output the usage
    if (@$argv && $argv->[0] =~ /^\-+h/) {
	&PrintUsage::print_txt_usage($options, "{import.params}");
	die "\n";
    }
    # now check that we had exactly one leftover arg, which should be 
    # the collection name. We don't want to do this earlier, cos 
    # -xml arg doesn't need a collection name

    if ($intArgLeftinAfterParsing != 1 )
    {
	&PrintUsage::print_txt_usage($options, "{import.params}", 1);
	print STDERR "There should be one argument left after parsing the script args: the collection name.\n";
	die "\n";
    }

    $self->{'close_out'} = 0;
    my $out = $self->{'out'};
    if ($out !~ /^(STDERR|STDOUT)$/i) {
	open (OUT, ">$out") ||
	    (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);
	$out = 'inexport::OUT';
	$self->{'close_out'} = 1;
    }
    $out->autoflush(1);
    $self->{'out'} = $out;

    my $statsfile = $self->{'statsfile'};
    if ($statsfile !~ /^(STDERR|STDOUT)$/i) {
	open (STATSFILE, ">$statsfile") ||
	    (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $statsfile) && die);
	$statsfile = 'inexport::STATSFILE';
	$self->{'close_stats'} = 1;
    }
    $statsfile->autoflush(1);
    $self->{'statsfile'} = $statsfile;

    # @ARGV should be only one item, the name of the collection
    $self->{'collection'} = shift @$argv;

    # Unless otherwise stated all manifests are considered version 1---where
    # they act more like an advanced process expression---as compared to newer
    # manifest files that act as an explicit (and exhaustive) list of files to
    # process [jmt12]
    $self->{'manifest_version'} = 1;

    return bless $self, $class;
}

# Simplified version of the contstructor for use with CGI scripts
sub newCGI 
{
    my $class = shift (@_);
    my ($mode,$collect,$gsdl_cgi,$opt_site) = @_;

    my $self = { 'xml' => 0, 'mode' => $mode };

    $self->{'out'} = STDERR;
    
	if (defined $gsdl_cgi) {
		$self->{'site'} = $opt_site;
		my $collect_dir = $gsdl_cgi->get_collection_dir($opt_site);
		$self->{'collectdir'} = $collect_dir;
	}
	else {	
		$self->{'site'} = "";
		$self->{'collectdir'} = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"collect");
	}
    $self->{'faillog'} = "";
   
    $self->{'collection'} = $collect;

    return bless $self, $class;
}
sub get_collection
{
    my $self = shift @_;
    
    return $self->{'collection'};
}


sub read_collection_cfg
{
    my $self = shift @_;
    my ($collection,$options) = @_;

    my $collectdir = $self->{'collectdir'};
    my $site       = $self->{'site'};
    my $out        = $self->{'out'};
	 
    if (($collection = &colcfg::use_collection($site, $collection, $collectdir)) eq "") {
	#&PrintUsage::print_txt_usage($options, "{import.params}", 1);
	die "\n";
    }

    # set gs_version 2/3
    $self->{'gs_version'} = "2";
    if ((defined $site) && ($site ne "")) {
	# gs3
	$self->{'gs_version'} = "3";
    }

    # add collection's perllib dir into include path in
    # case we have collection specific modules
    &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib'));

    # check that we can open the faillog
    my $faillog = $self->{'faillog'};
    if ($faillog eq "") {
	$faillog = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "etc", "fail.log");
    }
    open (FAILLOG, ">$faillog") ||
	(&gsprintf(STDERR, "{import.cannot_open_fail_log}\n", $faillog) && die);

    
    my $faillogname = $faillog;
    $faillog = 'inexport::FAILLOG';
    $faillog->autoflush(1);
    $self->{'faillog'} = $faillog;
    $self->{'faillogname'} = $faillogname;
    $self->{'close_faillog'} = 1;

    # Read in the collection configuration file.
    my $gs_mode = "gs".$self->{'gs_version'}; #gs2 or gs3
    my $config_filename = &colcfg::get_collect_cfg_name($out, $gs_mode);

    # store the config file's name, so oaiinfo object constructor can be instantiated with it
    $self->{'config_filename'} = $config_filename;

    my $collectcfg = &colcfg::read_collection_cfg ($config_filename, $gs_mode);

    return ($config_filename,$collectcfg);
}

sub set_collection_options
{
    my $self = shift @_;
    my ($collectcfg) = @_;

    my $inexport_mode = $self->{'mode'};

    my $importdir  = $self->{'importdir'};
    my $archivedir = $self->{'archivedir'} || $self->{'exportdir'};
    my $out        = $self->{'out'};

    # If the infodbtype value wasn't defined in the collect.cfg file, use the default
    if (!defined($collectcfg->{'infodbtype'}))
    {
      $collectcfg->{'infodbtype'} = &dbutil::get_default_infodb_type();
    }
    if ($collectcfg->{'infodbtype'} eq "gdbm-txtgz") {
	# we can't use the text version for archives dbs.
	$collectcfg->{'infodbtype'} = "gdbm";
    }

    if (defined $self->{'default_importdir'} && defined $collectcfg->{'importdir'}) {
	$importdir = $collectcfg->{'importdir'};
    }

    if ($inexport_mode eq "import") {
	if ( defined $self->{'default_archivedir'} && defined $collectcfg->{'archivedir'}) {
	    $archivedir = $collectcfg->{'archivedir'};
	}
    }
    elsif ($inexport_mode eq "export") {
	if (defined $self->{'default_exportdir'} && defined $collectcfg->{'exportdir'}) {
	    $archivedir = $collectcfg->{'exportdir'};
	}
    }
    # fill in the default import and archives directories if none
    # were supplied, turn all \ into / and remove trailing /
    if (!&FileUtils::isFilenameAbsolute($importdir))
    {
      $importdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, $importdir);
    }
    else
    {
      # Don't do this - it kills protocol prefixes
      #$importdir =~ s/[\\\/]+/\//g;
      #$importdir =~ s/\/$//;
      # Do this instead
      &FileUtils::sanitizePath($importdir);
    }
    if (!&FileUtils::directoryExists($importdir))
    {
      &gsprintf($out, "{import.no_import_dir}\n\n", $importdir);
      die "\n";
    }
    $self->{'importdir'} = $importdir;

    if (!&FileUtils::isFilenameAbsolute($archivedir)) {
	$archivedir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, $archivedir);
    }
    else {
	
	$archivedir = &FileUtils::sanitizePath($archivedir);
    }
    $self->{'archivedir'} = $archivedir;

    if (defined $self->{'default_verbosity'}) {
	if (defined $collectcfg->{'verbosity'} && $collectcfg->{'verbosity'} =~ /\d+/) {
	    $self->{'verbosity'} = $collectcfg->{'verbosity'};
	} 
    }
 
    if (defined $collectcfg->{'manifest'} && $self->{'manifest'} eq "") {
	$self->{'manifest'} = $collectcfg->{'manifest'};
    }

    if (defined $collectcfg->{'gzip'} && !$self->{'gzip'}) {
	if ($collectcfg->{'gzip'} =~ /^true$/i) {
	    $self->{'gzip'} = 1;
	}
    }

    if (defined $self->{'default_maxdocs'}) {
	if (defined $collectcfg->{'maxdocs'} && $collectcfg->{'maxdocs'} =~ /\-?\d+/) {
	    $self->{'maxdocs'} = $collectcfg->{'maxdocs'};
	}
    }

   

    if (defined $self->{'default_OIDtype'} ) {
	if (defined $collectcfg->{'OIDtype'} 
	    && $collectcfg->{'OIDtype'} =~ /^(hash|hash_on_full_filename|incremental|assigned|filename|dirname|full_filename)$/) {
	    $self->{'OIDtype'} = $collectcfg->{'OIDtype'};
	}
    }

    if (defined $self->{'default_OIDmetadata'}) {
	if (defined $collectcfg->{'OIDmetadata'}) {
	    $self->{'OIDmetadata'} = $collectcfg->{'OIDmetadata'};
	} 
    }

    if (defined $collectcfg->{'debug'} && $collectcfg->{'debug'} =~ /^true$/i) {
	$self->{'debug'} = 1;
    }
    if (defined $collectcfg->{'gli'} && $collectcfg->{'gli'} =~ /^true$/i) {
	$self->{'gli'} = 1;
    }
    $self->{'gli'} = 0 unless defined $self->{'gli'};
       
    # check keepold and removeold
    my $checkdir = ($inexport_mode eq "import") ? "archives" : "export";

    my ($removeold, $keepold, $incremental, $incremental_mode) 
	= &scriptutil::check_removeold_and_keepold($self->{'removeold'}, $self->{'keepold'}, 
						   $self->{'incremental'}, $checkdir, 
						   $collectcfg);

    $self->{'removeold'}        = $removeold;
    $self->{'keepold'}          = $keepold;
    $self->{'incremental'}      = $incremental;
    $self->{'incremental_mode'} = $incremental_mode;

    # Since this wasted my morning, let's at least warn a user that manifest
    # files now *only* work if keepold is set [jmt12]
    if ($self->{'manifest'} && (!$keepold || !$incremental))
    {
      print STDERR "Warning: -manifest flag should not be specified without also setting -keepold or -incremental\n";
    }
	}

sub process_files
{
    my $self = shift @_;
    my ($config_filename,$collectcfg) = @_;

    my $inexport_mode = $self->{'mode'};

    my $verbosity   = $self->{'verbosity'};
    my $debug       = $self->{'debug'};

    my $importdir   = $self->{'importdir'};
    my $archivedir = $self->{'archivedir'} || $self->{'exportdir'};

    my $incremental = $self->{'incremental'};
    my $incremental_mode = $self->{'incremental_mode'};

    my $gs_version = $self->{'gs_version'};

    my $removeold   = $self->{'removeold'};
    my $keepold     = $self->{'keepold'};

    my $saveas      = $self->{'saveas'};
    my $saveas_options = $self->{'saveas_options'};
    my $OIDtype     = $self->{'OIDtype'};
    my $OIDmetadata = $self->{'OIDmetadata'};

    my $out         = $self->{'out'};
    my $faillog     = $self->{'faillog'};

    my $maxdocs     = $self->{'maxdocs'};
    my $gzip        = $self->{'gzip'};
    my $groupsize   = $self->{'groupsize'};
    my $sortmeta    = $self->{'sortmeta'};

    my $removeprefix = $self->{'removeprefix'};
    my $removesuffix = $self->{'removesuffix'};

    my $gli          = $self->{'gli'};

    # related to export
    my $xsltfile         = $self->{'xsltfile'};
    my $group_marc       = $self->{'group_marc'};
    my $mapping_file     = $self->{'mapping_file'};
    my $xslt_mets        = $self->{'xslt_mets'};
    my $xslt_txt         = $self->{'xslt_txt'};
    my $fedora_namespace = $self->{'fedora_namespace'};
    my $metadata_prefix  = $self->{'metadata_prefix'};

    if ($inexport_mode eq "import") {
	print STDERR "<Import>\n" if $gli;
    }
    else {
	print STDERR "<export>\n" if $gli;
    }

    my $manifest_lookup = new manifest($collectcfg->{'infodbtype'},$archivedir);
    if ($self->{'manifest'} ne "") {
	my $manifest_filename = $self->{'manifest'};

	if (!&FileUtils::isFilenameAbsolute($manifest_filename)) {
	    $manifest_filename = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, $manifest_filename);
	}
        $self->{'manifest'} = &FileUtils::sanitizePath($self->{'manifest'});
	#$self->{'manifest'} =~ s/[\\\/]+/\//g;
	#$self->{'manifest'} =~ s/\/$//;

	$manifest_lookup->parse($manifest_filename);

        # manifests may now include a version number [jmt12]
        $self->{'manifest_version'} = $manifest_lookup->get_version();
    }

    my $manifest = $self->{'manifest'};

    # load all the plugins
    my $plugins = [];
    if (defined $collectcfg->{'plugin'}) {
	$plugins = $collectcfg->{'plugin'};
    }

    my $plugin_incr_mode = $incremental_mode;
    if ($manifest ne "") {
	# if we have a manifest file, then we pretend we are fully incremental for plugins
	$plugin_incr_mode = "all";
    }
    #some global options for the plugins
    my @global_opts = ();

    my $pluginfo = &plugin::load_plugins ($plugins, $verbosity, $out, $faillog, \@global_opts, $plugin_incr_mode, $gs_version);
    if (scalar(@$pluginfo) == 0) {
	&gsprintf($out, "{import.no_plugins_loaded}\n");
	die "\n";
    }

    # remove the old contents of the archives directory (and tmp
    # directory) if needed

    if ($removeold) {
	if (&FileUtils::directoryExists($archivedir)) {
	    &gsprintf($out, "{import.removing_archives}\n");
	    &FileUtils::removeFilesRecursive($archivedir);
	}
	my $tmpdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
	$tmpdir =~ s/[\\\/]+/\//g;
	$tmpdir =~ s/\/$//;
	if (&FileUtils::directoryExists($tmpdir)) {
	    &gsprintf($out, "{import.removing_tmpdir}\n");
	    &FileUtils::removeFilesRecursive($tmpdir);
	}
    }

    # create the archives dir if needed
    &FileUtils::makeAllDirectories($archivedir);

    # read the archive information file

    # BACKWARDS COMPATIBILITY: Just in case there are old .ldb/.bdb files (won't do anything for other infodbtypes)
    &util::rename_ldb_or_bdb_file(&FileUtils::filenameConcatenate($archivedir, "archiveinf-doc"));
    &util::rename_ldb_or_bdb_file(&FileUtils::filenameConcatenate($archivedir, "archiveinf-src"));

    # When we make these initial calls to determine the archive information doc
    # and src databases we pass through a '1' to indicate this is the first
    # time we are referring to these databases. When using dynamic dbutils
    # (available in extensions) this indicates to some database types (for
    # example, persistent servers) that this is a good time to perform any
    # one time initialization. The argument has no effect on vanilla dbutils
    # [jmt12]
    my $perform_firsttime_init = 1;
    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($collectcfg->{'infodbtype'}, "archiveinf-doc", $archivedir, $perform_firsttime_init);
    my $arcinfo_src_filename = &dbutil::get_infodb_file_path($collectcfg->{'infodbtype'}, "archiveinf-src", $archivedir, $perform_firsttime_init);

    my $archive_info = new arcinfo ($collectcfg->{'infodbtype'});
    $archive_info->load_info ($arcinfo_doc_filename);

    if ($manifest eq "") {
	# Load in list of files in import folder from last import (if present)
	$archive_info->load_prev_import_filelist ($arcinfo_src_filename);
    }

    ####Use Plugout####
    my $plugout; 

    my $generate_auxiliary_files = 0;
    if ($inexport_mode eq "import") {
	$generate_auxiliary_files = 1;
    }
    elsif ($self->{'include_auxiliary_database_files'}) {
	$generate_auxiliary_files = 1;
    }
    $self->{'generate_auxiliary_files'} = $generate_auxiliary_files;

    # Option to use user defined plugout
    if ($inexport_mode eq "import") {
	if (defined $collectcfg->{'plugout'}) {
	    # If a plugout was specified in the collect.cfg file, assume it is sensible
	    # We can't check the name because it could be anything, if it is a custom plugout
	    print STDERR "Using plugout specified in collect.cfg: ".join(' ', @{$collectcfg->{'plugout'}})."\n";
	    $plugout = $collectcfg->{'plugout'};
	}
	else {
	    push @$plugout,$saveas."Plugout";
	}

    }
    else {
	if (defined $collectcfg->{'plugout'} && $collectcfg->{'plugout'} =~ /^(GreenstoneXML|.*METS|DSpace|MARCXML)Plugout/) {
	    $plugout = $collectcfg->{'plugout'};
	    print STDERR "Using plugout specified in collect.cfg: $collectcfg->{'plugout'}\n";
	}
	else {
	    push @$plugout,$saveas."Plugout";
	}
    }

    my $plugout_name = $plugout->[0];

    if (defined $saveas_options) {
	my @user_plugout_options = split(" ", $saveas_options);
	push @$plugout, @user_plugout_options;
    }
    push @$plugout,("-output_info",$archive_info)  if (defined $archive_info); 
    push @$plugout,("-verbosity",$verbosity)       if (defined $verbosity);
    push @$plugout,("-debug")                      if ($debug);
    push @$plugout,("-gzip_output")                if ($gzip);
    push @$plugout,("-output_handle",$out)         if (defined $out);

    push @$plugout,("-xslt_file",$xsltfile)        if (defined $xsltfile && $xsltfile ne "");
    push @$plugout, ("-no_auxiliary_databases") if ($generate_auxiliary_files == 0);
    if ($inexport_mode eq "import") {
	if ($plugout_name =~ m/^GreenstoneXMLPlugout$/) {
	    push @$plugout,("-group_size",$groupsize)      if (defined $groupsize);
	}
    }
    my $processor = &plugout::load_plugout($plugout);
    $processor->setoutputdir ($archivedir);
    $processor->set_sortmeta ($sortmeta, $removeprefix, $removesuffix) if defined $sortmeta;
    $processor->set_OIDtype ($OIDtype, $OIDmetadata);
    $processor->begin();
    &plugin::begin($pluginfo, $importdir, $processor, $maxdocs, $gli);
    
    if ($removeold) {
    	# occasionally, plugins may want to do something on remove
    	# old, eg pharos image indexing
	&plugin::remove_all($pluginfo, $importdir, $processor, $maxdocs, $gli);
    }

    # process the import directory
    my $block_hash = {};
    $block_hash->{'new_files'} = {};
    $block_hash->{'reindex_files'} = {};
    # all of these are set somewhere else, so it's more readable to define them
    # here [jmt12]
    $block_hash->{'all_files'} = {};
    $block_hash->{'deleted_files'} = {};
    $block_hash->{'file_blocks'} = {};
    $block_hash->{'metadata_files'} = {};
    $block_hash->{'shared_fileroot'} = '';
    # a new flag so we can tell we had a manifest way down in the plugins
    # [jmt12]
    $block_hash->{'manifest'} = 'false';
    my $metadata = {};
    
    # global blocking pass may set up some metadata
    # does this set up metadata?????
    # - when we have a newer manifest file we don't do this -unless- the
    #   collection configuration indicates this collection contains complex
    #   (inherited) metadata [jmt12]
    if ($manifest eq '' || (defined $collectcfg->{'complexmeta'} && $collectcfg->{'complexmeta'} eq 'true'))
    {
      &plugin::file_block_read($pluginfo, $importdir, "", $block_hash, $metadata, $gli);
    }
    else
    {
      print STDERR "Skipping global file scan due to manifest and complexmeta configuration\n";
    }


    # Prepare to work with the <collection>/etc/oai-inf.<db> that keeps track
    # of the OAI identifiers with their time stamps and deleted status.    
    my $oai_info = new oaiinfo($self->{'config_filename'}, $collectcfg->{'infodbtype'}, $verbosity);
    my $have_manifest = ($manifest eq '') ? 0 : 1;    
    $oai_info->import_stage($removeold, $have_manifest);


    if ($manifest ne "") {

      # mark that we are using a manifest - information that might be needed
      # down in plugins (for instance DirectoryPlugin)
      $block_hash->{'manifest'} = $self->{'manifest_version'};

	# 
	# 1. Process delete files first
	# 
	my @deleted_files = keys %{$manifest_lookup->{'delete'}};
	my @full_deleted_files = ();

	# ensure all filenames are absolute
	foreach my $df (@deleted_files) {
	    my $full_df =
		(&FileUtils::isFilenameAbsolute($df)) 
		? $df
		: &FileUtils::filenameConcatenate($importdir,$df);

	    if (-d $full_df) {
		&add_dir_contents_to_list($full_df, \@full_deleted_files);
	    } else {
		push(@full_deleted_files,$full_df);
	    }
	}
	
	&plugin::remove_some($pluginfo, $collectcfg->{'infodbtype'}, $archivedir, \@full_deleted_files);
	mark_docs_for_deletion($archive_info,{},
			       \@full_deleted_files,
			       $archivedir, $verbosity, "delete");


	# 
	# 2. Now files for reindexing
	# 

	my @reindex_files = keys %{$manifest_lookup->{'reindex'}};
	my @full_reindex_files = ();
	# ensure all filenames are absolute
	foreach my $rf (@reindex_files) {	    
	    my $full_rf =
		(&FileUtils::isFilenameAbsolute($rf)) 
		? $rf
		: &FileUtils::filenameConcatenate($importdir,$rf);

	    if (-d $full_rf) {
		&add_dir_contents_to_list($full_rf, \@full_reindex_files);
	    } else {
		push(@full_reindex_files,$full_rf);
	    }
	}
	
	&plugin::remove_some($pluginfo, $collectcfg->{'infodbtype'}, $archivedir, \@full_reindex_files);
	mark_docs_for_deletion($archive_info,{},\@full_reindex_files, $archivedir,$verbosity, "reindex");

	# And now to ensure the new version of the file processed by 
	# appropriate plugin, we need to add it to block_hash reindex list
	foreach my $full_rf (@full_reindex_files) {
	    $block_hash->{'reindex_files'}->{$full_rf} = 1;
	}


	# 
	# 3. Now finally any new files - add to block_hash new_files list
	# 

	my @new_files = keys %{$manifest_lookup->{'index'}};
	my @full_new_files = ();

	foreach my $nf (@new_files) {
	    # ensure filename is absolute
	    my $full_nf =
		(&FileUtils::isFilenameAbsolute($nf)) 
		? $nf
		: &FileUtils::filenameConcatenate($importdir,$nf);

	    if (-d $full_nf) {
		&add_dir_contents_to_list($full_nf, \@full_new_files);
	    } else {
		push(@full_new_files,$full_nf);
	    }
	}

	my $arcinfo_src_filename = &dbutil::get_infodb_file_path($collectcfg->{'infodbtype'}, "archiveinf-src", $archivedir);
      # need to check this file exists before trying to read it - in the past
      # it wasn't possible to have a manifest unless keepold was also set so
      # you were pretty much guaranteed arcinfo existed
      # [jmt12]
      # @todo &FileUtils::fileExists($arcinfo_src_filename) [jmt12]
      if (-e $arcinfo_src_filename)
      {
	my $arcinfodb_map = {};
	&dbutil::read_infodb_file($collectcfg->{'infodbtype'}, $arcinfo_src_filename, $arcinfodb_map);
	foreach my $f (@full_new_files) {
	    my $rel_f = &util::abspath_to_placeholders($f);

	    # check that we haven't seen it already
	    if (defined $arcinfodb_map->{$rel_f}) {
		# TODO make better warning
		print STDERR "Warning: $f ($rel_f) already in src archive, \n";
	    } else {
		$block_hash->{'new_files'}->{$f} = 1;
	    }
	}

	undef $arcinfodb_map;
      }
      # no existing files - so we can just add all the files [jmt12]
      else
      {
        foreach my $f (@full_new_files)
        {
          $block_hash->{'new_files'}->{$f} = 1;
        }
      }

      # If we are not using complex inherited metadata (and thus have skipped
      # the global file scan) we need to at least check for a matching
      # metadata.xml for the files being indexed/reindexed
      # - unless we are using the newer version of Manifests, which are treated
      #   verbatim, and should have a metadata element for metadata files (so
      #   we can explicitly process metadata files other than metadata.xml)
      # [jmt12]
      if ($self->{'manifest_version'} == 1 && (!defined $collectcfg->{'complexmeta'} || $collectcfg->{'complexmeta'} ne 'true'))
      {
        my @all_files_to_import = (keys %{$block_hash->{'reindex_files'}}, keys %{$block_hash->{'new_files'}});
        foreach my $file_to_import (@all_files_to_import)
        {
          my $metadata_xml_path = $file_to_import;
          $metadata_xml_path =~ s/[^\\\/]*$/metadata.xml/;
          if (&FileUtils::fileExists($metadata_xml_path))
          {
            &plugin::file_block_read($pluginfo, '', $metadata_xml_path, $block_hash, $metadata, $gli);
          }
        }
      }

      # new version manifest files explicitly list metadata files to be
      # processed (ignoring complexmeta if set)
      # [jmt12]
      if ($self->{'manifest_version'} > 1)
      {
        # Process metadata files
        foreach my $file_to_import (keys %{$block_hash->{'reindex_files'}}, keys %{$block_hash->{'new_files'}})
        {
          $self->perform_process_files($manifest, $pluginfo, '', $file_to_import, $block_hash, $metadata, $processor, $maxdocs);
        }
      }
    } # end if (manifest ne "")
    else {
	# if incremental, we read through the import folder to see whats changed.

	if ($incremental || $incremental_mode eq "onlyadd") {
	    prime_doc_oid_count($archivedir);

	    # Can now work out which files were new, already existed, and have
	    # been deleted
	    
	    new_vs_old_import_diff($archive_info,$block_hash,$importdir,
				   $archivedir,$verbosity,$incremental_mode);
	    
	    my @new_files = sort keys %{$block_hash->{'new_files'}};
	    if (scalar(@new_files>0)) {
		print STDERR "New files and modified metadata files since last import:\n  ";
		print STDERR join("\n  ",@new_files), "\n";
	    }

	    if ($incremental) {
               # only look for deletions if we are truely incremental
		my @deleted_files = sort keys %{$block_hash->{'deleted_files'}};
		# Filter out any in gsdl/tmp area
		my @filtered_deleted_files = ();
		my $gsdl_tmp_area = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "tmp");
		my $collect_tmp_area = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
		$gsdl_tmp_area = &util::filename_to_regex($gsdl_tmp_area);
		$collect_tmp_area = &util::filename_to_regex($collect_tmp_area);
			      
		foreach my $df (@deleted_files) {
		    next if ($df =~ m/^$gsdl_tmp_area/);
		    next if ($df =~ m/^$collect_tmp_area/);
		    
		    push(@filtered_deleted_files,$df);
		}		
		

		@deleted_files = @filtered_deleted_files;
		
		if (scalar(@deleted_files)>0) {
		    print STDERR "Files deleted since last import:\n  ";
		    print STDERR join("\n  ",@deleted_files), "\n";
		
		
		    &plugin::remove_some($pluginfo, $collectcfg->{'infodbtype'}, $archivedir, \@deleted_files);
		    
		    mark_docs_for_deletion($archive_info,$block_hash,\@deleted_files, $archivedir,$verbosity, "delete");
		}
		
		my @reindex_files = sort keys %{$block_hash->{'reindex_files'}};
		
		if (scalar(@reindex_files)>0) {
		    print STDERR "Files to reindex since last import:\n  ";
		    print STDERR join("\n  ",@reindex_files), "\n";
		    &plugin::remove_some($pluginfo, $collectcfg->{'infodbtype'}, $archivedir, \@reindex_files);
		    mark_docs_for_deletion($archive_info,$block_hash,\@reindex_files, $archivedir,$verbosity, "reindex");
		}
				
	    }	    
	} # end if incremental/only_add mode
	# else no manifest AND not incremental
    } # end if else block of manifest ne "" else eq ""

    # Check for existence of the file that's to contain earliestDateStamp in archivesdir
    # Do nothing if the file already exists (file exists on incremental build).
    # If the file doesn't exist, as happens on full build, create it and write out the current datestamp into it
    # In buildcol, read the file's contents and set the earliestdateStamp in GS2's build.cfg / GS3's buildconfig.xml
    # In doc.pm have set_oaiLastModified similar to set_lastmodified, and create the doc fields 
    # oailastmodified and oailastmodifieddate
    my $earliestDatestampFile = &FileUtils::filenameConcatenate($archivedir, "earliestDatestamp");
    if ($self->{'generate_auxiliary_files'}) {
    if (!-f $earliestDatestampFile && -d $archivedir) {
	my $current_time_in_seconds = time; # in seconds

	if(open(FOUT, ">$earliestDatestampFile")) {
	    # || (&gsprintf(STDERR, "{common.cannot_open}: $!\n", $earliestDatestampFile) && die);
	    print FOUT $current_time_in_seconds;
	    close(FOUT);
	}
	else {
	    &gsprintf(STDERR, "{import.cannot_write_earliestdatestamp}\n", $earliestDatestampFile);
	}

    }
    }
    
    $self->perform_process_files($manifest, $pluginfo, $importdir, '', $block_hash, $metadata, $processor, $maxdocs);

    if ($saveas eq "FedoraMETS") {
	# create collection "doc obj" for Fedora that contains
	# collection-level metadata
	
	my $doc_obj = new doc($config_filename,"nonindexed_doc","none");
	$doc_obj->set_OID("collection");
	
	my $col_name = undef;
	my $col_meta = $collectcfg->{'collectionmeta'};
	
	if (defined $col_meta) {	    
	    store_collectionmeta($col_meta,"collectionname",$doc_obj); # in GS3 this is a collection's name
	    store_collectionmeta($col_meta,"collectionextra",$doc_obj); # in GS3 this is a collection's description	    
	}
	$processor->process($doc_obj);
    }

    &plugin::end($pluginfo, $processor);

    &plugin::deinit($pluginfo, $processor);

    # Store the value of OIDCount (used in doc.pm) so it can be
    # restored correctly to this value on an incremental build
    # - this OIDcount file should only be generated for numerical oids [jmt12]
    if ($self->{'OIDtype'} eq 'incremental')
    {
      store_doc_oid_count($archivedir);
    }

    # signal to the processor (plugout) that we have finished processing - if we are group processing, then the final output file needs closing.
    $processor->close_group_output() if $processor->is_group();

#    if ($inexport_mode eq "import") {
    if ($self->{'generate_auxiliary_files'}) {
	# write out the archive information file
	# for backwards compatability with archvies.inf file
	if ($arcinfo_doc_filename =~ m/(contents)|(\.inf)$/) {
	    $archive_info->save_info($arcinfo_doc_filename);
	}
	else {
	    $archive_info->save_revinfo_db($arcinfo_src_filename);
	}
    }
    return $pluginfo;
}

# @function perform_process_files()
# while process_files() above prepares the system to import files this is the
# function that actually initiates the plugin pipeline to process the files.
# This function the therefore be overridden in subclasses of inexport.pm should
# they wish to do different or further processing
# @author jmt12
sub perform_process_files
{
  my $self = shift(@_);
  my ($manifest, $pluginfo, $importdir, $file_to_import, $block_hash, $metadata, $processor, $maxdocs) = @_;
  my $gli = $self->{'gli'};
  # specific file to process - via manifest version 2+
  if ($file_to_import ne '')
  {
    &plugin::read ($pluginfo, '', $file_to_import, $block_hash, $metadata, $processor, $maxdocs, 0, $gli);
  }
  # global file scan - if we are using a new version manifest, files would have
  # been read above. Older manifests use extra settings in the $block_hash to
  # control what is imported, while non-manifest imports use a regular
  # $block_hash (so obeying process_exp and block_exp) [jmt12]
  elsif ($manifest eq '' || $self->{'manifest_version'} == 1)
  {
    &plugin::read ($pluginfo, $importdir, '', $block_hash, $metadata, $processor, $maxdocs, 0, $gli);
  }
  else
  {
    print STDERR "Skipping perform_process_files() due to manifest presence and version\n";
  }
}
# perform_process_files()

# @function generate_statistics()
sub generate_statistics
{
  my $self = shift @_;
  my ($pluginfo) = @_;

  my $inexport_mode = $self->{'mode'};
  my $out           = $self->{'out'};
  my $faillogname   = $self->{'faillogname'};
  my $statsfile     = $self->{'statsfile'};
  my $gli           = $self->{'gli'};

  &gsprintf($out, "\n");
  &gsprintf($out, "*********************************************\n");
  &gsprintf($out, "{$inexport_mode.complete}\n");
  &gsprintf($out, "*********************************************\n");

  &plugin::write_stats($pluginfo, $statsfile, $faillogname, $gli);
}
# generate_statistics()


# @function deinit()
# Close down any file handles that we opened (and hence are responsible for
# closing
sub deinit
{
  my $self = shift(@_);
  close OUT if $self->{'close_out'};
  close FAILLOG if $self->{'close_faillog'};
  close STATSFILE if $self->{'close_statsfile'};
}
# deinit()


sub store_collectionmeta
{
    my ($collectionmeta,$field,$doc_obj) = @_;
    
    my $section = $doc_obj->get_top_section();
    
    my $field_hash = $collectionmeta->{$field};
    
    foreach my $k (keys %$field_hash)
    {
	my $val = $field_hash->{$k};
	
	### print STDERR "*** $k = $field_hash->{$k}\n";
	
	my $md_label = "ex.$field";
	
	
	if ($k =~ m/^\[l=(.*?)\]$/)
	{
	    
	    my $md_suffix = $1;
	    $md_label .= "^$md_suffix";
	}
	
	
	$doc_obj->add_utf8_metadata($section,$md_label, $val);
	
	# see collConfigxml.pm: GS2's "collectionextra" is called "description" in GS3,
	# while "collectionname" in GS2 is called "name" in GS3.
	# Variable $nameMap variable in collConfigxml.pm maps between GS2 and GS3
	if (($md_label eq "ex.collectionname^en") || ($md_label eq "ex.collectionname"))
	{
	    $doc_obj->add_utf8_metadata($section,"dc.Title", $val);
	}
	
    }
}


sub oid_count_file {
    my ($archivedir) = @_;
    return &FileUtils::filenameConcatenate($archivedir, "OIDcount");
}


sub prime_doc_oid_count
{
    my ($archivedir) = @_;
    my $oid_count_filename = &oid_count_file($archivedir);

    if (-e $oid_count_filename) {
	if (open(OIDIN,"<$oid_count_filename")) {
	    my $OIDcount = <OIDIN>;
	    chomp $OIDcount;	    
	    close(OIDIN);

	    $doc::OIDcount = $OIDcount;	    
	}
	else {	    
	    &gsprintf(STDERR, "{import.cannot_read_OIDcount}\n", $oid_count_filename);
	}
    }
    
}

sub store_doc_oid_count
{
    # Use the file "OIDcount" in the archives directory to record
    # what value doc.pm got up to

    my ($archivedir) = @_;
    my $oid_count_filename = &oid_count_file($archivedir);

    # @todo $oidout = &FileUtils::openFileDescriptor($oid_count_filename, 'w') [jmt12]
    if (open(OIDOUT,">$oid_count_filename")) {
	print OIDOUT $doc::OIDcount, "\n";
	    
	close(OIDOUT);
    }
    else {
	&gsprintf(STDERR, "{import.cannot_write_OIDcount}\n", $oid_count_filename);
    }
}



sub new_vs_old_import_diff
{
    my ($archive_info,$block_hash,$importdir,$archivedir,$verbosity,$incremental_mode) = @_;

    # Get the infodbtype value for this collection from the arcinfo object
    my $infodbtype = $archive_info->{'infodbtype'};

    # in this method, we want to know if metadata files are modified or not.
    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archivedir);

    my $archiveinf_timestamp = -M $arcinfo_doc_filename;

    # First convert all files to absolute form
    # This is to support the situation where the import folder is not
    # the default
    
    my $prev_all_files = $archive_info->{'prev_import_filelist'};
    my $full_prev_all_files = {};

    foreach my $prev_file (keys %$prev_all_files) {

	if (!&FileUtils::isFilenameAbsolute($prev_file)) {
	    my $full_prev_file = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},$prev_file);
	    $full_prev_all_files->{$full_prev_file} = $prev_file;
	}
	else {
	    $full_prev_all_files->{$prev_file} = $prev_file;
	}
    }


    # Figure out which are the new files, existing files and so
    # by implication the files from the previous import that are not
    # there any more => mark them for deletion
    foreach my $curr_file (keys %{$block_hash->{'all_files'}}) {
	
	my $full_curr_file = $curr_file;

	# entry in 'all_files' is moved to either 'existing_files', 
	# 'deleted_files', 'new_files', or 'new_or_modified_metadata_files'

	if (!&FileUtils::isFilenameAbsolute($curr_file)) {
	    # add in import dir to make absolute
	    $full_curr_file = &FileUtils::filenameConcatenate($importdir,$curr_file);
	}

	# figure out if new file or not
	if (defined $full_prev_all_files->{$full_curr_file}) {
	    # delete it so that only files that need deleting are left
	    delete $full_prev_all_files->{$full_curr_file};
	    
	    # had it before. is it a metadata file?
	    if ($block_hash->{'metadata_files'}->{$full_curr_file}) {
		
		# is it modified??
		if (-M $full_curr_file < $archiveinf_timestamp) {
		    print STDERR "*** Detected a *modified metadata* file: $full_curr_file\n" if $verbosity >= 2;
		    # its newer than last build
		    $block_hash->{'new_or_modified_metadata_files'}->{$full_curr_file} = 1;
		}
	    }
	    else {
		if ($incremental_mode eq "all") {
		    
		    # had it before
		    $block_hash->{'existing_files'}->{$full_curr_file} = 1;
		    
		}
		else {
		    # Warning in "onlyadd" mode, but had it before!
		    print STDERR "Warning: File $full_curr_file previously imported.\n";
		    print STDERR "         Treating as new file\n";
		    
		    $block_hash->{'new_files'}->{$full_curr_file} = 1;
		    
		}
	    }
	}
	else {
	    if ($block_hash->{'metadata_files'}->{$full_curr_file}) {
		# the new file is the special sort of file greenstone uses
		# to attach metadata to src documents
		# i.e metadata.xml 
		# (but note, the filename used is not constrained in 
		# Greenstone to always be this)

		print STDERR "*** Detected *new* metadata file: $full_curr_file\n" if $verbosity >= 2;
		$block_hash->{'new_or_modified_metadata_files'}->{$full_curr_file} = 1;
	    }
	    else {
		$block_hash->{'new_files'}->{$full_curr_file} = 1;
	    }
	}

	
	delete $block_hash->{'all_files'}->{$curr_file};
    }




    # Deal with complication of new or modified metadata files by forcing
    # everything from this point down in the file hierarchy to
    # be freshly imported.  
    #
    # This may mean files that have not changed are reindexed, but does
    # guarantee by the end of processing all new metadata is correctly
    # associated with the relevant document(s).

    foreach my $new_mdf (keys %{$block_hash->{'new_or_modified_metadata_files'}}) {
	my ($fileroot,$situated_dir,$ext) = fileparse($new_mdf, "\\.[^\\.]+\$");

	$situated_dir =~ s/[\\\/]+$//; # remove tailing slashes
	$situated_dir = &util::filename_to_regex($situated_dir); # need to escape windows slash \ and brackets in regular expression
	
	# Go through existing_files, and mark anything that is contained
	# within 'situated_dir' to be reindexed (in case some of the metadata
	# attaches to one of these files)

	my $reindex_files = [];

	foreach my $existing_f (keys %{$block_hash->{'existing_files'}}) {
	
	    if ($existing_f =~ m/^$situated_dir/) {

#		print STDERR "**** Existing file $existing_f\nis located within\n$situated_dir\n";

		push(@$reindex_files,$existing_f);
		$block_hash->{'reindex_files'}->{$existing_f} = 1;
		delete $block_hash->{'existing_files'}->{$existing_f};

	    }
	}
	
	# metadata file needs to be in new_files list so parsed by MetadataXMLPlug
	# (or equivalent)
	$block_hash->{'new_files'}->{$new_mdf} = 1; 

    }

    # go through remaining existing files and work out what has changed and needs to be reindexed.
    my @existing_files = sort keys %{$block_hash->{'existing_files'}};

    my $reindex_files = [];

    foreach my $existing_filename (@existing_files) {
	if (-M $existing_filename < $archiveinf_timestamp) {
	    # file is newer than last build
	    
	    my $existing_file = $existing_filename;
	    #my $collectdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'});

	    #my $collectdir_resafe = &util::filename_to_regex($collectdir);
	    #$existing_file =~ s/^$collectdir_resafe(\\|\/)?//;
	    
	    print STDERR "**** Reindexing existing file: $existing_file\n";

	    push(@$reindex_files,$existing_file);
	    $block_hash->{'reindex_files'}->{$existing_filename} = 1;
	}

    }

    
    # By this point full_prev_all_files contains the files
    # mentioned in archiveinf-src.db but are not in the 'import'
    # folder (or whatever was specified through -importdir ...)

    # This list can contain files that were created in the 'tmp' or
    # 'cache' areas (such as screen-size and thumbnail images).
    #
    # In building the final list of files to delete, we test to see if
    # it exists on the filesystem and if it does (unusual for a "normal" 
    # file in import, but possible in the case of 'tmp' files), 
    # supress it from going into the final list

    my $collectdir = $ENV{'GSDLCOLLECTDIR'};

    my @deleted_files = values %$full_prev_all_files;
    map { my $curr_file = $_;
	  my $full_curr_file = $curr_file;

	  if (!&FileUtils::isFilenameAbsolute($curr_file)) {
	      # add in import dir to make absolute

	      $full_curr_file = &FileUtils::filenameConcatenate($collectdir,$curr_file);
	  }


	  if (!-e $full_curr_file) {
	      $block_hash->{'deleted_files'}->{$curr_file} = 1;
	  }
      } @deleted_files;



}


# this is used to delete "deleted" docs, and to remove old versions of "changed" docs
# $mode is 'delete' or 'reindex'
sub mark_docs_for_deletion
{
    my ($archive_info,$block_hash,$deleted_files,$archivedir,$verbosity,$mode) = @_;

    my $mode_text = "deleted from index";
    if ($mode eq "reindex") {
	$mode_text = "reindexed";
    }

    # Get the infodbtype value for this collection from the arcinfo object
    my $infodbtype = $archive_info->{'infodbtype'};

    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archivedir);
    my $arcinfo_src_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-src", $archivedir);


    # record files marked for deletion in arcinfo
    foreach my $file (@$deleted_files) {
	# use 'archiveinf-src' info database file to look up all the OIDs
	# that this file is used in (note in most cases, it's just one OID)
	
	my $relfile = &util::abspath_to_placeholders($file);

	my $src_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_src_filename, $relfile);
	my $oids = $src_rec->{'oid'};
	my $file_record_deleted = 0;

	# delete the src record
	my $src_infodb_file_handle = &dbutil::open_infodb_write_handle($infodbtype, $arcinfo_src_filename, "append");
	&dbutil::delete_infodb_entry($infodbtype, $src_infodb_file_handle, $relfile);
	&dbutil::close_infodb_write_handle($infodbtype, $src_infodb_file_handle);


	foreach my $oid (@$oids) {

	    # find the source doc (the primary file that becomes this oid)
	    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $oid);
	    my $doc_source_file = $doc_rec->{'src-file'}->[0];
	    $doc_source_file = &util::placeholders_to_abspath($doc_source_file);

	    if (!&FileUtils::isFilenameAbsolute($doc_source_file)) {
		$doc_source_file = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},$doc_source_file);
	    }

	    if ($doc_source_file ne $file) {
		# its an associated or metadata file
		
		# mark source doc for reimport as one of its assoc files has changed or deleted
		$block_hash->{'reindex_files'}->{$doc_source_file} = 1;
		
	    }
	    my $curr_status = $archive_info->get_status_info($oid);
	    if (defined($curr_status) && (($curr_status ne "D"))) {
		if ($verbosity>1) {
		    print STDERR "$oid ($doc_source_file) marked to be $mode_text on next buildcol.pl\n";
		}
		# mark oid for deletion (it will be deleted or reimported)
		$archive_info->set_status_info($oid,"D");
		my $val = &dbutil::read_infodb_rawentry($infodbtype, $arcinfo_doc_filename, $oid);
		$val =~ s/^<index-status>(.*)$/<index-status>D/m;

		my $val_rec = &dbutil::convert_infodb_string_to_hash($infodbtype,$val);
		my $doc_infodb_file_handle = &dbutil::open_infodb_write_handle($infodbtype, $arcinfo_doc_filename, "append");

		&dbutil::write_infodb_entry($infodbtype, $doc_infodb_file_handle, $oid, $val_rec);
		&dbutil::close_infodb_write_handle($infodbtype, $doc_infodb_file_handle);
	    }
	}
	
    }

    # now go through and check that we haven't marked any primary
    # files for reindex (because their associated files have
    # changed/deleted) when they have been deleted themselves. only in
    # delete mode.

    if ($mode eq "delete") {
	foreach my $file (@$deleted_files) {
	    if (defined $block_hash->{'reindex_files'}->{$file}) {
		delete $block_hash->{'reindex_files'}->{$file};
	    }
	}
    }


}

sub add_dir_contents_to_list {

    my ($dirname, $list) = @_;
 
    # Recur over directory contents.
    my (@dir, $subfile);
    
    # find all the files in the directory
    if (!opendir (DIR, $dirname)) {
	print STDERR "inexport: WARNING - couldn't read directory $dirname\n";
	return -1; # error in processing
    }
    @dir = readdir (DIR);
    closedir (DIR);
    
    for (my $i = 0; $i < scalar(@dir); $i++) {
	my $subfile = $dir[$i];
	next if ($subfile =~ m/^\.\.?$/);
	next if ($subfile =~ /^\.svn$/);
	my $full_file = &FileUtils::filenameConcatenate($dirname, $subfile);
	if (-d $full_file) {
	    &add_dir_contents_to_list($full_file, $list);
	} else {
	    push (@$list, $full_file);
	}
    }
	
}

    
1;
