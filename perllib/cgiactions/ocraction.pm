package ocraction;

use strict;

use cgiactions::baseaction;

use dbutil;
use ghtml;


BEGIN {
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");
    require XML::Rules;
}


@ocraction::ISA = ('baseaction');

my $action_table =
{ 
    "preformOcr"     => { 'compulsory-args' => [ "d", "imagename" ],
			         'optional-args'   => [] },
	"setText"		 =>	{ 'compulsory-args' => [ "d", "newtext" ],
					 'optional-args'   => [] }
};

sub new 
{
    my $class = shift (@_);
    my ($gsdl_cgi,$iis6_mode) = @_;

    my $self = new baseaction($action_table,$gsdl_cgi,$iis6_mode);

    return bless $self, $class;
}

sub preformOcr
{
	my $self = shift @_;

	my $collection = $self->{'collect'};
	my $site = $self->{'site'};
	my $gsdl_cgi  = $self->{'gsdl_cgi'};
	
	my $docId = $self->{'d'};
	my $imagename = $self->{'imagename'};

	# Change URL style '/' to Windows style
	$imagename =~ s/\//\\/g;

	my $indexDir = "C:\\Users\\Bryce\\Desktop\\Research\\greenstone3-svn-bryce64\\web\\sites\\localsite\\collect\\jonesmin\\";
	##my $hashDir = $archivesDir . substr($docId,0,8) . ".dir\\";

	my $imageFile = $indexDir . $imagename;

	my $outputFile = $ENV{'TEMP'} . "\\out";
	my $cmd = "tesseract $imageFile $outputFile";
	## print STDERR "\n\n CMD=\n$cmd \n\n";

	my $status = system($cmd);
	if($status != 0) { print STDERR "\n\n Fail to run \n $cmd \n $! \n\n"; }
	if (open (FILE, "<$outputFile" . ".txt")==0) {
		$gsdl_cgi->generate_error("Unable to open file containing OCR'd text:<br> $!");
		return;
	}
		
	my $result = "";
	my $line;
	while(defined ($line=<FILE>)) {
		$result .= $line;
	}
	close FILE;
	unlink($outputFile . ".txt");
	
	$gsdl_cgi->generate_ok_message($result);
}

sub setText
{
	my $self = shift @_;
	my $collection = $self->{'collect'};
	my $site = $self->{'site'};
	my $docId = $self->{'d'};
	my $newtext = $self->{'newtext'};
}

1;