#!/bin/bash

glilang=en

if [ "x$PROGNAME" = "x" ] ; then
  if [ "$glilang" = "es" ]; then
    PROGNAME="Biblioteca Digital Greenstone"
  elif [ "$glilang" = "fr" ]; then
    PROGNAME="BibliothИcaire Greenstone"
  elif [ "$glilang" = "ru" ]; then
    PROGNAME="интерфейс Greenstone"
  else
    PROGNAME="Greenstone Librarian Interface"
  fi
fi

if [ "x$PROGABBR" = "x" ] ; then
    PROGABBR="GLI"
fi

if [ "x$PROGNAME_EN" = "x" ] ; then
    PROGNAME_EN="Greenstone Librarian Interface"
fi

if [ "x$GLIMODE" = "x" ] ; then
    GLIMODE="local"
fi

echo
if [ "$glilang" = "es" ]; then
    echo "Interfaz de la $PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2006, New Zealand Digital Library Project, University Of Waikato"
    echo "La Interfaz de la $PROGNAME NO INCLUYE ABSOLUTAMENTE NINGUNA GARANTмA."
    echo "Para mayor informaciСn vea los tИrminos de la licencia en LICENSE.txt"
    echo "Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita"
elif [ "$glilang" = "fr" ]; then
    echo "Interface du $PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2006, New Zealand Digital Library Project, University Of Waikato"
    echo "$PROGABBR est fourni sans AUCUNE GARANTIE; pour des dИtails, voir LICENSE.txt"
    echo "Ceci est un logiciel libre, et vous Йtes invitИ Ю le redistribuer"
elif [ "$glilang" = "ru" ]; then
    echo "Библиотечный $PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2006, New Zealand Digital Library Project, University Of Waikato"
    echo "БИГ не дает АБСОЛЮТНО НИКАКИХ ГАРАНТИЙ; детали см. в тексте LICENSE.TXT"
    echo "Это - свободно распространяемое программное обеспечение и Вы можете распространять его"
else
    echo "$PROGNAME ($PROGABBR)"
    echo "Copyright (C) 2006, New Zealand Digital Library Project, University Of Waikato"
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


##  ---- Determine GSDLHOME ----
# need to source a script in order to inherit the env vars it has set
# Exit on error code (non-zero)
exit_status=0
source ./findgsdl.sh
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi

## ---- find perl ----
# no need to source the findperl script since it does not set env vars
exit_status=0
./findperl.sh
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi

## ---- Check Java ----
# call the script with source, so that we have the variables it sets ($javapath)
exit_status=0
source ./findjava.sh "$glilang" "$PROGNAME"
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi
## if we're using a bundled java in GS2, then put the bundled java into the environment too (don't just use it to launch GLI)
#if [[ $javapath == *"/packages/jre"* ]]; then
#    if [ "$_version" -eq 2 ]; then
#	export JRE_HOME=$GSDLHOME/packages/jre
## Shouldn't be necessary to set JAVA_HOME to JRE_HOME. If only JRE_HOME exists, it should suffice for GLI:
#	##export JAVA_HOME=$JRE_HOME
#	echo "@@@ SETTING JAVA ENV TO THE BUNDLED JRE: JRE_HOME: $JRE_HOME"
#	export PATH=$JRE_HOME/bin:$PATH
#    fi
#fi


## ---- Check that the GLI has been compiled ----
if [ ! -f "classes/org/greenstone/gatherer/GathererProg.class" ] && [ ! -f "GLI.jar" ]; then
    echo
    if [ "$glilang" = "es" ]; then
    echo "Usted necesita compilar la Interfaz de la Biblioteca Digital Greenstone"
    echo "(por medio de makegli.sh) antes de ejecutar este guiСn."
    elif [ "$glilang" = "fr" ]; then
    echo "Vous devez compiler le Greenstone Interface (en utilisant makegli.sh)"
    echo "avant d'exИcuter ce script."
    elif [ "$glilang" = "ru" ]; then
    echo "Вы должны компилировать библиотечный интерфейс Greenstone"
    echo "(используя makegli.sh) перед вводом этого скрипта"
    else
    echo "You need to compile the Greenstone Librarian Interface (using makegli.sh)"
    echo "before running this script."
    fi
    exit 1
