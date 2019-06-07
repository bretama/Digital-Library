###############################################################################
#
# GDBM.pm -- utility functions for writing to gdbm databases
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

package DBDrivers::GDBM;

# Pragma
use strict;

# Libraries
use util;
use FileUtils;
use DBDrivers::70HyphenFormat;


BEGIN
{
    if (!defined $ENV{'GSDLHOME'} || !defined $ENV{'GSDLOS'}) {
        die("Error! Environment not prepared. Have you sourced setup.bash?\n");
    }
    @DBDrivers::GDBM::ISA = ('DBDrivers::70HyphenFormat');
}


## @function constructor
#
sub new
{
    my $class = shift(@_);
    my $self = DBDrivers::70HyphenFormat->new(@_);
    $self->{'default_file_extension'} = 'gdb';
    # note: file separator agnostic
    $self->{'executable_path'} = FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, 'bin', $ENV{'GSDLOS'});
    $self->{'read_executable'} = 'db2txt';
    $self->{'keyread_executable'} = 'gdbmkeys';
    $self->{'write_executable'} = 'txt2db';
    # Optional Support
    $self->{'supports_set'} = 1;
    bless($self, $class);
    return $self;
}
## new(void) => GDBM ##


# -----------------------------------------------------------------------------
#   GDBM IMPLEMENTATION
# -----------------------------------------------------------------------------

# Handled by BaseDBDriver
# sub get_infodb_file_path(string, string) => string
# sub rename_db_file_to(string, string) => void
# sub remove_db_file(string) => void

# Handled by 70HyphenFormat
# sub open_infodb_write_handle(string, string?) => filehandle
# sub close_infodb_write_handle(filehandle) => void
# sub delete_infodb_entry(filehandle, string) => void
# sub read_infodb_entry(string, string) => hashmap
# sub read_infodb_file(string, hashmap) => void
# sub read_infodb_keys(string, hashmap) => void
# sub read_infodb_rawentry(string, string) => string
# sub set_infodb_entry(string, string, hashmap) => integer
# sub write_infodb_entry(filehandle, string, hashmap) => void
# sub write_infodb_rawentry(filehandle, string, string) => void

1;
