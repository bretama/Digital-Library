###########################################################################
#
# OAIPlug.pm -- basic Open Archives Initiative (OAI) plugin
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
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

package OAIPlugin;

# Devel::Peek's Dump($var) function is useful for debugging encoding issues. 
#use Devel::Peek;
use Encode;
use extrametautil;
use unicode;
use util;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use ReadXMLFile;
use ReadTextFile; # needed for subroutine textcat_get_language_encoding
use metadatautil;
use MetadataRead;
use util;

# methods with identical signatures take precedence in the order given in the ISA list.
sub BEGIN {
    @OAIPlugin::ISA = ('MetadataRead', 'ReadXMLFile', 'ReadTextFile');
}

my $set_list =
    [ { 'name' => "auto",
	'desc' => "{OAIPlugin.metadata_set.auto}" },
      { 'name' => "dc",
	'desc' => "{OAIPlugin.metadata_set.dc}" } 
      ];

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "metadata_set",
	'desc' => "{OAIPlugin.metadata_set}",
	'type' => "enumstring",
	'reqd' => "no",
	'list' => $set_list,
	'deft' => "dc" },
      { 'name' => "document_field",
	'desc' => "{OAIPlugin.document_field}",
	'type' => "metadata",
	'reqd' => "no",
	'deft' => "gi.Sourcedoc" }
      ];

my $options = { 'name'     => "OAIPlugin",
		'desc'     => "{OAIPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists,1);
    my $self = new ReadXMLFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about modifying options
	return bless $self, $class;
    }
    # trim any ex. from document field iff it's the only metadata namespace prefix    
    $self->{'document_field'} =~ s/^ex\.([^.]+)$/$1/;
    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)(\.oai)$^;
}

sub get_doctype {
    my $self = shift(@_);
    
    return "OAI-PMH";
}

sub xml_start_document {
    my $self = shift (@_);
    $self->{'in_metadata_node'} = 0;
    $self->{'rawxml'} = "";
    $self->{'saved_metadata'} = {};
}

sub xml_end_document {
}

sub xml_doctype {
    my $self = shift(@_);

    my ($expat, $name, $sysid, $pubid, $internal) = @_;

    ##die "" if ($name !~ /^OAI-PMH$/);

    my $outhandle = $self->{'outhandle'};
    print $outhandle "OAIPlugin: processing $self->{'file'}\n" if $self->{'verbosity'} > 1;
    print STDERR "<Processing n='$self->{'file'}' p='OAIPlugin'>\n" if $self->{'gli'};

}


sub xml_start_tag {
    my $self = shift(@_);
    my ($expat,$element) = @_;

    my %attr_hash = %_;

    my $attr = "";
    map { $attr .= " $_=$attr_hash{$_}"; } keys %attr_hash;

    $self->{'rawxml'} .= "<$element$attr>";

    if ($element eq "metadata") {
	$self->{'in_metadata_node'} = 1;
	$self->{'metadata_xml'} = "";
    }

    if ($self->{'in_metadata_node'}) {
	$self->{'metadata_xml'} .= "<$element$attr>";
    }
}

sub xml_end_tag {
    my $self = shift(@_);
    my ($expat, $element) = @_;

    $self->{'rawxml'} .= "</$element>";

    if ($self->{'in_metadata_node'}) {
	$self->{'metadata_xml'} .= "</$element>";
    }

    if ($element eq "metadata") {
	my $textref = \$self->{'metadata_xml'};
	#my $metadata = $self->{'metadata'};
	my $metadata = $self->{'saved_metadata'};
	$self->extract_oai_metadata($textref,$metadata);

	$self->{'in_metadata_node'} = 0;	
    }


}

sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;

    $self->{'rawxml'} .= $_;

    if ($self->{'in_metadata_node'}) {
	$self->{'metadata_xml'} .= $_;
    }
}


