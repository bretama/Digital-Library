###########################################################################
#
# ReadTxtFile.pm -- base class for import plugins that have plain text files
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2005 New Zealand Digital Library Project
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

package ReadTextFile;

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use Encode;

use multiread;
use encodings;
use unicode;
use textcat;
use doc;
use ghtml;
use gsprintf 'gsprintf';

use AutoExtractMetadata;

sub BEGIN {
    @ReadTextFile::ISA = ( 'AutoExtractMetadata' );
}

my $encoding_plus_auto_list = 
    [ { 'name' => "auto",
	'desc' => "{ReadTextFile.input_encoding.auto}" } ];
push(@{$encoding_plus_auto_list},@{$CommonUtil::encoding_list});

my $arguments =
    [ { 'name' => "input_encoding",
	'desc' => "{ReadTextFile.input_encoding}",
	'type' => "enum",
	'list' => $encoding_plus_auto_list,
	'reqd' => "no" ,
	'deft' => "auto" } ,
      { 'name' => "default_encoding",
	'desc' => "{ReadTextFile.default_encoding}",
	'type' => "enum",
	'list' => $CommonUtil::encoding_list,
	'reqd' => "no",
        'deft' => "utf8" },
      { 'name' => "extract_language",
	'desc' => "{ReadTextFile.extract_language}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "default_language",
	'desc' => "{ReadTextFile.default_language}",
	'type' => "string",
	'deft' => "en",
	'reqd' => "no" }
      ];


my $options = { 'name'     => "ReadTextFile",
		'desc'     => "{ReadTextFile.desc}",
		'abstract' => "yes",
		'inherits' => "no",
		'args'     => $arguments };



sub new {
    my $class = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists, $auxiliary) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new AutoExtractMetadata($pluginlist, $inputargs, $hashArgOptLists, $auxiliary);

    return bless $self, $class;
    
}



# The ReadTextFile read_into_doc_obj() function. This function does all the
# right things to make general options work for a given plugin.  It reads in
# a file and sets up a slew of metadata all saved in doc_obj, which
# it then returns as part of a tuple (process_status,doc_obj)
#
# Much of this functionality used to reside in read, but it was broken
# down into a supporting routine to make the code more flexible.  
#
# recursive plugins (e.g. RecPlug) and specialized plugins like those
# capable of processing many documents within a single file (e.g.
# GMLPlug) will normally want to implement their own version of
# read_into_doc_obj()
#
# Note that $base_dir might be "" and that $file might 
# include directories
sub read_into_doc_obj {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};
    # should we move this to read? What about secondary plugins?
    print STDERR "<Processing n='$file' p='$self->{'plugin_type'}'>\n" if ($gli);
    my $pp_file = &util::prettyprint_file($base_dir,$file,$gli);
    print $outhandle "$self->{'plugin_type'} processing $pp_file\n"
	    if $self->{'verbosity'} > 1;

    my ($filename_full_path, $filename_no_path) =  &util::get_full_filenames($base_dir, $file);

    # Do encoding stuff
    my ($language, $content_encoding) = $self->textcat_get_language_encoding ($filename_full_path);
    if ($self->{'verbosity'} > 2) {
	print $outhandle "ReadTextFile: reading $file as ($content_encoding,$language)\n";
    }

    # create a new document
    my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});
    my $top_section = $doc_obj->get_top_section();

    # this should look at the plugin option too...
    $doc_obj->add_utf8_metadata($top_section, "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_utf8_metadata($top_section, "FileSize", (-s $filename_full_path));

    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj, $filename_full_path, $filename_encoding);

    $doc_obj->add_utf8_metadata($top_section, "Language", $language);
    $doc_obj->add_utf8_metadata($top_section, "Encoding", $content_encoding);
    
    # read in file ($text will be in perl internal unicode aware format)
    my $text = "";
    $self->read_file ($filename_full_path, $content_encoding, $language, \$text);

    if (!length ($text)) {
	if ($gli) {
	    print STDERR "<ProcessingError n='$file' r='File contains no text'>\n";
	}
	gsprintf($outhandle, "$self->{'plugin_type'}: {ReadTextFile.file_has_no_text}\n", $filename_full_path) if $self->{'verbosity'};

	my $failhandle = $self->{'failhandle'};
	gsprintf($failhandle, "$file: " . ref($self) . ": {ReadTextFile.empty_file}\n");
	# print $failhandle "$file: " . ref($self) . ": file contains no text\n";
	$self->{'num_not_processed'} ++;

	return (0,undef); # what should we return here?? error but don't want to pass it on
    }
   
    # do plugin specific processing of doc_obj
    unless (defined ($self->process (\$text, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli))) {
	$text = '';
	undef $text;
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return (-1,undef);
    }
    $text='';
    undef $text;
   
    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    $self->add_associated_files($doc_obj, $filename_full_path);
    $self->extra_metadata ($doc_obj, $top_section, $metadata);

     # do any automatic metadata extraction
    $self->auto_extract_metadata ($doc_obj);


    # if we haven't found any Title so far, assign one
    $self->title_fallback($doc_obj,$top_section,$filename_no_path);

    $self->add_OID($doc_obj);
    
    return (1,$doc_obj);
}

