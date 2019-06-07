#!/bin/sh

glihome=$GSDLHOME/gli

lang=$1
if [ "x$lang" == "x" ]; then
    lang=en
fi

if [ "$glihome" == "" ]; then
    # assume glihelp in its usual place
      pushd ../ > /dev/null
      glihome=`pwd`
      popd > /dev/null
fi

if test ! -d "$glihome/shared"; then
    #echo "Please checkout http://svn.greenstone.org/documentation/trunk/shared into gli (as gli/shared)"
    #echo "Then run ./COMPILE-ALL.sh(bat)"
    echo ""
    echo "**** Will checkout http://svn.greenstone.org/documentation/trunk/shared into gli (as gli/shared)"
    svn co http://svn.greenstone.org/documentation/trunk/shared $glihome/shared
    echo ""
    echo "**** Will compile the $glihome/shared folder with ./COMPILE-ALL.sh"
    pushd $glihome/shared
    ./COMPILE-ALL.sh
    popd
    echo ""
fi

if test -d "$glihome/shared"; then
    echo "processing $lang version"
    cd $lang
    java -cp $glihome/shared:$glihome/shared/xalan.jar -DGSDLHOME=$GSDLHOME ApplyXSLT $lang ../gen-many-html.xsl help.xml | perl -S ../splithelpdocument.pl
    java -cp $glihome/shared:$glihome/shared/xalan.jar -DGSDLHOME=$GSDLHOME ApplyXSLT $lang ../gen-index-xml.xsl help.xml > help_index.xml
    cd ..
else
    echo "Tried to svn checkout http://svn.greenstone.org/documentation/trunk/shared into gli/shared, but did not succeed"
fi


