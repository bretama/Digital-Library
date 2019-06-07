#!/usr/bin/perl -w


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");
}

use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments
no strict 'refs'; # allow filehandles to be variables and vice versa

use encodings;
use extrametautil;
use util;
use FileUtils;
use printusage;
use parse2;
use colcfg;

use FileHandle;

use File::Spec;
use File::Basename;

my $unicode_list =
    [ { 'name' => "auto",
	'desc' => "{ReadTextFile.input_encoding.auto}" },
      { 'name' => "ascii",
	'desc' => "{BasePlugin.encoding.ascii}" },
      { 'name' => "utf8",
	'desc' => "{BasePlugin.encoding.utf8}" },
      { 'name' => "unicode",
	'desc' => "{BasePlugin.encoding.unicode}" } ];

my $e = $encodings::encodings;
foreach my $enc (sort {$e->{$a}->{'name'} cmp $e->{$b}->{'name'}} keys (%$e)) 
{
    my $hashEncode =
    {'name' => $enc,
     'desc' => $e->{$enc}->{'name'}};
    
    push(@{$unicode_list},$hashEncode);
}

my $arguments = 
    [ 
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "plugin",
	'desc' => "{explode.plugin}",
	'type' => "string",
	'reqd' => "yes",
	'hiddengli' => "yes"},
      { 'name' => "input_encoding",
	'desc' => "{explode.encoding}",
	'type' => "enum",
	'deft' => "auto",
	'list' => $unicode_list,
	'reqd' => "no" },
      { 'name' => "metadata_set",
	'desc' => "{explode.metadata_set}",
	'type' => "string",
	'reqd' => "no" },
      { 'name' => "document_field",
	'desc' => "{explode.document_field}",
	'type' => "string",
	'reqd' => "no"},
       { 'name' => "document_prefix",
	'desc' => "{explode.document_prefix}",
	'type' => "string",
	'reqd' => "no"},
      { 'name' => "document_suffix",
	'desc' => "{explode.document_suffix}",
	'type' => "string",
	'reqd' => "no"},
      { 'name' => "records_per_folder",
	'desc' => "{explode.records_per_folder}",
	'type' => "int",
	'range' => "0,",
	'deft' => "100",
	'reqd' => "no" },
       { 'name' => "collectdir",
	'desc' => "{import.collectdir}",
	'type' => "string",
	# parsearg left "" as default
	#'deft' => &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect"),
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "site",
	'desc' => "{import.site}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "collection",
	'desc' => "{explode.collection}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "use_collection_plugin_options",
	'desc' => "{explode.use_collection_plugin_options}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "plugin_options",
	'desc' => "{explode.plugin_options}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes"},
      { 'name' => "verbosity",
	'desc' => "{import.verbosity}",
	'type' => "int",
	'range' => "0,",
	'deft' => "1",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "xml",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" }
      ];
	
my $options = { 'name' => "explode_metadata_database.pl",
		'desc' => "{explode.desc}",
		'args' => $arguments };



