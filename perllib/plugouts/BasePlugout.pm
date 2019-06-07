###########################################################################
#
# BasePlugout.pm -- base class for all the plugout modules
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

package BasePlugout;

eval {require bytes};

use strict;
no strict 'subs';
no strict 'refs';

use dbutil;
use gsprintf 'gsprintf';
use printusage;
use parse2;
use util;
use FileUtils;
use sorttools;

# suppress the annoying "subroutine redefined" warning that various
# gets cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

my $arguments = [ 
       { 'name' => "xslt_file", 
	'desc' => "{BasPlugout.xslt_file}",
	'type' => "string",
	'reqd' => "no",
	 'deft' => "",
	'hiddengli' => "no"},
       { 'name' => "subdir_split_length",
	 'desc' => "{BasPlugout.subdir_split_length}",
	 'type' => "int",
	 'reqd' => "no",
         'deft' => "8",
	 'hiddengli' => "no"},
       { 'name' => "subdir_hash_prefix",
	 'desc' => "{BasPlugout.subdir_hash_prefix}",
	 'type' => "flag",
	 'reqd' => "no",
         'deft' => "0",
	 'hiddengli' => "no"},
       { 'name' => "gzip_output", 
	'desc' => "{BasPlugout.gzip_output}",
	'type' => "flag",
	'reqd' => "no",  
     	'hiddengli' => "no"},
        { 'name' => "verbosity", 
	'desc' => "{BasPlugout.verbosity}",
	'type' => "int",
        'deft' =>  "0",
	'reqd' => "no",  
     	'hiddengli' => "no"},
      { 'name' => "output_info", 
	'desc' => "{BasPlugout.output_info}",
	'type' => "string",   
	'reqd' => "yes",
	'hiddengli' => "yes"},        
       { 'name' => "output_handle", 
	'desc' => "{BasPlugout.output_handle}",
	'type' => "string",
        'deft' =>  'STDERR',
	'reqd' => "no",
	'hiddengli' => "yes"},
       { 'name' => "debug",
	 'desc' => "{BasPlugout.debug}",
	 'type' => "flag",
	 'reqd' => "no",
	 'hiddengli' => "yes"},
       { 'name' => 'no_rss',
         'desc' => "{BasPlugout.no_rss}",
         'type' => 'flag',
         'reqd' => 'no',
         'hiddengli' => 'yes'},
       { 'name' => 'rss_title',
         'desc' => "{BasPlugout.rss_title}",
         'type' => 'string',
	 'deft' => 'dc.Title',
         'reqd' => 'no',
         'hiddengli' => 'yes'},
    { 'name' => "no_auxiliary_databases",
      'desc' => "{BasPlugout.no_auxiliary_databases}",
      'type' => "flag",
      'reqd' => "no",
      'hiddengli' => "yes"}

];

my $options = { 'name'     => "BasePlugout",
		'desc'     => "{BasPlugout.desc}",
		'abstract' => "yes",
		'inherits' => "no",
		'args'     => $arguments};

sub new 
{
    my $class = shift (@_);

    my ($plugoutlist,$args,$hashArgOptLists) = @_;
    push(@$plugoutlist, $class);

    my $plugout_name = (defined $plugoutlist->[0]) ? $plugoutlist->[0] : $class;

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = {};
    $self->{'plugout_type'} = $class;
    $self->{'option_list'} = $hashArgOptLists->{"OptList"};
    $self->{"info_only"} = 0;

    # Check if gsdlinfo is in the argument list or not - if it is, don't parse 
    # the args, just return the object.  
    foreach my $strArg (@{$args})
    {
	if(defined $strArg && $strArg eq "-gsdlinfo")
	{
	    $self->{"info_only"} = 1;
	    return bless $self, $class;
	}
    }
    
    delete $self->{"info_only"};
    
    if(parse2::parse($args,$hashArgOptLists->{"ArgList"},$self) == -1)
    {
	my $classTempClass = bless $self, $class;
	print STDERR "<BadPlugout d=$plugout_name>\n";
	&gsprintf(STDERR, "\n{BasPlugout.bad_general_option}\n", $plugout_name);
	$classTempClass->print_txt_usage("");  # Use default resource bundle
	die "\n";
    }

 
    if(defined $self->{'xslt_file'} &&  $self->{'xslt_file'} ne "")
    {
	my $full_file_path = &util::locate_config_file($self->{'xslt_file'});
	if (!defined $full_file_path) {
	    print STDERR "Can not find $self->{'xslt_file'}, please make sure you have supplied the correct file path or put the file into the collection's etc or greenstone's etc folder\n";
	    die "\n";
	}
	$self->{'xslt_file'} = $full_file_path;
    }

    # for group processing
    $self->{'gs_count'} = 0;
    $self->{'group_position'} = 1;

    $self->{'keep_import_structure'} = 0;

    $self->{'generate_databases'} = 1;
    if ($self->{'no_auxiliary_databases'}) {
	$self->{'generate_databases'} = 0;
    }
    undef $self->{'no_auxiliary_databases'};
    return bless $self, $class;

}

