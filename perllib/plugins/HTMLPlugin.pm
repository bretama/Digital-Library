###########################################################################
#
# HTMLPlugin.pm -- basic html plugin
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

# 
# Note that this plugin handles frames only in a very simple way
# i.e. each frame is treated as a separate document. This means
# search results will contain links to individual frames rather
# than linking to the top level frameset.
# There may also be some problems caused by the _parent target
# (it's removed by this plugin)
#

package HTMLPlugin;

use Encode;
use Unicode::Normalize 'normalize';

use ReadTextFile;
use HBPlugin;
use ghtml;
use unicode;
use util;
use FileUtils;
use XMLParser;

use File::Copy;

sub BEGIN {
    @HTMLPlugin::ISA = ('ReadTextFile', 'HBPlugin');
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan"); # for Image/Size.pm
}

use Image::Size;

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' =>  &get_default_process_exp() },
      { 'name' => "block_exp",
	'desc' => "{CommonUtil.block_exp}",
	'type' => 'regexp',
	'deft' =>  &get_default_block_exp() },
      { 'name' => "nolinks",
	'desc' => "{HTMLPlugin.nolinks}",
	'type' => "flag" },
      { 'name' => "keep_head",
	'desc' => "{HTMLPlugin.keep_head}",
	'type' => "flag" },
      { 'name' => "no_metadata",
	'desc' => "{HTMLPlugin.no_metadata}",
	'type' => "flag" },
      { 'name' => "metadata_fields",
	'desc' => "{HTMLPlugin.metadata_fields}",
	'type' => "string",
	'deft' => "Title" },
      { 'name' => "metadata_field_separator",
	'desc' => "{HTMLPlugin.metadata_field_separator}",
	'type' => "string",
	'deft' => "" },
      { 'name' => "hunt_creator_metadata",
	'desc' => "{HTMLPlugin.hunt_creator_metadata}",
	'type' => "flag" },
      { 'name' => "file_is_url",
	'desc' => "{HTMLPlugin.file_is_url}",
	'type' => "flag" },
      { 'name' => "assoc_files",
	'desc' => "{HTMLPlugin.assoc_files}",
	'type' => "regexp",
	'deft' => &get_default_block_exp() },
      { 'name' => "rename_assoc_files",
	'desc' => "{HTMLPlugin.rename_assoc_files}",
	'type' => "flag" },
      { 'name' => "title_sub",
	'desc' => "{HTMLPlugin.title_sub}",
	'type' => "string", 
	'deft' => "" },
      { 'name' => "description_tags",
	'desc' => "{HTMLPlugin.description_tags}",
	'type' => "flag" },
      # retain this for backward compatibility (w3mir option was replaced by
      # file_is_url)
      { 'name' => "w3mir",
#	'desc' => "{HTMLPlugin.w3mir}",
	'type' => "flag",
	'hiddengli' => "yes"},
      { 'name' => "no_strip_metadata_html",
	'desc' => "{HTMLPlugin.no_strip_metadata_html}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no"},
      { 'name' => "sectionalise_using_h_tags",
	'desc' => "{HTMLPlugin.sectionalise_using_h_tags}",
	'type' => "flag" },
      { 'name' => "use_realistic_book",
        'desc' => "{HTMLPlugin.tidy_html}",
	'type' => "flag"},
      { 'name' => "old_style_HDL",
        'desc' => "{HTMLPlugin.old_style_HDL}",
	'type' => "flag"},
      {'name' => "processing_tmp_files",
       'desc' => "{BaseImporter.processing_tmp_files}",
       'type' => "flag",
       'hiddengli' => "yes"}
      ];

my $options = { 'name'     => "HTMLPlugin",
		'desc'     => "{HTMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    

    my $self = new ReadTextFile($pluginlist,$inputargs,$hashArgOptLists);
    
    if ($self->{'w3mir'}) {
	$self->{'file_is_url'} = 1;
    }
    $self->{'aux_files'} = {};
    $self->{'dir_num'} = 0;
    $self->{'file_num'} = 0;
    
    return bless $self, $class;
}

# may want to use (?i)\.(gif|jpe?g|jpe|png|css|js(?:@.*)?)$
# if have eg <script language="javascript" src="img/lib.js@123">
# blocking is now done by reading through the file and recording all the 
# images and other files
sub get_default_block_exp {
    my $self = shift (@_);
    
    #return q^(?i)\.(gif|jpe?g|jpe|jpg|png|css)$^;
    return "";
}

sub get_default_process_exp {
    my $self = shift (@_);
    
    # the last option is an attempt to encode the concept of an html query ...
    return q^(?i)(\.html?|\.shtml|\.shm|\.asp|\.php\d?|\.cgi|.+\?.+=.*)$^;
}

sub store_block_files
{
    my $self =shift (@_);
    my ($filename_full_path, $block_hash) = @_;

    my $html_fname = $filename_full_path;
    
    my ($language, $content_encoding) = $self->textcat_get_language_encoding ($filename_full_path);
    $self->{'store_content_encoding'}->{$filename_full_path} = [$content_encoding, $language];
    

    # read in file ($text will be in the filesystem encoding)
    my $raw_text = "";
    $self->read_file_no_decoding($filename_full_path, \$raw_text);

    my $textref = \$raw_text;
    my $opencom = '(?:<!--|&lt;!(?:&mdash;|&#151;|--))';
    my $closecom = '(?:-->|(?:&mdash;|&#151;|--)&gt;)';
    $$textref =~ s/$opencom(.*?)$closecom//gs;

    # Convert entities to their UTF8 equivalents
    $$textref =~ s/&(lt|gt|amp|quot|nbsp);/&z$1;/go;
    $$textref =~ s/&([^;]+);/&ghtml::getcharequiv($1,1,0)/gseo; # on this occassion, want it left as utf8
    $$textref =~ s/&z(lt|gt|amp|quot|nbsp);/&$1;/go;

    my $attval = "\\\"[^\\\"]+\\\"|[^\\s>]+";
    my @img_matches = ($$textref =~ m/<img[^>]*?src\s*=\s*($attval)[^>]*>/igs);
    my @usemap_matches = ($$textref =~ m/<img[^>]*?usemap\s*=\s*($attval)[^>]*>/igs);
    my @link_matches = ($$textref =~ m/<link[^>]*?href\s*=\s*($attval)[^>]*>/igs);
    my @embed_matches = ($$textref =~ m/<embed[^>]*?src\s*=\s*($attval)[^>]*>/igs);
    my @tabbg_matches = ($$textref =~ m/<(?:body|table|tr|td)[^>]*?background\s*=\s*($attval)[^>]*>/igs);
    my @script_matches = ($$textref =~ m/<script[^>]*?src\s*=\s*($attval)[^>]*>/igs);

    if(!defined $self->{'unicode_to_original_filename'}) { 
	# maps from utf8 converted link name -> original filename referrred to by (possibly URL-encoded) src url
	$self->{'unicode_to_original_filename'} = {};
    }

    foreach my $raw_link (@img_matches, @usemap_matches, @link_matches, @embed_matches, @tabbg_matches, @script_matches) {

	# remove quotes from link at start and end if necessary
	if ($raw_link =~ m/^\"/) {
	    $raw_link =~ s/^\"//;
	    $raw_link =~ s/\"$//;
	}

	# remove any anchor names, e.g. foo.html#name becomes foo.html 
	# but watch out for any #'s that are part of entities, such as &#x3B1;
	$raw_link =~ s/([^&])\#.*$/$1/s; 

	# some links may just be anchor names
	next unless ($raw_link =~ /\S+/);

	if ($raw_link !~ m@^/@ && $raw_link !~ m/^([A-Z]:?)\\/i) {
	    # Turn relative file path into full path
	    my $dirname = &File::Basename::dirname($filename_full_path);
	    $raw_link = &FileUtils::filenameConcatenate($dirname, $raw_link);
	}
	$raw_link = $self->eval_dir_dots($raw_link);

	# this is the actual filename on the filesystem (that the link refers to)
	my $url_original_filename = $self->opt_url_decode($raw_link);

	my ($uses_bytecodes,$exceeds_bytecodes) = &unicode::analyze_raw_string($url_original_filename);

	if ($exceeds_bytecodes) {
	    # We have a link to a file name that is more complicated than a raw byte filename
	    # What we do next depends on the operating system we are on

	    if ($ENV{'GSDLOS'} =~ /^(linux|solaris)$/i) {
		# Assume we're dealing with a UTF-8 encoded filename
		$url_original_filename = encode("utf8", $url_original_filename);
	    }
	    elsif ($ENV{'GSDLOS'} =~ /^darwin$/i) {
		# HFS+ is UTF8 with decompostion
		$url_original_filename = encode("utf8", $url_original_filename);
		$url_original_filename = normalize('D', $url_original_filename); # Normalization Form D (decomposition)		
	    }
	    elsif ($ENV{'GSDLOS'} =~ /^windows$/i) {
		# Don't need to do anything as later code maps Windows
		# unicode filenames to DOS short filenames when needed		
	    }
	    else {
		my $outhandle = $self->{'outhandle'};
		print $outhandle "Warning: Unrecognized operating system ", $ENV{'GSDLOS'}, "\n";
		print $outhandle "         in raw file system encoding of: $raw_link\n";
		print $outhandle "         Assuming filesystem is UTF-8 based.\n";
		$url_original_filename = encode("utf8", $url_original_filename);
	    }
	}

	# Convert the (currently raw) link into its Unicode version. 
	# Store the Unicode link along with the url_original_filename
	my $unicode_url_original_filename = "";
	$self->decode_text($raw_link,$content_encoding,$language,\$unicode_url_original_filename);


	$self->{'unicode_to_original_filename'}->{$unicode_url_original_filename} = $url_original_filename;


	if ($url_original_filename ne $unicode_url_original_filename) {
	    my $outhandle = $self->{'outhandle'};
	    
	    print $outhandle "URL Encoding $url_original_filename\n";
	    print $outhandle " ->$unicode_url_original_filename\n";

	    # make sure not to block the file itself, as happens when an html file links to itself
		# e.g. if the current file is mary-boleyn/index.html and contains <link rel="canonical" href="index.html" />
		my $unicode_html_fname = "";
		$self->decode_text($html_fname,$content_encoding,$language,\$unicode_html_fname);		
		if($unicode_url_original_filename ne $unicode_html_fname) {
			# Allow for possibility of raw byte version and Unicode versions of file
			$self->block_filename($block_hash,$unicode_url_original_filename);
		}
	}

	# $url_original_filename = &util::upgrade_if_dos_filename($url_original_filename);
	# TODO now use unicode files in block, do we need this??
	$self->block_raw_filename($block_hash,$url_original_filename) if $url_original_filename ne $html_fname;

	# but only add the linked file to the blocklist if the current html file does not link to itself
		
    }
}

