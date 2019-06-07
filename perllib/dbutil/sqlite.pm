###########################################################################
#
# dbutil::sqlite -- utility functions for writing to sqlite databases
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2009-2010  DL Consulting Ltd.
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

package dbutil::sqlite;

use strict;

# Please set $db_fast to 1 if you wish to enable faster I/O to the database by using
# optimisations such as PRAGMA journal_mode (MEMORY instead of DELETE) and synchronous (OFF instead of FULL)
# Please be aware that in this case it will be less secure and the database file
# may become corrupted if the if the operating system crashes or the computer loses
# power before that data has been written to the disk surface.
# But the speed gain is about 50x
my $db_fast = 0;

# Set to 1 to enable Write Ahead Logging - which is supposed to allow multiple
# readers/writers on a SQLite database (incompatible with db_fast). From SQLite
# 3.7 onwards, WAL offers limited parallel reader/writer support but is limited
# to single computers (doesn't work over networked filesystems). For details
# see: http://www.sqlite.org/draft/wal.html [jmt12]
my $db_wal = 0;

# -----------------------------------------------------------------------------
#   SQLITE IMPLEMENTATION
# -----------------------------------------------------------------------------

sub open_infodb_write_handle
{
  my $infodb_file_path = shift(@_);
  my $opt_append = shift(@_);
 
  my $sqlite3_exe = &util::filename_cat($ENV{'GSDLHOME'},"bin",$ENV{'GSDLOS'}, "sqlite3" . &util::get_os_exe());
  my $infodb_handle = undef;

  if (!-e "$sqlite3_exe")
  {
      print STDERR "Error: Unable to find $sqlite3_exe\n";
      return undef;
  } 

  # running sqlite3 with the pragma journal_mode=memory, causes sqlite to print out the 
  # word "memory". While this is not a problem usually, in our case, this ends up going out
  # to the web page first, as part of the web page's headers, thus ruining the web page
  # which causes an Internal Server Error (500). Therefore, we redirect sqlite's output to
  # the nul device instead.
  # using WAL mode (which also changes the journal) suffers a similar issue [jmt12]
  my $nul_device="";
  if($db_fast == 1 || $db_wal == 1) {
	if($ENV{'GSDLOS'} =~ m/windows/) {
		$nul_device=">NUL";
	} else {
		$nul_device=">/dev/null"; # linux, mac
	}
  }  
  
  if(!open($infodb_handle, "| \"$sqlite3_exe\" \"$infodb_file_path\"$nul_device"))
  {
      print STDERR "Error: Failed to open pipe to \"$sqlite3_exe\" \"$infodb_file_path\"\n";
      print STDERR "       $!\n";
      return undef;
  }

  binmode($infodb_handle,":utf8");
  
   # Add extra optimisations, less secure but with a massive gain in performance with large databases which are often uptaded
   # They should be set before the transaction begins
  if (defined $db_fast && $db_fast == 1) {
	print $infodb_handle "PRAGMA synchronous=OFF;\n";
	print $infodb_handle "PRAGMA journal_mode=MEMORY;\n";
  }
  # Allow parallel readers/writers by using a Write Ahead Logger
  elsif ($db_wal)
  {
    print $infodb_handle "PRAGMA journal_mode=WAL;\n";
  }

  # This is very important for efficiency, otherwise each command will be actioned one at a time
  print $infodb_handle "BEGIN TRANSACTION;\n";
  


  if (!(defined $opt_append) || ($opt_append ne "append")) {
    print $infodb_handle "DROP TABLE IF EXISTS data;\n";
	print $infodb_handle "DROP TABLE IF EXISTS document_metadata;\n";
  }
   
  print $infodb_handle "CREATE TABLE IF NOT EXISTS data (key TEXT PRIMARY KEY, value TEXT);\n";
  print $infodb_handle "CREATE TABLE IF NOT EXISTS document_metadata (id INTEGER PRIMARY KEY, docOID TEXT, element TEXT, value TEXT);\n";

  # This is crucial for efficiency when importing large amounts of data
  print $infodb_handle "CREATE INDEX IF NOT EXISTS dmd ON document_metadata(docOID);\n";

  return $infodb_handle;
}