# uses the multiread package to read in the entire file pointed to
# by filename and loads the resulting text into $$textref. Input text
# may be in any of the encodings handled by multiread, output text
# will be in utf8
sub read_file {
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;

    if (!-r $filename)
    {
	my $outhandle = $self->{'outhandle'};
	gsprintf($outhandle, "{ReadTextFile.read_denied}\n", $filename) if $self->{'verbosity'};
	# print $outhandle "Read permission denied for $filename\n" if $self->{'verbosity'};
	return;
    }
    $$textref = "";
    if (!open (FILE, $filename)) {
	gsprintf(STDERR, "ReadTextFile::read_file {ReadTextFile.could_not_open_for_reading} ($!)\n", $filename);
	die "\n";
    }
     
    if ($encoding eq "ascii") {
	# Replace file 'slurp' with faster implementation
	sysread(FILE, $$textref, -s FILE);
	
	# The old slow way of reading in a file
	#undef $/;
	#$$textref = <FILE>;
	#$/ = "\n";
    } else {
	my $reader = new multiread();
	$reader->set_handle ('ReadTextFile::FILE');
	$reader->set_encoding ($encoding);
	$reader->read_file ($textref);
    }

    # At this point $$textref is a binary byte string
    # => turn it into a Unicode aware string, so full
    # Unicode aware pattern matching can be used.
    # For instance: 's/\x{0101}//g' or '[[:upper:]]'
    # 

    $$textref = decode("utf8",$$textref);

    close FILE;
}


# Not currently used
sub UNUSED_read_file_usingPerlsEncodeModule {
##sub read_file {
    my $self = shift (@_);
    my ($filename, $encoding, $language, $textref) = @_;

    if (!-r $filename)
    {
        my $outhandle = $self->{'outhandle'};
        gsprintf($outhandle, "{ReadTextFile.read_denied}\n", $filename) if $self->{'verbosity'};
        # print $outhandle "Read permission denied for $filename\n" if $self->{'verbosity'};
        return;
    }
    $$textref = "";
    if (!open (FILE, $filename)) {
        gsprintf(STDERR, "ReadTextFile::read_file {ReadTextFile.could_not_open_f
or_reading} ($!)\n", $filename);
        die "\n";
    }

    my $store_slash = $/;
    undef $/;
    my $text = <FILE>;
    $/ = $store_slash;

    $$textref = decode($encoding,$text);

    close FILE;
}


