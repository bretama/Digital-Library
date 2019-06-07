###########################################################################
#
# ProCitePlugin.pm -- A plugin for (exported) ProCite databases
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 1999-2004 New Zealand Digital Library Project
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

package ProCitePlugin;


use multiread;
use SplitTextFile;
use MetadataRead;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# ProCitePlugin is a sub-class of SplitTextFile
sub BEGIN {
    @ProCitePlugin::ISA = ('MetadataRead', 'SplitTextFile');
}


my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'deft' => &get_default_split_exp(),
	'reqd' => "no" },
      
      # The interesting options
      { 'name' => "entry_separator",
	'desc' => "{ProCitePlugin.entry_separator}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "//" },
      ];

my $options = { 'name'     => "ProCitePlugin",
		'desc'     => "{ProCitePlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };


# This plugin processes exported ProCite files with the suffix ".txt"
sub get_default_process_exp
{
    return q^(?i)(\.txt)$^;
}


# This plugin splits the input text at every line
sub get_default_split_exp
{
    return q^\n^;
}


sub new
{
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}


my %crazy_workform_mapping =
    ( "A", "Book, Long Form",
      "B", "Book, Short Form",
      "C", "Journal, Long Form",
      "D", "Journal, Short Form",
      "E", "Report",
      "F", "Newspaper",
      "G", "Dissertation",
      "H", "Trade Catalog",
      "I", "Letter (Correspondence)",
      "J", "Manuscript",
      "K", "Conference Proceedings",
      "L", "Map",
      "M", "Music Score",
      "N", "Sound Recording",
      "O", "Motion Picture",
      "P", "Audiovisual Material",
      "Q", "Video Recording",
      "R", "Art Work",
      "S", "Computer Program",
      "T", "Data File" );


sub read_file
{
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;
    
    # Store the workform definitions for this file
    my %workform_definitions = ();

    # Read the contents of the file into $textref
    open(PROCITE_FILE, "<$filename");
    my $reader = new multiread();
    $reader->set_handle ('ProCitePlugin::PROCITE_FILE');
    $reader->set_encoding ($encoding);
    $reader->read_file ($textref);
    close(PROCITE_FILE);

    # Read the workform definitions at the start of the file
    while ($$textref =~ /^\<Workform Definition\>/) {
	# Remove the workform definition line so it is not processed later as a record
	$$textref =~ s/^\<Workform Definition\>(.*)\n//;
	my $workform_definition = $1;
	# Parse the workform definitions and store them for later
	$workform_definition =~ s/^\"([^\"]*)\",//;
	my $workform_name = $1;
	my @workform_values;
	while ($workform_definition !~ /^\s*$/) {
	    $workform_definition =~ s/^\"([^\"]*)\",?//;
	    my $workform_field = $1;
	    push(@workform_values, $workform_field);
	}
	
	# Remember this workform definition for when we're reading the records
	$workform_definitions{$workform_name} = \@workform_values;
    }

    $self->{'workform_definitions'}->{$filename} = \%workform_definitions;
}


sub process
{
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    my $filename = &util::filename_cat($base_dir, $file);
    my $cursection = $doc_obj->get_top_section();

    # Build up an HTML view of the record for easy display at run-time
    my $html_record = "<table>";

    # Read the record's workform indicator and record number
    #$$textref =~ s/^\"([^\"]*)\",\"([^\"]*)\",//;
    $$textref =~  s/^\"([^\"]*)\",//;
    my $workform_indicator = $1;

    # some procite files have a record number next
    
    my $recordnum = $$textref =~ s/^\"(\d*)\",//;
    $recordnum = "undefined" unless defined $recordnum;

    # If necessary, map the workform indicator into something useful
    if ($crazy_workform_mapping{$workform_indicator}) {
	$workform_indicator = $crazy_workform_mapping{$workform_indicator};
    }

    # Check we know about the workform of this record
    my %workform_definitions = %{$self->{'workform_definitions'}->{$filename}};
    if (!$workform_definitions{$workform_indicator}) {
	print STDERR "Unknown workform $workform_indicator!\n";
	return 0;
    }

    # Store the full record as the document text
    $doc_obj->add_utf8_text($cursection, $$textref);

    # Store workform and record number as metadata
    $doc_obj->add_utf8_metadata($cursection, "Workform", $workform_indicator);
    $doc_obj->add_utf8_metadata($cursection, "RecordNumber", $recordnum);
    
    # Store FileFormat metadata
    $doc_obj->add_metadata($cursection, "FileFormat", "ProCite");

    $html_record .= "<tr><td valign=top><b>Record Number: </b></td><td valign=top>$recordnum</td></tr>";

    my @workform_values = @{$workform_definitions{$workform_indicator}};

    # Read each field (surrounded by quotes) of the record
    my $fieldnum = 0;
    while ($$textref !~ /^\s*$/) {
	$$textref =~ s/^\"([^\"]*)\",?//;
	my $field_value_raw = $1;

	# Add non-empty metadata values to the document
	unless ($field_value_raw eq "") {
	    # Add the display name of the metadata field for format statement convenience
	    my $field_name = $workform_values[$fieldnum];
	    #unless ($field_name eq "---") {
	#	my $meta_name = "Field" . ($fieldnum + 1) . "Name";
	#	$doc_obj->add_utf8_metadata($cursection, $meta_name, $field_name);
	 #   }
	    if ($field_name eq "---") {
		$field_name = "Field" . ($fieldnum + 1);
	    }
	    $html_record .= "<tr><td valign=top><b>$field_name: </b></td><td valign=top>";

	    # Multiple metadata values are separated with "//"
	    #foreach my $field_value (split(/\/\//, $field_value_raw)) {
	    foreach my $field_value (split($self->{'entry_separator'}, $field_value_raw)) {
		#my $meta_name = "Field" . ($fieldnum + 1) . "Value";
		#$doc_obj->add_utf8_metadata($cursection, $meta_name, $field_value);
		$doc_obj->add_utf8_metadata($cursection, $field_name, $field_value);
		$html_record .= $field_value . "<br>";
	    }

	    $html_record .= "</td></tr>";
	}

	$fieldnum++;
    }

    $html_record .= "</table>";
    # Store HTML view of record as metadata
    $doc_obj->add_utf8_metadata($cursection, "HTMLDisplay", $html_record);

    # Record was processed successfully
    return 1;
}


1;
