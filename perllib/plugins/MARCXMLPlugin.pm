###########################################################################
#
# MARCXMLPlugin.pm
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

# Processes MARCXML documents. Note that this plugin does no
# syntax checking (though the XML::Parser module tests for
# well-formedness).

package MARCXMLPlugin;

use ReadXMLFile;
use ReadTextFile;
use MetadataRead;
use marcmapping;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# methods with identical signatures take precedence in the order given in the ISA list.
sub BEGIN {
    @MARCXMLPlugin::ISA = ('MetadataRead', 'ReadXMLFile', 'ReadTextFile');
}

my $arguments = [{'name' => "metadata_mapping_file",
		  'desc' => "{MARCXMLPlugin.metadata_mapping_file}",
		  'type' => "string",
		  'deft' => "marc2dc.txt",
		  'reqd' => "no" },
		 { 'name' => "process_exp",
		   'desc' => "{BaseImporter.process_exp}",
		   'type' => "regexp",
		   'deft' => &get_default_process_exp(),
		   'reqd' => "no" }];

my $options = { 'name'     => "MARCXMLPlugin",
		'desc'     => "{MARCXMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments 
		};


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    # we want to be able to use the textcat methods from ReadTextFile
    # to get the language and encoding
    new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists, 1);

    my $self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);
        
    # we want to strip namespaces, so have to create a new XML parser
    my $parser = new XML::Parser('Style' => 'Stream',
                                 'Pkg' => 'ReadXMLFile',
                                 'PluginObj' => $self,
				 'Namespaces' => 1, # strip out namespaces
				 'Handlers' => {'Char' => \&Char,
						'XMLDecl' => \&ReadXMLFile::XMLDecl,
						'Entity'  => \&ReadXMLFile::Entity,
						'Doctype' => \&ReadXMLFile::Doctype,
						'Default' => \&ReadXMLFile::Default
                                 });

    $self->{'parser'} = $parser;

    $self->{'content'} = "";
    $self->{'xmlcontent'} = "";
    $self->{'record_count'} = 1;
    $self->{'language'} = "";
    $self->{'encoding'} = "";
    $self->{'marc_mapping'} = {};
    $self->{'current_code'} = "";
    $self->{'current_tag'} = "";
    $self->{'current_element'} = "";
    $self->{'metadata_mapping'} = undef;
    $self->{'num_processed'} = 0;
    $self->{'indent'} = 0;

    # in case we have individual records without a collection tag
    $self->{'xmlcollectiontag'} = "<collection>";
    return bless $self, $class;
}


sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.xml$^;
}

sub get_doctype {
    my $self = shift(@_);
    
    return "(collection|record)";
}


sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;
    
    ## the mapping file has already been loaded
    if (defined $self->{'metadata_mapping'} ){ 
	$self->SUPER::init(@_);
	return;
    }

    # read in the metadata mapping file
    my $mm_file = &util::locate_config_file($self->{'metadata_mapping_file'}); 

    if (! defined $mm_file)
    {
	my $msg = "MARCXMLPlugin ERROR: Can't locate mapping file \"" .
	    $self->{'metadata_mapping_file'} . "\".\n " .
		"    No metadata will be extracted from MARCXML files.\n";

	print $outhandle $msg;
	print $failhandle $msg;
	$self->{'metadata_mapping'} = undef;
	# We pick up the error in process() if there is no $mm_file
	# If we exit here, then pluginfo.pl will exit too!
    }
    else {
	$self->{'metadata_mapping'} = &marcmapping::parse_marc_metadata_mapping($mm_file, $outhandle);
    }


    ##map { print STDERR $_."=>".$self->{'metadata_mapping'}->{$_}."\n"; } keys %{$self->{'metadata_mapping'}};

    $self->SUPER::init(@_);
}


