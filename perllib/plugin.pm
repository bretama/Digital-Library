###########################################################################
#
# plugin.pm -- functions to handle using plugins
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

package plugin;


use strict; # to pick up typos and undeclared variables...
no strict 'refs'; # ...but allow filehandles to be variables and vice versa
no strict 'subs';

require util;
use FileUtils;
use gsprintf 'gsprintf';

# mapping from old plugin names to new ones for backwards compatibility
# can remove at sometime in future when we no longer want to support old xxPlug names in the config file
my $plugin_name_map = {
    'GAPlug' => 'GreenstoneXMLPlugin',
    'ArcPlug' => 'ArchivesInfPlugin',
    'RecPlug' => 'DirectoryPlugin',
    'TEXTPlug' => 'TextPlugin',
    'XMLPlug' => 'ReadXMLFile',
    'EMAILPlug' => 'EmailPlugin',
    'SRCPlug' => 'SourceCodePlugin',
    'NULPlug' => 'NulPlugin',
    'W3ImgPlug' => 'HTMLImagePlugin',
    'PagedImgPlug' => 'PagedImagePlugin',
    'METSPlug' => 'GreenstoneMETSPlugin',
    'PPTPlug' => 'PowerPointPlugin',
    'PSPlug' => 'PostScriptPlugin',
    'DBPlug' => 'DatabasePlugin'
    };

# global variables
my $stats = {'num_processed' => 0,
	     'num_blocked' => 0,
	     'num_not_processed' => 0,
	     'num_not_recognised' => 0,
	     'num_archives' => 0
	     };

#globaloptions contains any options that should be passed to all plugins
my ($verbosity, $outhandle, $failhandle, $globaloptions);

sub get_valid_pluginname {
    my ($pluginname) = @_;
    my $valid_name = $pluginname;
    if (defined $plugin_name_map->{$pluginname}) {
	$valid_name = $plugin_name_map->{$pluginname};
    } elsif ($pluginname =~ /Plug$/) {
	$valid_name =~ s/Plug/Plugin/;
	
    }
    return $valid_name;
}

sub load_plugin_require
{
    my ($pluginname) = @_;

    my @check_list = ();

    # pp_plugname shorthand for 'perllib' 'plugin' '$pluginname.pm' 
    my $pp_plugname 
	= &FileUtils::filenameConcatenate('perllib', 'plugins', "${pluginname}.pm");
    my $collectdir = $ENV{'GSDLCOLLECTDIR'};

    # find the plugin
    if (defined($ENV{'GSDLCOLLECTION'}))
    {
	my $customplugname 
	    = &FileUtils::filenameConcatenate($collectdir, "custom",$ENV{'GSDLCOLLECTION'},
				  $pp_plugname);
	push(@check_list,$customplugname);
    }

    my $colplugname = &FileUtils::filenameConcatenate($collectdir, $pp_plugname);
    push(@check_list,$colplugname);

    if (defined $ENV{'GSDLEXTS'}) {

	my $ext_prefix = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "ext");

	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {
	    my $extplugname = &FileUtils::filenameConcatenate($ext_prefix, $e, $pp_plugname);
	    push(@check_list,$extplugname);

	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {

	my $ext_prefix = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "ext");

	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {
	    my $extplugname = &FileUtils::filenameConcatenate($ext_prefix, $e, $pp_plugname);
	    push(@check_list,$extplugname);

	}
    }


    my $mainplugname = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, $pp_plugname);
    push(@check_list,$mainplugname);

    my $success=0;
    foreach my $plugname (@check_list) {
	if (&FileUtils::fileExists($plugname)) {
	    # lets add perllib folder to INC
          # check it isn't already there first [jmt12]
	    my ($perllibfolder) = $plugname =~ /^(.*[\/\\]perllib)[\/\\]plugins/;
	    if (&FileUtils::directoryExists($perllibfolder))
            {
              my $found_perllibfolder = 0;
              foreach my $path (@INC)
              {
                if ($path eq $perllibfolder)
                {
                  $found_perllibfolder = 1;
                  last;
                }
              }
              if (!$found_perllibfolder)
              {
		unshift (@INC, $perllibfolder);
              }
	    }
	    require $plugname;
	    $success=1;
	    last;
	}
    }

    if (!$success) {
	&gsprintf(STDERR, "{plugin.could_not_find_plugin}\n",
		  $pluginname);
	die "\n";
    }
}

