#!/usr/bin/perl

#data structures used:
#-document_keyphrase
#%document_phrases = ("hashID" => {"phrase" => "number of occurrences"})
#-keyphrase_document 
#%phrases_document = ("phrase" => "no. of docs phrase occurs in")

#after calculation relational data, it will amend gml files
#to include this data while writing to a file ID_relatedlinks.txt
#the html links of the related files
#if option p is set then the user wishes to add the related documents
#as bookmarks to the pdf file

require "getopts.pl";
&Getopts('N:P'); #process option arguments


$gsdlhome = $ENV{'GSDLHOME'};
@directories; #list of directories for the collections
%phrases_document; #hash storing phrase index => no. of documents with phrase in it
%document_phrases; #hash of hashes ID => {phrase number => no. of phrases in ID}
$N = 0; #number of documents in the index (presumably in the collection)
%cosine_matrix; #2-dimensional matrix, for each pair of documents stores a cosine measure
$number_of_files = 1; #by default the top related file is returned
$do_pdfs = 0;

if($opt_N =~ /(\d)+/){ #if flag is set then return top N docs
    $number_of_files = $opt_N;
}

#get server name and httpprefix
$httpprefix;
$servername = "nzdl2.cs.waikato.ac.nz"; #should be localhost

if($opt_P == 1){ #if flag is set 
    $do_pdfs = 1;
    
    #get the httpprefix from gsdlsite.cfg
    my $cgibin = "cgi-bin/$ENV{'GSDLOS'}";
    $cgibin = $cgibin.$ENV{'GSDLARCH'} if defined $ENV{'GSDLARCH';}
    open(CFG, "$gsdlhome/$cgibin/gsdlsite.cfg") 
	or die "$gsdlhome/$cgibin/gsdlsite.cfg could not be opened";
    
    while(<CFG>){
	chomp;
	if(/httpprefix \/(.+)/){
	    $httpprefix = $1; 
	}
    }
    close CFG;
}

if(@ARGV){

    @directories = @ARGV;

} else { #open collect directory and get a list of all collections
    opendir(DIR, "$gsdlhome/collect");
    @directories = grep(!/(^\.|(CVS)|(modelcol))/, readdir(DIR));
    closedir(DIR);
}



#get the name of the directory the index will be stored in
$dirname = "";
foreach $collection (sort @directories){
    $dirname .= $collection."_";
}
$dirname .= "indexes";
print STDERR "directory name: $dirname\n";

#open keyphrases_document.txt
open(KEY_FILE, "$gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt") 
    or die "$gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt could not be opened";

print STDERR "\nreading keyphrase_document.txt...\n";

#read a list of phrase indexes and number of documents that phrase appears in 
while(<KEY_FILE>){
    chomp;
    if(/(\d+)\:(\d+)(.*)/){ #all lines should be of this form
	my $phrase_index = $1;
	my $doc_num = $2;
	$phrases_document{"$phrase_index"} = "$doc_num"; #build keyphrase hash
    }
}

close(KEY_FILE); 

print STDERR "\nreading document_keyphrase.txt...\n";

#open document_keyphrases.txt
open(DOC_FILE, "$gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt") 
    or die "$gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt could not be opened";

#read a list of documents and the phrases that appear in them (& how many times they appear)
while(<DOC_FILE>){
    chomp;
    my %document;
    if(/(\w+)\:(\d+)((\|\d+,\d+)+)/){ #every line in the index of this form
	my $ID = $1;
	my $pairs = $3;
	while ($pairs =~ s/\|(\d+),(\d+)//) { #this is the list of keyphrases and numbers
	    my $phrase_index = $1;
	    my $num_phrase = $2;
	    $document{"$phrase_index"} = "$num_phrase"; #table to be stored in another table
	}
	$document_phrases{"$ID"} = ({%document});	  
	$N++; #number of documents in the collection (which have kea metadata)
    }
}

close(DOC_FILE);
 
#we do not want to recalculate measures ie if we have already calculated
#doc1 & doc2 we do not then want to calculate doc2 & doc1
#to achieve this we must first sort the list of ids so that both lists
#of documents will be in the same order (otherwise hash tables return values in 
#no particular order). We then compare each document in the left 
#column below against the documents in the right column:

#doc0 -> 
#doc1 -> doc0 
#doc2 -> doc0, doc 1 
#doc3 -> doc0, doc 1, doc 2 
#doc4 -> doc0, doc 1, doc 2, doc 3 
#doc5 -> doc0, doc 1, doc 2, doc 3, doc 4 
#etc

#this way we are not recalculating the same value and also not
#comparing each document to itself (which would result in the
#value 1) thus more than halving the processing time.

print STDERR "\ncalculating cosine measures for $N documents...\n";

$count = 0;
@ids = sort keys(%document_phrases);

