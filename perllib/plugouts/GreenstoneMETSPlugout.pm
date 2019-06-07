###########################################################################
#
# GreenstoneMETSPlugout.pm -- the plugout module for METS archives
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

package GreenstoneMETSPlugout;

use strict;
no strict 'refs';

#eval {require bytes};
#use util;
use METSPlugout;
#use docprint; # for escape_text

sub BEGIN {
    @GreenstoneMETSPlugout::ISA = ('METSPlugout');
}

my $arguments = [
      ];

my $options = { 'name'     => "GreenstoneMETSPlugout",
		'desc'     => "{GreenstoneMETSPlugout.desc}",
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

    my $self = new METSPlugout($plugoutlist,$inputargs,$hashArgOptLists);
    
    return bless $self, $class;
}


sub output_mets_xml_header
{
    my $self = shift(@_);
    my ($handle, $OID, $doc_title) = @_;

    my $extra_attr = "OBJID=\"$OID:2\"";

    $self->output_mets_xml_header_extra_attribute($handle,$extra_attr);

}

#
#  Print out docmets.xml file
#
sub output_mets_section 
{
    my $self = shift(@_);
    my ($handle, $doc_obj, $section, $working_dir) = @_;

    # print out the dmdSection
    print $handle $self->buffer_mets_dmdSection_section_xml($doc_obj,$section);

    print $handle "<mets:fileSec>\n";

    # print out the fileSection by sections
    print $handle $self->buffer_mets_fileSection_section_xml($doc_obj,$section,$working_dir);

    # print out the whole fileSection
    print $handle $self->buffer_mets_fileWhole_section_xml($doc_obj,$section,$working_dir); 

    print $handle "</mets:fileSec>\n";
  
    # print out the StructMapSection by sections

    my $struct_type = "Section";


    # consider making the following its own subroutine

    print $handle "<mets:structMap ID=\"Section\" TYPE=\"$struct_type\" LABEL=\"Section\">\n";
    my $order_num=0;
    print $handle $self->buffer_mets_StructMapSection_section_xml($doc_obj,$section, \$order_num);
    print $handle "</mets:structMap>\n";
    
    print $handle '<mets:structMap ID="All" TYPE="Whole Document" LABEL="All">'."\n";
    print $handle $self->buffer_mets_StructMapWhole_section_xml($doc_obj,$section);
    print $handle "</mets:structMap>\n";

  
}

sub buffer_mets_dmdSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section) = @_;
   
    $section="" unless defined $section;
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    # convert section number
    my $section_num ="1". $section;
    my $dmd_num = $section_num;

    my $all_text = "";

    my $label_attr = "";
    # TODO::
    #print STDERR "***** Check that GROUPID in dmdSec is valid!!!\n";
    #print STDERR "***** Check to see if <techMD> required\n";
    # if it isn't allowed, go back and set $mdTag = dmdSec/amdSec

    $all_text .= "<mets:dmdSec ID=\"DM$dmd_num\" GROUPID=\"$section_num\">\n";

    $all_text .= "  <mets:mdWrap $label_attr MDTYPE=\"OTHER\" OTHERMDTYPE=\"gsdl3\" ID=\"gsdl$section_num\">\n";
    $all_text .= "    <mets:xmlData>\n";

    foreach my $data (@{$section_ptr->{'metadata'}}){
	my $escaped_value = &docprint::escape_text($data->[1]);
	$all_text .= '      <gsdl3:Metadata name="'. $data->[0].'">'. $escaped_value. "</gsdl3:Metadata>\n";
	if ($data->[0] eq "dc.Title") {
	    $all_text .= '      <gsdl3:Metadata name="Title">'. $escaped_value."</gsdl3:Metadata>\n";
	}
    }
   
    $all_text .= "    </mets:xmlData>\n";
    $all_text .= "  </mets:mdWrap>\n";
    
    $all_text .= "</mets:dmdSec>\n";    


    foreach my $subsection (@{$section_ptr->{'subsection_order'}}){
	$all_text .= $self->buffer_mets_dmdSection_section_xml($doc_obj,"$section.$subsection");
    }
    
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}



sub doctxt_to_xlink
{
    my $self = shift @_;
    my ($fname,$working_dir) = @_;

    my $xlink_href  = "file:$fname";

    return $xlink_href;

}



sub buffer_mets_fileSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir,$is_recursive) = @_;

    my $is_txt_split = undef;

    my $all_text 
	= $self->SUPER::buffer_mets_fileSection_section_xml($doc_obj,$section,$working_dir,$is_txt_split);

    return $all_text;
}

sub buffer_mets_fileWhole_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir) = @_;

    my $section_ptr = $doc_obj-> _lookup_section($section);
    return "" unless defined $section_ptr;
    
    my $all_text="";

    my $fileID=0;

    # Output the fileSection for the whole section
    #  => get the sourcefile and associative file

    my $id_root = "default";
    my $opt_owner_id = "";    

    $all_text .= "  <mets:fileGrp ID=\"$id_root\">\n";


    foreach my $data (@{$section_ptr->{'metadata'}}){
       my $escaped_value = &docprint::escape_text($data->[1]);

       if ($data->[0] eq "gsdlsourcefilename") { 
          my ($dirPath) = $escaped_value =~ m/^(.*)[\/\\][^\/\\]*$/;

          ++$fileID;	  
          $all_text .= "    <mets:file MIMETYPE=\"text/xml\" ID=\"$id_root.$fileID\" $opt_owner_id >\n";
        
	  $all_text .= '      <mets:FLocat LOCTYPE="URL" xlink:href="file:'.$data->[1].'" />'."\n";
	  
          $all_text .= "    </mets:file>\n";
       }
       
       if ($data->[0] eq "gsdlassocfile"){
	   
	   $escaped_value =~ m/^(.*?):(.*):(.*)$/;
	   my $assoc_file = $1;
	   my $mime_type  = $2;
	   my $assoc_dir  = $3;
	   
	   my $assfilePath = ($assoc_dir eq "") ? $assoc_file : "$assoc_dir/$assoc_file";
	   ++$fileID;
	   
	   my $mime_attr   = "MIMETYPE=\"$mime_type\"";
	   my $xlink_title = "xlink:title=\"$assoc_file\"";

	   my $id_attr;
	   my $xlink_href;

	   $id_attr = "ID=\"$id_root.$fileID\"";
	   $xlink_href  = "xlink:href=\"$assfilePath\"";

	   $all_text .= "    <mets:file $mime_attr $id_attr $opt_owner_id >\n";
	   $all_text .= "      <mets:FLocat LOCTYPE=\"URL\" $xlink_href $xlink_title />\n";
	   
	   $all_text .= "    </mets:file>\n";
	   	   
       }
   }
    
    $all_text .= "  </mets:fileGrp>\n";
    
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;
    
    return $all_text;
}


1;
