###########################################################################
#
# EmbeddedMetadataPlugin.pm -- A plugin for EXIF
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 2007 New Zealand Digital Library Project
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


package EmbeddedMetadataPlugin;

use BaseImporter;
use extrametautil;
use util;

use Encode;
use Image::ExifTool qw(:Public);
use strict;

no strict 'refs'; # allow filehandles to be variables and viceversa


sub BEGIN
{
	@EmbeddedMetadataPlugin::ISA = ('BaseImporter');
	binmode(STDERR, ":utf8");
}

my $encoding_plus_auto_list = [{ 
		'name' => "auto",
		'desc' => "{ReadTextFile.input_encoding.auto}" }];
push(@{$encoding_plus_auto_list},@{$CommonUtil::encoding_list});

my $arguments = [{ 
	'name' => "metadata_field_separator",
	'desc' => "{HTMLPlugin.metadata_field_separator}",
	'type' => "string",
	'deft' => "" 
	},{ 
	'name' => "input_encoding",
	'desc' => "{ReadTextFile.input_encoding}",
	'type' => "enum",
	'list' => $encoding_plus_auto_list,
	'reqd' => "no",
	'deft' => "auto" 
	},{
	'name' => "join_before_split",
	'desc' => "{EmbeddedMetadataPlugin.join_before_split}",
	'type' => "flag"
	},{
	'name' => "join_character",
	'desc' => "{EmbeddedMetadataPlugin.join_character}",
	'type' => "string",
	'deft' => " "
	},{
	'name' => "trim_whitespace",
	'desc' => "{EmbeddedMetadataPlugin.trim_whitespace}",
	'type' => "enum",
	'list' => [{'name' => "true", 'desc' => "{common.true}"}, {'name' => "false", 'desc' => "{common.false}"}],
	'deft' => "true"
	},{
	'name' => "set_filter_list",
	'desc' => "{EmbeddedMetadataPlugin.set_filter_list}",
	'type' => "string"
	},{
	'name' => "set_filter_regexp",
	'desc' => "{EmbeddedMetadataPlugin.set_filter_regexp}",
	'type' => "string",
	'deft' => ".*" #If changing this default, also need to update the constructor
	}];

my $options = { 
	'name'     => "EmbeddedMetadataPlugin",
	'desc'     => "{EmbeddedMetadataPlugin.desc}",
	'abstract' => "no",
	'inherits' => "yes",
	'args'     => $arguments };

sub new()
{
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    if(defined $arguments){ push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});}
    if(defined $options) { push(@{$hashArgOptLists->{"OptList"}},$options)};

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    # Create a new Image::ExifTool object
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 0);
	$exifTool->Options(PrintConv => 0);
    $exifTool->Options(Unknown => 1);
    $exifTool->Options('Verbose');
    $self->{'exiftool'} = $exifTool;
	
	my $setFilterList = $self->{'set_filter_list'};
	my $setFilterRegexp = $self->{'set_filter_regexp'};
	if ((defined $setFilterList) && ($setFilterList ne ""))
	{
		if ((defined $setFilterRegexp) && ($setFilterRegexp ne ".*") && ($setFilterRegexp ne ""))
		{
			my $outhandle = $self->{'outhandle'};
			print $outhandle "Warning: can only specify 'set_filter_list' or 'set_filter_regexp'\n";
			print $outhandle "         defaulting to 'set_filter_list'\n";
		}

		my @sets = split(/,/,$setFilterList);
		my @sets_bracketed;
		foreach my $s (@sets)
		{
			$s =~ s/^(ex\.)?(.*)$/(ex.$2)/;
			push (@sets_bracketed, $s);
		}

		my $setFilterRegexp = join("|",@sets_bracketed);
		$self->{'set_filter_regexp'} = $setFilterRegexp;
	}

    return bless $self, $class;
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;


    # For most plugins, the metadata_read() phase either does not
    # exist, or is very fast at processing the files, and so is
    # not an undue burden on collection building.

    # EmbeddedMetadataPlugin bucks this trend, as the ExifTool module
    # it relies on needs to make a fairly detailed scan of the files
    # that match the plugin's process expression.  This has the
    # unfortunate side effect of hampering quick collection building
    # with '-maxdocs'.  It is therefore worth a bit of non-standard
    # "meddling" (as Anu would say) to help the special case of 
    # 'maxdocs' run more quickly.  
    #
    # The approach is to notice how many files EmbeddedMetadtaPlugin
    # has scanned, and once this reaches 'maxdocs' to then force the
    # can_process_this_file_for_metadata() method to always return the
    # answer 'not recognized' to prevent any further scanning.
    # Bacause 'maxdocs' is not one of the standard parameters passed
    # in to metadata_read() we need to store the value in the object
    # using this method so it can be used at the relevant place in the
    # code later on

    $self->{'maxdocs'} = $maxdocs;
    $self->{'exif_scanned_count'} = 0;

}


# Need to think some more about this
sub get_default_process_exp()
{
##    return ".*";
    q^(?i)\.(jpe?g|gif|png|tiff|pdf)$^;
}

