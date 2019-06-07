###########################################################################
#
# CommonUtil.pm -- base class for file and directory plugins - aims to 
# handle all encoding stuff, blocking stuff, to keep it in one place
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2017 New Zealand Digital Library Project
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

package CommonUtil;

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use encodings;
use Unicode::Normalize 'normalize';

use PrintInfo;
use Encode;
use Unicode::Normalize 'normalize';

BEGIN {
    @CommonUtil::ISA = ( 'PrintInfo' );
}

our $encoding_list =
    [ { 'name' => "ascii",
	'desc' => "{CommonUtil.encoding.ascii}" },
      { 'name' => "utf8",
	'desc' => "{CommonUtil.encoding.utf8}" },
      { 'name' => "unicode",
	'desc' => "{CommonUtil.encoding.unicode}" } ];


my $e = $encodings::encodings;
foreach my $enc (sort {$e->{$a}->{'name'} cmp $e->{$b}->{'name'}} keys (%$e)) 
{
    my $hashEncode =
    {'name' => $enc,
     'desc' => $e->{$enc}->{'name'}};
    
    push(@{$encoding_list},$hashEncode);
}

our $encoding_plus_auto_list = 
    [ { 'name' => "auto",
	'desc' => "{CommonUtil.filename_encoding.auto}" },
      { 'name' => "auto-language-analysis",
	'desc' => "{CommonUtil.filename_encoding.auto_language_analysis}" }, # textcat
      { 'name' => "auto-filesystem-encoding",
	'desc' => "{CommonUtil.filename_encoding.auto_filesystem_encoding}" }, # locale
      { 'name' => "auto-fl",
	'desc' => "{CommonUtil.filename_encoding.auto_fl}" }, # locale followed by textcat
      { 'name' => "auto-lf",
	'desc' => "{CommonUtil.filename_encoding.auto_lf}" } ]; # texcat followed by locale 

push(@{$encoding_plus_auto_list},@{$encoding_list});

my $arguments =
    [  { 'name' => "block_exp",
	 'desc' => "{CommonUtil.block_exp}",
	 'type' => "regexp",
	 'deft' => "",
	 'reqd' => "no" },
       { 'name' => "no_blocking",
	 'desc' => "{CommonUtil.no_blocking}",
	 'type' => "flag",
	 'reqd' => "no"},
       { 'name' => "filename_encoding",
	 'desc' => "{CommonUtil.filename_encoding}",
	 'type' => "enum",
	 'deft' => "auto",
	 'list' => $encoding_plus_auto_list,
	 'reqd' => "no" }
    ];

my $options = { 'name'     => "CommonUtil",
		'desc'     => "{CommonUtil.desc}",
		'abstract' => "yes",
		'inherits' => "no",
		'args'     => $arguments };


sub new {

    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$auxiliary) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists,$auxiliary);

    return bless $self, $class;
 
}

sub init {    
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;

    # verbosity is passed through from the processor
    $self->{'verbosity'} = $verbosity;

    # as are the outhandle and failhandle
    $self->{'outhandle'} = $outhandle if defined $outhandle;
    $self->{'failhandle'} = $failhandle;

}

