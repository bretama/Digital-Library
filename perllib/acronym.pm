##########################################################################
#
# acronym.pm --
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
#    class to handle acronyms
###########################################################################

eval "require diagnostics"; # some perl distros (eg mac) don't have this

package acronym;

use util;
use strict;

###########################################################################
#    global variables
###########################################################################
# valiables to control the recall/precision tradeoff

#the maximum range to look for acronyms 
my $max_offset = 30;
#acronyms must be upper case
my $upper_case = 1;
#acronym case must match
my $case_match = 1;
#minimum acronym length
my $min_def_length = 3;
#minimum acronym length
my $min_acro_length = 3;
#minimum acronym length saving
my $min_length_saving = 4;
#allow recusive acronyms
my $allow_recursive = 0;
#let definitions be all capitals
my $allow_all_caps = 0;

my @stop_words = split / /, "OF AT THE IN TO AND";

#the text split into an array, one word per element
my @split_text = ();
my @acronym_list = ();


my %acronyms_found_in_collection = ();
my %acronyms_banned_from_collection = ();

my $writing_acronyms = 1;
my $accumulate_acronyms = 1;
my $markup_accumulate_acronyms = 1;
my $markup_local_acronyms = 1;



###########################################################################
#   file saving / loading stuff
###########################################################################

