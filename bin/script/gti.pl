#!/usr/bin/perl -w

###########################################################################
#
# gti.pl
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2005 New Zealand Digital Library Project
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


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}


use iso639;
use strict;
use util;
use FileUtils;

my $gsdl_root_directory = "$ENV{'GSDLHOME'}";
my $gti_log_file = &util::filename_cat($gsdl_root_directory, "etc", "gti.log");
my $source_language_code = "en";  # This is non-negotiable

my $gti_translation_files =
[ # Greenstone macrofiles
{ 'key' => "coredm",
	'file_type' => "macrofile",
	'source_file' => "macros/english.dm",
	'target_file' => "macros/{bn:bengali;fa:farsi;gd:gaelic;id:indo;lv:latvian;pt-br:port-br;pt-pt:port-pt;zh-tr:chinese-trad;iso_639_1_target_language_name}.dm" },

{ 'key' => "auxdm",
	'file_type' => "macrofile",
	'source_file' => "macros/english2.dm",
	'target_file' => "macros/{bn:bengali;fa:farsi;gd:gaelic;id:indo;lv:latvian;pt-br:port-br;pt-pt:port-pt;zh-tr:chinese-trad;iso_639_1_target_language_name}2.dm" },

#{ 'key' => "paperspastdm",
#	'file_type' => "macrofile",
#	'source_file' => "macros/paperspast-english.dm",
#	'target_file' => "macros/paperspast-{bn:bengali;fa:farsi;gd:gaelic;id:indo;lv:latvian;pt-br:port-br;pt-pt:port-pt;zh-tr:chinese-trad;iso_639_1_target_language_name}.dm" },

# GLI dictionary
{ 'key' => "glidict",
	'file_type' => "resource_bundle",
	'source_file' => "gli/classes/dictionary.properties",
	'target_file' => "gli/classes/dictionary_{target_language_code}.properties" },

# GLI help
{ 'key' => "glihelp",
	'file_type' => "greenstone_xml",
	'source_file' => "gli/help/en/help.xml",
	'target_file' => "gli/help/{target_language_code}/help.xml" },

# Greenstone Perl modules
{ 'key' => "perlmodules",
	'file_type' => "resource_bundle",
	'source_file' => "perllib/strings.properties",
	'target_file' => "perllib/strings_{target_language_code}.properties" },

# Greenstone Installer interface
{ 'key' => "gsinstaller",
	'file_type' => "resource_bundle",
	'source_file' => "gsinstaller/LanguagePack.properties",
	'target_file' => "gsinstaller/LanguagePack_{target_language_code}.properties" },

# Greenstone tutorial exercises
# { 'key' => "tutorials",
# 'file_type' => "greenstone_xml",
# 'source_file' => "gsdl-documentation/tutorials/xml-source/tutorial_en.xml",
# 'target_file' => "gsdl-documentation/tutorials/xml-source/tutorial_{target_language_code}.xml" },

# new Greenstone.org
{ 'key' => "greenorg",
	'file_type' => "resource_bundle",
	'source_file' => "greenstoneorg/website/classes/Gsc.properties",
	'target_file' => "greenstoneorg/website/classes/Gsc_{target_language_code}.properties" 
},

# greenstone 3 interface files, from http://svn.greenstone.org/main/trunk/greenstone3/web/WEB-INF/classes
# check it out as greenstone3
{ 'key' => "gs3interface",
        'file_type' => "resource_bundle",
        'source_file' => "greenstone3",
        'target_file' => "greenstone3"
},

# collection config display items of GS3 demo collections. Checked out as gs3-collection-configs
# from http://svn.greenstone.org/main/trunk/gs3-collection-configs
{ 'key' => "gs3colcfg",
	'file_type' => "resource_bundle",
	'source_file' => "gs3-collection-configs",
	'target_file' => "gs3-collection-configs"
}
];

my @gs3_col_cfg_files = ("lucene-jdbm-demo", "solr-jdbm-demo", "localsite");

my @gs3_interface_files = ("interface_default", "ServiceRack", "metadata_names");
#"AbstractBrowse", "AbstractGS2FieldSearch", "AbstractSearch", "AbstractTextSearch", "Authentication", "CrossCollectionSearch", "GS2LuceneSearch", "LuceneSearch", "MapRetrieve", "MapSearch", "PhindPhraseBrowse", "SharedSoleneGS2FieldSearch");

# Auxilliary GS3 interface files. This list is not used at present
# Combine with above list if generating translation spreadsheet for all interface files
my @gs3_aux_interface_files = ("GATEServices","QBRWebServicesHelp", "Visualizer", "IViaSearch", "GS2Construct");

my @gs3_other_interface_files = ("interface_default2", "interface_basic", "interface_basic2", "interface_nzdl", "interface_gs2");

# Not: i18n, log4j

sub main
{
    # Get the command to process, and any arguments
    my $gti_command = shift(@_);
    my @gti_command_arguments = @_;
    my $module = $_[1];

    # for GS3, set gsdl_root_dir to GSDL3HOME
    #if($module && $module eq "gs3interface"){ # module is empty when the gti-command is create-glihelp-zip-file
	#if($ENV{'GSDL3SRCHOME'}) {
	 #   $gsdl_root_directory = (defined $ENV{'GSDL3HOME'}) ? $ENV{'GSDL3HOME'} : &util::filename_cat($ENV{'GSDL3SRCHOME'}, "web");
	 #   $gti_log_file = &util::filename_cat($gsdl_root_directory, "logs", "gti.log");
	#}
    #}
	
    # Open the GTI log file for appending, or write to STDERR if that fails
    if (!open(GTI_LOG, ">>$gti_log_file")) {
		open(GTI_LOG, ">&STDERR");
    }
	
    # Log the command that launched this script
    &log_message("Command: $0 @ARGV");
	
    # Check that a command was supplied
    if (!$gti_command) {
		&throw_fatal_error("Missing command.");
    }      
	
    # Process the command
    if ($gti_command =~ /^get-all-chunks$/i) {
		# Check that GS3 interface is the target
		if ($module =~ m/^gs3/) { # gs3interface, gs3colcfg
			print &get_all_chunks_for_gs3(@gti_command_arguments);
		} else {
			print &get_all_chunks(@gti_command_arguments);
		}
    }
    elsif ($gti_command =~ /^get-first-n-chunks-requiring-work$/i) {
		if ($module =~ m/^gs3/) {	   
			print &get_first_n_chunks_requiring_work_for_gs3(@gti_command_arguments);
		} else {
			print &get_first_n_chunks_requiring_work(@gti_command_arguments);
		}
    }
    elsif ($gti_command =~ /^get-uptodate-chunks$/i) {
		if ($module =~ m/^gs3/) {	   
			print &get_uptodate_chunks_for_gs3(@gti_command_arguments);
		} else {
			print &get_uptodate_chunks(@gti_command_arguments);
		}
    }
    elsif ($gti_command =~ /^get-language-status$/i) {
		print &get_language_status(@gti_command_arguments);       
    }
    elsif ($gti_command =~ /^search-chunks$/i) {
		print &search_chunks(@gti_command_arguments);
    }
    elsif ($gti_command =~ /^submit-translations$/i) {
		# This command cannot produce any output since it reads input
		&submit_translations(@gti_command_arguments);
    }
    elsif ($gti_command =~ /^create-glihelp-zip-file$/i) {
		# This command cannot produce any output since it reads input
		&create_glihelp_zip_file(@gti_command_arguments);
    }
    else {
		# The command was not recognized
		&throw_fatal_error("Unknown command \"$gti_command\".");
    }
}


sub throw_fatal_error
{
    my $error_message = shift(@_);
	
    # Write an XML error response
    print "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    print "<GTIResponse>\n";
    print "  <GTIError time=\"" . time() . "\">" . $error_message . "</GTIError>\n";
    print "</GTIResponse>\n";
	
    # Log the error message, then die
    &log_message("Error: $error_message");
    die "\n";
}


sub log_message
{
    my $log_message = shift(@_);
    print GTI_LOG time() . " -- " . $log_message . "\n";
}


sub get_all_chunks
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key) {
		&throw_fatal_error("Missing command argument.");
    }
	
    # Get (and check) the translation configuration
    my ($source_file, $target_file, $translation_file_type)
	= &get_translation_configuration($target_language_code, $translation_file_key);
	
    # Parse the source language and target language files
    my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
    my @source_file_lines = &read_file_lines($source_file_path);
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
    
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    my @target_file_lines = &read_file_lines($target_file_path);
    my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
	
    # Filter out any automatically translated chunks
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
			delete $source_file_key_to_line_mapping{$chunk_key};
			delete $target_file_key_to_line_mapping{$chunk_key};
		}
    }
	
    my %source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
    &log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
    &log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
	
    my %source_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($source_file, \@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($target_file, \@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
	
    my $xml_response = &create_xml_response_for_all_chunks($translation_file_key, $target_file, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping, \%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);   
    
    return $xml_response;
}


sub get_uptodate_chunks
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key) {
		&throw_fatal_error("Missing command argument.");
    }
	
    # Get (and check) the translation configuration
    my ($source_file, $target_file, $translation_file_type)
	= &get_translation_configuration($target_language_code, $translation_file_key);
	
    # Parse the source language and target language files
    my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
    my @source_file_lines = &read_file_lines($source_file_path);
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
    
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    my @target_file_lines = &read_file_lines($target_file_path);
    my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
	
    # Filter out any automatically translated chunks
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
			delete $source_file_key_to_line_mapping{$chunk_key};
			delete $target_file_key_to_line_mapping{$chunk_key};
		}
    }
	
    my %source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
    &log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
    &log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
	
    my %source_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($source_file, \@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($target_file, \@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);	
  

    # Chunks needing updating are those in the target file that have been more recently edited in the source file
    # All others are uptodate (which implies that they have certainly been translated at some point and would not be empty)
    my @uptodate_target_file_keys = ();
    foreach my $chunk_key (keys(%source_file_key_to_last_update_date_mapping)) {
		my $source_chunk_last_update_date = $source_file_key_to_last_update_date_mapping{$chunk_key};
		my $target_chunk_last_update_date = $target_file_key_to_last_update_date_mapping{$chunk_key};
        
        # print "key: $chunk_key\nsource date : $source_chunk_last_update_date\ntarget date : $target_chunk_last_update_date\nafter? ". &is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date) . "\n\n";        
		
        if (defined($target_chunk_last_update_date) && !&is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date)) {
			# &log_message("Chunk with key $chunk_key needs updating.");
			push(@uptodate_target_file_keys, $chunk_key);
		}
    }

    my $xml_response = &create_xml_response_for_uptodate_chunks($translation_file_key, $target_file, \@uptodate_target_file_keys, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping, \%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);   

    return $xml_response;
}


