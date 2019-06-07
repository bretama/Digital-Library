#!/usr/bin/perl
#Jessica Thurston
#usage: perl amend_pdf.pl filename
#This program takes a pdf file 'filename'
#and modifys it to include outline entries
#(bookmarks).  
#This is achieved using a pdf library which
#parses the pdf file into objects allowing 
#this script to more easily manipulate the pdf
#objects and then modify the file by means
#of incremental updates. (modifys the necessary
#pdf objects and appends them to the end of 
#the file, then updates the xreference table and
#trailer). This library can be downloaded at
# http://www.sanface.com/PDF-lib/
#A file url.txt stored in the same
#directory is read containing two columns of data:
#title of related pdf document     url of related pdf document
#The pdf document is modified so that the title of the
#related pdf documents are displayed as bookmarks and
#when the user clicks on it the web browser opens at
#the url stored in the same column of url.txt.
#
#This program was designed to be used with the Greenstone
#digital library in the following ways:
#-When a user has built a collection containing
# pdf documents, they have a choice of either displaying
# the page in the web browser in gml form or saving the
# original pdf document to view in an acrobat pdf reader.
#-The related document file url.txt can be downloaded
# in the same way if the user has included in the format
# string for that page (ie search list) in the collection 
# configuration file [urllink] related documents [/urllink].  
# This will create a html link 'related documents' which 
# when clicked on will enable the user to save a file url.txt 
# containing the related documents for that particular document. 
#-This file has been written upon running the perl script
# relationPDF.pl which will also amend the gml documents to 
# include the 'urllink' information enabling the user to 
# include the related document links in config file format 
# strings.
#-So once this related doc info has been included the user
# can download both the pdf file (doc.pdf) and the related
# document file for that particluar document (url.txt).
#-perl amend_pdf.pl doc.pdf is then run in the command line
# modifying the pdf document to the desired effect.  
#bugs:
#-cannot be run more than once on the same file
#-doesn't make use of free objects (free objects
# are quite unlikely though, I didn't come across
# any while looking through pdfs)
#-many other things I haven't bothered testing

use Carp;
use Getopt::Long;
use PDF;

$objects = 0;
$offsets = 1;


#for each command line argument add the outlines
#contained in url.txt
#foreach (@ARGV) {
#    create_outlines($_); 
#}

if(defined $ARGV[0]){
    $pdf_document = $ARGV[0];
} else {
    print STDERR "You must supply pdf document filename\n";
    return;
}
if(defined $ARGV[1]){
    $related_docs = $ARGV[1];
} else {
print STDERR "You must supply related document filename\n";
return;
}
create_outlines($pdf_document); 

exit(1);


#this function first checks to see is the file is indeed
#a pdf file - if not then exits. If it is a pdf then it
#checks to see if it is encrypted. If it is then exits.
#Next we check if the outlines dictionary exists in the
#document catalog. 
#-If the outline entry exists but there are no actual outlines
# present then call add_outlines but pass on the existing
# outline dictionary.
#-otherwise call modify_outlines to modify the existing outline
# structure to include new outlines.
#If outlines dictionary doesn't exist call add_outlines.
sub create_outlines {

  my $filename = shift;

  #parse pdf filename
  my @filelist = split("/", $filename);
  my $file = pop @filelist;

  print STDERR "pdf file to be manipulated: $file\n";
  print STDERR "pdf file to be saved: tmp_$file\n";

  #make a copy of that file in this directory
  print STDERR "cp $filename $file\n"; 
  `cp $filename $file\n`; 
  `cp $filename tmp_$file\n`; 

  #create and parse a new 'pdf' object
  my $PDFfile = PDF->new($file);  

  #if it is a pdf file
  if ($PDFfile->{"Header"}){

      if($PDFfile->IscryptPDF){
	  #an encrypted file so cannot continue with
	  #adding the related doc outlines to it 
	  print STDERR "file \"$file\" is encrypted \n"; 
	  return;
      }

      #display some relevant information about the document
      print STDERR "Author: ", $PDFfile->GetInfo ("Author"), "\n"; 
      print STDERR "Title: ", $PDFfile->GetInfo ("Title"), "\n"; 
      print STDERR "Subject: ", $PDFfile->GetInfo ("Subject"), "\n"; 
      print STDERR "Updated: ", $PDFfile->{"Updated"}, "\n";
     
      #if the pdf document already includes an outline dictionary
      if (defined $PDFfile->{"Catalog"}{"/Outlines"}) {

	  #get the outline object from the indirect ref
	  my $outline_data = $PDFfile->GetObject($PDFfile->{"Catalog"}{"/Outlines"});
	  #obtain the number of existing outlines
	  $PDFfile->{"Outlines"}{"/Count"} = $outline_data->{"/Count"};
	  print STDERR "number of existing outlines: $PDFfile->{\"Outlines\"}{\"/Count\"}\n";

	  #this means that the pdf file had an outline dictionary but
	  #did not actually include any outlines.
	  if($PDFfile->{"Outlines"}{"/Count"} == 0){
	      #obtain object number of outline dictionary and pass to add_outlines
	      my $dictionary = split(/\s/, $PDFfile->{"Catalog"}{"/Outlines"});
	     
	      add_outlines($PDFfile, $file, $dictionary);
	  } else { 
	      #collect other outline data to pass to modify_outlines
	      $PDFfile->{"Outlines"}{"/First"} = $outline_data->{"/First"};
	      $PDFfile->{"Outlines"}{"/Last"} = $outline_data->{"/Last"};

	      #modify last outline entry
	      modify_outlines($outline_data, $PDFfile, $file);
	  }
      } else { #there was no outline dictionary thus no outlines so add some
	  print STDERR "no bookmarks in \"$file\" \n"; 
	  add_outlines($PDFfile, $file, 0);
      }
  } else { #the file was not a pdf file
      print STDERR "$file is not a pdf file!!\n"; 
  }


  #copy back the file we modified and the saved copy 
  my $copypath = join("/", @filelist);
  print STDERR "cp $file $filename\n"; 
  print STDERR "cp tmp_$file $copypath/tmp_$file\n"; 
  `cp $file $filename\n`; 
  `cp tmp_$file $copypath/tmp_$file\n`; 

  #remove the copy of that file in this directory
  #print STDERR "rm $file\n"; 
  `rm $file\n`;  
  `rm tmp_$file\n`; 
}


