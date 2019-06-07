#!/usr/bin/perl -w

###########################################################################
#
# importfrom.pl --
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


# This program will contact the named DL server
#  and export its metadata and (optionally) it documents.

# Currently only designed for OAI exporting

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use colcfg;
use util;
use FileUtils;
use parsargv;
use FileHandle;

my $wgetopt = "";

my $num_processed = 0;

sub print_usage {
    print STDERR "\n  usage: $0 [options] collection-name\n\n";
    print STDERR "  options:\n";
    print STDERR "   -verbosity number      0=none, 3=lots\n";
    print STDERR "   -getdoc                Also download if source document if present\n";
    print STDERR "   -importdir directory   Where the original material lives\n";
    print STDERR "   -keepold               Will not destroy the current contents of the\n";
    print STDERR "                          import directory (the default)\n";
    print STDERR "   -removeold             Will remove the old contents of the import\n";
    print STDERR "                          directory -- use with care\n";
    print STDERR "   -gzip                  Use gzip to compress exported documents\n";
    print STDERR "                          (don't forget to include ZIPPlugin in your plugin\n";
    print STDERR "   -maxdocs number        Maximum number of documents to import\n";
    print STDERR "   -debug                 Print imported text to STDOUT\n";
    print STDERR "   -collectdir directory  Collection directory (defaults to " .
	&FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect") . ")\n";
    print STDERR "   -out                   Filename or handle to print output status to.\n";
    print STDERR "                          The default is STDERR\n\n";
}



sub xml_pretty_print
{
    my ($text,$out,$verbosity) = @_;

    if (system("xmllint --version >/dev/null 2>&1")!=0) {
	if ($verbosity>1) {
	    print STDERR "Warning: Unable to find xmllint for pretty printing.\n";
	    print STDERR "         XML will be shown verbatim.\n\n";
	}
	print $out $text;
    }
    else {

	if (!open (PPOUT,"|xmllint --format -")) {
	    print STDERR "Error running xmllint: $!\n\n";
	    print $out $text;
	    return;
	}

	print PPOUT $text;
	close(PPOUT);
    }
}

sub wget_oai_url 
{
    my ($wget_cmd,$out,$verbosity) = @_;

    # the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
    &util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

    if ($verbosity>2) {
	print $out "  $wget_cmd\n";
    }

    open (OAIIN,"$wget_cmd |")
	|| die "wget request failed: $!\n";
 
    my $li_record = "";

    my $line;
    while (defined($line=<OAIIN>))
    {
	$li_record .= $line;
	# print $out $line;
    }

    close(OAIIN);

    return $li_record;
}

sub oai_info
{
    my ($base_url,$out,$verbosity) = @_;

    my $base_wget_cmd = "wget $wgetopt -q -O - \"$base_url?_OPTS_\"";
 
    my $identify = "verb=Identify";
    my $list_sets = "verb=ListSets";
    my $list_md_formats = "ListMetadataFormats"; # not currently used

    my $identify_cmd = $base_wget_cmd;
    $identify_cmd =~ s/_OPTS_/$identify/;
    print $out "-------------------\n";
    print $out "General Information\n";
    print $out "-------------------\n";
    my $identify_text = wget_oai_url($identify_cmd,$out,$verbosity);
    xml_pretty_print($identify_text,$out,$verbosity);

    
    my $list_sets_cmd = $base_wget_cmd;
    $list_sets_cmd =~ s/_OPTS_/$list_sets/;
    print $out "-------------------\n";
    print $out "Set Information\n";
    print $out "-------------------\n";
    my $list_sets_text = wget_oai_url($list_sets_cmd,$out,$verbosity);
    xml_pretty_print($list_sets_text,$out,$verbosity);
}


sub get_oai_ids
{
    my ($base_url, $set, $format, $out, $verbosity) = @_;

    print $out "Requesting list of identifiers ...\n";
    
    my $base_wget_cmd = "wget $wgetopt -q -O - \"$base_url?_OPTS_\"";
    my $identifiers_cmd = $base_wget_cmd;

    my $identifiers_opts = "verb=ListIdentifiers&metadataPrefix=$format";

    if (defined $set && ($set ne "")) {
	$identifiers_opts .= "&set=$set";
    }

    $identifiers_cmd =~ s/_OPTS_/$identifiers_opts/;

    my $li_record = wget_oai_url($identifiers_cmd,$out,$verbosity);

    print $out "... Done.\n";

    return $li_record;
}

