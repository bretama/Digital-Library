###########################################################################
#
# classify.pm --
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

# functions to handle classifiers

package classify;

require util;
use FileUtils;
require AllList;

use dbutil;
use gsprintf;
use strict; no strict 'subs';


sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}


sub load_classifier_for_info {
    my ($classifier) = shift @_;

    # find the classifier
    # - used to have hardcoded list of places to load classifier from. We
    # should, instead, try loading from all of the perllib places on the
    # library path, as that improves support for extensions. Special cases
    # needed for collection specific and custom classifier. [jmt12]
    my @possible_class_paths;
    if (defined($ENV{'GSDLCOLLECTION'}))
    {
      push(@possible_class_paths, &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'custom', $ENV{'GSDLCOLLECTION'}, 'perllib', 'classify', $classifier . '.pm'));
    }
    # (why does GSDLCOLLECTDIR get set to GSDLHOME for classinfo calls?)
    if ($ENV{'GSDLCOLLECTDIR'} ne $ENV{'GSDLHOME'})
    {
      push(@possible_class_paths, &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib', 'classify', $classifier . '.pm'));
    }
    foreach my $library_path (@INC)
    {
      # only interested in classify paths found in the library paths
      if ($library_path =~ /classify$/)
      {
       push(@possible_class_paths, &FileUtils::filenameConcatenate($library_path, $classifier . '.pm'));
      }
    }
    my $found_class = 0;
    foreach my $possible_class_path (@possible_class_paths)
    {
      if (-e $possible_class_path)
      {
        require $possible_class_path;
        $found_class = 1;
        last;
      }
    }
    if (!$found_class)
    {
      &gsprintf(STDERR, "{classify.could_not_find_classifier}\n", $classifier) && die "\n";
    }

    my ($classobj);
    my $options = "-gsdlinfo";
    eval ("\$classobj = new \$classifier([],[$options])");
    die "$@" if $@;

    return $classobj;
}

sub load_classifiers {
    my ($classify_list, $build_dir, $outhandle) = @_;
    my @classify_objects = ();
    my $classify_number  = 1;

    # - ensure colclassdir doesn't already exist in INC before adding, other-
    # wise we risk clobbering classifier inheritence implied by order of paths
    # in INC [jmt12]
    my $colclassdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},"perllib/classify");
    &util::augmentINC($colclassdir);

    foreach my $classifyoption (@$classify_list) {

	# get the classifier name
	my $classname = shift @$classifyoption;
	next unless defined $classname;

	# find the classifier
        # - replaced as explained in load_classifier_for_info() [jmt12]
        my @possible_class_paths;
        if (defined($ENV{'GSDLCOLLECTION'}))
        {
          push(@possible_class_paths, &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'custom', $ENV{'GSDLCOLLECTION'}, 'perllib', 'classify', $classname . '.pm'));
        }
        # (why does GSDLCOLLECTDIR get set to GSDLHOME for classinfo calls?)
        if ($ENV{'GSDLCOLLECTDIR'} ne $ENV{'GSDLHOME'})
        {
          push(@possible_class_paths,&FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, 'perllib', 'classify', $classname . '.pm'));
        }
        foreach my $library_path (@INC)
        {
          # only interested in classify paths found in the library paths
          if ($library_path =~ /classify$/)
          {
            push(@possible_class_paths, &FileUtils::filenameConcatenate($library_path, $classname . '.pm'));
          }
        }
        my $found_class = 0;
        foreach my $possible_class_path (@possible_class_paths)
        {
          if (-e $possible_class_path)
          {
            require $possible_class_path;
            $found_class = 1;
            last;
          }
        }
        if (!$found_class)
        {
          &gsprintf(STDERR, "{classify.could_not_find_classifier}\n", $classname) && die "\n";
        }

	# create the classify object
	my ($classobj);

	my @newoptions;

	# do these first so they can be overriden by user supplied options
	if ($build_dir) {
		(my $build_dir_re = $build_dir) =~ s@\\@\\\\@g; # copy build_dir into build_dir_re and modify build_dir_re
		push @newoptions, "-builddir", "$build_dir_re";
	}
	push @newoptions, "-outhandle", "$outhandle" if ($outhandle);
	push @newoptions, "-verbosity", "2";

	# backwards compatability hack: if the classifier options are 
	# in "x=y" format, convert them to parsearg ("-x y") format.
	my ($opt, $key, $value);
	foreach $opt (@$classifyoption) {
	    # if ($opt =~ /^(\w+)=(.*)$/) {
	    #	push @newoptions, "-$1", $2;
	    # } else {
		push @newoptions, $opt;
	    #}
	}

	eval ("\$classobj = new \$classname([],[\@newoptions])");
	die "$@" if $@;

	$classobj->set_number($classify_number);
	$classify_number ++;

       	# add this object to the list
	push (@classify_objects, $classobj);
    }

    return \@classify_objects;
}

# init_classifiers resets all the classifiers and readys them to process
# the documents.
sub init_classifiers {
    my ($classifiers) = @_;
    
    foreach my $classobj (@$classifiers) {
	$classobj->init();
    }
}



