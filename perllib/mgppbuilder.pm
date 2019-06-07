###########################################################################
#
# mgppbuilder.pm -- MGBuilder object
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

package mgppbuilder;

use basebuilder;
use colcfg;
use plugin;
use strict; no strict 'refs';
use util;
use FileUtils;


sub BEGIN {
    @mgppbuilder::ISA = ('basebuilder');
}


$SIG{PIPE} = sub {
    print "got SIGPIPE\n";
    die "$0: Error: $!";
};


our %level_map = ('document'=>'Doc',
	      'section'=>'Sec',
	      'paragraph'=>'Para',
	      'Doc'=>'_textdocument_',
	      'Sec'=>'_textsection_',
	      'Para'=>'_textparagraph_');

our %wanted_index_files = ('td'=>1,
		       't'=>1,
		       'tl'=>1,
		       'ti'=>1,
		       'idb'=>1,
		       'ib1'=>1,
		       'ib2'=>1,
		       'ib3'=>1,
		       'ib4'=>1,
		       'ib5'=>1,
		       'ib6'=>1,
		       'ib7'=>1,
		       'i'=>1,
		       'il'=>1,
		       'w'=>1,
		       'wa'=>1);


my $maxdocsize = $basebuilder::maxdocsize;

sub new {
    my $class = shift(@_);

    my $self = new basebuilder (@_);
    $self = bless $self, $class;

    #$self->{'indexfieldmap'} = \%static_indexfield_map;

    # get the levels (Section, Paragraph) for indexing and compression
    $self->{'levels'} = {};
    $self->{'levelorder'} = ();
    if (defined $self->{'collect_cfg'}->{'levels'}) {
        foreach my $level ( @{$self->{'collect_cfg'}->{'levels'}} ){
	    $level =~ tr/A-Z/a-z/;
            $self->{'levels'}->{$level} = 1;
	    push (@{$self->{'levelorder'}}, $level);
        }
    } else { # default to document
	$self->{'levels'}->{'document'} = 1;
	push (@{$self->{'levelorder'}}, 'document');
    }
    
    $self->{'buildtype'} = "mgpp";

    return $self;
}

sub generate_index_list {
    my $self  = shift (@_);
    
    # sort out the indexes
    #indexes are specified with spaces, but we put them into one index
    my $indexes = $self->{'collect_cfg'}->{'indexes'};
    if (defined $indexes) {
	$self->{'collect_cfg'}->{'indexes'} = [];

	# remove any ex. from index spec but iff it is the only namespace in the metadata name
	my @indexes_copy = @$indexes; # make a copy, as 'map' changes entry in array
	#map { $_ =~ s/(^|,|;)ex\.([^.]+)$/$1$2/; } @indexes_copy; # No. Will replace metanames like flex.Image with fl.Image
	map { $_ =~ s/(,|;)/$1 /g; } @indexes_copy; # introduce a space after every separator
	map { $_ =~ s/(^| )ex\.([^.,:]+)(,|;|$)/$1$2$3/g; } @indexes_copy; # replace all <ex.> at start of metanames or <, ex.> when in a comma separated list
	map { $_ =~ s/(,|:) /$1/g; } @indexes_copy; # remove space introduced after every separator
	my $single_index = join(';', @indexes_copy).";";

	push (@{$self->{'collect_cfg'}->{'indexes'}}, $single_index);
    }
}

sub generate_index_options {
    my $self = shift (@_);

    $self->SUPER::generate_index_options();

    $self->{'casefold'} = 0;
    $self->{'stem'} = 0;
    $self->{'accentfold'} = 0; 
    
    if (defined($self->{'collect_cfg'}->{'indexoptions'})) {
	foreach my $option (@{$self->{'collect_cfg'}->{'indexoptions'}}) {
	    if ($option =~ /stem/) {
		$self->{'stem'} = 1;
	    } elsif ($option =~ /casefold/) {
		$self->{'casefold'} = 1;
	    } elsif ($option =~ /accentfold/) {
		$self->{'accentfold'} = 1;
	    }
	}
    }
    
    # now we record this for the build cfg
    $self->{'stemindexes'} = 0;
    if ($self->{'casefold'}) {
	$self->{'stemindexes'} += 1;
    }
    if ($self->{'stem'}) {
	$self->{'stemindexes'} += 2;
    }
    if ($self->{'accentfold'}) {
	$self->{'stemindexes'} += 4;
    }
    
}

sub default_buildproc {
    my $self  = shift (@_);

    return "mgppbuildproc";
}