sub close_infodb_write_handle
{
  my $infodb_handle = shift(@_);

  # This is crucial for efficient queries on the database!
  print $infodb_handle "CREATE INDEX IF NOT EXISTS dme ON document_metadata(element);\n";
  
  # Close the transaction we began after opening the file
  print $infodb_handle "END TRANSACTION;\n";

  close($infodb_handle);
}


sub read_infodb_cmd
{
  my $infodb_file_path = shift(@_);
  my $sqlcmd = shift(@_);

  my $result = "";

  my $sqlite3_exe = &util::filename_cat($ENV{'GSDLHOME'},"bin",$ENV{'GSDLOS'}, "sqlite3" . &util::get_os_exe());
  my $infodb_handle = undef;
  my $cmd = "\"$sqlite3_exe\" \"$infodb_file_path\" \"$sqlcmd\"";

  if (!-e "$sqlite3_exe" || !open($infodb_handle, "$cmd |"))
  {
      print STDERR "Unable to execute: $cmd\n";
      print STDERR "$!\n";
  }
  else {

      binmode($infodb_handle, ":utf8");
      my $line;
      while (defined($line=<$infodb_handle>)) {
	  $result .= $line;
      }

      close($infodb_handle);
  }

  return $result;
}

sub get_infodb_file_path
{
  my $collection_name = shift(@_);
  my $infodb_directory_path = shift(@_);

  my $infodb_file_extension = ".db";
  my $infodb_file_name = &util::get_dirsep_tail($collection_name) . $infodb_file_extension;
  return &util::filename_cat($infodb_directory_path, $infodb_file_name);
}


sub read_infodb_file
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);


  my $keys_str = read_infodb_cmd($infodb_file_path,"SELECT key FROM data ORDER BY key;");

  my @keys = split(/\n/,$keys_str);

  foreach my $k (@keys) {
      
      my $k_safe = &sqlite_safe($k);
      my $select_val_cmd = "SELECT value FROM data WHERE key='$k_safe';";

      my $val_str = read_infodb_cmd($infodb_file_path,$select_val_cmd);

      $infodb_map->{$k} = $val_str;
  }

}


sub read_infodb_keys
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);


  my $keys_str = read_infodb_cmd($infodb_file_path,"SELECT key FROM data;");

  my @keys = split(/\n/,$keys_str);

  foreach my $key (@keys)
  {
      $infodb_map->{$key} = 1;
  }
}

sub read_infodb_rawentry
{
  my $infodb_file_path = shift(@_);
  my $infodb_key = shift(@_);

  
  my $key_safe = &sqlite_safe($infodb_key);
  my $select_val_cmd = "SELECT value FROM data WHERE key='$key_safe';";

  my $val_str = read_infodb_cmd($infodb_file_path,$select_val_cmd);

  return $val_str
}

sub read_infodb_entry
{
  my $infodb_file_path = shift(@_);
  my $infodb_key = shift(@_);

  my $val_str = read_infodb_rawentry($infodb_file_path,$infodb_key);
  
  my $rec_hash = &dbutil::convert_infodb_string_to_hash($val_str);

  return $rec_hash;
}


