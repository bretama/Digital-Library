#
# Python Cron
# by Emilio Schapira
# Copyright (C) 2003 Advanced Interface Technologies, Inc.
# http://www.advancedinterfaces.com
# http://sourceforge.net/projects/pycron/
#

**
** INTRODUCTION
**

This is a clone of the well-known cron job scheduler for the unix flavored 
operating systems. It is implemented in Python. The main motivation for the 
project is to provide a robust cron daemon for the Microsoft Windows* 
operating system. However, Python Cron is platform-independant, and can 
be used on any operating system that supports python.
 
CygWin (http://www.cygwin.com/) provides a robust implementation of the cron 
daemon, however it requires installing the full cygwin package. There are 
currently other alternatives that are either not robust, not free or not 
open source. Examples of these alternatives are WinCron 
(http://www.wincron.co.uk/), Cron (http://www.kalab.com/freeware/cron/cron.htm).
 
This implementation is very simple, complete and robust.

**
** USAGE
**

usage: cron [crontab_file_name [log_file_name [pid_file_name]]]

    crontab_file_name     Name and location of the crontab file. By
                          default it is ./crontab
    log_file_name         Name and location of the log file. By default
                          it is ./cron.log
    pid_file_name         Name and location of the pid file. This file
                          will contain the process id of the cron
                          process. It can be used later to stop the cron
                          file. By default it is ./cron.pid

**
** Crontab files
**

A contrab file contains one command per line, except empty lines and
lines starting with the character #, which are considered as comments.
This file will be scanned every minute when cron is running.

Each command has the format:

<minute> <hour> <day of month> <month> <day of week> <command> <args>

Cron will scan each entry and match the first five values with the
current local time and date. The entries for each of these values must 
be either:

  - A number. For <month> it is the month number, and for <day of week>
    is the day number starting with Sunday=0.
  - An asterisk (*) which indicates that any value matches this field.
  - Comma separated numbers that indicate that each of the values can
    match this field.

The 6th argument, <command>, is the name of the program to run. The remaining
arguments are passed to the programm <command> as command-line arguments.

Example cron entries

0 * * * * echo "run every hour"

0 3 * * * echo "run every day at 3am"

30,0 * * * * echo "run every half hour"

45 15 * * 1 echo "run every monday at 3:45pm"

0 4 15 * * echo "run on the 15th of every month at 4am"

**
** Windows 
**

This example is for Windows 2K.

1.- Unzip the package in c:\Program Files\pycron.

2.- You can create a shorcut in the startup folder, with 
    the following properties:

  Target = C:\Program Files\Python22\pythonw.exe C:\Program Files\pycron\cron.py
  Start In = C:\Program Files\pycron

You will notice that console processes are launched in a new console window.
To avoid this, use the provided program silentstart in your crontab file. For
example:

# Run backup script every morning at 3am
0 3 * * * silentstart c:\scripts\backup.bat

silentstart.exe must be in the path. You can copy it to c:\winnt\system32.

**
** Limitations
**

- Crontab files can not have environment variable definitions.
- pycron doeas not support the expresions of the form /2, month
  or day of the week names, or dash expresions such as 5-9.

