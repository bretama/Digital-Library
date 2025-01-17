@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
IF EXIST "%~dp0perl.exe" (
"%~dp0perl.exe" -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
) ELSE IF EXIST "%~dp0..\..\bin\perl.exe" (
"%~dp0..\..\bin\perl.exe" -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
) ELSE (
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
)

goto endofperl
:WinNT
IF EXIST "%~dp0perl.exe" (
"%~dp0perl.exe" -x -S %0 %*
) ELSE IF EXIST "%~dp0..\..\bin\perl.exe" (
"%~dp0..\..\bin\perl.exe" -x -S %0 %*
) ELSE (
perl -x -S %0 %*
)

if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!/usr/bin/perl -w
#line 29
#========================================================================
#
# tpage
#
# DESCRIPTION
#   Script for processing and rendering a template document using the 
#   Perl Template Toolkit. 
#
# AUTHOR
#   Andy Wardley   <abw@cre.canon.co.uk>
#
# COPYRIGHT
#   Copyright (C) 1996-1999 Andy Wardley.  All Rights Reserved.
#   Copyright (C) 1998-1999 Canon Research Centre Europe Ltd.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
#------------------------------------------------------------------------
#
# $Id: tpage,v 1.3 1999/08/16 14:44:50 abw Exp $
#
#========================================================================

use strict;
use Template;

# look for -h or --help option, print usage and exit
if (grep /^--?h(elp)?/, @ARGV) {
    print "usage: tpage file [ file [...] ]\n";
    exit 0;
}

# read from STDIN if no files specified
push(@ARGV, '-') unless @ARGV;

# create a template processor 
my $template = Template->new();

# process each input file 
foreach my $file (@ARGV) {
    $file = \*STDIN if $file eq '-';
    $template->process($file)
	|| die $template->error();
}



__END__

=head1 NAME

tpage - processes template documents using the Perl Template Toolkit.

=head1 USAGE

    tpage file [ file [...] ]

=head1 DESCRIPTION

The B<tpage> script is a simple wrapper around the Template Toolkit processor.
Files specified by name on the command line are processed in turn by the 
template processor and the resulting output is sent to STDOUT and can be 
redirected accordingly.

e.g.
    tpage myfile > myfile.out
    tpage header myfile footer > myfile.html

If no file names are specified on the command line then B<tpage> will read
STDIN for input.

See L<Template> for general information about the Perl Template 
Toolkit and the template language and features.

=head1 AUTHOR

Andy Wardley E<lt>cre.canon.co.ukE<gt>

=head1 REVISION

$Revision: 1.3 $

=head1 COPYRIGHT

Copyright (C) 1996-1999 Andy Wardley.  All Rights Reserved.
Copyright (C) 1998-1999 Canon Research Centre Europe Ltd.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template|Template>

=cut



__END__
:endofperl
