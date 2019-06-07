###########################################################################
#
# ImageConverter - helper plugin that does image conversion using ImageMagick
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2008 New Zealand Digital Library Project
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
package ImageConverter;

use BaseMediaConverter;


use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use util;
use FileUtils;
use gsprintf 'gsprintf';

BEGIN {
    @ImageConverter::ISA = ('BaseMediaConverter');
}

# When used with multiple builder+buildproc, plugins loaded multiple times
# => use this 'our' var to ensure only see the warning about ImageMagick once
our $given_image_conversion_warning = 0;

my $arguments = [
      { 'name' => "create_thumbnail",
	'desc' => "{ImageConverter.create_thumbnail}",
	'type' => "enum",
	'list' => [{'name' => "true", 'desc' => "{common.true}"},
		   {'name' => "false", 'desc' => "{common.false}"}],
	'deft' => "true",
	'reqd' => "no" },
      { 'name' => "thumbnailsize",
	'desc' => "{ImageConverter.thumbnailsize}",
	'type' => "int",
	'deft' => "100",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "thumbnailtype",
	'desc' => "{ImageConverter.thumbnailtype}",
	'type' => "string",
	'deft' => "gif",
	'reqd' => "no" },
      { 'name' => "noscaleup",
	'desc' => "{ImageConverter.noscaleup}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "create_screenview",
	'desc' => "{ImageConverter.create_screenview}",
	'type' => "enum",
	'list' => [{'name' => "true", 'desc' => "{common.true}"},
		   {'name' => "false", 'desc' => "{common.false}"}],
	'deft' => "true",
	'reqd' => "no" },
      { 'name' => "screenviewsize",
	'desc' => "{ImageConverter.screenviewsize}",
	'type' => "int",
	'deft' => "500",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "screenviewtype",
	'desc' => "{ImageConverter.screenviewtype}",
	'type' => "string",
	'deft' => "jpg",
	'reqd' => "no" },
      { 'name' => "converttotype",
	'desc' => "{ImageConverter.converttotype}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "minimumsize",
	'desc' => "{ImageConverter.minimumsize}",
	'type' => "int",
	'deft' => "100",
	'range' => "1,",
	'reqd' => "no" },
    { 'name' => "store_original_image",
      'desc' => "{ImageConverter.store_original_image}",
      'type' => "flag",
      'reqd' => "no"},
      { 'name' => "apply_aspectpad",
	'desc' => "{ImageConverter.apply_aspectpad}",
	'type' => "enum",
	'list' => [{'name' => "true", 'desc' => "{common.true}"},
		   {'name' => "false", 'desc' => "{common.false}"}],
	'deft' => "false",
	'reqd' => "no" },
      { 'name' => "aspectpad_ratio",
	'desc' => "{ImageConverter.aspectpad_ratio}",
	'type' => "string",
	'deft' => "2",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "aspectpad_mode",
	'desc' => "{ImageConverter.aspectpad_mode}",
	'type' => "enum",
	'list' => [{'name' => "al", 'desc' => "{aspectpad.al}"},
		   {'name' => "ap", 'desc' => "{aspectpad.ap}"},
		   {'name' => "l",  'desc' => "{aspectpad.l}"},
		   {'name' => "p",  'desc' => "{aspectpad.p}"}],
	'deft' => "al",
	'reqd' => "no" },
      { 'name' => "aspectpad_colour",
	'desc' => "{ImageConverter.aspectpad_colour}",
	'type' => "string",
	'deft' => "transparent",
	'reqd' => "no" },
      { 'name' => "aspectpad_tolerance",
	'desc' => "{ImageConverter.aspectpad_tolerance}",
	'type' => "string",
	'deft' => "0.0",
	'range' => "0,",
	'reqd' => "no" },


		 ];

my $options = { 'name' => "ImageConverter",
		'desc' => "{ImageConverter.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args' => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseMediaConverter($pluginlist, $inputargs, $hashArgOptLists, 1);
  
    return bless $self, $class;

}