sub get_first_n_chunks_requiring_work
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
    # The number of chunks to return (defaults to one if not specified)
    my $num_chunks_to_return = shift(@_) || "1";
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key) {
		&throw_fatal_error("Missing command argument.");
    }
	
    # Get (and check) the translation configuration
    my ($source_file, $target_file, $translation_file_type)
	= &get_translation_configuration($target_language_code, $translation_file_key);

    # Parse the source language and target language files
    my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
    my @source_file_lines = &read_file_lines($source_file_path);
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
    
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    my @target_file_lines = &read_file_lines($target_file_path);
    my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
	
    # Filter out any automatically translated chunks
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
			delete $source_file_key_to_line_mapping{$chunk_key};
			delete $target_file_key_to_line_mapping{$chunk_key};
		}
    }
	
    my %source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
    &log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
    &log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
	
    # Determine the target file chunks requiring translation
    my @target_file_keys_requiring_translation = &determine_chunks_requiring_translation(\%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping);
    &log_message("Number of target chunks requiring translation: " . scalar(@target_file_keys_requiring_translation));
	
    # Determine the target file chunks requiring updating
    my %source_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($source_file, \@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
    my %target_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($target_file, \@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
    my @target_file_keys_requiring_updating = &determine_chunks_requiring_updating(\%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);
    &log_message("Number of target chunks requiring updating: " . scalar(@target_file_keys_requiring_updating));
	
    my $xml_response = &create_xml_response_for_chunks_requiring_work($translation_file_key, $target_file, scalar(keys(%source_file_key_to_text_mapping)), \@target_file_keys_requiring_translation, \@target_file_keys_requiring_updating, $num_chunks_to_return, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping, \%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);   
    
    return $xml_response;
}


sub get_language_status
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code) {
		&throw_fatal_error("Missing command argument.");
    }
	
    # Form an XML response to the command
    my $xml_response = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $xml_response .= "<GTIResponse>\n";
    $xml_response .= "  <LanguageStatus code=\"$target_language_code\">\n";
	
    foreach my $translation_file (@$gti_translation_files) {	
		my ($num_source_chunks, $num_target_chunks, $num_chunks_requiring_translation, $num_chunks_requiring_updating) = 0;
		my $target_file_name = "";
		
		if ($translation_file->{'key'} =~ m/^gs3/) { # gs3interface, gs3colcfg
			my (%source_file_key_to_text_mapping, %target_file_key_to_text_mapping, %source_file_key_to_last_update_date_mapping, %target_file_key_to_last_update_date_mapping ) = ();
			&build_gs3_configuration($translation_file->{'key'}, $target_language_code, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping, \%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping );    
			
			my @target_file_keys_requiring_translation = &determine_chunks_requiring_translation(\%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping);	    
			my @target_file_keys_requiring_updating = &determine_chunks_requiring_updating(\%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);
			
			$num_source_chunks = scalar(keys(%source_file_key_to_text_mapping));
			$num_target_chunks = scalar(keys(%target_file_key_to_text_mapping));
			$num_chunks_requiring_translation = scalar(@target_file_keys_requiring_translation);
			$num_chunks_requiring_updating = scalar(@target_file_keys_requiring_updating);
		}
		else {
			# Get (and check) the translation configuration
			my ($source_file, $target_file, $translation_file_type) = &get_translation_configuration($target_language_code, $translation_file->{'key'});
			$target_file_name = $target_file;
			
			# Parse the source language and target language files
			my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
			my @source_file_lines = &read_file_lines($source_file_path);
			my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
			
			my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
			my @target_file_lines = &read_file_lines($target_file_path);
			my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
			
			# Filter out any automatically translated chunks
			foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
				if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
					delete $source_file_key_to_line_mapping{$chunk_key};
					delete $target_file_key_to_line_mapping{$chunk_key};
				}
			}
			
			my %source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
			my %target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
			
			# Determine the target file chunks requiring translation
			my @target_file_keys_requiring_translation = &determine_chunks_requiring_translation(\%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping);	    
			
			# Determine the target file chunks requiring updating
			my @target_file_keys_requiring_updating = ();
			if (-e $target_file_path) {
				my %source_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($source_file, \@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
				my %target_file_key_to_last_update_date_mapping = &build_key_to_last_update_date_mapping($target_file, \@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
				@target_file_keys_requiring_updating = &determine_chunks_requiring_updating(\%source_file_key_to_last_update_date_mapping, \%target_file_key_to_last_update_date_mapping);		
			}
			
			$num_source_chunks = scalar(keys(%source_file_key_to_text_mapping));
			$num_target_chunks = scalar(keys(%target_file_key_to_text_mapping));
			$num_chunks_requiring_translation = scalar(@target_file_keys_requiring_translation);
			$num_chunks_requiring_updating = scalar(@target_file_keys_requiring_updating);
		}
		
		&log_message("Status of " . $translation_file->{'key'});
		&log_message("Number of source chunks: " . $num_source_chunks);
		&log_message("Number of target chunks: " . $num_target_chunks);
		&log_message("Number of target chunks requiring translation: " . $num_chunks_requiring_translation);
		&log_message("Number of target chunks requiring updating: " . $num_chunks_requiring_updating);
		
		$xml_response .= "    <TranslationFile"
	    . " key=\"" . $translation_file->{'key'} . "\""
	    . " target_file_path=\"" . $target_file_name . "\""
	    . " num_chunks_translated=\"" . ($num_source_chunks - $num_chunks_requiring_translation) . "\""
	    . " num_chunks_requiring_translation=\"" . $num_chunks_requiring_translation . "\""
	    . " num_chunks_requiring_updating=\"" . $num_chunks_requiring_updating . "\"\/>\n";
    }
	
    $xml_response .= "  </LanguageStatus>\n";
	
    $xml_response .= "</GTIResponse>\n";
    return $xml_response;
}


sub search_chunks
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
    # The query string
    my $query_string = join(' ', @_);
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key || !$query_string) {
		&throw_fatal_error("Missing command argument.");
    }
	
    my ($source_file, $target_file, $translation_file_type) = ();
    my %source_file_key_to_text_mapping = ();
    my %target_file_key_to_text_mapping = ();
    
    
    if ($translation_file_key !~ m/^gs3/) {
		# Get (and check) the translation configuration
		($source_file, $target_file, $translation_file_type) = &get_translation_configuration($target_language_code, $translation_file_key);
		
		# Parse the source language and target language files
		my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
		my @source_file_lines = &read_file_lines($source_file_path);
		my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
		
		my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
		my @target_file_lines = &read_file_lines($target_file_path);
		my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
		
		# Filter out any automatically translated chunks
		foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
			if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
				delete $source_file_key_to_line_mapping{$chunk_key};
				delete $target_file_key_to_line_mapping{$chunk_key};
			}
		}
		
		%source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
		%target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
    }
    else {
		# Not needed in this case
		my (%source_file_key_to_gti_command_mapping, %target_file_key_to_gti_command_mapping) = ();
		&build_gs3_configuration($translation_file_key, $target_language_code, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping,
		\%source_file_key_to_gti_command_mapping, \%target_file_key_to_gti_command_mapping, 1);
    }
	
    &log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
    &log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
	
    # Determine the target file chunks matching the query
    my @target_file_keys_matching_query = ();
    foreach my $chunk_key (keys(%target_file_key_to_text_mapping)) {
		my $target_file_text = $target_file_key_to_text_mapping{$chunk_key};
		if ($target_file_text =~ /$query_string/i) {
			# &log_message("Chunk with key $chunk_key matches query.");
			push(@target_file_keys_matching_query, $chunk_key);
		}
    }
	
    # Form an XML response to the command
    my $xml_response = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $xml_response .= "<GTIResponse>\n";
	
    $xml_response .= "  <ChunksMatchingQuery size=\"" . scalar(@target_file_keys_matching_query) . "\">\n";
    foreach my $chunk_key (@target_file_keys_matching_query) {
		my $target_file_chunk_text = &make_text_xml_safe($target_file_key_to_text_mapping{$chunk_key});
		
		$xml_response .= "    <Chunk key=\"$chunk_key\">\n";
		$xml_response .= "      <TargetFileText>$target_file_chunk_text</TargetFileText>\n";
		$xml_response .= "    </Chunk>\n";
    }
    $xml_response .= "  </ChunksMatchingQuery>\n";
	
    $xml_response .= "</GTIResponse>\n";
    return $xml_response;
}


sub submit_translations
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
    # The username of the translation submitter
    my $submitter_username = shift(@_);
    # Whether to submit a target chunk even if it hasn't changed
    my $force_submission_flag = shift(@_);
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key || !$submitter_username) {
		&log_message("Fatal error (but cannot be thrown): Missing command argument.");
		die "\n";
    }
    
    my %source_file_key_to_text_mapping = ();
    my %source_file_key_to_gti_comment_mapping = ();
    my %target_file_key_to_text_mapping = ();
    my %target_file_key_to_gti_comment_mapping = ();
	
    my (@source_file_lines, @target_file_lines) = ();
    my ($source_file, $target_file, $translation_file_type);
	
    
    if ($translation_file_key !~ m/^gs3/) {
		# Get (and check) the translation configuration
		($source_file, $target_file, $translation_file_type)
	    = &get_translation_configuration($target_language_code, $translation_file_key);
		
		# Parse the source language and target language files
		@source_file_lines = &read_file_lines(&util::filename_cat($gsdl_root_directory, $source_file));
		my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
		%source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
		%source_file_key_to_gti_comment_mapping = &build_key_to_gti_comment_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);	
		
		@target_file_lines = &read_file_lines(&util::filename_cat($gsdl_root_directory, $target_file));
		my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
		%target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
		%target_file_key_to_gti_comment_mapping = &build_key_to_gti_comment_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);	
    } 
    else {
		&build_gs3_configuration($translation_file_key, $target_language_code, \%source_file_key_to_text_mapping, \%target_file_key_to_text_mapping, 
		\%source_file_key_to_gti_comment_mapping, \%target_file_key_to_gti_comment_mapping, 1);
    }
    &log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
    &log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
	
    # Submission date
    my $day = (localtime)[3];
    my $month = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[(localtime)[4]];
    my $year = (localtime)[5] + 1900;
    my $submission_date = "$day-$month-$year";
	
    open(SUBMISSION, "-");
    my @submission_lines = <SUBMISSION>;
    close(SUBMISSION);
	
    # Remove any nasty carriage returns
    # &log_message("Submission:");
    foreach my $submission_line (@submission_lines) {
		$submission_line =~ s/\r$//;
		#&log_message("  $submission_line");
    }
	
    my %source_file_key_to_submission_mapping = ();
    my %target_file_key_to_submission_mapping = ();
    for (my $i = 0; $i < scalar(@submission_lines); $i++) {
		# Read source file part of submission
		if ($submission_lines[$i] =~ /^\<SourceFileText key=\"(.+)\"\>/) {
			my $chunk_key = $1;
			
			# Read the source file text
			my $source_file_chunk_text = "";
			$i++;
			while ($i < scalar(@submission_lines) && $submission_lines[$i] !~ /^\<\/SourceFileText\>/) {
				$source_file_chunk_text .= $submission_lines[$i];
				$i++;
			}
			$source_file_chunk_text =~ s/\n$//;  # Strip the extra newline character added
			$source_file_chunk_text = &unmake_text_xml_safe($source_file_chunk_text);
			
			#&log_message("Source file key: $chunk_key");
			#&log_message("Source file text: $source_file_chunk_text");
			$source_file_key_to_submission_mapping{$chunk_key} = $source_file_chunk_text;
		}
		
		# Read target file part of submission
		if ($submission_lines[$i] =~ /^\<TargetFileText key=\"(.+)\"\>/) {
			my $chunk_key = $1;
			
			# Read the target file text
			my $target_file_chunk_text = "";
			$i++;
			while ($i < scalar(@submission_lines) && $submission_lines[$i] !~ /^\<\/TargetFileText\>/) {
				$target_file_chunk_text .= $submission_lines[$i];
				$i++;
			}
			$target_file_chunk_text =~ s/\n$//;  # Strip the extra newline character added
			$target_file_chunk_text = &unmake_text_xml_safe($target_file_chunk_text);
			
			#&log_message("Target file key: $chunk_key");
			#&log_message("Target file text: $target_file_chunk_text");
			$target_file_key_to_submission_mapping{$chunk_key} = $target_file_chunk_text;
		}
    }
	
    # -----------------------------------------
    #   Validate the translation submissions
    # -----------------------------------------
	
    # Check that the translations are valid
    foreach my $chunk_key (keys(%source_file_key_to_submission_mapping)) {

	# Kathy introduced escaped colons ("\:") into chunk keys in properties files (greenstone3/metadata_names),	
	# but they're not escaped in the submitted XML versions, nor are they escaped in memory (in the $chunk_key)

		# Make sure the submitted chunk still exists in the source file
		if (!defined($source_file_key_to_text_mapping{$chunk_key})) {
			&log_message("Warning: Source chunk $chunk_key no longer exists (ignoring submission).");
			delete $source_file_key_to_submission_mapping{$chunk_key};
			delete $target_file_key_to_submission_mapping{$chunk_key};
			next;
		}
		
		# Make sure the submitted source chunk matches the source file chunk
		if ($source_file_key_to_submission_mapping{$chunk_key} ne &unmake_text_xml_safe($source_file_key_to_text_mapping{$chunk_key})) {
		#if (&unmake_text_xml_safe($source_file_key_to_submission_mapping{$chunk_key}) ne &unmake_text_xml_safe($source_file_key_to_text_mapping{$chunk_key})) {
		    		#print STDERR "**** $source_file_key_to_submission_mapping{$chunk_key}\n";
				#print STDERR "**** " . &unmake_text_xml_safe($source_file_key_to_text_mapping{$chunk_key}) ."\n";

			&log_message("Warning: Source chunk $chunk_key has changed (ignoring submission).");
			&log_message("Submission source: |$source_file_key_to_submission_mapping{$chunk_key}|");
			&log_message("      Source text: |$source_file_key_to_text_mapping{$chunk_key}|");
			delete $source_file_key_to_submission_mapping{$chunk_key};
			delete $target_file_key_to_submission_mapping{$chunk_key};
			next;
		}
    }
	
    # Apply the submitted translations
    foreach my $chunk_key (keys(%target_file_key_to_submission_mapping)) {
		# Only apply the submission if it is a change, unless -force_submission has been specified
		if ($force_submission_flag || !defined($target_file_key_to_text_mapping{$chunk_key}) || $target_file_key_to_submission_mapping{$chunk_key} ne $target_file_key_to_text_mapping{$chunk_key}) {
			$target_file_key_to_text_mapping{$chunk_key} = $target_file_key_to_submission_mapping{$chunk_key};
			$target_file_key_to_gti_comment_mapping{$chunk_key} = "Updated $submission_date by $submitter_username";
		}
    }
    
    if ($translation_file_key !~ m/^gs3/) {
		eval "&write_translated_${translation_file_type}(\$source_file, \\\@source_file_lines, \\\%source_file_key_to_text_mapping, \$target_file, \\\@target_file_lines, \\\%target_file_key_to_text_mapping, \\\%target_file_key_to_gti_comment_mapping, \$target_language_code)";
    } else {
		eval "&write_translated_gs3interface(\$translation_file_key, \\\%source_file_key_to_text_mapping, \\\%target_file_key_to_text_mapping, \\\%target_file_key_to_gti_comment_mapping, \$target_language_code)";
    }
}


