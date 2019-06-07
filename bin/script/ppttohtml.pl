eval 'exec perl -x -- $0 $@'
    if 0;
#! perl
# line 6

sub usage() {
    print "$0 <input.ppt> <output.html>\n";
}


if (@ARGV != 2) {
    usage();
    exit(1);
}
my $input_ppt=shift;
my $output_html=shift;

# try to find ppthtml binary in GSDLHOME
my $ppthtml_binary="ppthtml";
my $GSDLOS=$ENV{'GSDLOS'};
my $GSDLHOME=$ENV{'GSDLHOME'};
if ($GSDLOS =~ /^windows$/i) {
    $ppthtml_binary.=".exe";
}

# assume it is on the path if running under windows, in case GSDLHOME
# has a space
if ($GSDLOS !~ /windows/i && -x "$GSDLHOME/bin/$GSDLOS/$ppthtml_binary") {
    $ppthtml_binary="$GSDLHOME/bin/$GSDLOS/$ppthtml_binary";
}

if (! -r $input_ppt) {
    print STDERR "Unable to read file `$input_ppt'\n";
    exit (1);
}

my $return_value=
    system("$ppthtml_binary \"$input_ppt\" > \"$output_html\"");

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

# if we are using the file name as the title, then get rid of it,
# as HTMLPlug will use the first 100 chars instead if there's no title.
$html =~ s@<title>.*?\.ppt</title>@<title></title>@i;

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

