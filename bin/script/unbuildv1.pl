#!/usr/bin/perl -w

###########################################################################
#
# unbuildv1.pl --
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

# this program will decompress all the text from a built index
# and return it to gml format - this version of the program is designed to
# work on collections built with the first version of the greenstone software
# it extracts the browse classifications from the gdbm file, and recreates 
# them. It also creates a default collect.cfg file.

# To run, this program needs the old archive directory (called archives),
# the index directory with the text and one other index, not paragraphs!! -
# use one of the section indexes. Also needs the build.cfg file (in the
# index dir) - used in creating a collect.cfg file. If build.cfg is not
# present, the parts of the collect.cfg file relating to indexes will not
# be entered.

# Stefan altered this script slightly August 2002 to use
# $GSDLHOME/bin/$GSDLOS/mgquery_old instead of the old mgquery in
# nzdl-1.2. mgquery_old is a statically linked binary compiled from
# mg-1.3d. It was compiled with SHORT_SUFFIX set so doesn't need the index
# file extensions to be altered. 
# Also changed the command line options a little.

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    $FileHandle = 'FH000';
}

use doc;
use util;
use parsargv;
use FileHandle;
use English;
use cfgread;
use unicode;
use plugout;
select STDERR; $| = 1;
select STDOUT; $| = 1;


# globals
$collection = "";  # the collection name
$index = "";  # the selected index (like stt/unu)
$textdir = ""; # the textdir (like text/unu)
$toplevelinfo = []; #list of document OIDs
%infodb = (); #hash into GDBM file
$classifyinfo = []; # list of classifications
$doc_classif_info = {};  # hash of OIDs->classifications they belong to
$collect_cfg = {}; #data for the configuration file
$mgread = ++$FileHandle;
$mgwrite = ++$FileHandle;

sub print_usage {
    print STDERR "\n  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -verbosity number      0=none, 3=lots\n";
    print STDERR "   -old directory         The directory in which the old collection lives\n";
    print STDERR "   -new directory         The directory in which to put the new collection\n";
}

&main ();

sub main {
    if (!parsargv::parse(\@ARGV, 
			 'verbosity/\d+/2', \$verbosity,
			 'old/.*/', \$old,
			 'new/.*/', \$new)) {
	&print_usage();
	die "\n";
    }

    die "$old does not exist\n\n" unless (-d $old);
    my $old_indexdir = &util::filename_cat($old, "index");
    my $old_archivedir = &util::filename_cat($old, "archives");

    my $new_archivedir = &util::filename_cat($new, "archives");
    my $new_etcdir = &util::filename_cat($new, "etc");
    if (!-e $new_archivedir) {
	&util::mk_all_dir($new_archivedir);
    }
    if (!(-d $new_etcdir)) {
	&util::mk_all_dir($new_etcdir);
    }

    my $gdbmfile = &get_gdbmfile($old_indexdir); # sets $collection and $textdir
    &set_index($old_indexdir);  # sets $index (just chooses one index)

    my $buildcfgfile = &util::filename_cat($old_indexdir, "build.cfg");
    my $colcfgfile = &util::filename_cat($new_etcdir, "collect.cfg");

    # don't need this but giving it a value stops an annoying undefined
    # value warning
    $ENV{'GSDLCOLLECTDIR'} = 'tmp';

    &add_default_cfg();
    &add_index_cfg($buildcfgfile);

    # work out all the classifications from the gdbm file, info for each doc
    # (ie which classifications they belong to, are kept in $doc_classif_info
    &get_classifyinfo($gdbmfile); #puts a list of classifications into classifyinfo
    &get_toplevel_OID($gdbmfile); # puts a list of the top level document OIDs into $toplevelinfo

    # read ldb file into %infodb
    &read_gdbm($gdbmfile);

    #this makes the files specifying the hierarchy of subjects, titles etc
    foreach my $classify (@$classifyinfo) {
	&make_info_file($new_etcdir, $classify);
    }
    
    # write out the collect.cfg
    &output_cfg_file($colcfgfile);

    &openmg($old_indexdir);

    # read the archive information file
    my $archive_info_filename = &util::filename_cat ($new_archivedir, "archives.inf");
    my $archive_info = new arcinfo ();

    my $opts = [];
    push @$opts,("-output_info",$archive_info); 

    $processor = &plugout::load_plugout("GreenstoneXMLPlugout",$opts); 
    $processor->setoutputdir ($new_archivedir);

    my ($doc_obj, $hashref, $children);
    print STDERR "processing documents now\n" if $verbosity >=2;
    foreach $oid (@$toplevelinfo) {
	$value = $infodb{$oid};
	$hashref={};
	$children = [];
	&get_metadata($value, $hashref);
	$doc_obj = new doc ();
	$doc_obj->set_OID($oid);
	my ($olddir) = $hashref->{'archivedir'}; # old dir for this doc, where images are stored
	$top = $doc_obj->get_top_section();
	&add_section_content ($doc_obj, $top, $hashref, $olddir);
	&add_classification_metadata($oid, $doc_obj, $top);
	&add_cover_image($doc_obj, $old_archivedir, $olddir);
	&get_children($hashref, $children);
	&recurse_sections($doc_obj, $children, $oid, $top, $olddir) if (defined ($children));

	#change OID to new format
	$doc_obj->delete_OID();
	$doc_obj->set_OID();
	$processor->process($doc_obj);
#	last;
    }
    print STDERR "\n";
   
    &closemg();

    # write out the archive information file
    $archive_info->save_info($archive_info_filename);
   
    
}

