###########################################################################
#
# OAIMetadataXMLPlugin.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2010 DL Consulting Ltd
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

# OAIMetadataXMLPlugin is a child of MetadataXMLPlugin
# It processes the metadata.xml file just like MetadataXMLPlugin.
# Additionally, it uses the "dc.Identifier" field and extracts OAI metadata from the specified OAI server (-oai_server_http_path)

package OAIMetadataXMLPlugin;

use strict;
no strict 'refs';

use extrametautil;
use MetadataXMLPlugin;

sub BEGIN {
  @OAIMetadataXMLPlugin::ISA = ('MetadataXMLPlugin');
  unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
}

my $arguments = [
                 { 'name' => "oai_server_http_path",
                   'desc' => "{OAIMetadataXMLPlugin.oai_server_http_path}",
                   'type' => "string",
                   'deft' => "" },
                 
                 { 'name' => "metadata_prefix",
                   'desc' => "{OAIMetadataXMLPlugin.metadata_prefix}",
                   'type' => "string",
                   'deft' => "oai_dc" },
                 
                 # If koha_mode flag is specified, the plugin will try to generate the oaiextracted.koharecordlink metadata
                 # This metadata contains the link back to Koha document
                 { 'name' => "koha_mode",
                   'desc' => "{OAIMetadataXMLPlugin.koha_mode}",
                   'type' => "flag",
                   'reqd' => "no" },
                ];

