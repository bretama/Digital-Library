package DateExtract;

##use BasPlug; ## no, DON'T use BasPlug, BasPlug uses us....
use sorttools;
use strict;
use util;

#75% of the instances of the word century use full name ordinals
my %ordinals = ("first" => 1, "second" => 2, "third" => 3, "fourth" => 4,
             "fifth" => 5, "sixth" => 6, "seventh" => 7, "eighth" => 8,
             "ninth" => 9, "tenth" => 10, "eleventh" => 11, "twelfth" => 12,
             "thirteenth" => 13, "fourteenth" => 14, "fifteenth" => 15,
             "sixteenth" => 16, "seventeenth" => 17, "eighteenth" => 18,
             "nineteenth" => 19, "twentieth" => 20);


             

#definitions for a date grammar.
my $fulOrd = join('|',(keys %ordinals));

my @months = ("january","february","march","april","may","june","july",
              "august","september","october","november","december");

my $shortmth = "";
foreach my $m (@months) { $shortmth .= (substr($m,0,3)."\\.?|"); }
chop($shortmth);

my $longmth = join('|',@months);


my $Qualifier = "(B(\\.)?C(\\.)?(E(\\.)?)?)|(A(\\.)?D(\\.)?)|(C(\\.)E(\\.)?)";
my $Century = "Cent(\\.|ur(y|ies))";
my $Ord = "st|nd|rd|th";
my $seasonref = "(spring|fall|autumn|winter|summer)";
my $sep = " ?- ?";
my $tri_digit = "(in|since|(the year)|($seasonref of)) \\d{3}\\D( ($Qualifier))?";
my $centurydate = "(((\\d{1,2})($Ord))|($fulOrd)) ($Century)( ($Qualifier))?";
my $qualified = "(($Qualifier) ?(\\d{1,4}))|((\\d{1,4}) ?($Qualifier))";
my $millenium = "[1-9]\\d{3}";
my $range = "(($millenium)($sep)($millenium))|(($millenium)($sep)(\\d{1,2}))|(($qualified)($sep)($qualified))|(($Qualifier) ?(\\d{1,3})($sep)(\\d{1,3}))|((\\d{1,3})($sep)(\\d{1,3}) ?($Qualifier))";

my $pgnum = "(p(p|g)?\\.? ?\\d+((-|,)(\\d+))?)|(page \\d+)|(pages \\d+((-|,)(\\d+))?)";
my $lgnum = "\\d{1,3},(\\d{3})+";
my $colon = ":\\d+";
my $money = "\$(\\d{1,3}(((,\\d{3})+)|\\d+))";  $money = "\\" . $money; 
my $microfilm = " reel([^\\.\\)])*(\\.|\\))";
my $lastaltered = "last (edited|updated)";
my $references = "reference(s?)(:?)\\n";
my $cited = "work(s?) cited";
my $biblio = "bibliography(:?)( ?)\\n";

my $direction = "(N(\\.|o\\.|th\\.|orth))|(S(\\.|th\\.|outh))|(E(\\.|ast))|(W(\\.|est))";
my $street_id = "(st\\.)|(street[^A-Za-z])|(ave\\.)|(avenue[^A-Za-z])|(boulevard[^A-Za-z])|(blvd\\.)|(rd\\.)|(road[^A-Za-z])";
my $streetname = "(\\d{1,2}(<SUP>)?($Ord)(</SUP>)?)|([A-Za-z]+( [A-Za-z]+)?)|([A-Za-z]+-[A-Za-z]+($Ord))";
my $address = "\\d{1,4} (($direction) )?($streetname) ($street_id)";

my $bracket = "\\($millenium\\)";
my $ref_end = ", ?$millenium\\)";
my $colonsp = ": $millenium";
my $reprint = "[Rr]eprint of \\d{4} edition";
my $comma = ", $millenium\\.";
my $fullstop = "\\. $millenium\\.";
my $semi = "; $millenium\\.";

my $lookalikes = "($pgnum)|($lgnum)|($colon)|($money)|($microfilm)|($address)";
my $spurious = "($lastaltered)";
my $bibheader = "($references)|($cited)|($biblio)";


