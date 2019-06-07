###########################################################################
#
# WebDownload.pm -- base class for all the import plugins
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

package WebDownload;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use WgetDownload;

sub BEGIN {
    @WebDownload::ISA = ('WgetDownload');
}

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles
no strict 'subs'; # to pass STDERR/STDOUT to functions

use gsprintf 'gsprintf';

my $arguments = 
    [ { 'name' => "url", 
	'disp' => "{WebDownload.url_disp}",
	'desc' => "{WebDownload.url}",
	'type' => "string",
	'reqd' => "yes"},
      { 'name' => "depth", 
	'disp' => "{WebDownload.depth_disp}",
	'desc' => "{WebDownload.depth}",
	'type' => "int",
	'deft' => "0",
	"range" => "0,",
	'reqd' => "no"},
      { 'name' => "below", 
	'disp' => "{WebDownload.below_disp}",
	'desc' => "{WebDownload.below}",
	'type' => "flag",
	'reqd' => "no"},
      { 'name' => "within", 
	'disp' => "{WebDownload.within_disp}",
	'desc' => "{WebDownload.within}",
	'type' => "flag",
	'reqd' => "no"},
      { 'name' => "html_only", 
	'disp' => "{WebDownload.html_only_disp}",
	'desc' => "{WebDownload.html_only}",
	'type' => "flag",
	'reqd' => "no"}
      ];

