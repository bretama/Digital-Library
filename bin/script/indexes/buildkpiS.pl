#! /user/bin/perl 

#usage: perl buildkpiS.pl [-R] [collection] [collection] etc
#
#-r or -R will remove previous index files so that you may build new ones
#
#The program performs the following tasks:
#-gathers the specified collections on the command line OR
#-gathers the directories of all the collections in the collect directory, this is all
# the directories apart from CVS, modelcol, . and .. which are not collections.
#-It then retrieves the archive.inf file from the archive directory of each collection
# to obtain the unique file ID and filepath of every document in the collection
#-Then parse through each doc.gml stored in filepath to gather information
#-From each file collect stems of kea keyphrases.
#-Determine the number of keyphrase stems for each document 
#-Search for the keyphrase stems in the numbered phrase index. If a phrase is not there then 
# the program will write the keyphrase stem to the phrase index . 
#-Search for the keyphrase stem in the keyphrase to document index. If the stem is there, 
# it will increment the number of documents that the keyphrase stem appears in and replace that
# then append the hash ID to the list of documents in the entry. If the stem is not there 
# then the program will write the stem to the phrase index.
#-Then write document ID, no of phrase, phrase number from index followed by number of times 
# phrase appears into the document_keyphrase index

$gsdlhome = $ENV{'GSDLHOME'};
$collection;

require "getopts.pl";
&Getopts('R'); #process option arguments

#if option R remove all previous indexes
if($opt_R == 1){ #remove indexes
    print STDERR "\nremoving $gsdlhome/bin/script/indexes/keyphrase_index.txt\n";
    print STDERR "removing $gsdlhome/bin/script/indexes/keyphrase_document.txt\n";
    print STDERR "removing $gsdlhome/bin/script/indexes/document_keyphrase.txt\n";
    system("rm $gsdlhome/bin/script/indexes/keyphrase_document.txt");   
    system("rm $gsdlhome/bin/script/indexes/document_keyphrase.txt"); 
    system("rm $gsdlhome/bin/script/indexes/keyphrase_index.txt");
}

#collections may be specified in the command line
#otherwise, all collections will be used to build
#the indexes.  
if(@ARGV){

    @directories = @ARGV;

} else { #open collect directory and get a list of all collections
    opendir(DIR, "$gsdlhome/collect");
    @directories = grep(!/(^\.|(CVS)|(modelcol))/, readdir(DIR));
    closedir(DIR);
}

#for each collection specified to build indexes for
foreach $collection (@directories){

    my @filelist;

    #archives.inf contains a list of unique hash ID's of each file and file paths
    open(INFO, "$gsdlhome/collect/$collection/archives/archives.inf")
	or die "$gsdlhome/collect/$collection/archives/archives.inf could not be opened.";

    while(<INFO>){ #get each line of text from archives.inf (OID \t filepath)
	chomp;
	push(@filelist, $_);
    }

    foreach $file (@filelist){ #add each document to the indexes
	build_index($file, $collection);
    }
}

#This function opens the file in the filepath sent as an argument.  From this it obtains 
#the kea and/or stem data, and then searches for these phrases in the file, counting and storing 
#how many times each phrase appears. The data is then sent to function keyphrase_document 
#with arguments hash ID, kea phrases and stem phrases to build the keyphrase_document index.
#The function which builds the document_keyphrase index is then passed the hash ID, the kea 
#phrases and/or the stemmed phrases and the array/s which hold the number of times each phrase
#appears in the document so that the data it has collected can be written to document_ keyphrase
#index.

