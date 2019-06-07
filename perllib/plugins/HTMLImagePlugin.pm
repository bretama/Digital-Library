###########################################################################
#
# HTMLImagePlugin.pm -- Context-based image indexing plugin for HTML documents
#
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

# DESCRIPTION:
#
#  Extracts images and associated text and metadata from
#  web pages as individual documents for indexing. Thumbnails
#  are created from each image for browsing purposes.
#
#  Options are available for configuring the aggressiveness of the
#  associated text extraction mechanisms. A higher level of
#  aggressiveness will extract more text and consequently
#  may mean lower accuracy (precision); however, it may also 
#  retrieve more of the relevant images from the collection (recall). 
#  Lower levels of aggressiveness maybe result in slightly faster
#  collection builds at the import stage.
#
#  HTMLImagePlugin is a subclass of HTMLPlug (i.e. it will index pages also 
#  if required). It can be used in place of HTMLPlugin to index both
#  pages and their images.
#
# REQUIREMENTS:
#   
#  The ImageMagick image manipulation is used to create
#  thumbnails and extract some image metadata. (Available 
#  from http://www.imagemagick.org/)
#
#  Unix:
#    Many Linux distributions contain ImageMagick.
#
#  Windows:
#    ImageMagick can be downloaded from the website above.
#    Make sure the system path includes the ImageMagick binaries
#    before using HTMLImagePlugin.
#
#    NOTE: NT/2000/XP contain a filesystem utility 'convert.exe' 
#    with the same name as the image conversion utility. The
#    ImageMagick FAQ recommends renaming the filesystem
#    utility (e.g. to 'fsconvert.exe') to avoid this clash.
#
# USAGE:  
#
#  An image document consists of metadata elements:
#
#   OriginalFilename, FilePath, Filename, FileExt, FileSize,
#   Width, Height, URL, PageURL, ThumbURL, CacheURL, CachePageURL
#   ImageText, PageTitle
#
#  Most of these are only useful in format strings (e.g. ThumbURL, 
#  Filename, URL, PageURL, CachePageURL). 
#
#  ImageText, as the name suggests contains the indexable text.
#  (unless using the -document_text plugin option)
#
#  Since image documents are made up of metadata elements 
#  alone, format strings are needed to display them properly. 
#  NOTE: The receptionist will only display results (e.g. thumbnails)
#  in 4 columns if the format string begins with "<td><table>".
#
#  The example below takes the user to the image within the
#  source HTML document rather than using a format string
#  on DocumentText to display the image document itself.
#
#  Example collect.cfg:
#
#   ...
#
#   indexes document:ImageText document:text
#   defaultindex document:ImageText
#  
#   collectionmeta .document:ImageText "images"
#   collectionmeta .document:text "documents"
#
#   ...
#
#   plugin HTMLImagePlugin -index_pages -aggressiveness 6
#
#   ...
#  
#   format SearchVList '<td>{If}{[Title],[link][icon]&nbsp;[Title][[/link],
#    <table><tr><td align="center"><a href="[CachePageURL]">
#    <img src="[ThumbURL]"></a></td></tr><tr><td align="center">
#    <a href="[CachePageURL]"><font size="-1">[OriginalFilename]</font></a>
#    <br>[Width]x[Height]</td></tr></table>}</td>'
#
#   ...
#
 
package HTMLImagePlugin;

use HTMLPlugin;
use ghtml;
use unicode;
use util;
use strict; # 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @HTMLImagePlugin::ISA = qw( HTMLPlugin );
}

my $aggressiveness_list = 
    [ { 'name' => "1",
	'desc' => "{HTMLImagePlugin.aggressiveness.1}" },
      { 'name' => "2",
	'desc' => "{HTMLImagePlugin.aggressiveness.2}" },
      { 'name' => "3",
	'desc' => "{HTMLImagePlugin.aggressiveness.3}" },
      { 'name' => "4",
	'desc' => "{HTMLImagePlugin.aggressiveness.4}" },
      { 'name' => "5",
	'desc' => "{HTMLImagePlugin.aggressiveness.5}" },
      { 'name' => "6",
	'desc' => "{HTMLImagePlugin.aggressiveness.6}" },
      { 'name' => "7",
	'desc' => "{HTMLImagePlugin.aggressiveness.7}" },
      { 'name' => "8",
	'desc' => "{HTMLImagePlugin.aggressiveness.8}" },
      { 'name' => "9",
	'desc' => "{HTMLImagePlugin.aggressiveness.9}" } ];

my $arguments =
    [ { 'name' => "aggressiveness",
	'desc' => "{HTMLImagePlugin.aggressiveness}",
	'type' => "int",
	'list' => $aggressiveness_list,
	'deft' => "3",
	'reqd' => "no" },
      { 'name' => "index_pages",
	'desc' => "{HTMLImagePlugin.index_pages}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "no_cache_images",
	'desc' => "{HTMLImagePlugin.no_cache_images}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "min_size",
	'desc' => "{HTMLImagePlugin.min_size}",
	'type' => "int",
	'deft' => "2000",
	'reqd' => "no" },
      { 'name' => "min_width",
	'desc' => "{HTMLImagePlugin.min_width}",
	'type' => "int",
	'deft' => "50",
	'reqd' => "no" },
      { 'name' => "min_height",
	'desc' => "{HTMLImagePlugin.min_height}",
	'type' => "int",
	'deft' => "50",
	'reqd' => "no" },
      { 'name' => "thumb_size",
	'desc' => "{HTMLImagePlugin.thumb_size}",
	'type' => "int",
	'deft' => "100",
	'reqd' => "no" },
      { 'name' => "convert_params",
	'desc' => "{HTMLImagePlugin.convert_params}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "min_near_text",
	'desc' => "{HTMLImagePlugin.min_near_text}",
	'type' => "int",
	'deft' => "10",
	'reqd' => "no" },
      { 'name' => "max_near_text",
	'desc' => "{HTMLImagePlugin.max_near_text}",
	'type' => "int",
	'deft' => "400",
	'reqd' => "no" },
      { 'name' => "smallpage_threshold",
	'desc' => "{HTMLImagePlugin.smallpage_threshold}",
	'type' => "int",
	'deft' => "2048",
	'reqd' => "no" },
      { 'name' => "textrefs_threshold",
	'desc' => "{HTMLImagePlugin.textrefs_threshold}",
	'type' => "int",
	'deft' => "2",
	'reqd' => "no" },
      { 'name' => "caption_length",
	'desc' => "{HTMLImagePlugin.caption_length}",
	'type' => "int",
	'deft' => "80",
	'reqd' => "no" },
      { 'name' => "neartext_length",
	'desc' => "{HTMLImagePlugin.neartext_length}",
	'type' => "int",
	'deft' => "300",
	'reqd' => "no" },
      { 'name' => "document_text",
	'desc' => "{HTMLImagePlugin.document_text}",
	'type' => "flag",
	'reqd' => "no" } ];

