###########################################################################
#
# MetadataXMLPlugin.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

# MetadataXMLPlugin process metadata.xml files in a collection

# Here's an example of a metadata file that uses three FileSet structures
# (ignore the # characters):

#<?xml version="1.0" encoding="UTF-8" standalone="no"?>
#<!DOCTYPE DirectoryMetadata SYSTEM "http://greenstone.org/dtd/DirectoryMetadata/1.0/DirectoryMetadata.dtd">
#<DirectoryMetadata>
#  <FileSet>
#    <FileName>nugget.*</FileName>
#    <Description>
#      <Metadata name="Title">Nugget Point, The Catlins</Metadata>
#      <Metadata name="Place" mode="accumulate">Nugget Point</Metadata>
#    </Description>
#  </FileSet>
#  <FileSet>
#    <FileName>nugget-point-1.jpg</FileName>
#    <Description>
#      <Metadata name="Title">Nugget Point Lighthouse, The Catlins</Metadata>
#      <Metadata name="Subject">Lighthouse</Metadata>
#    </Description>
#  </FileSet>
#  <FileSet>
#    <FileName>kaka-point-dir</FileName>
#    <Description>
#      <Metadata name="Title">Kaka Point, The Catlins</Metadata>
#    </Description>
#  </FileSet>
#</DirectoryMetadata>

# Metadata elements are read and applied to files in the order they appear
# in the file.
#
# The FileName element describes the subfiles in the directory that the
# metadata applies to as a perl regular expression (a FileSet group may
# contain multiple FileName elements). So, <FileName>nugget.*</FileName>
# indicates that the metadata records in the following Description block
# apply to every subfile that starts with "nugget".  For these files, a
# Title metadata element is set, overriding any old value that the Title
# might have had.
#
# Occasionally, we want to have multiple metadata values applied to a
# document; in this case we use the "mode=accumulate" attribute of the
# particular Metadata element.  In the second metadata element of the first
# FileSet above, the "Place" metadata is accumulating, and may therefore be
# given several values.  If we wanted to override these values and use a
# single metadata element again, we could set the mode attribute to
# "override" instead.  Remember: every element is assumed to be in override
# mode unless you specify otherwise, so if you want to accumulate metadata
# for some field, every occurance must have "mode=accumulate" specified.
#
# The second FileSet element above applies to a specific file, called
# nugget-point-1.jpg.  This element overrides the Title metadata set in the
# first FileSet, and adds a "Subject" metadata field.
#
# The third and final FileSet sets metadata for a subdirectory rather than
# a file.  The metadata specified (a Title) will be passed into the
# subdirectory and applied to every file that occurs in the subdirectory
# (and to every subsubdirectory and its contents, and so on) unless the
# metadata is explictly overridden later in the import.

package MetadataXMLPlugin;

use strict;
no strict 'refs';

use Encode;

use BaseImporter;
use extrametautil;
use util;
use FileUtils;
use metadatautil;

sub BEGIN {
    @MetadataXMLPlugin::ISA = ('BaseImporter');
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
}

use XMLParser;

my $arguments = [
      { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() }

];

my $options = { 'name'     => "MetadataXMLPlugin",
		'desc'     => "{MetadataXMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options or initialisations etc
	return bless $self, $class;
    }
	
    # The following used to be passed in as a parameter to XML::Parser,
    # if the version of perl was greater than or equal to 5.8. 
    # The svn commit comment explaining the reason for adding this was
    # not very clear and also said that it was quick fix and hadn't
    # been tested under windows. 
    # More recent work has been to make strings in Perl "Unicode-aware"
    # and so this line might actually be potentially harmful, however
    # it is not the case that we encountered an actual error leading to
    # its removal, rather it has been eliminated in an attempt to tighten
    # up the code. For example, this protocol encoding is not used in
    # ReadXMLFile.
    # 'ProtocolEncoding' => 'ISO-8859-1',

    # create XML::Parser object for parsing metadata.xml files
    my $parser = new XML::Parser('Style' => 'Stream',							  
                                  'Pkg' => 'MetadataXMLPlugin',
                                  'PluginObj' => $self,
					'Handlers' => {'Char' => \&Char,
						 'Doctype' => \&Doctype
						 });

    $self->{'parser'} = $parser;
    $self->{'in_filename'} = 0;
    
    return bless $self, $class;
}


