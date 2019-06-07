package Kea;

use strict;

# This function is called by BasPlug.pm when a flag in a collection
# configuration document specifies that keyphrase metadata must be gathered for
# that collection.
# It is passed as arguments, the documents text and possibly some options for
# how the keyphrase data is to be collected if the keyphrase option flag was
# set in the collection configuration file.  This module then writes the
# documents text to a file in a temporary directory because the stand-alone program Kea which will be
# called to do the actual extraction of the keyphrases expects a directory with one or more files as argument.
# Once Kea has been called upon, the file containing the keyphrase data
# gathered by Kea should be stored in gsdl/tmp and this file is read, the data
# we are interested in is extracted and passed back to BasPlug.pm in an
# appropriate format.

sub get_Kea_directory
{
    my $kea_version = shift(@_);
    return &util::filename_cat($ENV{'GSDLHOME'}, "packages", "kea", "kea-$kea_version");
}

# returns a string containing comma-separated keyphrases
sub extract_KeyPhrases
{
    my $kea_version = shift(@_);
    my $doc = shift(@_);  # Document's text  
    my $args = shift(@_);  # Options

    # Set default models
    my $kea_home = &get_Kea_directory($kea_version);
    my $default_model_path = &util::filename_cat($kea_home, "CSTR-20");
    if ($kea_version eq "4.0") {
	# Use a different default model for Kea 4.0
	$default_model_path = &util::filename_cat($kea_home, "FAO-20docs");
    }

    # Parse the Kea options
    my $options_string;
    my @args_list = split(/\s+/, $args) if (defined($args));
    if (@args_list) {
	my $model_specified = 0;
	foreach my $arg (@args_list) {
	    if (length($arg) == 1) {
		$options_string .= " -$arg";
	    }
	    else {
		my $option = substr($arg, 0, 1);
		my $value = substr($arg, 1);
		if ($option eq "m") {
		    my $model_path = &util::filename_cat($kea_home, $value);
		    if (-e $model_path) {
			$options_string .= " -m $model_path";
		    }
		    else {
			print STDERR "Warning: Couldn't find model $model_path; using the default model instead.\n";
			$options_string .= " -m $default_model_path";
		    }
		    $model_specified = 1;
		}
		else {
		    $options_string .= " -$option $value";
		}
	    }
	}

	# If none of the option specifies the model, use the default one
	if ($model_specified != 1) {
	    $options_string .= " -m $default_model_path";
	}
    }
    else {
	# If no options were specified, use the default model
	$options_string = "-m $default_model_path";
    }

    # Remove all HTML tags from the original text
    $doc =~ s/<P[^>]*>/\n/sgi;
    $doc =~ s/<H[^>]*>/\n/sgi;
    $doc =~ s/<[^>]*>//sgi;
    $doc =~ tr/\n/\n/s;

    # Write text to a temporary file doc.txt
    my $tmp_directory_path = &util::filename_cat($ENV{'GSDLHOME'}, "tmp");
    my $doc_txt_file_path = &util::filename_cat($tmp_directory_path, "doc.txt");
    open(DOC_TXT, ">$doc_txt_file_path") or die "Error: Could not write $doc_txt_file_path in Kea.pm.\n";  
    print DOC_TXT $doc;
    close(DOC_TXT);

    # Run Kea with the specified options
    system("java -classpath \"$kea_home\" KEAKeyphraseExtractor -l $tmp_directory_path $options_string");

    # Read the resulting doc.key file which contains the keyphrases
    my $doc_key_file_path = &util::filename_cat($tmp_directory_path, "doc.key");
    if (!open(IN, "<$doc_key_file_path")) {
	# The doc.key file does not exist (either an option was wrongly specified, or no keyphrases were found)
	return "";
    }

    my @keyphrase_list = ();
    while (<IN>) {
	chomp;
	push(@keyphrase_list, $_);
    }
    close(IN);

    # Delete doc.key so that in future it will not be opened and read (otherwise KEA sees it as more keyphrases!)
    unlink($doc_key_file_path);

    my $keyphrases = join(", ", @keyphrase_list);
    return $keyphrases;
}

1;