sub Char {
    # ReadXMLPlugin currently has 'use bytes' here, apparently to sort out
    # an encoding issue.  Possible that the time that 'use bytes' was
    # added in (to fix a problem) our understanding of Unicode in Perl
    # wasn't completely correct

    # Trialing out this new version (without 'use bytes') here for MarcXML data

    $_[0]->{'Text'} .= $_[1];
    return undef;
}

# Called for DOCTYPE declarations - use die to bail out if this doctype
# is not meant for this plugin
sub xml_doctype {
    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;
   return;

}


sub xml_start_document {
    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;

      
    my $file = $self->{'file'};
    my $filename = $self->{'filename'};
       
    my ($language, $encoding) = $self->textcat_get_language_encoding ($filename);

    $self->{'language'} = $language;
    $self->{'encoding'} = $encoding;
    $self->{'element_count'} = 1;
    $self->{'indent'} = 0;
    my $outhandle = $self->{'outhandle'};
    print $outhandle "MARCXMLPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;
    print STDERR "<Processing n='$self->{'file'}' p='MARCXMLPlugin'>\n" if $self->{'gli'};

    # reset the base id
    $self->{'base_oid'} = undef;
 
}

sub xml_end_document {

}

sub xml_start_tag {
    my $self = shift;
    my $expat = shift;
    my $element = shift;  

    my $text = $_;
    my $escaped_text =  $self->escape_text($_); 
  
    $self->{'current_element'} = $element;

    ##get all atributes of this element and store it in a map name=>value    
    my %attr_map = (); 
    my $attrstring = $_;
    while ($attrstring =~ /(\w+)=\"(\w+)\"/){
	$attr_map{$1}=$2;
	$attrstring = $'; #'
    }


    my $processor = $self->{'processor'};
	my $metadata  = $self->{'metadata'};

    ##create a new document for each record 
    if ($element eq "record") {
        my $filename = $self->{'filename'};
	my $language = $self->{'language'};
        my $encoding = $self->{'encoding'};
	my $file = $self->{'file'};
	my $doc_obj = new doc($filename, undef, $self->{'file_rename_method'});
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Language", $language);
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Encoding", $encoding);

	my ($filemeta) = $file =~ /([^\\\/]+)$/;
	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename, $filename_encoding);

	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "SourceSegment", "$self->{'record_count'}");
        if ($self->{'cover_image'}) {
	    $self->associate_cover_image($doc_obj, $filename);
	}
	$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
	$doc_obj->add_metadata($doc_obj->get_top_section(), "FileFormat", "MARCXML");

	my $outhandle = $self->{'outhandle'};
	print $outhandle "Record $self->{'record_count'}\n" if $self->{'verbosity'} > 1; 

        $self->{'record_count'}++;
        $self->{'doc_obj'} = $doc_obj;       
	$self->{'num_processed'}++;
	if (!defined $self->{'base_oid'}) {
	    $self->SUPER::add_OID($doc_obj);
	    $self->{'base_oid'} = $doc_obj->get_OID();
	}
	

    }
    
    ## get the marc code, for example 520
     if ($element eq "datafield") {
    	 if (defined $attr_map{'tag'} and $attr_map{'tag'} ne ""){
	     $self->{'current_tag'} = $attr_map{tag};  
	 }
     }


    ## append the subcode to the marc code for example 520a or 520b 
    if ($element eq "subfield"){
   	if (defined $attr_map{'code'} and $attr_map{'code'} ne "" and $self->{'current_tag'} ne ""){
	    $self->{'current_code'} = $attr_map{'code'};
	}
    }

   if ($element eq "record"){
        $self->{'indent'} = 0;
        $self->{'content'} = "";
        $self->{'xmlcontent'} = "";
    }
    else {
         if ($element ne "subfield"){
              $self->{'indent'} = 1;
         }
         else{
           $self->{'indent'} = 2;
         }
    }
    

    if ($element eq "collection") {
	# remember the full start tag for <collection ...>
	# This is needed to wrap around each <record> when generating its associate MARCXML file

        $self->{'xmlcollectiontag'} = $text;
    }
    else {
        $self->{'content'} .= "<br/>" if ($element ne "record");
        $self->{'content'} .= $self->calculate_indent($self->{'indent'}).$escaped_text;
        $self->{'xmlcontent'} .= $text;
   }
    
}



sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    my $text = $_;
    my $escaped_text =  $self->escape_text($_); 
 
    if ($element eq "record" and defined $self->{'doc_obj'}) {
	# process the document
	my $processor = $self->{'processor'};
	my $doc_obj = $self->{'doc_obj'};
        $self->{'content'} .= "<br/>".$escaped_text;
        $self->{'xmlcontent'} .= $text;
      

	my $top_section = $doc_obj->get_top_section();

	my $tmp_marcxml_filename = &util::get_tmp_filename("xml");
	if (open (XMLOUT,">$tmp_marcxml_filename")) {
	    binmode(XMLOUT,":utf8");

	    print XMLOUT "<?xml-stylesheet type=\"text/xsl\" href=\"MARC21slim2English.xsl\"?>\n";	    
	    my $xml_content = $self->{'xmlcontent'};

	    $xml_content = $self->{'xmlcollectiontag'}.$xml_content."</collection>";

	    print XMLOUT $xml_content;

	    close(XMLOUT);

	    $doc_obj->associate_file($tmp_marcxml_filename,"marcxml.xml","text/xml", $top_section);
	    
	    # assicate xsl style file for presentation as HTML
	    my $xsl_filename = &util::filename_cat($ENV{'GSDLHOME'},"etc","MARC21slim2English.xsl");
	    $doc_obj->associate_file($xsl_filename,"MARC21slim2English.xsl","text/xml", $top_section);

	}
	else {
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "Warning: Unable for write out associated MARCXML file $tmp_marcxml_filename\n";
	}
	
	# include any metadata passed in from previous plugins 
	# note that this metadata is associated with the top level section
	
	$self->extra_metadata ($doc_obj, 
			       $doc_obj->get_top_section(), 
			       $self->{'metadata'});
	

	$self->add_OID($doc_obj, $self->{'base_oid'}, $self->{'record_count'});

	$doc_obj->add_utf8_text($doc_obj->get_top_section(),$self->{'content'});
        $processor->process($doc_obj);

        ##clean up
	$self->{'content'} = "";  
	$self->{'xmlcontent'} = "";  
	$self->{'doc_obj'} = undef;
        return;
    }

    ## map the xmlmarc to gsdl metadata
    if ($element eq "datafield" and defined $self->{'doc_obj'} and defined $self->{'marc_mapping'} and defined $self->{'metadata_mapping'}){
	my $metadata_mapping = $self->{'metadata_mapping'};
	my $marc_mapping = $self->{'marc_mapping'};
	my $doc_obj = $self->{'doc_obj'};

	##print STDERR "**** Marc Record\n";
      ##map { print STDERR $_."=>".$marc_mapping->{$_}."\n"; } keys %$marc_mapping;
	##print STDERR "**** Metadata Mapping\n";
      ##map { print STDERR $_."=>".$metadata_mapping->{$_}."\n"; } keys %$metadata_mapping;


	foreach my $marc_field (keys %$metadata_mapping){

	    ## test whether this field has subfield
	    my $subfield = undef;
	    if ($marc_field =~ /(\d\d\d)(?:\$|\^)?(\w)/){
		$marc_field = $1;
		$subfield = $2;
	    }

	    my $matched_field = $marc_mapping->{$marc_field}; 

	    if (defined $matched_field) {

		my $meta_name  = undef;
		my $meta_value = undef;

		if (defined $subfield){
		    $meta_name = $metadata_mapping->{$marc_field."\$".$subfield};

		    $meta_value = $matched_field->{$subfield};
		    
		    if (!defined $meta_value) {
			# record read in does not have the specified subfield
			next;
		    }
		}
		else {
		    $meta_name = $metadata_mapping->{$marc_field};
		    
		    # no subfield => get all the values
		    my $first = 1;
		    foreach my $value (sort keys %{$matched_field}) {
			if ($first) {
			    $meta_value = $matched_field->{$value};
			    $first = 0;
			} else {
			    $meta_value .= " " . $matched_field->{$value};
			}
		    }

		}
		
		my $gs_mode = ($ENV{'GSDL3SRCHOME'}) ? "gs3" : "gs2";

		if ($gs_mode eq "gs2") {
		    ## escape [ and ]
		    $meta_value =~ s/\[/\\\[/g;
		    $meta_value =~ s/\]/\\\]/g;

		    # The following is how MARCPlug does this
		    # If this is really OK for Greenstone2, then consider
		    # to switching to this, as this would mean we
		    # wouldn't need a special gs2/gs3 test here!

#		    $meta_value =~ s/\[/&\#091;/g;
#		    $meta_value =~ s/\]/&\#093;/g;

		    ##print STDERR  "$meta_name=$meta_value\n";
		}

		$doc_obj->add_utf8_metadata($doc_obj->get_top_section(),$meta_name, $meta_value);
		
	    }		    
			
	}

	##clean up
	$self->{'marc_mapping'} = undef;
	$self->{'current_tag'} = "";
    }
  
   if ($element eq "datafield"){
       $self->{'indent'} = 1;
       $self->{'content'} .= "<br/>".$self->calculate_indent($self->{'indent'}).$escaped_text;
       $self->{'xmlcontent'} .= $text;
   }
    else{
	$self->{'content'} .= $escaped_text;   
	$self->{'xmlcontent'} .= $text;   
    }
     
}

