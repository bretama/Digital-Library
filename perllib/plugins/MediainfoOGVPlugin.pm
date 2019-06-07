###########################################################################
#
# MediainfoOGVPlugin.pm -- Plugin for OGV multimedia files
#
# A component of the Greenstone digital library software from the New
# Zealand Digital Library Project at the University of Waikato, New
# Zealand.
#
# Copyright (C) 2010 Arnaud Yvan
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

# MediainfoOGVPlugin - a plugin for OGV multimedia files
# contributed to Greenstone by Arnaud Yvan

# This is a simple Plugin for importing OGV multimedia files.
# Mediainfo will retrieve the metadata of the file. A fictional document will
# be created for every such file, and the file itself will be passed
# to Greenstone as the "associated file" of the document.

# Here's an example where it is useful: I have a collection of
# ogg movie files with names like conference_20080402.ogv.
# I add this line to the collection configuration file:

# plugin MediainfoOGVPlugin -process_exp "*.ogv" -assoc_field "movie"

# A document is created for each movie, with the associated movie
# file's name in the "movie" metadata field.

# The plugin also add some metadata :
# Duration (in seconds), filesize, title, artist, location, organization,
# date, contact, copyright.



package MediainfoOGVPlugin;

use BaseImporter;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
no strict 'subs';

sub BEGIN {
    @MediainfoOGVPlugin::ISA = ('BaseImporter');
}

my $arguments  =  
    [ { 'name' => "process_exp",
        'desc' => "{BaseImporter.process_exp}",
        'type' => "regexp",
        'deft' => &get_default_process_exp(),
        'reqd' => "no" },
      { 'name' => "assoc_field",
	'desc' => "{MediainfoOGVPlugin.assoc_field}",
	'type' => "string",
	'deft' => "Movie",
	'reqd' => "no" },
      ];

my $options = { 'name'     => "MediainfoOGVPlugin",
		'desc'     => "{MediainfoOGVPlugin.desc}",
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

sub init {
    my $self = shift(@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    $self->BaseImporter::init($verbosity, $outhandle, $failhandle);   

    # Check that Mediainfo is installed and available on the path (except for Windows 95/98)
    if (!($ENV{'GSDLOS'} eq "windows" && !Win32::IsWinNT())) {
	my $result = `mediainfo 2>&1`;
	if ($? == -1 || $? == 256) {  # Linux and Windows return different values for "program not found"
	    $self->{'mediainfo_not_installed'} = 1;
	}
    }

}
sub get_default_process_exp {
    return q^(?i)\.ogv$^;
}

# MediainfoOGVPlugin processing of doc_obj.

sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    #print STDERR "\n\n**** START of processing MediainfoOGVPlugin\n\n";

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    # check the filename is okay - do we need this??
    if ($filename_full_path eq "" || $filename_no_path eq "") {
        print $outhandle "MediainfoOGVPlugin: couldn't process \"$filename_no_path\"\n";
        return undef;
    }

    # Add the file as an associated file ...
    my $section = $doc_obj->get_top_section();
    my $file_format = "ogv";
    my $mime_type = "video/ogg";
    my $assoc_field = $self->{'assoc_field'};

    # The assocfilename is the url-encoded version of the utf8 filename
    my $assoc_file = $doc_obj->get_assocfile_from_sourcefile();

    $doc_obj->associate_file($filename_full_path, $assoc_file, $mime_type, $section);
    $doc_obj->add_metadata ($section, "FileFormat", $file_format);
    $doc_obj->add_metadata ($section, "dc.Format", $file_format);
    $doc_obj->add_metadata ($section, "MimeType", $mime_type);
    $doc_obj->add_utf8_metadata ($section, $assoc_field, $doc_obj->get_source()); # Source metadata is already in utf8

    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($section, "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($section, "srclinkFile", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ($section, "srcicon", "_iconogg_");

    # we have no text - add dummy text and NoText metadata
    $self->add_dummy_text($doc_obj, $section);

    if (defined $self->{'mediainfo_not_installed'}) {
	# can't do any extracted
	print STDERR "Mediainfo not installed, so can't extract metadata\n";
	return 1;
    }

    
    # Retrieve the file metadata
    my $command = "mediainfo --inform=\"General;%Duration/String2%|%Duration%|%FileSize/String2%|%Performer%|%Title%|%Recorded_Date%|%Recorded/Location%|%Producer%|%Copyright%|%LICENSE%|%Publisher%\" \"$filename_full_path\"";
    print $outhandle "$command\n" if ($verbosity > 2);
    
    # execute the mediainfo command and store the output of execution in $videodata
    # my $video_metadata = `$command`; # backticks operator way
    # Another way to execute the command: better experience with this than with backticks operator above:
    # use open() to read the output of executing the command (which is piped through to a handle using the | operator)
    my $video_metadata;
    if (open(VMIN,"$command|")) {
        my $line;
	
	# we read a line of output at a time
        while (defined ($line=<VMIN>)) {
	    #print STDERR "***** line = $line\n";
	    
	    $video_metadata .= $line;
        }
	
        close(VMIN);
    }
    
    print $outhandle "$video_metadata\n" if ($verbosity > 2);

    # There are 10 fields separated by |, split these into ordered, individual-named variables
    my ($FormattedDuration,$Duration,$Filesize,$Artist,$Title,$Date,$Location,$Organization,$Copyright,$License,$Contact) = split(/\|/,$video_metadata);
    $Duration = int($Duration/1000);
    $Artist =~ s/\\047/\'/g; # Perl's way of doing: $artist = `echo $artist | sed \"s/\\047/'/g\"`;
    $Title =~ s/\\047/\'/g; # $title = `echo $title | sed \"s/\\047/'/g\"`;

    print $outhandle "RESULT = $FormattedDuration\n$Duration\n$Filesize\n$Artist\n$Title\n$Date\n$Location\n$Organization\n$Copyright\n$License\n$Contact\n" if ($verbosity > 2);
    
 
    $doc_obj->add_metadata ($section, "FormattedDuration", $FormattedDuration);
    $doc_obj->add_metadata ($section, "Duration", $Duration);
 

    $doc_obj->add_metadata($section,"FileSize",$Filesize);
    $doc_obj->add_utf8_metadata($section,"dc.Creator",$Artist);
    $doc_obj->add_utf8_metadata($section,"Artist",$Artist);
    $doc_obj->add_utf8_metadata($section,"dc.Title",$Title);
    $doc_obj->add_utf8_metadata($section,"Title",$Title);
    $doc_obj->add_utf8_metadata($section,"dc.Date",$Date);
    $doc_obj->add_utf8_metadata($section,"Date",$Date);
    $doc_obj->add_utf8_metadata($section,"dc.Coverage",$Location);
    $doc_obj->add_utf8_metadata($section,"Location",$Location);
    $doc_obj->add_utf8_metadata($section,"dc.Publisher",$Organization);
    $doc_obj->add_utf8_metadata($section,"Organization",$Organization);
    $doc_obj->add_utf8_metadata($section,"dc.Rights",$Copyright);
    $doc_obj->add_utf8_metadata($section,"Copyright",$Copyright);
    $doc_obj->add_utf8_metadata($section,"dc.accessRights",$License);
    $doc_obj->add_utf8_metadata($section,"License",$License);
    $doc_obj->add_utf8_metadata($section,"dc.Contributor",$Contact);
    $doc_obj->add_utf8_metadata($section,"Contact",$Contact);
 

    #print STDERR "\n\n**** END of MediainfoOGVPlugin\n\n";
    
    return 1;
}


1;