# converts raw filesystem filename to perl unicode format
sub raw_filename_to_unicode {
    my $self = shift (@_);
    my ($file) = @_;

    my $unicode_file = "";
    ### need it in perl unicode, not raw filesystem
    my $filename_encoding =  $self->guess_filesystem_encoding();  
		
    # copied this from set_Source_metadata in BaseImporter
    if ((defined $filename_encoding) && ($filename_encoding ne "ascii")) {
	# Use filename_encoding to map raw filename to a Perl unicode-aware string 
	$unicode_file = decode($filename_encoding,$file);		
    }
    else {
	# otherwise generate %xx encoded version of filename for char > 127
	$unicode_file = &unicode::raw_filename_to_url_encoded($file);
    }
    return $unicode_file;

}
# just converts path as is to utf8.
sub filepath_to_utf8 {
    my $self = shift (@_);  
    my ($file, $file_encoding) = @_;
    my $filemeta = $file;

    my $filename_encoding = $self->{'filename_encoding'}; # filename encoding setting

    # Whenever filename-encoding is set to any of the auto settings, we
    # check if the filename is already in UTF8. If it is, then we're done.
    if($filename_encoding =~ m/auto/) {
	if(&unicode::check_is_utf8($filemeta)) 
	{
	    $filename_encoding = "utf8";
	    return $filemeta;
	} 
    }
    
    # Auto setting, but filename is not utf8
    if ($filename_encoding eq "auto") 
    {
	# try textcat
	$filename_encoding = $self->textcat_encoding($filemeta);
	
	# check the locale next
	$filename_encoding = $self->locale_encoding() if $filename_encoding eq "undefined";
	
	
	# now try the encoding of the document, if available
	if ($filename_encoding eq "undefined" && defined $file_encoding) {
	    $filename_encoding = $file_encoding;
	}

    }

    elsif ($filename_encoding eq "auto-language-analysis") 
    {	
	$filename_encoding = $self->textcat_encoding($filemeta);

	# now try the encoding of the document, if available
	if ($filename_encoding eq "undefined" && defined $file_encoding) {
	    $filename_encoding = $file_encoding;
	} 
    }

    elsif ($filename_encoding eq "auto-filesystem-encoding") 
    {	
	# try locale
	$filename_encoding = $self->locale_encoding();
    }

    elsif ($filename_encoding eq "auto-fl") 
    {
	# filesystem-encoding (locale) then language-analysis (textcat)
	$filename_encoding = $self->locale_encoding();
	
	# try textcat
	$filename_encoding = $self->textcat_encoding($filemeta) if $filename_encoding eq "undefined";
	
	# else assume filename encoding is encoding of file content, if that's available
	if ($filename_encoding eq "undefined" && defined $file_encoding) {
	    $filename_encoding = $file_encoding;
	}
    }
    
    elsif ($filename_encoding eq "auto-lf") 
    {
	# language-analysis (textcat) then filesystem-encoding (locale)
	$filename_encoding = $self->textcat_encoding($filemeta);
	
	# guess filename encoding from encoding of file content, if available
	if ($filename_encoding eq "undefined" && defined $file_encoding) {
	    $filename_encoding = $file_encoding;
	}

	# try locale
	$filename_encoding = $self->locale_encoding() if $filename_encoding eq "undefined";
    }
    
    # if still undefined, use utf8 as fallback
    if ($filename_encoding eq "undefined") {
	$filename_encoding = "utf8";
    }

    #print STDERR "**** UTF8 encoding the filename $filemeta ";
    
    # if the filename encoding is set to utf8 but it isn't utf8 already--such as when
    # 1. the utf8 fallback is used, or 2. if the system locale is used and happens to
    # be always utf8 (in which case the filename's encoding is also set as utf8 even 
    # though the filename need not be if it originates from another system)--in such
    # cases attempt to make the filename utf8 to match.
    if($filename_encoding eq "utf8" && !&unicode::check_is_utf8($filemeta)) {
	&unicode::ensure_utf8(\$filemeta);
    }

    # convert non-unicode encodings to utf8
    if ($filename_encoding !~ m/(?:ascii|utf8|unicode)/) {
	$filemeta = &unicode::unicode2utf8(
					   &unicode::convert2unicode($filename_encoding, \$filemeta)
					   );
    }

    #print STDERR " from encoding $filename_encoding -> $filemeta\n";
    return $filemeta;
}

# gets the filename with no path, converts to utf8, and then dm safes it.
# filename_encoding set by user
sub filename_to_utf8_metadata
{
    my $self = shift (@_);  
    my ($file, $file_encoding) = @_;

    my $outhandle = $self->{'outhandle'};

    print $outhandle "****!!!!**** CommonUtil::filename_to_utf8_metadata now deprecated\n";
    my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(0);
    print $outhandle "Calling method: $cfilename:$cline $cpackage->$csubr\n";

    my ($filemeta) = $file =~ /([^\\\/]+)$/; # getting the tail of the filepath (skips all string parts containing slashes upto the end)
    $filemeta = $self->filepath_to_utf8($filemeta, $file_encoding);

    return $filemeta;
}