sub write_infodb_entry
{
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);
  

  # Add the key -> value mapping into the "data" table
  my $infodb_entry_value = "";
  foreach my $infodb_value_key (keys(%$infodb_map))
  {
    foreach my $infodb_value (@{$infodb_map->{$infodb_value_key}})
    {
      $infodb_entry_value .= "<$infodb_value_key>" . $infodb_value . "\n";
    }
  }
  
  my $safe_infodb_key = &sqlite_safe($infodb_key);
  print $infodb_handle "INSERT OR REPLACE INTO data (key, value) VALUES ('" . $safe_infodb_key . "', '" . &sqlite_safe($infodb_entry_value) . "');\n";

  # If this infodb entry is for a document, add all the interesting document metadata to the
  #   "document_metadata" table (for use by the dynamic classifiers)
  if ($infodb_key !~ /\./ && $infodb_entry_value =~ /\<doctype\>doc\n/)
  {
	
    print $infodb_handle "DELETE FROM document_metadata WHERE docOID='" . $safe_infodb_key . "';\n";
	
    foreach my $infodb_value_key (keys(%$infodb_map))
    {
      # We're not interested in most of the automatically added document metadata
      next if ($infodb_value_key eq "archivedir" ||
               $infodb_value_key eq "assocfilepath" ||
               $infodb_value_key eq "childtype" ||
               $infodb_value_key eq "contains" ||
               $infodb_value_key eq "docnum" ||
               $infodb_value_key eq "doctype" ||
               $infodb_value_key eq "Encoding" ||
               $infodb_value_key eq "FileSize" ||
               $infodb_value_key eq "hascover" ||
               $infodb_value_key eq "hastxt" ||
               $infodb_value_key eq "lastmodified" ||
               $infodb_value_key eq "metadataset" ||
               $infodb_value_key eq "thistype" ||
               $infodb_value_key =~ /^metadatafreq\-/ ||
               $infodb_value_key =~ /^metadatalist\-/);

      foreach my $infodb_value (@{$infodb_map->{$infodb_value_key}})
      {
		 print $infodb_handle "INSERT INTO document_metadata (docOID, element, value) VALUES ('" . $safe_infodb_key . "', '" . &sqlite_safe($infodb_value_key) . "', '" . &sqlite_safe($infodb_value) . "');\n";
      }
    }
  }

	 #### DEBUGGING
	#my $new_file = "D:\\sql.txt";
	#open(FOUT, ">>$new_file") or die "Unable to open $new_file for writing out sql statements...ERROR: $!\n";
    #print FOUT "BEGIN;\n".$insertStatementsBuffer."\nEND;\n";
    #close(FOUT);
	#print STDERR $insertStatementsBuffer; 
	 #### END DEBUGGING
}

sub write_infodb_rawentry
{
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_val = shift(@_);

  my $safe_infodb_key = &sqlite_safe($infodb_key);
  print $infodb_handle "INSERT OR REPLACE INTO data (key, value) VALUES ('" . $safe_infodb_key . "', '" . &sqlite_safe($infodb_val) . "');\n";
}


sub set_infodb_entry
{
  my $infodb_file_path = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);
  my $infodb_handle = open_infodb_write_handle($infodb_file_path, "append");

  if (!defined $infodb_handle) {
      print STDERR "Error: Failed to open infodb write handle\n";
	  return -1;
  }
  else {
	  write_infodb_entry($infodb_handle,$infodb_key,$infodb_map);
      close_infodb_write_handle($infodb_handle);
  }
  # Not currently checking for errors on write to DB
  return 0;

}



sub delete_infodb_entry
{
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);

  # Delete the key from the "data" table

  my $safe_infodb_key = &sqlite_safe($infodb_key);

  print $infodb_handle "DELETE FROM data WHERE key='" . $safe_infodb_key . "';\n";

  # If this infodb entry is for a document, delete the
  #   "document_metadata" table entry also (for use by the dynamic classifiers)
  if ($infodb_key !~ /\./)
  {
      # Possible for there not to be a docOID matching this infodb_key
      # (entries are only made when <doctype> == doc
      # Attempt to delete it, and don't complain if one isn't found

      print $infodb_handle "DELETE FROM document_metadata WHERE docOID='" . $safe_infodb_key . "';\n";

  }
}


sub sqlite_safe
{
  my $value = shift(@_);

  # Escape any single quotes in the value
  $value =~ s/\'/\'\'/g;

  return $value;
}


1;
