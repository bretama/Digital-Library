eval 'exec perl -x -- $0 $@'
    if 0;
#! perl
# line 6

sub usage() {
    print "$0 <input.xls> <output.html>\n";
}


if (@ARGV != 2) {
    usage();
    exit(1);
}
my $input_xls=shift;
my $output_html=shift;

# try to find xlhtml binary in GSDLHOME
my $xlhtml_binary="xlhtml";
my $GSDLOS=$ENV{'GSDLOS'};
my $GSDLHOME=$ENV{'GSDLHOME'};
if ($GSDLOS =~ /^windows/i) {
    $xlhtml_binary.=".exe";
}

# Trouble happens if there are spaces in GSDLHOME. Assume that on windows
# the program is found in the path.
if ($GSDLOS !~ /windows/i && -x "$GSDLHOME/bin/$GSDLOS/$xlhtml_binary") {
    $xlhtml_binary="$GSDLHOME/bin/$GSDLOS/$xlhtml_binary";
}

if (! -r $input_xls) {
    print STDERR "Unable to read file `$input_xls'\n";
    exit (1);
}

my $return_value=
    system("$xlhtml_binary \"$input_xls\" > \"$output_html\"");

if ($return_value != 0) {
    exit (1);
}

# Ok, we made an html file. Check to see if it has any content, and remove
# the little nag link at the the bottom.
my $html="";
open (HTML, "$output_html") || die "Can't read file:$!";
$html=join('', <HTML>);
close HTML;

$html =~ s@<hr><FONT SIZE=-1>Created with.*\n</BODY></HTML>$@</BODY></HTML>@s;

# xlHtml uses the filename as the title.
# HTMLPlug will use the first 100 chars instead if there's no title.
# Don't know if that's a good idea with a spreadsheet, though...
$html =~ s@<title>.*?\.xls</title>@<title></title>@i;

my $tmp=$html;
$tmp =~ s/^.*?<BODY>//ms;
$tmp =~ s/(&nbsp;)|\s//gims;
if ($tmp !~ m/(>[^<]+<)/) {
    print STDERR "No text found in extracted html file!\n";
    exit(1);
}
open (NEWHTML, ">$output_html") || die "Can't create file:$!";
print NEWHTML $html;
close NEWHTML;
exit (0);