# implement this in subclass if you want to do some initialization after 
# loading and setting parameters, and before processing the documents.
sub begin {

    my $self= shift (@_);

}
sub print_xml_usage
{
    my $self = shift(@_);
    my $header = shift(@_);
    my $high_level_information_only = shift(@_);

    # XML output is always in UTF-8
    gsprintf::output_strings_in_UTF8;

    if ($header) {
	&PrintUsage::print_xml_header("plugout");
    }
    $self->print_xml($high_level_information_only);
}


sub print_xml
{
    my $self = shift(@_);
    my $high_level_information_only = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $plugoutoptions = shift(@$optionlistref);
    return if (!defined($plugoutoptions));

    gsprintf(STDERR, "<PlugoutInfo>\n");
    gsprintf(STDERR, "  <Name>$plugoutoptions->{'name'}</Name>\n");
    my $desc = gsprintf::lookup_string($plugoutoptions->{'desc'});
    $desc =~ s/</&amp;lt;/g; # doubly escaped
    $desc =~ s/>/&amp;gt;/g;
    gsprintf(STDERR, "  <Desc>$desc</Desc>\n");
    gsprintf(STDERR, "  <Abstract>$plugoutoptions->{'abstract'}</Abstract>\n");
    gsprintf(STDERR, "  <Inherits>$plugoutoptions->{'inherits'}</Inherits>\n");
    unless (defined($high_level_information_only)) {
	gsprintf(STDERR, "  <Arguments>\n");
	if (defined($plugoutoptions->{'args'})) {
	    &PrintUsage::print_options_xml($plugoutoptions->{'args'});
	}
	gsprintf(STDERR, "  </Arguments>\n");

	# Recurse up the plugout hierarchy
	$self->print_xml();
    }
    gsprintf(STDERR, "</PlugoutInfo>\n");
}


sub print_txt_usage
{
    my $self = shift(@_);

    # Print the usage message for a plugout (recursively)
    my $descoffset = $self->determine_description_offset(0);
    $self->print_plugout_usage($descoffset, 1);
}

sub determine_description_offset
{
    my $self = shift(@_);
    my $maxoffset = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $plugoutoptions = pop(@$optionlistref);
    return $maxoffset if (!defined($plugoutoptions));

    # Find the length of the longest option string of this download
    my $plugoutargs = $plugoutoptions->{'args'};
    if (defined($plugoutargs)) {
	my $longest = &PrintUsage::find_longest_option_string($plugoutargs);
	if ($longest > $maxoffset) {
	    $maxoffset = $longest;
	}
    }

    # Recurse up the download hierarchy
    $maxoffset = $self->determine_description_offset($maxoffset);
    $self->{'option_list'} = \@optionlist;
    return $maxoffset;
}


sub print_plugout_usage
{
    my $self = shift(@_);
    my $descoffset = shift(@_);
    my $isleafclass = shift(@_);

    my $optionlistref = $self->{'option_list'};
    my @optionlist = @$optionlistref;
    my $plugoutoptions = shift(@$optionlistref);
    return if (!defined($plugoutoptions));

    my $plugoutname = $plugoutoptions->{'name'};
    my $plugoutargs = $plugoutoptions->{'args'};
    my $plugoutdesc = $plugoutoptions->{'desc'};

    # Produce the usage information using the data structure above
    if ($isleafclass) {
	if (defined($plugoutdesc)) {
	    gsprintf(STDERR, "$plugoutdesc\n\n");
	}
	gsprintf(STDERR, " {common.usage}: plugout $plugoutname [{common.options}]\n\n");
    }

    # Display the download options, if there are some
    if (defined($plugoutargs)) {
	# Calculate the column offset of the option descriptions
	my $optiondescoffset = $descoffset + 2;  # 2 spaces between options & descriptions

	if ($isleafclass) {
	    gsprintf(STDERR, " {common.specific_options}:\n");
	}
	else {
	    gsprintf(STDERR, " {common.general_options}:\n", $plugoutname);
	}

	# Display the download options
	&PrintUsage::print_options_txt($plugoutargs, $optiondescoffset);
    }

    # Recurse up the download hierarchy
    $self->print_plugout_usage($descoffset, 0);
    $self->{'option_list'} = \@optionlist;
}


sub error
{
      my ($strFunctionName,$strError) = @_;
    {
	print "Error occoured in BasePlugout.pm\n".
	    "In Function: ".$strFunctionName."\n".
	    "Error Message: ".$strError."\n";
	exit(-1);
    }  
}

# OIDtype may be "hash" or "hash_on_full_filename" or "incremental" or "filename" or "dirname" or "full_filename" or "assigned"
sub set_OIDtype {
    my $self = shift (@_);
    my ($type, $metadata) = @_;

    if ($type =~ /^(hash|hash_on_full_filename|incremental|filename|dirname|full_filename|assigned)$/) {
	$self->{'OIDtype'} = $type;
    } else {
	$self->{'OIDtype'} = "hash";
    }
    if ($type =~ /^assigned$/) {
	if (defined $metadata) {
	    $self->{'OIDmetadata'} = $metadata;
	} else {
	    $self->{'OIDmetadata'} = "dc.Identifier";
	}
    }
}

sub set_output_dir 
{
    my $self = shift @_;
    my ($output_dir) = @_;

   $self->{'output_dir'} = $output_dir;
}

sub setoutputdir 
{
    my $self = shift @_;
    my ($output_dir) = @_;

    $self->{'output_dir'} = $output_dir;
}

sub get_output_dir 
{
    my $self = shift (@_);

   return $self->{'output_dir'};
}

