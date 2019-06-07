###########################################################################
#
# PrintInfo - most base plugin
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2008 New Zealand Digital Library Project
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

## Most basic plugin, just handles parsing the arguments and printing out descriptions. Used for plugins and Extractor plugins

package PrintInfo;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
}

eval {require bytes};
eval "require diagnostics"; # some perl distros (eg mac) don't have this

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use strict;
no strict 'subs';

use gsprintf 'gsprintf';
use parse2;
use printusage;

my $arguments = [
    { 'name' => "gs_version",
      'desc' => "{PrintInfo.gs_version}",
      'type' => "string",
      'reqd' => "no",
      'hiddengli' => "yes" }

];

my $options = { 'name'     => "PrintInfo",
		'desc'     => "{PrintInfo.desc}",
		'abstract' => "yes",
		'inherits' => "no",
		'args'     => $arguments };

# $auxiliary_plugin argument passed in by "on-the-side" plugin helpers such as Extractors and ImageConverter. We don't want parsing of args done by them.
sub new 
{
    my $class = shift (@_);
    my ($pluginlist,$args,$hashArgOptLists, $auxiliary) = @_;
    my $plugin_name = (defined $pluginlist->[0]) ? $pluginlist->[0] : $class;

   if ($plugin_name eq $class) {
	push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
	push(@{$hashArgOptLists->{"OptList"}},$options);
   }
    my $self = {};
    $self->{'outhandle'} = STDERR;
    $self->{'option_list'} = $hashArgOptLists->{"OptList"};
    $self->{"info_only"} = 0;
    $self->{'gs_version'} = "2";
    # Check if gsdlinfo is in the argument list or not - if it is, don't parse 
    # the args, just return the object. 
    # gsdlinfo must come before gs_version. both are set by plugin.pm
    my $v=0;
    foreach my $strArg (@{$args})
    {
	if ($v) {
	    $self->{'gs_version'} = $strArg;
	    last;
	}
 	elsif($strArg eq "-gsdlinfo")
	{
	    $self->{"info_only"} = 1;
	    #return bless $self, $class;
	}
	elsif ($strArg eq "-gs_version") {
	    $v = 1;	    
	}
    }

    if ($self->{"info_only"}) {
	return bless $self, $class;
    }
    if (defined $auxiliary) { # don't parse the args here
	return bless $self, $class;
    }

    # now that we are passed printing out info, we do need to add in this class's options so that they are available for parsing. 
    if ($plugin_name ne $class) {
	push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
	push(@{$hashArgOptLists->{"OptList"}},$options);
    }

    if(parse2::parse($args,$hashArgOptLists->{"ArgList"},$self) == -1)
    {
	my $classTempClass = bless $self, $class;
	print STDERR "<BadPlugin p=$plugin_name>\n";
	&gsprintf(STDERR, "\n{PrintInfo.bad_general_option}\n", $plugin_name);
	$classTempClass->print_txt_usage("");  # Use default resource bundle
	die "\n";
    }

    delete $self->{"info_only"};
    # else parsing was successful.

    $self->{'plugin_type'} = $plugin_name;
 
    return bless $self, $class;
    
}   

#sub init {
#}

sub set_incremental {
    my $self = shift(@_);
    my ($incremental_mode) = @_;

    if (!defined $incremental_mode) {
	$self->{'incremental'} = 0;
	$self->{'incremental_mode'} = "none";
    }
    elsif ($incremental_mode eq "all") {
	$self->{'incremental'} = 1;
	$self->{'incremental_mode'} = "all";
    }
    else {
	# none, onlyadd
	$self->{'incremental'} = 0;
	$self->{'incremental_mode'} = $incremental_mode;
    }	
}

sub get_arguments
{
    my $self = shift(@_);
    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $pluginoptions = pop(@$optionlistref);
    my $pluginarguments = $pluginoptions->{'args'};
    return $pluginarguments;
}


sub print_xml_usage
{
    my $self = shift(@_);
    my $header = shift(@_);
    my $high_level_information_only = shift(@_);
    
    # XML output is always in UTF-8
    gsprintf::output_strings_in_UTF8;

    if ($header) {
	&PrintUsage::print_xml_header("plugin");
    }
    $self->print_xml($high_level_information_only);
}


