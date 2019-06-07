###########################################################################
#
# multiread.pm --
#
# Copyright (C) 1999 DigiLib Systems Limited, NZ
# Copyright (C) 2005 New Zealand Digital Library project
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

# the multiread object will read in a number of encodings,
# the results are always returned in the utf-8 format

# encodings currently supported are
#
# utf8             - either utf8 or unicode (automatically detected)
# unicode          - 2-byte UCS (does endian detection)
#
# plus all encodings in the "encodings" package

package multiread;

eval {require bytes};

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use unicode;

sub new {
    my ($class) = @_;

    my $self = {'handle'    => "",
		'first'     => 1,
		'encoding'  => "utf8",
		'bigendian' => 1};

    return bless $self, $class;
}

# set_handle expects the file to be already open but
# not read yet
sub set_handle {
    my $self = shift;
    $self->{'handle'} = shift;
    binmode( $self->{'handle'} );
    $self->{'first'} = 1;
    $self->{'encoding'} = "utf8";
    $self->{'bigendian'} = 1;
}

# set_encoding should be called after set_handle
sub set_encoding {
    my $self = shift;
    $self->{'encoding'} = shift;
}

sub get_encoding {
    my $self = shift (@_);
    return $self->{'encoding'};
}

# undef will be returned if the eof has been reached
# the result will always be returned in utf-8

sub read_unicode_char {
    my $self = shift (@_);

    # make sure we have a file handle
    return undef if ($self->{'handle'} eq "");
    my $handle = $self->{'handle'};

    if ($self->{'encoding'} eq "utf8") {
	# utf-8 text, how many characters we get depends 
	# on what we find
	my $c1 = "";
	my $c2 = "";
	my $c3 = "";

	while (!eof ($handle)) {
	    $c1 = ord (getc ($handle));

	    if ($c1 <= 0x7f) {
		# one byte character
		return chr ($c1);

	    } elsif ($c1 >= 0xc0 && $c1 <= 0xdf) {
		# two byte character
		$c2 = getc ($handle) if (!eof ($handle));
		return chr ($c1) . $c2;

	    } elsif ($c1 >= 0xe0 && $c1 <= 0xef) {
		# three byte character
		$c2 = getc ($handle) if (!eof ($handle));
		$c3 = getc ($handle) if (!eof ($handle));
		return chr ($c1) . $c2 . $c3;
	    }

	    # if we get here there was an error in the file, we should
	    # be able to recover from it however, maybe the file is in
	    # another encoding
	}

	return undef if (eof ($handle));
    }

    if ($self->{'encoding'} eq "unicode") {
	# unicode text, get the next two characters
	return undef if (eof ($handle));
	my $c1 = ord (getc ($handle));
	return undef if (eof ($handle));
	my $c2 = ord (getc ($handle));

	return &unicode::unicode2utf8 ([(($self->{'bigendian'}) ? ($c1*256+$c2) : ($c2*256+$c1))]);
    }

    return undef;
}


sub unicodechar_to_ord
{
    my $self = shift (@_);
    my ($unicode_text) = @_;

    my $bigendian_ord_array = [];

    my @unicodechar_array = ($unicode_text =~ m/(..)/g);

    foreach my $pair (@unicodechar_array) {
	# for each 2 byte pair       
	my $c1=ord(substr($pair,0,1));
	my $c2=ord(substr($pair,1,1));

	my $be_ord = ($self->{'bigendian'}) ? $c1*256+$c2 : $c2*256+$c1;
	push(@$bigendian_ord_array,$be_ord);
    }

    return $bigendian_ord_array;
}


# undef will be returned if the eof has been reached
# the result will always be returned in utf-8
sub read_line {
    my $self = shift (@_);

    # make sure we have a file handle
    return undef if ($self->{'handle'} eq "");

    my $handle = $self->{'handle'};

    if ($self->{'encoding'} eq "utf8") {
	# utf-8 line
	return <$handle>;
    }

    if ($self->{'encoding'} eq "unicode") {
	# unicode line
	my $c = "";
	my ($c1, $c2) = ("", "");
	my $out = "";
	while (read ($handle, $c, 2) == 2) {
	    $c1 = ord (substr ($c, 0, 1));
	    $c2 = ord (substr ($c, 1, 1));
	    $c = &unicode::unicode2utf8([(($self->{'bigendian'}) ? ($c1*256+$c2) : ($c2*256+$c1))]);
	    $out .= $c;
	    last if ($c eq "\n");
	}

	return $out if (length ($out) > 0);
	return undef;
    }

    if ($self->{'encoding'} eq "iso_8859_1") {
	# we'll use ascii2utf8() for this as it's faster than going
	# through convert2unicode()
	my $line = "";
	if (defined ($line = <$handle>)) {
	    return &unicode::ascii2utf8 (\$line);
	}
    }

    # everything else uses unicode::convert2unicode
    my $line = "";
    if (defined ($line = <$handle>)) {
	return &unicode::unicode2utf8 (&unicode::convert2unicode ($self->{'encoding'}, \$line));
    }

    return undef;
}



