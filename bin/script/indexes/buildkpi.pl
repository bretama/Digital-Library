#! /user/bin/perl 

#usage: perl buildkpi.pl [-R] [collection] [collection] etc
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
#-From each file collect kea phrases and/or stems
#-Determine the number of kea phrases and stems for each document 
#-Search for the kea phrases in the numbered phrase index. If a phrase is not there then 
# the program will write the kea phrase to the phrase index . 
#-Search for the kea phrases in the keyphrase to document index. If the phrase is there, 
# it will increment the number of documents that the keyphrase appears in and replace that
# then append the hash ID to the list of documents in the entry. If the phrase is not there 
# then the program will write the kea phrase to the phrase index.
#-Then write document ID, no of phrase, phrase number from index followed by number of times 
# phrase appears into the document_keyphrase index

$gsdlhome = $ENV{'GSDLHOME'};

require "getopts.pl";
&Getopts('R'); #process option arguments


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


#directory to store indexes in using collection names
$dirname = "";
foreach $collection (sort @directories){
    $dirname .= $collection."_";
}
$dirname .= "indexes";
print STDERR "directory name: $dirname\n";

#if option R remove all previous indexes
if($opt_R == 1){ #remove indexes
    print STDERR "\nremoving $gsdlhome/bin/script/indexes/$dirname/keyphrase_index.txt\n";
    print STDERR "removing $gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt\n";
    print STDERR "removing $gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt\n";
    system("rm $gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt");   
    system("rm $gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt"); 
    system("rm $gsdlhome/bin/script/indexes/$dirname/keyphrase_index.txt");
} 

#create the new directory, display an error message if the directory
#already exists.
`mkdir --verbose $gsdlhome/bin/script/indexes/$dirname`;

