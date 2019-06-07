###############################################################################
#
# DBDrivers/MSSQL.pm -- utility functions for writing to mssql databases
#
# A component of the Greenstone digital library software from the New Zealand
# Digital Library Project at the University of Waikato, New Zealand.
#
# Copyright (C) 1999-2015 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 675 Mass
# Ave, Cambridge, MA 02139, USA.
#
###############################################################################

package DBDrivers::MSSQL;

# Pragma
use strict;

# Libraries
use Encode;
use DBDrivers::BaseDBDriver;

sub BEGIN
{
    @DBDrivers::MSSQL::ISA = ( 'DBDrivers::BaseDBDriver' );
}

sub new
{
    my $class = shift(@_);
    if ($^O !~ /cygwin|MSWin32/) {
        print STDERR "Warning! Non-Windows operating system detected... good luck getting this to work.\n";
    }
    return bless ($self, $class);
}

# -----------------------------------------------------------------------------
#   MSSQL IMPLEMENTATION
# -----------------------------------------------------------------------------

# The hard coded server connection thingy which should be place in some
# configuration file.
# If you have problem connecting to your MS SQL server:
# 1. Check if your MSSQL server has been started.
# 2. Check if the TCP/IP connection has been enabled.
# 3. Use telnet to the server
# (don't forget to specify the port, which can be found in the configuration manager)
# If none of the above helped, the you need to start googling then.
my $host = "localhost,1660"; # Need to look up your SQL server and see what port is it using.
my $user = "sa"; # Generally "sa" for default admin, but YMMV
my $pwd = "[When installing the MSSQL, you will be asked to input a password for the sa user, use that password]";
my $database = "[Create a database in MSSQL and use it here]";

my $mssql_collection_name = "";
my $mssql_data_table_name = "";
my $mssql_document_metadata_table_name = "";


sub open_infodb_write_handle
{
  my $infodb_file_path = shift(@_);

  # You might have to install the DBD::ADO module from CPAN
  use DBI;
  use DBD::ADO;
  Win32::OLE->Option(CP => Win32::OLE::CP_UTF8);

  # Create the unique name for the table
  # We do not want to change the database for the current running index
  # Therefore we use timestamp and collection short name to create an unqiue name
  my $cur_time = time();
  my $unique_key = $mssql_collection_name . "_" . $cur_time;
  $mssql_data_table_name = "data_" . $unique_key;
  $mssql_document_metadata_table_name = "document_metadata_" . $unique_key;
  print STDERR "MSSQL: Creating unique table name. Unique ID:[" . $unique_key . "]\n";
      
  # Store these information into the infodbfile  
  open(FH, ">" . $infodb_file_path);
  print FH "mss-host\t" . $host . "\n";
  print FH "username\t" . $user . "\n";
  print FH "password\t" . $pwd . "\n";
  print FH "database\t" . $database . "\n";
  print FH "tableid\t" . $unique_key . "\n";
  close(FH);
  print STDERR "MSSQL: Saving db info into :[" . $infodb_file_path . "]\n";

  # Make the connection
  my $dsn = "Provider=SQLNCLI;Server=$host;Database=$database";
  my $infodb_handle = DBI->connect("dbi:ADO:$dsn", $user, $pwd, { RaiseError => 1, AutoCommit => 1}) || return undef;
  print STDERR "MSSQL: Connect to MS SQL database. DSN:[" . $dsn . "]\n";

  # Make sure the data table has been created.
  my $data_table_checker_array = dbgetarray($infodb_handle, "SELECT name FROM sysobjects WHERE name = '" . $mssql_data_table_name . "' AND OBJECTPROPERTY(id,'IsUserTable') = 1");
  if (scalar(@{$data_table_checker_array}) == 0)
  {
    dbquery($infodb_handle, "CREATE TABLE " . $mssql_data_table_name . " (one_key NVARCHAR(50) UNIQUE, one_value NVARCHAR(MAX))");
  }
  print STDERR "MSSQL: Making sure the data table(" . $mssql_data_table_name . ") exists\n";
    
  # Make sure the document_metadata table has been created.
  my $document_metadata_table_checker_array = dbgetarray($infodb_handle, "SELECT name FROM sysobjects WHERE name = '" . $mssql_document_metadata_table_name . "' AND OBJECTPROPERTY(id,'IsUserTable') = 1");
  if (scalar(@{$document_metadata_table_checker_array}) == 0)
  {
    dbquery($infodb_handle, "CREATE TABLE " . $mssql_document_metadata_table_name . " (id INTEGER IDENTITY(1,1) PRIMARY KEY, docOID NVARCHAR(50), element NVARCHAR(MAX), value NVARCHAR(MAX))");
    dbquery($infodb_handle, "CREATE INDEX dmd ON " . $mssql_document_metadata_table_name . "(docOID)");
  } 
  print STDERR "MSSQL: Making sure the document_metadata table(" . $mssql_data_table_name . ") exists.\n";
  
  return $infodb_handle;
}


sub close_infodb_write_handle
{
  my $infodb_handle = shift(@_);    
  
  $infodb_handle->disconnect();
}


