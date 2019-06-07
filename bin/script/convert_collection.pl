#! /usr/bin/perl -w

# converts an old style humanity collection which uses an index.txt file to
# use a single metadata.xml file instead


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use util;
use cfgread;

my $collection = $ARGV[0];
my $collectdir = &util::filename_cat($ENV{'GSDLHOME'}, "collect", $collection);
my $importdir = &util::filename_cat($collectdir, "import");

die unless -d $importdir;

# new import structure will be created in "import.new" directory
my $importnewdir = $importdir . ".new";
`mkdir $importnewdir`;


# read in index.txt file and generate metadata.xml, in the process
# converting the html files and copying them across to the import.new
# directory

my $metadata_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n";
$metadata_xml .= "<!DOCTYPE DirectoryMetadata SYSTEM " .
    "\"http://greenstone.org/dtd/DirectoryMetadata/1.0/DirectoryMetadata.dtd\">\n";
$metadata_xml .= "<DirectoryMetadata>\n\n";

my $index_txt = &util::filename_cat($importdir, "index.txt");

open (INDEXTXT, $index_txt) || die;

my $line = [];
my @fields = ();
my $count = 0;
while (defined ($line = cfgread::read_cfg_line("main::INDEXTXT"))) {

#    last if $count > 10;

    if ($line->[0] eq "key:") {
	shift @$line;
	@fields = @$line;
    } else {
	
	my $jobnumber = shift @$line;
	&new_document($jobnumber);
	$count ++;

	my $i = 0;
	for ($i = 0; $i < scalar(@$line); $i++) {
	    if ($line->[$i] =~ /^<([^>]+)>(.*)$/) {
		&set_metadata($1, $2);
	    } else {
		if (defined ($fields[$i])) {
		    &set_metadata($fields[$i], $line->[$i]);
		} else {
		    print STDERR "error 1\n";
		}
	    }
	}

	$metadata_xml .= "    </Description>\n";
	$metadata_xml .= "  </FileSet>\n\n";
    }
}
close INDEXTXT;

$metadata_xml .= "</DirectoryMetadata>\n";

my $metafile = &util::filename_cat($importnewdir, "metadata.xml");
open (META, ">$metafile") || die;
print META $metadata_xml;
close META;


sub new_document {
    my ($jobnumber) = @_;

    print STDERR "creating new document ($jobnumber)\n";

    my $docdir = &util::filename_cat($importdir, $jobnumber);
    die unless -d $docdir;

    # copy whole directory across to import.new
    $jobnumber =~ s/^.*?\///;
    my $newdocdir = &util::filename_cat($importnewdir, $jobnumber);
    die if -e $newdocdir;
    `cp -r $docdir $newdocdir`;

    # convert the htm file to use the new syntax
    my $htmfile = &util::filename_cat($newdocdir, "$jobnumber.htm");
    die unless -e $htmfile;
    `convert_toc.pl < $htmfile > $htmfile.new`;
    `mv $htmfile.new $htmfile`;

    # update metadata.xml
    $metadata_xml .= "  <FileSet>\n";
    $metadata_xml .= "    <FileName>$jobnumber</FileName>\n";
    $metadata_xml .= "    <Description>\n";
}

sub set_metadata {
    my ($key, $value) = @_;

    $metadata_xml .= "      <Metadata name=\"$key\" mode=\"accumulate\">$value</Metadata>\n";
}