# returns the path to the gdbm info database - also
# sets the $collection and $textdir global variable
sub get_gdbmfile {
    my ($indexdir) = @_;
    my ($gdbmfile);

    opendir (DIR, $indexdir) || die "Couldn't open directory $indexdir\n\n";
    my @conts = readdir DIR;
    close DIR;

    foreach $file (@conts) {
	if ($file =~ /text$/) {
	    $textdir = $file;
	    last;
	}
    }
    die "No text directory found in $indexdir\n\n" 
	unless defined $textdir && $textdir =~ /text$/;

    $gdbmfile = &util::filename_cat ($indexdir, $textdir);

    opendir (DIR, $gdbmfile) || die "Couldn't open directory $gdbmfile\n\n";
    @conts = readdir DIR;
    close DIR;

    foreach my $file (@conts) {
	if ($file =~ /^(.*?)\.(?:ldb|bdb)$/) {
	    $collection = $1;
	    $gdbmfile = &util::filename_cat ($gdbmfile, $file);
	    last;
	}
    }
    
    if (defined $collection && $collection =~ /\w/) {
	$textdir = &util::filename_cat ($textdir, $collection);
    } else {
	die "collection global wasn't set\n";
    }
    return $gdbmfile if (-e $gdbmfile);
    die "Couldn't find gdbm info database in $indexdir\n\n";
}


#this function will probably need to be changed for any different file formats
sub get_toplevel_OID {
    my ($gdbmfile) = @_;

    open (DB2TXT, "db2txt $gdbmfile |") || die "couldn't open pipe to db2txt\n";
    print STDERR "Finding all top level sections from $gdbmfile\n" if $verbosity >= 2;

    $/ = '-' x 70;
    my $entry = "";
    while (defined ($entry = <DB2TXT>)) {
	next unless $entry =~ /\w/;  #ignore blank entries
	$entry =~ s/\n+/\\n/g;  # replace multiple \n with single \n
	my ($key, $value) = $entry =~ /\[([^\]]*)\](.*)/;

	next unless ($key =~ /B\.\d*$/); # assumes top level OID is like
	                                 # B.12

	push( @$toplevelinfo, $key);
   
    }

    $/ = "\n";
}
    
