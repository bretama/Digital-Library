#!/bin/bash
# if this file is executed, /bin/sh is used, as we don't start with #!
# this should work under ash, bash, zsh, ksh, sh style shells.
gsdllang=""
# encoding inputs and outputs
gsdltoenc=""
gsdlfromenc=""

# see if the shell has any language environment variables set
# see locale(7) manpage for this ordering.
if test ! -z "$LC_ALL" ; then
  gsdllang="$LC_ALL"
elif test ! -z "$LANG"; then
  gsdllang="$LANG"
fi


# note... all our output strings have the charset hard-coded, but
# people may be using a different encoding in their terminal. LANG
# strings look like "en_NZ.UTF-8".

# Determine the requested output encoding
case $gsdllang in
  *.*)
    gsdltoenc=`echo $gsdllang | sed 's/.*\.//'`
    ;;
esac

# Our french and spanish strings are currently in iso-8859-1 encoding.
case $gsdllang in
  fr*|FR*)
    gsdllang=fr
    gsdlfromenc="iso-8859-1"
  ;;
  es*|ES*)
    gsdllang=es
    gsdlfromenc="iso-8859-1"
  ;;
  ru*|RU*)
    gsdllang=ru
    gsdlfromenc="koi8r"
  ;;
  *) # default
    gsdllang=en
    gsdlfromenc="iso-8859-1"
  ;;
esac  

# "iconv" is the program for converting text between encodings.
gsdliconv=`which iconv 2>/dev/null`
if test $? -ne 0 || test ! -x "$gsdliconv" || test -z "$gsdlfromenc" || test -z "$gsdltoenc"; then
# we can't convert encodings from some reason
  gsdliconv="cat"
else
# add the encodings
  gsdliconv="$gsdliconv -f $gsdlfromenc -t $gsdltoenc"
fi

# make sure we are sourced, and not run

if test "$0" != "`echo $0 | sed s/setup\.bash//`" ; then
# if $0 contains "setup.bash" we've been run... $0 is shellname if sourced.
# One exception is zsh has an option to set it temporarily to the script name
  if test -z "$ZSH_NAME" ; then
  # we aren't using zsh
  gsdl_not_sourced=true
  fi
fi

if test -n "$gsdl_not_sourced" ; then
  case "$gsdllang" in
 "es")
eval $gsdliconv <<EOF
      Error: Asegúrese de compilar este guión, no de ejecutarlo. P. ej.:
         $ source setup.bash
      o
         $ . ./setup.bash
      no
         $ ./setup.bash
EOF
  ;;
  "fr")
eval $gsdliconv <<EOF
      Erreur: Assurez-vous de "sourcer" le script, plutôt que de l'exécuter. Ex:
         $ source setup.bash
      ou
         $ . ./setup.bash
      pas
         $ ./setup.bash
EOF
  ;;
  "ru")
eval $gsdliconv <<EOF
      ïÛÉÂËÁ: õÄÏÓÔÏ×ÅÒØÔÅÓØ × ÉÓÔÏÞÎÉËÅ ÜÔÏÇÏ ÓËÒÉÐÔÁ. îÅ ÉÓÐÏÌÎÑÊÔÅ ÅÇÏ.
      îÁÐÒÉÍÅÒ:
         $ source setup.bash
      ÉÌÉ
         $ . ./setup.bash
      ÎÅÔ
         $ ./setup.bash
EOF
  ;;
  *)
eval $gsdliconv <<EOF
	Error: Make sure you source this script, not execute it. Eg:
		$ source setup.bash
	or
		$ . ./setup.bash
	not
		$ ./setup.bash
EOF
  ;;
  esac
elif test -n "$GSDLHOME" ; then
  case "$gsdllang" in
  "es")
    echo '¡Su ambiente ya está listo para Greenstone!' | eval $gsdliconv
  ;;
  "fr")
    echo 'Votre environnement est déjà préparé pour Greenstone!' | eval $gsdliconv
 ;;
  "ru")
    echo '÷ÁÛÅ ÏËÒÕÖÅÎÉÅ ÕÖÅ ÎÁÓÔÒÏÅÎÏ ÄÌÑ Greenstone!' | eval $gsdliconv
  ;;
  *)
    echo 'Your environment is already set up for Greenstone!'
  ;;
  esac