# Given a filename in any encoding, will URL decode it to get back the original filename
# in the original encoding. Because this method is intended to work out the *original* 
# filename*, it does not URL decode any filename if a file by the name of the *URL-encoded*
# string already exists in the local folder.
#
sub opt_url_decode {
    my $self = shift (@_);
    my ($raw_link) = @_;


    # Replace %XX's in URL with decoded value if required.
    # Note that the filename may include the %XX in some situations

##    if ($raw_link =~ m/\%[A-F0-9]{2}/i) {

    if (($raw_link =~ m/\%[A-F0-9]{2}/i) || ($raw_link =~ m/\&\#x[0-9A-F]+;/i) || ($raw_link =~ m/\&\#[0-9]+;/i)) {
	if (!-e $raw_link) {
	    $raw_link = &unicode::url_decode($raw_link,1);
	}
    } 
    
    return $raw_link;
}

sub read_into_doc_obj 
{
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;
        
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    # Lookup content_encoding and language worked out in file_block pass for this file
    # Store them under the local names they are nice and easy to access
    $self->{'content_encoding'} = $self->{'store_content_encoding'}->{$filename_full_path}[0];
    $self->{'language'} = $self->{'store_content_encoding'}->{$filename_full_path}[1];

    # get the input file
    my $input_filename = $file;
    my ($tailname, $dirname, $suffix) = &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");
    $suffix = lc($suffix);   
    my $tidy_filename;
    if (($self->{'use_realistic_book'}) || ($self->{'old_style_HDL'}))
    {
	# because the document has to be sectionalized set the description tags 
	$self->{'description_tags'} = 1;
	
	# set the file to be tidied
	$input_filename = &FileUtils::filenameConcatenate($base_dir,$file) if $base_dir =~ m/\w/;
	
	# get the tidied file
	#my $tidy_filename = $self->tmp_tidy_file($input_filename);
	$tidy_filename = $self->convert_tidy_or_oldHDL_file($input_filename);
	
	# derive tmp filename from input filename
	my ($tailname, $dirname, $suffix) = &File::Basename::fileparse($tidy_filename, "\\.[^\\.]+\$");
	
	# set the new input file and base_dir to be from the tidied file
	$file = "$tailname$suffix";
	$base_dir = $dirname;
    }
    
    # call the parent read_into_doc_obj
    my ($process_status,$doc_obj) = $self->SUPER::read_into_doc_obj($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli);
    if (($self->{'use_realistic_book'}) || ($self->{'old_style_HDL'}))
    {
	# now we need to reset the filenames in the doc obj so that the converted filenames are not used
	my $collect_file = &util::filename_within_collection($filename_full_path);
	$doc_obj->set_source_filename ($collect_file, $self->{'file_rename_method'}); 
	## set_source_filename does not set the doc_obj source_path which is used in archives dbs for incremental
	# build. So set it manually.
	$doc_obj->set_source_path($filename_full_path);
	my $collect_conv_file = &util::filename_within_collection($tidy_filename);
	$doc_obj->set_converted_filename($collect_conv_file);

	my $plugin_filename_encoding = $self->{'filename_encoding'};
	my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
	$self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);
    }

    delete $self->{'store_content_encoding'}->{$filename_full_path};
    $self->{'content_encoding'} = undef;

    return ($process_status,$doc_obj);
}

# do plugin specific processing of doc_obj
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    if ($ENV{'GSDLOS'} =~ m/^windows/i) {
	# this makes life so much easier... perl can cope with unix-style '/'s.
	$base_dir =~ s@(\\)+@/@g; 
	$file =~ s@(\\)+@/@g;     
    }

    my $filename = &FileUtils::filenameConcatenate($base_dir,$file);
    my $upgraded_base_dir = &util::upgrade_if_dos_filename($base_dir);
    my $upgraded_filename = &util::upgrade_if_dos_filename($filename);

    if ($ENV{'GSDLOS'} =~ m/^windows/i) {
	# And again
	$upgraded_base_dir =~ s@(\\)+@/@g;	
	$upgraded_filename =~ s@(\\)+@/@g;
	
	# Need to make sure there is a '/' on the end of upgraded_base_dir
	if (($upgraded_base_dir ne "") && ($upgraded_base_dir !~ m/\/$/)) {
	    $upgraded_base_dir .= "/";
	}
    }
    my $upgraded_file = &util::filename_within_directory($upgraded_filename,$upgraded_base_dir);
    
    # reset per-doc stuff...
    $self->{'aux_files'} = {};
    $self->{'dir_num'} = 0;
    $self->{'file_num'} = 0;

    # process an HTML file where sections are divided by headings tags (H1, H2 ...)
    # you can also include metadata in the format (X can be any number)
    # <hX>Title<!--gsdl-metadata
    #	<Metadata name="name1">value1</Metadata>
    #	...
    #	<Metadata name="nameN">valueN</Metadata>
    #--></hX>
    if ($self->{'sectionalise_using_h_tags'}) {
	# description_tags should allways be activated because we convert headings to description tags
	$self->{'description_tags'} = 1;

	my $arrSections = [];
	$$textref =~ s/<h([0-9]+)[^>]*>(.*?)<\/h[0-9]+>/$self->process_heading($1, $2, $arrSections, $upgraded_file)/isge;

	if (scalar(@$arrSections)) {
	    my $strMetadata = $self->update_section_data($arrSections, -1);
	    if (length($strMetadata)) {
		$strMetadata = '<!--' . $strMetadata . "\n-->\n</body>";
		$$textref =~ s/<\/body>/$strMetadata/ig;
	    }
	}
    }

    my $cursection = $doc_obj->get_top_section();

    $self->extract_metadata ($textref, $metadata, $doc_obj, $cursection)
	unless $self->{'no_metadata'} || $self->{'description_tags'};

    # Store URL for page as metadata - this can be used for an
    # altavista style search interface. The URL won't be valid
    # unless the file structure contains the domain name (i.e.
    # like when w3mir is used to download a website).

    # URL metadata (even invalid ones) are used to support internal
    # links, so even if 'file_is_url' is off, still need to store info

    my ($tailname,$dirname) = &File::Basename::fileparse($upgraded_file);

