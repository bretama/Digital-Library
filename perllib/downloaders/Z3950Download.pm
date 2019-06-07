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

package Z3950Download;

eval {require bytes};

# suppress the annoying "subroutine redefined" warning that various
# plugins cause under perl 5.6
$SIG{__WARN__} = sub {warn($_[0]) unless ($_[0] =~ /Subroutine\s+\S+\sredefined/)};

use strict;

use BaseDownload;
use IPC::Open2;
use POSIX ":sys_wait_h"; # for waitpid, http://perldoc.perl.org/functions/waitpid.html

sub BEGIN {
    @Z3950Download::ISA = ('BaseDownload');
}

my $arguments = 
    [  { 'name' => "host", 
	'disp' => "{Z3950Download.host_disp}",
	'desc' => "{Z3950Download.host}",
	'type' => "string",
	'reqd' => "yes"},
      { 'name' => "port", 
	'disp' => "{Z3950Download.port_disp}",
	'desc' => "{Z3950Download.port}",
	'type' => "string",
	'reqd' => "yes"},
      { 'name' => "database", 
	'disp' => "{Z3950Download.database_disp}",
	'desc' => "{Z3950Download.database}",
      	'type' => "string",
	'reqd' => "yes"},
      { 'name' => "find", 
	'disp' => "{Z3950Download.find_disp}",
	'desc' => "{Z3950Download.find}",
	'type' => "string",
	'deft' => "",
	'reqd' => "yes"},
      { 'name' => "max_records", 
	'disp' => "{Z3950Download.max_records_disp}",
	'desc' => "{Z3950Download.max_records}",
	'type' => "int",
	'deft' => "500",
	'reqd' => "no"}];

my $options = { 'name'     => "Z3950Download",
		'desc'     => "{Z3950Download.desc}",
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

    my $self = new BaseDownload($getlist,$inputargs,$hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    # Must set $self->{'url'}, since GLI use $self->{'url'} to calculate the log file name!
    $self->{'url'} = $self->{'host'}.":".$self->{'port'};

    $self->{'yaz'} = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "yaz-client");
    
    return bless $self, $class;

}

sub download
{
    my ($self) = shift (@_);
    my ($hashGeneralOptions) = @_;
    my ($strOpen,$strBase,$strFind,$strResponse,$intAmount,$intMaxRecords,$strRecords);

    my $url = $self->{'url'};
 
    print STDERR "<<Defined Maximum>>\n";
 
    $strOpen = $self->start_yaz($url);

    print STDERR "Access database: \"$self->{'database'}\"\n";
    $self->run_command_without_output("base $self->{'database'}");
    print STDERR "Searching for keyword: \"$self->{'find'}\"\n";
    $intAmount = $self->findAmount($self->{'find'});

    if($intAmount <= 0)
    {
	($intAmount == -1)? 
	    print STDERR "Something wrong with the arguments,downloading can not be performed\n": 
		print STDERR "No Record is found\n";
	print STDERR "<<Finished>>\n";
	return 0;
    }
    $intMaxRecords = ($self->{'max_records'} > $intAmount)? $intAmount : $self->{'max_records'};
    print STDERR "<<Total number of record(s):$intMaxRecords>>\n";
    $strRecords = "Records: $intMaxRecords\n".$self->getRecords($intMaxRecords);
   
    $self->saveRecords($strRecords,$hashGeneralOptions->{'cache_dir'},$intMaxRecords);
    print STDERR "Closing connection...\n";

    $self->quit_yaz();
    return 1;
}


sub start_yaz 
{
    my ($self, $url) = @_;    

    print STDERR "Opening connection to $url\n";
     
    my $yaz = $self->{'yaz'};
    
    my $childpid = open2(*YAZOUT, *YAZIN, $yaz)
	or (print STDERR "<<Finished>>\n" and die "can't open pipe to yaz-client: $!");
    $self->{'pid'} = $childpid;
    $self->{'YAZOUT'} = *YAZOUT;
    $self->{'YAZIN'} = *YAZIN;

    my $strOpen = $self->open_connection("open $url");  

    if (!$strOpen) {
        print STDERR "Cannot connect to $url\n"; 
        print STDERR "<<Finished>>\n";  
	return 0;
    }
    return $strOpen;
}

sub quit_yaz 
{
    my ($self) = shift (@_);

    # can't send a "close" cmd to close the database here, since the close command is only
    # recognised by Z3950, not by SRW. (This method is also used by the subclass for SRW.)

    print STDERR "<<Finished>>\n";

    # need to send the quit command, else yaz-client is still running in the background
    $self->run_command_without_output("quit");
    close($self->{'YAZIN'}); # close the input to yaz. It also flushes quit command to yaz.

    # make sure nothing is being output by yaz
    # flush the yaz-client process' outputstream, else we'll be stuck in an infinite
    # loop waiting for the process to quit.
    my $output = $self->{'YAZOUT'};
    my $line;
    while (defined ($line = <$output>)) { 
	if($line !~ m/\w/s) { # print anything other than plain whitespace in case it is important
	    print STDERR "***### $line";
	}
    }

    close($self->{'YAZOUT'});

    # Is the following necessary? The PerlDoc on open2 (http://perldoc.perl.org/IPC/Open2.html)
    # says that waitpid must be called to "reap the child process", or otherwise it will hang
    # around like a zombie process in the background. Adding it here makes the code work as 
    # before, but it is certainly necessary to call waitpid on wget (see WgetDownload.pm).
    # http://perldoc.perl.org/functions/waitpid.html
    my $kidpid;
    do {
	$kidpid = waitpid($self->{'pid'}, WNOHANG);
    } while $kidpid > 0; # waiting for pid to become -1
}

