###########################################################################
#
# DirectoryPlugin.pm --
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

# DirectoryPlugin is a plugin which recurses through directories processing
# each file it finds - which basically means passing it down the plugin 
# pipeline

package DirectoryPlugin;

use extrametautil;
use CommonUtil;
use plugin;
use util;
use FileUtils;
use metadatautil;

use File::Basename;
use strict;
no strict 'refs';
no strict 'subs';

use Encode::Locale;
use Encode;
use Unicode::Normalize;

BEGIN {
    @DirectoryPlugin::ISA = ('CommonUtil');
}

my $arguments =
    [ { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => "regexp",
	'deft' => &get_default_block_exp(),
	'reqd' => "no" },
      # this option has been deprecated. leave it here for now so we can warn people not to use it
      { 'name' => "use_metadata_files",
	'desc' => "{DirectoryPlugin.use_metadata_files}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "recheck_directories",
	'desc' => "{DirectoryPlugin.recheck_directories}",
	'type' => "flag",
	'reqd' => "no" } ];
    
my $options = { 'name'     => "DirectoryPlugin",
		'desc'     => "{DirectoryPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new CommonUtil($pluginlist, $inputargs, $hashArgOptLists);
    
    if ($self->{'info_only'}) {
	# don't worry about any options or initialisations etc
	return bless $self, $class;
    }

    # we have left this option in so we can warn people who are still using it
    if ($self->{'use_metadata_files'}) {
	die "ERROR: DirectoryPlugin -use_metadata_files option has been deprecated. Please remove the option and add MetadataXMLPlug to your plugin list instead!\n";
    }
	
    $self->{'num_processed'} = 0;
    $self->{'num_not_processed'} = 0;
    $self->{'num_blocked'} = 0;
    $self->{'num_archives'} = 0;

    $self->{'subdir_extrametakeys'} = {};

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

# called once, after all passes have finished
sub deinit {
    my ($self) = @_;

}

# called at the beginning of each plugin pass (import has one, building has many)
sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    # Only lookup timestamp info for import.pl, and only if incremental is set
    my $proc_package_name = ref $processor;
    if ($proc_package_name !~ /buildproc$/ && $self->{'incremental'} == 1) {
        # Get the infodbtype value for this collection from the arcinfo object
        my $infodbtype = $processor->getoutputinfo()->{'infodbtype'};
	$infodbtype = "gdbm" if $infodbtype eq "gdbm-txtgz"; # in archives, cannot use txtgz version
	my $output_dir = $processor->getoutputdir();
    	my $archives_inf = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $output_dir);

	if ( -e $archives_inf ) {
	    $self->{'inf_timestamp'} = -M $archives_inf;
	}
    }
}

sub remove_all {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;
}