sub main
{
    my ($language, $input_encoding, $metadata_set, $plugin, 
	$document_field, $document_prefix, $document_suffix, 
	$records_per_folder, $plugin_options, $collectdir, $site, $collection, 
	$use_collection_plugin_options, $verbosity);

    my $xml = 0;

    my $hashParsingResult = {};
    # parse the options
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");

    # If parse returns -1 then something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{explode.params}");
	die "\n";
    }

    foreach my $strVariable (keys %$hashParsingResult)
    {
	eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }

    # If $language has been specified, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language && $language =~ /\S/) {
	&gsprintf::load_language_specific_resource_bundle($language);
    }

    if ($xml) {
        &PrintUsage::print_xml_usage($options);
	print "\n";
	return;
    }

    
    # There should one arg left after parsing (the filename)
    # Or the user may have specified -h, in which case we output the usage
    if($intArgLeftinAfterParsing != 1 || (@ARGV && $ARGV[0] =~ /^\-+h/))
    {
	&PrintUsage::print_txt_usage($options, "{explode.params}");
	die "\n";
    }

    # The metadata database filename is the first value that remains after the options have been parsed out
    my $filename = $ARGV[0];
    if (!defined $filename || $filename !~ /\w/) { 
	&PrintUsage::print_txt_usage($options, "{explode.params}");
	print STDERR "You need to specify a filename";
	die "\n";
    }
    # check that file exists
    if (!-e $filename) {
	print STDERR "File $filename doesn't exist...\n";
	die "\n";
    }
    # check required options
    if (!defined $plugin || $plugin !~ /\w/) {
	&PrintUsage::print_txt_usage($options, "{explode.params}");
	print STDERR "You need to specify a plugin";
	die "\n";
    }
    
    # check metadata set
    if (defined $metadata_set && $metadata_set =~ /\w/) {
	$metadata_set .= ".";
    } else {
	$metadata_set = "";
    }
    if (defined $collection && $collection =~ /\w/) {
	if (($collection = &colcfg::use_collection($site, $collection, $collectdir)) eq "") {
	    print STDERR "Collection $collection does not exist\n";
	    die "\n";
	}
    } else {
	undef $collection;
    }
    
    if ($use_collection_plugin_options) {
	if (defined $plugin_options && $plugin_options =~ /\w/) {
	    print STDERR "Error: you cannot have -use_collection_plugin_options and -plugin_options set at the same time\n";
	    die "\n";
	}
	if (not defined $collection) {
	    print STDERR "Error: you must specify a collection using -collection to use -use_collection_plugin_options\n";
	    die "\n";
	}
    }
    my $plugobj;
    require "$plugin.pm";

    my $plugin_options_string = "";
    if ($use_collection_plugin_options) {
	# read in the collect.cfg file
	# Read in the collection configuration file.
	my $gs_mode = "gs2";
	if ((defined $site) && ($site ne "")) { # GS3
	    $gs_mode = "gs3";
	}
	my $configfilename = &colcfg::get_collect_cfg_name(STDERR, $gs_mode);
	my $collectcfg = &colcfg::read_collect_cfg ($configfilename, $gs_mode);
	$plugin_options_string = &get_plugin_options($collectcfg, $plugin);
    }
    elsif (defined $plugin_options && $plugin_options =~ /\w/) {
	my @options = split(/\s/, $plugin_options);
	map { $_ = "\"$_\"" unless $_ =~ /^\"/; } @options;
	$plugin_options_string= join (",", @options);
    }

    if ($plugin_options_string eq "") {
	eval ("\$plugobj = new $plugin()");
	die "$@" if $@;
    } else {
	eval ("\$plugobj = new $plugin([], [$plugin_options_string])");
	die "$@" if $@;
    } 
    
    # ...and initialize it
    $plugobj->init($verbosity, "STDERR", "STDERR");

    if ($input_encoding eq "auto") {
	($language, $input_encoding) = $plugobj->textcat_get_language_encoding ($filename);
    }	    

    # Create a directory to store the document files...
    my ($exploded_base_dir) = ($filename =~ /(.*)\.[^\.]+$/);

    my $orig_base_dir = &File::Basename::dirname($filename);


    my $split_exp = $plugobj->{'split_exp'};
    if (defined $split_exp) {
	# Read in file, and then split and process individual records

	my $text = "";
	# Use the plugin's read_file function to avoid duplicating code
	$plugobj->read_file($filename, $input_encoding, undef, \$text);
	# is there any text in the file??
	die "\n" unless length($text);

	# Split the text into records, using the plugin's split_exp

	my @metadata_records = split(/$split_exp/, $text);
	my $total_num_records = scalar(@metadata_records);
	print STDERR "Number of records: $total_num_records\n";
	
	# Write the metadata from each record to the metadata.xml file
	my $record_number = 1;
	my $documents_directory;
	foreach my $record_text (@metadata_records) {
	    
	    # Check if we need to start a new directory for these records
	    check_need_new_directory($exploded_base_dir,$record_number,
				     $records_per_folder,$total_num_records,
				     \$documents_directory);
	    # Use the plugin's process function to avoid duplicating code
	    my $doc_obj = new doc($filename, "nonindexed_doc", $plugobj->get_file_rename_method());
	    $plugobj->process(\$record_text, undef, undef, $filename, undef, $doc_obj, 0);
	    
	    
	    # Try to get a doc to attach the metadata to
	    # If no match found, create a dummy .nul file
	    attach_metadata_or_make_nul_doc($document_field, $doc_obj, $record_number,
				       $documents_directory, $orig_base_dir,
				       $document_prefix, $document_suffix, $metadata_set, $verbosity);
	    	    
	    
	    check_close_directory($record_number,$records_per_folder,$total_num_records);
	    
	    $record_number = $record_number + 1;
	}
    }
    else {
	# Call metadata_read to set up associated metadata 

	my $pluginfo = undef;
	my $block_hash = {};

	my $processor = undef;
	my $maxdocs = undef;
	my $gli = undef;

	my $extrametakeys = [];
	my $extrametadata = {};
	my $extrametafile = {};

	$plugobj->metadata_read($pluginfo, "", $filename, $block_hash,   
				$extrametakeys, $extrametadata, $extrametafile,
				$processor, $maxdocs, $gli);

	my $total_num_records = scalar (@$extrametakeys);
	print STDERR "Number of records: $total_num_records\n";
	my $record_number = 1;
	my $documents_directory;
	foreach my $record (@$extrametakeys) {
	    &check_need_new_directory($exploded_base_dir, $record_number, $records_per_folder, $total_num_records, \$documents_directory);
	    
	    # Attach metadata to object
	    # => use the plugin's extra_metadata function to avoid duplicating code
	    my $doc_obj = new doc($filename, "nonindexed_doc", $plugobj->get_file_rename_method());
	    # all the metadata has been extracted into extrametadata
		$plugobj->extra_metadata ($doc_obj, $doc_obj->get_top_section(), &extrametautil::getmetadata($extrametadata, $record));	    

	    # Try to get a doc to attach the metadata to
	    # If no match found, create a dummy .nul file
	    attach_metadata_or_make_nul_doc($document_field, $doc_obj, $record_number, $documents_directory, $orig_base_dir, $document_prefix, $document_suffix, $metadata_set, $verbosity);
	    
	    &check_close_directory($record_number,$records_per_folder,$total_num_records);
	    
	    $record_number = $record_number + 1;

	}
    }

    # Explode means just that: the original file is deleted
    &FileUtils::removeFiles($filename);
    $plugobj->clean_up_after_exploding();

}