sub locale_encoding {
    my $self = shift(@_);
    
    if (!defined $self->{'filesystem_encoding'}) {
	$self->{'filesystem_encoding'} = $self->get_filesystem_encoding();
    }

    #print STDERR "*** filename encoding determined based on locale: " . $self->{'filesystem_encoding'} . "\n";
    return $self->{'filesystem_encoding'}; # can be the string "undefined"
}


sub textcat_encoding {
    my $self = shift(@_);
    my ($filemeta) = @_;

    # analyse filenames without extensions and digits (and trimmed of
    # surrounding whitespace), so that irrelevant chars don't confuse
    # textcat
    my $strictfilemeta = $filemeta;
    $strictfilemeta =~ s/\.[^\.]+$//g;
    $strictfilemeta =~ s/\d//g;
    $strictfilemeta =~ s/^\s*//g;
    $strictfilemeta =~ s/\s*$//g;
    
    my $filename_encoding = $self->encoding_from_language_analysis($strictfilemeta);
    if(!defined $filename_encoding) {
	$filename_encoding = "undefined";
    }

    return $filename_encoding; # can be the string "undefined"
}

# performs textcat
sub encoding_from_language_analysis {
    my $self = shift(@_);
    my ($text) = @_;

    my $outhandle = $self->{'outhandle'};
    my $best_encoding = undef;
    
    # get the language/encoding of the textstring using textcat
    require textcat;  # Only load the textcat module if it is required
    $self->{'textcat'} = new textcat() unless defined($self->{'textcat'});
    my $results = $self->{'textcat'}->classify_cached_filename(\$text);


    if (scalar @$results < 0) { 
	return undef;
    }
    
    # We have some results, we choose the first
    my ($language, $encoding) = $results->[0] =~ /^([^-]*)(?:-(.*))?$/;
    
    $best_encoding = $encoding;
    if (!defined $best_encoding) {
	return undef;
    } 
    
    if (defined $best_encoding && $best_encoding =~ m/^iso_8859/ && &unicode::check_is_utf8($text)) {
	# the text is valid utf8, so assume that's the real encoding (since textcat is based on probabilities)
	$best_encoding = 'utf8';
    }
    
    
    # check for equivalents where textcat doesn't have some encodings...
    # eg MS versions of standard encodings
    if (defined $best_encoding && $best_encoding =~ /^iso_8859_(\d+)/) {
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
    
    if (defined $best_encoding && $best_encoding !~ /^(ascii|utf8|unicode)$/ &&
	!defined $encodings::encodings->{$best_encoding}) 
    {
	if ($self->{'verbosity'}) { 
	    gsprintf($outhandle, "CommonUtil: {ReadTextFile.unsupported_encoding}\n", $text, $best_encoding, "undef");
	}
	$best_encoding = undef;
    }
    
    return $best_encoding;
}



sub deduce_filename_encoding
{
    my $self = shift (@_);  
    my ($file,$metadata,$plugin_filename_encoding) = @_;

    my $gs_filename_encoding = $metadata->{"gs.filenameEncoding"};
    my $deduced_filename_encoding = undef;
    
    # Start by looking for manually assigned metadata
    if (defined $gs_filename_encoding) {
	if (ref ($gs_filename_encoding) eq "ARRAY") {
	    my $outhandle = $self->{'outhandle'};
	    
	    $deduced_filename_encoding = $gs_filename_encoding->[0];
	    
	    my $num_vals = scalar(@$gs_filename_encoding);
	    if ($num_vals>1) {
		print $outhandle "Warning: gs.filenameEncoding multiply defined for $file\n";
		print $outhandle "         Selecting first value: $deduced_filename_encoding\n";
	    }
	} 
	else {
	    $deduced_filename_encoding = $gs_filename_encoding;
	}
    }
    
    if (!defined $deduced_filename_encoding || ($deduced_filename_encoding =~ m/^\s*$/)) {
	# Look to see if plugin specifies this value

	if (defined $plugin_filename_encoding) {
	    # First look to see if we're using any of the "older" (i.e. deprecated auto-... plugin options)
	    if ($plugin_filename_encoding =~ m/^auto-.*$/) {
		my $outhandle = $self->{'outhandle'};
		print $outhandle "Warning: $plugin_filename_encoding is no longer supported\n";
		print $outhandle "         default to 'auto'\n";
		$self->{'filename_encoding'} = $plugin_filename_encoding = "auto";
	    }
	    
	    if ($plugin_filename_encoding ne "auto") {
		# We've been given a specific filenamne encoding
		# => so use it!
		$deduced_filename_encoding = $plugin_filename_encoding;
	    }
	}
    }
    
    if (!defined $deduced_filename_encoding || ($deduced_filename_encoding =~ m/^\s*$/)) {

	# Look to file system to provide a character encoding

	# If Windows NTFS, then -- assuming we work with long file names got through
	# Win32::GetLongFilePath() -- then the underlying file system is UTF16

	if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	    # Can do better than working with the DOS character encoding returned by locale	    
	    $deduced_filename_encoding = "unicode";
	}
	else {
	    # Unix of some form or other

	    # See if we can determine the file system encoding through locale
	    $deduced_filename_encoding = $self->locale_encoding();
	    
	    # if locale shows us filesystem is utf8, check to see filename is consistent
	    # => if not, then we have an "alien" filename on our hands

	    if (defined $deduced_filename_encoding && $deduced_filename_encoding =~ m/^utf-?8$/i) {
		if (!&unicode::check_is_utf8($file)) {
		    # "alien" filename, so revert
		    $deduced_filename_encoding = undef;
		}
	    }
	}
    }
    
#    if (!defined $deduced_filename_encoding || ($deduced_filename_encoding =~ m/^\s*$/)) {
#		# Last chance, apply textcat to deduce filename encoding
#		$deduced_filename_encoding = $self->textcat_encoding($file);
#    }

    if ($self->{'verbosity'}>3) {
	my $outhandle = $self->{'outhandle'};

	if (defined $deduced_filename_encoding) {
	    print $outhandle "  Deduced filename encoding as: $deduced_filename_encoding\n";
	}
	else {
	    print $outhandle "  No filename encoding deduced\n";
	}
    }
    
    return $deduced_filename_encoding;
}


