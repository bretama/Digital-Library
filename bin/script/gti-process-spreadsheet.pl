#!/usr/bin/perl -w

###########################################################################
#
# gti-process-excel-xml.pl
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005 New Zealand Digital Library Project
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


use strict;


sub main
{
    # Required parameter: the path of the spreadsheet file saved in UTF-16 Excel text format
    my $utf16_excel_txt_file_path = shift(@_);
    if (!defined($utf16_excel_txt_file_path)) {
	die "Usage: gti-process-spreadsheet.pl <txt-file-path>\n";
    }

    # Ensure the UTF-16 Excel text file exists
    if (!-f $utf16_excel_txt_file_path) {
	die "Error: UTF-16 Excel text file $utf16_excel_txt_file_path does not exist.\n";
    }

    # Convert the Excel text file from UTF-16 to UTF-8
    my $excel_txt_file_path = $utf16_excel_txt_file_path . "-utf8";
    if (!-f $excel_txt_file_path) {
	# Only bother if the file doesn't already exist
	`iconv -f UTF-16 -t UTF-8 $utf16_excel_txt_file_path -o $excel_txt_file_path`;
    }

    # Read the (UTF-8) Excel Unicode text file data
    open(EXCEL_TXT_FILE, $excel_txt_file_path);
    my @excel_txt_file_lines = <EXCEL_TXT_FILE>;
    my $excel_txt_file_data = join("", @excel_txt_file_lines);
    close(EXCEL_TXT_FILE);

    # Remove any nasty carriage returns
    $excel_txt_file_data =~ s/\r//g;

    # Make sure the first line is where we want it, and remove all stray whitespace
    $excel_txt_file_data =~ s/^(\n)*/\n\n/;
    $excel_txt_file_data =~ s/\n(\s*)\n/\n\n/g;

    # Split into chunks
    my @chunks = split(/\n\nsource::/, $excel_txt_file_data);
    shift(@chunks);  # Ignore the first (empty) chunk
    print STDERR "Number of chunks: " . scalar(@chunks) . "\n";

    # Check we've split the chunks correctly
    my $total_number_of_chunks = ($excel_txt_file_data =~ s/source::/source::/g);
    if (scalar(@chunks) != $total_number_of_chunks) {
	die "Error: Expected $total_number_of_chunks chunks but only have " . scalar(@chunks) . " from splitting";
    }

    # Process each submitted chunk
    foreach my $chunk (@chunks) {
 	my $source_file_chunk = (split(/\ntarget::/, $chunk))[0];
 	my $target_file_chunk = (split(/\ntarget::/, $chunk))[1];

 	# Parse the chunk key and chunk text
 	$source_file_chunk =~ /^(\S+)\s+((.|\n)*)$/;
 	my $source_file_chunk_key = $1;
#	print STDERR "******** key: |$source_file_chunk_key| ";
 	my $source_file_chunk_text = $2;
#	print STDERR "******** text: |$source_file_chunk_text|\n";
 	$target_file_chunk =~ /^(\S+)\s+((.|\n)*)$/;
 	my $target_file_chunk_key = $1;
 	my $target_file_chunk_text = $2;

 	# Remove the quotes around multiline chunks
 	if ($source_file_chunk_text =~ /^\"/ && $source_file_chunk_text =~ /\"$/) {
#	    print STDERR "******** source text: |$source_file_chunk_text| \n";
 	    $source_file_chunk_text =~ s/^\"//;
 	    $source_file_chunk_text =~ s/\"$//;
 	}
 	if ($target_file_chunk_text =~ /^\"/ && $target_file_chunk_text =~ /\"$/) {
#	    print STDERR "******** target text: |$target_file_chunk_text| \n";
 	    $target_file_chunk_text =~ s/^\"//;
 	    $target_file_chunk_text =~ s/\"$//;
 	}
#	else {
#	    print STDERR "******** !target text: |$target_file_chunk_text| \n";
#	}

        # Remove the blank space Excel adds at the start of each line
 	$source_file_chunk_text =~ s/\n /\n/g;
 	$target_file_chunk_text =~ s/\n /\n/g;

 	# Remove Excel's doubled-up quotes
 	$source_file_chunk_text =~ s/\"\"/\"/g;
 	$target_file_chunk_text =~ s/\"\"/\"/g;

	# ensure newline html entities in the unicode txt file version of the spreadsheet are replaced with newlines
	$source_file_chunk_text =~ s/&#10; /\n/g;
	$target_file_chunk_text =~ s/&#10; /\n/g;

 	print "<SourceFileText key=\"" . $source_file_chunk_key . "\">\n" . $source_file_chunk_text . "\n</SourceFileText>\n";
 	print "<TargetFileText key=\"" . $target_file_chunk_key . "\">\n" . $target_file_chunk_text . "\n</TargetFileText>\n";
    }
}


&main(@ARGV);
