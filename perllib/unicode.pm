###########################################################################
#
# unicode.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2004 New Zealand Digital Library Project
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

# useful functions for dealing with Unicode

# Unicode strings are stored as arrays of scalars as perl 
# lacks characters are 8-bit (currently)

package unicode;

eval {require bytes};

use encodings;
use strict;
use util;
use FileUtils;
use MIME::Base64; # for base64 encoding

no strict 'refs';



sub utf8decomp
{   
    my ($str) = @_;

    return if (!defined $str);
    return "" if ($str eq "");
	
    my @unpacked_chars = unpack("C*", $str); # unpack Unicode characters

    my @each_char
	= map { ($_ > 255 )
		   ? # if wide character...
		     sprintf("\\x{%04X}", $_) 
		   : # \x{...}
		     (chr($_) =~ m/[[:cntrl:]]/ )
		     ? # else if control character ...
		       sprintf("\\x%02X", $_) 
		     : # \x..
		       quotemeta(chr($_)) # else quoted or as themselves
		   } @unpacked_chars;
    
    return join("",@each_char);
}


sub hex_codepoint {
    if (my $char = shift) {
        return sprintf '%2.2x', unpack('U0U*', $char);
    }
}




# ascii2unicode takes an (extended) ascii string (ISO-8859-1)
# and returns a unicode array.
sub ascii2unicode {
    my ($in) = @_;
    my $out = [];

    my $i = 0;
    my $len = length($in);
    while ($i < $len) {
	push (@$out, ord(substr ($in, $i, 1)));	
	$i++;
    }

    return $out;
}

# ascii2utf8 takes a reference to an (extended) ascii string and returns a
# UTF-8 encoded string. This is just a faster version of
# "&unicode2utf8(&ascii2unicode($str));"
# "Extended ascii" really means "iso_8859_1"
sub ascii2utf8 {
    my ($in) = @_;
    my $out = "";

    if (!defined($in)|| !defined($$in)) {
	return $out;
    }

    my ($c);
    my $i = 0;
    my $len = length($$in);
    while ($i < $len) {
	$c = ord (substr ($$in, $i, 1));
	if ($c < 0x80) {
	    # ascii character
	    $out .= chr ($c);

	} else {
	    # extended ascii character
	    $out .= chr (0xc0 + (($c >> 6) & 0x1f));
	    $out .= chr (0x80 + ($c & 0x3f));
	}
	$i++;
    }

    return $out;
}

# unicode2utf8 takes a unicode array as input and encodes it
# using utf-8
sub unicode2utf8 {
    my ($in) = @_;
    my $out = "";
    
    foreach my $num (@$in) {
	next unless defined $num;
	if ($num < 0x80) {
	    $out .= chr ($num);

	} elsif ($num < 0x800) {
	    $out .= chr (0xc0 + (($num >> 6) & 0x1f));
	    $out .= chr (0x80 + ($num & 0x3f));

	} elsif ($num < 0xFFFF) {
	    $out .= chr (0xe0 + (($num >> 12) & 0xf));
	    $out .= chr (0x80 + (($num >> 6) & 0x3f));
	    $out .= chr (0x80 + ($num & 0x3f));

	} else {
	    # error, don't encode anything
	    #die;
	    # Diego's bugfix: instead of aborting the import process, it
	    # is better to get a converted file with a few extra spaces
	    print STDERR "strange char: $num\n";
	    $out .= " ";

	}
    }
    return $out;
}

# utf82unicode takes a utf-8 string and produces a unicode
# array
sub utf82unicode {
    my ($in) = @_;
    my $out = [];

    if(!defined $in) {
	return $out;
    }

    my $i = 0;
    my ($c1, $c2, $c3);
    my $len = length($in);
    while ($i < $len) {
	if (($c1 = ord(substr ($in, $i, 1))) < 0x80) {
	    # normal ascii character
	    push (@$out, $c1);

	} elsif ($c1 < 0xc0) {
	    # error, was expecting the first byte of an
	    # encoded character. Do nothing.

	} elsif ($c1 < 0xe0 && $i+1 < $len) {
	    # an encoded character with two bytes
	    $c2 = ord (substr ($in, $i+1, 1));
	    if ($c2 >= 0x80 && $c2 < 0xc0) {
		# everything looks ok
		push (@$out, ((($c1 & 0x1f) << 6) +
		      ($c2 & 0x3f)));
		$i++; # gobbled an extra byte
	    }

	} elsif ($c1 < 0xf0 && $i+2 < $len) {
	    # an encoded character with three bytes
	    $c2 = ord (substr ($in, $i+1, 1));
	    $c3 = ord (substr ($in, $i+2, 1));
	    if ($c2 >= 0x80 && $c2 < 0xc0 &&
		$c3 >= 0x80 && $c3 < 0xc0) {
		# everything looks ok
		push (@$out, ((($c1 & 0xf) << 12) +
		      (($c2 & 0x3f) << 6) +
		      ($c3 & 0x3f)));

		$i += 2; # gobbled an extra two bytes
	    }

	} else {
	    # error, only decode Unicode characters not full UCS.
	    # Do nothing.
	}

	$i++;
    }

    return $out;
}