# gets all the metadata from a gdbm file entry, and puts it into a hashref
#this has changed for old style formats
sub get_metadata {

    my ($gdb_str_ref, $hashref) = @_;
#    print STDERR $gdb_str_ref;
    my @entries = split(/\n/, $gdb_str_ref);

    my $hastext = 1;
    foreach $entry (@entries) {
	
	my($key, $value) = ($entry =~ /^<([^>]*)>(.*?)$/ );

	next if ($key eq "p");
	next if ($key eq "j");
	
	$key = "Title" if $key eq "t";
	$key = "docnum" if $key eq "d";	
	if ($key eq "o") {
	    $key = "archivedir";
	    $value =~ s/HASH/hash/;
	}
	if ($key eq "c") {
	    $key = "contains";
	    $hastext=0;}

	$$hashref{$key} .= $value;
						  
    }
    
    $$hashref{'hastxt'} = $hastext;

}					  

# takes a hashref containing the metadata for a gdbmfile entry, and
# extracts the childrens numbers (from the 'contains' entry).  assumes
# format is like B.14.1:B.24.2:B.24.3 returns a list like 1 2 3 4
sub get_children {	
    my ($hashref, $children) = @_; 

    my $childs = $hashref->{'contains'};
    if (defined ($childs)) {
	@xchildren = split /\:/, $childs;
	foreach $kid (@xchildren) {
	    my ($child)= $kid =~ /\.([^\.]*)(?:\\n|$)/;
	    push (@$children, $child);
	}
#	print STDERR "children are: ", @$children;
    }
    else {
	$children = [];
    }
}

#takes a hashref containing the metadata for a gdbmfile entry, and extracts 
#the childrens numbers (from the 'contains' entry).	
#assumes format is like B.14.1:B.24.2:B.24.3
#returns a list with the full child name ie B.14.1 B.14.2 etc
#used for classification stuff
sub get_whole_children {	

    my ($hashref, $children) = @_; 

    my $childs = $hashref->{'contains'};
    if (defined ($childs)) {
	@$children = split /\:/, $childs;
	#print STDERR "children are: ", @$children;
    }
    else {
	$children = [];
    }
}
    
sub recurse_sections {
    my ($doc_obj, $children, $parentoid, $parentsection, $olddir) = @_;

    foreach $child (sort numerically @$children) {
	$doc_obj->create_named_section("$parentsection.$child");
	my $value = $infodb{"$parentoid.$child"};
	my $hashref={};
	&get_metadata($value, $hashref); # get childs metadata
	my $newchildren = [];
	&get_children($hashref, $newchildren); # get childs children
	#add content fo rcurrent section
	&add_section_content($doc_obj, "$parentsection.$child", $hashref, $olddir);
	# process all the children if there are any
	&recurse_sections($doc_obj, $newchildren, "$parentoid.$child", "$parentsection.$child", $olddir)
	    if (defined ($newchildren));
    }
}					     

sub add_section_content {
    my ($doc_obj, $cursection, $hashref, $olddir) = @_;
    
    foreach $key (keys %$hashref) {
	#dont need to store these metadata
	next if $key =~ /(contains|docnum|hastxt|doctype|archivedir|classifytype)/i;
	my @items = split /@/, $hashref->{$key};
	map {$doc_obj->add_metadata ($cursection, $key, $_); } @items;
	
    }

    my ($hastext) = $hashref->{'hastxt'} =~ /(0|1)/;
    if ($hastext) {
	
	my ($docnum)= $hashref->{'docnum'} =~ /(\d*)/;
	my $text = &get_text($docnum);
	$doc_obj->add_text ($cursection, $text);
	
	my (@images) = $text =~ /<img.*?src=\"([^\"]*)\"[^>]*>/g;
	
	if (scalar(@images)>0) {
	    
	    foreach $img (@images) {
		my ($assoc_file) = $img =~ /([^\/\\]*\..*)$/; #the name of the image
		$img =~ s/_httpcollection_/$old/; #replace _httpcollection_ with path to old collection
		$olddir =~ s/HASH/hash/;
		$img =~ s/_thisOID_/$olddir/; #replace _thisOID_ with old archivedir name   #the path to the image
		$img = lc $img; # doc names and path upper case in file, lower
		# case in directory
		if (-e $img) {
		    $doc_obj->associate_file($img, $assoc_file);
		} else {
		    print STDERR "WARNING: $img does not exist\n";
		}
	    }
	    
	}
    }
}


