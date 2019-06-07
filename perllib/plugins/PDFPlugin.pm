###########################################################################
#
# PDFPlugin.pm -- reasonably with-it pdf plugin
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2001 New Zealand Digital Library Project
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
package PDFPlugin;

use strict;
no strict 'refs'; # so we can use a var for filehandles (e.g. STDERR)

use ReadTextFile;
use unicode;

use AutoLoadConverters;
use ConvertBinaryFile;

@PDFPlugin::ISA = ('ConvertBinaryFile', 'AutoLoadConverters', 'ReadTextFile');


my $convert_to_list =
    [ {	'name' => "auto",
	'desc' => "{ConvertBinaryFile.convert_to.auto}" },
      {	'name' => "html",
	'desc' => "{ConvertBinaryFile.convert_to.html}" },
      {	'name' => "text",
	'desc' => "{ConvertBinaryFile.convert_to.text}" },
      { 'name' => "pagedimg_jpg",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_jpg}"},
      { 'name' => "pagedimg_gif",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_gif}"},
      { 'name' => "pagedimg_png",
	'desc' => "{ConvertBinaryFile.convert_to.pagedimg_png}"}, 
      ];


my $arguments = 
    [
     { 'name' => "convert_to",
       'desc' => "{ConvertBinaryFile.convert_to}",
       'type' => "enum",
       'reqd' => "yes",
       'list' => $convert_to_list, 
       'deft' => "html" },	 
     { 'name' => "process_exp",
       'desc' => "{BaseImporter.process_exp}",
       'type' => "regexp",
       'deft' => &get_default_process_exp(),
       'reqd' => "no" },
     { 'name' => "block_exp",
       'desc' => "{CommonUtil.block_exp}",
       'type' => "regexp",
       'deft' => &get_default_block_exp() },
     { 'name' => "metadata_fields",
       'desc' => "{HTMLPlugin.metadata_fields}",
       'type' => "string",
       'deft' => "Title,Author,Subject,Keywords" },
      { 'name' => "metadata_field_separator",
	'desc' => "{HTMLPlugin.metadata_field_separator}",
	'type' => "string",
	'deft' => "" },
     { 'name' => "noimages",
       'desc' => "{PDFPlugin.noimages}",
       'type' => "flag" },
     { 'name' => "allowimagesonly",
       'desc' => "{PDFPlugin.allowimagesonly}",
       'type' => "flag" },
     { 'name' => "complex",
       'desc' => "{PDFPlugin.complex}",
       'type' => "flag" },
     { 'name' => "nohidden",
       'desc' => "{PDFPlugin.nohidden}",
       'type' => "flag" },
     { 'name' => "zoom",
       'desc' => "{PDFPlugin.zoom}",
       'deft' => "2",
       'range' => "1,3", # actually the range is 0.5-3 
       'type' => "int" },
     { 'name' => "use_sections",
       'desc' => "{PDFPlugin.use_sections}",
       'type' => "flag" },
     { 'name' => "description_tags",
       'desc' => "{HTMLPlugin.description_tags}",
       'type' => "flag" },
      { 'name' => "use_realistic_book",
        'desc' => "{PDFPlugin.use_realistic_book}",
	'type' => "flag"}
     ];

