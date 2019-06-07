###########################################################################
#
# MARCPlugin.pm -- basic MARC plugin
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2002 New Zealand Digital Library Project
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

package MARCPlugin;

use SplitTextFile;
use MetadataRead;

use Encode;

use unicode;
use util;
use marcmapping;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# methods defined in superclasses that have the same signature take
# precedence in the order given in the ISA list. We want MetaPlugins to
# call MetadataRead's can_process_this_file_for_metadata(), rather than
# calling BaseImporter's version of the same method, so list inherited 
# superclasses in this order.
sub BEGIN {
    @MARCPlugin::ISA = ('MetadataRead', 'SplitTextFile'); 
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
}

my $arguments = 
    [ { 'name' => "metadata_mapping",
	'desc' => "{common.deprecated} {MARCPlugin.metadata_mapping}",
	'type' => "string",
	'deft' => "",
	'hiddengli' => "yes", # deprecated in favour of 'metadata_mapping_file'
	'reqd' => "no" },
      { 'name' => "metadata_mapping_file",
	'desc' => "{MARCXMLPlugin.metadata_mapping_file}",
	'type' => "string",
	'deft' => "marc2dc.txt",
	'reqd' => "no" },
      { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_split_exp() } 
      ];

my $options = { 'name'     => "MARCPlugin",
		'desc'     => "{MARCPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };

require MARC::Record;  
require MARC::Batch;  
#use MARC::Record;  
#use MARC::Batch;

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
 
	# this does nothing yet, but if member vars are ever added
	# to MetadataRead, will need to do this anyway:
	#new MetadataRead($pluginlist, $inputargs, $hashArgOptLists);
    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about the options
	return bless $self, $class;
    }
    # 'metadata_mapping' was used in two ways in the plugin: as a plugin
    # option (filename) and as a datastructure to represent the mapping.
    # In MARXXMLPlug (written later) the two are separated: filename is
    # represented through 'metadata_mapping_file' and the data-structure
    # mapping left as 'metadata_mapping'
    # 'metadata_mapping' still present (but hidden in GLI) for
    # backwards compatibility, but 'metadata_mapping_file' is used by
    # preference

    if ($self->{'metadata_mapping'} ne "") {
	print STDERR "MARCPlugin WARNING:: the metadata_mapping option is set but has been deprecated. Please use metadata_mapping_file option instead\n";
	# If the old version is set, use it. 
	$self->{'metadata_mapping_file'} = $self->{'metadata_mapping'};
    }
    $self->{'metadata_mapping'} = undef;
    $self->{'type'} = "";
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    ## the mapping file has already been loaded
    if (defined $self->{'metadata_mapping'} ){ 
	$self->SUPER::init(@_);
	return;
    }

    # read in the metadata mapping files
    my $mm_files = &util::locate_config_files($self->{'metadata_mapping_file'});
    if (scalar(@$mm_files)==0)
    {
	my $msg = "MARCPlugin ERROR: Can't locate mapping file \"" .
	    $self->{'metadata_mapping_file'} . "\".\n " .
		"    No metadata will be extracted from MARC files.\n";

	print $outhandle $msg;
	print $failhandle $msg;
	$self->{'metadata_mapping'} = undef;
	# We pick up the error in process() if there is no $mm_file
	# If we exit here, then pluginfo.pl will exit too!
    }
    else {
	$self->{'metadata_mapping'} = &marcmapping::parse_marc_metadata_mapping($mm_files, $outhandle);
    }

    ##map { print STDERR $_."=>".$self->{'metadata_mapping'}->{$_}."\n"; } keys %{$self->{'metadata_mapping'}};

    $self->SUPER::init(@_);
}



sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)(\.marc)$^;
}


sub get_default_split_exp {
    # \r\n for msdos eol, \n for unix
    return q^\r?\n\s*\r?\n|\[\w+\]Record type: USmarc^;
}



# The bulk of this function is based on read_line in multiread.pm
# Unable to use read_line original because it expects to get its input
# from a file.  Here the line to be converted is passed in as a string