sub getoutputdir 
{
    my $self = shift (@_);

    return $self->{'output_dir'};
}

sub getoutputinfo 
{
    my $self = shift (@_);

    return $self->{'output_info'};
}


sub get_output_handler
{
    my $self = shift (@_);

    my ($output_file_name) = @_;

    my $fh;
    &FileUtils::openFileHandle($output_file_name, '>', \$fh) or die('Can not open a file handler for: ' . $output_file_name . "\n");

    return $fh;
}

sub release_output_handler
{
    my $self = shift (@_);
    my ($outhandler) = @_;

    close($outhandler);

}

sub output_xml_header {
    my $self = shift (@_);
    my ($handle,$docroot,$nondoctype) = @_;
    
    
	#print $handle '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' . "\n";
	
	#For Dspace must be UTF in lower case
	print $handle '<?xml version="1.0" encoding="utf-8" standalone="no"?>' . "\n";
   
    if (!defined $nondoctype){
	my $doctype = (defined $docroot) ? $docroot : "Section";

	# Used to be '<!DOCTYPE Archive SYSTEM ...'
	
	print $handle "<!DOCTYPE $doctype SYSTEM \"http://greenstone.org/dtd/Archive/1.0/Archive.dtd\">\n"; 
    }

    print $handle "<$docroot>\n" if defined $docroot;
}

sub output_xml_footer {
    my $self = shift (@_);
    my ($handle,$docroot) = @_;
    print $handle "</$docroot>\n" if defined $docroot;
}


sub output_general_xml_header 
{
    my $self = shift (@_);
    my ($handle,$docroot,$opt_attributes,$opt_dtd, $opt_doctype) = @_;
    
    print $handle '<?xml version="1.0" encoding="utf-8" standalone="no"?>' . "\n";
   
    if (defined $opt_dtd) {
        my $doctype = (defined $opt_doctype) ? $opt_doctype : $docroot;
	print $handle "<!DOCTYPE $doctype SYSTEM \"$opt_dtd\">\n";
    }

    if (defined $docroot) {
        my $full_docroot = $docroot;
        if (defined $opt_attributes) {
          $full_docroot .= " $opt_attributes";
        }

        print $handle "<$full_docroot>\n" 
      }
}

sub output_general_xml_footer 
{
    output_xml_footer(@_);
}

# This is called by the plugins after read_into_doc_obj generates the doc_obj.
sub process {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $output_info = $self->{'output_info'};
    return if (!defined $output_info);

    # for OAI purposes
    $doc_obj->set_lastmodified();
    $doc_obj->set_oailastmodified();

    # find out which directory to save to
    my $doc_dir = "";
    if ($self->is_group()) {
	$doc_dir = $self->get_group_doc_dir($doc_obj);		
    } else {
	$doc_dir = $self->get_doc_dir($doc_obj);
    }
	  
    ##############################
    # call subclass' saveas method
    ##############################
    $self->saveas($doc_obj,$doc_dir);

    # write out data to archiveinf-doc.db
    if ($self->{'generate_databases'}) {
	$self->archiveinf_db($doc_obj); 
    }
    if ($self->is_group()) {
	$self->{'gs_count'}++; # do we want this for all cases?
	$self->{'group_position'}++;
    }
}

sub store_output_info_reference {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $output_info = $self->{'output_info'};
    my $metaname = $self->{'sortmeta'};

    my $group_position;
    if ($self->is_group()) {
	$group_position = $self->{'group_position'};
    }
    if (!defined $metaname || $metaname !~ /\S/) {
	my $OID = $doc_obj->get_OID();
	$output_info->add_info($OID,$self->{'short_doc_file'}, undef, "", $group_position);
	return;
    }
	
    if ($metaname eq "OID") { # sort by OID
	my $OID = $doc_obj->get_OID();
	$output_info->add_info($OID,$self->{'short_doc_file'}, undef, $OID, undef);
	return;
    }
    
    my $metadata = "";
    my $top_section = $doc_obj->get_top_section();
    
    my @commameta_list = split(/,/, $metaname);
    foreach my $cmn (@commameta_list) {
	my $meta = $doc_obj->get_metadata_element($top_section, $cmn);
	if ($meta) {
	    # do remove prefix/suffix - this will apply to all values
	    $meta =~ s/^$self->{'removeprefix'}// if defined $self->{'removeprefix'};	       
	    $meta =~ s/$self->{'removesuffix'}$// if defined $self->{'removesuffix'};
	    $meta = &sorttools::format_metadata_for_sorting($cmn, $meta, $doc_obj);
	    $metadata .= $meta if ($meta);
	}
    }

    # store reference in the output_info     
    $output_info->add_info($doc_obj->get_OID(),$self->{'short_doc_file'}, undef, $metadata,undef);
    
}



sub saveas {
    my $self = shift (@_); 
    my ($doc_obj, $doc_dir) = @_;
   
    die "Basplug::saveas function must be implemented in sub classes\n";
}

