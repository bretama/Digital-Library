###########################################################################
#
# MetadataRead - like a Java interface that defines that a subclass is
# a Plugin that extracts Metadata
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2008 New Zealand Digital Library Project
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

package MetadataRead;

use PrintInfo;
use strict;

# MetadataRead is an abstract superclass that does not inherit from anything else.
# It exists solely to define the can_process_this_file_for_metadata() method in
# such a way that those MetadataPlugins that inherit from MetadataRead don't need 
# to define this method and will always process the files associated with them for 
# metadata and other plugins in the pipeline won't be passed these files anymore.

# MetadataRead defines method can_process_this_file_for_metadata() with identical
# signature to BaseImporter. (MetadataRead doesn't inherit from BaseImporter, so it's
# not 'overriding' it.) Subclasses of MetadataRead that want to use this method 
# definition can override their inherited BaseImporter version of the method by 
# listing MetadataRead as the *first* superclass they inherit from in the ISA list.
# This is the way Perl resolves conflicting method definitions.

my $arguments = [];

my $options = { 'name'     => "MetadataRead",
		'desc'     => "{MetadataRead.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$auxiliary) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

	# Like PrintInfo, MetadataRead has no superclass,
	# so $self is intialised to an empty array.
	my $self = {};
    return bless $self, $class;

}

# MetadataPlugins that inherit from MetadataRead will by default
# process all the metadata in files whose extensions match. 
# Override this method in a subclass to return undef if other 
# files should also be allowed to process the metadata therafter.
sub can_process_this_file_for_metadata {
    my $self = shift(@_);

#	print STDERR "********* MetadataRead::can_process_this_file_for_metadata() called.\n";
	
    return $self->can_process_this_file(@_);
}


1;
