#!/usr/bin/perl -w

BEGIN 
{
    if (!defined $ENV{'GSDLHOME'}) {
	print STDERR "Environment variable GSDLHOME not set.\n";
	print STDERR "  Have you sourced Greenstone's 'setup.bash' file?\n";
	exit 1;
    }

    $ENV{'FEDORA_HOSTNAME'} = "localhost" if (!defined $ENV{'FEDORA_HOSTNAME'});
    $ENV{'FEDORA_SERVER_PORT'} = "8080" if (!defined $ENV{'FEDORA_SERVER_PORT'});
    $ENV{'FEDORA_USER'}     = "fedoraAdmin" if (!defined $ENV{'FEDORA_USER'});
    $ENV{'FEDORA_PASS'}     = "fedoraAdmin" if (!defined $ENV{'FEDORA_PASS'});
    $ENV{'FEDORA_PROTOCOL'} = "http" if (!defined $ENV{'FEDORA_PROTOCOL'});
    $ENV{'FEDORA_PID_NAMESPACE'} = "greenstone" if (!defined $ENV{'FEDORA_PID_NAMESPACE'});
    $ENV{'FEDORA_PREFIX'} = "/fedora" if (!defined $ENV{'FEDORA_PREFIX'});

    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/");
}


use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (e.g. STDERR) as function arguments

use util;
use gsprintf 'gsprintf';
use printusage;
use parse2;


use g2futil;


