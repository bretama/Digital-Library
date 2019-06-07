###############################################################################
#
# 70HyphenFormat.pm -- The parent class of drivers that use the basic GS format
#                      of a text obeying these rules:
#
#                      <line>      := <uniqueid> <metadata>+ <separator>
#                      <uniqueid>  := \[[a-z][a-z0-9]*\]\n
#                      <metadata>  := <[a-z][a-z0-9]*>(^-{70})+\n
#                      <separator> := -{70}\n
#
#                      Contains some utility functions useful to any driver
#                      that makes use of this format.
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

# Note: This driver may be a candidate for further splitting, maybe into a
# PipedExecutableDriver and a 70HyphenFormatDriver... but for now all piped
# drivers are 70 hyphen format ones, so, yeah.

package DBDrivers::70HyphenFormat;

# Pragma
use strict;

# Libraries
use ghtml;
use util;
use FileUtils;

use DBDrivers::BaseDBDriver;

BEGIN {
    @DBDrivers::70HyphenFormat::ISA = ('DBDrivers::BaseDBDriver');
}

use constant {
    RWMODE_READ  => '-|',
    RWMODE_WRITE => '|-',
};

## @function constructor
#
sub new
{
    my $class = shift(@_);
    my $self = DBDrivers::BaseDBDriver->new(@_);
    $self->{'executable_path'} = 'error';
    $self->{'keyread_executable'} = 'error';
    $self->{'read_executable'} = 'error';
    $self->{'write_executable'} = 'error';
    #
    $self->{'forced_affinity'} = -1; # Set to processor number for forced affinity
    bless($self, $class);
    return $self;
}
## new(void) => 70HyphenFormat ##


################################## Protected ##################################


## @function close_infodb_write_handle(filehandle)
#
sub close_infodb_write_handle
{
    my $self = shift(@_);
    $self->debugPrintFunctionHeader(@_);
    my $handle = shift(@_);
    my $force_close = shift(@_); # Undefined most of the time
    my $continue_close = $self->removeConnectionIfPersistent($handle, $force_close);
    if ($continue_close) {
	close($handle);
    }
    return;
}
## close_infodb_write_handle(filehandle) => void ##


## @function delete_infodb_entry(filehandle, string)
#
sub delete_infodb_entry
{
    my $self = shift(@_);
    $self->debugPrintFunctionHeader(@_);
    my $infodb_handle = shift(@_);
    my $infodb_key = shift(@_);
    # A minus at the end of a key (after the ]) signifies 'delete'
    print $infodb_handle '[' . $infodb_key . ']-' . "\n";
    # The 70 minus signs are also needed, to help make the parsing by db2txt simple
    print $infodb_handle '-' x 70, "\n";
}
## delete_infodb_entry(filehandle, string) => void ##


## @function open_infodb_write_handle(string, string)
#
sub open_infodb_write_handle
{
    my $self = shift(@_);
    $self->debugPrintFunctionHeader(@_);
    my $path = shift(@_);
    my $append = shift(@_);
    my $infodb_file_handle = $self->retrieveConnectionIfPersistent($path, $append);;
    # No available existing connection
    if (!defined $infodb_file_handle || !$infodb_file_handle) {
	push(@_,$append) if defined $append;
        $infodb_file_handle = $self->openWriteHandle($path, @_);
	$self->registerConnectionIfPersistent($infodb_file_handle, $path, $append);
    }
    return $infodb_file_handle;
}
## open_infodb_write_handle(string, string) => filehandle ##