sub initialise_acronyms {

    my $local_max_offset = $max_offset;
    my $local_upper_case = $upper_case;
    my $local_case_match = $case_match ;
    my $local_min_def_length = $min_def_length;
    my $local_min_acro_length = $min_acro_length;
    my $local_min_length_saving = $min_length_saving;
    my $local_allow_recursive = $allow_recursive;
    my $local_allow_all_caps = $allow_all_caps;
    my @local_stop_words = @stop_words;
    
    
    # the file to collate acronyms into

    my $def_acronym_acc_file_pm = '&util::filename_cat($ENV{\'GSDLCOLLECTDIR\'}, "etc","acronym_definitions.pm");';
    my $acronym_accumulate_file = eval { $def_acronym_acc_file_pm };
    my $acronym_options_file = &util::filename_cat($ENV{'GSDLCOLLECTDIR'},"etc","acronym_options.pm");


    my $file_text = "";
    if (open ACRONYM_HANDLE, "<$acronym_options_file")
    {
	$file_text = do { local $/; <ACRONYM_HANDLE> };  
    }
    if ($file_text eq "")
    {
	print STDERR "failed to open $acronym_options_file\n";
	open ACRONYM_HANDLE, ">$acronym_options_file\n";
	print ACRONYM_HANDLE "use util;\n";
	print ACRONYM_HANDLE "#Config file for acronym extraction. EDIT THIS FILE, it should\n";
	print ACRONYM_HANDLE "#not be overridden by the software. It's read by GSDL using perl's\n";
	print ACRONYM_HANDLE "#'eval' function, so pretty much anything that's valid in perl is \n";
	print ACRONYM_HANDLE "#valid here.\n\n";
	print ACRONYM_HANDLE "#Quite a few things here are defined in terms of recall and precision\n";
	print ACRONYM_HANDLE "#which are the key measures from Information Retreval (IR). If you\n";
	print ACRONYM_HANDLE "#don't understand recall and precision, any good IR textbook should\n";
	print ACRONYM_HANDLE "#explain them fully \n\n";
	print ACRONYM_HANDLE "#the maximum range to look for acronyms (raise to raise precision)\n"; 
	print ACRONYM_HANDLE "\$local_max_offset = $max_offset;\n\n"; 
	print ACRONYM_HANDLE "#acronyms must be upper case (0 = false, 1 = true (high precision))\n";
	print ACRONYM_HANDLE "\$local_upper_case = $upper_case;\n\n";
	print ACRONYM_HANDLE "#acronym case must match (0 = false, 1 = true (high precision))\n";
	print ACRONYM_HANDLE "\$local_case_match = $case_match;\n\n";
	print ACRONYM_HANDLE "#minimum acronym length (raise to raise precision)\n";
	print ACRONYM_HANDLE "\$local_min_def_length = $min_def_length;\n\n";
	print ACRONYM_HANDLE "#let definitions be all capitals\n";
	print ACRONYM_HANDLE "\$local_allow_all_caps = $allow_all_caps;\n\n";
	print ACRONYM_HANDLE "#minimum acronym length (raise to raise precision)\n";
	print ACRONYM_HANDLE "\$local_min_acro_length = 3;\n\n";
	print ACRONYM_HANDLE "#minimum acronym length saving (raise to raise precision)\n";
	print ACRONYM_HANDLE "\$local_min_length_saving = 4;\n\n";
	print ACRONYM_HANDLE "#allow recusive acronyms (0 = false (high precision), 1 = true)\n";
	print ACRONYM_HANDLE "\$local_allow_recursive = 0;\n\n";
	print ACRONYM_HANDLE "#stop words-words allowed in acronyms (the multi-lingual version\n";
	print ACRONYM_HANDLE "#slows down acronym extraction slightly so is not the default)\n";
	print ACRONYM_HANDLE "#\@local_stop_words = split / /, \"A OF AT THE IN TO AND VON BEI DER DIE DAS DEM DEN DES UND DE DU A LA LE LES L DANS ET S\";\n";
	print ACRONYM_HANDLE "\@local_stop_words = split / /, \"OF AT THE IN TO AND\";\n"; 
	print ACRONYM_HANDLE "\n"; 
	print ACRONYM_HANDLE "#the file to collate acronyms into\n";
	print ACRONYM_HANDLE "\$acronym_accumulate_file = $def_acronym_acc_file_pm\n";
	print ACRONYM_HANDLE "\n";
	print ACRONYM_HANDLE "# any acronym definitions which should always be marked up can be copied here\n";
	print ACRONYM_HANDLE "# from the acronym_accumulate_file file ...\n";
	print ACRONYM_HANDLE "# \n";
	print ACRONYM_HANDLE "# \n";
	print ACRONYM_HANDLE "# \n";
	print STDERR "written new options file to $acronym_options_file...\n";
    } else {
	print STDERR "read file $acronym_options_file...\n";
	eval $file_text ;
	warn $@ if $@;
	print STDERR "evaluated file $acronym_options_file...\n";
    }

    $max_offset = $local_max_offset;
    $upper_case = $local_upper_case;
    $case_match = $local_case_match ;
    $min_def_length = $local_min_def_length;
    $min_acro_length = $local_min_acro_length;
    $min_length_saving = $local_min_length_saving;
    $allow_recursive = $local_allow_recursive;
    $allow_all_caps = $local_allow_all_caps;
    @stop_words = @local_stop_words;
        

    &read_all_acronyms_from_file($acronym_accumulate_file);
#    rename $acronym_file, $acronym_file . "." . int(rand (2<<7)). 
#	int(rand (2<<7)). int(rand (2<<7)). int(rand (2<<7));
    if ($writing_acronyms && open ACRONYM_HANDLE, ">$acronym_accumulate_file")
    {
	print ACRONYM_HANDLE "#This is an automatically generated file.\n";
	print ACRONYM_HANDLE "#\n";
	print ACRONYM_HANDLE "#If you edit this file and it will be overwritten the next\n";
	print ACRONYM_HANDLE "#time the acronym code runs unless you set the file to \n";
	print ACRONYM_HANDLE "#read-only. \n";
	print ACRONYM_HANDLE "#\n";
	print ACRONYM_HANDLE "#start of acronyms...\n";
	$writing_acronyms = 1;
    } else {
	warn "failed to open $acronym_accumulate_file for writing\n";
	$writing_acronyms = 0;
    }
}

#close the list of accumulated acronyms
sub finalise_acronyms {
    if ($writing_acronyms)
    {
	print ACRONYM_HANDLE "#end of acronyms.\n";  
	close ACRONYM_HANDLE;
    }
}

#eval a file of accumulated acronyms
sub read_all_acronyms_from_file {
    my ($acronym_accumulate_file) = @_;

    my $file_text = " ";
    if (open ACRONYM_HANDLE, "<$acronym_accumulate_file")
    {
	$file_text = do { local $/; <ACRONYM_HANDLE> };  
    } else {
	print STDERR "failed to open $acronym_accumulate_file for reading (this is the first pass?).\n";
    }
    eval $file_text;
    #promotes warnings/errors from evaluated file to current context 
    warn $@ if $@;
}

