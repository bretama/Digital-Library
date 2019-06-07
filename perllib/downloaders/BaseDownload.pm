###########################################################################
#
# BaseDownload.pm -- base class for all the Download modules
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 New Zealand Digital Library Project
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

package BaseDownload;

eval {require bytes};

use strict;
no strict 'subs';

use gsprintf 'gsprintf';
use printusage;
use parse2;

# suppress the annoying "subroutine redefined" warning that various
# gets cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

my $arguments = [];

my $options = { 'name'     => "BaseDownload",
		'desc'     => "{BaseDownload.desc}",
		'abstract' => "yes",
		'inherits' => "no" };

sub new 
{
    my $class = shift (@_);
    my ($downloadlist,$args,$hashArgOptLists) = @_;
    push(@$downloadlist, $class);
    my $strDownloadName = (defined $downloadlist->[0]) ? $downloadlist->[0] : $class;

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = {};
    $self->{'download_type'} = $strDownloadName;
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
    
    delete $self->{"info_only"};
    
    if(parse2::parse($args,$hashArgOptLists->{"ArgList"},$self) == -1)
    {
	my $classTempClass = bless $self, $class;
	print STDERR "<BadDownload d=$self->{'download_name'}>\n";
	&gsprintf(STDERR, "\n{BaseDownload.bad_general_option}\n", $self->{'download_name'});
	$classTempClass->print_txt_usage("");  # Use default resource bundle
	die "\n";
    }

    return bless $self, $class;

}

sub download
{
    my ($self) = shift (@_);
    my ($hashGeneralOptions) = @_;
    &error("download","No download specified for $hashGeneralOptions->{download_mode}.\n");
}


sub print_xml_usage
{
    my $self = shift(@_);
    my $header = shift(@_);
    my $high_level_information_only = shift(@_);
    
    # XML output is always in UTF-8
    gsprintf::output_strings_in_UTF8;

    if ($header) {
	&PrintUsage::print_xml_header("download");
    }
    $self->print_xml($high_level_information_only);
}


sub print_xml
{
    my $self = shift(@_);
    my $high_level_information_only = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $downloadoptions = shift(@$optionlistref);
    return if (!defined($downloadoptions));

    gsprintf(STDERR, "<DownloadInfo>\n");
    gsprintf(STDERR, "  <Name>$downloadoptions->{'name'}</Name>\n");
    my $desc = gsprintf::lookup_string($downloadoptions->{'desc'});
    $desc =~ s/</&amp;lt;/g; # doubly escaped
    $desc =~ s/>/&amp;gt;/g;
    gsprintf(STDERR, "  <Desc>$desc</Desc>\n");
    gsprintf(STDERR, "  <Abstract>$downloadoptions->{'abstract'}</Abstract>\n");
    gsprintf(STDERR, "  <Inherits>$downloadoptions->{'inherits'}</Inherits>\n");
    unless (defined($high_level_information_only)) {
	gsprintf(STDERR, "  <Arguments>\n");
	if (defined($downloadoptions->{'args'})) {
	    &PrintUsage::print_options_xml($downloadoptions->{'args'});
	}
	gsprintf(STDERR, "  </Arguments>\n");

	# Recurse up the download hierarchy
	$self->print_xml();
    }
    gsprintf(STDERR, "</DownloadInfo>\n");
}


sub print_txt_usage
{
    my $self = shift(@_);

    # Print the usage message for a download (recursively)
    my $descoffset = $self->determine_description_offset(0);
    $self->print_download_usage($descoffset, 1);
}

sub determine_description_offset
{
    my $self = shift(@_);
    my $maxoffset = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $downloadoptions = pop(@$optionlistref);
    return $maxoffset if (!defined($downloadoptions));

    # Find the length of the longest option string of this download
    my $downloadargs = $downloadoptions->{'args'};
    if (defined($downloadargs)) {
	my $longest = &PrintUsage::find_longest_option_string($downloadargs);
	if ($longest > $maxoffset) {
	    $maxoffset = $longest;
	}
    }

    # Recurse up the download hierarchy
    $maxoffset = $self->determine_description_offset($maxoffset);
    $self->{'option_list'} = \@optionlist;
    return $maxoffset;
}


sub print_download_usage
{
    my $self = shift(@_);
    my $descoffset = shift(@_);
    my $isleafclass = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $downloadoptions = shift(@$optionlistref);
    return if (!defined($downloadoptions));

    my $downloadname = $downloadoptions->{'name'};
    my $downloadargs = $downloadoptions->{'args'};
    my $downloaddesc = $downloadoptions->{'desc'};

    # Produce the usage information using the data structure above
    if ($isleafclass) {
	if (defined($downloaddesc)) {
	    gsprintf(STDERR, "$downloaddesc\n\n");
	}
	gsprintf(STDERR, " {common.usage}: download $downloadname [{common.options}]\n\n");
    }

    # Display the download options, if there are some
    if (defined($downloadargs)) {
	# Calculate the column offset of the option descriptions
	my $optiondescoffset = $descoffset + 2;  # 2 spaces between options & descriptions

	if ($isleafclass) {
	    gsprintf(STDERR, " {common.specific_options}:\n");
	}
	else {
	    gsprintf(STDERR, " {common.general_options}:\n", $downloadname);
	}

	# Display the download options
	&PrintUsage::print_options_txt($downloadargs, $optiondescoffset);
    }

    # Recurse up the download hierarchy
    $self->print_download_usage($descoffset, 0);
    $self->{'option_list'} = \@optionlist;
}

sub url_information
{
    my ($self) = @_;
    print STDERR "There is no extra information provided for this Download.\n";
    return "";
}

# method to set whether or not we're running the download scripts from GLI
sub setIsGLI()
{
    my ($self, $is_gli) = @_; 

    $self->{'gli'} = $is_gli;
}

sub error
{
      my ($strFunctionName,$strError) = @_;
    {
	print "An error occurred in BaseDownload.pm\n".
	    "In Function: ".$strFunctionName."\n".
	    "Error Message: ".$strError."\n";
	exit(-1);
    }  
}

1;
