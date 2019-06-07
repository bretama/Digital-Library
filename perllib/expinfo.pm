###########################################################################
#
# expinfo.pm --
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

# modified by: Chi-Yu Huang
# This module stores information about the export directory. At the moment
# this information just consists of the file name (relative to the
# directory the export information file is in) and its OID.

# This module assumes there is a one to one correspondance between
# a file in the export directory and an OID.

package expinfo;


use strict;


sub new {
    my ($class) = @_;
    my $self = {'info'=>{},
		'order'=>[]};

    return bless $self, $class;
}

sub load_info {
    my $self = shift (@_);
    my ($filename) = @_;

    $self->{'info'} = {};
 
    if (-e $filename) {
	open (INFILE, $filename) || 
	    die "expinfo::load_info couldn't read $filename\n";

	my ($line, @line);
	while (defined ($line = <INFILE>)) {
	    $line =~ s/\cM|\cJ//g; # remove end-of-line characters
	    @line = split ("\t", $line); # filename, 
	    if (scalar(@line) >= 2) {
		$self->add_info (@line);
	    }
	}
	close (INFILE);
    }
}

sub save_info {
    my $self = shift (@_);
    my ($filename) = @_;

    my ($OID, $info);

    open (OUTFILE, ">$filename") || 
	die "expinfo::save_info couldn't write $filename\n";

    foreach $info (@{$self->get_OID_list()}) {
	if (defined $info) {
	    print OUTFILE join("\t", @$info), "\n";
	}
    }
    close (OUTFILE);
}

sub delete_info {
    my $self = shift (@_);
    my ($OID) = @_;

    if (defined $self->{'info'}->{$OID}) {
	delete $self->{'info'}->{$OID};
	
	my $i = 0;
	while ($i < scalar (@{$self->{'order'}})) {
	    if ($self->{'order'}->[$i]->[0] eq $OID) {
		splice (@{$self->{'order'}}, $i, 1);
		last;
	    }
	    $i ++;
	}
    }
}

sub add_info {
    my $self = shift (@_);
    my ($OID, $doc_file, $index_status, $sortmeta) = @_;
    $sortmeta = "" unless defined $sortmeta;

    if (! defined($OID)) {
	# only happens when no files can be processed?
	return undef;
    }

    print STDERR "**** adding info $OID\n";

    if (defined $self->{'info'}->{$OID}) {
	# test to see if we are in a reindex situation

	my $existing_status_info = $self->get_status_info($OID);

	if ($existing_status_info eq "D") {
	    # yes, we're in a reindexing situation
	    $self->delete_info ($OID);


	    # force setting to "reindex"
	    $index_status = "R";

	}
	else {
	    # some other, possibly erroneous, situation has arisen
	    # where the document already seems to exist
	    print STDERR "Warning: $OID already exists with index status $existing_status_info\n";
	    print STDERR "         Deleting previous version\n";

	    $self->delete_info ($OID);
	}
    }

    $self->{'info'}->{$OID} = [$doc_file,$index_status];
    push (@{$self->{'order'}}, [$OID, $sortmeta]);
}

# returns a list of the form [[OID, doc_file], ...]
sub get_OID_list {
    my $self = shift (@_);

    my ($OID);
    my @list = ();

    foreach $OID (sort {$a->[1] cmp $b->[1]} @{$self->{'order'}}) {
	push (@list, [$OID->[0], $self->{'info'}->{$OID->[0]}->[0]]);
    }
    return \@list;
}

# returns a list of the form [[doc_file, OID], ...]
sub get_file_list {
    my $self = shift (@_);

    my ($OID);
    my @list = ();

    foreach $OID (sort {$a->[1] cmp $b->[1]} @{$self->{'order'}}) {
	push (@list, [$self->{'info'}->{$OID->[0]}->[0], $OID->[0]]);
    }
    return \@list;
}


# returns a list of the form [doc_file]
sub get_info {
    my $self = shift (@_);
    my ($OID) = @_;

    if (defined $self->{'info'}->{$OID}) {
	return $self->{'info'}->{$OID};
    }

    return undef;
}


# returns the number of documents so far
sub size {
    my $self = shift (@_);
    return (scalar(@{$self->{'order'}}));
}

1;

