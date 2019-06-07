###########################################################################
#
# BaseImporter.pm -- base class for all the import plugins
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2005 New Zealand Digital Library Project
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

package BaseImporter;

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use File::Basename;
use Encode;
use Unicode::Normalize 'normalize';

use encodings;
use unicode;
use doc;
use ghtml;
use gsprintf 'gsprintf';
use util;
use FileUtils;

use CommonUtil;

BEGIN {
    @BaseImporter::ISA = ( 'CommonUtil' );
}

# the different methods that can be applied when renaming
# imported documents and their associated files
our $file_rename_method_list = 
    [ { 'name' => "url",
	'desc' => "{BaseImporter.rename_method.url}" },
      { 'name' => "base64",
	'desc' => "{BaseImporter.rename_method.base64}" }, 
      { 'name' => "none",
	'desc' => "{BaseImporter.rename_method.none}", 
	'hiddengli' => "yes" } ];

# here went encoding list stuff

our $oidtype_list = 
    [ { 'name' => "auto",
	'desc' => "{BaseImporter.OIDtype.auto}" },
      { 'name' => "hash",
        'desc' => "{import.OIDtype.hash}" },
      { 'name' => "hash_on_ga_xml",
        'desc' => "{import.OIDtype.hash_on_ga_xml}" },
      { 'name' => "hash_on_full_filename",
        'desc' => "{import.OIDtype.hash_on_full_filename}" },
      { 'name' => "assigned",
        'desc' => "{import.OIDtype.assigned}" },
      { 'name' => "incremental",
        'desc' => "{import.OIDtype.incremental}" },
      { 'name' => "filename",
        'desc' => "{import.OIDtype.filename}" },
      { 'name' => "dirname",
        'desc' => "{import.OIDtype.dirname}" },
      { 'name' => "full_filename",
        'desc' => "{import.OIDtype.full_filename}" } ];

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" },
     { 'name' => "store_original_file",
	'desc' => "{BaseImporter.store_original_file}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "associate_ext",
	'desc' => "{BaseImporter.associate_ext}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "associate_tail_re",
	'desc' => "{BaseImporter.associate_tail_re}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "OIDtype",
	'desc' => "{import.OIDtype}",
	'type' => "enum",
	'list' => $oidtype_list,
	# leave default empty so we can tell if its been set or not - if not set will use option from import.pl
	'deft' => "auto",
	'reqd' => "no" },
      { 'name' => "OIDmetadata",
	'desc' => "{import.OIDmetadata}",
	'type' => "metadata",
	'deft' => "dc.Identifier",
	'reqd' => "no" },      
#      { 'name' => "use_as_doc_identifier",
#	'desc' => "{BaseImporter.use_as_doc_identifier}",
#	'type' => "string",
#	'reqd' => "no" ,
#	'deft' => "" } ,
      { 'name' => "no_cover_image",
	'desc' => "{BaseImporter.no_cover_image}",
	'type' => "flag",
	'reqd' => "no" },
     { 'name' => "file_rename_method",
	'desc' => "{BaseImporter.file_rename_method}",
	'type' => "enum",
	'deft' => &get_default_file_rename_method(), # by default rename imported files and assoc files using this encoding
	'list' => $file_rename_method_list,
	'reqd' => "no"
	}
      
      ];


