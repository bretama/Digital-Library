###########################################################################
#
# FedoraMETSPlugout.pm -- the plugout module for METS archives
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
# But WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################

package FedoraMETSPlugout;

use strict;
no strict 'refs';

#eval {require bytes};
#use util;
use METSPlugout;
#use docprint; # for escape_text

sub BEGIN {
    @FedoraMETSPlugout::ISA = ('METSPlugout');

    if ((!defined $ENV{'FEDORA_HOME'}) || (!defined $ENV{'FEDORA_VERSION'})) {
	if (defined $ENV{'FEDORA_HOME'}) {
	    print STDERR "FEDORA_HOME = $ENV{'FEDORA_HOME'}";
	}

	if (defined $ENV{'FEDORA_VERSION'}) {
	    print STDERR "FEDORA_VERSION = $ENV{'FEDORA_VERSION'}";
	}

	die "Need both environment variables FEDORA_HOME and FEDORA_VERSION to be set\n";
    }

    $ENV{'FEDORA_HOSTNAME'} = "localhost" if (!defined $ENV{'FEDORA_HOSTNAME'});
    $ENV{'FEDORA_SERVER_PORT'} = "8080" if (!defined $ENV{'FEDORA_SERVER_PORT'});
    $ENV{'FEDORA_USER'}     = "fedoraAdmin" if (!defined $ENV{'FEDORA_USER'});
    $ENV{'FEDORA_PASS'}     = "fedoraAdmin" if (!defined $ENV{'FEDORA_PASS'});
    $ENV{'FEDORA_PROTOCOL'} = "http" if (!defined $ENV{'FEDORA_PROTOCOL'});
    $ENV{'FEDORA_PID_NAMESPACE'} = "greenstone" if (!defined $ENV{'FEDORA_PID_NAMESPACE'});
    $ENV{'FEDORA_PREFIX'} = "/fedora" if (!defined $ENV{'FEDORA_PREFIX'});
}

my $arguments = [ 
      { 'name' => "fedora_namespace", 
	'desc' => "{FedoraMETSPlugout.fedora_namespace}",
	'type' => "string",
        'deft' =>  "greenstone",
	'reqd' => "no",    
	'hiddengli' => "no"}
		  ];



my $options = { 'name'     => "FedoraMETSPlugout",
		'desc'     => "{FedoraMETSPlugout.desc}",
		'abstract' => "no",
		'inherits' => "yes", 
	        'args'     => $arguments
                };


sub new 
{
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

    my $fnamespace = $self->{'fedora_namespace'};
    my $oid_namespace = (defined $fnamespace) ? $fnamespace : "test";

    my $collection = $ENV{'GSDLCOLLECTION'};

    # Might need the following in the schemeLocation attribute for Fedora3
    #   http://www.fedora.info/definitions/1/0/mets-fedora-ext1-1.xsd
    my $extra_attr = "OBJID=\"$oid_namespace:$collection-$OID\" TYPE=\"FedoraObject\" LABEL=\"$doc_title\"";

    my $extra_schema = undef;

    if (defined $ENV{'FEDORA_VERSION'} && $ENV{'FEDORA_VERSION'} =~ m/^2/) { # checking if major version is 2
    	$extra_schema = "http://www.fedora.info/definitions/1/0/mets-fedora-ext.xsd";
    }
    else {
	$extra_attr .= " EXT_VERSION=\"1.1\"";
    }
    
    $self->output_mets_xml_header_extra_attribute($handle,$extra_attr,$extra_schema);

    print $handle '<mets:metsHdr RECORDSTATUS="A"/>'. "\n"; # A = active

}

#
#  Print out "family" of doctxt.xml files
#