sub read_file_no_decoding {
    my $self = shift (@_);
    my ($filename, $textref) = @_;

    if (!-r $filename)
    {
	my $outhandle = $self->{'outhandle'};
	gsprintf($outhandle, "{ReadTextFile.read_denied}\n", $filename) if $self->{'verbosity'};
	# print $outhandle "Read permission denied for $filename\n" if $self->{'verbosity'};
	return;
    }
    $$textref = "";
    if (!open (FILE, $filename)) {
	gsprintf(STDERR, "ReadTextFile::read_file {ReadTextFile.could_not_open_for_reading} ($!)\n", $filename);
	die "\n";
    }
     
    my $reader = new multiread();
    $reader->set_handle ('ReadTextFile::FILE');
    $reader->read_file_no_decoding ($textref);
    
    $self->{'reader'} = $reader;

    close FILE;
}


sub decode_text {
    my $self = shift (@_);
    my ($raw_text, $encoding, $language, $textref) = @_;

    my $reader = $self->{'reader'};
    if (!defined $reader) {
	gsprintf(STDERR, "ReadTextFile::decode_text needs to call ReadTextFile::read_file_no_decoding first\n");
    }
    else {
	$reader->set_encoding($encoding);
	$reader->decode_text($raw_text,$textref);

	# At this point $$textref is a binary byte string
	# => turn it into a Unicode aware string, so full
	# Unicode aware pattern matching can be used.
	# For instance: 's/\x{0101}//g' or '[[:upper:]]'	
	
	$$textref = decode("utf8",$$textref);
    }
}


sub textcat_get_language_encoding {
    my $self = shift (@_);
    my ($filename) = @_;

    my ($language, $encoding, $extracted_encoding);
    if ($self->{'input_encoding'} eq "auto") {
        # use textcat to automatically work out the input encoding and language
        ($language, $encoding) = $self->get_language_encoding ($filename);
    } elsif ($self->{'extract_language'}) {
	# use textcat to get language metadata
        ($language, $extracted_encoding) = $self->get_language_encoding ($filename);
        $encoding = $self->{'input_encoding'};
	# don't print this message for english... english in utf8 is identical
	# to english in iso-8859-1 (except for some punctuation). We don't have
	# a language model for en_utf8, so textcat always says iso-8859-1!
        if ($extracted_encoding ne $encoding && $language ne "en" && $self->{'verbosity'}) {
	    my $plugin_name = ref ($self);
	    my $outhandle = $self->{'outhandle'};
	    gsprintf($outhandle, "$plugin_name: {ReadTextFile.wrong_encoding}\n", $filename, $encoding, $extracted_encoding);
        }
    } else {
        $language = $self->{'default_language'};
        $encoding = $self->{'input_encoding'}; 
    }
    
#    print STDERR "**** language encoding of contents of file $filename:\n\t****$language $encoding\n";

    return ($language, $encoding);
}