my $options = { 'name'     => "BaseImporter",
		'desc'     => "{BaseImporter.desc}",
		'abstract' => "yes",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {

    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists,$auxiliary) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new CommonUtil($pluginlist, $inputargs, $hashArgOptLists,$auxiliary);
    
    if ($self->{'info_only'}) {
        # don't worry about any options etc
        return bless $self, $class;
    }

    my $plugin_name = (defined $pluginlist->[0]) ? $pluginlist->[0] : $class;
    $self->{'plugin_type'} = $plugin_name;

    # remove ex. from OIDmetadata iff it's the only namespace prefix
    $self->{'OIDmetadata'} =~ s/^ex\.([^.]+)$/$1/ if defined $self->{'OIDmetadata'};
    $self->{'num_processed'} = 0;
    $self->{'num_not_processed'} = 0;
    $self->{'num_blocked'} = 0;
    $self->{'num_archives'} = 0;
    $self->{'cover_image'} = 1; # cover image is on by default
    $self->{'cover_image'} = 0 if ($self->{'no_cover_image'});
    $self->{'can_process_directories'} = 0;
    #$self->{'option_list'} = $hashArgOptLists->{"OptList"};
    
    my $associate_ext = $self->{'associate_ext'};
    if ((defined $associate_ext) && ($associate_ext ne "")) {

	my $associate_tail_re = $self->{'associate_tail_re'};
	if ((defined $associate_tail_re) && ($associate_tail_re ne "")) {
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "Warning: can only specify 'associate_ext' or 'associate_tail_re'\n";
	    print $outhandle "         defaulting to 'associate_tail_re'\n";
	}
	else {
	    my @exts = split(/,/,$associate_ext);

	    my @exts_bracketed = map { $_ = "(?:\\.$_)" } @exts;
	    my $associate_tail_re = join("|",@exts_bracketed);
	    $self->{'associate_tail_re'} = $associate_tail_re;
	}

	delete $self->{'associate_ext'};
    }

    return bless $self, $class;

}

sub merge_inheritance
{
    my $self = {};
    my @child_selfs = @_;

    foreach my $child_self (@child_selfs) {	
	foreach my $key (keys %$child_self) {
	    if (defined $self->{$key}) {
		if ($self->{$key} ne $child_self->{$key}) {
#		    print STDERR "Warning: Conflicting value in multiple inheritance for '$key'\n";
#		    print STDERR "Existing stored value = $self->{$key}\n";
#		    print STDERR "New (child) value     = $child_self->{$key}\n";
#		    print STDERR "Keeping existing value\n";
		    # Existing value seems to be option specified in collect.cfg

		    ### $self->{$key} = $child_self->{$key};
		    
		}
		else {
##		    print STDERR "****Info: Value $self->{$key} for $key already defined through multiple inheritance as the same value\n";
		}

	    }
	    else {
		$self->{$key} = $child_self->{$key};
	    }
	}
    }

    return $self;	
}

# initialize BaseImporter options
# if init() is overridden in a sub-class, remember to call BaseImporter::init()
sub init {
    my $self = shift (@_);
    my ($verbosity, $outhandle, $failhandle) = @_;
    
    $self->SUPER::init(@_);
    
    # set process_exp and block_exp to defaults unless they were
    # explicitly set

    if ((!$self->is_recursive()) and 
	(!defined $self->{'process_exp'}) || ($self->{'process_exp'} eq "")) {

	$self->{'process_exp'} = $self->get_default_process_exp ();
	if ($self->{'process_exp'} eq "") {
	    warn ref($self) . " Warning: Non-recursive plugin has no process_exp\n";
	}
    }

    if ((!defined $self->{'block_exp'}) || ($self->{'block_exp'} eq "")) {
	$self->{'block_exp'} = $self->get_default_block_exp ();
    }

}

sub begin {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;

    if ($self->{'OIDtype'} eq "auto") {
	# hasn't been set in the plugin, use the processor values
	$self->{'OIDtype'} = $processor->{'OIDtype'};
	$self->{'OIDmetadata'} = $processor->{'OIDmetadata'};
    }
    if ($self->{'OIDtype'} eq "hash") {
	# should we hash on the file or on the doc xml??
	$self->{'OIDtype'} = $self->get_oid_hash_type();
	if ($self->{'OIDtype'} !~ /^(hash_on_file|hash_on_ga_xml)$/) {
	    $self->{'OIDtype'} = "hash_on_file";
	}
    }
}

# This is called once if removeold is set with import.pl. Most plugins will do
# nothing but if a plugin does any stuff outside of creating doc obj, then 
# it may need to clear something.
sub remove_all {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $processor, $maxdocs) = @_;
}

# This is called per document for docs that have been deleted from the 
# collection. Most plugins will do nothing
# but if a plugin does any stuff outside of creating doc obj, then it may need
# to clear something.
sub remove_one {
    my $self = shift (@_);
    
    my ($file, $oids, $archivedir) = @_;
    return 0 if $self->can_process_this_file($file);
    return undef;
}

sub end {
    # potentially called at the end of each plugin pass 
    # import.pl only has one plugin pass, but buildcol.pl has multiple ones

    my ($self) = shift (@_);
}

