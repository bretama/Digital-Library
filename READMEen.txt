Title	Greenstone digital library software

Purpose
		A suite of digital library software which includes the ability to
		serve digital library collections and build new collections

Author	New Zealand Digital Library Project

License
		GNU General Public Licence (Version 2)
		Full terms and conditions are in the file "LICENSE.txt"

Date	September 2017

Version 2.87

Contents: Programs

	Greenstone library server
		A cgi program to serve digital library collections

	Greenstone server interface (GSI)
		A graphical interface to start/stop the library server (see notes below)

	Greenstone oaiserver
		A cgi program to serve collections using the OAI-PMH protocol.

	Greenstone Librarian Interface (GLI)
		A graphical tool for collection building

	Greenstone Editor for Metadata Sets (GEMS)
		A graphical tool for creating and editing metadata sets used by GLI

Contents: Directory Structure

	bin		Executable code
	cgi-bin		CGI scripts
	collect		Collections
	etc		Configuration files, log files, user databases etc
	gli		Librarian Interface
	images		Images and CSS files used by the interface
	macros		Display macros
	mappings	Unicode translation tables
	perllib		Perl modules used for collection building

	If source code is present (from a source release or by adding the 
	source component):

	common-src	Source code and packages used when building collections and at
				runtime
	build-src	Source code and packages only used when building collections
	runtime-src	Source code and packages only used at runtime

Contents: Additional Packages (available only in full binary releases)

	Java Runtime 1.6 (installer release only)
	ImageMagick
	Ghostscript (Windows, Mac only)
	Perl (Windows only)

Documentation and Support
	Greenstone Website:
		http://www.greenstone.org
		Greenstone's main website.
	Greenstone Wiki: 
		http://wiki.greenstone.org
		Contains documentation, and links to manuals, tutorials etc.
	Greenstone Mailing List:
		(to subscribe)		
		http://list.waikato.ac.nz/mailman/listinfo/greenstone-users
		(to post)
		greenstone-users@list.waikato.ac.nz
	New Zealand Digital Library: 
		http://www.nzdl.org
		A demonstration site containing lots of collections


Platform
	Greenstone runs on Unix, Windows 2000/XP/2003/Vista/2008 and 
	Mac OS 10.5.2 (Leopard).

	The Greenstone Librarian Interface requires version 1.5 or later 
	of the Java Runtime Environment. Java 1.6 is included in binary 
	releases of Greenstone.

	The Greenstone user interface uses a Web browser capable of Javascript,
	Tables, and Frames. Browsers that meet these requirements include:

		Netscape Navigator 4.0
		Internet Explorer 4.0
		Mozilla
		Safari

	More recent versions of these browsers should also work (recommended).
		
Unix
	Source code has been compiled and tested on the following 
	distributions:

		Ubuntu 8.04 & 8.10
		Mandriva 2008 Spring
		OpenSUSE 11
		Fedora 6 & 9
		CentOS 5.2


Windows
	Source code can be compiled with Microsoft Visual C++ 6.0, 7 
	(VS 2003.Net), 8 (VS 2005 Pro or VC++ Express 2005 with Microsoft 
	Platform SDK 2003 R2).

	Binary code has been tested on 32 bit versions of:
		Windows 2000
		Windows XP
		Windows Server 2003
		Windows Vista
		Windows Server 2008

	Greenstone software (version 2.81 and later) no longer runs on 
		Windows 3.1
		Windows 95
		Windows 98
		Windows Me
		Windows NT

Mac
	Source code has been compiled with Xcode 3.1 on Intel Mac OS 10.5.2.
	Binary has been tested on Intel Mac OS 10.5.2 (Leopard).

	However the source code can be compiled with other versions of Mac OS 
	and Xcode, in that case please download Imagemagick and Ghostscript to 
	recompile them from source.



The Greenstone Server Interface (GSI)

	This is the application with a graphical user interface that allows you to
	stop and start greenstone's Local Library Server (LLS) and change a few
	settings like the server's port number. On Linux and Mac it uses the apache
	web server that comes with Greenstone and on Windows it uses a separate
	server program.

	The Greenstone 2.8x binary release comes with the Local Library Server
	ready for use.

	If you're on Windows, then you can click on the Greenstone Server shortcut
	in your Start Menu to run it.

	If on Linux, you run it by executing the following from your Greenstone
	installation directory:

		./gs2-server.sh

	This starts up the Greenstone Server Interface (GSI). Certain server
	settings can be changed through its File > Settings menu.

	For instructions on how to compile up the Local Library Server on Unix
	systems and for further details on how to start the server through the
	command line (without using the graphical interface of the GSI application),
	see below.


Local Library Server (LLS) on LINUX AND MAC
	We've not tested the Local Library Server on Unix systems other than Linux
	and Mac, but you can try the following out.

	SUMMARY
	1. If you're compiling and running it, run the following in sequence from your Greenstone installation directory:
		./configure --enable-apache-httpd
		make
		make install

	2.a Then you can launch the GSI graphical user application with:
		./gs2-server.sh

	2.b OR
		If working on the command-line, you first need to configure the server
		after compilation with:
			./gsicontrol.sh configure-web
		Then run it with:
			./gsicontrol.sh web-start
		To stop it, use:
			./gsicontrol.sh web-stop

		(If your Unix system can handle Makefiles, you can issue simila
		commands to "make" as to gsicontrol.sh:
			make configure-web
			make web-start
			make web-stop)

		For a list of all commands that the gsi-control script takes (which is
		what the Makefile ends up calling anyway), type
			./gsicontrol.sh
		This script can be used to change your Greenstone Admin password and
		change the port number of your server. The same commands can also be
		issued by running "make <command>", if your Unix machine can handle
		Makefiles.
		Some of this functionality to control the Local Library Server is also
		available through the graphical GSI application, from its
		File > Settings menu. 


	If you've started the Local Libary Server, you can view the collections and
	the documents it serves up by going to your digital library home. This is at
	a URL that is of the form:
		http://localhost:<portnumber>/greenstone/cgi-bin/library.cgi
	by default it will try to use port 80 if this is available and accessible.
	If you're using the GSI application and port 80 is in use, it will assign a
	new one. Alternatively, you can change the port number
		- through the File > Settings menu of the GSI application.
		- or change it in the llssite.cfg file located in the Greenstone
		  installation directory and then run
			./gsicontrol.sh configure-apache

	The GSI application will launch the library home page for you in your
	browser if you click the button marked "Enter Library" or "Restart Library".