my $options = { 'name'     => "PDFPlugin",
		'desc'     => "{PDFPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'srcreplaceable' => "yes", # Source docs in PDF can be replaced with GS-generated html		
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@$inputargs,"-title_sub");
    push(@$inputargs,'^(Page\s+\d+)?(\s*1\s+)?');

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $auto_converter_self = new AutoLoadConverters($pluginlist,$inputargs,$hashArgOptLists,["PDFBoxConverter"],1);
    my $cbf_self = new ConvertBinaryFile($pluginlist, $inputargs, $hashArgOptLists);
    my $self = BaseImporter::merge_inheritance($auto_converter_self, $cbf_self);
    
    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }
    
    $self = bless $self, $class;
    $self->{'file_type'} = "PDF";

    # these are passed through to gsConvert.pl by ConvertBinaryFile.pm
    my $zoom = $self->{"zoom"};
    $self->{'convert_options'} = "-pdf_zoom $zoom";
    $self->{'convert_options'} .= " -pdf_complex" if $self->{"complex"};
    $self->{'convert_options'} .= " -pdf_nohidden" if $self->{"nohidden"};
    $self->{'convert_options'} .= " -pdf_ignore_images" if $self->{"noimages"};
    $self->{'convert_options'} .= " -pdf_allow_images_only" if $self->{"allowimagesonly"};

    # check convert_to
    if ($self->{'convert_to'} eq "text" && $ENV{'GSDLOS'} =~ /^windows$/i) {
	print STDERR "Windows does not support pdf to text. PDFs will be converted to HTML instead\n";
	$self->{'convert_to'} = "html";
    }
    elsif ($self->{'convert_to'} eq "auto") {
	# choose html ?? is this the best option
	$self->{'convert_to'} = "html";
    }
    if ($self->{'use_realistic_book'}) {
	if ($self->{'convert_to'} ne "html") {
	    print STDERR "PDFs will be converted to HTML for realistic book functionality\n";
	    $self->{'convert_to'} = "html";
	}
    }
    # set convert_to_plugin and convert_to_ext
    $self->set_standard_convert_settings();

    my $secondary_plugin_name = $self->{'convert_to_plugin'};
    my $secondary_plugin_options = $self->{'secondary_plugin_options'};

    if (!defined $secondary_plugin_options->{$secondary_plugin_name}) {
	$secondary_plugin_options->{$secondary_plugin_name} = [];
    }
    my $specific_options = $secondary_plugin_options->{$secondary_plugin_name};

    # following title_sub removes "Page 1" added by pdftohtml, and a leading
    # "1", which is often the page number at the top of the page. Bad Luck
    # if your document title actually starts with "1 " - is there a better way?
    push(@$specific_options , "-title_sub", '^(Page\s+\d+)?(\s*1\s+)?');
    my $associate_tail_re = $self->{'associate_tail_re'};
    if ((defined $associate_tail_re) && ($associate_tail_re ne "")) {
	push(@$specific_options, "-associate_tail_re", $associate_tail_re);
    }
    push(@$specific_options, "-file_rename_method", "none");
    
    if ($secondary_plugin_name eq "HTMLPlugin") {
	# pdftohtml always produces utf8 - What about pdfbox???
	# push(@$specific_options, "-input_encoding", "utf8");
	push(@$specific_options, "-extract_language") if $self->{'extract_language'};
	push(@$specific_options, "-processing_tmp_files");
	# Instruct HTMLPlug (when eventually accessed through read_into_doc_obj) 
	# to extract these metadata fields from the HEAD META fields
	if (defined $self->{'metadata_fields'} && $self->{'metadata_fields'} =~ /\S/) {
	    push(@$specific_options,"-metadata_fields",$self->{'metadata_fields'});
	} else {
	    push(@$specific_options,"-metadata_fields","Title,GENERATOR,date,author<Creator>");
	}
	if (defined $self->{'metadata_field_separator'} && $self->{'metadata_field_separator'} =~ /\S/) {
	    push(@$specific_options,"-metadata_field_separator",$self->{'metadata_field_separator'});
	}
	if ($self->{'use_sections'} || $self->{'description_tags'}) {
	    $self->{'description_tags'} = 1;
	    push(@$specific_options, "-description_tags");
	}
	if ($self->{'use_realistic_book'}) {
	    push(@$specific_options, "-use_realistic_book");
	}
    }
    elsif ($secondary_plugin_name eq "PagedImagePlugin") {
	push(@$specific_options, "-screenviewsize", "1000");
	push(@$specific_options, "-enable_cache");
	push(@$specific_options, "-processing_tmp_files");
    }

    $self = bless $self, $class;
    $self->load_secondary_plugins($class,$secondary_plugin_options,$hashArgOptLists);
    return $self;
}

sub get_default_process_exp {
    my $self = shift (@_);

    return q^(?i)\.pdf$^;
}

# so we don't inherit HTMLPlug's block exp...
sub get_default_block_exp {
    return "";
}

sub init {
    my $self = shift (@_);

    # ConvertBinaryFile init
    $self->SUPER::init(@_);
    $self->AutoLoadConverters::init(@_);

}

sub begin {
    my $self = shift (@_);

    $self->AutoLoadConverters::begin(@_);
    $self->SUPER::begin(@_);

}

sub deinit {
    my $self = shift (@_);
    
    $self->AutoLoadConverters::deinit(@_);
    $self->SUPER::deinit(@_);

}
  
