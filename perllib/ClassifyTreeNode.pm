###########################################################################
#
# ClassifyTreeNode.pm --
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


package ClassifyTreeNode;

use ClassifyTreeNode;
use ClassifyTreePath;
use strict;


# /** Constructor
#  *
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub new()
  {
    my ($class, $model, $clid, $force_new) = @_;
    my $debug = 0;
    $force_new = 0 unless defined($force_new);
    print STDERR "ClassifyTreeNode.new(model, \"$clid\", $force_new)\n" unless !$debug;
    $force_new = 0 unless defined($force_new);
    # Test the parameters
    die("Can't create a tree node that doesn't belong to a tree model!") unless $model;
    die("Can't create a tree node that doesn't have a unique id (OID)!") unless $clid;
    # Store the variables
    my $self = {};
    $self->{'debug'} = $debug;
    $self->{'model'} = $model;
    $self->{'clid'} = $clid;

    my $collection = $model->getCollection();
    $self->{'infodbtype'} = $model->getInfoDBType();

    my $index_text_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "index", "text");
    $self->{'infodb_file_path'} = &dbutil::get_infodb_file_path($self->{'infodbtype'}, $collection, $index_text_directory_path);

    # Check if this node already exists in the database, and if not insert it
    # now
    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $clid);
    if($text !~ /\w+/ && $force_new)
      {
	my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
	&dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $clid, &dbutil::convert_infodb_string_to_hash("<doctype>classify\n<hastxt>0\n<childtype>VList\n<Title>\n<numleafdocs>0\n<contains>\n"));
	&dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);
      }
    # Bless me father for I have sinned
    bless $self, $class;
    return $self;
  }
# /** new() **/

# /** Add a document to this tree node.
#  *
#  *  @param  $oid The unique identifier of the document to add
#  *
#  *  @author John Thompson, DL Consulting Ltd
#  */
sub addDocument()
  {
    my ($self, $oid) = @_;
    print STDERR "ClassifyTreeNode.addDocument(\"$oid\")\n" unless !$self->{'debug'};
    # Get the current contains list
    my $contains = $self->getContains();
    # See whether this document already exists in the contains
    if ($contains !~ /(^$oid$|^$oid;$|;$oid;|;$oid$)/)
      {
        # If not, append to the contains list
        if ($contains ne "")
          {
            $contains .= ";$oid";
          }
        else
          {
            $contains = $oid;
          }
        # Store the changed contains
        $self->setContains($contains);
        # We now have to update the numleafdocs count for this node and its
        # ancestor nodes
        my $cur_node_obj = $self;
        while ($cur_node_obj)
          {
            my $numleafdocs = $cur_node_obj->getNumLeafDocs();
            if ($numleafdocs =~ /^\d+$/)
              {
                $numleafdocs ++;
              }
            else
              {
                $numleafdocs = 1;
              }
            $cur_node_obj->setNumLeafDocs($numleafdocs);
            $cur_node_obj = $cur_node_obj->getParentNode();
          }
      }
    else
      {
        print STDERR "Document already exists!\n" unless !$self->{'debug'};
      }
  }
# /** addDocument() **/

# /** Changes the CLID of a particular node. Note that this is significantly
#  *  tricky step, as we have to remove the old node from the database, and
#  *  then readd with the corrected CLID.
#  *
#  *  @param  $clid The new CLID as an integer
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub changeCLID()
  {
    my($self, $new_clid) = @_;
    print STDERR "ClassifyTreeNode.changeCLID(\"$new_clid\")\n" unless !$self->{'debug'};
    # Store the current clid for later use
    my $old_clid = $self->{'clid'};
    # And record the children now, as they'll change after we shift the parent
    # CLID
    my @child_nodes = $self->getChildren();

    # Retrieve the current document
    my $text = $self->toString();

    my $collection = $self->{'model'}->getCollection();

    # Create a new document with the correct CLID
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $new_clid, &dbutil::convert_infodb_string_to_hash($text));
    # Remove the old document
    &dbutil::delete_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $self->{'clid'});
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);

    # Finally, change the clid stored in this document
    $self->{'clid'} = $new_clid;

    # Now go through this nodes children, and shift them too
    foreach my $child_node (@child_nodes)
      {
        # We determine the new clid by retrieving the childs current clid,
        # and then replacing any occurance to the parents old clid with the
        # parents new clid
        my $old_child_clid = $child_node->getCLID();
        #rint STDERR "* considering: " . $old_child_clid . "\n";
        if($old_child_clid =~ /^CL/)
          {
            my $new_child_clid = $new_clid . substr($old_child_clid, length($old_clid));
            #rint STDERR "* shifting child $old_child_clid to $new_child_clid\n";
            $child_node->changeCLID($new_child_clid);
          }
      }
  }
