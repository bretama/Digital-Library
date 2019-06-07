###########################################################################
#
# LaTeXPlugin.pm
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Written by John McPherson
# Copyright (C) 2004 New Zealand Digital Library Project
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
###########################################################################

# todo:
#  \includegraphics
#  parse/remove tex \if ... macros

package LaTeXPlugin;

# System complains about $arguments if the strict is set
use strict;
no strict 'refs'; # so we can print to a handle named by a variable

# greenstone packages
use ReadTextFile;
use MetadataRead;
use unicode;
use util;

my $arguments =
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() } ];

my $options = { 'name'     => "LaTeXPlugin",
		'desc'     => "{LaTeXPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub BEGIN {
    @LaTeXPlugin::ISA = ('MetadataRead', 'ReadTextFile');
}

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new ReadTextFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'aux_files'} = {};
    $self->{'dir_num'} = 0;
    $self->{'file_num'} = 0;
    return bless $self, $class;
}


sub get_default_process_exp {
    my $self = shift (@_);
    return q^\.tex$^;
}

sub get_default_block_exp {
    # assume any .eps files are part of the latex stuff
    return '\.(?:eps)$';
}


sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;

    my $start=substr($$textref, 0, 200); # first 200 bytes

    if ($start !~ m~\\ (?:documentclass | documentstyle | input | section 
			| chapter | contents | begin) ~x) {
	# this doesn't look like latex...
	return undef;
    }
    my $outhandle = $self->{'outhandle'};

    my $cursection = $doc_obj->get_top_section();

    ###### clean up text ######
    $$textref =~ s/\r$//mg;  # remove dos ^M
    $$textref =~ s/%.*$//mg; # remove comments

    # convert to utf-8 if not already - assume non ascii => iso-8859-1/latin

    $$textref =~ s@(?<=[[:ascii:]])\xA0+@\xc2\xa0@g; # latin nonbreaking space
    # check that both sides are ascii, so we don't screw up utf-8 chars
    $$textref =~ s@ (?<=[[:ascii:]])([\x80-\xff])(?=[[:ascii:]]) @
	unicode::ascii2utf8($1) @egx; # takes "extended ascii" (ie latin)


    ###### find metadata ######

    ## FileFormat metadata ##
    $doc_obj->add_metadata($cursection, "FileFormat", "LaTeX");

    ### title metadata ###
    $$textref =~ m@\\title\s*{(.*?)}@s;
    my $title = $1;
    if (!$title) {
	# no title tag. look for a chapter/section heading
	$$textref =~ m@\\(?:chapter|section)\s*{(.*?)}@s; # will get 1st match
	$title = $1;
    }
    if (!$title) {
	# no chapter/section heading tags either... use filename
	$title = $file;
	$title =~ s/\.tex$//i;
	$title =~ s/[-_.]/ /g; # turn punctuation into spaces
    }
    if ($title) {
	$title =~ s@\\\\@ @g; # embedded newlines
	$title = $self->process_latex($title); # no "-html" for title eg in browser
	$doc_obj->add_utf8_metadata($cursection, "Title", $title);
    }

    ### creator/individual author metadata ###
    $$textref =~ m@\\author\s*{((?:{.*?}|.*?)+)}\s*$@sm;
    my $authors=$1;
    if ($authors) {
	# take care of "et al."...
	$authors =~ s/(\s+et\.?\s+al\.?)\s*$//;
	my $etal=$1;
	$etal="" if (!defined ($etal));

	my @authorlist=parse_authors($self, $authors);

	foreach my $author (@authorlist) {
	    # Add each name to set of Authors
	    $doc_obj->add_utf8_metadata ($cursection, "Author", $author);
	}

	# Only want at most one "and" in the Creator field
	my $creator_str="";
	if (scalar(@authorlist) > 2) {
	    my $lastauthor=pop @authorlist;
	    $creator_str=join(', ', @authorlist);
	    $creator_str.=" and $lastauthor";
	} else { # 1 or 2 authors...
	    $creator_str=join(" and ",@authorlist);
	}
	$creator_str.=$etal; # if there was "et al."
    	$doc_obj->add_utf8_metadata($cursection, "Creator", $creator_str);
    }
    ### end of author metadata ###

    ###### process latex for the main text ######
    $$textref =~ s/^.*?\\begin\{document}//s;
    $$textref =~ s/\\end\{document}.*?$//s;
    $$textref = $self->process_latex("-html",$$textref);
    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}


