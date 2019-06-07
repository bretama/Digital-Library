###########################################################################
#
# HTML.pm --
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

# html classifier plugin - creates an empty classification
# that's simply a link to a web page

package HTML;

use BaseClassifier;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @HTML::ISA = ('BaseClassifier');
}

my $arguments = 
    [ { 'name' => "url",
	'desc' => "{HTML.url}",
	'type' => "string",
	'reqd' => "yes" } ,
      { 'name' => "buttonname",
	'desc' => "{BasClas.buttonname}",
	'type' => "string",
	'deft' => "Browse",
	'reqd' => "no" } ];

my $options = { 'name'     => "HTML",
		'desc'     => "{HTML.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseClassifier($classifierslist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    if (!$self->{'url'}) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "HTML Error: required option -url not supplied\n";
	$self->print_txt_usage("");
	die "HTML Error: required option -url not supplied\n";
    }
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    # we don't do anything for individual documents
}

sub get_classify_info {
    my $self = shift (@_);

    my %classifyinfo = ('thistype'=>'Invisible',
			'childtype'=>'HTML',
			'Title'=>$self->{'buttonname'},
			'contains'=>[]);

    push (@{$classifyinfo{'contains'}}, {'OID'=>$self->{'url'}});

    return \%classifyinfo;
}


1;