sub saveas_doctxt_section
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir,$section) = @_;

    my $section_ptr=$doc_obj->_lookup_section($section);
    return unless defined $section_ptr;

    my $section_fnum ="1". $section;
    $section_fnum =~ s/\./_/g;

    my $doc_txt_file = &FileUtils::filenameConcatenate ($working_dir,"doctxt$section_fnum.xml");	
	
    $self->open_xslt_pipe($doc_txt_file,$self->{'xslt_txt'});

    my $outhandler; 

    if (defined $self->{'xslt_writer'}){
	$outhandler = $self->{'xslt_writer'};
    }
    else{
	$outhandler = $self->get_output_handler($doc_txt_file);
    } 

    $self->output_xml_header($outhandler);

    ## change links to be Fedora cognant:
    my $txt = $section_ptr->{'text'};
    $section_ptr->{'text'} = $self->adjust_links($doc_obj, \$txt);

    $self->output_txt_section($outhandler,$doc_obj, $section);
    $self->output_xml_footer($outhandler);
    

    if (defined $self->{'xslt_writer'}){     
	$self->close_xslt_pipe(); 
    }
    else{
	close($outhandler);
    } 


    # Output all the subsections as separate files
    foreach my $subsection (@{$section_ptr->{'subsection_order'}}){
	
	$self->saveas_doctxt_section($doc_obj, $working_dir, "$section.$subsection");
    }
}

