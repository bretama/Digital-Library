###########################################################################
#
# basebuilder.pm -- base class for collection builders
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

package basebuilder;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use arcinfo;
use classify;
use cfgread;
use colcfg;
use dbutil;
use oaiinfo;
use plugin;
use util;
use FileUtils;


BEGIN {
    # set autoflush on for STDERR and STDOUT so that mgpp
    # doesn't get out of sync with plugins
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
}

END {
    STDOUT->autoflush(0);
    STDERR->autoflush(0);
}

our $maxdocsize = 12000;

# used to signify "gs2"(default) or "gs3"
our $gs_mode = "gs2";

sub new {
    my ($class, $site, $collection, $source_dir, $build_dir, $verbosity, 
	$maxdocs, $debug, $keepold, $incremental, $incremental_mode,
	$remove_empty_classifications, 
	$outhandle, $no_text, $failhandle, $gli) = @_;

    $outhandle = *STDERR unless defined $outhandle;
    $no_text = 0 unless defined $no_text;
    $failhandle = *STDERR unless defined $failhandle;

    # create a builder object
    my $self = bless {'site'=>$site, # will be undef for Greenstone 2
		      'collection'=>$collection,
		      'source_dir'=>$source_dir,
		      'build_dir'=>$build_dir,
		      'verbosity'=>$verbosity,
		      'maxdocs'=>$maxdocs,
		      'debug'=>$debug,
		      'keepold'=>$keepold,
		      'incremental'=>$incremental,
		      'incremental_mode'=>$incremental_mode,
		      'remove_empty_classifications'=>$remove_empty_classifications,
		      'outhandle'=>$outhandle,
		      'no_text'=>$no_text,
		      'failhandle'=>$failhandle,
		      'notbuilt'=>{},    # indexes not built
		      'gli'=>$gli
		      }, $class;

    $self->{'gli'} = 0 unless defined $self->{'gli'};
    
    # Read in the collection configuration file.
    if ((defined $site) && ($site ne "")) { # GS3
	$gs_mode = "gs3";
    }

    my $colcfgname = &colcfg::get_collect_cfg_name($outhandle, $gs_mode);
    $self->{'colcfgname'} = $colcfgname;
    $self->{'collect_cfg'} = &colcfg::read_collection_cfg ($colcfgname, $gs_mode);

    if ($gs_mode eq "gs3") {
	# read it in again to save the original form for later writing out
	# of buildConfig.xml
	# we use this preserve object because $self->{'collect_cfg'}->{'classify'} somewhat gets modified during the calling of &classify::load_classifiers.
	$self->{'collect_cfg_preserve'} = &colcfg::read_collection_cfg ($colcfgname, $gs_mode);	
    }
    
    # get the database type for this collection from the collect.cfg file (may be undefined)
    $self->{'infodbtype'} = $self->{'collect_cfg'}->{'infodbtype'} || &dbutil::get_default_infodb_type();


    # load up any dontdb fields
    $self->{'dontdb'} = {};
    if (defined ($self->{'collect_cfg'}->{'dontgdbm'})) {
	foreach my $dg (@{$self->{'collect_cfg'}->{'dontgdbm'}}) {
	    $self->{'dontdb'}->{$dg} = 1;
	}
    }

    $self->{'maxnumeric'} = 4;
    return $self;
}

