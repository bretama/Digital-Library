###########################################################################
#
# GreenstoneXMLPlugout.pm -- the plugout module for Greenstone Archives
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

package GreenstoneXMLPlugout;

use strict;
no strict 'refs';
no strict 'subs';

eval {require bytes};
use util;
use FileUtils;
use BasePlugout;
use docprint;

sub BEGIN {
    @GreenstoneXMLPlugout::ISA = ('BasePlugout');
}

my $arguments = [
       { 'name' => "group_size", 
	'desc' => "{BasePlugout.group_size}",
	'type' => "int",
        'deft' =>  "1",
	'reqd' => "no",
	'hiddengli' => "no"}
    ];
my $options = { 'name'     => "GreenstoneXMLPlugout",
		'desc'     => "{GreenstoneXMLPlugout.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($plugoutlist, $inputargs,$hashArgOptLists) = @_;
    push(@$plugoutlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BasePlugout($plugoutlist,$inputargs,$hashArgOptLists);
 
    return bless $self, $class;
}

sub is_group {
    my $self = shift (@_);
    return ($self->{'group_size'} > 1); 
}

sub saveas {
    my $self = shift (@_);
    my ($doc_obj, $doc_dir) = @_;
    my $outhandler;
    my $output_file;
    if ($self->{'debug'}) {
	$outhandler = STDOUT;
    }
    else {
	   
	$self->process_assoc_files($doc_obj, $doc_dir, '');
	$self->process_metafiles_metadata ($doc_obj);
	
	# open up the outhandler    
	if ($self->is_group() && !$self->{'new_doc_dir'}) { 
	    # we already have a handle open ??
	    $outhandler = $self->{'group_outhandler'};
	} else {
	    $output_file = &FileUtils::filenameConcatenate($self->{'output_dir'}, $doc_dir, "doc.xml");
	    # open the new handle
	    $self->open_xslt_pipe($output_file, $self->{'xslt_file'});

	    if (defined $self->{'xslt_writer'}){
		$outhandler = $self->{'xslt_writer'};
	    }
	    else{
		$outhandler = $self->get_output_handler($output_file);
	    }
	    
	    if ($self->is_group()) {
		$self->{'group_outhandler'} = $outhandler;
	    }
	}
    } # else not debug
    binmode($outhandler,":utf8");

    # only output the header if we have started a new doc
    if (!$self->is_group() || $self->{'new_doc_dir'}) {
	$self->output_xml_header($outhandler);
    }

    my $section_text = &docprint::get_section_xml($doc_obj,$doc_obj->get_top_section());
    print $outhandler $section_text;
 
    # only output the footer if we are not doing group stuff. The group file will be finished in close_group_output
    if (!$self->is_group()) {
	$self->output_xml_footer($outhandler);
    }

    # close off the output - in a group process situation, this will be done by close_group_output
    if (!$self->is_group() && !$self->{'debug'}) {
	if (defined $self->{'xslt_writer'}){     
	    $self->close_xslt_pipe(); 
	}
	else {
	    &FileUtils::closeFileHandle($output_file, \$outhandler) if defined $output_file;
	}
    }
    $self->{'short_doc_file'} = &FileUtils::filenameConcatenate($doc_dir, "doc.xml");  
    
    $self->store_output_info_reference($doc_obj);
    
}

sub output_xml_header {
    my $self = shift (@_);
    my ($outhandle) = @_;

    print $outhandle '<?xml version="1.0" encoding="utf-8" standalone="no"?>' . "\n";
    print $outhandle "<!DOCTYPE Archive SYSTEM \"http://greenstone.org/dtd/Archive/1.0/Archive.dtd\">\n";
    print $outhandle "<Archive>\n";
}

sub output_xml_footer {
    my $self = shift (@_);
    my ($outhandle) = @_;

    print $outhandle "</Archive>\n";
}

sub close_group_output
{
    my $self = shift(@_);
 
    # make sure that the handle has been opened - it won't be if we failed
    # to import any documents...
    my $outhandle = $self->{'group_outhandler'};
    if (defined(fileno($outhandle))) {
	$self->output_xml_footer($outhandle);    
	&FileUtils::closeFileHandle("", \$outhandle);
	undef $self->{'group_outhandler'}
    }

    my $OID = $self->{'gs_OID'};
    my $short_doc_file = $self->{'short_doc_file'};
   
	### TODO - from here is old code. check that it is still valid.
    if ($self->{'gzip'}) {
	my $doc_file = $self->{'gs_filename'};
	`gzip $doc_file`;
	$doc_file .= ".gz";
	$short_doc_file .= ".gz";
	if (!&FileUtils::fileExists($doc_file)) {
	     my $outhandle = $self->{'output_handle'};
	    print $outhandle "error while gzipping: $doc_file doesn't exist\n";
	    return 0;
	}
    }

    return 1;
}


1;