sub create_glihelp_zip_file
{
    my $target_language_code = shift(@_);
    my $translation_file_key = "glihelp";
    
    &log_message("Creating GLI Help zip file for $target_language_code");
	
    my ($source_file, $target_file, $translation_file_type) = &get_translation_data_for($target_language_code, $translation_file_key);    
    
    my $classpath = &util::filename_cat($gsdl_root_directory, "gti-lib");
    my $oldclasspath = $classpath;
    if ( ! -e $classpath) {
	$classpath = &util::filename_cat($gsdl_root_directory, "gli", "shared");
    }
    if ( ! -e $classpath) {
		&throw_fatal_error("$classpath doesn't exist! (Neither does $oldclasspath.) Need the files in this directory (ApplyXLST and its related files) to create the zip file for GLI Help");
    }

    
    my $perllib_path = &util::filename_cat($gsdl_root_directory, "perllib"); # strings.properties
    my $gliclasses_path = &util::filename_cat($gsdl_root_directory, "gli", "classes"); # dictionary.properties
    my $os = $^O;
    my $path_separator = ($^O =~ m/mswin/i) ? ";" : ":";
    my $xalan_path = &util::filename_cat($classpath, "xalan.jar");
    $classpath = "$perllib_path$path_separator$gliclasses_path$path_separator$classpath$path_separator$xalan_path";

    my $gli_help_directory = &util::filename_cat($gsdl_root_directory, "gli");
    $gli_help_directory = &util::filename_cat($gli_help_directory, "help");
    
    my $gen_many_html_xsl_filepath = &util::filename_cat($gli_help_directory, "gen-many-html.xsl");
    if ( ! -e $gen_many_html_xsl_filepath) {
		&throw_fatal_error("$gen_many_html_xsl_filepath doesn't exist! Need this file to create the zip file for GLI Help");
    }
	
    my $gen_index_xml_xsl_filepath = &util::filename_cat($gli_help_directory, "gen-index-xml.xsl");   
    my $split_script_filepath = &util::filename_cat($gli_help_directory, "splithelpdocument.pl");   
    
    my $target_file_directory = &util::filename_cat($gli_help_directory, $target_language_code);
    $target_file_directory = $target_file_directory."/";
	
    my $target_filepath = &util::filename_cat($gsdl_root_directory, $target_file);

    # if gli/help/nl doesn't exist, create it by copying over gli/help/en/help.xml, then process the copied file
    my ($tailname, $glihelp_lang_dir, $suffix) =  &File::Basename::fileparse($target_filepath, "\\.[^\\.]+\$");    
    if(!&FileUtils::directoryExists($glihelp_lang_dir)) { 

	# copy across the gli/help/en/help.xml into a new folder for the new language gli/help/<newlang>
	my $en_glihelp_dir = &util::filename_cat($gli_help_directory, "en");
	my $en_helpxml_file = &util::filename_cat($en_glihelp_dir, "$tailname$suffix"); #$tailname$suffix="help.xml"
	&FileUtils::copyFilesRecursiveNoSVN($en_helpxml_file, $glihelp_lang_dir);

	# In gli/help/<newlang>/help.xml, replace all occurrences of 
	# <Text id="1">This text in en will be removed for new langcode</Text> 
	# with <!-- Missing translation: 1 --> 
	open(FIN,"<$target_filepath") or &throw_fatal_error("Could not open $target_filepath for READING after creating it");
	my $help_xml_contents;
	# Read in the entire contents of the file in one hit
	sysread(FIN, $help_xml_contents, -s FIN);
	close(FIN);	
	
	$help_xml_contents =~ s@<Text id="([^"]+?)">(.*?)</Text>@<!-- Missing translation: $1 -->@sg;

	open(FOUT, ">$target_filepath") or &throw_fatal_error("Could not open $target_filepath for WRITING after creating it");
	print FOUT $help_xml_contents;
	close(FOUT);
    }

	my $perl_exec = &util::get_perl_exec();
	my $java_exec = "java";
	if(defined($ENV{'JAVA_HOME'}) && $ENV{'JAVA_HOME'} ne ""){
		$java_exec = &util::filename_cat($ENV{'JAVA_HOME'}, "bin", "java");
	} elsif(defined($ENV{'JRE_HOME'}) && $ENV{'JRE_HOME'} ne ""){
		$java_exec = &util::filename_cat($ENV{'JRE_HOME'}, "bin", "java");
	}

    #my $cmd = "$java_exec -cp $classpath:$classpath/xalan.jar ApplyXSLT $target_language_code $gen_many_html_xsl_filepath $target_filepath | \"$perl_exec\" -S $split_script_filepath $target_file_directory";
    my $cmd = "$java_exec -DGSDLHOME=$gsdl_root_directory -cp $classpath ApplyXSLT $target_language_code $gen_many_html_xsl_filepath $target_filepath | \"$perl_exec\" -S $split_script_filepath $target_file_directory";
    #&throw_fatal_error("RAN gti command: $cmd");
    my $response = `$cmd`;

    #$cmd = "$java_exec -cp $classpath:$classpath/xalan.jar ApplyXSLT $target_language_code $gen_index_xml_xsl_filepath $target_filepath > " . $target_file_directory . "help_index.xml"; # 2>/dev/null";
    $cmd = "$java_exec -cp $classpath -DGSDLHOME=$gsdl_root_directory ApplyXSLT $target_language_code $gen_index_xml_xsl_filepath $target_filepath > " . $target_file_directory . "help_index.xml"; # 2>/dev/null";
    $response = `$cmd`;

    # create a gti/tmp folder, if one doesn't already exist, and store the downloadable zip file in there
    my $tmpdir = &util::filename_cat($gsdl_root_directory, "tmp");
    if(!&FileUtils::directoryExists($tmpdir)) {
	&FileUtils::makeDirectory($tmpdir);
    }
    #my $zip_file_path = "/greenstone/custom/gti/" . $target_language_code . "_GLIHelp.zip";    
    my $zip_file_path = &util::filename_cat($tmpdir, $target_language_code . "_GLIHelp.zip");
    $cmd = "zip -rj $zip_file_path $target_file_directory -i \*.htm \*.xml";

    $response = `$cmd`;
}


sub get_translation_configuration
{
    # Get the code of the target language
    my $target_language_code = shift(@_);
    # Get the key of the file to translate
    my $translation_file_key = shift(@_);
	
    # Read the translation data from the gti.cfg file
    my ($source_file, $target_file, $translation_file_type) =
	&get_translation_data_for($target_language_code, $translation_file_key);
	
    # Check that the file to translate is defined in the gti.cfg file
    if (!$source_file || !$target_file || !$translation_file_type) {
		&throw_fatal_error("Missing or incomplete specification for translation file \"$translation_file_key\" in gti.pl.");
    }
	
    # Check that the source file exists
    my $source_file_path = &util::filename_cat($gsdl_root_directory, $source_file);
    if (!-e $source_file_path) {
		&throw_fatal_error("Source file $source_file_path does not exist.");
    }
	
    # Check that the source file is up to date
    # The "2>/dev/null" is very important! If it is missing this will never return when run from the receptionist
    # unless ($translation_file_is_not_in_cvs) {
	#my $source_file_cvs_status = `cd $gsdl_root_directory; cvs -d $anonymous_cvs_root update $source_file 2>/dev/null`;
	my $source_file_cvs_status = `cd $gsdl_root_directory; svn status $source_file 2>/dev/null`;
	if ($source_file_cvs_status =~ /^C /) {
	    &throw_fatal_error("Source file $source_file_path conflicts with the repository.");
	}
	if ($source_file_cvs_status =~ /^M /) {
	    &throw_fatal_error("Source file $source_file_path contains uncommitted changes.");
	}
    # }
	
    return ($source_file, $target_file, $translation_file_type);
}


