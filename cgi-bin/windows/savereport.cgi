#!/usr/bin/perl

use usabcgi;

print "Content-type:text/html\n\n";




$idno=$ENV{REMOTE_ADDR};
$idno =~ s/\.//g;
$idno =~ tr/0123456789/1357902468/;
$idno .= time;

print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n"; 
print "<html>\n<head>\n<title>Greenstone Usability Thank you!</title>\n";
print "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n";

usabcgi::printstyle($ENV{HTTP_USER_AGENT});
usabcgi::printscript;
#print "timeleft=21;\n";
#print "function timerdisplay(){\n";
#print "\tif(eval(document.getElementById != undefined )){\n";
#print "\t\tif(parseInt(timeleft)>0){\n";
#print "\t\t\ttimeleft-=1;\n";
#print "\t\t\ttimeforscreen = timeleft+\' second\';\n";
#print "\t\t\tif(timeleft>1)\{ timeforscreen += \'s\';\}\n";
#print "\t\t\t\tdocument.getElementById(\'timer\').firstChild.nodeValue=timeforscreen;\n";
#print "\t\t\t\tsetTimeout(\'timerdisplay()\',1000);\n";
#print "\t\t}\n";
#print "\t}\n";
#print "}\n";
#print "\n";

print "</head><body onLoad=\"if(parseInt(navigator.appVersion)>3)\{window.resizeTo(420,300);\}\" bgcolor=\"#FFFFFF\">\n";


usabcgi::printbanner("Thank You");

($fileoutloc) = usabcgi::get_config_info("gsdlhome");
if(!($fileoutloc =~/\/$/)) {$fileoutloc.="/";}
$fileoutloc .= "etc/usability.txt";

if(-e $fileoutloc){
    open FILEOUT, (">>$fileoutloc");
}
else {
    open FILEOUT, (">$fileoutloc");
}

usabcgi::printaplinks;
print "<p>Your comments have been noted. <p>Thank you for helping us make Greenstone more usable.</p>\n";
print "<table width=\"100%\"><tr>\n";
print "<td class=\"sans\"><a href=\"readresults.cgi?$idno\" target=\"_blank\">View report details</a></td>\n";
print "<td class=\"sans\"><a href=\"trackreport.cgi?$idno\" target=\"_blank\">Track report</a></td>";
print "<td align=\"right\"><form action=\"\"><button type=\"button\" onClick=\"window.close();\"><strong>Close Window</strong></button></form></td>\n";
print"</tr></table>\n";


#print "<h2>Your report ID number is: $idno</h2>";
#print "<p>The information has now been sent, thank-you.  The information sent is displayed below.  This window will close automatically after <span id=\"timer\">20 seconds</span>.";
read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
@pairs=split(/&/,$buffer);

foreach $pair (@pairs) {
    ($name, $value) = split(/=/,$pair);
    $value=~ tr/+/ /;
    $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    $FORM{$name} = $value;
}



if (-e $fileoutloc){ 
    open FILEOUT, (">>$fileoutloc");
}
else { open FILEOUT, (">$fileoutloc") or print "cannot open file $fileoutloc\n"; }
#print FILEOUT "-------------------------------------\n";
print FILEOUT "report-id := $idno\&usabend;\n";
foreach $key (keys(%FORM)) {
    if($key eq "URL") {
	$url = $FORM{$key};
	$url =~s/\&/\&amp\;/g;
    }
    print FILEOUT "$key := $FORM{$key}\&usabend;\n"; 
}
print FILEOUT "browser-read-by-server :=  $ENV{HTTP_USER_AGENT}\&usabend;\n";
print FILEOUT "browser-ip-no :=  $ENV{REMOTE_ADDR}\&usabend;\n";
print FILEOUT "server-ip-no :=  $ENV{SERVER_ADDR}\&usabend;\n";
print FILEOUT "time := ".scalar(localtime(time))."\&usabend;\n";
print FILEOUT "----------------------------------------------\n";
close (FILEOUT);


print"</body></html>\n"; 

