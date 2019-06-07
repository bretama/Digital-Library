###########################################################################
#
# dbutil::jdbm -- utility functions for writing to jdbm databases
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

package dbutil::jdbm;

use strict;


# -----------------------------------------------------------------------------
#   JDBM IMPLEMENTATION
# -----------------------------------------------------------------------------

# When DBUtil::* is properly structured with inheritence, then
# much of this code (along with GDBM and GDBM-TXT-GZ) can be grouped into
# a shared base class.  Really it is only the the command that needs to 
# be constructed that changes between much of the code that is used


sub open_infodb_write_handle
{
  my $infodb_file_path = shift(@_);
  my $opt_append = shift(@_);

  my $jdbmwrap_jar = &util::filename_cat($ENV{'GSDLHOME'},"bin","java", "JDBMWrapper.jar");
  my $jdbm_jar = &util::filename_cat($ENV{'GSDLHOME'},"lib","java", "jdbm.jar");

  my $classpath = &util::pathname_cat($jdbmwrap_jar,$jdbm_jar);

  if ($^O eq "cygwin") {
      # Away to run a java program, using a binary that is native to Windows, so need
      # Windows directory and path separators

      $classpath = `cygpath -wp "$classpath"`;
      chomp($classpath);
      $classpath =~ s%\\%\\\\%g;
  }

  my $infodb_file_handle = undef;
  my $txt2jdb_cmd = "java -cp \"$classpath\" Txt2Jdb";

  if ((defined $opt_append) && ($opt_append eq "append")) {
      $txt2jdb_cmd .= " -append";
      print STDERR "Append operation to $infodb_file_path\n";
  }
  else {
      print STDERR "Create database $infodb_file_path\n";
  }
  
  # Lop off file extension, as JDBM does not expect this to be present
  $infodb_file_path =~ s/\.jdb$//;

  if ($^O eq "cygwin") {
      $infodb_file_path = `cygpath -w "$infodb_file_path"`;
      chomp($infodb_file_path);
      $infodb_file_path =~ s%\\%\\\\%g;
  }

  $txt2jdb_cmd .= " \"$infodb_file_path\"";

  if (!open($infodb_file_handle, "| $txt2jdb_cmd"))
  {
      print STDERR "Error: Failed to open pipe to $txt2jdb_cmd";
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

  my $infodb_file_extension = ".jdb";
  my $infodb_file_name = &util::get_dirsep_tail($collection_name) . $infodb_file_extension;
  return &util::filename_cat($infodb_directory_path, $infodb_file_name);
}


sub read_infodb_file
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  my $jdbmwrap_jar = &util::filename_cat($ENV{'GSDLHOME'},"bin","java", "JDBMWrapper.jar");
  my $jdbm_jar = &util::filename_cat($ENV{'GSDLHOME'},"lib","java", "jdbm.jar");

  my $classpath = &util::pathname_cat($jdbmwrap_jar,$jdbm_jar);

  if ($^O eq "cygwin") {
      # Away to run a java program, using a binary that is native to Windows, so need
      # Windows directory and path separators
      
      $classpath = `cygpath -wp "$classpath"`;
      chomp($classpath);
      $classpath =~ s%\\%\\\\%g;

      $infodb_file_path = `cygpath -w "$infodb_file_path"`;
      chomp($infodb_file_path);
      $infodb_file_path =~ s%\\%\\\\%g;
  }

  my $jdb2txt_cmd = "java -cp \"$classpath\" Jdb2Txt";

  open (PIPEIN, "$jdb2txt_cmd \"$infodb_file_path\" |") || die "couldn't open pipe from db2txt \$infodb_file_path\"\n";
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

  my $jdbmwrap_jar = &util::filename_cat($ENV{'GSDLHOME'},"bin","java", "JDBMWrapper.jar");
  my $jdbm_jar = &util::filename_cat($ENV{'GSDLHOME'},"lib","java", "jdbm.jar");

  my $classpath = &util::pathname_cat($jdbmwrap_jar,$jdbm_jar);

  my $jdbkeys_cmd = "java -cp \"$classpath\" JdbKeys";

  open (PIPEIN, "$jdbkeys_cmd \"$infodb_file_path\" |") || die "couldn't open pipe from jdbmkeys \$infodb_file_path\"\n";
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

  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);

  print $infodb_handle "[$infodb_key]\n";
  foreach my $infodb_value_key (keys(%$infodb_map))
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

    # Store it into JDBM using 'Txt2Jdb .... -append' which despite its name
    # actually replaces the record if it already exists

    my $jdbmwrap_jar = &util::filename_cat($ENV{'GSDLHOME'},"bin","java", "JDBMWrapper.jar");
    my $jdbm_jar = &util::filename_cat($ENV{'GSDLHOME'},"lib","java", "jdbm.jar");
    
    my $classpath = &util::pathname_cat($jdbmwrap_jar,$jdbm_jar);

    # Lop off file extension, as JDBM does not expect this to be present
    $infodb_file_path =~ s/\.jdb$//;

    if ($^O eq "cygwin") {
 	# Away to run a java program, using a binary that is native to Windows, so need
	# Windows directory and path separators
	
      $classpath = `cygpath -wp "$classpath"`;
      chomp($classpath);
      $classpath =~ s%\\%\\\\%g;

      $infodb_file_path = `cygpath -w "$infodb_file_path"`;
      chomp($infodb_file_path);
      $infodb_file_path =~ s%\\%\\\\%g;
    }

    my $cmd = "java -cp \"$classpath\" Txt2Jdb -append \"$infodb_file_path\"";

    my $status = undef;
    if(!open(GOUT, "| $cmd"))
    {
	print STDERR "Error: jdbm::set_infodb_entry() failed to open pipe to: $cmd\n";
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
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  
  # A minus at the end of a key (after the ]) signifies 'delete'
  print $infodb_handle "[$infodb_key]-\n"; 

  # The 70 minus signs are also needed, to help make the parsing by db2txt simple
  print $infodb_handle '-' x 70, "\n";
}


1;
