
*******
* gnome-lib
*******

For most Linux distributions it is also necessary to check out the
'gnome-lib' extension and compile this up *first* before compiling the main
source code -- be it Greenstone2 or Greenstone3 you are looking to work
with, as the latter makes use of Greestone2's building code, and get's
checked out as 'gs2build'.  

Starting in this 'ext' folder you can do this by:

  svn co http://svn.greenstone.org/gs2-extensions/gnome-lib/trunk/src gnome-lib
  cd gnome-lib
  source devel.sh
  ./CASCADE-MAKE.sh

Assuming this completes successfully, now return to your top-level
Greenstone directory and follow the instructions for compiling that.

ALTERNATIVELY ... you could try the pre-bundled binary version.

On MacOS:

  curl http://svn.greenstone.org/gs2-extensions/gnome-lib/trunk/gnome-lib-darwin-intel.tar.gz \
   > gnome-lib-darwin-intel.tar.gz
  tar xvzf gnome-lib-darwin-intel.tar.gz


*******
* open-office
*******

A good optional extra to put in is the OpenOffice extension, with which 
you can build higher quality DL collections sourced from MS Office docs.



  http://trac.greenstone.org/export/27101/gs2-extensions/open-office/trunk/open-office-java.tar.gz

  http://trac.greenstone.org/export/27101/gs2-extensions/open-office/trunk/open-office-java.zip