my $options = { 'name'     => "WebDownload",
		'desc'     => "{WebDownload.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


my $self;

sub new 
{
    my ($class) = shift (@_);
    my ($getlist,$inputargs,$hashArgOptLists) = @_;
    push(@$getlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new WgetDownload($getlist,$inputargs,$hashArgOptLists);
    
    return bless $self, $class;
}

sub download
{
    my ($self) = shift (@_);
    my ($hashGeneralOptions) = @_;

  
    # Download options
    my $strOptions = $self->generateOptionsString();
    my $strWgetOptions = $self->getWgetOptions();
      
    # Setup the command for using wget
    my $cache_dir = "";
    if($hashGeneralOptions->{'cache_dir'}) { # don't provide the prefix-dir flag to wget unless the cache_dir is specified
	if ($ENV{'GSDLOS'} eq "windows") {    
	    $cache_dir = "-P \"".$hashGeneralOptions->{'cache_dir'}."\" ";
	}
	else {
	    $cache_dir = "-P ".$hashGeneralOptions->{'cache_dir'};
	}
    }
    #my $cmdWget = "-N -k -x -t 2 -P \"".$hashGeneralOptions->{"cache_dir"}."\" $strWgetOptions $strOptions ".$self->{'url'};
    #my $cmdWget = "-N -k -x --tries=2 $strWgetOptions $strOptions $cache_dir " .$self->{'url'};
    my $cmdWget = "-N -k -x $strWgetOptions $strOptions $cache_dir " .$self->{'url'};

    #print STDOUT "\n@@@@ RUNNING WGET CMD: $cmdWget\n\n";
	
    # Download the web pages
    # print "Start download from $self->{'url'}...\n";
    print STDERR "<<Undefined Maximum>>\n";
    
    if ($ENV{'GSDLOS'} eq "windows") {
	my $strResponse = $self->useWget($cmdWget,1);
    } else {
	my $strResponse = $self->useWget($cmdWget,1,$hashGeneralOptions->{"cache_dir"} );
	
    }
    
    # if ($strResponse ne ""){print "$strResponse\n";}
     print STDERR "Finished downloading from $self->{'url'}\n";

    print STDERR "<<Finished>>\n";
  
    return 1;
}

sub generateOptionsString
{
    my ($self) = @_;
    my $strOptions;

    (defined $self) || &error("generateOptionsString","No \$self is defined!!\n");
    (defined $self->{'depth'})|| &error("generateOptionsString","No depth is defined!!\n");
    
   
    if($self->{'depth'} == 0)
    {
	$strOptions .= " ";
    }
    elsif($self->{'depth'} > 0)
    {
	$strOptions .= "-r -l ".$self->{'depth'}." ";
    }
    else
    {
	$self->error("setupOptions","Incorrect Depth is defined!!\n");
    }

    if($self->{'below'})
    {
	$strOptions .="-np ";
    }

     if($self->{'html_only'})
    {
	$strOptions .="-A .html,.htm,.shm,.shtml,.asp,.php,.cgi,*?*=* ";
    }
    else{

	$strOptions .="-p ";
    }

    if (!$self->{'within'}){
	$strOptions .="-H ";
    }

    return $strOptions;
  
}

sub url_information
{
    my ($self) = shift (@_);

    my $strOptions = $self->getWgetOptions();

    #my $strBaseCMD = $strOptions." --tries=2 -q -O - \"$self->{'url'}\"";
    my $strBaseCMD = $strOptions." -q -O - $self->{'url'}";

    #&util::print_env(STDERR, "https_proxy", "http_proxy", "ftp_proxy");
    #&util::print_env(STDERR);	
    
    my $strIdentifyText = $self->useWget($strBaseCMD);
    
    if (!defined $strIdentifyText or $strIdentifyText eq ""  ){
	
	print STDERR "Server information is unavailable.\n";
	
	if ($self->{'proxy_on'}) { # if proxying set, the settings may be wrong
	    &gsprintf::gsprintf(STDERR, "{WebDownload.proxied_connect_failed_info}\n");
	    
	    if($self->{'http_proxy_host'} && defined $self->{'http_proxy_port'}) {
		&gsprintf::gsprintf(STDERR, "{WebDownload.http_proxy_settings}\n", $self->{'http_proxy_host'}, $self->{'http_proxy_port'});
	    }
	    if($self->{'https_proxy_host'} && defined $self->{'https_proxy_port'}) {
		&gsprintf::gsprintf(STDERR, "{WebDownload.https_proxy_settings}\n", $self->{'https_proxy_host'}, $self->{'https_proxy_port'});
	    }
	    if($self->{'ftp_proxy_host'} && defined $self->{'ftp_proxy_port'}) {
		&gsprintf::gsprintf(STDERR, "{WebDownload.ftp_proxy_settings}\n", $self->{'ftp_proxy_host'}, $self->{'ftp_proxy_port'});
	    }
	} else { # else no proxy set, the user may need proxy settings
	    &gsprintf::gsprintf(STDERR, "{WebDownload.proxyless_connect_failed_info}\n");
	}
	
	# with or without proxying set, getting server info may have failed if the URL was https
	# but the site had no valid certificate and no_check_certificate wasn't turned on
	# suggest to the user to try turning it on
	&gsprintf::gsprintf(STDERR, "{WebDownload.connect_failed_info}\n");
	
	print STDERR "<<Finished>>\n";
	return;  
    }

    while ($strIdentifyText =~ m/^(.*)<title>(.*?)<\/title>(.*)$/si)
    {
	$strIdentifyText = $1.$3;
	print STDERR "Page Title: $2\n";
    }
  
    while ($strIdentifyText =~ m/^(.*)<meta (.*?)>(.*)$/si)
    {
	$strIdentifyText = $1.$3;
	my $strTempString = $2;
	print STDERR "\n";

	while($strTempString =~ m/(.*?)=[\"|\'](.*?)[\"|\'](.*?)$/si)
	{
	    # Store the infromation in to variable, since next time when we do 
	    # regular expression, we will lost all the $1, $2, $X....
	    $strTempString = $3;
	    my $strMetaName = $1;
	    my $strMetaContain = $2;
	    
	    # Take out the extra space in the beginning of the string.
	    $strMetaName =~ s/^([" "])+//m;
	    $strMetaContain =~ s/^([" "])+//m;
              
	    print STDERR "$strMetaName: $strMetaContain\n\n";
           
	}

    }

    print STDERR "<<Finished>>\n";

}


sub error
{
    my ($strFunctionName,$strError) = @_;
    {
	print "Error occoured in WebDownload.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}

1;

