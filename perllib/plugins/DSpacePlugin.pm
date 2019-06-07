
###########################################################################
#
# DSpacePlugin.pm -- plugin for importing a collection from DSpace 
# 
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2004 New Zealand Digital Library Project
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


# This plugin takes "contents" and dublin_core.xml file, which contain 
# Metadata and lists of associated files for a particular document
# and produces a document containing sections, one for each page.
# The files should be named "contents" and "dublin_core.xml".  For each of 
# document in DSpace, it is stored in one directory
#
# The format of the "contents" file is as follows:
# 
# File.type      bundle:ORIGINAL
# license.txt    bundle:LICENSE
# The format of the "dublin_core.xml" file is as follows:
# The first line contains any metadata for the whole document
# <dublin_core>
# eg.
# <dcvalue element="Title" qualifier="">Snail farming</dcvalue>
# <dcvalue element="date" qualifier="">2004-10-15</dcvalue>
#

package DSpacePlugin;

use extrametautil;
use ReadTextFile;
use plugin;
use util;
use FileUtils;
use XMLParser;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @DSpacePlugin::ISA = ('ReadTextFile');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "string",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "only_first_doc",
	'desc' => "{DSpacePlugin.only_first_doc}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "first_inorder_ext",
	'desc' => "{DSpacePlugin.first_inorder_ext}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "first_inorder_mime",
	'desc' => "{DSpacePlugin.first_inorder_mime}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'deft' => &get_default_block_exp(),
	'reqd' => "no" }];


my $options = { 'name'     => "DSpacePlugin",
		'desc'     => "{DSpacePlugin.desc}",
		'inherits' => "yes",
		'abstract' => "no",
		'args'     => $arguments };


my $primary_doc_lookup = { 'text/html' => '(?i)\.(gif|jpe?g|jpe|jpg|png|css)$' };

# Important variation to regular plugin structure.  Need to declare
# $self as global variable to file so XMLParser callback routines
# can access the content of the object. 
my ($self); 

sub new {
    my ($class) = shift (@_); 
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);
    
    if ($self->{'info_only'}) {
	# don't worry about creating the XML parser as all we want is the 
	# list of plugin options
	return bless $self, $class;
    }

    #create XML::Parser object for parsing dublin_core.xml files
    my $parser = new XML::Parser('Style' => 'Stream',
				 'Handlers' => {'Char' => \&Char,
						'Doctype' => \&Doctype
						});
    $self->{'parser'} = $parser;
    $self->{'extra_blocks'} = {};

    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)(contents)$^;
}

# want to block all files except the "contents"
sub get_default_block_exp {
    my $self = shift (@_);
    
    # Block handle and txt files if present. Specifically don't block dublin_core xml
    return q^(?i)(handle|\.tx?t)$^;
}

sub store_block_files_BACKUP
{
    # Option of making blocking sensitive to files that are in directory
    # This subroutine is not currently used! (relies on default block expression stopping all handle and .txt files)

    my $self =shift (@_);
    my ($filename_full_path, $block_hash) = @_;

    my ($tailname, $contents_basedir, $suffix) = &File::Basename::fileparse($filename_full_path, "\\.[^\\.]+\$");
    my $handle_filename = &FileUtils::filenameConcatenate($contents_basedir,"handle");

    if (&FileUtils::fileTest($handle_filename)) {
	$self->block_raw_filename($block_hash,$handle_filename);
    }
}