# /** changeCLID() **/


# /** Retrieve the unique id for this classifier.
#  *
#  *  @return The CLID as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getCLID()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getCLID()\n" unless !$self->{'debug'};
    return $self->{'clid'};
  }

# /** Return the child objects of this node an as array.
#  *
#  *  @return An array of node objects
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getChildren()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getChildren()\n" unless !$self->{'debug'};
    my $text = $self->toString();
    my @children = ();
    # Retrieve the contains metadata item
    if($text =~ /<contains>(.*?)\r?\n/)
      {
        #rint STDERR "* children formed from contains: $1\n";
        my $contains_raw = $1;
        my @contains = split(/;/, $contains_raw);
        foreach my $child_clid (@contains)
          {
            # Replace the " with the parent clid
            $child_clid =~ s/\"/$self->{'clid'}/;
            # Create the node obj
            my $child_node_obj = new ClassifyTreeNode($self->{'model'}, $child_clid);
            # And insert into ever growing array of child nodes
            push(@children, $child_node_obj);
          }
      }
    return @children;
  }
# /** getChildren() **/

# /** Retrieve the contains metadata which is used to determine this nodes
#  *  children.
#  *
#  *  @return The contains metadata as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getContains()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getContains()\n" unless !$self->{'debug'};
    my $result = 0;
    my $text = $self->toString();
    if($text =~ /<contains>(.*?)\r?\n/)
      {
        $result = $1;
        # Replace " with this nodes CLID
        $result =~ s/\"/$self->{'clid'}/g;
      }
    return $result;
  }
# /** getContains() **/

# /** Retrieve this nodes next sibling.
#  *
#  *  @return The next sibling node object or 0 if no such node
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getNextSibling()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getNextSibling()\n" unless !$self->{'debug'};
    my $sibling_node = 0;
    # The next sibling would be the node identified by the CLID with its
    # suffix number one greater than this nodes CLID.
    my @clid_parts = split(/\./, $self->{'clid'});
    my $suffix = pop(@clid_parts);
    $suffix++;
    push(@clid_parts, $suffix);
    my $next_clid = join(".", @clid_parts);

    my $collection = $self->{'model'}->getCollection();

    # Now determine if this node exists.
    if (&dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $next_clid) =~ /\w+/)
      {
        # And if so, create it.
        $sibling_node = new ClassifyTreeNode($self->{'model'}, $next_clid);
      }
    # Done
    return $sibling_node;
  }
# /** getNextSibling() **/

# /** Retrieve the numleafdocs metadata which if affected by any changes to
#  *  child nodes.
#  *
#  *  @return The numleafdocs as an integer
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getNumLeafDocs()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getNumLeafDocs()\n" unless !$self->{'debug'};
    my $result = 0;
    my $text = $self->toString();
    if($text =~ /<numleafdocs>(\d*?)\r?\n/)
      {
        $result = $1;
      }
    return $result;
  }
# /** getNumLeafDocs() **/

# /** Retrieve the parent node of the given node.
#  *
#  *  @param  $child_node The node whose parent we want to retrieve
#  *  @return The parent node, or 0 if this is the root
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getParentNode()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getParentNode()\n" unless !$self->{'debug'};
    my $parent_node = 0;
    my $child_clid = $self->getCLID();
    my @clid_parts = split(/\./, $child_clid);
    if(scalar(@clid_parts) > 1)
      {
        pop(@clid_parts);
        my $parent_clid = join(".", @clid_parts);
        $parent_node = $self->{'model'}->getNodeByCLID($parent_clid);
      }
    # Otherwise we are already at the root node
    return $parent_node;
  }
# /** getParentNode() **/

