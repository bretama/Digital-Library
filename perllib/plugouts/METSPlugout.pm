###########################################################################
#
# METSPlugout.pm -- the plugout module for METS archives
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

package METSPlugout;

use strict;
no strict 'subs';
no strict 'refs';

use gsprintf 'gsprintf';

eval {require bytes};
use FileUtils;
use BasePlugout;
use docprint; # for escape_text

sub BEGIN {
    @METSPlugout::ISA = ('BasePlugout');
}

my $arguments = [
      { 'name' => "xslt_txt", 
	'desc' => "{METSPlugout.xslt_txt}",
	'type' => "string",
	'reqd' => "no",    
	'hiddengli' => "no"},
      { 'name' => "xslt_mets", 
	'desc' => "{METSPlugout.xslt_mets}",
	'type' => "string",
	'reqd' => "no",    
	'hiddengli' => "no"}
      ];

my $options = { 'name'     => "METSPlugout",
		'desc'     => "{METSPlugout.desc}",
		'abstract' => "yes",
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

    if(defined $self->{'xslt_txt'} &&  $self->{'xslt_txt'} ne "")
    {
	my $full_file_path = &util::locate_config_file($self->{'xslt_txt'});
	if (!defined $full_file_path) {
	    print STDERR "Can not find $self->{'xslt_txt'}, please make sure you have supplied the correct file path or put the file into collection or greenstone etc folder\n";
	    die "\n";
	}
	$self->{'xslt_txt'} = $full_file_path;
    }
    if(defined $self->{'xslt_mets'} &&  $self->{'xslt_mets'} ne "")
    {
	my $full_file_path = &util::locate_config_file($self->{'xslt_mets'});
	if (!defined $full_file_path) {
	    print STDERR "Can not find $self->{'xslt_mets'}, please make sure you have supplied the correct file path or put the file into collection or greenstone etc folder\n";
	    die "\n";
	}
	$self->{'xslt_mets'} = $full_file_path;
    }

    return bless $self, $class;
}


sub saveas_doctxt
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir) = @_;

    my $is_recursive = 1;

    my $doc_txt_file = &FileUtils::filenameConcatenate ($working_dir,"doctxt.xml");	
	
    $self->open_xslt_pipe($doc_txt_file,$self->{'xslt_txt'});

    my $outhandler; 

    if (defined $self->{'xslt_writer'}){
	$outhandler = $self->{'xslt_writer'};
    }
    else{
	$outhandler = $self->get_output_handler($doc_txt_file);
    } 

    binmode($outhandler,":utf8");

    $self->output_xml_header($outhandler);
    my $section = $doc_obj->get_top_section();
    $self->output_txt_section($outhandler,$doc_obj, $section, $is_recursive);
    $self->output_xml_footer($outhandler);
    

    if (defined $self->{'xslt_writer'}){     
	$self->close_xslt_pipe(); 
    }
    else{
	close($outhandler);
    }

}

sub saveas_docmets
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir) = @_;

    my $doc_mets_file = &FileUtils::filenameConcatenate ($working_dir, "docmets.xml");
    
    my $doc_title = $doc_obj->get_metadata_element($doc_obj->get_top_section(),"dc.Title");
    if (!defined $doc_title) {
	$doc_title = $doc_obj->get_metadata_element($doc_obj->get_top_section(),"Title");
    }
 
    $self->open_xslt_pipe($doc_mets_file,$self->{'xslt_mets'});

    my $outhandler; 

    if (defined $self->{'xslt_writer'}){
       $outhandler = $self->{'xslt_writer'};
    }
    else{
       $outhandler = $self->get_output_handler($doc_mets_file);
     }   
       
    binmode($outhandler,":utf8");

    $self->output_mets_xml_header($outhandler, $doc_obj->get_OID(), $doc_title);
    $self->output_mets_section($outhandler, $doc_obj, $doc_obj->get_top_section(),$working_dir);
    $self->output_mets_xml_footer($outhandler);
	
     if (defined $self->{'xslt_writer'}){     
	$self->close_xslt_pipe(); 
    }
    else{
	close($outhandler);
    }
    

}