sub build_index {

    my $args = shift(@_);
    my $collection = shift(@_);
    my ($ID, $filepath) = split(/\t/, $args);
    my $stemsS = "";
    my @stem_phrase_counts = 0;
    my $text = "";

    print STDERR "\nID: $ID\n";
    print STDERR "filepath: $filepath\n";

    #open file to extract keyphrase information
    open(FILE, "$gsdlhome/collect/$collection/archives/$filepath")
	or die "$gsdlhome/collect/$collection/archives/$filepath could not be opened.";

    #patterns to search for so that we can extract the kea information
    my $stem_search = "stems=\"([^\"]*)\"";

    while(<FILE>){ #get kea and stem data and store
	chomp;
	$stemsS = $1 if (/$stem_search/);
    }

    close(FILE);
    
    print STDERR "stems: $stemsS\n";

    my @stems = split(", ", $stemsS);

    if(@stems){ #if the data exists
	
	#open the filepath to the current document
	open(FILE, "$gsdlhome/collect/$collection/archives/$filepath")
	    or die "$gsdlhome/collect/$collection/archives/$filepath could not be opened.";
	
	while(<FILE>){ #get the text
	    chomp;
	    $text .= $_;
	}
 
	#chop out all things in angled brackets
	$text =~ s/(<[^>]*>)//g;

	#initilise counts
	for($i=0; $i<=$#stems; $i++){
	    $stem_phrase_counts[$i] = 0;
	}
	
	#using regular expressions generated from stem-reg
	#count how many of each phrase appear in the document
	
	$text_copy = $text;
	for($i=0; $i<=$#stems; $i++){ #search for text with stem phrases
	    my $stem = $stems[$i];
	    $reg = &stem_reg(split(/\s+/, $stem));
	    while($text_copy =~ s/$reg//i){
		$stem_phrase_counts[$i]++; #count the number of stem phrases
	    } 
	    $text_copy = $text;
	}

	
	#write data to keyphrase_document index
	&keyphrase_document($ID, $stemsS); 
	
	#write data to document_keyphrase index
	$stem_counts = join(", ", @stem_phrase_counts);
	&document_keyphrase($ID, $stemsS, $stem_counts);
	
    } else { 
	print STDERR "No stem data was found in file $filepath\n";
    }

}

#returns a regular expression designed to 
#search for stems in text
#eg 'agri cari'
#    agri followed by 0 or more non-whitespace characters
#         followed by one or more whitespace OR 0 or 1 non-whitespace characters
#    cari followed by 0 or more non-whitespace characters
#modified from original by Stephen Lundy 

sub stem_reg {
   
    $regexp = "";

    $l = @_;

    if ($l > 0) {
        $s = shift;
        $regexp = "$s\\S*";

        if ($l-1 > 0) {
            foreach $s (@_) {
                $regexp .= "(\\s+|\\S?)$s\\S*";
            }
        }
    }

    return $regexp;
}



#This function is passed as arguments a list of kea phrase stems. Its purpose is to 
#check in the keyphrase index file for each phrase and determine whether or not an entry has
#been made for that phrase and an index number assigned to it. If there has not been an entry
#made then an index number is assigned to the phrase and it is written to the file.  This 
#function is called by document_keyphrase and keyphrase_document.  Each line in the file has
#this form:
#-phrase index number:phrase
#This function then returns a table of pairs of the phrases that were sent as arguments to it
#{phrase => phrase index number}.
 
sub keyphrase_index_search {

    my $phrases = shift(@_);
    my @phrases = split(", ", $phrases);
    my %table;
    my $index = 1;
    my $create_new_index = 0;

    print STDERR "searching keyphrase index...\n";

    #initilise table of phrases and index numbers
    foreach $phrase (@phrases){
	$table{"$phrase"} = "0";
    }

    #open keyphrase index for appending data and for reading
    open(INDEX_OUT, ">>$gsdlhome/bin/script/indexes/keyphrase_index.txt");
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/keyphrase_index.txt")
	or $create_new_index = 1;

    if($create_new_index == 0){
	#if the index already exists read in the phrases
	while(<INDEX_IN>){
	    chomp;
	    foreach $phrase (@phrases){
		if(/(\d+):$phrase/){
		    $index = $1;
		    $table{"$phrase"} = "$index";
		}
	    }
	    $index++; #new starting index (one + the last index)
	}

	close(INDEX_IN);

    }

    #add new phrases to the phrase index
    foreach $phrase (keys %table){
	if($table{"$phrase"} eq "0"){
	    print INDEX_OUT "$index:$phrase\n";
	    $table{"$phrase"} = "$index"; 
	    $index++;
	}
    }

    close(INDEX_OUT);
    return %table;
}

