###########################################################################
#
# ClassifyTreeModel.pm --
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006-2010  DL Consulting Ltd
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


package ClassifyTreeModel;

use ClassifyTreeNode;
use strict;


# /** Constructor
#  *
#  *  @param  $class       The name of the class to bless as a string
#  *  @param  $collection  The name of the collection whose info database we
#  *                       will be accessing as a string
#  *  @param  $root        The oid of the root node of the classifier as a
#  *                       string
#  *  @return A reference to the ClassifyTreeModel object
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub new()
  {
    my ($class, $collection, $infodbtype, $root) = @_;
    my $debug = 0;
    print STDERR "ClassifyTreeModel.new(\"$collection\", $infodbtype, \"$root\")\n" unless !$debug;
    # Store the variables
    my $self = {};
    $self->{'collection'} = $collection;
    $self->{'infodbtype'} = $infodbtype;
    $self->{'debug'} = $debug;
    $self->{'root'} = $root;
    # Bless me father for I have sinned
    bless $self, $class;
    return $self;
  }
# /** new() **/

# /** Given a path and a document id, add this document to the classifier tree
#  *  creating any necessary tree nodes first.
#  *
#  *  @param  $value The path to store this document in
#  *  @param  $oid Unique identifier of a document
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub addDocument()
  {
    my ($self, $value, $oid) = @_;
    print STDERR "ClassifyTreeModel.addDocument(\"$value\", \"$oid\")\n" unless !$self->{'debug'};
    # Generate a treepath object from the metadata value, remembering to prefix
    # with the root nodes path
    my $root_node_obj = $self->getRootNode();
    my $path_obj = $root_node_obj->getPath();
    $path_obj->addPathComponent($value);
    # Ensure that this classifier node, and if necessary its ancestor nodes,
    # exist in our tree.
    my $node_obj = $self->getNodeByPath($path_obj);
    if (!$node_obj)
      {
        # The node doesn't exist, so we need to add it
        $node_obj = $self->addNode($path_obj);
      }
    # Add the document to the node.
    $node_obj->addDocument($oid);
    # Done.
  }
# /** addDocument() **/

# /** Add a node into the tree first ensuring all its parent nodes are inserted
#  *  to.
#  *
#  *  @param  $path_obj The path to insert the new node at
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub addNode()
  {
    my ($self, $path_obj) = @_;
    print STDERR "ClassifyTreeModel.addNode(\"" . $path_obj->toString() . "\")\n" unless !$self->{'debug'};
    # Ensure the parent exists, assuming we aren't at the root
    my $parent_path_obj = $path_obj->getParentPath();
    #rint STDERR "* parent path: " . $parent_path_obj->toString() . "\n";
    my $parent_node_obj = $self->getNodeByPath($parent_path_obj);
    #rint STDERR "* does parent node already exist? " . $parent_node_obj . "\n";
    #rint STDERR "* are we at the root node yet? " . $parent_path_obj->isRootPath() . "\n";
    if (!$parent_node_obj && !$parent_path_obj->isRootPath())
      {
        #rint STDERR "* recursive call!\n";
        $parent_node_obj = $self->addNode($parent_path_obj);
      }
    # Insert this node into it's parent.
    return $parent_node_obj->insertNode($path_obj);
  }
# /** addNode() **/

# /** Retrieve the name of the collection this model is drawing from.
#  *
#  *  @return The collection name as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getCollection()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeModel.getCollection()\n" unless !$self->{'debug'};
    return $self->{'collection'};
  }
# /** getCollection() **/

sub getInfoDBType()
{
  my $self = shift(@_);
  return $self->{'infodbtype'};
}

# /** Retrieve a node from this tree based upon its CLID (OID).
#  *  @param  $clid  The CLID as a string
#  *  @return The indicated ClassifyTreeNode or null
sub getNodeByCLID()
  {
    my ($self, $clid) = @_;
    print STDERR "ClassifyTreeModel.getNodeByCLID(\"$clid\")\n" unless !$self->{'debug'};
    my $result = 0;
    # Test if this clid is even in our tree
    if($clid !~ /^$self->{'root'}/)
      {
        print STDERR "Requested node $clid, which isn't part of " . $self->{'root'} . "\n";
        return 0;
      }
    # Unfortunately I have to check that there is text to retrieve before I
    # create a new node.

    my $index_text_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $self->getCollection(), "index", "text");
    my $infodb_file_path = &dbutil::get_infodb_file_path($self->{'infodbtype'}, $self->getCollection(), $index_text_directory_path);
    if (&dbutil::read_infodb_rawentry($self->{'infodbtype'}, $infodb_file_path, $clid) =~ /\w+/)
      {
        # Since the CLID can directly reference the correct entry in the info database we
        # just create the node and return it
        $result = new ClassifyTreeNode($self, $clid);
      }
    return $result;
  }