sub load_plugin_for_info {
    my ($pluginname, $gs_version) = (@_);
    $pluginname = &get_valid_pluginname($pluginname);
    load_plugin_require($pluginname);

    # create a plugin object
    my ($plugobj);
    my $options = "-gsdlinfo,-gs_version,$gs_version";
    
    eval ("\$plugobj = new \$pluginname([],[$options])");
    die "$@" if $@;

    return $plugobj;
}

sub load_plugins {
    my ($plugin_list) = shift @_;
    my ($incremental_mode, $gs_version);
    ($verbosity, $outhandle, $failhandle, $globaloptions, $incremental_mode, $gs_version) = @_; # globals
    my @plugin_objects = ();
    $verbosity = 2 unless defined $verbosity;
    $outhandle = 'STDERR' unless defined $outhandle;
    $failhandle = 'STDERR' unless defined $failhandle;

    # before pushing collection perl and plugin directories onto INC, test that
    # they aren't already there [jmt12]
    &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},'perllib'));
    &util::augmentINC(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},'perllib','plugins'));

    map { $_ = "\"$_\""; } @$globaloptions;
    my $globals = join (",", @$globaloptions);

    foreach my $pluginoptions (@$plugin_list) {
	my $pluginname = shift @$pluginoptions;
	next unless defined $pluginname;
	$pluginname = &get_valid_pluginname($pluginname);
	load_plugin_require($pluginname);

	# create a plugin object
	my ($plugobj);
	# put quotes around each option to the plugin, unless the option is already quoted
	map { $_ = "\"$_\"" unless ($_ =~ m/^\s*\".*\"\s*$/) ; } @$pluginoptions;
	my $options = "-gs_version,$gs_version,".join (",", @$pluginoptions);
	if ($globals) {
	    if (@$pluginoptions) {
		$options .= ",";
	    }
	    $options .= "$globals";
	}
	# need to escape backslash before putting in to the eval
	# but watch out for any \" (which shouldn't be further escaped)
	$options =~ s/\\([^"])/\\\\$1/g; #"
	$options =~ s/\$/\\\$/g;

	eval ("\$plugobj = new \$pluginname([],[$options])");
	die "$@" if $@;
	
	# initialize plugin
	$plugobj->init($verbosity, $outhandle, $failhandle);
	
	$plugobj->set_incremental($incremental_mode);

	# add this object to the list
	push (@plugin_objects, $plugobj);
    }

    return \@plugin_objects;
}


sub begin {
    my ($pluginfo, $base_dir, $processor, $maxdocs, $gli) = @_;

    map { $_->{'gli'} = $gli; } @$pluginfo;
    map { $_->begin($pluginfo, $base_dir, $processor, $maxdocs); } @$pluginfo;
}

 sub remove_all {
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    map { $_->remove_all($pluginfo, $base_dir, $processor, $maxdocs); } @$pluginfo;
}
  
sub remove_some {
    my ($pluginfo, $infodbtype, $archivedir, $deleted_files) = @_;
    return if (scalar(@$deleted_files)==0);
    $infodbtype = "gdbm" if $infodbtype eq "gdbm-txtgz";
    my $arcinfo_src_filename = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-src", $archivedir);

    foreach my $file (@$deleted_files) {
	# use 'archiveinf-src' info database to look up all the OIDs
	# that this file is used in (note in most cases, it's just one OID)
	
	my $file_with_placeholders = &util::abspath_to_placeholders($file);
	my $src_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_src_filename, $file_with_placeholders);
	my $oids = $src_rec->{'oid'};
	my $rv;
	foreach my $plugobj (@$pluginfo) {

	    $rv = $plugobj->remove_one($file, $oids, $archivedir);
	    if (defined $rv && $rv != -1) {
		return $rv;
	    } # else undefined (was not recognised by the plugin) or there was an error, try the next one
	}
	return 0;
    }

}
sub file_block_read {
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;


    $gli = 0 unless defined $gli;

    my $rv = 0;
    my $glifile = $file;
    
    $glifile =~ s/^[\/\\]+//; # file sometimes starts with a / so get rid of it
    
    # Announce to GLI that we are handling a file
    print STDERR "<File n='$glifile'>\n" if $gli;
    
    # the .kill file is a handy (if not very elegant) way of aborting 
    # an import.pl or buildcol.pl process
    if (&FileUtils::fileExists(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, ".kill"))) {
	gsprintf($outhandle, "{plugin.kill_file}\n");
	die "\n";
    }
    
    foreach my $plugobj (@$pluginfo) {

      	$rv = $plugobj->file_block_read($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli); 
	#last if (defined $rv && $rv==1); # stop this file once we have found something to 'process' it
    }
    
}


sub metadata_read {
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile, 
	$processor, $gli, $aux) = @_;

    $gli = 0 unless defined $gli;

    my $rv = 0;
    my $glifile = $file;
    
    $glifile =~ s/^[\/\\]+//; # file sometimes starts with a / so get rid of it
    
    # Announce to GLI that we are handling a file
    print STDERR "<File n='$glifile'>\n" if $gli;
    
    # the .kill file is a handy (if not very elegant) way of aborting 
    # an import.pl or buildcol.pl process
    if (&FileUtils::fileExists(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, ".kill"))) {
	gsprintf($outhandle, "{plugin.kill_file}\n");
	die "\n";
    }

    my $had_error = 0;
    # pass this file by each of the plugins in turn until one
    # is found which will process it
    # read must return:
    # undef - could not recognise
    # -1 - tried but error
    # 0 - blocked
    # anything else for successful processing
	
    foreach my $plugobj (@$pluginfo) {

	$rv = $plugobj->metadata_read($pluginfo, $base_dir, $file, $block_hash,
			     $extrametakeys, $extrametadata, $extrametafile,
			     $processor, $gli, $aux);

	if (defined $rv) {
	    if ($rv == -1) {
	        # an error has occurred
		$had_error = 1;
		print STDERR "<ProcessingError n='$glifile'>\n" if $gli;
	    } else {
        	return $rv;
	    }
	} # else undefined - was not recognised by the plugin
    }

    return 0;
}

