###############################################################################
#
# dbutil.pm -- functions to handle using dbdrivers
#
# Copyright (c) 2015 New Zealand Digital Library Project
#
# A component of the Greenstone digital library software from the New Zealand
# Digital Library Project at the University of Waikato, New Zealand.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 675 Mass
# Ave, Cambridge, MA 02139, USA.
#
###############################################################################

package dbutil;

# Pragma
use strict;

# DEBUGGING: You can enable a DBDriver one at a time to ensure they don't have
# compilation errors.
BEGIN
{
    if (!defined $ENV{'GSDLHOME'} || !defined $ENV{'GSDLOS'}) {
        die("Error! Environment not prepared. Have you sourced setup.bash?\n");
    }
    # Are we running standalone? In which case the INC won't be correct
    # - derp. Linux only sorry
    if ($^O !~ /cygwin|MSWin32/) {
	my $perllib_path = $ENV{'GSDLHOME'} . '/perllib';
	my $all_inc = join(':', @INC);
	if ($all_inc !~ /$perllib_path/) {
	    unshift(@INC, $perllib_path);
	    unshift(@INC, $ENV{'GSDLHOME'} . '/ext/parallel-building/perllib');
	    unshift(@INC, $ENV{'GSDLHOME'} . '/ext/tdb/perllib');
	}
    }
    ## You can uncomment and name a Driver here to test it compiles
    #require DBDrivers::TDBCLUSTER;
    #my $driver = DBDrivers::TDBCLUSTER->new(1);
}

# Libraries
use Devel::Peek;
use Time::HiRes qw ( gettimeofday tv_interval );
use FileUtils;
use gsprintf 'gsprintf';
use util;

# Modulino pattern
__PACKAGE__->main unless caller;

###############################################################################
## Private
###############################################################################

## Display debug messages?
my $debug = 0; # Set to 1 to display

## Keep track of the driver objects we have initialised
my $dbdriver_pool = {};

# Testing globals
my $test_count = 0;
my $pass_count = 0;
my $skip_count = 0;


## @function _addPathsToINC(void) => void
#
# A hopefully unused function to ensure the INC path contains all the available
# perllib directories (from main, collection, and extensions)
#
sub _addPathsToINC
{
    &_debugPrint('_addPathsToINC() => ', 0);
    my @possible_paths;
    #... the main perllib directory...
    push(@possible_paths, &FileUtils::filenameConcatenate());
    #... a collection specific perllib directory...
    if (defined $ENV{'GSDLCOLLECTDIR'} && $ENV{'GSDLCOLLECTION'}) {
	push(@possible_paths, &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'collect', $ENV{'GSDLCOLLECTION'}, 'perllib'));
    }
    #... any registered extension may also have a perllib!
    if (defined $ENV{'GSDLEXTS'} && defined $ENV{'GSDLHOME'}) {
	foreach my $gs2_extension (split(/:/, $ENV{'GSDLEXTS'})) {
	    push(@possible_paths, &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, 'ext', $gs2_extension, 'perllib'));
	}
    }
    if (defined $ENV{'GSDL3EXTS'} && defined $ENV{'GSDL3SRCHOME'}) {
	foreach my $gs3_extension (split(/:/, $ENV{'GSDL3EXTS'})) {
	    push(@possible_paths, &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, 'ext', $gs3_extension, 'perllib'));
	}
    }
    my $path_counter = 0;
    foreach my $possible_path (@possible_paths) {
	# we only try adding paths that actually exist
	if (-d $possible_path) {
	    my $did_add_path = &util::augmentINC($possible_path);
	    if ($did_add_path) {
		$path_counter++;
	    }
	}
    }
    &_debugPrint('Added ' . $path_counter . ' paths');
}
## _addPathsToINC(void) => void #


## @function _debugPrint(string, boolean)
#
sub _debugPrint
{
    my ($message, $newline) = @_;
    if ($debug) {
        if (!defined($newline)) {
            $newline = 1;
        }
        print STDERR '[DEBUG] dbutil::' . $message;
        if ($newline) {
            print STDERR "\n";
        }
    }
}
## _debugPrint(string, boolean) => void ##


