#! /usr/bin/perl -w

# extract_text.pl extracts the text from macro files, install scripts
# etc. for translation.

# output is currently to a tab separated list, suitable for importing into
# excel.


BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
}

my $installsh = "$ENV{'GSDLHOME'}/Install.sh";
my $macrosdir = "$ENV{'GSDLHOME'}/macros";
my $installshield = 'C:/My Installations/is_gsdl_cdrom/String Tables/0009-English/value.shl';

my $texthash = {};

# first extract all the itextn variables from Install.sh
open (INSTALLSH, $installsh) || die;
undef $/;
my $file = <INSTALLSH>;
$/ = "\n";
close INSTALLSH;

$texthash->{'install_sh'} = {};
while ($file =~ s/^(itext\d+)=\"(.*?)(?<!\\)\"//sm) {
    my $key = $1;
    my $value = $2;
    $value =~ s/\n/\\n/gs;
    $value =~ s/\t/\\t/gs;
    if (defined ($texthash->{'install_sh'}->{$key})) {
	print STDERR "ERROR: $1 already defined\n";
    }
    $texthash->{'install_sh'}->{$key} = $value;
}


# now grab the text from the macro files
$texthash->{'macros'} = {};

# english.dm
&grab_macros("$macrosdir/english.dm");
# english2.dm
&grab_macros("$macrosdir/english2.dm");


# text from installshield installation
$texthash->{'installshield'} = {};
open (ISHIELD, $installshield) || die;
my $line = "";
my $textserver = {};
while (defined ($line = <ISHIELD>)) {
    next unless ($line =~ /\w/);
    last if $line =~ /^\[General\]/;
    next if $line =~ /^\[/;

    $line =~ s/\n/\\n/gs;
    $line =~ s/\t/\\t/gs;

    if ($line =~ /^(TEXT_SERVERTXT_\d+)=(.*)$/) {
	$textserver->{$1} = $2;
    } else {
	$line =~ /^([^=]+)=(.*)$/;
	$texthash->{'installshield'}->{$1} = $2;
    }
}
close ISHIELD;
my $tserver = "";
foreach my $stext (sort keys %{$textserver}) {
    $tserver .= $textserver->{$stext};
}
$texthash->{'installshield'}->{'TEXT_SERVERTXT'} = $tserver;

# print out the result
foreach my $type (keys (%$texthash)) {
    print STDOUT "type:\t$type\n";
    foreach my $key (sort keys (%{$texthash->{$type}})) {
	print STDOUT "$key\t$texthash->{$type}->{$key}\n";
    }
}

sub grab_macros {
    my ($filename) = @_;

    my $line = "";
    my $pack = "Global";
    my $macroname = "";
    my $macrovalue = "";
    open (FILE, $filename) || die;
    while (defined ($line = <FILE>)) {
	if ($line =~ /^package (\w+)/) {
	    $pack = $1;
	    $macroname = "";
	    $macrovalue = "";
	    next;
	}

	if ($line =~ /^_([^_\s]+)_\s*(?:\[[^\]]*\])?\s*\{(.*)$/s) {
	    die "ERROR 1\n" if ($macroname ne "" || $macrovalue ne "");
	    $macroname = $1;
	    $macrovalue = $2 if defined $2;
	    if ($macrovalue =~ s/^(.*?)(?<!\\)\}/$1/) {
		&addmacro($pack, \$macroname, \$macrovalue);
	    }		
	} elsif ($macroname ne "") {
	    if ($line =~ /^(.*?)(?<!\\)\}/) {
		$macrovalue .= $1 if defined $1;
		&addmacro($pack, \$macroname, \$macrovalue);
	    } else {
		$macrovalue .= $line;
	    }
	} elsif ($line =~ /^\#\# \"([^\"]+)\" \#\# \w+ \#\# (\w+) \#\#/) {
	    my $imagename = "image:$2";
	    my $imagetext = $1;
	    &addmacro($pack, \$imagename, \$imagetext);
	}
    }
    close FILE;
}

sub addmacro {
    my ($pack, $nameref, $valref) = @_;

    if ($$nameref !~ /^(httpicon|width|height)/) {

	my $name = "$pack:$$nameref";
	
	if (defined ($texthash->{'macros'}->{$name})) {
	    print STDERR "ERROR: $name already defined\n";	
	}


	$$valref =~ s/\n/\\n/gs;
	$$valref =~ s/\t/\\t/gs;

	$texthash->{'macros'}->{$name} = $$valref;
    }

    else {
#	print STDERR "ignoring $$nameref\n";
    }

    $$nameref = "";
    $$valref = "";
}
