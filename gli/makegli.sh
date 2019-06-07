#!/bin/sh
glilang=en

echo
if [ "$glilang" = "es" ]; then
    echo "Interfaz de la Biblioteca Digital Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "La Interfaz de la Biblioteca Digital Greenstone NO INCLUYE ABSOLUTAMENTE NINGUNA GARANT�A."
    echo "Para mayor informaci�n vea los t�rminos de la licencia en LICENSE.txt"
    echo "Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita"
elif [ "$glilang" = "fr" ]; then
    echo "Interface du Biblioth�caire Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "GLI est fourni sans AUCUNE GARANTIE; pour des d�tails, voir LICENSE.txt"
    echo "Ceci est un logiciel libre, et vous �tes invit� � le redistribuer"
elif [ "$glilang" = "ru" ]; then
    echo "������������ ��������� Greenstone (Greenstone Librarian Interface - GLI)"
    echo "Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato"
    echo "��� �� ���� ��������� ������� ��������; ������ ��. � ������ LICENSE.TXT"
    echo "��� - �������� ���������������� ����������� ����������� � �� ������ �������������� ���"
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
    echo "V�rification de Javac: $javacpath"
elif [ "$glilang" = "ru" ]; then
    echo "�������� Javac: $javacpath"
else
    echo "Checking Javac: $javacpath"
fi
if [ ! -x "$javacpath" ]; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "No se pudo localizar una versi�n apropiada de Javac."
	echo "Por favor instale una nueva versi�n del Kit de Desarrollo de"
	echo "Software Java (versi�n 1.4 o posterior) y ejecute nuevamente"
	echo "este gui�n."
    elif [ "$glilang" = "fr" ]; then
	echo "Une version appropri�e de Javac n'a pas pu �tre localis�e."
	echo "Veuillez installer une nouvelle version de Java SDK (version 1.4 ou"
	echo "plus r�cente) et red�marrez ce script."
    elif [ "$glilang" = "ru" ]; then
	echo "�� ������� ���������� ��������������� ��������������� ������ Javac."
	echo "����������, ���������� ����� ������ Java SDK (������ 1.4 ��� �����"
	echo "�����) � �������������� ���� ������."
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
	echo "Compilation de $* et des classes d�pendantes,,,"
    elif [ "$glilang" = "ru" ]; then
	echo "�������������� $* � ��������� ������..."
    else
	echo "Compiling $* and dependent classes..."
    fi

    $javacpath $JAVACFLAGS -deprecation -d classes/ -sourcepath src/ -classpath classes/:lib/apache.jar:lib/jna.jar:lib/jna-platform.jar:lib/qfslib.jar:lib/rsyntaxtextarea.jar $*

    if [ "$glilang" = "es" ]; then
	echo "�Hecho!"
    elif [ "$glilang" = "fr" ]; then
	echo "Termin�!"
    elif [ "$glilang" = "ru" ]; then
	echo "���������!"
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
    echo "�������������� ������������� ���������� Greenstone..."
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
    echo "�Hecho!"
elif [ "$glilang" = "fr" ]; then
    echo "Termin�!"
elif [ "$glilang" = "ru" ]; then
    echo "���������!"
else
    echo "Done!"
fi
