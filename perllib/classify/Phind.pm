###########################################################################
#
# Phind.pm -- the Phind classifier
#
# Copyright (C) 2000 Gordon W. Paynter
# Copyright (C) 2000 New Zealand Digital Library Project
#
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
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

# The Phind clasifier plugin. 
# Type "classinfo.pl Phind" at the command line for a summary.

package Phind;

use BaseClassifier;
use FileUtils;
use util;
use ghtml;
use unicode;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

my @removedirs = ();

my %wanted_index_files = ('td'=>1,
			  't'=>1,
			  'ti'=>1,
			  'tl'=>1,
			  'tsd'=>1,
			  'idb'=>1,
			  'ib1'=>1,
			  'ib2'=>1,
			  'ib3'=>1,
			  'i'=>1,
			  'il'=>1,
			  'w'=>1,
			  'wa'=>1);

sub BEGIN {
    @Phind::ISA = ('BaseClassifier');
}

sub END {
    
    # Tidy up stray files - we do this here as there's some weird problem
    # preventing us from doing it in the get_classify_info() function (on
    # windows at least) where the close() appears to fail on txthandle and
    # dochandle, thus preventing us from deleting those files

    foreach my $dir (@removedirs) {
	if (-d $dir && opendir (DIR, $dir)) {
	    my @files = readdir DIR;
	    closedir DIR;
	
	    foreach my $file (@files) {
		next if $file =~ /^\.\.?$/;
		my ($suffix) = $file =~ /\.([^\.]+)$/;
		if (!defined $suffix || !defined $wanted_index_files{$suffix}) {
		    # delete it!
		    &FileUtils::removeFiles (&FileUtils::filenameConcatenate ($dir, $file));
		}
	    }
	}
    }
}

my $arguments =
    [ { 'name' => "text",
	'desc' => "{Phind.text}",
	'type' => "string",
	'deft' => "section:Title,section:text",
	'reqd' => "no" },
      { 'name' => "title",
	'desc' => "{Phind.title}",
	'type' => "metadata",
	'deft' => "Title",
	'reqd' => "no" },
      { 'name' => "buttonname",
	'desc' => "{BasClas.buttonname}",
	'type' => "string",
	'deft' => "Phrase",
	'reqd' => "no" },
      { 'name' => "language",
	'desc' => "{Phind.language}",
	'type' => "string",
	'deft' => "en",
	'reqd' => "no" },
      { 'name' => "savephrases",
	'desc' => "{Phind.savephrases}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "suffixmode",
	'desc' => "{Phind.suffixmode}",
	'type' => "int",
	'deft' => "1",
	'range' => "0,1",
	'reqd' => "no" },
      { 'name' => "min_occurs",
	'desc' => "{Phind.min_occurs}",
	'type' => "int",
	'deft' => "2",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "thesaurus",
	'desc' => "{Phind.thesaurus}",
	'type' => "string",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "untidy",
	'desc' => "{Phind.untidy}",
	'type' => "flag",
	'reqd' => "no" } ];

my $options = { 'name'     => "Phind",
		'desc'     => "{Phind.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };


# Phrase delimiter symbols - these should be abstracted out someplace

my $colstart = "COLLECTIONSTART";
my $colend   = "COLLECTIONEND";
my $doclimit = "DOCUMENTLIMIT";
my $senlimit = "SENTENCELIMIT";
my @delimiters = ($colstart, $colend, $doclimit, $senlimit);


# Create a new Phind browser based on collect.cfg

sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseClassifier($classifierslist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }

    # Ensure the Phind generate scripts are in place

    # the suffix binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
    &util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

    my $file1 = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}, "suffix");
    $file1 .= ".exe" if $ENV{'GSDLOS'} =~ /^windows$/;
    my $src = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "src", "phind", "generate");
    if (!(-e $file1)) {
	print STDERR "Phind.pm: ERROR: The Phind \"suffix\" program is not installed.\n\n";
	exit(1);
    }
    
    # things that may have ex. in them that need to be stripped off
    $self->{'text'} = $self->strip_ex_from_metadata($self->{'text'});
    $self->{'title'} = $self->strip_ex_from_metadata($self->{'title'});

    # Transfer value from Auto Parsing to the variable name that used in previous GreenStone.
    
    $self->{"indexes"} = $self->{"text"};

    # Further setup
    $self->{'collection'} = $ENV{'GSDLCOLLECTION'}; # classifier information
    $self->{'collectiondir'} = $ENV{'GSDLCOLLECTDIR'}; # collection directories
    if (! defined $self->{'builddir'}) {
	$self->{'builddir'} = &FileUtils::filenameConcatenate($ENV{'GSDLCOLLECTDIR'}, "building");
    } 
    $self->{'total'} = 0;
    
    # we set phind to be rtl if language is arabic
    if ($self->{'language'} eq "ar") {
	$self->{'textorientation'} = "rtl";
    }
    # Clean out the unused keys
    delete $self->{"text"};

    return bless $self, $class;
}


# Initialise the Phind classifier

sub init {
    my $self = shift (@_);

    # ensure we have a build directory
    my $builddir = $self->{'builddir'};
    die unless (-e "$builddir");

    # create Phind directory
    my $phnumber = 1;
    my $phinddir = &FileUtils::filenameConcatenate($builddir, "phind1");
    while (-e "$phinddir") {
	$phnumber++;
	$phinddir = &FileUtils::filenameConcatenate($builddir, "phind$phnumber");
    }
    &FileUtils::makeDirectory("$phinddir");
    $self->{'phinddir'} = $phinddir;
    $self->{'phindnumber'} = $phnumber;

    push(@removedirs, $phinddir) unless $self->{'untidy'};

    # open filehandles for documents and text
    my $clausefile =  &FileUtils::filenameConcatenate("$phinddir", "clauses");
    &FileUtils::removeFiles($clausefile) if (-e $clausefile);

    my $txthandle = 'TEXT' . $phnumber;
    open($txthandle, ">$clausefile") || die "Cannot open $clausefile: $!";
    $self->{'txthandle'} = $txthandle;

    my $docfile = &FileUtils::filenameConcatenate("$phinddir", "docs.txt");
    &FileUtils::removeFiles($docfile) if (-e $docfile);

    my $dochandle = 'DOC' . $phnumber;
    open($dochandle, ">$docfile") || die "Cannot open $docfile: $!";
    $self->{'dochandle'} = $dochandle;
    
}


