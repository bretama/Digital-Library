###########################################################################
#
# EmailAddressExtractor - helper plugin that extracts email addresses from text
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

package EmailAddressExtractor;

use PrintInfo;
use strict;

use gsprintf 'gsprintf';

BEGIN {
    @EmailAddressExtractor::ISA = ('PrintInfo');
}

my $arguments = [
      { 'name' => "extract_email",
	'desc' => "{EmailAddressExtractor.extract_email}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "new_extract_email",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" } 
		 ];

my $options = { 'name'     => "EmailAddressExtractor",
		'desc'     => "{EmailAddressExtractor.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new PrintInfo($pluginlist, $inputargs, $hashArgOptLists, 1);

    return bless $self, $class;

}

# extract metadata
sub extract_email_metadata {

    my $self = shift (@_);
    my ($doc_obj) = @_;
    
    if ($self->{'extract_email'}) {
	my $thissection = $doc_obj->get_top_section();
	while (defined $thissection) {
	    my $text = $doc_obj->get_text($thissection);
	    $self->extract_email (\$text, $doc_obj, $thissection) if $text =~ /./;
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    } 

}

sub extract_email {
    my $self = shift (@_);
    my ($textref, $doc_obj, $thissection) = @_;
    my $outhandle = $self->{'outhandle'};

    gsprintf($outhandle, " {EmailAddressExtractor.extracting_emails}...\n")
	if ($self->{'verbosity'} > 2);
    
    my @email = ($$textref =~ m/([-a-z0-9\.@+_=]+@(?:[-a-z0-9]+\.)+(?:com|org|edu|mil|int|net|[a-z][a-z]))/g);
    @email = sort @email;
    
#    if($self->{"new_extract_email"} == 0)
#    {
#    my @email2 = ();
#    foreach my $address (@email) 
#   {
#	if (!(join(" ",@email2) =~ m/(^| )$address( |$)/ )) 
#	    {
#		push @email2, $address;
#		$doc_obj->add_utf8_metadata ($thissection, "EmailAddress", $address);
#		# print $outhandle "  extracting $address\n" 
#		&gsprintf($outhandle, "  {AutoExtractMetadata.extracting} $address\n")
#		    if ($self->{'verbosity'} > 3);
#	    }
#	}
#    }
#    else
#    {
    my $hashExistMail = {};
    foreach my $address (@email) {
	if (!(defined $hashExistMail->{$address}))
	{
	    $hashExistMail->{$address} = 1;
	    $doc_obj->add_utf8_metadata ($thissection, "EmailAddress", $address);
	    gsprintf($outhandle, "  {AutoExtractMetadata.extracting} $address\n")
		if ($self->{'verbosity'} > 3);
	}
    }
    gsprintf($outhandle, " {EmailAddressExtractor.done_email_extract}\n")
	if ($self->{'verbosity'} > 2);
}


1;
