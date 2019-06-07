#!/usr/bin/perl -w

BEGIN 
{
    if (!defined $ENV{'GSDLHOME'}) {
	print STDERR "Environment variable GSDLHOME not set.\n";
	print STDERR "  Have you sourced Greenstone's 'setup.bash' file?\n";
	exit 1;
    }

    if (!defined $ENV{'JAVA_HOME'} && !defined $ENV{'JRE_HOME'}) {
	print STDERR "Neither JAVA_HOME nor JRE_HOME set.\n";
	print STDERR "Needed by Fedora command line scripts.\n";
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
use cfgread;
use colcfg;

use g2futil;

use dbutil;

my $arguments = 
    [ 
      { 'name' => "verbosity",
	'desc' => "Level of verbosity generated",
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
	'hiddengli' => "yes" }
      ];

my $prog_options 
    = { 'name' => "g2fbuildcol.pl",
	'desc' => "Ingest Greenstone directory of FedoraMETS documents into Fedora",
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

    my $collectdir = $options->{'collectdir'};

    if (!$collectdir) {
	if($ENV{'GSDL3HOME'}) {
	    $collectdir = &util::filename_cat($ENV{'GSDL3HOME'},"sites","localsite","collect");
	} else {
	    $collectdir = &util::filename_cat($ENV{'GSDLHOME'},"collect");
	}
    }

    my $full_gs_col = &util::filename_cat($collectdir,$gs_col);


    if (!-e $full_gs_col ) {
	print STDERR "Unable to find Greenstone collection $full_gs_col\n";
	exit 1;
    }

##    my $archives_dir = &util::filename_cat($full_gs_col,"archives");
    my $export_dir = &util::filename_cat($full_gs_col,"export");


    print "***\n";
    print "* Ingesting Greenstone processed files into Fedora $pid_namespace\n";
    print "***\n";

    # Following falls foul of Schematron rule checking
    my $fd_add_prog = "fedora-ingest";
#    my $fd_add_cmd;
#    $fd_add_args  = "dir $export_dir O metslikefedora1 $hostname:$port $username $password \\\n";
#    $fd_add_args .= "  \"Automated_ingest_by_gs2fed.pl\"";

#    &g2futil::run_cmd($fd_add_prog,$fd_add_args,$options);


    # => Ingest individually!

    # set up fedoragsearch for updating the index upon ingesting documents
    my $fedoragsearch_webapp = &g2futil::gsearch_webapp_folder();    

    # need the username and password preset in order to run fedoraGSearch's RESTClient script
    # this assumes that the fedoragsearch authentication details are the same as for fedora
    if (defined $fedoragsearch_webapp) {	
	$ENV{'fgsUserName'} = $options->{'username'};
	$ENV{'fgsPassword'} = $options->{'password'};
    }

    if (opendir(DIR, $export_dir)) {
	closedir DIR;
	## my @hash_dirs = grep { /\.dir$/ } readdir(DIR);
	my @hash_dirs = &g2futil::get_all_hash_dirs($export_dir);


	# for each hash dir, purge its respective PID
	foreach my $hd (@hash_dirs) {

	    my $hash_id = &g2futil::get_hash_id($hd);
	    
	    if (defined $hash_id) {

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

	    my $docmets_filename 
		= &util::filename_cat($hd,"docmets.xml");

	    print STDERR "<Build>\n" if $gli;

	    print "Ingesting $docmets_filename\n";

	    my $status = &g2futil::run_ingest($docmets_filename,$options);

	    # if the document was ingested into Fedora successfully, index it with GSearch next
	    if($status == 0) {
		if(defined $hash_id) {
		    my $pid = "$pid_namespace:$gs_col-$hash_id";
		    # now update the fedoragsearch index with the newly ingested document
		    &g2futil::run_update_index($fedoragsearch_webapp,$pid,$options) if defined $fedoragsearch_webapp;
		}
	    }

	    print STDERR "</Build>\n" if $gli;

	}	    
    }
    else {
	print STDERR "Error: Unable to open directory $export_dir: $!\n";
	exit 1;
    }


# can possibly use inexport instead of running buildcol.pl through system()
    print STDERR "**** Just for now, also run Greenstone's buildcol.pl\n";

    my $gs_opts = " -verbosity $verbosity";
    $gs_opts .= " -gli" if ($gli);
    $gs_opts .= " -collectdir \"$collectdir\"" if ($collectdir);
    $gs_opts .= " -mode infodb";

    my $gs_buildcol_arguments = "$gs_opts $gs_col";

    &g2futil::run_cmd("buildcol.pl", $gs_buildcol_arguments, $options);

    # read in collect cfg file to work out db type
    my $collectcfg = &util::filename_cat ($collectdir, $gs_col, "etc", "collectionConfig.xml");
    #print STDERR "**** collectcfg file: $collectcfg\n";
    unless(open(FIN, "<$collectcfg")) { 
	print STDERR "g2f-buildcol.pl: Unable to open $collectcfg...ERROR: $!\n";
	exit 1;	
    }
    close(FIN);

    # for now we assume GS3, since that's what the following gets implemented for
    my $collect_cfg = &colcfg::read_collection_cfg ($collectcfg, "gs3");
    # get the database type for this collection from its configuration file (may be undefined)
    my $infodbtype = $collect_cfg->{'infodbtype'} || &dbutil::get_default_infodb_type();
 
    # open .gdbm database file in building/text/$colname.gdb, using dbutil
    my $colname = $gs_col;
    $colname =~ s/(:?\\|\/)(.*)$/$1/; # remove any collect group from collection name to get tailname

    my $building_txt_dir = &util::filename_cat ($collectdir, $gs_col, "building", "text");
    my $building_txt_db = &dbutil::get_infodb_file_path($infodbtype, "$colname", $building_txt_dir);

    # foreach key that matches http://dir1/dir2/....file.xxx
    my $db_keys = {};
    &dbutil::read_infodb_keys($infodbtype,$building_txt_db, $db_keys);

    foreach my $key (keys %$db_keys) {
	if($key =~ m@^http://@) {

	    # get value for the key
	    my $src_rec = &dbutil::read_infodb_entry($infodbtype,$building_txt_db, $key);
	    my $OID_hash_value = $src_rec->{'section'}->[0];
	    $OID_hash_value = "$pid_namespace:$gs_col-".$OID_hash_value; # convert to fedoraPID

	    #   its fedora pid = "greenstone-http:$colname-http:||dir|file.xxx"
	    # except that fedorapids don't like extra colons and don't like |
	    my $fedora_identifier = "$pid_namespace-http:$gs_col-$key";
	    # CAN'T HAVE | OR : (as in "http:||one|two.html") in fedoraPID
	    $key =~ s@/@_@g; 
	    $key =~ s@:@-@g;
	    my $fedora_pid = "$pid_namespace-http:$gs_col-$key";

	    #   To run fedora ingest on the new file need to have sensible
	    #   filenames that won't offend windows	    
	    my $fedora_key_file_name = "$fedora_pid";
	    $fedora_key_file_name =~ s@\.@-@g;
	    $fedora_key_file_name =~ s/\:/=/g;
	    $fedora_key_file_name .= ".xml";
#	    print STDERR "+++++ fpid: $fedora_pid, fedora-key filename: $fedora_key_file_name\n";

	    #   write out a FedoraMets File for this key (in /tmp)
	    #   -> it has one metadata value, which is 'dc:title' = HASHxxxxxx
	    
	     # The HASHID shouldn't be the title: then will have
	     # duplicate titles and it will be hard to search for
	     # unique ones. What about making the filename the
	     # dc.title and the HASHID the dc.identifier

	    my $contents = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
	    $contents .= "<mets:mets xmlns:mets=\"http://www.loc.gov/METS/\"\n";
	    $contents .= " xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n";
	    $contents .= " xmlns:gsdl3=\"http://www.greenstone.org/namespace/gsdlmetadata/1.0/\"\n";
	    $contents .= " xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n";
	    $contents .= " xsi:schemaLocation=\"http://www.loc.gov/METS/\n";
	    $contents .= " http://www.loc.gov/standards/mets/mets.xsd\n";
	    $contents .= " http://www.greenstone.org/namespace/gsdlmetadata/1.0/\n";
	    $contents .= " http://www.greenstone.org/namespace/gsdlmetadata/1.0/gsdl_metadata.xsd\"\n";
	    $contents .= " OBJID=\"$fedora_pid\"\n";
#	    $contents .= " OBJID=\"greenstone:$gs_col-HASH1f814d07252c354039ee11\"\n";
	    $contents .= " TYPE=\"FedoraObject\" LABEL=\"$fedora_pid\" EXT_VERSION=\"1.1\">\n";
	    $contents .= "<mets:metsHdr RECORDSTATUS=\"A\"/>\n";
	    $contents .= "   <mets:amdSec ID=\"DC\" >\n";
	    $contents .= "      <mets:techMD ID=\"DC.0\">\n";
	    $contents .= "         <mets:mdWrap LABEL=\"Metadata\" MDTYPE=\"OTHER\" OTHERMDTYPE=\"gsdl3\" ID=\"DCgsdl1\">\n";
	    $contents .= "            <mets:xmlData>\n";
	    $contents .= "               <oai_dc:dc xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:oai_dc=\"http://www.openarchives.org/OAI/2.0/oai_dc/\" >\n";
	    $contents .= "                  <dc:title>$OID_hash_value</dc:title>\n";
#	    $contents .= "                  <dc:identifier>$fedora_identifier</dc:identifier>\n";
	    $contents .= "               </oai_dc:dc>\n";
	    $contents .= "            </mets:xmlData>\n";
	    $contents .= "         </mets:mdWrap>\n";
	    $contents .= "      </mets:techMD>\n";
	    $contents .= "   </mets:amdSec>\n";
	    $contents .= "</mets:mets>\n";	    

   
	    #   write out the file and then run fedora ingest on that file
	    #   The file gets purged in g2f-import.pl, so don't remove it from export dir now
	    my $fedora_key_file_path = &util::filename_cat($export_dir, $fedora_key_file_name);
	    unless(open(FOUT, ">$fedora_key_file_path")) { 
		print STDERR "g2f-buildcol.pl: Unable to open $fedora_key_file_path...ERROR: $!\n";
		exit 1;	
	    }
	    print FOUT $contents;
	    close(FOUT);

	    print STDERR "<Build>\n" if $gli;
	    print STDERR "Ingesting $fedora_key_file_name\n";
#	    print STDERR "#### ".join(",", %$options)."\n";

	    &g2futil::run_ingest($fedora_key_file_path,$options);
	    print STDERR "</Build>\n" if $gli;
	}
	
    }


    # If successful!!! Then need to think about:
    #    [CLX] nodes
    #    Doing this with FedoraMETSPlugin

    
    # for the Greenstone reader interface to make the new Fedora collection available,
    # need to write out buildConfig.xml with FedoraServiceProxy as a new ServiceRack element
    # Kathy thinks it's better to create a buildConfig.xml than put it in collectionConfig.xml
    
    my $indexdir = &util::filename_cat ($collectdir, $gs_col, "index");
    &util::mk_dir($indexdir) unless &util::dir_exists($indexdir);
    
    my $buildcfg = &util::filename_cat ($indexdir, "buildConfig.xml");
    if(-e $buildcfg) {
	print STDERR "***** $buildcfg already exists for this fedora collection.\n";
	print STDERR "***** Not modifying it to insert a FedoraServiceProxy ServiceRack.\n";
    } 
    else { # or do I just have a template buildConfig.xml that I copy over?
	
	my $contents = "<buildConfig>\n";
	$contents .= "  <metadataList/>\n";
	$contents .= "  <serviceRackList>\n";                                                            
	$contents .= "    <serviceRack name=\"FedoraServiceProxy\" />\n";
	$contents .= "  </serviceRackList>\n";
	$contents .= "</buildConfig>\n";
	
	#print STDERR "**** buildcfg file: $buildcfg\n";
	unless(open(FOUT, ">$buildcfg")) { 
	    print STDERR "g2f-buildcol.pl: Unable to open $buildcfg...ERROR: $!\n";
	    exit 1;	
	}
	print FOUT $contents;
	close(FOUT);
    }
}

&main(@ARGV);