# unicode2ucs2 takes a unicode array and produces a UCS-2
# unicode string (every two bytes forms a unicode character)
sub unicode2ucs2 {
    my ($in) = @_;
    my $out = "";

    foreach my $num (@$in) {
	$out .= chr (($num & 0xff00) >> 8);
	$out .= chr ($num & 0xff);
    }

    return $out;
}

# ucs22unicode takes a UCS-2 string and produces a unicode array
sub ucs22unicode {
    my ($in) = @_;
    my $out = [];

    my $i = 0;
    my $len = length ($in);
    while ($i+1 < $len) {
	push (@$out, ord (substr($in, $i, 1)) << 8 +
	      ord (substr($in, $i+1, 1)));

	$i ++;
    }

    return $out;
}

# takes a reference to a string and returns a reference to a unicode array
sub convert2unicode {
    my ($encoding, $textref) = @_;

    if (!defined $encodings::encodings->{$encoding}) {
	print STDERR "unicode::convert2unicode: ERROR: Unsupported encoding ($encoding)\n";
	return [];
    }

    my $encodename = "$encoding-unicode";
    my $enc_info = $encodings::encodings->{$encoding};
    my $mapfile = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "mappings",
				      "to_uc", $enc_info->{'mapfile'});
    if (!&loadmapencoding ($encodename, $mapfile)) {
	print STDERR "unicode: ERROR - could not load encoding $encodename: $! $mapfile\n";
	return [];
    }
    
    if (defined $enc_info->{'converter'}) {
	my $converter = $enc_info->{'converter'};
	return &$converter ($encodename, $textref);
    }

    if ($unicode::translations{$encodename}->{'count'} == 1) {
	return &singlebyte2unicode ($encodename, $textref);
    } else {
	return &doublebyte2unicode ($encodename, $textref);
    }
}

# singlebyte2unicode converts simple 8 bit encodings where characters below
# 0x80 are normal ascii characters and the rest are decoded using the
# appropriate mapping files.
#
# Examples of encodings that may be converted using singlebyte2unicode are
# the iso-8859 and windows-125* series.
sub singlebyte2unicode {
    my ($encodename, $textref) = @_;

    my @outtext = ();
    my $len = length($$textref);
    my ($c);
    my $i = 0;

    while ($i < $len) {
	if (($c = ord(substr($$textref, $i, 1))) < 0x80) {
	    # normal ascii character
	    push (@outtext, $c);
	} else {
	    $c = &transchar ($encodename, $c);
	    # put a black square if cannot translate
	    $c = 0x25A1 if $c == 0;
	    push (@outtext, $c);
	}
	$i ++;
    }
    return \@outtext;
}

# doublebyte2unicode converts simple two byte encodings where characters
# below code point 0x80 are single-byte characters and the rest are
# double-byte characters.
#
# Examples of encodings that may be converted using doublebyte2unicode are
# CJK encodings like GB encoded Chinese and UHC Korean.
#
# Note that no error checking is performed to make sure that the input text
# is valid for the given encoding.
#
# Also, encodings that may contain characters of more than two bytes are
# not supported (any EUC encoded text may in theory contain 3-byte
# characters but in practice only one and two byte characters are used).
sub doublebyte2unicode {
    my ($encodename, $textref) = @_;    
    
    my @outtext = ();
    my $len = length($$textref);
    my ($c1, $c2);
    my $i = 0;

    while ($i < $len) {
	if (($c1 = ord(substr($$textref, $i, 1))) >= 0x80) {
	    if ($i+1 < $len) {
		# double-byte character
		$c2 = ord(substr($$textref, $i+1, 1));
		my $c = &transchar ($encodename, ($c1 << 8) | $c2);
		# put a black square if cannot translate
		$c = 0x25A1 if $c == 0;
		push (@outtext, $c);
		$i += 2;
		
	    } else {
		# error
		print STDERR "unicode: ERROR missing second half of double-byte character\n";
		$i++;
	    }
	    
	} else {
	    # single-byte character
	    push (@outtext, $c1);
	    $i++;
	}
    }
    return \@outtext;
}