# By setting hashing to be on ga xml this ensures that two 
# PDF files that are identical except for the metadata
# to hash to different values. Without this, when each PDF
# file is converted to HTML there is a chance that they 
# will both be *identical* if the conversion utility does
# not embed the metadata in the generated HTML. This is
# certainly the case when PDFBOX is being used. 

# This change makes this convert to based plugin more 
# consistent with the original vision that the same document 
# with different metadata should
# be seen as different.

sub get_oid_hash_type {
    my $self = shift (@_);
    return "hash_on_ga_xml";
}
  
  
sub tmp_area_convert_file {

    my $self = shift (@_);
    return $self->AutoLoadConverters::tmp_area_convert_file(@_);

}

sub convert_post_process
{
    my $self = shift (@_);
    my ($conv_filename) = @_;

    my $outhandle=$self->{'outhandle'};

    #$self->{'input_encoding'} = "utf8"; # The output is always in utf8 (is it?? it is for html, but what about other types?)
    #my ($language, $encoding) = $self->textcat_get_language_encoding ($conv_filename);

    # read in file ($text will be in utf8)
    my $text = "";
    # encoding will be utf8 for html files - what about other types? will we do this step for them anyway?
    $self->read_file ($conv_filename, "utf8", "", \$text);

    # To support the use_sections option with PDFBox: Greenstone splits PDFs into pages for 
    # sections. The PDFPlugin code wants each new page to be prefixed with <a name=pagenum></a>,
    # which it then splits on to generate page-based sections. However, that's not what PDFBox 
    # generates in its HTML output. Fortunately, PDFBox does have its own page-separator: it
    # embeds each page in an extra div. The div opener is: 
    # <div style=\"page-break-before:always; page-break-after:always\">
    # The PDFPlugin now looks for this and prefixes <a name=0></a> to each such div. (The 
    # pagenumber is fixed at 0 since I'm unable to work out how to increment the pagenum during 
    # a regex substitution even with regex extensions on.) Later, when we process each section 
    # to get the pagenum, PDFBox's output for this is pre-processed by having a loopcounter 
    # that increments the pagenum for each subsequent section.

    #$pdfbox_pageheader="\<div style=\"page-break-before:always; page-break-after:always\">";
    my $loopcounter = 0; # used later on!
    $text =~ s@\<div style=\"page-break-before:always; page-break-after:always\">@<a name=$loopcounter></a><div style=\"page-break-before:always; page-break-after:always\">@g;


    # Calculate number of pages based on <a ...> tags (we have a <a name=1> etc
    # for each page).  Metadata based on this calculation not set until process()
    # 
    # Note: this is done even if we are not breaking the document into pages as it might
    # be useful to give an indication of document length in browser through setting
    # num_pages as metadata.
    # Clean html from low and hight surrogates D800–DFFF
    $text =~ s@[\N{U+D800}-\N{U+DFFF}]@\ @g;
    my @pages = ($text =~ m/\<[Aa] name=\"?\w+\"?>/ig); #<div style=\"?page-break-before:always; page-break-after:always\"?>
    my $num_pages = scalar(@pages);
    $self->{'num_pages'} = $num_pages;

    if ($self->{'use_sections'}
	&& $self->{'converted_to'} eq "HTML") {

	print $outhandle "PDFPlugin: Calculating sections...\n";

	# we have "<a name=1></a>" etc for each page
	# it may be <A name=
	my @sections = split('<[Aa] name=', $text);

	my $top_section = "";

	if (scalar (@sections) == 1) { #only one section - no split!
	    print $outhandle "PDFPlugin: warning - no sections found\n";
	} else {
	    $top_section .= shift @sections; # keep HTML header etc as top_section
	}

	# handle first section specially for title? Or all use first 100...
	
	my $title = $sections[0];
	$title =~ s/^\"?\w+\"?>//; # specific for pdftohtml...
	$title =~ s/<\/([^>]+)><\1>//g; # (eg) </b><b> - no space
	$title =~ s/<[^>]*>/ /g;
	$title =~ s/(?:&nbsp;|\xc2\xa0)/ /g; # utf-8 for nbsp...
	$title =~ s/^\s+//s;
	$title =~ s/\s+$//;
	$title =~ s/\s+/ /gs;
	$title =~ s/^$self->{'title_sub'}// if ($self->{'title_sub'});
	$title =~ s/^\s+//s; # in case title_sub introduced any...
	$title = substr ($title, 0, 100);
	$title =~ s/\s\S*$/.../;


	if (scalar (@sections) == 1) { # no sections found
	    $top_section .= $sections[0];
	    @sections=();
	} else {
	    $top_section .= "<!--<Section>\n<Metadata name=\"Title\">$title</Metadata>\n-->\n <!--</Section>-->\n";
	}

	# add metadata per section...
	foreach my $section (@sections) {
	    # section names are not always just digits, may be like "outline"
	    $section =~ s@^\"?(\w+)\"?></a>@@; # leftover from split expression...

	    $title = $1; # Greenstone does magic if sections are titled digits

	    # A title of pagenum=0 means use_sections is being applied on output from PDFBox,
	    # which didn't originally have a <a name=incremented pagenumber></a> to split each page. 
	    # Our Perl code then prefixed <a name=0></a> to it. Now need to increment the pagenum here:
	    if($loopcounter > 0 || ($title eq 0 && $loopcounter == 0)) { # implies use_sections with PDFBox
		$title = ++$loopcounter;
	    }

	    if (! defined($title) ) {
		print STDERR "no title: $section\n";
		$title = " "; # get rid of the undefined warning in next line
	    }
	    my $newsection = "<!-- from PDFPlugin -->\n<!-- <Section>\n";
	    $newsection .= "<Metadata name=\"Title\">" . $title
		. "</Metadata>\n--><br />\n";
	    $newsection .= $section;
	    $newsection .= "<!--</Section>-->\n";
	    $section = $newsection;
	}

	$text=join('', ($top_section, @sections));
    }

    if ($self->{'use_sections'}
	&& $self->{'converted_to'} eq "text") {
	print STDERR "**** When converting PDF to text, cannot apply use_sections\n";
    }


    # The following should no longer be needed, now that strings
    # read in are Unicode aware (in the Perl sense) rather than
    # raw binary strings that just happen to be UTF-8 compliant

    # turn any high bytes that aren't valid utf-8 into utf-8.
##    unicode::ensure_utf8(\$text);

    # Write it out again!
    $self->utf8_write_file (\$text, $conv_filename);
}


# do plugin specific processing of doc_obj for HTML type
sub process {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $result = $self->process_type($base_dir,$file,$doc_obj);

    # fix up the extracted date metadata to be in Greenstone date format,
    # and fix the capitalisation of 'date'
    my $cursection = $doc_obj->get_top_section();
    foreach my $datemeta (@{$doc_obj->get_metadata($cursection, "date")}) {
	$doc_obj->delete_metadata($cursection, "date", $datemeta);

	# We're just interested in the date bit, not the time
	# some pdf creators (eg "Acrobat 5.0 Scan Plug-in for Windows")
	# set a /CreationDate, and set /ModDate to 000000000. pdftohtml
	# extracts the ModDate, so it is 0...
	$datemeta =~ /(\d+)-(\d+)-(\d+)/;
	my ($year, $month, $day) = ($1,$2,$3);
	if (defined($year) && defined($month) && defined($day)) {
	    if ($year == 0) {next}
	    if ($year < 100) {$year += 1900} # just to be safe
	    if ($month =~ /^\d$/) {$month="0$month"} # single digit
	    if ($day =~ /^\d$/) {$day="0$day"} # single digit
	    my $date="$year$month$day";
	    $doc_obj->add_utf8_metadata($cursection, "Date", $date);
	}
    }

    $doc_obj->add_utf8_metadata($cursection, "NumPages", $self->{'num_pages'}) if defined $self->{'num_pages'};
    
    if ($self->{'use_sections'} && $self->{'converted_to'} eq "HTML") {
	# For gs2 we explicitly make it a paged document, cos greenstone won't get it
	# right if any section has an empty title, or one with letters in it
	if (&util::is_gs3()) {
	    # but for gs3, paged docs currently use image slider which is ugly if there are no images
	    $doc_obj->set_utf8_metadata_element ($cursection, "gsdlthistype", "Hierarchy");
	} else {
	    $doc_obj->set_utf8_metadata_element ($cursection, "gsdlthistype", "Paged");
	}
    }

    return $result;
}

1;