sub get_group_doc_dir {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $outhandle = $self->{'output_handle'};
    my $OID = $doc_obj->get_OID(); 
    $OID = "NULL" unless defined $OID;

    my $groupsize = $self->{'group_size'};
    my $gs_count = $self->{'gs_count'};
    my $open_new_file = (($gs_count % $groupsize)==0);

    my $doc_dir;

    if (!$open_new_file && scalar(@{$doc_obj->get_assoc_files()})>0) {
	# if we have some assoc files, then we will need to start a new file
	if ($self->{'verbosity'} > 2) {
	    print $outhandle " Starting a archives folder for $OID as it has associated files\n";
	}
	$open_new_file = 1;
    }
    
    # opening a new file
    if (($open_new_file)  || !defined($self->{'gs_doc_dir'})) {
	# first we close off the old output
	if ($gs_count>0)
	{
	    return if (!$self->close_group_output());
	}

	# this will create the directory
	$doc_dir = $self->get_doc_dir ($doc_obj); 
	$self->{'new_doc_dir'} = 1;
	$self->{'gs_doc_dir'} = $doc_dir;
	$self->{'group_position'} = 1;
    }
    else {
	$doc_dir = $self->{'gs_doc_dir'};
	$self->{'new_doc_dir'} = 0;
    }
    return $doc_dir;

}
sub get_doc_dir {
    
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $OID = $doc_obj->get_OID(); 
    $OID = "NULL" unless defined $OID;

    my $working_dir  = $self->get_output_dir();
    my $working_info = $self->{'output_info'}; 
    return if (!defined $working_info);

    my $doc_info = $working_info->get_info($OID);
    my $doc_dir = '';

    if (defined $doc_info && scalar(@$doc_info) >= 1)
    {
	# This OID already has an archives directory, so use it again
	$doc_dir = $doc_info->[0];
	$doc_dir =~ s/\/?((doc(mets)?)|(dublin_core))\.xml(\.gz)?$//;
    }
    elsif ($self->{'keep_import_structure'})
    {
	my $source_filename = $doc_obj->get_source_filename();
	$source_filename = &File::Basename::dirname($source_filename);
	$source_filename =~ s/[\\\/]+/\//g;
	$source_filename =~ s/\/$//;

      	$doc_dir = substr($source_filename, length($ENV{'GSDLIMPORTDIR'}) + 1);
    }

    # We have to use a new archives directory for this document
    if ($doc_dir eq "")
    {
	$doc_dir = $self->get_new_doc_dir ($working_info, $working_dir, $OID);
    }

    &FileUtils::makeAllDirectories(&FileUtils::filenameConcatenate($working_dir, $doc_dir));

    return $doc_dir;
}


