###########################################################################
#
# doc.pm --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
#
# This program is free software; you can redistr   te it and/or modify
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

# base class to hold documents

package doc;
eval {require bytes};

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/dynamic/lib/site_perl/5.005/i686-linux");
}

use strict;
use unicode;
use util;
use FileUtils;
use ghtml;
use File::stat;
##use hashdoc;
use docprint;

# the document type may be indexed_doc, nonindexed_doc, or
# classification

our $OIDcount = 0;

# rename_method can be 'url', 'none', 'base64'
sub new {
    my $class = shift (@_);
    my ($source_filename, $doc_type, $rename_method) = @_;


    my $self = bless {'associated_files'=>[],
		      'subsection_order'=>[],
		      'next_subsection'=>1,
		      'subsections'=>{},
		      'metadata'=>[],
		      'text'=>"",
		      'OIDtype'=>"hash"}, $class;

    # used to set lastmodified here, but this can screw up the HASH ids, so
    # the docsave processor now calls set_lastmodified

    $self->set_source_path($source_filename);
    
    if (defined $source_filename) {
	$source_filename = &util::filename_within_collection($source_filename);
	print STDERR "****** doc.pm::new(): no file rename method provided\n" unless $rename_method;
	$self->set_source_filename ($source_filename, $rename_method);
    }

    $self->set_doc_type ($doc_type) if defined $doc_type;

    return $self;
}


sub set_source_path
{
    my $self = shift @_;
    my ($source_filename) = @_;

    if (defined $source_filename) {
	# On Windows the source_filename can be in terse DOS format
	# e.g. test~1.txt

	$self->{'terse_source_path'} = $source_filename;

        # Use the FileUtil library methods as they are aware of more special
        # cases such as HDFS [jmt12]
 	if (&FileUtils::fileExists($source_filename))
        {
	    # See if we can do better for Windows with a filename
	    if ($ENV{'GSDLOS'} =~ /^windows$/i) {
		require Win32;
		$self->{'source_path'} = Win32::GetLongPathName($source_filename);
	    }
	    else {
		# For Unix-based systems, there is no difference between the two
		$self->{'source_path'} = $source_filename;
	    }
	}
	else {
	    print STDERR "Warning: In doc::set_source_path(), file\n";
	    print STDERR "           $source_filename\n";
	    print STDERR "         does not exist\n";
	    
	    # (default) Set it to whatever we were given
	    $self->{'source_path'} = $source_filename;
	}	
    }
    else {
	# Previous code for setting source_path allowed for
	# it to be undefined, so continue this practice
	$self->{'terse_source_path'} = undef;
	$self->{'source_path'} = undef;
    }
}


sub get_source_path
{
    my $self = shift @_;

    return $self->{'terse_source_path'};
}

# set lastmodified for OAI purposes, added by GRB, moved by kjdon
sub set_oailastmodified {
    my $self = shift (@_);

    my $source_path = $self->{'terse_source_path'};
   
    if (defined $source_path && (-e $source_path)) {
	my $current_time = time;

	my ($seconds, $minutes, $hours, $day_of_month, $month, $year,
	    $wday, $yday, $isdst) = localtime($current_time);

	my $date_modified = sprintf("%d%02d%02d",1900+$year,$month+1,$day_of_month);

	$self->add_utf8_metadata($self->get_top_section(), "oailastmodified", $current_time);
	$self->add_utf8_metadata($self->get_top_section(), "oailastmodifieddate", $date_modified);
    } 
}

# no longer used for OAI purposes, since lastmodified is not what we want as the
# Datestamp of a document. This doc metadata may be useful for general purposes.
sub set_lastmodified {
    my $self = shift (@_);

    my $source_path = $self->{'terse_source_path'};
   
    if (defined $source_path && (-e $source_path)) {

      	my $file_stat = stat($source_path);
	my $mtime = $file_stat->mtime;
	my ($seconds, $minutes, $hours, $day_of_month, $month, $year,
	    $wday, $yday, $isdst) = localtime($mtime);

	my $date_modified = sprintf("%d%02d%02d",1900+$year,$month+1,$day_of_month);

	$self->add_utf8_metadata($self->get_top_section(), "lastmodified", $mtime);
	$self->add_utf8_metadata($self->get_top_section(), "lastmodifieddate", $date_modified);
    } 
}

# clone the $self object
sub duplicate {
    my $self = shift (@_);

    my $newobj = {};
    
    foreach my $k (keys %$self) {
	$newobj->{$k} = &clone ($self->{$k});
    }

    bless $newobj, ref($self);
    return $newobj;
}

sub clone {
    my ($from) = @_;
    my $type = ref ($from);

    if ($type eq "HASH") {
	my $to = {};
	foreach my $key (keys %$from) {
	    $to->{$key} = &clone ($from->{$key});
	}
	return $to;
    } elsif ($type eq "ARRAY") {
	my $to = [];
	foreach my $v (@$from) {
	    push (@$to, &clone ($v));
	}
	return $to;
    } else {
	return $from;
    }
}