sub read {
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli, $aux) = @_;

    $maxdocs = -1 unless defined $maxdocs && $maxdocs =~ /\d/;
    $total_count = 0 unless defined $total_count && $total_count =~ /\d/;
    $gli = 0 unless defined $gli;

    my $rv = 0;
    my $glifile = $file;
    
    $glifile =~ s/^[\/\\]+//; # file sometimes starts with a / so get rid of it
    
    # Announce to GLI that we are handling a file
    print STDERR "<File n='$glifile'>\n" if $gli;
    
    # the .kill file is a handy (if not very elegant) way of aborting 
    # an import.pl or buildcol.pl process
    if (&FileUtils::fileExists(&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, ".kill"))) {
	gsprintf($outhandle, "{plugin.kill_file}\n");
	die "\n";
    }

    my $had_error = 0;
    # pass this file by each of the plugins in turn until one
    # is found which will process it
    # read must return:
    # undef - could not recognise
    # -1 - tried but error
    # 0 - blocked
    # anything else for successful processing
	
    foreach my $plugobj (@$pluginfo) {

      	$rv = $plugobj->read($pluginfo, $base_dir, $file, 
			     $block_hash, $metadata, $processor, $maxdocs, 
			     $total_count, $gli, $aux);

	if (defined $rv) {
	    if ($rv == -1) {
	        # an error has occurred
		$had_error = 1;
	    } else {
        	return $rv;
	    }
	} # else undefined - was not recognised by the plugin
    }

    if ($had_error) {
	# was recognised but couldn't be processed
	if ($verbosity >= 2) {
	    gsprintf($outhandle, "{plugin.no_plugin_could_process}\n", $file);
	}
	# tell the GLI that it was not processed
	print STDERR "<NonProcessedFile n='$glifile'>\n" if $gli;
      
	gsprintf($failhandle, "$file: {plugin.no_plugin_could_process_this_file}\n");
	$stats->{'num_not_processed'} ++;
    } else {
	# was not recognised
	if ($verbosity >= 2) {
	    gsprintf($outhandle, "{plugin.no_plugin_could_recognise}\n",$file);
	}
	# tell the GLI that it was not processed
	print STDERR "<NonRecognisedFile n='$glifile'>\n" if $gli;
	
	gsprintf($failhandle, "$file: {plugin.no_plugin_could_recognise_this_file}\n");
	$stats->{'num_not_recognised'} ++;
    }
    return 0;
}

