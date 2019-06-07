###########################################################################
#
# muread.pm -- read a marked-up file
#
# Copyright (C) 1999 DigiLib Systems Limited, NZ
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


package muread;

use strict;
use unicode;
use multiread;

sub new {
    my ($class) = @_;

    my $self = {'filename'=>"",
		'encoding'=>"",
		'handle'=>"",
		'reader'=>"",
		'buffer'=>""};

    return bless $self, $class;
}

# returns a new tag with a tag name and any options
sub parse_tag {
    my $self = shift (@_);
    my ($orgtagtext) = @_;
    my $tagtext = $orgtagtext;
    my $newtag = {};
    my $misformed = 0;

#    print STDERR "parsing \"$tagtext\"\n";

    # get tag name (if there is one)
    if ($tagtext =~ /^(\w+)/) {
	$newtag->{'_tagname'} = $1;
	$tagtext =~ s/^(\w+)//;
    } else {
	print STDERR "muread::parse_tag error - no tag name found\n";
    }

    # get the tag arguments
    while ($tagtext =~ /\S/) {
	$tagtext =~ s/^\s+//s;
	if ($tagtext =~ /^(\w+)\s*=\s*\"([^\"]*)\"/s) {
	    $newtag->{$1} = (defined $2) ? $2 : "";
	    $tagtext =~ s/^\w+\s*=\s*\"[^\"]*\"//s;

	} else {
	    if (!$misformed) {
		print STDERR "muread::parse_tag error - miss-formed tag <$orgtagtext>\n";
		$misformed = 1;
	    }
	    $tagtext =~ s/^\S+//s;
	}
    }

    return $newtag;
}

sub read_tag_content {
    my $self = shift (@_);
    my ($tag) = @_;

    # all tags contain a _tagname except the tag for the document

    my $line = "";
    while (1) {
	# deal with preceeding text
	if ($self->{'buffer'} =~ /^([^<]+)</s) {
	    # add preceeding text
	    $tag->{'_contains'} = [] unless defined $tag->{'_contains'};
	    push (@{$tag->{'_contains'}}, {'_text'=>$1});

	    $self->{'buffer'} =~ s/^[^<]+</</s;
	}

	if ($self->{'buffer'} =~ /^<([^>\/]+)>/s) {
	    # add info from this tag
	    my $tagtext = $1;
	    my $newtag = $self->parse_tag ($tagtext);
	    push (@{$tag->{'_contains'}}, $newtag);
	    $self->{'buffer'} =~ s/^<[^>\/]+>//s;
	    
	    # deal with the contents of this tag
	    $self->read_tag_content ($newtag);

	} elsif ($self->{'buffer'} =~ /^<\/([^>\/]+)>/s) {
	    my $tagname = $1;
	    $self->{'buffer'} =~ s/^<\/[^>\/]+>//s;

	    # check that this tag is the right tag
	    if (!defined $tag->{'_tagname'} || $tag->{'_tagname'} ne $tagname) {
		print STDERR "muread::read_tag_content error - mismatched tag </$tagname>, " .
		    "expected </$tag->{'_tagname'}>\n";
	    } else {
		return;
	    }
	} elsif (defined ($line = $self->{'reader'}->read_line())) {
	    $self->{'buffer'} .= $line;
	} else {
	    if ($self->{'buffer'} =~ /\S/) {
		print STDERR "muread::read_tag_content error - can't parse text \"$self->{'buffer'}\"\n";
	    }
	    last;
	}
    }
    
    if (defined $tag->{'_tagname'}) {
	print STDERR "muread::read_tag_content error - eof reached before closing " .
	    "tag \"$tag->{'_tagname'}\" found\n";
    }
}

sub read_file {
    my $self = shift (@_);
    ($self->{'handle'}, $self->{'filename'}, $self->{'encoding'}) = @_;
    $self->{'encoding'} = "utf8" unless defined $self->{'encoding'};

    my $doc = {};

    # get reader set up
    $self->{'reader'} = new multiread ();
    $self->{'reader'}->set_handle ($self->{'handle'});
    $self->{'reader'}->set_encoding ($self->{'encoding'});

    # read in the file
    $self->read_tag_content ($doc);

    $self->{'handle'} = "";
    return $doc;
}

1;