sub adjust_links
{
    my $self = shift(@_);
    my ($doc_obj, $textref) = @_;

    ## change links to be Fedora cognant:
    # 1. retrieve txt of section - $$textref
    # 2. change it:
    # /$ENV{'FEDORA_PREFIX'}/objects/$greenstone-docobj-hash-xxx/datastreams/FG<orig-img-name>/content
    # 3. only replace it back in doc_obj if we didn't get a ref in the first place

    my $OID = $doc_obj->get_OID();
    my $fnamespace = $self->{'fedora_namespace'};
    if($OID ne "collection" && defined $fnamespace) {
	my $fed_id = "$fnamespace:".$ENV{'GSDLCOLLECTION'}."-$OID"; #oid_namespace:collection-OID
	my $fedora_url_prefix = $ENV{'FEDORA_PREFIX'}."/objects/$fed_id/datastreams/FG";
	my $fedora_url_suffix = "/content";

	$$textref =~ s/(<(?:img|embed|table|tr|td|link|script)[^>]*?(?:src|background|href)\s*=\s*)((?:[\"][^\"]+[\"])|(?:[\'][^\']+[\'])|(?:[^\s\/>]+))([^>]*>)/$self->replace_rel_link($1, $2, $3, $fedora_url_prefix, $fedora_url_suffix)/isge;
#	print STDERR "*** all text after: $$textref\n\n";
    }

    return $$textref;
}

# replace relative link with the prefix and suffix given
sub replace_rel_link
{
    my $self = shift (@_);
    my ($front, $link, $back, $url_prefix, $url_suffix) = @_;

    # only process relative links. Return if absolute link
    if($link =~ m/^http/) {
	return "$front$link$back";
    }

    # remove quotes from link at start and end if necessary
    if ($link=~/^[\"\']/) {
	$link=~s/^[\"\']//;
	$link=~s/[\"\']$//;
	$front.='"';
	$back="\"$back";
    }

    # remove any _httpdocimg_/ that greenstone may have prefixed to the image
    $link =~ s/^_httpdocimg_(?:\/|\\)//;
    
    return "$front$url_prefix$link$url_suffix$back";
}


sub saveas_doctxt
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir) = @_;

    my $section = $doc_obj->get_top_section();

    $self->saveas_doctxt_section($doc_obj,$working_dir,$section);

    $self->saveas_toc($doc_obj,$working_dir);
}

sub buffer_toc
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir,$section,$depth) = @_;
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    my $all_text = "";

    my $section_num ="1". $section;
    my $indent = " " x ($depth*2);

    $all_text .= "$indent<Section id=\"$section_num\">\n";

    # Output all the subsections as separate files
    foreach my $subsection (@{$section_ptr->{'subsection_order'}})
    {
	$all_text 
	    .= $self->buffer_toc($doc_obj, $working_dir, 
				 "$section.$subsection",$depth+1);
    }

    $all_text .= "$indent</Section>\n";

    return $all_text;
}


sub saveas_toc
{
    my $self = shift (@_);
    my ($doc_obj,$working_dir) = @_;

    my $section = $doc_obj->get_top_section();
    my $section_ptr=$doc_obj->_lookup_section($section);
    my $num_subsections = scalar(@{$section_ptr->{'subsection_order'}});

    # If num_subsections is 0, then there is no nested TOC

    if ($num_subsections>0) {

	my $doc_txt_file = &FileUtils::filenameConcatenate ($working_dir,"doctoc.xml");
	
	$self->open_xslt_pipe($doc_txt_file,$self->{'xslt_txt'});
	
	my $outhandler; 
	
	if (defined $self->{'xslt_writer'}){
	    $outhandler = $self->{'xslt_writer'};
	}
	else{
	    $outhandler = $self->get_output_handler($doc_txt_file);
	} 
	print $outhandler $self->buffer_toc($doc_obj, $working_dir, $section, 0);
	
	if (defined $self->{'xslt_writer'}){     
	    $self->close_xslt_pipe(); 
	}
	else{
	    close($outhandler);
	} 
    }

}


sub buffer_mets_relsext_xml
{
    my $self = shift(@_);
    my ($doc_obj) = @_;

    my $OID = $doc_obj->get_OID();

    my $fnamespace = $self->{'fedora_namespace'};
    my $oid_namespace = (defined $fnamespace) ? $fnamespace : "test";
    my $collection = $ENV{'GSDLCOLLECTION'};

    my $fed_id = "$oid_namespace:$collection-$OID";

    my $all_text = "";

    my $top_section = $doc_obj->get_top_section();
    my $plugin_type = $doc_obj->get_metadata_element($top_section,"Plugin");
    
# Images do not get ingested into Fedora when on Linux if the following is included
# Needs more investigation, since we'd like a working version of the following
# in order to get thumbnails working and other stuff.
#    if ((defined $plugin_type) && ($plugin_type eq "ImagePlugin"))
#    {
#
#	$all_text .= "<mets:amdSec ID=\"RELS-EXT\">\n";
#	$all_text .= "  <mets:techMD ID=\"RELS-EXT1.0\" STATUS=\"A\">\n";
#	$all_text .= "    <mets:mdWrap LABEL=\"RELS-EXT - RDF formatted relationship metadata\" MDTYPE=\"OTHER\" MIMETYPE=\"text/xml\">\n";
#	$all_text .= "      <mets:xmlData>\n";
#	$all_text .= "        <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:fedora-model=\"info:fedora/fedora-system:def/model#\">\n";
#	$all_text .= "          <rdf:Description rdf:about=\"info:fedora/$fed_id\">\n";
#	$all_text .= "            <fedora-model:hasContentModel rdf:resource=\"info:fedora/demo:UVA_STD_IMAGE\"/>\n";
#	$all_text .= "          </rdf:Description>\n";
#	$all_text .= "        </rdf:RDF>\n";
#	$all_text .= "      </mets:xmlData>\n";
#	$all_text .= "    </mets:mdWrap>\n";
#	$all_text .= "  </mets:techMD>\n";
#	$all_text .= "</mets:amdSec>\n";
#    }

    return $all_text;
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

    print $handle $self->buffer_mets_relsext_xml($doc_obj);

    print $handle "<mets:fileSec>\n";
    print $handle "  <mets:fileGrp ID=\"DATASTREAMS\">\n";

    # Generate Filestream for Table of Contents (TOC)
    my $section_ptr=$doc_obj->_lookup_section($section);
    my $num_subsections = scalar(@{$section_ptr->{'subsection_order'}});

    # If num_subsections is 0, then there is no nested TOC

    if ($num_subsections>0) {
	print $handle $self->buffer_mets_fileSection_toc($doc_obj,$section,$working_dir);
    }

    # print out the fileSection by sections
    print $handle $self->buffer_mets_fileSection_section_xml($doc_obj,$section,$working_dir);

    # print out the whole fileSection
    print $handle $self->buffer_mets_fileWhole_section_xml($doc_obj,$section,$working_dir); 

    print $handle "  </mets:fileGrp>\n";
    print $handle "</mets:fileSec>\n";
  
    # print out the StructMapSection by sections

    my $struct_type = "fedora:dsBindingMap";

    # If document is going to make use of deminators (BMech and BDef) then
    # need to code up more output XML here (structMap)and in  
    # METS:behaviorSec (Fedora extension?) sections
  
}

sub buffer_mets_amdSec_header
{
    my $self = shift(@_);
    my ($section,$id) = @_;

    # convert section number
    my $section_num ="1". $section;

    my $all_text = "";

    my $label_attr = "";

    $all_text .= "<mets:amdSec ID=\"$id$section\" >\n";
    $all_text .= "  <mets:techMD ID=\"$id$section.0\">\n"; # .0 fedora version number?
    
    $label_attr = "LABEL=\"Metadata\"";

    $all_text .= "  <mets:mdWrap $label_attr MDTYPE=\"OTHER\" OTHERMDTYPE=\"gsdl3\" ID=\"".$id."gsdl$section_num\">\n";
    $all_text .= "    <mets:xmlData>\n";

    return $all_text;

}

sub buffer_mets_amdSec_footer
{
    my $self = shift(@_);

    my $all_text = "";
    
    $all_text .= "    </mets:xmlData>\n";
    $all_text .= "  </mets:mdWrap>\n";
    
    $all_text .= "  </mets:techMD>\n";
    $all_text .= "</mets:amdSec>\n";

    return $all_text;

}

sub oai_dc_metadata_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section) = @_;

    my $all_text = "";

    my $dc_namespace = "";
    $dc_namespace .= "xmlns:dc=\"http://purl.org/dc/elements/1.1/\"";
    $dc_namespace .= " xmlns:oai_dc=\"http://www.openarchives.org/OAI/2.0/oai_dc/\" ";
    
    $all_text .= "  <oai_dc:dc $dc_namespace>\n";
    
    $all_text .= $self->get_dc_metadata($doc_obj, $section,"oai_dc");
    $all_text .= "  </oai_dc:dc>\n";

    return $all_text;
}