# Shift-JIS to unicode
# We can't use doublebyte2unicode for Shift-JIS because it uses some
# single-byte characters above code point 0x80 (i.e. half-width katakana
# characters in the range 0xA1-0xDF)
sub shiftjis2unicode {
    my ($encodename, $textref) = @_;
    
    my @outtext = ();
    my $len = length($$textref);
    my ($c1, $c2);
    my $i = 0;

    while ($i < $len) {
	$c1 = ord(substr($$textref, $i, 1));

	if (($c1 >= 0xA1 && $c1 <= 0xDF) || $c1 == 0x5c || $c1 == 0x7E) {
	    # Single-byte half-width katakana character or
	    # JIS Roman yen or overline characters
	    my $c = &transchar ($encodename, $c1);
	    # - put a black square if cannot translate
	    $c = 0x25A1 if $c == 0;
	    push (@outtext, $c);
	    $i++;

	} elsif ($c1 < 0x80) {
	    # ASCII
	    push (@outtext, $c1);
	    $i ++;

	} elsif ($c1 < 0xEF) {
	    if ($i+1 < $len) {
		$c2 = ord(substr($$textref, $i+1, 1));
		if (($c2 >= 0x40 && $c2 <= 0x7E) || ($c2 >= 0x80 && $c2 <= 0xFC)) {
		    # Double-byte shift-jis character
		    my $c = &transchar ($encodename, ($c1 << 8) | $c2);
		    # put a black square if cannot translate
		    $c = 0x25A1 if $c == 0;
		    push (@outtext, $c);
		} else {
		    # error
		    print STDERR "unicode: ERROR Invalid Shift-JIS character\n";
		}
		$i += 2;
	    } else {
		# error
		print STDERR "unicode: ERROR missing second half of Shift-JIS character\n";
		$i ++;
	    }
	} else {
	    # error
	    print STDERR "unicode: ERROR Invalid Shift-JIS character\n";
	    $i ++;
	}
    }
    return \@outtext;
}

sub transchar {
    my ($encoding, $from) = @_;
    my $high = ($from / 256) % 256;
    my $low = $from % 256;

    return 0 unless defined $unicode::translations{$encoding};

    my $block = $unicode::translations{$encoding}->{'map'};

    if (ref ($block->[$high]) ne "ARRAY") {
	return 0;
    }
    return $block->[$high]->[$low];
}

# %translations is of the form:
#
# encodings{encodingname-encodingname}->{'map'}->blocktranslation
# blocktranslation->[[0-255],[256-511], ..., [65280-65535]]
#
# Any of the top translation blocks can point to an undefined
# value. This data structure aims to allow fast translation and 
# efficient storage.
%unicode::translations = ();

# @array256 is used for initialisation, there must be
# a better way...
# What about this?: @array256 = (0) x 256;
@unicode::array256 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

# returns 1 if successful, 0 if unsuccessful
sub loadmapencoding {
    my ($encoding, $mapfile) = @_;
    
    # check to see if the encoding has already been loaded
    return 1 if (defined $unicode::translations{$encoding});

    if (! -r $mapfile || -d $mapfile) {
	return 0;
    }
    return 0 unless open (MAPFILE, $mapfile);
    binmode (MAPFILE);

    $unicode::translations{$encoding} = {'map' => [@unicode::array256], 'count' => 0};
    my $block = $unicode::translations{$encoding};

    my ($in,$i,$j);
    while (1) {
	my $ret=read(MAPFILE, $in, 1);
	if (!defined($ret)) { # error
	    print STDERR "unicode.pm: error reading mapfile: $!\n";
	    last;
	}
	if ($ret != 1) { last }
	$i = unpack ("C", $in);
	$block->{'map'}->[$i] = [@unicode::array256];
	for ($j=0; $j<256 && read(MAPFILE, $in, 2)==2; $j++) {
	    my ($n1, $n2) = unpack ("CC", $in);
	    $block->{'map'}->[$i]->[$j] = ($n1*256) + $n2;
	}
	$block->{'count'} ++;
    }

    close (MAPFILE);
}

