#!/usr/bin/perl -w

###########################################################################
#
# schedule.pl --
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

package schedule;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugins");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/plugouts");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/classify");

    if (defined $ENV{'GSDLEXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDLEXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDLHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	}
    }
    if (defined $ENV{'GSDL3EXTS'}) {
	my @extensions = split(/:/,$ENV{'GSDL3EXTS'});
	foreach my $e (@extensions) {
	    my $ext_prefix = "$ENV{'GSDL3SRCHOME'}/ext/$e";

	    unshift (@INC, "$ext_prefix/perllib");
	    unshift (@INC, "$ext_prefix/perllib/cpan");
	}
    }

}

use strict; 
no strict 'refs'; 
no strict 'subs'; 

use FileHandle; 
use Fcntl; 
use printusage; 
use parse2; 
use parse3;
use gsprintf 'gsprintf';
if($ENV{'GSDLOS'} eq "windows") {
	eval("require \"Win32.pm\" "); 
}

my $frequency_list = 
    [  { 'name' => "hourly",
         'desc' =>  "{schedule.frequency.hourly}" }, 
       { 'name' => "daily",
         'desc' =>  "{schedule.frequency.daily}" }, 
       { 'name' => "weekly",
         'desc' =>  "{schedule.frequency.weekly}" } 
     ];

my $action_list = 
    [  { 'name' => "add",
         'desc' =>  "{schedule.action.add}" }, 
       { 'name' => "update",
         'desc' =>  "{schedule.action.update}" }, 
       { 'name' => "delete",
         'desc' =>  "{schedule.action.delete}" } 
     ];

my $arguments = 
    [
     { 'name' => "schedule", 
       'desc' => "{schedule.schedule}",
       'type' => "flag", 
       'reqd' => "no", 
       'modegli' => "3" }, 
      { 'name' => "frequency", 
       'desc' => "{schedule.frequency}",
       'type' => "enum",
       'list' => $frequency_list, 
       'deft' => "daily", 
       'reqd' => "no", 
       'modegli' => "3" }, 
     { 'name' => "action", 
       'desc' => "{schedule.action}",
       'type' => "enum", 
       'list' => $action_list, 
       'deft' => "add", 
       'reqd' => "no", 
       'modegli' => "3" },
     { 'name' => "import", 
       'desc' => "{schedule.import}",
       'type' => "quotestr", 
       'deft' => "", 
       'reqd' => "yes", 
       'hiddengli' => "yes" },
     { 'name' => "build", 
       'desc' => "{schedule.build}",
       'type' => "quotestr", 
       'deft' => "", 
       'reqd' => "yes", 
       'hiddengli' => "yes" }, 
     { 'name' => "colname", 
       'desc' => "{schedule.colname}",
       'type' => "string", 
       'deft' => "", 
       'reqd' => "no", 
       'hiddengli' => "yes" }, 
     { 'name' => "xml", 
       'desc' => "{scripts.xml}",
       'type' => "flag", 
       'reqd' => "no", 
       'hiddengli' => "yes" },
     { 'name' => "language", 
       'desc' => "{scripts.language}",
       'type' => "string", 
       'reqd' => "no", 
       'hiddengli' => "yes" },
     { 'name' => "email", 
       'desc' => "{schedule.email}",
       'type' => "flag", 
       'reqd' => "no", 
       'modegli' => "3" },
     { 'name' => "toaddr", 
       'desc' => "{schedule.toaddr}",
       'type' => "string", 
       'reqd' => "no", 
       'deft' => "", 
       'modegli' => "3" },
     { 'name' => "fromaddr", 
       'desc' => "{schedule.fromaddr}",
       'type' => "string",
       'deft' => "", 
       'reqd' => "no",
       'modegli' => "3" },
     { 'name' => "smtp", 
       'desc' => "{schedule.smtp}",
       'type' => "string",
       'deft' => "",
       'reqd' => "no", 
       'modegli' => "3" },
     { 'name' => "out",
        'desc' => "{schedule.out}",
        'type' => "string",
        'deft' => "STDERR",
        'reqd' => "no",
        'hiddengli' => "yes" },
     { 'name' => "gli",
        'desc' => "{schedule.gli}",
        'type' => "flag",
        'reqd' => "no",
        'hiddengli' => "yes" }
     ];


