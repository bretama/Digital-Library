###########################################################################
#
# BaseClassifier.pm -- base class for all classifiers
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2000 New Zealand Digital Library Project
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

package BaseClassifier;

# How a classifier works.  
#
# For each classifier requested in the collect.cfg file, buildcol.pl creates
# a new classifier object (a subclass of BaseClassifier).  Later, it passes each 
# document object to each classifier in turn for classification.
#
# Four primary functions are used:
#
# 1. "new" is called before the documents are processed to set up the
#    classifier.
#
# 2. "init" is called after buildcol.pl has created the indexes etc but
#    before the documents are classified in order that the classifier might
#    set any variables it requires, etc.
#
# 3. "classify" is called once for each document object.  The classifier
#    "classifies" each document and updates its local data accordingly.
#
# 4. "get_classify_info" is called after every document has been
#    classified.  It collates the information about the documents and
#    stores a reference to the classifier so that Greenstone can later
#    display it.

# 09/05/02 Added usage datastructure - John Thompson
# 28/11/03 Commented out verbosity argument - John Thompson

use gsprintf;
use printusage;
use parse2;

# suppress the annoying "subroutine redefined" warning that various
# classifiers cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments
no strict 'refs'; # allow filehandles to be variables and viceversa

my $arguments = 
    [ 
      { 'name' => "buttonname",
  	'desc' => "{BasClas.buttonname}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "no_metadata_formatting",
        'desc' => "{BasClas.no_metadata_formatting}",
        'type' => "flag" },
      { 'name' => "builddir",
	'desc' => "{BasClas.builddir}",
	'type' => "string",
	'deft' => "" },
      { 'name' => "outhandle",
	'desc' => "{BasClas.outhandle}",
	'type' => "string",
	'deft' => "STDERR" },
      { 'name' => "verbosity",
	'desc' => "{BasClas.verbosity}",
#	'type' => "enum",
	'type' => "int",
	'deft' => "2",
	'reqd' => "no" }
      
#      { 'name' => "ignore_namespace",
#	'desc' => "{BasClas.ignore_namespace}",
#	'type' => "flag"} 
      ];

my $options = { 'name'     => "BaseClassifier",
		'desc'     => "{BasClas.desc}",
		'abstract' => "yes",
		'inherits' => "no",
		'args'     => $arguments };


sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}


sub print_xml_usage
{
    my $self = shift(@_);
    my $header = shift(@_);
    my $high_level_information_only = shift(@_);
    
    # XML output is always in UTF-8
    &gsprintf::output_strings_in_UTF8;

    if ($header) {
	&PrintUsage::print_xml_header("classify");
    }
    $self->print_xml($high_level_information_only);
}


sub print_xml
{
    my $self = shift(@_);
    my $high_level_information_only = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $classifieroptions = shift(@$optionlistref);
    return if (!defined($classifieroptions));

    &gsprintf(STDERR, "<ClassInfo>\n");
    &gsprintf(STDERR, "  <Name>$classifieroptions->{'name'}</Name>\n");
    my $desc = &gsprintf::lookup_string($classifieroptions->{'desc'});
    $desc =~ s/</&amp;lt;/g; # doubly escaped
    $desc =~ s/>/&amp;gt;/g;
    &gsprintf(STDERR, "  <Desc>$desc</Desc>\n");
    &gsprintf(STDERR, "  <Abstract>$classifieroptions->{'abstract'}</Abstract>\n");
    &gsprintf(STDERR, "  <Inherits>$classifieroptions->{'inherits'}</Inherits>\n");
    unless (defined($high_level_information_only)) {
	&gsprintf(STDERR, "  <Arguments>\n");
	if (defined($classifieroptions->{'args'})) {
	    &PrintUsage::print_options_xml($classifieroptions->{'args'});
	}
	&gsprintf(STDERR, "  </Arguments>\n");

	# Recurse up the classifier hierarchy
	$self->print_xml();
    }
    &gsprintf(STDERR, "</ClassInfo>\n");
}


sub print_txt_usage
{
    my $self = shift(@_);

    # Print the usage message for a classifier (recursively)
    my $descoffset = $self->determine_description_offset(0);
    $self->print_classifier_usage($descoffset, 1);
}


sub determine_description_offset
{
    my $self = shift(@_);
    my $maxoffset = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $classifieroptions = pop(@$optionlistref);
    return $maxoffset if (!defined($classifieroptions));

    # Find the length of the longest option string of this classifier
    my $classifierargs = $classifieroptions->{'args'};
    if (defined($classifierargs)) {
	my $longest = &PrintUsage::find_longest_option_string($classifierargs);
	if ($longest > $maxoffset) {
	    $maxoffset = $longest;
	}
    }

    # Recurse up the classifier hierarchy
    $maxoffset = $self->determine_description_offset($maxoffset);
    $self->{'option_list'} = \@optionlist;
    return $maxoffset;
}