sub read_content
{
    my $self = shift (@_);
    my ($dir, $only_first_doc, $first_inorder_ext, $first_inorder_mime, $mimetype_list) = @_;
    my $outhandle = $self->{'outhandle'};

    my @fnamemime_list = ();
    my @assocmime_list = ();

    my $content_fname = &FileUtils::filenameConcatenate($dir,"contents");

    open(CIN,"<$content_fname") 
	|| die "Unable to open $content_fname: $!\n";
    
    my $line;
    my $pos = 0;

    while (defined ($line = <CIN>)) {
	if ($line =~ m/^(.*)\s+bundle:ORIGINAL\s*$/) {
	    my $fname = $1;
	    my $mtype = $mimetype_list->[$pos];
	    my $fm_rec = { 'file' => $fname, 'mimetype' => $mtype};
	    push(@fnamemime_list,$fm_rec);
	    $pos++;
	}
    }
    close CIN;

    if ($only_first_doc){
	my ($first_fname, @rest_fnames) = @fnamemime_list;
	@fnamemime_list = ($first_fname);
	@assocmime_list = @rest_fnames;
    }

    # allow user to specify the types of files (inorder)they would like to assign as
    # a primary bitstream
    if ($first_inorder_ext) {
	# parse user-define file extension names
	my @extfiles_list = split /,/, $first_inorder_ext;
	my (@rest_fnames) = @fnamemime_list;
	my @matched_list = ();
	foreach my $file_ext (@extfiles_list) {
	    $pos = 0;
	    foreach my $allfiles (@fnamemime_list){
		$allfiles->{'file'} =~ /^(.*)\.(.*?)$/;
		my $allfiles_ext = $2;

		if ($allfiles_ext =~ /$file_ext/) {
		    print $outhandle "Existing file:$allfiles->{'file'} match the user-define File Extension:$file_ext\n";
		    push (@matched_list, $allfiles);

		    # delete the matched extension file from the array
		    splice(@rest_fnames,$pos,1);

		    return (\@matched_list, \@rest_fnames);

		}
		$pos++;
	    }
	}
    }
    
    if ($first_inorder_mime) {
	# parse user-define file mimetype
	my @file_mime_list = split /,/, $first_inorder_mime;
	my (@rest_fnames) = @fnamemime_list;
	my @matched_list = ();
	foreach my $file_mime (@file_mime_list) {
	    $pos = 0;
	    foreach my $allfiles (@fnamemime_list){
		my $allfiles_mime = $allfiles->{'mimetype'};

		if ($allfiles_mime =~ /$file_mime/) {
		    print $outhandle "Existing file:$allfiles->{'file'} match the user-defined File MimeType:$file_mime\n";
		    push (@matched_list, $allfiles);

		    # delete the matched MIMEType file from the array
		    splice(@rest_fnames,$pos,1);
		    return (\@matched_list, \@rest_fnames);
		}
		$pos++;
	    }
	}
    }
    return (\@fnamemime_list, \@assocmime_list);
}


sub filemime_list_to_re
{
    my $self = shift (@_);
    my ($fnamemime_list) = @_;

    my @fname_list = map { "(".$_->{'file'}.")" } @$fnamemime_list;
    my $fname_re = join("|",@fname_list);
	
	# Indexing into the extrameta data structures requires the filename's style of slashes to be in URL format
	# Then need to convert the filename to a regex, no longer to protect windows directory chars \, but for
	# protecting special characters like brackets in the filepath such as "C:\Program Files (x86)\Greenstone".
	$fname_re = &util::filepath_to_url_format($fname_re); # just in case there are slashes in there 
	
    $fname_re =~ s/\./\\\./g;

    return $fname_re;
}

