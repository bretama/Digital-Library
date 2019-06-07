###########################################################################
#
# arcinfo.pm --
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


# This module stores information about the archives. At the moment
# this information just consists of the file name (relative to the
# directory the archives information file is in) and its OID.

# This module assumes there is a one to one correspondance between
# a file in the archives directory and an OID.

package arcinfo;

use constant ORDER_OID_INDEX  => 0;
use constant ORDER_SORT_INDEX => 1;

use constant INFO_FILE_INDEX    => 0;
use constant INFO_STATUS_INDEX  => 1;

use constant INFO_GROUPPOS_INDEX  => 3;
use strict;

use dbutil;


# File format read in: OID <tab> Filename <tab> Optional-Index-Status

# Index status can be:
#  I = Index for the first time
#  R = Reindex
#  D = Delete
#  B = Been indexed

sub new {
    my $class = shift(@_);
    my $infodbtype = shift(@_);

    # If the infodbtype wasn't passed in, use the default from dbutil
    if (!defined($infodbtype))
    {
      $infodbtype = &dbutil::get_default_infodb_type();
    }

    my $self = {'infodbtype' => $infodbtype,
		'info'=>{},
		'reverse-info'=>{},
		'order'=>[],
		'reverse_sort'=>0,
		'sort'=>0};

    return bless $self, $class;
}

sub _load_info_txt 
{
    my $self = shift (@_);
    my ($filename) = @_;

    if (defined $filename && &FileUtils::fileExists($filename)) {
	open (INFILE, $filename) || 
	    die "arcinfo::load_info couldn't read $filename\n";

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

sub _load_info_db
{
    my $self = shift (@_);
    my ($filename) = @_;

    my $infodb_map = {};

    &dbutil::read_infodb_file($self->{'infodbtype'}, $filename, $infodb_map);

    foreach my $oid ( keys %$infodb_map ) {
	my $vals = $infodb_map->{$oid};
	# interested in doc-file and index-status

	my ($doc_file) = ($vals=~/^<doc-file>(.*)$/m);
	my ($index_status) = ($vals=~/^<index-status>(.*)$/m);
	my ($sortmeta) = ($vals=~/^<sort-meta>(.*)$/m);
	my ($group_position) = ($vals=~/^<group-position>(.*)$/m);
	$self->add_info ($oid,$doc_file,$index_status,$sortmeta, $group_position);
    }
}


sub load_info {
    my $self = shift (@_);
    my ($filename) = @_;

    $self->{'info'} = {};

    if ((defined $filename) && &FileUtils::fileExists($filename)) {
	if ($filename =~ m/\.inf$/) {
	    $self->_load_info_txt($filename);
	}
	else {
	    $self->_load_info_db($filename);
	}
    }
}

sub _load_filelist_db
{
    my $self = shift (@_);
    my ($filename) = @_;

    my $infodb_map = {};

    &dbutil::read_infodb_file($self->{'infodbtype'}, $filename, $infodb_map);

    foreach my $file ( keys %$infodb_map ) {
	# turn placeholders in the file keys of archiveinf-src file back to absolute paths
	$file = &util::placeholders_to_abspath($file);
	$self->{'prev_import_filelist'}->{$file} = 1;
    }
}


sub load_prev_import_filelist {
    my $self = shift (@_);
    my ($filename) = @_;

    $self->{'import-filelist'} = {};

    if ((defined $filename) && &FileUtils::fileExists($filename)) {
	if ($filename =~ m/\.inf$/) {
	    # e.g. 'archives-src.inf' (which includes complete list of file
	    # from last time import.pl was run)
	    $self->_load_info_txt($filename);
	}
	else {
	    $self->_load_filelist_db($filename);
	}
    }
}

sub load_revinfo_UNTESTED
{
    my $self = shift (@_);
    my ($rev_filename) = @_;

    my $rev_infodb_map = {};

    &dbutil::read_infodb_file($self->{'infodbtype'}, $rev_filename, $rev_infodb_map);

    foreach my $srcfile ( keys %$rev_infodb_map ) {

	my $vals = $rev_infodb_map->{$srcfile};

	$srcfile = &util::abspath_to_placeholders($srcfile);

	foreach my $OID ($vals =~ m/^<oid>(.*)$/gm) {
	    $self->add_reverseinfo($srcfile,$OID);
	}
    }
}


sub _save_info_txt {
    my $self = shift (@_);
    my ($filename) = @_;

    my ($OID, $info);

    open (OUTFILE, ">$filename") || 
	die "arcinfo::save_info couldn't write $filename\n";
  
    foreach $info (@{$self->get_OID_list()}) {
	if (defined $info) {
	    print OUTFILE join("\t", @$info), "\n";
	}
    }
    close (OUTFILE);
}

sub _save_info_db {
    my $self = shift (@_);
    my ($filename) = @_;

    my $infodbtype = $self->{'infodbtype'};

    # Not the most efficient operation, but will do for now

    # read it in
    my $infodb_map = {};
    &dbutil::read_infodb_file($infodbtype, $filename, $infodb_map);

    # change index-status values
    foreach my $info (@{$self->get_OID_list()}) {
	if (defined $info) {
	    my ($oid,$doc_file,$index_status) = @$info;
	    if (defined $infodb_map->{$oid}) {
		my $vals_ref = \$infodb_map->{$oid};
		$$vals_ref =~ s/^<index-status>(.*)$/<index-status>$index_status/m;
	    }
	    else {
		print STDERR "Warning: $filename does not have key $oid\n";
	    }
	}
    }


    # write out again
    my $infodb_handle = &dbutil::open_infodb_write_handle($infodbtype, $filename);
    foreach my $oid ( keys %$infodb_map ) {
	my $vals = $infodb_map->{$oid};
	&dbutil::write_infodb_rawentry($infodbtype,$infodb_handle,$oid,$vals);
    }
    &dbutil::close_infodb_write_handle($infodbtype, $infodb_handle);

}

sub save_revinfo_db {
    my $self = shift (@_);
    my ($rev_filename) = @_;

    # Output reverse lookup database

    my $rev_infodb_map = $self->{'reverse-info'};
    my $rev_infodb_handle 
	= &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $rev_filename, "append");

    foreach my $key ( keys %$rev_infodb_map ) {
	my $val_hash = $rev_infodb_map->{$key};

	$key = &util::abspath_to_placeholders($key);	

	&dbutil::write_infodb_entry($self->{'infodbtype'}, $rev_infodb_handle, $key, $val_hash);
    }
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $rev_infodb_handle);

}