my $options = { 'name'     => "HTMLImagePlugin",
		'desc'     => "{HTMLImagePlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new HTMLPlugin($pluginlist, $inputargs, $hashArgOptLists);

    # init class variables
    $self->{'textref'} = undef; # init by read_file fn
    $self->{'htdoc_obj'} = undef; # init by process fn
    $self->{'htpath'} = undef; # init by process fn
    $self->{'hturl'} = undef; # init by process fn
    $self->{'plaintext'} = undef; # HTML stripped version - only init if needed by raw_neartext sub
    $self->{'smallpage'} = 0; # set by process fn
    $self->{'images_indexed'} = undef; # num of images indexed - if 1 or 2 then we know page is small
    $self->{'initialised'} = undef; # flag (see set_extraction_options())

    return bless $self, $class;
}

# if indexing pages, let HTMLPlugin do it's stuff
# image extraction done through read()
sub process {
    my $self = shift(@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    $self->{'imglist'} = ();
    if ( $self->{'index_pages'} ) {
	my $ok = $self->SUPER::process($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli);
	if ( ! $ok ) { return $ok }
	$self->{'htdoc_obj'} = $doc_obj;
    }
    # else use URL for referencing
    #if ( $file =~ /(.*)[\/\\]/ ) { $self->{'htpath'} = $1; } else { $self->{'htpath'} = $file; }

    $self->{'htpath'} = $base_dir if (-d $base_dir);
    if ( $file =~ /(.*)[\/\\]/ ) { $self->{'htpath'} .= "/$1"; }
    $self->{'htpath'} =~ s/\\/\//g;  # replace \ with /

    $self->{'hturl'} = "http://$file";
    $self->{'hturl'} =~ s/\\/\//g; # for windows
    ($self->{'filename'}) = $file =~ /.*[\/\\](.*)/;
    ($self->{'base_path'}) = $file =~ /(.*)[\/\\]/i;
    if ( ( -s "$base_dir/$file") <= $self->{'smallpage_threshold'} ) {
	$self->{'smallpage'} = 1;
    } else { $self->{'smallpage'} = 0; }

    if ( defined($self->{'initialised'}) ) { return 1; }
    else {
	$self->{'initialised'} = $self->set_extraction_options($base_dir =~ /^(.*?)\/import/i);
	return $self->{'initialised'};
    }
}

# get complex configuration options from configuration files
# -- $GSDLCOLLECTION/etc/HTMLImagePlugin.cfg (tag sets for aggr 2+)
# -- $GSDLHOME/etc/packages/phind/stopword/en/brown.sw (stopwords for aggr 5+)

# If there's no HTMLImagePlugin.cfg file we'll use the following default values
my $defaultcfg = '
<delimitertagset>
  <setname>Caption</setname>
  <taggroup>font</taggroup>
  <taggroup>tt</taggroup>
  <taggroup>small</taggroup>
  <taggroup>b</taggroup>
  <taggroup>i</taggroup>
  <taggroup>u</taggroup>
  <taggroup>em</taggroup>
  <taggroup>td</taggroup>
  <taggroup>li</taggroup>
  <taggroup>a</taggroup>
  <taggroup>p</taggroup>
  <taggroup>tr</taggroup>
  <taggroup>center</taggroup>
  <taggroup>div</taggroup>
  <taggroup>caption</taggroup>
  <taggroup>br</taggroup>
  <taggroup>ul</taggroup>
  <taggroup>ol</taggroup>
  <taggroup>table</taggroup>
  <taggroup>hr</taggroup>
</delimitertagset>

<delimitertagset>
  <setname>Neartext</setname>
  <taggroup>tr|hr|table|h\d|img|body</taggroup>
  <taggroup>td|tr|hr|table|h\d|img|body</taggroup>
  <taggroup>p|br|td|tr|hr|table|h\d|img|body</taggroup>
  <taggroup>font|p|i|b|em|img</taggroup>
</delimitertagset>
';

sub set_extraction_options() {
    my ($self, $collpath) = @_;
    my ($filepath);

    print {$self->{'outhandle'}} "HTMLImagePlugin: Initialising\n"
	if $self->{'verbosity'} > 1;
    # etc/HTMLImagePlugin.cfg (XML)
    # tag sets for captions and neartext
    if ( $self->{'aggressiveness'} > 1 && $self->{'aggressiveness'} != 9 ) {
	$self->{'delims'} = [];
	$self->{'cdelims'} = [];
	my ($cfg, @tagsets, $tagset, $type, @delims);

	$filepath = "$collpath/etc/HTMLImagePlugin.cfg";
	if ( open CFG, "<$filepath" ) {
	    while (<CFG>) { $cfg .= $_ }
	    close CFG;
	} else {
	    $cfg = $defaultcfg;
	}

	(@tagsets) = 
	    $cfg =~ /<delimitertagset>(.*?)<\/delimitertagset>/igs;
	foreach $tagset ( @tagsets ) {
	    ($type) = $tagset =~ /<setname>(.*?)<\/setname>/i;
	    if ( lc($type) eq "caption" ) {
		(@{$self->{'cdelims'}}) = $tagset =~ /<taggroup>(.*?)<\/taggroup>/igs;
	    }
	    elsif ( lc($type) eq "neartext" ) {
		(@{$self->{'delims'}}) = $tagset =~ /<taggroup>(.*?)<\/taggroup>/igs;
	    }
	}

	# output a warning if there seem to be no delimiters
	if ( scalar(@{$self->{'cdelims'}} == 0)) {
	    print {$self->{'outhandle'}} "HTMLImagePlugin: Warning: no caption delimiters found in $filepath\n";
	}
	if ( scalar(@{$self->{'delims'}} == 0)) {
	    print {$self->{'outhandle'}} "HTMLImagePlugin: Warning: no neartext delimiters found in $filepath\n";
	}
    }
    
    # get stop words for textual reference extraction
    # TODO: warnings scroll off. Would be best to output them again at end of import
    if ( $self->{'aggressiveness'} >=5 && $self->{'aggressiveness'} != 9 ) {
	$self->{'stopwords'} = ();
	$filepath = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "etc", "packages", "phind", "stopword", "en", "brown.sw");
	if ( open STOPWORDS, "<$filepath" ) {
	    while ( <STOPWORDS> ) {
		chomp;
		$self->{'stopwords'}{$_} = 1;
	    }
	    close STOPWORDS;
	} else {
	    print {$self->{'outhandle'}} "HTMLImagePlugin: Warning: couldn't open stopwords file at $filepath ($!)\n";
	}
	
    }

    if ( $self->{'neartext_length'} > $self->{'max_near_text'} ) {
	$self->{'max_near_text'} = $self->{'neartext_length'} * 1.33;
	print {$self->{'outhandle'}} "HTMLImagePlugin: Warning: adjusted max_text to $self->{'max_near_text'}\n";
    } 
    if ( $self->{'caption_length'} > $self->{'max_near_text'} ) {
	$self->{'max_near_text'} = $self->{'caption_length'} * 1.33;
	print {$self->{'outhandle'}} "HTMLImagePlugin: Warning: adjusted max_text to $self->{'max_near_text'}\n";
    }

    return 1;
}