sub get_infodb_file_path
{
  my $collection_name = shift(@_);
  my $infodb_directory_path = shift(@_);

  my $infodb_file_extension = ".mssqldbinfo";
  my $infodb_file_name = &util::get_dirsep_tail($collection_name) . $infodb_file_extension;
  
  # This will be used in the open_infodb_write_handle function
  $mssql_collection_name =  $collection_name;

  return &util::filename_cat($infodb_directory_path, $infodb_file_name);
}


sub read_infodb_file
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  print STDERR "******* mssql::read_infodb_file() TO BE IMPLEMENTED!\n";
  print STDERR "******* See sqlite.pm for comparable implementation that has been coded up!\n";
}

sub read_infodb_keys
{
  my $infodb_file_path = shift(@_);
  my $infodb_map = shift(@_);

  print STDERR "******* mssql::read_infodb_keys() TO BE IMPLEMENTED!\n";
  print STDERR "******* See sqlite.pm for comparable implementation that has been coded up!\n";
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
      $infodb_entry_value .= "<$infodb_value_key>" . &Encode::decode_utf8($infodb_value) . "\n";
    }
  }
  
  # Prepare the query
  my $safe_infodb_key = &mssql_safe($infodb_key);
  my $query = "INSERT INTO " . $mssql_data_table_name . " (one_key, one_value) VALUES (N'" . $safe_infodb_key . "', N'" . &mssql_safe($infodb_entry_value) . "')";
  dbquery($infodb_handle, $query);
  
  # If this infodb entry is for a document, add all the interesting document metadata to the
  # "document_metadata" table (for use by the dynamic classifiers)
  if ($infodb_key !~ /\./ && $infodb_entry_value =~ /\<doctype\>doc\n/)
  {
    dbquery($infodb_handle, "DELETE FROM " . $mssql_document_metadata_table_name . " WHERE docOID=N'" . $safe_infodb_key . "'");
    
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
        $infodb_handle->{LongReadLen} = 65535; # Added for the encoding issue
        my $query = "INSERT INTO " . $mssql_document_metadata_table_name . " (docOID, element, value) VALUES (N'" . $safe_infodb_key . "', N'" . &mssql_safe(&Encode::decode_utf8($infodb_value_key)) . "', N'" . &mssql_safe(&Encode::decode_utf8($infodb_value)) . "')";
        dbquery($infodb_handle, $query);
      }
    }
  }
}


sub write_infodb_rawentry
{
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_val = shift(@_);
  
  # Prepare the query
  my $safe_infodb_key = &mssql_safe($infodb_key);
  my $query = "INSERT INTO " . $mssql_data_table_name . " (one_key, one_value) VALUES (N'" . $safe_infodb_key . "', N'" . &mssql_safe($infodb_val) . "')";
  dbquery($infodb_handle, $query);
}


 sub set_infodb_entry
{
  my $infodb_file_path = shift(@_);
  my $infodb_key = shift(@_);
  my $infodb_map = shift(@_);
  
  print STDERR "***** mssql::set_infodb_entry() not implemented yet!\n";
}

sub delete_infodb_entry
{
  my $infodb_handle = shift(@_);
  my $infodb_key = shift(@_);
  
  # Delete the key from the "data" table

  
  # Prepare the query
  my $safe_infodb_key = &mssql_safe($infodb_key);
  my $query = "DELETE FROM " . $mssql_data_table_name . " WHERE one_key=N'" . $safe_infodb_key . "'";
  dbquery($infodb_handle, $query);
  
  # If this infodb entry is for a document, add all the interesting document metadata to the
  # "document_metadata" table (for use by the dynamic classifiers)
  if ($infodb_key !~ /\./)
  {
      # Possible for there not to be a docOID matching this infodb_key
      # (entries are only made when <doctype> == doc
      # Attempt to delete it, and don't complain if one isn't found

      dbquery($infodb_handle, "DELETE FROM " . $mssql_document_metadata_table_name . " WHERE docOID=N'" . $safe_infodb_key . "'");
      
  }
}



sub mssql_safe
{
  my $value = shift(@_);
  
  # Escape any single quotes in the value
  $value =~ s/\'/\'\'/g;
  
  return $value;
}


sub dbquery
{
  my $infodb_handle = shift(@_);
  my $sql_query = shift(@_);

  # Execute the SQL statement
  my $statement_handle = $infodb_handle->prepare($sql_query);
  $statement_handle->execute();
  if ($statement_handle->err) 
  {
    print STDERR "Error:" . $statement_handle->errstr . "\n";
    return undef;
  }
  
  return $statement_handle;
}


sub dbgetarray
{
  my $infodb_handle = shift(@_);
  my $sql_query = shift(@_);
  
  my $statement_handle = dbquery($infodb_handle, $sql_query);
  my $return_array = [];
  
  # Iterate through the results and push them into an array
  if (!defined($statement_handle)) 
  {
    return [];
  }
  
  while ((my $temp_hash = $statement_handle->fetchrow_hashref()))
  {
    push(@$return_array, $temp_hash);
  }

  return $return_array; 
}


1;