## @function openPipedHandle(integer, string, string, string*) => filehandle
#
sub openPipedHandle
{
    my $self = shift(@_);
    my $mode = shift(@_);
    my $executable_and_default_args = shift(@_);
    my $infodb_file_path = shift(@_);
    my ($executable, $default_args) = $executable_and_default_args =~ /^([a-z0-9]+)\s*(.*)$/;
    my $exe = &FileUtils::filenameConcatenate($self->{'executable_path'}, $executable . &util::get_os_exe());
    if (!-e $exe) {
	# Hope it's on path
	$exe = $executable . &util::get_os_exe();
    }
    my $infodb_file_handle = undef;
    my $cmd = '';
    if ($self->{'forced_affinity'} >= 0)
    {
        $cmd = 'taskset -c ' . $self->{'forced_affinity'} . ' ';
    }
    $cmd .= '"' . $exe . '" ' . $default_args;
    foreach my $open_arg (@_) {
	# Special - append is typically missing a hyphen
	if ($open_arg eq 'append') {
	    $open_arg = '-append';
	}
	$cmd .= ' ' . $open_arg;
    }
    $cmd .= ' "' . $infodb_file_path . '"';
    $self->debugPrint("CMD: '" . $cmd . "'\n");
    if(!open($infodb_file_handle, $mode . ':utf8', $cmd)) {
        print STDERR "Error: Failed to open pipe to '$cmd'\n";
        print STDERR "       $!\n";
        return undef;
    }
    #binmode($infodb_file_handle,":utf8");
    return $infodb_file_handle;
}
## openPipedHandle(integer, string, string, string*) => filehandle ##


## @function openReadHandle(string, string) => filehandle
#
sub openReadHandle
{
    my $self = shift(@_);
    return $self->openPipedHandle(RWMODE_READ, $self->{'read_executable'}, @_);
}
## openReadHandle(string, string) => filehandle


## @function openWriteHandle(*) => filehandle
#
sub openWriteHandle
{
    my $self = shift(@_);
    return $self->openPipedHandle(RWMODE_WRITE, $self->{'write_executable'}, @_);
}
## openWriteHandle(*) => filehandle ##


## @function read_infodb_entry(string, string) => hashmap
#
sub read_infodb_entry
{
    my $self = shift(@_);
    my $raw_string = $self->read_infodb_rawentry(@_);
    my $infodb_rec = $self->convert_infodb_string_to_hash($raw_string);
    return $infodb_rec;
}
## read_infodb_entry(string, string) => hashmap ##


## @function read_infodb_file(string, hashmap) => void
#
sub read_infodb_file
{
    my $self = shift(@_);
    my $infodb_file_path = shift(@_);
    my $infodb_map = shift(@_);
    $self->debugPrintFunctionHeader($infodb_file_path, $infodb_map);
    my $infodb_file_handle = $self->openReadHandle($infodb_file_path);
    my $infodb_line = "";
    my $infodb_key = "";
    my $infodb_value = "";
    while (defined ($infodb_line = <$infodb_file_handle>)) {
        $infodb_line =~ s/(\r\n)+$//; # more general than chomp
        if ($infodb_line =~ /^\[([^\]]+)\]$/) {
            $infodb_key = $1;
        }
        elsif ($infodb_line =~ /^-{70}$/) {
            $infodb_map->{$infodb_key} = $infodb_value;
            $infodb_key = "";
            $infodb_value = "";
        }
        else {
            $infodb_value .= $infodb_line;
        }
    }
  $self->close_infodb_write_handle($infodb_file_handle);
}
## read_infodb_file(string, hashmap) => void ##