# return number of files processed, undef if can't recognise, -1 if 
# cant process
# Note that $base_dir might be "" and that $file might 
# include directories
sub read {
    my ($self, $pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = (@_);
    my ($doc_obj, $section, $filepath, $imgtag, $pos, $context, $numdocs, $tndir, $imgs);
    # forward normal read (runs HTMLPlugin if index_pages T)
    my $ok =  $self->SUPER::read($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli); 
    if ( ! $ok ) { return $ok } # what is this returning??

    my $outhandle = $self->{'outhandle'};
    my $textref = $self->{'textref'};
    my $htdoc_obj = $self->{'htdoc_obj'};
    $numdocs = 0;
    $base_dir =~ /(.*)\/.*/;
    $tndir = "$1/archives/thumbnails"; # TODO: this path shouldn't be hardcoded?
    &FileUtils::makeAllDirectories($tndir) unless -e "$tndir"; 

    $imgs = \%{$self->{'imglist'}};
    my $nimgs = $self->get_img_list($textref);
    $self->{'images_indexed'} = $nimgs;
    if ( $nimgs > 0 ) {
	my @fplist = (sort { $imgs->{$a}{'pos'} <=> $imgs->{$b}{'pos'} } keys %{$imgs});
	my $i = 0;
	foreach $filepath ( @fplist ) {
	    $pos = $imgs->{$filepath}{'pos'}; 
	    $context = substr ($$textref, $pos - 50, $pos + 50); # grab context (quicker)
	    ($imgtag) = ($context =~ /(<(?:img|a|body)\s[^>]*$filepath[^>]*>)/is );
	    if (! defined($imgtag)) { $imgtag = $filepath }
	    print $outhandle "HTMLImagePlugin: extracting $filepath\n"
		if ( $self->{'verbosity'} > 1 );
	    $doc_obj = new doc ("", "indexed_doc", $self->{'file_rename_method'});
	    $section = $doc_obj->get_top_section();
	    my $prevpos = ( $i == 0 ? 0 : $imgs->{$fplist[$i - 1]}{'pos'});
	    my $nextpos = ( $i >= ($nimgs -1) ? -1 : $imgs->{$fplist[$i + 1]}{'pos'} );

	    $self->extract_image_info($imgtag, $filepath, $textref, $doc_obj, $section, $tndir, $prevpos, $nextpos);
            $processor->process($doc_obj);
	    $numdocs++;
	    $i++;
	}
	return $numdocs;
    } else {
	print $outhandle "HTMLImagePlugin: No images from $file indexed\n"
	    if ( $self->{'verbosity'} > 2 );
	return 1;
    }
    
}

# for every valid image tag
# 1. extract related text and image metadata
# 2. add this as document meta-data
# 3. add assoc image(s) as files
#
sub extract_image_info {
    my $self = shift (@_);
    my ($tag, $id, $textref, $doc_obj, $section, $tndir, $prevpos, $nextpos) = (@_);
    my ($filename, $orig_fp, $fn, $ext, $reltext, $relreltext, $crcid, $imgs,
	$thumbfp, $pagetitle, $alttext,	$filepath, $aggr);

    my $imagick_cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl";

    $aggr = $self->{'aggressiveness'};
    $imgs = \%{$self->{'imglist'}};
    $filepath = $imgs->{$id}{'relpath'}; 
    ($filename) = $filepath =~ /([^\/\\]+)$/s;
    ($orig_fp) = "$self->{'base_path'}/$filepath"; 
    $orig_fp =~ tr/+/ /;
    $orig_fp =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg; # translate %2E to space, etc
    $orig_fp =~ s/\\/\//g;
    $filepath = "$self->{'htpath'}/$filepath";
    my ($onlyfn) = $filename =~ /([^\\\/]*)$/;
    ($fn, $ext) = $onlyfn =~ /(.*)\.(.*)/;
    $fn = lc $fn; $ext = lc $ext;
    ($reltext) = "<tr><td>GifComment</td><td>" . `$imagick_cmd identify $filepath -ping -format "%c"` . "</td></tr>\n"
        if ($ext eq "gif");
    $reltext .= "<tr><td>FilePath</td><td>$orig_fp</td></tr>\n";

    if ($ENV{'GSDLOS'} =~ /^windows$/i) {
	$crcid = "$fn.$ext." . $self->{'next_crcid'}++;
    } else { 
	($crcid) = `cksum $filepath` =~ /^(\d+)/; 
    }
    
    $thumbfp = "$tndir/tn_$crcid.jpg";
    `$imagick_cmd convert -flatten -filter Hanning $self->{'convert_params'} -geometry "$self->{'thumb_size'}x$self->{'thumb_size'}>" $filepath $thumbfp` unless -e $thumbfp;
    if ( ! (-e $thumbfp) ) {
	print STDERR "HTMLImagePlugin: 'convert' failed. Check ImageMagicK binaries are installed and working correctly\n"; return 0; 
    }
    
    # shove in full text (tag stripped or unstripped) if settings require it
    if ( $aggr == 10) {
	$reltext = "<tr><td>AllPage</td><td>" . $$textref . "</td><tr>\n";   # level 10 (all text, verbatim)
    } else {
	$pagetitle = $self->get_meta_value("title", $textref);
	($alttext) = $tag =~ /\salt\s*=\s*(?:\"|\')(.+?)(?:\"|\')/is;
	if ( defined($alttext) && length($alttext) > 1) {
	    $reltext .= "<tr><td>ALTtext</td><td>$alttext</td></tr>\n"; }
	$reltext .= "<tr><td>SplitCapitalisation</td><td>" . 
	    $self->split_filepath($orig_fp) . "</td></tr>\n";

	# get caption/tag based near text (if appropriate)
	if ( $aggr > 1 ) {
	    if ( $aggr >= 2 ) {
		$reltext .= 
		    $self->extract_caption_text($tag, $textref, $prevpos, $imgs->{$id}{'pos'}, $nextpos);
		$relreltext = $reltext;
	    } 
	    # repeat the filepath, alt-text, caption, etc
	    if ( $aggr == 8 ) {
		$reltext .= $relreltext; 
	    }
	    if ( $aggr >= 3 ) {
		$reltext .= 
		    $self->extract_near_text($tag, $textref, $prevpos, $imgs->{$id}{'pos'}, $nextpos);
	    }
	
	    # get page metadata (if appropriate)
	    if ( $aggr >= 6 || ( $aggr >= 2 && 
						     ( $self->{'images_indexed'} < 2 || 
						       ($self->{'smallpage'} == 1 && $self->{'images_indexed'} < 6 )))) {	
		$reltext .= $self->get_page_metadata($textref);
	    }
	    # textual references
	    if ( $aggr  == 5 || $aggr >= 7) {
		if ( length($relreltext) > ($self->{'caption_length'} * 2) )  {
		    $reltext .= $self->get_textrefs($relreltext, $textref, $prevpos, $imgs->{$id}{'pos'}, $nextpos); }
		else {
		    $reltext .= $self->get_textrefs($reltext, $textref, $prevpos, $imgs->{$id}{'pos'}, $nextpos); 
		}
	    }
	} # aggr > 1
    } # aggr != 10
    
    $doc_obj->set_OID($crcid); 
    $doc_obj->associate_file($thumbfp, "$fn.thumb.jpg", undef, $section);
    $doc_obj->add_metadata($section, "OriginalFilename", $filename);
    $doc_obj->add_metadata($section, "FilePath", $orig_fp);
    $doc_obj->add_metadata($section, "Filename", $fn);
    $doc_obj->add_metadata($section, "FileExt", $ext);
    $doc_obj->add_metadata($section, "FileSize", $imgs->{$id}{'filesize'});
    $doc_obj->add_metadata($section, "Width", $imgs->{$id}{'width'});
    $doc_obj->add_metadata($section, "Height", $imgs->{$id}{'height'});
    $doc_obj->add_metadata($section, "URL", "http://$orig_fp");
    $doc_obj->add_metadata($section, "PageURL", $self->{'hturl'});
    $doc_obj->add_metadata($section, "PageTitle", $pagetitle);
    $doc_obj->add_metadata($section, "ThumbURL", 
			   "_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/$fn.thumb.jpg");
    $doc_obj->add_metadata($section, "FileFormat", "W3Img");

    if ( $self->{'document_text'} ) {
	$doc_obj->add_utf8_text($section, "<table border=1>\n$reltext</table>");
    } else {
	$doc_obj->add_metadata($section, "ImageText", "<table border=1>\n$reltext</table>\n");
    }
    
    if ( $self->{'index_pages'} ) {
	my ($cache_url) = "_httpdoc_&d=" . $self->{'htdoc_obj'}->get_OID();
	if ( $imgs->{$id}{'anchored'} ) {
	    my $a_name = $id;
	    $a_name =~ s/[\/\\\:\&]/_/g;
	    $cache_url .=  "#gsdl_$a_name" ;
	}
	$doc_obj->add_utf8_metadata($section, "CachePageURL", $cache_url);
    }
    if ( ! $self->{'no_cache_images'} ) {
	$onlyfn = lc $onlyfn;
	$doc_obj->associate_file($filepath, $onlyfn, undef, $section);
	$doc_obj->add_utf8_metadata($section, "CacheURL", 
			       "_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/$onlyfn");
    }
    return 1;
}

sub get_page_metadata {
    my ($self, $textref) = (@_);
    my (@rval);
    $rval[0] = $self->get_meta_value("title", $textref);
    $rval[1] = $self->get_meta_value("keywords", $textref);
    $rval[2] = $self->get_meta_value("description", $textref);
    $rval[3] = $self->{'filename'};

    return wantarray ? @rval : "<tr><td>PageMeta</td><td>@rval</td></tr>\n" ;
}

# turns LargeCatFish into Large,Cat,Fish so MG sees the separate words
sub split_filepath {
    my ($self, $filepath) = (@_);
    my (@words) = $filepath =~ /([A-Z][a-z]+)/g; 
    return join(',', @words);
}

# finds and extracts sentences
# that seem to be on the same topic
# as other related text (correlations)
# and textual references (e.g. in figure 3 ...)
sub get_textrefs {
    my ($self, $reltext, $textref, $prevpos, $pos, $nextpos) = (@_);
    my ($maxtext, $mintext, $startpos, $context_size, $context);

    my (@relwords, @refwords, %sentences, @pagemeta);

    # extract larger context
    $maxtext = $self->{'max_near_text'};
    $startpos = $pos - ($maxtext * 4);
    $context_size = $maxtext*10;
    if ($startpos < $prevpos ) { $startpos = $prevpos }
    if ($nextpos != -1 && $context_size > ( $nextpos - $startpos )) { $context_size = ($nextpos - $startpos) }
    $context = substr ( $$textref, $startpos, $context_size );
    $context =~ s/<.*?>//gs;
    $context =~ s/^.*>(.*)/$1/gs;
    $context =~ s/(.*)<.*$/$1/gs;

    # get page meta-data (if not already included)
    if ( $self->{'aggressiveness'} == 5 && ! $self->{'smallpage'} ) {
	@pagemeta = $self->get_page_metadata($textref);
	foreach my $value ( @pagemeta ) {
	    $context .= "$value."; # make each into psuedo-sentence
	}
    }

    # TODO: this list is not exhaustive
    @refwords = ( '(?:is|are)? ?(?:show(?:s|n)|demonstrate(?:d|s)|explains|features) (?:in|by|below|above|here)', 
		  '(?:see)? (?:figure|table)? (?:below|above)');    

    # extract general references
    foreach my $rw ( @refwords ) {
	while ( $context =~ /[\.\?\!\,](.*?$rw\W.*?[\.\?\!\,])/ig ) {
	    my $sentence = $1;
	    $sentence =~ s/\s+/ /g;
	    $sentences{$sentence}+=2;
	}
    }
    # extract specific (figure, table) references by number
    my ($fignum) = $context =~ /[\.\?\!].*?(?:figure|table)s?[\-\_\ \.](\d+\w*)\W.*?[\.\?\!]/ig;
    if ( $fignum ) {
	foreach my $rw ( @refwords ) {
	    while ( $context =~ /[\.\?\!](.*?(figure|table)[\-\_\ \.]$fignum\W.*?[\.\?\!])/ig ) {
		my $sentence = $1;
		$sentence =~ s/\s+/ /g;
		$sentences{$sentence}+=4;
	    }
	}
    }

    # sentences with occurances of important words
    @relwords = $reltext =~ /([a-zA-Z]{4,})/g; # take out small words
    foreach my $word ( @relwords ) {
	if ( $self->{'stopwords'}{$word} ) { next } # skip stop words
	while ( $context =~ /([^\.\?\!]*?$word\W.*?[\.\?\!])/ig ) {
	    my $sentence = $1;
	    $sentence =~ s/\s+/ /g;
	    $sentences{$sentence}++;
	}
    }
    foreach my $sentence ( keys %sentences ) {
	if ($sentences{$sentence} < $self->{'textrefs_threshold'}) {
	    delete $sentences{$sentence};
	}
    }
    my ($rval) = join "<br>\n", (keys %sentences);
    if ( $rval && length($rval) > 5 ) {
	return ( "<tr><td>TextualReferences</td><td>" . $rval . "</td></tr>\n") }
    else { return "" }
}

# handles caption extraction
# calling the extractor with different
# tags and choosing the best candidate caption
sub extract_caption_text {
    my ($self, $tag, $textref, $prevpos, $pos, $nextpos) = (@_);
    my (@neartext, $len, $hdelim, $mintext, $goodlen,
	$startpos, $context, $context_size);
    
    $mintext = $self->{'min_near_text'};
    $goodlen = $self->{'caption_length'};

    # extract a context to extract near text from (faster)
    $context_size = $self->{'max_near_text'}*3;
    $startpos = $pos - ($context_size / 2);
    if ($startpos < $prevpos ) { $startpos = $prevpos }
    if ($nextpos != -1 && $context_size > ( $nextpos - $startpos )) 
    { $context_size = ($nextpos - $startpos) }

    $context = substr ( $$textref, $startpos, $context_size );
    $context =~ s/<!--.*?-->//gs;
    $context =~ s/^.*-->(.*)/$1/gs;
    $context =~ s/(.*)<!--.*$/$1/gs;

    # try stepping through markup delimiter sets
    # and selecting the best one
    foreach $hdelim ( @{ $self->{'cdelims'} } ) {
	@neartext = $self->extract_caption($tag, $hdelim, \$context);
	$len = length(join("", @neartext));
	last if ($len >= $mintext && $len <= $goodlen);
    }
    # reject if well over reasonable length
    if ( $len > $goodlen ) {
	@neartext = [];
    }
    $neartext[0] = " " if (! defined $neartext[0]);
    $neartext[1] = " " if (! defined $neartext[1]);
    return "<tr><td>Caption</td><td>" . (join ",",  @neartext) . "</td></tr>\n"; # TODO: the | is for testing purposes
} # end extract_caption_text

# the previous section header often gives a bit
# of context to the section that the image is
# in (invariably the header is before/above the image)
# so extract the text of the closest header above the image
#
# this fn just gets all the headers above the image, within the context window
sub get_prev_header {
    my ($self, $pos, $textref) = (@_);
    my ($rhtext);
    while ( $$textref =~ /<h\d>(.*?)<\/h\d>/sig ) {
	# only headers before image
	if ((pos $$textref) < $pos) {
	    $rhtext .= "$1, ";
	}
    } 
    if ( $rhtext ) { return "Header($rhtext)" }
    else { return "" }
}

# not the most robust tag stripping 
# regexps (see perl.com FAQ) but good enough
#
# used by caption & tag-based near text algorithms
sub strip_tags {
    my ( $self, $value ) = @_;
    if ( ! defined($value) ) { $value = "" } # handle nulls
    else {
	$value =~ s/<.*?>//gs; # strip all html tags
	$value =~ s/\s+/\ /g; # remove extra whitespace
	$value =~ s/\&\w+\;//g; # remove &nbsp; etc
    }
    return $value;
}

# uses the given tag(s) to identify
# the caption near to the image
# (below, above or both below and above)
sub extract_caption {
    my ($self, $tag, $bound_tag, $contextref) = (@_);
    my (@nt, $n, $etag, $gotcap);
    return ("", "") if ( ! ($$contextref =~ /\Q$tag/) );

    $nt[0] = $`;
    $nt[1] = $';
    $gotcap = 0;

    # look before the image for a boundary tag
    ($etag, $nt[0]) = $nt[0] =~ /<($bound_tag)[\s]?.*?>(.*?)$/is;
    # if bound_tag too far from the image, then prob not caption
    # (note: have to allow for tags, so multiply by 3
    if ( $etag && length($nt[0]) < ($self->{'caption_length'} * 3) ) { 
	if ( $nt[0] =~ /<\/$etag>/si ) {
	    # the whole caption is above the image: <tag>text</tag><img>
	    ($nt[0]) =~ /<(?:$etag)[\s]?.*?>(.*?)<\/$etag>/is;
	    $nt[0] = $self->strip_tags($nt[0]);
	    if ( length($nt[0]) > $self->{'min_near_text'} ) { 
		$gotcap = 1;
		$nt[1] = ""; 
	    }

	} elsif ( $nt[1] =~ /<\/$etag>/si) {
	    # the caption tag covers image: <tag>text?<img>text?</tag>
	    ($nt[1]) = $nt[1] =~ /(.*?)<\/$etag>/si;
	    $nt[0] = $self->strip_tags($nt[0] . $nt[1]);
	    if ( length($nt[0]) > $self->{'min_near_text'} ) { 
		$gotcap = 2;
		$nt[1] = "";
	    }
	}
    }
    # else try below the image
    if ( ! $gotcap ) { 
	# the caption is after the image: <img><tag>text</tag>
	($etag, $nt[1]) = $nt[1] =~ /^.*?<($bound_tag)[\s]?.*?>(.*)/is;
	if ( $etag && $nt[1] =~ /<\/$etag>/s) {
	    ($nt[1]) = $nt[1] =~ /(.*?)<\/$etag>/si;
	    $gotcap = 3;
	    $nt[0] = "";
	    $nt[1] = $self->strip_tags($nt[1]);
	} 
    }
    if ( ! $gotcap ) { $nt[0] = $nt[1] = "" }
    else {
	# strip part-tags
	$nt[0] =~ s/^.*>//s;
	$nt[1] =~ s/<.*$//s;
    }
    my ($type);
    if ( $gotcap == 0 ) { return ("nocaption", "") }
    elsif ( $gotcap == 1 ) { $type = "captionabove:" }
    elsif ( $gotcap == 2 ) { $type = "captioncovering:" }
    elsif ( $gotcap == 3 ) { $type = "captionbelow:" }
    return ($type, $nt[0], $nt[1]);
}

# tag-based near text
# 
# tries different tag sets
# and chooses the best one
sub extract_near_text {
    my ($self, $tag, $textref, $prevpos, $pos, $nextpos) = (@_);
    my (@neartext, $len, $hdelim, $maxtext, $mintext, $goodlen,
	@bestlen, @best, $startpos, $context, $context_size,
	$dist, $bdist, $best1, $i, $nt);
    $bestlen[0] = $bestlen[1] = 0; $bestlen[2] = $bdist = 999999;
    $best[0] = $best[1] = $best[2] = "";
    $maxtext = $self->{'max_near_text'};
    $mintext = $self->{'min_near_text'};
    $goodlen = $self->{'neartext_length'}; 

    # extract a context to extract near text from (faster)
    $context_size = $maxtext*4;
    $startpos = $pos - ($context_size / 2);
    if ($startpos < $prevpos ) { $startpos = $prevpos }
    if ($nextpos != -1 && $context_size > ( $nextpos - $startpos )) 
    { $context_size = ($nextpos - $startpos) }
    $context = substr ( $$textref, $startpos, $context_size );
    $context =~ s/<!--.*?-->//gs;
    $context =~ s/^.*-->(.*)/$1/gs;
    $context =~ s/(.*)<!--.*$/$1/gs;

    # try stepping through markup delimiter sets
    # and selecting the best one
    foreach $hdelim ( @{ $self->{'delims'} } ) {
	@neartext = $self->extract_tagged_neartext($tag, $hdelim, \$context);
	$nt = join("", @neartext);
	$len = length($nt);
	# Priorities:
	# 1. Greater than mintext 
	# 2. Less than maxtext 
	# 3. Closest to goodlen
	if ( $len <= $goodlen && $len > $bestlen[0] ) {
	    $bestlen[0] = $len;
	    $best[0] = $hdelim;
	} elsif ( $len >= $maxtext && $len < $bestlen[2] ) {
	    $bestlen[2] = $len;
	    $best[2] = $hdelim;
	} elsif ( $len >= $bestlen[0] && $len <= $bestlen[2] ) {
	    $dist = abs($goodlen - $len);
	    if ( $dist < $bdist ) {
		$bestlen[1] = $len;
		$best[1] = $hdelim;
		$bdist = $dist;
	    }
	}
    }
    $best1 = 2;
    foreach $i ( 0..2 ) {
	if ( $bestlen[$i] == 999999 ) { $bestlen[$i] = 0 }
	$dist = abs($goodlen - $bestlen[$i]);
	if ( $bestlen[$i] > $mintext && $dist <= $bdist ) {
	    $best1 = $i;
	    $bdist = $dist;
	}
    }
    @neartext = $self->extract_tagged_neartext($tag, $best[$best1], \$context);
    if ( $bestlen[$best1] > $maxtext ) {
	# truncate on word boundary if too much text
	my $hmax = $maxtext / 2;
	($neartext[0]) = $neartext[0] =~ /([^\s]*.{1,$hmax})$/s;
	($neartext[1]) = $neartext[1] =~ /^(.{1,$hmax}[^\s]*)/s;
    } elsif ( $bestlen[$best1] < $mintext ) {
	# use plain text extraction if tags failed (e.g. usable tag outside context)
	print {$self->{'outhandle'}} "HTMLImagePlugin: Fallback to plain-text extraction for $tag\n" 
	    if $self->{'verbosity'} > 2;
	$neartext[0] = "<tr><td>RawNeartext</td><td>" . $self->extract_raw_neartext($tag, $textref) . "</td></tr>";
	$neartext[1] = "";
    }
    # get previous header if available
    $neartext[0] .= "<br>\n" . 
	$self->get_prev_header($pos, \$context) if ( $self->{'aggressiveness'} >= 4 );
    $neartext[0] = " " if (! defined $neartext[0]);
    $neartext[1] = " " if (! defined $neartext[1]);

    return "<tr><td>NearText</td><td>" . (join "|",  @neartext) . "</td></tr>\n"; # TODO: the | is for testing purposes
} # end extract_near_text

# actually captures tag-based
# near-text given a tag set
sub extract_tagged_neartext {
    my ($self, $tag, $bound_tag, $textref) = (@_);
    return "" if ( ! ($$textref =~ /\Q$tag/) );
    my (@nt, $delim, $pre_tag, $n);
    $nt[0] = $`;
    $nt[1] = $';

    # get text after previous image tag
    $nt[0] =~ s/.*<($bound_tag)[^>]*>(.*)/$2/is; # get rid of preceding text
    if (defined($1)) { $delim = $1 }    
    $pre_tag = $bound_tag;

    if (defined($delim)) {
	# we want to try and use the end tag of the previous delimiter
	# (put it on the front of the list)
	$pre_tag =~ s/(^|\|)($delim)($|\|)//i; # take it out
	$pre_tag =~ s/\|\|/\|/i; # replace || with |
	$pre_tag = $delim . "|" . $pre_tag; # put it on the front
    }
    
    # get text before next image tag
    $nt[1] =~ s/<\/?(?:$pre_tag)[^>]*>.*//is; # get rid of stuff after first delimiter

    # process related text
    for $n (0..1) {
	if ( defined($nt[$n]) ) {
	    $nt[$n] =~ s/<.*?>//gs; # strip all html tags
	    $nt[$n] =~ s/\s+/\ /gs; # remove extra whitespace
	    $nt[$n] =~ s/\&\w+\;//sg; # remove &nbsp; etc
	    # strip part-tags
	    if ( $n == 0 ) { $nt[0] =~ s/^.*>//s }
	    if ( $n == 1 ) { $nt[1] =~ s/<.*$//s }
	} else { $nt[$n] = ""; } # handle nulls
    }
    return @nt;
}

# this function is fall-back
# if tags aren't suitable.
#
# extracts a fixed length of characters
# either side of image tag (on word boundary)
sub extract_raw_neartext {
    my ($self, $tag, $textref) = (@_);
    my ($rawtext, $startpos, $fp);
    my $imgs = \%{$self->{'imglist'}};
    ($fp) = $tag =~ /([\w\\\/]+\.(?:gif|jpe?g|png))/is;
    if (! $fp) { return " " };
    # if the cached, plain-text version isn't there, then create it
    $self->init_plaintext($textref) unless defined($self->{'plaintext'});

    # take the closest maxtext/2 characters 
    # either side of the tag (by word boundary)
    return "" if ( ! exists $imgs->{$fp}{'rawpos'} );
    $startpos = $imgs->{$fp}{'rawpos'} - (($self->{'max_near_text'} / 2) + 20);
    if ( $startpos < 0 ) { $startpos = 0 }
    $rawtext = substr $self->{'plaintext'}, $startpos, $self->{'max_near_text'} + 20;
    $rawtext =~ s/\s\s/ /g;

    return $rawtext;
}

# init plaintext variable for HTML-stripped version 
# (for full text index/raw assoc text extraction)
sub init_plaintext {
    my ($self, $textref) = (@_);
    my ($page, $fp);
    my $imgs = \%{$self->{'imglist'}};
    $page = $$textref; # make a copy of original

    # strip tags around image filenames so they don't get zapped
    $page =~ s/<\w+\s+.*?([\w\/\\]+\.(?:gif|jpe?g|png))[^>]*>/\"$1\"/gsi;
    $page =~ s/<.*?>//gs;
    $page =~ s/&nbsp;/ /gs;
    $page =~ s/&amp;/&/gs; #TODO: more &zzz; replacements (except &lt;, $gt;)

    # get positions and strip images
    while ( $page =~ /([^\s\'\"]+\.(jpe?g|gif|png))/ig ) {
	$fp = $1;
	if ( $imgs->{$fp}{'exists'} ) {
	    $imgs->{$fp}{'rawpos'} = pos $page;
	}
	$page =~ s/\"$fp\"//gs;
    }
    $self->{'plaintext'} = $page;
}

# finds and filters images based on size 
# (dimensions, height, filesize) and existence
#
# looks for image filenames (.jpg, .gif, etc)
# and checks for existence on disk 
# (hence supports most JavaScript images)
sub get_img_list {
    my $self = shift (@_);
    my ($textref) = (@_);
    my ($filepath, $relpath, $abspath, $pos, $num, $width, $height, $filesize);
    my $imgs = \%{$self->{'imglist'}};
    while ( $$textref =~ /([^\s\'\"]+\.(jpe?g|gif|png))/ig ) {
	$filepath = $1;
	$pos = pos $$textref;
	next if ( $imgs->{$filepath}{'relpath'} );
        $relpath = $filepath;
	$relpath =~ s/^http\:\/\///; # remove http:// in case we have mirrored it
	$relpath =~ s/\\/\//g;  # replace \ with /
	$relpath =~ s/^\.\///s; # make "./filepath" into "filepath"
	$imgs->{$filepath}{'relpath'} = $relpath;
	$abspath = "$self->{'htpath'}/$relpath";

	if (! -e $abspath) { next }

	# can't modify real filepath var because it
	# then can't be located in the page for tag recognition later
	my $imagick_cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl";
	($width, $height) = 
	    `$imagick_cmd identify $abspath -ping -format "%wx%h"` =~ /^(\d*)x(\d*)$/m;
	if (! ($width && $height)) { 
	    print STDERR "HTMLImagePlugin: ($abspath) 'identify' failed. Check ImageMagicK binaries are installed and working correctly\n"; next;
	}
	$filesize = (-s $abspath);
	if ( $filesize >= $self->{'min_size'} 
	    && ( $width >= $self->{'min_width'} ) 
	    && ( $height >= $self->{'min_height'} ) ) {
	    
	   $imgs->{$filepath}{'exists'} = 1;
	   $imgs->{$filepath}{'pos'} = $pos;
	   $imgs->{$filepath}{'width'} = $width;
	   $imgs->{$filepath}{'height'} = $height;
	   $imgs->{$filepath}{'filesize'} = $filesize;
       } else {
	   print {$self->{'outhandle'}} "HTMLImagePlugin: skipping $self->{'base_path'}/$relpath: $filesize, $width x $height\n" 
	       if $self->{'verbosity'} > 2;
       }
    }
    $num = 0;
    foreach my $i ( keys %{$imgs} ) {
	if ( $imgs->{$i}{'pos'} ) {
	    $num++;
	} else { delete $imgs->{$i} }
    }
    return $num;
}

# make the text available to the read function
# by making it an object variable
sub read_file {
    my ($self, $filename, $encoding, $language, $textref) = @_;
    $self->SUPER::read_file($filename, $encoding, $language, $textref);

    # if HTMLplug has run through, then it will
    # have replaced references so we have to 
    # make a copy of the text before processing
    if ( $self->{'index_pages'} ) {
	$self->{'text'} = $$textref;
	$self->{'textref'} = \($self->{'text'});
    } else {
	$self->{'textref'} = $textref;
    }
    $self->{'plaintext'} = undef;
}

# HTMLPlugin only extracts meta-data if it is specified in plugin options
# hence a special function to do it here
sub get_meta_value {
    my ($self, $name, $textref) = @_;
    my ($value);
    $name = lc $name;
    if ($name eq "title") {
	($value) = $$textref =~ /<title>(.*?)<\/title>/is
    } else {
	my $qm = "(?:\"|\')";
	($value) = $$textref =~ /<meta name\s*=\s*$qm?$name$qm?\s+content\s*=\s*$qm?(.*?)$qm?\s*>/is
    }
    $value = "" unless $value;
    return $value;
}

# make filename an anchor reference
# so we can go straight to the image
# within the cached version of the source page
# (augment's HTMLPlugin sub)
sub replace_images {
    my $self = shift (@_);
    my ($front, $link, $back, $base_dir, 
	$file, $doc_obj, $section) = @_;
    $link =~ s/\"//g;
    my ($a_name) = $link;
    $a_name =~ s/[\/\\\:\&]/_/g;
    # keep a list so we don't repeat the same anchor
    if ( ! $self->{'imglist'}{$link}{'anchored'} ) {
	$front = "<a name=\"gsdl_$a_name\">$front";
	$back = "$back</a>";
	$self->{'imglist'}{$link}{'anchored'} = 1;
    }
    return $self->SUPER::replace_images($front, $link, $back, $base_dir, 
				     $file, $doc_obj, $section);
}

1;