# Classify each document.
#
# Each document is passed here in turn.  The classifier extracts the 
# text of each and stores it in the clauses file.  Document details are
# stored in the docs.txt file. 

sub classify {
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $verbosity = $self->{'verbosity'};
    my $top_section = $doc_obj->get_top_section();

    my $titlefield = $self->{'title'};
    
    my $title = $doc_obj->get_metadata_element ($top_section, $titlefield);
    if (!defined($title)) {
	$title = "";
	print STDERR "Phind: document has no title\n";
    }
    print "process: $title\n" if ($verbosity > 2);

    # Only consider the file if it is in the correct language
    my $doclanguage = $doc_obj->get_metadata_element ($top_section, "Language");
    my $phrlanguage = $self->{'language'};
    return if ($doclanguage && ($doclanguage !~ /$phrlanguage/i));

    # record this file
    $self->{'total'} ++;
    # what is $file ???
    # print "file $self->{'total'}: $file\n" if ($self->{'$verbosity'});

    # Store document details
    my $OID = $doc_obj->get_OID();
    $OID = "NULL" unless defined $OID;
    my $dochandle = $self->{'dochandle'};
    print $dochandle "<Document>\t$OID\t$title\n";
    
    # Store the text occuring in this object

    # output the document delimiter
    my $txthandle = $self->{'txthandle'};
    print $txthandle "$doclimit\n";

    # iterate over the required indexes and store their text
    my $indexes = $self->{'indexes'};
    my $text = "";
    my ($part, $level, $field, $section, $data, $dataref);

    foreach $part (split(/,/, $indexes)) {

	# Each field has a level and a data element ((e.g. document:Title)
	($level, $field) = split(/:/, $part);
	die unless ($level && $field);
	
	# Extract the text from every section
	# (In phind, document:text and section:text are equivalent)
	if ($field eq "text") {
	    $data = "";
	    $section = $doc_obj->get_top_section();
	    while (defined($section)) {
		$data .= $doc_obj->get_text($section) . "\n";
		$section = $doc_obj->get_next_section($section);
	    }
	    $text .= convert_gml_to_tokens($phrlanguage, $data) . "\n";
	}
	
	# Extract a metadata field from a document
	# (If there is more than one element of the given type, get them all.)
	elsif ($level eq "document") {
	    $dataref = $doc_obj->get_metadata($doc_obj->get_top_section(), $field);
	    foreach $data (@$dataref) {
		$text .= convert_gml_to_tokens($phrlanguage, $data) . "\n";
	    } 
	}

	# Extract metadata from every section in a document
	elsif ($level eq "section") {
	    $data = "";
	    $section = $doc_obj->get_top_section();
	    while (defined($section)) {
		$dataref = $doc_obj->get_metadata($section, $field);
		$data .= join("\n", @$dataref) . "\n";
		$section = $doc_obj->get_next_section($section);
	    }
	    $text .= convert_gml_to_tokens($phrlanguage, $data) . "\n";
	} 
	
	# Some sort of specification which I don't understand
	else {
	    die "Unknown level ($level) in Phind index ($part)\n";
	}
	
    }

    # output the text
    $text =~ tr/\n//s;
    print $txthandle "$text";
}


# Construct the classifier from the information already gathered
#
# When get_classify_info is called, the clauses and docs.txt files have
# already been constructed in the Phind directory.  This function will
# translate them into compressed, indexed MGPP files that can be read by
# the phindcgi script.  It will also register our classifier so that it
# shows up in the navigation bar.