sub remove_one {
    my $self = shift (@_);
    my ($file, $oids, $archivedir) = @_;
    return undef; # this will never be called for directories (will it??)

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

sub get_default_block_exp {
    my $self = shift (@_);
    
    return '(?i)(CVS|\.svn|Thumbs\.db|OIDcount|\.DS_Store|~)$';
}

sub check_directory_path {

    my $self = shift(@_);
    my ($dirname) = @_;
    
    return undef unless (-d $dirname);

    return 0 if ($self->{'block_exp'} ne "" && $dirname =~ /$self->{'block_exp'}/);

    my $outhandle = $self->{'outhandle'};
    
    # check to make sure we're not reading the archives or index directory
    my $gsdlhome = quotemeta($ENV{'GSDLHOME'});
    if ($dirname =~ m/^$gsdlhome\/.*?\/import.*?\/(archives|index)$/) {
	print $outhandle "DirectoryPlugin: $dirname appears to be a reference to a Greenstone collection, skipping.\n";
        return 0;
    }
    
    # check to see we haven't got a cyclic path...
    if ($dirname =~ m%(/.*){,41}%) {
	print $outhandle "DirectoryPlugin: $dirname is 40 directories deep, is this a recursive path? if not increase constant in DirectoryPlugin.pm.\n";
	return 0;
    }
    
    # check to see we haven't got a cyclic path...
    if ($dirname =~ m%.*?import/(.+?)/import/\1.*%) {
	print $outhandle "DirectoryPlugin: $dirname appears to be in a recursive loop...\n";
	return 0;
    }

    return 1;
}

# this may be called more than once
sub sort_out_associated_files {

    my $self = shift (@_);
    my ($block_hash) = @_;
    if (!scalar (keys %{$block_hash->{'shared_fileroot'}})) {
	return;
    }

    $self->{'assocfile_info'} = {} unless defined $self->{'assocfile_info'};
    my $metadata = $self->{'assocfile_info'};
    foreach my $prefix (keys %{$block_hash->{'shared_fileroot'}}) {
	my $record = $block_hash->{'shared_fileroot'}->{$prefix};

	my $tie_to = $record->{'tie_to'};
	my $exts = $record->{'exts'};
	
	if ((defined $tie_to) && (scalar (keys %$exts) > 0)) {
	    # set up fileblocks and assocfile_tobe
	    my $base_file = "$prefix$tie_to";
	    $metadata->{$base_file} = {} unless defined $metadata->{$base_file};
	    my $base_file_metadata = $metadata->{$base_file};
	    
	    $base_file_metadata->{'gsdlassocfile_tobe'} = [] unless defined $base_file_metadata->{'gsdlassocfile_tobe'};
	    my $assoc_tobe = $base_file_metadata->{'gsdlassocfile_tobe'};
	    foreach my $e (keys %$exts) {
		# block the file
		$self->block_filename($block_hash,"$prefix$e");
		# set up as an associatd file
		print STDERR "  $self->{'plugin_type'}: Associating $prefix$e with $tie_to version\n";
		my $mime_type = ""; # let system auto detect this
		push(@$assoc_tobe,"$prefix$e:$mime_type:"); 

	    }
	}
    } # foreach record

    $block_hash->{'shared_fileroot'} = undef;
    $block_hash->{'shared_fileroot'} = {};

}




sub file_block_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};
    
    # Calculate the directory name and ensure it is a directory and
    # that it is not explicitly blocked.
    my $dirname = $file;
    $dirname = &FileUtils::filenameConcatenate($base_dir, $file) if $base_dir =~ /\w/;

    my $directory_ok = $self->check_directory_path($dirname);
    return $directory_ok unless (defined $directory_ok && $directory_ok == 1);

    print $outhandle "Global file scan checking directory: $dirname\n" if ($verbosity > 2);

    $block_hash->{'all_files'} = {} unless defined $block_hash->{'all_files'};
    $block_hash->{'metadata_files'} = {} unless defined $block_hash->{'metadata_files'};

    $block_hash->{'file_blocks'} = {} unless defined $block_hash->{'file_blocks'};
    $block_hash->{'shared_fileroot'} = {} unless defined $block_hash->{'shared_fileroot'};

     # Recur over directory contents.
    my (@dir, $subfile);
    #my $count = 0;
    
    print $outhandle "DirectoryPlugin block: getting directory $dirname\n" if ($verbosity > 2);
    
    # find all the files in the directory
    if (!opendir (DIR, $dirname)) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='Could not read directory $dirname'>\n";
	}
	print $outhandle "DirectoryPlugin: WARNING - couldn't read directory $dirname\n";
	return -1; # error in processing
    }
    @dir = sort readdir (DIR);
    closedir (DIR);
    
    for (my $i = 0; $i < scalar(@dir); $i++) {
	my $raw_subfile = $dir[$i];
	next if ($raw_subfile =~ m/^\.\.?$/);

	my $this_file_base_dir = $base_dir;
	my $raw_file_subfile = &FileUtils::filenameConcatenate($file, $raw_subfile);

	# Recursively read each $raw_subfile
	print $outhandle "DirectoryPlugin block recurring: $raw_file_subfile\n" if ($verbosity > 2);
	#$count += &plugin::file_block_read ($pluginfo, $this_file_base_dir,

	&plugin::file_block_read ($pluginfo, $this_file_base_dir,
				  $raw_file_subfile,
				  $block_hash, $metadata, $gli);
	
    }
    $self->sort_out_associated_files($block_hash);
    #return $count;
	return 1;
    
}

# We don't do metadata_read
sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    return undef;
}


# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories

# This function passes around metadata hash structures.  Metadata hash
# structures are hashes that map from a (scalar) key (the metadata element
# name) to either a scalar metadata value or a reference to an array of
# such values.

sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $in_metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    # Calculate the directory name and ensure it is a directory and
    # that it is not explicitly blocked.
    my $dirname;
    if ($file eq "") {
	$dirname = $base_dir;
    } else {
	$dirname = $file;
	$dirname = &FileUtils::filenameConcatenate($base_dir, $file) if $base_dir =~ /\w/;
    }
	
    my $directory_ok = $self->check_directory_path($dirname);
    return $directory_ok unless (defined $directory_ok && $directory_ok == 1);
        
    if (($verbosity > 2) && ((scalar keys %$in_metadata) > 0)) {
        print $outhandle "DirectoryPlugin: metadata passed in: ", 
	join(", ", keys %$in_metadata), "\n";
    }
    
    # Recur over directory contents.
    my (@dir, $subfile);
    
    print $outhandle "DirectoryPlugin read: getting directory $dirname\n" if ($verbosity > 2);
    
    # find all the files in the directory
    if (!opendir (DIR, $dirname)) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='Could not read directory $dirname'>\n";
	}
	print $outhandle "DirectoryPlugin: WARNING - couldn't read directory $dirname\n";
	return -1; # error in processing
    }
    @dir = sort readdir (DIR);
    map {  $_ = &unicode::raw_filename_to_url_encoded($_);  } @dir;
    closedir (DIR);
    # Re-order the files in the list so any directories ending with .all are moved to the end
    for (my $i = scalar(@dir) - 1; $i >= 0; $i--) {
	if (-d &FileUtils::filenameConcatenate($dirname, $dir[$i]) && $dir[$i] =~ /\.all$/) {
	    push(@dir, splice(@dir, $i, 1));
	}
    }

    # setup the metadata structures. we do a metadata_read pass to see if there is any additional metadata, then pass it to read
    
    my $additionalmetadata = 0;      # is there extra metadata available?
    my %extrametadata;               # maps from filespec to extra metadata keys
    my %extrametafile;               # maps from filespec to the metadata.xml (or similar) file it came from
    my @extrametakeys;               # keys of %extrametadata in order read


    my $os_dirsep = &util::get_os_dirsep();
    my $dirsep    = &util::get_dirsep();
    my $base_dir_regexp = $base_dir;
    $base_dir_regexp =~ s/\//$os_dirsep/g;
       
    # Want to get relative path of local_dirname within the base_directory
    # but with URL style slashes. 
    my $local_dirname = &util::filename_within_directory_url_format($dirname, $base_dir);

    # if we are in import folder, then local_dirname will be empty
    if ($local_dirname ne "") {
	# convert to perl unicode
	$local_dirname = $self->raw_filename_to_unicode($local_dirname);
	
	# look for extra metadata passed down from higher folders 	
	$local_dirname .= "/"; # closing slash must be URL type slash also and not $dirsep;
	if (defined $self->{'subdir_extrametakeys'}->{$local_dirname}) {
	    my $extrakeys = $self->{'subdir_extrametakeys'}->{$local_dirname};
	    foreach my $ek (@$extrakeys) {
		my $extrakeys_re  = $ek->{'re'};
		my $extrakeys_md  = $ek->{'md'};
		my $extrakeys_mf  = $ek->{'mf'};
		&extrametautil::addmetakey(\@extrametakeys, $extrakeys_re);
		&extrametautil::setmetadata(\%extrametadata, $extrakeys_re, $extrakeys_md);
		&extrametautil::setmetafile(\%extrametafile, $extrakeys_re, $extrakeys_mf);
	    }
	    delete($self->{'subdir_extrametakeys'}->{$local_dirname});
	} 
    }
    # apply metadata pass for each of the files in the directory -- ignore
    # maxdocs here
    my $num_files = scalar(@dir);
    for (my $i = 0; $i < scalar(@dir); $i++) {
	my $subfile = $dir[$i];
	next if ($subfile =~ m/^\.\.?$/);

	my $this_file_base_dir = $base_dir;
	my $raw_subfile = &unicode::url_encoded_to_raw_filename($subfile);

	my $raw_file_subfile = &FileUtils::filenameConcatenate($file, $raw_subfile);
	my $raw_full_filename = &FileUtils::filenameConcatenate($this_file_base_dir, $raw_file_subfile);
	if ($self->raw_file_is_blocked($block_hash, $raw_full_filename)) {
	    print STDERR "DirectoryPlugin: file $raw_full_filename was blocked for metadata_read\n" if ($verbosity > 2);
	    next;
	}

	# Recursively read each $raw_subfile
	print $outhandle "DirectoryPlugin metadata recurring: $raw_subfile\n" if ($verbosity > 2);
	
	&plugin::metadata_read ($pluginfo, $this_file_base_dir,
				$raw_file_subfile,$block_hash,
				\@extrametakeys, \%extrametadata,
				\%extrametafile,
				$processor, $gli);
	$additionalmetadata = 1;
    }

    # filter out any extrametakeys that mention subdirectories and store
    # for later use (i.e. when that sub-directory is being processed)
    foreach my $ek (@extrametakeys) { # where each Extrametakey (which is a filename) is stored as a  url-style regex
	
	my ($subdir_re,$extrakey_dir) = &util::url_fileparse($ek);
	if ($extrakey_dir ne "") {
	    # a subdir was specified
	    my $md = &extrametautil::getmetadata(\%extrametadata, $ek);
	    my $mf = &extrametautil::getmetafile(\%extrametafile, $ek);

	    my $subdir_extrametakeys = $self->{'subdir_extrametakeys'};
	    my $subdir_rec = { 're' => $subdir_re, 'md' => $md, 'mf' => $mf };

	    # when it's looked up, it must be relative to the base dir
	    push(@{$subdir_extrametakeys->{"$local_dirname$extrakey_dir"}},$subdir_rec);
	}
    }
    
    # import each of the files in the directory
    my $count=0;
    for (my $i = 0; $i <= scalar(@dir); $i++) {
	# When every file in the directory has been done, pause for a moment (figuratively!)
	# If the -recheck_directories argument hasn't been provided, stop now (default)
	# Otherwise, re-read the contents of the directory to check for new files
	#   Any new files are added to the @dir list and are processed as normal
	#   This is necessary when documents to be indexed are specified in bibliographic DBs
	#   These files are copied/downloaded and stored in a new folder at import time
	if ($i == $num_files) {
	    last unless $self->{'recheck_directories'};

	    # Re-read the files in the directory to see if there are any new files
	    last if (!opendir (DIR, $dirname));
	    my @dirnow = sort readdir (DIR);
	    map { $_ = &unicode::raw_filename_to_url_encoded($_) } @dirnow;
	    closedir (DIR);

	    # We're only interested if there are more files than there were before
	    last if (scalar(@dirnow) <= scalar(@dir));

	    # Any new files are added to the end of @dir to get processed by the loop
	    my $j;
	    foreach my $subfilenow (@dirnow) {
		for ($j = 0; $j < $num_files; $j++) {
		    last if ($subfilenow eq $dir[$j]);
		}
		if ($j == $num_files) {
		    # New file
		    push(@dir, $subfilenow);
		}
	    }
	    # When the new files have been processed, check again
	    $num_files = scalar(@dir);
	}

	my $subfile = $dir[$i];
	last if ($maxdocs != -1 && ($count + $total_count) >= $maxdocs);
	next if ($subfile =~ /^\.\.?$/);

	my $this_file_base_dir = $base_dir;
	my $raw_subfile = &unicode::url_encoded_to_raw_filename($subfile);
	# get the canonical unicode version of the filename. This may not match
	# the filename on the file system. We will use it to compare to regex
	# in the metadata table.
	my $unicode_subfile = &util::raw_filename_to_unicode($dirname, $raw_subfile);
	my $raw_file_subfile = &FileUtils::filenameConcatenate($file, $raw_subfile);
	my $raw_full_filename 
	    = &FileUtils::filenameConcatenate($this_file_base_dir,$raw_file_subfile);
	my $full_unicode_file = $self->raw_filename_to_unicode($raw_full_filename);

	if ($self->file_is_blocked($block_hash,$full_unicode_file)) {
	    next;
	}
	if ($self->file_is_blocked($block_hash,$raw_full_filename)) {
	    print STDERR "DirectoryPlugin: file $raw_full_filename was blocked for read\n"  if ($verbosity > 2);
	    next;
	}
	# Follow Windows shortcuts
	if ($raw_subfile =~ m/(?i)\.lnk$/ && (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin"))) {
	    require Win32::Shortcut;
	    my $shortcut = new Win32::Shortcut(&FileUtils::filenameConcatenate($dirname, $raw_subfile));
	    if ($shortcut) {
		# The file to be processed is now the target of the shortcut
		$this_file_base_dir = "";
		$file = "";
		$raw_subfile = $shortcut->Path;
	    }
	    $shortcut->Close(); # see http://cpansearch.perl.org/src/JDB/Win32-Shortcut-0.08/docs/reference.html
	}

	# check for a symlink pointing back to a leading directory
	if (-d "$dirname/$raw_subfile" && -l "$dirname/$raw_subfile") {
	    # readlink gives a "fatal error" on systems that don't implement
	    # symlinks. This assumes the the -l test above would fail on those.
	    my $linkdest=readlink "$dirname/$raw_subfile";
	    if (!defined ($linkdest)) {
		# system error - file not found?
		warn "DirectoryPlugin: symlink problem - $!";
	    } else {
		# see if link points to current or a parent directory
		if ($linkdest =~ m@^[\./\\]+$@ ||
		    index($dirname, $linkdest) != -1) {
		    warn "DirectoryPlugin: Ignoring recursive symlink ($dirname/$raw_subfile -> $linkdest)\n";
		    next;
		    ;
		}
	    }
	}

	print $outhandle "DirectoryPlugin: preparing metadata for $raw_subfile\n" if ($verbosity > 2);

	# Make a copy of $in_metadata to pass to $raw_subfile
	my $out_metadata = {};
	&metadatautil::combine_metadata_structures($out_metadata, $in_metadata);

	# check the assocfile_info
	if (defined $self->{'assocfile_info'}->{$raw_full_filename}) {
	    &metadatautil::combine_metadata_structures($out_metadata, $self->{'assocfile_info'}->{$raw_full_filename});
	}

	### Now we need to look up the metadata table to see if there is any 
	# extra metadata for us. We need the canonical unicode version here.
	if ($additionalmetadata == 1) {
	    foreach my $filespec (@extrametakeys) {
		if ($unicode_subfile =~ /^$filespec$/) {
		    print $outhandle "File \"$unicode_subfile\" matches filespec \"$filespec\"\n" 
			if ($verbosity > 2);
		    my $mdref = &extrametautil::getmetadata(\%extrametadata, $filespec);
		    my $mfref = &extrametautil::getmetafile(\%extrametafile, $filespec);

		    # Add the list files where the metadata came from
		    # into the metadata table so we can track this
		    # This mechanism is similar to how gsdlassocfile works

		    my @metafile_pair = ();
		    foreach my $l (keys %$mfref) {
			my $f = $mfref->{$l};
			push (@metafile_pair, "$f : $l");
		    }

		    $mdref->{'gsdlmetafile'} = \@metafile_pair;

		    &metadatautil::combine_metadata_structures($out_metadata, $mdref);
		}
	    }
	}

	if (defined $self->{'inf_timestamp'}) {
	    # Look to see if it's a completely new file

	    if (!$block_hash->{'new_files'}->{$raw_full_filename}) {
		# Not a new file, must be an existing file
		# Let' see if it's newer than the last import.pl


		if (! -d $raw_full_filename) {
		    if (!$block_hash->{'reindex_files'}->{$raw_full_filename}) {
			# filename has been around for longer than inf_timestamp
			print $outhandle "**** Skipping $unicode_subfile\n" if ($verbosity >3);
			next;
		    }
		    else {
			# Remove old folder in archives (might hash to something different)
			# *** should be doing this on a Del one as well
			# but leave folder name?? and ensure hashs to
			# same again??

			# Then let through as new doc??

			# mark to doc-oids that rely on it for re-indexing
		    }
		}
	    }
	}

	# Recursively read each $subfile
	print $outhandle "DirectoryPlugin recurring: $unicode_subfile\n" if ($verbosity > 2);
	
	$count += &plugin::read ($pluginfo, $this_file_base_dir,
				 $raw_file_subfile, $block_hash,
				 $out_metadata, $processor, $maxdocs, ($total_count + $count), $gli);
    }

    return $count;
}

sub compile_stats {
    my $self = shift(@_);
    my ($stats) = @_;
}

1;
