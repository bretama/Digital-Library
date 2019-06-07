#!/bin/bash

if [ -z "$serverlang" ]; then
    serverlang=en
fi

java_min_version=1.5.0_00
PROGNAME="gs2-server"
PROGFULLNAME="Greenstone-Server"
if [ -z "$PROGABBR" ]; then
   PROGABBR="GSI"
fi

function autoset_gsdl_home() {

  # remove leading ./ if present
  prog="${0#./}"

  isrelative="${prog%%/*}"

  if [ ! -z "$isrelative" ] ; then
    # some text is left after stripping
    # => is relative
    prog="$PWD/$prog"
  fi

  fulldir="${prog%/*}"

  # remove trailing /. if present
  eval "$1=\"${fulldir%/.}\""
}

function isinpath() {
  for file in `echo $1 | sed 's/:/ /g'`; do
    if [ "$file" == "$2" ]; then
      echo true
      return
    fi
  done
  echo false
}


echo "Greenstone 2 Server"
echo "Copyright (C) 2009, New Zealand Digital Library Project, University Of Waikato"
echo "This software comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt"
echo "This is free software, and you are welcome to redistribute it"

##  -------- Run the Greenstone 2 Server --------

##  ---- Determine GSDLHOME ----
gsdl2path=

# Some users may set the above line manually
if [ -z "$gsdl2path" ]; then
   autoset_gsdl_home gsdl2path
fi

# Setup Greenstone2, unless it has already been done
if [ -z "$GSDLHOME" ]; then 
  pushd "$gsdl2path" > /dev/null
  source ./setup.bash
  popd > /dev/null
fi

# First test that there is actually something that can be run...
# Exit if the apache-httpd folder doesn't exist for some reason
# (The errors reported when the apache webserver does not exist 
# in the correct location are not at all helpful).
if [ ! -d "$GSDLHOME/apache-httpd" ]; then
    echo ""
    echo "UNABLE TO CONTINUE: There is no apache-httpd directory."
    echo "It does not look like the local apache webserver has been installed."
    echo "Exiting..."
    echo ""
    exit 1
fi

# If there's no llssite.cfg file, copy from the template
if [ ! -e "$GSDLHOME/llssite.cfg" ]; then
    if [ -e "$GSDLHOME/llssite.cfg.in" ]; then
    cp "$GSDLHOME/llssite.cfg.in" "$GSDLHOME/llssite.cfg"
    else
    echo "Warning: could not find llssite.cfg.in to create llssite.cfg from."
    fi
fi

##  ---- Determine JAVA_HOME ----
# Set this to true if you want the Greenstone server interface to run in the background
# and not print any error messages to the x-term.
silent=

# JRE_HOME or JAVA_HOME must be set correctly to run this program
search4j -m $java_min_version &> /dev/null
# for some reason, Mac requires an echo after the above
echo
if [ "$?" == "0" ]; then
    # In Java code, '...getResourceAsStream("build.properties")'
    # needs up to be in the right directory when run
    pushd "$gsdl2path" > /dev/null


    #CLASSPATH
    if [ `isinpath "$CLASSPATH" "$GSDLHOME/lib/java"` == "false" ]; then
        CLASSPATH="$GSDLHOME/lib/java:$CLASSPATH"
        for JARFILE in lib/java/*.jar; do
            CLASSPATH="$CLASSPATH:$GSDLHOME/$JARFILE"
        done
        export CLASSPATH
        echo "  - Adjusted CLASSPATH"

    else
        echo "  - CLASSPATH already correct"
    fi

    ## ---- Check Java ----
    # call the script with source, so that we have the variables it sets ($javapath)
    exit_status=0
    source ./findjava.sh "$serverlang" "$PROGNAME"
    exit_status=$?
    if [ "$exit_status" -eq 1 ]; then
        exit 1;
    fi
    export PATH=$javahome/bin:$PATH

    # some informative messages to direct the users to the logs
    if [ "$serverlang" == "en" -o "x$serverlang" == "x" ]; then
	echo "***************************************************************"
	echo "Starting the Greenstone Server Interface (GSI)..."
	echo
	echo "Server log messages go to:"
	echo "   $GSDLHOME/etc/logs-gsi/server.log"
	echo
	echo "Using Apache web server located at:"
	echo "   $GSDLHOME/apache-httpd/$GSDLOS/bin/httpd"
	echo "The Apache error log is at:"
	echo "   $GSDLHOME/apache-httpd/$GSDLOS/logs/error_log"
	echo "The Apache configuration file template is at:"
	echo "   $GSDLHOME/apache-httpd/$GSDLOS/conf/httpd.conf.in"
	echo "This is used to generate:"
	echo "   $GSDLHOME/apache-httpd/$GSDLOS/conf/httpd.conf"
	echo "   each time Enter Library is pressed or otherwise activated."
	echo "***************************************************************"
	echo
	echo
    fi

    # -Xdock:name      To set the name of the app in the MacOS Dock bar
    # -Xdock:icon      Path to the MacOS Doc icon (not necessary for GS)    
    custom_vm_args=""
    if [ "$GSDLOS" = "darwin" ]; then
    	custom_vm_args="-Xdock:name=$PROGFULLNAME"
	if [ -f "gs2-server.app/Contents/Resources/AutomatorApplet.icns" ]; then
	   custom_vm_args="$custom_vm_args -Xdock:icon=gs2-server.app/Contents/Resources/AutomatorApplet.icns"
	fi
    fi

    # whenever the server is started up, make sure gsdlhome is correct (in case the gs install was moved).
    # If both stderr and stdout need to be redirected into the void (with &>/dev/null), see
    # http://linuxwave.blogspot.com/2008/03/redirecting-stdout-and-stderr.html
    ./gsicontrol.sh reset-gsdlhome >/dev/null

    if [ "x$silent" == "x" -o "x$silent" != "xtrue" ]; then 
        # verbose mode, show all output, but then we can't run the server interface in the background
	
	"$javapath" $custom_vm_args org.greenstone.server.Server2 "$GSDLHOME" "$GSDLOS$GSDLARCH" "$serverlang" $*
    else
        # If we launch the Greenstone Server Interface application in the background (with & at end)
        # need to redirect any STDERR (STDOUT) output to /dev/null first, else output will hog the x-term.
	"$javapath" $custom_vm_args org.greenstone.server.Server2 "$GSDLHOME" "$GSDLOS$GSDLARCH" "$serverlang" $* > /dev/null &
    fi

    popd > /dev/null
fi

