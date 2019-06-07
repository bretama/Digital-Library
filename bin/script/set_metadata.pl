#!/usr/bin/perl -w

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/bin/script");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use doc;
use strict;
# Include John's incremental building API
use IncrementalBuildUtils;
use IncrementalDocument;

if (!$ARGV[0] || !$ARGV[1] || !$ARGV[2] || !$ARGV[3] || !$ARGV[4] || ($ARGV[3] eq "REPLACE" && !$ARGV[5])) {
  print STDERR "Usage: set_metadata <collection> <oid> <metadata_field> (REPLACE <old_value> <new_value> | (ADD|REMOVE) <value>)\n";
  print STDERR "[you tried: set_metadata ";
  foreach my $arg (@$ARGV) {
    print STDERR $arg . " ";
  }
  print STDERR "]\n";
  exit;
}

my $collection = $ARGV[0];
my $oid        = $ARGV[1];
my $field      = $ARGV[2];
my $action     = $ARGV[3];
my $a_value    = $ARGV[4];
my $b_value    = "";
if ($action eq "REPLACE")
{
  $b_value     = $ARGV[5];
}

# We pass a 1 to force the indexes to be updated too.
if ($action eq "ADD")
{
  &IncrementalBuildUtils::setDocumentMetadata($collection, "gdbm", $oid, $field, "", $a_value, 1);
}
elsif ($action eq "REMOVE")
{
  &IncrementalBuildUtils::setDocumentMetadata($collection, "gdbm", $oid, $field, $a_value, "", 1);
}
elsif ($action eq "REPLACE")
{
  &IncrementalBuildUtils::setDocumentMetadata($collection, "gdbm", $oid, $field, $a_value, $b_value, 1);
}

exit;