sub add_classification_metadata {

    my ($oid, $doc_obj, $cursection) = @_;
    
    if (defined $doc_classif_info->{$oid}) {

	$hashref = $doc_classif_info->{$oid};
	
	foreach $key (keys %$hashref) {
	    my @items = @{$hashref->{$key}};
	    map {$doc_obj->add_metadata ($cursection, $key, $_); } @items;
	}
    }
}
# picks up the cover image "cover.jpg" from the old archives directory.
sub add_cover_image {
    my ($doc_obj, $archivedir, $olddir) =  @_;
    $assoc_file = "cover.jpg";
    $img = &util::filename_cat($archivedir, $olddir, $assoc_file);

    if (-e $img) {
	$doc_obj->associate_file($img, $assoc_file);
    } else {
	print STDERR "WARNING: couldn't find $img\n";
    }
}

sub set_index {
    my ($indexdir) = @_;

    # check that $collection has been set
    die "collection global was not set\n"
	unless defined $collection && $collection =~ /\w/;

    # find an index (just use first non-text and non-paragraph directory we
    # come across in $indexdir)
    opendir (INDEXDIR, $indexdir) || die "couldn't open directory $indexdir\n";
    my @indexes = readdir INDEXDIR;
    close INDEXDIR;
    foreach $i (@indexes) {
	next if $i =~ /text$/i || $i =~ /\./ || $i =~ /^p/i;
	$index = &util::filename_cat ($i, $collection);
	last;
    }
}


#########################################################################

################ functions involving mg ################################
sub get_text {
    my ($docnum) = @_;

    print STDERR "." if $verbosity >= 2;
    &mgcommand ($docnum);

   <$mgread>;	# eat the document separator

    my $text = "";
    my $line = "";

    while (defined ($line = <$mgread>))
    {
	last if $line =~ /^<\/mg>/;
	$text .= $line;
    }

    # Read in the last statement, which should be:
    #  "dd documents retrieved."
    <$mgread>;

    return $text;
}


sub numerically {$a <=> $b;}



# mg stuff

sub openmg {
    my ($indexdir) = @_;

    die "Unable to start mgquery." unless
	&openpipe($mgread, $mgwrite, "mgquery_old -d $indexdir -f $index -t $textdir");

    $mgwrite->autoflush();
    &mgcommand('.set expert true');
    &mgcommand('.set terminator "</mg>\n"');
    &mgcommand('.set mode text');
    &mgcommand('.set query docnums');
    &mgcommand('.set term_freq off');
}

sub closemg {
    &mgcommand (".quit");
    close($mgread);
    close($mgwrite);
}

sub mgcommand {
    my ($command) = @_;

    return if $command =~ /^\s*$/;  #whitespace
    #print STDERR "command: $command\n";
    print $mgwrite "$command\n";

    # eat up the command executed which is echoed
    <$mgread>;
}

# openpipe(READ, WRITE, CMD)
# 
# Like open2, except CMD's stderr is also redirected.
# 
sub openpipe
{
    my ($read, $write, $cmd) = @_;
    my ($child_read, $child_write);

    $child_read = ++$FileHandle;
    $child_write = ++$FileHandle;

    pipe($read, $child_write) || die "Failed pipe($read, $child_write): $!";
    pipe($child_read, $write) || die "Failed pipe($child_read, $write): $!";
    my $pid;

    if (($pid = fork) < 0) {
        die "Failed fork: $!";
    } elsif ($pid == 0) {
        close($read);
        close($write);
        open(STDIN, "<&$child_read");
        open(STDOUT, ">&$child_write");
        open(STDERR, ">&$child_write");
        exec($cmd);
        die "Failed exec $cmd: $!";
    }

    close($child_read);
    close($child_write);

    $write->autoflush();
    $read->autoflush();

    return 1;
}


######################################################################