#    my $utf8_file = $self->filename_to_utf8_metadata($file);
#    $utf8_file =~ s/&\#095;/_/g;
#    variable below used to be utf8_file

    my $url_encoded_file = &unicode::raw_filename_to_url_encoded($tailname);
    my $utf8_url_encoded_file = &unicode::raw_filename_to_utf8_url_encoded($tailname);
    
    my $web_url = "http://";
    my $utf8_web_url = "http://";
    
    if(defined $dirname) { # local directory

        # Check for "ftp" in the domain name of the directory
        #  structure to determine if this URL should be a ftp:// URL
        # This check is not infallible, but better than omitting the
        #  check, which would cause all files downloaded from ftp sites
        #  via mirroring with wget to have potentially erroneous http:// URLs
        #  assigned in their metadata
        if ($dirname =~ /^[^\/]*ftp/i)
	{
	  $web_url = "ftp://";
	  $utf8_web_url = "ftp://";
	}
	$dirname = $self->eval_dir_dots($dirname);
	$dirname .= &util::get_dirsep() if $dirname ne ""; # if there's a directory, it should end on "/"

	# this local directory in import may need to be URL encoded like the file
	my $url_encoded_dir = &unicode::raw_filename_to_url_encoded($dirname);
	my $utf8_url_encoded_dir =  &unicode::raw_filename_to_utf8_url_encoded($dirname);
	
	# changed here
	$web_url = $web_url.$url_encoded_dir.$url_encoded_file; 
	$utf8_web_url = $utf8_web_url.$utf8_url_encoded_dir.$utf8_url_encoded_file; 
    } else {
	$web_url = $web_url.$url_encoded_file;
	$utf8_web_url = $utf8_web_url.$utf8_url_encoded_file;
    }
    $web_url =~ s/\\/\//g;
    $utf8_web_url =~ s/\\/\//g;

    if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
	print STDERR "*******DEBUG: upgraded_file:       $upgraded_file\n";
	print STDERR "*******DEBUG: adding URL metadata: $utf8_url_encoded_file\n";
	print STDERR "*******DEBUG: web url:             $web_url\n";
	print STDERR "*******DEBUG: utf8 web url:        $utf8_web_url\n";
    }


    $doc_obj->add_utf8_metadata($cursection, "URL", $web_url);
    $doc_obj->add_utf8_metadata($cursection, "UTF8URL", $utf8_web_url);

    if ($self->{'file_is_url'}) {
	$doc_obj->add_metadata($cursection, "weblink", "<a href=\"$web_url\">");
	$doc_obj->add_metadata($cursection, "webicon", "_iconworld_");
	$doc_obj->add_metadata($cursection, "/weblink", "</a>");
    }

    if ($self->{'description_tags'}) {
	# remove the html header - note that doing this here means any
	# sections defined within the header will be lost (so all <Section>
	# tags must appear within the body of the HTML)
	my ($head_keep) = ($$textref =~ m/^(.*?)<body[^>]*>/is);

	$$textref =~ s/^.*?<body[^>]*>//is;
	$$textref =~ s/(<\/body[^>]*>|<\/html[^>]*>)//isg;

	my $opencom = '(?:<!--|&lt;!(?:&mdash;|&#151;|--))';
	my $closecom = '(?:-->|(?:&mdash;|&#151;|--)&gt;)';

	my $lt = '(?:<|&lt;)';
	my $gt = '(?:>|&gt;)';
	my $quot = '(?:"|&quot;|&rdquo;|&ldquo;)';

	my $dont_strip = '';
	if ($self->{'no_strip_metadata_html'}) {
	    ($dont_strip = $self->{'no_strip_metadata_html'}) =~ s{,}{|}g;
	}

	my $found_something = 0; my $top = 1;
	while ($$textref =~ s/^(.*?)$opencom(.*?)$closecom//s) {
	    my $text = $1;
	    my $comment = $2;
	    if (defined $text) {
		# text before a comment - note that getting to here
		# doesn't necessarily mean there are Section tags in
		# the document
		$self->process_section(\$text, $upgraded_base_dir, $upgraded_file, $doc_obj, $cursection);
	    }
	    while ($comment =~ s/$lt(.*?)$gt//s) {
		my $tag = $1;
		if ($tag eq "Section") {
		    $found_something = 1;
		    $cursection = $doc_obj->insert_section($doc_obj->get_end_child($cursection)) unless $top;
		    $top = 0;
		} elsif ($tag eq "/Section") {
		    $found_something = 1;
		    $cursection = $doc_obj->get_parent_section ($cursection);
		} elsif ($tag =~ m/^Metadata name=$quot(.*?)$quot/s) {
		    my $metaname = $1;
		    my $accumulate = $tag =~ m/mode=${quot}accumulate${quot}/ ? 1 : 0;
		    $comment =~ s/^(.*?)$lt\/Metadata$gt//s;
		    my $metavalue = $1;
		    $metavalue =~ s/^\s+//;
		    $metavalue =~ s/\s+$//;
                    # assume that no metadata value intentionally includes
                    # carriage returns or HTML tags (if they're there they
                    # were probably introduced when converting to HTML from
                    # some other format).
		    # actually some people want to have html tags in their
		    # metadata.
		    $metavalue =~ s/[\cJ\cM]/ /sg;
		    $metavalue =~ s/<[^>]+>//sg
			unless $dont_strip && ($dont_strip eq 'all' || $metaname =~ m/^($dont_strip)$/);
		    $metavalue =~ s/\s+/ /sg;
		    if ($metaname =~ /\./) { # has a namespace
			$metaname = "ex.$metaname";
		    }
		    if ($accumulate) {
			$doc_obj->add_utf8_metadata($cursection, $metaname, $metavalue);
		    } else {
			$doc_obj->set_utf8_metadata_element($cursection, $metaname, $metavalue);	
		    }
		} elsif ($tag eq "Description" || $tag eq "/Description") {
		    # do nothing with containing Description tags
		} else {
		    # simple HTML tag (probably created by the conversion
		    # to HTML from some other format) - we'll ignore it and
		    # hope for the best ;-)
		}
	    }
	}
	if ($cursection ne "") {
	    print $outhandle "HTMLPlugin: WARNING: $upgraded_file contains unmatched <Section></Section> tags\n";
	}

	$$textref =~ s/^.*?<body[^>]*>//is;
	$$textref =~ s/(<\/body[^>]*>|<\/html[^>]*>)//isg;
	if ($$textref =~ m/\S/) {
	    if (!$found_something) {
		if ($self->{'verbosity'} > 2) {
		    print $outhandle "HTMLPlugin: WARNING: $upgraded_file appears to contain no Section tags so\n";
		    print $outhandle "          will be processed as a single section document\n";
		}

		# go ahead and process single-section document
		$self->process_section($textref, $upgraded_base_dir, $upgraded_file, $doc_obj, $cursection);

		# if document contains no Section tags we'll go ahead
		# and extract metadata (this won't have been done
		# above as the -description_tags option prevents it)
		my $complete_text = $head_keep.$doc_obj->get_text($cursection);
		$self->extract_metadata (\$complete_text, $metadata, $doc_obj, $cursection) 
		    unless $self->{'no_metadata'};

	    } else {
		print $outhandle "HTMLPlugin: WARNING: $upgraded_file contains the following text outside\n";
		print $outhandle "          of the final closing </Section> tag. This text will\n";
		print $outhandle "          be ignored.";

		my ($text);
		if (length($$textref) > 30) {
		    $text = substr($$textref, 0, 30) . "...";
		} else {
		    $text = $$textref;
		}
		$text =~ s/\n/ /isg;
		print $outhandle " ($text)\n";
	    }
	} elsif (!$found_something) {

	    if ($self->{'verbosity'} > 2) {
		# may get to here if document contained no valid Section
		# tags but did contain some comments. The text will have
		# been processed already but we should print the warning
		# as above and extract metadata
		print $outhandle "HTMLPlugin: WARNING: $upgraded_file appears to contain no Section tags and\n";
		print $outhandle "          is blank or empty.  Metadata will be assigned if present.\n";
	    }

	    my $complete_text = $head_keep.$doc_obj->get_text($cursection);
	    $self->extract_metadata (\$complete_text, $metadata, $doc_obj, $cursection) 
		unless $self->{'no_metadata'};
	}
	$self->replace_section_links($doc_obj);
    } else {

	# remove header and footer
	if (!$self->{'keep_head'} || $self->{'description_tags'}) {
	    $$textref =~ s/^.*?<body[^>]*>//is;
	    $$textref =~ s/(<\/body[^>]*>|<\/html[^>]*>)//isg;
	}

	$self->{'css_assoc_files'} = {};
	
	# single section document
	$self->process_section($textref, $upgraded_base_dir, $upgraded_file, $doc_obj, $cursection);
	
	#my $upgraded_filename_dirname = &File::Basename::dirname($upgraded_filename);
		
	$self->acquire_css_associated_files($doc_obj, $cursection);
	
	$self->{'css_assoc_files'} = {};
    }

    return 1;
}


