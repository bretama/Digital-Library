package webpageutil;

use ghtml;
use strict;

sub error_location
{
    my ($args,$text) = @_;

    &ghtml::urlsafe($text);
    my $mess_url = "$args->{'httpbuild'}&bca=mess&head=_headerror_";
    print "Location: $mess_url&mess=$text\n\n";
}

sub status_location
{
    my ($args,$text,$tmpname,$bc1finished) = @_;

    &ghtml::urlsafe($text);    
    my $mess_url = "$args->{'httpbuild'}&bca=buildstatus";
    $mess_url .= "&bc1tmpfilename=$tmpname&bc1finished=$bc1finished";
    print "Location: $mess_url&mess=$text\n\n";
}

1;