sub get_classify_info {
    my $self = shift (@_);
    my ($gli) = @_;    

    close $self->{'dochandle'};
    close $self->{'txthandle'};
    my $verbosity = $self->{'verbosity'};
    my $out = $self->{'outhandle'};
    my $phinddir = $self->{'phinddir'};

    my $osextra = "";
    if ($ENV{'GSDLOS'} !~ /^windows$/i) {
	$osextra = " -d /";
    }

    print STDERR "</Stage>\n" if $gli;

    if ($verbosity) {
	print $out "\n*** Phind.pm generating indexes for ", $self->{'indexes'}, "\n";
	print $out "***          in ", $self->{'phinddir'}, "\n";
    }

    print STDERR "<Stage name='Phind'>\n" if $gli;

    # Construct phind indexes
    my $suffixmode = $self->{'suffixmode'};
    my $min_occurs = $self->{'min_occurs'};
    my ($command, $status);
    
    # Generate the vocabulary, symbol statistics, and numbers file
    # from the clauses file
    print $out "\nExtracting vocabulary and statistics\n" if $verbosity;
    print STDERR "<Phase name='ExtractingVocab'/>\n" if $gli;
    &extract_vocabulary($self);
 
    # Use the suffix program to generate the phind/phrases file
    print $out "\nExtracting phrases from processed text (with suffix)\n" if $verbosity;
    print STDERR "<Phase name='ExtractingPhrase'/>\n" if $gli;
    &execute("suffix \"$phinddir\" $suffixmode $min_occurs $verbosity", $verbosity, $out);

    # check that we generated some files. It's not necessarily an error if
    # we didn't (execute() would have quit on error), but we can't go on.
    my $phrasesfile=&FileUtils::filenameConcatenate($self->{'phinddir'}, 'phrases');
    if (! -r $phrasesfile) {
	print STDERR "<Warning name='NoPhrasesFound'/>\n" if $gli;
	print $out "\nNo phrases found for Phind classifier!\n";
	return;
    }   

    # Create the phrase file and put phrase numbers in phind/phrases
    print $out "\nSorting and renumbering phrases for input to mgpp\n" if $verbosity;
    print STDERR "<Phase name='SortAndRenumber'/>\n" if $gli;
    &renumber_phrases($self);

    print $out "\nCreating phrase databases\n";
    print STDERR "<Phase name='PhraseDatabases'/>\n" if $gli;
    my $mg_input = &FileUtils::filenameConcatenate($phinddir, "pdata.txt");
    my $mg_stem = &FileUtils::filenameConcatenate($phinddir, "pdata");

    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T1 \"$mg_input\"", $verbosity, $out);
    &execute("mgpp_compression_dict $osextra -f \"$mg_stem\"", $verbosity, $out);
    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T2 \"$mg_input\"", $verbosity, $out);

    # create the mg index of words
    print $out "\nCreating word-level search indexes\n";
    print STDERR "<Phase name='WordLevelIndexes'/>\n" if $gli;
    $mg_input = &FileUtils::filenameConcatenate($phinddir, "pword.txt");
    $mg_stem = &FileUtils::filenameConcatenate($phinddir, "pword");

    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T1 -I1 \"$mg_input\"", $verbosity, $out);
    &execute("mgpp_compression_dict $osextra -f \"$mg_stem\"", $verbosity, $out);
    &execute("mgpp_perf_hash_build $osextra -f \"$mg_stem\"", $verbosity, $out);
    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T2 -I2 \"$mg_input\"", $verbosity, $out);
    &execute("mgpp_weights_build $osextra -f \"$mg_stem\"", $verbosity, $out);
    &execute("mgpp_invf_dict $osextra -f \"$mg_stem\"", $verbosity, $out);

    &execute("mgpp_stem_idx $osextra -f \"$mg_stem\" -s 1", $verbosity, $out);
    &execute("mgpp_stem_idx $osextra -f \"$mg_stem\" -s 2", $verbosity, $out);
    &execute("mgpp_stem_idx $osextra -f \"$mg_stem\" -s 3", $verbosity, $out);

    # create the mg document information database
    print $out "\nCreating document information databases\n";
    print STDERR "<Phase name='DocInfoDatabases'/>\n" if $gli;
    $mg_input = &FileUtils::filenameConcatenate($phinddir, "docs.txt");
    $mg_stem = &FileUtils::filenameConcatenate($phinddir, "docs");

    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T1 \"$mg_input\"", $verbosity, $out);
    &execute("mgpp_compression_dict $osextra -f \"$mg_stem\"", $verbosity, $out);
    &execute("mgpp_passes $osextra -f \"$mg_stem\" -T2 \"$mg_input\"", $verbosity, $out);

    my $parameters = "phindnumber=$self->{'phindnumber'}";
    if (defined ($self->{'textorientation'})) {
	$parameters .= ";textorientation=$self->{'textorientation'}";
    }
    # Return the information about the classifier that we'll later want to
    # use to create macros when the Phind classifier document is displayed.
    my %classifyinfo = ('thistype'=>'Invisible',
                        'childtype'=>'Phind', 
                        'Title'=>$self->{'buttonname'},
                        'parameters'=>$parameters,
			'contains'=>[]);
    
    my $collection = $self->{'collection'};
    my $url = "library?a=p&p=phind&c=$collection";
    push (@{$classifyinfo{'contains'}}, {'OID'=>$url});
   
    return \%classifyinfo;
}



