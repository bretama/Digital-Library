###########################################################################
#
# IncrementalBuildUtils.pm -- API to assist incremental building
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
# /** Initial versions of these functions by John Thompson, revisions by
#  *  and turning it into a package by John Rowe. Used heavily by
#  *  basebuilder::remove_document() and getdocument.pl
#  *
#  *  @version 1.0 Initial version by John Thompson
#  *  @version 1.1 Addition of get_document and change of get_document_as_xml
#  *               by John Rowe
#  *  @version 2.0 Package version including seperation from calling code and
#  *               modularisation by John Rowe
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  *  @author John Rowe, DL Consulting Ltd.
#  */
###########################################################################
package IncrementalBuildUtils;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};

    # - ensure we only add perllib paths to INC if they weren't already there
    # as otherwise we lose the ability to use order in INC as a guide for
    # inheritence/overriding [jmt12]
    my $gsdl_perllib_path = $ENV{'GSDLHOME'} . '/perllib';
    my $found_path = 0;
    foreach my $inc_path (@INC)
    {
      if ($inc_path eq $gsdl_perllib_path)
      {
        $found_path = 1;
        last;
      }
    }
    if (!$found_path)
    {
      unshift (@INC, $gsdl_perllib_path);
      unshift (@INC, $gsdl_perllib_path . '/cpan');
      unshift (@INC, $gsdl_perllib_path . '/plugins');
      unshift (@INC, $gsdl_perllib_path . '/classify');
    }
}

use doc;
use cfgread;
use colcfg;
use strict;
use util;

use ClassifyTreeModel;
use IncrementalDocument;

# Change debugging to 1 if you want verbose debugging output
my $debug = 1;

# Ensure the collection specific binaries are on the search path
my $path_separator = ":";
if($ENV{'GSDLOS'} =~ /^win/) { # beware to check that it starts with "win" for windows, since darwin also contains "win" but path separator for that should be :
  $path_separator = ";";
}
# - once again we need to ensure we aren't duplicating paths on the environment
# otherwise things like extension executables won't be correctly used in
# preference to main Greenstone ones [jmt12]
my @env_path = split($path_separator, $ENV{'PATH'});
my $os_binary_path = &util::filename_cat($ENV{'GSDLHOME'}, 'bin', $ENV{'GSDLOS'});
my $script_path = &util::filename_cat($ENV{'GSDLHOME'}, 'bin', 'script');
my $found_os_bin = 0;
foreach my $path (@env_path)
{
  if ($path eq $os_binary_path)
  {
    $found_os_bin = 1;
    last;
  }
}
if (!$found_os_bin)
{
  $ENV{'PATH'} = $os_binary_path . $path_separator . $script_path . $path_separator . $ENV{'PATH'};
}


# /**
#  */
sub addDocument()
  {
    my ($collection, $infodbtype, $doc_obj, $section, $updateindex) = @_;

    $updateindex = 0 unless defined($updateindex);

    print STDERR "IncrementalBuildUtils::addDocument('$collection',$infodbtype,$doc_obj,'$section')\n" unless !$debug;
    # Gonna need to know in several places whether this is the top section
    # of the document or not
    my $is_top = ($section eq $doc_obj->get_top_section());

    # Retrieve all of the metadata from this document object only - not any
    # child documents
    my $metadata = $doc_obj->get_all_metadata($section);
    # Check and add the docnum first
    my $found_docnum = 0;
    foreach my $pair (@$metadata)
      {
        my ($key, $value) = (@$pair);
        if ($key eq "docnum")
          {
            &setDocumentMetadata($collection, $infodbtype, $doc_obj->get_OID() . "$section", $key, "", $value, $updateindex);
            $found_docnum = 1;
          }
      }

    if (!$found_docnum)
      {
        die("Fatal Error! Tried to add document without providing docnum");
      }

    # Add it piece by piece - this depends on the loading of a blank document
    # working the way it should.
    foreach my $pair (@$metadata)
      {
        my ($key, $value) = (@$pair);
        if ($key ne "Identifier" && $key ne "docnum" && $key !~ /^gsdl/ && defined $value && $value ne "")
          {
            # escape problematic stuff
            $value =~ s/\\/\\\\/g;
            $value =~ s/\n/\\n/g;
            $value =~ s/\r/\\r/g;
            if ($value =~ /-{70,}/)
              {
                # if value contains 70 or more hyphens in a row we need
                # to escape them to prevent txt2db from treating them
                # as a separator
                $value =~ s/-/&\#045;/gi;
              }
            # Go ahead and set the metadata
            &setDocumentMetadata($collection, $infodbtype, $doc_obj->get_OID() . "$section", $key, "", $value, $updateindex);
          }
      }
    # We now have to load the browselist node too. We create a ClassifyTreeNode
    # based on a dummy model.
    # Note: only if section is the top section
    if ($is_top)
      {
        my $dummy_model = new ClassifyTreeModel($collection, $infodbtype, "");
        my $browselist_node = new ClassifyTreeNode($dummy_model, "browselist");
        # Add the document
        $browselist_node->addDocument($doc_obj->get_OID());
      }
    # We now recursively move through the document objects child sections,
    # adding them too. As we do this we build up a contains list for this
    # document.
    my $section_ptr = $doc_obj->_lookup_section($section);
    my @contains = ();
    if (defined $section_ptr)
      {
        foreach my $subsection (@{$section_ptr->{'subsection_order'}}) {
          &addDocument($collection, $infodbtype, $doc_obj, "$section.$subsection");
          push(@contains, "\".$subsection");
        }
      }
    # Done - clean up
  }