# unicode2singlebyte converts unicode to simple 8 bit encodings where
# characters below 0x80 are normal ascii characters and the rest are encoded
# using the appropriate mapping files.
#
# Examples of encodings that may be converted using unicode2singlebyte are
# the iso-8859 and windows-125* series, KOI8-R (Russian), and the Kazakh encoding.
sub unicode2singlebyte {
    my ($uniref, $encoding) = @_;

    my $outtext = "";
    my $encodename = "unicode-$encoding";

    if (!exists $encodings::encodings->{$encoding}) {
	print STDERR "unicode.pm: ERROR - unsupported encoding "
	    . "'$encoding' requested\n";
	return "";
    }

    my $enc_info = $encodings::encodings->{$encoding};
    my $mapfile = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "mappings",
				      "from_uc", $enc_info->{'mapfile'});
    if (!&loadmapencoding ($encodename, $mapfile)) {
	print STDERR "unicode: ERROR - could not load encoding $encodename: $! $mapfile\n";
	return "";
    }
    
    foreach my $c (@$uniref) {
	if ($c < 0x80) {
	    # normal ascii character
	    $outtext .= chr($c);
	} else {
	    # extended ascii character
	    $c = &transchar ($encodename, $c);

	    # put a question mark if cannot translate
	    if ($c == 0) {
		$outtext .= "?";
	    } else {
		$outtext .= chr($c);
	    }
	}
    }
    return $outtext;
}


# this makes sure that the referenced input string is utf8 encoded, and
# will change/remove bytes that aren't.
# returns 0 if the text was already utf8, or 1 if text modified to become utf8
sub ensure_utf8 {
    my $stringref=shift;

    if (!defined($stringref) || ref($stringref) ne 'SCALAR') {
	return $stringref;
    }

    my $value=$$stringref;

    my $non_utf8_found = 0;
    $value =~ m/^/g; # to set \G
    while ($value =~ m!\G.*?([\x80-\xff]+)!sg) {
	my $highbytes=$1;
	my $highbyteslength=length($highbytes);
	# make sure this block of high bytes is utf-8
	$highbytes =~ /^/g; # set pos()
	my $byte_replaced = 0;
	while ($highbytes =~
		m!\G (?: [\xc0-\xdf][\x80-\xbf]   | # 2 byte utf-8
			[\xe0-\xef][\x80-\xbf]{2} | # 3 byte
			[\xf0-\xf7][\x80-\xbf]{3} | # 4 byte
			[\xf8-\xfb][\x80-\xbf]{4} | # 5 byte
			[\xfc-\xfd][\x80-\xbf]{5} | # 6 byte
			)*([\x80-\xff])? !xg
		) {
	    # this highbyte is "out-of-place" for valid utf-8
	    my $badbyte=$1;
	    if (!defined $badbyte) {next} # hit end of string
	    my $pos=pos($highbytes);
	    # replace bad byte. assume iso-8859-1 -> utf-8
	    # ascii2utf8 does "extended ascii"... ie iso-8859-1
	    my $replacement=&unicode::ascii2utf8(\$badbyte);
	    substr($highbytes, $pos-1, 1, $replacement);
	    # update the position to continue searching (for \G)
	    pos($highbytes) = $pos+length($replacement)-1;
	    $byte_replaced = 1;
	}
	if ($byte_replaced) {
	    # replace this block of high bytes in the $value
	    $non_utf8_found = 1;
	    my $replength=length($highbytes); # we've changed the length
	    my $textpos=pos($value); # pos at end of last match
	    # replace bad bytes with good bytes
	    substr($value, $textpos-$highbyteslength,
			    $highbyteslength, $highbytes);
	    # update the position to continue searching (for \G)
	    pos($value)=$textpos+($replength-$highbyteslength)+1;
	}
    }

    $$stringref = $value;
    return $non_utf8_found;
}

# Returns true (1) if the given string is utf8 and false (0) if it isn't.
# Does not modify the string parameter.
sub check_is_utf8 {
    my $value=shift;

    if (!defined($value)) {
	return 0; # not utf8 because it is undefined
    }

    $value =~ m/^/g; # to set \G
    while ($value =~ m!\G.*?([\x80-\xff]+)!sg) {
	my $highbytes=$1;
	# make sure this block of high bytes is utf-8
	$highbytes =~ /^/g; # set pos()
	while ($highbytes =~
		m!\G (?: [\xc0-\xdf][\x80-\xbf]   | # 2 byte utf-8
			[\xe0-\xef][\x80-\xbf]{2} | # 3 byte
			[\xf0-\xf7][\x80-\xbf]{3} | # 4 byte
			[\xf8-\xfb][\x80-\xbf]{4} | # 5 byte
			[\xfc-\xfd][\x80-\xbf]{5} | # 6 byte
			)*([\x80-\xff])? !xg
		) {
	    my $badbyte=$1;
	    if (defined $badbyte) { # not end of string
		return 0; # non-utf8 found
	    } 
	}
    }
    
    return 1;
}