## @function read_infodb_keys(string, hashmap) => void
#
sub read_infodb_keys
{
    my $self = shift(@_);
    my $infodb_file_path = shift(@_);
    my $infodb_map = shift(@_);
    my $infodb_file_handle = $self->openPipedHandle(RWMODE_READ, $self->{'keyread_executable'}, $infodb_file_path);
    if (!$infodb_file_handle) {
	die("Couldn't open pipe from gdbmkeys: " . $infodb_file_path . "\n");
    }
    my $infodb_line = "";
    my $infodb_key = "";
    my $infodb_value = "";
    # Simple case - dedicated keyread exe, so keys are strings
    if ($self->{'keyread_executable'} ne $self->{'read_executable'}) {
	while (defined ($infodb_line = <$infodb_file_handle>)) {
	    $infodb_line =~ s/[\r\n]+$//;
	    $infodb_map->{$infodb_line} = 1;
	}
    }
    # Slightly more difficult - have to parse keys out of 70hyphen format
    else {
	while (defined ($infodb_line = <$infodb_file_handle>)) {
	    if ($infodb_line =~ /^\[([^\]]+)\](-)?[\r\n]*$/) {
		my $key = $1;
		my $delete_flag = $2;
		if (defined $delete_flag) {
		    delete $infodb_map->{$key}
		}
		else {
		    $infodb_map->{$key} = 1;
		}
	    }
	}
    }
    $self->close_infodb_write_handle($infodb_file_handle);
}
## read_infodb_keys(string, hashmap) => void ##


## @function read_infodb_rawentry(string, string) => string
#
# !! TEMPORARY: Slow and naive implementation that just reads the entire file
# and picks out the one value. This should one day be replaced with database-
# specific versions that will use dbget etc.
#
sub read_infodb_rawentry
{
    my $self = shift(@_);
    my $infodb_file_path = shift(@_);
    my $infodb_key = shift(@_);
    # temporary hashmap... we're only interested in one entry
    my $infodb_map = {};
    $self->read_infodb_file($infodb_file_path, $infodb_map);
    return $infodb_map->{$infodb_key};
}
## read_infodb_rawentry(string, string) => string ##


## @function set_infodb_entry(string, string, hashmap)
#
sub set_infodb_entry
{
    my $self = shift(@_);
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
    my $serialized_infodb_map = $self->convert_infodb_hash_to_string($infodb_map);

    # Store it into DB using '... -append' which despite its name actually
    # replaces the record if it already exists
    my $status = undef;
    my $infodb_file_handle = $self->openWriteHandle($infodb_file_path, '-append');
    if (!$infodb_file_handle) {
	print STDERR "Error: set_infodb_entry() failed to open pipe to: " . $infodb_file_handle ."\n";
	print STDERR "       $!\n";
	$status = -1;
    }
    else {
	print $infodb_file_handle "[$infodb_key]\n";
	print $infodb_file_handle "$serialized_infodb_map\n";
	$self->close_infodb_write_handle($infodb_file_handle);
	$status = 0; # as in exit status of cmd OK
    }
    return $status;
}
## set_infodb_entry(string, string, hashmap) => integer ##


## @function write_infodb_entry(filehandle, string, hashmap)
#
sub write_infodb_entry
{
    my $self = shift(@_);
    my $infodb_handle = shift(@_);
    my $infodb_key = shift(@_);
    my $infodb_map = shift(@_);

    print $infodb_handle "[$infodb_key]\n";
    foreach my $infodb_value_key (sort keys(%$infodb_map)) {
        foreach my $infodb_value (@{$infodb_map->{$infodb_value_key}}) {
            if ($infodb_value =~ /-{70,}/) {
                # if value contains 70 or more hyphens in a row we need to escape them
                # to prevent txt2db from treating them as a separator
                $infodb_value =~ s/-/&\#045;/gi;
            }
            print $infodb_handle "<$infodb_value_key>" . $infodb_value . "\n";
        }
    }
    print $infodb_handle '-' x 70, "\n";
}
## write_infodb_entry(filehandle, string, hashmap) => void ##


## @function write_infodb_rawentry(filehandle, string, string)
#
sub write_infodb_rawentry
{
    my $self = shift(@_);
    my $infodb_handle = shift(@_);
    my $infodb_key = shift(@_);
    my $infodb_val = shift(@_);

    print $infodb_handle "[$infodb_key]\n";
    print $infodb_handle "$infodb_val\n";
    print $infodb_handle '-' x 70, "\n";
}
## write_infodb_rawentry(filehandle, string, string) ##


1;