# /** addDocument() **/

# /** Sets the metadata attached to a given document. This will update, at most,
#  *  three different locations:
#  *  1. The Lucene index must be updated. This will involve removing any
#  *     existing value and, if required, adding a new value in its place.
#  *  2. The info database must be updated. Again any existing value will be
#  *     removed and, if required, a new value added.
#  *  3. Finally a check against the collect.cfg will be done to determine if
#  *     the changed metadata would have an effect on a classifier and, if so
#  *     the classifier tree will be updated to remove, add or replace any
#  *     tree nodes or node 'contains lists' as necessary.
#  *
#  *  Pseudo Code:
#  *  ------------
#  *  To add metadata to the document NT1
#  *  A. Establish connection to Lucene
#  *  B. Create a IncrementalDocument object for 'NT1' loading the information
#  *     from the info database
#  *  C. Check to see if this metadata is used to build a classifier(s) and if
#  *     so create the appropriate ClassifyTreeModel(s)
#  *  D. If removing or replacing metadata:
#  *     i/   Call ??? to remove key-value from Lucene index
#  *     ii/  Use removeMetadata() to clear value in IncrementalDocument
#  *     iii/ Call removeDocument() in ClassifyTreeModel(s) as necessary
#  *  E. If adding or replacing metadata:
#  *     i/   Call ??? to add key-value from Lucene index
#  *     ii/ Use addMetadata() to add value in IncrementalDocument
#  *     iii/ Call addDocument() in ClassifyTreeModel(s) as necessary
#  *  F. Complete Lucene transaction
#  *  G. Save IncrementalDocument to info database
#  *  Note: ClassifyTreeModel automatically updates the info database as necessary.
#  *
#  *  @param  $collection  The name of the collection to update as a string
#  *  @param  $oid         The unique identifier of a Greenstone document as a
#  *                       string
#  *  @param  $key         The key of the metadata being added as a string
#  *  @param  $old_value   The value of the metadata being removed/replaced
#  *                       or an empty string if adding metadata
#  *  @param  $new_value   The value of the metadata being added/replacing
#  *                       or an empty string if removing metadata
#  *  @param  $updateindex 1 to get the index updated. This is used to prevent
#  *                       the indexes being changed when doing an incremental
#  *                       addition of a new document.
#  *
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub setDocumentMetadata()
  {
    my ($collection, $infodbtype, $oid, $key, $old_value, $new_value, $updateindex) = @_;
    print STDERR "IncrementalBuildUtils::setDocumentMetadata('$collection',$infodbtype,'$oid','$key','$old_value','$new_value',$updateindex)\n" unless !$debug;
    # A. Establish connection to Lucene
    #    This isn't required at the moment, but might be later if we implement
    #    Lucene daemon.
    # B. Create a IncrementalDocument object for 'NT1' loading the information
    #    from the info database
    print STDERR "* creating incremental document for $oid\n" unless !$debug;
    my $doc_obj = new IncrementalDocument($collection, $infodbtype, $oid);
    $doc_obj->loadDocument();
    # C. Check to see if this metadata is used to build a classifier(s) and if
    #    so create the appropriate ClassifyTreeModel(s)
    print STDERR "* load collection configuration\n" unless !$debug;
    my $config_obj = &getConfigObj($collection);
    my $clidx = 1;
    my @classifier_tree_models = ();
    foreach my $classifier (@{$config_obj->{'classify'}})
      {
        my $index = 0;
        my $option_count = scalar(@{$classifier});
        for ($index = 0; $index < $option_count; $index++)
          {
            if ($index + 1 < $option_count && @{$classifier}[$index] eq "-metadata" && @{$classifier}[$index + 1] eq $key)
              {
                # Create a tree model for this classifier
                print STDERR "* creating a tree model for classifier: CL$clidx\n" unless !$debug;
                my $tree_model_obj = new ClassifyTreeModel($collection, $infodbtype, "CL" . $clidx);
                # And store it for later
                push(@classifier_tree_models, $tree_model_obj);
              }
          }
        $clidx++;
      }
    # D. If removing or replacing metadata:
    if (defined($old_value) && $old_value =~ /[\w\d]+/)
      {
        print STDERR "* removing '$key'='$old_value' from info database for document $oid\n" unless !$debug;
        # i/   Call ??? to remove key-value from Lucene index
        #      Moved elsewhere
        # ii/  Use removeMetadata() to clear value in IncrementalDocument
        $doc_obj->removeMetadata($key, $old_value);
        # iii/ Call removeDocument() in ClassifyTreeModel(s) as necessary
        foreach my $classifier_tree_model (@classifier_tree_models)
          {
            print STDERR "* removing '$old_value' from classifier tree\n" unless !$debug;
            $classifier_tree_model->removeDocument($old_value, $oid, 1);
          }
      }
    # E. If adding or replacing metadata:
    if (defined($new_value) && $new_value =~ /[\w\d]+/)
      {
        print STDERR "* adding '$key'='$new_value' to info database for document $oid\n" unless !$debug;
        # i/   Call ??? to add key-value from Lucene index
        #      Moved elsewhere
        # ii/ Use addMetadata() to add value in IncrementalDocument
        $doc_obj->addMetadata($key, $new_value);
        # iii/ Call addDocument() in ClassifyTreeModel(s) as necessary
        foreach my $classifier_tree_model (@classifier_tree_models)
          {
            print STDERR "* adding '$new_value' to classifier tree\n" unless !$debug;
            $classifier_tree_model->addDocument($new_value, $oid);
          }
      }
    # F. Complete Lucene transaction
    if(defined($updateindex) && $updateindex)
      {
        print STDERR "* updating Lucene indexes\n" unless !$debug;
        &callGS2LuceneEditor($collection, $doc_obj->getDocNum, $key, $old_value, $new_value);
      }
    # G. Save IncrementalDocument to info database
    $doc_obj->saveDocument();
    $doc_obj = 0;
  }
