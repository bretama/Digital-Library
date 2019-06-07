###########################################################################
#
# EmailPlugin.pm - a plugin for parsing email files
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999-2002 New Zealand Digital Library Project
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



# EmailPlugin
#
# by Gordon Paynter (gwp@cs.waikato.ac.nz)
#
# Email plug reads email files.  These are named with a simple
# number (i.e. as they appear in maildir folders) or with the 
# extension .mbx (for mbox mail file format)
#
# Document text:
#   The document text consists of all the text 
#   after the first blank line in the document.
#
# Metadata (not Dublin Core!):
#   $Headers      All the header content (optional, not stored by default)
#   $Subject      Subject: header
#   $To           To: header
#   $From         From: header
#   $FromName     Name of sender (where available)
#   $FromAddr     E-mail address of sender
#   $DateText     Date: header
#   $Date         Date: header in GSDL format (eg: 19990924)
#
#   $Title	  made up of Subject, Date and Sender (for default formatting)
#   $InReplyTo    Message id of the one this replies to
#
# John McPherson - June/July 2001
# added (basic) MIME support and quoted-printable and base64 decodings.
# Minor fixes for names that are actually email addresses (ie <...> was lost)
#
# See:  * RFC 822  - ARPA Internet Text Messages
#       * RFC 2045 - Multipurpose Internet Mail Extensions (MIME) -part1
#       * RFC 2046 - MIME (part 2)  Media Types (and multipart messages)
#       * RFC 2047 - MIME (part 3)  Message Header Extensions
#       * RFC 1806 - Content Dispositions (ie inline/attachment)


package EmailPlugin;

use strict;
no strict "refs"; # so we can use a variable as a filehandle for print $out


use SplitTextFile;
use unicode;  # gs conv functions
use gsprintf 'gsprintf'; # translations

use sorttools;
use FileUtils;

sub BEGIN {
    @EmailPlugin::ISA = ('SplitTextFile');
}

my $extended_oidtype_list = 
    [ {'name' => "message_id",
       'desc' => "{EmailPlugin.OIDtype.message_id}" }
      ];

# add in all the standard options from BaseImporter
unshift (@$extended_oidtype_list, @{$BaseImporter::oidtype_list});

