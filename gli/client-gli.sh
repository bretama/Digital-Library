#!/bin/bash
glilang=en

if [ "x$PROGNAME" = "x" ] ; then
    PROGNAME="Greenstone"
  if [ "$glilang" = "es" ]; then
    PROGFULLNAME="Biblioteca Digital Greenstone"
  elif [ "$glilang" = "fr" ]; then
    PROGFULLNAME="BibliothИcaire Greenstone"
  elif [ "$glilang" = "ru" ]; then
    PROGFULLNAME="интерфейс Greenstone"
  else
    PROGFULLNAME="Greenstone Digital Library"
  fi
  else
    PROGFULLNAME=$PROGNAME
fi
export PROGNAME
export PROGFULLNAME

if [ "x$PROGABBR" = "x" ] ; then
    PROGABBR="Client-GLI"
fi
export PROGABBR

if [ "x$PROGNAME_EN" = "x" ] ; then
    PROGNAME_EN="Greenstone Librarian Interface - Remote Client"
fi
export PROGNAME_EN

# we're running GLI (or FLI) in client mode
GLIMODE="client"


echo
if [ "$glilang" = "es" ]; then
    echo "Interfaz de la $PROGFULLNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "La Interfaz de la $PROGNAME NO INCLUYE ABSOLUTAMENTE NINGUNA GARANTмA."
    echo "Para mayor informaciСn vea los tИrminos de la licencia en LICENSE.txt"
    echo "Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita"
elif [ "$glilang" = "fr" ]; then
    echo "Interface du $PROGFULLNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "$PROGABBR est fourni sans AUCUNE GARANTIE; pour des dИtails, voir LICENSE.txt"
    echo "Ceci est un logiciel libre, et vous Йtes invitИ Ю le redistribuer"
elif [ "$glilang" = "ru" ]; then
    echo "Библиотечный $PROGFULLNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "БИГ не дает АБСОЛЮТНО НИКАКИХ ГАРАНТИЙ; детали см. в тексте LICENSE.TXT"
    echo "Это - свободно распространяемое программное обеспечение и Вы можете распространять его"
else
    echo "$PROGNAME Librarian Interface ($PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "$PROGABBR comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt"
    echo "This is free software, and you are welcome to redistribute it"
fi
echo

##  -------- Run the Greenstone Librarian Interface --------
# Need to run this script from its own directory instead of whichever directory it may be called from
#currentdir=$(cd `dirname "$0"` && pwd)
thisdir="`dirname \"$0\"`"
thisdir="`cd \"$thisdir\" && pwd`"
cd "$thisdir"

##  ---- Determine GSDLHOME to see if the download panel can be enabled ----
# Need to source a script in order to inherit the env vars it has set.
# Try to detect a local GSDLHOME installation (need gs2build). If none can
# be found, then client-gli won't have a download panel. We're calling 
# findgsdl.bat purely for knowing if there's a GSDLHOME around and to set and
# use that for downloading. If there IS a local GSDLHOME, then we can download
# (and build) locally, but ONLY if we have perl. Else downloading and building
# will have to be done remotely anyway. If Perl is found, PERLPATH will be set.
source ./findgsdl.sh
local_gs="false"
if [ "x$GSDLHOME" != "x" ] ; then
    # GSDLHOME set, test for perl
    # no need to source the findperl script since it does not set env vars
    exit_status=0
    ./findperl.sh
    exit_status=$?
    if [ "$exit_status" -ne 1 ]; then
	local_gs="true"
    fi 
fi


## ---- findJava ----
# call the script with source, so that we have the variables it sets ($javapath)
exit_status=0
source ./findjava.sh "$glilang" "$PROGABBR"
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi

## ---- Check that the GLI has been compiled ----
if [ ! -f "classes/org/greenstone/gatherer/GathererProg.class" ] && [ ! -f "GLI.jar" ]; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "Usted necesita compilar la Interfaz de la $PROGFULLNAME"
	echo "(por medio de makegli.sh) antes de ejecutar este guiСn."
    elif [ "$glilang" = "fr" ]; then
	echo "Vous devez compiler le $PROGNAME Interface (en utilisant makegli.sh)"
	echo "avant d'exИcuter ce script."
    elif [ "$glilang" = "ru" ]; then
	echo "Вы должны компилировать библиотечный интерфейс $PROGNAME"
	echo "(используя makegli.sh) перед вводом этого скрипта"
    else
	echo "You need to compile the $PROGNAME Librarian Interface (using makegli.sh)"
	echo "before running this script."
    fi
    exit 1
fi


## ---- Finally, run the GLI ----
echo
if [ "$glilang" = "es" ]; then
    echo "Ejecutando la Interfaz de la $PROGFULLNAME..."
elif [ "$glilang" = "fr" ]; then
    echo "ExИcution de $PROGNAME Librarian Interface"
elif [ "$glilang" = "ru" ]; then
    echo "Текущий библиотечный интерфейс $PROGNAME..."
else
    echo "Running the $PROGNAME Librarian Interface..."
fi

# Other arguments you can provide to GLI to work around memory limitations, or debug
# -Xms<number>M    To set minimum memory (by default 32MB)
# -Xmx<number>M    To set maximum memory (by default the nearest 2^n to the total remaining physical memory)
# -verbose:gc      To set garbage collection messages
# -Xincgc          For incremental garbage collection (significantly slows performance)
# -Xprof           Function call profiling
# -Xloggc:<file>   Write garbage collection log

# -Xdock:name      To set the name of the app in the MacOS Dock bar
# -Xdock:icon      Path to the MacOS Doc icon (not necessary for GS)    
custom_vm_args=""
if [ "$GSDLOS" = "darwin" ]; then
    custom_vm_args="-Xdock:name=$PROGABBR"
    if [ -f "../client-gli.app/Contents/Resources/AutomatorApplet.icns" ]; then
	custom_vm_args="$custom_vm_args -Xdock:icon=../client-gli.app/Contents/Resources/AutomatorApplet.icns"
    fi
fi

# GS2 only requires -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar. GS3 requires more but it doesn't conflict with GS2:
if [ "$local_gs" = "false" ]; then
    echo "Since there's no GSDLHOME, client-GLI's download panel will be deactivated."
    echo
    $javapath -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar:lib/commons-codec-1.3.jar:lib/commons-httpclient-3.1-rc1.jar:lib/commons-logging-1.1.jar $custom_vm_args org.greenstone.gatherer.GathererProg -use_remote_greenstone $*
else
    gsdlos=`uname -s | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'`
    # check for running bash under cygwin
    if test "`echo $gsdlos | sed 's/cygwin//'`" != "$gsdlos" ; then
	gsdlos=windows
    fi
    echo "Perl and GSDLHOME ($GSDLHOME) detected."
    echo "Downloading is enabled."
    echo
    $javapath -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar:lib/commons-codec-1.3.jar:lib/commons-httpclient-3.1-rc1.jar:lib/commons-logging-1.1.jar $custom_vm_args org.greenstone.gatherer.GathererProg -use_remote_greenstone -gsdl "$GSDLHOME" -gsdlos $gsdlos $*
fi

if [ "$glilang" = "es" ]; then
    echo "║Hecho!"
elif [ "$glilang" = "fr" ]; then
    echo "TerminИ!"
elif [ "$glilang" = "ru" ]; then
    echo "Выполнено!"
else
    echo "Done!"
fi