my $options = { 'name'     => "OAIMetadataXMLPlugin",
		'desc'     => "{OAIMetadataXMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


sub new 
{
  my ($class) = shift (@_);
  my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
  push(@$pluginlist, $class);
  
  push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
  push(@{$hashArgOptLists->{"OptList"}},$options);
  
  my $self = new MetadataXMLPlugin($pluginlist, $inputargs, $hashArgOptLists);
  
  return bless $self, $class;
}


sub metadata_read
{
  my $self = shift (@_);
  my ($pluginfo, $base_dir, $file, $block_hash, $extrametakeys, $extrametadata,$extrametafile, $processor, $gli, $aux) = @_;
  
  # Read in the normal metadata.xml file
  $self->SUPER::metadata_read(@_); 
  
  my $outhandle = $self->{'outhandle'};

  #======================================================================#
  # Checks to make sure the OAI-PMH server is connectable [START]
  #======================================================================#
  print $outhandle "OAIMetadataXMLPlugin: Checking OAI server (" . $self->{"oai_server_http_path"} . ") connection\n" if ($self->{'verbosity'})> 1;
  
  # Checks to make sure LWP (5.64) is available, it should always be available if you have Perl installed
  # However if you are using the Greenstone's cut-down version of Perl, this LWP module will not be included
  eval { require LWP };
  if ($@)
  { 
    print STDERR "Error: Failed to load Perl module LWP: $@\n"; 
    return;
  }
  
  # Create the LWP module
  my $browser = LWP::UserAgent->new;
  my $response = $browser->get($self->{"oai_server_http_path"});
  
  # Do not go further if the OAI server is not accessible
  if (!$response->is_success)
  {
    print $outhandle "OAIMetadataXMLPlugin: Error! OAI server (" . $self->{"oai_server_http_path"} . ") unavailable\n";
    return;
  }
  #======================================================================#
  # Checks to make sure the OAI-PMH server is connectable [END]
  #======================================================================#

  #======================================================================#
  # Process each fileset [START]
  #======================================================================#
  foreach my $one_file (@{$extrametakeys})
  {
    # Don't harvest file sets that don't have dc.Identifier set, "dc.Identifier" is usde as the key between Greenstone and OAI Server!
	my $dc_identifier = &extrametautil::getmetadata_for_named_pos($extrametadata, $one_file, "dc.Identifier", 0);
	next if (!defined($dc_identifier) || $dc_identifier eq "");

    #======================================================================#
    # Only try to harvest file set with dc.Identifier specified. [START]
    #======================================================================#
    # The dc.Identifier has to be the same as the OAI record identifier 
    my $oai_identifier = $dc_identifier;
    
    # Now, let's get the OAI metadata
    my $request = $self->{"oai_server_http_path"} . "?verb=GetRecord&identifier=" . $oai_identifier. "&metadataPrefix=" . $self->{"metadata_prefix"};
    print $outhandle "OAIMetadataXMLPlugin: OAI Harvesting Request (" . $request . ")\n";
    $response = undef;
    $response = $browser->get($request);
    die "OAIMetadataXMLPlugin: This should never be happening - \"get\" should always be successful unless the OAI server was temporary down (some kind of race condition)\n" unless ($response->is_success);
    my $reponse_content = $response->content();
    
    # Check to make sure there is no error in the OAI response
    if ($reponse_content =~ /\<error\scode\=[\"\']([^\"\']+)[\"\']>([^\<]*)\<\/error\>/)     
    {
      print $outhandle "OAIMetadataXMLPlugin: Failed to retrive OAI record (" . $oai_identifier . "). ErrorCode: [$1] ErrorMessage: [$2], skip.\n";
      next;
    }
    print $outhandle "OAIMetadataXMLPlugin: OAI record (" . $oai_identifier . ") found.\n";
    
    # Get the oai metadata (We will need to extend this code to support future metadataPrefix)
    my $oai_content = undef;

    # Special Note for KOHA OAI Server: there is an error in the KOHA's OAI-PMH server (it is still under development at the time when I am writting this)
    # The metadata set should be oai_dc:dc tag, but they incorrectly output the tag as oaidc:dc (which doesn't match with the metadataPrefix)
    if ($self->{"metadata_prefix"} eq "oai_dc" && $reponse_content =~ /\<oai\_?dc:dc[^\>]+\>(.*?)\<\/oai\_?dc\:dc\>/s)
    {
      $oai_content = $1;
    }
    else
    {
      my $reg_match = "\<" . $self->{"metadata_prefix"} . "\:" . $self->{"metadata_prefix"} . "[^\>]+\>(.*?)\<\/" . $self->{"metadata_prefix"} . "\:" . $self->{"metadata_prefix"} . "\>";
      if ($reponse_content =~ /$reg_match/s)
      {
        $oai_content = $1;
      }
      else
      {
        print $outhandle "OAIMetadataXMLPlugin: Failed to match " . $self->{"metadata_prefix"} . ":" . $self->{"metadata_prefix"} . " metadata set, skip\n " . $reponse_content . "\n";
        next;
      }
    }
    
    # Get each metadata field and value
    while ($oai_content =~ /\<([^\>]+)\>([^\<]+)\<\/[^\>]+\>/g)
    {
      my $field_name = "oaiextracted." . lc($1);
      my $value = $2;
      
      # Special hack for Koha data from Nitesh
      # Some of their data contain "  \" as the value... that is pretty wrong.
      # If the value is empty, ignore it.
      if ($value =~ /^[^\w]*$/)
      {
        print STDERR "Ignore value:[" . $value . "]\n";
        next;
      }
      
      # Special case for identifier
      if ($self->{"koha_mode"} == 1 && $1 eq "identifier" && $2 =~ /https?\:\/\//)
      {
        $field_name = "oaiextracted.koharecordlink";
        
        # Koha OAI server is not up-to-date... so it was still pointing to the old interface
        # This might need change over once they update the Koha OAI server
        $value =~ s/\/opac\/opac\-detail\.pl\?bib\=/\/catalogue\/detail\.pl\?biblionumber\=/;
      }	  
	  
      &extrametautil::setmetadata_for_named_metaname($extrametadata, $one_file, $field_name, []) if (!defined (&extrametautil::getmetadata_for_named_metaname($extrametadata, $one_file, $field_name)));
	  &extrametautil::addmetadata_for_named_metaname($extrametadata, $one_file, $field_name, $value);
    }
    #======================================================================#
    # Only try to harvest file set with dc.Identifier specified. [END]
    #======================================================================#
  }
  #======================================================================#
  # Process each fileset [END]
  #======================================================================#
}
  
1;