sub deinit {
    # called only once, after all plugin passes have been done

    my ($self) = @_;
}

# default hashing type is to hash on the original file (or converted file)
# override this to return hash_on_ga_xml for filetypes where hashing on the 
# file is no good eg video
sub get_oid_hash_type {

    my $self = shift (@_);

    return "hash_on_file";
}


# this function should be overridden to return 1
# in recursive plugins
sub is_recursive {
    my $self = shift (@_);

    return 0; 
}

sub get_default_block_exp {
    my $self = shift (@_);

    return "";
}

sub get_default_process_exp {
    my $self = shift (@_);

    return "";
}


# rename imported files and assoc files using URL encoding by default
# as this will work for most plugins and give more legible filenames
sub get_default_file_rename_method() {
    my $self = shift (@_);
    return "url";
}

# returns this plugin's active (possibly user-selected) file_rename_method
sub get_file_rename_method() {
    my $self = shift (@_);
    my $rename_method = $self->{'file_rename_method'};
    if($rename_method) {
	return $rename_method;
    } else {	
	return $self->get_default_file_rename_method();
    }
}

# default implementation is to do nothing
sub store_block_files {
    
    my $self =shift (@_);
    my ($filename_full_path, $block_hash) = @_;

}

# put files to block into hash 
sub use_block_expressions {

    my $self =shift (@_);
    my ($filename_full_path, $block_hash) = @_;

    $filename_full_path = &util::upgrade_if_dos_filename($filename_full_path);

    if ($self->{'block_exp'} ne "" && $filename_full_path =~ /$self->{'block_exp'}/) {
	$self->block_filename($block_hash,$filename_full_path);
    }

}

#default implementation is to block a file with same name as this, but extension jpg or JPG, if cover_images is on.
sub block_cover_image
{
    my $self =shift;
    my ($filename, $block_hash) = @_;

    $filename = &util::upgrade_if_dos_filename($filename);

    if ($self->{'cover_image'}) {
	my $coverfile = $filename;
	$coverfile =~ s/\.[^\\\/\.]+$/\.jpg/;

	#if there is no file extension, coverfile will be the same as filename
	return if $coverfile eq $filename;
	
	if (!&FileUtils::fileExists($coverfile)) {
	    $coverfile =~ s/jpg$/JPG/;
	} 	
	if (&FileUtils::fileExists($coverfile)) {
	    $self->block_filename($block_hash,$coverfile);
	} 
    }

    return;
}


# discover all the files that should be blocked by this plugin
# check the args ...
sub file_block_read {

    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $gli) = @_;
    # Keep track of filenames with same root but different extensions
    # Used to support -associate_ext and the more generalised
    # -associate_tail_re
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    if (!-d $filename_full_path) {
	$block_hash->{'all_files'}->{$file} = 1;
    }

    my $associate_tail_re = $self->{'associate_tail_re'};
    if ((defined $associate_tail_re) && ($associate_tail_re ne "")) {
	my ($file_prefix,$file_ext) 
	    = &util::get_prefix_and_tail_by_regex($filename_full_path,$associate_tail_re);
	if ((defined $file_prefix) && (defined $file_ext)) {
	    my $shared_fileroot = $block_hash->{'shared_fileroot'};
	    if (!defined $shared_fileroot->{$file_prefix}) {
		my $file_prefix_rec = { 'tie_to'  => undef, 
				        'exts'    => {} };
		$shared_fileroot->{$file_prefix} = $file_prefix_rec;
	    }
	    
	    my $file_prefix_rec = $shared_fileroot->{$file_prefix};

	    if ($self->can_process_this_file($filename_full_path) && $file_ext !~ m/.\./) {
		# This is the document the others should be tied to
		$file_prefix_rec->{'tie_to'} = $file_ext;
	    }
	    else {
		if ($file_ext =~ m/$associate_tail_re$/) {
		    # this file should be associated to the main one
		    $file_prefix_rec->{'exts'}->{$file_ext} = 1;
		}
	    }

	}
    }

    # check block expressions
    $self->use_block_expressions($filename_full_path, $block_hash) unless $self->{'no_blocking'};

    # now check whether we are actually processing this
    if (!-f $filename_full_path || !$self->can_process_this_file($filename_full_path)) {
	return undef; # can't recognise
    }
    
    # if we have a block_exp, then this overrides the normal 'smart' blocking
    $self->store_block_files($filename_full_path, $block_hash) unless ($self->{'no_blocking'} || $self->{'block_exp'} ne "");

    # block the cover image if there is one
    if ($self->{'cover_image'}) {
	$self->block_cover_image($filename_full_path, $block_hash); 
    }
    
    return 1;
}

