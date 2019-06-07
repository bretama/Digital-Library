###########################################################################
#
# GreenstoneMETSPlugin.pm
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

# Processes GreenstoneArchive METS documents. Note that this plugin does no
# syntax checking (though the XML::Parser module tests for
# well-formedness). It's assumed that the GreenstoneArchive files conform
# to their DTD.


package GreenstoneMETSPlugin;

use Encode;
use ghtml;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use ReadXMLFile;
use XML::XPath;
use XML::XPath::XMLParser;

sub BEGIN {
    @GreenstoneMETSPlugin::ISA = ('ReadXMLFile');
}

my $arguments = [ { 'name' => "process_exp",
		    'desc' => "{BaseImporter.process_exp}",
		    'type' => "regexp",
		    'reqd' => "no",
		    'deft' => &get_default_process_exp()
		    }
		  ];

my $options = { 'name'     => "GreenstoneMETSPlugin",
		'desc'     => "{GreenstoneMETSPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };
 


sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)docmets\.xml$^;
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    # have no args - do we still want this?
    #push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'section'} = "";
    $self->{'section_level'} = 0;
    $self->{'metadata_name'} = "";
    $self->{'metadata_value'} = "";
    $self->{'content'} = "";

    return bless $self, $class;
}

sub xml_start_document {
    my $self = shift (@_);
    my ($expat, $element) =  @_;

    $self->{'section'} = "";
    $self->{'section_level'} = 0;
    $self->{'metadata_name'} = "";
    $self->{'metadata_value'} = "";
    $self->{'content'} = "";

    #**defined a dmdSection Table
    $self->{'dmdSec_table'}={};

    #**defined a fileSection Table
    $self->{'fileSec_table'}={};

    #***open doctxt.xml and read the data in 
    my $filename = $self->{'filename'};
    
    $filename =~ s/docmets.xml$/doctxt.xml/;
   
    if (!open (FILEIN, "<:utf8", $filename)) {
   	print STDERR "Warning: unable to open the $filename\n";
	$self->{'xmltxt'} = "";
    }
    else {
	my $xml_text = "";
	while (defined (my $line = <FILEIN>)) {
	    if ($line !~ m/^<!DOCTYPE.*>/) {
		$xml_text .= $line;
	    }
	}

        my $xml_parser = XML::XPath->new (xml=> $xml_text);
	#my $xml_tree = $xml_parser->parse ($xml_text);

	#eval {$self->{'parser_text'}->parse};
	$self->{'parsed_xml'} = $xml_parser;
    }
    my $outhandle = $self->{'outhandle'};
    print $outhandle "GreenstoneMETSPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;
    print STDERR "<Processing n='$self->{'file'}' p='GreenstoneMETSPlugin'>\n" if ($self->{'gli'});

}

sub xml_end_document {
}

sub xml_doctype {
}

sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    $self->{'element'} = $element;
    #**deal with dmdSection
    if ($element =~ /^(mets:)?dmdSec$/ || $element =~ /(gsdl3:)?Metadata$/){ 
	$self->xml_dmd_start_tag (@_);
    } elsif ($element =~ /^(mets:)?file$/) {
	# only store the file_id for sections with text. Not for default ids (assoc files)
	if ($_{'ID'} =~ m/FILE(.*)/) {
	    $self->{'file_Id'} = $1;
	}
	else {
	    undef $self->{'file_Id'};
	}
    } elsif ($element =~ /^(mets:)?FLocat$/){
	#***deal with fileSection
	$self->xml_fileloc_start_tag (@_);
    } elsif ($element =~ /^(mets:)?div$/){
	#***deal with StrucMap Section
	$self->xml_strucMap_start_tag (@_);
    }
}

sub xml_dmd_start_tag {
    my $self = shift (@_);
    my ($expat, $element) = @_;

    if ($element =~ /^(mets:)?dmdSec$/){
  	my ($section_num) = ($_{'ID'} =~ m/DM(.*)/);
	$self->{'dmdSec_table'}->{"$section_num"}=[];
	$self->{'dmdSec_table'}->{'section_num'}=$section_num;
    } elsif ($element =~ /^(gsdl3:)?Metadata$/) {
	$self->{'metadata_name'} = $_{'name'};
    }
}