sub parse_oai_ids
{
    my ($li_record, $out, $verbosity) = @_;

    # extract identifier list
    $li_record =~ s/^.*?<identifier>/<identifier>/s;
    $li_record =~ s/^(.*<\/identifier>).*$/$1/s;

    my @ids = ();

    while ($li_record =~ m/<identifier>(.*?)<\/identifier>(.*)$/s)
    {
	$li_record = $2;
	push(@ids,$1);
    }

    return \@ids;
}


sub dir_file_split
{
    my ($file) = @_;

    my @dirs = split("/",$file);
    my $local_file = pop(@dirs);
    my $sub_dirs = join("/",@dirs);

    return ($sub_dirs,$local_file);
}

sub get_oai_document
{
    my ($doc_url,$output_dir, $out) = @_;

    my ($id_dir,$id_fname) = dir_file_split($doc_url);

    print $out "Getting document $doc_url\n";

    &FileUtils::makeDirectory($output_dir)  if (!-e "$output_dir");

    my $full_id_fname = &FileUtils::filenameConcatenate($output_dir,$id_fname);

    my $wget_cmd = "wget $wgetopt --quiet -O \"$full_id_fname\" \"$doc_url\"";

    # the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
    &util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

    if (system($wget_cmd)!=0) {
	print STDERR "Error: failed to execute $wget_cmd\n";
	return 0;
    }

    return 1;    
}

sub get_oai_records
{
    my ($base_url,$format, $ids,$output_dir, $get_id, $maxdocs, $out) = @_;

    my $doc_count = 0;

    my $i;
    foreach $i ( @$ids )
    {
	# wget it;
	my $url = "$base_url?verb=GetRecord&metadataPrefix=$format";
	$url .= "&identifier=$i";
	print $out "Downloading metadata record for $i\n";

        my $i_url = $i; #convert OAI set separators (:) to directory sep
        $i_url =~ s/:/\//g;
	my $file_i_url = "$output_dir/$i_url.oai";

	my $ds = &util::get_dirsep();
	my $i_os = $i; #convert OAI set separators (:) to OS dir sep
	$i_os =~ s/:/$ds/g;
	my $file_i = &FileUtils::filenameConcatenate($output_dir,"$i_os.oai");

	# obtain record
	my $wget_cmd = "wget $wgetopt -q -O - \"$url\"";

	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

	open (OAIIN,"$wget_cmd|")
	    || die "wget request failed: $!\n";
	my $i_record = "";
	
	my $line;
	while (defined($line=<OAIIN>))
	{
	    $i_record .= $line;
	}

	close(OAIIN);

	$num_processed++;
	
	# prepare subdirectory for record (if needed)
	my ($i_dir,$unused) = dir_file_split($file_i_url);

	&FileUtils::makeAllDirectories($i_dir);

	# look out for identifier tag in metadata section
	if ($i_record =~ m/<metadata>(.*)<\/metadata>/s)
	{
	    my $m_record = $1;

	    if ($get_id)
	    {
		my $got_doc = 0;

		my @url_matches = ($m_record =~ m/<(?:dc:)?identifier>(.*?)<\/(?:dc:)?identifier>/gs);
		foreach my $doc_url (@url_matches) 
		{
		    if ($doc_url =~ m/^(http|ftp):/) {

			my $revised_doc_url = $doc_url;
##			$revised_doc_url =~ s/hdl\.handle\.net/mcgonagall.cs.waikato.ac.nz:8080\/dspace\/handle/;
			
			my $srcdocs_dir = &FileUtils::filenameConcatenate($i_dir,"srcdocs");

			if (get_oai_document($revised_doc_url,$srcdocs_dir, $out)) {			   

			    $got_doc = 1;
			    my ($id_dir,$id_fname) = dir_file_split($revised_doc_url);
			    
			    $i_record =~ s/<metadata>(.*?)<(dc:)?identifier>$doc_url<\/(dc:)?identifier>(.*?)<\/metadata>/<metadata>$1<OrigURL>$doc_url<\/OrigURL>\n   <identifier>srcdocs\/$id_fname<\/identifier>$4<\/metadata>/s;
			    
			}
		    }

		    if (!$got_doc) {
			$i_record =~ s/<metadata>(.*?)<(dc:)?identifier>$doc_url<\/(dc:)?identifier>(.*?)<\/metadata>/<metadata>$1<OrigIdentifier>$doc_url<\/OrigIdentifier>$4<\/metadata>/s;
		    }
		}
	    }
	}

	# save record 
	open (OAIOUT,">$file_i")
	    || die "Unable to save oai metadata record: $!\n";
	print OAIOUT $i_record;
	close(OAIOUT);

	$doc_count++;
	last if ($doc_count == $maxdocs);
    }
}