# Work out the what the metadata set prefixes (dc,dls etc.) are for 
# this document

sub metadata_set_prefixes
{
    my $self = shift(@_);
    my ($doc_obj, $section) = @_;
    
    $section="" unless defined $section;
    
    my $section_ptr = $doc_obj->_lookup_section($section);
    return {} unless defined $section_ptr;

    my $unique_prefix = {};

    foreach my $data (@{$section_ptr->{'metadata'}})
    {
	my ($prefix) = ($data->[0]=~ m/^(.*?)\./);
	
	if (defined $prefix)
	{
	    next if ($prefix eq "dc"); # skip dublin core as handled separately elsewhere

	    $unique_prefix->{$prefix} = 1;
	}
	else
	{
	    $unique_prefix->{"ex"} = 1;
	}

    }

    return $unique_prefix;
}


sub mds_metadata_xml 
{
    my $self = shift(@_);
    my ($doc_obj, $section, $mds_prefix, $namespace) = @_;
    
    # build up string of metadata with $mds_prefix
    $section="" unless defined $section;
    
    my $section_ptr = $doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    my $all_text="";
    $all_text .= "  <$mds_prefix:$mds_prefix $namespace>\n";


    foreach my $data (@{$section_ptr->{'metadata'}})
    {
	if ($data->[0]=~ m/^(?:(.*?)\.)?(.*)$/) 
	{
	    my $curr_mds_prefix = $1;
	    my $mds_full_element = $2;

	    $curr_mds_prefix = "ex" unless defined $curr_mds_prefix;

	    if ($curr_mds_prefix eq $mds_prefix)
	    {
		# split up full element in the form Title^en into element=Title, attr="en"
		my ($mds_element,$subelem) = ($mds_full_element =~ m/^(.*?)(?:\^(.*))?$/);
		my $mds_attr = (defined $subelem) ? "qualifier=\"$subelem\"" : "";
		
		my $escaped_value = &docprint::escape_text($data->[1]);
		
		$all_text .= "   <$mds_prefix:metadata name=\"$mds_element\" $mds_attr>$escaped_value</$mds_prefix:metadata>\n";
	    }
	}
    }

    $all_text .= "  </$mds_prefix:$mds_prefix>\n";


    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}



