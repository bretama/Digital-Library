###########################################################################
#
# ISISPlugin.pm -- A plugin for CDS/ISIS databases
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

package ISISPlugin;

use Encode;

use multiread;
use SplitTextFile;
use MetadataRead;
use FileUtils;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# ISISPlugin is a sub-class of SplitTextFile.
# methods with identical signatures take precedence in the order given in the ISA list.
sub BEGIN {
    @ISISPlugin::ISA = ('MetadataRead', 'SplitTextFile');
}


my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_block_exp(),
	'hiddengli' => "yes" },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_split_exp(),
        'hiddengli' => "yes" },

      # The interesting options
      { 'name' => "entry_separator",
	'desc' => "{ISISPlugin.entry_separator}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "<br>" },
      { 'name' => "subfield_separator",
	'desc' => "{ISISPlugin.subfield_separator}",
	'type' => "string",
	'reqd' => "no",
	'deft' => ", " }
      ];

my $options = { 'name'     => "ISISPlugin",
		'desc'     => "{ISISPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };


# This plugin processes files with the suffix ".mst"
sub get_default_process_exp {
    return q^(?i)(\.mst)$^;
}


# This plugin blocks files with the suffix ".fdt" and ".xrf"
sub get_default_block_exp {
    return q^(?i)(\.fdt|\.xrf)$^;
    #return "";
}

    
# This plugin splits the input text at the "----------" lines
sub get_default_split_exp {
    return q^\r?\n----------\r?\n^;
}


sub new
{
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    # isis plug doesn't care about encoding - it assumes ascii unless the user
    # has specified an encoding
    if ($self->{'input_encoding'} eq "auto") {
	$self->{'input_encoding'} = "ascii";
    }
    return bless $self, $class;
}

# we block the corresponding fdt and xrf
# a pain on windows. blocks xxx.FDT, but if actual file is xx.fdt then 
# complains that no plugin can process it. Have put it back to using 
# block exp for now
# This works now, as are doing case insenstive blocking on windows. However,
# a pain for GLI as will not know what plugin processes the fdt and xrf.
# if add to process expression, then get more problems.
sub store_block_files_tmp {
    
    my $self =shift (@_);
    my ($filename_full_path, $block_hash) = @_;
    print STDERR "in store block files\n";
    $self->check_auxiliary_files($filename_full_path);
    if (-e $self->{'fdt_file_path'}) {
	print STDERR "$self->{'fdt_file_path'}\n";
	my $fdt_file = $self->{'fdt_file_path'};
	$self->block_raw_filename($block_hash,$fdt_file);
    }
    if (-e $self->{'xrf_file_path'}) {
	print STDERR "$self->{'xrf_file_path'}\n";
	my $xrf_file = $self->{'xrf_file_path'};
	$self->block_raw_filename($block_hash,$xrf_file);
    }
    

}

sub check_auxiliary_files {
    my $self = shift (@_);
    my ($filename) = @_;

    my ($database_file_path_root) = ($filename =~ /(.*)\.mst$/i);
    # Check the associated .fdt and .xrf files exist
    $self->{'fdt_file_path'} = $database_file_path_root . ".FDT";
    if (!-e $self->{'fdt_file_path'}) {
	$self->{'fdt_file_path'} = $database_file_path_root . ".fdt";
    }
    $self->{'xrf_file_path'} = $database_file_path_root . ".XRF";
    if (!-e $self->{'xrf_file_path'}) {
	$self->{'xrf_file_path'} = $database_file_path_root . ".xrf";
    }
}
    

sub read_file
{
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;
    my $outhandle = $self->{'outhandle'};

    my ($database_file_path_root) = ($filename =~ /(.*)\.mst$/i);
    my $mst_file_path_relative = $filename;
    $mst_file_path_relative =~ s/^.+import.(.*?)$/$1/;

    # Check the associated .fdt and .xrf files exist
    $self->check_auxiliary_files($filename);
    
    if (!-e $self->{'fdt_file_path'}) {
	print STDERR "<ProcessingError n='$mst_file_path_relative' r='Could not find ISIS FDT file $self->{'fdt_file_path'}'>\n" if ($self->{'gli'});
	print $outhandle "Error: Could not find ISIS FDT file " . $self->{'fdt_file_path'} . ".\n";
	return;
    }
    if (!-e $self->{'xrf_file_path'}) {
	print STDERR "<ProcessingError n='$mst_file_path_relative' r='Could not find ISIS XRF file $self->{'xrf_file_path'}'>\n" if ($self->{'gli'});
	print $outhandle "Error: Could not find ISIS XRF file " . $self->{'xrf_file_path'} . ".\n";
	return;
    }

    # The text to split is exported from the database by the IsisGdl program
    open(FILE, "IsisGdl \"$filename\" |");

    my $reader = new multiread();
    $reader->set_handle('ISISPlugin::FILE');
    $reader->set_encoding($encoding);
    $reader->read_file($textref);

	# At this point $$textref is a binary byte string
    # => turn it into a Unicode aware string, so full
    # Unicode aware pattern matching can be used.
    # For instance: 's/\x{0101}//g' or '[[:upper:]]'
    # 

    $$textref = decode("utf8",$$textref);
    close(FILE);

    # Parse the associated ISIS database Field Definition Table file (.fdt)
    my %fdt_mapping = &parse_field_definition_table($self->{'fdt_file_path'}, $encoding);
    $self->{'fdt_mapping'} = \%fdt_mapping;

    # Remove the line at the start, and any blank lines, so the data is split and processed properly
    $$textref =~ s/^----------\r?\n//;
    $$textref =~ s/(\r|\n)\n/\n/g;
}


sub process
{
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    # store the auxiliary files so we know which ones were used
    # (mst file becomes the source file)
    $doc_obj->associate_source_file($self->{'fdt_file_path'});
    $doc_obj->associate_source_file($self->{'xrf_file_path'});

    my $section = $doc_obj->get_top_section();
    my $fdt_mapping = $self->{'fdt_mapping'};
    my $subfield_separator = $self->{'subfield_separator'};
    my $entry_separator = $self->{'entry_separator'};
    my $isis_record_html_metadata_value = "<table cellpadding=\"4\" cellspacing=\"0\">";

    # Process each line of the ISIS record, one at a time
    foreach my $line (split(/\n/, $$textref)) {
	$line =~ s/(\s*)$//;  # Remove any nasty whitespace (very important for Windows)
	$line =~ /^tag=(.*) data=(.+)$/;
	my $tag = $1;
	my $tag_data = $2;
        # print STDERR "\nTag: $tag, Data: $tag_data\n";

	# Convert the tag number into a name, and remove any invalid characters
	my $raw_metadata_name = $fdt_mapping->{$tag}{'name'} || "";
	$raw_metadata_name =~ s/[,&\#\.\-\/]/ /g;
	next if ($raw_metadata_name eq "");

	# Metadata field names: title case, then remove spaces
	my $metadata_name = "";
	foreach my $word (split(/\s+/, $raw_metadata_name)) {
	    substr($word, 0, 1) =~ tr/a-z/A-Z/;
	    $metadata_name .= $word;
	}

	my $all_metadata_name = $metadata_name . "^all";
	my $all_metadata_value = "";

	# Handle repeatable fields
	if ($fdt_mapping->{$tag}{'repeatable'}) {
	    # Multiple values are separated using the '%' character
	    foreach my $raw_metadata_value (split(/%/, $tag_data)) {
		my $metadata_value = "";

		# Handle subfields
		while ($raw_metadata_value ne "") {
		    # If there is a subfield specifier, parse it off
		    my $sub_metadata_name = $metadata_name;
		    if ($raw_metadata_value =~ s/^\^// && $raw_metadata_value =~ s/^([a-z])//) {
			$sub_metadata_name .= "^$1";
		    }

		    # Parse the value off and add it as metadata
		    $raw_metadata_value =~ s/^([^\^]*)//;
		    my $sub_metadata_value = &escape_metadata_value($1);

		    # print STDERR "Sub metadata name: $sub_metadata_name, value: $sub_metadata_value\n";
		    if ($sub_metadata_name ne $metadata_name) {
			$doc_obj->add_utf8_metadata($section, $sub_metadata_name, $sub_metadata_value); 
		    }

		    # If this tag has subfields and this is the first, use the value for the CDS/ISIS ^* field
		    if ($fdt_mapping->{$tag}{'subfields'} ne "" && $metadata_value eq "") {
			$doc_obj->add_utf8_metadata($section, $metadata_name . "^*", $sub_metadata_value); 
		    }

		    $metadata_value .= $subfield_separator unless ($metadata_value eq "");
		    $metadata_value .= $sub_metadata_value;
		}

		# Add the metadata value
		# print STDERR "Metadata name: $metadata_name, value: $metadata_value\n";
		$doc_obj->add_utf8_metadata($section, $metadata_name, $metadata_value); 

		$all_metadata_value .= $entry_separator unless ($all_metadata_value eq "");
		$all_metadata_value .= $metadata_value;
	    }
	}

	# Handle non-repeatable fields
	else {
	    my $raw_metadata_value = $tag_data;
	    my $metadata_value = "";

	    # Handle subfields
	    while ($raw_metadata_value ne "") {
		# If there is a subfield specifier, parse it off
		my $sub_metadata_name = $metadata_name;
		if ($raw_metadata_value =~ s/^\^// && $raw_metadata_value =~ s/^([a-z])//) {
		    $sub_metadata_name .= "^$1";
		}

		# Parse the value off and add it as metadata
		$raw_metadata_value =~ s/^([^\^]*)//;
		my $sub_metadata_value = $1;

		# Deal with the case when multiple values are specified using <...>
		if ($sub_metadata_value =~ /\<(.+)\>/) {
		    my $sub_sub_metadata_name = $sub_metadata_name . "^sub";
		    my $tmp_sub_metadata_value = $sub_metadata_value;
		    while ($tmp_sub_metadata_value =~ s/\<(.+?)\>//) {
			my $sub_sub_metadata_value = $1;
			$doc_obj->add_utf8_metadata($section, $sub_sub_metadata_name, $sub_sub_metadata_value); 
		    }
		}
		# Deal with the legacy case when multiple values are specified using /.../
		elsif ($sub_metadata_value =~ /\/(.+)\//) {
		    my $sub_sub_metadata_name = $sub_metadata_name . "^sub";
		    my $tmp_sub_metadata_value = $sub_metadata_value;
		    while ($tmp_sub_metadata_value =~ s/\/(.+?)\///) {
			my $sub_sub_metadata_value = $1;
			$doc_obj->add_utf8_metadata($section, $sub_sub_metadata_name, $sub_sub_metadata_value); 
		    }
		}

		# Escape the metadata value so it appears correctly in the final collection
		$sub_metadata_value = &escape_metadata_value($sub_metadata_value);

		# print STDERR "Sub metadata name: $sub_metadata_name, value: $sub_metadata_value\n";
		if ($sub_metadata_name ne $metadata_name) {
		    $doc_obj->add_utf8_metadata($section, $sub_metadata_name, $sub_metadata_value); 
		}

		# If this tag has subfields and this is the first, use the value for the CDS/ISIS ^* field
		if ($fdt_mapping->{$tag}{'subfields'} ne "" && $metadata_value eq "") {
		    $doc_obj->add_utf8_metadata($section, $metadata_name . "^*", $sub_metadata_value); 
		}

		$metadata_value .= $subfield_separator unless ($metadata_value eq "");
		$metadata_value .= $sub_metadata_value;
	    }

	    # Add the metadata value
	    # print STDERR "Metadata name: $metadata_name, value: $metadata_value\n";
	    $doc_obj->add_utf8_metadata($section, $metadata_name, $metadata_value); 

	    $all_metadata_value .= $entry_separator unless ($all_metadata_value eq "");
	    $all_metadata_value .= $metadata_value;
	}

	# Add the "^all" metadata value
	# print STDERR "All metadata name: $all_metadata_name, value: $all_metadata_value\n";
	$doc_obj->add_utf8_metadata($section, $all_metadata_name, $all_metadata_value); 

	$isis_record_html_metadata_value .= "<tr><td valign=top><nobr><b>" . $fdt_mapping->{$tag}{'name'} . "</b></nobr></td><td valign=top>" . $all_metadata_value . "</td></tr>";
    }

    # Add a reasonably formatted HTML table view of the record as the document text
    $isis_record_html_metadata_value .= "</table>";
    $doc_obj->add_utf8_text($section, $isis_record_html_metadata_value);

    # Add the full raw record as metadata
    my $isis_raw_record_metadata_value = &escape_metadata_value($$textref);
    $doc_obj->add_utf8_metadata($section, "ISISRawRecord", $isis_raw_record_metadata_value);

    # Add FileFormat metadata
    $doc_obj->add_utf8_metadata($section, "FileFormat", "CDS/ISIS");

    # Record was processed successfully
    return 1;
}


sub parse_field_definition_table
{
    my $fdtfilename = shift(@_);
    my $encoding = shift(@_);

    my %fdtmapping = ();

    open(FDT_FILE, "<$fdtfilename") || die "Error: Could not open file $fdtfilename.\n";

    my $fdtfiletext = "";
    my $reader = new multiread();
    $reader->set_handle('ISISPlugin::FDT_FILE');
    $reader->set_encoding($encoding);
    $reader->read_file($fdtfiletext);

    my $amongstdefinitions = 0;
    foreach my $fdtfileline (split(/\n/, $$fdtfiletext)) {
	$fdtfileline =~ s/(\s*)$//;  # Remove any nasty spaces at the end of the lines

	if ($amongstdefinitions) {
	    my $fieldname      = &unicode::substr($fdtfileline,  0, 30);
	    my $fieldsubfields = &unicode::substr($fdtfileline, 30, 20);
	    my $fieldspecs     = &unicode::substr($fdtfileline, 50, 50);

	    # Remove extra spaces
	    $fieldname =~ s/(\s*)$//;
	    $fieldsubfields =~ s/(\s*)$//;
	    $fieldspecs =~ s/(\s*)$//;

	    # Map from tag number to metadata field title, subfields, and repeatability
	    my $fieldtag = (split(/ /, $fieldspecs))[0];
	    my $fieldrepeatable = (split(/ /, $fieldspecs))[3];
	    $fdtmapping{$fieldtag} = { 'name' => $fieldname,
				       'subfields' => $fieldsubfields,
				       'repeatable' => $fieldrepeatable };
	}
	elsif ($fdtfileline eq "***") {
	    $amongstdefinitions = 1;
	}
    }

    close(FDT_FILE);

    return %fdtmapping;
}


sub escape_metadata_value
{
    my $value = shift(@_);
    $value =~ s/\</&lt;/g;
    $value =~ s/\>/&gt;/g;
    $value =~ s/\\/\\\\/g;
    return $value;
}


sub clean_up_after_exploding
{
    my $self = shift(@_);

    # Delete the FDT and XRF files too
    &FileUtils::removeFiles($self->{'fdt_file_path'});
    &FileUtils::removeFiles($self->{'xrf_file_path'});
}


1;
