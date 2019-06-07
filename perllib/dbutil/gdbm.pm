###########################################################################
#
# dbutil::gdbm -- utility functions for writing to gdbm databases
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009
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

package dbutil::gdbm;

use strict;

use util;
use FileUtils;
use dbutil::gdbmtxtgz;

# -----------------------------------------------------------------------------
#   GDBM IMPLEMENTATION
# -----------------------------------------------------------------------------

sub open_infodb_write_handle
{
  my $infodb_file_path = shift(@_);
  my $opt_append = shift(@_);

  my $txt2db_exe = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin",$ENV{'GSDLOS'}, "txt2db" . &util::get_os_exe());
  my $infodb_file_handle = undef;
  my $cmd = "\"$txt2db_exe\"";
  if ((defined $opt_append) && ($opt_append eq "append")) {
      $cmd .= " -append";
  }
  $cmd .= " \"$infodb_file_path\"";

  if (!-e "$txt2db_exe")
  {
      print STDERR "Error: Unable to find $txt2db_exe\n";
      return undef;
  }

  if(!open($infodb_file_handle, "| $cmd"))
  {

      print STDERR "Error: Failed to open pipe to $cmd\n";
      print STDERR "       $!\n";
      return undef;
  }

  binmode($infodb_file_handle,":utf8");

  return $infodb_file_handle;
}



sub close_infodb_write_handle
{
  my $infodb_handle = shift(@_);

  close($infodb_handle);
}


sub get_infodb_file_path
{
  my $collection_name = shift(@_);
  my $infodb_directory_path = shift(@_);

  my $infodb_file_extension = ".gdb";
  my $infodb_file_name = &util::get_dirsep_tail($collection_name) . $infodb_file_extension;
  return &FileUtils::filenameConcatenate($infodb_directory_path, $infodb_file_name);
}


sub read_infodb_file
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  open (PIPEIN, "db2txt \"$infodb_file_path\" |") 
      || die "couldn't open pipe from db2txt \$infodb_file_path\"\n";

  binmode(PIPEIN,":utf8");

  my $infodb_line = "";
  my $infodb_key = "";
  my $infodb_value = "";
  while (defined ($infodb_line = <PIPEIN>))
  {
    $infodb_line =~ s/(\r\n)+$//; # more general than chomp

    if ($infodb_line =~ /^\[([^\]]+)\]$/)
    {
      $infodb_key = $1;
    }
    elsif ($infodb_line =~ /^-{70}$/)
    {
      $infodb_map->{$infodb_key} = $infodb_value;
      $infodb_key = "";
      $infodb_value = "";
    }
    else
    {
      $infodb_value .= $infodb_line;
    }
  }

  close (PIPEIN);
}

sub read_infodb_keys
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  open (PIPEIN, "gdbmkeys \"$infodb_file_path\" |") 
      || die "couldn't open pipe from gdbmkeys \$infodb_file_path\"\n";

  binmode(PIPEIN,":utf8");

  my $infodb_line = "";
  my $infodb_key = "";
  my $infodb_value = "";
  while (defined ($infodb_line = <PIPEIN>))
  {
      # chomp $infodb_line; # remove end of line 
      $infodb_line =~ s/(\r\n)+$//; # more general than chomp

      $infodb_map->{$infodb_line} = 1;
  }

  close (PIPEIN);
}

sub write_infodb_entry
{
  # With infodb_handle already set up, works the same as _gdbm_txtgz version
  &dbutil::gdbmtxtgz::write_infodb_entry(@_);
}

sub write_infodb_rawentry
{
  # With infodb_handle already set up, works the same as _gdbm_txtgz version
  &dbutil::gdbmtxtgz::write_infodb_rawentry(@_);
}


sub set_infodb_entry_OLD
{
    my $infodb_file_path = shift(@_);
    my $infodb_key = shift(@_);
    my $infodb_map = shift(@_);
  
    # Protect metadata values that go inside quotes for gdbmset
    foreach my $k (keys %$infodb_map) {
	  my @escaped_v = ();
	  foreach my $v (@{$infodb_map->{$k}}) {
	    if ($k eq "contains") {
		  # protect quotes in ".2;".3 etc
		  $v =~ s/\"/\\\"/g;
		  push(@escaped_v, $v);
	    }
	    else {
		  my $ev = &ghtml::unescape_html($v);
		  $ev =~ s/\"/\\\"/g;
		  push(@escaped_v, $ev);
	    }
	  }
	  $infodb_map->{$k} = \@escaped_v;
	}
	
    # Generate the record string
    my $serialized_infodb_map = &dbutil::convert_infodb_hash_to_string($infodb_map);
##    print STDERR "**** ser dr\n$serialized_infodb_map\n\n\n";

    # Store it into GDBM
    my $cmd = "gdbmset \"$infodb_file_path\" \"$infodb_key\" \"$serialized_infodb_map\"";
    my $status = system($cmd);

    return $status;
  
}



sub set_infodb_entry
{
    my $infodb_file_path = shift(@_);
    my $infodb_key = shift(@_);
    my $infodb_map = shift(@_);
  
    # HTML escape anything that is not part of the "contains" metadata value
    foreach my $k (keys %$infodb_map) {
	  my @escaped_v = ();
	  foreach my $v (@{$infodb_map->{$k}}) {
	    if ($k eq "contains") {
		  push(@escaped_v, $v);
	    }
	    else {
		  my $ev = &ghtml::unescape_html($v);
		  push(@escaped_v, $ev);
	    }
	  }
	  $infodb_map->{$k} = \@escaped_v;
	}
	
    # Generate the record string
    my $serialized_infodb_map = &dbutil::convert_infodb_hash_to_string($infodb_map);
###    print STDERR "**** ser dr\n$serialized_infodb_map\n\n\n";

    # Store it into GDBM using 'txt2db -append' which despite its name
    # actually replaces the record if it already exists

    my $cmd = "txt2db -append \"$infodb_file_path\"";

    my $status = undef;
    if(!open(GOUT, "| $cmd"))
    {
	print STDERR "Error: gdbm::set_infodb_entry() failed to open pipe to: $cmd\n";
	print STDERR "       $!\n";
	$status = -1;
    }
    else {
	binmode(GOUT,":utf8");
	
	print GOUT "[$infodb_key]\n";
	print GOUT "$serialized_infodb_map\n";

	close(GOUT);
	$status = 0; # as in exit status of cmd OK
    }

    return $status;  
}


sub delete_infodb_entry
{
  # With infodb_handle already set up, works the same as _gdbm_txtgz version
  &dbutil::gdbmtxtgz::delete_infodb_entry(@_);
}



1;
