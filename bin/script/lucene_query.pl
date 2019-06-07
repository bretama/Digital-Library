#!/usr/bin/perl -w

###########################################################################
#
# lucene_query.pl -- perl wrapper to initiate query using Lucene
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


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use strict;
use util;

my $PROGNAME = $0;
$PROGNAME =~ s/^.*\/(.*)$/$1/;


sub get_java_path()
{
    # Check the JAVA_HOME environment variable first
    if (defined $ENV{'JAVA_HOME'}) {
	my $java_home = $ENV{'JAVA_HOME'};
	$java_home =~ s/\/$//;  # Remove trailing slash if present (Unix specific)
	return &util::filename_cat($java_home, "bin", "java");
    }
    elsif (defined $ENV{'JRE_HOME'}) {
	my $jre_home = $ENV{'JRE_HOME'};
	$jre_home =~ s/\/$//;  # Remove trailing slash if present (Unix specific)
	return &util::filename_cat($jre_home, "bin", "java");
    }

    # Hope that Java is on the PATH
    return "java";
}

sub open_java_lucene
{
    my $full_indexdir = shift(@_);
    my $fuzziness = shift(@_);
    my $filter_string = shift(@_);
    my $sort_field = shift(@_);
    my $reverse_sort = shift(@_);
    my $dco = shift(@_);
    my $start_results = shift(@_);
    my $end_results = shift(@_);
    my $out_file = shift(@_);

    my $java = &get_java_path();
    my $classpath = &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java", "LuceneWrapper4.jar");
    my $java_lucene = "\"$java\" -classpath \"$classpath\" org.greenstone.LuceneWrapper4.GS2LuceneQuery";

    my $cmd = "| " . $java_lucene . " \"" . $full_indexdir . "\"";
    if (defined($fuzziness)) {
        $cmd .= " -fuzziness " . $fuzziness;
    }
    if (defined($filter_string)) {
	$cmd .= " -filter \"" . $filter_string . "\"";
    }
    if (defined($sort_field)) {
        $cmd .= " -sort " . $sort_field;
    }
    if ($reverse_sort) {
	$cmd .= " -reverse_sort";
    }
    if (defined($dco)) {
        $cmd .= " -dco " . $dco;
    }
    if (defined($start_results)) {
        $cmd .= " -startresults " . $start_results;
    }
    if (defined($end_results)) {
        $cmd .= " -endresults " . $end_results;
    }
    if (defined($out_file)) {
	$cmd .= " > \"" . $out_file . "\"";
    }
     print STDERR $cmd . "\n";

    if (!open (PIPEOUT, $cmd)) {
	die "$PROGNAME - couldn't run $cmd\n";
    }
}

sub close_java_lucene
{
    close(PIPEOUT);
}

sub main
{
    my (@argv) = @_;
    my $argc = scalar(@argv);
    if ($argc == 0) {
	print STDERR "Usage: $PROGNAME full-index-dir [query] [-fuzziness value] [-filter filter_string] [-sort sort_field] [-reverse_sort]  [-dco AND|OR] [-startresults number -endresults number] [-out out_file]\n";
	exit 1;
    }

    my $full_indexdir = shift(@argv);
    my $query = undef;
    my $fuzziness = undef;
    my $filter_string = undef;
    my $sort_field = undef;
    my $reverse_sort = 0;
    my $dco = undef;
    my $start_results = undef;
    my $end_results = undef;
    my $out_file = undef;
    for (my $i = 0; $i < scalar(@argv); $i++)
    {
	if ($argv[$i] eq "-fuzziness") {
	    $i++;
	    $fuzziness = $argv[$i];
	}
        elsif ($argv[$i] eq "-filter") {
            $i++;
            $filter_string = $argv[$i];
	}
        elsif ($argv[$i] eq "-sort") {
            $i++;
            $sort_field = $argv[$i];
	}
	elsif ($argv[$i] eq "-reverse_sort") {
	    $reverse_sort = 1;
	}
        elsif ($argv[$i] eq "-dco") {
            $i++;
            $dco = $argv[$i];
	}
        elsif ($argv[$i] eq "-startresults") {
            $i++;
            $start_results = $argv[$i];
	}
        elsif ($argv[$i] eq "-endresults") {
            $i++;
            $end_results = $argv[$i];
	}
        elsif ($argv[$i] eq "-out") {
            $i++;
            $out_file = $argv[$i];
	}
        else {
            $query = $argv[$i];
	}
    }

    open_java_lucene($full_indexdir, $fuzziness, $filter_string, $sort_field, $reverse_sort, $dco, $start_results, $end_results, $out_file);

    if (defined $query) {
	print PIPEOUT "$query\n";
    }
    else {
	while (defined (my $line = <STDIN>)) {
	    print PIPEOUT $line;
	}
    }

    close_java_lucene();
}

&main(@ARGV);
