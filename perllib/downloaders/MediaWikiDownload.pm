###########################################################################
#
# MediaWikiDownload.pm -- downloader for wiki pages
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

package MediaWikiDownload;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use WgetDownload;

sub BEGIN {
    @MediaWikiDownload::ISA = ('WgetDownload');
}

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles

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
      { 'name' => "reject_files",
	'disp' => "{MediaWikiDownload.reject_filetype_disp}",
	'desc' => "{MediaWikiDownload.reject_filetype}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "*action=*,*diff=*,*oldid=*,*printable*,*Recentchangeslinked*,*Userlogin*,*Whatlinkshere*,*redirect*,*Special:*,Talk:*,Image:*,*.ppt,*.pdf,*.zip,*.doc"},
      { 'name' => "exclude_directories",
	'disp' => "{MediaWikiDownload.exclude_directories_disp}",
	'desc' => "{MediaWikiDownload.exclude_directories}",
	'type' => "string",
	'reqd' => "no",
	'deft' => "/wiki/index.php/Special:Recentchangeslinked,/wiki/index.php/Special:Whatlinkshere,/wiki/index.php/Talk:Creating_CD"},
      ];

my $options = { 'name'     => "MediaWikiDownload",
		'desc'     => "{MediaWikiDownload.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

my $wget_options = "";

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
    $wget_options = "-N -k -x -t 2 -P \"". $hashGeneralOptions->{"cache_dir"}."\" $strWgetOptions $strOptions ";
    my $cmdWget = "-N -k -x -t 2 -P \"". $hashGeneralOptions->{"cache_dir"}."\" $strWgetOptions $strOptions " . $self->{'url'};
    
    # Download the web pages
    # print "Strat download from $self->{'url'}...\n";
    print STDERR "<<Undefined Maximum>>\n";

    my $strResponse = $self->useWget($cmdWget,1);
 
    # if ($strResponse ne ""){print "$strResponse\n";}
        
    print STDERR "Finish download from $self->{'url'}\n";
    
    # check css files for HTML pages are downloaded as well
    $self->{'url'} =~ /http:\/\/([^\/]*)\//;        
    my $base_url = &FileUtils::filenameConcatenate($hashGeneralOptions->{"cache_dir"}, $1);    
    &check_file($base_url, $self);
        
    print STDERR "<<Finished>>\n";
  
    return 1;
}

sub check_file 
{    
    my $dir = shift;
    my ($self) = shift;
    
    local *DIR; 
     
    opendir DIR, $dir or return;
    
    my @contents = grep { $_ ne '.' and $_ ne '..' } readdir DIR;
    
    closedir DIR;
    
    foreach (@contents) {
      # broad-first search
      &check_file("$dir/$_", $self);
      
      # read in every HTML page and check the css associated with import statement already exists.
      &check_imported_css($self, "$dir/$_");
    }
} 

sub check_imported_css
{
    my ($self) = shift(@_);    
    my $downloaded_file = shift(@_);
            
    $downloaded_file =~ /(.+)(\/|\\)cache(\/|\\)([^\/\\]+)(\/|\\)/;
    
    # external website url, to make up the stylesheet urls
    my $base_website_url = $4;
    
    # the cache download file directory
    my $base_dir = "$1$2cache$3$4" if defined $base_website_url;
    
    if($downloaded_file=~/(.+)\.(html|htm)/) {
      my $content = "";
      if(open(INPUT, "<$downloaded_file")){
	while(my $line = <INPUT>){
          $content .= $line;
	}
        close(INPUT);
      }
      
      my @css_files;
      my @css_files_paths;
      my $css_file_count = 0;
      while($content =~ /<style type="text\/css"(.+)?import "(.+)?"/ig){
	$css_files[$css_file_count] = $base_website_url . $2 if defined $2;
        $css_files_paths[$css_file_count] = $base_dir . $2 if defined $2;
        $css_file_count++;
      }
      
      for($css_file_count=0; $css_file_count<scalar(@css_files); $css_file_count++) {        
        my $css_file = "http://" . $css_files[$css_file_count];
        my $css_file_path = $css_files_paths[$css_file_count];
        
        # trim the ? mark append to the end of a stylesheet
        $css_file =~ s/\?([^\/\.\s]+)$//isg;         
        $css_file_path =~ s/\?([^\/\.\s]+)$//isg;         
        
        # do nothing if the css file existed
        next if(-e $css_file_path);
        
        # otherwise use Wget to download the css files
        my $cmdWget = $wget_options . $css_file;        
        my $strResponse = $self->useWget($cmdWget,1);
        
        print STDERR "Downloaded associated StyleSheet : $css_file\n";
      }
    }
}


sub generateOptionsString
{
    my ($self) = @_;
    my $strOptions;

    (defined $self) || &error("generateOptionsString","No \$self is defined!!\n");
    (defined $self->{'depth'})|| &error("generateOptionsString","No depth is defined!!\n");   
    
    # -r for recursive downloading
    # -E to append a 'html' suffix to a file of type 'application/xhtml+xml' or 'text/html'
    $strOptions .="-r -E ";

    # -X exclude file directories
    if($self->{'exclude_directories'}==1) {
	$strOptions .="-X " . $self->{'exclude_directories'};
    } else {
	$strOptions .="-X /wiki/index.php/Special:Recentchangeslinked,/wiki/index.php/Special:Whatlinkshere,/wiki/index.php/Talk:Creating_CD ";
    }	

    # -R reject file list, reject files with these text in their names
    if($self->{'reject_files'}==1) {
	$strOptions .="-R " . $self->{'reject_files'};
    } else {
	$strOptions .="-R *action=*,*diff=*,*oldid=*,*printable*,*Recentchangeslinked*,*Userlogin*,*Whatlinkshere*,*redirect*,*Special:*,Talk:*,Image:* ";
    }    
    
    if($self->{'depth'} == 0){
	$strOptions .= " ";
    } elsif($self->{'depth'} > 0) {
	$strOptions .= "-l ".$self->{'depth'}." "; # already got -r
    } else {
	$self->error("setupOptions","Incorrect Depth is defined!!\n");
    }

    if($self->{'below'})  {
	$strOptions .="-np ";
    }

    # if($self->{'html_only'}) {
	# $strOptions .="-A .html,.htm,.shm,.shtml,.asp,.php,.cgi,*?*=* ";
    # } else{
	# $strOptions .="-p ";
    #}

    if (!$self->{'within'}){
	$strOptions .="-H ";
    }    
    
    return $strOptions;  
}

sub url_information
{
    my ($self) = shift (@_);

    my $strOptions = $self->getWgetOptions();

    my $strBaseCMD = $strOptions." -q -O - \"$self->{'url'}\"";

  
    my $strIdentifyText = $self->useWget($strBaseCMD);
    
    if (!defined $strIdentifyText or $strIdentifyText eq ""  ){
		print STDERR "Server information is unavailable.\n";
		print STDERR "<<Finished>>\n";
		return;  
    }

    while ($strIdentifyText =~ m/^(.*)<title>(.*?)<\/title>(.*)$/s)  {
		$strIdentifyText = $1.$3;
		print STDERR "Page Title: $2\n";
    }
  
    while ($strIdentifyText =~ m/^(.*)<meta (.*?)>(.*)$/s)  {
	$strIdentifyText = $1.$3;
	my $strTempString = $2;
	print STDERR "\n";

	while($strTempString =~ m/(.*?)=[\"|\'](.*?)[\"|\'](.*?)$/s){
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
	print "Error occoured in MediaWikiDownload.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}

1;