#add_outlines function recieves following params
#PDF file information, filename of pdf file, outline dictionary
#(if outline dict. is 0 that means it must be created).
#First the function decides if we are to create new dictionary
#or not. Next read in the url file. Open up the pdf document.
#Modify the catalog so that it includes the outline dictionary
#(this is done even if the catalog doesn't need modifying 
# so that the objects in the objects/offset table will not
# be all mucked up when it comes time to write the xreference
# table)
#Then append outline dictionary to end of file (either modified
#or created). Then append the top heirarchy related document
#outline.  Then the new file url bookmarks. Call  xref_table
#to write new xreference table. Call trailer to write new trailer.

#table[0][0] - document catalog
#table[0][1] - document catalog offset
#table[1][0] - outline dictionary
#table[1][1] - outline dictionary offset
#table[2][0] - related document outline
#table[2][1] - related document outline offset
#table[3][0] etc - url outlines, read from file
#table[3][1] etc - url outlines offset, read from file

sub add_outlines (*\$){
    
 my $PDFfile = shift; 
 my $file = shift; 

 my @table;
 $table[1][$objects] = shift;

 #read in file of url's
 my @urls = read_file(); 
 my $url_num = $#urls + 1;
 
 #if outline dictionary was not present in catalog
 if ($table[1][$objects] == 0){ #get new object number for new dictionary
     $table[1][$objects] = $PDFfile->{"Trailer"}{"/Size"}; #outline dictionary to be created
     $table[2][$objects] = $table[1][$objects] + 1; #related document outline
 } else { #else get object number for related doc outline to be appended
     $table[2][$objects] = $PDFfile->{"Trailer"}{"/Size"}; #related document outline
 }
 
 #open up pdf file for appending
 open(FILE, ">> $file") or croak "can't open $file: $!"; 
 binmode \*FILE;
 
 #obtain object number and offset for the document catalog
 $table[0][$objects] = split(/\s/, $PDFfile->{"Trailer"}{"/Root"});
 $table[0][$offsets] = tell \*FILE;

 #print the modified or original catalog back to the file (appended)
 print FILE "$table[0][$objects] 0 obj";
 print FILE "<<";
 print FILE "/Pages $PDFfile->{\"Catalog\"}{\"/Pages\"}";
 print FILE "/Outlines $table[1][$objects] 0 R"; #only line actually added
 print FILE "/Type /Catalog";
 print FILE "/DefaultGray $PDFfile->{\"Catalog\"}{\"/DefaultGray\"}"
     if (defined ($PDFfile->{"Catalog"}{"/DefaultGray"}));
 print FILE "/DefaultRGB $PDFfile->{\"Catalog\"}{\"/DefaultRGB\"}"
     if (defined ($PDFfile->{"Catalog"}{"/DefaultRGB"}));
 print FILE "/PageLabels $PDFfile->{\"Catalog\"}{\"/PageLabels\"}"
     if (defined ($PDFfile->{"Catalog"}{"/PageLabels"}));
 print FILE "/Names $PDFfile->{\"Catalog\"}{\"/Names\"}" 
     if (defined ($PDFfile->{"Catalog"}{"/Names"}));
 print FILE "/Dests $PDFfile->{\"Catalog\"}{\"/Dests\"}"
     if (defined ($PDFfile->{"Catalog"}{"/Dests"}));
 print FILE "/ViewerPreferences $PDFfile->{\"Catalog\"}{\"/ViewerPreferences\"}"
     if (defined ($PDFfile->{"Catalog"}{"/ViewerPreferences"}));
 print FILE "/PageLayout $PDFfile->{\"Catalog\"}{\"/PageLayout\"}"
     if (defined ($PDFfile->{"Catalog"}{"/PageLayout"}));
 print FILE "/PageMode $PDFfile->{\"Catalog\"}{\"/PageMode\"}"
     if (defined ($PDFfile->{"Catalog"}{"/PageMode"}));
 print FILE "/Threads $PDFfile->{\"Catalog\"}{\"/Threads\"}"
     if (defined ($PDFfile->{"Catalog"}{"/Threads"}));
 print FILE "/OpenAction $PDFfile->{\"Catalog\"}{\"/OpenAction\"}"
     if (defined ($PDFfile->{"Catalog"}{"/OpenAction"}));
 print FILE "/URI $PDFfile->{\"Catalog\"}{\"/URI\"}"
     if (defined ($PDFfile->{"Catalog"}{"/URI"}));
 print FILE "/Acroform $PDFfile->{\"Catalog\"}{\"/Acroform\"}"
     if (defined ($PDFfile->{"Catalog"}{"/Acroform"}));
 print FILE "/StructTreeRoot $PDFfile->{\"Catalog\"}{\"/StructTreeRoot\"}"
     if (defined ($PDFfile->{"Catalog"}{"/StructTreeRoot"}));
 print FILE "/SpiderInfo $PDFfile->{\"Catalog\"}{\"/SpiderInfo\"}"
     if (defined ($PDFfile->{"Catalog"}{"/SpiderInfo"}));
 print FILE ">>";
 print FILE "endobj";
 
 #obtain offset for outline dictionary
 $table[1][$offsets] = tell \*FILE;

 #append newly created outline dictionary
 print FILE "$table[1][$objects] 0 obj";
 print FILE "<<";
 print FILE "/Type /Outlines";
 print FILE "/Count ", $url_num + 1, "";
 print FILE "/First $table[2][$objects] 0 R";
 print FILE "/Last $table[2][$objects] 0 R";
 print FILE ">>";
 print FILE "endobj";


 #get the related document outline object num and offset
 my $obj = $table[2][$objects]; 
 $table[2][$offsets] = tell \*FILE;

 #append the top heirarchy related document outline to file 
 print FILE "$table[2][$objects] 0 obj";
 print FILE "<<";
 print FILE "/Title (Related Documents)";
 print FILE "/Parent $table[1][$objects] 0 R";
 print FILE "/Count ", $url_num, "";
 print FILE "/First ", $obj + 1, " 0 R";
 print FILE "/Last ", $table[2][$objects] + $url_num, " 0 R";
 print FILE ">>";
 print FILE "endobj";

 my $ind = 3;
 $obj++;

 
 #store the object nums and offsets of the new related document
 #outlines and write them to the file (must be outline with
 #an action eg go to specific url)
 for $i ( 0 .. $#urls ) {
     $table[$ind][$offsets] = tell \*FILE; 
     $table[$ind][$objects] = $obj; 
     print FILE "$obj 0 obj";
     print FILE "<<";
     print FILE "/Title ($urls[$i][0])"; 
     print FILE "/Parent $table[2][$objects] 0 R";
     print FILE "/Next ", $obj + 1, " 0 R" if (($obj + 1) <= ($table[2][$objects] + $url_num)); 
     print FILE "/Prev ", $obj - 1, " 0 R" if(($obj - 1) != ($table[2][$objects]));
     print FILE "/A << /Type /Action";
     print FILE "/S /URI"; 
     print FILE "/URI ($urls[$i][1])"; 
     print FILE ">>";
     print FILE ">>";
     print FILE "endobj";
     $obj++;
     $ind++; 
 }


 #append new X-reference table 
 my $xref_offset = tell \*FILE;
 xref_table(\*FILE, $url_num, @table);

 #print trailer 
 trailer(\*FILE, $PDFfile, $obj); 
 print FILE "$xref_offset";
 print FILE "%%EOF"; 

 #close FILE;
}

