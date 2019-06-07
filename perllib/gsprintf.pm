###########################################################################
#
# gsprintf.pm --
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
use strict;
no strict 'refs';

package gsprintf;
require Exporter;
@gsprintf::ISA=qw(Exporter);

use Encode;

use unicode;
use util;
use FileUtils;

@gsprintf::EXPORT_OK = qw(gsprintf); # functions we can export into namespace


# Language-specific resource bundle
my %specialresourcebundle = ();
our $specialoutputencoding; # our, so that it can be changed outside.

# Default resource bundle
my %defaultresourcebundle;
my $defaultoutputencoding;

# English resource bundle
my %englishresourcebundle;
my $englishoutputencoding;

# Ignore the OutputEncoding strings in the resource bundles and output all text in UTF-8
my $outputstringsinUTF8 = 0;
my $freetext_xml_mode = 0;


sub make_freetext_xml_safe
{
    my ($text) = @_;

    $text =~ s/\&/&amp;/g;
    $text =~ s/\"/&quot;/g;
    $text =~ s/\</&lt;/g;
    $text =~ s/\>/&gt;/g;

    return $text;
}


sub gsprintf
{
    my ($handle, $text_string, @text_arguments) = @_;

    # Return unless the required arguments were supplied
    return unless (defined($handle) && defined($text_string));
    
    # Look up all the strings in the dictionary
    $text_string =~ s/(\{[^\}]+\})/&lookup_string($1)/eg;

    # Resolve the string arguments using sprintf, then write out to the handle
    my $text_string_resolved = sprintf($text_string, @text_arguments);
    
    if ($freetext_xml_mode) {
	$text_string_resolved = make_freetext_xml_safe($text_string_resolved);
    }
    
    print $handle $text_string_resolved;
}



sub lookup_string
{
    my ($stringkey, $native_perl) = @_;
    
    if (!defined $native_perl || $native_perl != 1) {
	$native_perl = 0;
    }
    return "" unless defined $stringkey;
    # Try the language-specific resource bundle first
    my $utf8string = $specialresourcebundle{$stringkey};
    my $outputencoding = $specialoutputencoding;

    # Try the default resource bundle next
    if (!defined($utf8string)) {
	# Load the default resource bundle if it is not already loaded
	&load_default_resource_bundle() if (!%defaultresourcebundle);
	
	$utf8string = $defaultresourcebundle{$stringkey};
	$outputencoding = $defaultoutputencoding;
    }
    
    # Try the English resource bundle last
    if (!defined($utf8string)) {
	# Load the English resource bundle if it is not already loaded
	&load_english_resource_bundle() if (!%englishresourcebundle);
	
	$utf8string = $englishresourcebundle{$stringkey};
	$outputencoding = $englishoutputencoding;
    }
    
    # No matching string was found, so just return the key
    if (!defined($utf8string)) {
	return $stringkey;
    }
    # we allow \n and \t as newlines and tabs.
    $utf8string =~ s@([^\\])\\n@$1\n@g;
    $utf8string =~ s@([^\\])\\t@$1\t@g;
    $utf8string =~ s@\\\\@\\@g;
    
    if ($native_perl ==1) {
	# decode the utf8 string to perl internal format
	return decode("utf8", $utf8string);
    }
    
    # Return the utf8 string if our output encoding is utf8
    if (!defined($outputencoding) || $outputstringsinUTF8
	|| $outputencoding eq "utf8") {
	return $utf8string;
    }

    # If an 8-bit output encoding has been defined, encode the string appropriately
    my $encoded=unicode::unicode2singlebyte(&unicode::utf82unicode($utf8string), $outputencoding);
    
    # If we successfully encoded it, return it
    if ($encoded) { return $encoded }
    
    # Otherwise, we can't convert to the requested encoding. return the utf8?
    $specialoutputencoding='utf8';
    return $utf8string;
}


sub load_language_specific_resource_bundle
{
    my $language = shift(@_);
    
    # Read the specified resource bundle
    my $resourcebundlename = "strings_" . $language . ".properties";
    
    %specialresourcebundle 
	= &read_resource_bundle_and_extensions($ENV{'GSDLHOME'},"perllib",$resourcebundlename);
    return if (!%specialresourcebundle);
    
    # Read the output encoding to use from the resource bundle
    if ($ENV{'GSDLOS'} =~ /windows/) {
	$specialoutputencoding = $specialresourcebundle{"{OutputEncoding.windows}"};
    }
    else {
	# see if there is an encoding set in the appropriate locale env var
	
	foreach my $envvar ('LC_ALL', 'LANG') {
	    if (!exists $ENV{$envvar}) { next }
	    my $locale=$ENV{$envvar};
	    if ($locale !~ /^\w+\.(.+)$/) { next }
	    my $enc=lc($1);
	    $enc =~ s/-/_/g;
	    if ($enc eq 'utf_8') { $enc='utf8' } # normalise to this name
	    $specialoutputencoding = $enc;
	    return;
	}
	$specialoutputencoding = $specialresourcebundle{"{OutputEncoding.unix}"};
    }
}