sub convert_gml_to_tokens {
    
    my ($language_exp, $text) = @_;

    # escape any magic words... - jrm21
    foreach my $delim (@delimiters) {
	my $replacement=lc($delim);
	my $num= $text=~ s/$delim/$replacement/g;
	if (!$num) {$num=0;}
    }

    if ($language_exp =~ /^en$/) {
	return &convert_gml_to_tokens_EN($text);
    }

    if ($language_exp =~ /zh/) {
	return &convert_gml_to_tokens_ZH($text);
    }  
    
    $_ = $text;

    # 1. remove GML tags

    # Remove everything that is in a tag
    s/\s*<p>\s*/ PARAGRAPHBREAK /isgo;
    s/\s*<br>\s*/ LINEBREAK /isgo;
    s/<[^>]*>/ /sgo;

    # Now we have the text, but it may contain HTML 
    # elements coded as &gt; etc.  Remove these tags. 
    s/&amp;/&/sgo;
    s/&lt;/</sgo;
    s/&gt;/>/sgo;
    s/\s*<p>\s*/ PARAGRAPHBREAK /isgo;
    s/\s*<br>\s*/ LINEBREAK /isgo;
    s/<[^>]*>/ /sgo;

    # replace<p> and <br> placeholders with clause break symbol (\n)
    s/\s+/ /gso;
    s/PARAGRAPHBREAK/\n/sgo;
    s/LINEBREAK/\n/sgo;

    
    # 2. Split the remaining text into space-delimited tokens

    # Convert any HTML special characters (like &quot;) to their UTF8 equivalent
    s/&([^;]+);/&unicode::ascii2utf8(\&ghtml::getcharequiv($1,1))/gse;

    # Split text at word boundaries
    s/\b/ /go;
    
    # 3. Convert the remaining text to "clause format"

    # Insert newline if the end of a sentence is detected
    # (delimter is:  "[\.\?\!]\s")
    # s/\s*[\.\?\!]\s+/\n/go; 

    # remove unnecessary punctuation and replace with clause break symbol (\n)
    # the following very nicely removes all non alphanumeric characters. too bad if you are not using english...
    #s/[^\w ]/\n/go;
    # replace punct with new lines - is this what we want??
    s/\s*[\?\;\:\!\,\.\"\[\]\{\}\(\)]\s*/\n/go; #"
    # then remove other punct with space
    s/[\'\`\\\_]/ /go;

    # remove extraneous whitespace
    s/ +/ /sgo;
    s/^\s+//mgo;
    s/\s*$/\n/mgo;

    # remove lines that contain one word or less
    s/^\S*$//mgo;
    s/^\s*$//mgo;
    tr/\n//s;

    return $_;
}

# a chinese version
sub convert_gml_to_tokens_ZH {

    $_ = shift @_;

    # Replace all whitespace with a simple space
    s/\s+/ /gs;
    # Remove everything that is in a tag
    s/\s*<p>\s*/ PARAGRAPHBREAK /isg;
    s/\s*<br>\s*/ LINEBREAK /isg;
    s/<[^>]*>/ /sg;

    # Now we have the text, but it may contain HTML 
    # elements coded as &gt; etc.  Remove these tags. 
    s/&lt;/</sg;
    s/&gt;/>/sg;

    s/\s+/ /sg;
    s/\s*<p>\s*/ PARAGRAPHBREAK /isg;
    s/\s*<br>\s*/ LINEBREAK /isg;
    s/<[^>]*>/ /sg;

    # remove &amp; and other miscellaneous markup tags
    s/&amp;/&/sg;
    s/&lt;/</sg;
    s/&gt;/>/sg;
    s/&amp;/&/sg;

    # replace<p> and <br> placeholders with carriage returns
    s/PARAGRAPHBREAK/\n/sg;
    s/LINEBREAK/\n/sg;

    
#    print STDERR "text:$_\n";
    return $_;
}

# A version of convert_gml_to_tokens that is fine-tuned to the English language.

sub convert_gml_to_tokens_EN {
    $_ = shift @_;

    # FIRST, remove GML tags

    # Replace all whitespace with a simple space
    s/\s+/ /gs;

    # Remove everything that is in a tag
    s/\s*<p>\s*/ PARAGRAPHBREAK /isg;
    s/\s*<br>\s*/ LINEBREAK /isg;
    s/<[^>]*>/ /sg;

    # Now we have the text, but it may contain HTML 
    # elements coded as &gt; etc.  Remove these tags. 
    s/&lt;/</sg;
    s/&gt;/>/sg;

    s/\s+/ /sg;
    s/\s*<p>\s*/ PARAGRAPHBREAK /isg;
    s/\s*<br>\s*/ LINEBREAK /isg;
    s/<[^>]*>/ /sg;

    # remove &amp; and other miscellaneous markup tags
    s/&amp;/&/sg;
    s/&lt;/</sg;
    s/&gt;/>/sg;
    s/&amp;/&/sg;

    # replace<p> and <br> placeholders with carriage returns
    s/PARAGRAPHBREAK/\n/sg;
    s/LINEBREAK/\n/sg;


    # Exceptional punctuation
    # 
    # We make special cases of some punctuation

    # remove any apostrophe that indicates omitted letters 
    s/(\w+)\'(\w*\s)/ $1$2 /g;

    # remove period that appears in a person's initals
    s/\s([A-Z])\./ $1 /g;

    # replace hyphens in hypheanted words and names with a space
    s/([A-Za-z])-\s*([A-Za-z])/$1 $2/g;

    # Convert the remaining text to "clause format",
    # This means removing all excess punctuation and garbage text,
    # normalising valid punctuation to fullstops and commas,
    # then putting one cluse on each line.

    # Insert newline when the end of a sentence is detected
    # (delimter is:  "[\.\?\!]\s")
    s/\s*[\.\?\!]\s+/\n/g; 

    # split numbers after four digits
    s/(\d\d\d\d)/$1 /g;

    # split words after 32 characters

    # squash repeated punctuation 
    tr/A-Za-z0-9 //cs;

    # save email addresses
    # s/\w+@\w+\.[\w\.]+/EMAIL/g;

    # normalise clause breaks (mostly punctuation symbols) to commas
    s/[^A-Za-z0-9 \n]+/ , /g;

    # Remove repeated commas, and replace with newline
    s/\s*,[, ]+/\n/g;

    # remove extra whitespace
    s/ +/ /sg;
    s/^\s+//mg;
    s/\s*$/\n/mg;

    # remove lines that contain one word or less
    s/^\w*$//mg;
    s/^\s*$//mg;
    tr/\n//s;

    return $_;

}



# Execute a system command

sub execute {
    my ($command, $verbosity, $outhandle) = @_;
    print $outhandle "Executing: $command\n"  if ($verbosity > 2);
    $! = 0;
    my $status = system($command);
    if ($status != 0) {
	print STDERR "Phind - Error executing '$command': $!\n";
	exit($status);  # this causes the build to fail... 
    }
}


# Generate the vocabulary, symbol statistics, and numbers file from the
# clauses file.  This is legacy code, so is a bit messy and probably wont
# run under windows.

sub extract_vocabulary {
    my ($self) = @_;
    
    my $verbosity = $self->{'verbosity'};
    my $out = $self->{'outhandle'};

    my $collectiondir = $self->{'collectiondir'};
    my $phinddir = $self->{'phinddir'};

    my $language_exp = $self->{'language'};

    my ($w, $l, $line, $word);
    
    my ($first_delimiter, $last_delimiter,
	$first_stopword, $last_stopword,
	$first_extractword, $last_extractword,
	$first_contentword, $last_contentword,
	$phrasedelimiter);
    
    my $thesaurus = $self->{'thesaurus'};
    my ($thesaurus_links, $thesaurus_terms, 
	%thesaurus, $first_thesaurusword, $last_thesaurusword);

    my %symbol;
    my (%freq);

    print $out "Calculating vocabulary\n" if ($verbosity > 1);

    # Read and store the stopwords
    my $stopdir = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "etc", "packages", "phind", "stopword");
    my $stopword_files = ();
    my ($language, $language_dir, $file, $file_name);
    my %stopwords;

    # Examine each directory in the stopword directory
    opendir(STOPDIR, $stopdir);
    foreach $language (readdir STOPDIR) {

	# Ignore entries that do not match the classifier's language
	next unless ($language =~ /$language_exp/);
	$language_dir = &FileUtils::filenameConcatenate($stopdir, $language);
	next unless (-d "$language_dir");

	opendir(LANGDIR, $language_dir);
	foreach $file (readdir LANGDIR) {

	    # Ignore entries that are not stopword files
	    next unless ($file =~ /sw$/);
	    $file_name = &FileUtils::filenameConcatenate($language_dir, $file);
	    next unless (-f "$file_name");

	    # Read the stopwords
	    open(STOPFILE, "<$file_name");
	    while (<STOPFILE>) {
		s/^\s+//;
		s/\s.*//;
		$word = $_;
		$l = lc($word);
		$stopwords{$l} = $word;
	    }
	    close STOPFILE;

	}
	closedir LANGDIR;
    }
    closedir STOPDIR;

    # Read thesaurus information
    if ($thesaurus) {

	# link file exists
	$thesaurus_links = &FileUtils::filenameConcatenate($collectiondir, "etc", "$thesaurus.lnk");
	die "Cannot find thesaurus link file" unless (-e "$thesaurus_links");

	# ensure term file exists in the correct language
	if ($language_exp =~ /^([a-z][a-z])/) {
	    $language = $1;
	} else {
	    $language = 'en';
	}
	$thesaurus_terms = &FileUtils::filenameConcatenate($collectiondir, "etc", "$thesaurus.$language");
	die "Cannot find thesaurus term file" unless (-e "$thesaurus_terms");
	

	# Read the thesaurus terms
	open(TH, "<$thesaurus_terms");
	while(<TH>) {
	    s/^\d+ //;
	    s/\(.*\)//;
	    foreach $w (split(/\s+/, $_)) {
		$thesaurus{lc($w)} = $w;
	    }
	}
	close TH;
    }

    # Read words in the text and count occurences
    open(TXT, "<$phinddir/clauses");

    my @words;
    while(<TXT>) {
	$line = $_;
	next unless ($line =~ /./);
	
	@words = split(/\s+/, $line);
	foreach $w (@words) {
	    $l = lc($w);
	    $w = $l if ((defined $stopwords{$l}) || (defined $thesaurus{$l}));
	    $freq{$w}++;
	}
	$freq{$senlimit}++;
    }
    
    close TXT;

    # Calculate the "best" form of each word
    my (%bestform, %totalfreq, %bestfreq);

    foreach $w (sort (keys %freq)) {
	$l = lc($w);
	
	# totalfreq is the number of times a term appears in any form
	$totalfreq{$l} += $freq{$w};
	
	if (defined $stopwords{$l}) {
	    $bestform{$l} = $stopwords{$l};
	    
	} elsif (defined $thesaurus{$l}) {
	    $bestform{$l} = $thesaurus{$l};
	    
	} elsif (!$bestform{$l} || ($freq{$w} > $bestfreq{$l})) {
	    $bestfreq{$l} = $freq{$w};
	    $bestform{$l} = $w;
	}
    }
    undef %freq;
    undef %bestfreq;
    

    # Assign symbol numbers to tokens
    my $nextsymbol = 1;
    my (@vocab);
    
    # Delimiters
    $first_delimiter = 1;
    
    foreach $word (@delimiters) {

#	$word = lc($word); # jrm21
	$word = uc($word);
	$bestform{$word} = $word;
	$vocab[$nextsymbol] = $word;
	$symbol{$word} = $nextsymbol;
	$nextsymbol++;
    }
    $last_delimiter = $nextsymbol - 1;
    # Stopwords
    $first_stopword = $nextsymbol;
    
    foreach my $word (sort keys %stopwords) {
	# don't include stopword unless it occurs in the text
	$word = lc($word);
	next unless ($totalfreq{$word});
	next if ($symbol{$word});
	
	$vocab[$nextsymbol] = $word;
	$symbol{$word} = $nextsymbol;
	$nextsymbol++;
    }
    $last_stopword = $nextsymbol - 1;
    $first_contentword = $nextsymbol;
    
    # Thesaurus terms
    if ($thesaurus) {
	$first_thesaurusword = $nextsymbol;
    
	foreach my $word (sort keys %thesaurus) {
	    
	    $word = lc($word);
	    next if ($symbol{$word});
	    $bestform{$word} = $thesaurus{$word};
	    
	    $vocab[$nextsymbol] = $word;
	    $symbol{$word} = $nextsymbol;
	    $nextsymbol++;
	    
	}
	$last_thesaurusword = $nextsymbol - 1;
    }

    # Other content words
    $first_extractword = $nextsymbol;
    
    foreach my $word (sort (keys %bestform)) {
	
	next if ($symbol{$word});
	
	$vocab[$nextsymbol] = $word;
	$symbol{$word} = $nextsymbol;
	$nextsymbol++;
    }
    $last_extractword = $nextsymbol - 1;
    $last_contentword = $nextsymbol - 1;
    
    # Outut the words
    print $out "Saving vocabulary in $phinddir/clauses.vocab\n" if ($verbosity > 1);
    open(VOC, ">$phinddir/clauses.vocab");

    for (my $i = 1; $i < $nextsymbol; $i++) {
	$w = $vocab[$i];

	print VOC "$bestform{$w}\n";
	$totalfreq{$w} = 0 unless ($totalfreq{$w});
    }
    close VOC;


    # Create statistics file
    # Output statistics about the vocablary
    print $out "Saving statistics in $phinddir/clauses.stats\n" if ($verbosity > 1);
    &FileUtils::removeFiles("$phinddir/clauses.stats") if (-e "$phinddir/clauses.stats");

    open(STAT, ">$phinddir/clauses.stats")
	|| die "Cannot open $phinddir/clauses.stats: $!";

    print STAT "first_delimiter $first_delimiter\n";
    print STAT "last_delimiter $last_delimiter\n";
    print STAT "first_stopword $first_stopword\n";
    print STAT "last_stopword $last_stopword\n";
    if ($thesaurus) {
	print STAT "first_thesaurusword $first_thesaurusword\n";
	print STAT "last_thesaurusword $last_thesaurusword\n";
    }
    print STAT "first_extractword $first_extractword\n";
    print STAT "last_extractword $last_extractword\n";
    print STAT "first_contentword $first_contentword\n";
    print STAT "last_contentword $last_contentword\n";
    print STAT "first_symbol $first_delimiter\n";
    print STAT "last_symbol $last_contentword\n";
    print STAT "first_word $first_stopword\n";
    print STAT "last_word $last_contentword\n";
    close STAT;

    undef @vocab;


    # Create numbers file
    # Save text as symbol numbers
    print $out "Saving text as numbers in $phinddir/clauses.numbers\n" if ($verbosity > 1);
    
    open(TXT, "<$phinddir/clauses");
    open(NUM, ">$phinddir/clauses.numbers");
    
##    $phrasedelimiter = $symbol{lc($senlimit)}; # jrm21
##    print NUM "$symbol{lc($colstart)}\n"; # jrm21
    $phrasedelimiter = $symbol{$senlimit};
    print NUM "$symbol{$colstart}\n";
    
    # set up the special symbols that delimit documents and sentences
    while(<TXT>) {
	
	# split sentence into a list of tokens
	$line = $_;
	next unless ($line =~ /./);
	@words = split(/\s+/, $line);
	
	# output one token at a time
	foreach $word (@words) {
# don't lower-case special delimiters - jrm21
	    if (!map {if ($word eq $_) {1} else {()}} @delimiters) {
		$word = lc($word);
	    }
	    print NUM "$symbol{$word}\n";
	}
	
	# output phrase delimiter
	print NUM "$phrasedelimiter\n";
    }
    
    close TXT;
#    print NUM "$symbol{lc($colend)}\n";# jrm21
    print NUM "$symbol{$colend}\n";
    close NUM;

    # Save thesaurus  data in one convienient file
    if ($thesaurus) {

	my $thesaurusfile = &FileUtils::filenameConcatenate($phinddir, "$thesaurus.numbers");


	print $out "Saving thesaurus as numbers in $thesaurusfile\n" 
	    if ($verbosity > 1);

	# Read the thesaurus terms
	my ($num, $text, %thes_symbols);
	
	open(TH, "<$thesaurus_terms");
	while(<TH>) {
	    chomp;
	    @words = split(/\s+/, $_);
	    $num = shift @words;
	    $text = "";

	    # translate words into symbol numbers
	    foreach $word (@words) {
		$word = lc($word);
		if ($symbol{$word}) {
		    $text .= "s$symbol{$word} ";
		} elsif ($verbosity) {
		    print $out "Phind: No thesaurus symbol, ignoring \"$word\"\n";
		}
	    }
	    $text =~ s/ $//;
	    $thes_symbols{$num} = $text;
	}
	close TH;

	# Read the thesaurus links and write the corresponding data
	open(TH, "<$thesaurus_links");
	open(THOUT, ">$thesaurusfile");

	while(<TH>) {
	    chomp;
	    ($num, $text) = split(/:/, $_);

	    if (defined($thes_symbols{$num})) {
		print THOUT "$num:$thes_symbols{$num}:$text\n";
	    } else {
		print THOUT "$num:untranslated:$text\n";
	    }
	}
	close TH;    
	close THOUT;
    }




}


# renumber_phrases
#
# Prepare the phrases file to be input to mgpp.  The biggest problem is
# reconciling the phrase identifiers used by the suffix program (which
# we'll call suffix-id numbers) with the numbers used in the thesaurus
# (theesaurus-id) to create a ciommon set of phind id numbers (phind-id).
# Phind-id numbers must be sorted by frequency of occurance.
#
# Start creating a set of phind-id numbers from the sorted suffix-id
# numbers and (if required) the thesaurus-id numbers.  Then add any other
# phrases occuring in the thesaurus.
#
# The last thing we have to do is restore the vocabulary information to the
# phrase file so that the phrases are stored as words, not as symbol
# numbers.

# The original phrases file looks something like this:
#   159396-1:s5175:4:1:116149-2:3:d2240,2;d2253;d2254
#   159409-1:s5263:6:1:159410-2:6:d2122;d2128;d2129;d2130;d2215;d2380
#   159415-1:s5267:9:1:159418-2:8:d3,2;d632;d633;d668;d1934;d2010;d2281;d2374
#   159426-1:s5273:5:2:159429-2,115168-17:5:d252;d815;d938;d939;d2361


sub renumber_phrases {
    my ($self) = @_;

    renumber_suffix_data($self);
    renumber_thesaurus_data($self);
    restore_vocabulary_data($self);

}



# renumber_suffix_data
#
# Translate phrases file to phrases.2 using phind keys instead
# of suffix keys and sorting the expansion data.

sub renumber_suffix_data {
    my ($self) = @_;
    
    my $verbosity = $self->{'verbosity'};
    my $out = $self->{'outhandle'};
    print $out "Translate phrases: suffix-ids become phind-id's\n" 
	if ($verbosity);
    
    my $phinddir = $self->{'phinddir'};
    my $infile = &FileUtils::filenameConcatenate($phinddir, 'phrases');
    my $outfile = &FileUtils::filenameConcatenate($phinddir, 'phrases.2');

    # Read the phrase file.  Calculate initial set of phind-id
    # numbers and store (suffixid -> frequency) relation.

    my %suffixtophind;
    my @totalfrequency;
    my (@fields, $suffixid);
    my $nextphind = 1;
    
    open(IN, "<$infile");
    while(<IN>) {

	chomp;
	@fields = split(/:/, $_);
	
	# get next suffixid and phindid
	$suffixid = shift @fields;
	$suffixtophind{$suffixid} = $nextphind;

	# store total frequency
	shift @fields;
	$totalfrequency[$nextphind] = shift @fields;

	$nextphind++;
    }
    close IN;


    # Translate phrases file to phrases.2.  Use phind keys (not suffix
    # keys), sort expansion and document occurance data in order of
    # descending frequency..
    open(IN, "<$infile");
    open(OUT, ">$outfile");
    
    my ($phindid, $text, $tf, $countexp, $expansions, $countdocs, $documents);
    my (@documwents, @newexp, $k, $n);
    my $linenumber = 0;

    while(<IN>) {
	
	# read the line
	chomp;
	@fields = split(/:/, $_);
	
	# get a phrase number for this line
	$suffixid = shift @fields;
	die unless (defined($suffixtophind{$suffixid}));
	$phindid = $suffixtophind{$suffixid};
	
	# get the symbols in the phrase
	$text = shift @fields;

	# output status information
	$linenumber++;
	if ($verbosity > 2) {
	    if ($linenumber % 1000 == 0) {
		print $out "line $linenumber:\t$phindid\t$suffixid\t($text)\n";
	    }
	    # what are $num and $key??
	    #print $out "$num: $key\t($text)\n" if ($verbosity > 3);
	}

	# get the phrase frequency
	$tf = shift @fields;
	
	# get the number of expansions
	$countexp = shift @fields;
	
	# get the expansions, convert them into phind-id numbers, and sort them
	$expansions = shift @fields;
	@newexp = ();
	foreach $k (split(/,/, $expansions)) {
	    die "ERROR - no phindid for: $k" unless (defined($suffixtophind{$k}));
	    $n = $suffixtophind{$k};
	    push @newexp, $n;
	}
	@newexp = sort {$totalfrequency[$b] <=> $totalfrequency[$a]} @newexp;

	# get the number of documents
	$countdocs = shift @fields;
	
	# get the documents and sort them
	$documents = shift @fields;
	$documents =~ s/d//g;
	my @documents = split(/;/, $documents);
	@documents = sort by_doc_frequency @documents;

	# output the phrase data
 	print OUT "$phindid:$text:$tf:$countexp:$countdocs:";
	print OUT join(",", @newexp), ",:", join(";", @documents), ";\n";
	
    }

    close IN;
    close OUT;
}


# renumber_thesaurus_data
#
# Translate phrases.2 to phrases.3, adding thesaurus data if available.

sub renumber_thesaurus_data {
    my ($self) = @_;
  
    my $out = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};
    my $thesaurus = $self->{'thesaurus'};

    my $phinddir = $self->{'phinddir'};
    my $infile = &FileUtils::filenameConcatenate($phinddir, "phrases.2");
    my $outfile = &FileUtils::filenameConcatenate($phinddir, "phrases.3");


    # If no thesaurus is defined, simply move the phrases file.
    if (!$thesaurus) {
	print $out "Translate phrases.2: no thesaurus data\n" 
	    if ($verbosity);
	&FileUtils::moveFiles($infile, $outfile);
	return;
    }

    print $out "Translate phrases.2: add thesaurus data\n" 
	if ($verbosity);

    # 1.
    # Read thesaurus file and store (symbols->thesaurusid) mapping
    my $thesaurusfile = &FileUtils::filenameConcatenate($phinddir, "$thesaurus.numbers");
    my %symbolstothesid;
    my (@fields, $thesid, $symbols);
    
    open(TH, "<$thesaurusfile");

    while (<TH>) {
	
	chomp;
	@fields = split(/:/, $_);
	
	# get id and text
	$thesid = shift @fields;
	$symbols = shift @fields;
	$symbolstothesid{$symbols} = $thesid;
    }
    close TH;    

    # 2. 
    # Read phrases file to find thesaurus entries that already
    # have a phindid.  Store their phind-ids for later translation,
    # and store their frequency for later sorting.
    my %thesaurustophindid;
    my %phindidtofrequency;
    my ($phindid, $freq);

    open(IN, "<$infile");
    
    while(<IN>) {
	
	chomp;
	@fields = split(/:/, $_);
	
	# phindid and symbols for this line
	$phindid = shift @fields;
	$symbols = shift @fields;
	$freq = shift @fields;

	# do we have a thesaurus id corresponding to this phrase?
	if (defined($symbolstothesid{$symbols})) {
	    $thesid = $symbolstothesid{$symbols};
	    $thesaurustophindid{$thesid} = $phindid;
	    $phindidtofrequency{$phindid} = $freq;
	}
    }
    close IN;
  
    undef %symbolstothesid;

    # 3.
    # Create phind-id numbers for remaining thesaurus entries,
    # and note that their frequency is 0 for later sorting.
    my $nextphindid = $phindid + 1;

    open(TH, "<$thesaurusfile");
    while(<TH>) {
	
	chomp;
	@fields = split(/:/, $_);
	
	# read thesaurus-id and ensure it has a corresponding phind-id
	$thesid = shift @fields;
	if (!defined($thesaurustophindid{$thesid})) {
	    $thesaurustophindid{$thesid} = $nextphindid;
	    $phindidtofrequency{$nextphindid} = 0;
	    $nextphindid++;
	}
    }
    close TH;

    # 4.
    # Translate thesaurus file, replacing thesaurus-id numbers with 
    # phind-id numbers.
    my $newthesaurusfile = &FileUtils::filenameConcatenate($phinddir, "$thesaurus.phindid");
    my ($relations, $linkcounter, $linktext, $linktype, @linkdata);
    my (@links, $linkid, %linkidtotype, $newrelation);

    open(TH, "<$thesaurusfile");
    open(TO, ">$newthesaurusfile");
    while(<TH>) {
	
	chomp;
	@fields = split(/:/, $_);
	
	# phindid and symbols for this line
	($thesid, $symbols, $relations) = @fields;
	
	die unless ($thesid && $symbols);
	die unless $thesaurustophindid{$thesid};
	$phindid = $thesaurustophindid{$thesid};

	# convert each part of the relation string to use phind-id numbers
	# at the same time, we want to sort the list by frequency.
	undef %linkidtotype;
	
	foreach $linktext (split(/;/, $relations)) {
	    @linkdata = split(/,/, $linktext);
	    
	    # remember the linktype (e.g. BT, NT)
	    $linktype = shift @linkdata;
	    
	    # store the type of each link
	    foreach $thesid (@linkdata) {
		die unless (defined($thesaurustophindid{$thesid}));
		$linkidtotype{$thesaurustophindid{$thesid}} = $linktype;
	    }
	}

	# sort the list of links, first by frequency, then by type.
	@links = sort { ($phindidtofrequency{$b} <=> $phindidtofrequency{$a}) 
                        or ($linkidtotype{$a} cmp $linkidtotype{$b}) } (keys %linkidtotype);
	$linkcounter = (scalar @links);

	# create a string describing the link information
	$linktype = $linkidtotype{$links[0]};
	$newrelation = $linktype;
	foreach $linkid (@links) {
	    if ($linkidtotype{$linkid} ne $linktype) {
		$linktype = $linkidtotype{$linkid};
		$newrelation .= ";" . $linktype;
	    }
	    $newrelation .= "," . $linkid;
	}
	$newrelation .= ";";
	

	# output the new line
	print TO "$phindid:$symbols:$linkcounter:$newrelation:\n";
    }
    close TH;
    close TO;

    undef %thesaurustophindid;
    undef %linkidtotype;
    undef %phindidtofrequency;

    # 5.
    # Read thesaurus data (in phind-id format) into memory
    my %thesaurusdata;

    open(TH, "<$newthesaurusfile");
    while(<TH>) {
	chomp;
	($phindid, $symbols, $linkcounter, $relations) = split(/:/, $_);
	die unless ($phindid && $symbols);
	$thesaurusdata{$phindid} = "$symbols:$linkcounter:$relations";
    }
    close TH;

    # 6. 
    # Add thesaurus data to phrases file
    my ($text, $tf, $countexp, $expansions, $countdocs, $documents);
    my (@documwents, @newexp, $k, $n);
    my $linenumber = 0;

    open(IN, "<$infile");
    open(OUT, ">$outfile");

    # Update existing phrases
    while(<IN>) {
	
	chomp;
	@fields = split(/:/, $_);
		
	# get data for this line
	$phindid = shift @fields;
	
	# output the phrase data, with thesaurus information
 	print OUT "$phindid:", join(":", @fields);

	# add thesaurus data
	if (defined($thesaurusdata{$phindid})) {
	    @fields = split(/:/, $thesaurusdata{$phindid});
	    shift @fields;
	    $linkcounter = shift @fields;
	    $relations = shift @fields;

	    print OUT ":$linkcounter:$relations";
	    $thesaurusdata{$phindid} = "";
	}
	print OUT "\n";
    }
    close IN;

    # Add phrases that aren't already in the file
    foreach $phindid (sort numerically keys %thesaurusdata) {
	next unless ($thesaurusdata{$phindid});

	@fields = split(/:/, $thesaurusdata{$phindid});
	$symbols = shift @fields;
	$linkcounter = shift @fields;
	$relations = shift @fields;

	print OUT "$phindid:$symbols:0:0:0:::$linkcounter:$relations\n";
    }
    close OUT;

}