# stuff has been moved here from new, so we can use subclass methods
sub init {
    my $self = shift(@_);
    
    my $outhandle = $self->{'outhandle'};
    my $failhandle = $self->{'failhandle'};

    $self->generate_index_list();
    my $indexes = $self->{'collect_cfg'}->{'indexes'};
    if (defined $indexes) {
	# sort out subcollection indexes
	if (defined $self->{'collect_cfg'}->{'indexsubcollections'}) {
	    $self->{'collect_cfg'}->{'indexes'} = [];
	    foreach my $subcollection (@{$self->{'collect_cfg'}->{'indexsubcollections'}}) {
		foreach my $index (@$indexes) {
		    push (@{$self->{'collect_cfg'}->{'indexes'}}, "$index:$subcollection");
		}
	    }
	}
	
	# sort out language subindexes
	if (defined $self->{'collect_cfg'}->{'languages'}) {
	    $indexes = $self->{'collect_cfg'}->{'indexes'};
	    $self->{'collect_cfg'}->{'indexes'} = [];
	    foreach my $language (@{$self->{'collect_cfg'}->{'languages'}}) {
		foreach my $index (@$indexes) {
		    if (defined ($self->{'collect_cfg'}->{'indexsubcollections'})) {
			push (@{$self->{'collect_cfg'}->{'indexes'}}, "$index:$language");
		    }
		    else { # add in an empty subcollection field
			push (@{$self->{'collect_cfg'}->{'indexes'}}, "$index\:\:$language");
		    }
		}
	    }
	}
    }
    
    if (defined($self->{'collect_cfg'}->{'indexes'})) {
	# make sure that the same index isn't specified more than once
	my %tmphash = ();
	my @tmparray = @{$self->{'collect_cfg'}->{'indexes'}};
	$self->{'collect_cfg'}->{'indexes'} = [];
	foreach my $i (@tmparray) {
	    if (!defined ($tmphash{$i})) {
		push (@{$self->{'collect_cfg'}->{'indexes'}}, $i);
		$tmphash{$i} = 1;
	    }
	}
    } else {
	$self->{'collect_cfg'}->{'indexes'} = [];
    }


    # Prepare to work with the <collection>/etc/oai-inf.<db> that keeps track
    # of the OAI identifiers with their time stamps and deleted status.
    #
    # At this stage of working with the oai info db, we don't care whether we have a
    # manifest or are otherwise incremental, or whether we're doing removeold (full rebuild).
    # Because we've already dealt with that during the import stage. From here on, we pretend
    # we're incremental, since the oai info db should just do what archiveinfo contains.
    # This is because "building is always incremental" where oai info db is concerned.
    
    my $archivedir = $self->{'source_dir'};
    my $oai_info = new oaiinfo($self->{'colcfgname'}, $self->{'collect_cfg'}->{'infodbtype'}, $self->{'verbosity'});    
    $oai_info->building_stage_before_indexing($archivedir);


    # check incremental against whether builder can cope or not.
    if ($self->{'incremental'} && !$self->is_incremental_capable()) {
	print $outhandle "WARNING: The indexer used is not capable of incremental building. Reverting to -removeold\n";
	$self->{'keepold'} = 0;
	$self->{'incremental'} = 0;
	$self->{'incremental_mode'} = "none";
    
    }

    # gs_version for plugins
    my $gs_version = "2";
    if ($gs_mode eq "gs3") {
	$gs_version = "3";
    }
    # get the list of plugins for this collection
    my $plugins = [];
    if (defined $self->{'collect_cfg'}->{'plugin'}) {
	$plugins = $self->{'collect_cfg'}->{'plugin'};
    }
    
    # load all the plugins

    #build up the extra global options for the plugins
    my @global_opts = ();
    if (defined $self->{'collect_cfg'}->{'separate_cjk'} && $self->{'collect_cfg'}->{'separate_cjk'} =~ /^true$/i) {
	push @global_opts, "-separate_cjk";
    }
    $self->{'pluginfo'} = &plugin::load_plugins ($plugins, $self->{'verbosity'}, $outhandle, $failhandle, \@global_opts, $self->{'incremental_mode'}, $gs_version);
   
    if (scalar(@{$self->{'pluginfo'}}) == 0) {
	print $outhandle "No plugins were loaded.\n";
	die "\n";
    }

    # get the list of classifiers for this collection
    my $classifiers = [];
    if (defined $self->{'collect_cfg'}->{'classify'}) {
	$classifiers = $self->{'collect_cfg'}->{'classify'};
    }

    # load all the classifiers
    $self->{'classifiers'} = &classify::load_classifiers ($classifiers, $self->{'build_dir'}, $outhandle);

    # load up the document processor for building
    # if a buildproc class has been created for this collection, use it
    # otherwise, use the default buildproc for the builder we are initialising
    my $buildprocdir = undef;
    my $buildproctype;

    my $collection = $self->{'collection'};
    if (-e "$ENV{'GSDLCOLLECTDIR'}/custom/${collection}/perllib/custombuildproc.pm") {
	$buildprocdir = "$ENV{'GSDLCOLLECTDIR'}/custom/${collection}/perllib";
	$buildproctype = "custombuildproc";
    } elsif (-e "$ENV{'GSDLCOLLECTDIR'}/perllib/custombuildproc.pm") {
	$buildprocdir = "$ENV{'GSDLCOLLECTDIR'}/perllib";
	$buildproctype = "custombuildproc";
    } elsif (-e "$ENV{'GSDLCOLLECTDIR'}/perllib/${collection}buildproc.pm") {
	$buildprocdir = "$ENV{'GSDLCOLLECTDIR'}/perllib";
	$buildproctype = "${collection}buildproc";
    } else {
	$buildproctype = $self->default_buildproc();
    }
    if (defined $buildprocdir) {
	require "$buildprocdir/$buildproctype.pm";
    }
    else {
	require "$buildproctype.pm";
    }

    eval("\$self->{'buildproc'} = new $buildproctype(\$self->{'collection'}, " .
	 "\$self->{'source_dir'}, \$self->{'build_dir'}, \$self->{'keepold'}, \$self->{'verbosity'}, \$self->{'outhandle'})");
    die "$@" if $@;

    # We call set_infodbtype() now so the buildproc knows the infodbtype for all phases of the build
    $self->{'buildproc'}->set_infodbtype($self->{'infodbtype'});
    
   $self->generate_index_options();

    if (!$self->{'debug'} && !$self->{'keepold'}) {
	# remove any old builds
	&FileUtils::removeFilesRecursive($self->{'build_dir'});
	&FileUtils::makeAllDirectories($self->{'build_dir'});
        
	# make the text directory
	my $textdir = "$self->{'build_dir'}/text";
	&FileUtils::makeAllDirectories($textdir);
    }

    if ($self->{'incremental'}) {
	# some classes may need to do some additional initialisation
	$self->init_for_incremental_build();
    }
    
}