sub print_classifier_usage
{
    my $self = shift(@_);
    my $descoffset = shift(@_);
    my $isleafclass = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $classifieroptions = shift(@$optionlistref);
    return if (!defined($classifieroptions));

    my $classifiername = $classifieroptions->{'name'};
    my $classifierargs = $classifieroptions->{'args'};
    my $classifierdesc = $classifieroptions->{'desc'};
    # Produce the usage information using the data structure above
    if ($isleafclass) {
	if (defined($classifierdesc)) {
	    &gsprintf(STDERR, "$classifierdesc\n\n");
	}
	&gsprintf(STDERR, " {common.usage}: classify $classifiername [{common.options}]\n\n");
	
    }

    # Display the classifier options, if there are some
    if (defined($classifierargs)) {
	# Calculate the column offset of the option descriptions
	my $optiondescoffset = $descoffset + 2;  # 2 spaces between options & descriptions

	if ($isleafclass) {
	    &gsprintf(STDERR, " {common.specific_options}:\n");
	}
	else {
	    &gsprintf(STDERR, " {common.general_options}:\n", $classifiername);
	}

	# Display the classifier options
	&PrintUsage::print_options_txt($classifierargs, $optiondescoffset);
    }

    # Recurse up the classifier hierarchy
    $self->print_classifier_usage($descoffset, 0);
    $self->{'option_list'} = \@optionlist;
}


sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$args,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);
    my $classifier_name = (defined $classifierslist->[0]) ? $classifierslist->[0] : $class;

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);


    # Manually set $self parameters.
    my $self = {};
    $self->{'outhandle'} = STDERR;
    $self->{'idnum'} = -1;
    $self->{'option_list'} = $hashArgOptLists->{"OptList"};
    $self->{"info_only"} = 0;

    # Check if gsdlinfo is in the argument list or not - if it is, don't parse 
    # the args, just return the object.  
    foreach my $strArg (@{$args})
    {
	if($strArg eq "-gsdlinfo")
	{
	    $self->{"info_only"} = 1;
	    return bless $self, $class;
	}
    }

    # general options available to all classifiers
    if(parse2::parse($args,$hashArgOptLists->{"ArgList"},$self) == -1)
    {
	#print out the text usage of this classifier. 
	my $classTempClass = bless $self, $class;
	print STDERR "<BadClassifier c=$classifier_name>\n";

	&gsprintf(STDERR, "\n{BasClas.bad_general_option}\n", $classifier_name);
	$classTempClass->print_txt_usage("");  # Use default resource bundle
	die "\n";
    }
    
    delete $self->{"info_only"};

# We now ensure that when text files (and even colcfg) are read in, 
# they are straightaway made to be Unicode aware strings in Perl
    
    return bless $self, $class;
}

sub init {
    my $self = shift (@_);

    $self->{'supportsmemberof'} = &supports_memberof();
}

sub set_number {
    my $self = shift (@_);
    my ($id)   = @_;
    $self->{'idnum'} = $id;
}

sub get_number {
    my $self = shift (@_);
    return $self->{'idnum'};
}

sub oid_array_delete
{
    my $self = shift (@_);
    my ($delete_oid,$field) = @_;

    my $outhandle = $self->{'outhandle'};

    my @filtered_list = ();
    foreach my $existing_oid (@{$self->{$field}}) {
	if ($existing_oid eq $delete_oid) {
	    print $outhandle "  Deleting old $delete_oid for ", ref $self, "\n";
	}
	else {
	    push(@filtered_list,$existing_oid);
	}
    }
    $self->{$field} = \@filtered_list;
}

sub oid_hash_delete
{
    my $self = shift (@_);
    my ($delete_oid,$field) = @_;

    my $outhandle = $self->{'outhandle'};

    print $outhandle "  Deleting old $delete_oid for ", ref $self, "\n";
    delete $self->{$field}->{$delete_oid};
}

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $outhandle = $self->{'outhandle'};
    &gsprintf($outhandle, "BaseClassifier::classify {common.must_be_implemented}\n");
}

sub get_classify_info {
    my $self = shift (@_);

    my $outhandle = $self->{'outhandle'};
    &gsprintf($outhandle, "BaseClassifier::get_classify_info {common.must_be_implemented}\n");
}

sub supports_memberof {
    my $self = shift(@_);

    return "false";
}

# previously, if a buttonname wasn't specified, we just use the metadata value,
# but with a list of metadata, we want to do something a bit nicer so that
# eg -metadata dc.Title,Title will end up with Title as the buttonname

# current algorithm - use the first element, but strip its namespace
sub generate_title_from_metadata {
    
    my $self = shift (@_);
    my $metadata = shift (@_);

    return "" unless defined $metadata && $metadata =~ /\S/;
    
    my @metalist = split(/,|;/, $metadata);
    my $firstmeta = $metalist[0];
    if ($firstmeta =~ /\./) {
	$firstmeta =~ s/^\w+\.//;
    }
    return $firstmeta; 
}


# ex. can be at front, or it may be a list of metadata, separated by ,/; 
sub strip_ex_from_metadata {
    my $self = shift (@_);
    my $metadata = shift (@_);

    return $metadata unless defined $metadata && $metadata =~ /\S/;

    # only remove ex. metadata prefix if there are no other prefixes after it
    $metadata =~ s/(,|;|:|\/)/$1 /g; # insert a space separator so meta names like flex.Image don't become fl.Image
    $metadata =~ s/(^| )ex\.([^.,;:\/]+)(,|;|:|\/|$)/$1$2$3/g; 
					 $metadata =~ s/(,|;|:|\/) /$1/g;

    return $metadata;
}
   

1; 