sub get_translation_data_for
{
    my ($target_language_code, $translation_file_key) = @_;
	
    foreach my $translation_file (@$gti_translation_files) {
		# If this isn't the correct translation file, move onto the next one
		next if ($translation_file_key ne $translation_file->{'key'});
		
		# Resolve the target language file
		my $target_language_file = $translation_file->{'target_file'};
		if ($target_language_file =~ /(\{.+\;.+\})/) {
			my $unresolved_target_language_file_part = $1;
			
			# Check for a special case for the target language code
			if ($unresolved_target_language_file_part =~ /(\{|\;)$target_language_code:([^\;]+)(\;|\})/) {
				my $resolved_target_language_file_part = $2;
				$target_language_file =~ s/$unresolved_target_language_file_part/$resolved_target_language_file_part/;
			}
			# Otherwise use the last part as the default value
			else {
				my ($default_target_language_file_part) = $unresolved_target_language_file_part =~ /([^\;]+)\}/;
			$target_language_file =~ s/$unresolved_target_language_file_part/\{$default_target_language_file_part\}/;		    
	    }
	}
	
	# Resolve instances of {iso_639_1_target_language_name}
	my $iso_639_1_target_language_name = $iso639::fromiso639{$target_language_code};
	$iso_639_1_target_language_name =~ tr/A-Z/a-z/ if $iso_639_1_target_language_name;
	$target_language_file =~ s/\{iso_639_1_target_language_name\}/$iso_639_1_target_language_name/g;
	
	# Resolve instances of {target_language_code}
	$target_language_file =~ s/\{target_language_code\}/$target_language_code/g;
	
	return ($translation_file->{'source_file'}, $target_language_file, $translation_file->{'file_type'});
}

return ();
}


sub read_file_lines
{
    my ($file_path) = @_;
	
    if (!open(FILE_IN, "<$file_path")) {
		&log_message("Note: Could not open file $file_path.");
		return ();
    }
    my @file_lines = <FILE_IN>;
    close(FILE_IN);
	
    return @file_lines;
}


sub build_key_to_line_mapping
{
    my ($file_lines, $translation_file_type) = @_;
    eval "return &build_key_to_line_mapping_for_${translation_file_type}(\@\$file_lines)";
}


sub build_key_to_text_mapping
{
    my ($file_lines, $key_to_line_mapping, $translation_file_type) = @_;
	
    my %key_to_text_mapping = ();
    foreach my $chunk_key (keys(%$key_to_line_mapping)) {
		my $chunk_starting_line = (split(/-/, $key_to_line_mapping->{$chunk_key}))[0];
		my $chunk_finishing_line = (split(/-/, $key_to_line_mapping->{$chunk_key}))[1];
		
		my $chunk_text = @$file_lines[$chunk_starting_line];
		for (my $l = ($chunk_starting_line + 1); $l <= $chunk_finishing_line; $l++) {
			$chunk_text .= @$file_lines[$l];
		}
		
		# Map from chunk key to text
		eval "\$key_to_text_mapping{\${chunk_key}} = &import_chunk_from_${translation_file_type}(\$chunk_text)";

		#if($chunk_key =~ m/document\\/) {
		    #&log_message("Submission source: $source_file_key_to_submission_mapping{$chunk_key}");
		    #&log_message("@@@ chunk key: $chunk_key");
		#}

    }
	
    return %key_to_text_mapping;
}


sub build_key_to_last_update_date_mapping
{
    my ($file, $file_lines, $key_to_line_mapping, $translation_file_type) = @_;
	
    # If the files aren't in CVS then we can't tell anything about what needs updating
    # return () if ($translation_file_is_not_in_cvs);
	
    # Build a mapping from key to CVS date
    # Need to be careful with this mapping because the chunk keys won't necessarily all be valid
    my %key_to_cvs_date_mapping = &build_key_to_cvs_date_mapping($file, $translation_file_type);
	
    # Build a mapping from key to comment date
    my %key_to_gti_comment_mapping = &build_key_to_gti_comment_mapping($file_lines, $key_to_line_mapping, $translation_file_type);
	
    # Build a mapping from key to last update date (the latter of the CVS date and comment date)
    my %key_to_last_update_date_mapping = ();
    foreach my $chunk_key (keys(%$key_to_line_mapping)) {
		# Use the CVS date as a starting point
		my $chunk_cvs_date = $key_to_cvs_date_mapping{$chunk_key};
		$key_to_last_update_date_mapping{$chunk_key} = $chunk_cvs_date;
		
		# If a comment date exists and it is after the CVS date, use that instead
        # need to convert the comment date format to SVN format
		my $chunk_gti_comment = $key_to_gti_comment_mapping{$chunk_key};
		if (defined($chunk_gti_comment) && $chunk_gti_comment =~ /(\d?\d-\D\D\D-\d\d\d\d)/) {
			my $chunk_comment_date = $1;           
			if ((!defined($chunk_cvs_date) || &is_date_after($chunk_comment_date, $chunk_cvs_date))) {
				$key_to_last_update_date_mapping{$chunk_key} = $chunk_comment_date;			
			}
		}
    }
	
    return %key_to_last_update_date_mapping;
}


sub build_key_to_cvs_date_mapping
{
    my ($filename, $translation_file_type) = @_;
	
    # Use SVN to annotate each line of the file with the date it was last edited
    # The "2>/dev/null" is very important! If it is missing this will never return when run from the receptionist
    my $cvs_annotated_file = `cd $gsdl_root_directory; svn annotate -v --force $filename 2>/dev/null`;
    
    my @cvs_annotated_file_lines = split(/\n/, $cvs_annotated_file);
	
    my @cvs_annotated_file_lines_date = ();
    foreach my $cvs_annotated_file_line (@cvs_annotated_file_lines) {
		# Extract the date from the SVN annotation at the front
		# svn format : 2007-07-16
        $cvs_annotated_file_line =~ s/^\s+\S+\s+\S+\s(\S+)//; 
        
        push(@cvs_annotated_file_lines_date, $1);
        
        # trim extra date information in svn annotation format
        # 15:42:49 +1200 (Wed, 21 Jun 2006)
        $cvs_annotated_file_line =~ s/^\s+\S+\s\S+\s\((.+?)\)\s//; 
    }    
    
    # Build a key to line mapping for the CVS annotated file, for matching the chunk key to the CVS date
    my %key_to_line_mapping = &build_key_to_line_mapping(\@cvs_annotated_file_lines, $translation_file_type);
	
    my %key_to_cvs_date_mapping = ();
    foreach my $chunk_key (keys(%key_to_line_mapping)) {
		my $chunk_starting_line = (split(/-/, $key_to_line_mapping{$chunk_key}))[0];
		my $chunk_finishing_line = (split(/-/, $key_to_line_mapping{$chunk_key}))[1];
		
		# Find the date this chunk was last edited, from the CVS annotation
		my $chunk_date = $cvs_annotated_file_lines_date[$chunk_starting_line];        
		for (my $l = ($chunk_starting_line + 1); $l <= $chunk_finishing_line; $l++) {
			if (&is_date_after($cvs_annotated_file_lines_date[$l], $chunk_date)) {
				# This part of the chunk has been updated more recently
				$chunk_date = $cvs_annotated_file_lines_date[$l];
				
			}
		}
		
		# Map from chunk key to CVS date
		$key_to_cvs_date_mapping{$chunk_key} = $chunk_date;
    }
	
    return %key_to_cvs_date_mapping;
}


sub build_key_to_gti_comment_mapping
{
    my ($file_lines, $key_to_line_mapping, $translation_file_type) = @_;
	
    my %key_to_gti_comment_mapping = ();
    foreach my $chunk_key (keys(%$key_to_line_mapping)) {
		my $chunk_starting_line = (split(/-/, $key_to_line_mapping->{$chunk_key}))[0];
		my $chunk_finishing_line = (split(/-/, $key_to_line_mapping->{$chunk_key}))[1];
		
		my $chunk_text = @$file_lines[$chunk_starting_line];
		for (my $l = ($chunk_starting_line + 1); $l <= $chunk_finishing_line; $l++) {
			$chunk_text .= @$file_lines[$l];
		}
		
		# Map from chunk key to GTI comment
		my $chunk_gti_comment;
		eval "\$chunk_gti_comment = &get_${translation_file_type}_chunk_gti_comment(\$chunk_text)";
		$key_to_gti_comment_mapping{$chunk_key} = $chunk_gti_comment if (defined($chunk_gti_comment));
    }
	
    return %key_to_gti_comment_mapping;
}


sub determine_chunks_requiring_translation
{
    my $source_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_text_mapping = shift(@_);
	
    # Chunks needing translation are those in the source file with no translation in the target file
    my @target_file_keys_requiring_translation = ();
    foreach my $chunk_key (keys(%$source_file_key_to_text_mapping)) {
		if ($source_file_key_to_text_mapping->{$chunk_key} && !$target_file_key_to_text_mapping->{$chunk_key}) {
			# &log_message("Chunk with key $chunk_key needs translating.");
			push(@target_file_keys_requiring_translation, $chunk_key);
		}
    }
	
    return @target_file_keys_requiring_translation;
}


sub determine_chunks_requiring_updating
{
    my $source_file_key_to_last_update_date_mapping = shift(@_);
    my $target_file_key_to_last_update_date_mapping = shift(@_);
	
    # Chunks needing updating are those in the target file that have been more recently edited in the source file
    my @target_file_keys_requiring_updating = ();
    foreach my $chunk_key (keys(%$source_file_key_to_last_update_date_mapping)) {
		my $source_chunk_last_update_date = $source_file_key_to_last_update_date_mapping->{$chunk_key};
		my $target_chunk_last_update_date = $target_file_key_to_last_update_date_mapping->{$chunk_key};
        
        # print "key: $chunk_key\nsource date : $source_chunk_last_update_date\ntarget date : $target_chunk_last_update_date\nafter? ". &is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date) . "\n\n";

        if (defined($target_chunk_last_update_date) && &is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date)) {
			# &log_message("Chunk with key $chunk_key needs updating.");
	    		# &log_message("key: $chunk_key\nsource date : $source_chunk_last_update_date\ntarget date : $target_chunk_last_update_date\nafter? ". &is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date) . "\n\n");
			push(@target_file_keys_requiring_updating, $chunk_key);
		}
    }
	
    return @target_file_keys_requiring_updating;
}


sub is_chunk_automatically_translated
{
    my ($chunk_key, $translation_file_type) = @_;
    eval "return &is_${translation_file_type}_chunk_automatically_translated(\$chunk_key)";
}


sub make_text_xml_safe
{
    my $text = shift(@_);
    $text =~ s/\&/\&amp\;/g;
    $text =~ s/\&amp\;lt\;/\&amp\;amp\;lt\;/g;
    $text =~ s/\&amp\;gt\;/\&amp\;amp\;gt\;/g;
    $text =~ s/\&amp\;rarr\;/\&amp\;amp\;rarr\;/g;
    $text =~ s/\&amp\;mdash\;/\&amp\;amp\;mdash\;/g;
    $text =~ s/</\&lt\;/g;
    $text =~ s/>/\&gt\;/g;
    return $text;
}


sub unmake_text_xml_safe
{
    my $text = shift(@_);
    $text =~ s/\&lt\;/</g;
    $text =~ s/\&gt\;/>/g;
    $text =~ s/\&amp\;/\&/g;
    return $text;
}


# Returns 1 if $date1 is after $date2, 0 otherwise
sub is_date_after_cvs
{
    my ($date1, $date2) = @_;
    my %months = ("Jan", 1, "Feb", 2, "Mar", 3, "Apr",  4, "May",  5, "Jun",  6,
	"Jul", 7, "Aug", 8, "Sep", 9, "Oct", 10, "Nov", 11, "Dec", 12);
	
	if(!defined $date1) {
		return 1;
	}
	
    my @date1parts = split(/-/, $date1);
    my @date2parts = split(/-/, $date2);
	
    # Compare year - nasty because we have rolled over into a new century
    my $year1 = $date1parts[2];
    if ($year1 < 80) {
		$year1 += 2000;
    }
    my $year2 = $date2parts[2];
    if ($year2 < 80) {
		$year2 += 2000;
    }
	
    # Compare year
    if ($year1 > $year2) {
		return 1;
    }
    elsif ($year1 == $year2) {
		# Year is the same, so compare month
		if ($months{$date1parts[1]} > $months{$date2parts[1]}) {
			return 1;
		}
		elsif ($months{$date1parts[1]} == $months{$date2parts[1]}) {
			# Month is the same, so compare day
			if ($date1parts[0] > $date2parts[0]) {
				return 1;
			}
		}
    }
	
    return 0;
}