sub print_xml
{
    my $self = shift(@_);
    my $high_level_information_only = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $pluginoptions = shift(@$optionlistref);
    return if (!defined($pluginoptions));

    # Find the process and block default expressions in the plugin arguments
    my $process_exp = "";
    my $block_exp = "";
    if (defined($pluginoptions->{'args'})) {
	foreach my $option (@{$pluginoptions->{'args'}}) {
	    if ($option->{'name'} eq "process_exp") {
		$process_exp = $option->{'deft'};
	    }
	    if ($option->{'name'} eq "block_exp") {
		$block_exp = $option->{'deft'};
	    }
	}
    }

    gsprintf(STDERR, "<PlugInfo>\n");
    gsprintf(STDERR, "  <Name>$pluginoptions->{'name'}</Name>\n");
    my $desc = gsprintf::lookup_string($pluginoptions->{'desc'});
    $desc =~ s/</&amp;lt;/g; # doubly escaped
    $desc =~ s/>/&amp;gt;/g;
    gsprintf(STDERR, "  <Desc>$desc</Desc>\n");
    gsprintf(STDERR, "  <Abstract>$pluginoptions->{'abstract'}</Abstract>\n");
    gsprintf(STDERR, "  <Inherits>$pluginoptions->{'inherits'}</Inherits>\n");
    gsprintf(STDERR, "  <Processes>$process_exp</Processes>\n");
    gsprintf(STDERR, "  <Blocks>$block_exp</Blocks>\n");
    gsprintf(STDERR, "  <Explodes>" . ($pluginoptions->{'explodes'} || "no") . "</Explodes>\n");
    # adding new option that works with replace_srcdoc_with_html.pl
    gsprintf(STDERR, "  <SourceReplaceable>" . ($pluginoptions->{'srcreplaceable'} || "no") . "</SourceReplaceable>\n");
    unless (defined($high_level_information_only)) {
	gsprintf(STDERR, "  <Arguments>\n");
	if (defined($pluginoptions->{'args'})) {
	    &PrintUsage::print_options_xml($pluginoptions->{'args'});
	}
	gsprintf(STDERR, "  </Arguments>\n");

	# Recurse up the plugin hierarchy
	$self->print_xml();
    }
    gsprintf(STDERR, "</PlugInfo>\n");
}


sub print_txt_usage
{
    my $self = shift(@_);
    # Print the usage message for a plugin (recursively)
    my $descoffset = $self->determine_description_offset(0);
    $self->print_plugin_usage($descoffset, 1);
}


sub determine_description_offset
{
    my $self = shift(@_);
    my $maxoffset = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $pluginoptions = shift(@$optionlistref);
    return $maxoffset if (!defined($pluginoptions));

    # Find the length of the longest option string of this plugin
    my $pluginargs = $pluginoptions->{'args'};
    if (defined($pluginargs)) {
	my $longest = &PrintUsage::find_longest_option_string($pluginargs);
	if ($longest > $maxoffset) {
	    $maxoffset = $longest;
	}
    }

    # Recurse up the plugin hierarchy
    $maxoffset = $self->determine_description_offset($maxoffset);
    $self->{'option_list'} = \@optionlist;
    return $maxoffset;
}


sub print_plugin_usage
{
    my $self = shift(@_);
    my $descoffset = shift(@_);
    my $isleafclass = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $pluginoptions = shift(@$optionlistref);
    return if (!defined($pluginoptions));

    my $pluginname = $pluginoptions->{'name'};
    my $pluginargs = $pluginoptions->{'args'};
    my $plugindesc = $pluginoptions->{'desc'};

    # Produce the usage information using the data structure above
    if ($isleafclass) {
	if (defined($plugindesc)) {
	    gsprintf(STDERR, "$plugindesc\n\n");
	}
	gsprintf(STDERR, " {common.usage}: plugin $pluginname [{common.options}]\n\n");
    }

    # Display the plugin options, if there are some
    if (defined($pluginargs)) {
	# Calculate the column offset of the option descriptions
	my $optiondescoffset = $descoffset + 2;  # 2 spaces between options & descriptions

	if ($isleafclass) {
	    gsprintf(STDERR, " {common.specific_options}:\n");
	}
	else {
	    gsprintf(STDERR, " {common.general_options}:\n", $pluginname);
	}

	# Display the plugin options
	&PrintUsage::print_options_txt($pluginargs, $optiondescoffset);
    }

    # Recurse up the plugin hierarchy
    $self->print_plugin_usage($descoffset, 0);
    $self->{'option_list'} = \@optionlist;
}


1;