elif test ! -f setup.bash ; then
  case "$gsdllang" in
    "es")
eval $gsdliconv <<EOF
Usted debe compilar el guión desde el interior del directorio de inicio
de Greenstone.
EOF
  ;;
  "fr")
echo 'Vous devez trouver la source du script dans le répertoire de base de Greenstone' | eval $gsdliconv
  ;;
  "ru")
eval $gsdliconv <<EOF
÷ÁÍ ÎÅÏÂÈÏÄÉÍ ÉÓÔÏÞÎÉË ÓËÒÉÐÔÁ ÉÚ ÂÁÚÏ×ÏÊ ÄÉÒÅËÔÏÒÉÉ Greenstone
EOF
  ;;
  *)
    echo 'You must source the script from within the Greenstone home directory'
  ;;
  esac
else
  GSDLHOME=`pwd`
  export GSDLHOME

  if test "x$GSDLOS" = "x" ; then
    GSDLOS=`uname -s | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'`
    # check for running bash under cygwin
    if test "`echo $GSDLOS | sed 's/cygwin//'`" != "$GSDLOS" ;
    then
      GSDLOS=windows
    fi
  fi
  export GSDLOS

  # check for running bash under mingw
  if test "`echo $GSDLOS | sed 's/mingw//'`" != "$GSDLOS" ;
  then
    GSDLOS=windows
  fi
  export GSDLOS

  # Establish cpu architecture
  # 32-bit or 64-bit?
  UNAME_HW_MACH=`uname -m`

# Original test
#  if test "`echo x$UNAME_HW_MACH | sed 's/^x.*_64$/x/'`" == "x" ;
#  then
#	GSDLARCH=64
#  else
#	GSDLARCH=32
#  fi

  # Following test came from VirtualBox's Guest Additions autostart.sh
  # (adapted for use in Greenstone)
  case "$UNAME_HW_MACH" in
    i[3456789]86|x86|i86pc)
      GSDLARCH='32'
      ;;
    x86_64|amd64|AMD64)
      GSDLARCH='64'
      ;;
    *)
      echo "Unknown architecture: $UNAME_HW_MACH"
      ;;
  esac

  # Only want non-trival GSDLARCH value set if there is evidence of
  # the installed bin (lib, ...) directories using linux32, linux64
  # (otherwise probably looking at an SVN compiled up version for single OS)
  if test ! -d "$GSDLHOME/bin/$GSDLOS$GSDLARCH" ;
  then 
    GSDLARCH=""
  fi

  export GSDLARCH

  PATH=$GSDLHOME/bin/script:$GSDLHOME/bin/$GSDLOS$GSDLARCH:$PATH
  export PATH
  
  if test "$GSDLOS" = "linux" ; then
      LD_LIBRARY_PATH="$GSDLHOME/lib/$GSDLOS$GSDLARCH:$LD_LIBRARY_PATH"
	  export LD_LIBRARY_PATH
  elif test "$GSDLOS" = "darwin" ; then
      DYLD_LIBRARY_PATH="$GSDLHOME/lib/$GSDLOS$GSDLARCH:$DYLD_LIBRARY_PATH"
      export DYLD_LIBRARY_PATH
  fi
 
  # Override Imagemagick and Ghostscript paths to the bundled applications shipped with greenstone if they exists otherwise use default environment variables.

# Imagemagick env vars are set in bin\script\gs-magick.pl


  # Note: Ghostscript is only bundled with Greenstone on Mac and Windows, not on Linux. The code below should be used only for the Darwin platform
  # for Windows please see setup.bat
