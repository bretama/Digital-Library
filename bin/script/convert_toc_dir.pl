#! /usr/bin/perl -w

# run convert_toc.pl on any html files found in the directory passed in on
# the command line (or any subdirs).

die "\$GSDLOS not set !\n" if (!defined $ENV{GSDLOS});
my ($move, $separator);
if ($ENV{GSDLOS} eq "windows") {
  $move = "move";
  $separator = "\\";
} else {
  $move = "mv";
  $separator = "/";
}

&recurse($ARGV[0]);

sub recurse {
    my ($dir) = @_;

    if (!-d $dir) {
	print STDERR "ERROR: $dir isn't a directory\n";
	return;
    }

    opendir (DIR, $dir) || die;
    my @files = readdir DIR;
    closedir DIR;

    foreach my $file (@files) {
	next if $file =~ /^\.\.?$/;
	my $fullpath = "$dir$separator$file";
	if (-d $fullpath) {
	    &recurse($fullpath);
	} elsif ($file =~ /\.html?$/i) {
	    print STDERR "converting $fullpath\n";
	    `convert_toc.pl $fullpath $fullpath.new`;
	    `$move $fullpath.new $fullpath`;
	}
    }
}