############# functions to do with the classificaiton stuff ##########
sub get_classifyinfo {
    my ($gdbmfile) = @_;

    open (DB2TXT, "db2txt $gdbmfile |") || die "couldn't open pipe to db2txt\n";
    print STDERR "Finding all classification sections from $gdbmfile\n" ;

    $/ = '-' x 70;
    my $entry = "";
    while (defined ($entry = <DB2TXT>)) {
	next unless $entry =~ /\w/;  #ignore blank entries
	$entry =~ s/\n+/\\n/g;  # replace multiple \n with single \n
	my ($key, $value) = $entry =~ /\[([^\]]*)\](.*)/;

	next unless ($key =~/^[A-Z]$/); # assumes classification OID is like
	                                 # C or T etc

	push( @$classifyinfo, $key);
   
    }

    $/ = "\n";
}

#this creates the classification files needed for the hierarchy classifier
#used for subjects, titles, orgs etc
#also adds in entries to the collect_cfg hash    
sub make_info_file {
    my ($etcdir, $classifier) = @_;
    my $info_file = "";

    $info_file = &util::filename_cat($etcdir, "CL.${classifier}.txt");
    $classifier_name = "CL.$classifier";
    print STDERR "classification $classifier will be called CL.$classifier\n";

    open (OUTDOC, ">$info_file" ) || die  "couldn't open file $info_file\n";
	
    my $entry = $infodb{$classifier};
    #print STDERR "entry = $entry\n";
    my $hashref = {};
    &get_metadata($entry, $hashref);
    my $children=[];
    &get_whole_children($hashref, $children);
    foreach $child (@$children) {
	&process_entry(OUTDOC, $classifier_name, $child);
    }
  
    close OUTDOC;
    
    &add_classify_cfg($classifier, $classifier_name, $info_file);
    
}


sub process_entry {
    my ($handle, $classifier_name, $classify_id) = @_;

    my $value = $infodb{$classify_id};
    my $hashref={};
    &get_metadata($value, $hashref);
    my $title = $hashref->{'Title'};

    &add_line($handle, $classify_id, $title);
    
    my $children = [];
    &get_whole_children($hashref, $children);
    foreach $child (@$children) {
	if (&is_document($child)) {
	    &add_doc_metadata($child, $classifier_name, $classify_id);
	}
	else {
	    &process_entry($handle, $classifier_name, $child);
	}
    }
}

sub add_doc_metadata {
    my ($doc_id, $classifier_name, $classifier_id) = @_;

    #add entry to doc database
    #print STDERR "at doc level, docnum=$classify_id\n";
    $doc_classif_info->{$doc_id}={} unless defined $doc_classif_info->{$doc_id};
    $doc_classif_info->{$doc_id}->{$classifier_name}=[] unless
	defined $doc_classif_info->{$doc_id}->{$classifier_name};
    push (@{$doc_classif_info->{$doc_id}->{$classifier_name}}, $classifier_id); 
}

sub add_line {
    my ($handle, $classify_id, $title) = @_;
    $title = &unicode::ascii2utf8(\$title);
    my ($num) = $classify_id =~ /^[A-Z]\.(.*)$/; #remove the C. from the front
    print $handle "$classify_id\t$num\t\"$title\"\n";
}

sub is_document {
    my ($oid) = @_;
    return 1 if $oid =~ /^B\.\d/;
    return 0;
}
    
########################################################################

########## stuff for producing collect.cfg file ###########################

