###########################################################################
#
# RogPlugin.pm -- simple text plugin
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

# creates simple single-level document from .rog or .mdb files 

package RogPlugin;

use BaseImporter;
use MetadataRead;
use sorttools;
use doc; 

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @RogPlugin::ISA = ('MetadataRead', 'BaseImporter');
}

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      ];

my $options = { 'name'     => "RogPlugin",
		'desc'     => "{RogPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args' => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}


# This plugin processes files with the suffix ".mdb" or ".rog"
sub get_default_process_exp {
    return q^(?i)\.(mdb|rog)$^;
}

sub read_rog_record
{
    my ($self,$file_buffer, $seclevel) = @_;

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
	if (defined $seclevel) 
	{
	    $content.= " $seclevel";
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

sub process_rog_record
{
    my ($self,$file,$metadata,$song,$processor) = @_;

    # create a new document
    my $doc_obj = new doc ($file, "indexed_doc", $self->{'file_rename_method'});
    my $cursection = $doc_obj->get_top_section();
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");

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
    $doc_obj->add_metadata($cursection, "FileFormat",    "Rog");
    $doc_obj->add_metadata($cursection, "FileSize",      (-s $file));

    foreach my $md ( @{$song->{'metadata'}} )
    {
	$doc_obj->add_metadata($cursection, $md->[0], $md->[1]); 
    }

    # add contents as text
    $doc_obj->add_text($cursection,$song->{'content'});

    $self->extra_metadata($doc_obj,$cursection, $metadata);
    
    # add OID
    $self->add_OID($doc_obj);

    my $oid = $doc_obj->get_OID();
    my $appletlink = "<a href=\"javascript:meldexout(\'$oid\','[TitleSafe]')\">";

    $doc_obj->add_utf8_metadata ($cursection, "audiolink",  $appletlink); 
    $doc_obj->add_utf8_metadata ($cursection, "audioicon",  "_iconaudio_"); 
    $doc_obj->add_utf8_metadata ($cursection, "/audiolink", "</a>"); 

    # process the document
    $processor->process($doc_obj);
}

# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $filename = &util::filename_cat($base_dir, $file);

    return undef unless ($filename =~ /\.((rog|mdb)(\.gz)?)$/i && (-e $filename));

    my $gz = (defined $3) ? 1: 0;

    print STDERR "<Processing n='$file' p='RogPlugin'>\n" if ($gli);
    print STDERR "RogPlugin: processing $filename\n" if $processor->{'verbosity'};
    
    if ($gz) {
	open (FILE, "zcat $filename |") 
	    || die "RogPlugin::read - zcat can't open $filename\n";
    } else {
	open (FILE, $filename) 
	    || die "RogPlugin::read - can't open $filename\n";
    }

    my $doc_count = 0;
    my $dot_count = 0;
    my $file_buffer = { line_no => 0, next_line => "", song => {} };

    while ($self->read_rog_record($file_buffer))
    {
	$self->process_rog_record($file,$metadata,$file_buffer->{'song'},$processor);
	$doc_count++;

	last if ($maxdocs !=-1 && ($total_count+$doc_count) >= $maxdocs);
	
	if (($doc_count % 10) == 0)
	{
	    print STDERR ".";
	    $dot_count++;
	    print STDERR "\n" if (($dot_count % 80) == 0);
	}
    }

    close FILE;

    print STDERR "\n";

    $self->{'num_processed'} = $doc_count;

    return 1; # processed the file
}

1;











