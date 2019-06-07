###########################################################################
#
# BibTexPlugin.pm - a plugin for bibliography records in BibTex format
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright 2000 Gordon W. Paynter
# Copyright 1999-2001 New Zealand Digital Library Project
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


# BibTexPlugin reads bibliography files in BibTex format.
#
# by Gordon W. Paynter (gwp@cs.waikato.ac.nz), November 2000
# Based on ReferPlug.  See ReferPlug for geneology.
#
# BibTexPlugin creates a document object for every reference a the file.
# It is a subclass of SplitTextFile, so if there are multiple records, all
# are read.
#
# Modified Dec 2001 by John McPherson:
#  *  some modifications submitted by Sergey Yevtushenko
#                      <sergey@intellektik.informatik.tu-darmstadt.de>
#  *  some non-ascii char support (ie mostly Latin)


package BibTexPlugin;

use SplitTextFile;
use MetadataRead;
use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

# BibTexPlugin is a sub-class of SplitTextFile.
sub BEGIN {
    @BibTexPlugin::ISA = ('MetadataRead', 'SplitTextFile');
}

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "split_exp",
	'desc' => "{SplitTextFile.split_exp}",
	'type' => "regexp",
	'deft' => &get_default_split_exp(),
	'reqd' => "no" }
      ];

my $options = { 'name'     => "BibTexPlugin",
		'desc'     => "{BibTexPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'explodes' => "yes",
		'args'     => $arguments };

# This plugin processes files with the suffix ".bib"
sub get_default_process_exp {
    return q^(?i)\.bib$^;
}

# This plugin splits the input text at blank lines
sub get_default_split_exp {
    return q^\n+(?=@)^;
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}



# The process function reads a single bibliographic record and stores
# it as a new document.

sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my $cursection = $doc_obj->get_top_section();
    $self->{'key'} = "default";

    # Check that we're dealing with a valid BibTex record
    return undef unless ($$textref =~ /^@\w+\{.*\}/s);

    # Ignore things we can't use
    return 0 if ($$textref =~ /^\@String/);

    # This hash translates BibTex field names into metadata names.  The
    # BibTex names are taken from the "Local Guide to Latex" Graeme
    # McKinstry.  Metadata names are consistent with ReferPlug.

    # The author metadata will be stored as one "Creator" entry, but will
    # also be split up into several individual "Author" fields.

    my %field = (
		 'address', 'PublisherAddress',
		 'author', 'Creator',
		  
		 'booktitle', 'Booktitle',
		 'chapter', 'Chapter',
		 'edition', 'Edition',
		 'editor', 'Editor', 
		 'institution', 'Publisher',
		 'journal', 'Journal',
		 'month', 'Month',
		 'number', 'Number',
		 'pages', 'Pages',
		 'publisher', 'Publisher',
		 'school', 'Publisher',
		 'title', 'Title',
		 'volume', 'Volume',
		 'year', 'Year', # Can't use "Date" as this implies DDDDMMYY!

		 'keywords', 'Keywords',
		 'abstract', 'Abstract',
		 'copyright', 'Copyright',
		 'note', 'Note',
		 'url', 'URL',
		 );

    # Metadata fields 
    my %metadata;
    my ($EntryType, $Creator, $Keywords, $text);

    my $verbosity = $self->{'verbosity'};
    $verbosity = 0 unless $verbosity;

    # Make sure the text has exactly one entry per line -
    # append line to previous if it doesn't start with "  <key> = "

    my @input_lines=split(/\r?\n/, $$textref);
    my @all_lines;
    my $entry_line=shift @input_lines;
    foreach my $input_line (@input_lines) {
	if ($input_line =~ m/^\s*\w+\s*=\s*/) {
	    # this is a new key
	    push(@all_lines, $entry_line);
	    $entry_line=$input_line;
	} else {
	    # this is a continuation of previous line
	    $entry_line .= " " . $input_line;
	}
	
    }
    # add final line, removing trailing '}'
    $entry_line =~ s/\}\s*$//;
    push(@all_lines, $entry_line);
    push(@all_lines, "}");

    # Read and process each line in the bib file.
    my ($entryname, $name, $value, $line);
    foreach $line (@all_lines) {

	# Add each line.  Most lines consist of a field identifer and
	# then data, and we simply store them, though we treat some
	# of the fields a bit differently.

	$line =~ s/\s+/ /g;
	$text .= "$line\n";


	print "Processing line = $line \n" if $verbosity>=4;

	# The first line is special, it contains the reference type and OID
	if ($line =~ /\@(\w+)\W*\{\W*([\*\.\w\d:-]*)\W*$/) {
	    $EntryType = $1;
	    my $EntryID = (defined $2) ? $2 : "default";
	    print "** $EntryType - \"$EntryID\" \n"
		if ($verbosity >= 4);

	    next;
	}
	if ($line =~ /\@/) {
	    print $outhandle "bibtexplug: suspect line in bibtex file: $line\n"
		if ($verbosity >= 2);
	    print $outhandle "bibtexplug: if that's the start of a new bibtex record ammend regexp in bibtexplug::process()\n"
		if ($verbosity >= 2);
	}
	
	# otherwise, parse the metadata out of this line
	next unless ($line =~ /^\s*(\w+)\s*=\s*(.*)/);
	$entryname = lc($1);
	$value = $2;
	$value =~ s/,?\s*$//; # remove trailing comma and space
	if ($value =~ /^"/ && $value =~ /"$/) {
	    # remove surrounding " marks
	    $value =~ s/^"//; $value =~ s/"$//;
	} elsif ($value =~ /^\{/ && $value =~ /\}$/) {
	    # remove surrounding {} marks
	    $value =~ s/^\{//; $value =~ s/\}$//;
	}
	# special case for year - we only want a 4 digit year, not 
	# "circa 2004" etc
	if ($entryname=~ /^year$/i) {
	    if ($value=~ /(\d{4})/) {
		$value=$1;
		$metadata{$entryname} .= "$value";
	    }
	} 
	else {
	    
	    $value = &process_latex($value);
	    # Add this line of metadata
	    $metadata{$entryname} .= "$value";	
	}
    }

    # Add the Entry type as metadata
    $doc_obj->add_utf8_metadata ($cursection, "EntryType", $EntryType);
    
    #Add the fileformat as metadata
    $doc_obj->add_metadata($cursection, "FileFormat", "BibTex");


    # Add the various field as metadata
    foreach my $entryname (keys %metadata) {
	next unless (defined $field{$entryname});
	next unless (defined $metadata{$entryname});	
	
	$name = $field{$entryname};
	$value = $metadata{$entryname};

	if ($name =~ /^Month/) {
	    $value=expand_month($value);
	}

	# Several special operatons on metadata follow
	
	# Add individual keywords.
	# The full set of keywords will be added, in due course, as "Keywords".
	# However, we also want to add them as individual "Keyword" metadata elements.
	if ($entryname eq "keywords") {
	    my @keywordlist = split(/,/, $value);
	    foreach my $k (@keywordlist) {
		$k = lc($k); 
		$k =~ s/\s*$//; 
		$k =~ s/^\s*//; 
		if ($k =~ /\w/) {
		    $doc_obj->add_utf8_metadata ($cursection, "Keyword", $k);
		}
	    } 
	}
	
	# Add individual authors
	# The author metadata will be stored as one "Creator" entry, but we
	# also want to split it into several individual "Author" fields in
	# "Lastname, Firstnames" format so we can browse it.
	if ($entryname eq "author") { #added also comparison with editor
	   
	    # take care of "et al."...
	    my $etal='';
	    if ($value =~ s/\s+(and\s+others|et\.?\s+al\.?)\s*$//i) {
		$etal=' <em>et. al.</em>';
	    }
	    # und here for german language...
	    # don't use brackets in pattern, else the matched bit becomes
	    # an element in the list!
	    my @authorlist = split(/\s+and\s+|\s+und\s+/, $value); 
	    my @formattedlist = ();
	    foreach $a (@authorlist) {
		$a =~ s/\s*$//; 
		$a =~ s/^\s*//; 
		# Reformat and add author name
		next if $a=~ /^\s*$/;
		
		# names are "First von Last", "von Last, First"
		# or "von Last, Jr, First". See the "BibTeXing" manual, page 16
		my $first="";
		my $vonlast="";
		my $jr="";

		if ($a =~ /,/) {
		    my @parts=split(/,\s*/, $a);
		    $first = pop @parts;
		    if (scalar(@parts) == 2) {
			$jr = pop @parts;
		    }
		    $vonlast=shift @parts;
		    if (scalar(@parts) > 0) {
			print $outhandle "BibTexPlugin: couldn't parse name $a\n";
			# but we continue anyway...
		    }
		} else { # First von Last
		    my @words = split(/ /, $a);
		    while (scalar(@words) > 1 && $words[0] !~ /^[a-z]{2..}/) {
			$first .= " " . shift (@words);
		    }
		    $first =~ s/^\s//;
		    $vonlast = join (' ', @words); # whatever's left...
		}
		my $von="";
		my $last="";
		if ($vonlast =~ m/^[a-z]/) { # lowercase implies "von"
		    $vonlast =~ s/^(([a-z]\w+\s+)+)//;
		    $von = $1;
		    if (!defined ($von)) {
			# some non-English names do start with lowercase
			# eg "Marie desJardins". Also we can get typos...
			print $outhandle "BibTexPlugin: couldn't parse surname $vonlast\n";
			$von="";
			if ($vonlast =~ /^[a-z]+$/) {
			    # if it's all lowercase, uppercase 1st.
			    $vonlast =~ s/^(.)/\u$1/;

			}
		    }
		    $von =~ s/\s*$//;
		    $last=$vonlast;
		} else {
		    $last=$vonlast;
		}
		my $wholename="$first $von $last $jr";
		$wholename =~ s/\s+/ /g; # squeeze multiple spaces
		$wholename =~ s/ $//;
		push (@formattedlist, $wholename);
		my $fullname = "$last";
		$fullname .= " $jr" if ($jr);
		$fullname .= ", $first";
		$fullname .= " $von" if ($von);

		# Add each name to set of Authors
		$doc_obj->add_utf8_metadata ($cursection, "Author", $fullname);
	    }

	    # Only want at most one "and" in the Creator field
	    if (scalar(@formattedlist) > 2) {
		my $lastauthor=pop @formattedlist;
		$value=join(', ', @formattedlist);
		$value.=" and $lastauthor";
	    } else { # 1 or 2 authors...
		$value=join(" and ",@formattedlist);
	    }
	    $value.=$etal; # if there was "et al."
	}

	# Books and Journals are additionally marked for display purposes
	if ($entryname eq "booktitle") {
	    $doc_obj->add_utf8_metadata($cursection, "BookConfOnly", 1);
	} elsif ($entryname eq "journal") {
	    $doc_obj->add_utf8_metadata($cursection, "JournalsOnly", 1); 
	}

	# Add the various fields as metadata	
	$doc_obj->add_utf8_metadata ($cursection, $name, $value); 
    
    }

    # for books and journals...
    if (!exists $metadata{'title'}) {
	my $name=$field{'title'}; # get Greenstone metadata name
	my $value;
	if (exists $metadata{'booktitle'}) {
	    $value=$metadata{'booktitle'};
	} elsif (exists $metadata{'journal'}) {
	    $value=$metadata{'journal'};
	}
	if ($value) {
	    $doc_obj->add_utf8_metadata ($cursection, $name, $value); 
	}
    }

    # Add Date (yyyymmdd) metadata
    if (defined ($metadata{'year'}) ) {
	my $date=$metadata{'year'};
	chomp $date;
	my $month=$metadata{'month'};
	if (defined($month)) {
	    # month is currently 3 letter code or a range...
	    $month = expand_month($month);
	    # take the first month found... might not find one!
	    $month =~ m/_textmonth(\d\d)_/;
	    $month = $1;
	}
	if (!defined($month)) {
	    $month="00";
	}
	$date .= "${month}00";
	$doc_obj->add_utf8_metadata($cursection, "Date", $date); 
}

#    # Add the text in BibTex format (all fields)
    if ($text =~ /\w/) {

	$text =~ s@&@&amp;@g;
	$text =~ s@<@&lt;@g;
	$text =~ s@>@&gt;@g;
	$text =~ s@\n@<br/>\n@g;
	$text =~ s@\\@\\\\@g;

	$doc_obj->add_utf8_text ($cursection, $text);
    }

    return 1;
}




# convert email addresses and URLs into links
sub convert_urls_into_links{
   my ($text) = @_;
 
   $text =~ s/([\w\d\.\-]+@[\w\d\.\-]+)/<a href=\"mailto:$1\">$1<\/a>/g;
   $text =~ s/(http:\/\/[\w\d\.\-]+[\/\w\d\.\-]*)/<a href=\"$1\">$1<\/a>/g;

   return $text;
}

# Clean up whitespace and convert \n charaters to <BR> or <P>
sub clean_up_whitespaces{
   my ($text) = @_;

   $text =~ s/%%%%%/<BR> <BR>/g;
   $text =~ s/ +/ /g;
   $text =~ s/\s*$//; 
   $text =~ s/^\s*//; 
   $text =~ s/\n/\n<BR>/g;
   $text =~ s/<BR>\s*<BR>/<P>/g;

   return $text;
}


sub convert_problem_characters_without_ampersand{
    my ($text) = @_;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    
    $text =~ s/\'\'/\"/g; #Latex -specific conversion
    $text =~ s/\`\`/\"/g; #Latex -specific conversion

    $text =~ s/\"/&quot;/g;
    $text =~ s/\'/&#8217;/g;
    $text =~ s/\`/&#8216;/g;

#    $text =~ s/\+/ /g;
#    $text =~ s/\(/ /g;
#    $text =~ s/\)/ /g;

    $text =~ s/\\/\\\\/g;

#    $text =~ s/\./\\\./g;

    return $text;
}

# Convert a text string into HTML.

# The HTML is going to be inserted into a GML file, so we have to be
# careful not to use symbols like ">", which occurs frequently in email
# messages (and use &gt instead.

# This function also turns URLs and email addresses into links, and
# replaces carriage returns with <BR> tags (and multiple carriage returns
# with <P> tags).

sub text_into_html {
    my ($text) = @_;

    # Convert problem characters into HTML symbols
    $text =~ s/&/&amp;/g;

    $text = &convert_problem_characters_without_ampersand( $text );

    # convert email addresses and URLs into links
    $text = &convert_urls_into_links( $text );

    $text = &clean_up_whitespaces( $text );

    return $text;
}


sub expand_month {
    my $text=shift;

    # bibtex style files expand abbreviations for months.
    # Entries can contain more than one month (eg ' month = jun # "-" # aug, ')
    $text =~ s/jan/_textmonth01_/g;
    $text =~ s/feb/_textmonth02_/g;
    $text =~ s/mar/_textmonth03_/g;
    $text =~ s/apr/_textmonth04_/g;
    $text =~ s/may/_textmonth05_/g;
    $text =~ s/jun/_textmonth06_/g;
    $text =~ s/jul/_textmonth07_/g;
    $text =~ s/aug/_textmonth08_/g;
    $text =~ s/sep/_textmonth09_/g;
    $text =~ s/oct/_textmonth10_/g;
    $text =~ s/nov/_textmonth11_/g;
    $text =~ s/dec/_textmonth12_/g;

    return $text;
}


# Convert accented characters, remove { }, interprete some commands....
# Note!! This is not comprehensive! Also assumes Latin -> Unicode!
sub process_latex {
    my ($text) = @_;
      
    # note - this is really ugly, but it works. There may be a prettier way
    # of mapping latex accented chars to utf8, but we just brute force it here.
    # Also, this isn't complete - not every single possible accented letter
    # is in here yet, but most of the common ones are.

    my %utf8_chars =
	(
	 # acutes
	 '\'a' => chr(0xc3).chr(0xa1),
	 '\'c' => chr(0xc4).chr(0x87),
	 '\'e' => chr(0xc3).chr(0xa9),
	 '\'i' => chr(0xc3).chr(0xad),
	 '\'l' => chr(0xc3).chr(0xba),
	 '\'n' => chr(0xc3).chr(0x84),
	 '\'o' => chr(0xc3).chr(0xb3),
	 '\'r' => chr(0xc5).chr(0x95),
	 '\'s' => chr(0xc5).chr(0x9b),
	 '\'u' => chr(0xc3).chr(0xba),
	 '\'y' => chr(0xc3).chr(0xbd),
	 '\'z' => chr(0xc5).chr(0xba),
	 # graves
	 '`a' => chr(0xc3).chr(0xa0),
	 '`A' => chr(0xc3).chr(0x80),
	 '`e' => chr(0xc3).chr(0xa8),
	 '`E' => chr(0xc3).chr(0x88),
	 '`i' => chr(0xc3).chr(0xac),
	 '`I' => chr(0xc3).chr(0x8c),
	 '`o' => chr(0xc3).chr(0xb2),
	 '`O' => chr(0xc3).chr(0x92),
	 '`u' => chr(0xc3).chr(0xb9),
	 '`U' => chr(0xc3).chr(0x99),
	 # circumflex
	 '^a' => chr(0xc3).chr(0xa2),
	 '^A' => chr(0xc3).chr(0x82),
	 '^c' => chr(0xc4).chr(0x89),
	 '^C' => chr(0xc4).chr(0x88),
	 '^e' => chr(0xc3).chr(0xaa),
	 '^E' => chr(0xc3).chr(0x8a),
	 '^g' => chr(0xc4).chr(0x9d),
	 '^G' => chr(0xc4).chr(0x9c),
	 '^h' => chr(0xc4).chr(0xa5),
	 '^H' => chr(0xc4).chr(0xa4),
	 '^i' => chr(0xc3).chr(0xae),
	 '^I' => chr(0xc3).chr(0x8e),
	 '^j' => chr(0xc4).chr(0xb5),
	 '^J' => chr(0xc4).chr(0xb4),
	 '^o' => chr(0xc3).chr(0xb4),
	 '^O' => chr(0xc3).chr(0x94),
	 '^s' => chr(0xc5).chr(0x9d),
	 '^S' => chr(0xc5).chr(0x9c),
	 '^u' => chr(0xc3).chr(0xa2),
	 '^U' => chr(0xc3).chr(0xbb),
	 '^w' => chr(0xc5).chr(0xb5),
	 '^W' => chr(0xc5).chr(0xb4),
	 '^y' => chr(0xc5).chr(0xb7),
	 '^Y' => chr(0xc5).chr(0xb6),
	 
	 # diaeresis
	 '"a' => chr(0xc3).chr(0xa4),
	 '"A' => chr(0xc3).chr(0x84),
	 '"e' => chr(0xc3).chr(0xab),
	 '"E' => chr(0xc3).chr(0x8b),
	 '"\\\\i' => chr(0xc3).chr(0xaf),
	 '"\\\\I' => chr(0xc3).chr(0x8f),
	 '"o' => chr(0xc3).chr(0xb6),
	 '"O' => chr(0xc3).chr(0x96),
	 '"u' => chr(0xc3).chr(0xbc),
	 '"U' => chr(0xc3).chr(0x9c),
	 '"y' => chr(0xc3).chr(0xbf),
	 '"Y' => chr(0xc3).chr(0xb8),
	 # tilde
	 '~A' => chr(0xc3).chr(0x83),
	 '~N' => chr(0xc3).chr(0x91),
	 '~O' => chr(0xc3).chr(0x95),
	 '~a' => chr(0xc3).chr(0xa3),
	 '~n' => chr(0xc3).chr(0xb1),
	 '~o' => chr(0xc3).chr(0xb5),
	 # caron - handled specially
	 # double acute
	 # ring
	 # dot
	 '.c' => chr(0xc4).chr(0x8b),
	 '.C' => chr(0xc4).chr(0x8a),
	 '.e' => chr(0xc4).chr(0x97),
	 '.E' => chr(0xc4).chr(0x96),
	 '.g' => chr(0xc4).chr(0xa1),
	 '.G' => chr(0xc4).chr(0xa0),
	 '.I' => chr(0xc4).chr(0xb0),
	 '.z' => chr(0xc5).chr(0xbc),
	 '.Z' => chr(0xc5).chr(0xbb),
	 # macron
	 '=a' => chr(0xc4).chr(0x81),
	 '=A' => chr(0xc4).chr(0x80),
	 '=e' => chr(0xc4).chr(0x93),
	 '=E' => chr(0xc4).chr(0x92),
	 '=i' => chr(0xc4).chr(0xab),
	 '=I' => chr(0xc4).chr(0xaa),
	 '=o' => chr(0xc4).chr(0x8d),
	 '=O' => chr(0xc4).chr(0x8c),
	 '=u' => chr(0xc4).chr(0xab),
	 '=U' => chr(0xc4).chr(0xaa),
	 
	 # stroke - handled specially - see below
	 
	 # cedilla - handled specially
	 );
    
# these are one letter latex commands - we make sure they're not a longer
# command name. eg {\d} is d+stroke, so careful of \d
    my %special_utf8_chars = 
	(
	 # breve
	 'u g' => chr(0xc4).chr(0x9f),
	 'u G' => chr(0xc4).chr(0x9e),
	 'u i' => chr(0xc4).chr(0xad),
	 'u I' => chr(0xc4).chr(0xac),
	 'u o' => chr(0xc5).chr(0x8f),
	 'u O' => chr(0xc5).chr(0x8e),
	 'u u' => chr(0xc5).chr(0xad),
	 'u U' => chr(0xc5).chr(0xac),
	 # caron
	 'v c' => chr(0xc4).chr(0x8d),
	 'v C' => chr(0xc4).chr(0x8c),
	 'v n' => chr(0xc5).chr(0x88),
	 'v N' => chr(0xc5).chr(0x87),
	 'v s' => chr(0xc5).chr(0xa1),
	 'v S' => chr(0xc5).chr(0xa5),
	 'v z' => chr(0xc5).chr(0xbe),
	 'v Z' => chr(0xc5).chr(0xbd),
	 # cedilla
	 'c c' => chr(0xc3).chr(0xa7),
	 'c C' => chr(0xc3).chr(0x87),
	 'c g' => chr(0xc4).chr(0xa3),
	 'c G' => chr(0xc4).chr(0xa2),
	 'c k' => chr(0xc4).chr(0xb7),
	 'c K' => chr(0xc4).chr(0xb6),
	 'c l' => chr(0xc4).chr(0xbc),
	 'c L' => chr(0xc4).chr(0xbb),
	 'c n' => chr(0xc5).chr(0x86),
	 'c N' => chr(0xc5).chr(0x85),
	 'c r' => chr(0xc5).chr(0x97),
	 'c R' => chr(0xc5).chr(0x96),
	 'c s' => chr(0xc5).chr(0x9f),
	 'c S' => chr(0xc5).chr(0x9e),
	 'c t' => chr(0xc5).chr(0xa3),
	 'c T' => chr(0xc5).chr(0xa2),
	 # double acute / Hungarian accent
	 'H O' => chr(0xc5).chr(0x90),
	 'H o' => chr(0xc5).chr(0x91),
	 'H U' => chr(0xc5).chr(0xb0),
	 'H u' => chr(0xc5).chr(0xb1),
	 
	 # stroke 
	 'd' => chr(0xc4).chr(0x91),
	 'D' => chr(0xc4).chr(0x90),
	 'h' => chr(0xc4).chr(0xa7),
#	 'H' => chr(0xc4).chr(0xa6), # !! this normally(!!?) means Hung. umlaut
	 'i' => chr(0xc4).chr(0xb1), # dotless lowercase i
	 'l' => chr(0xc5).chr(0x82),
	 'L' => chr(0xc5).chr(0x81),
	 'o' => chr(0xc3).chr(0xb8),
	 'O' => chr(0xc3).chr(0x98),
	 't' => chr(0xc5).chr(0xa7),
	 'T' => chr(0xc5).chr(0xa6),
	 # german ss/szlig/sharp s
	 'ss' => chr(0xc3).chr(0x9f),
	 );
    
    # convert latex-style accented characters.

    # remove space (if any) between \ and letter to accent (eg {\' a})

    $text =~ s@(\\[`'="^~\.])\s(\w)@$1$2@g; #`
		   
    # remove {} around a single character (eg \'{e})
    $text =~ s@(\\[`'="^~\.]){(\w)}@{$1$2}@g; #`

    # \, is another way of doing cedilla \c
    $text =~ s@\\,(.)@\\c $1@g;

    # remove {} around a single character for special 1 letter commands -
    # need to insert a space. Eg \v{s}  ->  {\v s}
    $text =~ s@(\\[uvcH]){(\w)}@{$1 $2}@g;

    # only do if the text contains a '\' character. 
    if ($text =~ m|\\|) {
	# "normal" accents - ie non-alpha latex tag
	while ($text =~ m@\\([`'="^~\.])([\w])@) { #`
	    my $tex="$1$2"; my $char="$2";
	    my $replacement=$utf8_chars{$tex};
	    if (!defined($replacement)) {
		print STDERR "BibTexPlugin: Warning: unknown latex accent \"$tex\" in \"$text\"\n";
		$replacement=$char;
	    }
	    $text =~ s/\\\Q$tex/$replacement/g;
	}

        # where the following letter matters (eg "sm\o rrebr\o d", \ss{})
        # only do the change if immediately followed by a space, }, {, or \
	# one letter accents ( + ss)
        while ($text =~ m@\\([DdhiLlOoTt]|ss)[{}\s\"\\]@) {
	    my $tex=$1;
	    my $replacement=$special_utf8_chars{$tex};
	    if (!defined($replacement)) {
		print STDERR "BibTexPlugin: Warning: unknown latex accent \"$tex\" in \"$text\"\n";
		$replacement=$tex;
	    }
	    $text =~ s/\\$tex([{}\s\"\\])/$replacement$1/g;

	}

	# one letter latex accent commands that affect following letter
        while ($text =~ m@\\([uvcH]) ([\w])@) {
          my $tex="$1 $2"; my $char="$2";
          my $replacement=$special_utf8_chars{$tex};
          if (!defined($replacement)) {
	      print STDERR "BibTexPlugin: Warning: unknown latex accent \"$tex\" in \"$text\"\n";
	      $replacement=$char;
	  }
          $text =~ s/\\$tex/$replacement/g;
        }
    }

    # escape html-sensitive characters
    $text =~ s@&@&amp;@g;
    $text =~ s@<@&lt;@g;
    $text =~ s@>@&gt;@g;
    $text =~ s/''/"/g; # Latex-specific
    $text =~ s/``/"/g; # Latex-specific
    # greenstone-specific
    $text =~ s@\[@&\#91;@g;
    $text =~ s@\]@&\#93;@g;

    # remove latex commands

    # explicitly recognised commands
    $text =~ s@\\ldots@&hellip;@g;

    # maths mode
    $text =~ s@\$(.*?)\$@&process_latex_math($1)@ge;

    # remove all other commands with optional arguments...
    $text =~ s@\\\w+(\[.*?\])?\s*@@g;
    # $text =~ s@\\noopsort{[^}]+\}@@g;
    # $text =~ s@\\\w+{(([^}]*[^\\])*)}@$1@g; # all other commands
    
    # remove latex groupings { } (but not \{ or \} )
    while ($text =~ s/([^\\])[\{\}]/$1/g) {;} # needed for "...}{..."
    $text =~ s/^\{//; # remove { if first char
    
    # latex characters
    # spaces - nobr space (~), opt break (\-), append ("#" - bibtex only)
    $text =~ s/([^\\])~+/$1 /g; # non-breaking space  "~"
    # optional break "\-"
    if ($text =~ m/[^&]\#/) { # concat macros (bibtex) but not HTML codes
	# the non-macro bits have quotes around them - we just remove quotes
	$text =~ s/([^&])[\"\#]/$1/g;
    }
    # dashes. Convert (m|n)-dash into single dash for html.
    $text =~ s@\-\-+@\-@g;

    # quoted { } chars
    $text =~ s@\\\{@{@g;
    $text =~ s@\\}@}@g;

    # finally to protect against macro language...
    $text =~ s@\\@\\\\@g;

    return $text;
}


sub process_latex_math {
    my $text = shift;

    $text =~ s@\\infty@infinity@g;       # or unicode 0x221E...
    $text =~ s@\^\{(.*?)}@<sup>$1</sup>@g; # superscript
    $text =~ s@\^([^\{])@<sup>$1</sup>@g;
    $text =~ s@\_\{(.*?)}@<sub>$1</sub>@g; # subscript
    $text =~ s@\_([^\{])@<sub>$1</sub>@g;

    # put all other command names in italics
    $text =~ s@\\([\w]+)@<i>$1</i>@g;

    return $text;
}

sub add_OID {
    my $self = shift (@_);
    my ($doc_obj, $id, $segment_number) = @_;
    
    if ( $self->{'key'} eq "default") {
	$self->SUPER::add_OID(@_);
#	$doc_obj->set_OID("$id\_$segment_number");
    } else {
	$doc_obj->set_OID($self->{'key'});
    }
}

1;


