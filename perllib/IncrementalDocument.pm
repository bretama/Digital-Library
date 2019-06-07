###########################################################################
#
# IncrementalDocument.pm -- An object to encapsulate the Greenstone 
#                           document retrieved from the info database.
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the
# University of Waikato, New Zealand.
#
# Copyright (C) 2006 DL Consulting Ltd and New Zealand Digital Library Project
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
package IncrementalDocument;


use strict;
use util;
use dbutil;

# /**
#  */
sub new()
  {
    my ($class, $collection, $infodbtype, $oid) = @_;

    #rint STDERR "IncrementalDocument::new($collection, $infodbtype, $oid)\n";

    # Test the parameters
    die ("Error! Can't create a document that doesn't belong to a collection!") unless $collection;
    die ("Error! Can't create a document that doesn't have a unique id (OID)!") unless $oid;

    # Store the variables
    my $self = {};

    # The collection this document object has been loaded from.
    $self->{'collection'} = $collection;

    # The infodbtype for the collection
    $self->{'infodbtype'} = $infodbtype;

    # An associative array of information retrieved from the info database
    # which maps a key string to a nested associative array listing values.
    $self->{'data'} = {};

    # The unique identifier of the document loaded
    $self->{'oid'} = $oid;

    # Stores the order in which metadata keys where discovered/added.
    $self->{'order'} = {};

    bless $self, $class;
    return $self;
  }
# /** new() **/

# /**
#  */
sub addMetadata()
  {
    my ($self, $key, $value, $internal) = @_;

    # Validate the arguments
    die ("Error! Can't add a metadata value to a document without a valid key!") unless $key =~ /[\w]+/;
    die ("Error! Can't add a metadata key to a document without a valid value!") unless $value =~ /[\w\d]+/;

    # Is this a new key that we haven't encountered before? If so ensure an
    # array exists for its values, and record the order in which we encountered
    # this key.
    if (!defined($self->{'data'}->{$key}))
      {
        # Determine how many data keys we're already storing, so we can add the next
        # one at the appropriate index
        my $index = scalar(keys %{$self->{'order'}});
        $self->{'order'}->{$index} = $key;
        $self->{'data'}->{$key} = {};
      }

    # Set the value of the associative path to 1.
    $self->{'data'}->{$key}->{$value} = 1;
  }
# /** addMetadata() **/

# /** Retrieve all the metadata of this document as an array of pairs.
#  *
#  */
sub getAllMetadata()
{
    my ($self) = @_;
    my @all_metadata;

    print STDERR "IncrementalDocument.getAllMetadata()\n";

    my $key_count = scalar(keys %{$self->{'order'}});
    for (my $i = 0; $i < $key_count; $i++)
      {
        my $key = $self->{'order'}->{$i};
        # Check if this key has been set
        if ($self->{'data'}->{$key})
          {
            # Note: there may be zero values left
            foreach my $value (sort keys %{$self->{'data'}->{$key}})
              {
                if ($self->{'data'}->{$key}->{$value})
                  {
                    print STDERR "* Storing $key => $value\n";
                    push(@all_metadata, [$key, $value]);
                  }
              }
          }
      }
    print STDERR "Complete!\n";
    return \@all_metadata;
  }
# /** getAllMetadata() **/

# /**
#  */
sub getDocNum()
  {
    my ($self) = @_;
    my $docnum = -1;
    # Check the docnum path exists in the associated data
    if(defined($self->{'data'}->{'docnum'}))
      {
        # Get the list of keys from that associative path
        my @values = keys (%{$self->{'data'}->{'docnum'}});
        # And since we know there will only ever be one value for docnum
        $docnum = $values[0];
      }
    return $docnum;
  }
# /** getDocNum() **/

# /**
#  */
sub loadDocument()
  {
    my ($self) = @_;
    #rint STDERR "IncrementalDocument::loadDocument()\n";
    # Load the raw text for the document object from the info database
    my $collection = $self->{'collection'};
    my $index_text_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "index", "text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($self->{'infodbtype'}, $collection, $index_text_directory_path);
    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $infodb_file_path, $self->{'oid'});
    # For each line in the raw text, extract the key (enclosed in angle
    # brackets) and the value
    $text =~ s/<([\w\d\.]+)>(.+?)\r?\n/&addMetadata($self, $1, $2, 1)/egs;
    # Done
  }
# /** loadDocument() **/

# /** Locates and removes the given key/value mappings from this document
#  *  object.
#  *
#  *  @param  $self A reference to this IncrementalDocument object
#  *  @param  $key The metadata key as a string
#  *  @param  $value The obsolete metadata value as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub removeMetadata()
  {
    my ($self, $key, $value) = @_;
    # Ensure the value doesn't exist by simply setting to 0 the correct
    # associative path
    $self->{'data'}->{$key}->{$value} = 0;
  }
# /*** removeMetadat() **/

# /**
#  */
sub saveDocument()
  {
    my ($self) = @_;
    # Get a textual version of this object
    my $text = $self->toString();

    # Now store the object in the info database
    my $collection = $self->{'collection'};

    my $index_text_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "index", "text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($self->{'infodbtype'}, $collection, $index_text_directory_path);
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $infodb_file_path, "append");
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $self->{'oid'}, &dbutil::convert_infodb_string_to_hash($text));
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);

    # There is a little bit of extra complexity when saving an incremental
    # document in that we should ensure that a reverse lookup-from DocNum or
    # nodeID to Greenstone document hash-exists in the database.
    my $doc_num = $self->getDocNum();
    if($doc_num >= 0)
      {
	my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $infodb_file_path, $doc_num);

        # If there is no reverse lookup, then add one now
        if($text !~ /<section>/)
          {
	    $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $infodb_file_path, "append");
	    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $doc_num, &dbutil::convert_infodb_string_to_hash("<section>" . $self->{'oid'}));
	    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);
          }
      }
    # Done
    #rint STDERR "Stored document:\n[" . $self->{'oid'} . "]\n$text\n";
  }
# /** saveDocument() **/

# /** Produces a textual representation of this object.
#  *
#  *  @return A string which describes this incremental document object
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub toString()
  {
    my ($self) = @_;
    my $text = "";

    my $key_count = scalar(keys %{$self->{'order'}});
    for (my $i = 0; $i < $key_count; $i++)
      {
        my $key = $self->{'order'}->{$i};
        # Check if this key has been set
        if ($self->{'data'}->{$key})
          {
            # Note: there may be zero values left
            foreach my $value (sort keys %{$self->{'data'}->{$key}})
              {
                if ($self->{'data'}->{$key}->{$value})
                  {
                    $text .= "<$key>$value\n";
                  }
              }
          }
      }
    return $text;
  }
# /** toString() **/

1;