# /** setDocumentMetadata() **/

# /**
#  *
#  */
sub callGS2LuceneDelete()
  {
    my ($collection, $docnum) = @_;

    # Some path information that is the same for all indexes
    my $classpath = &util::filename_cat($ENV{'GSDLHOME'},"bin","java","LuceneWrap.jar");
    my $java_lucene = "org.nzdl.gsdl.LuceneWrap.GS2LuceneDelete";
    my $indexpath = &util::filename_cat($ENV{'GSDLHOME'},"collect",$collection,"index");
    # Determine what indexes need to be changed by opening the collections
    # index path and searching for directories named *idx
    # If the directory doesn't exist, then there is no built index, and nothing
    # for us to do.
    if(opendir(INDEXDIR, $indexpath))
      {
        my @index_files = readdir(INDEXDIR);
        closedir(INDEXDIR);
        # For each index that matches or pattern, we call the java application
        # to change the index (as necessary - not every index will include the
        # document we have been asked to modify)
        foreach my $actual_index_dir (@index_files)
          {
            next unless $actual_index_dir =~ /idx$/;
            # Determine the path to the index to modify
            my $full_index_dir = &util::filename_cat($indexpath, $actual_index_dir);
            # Call java to remove the document
            my $cmd = "java -classpath \"$classpath\" $java_lucene --index $full_index_dir --nodeid $docnum";
            print STDERR "CMD: " . $cmd . "\n" unless !$debug;
            # Run command
            my $result = `$cmd 2>&1`;
            print STDERR $result unless !$debug;
          }
      }
    # Done
  }