sub buffer_mets_dmdSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section) = @_;
   
    $section="" unless defined $section;
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    my $all_text = "";

    $all_text .= $self->buffer_mets_amdSec_header($section,"DC");
    $all_text .= $self->oai_dc_metadata_xml($doc_obj,$section);
    $all_text .= $self->buffer_mets_amdSec_footer($section);

    # for each metadata set
    my $md_sets = $self->metadata_set_prefixes($doc_obj,$section);

    foreach my $md_set (keys %$md_sets)
    {
	# Greenstone's agnostic approach to metadata sets conflicts with
	# Fedoras more clinically prescribed one.  Fake a namespace for
	# each $md_set to keep both sides happy

	my $fake_namespace 
	    = "xmlns:$md_set=\"http://www.greenstone.org/namespace/fake/$md_set\"";
	my $id_caps = $md_set;
	$id_caps =~ tr/[a-z]/[A-Z]/;

	$all_text .= $self->buffer_mets_amdSec_header($section,$id_caps);
	$all_text .= $self->mds_metadata_xml($doc_obj,$section,$md_set,$fake_namespace);
	$all_text .= $self->buffer_mets_amdSec_footer($section);
    }


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

    my $xlink_href;

    my $fedora_prefix = $ENV{'FEDORA_HOME'};
    if (!defined $fedora_prefix) {
	$xlink_href  = "file:$fname";
    }
    else
    {
	my $collectparent;
	if (defined $ENV{'GSDL3SRCHOME'}) { # we're dealing with a GS3 server
	    if(defined $ENV{'GSDL3HOME'}) { # in case the web directory is located in a separate place
		$collectparent = &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'},"sites","localsite");
	    } 
	    else { # try the default location for the web directory
		$collectparent = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'},"web","sites","localsite");
	    }
	}
	else {
	    # greenstone 2
	    $collectparent = $ENV{'GSDLHOME'};
	}
	
	my $gsdl_href = &FileUtils::filenameConcatenate($working_dir, $fname);
	$collectparent = &util::filename_to_regex($collectparent); # escape reserved metacharacter \ in path (by replacing it with \\) for substitution
	$gsdl_href =~ s/^$collectparent(\/|\\)?//; # remove the collectparent path in gsdl_href and any trailing slash
	$gsdl_href =~ s/\\/\//g;                   # make sure we have url paths (which only use / not \)
	my $localfedora = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "packages", "tomcat", "conf", "Catalina", "localhost", "fedora.xml");
	
	my $greenstone_url_prefix = &util::get_greenstone_url_prefix();
	# prepend url_prefix (which will contain the forward slash upfront)
	if($ENV{'GSDL3SRCHOME'} && -e $localfedora) {               # Fedora uses Greenstone's tomcat.
	    $gsdl_href = "$greenstone_url_prefix/sites/localsite/$gsdl_href";     # Default: /greenstone3/sites/localsite/$gsdl_href
	} else {
	    $gsdl_href = "$greenstone_url_prefix/$gsdl_href"; 	    # By default: "/greenstone/$gsdl_href";
	}

	my $fserver = $ENV{'FEDORA_HOSTNAME'};
	my $fport = $ENV{'FEDORA_SERVER_PORT'};
	
	my $fdomain = "http://$fserver:$fport";
	$xlink_href  = "$fdomain$gsdl_href";
#ERROR: $xlink_href  = "$fname";
    }

    return $xlink_href;

}


sub buffer_mets_fileSection_toc
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir) = @_;

    my $opt_attr = "OWNERID=\"M\"";

    my $all_text = '  <mets:fileGrp ID="TOC">'. "\n";
    $all_text .= "    <mets:file MIMETYPE=\"text/xml\" ID=\"FILETOC\" $opt_attr >\n";    
    my $xlink = $self->doctxt_to_xlink("doctoc.xml",$working_dir);

    $all_text .= '      <mets:FLocat LOCTYPE="URL" xlink:href="'.$xlink.'"';

    $all_text .= ' xlink:title="Table of Contents"/>' . "\n";
    $all_text .= "    </mets:file>\n";
    $all_text .= "  </mets:fileGrp>\n";

    return $all_text;
}