#modify_outlines function recieves following params
#PDF file information, outline data, pdf filename
#First the function obtains the object data for the
#last outline entry. Next read in the url file. 
#Open up the pdf document.Then append the modified 
#outline dictionary to end of file. Next append the
#modified last outline.  Then append the 
#top heirarchy related document outline.  Then the 
#new file url bookmarks. Call  xref_table
#to write new xreference table. 
#Call trailer to write new trailer.

#table[0][0] - outline dictionary
#table[0][1] - outline dictionary offset
#table[1][0] - last outline
#table[1][1] - last outline offset
#table[2][0] - related document outline
#table[2][1] - related document outline offset
#table[3][0] etc - url outlines, read from file
#table[3][1] etc - url outlines offset, read from file

sub modify_outlines (*\$){

    my ($outline_data, $PDFfile, $file) = @_;

    #collect the data for the last outline (which must be modified)
    $PDFfile->{"Outlines"}{"/Last"} = $outline_data->{"/Last"};
    my $last_data = $PDFfile->GetObject($PDFfile->{"Outlines"}{"/Last"});  

    #read in file of url's
    my @urls = read_file(); 
    my $url_num = $#urls + 1;
 
    my @table;

    #This number is the number to use for the next created object
    #eg the related doc heirarchy
    $table[2][$objects] = $PDFfile->{"Trailer"}{"/Size"};
  
    #open up the pdf file for appending
    open(FILE, ">> $file") or croak "can't open $file: $!"; 
    binmode \*FILE;
    
    #store the object number and offset of the outline dictionary
    $table[0][$objects] = split(/\s/, $PDFfile->{"Catalog"}{"/Outlines"});
    $table[0][$offsets] = tell \*FILE;
   
    #write the outline dictionary back to the file (appending)
    print FILE "$table[0][$objects] 0 obj";
    print FILE "<<";
    print FILE "/Type /Outlines";
    print FILE "/Count ", $PDFfile->{"Outlines"}{"/Count"} + 1, ""
	if (defined ($PDFfile->{"Outlines"}{"/Count"}));
    print FILE "/First $PDFfile->{\"Outlines\"}{\"/First\"}"
	if (defined ($PDFfile->{"Outlines"}{"/First"}));
    print FILE "/Last $table[2][$objects] 0 R";
    print FILE ">>";
    print FILE "endobj";
    
    #store the last outline entry object num and file offset
    my @last_entry = split(/\s/, $PDFfile->{"Outlines"}{"/Last"});
    $table[1][$objects] = $last_entry[0]; 
    $table[1][$offsets] = tell \*FILE; 

    #append modified last outline entry
    print FILE "$table[1][$objects] 0 obj";
    print FILE "<<";
    print FILE "/Title $last_data->{\"/Title\"}";
    print FILE "/Dest $last_data->{\"/Dest\"}" if(defined $last_data->{"/Dest"});
    print FILE "/Parent $last_data->{\"/Parent\"}";
    print FILE "/Prev $last_data->{\"/Prev\"}";
    print FILE "/Next $table[2][$objects] 0 R";
    print FILE "/First $last_data->{\"/First\"}" if(defined $last_data->{"/First"});
    print FILE "/Last $last_data->{\"/Last\"}" if(defined $last_data->{"/Last"});
    print FILE "/Count $last_data->{\"/Count\"}"if(defined $last_data->{"/Count"});
    print FILE "/A $last_data->{\"/A\"}" if(defined $last_data->{"/A"});
    print FILE "/SE $last_data->{\"/SE\"}" if(defined $last_data->{"/SE"});
    print FILE ">>";
    print FILE "endobj";
    
    #store the object num and offset of the related
    #document top level outline
    my $obj = $table[2][$objects] + 1;
    $table[2][$offsets] = tell \*FILE;

    #append related document top level outline
    print FILE "$table[2][$objects] 0 obj";
    print FILE "<<";
    print FILE "/Title (Related Documents)"; 
    print FILE "/Parent $last_data->{\"/Parent\"}";
    print FILE "/Count ", $url_num, "";
    print FILE "/First $obj 0 R";
    print FILE "/Last ", $table[2][$objects] + $url_num , " 0 R";
    print FILE ">>";
    print FILE "endobj";
    
   
    my $ind = 3;

    #store the object nums and offsets of the new related document
    #outlines and write them to the file (must be outline with
    #an action eg go to specific url)
    for $i ( 0 .. $#urls ) { 
	$table[$ind][$objects] = $obj;  
	$table[$ind][$offsets] = tell \*FILE; 
	print FILE "$obj 0 obj";
	print FILE "<<";
	print FILE "/Title ($urls[$i][0])"; 
	print FILE "/Parent $table[2][$objects] 0 R";
	print FILE "/Next ", $obj + 1, " 0 R" if (($obj + 1) <= ($table[2][$objects] + $url_num)); 
	print FILE "/Prev ", $obj - 1, " 0 R" if (($obj - 1) != ($table[2][$objects]));
	print FILE "/A << /Type /Action";
	print FILE "/S /URI"; 
	print FILE "/URI ($urls[$i][1])"; 
	print FILE ">>";
	print FILE ">>";
	print FILE "endobj";
	$obj++;
	$ind++;
    }
    
    #append new X-reference table
    my $xref_offset = tell \*FILE;   
    xref_table(\*FILE, $url_num, @table); 
  
    #print trailer  
    trailer(\*FILE, $PDFfile, $obj);
    print FILE "$xref_offset";
    print FILE "%%EOF"; 

    close FILE;

}