sub is_incremental_capable
{
    # By default we return 'no' as the answer
    # Safer to assume non-incremental to start with, and then override in
    # inherited classes that are.

    return 0;
}

# implement this in subclass if want to do additional initialisation for an
# incremental build
sub init_for_incremental_build {
    my $self = shift (@_);
}

sub deinit {
    my $self = shift (@_);
    
    &plugin::deinit($self->{'pluginfo'},$self->{'buildproc'});
}

sub generate_index_options {
    my $self = shift (@_);

    my $separate_cjk = 0;

    my $indexoptions = $self->{'collect_cfg'}->{'indexoptions'};    
    if (defined($indexoptions)) {

	foreach my $option (@$indexoptions) {
	    if ($option =~ /separate_cjk/) {
		$separate_cjk = 1;
	    }
	}
    }
    # set this for building
    $self->{'buildproc'}->set_separate_cjk($separate_cjk);
    # record it for build.cfg
    $self->{'separate_cjk'} = $separate_cjk;
}
 
sub set_sections_index_document_metadata {
    my $self = shift (@_);
    my ($index) = @_;
  
    $self->{'buildproc'}->set_sections_index_document_metadata($index);
}

sub set_maxnumeric {
    my $self = shift (@_);
    my ($maxnumeric) = @_;

    $self->{'maxnumeric'} = $maxnumeric;
}
sub set_strip_html {
    my $self = shift (@_);
    my ($strip) = @_;
    
    $self->{'strip_html'} = $strip;
    $self->{'buildproc'}->set_strip_html($strip);
}

sub set_store_metadata_coverage {
    my $self = shift (@_);
    my ($store_metadata_coverage) = @_;
    
    $self->{'buildproc'}->set_store_metadata_coverage($store_metadata_coverage);
}

sub compress_text {
    my $self = shift (@_);
    my ($textindex) = @_;

    print STDERR "compress_text() should be implemented in subclass!!";
    return;
}


sub build_indexes {
    my $self = shift (@_);
    my ($indexname) = @_;
    my $outhandle = $self->{'outhandle'};

    $self->pre_build_indexes();

    my $indexes = [];
    if (defined $indexname && $indexname =~ /\w/) {
	push @$indexes, $indexname;
    } else {
	$indexes = $self->{'collect_cfg'}->{'indexes'};
    }

    # create the mapping between the index descriptions 
    # and their directory names (includes subcolls and langs)
    $self->{'index_mapping'} = $self->create_index_mapping ($indexes);
   
    # build each of the indexes
    foreach my $index (@$indexes) {
	if ($self->want_built($index)) {
	    print $outhandle "\n*** building index $index in subdirectory " . 
		"$self->{'index_mapping'}->{$index}\n" if ($self->{'verbosity'} >= 1);
	    print STDERR "<Stage name='Index' source='$index'>\n" if $self->{'gli'};
	    $self->build_index($index);
	} else {
	    print $outhandle "\n*** ignoring index $index\n" if ($self->{'verbosity'} >= 1);
	}
    }

    $self->post_build_indexes();

}

