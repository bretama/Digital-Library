###############################################################################
#
# BaseDBDriver.pm -- base class for all the database drivers
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

package DBDrivers::BaseDBDriver;

# Pragma
use strict;
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

# Libaries
use Time::HiRes qw( gettimeofday );
use gsprintf 'gsprintf';


## @function constructor
#
sub new
{
    my $class = shift(@_);
    my $debug = shift(@_);
    my $self = {};
    # Debug messages for this driver
    $self->{'debug'} = $debug; # 1 to enable
    # We'll use this in places other than 70HyphenFormat
    $self->{'70hyphen'} = '-' x 70;
    # Keep track of all opened file handles, but only for drivers that support
    # persistent connections
    $self->{'handle_pool'} = {};
    # Default file extension - in this case it is an error to create a DB from
    # BaseDBDriver
    $self->{'default_file_extension'} = 'err';
    # Support
    $self->{'supports_datestamp'} = 0;
    $self->{'supports_merge'} = 0;
    $self->{'supports_persistentconnection'} = 0;
    $self->{'supports_rss'} = 0;
    $self->{'supports_concurrent_read_and_write'} = 0;
    $self->{'supports_set'} = 0;
    $self->{'write_only'} = 0; # Some drivers are one way - i.e. STDOUTXML
    bless($self, $class);
    return $self;
}
## new(void) => BaseDBDriver ##


## @function DESTROY
#
# Built-in destructor block that, unlike END, gets passed a reference to self.
# Responsible for properly closing any open database handles.
#
sub DESTROY
{
    my $self = shift(@_);
    # Close all remaining filehandles
    foreach my $infodb_file_path (keys(%{$self->{'handle_pool'}})) {
	my $infodb_handle = $self->{'handle_pool'}->{$infodb_file_path};
	# By passing the filepath as the second argument we instruct the driver
	# that we actually want to close the connection by passing a non-zero
	# value, but we sneakily optimize things a little as the close method
	# can now check to see if it's been provided a file_path rather than
	# having to search the handle pool for it. The file_path is needed to
	# remove the closed handle from the pool anyway.
	$self->close_infodb_write_handle($infodb_handle, $infodb_file_path);
    }
}
## DESTROY(void) => void ##


###############################################################################
## Protected Functions
###############################################################################


## @function debugPrint(string) => void
#
sub debugPrint
{
    my $self = shift(@_);
    my $message = shift(@_);
    if ($self->{'debug'}) {
	my ($seconds, $microseconds) = gettimeofday();
	print STDERR '[DEBUG:' . $seconds . '.' . $microseconds . '] ' . (caller 1)[3] . '() ' . $message . "\n";
    }
}
## debugPrint(string) => void ##


## @function debugPrintFunctionHeader(*) => void
#
sub debugPrintFunctionHeader
{
    my $self = shift(@_);
    if ($self->{'debug'}) {
	my @arguments;
	foreach my $argument (@_) {
	    if ($argument !~ /^-?\d+(\.?\d+)?$/) {
		push(@arguments, '"' . $argument . '"');
	    }
	    else {
		push(@arguments, $argument);
	    }
	}
	my $message = '(' . join(', ', @arguments) . ')';
	# Would love to just call debugPrint() here, but then caller would be wrong
	my ($seconds, $microseconds) = gettimeofday();
	print STDERR '[DEBUG:' . $seconds . '.' . $microseconds . '] ' . (caller 1)[3] . $message . "\n";
    }
}
## debugPrintFunctionHeader(*) => void


## @function errorPrint(string, integer) => void
#
sub errorPrint
{
    my $self = shift(@_);
    my $message = shift(@_);
    my $is_fatal = shift(@_);
    print STDERR 'Error in ' . (caller 1)[3] . '! ' . $message . "\n";
    if ($is_fatal) {
	exit();
    }
}
## errorPrint(string, integer) => void ##


## @function registerConnectionIfPersistent(filehandle, string, string) => void
#
sub registerConnectionIfPersistent
{
    my $self = shift(@_);
    my $conn = shift(@_);
    my $path = shift(@_);
    my $append = shift(@_);
    if ($self->{'supports_persistentconnection'}) {
	$self->debugPrintFunctionHeader($conn, $path, $append);
	my $fhid = $path;
	if (defined $append && $append eq '-append') {
	    $fhid .= ' [APPEND]';
	}
	$self->debugPrint('Registering connection: "' . $fhid . '"');
	$self->{'handle_pool'}->{$fhid} = $conn;
    }
    return;
}
## registerConnectionIfPersistent(filehandle, string, string) => void ##