# plugins that rely on more than process_exp (eg XML plugins) can override this method
sub can_process_this_file {
    my $self = shift(@_);
    my ($filename) = @_;

    if (-d $filename && !$self->{'can_process_directories'}) {
	return 0;
    }

    if ($self->{'process_exp'} ne "" && $filename =~ /$self->{'process_exp'}/) {
	return 1;
    }
    return 0;
    
}

# Even if a plugin can extract metadata in its metadata_read pass,
# make the default return 'undef' so processing of the file continues
# down the pipeline, so other plugins can also have the opportunity to
# locate metadata and set it up in the extrametakeys variables that
# are passed around.

sub can_process_this_file_for_metadata {
    my $self = shift(@_);

    return undef;
}



# Notionally written to be called once for each document, it is however safe to
# call multiple times (as in the case of ImagePlugin) which calls this later on
# after the original image has potentially been converted to a *new* source image
# format (e.g. TIFF to PNG)

sub set_Source_metadata {
    my $self = shift (@_);  
    my ($doc_obj, $raw_filename, $filename_encoding, $section) = @_;
    
    # 1. Sets the filename (Source) for display encoded as Unicode if possible,
    #    and (as a fallback) using %xx if not for non-ascii chars
    # 2. Sets the url ref (SourceFile) to the URL encoded version
    #    of filename for generated files
    
    my ($unused_full_rf, $raw_file) = &util::get_full_filenames("", $raw_filename);

    my $this_section = (defined $section)? $section : $doc_obj->get_top_section();

    my $octet_file = $raw_file;

    # UTF-8 version of filename
#    if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
#	print STDERR "**** Setting Source Metadata given: $octet_file\n";
#    }
    
    # Deal with (on Windows) raw filenames that are in their
    # abbreviated DOS form

    if (($ENV{'GSDLOS'} =~ m/^windows$/i) && ($^O ne "cygwin")) {
	if ((defined $filename_encoding) && ($filename_encoding eq "unicode")) {
	    if (-e $raw_filename) {
		my $unicode_filename = Win32::GetLongPathName($raw_filename);
		
		my $unused_full_uf;
		($unused_full_uf, $octet_file) = &util::get_full_filenames("", $unicode_filename);
	    }
	}
    }

    my $url_encoded_filename;
    if ((defined $filename_encoding) && ($filename_encoding ne "ascii")) {
	# => Generate a pretty print version of filename that is mapped to Unicode
	
	# Use filename_encoding to map raw filename to a Perl unicode-aware string 
	$url_encoded_filename = decode($filename_encoding,$octet_file);		
    }
    else {
	# otherwise generate %xx encoded version of filename for char > 127
	$url_encoded_filename = &unicode::raw_filename_to_url_encoded($octet_file);
    }
    
#    if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
#	print STDERR "****** saving Source as:             $url_encoded_filename\n";
#    }

    # In the case of converted files and (generalized) exploded documents, there
    # will already be a source filename => store as OrigSource before overriding
    my $orig_source = $doc_obj->get_metadata_element ($this_section, "Source");
    if ((defined $orig_source) && ($orig_source !~ m/^\s*$/)) {
	$doc_obj->set_utf8_metadata_element($this_section, "OrigSource", $orig_source); 
    }
        
    # Source is the UTF8 display name - not necessarily the name of the file on the system
    if ($ENV{'GSDLOS'} =~ m/^darwin$/i) {
	# on Darwin want all display strings to be in composed form, then can search on that
	$url_encoded_filename = normalize('C', $url_encoded_filename); # Normalisation Form 'C' (composition)
    }
    # set_utf8_metadata actually sets perl unicode aware strings. not utf8
    $doc_obj->set_utf8_metadata_element($this_section, "Source", $url_encoded_filename); 

    
    my $renamed_raw_file = &util::rename_file($raw_file, $self->{'file_rename_method'});
    # If using URL encoding, then SourceFile is the url-reference to url-encoded
    # renamed_raw_url: it's a url that refers to the actual file on the system
    # this call just replaces % with %25
    my $renamed_raw_url = &unicode::filename_to_url($renamed_raw_file);

    $doc_obj->set_utf8_metadata_element($this_section, "SourceFile",
					$renamed_raw_url);

#    if ((defined $ENV{"DEBUG_UNICODE"}) && ($ENV{"DEBUG_UNICODE"})) {
#	print STDERR "****** saving SourceFile as:         $renamed_raw_url\n";
#    }
}