sub get_default_process_exp
{
    return q^metadata\.xml$^;
}

sub get_doctype {
    my $self = shift(@_);
    
    return "(Greenstone)?DirectoryMetadata"
}

sub can_process_this_file {
    my $self = shift(@_);
    my ($filename) = @_;

    if (-f $filename && $self->SUPER::can_process_this_file($filename) && $self->check_doctype($filename)) {
	   return 1; # its a file for us
    }
    return 0;
}

sub check_doctype {
    my $self = shift (@_);
    
    my ($filename) = @_;

    if (open(XMLIN,"<$filename")) {
	my $doctype = $self->get_doctype();
	## check whether the doctype has the same name as the root element tag
	while (defined (my $line = <XMLIN>)) {
	    ## find the root element
	    if ($line =~ /<([\w\d:]+)[\s\/>]/){
		my $root = $1;
		if ($root !~ $doctype){
		    close(XMLIN);
		    return 0;
		}
		else {
		    close(XMLIN); 
		    return 1;
		}
	    }
	}
	close(XMLIN);
    }
    
    return undef; # haven't found a valid line
    
}

sub file_block_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;
	
    my $filename_full_path = &FileUtils::filenameConcatenate($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);    

    if (($ENV{'GSDLOS'} =~ m/^windows$/) && ($^O ne "cygwin")) {
		# convert to full name - paths stored in block hash are long filenames
	$filename_full_path = &util::upgrade_if_dos_filename($filename_full_path);
	my $lower_drive = $filename_full_path;
	$lower_drive =~ s/^([A-Z]):/\l$1:/i;
	
	my $upper_drive = $filename_full_path;
	$upper_drive =~ s/^([A-Z]):/\u$1:/i;
	
	$block_hash->{'metadata_files'}->{$lower_drive} = 1;
	$block_hash->{'metadata_files'}->{$upper_drive} = 1;
		
    }
    else {
	$block_hash->{'metadata_files'}->{$filename_full_path} = 1;
    }

    return 1;
}

sub metadata_read
{
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata,$extrametafile,
	$processor, $gli, $aux) = @_;

    my $filename = &FileUtils::filenameConcatenate($base_dir, $file);
    return undef unless $self->can_process_this_file($filename);    
	
    $self->{'metadata-file'} = $file;
    $self->{'metadata-filename'} = $filename;
	
    my $outhandle = $self->{'outhandle'};
    
    print STDERR "\n<Processing n='$file' p='MetadataXMLPlugin'>\n" if ($gli);
    print $outhandle "MetadataXMLPlugin: processing $file\n" if ($self->{'verbosity'})> 1;
    # add the file to the block list so that it won't be processed in read, as we will do all we can with it here
    $self->block_raw_filename($block_hash,$filename);

    $self->{'metadataref'} = $extrametadata;
    $self->{'metafileref'} = $extrametafile;
    $self->{'metakeysref'} = $extrametakeys;
    
    eval {
	$self->{'parser'}->parsefile($filename);
    };

    if ($@) {
	print STDERR "**** Error is: $@\n";
	my $plugin_name = ref ($self);
	my $failhandle = $self->{'failhandle'};
	print $outhandle "$plugin_name failed to process $file ($@)\n";
	print $failhandle "$plugin_name failed to process $file ($@)\n";
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1; #error
    }

    return 1;

}


