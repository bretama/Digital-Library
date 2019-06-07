###########################################################################
#
# ghtml.pm -- this used to be called html.pm but it clashed
# with the existing html module under windows
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

package ghtml;

use strict;
use unicode;

# htmlsafe(TEXT)
# 
# Converts SGML meta characters in TEXT to entity references.
# 
sub htmlsafe
{
    $_[0] =~ s/&/&amp;/osg;
    $_[0] =~ s/</&lt;/osg;
    $_[0] =~ s/>/&gt;/osg;
    $_[0] =~ s/\"/&quot;/osg;
}

# unescape_html(TEXT)
# 
# Converts HTML entities into their original form.
# 
sub unescape_html
{
    my ($html) = @_;

    $html =~ s/&amp;/&/osg;
    $html =~ s/&lt;/</osg;
    $html =~ s/&gt;/>/osg;
    $html =~ s/&quot;/\"/osg;

    return $html;
}

# urlsafe(TEXT)
# 
# Converts characters not allowed in a URL to their hex representation.
# 
sub urlsafe
{
    # protect any hash's that are part of an entity, e.g. &#097;
    $_[0] =~ s/&#(.*?);/&%23$1;/g;

    # and the usual suspects
    $_[0] =~ s/[\x09\x20\x22\x3c\x3e\x5b\x5c\x5d\x5e\x60\x7b\x7c\x7d\x7e\?\=\&\+_\/]/sprintf("%%%2x", ord($&))/gse;
}


# named entry to the standard html font
my %charnetosf = ("Agrave"=> "192",  "Aacute"=> "193",  "Acirc" => "194",  "Atilde"=> "195",
	       "Auml"  => "196",  "Aring" => "197",  "AElig" => "198",  "Ccedil"=> "199",
	       "Egrave"=> "200",  "Eacute"=> "201",  "Ecirc" => "202",  "Euml"  => "203",
	       "Igrave"=> "204",  "Iacute"=> "205",  "Icirc" => "206",  "Iuml"  => "207",
	       "ETH"   => "208",  "Ntilde"=> "209",  "Ograve"=> "210",  "Oacute"=> "211",
	       "Ocirc" => "212",  "Otilde"=> "213",  "Ouml"  => "214",  
	       "Oslash"=> "216",  "Ugrave"=> "217",  "Uacute"=> "218",  "Ucirc" => "219",
	       "Uuml"  => "220",  "Yacute"=> "221",  "THORN" => "222",  "szlig" => "223",
	       "agrave"=> "224",  "aacute"=> "225",  "acirc" => "226",  "atilde"=> "227",
	       "auml"  => "228",  "aring" => "229",  "aelig" => "230",  "ccedil"=> "231",
	       "egrave"=> "232",  "eacute"=> "233",  "ecirc" => "234",  "euml"  => "235",
	       "igrave"=> "236",  "iacute"=> "237",  "icirc" => "238",  "iuml"  => "239",
	       "eth"   => "240",  "ntilde"=> "241",  "ograve"=> "242",  "oacute"=> "243",
	       "ocirc" => "244",  "otilde"=> "245",  "ouml"  => "246",  
	       "oslash"=> "248",  "ugrave"=> "249",  "uacute"=> "250",  "ucirc" => "251",
	       "uuml"  => "252",  "yacute"=> "253",  "thorn" => "254",  "yuml"  => "255");

my %symnetosf = ("quot"  => "34",   "amp"   => "38",   "lt"    => "60",   "gt"    => "62",
	      "nbsp"  => "160",  "iexcl" => "161",  "cent"  => "162",  "pound" => "163",
	      "curren"=> "164",  "yen"   => "165",  "brvbar"=> "166",  "sect"  => "167",
	      "uml"   => "168",  "copy"  => "169",  "ordf"  => "170",  "laquo" => "171",
	      "not"   => "172",  "shy"   => "173",  "reg"   => "174",  "macr"  => "175",
	      "deg"   => "176",  "plusmn"=> "177",  "sup2"  => "178",  "sup3"  => "179",
	      "acute" => "180",  "micro" => "181",  "para"  => "182",  "middot"=> "183",
	      "cedil" => "184",  "sup1"  => "185",  "ordm"  => "186",  "raquo" => "187",
	      "frac14"=> "188",  "frac12"=> "189",  "frac34"=> "190",  "iquest"=> "191",
	      "times" => "215",  "divide"=> "247");