## @function _isDriverLoaded(string) => boolean
#
sub _isDriverLoaded
{
    my ($dbdriver_name) = @_;
    (my $dbdriver_file = $dbdriver_name) =~ s/::/\//g;
    $dbdriver_file .= '.pm';
    my $result = defined($INC{$dbdriver_file});
    &_debugPrint('_isDriverLoaded("' . $dbdriver_name . '") => ' . $result);
    return $result;
}
## _isDriverLoaded(string) => boolean ##

## @function _loadDBDriver(string, string)
#
sub _loadDBDriver
{
    my ($dbdriver_name, $db_filepath) = @_;
    my $dbdriver;
    # I've decided (arbitrarily) to use uppercase for driver names since they
    # are mostly acronyms
    $dbdriver_name = uc($dbdriver_name);
    # Ensure the driver has the correct package prefix
    if ($dbdriver_name !~ /^DBDrivers/) {
        $dbdriver_name = 'DBDrivers::' . $dbdriver_name;
    }
    # We only need to create each driver once
    if (defined($dbdriver_pool->{$dbdriver_name})) {
        $dbdriver = $dbdriver_pool->{$dbdriver_name};
    }
    else {
        &_debugPrint('_loadDBDriver() => ' . $dbdriver_name);
        # Assuming the INC is correctly setup, then this should work nicely
        # - make sure we have required this dbdriver package
	eval "require $dbdriver_name";
	if (&_isDriverLoaded($dbdriver_name)) {
	    $dbdriver_name->import();
        }
	# What should we do about drivers that aren't there?
	else {
	    print STDERR "Error! Failed to load: " . $dbdriver_name . "\n";
	}
        # Then initialise and return a new one
        $dbdriver = $dbdriver_name->new($debug);
        # Store it for later use
        $dbdriver_pool->{$dbdriver_name} = $dbdriver;
    }
    return $dbdriver;
}
## _loadDBDriver(string, string) => BaseDBDriver ##


## @function _printTest(string, integer) => void
#
sub _printTest
{
    my $title = shift(@_);
    my $result = shift(@_);
    $test_count++;
    print " - Test: " . $title . "... ";
    if ($result) {
	print "Passed\n";
	$pass_count++;
    }
    else {
	print "Failed\n";
    }
}
## _printTest(string, integer) => void ##


sub _compareHash
{
    my $hash1 = shift(@_);
    my $hash2 = shift(@_);
    my $str1 = &_hash2str($hash1);
    my $str2 = &_hash2str($hash2);
    return ($str1 eq $str2);
}

sub _hash2str
{
    my $hash = shift(@_);
    my $str = '';
    foreach my $key (sort keys %{$hash}) {
	$str .= '{' . $key . '=>{{' . join('},{', @{$hash->{$key}}) . '}}}';
    }
    return $str;
}


###############################################################################
## Public
###############################################################################