#repeat for all pairs of documents
foreach $id1 (sort keys(%document_phrases)) { 
    my %table;
   
    for($i=0; $i<$count; $i++){ #calculate the cosine measure and store
	my $cosine_measure = &compare_docs($id1, $ids[$i]); 
	$table{"$ids[$i]"} = "$cosine_measure";  	
    }
    $cosine_matrix{"$id1"} = ({%table});
    $count++; #each iteration the number of documents to compare against expands by 1
}

&addtogml(); #add the relational data we have just gathered to the documents gml files

   
#this function takes as an argument two document IDs and uses these to extract the
#keyphrases from the document_keyphrase data structure.  It then calculates a 
#'measure of relativity' [0-1] with which we can establish how similar the two
#documents are to each other. (0-not related, 1-same document).  The equation 
#used to establish this similarity:
#
#                     for all phrases 
#                     in both d1, d2 (fd1p * loge(N/fp) (fd2p * loge(N/fp) 
#  cosine(d1, d2) = --------------------------------------------------------------
#                     sqrt(sum of phrases in d1(fd1p * loge(N/fp))) * 
#                     sqrt(sum of phrases in d2(fd2p * loge(N/fp))) 
#
#where d1 and d2 are lists of keyphrase and represent documents
#fd1p is the frequency that phrase p occurs in document d1
#fd2p is the frequency that phrase p occurs in document d2
#fp is the number of documents that have p as a keyphrase
#N is the number of documents in the collection 
sub compare_docs {

  
    my $ID1 = shift(@_); #ID for document one 
    my $ID2 = shift(@_); #ID for document two
  
    my @phrases; #a list of phrases in document 1 and document 2
    my @phrases1; #a list of phrases in document 1
    my @phrases2; #a list of phrases in document 2
    
    
    foreach $phrase (keys %{ $document_phrases{$ID1}}) { #list of phrases in doc1
	push(@phrases1, $phrase);
    } 
    foreach $phrase (keys %{ $document_phrases{$ID2}}) { #list of phrases in doc2
	push(@phrases2, $phrase);
    }
    foreach $phrase1 (@phrases1) { #list holds intersection of doc1 and doc2
	foreach $phrase2 (@phrases2) {
	    push(@phrases, $phrase1) if ($phrase1 == $phrase2);
	}
    }
 
#COSINE MEASURE
    my $wqtwdt= 0; 
   
    foreach $phrase (@phrases){ #for all phrases ocurring in d1 and d2
	#the frequency that phrase occurs in document d1
	$fd1p = $document_phrases{$ID1}{$phrase}; 
	
	#log base e(N/the number of documents that have phrase as a keyphrase)
	$log_freq = log($N/$phrases_document{$phrase});
	
	#the frequency that phrase occurs in document d2
	$fd2p = $document_phrases{$ID2}{$phrase};
	$sum = ($fd1p * $log_freq) * ($fd2p * $log_freq);
	$wqtwdt += $sum;
    }
  
   
    my $wd = 0; #stores the calculation for wd

    foreach $phrase (@phrases1){ #for all phrases ocurring in d1 and d2
	#the frequency that phrase occurs in document d1
	$fd1p = $document_phrases{$ID1}{$phrase};
	
	#log base e($N/the number of documents that have phrase as a keyphrase)
	$log_freq = log($N/$phrases_document{$phrase});
	$sum = $fd1p * $log_freq;
	$wd += ($sum * $sum); #sum squared
    }

   
    my $wq = 0; #stores the calculation for wq
 
    foreach $phrase (@phrases2){ #for all phrases ocurring in d2
	#the frequency that phrase occurs in document d2
	$fd2p = $document_phrases{$ID2}{$phrase};

	#log base e($N/the number of documents that have phrase as a keyphrase)
	$log_freq = log($N/$phrases_document{$phrase});
	$sum = $fd2p * $log_freq;
	$wq += ($sum * $sum); #sum squared 
    }
   
    my $wdwq = sqrt($wq)  * sqrt($wd);  
    my $cosine = $wqtwdt / $wdwq;
    
    return $cosine;
	
}
   
