###########################################################################
#
# ReadXMLFile.pm -- base class for XML plugins
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

package ReadXMLFile;

use BaseImporter;
use doc;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @ReadXMLFile::ISA = ('BaseImporter');
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
}

use XMLParser;

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => &get_default_process_exp(),
	'reqd' => "no" },
      { 'name' => "xslt",
	'desc' => "{ReadXMLFile.xslt}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" } ];

my $options = { 'name'     => "ReadXMLFile",
		'desc'     => "{ReadXMLFile.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about creating the XML parser as all we want is the 
	# list of plugin options
	return bless $self, $class;
    }

    my $parser = new XML::Parser('Style' => 'Stream',
                                 'Pkg' => 'ReadXMLFile',
                                 'PluginObj' => $self,
				 'Handlers' => {'Char' => \&Char,
						'XMLDecl' => \&XMLDecl,
						'Entity'  => \&Entity,
						'Doctype' => \&Doctype,
						'Default' => \&Default
                                 });

    $self->{'parser'} = $parser;

    return bless $self, $class;
}

# the inheriting class must implement this method to tell whether to parse this doc type
sub get_doctype {
    my $self = shift(@_);
    die "$self The inheriting class must implement get_doctype method";
}


sub apply_xslt
{
    my $self = shift @_;
    my ($xslt,$filename) = @_;
    
    my $outhandle = $self->{'outhandle'};

    my $xslt_filename = $xslt;

    if (! -e $xslt_filename) {
	# Look in main site directory
	my $gsdlhome = $ENV{'GSDLHOME'};
	$xslt_filename = &util::filename_cat($gsdlhome,$xslt);
    }

    if (! -e $xslt_filename) {
	# Look in collection directory
	my $coldir = $ENV{'GSDLCOLLECTDIR'};
	$xslt_filename = &util::filename_cat($coldir,$xslt);
    }

    if (! -e $xslt_filename) {
	print $outhandle "Warning: Unable to find XSLT $xslt\n";
	if (open(XMLIN,"<$filename")) {

	    my $untransformed_xml = "";
	    while (defined (my $line = <XMLIN>)) {

		$untransformed_xml .= $line;
	    }
	    close(XMLIN);
	    
	    return $untransformed_xml;
	}
	else {
	    print $outhandle "Error: Unable to open file $filename\n";
	    print $outhandle "       $!\n";
	    return "";
	}
	
    }

    my $bin_java = &util::filename_cat($ENV{'GSDLHOME'},"bin","java");
    my $jar_filename = &util::filename_cat($bin_java,"xalan.jar");
    my $xslt_base_cmd = "java -jar $jar_filename";
    my $xslt_cmd = "$xslt_base_cmd -IN \"$filename\" -XSL \"$xslt_filename\"";

    my $transformed_xml = "";

    if (open(XSLT_IN,"$xslt_cmd |")) {
	while (defined (my $line = <XSLT_IN>)) {

	    $transformed_xml .= $line;
	}
	close(XSLT_IN);
    }
    else {
	print $outhandle "Error: Unable to run command $xslt_cmd\n";
	print $outhandle "       $!\n";
    }

    return $transformed_xml;

}

sub can_process_this_file {
    my $self = shift(@_);
    my ($filename) = @_;

    if (-f $filename 
	&& $self->SUPER::can_process_this_file($filename)
	&& $self->check_doctype($filename)) {
	return 1; # its a file for us
    }
    return 0;
}

sub check_doctype {
    my $self = shift (@_);
    
    my ($filename) = @_;

    if (open(XMLIN,"<$filename")) {
	my $doctype = $self->get_doctype();
	## check whether the doctype has the same name as the root element tag
	while (defined (my $line = <XMLIN>)) {
	    ## find the root element
	    if ($line =~ /<([\w\d:]+)[\s>]/){
		my $root = $1;
		if ($root !~ $doctype){
		    close(XMLIN);
		    return 0;
		}
		else {
		    close(XMLIN); 
		    return 1;
		}
	    }
	}
	close(XMLIN);
    }
    
    return undef; # haven't found a valid line
    
}

sub read {
    my $self = shift (@_);  
  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);
    
    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up
    $self->{'base_dir'} = $base_dir;
    $self->{'file'} = $file;
    $self->{'filename'} = $filename_full_path;
    $self->{'filename_no_path'} = $filename_no_path;
    $self->{'processor'} = $processor;

    # this contains metadata passed in from running metadata_read with other plugins (eg from MetadataXMLPlugin)
    # we are also using it to store up any metadata found during parsing the XML, so that it can be added to the doc obj.
    $self->{'metadata'} = $metadata;

    if ($self->parse_file($filename_full_path)) {
	return 1; # processed the file
    }
    return -1;
}


