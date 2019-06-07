#!/usr/bin/perl -w

use strict;

use LWP::UserAgent;
use HTTP::Request::Common;

use CGI::Carp qw(fatalsToBrowser); 
use CGI; 

use File::Basename;

BEGIN {
    eval('require "./gsdlCGI.pm"');
    if ($@)
    {
	print STDOUT "Content-type:text/plain\n\n";
	print STDOUT "ERROR: $@\n";
	exit 0;
    }

    # Line to stop annoying child DOS CMD windows from appearing
    Win32::SetChildShowWindow(0) 
	if defined &Win32::SetChildShowWindow;
}




sub get_infodb_type
{
    my ($opt_site,$collect_home,$collect) = @_;

    my $out = "STDERR";

    $collect = &colcfg::use_collection($opt_site, $collect, $collect_home);

    if ($collect eq "") {
	print STDERR "Error: failed to find collection $collect in $collect_home\n";
	print STDOUT "Content-type:text/plain\n\n";
	print STDOUT "ERROR: Failed to find collection $collect\n";
	exit 0;
	
    }

    # Read in the collection configuration file.
    my ($config_filename, $gs_mode) = &colcfg::get_collect_cfg_name($out);
    my $collectcfg = &colcfg::read_collection_cfg ($config_filename, $gs_mode);

    return $collectcfg->{'infodbtype'};
}


sub oid_to_docxml_filename
{
    my ($opt_site,$collect_home,$collect,$docid) = @_;

    my $infodb_type = get_infodb_type($opt_site,$collect_home,$collect);

    # Derive the archives dir    
    my $archive_dir = &util::filename_cat($collect_home,$collect,"archives");

    # Obtain the doc.xml path for the specified docID
    my $arcinfo_doc_filename 
	= &dbutil::get_infodb_file_path($infodb_type, "archiveinf-doc", 
					$archive_dir);
    my $doc_rec
	= &dbutil::read_infodb_entry($infodb_type, $arcinfo_doc_filename, 
				     $docid);

    my $doc_xml_file = $doc_rec->{'doc-file'}->[0];
    my $assoc_path = dirname($doc_xml_file);

    # The $doc_xml_file is relative to the archives, so now let's get the 
    # full path
    my $doc_xml_filename = &util::filename_cat($archive_dir,$doc_xml_file);

    return ($doc_xml_filename,$assoc_path);
}

sub zip_up_archives_doc
{
    my ($gsdl_cgi,$collect_home,$collect,$doc_xml_filename,$assoc_path) = @_;

    my $timestamp = time(); 
    my $lang_env = $gsdl_cgi->clean_param("lr") || "";

    my $archive_dir = &util::filename_cat($collect_home,$collect,"archives");

    # Zip up the doc_xml file and all the files associated with it
    my $java = $gsdl_cgi->get_java_path();
    my $jar_dir= &util::filename_cat($ENV{'GSDLHOME'}, "bin", "java");
    my $java_classpath = &util::filename_cat($jar_dir,"GLIServer.jar");

    if (!-f $java_classpath) {
	my $progname = $0;
	$progname =~ s/^.*[\/\\]//;
	my $mess = "$progname:\nFailed to find $java_classpath\n";
	$gsdl_cgi->generate_error($mess);
    }

    my $zip_file = "$collect-$timestamp.zip";
    my $zip_file_path = &util::filename_cat($archive_dir,$zip_file);

    my $java_args = "\"$zip_file_path\" \"$archive_dir\" \"$assoc_path\"";

    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.ZipFiles $java_args"; 

    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	$gsdl_cgi->generate_error("Java failed: $java_command\n--\n$java_output\nExit status: " . ($java_status / 256) . "\n" . $gsdl_cgi->check_java_home());
    }

    # Check that the zip file was created successfully
    if (!-e $zip_file_path || -z $zip_file_path) {
	$gsdl_cgi->generate_error("Collection zip file $zip_file_path could not be created.");
    }

    return $zip_file_path;

}

sub main
{
    # Setup greenstone Perl include paths so additional packages can be found
    my $gsdl_cgi = gsdlCGI->new(); 
    $gsdl_cgi->setup_gsdl();

    my $gsdl_home = $gsdl_cgi->get_gsdl_home();
    my $collect_home = &util::filename_cat($gsdl_home,"collect");

    require dbutil;
    require talkback;
    require colcfg;

    my $oid     = $gsdl_cgi->param('oid');
    my $collect = $gsdl_cgi->param('fromCollect');
    my $toCollect = $gsdl_cgi->param('toCollect');
    my $site    = $gsdl_cgi->param('site');

    # sanity check
    if (!defined $oid || !defined $collect) {
	print STDOUT "Content-type:text/plain\n\n";
	print STDOUT "ERROR: Malformed CGI argments.  Need to specify 'oid' and 'collect'\n";
	exit 0;
    }

    my $uniq_prefix = "$collect-$oid";

    my ($docxml_filename,$assoc_path) 
	= oid_to_docxml_filename($site,$collect_home,$collect,$oid);

    my $zip_filename 
	= zip_up_archives_doc($gsdl_cgi,$collect_home,$collect,
			      $docxml_filename,$assoc_path);

    my $talktoUploadURL = $gsdl_cgi->param('talktoUpload');

    my $browser = LWP::UserAgent->new(agent => 'Perl File Upload');

    my $response = $browser->post(
	   $talktoUploadURL,
	   [ 'yes_upload'   => '1',
	     'process'      => '1',
	     'oid'          => $oid,
	     'toCollect'    => $toCollect,
	     'uploadedfile' => [$zip_filename, "$uniq_prefix-doc.zip"] 
	     ],
	   'Content_Type' => 'form-data'
	  );

    if ($response->is_success) {
	print "Content-type:text/html\n\n";
	print $response->content;
    }
    else {
	print $response->error_as_HTML;
    }

}

main();