# standard font to plain text
my %sftotxt = ("32"  => " ",  "33"  => "!",  "34"  => "\"",  "35"  => "\#",  "36"  => "\$",
	    "37"  => "\%", "38"  => "&",  "39"  => "'",   "40"  => "(",   "41"  => ")",
	    "42"  => "*",  "43"  => "+",  "44"  => ",",   "45"  => "-",   "46"  => ".",
	    "47"  => "/",  "48"  => "0",  "49"  => "1",   "50"  => "2",   "51"  => "3",
	    "52"  => "4",  "53"  => "5",  "54"  => "6",   "55"  => "7",   "56"  => "8",
	    "57"  => "9",  "58"  => ":",  "59"  => ";",   "60"  => "<",   "61"  => "=",
	    "62"  => ">",  "63"  => "?",  "64"  => "\@",  "65"  => "A",   "66"  => "B",
	    "57"  => "9",  "58"  => ":",  "59"  => ";",   "61"  => "=",
	    "63"  => "?",  "64"  => "\@", "65"  => "A",  "66"  => "B",
	    "67"  => "C",  "68"  => "D",  "69"  => "E",   "70"  => "F",   "71"  => "G",
	    "72"  => "H",  "73"  => "I",  "74"  => "J",   "75"  => "K",   "76"  => "L",
	    "77"  => "M",  "78"  => "N",  "79"  => "O",   "80"  => "P",   "81"  => "Q",
	    "82"  => "R",  "83"  => "S",  "84"  => "T",   "85"  => "U",   "86"  => "V",
	    "87"  => "W",  "88"  => "X",  "89"  => "Y",   "90"  => "Z",   "91"  => "[",
	    "92"  => "\\", "93"  => "]",  "94"  => "^",   "95"  => "_",   "96"  => "`",
	    "97"  => "a",  "98"  => "b",  "99"  => "c",   "100" => "d",   "101" => "e",
	    "102" => "f",  "103" => "g",  "104" => "h",   "105" => "i",   "106" => "j",
	    "107" => "k",  "108" => "l",  "109" => "m",   "110" => "n",   "111" => "o",
	    "112" => "p",  "113" => "q",  "114" => "r",   "115" => "s",   "116" => "t",
	    "117" => "u",  "118" => "v",  "119" => "w",   "120" => "x",   "121" => "y",
	    "122" => "z",  "123" => "{",  "124" => "|",   "125" => "}",   "126" => "~",
	    "130" => ",",  "131" => "f",  "132" => "\"",   "133" => "...", "139" => "<",
	    "140" => "OE", "145" => "'",  "146" => "'",   "147" => "\"",   "148" => "\"",
	    "149" => "o",  "150" => "--", "151" => "-",   "152" => "~",   "153" => "TM",
	    "155" => ">",  "156" => "oe", "159" => "Y",   "160" => " ",   "178" => "2",
	    "179" => "3",  "185" => "1",  "188" => "1/4", "189" => "1/2", "190" => "3/4",
	    "192" => "A",  "193" => "A",  "194" => "A",   "195" => "A",   "196" => "A",
	    "197" => "A",  "198" => "AE", "199" => "C",   "200" => "E",   "201" => "E",
	    "202" => "E",  "203" => "E",  "204" => "I",   "205" => "I",   "206" => "I",
	    "207" => "I",  "208" => "D",  "209" => "N",   "210" => "O",   "211" => "O",
	    "212" => "O",  "213" => "O",  "214" => "O",   "215" => "*",   "216" => "O",
	    "217" => "U",  "218" => "U",  "219" => "U",   "220" => "U",   "221" => "Y",
	    "223" => "ss", "224" => "a",  "225" => "a",   "226" => "a",   "227" => "a",
	    "228" => "a",  "229" => "a",  "230" => "ae",  "231" => "c",   "232" => "e",
	    "233" => "e",  "234" => "e",  "235" => "e",   "236" => "i",   "237" => "i",
	    "238" => "i",  "239" => "i",  "241" => "n",   "242" => "o",   "243" => "o",
	    "244" => "o",  "245" => "o",  "246" => "o",   "247" => "/",   "248" => "o",
	    "249" => "u",  "250" => "u",  "251" => "u",   "252" => "u",   "253" => "y",
	    "255" => "y",  "8218" => ",");