# /** Retrieve the path to this node.
#  *
#  *  @return The path obj which represents the path to this node or 0 if no
#  *          path information exists
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getPath()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getPath()\n" unless !$self->{'debug'};
    my $result = 0;
    my $text = $self->toString();
    if($text =~ /<Title>(.*?)\r?\n/ )
      {
        my $this_component = $1;
        # If this node has a parent, then retrieve its path
        my $parent_node = $self->getParentNode();
        if ($parent_node)
          {
            # Get the path...
            $result = $parent_node->getPath();
            # ... and add our component
            $result->addPathComponent($this_component);
          }
        else
          {
            $result = new ClassifyTreePath($this_component);
          }
      }
    return $result;
  }
# /** getPath() **/

# /** Retrieve the title of this node. This returns essentially the same
#  *  information as getPath, but without the encapsulating object.
#  *
#  *  @return The title as a string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getTitle()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.getTitle()\n" unless !$self->{'debug'};
    my $result = 0;
    my $text = $self->toString();
    if($text =~ /<Title>(.*?)\r?\n/)
      {
        $result = $1;
      }
    return $result;
  }
# /** getTitle() **/

# /** Using the given value locate the correct position to insert a new node,
#  *  create it, and then establish it in the database.
#  *
#  *  @param  $path The path used to determine where to insert node as a string
#  *  @return The newly inserted node object
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub insertNode()
  {
    my ($self, $path) = @_;
    print STDERR "ClassifyTreeNode.insertNode(\"$path\")\n" unless !$self->{'debug'};
    my $child_clid = "";
    my $child_node = 0;
    my $new_contains = "";
    # Get the children of this node
    my @children = $self->getChildren();
    # If there are no current children, then this will be the first
    if (scalar(@children) == 0)
      {
        #rint STDERR "ClassifyTreeNode.insertNode: first child!\n";
        $child_clid = $self->{'clid'} . ".1"; # First child
        # Contains needs to have this new clid added
        $new_contains = $child_clid;
      }
    # Otherwise search through the current children, looking at their values
    # to locate where to insert this node.
    else
      {
        #rint STDERR "ClassifyTreeNode.insertNode: searching for position...\n";
        my $found = 0;
        my $offset = 1;
        foreach my $sibling_node (@children)
          {
            my $sibling_path = $sibling_node->getPath();
            # If we are still searching for the insertion point
            if(!$found)
              {
                if($sibling_path->toString() eq $path->toString())
                  {
                    # What?!? This node already exists! why are we adding it again!
                    print STDERR "ClassifyTreeNode.insertNode: what?!? node already exists... how did we get here?\n";
                    return $sibling_node;
                  }
                elsif($sibling_path->toString() gt $path->toString())
                  {
                    # Found our location!
                    $found = 1;
                    $child_clid = $self->{'clid'} . "." . $offset;
                    # You may notice we haven't added this node to contains.
                    # This is because the parent node already contains this
                    # clid - instead we need to record the new highest clid
                    # created when we move the sibling nodes for here onwards
                    # up one space.
                    #rint STDERR "ClassifyTreeNode.insertNode: found our location: $child_clid \n";
                    last;
                  }
              }
            $offset++;
          }
        # If we haven't found the node, we insert at the end.
        if(!$found)
          {
            #rint STDERR "ClassifyTreeNode.insertNode not found... insert at end \n";
            $child_clid = $self->{'clid'} . "." . $offset;
            # Contains needs to have this new clid added
            $new_contains = $child_clid;
          }
        # If we did find the node, we now have to go through the sibling nodes
        # shifting them up one CLID to ensure there's space.
        else
          {
            # We need another copy of children, but this time with the last 
            # children first!
            @children = reverse $self->getChildren();
            my $offset2 = scalar(@children) + 1;
            foreach my $sibling_node (@children)
              {
                $sibling_node->changeCLID($self->{'clid'} . "." . $offset2);
                # If this if the highest sibling node we are going to rename,
                # then use it to set the contains metadata.
                if($new_contains !~ /\w+/)
                  {
                    $new_contains = $self->{'clid'} . "." . $offset2;
                  }
                # Once we've processed the node exactly in the space the new
                # node will occupy, we're done.
                $offset2--;
                if($offset2 == $offset)
                  {
                    last;
                  }
              }
          }
      }
    $child_node = new ClassifyTreeNode($self->{'model'}, $child_clid, 1);
    # Set the value, as this is the only piece of metadata we know and care
    # about at this stage
    $child_node->setTitle($path->getLastPathComponent());
    # Update the contains metadata for this node
    my $contains = $self->getContains();
    if($contains =~ /\w/)
      {
        $contains .= ";" . $new_contains;
      }
    else
      {
        $contains = $new_contains;
      }
    $self->setContains($contains);
    # And return the node
    return $child_node;
  }