#called from within the file of accumulated acronyms to indicate a good acronym
sub add {
    my $self = shift (@_);
    if (defined ($acronyms_found_in_collection{$self->[0]}))
    {
	my $def = $self->to_def_string();
	if ($acronyms_found_in_collection{$self->[0]} =~ m/(^|\|)$def(\||$)/)
	{
	    return;
	}
	$acronyms_found_in_collection{$self->[0]} = 
	    $acronyms_found_in_collection{$self->[0]} . "|" . $self->to_def_string();
    } else {
	$acronyms_found_in_collection{$self->[0]} = $self->to_def_string();
    }
}

#called from within the file of accumulated acronyms to indicate a bad acronym
sub ban {
    my $self = shift (@_);
    
    if (!defined $acronyms_banned_from_collection{$self->[0]})
    {
	$acronyms_banned_from_collection{$self->[0]} = $self->to_def_string();
    } else {
	$acronyms_banned_from_collection{$self->[0]} = $acronyms_banned_from_collection{$self->[0]} . "|" . $self->to_def_string();
    }
}


#write a good acronym to the accumulated acronyms file
sub write_to_file {
    my $self = shift (@_);
    if ($writing_acronyms)
    {
	print ACRONYM_HANDLE "new acronym(\"$self->[0]\",\"" . 
	    $self->to_def_string() . 
		"\")->add();\n";
    }
}


###########################################################################
# mark functionality    
###########################################################################

#small routine to sort by length 
sub sort_by_length {
    length($b) <=> length($a) or $a cmp $b
}

sub markup_acronyms {
    my  $text = shift (@_);
    my  $verbosity_obj = shift (@_);
    if (defined $text)
    {
	for my $acro (sort sort_by_length keys %acronyms_found_in_collection)
	{
	    $text  =~ s/^((?:[^\<\n]|(?:\<[^\>\n]*\>))*)$acro([^\<A-Z])/$1$acro\<img src=\"\" width=8 height=8 alt=\"$acronyms_found_in_collection{$acro}\"\>$2/gm;
	    printf STDERR " " .  $acro . ","
		if ($verbosity_obj->{'verbosity'} >= 2);
	}
    }
    return $text;
}



###########################################################################
#    member functions 
###########################################################################


sub new {
    my $trash = shift (@_); 
    my $acro = shift (@_); 
    my $def  = shift (@_); 
    
    my $self = [
		"", # 0 acronym
		[], # 1 definition
               ];
    
    $self->[0] = $acro                    if defined $acro;
    push @{$self->[1]},  split / /, $def  if defined $def;
    
    bless $self;
}

sub clone  {
    my $self = shift (@_);

    my $copy = new acronym;

    $copy->[0] = $self->[0];
    push @{$copy->[1]}, @{$self->[1]};
    bless $copy;

    return $copy;
}

#return the acronym
sub to_acronym {
    my $self = shift (@_);
    my @array = @{$self->[1]};

    return $self->[0];
}

#return the number of words in the acronym definition
sub words_in_acronym_definition {
    my $self = shift (@_);
    my @array = @{$self->[1]};

    return $#array + 1;
}

#return the number of letters in the acronym definition
sub letters_in_acronym_definition {
    my $self = shift (@_);

    return length($self->to_def_string());
}

#return the number of letters in the acronym definition
sub letters_in_acronym {
    my $self = shift (@_);

    return length($self->to_acronym());
}