my $arguments = 
    [ 
      { 'name' => "verbosity",
	'desc' => "{import.verbosity}",
	'type' => "string",
	'deft' => '1',
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "hostname",
	'desc' => "Domain hostname of Fedora server",
	'type' => "string",
	'deft' => $ENV{'FEDORA_HOSTNAME'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "port",
	'desc' => "Port that the Fedora server is running on.",
	'type' => "string",
	'deft' => $ENV{'FEDORA_SERVER_PORT'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "username",
	'desc' => "Fedora admin username",
	'type' => "string",
	'deft' => $ENV{'FEDORA_USER'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "password",
	'desc' => "Fedora admin password",
	'type' => "string",
	'deft' => $ENV{'FEDORA_PASS'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "protocol",
	'desc' => "Fedora protocol, e.g. 'http' or 'https'",
	'type' => "string",
	'deft' => $ENV{'FEDORA_PROTOCOL'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "pidnamespace",
	'desc' => "Fedora prefix for PIDs",
	'type' => "string",
	'deft' => $ENV{'FEDORA_PID_NAMESPACE'},
	'reqd' => "no",
        'hiddengli' => "no" },
      { 'name' => "maxdocs",
	'desc' => "{import.maxdocs}",
	'type' => "int",
	'reqd' => "no",
	'range' => "1,",
	'modegli' => "1" },
      { 'name' => "gli",
	'desc' => "",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "removeold",
	'desc' => "{import.removeold}",
	'type' => "flag",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
	'modegli' => "3" },
      { 'name' => "collectdir",
	'desc' => "{import.collectdir}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no",
	'hiddengli' => "yes" },


      ];

my $prog_options 
    = { 'name' => "g2fimport.pl",
	'desc' => "Generate Fedora METS format using Greenstone document processing capabilities",
	'args' => $arguments };


sub main
{
    my (@ARGV) = @_;

    my $GSDLHOME = $ENV{'GSDLHOME'};


    my $options = {};
    # general options available to all plugins
    my $intArgLeftinAfterParsing = parse2::parse(\@ARGV,$arguments,$options,"allow_extra_options");

    # Something went wrong with parsing
    if ($intArgLeftinAfterParsing ==-1)
    {
	&PrintUsage::print_txt_usage($prog_options, "[options] greenstone-col");
	die "\n";
    }

    my $xml = $options->{'xml'};
    my $gli = $options->{'gli'};

    if ($intArgLeftinAfterParsing != 1)
    {
	if ($xml) {
	    &PrintUsage::print_xml_usage($prog_options);
	    print "\n";
	    return;
	}
	else {
	    &PrintUsage::print_txt_usage($prog_options, "[options] greenstone-col");
	    print "\n";
	    return;
	}
	    
    }

    if ($gli) { # the gli wants strings to be in UTF-8
	&gsprintf::output_strings_in_UTF8; 
    }

    my $gs_col = $ARGV[0];

    my $verbosity = $options->{'verbosity'};
    my $hostname  = $options->{'hostname'}; 
    my $port      = $options->{'port'};
    my $username  = $options->{'username'};
    my $password  = $options->{'password'};
    my $protocol  = $options->{'protocol'};
    my $pid_namespace = $options->{'pidnamespace'};

    # The following are needed in the FedoraMETS plugout
    $ENV{'FEDORA_HOSTNAME'} = $hostname;
    $ENV{'FEDORA_SERVER_PORT'} = $port;

    my $language   = $options->{'language'};
    my $collectdir = $options->{'collectdir'};
    my $removeold  = $options->{'removeold'};
    my $maxdocs    = $options->{'maxdocs'};

    if (!$collectdir) {
	# Explicitly set one, depending on whether it's GS2 or GS3
	if($ENV{'GSDL3HOME'}) {
	    $collectdir = &util::filename_cat($ENV{'GSDL3HOME'},"sites","localsite","collect");
	} else {
	    $collectdir = &util::filename_cat($ENV{'GSDLHOME'},"collect");
	}
    }

    # if GS3, and if Fedora uses Greenstone 3's tomcat, then we do not need to write out the file gsdl.xml into Fedora's tomcat
    my $localfedora = &util::filename_cat($ENV{'GSDL3SRCHOME'}, "packages", "tomcat", "conf", "Catalina", "localhost", "fedora.xml");
    unless($ENV{'GSDL3SRCHOME'} && -e $localfedora) {
	# method that will tell Fedora where the ultimate output of g2f-import and g2f-build
	# will be found: Points Fedora to the collect directory where FedoraMETS will be output.
	&g2futil::write_gsdl_xml_file($hostname, $collectdir, $options);
    }

    my $full_gs_col = &util::filename_cat($collectdir,$gs_col);

    if (!-e $full_gs_col ) {
	print STDERR "Unable to find Greenstone collection $full_gs_col\n";
	exit 1;
    }

    my $export_dir = &util::filename_cat($full_gs_col,"export");

    if ( -e $export_dir ) {
        print "***\n";
	print "* Updating existing Greenstone $gs_col objects from Fedora $pid_namespace\n";
        print "***\n";

	# set up fedoragsearch for updating the index upon ingesting documents
	my $fedoragsearch_webapp = &g2futil::gsearch_webapp_folder();
	
	# need the username and password preset in order to run fedoraGSearch's RESTClient script
	# this assumes that the fedoragsearch authentication details are the same as for fedora
	if (defined $fedoragsearch_webapp) {	
	    $ENV{'fgsUserName'} = $options->{'username'};
	    $ENV{'fgsPassword'} = $options->{'password'};
	}

	# readdir
	if (opendir(DIR, $export_dir)) {
	    my @xml_files = grep { $_ =~ m/^greenstone-http.*\.xml$/ } readdir(DIR);
	    closedir DIR;

	    # purge all the (URL,hashID) metadata files that we inserted
	    # into fedora at the end of g2f-buildcol.pl
	    # convert the filenames into fedora-pids
	    # filename = greenstone-http=tmpcol-http-__test1-html.xml -> fpid = greenstone-http:tmpcol-http-__test1.html
	    foreach my $file (@xml_files) {
		my $fedora_pid = $file;
		$fedora_pid =~ s/\.xml$//;
		$fedora_pid =~ s/\=/:/;
		$fedora_pid =~ s/(.*)-(.*)$/$1.$2/;
		
#		print STDERR "#### fedora_pid: $fedora_pid\n";
		&g2futil::run_purge($fedora_pid,$options); # displays error message if first time (nothing to purge)
	    }

	    my @hash_dirs = &g2futil::get_all_hash_dirs($export_dir,$maxdocs);

	    # for each hash dir, purge its respective PID
	    foreach my $full_hd (@hash_dirs) {

		my $hash_id = &g2futil::get_hash_id($full_hd);

		next if !defined $hash_id;

		my $pid = "$pid_namespace:$gs_col-$hash_id";

		my $dsinfo_status = &g2futil::run_datastore_info($pid,$options);

		if ($dsinfo_status == 0) {
		    # first remove the doc from the gsearch index before removing it from the fedora repository
		    print "  deleting $pid from GSearch index\n";
		    &g2futil::run_delete_from_index($fedoragsearch_webapp,$pid,$options) if defined $fedoragsearch_webapp;

		    print "  $pid being updated.\n";	    
		    &g2futil::run_purge($pid,$options);
		}
		else {
		    print "  $pid not present.\n";
		}
	    }	    
	}
	else {
	    print STDERR "Error: Unable to open directory $export_dir: $!\n";
	    exit;
	}
    }

    print "***\n";
    print "* Processing $gs_col into FedoraMETS format\n";
    print "***\n";

    my $gs_export_opts = "-saveas FedoraMETS -fedora_namespace $pid_namespace";

    my $gs_opts = " -verbosity $verbosity";
    $gs_opts .= " -gli" if ($gli);

    $gs_opts .= " -language $language" if ($language);
    $gs_opts .= " -collectdir \"$collectdir\"" if ($collectdir);
    $gs_opts .= " -removeold" if ($removeold);
    $gs_opts .= " -maxdocs $maxdocs" if ($maxdocs);

    $gs_export_opts .= " $gs_opts -exportdir \"$export_dir\"";

    my $gs_export_arguments = "$gs_export_opts $gs_col";

    &g2futil::run_cmd("export.pl", $gs_export_arguments, $options);

    print STDERR "**** Just for now, also run Greenstone's import.pl\n";
# if we have the FedoraMETSPlugIN then we wouldn't have to run import anymore
    my $gs_import_arguments = "$gs_opts $gs_col";

    &g2futil::run_cmd("import.pl", $gs_import_arguments, $options);
}

&main(@ARGV);



