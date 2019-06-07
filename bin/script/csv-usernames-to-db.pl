#!/usr/bin/perl -w

###########################################################################
#
# csv-usernames-to-db.pl --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################


# This program converts username details (password, group information etc)
# into the format used by Greenstone, and store them in etc/users.gdb 

package cu2db;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
#    unshift (@INC, "$ENV{'GSDLHOME'}/perllib/cpan/perl-5.8");

}

use strict;
no strict 'refs'; # allow filehandles to be variables and vice versa
no strict 'subs'; # allow barewords (eg STDERR) as function arguments

use FileHandle;
use util;
use gsprintf 'gsprintf';
use printusage;
use parse2;


my $arguments = 
    [ { 'name' => "fieldseparator",
	'desc' => "{cu2db.field-separator}",
	'type' => "string",
	'deft' => ",",
	'reqd' => "no" },
      { 'name' => "alreadyencrypted",
	'desc' => "{cu2db.already-encrypted}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name'  => "verbosity",
	'desc'  => "{scripts.verbosity}",
	'type'  => "int",
	'range' => "0,",
	'deft'  => "1",
	'reqd'  => "no" },
      { 'name' => "language",
	'desc' => "{scripts.language}",
	'type' => "string",
	'reqd' => "no",
	'hiddengli' => "yes" },
      { 'name' => "out",
	'desc' => "{scripts.out}",
	'type' => "string",
	'deft' => "STDERR",
	'reqd' => "no",
        'hiddengli' => "yes" },
      { 'name' => "faillog",
	'desc' => "{import.faillog}",
	'type' => "string",
	'deft' => &util::filename_cat($ENV{'GSDLHOME'},"etc", "error.txt"),
	'reqd' => "no",
        'modegai' => "3" },
      { 'name' => "xml",
	'desc' => "{scripts.xml}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengai' => "yes" },
      { 'name' => "gai",
	'desc' => "{scripts.gai}",
	'type' => "flag",
	'reqd' => "no",
	'hiddengai' => "yes" }];



my $options = { 'name' => "csv-usernames-to-db.pl",
		'desc' => "{cu2db.desc}",
		'args' => $arguments };


sub convert_csv_to_db
{
    my ($csv_filename,$fieldseparator,$alreadyencrypted) = @_;

    my $db_filename = &util::filename_cat($ENV{'GSDLHOME'},"etc","users.gdb");

    my $cmd = "txt2db -append \"$db_filename\"";
    
    if (!open(DBOUT,"| $cmd")) {
	print STDERR "Error: failed to run\n  $cmd\n";
	print STDERR "$!\n";
	exit(-1);
    }
    
    binmode(DBOUT, ":utf8");

    if (!open(FIN,"<$csv_filename")) {
	print STDERR "Error: Unable to open file $csv_filename\n";
	print STDERR "$!\n";
	exit(-1);
    }

    my $line;
    while (defined ($line = <FIN>)) {
	chomp $line;
	my ($username,$password,$groups,$comment) = split(/$fieldseparator/,$line);
	
	if (!$alreadyencrypted) {
	    $password = crypt($password,"Tp");
	}
	
	print DBOUT "[$username]\n";
	print DBOUT "<comment>$comment\n";
	print DBOUT "<enabled>true\n";
	print DBOUT "<groups>$groups\n";
	print DBOUT "<password>$password\n";
	print DBOUT "<username>$username\n";
	print DBOUT "-" x 70, "\n";
    }
    
    close(FIN);
    close(DBOUT);
}


sub main 
{
    my ($fieldseparator,$alreadyencrypted);
    my ($language, $out, $faillog);

    my $xml = 0;
    my $gai = 0;

    my $service = "csv-usernames";

    my $hashParsingResult = {};
    # general options available to all plugins
    my $intArgLeftinAfterParsing 
	= parse2::parse(\@ARGV,$arguments,$hashParsingResult,
			"allow_extra_options");
    # Parse returns -1 if something has gone wrong
    if ($intArgLeftinAfterParsing == -1)
    {
	&PrintUsage::print_txt_usage($options, "{cu2db.params}");
	die "\n";
    }
    
    foreach my $strVariable (keys %$hashParsingResult)
    {
	eval "\$$strVariable = \$hashParsingResult->{\"\$strVariable\"}";
    }


    # If $language has been specified, load the appropriate resource bundle
    # (Otherwise, the default resource bundle will be loaded automatically)
    if ($language && $language =~ /\S/) {
	&gsprintf::load_language_specific_resource_bundle($language);
    }

    if ($xml) {
        &PrintUsage::print_xml_usage($options);
	print "\n";
	return;
    }

    if ($gai) { # the gli wants strings to be in UTF-8
	&gsprintf::output_strings_in_UTF8; 
    }
    
    # now check that we had exactly one leftover arg, which should be 
    # the collection name. We don't want to do this earlier, cos 
    # -xml arg doesn't need a collection name
    # Or if the user specified -h, then we output the usage also
    if ($intArgLeftinAfterParsing != 1 || (@ARGV && $ARGV[0] =~ /^\-+h/))
    {
	&PrintUsage::print_txt_usage($options, "{cu2db.params}");
	die "\n";
    }

    my $csv_filename = shift @ARGV;

    my $close_out = 0;
    if ($out !~ /^(STDERR|STDOUT)$/i) {
	open (OUT, ">$out") ||
	    (&gsprintf(STDERR, "{common.cannot_open_output_file}: $!\n", $out) && die);
	$out = 'cu2db::OUT';
	$close_out = 1;
    }
    $out->autoflush(1);

    # check that we can open the faillog
    if ($faillog eq "") {
	$faillog = &util::filename_cat($ENV{'GSDLHOME'}, "etc", "error.txt");
    }
    open (FAILLOG, ">$faillog") ||
	(&gsprintf(STDERR, "{script.cannot_open_fail_log}\n", $faillog) && die);

    
    my $faillogname = $faillog;
    $faillog = 'cu2db::FAILLOG';
    $faillog->autoflush(1);

    convert_csv_to_db($csv_filename,$fieldseparator,$alreadyencrypted);


    close OUT if $close_out;
    close FAILLOG;
}


&main();
