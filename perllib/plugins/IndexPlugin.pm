###########################################################################
#
# IndexPlugin.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
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

# This recursive plugin processes an index.txt file. 
# The index.txt file should contain the list of files to be
# included in the collection followed by any extra metadata to
# be associated with each file.

# The index.txt file should be formatted as follows:
# The first line may be a key (beginning with key:)
# to name the metadata fields
# (e.g. key: Subject Organization Date) 
# The following lines will contain a filename followed 
# by the value that metadata entry is to be set to.
# (e.g. 'irma/iw097e 3.2 unesco 1993' will associate the
# metadata Subject=3.2, Organization=unesco, and Date=1993
# with the file irma/iw097e if the above key line was used)

# Note that if any of the metadata fields use the Hierarchy
# classifier plugin then the value they're set to should
# correspond to the first field (the descriptor) in the
# appropriate classification file.

# Metadata values may be named separately using a tag 
# (e.g. <Subject>3.2) and this will override any name 
# given to them by the key line.
# If there's no key line any unnamed metadata value will be
# named 'Subject'.

package IndexPlugin;

use plugin;
use BaseImporter;
use doc;
use util;
use cfgread;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @IndexPlugin::ISA = ('BaseImporter');
}

#my $arguments = [
#		 ];

my $options = { 'name'     => "IndexPlugin",
		'desc'     => "{IndexPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes" };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    #push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

# return 1 if this class might recurse using $pluginfo
sub is_recursive {
    my $self = shift (@_);
    
    return 1;
}

# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $indexfile = &util::filename_cat($base_dir, $file, "index.txt");
    if (!-f $indexfile) {
	# not a directory containing an index file
	return undef;
    }

    # found an index.txt file
    print STDERR "<Processing n='$file' p='IndexPlugin'>\n" if ($gli);
    print $outhandle "IndexPlugin: processing $indexfile\n";

    # read in the index.txt
    my $list = &cfgread::read_cfg_file ($indexfile, undef, '^[^#]\w');
    my @fields = ();
    # see if there's a 'key:' line
    if (defined $list->{'key:'}) {
	@fields = @{$list->{'key:'}};
    }

    my $index_base_dir = &util::filename_cat($base_dir, $file);

    # process each document
    my $count = 0;
    foreach my $docfile (keys (%$list)) {
	last if ($maxdocs != -1 && ($total_count + $count) >= $maxdocs);
	$metadata = {}; # at present we can do this as metadata
	                # will always be empty when it arrives
	                # at this plugin - this might cause 
	                # problems if things change though

	# note that $list->{$docfile} is an array reference
	if ($docfile !~ /key:/i) {
	    my $i = 0;
	    for ($i = 0; $i < scalar (@{$list->{$docfile}}); $i ++) {
		if ($list->{$docfile}->[$i] =~ /^<([^>]+)>(.+)$/) {
		    unless (defined ($metadata->{$1})) {
			$metadata->{$1} = [];
		    } 
		    push (@{$metadata->{$1}}, $2);
		} elsif (scalar @fields >= $i) {
		    unless (defined ($metadata->{$fields[$i]})) {
			$metadata->{$fields[$i]} = [];
		    } 
		    push (@{$metadata->{$fields[$i]}}, $list->{$docfile}->[$i]);
		} else {
		    $metadata->{'Subject'} = $list->{$docfile};
		}
	    }
	    $count += &plugin::read ($pluginfo, $index_base_dir, $docfile, $block_hash, $metadata, $processor, $maxdocs, ($total_count +$count), $gli);
	}
    }

    return $count; # was processed
}


1;