## @function get_new_doc_dir()
#
# Once a doc object is ready to write to disk (and hence has a nice OID),
# generate a unique subdirectory to write the information to.
#
# - create the directory as part of this call, to try and avoid race conditions
#   found in parallel processing [jmt12]
#
# @todo figure out what the rule regarding $work_info->size() is meant to do
#
# @todo determine what $self->{'group'} is, and whether it should affect
#       directory creation
#
sub get_new_doc_dir
{
  my $self = shift (@_);
  my($working_info,$working_dir,$OID) = @_;

  my $doc_dir = "";
  my $doc_dir_rest = $OID;

  # remove any \ and / from the OID
  $doc_dir_rest =~ s/[\\\/]//g;

  # Remove ":" if we are on Windows OS, as otherwise they get confused with the drive letters
  if ($ENV{'GSDLOS'} =~ /^windows$/i)
  {
    $doc_dir_rest =~ s/\://g;
  }

  # we generally create a unique directory by adding consequtive fragments of
  # the document identifier (split by some predefined length - defaulting to
  # 8) until we find a directory that doesn't yet exist. Note that directories
  # that contain a document have a suffix ".dir" (whereas those that contain
  # only subdirectories have no suffix).
  my $doc_dir_num = 0; # how many directories deep we are
  my $created_directory = 0; # have we successfully created a new directory
  do
  {
    # (does this work on windows? - jmt12)
    if ($doc_dir_num > 0)
    {
      $doc_dir .= '/';
    }

    # the default matching pattern grabs the next 'subdir_split_length'
    # characters of the OID to act as the next subdirectory
    my $pattern = '^(.{1,' . $self->{'subdir_split_length'} . '})';

    # Do we count any "HASH" prefix against the split length limit?
    if ($self->{'subdir_hash_prefix'} && $doc_dir_num == 0)
    {
      $pattern = '^((HASH)?.{1,' . $self->{'subdir_split_length'} . '})';
    }

    # Note the use of 's' to both capture the next chuck of OID and to remove
    # it from OID at the same time
    if ($doc_dir_rest =~ s/$pattern//i)
    {
      $doc_dir .= $1;
      $doc_dir_num++;

      my $full_doc_dir = &FileUtils::filenameConcatenate($working_dir, $doc_dir . '.dir');
      if(!FileUtils::directoryExists($full_doc_dir))
      {
        &FileUtils::makeAllDirectories($full_doc_dir);
        $created_directory = 1;
      }

      ###rint STDERR "[DEBUG] BasePlugout::get_new_doc_dir(<working_info>, $working_dir, $oid)\n";
      ###rint STDERR " - create directory: $full_doc_dir => $created_directory\n";
      ###rint STDERR " - rest: $doc_dir_rest\n";
      ###rint STDERR " - working_info->size(): " . $working_info->size() . " [ < 1024 ?]\n";
      ###rint STDERR " - doc_dir_num: " . $doc_dir_num . "\n";
    }
  }
  while ($doc_dir_rest ne '' && ($created_directory == 0 || ($working_info->size() >= 1024 && $doc_dir_num < 2)));

  # not unique yet? Add on an incremental suffix until we are unique
  my $i = 1;
  my $doc_dir_base = $doc_dir;
  while ($created_directory == 0)
  {
    $doc_dir = $doc_dir_base . '-' . $i;
    $created_directory = &FileUtils::makeAllDirectories(&FileUtils::filenameConcatenate($working_dir, $doc_dir . '.dir'));
    $i++;
  }

  # in theory this should never happen
  if (!$created_directory)
  {
    die("Error! Failed to create directory for document: " . $doc_dir_base . "\n");
  }

  return $doc_dir . '.dir';
}
## get_new_doc_dir()


sub process_assoc_files {
    my $self = shift (@_);
    my ($doc_obj, $doc_dir, $handle) = @_;

    my $outhandle = $self->{'output_handle'};
    
    my $output_dir = $self->get_output_dir();
    return if (!defined $output_dir);

    &FileUtils::makeAllDirectories($output_dir) unless &FileUtils::directoryExists($output_dir);
      
    my $working_dir = &FileUtils::filenameConcatenate($output_dir, $doc_dir);
    &FileUtils::makeAllDirectories($working_dir) unless &FileUtils::directoryExists($working_dir);

    my @assoc_files = ();
    my $filename;;

    my $source_filename = $doc_obj->get_source_filename();

    my $collect_dir = $ENV{'GSDLCOLLECTDIR'};

    if (defined $collect_dir) {
	my $dirsep_regexp = &util::get_os_dirsep();

	if ($collect_dir !~ /$dirsep_regexp$/) {
	    $collect_dir .= &util::get_dirsep(); # ensure there is a slash at the end
	}

	# This test is never going to fail on Windows -- is this a problem?
     
	if ($source_filename !~ /^$dirsep_regexp/) {
	    $source_filename = &FileUtils::filenameConcatenate($collect_dir, $source_filename);
	}
    }


    # set the assocfile path (even if we have no assoc files - need this for lucene)
    $doc_obj->set_utf8_metadata_element ($doc_obj->get_top_section(),
					 "assocfilepath",
					 "$doc_dir");
    foreach my $assoc_file_rec (@{$doc_obj->get_assoc_files()}) {
	my ($dir, $afile) = $assoc_file_rec->[1] =~ /^(.*?)([^\/\\]+)$/;
	$dir = "" unless defined $dir;
	    
	my $utf8_real_filename = $assoc_file_rec->[0];

	# for some reasons the image associate file has / before the full path
	$utf8_real_filename =~ s/^\\(.*)/$1/i;

##	my $real_filename = &util::utf8_to_real_filename($utf8_real_filename);
	my $real_filename = $utf8_real_filename;
	$real_filename = &util::downgrade_if_dos_filename($real_filename);

	if (&FileUtils::fileExists($real_filename)) {

	    $filename = &FileUtils::filenameConcatenate($working_dir, $afile);

            &FileUtils::hardLink($real_filename, $filename, $self->{'verbosity'});

	    $doc_obj->add_utf8_metadata ($doc_obj->get_top_section(),
					 "gsdlassocfile",
					 "$afile:$assoc_file_rec->[2]:$dir");
	} elsif ($self->{'verbosity'} > 1) {
	    print $outhandle "BasePlugout::process couldn't copy the associated file " .
		"$real_filename to $afile\n";
	}
    }
}


sub process_metafiles_metadata 
{
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $top_section = $doc_obj->get_top_section();
    my $metafiles = $doc_obj->get_metadata($top_section,"gsdlmetafile");

    foreach my $metafile_pair (@$metafiles) {
	my ($full_metafile,$metafile) = split(/ : /,$metafile_pair);

	$doc_obj->metadata_file($full_metafile,$metafile);
    }

    $doc_obj->delete_metadata($top_section,"gsdlmetafile");
}

sub archiveinf_files_to_field
{
    my $self = shift(@_);
    my ($files,$field,$collect_dir,$oid_files,$reverse_lookups) = @_;

    foreach my $file_rec (@$files) {
	my $real_filename = (ref $file_rec eq "ARRAY") ? $file_rec->[0] : $file_rec;
	my $full_file = (ref $file_rec eq "ARRAY") ? $file_rec->[1] : $file_rec;
	# for some reasons the image associate file has / before the full path
	$real_filename =~ s/^\\(.*)/$1/i;

	my $raw_filename = &util::downgrade_if_dos_filename($real_filename);

	if (&FileUtils::fileExists($raw_filename)) {

#	    if (defined $collect_dir) {
#		my $collect_dir_re_safe = $collect_dir;
#		$collect_dir_re_safe =~ s/\\/\\\\/g; # use &util::filename_to_regex()
#		$collect_dir_re_safe =~ s/\./\\./g;##

#		$real_filename =~ s/^$collect_dir_re_safe//;
#	    }
	    
	    if (defined $reverse_lookups) {
		$reverse_lookups->{$real_filename} = 1;
	    }

	    if($field =~ m@assoc-file|src-file|meta-file@) {
		$raw_filename = &util::abspath_to_placeholders($raw_filename);
	    }

###	    push(@{$oid_files->{$field}},$full_file);	    
	    push(@{$oid_files->{$field}},$raw_filename);
	}
	else {
	    print STDERR "Warning: archiveinf_files_to_field()\n  $real_filename does not appear to be on the file system\n";
	}
    }
}

sub archiveinf_db
{
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $verbosity = $self->{'verbosity'};

    my $collect_dir = $ENV{'GSDLCOLLECTDIR'};
    if (defined $collect_dir) {
	my $dirsep_regexp = &util::get_os_dirsep();

	if ($collect_dir !~ /$dirsep_regexp$/) {
	    # ensure there is a slash at the end
	    $collect_dir .= &util::get_dirsep(); 
	}
    }

    my $oid = $doc_obj->get_OID();
    my $source_filename = $doc_obj->get_unmodified_source_filename();
    my $working_info = $self->{'output_info'}; 
    my $doc_info = $working_info->get_info($oid);

    my ($doc_file,$index_status,$sortmeta, $group_position) = @$doc_info;
    # doc_file is the path to the archive doc.xml. Make sure it has unix 
    # slashes, then if the collection is copied to linux, it can be built without reimport
    $doc_file =~ s/\\/\//g;
    my $oid_files = { 'doc-file' => $doc_file,
		      'index-status' => $index_status,
		      'src-file' => $source_filename,
		      'sort-meta' => $sortmeta,
		      'assoc-file' => [],
		      'meta-file'  => [] };
    if (defined $group_position) {
	$oid_files->{'group-position'} = $group_position;
    }
    my $reverse_lookups = { $source_filename => "1" };


    $self->archiveinf_files_to_field($doc_obj->get_source_assoc_files(),"assoc-file",
				     $collect_dir,$oid_files,$reverse_lookups);


    $self->archiveinf_files_to_field($doc_obj->get_meta_files(),"meta-file",
				     $collect_dir,$oid_files);

    # Get the infodbtype value for this collection from the arcinfo object
    my $infodbtype = $self->{'output_info'}->{'infodbtype'};
    my $output_dir = $self->{'output_dir'};

    my $doc_db = &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $output_dir);

    ##print STDERR "*** To set in db: \n\t$doc_db\n\t$oid\n\t$doc_db_text\n";

    if (!$self->{'no_rss'})
    {
      if (($oid_files->{'index-status'} eq "I") || ($oid_files->{'index-status'} eq "R")) {
	my $top_section = $doc_obj->get_top_section();
	
	# rss_title can be set in collect.cfg as follows: 
	#      plugout GreenstoneXMLPlugout -rss_title "dc.Title; ex.Title"
	# rss_title is a semi-colon or comma-separated list of the metadata field names that should
	# be consulted in order to obtain a Title (anchor text) for the RSS document link.	 
	# If not specified, rss_title will default to dc.Title, and fall back on Untitled
	my $metafieldnames = $self->{'rss_title'};
	my @metafieldarray = split(/[,;] ?/,$metafieldnames); # , or ; separator can be followed by an optional space
	my $titles;
	#@$titles=(); # at worst @$titles will be (), as get_metadata(dc.Titles) may return ()
	foreach my $metafieldname (@metafieldarray) {
	    $metafieldname =~ s@^ex\.@@; # if ex.Title, need to get_metadata() on metafieldname=Title
	    $titles = $doc_obj->get_metadata($top_section,$metafieldname);

	    if(scalar(@$titles) != 0) { # found at least one title for one metafieldname
	       last; # break out of the loop
	    }
	}
	
	# if ex.Title was listed in the metafieldnames, then we'll surely have a value for title for this doc
	# otherwise, if we have no titles at this point, add in a default of Untitled as this doc's title
	if(scalar(@$titles) == 0) { #&& $metafieldnames !~ m@ex.Title@) {
	    push(@$titles, "Untitled");
	}
	
	# encode basic html entities like <>"& in the title(s), since the & char can break RSS links
	for (my $i = 0; $i < scalar(@$titles); $i++) {
	    &ghtml::htmlsafe(@$titles[$i]);
	}

	my $dc_title = join("; ", @$titles);

	if ($oid_files->{'index-status'} eq "R") {
	    $dc_title .= " (Updated)";
	}

        my $rss_entry = "<item>\n";
        $rss_entry   .= "   <title>$dc_title</title>\n";
	if(&util::is_gs3()) {
	    $rss_entry   .= "   <link>_httpdomain__httpcollection_/document/$oid</link>\n";
	} else {
	    $rss_entry   .= "   <link>_httpdomainHtmlsafe__httpcollection_/document/$oid</link>\n";
	}
	$rss_entry   .= "</item>";

        if (defined(&dbutil::supportsRSS) && &dbutil::supportsRSS($infodbtype))
        {
          my $rss_db = &dbutil::get_infodb_file_path($infodbtype, 'rss-items', $output_dir);
          my $rss_db_fh = &dbutil::open_infodb_write_handle($infodbtype, $rss_db, 'append');
          &dbutil::write_infodb_rawentry($infodbtype, $rss_db_fh, $oid, $rss_entry);
          &dbutil::close_infodb_write_handle($infodbtype, $rss_db_fh);
        }
        else
        {
          my $rss_filename = &FileUtils::filenameConcatenate($output_dir,"rss-items.rdf");
          my $rss_fh;
          if (&FileUtils::openFileHandle($rss_filename, '>>', \$rss_fh, "utf8"))
          {
	    print $rss_fh $rss_entry . "\n";
	    &FileUtils::closeFileHandle($rss_filename, \$rss_fh);
          }
          else
          {
	    print STDERR "**** Failed to open $rss_filename\n$!\n";
          }
        }
      }
    }

    $oid_files->{'doc-file'} = [ $oid_files->{'doc-file'} ];
    $oid_files->{'index-status'} = [ $oid_files->{'index-status'} ];
    $oid_files->{'src-file'} = &util::abspath_to_placeholders($oid_files->{'src-file'});
    $oid_files->{'src-file'} = [ $oid_files->{'src-file'} ];
    $oid_files->{'sort-meta'} = [ $oid_files->{'sort-meta'} ];
    if (defined $oid_files->{'group-position'}) {
	$oid_files->{'group-position'} = [ $oid_files->{'group-position'} ];
    }

    my $infodb_file_handle = &dbutil::open_infodb_write_handle($infodbtype, $doc_db, "append");
    &dbutil::write_infodb_entry($infodbtype, $infodb_file_handle, $oid, $oid_files);
    &dbutil::close_infodb_write_handle($infodbtype, $infodb_file_handle);

    foreach my $rl (keys %$reverse_lookups) {
	$working_info->add_reverseinfo($rl,$oid);
    }  

    # meta files not set in reverese entry, but need to set the metadata flag
    if (defined $doc_obj->get_meta_files()) {
	foreach my $meta_file_rec(@{$doc_obj->get_meta_files()}) {
	    my $full_file = (ref $meta_file_rec eq "ARRAY") ? $meta_file_rec->[0] : $meta_file_rec;
	    $working_info->set_meta_file_flag($full_file);
	}
    }
}