# needs to be called after BaseImporter init, so that outhandle is set up.
sub init {
    my $self = shift(@_);

    $self->{'tmp_file_paths'} = ();

    # Check that ImageMagick is installed and available on the path 
    my $image_conversion_available = 1;
    my $no_image_conversion_reason = "";
    # None of this works very well on Windows 95/98...
    if ($ENV{'GSDLOS'} eq "windows" && !Win32::IsWinNT()) {
	$image_conversion_available = 0;
	$no_image_conversion_reason = "win95notsupported";
    } else {
	my $imagick_cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl";
	my $result = `$imagick_cmd identify -help 2>&1`;
	my $return_value = $?;

	# When testing against non-zero return_value ($?), need to shift by 8 
	# and convert it to its signed value. Linux returns -1 and Windows returns 
	# 256 for "program not found". The signed equivalents are -1 and 1 respectively.
	$return_value >>= 8;
	$return_value = (($return_value & 0x80) ? -(0x100 - ($return_value & 0xFF)) : $return_value);

	if ( ($ENV{'GSDLOS'} eq "windows" && $return_value == 1) || $return_value == -1) {  # Linux and Windows return different values for "program not found"
	    $image_conversion_available = 0;
	    $no_image_conversion_reason = "imagemagicknotinstalled";
	}
    }
    $self->{'image_conversion_available'} = $image_conversion_available;
    $self->{'no_image_conversion_reason'} = $no_image_conversion_reason;

    if ($self->{'image_conversion_available'} == 0) {
	if (!$given_image_conversion_warning) {
	    my $outhandle = $self->{'outhandle'};
	    &gsprintf($outhandle, "ImageConverter: {ImageConverter.noconversionavailable} ({ImageConverter.".$self->{'no_image_conversion_reason'}."})\n");
	    $given_image_conversion_warning = 1;
	}
    }
       
}
	