sub need_new_directory
{
    my ($exploded_base_dir) = @_;
    
    my $documents_directory = $exploded_base_dir;

    if (-d $documents_directory) {
	die "Error: document directory $documents_directory already exists (bailing).\n";
    }
    &FileUtils::makeDirectory($documents_directory);

    my $documents_metadata_xml_file = &FileUtils::filenameConcatenate($documents_directory, "metadata.xml");
    if (-e $documents_metadata_xml_file) {
	die "Error: documents metadata.xml file $documents_metadata_xml_file already exists (bailing).\n";
    }

    # Start the metadata.xml file
    open(METADATA_XML_FILE, ">$documents_metadata_xml_file");
	binmode METADATA_XML_FILE, ":utf8";
    print METADATA_XML_FILE
	"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n" .
	"<!DOCTYPE DirectoryMetadata SYSTEM \"http://greenstone.org/dtd/DirectoryMetadata/1.0/DirectoryMetadata.dtd\">\n" .
	"<DirectoryMetadata>\n";

    return $documents_directory;
}

sub check_need_new_directory
{
    my ($exploded_base_dir,$record_number, $records_per_folder,
	$total_num_records, $documents_dir_ref) = @_;
    

    # Check if we need to start a new directory for these records
    if ($records_per_folder == 1 || ($record_number % $records_per_folder) == 1) {
	my $documents_directory = $exploded_base_dir;

	if ($total_num_records > $records_per_folder) {
	    $documents_directory .= "." . sprintf("%8.8d", $record_number);
	}

	$$documents_dir_ref = need_new_directory($documents_directory);
    }
}