# Read dublin_core metadata from DSpace collection 
sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    my $only_first_doc = $self->{'only_first_doc'};
    my $first_inorder_ext = $self->{'first_inorder_ext'};
    my $first_inorder_mime = $self->{'first_inorder_mime'};
    
    my $outhandle = $self->{'outhandle'};
    
    my $filename = &FileUtils::filenameConcatenate($base_dir, $file);
    # return 0 if $self->{'block_exp'} ne "" && $filename =~ /$self->{'block_exp'}/;
    
    if ($filename !~ /dublin_core\.xml$/ || !-f $filename) {
	return undef;
    }
    
    print $outhandle "DSpacePlugin: extracting metadata from $file\n"
	if $self->{'verbosity'} > 1;
    
    my ($dir) = $filename =~ /^(.*?)[^\/\\]*$/;

    eval {
	$self->{'parser'}->parsefile($filename);
    };
    
    if ($@) {
	die "DSpacePlugin: ERROR $filename is not a well formed dublin_core.xml file ($@)\n";
    }

    my $mimetype_list = $self->{'saved_metadata'}->{'ex.dc.Format^mimetype'};
    my ($doc_file_mimes, $assoc_file_mimes) = $self->read_content($dir, $only_first_doc, $first_inorder_ext, 
								  $first_inorder_mime, $mimetype_list);

    my $file_re = $self->filemime_list_to_re($doc_file_mimes);

    if ($only_first_doc || $first_inorder_ext || $first_inorder_mime) {	
	foreach my $afm ( @$assoc_file_mimes ) {
 	    my $full_af = &FileUtils::filenameConcatenate($dir,$afm->{'file'});
	    $self->{'extra_blocks'}->{$full_af} = 1;
	}
    }
    &extrametautil::addmetakey($extrametakeys, $file_re);

    # See Format's Extent section in http://dublincore.org/documents/usageguide/qualifiers.shtml
    # it could specify duration, size or even dimensions of the resource. It may be a useful piece
    # of metadata to preserve after all.
    #if (defined $self->{'saved_metadata'}->{'ex.dc.Format^extent'}) {
	#delete $self->{'saved_metadata'}->{'ex.dc.Format^extent'};
    #}

    if (defined $mimetype_list) {
	delete $self->{'saved_metadata'}->{'ex.dc.Format^mimetype'};

	# Temporarily store associate file info in metadata table
	# This will be removed in 'extra_metadata' in BaseImporter and used
	# to perform the actual file association (once the doc obj has
	# been formed

	my $main_doc = $doc_file_mimes->[0];
	my $md_mimetype = $main_doc->{'mimetype'};

	my $pd_lookup = $primary_doc_lookup->{$md_mimetype};

	if (defined $pd_lookup) {
	    my $filter_re = $pd_lookup;
	    @$assoc_file_mimes = grep { $_->{'file'} !~ m/$filter_re/ }  @$assoc_file_mimes;
	}

	my @gsdlassocfile_tobe 
	    = map { &FileUtils::filenameConcatenate($dir,$_->{'file'}) .":".$_->{'mimetype'}.":" } @$assoc_file_mimes if @$assoc_file_mimes;
	$self->{'saved_metadata'}->{'gsdlassocfile_tobe'} = \@gsdlassocfile_tobe;

    }
    
    &extrametautil::setmetadata($extrametadata, $file_re, $self->{'saved_metadata'});

    return 1;
}


# The DSpacePlugin read() function. We are not actually reading any documents 
# here, just blocking ones that have been processed by metadata read.
#
# Returns 0 for a file its blocking, undef for any other
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};
    
    # Block all files except contents
    my $filename = &FileUtils::filenameConcatenate($base_dir, $file);
    return 0 if $self->{'block_exp'} ne "" && $filename =~ /$self->{'block_exp'}/;

    my $assocfile = $metadata->{'assocfile'};

    return 0 if (($filename =~ /dublin_core\.xml$/) || ($filename =~ /contents$/));
    return 0 if (defined $self->{'extra_blocks'}->{$filename});
    return undef;
}

sub Doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    die if ($name !~ /^dublin_core$/);
}

sub StartTag {
    my ($expat, $element) = @_;
    if ($element eq "dublin_core") {
	$self->{'saved_metadata'} = {};
    } elsif ($element eq "dcvalue") {
	my $metaname = $_{'element'};
	my $qualifier = $_{'qualifier'}||"";
	if ($metaname ne "description" || $qualifier ne "provenance") {
	    $metaname .= "^$qualifier" if ($qualifier ne "none" && $qualifier ne "");
	    $self->{'metaname'} = "ex.dc.\u$metaname";
	}
    }
}

sub EndTag {
    my ($expat, $element) = @_;
    
    if ($element eq "dcvalue") {
	$self->{'metaname'} = "";
    }
}

sub Text {
    if (defined ($self->{'metaname'}) && $self->{'metaname'} ne "") {
	# $_ == Metadata content
	my $mname = $self->{'metaname'};
	my $mvalue = prepareMetadataValue($_);
	if (defined $self->{'saved_metadata'}->{$mname}) {
	    # accumulate - add value to existing value(s)
	    if (ref ($self->{'saved_metadata'}->{$mname}) eq "ARRAY") {
		push (@{$self->{'saved_metadata'}->{$mname}}, $mvalue);
	    } else {
		$self->{'saved_metadata'}->{$mname} = 
		    [$self->{'saved_metadata'}->{$mname}, $mvalue];
	    }
	} else {
	    # accumulate - add value into (currently empty) array
	    $self->{'saved_metadata'}->{$mname} = [$mvalue];
	}

    }
}

# Prepare DSpace metadata for using with Greenstone.
# Some value must be escaped.
sub prepareMetadataValue {
	my ($value) = @_;
	
	$value =~ s/\[/&#091;/g;
	$value =~ s/\]/&#093;/g;
	
	return $value;
 }
# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
    use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+
    $_[0]->{'Text'} .= $_[1];
    return undef;
}

1;