sub process_heading
{
    my ($self, $nHeadNo, $strHeadingText, $arrSections, $file) = @_;
    $strHeadingText = '' if (!defined($strHeadingText));

    my $strMetadata = $self->update_section_data($arrSections, int($nHeadNo));

    my $strSecMetadata = '';
    while ($strHeadingText =~ s/<!--gsdl-metadata(.*?)-->//is)
    {
	$strSecMetadata .= $1;
    }

    $strHeadingText =~ s/^\s+//g;
    $strHeadingText =~ s/\s+$//g;
    $strSecMetadata =~ s/^\s+//g;
    $strSecMetadata =~ s/\s+$//g;

    $strMetadata .= "\n<Section>\n\t<Description>\n\t\t<Metadata name=\"Title\">" . $strHeadingText . "</Metadata>\n";

    if (length($strSecMetadata)) {
	$strMetadata .= "\t\t" . $strSecMetadata . "\n";
    }

    $strMetadata .= "\t</Description>\n";

    return "<!--" . $strMetadata . "-->";
}


sub update_section_data
{
    my ($self, $arrSections, $nCurTocNo) = @_;
    my ($strBuffer, $nLast, $nSections) = ('', 0, scalar(@$arrSections));

    if ($nSections == 0) {
	push @$arrSections, $nCurTocNo;
	return $strBuffer;
    }
    $nLast = $arrSections->[$nSections - 1];
    if ($nCurTocNo > $nLast) {
	push @$arrSections, $nCurTocNo;
	return $strBuffer;
    }
    for(my $i = $nSections - 1; $i >= 0; $i--) {
	if ($nCurTocNo <= $arrSections->[$i]) {
	    $strBuffer .= "\n</Section>";
	    pop @$arrSections;
	}
    }
    push @$arrSections, $nCurTocNo;
    return $strBuffer;
}


# note that process_section may be called multiple times for a single
# section (relying on the fact that add_utf8_text appends the text to any
# that may exist already).
sub process_section {
    my $self = shift (@_);
    my ($textref, $base_dir, $file, $doc_obj, $cursection) = @_;

	my @styleTagsText = ($$textref =~ m/<style[^>]*>([^<]*)<\/style>/sg);
	if(scalar(@styleTagsText) > 0)
	{
		my $css_filename_dirname = &File::Basename::dirname(&FileUtils::filenameConcatenate($base_dir, $file));
		foreach my $styleText (@styleTagsText)
		{
			$self->acquire_css_associated_files_from_text_block($styleText, $css_filename_dirname);
		}
	}

    # trap links
    if (!$self->{'nolinks'}) {
	# usemap="./#index" not handled correctly => change to "#index"
##	$$textref =~ s/(<img[^>]*?usemap\s*=\s*[\"\']?)([^\"\'>\s]+)([\"\']?[^>]*>)/

##	my $opencom = '(?:<!--|&lt;!(?:&mdash;|&#151;|--))';
##	my $closecom = '(?:-->|(?:&mdash;|&#151;|--)&gt;)';

	$$textref =~ s/(<img[^>]*?usemap\s*=\s*)((?:[\"][^\"]+[\"])|(?:[\'][^\']+[\'])|(?:[^\s\/>]+))([^>]*>)/
	    $self->replace_usemap_links($1, $2, $3)/isge;

	$$textref =~ s/(<(?:a|area|frame|link|script)\s+[^>]*?\s*(?:href|src)\s*=\s*)((?:[\"][^\"]+[\"])|(?:[\'][^\']+[\'])|(?:[^\s\/>]+))([^>]*>)/
	    $self->replace_href_links ($1, $2, $3, $base_dir, $file, $doc_obj, $cursection)/isge; 
	
##	$$textref =~ s/($opencom.*?)?+(<(?:a|area|frame|link|script)\s+[^>]*?\s*(?:href|src)\s*=\s*)((?:[\"][^\"]+[\"])|(?:[\'][^\']+[\'])|(?:[^\s\/>]+))([^>]*>)(.*?$closecom)?+/
#	    $self->replace_href_links ($1, $2, $3, $4, $5, $base_dir, $file, $doc_obj, $cursection)/isge;
    }

    # trap images

    # Previously, by default, HTMLPlugin would embed <img> tags inside anchor tags
    # i.e. <a href="image><img src="image"></a> in order to overcome a problem that
    # turned regular text succeeding images into links. That is, by embedding <imgs>
    # inside <a href=""></a>, the text following images were no longer misbehaving.
    # However, there would be many occasions whereby images were not meant to link
    # to their source images but where the images would link to another web page.
    # To allow this, the no_image_links option was introduced: it would prevent
    # the behaviour of embedding images into links that referenced the source images.

    # Somewhere along the line, the problem of normal text turning into links when 
    # such text followed images which were not embedded in <a href=""></a> ceased 
    # to occur. This is why the following lines have been commented out (as well as 
    # two lines in replace_images). They appear to no longer apply.

    # If at any time, there is a need for having images embedded in <a> anchor tags,
    # then it might be better to turn that into an HTMLPlugin option rather than make
    # it the default behaviour. Also, eventually, no_image_links needs to become
    # a deprecated option for HTMLPlugin as it has now become the default behaviour.

    #if(!$self->{'no_image_links'}){
    $$textref =~ s/(<(?:img|embed|table|tr|td)[^>]*?(?:src|background)\s*=\s*)((?:[\"][^\"]+[\"])|(?:[\'][^\']+[\'])|(?:[^\s\/>]+))([^>]*>)/
	$self->replace_images ($1, $2, $3, $base_dir, $file, $doc_obj, $cursection)/isge;
    #}

    # add text to document object
    # turn \ into \\ so that the rest of greenstone doesn't think there
    # is an escape code following. (Macro parsing loses them...)
    $$textref =~ s/\\/\\\\/go;
    
    $doc_obj->add_utf8_text($cursection, $$textref);
}

sub replace_images {
    my $self = shift (@_);
    my ($front, $link, $back, $base_dir, 
	$file, $doc_obj, $section) = @_;

    # remove quotes from link at start and end if necessary
    if ($link=~/^[\"\']/) {
	$link=~s/^[\"\']//;
	$link=~s/[\"\']$//;
	$front.='"';
	$back="\"$back";
    }

    $link =~ s/\n/ /g;

    # Hack to overcome Windows wv 0.7.1 bug that causes embedded images to be broken
    # If the Word file path has spaces in it, wv messes up and you end up with
    #   absolute paths for the images, and without the "file://" prefix
    # So check for this special case and massage the data to be correct
    if ($ENV{'GSDLOS'} =~ m/^windows/i && $self->{'plugin_type'} eq "WordPlug" && $link =~ m/^[A-Za-z]\:\\/) {
	$link =~ s/^.*\\([^\\]+)$/$1/;
    }
    
    my ($href, $hash_part, $rl) = $self->format_link ($link, $base_dir, $file);

    my $img_file =  $self->add_file ($href, $rl, $hash_part, $base_dir, $doc_obj, $section);

#    print STDERR "**** link = $link\n**** href = $href\n**** img_file = $img_file, rl = $rl\n\n";

    my $anchor_name = $img_file;
    #$anchor_name =~ s/^.*\///;
    #$anchor_name = "<a name=\"$anchor_name\" ></a>";

    my $image_link = $front . $img_file .$back;
    return $image_link;

    # The reasons for why the following two lines are no longer necessary can be 
    # found in subroutine process_section
    #my $anchor_link = "<a href=\"$img_file\" >".$image_link."</a>";  
    #return $anchor_link;	
    
    #return $front . $img_file . $back . $anchor_name;
}

sub replace_href_links {
    my $self = shift (@_);
    my ($front, $link, $back, $base_dir, $file, $doc_obj, $section) = @_;
	
	if($front =~ m/^<link / && $link =~ m/\.css"$/)
	{
		my $actual_link = $link;
		$actual_link =~ s/^"(.*)"$/$1/;
		
		my $directory = &File::Basename::dirname($file);
		
		my $css_filename = &FileUtils::filenameConcatenate($base_dir, $directory, $actual_link);	
		$self->retrieve_css_associated_files($css_filename);
	}
	
    # remove quotes from link at start and end if necessary
    if ($link=~/^[\"\']/) {
	$link=~s/^[\"\']//;
	$link=~s/[\"\']$//;
	$front.='"';
	$back="\"$back";
    }

    # can't remember adding this :-( must have had a reason though...
    if ($link =~ /^\_http/ || $link =~ /^\_libraryname\_/) {
	# assume it is a greenstone one and leave alone
	return $front . $link . $back;
    }

    # attempt to sort out targets - frames are not handled 
    # well in this plugin and some cases will screw things
    # up - e.g. the _parent target (so we'll just remove 
    # them all ;-)
    $front =~ s/(target=\"?)_top(\"?)/$1_gsdltop_$2/is;
    $back =~ s/(target=\"?)_top(\"?)/$1_gsdltop_$2/is;
    $front =~ s/target=\"?_parent\"?//is;
    $back =~ s/target=\"?_parent\"?//is;

	if($link =~ m/^\#/s)
	{
		return $front . "_httpsamepagelink_" . $link . $back;	
	}
    
    $link =~ s/\n/ /g;

    # Find file referred to by $link on file system 
    # This is more complicated than it sounds when char encodings
    # is taken in to account
    my ($href, $hash_part, $rl) = $self->format_link ($link, $base_dir, $file);

    # href may use '\'s where '/'s should be on Windows
    $href =~ s/\\/\//g;
    my ($filename) = $href =~ m/^(?:.*?):(?:\/\/)?(.*)/;

    ##### leave all these links alone (they won't be picked up by intermediate 
    ##### pages). I think that's safest when dealing with frames, targets etc.
    ##### (at least until I think of a better way to do it). Problems occur with
    ##### mailto links from within small frames, the intermediate page is displayed
    ##### within that frame and can't be seen. There is still potential for this to
    ##### happen even with html pages - the solution seems to be to somehow tell
    ##### the browser from the server side to display the page being sent (i.e. 
    ##### the intermediate page) in the top level window - I'm not sure if that's 
    ##### possible - the following line should probably be deleted if that can be done
    return $front . $link . $back if $href =~ m/^(mailto|news|gopher|nntp|telnet|javascript):/is;

    if (($rl == 0) || ($filename =~ m/$self->{'process_exp'}/) || 
	($href =~ m/\/$/) || ($href =~ m/^(mailto|news|gopher|nntp|telnet|javascript):/i)) {

	if ($ENV{'GSDLOS'} =~ m/^windows$/) {

	    # Don't do any encoding for now, as not clear what
	    # the right thing to do is to support filename
	    # encoding on Windows when they are not UTF16
	    # 
	}
	else {
	    # => Unix-based system

	    # If web page didn't give encoding, then default to utf8
	    my $content_encoding= $self->{'content_encoding'} || "utf8";

	    if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
		print STDERR "**** Encoding with '$content_encoding', href: $href\n";
	    }

	    # on Darwin, the unicode filenames are stored on the file
	    # system in decomposed form, so any href link (including when 
	    # URL-encoded) should refer to the decomposed name of the file
	    if ($ENV{'GSDLOS'} =~ /^darwin$/i) {
		$href = normalize('D', $href); # Normalization Form D (decomposition) 
	    }

	    $href = encode($content_encoding,$href);
	}
	
	$href = &unicode::raw_filename_to_utf8_url_encoded($href); 
	$href = &unicode::filename_to_url($href);
	
	&ghtml::urlsafe ($href);
	
	if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
		print STDERR "******DEBUG: href=$href\n";    
	}
	
	#TODO here
#	if ($rl ==1) {
	    # have a relative link, we need to do URL encoding etc so it matches what has happened for that file
	    #$href = &util::rename_file($href, $self->{'file_rename_method'});
#	    $href = &unicode::raw_filename_to_url_encoded($href);
	    # then, this might be url encoded, so we replace % with %25
#	    $href = &unicode::filename_to_url($href);
#	    print STDERR "DEBUG: url encoded href = $href\n";
#	}

	return $front . "_httpextlink_&amp;rl=" . $rl . "&amp;href=" . $href . $hash_part . $back;
    } else {
	# link is to some other type of file (e.g., an image) so we'll
	# need to associate that file
	return $front . $self->add_file ($href, $rl, $hash_part, $base_dir, $doc_obj, $section) . $back;
    }
}

sub retrieve_css_associated_files {
	my $self = shift (@_);
	my ($css_filename) = @_;
	
	my $css_filename_dirname = &File::Basename::dirname($css_filename);
	
	open (CSSFILE, $css_filename) || return;
	sysread (CSSFILE, my $file_string, -s CSSFILE);
	
	$self->acquire_css_associated_files_from_text_block($file_string, $css_filename_dirname) unless !defined $file_string;
	
	close CSSFILE;
}

sub acquire_css_associated_files_from_text_block {
	my $self = shift (@_);
	my ($text, $css_filename_dirname) = @_;
	
	my @image_urls = ($text =~ m/background-image:\s*url[^;]*;/sg);
	foreach my $img_url (@image_urls)
	{
		$img_url =~ s/^.*url.*\((.*)\).*$/$1/;
		$img_url =~ s/^\s*"?([^"]*)"?\s*$/$1/;

		$self->{'css_assoc_files'}->{&FileUtils::filenameConcatenate($css_filename_dirname, $img_url)} = $img_url;
	}
}

sub acquire_css_associated_files {
	my $self = shift(@_);
	
	my ($doc_obj, $section) = @_;
	
	foreach my $image_filename (keys %{$self->{'css_assoc_files'}})
	{
		$doc_obj->associate_file($image_filename, $self->{'css_assoc_files'}->{$image_filename}, undef, $section);	
	}
}

sub add_file {
    my $self = shift (@_);
    my ($href, $rl, $hash_part, $base_dir, $doc_obj, $section) = @_;
    my ($newname);

    my $filename = $href;
    if ($base_dir eq "") {
	if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
	    # remove http://
	    $filename =~ s/^[^:]*:\/\///;
	}
	else {
	    # remove http:/ thereby leaving one slash at the start as
	    # part of full pathname
	    $filename =~ s/^[^:]*:\///;
	}
    }
    else {
	# remove http://
	$filename =~ s/^[^:]*:\/\///;
    }
	
	if ($ENV{'GSDLOS'} =~ m/^windows$/i) {
		$filename =~ s@\/@\\@g;
	}
	
    $filename = &FileUtils::filenameConcatenate($base_dir, $filename);

    if (($self->{'use_realistic_book'}) || ($self->{'old_style_HDL'})) {
	# we are processing a tidytmp file - want paths to be in import
	$filename =~ s/([\\\/])tidytmp([\\\/])/$1import$2/;
    }

    # Replace %XX's in URL with decoded value if required. Note that the
    # filename may include the %XX in some situations. If the *original*
    # file's name was in URL encoding, the following method will not decode
    # it.
    my $unicode_filename = $filename;
    my $opt_decode_unicode_filename = $self->opt_url_decode($unicode_filename);

    # wvWare can generate <img src="StrangeNoGraphicData"> tags, but with no
    # (it seems) accompanying file
    if ($opt_decode_unicode_filename =~ m/StrangeNoGraphicData$/) { return ""; }

    my $content_encoding= $self->{'content_encoding'} || "utf8";

    if ($ENV{'GSDLOS'} =~ /^(linux|solaris)$/i) {
	# The filenames that come through the HTML file have been decoded
	# into Unicode aware Perl strings.  Need to convert them back
	# to their initial raw-byte encoding to match the file that
	# exists on the file system
	$filename = encode($content_encoding, $opt_decode_unicode_filename);
	
    }
    elsif ($ENV{'GSDLOS'} =~ /^darwin$/i) {
	# HFS+ is UTF8 with decompostion
	$filename = encode($content_encoding, $opt_decode_unicode_filename);
	$filename = normalize('D', $filename); # Normalization Form D (decomposition)

    }
    elsif ($ENV{'GSDLOS'} =~ /^windows$/i) {
	my $long_filename = Win32::GetLongPathName($opt_decode_unicode_filename);

	if (defined $long_filename) {
	    my $short_filename = Win32::GetLongPathName($long_filename);
	    $filename = $short_filename;
	}
#	else {
#	    print STDERR "***** failed to map href to real file:\n";
#	    print STDERR "****** $href -> $opt_decode_unicode_filename\n";
#	}
    }
    else {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "Warning: Unrecognized operating system ", $ENV{'GSDLOS'}, "\n";
	print $outhandle "         in file system encoding of href: $href\n";
	print $outhandle "         No character encoding done.\n";
    }


    # some special processing if the intended filename was converted to utf8, but
    # the actual file still needs to be renamed
    if (!&FileUtils::fileExists($filename)) {
	# try the original filename stored in map
	if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
		print STDERR "******!! orig filename did not exist: $filename\n";
	}

##	print STDERR "**** trying to look up unicode_filename: $unicode_filename\n";

	my $original_filename = $self->{'unicode_to_original_filename'}->{$unicode_filename};

	if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
		print STDERR "******   From lookup unicode_filename, now trying for: $original_filename\n";
	}

	if (defined $original_filename && -e $original_filename) {
		if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
			print STDERR "******   Found match!\n";
		}
	    $filename = $original_filename;
	} 
    }
    
    my ($ext) = $filename =~ m/(\.[^\.]*)$/;

    if ($rl == 0) {
	if ((!defined $ext) || ($ext !~ m/$self->{'assoc_files'}/)) {
	    return "_httpextlink_&amp;rl=0&amp;el=prompt&amp;href=" . $href . $hash_part;
	}
	else {
	    return "_httpextlink_&amp;rl=0&amp;el=direct&amp;href=" . $href . $hash_part;
	}
    }

    if ((!defined $ext) || ($ext !~ m/$self->{'assoc_files'}/)) {
	return "_httpextlink_&amp;rl=" . $rl . "&amp;href=" . $href . $hash_part;
    }
    # add the original image file as a source file
    if (!$self->{'processing_tmp_files'} ) {
	$doc_obj->associate_source_file($filename);
    }
    if ($self->{'rename_assoc_files'}) {
	if (defined $self->{'aux_files'}->{$href}) {
	    $newname = $self->{'aux_files'}->{$href}->{'dir_num'} . "/" .
		$self->{'aux_files'}->{$href}->{'file_num'} . $ext;
	} else {
	    $newname = $self->{'dir_num'} . "/" . $self->{'file_num'} . $ext;
	    $self->{'aux_files'}->{$href} = {'dir_num' => $self->{'dir_num'}, 'file_num' => $self->{'file_num'}};
	    $self->inc_filecount ();
	}
	$doc_obj->associate_file($filename, $newname, undef, $section);
	return "_httpdocimg_/$newname";
    } else {
	if(&unicode::is_url_encoded($unicode_filename)) {
	    # use the possibly-decoded filename instead to avoid double URL encoding
	    ($newname) = $filename =~ m/([^\/\\]*)$/;
	} else {
	    ($newname) = $unicode_filename =~ m/([^\/\\]*)$/;
	}

	# Make sure this name uses only ASCII characters. 
	# We use either base64 or URL encoding, as these preserve original encoding
	$newname = &util::rename_file($newname, $self->{'file_rename_method'});

###	print STDERR "***** associating $filename (raw-byte/utf8)-> $newname\n";
	$doc_obj->associate_file($filename, $newname, undef, $section);

	# Since the generated image will be URL-encoded to avoid file-system/browser mess-ups
	# of filenames, URL-encode the additional percent signs of the URL-encoded filename
	my $newname_url = $newname;
	$newname_url = &unicode::filename_to_url($newname_url);
	return "_httpdocimg_/$newname_url";	
    }
}

sub replace_section_links {
	my $self = shift(@_);
	my ($doc_obj) = @_;
	my %anchors;
	my $top_section = $doc_obj->get_top_section();
	my $thissection = $doc_obj->get_next_section($top_section);
	while ( defined $thissection ) {
		my $text = $doc_obj->get_text($thissection);
		while ( $text =~ /(?:(?:id|name)\s*=\s*[\'\"])([^\'\"]+)/gi ) {
			$anchors{$1} = $thissection;
		}
		$thissection = $doc_obj->get_next_section($thissection);
	}
	$thissection = $top_section;
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $text =~ s/(href\s*=\s*[\"\'])(_httpsamepagelink_#)([^\'\"]+)/$self->replace_link_to_anchor($1,$2,$3,$thissection,$anchors{$3})/ige;
		$doc_obj->delete_text( $thissection);
		$doc_obj->add_utf8_text( $thissection, $text );
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
}
sub replace_link_to_anchor {
	my $self = shift(@_);
	my ($href_part,$old_link,$identifier,$current_section,$target_section) = @_;
	if (length $target_section){
		return $href_part . "javascript:goToAnchor(\'" . $target_section . "\',\'" . $identifier . "\');" ;  
	}
	return $href_part . $old_link . $identifier ;
}

sub format_link {
    my $self = shift (@_);
    my ($link, $base_dir, $file) = @_;
 
    # strip off hash part, e.g. #foo, but watch out for any entities, e.g. &#x3B1;
    my ($before_hash, $hash_part) = $link =~ m/^(.*?[^&])(\#.*)?$/;
	
    $hash_part = "" if !defined $hash_part;
    if (!defined $before_hash || $before_hash !~ m/[\w\.\/]/) {
		my $outhandle = $self->{'outhandle'};
		print $outhandle "HTMLPlugin: ERROR - badly formatted tag ignored ($link)\n"
		    if $self->{'verbosity'};
		return ($link, "", 0);
    }
	
#    my $dirname;
    if ($before_hash =~ s@^((?:http|https|ftp|file|mms)://)@@i) {
	my $type = $1;
	my $before_hash_file = $before_hash;
		
	if ($link =~ m/^(http|ftp):/i) {
		
	    # Turn url (using /) into file name (possibly using \ on windows)
	    my @http_dir_split = split('/', $before_hash_file);
	    $before_hash_file = &FileUtils::filenameConcatenate(@http_dir_split);		
	}
	
	# want to maintain two version of "before_hash": one representing the URL, the other using filesystem specific directory separator
	$before_hash_file = $self->eval_dir_dots($before_hash_file);
	my $before_hash_url = $before_hash_file;
	if ($ENV{'GSDLOS'} =~ /^windows$/i) {
	    $before_hash_url =~ s@\\@\/@g;
	}
	
	######## TODO need to check this for encoding stufff
	my $linkfilename = &FileUtils::filenameConcatenate($base_dir, $before_hash_file);
	print STDERR "checking for existence whether relative link or not $linkfilename\n";
	my $rl = 0;
	$rl = 1 if (-e $linkfilename);
	if (-e $linkfilename) {
	    
	    print STDERR "DOES exist $linkfilename\n";
	} else {
	    print STDERR "DOESN'T exist $linkfilename\n";
	}
	# make sure there's a slash on the end if it's a directory
	if ($before_hash_url !~ m/\/$/) {
	    $before_hash_url .= "/" if (-d $linkfilename);
	}
	return ($type . $before_hash_url, $hash_part, $rl);
	
    } elsif ($link !~ m/^(mailto|news|gopher|nntp|telnet|javascript):/i && $link !~ m/^\//) {

	#### TODO whst is this test doing???
	if ($before_hash =~ s@^/@@ || $before_hash =~ m/\\/) {

	    # the first directory will be the domain name if file_is_url
	    # to generate archives, otherwise we'll assume all files are
	    # from the same site and base_dir is the root

	    if ($self->{'file_is_url'}) {
		my @dirs = split /[\/\\]/, $file;
		my $domname = shift (@dirs);
		$before_hash = &FileUtils::filenameConcatenate($domname, $before_hash);
		$before_hash =~ s@\\@/@g; # for windows
	    }
	    else
	    {
		# see if link shares directory with source document
		# => turn into relative link if this is so!
		
		if ($ENV{'GSDLOS'} =~ m/^windows/i) {
		    # too difficult doing a pattern match with embedded '\'s...
		    my $win_before_hash=$before_hash;
		    $win_before_hash =~ s@(\\)+@/@g;
		    # $base_dir is already similarly "converted" on windows.
		    if ($win_before_hash =~ s@^$base_dir/@@o) {
			# if this is true, we removed a prefix
			$before_hash=$win_before_hash;
		    }
		}
		else {
		    # before_hash has lost leading slash by this point,
		    # -> add back in prior to substitution with $base_dir
		    $before_hash = "/$before_hash"; 

		    $before_hash = &FileUtils::filenameConcatenate("",$before_hash);
		    $before_hash =~ s@^$base_dir/@@;
		}
	    }
	} else {

	    # Turn relative file path into full path (inside import dir)
	    my $dirname = &File::Basename::dirname($file);

	    # we want to add dirname (which is raw filesystem path) onto $before_hash, (which is perl unicode aware string). Convert dirname to perl string

	    my $unicode_dirname ="";
        # we need to turn raw filesystem filename into perl unicode aware string  
	    my $filename_encoding =  $self->guess_filesystem_encoding();  
		
	    # copied this from set_Source_metadata in BaseImporter
	    if ((defined $filename_encoding) && ($filename_encoding ne "ascii")) {
		# Use filename_encoding to map raw filename to a Perl unicode-aware string 
		$unicode_dirname = decode($filename_encoding,$dirname);		
	    }
	    else {
		# otherwise generate %xx encoded version of filename for char > 127
		$unicode_dirname = &unicode::raw_filename_to_url_encoded($dirname);
	    }
	    $before_hash = &FileUtils::filenameConcatenate($unicode_dirname, $before_hash);
	    $before_hash = $self->eval_dir_dots($before_hash);	 
	    $before_hash =~ s@\\@/@g; # for windows   	    
	}

	my $linkfilename = &FileUtils::filenameConcatenate($base_dir, $before_hash); 	

	# make sure there's a slash on the end if it's a directory
	if ($before_hash !~ m/\/$/) {
	    $before_hash .= "/" if (-d $linkfilename);
	}
	return ("http://" . $before_hash, $hash_part, 1);
    } else {
	# mailto, news, nntp, telnet, javascript or gopher link
	return ($before_hash, "", 0);
    }
}

sub extract_first_NNNN_characters {
    my $self = shift (@_);
    my ($textref, $doc_obj, $thissection) = @_;
    
    foreach my $size (split /,/, $self->{'first'}) {
	my $tmptext =  $$textref;
	# skip to the body
	$tmptext =~ s/.*<body[^>]*>//i;
	# remove javascript
	$tmptext =~ s@<script.*?</script>@ @sig;
	$tmptext =~ s/<[^>]*>/ /g;
	$tmptext =~ s/&nbsp;/ /g;
	$tmptext =~ s/^\s+//;
	$tmptext =~ s/\s+$//;
	$tmptext =~ s/\s+/ /gs;
	$tmptext = &unicode::substr ($tmptext, 0, $size);
	$tmptext =~ s/\s\S*$/&#8230;/; # adds an ellipse (...)
	$doc_obj->add_utf8_metadata ($thissection, "First$size", $tmptext);
    }
}


sub extract_metadata {
    my $self = shift (@_);
    my ($textref, $metadata, $doc_obj, $section) = @_;
    my $outhandle = $self->{'outhandle'};
    # if we don't want metadata, we may as well not be here ...
    return if (!defined $self->{'metadata_fields'});
    my $separator = $self->{'metadata_field_separator'};
    if ($separator eq "") {
	undef $separator;
    }

    # metadata fields to extract/save. 'key' is the (lowercase) name of the
    # html meta, 'value' is the metadata name for greenstone to use
    my %find_fields = ();

    my %creator_fields = (); # short-cut for lookups


    foreach my $field (split /,/, $self->{'metadata_fields'}) {
        $field =~ s/^\s+//; # remove leading whitespace
        $field =~ s/\s+$//; # remove trailing whitespace
	
	# support tag<tagname>
	if ($field =~ m/^(.*?)\s*<(.*?)>$/) {
	    # "$2" is the user's preferred gs metadata name
	    $find_fields{lc($1)}=$2; # lc = lowercase
	} else { # no <tagname> for mapping
	    # "$field" is the user's preferred gs metadata name
	    $find_fields{lc($field)}=$field; # lc = lowercase
	}
    }

    if (defined $self->{'hunt_creator_metadata'} &&
	$self->{'hunt_creator_metadata'} == 1 ) {
	my @extra_fields =
	    (
	     'author',
	     'author.email',
	     'creator',
	     'dc.creator',
	     'dc.creator.corporatename',
	     );

	# add the creator_metadata fields to search for
	foreach my $field (@extra_fields) {
	    $creator_fields{$field}=0; # add to lookup hash
	}
    }


    # find the header in the html file, which has the meta tags
    $$textref =~ m@<head>(.*?)</head>@si;

    my $html_header=$1;

    # go through every <meta... tag defined in the html and see if it is
    # one of the tags we want to match.
    
    # special case for title - we want to remember if its been found
    my $found_title = 0;
    # this assumes that ">" won't appear. (I don't think it's allowed to...)
    $html_header =~ m/^/; # match the start of the string, for \G assertion
    
    while ($html_header =~ m/\G.*?<meta(.*?)>/sig) {
	my $metatag=$1;
	my ($tag, $value);

	# find the tag name
	$metatag =~ m/(?:name|http-equiv)\s*=\s*([\"\'])?(.*?)\1/is;
	$tag=$2;
	# in case they're not using " or ', but they should...
	if (! $tag) {
	    $metatag =~ m/(?:name|http-equiv)\s*=\s*([^\s\>]+)/is;
	    $tag=$1;
	}

	if (!defined $tag) {
	    print $outhandle "HTMLPlugin: can't find NAME in \"$metatag\"\n";
	    next;
	}
	
	# don't need to assign this field if it was passed in from a previous 
	# (recursive) plugin
	if (defined $metadata->{$tag}) {next}

	# find the tag content
	$metatag =~ m/content\s*=\s*([\"\'])?(.*?)\1/is;
	$value=$2;

	# The following code assigns the metaname to value if value is
	# empty. Why would we do this?
	#if (! $value) {
	#    $metatag =~ m/(?:name|http-equiv)\s*=\s*([^\s\>]+)/is;
	#    $value=$1;
	#}
	if (!defined $value || $value eq "") {
	    print $outhandle "HTMLPlugin: can't find VALUE in <meta $metatag >\n" if ($self->{'verbosity'} > 2);
	    next;
	}
	
	# clean up and add
	$value =~ s/\s+/ /gs;
	chomp($value); # remove trailing \n, if any
	if (exists $creator_fields{lc($tag)}) {
	    # map this value onto greenstone's "Creator" metadata
	    $tag='Creator';
	} elsif (!exists $find_fields{lc($tag)}) {
	    next; # don't want this tag
	} else {
	    # get the user's preferred capitalisation
	    $tag = $find_fields{lc($tag)};
	}
	if (lc($tag) eq "title") {
	    $found_title = 1;
	}

	if ($self->{'verbosity'} > 2) {
	    print $outhandle " extracted \"$tag\" metadata \"$value\"\n";
	}

	if ($tag =~ /\./) {
	    # there is a . so has a namespace, add ex.
	    $tag = "ex.$tag";
	}
	if (defined $separator) {
	    my @values = split($separator, $value);
	    foreach my $v (@values) {
		$doc_obj->add_utf8_metadata($section, $tag, $v) if $v =~ /\S/;
	    }
	}
	else {
	    $doc_obj->add_utf8_metadata($section, $tag, $value);
	}
    }
    
    # TITLE: extract the document title
    if (exists $find_fields{'title'} && !$found_title) {
	# we want a title, and didn't find one in the meta tags
	# see if there's a <title> tag
	my $title;
	my $from = ""; # for debugging output only
	if ($html_header =~ m/<title[^>]*>([^<]+)<\/title[^>]*>/is) {
	    $title = $1;
	    $from = "<title> tags";
	}

	if (!defined $title) {
	    $from = "first 100 chars";
	    # if no title use first 100 or so characters
	    $title = $$textref;
	    $title =~ s/^\xFE\xFF//; # Remove unicode byte order mark	    
	    $title =~ s/^.*?<body>//si;
	    # ignore javascript!
	    $title =~ s@<script.*?</script>@ @sig;
	    $title =~ s/<\/([^>]+)><\1>//g; # (eg) </b><b> - no space
	    $title =~ s/<[^>]*>/ /g; # remove all HTML tags
		$title =~ s@\r@@g; # remove Windows carriage returns to ensure that titles of pdftohtml docs are consistent (the same 100 chars) across windows and linux
	    $title = substr ($title, 0, 100);
	    $title =~ s/\s\S*$/.../;
	}
	$title =~ s/<[^>]*>/ /g; # remove html tags
	$title =~ s/&nbsp;/ /g;
	$title =~ s/(?:&nbsp;|\xc2\xa0)/ /g; # utf-8 for nbsp...
	$title =~ s/\s+/ /gs; # collapse multiple spaces
	$title =~ s/^\s*//;   # remove leading spaces
	$title =~ s/\s*$//;   # remove trailing spaces

	$title =~ s/^$self->{'title_sub'}// if ($self->{'title_sub'});
	$title =~ s/^\s+//s; # in case title_sub introduced any...
	$doc_obj->add_utf8_metadata ($section, "Title", $title);
	print $outhandle " extracted Title metadata \"$title\" from $from\n" 
	    if ($self->{'verbosity'} > 2);
    } 
    
    # add FileFormat metadata
    $doc_obj->add_metadata($section,"FileFormat", "HTML");

    # Special, for metadata names such as tagH1 - extracts
    # the text between the first <H1> and </H1> tags into "H1" metadata.

    foreach my $field (keys %find_fields) {
	if ($field !~ m/^tag([a-z0-9]+)$/i) {next}
	my $tag = $1;
	if ($$textref =~ m@<$tag[^>]*>(.*?)</$tag[^>]*>@g) {
	    my $content = $1;
	    $content =~ s/&nbsp;/ /g;
	    $content =~ s/<[^>]*>/ /g;
	    $content =~ s/^\s+//;
	    $content =~ s/\s+$//;
	    $content =~ s/\s+/ /gs;
	    if ($content) {
		$tag=$find_fields{"tag$tag"}; # get the user's capitalisation
		$tag =~ s/^tag//i;
		$doc_obj->add_utf8_metadata ($section, $tag, $content);
		print $outhandle " extracted \"$tag\" metadata \"$content\"\n" 
		    if ($self->{'verbosity'} > 2);
	    }
	}
    }    
}


# evaluate any "../" to next directory up
# evaluate any "./" as here
sub eval_dir_dots {
    my $self = shift (@_);
    my ($filename) = @_;
    my $dirsep_os = &util::get_os_dirsep();
    my @dirsep = split(/$dirsep_os/,$filename);

    my @eval_dirs = ();
    foreach my $d (@dirsep) {
	if ($d eq "..") {
	    pop(@eval_dirs);
	    
	} elsif ($d eq ".") {
	    # do nothing!

	} else {
	    push(@eval_dirs,$d);
	}
    }

    # Need to fiddle with number of elements in @eval_dirs if the
    # first one is the empty string.  This is because of a
    # modification to FileUtils::filenameConcatenate that supresses the addition
    # of a leading '/' character (or \ if windows) (intended to help
    # filename cat with relative paths) if the first entry in the
    # array is the empty string.  Making the array start with *two*
    # empty strings is a way to defeat this "smart" option.
    #
    if (scalar(@eval_dirs) > 0) {
	if ($eval_dirs[0] eq ""){
	    unshift(@eval_dirs,"");
	}
    }
    
    my $evaluated_filename = (scalar @eval_dirs > 0) ? &FileUtils::filenameConcatenate(@eval_dirs) : "";
    return $evaluated_filename;
}

sub replace_usemap_links {
    my $self = shift (@_);
    my ($front, $link, $back) = @_;

    # remove quotes from link at start and end if necessary
    if ($link=~/^[\"\']/) {
	$link=~s/^[\"\']//;
	$link=~s/[\"\']$//;
	$front.='"';
	$back="\"$back";
    }

    $link =~ s/^\.\///;
    return $front . $link . $back;
}

sub inc_filecount {
    my $self = shift (@_);

    if ($self->{'file_num'} == 1000) {
	$self->{'dir_num'} ++;
	$self->{'file_num'} = 0;
    } else {
	$self->{'file_num'} ++;
    }
}


# Extend read_file so that strings like &eacute; are
# converted to UTF8 internally.  
#
# We don't convert &lt; or &gt; or &amp; or &quot; in case
# they interfere with the GML files

sub read_file {
    my $self = shift(@_);
    my ($filename, $encoding, $language, $textref) = @_;

    $self->SUPER::read_file($filename, $encoding, $language, $textref);

    # Convert entities to their Unicode code-point equivalents
    $$textref =~ s/&(lt|gt|amp|quot|nbsp);/&z$1;/go;
    $$textref =~ s/&([^;]+);/&ghtml::getcharequiv($1,1,1)/gseo;
    $$textref =~ s/&z(lt|gt|amp|quot|nbsp);/&$1;/go;

}

sub HB_read_html_file {
    my $self = shift (@_);
    my ($htmlfile, $text) = @_;
    
    # load in the file
    if (!open (FILE, $htmlfile)) {
	print STDERR "ERROR - could not open $htmlfile\n";
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
	if ($line =~ m/<font [^>]*?face\s*=\s*\"?(\w+)\"?/i) {
	    my $font = $1;
	    print STDERR "HBPlug::HB_gettext - warning removed font $font\n" 
		if ($font !~ m/^arial$/i);
	}

	$$text .= $line;
    }

    if ($self->{'input_encoding'} eq "iso_8859_1") {
	# convert to utf-8
	$$text=&unicode::unicode2utf8(&unicode::convert2unicode("iso_8859_1", $text));
    }
    # convert any alphanumeric character entities to their utf-8
    # equivalent for indexing purposes
    #&ghtml::convertcharentities ($$text);

    $$text =~ s/\s+/ /g; # remove \n's

    # At this point $$text is a binary byte string
    # => turn it into a Unicode aware string, so full
    # Unicode aware pattern matching can be used.
    # For instance: 's/\x{0101}//g' or '[[:upper:]]'
    # 

    $$text = decode("utf8",$$text);
}

sub HB_clean_section {
    my $self = shift (@_);
    my ($section) = @_;

    # remove tags without a starting tag from the section
    my ($tag, $tagstart);
    while ($section =~ m/<\/([^>]{1,10})>/) {
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
	<center><img src=\"$1\" \/><\/center><br\/>/ig;
    $section =~ s/&lt;&lt;I&gt;&gt;\s*([^\.]+\.(png|jpg|gif))/
	<center><img src=\"$1\" \/><\/center><br\/>/ig;

    return $section;
}

# Will convert the oldHDL format to the new HDL format (using the Section tag)	
sub convert_to_newHDLformat
{
    my $self = shift (@_);
    my ($file,$cnfile) = @_;
    my $input_filename = $file;
    my $tmp_filename = $cnfile;
    
    # write HTML tmp file with new HDL format
    open (PROD, ">$tmp_filename") || die("Error Writing to File: $tmp_filename $!");
    
    # read in the file and do basic html cleaning (removing header etc)
    my $html = "";
    $self->HB_read_html_file ($input_filename, \$html);
    
    # process the file one section at a time
    my $curtoclevel = 1;
    my $firstsection = 1;
    my $toclevel = 0;
    while (length ($html) > 0) {
	if ($html =~ s/^.*?(?:<p\b[^>]*>)?((<b>|<i>|<u>|\s)*)&lt;&lt;TOC(\d+)&gt;&gt;\s*(.*?)<p\b/<p/i) {
	    $toclevel = $3;
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
	    print PROD "<!--\n";
	    while (($curtoclevel > $toclevel) ||
		   (!$firstsection && $curtoclevel == $toclevel)) {
		$curtoclevel--;
		print PROD "</Section>\n";
	    }
	    if ($curtoclevel+1 < $toclevel) {
		print STDERR "WARNING - jump in toc levels in $input_filename " . 
		    "from $curtoclevel to $toclevel\n";
	    }
	    while ($curtoclevel < $toclevel) {
		$curtoclevel++;
	    }

	    if ($curtoclevel == 1) {
	    	# add the header tag
		print PROD "-->\n";
    		print PROD "<HTML>\n<HEAD>\n<TITLE>$title</TITLE>\n</HEAD>\n<BODY>\n";
		print PROD "<!--\n";
	    }
	    
	    print PROD "<Section>\n\t<Description>\n\t\t<Metadata name=\"Title\">$title</Metadata>\n\t</Description>\n";
	    
	    print PROD "-->\n";
	    
	    # clean up the section html
	    $sectiontext = $self->HB_clean_section($sectiontext);

	    print PROD "$sectiontext\n";	 

	} else {
	    print STDERR "WARNING - leftover text\n" , $self->shorten($html), 
	    "\nin $input_filename\n";
	    last;
	}
	$firstsection = 0;
    }
    
    print PROD "<!--\n";
    while ($curtoclevel > 0) {
	$curtoclevel--;
	print PROD "</Section>\n";
    }
    print PROD "-->\n";
    
    close (PROD) || die("Error Closing File: $tmp_filename $!");
    
    return $tmp_filename;
}		

sub shorten {
    my $self = shift (@_);
    my ($text) = @_;

    return "\"$text\"" if (length($text) < 100);

    return "\"" . substr ($text, 0, 50) . "\" ... \"" . 
	substr ($text, length($text)-50) . "\"";
}

sub convert_tidy_or_oldHDL_file
{
    my $self = shift (@_);
    my ($file) = @_;
    my $input_filename = $file;
    
    if (-d $input_filename)
    {
    	return $input_filename;
    }
    
    # get the input filename
    my ($tailname, $dirname, $suffix) = &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");
    my $base_dirname = $dirname;
    $suffix = lc($suffix);   
    
    # derive tmp filename from input filename
    # Remove any white space from filename -- no risk of name collision, and
    # makes later conversion by utils simpler. Leave spaces in path...
    # tidy up the filename with space, dot, hyphen between
    $tailname =~ s/\s+//g; 
    $tailname =~ s/\.+//g;
    $tailname =~ s/\-+//g;
    # convert to utf-8 otherwise we have problems with the doc.xml file
    # later on
    &unicode::ensure_utf8(\$tailname);
    
    # softlink to collection tmp dir
    my $tmp_dirname = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "tidytmp");
    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);
    
    my $test_dirname = "";
    my $f_separator = &util::get_os_dirsep();
    
    if ($dirname =~ m/import$f_separator/)
    {
    	$test_dirname = $'; #'
	
	#print STDERR "init $'\n";
	
	while ($test_dirname =~ m/[$f_separator]/)
	{
	    my $folderdirname = $`;
	    $tmp_dirname = &FileUtils::filenameConcatenate($tmp_dirname,$folderdirname);
	    &FileUtils::makeDirectory($tmp_dirname) if (!-e $tmp_dirname);
	    $test_dirname = $'; #'
	}
    }
    
    my $tmp_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix");
    
    # tidy or convert the input file if it is a HTML-like file or it is accepted by the process_exp
    if (($suffix eq ".htm") || ($suffix eq ".html") || ($suffix eq ".shtml"))
    {   
    	#convert the input file to a new style HDL
    	my $hdl_output_filename = $input_filename;
    	if ($self->{'old_style_HDL'})
    	{
	    $hdl_output_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix");
	    $hdl_output_filename = $self->convert_to_newHDLformat($input_filename,$hdl_output_filename);
    	}
	
	#just for checking copy all other file from the base dir to tmp dir if it is not exists
	opendir(DIR,$base_dirname) or die "Can't open base directory : $base_dirname!";
	my @files = grep {!/^\.+$/} readdir(DIR);
	close(DIR);

	foreach my $file (@files) 
	{
	    my $src_file = &FileUtils::filenameConcatenate($base_dirname,$file);
	    my $dest_file = &FileUtils::filenameConcatenate($tmp_dirname,$file);
	    if ((!-e $dest_file) && (!-d $src_file))
	    {
		# just copy the original file back to the tmp directory
		copy($src_file,$dest_file) or die "Can't copy file $src_file to $dest_file $!";
	    }
	}
	
	# tidy the input file
	my $tidy_output_filename = $hdl_output_filename;
	if ($self->{'use_realistic_book'})
	{
	    $tidy_output_filename = &FileUtils::filenameConcatenate($tmp_dirname, "$tailname$suffix");
	    $tidy_output_filename = $self->tmp_tidy_file($hdl_output_filename,$tidy_output_filename);
	}
	$tmp_filename = $tidy_output_filename;
    }
    else
    {
    	if (!-e $tmp_filename)
	{
	    # just copy the original file back to the tmp directory
	    copy($input_filename,$tmp_filename) or die "Can't copy file $input_filename to $tmp_filename $!";
	}
    }
    
    return $tmp_filename;
}


# Will make the html input file as a proper XML file with removed font tag and
# image size added to the img tag.
# The tidying process takes place in a collection specific 'tmp' directory so 
# that we don't accidentally damage the input.
sub tmp_tidy_file 
{
    my $self = shift (@_);
    my ($file,$cnfile) = @_;
    my $input_filename = $file;
    my $tmp_filename = $cnfile;
    
    # get the input filename
    my ($tailname, $dirname, $suffix) = &File::Basename::fileparse($input_filename, "\\.[^\\.]+\$");

    require HTML::TokeParser::Simple;
    
    # create HTML parser to decode the input file
    my $parser = HTML::TokeParser::Simple->new($input_filename);

    # write HTML tmp file without the font tag and image size are added to the img tag
    open (PROD, ">$tmp_filename") || die("Error Writing to File: $tmp_filename $!");
    while (my $token = $parser->get_token())
    {
	# is it an img tag
	if ($token->is_start_tag('img'))
	{
	    # get the attributes
	    my $attr = $token->return_attr;

	    # get the full path to the image
	    my $img_file = &FileUtils::filenameConcatenate($dirname,$attr->{src});
	    
	    # set the width and height attribute
	    ($attr->{width}, $attr->{height}) = imgsize($img_file);

	    # recreate the tag
	    print PROD "<img";
	    print PROD map { qq { $_="$attr->{$_}"} } keys %$attr;
	    print PROD ">";
	}
	# is it a font tag
	else 
	{
	    if (($token->is_start_tag('font')) || ($token->is_end_tag('font')))
	    {
		# remove font tag
		print PROD "";
	    }
	    else
	    {
		# print without changes
		print PROD $token->as_is;
	    }
	}
    }
    close (PROD) || die("Error Closing File: $tmp_filename $!");

    # run html-tidy on the tmp file to make it a proper XML file

    my $outhandle = $self->{'outhandle'};
    print $outhandle "Converting HTML to be XML compliant:\n";

    my $tidy_cmd = "tidy";
    $tidy_cmd .= " -q" if ($self->{'verbosity'} <= 2);
    $tidy_cmd .= " -raw -wrap 0 -asxml \"$tmp_filename\"";
    if ($self->{'verbosity'} <= 2) {
	if ($ENV{'GSDLOS'} =~ m/^windows/i) {
	    $tidy_cmd .= " 2>nul";
	}
	else {
	    $tidy_cmd .= " 2>/dev/null";
	}
	print $outhandle "  => $tidy_cmd\n";
    }

    my $tidyfile = `$tidy_cmd`;

    # write result back to the tmp file
    open (PROD, ">$tmp_filename") || die("Error Writing to File: $tmp_filename $!");
    print PROD $tidyfile;
    close (PROD) || die("Error Closing File: $tmp_filename $!");
    
    # return the output filename
    return $tmp_filename;
} 

sub associate_cover_image
{
    my $self = shift(@_);
    my ($doc_obj, $filename) = @_;
    if (($self->{'use_realistic_book'}) || ($self->{'old_style_HDL'}))
    {
	# we will have cover image in tidytmp, but want it from import
	$filename =~ s/([\\\/])tidytmp([\\\/])/$1import$2/;
    }
    $self->SUPER::associate_cover_image($doc_obj, $filename);
}

    
1;