my $arguments = 
    [ { 'name' => "process_exp",
	'desc' => "{BaseImporter.process_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_process_exp() },
      { 'name' => "no_attachments",
	'desc' => "{EmailPlugin.no_attachments}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "headers",
	'desc' => "{EmailPlugin.headers}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "OIDtype",
	'desc' => "{import.OIDtype}",
	'type' => "enum",
	'list' => $extended_oidtype_list,
	'deft' => "message_id",
	'reqd' => "no" },
      { 'name' => "OIDmetadata",
	'desc' => "{import.OIDmetadata}",
	'type' => "metadata",
	'deft' => "dc.Identifier",
	'reqd' => "no" },
      { 'name' => "split_exp",
	'desc' => "{EmailPlugin.split_exp}",
	'type' => "regexp",
	'reqd' => "no",
	'deft' => &get_default_split_exp() } 
      ];

my $options = { 'name'     => "EmailPlugin",
		'desc'     => "{EmailPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new SplitTextFile($pluginlist, $inputargs, $hashArgOptLists);

    $self->{'assoc_filenames'} = {}; # to save attach names so we don't clobber
    $self->{'tmp_file_paths'} = (); # list of tmp files to delete after processing is finished

    # this might not actually be true at read-time, but after processing
    # it should all be utf8.
    $self->{'input_encoding'}="utf8";
    return bless $self, $class;
}

sub get_default_process_exp {
    my $self = shift (@_);
    # mbx/email for mailbox file format, \d+ for maildir (each message is
    # in a separate file, with a unique number for filename)
    # mozilla and IE will save individual mbx format files with a ".eml" ext.
    return q@([\\/]\d+|\.(mbo?x|email|eml))$@;
}

# This plugin splits the mbox mail files at lines starting with From<sp>
# It is supposed to be "\n\nFrom ", but this isn't always used.
# add \d{4} so that the line ends in a year (in case the text has an
# unescaped "From " at the start of a line).
sub get_default_split_exp {
    return q^\nFrom .*\d{4}\n^;
    
}

sub can_process_this_file {
    my $self = shift(@_);
    my ($filename) = @_;

    # avoid any confusion between filenames matching \d+ (which are by default
    # matched by EmailPlugin) and directories that match \d+ (which should not)

    return 0 if (-d $filename); 

    if ($self->{'process_exp'} ne "" && $filename =~ /$self->{'process_exp'}/) {
	return 1;
    }
    return 0;
    
}


# do plugin specific processing of doc_obj
sub process {

    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    # Check that we're dealing with a valid mail file
    # mbox message files start with "From "
    # maildir messages usually start with Return-Path and Delivered-To
    # mh is very similar to maildir
    my $startoffile=substr($$textref,0,256);
    if (($startoffile !~ /^(From )/) &&
	($startoffile !~ /^(From|To|Envelope.*|Received|Return-Path|Date|Subject|Content\-.*|MIME-Version|Forwarded):/im)) {
	return undef;
    }
 
    my $cursection = $doc_obj->get_top_section();

    #
    # Parse the document's text and extract metadata
    #

    # Protect backslashes
    $$textref =~ s@\\@\\\\@g;

    # Separate header from body of message
    my $Headers = $$textref;
    $Headers =~ s/\r?\n\r?\n(.*)$//s;
    $$textref = $1;
    $Headers .= "\n";
    
    # Unfold headers - see rfc822
    $Headers =~ s/\r?\n[\t\ ]+/ /gs;
    # Extract basic metadata from header
    my @headers = ("From", "To", "Subject", "Date");
    my %raw;
    foreach my $name (@headers) {
	$raw{$name} = "No $name value";
    }

    # Get a default encoding for the header - RFC says should be ascii...
    my $default_header_encoding="iso_8859_1";

    # We don't know what character set is the user's default...
    # We could use textcat to guess... for now we'll look at mime content-type
#    if ($Headers =~ /([[:^ascii:]])/) {
#    }
    if ($Headers =~ /^Content\-type:.*charset=\"?([a-z0-9\-_]+)/mi) {
	$default_header_encoding=$1;
	$default_header_encoding =~ s@\-@_@g;
	$default_header_encoding =~ tr/A-Z/a-z/;
    }


    # Examine each line of the headers
    my ($line, $name, $value);
    my @parts;
    foreach $line (split(/\n/, $Headers)) {
	
	# Ignore lines with no content or which begin with whitespace
	next unless ($line =~ /:/);
	next if ($line =~ /^\s/);

	# Find out what metadata is on this line
	@parts = split(/:/, $line);
	$name = shift @parts;
        # get fieldname in canonical form - first cap, then lower case.
	$name =~ tr/A-Z/a-z/;
        # uppercase the first character according to the current locale
	$name=~s/(.+)/\u$1/;
	next unless $name;
	next unless ($raw{$name});

	# Find the value of that metadata
	$value = join(":", @parts);
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	# decode header values, using either =?<charset>?[BQ]?<data>?= (rfc2047) or default_header_encoding
	$self->decode_header_value($default_header_encoding, \$value);
	
	# Store the metadata
	$value =~ s@_@\\_@g; # protect against GS macro language
	$raw{$name} = $value;
    }

    # Extract the name and e-mail address from the From metadata
    my $frommeta = $raw{"From"};
    my $fromnamemeta;
    my $fromaddrmeta;

    $frommeta =~ s/\s*$//;  # Remove trailing space, if any

    if ($frommeta =~ m/(.+)\s*<(.+)>/) {
	$fromnamemeta=$1;
	$fromaddrmeta=$2;
    } elsif ($frommeta =~ m/(.+@.+)\s+\((.*)\)/) {
	$fromnamemeta=$2;
	$fromaddrmeta=$1;
    } elsif ($frommeta =~ m/(.+)\s+at\s+(.+)\s+\((.*)\)/) {
	$fromnamemeta=$3;
	$fromaddrmeta="$1&#64;$2";
    }

    if (!defined($fromaddrmeta)) {
	$fromaddrmeta=$frommeta;
    }
    $fromaddrmeta=~s/<//; $fromaddrmeta=~s/>//;
    # minor attempt to prevent spam-bots from harvesting addresses...
    $fromaddrmeta=~s/@/&#64;/;

    $doc_obj->add_utf8_metadata ($cursection, "FromAddr", $fromaddrmeta);

    if (defined($fromnamemeta) && $fromnamemeta) { # must be > 0 long
	$fromnamemeta =~ s/\"//g;  # remove quotes
	$fromnamemeta =~ s/\s+$//; # remove trailing whitespace
    }
    else {
	$fromnamemeta = $fromaddrmeta;
    }
    # if name is an address
    $fromnamemeta =~ s/<//g; $fromnamemeta =~ s/>//g;
    $fromnamemeta=~s/@/&#64\;/;
    $doc_obj->add_utf8_metadata ($cursection, "FromName", $fromnamemeta);

    $raw{"From"}=$frommeta;

    # Process Date information
    if ($raw{"Date"} !~ /No Date/) {
	$raw{"DateText"} = $raw{"Date"};
	
	# Convert the date text to internal date format
	$value = $raw{"Date"};
	# proper mbox format: Tue, 07 Jan 2003 17:27:42 +1300
	my ($day, $month, $year) = $value =~ /(\d?\d)\s([A-Z][a-z][a-z])\s(\d\d\d?\d?)/;
	if (!defined($day) || !defined($month) || !defined ($year)) {
	    # try monthly archive format: Wed Apr 23 00:26:08 2008
	    ($month,$day, $year) = $value =~ /([A-Z][a-z][a-z])\s\s?(\d?\d)\s\d\d:\d\d:\d\d\s(\d\d\d\d)/;
	}

	# make some assumptions about the year formatting...
	# some (old) software thinks 2001 is 101, some think 2001 is 01
	if ($year < 20) { $year += 2000; } # assume not really 1920...
	elsif ($year < 150) { $year += 1900; } # assume not really 2150...
	$raw{"Date"} = &sorttools::format_date($day, $month, $year);
	
    } else {
	# We have not extracted a date
	$raw{"DateText"} = "Unknown.";
	$raw{"Date"} = "19000000";
    }

    # Add extracted metadata to document object
    foreach my $name (keys %raw) {
	$value = $raw{$name};
	if ($value) {
	    # assume subject, etc headers have no special HTML meaning.
	    $value = &text_into_html($value);
	    # escape [] so it isn't re-interpreted as metadata
	    $value =~ s/\[/&#91;/g; $value =~ s/\]/&#93;/g;
	} else {
	    $value = "No $name field";
	}
	$doc_obj->add_utf8_metadata ($cursection, $name, $value);
    }


    # extract a message ID from the headers, if there is one, and we'll use
    # that as the greenstone doc ID. Having a predictable ID means we can
    # link to other messages, eg from In-Reply-To or References headers...
    if ($Headers =~ m@^Message-ID:(.+)$@mi) {
	my $id=escape_msg_id($1);
	$doc_obj->{'msgid'}=$id;
    }
    # link to another message, if this is a reply
    if ($Headers =~ m@^In-Reply-To:(.+)$@mi) {
	my $id=escape_msg_id($1);
	$doc_obj->add_utf8_metadata ($cursection, 'InReplyTo', $id);
    } elsif ($Headers =~ m@^References:.*\s([^\s]+)$@mi) {
	# References can have multiple, get the last one
	my $id=escape_msg_id($1);
	# not necessarily in-reply-to, but same thread...
	$doc_obj->add_utf8_metadata ($cursection, 'InReplyTo', $id);
    }



    my $mimetype="text/plain";
    my $mimeinfo="";
    my $charset = $default_header_encoding;
    # Do MIME and encoding stuff. Allow \s in mimeinfo in case there is
    # more than one parameter given to Content-type.
    # eg: Content-type: text/plain; charset="us-ascii"; format="flowed"
    if ($Headers =~ m@^content\-type:\s*([\w\.\-/]+)\s*(\;\s*.+)?\s*$@mi)
	{
	    $mimetype=$1;
	    $mimetype =~ tr/[A-Z]/[a-z]/;

	    if ($mimetype eq "text") { # for pre-RFC2045 messages (c. 1996)
		$mimetype = "text/plain";
	    }

	    $mimeinfo=$2;
	    if (!defined $mimeinfo) {
		$mimeinfo="";
	    } else { # strip leading and trailing stuff
		$mimeinfo =~ s/^\;\s*//;
		$mimeinfo =~ s/\s*$//;
	    }
	    if ($mimeinfo =~ /charset=\"([^\"]+)\"/i) {
	      $charset = $1;
	    }
	}

    my $transfer_encoding="7bit";
    if ($Headers =~ /^content-transfer-encoding:\s*([^\s]+)\s*$/mi) {
	$transfer_encoding=$1;
    }

    if ($mimetype eq "text/html") {
	$$textref= $self->text_from_part($$textref, $Headers);
    } elsif ($mimetype ne "text/plain") {
	$self->{'doc_obj'} = $doc_obj; # in case we need to associate files...
	$$textref=$self->text_from_mime_message($mimetype,$mimeinfo,$default_header_encoding,$$textref);
    } else { # mimetype eq text/plain

	if ($transfer_encoding =~ /quoted\-printable/) {
	    $$textref=qp_decode($$textref);
	} elsif ($transfer_encoding =~ /base64/) {
	    $$textref=base64_decode($$textref);
	}
	$self->convert2unicode($charset, $textref);

	$$textref = &text_into_html($$textref);
	$$textref =~ s@_@\\_@g; # protect against GS macro language

    }

    
    if ($self->{'headers'} && $self->{'headers'} == 1) {
	# Add "All headers" metadata
	$Headers = &text_into_html($Headers);

	$Headers = "No headers" unless ($Headers =~ /\w/);
	$Headers =~ s/@/&#64\;/g;
	# escape [] so it isn't re-interpreted as metadata
	$Headers =~ s/\[/&#91;/g; $Headers =~ s/\]/&#93;/g;
	$self->convert2unicode($charset, \$Headers);

	$Headers =~ s@_@\\_@g; # protect against GS macro language
	$doc_obj->add_utf8_metadata ($cursection, "Headers", $Headers);
    }


    # Add Title metadata
    my $Title = text_into_html($raw{'Subject'});
    $Title .= "<br>From: " . text_into_html($fromnamemeta);
    $Title .= "<br>Date: " . text_into_html($raw{'DateText'});
    $Title =~ s/\[/&#91;/g; $Title =~ s/\]/&#93;/g;

    $doc_obj->add_utf8_metadata ($cursection, "Title", $Title);
	
    # Add FileFormat metadata
    $doc_obj->add_metadata($cursection, "FileFormat", "EMAIL");

    # Add text to document object
    $$textref = "No message" unless ($$textref =~ /\w/);

    $doc_obj->add_utf8_text($cursection, $$textref);

    return 1;
}

# delete any temp files that we have created
sub clean_up_after_doc_obj_processing {
    my $self = shift(@_);
    
    foreach my $tmp_file_path (@{$self->{'tmp_file_paths'}}) {
        if (-e $tmp_file_path) {
            &FileUtils::removeFiles($tmp_file_path);
        }
    }
    
}

# Convert a text string into HTML.
#
# The HTML is going to be inserted into a GML file, so 
# we have to be careful not to use symbols like ">",
# which ocurs frequently in email messages (and use
# &gt instead.
#
# This function also turns links and email addresses into hyperlinks,
# and replaces carriage returns with <BR> tags (and multiple carriage
# returns with <P> tags).


sub text_into_html {
    my ($text) = @_;

    # Convert problem characters into HTML symbols
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/\"/&quot;/g;

    # convert email addresses and URIs into links
# don't markup email addresses for now
#    $text =~ s/([\w\d\.\-]+@[\w\d\.\-]+)/<a href=\"mailto:$1\">$1<\/a>/g;

    # try to munge email addresses a little bit...
    $text =~ s/@/&#64;/;
    # assume hostnames are \.\w\- only, then might have a trailing '/.*'
    # assume URI doesn't finish with a '.'
    $text =~ s@((http|ftp|https)://[\w\-]+(\.[\w\-]+)*/?((&amp;|\.|\%[a-f0-9]{2})?[\w\?\=\-_/~]+)*(\#[\w\.\-_]*)?)@<a href=\"$1\">$1<\/a>@gi;


    # Clean up whitespace and convert \n charaters to <BR> or <P>
    $text =~ s/ +/ /g;
    $text =~ s/\s*$//g; 
    $text =~ s/^\s*//g;
    $text =~ s/\n/\n<br>/g;
    $text =~ s/<br>\s*<br>/<p>/gi;

    return $text;
}




#Process a MIME message.
# the textref we are given DOES NOT include the header.
sub text_from_mime_message {
    my $self = shift(@_);
    my ($mimetype,$mimeinfo,$default_header_encoding,$text)=(@_);
    my $outhandle=$self->{'outhandle'};
    # Check for multiparts - $mimeinfo will be a boundary
    if ($mimetype =~ /multipart/) {
	my $boundary="";
	if ($mimeinfo =~ m@boundary=(\"[^\"]+\"|[^\s]+)\s*$@im) {
	    $boundary=$1;
	    if ($boundary =~ m@^\"@) {
		$boundary =~ s@^\"@@; $boundary =~ s@\"$@@;
	    }
	} else {
	    print $outhandle "EmailPlugin: (warning) couldn't parse MIME boundary\n";
	}
	# parts start with "--$boundary"
	# message ends with "--$boundary--"
	# RFC says boundary is <70 chars, [A-Za-z'()+_,-./:=?], so escape any
	# that perl might want to interpolate. Also allows spaces...
	$boundary=~s/\\/\\\\/g;
	$boundary=~s/([\?\+\.\(\)\:\/\'])/\\$1/g;
	my @message_parts = split("\r?\n\-\-$boundary", "\n$text");
	# remove first "part" and last "part" (final --)
	shift @message_parts;
	my $last=pop @message_parts;
	# if our boundaries are a bit dodgy and we only found 1 part...
	if (!defined($last)) {$last="";}
	# make sure it is only -- and whitespace
	if ($last !~ /^\-\-\s*$/ms) {
	    print $outhandle "EmailPlugin: (warning) last part of MIME message isn't empty\n";
	}
	foreach my $message_part (@message_parts) {
	    # remove the leading newline left from split.
	    $message_part=~s/^\r?\n//;
	}
	if ($mimetype eq "multipart/alternative") {
	    # check for an HTML version first, then TEXT, otherwise use first.
	    my $part_text="";
	    foreach my $message_part (@message_parts) {
		if ($message_part =~ m@^content\-type:\s*text/html@i)
		{
		    # Use the HTML version
		    $part_text = $self->text_from_part($message_part);
		    $mimetype="text/html";
		    last;
		}
	    }
	    if ($part_text eq "") { # try getting a text part instead
		foreach my $message_part (@message_parts) {
		    if ($message_part =~ m@^content\-type:\s*text/plain@i)
		    {
			# Use the plain version
			$part_text = $self->text_from_part($message_part);
			if ($part_text =~/[^\s]/) {
			    $part_text = text_into_html($part_text);
			}
			$mimetype="text/plain";
			last;
		    }
		}
	    }
	    if ($part_text eq "") { #use first part (no html/text part found)
		$part_text = $self->text_from_part(shift @message_parts);
		$part_text = text_into_html($part_text);
	    }
	    if ($part_text eq "") { # we couldn't get anything!!!
		# or it was an empty message...
		# do nothing...
		gsprintf($outhandle, "{ReadTextFile.empty_file} - empty body?\n");
	    } else {
		$text = $part_text;
	    }
	} elsif ($mimetype =~ m@multipart/(mixed|digest|related|signed)@) {
	    $text = "";
	    # signed is for PGP/GPG messages... the last part is a hash
	    if ($mimetype =~ m@multipart/signed@) {
		pop @message_parts;
	    }
	    my $is_first_part=1;
	    foreach my $message_part (@message_parts) {
		if ($is_first_part && $text ne "") {$is_first_part=0;}

		if ($mimetype eq "multipart/digest") {
		    # default type - RTFRFC!! Set if not already set
		    $message_part =~ m@^(.*)\n\r?\n@s;
		    my $part_header=$1;
		    if ($part_header !~ m@^content-type@mi) {
			$message_part="Content-type: message/rfc822\n"
			    . $message_part; # prepend default type
		    }
		}

		$text .= $self->process_multipart_part($default_header_encoding,
						       $message_part,
						       $is_first_part);
	    } # foreach message part.
	} else {
	    # we can't handle this multipart type (not mixed or alternative)
	    # the RFC also mentions "parallel".
	}
    } # end of ($mimetype =~ multipart)
    elsif ($mimetype =~ m@message/rfc822@) {
	my $msg_header = $text;
	$msg_header =~ s/\r?\n\r?\n(.*)$//s;
	$text = $1;

	if ($msg_header =~ /^content\-type:\s*([\w\.\-\/]+)\s*\;?\s*(.+?)\s*$/mi)
	{
	    $mimetype=$1;
	    $mimeinfo=$2;
	    $mimetype =~ tr/[A-Z]/[a-z]/;

	    my $msg_text;
	    if ($mimetype =~ m@multipart/@) {
		$msg_text = $self->text_from_mime_message($mimetype, $mimeinfo,
						   $default_header_encoding,
						   $text);
	    } else {
		$msg_text=$self->text_from_part($text,$msg_header);
	    }

	    my $brief_header=text_into_html(get_brief_headers($msg_header));
	    $text= "\n<b>&lt;&lt;attached message&gt;&gt;</b><br>";
	    $text.= "<table><tr><td width=\"5%\"> </td>\n";
	    $text.="<td>" . $brief_header . "\n</p>" . $msg_text 
		. "</td></tr></table>";
	}
    } else {
	# we don't do any processing of the content.
    }

    return $text;
}



# used for turning a message id into a more friendly string for greenstone
sub escape_msg_id {
#msgid
    my $id=shift;
    chomp $id; $id =~ s!\s!!g; # remove spaces
    $id =~ s![<>\[\]]!!g; # remove [ ] < and >
    $id =~ s![_&]!-!g; # replace symbols that might cause problems
    $id =~ s!\.!-!g; # . means section to greenstone doc ids!
    $id =~ s!@!-!g; # replace @ symbol, to avoid spambots
    return $id;
}



sub process_multipart_part {
    my $self = shift;
    my $default_header_encoding = shift;
    my $message_part = shift;
    my $is_first_part = shift;

    my $return_text="";
    my $part_header=$message_part;
    my $part_body;
    if ($message_part=~ /^\s*\n/) {
	# no header... use defaults
	$part_body=$message_part;
	$part_header="Content-type: text/plain; charset=us-ascii";
    } elsif ($part_header=~s/\r?\n\r?\n(.*)$//s) {
	$part_body=$1;
    } else {
	# something's gone wrong...
	$part_header="";
	$part_body=$message_part;
    }
    
    $part_header =~ s/\r?\n[\t\ ]+/ /gs; #unfold
    my $part_content_type="";
    my $part_content_info="";

    if ($part_header =~ m@^content\-type:\s*([\w\.\-/]+)\s*(\;.*)?$@mi) {
	$part_content_type=$1; $part_content_type =~ tr/A-Z/a-z/;
	$part_content_info=$2;
	if (!defined($part_content_info)) {
	    $part_content_info="";
	} else {
	    $part_content_info =~ s/^\;\s*//;
	    $part_content_info =~ s/\s*$//;
	}
    }
    my $filename="";
    if ($part_header =~ m@name=\"?([^\"\n]+)\"?@mis) {
	$filename=$1;
	$filename =~ s@\r?\s*$@@; # remove trailing space, if any
	# decode the filename
	$self->decode_header_value($default_header_encoding, \$filename);

    }
    
    # disposition - either inline or attachment.
    # NOT CURRENTLY USED - we display all text types instead...
    # $part_header =~ /^content\-disposition:\s*([\w+])/mis;
    
    # add <<attachment>> to each part except the first...
    if (!$is_first_part) {
	$return_text.="\n<p><hr><strong>&lt;&lt;attachment&gt;&gt;";
	# add part info header
	my $header_text = "<br>Type: $part_content_type<br>\n";
	if ($filename ne "") {
	    $header_text .= "Filename: $filename\n";
	}
	$header_text =~ s@_@\\_@g;
	$return_text .= $header_text . "</strong></p>\n<p>\n";
    }

    if ($part_content_type =~ m@text/@)
    {
	# $message_part includes the mime part headers
	my $part_text = $self->text_from_part($message_part);
	if ($part_content_type !~ m@text/(ht|x)ml@) {
	    $part_text = text_into_html($part_text);
	}
	if ($part_text eq "") {
	    $part_text = ' ';
	}
	$return_text .= $part_text;
    } elsif ($part_content_type =~ m@message/rfc822@) {
	# This is a forwarded message
	my $message_part_headers=$part_body;
	$message_part_headers=~s/\r?\n\r?\n(.*)$//s;
	my $message_part_body=$1;
	$message_part_headers =~ s/\r?\n[\t\ ]+/ /gs; #unfold
	
	my $rfc822_formatted_body=""; # put result in here
	if ($message_part_headers =~
	    /^content\-type:\s*([\w\.\-\/]+)\s*(\;.*)?$/ims)
	{
	    # The message header uses MIME flags
	    my $message_content_type=$1;
	    my $message_content_info=$2;
	    if (!defined($message_content_info)) {
		$message_content_info="";
	    } else {
		$message_content_info =~ s/^\;\s*//;
		$message_content_info =~ s/\s*$//;
	    }
	    $message_content_type =~ tr/A-Z/a-z/;
	    if ($message_content_type =~ /multipart/) {
		$rfc822_formatted_body=
		    $self->text_from_mime_message($message_content_type,
						  $message_content_info,
						  $default_header_encoding,
						  $message_part_body);
	    } else {
		$message_part_body=$self->text_from_part($part_body,
							$message_part_headers);
		$rfc822_formatted_body=text_into_html($message_part_body);
	    }
	} else {
	    # message doesn't use MIME flags
	    $rfc822_formatted_body=text_into_html($message_part_body);
	    $rfc822_formatted_body =~ s@_@\\_@g;
	}
	# Add the returned text to the output
	# don't put all the headers...
#	$message_part_headers =~ s/^(X\-.*|received|message\-id|return\-path):.*\n//img;
	my $brief_headers=get_brief_headers($message_part_headers);
	$return_text.=text_into_html($brief_headers);
	$return_text.="</p><p>\n";
	$return_text.=$rfc822_formatted_body;
	$return_text.="</p>\n";
	# end of message/rfc822
    } elsif ($part_content_type =~ /multipart/) { 
	# recurse again
	
	my $tmptext= $self->text_from_mime_message($part_content_type,
						   $part_content_info,
						   $default_header_encoding,
						   $part_body);
	$return_text.=$tmptext;
    } else {
	# this part isn't text/* or another message...
	if ($is_first_part) {
	    # this is the first part of a multipart, or only part!
	    $return_text="\n<p><hr><strong>&lt;&lt;attachment&gt;&gt;";
	    # add part info header
	    my $header_text="<br>Type: $part_content_type<br>\n";
	    $header_text.="Filename: $filename</strong></p>\n<p>\n";
	    $header_text =~ s@_@\\_@g;
	    $return_text.=$header_text;
	}
	
	# save attachment by default
	if (!$self->{'no_attachments'}
	    && $filename ne "") { # this part has a file...
	    my $encoding="8bit";
	    if ($part_header =~
		/^content-transfer-encoding:\s*(\w+)/mi ) {
		$encoding=$1; $encoding =~ tr/A-Z/a-z/;
	    }
	    my $tmpdir=&FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "tmp");
	    my $save_filename=$filename;
	    
	    # make sure we don't clobber files with same name;
	    # need to keep state between .mbx files
	    my $assoc_files=$self->{'assoc_filenames'};
	    if ($assoc_files->{$filename}) { # it's been set...
		$assoc_files->{$filename}++;
		$filename =~ m/(.+)\.(\w+)$/;
		my ($filestem, $ext)=($1,$2);
		$save_filename="${filestem}_"
		    . $assoc_files->{$filename} . ".$ext";
	    } else { # first file with this name
		$assoc_files->{$filename}=1;
	    }
	    my $tmp_filename = &FileUtils::filenameConcatenate($tmpdir, $save_filename);
	    open (SAVE, ">$tmp_filename") ||
		warn "EMAILPlug: Can't save attachment as $tmp_filename: $!";
	    binmode(SAVE); # needed on Windows
	    my $part_text = $message_part;
	    $part_text =~ s/(.*?)\r?\n\r?\n//s; # remove header
	    if ($encoding eq "base64") {
		print SAVE base64_decode($part_text);
	    } elsif ($encoding eq "quoted-printable") {
		print SAVE qp_decode($part_text);
	    } else { # 7bit, 8bit, binary, etc...
		print SAVE $part_text;
	    }
	    close SAVE;
	    my $doc_obj=$self->{'doc_obj'};
	    $doc_obj->associate_file("$tmp_filename",
				     "$save_filename",
				     $part_content_type # mimetype
				     );
	    # add this file to the list of tmp files for deleting later
	    push(@{$self->{'tmp_file_paths'}}, $tmp_filename);

	    my $outhandle=$self->{'outhandle'};
	    print $outhandle "EmailPlugin: saving attachment \"$filename\"\n"; #
	    
	    # be nice if "download" was a translatable macro :(
	    $return_text .="<a href=\"_httpdocimg_/$save_filename\">download</a>";
	} # end of save attachment
    } # end of !text/message part


    return $return_text;
}


# Return only the "important" headers from a set of message headers
sub get_brief_headers {
    my $msg_header = shift;
    my $brief_header = "";

    # Order matters!
    if ($msg_header =~ /^(From:.*)$/im) {$brief_header.="$1\n";}
    if ($msg_header =~ /^(To:.*)$/im) {$brief_header.="$1\n";}
    if ($msg_header =~ /^(Cc:.*)$/im) {$brief_header.="$1\n";}
    if ($msg_header =~ /^(Subject:.*)$/im) {$brief_header.="$1\n";}
    if ($msg_header =~ /^(Date:.*)$/im) {$brief_header.="$1\n";}

    return $brief_header;
}


# Process a MIME part. Return "" if we can't decode it.
# should only be called for parts with type "text/*" ?
# Either pass the entire mime part (including the part's header),
# or pass the mime part's text and optionally the part's header.
sub text_from_part {
    my $self = shift;
    my $text = shift || '';
    my $part_header = shift;


    my $type="text/plain"; # default, overridden from part header
    my $charset=undef;     # convert2unicode() will guess if necessary

    if (! $part_header) { # no header argument was given. check the body
	$part_header = $text;
	# check for empty part header (leading blank line)
	if ($text =~ /^\s*\r?\n/) {
	    $part_header="Content-type: text/plain; charset=us-ascii";
	} else {
	    $part_header =~ s/\r?\n\r?\n(.*)$//s;
	    $text=$1; if (!defined($text)) {$text="";}
	}
	$part_header =~ s/\r?\n[\t ]+/ /gs; #unfold
    }

    if ($part_header =~
	/content\-type:\s*([\w\.\-\/]+).*?charset=\"?([^\;\"\s]+)\"?/is) {
	$type=$1;
	$charset=$2;
    }
    my $encoding="";
    if ($part_header =~ /^content\-transfer\-encoding:\s*([^\s]+)/mis) {
	$encoding=$1; $encoding=~tr/A-Z/a-z/;
    }
    # Content-Transfer-Encoding is per-part
    if ($encoding ne "") {
	if ($encoding =~ /quoted\-printable/) {
	    $text=qp_decode($text);
	} elsif ($encoding =~ /base64/) {
	    $text=base64_decode($text);
	} elsif ($encoding !~ /[78]bit/) { # leave 7/8 bit as is.
	    # rfc2045 also allows binary, which we ignore (for now).
	    my $outhandle=$self->{'outhandle'};
	    print $outhandle "EmailPlugin: unknown transfer encoding: $encoding\n";
	    return "";
	}
    }

    if ($type eq "text/html") {
	# only get stuff between <body> tags, or <html> tags.
	$text =~ s@^.*<html[^>]*>@@is;
	$text =~ s@</html>.*$@@is;
	$text =~ s/^.*?<body[^>]*>//si;
	$text =~ s/<\/body>.*$//si;
    }
    elsif ($type eq "text/xml") {
	$text=~s/</&lt;/g;$text=~s/>/&gt;/g;
	$text="<pre>\n$text\n</pre>\n";
    }
    # convert to unicode
    $self->convert2unicode($charset, \$text);
    $text =~ s@_@\\_@g; # protect against GS macro language
    return $text;
}




# decode quoted-printable text
sub qp_decode {
    my $text=shift;

    # if a line ends with "=\s*", it is a soft line break, otherwise
    # keep in any newline characters.

    $text =~ s/=\s*\r?\n//mg;
    $text =~ s/=([0-9A-Fa-f]{2})/chr (hex "0x$1")/eg;
    return $text;
}

# decode base64 text. This is fairly slow (since it's interpreted perl rather
# than compiled XS stuff like in the ::MIME modules, but this is more portable
# for us at least).
# see rfc2045 for description, but basically, bits 7 and 8 are set to zero;
# 4 bytes of encoded text become 3 bytes of binary - remove 2 highest bits
# from each encoded byte.


sub base64_decode {
    my $enc_text = shift;
# A=>0, B=>1, ..., '+'=>62, '/'=>63
# also '=' is used for padding at the end, but we remove it anyway.
    my $mimechars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
# map each MIME char into it's value, for more efficient lookup.
    my %index;
    map { $index{$_} = index ($mimechars, $_) } (split ('', $mimechars));
# remove all non-base64 chars. eval to get variable in transliteration...
# also remove '=' - we'll assume (!!) that there are no errors in the encoding
    eval "\$enc_text =~ tr|$mimechars||cd";
    my $decoded="";
    while (length ($enc_text)>3)
    { 
	my $fourchars=substr($enc_text,0,4,"");
	my @chars=(split '',$fourchars);
	$decoded.=chr( $index{$chars[0]}        << 2 | $index{$chars[1]} >> 4);
	$decoded.=chr( ($index{$chars[1]} & 15) << 4 | $index{$chars[2]} >> 2);
	$decoded.=chr( ($index{$chars[2]} & 3 ) << 6 |  $index{$chars[3]});
    } 
# if there are any input chars left, there are either
# 2 encoded bytes (-> 1 raw byte) left or 3 encoded (-> 2 raw) bytes left.
    my @chars=(split '',$enc_text);
    if (length($enc_text)) {
	$decoded.=chr($index{$chars[0]} << 2 | (int $index{$chars[1]} >> 4));
    } 
    if (length($enc_text)==3) {
	$decoded.=chr( ($index{$chars[1]} & 15) << 4 | $index{$chars[2]} >> 2);
    }
    return $decoded;
}

# returns 0 if valid utf-8, 1 if invalid
sub is_utf8 {
    my $self = shift;
    my $textref = shift;

    $$textref =~ m/^/g; # to set \G
    my $badbytesfound=0;
    while ($$textref =~ m!\G.*?([\x80-\xff]+)!sg) {
	my $highbytes=$1;
	my $highbyteslength=length($highbytes);
	# replace any non utf8 complaint bytes
	$highbytes =~ /^/g; # set pos()
	while ($highbytes =~
	       m!\G (?: [\xc0-\xdf][\x80-\xbf] | # 2 byte utf-8
		     [\xe0-\xef][\x80-\xbf]{2} | # 3 byte
		     [\xf0-\xf7][\x80-\xbf]{3} | # 4 byte
		     [\xf8-\xfb][\x80-\xbf]{4} | # 5 byte
		     [\xfc-\xfd][\x80-\xbf]{5}   # 6 byte
		     )*([\x80-\xff])? !xg
	       ) {
	    my $badbyte=$1;
	    if (!defined $badbyte) {next} # hit end of string
	    return 1;
	}
    }
    return 0;
}

# words with non ascii characters in header values must be encoded in the 
# following manner =?<charset>?[BQ]?<data>?= (rfc2047)

sub decode_header_value {
    my $self = shift(@_);
    my ($default_header_encoding, $textref) = @_;
    
    if (!$$textref) {
	# nothing to do!
	return;
    }
    my $value = $$textref;
    # decode headers if stored using =?<charset>?[BQ]?<data>?= (rfc2047)
    if ($value =~ /=\?.*\?[BbQq]\?.*\?=/) {
	my $original_value=$value;
	my $encoded=$value;
	$value="";
	# we should ignore spaces between consecutive encoded-texts
	$encoded =~ s@\?=\s+=\?@\?==\?@g;
	while ($encoded =~ s/(.*?)=\?([^\?]*)\?([bq])\?([^\?]+)\?=//i) {
	    my ($charset, $encoding, $data)=($2,$3,$4);
	    my ($decoded_data);
	    my $leading_chars = "$1";
	    $self->convert2unicode($default_header_encoding, \$leading_chars);
	    $value.=$leading_chars; 
	    
	    $data=~s/^\s*//; $data=~s/\s*$//; # strip whitespace from ends
	    chomp $data;
	    $encoding =~ tr/BQ/bq/;
	    if ($encoding eq "q") { # quoted printable
		$data =~ s/_/\ /g;  # from rfc2047 (sec 4.2.2)
		$decoded_data=qp_decode($data);
		# qp_decode adds \n, which is default for body text
		chomp($decoded_data);
	    } else { # base 64
		$decoded_data=base64_decode($data);
	    }
	    $self->convert2unicode($charset, \$decoded_data);
	    $value .= $decoded_data;
	} # end of while loop
	
	# get any trailing characters
	$self->convert2unicode($default_header_encoding, \$encoded);
	$value.=$encoded;
	
	if ($value =~ /^\s*$/) { # we couldn't extract anything...
	    $self->convert2unicode($default_header_encoding,
				   \$original_value);
	    $value=$original_value;
	}
	$$textref = $value;
    } # end of if =?...?=
    
    # In the absense of other charset information, assume the
    # header is the default (usually "iso_8859_1") and convert to unicode.
    else {
	$self->convert2unicode($default_header_encoding, $textref);
    }   
    
}



sub convert2unicode {
  my $self = shift(@_);
  my ($charset, $textref) = @_;

  if (!$$textref) {
      # nothing to do!
      return;
  }

  if (! defined $charset) {
      # check if we have valid utf-8
      if ($self->is_utf8($textref)) { $charset = "utf8" }

      # default to latin
      $charset = "iso_8859_1" if ! defined($charset);
  }

  # first get our character encoding name in the right form.
  $charset =~ tr/A-Z/a-z/; # lowercase
  $charset =~ s/\-/_/g;
  if ($charset =~ /gb_?2312/) { $charset="gb" }
  # assumes EUC-KR, not ISO-2022 !?
  $charset =~ s/^ks_c_5601_1987/korean/;
  if ($charset eq 'utf_8') {$charset='utf8'}

  my $outhandle = $self->{'outhandle'};

  if ($charset eq "utf8") {
      # no conversion needed, but lets check that it's valid utf8
      # see utf-8 manpage for valid ranges
      $$textref =~ m/^/g; # to set \G
      my $badbytesfound=0;
      while ($$textref =~ m!\G.*?([\x80-\xff]+)!sg) {
	  my $highbytes=$1;
	  my $highbyteslength=length($highbytes);
	  # replace any non utf8 complaint bytes
	  $highbytes =~ /^/g; # set pos()
	  while ($highbytes =~
		 m!\G (?: [\xc0-\xdf][\x80-\xbf] | # 2 byte utf-8
		       [\xe0-\xef][\x80-\xbf]{2} | # 3 byte
		       [\xf0-\xf7][\x80-\xbf]{3} | # 4 byte
		       [\xf8-\xfb][\x80-\xbf]{4} | # 5 byte
		       [\xfc-\xfd][\x80-\xbf]{5}   # 6 byte
		       )*([\x80-\xff])? !xg
		 ) {
	      my $badbyte=$1;
	      if (!defined $badbyte) {next} # hit end of string
	      my $pos=pos($highbytes);
	      substr($highbytes, $pos-1, 1, "\xc2\x80");
	      # update the position to continue searching (for \G)
	      pos($highbytes) = $pos+1; # set to just after the \x80
	      $badbytesfound=1;
	  }
	  if ($badbytesfound==1) {
	      # claims to be utf8, but it isn't!
	      print $outhandle "EmailPlugin: Headers claim utf-8 but bad bytes "
		  . "detected and removed.\n";

	      my $replength=length($highbytes);
	      my $textpos=pos($$textref);
	      # replace bad bytes with good bytes
	      substr( $$textref, $textpos-$replength,
		      $replength, $highbytes);
	      # update the position to continue searching (for \G)
	      pos($$textref)=$textpos+($replength-$highbyteslength);
	  }
      }
      return;
  }

  # It appears that we can't always trust ascii text so we'll treat it
  # as iso-8859-1 (letting characters above 0x80 through without
  # converting them to utf-8 will result in invalid XML documents
  # which can't be parsed at build time).
  $charset = "iso_8859_1" if ($charset eq "us_ascii" || $charset eq "ascii");

  if ($charset eq "iso_8859_1") {
      # test if the mailer lied, and it has win1252 chars in it...
      # 1252 has characters between 0x80 and 0x9f, 8859-1 doesn't
      if ($$textref =~ m/[\x80-\x9f]/) {
	  print $outhandle "EmailPlugin: Headers claim ISO charset but MS ";
	  print $outhandle "codepage 1252 detected.\n";
	  $charset = "windows_1252";
      }
  }
  my $utf8_text=&unicode::unicode2utf8(&unicode::convert2unicode($charset,$textref));

  if ($utf8_text ne "") {
      $$textref=$utf8_text;
  } else {
      # we didn't get any text... unsupported encoding perhaps? Or it is
      # empty anyway. We'll try to continue, assuming 8859-1. We could strip
      # characters out here if this causes problems...
      my $outhandle=$self->{'outhandle'};
      print $outhandle "EmailPlugin: falling back to iso-8859-1\n";
      $$textref=&unicode::unicode2utf8(&unicode::convert2unicode("iso_8859_1",$textref));

  }
}

sub get_base_OID {
    my $self = shift(@_);
    my ($doc_obj) = @_;

    if ($self->{'OIDtype'} eq "message_id") {
	# temporarily set OIDtype to hash to get a base id
	$self->{'OIDtype'} = "hash_on_ga_xml";
	my $id = $self->SUPER::get_base_OID(@_);
	$self->{'OIDtype'} = "message_id";
	return $id;
    }
    return $self->SUPER::get_base_OID(@_);
}


sub add_OID {
    my $self = shift (@_);
    my ($doc_obj, $id, $segment_number) = @_;
    if ($self->{'OIDtype'} eq "message_id" && exists $doc_obj->{'msgid'} ) {
	$doc_obj->set_OID($doc_obj->{'msgid'});
    }
    else {
	$doc_obj->set_OID("$id\_$segment_number");
    }
}


# Perl packages have to return true if they are run.
1;
