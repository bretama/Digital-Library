#!/usr/bin/perl -w

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/bin/script");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
    unshift (@INC, "$ENV{'GSDLHOME'}/collect/lld/perllib");
}

use util;

use IncrementalBuildUtils; # Include John's incremental building API

# Ensure the collection specific binaries are on the search path
my $path_separator = ":";
$ENV{'PATH'} = &util::filename_cat($ENV{'GSDLHOME'}, "bin", $ENV{'GSDLOS'}) .
$path_separator . &util::filename_cat($ENV{'GSDLHOME'}, "bin", "script") .
$path_separator . $ENV{'PATH'};

if(!$ARGV[0] || !$ARGV[1]) {
  print STDERR "Usage: removedocument <collection> <oid>\n";
  exit;
}

my $collection = $ARGV[0];
my $oid = $ARGV[1];

&IncrementalBuildUtils::deleteDocument($collection, "gdbm", $oid);

exit;