# takes a hashref containing the metadata for an infodb entry, and extracts 
# the childrens numbers (from the 'contains' entry).	
# assumes format is ".1;".2;".3
sub get_children {	
    my ($doc_db_hash) = @_; 

    my $children = undef;

    my $contains = $doc_db_hash->{'contains'};
    if (defined ($contains)) {
	$contains =~ s/\@$//;  #remove trailing @
	$contains =~ s/^\"\.//; #remove initial ".
	@$children = split /\;\"\./, $contains;
    }

    return $children;
}

    
sub recurse_sections {
    my ($doc_obj, $children, $parentoid, $parentsection, $database_recs) = @_;

    return if (!defined $children);

    foreach my $child (sort { $a <=> $b} @$children) {
	$doc_obj->create_named_section("$parentsection.$child");
	my $doc_db_rec = $database_recs->{"$parentoid.$child"};
	my $doc_db_hash = db_rec_to_hash($doc_db_rec);

	# get child's children
	my $newchildren = &get_children($doc_db_hash); 

	# add content for current section
	add_section_content($doc_obj, "$parentsection.$child", $doc_db_hash);

	# process all the children if there are any
	if (defined ($newchildren))
	{
	    recurse_sections($doc_obj, $newchildren, "$parentoid.$child", 
			     "$parentsection.$child", $database_recs);
	}
    }
}					     


sub add_section_content {
    my ($doc_obj, $cursection, $doc_db_hash) = @_;
 
    foreach my $key (keys %$doc_db_hash) {
	#don't need to store these metadata
	next if $key =~ /(thistype|childtype|contains|docnum|doctype|classifytype)/i;
	# but do want things like hastxt and archivedir
	my @items = split /@/, $doc_db_hash->{$key};
	# metadata is all from the info database so should already be in utf8
	map {$doc_obj->add_utf8_metadata ($cursection, $key, $_); } @items;

    }
}


# gets all the metadata from an infodb entry, and puts it into a hashref
sub db_rec_to_hash {
    
    my ($infodb_str_ref) = @_;

    my $hashref = {};

    my @entries = split(/\n/, $infodb_str_ref);
    foreach my $entry (@entries) {
	my($key, $value) = ($entry =~ /^<([^>]*)>(.*?)$/ );
	$hashref->{$key} .= '@' if defined $hashref->{$key};
	$hashref->{$key} .= $value;
	
    }
   
    return $hashref;
}					  


sub reconstruct_doc_objs_metadata
{
    my $infodb_type = shift(@_);
    my $infodb_file_path = shift(@_);
    my $database_recs = shift(@_);

    # dig out top level doc sections
    my %top_sections = ();
    my %top_docnums = ();
    foreach my $key ( keys %$database_recs )
    {
	my $md_rec = $database_recs->{$key};
	my $md_hash = db_rec_to_hash($md_rec);

	if ((defined $md_hash->{'doctype'}) && ($md_hash->{'doctype'} eq "doc")) {
	    next if ($key =~ m/\./);
	    $top_sections{$key} = $md_hash;
	    $top_docnums{$key} = $md_hash->{'docnum'};
	}
    }

    # for greenstone document objects based on metadata in database file
    my @all_docs = ();
    # we need to make sure the documents were processed in the same order as
    # before, so sort based on their docnums
    foreach my $oid ( sort { $top_docnums{$a} <=> $top_docnums{$b} } keys %top_sections )
    {
	my $doc_db_hash = $top_sections{$oid};

	my $doc_obj = new doc();
	$doc_obj->set_OID($oid);
	my $top = $doc_obj->get_top_section();
        add_section_content ($doc_obj, $top, $doc_db_hash);
        my $children = &get_children($doc_db_hash);
        recurse_sections($doc_obj, $children, $oid, $top, $database_recs);

	push(@all_docs,$doc_obj);
    }    

    return \@all_docs;   
}





# classify_doc lets each of the classifiers classify a document
sub classify_doc {
    my ($classifiers, $doc_obj) = @_;

    foreach my $classobj (@$classifiers) {
	my $title = $classobj->{'title'};

	$classobj->classify($doc_obj);
    }
}


our $next_classify_num = 1;

# output_classify_info outputs all the info needed for the classification
# to the database
sub output_classify_info
{
    my ($classifiers, $infodb_type, $infodb_handle, $remove_empty_classifications, $gli) = @_;

    $gli = 0 unless defined $gli;

    # create a classification containing all the info
    my $classifyinfo = { 'classifyOID'=> 'browse',
			 'contains' => [] };

    # get each of the classifications
    foreach my $classifier (@$classifiers)
    {
	my $classifier_info = $classifier->get_classify_info($gli);
	if (defined $classifier_info) {
	    $classifier_info->{'classifyOID'} = "CL$next_classify_num" unless defined($classifier_info->{'classifyOID'});
	    print STDERR "*** outputting information for classifier: $classifier_info->{'classifyOID'}\n";

	    push(@{$classifyinfo->{'contains'}}, $classifier_info);
	} else {
	    print STDERR "*** error with classifier CL$next_classify_num, not outputing it\n";
	}
	$next_classify_num++;

    }

    &print_classify_info($infodb_type, $infodb_handle, $classifyinfo, "", $remove_empty_classifications);
}