sub xml_fileloc_start_tag {
    my $self = shift (@_);
    my ($expat, $element) = @_;

    my $xlink = $_{'xlink:href'};
    if (!defined $xlink) {
	# try without namespace
	$xlink = $_{'href'};
    }
    #my ($section_num) = ($_{'ID'} =~ m/^FLOCAT(.*)$/);
    my $section_num = $self->{'file_Id'};
    return if (!defined $section_num); 

    $self->{'fileSec_table'}->{"$section_num"}=[];
    $self->{'fileSec_table'}->{'section_num'}=$section_num;
    
    my ($filename,$xpath_expr)=($xlink =~ m/^file:(.*)\#xpointer\((.*)\)$/);
    my $nodeset = $self->{'parsed_xml'}->findnodes ($xpath_expr);
    my $node_size= $nodeset->size;
    
    if ($node_size==0) {
	print STDERR "Warning: no text associated with XPATH $xpath_expr\n";
    }
    else {
	foreach my $node ($nodeset->get_nodelist) {
	    my $xml_content = XML::XPath::XMLParser::as_string($node);
	    my $unescaped_xml_content = &ghtml::unescape_html($xml_content);
	    my $section_content={'section_content'=> $unescaped_xml_content};
	    
	    my $content_list = $self->{'fileSec_table'}->{"$section_num"};
	    push (@$content_list, $section_content);
	}
    }
}

sub xml_strucMap_start_tag {
    my $self = shift (@_);
    my ($expat, $element) = @_;


    my ($section_num) = ($_{'ID'} =~ m/DS(.*)/);

    if ($_{'ID'} ne "DSAll"){
	if ($self->{'section_level'}==0) {
	    $self->open_document();
	} else {
	    my $doc_obj = $self->{'doc_obj'};
	    $self->{'section'}=
		$doc_obj->insert_section($doc_obj->get_end_child($self->{'section'}));
	}
	$self->{'section_level'}++;
	
	#***Add metadata from dmdSection
	my $md_list = $self->{'dmdSec_table'}->{"$section_num"};
	
	foreach my $md_pair (@$md_list){
	    # text read in by XML::Parser is in Perl's binary byte value
	    # form ... need to explicitly make it UTF-8

	    my $metadata_name = decode("utf8",$md_pair->{'metadata_name'});
	    my $metadata_value = decode("utf8",$md_pair->{'metadata_value'});

	    $self->{'doc_obj'}->add_utf8_metadata($self->{'section'}, 
						  $metadata_name, $metadata_value);
	}
	
	#*** Add content from fileSection
	my $content_list = $self->{'fileSec_table'}->{"$section_num"};
	
	foreach my $section_content (@$content_list){
	    # Don't need to decode $content as this has been readin in
	    # through XPath which (unlike XML::Parser) correctly sets
	    # the string to be UTF8 rather than a 'binary' string of bytes
	    my $content = $section_content->{'section_content'};

	    $self->{'doc_obj'}->add_utf8_text($self->{'section'},$content);
	}
    }
}

sub get_doctype {
    my $self = shift(@_);
    
    return "mets:mets";
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    if ($element =~ /^(gsdl3:)?Metadata$/) {
	my $section_num = $self->{'dmdSec_table'}->{'section_num'};
	my $metadata_name=$self->{'metadata_name'};
	my $metadata_value=$self->{'metadata_value'};

	my $md_pair={'metadata_name' => $metadata_name,
		     'metadata_value'=> $metadata_value};

	my $md_list = $self->{'dmdSec_table'}->{"$section_num"};

	push(@$md_list,$md_pair);
      
	$self->{'metadata_name'} = "";
	$self->{'metadata_value'} = "";
    } elsif ($element =~ /^(mets:)?file$/){
	$self->{'file_id'} = "";
    }
    
    
    #*** StrucMap Section
    if ($element =~ /^(mets:)?div$/) {
	$self->{'section_level'}--;
	$self->{'section'} = $self->{'doc_obj'}->get_parent_section($self->{'section'});
	$self->close_document() if $self->{'section_level'}==0;
    }
    $self->{'element'} = "";
}

sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_; 

    if ($self->{'element'} =~ /^(gsdl3:)?Metadata$/) {
   	$self->{'metadata_value'} .= $_;
    }
}

sub open_document {
    my $self = shift(@_);

    # create a new document
    $self->{'doc_obj'} = new doc ();
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
    if (defined ($assoc_filepath)) {
	# make absolute rather than relative...
	$self->{'filename'} =~ m@^(.*[\\/]archives)@;
	$assoc_filepath = "$1/$assoc_filepath/";
    } else {
	$assoc_filepath = $self->{'filename'};
	$assoc_filepath =~ s/[^\\\/]*$//;
    }

    foreach my $assoc_file_info (@$assoc_files) {
	my ($assoc_file, $mime_type, $dir) = split (":", $assoc_file_info);
	my $real_dir = &util::filename_cat($assoc_filepath, $assoc_file),
	my $assoc_dir = (defined $dir && $dir ne "") 
	    ? &util::filename_cat($dir, $assoc_file) : $assoc_file;
	$self->{'doc_obj'}->associate_file($real_dir, $assoc_dir, $mime_type);
    }
    $self->{'doc_obj'}->delete_metadata($self->{'doc_obj'}->get_top_section(), "gsdlassocfile");

    # process the document
    $self->{'processor'}->process($self->{'doc_obj'}, $self->{'file'});
}


1;