sub compress_text {

    my $self = shift (@_);

    # we don't do anything if we don't want compressed text
    return if $self->{'no_text'};
    
    my ($textindex) = @_;

    my $exedir = "$ENV{'GSDLHOME'}/bin/$ENV{'GSDLOS'}";
    my $exe = &util::get_os_exe ();
    my $mgpp_passes_exe = &FileUtils::filenameConcatenate($exedir, "mgpp_passes$exe");
    my $mgpp_compression_dict_exe = &FileUtils::filenameConcatenate($exedir, "mgpp_compression_dict$exe");
    my $outhandle = $self->{'outhandle'};

    my $maxnumeric = $self->{'maxnumeric'};
    
    &FileUtils::makeAllDirectories (&FileUtils::filenameConcatenate($self->{'build_dir'}, "text"));

    my $collect_tail = &util::get_dirsep_tail($self->{'collection'});
    my $basefilename = &FileUtils::filenameConcatenate("text",$collect_tail);
    my $fulltextprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, $basefilename);
    
    my $osextra = "";
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$fulltextprefix =~ s@/@\\@g;
    } 
    else {
	$osextra = " -d /";
    }


    # define the section names and possibly the doc name for mgpasses
    # the compressor doesn't need to know about paragraphs - never want to 
    # retrieve them
    
    # always use Doc and Sec levels
    my $mgpp_passes_sections = "-J ". $level_map{"document"} ." -K " . $level_map{"section"} ." ";

    print $outhandle "\n*** creating the compressed text\n" if ($self->{'verbosity'} >= 1);
    print STDERR "<Stage name='CompressText'>\n" if $self->{'gli'};

    # collect the statistics for the text
    # -b $maxdocsize sets the maximum document size to be 12 meg
    print $outhandle "\n    collecting text statistics (mgpp_passes -T1)\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CollectTextStats'/>\n" if $self->{'gli'};

    my ($handle);
    if ($self->{'debug'}) {
	$handle = *STDOUT;
    }
    else {
	my $mgpp_passes_cmd = "mgpp_passes$exe  -M $maxnumeric $mgpp_passes_sections -f \"$fulltextprefix\" -T1 $osextra";
	print $outhandle "\ncmd: $mgpp_passes_cmd\n"  if ($self->{'verbosity'} >= 4);
	if (!-e "$mgpp_passes_exe" || !open($handle, "| $mgpp_passes_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::compress_text - couldn't run $mgpp_passes_exe\n";
	}
    }
    
    my $db_level = "section";

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->set_mode ('text');
    $self->{'buildproc'}->set_index ($textindex);
    $self->{'buildproc'}->set_indexing_text (0);
    #$self->{'buildproc'}->set_indexfieldmap ($self->{'indexfieldmap'});
    $self->{'buildproc'}->set_levels ($self->{'levels'});                      
    $self->{'buildproc'}->set_db_level ($db_level);                       
    $self->{'buildproc'}->reset();
    &plugin::begin($self->{'pluginfo'}, $self->{'source_dir'}, 
		   $self->{'buildproc'}, $self->{'maxdocs'});
    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'}, 0, $self->{'gli'});
    &plugin::end($self->{'pluginfo'});

    close ($handle) unless $self->{'debug'};

    $self->print_stats();

    # create the compression dictionary
    # the compression dictionary is built by assuming the stats are from a seed
    # dictionary (-S), if a novel word is encountered it is spelled out (-H),
    # and the resulting dictionary must be less than 5 meg with the most 
    # frequent words being put into the dictionary first (-2 -k 5120)
    # note: these options are left over from mg version
    if (!$self->{'debug'}) {
	my $compdict_cmd = "mgpp_compression_dict$exe -f \"$fulltextprefix\" -S -H -2 -k 5120 $osextra";	
	print $outhandle "\n    creating the compression dictionary\n"  if ($self->{'verbosity'} >= 1);
	print $outhandle "\ncmd: $compdict_cmd\n"  if ($self->{'verbosity'} >= 4);
	print STDERR "<Phase name='CreatingCompress'/>\n" if $self->{'gli'};
	if (!-e "$mgpp_compression_dict_exe") {
	    print STDERR "<FatalError name='NoRunMGCompress'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::compress_text - couldn't run $mgpp_compression_dict_exe\n";
	}
	my $comp_dict_status = system ($compdict_cmd);
	if($comp_dict_status != 0) {
	    print $outhandle "\nmgppbuilder::compress_text - Warning: there's no compressed text\n";
	    $self->{'notbuilt'}->{'compressedtext'} = 1;
	    print STDERR "<Warning name='NoCompressedText'/>\n</Stage>\n" if $self->{'gli'};
	    return;
	}

	if (!$self->{'debug'}) {
	    my $mgpp_passes_cmd = "mgpp_passes$exe -M $maxnumeric $mgpp_passes_sections -f \"$fulltextprefix\" -T2 $osextra";
	    print $outhandle "\ncmd: $mgpp_passes_cmd\n"  if ($self->{'verbosity'} >= 4);

	    if (!-e "$mgpp_passes_exe" || !open ($handle, "| $mgpp_passes_cmd")) {
		print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
		die "mgppbuilder::compress_text - couldn't run $mgpp_passes_exe\n";
	    }
	}
    }
    else {
	print STDERR "<Phase name='SkipCreatingComp'/>\n" if $self->{'gli'};
    }

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->reset();

    # compress the text
    print $outhandle "\n    compressing the text (mgpp_passes -T2)\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CompressingText'/>\n" if $self->{'gli'};

    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'}, 0, $self->{'gli'});
    close ($handle) unless $self->{'debug'};

    $self->print_stats();
    print STDERR "</Stage>\n" if $self->{'gli'};
}