my %mime_type = ("ai"=>"application/postscript", "aif"=>"audio/x-aiff", 
		     "aifc"=>"audio/x-aiff", "aiff"=>"audio/x-aiff", 
		     "au"=>"audio/basic", "avi"=>"video/x-msvideo",
		     "bcpio"=>"application/x-bcpio", "bin"=>"application/octet-stream", 
		     "cdf"=>"application/x-netcdf", "class"=>"application/octet-stream", 
		     "cpio"=>"application/x-cpio", "cpt"=>"application/mac-compactpro",
		     "csh"=>"application/x-csh", "dcr"=>"application/x-director", 
		     "dir"=>"application/x-director", "dms"=>"application/octet-stream", 
		     "doc"=>"application/msword", "dvi"=>"application/x-dvi",
		     "dxr"=>"application/x-director", "eps"=>"application/postscript", 
		     "etx"=>"text/x-setext",
		     "exe"=>"application/octet-stream", "gif"=>"image/gif",
		     "gtar"=>"application/x-gtar", "hdf"=>"application/x-hdf",
		     "hqx"=>"application/mac-binhex40", "htm"=>"text/html",
		     "html"=>"text/html", "ice"=>"x-conference/x-cooltalk",
		     "ief"=>"image/ief", "jpe"=>"image/jpeg",
		     "jpeg"=>"image/jpeg", "jpg"=>"image/jpeg",
		     "kar"=>"audio/midi", "latex"=>"application/x-latex",
		     "lha"=>"application/octet-stream", "lzh"=>"application/octet-stream",
		     "man"=>"application/x-troff-man", "mcf"=>"image/vasa",
		     "me"=>"application/x-troff-me", "mid"=>"audio/midi",
		     "midi"=>"audio/midi", "mif"=>"application/x-mif",
		     "mov"=>"video/quicktime", "movie"=>"video/x-sgi-movie",
		     "mp2"=>"audio/mpeg", "mpe"=>"video/mpeg",
		     "mpeg"=>"video/mpeg", "mpg"=>"video/mpeg",
		     "mpga"=>"audio/mpeg", "ms"=>"application/x-troff-ms",
		     "nc"=>"application/x-netcdf", "oda"=>"application/oda",
		     "pbm"=>"image/x-portable-bitmap", "pdb"=>"chemical/x-pdb",
		     "pdf"=>"application/pdf", "pgm"=>"image/x-portable-graymap",
		     "png"=>"image/png", "pnm"=>"image/x-portable-anymap",
		     "ppm"=>"image/x-portable-pixmap",
		     "ppt"=>"application/vnd.ms-powerpoint",
		     "ps"=>"application/postscript", "qt"=>"video/quicktime",
		     "ra"=>"audio/x-realaudio", "ram"=>"audio/x-pn-realaudio",
		     "ras"=>"image/x-cmu-raster", "rgb"=>"image/x-rgb",
		     "roff"=>"application/x-troff", "rpm"=>"audio/x-pn-realaudio-plugin",
		     "rtf"=>"application/rtf", "rtx"=>"text/richtext",
		     "sgm"=>"text/x-sgml", "sgml"=>"text/x-sgml",
		     "sh"=>"application/x-sh", "shar"=>"application/x-shar",
		     "sit"=>"application/x-stuffit", "skd"=>"application/x-koan",
		     "skm"=>"application/x-koan", "skp"=>"application/x-koan",
		     "skt"=>"application/x-koan", "snd"=>"audio/basic",
		     "src"=>"application/x-wais-source", "sv4cpio"=>"application/x-sv4cpio",
		     "sv4crc"=>"application/x-sv4crc", "t"=>"application/x-troff",
		     "tar"=>"application/x-tar", "tcl"=>"application/x-tcl",
		     "tex"=>"application/x-tex", "texi"=>"application/x-texinfo",
		     "texinfo"=>"application/x-texinfo", "tif"=>"image/tiff",
		     "tiff"=>"image/tiff", "tr"=>"application/x-troff",
		     "tsv"=>"text/tab-separated-values", "txt"=>"text/plain",
		     "ustar"=>"application/x-ustar", "vcd"=>"application/x-cdlink",
		     "vrml"=>"x-world/x-vrml", "wav"=>"audio/x-wav",
		     "wrl"=>"x-world/x-vrml", "xbm"=>"image/x-xbitmap",
		     "xls"=>"application/vnd.ms-excel",
		     "xpm"=>"image/x-xpixmap", "xwd"=>"image/x-xwindowdump",
		     "xyz"=>"chemical/x-pdb", "zip"=>"application/zip");