sub load_default_resource_bundle
{
    # Read the default resource bundle
    my $resourcebundlename = "strings.properties";

    %defaultresourcebundle 
	= &read_resource_bundle_and_extensions($ENV{'GSDLHOME'},"perllib",$resourcebundlename);
    if (!%defaultresourcebundle) {
        # $! will still have the error value for the last failed syscall

        my $error_message = "$! $resourcebundlename\n";

	if ($freetext_xml_mode) {
	    $error_message = make_freetext_xml_safe($error_message);
	}

        print STDERR $error_message;

	# set something so we don't bother trying to load it again
	$defaultresourcebundle{0}=undef; 
        return;
    }
    
    # Read the output encoding to use from the resource bundle
    if ($ENV{'GSDLOS'} =~ /windows/) {
	$defaultoutputencoding = $defaultresourcebundle{"{OutputEncoding.windows}"};
    }
    else {
	$defaultoutputencoding = $defaultresourcebundle{"{OutputEncoding.unix}"};
    }
}


sub load_english_resource_bundle
{
    # Ensure the English resource bundle hasn't already been loaded
    if (%specialresourcebundle && $specialresourcebundle{"{Language.code}"} eq "en") {
	%englishresourcebundle = %specialresourcebundle;
	$englishoutputencoding = $specialoutputencoding;
    }
    
    if ($defaultresourcebundle{"{Language.code}"} &&
        $defaultresourcebundle{"{Language.code}"} eq "en") {
	%englishresourcebundle = %defaultresourcebundle;
	$englishoutputencoding = $defaultoutputencoding;
    }
    
    # Read the English resource bundle
    my $resourcebundlename = "strings_en.properties";

    %englishresourcebundle 
	= &read_resource_bundle_and_extensions($ENV{'GSDLHOME'},"perllib",$resourcebundlename);
    return if (!%englishresourcebundle);
    
    # Read the output encoding to use from the resource bundle
    if ($ENV{'GSDLOS'} =~ /windows/) {
	$englishoutputencoding = $englishresourcebundle{"{OutputEncoding.windows}"};
    }
    else {
	$englishoutputencoding = $englishresourcebundle{"{OutputEncoding.unix}"};
    }
}


sub read_resource_bundle_and_extensions
{
    my ($bundle_base,$primary_dir,$resourcename) = @_;

    my $primary_resourcebundlefile 
	= &FileUtils::filenameConcatenate($bundle_base,$primary_dir,$resourcename);

    my $resourcebundle = read_resource_bundle($primary_resourcebundlefile);
    return if (!defined $resourcebundle);

    if (defined $ENV{'GSDLEXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {	
	    my $ext_base
		= &FileUtils::filenameConcatenate($bundle_base,"ext",$e);
	    
	    my $ext_resourcebundlefile 
		= &FileUtils::filenameConcatenate($ext_base,$primary_dir,$resourcename);
	    
	    # can ignore return value (will be same reference to $resourcebundle)
	    read_resource_bundle($ext_resourcebundlefile,$resourcebundle);
	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {	
	    my $ext_base
		= &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'},"ext",$e);
	    
	    my $ext_resourcebundlefile 
		= &FileUtils::filenameConcatenate($ext_base,$primary_dir,$resourcename);
	    
	    # can ignore return value (will be same reference to $resourcebundle)
	    read_resource_bundle($ext_resourcebundlefile,$resourcebundle);
	}
    }
    
    return %$resourcebundle;
}


sub read_resource_bundle
{
    my ($resourcebundlefilepath,$resourcebundle) = @_;

    if (!open(RESOURCE_BUNDLE, "<$resourcebundlefilepath")) {
	# When called for the first time (primary resource), $resourcebundle
	# is not defined (=undef). If the file does not exist, then we return
	# this 'undef' to signal it was not found
	# For an extension resource bundle, if it does not exist this
	# is not so serious (in fact quite likely) => return what we 
	# have built up so far
	
	return $resourcebundle;
    }

    if (!defined $resourcebundle) {	
	# resource files exists, so exect some content to be stored
	$resourcebundle = {};
    }
    
    # Load this resource bundle
    my @resourcebundlelines = <RESOURCE_BUNDLE>;
    close(RESOURCE_BUNDLE);

    # Parse the resource bundle

    foreach my $line (@resourcebundlelines) {
        # Remove any trailing whitespace
        $line =~ s/(\s*)$//;

        # Ignore comments and empty lines
        if ($line !~ /^\#/ && $line ne "") {
            # Parse key (everything up to the first colon)
            if ($line =~ m/^([^:]+):(.+)$/) {
                my $linekey = "{" . $1 . "}";
                my $linetext = $2;
                $linetext =~ s/(\s*)\#\s+Updated\s+(\d?\d-\D\D\D-\d\d\d\d).*$//i;

                # Map key to text
                $resourcebundle->{$linekey} = $linetext;
            }
        }
    }

    return $resourcebundle;
}


sub set_print_freetext_for_xml
{
    $freetext_xml_mode = 1;
}

sub set_print_xml_tags
{
    $freetext_xml_mode = 0;
}

sub output_strings_in_UTF8
{
    $outputstringsinUTF8 = 1;
}


sub debug_unicode_string
{
    join("",
     map { $_ > 255 ?                      # if wide character...
           sprintf("\\x{%04X}", $_) :  # \x{...}
           chr($_)          
           } unpack("U*", $_[0]));         # unpack Unicode characters
}


1;