# this should be called by all plugins to set the oid of the doc obj, rather
# than calling doc_obj->set_OID directly
sub add_OID {
    my $self = shift (@_);  
    my ($doc_obj, $force) = @_;

    # don't add one if there is one already set, unless we are forced to do so
    return unless ($doc_obj->get_OID() =~ /^NULL$/ || $force);
    $doc_obj->set_OIDtype($self->{'OIDtype'}, $self->{'OIDmetadata'});

    # see if there is a plugin specific set_OID function
    if (defined ($self->can('set_OID'))) {
	$self->set_OID(@_); # pass through doc_obj and any extra arguments
    }
    else {
	# use the default set_OID() in doc.pm
	$doc_obj->set_OID();
    }

}

# The BaseImporter read_into_doc_obj() function. This function does all the
# right things to make general options work for a given plugin.  It doesn't do anything with the file other than setting reads in
# a file and sets up a slew of metadata all saved in doc_obj, which
# it then returns as part of a tuple (process_status,doc_obj)
#
# Much of this functionality used to reside in read, but it was broken
# down into a supporting routine to make the code more flexible.  
#
# recursive plugins (e.g. RecPlug) and specialized plugins like those
# capable of processing many documents within a single file (e.g.
# GMLPlug) will normally want to implement their own version of
# read_into_doc_obj()
#
# Note that $base_dir might be "" and that $file might 
# include directories

# currently blocking has been done before it gets here - does this affect secondary plugin stuff??
sub read_into_doc_obj {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    my $outhandle = $self->{'outhandle'};

    # should we move this to read? What about secondary plugins?
    my $pp_file = &util::prettyprint_file($base_dir,$file,$gli);
    print STDERR "<Processing n='$file' p='$self->{'plugin_type'}'>\n" if ($gli);
    print $outhandle "$self->{'plugin_type'} processing $pp_file\n"
	if $self->{'verbosity'} > 1;

    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    
    # create a new document
    my $doc_obj = new doc ($filename_full_path, "indexed_doc", $self->{'file_rename_method'});
    my $top_section = $doc_obj->get_top_section();

    $doc_obj->add_utf8_metadata($top_section, "Plugin", "$self->{'plugin_type'}");
    $doc_obj->add_utf8_metadata($top_section, "FileSize", (-s $filename_full_path));
    

    my $plugin_filename_encoding = $self->{'filename_encoding'};
    my $filename_encoding = $self->deduce_filename_encoding($file,$metadata,$plugin_filename_encoding);
    $self->set_Source_metadata($doc_obj,$filename_full_path,$filename_encoding,$top_section);

    # plugin specific stuff - what args do we need here??
    unless (defined ($self->process($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli))) {
	print STDERR "<ProcessingError n='$file'>\n" if ($gli);
	return -1;
    }
    
    # include any metadata passed in from previous plugins 
    # note that this metadata is associated with the top level section
    my $section = $doc_obj->get_top_section();
    # can we merge these two methods??
    $self->add_associated_files($doc_obj, $filename_full_path);
    $self->extra_metadata ($doc_obj, $section, $metadata);
    $self->auto_extract_metadata($doc_obj);

    # if we haven't found any Title so far, assign one
    # this was shifted to here from inside read()
    $self->title_fallback($doc_obj,$section,$filename_no_path);
    
    $self->add_OID($doc_obj);
    
    $self->post_process_doc_obj($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli);
    return (1,$doc_obj);
}

sub post_process_doc_obj {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    return 1;
}

