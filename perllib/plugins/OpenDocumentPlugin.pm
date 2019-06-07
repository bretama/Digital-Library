###########################################################################
#
# OpenDocumentPlugin.pm -- The Open Document plugin
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

# Processes OASIS Open Document format.
# Word processing document: .odt, template: .ott 
# Spreadsheet document: .ods, template: .ots
# Presentation document: .odp, template: .otp
# Graphics document: .odg, template: .otg
# Formulas document: .odf, template: .otf (not supported)

#This basically extracts any text out of the document, but not much else. 

# this inherits ReadXMLFile, and therefore offers -xslt option, but does
# nothing with it.

package OpenDocumentPlugin;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use ReadXMLFile;
use XML::XPath;
use XML::XPath::XMLParser;
use Cwd;
use util;
use ghtml;

sub BEGIN {
    @OpenDocumentPlugin::ISA = ('ReadXMLFile');
}

our @filesProcess = ( "content.xml" , "meta.xml" );

my $arguments = [
		 { 'name' => "process_exp",
		   'desc' => "{BaseImporter.process_exp}",
		   'type' => "regexp",
		   'deft' =>  &get_default_process_exp() }
		 ];

my $options = { 'name'     => "OpenDocumentPlugin",
		'desc'     => "{OpenDocumentPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments};

sub get_default_process_exp { return q^(?i)\.o(?:d|t)(?:t|s|p|g)$^; }

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'section'} = "";
    $self->{'office:meta'} = "";
    
    return bless $self, $class;
}

# want to use BaseImporter's version of this, not ReadXMLFile's
sub can_process_this_file {
    my $self = shift(@_);
    
    return $self->BaseImporter::can_process_this_file(@_);
}

sub get_doctype {
    my $self = shift(@_);
    
    return "manifest:manifest";
}

sub xml_doctype {
    my $self = shift(@_);
    my ($expat, $name, $sysid, $pubid, $internal) = @_;
    die "The only valid doctype is manifest, $name is not valid" if ($name ne "manifest:manifest");
}

# Called for every start tag. The $_ variable will contain a copy of the
# tag and the %_ variable will contain the element's attributes.
sub xml_start_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    my %atts  = %_;
    $self->{'office:meta'} = $element if $self->{'office:meta'} eq "Start";
    if($element eq 'office:text') {
	$self->{'collectedText'} = "";
    }elsif($element eq 'office:meta') {
	$self->{'collectedText'} = "";
	$self->{'office:meta'} = "Start";
    }elsif($element eq 'meta:document-statistic'){
	foreach my $att (keys %atts) {
	    $self->{'doc_obj'}->add_utf8_metadata("",$att,$atts{$att});
	}
	
    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;
    
    if($element eq 'office:text') {
	$self->{'doc_obj'}->add_utf8_text("",$self->{'collectedText'});
	$self->{'collectedText'} = "";
    }elsif($element eq $self->{'office:meta'}) {
	if( $self->{'collectedText'} ne "") {
	    $self->{'doc_obj'}->add_utf8_metadata("",$self->{'office:meta'},$self->{'collectedText'});
	    $self->{'doc_obj'}->add_utf8_metadata("","Title",$self->{'collectedText'}) if $self->{'office:meta'} =~ m/:title$/;
	    $self->{'doc_obj'}->add_utf8_metadata("","Language",$self->{'collectedText'}) if $self->{'office:meta'} =~ m/:language$/;
	    $self->{'doc_obj'}->add_utf8_metadata("","GENERATOR",$self->{'collectedText'}) if $self->{'office:meta'} =~ m/:generator$/;
	    
    	}
	$self->{'collectedText'} = "";
        $self->{'office:meta'} = "Start";
    }elsif($element eq 'office:meta'){
	$self->{'office:meta'} = "";
    }elsif($element eq 'office:body'){
	#some documents have text in other places that should probably be indexed if we can't find any doc text
	
	if( defined $self->{'collectedText'} && $self->{'collectedText'} ne "" && $self->{'doc_obj'}->get_text("") eq "") {
	    $self->{'doc_obj'}->add_utf8_text("",$self->{'collectedText'});
	}
    }
}

sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;
    if($_ =~ m/\w/i) {
	$self->{'collectedText'} .= "<br/>" if $self->{'collectedText'} ne "";
	$self->{'collectedText'} .= "$_";
    }
}