sub set_sortmeta {
    my $self = shift (@_);
    my ($sortmeta, $removeprefix, $removesuffix) = @_;
    
    $self->{'sortmeta'} = $sortmeta;
    if (defined ($removeprefix) && $removeprefix ) {
	$removeprefix =~ s/^\^//; # don't need a leading ^
	$self->{'removeprefix'} = $removeprefix;
    }
    if (defined ($removesuffix) && $removesuffix) {
	$removesuffix =~ s/\$$//; # don't need a trailing $
	$self->{'removesuffix'} = $removesuffix;
    }
}



sub open_xslt_pipe
{
    my $self = shift @_;
    my ($output_file_name, $xslt_file)=@_;

    return unless defined $xslt_file and $xslt_file ne "" and &FileUtils::fileExists($xslt_file);
    
    my $java_class_path =  &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin","java","ApplyXSLT.jar");

    my $mapping_file_path = "";

    if ($ENV{'GSDLOS'} eq "windows"){
	$java_class_path .=";".&FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin","java","xalan.jar");
	# this file:/// bit didn't work for me on windows XP
	#$xslt_file = "\"file:///".$xslt_file."\"";
	#$mapping_file_path = "\"file:///";
    }
    else{
	$java_class_path .=":".&FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin","java","xalan.jar");
    }


    $java_class_path = "\"".$java_class_path."\"";

    my $cmd = "| java -cp $java_class_path org.nzdl.gsdl.ApplyXSLT -t \"$xslt_file\" "; 

    if (defined $self->{'mapping_file'} and $self->{'mapping_file'} ne ""){
	my $mapping_file_path = "\"".$self->{'mapping_file'}."\""; 
	$cmd .= "-m $mapping_file_path";
    }
    
    open(*XMLWRITER, $cmd)
	or die "can't open pipe to xslt: $!";

    
    $self->{'xslt_writer'} = *XMLWRITER;

    print XMLWRITER "<?DocStart?>\n";	    
    print XMLWRITER "$output_file_name\n";

 
  }
  