# returns the character as a raw utf-8 character. It assumes that the
# & and ; have been stripped off the string.
sub getcharequiv {
    my ($entity, $convertsymbols, $and_decode) = @_;

    my $char_equiv = undef;

    # a numeric entity
    my $code = undef;
    if ($entity =~ m/^\#0*(\d+)$/) {
	$code=$1;
    }
    elsif ($entity =~ m/^\#x([0-9A-F]+)$/i) {
	$code=hex($1);
    }


    if (defined $code) {
    
	# malformed UTF-8 character used in UTF-16
	if($code >= 0xD800 && $code <= 0xDFFF) {
	    print STDERR "Warning: encountered the HTML entity \&#$code; which represents part of a UTF-16 surrogate pair, which is not supported in ghtml::getcharequiv(). Replacing with '?'.\n";
	    $code = ord("?");
	}

	# non-standard Microsoft breakage, as usual
	if ($code < 0x9f) { # code page 1252 uses reserved bytes
	    if ($code == 0x91) {$code=0x2018} # 145 = single left quote
	    elsif ($code == 0x92) {$code=0x2019} # 146 = single right quote
	    elsif ($code == 0x93) {$code=0x201c} # 147 = double left quote
	    elsif ($code == 0x94) {$code=0x201d} # 148 = double right quote
	    # ...
	}	
	$char_equiv = &unicode::unicode2utf8([$code]);
    }
    
    # a named character entity
    elsif (defined $charnetosf{$entity}) {
	$char_equiv = &unicode::unicode2utf8([$charnetosf{$entity}]);
    }

    # a named symbol entity
    elsif ($convertsymbols && defined $symnetosf{$entity}) {
	$char_equiv = &unicode::unicode2utf8([$symnetosf{$entity}]);
    }

    if (!defined $char_equiv) {
	return "&$entity;"; # unknown character
    }
    else {
	if ((defined $and_decode) && ($and_decode)) {
	    $char_equiv = Encode::decode("utf8",$char_equiv);
	}
	return $char_equiv;
    }
}

# convert character entities from named equivalents to html font
sub convertcharentities {
    # args: the text that you want to convert

    $_[0] =~ s/&([^;]+);/&getcharequiv($1,0)/gse;
}

# convert any entities from named equivalents to html font
sub convertallentities {
    # args: the text that you want to convert

    $_[0] =~ s/&([^;]+);/&getcharequiv($1,1)/gse;
}

sub html2txt {
    # args: the text that you want converted to ascii, 
    # and whether to strip out sgml tags

    # strip out sgml tags if needed
    $_[0] =~ s/<[^>]*>//g if $_[1];

    # convert the char entities to the standard html font
    &convertcharentities($_[0]); 
    
    # convert the html character set to a plain ascii character set
    my $pos = 0;
    while ($pos < length($_[0])) {
	my $charnum = ord(substr($_[0], $pos, 1));
	if ($charnum >= 32) { # only convert characters above #32
	    my $replacechars = " ";
	    $replacechars = $sftotxt{$charnum} if defined $sftotxt{$charnum};
	    substr($_[0], $pos, 1) = $replacechars;
	    $pos += length ($replacechars);

	} else {
	    $pos ++;
	}
    }
}  


# look for mime.types (eg in /etc, or apache/conf directories), or have a look
# at <ftp://ftp.iana.org/in-notes/iana/assignments/media-types/> for defaults.
sub guess_mime_type {
    my ($filename) = @_;
    # make the filename lowercase, since the mimetypes hashmap looks for lowercase
    $filename = lc($filename);

    my ($fileext) = $filename =~ /\.(\w+)$/;
    return "unknown" unless defined $fileext;

    # else
    my $mimetype =  $mime_type{$fileext};
    return $mimetype if (defined $mimetype);

    return "unknown";
}


1;
