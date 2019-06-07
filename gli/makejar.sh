#!/bin/sh
glilang=en


# This script must be run from within the directory in which it lives
thisdir=`pwd`
if [ ! -f "${thisdir}/makejar.sh" ]; then
    if [ "$glilang" = "es" ]; then
        echo "Este gui�n deber� ejecutarse desde el directorio en el que reside."
    elif [ "$glilang" = "fr" ]; then
	echo "Ce script doit �tre ex�cut� � partir du r�pertoire dans lequel il se trouve."
    elif [ "$glilang" = "ru" ]; then
	echo "���� ������ ������ ���� ���� �� ����������, � ������� �� ����������"
    else
	echo "This script must be run from the directory in which it resides."
    fi
    exit 1
fi

echo "Generating the JAR files for Remote Greenstone"

## ---- Check that the GLI has been compiled ----
if [ ! -f "classes/org/greenstone/gatherer/GathererProg.class" ]; then
    echo
    if [ "$glilang" = "es" ]; then
	echo "Usted necesita compilar la Interfaz de la Biblioteca Digital Greenstone"
	echo "(por medio de makegli.sh) antes de ejecutar este gui�n."
    elif [ "$glilang" = "fr" ]; then
	echo "Vous devez compiler le Greenstone Interface (en utilisant makegli.sh)"
	echo "avant d'ex�cuter ce script."
    elif [ "$glilang" = "ru" ]; then
	echo "�� ������ ������������� ������������ ��������� Greenstone"
	echo "(��������� makegli.sh) ����� ������ ����� �������"
    else
	echo "You need to compile the Greenstone Librarian Interface (using makegli.sh)"
	echo "before running this script."
    fi
    exit 1
fi

echo "Assuming that Java code is freshly compiled..."

rm -rf jar
mkdir jar

# GLI class files and supporting libraries
cd jar
jar xf ../lib/apache.jar com org javax
jar xf ../lib/jna.jar com
jar xf ../lib/jna-platform.jar com
jar xf ../lib/qfslib.jar de
jar xf ../lib/rsyntaxtextarea.jar org theme.dtd
cd ..

# Copy the latest version of the GLI classes into the jar directory
rm -rf jar/org/greenstone
cp -r classes/org/greenstone jar/org

# Some of the things to go into the JAR file are optional, and may not exist
if [ -f collect.zip ]; then
  cp collect.zip jar
fi

# Recreate the metadata.zip file (contains the GLI metadata directory)
rm -f metadata.zip
zip -r jar/metadata.zip metadata >/dev/null

# Dictionary files
cd classes
for dict_file in dictionary*.properties; do
	cp $dict_file ../jar
done
cd ..

# Other required directories and files
cp -r 'help' jar
cp -r 'classes/images' jar
cp -r 'classes/xml' jar
cp 'classes/feedback.properties' jar
cp '.java.policy' jar

# Clean .svn dirs
find jar -name '.svn' -type d -exec rm -rf {} \; 2> /dev/null

# Jar everything up
cd jar
jar cf ../GLI.jar *
cd ..

# Generate the GLIServer.jar file for remote building
jar cf GLIServer.jar -C jar org/greenstone/gatherer/remote

# ---- Make signed JAR file for the applet, if desired ----
if [ "$1" = "-sign" ]; then
    rm -f SignedGatherer.jar
    echo "greenstone" | jarsigner -keystore .greenstonestore -signedjar SignedGatherer.jar GLI.jar privateKey 2> /dev/null
    echo
    echo "Installing SignedGatherer in ../bin/java"
    mv SignedGatherer.jar ../bin/java/.
fi
