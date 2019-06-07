###########################################################################
#
# ArchivesInfPlugin.pm --
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

# plugin which reads through an archives.inf (or archiveinf-doc info database equivalent)
# -- i.e. the file generated in the archives directory when an import is done),
# processing each file it finds

package ArchivesInfPlugin;

use util;
use FileUtils;
use doc;
use CommonUtil;
use plugin;
use arcinfo;
use gsprintf;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa


BEGIN {
    @ArchivesInfPlugin::ISA = ('CommonUtil');
}

my $arguments = [
      { 'name' => "reversesort",
	'desc' => "{ArchivesInfPlugin.reversesort}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "2" },
	{ 'name' => "sort",
	'desc' => "{ArchivesInfPlugin.sort}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "2" }

		 ];

my $options = { 'name'     => "ArchivesInfPlugin",
		'desc'     => "{ArchivesInfPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
	        'args' => $arguments};
         
sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new CommonUtil($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

# called once, at the start of processing
sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    # verbosity is passed through from the processor
    $self->{'verbosity'} = $verbosity;

    # as are the outhandle and failhandle
    $self->{'outhandle'} = $outhandle if defined $outhandle;
    $self->{'failhandle'} = $failhandle;

}

sub deinit {
    my ($self) = @_;

    my $archive_info = $self->{'archive_info'};
    my $verbosity = $self->{'verbosity'};
    my $outhandle = $self->{'outhandle'};

    if (defined $archive_info) {
        # Get the infodbtype value for this collection from the arcinfo object
        my $infodbtype = $archive_info->{'infodbtype'};
	my $archive_info_filename = $self->{'archive_info_filename'};
	my $infodb_file_handle = &dbutil::open_infodb_write_handle($infodbtype, $archive_info_filename, "append");

       	my $file_list = $archive_info->get_file_list();

	foreach my $subfile (@$file_list) {	    
	    my $doc_oid = $subfile->[1];

	    my $index_status = $archive_info->get_status_info($doc_oid);

	    if ($index_status eq "D") {
		# delete
		$archive_info->delete_info($doc_oid);
		&dbutil::delete_infodb_entry($infodbtype, $infodb_file_handle, $doc_oid);

		my $doc_file = $subfile->[0];
		my $base_dir =$self->{'base_dir'};

		my $doc_filename = &FileUtils::filenameConcatenate($base_dir,$doc_file);

		my ($doc_tailname, $doc_dirname, $suffix) 
		    = File::Basename::fileparse($doc_filename, "\\.[^\\.]+\$");

		print $outhandle "Removing $doc_dirname\n" if ($verbosity>2);

		&FileUtils::removeFilesRecursive($doc_dirname);


	    }
	    elsif ($index_status =~ m/^(I|R)$/) {
		# mark as "been indexed"
		$archive_info->set_status_info($doc_oid,"B");
	    }
	}

	&dbutil::close_infodb_write_handle($infodbtype, $infodb_file_handle);
	$archive_info->save_info($archive_info_filename);
    }
}

# called at the beginning of each plugin pass (import has one, buildin has many)
sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    $self->{'base_dir'} = $base_dir;
}

sub remove_all {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;
}

sub remove_one {
    my $self = shift (@_);
    my ($file, $oids, $archivedir) = @_;
    return undef; # only called during import at this stage, this will never be processing a file
    
}


# called at the end of each plugin pass
sub end {
    my ($self) = shift (@_);

}


# return 1 if this class might recurse using $pluginfo
sub is_recursive {
    my $self = shift (@_);

    return 1;
}


sub compile_stats {
    my $self = shift(@_);
    my ($stats) = @_;
}

# We don't do metadata_read
sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    return undef;
}

sub file_block_read {

    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;

    if ($file eq "OIDcount") {
	my ($filename_full_path, $filename_no_path) 
	    = &util::get_full_filenames($base_dir, $file);
	$self->block_raw_filename($block_hash,$filename_full_path);
	return 1;
    }

    # otherwise, we don't do any file blocking

    return undef;
}


# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs,$total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $count = 0;

    # This function only makes sense at build-time
    return if (ref($processor) !~ /buildproc$/i);

    # Get the infodbtype value for this collection from the buildproc object
    my $infodbtype = $processor->{'infodbtype'};
    $infodbtype = "gdbm" if $infodbtype eq "gdbm-txtgz";
    
    # see if this has a archives information file within it
##    my $archive_info_filename = &FileUtils::filenameConcatenate($base_dir,$file,"archives.inf");
    my $archive_info_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", &FileUtils::filenameConcatenate($base_dir, $file));

    if (-e $archive_info_filename) {

	# found an archives.inf file
	&gsprintf($outhandle, "ArchivesInfPlugin: {common.processing} $archive_info_filename\n") if $self->{'verbosity'} > 1;

	# read in the archives information file
	my $archive_info = new arcinfo($infodbtype);
	$self->{'archive_info'} = $archive_info;
	$self->{'archive_info_filename'} = $archive_info_filename;
	if ($self->{'reversesort'}) {
	    $archive_info->reverse_sort();
	} elsif ($self->{'sort'}) {	
	    $archive_info->sort();
	}
	
	$archive_info->load_info ($archive_info_filename);
	
	my $file_list = $archive_info->get_file_list();

	# process each file
	foreach my $subfile (@$file_list) {

	    last if ($maxdocs != -1 && ($total_count + $count) >= $maxdocs);

	    my $tmp = &FileUtils::filenameConcatenate($file, $subfile->[0]);
	    next if $tmp eq $file;

	    my $doc_oid = $subfile->[1];
	    my $index_status = $archive_info->get_status_info($doc_oid);

	    my $curr_mode = $processor->get_mode();
	    my $new_mode = $curr_mode;
	    my $group_position = $archive_info->get_group_position($doc_oid);

	    # Start by assuming we want to process the file...
	    my $process_file = 1;

	    # ... unless we have processed files into a group doc.xml, in which case we only process the xml for the first one
	    if (defined $group_position && $group_position >1) {
		$process_file = 0;
	    }
	    # ...unless the build processor is incremental capable and -incremental was specified, in which case we need to check its index_status flag
	    elsif ($processor->is_incremental_capable() && $self->{'incremental'})
	    {
	        # Check to see if the file needs indexing
		if ($index_status eq "B")
		{
		    # Don't process this file as it has already been indexed
		    $process_file = 0;
		}
		elsif ($index_status eq "D") {
		    # Need to be delete it from the index.
		    $new_mode = $curr_mode."delete";
		    $process_file = 1;
		}
		elsif ($index_status eq "R") {
		    # Need to be reindexed/replaced
		    $new_mode = $curr_mode."reindex";

		    $process_file = 1;
		}
	    }
	    # ... or we're being asked to delete it (in which case skip it)
	    elsif ($index_status eq "D") {
		# Non-incremental Delete
		# It's already been deleted from the archives directory
		# (done during import.pl)
		# => All we need to do here is not process it

		$process_file = 0;
	    }

	    if (!$processor->is_incremental_capable() && $self->{'incremental'}) {
		# Nag feature
		if (!defined $self->{'incremental-warning'}) {
		    print $outhandle "\n";
		    print $outhandle "Warning: command-line option '-incremental' used with *non-incremental*\n";
		    print $outhandle "         processor '", ref $processor, "'. Some conflicts may arise.\n";
		    print $outhandle "\n";
		    sleep 10;
		    $self->{'incremental-warning'} = 1;
		}
	    }

	    if ($process_file) {
		# note: metadata is not carried on to the next level
		
		$processor->set_mode($new_mode) if ($new_mode ne $curr_mode);

		$count += &plugin::read ($pluginfo, $base_dir, $tmp, $block_hash, {}, $processor, $maxdocs, ($total_count+$count), $gli);

		$processor->set_mode($curr_mode) if ($new_mode ne $curr_mode);
	    }
	}

	return $count;
    }


    # wasn't an archives directory, someone else will have to process it
    return undef;
}

1;