# convert image to new type if converttotype is set
# generate thumbnails if required
# generate screenview if required
# discover image metadata
# filename_no_path must be in utf8 and url-encoded
sub generate_images {
    my $self = shift(@_);
    my ($filename_full_path, $filename_encoded_full_path, $doc_obj, $section, $filename_encoding) = @_;

    my ($unused_fefp,$filename_encoded_no_path)
	= &util::get_full_filenames("",$filename_encoded_full_path);

    # The following is potentially very muddled thinking (but currently seems to work)
    # generate_images currently called from ImagePlugin and PagedImagePlugin
    my $filename_no_path = $filename_encoded_no_path;
    my $original_filename_full_path = $filename_full_path;
    my $original_filename_no_path = $filename_no_path;
    my $original_file_was_converted = 0;
    
    # check image magick status
    return 0 if $self->{'image_conversion_available'} == 0;

    # check the filenames
    return 0 if ($filename_no_path eq "" || !-f $filename_full_path);

    if ($self->{'enable_cache'}) {
	$self->init_cache_for_file($filename_full_path);
    }
    if ($self->{'store_file_paths'}) {
	$self->{'orig_file'} = "";
	$self->{'thumb_file'} = "";
	$self->{'screen_file'} = "";
    }
    my $verbosity = $self->{'verbosity'};
    my $outhandle = $self->{'outhandle'};

    # check the size of the image against minimum size if specified
    my $minimumsize = $self->{'minimumsize'};
    if (defined $minimumsize && (&FileUtils::fileSize($filename_full_path) < $minimumsize)) {
        print $outhandle "ImageConverter: \"$filename_full_path\" too small, skipping\n"
	    if ($verbosity > 1);
	return 0; # or is there a better return value??
    }
    
    my $filehead = $filename_no_path;
    $filehead =~ s/\.([^\.]*)$//; # filename with no extension
    my $assocfilemeta = "[assocfilepath]";
    if ($section ne $doc_obj->get_top_section()) {
	$assocfilemeta = "[parent(Top):assocfilepath]";
    }

    # The images that will get generated may contain percent signs in their src filenames
    # Encode those percent signs themselves so that urls to the imgs refer to them correctly 
    my $url_to_filehead = &unicode::filename_to_url($filehead);
    my $url_to_filename_no_path = &unicode::filename_to_url($filename_no_path);

    my $type = "unknown";

    # Convert the image to a new type (if required).
    my $converttotype = $self->{'converttotype'};

    if ($converttotype ne "" && $filename_full_path !~ m/$converttotype$/) {
#	#    $doc_obj->add_utf8_metadata($section, "Image", $utf8_filename_meta);
	my ($result, $converted_filename_full_path)
	    = $self->convert($filename_full_path, $converttotype, "", "CONVERTTYPE");

	$type = $converttotype;
	$filename_full_path = $converted_filename_full_path;
	$filename_no_path = "$filehead.$type";
	$url_to_filename_no_path = "$url_to_filehead.$type";
	if ($self->{'store_file_paths'}) {
	    $self->{'orig_file'} = $converted_filename_full_path;
	}
	$original_file_was_converted = 1;
    }

    # Apply aspect padding (if required).
    my $apply_aspectpad = $self->{'apply_aspectpad'};

    if ($apply_aspectpad eq "true") {
	my $aspectpad_ratio     = $self->{'aspectpad_ratio'};
	my $aspectpad_mode      = $self->{'aspectpad_mode'};
	my $aspectpad_colour    = $self->{'aspectpad_colour'};
	my $aspectpad_tolerance = $self->{'aspectpad_tolerance'};

	($type) = ($filename_full_path =~ m/\.(.*?)$/);
	##$type = lc($type);

	my ($result, $aspectpad_filename_full_path)
	    = $self->aspectpad($filename_full_path, $type, $aspectpad_ratio, $aspectpad_mode, 
			       $aspectpad_colour, $aspectpad_tolerance, "", "ASPECTPAD");

	$filename_full_path = $aspectpad_filename_full_path;

	if ($self->{'store_file_paths'}) {
	    $self->{'orig_file'} = $aspectpad_filename_full_path;
	}
	$original_file_was_converted = 1;

    }
    
    # add Image metadata 
    $doc_obj->add_utf8_metadata($section, "Image", $url_to_filename_no_path); # url to generated image

    # here we overwrite the original with the potentially converted one
#    $doc_obj->set_utf8_metadata_element($section, "Source", &unicode::url_decode($filename_no_path)); # displayname of generated image
#    $doc_obj->set_utf8_metadata_element($section, "SourceFile", $url_to_filename_no_path); # displayname of generated image

#    $self->set_Source_metadata($doc_obj,$url_to_filename_no_path,undef);

    my $raw_filename_full_path = &unicode::url_decode($filename_encoded_full_path);
    $self->set_Source_metadata($doc_obj,$raw_filename_full_path,
			       $filename_encoding, $section);


    # use identify to get info about the (possibly converted) image
    my ($image_type, $image_width, $image_height, $image_size, $size_str) 
	= &identify($filename_full_path, $outhandle, $verbosity);

    if ($image_type ne " ") {
	$type = $self->correct_mime_type($image_type);
    }

    #overwrite the ones added in BaseImporter
    $doc_obj->set_metadata_element ($section, "FileFormat", $type);
    my $sys_file_size = &FileUtils::fileSize($filename_full_path);
    $doc_obj->set_metadata_element ($section, "FileSize",   $sys_file_size); #$image_size);

    $doc_obj->add_metadata ($section, "ImageType",   $image_type);
    $doc_obj->add_metadata ($section, "ImageWidth",  $image_width);
    $doc_obj->add_metadata ($section, "ImageHeight", $image_height);
    $doc_obj->add_metadata ($section, "ImageSize",   $size_str);

    if ((defined $self->{'MaxImageWidth'}) 
	&& ($image_width > $self->{'MaxImageWidth'})) {
	$self->{'MaxImageWidth'} = $image_width;
    }
    if ((defined $self->{'MaxImageHeight'})
	&& ($image_height > $self->{'MaxImageHeight'})) {
	$self->{'MaxImageHeight'} = $image_height;
    }

    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($section, "srclink_file", $url_to_filename_no_path);
    $doc_obj->add_metadata ($section, "srclinkFile", $url_to_filename_no_path);
    $doc_obj->add_metadata ($section, "srcicon", "<img src=\"_httpprefix_/collect/[collection]/index/assoc/$assocfilemeta/[srclinkFile]\" width=\"[ImageWidth]\" height=\"[ImageHeight]\">");

    # Add the image as an associated file
    $doc_obj->associate_file($filename_full_path, $filename_no_path, "image/$type", $section);

    if ($self->{'store_original_image'} && $original_file_was_converted) {

	# work out the file type
	# use identify to get info about the original image
	my ($orig_type, $orig_width, $orig_height, $orig_size, $origsize_str) 
	= &identify($original_filename_full_path, $outhandle, $verbosity);

	if ($orig_type ne " ") {
	    $orig_type = $self->correct_mime_type($orig_type);
	}

	# add the original image as an associated file
	$doc_obj->associate_file($original_filename_full_path, $original_filename_no_path, "image/$orig_type", $section);
    }
    if ($self->{'create_thumbnail'} eq "true") {
	$self->create_thumbnail($filename_full_path, $filehead, $doc_obj, $section, $assocfilemeta, $url_to_filehead);
    }
    if ($self->{'create_screenview'} eq "true") {
	$self->create_screenview($filename_full_path, $filehead, $doc_obj, $section, $assocfilemeta, $url_to_filehead, $image_width, $image_height);
    }

    return 1;
}