# restore_vocabulary_data
#
# Read phrases.3 and restore vocabulary information. Then write 
# this data to the MGPP input files (pword.txt and pdata.txt) and
# (if requested) to the saved phrases file.

sub restore_vocabulary_data {
    my ($self) = @_;
 
    my $out = $self->{'outhandle'};
    my $verbosity = $self->{'verbosity'};
    print $out "Translate phrases.3: restore vocabulary\n" if ($verbosity);

    my $phinddir = $self->{'phinddir'};
    my $infile = &FileUtils::filenameConcatenate($phinddir, 'phrases.3');
    my $vocabfile = &FileUtils::filenameConcatenate($phinddir, 'clauses.vocab');
    my $datafile = &FileUtils::filenameConcatenate($phinddir, 'pdata.txt');
    my $wordfile = &FileUtils::filenameConcatenate($phinddir, 'pword.txt');

    my $savephrases = $self->{'savephrases'};

    # 1.
    # Read the vocabulary file
    open(V, "<$vocabfile")
	|| die "Cannot open $vocabfile: $!";
    my @symbol;
    my $i = 1;
    while(<V>) {
	chomp;
	$symbol[$i++] = $_;
    }
    close V;

    # 2. 
    # Translate phrases.3 to MGPP input files
    my ($key, $text, $word, $isThesaurus, $line);
    my @fields;
    my $linenumber = 0;

    open(IN, "<$infile");
    open(DATA, ">$datafile");
    open(WORD, ">$wordfile");

    # Save the phrases in a separate text file
    if ($savephrases) {
	print $out "Saving phrases in $savephrases\n" if ($verbosity);
	open(SAVE, ">$savephrases");
    }

    while(<IN>) {
	
	# read the line
	chomp;
	$line = $_;
	@fields = split(/:/, $line);
	
	# get a phrase number for this line
	$key = shift @fields;
	
	# restore the text of the phrase
	$text = shift @fields;
	$text =~ s/s(\d+)/$symbol[$1]/g;
	if ($text =~ / /) {
	    $word = "";
	} elsif ($text ne 'untranslated') {
	    $word = $text;
	}

	# output the phrase data
	print DATA "<Document>";
 	print DATA "$key:$text:", join(":", @fields), ":\n";
	
	# output the word index search data
	print WORD "<Document>$word\n";

	# output the phrases to a text file
	if ($savephrases) {
	    if ((scalar @fields) == 7) {
		$isThesaurus = 1;
	    } else {
		$isThesaurus = 0;
	    }
	    print SAVE $fields[0], "\t", $fields[2], "\t$isThesaurus\t$text\n";
	}
    }
    close IN;
    close WORD;
    close DATA;
    close SAVE if ($savephrases);

}



# sort routines used to renumber phrases

sub numerically { $a <=> $b }

sub by_doc_frequency { 
    my $fa = 1;
    if ($a =~ /,/) {
	$fa = $a;
	$fa =~ s/\d+,//;
    }
    my $fb = 1;
    if ($b =~ /,/) {
	$fb = $b;
	$fb =~ s/\d+,//;
    }

    return ($fb <=> $fa);
}

1;
