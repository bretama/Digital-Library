#!/usr/bin/perl

use usabcgi;

print "Content-type:text/html\n\n";


print "<html><head><title>Greenstone Usability - Track Report</title>\n";
usabcgi::printscript;
usabcgi::printstyle($ENV{HTTP_USER_AGENT});

print "</head><body bgcolor=\"#ffffff\">\n";

usabcgi::printbanner("Track Report");
usabcgi::printaplinks;

usabcgi::checkidno;

%reportvals=usabcgi::getusabreportdetails;

print "<h2>Your automatically generated report ID number is: $reportvals{\"report-id\"}</h2>\n";

print "<p>Thank you very much for helping us improve the usability of the Greenstone software\n<p>We received your report at $reportvals{\"time\"}, any updates are shown below.\n<p>To track this report continue to use the URL <a href=\"http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}?$ENV{QUERY_STRING}\">http://$ENV{HTTP_HOST}$ENV{SCRIPT_NAME}?$ENV{QUERY_STRING}</a>.\n";

print "<h2>Updates on this report</h2>\n";
if(!(defined($reportvals{"update"}))){ print "<p>None at this time.</p>\n"; }
else { print $reportvals{"update"}; }

print "<br><br><p class=\"sans\"><a href=\"mailto:greenstone&#064;cs.waikato.ac.nz\">Contact us</a> with any queries or if you would like this report to be removed from the database.  Please include your report ID number ($ENV{QUERY_STRING}) if your query concerns this report specifically.\n";


	
print "</body></html>";