sub post_build_indexes {
    my $self = shift(@_);

    #define the final field lists
    $self->make_final_field_list();
}    

# creates directory names for each of the index descriptions
sub create_index_mapping {
    my $self = shift (@_);
    my ($indexes) = @_;

    my %mapping = ();

    return \%mapping if !(scalar @$indexes);

    $mapping{'indexmaporder'} = [];
    $mapping{'subcollectionmaporder'} = [];
    $mapping{'languagemaporder'} = [];
    
    # dirnames is used to check for collisions. Start this off
    # with the manditory directory names
    my %dirnames = ('text'=>'text',
		    'extra'=>'extra');
    my %pnames = ('index' => {}, 'subcollection' => {}, 'languages' => {});

    foreach my $index (@$indexes) {
	my ($fields, $subcollection, $languages) = split (":", $index);
	
	# we only ever have one index, and its called 'idx'
	my $pindex = 'idx';
	
	# next comes a processed version of the subcollection if there is one.
	my $psub = $self->process_field ($subcollection);
	$psub = lc ($psub);

	# next comes a processed version of the language if there is one.
	my $plang = $self->process_field ($languages);
	$plang = lc ($plang);

	my $dirname = $pindex . $psub . $plang;

	# check to be sure all index names are unique
	while (defined ($dirnames{$dirname})) {
	    $dirname = $self->make_unique (\%pnames, $index, \$pindex, \$psub, \$plang);
	}

	$mapping{$index} = $dirname;

	# store the mapping orders as well as the maps
	# also put index, subcollection and language fields into the mapping thing - 
	# (the full index name (eg text:subcol:lang) is not used on
	# the query page) -these are used for collectionmeta later on
	if (!defined $mapping{'indexmap'}{"$fields"}) {
	    $mapping{'indexmap'}{"$fields"} = $pindex;
	    push (@{$mapping{'indexmaporder'}}, "$fields");
	    if (!defined $mapping{"$fields"}) {
		$mapping{"$fields"} = $pindex;
	    }	
	}
	if ($psub =~ /\w/ && !defined ($mapping{'subcollectionmap'}{$subcollection})) {
	    $mapping{'subcollectionmap'}{$subcollection} = $psub;
	    push (@{$mapping{'subcollectionmaporder'}}, $subcollection);
	    $mapping{$subcollection} = $psub;
	}
	if ($plang =~ /\w/ && !defined ($mapping{'languagemap'}{$languages})) {
	    $mapping{'languagemap'}{$languages} = $plang;
	    push (@{$mapping{'languagemaporder'}}, $languages);
	    $mapping{$languages} = $plang;
	}
	$dirnames{$dirname} = $index;
	$pnames{'index'}->{$pindex} = "$fields";
	$pnames{'subcollection'}->{$psub} = $subcollection;
	$pnames{'languages'}->{$plang} = $languages;
    }

    return \%mapping;
}

sub make_unique {
    my $self = shift (@_);
    my ($namehash, $index, $indexref, $subref, $langref) = @_;
    my ($fields, $subcollection, $languages) = split (":", $index);

    if ($namehash->{'index'}->{$$indexref} ne "$fields") {
	$self->get_next_version ($indexref);
    } elsif ($namehash->{'subcollection'}->{$$subref} ne $subcollection) {
	$self->get_next_version ($subref);
    } elsif ($namehash->{'languages'}->{$$langref} ne $languages) {
	$self->get_next_version ($langref);
    }
    return "$$indexref$$subref$$langref";
}	