sub metadata_read {
    my $self = shift (@_);  

    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file_for_metadata($filename_full_path);

    print STDERR "\n<Processing n='$file' p='OAIPlugin'>\n" if ($gli);
    print STDERR "OAIPlugin: processing $file\n" if ($self->{'verbosity'}) > 1;
    
    if (!$self->parse_file($filename_full_path, $file, $gli)) {
	$self->{'saved_metadata'} = undef;
	return undef;
    }

    my $verbosity = $self->{'verbosity'};
    my $new_metadata = $self->{'saved_metadata'};
    $self->{'saved_metadata'} = undef;

    # add the pretty metadata table as metadata
    my $ppmd_table = $self->{'ppmd_table'};
    $new_metadata->{'prettymd'} = $ppmd_table;
    $self->{'ppmd_table'} = undef;
      
    my $document_metadata_field = $self->{'document_field'};
    my $url_array = $new_metadata->{$document_metadata_field};
    if (!defined $url_array) {
	# try ex.
	$url_array = $new_metadata->{"ex.$document_metadata_field"};
    }
    my $num_urls = (defined $url_array) ? scalar(@$url_array) : 0;
    ##print STDERR "$num_urls urls for $file\n";
    my $srcdoc_exists = 0;
    my $srcdoc_pos = 0;
    my $filename_dir = &util::filename_head($filename_full_path);
    
    # filenames in extrametadata must be relative to current dir, as 
    # DirectoryPlugin adds path info on itself
    my ($filename_for_metadata) = $file =~ /([^\\\/]+)$/; # this assumes there will only be one record per oai file - is this always the case??
    for (my $i=0; $i<$num_urls; $i++) {
	
	if ($url_array->[$i] !~ m/^(https?|ftp):/) {
	    
	    my $src_filename = &util::filename_cat($filename_dir, $url_array->[$i]);
	    if (-e $src_filename) {
		$srcdoc_pos = $i;
		$srcdoc_exists = 1;
		# get the slashes the right way, use filename_cat
		$filename_for_metadata = &util::filename_cat($url_array->[$i]);
		last;
	    }
	}
    }
    
    if ($srcdoc_exists) {
	$self->{'oai-files'}->{$file}->{'srcdoc_exists'} = 1;
    }
    else {
	# save the rawxml for the source document
	$self->{'oai-files'}->{$file}->{'srcdoc_exists'} = 0;
	$self->{'oai-files'}->{$file}->{'rawxml'} = $self->{'rawxml'};
	$self->{'rawxml'} = "";
    }
    
    # return all the metadata we have extracted to the caller.
    # Directory plug will pass it back in at read time, so we don't need to extract it again.
    
	# Extrametadata keys should be regular expressions
	# Indexing into the extrameta data structures requires the filename's style of slashes to be in URL format
	# Then need to convert the filename to a regex, no longer to protect windows directory chars \, but for
	# protecting special characters like brackets in the filepath such as "C:\Program Files (x86)\Greenstone".
	$filename_for_metadata = &util::filepath_to_url_format($filename_for_metadata);
    $filename_for_metadata = &util::filename_to_regex($filename_for_metadata);

    # Check that we haven't already got some metadata
    if (defined &extrametautil::getmetadata($extrametadata, $filename_for_metadata)) {
	print STDERR "\n****  OAIPlugin: Need to merge new metadata with existing stored metadata: file = $filename_for_metadata\n" if $verbosity > 3;

	my $file_metadata_table = &extrametautil::getmetadata($extrametadata, $filename_for_metadata);

	foreach my $metaname (keys %{$new_metadata}) {
	    # will create new entry if one does not already exist
	    push(@{$file_metadata_table->{$metaname}}, @{$new_metadata->{$metaname}});	    
	}

    } else {
	&extrametautil::setmetadata($extrametadata, $filename_for_metadata, $new_metadata);
	&extrametautil::addmetakey($extrametakeys, $filename_for_metadata);
    }

    if ($srcdoc_exists) {	
	if (!defined &extrametautil::getmetafile($extrametafile, $filename_for_metadata)) {
		&extrametautil::setmetafile($extrametafile, $filename_for_metadata, {});
	}
	 #maps the file to full path
	&extrametautil::setmetafile_for_named_file($extrametafile, $filename_for_metadata, $file, $filename_full_path);
	
    }
    return 1;
    
}