# implement this in subclass if want to do extra stuff at before building
# all the indexes
sub pre_build_indexes {
    my $self = shift(@_);
    my ($indexname) = @_; # optional parameter
}

# implement this in subclass if want to do extra stuff at the end of building
# all the indexes
sub post_build_indexes {
    my $self = shift(@_);   
}

sub build_index {
    my $self = shift (@_);
    my ($index) = @_;
    
    print STDERR "build_index should be implemented in subclass\n";
    return;
}

# By default, builders do support make_infodatabase()
sub supports_make_infodatabase {
    return 1;
}


sub make_infodatabase {
    my $self = shift (@_);
    my $outhandle = $self->{'outhandle'};

    print STDERR "BuildDir: $self->{'build_dir'}\n";

    my $textdir = &FileUtils::filenameConcatenate($self->{'build_dir'}, "text");
    my $assocdir = &FileUtils::filenameConcatenate($self->{'build_dir'}, "assoc");
    &FileUtils::makeAllDirectories ($textdir);
    &FileUtils::makeAllDirectories ($assocdir);

    # Get info database file path
    my $infodb_type = $self->{'infodbtype'};
    my $infodb_file_path = &dbutil::get_infodb_file_path($infodb_type, $self->{'collection'}, $textdir);

    print $outhandle "\n*** creating the info database and processing associated files\n" 
	if ($self->{'verbosity'} >= 1);
    print STDERR "<Stage name='CreateInfoData'>\n" if $self->{'gli'};

    # init all the classifiers
    &classify::init_classifiers ($self->{'classifiers'});

    my $reconstructed_docs = undef;
    my $database_recs = undef;

    if ($self->{'incremental'}) {
	$database_recs = {};

	&dbutil::read_infodb_file($infodb_type, $infodb_file_path, $database_recs);
    }

    
    # Important (for memory usage reasons) that we obtain the filehandle
    # here for writing out to the database, rather than after 
    # $reconstructed_docs has been set up (assuming -incremental is on)
    #
    # This is because when we open a pipe to txt2db [using open()]
    # this triggers a fork() followed by exec().  $reconstructed_docs
    # can get very large, and so if we did the open() after this, it means
    # the fork creates a clone of the *large* process image which (admittedly)
    # is then quickly replaced in the execve() with the much smaller image for 
    # 'txt2db'.  The trouble is, in that seismic second caused by
    # the fork(), the system really does need to have all that memory available
    # even though it isn't ultimately used.  The result is an out of memory
    # error.

    my ($infodb_handle);
    if ($self->{'debug'}) {
	$infodb_handle = *STDOUT;
    }
    else {
	$infodb_handle = &dbutil::open_infodb_write_handle($infodb_type, $infodb_file_path);
	if (!defined($infodb_handle))
	{
	    print STDERR "<FatalError name='NoRunText2DB'/>\n</Stage>\n" if $self->{'gli'};
	    die "builder::make_infodatabase - couldn't open infodb write handle\n";
	}
    }

    if ($self->{'incremental'}) {
	# reconstruct doc_obj metadata from database for all docs
	$reconstructed_docs 
	    = &classify::reconstruct_doc_objs_metadata($infodb_type, 
						       $infodb_file_path,
						       $database_recs);
    }

    # set up the document processor

    $self->{'buildproc'}->set_output_handle ($infodb_handle);
    $self->{'buildproc'}->set_mode ('infodb');
    $self->{'buildproc'}->set_assocdir ($assocdir);
    $self->{'buildproc'}->set_dontdb ($self->{'dontdb'});
    $self->{'buildproc'}->set_classifiers ($self->{'classifiers'});
    $self->{'buildproc'}->set_indexing_text (0);
    $self->{'buildproc'}->set_store_text(1);

    # make_infodatabase needs full reset even for incremental build
    # as incremental works by reconstructing all docs from the database and
    # then adding in the new ones
    $self->{'buildproc'}->zero_reset(); 

    $self->{'buildproc'}->{'mdprefix_fields'} = {};
   
    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'},0, $self->{'gli'});

    if ($self->{'incremental'}) {
	# create flat classify structure, ready for new docs to be added
	foreach my $doc_obj ( @$reconstructed_docs ) {
	    if (! defined $self->{'buildproc'}->{'dont_process_reconstructed'}->{$doc_obj->get_OID()}) {
		print $outhandle "  Adding reconstructed ", $doc_obj->get_OID(), " into classify structures\n";
		$self->{'buildproc'}->process($doc_obj,undef);
	    } 
	}
    }
    # this has changed to only output collection meta if its 
    # not in the config file
    $self->output_collection_meta($infodb_handle);
    
    # output classification information
    &classify::output_classify_info ($self->{'classifiers'}, $infodb_type, $infodb_handle,
				     $self->{'remove_empty_classifications'}, 
				     $self->{'gli'});

    # Output classifier reverse lookup, used in incremental deletion
    ####&classify::print_reverse_lookup($infodb_handle);

    # output doclist
    my @doc_list = $self->{'buildproc'}->get_doc_list();
    my $browselist_infodb = { 'hastxt' => [ "0" ],
			      'childtype' => [ "VList" ],
			      'numleafdocs' => [ scalar(@doc_list) ],
			      'thistype' => [ "Invisible" ],
			      'contains' => [ join(";", @doc_list) ] };
    &dbutil::write_infodb_entry($infodb_type, $infodb_handle, "browselist", $browselist_infodb);

    &dbutil::close_infodb_write_handle($infodb_type, $infodb_handle) if !$self->{'debug'};
    
    if ($infodb_type eq "gdbm-txtgz") {
	my $gdb_infodb_file_path = &dbutil::get_infodb_file_path("gdbm", $self->{'collection'}, $textdir);
	if (-e $gdb_infodb_file_path) {
	    &FileUtils::removeFiles($gdb_infodb_file_path);
	}
    }
    print STDERR "</Stage>\n" if $self->{'gli'};
}

