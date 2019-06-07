#!/bin/bash

glilang=en

if [ "$glilang" = "es" ]; then
    PROGNAME="Editar conjuntos de metadatos"
elif [ "$glilang" = "fr" ]; then
    PROGNAME="Editer les jeux de mИta-donnИes"
elif [ "$glilang" = "ru" ]; then
    PROGNAME="Редактировать наборы метаданных"
else
    PROGNAME="Greenstone Editor for Metadata Sets"
fi

PROGABBR="GEMS"

PROGNAME_EN="Greenstone Editor for Metadata Sets"

echo
if [ "$glilang" = "es" ]; then
    echo "$PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GEMS NO INCLUYE ABSOLUTAMENTE NINGUNA GARANTмA."
    echo "Para mayor informaciСn vea los tИrminos de la licencia en LICENSE.txt"
    echo "Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita"
elif [ "$glilang" = "fr" ]; then
    echo "$PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GEMS est fourni sans AUCUNE GARANTIE; pour des dИtails, voir LICENSE.txt"
    echo "Ceci est un logiciel libre, et vous Йtes invitИ Ю le redistribuer"
elif [ "$glilang" = "ru" ]; then
    echo "$PROGNAME ($PROGNAME_EN - $PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "БИГ не дает АБСОЛЮТНО НИКАКИХ ГАРАНТИЙ; детали см. в тексте LICENSE.TXT"
    echo "Это - свободно распространяемое программное обеспечение и Вы можете распространять его"
else
    echo "$PROGNAME ($PROGABBR)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GEMS comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt"
    echo "This is free software, and you are welcome to redistribute it"
fi
echo

##  -------- Run the Greenstone Editor for Metadata Sets --------
# This script must be run from within the directory in which it lives
thisdir="`dirname \"$0\"`"
thisdir="`cd \"$thisdir\" && pwd`"
cd "$thisdir"

##  ---- Determine GSDLHOME ----
## gsdlpath can be either Greenstone 3 or Greenstone 2
exit_status=0
source ./findgsdl.sh
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi

## ---- Check Java ----
# call the script with source, so that we have the variables it sets ($javapath
exit_status=0
source ./findjava.sh "$glilang" "$PROGNAME"
exit_status=$?
if [ "$exit_status" -eq 1 ]; then
    exit 1;
fi

## ---- Check that the GEMS has been compiled ----
if [ ! -f "classes/org/greenstone/gatherer/gems/GEMS.class" ] && [ ! -f "GLI.jar" ]; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "Usted necesita compilar la $PROGNAME"
	echo "(por medio de makegli.sh) antes de ejecutar este guiСn."
    elif [ "$glilang" = "fr" ]; then
	echo "Vous devez compiler le $PROGNAME (en utilisant makegli.sh)"
	echo "avant d'exИcuter ce script."
    elif [ "$glilang" = "ru" ]; then
	echo "Вы должны компилировать $PROGNAME"
	echo "(используя makegli.sh) перед вводом этого скрипта"
    else
	echo "You need to compile the $PROGNAME (using makegli.sh)"
	echo "before running this script."
    fi
    exit 1
fi

## ---- Finally, run the GEMS ----
echo
if [ "$glilang" = "es" ]; then
    echo "Ejecutando la $PROGNAME..."
elif [ "$glilang" = "fr" ]; then
    echo "ExИcution de $PROGNAME..."
elif [ "$glilang" = "ru" ]; then
    echo "Текущий библиотечный $PROGNAME..."
else
    echo "Running the $PROGNAME..."
fi

# Other arguments you can provide to GEMS to work around memory limitations, or debug
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
    if [ -f "../gems.app/Contents/Resources/AutomatorApplet.icns" ]; then
	custom_vm_args="$custom_vm_args -Xdock:icon=../gems.app/Contents/Resources/AutomatorApplet.icns"
    fi
fi

# basic_command is the cmd string common to both Greenstone 3 and Greenstone 2 execution
# (gs3 doesn't -gsdl3src $GSDL3SRCHOME passed to it, it needs $GSDL3HOME to find the collect dir)
basic_command="$javapath -classpath classes/:GLI.jar:lib/apache.jar $custom_vm_args org.greenstone.gatherer.gems.GEMS"

if [ "$_version" -eq 2 ]; then
    `$basic_command -gsdl $GSDLHOME $*`
elif [ "$_version" -eq 3 ]; then    
    `$basic_command -gsdl3 $GSDL3HOME $*`
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
