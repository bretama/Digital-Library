
###########################################################################
#
# GreenstoneXMLPlugin.pm
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2001 New Zealand Digital Library Project
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

# Processes GreenstoneArchive XML documents. Note that this plugin does no
# syntax checking (though the XML::Parser module tests for
# well-formedness). It's assumed that the GreenstoneArchive files conform
# to their DTD.

package GreenstoneXMLPlugin;

use Encode;
use File::Basename;

use ReadXMLFile;
use util;
use FileUtils;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @GreenstoneXMLPlugin::ISA = ('ReadXMLFile');
}




sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)doc(-\d+)?\.xml$^;
}

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" } ];

my $options = { 'name'     => "GreenstoneXMLPlugin",
		'desc'     => "{GreenstoneXMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
	        'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'section'} = "";
    $self->{'section_level'} = 0;
    $self->{'metadata_name'} = "";
    $self->{'metadata_value'} = "";
    $self->{'content'} = "";
    $self->{'metadata_read_store'} = {};

#    # Currently used to store information for previous values controls. In
#    # the next contract I'll move to using information directly from Lucene.
#    $self->{'sqlfh'} = 0;
   
    return bless $self, $class;
}




sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    my $outhandle = $self->{'outhandle'};

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    return undef unless $self->can_process_this_file($filename_full_path);

    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up
    
    print $outhandle "GreenstoneXMLPlugin: setting up block list for $file\n"
	if $self->{'verbosity'} > 1;

    my $line;
    if (open(GIN,"<:utf8",$filename_full_path)) {

	while (defined($line=<GIN>)) {
	    if ($line =~ m@<Metadata\s+name="gsdlassocfile">([^:]*):(?:[^:]*):(?:[^:]*)</Metadata>@) {
		my $gsdl_assoc_file = $1;

		my $dirname = dirname($filename_full_path);
		my $full_gsdl_assoc_filename = &FileUtils::filenameConcatenate($dirname,$gsdl_assoc_file);
		if ($self->{'verbosity'}>2) {
		    print $outhandle "  Storing block list item: $full_gsdl_assoc_filename\n";
		}

		# is this raw filename here, or unicode?? assuming unicode
		# however we have concatenated raw directory???
		$self->block_filename($block_hash,$full_gsdl_assoc_filename);		
	    }
	}

	close(GIN);
    }
    else {
	
	print $outhandle "Error: Failed to open $file in GreenstoneXMLPlugin::metadata_read()\n";
	print $outhandle "       $!\n";
    }


    $self->{'metadata_read_store'}->{$filename_full_path} = 1;

    return 1;
}


sub xml_start_document {

    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    my $outhandle = $self->{'outhandle'};
    print $outhandle "GreenstoneXMLPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;
    print STDERR "<Processing n='$self->{'file'}' p='GreenstoneXMLPlugin'>\n" if $self->{'gli'};

}

sub xml_end_document {
}

sub get_doctype {
    my $self = shift(@_);
    
    return "(Greenstone)?Archive";
}


sub xml_doctype {
    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    # Some doc.xml files that have been manipulated by XML::Rules
    # no longer have the DOCTYPE line.  No obvious way to fix
    # the XML::Rules based code to keep DOCTYPE, so commenting
    # out the code below to allow doc.xml files with DOCTYPE
    # to be processed

    # allow the short-lived and badly named "GreenstoneArchive" files to be processed
    # as well as the "Archive" files which should now be created by import.pl
##    die "" if ($name !~ /^(Greenstone)?Archive$/);

#    my $outhandle = $self->{'outhandle'};
#    print $outhandle "GreenstoneXMLPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;
#    print STDERR "<Processing n='$self->{'file'}' p='GreenstoneXMLPlugin'>\n" if $self->{'gli'};

}


sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    $self->{'element'} = $element;
    if ($element eq "Section") {
	if ($self->{'section_level'} == 0) {
	    $self->open_document();
       	} else {
	    my $doc_obj = $self->{'doc_obj'};
	    $self->{'section'} = 
		$doc_obj->insert_section($doc_obj->get_end_child($self->{'section'}));
	}
	
	$self->{'section_level'} ++;
    }
    elsif ($element eq "Metadata") {
	$self->{'metadata_name'} = $_{'name'};
    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    if ($element eq "Section") {
	$self->{'section_level'} --;
	$self->{'section'} = $self->{'doc_obj'}->get_parent_section ($self->{'section'});
	$self->close_document() if $self->{'section_level'} == 0;
    }
    elsif ($element eq "Metadata") {
	# text read in by XML::Parser is in Perl's binary byte value
	# form ... need to explicitly make it UTF-8


	my $metadata_name = $self->{'metadata_name'};
	my $metadata_value = $self->{'metadata_value'};
	#my $metadata_name = decode("utf-8",$self->{'metadata_name'});
	#my $metadata_value = decode("utf-8",$self->{'metadata_value'});

	$self->{'doc_obj'}->add_utf8_metadata($self->{'section'}, 
					      $metadata_name,$metadata_value);

        # Ensure this value is added to the allvalues database in gseditor.
        # Note that the database constraints prevent multiple occurances of the
        # same key-value pair.
        # We write these out to a file, so they can all be commited in one
        # transaction
        #if (!$self->{'sqlfh'})
        #  {
        #    my $sql_file = $ENV{'GSDLHOME'} . "/collect/lld/tmp/gseditor.sql";
        #    # If the file doesn't already exist, open it and begin a transaction
        #    my $sql_fh;
        #    if (!-e $sql_file)
        #      {
        #        open($sql_fh, ">" . $sql_file);
        #        print $sql_fh "BEGIN TRANSACTION;\n";
        #      }
        #    else
        #      {
        #        open($sql_fh, ">>" . $sql_file);
        #      }
        #    print STDERR "Opened SQL log\n";
        #    $self->{'sqlfh'} = $sql_fh;
        #  }

        #my $mvalue = $self->{'metadata_value'};
        #$mvalue =~ s/\'/\'\'/g;
        #$mvalue =~ s/_claimantsep_/ \& /g;

        #my $fh = $self->{'sqlfh'};
        #if ($fh)
        #  {
        #    print $fh "INSERT INTO allvalues (mkey, mvalue) VALUES ('" . $self->{'metadata_name'} . "', '" . $mvalue . "');\n";
        #  }

        # Clean Up
	$self->{'metadata_name'} = "";
	$self->{'metadata_value'} = "";
    }
    elsif ($element eq "Content" && $self->{'content'} ne "") {

	# text read in by XML::Parser is in Perl's binary byte value
	# form ... need to explicitly make it UTF-8
	#my $content = decode("utf-8",$self->{'content'});
	my $content = $self->{'content'};

	$self->{'doc_obj'}->add_utf8_text($self->{'section'}, $content);
	$self->{'content'} = "";
    }
    $self->{'element'} = "";
}

sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;

    if ($self->{'element'} eq "Metadata") {
	$self->{'metadata_value'} .= $_;
    }
    elsif ($self->{'element'} eq "Content") {
	$self->{'content'} .= $_;
    }
}

sub open_document {
    my $self = shift(@_);

    my $filename = $self->{'filename'};

    # create a new document
    if (defined $self->{'metadata_read_store'}->{$filename}) {
	# Being processed as part of *import* phase 
	# (i.e. was in import directory)
	$self->SUPER::open_document(@_);
	delete $self->{'metadata_read_store'}->{$filename};
    }
    else {
	# Otherwise being processed as part of the *buildcol* phase 
	# (i.e. named directly by ArchiveInf plugin)
	$self->{'doc_obj'} = new doc();
    }

    $self->{'section'} = "";
}

sub close_document {
    my $self = shift(@_);

    # add the associated files
    my $assoc_files = 
	$self->{'doc_obj'}->get_metadata($self->{'doc_obj'}->get_top_section(), "gsdlassocfile");

    # for when "assocfilepath" isn't the same directory that doc.xml is in...
    my $assoc_filepath_list= $self->{'doc_obj'}->get_metadata($self->{'doc_obj'}->get_top_section(), "assocfilepath");

    my $assoc_filepath=shift (@$assoc_filepath_list);

    #rint STDERR "Filename is: " . $self->{'filename'} . "\n";
    #rint STDERR "Initially my assoc_filepath is: $assoc_filepath\n";
    #rint STDERR "Custom archive dir is: " . $self->{'base_dir'} . "\n";
    # Correct the assoc filepath if one is defined
    if (defined ($assoc_filepath))
      {
        # Check whether the assoc_filepath already includes the base dir
        if (index($assoc_filepath, $self->{'base_dir'}) == -1)
          {
            # And if not, append it so as to make this absolute
            $assoc_filepath = &FileUtils::filenameConcatenate($self->{'base_dir'}, $assoc_filepath);
          }
      }
    else
      {
	$assoc_filepath = $self->{'filename'};
	$assoc_filepath =~ s/[^\\\/]*$//;
      }
    #rint STDERR "Goned and made it absolute: $assoc_filepath\n";

    foreach my $assoc_file_info (@$assoc_files) {
	my ($assoc_file, $mime_type, $dir) = split (":", $assoc_file_info);
        #rint STDERR "assoc_file: $assoc_file\n";
        #rint STDERR "mime_type: $mime_type\n";
        #rint STDERR "dir: $dir\n";
	my $real_dir = &FileUtils::filenameConcatenate($assoc_filepath, $assoc_file),
	my $assoc_dir = (defined $dir && $dir ne "") 
	    ? &FileUtils::filenameConcatenate($dir, $assoc_file) : $assoc_file;
	$self->{'doc_obj'}->associate_file($real_dir, $assoc_dir, $mime_type);
        #rint STDERR "According to me the real assoc_filepath is: $real_dir\n";
    }
    $self->{'doc_obj'}->delete_metadata($self->{'doc_obj'}->get_top_section(), "gsdlassocfile");

    # process the document
    $self->{'processor'}->process($self->{'doc_obj'}, $self->{'file'});

    $self->{'num_processed'} ++;
    undef $self->{'doc_obj'};
}


1;


