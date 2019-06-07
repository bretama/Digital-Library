The Greenstone Librarian Interface
----------------------------------

This folder contains the Greenstone Librarian Interface (GLI), a tool to
assist you with building digital libraries using Greenstone. The GLI gives
you access to Greenstone's functionality from an easy-to-use, 'point and
click' interface.

To use the GLI, you need a suitable version of the Java Runtime Environment
(version 1.4.0 or newer). If you don't already have one, you can download
one from http://java.sun.com/j2se/downloads.html

Note that the GLI is run in conjunction with Greenstone, and assumes that
it is installed in a subdirectory of your Greenstone installation. If you
have downloaded one of the Greenstone distributions, or installed from a 
Greenstone CD-ROM, this will be the case.


-- Running the GLI under Windows --

To run the GLI under Windows, browse to the GLI folder in your Greenstone
installation (using Windows Explorer), and double-click on the gli.bat
file. This file will check that Greenstone, Perl, and the Java Runtime
Environment are installed, then start the Greenstone Librarian Interface.


-- Running the GLI under Unix --

To run the GLI under Unix, change to the GLI directory in your Greenstone
installation, then run the gli.sh script. This script will check that
Greenstone, Perl, and the Java Runtime Environment are installed (make sure
they are on your search path), then start the Greenstone Librarian
Interface.


Please report any problems you have running or using the Librarian
Interface to greenstone@cs.waikato.ac.nz.


-- Compiling the GLI --

If you have downloaded the Greenstone source distribution, or you have
obtained the GLI via SVN, you will have the source code (Java) of the
Librarian Interface. Compiling it requires a suitable version of the Java
Software Development Kit (version 1.4.0 or newer). You can download one
from http://java.sun.com/j2se/downloads.html

To compile this source code, run the makegli.bat (Windows) or makegli.sh
(Unix) files. Once this has been done, you can run the GLI using the
instructions above.