#This function reads a file 'url.txt' which contains
#two columns of data in the following format:
#related document title    related document url
#each array of title, url is stored in an array
#(to obtain the title of the first related  
#document in the file)
#eg table[1st related document][title] 
#(to obtain the url of the second related 
#document in the file)
#eg table[2nd related document][url]
#this table is then returned to the calling 
#function.
sub read_file {

    #create two-dimensional array for urls
    my @urls;

    #open up url.txt to start reading
    open(URL, "$related_docs") or croak "Can't open $related_docs: $!"; 

    my $counter = 0;

    #read in url.txt and store into the arry
    while (<URL>){
	chomp;
	if(/([^\t]*)\t(.*)/){ 
	    push @urls, [ split ]; #split on /s into arrays of arrays
	}
    }

    close URL;

    return (@urls);

}

 
#this function takes as parameters the filehandle
#to the pdf document, the number of related documents
#to this pdf doc and a table of object numbers and
#their offsets. Using this information it writes
#(appends) a new xreference table to the pdf 
#document. 

sub xref_table  (*\$) {
    
    my ($fd, $num, @table) = @_;
    my $offset;

    #print the new xref table (append to file)
    print $fd "xref";
    print $fd "0 1 ";
    print $fd "0000000000 65535 f ";
    print $fd "$table[0][$objects] 1 ";
    $offset = '0'x(10-length($table[0][$offsets])).$table[0][$offsets];
    print $fd "$offset 00000 n ";
    print $fd "$table[1][$objects] 1 "; 
    $offset = '0'x(10-length($table[1][$offsets])).$table[1][$offsets];
    print $fd "$offset 00000 n ";
    print $fd "$table[2][$objects] ", $num + 1, " "; 
    for $i ( 2 .. ($num + 2) ) { #add 2 on because already written 2 to file
	$offset = '0'x(10-length($table[$i][$offsets])).$table[$i][$offsets];
	print $fd "$offset 00000 n ";
    }
    
}