## @function removeConnectionIfPersistent(filehandle, string) => integer
#
sub removeConnectionIfPersistent
{
    my $self = shift(@_);
    my $handle = shift(@_);
    my $force_close = shift(@_);
    my $continue_close = 1;
    if ($self->{'supports_persistentconnection'}) {
	$self->debugPrintFunctionHeader($handle, $force_close);
	if (defined($force_close)) {
	    # We'll need the file path so we can locate and remove the entry
	    # in the handle pool (plus possibly the [APPEND] suffix for those
	    # connections in opened in append mode)
	    my $fhid = undef;
	    # Sometimes we can cheat, as the force_close variable will have the
	    # file_path in it thanks to the DESTROY block above. Doing a regex
	    # on force_close will treat it like a string no matter what it was,
	    # and we can search for the appropriate file extension that should
	    # be there for valid paths.
	    my $pattern = '\.' . $self->{'default_file_extension'} . '(\s\[APPEND\])?$';
	    if ($force_close =~ /$pattern/) {
		$fhid = $force_close;
	    }
	    # If we can't cheat then we are stuck finding which connection in
	    # the handle_pool we are about to close. Need to compare objects
	    # using refaddr()
	    else {
		foreach my $possible_fhid (keys %{$self->{'handle_pool'}}) {
		    my $possible_handle = $self->{'handle_pool'}->{$possible_fhid};
		    if (ref($handle) && ref($possible_handle) && refaddr($handle) == refaddr($possible_handle)) {
			$fhid = $possible_fhid;
			last;
		    }
		}
	    }
	    # If we found the fhid we can proceed to close the connection
	    if (defined($fhid)) {
		$self->debugPrint('Closing persistent connection: ' . $fhid);
		delete($self->{'handle_pool'}->{$fhid});
		$continue_close = 1;
	    }
	    else {
		print STDERR "Warning! About to close persistent database handle, but couldn't locate in open handle pool.\n";
	    }
	}
	# Persistent connection don't close *unless* force close is set
	else {
	    $continue_close = 0;
	}
    }
    return $continue_close;
}
## removeConnectionIfPersistent(filehandle, string) => integer ##


##
#
sub retrieveConnectionIfPersistent
{
    my $self = shift(@_);
    my $path = shift(@_);
    my $append = shift(@_); # -append support
    my $conn; # This should be populated
    if ($self->{'supports_persistentconnection'}) {
	$self->debugPrintFunctionHeader($path, $append);
	my $fhid = $path;
	# special case: if the append mode has changed for a persistent
	# connection, we need to close the old connection first or things
	# will get wiggy.
	if (defined $append && $append eq '-append') {
	    # see if there is a non-append mode connection already open
	    if (defined $self->{'handle_pool'}->{$path}) {
		$self->debugPrint("Append mode added - closing existing non-append mode connection");
		my $old_conn = $self->{'handle_pool'}->{$path};
		$self->close_infodb_write_handle($old_conn, $path);
	    }
	    # Append -append so we know what happened.
	    $fhid .= ' [APPEND]';
	}
	else {
	    my $fhid_append = $path . ' [APPEND]';
	    if (defined $self->{'handle_pool'}->{$fhid_append}) {
		$self->debugPrint("Append mode removed - closing existing append mode connection");
		my $old_conn = $self->{'handle_pool'}->{$fhid_append};
		$self->close_infodb_write_handle($old_conn, $fhid_append);
	    }
	}
	if (defined $self->{'handle_pool'}->{$fhid}) {
	    $self->debugPrint('Retrieving existing connection: ' . $fhid);
	    $conn = $self->{'handle_pool'}->{$fhid};
	}
    }
    return $conn;
}
## ##







###############################################################################
## Public Functions
###############################################################################


## @function convert_infodb_hash_to_string(hashmap) => string
#
sub convert_infodb_hash_to_string
{
    my $self = shift(@_);
    my $infodb_map = shift(@_);
    my $infodb_entry_value = "";
    foreach my $infodb_value_key (keys(%$infodb_map)) {
        foreach my $infodb_value (@{$infodb_map->{$infodb_value_key}}) {
            $infodb_entry_value .= "<$infodb_value_key>" . $infodb_value . "\n";
        }
    }
    return $infodb_entry_value;
}
## convert_infodb_hash_to_string(hashmap) => string ##


## @function convert_infodb_string_to_hash(string) => hashmap
#
sub convert_infodb_string_to_hash
{
    my $self = shift(@_);
    my $infodb_entry_value = shift(@_);
    my $infodb_map = ();

    if (!defined $infodb_entry_value) {
	print STDERR "Warning: No value to convert into a infodb hashtable\n";
    }
    else {
        while ($infodb_entry_value =~ /^<(.*?)>(.*)$/mg) {
            my $infodb_value_key = $1;
            my $infodb_value = $2;

            if (!defined($infodb_map->{$infodb_value_key})) {
                $infodb_map->{$infodb_value_key} = [ $infodb_value ];
            }
            else {
                push(@{$infodb_map->{$infodb_value_key}}, $infodb_value);
            }
	}
    }

    return $infodb_map;
}
## convert_infodb_string_to_hash(string) => hashmap ##