sub make_auxiliary_files {
    my $self = shift (@_);
    my ($index);
    my $build_cfg = {};
    # subclasses may have already defined stuff in here
    if (defined $self->{'build_cfg'}) {
	$build_cfg = $self->{'build_cfg'};
    }

    my $outhandle = $self->{'outhandle'};

    print $outhandle "\n*** creating auxiliary files \n" if ($self->{'verbosity'} >= 1);
    print STDERR "<Stage name='CreatingAuxilary'>\n" if $self->{'gli'};

    # get the text directory
    &FileUtils::makeAllDirectories ($self->{'build_dir'});

    # store the build date
    $build_cfg->{'builddate'} = time;
    $build_cfg->{'buildtype'} = $self->{'buildtype'};
    $build_cfg->{'indexstem'} = &util::get_dirsep_tail($self->{'collection'});
    $build_cfg->{'stemindexes'} = $self->{'stemindexes'};
    if ($self->{'separate_cjk'}) {
	$build_cfg->{'separate_cjk'} = "true";
    }
    
    # store the number of documents and number of bytes
    $build_cfg->{'numdocs'} = $self->{'buildproc'}->get_num_docs();
    $build_cfg->{'numsections'} = $self->{'buildproc'}->get_num_sections();
    $build_cfg->{'numbytes'} = $self->{'buildproc'}->get_num_bytes();

    # store the mapping between the index names and the directory names
    # the index map is used to determine what indexes there are, so any that are not built should not be put into the map.
    my @indexmap = ();
    foreach my $index (@{$self->{'index_mapping'}->{'indexmaporder'}}) {
	if (not defined ($self->{'notbuilt'}->{$index})) {
	    push (@indexmap, "$index\-\>$self->{'index_mapping'}->{'indexmap'}->{$index}");
	}
    }
	
	# store the number of indexes built to later determine whether search serviceracks get written out to buildConfig.xml
	$build_cfg->{'num_indexes'} = scalar (@indexmap);	
	
    $build_cfg->{'indexmap'} = \@indexmap if scalar (@indexmap);

    my @subcollectionmap = ();
    foreach my $subcollection (@{$self->{'index_mapping'}->{'subcollectionmaporder'}}) {
	push (@subcollectionmap, "$subcollection\-\>" .
	      $self->{'index_mapping'}->{'subcollectionmap'}->{$subcollection});
    }
    $build_cfg->{'subcollectionmap'} = \@subcollectionmap if scalar (@subcollectionmap);

    my @languagemap = ();
    foreach my $language (@{$self->{'index_mapping'}->{'languagemaporder'}}) {
	push (@languagemap, "$language\-\>" .
	      $self->{'index_mapping'}->{'languagemap'}->{$language});
    }
    $build_cfg->{'languagemap'} = \@languagemap if scalar (@languagemap);

    my @notbuilt = ();
    foreach my $nb (keys %{$self->{'notbuilt'}}) {
	push (@notbuilt, $nb);
    }
    $build_cfg->{'notbuilt'} = \@notbuilt if scalar (@notbuilt);

    $build_cfg->{'maxnumeric'} = $self->{'maxnumeric'};

    $build_cfg->{'infodbtype'} = $self->{'infodbtype'};
    
    # write out the earliestDatestamp information needed for OAI
    my $archivedir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "archives");
    if(!-d $archivedir) {
	$archivedir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "export");
    }
    my $earliestDatestampFile = &FileUtils::filenameConcatenate($archivedir, "earliestDatestamp");
    my $earliestDatestamp = 0;
    if (open(FIN,"<$earliestDatestampFile")) {
	{
	    # slurp in file as a single line
	    local $/ = undef;
	    $earliestDatestamp = <FIN>;
	    #&unicode::ensure_utf8(\$earliestDatestamp); # turn any high bytes that aren't valid utf-8 into utf-8.
	}
	close(FIN);
    }
    else {
	print $outhandle "Warning: unable to read collection's earliestDatestamp from $earliestDatestampFile.\n";
	print $outhandle "Setting value to 0.\n";
    }
    $build_cfg->{'earliestdatestamp'} = $earliestDatestamp;
    
    $self->build_cfg_extra($build_cfg);

    if ($gs_mode eq "gs2") {
      &colcfg::write_build_cfg(&FileUtils::filenameConcatenate($self->{'build_dir'},"build.cfg"), $build_cfg);
    }
    if ($gs_mode eq "gs3") {

      &colcfg::write_build_cfg_xml(&FileUtils::filenameConcatenate($self->{'build_dir'}, "buildConfig.xml"), $build_cfg, $self->{'collect_cfg_preserve'});
    }    

    print STDERR "</Stage>\n" if $self->{'gli'};
}