sub set_OIDtype {
    my $self = shift (@_);
    my ($type, $metadata) = @_;

    if (defined $type && $type =~ /^(hash|hash_on_file|hash_on_ga_xml|hash_on_full_filename|incremental|filename|dirname|full_filename|assigned)$/) {
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

# rename_method can be 'url', 'none', 'base64'
sub set_source_filename {
    my $self = shift (@_);
    my ($source_filename, $rename_method) = @_;

    # Since the gsdlsourcefilename element goes into the doc.xml it has 
    # to be utf8. However, it should also *represent* the source filename 
    # (in the import directory) which may not be utf8 at all. 
    # For instance, if this meta element (gsdlsourcefilename) will be used 
    # by other applications that parse doc.xml in order to locate 
    # gsdlsourcefilename. Therefore, the solution is to URLencode or base64 
    # encode the real filename as this is a binary-to-text encoding meaning
    # that the resulting string is ASCII (utf8). Decoding will give the original.
    
#    print STDERR "******URL/base64 encoding the gsdl_source_filename $source_filename ";

    # URLencode just the gsdl_source_filename, not the directory. Then prepend dir 
    $source_filename = $self->encode_filename($source_filename, $rename_method);
#    my ($srcfilename,$dirname,$suffix) 
#	= &File::Basename::fileparse($source_filename, "\\.[^\\.]+\$");
#    print STDERR "-> $srcfilename -> ";
#    $srcfilename = &util::rename_file($srcfilename.$suffix, $rename_method);
#    $source_filename = &FileUtils::filenameConcatenate($dirname, $srcfilename);
#    print STDERR "$source_filename\n";
	
    $self->set_utf8_metadata_element ($self->get_top_section(), 
				 "gsdlsourcefilename", 
				 $source_filename);
}

sub encode_filename {
    my $self = shift (@_);
    my ($source_filename, $rename_method) = @_;

     my ($srcfilename,$dirname,$suffix) 
	= &File::Basename::fileparse($source_filename, "\\.[^\\.]+\$");
#    print STDERR "-> $srcfilename -> ";
    $srcfilename = &util::rename_file($srcfilename.$suffix, $rename_method);
    $source_filename = &FileUtils::filenameConcatenate($dirname, $srcfilename);

    return $source_filename;
}

sub set_converted_filename {
    my $self = shift (@_);
    my ($converted_filename) = @_;

    # we know the converted filename is utf8
    $self->set_utf8_metadata_element ($self->get_top_section(), 
				 "gsdlconvertedfilename", 
				 $converted_filename);
}

# returns the source_filename as it was provided
sub get_unmodified_source_filename {
    my $self = shift (@_);

    return $self->{'terse_source_path'};
}

# returns the source_filename with whatever rename_method was given
sub get_source_filename {
    my $self = shift (@_);

    return $self->get_metadata_element ($self->get_top_section(), "gsdlsourcefilename");
}



# returns converted filename if available else returns source filename
sub get_filename_for_hashing {
    my $self = shift (@_);

    my $filename = $self->get_metadata_element ($self->get_top_section(), "gsdlconvertedfilename");

    if (!defined $filename) {
	my $plugin_name = $self->get_metadata_element ($self->get_top_section(), "Plugin");
	# if NULPlug processed file, then don't give a filename
	if (defined $plugin_name && $plugin_name eq "NULPlug") {
	    $filename = undef;
	} else { # returns the URL encoded source filename!
	    $filename = $self->get_metadata_element ($self->get_top_section(), "gsdlsourcefilename");
	}
    }

    if (!&FileUtils::isFilenameAbsolute($filename)) {
	$filename = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'},$filename);
    }

    return $filename;
}

sub set_doc_type {
    my $self = shift (@_);
    my ($doc_type) = @_;

    $self->set_metadata_element ($self->get_top_section(), 
				 "gsdldoctype", 
				 $doc_type);
}

# returns the gsdldoctype as it was provided
# the default of "indexed_doc" is used if no document
# type was provided
sub get_doc_type {
    my $self = shift (@_);

    my $doc_type = $self->get_metadata_element ($self->get_top_section(), "gsdldoctype");
    return $doc_type if (defined $doc_type);
    return "indexed_doc";
}


# look up the reference to the a particular section
sub _lookup_section {
    my $self = shift (@_);
    my ($section) = @_;

    my ($num);
    my $sectionref = $self;

    while (defined $section && $section ne "") {
	
	($num, $section) = $section =~ /^\.?(\d+)(.*)$/;
	
	$num =~ s/^0+(\d)/$1/ if defined $num ; # remove leading 0s
	
	$section = "" unless defined $section;
	

	if (defined $num && defined $sectionref->{'subsections'}->{$num}) {
	    $sectionref = $sectionref->{'subsections'}->{$num};
	} else {
	    return undef;
	}
    }
    
    return $sectionref;
}

# calculate OID by hashing the contents of the document
sub _calc_OID {
    my $self = shift (@_);
    my ($filename) = @_;


    my $osexe = &util::get_os_exe();

    my $hashfile_exe = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"bin",
					   $ENV{'GSDLOS'},"hashfile$osexe");

    &util::set_gnomelib_env(); # gnomelib_env (particularly lib/libiconv2.dylib) required to run the hashfile executable on Mac Lions
    # The subroutine will set the gnomelib env once for each subshell launched, by first testing if GEXTGNOME is not already set

    # A different way to set the gnomelib env would be to do it more locally: exporting the necessary vars 
    # (specifically DYLD/LD_LIB_PATH) for gnome_lib as part of the command executed. 
    # E.g. $result=`export LD_LIBRARY_PATH=../ext/gnome-lib/darwin/lib; hashfile...`

    my $result = "NULL";

    
    if (-e "$hashfile_exe") {
#	$result = `\"$hashfile_exe\" \"$filename\"`;
#	$result = `hashfile$osexe \"$filename\" 2>&1`;
	$result = `hashfile$osexe \"$filename\"`;

	($result) = $result =~ /:\s*([0-9a-f]+)/i;
    } else {
	print STDERR "doc::_calc_OID $hashfile_exe could not be found\n";
    }
    return "HASH$result";
}

# methods dealing with OID, not groups of them.

# if $OID is not provided one is calculated
sub set_OID {
    my $self = shift (@_);
    my ($OID) = @_;
    
    my $use_hash_oid = 0;
    # if an OID wasn't provided calculate one
    if (!defined $OID) {
	$OID = "NULL";
	if ($self->{'OIDtype'} =~ /^hash/) {
	    $use_hash_oid = 1;
	} elsif ($self->{'OIDtype'} eq "incremental") {
	    $OID = "D" . $OIDcount;
	    $OIDcount ++;
	} elsif ($self->{'OIDtype'} eq "filename") {
	    my $filename = $self->get_source_filename();
	    $OID = &File::Basename::fileparse($filename, qr/\.[^.]*/);
	    $OID = &util::tidy_up_oid($OID);
	} elsif ($self->{'OIDtype'} eq "full_filename") {
	    my $source_filename = $self->get_source_filename();
	    my $dirsep = &util::get_os_dirsep();

	    $source_filename =~ s/^import$dirsep//;
	    $source_filename =~ s/$dirsep/-/g;
	    $source_filename =~ s/\./_/g;

	    $OID = $source_filename;
	    $OID = &util::tidy_up_oid($OID);
	} elsif ($self->{'OIDtype'} eq "dirname") {
	    my $filename = $self->get_source_filename();
	    if (defined($filename)) { # && -e $filename) {
		# get the immediate parent directory
		$OID = &File::Basename::dirname($filename);
		if (defined $OID) {
		    $OID = &File::Basename::basename($OID);
		    $OID = &util::tidy_up_oid($OID);
		} else {
		    print STDERR "Failed to find base for filename ($filename)...generating hash id\n";
		    $use_hash_oid = 1;
		}
	    } else {
		print STDERR "Failed to find a filename, generating hash id\n";
		$use_hash_oid = 1;
	    }    
	    
	} elsif ($self->{'OIDtype'} eq "assigned") {
	    my $identifier = $self->get_metadata_element ($self->get_top_section(), $self->{'OIDmetadata'});
	    if (defined $identifier && $identifier ne "") {
		$OID = $identifier;
		$OID = &util::tidy_up_oid($OID);
	    } else {
		# need a hash id
		print STDERR "no $self->{'OIDmetadata'} metadata found, generating hash id\n";
		$use_hash_oid = 1;
	    }
	    	    
	} else {
	    $use_hash_oid = 1;
	}

	if ($use_hash_oid) {
	    my $hash_on_file = 1; 
	    my $hash_on_ga_xml = 0;

	    if ($self->{'OIDtype'} eq "hash_on_ga_xml") {
		$hash_on_file = 0;
		$hash_on_ga_xml = 1;
	    }

	    if ($self->{'OIDtype'} eq "hash_on_full_filename") {
		$hash_on_file = 0;
		$hash_on_ga_xml = 0;

		my $source_filename = $self->get_source_filename();
		my $dirsep = &util::get_os_dirsep();

		$source_filename =~ s/^import$dirsep//;
		$source_filename =~ s/$dirsep/-/g;
		$source_filename =~ s/\./_/g;
		
		# If the filename is very short then (handled naively)
		# this can cause conjestion in the hash-values
		# computed, leading documents sharing the same leading
		# Hex values in the computed has.
		#
		# The solution taken here is to replace the name of
		# the file name a sufficient number of times (up to
		# the character limit defined in 'rep_limit' and
		# make that the content that is hashed on

		# *** Think twice before changing the following value
		# as it will break backward compatability of computed
		# document HASH values

		my $rep_limit  = 256; 
		my $hash_content = undef;

		if (length($source_filename)<$rep_limit) {
		    my $rep_string = "$source_filename|";
		    my $rs_len = length($rep_string);

		    my $clone_times = int(($rep_limit-1)/$rs_len) +1;
		    
		    $hash_content = substr($rep_string x $clone_times, 0, $rep_limit);
		}
		else {
		    $hash_content = $source_filename;
		}

		my $filename = &util::get_tmp_filename();
		if (!open (OUTFILE, ">:utf8", $filename)) {
		    print STDERR "doc::set_OID could not write to $filename\n";
		} else {
		    print OUTFILE $hash_content;
		    close (OUTFILE);
		}
		$OID = $self->_calc_OID ($filename);

		&FileUtils::removeFiles ($filename);
	    }

	    if ($hash_on_file) {
		# "hash" OID - feed file to hashfile.exe
		my $filename = $self->get_filename_for_hashing();
		
		# -z: don't want to hash on the file if it is zero size
		if (defined($filename) && -e $filename && !-z $filename) {
		    $OID = $self->_calc_OID ($filename);
		} else {
		    $hash_on_ga_xml = 1; # switch to back-up plan, and hash on GA file instead
		}
	    }

	    if ($hash_on_ga_xml) {
		# In addition being asked to explicity calculate the has based on the GA file,
		# can also end up coming into this block is doing 'hash_on_file' but the file
		# itself is of zero bytes (as could be the case with 'doc.nul' file

		my $filename = &util::get_tmp_filename();
		if (!open (OUTFILE, ">:utf8", $filename)) {
		    print STDERR "doc::set_OID could not write to $filename\n";
		} else {
		    my $doc_text = &docprint::get_section_xml($self, $self->get_top_section());
		    print OUTFILE $doc_text;
		    close (OUTFILE);
		}
		$OID = $self->_calc_OID ($filename);
		&FileUtils::removeFiles($filename);
	    }
	}
    }
    $self->set_metadata_element ($self->get_top_section(), "Identifier", $OID);
}

# this uses hashdoc (embedded c thingy) which is faster but still 
# needs a little work to be suffiently stable
sub ___set_OID {
    my $self = shift (@_);
    my ($OID) = @_;

    # if an OID wasn't provided then calculate hash value based on document
    if (!defined $OID) 
    {
	my $hash_text = &docprint::get_section_xml($self, $self->get_top_section());
	my $hash_len = length($hash_text);

        $OID = &hashdoc::buffer($hash_text,$hash_len);
    }

    $self->set_metadata_element ($self->get_top_section(), "Identifier", $OID);
}

# returns the OID for this document
sub get_OID {
    my $self = shift (@_);
    my $OID = $self->get_metadata_element ($self->get_top_section(), "Identifier");
    return $OID if (defined $OID);
    return "NULL";
}

sub delete_OID {
    my $self = shift (@_);
    
    $self->set_metadata_element ($self->get_top_section(), "Identifier", "NULL");
}


# methods for manipulating section names

# returns the name of the top-most section (the top
# level of the document
sub get_top_section {
    my $self = shift (@_);
    
    return "";
}

# returns a section
sub get_parent_section {
    my $self = shift (@_);
    my ($section) = @_;

    $section =~ s/(^|\.)\d+$//;

    return $section;
}

# returns the first child section (or the end child 
# if there isn't any)
sub get_begin_child {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    return "" unless defined $section_ptr;

    if (defined $section_ptr->{'subsection_order'}->[0]) {
	return "$section.$section_ptr->{'subsection_order'}->[0]";
    }

    return $self->get_end_child ($section);
}

# returns the next child of a parent section
sub get_next_child {
    my $self = shift (@_);
    my ($section) = @_;
    
    my $parent_section = $self->get_parent_section($section);
    my $parent_section_ptr = $self->_lookup_section($parent_section);
    return undef unless defined $parent_section_ptr;

    my ($section_num) = $section =~ /(\d+)$/;
    return undef unless defined $section_num;

    my $i = 0;
    my $section_order = $parent_section_ptr->{'subsection_order'};
    while ($i < scalar(@$section_order)) {
	last if $section_order->[$i] eq $section_num;
	$i++;
    }

    $i++; # the next child
    if ($i < scalar(@$section_order)) {
	return $section_order->[$i] if $parent_section eq "";
	return "$parent_section.$section_order->[$i]";
    }

    # no more sections in this level
    return undef;
}

# returns a reference to a list of children
sub get_children {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    return [] unless defined $section_ptr;

    my @children = @{$section_ptr->{'subsection_order'}};

    map {$_ = "$section.$_"; $_ =~ s/^\.+//;} @children;
    return \@children;
}

# returns the child section one past the last one (which
# is coded as "0")
sub get_end_child {
    my $self = shift (@_);
    my ($section) = @_;

    return $section . ".0" unless $section eq "";
    return "0";
}

# returns the next section in book order
sub get_next_section {
    my $self = shift (@_);
    my ($section) = @_;

    return undef unless defined $section;

    my $section_ptr = $self->_lookup_section($section);
    return undef unless defined $section_ptr;

    # first try to find first child
    if (defined $section_ptr->{'subsection_order'}->[0]) {
	return $section_ptr->{'subsection_order'}->[0] if ($section eq "");
	return "$section.$section_ptr->{'subsection_order'}->[0]";
    }

    do {
	# try to find sibling
	my $next_child = $self->get_next_child ($section);
	return $next_child if (defined $next_child);

	# move up one level
	$section = $self->get_parent_section ($section);
    } while $section =~ /\d/;

    return undef;
}

sub is_leaf_section {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    return 1 unless defined $section_ptr;

    return (scalar (@{$section_ptr->{'subsection_order'}}) == 0);
}

# methods for dealing with sections

# returns the name of the inserted section
sub insert_section {
    my $self = shift (@_);
    my ($before_section) = @_;

    # get the child to insert before and its parent section
    my $parent_section = "";
    my $before_child = "0";
    my @before_section = split (/\./, $before_section);
    if (scalar(@before_section) > 0) {
	$before_child = pop (@before_section);
	$parent_section = join (".", @before_section);
    }

    my $parent_section_ptr = $self->_lookup_section($parent_section);
    if (!defined $parent_section_ptr) {
	print STDERR "doc::insert_section couldn't find parent section " .
	    "$parent_section\n";
	return;
    }

    # get the next section number
    my $section_num = $parent_section_ptr->{'next_subsection'}++;

    my $i = 0;
    while ($i < scalar(@{$parent_section_ptr->{'subsection_order'}}) &&
	   $parent_section_ptr->{'subsection_order'}->[$i] ne $before_child) {
	$i++;
    }
    
    # insert the section number into the order list
    splice (@{$parent_section_ptr->{'subsection_order'}}, $i, 0, $section_num);

    # add this section to the parent section
    my $section_ptr = {'subsection_order'=>[],
		       'next_subsection'=>1,
		       'subsections'=>{},
		       'metadata'=>[],
		       'text'=>""};
    $parent_section_ptr->{'subsections'}->{$section_num} = $section_ptr;

    # work out the full section number
    my $section = $parent_section;
    $section .= "." unless $section eq "";
    $section .= $section_num;
    
    return $section;
}

# creates a pre-named section
sub create_named_section {
    my $self = shift (@_);
    my ($mastersection) = @_;

    my ($num);
    my $section = $mastersection;
    my $sectionref = $self;

    while ($section ne "") {
	($num, $section) = $section =~ /^\.?(\d+)(.*)$/;
	$num =~ s/^0+(\d)/$1/; # remove leading 0s
	$section = "" unless defined $section;
	
	if (defined $num) {
	    if (!defined $sectionref->{'subsections'}->{$num}) {
		push (@{$sectionref->{'subsection_order'}}, $num);
		$sectionref->{'subsections'}->{$num} = {'subsection_order'=>[],
							'next_subsection'=>1,
							'subsections'=>{},
							'metadata'=>[],
							'text'=>""};
		if ($num >= $sectionref->{'next_subsection'}) {
		    $sectionref->{'next_subsection'} = $num + 1;
		}
	    }
	    $sectionref = $sectionref->{'subsections'}->{$num};

	} else {
	    print STDERR "doc::create_named_section couldn't create section ";
	    print STDERR "$mastersection\n";
	    last;
	}
    }
}

# returns a reference to a list of subsections
sub list_subsections {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section ($section);
    if (!defined $section_ptr) {
	print STDERR "doc::list_subsections couldn't find section $section\n";
	return [];
    }

    return [@{$section_ptr->{'subsection_order'}}];
}

sub delete_section {
    my $self = shift (@_);
    my ($section) = @_;

#    my $section_ptr = {'subsection_order'=>[],
#		       'next_subsection'=>1,
#		       'subsections'=>{},
#		       'metadata'=>[],
#		       'text'=>""};

    # if this is the top section reset everything
    if ($section eq "") {
	$self->{'subsection_order'} = [];
	$self->{'subsections'} = {};
	$self->{'metadata'} = [];
	$self->{'text'} = "";
	return;
    }

    # find the parent of the section to delete
    my $parent_section = "";
    my $child = "0";
    my @section = split (/\./, $section);
    if (scalar(@section) > 0) {
	$child = pop (@section);
	$parent_section = join (".", @section);
    }

    my $parent_section_ptr = $self->_lookup_section($parent_section);
    if (!defined $parent_section_ptr) {
	print STDERR "doc::delete_section couldn't find parent section " .
	    "$parent_section\n";
	return;
    }

    # remove this section from the subsection_order list
    my $i = 0;
    while ($i < scalar (@{$parent_section_ptr->{'subsection_order'}})) {
	if ($parent_section_ptr->{'subsection_order'}->[$i] eq $child) {
	    splice (@{$parent_section_ptr->{'subsection_order'}}, $i, 1);
	    last;
	}
	$i++;
    }

    # remove this section from the subsection hash
    if (defined ($parent_section_ptr->{'subsections'}->{$child})) {
	undef $parent_section_ptr->{'subsections'}->{$child};
    }
}

#--
# methods for dealing with metadata

# set_metadata_element and get_metadata_element are for metadata
# which should only have one value. add_meta_data and get_metadata
# are for metadata which can have more than one value.

# returns the first metadata value which matches field

# This version of get metadata element works much like the one above,
# except it allows for the namespace portion of a metadata element to
# be ignored, thus if you are searching for dc.Title, the first piece
# of matching metadata ending with the name Title (once any namespace
# is removed) would be returned.
# 28-11-2003 John Thompson
sub get_metadata_element {
    my $self = shift (@_);
    my ($section, $field, $ignore_namespace) = @_;
    my ($data);

    $ignore_namespace = 0 unless defined $ignore_namespace;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::get_metadata_element couldn't find section ", $section, "\n";
	return;
    }

    # Remove any namespace if we are being told to ignore them
    if($ignore_namespace) {
	$field =~ s/^.*\.//; #$field =~ s/^\w*\.//;
    }

    foreach $data (@{$section_ptr->{'metadata'}}) {

	my $data_name = $data->[0];

	# Remove any namespace if we are being told to ignore them
	if($ignore_namespace) {
	    $data_name =~ s/^.*\.//; #$data_name =~ s/^\w*\.//;
	}
	# we always remove ex. (but not any subsequent namespace) - ex. maybe there in doc_obj, but we will never ask for it.
	$data_name =~ s/^ex\.([^.]+)$/$1/; #$data_name =~ s/^ex\.//; 
	
	return $data->[1] if (scalar(@$data) >= 2 && $data_name eq $field);
    }
	
    return undef; # was not found
}

# returns a list of the form [value1, value2, ...]
sub get_metadata {
    my $self = shift (@_);
    my ($section, $field, $ignore_namespace) = @_;
    my ($data);

    $ignore_namespace = 0 unless defined $ignore_namespace;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
        print STDERR "doc::get_metadata couldn't find section ",
	    $section, "\n";
        return;
    }

    # Remove any namespace if we are being told to ignore them
    if($ignore_namespace) {
	$field =~ s/^.*\.//;
    }

    my @metadata = ();
    foreach $data (@{$section_ptr->{'metadata'}}) {

	my $data_name = $data->[0];

	# Remove any namespace if we are being told to ignore them
	if($ignore_namespace) {
	    $data_name =~ s/^.*\.//;
	}	
	# we always remove ex. (but not any subsequent namespace) - ex. maybe there in doc_obj, but we will never ask for it.
	$data_name =~ s/^ex\.([^.]+)$/$1/;

        push (@metadata, $data->[1]) if ($data_name eq $field);
    }

    return \@metadata;
}