# plugins that rely on more than process_exp (eg XML plugins) can override this method
sub can_process_this_file {
    my $self = shift(@_);

    # we process metadata, not the file 
    return 0;    
}

# Even if a plugin can extract metadata in its metadata_read pass,
# make the default return 'undef' so processing of the file continues
# down the pipeline, so other plugins can also have the opportunity to
# locate metadata and set it up in the extrametakeys variables that
# are passed around.

sub can_process_this_file_for_metadata {
    my $self = shift(@_);
    my ($filename) = (@_);

    # Want this plugin to look for metadata in the named file using
    # ExifTool through its metadata_read() function, as long as it
    # matches the process expression. But first there are a few
    # special cases to test for ...
    #

    if (-d $filename && !$self->{'can_process_directories'}) {
	return 0;
    }

    if ($self->{'maxdocs'} != -1) {
	$self->{'exif_scanned_count'}++;
	if ($self->{'exif_scanned_count'} > $self->{'maxdocs'}) {
	    # Above the limit of files to scan
	    return 0;
	}
    }


    if ($self->{'process_exp'} ne "" && $filename =~ /$self->{'process_exp'}/) {
	# Even though we say yes to this here, because we are using a custom
	# metadata_read() method in this plugin, we can also ensure the
	# file is considered by other plugins in the pipeline

	return 1;
    }

    # If we get to here then the answer is no for processing by this plugin
    # Note :because this plugin has its own custom metadata_read(), even
    #  though we return a 'no' here, this doesn't stop the file being
    #  considered by other plugins in the pipleline for metadata_read().  
    #  This is needed to ensure a file like metadata.xml (which would
    #  normally not be of interest to this plugin) is passed on to
    #  the plugin that does need to read it (MetadataPlugin in this case).

    return 0;
}

sub checkAgainstFilters
{
	my $self = shift(@_);
	my $name = shift(@_);
	
	my $setFilterRegexp = $self->{'set_filter_regexp'};
	if((defined $setFilterRegexp) && ($setFilterRegexp ne ""))
	{
		return ($name =~ m/($setFilterRegexp)/i);
	}
	else
	{
		return 1;
	}
}

sub filtered_add_metadata
{
    my $self = shift(@_);
    my ($field,$val,$exif_metadata_ref) = @_;

    my $count = 0;

    if ($self->checkAgainstFilters($field)) {
	push (@{$exif_metadata_ref->{$field}}, $self->gsSafe($val));
	$count++;


	if ($field =~ m/GPSPosition/) {
	    my ($lat,$long) = split(/\s+/,$val);
	    
	    push (@{$exif_metadata_ref->{"Longitude"}}, $self->gsSafe($long));
	    push (@{$exif_metadata_ref->{"Latitude"}}, $self->gsSafe($lat));
	    # 'count' keeps track of the number of items extracted from the file
	    # so for these 'on the side' values set, don't include them in 
	    # the count

	}


	if ($field =~ m/GPSDateTime/) {
	    my ($date,$time) = split(/\s+/,$val);

	    my ($yyyy,$mm,$dd) = ($date =~ m/^(\d{4}):(\d{2}):(\d{2})$/);

	    push (@{$exif_metadata_ref->{"Date"}}, $self->gsSafe("$yyyy$mm$dd"));
	    # as for Long/Lat don't need to increase 'count'

	}

    
    }

    return $count;
}