# /** Retrieve a node from this tree based upon a path
#  *
#  *  @param  $path  The path to the node as a ClassifyTreePath
#  *  @return The indicated ClassifyTreeNode or null
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getNodeByPath()
  {
    my ($self, $path_obj) = @_;
    print STDERR "ClassifyTreeModel.getNodeByPath(\"" . $path_obj->toString() . "\")\n" unless !$self->{'debug'};
    # Starting at the ROOT of the tree, and with the first path component,
    # recursively descend through the tree looking for the node - we can assume
    # that we've found the root node (otherwise we won't be in a tree)
    my $cur_node_obj = $self->getRootNode();
    my $cur_path_obj = $cur_node_obj->getPath();
    my $depth = 1;
    # Continue till we either find the node we want, or run out a nodes
    while(!$cur_node_obj->getPath()->equals($path_obj))
      {
        # Append the path component at this depth to the current path we
        # are searching for
        $cur_path_obj->addPathComponent($path_obj->getPathComponent($depth));
        $depth++;
        #rint STDERR "Searching " . $cur_node_obj->getPath()->toString() . "'s children for: " . $cur_path_obj->toString() . "\n";
        # Search through the current nodes children, looking for one that
        # matches the current path
        my $found = 0;
        foreach my $child_node_obj ($cur_node_obj->getChildren())
          {
            #rint STDERR "* testing " . $child_node_obj->getPath()->toString() . "\n";
            if($child_node_obj->getPath()->equals($cur_path_obj))
              {
                $cur_node_obj = $child_node_obj;
                $found = 1;
                last;
              }
          }
        # Couldn't find any node with this path
        if(!$found)
          {
            #rint STDERR "* no such node exists!\n";
            return 0;
          }
      }
    return $cur_node_obj;
  }
# /** getChild() **/

# /** Retrieve the parent node of the given node.
#  *
#  *  @param  $child_node The node whose parent we want to retrieve
#  *  @return The parent node, or 0 if this is the root
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getParentNode()
  {
    my ($self, $child_node) = @_;
    print STDERR "ClassifyTreeModel.getParentNode()\n" unless !$self->{'debug'};
    return $child_node->getParentNode();
  }
# /** getParentNode() **/

sub getRootNode()
{
  my ($self) = @_;
  print STDERR "ClassifyTreeModel.getRootNode()\n" unless !$self->{'debug'};
  return new ClassifyTreeNode($self, $self->{'root'});
}

# /** Remove the given document from the classifier tree, and then remove any
#  *  empty nodes if required.
#  *
#  *  @param  $value The value which contains the path of the node to remove
#  *                 the document from
#  *  @param  $oid The unique identifier of the document to remove
#  *  @param  $remove_empty Sets whether empty nodes are removed
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub removeDocument()
  {
    my ($self, $path, $oid, $remove_empty) = @_;
    print STDERR "ClassifyTreeModel.removeDocument(\"$path\",\"$oid\",$remove_empty)\n" unless !$self->{'debug'};
    # Append to root path
    my $root_node_obj = $self->getRootNode();
    my $path_obj = $root_node_obj->getPath();
    $path_obj->addPathComponent($path);
    # Retrieve the node in question
    my $node_obj = $self->getNodeByPath($path_obj);
    # Check we retrieved a node
    if ($node_obj)
      {
        # Remove the document
        $node_obj->removeDocument($oid);
        # If we have been asked to remove empty nodes, do so now.
        if ($remove_empty)
          {
            my $cur_node_obj = $node_obj;
            my $empty_node_obj = 0;
            while ($cur_node_obj->getNumLeafDocs() == 0)
              {
                $empty_node_obj = $cur_node_obj;
                $cur_node_obj = $cur_node_obj->getParentNode();
              }
            if ($empty_node_obj)
              {
                # Try to retrieve the parent of this node
                my $parent_node_obj = $empty_node_obj->getParentNode();
                # As long as we have a parent (i.e. we aren't the root node) go
                # ahead and delete this subtree starting at empty node
                if ($parent_node_obj)
                  {
                    $parent_node_obj->removeNode($empty_node_obj);
                  }
              }
          }
      }
    # If the node doesn't exist in this tree, then we can't very well remove
    # anything from it!
  }
# /** removeDocument() **/

1;
