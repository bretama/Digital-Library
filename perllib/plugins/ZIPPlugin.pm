###########################################################################
#
# ZIPPlugin.pm --
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

# plugin which handles compressed and/or archived input formats
#
# currently handled formats and file extensions are:
# 
# gzip (.gz, .z, .tgz, .taz)
# bzip (.bz)
# bzip2 (.bz2)
# zip (.zip .jar)
# tar (.tar)
#
# this plugin relies on the following utilities being present 
# (if trying to process the corresponding formats)
#
# gunzip (for gzip)
# bunzip (for bzip)
# bunzip2 
# unzip (for zip)
# tar (for tar) 


package ZIPPlugin;

use BaseImporter;
use plugin;
use util;
use FileUtils;
use Cwd;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

BEGIN {
    @ZIPPlugin::ISA = ('BaseImporter');
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "string",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ];

my $options = { 'name'     => "ZIPPlugin",
		'desc'     => "{ZIPPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {

    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    # Are we actually incremental and doing import?
    my $proc_package_name = ref $processor;
    if ($proc_package_name !~ /buildproc$/ && $self->{'incremental'} == 1) {
        # Get the infodbtype value for this collection from the arcinfo object
        my $infodbtype = $processor->getoutputinfo()->{'infodbtype'};
	$infodbtype = "gdbm" if $infodbtype eq "gdbm-txtgz"; # in archives, cannot use txtgz version
	my $output_dir = $processor->getoutputdir();
    	my $archives_inf = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $output_dir);

	if ( -e $archives_inf ) {
	    $self->{'actually_incremental'} = 1;
	}
    }
   
    
}
# this is a recursive plugin
sub is_recursive {
    my $self = shift (@_);

    return 1;
}

sub get_default_process_exp {
    return q^(?i)\.(gz|tgz|z|taz|bz|bz2|zip|jar|tar)$^;
}

# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);
	
    my $tmpdir = $file;
    $tmpdir =~ s/\.[^\.]*//;
    $tmpdir = &util::rename_file($tmpdir, $self->{'file_rename_method'});
    $tmpdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp", $tmpdir);
    &FileUtils::makeAllDirectories ($tmpdir);
    
    print $outhandle "ZIPPlugin: extracting $filename_no_path to $tmpdir\n"
	if $self->{'verbosity'} > 1;
    
    # save current working directory
    my $cwd = cwd();
    chdir ($tmpdir) || die "Unable to change to $tmpdir";
    &FileUtils::copyFiles ($filename_full_path, $tmpdir);
    
    if ($file =~ /\.bz$/i) {
	$self->bunzip ($filename_no_path);
    } elsif ($file =~ /\.bz2$/i) {
	$self->bunzip2 ($filename_no_path);
    } elsif ($file =~ /\.(zip|jar|epub)$/i) {
	$self->unzip ($filename_no_path);
    } elsif ($file =~ /\.tar$/i) {
	$self->untar ($filename_no_path);
    } else {
	$self->gunzip ($filename_no_path);
    }
    
    chdir ($cwd) || die "Unable to change back to $cwd";
    
    # do the blocking step inside the folder
    &plugin::file_block_read ($pluginfo, "", $tmpdir,
			      $block_hash, $metadata, $gli);

    # if we are incremental, then we need to add all the files in the tmp folder into the new_files list otherwise they won't get processed.
    if ($self->{'actually_incremental'}) {
	my @file_list = ();
	&inexport::add_dir_contents_to_list($tmpdir, \@file_list);
	foreach my $file (@file_list) {
	    $block_hash->{'new_files'}->{$file} = 1;
	}
    }
    # all files in the tmp folder need to get the gsdlzipfilenmae metadata
    my $this_metadata = {};
    $this_metadata->{"gsdlzipfilename"} = $filename_full_path;
    &metadatautil::combine_metadata_structures($this_metadata, $metadata);
    my $numdocs = &plugin::read ($pluginfo, "", $tmpdir, $block_hash, $this_metadata, $processor, $maxdocs, $total_count, $gli);
    &FileUtils::removeFilesRecursive ($tmpdir);
    
    $self->{'num_archives'} ++;
    
    return $numdocs;
    
}

sub bunzip {
    my $self = shift (@_);
    my ($file) = @_;

    if (system ("bunzip \"$file\"")!=0)
    {
	&FileUtils::removeFiles ($file);
    }
}

sub bunzip2 {
    my $self = shift (@_);
    my ($file) = @_;

    if (system ("bunzip2 \"$file\"")!=0)
    {
	&FileUtils::removeFiles ($file);
    }
}

sub unzip {
    my $self = shift (@_);
    my ($file) = @_;

    system ("unzip \"$file\"");
    &FileUtils::removeFiles ($file) if -e $file;
}

sub untar {
    my $self = shift (@_);
    my ($file) = @_;

    system ("tar xf \"$file\"");
    &FileUtils::removeFiles ($file) if -e $file;
}

sub gunzip {
    my $self = shift (@_);
    my ($file) = @_;

    if (system ("gunzip \"$file\"")!=0)
    {
	&FileUtils::removeFiles ($file);
    };
}



1;