sub parse_file {
    my $self = shift (@_);
    my ($filename_full_path, $file, $gli) = @_;
    eval {
	my $xslt = $self->{'xslt'};
	if (defined $xslt && ($xslt ne "")) {
	    # perform xslt
	    my $transformed_xml = $self->apply_xslt($xslt,$filename_full_path);

	    # feed transformed file (now in memory as string) into XML parser
	    $self->{'parser'}->parse($transformed_xml);
	}
	else {
	    $self->{'parser'}->parsefile($filename_full_path);
	}
    };
  
    if ($@) {

	# parsefile may either croak somewhere in XML::Parser (e.g. because
	# the document is not well formed) or die somewhere in ReadXMLFile or a
	# derived plugin (e.g. because we're attempting to process a
	# document whose DOCTYPE is not meant for this plugin). For the
	# first case we'll print a warning and continue, for the second
	# we'll just continue quietly

	print STDERR "**** Error is: $@\n";

	my ($msg) = $@ =~ /Carp::croak\(\'(.*?)\'\)/;
	if (defined $msg) {	
	    my $outhandle = $self->{'outhandle'};
	    my $plugin_name = ref ($self);
	    print $outhandle "$plugin_name failed to process $file ($msg)\n";
	}

	# reset ourself for the next document
	$self->{'section_level'}=0;
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1; # error during processing
    }
    return 1; # parsing was successful
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.xml$^;
}

sub StartDocument {$_[0]->{'PluginObj'}->xml_start_document(@_);}
sub XMLDecl {$_[0]->{'PluginObj'}->xml_xmldecl(@_);}
sub Entity {$_[0]->{'PluginObj'}->xml_entity(@_);}
sub Doctype {$_[0]->{'PluginObj'}->xml_doctype(@_);}
sub StartTag {$_[0]->{'PluginObj'}->xml_start_tag(@_);}
sub EndTag {$_[0]->{'PluginObj'}->xml_end_tag(@_);}
sub Text {$_[0]->{'PluginObj'}->xml_text(@_);}
sub PI {$_[0]->{'PluginObj'}->xml_pi(@_);}
sub EndDocument {$_[0]->{'PluginObj'}->xml_end_document(@_);}
sub Default {$_[0]->{'PluginObj'}->xml_default(@_);}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
#    use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+
    $_[0]->{'Text'} .= $_[1];
    return undef;
}


# Called at the beginning of the XML document.
sub xml_start_document {
    my $self = shift(@_);
    my ($expat) = @_;

    $self->open_document();
}

# Called for XML declarations
sub xml_xmldecl {
    my $self = shift(@_);
    my ($expat, $version, $encoding, $standalone) = @_;
}

# Called for XML entities
sub xml_entity {
  my $self = shift(@_);
  my ($expat, $name, $val, $sysid, $pubid, $ndata) = @_;
}

# Called for DOCTYPE declarations - use die to bail out if this doctype
# is not meant for this plugin
sub xml_doctype {
    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;
    die "ReadXMLFile Cannot process XML document with DOCTYPE of $name";
}


# Called for every start tag. The $_ variable will contain a copy of the
# tag and the %_ variable will contain the element's attributes.
sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
}

# Called for every end tag. The $_ variable will contain a copy of the tag.
sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
}

# Called just before start or end tags with accumulated non-markup text in
# the $_ variable.
sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;
}

# Called for processing instructions. The $_ variable will contain a copy
# of the pi.
sub xml_pi {
    my $self = shift(@_);
    my ($expat, $target, $data) = @_;
}

# Called at the end of the XML document.
sub xml_end_document {
    my $self = shift(@_);
    my ($expat) = @_;

    $self->close_document();
}

# Called for any characters not handled by the above functions.
sub xml_default {
    my $self = shift(@_);
    my ($expat, $text) = @_;
}

sub open_document {
    my $self = shift(@_);

    my $metadata = $self->{'metadata'};
    my $filename_full_path = $self->{'filename'};

    # create a new document
    my $doc_obj = $self->{'doc_obj'} = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});

    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");

    my $filename_no_path = $self->{'filename_no_path'};
    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($filename_no_path,$metadata,$plugin_filename_encoding);

    $self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);
    
    # do we want other auto metadata here (see BaseImporter.read_into_doc_obj)
}

sub close_document {
    my $self = shift(@_);
    my $doc_obj = $self->{'doc_obj'};

    # do we want other auto stuff here, see BaseImporter.read_into_doc_obj

    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    $self->extra_metadata ($doc_obj, 
			   $doc_obj->get_top_section(), 
			   $self->{'metadata'});
   
    # do any automatic metadata extraction
    $self->auto_extract_metadata ($doc_obj);
   
    # add an OID
    $self->add_OID($doc_obj);
    
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_metadata($doc_obj->get_top_section(), "FileFormat", "XML");

    # process the document
    $self->{'processor'}->process($doc_obj);
    
    $self->{'num_processed'} ++;
    undef $self->{'doc_obj'};
    undef $doc_obj; # is this the same as above??
}

1;