#this function adds the relational data we have collected to the gml files
sub addtogml {

 print STDERR "\nadding relational data to $N gml documents...\n\n";
 my @doclist;
 my %filetable;
 my $pattern = "kea="; #pattern to search for to find where to insert relation data

 #open archive info for each collecticollection
 foreach $collection (@directories){

     open(INFO, "$gsdlhome/collect/$collection/archives/archives.inf") 
	 or die "$gsdlhome/collect/$collection/archives/archives.inf could not be opened";
     
     #read a list of ID's and pathnames into a file table
     while(<INFO>){
	 chomp;
	 my %idtable;
	 my $ID;
	 if(/(\w+)(\s+)([\w\.\/]+)/){ #format of the line
	     $ID = $1;
	     $path = $3;
	     $idtable{"$path"} = "$collection";
	 }
	 $filetable{"$ID"} = ({%idtable});
     } 
  
     close(INFO);
 }

 

 #for each id in the matrix calculate a list of related documents
 foreach $id (keys %cosine_matrix){    
    
     @doclist = &calculate_list($id); #gets list of documents with most relevant scores

     my @path = keys %{$filetable{$id}}; #get filepath for document
     my $collection = $filetable{$id}{$path[0]};
     
     #open gml file to amend for each collection
     open(FILE, "$gsdlhome/collect/$collection/archives/$path[0]") 
	 or die "$gsdlhome/collect/$collection/archives/$path[0] could not be opened";
     
     #read the gml file into text
     $text = ""; 
     while(<FILE>){
	 $text .= $_;
     }
     
     close(FILE);
     
     #delete previous relational data and urllinks to files storing rel doc links
     $text =~ s/(\s)+relation=\"([^\"]*)\"//g;
     $text =~ s/(\s)+urllink=\"([^\"]*)\"//g;
     $text =~ s/(\s)+\/urllink=\"([^\"]*)\"//g;
     
     #if we want to insert each relation item as 'relation1="id" relation2="id"'
     #$count = 1; #insert each item in the list
     #foreach $item (@doclist){ #insert list into text
     #	 $text =~ s/(\s)($pattern)/ relation$count=\"$item\" $2/g;
     #	 $count++;
     #} 
     
     #or relation="id, id, id"
     #my $relation = join(",", @doclist);

     #if pdf flag is set then delete pdf url document
     if($do_pdfs == 1){ 
	 my $dirpath = $path[0];
	 $dirpath =~ s/(^(\/doc\.gml))*\/doc\.(gml)/$1/;
 	 `rm $gsdlhome/collect/$collection/index/assoc/$dirpath/url.txt`; 
     }

     my $title = "related document";
     $title = $2 if($text =~ /(\s)+Title=\"([^\"]*)\"/g);
   
     #relation="collection,id collection,id"
     my @relationlist;
     my $relation = "";
     foreach $doc (@doclist){
	 my @p = keys %{$filetable{$doc}};
	 my $collect = $filetable{$doc}{$p[0]};
	 push(@relationlist, "$collect,$doc");

	 #write pdf docs to file
	 if($do_pdfs == 1){
	     my @rel_path = keys %{$filetable{$doc}};
	     &write_related_urls($title, $collection, $path[0], $collect, $rel_path[0]);
	 }
     }
  
     #modify the text to include relation data
     $relation = join(" ", @relationlist); 
     $text =~ s/($pattern)/ relation=\"$relation\" $1/g;

     #open gml file to write back new text
     open(FILE, ">$gsdlhome/collect/$collection/archives/$path[0]") or print STDERR "NO!!!!\n";
     print FILE "$text"; #write back text
     close(FILE);

     #amend the pdf file 
     if($do_pdfs == 1){
	 my $pdf_path = $path[0];
	 $pdf_path =~ s/(^(\/doc\.gml))*\/doc\.(gml)/$1/;
	 `perl amend_pdf.pl $gsdlhome/collect/$collection/index/assoc/$pdf_path/doc.pdf $gsdlhome/collect/$collection/index/assoc/$pdf_path/url.txt\n`;
     }
 } 
}

#this function builds a list of cosine measures for each
#document and sorts the list of ids each measure belongs to
#in reverse order (ie docs with greatest cosine measure first)
#returns the list calculated
sub calculate_list {
   
    my $document = shift(@_);
    my %measures;
    my @doclist;
    
    
    #find the top $number_of_files for $document  
    foreach $id (keys %{$cosine_matrix{$document}}){ 
	    $measures{"$cosine_matrix{$document}{$id}"} = "$id";
    }
    
    my @list = reverse sort {$a<=>$b} keys %measures;

    #list is as big as specified in command line (default is 1)
    for($i = 0; $i<$number_of_files; $i++){ 
	my $id = $measures{$list[$i]};
	push(@doclist, $id) if($id ne "");
    }

    return @doclist;
}


sub write_related_urls {

    
 #need server name eg nzdl2.cs.waikato.ac.nz
 #localhost should work but doesn't on this computer?
 #open up config file to read httpprefix
 #get collection name of related document
 #get hash directory of related document
 #write http://nzdl2.cs.waikato.ac.nz/httpprefix/collectionname/index/assoc/directory/doc.pdf

 my ($title, $collection, $path, $collect, $rel_path) = @_;

 $rel_path =~ s/(^(\/doc\.gml))*\/doc\.(gml)/$1/;
 $path =~ s/(^(\/doc\.gml))*\/doc\.(gml)/$1/;
 
 print STDERR "writing related pdf urls to file ";
 print STDERR "$gsdlhome/collect/$collection/index/assoc/$path/url.txt...\n";
 
 open(URL, ">>$gsdlhome/collect/$collection/index/assoc/$path/url.txt") 
     or open(URL, ">$gsdlhome/collect/$collection/index/assoc/$path/url.txt")
	 or print STDERR "This file $title is not a pdf file\n";

 print URL "$title\t"; 
 print URL "http://$servername/$httpprefix/collect/$collect/index/assoc/$rel_path/doc.pdf\n";
 close URL;

}