sub attach_metadata_or_make_nul_doc
{
    my ($document_field, $doc_obj, $record_number, 
	$documents_directory, $orig_base_dir,
	$document_prefix, $document_suffix, $metadata_set, $verbosity) = @_;

    my $record_metadata = $doc_obj->get_all_metadata($doc_obj->get_top_section());
    my $document_file;

    # try to get a doc to attach the metadata to
    if (defined $document_field) {
	foreach my $pair (@$record_metadata) {
	    my ($field, $value) = (@$pair);
	    $field =~ s/^ex\.([^.]+)$/$1/; #remove any ex. iff it's the only metadata set prefix (will leave ex.dc.* intact)
	    $value =~ s/\\\\/\\/g;         # don't regex brackets () here though!
	    my $document_file_full;

	    # Does this metadata element specify a document to obtain?
	    if ($field eq $document_field) {
		if(-d $document_prefix && $document_prefix !~ m@^(http|ftp|https)://@ ) {
		    # if the document-prefix refers to a directory but not URL, ensure it has a file-separator at the end
		    # by first of all stripping any trailing slash and then always ensuring one is used through filename_cat
		    $document_prefix =~ s/(\/|\\)$//;
		    $document_file_full = &FileUtils::filenameConcatenate($document_prefix, "$value$document_suffix");
		} else { # the doc prefix may also contain the prefix of the actual *filename* following the directory
		    $document_file_full = $document_prefix . $value . $document_suffix;
		}

		# this either downloads/copies the document, or creates a nul file for it.
		$document_file = &obtain_document($document_file_full, $documents_directory, $orig_base_dir, $verbosity);
		&write_metadata_xml_file_entry(METADATA_XML_FILE, $document_file, $record_metadata, $metadata_set);
	    }
	}
    }
    
    # Create a dummy .nul file if we haven't obtained a document (or null file) for this record
    if (not defined $document_file) {

	if (defined ($record_number)) {
	    $document_file = sprintf("%8.8d", $record_number) . ".nul";
	}
	else {
	    $document_file = "doc.nul";
	}
	open(DUMMY_FILE, ">$documents_directory/$document_file");
	close(DUMMY_FILE);
	&write_metadata_xml_file_entry(METADATA_XML_FILE, $document_file, $record_metadata, $metadata_set);
    }

}

sub close_directory
{
    # Finish and close the metadata.xml file
    print METADATA_XML_FILE "\n</DirectoryMetadata>\n";
    close(METADATA_XML_FILE);

}


sub check_close_directory
{
    my ($record_number,$records_per_folder,$total_num_records) = @_;

    if (($record_number % $records_per_folder) == 0 || $record_number == $total_num_records) {
	# Finish and close the metadata.xml file
	close_directory();
    }
}
	    


sub write_metadata_xml_file_entry
{
    my $metadata_xml_file = shift(@_);
    my $file_name = shift(@_);
    my $record_metadata = shift(@_);
    my $meta_prefix = shift(@_);
    
    # Make $file_name XML-safe
    $file_name =~ s/&/&amp;/g;
    $file_name =~ s/</&lt;/g;
    $file_name =~ s/>/&gt;/g;

    # Convert $file_name into a regular expression that matches it
    $file_name =~ s/\./\\\./g;
    $file_name =~ s/\(/\\\(/g;
    $file_name =~ s/\)/\\\)/g;
    $file_name =~ s/\{/\\\{/g;
    $file_name =~ s/\}/\\\}/g;
    $file_name =~ s/\[/\\\[/g;
    $file_name =~ s/\]/\\\]/g;
    
    print $metadata_xml_file
	"\n" .
        "  <FileSet>\n" .
	"    <FileName>$file_name</FileName>\n" .
	"    <Description>\n";

    foreach my $pair (@$record_metadata) {
	my ($field, $value) = (@$pair);

	# We're only interested in metadata from the database
	next if ($field eq "lastmodified");
	next if ($field eq "gsdlsourcefilename");
	next if ($field eq "gsdldoctype");
	next if ($field eq "FileFormat");

	# Ignore the ^all metadata, since it will be invalid if the source metadata is changed
	next if ($field =~ /\^all$/);  # ISISPlug specific!

	$field =~ s/^ex\.([^.]+)$/$1/; #remove any ex. iff it's the only metadata set prefix (will leave ex.dc.* intact)

	# Square brackets in metadata values need to be escaped so they don't confuse Greenstone/GLI
	$value =~ s/\[/&\#091;/g;
	$value =~ s/\]/&\#093;/g;

	# Make $value XML-safe
	$value =~ s/&/&amp;/g;  # May mess up existing entities!
	$value =~ s/</&lt;/g;
	$value =~ s/>/&gt;/g;

	# we are not allowed & in xml except in entities. 
	# if there are undefined entities then parsing will also crap out.
	# should we be checking for them too?
	# this may not get all possibilities
	# $value =~ s/&([^;\s]*(\s|$))/&amp;$1/g;

	# do we already have a namespace specified?
	my $full_field = $field;
	if ($meta_prefix ne "") {
	    $full_field =~ s/^\w+\.//;
	    $full_field = $meta_prefix.$full_field;
	}

	print $metadata_xml_file "      <Metadata mode=\"accumulate\" name=\"$full_field\">$value</Metadata>\n";
    }

    print $metadata_xml_file
	"    </Description>\n" .
	    "  </FileSet>\n";
}

