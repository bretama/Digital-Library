#!/bin/sh
glilang=en

echo
if [ "$glilang" = "es" ]; then
    echo "Interfaz de la Biblioteca Digital Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "La Interfaz de la Biblioteca Digital Greenstone NO INCLUYE ABSOLUTAMENTE NINGUNA GARANTмA."
    echo "Para mayor informaciСn vea los tИrminos de la licencia en LICENSE.txt"
    echo "Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita"
elif [ "$glilang" = "fr" ]; then
    echo "Interface du BibliothИcaire Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GLI est fourni sans AUCUNE GARANTIE; pour des dИtails, voir LICENSE.txt"
    echo "Ceci est un logiciel libre, et vous Йtes invitИ Ю le redistribuer"
elif [ "$glilang" = "ru" ]; then
    echo "Библиотечный интерфейс Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "БИГ не дает АБСОЛЮТНО НИКАКИХ ГАРАНТИЙ; детали см. в тексте LICENSE.TXT"
    echo "Это - свободно распространяемое программное обеспечение и Вы можете распространять его"
else
    echo "Greenstone Librarian Interface (GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GLI comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt"
    echo "This is free software, and you are welcome to redistribute it"
fi
echo

##  -------- Compile the Greenstone Librarian Interface --------

## ---- Check Javac exists ----
javacpath=

# Some users may set the above line manually
if [ "x$javacpath" = "x" ]; then

    # If the JAVAC environment variable is set then use it
    if [ "x$JAVAC" != "x" ] ; then
	javacpath=$JAVAC
    # If it is set, use the JAVA_HOME environment variable
    elif [ "x$JAVA_HOME" != "x" ]; then
	javacpath="$JAVA_HOME/bin/javac"
    # Check if Javac is on the search path
    else
	javacpath=`which javac 2> /dev/null`
    fi
fi

if [ "xJAVACFLAGS" = "x" ] ; then
    JAVACFLAGS="-source 1.4 -target 1.4"
fi

# Check that a Javac executable has been found
if [ "$glilang" = "es" ]; then
    echo "Revisando Javac: $javacpath"
elif [ "$glilang" = "fr" ]; then
    echo "VИrification de Javac: $javacpath"
elif [ "$glilang" = "ru" ]; then
    echo "Проверка Javac: $javacpath"
else
    echo "Checking Javac: $javacpath"
fi
if [ ! -x "$javacpath" ]; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "No se pudo localizar una versiСn apropiada de Javac."
	echo "Por favor instale una nueva versiСn del Kit de Desarrollo de"
	echo "Software Java (versiСn 1.4 o posterior) y ejecute nuevamente"
	echo "este guiСn."
    elif [ "$glilang" = "fr" ]; then
	echo "Une version appropriИe de Javac n'a pas pu Йtre localisИe."
	echo "Veuillez installer une nouvelle version de Java SDK (version 1.4 ou"
	echo "plus rИcente) et redИmarrez ce script."
    elif [ "$glilang" = "ru" ]; then
	echo "Не удалось определить местонахождение соответствующей версии Javac."
	echo "Пожалуйста, установите новую версию Java SDK (версию 1.4 или более"
	echo "новую) и переустановите этот скрипт."
    else
	echo "Failed to locate an appropriate version of Javac. You must install a"
	echo "Java Development Kit (version 1.4 or greater) before compiling the"
	echo "Greenstone Librarian Interface."
    fi
    exit 1
fi

## ---- Compile the GLI ----

# If a file has been specified at the command-line, just compile that file
if [ ! "x$*" = "x" ] ; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "Compilando $* y clases dependientes..."
    elif [ "$glilang" = "fr" ]; then
	echo "Compilation de $* et des classes dИpendantes,,,"
    elif [ "$glilang" = "ru" ]; then
	echo "Компилирование $* и зависимые классы..."
    else
	echo "Compiling $* and dependent classes..."
    fi

    $javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar $*

    if [ "$glilang" = "es" ]; then
	echo "║Hecho!"
    elif [ "$glilang" = "fr" ]; then
	echo "TerminИ!"
    elif [ "$glilang" = "ru" ]; then
	echo "Выполнено!"
    else
	echo "Done!"
    fi
    exit 0
fi

# Otherwise compile the lot...

# Remove any existing class files first
./clean.sh

if [ "$glilang" = "es" ]; then
    echo "Compilando la Interfaz de la Biblioteca Digital Greenstone..."
elif [ "$glilang" = "fr" ]; then
    echo "Compilation de Greenstone Librarian Interface,,,"
elif [ "$glilang" = "ru" ]; then
    echo "Компилирование библиотечного интерфейса Greenstone..."
else
    echo "Compiling the Greenstone Librarian Interface..."
fi

# Compile the GLI
$javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererProg.java
$javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererApplet.java
#$javacpath -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererApplet4gs3.java
# Compile the GEMS
$javacpath -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/gems/GEMS.java

# Compile the standalone programs needed on the server for remote building
$javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/ src/org/greenstone/gatherer/remote/Zip*.java
$javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/ src/org/greenstone/gatherer/remote/Unzip.java

if [ "$glilang" = "es" ]; then
    echo "║Hecho!"
elif [ "$glilang" = "fr" ]; then
    echo "TerminИ!"
elif [ "$glilang" = "ru" ]; then
    echo "Выполнено!"
else
    echo "Done!"
fi
