###########################################################################
#
# parseargv.pm --
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

package parsargv;

use strict;

# 
# parse(ARGVREF, [SPEC, VARREF] ...)
# 
# Parse command line arguments.
# 
# ARGVREF is an array reference, usually to @ARGV.  The remaining
# arguments are paired (SPEC, VARREF).  SPEC is a specification string
# for a particular argument; VARREF is a variable reference that will
# receive the argument.
# 
# SPEC is in one of the following forms:
# 
# ARG/REGEX/DEFAULT ARG is the name of command line argument.  REGEX is
#     a regular expression that gives legal values for the argument.
#     DEFAULT is the default value assigned to VARREF if the option does
#     not appear on the command line.  Example
# 
# 
# ARG/REGEX ARG and REGEX are as above.  Since no default is given, ARG
#     must appear on the command line; if it doesn't, parse() returns 0.
# 
# ARG ARG is as above.  ARG is a boolean option.  VARREF is assigned 0 if ARG
#     is not on the command line; 1 otherwise.
# 
# SPEC may start with a punctuation character, in which case this
# character will be used instead of '/' as a delimiter.  Useful when '/'
# is needed in the REGEX part.
# 
# VARREF is a reference to a scalar or an array.  If VARREF is an array
# reference, then multiple command line options are allowed an append.  Example:
# 
# 	Command line: -day mon -day fri
# 
# 	parse(\@ARGV, "day/(mon|tue|wed|thu|fri)", \@days)
# 
# 	days => ('mon', 'fri')
# 
# Returns 0 if there was an error, nonzero otherwise.
# 

 
sub parse
{
    my $arglist = shift;
    my ($spec, $var);
    my %option;

    my @rest = @_;


    # if the last argument is the string "allow_extra_options" then options
    # in \@rest without a corresponding SPEC will be ignored (i.e. the "$arg is
    # not a valid option" error won't occur)\n";
    my $allow_extra_options = pop @rest;
    if (defined ($allow_extra_options)) {
	if ($allow_extra_options eq "allow_extra_options") {
	    $allow_extra_options = 1;
	} else {
	    # put it back where we got it
	    push (@rest, $allow_extra_options);
	    $allow_extra_options = 0;
	}
    } else {
	$allow_extra_options = 0;
    }

    while (($spec, $var) = splice(@rest, 0, 2))
        {
	  
	die "Variable for $spec is not a valid type."
	    unless ref($var) eq 'SCALAR' || ref($var) eq 'ARRAY'
	    || (ref($var) eq 'REF' && ref($$var) eq 'GLOB');

	my $delimiter;
	if ($spec !~ /^\w/)
	{
	    $delimiter = substr($spec, 0, 1);
	    $spec = substr($spec, 1);
	}
	else
	{
	    $delimiter = '/';
	}
	my ($name, $regex, $default) = split(/$delimiter/, $spec, 3);
	
	
	if ($name)
	{   
	    if ($default && $default !~ /$regex/)
	    {
		die "Default value for $name doesn't match regex ($spec).";
	    }
	    $option{$name} = {'name' => $name,
			      'regex' => $regex,
			      'default' => $default,
			      'varref' => $var,
			      'set' => 0};
	}
	else
	{
	    die "Invalid argument ($spec) for parsargv.";
	}
    }

    my @argv;
    my $arg;
    my $parse_options = 1;
    my $errors = 0;

    while ($arg = shift(@$arglist))
    {
	if ($parse_options && $arg eq '--')
	{
	    $parse_options = 0;
	    next;
	}

	if ($parse_options && $arg =~ /^-+\w/)
	{
	    $arg =~ s/^-+//;

	    if (defined $option{$arg})
	    {
		&process_arg($option{$arg}, $arglist, \$errors);
	    }
	    elsif (!$allow_extra_options)
	    {
		print STDOUT "$arg is not a valid option.\n";
		$errors++;
	    }
	}
	else
	{
	    push(@argv, $arg);
	}
    }
    @$arglist = @argv;

    foreach $arg (keys %option)
    {
	if ($option{$arg}->{'set'} == 0)
	{
	    if (defined $option{$arg}->{'default'})
	    {
		&set_var($option{$arg}, $option{$arg}->{'default'});
	    }
	    elsif (!$option{$arg}->{'regex'})
	    {
		&set_var($option{$arg}, 0)
	    }
	    elsif (ref($option{$arg}->{'varref'}) ne 'ARRAY')
	    {
		print STDOUT "Missing command line argument -$arg.\n";
		$errors++;
	    }
	}
    }
    return $errors == 0;
}

sub process_arg
{
    my ($option, $arglist, $errors) = @_;

    if ($option->{'regex'} && @$arglist > 0 && $arglist->[0] !~ /^-+\w/)
    {
	if ($arglist->[0] =~ /$option->{'regex'}/)
	{
	    &set_var($option, shift(@$arglist));
	}
	else
	{
	    print STDOUT  "Bad value for -$option->{'name'} argument.\n";
	    $$errors++;
	}
    }
    elsif (!$option->{'regex'})
    {
	&set_var($option, 1);
    }
    else
    {
	print STDOUT "No value given for -$option->{'name'}.\n";
	$$errors++;
    }
}

sub set_var
{
    my ($option, $value) = @_;
    my $type = ref($option->{'varref'});

    if ($type eq 'SCALAR')
    {
	${$option->{'varref'}} = $value;
    }
    elsif ($type eq 'ARRAY')
    {
	push(@{$option->{'varref'}}, $value);
    }
    $option->{'set'} = 1;
}

1;