#This function is passed as arguments file hash ID and a list of kea phrases and/or stems
#that exist for that particular file.  Its purpose is to write to the keyphrase_document
#index a line for the document it has been sent:
#-phrase index number:number of documents it appears in|ID
sub keyphrase_document{

    my ($ID, $stems) = @_;
    my $text = ""; 
    my @textlist;
    my $create_new_index = 0;

    print STDERR "writing to keyphrase_document.txt...\n";

    #get table of phrases and phrase indexes 
    my %table = keyphrase_index_search($stems); 
    
  
    #open index for reading
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/keyphrase_document.txt")
	or $create_new_index = 1;

    #read in document if file exists
    if($create_new_index == 0){

	while(<INDEX_IN>){
	    $text .= $_;
	}

	close(INDEX_IN);

	#split text into lines
	@textlist = split(/\n/, $text);

    } 

    #open index for output
    open(INDEX_OUT, ">$gsdlhome/bin/script/indexes/keyphrase_document.txt");

    if($create_new_index == 0){ #amend existing index
	
	foreach $line (@textlist){
	    foreach $phrase (keys %table){
		if($line =~ /(\d+):(\d+)(.*)/){ #all lines of this form
		    $index = $1;
		    if($table{"$phrase"} eq "$index") { #if phrase exists in index
			$ids = $3; #get all doc IDs for that keyphrase
			if($ids !~ /$ID/){ #if doc ID not already included
			    $num_docs = $2;
			    $num_docs++; #increment number of docs
			    $line = "$index:$num_docs$3|$ID"; #line to append to index
			    $table{"$phrase"} = "0"; 
			}
		    }
		}
	    }
	    print INDEX_OUT "$line\n";
	}
    }

    #add new phrases to the index
    foreach $phrase (keys %table){ #write 'phrase index:1:file ID
	if($table{"$phrase"} ne "0"){
	    my $line = "$table{$phrase}:1:$ID";
	    print INDEX_OUT "$line\n"; 
	}
    }

    close(INDEX_OUT);

}

#This function is passed as arguments file hash ID and a list of kea phrase stems
#that exist for that particular file and a list of the number of times each stem
#phrase appear in that document.  Its purpose is to write to the document_keyphrase
#index a line for the document it has been sent:
#-file ID:number of phrases and/or stems appear in the document
#      |pairs of 'phrase index,number of times the phrase appears in the document' 
sub document_keyphrase {

    my ($ID, $stemsS, $stem_c) = @_;
    my $text = "";
    my @textlist;
    my %phrases;
    my $create_new_index = 0;

    print STDERR "writing to document_keyphrase.txt...\n";

    #split phrase counts into arrays
    my @stem_counts = split(", ", $stem_c);
  
    #get table of phrases and phrase indexes
    my %table = keyphrase_index_search($stemsS);

    #split phrases into arrays
    my @stems = split(", ", $stemsS);

    #build new phrases dictionary
    for($i=0; $i<=$#stems; $i++){
	my $phrase = $table{"$stems[$i]"};
	$phrases{"$phrase"} = "$stem_counts[$i]";
    }   
    my @num = keys %phrases;
    my $phrasenum = $#num + 1; #number of phrases in doc

    #open index for reading
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/document_keyphrase.txt")
	or $create_new_index = 1;

     
    if($create_new_index == 0){ #index doesn't need to be created

	while(<INDEX_IN>){
	    $text .= $_;
	}

	close(INDEX_IN);
	
	#split text into lines
	@textlist = split(/\n/, $text);

    }  


    #must write this line to the file
    #'document ID:num of phrases|phrase index, number of times phrases appears
    my $newline = "$ID:$phrasenum";
    foreach $phrase (keys %phrases){
	$newline .= "|$phrase,$phrases{$phrase}";
    }

    #open index for output
    open(INDEX_OUT, ">$gsdlhome/bin/script/indexes/document_keyphrase.txt");

    if($create_new_index == 1){ #create a new index

	print INDEX_OUT "$newline\n";

    } else {

	#if ID is already in the file write line overtop incase
	#someone has modified the file.  Otherwise add the line
	#to the end of the file
	my $found = 0;

	foreach $line (@textlist){
	    if($line =~ /([^:]+):(.*)/){ #all lines should follow this pattern
		$id = $1;
		if($ID eq $id){ #id is already in the file
		    print INDEX_OUT "$newline\n"; #print line overtop
		    $found = 1;
		} else {
		    print INDEX_OUT "$line\n"; #print old line out
		}
	    }
	}

	print INDEX_OUT "$newline\n" if ($found == 0); #append new line to end of file 

    }

    close(INDEX_OUT);

}










