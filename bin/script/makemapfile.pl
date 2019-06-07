#!/usr/bin/perl -w

###########################################################################
#
# makemapfile.pl --
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

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use parsargv;
use util;

# %translations is of the form:
#
# encodings{encodingname-encodingname}->blocktranslation
# blocktranslation->[[0-255],[256-511], ..., [65280-65535]]
#
# Any of the top translation blocks can point to an undefined
# value. This data structure aims to allow fast translation and 
# efficient storage.
%translations = ();

# @array256 is used for initialisation, there must be
# a better way...
@array256 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
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

&main();

sub print_usage {
    print STDERR "\n";
    print STDERR "makemapfile.pl: Creates unicode map (.ump) files from plain\n";
    print STDERR "                text code pages.\n\n";
    print STDERR "  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -encoding name\n";
    print STDERR "   -mapfile  text file from which to create binary ump file\n\n";
}

sub main {
    if (!parsargv::parse(\@ARGV, 
			 'encoding/.+', \$encoding,
			 'mapfile/.+', \$mapfile)) {
	&print_usage();
	die "\n";
    }

    if (!&loadencoding ($encoding, $mapfile)) {
	die "couldn't load encoding $encoding";
    }

    # write out map files
    &writemapfile ("$encoding-unicode", $encoding, 1);
    &writemapfile ("unicode-$encoding", $encoding, 0);
}

sub writemapfile {
    my ($encoding, $filename, $tounicode) = @_;

    $filename .= ".ump"; # unicode map file
    if ($tounicode) {
	$filename = &util::filename_cat ($ENV{'GSDLHOME'}, "mappings", "to_uc", $filename);
    } else {
	$filename = &util::filename_cat ($ENV{'GSDLHOME'}, "mappings", "from_uc", $filename);
    }

    die "translation not defined" if (!defined $translations{$encoding});
    my $block = $translations{$encoding};

    print "writing $filename\n";
    open (MAPFILE, ">" . $filename) || die;
    binmode (MAPFILE);

    my ($i, $j);
    for ($i=0; $i<256; $i++) {
	if (ref ($block->[$i]) eq "ARRAY") {
	    print MAPFILE pack ("C", $i);
	    for ($j=0; $j<256; $j++) {
		# unsigned short in network order
		print MAPFILE pack ("CC", int($block->[$i]->[$j] / 256), 
				    $block->[$i]->[$j] % 256);
	    }
	}
    }
    close (MAPFILE);
}

# loadencoding expects the mapfile to contain (at least) two
# tab-separated fields. The first field is the mapped value
# and the second field is the unicode value.
#
# It returns 1 if successful, 0 if unsuccessful
sub loadencoding {
    my ($encoding, $mapfile) = @_;
    
    my $to = "$encoding-unicode";
    my $from = "unicode-$encoding";

    # check to see if the encoding has already been loaded
    if (defined $translations{$to} && defined $translations{$from}) {
	return 1;
    }

    return 0 unless open (MAPFILE, $mapfile);

    my ($line, @line);
    $translations{$to} = [@array256];
    $translations{$from} = [@array256];
    while (defined ($line = <MAPFILE>)) {
	chomp $line;
	# remove comments
	$line =~ s/\#.*$//;
	next unless $line =~ /\S/;

	# split the line into fields and do a few
	# simple sanity checks
	@line = split (/\t/, $line);
	next unless (scalar(@line) >= 2 &&
		     $line[0] =~ /^0x/ &&
		     $line[1] =~ /^0x/);

	my $char = hex($line[0]);
	my $unic = hex($line[1]);

	# might need this for some versions of gb but not gbk
#	$char = $char | 0x8080 unless ($encoding =~ /gbk/i);

	&addchartrans ($translations{$to}, $char, $unic);
	&addchartrans ($translations{$from}, $unic, $char);
    }

    close (MAPFILE);

    return 1;
}

# addchartrans adds one character translation to a translation block.
# It also simplifies the translation block if possible.
sub addchartrans {
    my ($block, $from, $to) = @_;
    my $i = 0;

    my $high = ($from / 256) % 256;
    my $low = $from % 256;

    if (ref ($block->[$high]) ne "ARRAY") {
	$block->[$high] = [@array256];
    }
    $block->[$high]->[$low] = $to;
}