if test -d "$GSDLHOME/bin/$GSDLOS$GSDLARCH/ghostscript" ; then
	PATH="$GSDLHOME/bin/$GSDLOS$GSDLARCH/ghostscript/bin":"$PATH"
	export PATH
  
	GS_LIB="$GSDLHOME/bin/$GSDLOS$GSDLARCH/ghostscript/share/ghostscript/8.63/lib"
	export GS_LIB

	GS_FONTPATH="$GSDLHOME/bin/$GSDLOS$GSDLARCH/ghostscript/share/ghostscript/8.63/Resource/Font"
	export GS_FONTPATH
fi
  

  
  MANPATH=$MANPATH:$GSDLHOME/packages/mg/man
  export MANPATH
  case "$gsdllang" in
    "es")
      echo 'Su ambiente ha sido configurado para correr los programas Greenstone.' | eval $gsdliconv
    ;;
    "fr")
      echo 'Votre environnement a été configuére avec succès pour exécuter Greenstone' | eval $gsdliconv
    ;;
    "ru")
eval $gsdliconv <<EOF
÷ÁÛÅ ÏËÒÕÖÅÎÉÅ ÂÙÌÏ ÕÓÐÅÛÎÏ ÎÁÓÔÒÏÅÎÏ, ÞÔÏÂÙ ÕÓÔÁÎÏ×ÉÔØ Greenstone
EOF
    ;;
    *)
      echo 'Your environment has successfully been set up to run Greenstone'
    ;;
  esac
fi
unset gsdl_not_sourced
unset gsdliconv
unset gsdlfromenc
unset gsdltoenc