sub add_OID {
    my $self = shift (@_);
    my ($doc_obj, $id, $record_number) = @_;

    my $full_id = $id . "r" . $record_number;
    if ($self->{'OIDtype'} eq "assigned") {
	my $identifier = $doc_obj->get_metadata_element ($doc_obj->get_top_section(), $self->{'OIDmetadata'});
	if (defined $identifier && $identifier ne "") {
	    $full_id = $identifier;
	    $full_id = &util::tidy_up_oid($full_id);
	}
    }
    $doc_obj->set_OID($full_id);
}

sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;

    my $text = $_;
    my $escaped_text = $self->escape_text($_);

    # protect against & in raw text file
    $text =~ s/&/&amp;/g; # can't have & in raw form, even in 'raw' xml text

    ## store the text of a marc code, for exapmle 520a=>A poem about....
    if ($self->{'current_element'} eq "subfield" and $self->{'current_code'} ne "" and $_ ne "" ){
	##stored it in the marc_mapping 

	my $current_tag  = $self->{'current_tag'};
	my $current_code = $self->{'current_code'};

     	$self->{'marc_mapping'}->{$current_tag}->{$current_code} .= $_;

	$self->{'current_code'} = "";
    }
    
    $self->{'content'} .= $escaped_text;
    $self->{'xmlcontent'} .= $text;
   
}

sub calculate_indent{
   my ($self,$num) = @_;

   my $indent ="";
  
   for (my $i=0; $i<$num;$i++){
       $indent .= "&nbsp;&nbsp;&nbsp;&nbsp;";
    } 
 
   return $indent;

}

sub escape_text {
    my ($self,$text) = @_;
    # special characters in the xml encoding
    $text =~ s/&/&amp;/g; # this has to be first...
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\"/&quot;/g;

    return $text;
}


sub unescape_text {
    my ($self,$text) = @_;
    # special characters in the xml encoding
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&quot;/\"/g;

    $text =~ s/&/&amp;/g; # can't have & in raw form, even in unescaped xml!

    return $text;
}


1;


