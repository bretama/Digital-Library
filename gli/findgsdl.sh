# Can't use exit in this script, since the script will be sourced
# The calling script will end up exiting too, if we exit here

# Uses GLIMODE which would have been set by the calling (client-)gli script.
# This script sets GSDLHOME and _version, if a GS installation can be found.
# May also set GSDL3SRCHOME and GSDL3HOME if a GS3 installation was found.


# Prints a message if the greenstone version is unknown, depending on whether
# the calling script launches the client-gli or not
function version_unknown {    
    # if GLIMODE is client, we can live without a local GS installation
    if [ "x$GLIMODE" == "xclient" ]; then
	if [ "x$GLILANG" = "en" -o "x$GLILANG" = "x" ]; then
	    echo "Could not detect a Greenstone installation (no GSDLHOME)."
	fi
    # otherwise GLIMODE is not client, in which case it is an error to not know the version
    else	
	if [ "x$GLILANG" = "en" -o "x$GLILANG" = "x" ]; then
	    echo "Error: can't determine which Greenstone version is being run."
	fi
    fi
    echo
}

# Function that, when given gsdlpath as parameter, will return the
# version of greenstone that is to run (2 or 3). If the version remains 
# unknown this script will return 1.
function get_version {
    # first parameter is value of gsdlpath
    if [ -f "${1}/gs3-setup.sh" ]; then
	return 3
    elif [ -f "${1}/setup.bash" ]; then
	return 2
    else
	# print message and return 1, which is not a valid Greenstone version
	version_unknown	
	return 1
    fi
}

# Function that is passed the following paramters (in order):
# - the gsdlpath (GS3 home, GS2 home or gs2build for GS3), 
# - the version of greenstone that's running, and 
# - the language GLI is set to
# and checks the installation. 
# If things are not right, this program will exit here.
function check_installation {
# Check that the Greenstone installation looks OK
    if [ "$3" = "es" ]; then
	echo "Revisando GSDL$2: $1"
    elif [ "$3" = "fr" ]; then
	echo "VÈrification de GSDL$2: $1"
    elif [ "$3" = "ru" ]; then
	echo "“œ◊≈“À¡ GSDL$2: $1"
    else
	echo "Checking GSDL$2: $1"
    fi
    # even if we are only checking for gs2build (gsdl2path), we still 
    # need the file setup.bash to exist in the following condition:
    if [ ! -f "${1}/gs3-setup.sh" -a ! -f "${1}/setup.bash" ] ; then
	echo
	if [ "$3" = "es" ]; then
	    echo "No se pudo encontrar la instalaciÛn de Greenstone $2 o est· incompleta."
	    echo "Trate de reinstalar Greenstone $2 y a continuaciÛn ejecute nuevamente"
	    echo "este guiÛn."
	elif [ "$3" = "fr" ]; then
	    echo "L'installation de Greenstone $2 est introuvable ou incomplËte."
	    echo "Essayez de rÈinstaller Greenstone $2 et exÈcutez ce script ‡ nouveau."
	elif [ "$3" = "ru" ]; then
	    echo "ÈŒ”‘¡ÃÃ—√…— Greenstone $_version Œ≈ ¬ŸÃ¡ Œ¡ ƒ≈Œ¡ …Ã… œŒ¡ Œ≈–œÃŒ¡."
	    echo "œ–“œ¬’ ‘≈ –œ◊‘œ“Œœ ’”‘¡Œœ◊…‘ÿ Greenstone $2, ¡ ⁄¡‘≈Õ ◊◊≈”‘… ‹‘œ‘ ”À“…–‘ ”Œœ◊¡."
	else
	    echo "The Greenstone $2 installation could not be found, or is incomplete."
	    echo "Try reinstalling Greenstone $2 then running this script again."
	fi
	exit 1
    fi
}


##  ---- Determine GSDLHOME ----
## gsdlpath can be either Greenstone 3 or Greenstone 2
gsdlpath=
# Some users may set the above line manually


