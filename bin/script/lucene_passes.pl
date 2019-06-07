#!/usr/bin/perl -w

###########################################################################
#
# lucene_passes.pl -- perl wrapper, akin to mgpp_passes, for Lucene
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
use FileUtils;

sub open_java_lucene
{
  my ($doc_tag_level,$full_builddir,$indexdir,$java_lucene_options) = @_;

  # Is there a collection-specific bin/java/LuceneWrapper4.jar file?
  my $bin_java = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"bin","java");
  my $classpath = &FileUtils::javaFilenameConcatenate($bin_java,"LuceneWrapper4.jar");
  if (!-f $classpath)
  {
      # No, so use the Greenstone one
      $bin_java = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin","java");
      $classpath = &FileUtils::javaFilenameConcatenate($bin_java,"LuceneWrapper4.jar");
      if(!-f $classpath) {
	  die "***** ERROR: $classpath does not exist\n";	  
      }
  }

  $full_builddir = &util::makeFilenameJavaCygwinCompatible($full_builddir);

  my $java_lucene = "java -classpath \"$classpath\" org.greenstone.LuceneWrapper4.GS2LuceneIndexer";
  my $java_cmd = "$java_lucene $java_lucene_options $doc_tag_level \"$full_builddir\" $indexdir";

  open (PIPEOUT, "| $java_cmd") or die "lucene_passes.pl - couldn't run $java_cmd\n";
}


sub close_java_lucene
{
  close(PIPEOUT);
}


sub save_xml_doc
{
    my ($full_textdir,$output_filename,$doc_xml) = @_;

    my $dir_sep = &util::get_os_dirsep();

    my $full_output_filename = &FileUtils::filenameConcatenate($full_textdir,$output_filename);
    my ($full_output_dir) = ($full_output_filename =~ m/^(.*$dir_sep)/x);
    &FileUtils::makeAllDirectories($full_output_dir);

    open(DOCOUT,">$full_output_filename")
	|| die "Unable to open $full_output_filename";

    print DOCOUT $doc_xml;
    close(DOCOUT);

    my @secs =  ($doc_xml =~ m/<Sec\s+gs2:id="\d+"\s*>.*?<\/Sec>/sg);
}


sub compress_xml_doc
{
    my ($full_textdir,$output_filename) = @_;

    my $full_output_filename
	= &FileUtils::filenameConcatenate($full_textdir,$output_filename);

    `gzip $full_output_filename`;
}


# This appears to be the callback that gets the xml stream during the
# build process, so I need to intercept it here and call my XML RPC
# to insert into the Lucene database.
sub monitor_xml_stream
{
    my ($mode, $full_textdir) = @_;

    my $doc_xml = "";
    my $output_filename = "";

    my $line;
    while (defined ($line = <STDIN>)) {
	$doc_xml .= $line;
	if ($line =~ m/^<Doc.+file=\"(.*?)\".*>$/) {
	    $output_filename = $1;
	    #change the filename to doc.xml, keeping any path
	    $output_filename = &util::filename_head($output_filename);
	    $output_filename = &util::filename_cat($output_filename, "doc.xml");
	}
	
	if ($line =~ m/^<\/Doc>$/) {
	    if ($mode eq "text") {
		save_xml_doc($full_textdir,$output_filename,$doc_xml);
	    } elsif ($mode eq "index") {
		# notify lucene indexer

		# SAX parser seems to be sensitive to blank lines
		# => remove them
		$doc_xml =~ s/\n+/\n/g;

#		 print STDERR $doc_xml;

##	    print PIPEOUT "$output_filename\n";

		print PIPEOUT "$doc_xml";


		#save_xml_doc($full_textdir, "$output_filename.txt", $doc_xml);
	    }
	    # compress file
###	    compress_xml_doc($full_textdir,$output_filename);

	    $doc_xml = "";
	    $output_filename = "";
	}
    }
}


# /** This checks the arguments on the command line, filters the
#  *  unknown command line arguments and then calls the open_java_lucene
#  *  function to begin processing. Most of the arguments are passed on
#  *  the command line of the java wrapper.
#  *
#  */
sub main
{
  my (@argv) = @_;
  my $argc = scalar(@argv);

  my $java_lucene_options = "";
  my @filtered_argv = ();

  my $i = 0;
  while ($i<$argc) {
    if ($argv[$i] =~ m/^\-(.*)$/) {

      my $option = $1;

      # -removeold causes the existing index to be overwritten
      if ($option eq "removeold") {
        print STDERR "\n-removeold set\n";
        $java_lucene_options .= "-removeold ";
      }
      # -verbosity <num>
      elsif ($option eq "verbosity") {
        $i++;
        if ($i<$argc)
	{
	  $java_lucene_options .= "-verbosity " . $argv[$i];
        }
      }
      else {
        print STDERR "Unrecognised minus option: -$option\n";
      }
    }
    else {
        push(@filtered_argv,$argv[$i]);
    }
    $i++;
  }

  my $filtered_argc = scalar(@filtered_argv);

  if ($filtered_argc < 4) {
    print STDERR "Usage: lucene_passes.pl [-removeold|-verbosity num] \"text\"|\"index\" doc-tag-level build-dir index-name\n";
    exit 1;
  }

  my $mode = $filtered_argv[0];
  my $doc_tag_level = $filtered_argv[1];
  my $full_builddir = $filtered_argv[2];
  my $indexdir      = $filtered_argv[3];
###    print STDERR "**** ARGS = ", join(" ", @argv), "\n";

  # We only need the Lucene handle opened if we are indexing the documents, not if we are just storing the text
  if ($mode eq "index") {
    open_java_lucene($doc_tag_level, $full_builddir, $indexdir, $java_lucene_options);
  }

  print STDERR "Monitoring for input!\n";
  my $full_textdir = &FileUtils::filenameConcatenate($full_builddir,"text");

  monitor_xml_stream($mode, $full_textdir);

  if ($mode eq "index") {
    close_java_lucene();
  }
}


&main(@ARGV);