# implement this in subclass if want to add extra stuff to build.cfg
sub build_cfg_extra {
   my $self = shift(@_);
   my ($build_cfg) = @_;
   
}


sub collect_specific {
    my $self = shift (@_);
}

sub want_built {
    my $self = shift (@_);
    my ($index) = @_;

    if (defined ($self->{'collect_cfg'}->{'dontbuild'})) {
	foreach my $checkstr (@{$self->{'collect_cfg'}->{'dontbuild'}}) {
	    if ($index =~ /^$checkstr$/) {
		$self->{'notbuilt'}->{$index} = 1;
		return 0;
	    }
	}
    }

    return 1;
}

sub create_index_mapping {
    my $self = shift (@_);
    my ($indexes) = @_;

    print STDERR "create_index_mapping should be implemented in subclass\n";
    my %mapping = ();
    return \%mapping;
}

# returns a processed version of a field.
# if the field has only one component the processed
# version will contain the first character and next consonant
# of that componant - otherwise it will contain the first 
# character of the first two components 
# only uses letdig (\w) characters now
sub process_field {
    my $self = shift (@_);
    my ($field) = @_;

    return "" unless (defined ($field) && $field =~ /\S/);
    
    my ($a, $b);
    my @components = split /,/, $field;
    if (scalar @components >= 2) {
	# pick the first letdig from the first two field names
	($a) = $components[0] =~ /^[^\w]*(\w)/;
	($b) = $components[1] =~ /^[^\w]*(\w)/;
    } else {
	# pick the first two letdig chars
	($a, $b) = $field =~ /^[^\w]*(\w)[^\w]*?(\w)/i;
    }
    # there may not have been any letdigs...
    $a = 'a' unless defined $a;
    $b = '0' unless defined $b;
    
    my $newfield = "$a$b";
    if ($newfield =~ /^\d\d$/) {
	# digits only - Greenstone runtime doesn't like this.
	$newfield = "a$a";
    }
    return $newfield;
    
}

