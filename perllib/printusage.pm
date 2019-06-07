###########################################################################
#
# printusage.pm --
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


package PrintUsage;


use gsprintf;
use strict;
no strict 'subs'; # allow barewords (eg STDERR) as function arguments


sub gsprintf
{
    return &gsprintf::gsprintf(@_);
}

# this is not called by plugins or classifiers, just by scripts
sub print_xml_usage
{
    my $options = shift(@_);

    # XML output is always in UTF-8
    &gsprintf::output_strings_in_UTF8;

    &print_xml_header("script");

    &gsprintf(STDERR, "<Info>\n");
    &gsprintf(STDERR, "  <Name>$options->{'name'}</Name>\n");
    &gsprintf(STDERR, "  <Desc>$options->{'desc'}</Desc>\n");
    &gsprintf(STDERR, "  <Arguments>\n");
    if (defined($options->{'args'})) {
	&print_options_xml($options->{'args'});
    }
    &gsprintf(STDERR, "  </Arguments>\n");
    &gsprintf(STDERR, "</Info>\n");
}


sub print_xml_header
{
    &gsprintf(STDERR, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
}


sub print_options_xml
{
    my $options = shift(@_);

    foreach my $option (@$options) {
	next if defined($option->{'internal'});
	
	my $optionname = $option->{'name'};
	my $displayname = $option->{'disp'};
	
	my $optiondesc = &gsprintf::lookup_string($option->{'desc'});

	# Escape '<' and '>' characters
	$optiondesc =~ s/</&amp;lt;/g; # doubly escaped
	$optiondesc =~ s/>/&amp;gt;/g;

	# Display option name, description and type
	&gsprintf(STDERR, "    <Option>\n");
	&gsprintf(STDERR, "      <Name>$optionname</Name>\n");
	if (defined($option->{'disp'})) {
	    my $displayname = &gsprintf::lookup_string($option->{'disp'});
	    # Escape '<' and '>' characters
	    $displayname =~ s/</&amp;lt;/g; # doubly escaped
	    $displayname =~ s/>/&amp;gt;/g;
	    &gsprintf(STDERR, "      <DisplayName>$displayname</DisplayName>\n");
	}
	&gsprintf(STDERR, "      <Desc>$optiondesc</Desc>\n");
	&gsprintf(STDERR, "      <Type>$option->{'type'}</Type>\n");

	# If the option has a required field, display this
	if (defined($option->{'reqd'})) {
	    &gsprintf(STDERR, "      <Required>$option->{'reqd'}</Required>\n");
	}

	# If the option has a charactor length field, display this
	if (defined($option->{'char_length'})) {
	    &gsprintf(STDERR, "      <CharactorLength>$option->{'char_length'}</CharactorLength>\n");
	}

	# If the option has a range field, display this
	if (defined($option->{'range'})) {
	    &gsprintf(STDERR, "      <Range>$option->{'range'}</Range>\n");
	}

	# If the option has a list of possible values, display these
	if (defined $option->{'list'}) {
	    &gsprintf(STDERR, "      <List>\n");
	    my $optionvalueslist = $option->{'list'};
	    foreach my $optionvalue (@$optionvalueslist) {
		&gsprintf(STDERR, "        <Value>\n");
		&gsprintf(STDERR, "          <Name>$optionvalue->{'name'}</Name>\n");
		if (defined $optionvalue->{'desc'}) {
		    my $optionvaluedesc = &gsprintf::lookup_string($optionvalue->{'desc'});

		    # Escape '<' and '>' characters
		    $optionvaluedesc =~ s/</&amp;lt;/g; #doubly escaped
		    $optionvaluedesc =~ s/>/&amp;gt;/g;

		    &gsprintf(STDERR, "          <Desc>$optionvaluedesc</Desc>\n");
		}
		&gsprintf(STDERR, "        </Value>\n");
	    }

#	    # Special case for 'input_encoding'
#	    if ($optionname =~ m/^input_encoding$/i) {
#		my $e = $encodings::encodings;
#		foreach my $enc (sort {$e->{$a}->{'name'} cmp $e->{$b}->{'name'}} keys (%$e)) {
#		    &gsprintf(STDERR, "        <Value>\n");
#		    &gsprintf(STDERR, "          <Name>$enc</Name>\n");
#		    &gsprintf(STDERR, "          <Desc>$e->{$enc}->{'name'}</Desc>\n");
#		    &gsprintf(STDERR, "        </Value>\n");
#		}
#	    }

	    &gsprintf(STDERR, "      </List>\n");
	}

	# Show the default value for the option, if there is one
	if (defined $option->{'deft'}) {
	    my $optiondeftvalue = $option->{'deft'};

	    # Escape '<' and '>' characters
	    $optiondeftvalue =~ s/</&lt;/g;
	    $optiondeftvalue =~ s/>/&gt;/g;

	    &gsprintf(STDERR, "      <Default>$optiondeftvalue</Default>\n");
	}

	# If the option is noted as being hidden in GLI, add that to the printout
	if (defined($option->{'hiddengli'})) {
	    &gsprintf(STDERR, "      <HiddenGLI>$option->{'hiddengli'}</HiddenGLI>\n");
	}
	# If the argument is not hidden then print out the lowest detail mode it is visible in
	if (defined($option->{'modegli'})) {
	    &gsprintf(STDERR, "      <ModeGLI>$option->{'modegli'}</ModeGLI>\n");
	}

	&gsprintf(STDERR, "    </Option>\n");
    }
}


sub print_txt_usage
{
    my $options = shift(@_);
    my $params = shift(@_);
    my $no_pager = shift(@_);

    unless ($no_pager) {
    # this causes us to automatically send output to a pager, if one is
    # set, AND our output is going to a terminal
    # active state perl on windows doesn't do open(handle, "-|");
    if ($ENV{'GSDLOS'} !~ /windows/ && -t STDOUT) {
        my $pager = $ENV{"PAGER"};
	if (! $pager) {$pager="(less || more)"}
	my $pid = open(STDIN, "-|"); # this does a fork... see man perlipc(1)
	if (!defined $pid) {
	    gsprintf(STDERR, "pluginfo.pl - can't fork: $!");
	} else {
	    if ($pid != 0) { # parent (ie forking) process. child gets 0
		exec ($pager);
	    }
	}
	open(STDERR,">&STDOUT"); # so it's easier to pipe output
    }
    }


    my $programname = $options->{'name'};
    my $programargs = $options->{'args'};
    my $programdesc = $options->{'desc'};

    # Find the length of the longest option string
    my $descoffset = 0;
    if (defined($programargs)) {
	$descoffset = &find_longest_option_string($programargs);
    }

    # Produce the usage information using the data structure above
    if (defined($programdesc)) {
	&gsprintf(STDERR, $programname . ": $options->{'desc'}\n\n");
    }

    &gsprintf(STDERR, " {common.usage}: $programname $params\n\n");

    # Display the program options, if there are some
    if (defined($programargs)) {
	# Calculate the column offset of the option descriptions
	my $optiondescoffset = $descoffset + 2;  # 2 spaces between options & descriptions

	&gsprintf(STDERR, " {common.options}:\n");

	# Display the program options
	&print_options_txt($programargs, $optiondescoffset);
    }
}


sub print_options_txt
{
    my $options = shift(@_);
    my $optiondescoffset = shift(@_);

    foreach my $option (@$options) {
	next if defined($option->{'internal'});

	# Display option name
	my $optionname = $option->{'name'};
	&gsprintf(STDERR, "  -$optionname");
	my $optionstringlength = length("  -$optionname");

	# Display option type, if the option is not a flag
	my $optiontype = $option->{'type'};
	if ($optiontype ne "flag") {
	    &gsprintf(STDERR, " <$optiontype>");
	    $optionstringlength = $optionstringlength + length(" <$optiontype>");
	}

	# Display the option description	
	if (defined($option->{'disp'})) {
	    my $optiondisp = &gsprintf::lookup_string($option->{'disp'});
	    &display_text_in_column($optiondisp, $optiondescoffset, $optionstringlength, 80);
	    &gsprintf(STDERR, " " x $optionstringlength);
	}
	my $optiondesc = &gsprintf::lookup_string($option->{'desc'});
	my $optionreqd = $option->{'reqd'};
	if (defined($optionreqd) && $optionreqd eq "yes") {
	    $optiondesc = "(" . &gsprintf::lookup_string("{PrintUsage.required}") . ") " . $optiondesc;
	}
	&display_text_in_column($optiondesc, $optiondescoffset, $optionstringlength, 80);

	# Show the default value for the option, if there is one
	my $optiondefault = $option->{'deft'};
	if (defined($optiondefault)) {
	    &gsprintf(STDERR, " " x $optiondescoffset);
	    &gsprintf(STDERR, "{PrintUsage.default}: $optiondefault\n");
	}

	# If the option has a list of possible values, display these
	my $optionvalueslist = $option->{'list'};
	if (defined($optionvalueslist)) {
	    &gsprintf(STDERR, "\n");
	    foreach my $optionvalue (@$optionvalueslist) {
		my $optionvaluename = $optionvalue->{'name'};
		&gsprintf(STDERR, " " x $optiondescoffset);
		&gsprintf(STDERR, "$optionvaluename:");

		my $optionvaluedesc = &gsprintf::lookup_string($optionvalue->{'desc'});
		&display_text_in_column($optionvaluedesc, $optiondescoffset + 2,
					$optiondescoffset + length($optionvaluename), 80);
	    }
	}

#	# Special case for 'input_encoding'
#	if ($optionname =~ m/^input_encoding$/i) {
#	    my $e = $encodings::encodings;
#	    foreach my $enc (sort {$e->{$a}->{'name'} cmp $e->{$b}->{'name'}} keys (%$e)) {
#		&gsprintf(STDERR, " " x $optiondescoffset);
#		&gsprintf(STDERR, "$enc:");
#
#		my $encodingdesc = $e->{$enc}->{'name'};
#		&display_text_in_column($encodingdesc, $optiondescoffset + 2,
#					$optiondescoffset + length("$enc:"), 80);
#	    }
#	}

	# Add a blank line to separate options
	&gsprintf(STDERR, "\n");
    }
}


sub display_text_in_column
{
    my ($text, $columnbeg, $firstlineoffset, $columnend) = @_;

    # Spaces are put *before* words, so treat the column beginning as 1 smaller than it is
    $columnbeg = $columnbeg - 1;

    # Add some padding (if needed) for the first line
    my $linelength = $columnbeg;
    if ($firstlineoffset < $columnbeg) {
	&gsprintf(STDERR, " " x ($columnbeg - $firstlineoffset));
    }
    else {
	$linelength = $firstlineoffset;
    }

    # Break the text into words, and display one at a time
    my @words = split(/ /, $text);

    foreach my $word (@words) {
	# If printing this word would exceed the column end, start a new line
	if (($linelength + length($word)) >= $columnend) {
	    &gsprintf(STDERR, "\n");
	    &gsprintf(STDERR, " " x $columnbeg);
	    $linelength = $columnbeg;
	}

	# Write the word
	&gsprintf(STDERR, " $word");
	$linelength = $linelength + length(" $word");
    }

    &gsprintf(STDERR, "\n");
}


sub find_longest_option_string
{
    my $options = shift(@_);

    my $maxlength = 0;
    foreach my $option (@$options) {
	my $optionname = $option->{'name'};
	my $optiontype = $option->{'type'};

	my $optionlength = length("  -$optionname");
	if ($optiontype ne "flag") {
	    $optionlength = $optionlength + length(" <$optiontype>");
	}

	# Remember the longest
	if ($optionlength > $maxlength) {
	    $maxlength = $optionlength;
	}
    }
    return $maxlength;
}


1;
