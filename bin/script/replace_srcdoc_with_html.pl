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
use printusage;
use parse2;
use FileHandle;

my $arguments = 
    [ 
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "plugin",
	'desc' => "{srcreplace.plugin}",
	'type' => "string",
	'reqd' => "yes",
	'hiddengli' => "yes"},
      { 'name' => "verbosity",
	'desc' => "{import.verbosity}",
	'type' => "int",
	'range' => "0,",
	'deft' => "1",
	'reqd' => "no",
	'modegli' => "3" },
      # Do not remove the following option, it's a flag for generating the xml of the options
      # It WILL be used!
      { 'name' => "xml", # run with -xml, the output generated should be valid XML.  Used from GLI
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" }
      ];
	
my $options = { 'name' => "replace_srcdoc_with_html.pl",
		'desc' => "{srcreplace.desc}",
		'args' => $arguments };

	    
sub main
{
    my ($language, $plugin, $verbosity);

    my $xml = 0;

    my $hashParsingResult = {};

 
    # parse the options
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$hashParsingResult,"allow_extra_options");

    # If parse returns -1 then something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{srcreplace.params}");
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

    # There should be one arg left after parsing (the filename)
    # Or the user may have specified -h, in which case we output the usage
    if($intArgLeftinAfterParsing != 1 || (@ARGV && $ARGV[0] =~ /^\-+h/))
    {
	&PrintUsage::print_txt_usage($options, "{srcreplace.params}");
	die "\n";
    }

    # The filename of the document to be replaced is the first value 
    # that remains after the options have been parsed out
    my $filename = $ARGV[0];
    if (!defined $filename || $filename !~ /\w/) { 	
	
	&PrintUsage::print_txt_usage($options, "{srcreplace.params}");
	print STDERR "You need to specify a filename\n";
	die "\n";
    }
    # check that file exists
    if (!-e $filename) {
	print STDERR "File $filename doesn't exist...\n";
	die "\n";
    }
    # check required options
    if (!defined $plugin || $plugin !~ /\w/) {
	&PrintUsage::print_txt_usage($options, "{srcreplace.params}");
	print STDERR "You need to specify a plugin";
	die "\n";
    }

    # ConvertToPlug.pm's subclasses should be available here through GLI,
    # but in cmdline version, these should be supplied
    my $plugobj;
    require "$plugin.pm";
    eval ("\$plugobj = new $plugin()");
    die "$@" if $@;

    # ...and initialize it
    $plugobj->init(1, "STDERR", "STDERR");
    
    # find the import directory, where we want to create it in. This is where the file
    # passed as parameter by GLI is located.
   
    # derive tmp filename from input filename
    my ($tailname, $import_dir, $suffix)
	= &File::Basename::fileparse($filename, "\\.[^\\.]+\$");

    # Use the plugin's tmp_area_convert_file function to avoid duplicating code.
    # This method returns the name of the output file. In the case of Word docs,
    # if converted with windows_scripting a "filename_files" folder might have been
    # created for associated files. Same situation when using wvware with gsConvert.pl.
    # (When old gsConvert.pl was used, wvware created no separate directory, instead files
    # associated with the html generated would be at the same level in the tmp folder
    # where the output file was created.) Now it's the same no matter whether wvware
    # or windows_scripting did the conversion of the Word doc to html.
    my $output_filename = $plugobj->tmp_area_convert_file("html", $filename);    


    # if something went wrong, then tmp_area_convert_file returns "", but can also check
    # for whether the output file exists or not
    if(!-e $output_filename || $output_filename eq "") { 
	# if no output html file was created, then die so that GLI displays error message
	print STDERR "***replace_srcdoc_with_html.pl: no output file created for $filename ***\n";
	die "No html file created for $filename. Replacement did not take place\n"; # Program NEEDS to die here, 
	# else the error that occurred is not transmitted to GLI and it thinks instead that execution was fine
	#return 0; # error code 0 for false <- NO, needs to die, not return!
    }
    #else:

    # now, find out what to move:
    # it may be a single file, or, if it is a word doc, it may also have an image folder
    # which has the name "filename-without-extension_files"
    my ($tmp_name, $tmp_dir, $ext) = &File::Basename::fileparse($output_filename, "\\.[^\\.]+\$");

    # the name of the folder of associated files (which may or may not exist) in the tmp dir
    my $assoc_folder = &util::filename_cat($tmp_dir, $tmp_name."_files");
 
    # Need to check for naming collisions: in case there is already a file or folder 
    # in the import directory by the name of those we want to move there from the tmp folder
    # First need to work out the full paths to any assoc folder if it were copied into the 
    # import directory, and the main html file if it were copied into the import folder:
    my $new_assoc_folder = &util::filename_cat($import_dir,  $tmp_name."_files"); 
    my $new_file = &util::filename_cat($import_dir,  $tmp_name.$ext); 

    # If there is an image folder, any naming collisions now would mean that the links of 
    # the html file to the image folder would break if we changed the assoc_folder's name. 
    # Therefore, in such a case this process dies after deleting both the file and assoc_folder.
    if(-e $assoc_folder && -e $new_assoc_folder) {
	# so an associated folder was generated, AND a folder by that name already exists
	# in the import folder where we want to copy the generated folder to.
	&util::rm($output_filename);
	&util::rm_r($assoc_folder); # we know directory exists, so remove dir
	die "Image folder $new_assoc_folder already exists.\nDeleting generated file and folder, else links to images will break.\n";
    } 
    # Finally, check that no file already exists with the same name as the generated stand-alone
    # file. Have to do this *after* checking for name collisions with any assoc_folder, because
    # that also tries to remove any output files.
    if(-e $new_file) { # a file by that name already exists, delete the generated file
	&util::rm($output_filename);
	die "File $new_file already exists. Deleting generated file.\n";
    }

    # Now we know we have no file name collisions. We 'move' the html file by copying its
    # contents over and ensuring that these contents are utf8. If we don't do this, PDFs
    # replaced by html may fail, whereas those converted with PDFPlug will have succeeded.
    open(FIN,"<$output_filename") or die "replace_srcdoc_with_html.pl: Unable to open $output_filename to ensure utf8...ERROR: $!\n";
    my $html_contents;
    # Read in the entire contents of the file in one hit
    sysread(FIN, $html_contents, -s FIN);
    &unicode::ensure_utf8(\$html_contents); # turn any high bytes that aren't valid utf-8 into utf-8.
    close(FIN); 

    # write the utf8 contents to the new file and delete the original.
    open(FOUT, ">$new_file") or die "replace_srcdoc_with_html.pl: Unable to open $new_file for writing out utf8 html...ERROR: $!\n";
    print FOUT $html_contents;
    close(FOUT);
    &util::rm($output_filename);
    
    # move any associated folders containing associated files too
    if(-e $assoc_folder) { 
	#print STDERR "****Folder for associated files is $assoc_folder\n";
	    #&util::mv($assoc_folder, $import_dir); # doesn't work for me
	&util::cp_r($assoc_folder, $import_dir);
	&util::rm_r($assoc_folder);
    }   

    # Now we can remove the source doc permanently (there are no assocdirs for source doc)
    &util::rm($filename);

    # need this output statement here, as GShell.java's runRemote() sets status to CANCELLED
    # if there is no output! (Therefore, it only had this adverse affect when running GSDL remotely) 
    # Do something useful with it: return the new filename without extension, used by remote GS server
    print STDOUT "$tmp_name\n"; 
}
&main(@ARGV);
