#!/usr/bin/perl -w

###########################################################################
#
# sendmail.pl --
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2000 New Zealand Digital Library Project
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

# sendmail.pl is a simple wrapper around the Sendmail perl module written
# by Milivoj Ivkovic <mi@alma.ch>

# Input is either read from STDIN or, if the -msgfile option is set, read
# from the given file.

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};
    unshift (@INC, "$ENV{'GSDLHOME'}/perllib");
}

use lib qq($ENV{'GSDLHOME'}/perllib/cpan);
use Mail::Sendmail;
use parsargv;

if (!parsargv::parse(\@ARGV, 
		     'to/@', \$to,
		     'from/@', \$from,
		     'subject/.*/', \$subject,
		     'html', \$html,
		     'smtp/.*', \$smtp,
		     'msgfile/.*/', \$msgfile)) {
    print STDERR "\n";
    print STDERR "sendmail.pl: A simple platform independant mail sending program.\n\n";
    print STDERR "  usage: $0 [options]\n\n";
    print STDERR "  options:\n";
    print STDERR "   -to addr      Comma separated list of mail recipients\n";
    print STDERR "   -from addr    Address of message sender\n";
    print STDERR "   -subject str  Optional subject line\n";   
    print STDERR "   -html         Send message as HTML\n";
    print STDERR "   -smtp server  The outgoing (SMTP) mail server\n";
    print STDERR "   -msgfile file A file from which message to be sent is read.\n";
    print STDERR "                 If not set message will be read in from STDIN\n";
    die "\n";
}

my %mail = ('SMTP' => $smtp, 
	    'To' => $to,
	    'From' => $from,
	    'Subject' => $subject,
	    );

my $msg = "";
if ($msgfile ne "") {
    if (!open (MSGFILE, $msgfile)) {
	print STDERR "ERROR: Failed to open $msgfile. Message was not sent\n";
	exit (-1);
    }
    undef $/;
    $msg = <MSGFILE>;
    $/ = "\n";
    close MSGFILE;
} else {
    $msg = <STDIN>;
}

$mail{'Content-type'} = "text/html; charset=\"iso-8859-1\"" if ($html);
$mail{'Message'} = $msg;
	
if (!sendmail %mail) {
    print STDERR "ERROR: Failed to send message\n";
    print STDERR "'$Mail::Sendmail::error'\n";
    exit (-1);
}
