package usabcgi;


sub get_config_info {
    open FILEIN, ("gsdlsite.cfg") 	|| die "ERROR: Could not open site configuration file\n";

    my $configfile;
    while(<FILEIN>) {
	$configfile .= $_;
    }
    close(FILEIN);

    
    ($infotype) = @_;
    
    $configfile =~ /^$infotype\s+(\S+)\s*\n/m;
    $loc=$1;
    $loc =~ s/\"//g;

    return ($loc);
}

sub get_httpimg {
    my ($imageloc) = usabcgi::get_config_info("httpimg");
    if(!($imageloc =~ "http")) {$imageloc="http://".$ENV{HTTP_HOST}.$imageloc;}
    return $imageloc;
}

sub get_httpusab {
    my ($htmlloc) = usabcgi::get_config_info("httpimg");
    if(!($htmlloc =~ "http")) {$htmlloc="http://".$ENV{HTTP_HOST}.$htmlloc;}
    $htmlloc =~ s/images/usability/;
    return  $htmlloc;

}

sub printscript {
    
    print "<script type=\"text/javascript\">\n";
    print "\tfunction showaboutprivacy(url){\n";
    print "\t\tinfowin=window.open(url,'infowin','toolbars=0, height=600, width=600')\n";
    print "\t}\n";
    print "</script>\n";
}

sub printbanner {
    ($title)=@_;
    ($imageloc) = usabcgi::get_httpimg();
    print "<table width=\"100%\"><tr>\n<td><h1>Greenstone Usability - $title</h1></td>\n";
    print "<td align=\"right\">";
    if ($imageloc) { print "<img src=\"$imageloc\/usabbnr.gif\" alt=\"Greenstone koru design\" title=\"Greenstone koru design\">"; }
    print "</td>\n</tr></table>";
}

sub printaplinks {
    # this is a hack
    ($htmlloc) = usabcgi::get_httpusab();
    print "<p class=\"sans\">\n";
    print "<a href=\"javascript:showaboutprivacy('$htmlloc/about.html')\">About</a>\n &#8226; <a href=\"javascript:showaboutprivacy('$htmlloc/privacy.html')\">Privacy</a>\n";

}

sub printstyle {
    ($browser) = @_;
    $browser=~/([^\/]*)\/([0-9]+\.[0-9]+)/;
    if(($1 ne "Netscape")||($2 > 4.77)){
	print "<style type=\"text/css\">\n";
	print "\th1 {font-family: sans-serif; font-size: 20px}\n";
	print "\th2 {font-family: sans-serif; font-size: 14px; font-weight: bold; color: #009966}\n";
	print "\tp.sans {font-family: sans-serif}\n";
	print "\ttd {vertical-align: top}\n";
	print "\ttd.sans {font-family: sans-serif; width: 50%}\n";
	print "</style>\n";
    }

}

sub checkidno {
    if((!($ENV{QUERY_STRING}=~/\d/)) || ($ENV{QUERY_STRING}=~/\D/) ) {
	print "<h2>Each report sent has an ID number.  This page needs one of those numbers to work.</h2>\n";
	print "<br><br><p class=\"sans\"><a href=\"mailto:greenstone&#064;cs.waikato.ac.nz\">Contact us</a> with any queries about this.\n";
	print "</body></html>\n";
	die;
    }
}

sub getusabreportdetails {
    ($etcfileloc) = usabcgi::get_config_info("gsdlhome");
    if(!($etcfileloc =~/\/$/)) {$etcfileloc.="/";}
    $etcfileloc .= "etc/usability.txt";
    open (FILEIN, $etcfileloc) or die "could not open usability.txt\n";
    while(<FILEIN>){
	$etcfile.=$_;
    }   
    close(FILEIN);

    if(!($etcfile=~ / $ENV{QUERY_STRING}\&usabend;/)) {
	print "<h2>Each report has an ID number.  This program needs one of those ID numbers to work, and the ID number provided wasn't found.</h2>\n";
	print "<br><br><p class=\"sans\"><a href=\"mailto:greenstone&#064;cs.waikato.ac.nz\">Contact us</a> with any queries about this.\n";
	print "</body></html>";  
        die;
    }

#get the report for whjich details are to be viewed.
    $etcfile=~/report-id := $ENV{QUERY_STRING}\&usabend\;\n/;
    $report = $&;
    $tmp=$';
    $tmp=~/----------------------?/;
    $report.=$`;
    @pairs=split(/\&usabend\;\n/,$report);
    foreach $pair (@pairs) {
	($name, $value)= split(/ := /,$pair);
	
	#this splits long values up for display purposes
	@tmplist = split(/ /,$value);
	foreach $item (@tmplist){
	    if(length $item > 60){
		$tmp="";
		while(length $item > 60){
		    $tmp.= substr $item, 0, 60;
		    $tmp.=" ";
		    $item = substr $item, 60;
		}
		$tmp.=$item;
		$item=$tmp;
	    }
	}
	$value = join(' ',@tmplist);
	
	#this adds html tags for breaks
	$value =~ s/\n/\<br\>\n/g;
	$reportvals{$name}=$value;
    }
    return %reportvals;

}    

1;




