sub main {
    my ($verbosity, $importdir, $keepold, 
	$getdoc, $acquire_info, $acquire_set,
	$removeold, $gzip, $groupsize, $debug, $maxdocs, $collection,
	$configfilename, $collectcfg,
	$out, $collectdir);

    if (!parsargv::parse(\@ARGV, 
			 'verbosity/\d+/2', \$verbosity,
			 'getdoc', \$getdoc,
			 'info', \$acquire_info,
			 'importdir/.*/', \$importdir,
			 'keepold', \$keepold,
			 'removeold', \$removeold,
			 'gzip', \$gzip,
			 'debug', \$debug,
			 'maxdocs/^\-?\d+/-1', \$maxdocs,
			 'collectdir/.*/', \$collectdir,
			 'out/.*/STDERR', \$out)) {
	&print_usage();
	die "\n";
    }

    my $close_out = 0;
    if ($out !~ /^(STDERR|STDOUT)$/i) {
	open (OUT, ">$out") || die "Couldn't open output file $out\n";
	$out = 'import::OUT';
	$close_out = 1;
    }
    $out->autoflush(1);

    # set removeold to false if it has been defined
    $removeold = 0 if ($keepold);

    # get and check the collection name
    if (($collection = &util::use_collection(@ARGV, $collectdir)) eq "") {
	&print_usage();
	die "\n";
    }


    # get acquire list
    my $acquire = [];
    $configfilename = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "etc", "collect.cfg");
    if (-e $configfilename) {
	$collectcfg = &colcfg::read_collect_cfg ($configfilename);
	if (defined $collectcfg->{'acquire'}) {
	    $acquire = $collectcfg->{'acquire'};
	}
	if (defined $collectcfg->{'importdir'} && $importdir eq "") {
	    $importdir = $collectcfg->{'importdir'};
	}
	if (defined $collectcfg->{'removeold'}) {
	    if ($collectcfg->{'removeold'} =~ /^true$/i && !$keepold) {
		$removeold = 1;
	    }
	    if ($collectcfg->{'removeold'} =~ /^false$/i && !$removeold) {
		$removeold = 0;
	    }
	}
    } else {
	die "Couldn't find the configuration file $configfilename\n";
    }
    
    # fill in the default import directory if none
    # were supplied, turn all \ into / and remove trailing /
    $importdir = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "import") if $importdir eq "";
    $importdir =~ s/[\\\/]+/\//g;
    $importdir =~ s/\/$//;

    # remove the old contents of the import directory if needed
    if ($removeold && -e $importdir) {
	print $out "Warning - removing current contents of the import directory\n";
	print $out "          in preparation for the acquire\n";
	&FileUtils::removeFilesRecursive($importdir);
    }

    my $e;
    foreach $e ( @$acquire )
    {
	my $acquire_type = shift @$e;
	my $acquire_src = undef;

	if ($acquire_type ne "OAI") {
	    print STDERR "Warning: $acquire_type not currently supported. Skipping.\n";
	    next;
	}

	my $store_getdoc = $getdoc;

	if (!parsargv::parse($e, 
			     'getdoc',  \$getdoc,
			     'set/.*/', \$acquire_set,
			     'format/.*/oai_dc', \$metadata_format,
			     'src/.*/', \$acquire_src)) {
	    &print_usage();
	    die "\n";
	}

	if (!defined $acquire_src) {
	    print STDERR "Warning: Not -src flag defined.  Skipping.\n";
	    next;
	}

	if (defined $acquire_info && ($acquire_info)) {
	    oai_info($acquire_src,$out,$verbosity);
	    next;
	}

	print $out "$acquire_type Acquire: from $acquire_src\n";

	my $li_record = get_oai_ids($acquire_src,$acquire_set,$metadata_format,
				    $out,$verbosity);
	my $ids = parse_oai_ids($li_record,$out,$verbosity);

	get_oai_records($acquire_src,$metadata_format, $ids,$importdir, 
			$getdoc, $maxdocs, $out);
	$getdoc = $store_getdoc;
    }

    print "\nNumber of documents processed: $num_processed\n";

    close OUT if $close_out;
}


&main();