#This function recieves as parameters the filehandle
#to the pdf document, parsed information about the
#document and the new size (last object number + 1)
#of the pdf file.  Using this information it appends
#a new trailer to the end of the pdf document.

sub trailer  (*\$) {

    my ($fd, $PDFfile, $new_size) = @_;

    #append the new trailer to the end of the file
    print $fd "trailer";
    print $fd "<<";
    print $fd "/Size ", $new_size, "";
    print $fd "/Root $PDFfile->{\"Trailer\"}{\"/Root\"}";
    print $fd "/Info $PDFfile->{\"Trailer\"}{\"/Info\"}" 
	if (defined ($PDFfile->{"Trailer"}{"/Info"}));
    print $fd "/ID [$PDFfile->{\"Trailer\"}{\"/ID\"}[0]$PDFfile->{\"Trailer\"}{\"/ID\"}[1]]"
	if (defined ($PDFfile->{"Trailer"}{"/ID"}));
    print $fd "/Prev $PDFfile->{\"Last_XRef_Offset\"}";
    print $fd "/Encrypt $PDFfile->{\"Trailer\"}{\"/Encrypt\"}"
	if (defined ($PDFfile->{"Trailer"}{"/Encrypt"}));
    print $fd ">>";
    print $fd "startxref";
   
}