sub guess_filesystem_encoding
{
   my $self = shift (@_); 
	# Look to file system to provide a character encoding
   my $deduced_filename_encoding = "";
	# If Windows NTFS, then -- assuming we work with long file names got through
	# Win32::GetLongFilePath() -- then the underlying file system is UTF16

	if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	    # Can do better than working with the DOS character encoding returned by locale	    
	    $deduced_filename_encoding = "unicode";
	}
	else {
	    # Unix of some form or other

	    # See if we can determine the file system encoding through locale
	    $deduced_filename_encoding = $self->locale_encoding(); #utf8??
	    
	}
   return $deduced_filename_encoding;
}


# uses locale
sub get_filesystem_encoding 
{

    my $self = shift(@_);

    my $outhandle = $self->{'outhandle'};
    my $filesystem_encoding = undef;

    eval {
	# Works for Windows as well, returning the DOS code page in use	
	use POSIX qw(locale_h);
	
	# With only one parameter, setlocale retrieves the 
	# current value
	my $current_locale = setlocale(LC_CTYPE);
	
	my $char_encoding = undef;
	if ($current_locale =~ m/\./) {
	    ($char_encoding) = ($current_locale =~ m/^.*\.(.*?)$/);
	    $char_encoding = lc($char_encoding);
	}
	else {
	    if ($current_locale =~ m/^(posix|c)$/i) {
		$char_encoding = "ascii";
	    }
	}

	if (defined $char_encoding) {
	    if ($char_encoding =~ m/^(iso)(8859)-?(\d{1,2})$/) {
		$char_encoding = "$1\_$2\_$3";
	    }

	    $char_encoding =~ s/-/_/g;
	    $char_encoding =~ s/^utf_8$/utf8/;
	    
	    if ($char_encoding =~ m/^\d+$/) {
		if (defined $encodings::encodings->{"windows_$char_encoding"}) {
		    $char_encoding = "windows_$char_encoding";
		}
		elsif (defined $encodings::encodings->{"dos_$char_encoding"}) {
		    $char_encoding = "dos_$char_encoding";
		}
	    }
	    
	    if (($char_encoding =~ m/(?:ascii|utf8|unicode)/) 
		|| (defined $encodings::encodings->{$char_encoding})) {
		$filesystem_encoding = $char_encoding;
	    }
	    else {
		print $outhandle "Warning: Unsupported character encoding '$char_encoding' from locale '$current_locale'\n";
	    }
	}
	

    };
    if ($@) {
	print $outhandle "$@\n";
	print $outhandle "Warning: Unable to establish locale.  Will assume filesystem is UTF-8\n";
	
    }

    return $filesystem_encoding;
}



