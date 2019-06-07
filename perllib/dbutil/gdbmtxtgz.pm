###########################################################################
#
# dbutil::gdbmtxtgz -- utility functions for writing to gdbm-txtgz databases
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

package dbutil::gdbmtxtgz;

use strict;



# -----------------------------------------------------------------------------
#   GDBM TXT-GZ IMPLEMENTATION
# -----------------------------------------------------------------------------

sub open_infodb_write_handle
{
  # Keep infodb in GDBM neutral form => save data as compressed text file, 
  # read for txt2db to be run on it later (i.e. by the runtime system,
  # first time the collection is ever accessed).  This makes it easier
  # distribute pre-built collections to various architectures.
  #
  # NB: even if two architectures are little endian (e.g. Intel and 
  # ARM procesors) GDBM does *not* guarantee that the database generated on 
  # one will work on the other

  my $infodb_file_path = shift(@_);

  # Greenstone ships with gzip for windows, on $PATH

  my $infodb_file_handle = undef;
  if (!open($infodb_file_handle, "| gzip - > \"$infodb_file_path\""))
  {
      print STDERR "Error: Failed to open pipe to gzip - > \"$infodb_file_path\"\n";
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

  my $infodb_file_name = &util::get_dirsep_tail($collection_name).".txt.gz";
  return &util::filename_cat($infodb_directory_path, $infodb_file_name);
}


sub read_infodb_file
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  my $cmd = "gzip --decompress --to-stdout \"$infodb_file_path\"";

  open (PIPEIN, "$cmd |") 
  || die "Error: Couldn't open pipe from gzip: $!\n  $cmd\n";

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

  my $cmd = "gzip --decompress --to-stdout \"$infodb_file_path\"";

  open (PIPEIN, "$cmd |") 
  || die "Error: Couldn't open pipe from gzip: $!\n  $cmd\n";

  binmode(PIPEIN,":utf8");
  my $infodb_line = "";
  my $infodb_key = "";
  while (defined ($infodb_line = <PIPEIN>))
  {
    $infodb_line =~ s/(\r\n)+$//; # more general than chomp

    if ($infodb_line =~ /^\[([^\]]+)\]$/)
    {
      $infodb_key = $1;
    }
    elsif ($infodb_line =~ /^-{70}$/)
    {
      $infodb_map->{$infodb_key} = 1;
      $infodb_key = "";
    }
  }

  close (PIPEIN);
}

    
sub write_infodb_entry
{

  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);
  
  print $infodb_handle "[$infodb_key]\n";
  foreach my $infodb_value_key (sort keys(%$infodb_map))
  {
    foreach my $infodb_value (@{$infodb_map->{$infodb_value_key}})
    {
      if ($infodb_value =~ /-{70,}/)
      {
        # if value contains 70 or more hyphens in a row we need to escape them
        # to prevent txt2db from treating them as a separator
        $infodb_value =~ s/-/&\#045;/gi;
      }
      print $infodb_handle "<$infodb_value_key>" . $infodb_value . "\n";
    }
  }
  print $infodb_handle '-' x 70, "\n";
}


    
sub write_infodb_rawentry
{

  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_val = shift(@_);
  
  print $infodb_handle "[$infodb_key]\n";
  print $infodb_handle "$infodb_val\n";
  print $infodb_handle '-' x 70, "\n";
}

 sub set_infodb_entry
{
  my $infodb_file_path = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);
  
  print STDERR "***** gdbmtxtgz::set_infodb_entry() not implemented yet!\n";
}



sub delete_infodb_entry
{

  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  

  # A minus at the end of a key (after the ]) signifies 'delete'
  print $infodb_handle "[$infodb_key]-\n"; 

  # The 70 minus signs are also needed, to help make the parsing by db2txt simple
  print $infodb_handle '-' x 70, "\n";
}



1;