sub add_dummy_text {
    my $self = shift(@_);
    my ($doc_obj, $section) = @_;

    # add NoText metadata so we can hide this dummy text in format statements
    $doc_obj->add_metadata($section, "NoText", "1");

    # lookup_string with extra '1' arg returns perl internal unicode aware text, so we use add_utf8_text so no encoding is done on it.
    $doc_obj->add_utf8_text($section, &gsprintf::lookup_string("{BaseImporter.dummy_text}",1));
    #$doc_obj->add_text($section, &gsprintf::lookup_string("{BaseImporter.dummy_text}",1));
    
    
}

# does nothing. Can be overridden by subclass
sub auto_extract_metadata {
    my $self = shift(@_);
    my ($doc_obj) = @_;
}

# adds cover image, associate_file options stuff. Should be called by sub class
# read_into_doc_obj
sub add_associated_files {
    my $self = shift(@_);
    # whatis filename??
    my ($doc_obj, $filename) = @_;
    
    # add in the cover image
    if ($self->{'cover_image'}) {
	$self->associate_cover_image($doc_obj, $filename);
    }
    # store the original (used for eg TextPlugin to store the original for OAI)
    if ($self->{'store_original_file'}) {
	$self->associate_source_file($doc_obj, $filename);
    }
    

}

# implement this if you are extracting metadata for other documents
sub metadata_read {
    my $self = shift (@_);
    my ($pluginfo, $base_dir, $file, $block_hash, 
	$extrametakeys, $extrametadata, $extrametafile,
	$processor, $gli, $aux) = @_;
    
    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);
    return undef unless $self->can_process_this_file_for_metadata($filename_full_path);

    return 1; # we recognise the file, but don't actually do anything with it
}


# The BaseImporter read() function. This function calls read_into_doc_obj()
# to ensure all the right things to make general options work for a
# given plugin are done. It then calls the process() function which
# does all the work specific to a plugin (like the old read functions
# used to do). Most plugins should define their own process() function
# and let this read() function keep control.  
#
# recursive plugins (e.g. RecPlug) and specialized plugins like those
# capable of processing many documents within a single file (e.g.
# GMLPlug) might want to implement their own version of read(), but
# more likely need to implement their own version of read_into_doc_obj()
#
# Return number of files processed, undef if can't recognise, -1 if can't
# process

sub read {
    my $self = shift (@_);  
    my ($pluginfo, $base_dir, $file, $block_hash, $metadata, $processor, $maxdocs, $total_count, $gli) = @_;

    # can we process this file??
    my ($filename_full_path, $filename_no_path) = &util::get_full_filenames($base_dir, $file);

    return undef unless $self->can_process_this_file($filename_full_path);
    
	#print STDERR "**** BEFORE READ INTO DOC OBJ: $file\n";
    my ($process_status,$doc_obj) = $self->read_into_doc_obj(@_);
    #print STDERR "**** AFTER READ INTO DOC OBJ: $file\n";
	
    if ((defined $process_status) && ($process_status == 1)) {
	
	# process the document
	$processor->process($doc_obj);

	$self->{'num_processed'} ++;
	undef $doc_obj; 
    }
    # delete any temp files that we may have created
    $self->clean_up_after_doc_obj_processing();


    # if process_status == 1, then the file has been processed.
    return $process_status;

}

# returns undef if file is rejected by the plugin
sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    gsprintf(STDERR, "BaseImporter::process {common.must_be_implemented}\n");

    my ($cpackage,$cfilename,$cline,$csubr,$chas_args,$cwantarray) = caller(1);
    print STDERR "Calling method: $cfilename:$cline $cpackage->$csubr\n";

    die "\n";

    return undef; # never gets here
}

# overwrite this method to delete any temp files that we have created
sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);

}



sub filename_based_title
{
    my $self = shift (@_);
    my ($file) = @_;

    my $file_derived_title = $file;
    $file_derived_title =~ s/_/ /g;
    $file_derived_title =~ s/\.[^.]+$//;

    return $file_derived_title;
}