# This variable is set automatically:
_version=
if [ "x$gsdlpath" != "x" ]; then
    get_version "$gsdlpath"
    _version=$?    
# otherwise $gsdlpath is not yet set
else
    # Check the environment variable first
    # Check whether environment variables for both GS2 and GS3 are set
    # and if so, warn the user that we have defaulted to GS3
    if [ "x$GSDLHOME" != "x" -a "x$GSDL3SRCHOME" != "x" ]; then
        # _version not set, but both env vars set, so default to 3
	_version=3
	gsdlpath="$GSDL3SRCHOME"
	echo "Both Greenstone 2 and Greenstone 3 environments are set." 
	echo "It is assumed you want to run Greenstone 3."
	echo "If you want to run Greenstone 2, please unset the"
	echo "environment variable GSDL3SRCHOME before running GLI."
	echo ""
    elif [ "x$GSDL3SRCHOME" != "x" ]; then
	echo "Only gsdl3srchome set"
	gsdlpath="$GSDL3SRCHOME"
	_version=3
	echo "$gsdlpath"
    elif [ "x$GSDLHOME" != "x" ]; then
	gsdlpath="$GSDLHOME"
	_version=2
    # If it is not set, assume that the GLI is installed as a subdirectory of Greenstone
    else
	gsdlpath=`(cd .. && pwd)`
        # Still need to find what version we are running:
        # GS3 main directory contains file gs3-setup.sh, GS2 only setup.bash
	get_version "$gsdlpath"
	_version=$?
    fi
fi

# if it's an invalid greenstone version, we exit the script here
if [ "$_version" -lt 2 ]; then
    return $_version;
fi

echo "Greenstone version found: $_version"

# Check that the main Greenstone installation for the version we're running looks OK
check_installation "$gsdlpath" "$_version" "$glilang"


# Need to source the correct setup file depending on whether we are running
# gs3 or gs2
# If we're running version GS2
if [ "$_version" -eq 2 ]; then
    # Setup Greenstone 2, unless it has already been done
    if [ "x$GSDLHOME" = "x" ]; then
    cd "$gsdlpath"
    . ./setup.bash
    cd "$thisdir"
    fi
# else, if we're running GS3
elif [ "$_version" -eq 3 ]; then
    # Setup Greenstone 3, unless it has already been done
    if [ "x$GSDL3HOME" = "x" -o "x$GSDL3SRCHOME" = "x" ]; then
    cd "$gsdlpath"
    . ./gs3-setup.sh
    cd "$thisdir"
    fi
    
    ## if Greenstone version 3 is running, we want to set gsdl2path
    ##  ---- Determine GSDLHOME ----
    ## may be already set, or manually entered here.
    gsdl2path=
    
    # Some users may set the above line manually
    if [ "x$gsdl2path" = "x" ]; then
        # Check the environment variable first
    if [ "x$GSDLHOME" != "x" ]; then
        echo "GSDLHOME environment variable is set to $GSDLHOME."
        echo "Will use this to find build scripts."
        gsdl2path="$GSDLHOME"
        # If it is not set, assume that the gs2build subdirectory of Greenstone 3 exists
    else
        gsdl2path="$GSDL3SRCHOME/gs2build"
    fi
    fi
    # Check that Greenstone 3's Greenstone 2 stuff looks OK (in gs2build)
    check_installation "$gsdl2path" "" "$glilang"
  
    # Setup Greenstone 3's gs2build, unless it has already been done
    if [ "x$GSDLHOME" = "x" ]; then
    cd "$gsdl2path"
    . ./setup.bash
    cd "$thisdir"
    fi

else 
    echo "Greenstone version unknown."    
    return 1
fi

echo
if [ "x$GSDL3SRCHOME" != "x" ]; then
    echo "GSDL3SRCHOME is: $GSDL3SRCHOME"
fi
if [ "x$GSDL3HOME" != "x" ]; then
    echo "GSDL3HOME is: $GSDL3HOME"
fi
if [ "x$GSDLHOME" != "x" ]; then
    echo "GSDLHOME is: $GSDLHOME"
fi
echo