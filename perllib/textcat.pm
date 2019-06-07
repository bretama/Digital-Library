###########################################################################
#
# textcat.pm -- Identify the language of a piece of text
#
#
# This file is based on TextCat version 1.08 by Gertjan van Noord
# Copyright (C) 1997 Gertjan van Noord (vannoord@let.rug.nl)
# TextCat is available from: http://odur.let.rug.nl/~vannoord/TextCat 
#
# It was modified by Gordon Paynter (gwp@cs.waikato.ac.nz) and turned
# into a package for use in Greenstone digital library system.  Most of
# the modifications consist of commenting out or deleting functionality
# I don't need.  
#
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

package textcat;

use strict;

# OPTIONS
my $model_dir = $ENV{'GSDLHOME'} . "/perllib/textcat";

my $opt_f = 1;                # Ngrams which occur <= this number of times are removed
my $opt_t = 400;              # topmost number of ngrams that should be used
my $opt_u = 1.05;             # how much worse result must be before it is ignored

my $non_word_characters = '0-9\s';

# caching related
my %filename_cache = (); # map of cached text-strings each to array of char-encodings for the strings themselves
my %filecontents_cache = (); # map of cached filenames to array of char-encodings for the contents of the files
my $MAX_CACHE_SIZE = 1000;

sub new {
    my $class = shift (@_);
    my ($tmp_f, $tmp_t, $tmp_u) = @_;

    my $self = {};

    # open directory to find which languages are supported
    opendir DIR, "$model_dir" or die "directory $model_dir: $!\n";
    my @languages = sort(grep { s/\.lm// && -r "$model_dir/$_.lm" } readdir(DIR));
    closedir DIR;
    @languages or die "sorry, can't read any language models from $model_dir\n" .
	"language models must reside in files with .lm ending\n";

    # load model and count for each language.
    foreach my $language (@languages) {
	my %ngram=();
	my $rang=1;
	open(LM, "$model_dir/$language.lm") || die "cannot open $language.lm: $!\n";
	while (<LM>) {
	    chomp;
	    # only use lines starting with appropriate character. Others are ignored.
	    if (/^[^$non_word_characters]+/o) {
		$self->{'ngrams'}->{$language}->{$&} = $rang++;
	    } 
	}
	close(LM);
    }

    $self->{'languages'} = \@languages;

    $self->{'opt_f'} = defined($tmp_f) ? $tmp_f : $opt_f;
    $self->{'opt_t'} = defined($tmp_t) ? $tmp_t : $opt_t;
    $self->{'opt_u'} = defined($tmp_u) ? $tmp_u : $opt_u;
    $self->{'max_cache_size'} = $MAX_CACHE_SIZE;

    return bless $self, $class;
}


# CLASSIFICATION
#
# What language is a text string?
#   Input:  text string
#   Output: array of language names
# $languages is the set of language models to consider (to textcat on)
# Can be set to filter out language models that don't belong to the given encoding 
# in order to obtain a list of the probable languages for that known encoding.
# $filter_by_encoding indicates what encoding to narrow the search for languages down to.
# This is for when we already know the encoding, but we're still looking for the language.
sub classify {
    my ($self, $inputref, $filter_by_encoding)=@_;
    my $languages;
    @$languages = ();

    # filter language filenames by encoding 
    if(defined $filter_by_encoding) {
	# make sure to normalize language and filtering encoding so we are not
	# stuck comparing hyphens with underscores in such things as iso-8859-1
	my $normalized_filter = $filter_by_encoding; 
	$normalized_filter =~ s/[\W\_]//g;

	foreach my $lang (@{$self->{'languages'}}) {
	    my $normalized_lang = $lang; 
	    $normalized_lang =~ s/[\W\_]//g;

	    if($normalized_lang =~ m/$normalized_filter/i) {
		push (@$languages, $lang);
	    }
	}
    }

    # if the filter_by_encoding wasn't in the list of language model filenames
    # or if we're not filtering, then work with all language model filenames
    if(scalar @$languages == 0) {
	$languages = $self->{'languages'};
    }

    my %results = ();
    my $maxp = $self->{'opt_t'};

    # create ngrams for input.
    my $unknown = $self->create_lm($inputref);

    foreach my $language (@$languages) {	
	# compare language model with input ngrams list
	my ($i,$p)=(0,0);
	while ($i < scalar (@$unknown)) {
	    if (defined ($self->{'ngrams'}->{$language}->{$unknown->[$i]})) {
		$p=$p+abs($self->{'ngrams'}->{$language}->{$unknown->[$i]}-$i);
	    } else { 
		$p=$p+$maxp; 
	    }
	    ++$i;
	}
	$results{$language} = $p;
    }

    my @results = sort { $results{$a} <=> $results{$b} } keys %results;
    my $a = $results{$results[0]};
  
    my @answers=(shift(@results));
    while (@results && $results{$results[0]} < ($self->{'opt_u'} *$a)) {
	@answers=(@answers,shift(@results));
    }

    return \@answers;
}


# Same as below, but caches textcat results on filenames for subsequent use.
# The cache is a map of the filename to the corresponding filename_encodings
# (an array of results returned by textcat of the possible filename-encodings 
# for the indexing filename string itself). 
# Need to make sure that the filename is only the tailname: no path and no
# extension (no digits), in order to make optimum use of cached textcat.
# Textcat is performed on $filename_ref and the results associated with $filename_ref.
# The cache will be cleared when the max_cache_size is reached, which is
# MAX_CACHE_SIZE by default or can be specified as a parameter. The cache
# can also be cleared by a call to clear_filename_cache.
sub classify_cached_filename {
    my ($self, $filename_ref)=@_;
    
    # if not already in the cache, work it out and put it there
    if (!defined $filename_cache{$$filename_ref}) 
    {
	if (scalar (keys %filename_cache) >= $self->{'max_cache_size'}) {
	    $self->clear_filename_cache();
	}
	$filename_cache{$$filename_ref} = $self->classify($filename_ref);
    } 

    # return cached array of encodings for the given string
    return $filename_cache{$$filename_ref}; 
}

# Same as above, but caches textcat results on filecontents for subsequent use.
# Textcat on a file's contents to work out its possible encodings. Uses the cache.
# The cache is a map of the filename to an array of possible filename_encodings
# for the *contents* of the file returned by textcat.
# Textcat is performed on $contents_ref and the results associated with $filename.
# The cache will be cleared when the max_cache_size is reached, which is
# MAX_CACHE_SIZE by default or can be specified as a parameter. The cache
# can also be cleared by a call to clear_filecontents_cache.
sub classify_contents {
    my ($self, $contents_ref, $filename)=@_;
     
    # if not already in the cache, work it out and put it there
    if (!defined $filecontents_cache{$filename})
    {	   
	if (scalar (keys %filecontents_cache) >= $self->{'max_cache_size'}) {
	    $self->clear_filecontents_cache();
	}
	
	# Finally, we can perform the textcat classification of language and encoding
	$filecontents_cache{$filename} = $self->classify($contents_ref);
    }
    # return cached array of content encodings for the given filename
    return $filecontents_cache{$filename};
}


# Given the known encoding for a file's contents, performs a textcat 
# filtering on the languages for the given encoding. Results are stored
# in the cache TWICE: once under $filename|$filter_by_encoding, and
# once under the usual $filename, so that subsequent calls to either
# this method or classify_contents using the same filename will not
# perform textcat again. 
sub classify_contents_for_encoding {
    my ($self, $contents_ref, $filename, $filter_by_encoding)=@_;

    if (!defined $filecontents_cache{"$filename|$filter_by_encoding"})
    {	   
	if (scalar (keys %filecontents_cache) >= $self->{'max_cache_size'}) {
	    $self->clear_filecontents_cache();
	}	

	$filecontents_cache{"$filename|$filter_by_encoding"} = $self->classify($contents_ref, $filter_by_encoding);
	# store this in cache again under $filename entry, so that subsequent 
	# calls to classify_contents will find it in the cache already
	$filecontents_cache{$filename} = $self->classify($contents_ref, $filter_by_encoding);
    }
    return $filecontents_cache{$filename};
}
   

# This method returns the most frequently occurring encoding 
# but only if any encoding occurs more than once in the given results.
# Otherwise, "" is returned.
sub most_frequent_encoding {
    my ($self, $results) = @_;
    my $best_encoding = "";

    # guessed_encodings is a hashmap of Encoding -> Frequency pairs
    my %guessed_encodings = ();
    foreach my $result (@$results) {
	# Get the encoding portion of a language-model filename like en-iso8859_1
	my ($encoding) = ($result =~ /^(?:[^\-]+)\-([^\-]+)$/);
	if(!defined($guessed_encodings{$encoding})) {
	    $guessed_encodings{$encoding} = 0;
	}
	$guessed_encodings{$encoding}++;
    }
    
    $guessed_encodings{""}=-1; # for default best_encoding of ""

    foreach my $enc (keys %guessed_encodings) {
	if ($guessed_encodings{$enc} > $guessed_encodings{$best_encoding}) {
	    $best_encoding = $enc;
	}
    }

    # If best_encoding's frequency == 1, then the frequency for all encodings will 
    # be 1 since the sum total of all frequencies is num_results: if any encoding
    # has frequency > 1 (it's possibly the best_encoding), one or more of the others
    # would have been at 0 frequency to compensate.
    return ($guessed_encodings{$best_encoding} > 1) ? $best_encoding : "";
}


# set some of the specific member variables
sub set_opts {
    my ($self, $opt_freq, $opt_factor, $opt_top, $max_size_of_cache)=@_;
         
    $self->{'opt_f'} = $opt_freq if defined $opt_freq;
    $self->{'opt_u'} = $opt_factor if defined $opt_factor;
    $self->{'opt_t'} = $opt_top if defined $opt_top;

    $self->{'max_cache_size'} = $max_size_of_cache if defined $max_size_of_cache;
}

sub get_opts {
    my $self = shift (@_);
    return ($self->{'opt_f'}, $self->{'opt_u'}, $self->{'opt_t'}, $self->{'max_cache_size'});
}

# Clears the filename cache (a map of strings to the textcat results for each string).
sub clear_filename_cache {
    my $self = shift (@_);

    %filename_cache = ();
}

# Clears the filecontents cache (a map of filenames to the textcat results on the contents of each file).
sub clear_filecontents_cache {
    my $self = shift (@_);

    %filecontents_cache = ();
}

sub create_lm {
    # $ngram contains reference to the hash we build
    # then add the ngrams found in each word in the hash
    my ($self, $textref) = @_;  
    
    my $ngram = {};

    foreach my $word (split(/[$non_word_characters]+/, $$textref)) {
	$word = "_" . $word . "_";
	my $len = length($word);
	my $flen=$len;
	my $i;

	for ($i=0; $i<$flen; $i++) {
	    $ngram->{substr($word,$i,5)}++ if $len > 4;
	    $ngram->{substr($word,$i,4)}++ if $len > 3;
	    $ngram->{substr($word,$i,3)}++ if $len > 2;
	    $ngram->{substr($word,$i,2)}++ if $len > 1;
	    $ngram->{substr($word,$i,1)}++;
	    $len--;
	}
    }

    map { if ($ngram->{$_} <= $self->{'opt_f'}) { delete $ngram->{$_}; }
      } keys %$ngram;
  
    # sort the ngrams, and spit out the $opt_t frequent ones.
    # adding  `or $a cmp $b' in the sort block makes sorting five
    # times slower..., although it would be somewhat nicer (unique result)
    my @sorted = sort { $ngram->{$b} <=> $ngram->{$a} } keys %$ngram;
    splice(@sorted,$self->{'opt_t'}) if (@sorted > $self->{'opt_t'}); 
    return \@sorted;
}

1;