sub is_date_after
{
    my ($date1, $date2) = @_;
    
    if(!defined $date1) {
		return 1;
    }
    if(!defined $date2) {
		return 0;
    }
    
    # 16-Aug-2006
    if($date1=~ /(\d+?)-(\S\S\S)-(\d\d\d\d)/){
		my %months = ("Jan", "01", "Feb", "02", "Mar", "03", "Apr",  "04", "May",  "05", "Jun",  "06",
		"Jul", "07", "Aug", "08", "Sep", "09", "Oct", "10", "Nov", "11", "Dec", "12");
		$date1=$3 . "-" . $months{$2} . "-" . $1;
		# print "** converted date1: $date1\n";
    }
    if($date2=~ /(\d+?)-(\S\S\S)-(\d\d\d\d)/){
		my %months = ("Jan", "01", "Feb", "02", "Mar", "03", "Apr",  "04", "May",  "05", "Jun",  "06",
		"Jul", "07", "Aug", "08", "Sep", "09", "Oct", "10", "Nov", "11", "Dec", "12");
		$date2=$3 . "-" . $months{$2} . "-" . $1;
		# print "** converted date2: $date2\n";
    }
    
    
    # 2006-08-16
    my @date1parts = split(/-/, $date1);
    my @date2parts = split(/-/, $date2);
    
    # Compare year
    if ($date1parts[0] > $date2parts[0]) {
		return 1;
    }
    elsif ($date1parts[0] == $date2parts[0]) {
		# Year is the same, so compare month
		if ($date1parts[1] > $date2parts[1]) {
			return 1;
		}
		elsif ($date1parts[1] == $date2parts[1]) {
			# Month is the same, so compare day
			if ($date1parts[2] > $date2parts[2]) {
				return 1;
			}
		}
    }    
    
    return 0;
}


sub create_xml_response_for_chunks_requiring_work
{
    my ($translation_file_key, $target_file, $total_num_chunks, $target_files_keys_requiring_translation, $target_files_keys_requiring_updating, $num_chunks_to_return, $source_files_key_to_text_mapping, $target_files_key_to_text_mapping, $source_files_key_to_last_update_date_mapping, $target_files_key_to_last_update_date_mapping) = @_;
	
    # Form an XML response to the command
    my $xml_response = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $xml_response .= "<GTIResponse>\n";
    $xml_response .= "  <TranslationFile"
	. " key=\"" . $translation_file_key . "\""
	. " target_file_path=\"" . $target_file . "\""
	. " num_chunks_translated=\"" . ($total_num_chunks - scalar(@$target_files_keys_requiring_translation)) . "\""
	. " num_chunks_requiring_translation=\"" . scalar(@$target_files_keys_requiring_translation) . "\""
	. " num_chunks_requiring_updating=\"" . scalar(@$target_files_keys_requiring_updating) . "\"\/>\n";
	
    # Do chunks requiring translation first
    if ($num_chunks_to_return > scalar(@$target_files_keys_requiring_translation)) {
		$xml_response .= "  <ChunksRequiringTranslation size=\"" . scalar(@$target_files_keys_requiring_translation) . "\">\n";
    }
    else {
		$xml_response .= "  <ChunksRequiringTranslation size=\"" . $num_chunks_to_return . "\">\n";
    }
	
    my @sorted_chunk_keys = sort (@$target_files_keys_requiring_translation);
    foreach my $chunk_key (@sorted_chunk_keys) {
		last if ($num_chunks_to_return == 0);
		
		my $source_file_chunk_date = $source_files_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $source_file_chunk_text = &make_text_xml_safe($source_files_key_to_text_mapping->{$chunk_key});	
		
		$xml_response .= "    <Chunk key=\"" . &make_text_xml_safe($chunk_key) . "\">\n";
		$xml_response .= "      <SourceFileText date=\"$source_file_chunk_date\">$source_file_chunk_text</SourceFileText>\n";	
		$xml_response .= "      <TargetFileText></TargetFileText>\n";
		$xml_response .= "    </Chunk>\n";
		
		$num_chunks_to_return--;
    }
	
    $xml_response .= "  </ChunksRequiringTranslation>\n";
	
    # Then do chunks requiring updating
    if ($num_chunks_to_return > scalar(@$target_files_keys_requiring_updating)) {
		$xml_response .= "  <ChunksRequiringUpdating size=\"" . scalar(@$target_files_keys_requiring_updating) . "\">\n";
    }
    else {
		$xml_response .= "  <ChunksRequiringUpdating size=\"" . $num_chunks_to_return . "\">\n";
    }
	
    # foreach my $chunk_key (@target_file_keys_requiring_updating) {
    @sorted_chunk_keys = sort (@$target_files_keys_requiring_updating);
    foreach my $chunk_key (@sorted_chunk_keys) {
		last if ($num_chunks_to_return == 0);
		
		my $source_file_chunk_date = $source_files_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $source_file_chunk_text = &make_text_xml_safe($source_files_key_to_text_mapping->{$chunk_key});
		my $target_file_chunk_date = $target_files_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $target_file_chunk_text = &make_text_xml_safe($target_files_key_to_text_mapping->{$chunk_key});
		
		$xml_response .= "    <Chunk key=\"" . &make_text_xml_safe($chunk_key) . "\">\n";	
		$xml_response .= "      <SourceFileText date=\"$source_file_chunk_date\">$source_file_chunk_text</SourceFileText>\n";
		$xml_response .= "      <TargetFileText date=\"$target_file_chunk_date\">$target_file_chunk_text</TargetFileText>\n";
		$xml_response .= "    </Chunk>\n";
		
		$num_chunks_to_return--;
    }
	
    $xml_response .= "  </ChunksRequiringUpdating>\n";
	
    $xml_response .= "</GTIResponse>\n";
	
    return $xml_response;
}

sub create_xml_response_for_uptodate_chunks
{
    my ($translation_file_key, $target_file, $uptodate_target_files_keys, $source_files_key_to_text_mapping, $target_files_key_to_text_mapping, $source_files_key_to_last_update_date_mapping, $target_files_key_to_last_update_date_mapping) = @_;
	
    # Form an XML response to the command
    my $xml_response = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $xml_response .= "<GTIResponse>\n";
    $xml_response .= "  <TranslationFile"
	. " key=\"" . $translation_file_key . "\""
	. " target_file_path=\"" . $target_file . "\""
	. " num_chunks_uptodate=\"" . scalar(@$uptodate_target_files_keys) . "\"\/>\n";
	
	
    # Then do chunks requiring updating
    $xml_response .= "  <UptodateChunks size=\"" . scalar(@$uptodate_target_files_keys) . "\">\n";
    
	
    # foreach my $chunk_key (@uptodate_target_file_keys) {
    my @sorted_chunk_keys = sort (@$uptodate_target_files_keys);
    foreach my $chunk_key (@sorted_chunk_keys) {
		
		my $source_file_chunk_date = $source_files_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $source_file_chunk_text = &make_text_xml_safe($source_files_key_to_text_mapping->{$chunk_key});
		my $target_file_chunk_date = $target_files_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $target_file_chunk_text = &make_text_xml_safe($target_files_key_to_text_mapping->{$chunk_key});
		
		$xml_response .= "    <Chunk key=\"" . &make_text_xml_safe($chunk_key) . "\">\n";	
		$xml_response .= "      <SourceFileText date=\"$source_file_chunk_date\">$source_file_chunk_text</SourceFileText>\n";
		$xml_response .= "      <TargetFileText date=\"$target_file_chunk_date\">$target_file_chunk_text</TargetFileText>\n";
		$xml_response .= "    </Chunk>\n";

    }
	
    $xml_response .= "  </UptodateChunks>\n";
	
    $xml_response .= "</GTIResponse>\n";
	
    return $xml_response;
}

sub create_xml_response_for_all_chunks
{
    my ($translation_file_key, $target_file, $source_file_key_to_text_mapping, $target_file_key_to_text_mapping, $source_file_key_to_last_update_date_mapping, $target_file_key_to_last_update_date_mapping) = @_;
	
    # Form an XML response to the command
    my $xml_response = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    $xml_response .= "<GTIResponse>\n";
    $xml_response .= "  <TranslationFile"
	. " key=\"" . $translation_file_key . "\""
	. " target_file_path=\"" . $target_file . "\"\/>\n";
    
    # Do all the chunks
    $xml_response .= "  <Chunks size=\"" . scalar(keys(%$source_file_key_to_text_mapping)) . "\">\n";
	
    my @sorted_chunk_keys = sort (keys(%$source_file_key_to_text_mapping));
    foreach my $chunk_key (@sorted_chunk_keys) {
		my $source_file_chunk_date = $source_file_key_to_last_update_date_mapping->{$chunk_key} || "";
		my $source_file_chunk_text = &make_text_xml_safe($source_file_key_to_text_mapping->{$chunk_key});
		
		$xml_response .= "    <Chunk key=\"" . &make_text_xml_safe($chunk_key) . "\">\n";
		$xml_response .= "      <SourceFileText date=\"$source_file_chunk_date\">$source_file_chunk_text</SourceFileText>\n";
		if (defined($target_file_key_to_text_mapping->{$chunk_key})) {
			my $target_file_chunk_date = $target_file_key_to_last_update_date_mapping->{$chunk_key} || "";
			my $target_file_chunk_text = &make_text_xml_safe($target_file_key_to_text_mapping->{$chunk_key});
			$xml_response .= "      <TargetFileText date=\"$target_file_chunk_date\">$target_file_chunk_text</TargetFileText>\n";
		}
		else {
			$xml_response .= "      <TargetFileText></TargetFileText>\n";
		}
		
		$xml_response .= "    </Chunk>\n";
    }
    $xml_response .= "  </Chunks>\n";
    
    $xml_response .= "</GTIResponse>\n";
    return $xml_response;
}



# ==========================================================================================
#   MACROFILE FUNCTIONS