sub get_date_metadata {
    #get the text of the document, the "document object" concerned,
    #and the current section within the document
    my ($text, $doc, $cursection, $keep_bib, $max_year, $max_century) = @_;
    
    #format a prechristian maximum century value to be negative so that it can
    #be used in numeric comparison
    if($max_century =~ /B/)
    {
        $max_century = $`;
        $max_century =~ /\d+/;
        $max_century = $&;
        $max_century *=-1
    }
   
    my $extr = &remove_excess($text);    
    #print "EXTRACTION TEXT:\n $extr";
    $extr = &remove_tags($extr);
    if(!$keep_bib){
        $extr = &remove_biblio($extr);
    }
  

    my @datelist = ();
    while($extr =~ m!($range)|($millenium)|($qualified)|($centurydate)|($tri_digit)!i)
    { 
        $extr = $';
        my $fulldate = $&;
        if ($fulldate =~ /$centurydate/i)
        {
            if($max_century!=-1)
            {

                my $date = $fulldate; if($date =~ /\d+/) {$date = $&;} 
                else 
                {
                    $date=$fulldate; $date =~ m! ($Century)!i; $date = $`;
                    $date =~ tr/A-Z/a-z/;
                    $date = $ordinals{$date};
                }
                if($max_century >= $date){
                    $date = ($date-1)*100 +1;
                    #if it BC, make it negative
                    $date = &convert_bc($fulldate,$date);
                    my $end = $date + 99; 
                    my @century = ($date..$end);
                    @datelist = (@datelist,@century);
                }
            }
        }
        
        elsif($fulldate =~ /$range/)
        {
            $fulldate =~ /$sep/;
            my @addlist = ();
            #print "Range: $fulldate\n";
            my $fullfirst = $`; 
            my $fullsecond = $'; 
            $fullfirst =~ /\d+/;
	    my $first = $&; 
            $fullsecond =~ /\d+/;
	    my $second = $&;
            my $len1 = length($first);
            my $len2 = length($second);
            $second = (substr($first,0,($len1-$len2))).$second;
            $first = &convert_bc($fullfirst,$first);
            $second = &convert_bc($fullsecond,$second);
            @addlist = ($first..$second);
            @datelist = (@datelist,@addlist);
            
        }
        else {
            
            my $date = $fulldate; $date =~ /\d+/; $date = $&;  
            $date = &convert_bc($fulldate,$date);
            #add the date metadata
            push(@datelist,$date);
            #print "datelist @datelist\n"
        }
        
    }
    
    if(@datelist){
        @datelist = sort { $a <=> $b } @datelist;
        @datelist = &post_process($max_year, @datelist);
        foreach my $date (@datelist)
        {
            if($date>0){
                $doc->add_metadata($cursection,"Coverage",$date);}
            else{
                $doc->add_metadata($cursection,"Coverage","bc".(-1*$date));}
                
        }
    }
}
sub convert_bc {
    my ($full,$num) = @_;
    if ($full =~ /B/) { $num *= -1; }
    $num;
}

sub post_process {
    my ($max_year, @list) = @_;
    my @cleanlist = ();
    my $prev = 0;
    foreach my $e (@list) {
        if ($e!=$prev && $e <= $max_year) {
            push(@cleanlist, $e);
        }
        $prev = $e;
    }
    @cleanlist;
}


#removes all html tags from that data, as they will not contain dates which
#are part of the content of the document, and therefore interesting, but do
#contain date lookalikes
sub remove_tags {
    my ($tmp) = @_;
   
    my $parsed = "";
    #while there is still text to be parsed and tags are still found
    while($tmp=~ m!<([^>])*(>|$)! && $tmp ne "")
    {
        $parsed .= $`;#keep all that is not in a tag
        $tmp = $';    #restart the search after then end of the tag
    }
    $parsed .= $tmp; #add anything after the last match
    $parsed;
}


sub remove_excess {
    my ($tmp) = @_;
    my $parsed = "";
   

    if(($tmp =~ m!($spurious)|($lookalikes)!i) == 0 )
    { 
        $parsed = $tmp;
    }
    else { 
        while ($tmp =~ m!($spurious)|($lookalikes)!i 
               && $tmp ne "")
        {
            $parsed .= $`;
            my $storage = $&;
            $tmp = $';
            #match the pattern which indicates most recent alteration 
            if ($storage =~ m!$lastaltered!i)
            {
                #match a four digit year or up until the first / 
                #(as in last edited 3/97). 
                $tmp =~ m!($millenium)|(\/)!;
                $tmp = $';
            }
                
        }
        
        $parsed .= $tmp;
           
    }
    #print "Parsed:\n $parsed\n\n";
    $parsed;
    
}

sub remove_biblio{
    my ($tmp) = @_;
    my $parsed = "";
    
    if($tmp =~ m!$bibheader!i)
    {
        $tmp=$`;
    }
    
    $tmp =~ s/( |\t)+/ /g;
    if(($tmp =~ m!($ref_end)|($bracket)|($colonsp)|($reprint)|($comma)|($fullstop)|($semi)|($seasonref) ($millenium)!i) == 0)
    {
        $parsed = $tmp;
    }
    else{

        #print "removing bib\n";
        while ($tmp =~ m!($ref_end)|($bracket)|($colonsp)|($reprint)|($comma)|($fullstop)|($semi)|(($seasonref) ($millenium))|($bibheader)!i && $tmp ne "")
        {
            
            $parsed .= $`;
            $tmp = $';
            if($&=~m!($comma)|($fullstop)!)
            {
                
                my $date = $&;
                if($parsed =~ m!((\d)($Ord)$)|(($shortmth)$)|(($longmth)$)!i)
                {
                    $parsed .= $date;
                }
            }  
            
        }
                   $parsed .= $tmp;
    }
    $parsed;
}


1;