sub create_thumbnail {
    my $self = shift(@_);
    my ($original_file, $filehead, $doc_obj, $section, $assocfilemeta, $url_to_filehead) = @_;
    $url_to_filehead = $filehead unless defined $url_to_filehead; 

    my $thumbnailsize = $self->{'thumbnailsize'};
    my $thumbnailtype = $self->correct_mime_type($self->{'thumbnailtype'});

    # Generate the thumbnail with convert
    my ($result,$thumbnailfile) 
	= $self->convert($original_file, $thumbnailtype, "-geometry $thumbnailsize" . "x$thumbnailsize", "THUMB");
    
    # Add the thumbnail as an associated file ...
    if (-e "$thumbnailfile") { 
	$doc_obj->associate_file("$thumbnailfile", $filehead."_thumb.$thumbnailtype", 
				 "image/$thumbnailtype",$section); # name of generated image
	$doc_obj->add_metadata ($section, "ThumbType", $thumbnailtype);
	$doc_obj->add_utf8_metadata ($section, "Thumb", $url_to_filehead."_thumb.$thumbnailtype"); # url to generated image
	
	$doc_obj->add_metadata ($section, "thumbicon", "<img src=\"_httpprefix_/collect/[collection]/index/assoc/$assocfilemeta/[Thumb]\" alt=\"[Thumb]\" width=\"[ThumbWidth]\" height=\"[ThumbHeight]\">");
    
	
	# Extract Thumbnail metadata from convert output
	if ($result =~ m/[0-9]+x[0-9]+=>([0-9]+)x([0-9]+)/) {
	    $doc_obj->add_metadata ($section, "ThumbWidth", $1);
	    $doc_obj->add_metadata ($section, "ThumbHeight", $2);
	}
	if ($self->{'store_file_paths'}) {
	    $self->{'thumb_file'} = $thumbnailfile;
	}

    } else {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "Couldn't find thumbnail $thumbnailfile\n";

    }
}

sub create_screenview {
    
    my $self = shift(@_);
    my ($original_file, $filehead, $doc_obj, $section, $assocfilemeta, $url_to_filehead, $image_width, $image_height) = @_;
    $url_to_filehead = $filehead unless defined $url_to_filehead; 

    my $screenviewsize = $self->{'screenviewsize'};
    my $screenviewtype = $self->correct_mime_type($self->{'screenviewtype'});

    # Scale the image, unless the original image is smaller than the screenview size and -noscaleup is set
    my $scale_option = "-geometry $screenviewsize" . "x$screenviewsize";
    if ($self->{'noscaleup'} && $image_width < $screenviewsize && $image_height < $screenviewsize)
    {
	$scale_option = "";
    }
    
    # make the screenview image
    my ($result,$screenviewfilename) 
	= $self->convert($original_file, $screenviewtype, $scale_option, "SCREEN");    
    
    #add the screenview as an associated file ...
    if (-e "$screenviewfilename") { 
	$doc_obj->associate_file("$screenviewfilename", $filehead."_screen.$screenviewtype", "image/$screenviewtype",$section); # name of generated image
	$doc_obj->add_metadata ($section, "ScreenType", $screenviewtype);
	$doc_obj->add_utf8_metadata ($section, "Screen", $url_to_filehead."_screen.$screenviewtype"); # url to generated image
	
	$doc_obj->add_metadata ($section, "screenicon", "<img src=\"_httpprefix_/collect/[collection]/index/assoc/$assocfilemeta/[Screen]\" width=[ScreenWidth] height=[ScreenHeight]>");

	# get screenview dimensions, size and type
	if ($result =~ m/[0-9]+x[0-9]+=>([0-9]+)x([0-9]+)/) {
	    $doc_obj->add_metadata ($section, "ScreenWidth", $1);
	    $doc_obj->add_metadata ($section, "ScreenHeight", $2);
	} elsif ($result =~ m/([0-9]+)x([0-9]+)/) {
	    #if the image hasn't changed size, the previous regex doesn't match
	    $doc_obj->add_metadata ($section, "ScreenWidth", $1);
	    $doc_obj->add_metadata ($section, "ScreenHeight", $2);
	}

	if ($self->{'store_file_paths'}) {
	    $self->{'screen_file'} = $screenviewfilename;
	}

    } else {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "Couldn't find screenview file $screenviewfilename\n";

    }

}



