###########################################################################
#
# HBPlugin.pm --
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

# plugin which processes an HTML book directory

# This plugin is used by the Humanity Library collections and does not handle
# input encodings other than ascii or extended ascii

# this code is kind of ugly and could no doubt be made to run faster, by leaving
# it in this state I hope to encourage people to make their collections use
# HBSPlug instead ;-)

# Use HBSPlug if creating a new collection and marking up files like the
# Humanity Library collections. HBSPlug accepts all input encodings but
# expects the marked up files to be cleaner than those used by the
# Humanity Library collections

package HBPlugin;

use ghtml;
use BaseImporter;
use unicode;
use util;
use doc;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @HBPlugin::ISA = ('BaseImporter');
}
my $encoding_list =     
    [ { 'name' => "ascii",
	'desc' => "{CommonUtil.encoding.ascii}" },
      { 'name' => "iso_8859_1",
	'desc' => "{HBPlugin.encoding.iso_8859_1}" } ];
 
my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "input_encoding",
	'desc' => "{ReadTextFile.input_encoding}",
	'type' => "enum",
	'deft' => "iso_8859_1",
	'list' => $encoding_list,
	'reqd' => "no" }
      ];

my $options = { 'name'     => "HBPlugin",
		'desc'     => "{HBPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseImporter($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

# this is included only to prevent warnings being printed out 
# from BaseImporter::init. The process_exp is not used by this plugin
sub get_default_process_exp {
    my $self = shift (@_);

    return "This plugin does not use a process_exp\n";
}


sub HB_read_html_file {
    my $self = shift (@_);
    my ($htmlfile, $text) = @_;

    # load in the file
    if (!open (FILE, $htmlfile)) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "ERROR - could not open $htmlfile\n";
	return;
    }

    my $foundbody = 0;
    $self->HB_gettext (\$foundbody, $text, "FILE");
    close FILE;

    # just in case there was no <body> tag
    if (!$foundbody) {
	$foundbody = 1;
	open (FILE, $htmlfile) || return;
	$self->HB_gettext (\$foundbody, $text, "FILE");	
	close FILE;
    }
    # text is in utf8
}

# converts the text to utf8, as ghtml does that for &eacute; etc.
sub HB_gettext {
    my $self = shift (@_);
    my ($foundbody, $text, $handle) = @_;
    my $outhandle = $self->{'outhandle'};

    my $line = "";
    while (defined ($line = <$handle>)) {
	# look for body tag
	if (!$$foundbody) {
	    if ($line =~ s/^.*<body[^>]*>//i) {
		$$foundbody = 1;
	    } else {
		next;
	    }
	}
	
	# check for symbol fonts
	if ($line =~ /<font [^>]*?face\s*=\s*\"?(\w+)\"?/i) {
	    my $font = $1;
	    print $outhandle "HBPlugin::HB_gettext - warning removed font $font\n" 
		if ($font !~ /^arial$/i);
	}

	$line =~ s/<\/p>//ig;   # remove </p> tags
	$line =~ s/<\/?(body|html|font)\b[^>]*>//ig; # remove any unwanted tags

	$$text .= $line;
    }
    #
    if ($self->{'input_encoding'} eq "iso_8859_1") {
	# convert to utf-8
	$$text=&unicode::unicode2utf8(&unicode::convert2unicode("iso_8859_1", $text));
    }
    # convert any alphanumeric character entities to their utf-8
    # equivalent for indexing purposes
    &ghtml::convertcharentities ($$text);

    $$text =~ s/\s+/ /g; # remove \n's
}