sub build_key_to_line_mapping_for_macrofile
{
    my (@file_lines) = @_;
	
    my $macro_package;
    my %chunk_key_to_line_mapping = ();
    # Process the contents of the file, line by line
    for (my $i = 0; $i < scalar(@file_lines); $i++) {
		my $line = $file_lines[$i];
		$line =~ s/(\s*)$//;  # Remove any nasty whitespace, carriage returns etc.
		
		# Check if a new package is being defined
		if ($line =~ m/^package\s+(.+)/) {
			$macro_package = $1;
		}
		
		# Line contains a macro name
		elsif ($line =~ m/^(_\w+_)/) {
			my $macro_key = $1;
			$line =~ s/\s*([^\\]\#[^\}]+)?$//;  # Remove any comments and nasty whitespace
			
			# While there is still text of the macro to go...
			my $startline = $i;
			while ($line !~ /\}$/) {
				$i++;
				if ($i == scalar(@file_lines)) {
					&throw_fatal_error("Could not find end of macro $macro_key.");
				}
				$line = $file_lines[$i];
				$line =~ s/\s*([^\\]\#[^\}]+)?$//;  # Remove any comments and nasty whitespace
			}
		
	    # The chunk key consists of the package name and the macro key
	    my $chunk_key = $macro_package . "." . $macro_key;
	    # Map from chunk key to line
	    $chunk_key_to_line_mapping{$chunk_key} = $startline . "-" . $i;
	}
	
	# Icon: line in format ## "image text" ## image_type ## macro_name ##
	elsif ($line =~ m/^\#\# .* \#\# .* \#\# (.*) \#\#/) {
	# The chunk key consists of package name and macro key
	my $chunk_key = $macro_package . "." . $1;
	# Map from chunk key to line
	$chunk_key_to_line_mapping{$chunk_key} = $i . "-" . $i;
}
}

return %chunk_key_to_line_mapping;
}


sub import_chunk_from_macrofile
{
    my ($chunk_text) = @_;
	
    # Is this an icon macro??
    if ($chunk_text =~ /^\#\# (.*)/) {
		# Extract image macro text
		$chunk_text =~ /^\#\#\s+([^\#]+)\s+\#\#/;
		$chunk_text = $1;
	
	# Remove enclosing quotes
	$chunk_text =~ s/^\"//;
	$chunk_text =~ s/\"$//;
    }

    # No, so it must be a text macro
    else {
	# Remove macro key
	$chunk_text =~ s/^_([^_]+)_(\s*)//;
	
	# Remove language specifier
	$chunk_text =~ s/^\[l=[^\]]*\](\s*)//; # only remove until first closing square bracket, ]
	
	# Remove braces enclosing text
	$chunk_text =~ s/^{(\s*)((.|\n)*)}(\s*)(\#.+\s*)?/$2/;
    }

    return $chunk_text;
}


sub get_macrofile_chunk_gti_comment
{
    my ($chunk_text) = @_;
	
    # Check for an "Updated DD-MMM-YYYY" comment at the end of the chunk
    if ($chunk_text =~ /\#\s+(Updated\s+\d?\d-\D\D\D-\d\d\d\d.*)\s*$/i) {
		return $1;
}

return undef;
}


sub is_macrofile_chunk_automatically_translated
{
    my ($chunk_key) = @_;
	
    # The _httpiconX_, _widthX_ and _heightX_ image macros are automatically translated
    if ($chunk_key =~ /\._(httpicon|width|height)/) {
		return 1;
    }
	
    return 0;
}


# Use the source file to generate a target file that is formatted the same
sub write_translated_macrofile
{
    my $source_file = shift(@_);  # Not used
    my @source_file_lines = @{shift(@_)};
    my $source_file_key_to_text_mapping = shift(@_);
    my $target_file = shift(@_);
    my @target_file_lines = @{shift(@_)};
    my $target_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_gti_comment_mapping = shift(@_);
    my $target_language_code = shift(@_);
	
    # Build a mapping from source file line to chunk key
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping_for_macrofile(@source_file_lines);
    my %source_file_line_to_key_mapping = ();
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		$source_file_line_to_key_mapping{$source_file_key_to_line_mapping{$chunk_key}} = $chunk_key;
    }
    my @source_file_line_keys = (sort sort_by_line (keys(%source_file_line_to_key_mapping)));
    my $source_file_line_number = 0;
	
    # Build a mapping from target file line to chunk key
    my %target_file_key_to_line_mapping = &build_key_to_line_mapping_for_macrofile(@target_file_lines);
    my %target_file_line_to_key_mapping = ();
    foreach my $chunk_key (keys(%target_file_key_to_line_mapping)) {
		$target_file_line_to_key_mapping{$target_file_key_to_line_mapping{$chunk_key}} = $chunk_key;
    }
    my @target_file_line_keys = (sort sort_by_line (keys(%target_file_line_to_key_mapping)));
	
    # Write the new target file
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    if (!open(TARGET_FILE, ">$target_file_path")) {
		&throw_fatal_error("Could not write target file $target_file_path.");
    }
	
    # Use the header from the target file, to keep language and author information
    if (scalar(@target_file_line_keys) > 0) {
		my $target_file_line_number = 0;
		my $target_file_chunk_starting_line_number = (split(/-/, $target_file_line_keys[0]))[0];
		while ($target_file_line_number < $target_file_chunk_starting_line_number) {
			my $target_file_line = $target_file_lines[$target_file_line_number];
			last if ($target_file_line =~ /^\# -- Missing translation: /);  # We don't want to get into the macros
				print TARGET_FILE $target_file_line;
			$target_file_line_number++;
		}
		
		$source_file_line_number = (split(/-/, $source_file_line_keys[0]))[0];
    }
	
    # Model the new target file on the source file, with the target file translations
    foreach my $line_key (@source_file_line_keys) {
		# Fill in the gaps before this chunk starts
		my $source_file_chunk_starting_line_number = (split(/-/, $line_key))[0];
		my $source_file_chunk_finishing_line_number = (split(/-/, $line_key))[1];
		while ($source_file_line_number < $source_file_chunk_starting_line_number) {
			print TARGET_FILE $source_file_lines[$source_file_line_number];
			$source_file_line_number++;
		}
		$source_file_line_number = $source_file_chunk_finishing_line_number + 1;
		
		my $chunk_key = $source_file_line_to_key_mapping{$line_key};
		my $source_file_chunk_text = $source_file_key_to_text_mapping->{$chunk_key};
		my $target_file_chunk_text = $target_file_key_to_text_mapping->{$chunk_key} || "";
		
		my $macrofile_key = $chunk_key;
		$macrofile_key =~ s/^(.+?)\.//;
		
		# If no translation exists for this chunk, show this, and move on
		if ($source_file_chunk_text ne "" && $target_file_chunk_text eq "") {
			print TARGET_FILE "# -- Missing translation: $macrofile_key\n";
			next;
		}
		
		# Grab the source chunk text
		my $source_file_chunk = $source_file_lines[$source_file_chunk_starting_line_number];
		for (my $l = ($source_file_chunk_starting_line_number + 1); $l <= $source_file_chunk_finishing_line_number; $l++) {
			$source_file_chunk .= $source_file_lines[$l];
		}
		
		# Is this an icon macro??
		if ($source_file_chunk =~ /^\#\# (.*)/) {
			# Escape any newline and question mark characters so the source text is replaced correctly
			$source_file_chunk_text =~ s/\\/\\\\/g;
	    $source_file_chunk_text =~ s/\?/\\\?/g;
		
	    # Build the new target chunk from the source chunk
	    my $target_file_chunk = $source_file_chunk;
	    $target_file_chunk =~ s/$source_file_chunk_text/$target_file_chunk_text/;
	    $target_file_chunk =~ s/(\s)*$//;
	    print TARGET_FILE "$target_file_chunk";
 	}
	
 	# No, it is just a normal text macro
 	else {
 	    print TARGET_FILE "$macrofile_key [l=$target_language_code] {$target_file_chunk_text}";
 	}
	
	# Add the "updated" comment, if one exists
	if ($target_file_key_to_gti_comment_mapping->{$chunk_key}) {
	    print TARGET_FILE "  # " . $target_file_key_to_gti_comment_mapping->{$chunk_key};
	}
	print TARGET_FILE "\n";
}

close(TARGET_FILE);
}


sub sort_by_line
{
    return ((split(/-/, $a))[0] <=> (split(/-/, $b))[0]);
}


# ==========================================================================================
#   RESOURCE BUNDLE FUNCTIONS

# need to handle multi-line properties. A multiline ends on \ if it continues over the next line
sub build_key_to_line_mapping_for_resource_bundle
{
    my (@file_lines) = @_;
	
    my %chunk_key_to_line_mapping = ();

    my $chunk_key;
    my $startindex = -1;

    for (my $i = 0; $i < scalar(@file_lines); $i++) {
		my $line = $file_lines[$i];
		$line =~ s/(\s*)$//;  # Remove any nasty whitespace, carriage returns etc.
		
		# a property line has a colon/equals sign as separator that is NOT escaped with a backslash (both keys and values
		# can use the colon or = sign. But in the key, such a char is always escaped. Unfortunately, they've not always been
		# escaped in the values. So we get the left most occurrence by not doing a greedy match (use ? to not be greedy).
		# So find the first :/= char not preceded by \. That will be the true separator of a chunk_key and its value chunk_text

		if ($line =~ m/^(\S*?[^\\])[:|=](.*)$/) {
		    # Line contains a dictionary string

		    # Unused but useful: http://stackoverflow.com/questions/87380/how-can-i-find-the-location-of-a-regex-match-in-perl
		    # http://perldoc.perl.org/perlvar.html
		    
		    $chunk_key = $1;
		    # remove the escaping of any :/= property separator from the chunk_key in memory, 
		    # to make comparison with its unescaped version during submissions easier. Will write out with escaping.
		    $chunk_key =~ s/\\([:=])/$1/g;		 
		    
		    $startindex = $i;
		}		
		if ($startindex != -1) {
		    if($line !~ m/\\$/) { # line finished
			# $i keeps track of the line at which this property (chunk_key) finishes

			# Map from chunk key to line
			$chunk_key_to_line_mapping{$chunk_key} = $startindex . "-" . $i;
			$startindex = -1;
			$chunk_key = "";
		    }
		}		
    }
	
    return %chunk_key_to_line_mapping;
}


sub import_chunk_from_resource_bundle
{
    my ($chunk_text) = @_;
	
    # Simple: just remove string key. 
    # But key can contain an escaped separator (\: or \=).
    # So just as in the previous subroutine, find the first (leftmost) : or = char not preceded by \. 
    # That will be the true separator of a chunk_key and its value chunk_text
    $chunk_text =~ s/^(\S*?[^\\])[:|=](\s*)//s;

    $chunk_text =~ s/(\s*)$//s;  # Remove any nasty whitespace, carriage returns etc.
    $chunk_text =~ s/(\s*)\#\s+Updated\s+(\d?\d-\D\D\D-\d\d\d\d.*)\s*$//is;
	
    return $chunk_text;
}


sub get_resource_bundle_chunk_gti_comment
{
    my ($chunk_text) = @_;
	
    # Check for an "Updated DD-MMM-YYYY" comment at the end of the chunk
    if ($chunk_text =~ /\#\s+(Updated\s+\d?\d-\D\D\D-\d\d\d\d.*)\s*$/i) {
		return $1;
    }

    return undef;
}


sub is_resource_bundle_chunk_automatically_translated
{
    # No resource bundle chunks are automatically translated
    return 0;
}


sub write_translated_resource_bundle
{
    my $source_file = shift(@_);  # Not used
    my @source_file_lines = @{shift(@_)};
    my $source_file_key_to_text_mapping = shift(@_);
    my $target_file = shift(@_);
    my @target_file_lines = @{shift(@_)};  # Not used
    my $target_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_gti_comment_mapping = shift(@_);
    my $target_language_code = shift(@_);  # Not used
	
    # Build a mapping from chunk key to source file line, and from source file line to chunk key
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping_for_resource_bundle(@source_file_lines);
    my %source_file_line_to_key_mapping = ();
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		$source_file_line_to_key_mapping{$source_file_key_to_line_mapping{$chunk_key}} = $chunk_key;
    }
	
    # Write the new target file
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    if (!open(TARGET_FILE, ">$target_file_path")) {
		&throw_fatal_error("Could not write target file $target_file_path.");
    }
	
    # Model the new target file on the source file, with the target file translations
    my $source_file_line_number = 0;
    foreach my $line_key (sort sort_by_line (keys(%source_file_line_to_key_mapping))) {
		# Fill in the gaps before this chunk starts
		my $source_file_chunk_starting_line_number = (split(/-/, $line_key))[0];
		my $source_file_chunk_finishing_line_number = (split(/-/, $line_key))[1];
		while ($source_file_line_number < $source_file_chunk_starting_line_number) {
			print TARGET_FILE $source_file_lines[$source_file_line_number];
			$source_file_line_number++;
		}
		$source_file_line_number = $source_file_chunk_finishing_line_number + 1;
		
		my $chunk_key = $source_file_line_to_key_mapping{$line_key};
		my $source_file_chunk_text = $source_file_key_to_text_mapping->{$chunk_key};
		my $target_file_chunk_text = $target_file_key_to_text_mapping->{$chunk_key} || "";
		
		# make sure any : or = sign in the chunk key is escaped again (with \) when written out 
		# since the key-value separator in a property resource bundle file is : or =
		my $escaped_chunk_key = $chunk_key;
		$escaped_chunk_key =~ s/(:|=)/\\$1/g; #$escaped_chunk_key =~ s/([^\\])(:|=)/\\$1$2/g;
		
		# If no translation exists for this chunk, show this, and move on
		if ($source_file_chunk_text ne "" && $target_file_chunk_text eq "") {
			print TARGET_FILE "# -- Missing translation: $escaped_chunk_key\n";
			next;
		}

		print TARGET_FILE "$escaped_chunk_key:$target_file_chunk_text";
		if ($target_file_key_to_gti_comment_mapping->{$chunk_key}) {
			print TARGET_FILE "  # " . $target_file_key_to_gti_comment_mapping->{$chunk_key};
		}
		print TARGET_FILE "\n";
    }
	
    close(TARGET_FILE);
}