sub read {
    my $self = shift (@_);  
    
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    if (!defined $self->{'oai-files'}->{$file}) {
	return undef;
    }
        
    my $srcdoc_exists = $self->{'oai-files'}->{$file}->{'srcdoc_exists'};
    if ($srcdoc_exists) {
	# do nothing more - all the metadata has been extracted and associated with the srcdoc
	# no more need to access details of this $file => tidy up as you go
	delete $self->{'oai-files'}->{$file};
	return 0; # not processed here, but don't pass on to rest of plugins
    }

    my $filename = $file;
    $filename = &util::filename_cat ($base_dir, $file) if $base_dir =~ /\w/;

    # Do encoding stuff on metadata
    my ($language, $encoding) = $self->textcat_get_language_encoding ($filename);

    # create a new document
    my $doc_obj = new doc ($filename, "indexed_doc", $self->{'file_rename_method'});
    my $top_section = $doc_obj->get_top_section;
    my $plugin_type = $self->{'plugin_type'};
    
    my ($filemeta) = $file =~ /([^\\\/]+)$/;
    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj, $filename, $filename_encoding);

    $doc_obj->add_utf8_metadata($top_section, "Language", $language);
    $doc_obj->add_utf8_metadata($top_section, "Encoding", $encoding);
    $doc_obj->add_utf8_metadata($top_section, "Plugin", $plugin_type);
    $doc_obj->add_metadata($top_section, "FileFormat", "OAI");
    $doc_obj->add_metadata($top_section, "FileSize", (-s $filename));
    
    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    # this will include all the metadata from the oai file that we extracted
    # during metadata_read
    $self->extra_metadata ($doc_obj, $doc_obj->get_top_section(), $metadata);
    
    # do plugin specific processing of doc_obj
    my $text = $self->{'oai-files'}->{$file}->{'rawxml'};
    delete $self->{'oai-files'}->{$file};

    unless (defined ($self->process(\$text, $pluginfo, $base_dir, $file, $metadata, $doc_obj))) {
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1;
    }
    
    # do any automatic metadata extraction
    $self->auto_extract_metadata ($doc_obj);
    
    # add an OID
    $self->add_OID($doc_obj);
        
    # process the document
    $processor->process($doc_obj);
    
    $self->{'num_processed'} ++;
    
    return 1; # processed the file
}


# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    print STDERR "<Processing n='$file' p='OAIPlugin'>\n" if ($gli);
    print $outhandle "OAIPlugin: processing $file\n"
	if $self->{'verbosity'} > 1;

    my $cursection = $doc_obj->get_top_section();

##    $self->extract_metadata ($textref, $metadata, $doc_obj, $cursection);

    # add text to document object

#    $$textref =~ s/<(.*?)>/$1 /g;
    $$textref =~ s/</&lt;/g;
    $$textref =~ s/>/&gt;/g;
    $$textref =~ s/\[/&#91;/g;
    $$textref =~ s/\]/&#93;/g;

    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}


# Improvement is to merge this with newer version in MetadataPass

sub open_prettyprint_metadata_table
{
    my $self = shift(@_);

    my $att   = "width=100% cellspacing=2";
    my $style = "style=\'border-bottom: 4px solid #000080\'";

	$self->{'ppmd_table'} = "\n<table $att $style>";
}

sub add_prettyprint_metadata_line 
{
    my $self = shift(@_);
    my ($metaname, $metavalue_utf8) = @_;

    $metavalue_utf8 = &util::hyperlink_text($metavalue_utf8);

    $self->{'ppmd_table'} .= "  <tr bgcolor=#b5d3cd>\n";
    $self->{'ppmd_table'} .= "    <td width=30%>\n";
    $self->{'ppmd_table'} .= "      $metaname\n";
    $self->{'ppmd_table'} .= "    </td>\n";
    $self->{'ppmd_table'} .= "    <td>\n";
    $self->{'ppmd_table'} .= "      $metavalue_utf8\n";
    $self->{'ppmd_table'} .= "    </td>\n";
    $self->{'ppmd_table'} .= "  </tr>\n";

}

sub close_prettyprint_metadata_table
{
    my $self = shift(@_);

    $self->{'ppmd_table'} .= "</table>\n";
}

my $qualified_dc_mapping = {
    "alternative" => "dc.title",
    "tableOfContents" => "dc.description",
    "abstract" => "dc.description",
    "created" => "dc.date",
    "valid" => "dc.date",
    "available" => "dc.date",
    "issued" => "dc.date",
    "modified" => "dc.date",
    "dateAccepted" => "dc.date",
    "dateCopyrighted" => "dc.date",
    "dateSubmitted" => "dc.date",
    "extent" => "dc.format",
    "medium" => "dc.format",
    "isVersionOf" => "dc.relation",
    "hasVersion" => "dc.relation",
    "isReplacedBy" => "dc.relation",
    "replaces" => "dc.relation",
    "isRequiredBy" => "dc.relation",
    "requires" => "dc.relation",
    "isPartOf" => "dc.relation",
    "hasPart" => "dc.relation",
    "isReferencedBy" => "dc.relation",
    "references" => "dc.relation",
    "isFormatOf" => "dc.relation",
    "hasFormat" => "dc.relation",
    "conformsTo" => "dc.relation",
    "spatial" => "dc.coverage",
    "temporal" => "dc.coverage",
# these are now top level elements in our qualified dc metadata set
#	"audience" => "dc.any",
#	"accrualMethod" => "dc.any",
#	"accrualPeriodicity" => "dc.any",
#	"accrualPolicy" => "dc.any",
#	"instructionalMethod" => "dc.any",
#	"provenance" => "dc.any",
#	"rightsHolder" => "dc.any",
    "mediator" => "dc.audience",
    "educationLevel" => "dc.audience",
    "accessRights" => "dc.rights",
    "license" => "dc.rights",
    "bibliographicCitation" => "dc.identifier"
    };

