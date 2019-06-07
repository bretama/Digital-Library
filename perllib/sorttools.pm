###########################################################################
#
# sorttools.pm --
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

# various subroutines to format strings
# for sorting

package sorttools;

use strict;

# moved here from BasClas so import can share it
sub format_metadata_for_sorting {
    my ($metaname, $metavalue, $doc_obj) = @_;
    if (!defined $metaname || $metaname !~ /\S/ || ! defined $metavalue || $metavalue !~ /\S/) {
	return "";
    }

    if ($metaname eq "Language") {
	$metavalue = $iso639::fromiso639{$metavalue};
	return $metavalue;
    } 
    
    my $lang;
    if (defined $doc_obj) {
	$lang = $doc_obj->get_metadata_element ($doc_obj->get_top_section(), 'Language');
    }
    $lang = 'en' unless defined $lang;
    
    # is this metadata likely to be a name?
    my $function_name="format_string_name_$lang";
    if ($metaname =~ /^(?:\w+\.)?(?:Creators?|Authors?|Editors?)(?:[:,].*)?$/
	&& exists &$function_name) {
	no strict 'refs';
	&$function_name(\$metavalue);
    } else {
	$function_name="format_string_$lang";
	if (exists &$function_name) {
	    no strict 'refs';
	    &$function_name(\$metavalue);
	}
    }
    
    return $metavalue;
}

### language-specific sorting functions (called by format_metadata_for_sorting)

## format_string_$lang() converts to lowercase (where appropriate), and
# removes punctuation, articles from the start of string, etc
## format_string_name_$lang() converts to lowercase, puts the surname first,
# removes punctuation, etc

sub format_string_en {
    my $stringref = shift;
    $$stringref = lc($$stringref);
    $$stringref =~ s/&[^\;]+\;//g; # html entities
    $$stringref =~ s/^\s*(the|a|an)\b//; # articles
    $$stringref =~ s/[^[:alnum:]]//g;
    $$stringref =~ s/\s+/ /g;
    $$stringref =~ s/^\s+//;
    $$stringref =~ s/\s+$//;
}

sub format_string_name_en {
    my ($stringref) = @_;
    $$stringref =~ tr/A-Z/a-z/;
    $$stringref =~ s/&\S+;//g;

    my $comma_format = ($$stringref =~ m/^.+,.+$/);
    $$stringref =~ s/[[:punct:]]//g;
    $$stringref =~ s/\s+/ /g;
    $$stringref =~ s/^\s+//;
    $$stringref =~ s/\s+$//;

    
    if (!$comma_format) {
	# No commas in name => name in 'firstname surname' format
	# need to sort by surname
	my @names = split / /, $$stringref;
	my $surname = pop @names;
	while (scalar @names && $surname =~ /^(jnr|snr)$/i) {
	    $surname = pop @names;
	}
	$$stringref = $surname . " " . $$stringref;
    }
}


sub format_string_fr {
    my $stringref = shift;

    $$stringref = lc($$stringref);
    $$stringref =~ s/&[^\;]+\;//g; # html entities
    $$stringref =~ s/^\s*(les?|la|une?)\b//; # articles
    $$stringref =~ s/[^[:alnum:]]//g;
    $$stringref =~ s/\s+/ /g;
    $$stringref =~ s/^\s+//;
    $$stringref =~ s/\s+$//;
}

sub format_string_es {
    my $stringref = shift;

    $$stringref = lc($$stringref);
    $$stringref =~ s/&[^\;]+\;//g; # html entities
    $$stringref =~ s/^\s*(la|el)\b//; # articles
    $$stringref =~ s/[^[:alnum:]]//g;
    $$stringref =~ s/\s+/ /g;
    $$stringref =~ s/^\s+//;
    $$stringref =~ s/\s+$//;
}

### end of language-specific functions

# takes arguments of day, month, year and converts to
# date of form yyyymmdd. month may be full (e.g. "January"),
# abbreviated (e.g. "Jan"), or a number (1-12). Years like "86" 
# will be assumed to be "1986".
sub format_date {
    my ($day, $month, $year) = @_;

    my %months = ('january' => '01', 'jan' => '01', 'february' => '02', 'feb' => '02',
		  'march' => '03', 'mar' => '03', 'april' => '04', 'apr' => '04',
		  'may' => '05', 'june' => '06', 'jun' => '06', 'july' => '07', 
		  'jul' => '07', 'august' => '08', 'aug' => '08', 'september' => '09', 
		  'sep' => '09', 'october' => '10', 'oct' => '10', 'november' => '11', 
		  'nov' => '11', 'december' => '12', 'dec' => '12');

    $month =~ tr/A-Z/a-z/;
    
    if ($day < 1) { 
	print STDERR "sorttools::format_date WARNING day $day out of range\n";
	$day = "01";
    } elsif ($day > 31) {
	print STDERR "sorttools::format_date WARNING day $day out of range\n";
	$day = "31";
    }

    $day = "0$day" if (length($day) == 1);

    if ($month =~ /^\d\d?$/) {
	if ($month < 1) {
	    print STDERR "sorttools::format_date WARNING month $month out of range\n";
	    $month = "01";
	} elsif ($month > 12) {
	    print STDERR "sorttools::format_date WARNING month $month out of range\n";
	    $month = "12";
	}
	if ($month =~ /^\d$/) {
	    $month = "0" . $month;
	}
    } elsif (!defined $months{$month}) {
	print STDERR "sorttools::format_date WARNING month $month out of range\n";
	$month = "01";
    } else {
	$month = $months{$month};
    }
    
    if ($year !~ /^\d\d\d\d$/) {
	if ($year !~ /^\d\d$/) {
	    my $newyear = 1900 + $year;
	    print STDERR "sorttools::format_date WARNING year $year assumed to be $newyear\n";
	    $year=$newyear;
	} else {
	    print STDERR "sorttools::format_date WARNING year $year out of range - reset to 1900\n";
	    $year = "1900";
	}
    }

    return "$year$month$day";
}


1;