# returns a list of author names
sub parse_authors {
    my $self=shift;
    my $authors=shift;

    my $outhandle=$self->{'outhandle'};

    $authors =~ s/\n/ /g; # remove newlines
	
    # some people do this for affiliation footnote/dagger
    $authors =~ s@\$.*?\$@@g; # remove maths from author :(

    # und here for german language...
    # don't use brackets in pattern, else the matched bit becomes
    # an element in the list!
    my @authorlist = split(/\s+and\s+|\s+und\s+/, $authors);
    my @formattedlist = ();
    foreach my $author (@authorlist) {
	$author =~ s/\s*$//; 
	$author =~ s/^\s*//; 
	# Reformat and add author name
	next if $author=~ /^\s*$/;

	# names are "First von Last", "von Last, First"
	# or "von Last, Jr, First". See the "BibTeXing" manual, page 16
	my $first="";
	my $vonlast="";
	my $jr="";
	    
	if ($author =~ /,/) {
	    my @parts=split(/,\s*/, $author);
	    $first = pop @parts;
	    if (scalar(@parts) == 2) {
		$jr = pop @parts;
	    }
	    $vonlast=shift @parts;
	    if (scalar(@parts) > 0) {
		print $outhandle $self->{'plugin_type'} .
		    ": couldn't parse name $author\n";
		# but we continue anyway...
	    }
	} else { # First von Last
	    my @words = split(/ /, $author);
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
		print $outhandle "BibTexPlug: couldn't parse surname $vonlast\n";
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
	$wholename =~ s/ $//; $wholename =~ s/\s+/ /g;
#	my $fullname = "$last";
#	$fullname .= " $jr" if ($jr);
#	$fullname .= ", $first";
#	$fullname .= " $von" if ($von);
	push (@formattedlist, $wholename);
    }
    return @formattedlist;
}


## following functions based on bibtex plugin ##
# not actually used at the moment, but might be useful in future?
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


# If you want basic html formatting (eg \emph -> <em>, \bf, etc), give "-html"
# as the first argument to this function.
#
# Convert accented characters, remove { }, interprete some commands....
# Note!! This is not comprehensive! Also assumes Latin -> Unicode!

# Also, it sucks quite a bit for complicated/nested commands since it doesn't
# match { with the corresponding }, only the nearest }

sub process_latex {
    my $self=shift;
    my $text=shift;

    my $outhandle=$self->{'outhandle'};

    my $html_markup=0;
    if ($text =~ /^\-html/) {
	$html_markup=1;
	$text=shift;
    }

    if (! $text) {
	return $text;
    }
    # escape html-sensitive characters
    $text =~ s@&@&amp;@g;
    $text =~ s@<@&lt;@g;
    $text =~ s@>@&gt;@g;
 
    # do this before accents, since \= means something different in tabbing
    # also \> is a tab stop too, and \\ is newline
    sub do_tabbing {
	my $tabbing=shift;
	$tabbing =~ s!^.*\\kill\s*$!!mg; # \kill sets tab stops, kills line
	$tabbing =~ s~\\(?:=|&gt;)~\xc2\xa0~g; # replace with nbsp
	$tabbing =~ s~[\\][\\](?:\[.*?\])?\s*$~<br/>~mg;
	return "<br/>" . $tabbing . "<br/>\n";
    }
    $text =~ s@\\begin\{tabbing}(.*?)\\end\{tabbing}@do_tabbing($1)@ges;
    sub do_tabular {
	my $tabular=shift;
	$tabular =~ s~(?<!\\)\s*&amp;\s*~</td><td>~g;
	$tabular =~ s~[\\][\\]\s*~</td></tr>\n <tr><td>~g;
	$tabular =~ s~\\hline~~g; # for now...
	$tabular =~ s~<td>\s*\\multicolumn\{(\d+)}\{.*?}~<td colspan="$1">~g;
	return "<table border=\"1\">\n <tr><td>"
	    . $tabular . "</td></tr></table>\n";
    }
    $text =~ s@\\begin\{tabular}(?:\[.*?\])?{.*?}(.*?)\\end\{tabular} @
    		do_tabular($1)  @xges;

    $text =~ s@[\\][\\]\s*\n@ @g; # fold lines ending with \\

    # process maths mode before accents... things like \, mean different!
    # maths mode
    $text =~ s@\$\$(.*?)\$\$ 
	@ process_latex_math($html_markup,$1)
	@xsge; # multi-line maths: $$ .... $$

    $text =~ s@([^\\])\$(.*?[^\\])\$
	@$1.process_latex_math($html_markup,$2)@xsge;


    # is this an amstext environment, or just custom for that input file?
    $text =~ s@\\begin\{(algorithm)}(.*?)\\end\{\1}@remove_equals($2)@ges;

    # convert latex-style accented characters.
    $self->latex_accents_to_utf8(\$text);

    # replace quotes with utf-8

    $text =~ s/``/\xe2\xc0\x9c/g; # Latex-specific, left-dbl quote (&ldquo;)
    $text =~ s/''/\xe2\xc0\x9d/g; # Latex-specific, right-dbl quote (&rdquo;)
    $text =~ s/`/\xe2\xc0\x98/g; # single left quote
    $text =~ s/'/\xe2\xc0\x99/g; # single right quote

    ###### remove/replace latex commands ######
    ### commands that expand to something that gets displayed ###
    $text =~ s~\\ldots~&hellip;~g;
    $text =~ s~\\hrule~<hr/>\n~g;
    $text =~ s~\\maketitle~ ~;
    ### space commands ###
    $text =~ s~\\[vh]skip\s+\S+~~g;
    $text =~ s~\\vspace\*?{.*?}~<div>&nbsp;</div>~g; # vertical space
    $text =~ s~\\\w+skip~ ~g; # \smallskip \medskip \bigskip \baselineskip etc
    $text =~ s~\\noindent\b~~g;
    # newpage, etc
    $text =~ s~\\(?:clearemptydoublepage|newpage)~~g;
    ### counters, contents, environments, labels, etc ###
    $text =~ s~\\(?:addcontentsline){.*?}\{.*?}\{.*}~~g;
    $text =~ s~\s*\\begin\{itemize}\s*~\n<ul>\n~g;
    $text =~ s~\s*\\end\{itemize}\s*~</li></ul>\n~g;
    $text =~ s~\s*\\begin\{enumerate}\s*~<ol>\n~g;
    $text =~ s~\s*\\end\{enumerate}\s*~</li></ol>\n~g;
    if ($text =~ s~\s*\\item~</li>\n<li>~g) {
	# (count for first list item)
	$text =~ s~<([ou])l>\s*</li>\s*~<$1l>~g;
    }
    $text =~ s~\\(?:label|begin|end){.*?}\s*\n?~ ~g; # remove tag and contents
    $text =~ s~\\(?:tableofcontents|listoffigures)~ ~g;
    ### font sizes/styles ###
    $text =~ s~\\(?:tiny|small|footnotesize|normalsize|large|Large|huge|Huge)\b~~g;

    if ($html_markup) {
	$text =~ s~\\section\*?{([^\}]+)}\s*\n?~<H1>$1</H1>\n~g;
	$text =~ s~\\subsection\*?{(.*?)}\s*\n?~<H2>$1</H2>\n~g;
	$text =~ s~{\\tt\s*(.*?)}~<tt>$1</tt>~g;
	$text =~ s~\\(?:texttt|tt|ttseries)\s*{(.*?)}~<tt>$1</tt>~g;
	$text =~ s~\\emph\{(.*?)}~<em>$1</em>~g;
	$text =~ s~{\\(?:em|it)\s*(.*?)}~<em>$1</em>~g;
	$text =~ s~{\\(?:bf|bfseries)\s*(.*?)}~<strong>$1</strong>~g;
	$text =~ s~\\(?:textbf|bf|bfseries)\s*{(.*?)}~<strong>$1</strong>~g;
    } else {
	# remove tags for text-only
	$text =~ s~\\(?:textbf|bf|bfseries|em|emph|tt|rm|texttt)\b~ ~g;
    }
    $text =~ s ~ {\\sc\s+(.*?)} ~
		{<span style="font-variant:\ small-caps">$1</span>} ~gx;
    # ignore these font tags (if there are any left)
    # sf is sans-serif
    $text =~ s~\\(?:mdseries|textmd|bfseries|textbf|sffamily|sf|sc)\b~ ~;
    #### end font-related stuff ####

    ### remove all other commands with optional arguments... ###
    # don't remove commands without { }....
    # $text =~ s~\\\w+(\[.*?\])?\s*~~g;
    # $text =~ s~\\noopsort{[^}]+\}~~g;
    # verbatim
    $text =~ s~\\verb(.)(.*?)\1~verb_text($1)~ge;
    # remove tags, keep contents for \tag[optional]{contents}
    while ($text =~ s~\\\w+(\[.*?\])?{([^}]+)}~$2 ~g) {;} # all other commands
    
    # remove latex groupings { } (but not \{ or \} )
    while ($text =~ s/([^\\])[\{\}]/$1/g) {;} # needed for "...}{..."
    $text =~ s/^\{//; # remove { if first char

    # latex characters
    # spaces - nobr space (~), opt break (\-), append ("#" - bibtex only)
    $text =~ s/([^\\])~+/$1 /g; # non-breaking space  "~"
    # optional break "\-"
    if ($text =~ m/[^&]\#/) { # concat macros (bibtex) but not HTML codes
	# the non-macro bits have quotes around them - we just remove quotes
	# XXX bibtex and latex differ here (for the '#' char)...
	$text =~ s/([^&])[\"\#]/$1/g;
    }
    # dashes. Convert (m|n)-dash into single dash for html.
    $text =~ s~\-\-+~\-~g;

    # quoted { } chars
    $text =~ s~\\\{~{~g;
    $text =~ s~\\}~}~g;

    # spaces
    $text =~ s~\\ ~ ~g;

    # finally to protect against macro language...
    # greenstone-specific
    $text =~ s~\[~&\#91;~g;
    $text =~ s~\]~&\#93;~g;
    $text =~ s~(?<!\\)([\\_])~\\$1~g;

    if ($html_markup) {
	$text =~ s~\n{2,}~\n</p>\n<p>~g;
	return "<p>$text</p>";
    }

    return $text;
}

# only used by process_latex for \verb....
sub verb_text {
    my $verbatim=shift;
    $verbatim =~ s/([{}_])/\\$1/g;
    return $verbatim;
}
# only used by process_latex_math
# returns a unicode char if applicable, otherwise ascii
sub math_fraction {
    my $num=$1;
    my $denom=$2;

    if ($num==1 && $denom==2) {return chr(0xc2).chr(0xbd)}
    if ($num==1 && $denom==4) {return chr(0xc2).chr(0xbc)}
    if ($num==3 && $denom==4) {return chr(0xc2).chr(0xbe)}
    return "$num/$denom";
}

sub process_latex_math {

    my $text = pop; # if given one or two args, this is the last one...
    my $html_markup=pop; # if given two args, this is the first one else undef

    $text =~ s~\\,~ ~g; # forces a space?
    $text =~ s~\\infty~infinity~g;             # or unicode 0x221E...

# use this one when more things can read 3-byte utf8 values like this!
#    $text =~ s~\\cup\b~\xe2\xc8\xaa~g; # union operator - unicode 0x222a
    $text =~ s~\\cup\b~ U ~g;

    $text =~ s~\\frac\s*{(.+?)}\{(.+?)}~math_fraction($1,$2)~ge;

    if ($html_markup) {
	$text =~ s~\^\{(.*?)}~<sup>$1</sup>~g;  # a^b superscript
	$text =~ s~\^([^\{])~<sup>$1</sup>~g;
	$text =~ s~\_\{(.*?)}~<sub>$1</sub>~g;  # a_b subscript
	$text =~ s~\_([^\{])~<sub>$1</sub>~g;
	
	$text =~ s~\\ldots~&hellip;~g;         # use html named entity for now

	# put all other command names in italics for now
	$text =~ s~\\([\w]+)~<i>$1</i> ~g;
    }

    # special cases, for some input files
    if ($text =~ m~^\\\w+$~) {
	$text="{" . $text . "}";
    }

    return $text;
}



sub latex_accents_to_utf8 {

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
	 '"i' => chr(0xc3).chr(0xaf),
	 '"I' => chr(0xc3).chr(0x8f),
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
	 'u z' => chr(0xc5).chr(0xbe), # !!! no such char, but common mistake
	 'u Z' => chr(0xc5).chr(0xbd), # used instead of v Z !!!
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

         # other special chars
         'ss' => chr(0xc3).chr(0x9f), # german ss/szlig/sharp s
         'aa' =>,chr(0xc3).chr(0xa5), # scandanavian/latin a with ring
	 );

    my $self=shift;
    my $textref=shift;

    my $outhandle=$self->{'outhandle'};
    my $text=$$textref;
    
    # remove space (if any) between \ and letter to accent (eg {\' a})
    $text =~ s!(\\[`'="^~\.])\s(\w)\b!$1$2!g;   # for emacs indenting... `]);

    # remove {} around a single character (eg \'{e})
    $text =~ s!(\\[`'="^~\.]){(\w)}!{$1$2}!g;  # for emacs indenting... `]);

    ## only in bibtex... not in latex proper?!
    ### \, is another way of doing cedilla \c
    ##$text =~ s~\\,(.)~\\c $1~g;

    # remove {} around a single character for special 1 letter commands -
    # need to insert a space. Eg \v{s}  ->  {\v s}
    $text =~ s~(\\[uvcH]){(\w)}~{$1 $2}~g;

    # only do if the text contains a '\' character. 
    if ($text =~ m|\\|) {
	# "normal" accents - ie non-alpha latex tag
	# xxx used to have ([\w]\b)@ (for word boundary)
	while ($text =~ m/\\([`'="^~\.])([\w])/) {      # for emacs `])){
	    my $tex="$1$2"; my $char="$2";
	    my $replacement=$utf8_chars{$tex};
	    if (!defined($replacement)) {
		$text =~ m~(.{20}\\\Q$tex\E.{20})~s;
		print $outhandle . $self->{'plugin_type'} .
		    ": Warning: unknown latex accent \"$tex\""
		    . " in \"$1\"\n";
		$replacement=$char;
	    }
	    $text =~ s/\\\Q$tex/$replacement/g;
	}

        # where the following letter matters (eg "sm\o rrebr\o d", \ss{})
        # only do the change if immediately followed by a space, }, {, or \
	# one letter accents ( + ss / aa)
        while ($text =~ m~\\([DdhiLlOoTt]|ss|aa)[{}\s\"\\]~) {
	    my $tex=$1;
	    my $replacement=$special_utf8_chars{$tex};
	    if (!defined($replacement)) {
		$text =~ m~(.{20}\\\Q$tex\E.{20})~s;
		print $outhandle $self->{'plugin_type'} .
		    ": Warning: unknown latex accent \"$tex\""
		    . " in \"$1\"\n";
		$replacement=$tex;
	    }
	    ($text =~ s/{\\$tex}/$replacement/g) or
		$text =~ s/\\$tex([{}\s\"\\])/$replacement$1/g;

	}

	# one letter latex accent commands that affect following letter
        while ($text =~ m~\\([uvcH]) ([\w])~) {
          my $tex="$1 $2"; my $char="$2";
          my $replacement=$special_utf8_chars{$tex};
          if (!defined($replacement)) {
	      $text =~ m~(.{20}\\\Q$tex\E.{20})~s;
	      print  $outhandle $self->{'plugin_type'} .
		  ": Warning: unknown latex accent \"$tex\""
		  . " in \"$1\"\n";
	      $replacement=$char;
	  }
          $text =~ s/\\$tex/$replacement/g;
        }
    }
    $textref=\$text;
}


# modules must return true
1;