# /** insertNode() **/

# /** Remove all the children of this node and return the number of document
#  *  references (leaf nodes) removed by this process.
#  *
#  *  @return The count of document references removed as an integer
#  *
#  *  @author John Thompson, DL Consulting Ltd
#  */
sub removeAllNodes()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode.removeAllNodes()\n" unless !$self->{'debug'};
    my $num_leaf_docs = 0;
    # Recursively remove this nodes children
    my @children = $self->getChildren();
    foreach my $child_node (@children)
      {
        $child_node->removeAllNodes();
      }
    # Retrieve the document count (leaf docs)
    my $text = $self->toString();
    if ($text =~ /<numleafdocs>(\d+)/)
      {
        $num_leaf_docs += $1;
      }
    # Now remove the node from the database
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
    &dbutil::delete_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $self->{'clid'});
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);

    # Return the leaf count (so we can adjust the numleafdocs at the root node
    # of this deletion.
    return $num_leaf_docs;
  }
# /** removeAllNodes() **/

# /** Remove the given document this node, and then update the numleafdocs
#  *  metadata for all the ancestor nodes.
#  *
#  *  @param  $oid The unique identifier of a greenstone document
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub removeDocument()
  {
    my ($self, $oid) = @_;
    print STDERR "ClassifyTreeNode::removeDocument(\"$oid\")\n" unless !$self->{'debug'};
    # Retrieve the contains metadata
    my $contains = $self->getContains();
    # Remove this oid
    my @contains_parts = split(/;/, $contains);
    my @new_contains_parts = ();
    foreach my $oid_or_clid (@contains_parts)
      {
        if ($oid ne $oid_or_clid && $oid_or_clid =~ /[\w\d]+/)
          {
            push(@new_contains_parts, $oid_or_clid);
          }
      }
    $contains = join(";", @new_contains_parts);
    $self->setContains($contains);
    # We now have to update the numleafdocs count for this node and its
    # ancestor nodes
    my $cur_node_obj = $self;
    while ($cur_node_obj)
      {
        my $numleafdocs = $cur_node_obj->getNumLeafDocs();
        if ($numleafdocs =~ /^\d+$/)
          {
            $numleafdocs--;
          }
        else
          {
            $numleafdocs = 0;
          }
        $cur_node_obj->setNumLeafDocs($numleafdocs);
        $cur_node_obj = $cur_node_obj->getParentNode();
      }
    # Done
  }
# /** removeDocument() **/

# /** Remove the node denoted by the path.
#  *
#  *  @param  $child_node The node to be removed
#  *
#  *  @author John Thompson, DL Consulting Ltd
#  */
sub removeNode()
  {
    my ($self, $child_node) = @_;
    # Not as easy as it first sounds as we have to do a recursive remove,
    # keeping track of any documents removed so we can update document count.
    # We then remove this node, adjusting the sibling's clid's as necessary
    # before altering the contains.
    print STDERR "ClassifyTreeNode::removeNode(child_node)\n" unless !$self->{'debug'};
    my $remove_clid = $child_node->getCLID();
    my $sibling_node = $child_node->getNextSibling();
    # Recursively remove this nodes and its children, taking note of decrease
    # in document count.
    my $removed_numleafdocs = $child_node->removeAllNodes();
    # Determine if removing this node requires other nodes to be moved, and if
    # so, do so. We do this in a repeating loop until there are no further
    # siblings, overwriting the $remove_clid variable with the clid of the node
    # just changed (you'll see why in a moment).
    while ($sibling_node != 0)
      {
        my $current_node = $sibling_node;
        # Get this nodes sibling
        $sibling_node = $current_node->getNextSibling();
        # Record the CLID to change to
        my $new_clid = $remove_clid;
        # Record the old clid
        $remove_clid = $current_node->getCLID();
        # Modify the clid of the current node
        $current_node->changeCLID($new_clid);
        # Continue until there are no further sibling nodes
      }
    # By now the $remove_clid will contain the CLID that has to be removed from
    # the contains metadata for this node
    my $contains = $self->getContains();
    my @contains_parts = split(/;/, $contains);
    my @new_contains_parts = ();
    foreach my $oid_or_clid (@contains_parts)
      {
        if ($remove_clid ne $oid_or_clid && $oid_or_clid =~ /[\w\d]+/)
          {
            push(@new_contains_parts, $oid_or_clid);
          }
      }
    $contains = join(";", @new_contains_parts);
    $self->setContains($contains);
    # We also alter the numleafdocs metadata to reflect the removal of these
    # nodes.
    my $numleafdocs = $self->getNumLeafDocs();
    if ($numleafdocs =~ /^\d+$/)
      {
        $numleafdocs -= $removed_numleafdocs;
      }
    else
      {
        $numleafdocs = 0;
      }
    $self->setNumLeafDocs($numleafdocs);
    # Done
  }