## @function main(void) => void
#
sub main
{
    my $t0 = [gettimeofday()];
    my $data1 = {'doh' => ['a deer, a female deer'],
		'ray' => ['a drop of golden sun'],
		'me'  => ['a name I call myself'],
		'far' => ['a long, long way to run']};
    my $data2 = {'sew' => ['a needle pulling thread'],
		 'lah' => ['a note to follow doh'],
		 'tea' => ['a drink with jam and bread'],
		 'doh' => ['which brings us back to']};
    $test_count = 0;
    $pass_count = 0;
    $skip_count = 0;
    print "===== DBUtils Testing Suite =====\n";
    print "For each driver specified, run a battery of tests\n";
    my @drivers;
    foreach my $arg (@ARGV) {
	if ($arg =~ /^-+([a-z]+)(=.+)?$/) {
	    my $arg_name = $1;
	    my $arg_value = $2;
	    if ($arg_name eq 'debug') {
		$debug = 1;
	    }
	}
	else {
	    push(@drivers, $arg);
	}
    }
    if (scalar(@drivers)) {
	# Ensure the Perl can load the drivers from all the typical places
	&_addPathsToINC();
	foreach my $driver_name (@drivers) {
	    my $t1 = [gettimeofday()];
	    print "=== Testing: " . $driver_name . " ===\n";
	    my $driver = _loadDBDriver($driver_name);
	    my $db_path = $driver->get_infodb_file_path('test-doc','/tmp/');
	    print " - Path: " . $db_path . "\n";
	    # 1. Open handle
	    my $db_handle = $driver->open_infodb_write_handle($db_path);
	    &_printTest('opening handle', (defined $db_handle));
	    # 2a. Write entry
	    $driver->write_infodb_entry($db_handle, 'Alpha', $data1);
	    &_printTest('writing entry', 1);
	    # 2b. Write raw entry
	    my $raw_data = $driver->convert_infodb_hash_to_string($data1);
	    $driver->write_infodb_rawentry($db_handle, 'Beta', $raw_data);
	    &_printTest('writing raw entry', 1);
	    # 3. Close handle
	    $driver->close_infodb_write_handle($db_handle);
	    if ($driver->supportsPersistentConnection()) {
		$test_count += 1;
		$skip_count += 1;
		print " - Skipping test as persistent drivers delay 'close'.\n";
	    }
	    else {
		&_printTest('closing handle', (tell($db_handle) < 1));
	    }
	    if (!$driver->writeOnly()) {
		# 4a. Read entry
		my $data3 = $driver->read_infodb_entry($db_path, 'Alpha');
		&_printTest('read entry', &_compareHash($data1, $data3));
		# 4b. Read raw entry
		my $raw_data4 = $driver->read_infodb_rawentry($db_path, 'Beta');
		my $data4 = $driver->convert_infodb_string_to_hash($raw_data4);
		&_printTest('read raw entry', &_compareHash($data1, $data4));
		# 5. Read keys
		my $keys1 = {};
		$driver->read_infodb_keys($db_path, $keys1);
		&_printTest('read keys', (defined $keys1->{'Alpha'} && defined $keys1->{'Beta'}));
		# 6. Set entry
		if ($driver->supportsSet()) {
		    my $status = $driver->set_infodb_entry($db_path, 'Alpha', $data2);
		    &_printTest('set entry (1)', ($status >= 0));
		    my $data5 = $driver->read_infodb_entry($db_path, 'Alpha');
		    &_printTest('set entry (2)', &_compareHash($data2, $data5));
		}
		else {
		    $test_count += 2;
		    $skip_count += 2;
		    print " - Skipping 2 tests as 'set' is not supported by this driver.\n";
		}
		# 7. Delete entry
		my $db_handle2 = $driver->open_infodb_write_handle($db_path, 'append');
		$driver->delete_infodb_entry($db_handle2, 'Alpha');
		$driver->close_infodb_write_handle($db_handle2);
		my $keys2 = {};
		$driver->read_infodb_keys($db_path, $keys2);
		&_printTest('delete entry', ((!defined $keys2->{'Alpha'}) && (defined $keys2->{'Beta'})));
	    }
	    else
	    {
		$test_count += 6;
		$skip_count += 6;
		print " - Skipping 6 tests as driver is write-only.\n";
	    }
	    # 8. Remove test db
	    unlink($db_path);
	    my $t2 = [gettimeofday()];
	    my $elapsed1 = tv_interval($t1, $t2);
	    print " - Testing took " . $elapsed1 . " seconds\n";
	}
	print "===== Results =====\n";
	print "Drivers Tested: " . scalar(@drivers) . "\n";
	print "Tests Run:      " . $test_count . "\n";
	print "Tests Passed:   " . $pass_count . "\n";
	print "Tests Failed:   " . ($test_count - $pass_count - $skip_count) . "\n";
	print "Tests Skipped:  " . $skip_count . "\n";
    }
    else
    {
	print "Warning! No drivers specified - expected as arguments to call\n";
    }
    my $t3 = [gettimeofday()];
    my $elapsed2 = tv_interval($t0, $t3);
    print "===== Complete in " . $elapsed2 . " seconds =====\n";
    print "\n";
    exit(0);
}
## main(void) => void


## @function close_infodb_write_handle(string, *) => void
#
sub close_infodb_write_handle
{
  my $infodb_type = shift(@_);
  my $driver = _loadDBDriver($infodb_type);
  $driver->close_infodb_write_handle(@_);
}
## close_infodb_write_handle(string, *) => void ##


