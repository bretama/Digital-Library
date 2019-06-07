###########################################################################
#
# MetadataCSVPlugin.pm -- A plugin for metadata in comma-separated value format
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 2006 New Zealand Digital Library Project
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

package MetadataCSVPlugin;


use BaseImporter;
use MetadataRead;

use strict;
no strict 'refs';

use extrametautil;
use multiread;
use util;

use Encode;

# methods with identical signatures take precedence in the order given in the ISA list.
sub BEGIN {
    @MetadataCSVPlugin::ISA = ('MetadataRead', 'BaseImporter');
}


my $arguments = [
      { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() }

];


my $options = { 'name'     => "MetadataCSVPlugin",
		'desc'     => "{MetadataCSVPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new
{
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}


sub get_default_process_exp
{
    return q^(?i)\.csv$^;
}

sub file_block_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    if (!-f $filename_full_path || !$self->can_process_this_file($filename_full_path)) {
	return undef; # can't recognise
    }

    # set this so we know this is a metadata file - needed for incremental 
    # build
    # if this file changes, then we need to reimport everything
    $block_hash->{'metadata_files'}->{$filename_full_path} = 1;

    return 1;
}

sub metadata_read
{
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    # Read metadata from CSV files
    my $filename = &util::filename_cat($base_dir, $file);
    if ($filename !~ /\.csv$/ || !-f $filename) {
	return undef;
    }
    print STDERR "\n<Processing n='$file' p='MetadataCSVPlugin'>\n" if ($gli);
    print STDERR "MetadataCSVPlugin: processing $file\n" if ($self->{'verbosity'}) > 1;

    my $outhandle = $self->{'outhandle'};
    my $failhandle = $self->{'failhandle'};

    # add the file to the block list so that it won't be processed in read, as we will do all we can with it here
    $self->block_raw_filename($block_hash,$filename);


    # Read the CSV file to get the metadata
    my $csv_file_content;
    open(CSV_FILE, "$filename");
    my $csv_file_reader = new multiread();
    $csv_file_reader->set_handle('MetadataCSVPlugin::CSV_FILE');
    $csv_file_reader->read_file(\$csv_file_content);

    # Would be nice if MetadataCSVPlugin was extended to support a minus
    # option to choose the character encoding the CSV file is in 
    # For now we will assume it is always in UTF8
    $csv_file_content = decode("utf8",$csv_file_content);

    close(CSV_FILE);

    # Split the file into lines and read the first line (contains the metadata names)
    $csv_file_content =~ s/\r/\n/g;  # Handle non-Unix line endings
    $csv_file_content =~ s/\n+/\n/g;
    my @csv_file_lines = split(/\n/, $csv_file_content);
    my $csv_file_field_line = shift(@csv_file_lines);
    my @csv_file_fields = split(/\,/, $csv_file_field_line);
    my $found_filename_field = 0;
    for (my $i = 0; $i < scalar(@csv_file_fields); $i++) {
	# Remove any spaces from the field names, and surrounding quotes too
	$csv_file_fields[$i] =~ s/ //g;
	$csv_file_fields[$i] =~ s/^"//;
	$csv_file_fields[$i] =~ s/"$//;

	if ($csv_file_fields[$i] eq "Filename") {
	    $found_filename_field = 1;
	}
    }

    if (!$found_filename_field) {
	$self->print_error($outhandle, $failhandle, $gli, $filename, "No Filename field in CSV file");
	return -1; # error
    }
    # Read each line of the file and assign the metadata appropriately
    foreach my $csv_line (@csv_file_lines) {
	# Ignore lines containing only whitespace
	next if ($csv_line =~ /^\s*$/);
	my $orig_csv_line = $csv_line;
	# Build a hash of metadata name to metadata value for this line
	my %csv_line_metadata;
	my $i = 0;
	$csv_line .= ",";  # To make the regular expressions simpler
	while ($csv_line ne "") {
	    # Metadata values containing commas are quoted
	    if ($csv_line =~ s/^\"(.*?)\"\,//) {
		# Only bother with non-empty values
		if ($1 ne "" && defined($csv_file_fields[$i])) {
		    if (!defined $csv_line_metadata{$csv_file_fields[$i]}) {
			$csv_line_metadata{$csv_file_fields[$i]} = [];
		    }
		    push (@{$csv_line_metadata{$csv_file_fields[$i]}}, $1);
		}
	    }
	    # Normal comma-separated case
	    elsif ($csv_line =~ s/^(.*?)\,//) {
		# Only bother with non-empty values
		if ($1 ne "" && defined($csv_file_fields[$i])) {
		    if (!defined $csv_line_metadata{$csv_file_fields[$i]}) {
			$csv_line_metadata{$csv_file_fields[$i]} = [];
		    }
		    # remove any surrounding quotes. (When exporting to CSV, some spreadsheet
		    # programs add quotes even around field values that don't contain commas.)
		    my $value = $1;
		    $value =~ s/^"//;
		    $value =~ s/"$//;
		    push (@{$csv_line_metadata{$csv_file_fields[$i]}}, $value);
		}
	    }
	    # The line must be formatted incorrectly
	    else {
		$self->print_error($outhandle, $failhandle, $gli, $filename, "Badly formatted CSV line: $csv_line");
		last;
	    }

	    $i++;
	}

	# We can't associate any metadata without knowing the file to associate it with
	my $csv_line_filename_array = $csv_line_metadata{"Filename"};
	if (!defined $csv_line_filename_array) {
	    $self->print_error($outhandle, $failhandle, $gli, $filename, "No Filename metadata in CSV line: $orig_csv_line");
	    next;
	}
	my $csv_line_filename = shift(@$csv_line_filename_array);
	delete $csv_line_metadata{"Filename"};


 	# Associate the metadata now
	# Indexing into the extrameta data structures requires the filename's style of slashes to be in URL format
	# Then need to convert the filename to a regex, no longer to protect windows directory chars \, but for
	# protecting special characters like brackets in the filepath such as "C:\Program Files (x86)\Greenstone".
	$csv_line_filename = &util::filepath_to_url_format($csv_line_filename);
	$csv_line_filename = &util::filename_to_regex($csv_line_filename);

	if (defined &extrametautil::getmetadata($extrametadata, $csv_line_filename)) { # merge with existing meta    

	    my $file_metadata_table = &extrametautil::getmetadata($extrametadata, $csv_line_filename);
	    
	    foreach my $metaname (keys %csv_line_metadata) {
		# will create new entry if one does not already exist
		push(@{$file_metadata_table->{$metaname}}, @{$csv_line_metadata{$metaname}});	    
	    }
	    
	    # no need to push $file on to $extrametakeys as it is already in the list
	} else { # add as new meta
	    
	    &extrametautil::setmetadata($extrametadata, $csv_line_filename, \%csv_line_metadata);
	    &extrametautil::addmetakey($extrametakeys, $csv_line_filename);
	}
	# record which file the metadata came from 
	if (!defined &extrametautil::getmetafile($extrametafile, $csv_line_filename)) {
	    &extrametautil::setmetafile($extrametafile, $csv_line_filename, {});
	}
	# maps the file to full path
	&extrametautil::setmetafile_for_named_file($extrametafile, $csv_line_filename, $file, $filename);
    }
}

sub print_error
{

    my $self = shift(@_);
    my ($outhandle, $failhandle, $gli, $file, $error) = @_;

    print $outhandle "MetadataCSVPlugin Error: $file: $error\n";
    print $failhandle "MetadataCSVPlugin Error: $file: $error\n";
    print STDERR "<ProcessingError n='$file' r='$error'/>\n" if ($gli);
}
1;
