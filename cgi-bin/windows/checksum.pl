#!C:\Users\brhane\Greenstone\bin\windows\perl\bin\perl.exe -w

use Digest::MD5;

use gsdlCGI;

sub load_gsdl_utils
{
    my ($gsdlhome) = @_;

    require "$gsdlhome/perllib/util.pm";
}

sub generate_checksum
{
    my ($filename,$gsdl_cgi) = @_;

    if (!defined $filename || ($filename =~ m/^\s*$/)) {
	$gsdl_cgi->generate_error("No filename given.\n");
	return;
    }

    if (!open(FILE, $filename)) {
	$gsdl_cgi->generate_error("Cannot open $filename: $!\n");
	return;
    }

    binmode(FILE);

    my $ctx = Digest::MD5->new;    
    $ctx->addfile(*FILE);    
    my $digest = $ctx->hexdigest;

    return $digest;
}


sub main
{
    #my $gsdl_cgi = new gsdlCGI("+cmdline"); # doesn't work anymore
    my $gsdl_cgi = new gsdlCGI();

    $gsdl_cgi->setup_gsdl();
    my $gsdlhome = $ENV{'GSDLHOME'};

    $gsdl_cgi->checked_chdir($gsdlhome);

    # filename is now local to the current dir after checked_dir
    my $filename = $gsdl_cgi->clean_param("filename");

    my $checksum = generate_checksum($filename,$gsdl_cgi);


    print STDOUT "Content-type:text/plain\n\n";
    print STDOUT "$checksum (MD5)\n";
}

&main();