sub save_info {
    my $self = shift (@_);
    my ($filename) = @_;
    if ($filename =~ m/(contents)|(\.inf)$/) {
	$self->_save_info_txt($filename);
    }
    else {
	$self->_save_info_db($filename);
    }
}

sub delete_info {
    my $self = shift (@_);
    my ($OID) = @_;

    if (defined $self->{'info'}->{$OID}) {
	delete $self->{'info'}->{$OID};
	
	my $i = 0;
	while ($i < scalar (@{$self->{'order'}})) {
	    if ($self->{'order'}->[$i]->[ORDER_OID_INDEX] eq $OID) {
		splice (@{$self->{'order'}}, $i, 1);
		last;
	    }
	    
	    $i ++;
	}
    }
}

sub add_info {
    my $self = shift (@_);
    my ($OID, $doc_file, $index_status, $sortmeta, $group_position) = @_;
    $sortmeta = "" unless defined $sortmeta;
    $index_status = "I" unless defined $index_status; # I = needs indexing
    if (! defined($OID)) {
	# only happens when no files can be processed?
	return undef;
    }

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

    $self->{'info'}->{$OID} = [$doc_file,$index_status,$sortmeta, $group_position];
    push (@{$self->{'order'}}, [$OID, $sortmeta]); # ORDER_OID_INDEX and ORDER_SORT_INDEX


}