#trap start and end document so we do not get our doc_obj closed too soon
sub xml_start_document {}
sub xml_end_document {}

sub read {
    my $self = shift (@_);  
   
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file($filename_full_path);

    my $outhandle = $self->{'outhandle'};
    # Report that we're processing the file
    print STDERR "<Processing n='$file' p='OpenDocumentPlugin'>\n" if ($gli);
    print $outhandle "OpenDocumentPlugin: processing $file\n"
  	if ($self->{'verbosity'}) > 1;

    $file =~ s/^[\/\\]+//; # $file often begins with / so we'll tidy it up
    $self->{'file'} = $file;
    $self->{'filename'} = $filename_full_path;
    $self->{'filename_no_path'} = $filename_no_path;
    $self->{'processor'} = $processor;
    $self->{'metadata'} = $metadata;
    
    eval{
	my ($file_only) = $file =~ /([^\\\/]*)$/;
	my $tmpdir = &util::get_tmp_filename ();
	&FileUtils::makeAllDirectories ($tmpdir);
	
	$self->open_document();
	
	# save current working directory
	my $cwd = getcwd();
	chdir ($tmpdir) || die "Unable to change to $tmpdir";
	&FileUtils::copyFiles ($filename_full_path, $tmpdir);
	
	$self->unzip ("\"$file_only\"");
	foreach my $xmlFile (@OpenDocumentPlugin::filesProcess) {
	    if (-e $xmlFile) {
		$self->{'parser'}->parsefile($xmlFile);
	    }
	}
	$self->close_document($filename_full_path,$file_only);
	
	chdir ($cwd) || die "Unable to change back to $cwd";
	&FileUtils::removeFilesRecursive ($tmpdir);
	
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
	    my $plugin_name = ref ($self);
	    print $outhandle "$plugin_name failed to process $file ($msg)\n";
	}

	# reset ourself for the next document
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1; # error during processing
    }

    return 1;
}

sub unzip {
    my $self = shift (@_);
    my ($file) = @_;

    system ("unzip $file");
    &FileUtils::removeFiles ($file) if -e $file;
}

sub close_document() {
    my $self = shift(@_);
    my ($filename,$file_only) = @_;
    
    my $doc_obj = $self->{'doc_obj'};  
    my $mimetype = $self->get_mimetype();

    $file_only = $doc_obj->get_assocfile_from_sourcefile(); # url-encoded filename in archives
    $doc_obj->associate_file($filename, $file_only, $mimetype, "");
    $doc_obj->associate_file("Thumbnails/thumbnail.png", "thumbnail.png", "image/png", "");
    my $doc_ext = $filename;
    $doc_ext =~ s/.*\.od(.)/od$1/;
    
    # We use set instead of add here because we only want one value
    $doc_obj->set_utf8_metadata_element("", "FileFormat", "Open Document");

    #setup to doclink thingi
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_metadata ("", "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_metadata ("", "srclinkFile", $doc_obj->get_sourcefile());
    $doc_obj->add_utf8_metadata ("", "srcicon",  "<img border=\"0\" align=\"absmiddle\" src=\"_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/thumbnail.png\" alt=\"View the Open document\" title=\"View the Open document\">"); 

	my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file_only,$self->{'metadata'},$plugin_filename_encoding);

    $self->set_Source_metadata($doc_obj, $filename, $filename_encoding);
    $doc_obj->set_utf8_metadata_element("", "FileSize", (-s $filename));
     
    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    $self->extra_metadata ($doc_obj, 
			   $doc_obj->get_top_section(), 
			   $self->{'metadata'});
    
    # add a Title if none has been found yet
    $self->title_fallback($doc_obj,"",$file_only);
   
    # add an OID
    $self->add_OID($doc_obj);
    
    $doc_obj->add_utf8_metadata("", "Plugin", "$self->{'plugin_type'}");

    # process the document
    $self->{'processor'}->process($doc_obj);
    
    $self->{'num_processed'} ++;
    return 1;
}

sub get_mimetype(){
    my $filename = "mimetype";
    if (!open (FILEIN,"<$filename")){
   	print STDERR "Warning: unable to open the $filename\n";
	return "Unknown OpenDocument Format";
    }
    else {
	my $text = "";
	while (defined (my $line = <FILEIN>)) {
	   $text .= $line;   
	}
	close(FILEIN);
	return $text;
    }
}
1;




