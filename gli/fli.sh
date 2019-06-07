#!/bin/sh

if [ "$glilang" = "es" ]; then
  PROGNAME="Biblioteca Digital Fedora"
elif [ "$glilang" = "fr" ]; then
  PROGNAME="BibliothÈcaire Fedora"
elif [ "$glilang" = "ru" ]; then
  PROGNAME="…Œ‘≈“∆≈ ” Fedora"
else
  PROGNAME="Fedora Librarian Interface"
fi
export PROGNAME

PROGNAME_EN="Fedora Librarian Interface"
export PROGNAME_EN

PROGABBR="FLI"
export PROGABBR

echo
# Test to see if FEDORA environment variables have been set up
if [ "x$FEDORA_HOME" == "x" ]; then
    echo "Error: Cannot run $PROGNAME_EN (PROGABBR) if FEDORA_HOME is not set."
    exit
fi

if [ ! -d "$FEDORA_HOME" ]; then
    echo "Error: Cannot find Fedora Home. No such directory: $FEDORA_HOME"
    exit
fi

# If FEDORA_VERSION not set, default fedora-version to 3 after warning user.  
if [ "x$FEDORA_VERSION" == "x" ]; then
    echo "FEDORA_VERSION (major version of Fedora) was not set. Defaulting to: 3."
    echo "If you are running a different version of Fedora, set the FEDORA_VERSION"
    echo "environment variable."
    FEDORA_VERSION="3"
    export FEDORA_VERSION
    echo
fi

# Finally run GLI in fedora mode
echo "FEDORA_HOME: $FEDORA_HOME"
echo "FEDORA_VERSION: $FEDORA_VERSION"

# Need to launch the gli.sh script from the same directory that fli was launched, 
# since that's where we are
# substring replacement (match end part of substring): http://tldp.org/LDP/abs/html/string-manipulation.html
gliscript=$0
gliscript=${0/%fli.sh/gli.sh}
#echo "script: $gliscript"
./$gliscript -fedora -fedora_home "$FEDORA_HOME" -fedora_version "$FEDORA_VERSION" $*