sub url_encode {
    my ($text) = @_;
    
    if (!&is_url_encoded($text)) {
	$text =~ s/([^0-9A-Z\ \.\-\_])/sprintf("%%%02X", ord($1))/iseg;
	# return the url-encoded character entity for underscore back to the entity
	$text =~ s/%26%23095%3B/&\#095;/g;
    }
    return $text;
}

sub url_decode {
    my ($text,$and_numeric_entities) = @_;

    if(defined $text) {
	$text =~ s/\%([0-9A-F]{2})/pack('C', hex($1))/ige;
	
	if ((defined $and_numeric_entities) && ($and_numeric_entities)) {
	    $text =~ s/\&\#x([0-9A-F]+);/pack('C', hex($1))/ige;
	    $text =~ s/\&\#u?([0-9]+);/pack('C', $1)/ige;
	}
    }

    return $text;
}

sub url_decode_utf8 {
    my ($text,$and_numeric_entities) = @_;

    $text =~ s/\%([0-9A-F]{2})/pack('b', hex($1))/ige;

    $text = Encode::decode("utf8",$text);

    return $text;
}

sub is_url_encoded {
    my ($text) = @_;
    return ($text =~ m/\%([0-9A-F]{2})/i) || ($text =~ m/\&\#x([0-9A-F]+;)/i) || ($text =~ m/\&\#([0-9]+;)/i);
}

# When a filename on the filesystem is already URL-encoded, the
# URL to it will have %25s in place of every % sign, so that 
# URLs in html pages can refer to the URL-encoded filename.
# This method changes the URL reference back into the actual 
# (URL-encoded) filename on the filesystem by replacing %25 with %. 
sub url_to_filename {
    my ($text) =@_;
    $text =~ s/%25/%/g if &is_url_encoded($text);
    # DM safing would have replaced underscores with character entity &#095; 
    # in SourceFile meta. Undo any such change to get the filename referred to.
    $text =~ s/&\#095;/_/g;
    return $text;
}

# When a filename on the filesystem is already URL-encoded, the
# URL to it will have %25s in place of every % sign, so that 
# URLs in html pages can refer to the URL-encoded filename.
# Given a (URL-encoded) filename on the filesystem, this subroutine
# returns the URL reference string for it by replacing % with %25. 
# The output string will be the same as the input string if the input
# already contains one or more %25s. This is to prevent processing 
# a url more than once this way.
sub filename_to_url {
    my ($text) = @_;
    
    if($text !~ m/%25/) {
	$text =~ s/%/%25/g;
    }
    return $text;
}

sub base64_encode {
    my ($text) = @_;
    if(!&conforms_to_mod_base64($text)) {
	# return entity for underscore to underscore before encoding
	$text =~ s/&\#095;/_/g;

	$text = &MIME::Base64::encode_base64($text);
	# base64 encoding may introduce + and / signs,
	# replacing them with - and _ to ensure it's filename-safe
	$text =~ s/\+/\-/g; # + -> -
	$text =~ s/\//\_/g; # / -> _
    }
    return $text;
}

# If the input fits the modified base64 pattern, this will try decoding it. 
# Still, this method does not guarantee the return value is the 'original', only
# that the result is where the base64 decoding process has been applied once.
# THIS METHOD IS NOT USED at the moment. It's here for convenience and symmetry.
sub base64_decode {
    my ($text) = @_;
    if(&conforms_to_mod_base64($text)) {
	# base64 encodes certain chars with + and /, but if we'd encoded it, we'd
	# have replaced them with - and _ respectively. Undo this before decoding.
	$text =~ s/\-/\+/g;      # - -> +
	$text =~ s/\_/\//g;      # _ -> /
	$text = &MIME::Base64::decode_base64($text);
    }
    return $text;
}

# Returns true if the given string is compatible with a modified version
# of base64 (where the + and / are replaced with - and _), a format which 
# includes also regular ASCII alphanumeric values. This method does not 
# guarantee that the given string is actually base64 encoded, since it will
# return true for any simple alphanumeric ASCII string as well. 
sub conforms_to_mod_base64 {
    my ($text) = @_;

    # need to treat the entity ref for underscore as underscore
    $text =~ s/&\#095;/_/g;

    # base 64 takes alphanumeric and [=+/], 
    # but we use modified base64 where + and / are replaced with  - and _
    return ($text =~ m/^[A-Za-z0-9\=\-\_]+$/); #alphanumeric and [=-_]
}

sub substr
{
    my ($utf8_string, $offset, $length) = @_;

    my @unicode_string = @{&utf82unicode($utf8_string)};
    my $unicode_string_length = scalar(@unicode_string);

    my $substr_start = $offset;
    if ($substr_start >= $unicode_string_length) {
	return "";
    }

    my $substr_end = $offset + $length - 1;
    if ($substr_end >= $unicode_string_length) {
	$substr_end = $unicode_string_length - 1;
    }

    my @unicode_substring = @unicode_string[$substr_start..$substr_end];
    return &unicode2utf8(\@unicode_substring);
}

# Useful method to print UTF8 (or other unicode) for debugging.
# Characters that are easily displayed (that is, printable ASCII) 
# are shown as-is, whereas hex values of the unicode code points 
# are shown for all other chars.
sub debug_unicode_string
{
    join("",
         map { $_ > 127 ?                      # if wide character...
                   sprintf("\\x{%04X}", $_) :  # \x{...}
                   chr($_)          
               } unpack("U*", $_[0]));         # unpack Unicode characters
}


sub raw_filename_to_url_encoded
{
    my ($str_in) = @_;

    my @url_encoded_chars
	= map { $_ > 255 ?                  # Needs to be represent in entity form
		    sprintf("&#x%X;",$_) :  
		    $_>127 || $_==ord("%") ?              # Representable in %XX form
		    sprintf("%%%2X", $_) :  
		    chr($_)                 # otherwise, Ascii char
		} unpack("U*", $str_in); # Unpack Unicode characters

    
    my $str_out = join("", @url_encoded_chars);

    return $str_out;

}

sub url_encoded_to_raw_filename
{
    my ($str_in) = @_;

    my $str_out = $str_in;

    $str_out =~ s/%([0-9A-F]{2})/chr(hex($1))/eig;
    $str_out =~ s/&#x([0-9A-F]+);/chr(hex($1))/eig;
    $str_out =~ s/&#([0-9]+);/chr($1)/eig;

    return $str_out;
}


sub raw_filename_to_utf8_url_encoded
{
    my ($str_in) = @_;

    $str_in = Encode::encode("utf8",$str_in) if !check_is_utf8($str_in);

    my @url_encoded_chars
	= map { $_ > 127 ?                  # Representable in %XX form
		    sprintf("%%%2X", $_) :  
		    chr($_)                 # otherwise, Ascii char
		} unpack("U*", $str_in); # Unpack utf8 characters

    
    my $str_out = join("", @url_encoded_chars);

    return $str_out;

}

sub utf8_url_encoded_to_raw_filename
{
    my ($str_in) = @_;

    my $utf8_str_out = $str_in;

    $utf8_str_out =~ s/%([0-9A-F]{2})/chr(hex($1))/eig;

    my $unicode_str_out = decode("utf8",$utf8_str_out);
    my $raw_str_out = utf8::downgrade($unicode_str_out);
    
    return $raw_str_out;
}

sub analyze_raw_string
{
    my ($str_in) = @_;

    my $uses_bytecodes = 0;
    my $exceeds_bytecodes = 0;

    map { $exceeds_bytecodes = 1 if ($_ >= 256);
	  $uses_bytecodes    = 1 if (($_ >= 128) && ($_ < 256));
    } unpack("U*", $str_in); # Unpack Unicode characters

    return ($uses_bytecodes,$exceeds_bytecodes);
}


sub convert_utf8_string_to_unicode_string
{
    my $utf8_string = shift(@_);

    my $unicode_string = "";
    foreach my $unicode_value (@{&unicode::utf82unicode($utf8_string)}) {
	$unicode_string .= chr($unicode_value);
    }
    return $unicode_string;
}

sub convert_unicode_string_to_utf8_string
{
    my $unicode_string = shift(@_);

    my @unicode_array;
    for (my $i = 0; $i < length($unicode_string); $i++) {
	push(@unicode_array, ord(&substr($unicode_string, $i, 1)));
    }
    return &unicode::unicode2utf8(\@unicode_array);
}


1;