my $options = { 'name' => "schedule.pl",
		'desc' => "Interaction with Cron",
		'args' => $arguments };

&main(); 

sub main { 

    #params
    my ($action, $frequency, $import, $build, $colname, $xml, $language, 
        $email, $toaddr, $fromaddr, $smtp, $gli, $out);

    #other vars
    my ($i,$numArgs,$os,$erase,$erase2,$copy,$newpl,$gsdl,$path,$cronf,
        $nf,$of,$opf, $cronstr, $ecmd,$ecmd2, $record, $cronrec,$ncronf);

    #some defaults
    $action = "add";   
    $frequency = "hourly"; 
    $import = ""; 
    $build = ""; 
    $colname = "";
    $xml = 0; 
    $email = 0;
    $gli = 0; 
    $language = ""; 
    $out = "STDERR"; 


    $gsdl = $ENV{'GSDLHOME'};
    $os = $ENV{'GSDLOS'};
    $path = $ENV{'PATH'}; 
	
	if("$gsdl" =~ m/(\\\(|\\\)| )/ ) { # () brackets or spaces in path
		&gsprintf($out, "\n\n{schedule.filepath_warning}\n\n\n", $gsdl);
	}

    my $service = "schedule"; 

    #For this to work, we need to know if -gli exists
 
    $numArgs=$#ARGV+1; 
    $i = 0; 
    while($i < $numArgs)
    {
	if($ARGV[$i] =~ /gli/) {
	    $gli = 1; 
	}
	$i++; 
    } 

    #We are using two different parsers here, because the GLI in linux (and probably darwin) will not take
    #an entire double-quoted string as an argument, while if schedule.pl is 
    #executed from the command line, the entire double-quoted string is taken
    #as an argument. For Windows, it seems that it does. 
    my $hashParsingResult = {}; 
    my $intArgLeftAfterParsing; 
    if($gli && ($os eq "linux" || $os eq "darwin")) {  
	$intArgLeftAfterParsing = parse3::parse(\@ARGV, $arguments, $hashParsingResult, "allow_extra_options"); 
    } else {
	$intArgLeftAfterParsing = parse2::parse(\@ARGV, $arguments, $hashParsingResult, "allow_extra_options"); 

    } 

    #check for extra options
    if ($intArgLeftAfterParsing == -1 || $intArgLeftAfterParsing > 0 || (@ARGV && $ARGV[0] =~ /^\-+h/))
    {
        &PrintUsage::print_txt_usage($options, "{schedule.params}");
        die "\n";
    }

    foreach my $strVariable (keys %$hashParsingResult)
    {
        eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }
  
    if ($xml) {
	    &PrintUsage::print_xml_usage($options); 
	    print "\n"; 
	    return; 

    }

    if ($gli) { # the gli wants strings to be in UTF-8
        &gsprintf::output_strings_in_UTF8; 
    }

    if($action eq "add" || $action eq "update") { 
	if($email) {
	    if($smtp eq "" || $toaddr eq "" || $fromaddr eq "" || $smtp =~ /^-/ || $toaddr =~ /^-/ || $fromaddr =~ /^-/) {
		&gsprintf($out, "{schedule.error.email} \n"); 
		die "\n"; 
	    }
	

	    if($import eq "" || $build eq "") { 
		&gsprintf($out, "{schedule.error.importbuild} \n");
		die "\n"; 
	    }
	}
    } 
    if($colname eq "") { 
	 &gsprintf($out, "{schedule.error.colname} \n");
	 die "\n"; 
    }

    #not sure if this is always set? 
    #language may be passed in too
    if($language eq "" && exists($ENV{'GSDLLANG'}))  {
        $language = $ENV{'GSDLLANG'}; 
    }
    elsif($language eq "")  {
	$language = "en"; 
    } 

    $newpl = "cron.pl"; 

    if($action eq "delete") {

	print STDERR "<Delete>\n" if $gli; 

	if($os =~ /^linux$/ || $os =~ /^darwin$/) { 
	        system("\\rm $gsdl/collect/$colname/$newpl 2>/dev/null");
		system("\\rm $gsdl/collect/$colname/cronjob 2>/dev/null"); 
	} else {  #in windows

	        system("del $gsdl\\\\collect\\\\$colname\\\\$newpl 2>nul");  #nul is windows equivalent to /dev/null

	} 


	&gsprintf($out, "{schedule.deleted}\n");
    } 
    else {
	#For the Scheduling monitor
	print STDERR "<Schedule>\n" if $gli; 

	if ($os =~ /^linux$/ || $os =~ /^darwin$/) {
 
	    $import = $import." 2>$gsdl/collect/$colname/log/\$logfile";
	    $build = $build." 2>>$gsdl/collect/$colname/log/\$logfile"; 
	    $erase = "\\\\rm -r $gsdl/collect/$colname/index 2>>$gsdl/collect/$colname/log/\$logfile";
	    $erase2 = "mkdir $gsdl/collect/$colname/index 2>>$gsdl/collect/$colname/log/\$logfile";  
	    $copy = "mv $gsdl/collect/$colname/building/* $gsdl/collect/$colname/index/ 2>>$gsdl/collect/$colname/log/\$logfile";
	    if($email) {
		#first,we need to add backslashes before the 'at' symbol. 
		$toaddr =~ s/\@/\\\@/g; 
		$fromaddr =~ s/\@/\\\@/g; 

		$ecmd = "$gsdl/bin/script/sendmail.pl -to $toaddr -from $fromaddr -smtp $smtp -msgfile $gsdl/collect/$colname/log/\$logfile -subject \\\"Results of build for collection $colname\\\" 2>>$gsdl/collect/$colname/log/\$logfile"; 

		$ecmd2 = "$gsdl/bin/script/sendmail.pl -to $toaddr -from $fromaddr -smtp $smtp -msgfile $gsdl/etc/cronlock.txt -subject \\\"Results of build for collection $colname\\\" 2>>$gsdl/collect/$colname/log/\$logfile"; 	       
	    }
   
	} else {   #in windows

	    $gsdl =~ s/\\/\\\\/g; 
	    $path =~ s/\\/\\\\/g; 

	    $import =~ s/\\/\\\\/g;
	    $build =~ s/\\/\\\\/g; 

  	    $import =~ s/exe/exe\\\"/g;
	    $import =~ s/pl/pl\\\"/g; 
  	    $build =~ s/exe/exe\\\"/g;
	    $build =~ s/pl/pl\\\"/g;  


	    my $prompt = substr($gsdl,0,2); 

	    $import =~ s/$prompt/\\\"$prompt/g; 
	    $build =~ s/$prompt/\\\"$prompt/g; 

	    #not the best solution - won't work if someone chooses something weird
	    $import =~ s/\\collect/\\collect\\\"/; 
            $build =~ s/\\collect/\\collect\\\"/; 

	    $import = "$import 2>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 
	    $build = "$build 2>>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 


	    $erase = "rd \\\/S \\\/Q \\\"$gsdl\\\\collect\\\\$colname\\\\index\\\" 2>>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 
	    $erase2 = "md \\\"$gsdl\\\\collect\\\\$colname\\\\index\\\" 2>>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 
	    $copy = "xcopy \\\/E \\\/Y \\\"$gsdl\\\\collect\\\\$colname\\\\building\\\\*\\\" \\\"$gsdl\\\\collect\\\\$colname\\\\index\\\\\\\" >>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" ";
	    if($email) {
		$toaddr =~ s/\@/\\\@/g; 
		$fromaddr =~ s/\@/\\\@/g; 
		$ecmd = "\\\"$gsdl\\\\bin\\\\windows\\\\perl\\\\bin\\\\perl.exe\\\" -S \\\"$gsdl\\\\bin\\\\script\\\\sendmail.pl\\\" -to $toaddr -from $fromaddr -smtp $smtp -msgfile \\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" -subject \\\"Results of build for collection $colname\\\" >>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 

		$ecmd2 = "\\\"$gsdl\\\\bin\\\\windows\\\\perl\\\\bin\\\\perl.exe\\\" -S \\\"$gsdl\\\\bin\\\\script\\\\sendmail.pl\\\" -to $toaddr -from $fromaddr -smtp $smtp -msgfile \\\"$gsdl\\\\etc\\\\cronlock.txt\\\" -subject \\\"Results of build for collection $colname\\\" >>\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\" "; 	       
	    }
	}


	$nf = new FileHandle() ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);

	open($nf, ">$gsdl/collect/$colname/$newpl") ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);
 
	
	print $nf "\#!/usr/bin/perl"; 
	print $nf "\n\n"; 


	#we need to set environment variables for import and build
	print $nf "\$ENV{'GSDLHOME'}=\"$gsdl\"\;\n"; 
	print $nf "\$ENV{'GSDLOS'}=\"$os\"\;\n";
	print $nf "\$ENV{'GSDLLANG'}=\"$language\"\;\n";  
	print $nf "\$ENV{'PATH'}=\"$path\"\;\n";  

	print $nf "\$logfile = \"cron\".time\(\).\".txt\"\;\n";

	if($os =~ /^windows$/) {
		print $nf "if\(-e \\\"$gsdl\\\\collect\\\\$colname\\\\etc\\\\cron.lck\\\" \"\)\{ \n"; 
	} else { 
		print $nf "if\(-e \"$gsdl/collect/$colname/etc/cron.lck\"\) \{ \n";
	}
	if($email) { 
	    print $nf "    system(\"$ecmd2\")\;\n"; 
	}
	else { 
	    if($os eq "windows") { 
		print $nf "    system(\"more \\\"$gsdl\\\\etc\\\\cronlock.txt\\\" >\\\"$gsdl\\\\collect\\\\$colname\\\\log\\\\\$logfile\\\"\"\)\;\n";
	    } else {
		print $nf "    system(\"more $gsdl/etc/cronlock/txt > $gsdl/collect/$colname/log/\$logfile \"\)\;\n"; 
	    }

	}
        print $nf "\} else \{\n";

	if($os eq "linux" || $os eq "darwin")  {
	    $import =~ s/\"//; 
	    $import =~ s/\"//;
	    $build =~ s/\"//; 
	    $build =~ s/\"//; 
	}
       
	if($os =~ /^windows$/) {
		print $nf "system(\"echo lock \>\\\"$gsdl\\\\collect\\\\$colname\\\\etc\\\\cron.lck\\\"\")\;\n"; 
	} else { 
		print $nf "system(\"echo lock >$gsdl/collect/$colname/etc/cron.lck\")\;\n"; 
	}

	print $nf "	system(\"$import\")\;\n";
	print $nf "	system(\"$build\")\;\n"; 

	print $nf "	system(\"$erase\")\;\n"; 
	print $nf "	system(\"$erase2\")\;\n"; 

	print $nf "	system(\"$copy\")\;\n";
	if($email)  {
	    print $nf "	system(\"$ecmd\")\;\n"; 
	}


	#need to set permissions in linux
	if($os =~ /^linux$/ || $os =~ /^darwin$/) {
	    print $nf "system(\"chmod -R 755 $gsdl/collect/$colname/index/*\")\;\n";
	    print $nf "system(\"\\\\rm $gsdl/collect/$colname/etc/cron.lck\")\;\n"; 
	} else { 
            print $nf "system(\"del \\\"$gsdl\\\\collect\\\\$colname\\\\etc\\\\cron.lck\\\" \")\;\n"; 
	}



        print $nf "\}\n"; 

	close($nf); 
	if($os =~ /^linux$/ || $os =~ /^darwin$/) {
	    system("chmod 755 $gsdl/collect/$colname/cron.pl"); 
	}

	&gsprintf($out, "{schedule.scheduled}\n");
    }

    #next, we need to create a crontab file.  For now, a crontab will be set up
    #to run at midnight either nightly or weekly.  
    $gsdl =~ s/\\\\/\\/g;
    if ($os =~ /^linux$/ || $os =~ /^darwin$/)
    {
	$cronf="cronjob"; 
	open($nf, ">$gsdl/collect/$colname/$cronf") ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);

	#see if there is an existing crontab
	system("crontab -l >$gsdl/collect/$colname/outfile 2>/dev/null"); 

	$opf = new FileHandle(); 
	open($opf, "$gsdl/collect/$colname/outfile")   ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);
	$record = <$opf>;  

	#if there is an existing crontab file
	#preserve all records and change existing record for 
	#current collection
	if ($record) 
	{
	    do
	    {
		if($record !~ /$colname/)
		{
		    print $nf $record; 
		} 
	    } while($record = <$opf>); 

	    close($opf); 
	}


	if($action =~ /^add$/ || $action =~ /^update$/)
	{
	    if($frequency eq "hourly") {
		$cronrec = "50 * * * * $gsdl/collect/$colname/cron.pl";
	    }
	    elsif($frequency eq "daily") {
		$cronrec = "00 0 * * * $gsdl/collect/$colname/cron.pl";
	    }
	    elsif($frequency eq "weekly") {
		$cronrec = "59 11 * * 0 $gsdl/collect/$colname/cron.pl";
	    }

	    $cronrec = $cronrec." 2>/dev/null\n"; 
	
	    print $nf $cronrec; 
	}

	close($nf); 

	#this makes the cronjob official
	#still needs to be done for existing records
	system("crontab $gsdl/collect/$colname/$cronf 2>/dev/null"); 

	#cleanup
	system("\\rm $gsdl/collect/$colname/outfile"); 
	system("\\rm $gsdl/collect/$colname/$cronf");

	if($action eq "add" || $action eq "update")  {
	    &gsprintf($out, "{schedule.cron}\n");
	}

    } else {  

    #for windows, we will put crontab file in the same place.  some limitations
    #1) the absolute path to greenstone cannot have spaces if one is going to do this
    #2) cron.exe needs to be started manually before doing this
    #3) greenstone may have to be shut down completely to do this or lock problems occur

	$cronf="crontab";  #pycron.exe expects this filename!
	$ncronf="crontab.new"; 
	#check to see if crontab file exists
	if(-e "$gsdl/collect/$cronf")
	{
		
		open($of, "$gsdl/collect/$cronf") ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);


		open($nf, ">$gsdl/collect/$ncronf")  ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);

		while($record = <$of>)
		{
	 		if($record !~ /$colname/)
			{
			    print $nf $record; 
			}
		} 
		close($of);
		close($nf);

		system("del \"$gsdl\\collect\\$cronf\""); 
		system("move \"$gsdl\\collect\\$ncronf\" \"$gsdl\\collect\\$cronf\""); 
		
		
		my $shortf = Win32::GetShortPathName($gsdl); 

		my $command = "$shortf\\bin\\windows\\silentstart $shortf\\bin\\windows\\perl\\bin\\perl $shortf\\collect\\$colname\\cron.pl\n"; 
		
		if($action =~ /^add$/ || $action =~ /^update$/)
		{
		    open($nf, ">>$gsdl/collect/$cronf") ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);

		    if($frequency eq "hourly") {
			print $nf "50 * * * * $command";
		    }
		    elsif($frequency eq "daily") {
			print $nf "00 0 * * * $command";
		    }
		    elsif($frequency eq "weekly") {
			print $nf "59 11 * * 0 $command";
		    }
		    close($nf);
		}

	} else {	

	    my $shortf = Win32::GetShortPathName($gsdl); 

	    my $command = "$shortf\\bin\\windows\\silentstart $shortf\\bin\\windows\\perl\\bin\\perl $shortf\\collect\\$colname\\cron.pl\n"; 
		

	    if($action =~ /^add$/ || $action =~ /^update$/)
	    {
		open($nf, ">$gsdl/collect/$cronf") ||
            (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);
		if($frequency eq "hourly") {
	 	   print $nf "50 * * * * $command";
		}
		elsif($frequency eq "daily") {
		    print $nf "00 0 * * * $command";
		}
		elsif($frequency eq "weekly") {
		    print $nf "59 11 * * 0 $command";
		}

		close($nf); 
	    }
	}

	if($action eq "update" || $action eq "add") { 
	    &gsprintf($out, "{schedule.cron}\n");
	}
    }

    #For the scheduling monitor
    print STDERR "<Done>\n" if $gli; 

 

} #end sub main