sub to_utf8
{
    my $self = shift (@_);
    my ($encoding, $line) = @_;

    if ($encoding eq "utf8") {
	# nothing needs to be done
	#return $line;
    } elsif ($encoding eq "iso_8859_1") {
	# we'll use ascii2utf8() for this as it's faster than going
	# through convert2unicode()
	#return &unicode::ascii2utf8 (\$line);
	$line = &unicode::ascii2utf8 (\$line);
    } else {

    # everything else uses unicode::convert2unicode
    $line = &unicode::unicode2utf8 (&unicode::convert2unicode ($encoding, \$line));
    }
    # At this point $line is a binary byte string
    # => turn it into a Unicode aware string, so full
    # Unicode aware pattern matching can be used.
    # For instance: 's/\x{0101}//g' or '[[:upper:]]'

    return decode ("utf8", $line);
}


sub read_file {
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;

    my $outhandle = $self->{'outhandle'};
    
    if (! defined($self->{'metadata_mapping'}))
    {
	# print a warning
	print $outhandle "MARCPlugin: no metadata mapping file! Can't extract metadata from $filename\n";
    }

    $self->{'readfile_encoding'}->{$filename} = $encoding;

       
    if (!-r $filename)
    {
	print $outhandle "Read permission denied for $filename\n" if $self->{'verbosity'};
	return;
    }

    ##handle ascii marc
    #test whether this is ascii marc file 
    if (open (FILE, $filename)) {
	while (defined (my $line = <FILE>)) {
	    $$textref .= $line;
	   if ($line =~ /\[\w+\]Record type:/){
	       undef $/;
	       $$textref .= <FILE>;
	       $/ = "\n";
	       $self->{'type'} = "ascii";
	       close FILE;
	       return;
	   }
	}
	close FILE;	
    }

      
    $$textref = "";
    my @marc_entries = ();
 
    my $batch = new MARC::Batch( 'USMARC', $filename );
    while ( my $marc = $batch->next ) 
    {
      	push(@marc_entries,$marc);
	$$textref .= $marc->as_formatted();
	$$textref .= "\n\n"; # for SplitTextFile - see default_split_exp above...
    }

    $self->{'marc_entries'}->{$filename} = \@marc_entries;
}



# do plugin specific processing of doc_obj
# This gets done for each record found by SplitTextFile in marc files.
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    my $filename = &util::filename_cat($base_dir, $file);

    my $cursection = $doc_obj->get_top_section();

    # Add fileFormat as the metadata
    $doc_obj->add_metadata($cursection, "FileFormat", "MARC");
    
    my $marc_entries = $self->{'marc_entries'}->{$filename};
    my $marc = shift(@$marc_entries);

    my $encoding = $self->{'readfile_encoding'}->{$filename};
    if (defined ($self->{'metadata_mapping'}) ) {
	if ($self->{'type'} ne "ascii" ){   
	    $self->extract_metadata ($marc, $metadata, $encoding, $doc_obj, $cursection);
	}
	else{
	    $self->extract_ascii_metadata ($$textref,$metadata,$doc_obj, $cursection);
	}
    }

    # add spaces after the sub-field markers, for word boundaries
    $$textref =~ s/^(.{6} _\w)/$1 /gm;

    # add text to document object
    $$textref =~ s/</&lt;/g;
    $$textref =~ s/>/&gt;/g;

    $$textref = $self->to_utf8($encoding,$$textref);

    print $outhandle "  Adding Marc Record:\n",substr($$textref,0,40), " ...\n"
	if $self->{'verbosity'} > 2;

    # line wrapping
    $$textref = &wrap_text_in_columns($$textref, 64);
    $$textref = "<pre>\n" . $$textref . "</pre>\n"; # HTML formatting...

    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}

sub wrap_text_in_columns
{
    my ($text, $columnwidth) = @_;
    my $newtext = "";
    my $linelength = 0;
    
    # Break the text into words, and display one at a time
    my @words = split(/ /, $text);

    foreach my $word (@words) {
	# If printing this word would exceed the column end, start a new line
	if (($linelength + length($word)) >= $columnwidth) {
	    $newtext .= "\n";
	    $linelength = 0;
	}
	
	# Write the word
	$newtext .= " $word";
	if ($word =~ /\n/) {
	    $linelength = 0;
	} else {
	    $linelength = $linelength + length(" $word");
	}
    }

    $newtext .= "\n";
    return $newtext;
}