sub obtain_document
{
    my ($document_file_full,$documents_directory,$orig_base_dir,$verbosity) = @_;
    
    print STDERR "Obtaining document file $document_file_full...\n" if ($verbosity > 1);

    my $document_file_name;
    my $local_document_file;

    # Document specified is on the web
    if ($document_file_full =~ /^https?:/ || $document_file_full =~ /^ftp:/) {
	$document_file_full =~ /([^\/]+)$/;
	$document_file_name = $1;
	$local_document_file = &FileUtils::filenameConcatenate($documents_directory, $document_file_name);

	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

	my $wget_options = "--quiet";
	$wget_options = "--verbose" if ($verbosity > 2);
	$wget_options .= " --timestamping";  # Only re-download files if they're newer
	my $wget_command = "wget $wget_options \"$document_file_full\" --output-document \"$local_document_file\"";
	`$wget_command`;

	# Check the document was obtained successfully
	if (!-e $local_document_file) {
	    print STDERR "WARNING: Could not obtain document file $document_file_full\n";
	}
    }
    # Document specified is on the disk
    else {
	# convert the dirseps in filepath to correct dir sep for OS
	$document_file_full = &FileUtils::filenameConcatenate($document_file_full);
	my $dir_sep = &util::get_os_dirsep();

	$document_file_full =~ m/(.+$dir_sep)?(.*)$/;
	$document_file_name = $2;


	my $is_absolute = File::Spec->file_name_is_absolute($document_file_full);
	print STDERR "doc file full = $document_file_full\n";

	if (!$is_absolute) {
	    $document_file_full 
		= &FileUtils::filenameConcatenate($orig_base_dir,$document_file_full);
	}

	$local_document_file = &FileUtils::filenameConcatenate($documents_directory, $document_file_name);

	if (-e $document_file_full) {
	    &FileUtils::copyFiles($document_file_full, $documents_directory);
	}
	
	# Check the document was obtained successfully
	if (!-e $local_document_file) {
	    print STDERR "WARNING: Could not obtain document file $document_file_full\n";
	}
	else {
		$orig_base_dir = &util::filename_to_regex($orig_base_dir); # escape windows style slashes for the regex below		
	    if ($document_file_full =~ m/^$orig_base_dir.*/) {
		# file local to metadata record
		# => copy has been made successfully, so remove original
		&FileUtils::removeFiles($document_file_full);
	    }
	}
    }

    # If the document wasn't obtained successfully, create a .nul file for it
    if (!-e $local_document_file) {
	$document_file_name .= ".nul";
	open(NULL_FILE, ">$local_document_file.nul");
	close(NULL_FILE);
	print STDERR "Creating a nul document $document_file_name\n";
    }

    return $document_file_name;
}

sub get_plugin_options {
    my ($collectcfg, $plugin)  = @_;
    
    my $plugin_list = $collectcfg ->{'plugin'};
    
    foreach my $pluginoptions (@$plugin_list) {
	my $pluginname = shift @$pluginoptions;
	next unless $pluginname eq $plugin;
	map { $_ = "\"$_\""; } @$pluginoptions;
	my $options = join (",", @$pluginoptions);
	return $options;
    }
    return "";
}

&main(@ARGV);