## @function delete_infodb_entry(string, *) => void
#
sub delete_infodb_entry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->delete_infodb_entry(@_);
}
## delete_infodb_entry(string, *) => void ##


## @function mergeDatabases(string, *) => integer
#
sub mergeDatabases
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $status = $driver->mergeDatabases(@_);
    return $status;
}
## mergeDatabases(string, *) => integer ##


## @function get_default_infodb_type(void) => string
#
sub get_default_infodb_type
{
  # The default is GDBM so everything works the same for existing collections
  # To use something else, specify the "infodbtype" in the collection's collect.cfg file
  return 'gdbm';
}
## get_default_infodb_type(void) => string ##


## @function get_infodb_file_path(string, *) => string
#
sub get_infodb_file_path
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $infodb_file_path = $driver->get_infodb_file_path(@_);
    return $infodb_file_path;
}
## get_infodb_file_path(string, *) => string ##


## @function convert_infodb_string_to_hash(string,hashmap) => string
#
sub convert_infodb_string_to_hash
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $infodb_handle = $driver->convert_infodb_string_to_hash(@_);
    return $infodb_handle;
}
## open_infodb_write_handle(string,hashmap) => string ##


## @function open_infodb_write_handle(string, *) => filehandle
#
sub open_infodb_write_handle
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $infodb_handle = $driver->open_infodb_write_handle(@_);
    return $infodb_handle;
}
## open_infodb_write_handle(string, *) => filehandle ##


## @function read_infodb_file(string, *) => void
#
sub read_infodb_file
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->read_infodb_file(@_);
}
## read_infodb_file(string, *) => void ##


## @function read_infodb_keys(string, *) => void
#
sub read_infodb_keys
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->read_infodb_keys(@_);
}
## read_infodb_keys(string, *) => void ##


## @function read_infodb_entry(string, *) => hashmap
#
sub read_infodb_entry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $infodb_entry = $driver->read_infodb_entry(@_);
    return $infodb_entry;
}
## read_infodb_entry(string, *) => hashmap ##


## @function read_infodb_rawentry(string, *) => string
#
sub read_infodb_rawentry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $raw_infodb_entry = $driver->read_infodb_rawentry(@_);
    return $raw_infodb_entry;
}
## read_infodb_rawentry(string, *) => string ##


## @function set_infodb_entry(string, *) => integer
#
sub set_infodb_entry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $status = $driver->set_infodb_entry(@_);
    return $status;
}
## set_infodb_entry(string, *) => integer ##


## @function supportDatestamp(string) => boolean
#
sub supportsDatestamp
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $supports_datestamp = $driver->supportsDatestamp();
    return $supports_datestamp;
}
## supportsDatestamp(string) => boolean ##


## @function supportMerge(string) => boolean
#
sub supportsMerge
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $supports_merge = $driver->supportsMerge();
    return $supports_merge;
}
## supportsMerge(string) => boolean ##


## @function supportRSS(string) => boolean
#
sub supportsRSS
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    my $supports_rss = $driver->supportsRSS();
    return $supports_rss;
}
## supportsRSS(string) => boolean ##


## @function supportsConcurrentReadAndWrite(string)  => boolean
#
sub supportsConcurrentReadAndWrite
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    return $driver->supportsConcurrentReadAndWrite();
}
## supportsConcurrentReadAndWrite(string) => boolean ##


## @function write_infodb_entry(string, *) => void
#
sub write_infodb_entry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->write_infodb_entry(@_);
}
## write_infodb_entry(string, *) => void ##


## @function write_infodb_rawentry(string, *) => void
#
sub write_infodb_rawentry
{
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->write_infodb_rawentry(@_);
}
## write_infodb_rawentry(string, *) => void ##

## @function rename_db_file_to(string, string) => void
#
sub rename_db_file_to {
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->rename_db_file_to(@_);    
}
## rename_db_file_to(string, string) => void ##

## @function remove_db_file(string) => void
#
sub remove_db_file {
    my $infodb_type = shift(@_);
    my $driver = _loadDBDriver($infodb_type);
    $driver->remove_db_file(@_);    
}
## remove_db_file(string, string) => void ##

1;
