###########################################################################
#
# OAIDownload.pm -- base class for all the import plugins
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

package OAIDownload;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use strict;

use WgetDownload;
use XMLParser;

use POSIX qw(tmpnam);
use util;

sub BEGIN {
    @OAIDownload::ISA = ('WgetDownload');
}

my $arguments = 
    [ { 'name' => "url", 
	'disp' => "{OAIDownload.url_disp}",
	'desc' => "{OAIDownload.url}",
	'type' => "string",
	'reqd' => "yes"},
      { 'name' => "metadata_prefix", 
	'disp' => "{OAIDownload.metadata_prefix_disp}",
	'desc' => "{OAIDownload.metadata_prefix}",
	'type' => "string",
	'deft' => "oai_dc",
	'reqd' => "no"},
      { 'name' => "set", 
	'disp' => "{OAIDownload.set_disp}",
	'desc' => "{OAIDownload.set}",
	'type' => "string",
	'reqd' => "no"},
      { 'name' => "get_doc",
	'disp' => "{OAIDownload.get_doc_disp}",
	'desc' => "{OAIDownload.get_doc}",
	'type' => "flag",
	'reqd' => "no"},
      { 'name' => "get_doc_exts",
	'disp' => "{OAIDownload.get_doc_exts_disp}",
	'desc' => "{OAIDownload.get_doc_exts}",
	'type' => "string",
	'deft' => "doc,pdf,ppt",
	'reqd' => "no"},
      { 'name' => "max_records", 
	'disp' => "{OAIDownload.max_records_disp}",
	'desc' => "{OAIDownload.max_records}",
	'type' => "int",
	'range' => "1,",
	'reqd' => "no"} ];