# /** callGS2LuceneDelete() **/

# /**
#  */
sub callGS2LuceneEditor()
  {
    my ($collection, $docnum, $key, $old_value, $new_value) = @_;

    # Some path information that is the same for all indexes
    my $classpath = &util::filename_cat($ENV{'GSDLHOME'},"collect",$collection,"java","classes");
    my $jarpath = &util::filename_cat($ENV{'GSDLHOME'},"bin","java","LuceneWrap.jar");
    my $java_lucene = "org.nzdl.gsdl.LuceneWrap.GS2LuceneEditor";
    my $indexpath = &util::filename_cat($ENV{'GSDLHOME'},"collect",$collection,"index");
    # And some commands that don't change
    my $java_args = "";
    # Append the node id
    $java_args .= "--nodeid $docnum ";
    # We have to convert the given metadata key into its two letter field code.
    # We do this by looking in the build.cfg file.
    my $field = &getFieldFromBuildCFG($indexpath, $key);
    # The metadata field to change
    $java_args .= "--field $field ";
    # And the old and new values as necessary
    if(defined($old_value) && $old_value =~ /[\w\d]+/)
      {
        $java_args .= "--oldvalue \"$old_value\" ";
      }
    if(defined($new_value) && $new_value =~ /[\w\d]+/)
      {
        $java_args .= "--newvalue \"$new_value\" ";
      }
    # Determine what indexes need to be changed by opening the collections
    # index path and searching for directories named *idx
    # If the directory doesn't exist, then there is no built index, and nothing
    # for us to do.
    # We also check if the field is something other than "". It is entirely
    # possible that we have been asked to update a metadata field that isn't
    # part of any index, so this is where we break out of editing the index if
    # we have
    if($field =~ /^\w\w$/ && opendir(INDEXDIR, $indexpath))
      {
        my @index_files = readdir(INDEXDIR);
        closedir(INDEXDIR);
        # For each index that matches or pattern, we call the java application
        # to change the index (as necessary - not every index will include the
        # document we have been asked to modify)
        foreach my $actual_index_dir (@index_files)
          {
            next unless $actual_index_dir =~ /idx$/;
            # Determine the path to the index to modify
            my $full_index_dir = &util::filename_cat($indexpath, $actual_index_dir);
            # And prepend to the command java arguments
            my $cur_java_args = "--index $full_index_dir " . $java_args;
            print STDERR "CMD: java -classpath \"$classpath:$jarpath\" $java_lucene $cur_java_args 2>&1\n" unless !$debug;
            # Run command
            my $result = `java -classpath \"$classpath:$jarpath\" $java_lucene $cur_java_args 2>&1`;
            print STDERR $result unless !$debug;
          }
      }
    # Done
  }
# /** callGS2LuceneEditor() **/

