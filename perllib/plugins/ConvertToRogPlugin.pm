###########################################################################
#
# ConvertToRogPlugin.pm -- plugin that inherits from RogPlugin
#
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


package ConvertToRogPlugin;

use RogPlugin;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa
use util;
use FileUtils;

sub BEGIN {
    @ConvertToRogPlugin::ISA = ('RogPlugin');
}

my $arguments = [
		 ];
my $options = { 'name'     => "ConvertToRogPlugin",
		'desc'     => "{ConvertToRogPlugin.desc}",
		'abstract' => "yes",
		'inherits' => "yes" };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new RogPlugin($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'convert_to'} = "Rog";
    $self->{'convert_to_ext'} = "rog";

    return bless $self, $class;
}


sub begin {
    my $self = shift (@_);
    
    $self->SUPER::begin(@_);

    $self->{'docnum'} = 0;
}

sub end {
    my ($self) = @_;

    # nothing to do, but keep symmetric with begin function
    $self->SUPER::end(@_);
}


# Run conversion utility on the input file.  
#
# The conversion takes place in a collection specific 'tmp' directory so 
# that we don't accidentally damage the input.
#
# The desired output type is indicated by $output_ext.  This is usually
# something like "html" or "word", but can be "best" (or the empty string)
# to indicate that the conversion utility should do the best it can.

sub tmp_area_convert_file {
    my $self = shift (@_);
    my ($output_ext, $input_filename, $textref) = @_;

    my $outhandle = $self->{'outhandle'};
    my $convert_to = $self->{'convert_to'};
    my $failhandle = $self->{'failhandle'};

    # softlink to collection tmp dir
    my $tmp_dirname 
	= &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);

    # derive tmp filename from input filename
    my ($tailname, $dirname, $suffix)
	= &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    # Remove any white space from filename -- no risk of name collision, and
    # makes later conversion by utils simpler. Leave spaces in path...
    $tailname =~ s/\s+//g;
    $tailname = $self->SUPER::filepath_to_utf8($tailname) unless &unicode::check_is_utf8($tailname);

    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix");

    &FileUtils::softLink($input_filename, $tmp_filename);

    my $verbosity = $self->{'verbosity'};
    if ($verbosity > 0) {
	print $outhandle "Converting $tailname$suffix to $convert_to format\n";
    }

    my $errlog = &FileUtils::filenameConcatenate($tmp_dirname, "err.log");
    
    # Execute the conversion command and get the type of the result,
    # making sure the converter gives us the appropriate output type
    my $output_type = lc($convert_to);
    my $cmd = "\"".&util::get_perl_exec()."\" -S gsMusicConvert.pl -verbose $verbosity -errlog \"$errlog\" -output $output_type \"$tmp_filename\"";
    $output_type = `$cmd`;

    # remove symbolic link to original file
    &FileUtils::removeFiles($tmp_filename);

    # Check STDERR here
    chomp $output_type;
    if ($output_type eq "fail") {
	print $outhandle "Could not convert $tailname$suffix to $convert_to format\n";
	print $failhandle "$tailname$suffix: " . ref($self) . " failed to convert to $convert_to\n";
	$self->{'num_not_processed'} ++;
	if (-s "$errlog") {
	    open(ERRLOG, "$errlog");
	    while (<ERRLOG>) {
		print $outhandle "$_";
	    }
	    print $outhandle "\n";
	    close ERRLOG;
	}
	&FileUtils::removeFiles("$errlog") if (-e "$errlog");
	return "";
    }

    # store the *actual* output type and return the output filename
    # it's possible we requested conversion to html, but only to text succeeded

    $self->{'convert_to_ext'} = $output_type;
    $self->{'converted_to'} = "Rog";

    my $output_filename = $tmp_filename;

    $output_filename =~ s/$suffix$//;

    return $output_filename;
}


# Remove collection specific tmp directory and all its contents.

sub cleanup_tmp_area {
    my $self = shift (@_);

    my $tmp_dirname 
	= &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tmp");
    &FileUtils::removeFilesRecursive($tmp_dirname);
    &FileUtils::makeDirectory($tmp_dirname);
}


# Exact copy of read_rog_record from RogPlugin 
# Needed for FILE in right scope