sub saveas 
{
    my $self = shift (@_);
    my ($doc_obj,$doc_dir) = @_;

    $self->process_assoc_files ($doc_obj, $doc_dir, '');

    $self->process_metafiles_metadata ($doc_obj);

    my $output_dir = $self->get_output_dir();
    &FileUtils::makeAllDirectories ($output_dir) unless -e $output_dir;
 
    my $working_dir = &FileUtils::filenameConcatenate ($output_dir, $doc_dir);              
   
    &FileUtils::makeAllDirectories ($working_dir) unless -e $working_dir;

    ###
    # Save the text as a filefile
    ###
    $self->saveas_doctxt($doc_obj,$working_dir);

    ###
    # Save the structure and metadata as a METS file
    ###
    $self->saveas_docmets($doc_obj,$working_dir);

    $self->{'short_doc_file'} =  &FileUtils::filenameConcatenate ($doc_dir, "docmets.xml");
  
    $self->store_output_info_reference($doc_obj);  

}


sub output_mets_xml_header
{
    my $self = shift(@_);
    my ($handle, $OID, $doc_title) = @_;

    gsprintf(STDERR, "METSPlugout::output_mets_xml_header {common.must_be_implemented}\n") && die "\n";
}

sub output_mets_xml_header_extra_attribute
{
    my $self = shift(@_);
    my ($handle, $extra_attr, $extra_schema) = @_;

    print $handle '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' . "\n";
    print $handle '<mets:mets xmlns:mets="http://www.loc.gov/METS/"' . "\n";
    print $handle '           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' . "\n";
    print $handle '           xmlns:gsdl3="http://www.greenstone.org/namespace/gsdlmetadata/1.0/"' . "\n";
    if (defined ($ENV{'FEDORA_VERSION'}) &&  $ENV{'FEDORA_VERSION'} =~ m/^2/) { # checking if major version is 2
    	print $handle '           xmlns:xlink="http://www.w3.org/TR/xlink"' ."\n";
    }
    else {
	print $handle '           xmlns:xlink="http://www.w3.org/1999/xlink"' ."\n";
    }
    print $handle '           xsi:schemaLocation="http://www.loc.gov/METS/' . "\n";
    print $handle '           http://www.loc.gov/standards/mets/mets.xsd' . "\n";
    print $handle " $extra_schema\n" if (defined $extra_schema);
    print $handle '           http://www.greenstone.org/namespace/gsdlmetadata/1.0/' . "\n";
    print $handle '           http://www.greenstone.org/namespace/gsdlmetadata/1.0/gsdl_metadata.xsd"' . "\n";

    print $handle "  $extra_attr>\n";

}

sub output_mets_xml_footer 
{
    my $self = shift(@_);
    my ($handle) = @_;
    print $handle '</mets:mets>' . "\n";
}

#  print out doctxt.xml file
sub output_txt_section {
    my $self = shift (@_);
    my ($handle, $doc_obj, $section, $is_recursive) = @_;

    print $handle $self->buffer_txt_section_xml($doc_obj, $section, $is_recursive);
}

sub buffer_txt_section_xml {
    my $self = shift(@_);
    my ($doc_obj, $section, $is_recursive) = @_;
 
    my $section_ptr = $doc_obj->_lookup_section ($section);
    
    return "" unless defined $section_ptr;
   
    my $all_text = "<Section>\n";
    $all_text .= &docprint::escape_text("$section_ptr->{'text'}");
   
    if (defined $is_recursive && $is_recursive)
    {
	# Output all the subsections
	foreach my $subsection (@{$section_ptr->{'subsection_order'}}){
	    $all_text .= $self->buffer_txt_section_xml($doc_obj, "$section.$subsection", $is_recursive);
	}
    }

     $all_text .= "</Section>\n";

     
     $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;
     return $all_text;
}

#
#  Print out docmets.xml file
#
sub output_mets_section 
{
    my $self = shift(@_);
    my ($handle, $doc_obj, $section, $working_dir) = @_;

    gsprintf(STDERR, "METSPlugout::output_mets_section {common.must_be_implemented}\n") && die "\n";

}


sub buffer_mets_dmdSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section) = @_;

    gsprintf(STDERR, "METSPlugout::buffer_mets_dmdSection_section_xml {common.must_be_implemented}\n") && die "\n";
}