sub print_classify_info
{
    my ($infodb_type, $infodb_handle, $classifyinfo, $OID, $remove_empty_classifications) = @_;

    $OID =~ s/^\.+//; # just for good luck

    # book information is printed elsewhere
    return if (defined ($classifyinfo->{'OID'}));
 
    # don't want empty classifications
    return if (&check_contents ($classifyinfo, $remove_empty_classifications) == 0 && $remove_empty_classifications);
   
    $OID = $classifyinfo->{'classifyOID'} if defined ($classifyinfo->{'classifyOID'});

    my %classify_infodb = ();
    $classify_infodb{"doctype"} = [ "classify" ];
    $classify_infodb{"hastxt"} = [ "0" ];
    $classify_infodb{"childtype"} = [ $classifyinfo->{'childtype'} ]
	if defined $classifyinfo->{'childtype'};
    $classify_infodb{"Title"} = [ $classifyinfo->{'Title'} ]
	if defined $classifyinfo->{'Title'};
    $classify_infodb{"numleafdocs"} = [ $classifyinfo->{'numleafdocs'} ]
	if defined $classifyinfo->{'numleafdocs'};
    $classify_infodb{"thistype"} = [ $classifyinfo->{'thistype'} ]
	if defined $classifyinfo->{'thistype'};
    $classify_infodb{"parameters"} = [ $classifyinfo->{'parameters'} ]
	if defined $classifyinfo->{'parameters'};
    $classify_infodb{"supportsmemberof"} = [ $classifyinfo->{'supportsmemberof'} ]
	if defined $classifyinfo->{'supportsmemberof'};
    
    my $contains_text = "";
    my $mdoffset_text = "";
    
    my $next_subOID = 1;
    my $first = 1;
    foreach my $tempinfo (@{$classifyinfo->{'contains'}}) {
	# empty contents were made undefined by clean_contents()
	next unless defined $tempinfo;
	if (!defined ($tempinfo->{'classifyOID'}) ||
	    $tempinfo->{'classifyOID'} ne "oai") {
	    $contains_text .= ";" unless $first;
	}
	$mdoffset_text .= ";" unless $first;
	$first = 0;
	
	if (defined ($tempinfo->{'classifyOID'}))
	{
	    if ($tempinfo->{'classifyOID'} ne "oai")
	    {
		$contains_text .= $tempinfo->{'classifyOID'};
	    }

	    &print_classify_info ($infodb_type, $infodb_handle, $tempinfo, $tempinfo->{'classifyOID'},
				  $remove_empty_classifications);
	}
	elsif (defined ($tempinfo->{'OID'}))
	{
	    $contains_text .= $tempinfo->{'OID'};
	    $mdoffset_text .= $tempinfo->{'offset'} if (defined ($tempinfo->{'offset'}));
	}
	else
	{
	    # Supress having top-level node in Collage classifier
	    # so no bookshelf icon appears, top-level, along with the
	    # applet
	    if (!defined ($tempinfo->{'Title'}) || $tempinfo->{'Title'} ne "Collage")
	    {
		$contains_text .= "\".$next_subOID"; 
	    }

	    &print_classify_info ($infodb_type, $infodb_handle, $tempinfo, "$OID.$next_subOID",
				  $remove_empty_classifications);
	    $next_subOID++;
	}
    }
    
    $classify_infodb{"contains"} = [ $contains_text ];
    $classify_infodb{"mdtype"} = [ $classifyinfo->{'mdtype'} ]
	if defined $classifyinfo->{'mdtype'};
    $classify_infodb{"mdoffset"} = [ $mdoffset_text ]
	if ($mdoffset_text !~ m/^;+$/);
    
    &dbutil::write_infodb_entry($infodb_type, $infodb_handle, $OID, \%classify_infodb);
}


sub check_contents {
    my ($classifyinfo,$remove_empty_classifications) = @_;
    $remove_empty_classifications = 0 unless ($remove_empty_classifications);
    my $num_leaf_docs = 0;
    my $sub_num_leaf_docs = 0;

    return $classifyinfo->{'numleafdocs'} if (defined $classifyinfo->{'numleafdocs'});

    foreach my $content (@{$classifyinfo->{'contains'}}) {
	if (defined $content->{'OID'}) {
	    # found a book
	    $num_leaf_docs ++;
	} elsif (($sub_num_leaf_docs = &check_contents ($content,$remove_empty_classifications)) > 0) {
	    # there's a book somewhere below
	    $num_leaf_docs += $sub_num_leaf_docs;
	} else {
	    if ($remove_empty_classifications){
		# section contains no books so we want to remove 
		# it from its parents contents
		$content = undef;
	    }
	}
    }

    $classifyinfo->{'numleafdocs'} = $num_leaf_docs;
    return $num_leaf_docs;
}

1;