sub title_fallback
{
    my $self = shift (@_);
    my ($doc_obj,$section,$file) = @_;

    if (!defined $doc_obj->get_metadata_element ($section, "Title") 
	|| $doc_obj->get_metadata_element($section, "Title") eq "") {

	my $source_file = $doc_obj->get_metadata_element($section, "Source");
	my $file_derived_title;
	if (defined $source_file) {
	    $file_derived_title =  $self->filename_based_title($source_file);
	}
	else {
	    # pp = pretty print
	    my $pp_file = (defined $source_file) ? $source_file : $file;

	    my $raw_title = $self->filename_based_title($file);
	    my $file_derived_title = &unicode::raw_filename_to_url_encoded($raw_title);
	}


	if (!defined $doc_obj->get_metadata_element ($section, "Title")) {
	    $doc_obj->add_utf8_metadata ($section, "Title", $file_derived_title);
	}
	else {
	    $doc_obj->set_utf8_metadata_element ($section, "Title", $file_derived_title);
	} 
    }
    
}

# add any extra metadata that's been passed around from one
# plugin to another.
# extra_metadata uses add_utf8_metadata so it expects metadata values
# to already be in utf8
sub extra_metadata {
    my $self = shift (@_);
    my ($doc_obj, $cursection, $metadata) = @_;

    my $associate_tail_re = $self->{'associate_tail_re'};

# Sort the extra metadata for diffcol so these meta appear in a consistent order
# in doc.xml. Necessary for the ex.PDF.* and ex.File.* meta that's extracted in
# the PDFBox collection, as the order of these varies between CentOS and Ubuntu.
    foreach my $field (sort keys(%$metadata)) {
#    foreach my $field (keys(%$metadata)) {
	# $metadata->{$field} may be an array reference
	if ($field eq "gsdlassocfile_tobe") {
	    # 'gsdlassocfile_tobe' is artificially introduced metadata
	    # that is used to signal that certain additional files should
	    # be tied to this document.  Useful in situations where a
	    # metadata pass in the plugin pipeline works out some files
	    # need to be associated with a document, but the document hasn't
	    # been formed yet.
	    my $equiv_form = "";
	    foreach my $gaf (@{$metadata->{$field}}) {
		my ($full_filename,$mimetype) = ($gaf =~ m/^(.*):(.*):$/);
		my ($tail_filename) = ($full_filename =~ /^.*[\/\\](.+?)$/);
		
		# we need to make sure the filename is valid utf-8 - we do 
		# this by url or base64 encoding it
		# $tail_filename is the name that we store the file as
		$tail_filename = &util::rename_file($tail_filename, $self->{'file_rename_method'});
		$doc_obj->associate_file($full_filename,$tail_filename,$mimetype);
		$doc_obj->associate_source_file($full_filename);
		# If the filename is url_encoded, we need to encode the % signs 
		# in the filename, so that it works in a url
		my $url_tail_filename = &unicode::filename_to_url($tail_filename);
		# work out extended tail extension (i.e. matching tail re)

		my ($file_prefix,$file_extended_ext) 
		    = &util::get_prefix_and_tail_by_regex($tail_filename,$associate_tail_re);
		my ($pre_doc_ext) = ($file_extended_ext =~ m/^(.*)\..*$/);
		my ($doc_ext) = ($tail_filename =~ m/^.*\.(.*)$/);

		# the greenstone 2 stuff
		my $start_doclink = "<a href=\"_httpprefix_/collect/[collection]/index/assoc/{Or}{[parent(Top):assocfilepath],[assocfilepath]}/$url_tail_filename\">";
		#my $start_doclink = "<a href=\'_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/$url_tail_filename\'>";
		my $start_doclink_gs3 = "<a href=\'_httpprefix_/collect/[collection]/index/assoc/[assocfilepath]/$url_tail_filename\'>";

		my $srcicon = "_icon".$doc_ext."_";
		my $end_doclink = "</a>";
		
		my $assoc_form = "$start_doclink\{If\}{$srcicon,$srcicon,$doc_ext\}$end_doclink";


		if (defined $pre_doc_ext && $pre_doc_ext ne "") {
		    # for metadata such as [mp3._edited] [mp3._full] ...
		    $doc_obj->add_utf8_metadata ($cursection, "$doc_ext.$pre_doc_ext", $assoc_form); 
		}

		# for multiple metadata such as [mp3.assoclink]
		$doc_obj->add_utf8_metadata ($cursection, "$doc_ext.assoclink", $assoc_form); 

		$equiv_form .= " $assoc_form";	

		# following are used for greenstone 3, 
		$doc_obj->add_utf8_metadata ($cursection, "equivDocLink", $start_doclink_gs3);
		$doc_obj->add_utf8_metadata ($cursection, "equivDocIcon", $srcicon);
		$doc_obj->add_utf8_metadata ($cursection, "/equivDocLink", $end_doclink);

	    }
	    $doc_obj->add_utf8_metadata ($cursection, "equivlink", $equiv_form); 
	}
	elsif ($field eq "gsdlzipfilename") {
	    # special case for when files have come out of a zip. source_path 
	    # (used for archives dbs and keeping track for incremental import)
	    # must be set to the zip file name
	    my $zip_filename = $metadata->{$field};
	    # overwrite the source_path
	    $doc_obj->set_source_path($zip_filename);
	    # and set the metadata
	    $zip_filename = &util::filename_within_collection($zip_filename);
	    $zip_filename = $doc_obj->encode_filename($zip_filename, $self->{'file_rename_method'});
	    $doc_obj->add_utf8_metadata ($cursection, $field, $zip_filename);
	}
	elsif (ref ($metadata->{$field}) eq "ARRAY") {
	    map { 
		$doc_obj->add_utf8_metadata ($cursection, $field, $_); 
	    } @{$metadata->{$field}};
	} else {
	    $doc_obj->add_utf8_metadata ($cursection, $field, $metadata->{$field}); 
	}
    }
}