sub extract_metadata
{
    my $self = shift (@_);
 
    my ($marc, $metadata, $encoding, $doc_obj, $section) = @_;
    my $outhandle = $self->{'outhandle'};

    if (!defined $marc){
	return;
    }

    my $metadata_mapping = $self->{'metadata_mapping'};;

    foreach my $marc_field ( sort keys %$metadata_mapping )
    {
	my $gsdl_field = $metadata_mapping->{$marc_field};
	
	# have we got a subfield?
	my $subfield = undef;
	if ($marc_field =~ /(\d\d\d)(?:\$|\^)?(\w)/){
	    $marc_field = $1;
	    $subfield = $2;
	}

	foreach my $meta_value_obj ($marc->field($marc_field)) {
	    my $meta_value;
	    if (defined($subfield)) {
		$meta_value = $meta_value_obj->subfield($subfield);
	    } else {
		$meta_value = $meta_value_obj->as_string();
	    }
	    if (defined $meta_value) {
		# Square brackets in metadata values need to be escaped so they don't confuse Greenstone/GLI

		# Important!  Check that this really works!! In MARCXMLPlugin
		# it maps these characters to \\\\[ \\\\]

		$meta_value =~ s/\[/&\#091;/g;
		$meta_value =~ s/\]/&\#093;/g;
		my $metavalue_str = $self->to_utf8($encoding, $meta_value);
		$doc_obj->add_utf8_metadata ($section, $gsdl_field, $metavalue_str);
	    }
	}
    }
}


sub extract_ascii_metadata 
{
    my $self = shift (@_);

    my ($text, $metadata,$doc_obj, $section) = @_;
    my $outhandle = $self->{'outhandle'};
    my $metadata_mapping = $self->{'metadata_mapping'};
    ## get fields
    my @fields = split(/[\n\r]+/,$text);
    my $marc_mapping ={};

    foreach my $field (@fields){
	if ($field ne ""){
	    $field =~ /^(\d\d\d)\s/;
	    my $code = $1;
	    $field = $'; #'
	    ##get subfields
	    my @subfields = split(/\$/,$field);
	    my $i=0;
	    $marc_mapping->{$code} = [];  
	    foreach my $subfield (@subfields){
		if ($i == 0){
		    ##print STDERR $subfield."\n";
		    push(@{$marc_mapping->{$code}},"info");
		    push(@{$marc_mapping->{$code}},$subfield);
		    	 
		    $i++;
		} 
		 else{
		     $subfield =~ /(\w)\s/;
		     ##print STDERR "$1=>$'\n";
		     push(@{$marc_mapping->{$code}},$1);
                     push(@{$marc_mapping->{$code}},$'); #'
		 }
	    }
	}
    }


     foreach my $marc_field ( keys %$metadata_mapping )
    {
		
	my $matched_field = $marc_mapping->{$marc_field};
 	my $subfield = undef;

	if (defined $matched_field){
	    ## test whether this field has subfield
	    if ($marc_field =~ /\d\d\d(\w)/){
		$subfield = $1;
	    }
	    my $metaname = $metadata_mapping->{$marc_field};
 
	    my $metavalue;
	    if (defined $subfield){
		my %mapped_subfield = {@$matched_field};
		$metavalue = $mapped_subfield{$subfield};
	    }
	    else{ ## get all values except info
		my $i =0;
		foreach my $value (@$matched_field){
		    if ($i%2 != 0 and $i != 1){
			$metavalue .= $value." ";
		    }
		    $i++;
		}
	    }
	    
	    ## escape [ and ]
	    $metavalue =~ s/\[/\\\[/g;
	    $metavalue =~ s/\]/\\\]/g;
	    ##print STDERR  "$metaname=$metavalue\n";
   	    $doc_obj->add_metadata ($section, $metaname, $metavalue) ;		 	
	}
       
    }

}


1;