sub close_xslt_pipe
{
  my $self = shift @_;

  
  return unless defined $self->{'xslt_writer'} ;
    
  my $xsltwriter = $self->{'xslt_writer'};
  
  print $xsltwriter "<?DocEnd?>\n";
  close($xsltwriter);

  undef $self->{'xslt_writer'};

}



#the subclass should implement this method if is_group method could return 1.
sub close_group_output{
   my $self = shift (@_);        
}

sub is_group {
    my $self = shift (@_);
    return 0;        
}

my $dc_set = { Title => 1,       
	       Creator => 1, 
	       Subject => 1, 
	       Description => 1, 
	       Publisher => 1, 
	       Contributor => 1, 
	       Date => 1, 
	       Type => 1, 
	       Format => 1, 
	       Identifier => 1, 
	       Source => 1, 
	       Language => 1, 
	       Relation => 1, 
	       Coverage => 1, 
	       Rights => 1};


# returns an XML representation of the dublin core metadata
# if dc meta is not found, try ex meta
# This method is not used by the DSpacePlugout, which has its
# own method to save its dc metadata
sub get_dc_metadata {
    my $self = shift(@_);
    my ($doc_obj, $section, $version) = @_;
    
    # build up string of dublin core metadata
    $section="" unless defined $section;
    
    my $section_ptr = $doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;


    my $explicit_dc = {};
    my $explicit_ex_dc = {};
    my $explicit_ex = {};

    my $all_text="";
    
    # We want high quality dc metadata to go in first, so we store all the
    # assigned dc.* values first. Then, for all those dc metadata names in
    # the official dc set that are as yet unassigned, we look to see whether
    # embedded ex.dc.* metadata has defined some values for them. If not,
    # then for the same missing dc metadata names, we look in ex metadata.

    foreach my $data (@{$section_ptr->{'metadata'}}){
	my $escaped_value = &docprint::escape_text($data->[1]);
	if ($data->[0]=~ m/^dc\./) {
	    $data->[0] =~ tr/[A-Z]/[a-z]/;

	    $data->[0] =~ m/^dc\.(.*)/;
	    my $dc_element =  $1;

	    if (!defined $explicit_dc->{$dc_element}) {
		$explicit_dc->{$dc_element} = [];
	    }
	    push(@{$explicit_dc->{$dc_element}},$escaped_value);

	    if (defined $version && ($version eq "oai_dc")) {
		$all_text .= "   <dc:$dc_element>$escaped_value</dc:$dc_element>\n";
	    }
	    else {
		# qualifier???
		$all_text .= '   <dcvalue element="'. $dc_element.'">'. $escaped_value. "</dcvalue>\n";
	    }

	} elsif ($data->[0]=~ m/^ex\.dc\./) { # now look through ex.dc.* to fill in as yet unassigned fields in dc metaset
	    $data->[0] =~ m/^ex\.dc\.(.*)/;
	    my $ex_dc_element = $1;
	    my $lc_ex_dc_element = lc($ex_dc_element);

	    # only store the ex.dc value for this dc metaname if no dc.* was assigned for it
	    if (defined $dc_set->{$ex_dc_element}) { 
		if (!defined $explicit_ex_dc->{$lc_ex_dc_element}) {
		    $explicit_ex_dc->{$lc_ex_dc_element} = [];
		}
		push(@{$explicit_ex_dc->{$lc_ex_dc_element}},$escaped_value);
	    }
	}
	elsif (($data->[0] =~ m/^ex\./) || ($data->[0] !~ m/\./)) { # look through ex. meta (incl. meta without prefix)
	    $data->[0] =~ m/^(ex\.)?(.*)/;
	    my $ex_element = $2;
	    my $lc_ex_element = lc($ex_element);

	    if (defined $dc_set->{$ex_element}) {
		if (!defined $explicit_ex->{$lc_ex_element}) {
		    $explicit_ex->{$lc_ex_element} = [];
		}
		push(@{$explicit_ex->{$lc_ex_element}},$escaped_value);
	    }
	}
    }

    # go through dc_set and for any element *not* defined in explicit_dc
    # that does exist in explicit_ex, add it in as metadata
    foreach my $k ( keys %$dc_set ) {
	my $lc_k = lc($k);

	if (!defined $explicit_dc->{$lc_k}) {
	    # try to find if ex.dc.* defines this dc.* meta,
	    # if not, then look for whether there's an ex.* equivalent

	    if (defined $explicit_ex_dc->{$lc_k}) {
		foreach my $v (@{$explicit_ex_dc->{$lc_k}}) {
		    my $dc_element    = $lc_k;
		    my $escaped_value = $v;
		    
		    if (defined $version && ($version eq "oai_dc")) {
			$all_text .= "   <dc:$dc_element>$escaped_value</dc:$dc_element>\n";
		    }
		    else {
			$all_text .= '   <dcvalue element="'. $dc_element.'">'. $escaped_value. "</dcvalue>\n";
		    }		    
		}
	    } elsif (defined $explicit_ex->{$lc_k}) {
		foreach my $v (@{$explicit_ex->{$lc_k}}) {
		    my $dc_element    = $lc_k;
		    my $escaped_value = $v;

		    if (defined $version && ($version eq "oai_dc")) {
			$all_text .= "   <dc:$dc_element>$escaped_value</dc:$dc_element>\n";
		    }
		    else {
			$all_text .= '   <dcvalue element="'. $dc_element.'">'. $escaped_value. "</dcvalue>\n";
		    }
		}
	    }
	}
    }

    if ($all_text eq "") {
	$all_text .= "   There is no Dublin Core metatdata in this document\n";
    }	
    $all_text =~ s/[\x00-\x09\x0B\x0C\x0E-\x1F]//g;

    return $all_text;
}

# Build up dublin_core metadata.  Priority given to dc.* over ex.*
# This method was apparently added by Jeffrey and committed by Shaoqun.
# But we don't know why it was added, so not using it anymore.
sub new_get_dc_metadata {
    
    my $self = shift(@_);
    my ($doc_obj, $section, $version) = @_;

    # build up string of dublin core metadata
    $section="" unless defined $section;
    
    my $section_ptr=$doc_obj->_lookup_section($section);
    return "" unless defined $section_ptr;

    my $all_text = "";
    foreach my $data (@{$section_ptr->{'metadata'}}){
	my $escaped_value = &docprint::escape_text($data->[1]);
	my $dc_element =  $data->[0];
	
	my @array = split('\.',$dc_element);
	my ($type,$name);

	if(defined $array[1])
	{
	    $type = $array[0];
	    $name = $array[1];
	}
	else
	{
	    $type = "ex";
	    $name = $array[0];
	}
	
	$all_text .= '   <Metadata Type="'. $type.'" Name="'.$name.'">'. $escaped_value. "</Metadata>\n";
    }
    return $all_text;
}


1;