sub extractEmbeddedMetadata()
{
    my $self = shift(@_);
    my ($file, $filename, $extrametadata, $extrametakeys) = @_;
 
    my %exif_metadata = ();

    my $verbosity = $self->{'verbosity'};
    my $outhandle = $self->{'outhandle'};

    my $metadata_count = 0;
    
    my $separator = $self->{'metadata_field_separator'};
    if ($separator eq "") {
		undef $separator;
    }

    my @group_list = Image::ExifTool::GetAllGroups(0);
    foreach my $group (@group_list) {
##	print STDERR "**** group = $group\n";

		# Extract meta information from an image
		$self->{'exiftool'}->Options(Group0 => [$group]);
		$self->{'exiftool'}->ExtractInfo($filename);

		# Get list of tags in the order they were found in the file
		my @tag_list = $self->{'exiftool'}->GetFoundTags('File');
		foreach my $tag (@tag_list) {

            # Strip any numbering suffix
			$tag =~ s/^([^\s]+)\s.*$/$1/i;
			my $value = $self->{'exiftool'}->GetValue($tag);
			if (defined $value && $value =~ /[a-z0-9]+/i) {
				my $field = "ex.$group.$tag";
				
				my $encoding = $self->{'input_encoding'};
				if($encoding eq "auto")
				{
					$encoding = "utf8"
				}

				if (!defined $exif_metadata{$field})
				{
					$exif_metadata{$field} = [];
				}

				$field = Encode::decode($encoding,$field);
				my $metadata_done = 0;
				if (ref $value eq 'SCALAR') {
					if ($$value =~ /^Binary data/) {
						$value = "($$value)";
					}
                    else {
						my $len = length($$value);
						$value = "(Binary data $len bytes)";
					}
				}
				elsif (ref $value eq 'ARRAY') {
					$metadata_done = 1;
					
					my $allvals = "";
					foreach my $v (@$value) {
						$v = Encode::decode($encoding,$v);
						
						if(!$self->{'join_before_split'}){
							if (defined $separator) {
								my @vs = split($separator, $v);
								foreach my $val (@vs) {
									if ($val =~ /\S/) {
									    $metadata_count += $self->filtered_add_metadata($field,$val,\%exif_metadata);
									}
								}
							}
							else
							{
							    $metadata_count += $self->filtered_add_metadata($field,$v,\%exif_metadata);
							}
						}
						else{
							if($allvals ne ""){
								$allvals = $allvals . $self->{'join_character'};
							}
							$allvals = $allvals . $v;
						}
					}
					
					if($self->{'join_before_split'}){
						if (defined $separator) {
							my @vs = split($separator, $allvals);
							foreach my $val (@vs) {
								if ($val =~ /\S/) {
									    $metadata_count += $self->filtered_add_metadata($field,$val,\%exif_metadata);
								}
							}
						}
						else
						{
						    $metadata_count += $self->filtered_add_metadata($field,$allvals,\%exif_metadata);
						}
					}
				}
				else {
					$value = Encode::decode($encoding,$value);
					if (defined $separator) {
						my @vs = split($separator, $value);
						$metadata_done = 1;
						foreach my $v (@vs) {
							if ($v =~ /\S/) {
							    $metadata_count += $self->filtered_add_metadata($field,$v,\%exif_metadata);
							}
						}
					}
				}
				if (!$metadata_done) {
				    $metadata_count += $self->filtered_add_metadata($field,$value,\%exif_metadata);
				}
			}
		}
	}

    if ($metadata_count > 0) {
		print $outhandle " Extracted $metadata_count pieces of metadata from $filename EXIF block\n";
    }

    # Indexing into the extrameta data structures requires the filename's style of slashes to be in URL format
	# Then need to convert the filename to a regex, no longer to protect windows directory chars \, but for
	# protecting special characters like brackets in the filepath such as "C:\Program Files (x86)\Greenstone".
    print STDERR "file = $file " . &unicode::debug_unicode_string($file);
    $file = &util::raw_filename_to_unicode(&util::filename_head($filename), $file);
    print STDERR "$file ". &unicode::debug_unicode_string($file);
	$file = &util::filepath_to_url_format($file);
    print STDERR "$file " . &unicode::debug_unicode_string($file);
    $file = &util::filename_to_regex($file); 
    print STDERR "$file ".&unicode::debug_unicode_string($file) ."\n";
    
    # Associate the metadata now

    if (defined &extrametautil::getmetadata($extrametadata, $file)) {
	print STDERR "\n****  EmbeddedMetadataPlugin: Need to merge new metadata with existing stored metadata: file = $file\n" if $verbosity > 3;

	my $file_metadata_table = &extrametautil::getmetadata($extrametadata, $file);

	foreach my $metaname (keys %exif_metadata) {
	    # will create new entry if one does not already exist
	    push(@{$file_metadata_table->{$metaname}}, @{$exif_metadata{$metaname}});	    
	}

	# no need to push $file on to $extrametakeys as it is already in the list
    }
    else {
	&extrametautil::setmetadata($extrametadata, $file, \%exif_metadata);
	&extrametautil::addmetakey($extrametakeys, $file);
    }

}


sub metadata_read
{
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;
 
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
 
# Now handled in the can_process_this_file_for_metadata method
#   
#    # we don't want to process directories
#    if (!-f $filename_full_path) {
#	return undef;
#    }

    if (!$self->can_process_this_file_for_metadata($filename_full_path)) {

	# Avoid scanning it with ExifTool ...
	# ... but let any other plugin in metadata_read() passes pipeline
	# consider it

	return undef;
    }


    print STDERR "\n<Processing n='$file' p='EmbeddedMetadataPlugin'>\n" if ($gli);
    print STDERR "EmbeddedMetadataPlugin: processing $file\n" if ($self->{'verbosity'}) > 1;
    
    $self->extractEmbeddedMetadata($filename_no_path,$filename_full_path,
				   $extrametadata,$extrametakeys);
    
    # also want it considered by other plugins in the metadata_read() pipeline
    return undef;
}

sub read
{
    return undef;
}

sub process
{
    # not used
    return undef;
}

sub gsSafe() {
	my $self = shift(@_);
	my ($text) = @_;
	
	# Replace potentially problematic characters
	$text =~ s/\(/&#40;/g;
	$text =~ s/\)/&#41;/g;
	$text =~ s/,/&#44;/g;
	$text =~ s/\</&#60;/g;
	$text =~ s/\>/&#62;/g;
	$text =~ s/\[/&#91;/g;
	$text =~ s/\]/&#93;/g;
	$text =~ s/\{/&#123;/g;
	$text =~ s/\}/&#125;/g;
	# Done
	
	if ($self->{'trim_whitespace'} eq "true"){
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
	}
	
	return $text;
}

1;