sub add_default_cfg {

    $username=`whoami`;
    $username=`logname` unless defined $username;
    $username="a_user" unless defined $username;
    $username =~ s/\n//;
    $collect_cfg->{'creator'}="$username\@cs.waikato.ac.nz";
    $collect_cfg->{'maintainer'}="$username\@cs.waikato.ac.nz";
    $collect_cfg->{'public'}="true";
    
    $collect_cfg->{'plugin'}=[];
    push (@{$collect_cfg->{'plugin'}}, ["GreenstoneXMLPlugin"]);
    push (@{$collect_cfg->{'plugin'}}, ["ArchivesInfPlugin"]);
    push (@{$collect_cfg->{'plugin'}}, ["DirectoryPlugin"]);

    $collect_cfg->{'format'}={};
    $collect_cfg->{'format'}->{'DocumentImages'}="true";
    $collect_cfg->{'format'}->{'DocumentText'} = 
	"\"<h3>[Title]</h3>\\\\n\\\\n<p>[Text]\"";
    $collect_cfg->{'format'}->{'SearchVList'} =
	"\"<td valign=top>[link][icon][/link]</td><td>{If}{[parent(All': '):Title],[parent(All': '):Title]:}[link][Title][/link]</td>\"";

    $collect_cfg->{'collectionmeta'}={};
    $collect_cfg->{'collectionmeta'}->{'collectionname'}="\"$collection\"";
    $collect_cfg->{'collectionmeta'}->{'iconcollection'}="\"_httpprefix_/collect/$collection/images/$collection.gif\"";
    $collect_cfg->{'collectionmeta'}->{'iconcollectionsmall'}="\"_httpprefix_/collect/$collection/images/${collection}sm.gif\"";
    $collect_cfg->{'collectionmeta'}->{'collectionextra'} = "\"This is a collection rebuilt from CDROM.\"";

}

sub add_index_cfg {
  my ($buildfile) = @_;

  my $data={};
  $collect_cfg->{'indexes'}=[];
  if (-e $buildfile) {
      $data=&cfgread::read_cfg_file($buildfile, '^(this)$', '^(indexmap)$'); 
      foreach my $i (@{$data->{'indexmap'}}) {
          my ($thisindex, $abbrev)= split (/\-\>/, $i);
          push (@{$collect_cfg->{'indexes'}}, $thisindex);
	  $collect_cfg->{'defaultindex'} = $thisindex unless defined 
	      $collect_cfg->{'defaultindex'};
          $name=&get_index_name($thisindex);
	  $thisindex=".$thisindex";
          $collect_cfg->{'collectionmeta'}->{$thisindex} = "\"$name\"";
      } 
  }
  else {
      print STDERR "Couldn't read $buildfile, could not add index data to configuration file\n";
  }

}

sub get_index_name {
    my ($thisindex) = @_;
    return "paragraphs" if $thisindex =~ /paragraph/;
    return "chapters" if $thisindex =~ /section.*text/;
    return "titles" if $thisindex =~ /Title/;
    return "other";
}

sub add_classify_cfg {

    my ($classify, $metadata, $file) = @_;
    $collect_cfg->{'classify'} = [] unless defined $collect_cfg->{'classify'};

    my ($title);
    $title = "Howto" if $classify eq 'H';
    $title = "Subject" if $classify eq 'C';
    $title = "Organization" if $classify eq 'O';
    $title = "Title" if $classify eq 'T';
    $title = "Other" unless defined $title;

    my ($filename) = $file =~ /\/([^\/]*)$/;
    my $entry = "Hierarchy -hfile $filename -metadata $metadata -buttonname $title -sort Title";
    $entry .= " -hlist_at_top" if $title eq "Title";
    push (@{$collect_cfg->{'classify'}},[$entry]);
   

}

sub output_cfg_file {

    my ($collfile) = @_;
    &cfgread::write_cfg_file($collfile, $collect_cfg, 
			     '^(creator|maintainer|public|beta|defaultindex)$',
                            '^(indexes)$', '^(format|collectionmeta)$',
                            '^(plugin|classify)$');
}

sub read_gdbm {
    my ($filename) = @_;

    open (PIPEIN, "db2txt \"$filename\" |") || die "couldn't open pipe from db2txt\n";
    my $line = ""; my $key = ""; my $value = "";
    while (defined ($line = <PIPEIN>)) {
	if ($line =~ /^\[([^\]]+)\]$/) {
	    $key = $1;
	} elsif ($line =~ /^-{70}$/) {
	    $infodb{$key} = $value;
	    $value = "";
	    $key = "";
	} else {
	    $value .= $line;
	}
    }
    close PIPEIN;
}