sub remap_dc_metadata
{
    my $self = shift(@_);

    my ($metaname) = @_;

    my ($prefix,$name) = ($metaname =~ m/^(.*?)\.(.*?)$/);
    
    if (defined $qualified_dc_mapping->{$name}) {
	
	return $qualified_dc_mapping->{$name}."^".$name;
    }
    
    
    return $metaname; # didn't get a match, return param passed in unchanged
}


sub extract_oai_metadata {
    my $self = shift (@_);
    my ($textref, $metadata) = @_;
    my $outhandle = $self->{'outhandle'};

    $self->open_prettyprint_metadata_table();

    # need to decode the string, else it will be double-encoded at this point
    $$textref = decode("utf-8",$$textref);

# Debugging encoding issues with Devel::Peek's Dump() which prints octal and hexcode
#    print STDERR "#### text ref: $$textref\n";
#    print STDERR "\n@@@\n";
#    Dump($$textref);
#    print STDERR "\n";

    if ($$textref =~ m/<metadata\s*>(.*?)<\/metadata\s*>/s)
    {
	my $metadata_text = $1;

	# locate and remove outermost tag (ignoring any attribute information in top-level tag)
	my ($outer_tagname,$inner_metadata_text) = ($metadata_text =~ m/<([^ >]+).*?>(.*?)<\/\1>/s);
	# split tag into namespace and tag name
	my($namespace,$top_level_prefix) = ($outer_tagname =~ m/^(.*?):(.*?)$/);
	# sometimes, the dc namespace is not specified as the prefix in each element (like <dc:title>)
	# but is rather defined in the wrapper element containing the various dc meta elements,
	# like <dc><title></title><creator></creator></dc>.
	# In such a case, we use this wrapper element as the top_level_prefix
	
	# if there was no prefix, then the tag itself becomes the top_level_prefix
	if(!defined $top_level_prefix && defined $outer_tagname) {
	    $top_level_prefix = $outer_tagname;
	}

	#process each element one by one
	while ($inner_metadata_text =~ m/<([^ >]+).*?>(.*?)<\/\1>(.*)/s)
	{

	    my $metaname = $1;
	    my $metavalue = $2;
	    $inner_metadata_text = $3;

	    # greenstone uses . for namespace, while oai uses :
	    $metaname =~ s/:/\./;
	    # if there is no namespace, then we use the outer tag name or 
	    # namespace for this element
	    if ($metaname !~ m/\./)
	    {
		$metaname = "$top_level_prefix.$metaname";
	    }
	    
	    # if metadata set is auto, leave as is, otherwise convert to 
	    # specified namespace
	    if ($self->{'metadata_set'} ne "auto") {
		if ($metaname !~ /^gi\./) { # hack to not overwrite gi metadata
		    $metaname =~ s/^([^\.]*)\./$self->{'metadata_set'}\./;
		    if ($self->{'metadata_set'} eq "dc") {
			# convert qualified dc terms to gs version, e.g.
			# spatial becomes coverage^spatial
			$metaname = $self->remap_dc_metadata($metaname);
		    }
		}
	    }

	    # uppercase the first char of the name
	    $metaname =~ s/\.(.)/\.\u$1/;
	    $metavalue =~ s/\[/&#91;/g;
	    $metavalue =~ s/\]/&#93;/g;

	    # so that GLI can see this metadata, store here as ex.dc.Title etc
	    my $ex_metaname = $metaname;
	    $ex_metaname =~ s/^ex\.//; # remove any pre-existing ex. prefix
	    $ex_metaname = "ex.$ex_metaname"; # at last can prefix ex.

	    if (defined $metadata->{$ex_metaname})
	    {
		push(@{$metadata->{$ex_metaname}},$metavalue);

	    }
	    else
	    {
		$metadata->{$ex_metaname} = [ $metavalue ];
	    }

	    # but don't add ex to the pretty print line
	    $self->add_prettyprint_metadata_line($metaname, $metavalue);
	    
	}
    }

    $self->close_prettyprint_metadata_table();
}

## we know from the file extension, so doesn't need to check the doctype
sub check_doctype {

    return 1;
}

1;