# this will look for a Byte Order Marker at the start of the file, and
# set the encoding appropriately if there is one, returning any
# non-marker text on the first line (or returns undef).
sub find_unicode_bom {
    my $self=shift;

    my $non_bom_text=""; # to return if we read in 'real' text

    if ($self->{'first'} == 0) { return }

    # make sure we have a file handle
    return if ($self->{'handle'} eq "");
    my $handle = $self->{'handle'};

    $self->{'first'} = 0;

    my $gc = getc ($handle);
    my $b1 = ord($gc);
    my $b2;
    my $b3;

    if ($b1 == 0xfe || $b1 == 0xff) {
	$b2 = ord (getc ($handle)) if (!eof ($handle));
	if ($b1 == 0xff && $b2 == 0xfe) {
	    $self->{'encoding'} = "unicode";
	    $self->{'bigendian'} = 0;
	    return;
	} elsif ($b1 == 0xfe && $b2 == 0xff) {
	    $self->{'encoding'} = "unicode";
	    $self->{'bigendian'} = 1;
	    return;
	} elsif ($b1 == 0xef && $b2 == 0xbb) {
	    $b3 = ord(getc($handle));
	    if ($b3 == 0xbf) {
		$self->{'encoding'} = "utf8";
		$self->{'bigendian'} = 1;
		return;
	    }
	    else {
		# put back all three bytes
		$handle->ungetc($b3);
		$handle->ungetc($b2);
		$handle->ungetc($b1); return;

	    }
	}
	else {
	    # put back two bytes read
	    $handle->ungetc($b2);
	    $handle->ungetc($b1); return;
	}
    } else { # $b1 != fe or ff
	# put back the one byte read
	$handle->ungetc($b1); return;
    }
}


sub read_file_no_decoding
{
    my $self = shift (@_);
    my ($outputref) = @_;

    # make sure we have a file handle
    return if ($self->{'handle'} eq "");

    my $handle = $self->{'handle'};

    # if encoding is set to utf8 or unicode, sniff to see if there is a 
    # byte order marker
    if ($self->{'first'} &&
	($self->{'encoding'} eq "utf8" || $self->{'encoding'} eq 'unicode')) {

	# this will change $self's encoding if there is a BOM (but won't consume any characters)
	$self->find_unicode_bom(); 
    }

    undef $/;
    $$outputref .=  <$handle>;
    $/ = "\n";

}


# will convert entire contents of file to utf8 and append result to $outputref
# this may be a slightly faster way to get the contents of a file than by 
# recursively calling read_line()
sub decode_text {
    my $self = shift (@_);

    my ($raw_text,$decoded_text_ref) = @_;

    if ($self->{'encoding'} eq "utf8") {
	# Nothing to do, raw text is in utf 8
	$$decoded_text_ref .= $raw_text;
	return;
    }

    if ($self->{'encoding'} eq "unicode") {
	my $unicode_array = $self->unicodechar_to_ord($raw_text);
	$$decoded_text_ref .= &unicode::unicode2utf8($unicode_array);
	return;
    }

    if ($self->{'encoding'} eq "iso_8859_1" || $self->{'encoding'} eq "ascii") {
	# we'll use ascii2utf8() for this as it's faster than going
	# through convert2unicode()
	$$decoded_text_ref .= &unicode::ascii2utf8 (\$raw_text);
	return;
    }

    # everything else uses unicode::convert2unicode
    my $unicode_text = &unicode::convert2unicode ($self->{'encoding'}, \$raw_text);

    $$decoded_text_ref .= &unicode::unicode2utf8 ($unicode_text);

###    print STDERR "!!! decoded ", join(":",map { ord($_) } split(//,$$decoded_text_ref)), "\n";
}



# will convert entire contents of file to utf8 and append result to $outputref
# this may be a slightly faster way to get the contents of a file than by 
# recursively calling read_line()
sub read_file {
    my $self = shift (@_);
    my ($outputref) = @_;

    # While unusual, $raw_text is initialized to $$outputref
    # to be consistent with code before refactoring
    my $raw_text = $$outputref; 

    $self->read_file_no_decoding(\$raw_text);
    $self->decode_text($raw_text,$outputref);
}

1;