# Updated by Jeffrey 2010/04/16 @ DL Consulting Ltd.
# Get rid off the global $self as it cause problems when there are 2+ MetadataXMLPlugin in your collect.cfg...
# For example when you have an OAIMetadataXMLPlugin that is a child of MetadataXMLPlugin
sub Doctype {$_[0]->{'PluginObj'}->xml_doctype(@_);}
sub StartTag {$_[0]->{'PluginObj'}->xml_start_tag(@_);}
sub EndTag {$_[0]->{'PluginObj'}->xml_end_tag(@_);}
sub Text {$_[0]->{'PluginObj'}->xml_text(@_);}


sub xml_doctype {
    my $self = shift(@_);
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    # allow the short-lived and badly named "GreenstoneDirectoryMetadata" files 
    # to be processed as well as the "DirectoryMetadata" files which should now
    # be created by import.pl
    die if ($name !~ /^(Greenstone)?DirectoryMetadata$/);
}

sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
	
    if ($element eq "FileSet") {
	$self->{'saved_targets'} = [];
	$self->{'saved_metadata'} = {};
    }
    elsif ($element eq "FileName") {
	$self->{'in_filename'} = 1;
    }
    elsif ($element eq "Metadata") {
	$self->{'metadata_name'} = $_{'name'};
	$self->{'metadata_value'} = "";
	if ((defined $_{'mode'}) && ($_{'mode'} eq "accumulate")) {
	    $self->{'metadata_accumulate'} = 1;
	} else {
	    $self->{'metadata_accumulate'} = 0;
	}
    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    if ($element eq "FileSet") {
	foreach my $target (@{$self->{'saved_targets'}}) {
	
	    # FileNames must be regex, but we allow \\ for path separator on windows. convert to /
	    $target = &util::filepath_regex_to_url_format($target);

	    # we want proper unicode for the regex, so convert url-encoded chars
	    if (&unicode::is_url_encoded($target)) {
		$target = &unicode::url_decode($target);
	    }

	    my $file_metadata = &extrametautil::getmetadata($self->{'metadataref'}, $target);
	    my $saved_metadata = $self->{'saved_metadata'};

	    if (!defined $file_metadata) {
		&extrametautil::setmetadata($self->{'metadataref'}, $target, $saved_metadata);

		# not had target before
		&extrametautil::addmetakey($self->{'metakeysref'}, $target);
	    }
	    else {
		&metadatautil::combine_metadata_structures($file_metadata,$saved_metadata);
	    }

	    
	    # now record which metadata.xml file it came from

	    my $file = $self->{'metadata-file'};
	    my $filename = $self->{'metadata-filename'};

	    if (!defined &extrametautil::getmetafile($self->{'metafileref'}, $target)) {
	    	&extrametautil::setmetafile($self->{'metafileref'}, $target, {});
	    }

	    &extrametautil::setmetafile_for_named_file($self->{'metafileref'}, $target, $file, $filename);
	}
    }
    elsif ($element eq "FileName") {
	$self->{'in_filename'} = 0;
    }
    elsif ($element eq "Metadata") {
	# text read in by XML::Parser is in Perl's binary byte value
	# form ... need to explicitly make it UTF-8
	
	my $metadata_name = $self->{'metadata_name'};
	my $metadata_value = $self->{'metadata_value'};
	#my $metadata_name = decode("utf-8",$self->{'metadata_name'});
	#my $metadata_value = decode("utf-8",$self->{'metadata_value'});
	
	&metadatautil::store_saved_metadata($self,
					    $metadata_name, $metadata_value, 
					    $self->{'metadata_accumulate'});
	$self->{'metadata_name'} = "";
    }

}

sub xml_text {
    my $self = shift(@_);

    if ($self->{'in_filename'}) {
	# $_ == FileName content
	push (@{$self->{'saved_targets'}}, $_);
    }
    elsif (defined ($self->{'metadata_name'}) && $self->{'metadata_name'} ne "") {
	# $_ == Metadata content
	$self->{'metadata_value'} = $_;
    }
}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
#    use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+ 

#    if ($]<5.008) {
#	use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+ and Perl 5.6
#    }
    $_[0]->{'Text'} .= $_[1];
    return undef;
}



1;