sub buffer_mets_fileSection_section_xml
{
    my $self = shift(@_);
    my ($doc_obj,$section,$working_dir) = @_;

    my $is_txt_split = 1;
    my $opt_owner_id = "OWNERID=\"M\"";

    my $all_text 
	= $self->SUPER::buffer_mets_fileSection_section_xml($doc_obj,$section,$working_dir,$is_txt_split, $opt_owner_id,"SECTION");


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

    my $id_root = "";
    my $opt_owner_id = "OWNERID=\"M\"";


    foreach my $data (@{$section_ptr->{'metadata'}}){
       my $escaped_value = &docprint::escape_text($data->[1]);

       if ($data->[0] eq "gsdlassocfile"){
	   
	   $escaped_value =~ m/^(.*?):(.*):(.*)$/;
	   my $assoc_file = $1;
	   my $mime_type  = $2;
	   my $assoc_dir  = $3;

	   $id_root = "FG$assoc_file";

	   $id_root =~ s/\//_/g;
	   $all_text .= "  <mets:fileGrp ID=\"$id_root\">\n";
	   
	   # The assoc_file's name may be url-encoded, so the xlink_href in the <mets:FLocat>
	   # element must be the url to this (possibly url-encoded) filename
	   my $assocfile_url = &unicode::filename_to_url($assoc_file);
	   my $assfilePath = ($assoc_dir eq "") ? $assocfile_url : "$assoc_dir/$assocfile_url";
	   ++$fileID;
	   
	   my $mime_attr   = "MIMETYPE=\"$mime_type\"";
	   my $xlink_title = "xlink:title=\"$assoc_file\"";

	   my $id_attr;
	   my $xlink_href;

	   $id_attr = "ID=\"F$id_root.0\"";

	   my $fedora_prefix = $ENV{'FEDORA_HOME'};
	   if (!defined $fedora_prefix) {
	       $xlink_href  = "xlink:href=\"$assfilePath\"";
	   }
	   else
	   {
	       my $collectparent;
	       if (defined $ENV{'GSDL3SRCHOME'}) { # we're dealing with a GS3 server
		   if(defined $ENV{'GSDL3HOME'}) { # in case the web directory is located in a separate place
		       $collectparent = &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'},"sites","localsite");
		   } 
		   else { # try the default location for the web directory
		       $collectparent = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'},"web","sites","localsite");
		   }
	       }	      
	       else {
		   # greenstone 2
		   $collectparent = $ENV{'GSDLHOME'};
	       }

	       my $gsdl_href = &FileUtils::filenameConcatenate($working_dir,$assfilePath);
	       $collectparent = &util::filename_to_regex($collectparent); # escape reserved metacharacter \ in path (by replacing it with \\) for substitution
	       $gsdl_href =~ s/^$collectparent(\/|\\)?//; # remove the collectparent path in gsdl_href and any trailing slash
	       $gsdl_href =~ s/\\/\//g;                   # make sure we have url paths (which only use / not \)
	       my $localfedora = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "packages", "tomcat", "conf", "Catalina", "localhost", "fedora.xml");

	       my $greenstone_url_prefix = &util::get_greenstone_url_prefix();
	       # prepend url_prefix (which will contain the forward slash upfront)
	       if($ENV{'GSDL3SRCHOME'} && -e $localfedora) {                 # Fedora uses Greenstone's tomcat. 
		   $gsdl_href = "$greenstone_url_prefix/sites/localsite/$gsdl_href";    # Default: /greenstone3/sites/localsite/$gsdl_href
	       } else {
		   $gsdl_href = "$greenstone_url_prefix/$gsdl_href";         # By default: "/greenstone/$gsdl_href";
	       }

	       my $fserver = $ENV{'FEDORA_HOSTNAME'};
	       my $fport = $ENV{'FEDORA_SERVER_PORT'};
	       
	       my $fdomain = "http://$fserver:$fport";
	       $xlink_href = "xlink:href=\"$fdomain$gsdl_href\"";
#ERROR: $xlink_href = "xlink:href=\"$assfilePath\"";
	   }
	   
	   my $top_section = $doc_obj->get_top_section();
	   my $id = $doc_obj->get_metadata_element($top_section,"Identifier");
	   
###	   print STDERR "**** mime-type: $mime_attr\n";

	   $all_text .= "    <mets:file $mime_attr $id_attr $opt_owner_id >\n";
	   $all_text .= "      <mets:FLocat LOCTYPE=\"URL\" $xlink_href $xlink_title />\n";

	   $all_text .= "    </mets:file>\n";
	   
	   $all_text .= "  </mets:fileGrp>\n";	   
       }
   }
    
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;
    
    return $all_text;
}


1;