# /** removeNode() **/

# /** Set the contains metadata in the database.
#  *
#  *  @param  $contains The new contains string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub setContains()
  {
    my ($self, $contains) = @_;
    print STDERR "ClassifyTreeNode::setContains(\"$contains\")\n" unless !$self->{'debug'};
    # Replace any occurance of this nodes CLID with "
    $contains =~ s/$self->{'clid'}/\"/g;

    my $collection = $self->{'model'}->getCollection();
    my $clid = $self->{'clid'};

    # Load the text of this node
    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $clid);

    # Replace the contains
    #rint STDERR "Before: $text\n";
    $text =~ s/<contains>.*?\n+/<contains>$contains\n/;
    #rint STDERR "After:  $text\n";
    # Store the changed text
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $clid, &dbutil::convert_infodb_string_to_hash($text));
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);
  }
# /** setContains() **/

# /** Set the numleafdocs metadata in the database.
#  *
#  *  @param  $numleafdocs The new count of leaf documents
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub setNumLeafDocs()
  {
    my ($self, $numleafdocs) = @_;
    print STDERR "ClassifyTreeNode::setNumLeafDocs(numleafdocs)\n" unless !$self->{'debug'};

    my $collection = $self->{'model'}->getCollection();
    my $clid = $self->{'clid'};

    # Load the text of this node
    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $clid);
    # Replace the numleafdocs
    $text =~ s/<numleafdocs>\d*?\n+/<numleafdocs>$numleafdocs\n/;
    # Store the changed text
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $clid, &dbutil::convert_infodb_string_to_hash($text));
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);
  }
# /** setNumLeafDocs() **/

# /** Set the title metadata in the database.
#  *  Note: Previously this was value and we extracted the title, but the new
#  *        autohierarchies don't set values.
#  *
#  *  @param  $title The new title string
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub setTitle()
  {
    my ($self, $title) = @_;
    print STDERR "ClassifyTreeNode::setTitle(\"$title\")\n" unless !$self->{'debug'};

    my $collection = $self->{'model'}->getCollection();
    my $clid = $self->{'clid'};

    # Load the text of this node
    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $clid);
    # Replace the title
    $text =~ s/<Title>.*?\n+/<Title>$title\n/;
    # Store the changed text
    my $infodb_file_handle = &dbutil::open_infodb_write_handle($self->{'infodbtype'}, $self->{'infodb_file_path'}, "append");
    &dbutil::write_infodb_entry($self->{'infodbtype'}, $infodb_file_handle, $clid, &dbutil::convert_infodb_string_to_hash($text));
    &dbutil::close_infodb_write_handle($self->{'infodbtype'}, $infodb_file_handle);
  }
# /** setValue() **/

# /** Represent this node as a string.
#  *
#  * @return The string representation of this node
#  *
#  * @author John Thompson, DL Consulting Ltd.
#  */
sub toString()
  {
    my ($self) = @_;
    print STDERR "ClassifyTreeNode::toString()\n" unless !$self->{'debug'};
    my $collection = $self->{'model'}->getCollection();
    my $clid = $self->{'clid'};

    my $text = &dbutil::read_infodb_rawentry($self->{'infodbtype'}, $self->{'infodb_file_path'}, $clid);
    return $text;
  }
# /** toString() **/

1;
