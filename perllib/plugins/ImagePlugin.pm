###########################################################################
#
# ImagePlugin.pm -- for processing standalone images
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

package ImagePlugin;

use BaseImporter;
use ImageConverter;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

use gsprintf 'gsprintf';

sub BEGIN {
    @ImagePlugin::ISA = ('BaseImporter', 'ImageConverter');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      ];

my $options = { 'name'     => "ImagePlugin",
		'desc'     => "{ImagePlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };



sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    
    new ImageConverter($pluginlist, $inputargs, $hashArgOptLists);
    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    $self->SUPER::init(@_);
    $self->ImageConverter::init();
    $self->{'cover_image'} = 0; # makes no sense for images
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    $self->SUPER::begin(@_);
    $self->ImageConverter::begin(@_);
}


sub get_default_process_exp {
    my $self = shift (@_);

	# from .jpf and onwards below, the file extensions are for JPEG2000
    return q^(?i)\.(jpe?g|gif|png|bmp|xbm|tif?f|jpf|jpx|jp2|jpc|j2k|pnm|pgx)$^; 
}

# this makes no sense for images
sub block_cover_image
{
    my $self =shift (@_);
    my ($filename) = @_;

    return;
}

# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    # options??
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
	
    if ($self->{'image_conversion_available'} == 1)
    {
		my $plugin_filename_encoding = $self->{'filename_encoding'};
		my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
		
		my $url_encoded_full_filename 
		    = &unicode::raw_filename_to_url_encoded($filename_full_path);

		# should we check the return value?
		$self->generate_images($filename_full_path, 
				       $url_encoded_full_filename, 
				       $doc_obj, $doc_obj->get_top_section(),$filename_encoding); 
		
    }
    else
    {
		if ($gli) {
			&gsprintf(STDERR, "<Warning p='ImagePlugin' r='{ImageConverter.noconversionavailable}: {ImageConverter.".$self->{'no_image_conversion_reason'}."}'>");
		}
		# all we do is add the original image as an associated file, and set up srclink etc
		my $assoc_file = $doc_obj->get_assocfile_from_sourcefile();
		my $section = $doc_obj->get_top_section();
		
		$doc_obj->associate_file($filename_full_path, $assoc_file, "", $section);
		
		# srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
		$doc_obj->add_metadata ($section, "srclink_file", $doc_obj->get_sourcefile()); 
		$doc_obj->add_metadata ($section, "srclinkFile", $doc_obj->get_sourcefile()); 
		# We don't know the size of the image, but the browser should display it at full size
		$doc_obj->add_metadata ($section, "srcicon", "<img src=\"_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/[srclinkFile]\">");
		
		# Add a fake thumbnail icon with the full-sized image scaled down by the browser
		$doc_obj->add_metadata ($section, "thumbicon", "<img src=\"_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/[srclinkFile]\" alt=\"[srclinkFile]\" width=\"" . $self->{'thumbnailsize'} . "\">");
    }
    #we have no text - adds dummy text and NoText metadata
    $self->add_dummy_text($doc_obj, $doc_obj->get_top_section());
	
    return 1;
	
}


sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);
    
    $self->ImageConverter::clean_up_temporary_files();
}

1;