sub get_metadata_hashmap {
	my $self = shift (@_);
	my ($section, $opt_namespace) = @_;
	
	my $section_ptr = $self->_lookup_section($section);
	if (!defined $section_ptr) {
            print STDERR "doc::get_metadata couldn't find section ",
            $section, "\n";
            return;
        }

	my $metadata_hashmap = {};
	foreach my $data (@{$section_ptr->{'metadata'}}) {
            my $metaname = $data->[0];
          
            if ((!defined $opt_namespace) || ($metaname =~ m/^$opt_namespace\./)) {
                if (!defined $metadata_hashmap->{$metaname}) {
                    $metadata_hashmap->{$metaname} = [];
                  }
                my $metaval_list = $metadata_hashmap->{$metaname};
                push(@$metaval_list, $data->[1]); 
              }
          }
	
	return $metadata_hashmap;
}

# returns a list of the form [[field,value],[field,value],...]
sub get_all_metadata {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::get_all_metadata couldn't find section ", $section, "\n";
	return;
    }
    
    return $section_ptr->{'metadata'};
}

# $value is optional
sub delete_metadata {
    my $self = shift (@_);
    my ($section, $field, $value) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::delete_metadata couldn't find section ", $section, "$field\n";
	return;
    }

    my $i = 0;
    while ($i < scalar (@{$section_ptr->{'metadata'}})) {
	if (($section_ptr->{'metadata'}->[$i]->[0] eq $field) &&
	    (!defined $value || $section_ptr->{'metadata'}->[$i]->[1] eq $value)) {
	    splice (@{$section_ptr->{'metadata'}}, $i, 1);
	} else {
	    $i++;
	}
    }
}