#for each collection specified to build indexes for
foreach $collection (@directories){

    print STDERR "\nBUILDING INDEXES FOR COLLECTION $collection\n\n";

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
    my $keaS = "";
    my $stemsS = "";
    my @kea_phrase_counts = 0;
    my @stem_phrase_counts = 0;
    my $text = "";

    print STDERR "\nID: $ID\n";
    print STDERR "filepath: $filepath\n";

    #open file to extract keyphrase information
    open(FILE, "$gsdlhome/collect/$collection/archives/$filepath")
	or die "$gsdlhome/collect/$collection/archives/$filepath could not be opened.";

    #patterns to search for so that we can extract the kea information
    my $kea_search = ".* kea=\"([^\"]*)\"";
    my $stem_search = "stems=\"([^\"]*)\"";

    while(<FILE>){ #get kea and stem data and store
	chomp;
	$keaS = $1 if (/$kea_search/);
	$stemsS = $1 if (/$stem_search/);
    }

    close(FILE);
    
    print STDERR "Kea: $keaS\n";
    print STDERR "stems: $stemsS\n";

    my @kea = split(", ", $keaS);
    my @stems = split(", ", $stemsS);

    if(@kea && @stems){ #if the data exists
	
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
	for($i=0; $i<=$#kea; $i++){
	    $kea_phrase_counts[$i] = 0;
	}
	
	for($i=0; $i<=$#stems; $i++){
	    $stem_phrase_counts[$i] = 0;
	}

	print STDERR "counting number of kea phrases in document...\n";

	#using regular expressions generated from kea-reg and stem-reg
	#count how many of each phrase appear in the document
	$text_copy = $text;
	for($i=0; $i<=$#kea; $i++){ #search for text with kea phrases
	    my $phrase = $kea[$i];
	    $reg = &kea_reg(split(/\s+/, $phrase));
	    while($text_copy =~ s/$reg//i){
		$kea_phrase_counts[$i]++; #count the number of kea phrases 
	    } 
	    $text_copy = $text;
	}  

	print STDERR "counting number of stemmed phrases in document...\n";

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
	&keyphrase_document($ID, $keaS, $stemsS); 
	
	#write data to document_keyphrase index
	$kea_counts = join(", ", @kea_phrase_counts);
	$stem_counts = join(", ", @stem_phrase_counts);
	&document_keyphrase($ID, $keaS, $stemsS, $kea_counts, $stem_counts);
	
    } else { 
	print STDERR "No kea data was found in file $filepath\n";
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

#returns a regular expression designed to 
#search for phrases in text
#eg 'agris caris'
#    agris followed by 0 or 1 non-whitespace characters OR
#          followed by one or more whitespace 
#    caris followed by 0 or 1 non-whitespace characters
#modified from original by Stephen Lundy 

sub kea_reg {
    $regexp = "";

    $l = @_;

    if ($l > 0) {
        $s = shift;
        #$regexp = "$s(\\S?)";
	$regexp = "$s(\\s+|\\S?)";

        if ($l-1 > 0) {
            foreach $s (@_) {
                $regexp .= "$s(\\s+|\\S?)";
            }
        }
    }

    return $regexp;
}


#This function is passed as arguments a list of kea phrases and/or stems. Its purpose is to 
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
    open(INDEX_OUT, ">>$gsdlhome/bin/script/indexes/$dirname/keyphrase_index.txt");
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/$dirname/keyphrase_index.txt")
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

    my ($ID, $kea, $stems) = @_;
    my $text = ""; 
    my @textlist;
    my $create_new_index = 0;

    print STDERR "writing to keyphrase_document.txt...\n";

    #get table of phrases and phrase indexes 
    my %table = keyphrase_index_search($kea.", ".$stems); 
    
  
    #open index for reading
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt")
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
    open(INDEX_OUT, ">$gsdlhome/bin/script/indexes/$dirname/keyphrase_document.txt");

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

#This function is passed as arguments file hash ID and a list of kea phrases and/or stems
#that exist for that particular file and a list of the number of times each kea and/or stem
#phrase appear in that document.  Its purpose is to write to the document_keyphrase
#index a line for the document it has been sent:
#-file ID:number of phrases and/or stems appear in the document
#      |pairs of 'phrase index,number of times the phrase appears in the document' 
sub document_keyphrase {

    my ($ID, $keaS, $stemsS, $kea_c, $stem_c) = @_;
    my $text = "";
    my @textlist;
    my %phrases;
    my $create_new_index = 0;

    print STDERR "writing to document_keyphrase.txt...\n";

    #split phrase counts into arrays
    my @kea_counts = split(", ", $kea_c);
    my @stem_counts = split(", ", $stem_c);
  
    #get table of phrases and phrase indexes
    my %table = keyphrase_index_search($keaS.", ".$stemsS);

    #split phrases into arrays
    my @kea = split(", ", $keaS);
    my @stems = split(", ", $stemsS);

    #build new phrases dictionary
    for($i=0; $i<=$#kea; $i++){
	my $phrase = $table{"$kea[$i]"};
	if($kea_counts[$i] > 0){
	    $phrases{"$phrase"} = "$kea_counts[$i]";
	} else {
	    $phrases{"$phrase"} = 1;
	}
    } 
    for($i=0; $i<=$#stems; $i++){
	my $phrase = $table{"$stems[$i]"};
	if($stem_counts[$i] > 0){
	    $phrases{"$phrase"} = "$stem_counts[$i]";
	} else {
	    $phrases{"$phrase"} = 1;
	}
    }   
    my @num = keys %phrases;
    my $phrasenum = $#num + 1; #number of phrases in doc

    #open index for reading
    open(INDEX_IN, "$gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt")
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
    #document ID:num of phrases|phrase index, number of times phrases appears
    my $newline = "$ID:$phrasenum";
    foreach $phrase (keys %phrases){
	$newline .= "|$phrase,$phrases{$phrase}";
    }

    #open index for output
    open(INDEX_OUT, ">$gsdlhome/bin/script/indexes/$dirname/document_keyphrase.txt");

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

