###########################################################################
#
# extrametautil.pm -- various useful utilities
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

package extrametautil;

use strict;

use util;
#use Encode;
#use File::Copy;
use File::Basename;


#******************* ADD: add extrametakey, add extrametadata *********************#
sub addmetakey {
	my ($extrametakeys, $filename_re_for_metadata) = @_;
	push(@$extrametakeys, $filename_re_for_metadata);
}

# Unused. Added for symmetry
sub addmetadata {
	my ($extrametadata, $filename_re_for_metadata, $value) = @_;	
	my $metanames = $extrametadata->{$filename_re_for_metadata};
	push(@$metanames, $value);
}

# Unused. Added for symmetry
sub addmetafile {
	my ($extrametafile, $filename_re_for_metadata, $file) = @_;	
	my $metafiles = $extrametafile->{$filename_re_for_metadata};
	push(@$metafiles, $file);
}

sub addmetadata_for_named_metaname { # e.g. push(@{$extrametadata->{$filename_re_for_metadata}->{$field_name}}, $value);
	my ($extrametadata, $filename_re_for_metadata, $field_name, $value) = @_;
	my $metaname_vals = $extrametadata->{$filename_re_for_metadata}->{$field_name};
	push(@$metaname_vals, $value); 
}

# Unused. Added for symmetry
sub addmetafile_for_named_file {	
	my ($extrametafile, $filename_re_for_metadata, $file, $filename_full_path) = @_;
	my $metafile_vals = $extrametafile->{$filename_re_for_metadata}->{$file};
	push(@$metafile_vals, $filename_full_path); 
}


#**************** In future, may be useful to expand this utility file 
#**************** by having remove methods to mirror the add methods


#******************* GET methods
sub getmetadata {
	my ($extrametadata, $filename_re_for_metadata) = @_;
	return $extrametadata->{$filename_re_for_metadata};
}

sub getmetafile {
	my ($extrametafile, $filename_re_for_metadata) = @_;
	return $extrametafile->{$filename_re_for_metadata};
}

sub getmetadata_for_named_metaname {
	my ($extrametadata, $filename_re_for_metadata, $field_name) = @_;
	return $extrametadata->{$filename_re_for_metadata}->{$field_name}; # e.g. $extrametadata->{$filename_re_for_metadata}->{$field_name}
}

# Unused. Added for symmetry
sub getmetadata_for_named_file {
	my ($extrametafile, $filename_re_for_metadata, $file) = @_;
	return $extrametafile->{$filename_re_for_metadata}->{$file};
}

sub getmetadata_for_named_pos {
	my ($extrametadata, $filename_re_for_metadata, $metaname, $index) = @_;
	return $extrametadata->{$filename_re_for_metadata}->{$metaname}->[$index]; # e.g. $extrametadata->{$filename_re_for_metadata}->{"dc.Identifier"}->[0]
}


#******************* SET methods
sub setmetadata {
	my ($extrametadata, $filename_re_for_metadata, $value) = @_;
	$extrametadata->{$filename_re_for_metadata} = $value;
}

sub setmetafile { # e.g. $extrametafile{$filename_re_for_metadata} = $file;
	my ($extrametafile, $filename_re_for_metadata, $file) = @_;
	$extrametafile->{$filename_re_for_metadata} = $file; 
}

sub setmetadata_for_named_metaname {
	my ($extrametadata, $filename_re_for_metadata, $field_name, $value) = @_;
	$extrametadata->{$filename_re_for_metadata}->{$field_name} = $value;
}

sub setmetafile_for_named_file {
	my ($extrametafile, $filename_re_for_metadata, $file, $filename_full_path) = @_;
	$extrametafile->{$filename_re_for_metadata}->{$file} = $filename_full_path;
}

# Unused. Added for symmetry
sub setmetadata_for_named_pos {
	my ($extrametadata, $filename_re_for_metadata, $metaname, $index, $value) = @_;
	$extrametadata->{$filename_re_for_metadata}->{$metaname}->[$index] =  $value;
}


1;
