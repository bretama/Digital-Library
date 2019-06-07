#!/usr/bin/perl

use usabcgi;

print "Content-type:text/html\n\n";


print "<html><head><title>Greenstone Usability - Report Details</title>\n";
usabcgi::printscript;
usabcgi::printstyle($ENV{HTTP_USER_AGENT});

print "</head><body bgcolor=\"#ffffff\">\n";

usabcgi::printbanner("Report Details");
usabcgi::printaplinks;
 
usabcgi::checkidno;

%reportvals=usabcgi::getusabreportdetails;

print "<p>Your automatically generated report ID number is: <b>$reportvals{\"report-id\"}</b>";
$reportid = $reportvals{"report-id"};
delete $reportvals{"report-id"};

print "<h2>The following technical information was automatically collected about your problem:</h2>\n";
print "<table width=\"100%\">\n";

make_table_entry("The URL of the page where you were having problems","URL");
make_table_entry("the collection you were using when you had problems","collection");
make_table_entry("Time you opened the usability report window","opentime");
make_table_entry("Time you sent the usability report","sendtime");
make_table_entry("Time the report was received by the server","time");
make_table_entry("Your browser as it identifies itself","browser");
make_table_entry("Your browser as the server identifies it","browser-read-by-server");
make_table_entry("Your browser's IP number","browser-ip-no");
make_table_entry("The server's IP number","server-ip-no");
make_table_entry("Your language as recorded by your browser","language");
make_table_entry("The resolution of your screen","resolution");
make_table_entry("The colour of your screen","screencolour");
make_table_entry("The number of bits per pixel your display uses to represent colour","pixeldepth");
print "</table>";

print "<h2>You provided us with the following extra information about the problem</h2>\n";

print"<table width=\"100%\">\n";
make_table_entry("How bad the problem was","severity");
make_table_entry("What kind of problem it was","probtype");
make_table_entry("Other details","moredetails");
print "</table>\n";

print "<h2>The following data was automatically collected from the form on the Greenstone interface</h2>\n";

print"<table width=\"100%\">\n";
print "<tr><td class=\"sans\"><b>Type of input</b></td><td class=\"sans\"><b>Name of input</b></td><td class=\"sans\"><b>Value of input</b></td></tr>\n";

foreach $key (keys(%reportvals)){
    if($key ne "update"){
	$key=~/-/;
	print "<tr><td width=\"33%\">$`</td><td width=\"33%\">$'</td><td width=\"34%\">$reportvals{$key}</td></tr>\n";
    }
}
print "</table>\n";

print "<br><br><p class=\"sans\"><a href=\"mailto:dmn&#064;cs.waikato.ac.nz\">Contact us</a> with any queries or if you would like this report to be removed from the database.  Please include your report ID number ($reportid) if your query concerns this report specifically.";
	
print "</body></html>";

#This function takes a key into the report values interface, and a desription 
# of what that entry means, and makes a properly formatted html table entry
sub make_table_entry {
    local ($desc, $entry) = @_;
    print "<tr><td class=\"sans\" width=\"50%\"><strong>$desc:</strong></td>";
    print "<td width=\"50%\">$reportvals{$entry}</td></tr>\n";
    delete $reportvals{$entry};

}













