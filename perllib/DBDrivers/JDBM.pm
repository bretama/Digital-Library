###############################################################################
#
# DBDrivers/JDBM.pm -- utility functions for writing to jdbm databases
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

package DBDrivers::JDBM;

# Pragma
use strict;

# Libraries
use util;
use FileUtils;
use DBDrivers::70HyphenFormat;

sub BEGIN
{
    if (!defined $ENV{'GSDLHOME'} || !defined $ENV{'GSDLOS'}) {
        die("Error! Environment must be prepared by sourcing setup.bash\n");
    }
    @DBDrivers::JDBM::ISA = ('DBDrivers::70HyphenFormat');
}


## @function constructor
#
sub new
{
    my $class = shift(@_);
    my $self = DBDrivers::70HyphenFormat->new(@_);
    $self->{'default_file_extension'} = 'jdb';
    $self->{'supports_concurrent_read_and_write'} = 1;

    # Executables need a little extra work since we are using Java
    # - we need to build up the classpath continue the Jar libraries to use
    my $jdbmwrap_jar = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, 'bin', 'java', 'JDBMWrapper.jar');
    my $jdbm_jar = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, 'lib', 'java', 'jdbm.jar');
    my $classpath = &util::pathname_cat($jdbmwrap_jar,$jdbm_jar);
    # Massage paths for Cygwin. Away to run a java program, using a binary that
    # is native to Windows, so need Windows directory and path separators
    # Note: this is done after the util::pathname_cat as that fuction can also
    # (incorrectly) change file separators.
    if ($^O eq "cygwin") {
	$classpath = `cygpath -wp "$classpath"`;
	chomp($classpath);
	$classpath =~ s%\\%\\\\%g;
    }
    $self->{'executable_path'} = '';
    $self->{'read_executable'} = 'java -cp "' . $classpath . '" Jdb2Txt';
    $self->{'keyread_executable'} = 'java -cp "' . $classpath . '" JdbKeys';
    $self->{'write_executable'} = 'java -cp "' . $classpath . '" Txt2Jdb';
    # Support
    $self->{'supports_set'} = 1;

    bless($self, $class);
    return $self;
}
## constructor() ##


# jdb also creates .lg log files, that don't get removed on delete or move operations
# Make sure to rename them to when performing a rename operation on the main db file.
# dbutil::renameTo(src,dest) already took care of renaming the main db file.
sub rename_db_file_to {
    my $self = shift(@_);   

    $self->SUPER::rename_db_file_to(@_);
    my ($srcpath, $destpath) = @_;

    my ($srctailname, $srcdirname, $srcsuffix)
	= &File::Basename::fileparse($srcpath, "\\.[^\\.]+\$");
    my ($desttailname, $destdirname, $destsuffix)
	= &File::Basename::fileparse($destpath, "\\.[^\\.]+\$");
    
    # add in the lg extension
    my $src_log_file = &FileUtils::filenameConcatenate($srcdirname, $srctailname.".lg");
    my $dest_log_file = &FileUtils::filenameConcatenate($destdirname, $desttailname.".lg");
    
    # finally, move/rename any log file belonging to the src db file
    if(&FileUtils::fileExists($src_log_file)) {
	&FileUtils::moveFiles($src_log_file, $dest_log_file);
    }
    
    # don't want to keep the log file for any files renamed to bak (backup file) though
    if($destsuffix =~ m/bak$/) {
	my $assoc_log_file = &FileUtils::filenameConcatenate($destdirname, $desttailname.".lg");
	if(&FileUtils::fileExists($assoc_log_file)) {
	    &FileUtils::removeFiles($assoc_log_file);
	}
    }

}

sub remove_db_file {
    my $self = shift(@_);

    $self->SUPER::remove_db_file(@_);
    my ($db_filepath) = @_;

    # add in the lg extension to get the log file name
    my ($tailname, $dirname, $suffix) = &File::Basename::fileparse($db_filepath, "\\.[^\\.]+\$");
    my $assoc_log_file = &FileUtils::filenameConcatenate($dirname, $tailname.".lg");

    # remove any log file associated with the db file
    if(&FileUtils::fileExists($assoc_log_file)) {
	&FileUtils::removeFiles($assoc_log_file);
    }

}



# -----------------------------------------------------------------------------
#   JDBM IMPLEMENTATION
# -----------------------------------------------------------------------------

# When DBUtil::* is properly structured with inheritance, then
# much of this code (along with GDBM and GDBM-TXT-GZ) can be grouped into
# a shared base class.  Really it is only the the command that needs to
# be constructed that changes between much of the code that is used

# Handled by BaseDBDriver
# sub get_infodb_file_path {}

# Handled by 70HyphenFormat
# sub open_infodb_write_handle(string, string?) => filehandle
# sub close_infodb_write_handle(filehandle) => void
# sub read_infodb_file(string, hashmap) => void
# sub read_infodb_keys(string, hashmap) => void
# sub write_infodb_entry(filehandle, string, hashmap) => void
# sub write_infodb_rawentry(filehandle, string, string) => void
# sub set_infodb_entry(filehandle, string, string) => void
# sub delete_infodb_entry(filehandle, string) => void

1;