sub compile_stats {
    my $self = shift(@_);
    my ($stats) = @_;

    $stats->{'num_processed'} += $self->{'num_processed'};
    $stats->{'num_not_processed'} += $self->{'num_not_processed'};
    $stats->{'num_archives'} += $self->{'num_archives'};

}
sub associate_source_file {
    my $self = shift(@_);
    
    my ($doc_obj, $filename) = @_;
    my $cursection = $doc_obj->get_top_section();
    my $assocfilename = $doc_obj->get_assocfile_from_sourcefile();
    
    $doc_obj->associate_file($filename, $assocfilename, undef, $cursection);
    # srclink_file is now deprecated because of the "_" in the metadataname. Use srclinkFile
    $doc_obj->add_utf8_metadata ($cursection, "srclink_file", $doc_obj->get_sourcefile());
    $doc_obj->add_utf8_metadata ($cursection, "srclinkFile", $doc_obj->get_sourcefile());
}

sub associate_cover_image {
    my $self = shift(@_);
    my ($doc_obj, $filename) = @_;

    my $upgraded_filename = &util::upgrade_if_dos_filename($filename);

    $filename =~ s/\.[^\\\/\.]+$/\.jpg/;
    $upgraded_filename =~ s/\.[^\\\/\.]+$/\.jpg/;

    if (exists $self->{'covers_missing_cache'}->{$upgraded_filename}) {
	# don't stat() for existence e.g. for multiple document input files
	# (eg SplitPlug)
	return;
    }

    my $top_section=$doc_obj->get_top_section();

    if (&FileUtils::fileExists($upgraded_filename)) {
	$doc_obj->associate_source_file($filename);
    	$doc_obj->associate_file($filename, "cover.jpg", "image/jpeg");
	$doc_obj->add_utf8_metadata($top_section, "hascover",  1);
    } else {
	my $upper_filename = $filename;
	my $upgraded_upper_filename = $upgraded_filename;

	$upper_filename =~ s/jpg$/JPG/;
	$upgraded_upper_filename =~ s/jpg$/JPG/;

	if (&FileUtils::fileExists($upgraded_upper_filename)) {
	    $doc_obj->associate_source_file($upper_filename);
	    $doc_obj->associate_file($upper_filename, "cover.jpg",
				     "image/jpeg");
	    $doc_obj->add_utf8_metadata($top_section, "hascover",  1);
	} else {
	    # file doesn't exist, so record the fact that it's missing so
	    # we don't stat() again (stat is slow)
	    $self->{'covers_missing_cache'}->{$upgraded_filename} = 1;
	}
    }

}


# Overridden by exploding plugins (eg. ISISPlug)
sub clean_up_after_exploding
{
    my $self = shift(@_);
}



1;