# write_file -- used by ConvertToPlug, for example in post processing
#
# where should this go, is here the best place??
sub utf8_write_file {
    my $self = shift (@_);
    my ($textref, $filename) = @_;
    
    if (!open (FILE, ">:utf8", $filename)) {
	gsprintf(STDERR, "ConvertToPlug::write_file {ConvertToPlug.could_not_open_for_writing} ($!)\n", $filename);
	die "\n";
    }
    print FILE $$textref;
    
    close FILE;
}

sub block_raw_filename {

    my $self = shift (@_);
    my ($block_hash,$filename_full_path) = @_;

    my $unicode_filename = $self->raw_filename_to_unicode($filename_full_path);
    return $self->block_filename($block_hash, $unicode_filename);
}

# block unicode string filename
sub block_filename
{
    my $self = shift (@_);
    my ($block_hash,$filename_full_path) = @_;
     
    if (($ENV{'GSDLOS'} =~ m/^windows$/) && ($^O ne "cygwin")) {
	   # block hash contains long names, lets make sure that we were passed a long name
	   $filename_full_path = &util::upgrade_if_dos_filename($filename_full_path);
	   # lower case the entire thing, eg for cover.jpg when its actually cover.JPG
	   my $lower_filename_full_path = lc($filename_full_path);
	   $block_hash->{'file_blocks'}->{$lower_filename_full_path} = 1;
	
    }
    elsif ($ENV{'GSDLOS'} =~ m/^darwin$/) {
	# we need to normalize the filenames
        my $composed_filename_full_path = normalize('C', $filename_full_path);
       ## print STDERR "darwin, composed filename =". &unicode::debug_unicode_string($composed_filename_full_path)."\n";
        $block_hash->{'file_blocks'}->{$composed_filename_full_path} = 1;
   }
 
    else {
	$block_hash->{'file_blocks'}->{$filename_full_path} = 1;
    }
}


# filename is raw filesystem name
sub raw_file_is_blocked {
     my $self = shift (@_);
     my ($block_hash, $filename_full_path) = @_;

     my $unicode_filename_full_path = $self->raw_filename_to_unicode($filename_full_path);
     return $self->file_is_blocked($block_hash, $unicode_filename_full_path);
}

# filename must be perl unicode string
sub file_is_blocked {
    my $self = shift (@_);
    my ($block_hash, $filename_full_path) = @_;

    # 
    if (($ENV{'GSDLOS'} =~ m/^windows$/) && ($^O ne "cygwin")) {
	# convert to long filenames if needed
	$filename_full_path = &util::upgrade_if_dos_filename($filename_full_path);
	# all block paths are lowercased.
	my $lower_filename = lc ($filename_full_path);
	if (defined $block_hash->{'file_blocks'}->{$lower_filename}) {
	    $self->{'num_blocked'} ++;
	    return 1;
	}
    }
    elsif ($ENV{'GSDLOS'} =~ m/^darwin$/) {

	# on mac, we want composed form in the block hash    
        my $composed_form = normalize('C', $filename_full_path);
        if (defined $block_hash->{'file_blocks'}->{$composed_form}) {
            $self->{'num_blocked'} ++;
            return 1;
        }
    }

    else {
	if (defined $block_hash->{'file_blocks'}->{$filename_full_path}) {
	    $self->{'num_blocked'} ++;
	    return 1;
	}
    }
    # check Directory plugin's own block_exp 
    if ($self->{'block_exp'} ne "" && $filename_full_path =~ /$self->{'block_exp'}/) {
	$self->{'num_blocked'} ++;
	return 1; # blocked
    }
    return 0;
}


1;