sub open_connection{
  my ($self,$strCommand) =  (@_);
  
  $self->run_command($strCommand);  

  my $out = $self->{'YAZOUT'}; 

  my $opening_line = <$out>;
  
  return ($opening_line =~ m/Connecting...OK/i)? 1: 0; 
 
}

sub findAmount
{
    my ($self) = shift (@_);
    my($strFindTarget) = @_;
    my $strResponse = $self->run_command_with_output("find $strFindTarget","^Number of hits:");
   return ($strResponse =~ m/^Number of hits: (\d+)/m)? $1:-1;    
}

sub getRecords
{
    my ($self) = shift (@_);
    my ($intMaxRecords) = @_;
    my ($strShow,$intStartNumber,$numRecords,$strResponse,$strRecords,$intRecordsLeft);

    $intStartNumber = 1;
    $intRecordsLeft = $intMaxRecords;
    $numRecords = 0;
    $strResponse ="";

    while ($intRecordsLeft > 0)
    {
	if($intRecordsLeft > 50)
	{
	   
	    print STDERR "Yaz is Gathering records: $intStartNumber - ".($intStartNumber+49)."\n";
	    $numRecords = 50;
	    $strShow = "show $intStartNumber+50";
	    $intStartNumber = $intStartNumber + 50;
	    $intRecordsLeft = $intRecordsLeft - 50;
             
	}
	else
	{
	    $numRecords = $intRecordsLeft;
	    print STDERR "Yaz is Gathering records: $intStartNumber - ".($intStartNumber+$intRecordsLeft-1)."\n";
	    $strShow = "show $intStartNumber+$intRecordsLeft";
	    $intRecordsLeft = 0;
	   
           }
	
	$strResponse .= $self->get($strShow,$numRecords);
         
	if ($strResponse eq ""){
	    print STDERR "<<ERROR: failed to get $numRecords records>>\n";
	}
	else{
	    print STDERR "<<Done:$numRecords>>\n";
	}
    }

    return  "$strResponse\n";
	
}

sub saveRecords
{
    my ($self,$strRecords,$strOutputDir,$intMaxRecords) = @_;

    # setup directories
    # Currently only gather the MARC format
    my $strFileName = $self->generateFileName($intMaxRecords);

    $strOutputDir  =~ s/"//g; #"

    my $strOutputFile = &FileUtils::filenameConcatenate($strOutputDir,$self->{'host'},"$strFileName.marc");
     # prepare subdirectory for record (if needed)
    my ($strSubDirPath,$unused) = $self->dirFileSplit($strOutputFile);
 
    &FileUtils::makeAllDirectories($strSubDirPath);
  
    print STDERR "Saving records to \"$strOutputFile\"\n";

    # save record 
    open (ZOUT,">$strOutputFile")
	|| die "Unable to save Z3950 record: $!\n";
    print ZOUT $strRecords;
    close(ZOUT);
}


sub run_command_with_output
{
    my ($self,$strCMD,$strStopRE) =@_;
   
    $self->run_command($strCMD); 
   
    return $self->get_output($strStopRE);
 
}

sub get{
   my ($self,$strShow,$numRecord) = @_;  

   $self->run_command($strShow);  
   
   my $strFullOutput="";
   my $count=0;
   my $readRecord = 0;
   
   my $output = $self->{'YAZOUT'};
   while (my $strLine = <$output>)
   {
   
       if ($strLine =~ m/Records: ([\d]*)/i ){ 
	   $readRecord = 1;
	   next;  
       }
      
      return $strFullOutput if ($strLine =~ m/nextResultSetPosition|Not connected/i);
        
      next if(!$readRecord);
      
      $strFullOutput .= $strLine;     
  }
   
}

sub run_command_without_output
{
     my ($self) = shift (@_);
    my ($strCMD) = @_;

    $self->run_command($strCMD);
}

sub run_command
{
    my ($self,$strCMD) = @_; 
 
    my $input = $self->{'YAZIN'};

    print $input "$strCMD\n";  
}

sub get_output{
    my ($self,$strStopRE) = @_;  

    if (!defined $strStopRE){return "";}
    else
    {
	my $strFullOutput;
        my $output = $self->{'YAZOUT'};
	while (my $strLine = <$output>)
	{
           $strFullOutput .= $strLine;   
	   if($strLine =~ m/^$strStopRE|Not connected/i){return $strFullOutput;}
	}
    }
}

sub generateFileName
{
    my ($self,$intMaxRecords) = @_;
    my $strFileName = ($self->{'database'})."_".($self->{'find'})."_".($intMaxRecords);
 
}

sub dirFileSplit
{
    my ($self,$strFile) = @_;

    my @aryDirs = split(/[\/\\]/,$strFile);
   
    my $strLocalFile = pop(@aryDirs);
    my $strSubDirs = join("/",@aryDirs);

    return ($strSubDirs,$strLocalFile);
}

sub url_information
{
   my ($self,$url) = @_;

   $url = $self->{'url'} unless defined $url;

   my $strOpen = $self->start_yaz();

   $strOpen = $self->run_command_with_output("open $url","^Options");  

   $strOpen =~ s/Z> //g;
   $strOpen =~ s/Elapsed:.*//g;

   print STDERR $strOpen; 

   $self->quit_yaz();

   return 0;

}

sub error
{
    my ($self,$strFunctionName,$strError) = @_;
    {
	print STDERR "Error occoured in Z3950Download.pm\n".
	    "In Function:".$strFunctionName."\n".
	    "Error Message:".$strError."\n";
	exit(-1);
    }
}

1;
