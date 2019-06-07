###############################################################################
#
# GDBMTXTGZ.pm -- utility functions for writing to gdbm-txtgz databases
#
# A component of the Greenstone digital library software from the New Zealand
# Digital Library Project at the University of Waikato, New Zealand.
#
# Copyright (c) 2015 New Zealand Digital Library Project
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

package DBDrivers::GDBMTXTGZ;

# Pragma
use strict;

# Libraries
use util;
use FileUtils;
use DBDrivers::70HyphenFormat;

BEGIN
{
    @DBDrivers::GDBMTXTGZ::ISA = ('DBDrivers::70HyphenFormat');
}


## Constructor
sub new
{
    my $class = shift(@_);
    my $self = DBDrivers::70HyphenFormat->new(@_);
    # Default TDB file extension
    $self->{'default_file_extension'} = 'txt.gz';
    # note: file separator agnostic
    $self->{'executable_path'} = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, 'bin', $ENV{'GSDLOS'});
    $self->{'read_executable'} = 'gzip --decompress --to-stdout';
    $self->{'keyread_executable'} = $self->{'read_executable'};
    $self->{'write_executable'} = 'gzip -';
    bless ($self, $class);
    return $self;
}

# -----------------------------------------------------------------------------
#   GDBM TXT-GZ IMPLEMENTATION
# -----------------------------------------------------------------------------

# Handled by BaseDBDriver
# sub get_infodb_file_path(string, string)

# Handled by 70HyphenFormat
# sub close_infodb_write_handle(filehandle) => void
# sub read_infodb_file(string, hashmap) => void
# sub read_infodb_keys(string, hashmap) => void
# sub write_infodb_entry(filehandle, string, hashmap) => void
# sub write_infodb_rawentry(filehandle, string, string) => void


## @function open_infodb_write_handle(string)
#
# Keep infodb in GDBM neutral form => save data as compressed text file, read
# for txt2db to be run on it later (i.e. by the runtime system, first time the
# collection is ever accessed).  This makes it easier distribute pre-built
# collections to various architectures.
#
# NB: even if two architectures are little endian (e.g. Intel and ARM procesors)
# GDBM does *not* guarantee that the database generated on one will work on the
# other
#
# Now only responsible for transforming the optional append argument into the
# correct redirection operand (either > for clobber or >> for append)
#
sub open_infodb_write_handle
{
    my $self = shift(@_);
    my $infodb_file_path = shift(@_);
    my $opt_append = shift(@_);
    my $infodb_file_handle;
    # append
    if (defined $opt_append && $opt_append =~ /^-?append$/) {
	$infodb_file_handle = $self->SUPER::open_infodb_write_handle($infodb_file_path, '>>');
    }
    # create or clobber
    else {
	$infodb_file_handle = $self->SUPER::open_infodb_write_handle($infodb_file_path, '>');
    }
    return $infodb_file_handle;
}
## open_infodb_write_handle(string) => filehandle ##

## @function set_infodb_entry(string, string, hashmap)
#
sub set_infodb_entry
{
    my $self = shift(@_);
    print STDERR "***** gdbmtxtgz::set_infodb_entry() not implemented yet!\n";
}
## set_infodb_entry(string, string, hashmap) => void ##


1;