sub convert {
    my $self = shift(@_);
    my $source_file_path = shift(@_);
    my $target_file_type = shift(@_);
    my $convert_options  = shift(@_) || "";
    my $convert_id       = shift(@_) || "";
    my $cache_mode       = shift(@_) || "";

    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    my $source_file_no_path = &File::Basename::basename($source_file_path);

    # Determine the full name and path of the output file
    my $target_file_path;
    if ($self->{'enable_cache'}) {
	my $cached_image_dir = $self->{'cached_dir'};
	my $image_root = $self->{'cached_file_root'};
	$image_root .= "_$convert_id" if ($convert_id ne "");
	my $image_file = "$image_root.$target_file_type";
	$target_file_path = &FileUtils::filenameConcatenate($cached_image_dir,$image_file);
    }
    else {
	$target_file_path = &util::get_tmp_filename($target_file_type);
	push(@{$self->{'tmp_file_paths'}}, $target_file_path);

	# Output filename used to be parsed from result line:
	#   my ($ofilename) = ($result =~ m/=>(.*\.$target_file_type)/);
	# by the function that called 'convert'
	# but this is no longer needed, as output filename is now
	# explicitly passed back
    }

    # Generate and run the convert command
    my $convert_command = "\"".&util::get_perl_exec()."\" -S gs-magick.pl --verbosity=".$self->{'verbosity'}." convert -interlace plane -verbose $convert_options \"$source_file_path\" \"$target_file_path\"";

    my $print_info = { 'message_prefix' => $convert_id,
		       'message' => "Converting image $source_file_no_path to: $convert_id $target_file_type" };
    $print_info->{'cache_mode'} = $cache_mode if ($cache_mode ne "");

    my ($regenerated,$result,$had_error) 
	= $self->autorun_general_cmd($convert_command,$source_file_path,$target_file_path,$print_info);

    return ($result,$target_file_path);
}


sub convert_without_result {
    my $self = shift(@_);

    my $source_file_path = shift(@_);
    my $target_file_type = shift(@_);
    my $convert_options  = shift(@_) || "";
    my $convert_id       = shift(@_) || "";

    return $self->convert($source_file_path,$target_file_type,
			  $convert_options,$convert_id,"without_result");
}


sub aspectpad {
    my $self = shift(@_);
    my $source_file_path     = shift(@_);
    my $target_file_type     = shift(@_);
    my $aspectpad_ratio      = shift(@_);
    my $aspectpad_mode       = shift(@_); 			       
    my $aspectpad_colour     = shift(@_);
    my $aspectpad_tolerance  = shift(@_);

    my $aspectpad_options  = shift(@_) || "";
    my $aspectpad_id       = shift(@_) || "";
    my $cache_mode       = shift(@_) || "";

    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    my $source_file_no_path = &File::Basename::basename($source_file_path);

    # Determine the full name and path of the output file
    my $target_file_path;
    if ($self->{'enable_cache'}) {
	my $cached_image_dir = $self->{'cached_dir'};
	my $image_root = $self->{'cached_file_root'};
	$image_root .= "_$aspectpad_id" if ($aspectpad_id ne "");
	my $image_file = "$image_root.$target_file_type";
	$target_file_path = &FileUtils::filenameConcatenate($cached_image_dir,$image_file);
    }
    else {
	$target_file_path = &util::get_tmp_filename($target_file_type);
	push(@{$self->{'tmp_file_paths'}}, $target_file_path);
    }

    # Generate and run the aspectpad command
    my $aspectpad_command = "\"".&util::get_perl_exec()."\" -S gs-magick.pl --verbosity=".$self->{'verbosity'}." aspectpad.sh -a $aspectpad_ratio -m $aspectpad_mode -p \"$aspectpad_colour\" -t $aspectpad_tolerance $aspectpad_options \"$source_file_path\" \"$target_file_path\"";

    my $print_info = { 'message_prefix' => $aspectpad_id,
		       'message' => "Aspect padding image $source_file_no_path to: $aspectpad_id $target_file_type" };
    $print_info->{'cache_mode'} = $cache_mode if ($cache_mode ne "");

    my ($regenerated,$result,$had_error) 
	= $self->autorun_general_cmd($aspectpad_command,$source_file_path,$target_file_path,$print_info);

    return ($result,$target_file_path);
}