# ==========================================================================================
#   GREENSTONE XML FUNCTIONS

sub build_key_to_line_mapping_for_greenstone_xml
{
    my (@file_lines) = @_;
	
    my %chunk_key_to_line_mapping = ();
    for (my $i = 0; $i < scalar(@file_lines); $i++) {
		my $line = $file_lines[$i];
		$line =~ s/(\s*)$//;  # Remove any nasty whitespace, carriage returns etc.
		
		# Line contains a string to translate
		if ($line =~ /^\s*<Text id=\"(.*?)\">/) {
			my $chunk_key = $1;
			$line =~ s/\s*$//;  # Remove any nasty whitespace
			$line =~ s/<Updated date=\"\d?\d-\D\D\D-\d\d\d\d.*\"\/>$//;
			
			# While there is still text of the string to go...
			my $startline = $i;
			while ($line !~ /<\/Text>$/) {
				$i++;
				if ($i == scalar(@file_lines)) {
					&throw_fatal_error("Could not find end of string $chunk_key.");
				}
				$line = $file_lines[$i];
				$line =~ s/\s*$//;  # Remove any nasty whitespace
				$line =~ s/<Updated date=\"\d?\d-\D\D\D-\d\d\d\d.*\"\/>$//;
			}
			
			# Map from chunk key to line
			if (!defined($chunk_key_to_line_mapping{$chunk_key})) {
				$chunk_key_to_line_mapping{$chunk_key} = $startline . "-" . $i;
			}
			else {
				&throw_fatal_error("Duplicate key $chunk_key.");
			}
		}
    }
	
    return %chunk_key_to_line_mapping;
}


sub import_chunk_from_greenstone_xml
{
    my ($chunk_text) = @_;
	
    # Simple: just remove the Text tags
    $chunk_text =~ s/^\s*<Text id=\"(.*?)\">(\s*)//;
    $chunk_text =~ s/<Updated date=\"\d?\d-\D\D\D-\d\d\d\d.*\"\/>$//;
    $chunk_text =~ s/<\/Text>$//;
	
    return $chunk_text;
}


sub get_greenstone_xml_chunk_gti_comment
{
    my ($chunk_text) = @_;
	
    # Check for an "Updated DD-MMM-YYYY" comment at the end of the chunk
    if ($chunk_text =~ /<Updated date=\"(\d?\d-\D\D\D-\d\d\d\d.*)\"\/>$/i) {
		return $1;
    }
	
    return undef;
}


sub is_greenstone_xml_chunk_automatically_translated
{
    # No greenstone XML chunks are automatically translated
    return 0;
}


sub write_translated_greenstone_xml
{
    my $source_file = shift(@_);  # Not used
    my @source_file_lines = @{shift(@_)};
    my $source_file_key_to_text_mapping = shift(@_);
    my $target_file = shift(@_);
    my @target_file_lines = @{shift(@_)};  # Not used
    my $target_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_gti_comment_mapping = shift(@_);
    my $target_language_code = shift(@_);  # Not used
	
    # Build a mapping from chunk key to source file line, and from source file line to chunk key
    my %source_file_key_to_line_mapping = &build_key_to_line_mapping_for_greenstone_xml(@source_file_lines);
    my %source_file_line_to_key_mapping = ();
    foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
		$source_file_line_to_key_mapping{$source_file_key_to_line_mapping{$chunk_key}} = $chunk_key;
    }
	
    # Write the new target file
    my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
    if (!open(TARGET_FILE, ">$target_file_path")) {
		&throw_fatal_error("Could not write target file $target_file_path.");
    }
	
    # Model the new target file on the source file, with the target file translations
    my $source_file_line_number = 0;
    foreach my $line_key (sort sort_by_line (keys(%source_file_line_to_key_mapping))) {
		# Fill in the gaps before this chunk starts
		my $source_file_chunk_starting_line_number = (split(/-/, $line_key))[0];
		my $source_file_chunk_finishing_line_number = (split(/-/, $line_key))[1];
		while ($source_file_line_number < $source_file_chunk_starting_line_number) {
			print TARGET_FILE $source_file_lines[$source_file_line_number];
			$source_file_line_number++;
		}
		$source_file_line_number = $source_file_chunk_finishing_line_number + 1;
		
		my $chunk_key = $source_file_line_to_key_mapping{$line_key};
		my $source_file_chunk_text = $source_file_key_to_text_mapping->{$chunk_key};
		my $target_file_chunk_text = $target_file_key_to_text_mapping->{$chunk_key} || "";
		$target_file_chunk_text =~ s/(\n)*$//g;
		
		# If no translation exists for this chunk, show this, and move on
		if ($source_file_chunk_text ne "" && $target_file_chunk_text eq "") {
			print TARGET_FILE "<!-- Missing translation: $chunk_key -->\n";
			next;
		}
		
		print TARGET_FILE "<Text id=\"$chunk_key\">$target_file_chunk_text</Text>";
		if ($target_file_key_to_gti_comment_mapping->{$chunk_key}) {
			my $chunk_gti_comment = $target_file_key_to_gti_comment_mapping->{$chunk_key};
			$chunk_gti_comment =~ s/^Updated //;
			print TARGET_FILE "<Updated date=\"" . $chunk_gti_comment . "\"\/>";
		}
		print TARGET_FILE "\n";
    }
	
    # Fill in the end of the file
    while ($source_file_line_number < scalar(@source_file_lines)) {
		print TARGET_FILE $source_file_lines[$source_file_line_number];
		$source_file_line_number++;
    }
	
    close(TARGET_FILE);
}


# ==========================================================================================
#   GREENSTONE3 FUNCTIONS

sub get_all_chunks_for_gs3
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    my $translation_file_key = lc(shift(@_));
	
    # Check that the necessary arguments were supplied
    if (!$target_language_code) {
		&throw_fatal_error("Missing command argument.");
    }
	
    # Get (and check) the translation configuration
    # my ($source_file_dir, $target_file, $translation_file_type) = &get_translation_configuration($target_language_code, $translation_file_key);
    
    my %source_files_key_to_text_mapping = ();
    my %target_files_key_to_text_mapping = ();
    my %source_files_key_to_last_update_date_mapping = ();
    my %target_files_key_to_last_update_date_mapping = ();
	
    &build_gs3_configuration($translation_file_key, $target_language_code, \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping, \%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
	
    &log_message("Total number of source chunks: " . scalar(keys(%source_files_key_to_text_mapping)));
    &log_message("Total number of target chunks: " . scalar(keys(%target_files_key_to_text_mapping)));
	
    my $xml_response = &create_xml_response_for_all_chunks($translation_file_key, "", \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping, \%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);   
    return $xml_response;
}