sub read_rog_record
{
    my ($self,$file_buffer, $docnum, $seclevel) = @_;

    my $next_line = $file_buffer->{'next_line'};

    return 0 if (!defined $next_line);

    if ($next_line eq "")
    {
	my $line;
	while(defined($line=<FILE>))  
	{
	    $line =~ s/\r$//;
	    $file_buffer->{'line_no'}++;
	    next if ($line =~ m/^\#/);
	    $next_line = $line;
	    last;
	}
    }
	    
    if ($next_line !~ m/^song( +)\"([^\"]*)\"( +)\"([^\"]*)\"( +)(\d+)( *)$/) 
    {
	print STDERR "Error: Malformed Rog file: $next_line";
	return 0;
    }
    else
    {
	# init default values
	$file_buffer->{'song'}->{'tempo'}    = 120;
	$file_buffer->{'song'}->{'ks_type'}  = 0;
	$file_buffer->{'song'}->{'ks_num'}   = 0;
	$file_buffer->{'song'}->{'metadata'} = [];
	$file_buffer->{'song'}->{'content'}  = "";
	
	$file_buffer->{'song'}->{'subcol'} = $2;
	$file_buffer->{'song'}->{'title'}  = $4;
	$file_buffer->{'song'}->{'tval'}   = $6;

	chomp($next_line);
	my $content = $next_line;
	if (defined $docnum) 
	{
	    $content.= " $docnum $seclevel";
	}
	$content .= "\n";

	$file_buffer->{'song'}->{'content'} = $content;


	my $line;
	while(defined($line=<FILE>))  
	{
	    $line =~ s/\r$//;

	    $file_buffer->{'line_no'}++;
	    next if ($line =~ m/^\#/);
	
	    if ($line =~ m/^song/) 
	    {	
		$file_buffer->{'next_line'} = $line;
		return 1;
	    }
	    elsif ($line =~ m/^tempo( +)(\d+)( *)$/) 
	    {
		$file_buffer->{'song'}->{'tempo'} = $2;
		$file_buffer->{'song'}->{'content'} .= $line;
	    } 
	    elsif ($line =~ m/^keysig( +)(\d+)( +)(\d+)( *)$/) 
	    {
		$file_buffer->{'song'}->{'ks_type'} = $2;
		$file_buffer->{'song'}->{'ks_num'}  = $4;
		$file_buffer->{'song'}->{'content'} .= $line;	   
	    } 
	    elsif ($line =~ m/^timesig( +)(\d+)( +)(\d+)( *)$/) 
	    {
		$file_buffer->{'song'}->{'ts_numer'} = $2;
		$file_buffer->{'song'}->{'ts_denom'} = $4;
		$file_buffer->{'song'}->{'content'} .= $line;
	    }
	    elsif ($line =~ m/^metadata ([^:]*): (.*)/)
	    {
		push(@{$file_buffer->{'song'}->{'metadata'}},[$1,$2]);
		$file_buffer->{'song'}->{'content'} .= $line;
	    }
	    else
	    {
		$file_buffer->{'song'}->{'content'} .= $line;
	    }
	}
	
	$file_buffer->{'next_line'} = undef;
    }

    return 1;
}

# Override RogPlugin function so rog files are stored as sections (not docs)

sub process_rog_record
{
    my ($self,$doc_obj,$cursection,$song) = @_;

    $cursection = 
	$doc_obj->insert_section($cursection);
    $self->{'docnum'}++;

    my $title = $song->{'title'};
    my $title_safe = $title;
    $title_safe =~ s/\'/\\\\&apos;/g;

    # add metadata 
    $doc_obj->add_metadata($cursection, "Tempo",         $song->{'tempo'}); 
    $doc_obj->add_metadata($cursection, "KeySigType",    $song->{'ks_type'}); 
    $doc_obj->add_metadata($cursection, "KeySigNum",     $song->{'ks_num'}); 
    $doc_obj->add_metadata($cursection, "SubCollection", $song->{'subcol'}); 
    $doc_obj->add_metadata($cursection, "Title",         $title); 
    $doc_obj->add_metadata($cursection, "TitleSafe",     $title_safe); 
    $doc_obj->add_metadata($cursection, "TVal",          $song->{'tval'}); 

    foreach my $md ( @{$song->{'metadata'}} )
    {
	$doc_obj->add_metadata($cursection, $md->[0], $md->[1]); 
    }

    # add contents as text
    $doc_obj->add_text($cursection,$song->{'content'});

    return $cursection;
}



# Override BaseImporter read
# We don't want to get language encoding stuff until after we've converted
# our file to Rog format
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);
 
    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up

    # read in file ($text will be in utf8)
    my $text = "";

    my $output_ext = $self->{'convert_to_ext'};
    my $conv_filename = $self->tmp_area_convert_file($output_ext, $filename_full_path);

    if ("$conv_filename" eq "") {return 0;} # allows continue on errors
    $self->{'conv_filename'} = $conv_filename;


    # create a new document
    #my $doc_obj = new doc ($conv_filename, "indexed_doc");
    # the original filename is used now
    my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});
    # the converted filename is set separately
    $doc_obj->set_converted_filename($conv_filename);

    my $topsection = $doc_obj->get_top_section();
    my $cursection = $topsection;

    $self->{'docnum'}++;
    my $docnum = $self->{'docnum'};

    my ($filemeta) = $file =~ /([^\\\/]+)$/;
	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj, $conv_filename, $filename_encoding);
    
    if ($self->{'cover_image'}) {
	$self->associate_cover_image($doc_obj, $filename_full_path);
    }
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "FileSize", (-s $filename_full_path));

    my $track_no = "1";
    my $rog_filename = "$conv_filename$track_no.$output_ext";
    while (1)
    {
	last unless open (FILE, $rog_filename) ;

	my $file_buffer = { line_no => 0, next_line => "", song => {} };
	
	while ($self->read_rog_record($file_buffer, $docnum, $track_no))
	{
	    my $song = $file_buffer->{'song'};
	    my $content = $song->{'content'};
	    $content =~ s/^song\w+(.*)$/song $1 X.$track_no/;
	    
	    $cursection 
		= $self->process_rog_record($doc_obj,$cursection,
					    $file_buffer->{'song'});
	}

	close FILE;

	$track_no++;
	$rog_filename = "$conv_filename$track_no.$output_ext";
    }

    print STDERR "\n";

    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    $self->extra_metadata ($doc_obj, $doc_obj->get_top_section(), $metadata);
    # do plugin specific processing of doc_obj
    unless (defined ($self->process(\$text, $pluginfo, $base_dir, $file, $metadata, $doc_obj))) {
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1;
    }
    # do any automatic metadata extraction
    $self->auto_extract_metadata ($doc_obj);
    # add an OID
    $self->add_OID($doc_obj);

    my $oid = $doc_obj->get_OID();
    my $appletlink = "<a href=\"javascript:meldexout(\'$oid\','[TitleSafe]')\">";

    $doc_obj->add_utf8_metadata ($topsection, "audiolink",  $appletlink); 
    $doc_obj->add_utf8_metadata ($topsection, "audioicon",  "_iconaudio_"); 
    $doc_obj->add_utf8_metadata ($topsection, "/audiolink", "</a>"); 

    # if no title metadata defined, set it to filename minus extension
    my $existing_title = $doc_obj->get_metadata_element($topsection,"Title");
    if (!defined $existing_title) 
    {
	my $title = $doc_obj->get_metadata_element($topsection,"Source");
	$title =~ s/\..*?$//g;
	$doc_obj->add_utf8_metadata ($topsection, "Title", $title); 

	my $title_safe = $title;
	$title_safe =~ s/\'/\\\\&apos;/g;
	$doc_obj->add_utf8_metadata ($topsection, "TitleSafe", $title_safe); 
    }

    # process the document
    $processor->process($doc_obj);
    $self->cleanup_tmp_area();

    $self->{'num_processed'} ++;

    return 1;
}


# do plugin specific processing of doc_obj for HTML type
sub process_type {
    my $self = shift (@_);
    my ($doc_ext, $textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj) = @_;
    
    my $conv_filename = $self->{'conv_filename'};
    my $tmp_dirname = File::Basename::dirname($conv_filename);
    my $tmp_tailname = File::Basename::basename($conv_filename);
    
    my $converted_to = $self->{'converted_to'};
    my $ret_val = 1;    

#   $ret_val = &RogPlugin::process($self, $textref, $pluginfo,
#				 $tmp_dirname, $tmp_tailname,
#				 $metadata, $doc_obj);

    # associate original file with doc object
    my $cursection = $doc_obj->get_top_section();
    my $filename = &FileUtils::filenameConcatenate($base_dir, $file);
    $doc_obj->associate_file($filename, "doc.$doc_ext", undef, $cursection);

    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ($cursection, "srclink_file", "doc.$doc_ext"); 
    $doc_obj->add_metadata ($cursection, "srclinkFile", "doc.$doc_ext"); 
    $doc_obj->add_utf8_metadata ($cursection, "srcicon",  "_icon".$doc_ext."_"); 

    return $ret_val;
}

1;