sub delete_all_metadata {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::delete_all_metadata couldn't find section ", $section, "\n";
	return;
    }
    
    $section_ptr->{'metadata'} = [];
}

sub set_metadata_element {
    my $self = shift (@_);
    my ($section, $field, $value) = @_;

    $self->set_utf8_metadata_element ($section, $field, 
				      &unicode::ascii2utf8(\$value));
}

# set_utf8_metadata_element assumes the text has already been
# converted to the UTF-8 encoding.
sub set_utf8_metadata_element {
    my $self = shift (@_);
    my ($section, $field, $value) = @_;
	
    $self->delete_metadata ($section, $field);
    $self->add_utf8_metadata ($section, $field, $value);
}


# add_metadata assumes the text is in (extended) ascii form. For
# text which has already been converted to the UTF-8 format use
# add_utf8_metadata.
sub add_metadata {
    my $self = shift (@_);
    my ($section, $field, $value) = @_;
	
    $self->add_utf8_metadata ($section, $field,
			      &unicode::ascii2utf8(\$value));
}

sub add_utf8_metadata {
    my $self = shift (@_);
    my ($section, $field, $value) = @_;
	
    #    my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(1);
    #    my ($lcfilename) = ($cfilename =~ m/([^\\\/]*)$/);
    #    print STDERR "** Calling method: $lcfilename:$cline $cpackage->$csubr\n";

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::add_utf8_metadata couldn't find section ", $section, "\n";
	return;
    }
    if (!defined $value) {
	print STDERR "doc::add_utf8_metadata undefined value for $field\n";
	return;
    }
    if (!defined $field) {
	print STDERR "doc::add_utf8_metadata undefined metadata type \n";
	return;
    }
    
    #print STDERR "###$field=$value\n";

    # For now, supress this check.  Given that text data read in is now 
    # Unicode aware, then the following block of code can (ironically enough) 
    # cause our unicode compliant string to be re-encoded (leading to
    # a double-encoded UTF-8 string, which we definitely don't want!).
    

    # double check that the value is utf-8
    #    if (!&unicode::check_is_utf8($value)) {
    #	print STDERR "doc::add_utf8_metadata - warning: '$field''s value $value wasn't utf8.";
    #	&unicode::ensure_utf8(\$value);
    #	print STDERR " Tried converting to utf8: $value\n";
    #    }

	#If the metadata value is either a latitude or a longitude value then we want to save a shortened version for spacial searching purposes
	if ($field =~ m/^(.+\.)?Latitude$/ || $field =~ m/^(.+\.)?Longitude$/)
	{
	        my ($mdprefix,$metaname) = ($field =~ m/(.+)\.(.+)$/);
		if (defined $mdprefix) {
		    # Add in a version of Latitude/Longitude without the metadata namespace prefix to keep Runtime happy
		    push (@{$section_ptr->{'metadata'}}, [$metaname, $value]);
		}

		my $direction;
		if($value =~ m/^-/)
		{
			$direction = ($field eq "Latitude") ? "S" : "W"; 
		}
		else
		{
			$direction = ($field eq "Latitude") ? "N" : "E"; 
		}
		
		my ($beforeDec, $afterDec) = ($value =~ m/^-?([0-9]+)\.([0-9]+)$/);
		if(defined $beforeDec && defined $afterDec)
		{
			my $name = ($field eq "Latitude") ? "LatShort" : "LngShort";
			push (@{$section_ptr->{'metadata'}}, [$name, $beforeDec . $direction]);
			
			for(my $i = 2; $i <= 4; $i++)
			{
				if(length($afterDec) >= $i)
				{
					push (@{$section_ptr->{'metadata'}}, [$name, substr($afterDec, 0, $i)]);
				}
			}
			
			#Only add the metadata if it has not already been added
			my $metaMap = $self->get_metadata_hashmap($section);
		}
	}

    push (@{$section_ptr->{'metadata'}}, [$field, $value]);
}