sub HB_clean_section {
    my $self = shift (@_);
    my ($section) = @_;

    # remove tags without a starting tag from the section
    my ($tag, $tagstart);
    while ($section =~ /<\/([^>]{1,10})>/) {
	$tag = $1;
	$tagstart = index($section, "<$tag");
	last if (($tagstart >= 0) && ($tagstart < index($section, "<\/$tag")));
	$section =~ s/<\/$tag>//;
    }
    
    # remove extra paragraph tags
    while ($section =~ s/<p\b[^>]*>\s*<p\b/<p/ig) {}
    
    # remove extra stuff at the end of the section
    while ($section =~ s/(<u>|<i>|<b>|<p\b[^>]*>|&nbsp;|\s)$//i) {}
    
    # add a newline at the beginning of each paragraph
    $section =~ s/(.)\s*<p\b/$1\n\n<p/gi;
    
    # add a newline every 80 characters at a word boundary
    # Note: this regular expression puts a line feed before
    # the last word in each section, even when it is not
    # needed.
    $section =~ s/(.{1,80})\s/$1\n/g;
    
    # fix up the image links
    $section =~ s/<img[^>]*?src=\"?([^\">]+)\"?[^>]*>/
	<center><img src=\"_httpdocimg_\/$1\"><\/center><br>/ig;
    $section =~ s/&lt;&lt;I&gt;&gt;\s*([^\.]+\.(png|jpg|gif))/
	<center><img src=\"_httpdocimg_\/$1\"><\/center><br>/ig;

    return $section;
}


sub shorten {
    my $self = shift (@_);
    my ($text) = @_;

    return "\"$text\"" if (length($text) < 100);

    return "\"" . substr ($text, 0, 50) . "\" ... \"" . 
	substr ($text, length($text)-50) . "\"";
}

# return number of files processed, undef if can't process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    # get the html filename and see if this is an HTML Book...
    my $jobnumber = $file;
    if ($file =~ /[\\\/]/) {
	($jobnumber) = $file =~ /[\\\/]([^\\\/]+)$/;
    }
    return undef unless defined $jobnumber;
    my $htmlfile = &util::filename_cat($base_dir, $file, "$jobnumber.htm");
    return undef unless -e $htmlfile;

    print STDERR "<Processing n='$file' p='HBPlugin'>\n" if ($gli);
    print $outhandle "HBPlugin: processing $file\n";

    # read in the file and do basic html cleaning (removing header etc)
    my $html = "";
    $self->HB_read_html_file ($htmlfile, \$html);
    # html is in utf8

    # create a new document
    my $doc_obj = new doc ($file, "indexed_doc", $self->{'file_rename_method'});

    # copy the book cover if it exists
    my $bookcover = &util::filename_cat($base_dir, $file, "$jobnumber.jpg");
    $doc_obj->associate_file($bookcover, "cover.jpg", "image/jpeg");
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "FileFormat", "HB");
    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), "FileSize", (-s $htmlfile));

    my $cursection = $doc_obj->get_top_section();
    
    # add metadata for top level of document
    foreach my $field (keys(%$metadata)) {
	# $metadata->{$field} may be an array reference
	if (ref ($metadata->{$field}) eq "ARRAY") {
	    map {
		$doc_obj->add_utf8_metadata($cursection, $field, $_);
	    } @{$metadata->{$field}};
	} else {
	    $doc_obj->add_utf8_metadata($cursection, $field, $metadata->{$field}); 
	}
    }

    # process the file one section at a time
    my $curtoclevel = 1;
    my $firstsection = 1;
    while (length ($html) > 0) {
	if ($html =~ s/^.*?(?:<p\b[^>]*>)?((<b>|<i>|<u>|\s)*)&lt;&lt;TOC(\d+)&gt;&gt;\s*(.*?)<p\b/<p/i) {
	    my $toclevel = $3;
	    my $title = $4;
	    my $sectiontext = "";
	    if ($html =~ s/^(.*?)((?:<p\b[^>]*>)?((<b>|<i>|<u>|\s)*)&lt;&lt;TOC\d+&gt;&gt;)/$2/i) {
		$sectiontext = $1;
	    } else {
		$sectiontext = $html;
		$html = "";
	    }

	    # remove tags and extra spaces from the title
	    $title =~ s/<\/?[^>]+>//g;
	    $title =~ s/^\s+|\s+$//g;

	    # close any sections below the current level and
	    # create a new section (special case for the firstsection)
	    while (($curtoclevel > $toclevel) ||
		   (!$firstsection && $curtoclevel == $toclevel)) {
		$cursection = $doc_obj->get_parent_section ($cursection);
		$curtoclevel--;
	    }
	    if ($curtoclevel+1 < $toclevel) {
		print $outhandle "WARNING - jump in toc levels in $htmlfile " . 
		    "from $curtoclevel to $toclevel\n";
	    }
	    while ($curtoclevel < $toclevel) {
		$curtoclevel++;
		$cursection = 
		    $doc_obj->insert_section($doc_obj->get_end_child($cursection));
	    }

	    # add the metadata to this section
	    $doc_obj->add_utf8_metadata($cursection, "Title", $title);

	    # clean up the section html
	    $sectiontext = $self->HB_clean_section($sectiontext);

	    # associate any files
	    map { $doc_obj->associate_file(&util::filename_cat ($base_dir, $file, $1), $1)
		      if /_httpdocimg_\/([^\"]+)\"/; 0; }
	         split (/(_httpdocimg_\/[^\"]+\")/, $sectiontext);

	    # add the text for this section
	    $doc_obj->add_utf8_text ($cursection, $sectiontext);
	} else {
	    print $outhandle "WARNING - leftover text\n" , $self->shorten($html), 
	    "\nin $htmlfile\n";
	    last;
	}
	$firstsection = 0;
    }

    # add a OID
    $self->add_OID($doc_obj);

    # process the document
    $processor->process($doc_obj, &util::filename_cat($file, "$jobnumber.htm"));
        
    return 1; # processed the file
}


1;