fi

## ---- Explain how to bypass Imagemagick and Ghostscript bundled with Greenstone if needed ----
if [ -e "$GSDLHOME/bin/$GSDLOS/ghostscript" ] ; then
echo "GhostScript bundled with Greenstone will be used, if you wish to use the version installed on your system (if any) please go to $GSDLHOME/bin/$GSDLOS and rename the folder called ghostscript to something else."
fi
echo
echo
if [ -e "$GSDLHOME/bin/$GSDLOS/imagemagick" ] ; then
echo "ImageMagick bundled with Greenstone will be used, if you wish to use the version installed on your system (if any) please go to $GSDLHOME/bin/$GSDLOS and rename the folder called imagemagick to something else."
echo
echo
fi


## ---- Finally, run the GLI ----
if [ "$glilang" = "es" ]; then
    echo "Ejecutando la Interfaz de la $PROGNAME..."
elif [ "$glilang" = "fr" ]; then
    echo "ExИcution de $PROGNAME..."
elif [ "$glilang" = "ru" ]; then
    echo "Текущий библиотечный $PROGNAME..."
else
    echo "Running the $PROGNAME..."
fi

# basic_command is the cmd string common to both Greenstone 3 and Greenstone 2 execution
#basic_command="$javapath -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg"
stop_gli=0
while [ "$stop_gli" = "0" ] ; do 
    
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
	if [ -f "../gli.app/Contents/Resources/AutomatorApplet.icns" ]; then
	   custom_vm_args="$custom_vm_args -Xdock:icon=../gli.app/Contents/Resources/AutomatorApplet.icns"
	fi
    fi
    
    exit_status=0
    if [ "$_version" -eq 2 ]; then
# GS2 webLib
	if [ "$PROGABBR" = "FLI" -o ! -f "$GSDLHOME/gs2-server.sh" ]; then
	    "$javapath" -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar $custom_vm_args org.greenstone.gatherer.GathererProg -gsdl "$GSDLHOME" -gsdlos $GSDLOS $*
	    exit_status=$?
# GS2 localLib
	else
	    "$javapath" -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar $custom_vm_args org.greenstone.gatherer.GathererProg -gsdl "$GSDLHOME" -gsdlos $GSDLOS -local_library "$GSDLHOME/gs2-server.sh" $*
	    exit_status=$?
	fi
# GS3
    elif [ "$_version" -eq 3 ]; then    
        "$javapath" -Xmx128M -classpath classes/:GLI.jar:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar $custom_vm_args org.greenstone.gatherer.GathererProg -gsdl "$GSDLHOME" -gsdlos $GSDLOS -gsdl3 "$GSDL3HOME" -gsdl3src "$GSDL3SRCHOME" $*
        exit_status=$?
    fi
    
    if [ "$exit_status" != "2" ] ; then
        stop_gli=1
    else
        echo
        if [ "$glilang" = "es" ]; then
            echo "Restarting/Ejecutando la Interfaz de la $PROGNAME..."
        elif [ "$glilang" = "fr" ]; then
            echo "Restarting/ExИcution de $PROGNAME..."
        elif [ "$glilang" = "ru" ]; then
            echo "Restarting/Текущий библиотечный $PROGNAME..."
        else
            echo "Restarting the $PROGNAME..."
        fi
    fi
done 

if [ "$glilang" = "es" ]; then
    echo "Hecho."
elif [ "$glilang" = "fr" ]; then
    echo "TerminИ."
elif [ "$glilang" = "ru" ]; then
    echo "Выполнено."
else
    echo "Done."
fi