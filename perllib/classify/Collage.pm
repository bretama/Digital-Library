##########################################################################
#
# Collage.pm --
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

package Collage;

use BaseClassifier;
use sorttools;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @Collage::ISA = ('BaseClassifier');
}

my $arguments = 
    [ { 'name' => "buttonname",
  	'desc' => "{Collage.buttonname}",
	'type' => "string",
	'deft' => "Collage",
	'reqd' => "no" }, 
      { 'name' => "geometry",
  	'desc' => "{Collage.geometry}",
	'type' => "string",
	'deft' => "600x300",
	'reqd' => "no" },
      { 'name' => "verbosity",
  	'desc' => "{BasClas.verbosity}",
	'type' => "string",
	'deft' => "5",
	'reqd' => "no" },
      { 'name' => "maxDepth",
  	'desc' => "{Collage.maxDepth}",
	'type' => "string",
	'deft' => "500"},
#      { 'name' => "maxDownloads",
#  	'desc' => "{Collage.maxDownloads}",
#	'type' => "string",
#	'deft' => "",
#	'reqd' => "no" },
      { 'name' => "maxDisplay",
  	'desc' => "{Collage.maxDisplay}",
	'type' => "string",
	'deft' => "25",
	'reqd' => "no" },
      { 'name' => "imageType",
  	'desc' => "{Collage.imageType}",
	'type' => "string",
	'deft' => ".jpg%%.png",
	'reqd' => "no" },
      { 'name' => "bgcolor",
  	'desc' => "{Collage.bgcolor}",
	'type' => "string",
	'deft' => "#96c29a",
	'reqd' => "no" },
      { 'name' => "refreshDelay",
  	'desc' => "{Collage.refreshDelay}",
	'type' => "string",
	'deft' => "1500",
	'reqd' => "no" },
      { 'name' => "isJava2",
  	'desc' => "{Collage.isJava2}",
	'type' => "string",
	'deft' => "auto",
	'reqd' => "no" },
      { 'name' => "imageMustNotHave",
  	'desc' => "{Collage.imageMustNotHave}",
	'type' => "string",
	'deft' => "hl=%%x=%%gt=%%gc=%%.pr",
	'reqd' => "no" },
      { 'name' => "caption",
  	'desc' => "{Collage.caption}",
	'type' => "string",
	'deft' => " ",
	'reqd' => "no" }
      ];




my $options = { 'name'     => "Collage",
		'desc'     => "{Collage.desc}",
		'abstract' => "no",
		'inherits' => "Yes",
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

    # Manually set $self parameters.
    $self->{'list'} = {};
    $self->{'buttonname'} = 'Collage' unless ($self->{'buttonname'});

    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    $self->{'list'} = [];
}

sub classify {
   
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $has_image_type = 0;

    my @image_type_split = split(/%/,$self->{'imageType'});
    my @image_type_ext = map { "($_)" } @image_type_split;
    my $image_type_re = join("|",@image_type_ext);
    $image_type_re =~ s/\./\\\./g;

    my $assoc_files = $doc_obj->{'associated_files'};

    foreach my $af ( @$assoc_files ) {
	my ($real_filename, $assoc_filename, $mime_type, $section) = @$af;
	if ($assoc_filename =~ m/$image_type_re/) {
	    $has_image_type = 1;
	    last;
	}
    }

    if ($has_image_type) {

	my $doc_OID = $doc_obj->get_OID();

	push (@{$self->{'list'}}, $doc_OID);
	
    }

}

sub get_classify_info {
    my $self = shift (@_);
    
    my $items_per_page = 2; 
    my $max_items_per_page = 20;

    my @list      = @{$self->{'list'}};

    my $outhandle = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};

    if ($verbosity>1) {
	print $outhandle ("$self->{'buttonname'}\n");
    }

    my $collage_head = $self->get_entry ($self->{'buttonname'}, "Collage", "Invisible");
    my $collage_curr = $self->get_entry("Collage","VList");
    push (@{$collage_head->{'contains'}},$collage_curr);

    my $global_c=1;
    my $within_page_c=1;

    foreach my $oid (@list) {
	if ($within_page_c>$items_per_page) {
	    my $title = "Items $global_c+";
	    my $nested_node = $self->get_entry($title,"VList");
	    push (@{$collage_curr->{'contains'}}, $nested_node);
	    $collage_curr = $nested_node;

	    $within_page_c=1;
	    
	    $items_per_page++ if ($items_per_page < $max_items_per_page);
	}

	push (@{$collage_curr->{'contains'}}, {'OID'=>$oid});
	$global_c++;
	$within_page_c++;
    }
   
    return $collage_head;
}


sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $thistype) = @_;

    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
			'Title'=>$title,
			'contains'=>[]);

    $classifyinfo{'thistype'} = $thistype if (defined $thistype);

    if ($childtype eq "Collage") {
	my $geometry = $self->{'geometry'};
	my ($x_dim,$y_dim) = ($geometry =~ m/^(.*)x(.*)$/);
	my $verbosity = $self->{'verbosity'};
	my $maxDepth = $self->{'maxDepth'};
#	my $maxDownloads = $self->{'maxDownloads'};
	my $maxDisplay = $self->{'maxDisplay'};
	my $imageType = $self->{'imageType'};
	my $bgcolor = $self->{'bgcolor'};
	my $refreshDelay = $self->{'refreshDelay'};
	my $isJava2 = $self->{'isJava2'};
	my $imageMustNotHave = $self->{'imageMustNotHave'};
	my $caption = $self->{'caption'};
	
	#if (!defined($maxDownloads)) {
	#    $maxDownloads="";
	#}

	my $parameters;

	$parameters = "xdim=".$x_dim;
	$parameters .= ";ydim=".$y_dim;
	$parameters .= ";geometry=".$self->{'geometry'};
	$parameters .= ";verbosity=".$self->{'verbosity'};
	$parameters .= ";maxDepth=".$self->{'maxDepth'};
#	$parameters .= ";maxDownloads=".$maxDownloads;
	$parameters .= ";maxDisplay=".$self->{'maxDisplay'};
	$parameters .= ";imageType=".$self->{'imageType'};
	$parameters .= ";bgcolor=".$self->{'bgcolor'};
	$parameters .= ";refreshDelay=".$self->{'refreshDelay'};
	$parameters .= ";isJava2=".$self->{'isJava2'};
	$parameters .= ";caption=".$self->{'caption'};

#	$parameters .= ";imageMustNotHave=".$self->{'imageMustNotHave'};

    
	$classifyinfo{'parameters'} = $parameters;
    }

    return \%classifyinfo;
}

1;
