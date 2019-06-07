###########################################################################
#
# mgbuilder.pm -- MGBuilder object
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

package mgbuilder;

use basebuilder;
use plugin;
use strict; no strict 'refs';
use util;
use FileUtils;


BEGIN {
    @mgbuilder::ISA = ('basebuilder');
}


$SIG{PIPE} = sub {
    print "got SIGPIPE\n";
    die "$0: Error: $!";
};


my %wanted_index_files = ('td'=>1,
		       't'=>1,
		       'idb'=>1,
		       'ib1'=>1,
		       'ib2'=>1,
		       'ib3'=>1,
		       'i'=>1,
		       'ip'=>1,
		       'tiw'=>1,
		       'wa'=>1);

my $maxdocsize = $basebuilder::maxdocsize;


sub new {
    my $class = shift(@_);

    my $self = new basebuilder (@_);
    $self = bless $self, $class;

    $self->{'buildtype'} = "mg";
    return $self;
}

sub default_buildproc {
    my $self  = shift (@_);

    return "mgbuildproc";
}

sub generate_index_list {
    my $self = shift (@_);

    if (!defined($self->{'collect_cfg'}->{'indexes'})) {
	$self->{'collect_cfg'}->{'indexes'} = [];
    }
    if (scalar(@{$self->{'collect_cfg'}->{'indexes'}}) == 0) {
	# no indexes have been specified so we'll build a "dummy:text" index
	push (@{$self->{'collect_cfg'}->{'indexes'}}, "dummy:text");	
    }
    # remove any ex. but only if there are no other metadata prefixes
    my @orig_indexes = @{$self->{'collect_cfg'}->{'indexes'}};
    $self->{'collect_cfg'}->{'indexes'} = [];
    foreach my $index (@orig_indexes) {
	#$index =~ s/ex\.([^.,:]+)(,|:|$)/$1$2/g; # doesn't preserve flex.Image, which is turned into fl.Image 
	$index =~ s/(,|:)/$1 /g;
	$index =~ s/(^| )ex\.([^.,:]+)(,|:|$)/$1$2$3/g;
	$index =~ s/(,|:) /$1/g;

	push (@{$self->{'collect_cfg'}->{'indexes'}}, $index);
    }
}