#return the acronym definition
sub to_def_string {
    my $self = shift (@_);

    my $result = "";

    # do the definition
    my @array = @{$self->[1]};
    my $i = 0;
    while ($i <= $#array)
    {
	$result = $result . $array[$i];

	if ($i+1 <= $#array)
	{
	    $result = $result . " ";
	}
	$i++;
    }
    return $result;
}


#print out the kwic for the acronym
sub to_string_kwic {
    my $self = shift (@_);

    # the list of all possible combinations
    my @list = ();

    my $result = "";

    my $j = 0;
    my @array = @{$self->[1]};
    while ($j <= $#array)
    {

	# do the definition
	my $i = 0;

	#add the key word
	$result = "<td halign=left>"  . $array[$j] . "</td><td halign=right>";

	#add the proceeding words
	while ($i < $j)
	{
	    $result = $result .  $array[$i] . " ";
	    $i++;
	}
	#add the key word
	$result = $result . "</td><td halign=left>"  . $array[$j] . 
	    "</td><td halign=left>";

	#add the trailing words
	$i++;
	while ($i <= $#array )
	{
	    $result = $result .  $array[$i] . " ";
	    $i++;
	}

	#add the actual acronym

	$result = $result . "</td><td halign=left>" . $self->[0] . "</td>";

	push @list, $result;
	$j++;
    }
    return @list;
}

#this is the one used when building the collection ...
sub to_string {
    my $self = shift (@_);

    my $result = $self->[0] . " ";

    # do the definition
    my @array = @{$self->[1]};
    my $i = 0;
    while ($i <= $#array)
    {
	$result = $result . $array[$i];
	if ($i+1 <= $#array)
	{
	    $result = $result . " ";
	}
	$i++;
    }
    return $result;
}

sub check {
    my $self = shift (@_);

    if (length($self->to_acronym()) < $min_acro_length) 
    {
#	print "acronym " . $self->to_string() . " rejected (too short I)\n";
	return 0;
    }
    if ($self->words_in_acronym_definition() < $min_def_length) 
    {
#	print "acronym " . $self->to_string() . " rejected (too short II)\n";
	return 0;
    }
    if ($min_length_saving * $self->letters_in_acronym() > 
	$self->letters_in_acronym_definition()) 
    {
#	print "acronym " . $self->to_string() . " rejected (too short III)\n";
#	print "" . $min_length_saving .
#	    "|" . $self->letters_in_acronym() .
#	    "|" . $self->letters_in_acronym_definition() . "\n";
	return 0;
    }
    if (!$allow_all_caps && 
	$self->to_def_string() eq uc($self->to_def_string()))
    {
#	print "acronym " . $self->to_string() . " rejected (all upper)\n";
	return 0;
    }
    if (!$allow_all_caps)
    {
	my $upper_count = 0;
	my $lower_count = 0;
	my @letters = $self->to_def_string();
	for my $letter (split //, $self->to_def_string())
	{
	    if ($letter eq uc($letter))
	    { 
		$upper_count++;
	    } else {
		$lower_count++;
	    }		
	}
	return 0 if ($upper_count > $lower_count);
    }
    if (!$allow_recursive && $self->to_def_string() =~ /$self->to_acronym()/i )
    {
	return 0;
    }
#    print "acronym " . $self->to_string() . " not rejected\n";
    return 1;
}

###########################################################################
#    static functions 
###########################################################################

sub recurse {
    my ($acro_offset,       #offset of word we're finding acronyms for
	$text_offset,       
	$letter_offset, 
	@def_so_far) = @_;

    my $word = $split_text[$text_offset];
    my $acro = $split_text[$acro_offset];
    $word = "" if !defined $word;
    $acro = "" if !defined $acro;
    
#    print "recurse(" . $acro_offset . ", " . $text_offset . ", " . 
#	$letter_offset  . ", " . @def_so_far . ")\n";

    #check for termination ...
    if ($letter_offset >= length($acro))
    {	
	my $acronym = new acronym();
	$acronym->[0] = $acro;
	push @{$acronym->[1]}, @def_so_far;
	if ($acronym->check())
	{
	    push @acronym_list, ( $acronym );
	}
#	print "acronym created\n";
	return;
    }
    #check for recursion
    if (!$allow_recursive)
    {
	if ($word eq $acro)
	{
#	    print "recursion detected\n";
	    return;
	}
    }
    
    #skip a stop-word
    my $i = 0;
    if ($letter_offset != 0)
    {
	while ($i <= $#stop_words)
	{
	    if ($stop_words[$i] eq uc($word))
	    {
#	    print "::found stop word::" . $stop_words[$i] . "\n";
		&recurse($acro_offset,
			 $text_offset+1,
			 $letter_offset,
			 @def_so_far, $word);
	    }
	    $i++;
	}
    }
    $i = 1;
    #using the first $i letters ...
    while ($letter_offset+$i <= length($acro) )
    {
#	print "". ((substr $word, 0, $i) . " " . 
#	    (substr $acro, $letter_offset, $i) . "\n");
	if (((!$case_match) &&
	     (uc(substr $word, 0, $i) eq
	      uc(substr $acro, $letter_offset, $i)))
	    ||
	    (($case_match) &&
	     ((substr $word, 0, $i) eq
	      (substr $acro, $letter_offset, $i))))
	{
#	    print "::match::\n";
#	    print "" . ((substr $word, 0, $i) . " " . 
#		   (substr $acro, $letter_offset, $i) . "\n");
	    &recurse($acro_offset,
		     $text_offset+1,
		     $letter_offset+$i,
		     @def_so_far, $word);
	} else {
	    return;
	}	    
	$i++;
    }
    return;
}

#the main
sub acronyms {
    #clean up the text
    my $processed_text =  shift @_;
    $$processed_text =~ s/<[^>]*>/ /g;
    $$processed_text =~ s/\W/ /g;
    $$processed_text =~ s/[0-9_]/ /g;
    $$processed_text =~ s/\s+/ /g;
    $$processed_text =~ s/(\n|\>)References.*/ /i;
    $$processed_text =~ s/(\n|\>)Bibliography.*/ /i;
    $$processed_text =~ s/(\n|\>)(Cited Works?).*/ /i;
    $$processed_text =~ s/(\n|\>)(Works? Cited).*/ /i;

    #clear some global variables
    @split_text = ();
    @acronym_list = ();

    return &acronyms_from_clean_text($processed_text);
}

sub acronyms_from_clean_text {
    my ($processed_text) = @_;

    @split_text = split / /, $$processed_text;

#    my $i = 0;
#    while ($i <= $#split_text)
#    {
#	print $split_text[$i] . "\n";
#	$i++;
#    }

    my $first = 0;
    my $last = $#split_text +1;
    my $acro_counter = $first;
    
    while ($acro_counter < $last)
    {
	my $word = $split_text[$acro_counter];

	if ((!$upper_case) ||
	    (uc($word) eq $word))
	{
	    
	    if (length $word >= $min_acro_length)
	    {
		my $def_counter = 0;
		if ($acro_counter - $max_offset > 0)
		{
		    $def_counter = $acro_counter - $max_offset;
		}
		my $local_last = $acro_counter  + $max_offset;
		if ($local_last > $last)
		{
		    $local_last = $last;
		}
		while ($def_counter <= $local_last)
		{
		    &recurse($acro_counter,$def_counter,0,());
		    $def_counter++;
		}
	    }
	}
	$acro_counter++;
    }

    return \@acronym_list;
}



sub test {

#    my $blarg = new acronym();
#    my $simple;
#    $simple = 10;
#    $blarg->initialise($simple, $simple, $simple);
#    my $blarg2 = $blarg->clone();
#    print $blarg->to_string();
#    print $blarg2;
#    print "\n";
#    
    my $tla = new acronym();
    $tla->[0] = "TLA";

    my @array = ("Three", "Letter", "Acronym");
#    my $i = 0;
#    while ($i <= $#array)
#    {
#	print @array[$i] . "\n";
#	$i++;
#    }

    print "\n";
    push @{$tla->[1]}, ("Three" );
    push @{$tla->[1]}, ("Letter" );
    push @{$tla->[1]}, ("Acronym" );
    print $tla->to_string(). "\n";
    print "\n";
    print "\n";
    my $tla2 = $tla->clone();
    push @{$tla2->[1]}, ("One");
    push @{$tla2->[1]}, ("Two");
    $tla2->[0] = "ALT";
    print $tla->to_string(). "\n";
    print $tla2->to_string(). "\n";

    print "\n";
    print "\n";

    print "Testing recursion ...\n";
    my $acros = &acronyms("TLA Three Letter Acronym in tla TlA");
    
    foreach my $acro (@$acros)
    {
	if ($acro->check)
        {
           print "accepted: " .$acro->to_string() . "\n";
#           print "|" .  $acro->to_acronym() . "|" .  $acro->to_def_string() .
#              "|" .  $acro->words_in_acronym_definition() .
#              "|" .  $acro->letters_in_acronym_definition() . 
#              "|" .  $acro->letters_in_acronym() . "|\n";
        } else {
#          print "found but rejected: " .$acro->to_string() . "\n";
        }
    }
}

#uncomment this line to test this package
#&test();

1;


