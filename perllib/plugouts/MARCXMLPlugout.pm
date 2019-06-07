###########################################################################
#
# MARCXMLPlugout.pm -- the plugout module for MARC xml recored
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

package MARCXMLPlugout;

use strict;
no strict 'refs';
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

eval {require bytes};
use util;
use FileUtils;
use BasePlugout;
use docprint; # for escape_text


sub BEGIN {
    @MARCXMLPlugout::ISA = ('BasePlugout');
}

my $arguments = [
		 { 'name' => "group", 
		   'desc' => "{MARCXMLPlugout.group}",
		   'type' => "flag",
		   'reqd' => "no",    
		   'hiddengli' => "no"},
		 { 'name' => "mapping_file", 
		   'desc' => "{MARCXMLPlugout.mapping_file}",
		   'type' => "string",
		   'deft' => "dc2marc-mapping.xml",
		   'reqd' => "no",    
		   'hiddengli' => "no"},
		 { 'name' => "xslt_file", 
		   'desc' => "{BasPlugout.xslt_file}",
		   'type' => "string",
		   'reqd' => "no",
		   'deft' => "dc2marc.xsl",
		   'hiddengli' => "no"}

                ];

my $options = { 'name'     => "MARCXMLPlugout",
		'desc'     => "{MARCXMLPlugout.desc}",
		'abstract' => "no",
		'inherits' => "yes",
	        'args'     => $arguments
                };

sub new {
    my ($class) = shift (@_);
    my ($plugoutlist, $inputargs,$hashArgOptLists) = @_;
    push(@$plugoutlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BasePlugout($plugoutlist,$inputargs,$hashArgOptLists);

    $self->{'buffered_output'} ="";
     
    # xslt_file is checked in BasePlugout
    # check the mapping file here
    my $full_path_to_mapping_file = &util::locate_config_file($self->{'mapping_file'});
    if (! defined $full_path_to_mapping_file) {
	print STDERR "Can not find mapping file $self->{'mapping_file'}, please make sure you have supplied the correct file path or put the file into the collection's etc or greenstone's etc folder\n";
	die "\n";
    }
    $self->{'mapping_file'} = $full_path_to_mapping_file;

    return bless $self, $class;
}

sub begin {

    my $self= shift (@_);
    if ($self->{'group'}) {
	# all output goes into this file
	my $output_dir = $self->get_output_dir();
	&FileUtils::makeAllDirectories ($output_dir) unless -e $output_dir;

	$self->{'short_doc_file'} = "marc.xml";
    }
}
# override BasePlugout process
sub process {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $output_info = $self->{'output_info'};
    return if (!defined $output_info);

    $self->process_metafiles_metadata ($doc_obj);  
    
    if ($self->{'group'}){
        $self->{buffered_output} .= $self->get_top_metadata_list($doc_obj)."\n"; 
    }
    else {
	# find out which directory to save to
	my $doc_dir = $self->get_doc_dir($doc_obj);
	my $output_file = &FileUtils::filenameConcatenate ($self->get_output_dir(), $doc_dir, "marc.xml");	  
	$self->open_xslt_pipe($output_file,$self->{'xslt_file'});
	
	my $outhandler = $self->{'xslt_writer'}; 
	$self->output_xml_header($outhandler, "MARCXML", 1);
	print $outhandler $self->get_top_metadata_list($doc_obj);
	$self->output_xml_footer($outhandler,"MARCXML");  
	$self->close_xslt_pipe(); 
	$self->{'short_doc_file'} = &FileUtils::filenameConcatenate ($doc_dir, "marc.xml");  
    }


     # write out data to archiveinf-doc.db
    if ($self->{'generate_databases'}) {
	$self->store_output_info_reference($doc_obj);    
	$self->archiveinf_db($doc_obj); 
    }
    if ($self->{'group'}){
  	$self->{'gs_count'}++; 
	$self->{'group_position'}++;
    }
}


# returns a xml element of the form <MetadataList><Metadata name="metadata-name">metadata_value</Metadata>...</MetadataList>

sub get_top_metadata_list {

    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    my @topmetadata =$doc_obj->get_all_metadata($doc_obj->get_top_section());
    my $metadatalist ='<MetadataList>';
    
    foreach my $i (@topmetadata){
	foreach my $j (@$i){	
	    my %metaMap = @$j;
	    foreach my $key (keys %metaMap){
		$metadatalist .='<Metadata name='."\"$key\"".'>'.&docprint::escape_text($metaMap{$key}).'</Metadata>'."\n";
	    }        
	}    
    }
    
    $metadatalist .='</MetadataList>';   
    return $metadatalist;
}


sub close_group_output{
    my $self = shift (@_);
    
    return unless $self->{'group'} and  $self->{buffered_output};

    my $output_file = &FileUtils::filenameConcatenate($self->get_output_dir(), $self->{'short_doc_file'});

    $self->open_xslt_pipe($output_file,$self->{'xslt_file'});

    my $outhandler = $self->{'xslt_writer'}; 

    $self->output_xml_header($outhandler, "MARCXML", 1);
    print $outhandler $self->{buffered_output};
    $self->output_xml_footer($outhandler,"MARCXML");  
    $self->close_xslt_pipe();    
}


sub is_group{
     my $self = shift (@_);
     return $self->{'group'}; 
}


1;