# methods for dealing with text

# returns the text for a section
sub get_text {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::get_text couldn't find section " .
	    "$section\n";
	return "";
    }

    return $section_ptr->{'text'};
}

# returns the (utf-8 encoded) length of the text for a section
sub get_text_length {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::get_text_length couldn't find section " .
	    "$section\n";
	return 0;
    }

    return length ($section_ptr->{'text'});
}

# returns the total length for all the sections
sub get_total_text_length {
    my $self = shift (@_);

    my $section = $self->get_top_section(); 
    my $length = 0;
    while (defined $section) {
	$length += $self->get_text_length($section);
	$section = $self->get_next_section($section);
    }
    return $length;
}

sub delete_text {
    my $self = shift (@_);
    my ($section) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::delete_text couldn't find section " .
	    "$section\n";
	return;
    }

    $section_ptr->{'text'} = "";
}

# add_text assumes the text is in (extended) ascii form. For
# text which has been already converted to the UTF-8 format
# use add_utf8_text.
sub add_text {
    my $self = shift (@_);
    my ($section, $text) = @_;

    # convert the text to UTF-8 encoded unicode characters
    # and add the text
    $self->add_utf8_text($section, &unicode::ascii2utf8(\$text));
}


# add_utf8_text assumes the text to be added has already
# been converted to the UTF-8 encoding. For ascii text use
# add_text
sub add_utf8_text {
    my $self = shift (@_);
    my ($section, $text) = @_;

    my $section_ptr = $self->_lookup_section($section);
    if (!defined $section_ptr) {
	print STDERR "doc::add_utf8_text couldn't find section " .
	    "$section\n";
	return;
    }

    $section_ptr->{'text'} .= $text;
}