sub buffer_mets_StructMapSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section, $order_numref, $fileid_base) = @_;

    $section="" unless defined $section;
    
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    $fileid_base = "FILEGROUP_PRELUDE" unless defined $fileid_base;

    # output fileSection by Sections
    my $section_num ="1". $section;
    my $dmd_num = $section_num;

    #**output the StructMap details
 
    my $dmdid_attr = "DM$dmd_num";

    my $all_text = "  <mets:div ID=\"DS$section_num\" TYPE=\"Section\" \n";
    $all_text .= '      ORDER="'.$$order_numref++.'" ORDERLABEL="'. $section_num .'" '."\n";
    $all_text .= "      LABEL=\"$section_num\" DMDID=\"$dmdid_attr\">\n";
   
    $all_text .= '    <mets:fptr FILEID="'.$fileid_base.$section_num.'" />'. "\n";


    foreach my $subsection (@{$section_ptr->{'subsection_order'}}){
       $all_text .= $self->buffer_mets_StructMapSection_section_xml($doc_obj,"$section.$subsection", $order_numref, $fileid_base);
    }
    
    $all_text .= "  </mets:div>\n";

    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}


sub buffer_mets_StructMapWhole_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section) = @_;
    
    my $section_ptr = $doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;
    
    my $all_text="";
    my $fileID=0;
    my $order_num = 0;

    $all_text .= '  <mets:div ID="DSAll" TYPE="Document" ORDER="'.$order_num.'" ORDERLABEL="All" LABEL="Whole Documemt" DMDID="DM1">' . "\n";
  
    #** output the StructMapSection for the whole section
    #  get the sourcefile and associative file

    foreach my $data (@{$section_ptr->{'metadata'}}){
       my $escaped_value = &docprint::escape_text($data->[1]);
   
       if ($data->[0] eq "gsdlsourcefilename") { 
          ++$fileID;
	  $all_text .= '    <mets:fptr FILEID="default.'.$fileID.'" />'."\n";
       }
       
       if ($data->[0] eq "gsdlassocfile"){
          ++$fileID;
	  $all_text .= '    <mets:fptr FILEID="default.'.$fileID. '" />'. "\n";
       }
    }
    $all_text .= "  </mets:div>\n";
    
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;
    
    return $all_text;
}



sub doctxt_to_xlink
{
    my $self = shift @_;
    my ($fname,$working_dir) = @_;

    gsprintf(STDERR, "METSPlugout::doxtxt_to_xlink {common.must_be_implemented}\n") && die "\n";
}

sub buffer_mets_fileSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir, $is_txt_split,$opt_attr,$fileid_base) = @_;

    #$section="" unless defined $section;
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;
 
    $fileid_base = "FILEGROUP_PRELUDE" unless defined $fileid_base;

    # output fileSection by sections
    my $section_num ="1". $section;
 
    $opt_attr = "" unless defined $opt_attr;
     
    # output the fileSection details
    my $all_text = '  <mets:fileGrp ID="'.$fileid_base.$section_num . '">'. "\n";
    $all_text .= "    <mets:file MIMETYPE=\"text/xml\" ID=\"FILE$section_num\" $opt_attr >\n";

    my $xlink;
    if (defined $is_txt_split && $is_txt_split)
    {
	my $section_fnum ="1". $section;
	$section_fnum =~ s/\./_/g;

    	$xlink = $self->doctxt_to_xlink("doctxt$section_fnum.xml",$working_dir);
    }
    else
    {
	$xlink = $self->doctxt_to_xlink("doctxt.xml",$working_dir);

	$xlink .= '#xpointer(/Section[';
    
	my $xpath = "1".$section;
	$xpath =~ s/\./\]\/Section\[/g;
	
	$xlink .=  $xpath;
	
	$xlink .= ']/text())';
    }



    $all_text .= '      <mets:FLocat LOCTYPE="URL" xlink:href="'.$xlink.'"';

    $all_text .= ' xlink:title="Hierarchical Document Structure"/>' . "\n";
    $all_text .= "    </mets:file>\n";
    $all_text .= "  </mets:fileGrp>\n";


    foreach my $subsection (@{$section_ptr->{'subsection_order'}}){
	$all_text .= $self->buffer_mets_fileSection_section_xml($doc_obj,"$section.$subsection",$working_dir, $is_txt_split, $opt_attr, $fileid_base);
    }
    
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}

sub buffer_mets_fileWhole_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir) = @_;

    gsprintf(STDERR, "METSPlugout::buffer_mets_fileWhole_section_xml {common.must_be_implemented}\n") && die "\n";

}

1;