sub generate_index_options {
    my $self = shift (@_);
    $self->SUPER::generate_index_options();
    
    $self->{'casefold'} = 0;
    $self->{'stem'} = 0;
    $self->{'accentfold'} = 0; #not yet implemented for mg
    
    if (defined($self->{'collect_cfg'}->{'indexoptions'})) {
	foreach my $option (@{$self->{'collect_cfg'}->{'indexoptions'}}) {
	    if ($option =~ /stem/) {
		$self->{'stem'} = 1;
	    } elsif ($option =~ /casefold/) {
		$self->{'casefold'} = 1;
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


}

sub compress_text {
    my $self = shift (@_);
    my ($textindex) = @_;
    my $exedir = "$ENV{'GSDLHOME'}/bin/$ENV{'GSDLOS'}";
    my $exe = &util::get_os_exe ();
    my $mg_passes_exe = &FileUtils::filenameConcatenate($exedir, "mg_passes$exe");
    my $mg_compression_dict_exe = &FileUtils::filenameConcatenate($exedir, "mg_compression_dict$exe");
    my $outhandle = $self->{'outhandle'};

    my $maxnumeric = $self->{'maxnumeric'};

    &FileUtils::makeAllDirectories (&FileUtils::filenameConcatenate($self->{'build_dir'}, "text"));

    my $collect_tail = &util::get_dirsep_tail($self->{'collection'});
    my $basefilename = &FileUtils::filenameConcatenate("text",$collect_tail);
    my $fulltextprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, $basefilename);

    my $osextra = "";
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$fulltextprefix =~ s@/@\\@g;
    } else {
	$osextra = " -d /";
    }

    print $outhandle "\n*** creating the compressed text\n" if ($self->{'verbosity'} >= 1);
    print STDERR "<Stage name='CompressText'>\n" if $self->{'gli'};

    # collect the statistics for the text
    # -b $maxdocsize sets the maximum document size to be 12 meg
    print $outhandle "\n    collecting text statistics\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CollectTextStats'/>\n" if $self->{'gli'};

    my ($handle);
    if ($self->{'debug'}) {
	$handle = *STDOUT;
    }
    else {
	my $mgpasses_cmd = "mg_passes$exe -f \"$fulltextprefix\" -b $maxdocsize -T1 -M $maxnumeric $osextra";	
	#print STDERR "**** mg_passes$exe -f \"$fulltextprefix\" -b $maxdocsize -T1 -M $maxnumeric $osextra\n\n";
	print $outhandle "\ncmd: $mgpasses_cmd\n" if ($self->{'verbosity'} >= 4);

	if (!-e "$mg_passes_exe" || !open($handle, "| $mgpasses_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::compress_text - couldn't run $mg_passes_exe\n";
	}
    }

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->set_mode ('text');
    $self->{'buildproc'}->set_index ($textindex);
    $self->{'buildproc'}->set_indexing_text (0);


    if ($self->{'no_text'}) {
	$self->{'buildproc'}->set_store_text(0);
    } else {
	$self->{'buildproc'}->set_store_text(1);
    }
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
    # and the resulting dictionary must be less than 5 meg with the most frequent
    # words being put into the dictionary first (-2 -k 5120)
    if (!$self->{'debug'}) {
	print $outhandle "\n    creating the compression dictionary\n"  if ($self->{'verbosity'} >= 1);
	my $compdict_cmd = "mg_compression_dict$exe -f \"$fulltextprefix\" -S\ -H -2 -k 5120 $osextra";
	print $outhandle "\ncmd: $compdict_cmd\n" if ($self->{'verbosity'} >= 4);
	print STDERR "<Phase name='CreatingCompress'/>\n" if $self->{'gli'};
	if (!-e "$mg_compression_dict_exe") {
	    die "mgbuilder::compress_text - couldn't run $mg_compression_dict_exe\n";
	}
	my $comp_dict_status = system ($compdict_cmd);
	if($comp_dict_status != 0) {
	    print $outhandle "\nmgbuilder::compress_text - Warning: there's no compressed text\n";
	    $self->{'notbuilt'}->{'compressedtext'} = 1;
	    print STDERR "<Warning name='NoCompressedText'/>\n</Stage>\n" if $self->{'gli'};
	    return;
	}

	# -b $maxdocsize sets the maximum document size to be 12 meg
	my $mgpasses_cmd = "mg_passes$exe -f \"$fulltextprefix\" -b $maxdocsize -T2 -M $maxnumeric $osextra" ;
	print $outhandle "\ncmd: $mgpasses_cmd\n" if ($self->{'verbosity'} >= 4);

	if (!-e "$mg_passes_exe" || !open ($handle, "| $mgpasses_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::compress_text - couldn't run $mg_passes_exe\n";
	}
    }
    else {
	print STDERR "<Phase name='SkipCreatingComp'/>\n" if $self->{'gli'};
    }

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->reset();

    # compress the text
    print $outhandle "\n    compressing the text\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CompressingText'/>\n" if $self->{'gli'};

    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'}, 0, $self->{'gli'});

    close ($handle) unless $self->{'debug'};

    $self->print_stats();
    print STDERR "</Stage>\n" if $self->{'gli'};
}


# creates directory names for each of the index descriptions
sub create_index_mapping {
    my $self = shift (@_);
    my ($indexes) = @_;

    my %mapping = ();
    $mapping{'indexmaporder'} = [];
    $mapping{'subcollectionmaporder'} = [];
    $mapping{'languagemaporder'} = [];
    
    # dirnames is used to check for collisions. Start this off
    # with the manditory directory names
    my %dirnames = ('text'=>'text',
		    'extra'=>'extra');
    my %pnames = ('index' => {}, 'subcollection' => {}, 'languages' => {});
    foreach my $index (@$indexes) {
	my ($level, $gran, $subcollection, $languages) = split (":", $index);

	# the directory name starts with the first character of the index level
	my ($pindex) = $level =~ /^(.)/;

	# next comes a processed version of the index
	$pindex .= $self->process_field ($gran); 
	$pindex = lc ($pindex);

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
	# (the full index name (eg document:text:subcol:lang) is not used on
	# the query page) -these are used for collectionmeta later on
	if (!defined $mapping{'indexmap'}{"$level:$gran"}) {
	    $mapping{'indexmap'}{"$level:$gran"} = $pindex;
	    push (@{$mapping{'indexmaporder'}}, "$level:$gran");
	    if (!defined $mapping{"$level:$gran"}) {
		$mapping{"$level:$gran"} = $pindex;
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
	$pnames{'index'}->{$pindex} = "$level:$gran";
	$pnames{'subcollection'}->{$psub} = $subcollection;
	$pnames{'languages'}->{$plang} = $languages;
    }

    return \%mapping;
}


sub make_unique {
    my $self = shift (@_);
    my ($namehash, $index, $indexref, $subref, $langref) = @_;
    my ($level, $gran, $subcollection, $languages) = split (":", $index);

    if ($namehash->{'index'}->{$$indexref} ne "$level:$gran") {
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
    my $fullindexprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, $indexdir, 
					       $collect_tail);
    my $fulltextprefix = &FileUtils::filenameConcatenate($self->{'build_dir'}, "text", 
					       $collect_tail);

    # get any os specific stuff
    my $exedir = "$ENV{'GSDLHOME'}/bin/$ENV{'GSDLOS'}";
    my $exe = &util::get_os_exe ();
    my $mg_passes_exe = &FileUtils::filenameConcatenate($exedir, "mg_passes$exe");
    my $mg_perf_hash_build_exe = 
	&FileUtils::filenameConcatenate($exedir, "mg_perf_hash_build$exe");
    my $mg_weights_build_exe = 
	&FileUtils::filenameConcatenate($exedir, "mg_weights_build$exe");
    my $mg_invf_dict_exe = 
	&FileUtils::filenameConcatenate($exedir, "mg_invf_dict$exe");
    my $mg_stem_idx_exe =
	&FileUtils::filenameConcatenate($exedir, "mg_stem_idx$exe");

    my $maxnumeric = $self->{'maxnumeric'};

    my $osextra = "";
    if (($ENV{'GSDLOS'} =~ /^windows$/i) && ($^O ne "cygwin")) {
	$fullindexprefix =~ s@/@\\@g;
    } else {
	$osextra = " -d /";
	if ($outhandle ne "STDERR") {
	    # so mg_passes doesn't print to stderr if we redirect output
	    $osextra .= " 2>/dev/null";
	}
    }

    # get the index level from the index description
    # the index will be level 2 unless we are building a
    # paragraph level index
    my $index_level = 2;
    $index_level = 3 if $index =~ /^paragraph/i;

    # get the index expression if this index belongs
    # to a subcollection
    my $indexexparr = [];
    my $langarr = [];
    # there may be subcollection info, and language info. 
    my ($level, $fields, $subcollection, $language) = split (":", $index);
    my @subcollections = ();
    @subcollections = split /,/, $subcollection if (defined $subcollection);

    foreach my $subcollection (@subcollections) {
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
    print $outhandle "\n    creating index dictionary\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='CreatingIndexDic'/>\n" if $self->{'gli'};
    my ($handle);
    if ($self->{'debug'}) {
	$handle = *STDOUT;
    }
    else {
        my $mgpasses_cmd = "mg_passes$exe -f \"$fullindexprefix\" -b $maxdocsize " .
		   "-$index_level -m 32 -s 0 -G -t 10 -N1 -M $maxnumeric $osextra";
    	print $outhandle "\ncmd: $mgpasses_cmd\n" if ($self->{'verbosity'} >= 4);

	if (!-e "$mg_passes_exe" || !open($handle, "| $mgpasses_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_passes_exe\n";
	}
    }
	
    # set up the document processor
    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->set_mode ('text');
    $self->{'buildproc'}->set_index ($index, $indexexparr);
    $self->{'buildproc'}->set_index_languages ($languagemetadata, $langarr) if (defined $language);
    $self->{'buildproc'}->set_indexing_text (1);
    $self->{'buildproc'}->set_store_text(1);

    $self->{'buildproc'}->reset();
    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'},0, $self->{'gli'});
    close ($handle) unless $self->{'debug'};

    $self->print_stats();

    # now we check to see if the required files have been produced - if not we quit building this index so the whole process doesn't crap out.
    # we check on the .id file - index dictionary
    my $dict_file = "$fullindexprefix.id";
    if (!-e $dict_file) {
	print $outhandle "mgbuilder::build_index - Couldn't create index $index\n";
	$self->{'notbuilt'}->{$index}=1;
	return;
    }
    if (!$self->{'debug'}) {
	# create the perfect hash function
	if (!-e "$mg_perf_hash_build_exe") {
	    print STDERR "<FatalError name='NoRunMGHash'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_perf_hash_build_exe\n";
	}
	
	my $hash_cmd = "mg_perf_hash_build$exe -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $hash_cmd\n" if ($self->{'verbosity'} >= 4);
	my $hash_status = system ($hash_cmd);
	print $outhandle "\nstatus from running hash_cmd: $hash_status\n" if ($self->{'verbosity'} >= 4);
	# check that perf hash was generated - if not, don't carry on
	if ($hash_status !=0) {
	    print $outhandle "mgbuilder::build_index - Couldn't create index $index as there are too few words in the index.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

        my $mgpasses_cmd = "mg_passes$exe -f \"$fullindexprefix\" -b $maxdocsize " .
            "-$index_level -c 3 -G -t 10 -N2 -M $maxnumeric $osextra";
    	print $outhandle "\ncmd: $mgpasses_cmd\n" if ($self->{'verbosity'} >= 4);
	if (!-e "$mg_passes_exe" || !open ($handle, "| $mgpasses_cmd")) {
	    print STDERR "<FatalError name='NoRunMGPasses'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_passes_exe\n";
	}
    }
    
    # invert the text
    print $outhandle "\n    inverting the text\n"  if ($self->{'verbosity'} >= 1);
    print STDERR "<Phase name='InvertingText'/>\n" if $self->{'gli'};

    $self->{'buildproc'}->set_output_handle ($handle);
    $self->{'buildproc'}->reset();

    &plugin::read ($self->{'pluginfo'}, $self->{'source_dir'}, 
		   "", {}, {}, $self->{'buildproc'}, $self->{'maxdocs'},0, $self->{'gli'});

   
    $self->print_stats ();

    if (!$self->{'debug'}) {

	close ($handle);
	my $passes_exit_status = $?;
	print $outhandle "\nMG passes exit status $passes_exit_status\n"  if ($self->{'verbosity'} >= 4);
	
	# create the weights file
	print $outhandle "\n    create the weights file\n"  if ($self->{'verbosity'} >= 1);
	print STDERR "<Phase name='CreateTheWeights'/>\n" if $self->{'gli'};
	if (!-e "$mg_weights_build_exe") {
	    print STDERR "<FatalError name='NoRunMGWeights'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_weights_build_exe\n";
	}
	my $weights_cmd = "mg_weights_build$exe -f \"$fullindexprefix\" -t \"$fulltextprefix\" $osextra";
	print $outhandle "\ncmd: $weights_cmd\n" if ($self->{'verbosity'} >= 4);
	my $weights_status = system ($weights_cmd);
	# check that it worked - if not, don't carry on
	if ($weights_status !=0) {
	    print $outhandle "mgbuilder::build_index - No Index: couldn't create weights file, error calling mg_weights_build.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

	# create 'on-disk' stemmed dictionary
	print $outhandle "\n    creating 'on-disk' stemmed dictionary\n"  if ($self->{'verbosity'} >= 1);
        my $invdict_cmd = "mg_invf_dict$exe -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $invdict_cmd\n" if ($self->{'verbosity'} >= 4);

	print STDERR "<Phase name='CreateStemmedDic'/>\n" if $self->{'gli'};
	if (!-e "$mg_invf_dict_exe") {
	    print STDERR "<FatalError name='NoRunMGInvf'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_invf_dict_exe\n";
	}
	my $invdict_status = system ($invdict_cmd);
	# check that it worked - if not, don't carry on
	if ($invdict_status !=0) {
	    print $outhandle "mgbuilder::build_index - No Index: couldn't create on-disk stemmed dictionary, error calling mg_invf_dict.\n";
	    print STDERR "<Warning name='NoIndex'/>\n</Stage>\n" if $self->{'gli'};
	    $self->{'notbuilt'}->{$index}=1;
	    return;
	    
	}

	# creates stem index files for the various stemming methods
	print $outhandle "\n    creating stem indexes\n"  if ($self->{'verbosity'} >= 1);
	print STDERR "<Phase name='CreatingStemIndx'/>\n" if $self->{'gli'};
	if (!-e "$mg_stem_idx_exe") {
	    print STDERR "<FatalError name='NoRunMGStem'/>\n</Stage>\n" if $self->{'gli'};
	    die "mgbuilder::build_index - couldn't run $mg_stem_idx_exe\n";
	}
	# currently mg wont work if we don't generate all the stem idexes
	# so we generate them whatever, but don't advertise the fact
	#if ($self->{'casefold'}) {
#	system ("mg_stem_idx$exe -b 4096 -s1 -f \"$fullindexprefix\" $osextra");
	#}
	#if ($self->{'stem'}) {
#	system ("mg_stem_idx$exe -b 4096 -s2 -f \"$fullindexprefix\" $osextra");
	#}
	#if ($self->{'casefold'} && $self->{'stem'}) {
#	system ("mg_stem_idx$exe -b 4096 -s3 -f \"$fullindexprefix\" $osextra");
	#}

	# same as above: generate all the stem idexes. But don't bother stemming if
	# casefolding failed, and don't try generating indexes for both if stemming failed
        my $stemindex_cmd = "mg_stem_idx$exe -b 4096 -s1 -f \"$fullindexprefix\" $osextra";
	print $outhandle "\ncmd: $stemindex_cmd\n" if ($self->{'verbosity'} >= 4);

        my $stem_index_status = system ($stemindex_cmd);
	if($stem_index_status != 0) {
	    print $outhandle "\nCase folding failed: mg_stem_idx exit status $stem_index_status\n" if ($self->{'verbosity'} >= 4);
	} else {
	    $stemindex_cmd = "mg_stem_idx$exe -b 4096 -s2 -f \"$fullindexprefix\" $osextra";
	    print $outhandle "\ncmd: $stemindex_cmd\n" if ($self->{'verbosity'} >= 4);
	    $stem_index_status = system ($stemindex_cmd);

	    if($stem_index_status != 0) {
		print $outhandle "\nStemming failed: mg_stem_idx exit status $stem_index_status\n" if ($self->{'verbosity'} >= 4);
	    } else {
		$stemindex_cmd = "mg_stem_idx$exe -b 4096 -s3 -f \"$fullindexprefix\" $osextra";
		print $outhandle "\ncmd: $stemindex_cmd\n" if ($self->{'verbosity'} >= 4);
		$stem_index_status = system ($stemindex_cmd);

		if($stem_index_status != 0) {
		    print $outhandle "\nCasefolding and stemming failed: mg_stem_idx exit status $stem_index_status\n" if ($self->{'verbosity'} >= 4);
		}
	    }
	}

	# remove unwanted files
	my $tmpdir = &FileUtils::filenameConcatenate($self->{'build_dir'}, $indexdir);
	opendir (DIR, $tmpdir) || die
	    "mgbuilder::build_index - couldn't read directory $tmpdir\n";
	foreach my $file (readdir(DIR)) {
	    next if $file =~ /^\./;
	    my ($suffix) = $file =~ /\.([^\.]+)$/;
	    if (defined $suffix && !defined $wanted_index_files{$suffix}) {
		# delete it!
		print $outhandle "deleting $file\n" if $self->{'verbosity'} > 2;
		&FileUtils::removeFiles (&FileUtils::filenameConcatenate($tmpdir, $file));
	    }
	}
	closedir (DIR);
    }
    print STDERR "</Stage>\n" if $self->{'gli'};
}

sub build_cfg_extra {
   my $self = shift(@_);
   my ($build_cfg) = @_;
   
    # get additional stats from mg
    my $exedir = "$ENV{'GSDLHOME'}/bin/$ENV{'GSDLOS'}";
    my $exe = &util::get_os_exe ();
    my $mgstat_exe = &FileUtils::filenameConcatenate($exedir, "mgstat$exe");

    my $collect_tail = &util::get_dirsep_tail($self->{'collection'});
    my $input_file = &FileUtils::filenameConcatenate("text", $collect_tail);

    my $mgstat_cmd = "mgstat$exe -d \"$self->{'build_dir'}\" -f \"$input_file\"";
    my $outhandle = $self->{'outhandle'};
    print $outhandle "\ncmd: $mgstat_cmd\n" if ($self->{'verbosity'} >= 4);
    if (!-e "$mgstat_exe" || !open (PIPEIN, "$mgstat_cmd |")) {

	print $outhandle "Warning: Couldn't open pipe to $mgstat_exe to get additional stats\n";
    } else {
	my $line = "";
	while (defined ($line = <PIPEIN>)) {
	    if ($line =~ /^Words in collection \[dict\]\s+:\s+(\d+)/) {
		($build_cfg->{'numwords'}) = $1;
	    } elsif ($line =~ /^Documents\s+:\s+(\d+)/) {
		($build_cfg->{'numsections'}) = $1;
	    }
	}
	close PIPEIN;
    }
}

1;