# returns the Source meta, which is the utf8 filename generated.
# Added a separate method here for convenience
sub get_source {
    my $self = shift (@_);
    return $self->get_metadata_element ($self->get_top_section(), "Source");
}

# returns the SourceFile meta, which is the url reference to the URL-encoded
# version of Source (the utf8 filename). Added a separate method here for convenience
sub get_sourcefile {
    my $self = shift (@_);
    return $self->get_metadata_element ($self->get_top_section(), "SourceFile");
}

# Get the actual name of the assocfile, a url-encoded string derived from SourceFile.
# The SourceFile meta is the (escaped) url reference to the url-encoded assocfile.
sub get_assocfile_from_sourcefile {
    my $self = shift (@_);
    
    # get the SourceFile meta, which is a *URL* to a file on the filesystem
    my $top_section = $self->get_top_section();
    my $source_file = $self->get_metadata_element($top_section, "SourceFile");

    # get the actual filename as it exists on the filesystem which this url refers to
    $source_file = &unicode::url_to_filename($source_file); 
    my ($assocfilename) = $source_file =~ /([^\\\/]+)$/;
    return $assocfilename;
}

# methods for dealing with associated files

# a file is associated with a document, NOT a section.
# if section is defined it is noted in the data structure
# only so that files associated from a particular section
# may be removed later (using delete_section_assoc_files)
sub associate_file {
    my $self = shift (@_);
    my ($real_filename, $assoc_filename, $mime_type, $section) = @_;
    $mime_type = &ghtml::guess_mime_type ($real_filename) unless defined $mime_type;

    # remove all associated files with the same name
    $self->delete_assoc_file ($assoc_filename);

    # Too harsh a requirement
    # Definitely get HTML docs, for example, with some missing
    # support files
#    if (!&util::fd_exists($real_filename)) {
#	print STDERR "****** doc::associate_file(): Failed to find the file $real_filename\n";
#	exit -1;
#    }

#    print STDERR "**** is the following a UTF8 rep of *real* filename?\n   $real_filename\n";
#    print STDERR "****##### so, ensure it is before storing?!?!?\n";
##    my $utf8_filename = Encode::encode("utf8",$filename);

    push (@{$self->{'associated_files'}}, 
	  [$real_filename, $assoc_filename, $mime_type, $section]);
}