sub get_next_version {
    my $self = shift (@_);
    my ($nameref) = @_;
    my $num=0;
    if ($$nameref =~ /(\d\d)$/) {
	$num = $1; $num ++;
	$$nameref =~ s/\d\d$/$num/;
    } elsif ($$nameref =~ /(\d)$/) {
	$num = $1;
	if ($num == 9) {$$nameref =~ s/\d$/10/;}
	else {$num ++; $$nameref =~ s/\d$/$num/;}
    } else {
	$$nameref =~ s/.$/0/;
    }
}



sub get_collection_meta_sets
{
    my $self = shift(@_);
    my $collection_infodb = shift(@_);

    my $mdprefix_fields = $self->{'buildproc'}->{'mdprefix_fields'};
    foreach my $prefix (keys %$mdprefix_fields)
    {	
	push(@{$collection_infodb->{"metadataset"}}, $prefix);

	foreach my $field (keys %{$mdprefix_fields->{$prefix}})
	{
	    push(@{$collection_infodb->{"metadatalist-$prefix"}}, $field);

	    my $val = $mdprefix_fields->{$prefix}->{$field};
	    push(@{$collection_infodb->{"metadatafreq-$prefix-$field"}}, $val);
	}
    }
}


# default is to output the metadata sets (prefixes) used in collection
sub output_collection_meta
{
    my $self = shift(@_);
    my $infodb_handle = shift(@_);

    my %collection_infodb = ();
    $self->get_collection_meta_sets(\%collection_infodb);
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, "collection", \%collection_infodb);
}

# sometimes we need to read in an existing build.cfg - for example, 
# if doing each stage of building separately, or when doing incremental 
# building
sub read_build_cfg {
    my $self = shift(@_);

    my $buildconfigfilename;
    
    if ($gs_mode eq "gs2") {
	$buildconfigfilename = "build.cfg";
    } else {
	$buildconfigfilename = "buildConfig.xml";
    }
    
    my $buildconfigfile = &FileUtils::filenameConcatenate($self->{'build_dir'}, $buildconfigfilename);
    
    if (!-e $buildconfigfile) {
	# try the index dir - but do we know where it is?? try here
	$buildconfigfile  = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "index", $buildconfigfilename);
	if (!-e $buildconfigfile) {
	    #we cant find a config file - just ignore the field list
	    return undef;
	}
    } 
    return &colcfg::read_building_cfg( $buildconfigfile, $gs_mode);
    
}

sub print_stats {
    my $self = shift (@_);

    my $outhandle = $self->{'outhandle'};
    my $indexing_text = $self->{'buildproc'}->get_indexing_text();
    my $index = $self->{'buildproc'}->get_index();
    my $num_bytes = $self->{'buildproc'}->get_num_bytes();
    my $num_processed_bytes = $self->{'buildproc'}->get_num_processed_bytes();

    if ($indexing_text) {
	print $outhandle "Stats (Creating index $index)\n";
    } else {
	print $outhandle "Stats (Compressing text from $index)\n";
    }
    print $outhandle "Total bytes in collection: $num_bytes\n";
    print $outhandle "Total bytes in $index: $num_processed_bytes\n";

    if ($num_processed_bytes < 50 && ($indexing_text || !$self->{'no_text'})) {
	
	if ($self->{'incremental'}) {
	    if ($num_processed_bytes == 0) {
		if ($indexing_text) {
		    print $outhandle "No additional text was added to $index\n";
		} elsif (!$self->{'no_text'}) {
		    print $outhandle "No additional text was compressed\n";
		}	
	    }	
	}
	else {
	    print $outhandle "***************\n";
	    if ($indexing_text) {
		print $outhandle "WARNING: There is very little or no text to process for $index\n";
	    } elsif (!$self->{'no_text'}) {
		print $outhandle "WARNING: There is very little or no text to compress\n";
	    }	   
	    print $outhandle "         Was this your intention?\n";
	    print $outhandle "***************\n";
	}

    }

}

  
1;