# write out some general stats that the plugins have compiled - note that
# the buildcol.pl process doesn't currently call this process so the stats
# are only output after import.pl -
sub write_stats {
    my ($pluginfo, $statshandle, $faillog, $gli) = @_;

    $gli = 0 unless defined $gli;

    foreach my $plugobj (@$pluginfo) {
	$plugobj->compile_stats($stats);
    }

    my $total = $stats->{'num_processed'} + $stats->{'num_blocked'} + 
	$stats->{'num_not_processed'} + $stats->{'num_not_recognised'};

    print STDERR "<ImportComplete considered='$total' processed='$stats->{'num_processed'}' blocked='$stats->{'num_blocked'}' ignored='$stats->{'num_not_recognised'}' failed='$stats->{'num_not_processed'}'>\n" if $gli;

    if ($total == 1) {
	gsprintf($statshandle, "* {plugin.one_considered}\n");
    } else {
	gsprintf($statshandle, "* {plugin.n_considered}\n", $total);
    }
    if ($stats->{'num_archives'}) {
	if ($stats->{'num_archives'} == 1) {
	    gsprintf($statshandle, "   ({plugin.including_archive})\n");
	}
	else {
	    gsprintf($statshandle, "   ({plugin.including_archives})\n",
		     $stats->{'num_archives'});
	}
    }
    if ($stats->{'num_processed'} == 1) {
	gsprintf($statshandle, "* {plugin.one_included}\n");
    } else {
	gsprintf($statshandle, "* {plugin.n_included}\n", $stats->{'num_processed'});
    }
    if ($stats->{'num_not_recognised'}) {
	if ($stats->{'num_not_recognised'} == 1) {
	    gsprintf($statshandle, "* {plugin.one_unrecognised}\n");
	} else {
	    gsprintf($statshandle, "* {plugin.n_unrecognised}\n",
		     $stats->{'num_not_recognised'});
	}

    }
    if ($stats->{'num_not_processed'}) {
	if ($stats->{'num_not_processed'} == 1) {
	    gsprintf($statshandle, "* {plugin.one_rejected}\n");
	} else {
	    gsprintf($statshandle, "* {plugin.n_rejected}\n",
		     $stats->{'num_not_processed'});
	}
    }
    if ($stats->{'num_not_processed'} || $stats->{'num_not_recognised'}) {
	gsprintf($statshandle, " {plugin.see_faillog}\n", $faillog);
    }
}

sub end {
    my ($pluginfo, $processor) = @_;
    map { $_->end($processor); } @$pluginfo;
}

sub deinit {
    my ($pluginfo, $processor) = @_;
   

    map { $_->deinit($processor); } @$pluginfo;
}

1;
