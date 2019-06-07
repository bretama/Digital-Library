#!/usr/bin/perl -w

###########################################################################
#
# gti-process-google-spreadsheet.pl
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


# This script takes a spreadsheet of 3 columns: the key, English, <translated language>
# and returns XML that Greenstone likes.
# Use of this file and where it fits in the processing of translation files is
# explained in gti-xml-to-spreadsheet.xsl (and gti-tmx-to-spreadsheet.xsl).


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
    close(EXCEL_TXT_FILE);

    print STDERR "Number of chunks: " . scalar(@excel_txt_file_lines) . "\n";
    shift(@excel_txt_file_lines);  # Ignore the header row (Key Source Target)

    # Process each submitted chunk, row by row
    foreach my $chunk (@excel_txt_file_lines) {

	# Remove any nasty carriage returns (especially at the end of each row/line)
	$chunk =~ s/\r//;
	# Just in case the newline at the end of each line is not /r but /n
	$chunk =~ s/\n//;

	#print STDOUT "**** chunk: $chunk\n";

	# each Excel row's 3 fields are delimited by tabs not commas
	my ($key, $source, $target) = split(/\t/, $chunk);

	# Remove the quotes around multiline chunks
 	if ($source =~ /^\"/ && $source =~ /\"$/) {
 	    $source =~ s/^\"//;
 	    $source =~ s/\"$//;
 	}
 	if ($target =~ /^\"/ && $target =~ /\"$/) {
 	    $target =~ s/^\"//;
 	    $target =~ s/\"$//;
 	}

        # Legacy: trim any leading blank space
 	$source =~ s/^ //g;
 	$target =~ s/^ //g;

 	# Remove Excel's doubled-up quotes
 	$source =~ s/\"\"/\"/g;
 	$target =~ s/\"\"/\"/g;

	# replace html entity for newline with actual newline 
	# No longer need to replace commas (&#44;) and double-quotes (&#34;) here, because 
	# gti-xml-to-spreadsheet.xslt doesn't insert entities for those anymore.
	# http://www.w3.org/MarkUp/html3/latin1.html
	$source =~ s/&#10;/\n/g;
	$target =~ s/&#10;/\n/g;

	#print STDOUT "***** key: $key\n";
	#print STDOUT "***** \tsource: $source\n";
	#print STDOUT "***** \ttarget: $target\n\n";

	print "<SourceFileText key=\"source::" . $key . "\">\n" . $source . "\n</SourceFileText>\n";
 	print "<TargetFileText key=\"target::" . $key . "\">\n" . $target . "\n</TargetFileText>\n";

    }
}


&main(@ARGV);