## @function get_infodb_file_path(string, string) => string
#
sub get_infodb_file_path
{
    my $self = shift(@_);
    my $collection_name = shift(@_);
    my $infodb_directory_path = shift(@_);
    my $infodb_file_name = &util::get_dirsep_tail($collection_name) . '.' . $self->{'default_file_extension'};
    my $infodb_file_path = &FileUtils::filenameConcatenate($infodb_directory_path, $infodb_file_name);
    # Correct the path separators to work in Cygwin
    if ($^O eq "cygwin") {
	$infodb_file_path = `cygpath -w "$infodb_file_path"`;
	chomp($infodb_file_path);
	$infodb_file_path =~ s%\\%\\\\%g;
    }
    return $infodb_file_path;
}
## get_infodb_file_path(string, string) => string ##


## @function rename_db_file_to(string, string) => void
#
sub rename_db_file_to {
    my $self = shift(@_);
    my ($srcpath, $destpath) = @_;

    # rename basic db file
    &FileUtils::moveFiles($srcpath, $destpath);

    # subclass should rename any additional files that the specific dbtype creates
}
## rename_db_file_to(string, string) => void ##

## @function remove_db_file(string) => void
#
sub remove_db_file {
    my $self = shift(@_);
    my ($db_filepath) = @_;
    
    # remove basic db file
    &FileUtils::removeFiles($db_filepath);

    # subclass must rename any additional files that the specific dbtype creates (e.g. transaction log files)
}
## remove_db_file(string, string) => void ##


## @function supportsDatestamp(void) => integer
#
sub supportsDatestamp
{
    my $self = shift(@_);
    return $self->{'supports_datestamp'};
}
## supportsDatestamp(void) => integer ##


## @function supportsMerge(void) => boolean
#
sub supportsMerge
{
    my $self = shift(@_);
    return $self->{'supports_merge'};
}
## supportsMerge(void) => integer ##


## @function supportsPersistentConnection(void) => integer
#
sub supportsPersistentConnection
{
    my $self = shift(@_);
    return $self->{'supports_persistentconnection'};
}
## supportsPersistentConnection(void) => integer ##


## @function supportsRSS(void) => integer
#
sub supportsRSS
{
    my $self = shift(@_);
    return $self->{'supports_rss'};
}
## supportsRSS(void) => integer ##


## @function supportsConcurrentReadAndWrite(void)  => integer
#
sub supportsConcurrentReadAndWrite 
{
    my $self = shift(@_);
    return $self->{'supports_concurrent_read_and_write'};
}
## supportsConcurrentReadAndWrite(void) => integer ##


## @function supportsSet(void) => integer
#
#  Not all drivers support the notion of set
#
sub supportsSet
{
    my $self = shift(@_);
    return $self->{'supports_set'};
}
## supportsSet(void) => integer ##


sub writeOnly
{
    my $self = shift(@_);
    return $self->{'write_only'};
}
## writeOnly() ##

###############################################################################
## Virtual Functions
###############################################################################


## @function close_infodb_write_handle(*) => void
#
sub close_infodb_write_handle
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## close_infodb_write_handle(*) => void ##


## @function delete_infodb_entry(*) => void
#
sub delete_infodb_entry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## delete_infodb_entry(*) => void ##


## @function mergeDatabases(*) => void
#
sub mergeDatabases
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## mergeDatabases(*) => void ##


## @function open_infodb_write_handle(*) => void
#
sub open_infodb_write_handle
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## open_infodb_write_handle(*) => void ##


## @function set_infodb_entry(*) => void
#
sub set_infodb_entry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## set_infodb_entry(*) => void ##


## @function read_infodb_entry(*) => void
#
sub read_infodb_entry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## read_infodb_entry(*) => void ##


## @function read_infodb_rawentry(*) => string
#
sub read_infodb_rawentry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## read_infodb_rawentry(*) => string ##


## @function read_infodb_file(*) => void
#
sub read_infodb_file
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## read_infodb_file(*) => void ##


## @function read_infodb_keys(*) => void
#
sub read_infodb_keys
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## read_infodb_keys(*) => void ##


## @function write_infodb_entry(*) => void
#
sub write_infodb_entry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## write_infodb_entry(*) => void ##


## @function write_infodb_rawentry(*) => void
#
sub write_infodb_rawentry
{
    my $self = shift(@_);
    gsprintf(STDERR, (caller(0))[3] . " {common.must_be_implemented}\n");
    die("\n");
}
## write_infodb_rawentry(*) => void ##


1;
