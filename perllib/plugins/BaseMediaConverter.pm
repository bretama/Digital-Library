###########################################################################
#
# BaseMediaConverter - helper plugin that provide base functionality for 
#                  image/video conversion using ImageMagick/ffmpeg
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
package BaseMediaConverter;

use PrintInfo;

use convertutil;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
use gsprintf 'gsprintf';

BEGIN {
    @BaseMediaConverter::ISA = ('PrintInfo');
}

my $arguments = [
      { 'name' => "enable_cache",
	'desc' => "{BaseMediaConverter.enable_cache}",
	'type' => "flag",
	'reqd' => "no",
	}

		 ];

my $options = { 'name' => "BaseMediaConverter",
		'desc' => "{BaseMediaConverter.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args' => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$auxiliary) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists, $auxiliary);

    return bless $self, $class;
}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    # Save base_dir for use in file cache
    $self->{'base_dir'} = $base_dir;
}


sub init_cache_for_file
{
    my $self = shift @_;
    my ($filename) = @_;

    my $verbosity = $self->{'verbosity'};
    my $outhandle = $self->{'outhandle'};
    my $base_dir = $self->{'base_dir'};

    my $collect_dir = $ENV{'GSDLCOLLECTDIR'};
    $collect_dir =~ s/\\/\//g; # Work in Unix style world
    
    # Work out relative filename within 'base_dir'
    $filename =~ s/\\/\//g;
    $base_dir =~ s/\\/\//g;
    my ($file) = ($filename =~ m/^$base_dir(.*?)$/);
    
    if (!defined $file) {
	# Perhaps the filename is taken from within cache_dir area?
	my $cached_dir = &FileUtils::filenameConcatenate($collect_dir,"cached");
	($file) = ($filename =~ m/^$cached_dir(.*?)$/);
	# A cached name already has the fileroot baked -in as the last directory name
	# => strip it out
	$file =~ s/[\/\\][^\/\\]+([\/\\][^\/\\]*)$/$1/;

#       Commented out code is the previous version that looked to
#       handle this situation, but ran foul of situtation where
#       sub-directories within 'import' are used
#
#	# Perhaps the filename is taken from within cache_dir area?
#	my $prev_cached_dir = $self->{'cached_dir'};
#	($file) = ($filename =~ m/^$prev_cached_dir(.*?)$/);
    }

    $file =~ s/^\/|\\//; # get rid of leading slash from relative filename


    # Setup cached_dir and file_root

    my ($file_root, $dirname, $suffix)
	= &File::Basename::fileparse($file, "\\.[^\\.]+\$");

    # if dirname is in collections tmp area, remove collect_dir prefix
    $dirname =~ s/^$collect_dir//;

    if ($ENV{'GSDLOS'} eq "windows") {
	# if dirname starts with Windows drive letter, strip it off
	$dirname =~ s/^[a-z]:\///i;
    }

    my $base_output_dir = &FileUtils::filenameConcatenate($collect_dir,"cached",$dirname);
##    my $base_output_dir = &FileUtils::filenameConcatenate($collect_dir,"cached",$dirname);

    if (!-e $base_output_dir ) {
	print $outhandle "Creating directory $base_output_dir\n"
	    if ($verbosity>2);

	&FileUtils::makeAllDirectories($base_output_dir);
    }

    my $output_dir = &FileUtils::filenameConcatenate($base_output_dir,$file_root);

    if (!-e $output_dir) {
	print $outhandle "Creating directory $output_dir\n"
	    if ($verbosity>2);

	&FileUtils::makeAllDirectories($output_dir);
    }

    $self->{'cached_dir'} = $output_dir;
    $self->{'cached_file_root'} = $file_root;    
}



sub run_general_cmd
{
    my $self = shift @_;
    my ($command,$print_info) = @_;


    if (!defined $print_info->{'verbosity'}) {
	$print_info->{'verbosity'} = $self->{'verbosity'};
    }

    if (!defined $print_info->{'outhandle'}) {
	$print_info->{'outhandle'} = $self->{'outhandle'};
    }

    
    return &convertutil::run_general_cmd(@_);
}


sub regenerate_general_cmd
{
    my $self = shift @_;
    my ($command,$ifilename,$ofilename,$print_info) = @_;

    if (!defined $print_info->{'verbosity'}) {
	$print_info->{'verbosity'} = $self->{'verbosity'};
    }

    if (!defined $print_info->{'outhandle'}) {
	$print_info->{'outhandle'} = $self->{'outhandle'};
    }

    return &convertutil::regenerate_general_cmd(@_);
}



sub run_uncached_general_cmd
{
    my $self = shift @_;

    my ($command,$ifilename,$ofilename,$print_info) = @_;

    return $self->run_general_cmd($command,$print_info);
}



sub run_cached_general_cmd
{
    my $self = shift @_;

    my ($command,$ifilename,$ofilename,$print_info) = @_;

    if (!defined $print_info->{'verbosity'}) {
	$print_info->{'verbosity'} = $self->{'verbosity'};
    }

    if (!defined $print_info->{'outhandle'}) {
	$print_info->{'outhandle'} = $self->{'outhandle'};
    }

    return &convertutil::run_cached_general_cmd(@_);
}



sub autorun_general_cmd
{
    my $self = shift @_;

    my ($command,$ifilename,$ofilename,$print_info) = @_;

    my $result;
    my $regenerated;
    my $had_error;

    if ($self->{'enable_cache'}) {
	($regenerated,$result,$had_error)
	    = $self->run_cached_general_cmd($command,$ifilename,$ofilename,$print_info);
    }
    else {
	$regenerated = 1; # always true for a command that is always run
	($result,$had_error)
	    = $self->run_general_cmd($command,$print_info);
    }

    return ($regenerated,$result,$had_error);
}


#
1;	
