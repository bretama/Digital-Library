GNUfile is the Windows version of the Linux file utility.
GNUfile can be used to detect the bitness (32 or 64 bit) of an executable.
The GNUfile executable itself is a 32 bit application.
It was suggested by http://stackoverflow.com/questions/2689168/checking-if-file-is-32bit-or-64bit-on-windows

GNUfile was downloaded as a zipped binary along with the dependencies zip from http://gnuwin32.sourceforge.net/packages/file.htm
The contents of the two zip files were merged into the new GNUfile zip directory that lives in GS2/bin/windows/GNUfile
Its license is at http://gnuwin32.sourceforge.net/license.html


Run as:
file.exe <exe>

e.g. GNUfile\bin\file.exe wvWare.exe

Output for 32-bit compiled wvWare mentions "PE32":
	wvWare.exe; PE32 executable for MS Windows (console) Intel 80386 32-bit

When run on 64bit executables like 7zip 7z.exe below, GNUfile's output mentions "PE32+":

	C:\Program Files\7-Zip\7z.exe; PE32+ executable for MS Windows (console) Mono/.Net assembly 