# returns a list of associated files in the form
#   [[real_filename, assoc_filename, mimetype], ...]
sub get_assoc_files {
    my $self = shift (@_);

    return $self->{'associated_files'};
}

# the following two methods used to keep track of original associated files
# for incremental building. eg a txt file used by an item file does not end
# up as an assoc file for the doc.xml, but it needs to be recorded as a source
# file for incremental build
sub associate_source_file {
    my $self = shift (@_);
    my ($full_filename) = @_;

    push (@{$self->{'source_assoc_files'}}, $full_filename);

}

sub get_source_assoc_files {
    my $self = shift (@_);

    return $self->{'source_assoc_files'};
 

}
sub metadata_file {
    my $self = shift (@_);
    my ($real_filename, $filename) = @_;
    
    push (@{$self->{'metadata_files'}}, 
	  [$real_filename, $filename]);
}

# used for writing out the archiveinf-doc info database, to list all the metadata files
sub get_meta_files {
    my $self = shift (@_);

    return $self->{'metadata_files'};
}

sub delete_section_assoc_files {
    my $self = shift (@_);
    my ($section) = @_;

    my $i=0;
    while ($i < scalar (@{$self->{'associated_files'}})) {
	if (defined $self->{'associated_files'}->[$i]->[3] &&
	    $self->{'associated_files'}->[$i]->[3] eq $section) {
	    splice (@{$self->{'associated_files'}}, $i, 1);
	} else {
	    $i++;
	}
    }
}

sub delete_assoc_file {
    my $self = shift (@_);
    my ($assoc_filename) = @_;

    my $i=0;
    while ($i < scalar (@{$self->{'associated_files'}})) {
	if ($self->{'associated_files'}->[$i]->[1] eq $assoc_filename) {
	    splice (@{$self->{'associated_files'}}, $i, 1);
	} else {
	    $i++;
	}
    }
}

sub reset_nextsection_ptr {
    my $self = shift (@_);
    my ($section) = @_;
    
    my $section_ptr = $self->_lookup_section($section);
    $section_ptr->{'next_subsection'} = 1;
}

1;