sub get_first_n_chunks_requiring_work_for_gs3
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
    # The number of chunks to return (defaults to one if not specified)
    my $num_chunks_to_return = shift(@_) || "1";
    
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key) {
		&throw_fatal_error("Missing command argument.");
    }

    my %source_files_key_to_text_mapping = ();
    my %target_files_key_to_text_mapping = ();
    my %source_files_key_to_last_update_date_mapping = ();
    my %target_files_key_to_last_update_date_mapping = ();
	
    &build_gs3_configuration($translation_file_key, $target_language_code, \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping, 
	\%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
    
    # Determine the target file chunks requiring translation
    my @target_files_keys_requiring_translation = &determine_chunks_requiring_translation(\%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping);    
    # Determine the target file chunks requiring updating
    my @target_files_keys_requiring_updating = &determine_chunks_requiring_updating(\%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
    &log_message("Total number of target chunks requiring translation: " . scalar(@target_files_keys_requiring_translation));
    &log_message("Total number of target chunks requiring updating: " . scalar(@target_files_keys_requiring_updating));

    my $download_target_filepath = "";


    # ****** DOWNLOADING LANGUAGE FILES WAS NOT YET IMPLEMENTED FOR GS3. RUDIMENTARY VERSION ****** #

    # if there is no copy of the language files for download, there's also no link to the spreadsheet
    # for translating offline. So GS3's download option, we will zip up all the relevant greenstone 3
    # interface *.properties files,and link to that zip as the file for offline translation.
    # Selecting only properties files for English and the language they're working on (if the last exists)

    # tar -cvzf gs3interface.tar.gz greenstone3/AbstractBrowse.properties greenstone3/AbstractBrowse_nl.properties 
    # will generate a tar file containing a folder called "greenstone3" with the specified *.properties files

    my $zip = &FileUtils::filenameConcatenate("tmp", "gs3interface_".$target_language_code.".tar.gz");
    my $tar_cmd = "tar -cvzf $zip";


    # store cur dir and cd to gsdlhome to generate the correct path in the zip file
    my $curdir = `pwd`;
    chdir $gsdl_root_directory;

    $tar_cmd .= " " . &get_gs3_zip_file_listing($target_language_code, "greenstone3", \@gs3_interface_files);
    $tar_cmd .= " " . &get_gs3_zip_file_listing($target_language_code, "gs3-collection-configs", \@gs3_col_cfg_files);

    # tar command will overwrite the previous version, but want to check we've created it
    if(&FileUtils::fileExists($zip)) {
	&FileUtils::removeFiles($zip);
    }

    #my $tar_result = system($tar_cmd); # works but then interface breaks
    `$tar_cmd`;
    my $tar_result = $?;

    if(&FileUtils::fileExists($zip)) { ## if($tar_result == 0) {, # breaks the interface
	$download_target_filepath = $zip;
    } else {
	&log_message("Unable to generate zip containing gs3interface files " . $download_target_filepath . "$!");
    }

    # change back to original working directory (cgi-bin/linux probably)
    chdir $curdir;

    # ************** END RUDIMENTARY VERSION OF DOWNLOADING LANGUAGE FILES FOR GS3 ************* #


    my $xml_response = &create_xml_response_for_chunks_requiring_work($translation_file_key, $download_target_filepath, scalar(keys(%source_files_key_to_text_mapping)),
	\@target_files_keys_requiring_translation, \@target_files_keys_requiring_updating,
	$num_chunks_to_return, \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping,
	\%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
	
    return $xml_response;
}

# helper function
# gets the listing of gs3 files for a gs3 interface module (gs3interface, gs3colcfg) 
# formatted correctly to go into a zip file
sub get_gs3_zip_file_listing
{
   my $target_language_code = shift(@_);
   my $sourcedir = shift(@_); 
   my $files_array = shift(@_); # reference to an array of the interfaces files for the gs3 module

   my $filelisting = "";
   foreach my $interface_file (@$files_array) {

	my $source_filepath = &FileUtils::filenameConcatenate($sourcedir, $interface_file.".properties");
	my $target_filepath = &FileUtils::filenameConcatenate($sourcedir, $interface_file."_".$target_language_code.".properties");
	
	$filelisting = "$filelisting $source_filepath";	
	if(&FileUtils::fileExists($target_filepath)) {
	    $filelisting = "$filelisting $target_filepath";
	}
    }

   return $filelisting;
}

sub get_uptodate_chunks_for_gs3
{
    # The code of the target language (ensure it is lowercase)
    my $target_language_code = lc(shift(@_));
    # The key of the file to translate (ensure it is lowercase)
    my $translation_file_key = lc(shift(@_));
    # The number of chunks to return (defaults to one if not specified)
    my $num_chunks_to_return = shift(@_) || "1";
    
    # Check that the necessary arguments were supplied
    if (!$target_language_code || !$translation_file_key) {
		&throw_fatal_error("Missing command argument.");
    }
    
    my %source_files_key_to_text_mapping = ();
    my %target_files_key_to_text_mapping = ();
    my %source_files_key_to_last_update_date_mapping = ();
    my %target_files_key_to_last_update_date_mapping = ();
	
    &build_gs3_configuration($translation_file_key, $target_language_code, \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping, 
	\%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
    

    # Chunks needing updating are those in the target file that have been more recently edited in the source file
    # All others are uptodate (which implies that they have certainly been translated at some point and would not be empty)
    my @uptodate_target_file_keys = ();
    foreach my $chunk_key (keys(%source_files_key_to_last_update_date_mapping)) {
		my $source_chunk_last_update_date = $source_files_key_to_last_update_date_mapping{$chunk_key};
		my $target_chunk_last_update_date = $target_files_key_to_last_update_date_mapping{$chunk_key};
        
        # print "key: $chunk_key\nsource date : $source_chunk_last_update_date\ntarget date : $target_chunk_last_update_date\nafter? ". &is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date) . "\n\n";        
		
        if (defined($target_chunk_last_update_date) && !&is_date_after($source_chunk_last_update_date, $target_chunk_last_update_date)) {
			# &log_message("Chunk with key $chunk_key needs updating.");
			push(@uptodate_target_file_keys, $chunk_key);
		}
    }

    my $xml_response = &create_xml_response_for_uptodate_chunks($translation_file_key, "", \@uptodate_target_file_keys, \%source_files_key_to_text_mapping, \%target_files_key_to_text_mapping, \%source_files_key_to_last_update_date_mapping, \%target_files_key_to_last_update_date_mapping);
	
    return $xml_response;
}


sub build_gs3_configuration
{
    my ($translation_file_key, $target_language_code, $source_files_key_to_text_mapping, $target_files_key_to_text_mapping,
	$source_files_key_to_gti_comment_or_last_updated_mapping, $target_files_key_to_gti_comment_or_last_updated_mapping, $get_gti_comments_not_last_updated) = @_;
    
    my $source_file_directory = "greenstone3";  # my $source_file_directory = &util::filename_cat("WEB-INF","classes"); 
    my $files_array = \@gs3_interface_files;

    if($translation_file_key eq "gs3colcfg") {
	$source_file_directory = "gs3-collection-configs";
	$files_array = \@gs3_col_cfg_files;
    }
    my $translation_file_type = "resource_bundle";
	
    foreach my $interface_file_key (@$files_array) {
		
		&log_message("Greenstone 3 interface file: " . $interface_file_key);
		
		# Parse the source language and target language files
		my $source_file = &util::filename_cat($source_file_directory, $interface_file_key.".properties");
		my @source_file_lines = &read_file_lines(&util::filename_cat($gsdl_root_directory, $source_file));
		my %source_file_key_to_line_mapping = &build_key_to_line_mapping(\@source_file_lines, $translation_file_type);
		my %source_file_key_to_text_mapping = &build_key_to_text_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
		#my %source_file_key_to_gti_comment_mapping = &build_key_to_gti_comment_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);	
		
		my %source_file_key_to_gti_comment_or_last_updated_mapping;
		if($get_gti_comments_not_last_updated) {
		    %source_file_key_to_gti_comment_or_last_updated_mapping = &build_key_to_gti_comment_mapping(\@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);	
		} else {
		    %source_file_key_to_gti_comment_or_last_updated_mapping = &build_key_to_last_update_date_mapping($source_file, \@source_file_lines, \%source_file_key_to_line_mapping, $translation_file_type);
		}

		my $target_file = &util::filename_cat($source_file_directory, $interface_file_key."_".$target_language_code.".properties");
		my @target_file_lines = &read_file_lines(&util::filename_cat($gsdl_root_directory, $target_file));
		my %target_file_key_to_line_mapping = &build_key_to_line_mapping(\@target_file_lines, $translation_file_type);
		my %target_file_key_to_text_mapping = &build_key_to_text_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
		#my %target_file_key_to_gti_comment_mapping = &build_key_to_gti_comment_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
		
		my %target_file_key_to_gti_comment_or_last_updated_mapping;
		if($get_gti_comments_not_last_updated) {
		    %target_file_key_to_gti_comment_or_last_updated_mapping = &build_key_to_gti_comment_mapping(\@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
		} else {
		    %target_file_key_to_gti_comment_or_last_updated_mapping = &build_key_to_last_update_date_mapping($target_file, \@target_file_lines, \%target_file_key_to_line_mapping, $translation_file_type);
		}
		
		
		# Filter out any automatically translated chunks
		foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
			if (&is_chunk_automatically_translated($chunk_key, $translation_file_type)) {
				delete $source_file_key_to_line_mapping{$chunk_key};
				delete $target_file_key_to_line_mapping{$chunk_key};
			}
		}
		
		&log_message("Number of source chunks: " . scalar(keys(%source_file_key_to_text_mapping)));
		&log_message("Number of target chunks: " . scalar(keys(%target_file_key_to_text_mapping)));
		
		foreach my $chunk_key (keys(%source_file_key_to_text_mapping)) {
			my $global_chunk_key = "$interface_file_key.$chunk_key";
			$source_files_key_to_text_mapping->{$global_chunk_key} = $source_file_key_to_text_mapping{$chunk_key};
			$source_files_key_to_gti_comment_or_last_updated_mapping->{$global_chunk_key} = $source_file_key_to_gti_comment_or_last_updated_mapping{$chunk_key};
			
			if (defined $target_file_key_to_text_mapping{$chunk_key}) {
				$target_files_key_to_text_mapping->{$global_chunk_key} = $target_file_key_to_text_mapping{$chunk_key};
				$target_files_key_to_gti_comment_or_last_updated_mapping->{$global_chunk_key} = $target_file_key_to_gti_comment_or_last_updated_mapping{$chunk_key};
			}
		}
    }
}


sub write_translated_gs3interface
{
    my $translation_file_key = shift(@_);
    my $source_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_text_mapping = shift(@_);
    my $target_file_key_to_gti_comment_mapping = shift(@_);
    my $target_language_code = shift(@_);
    
    my @sorted_chunk_keys = sort (keys(%$source_file_key_to_text_mapping));
	
    my %translated_interface_file_keys = ();
    foreach my $chunk_key (keys(%$target_file_key_to_text_mapping)) {
		$chunk_key =~ /^([^\.]+)?\.(.*)$/;
		if (!defined $translated_interface_file_keys{$1}) {
			&log_message("Updated interface file: " . $1);	
			$translated_interface_file_keys{$1}="";
		}
    }
    &log_message("Updated interface files: " . scalar(keys(%translated_interface_file_keys)));
    
    my $source_file_directory = "greenstone3";    
    $source_file_directory = "gs3-collection-configs" if $translation_file_key eq "gs3colcfg";

    foreach my $interface_file_key (keys(%translated_interface_file_keys)) {
		
		# Build a mapping from chunk key to source file line, and from source file line to chunk key
		my $source_file = &util::filename_cat($source_file_directory, "$interface_file_key.properties");
		my @source_file_lines = &read_file_lines(&util::filename_cat($gsdl_root_directory, $source_file));
		my %source_file_key_to_line_mapping = &build_key_to_line_mapping_for_resource_bundle(@source_file_lines);
		my %source_file_line_to_key_mapping = ();
		foreach my $chunk_key (keys(%source_file_key_to_line_mapping)) {
			$source_file_line_to_key_mapping{$source_file_key_to_line_mapping{$chunk_key}} = $chunk_key;
		}
		
		# Write the new target file
		my $target_file = &util::filename_cat($source_file_directory, $interface_file_key . "_" . $target_language_code . ".properties");
		my $target_file_path = &util::filename_cat($gsdl_root_directory, $target_file);
		if (!open(TARGET_FILE, ">$target_file_path")) {
			&throw_fatal_error("Could not write target file $target_file_path.");
		}
		
		# Model the new target file on the source file, with the target file translations
		my $source_file_line_number = 0;
		foreach my $line_key (sort sort_by_line (keys(%source_file_line_to_key_mapping))) {
			# Fill in the gaps before this chunk starts
			my $source_file_chunk_starting_line_number = (split(/-/, $line_key))[0];
			my $source_file_chunk_finishing_line_number = (split(/-/, $line_key))[1];
			while ($source_file_line_number < $source_file_chunk_starting_line_number) {
				print TARGET_FILE $source_file_lines[$source_file_line_number];
				$source_file_line_number++;
			}
			$source_file_line_number = $source_file_chunk_finishing_line_number + 1;
			
			my $chunk_key = $source_file_line_to_key_mapping{$line_key};
			my $global_chunk_key = "$interface_file_key.$chunk_key";
			my $source_file_chunk_text = $source_file_key_to_text_mapping->{$global_chunk_key};
			my $target_file_chunk_text = $target_file_key_to_text_mapping->{$global_chunk_key} || "";
			
			# make sure any : or = sign in the chunk key is escaped again (with \) when written out
			# since the key-value separator in a property resource bundle file is : or =
			my $escaped_chunk_key = $chunk_key;
			$escaped_chunk_key =~ s/(:|=)/\\$1/g; #$escaped_chunk_key =~ s/([^\\])(:|=)/\\$1$2/g;

			# If no translation exists for this chunk, show this, and move on
			if ($source_file_chunk_text ne "" && $target_file_chunk_text eq "") {
				print TARGET_FILE "# -- Missing translation: $escaped_chunk_key\n";
				next;
			}
			
			print TARGET_FILE "$escaped_chunk_key:$target_file_chunk_text";
			if ($target_file_key_to_gti_comment_mapping->{$global_chunk_key}) {
				print TARGET_FILE "  # " . $target_file_key_to_gti_comment_mapping->{$global_chunk_key};
			}
			print TARGET_FILE "\n";
		}
		
		close(TARGET_FILE);	
    }           
}

&main(@ARGV);