sub build_index {
    my $self = shift (@_);
    my ($index) = @_;
    my $outhandle = $self->{'outhandle'};

    # get the full index directory path and make sure it exists
    my $indexdir = $self->{'index_mapping'}->{$index};
    &FileUtils::makeAllDirectories (&FileUtils::filenameConcatenate($self->{'build_dir'}, $indexdir));

    my $collect_tail = &util::get_dirsep_tail($self->{'collection'});
    my $fullindexprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, 
					       $indexdir, 
					       $collect_tail);
    my $fulltextprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, "text", 
					       $collect_tail);

    # get any os specific stuff
    my $exedir = "$ENV{'GSDLHOME'}/bin/$ENV{'GSDLOS'}";

    my $exe = &util::get_os_exe ();
    my $mgpp_passes_exe = &FileUtils::filenameConcatenate($exedir, "mgpp_passes$exe");

    # define the section names for mgpasses
    my $mgpp_passes_sections = "-J ". $level_map{"document"} ." -K " . $level_map{"section"} ." ";
    if ($self->{'levels'}->{'paragraph'}) {
	$mgpp_passes_sections .= "-K " . $level_map{'paragraph'}. " ";
    }

    my $mgpp_perf_hash_build_exe = 
	&FileUtils::filenameConcatenate($exedir, "mgpp_perf_hash_build$exe");
    my $mgpp_weights_build_exe = 
	&FileUtils::filenameConcatenate($exedir, "mgpp_weights_build$exe");
    my $mgpp_invf_dict_exe = 
	&FileUtils::filenameConcatenate($exedir, "mgpp_invf_dict$exe");
    my $mgpp_stem_idx_exe =
	&FileUtils::filenameConcatenate($exedir, "mgpp_stem_idx$exe");

    my $maxnumeric = $self->{'maxnumeric'};

    my $osextra = "";
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$fullindexprefix =~ s@/@\\@g;
    } else {
	$osextra = " -d /";
	if ($outhandle ne "STDERR") {
	    # so mgpp_passes doesn't print to stderr if we redirect output
	    $osextra .= " 2>/dev/null";
	}
    }
 
    # get the index expression if this index belongs
    # to a subcollection
    my $indexexparr = [];
    my $langarr = [];
    # there may be subcollection info, and language info. 
    my ($fields, $subcollection, $language) = split (":", $index);
    my @subcollections = ();
    @subcollections = split /,/, $subcollection if (defined $subcollection);

    foreach $subcollection (@subcollections) {
	if (defined ($self->{'collect_cfg'}->{'subcollection'}->{$subcollection})) {
	    push (@$indexexparr, $self->{'collect_cfg'}->{'subcollection'}->{$subcollection});
	} 
    }
    
    # add expressions for languages if this index belongs to
    # a language subcollection - only put languages expressions for the 
    # ones we want in the index
    
    my @languages = ();
    my $languagemetadata = "Language";
    if (defined ($self->{'collect_cfg'}->{'languagemetadata'})) {
	$languagemetadata = $self->{'collect_cfg'}->{'languagemetadata'};
    }
    @languages = split /,/, $language if (defined $language);
    foreach my $language (@languages) {
	my $not=0;
	if ($language =~ s/^\!//) {
	    $not = 1;
	}
	if($not) {
	    push (@$langarr, "!$language");
	} else {
	    push (@$langarr, "$language");
	}
    }

    # Build index dictionary. Uses verbatim stem method
    print $outhandle "\n    creating index dictionary (mgpp_passes -I1)\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CreatingIndexDic'/>\n" if $self->{'gli'};
    my ($handle);
    if ($self->{'debug'}) {
	$handle = *STDOUT;
    }
    else {
        my $mgpp_passes_cmd = "mgpp_passes$exe -M $maxnumeric $mgpp_passes_sections -f \"$fullindexprefix\" -I1 $osextra";
    	print $outhandle "\ncmd: $mgpp_passes_cmd\n"  if ($self->{'verbosity'} >= 4);
	if (!-e "$mgpp_passes_exe" || !open($handle, "| $mgpp_passes_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_passes_exe\n";
	}
    }
	    
    # db_level is always section
    my $db_level = "section";

    # set up the document processr
    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->set_mode ('text');
    $self->{'buildproc'}->set_index ($index, $indexexparr);
    $self->{'buildproc'}->set_index_languages ($languagemetadata, $langarr) if (defined $language);
    $self->{'buildproc'}->set_indexing_text (1);
    $self->{'buildproc'}->set_levels ($self->{'levels'}); 
    $self->{'buildproc'}->set_db_level ($db_level);   
    
    $self->{'buildproc'}->reset();

    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'}, 0, $self->{'gli'});
    close ($handle) unless $self->{'debug'};

    $self->print_stats();

    # now we check to see if the required files have been produced - if not we quit building this index so the whole process doesn't crap out.
    # we check on the .id file - index dictionary
    my $dict_file = "$fullindexprefix.id";
    if (!-e $dict_file) {
	print $outhandle "mgppbuilder::build_index - Couldn't create index $index\n";
	print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	$self->{'notbuilt'}->{$index}=1;
	return;
    }

    if (!$self->{'debug'}) {
	# create the perfect hash function
	if (!-e "$mgpp_perf_hash_build_exe") {
	    print STDERR "<FatalError name='NoRunMGHash'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_perf_hash_build_exe\n";
	}
	my $hash_cmd = "mgpp_perf_hash_build$exe -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $hash_cmd\n" if ($self->{'verbosity'} >= 4);
	
	my $hash_status = system ($hash_cmd);
	print $outhandle "\nstatus from running hash_cmd: $hash_status\n" if ($self->{'verbosity'} >= 4);
	# check that perf hash was generated - if not, don't carry on
	if ($hash_status !=0) {
	    print $outhandle "mgppbuilder::build_index - Couldn't create index $index as there are too few words in the index.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

	my $mgpp_passes_cmd = "mgpp_passes$exe -M $maxnumeric $mgpp_passes_sections -f \"$fullindexprefix\" -I2 $osextra";
    	print $outhandle "\ncmd: $mgpp_passes_cmd\n"  if ($self->{'verbosity'} >= 4);
	if (!-e "$mgpp_passes_exe" || !open ($handle, "| $mgpp_passes_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_passes_exe\n";
	}
    }
    
    # invert the text
    print $outhandle "\n    inverting the text (mgpp_passes -I2)\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='InvertingText'/>\n" if $self->{'gli'};

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->reset();

    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'}, 0, $self->{'gli'});

    $self->print_stats ();
    
    if (!$self->{'debug'}) {

	close ($handle);
	my $passes_exit_status = $?;
	print $outhandle "\nMGPP Passes exit status $passes_exit_status\n"  if ($self->{'verbosity'} >= 4);	
	
	# create the weights file
	print $outhandle "\n    create the weights file\n"  if ($self->{'verbosity'} >= 1);
	print STDERR "<Phase name='CreateTheWeights'/>\n" if $self->{'gli'};
	if (!-e "$mgpp_weights_build_exe") {
	    print STDERR "<FatalError name='NoRunMGWeights'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_weights_build_exe\n";
	}
	my $weights_cmd = "mgpp_weights_build$exe -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $weights_cmd\n" if ($self->{'verbosity'} >= 4);	
	my $weights_status = system ($weights_cmd);
	# check that it worked - if not, don't carry on
	if ($weights_status !=0) {
	    print $outhandle "mgppbuilder::build_index - No Index: couldn't create weights file, error calling mgpp_weights_build.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

	# create 'on-disk' stemmed dictionary
	print $outhandle "\n    creating 'on-disk' stemmed dictionary\n"  if ($self->{'verbosity'} >= 1);
	if (!-e "$mgpp_invf_dict_exe") {
	    print STDERR "<FatalError name='NoRunMGInvf'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_invf_dict_exe\n";
	}
        my $invdict_cmd = "mgpp_invf_dict$exe -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $invdict_cmd\n"  if ($self->{'verbosity'} >= 4);
        my $invdict_status = system ($invdict_cmd);
	# check that it worked - if not, don't carry on
	if ($invdict_status !=0) {
	    print $outhandle "mgppbuilder::build_index - No Index: couldn't create on-disk stemmed dictionary, error calling mgpp_invf_dict.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

	# creates stem index files for the various stemming methods
	print $outhandle "\n    creating stem indexes\n"  if ($self->{'verbosity'} >= 1);
	print STDERR "<Phase name='CreatingStemIndx'/>\n" if $self->{'gli'};
	if (!-e "$mgpp_stem_idx_exe") {
	    print STDERR "<FatalError name='NoRunMGStem'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgppbuilder::build_index - couldn't run $mgpp_stem_idx_exe\n";
	}
	my $accent_folding_enabled = 1;
	if ($self->{'accentfold'}) {
	    my $accentfold_cmd = "mgpp_stem_idx$exe -b 4096 -s4 -f \"$fullindexprefix\" $osextra";
	    print $outhandle "\ncmd: $accentfold_cmd\n"  if ($self->{'verbosity'} >= 4);
	    # the first time we do this, we test for accent folding enabled
	    my $accent_status = system ($accentfold_cmd);
	    if ($accent_status == 2) {
		# accent folding has not been enabled in mgpp
		$accent_folding_enabled = 0;
		$self->{'stemindexes'} -= 4;
	    } elsif ($accent_status != 0) {
		print $outhandle "\nAccent folding failed: mgpp_stem_idx exit status $accent_status\n" if ($self->{'verbosity'} >= 4);
		$self->{'accentfold'} = 0; 
		#$accent_folding_enabled = 0;
		$self->{'stemindexes'} -= 4;
	    }
	}
	if ($self->{'casefold'}) {
	    my $casefold_cmd = "mgpp_stem_idx$exe -b 4096 -s1 -f \"$fullindexprefix\" $osextra";
	    print $outhandle "\ncmd: $casefold_cmd\n"  if ($self->{'verbosity'} >= 4);
	    my $casefold_status = system ($casefold_cmd);
	    if ($casefold_status != 0) {
		print $outhandle "\nCase folding failed: mgpp_stem_idx exit status $casefold_status\n" if ($self->{'verbosity'} >= 4);
		$self->{'casefold'} = 0;
		$self->{'stemindexes'} -= 1;
	    }
	    
	    elsif ($accent_folding_enabled && $self->{'accentfold'}) {
	        my $accent_casefold_cmd = "mgpp_stem_idx$exe -b 4096 -s5 -f \"$fullindexprefix\" $osextra";
	        print $outhandle "\ncmd: $accent_casefold_cmd\n"  if ($self->{'verbosity'} >= 4);
		my $status = system ($accent_casefold_cmd);
		if($status != 0) {
		    print $outhandle "\nAccent folding (with casefolding) failed: mgpp_stem_idx exit status $status\n" if ($self->{'verbosity'} >= 4);
		    $self->{'accentfold'} = 0;
		    $self->{'stemindexes'} -= 4; # casefold worked, only accentfold failed, so -= 4, not -= 5
		}
	    }
	}
	if ($self->{'stem'}) {
            my $stem_cmd = "mgpp_stem_idx$exe -b 4096 -s2 -f \"$fullindexprefix\" $osextra";
            print $outhandle "\ncmd: $stem_cmd\n"  if ($self->{'verbosity'} >= 4);
	    my $stem_status = system ($stem_cmd);
	    if ($stem_status != 0) {
		print $outhandle "\nStemming failed: mgpp_stem_idx exit status $stem_status\n" if ($self->{'verbosity'} >= 4);
		$self->{'stem'} = 0;
		$self->{'stemindexes'} -= 2;
	    }
	    elsif ($accent_folding_enabled && $self->{'accentfold'}) {
                my $accent_stem_cmd = "mgpp_stem_idx$exe -b 4096 -s6 -f \"$fullindexprefix\" $osextra";
                print $outhandle "\ncmd: $accent_stem_cmd\n"  if ($self->{'verbosity'} >= 4);
	        my $status = system ($accent_stem_cmd);
		if($status != 0) {
		    print $outhandle "\nAccent folding (with stemming) failed: mgpp_stem_idx exit status $status\n" if ($self->{'verbosity'} >= 4);
		    $self->{'accentfold'} = 0;
		    $self->{'stemindexes'} -= 4; # stem worked, only accentfold failed, so -= 4, not -= 6
		}
	    }
	}
	if ($self->{'casefold'} && $self->{'stem'}) {
            my $case_stem_cmd = "mgpp_stem_idx$exe -b 4096 -s3 -f \"$fullindexprefix\" $osextra";
            print $outhandle "\ncmd: $case_stem_cmd\n"  if ($self->{'verbosity'} >= 4);
	    my $case_and_stem_status = system ($case_stem_cmd);
	    if ($case_and_stem_status != 0) {
		print $outhandle "\nCasefolding and stemming failed: mgpp_stem_idx exit status $case_and_stem_status\n" if ($self->{'verbosity'} >= 4);
		$self->{'stem'} = 0;
		$self->{'casefold'} = 0;
		$self->{'stemindexes'} -= 3;
	    }
	    elsif ($accent_folding_enabled && $self->{'accentfold'}) {
		my $accent_case_stem_cmd = "mgpp_stem_idx$exe -b 4096 -s7 -f \"$fullindexprefix\" $osextra";
                print $outhandle "\ncmd: $accent_case_stem_cmd\n"  if ($self->{'verbosity'} >= 4);
		my $status = system ($accent_case_stem_cmd);
		if($status != 0) {
		    print $outhandle "\nAccent folding (with stemming and casefolding) failed: mgpp_stem_idx exit status $status\n" if ($self->{'verbosity'} >= 4);
		    $self->{'accentfold'} = 0;
		    $self->{'stemindexes'} -= 4; # casefold and stem worked, only accentfold failed, so -= 4, not -= 7
		}
	    }
	}

	# remove unwanted files
	my $tmpdir = &FileUtils::filenameConcatenate($self->{'build_dir'}, $indexdir);
	opendir (DIR, $tmpdir) || die
	    "mgppbuilder::build_index - couldn't read directory $tmpdir\n";
	foreach my $file (readdir(DIR)) {
	    next if $file =~ /^\./;
	    my ($suffix) = $file =~ /\.([^\.]+)$/;
	    if (defined $suffix && !defined $wanted_index_files{$suffix}) {
		# delete it!
		print $outhandle "deleting $file\n" if $self->{'verbosity'} > 2;
		#&util::rm (&FileUtils::filenameConcatenate($tmpdir, $file));
	    }
	}
	closedir (DIR);
    }
    print STDERR "</Stage>\n" if $self->{'gli'};
}   


sub get_collection_meta_indexes
{
    my $self = shift(@_);
    my $collection_infodb = shift(@_);

    # define the indexed field mapping if not already done so 
    # (i.e. if infodb called separately from build_index)
    if (!defined $self->{'build_cfg'}) {
	$self->read_final_field_list();
    }

    # first do the collection meta stuff - everything without a dot
    my $collmetadefined = 0;
    my $metadata_entry;
    if (defined $self->{'collect_cfg'}->{'collectionmeta'}) {
	$collmetadefined = 1;
    }

    #add the index field macros to [collection]
    # eg <TI>Title
    #    <SU>Subject
    # these now come from collection meta. if that is not defined, uses the metadata name
    my $collmeta = "";
    if (defined $self->{'build_cfg'}->{'extraindexfields'}) {
	foreach my $longfield (@{$self->{'build_cfg'}->{'extraindexfields'}}){
	    my $shortfield = $self->{'buildproc'}->{'fieldnamemap'}->{$longfield};
	    next if $shortfield eq 1;
	    
	    # we need to check if some coll meta has been defined - don't output 
	    # any that have
	    $collmeta = ".$longfield";
	    if (!$collmetadefined || !defined $self->{'collect_cfg'}->{'collectionmeta'}->{$collmeta}) {
		if ($longfield eq "allfields") {
		    $collection_infodb->{$shortfield} = [ "_query:textallfields_" ];
		} elsif ($longfield eq "text") {
		    $collection_infodb->{$shortfield} = [ "_query:texttextonly_" ];
		} else {
		    $collection_infodb->{$shortfield} = [ $longfield ];
		}
	    }
	}
    }

    # now add the level names
    my $level_entry = "";
    foreach my $level (@{$self->{'collect_cfg'}->{'levels'}}) {
	$collmeta = ".$level"; # based on the original specification
	$level =~ tr/A-Z/a-z/; # make it lower case
	my $levelid = $level_map{$level}; # find the actual value we used in the index
	if (!$collmetadefined || !defined $self->{'collect_cfg'}->{'collectionmeta'}->{$collmeta}) {
	    # use the default macro
	    $collection_infodb->{$levelid} = [ $level_map{$levelid} ];
	}
    }
    
    # now add subcoll meta
    my $subcoll_entry = "";
    my $shortname = "";
    my $one_entry = "";
    foreach my $subcoll (@{$self->{'index_mapping'}->{'subcollectionmaporder'}}) {
	$shortname = $self->{'index_mapping'}->{$subcoll};
	if (!$collmetadefined || !defined $self->{'collect_cfg'}->{'collectionmeta'}->{".$subcoll"}) {
	    $collection_infodb->{$shortname} = [ $subcoll ];
	}
    }

    # now add language meta
    my $lang_entry = "";
    foreach my $lang (@{$self->{'index_mapping'}->{'languagemaporder'}}) {
	$shortname = $self->{'index_mapping'}->{$lang};
	if (!$collmetadefined || !defined $self->{'collect_cfg'}->{'collectionmeta'}->{".$lang"}) {
	    $collection_infodb->{$shortname} = [ $lang ];
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
    $self->get_collection_meta_indexes(\%collection_infodb);
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_handle, "collection", \%collection_infodb);
}


# at the end of building, we have an indexfieldmap with all the mappings,
# plus some extras, and indexmap with any indexes in it that weren't
# specified in the index definition.  We want to make an ordered list of
# fields that are indexed, and a list of mappings that are used. This will
# be used for the build.cfg file, and for collection meta definition we
# store these in a build.cfg bit
sub make_final_field_list {
    my $self = shift (@_);
    
    $self->{'build_cfg'} = {};
    
    # store the indexfieldmap information
    my @indexfieldmap = ();
    my @indexfields = ();
    my $specifiedfields = {};
    my @specifiedfieldorder = ();

    # go through the index definition and add each thing to a map, so we
    # can easily check if it is already specified - when doing the
    # metadata, we print out all the individual fields, but some may
    # already be specified in the index definition, so we dont want to add
    # those again.

    my $field;
    foreach $field (@{$self->{'collect_cfg'}->{'indexes'}}) {
	# remove subcoll stuff
	my $parts = $field;
	$parts =~ s/:.*$//;
	# *************
	my @fs = split(';', $parts);
	foreach my $f(@fs) {
	    if (!defined $specifiedfields->{$f}) {
		$specifiedfields->{$f}=1;
		push (@specifiedfieldorder, "$f");
	    }
	}
    }
    
    #add all fields bit 
    my $fnm = $self->{'buildproc'}->{'fieldnamemap'};
    
    foreach $field (@specifiedfieldorder) {
	if ($field eq "metadata") {
	    foreach my $newfield (keys %{$self->{'buildproc'}->{'extraindexfields'}}) {
		if (!defined $specifiedfields->{$newfield}) {
		    push (@indexfieldmap, "$newfield\-\>$fnm->{$newfield}");
		    push (@indexfields, "$newfield");
		}
	    }

	} elsif ($field eq 'text') {
	    push (@indexfieldmap, "text\-\>TX");
	    push (@indexfields, "text");
	} elsif ($field eq 'allfields') {
	    push (@indexfieldmap, "allfields\-\>ZZ");
	    push (@indexfields, "allfields");
	} else {
	    # we only add in the ones that have been processed
	    if (defined $self->{'buildproc'}->{'allindexfields'}->{$field}) {
		push (@indexfieldmap, "$field\-\>$fnm->{$field}");
		push (@indexfields, "$field");
	    }
	}
    }

    if (scalar @indexfieldmap) {
	$self->{'build_cfg'}->{'indexfieldmap'} = \@indexfieldmap;
    }

    if (scalar @indexfields) {
	$self->{'build_cfg'}->{'indexfields'} = \@indexfields;
    }
}


# recreate the field list from the build.cfg file, look first in building,
# then in index to find it. if there is no build.cfg, we can't do the field
# list (there is unlikely to be any index anyway.)
sub read_final_field_list {
    my $self = shift (@_);
    $self->{'build_cfg'} = {};
    my @indexfieldmap = ();
    my @indexfields = ();
    my @indexmap = ();

    # we read the stuff in from the build.cfg file - if its there
    my $buildcfg = $self->read_build_cfg();
    return unless defined $buildcfg;

    my $field;
    if (defined $buildcfg->{'indexfields'}) {
	foreach $field (@{$buildcfg->{'indexfields'}}) {
	    push (@indexfields, "$field");
	}
    }

    if (defined $buildcfg->{'indexfieldmap'}) {
	foreach $field (@{$buildcfg->{'indexfieldmap'}}) {
	    push (@indexfieldmap, "$field");
	    my ($f, $v) = $field =~ /^(.*)\-\>(.*)$/;
	    $self->{'buildproc'}->{'indexfieldmap'}->{$f} = $v;
	}
    }	    

    if (defined $buildcfg->{'indexmap'}) {
	foreach $field (@{$buildcfg->{'indexmap'}}) {
	    push (@indexmap, "$field");
	}
    }	    

    $self->{'build_cfg'}->{'indexfieldmap'} = \@indexfieldmap;
    $self->{'build_cfg'}->{'indexfields'} = \@indexfields;
    $self->{'build_cfg'}->{'indexmap'} = \@indexmap;
}


sub build_cfg_extra {
    my $self = shift (@_);
    my ($build_cfg) = @_;

    $build_cfg->{'numsections'} = $self->{'buildproc'}->get_num_sections();
    
    # store the level info
    my @indexlevels = ();
    my @levelmap = ();
    foreach my $l (@{$self->{'levelorder'}}) {
	push (@indexlevels, $level_map{$l});
	push (@levelmap, "$l\-\>$level_map{$l}");
    }
    $build_cfg->{'indexlevels'} = \@indexlevels;
    $build_cfg->{'levelmap'} = \@levelmap;

    # text level (and database level) is always section
    $build_cfg->{'textlevel'} = $level_map{'section'};
   
}

1;