sub set_status_info {
    my $self = shift (@_);
    my ($OID, $index_status) = @_;

    my $OID_info = $self->{'info'}->{$OID};
    $OID_info->[INFO_STATUS_INDEX] = $index_status;
}


sub get_status_info {
    my $self = shift (@_);
    my ($OID) = @_;

    my $index_status = undef;

    my $OID_info = $self->{'info'}->{$OID};
    if (defined $OID_info) {
	$index_status = $OID_info->[INFO_STATUS_INDEX];
    }
    else {
	die "Unable to find document id $OID\n";
    }

    return $index_status;

}

sub get_group_position {
    my $self = shift (@_);
    my ($OID) = @_;

    my $group_position = undef;
    my $OID_info = $self->{'info'}->{$OID};
    if (defined $OID_info) {
	$group_position = $OID_info->[INFO_GROUPPOS_INDEX];
    }
    else {
	die "Unable to find document id $OID\n";
    }
    return $group_position;
	
}
sub add_reverseinfo {
    my $self = shift (@_);
    my ($key, $OID) = @_;

    my $existing_key = $self->{'reverse-info'}->{$key};
    if (!defined $existing_key) {
	$existing_key = {};
	$self->{'reverse-info'}->{$key} = $existing_key;
    }

    my $existing_oid = $existing_key->{'oid'};	
    if (!defined $existing_oid) {
	$existing_oid = [];
	$existing_key->{'oid'} = $existing_oid;
    }

    push(@$existing_oid,$OID);
}

sub set_meta_file_flag {
    my $self = shift (@_);
    my ($key) = @_;

    my $existing_key = $self->{'reverse-info'}->{$key};
    if (!defined $existing_key) {
	$existing_key = {};
	$self->{'reverse-info'}->{$key} = $existing_key;
    }

    $existing_key->{'meta-file'} = ["1"];

}
sub reverse_sort 
{
    my $self = shift(@_);
    $self->{'reverse_sort'} = 1;
}
sub sort 
{
    my $self = shift(@_);
    $self->{'sort'} = 1;
}


# returns a list of the form [[OID, doc_file, index_status], ...]
sub get_OID_list 
{
    my $self = shift (@_);

    my $order = $self->{'order'};

    my @sorted_order;
    if ($self->{'reverse_sort'}) {
	@sorted_order = sort {$b->[ORDER_SORT_INDEX] cmp $a->[ORDER_SORT_INDEX]} @$order;
    } elsif ($self->{'sort'}) {
	@sorted_order = sort {$a->[ORDER_SORT_INDEX] cmp $b->[ORDER_SORT_INDEX]} @$order;
    } else { # not sorting, don't bother
	@sorted_order = @$order;
    }

    my @list = ();

    foreach my $OID_order (@sorted_order) {
	my $OID = $OID_order->[ORDER_OID_INDEX];
	my $OID_info = $self->{'info'}->{$OID};

	push (@list, [$OID, $OID_info->[INFO_FILE_INDEX], 
		      $OID_info->[INFO_STATUS_INDEX]]);
    }

    return \@list;
}

# returns a list of the form [[doc_file, OID], ...]
sub get_file_list {
    my $self = shift (@_);

    my $order = $self->{'order'};

    my @sorted_order;
    if ($self->{'reverse_sort'}) {
	@sorted_order = sort {$b->[ORDER_SORT_INDEX] cmp $a->[ORDER_SORT_INDEX]} @$order;
    } elsif ($self->{'sort'}) {
	@sorted_order = sort {$a->[ORDER_SORT_INDEX] cmp $b->[ORDER_SORT_INDEX]} @$order;
    } else { # not sorting, don't bother
	@sorted_order = @$order;
    }

    my @list = ();

    foreach my $OID_order (@sorted_order) {
	my $OID = $OID_order->[ORDER_OID_INDEX];
	my $OID_info = $self->{'info'}->{$OID};

	push (@list, [$OID_info->[INFO_FILE_INDEX], $OID]);
    }

    return \@list;
}


# returns a list of the form [doc_file,index_status,$sort_meta, $group_position]
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