# Discover the characteristics of an image file with the ImageMagick
# "identify" command.

sub identify { 
    my ($image, $outhandle, $verbosity) = @_;

    # Use the ImageMagick "identify" command to get the file specs
    my $command = "\"".&util::get_perl_exec()."\" -S gs-magick.pl identify \"$image\" 2>&1";
    print $outhandle "$command\n" if ($verbosity > 2);
    my $result = '';
    $result = `$command`;
    print $outhandle "$result\n" if ($verbosity > 3);

    # Read the type, width, and height
    my $type =   'unknown';
    my $width =  'unknown';
    my $height = 'unknown';

    my $image_safe = quotemeta $image;
    if ($result =~ /^$image_safe (\w+) (\d+)x(\d+)/) {
	$type = $1;
	$width = $2;
	$height = $3;
    }

    # Read the size
    my $size = "unknown";
    my $size_str="unknown";

    if ($result =~ m/^.* ([0-9]+)b/i) {
	$size_str="$1B"; # display string
	$size = $1;
    }
    elsif ($result =~ m/^.* ([0-9]+)(\.([0-9]+))?kb?/i) {
	# display string stays about the same
	$size_str="$1";
	$size_str.="$2" if defined $2;
	$size_str.="KB";

	$size = 1024 * $1;
	if (defined($2)) {
	    $size = $size + (1024 * $2);
	    # Truncate size (it isn't going to be very accurate anyway)
	    $size = int($size);
	}
    }
    elsif ($result =~ m/^.* ([0-9]+)(\.([0-9]+))?mb?/i) {
	# display string stays about the same
	$size_str="$1";
	$size_str.="$2" if defined $2;
	$size_str.="MB";

	$size = 1024 * 1024 * $1;
        if (defined($2)) {
	    $size = $size + (1024 * 1024 * $2);
            # Truncate size (it isn't going to be very accurate anyway)
            $size = int($size);
        }
    }
    elsif ($result =~ m/^.* ((([0-9]+)(\.([0-9]+))?e\+([0-9]+))(kb|b)?)/i) {
	# display string stays the same
	$size_str="$1";

	# Deals with file sizes on Linux of type "3.4e+02kb" where e+02 is 1*10^2.
	# 3.4e+02 therefore evaluates to 3.4 x 1 x 10^2 = 340kb.
	# Programming languages including Perl know how that 3.4e+02 is a number,
	# so we don't need to do any calculations.
	# $2 is just the number without the kb/b at the end.
	$size = $2*1; # turn the string into a number by multiplying it by 1
	       #if we did $size = $1; $size would be merely the string "3.4e+02"
	$size = int($size); # truncate size
    }
    print $outhandle "file: $image:\t $type, $width, $height, $size, $size_str\n" 
	if ($verbosity > 2);

    # Return the specs
    return ($type, $width, $height, $size, $size_str);
}

sub clean_up_temporary_files {
    my $self = shift(@_);

    foreach my $tmp_file_path (@{$self->{'tmp_file_paths'}}) {
	if (-e $tmp_file_path) {
	    &FileUtils::removeFiles($tmp_file_path);
	}
    }
   
}

# image/jpg is not a valid mime-type, it ought to be image/jpeg. 
# Sometimes JPEG is passed in also, want to keep things lowercase just in case.
sub correct_mime_type {
    my $self = shift(@_);
    my ($file_extension) = @_;
    
    $file_extension = lc($file_extension);
    $file_extension =~ s/jpg/jpeg/s; 

    return $file_extension;
}

1;	