if test "x$gsopt_noexts" != "x1" ; then
    if test -e ext; then
	for gsdl_ext in ext/*; do
	    if test -d $gsdl_ext; then
		cd $gsdl_ext > /dev/null
		if test -e setup.bash ; then
		    source ./setup.bash
		fi
		cd ../..
	    fi
	done
    fi
fi

if test -e apache-httpd ; then
  echo "+Adding in executable path for apache-httpd"
  PATH=$GSDLHOME/apache-httpd/$GSDLOS$GSDLARCH/bin:$PATH
  export PATH

  if test "$GSDLOS" = "linux" ; then
      LD_LIBRARY_PATH="$GSDLHOME/apache-httpd/$GSDLOS$GSDLARCH/lib:$LD_LIBRARY_PATH"
      export LD_LIBRARY_PATH
  
  elif test "$GSDLOS" = "darwin" ; then
      DYLD_LIBRARY_PATH="$GSDLHOME/apache-httpd/$GSDLOS$GSDLARCH/lib:$DYLD_LIBRARY_PATH"
      export DYLD_LIBRARY_PATH
  fi
fi

if test -e local ; then
  if test -e local/setup.bash ; then 
    echo "Sourcing local/setup.bash"
    cd local ; source setup.bash ; cd ..
  fi

  PATH=$GSDLHOME/local/bin:$PATH
  export PATH
  LD_LIBRARY_PATH=$GSDLHOME/local/lib:$LD_LIBRARY_PATH
  export LD_LIBRARY_PATH
fi

# Only for GS2: work out java, and if the bundled jre is found, then set Java env vars with it
# Then the same java will be consistently available for all aspects of GS2 (server or GLI, and any subshells these launch)
if [ "x$GSDL3SRCHOME" = "x" ] ; then
    MINIMUM_JAVA_VERSION=1.5.0_00	

    echo "GS2 installation: Checking for Java of version $MINIMUM_JAVA_VERSION or above"

    SEARCH4J_EXECUTABLE="$GSDLHOME/bin/$GSDLOS$GSDLARCH/search4j"
    if [ -f "$SEARCH4J_EXECUTABLE" ]; then
	
	# Give search4j a hint to find Java depending on the platform
        # we now include a JRE with Mac (Mountain) Lion, because from Yosemite onwards there's no system Java on Macs
	HINT=`cd "$GSDLHOME";pwd`/packages/jre    
	
        # we can't use boolean operator -a to do the AND, since it doesn't "short-circuit" if the first test fails
        # see http://www.tldp.org/LDP/abs/html/comparison-ops.html


	if [ "x$GSDLOS" = "xdarwin" ] && [ ! -d "$HINT" ]; then
           # http://java.dzone.com/articles/java-findingsetting
	   # explains that /usr/libexec/java_home will print the default JDK
	   # regardless of which Mac OS we're on. Tested on Maverick, Lion, Leopard
	   # (run `/usr/libexec/java_home -v 1.7` to find a specific version)
	    macHINT=`/usr/libexec/java_home 2>&1`
	    status=$?
	    # if no java installed, then HINT will contain:
	    #  Unable to find any JVMs matching version "(null)".
	    #  No Java runtime present, try --request to install.
	    # and the status of running /usr/libexec/java_home will not be 0 but 1:
	    if [ "$status" = "0" ]; then
		HINT=$macHINT
	    else
		echo "No system Java on this mac..."
	    fi
	fi
	
	javahome="`"$SEARCH4J_EXECUTABLE" -p "$HINT" -m $MINIMUM_JAVA_VERSION`"
	BUNDLED_JRE="$GSDLHOME/packages/jre"

	if [ "$?" != "0" ]; then
	    echo "setup.bash: Could not find Java in the environment or installation."
	    echo "Set JAVA_HOME or JRE_HOME, and put it on the PATH, if working with Java tools like Lucene."
	elif [[ "x$javahome" != "x" && "x$javahome" != "x$BUNDLED_JRE" ]]; then
            echo "Using Java found at $javahome" 
	    if [ "x$JAVA_HOME" = "x" ]; then
		# if Java env vars not already set, then set them to the $javahome found
		echo "Found a Java on the system. Setting up GS2's Java environment to use this"
		export JAVA_HOME=$javahome
		export PATH=$JAVA_HOME/bin:$PATH
	    fi
	    # else JAVA_HOME, and PATH presumably too, would already be set
	elif [ -d "$GSDLHOME/packages/jre" ]; then
	    echo "Found a bundled JRE. Setting up GS2's Java environment to use this"
	    export JRE_HOME=$GSDLHOME/packages/jre    
	    export PATH=$JRE_HOME/bin:$PATH
	else
	    # can we ever really get here?
	    echo "Java environment not set and bundled JRE doesn't exist. Some tools need the Java environment. Proceeding without..."
	fi
    fi
fi

# if the Perl-for-greenstone tarfile has been installed in the bin/linux
# folder, then we set things up to use that, instead of a system perl 
if [ -d "$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl" ] ; then

	if [ -d "$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/bin" ] ; then
		PERLPATH=$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/bin
		export PERLPATH
		PATH=$PERLPATH:$PATH
		export PATH
	fi   

    if test "$GSDLOS" = "linux" ; then
	LD_LIBRARY_PATH=$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/lib/5.8.9/i686-linux-thread-multi/CORE:$LD_LIBRARY_PATH
	export LD_LIBRARY_PATH
    elif test "$GSDLOS" = "darwin" ; then
	DYLD_LIBRARY_PATH=$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/lib/5.8.9/darwin-thread-multi-2level/CORE:$DYLD_LIBRARY_PATH
	export DYLD_LIBRARY_PATH
    fi

    if [ "x$PERL5LIB" = "x" ] ; then
	PERL5LIB=$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/lib
    else 
	PERL5LIB=$GSDLHOME/bin/$GSDLOS$GSDLARCH/perl/lib:$PERL5LIB
    fi
    export PERL5LIB

    echo ""
    echo "***** Perl installation detected inside Greenstone."
    echo "Command-line scripts need to be run with \"perl -S ...\""
    echo "    e.g. perl -S import.pl -removeold demo"
    echo ""
# else we may in future need to update PERL5LIB with some other (further) locations
fi

# Perl >= v5.18.* randomises map iteration order within a process
export PERL_PERTURB_KEYS=0

# turn off certificate errors when using wget to retrieve over https
# (to avoid turning it off with the --no-check-certificate flag to each wget cmd)
# See https://superuser.com/questions/508696/wget-without-no-check-certificate
# https://www.gnu.org/software/wget/manual/html_node/Wgetrc-Location.html
export WGETRC=$GSDLHOME/bin/$GSDLOS/wgetrc