my $options = { 'name'     => "OAIDownload",
		'desc'     => "{OAIDownload.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new 
{
    my ($class) = shift (@_);
    my ($getlist,$inputargs,$hashArgOptLists) = @_;
    push(@$getlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new WgetDownload($getlist,$inputargs,$hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    my $parser = new XML::Parser('Style' => 'Stream',
                                 'PluginObj' => $self,
				 'Handlers' => {'Char' => \&Char,
						'Start' => \&OAI_StartTag,
						'End' => \&OAI_EndTag
						});
    $self->{'parser'} = $parser;
    
    # make sure the tmp directory that we will use later exists
    my $tmp_dir = "$ENV{GSDLHOME}/tmp";
    if (! -e $tmp_dir) {
	&FileUtils::makeDirectory($tmp_dir);
    }

    # if max_records not specified, parsing will have set it to ""
    undef $self->{'max_records'} if $self->{'max_records'} eq "";

    # set up hashmap for individual items in get_doc_exts
    # to make testing for matches easier

    $self->{'lookup_exts'} = {};
    my $get_doc_exts = $self->{'get_doc_exts'};
    
    if ((defined $get_doc_exts) && ($get_doc_exts ne "")) {
	my @exts = split(/,\s*/,$get_doc_exts);
	foreach my $e (@exts) {
	    $self->{'lookup_exts'}->{lc($e)} = 1;
	}
    }


    return bless $self, $class;
}

sub download
{
    my ($self) = shift (@_);
    my ($hashGeneralOptions) = @_;

##    my $cmdWget = $strWgetOptions;
  
    my $strOutputDir ="";
    $strOutputDir = $hashGeneralOptions->{"cache_dir"};
    my $strBasURL = $self->{'url'};
    my $blnDownloadDoc = $self->{'get_doc'};

    print STDERR "<<Defined Maximum>>\n";

    my $strIDs = $self->getOAIIDs($strBasURL);
 
    if($strIDs eq "")
    {
	print STDERR "Error: No IDs found\n";
	return 0;
    }

    my $aryIDs = $self->parseOAIIDs($strIDs);
    my $intIDs = 0;
    if(defined $self->{'max_records'} && $self->{'max_records'} < scalar(@$aryIDs))
    {
	$intIDs = $self->{'max_records'};
    }
    else
    {
	$intIDs = scalar(@$aryIDs);
    }
    print STDERR "<<Total number of record(s):$intIDs>>\n";

    $self->getOAIRecords($aryIDs, $strOutputDir, $strBasURL, $self->{'max_records'}, $blnDownloadDoc);

#    my $tmp_file = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"tmp","oai.tmp");
#    &FileUtils::removeFiles($tmp_file); 

    return 1;
}

sub getOAIIDs
{
    my ($self,$strBasURL) = @_;
##    my ($cmdWget);
     
    my $wgetOptions = $self->getWgetOptions();

    my $cmdWget = $wgetOptions;
  
    print STDERR  "Gathering OAI identifiers.....\n";
    
    my $metadata_prefix = $self->{'metadata_prefix'};
    $cmdWget .= " -q -O - \"$strBasURL?verb=ListIdentifiers&metadataPrefix=$metadata_prefix";

    # if $set specified, add it in to URL
    my $set = $self->{'set'};
    $cmdWget .= "&set=$set" if ($set ne "");

    $cmdWget .= "\" ";

    my $accumulated_strIDs = "";
    my $strIDs =  $self->useWget($cmdWget);

    if (!defined $strIDs or $strIDs eq ""  ){
	print STDERR "Server information is unavailable.\n";
	print STDERR "<<Finished>>\n";
        return;  
    }
    if ($self->{'forced_quit'}) {
	return $strIDs;
    }

    print STDERR "<<Download Information>>\n";
    
    $self->parse_xml($strIDs);

    $accumulated_strIDs = $strIDs;
    my $max_recs = $self->{'max_records'};
    while ($strIDs =~ m/<resumptionToken.*?>\s*(.*?)\s*<\/resumptionToken>/s) { 
	# top up list with further requests for IDs

	my $resumption_token = $1;

	$cmdWget = $wgetOptions;

	$cmdWget .= " -q -O - \"$strBasURL?verb=ListIdentifiers&resumptionToken=$resumption_token\"";

	$strIDs =  $self->useWget($cmdWget);
	if ($self->{'forced_quit'}) {
	    return $accumulated_strIDs;
	}

	$self->parse_xml($strIDs);

	$accumulated_strIDs .= $strIDs;

	my @accumulated_identifiers 
	    = ($accumulated_strIDs =~ m/<identifier>(.*?)<\/identifier>/sg);

	my $num_acc_identifiers = scalar(@accumulated_identifiers);
	if (defined  $max_recs && $num_acc_identifiers > $max_recs ) {
	    last;
	}
    }

    return $accumulated_strIDs;
}

sub parseOAIIDs
{   
    my ($self,$strIDs) = @_;

    print STDERR "Parsing OAI identifiers.....\n";
    $strIDs =~ s/^.*?<identifier>/<identifier>/s;
    $strIDs =~ s/^(.*<\/identifier>).*$/$1/s;

    my @aryIDs = ();

    while ($strIDs =~ m/<identifier>(.*?)<\/identifier>(.*)$/s)
    {
	$strIDs = $2;
	push(@aryIDs,$1);
    }
    
    return \@aryIDs;
} 

sub dirFileSplit
{
    my ($self,$strFile) = @_;

    my @aryDirs = split("[/\]",$strFile);
   
    my $strLocalFile = pop(@aryDirs);
    my $strSubDirs = join("/",@aryDirs);

    return ($strSubDirs,$strLocalFile);
}

sub getOAIDoc
{
    my ($self,$strRecord, $oai_rec_filename) = @_;
 
    print  STDERR "Gathering source documents.....\n";
    # look out for identifier tag in metadata section
   
    if ($strRecord =~ m/<metadata>(.*)<\/metadata>/s)
    {
	my $strMetaTag = $1;
	my $had_valid_url = 0;
	my $count = 1;
	while ($strMetaTag =~ s/<(dc:)?identifier>(.*?)<\/(dc:)?identifier>//is)
	{
	    my $doc_id_url = $2;
	    print STDERR "Found doc url: $doc_id_url\n";
	    next if ($doc_id_url !~ m/^(https?|ftp):\/\//);

	    my $orig_doc_id_url = $doc_id_url;
	    $had_valid_url = 1;

	    my ($doc_dir_url_prefix,$doc_id_tail) = ($doc_id_url =~ m/^(.*)\/(.*?)$/);
	    my $faked_ext = 0;
	    my $primary_doc_match = 0;

	    my ($id_file_ext) = ($doc_id_tail =~ m/\.([^\.]+)$/);

	    if (defined $id_file_ext) {
		# cross-check this filename extension with get_doc_exts option
		# if provided
		my $lookup_exts = $self->{'lookup_exts'};

		if (defined $lookup_exts->{lc($id_file_ext)}) {
		    # this initial URL matches requirement
		    $primary_doc_match = 1;
		}
	    }
	    else {
		$faked_ext = 1;
		$id_file_ext = "html";
	    }


		my $is_page_html = 0;
		if($id_file_ext =~ m/^html?$/i) {
			$is_page_html = 1;
		} elsif ($doc_id_url) { # important: if no doc id has currently been typed into the url field, skip this block
		
			# get the page and check the header's content-type and see if this is text/html
			# if so, $is_page_html is true
			# See http://superuser.com/questions/197009/wget-head-request
			
			my $wget_opts3 = $self->getWgetOptions();
			my $wget_header_cmd = "$wget_opts3 -S --spider \"$doc_id_url\"";
			my $page_content = $self->useWget($wget_header_cmd);			
			
			if($page_content && $page_content =~ m@Content-Type:\s*text/html@i) {				
				$is_page_html = 1;
			}
		}
		
		if (!$primary_doc_match && $is_page_html) {		
		
		# Download this doc if HTML, scan through it looking for a link
		# that does match get_doc_exts
		

		# 1. Generate a tmp name
		my $tmp_filename = &util::get_tmp_filename();

		# 2. Download it
		my $wget_opts2 = $self->getWgetOptions();
		my $wget_cmd2 = "$wget_opts2 --convert-links -O \"$tmp_filename\" \"$doc_id_url\"";
		my ($stdout_and_err2,$error2,$follow2) =  $self->useWgetMonitored($wget_cmd2);
		return $strRecord if $self->{'forced_quit'};

		if($error2 ne "")
		{
		    print STDERR "Error occured while retrieving OAI source documents (1): $error2\n";
		    #exit(-1);
		    next; 
		}

		if (defined $follow2) {
		    # src url was "redirected" to another place
		    # => pick up on this and make it the new doc_id_url
		    $doc_id_url = $follow2;
		}

		my $primary_doc_html = "";
		if (open(HIN,"<$tmp_filename")) {
		    my $line;
		    while (defined ($line = <HIN>)) {
			$primary_doc_html .= $line;
		    }
		    close(HIN);

		    # 3. Scan through it looking for match
		    # 
		    # if got match, change $doc_id_url to this new URL and
		    # $id_file_ext to 'match' 
		    
		    my @href_links = ($primary_doc_html =~ m/href="(.*?)"/gsi);

		    my $lookup_exts = $self->{'lookup_exts'};

		    foreach my $href (@href_links) {
			my ($ext) = ($href =~ m/\.([^\.]+)$/);

			if ((defined $ext) && (defined $lookup_exts->{$ext})) {

			    if ($href !~ m/^(https?|ftp):\/\//) {
				# link is within current site
				my ($site_domain) = ($doc_id_url =~ m/^((?:https?|ftp):\/\/.*?)\//);

				$href = "$site_domain$href";
			    }

			    $doc_id_url = $href;
			    $id_file_ext = $ext;
			    last;
			}
		    }
		}
		else {
		    print STDERR "Error occurred while retrieving OAI source documents (2):\n";
		    print STDERR "$!\n";
		}

		if (-e $tmp_filename) {
		    &FileUtils::removeFiles($tmp_filename); 
		}
	    }

	    my $download_doc_filename = $oai_rec_filename;
		# As requested by John Rose, don't suffix -$count for the very first document (so no "-1" suffix):
	    my $new_extension = ($count > 1) ? "\-$count\.$id_file_ext" : "\.$id_file_ext";
	    $count++;
	    #$download_doc_filename =~ s/\.oai$/\.$id_file_ext/;
	    $download_doc_filename =~ s/\.oai$/$new_extension/;
	    my ($unused,$download_doc_file) = $self->dirFileSplit($download_doc_filename);

	    # may have &apos; in url - others??
	    my $safe_doc_id_url = $doc_id_url;
	    $safe_doc_id_url =~ s/&apos;/\'/g;

	    my $wget_opts = $self->getWgetOptions();
	    my $wget_cmd = "$wget_opts --convert-links -O \"$download_doc_filename\" \"$safe_doc_id_url\"";
	    
	    my ($stdout_and_err,$errors,$follow) =  $self->useWgetMonitored($wget_cmd);
	    return $strRecord if $self->{'forced_quit'};

	    if($errors ne "")
	    {
		print STDERR "Error occured while retriving OAI souce documents (3):\n";
		print STDERR "$errors\n";
		#exit(-1);
		next;
	    }

	    
	    $strRecord =~ s/<metadata>(.*?)<((?:dc:)?identifier)>$orig_doc_id_url<\/((?:dc:)?identifier)>(.*?)<\/metadata>/<metadata>$1<${2}>$orig_doc_id_url<\/${2}>\n   <gi.Sourcedoc>$download_doc_file<\/gi.Sourcedoc>$4<\/metadata>/s;
	}

	if (!$had_valid_url)
	{
	    print  STDERR "\tNo source document URL is specified in the OAI record (No (dc:)?identifier is provided)\n";
	}
    }
    else
    {
	print  STDERR "\tNo source document URL is specified in the OAI record (No metadata field is provided)\n";
    }

    return $strRecord;
}

sub getOAIRecords
{
    my ($self,$aryIDs, $strOutputDir, $strBasURL, $intMaxRecords, $blnDownloadDoc) = @_;
    my $intDocCounter = 0;

    my $metadata_prefix = $self->{'metadata_prefix'};

    foreach my $strID ( @$aryIDs)
    {
	print  STDERR "Gathering OAI record with ID $strID.....\n";
	   
	my $wget_opts = $self->getWgetOptions();
	my $cmdWget= "$wget_opts -q -O - \"$strBasURL?verb=GetRecord&metadataPrefix=$metadata_prefix&identifier=$strID\"";
	
	my $strRecord =  $self->useWget($cmdWget);

	my @fileDirs = split(":",$strID);  
	my $local_id = pop @fileDirs;

	# setup directories

        $strOutputDir  =~ s/"//g; #"

        my $host =$self->{'url'}; 
  
        $host =~ s@https?:\/\/@@g;

        $host =~ s/:.*//g; 

	my $strFileURL = "";
	if ($strOutputDir ne "") {
	    $strFileURL = "$strOutputDir/";
	}
	$strFileURL .= "$host/$local_id.oai";

	# prepare subdirectory for record (if needed)
	my ($strSubDirPath,$unused) = ("", "");

       	($strSubDirPath,$unused) = $self->dirFileSplit($strFileURL);
   
	&FileUtils::makeAllDirectories($strSubDirPath);

	my $ds = &util::get_dirsep();
	
	if($blnDownloadDoc)
	{
	    $strRecord = $self->getOAIDoc($strRecord,$strFileURL);
	}

	# save record 
	open (OAIOUT,">$strFileURL")
	    || die "Unable to save oai metadata record: $!\n";
	print OAIOUT $strRecord;
	close(OAIOUT);

        print STDERR "Saving record to $strFileURL\n";
        print STDERR "<<Done>>\n";
	$intDocCounter ++;	
	last if (defined $intMaxRecords && $intDocCounter >= $intMaxRecords);
    }

    (defined $intMaxRecords && $intDocCounter >= $intMaxRecords) ? 
	print  STDERR "Reached maximum download records, use -max_records to set the maximum.\n": 
	print  STDERR "Complete download meta record from $strBasURL\n";

       print STDERR "<<Finished>>\n";
}

sub url_information
{
    my ($self) = shift (@_);
    if(!defined $self){ die "System Error: No \$self defined for url_information in OAIDownload\n";}
    
    my $wgetOptions = $self->getWgetOptions();
    my $strBaseCMD = $wgetOptions." -q -O - \"$self->{'url'}?_OPTS_\"";
 
    my $strIdentify = "verb=Identify";
    my $strListSets = "verb=ListSets";
    my $strListMdFormats = "verb=ListMetadataFormats";

    my $strIdentifyCMD = $strBaseCMD;
    $strIdentifyCMD =~ s/_OPTS_/$strIdentify/;	

    my $strIdentifyText = $self->useWget($strIdentifyCMD);

     if (!defined $strIdentifyText or $strIdentifyText eq ""  ){
	print STDERR "Server information is unavailable.\n";
	print STDERR "<<Finished>>\n";
        return;  
    }

    print STDERR "General information:\n";
    $self->parse_xml($strIdentifyText);
    print STDERR "\n";

    print STDERR "=" x 10, "\n";
    print STDERR "Metadata Format Information (metadataPrefix):\n";
    print STDERR "=" x 10, "\n";

    my $strListMdFormatsCMD = $strBaseCMD;
    $strListMdFormatsCMD =~ s/_OPTS_/$strListMdFormats/;	
    my $strListMdFormatsText = $self->useWget($strListMdFormatsCMD);

    $self->parse_xml($strListMdFormatsText);
    print STDERR "\n";

    print STDERR "=" x 10, "\n";
    print STDERR "List Information:\n";
    print STDERR "=" x 10, "\n";

    my $strListSetCMD = $strBaseCMD;
    $strListSetCMD =~ s/_OPTS_/$strListSets/;	
    my $strListSetsText = $self->useWget($strListSetCMD);

    $self->parse_xml($strListSetsText);
}

sub parse_xml
{    
    my ($self) = shift (@_);
    my ($xml_text) = @_;
   
    #### change this to work directly from $xml_text

    #Open a temporary file to store OAI information, and store the information to the temp file
    my $name = &FileUtils::filenameConcatenate($ENV{GSDLHOME},"tmp","oai.tmp"); 

    open(*OAIOUT,"> $name");
	
    print OAIOUT $xml_text;
    close(OAIOUT);

    $self->{'temp_file_name'} = $name;

##    print STDERR "**** xml text = $xml_text\n";

    eval {
	$self->{'parser'}->parsefile("$name");
##	$self->{'parser'}->parse($xml_text);
    };

    if ($@) {
	die "OAI: Parsed file $name is not a well formed XML file ($@)\n";
##	die "OAI: Parsed text is not a well formed XML file ($@)\n";
    }

    unlink($self->{'temp_file_name'}) or die "Could not unlink $self->{'temp_file_name'}: $!";
}

####END 
#{
#    if($self->{'info'})
#    {
#	unlink($self->{'temp_file_name'}) or die "Could not unlink $self->{'temp_file_name'}: $!";
#    }
#}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {   
    use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+
    $_[0]->{'Text'} .= $_[1];

    my $self = $_[0]->{'PluginObj'};
    if ((defined $self->{'subfield'} && ($self->{'subfield'} ne ""))) {
	$self->{'text'} .= $_[1];
	$self->{'text'} =~ s/[\n]|([ ]{2,})//g;
	if($self->{'text'} ne "")
	{	    
	    print STDERR " $self->{'subfield'}:($self->{'text'})\n";
	}
    }
    return undef;
}

sub OAI_StartTag
{
    my ($expat, $element, %attr) = @_;

    my $self = $expat->{'PluginObj'};
    $self->{'subfield'} = $element;
    
}

sub OAI_EndTag
{
    my ($expat, $element) = @_;

    my $self = $expat->{'PluginObj'};
    $self->{'text'} = "";
    $self->{'subfield'} = "";
}

sub error
{
    my ($self,$strFunctionName,$strError) = @_;
    {
	print "Error occoured in OAIDownload.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}



1;