## Remove a document from the info database and Index.
#
#  @param  collection  The collection to alter
#  @param  oid         The unique identifier of the document to be removed
##
sub deleteDocument()
  {
    my ($collection, $infodbtype, $oid) = @_;
    # Load the incremental document to go with this oid, as we need some
    # information from it.
    my $doc_obj = new IncrementalDocument($collection, $infodbtype, $oid);
    $doc_obj->loadDocument();
    # Check if this object even exists by retrieving the docnum.
    my $doc_num = $doc_obj->getDocNum();
    print STDERR "Removing document docnum: $doc_num\n" unless !$debug;
    if ($doc_num > -1)
      {
        # Now write a blank string to this oid in the info database
	my $index_text_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "index", "text");
	my $infodb_file_path = &dbutil::get_infodb_file_path($infodbtype, $collection, $index_text_directory_path);
	my $infodb_file_handle = &dbutil::open_infodb_write_handle($infodbtype, $infodb_file_path, "append");
	&dbutil::write_infodb_entry($infodbtype, $infodb_file_handle, $oid, &dbutil::convert_infodb_string_to_hash(""));
        # Remove reverse lookup
	&dbutil::write_infodb_entry($infodbtype, $infodb_file_handle, $doc_num, &dbutil::convert_infodb_string_to_hash(""));
	&dbutil::close_infodb_write_handle($infodbtype, $infodb_file_handle);

        # And remove from the database
        &callGS2LuceneDelete($collection, $doc_num);

        # Regenerate the classifier trees.
        print STDERR "* load collection configuration\n";# unless !$debug;
        my $config_obj = &getConfigObj($collection);
        my $clidx = 1;
        my %classifier_tree_models = ();
        foreach my $classifier (@{$config_obj->{'classify'}})
          {
            my $index = 0;
            my $option_count = scalar(@{$classifier});
            for ($index = 0; $index < $option_count; $index++)
              {
                if ($index + 1 < $option_count && @{$classifier}[$index] eq "-metadata")
                  {
                    my $key = @{$classifier}[$index + 1];
                    # Create a tree model for this classifier
                    print STDERR "* creating a tree model for classifier: CL" . $clidx . " [" . $key . "]\n";# unless !$debug;
                    my $tree_model_obj = new ClassifyTreeModel($collection, $infodbtype, "CL" . $clidx);
                    # And store it against its key for later
                    $classifier_tree_models{$key} = $tree_model_obj;
                  }
              }
            $clidx++;
          }
        
        # For each piece of metadata assigned to this document, if there is a 
        # matching classifier tree, remove the path from the tree.
        print STDERR "* searching for classifier paths to be removed\n";
        
        my $metadata = $doc_obj->getAllMetadata();
        foreach my $pair (@$metadata)
          {
            my ($key, $value) = @$pair;
            print STDERR "* testing " . $key . "=>" . $value . "\n";
            if (defined($classifier_tree_models{$key}))
              {
                my $model = $classifier_tree_models{$key};
                print STDERR "* removing '" . $value . "' from classifier " . $model->getRootNode()->getCLID() . "\n";
                $model->removeDocument($value, $oid, 1);
              }
          }

        # We also have to remove from browselist - the reverse process of
        # adding to browselist shown above.
        my $dummy_model = new ClassifyTreeModel($collection, $infodbtype, "");
        my $browselist_node = new ClassifyTreeNode($dummy_model, "browselist");
        # Add the document
        $browselist_node->removeDocument($oid);
        # Clean up
      }
    # else, no document, no need to delete.
  }
## deleteDocument() ##

# /**
#  */
sub getFieldFromBuildCFG()
  {
    my ($indexpath, $key) = @_;
    my $field = "";
    my $build_cfg = &util::filename_cat($indexpath, "build.cfg");
    # If there isn't a build.cfg then the index hasn't been built and there is
    # nothing to do
    if(open(BUILDCFG, $build_cfg))
      {
        # For each line of the build configuration
        my $line;
        while($line = <BUILDCFG>)
          {
            # Only interested in the indexfieldmap line
            if($line =~ /^indexfieldmap\s+/)
              {
                # Extract the field information by looking up the key pair
                if($line =~ /\s$key->(\w\w)/)
                  {
                    $field = $1;
                  }
              }
          }
        # Done with file
        close(BUILDCFG);
      }
    # Return whatever we found
    return $field;
  }
# /** getFieldFromBuildCFG() **/





# /** Retrieve an object (associative array) containing information about the
#  *  collection configuration.
#  *  @param  $collection The shortname of the collection as a string
#  *  @return An associative array containing information from the collect.cfg
#  *  @author John Thompson, DL Consulting Ltd.
#  */
sub getConfigObj()
  {
    my ($collection) = @_;

    #rint STDERR "getConfigObj()\n" unless !$debug;

    my $colcfgname = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection, "etc", "collect.cfg");
    if (!-e $colcfgname)
      {
        die "IncrementalBuildUtils - couldn't find collect.cfg for collection $collection\n";
      }
    return &colcfg::read_collect_cfg ($colcfgname);
  }
# /** getConfigObj() **/

1;