# Uses textcat to work out the encoding and language of the text in 
# $filename. All html tags are removed before processing.
# returns an array containing "language" and "encoding"
sub get_language_encoding {
    my $self = shift (@_);
    my ($filename) = @_;
    my $outhandle = $self->{'outhandle'};
    my $unicode_format = "";
    my $best_language = "";
    my $best_encoding = "";
    

    # read in file
    if (!open (FILE, $filename)) {
	gsprintf(STDERR, "ReadTextFile::get_language_encoding {ReadTextFile.could_not_open_for_reading} ($!)\n", $filename);
	# this is a pretty bad error, but try to continue anyway
	return ($self->{'default_language'}, $self->{'input_encoding'});
    }
    undef $/;
    my $text = <FILE>;
    $/ = "\n";
    close FILE;

    # check if first few bytes have a Byte Order Marker
    my $bom=substr($text,0,2); # check 16bit unicode
    if ($bom eq "\xff\xfe") { # little endian 16bit unicode
	$unicode_format="unicode";
    } elsif ($bom eq "\xfe\xff") { # big endian 16bit unicode
	$unicode_format="unicode";
    } else {
	$bom=substr($text,0,3); # check utf-8
	if ($bom eq "\xef\xbb\xbf") { # utf-8 coded FEFF bom
	    $unicode_format="utf8";
#	} elsif ($bom eq "\xef\xbf\xbe") { # utf-8 coded FFFE bom. Error!?
#	    $unicode_format="utf8";
	}
    }
    
    my $found_html_encoding = 0;
    # handle html files specially
    # XXX this doesn't match plugins derived from HTMLPlug (except ConvertTo)
    if (ref($self) eq 'HTMLPlugin' ||
	(exists $self->{'converted_to'} && $self->{'converted_to'} eq 'HTML')){

	# remove comments in head, including multiline ones, so that we don't match on 
	# inactive tags (those that are nested inside comments)
	my ($head) = ($text =~ m/<head>(.*)<\/head>/si);
	$head = "" unless defined $head; # some files are not proper HTML eg php files
	$head =~ s/<!--.*?-->//sg;

	# remove <title>stuff</title> -- as titles tend often to be in English
	# for foreign language documents
	$text =~ s!<title>.*?</title>!!si;

	# see if this html file specifies its encoding
	if ($text =~ /^<\?xml.*encoding="(.+?)"/) {
	    $best_encoding = $1;
	}
	# check the meta http-equiv charset tag
	elsif ($head =~ m/<meta http-equiv.*content-type.*charset=(.+?)\"/si) {		       
	    $best_encoding = $1;
	}
	if ($best_encoding) { # we extracted an encoding
	    $best_encoding =~ s/-+/_/g;
	    $best_encoding = lc($best_encoding); # lowercase
	    if ($best_encoding eq "utf_8") { $best_encoding = "utf8" }
	    $found_html_encoding = 1;
	    # We shouldn't be modifying this here!!
	    #$self->{'input_encoding'} = $best_encoding;
	}
        
	# remove all HTML tags
	$text =~ s/<[^>]*>//sg;
    }

    # don't need to do textcat if we know the encoding now AND don't need to extract language
    if($found_html_encoding && !$self->{'extract_language'}) { # encoding specified in html file
	$best_language = $self->{'default_language'};
    }

    else { # need to use textcat to get either the language, or get both language and encoding
	$self->{'textcat'} = new textcat() if (!defined($self->{'textcat'}));
	
	if($found_html_encoding) { # know encoding, find language by limiting search to known encoding
	    my $results = $self->{'textcat'}->classify_contents_for_encoding(\$text, $filename, $best_encoding);
	    
	    my $language;
	    ($language) = $results->[0] =~ m/^([^-]*)(?:-(?:.*))?$/ if (scalar @$results > 0);

	    if (!defined $language || scalar @$results > 3) {
		# if there were too many results even when restricting results by encoding,
		# or if there were no results, use default language with the known encoding
		$best_language = $self->use_default_language($filename);
	    } 
	    else { # fewer than 3 results means textcat is more certain, use the first result
		$best_language = $language;		
	    } 
	}
	else { # don't know encoding or language yet, therefore we use textcat
	    my $results = $self->{'textcat'}->classify_contents(\$text, $filename);
	    
	    # if textcat returns 3 or less possibilities we'll use the first one in the list
	    if (scalar @$results <= 3) { # results will be > 0 when we don't constrain textcat by an encoding
		my ($language, $encoding) = $results->[0] =~ m/^([^-]*)(?:-(.*))?$/;

		$language = $self->use_default_language($filename) unless defined $language;
		$encoding = $self->use_default_encoding($filename) unless defined $encoding;

		$best_language = $language;
		$best_encoding = $encoding;
	    }
	    else { # if (scalar @$results > 3) {
		if ($unicode_format) { # in case the first had a BOM
		    $best_encoding=$unicode_format;
		}
		else {
		    # Find the most frequent encoding in the textcat results returned
		    # Returns "" if there's no encoding more frequent than another
		    $best_encoding = $self->{'textcat'}->most_frequent_encoding($results);
		}
		
		if ($best_encoding eq "") { # encoding still not set, use defaults
		    $best_language = $self->use_default_language($filename);
		    $best_encoding = $self->use_default_encoding($filename);
		}
		elsif (!$self->{'extract_language'}) { # know encoding but don't need to discover language
		    $best_language = $self->use_default_language($filename);
		}
		else { # textcat again using the most frequent encoding or the $unicode_format set above
		    $results = $self->{'textcat'}->classify_contents_for_encoding(\$text, $filename, $best_encoding);
		    my $language;
		    ($language) = $results->[0] =~ m/^([^-]*)(?:-(.*))?$/ if (scalar @$results > 0);
		    if (!defined $language || scalar @$results > 3) { 
			# if no result or too many results, use default language for the encoding previously found
			$best_language = $self->use_default_language($filename);
		    }
		    else { # fewer than 3 results, use the language of the first result
			$best_language = $language;
		    }
		}
	    }
	}
    }

    if($best_encoding eq "" || $best_language eq "") {
	print STDERR "****Shouldn't happen: encoding and/or language still not set. Using defaults.\n";
	$best_encoding = $self->use_default_encoding($filename) if $best_encoding eq "";
	$best_language = $self->use_default_language($filename) if $best_language eq "";
    }
#    print STDERR "****Content language: $best_language; Encoding: $best_encoding.\n";


    if ($best_encoding =~ /^iso_8859/ && &unicode::check_is_utf8($text)) {
	# the text is valid utf8, so assume that's the real encoding
	# (since textcat is based on probabilities)
	$best_encoding = 'utf8';
    }

    # check for equivalents where textcat doesn't have some encodings...
    # eg MS versions of standard encodings
    if ($best_encoding =~ /^iso_8859_(\d+)/) {
	my $iso = $1; # which variant of the iso standard?
	# iso-8859 sets don't use chars 0x80-0x9f, windows codepages do
	if ($text =~ /[\x80-\x9f]/) {
	    # Western Europe
	    if ($iso == 1 or $iso == 15) { $best_encoding = 'windows_1252' }
	    elsif ($iso == 2) {$best_encoding = 'windows_1250'} # Central Europe
	    elsif ($iso == 5) {$best_encoding = 'windows_1251'} # Cyrillic
	    elsif ($iso == 6) {$best_encoding = 'windows_1256'} # Arabic
	    elsif ($iso == 7) {$best_encoding = 'windows_1253'} # Greek
	    elsif ($iso == 8) {$best_encoding = 'windows_1255'} # Hebrew
	    elsif ($iso == 9) {$best_encoding = 'windows_1254'} # Turkish
	}
    }

    if ($best_encoding !~ /^(ascii|utf8|unicode)$/ &&
	!defined $encodings::encodings->{$best_encoding}) {
	if ($self->{'verbosity'}) {
	    gsprintf($outhandle, "ReadTextFile: {ReadTextFile.unsupported_encoding}\n",
		     $filename, $best_encoding, $self->{'default_encoding'});
	}
	$best_encoding = $self->{'default_encoding'};
    }

    return ($best_language, $best_encoding);
}


sub use_default_language {
    my $self = shift (@_);
    my ($filename) = @_;

    if ($self->{'verbosity'}>2) {
	gsprintf($self->{'outhandle'},
		 "ReadTextFile: {ReadTextFile.could_not_extract_language}\n",
		 $filename, $self->{'default_language'});
    }
    return $self->{'default_language'};
}

sub use_default_encoding {
    my $self = shift (@_);
    my ($filename) = @_;

    if ($self->{'verbosity'}>2) {
	gsprintf($self->{'outhandle'},
		 "ReadTextFile: {ReadTextFile.could_not_extract_encoding}\n",
		 $filename, $self->{'default_encoding'});
    }
    return $self->{'default_encoding'};
}

# Overridden by exploding plugins (eg. ISISPlug)
sub clean_up_after_exploding
{
    my $self = shift(@_);
}


1;
