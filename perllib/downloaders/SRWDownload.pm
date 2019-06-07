###########################################################################
#
# SRWDownload.pm -- base class for all the import plugins
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

package SRWDownload;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use strict;

use Z3950Download;
use IPC::Open2;

sub BEGIN {
    @SRWDownload::ISA = ('Z3950Download');
}

my $arguments = [
		 ];

my $options = { 'name'     => "SRWDownload",
		'desc'     => "{SRWDownload.desc}",
		'abstract' => "no",
		'inherits' => "yes"
		};


sub new 
{
    my ($class) = shift (@_);
    my ($getlist,$inputargs,$hashArgOptLists) = @_;
    push(@$getlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new Z3950Download($getlist,$inputargs,$hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    # Must set $self->{'url'}, since GLI use $self->{'url'} to calculate the log file name!
    $self->{'url'} = $self->{'host'}.":".$self->{'port'};
    return bless $self, $class;
}

sub download
{
    my ($self) = shift (@_);
    my ($hashGeneralOptions) = @_;
    my ($strOpen,$strBase,$strFind,$strResponse,$intAmount,$intMaxRecords,$strRecords);

    # If the url contains just the host and port (as it would for Z39.50), then prepend
    # the http protocol. Otherwise the download is stuck in an infinite loop for SRW/SRU
    $self->{'url'} = "http://$self->{'url'}"  if $self->{'url'} !~ m/^http/;
    my $url = $self->{'url'};

    print STDERR "<<Defined Maximum>>\n";

    $strOpen = $self->start_yaz($url);
    
    print STDERR "Opening connection to \"$self->{'url'}\"\n";
    print STDERR "Access database: \"$self->{'database'}\"\n";
    $self->run_command_without_output("base $self->{'database'}");
    $self->run_command_without_output("querytype prefix");
    print STDERR "Searching for keyword: \"$self->{'find'}\"\n";

    $intAmount =$self->findAmount($self->{'find'});

    if($intAmount <= 0)
    {
	($intAmount == -1)? 
	    print STDERR "Something wrong with the arguments,downloading can not be performed\n" : 
		print STDERR "No Record is found\n";
	print STDERR "<<Finished>>\n";
	return 0;
    }
    $intMaxRecords = ($self->{'max_records'} > $intAmount)? $intAmount : $self->{'max_records'};
    print STDERR "<<Total number of record(s):$intMaxRecords>>\n";
   
    $strRecords = $self->getRecords($intMaxRecords);

    $self->saveRecords($strRecords,$hashGeneralOptions->{'cache_dir'},$intMaxRecords);
    print STDERR "Closing connection...\n";
    
    $self->quit_yaz();
    return 1;
}


sub saveRecords
{
    my ($self,$strRecords,$strOutputDir,$intMaxRecords) = @_;

    # setup directories
    # Currently only gather the MARC format
    $strRecords ="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<collection>$strRecords</collection>";  
    my $strFileName =  $self->generateFileName($intMaxRecords);
    my $host = $self->{'host'};
    $host =~ s/http:\/\///;
    $strOutputDir  =~ s/"//g; #"
    my $strOutputFile = &FileUtils::filenameConcatenate($strOutputDir,$host,"$strFileName.xml");
 
    # prepare subdirectory for record (if needed)

    my ($strSubDirPath,$unused) = $self->dirFileSplit($strOutputFile);
    &FileUtils::makeAllDirectories($strSubDirPath);

    print STDERR "Saving records to \"$strOutputFile\"\n";

    # save record 
    open (ZOUT,">$strOutputFile")
	|| die "Unable to save oai metadata record: $!\n";
    print ZOUT $strRecords;
    close(ZOUT);
}

sub get {
   my ($self,$strShow,$numRecord) = @_;  

   $self->run_command_without_output($strShow); 

   my $strFullOutput="";
   my $count=0;
   my $readRecord = 0;
   my $endRecord = 0;

   my $output = $self->{'YAZOUT'};
   my $strLine;

   while ($strLine = <$output>)    #while (defined ($strLine = <$output>)) 
   {
       last if ($count >= $numRecord && $endRecord); # done, if we've reached the end of the last record

       last if($strLine =~ m/^HTTP ERROR/i);

       if ($strLine =~ m/pos=[\d]*/i ) { 
           $count++;
	   $readRecord = 1;
	   $endRecord = 0;
	   next;
       }

       if ($strLine =~ m/<\/record>/i ) { # end tag of record
	   $endRecord = 1;
       }

       next if(!$readRecord);

       $strFullOutput .= $strLine;     
   }

   return $strFullOutput;
}

sub url_information{
   my ($self) = @_;

   my $url = $self->{'url'};

   $url =~ s#http://##; 

  return $self->SUPER::url_information($url);  

}

sub error
{
    my ($self, $strFunctionName,$strError) = @_;
    {
	print STDERR "Error occoured in SRWDownload.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}

1;
