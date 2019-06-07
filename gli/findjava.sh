# We will already be in the correct folder (GLI folder), which would
# contain a compiled up search4j if this GLI is part of an installation.
# If a search4j executable is not there, then it means this is an SVN checkout. 
# In such a case, it's up to the user checking things out to ensure JAVA_HOME
# is set and moreover points to the correct version of the Java.

# Function to check if any JAVA_HOME is set and if so, try using that
function try_java {
    MIN_DISPLAY_VERSION=${1};

    if [ "x$JAVA_HOME" = "x" -o ! -f "$JAVA_HOME/bin/java" ]; then
	no_java "$MIN_DISPLAY_VERSION"
	return $?
    else
	# There is a JAVA_HOME already set, we're going to try using that
	javapath="$JAVA_HOME/bin/java"
	javahome="$JAVA_HOME"
	# Print a warning that we're going to use whatever JAVA_HOME is set (fingers crossed)
	if [ "x$gslang" = "x" -o "$gslang" = "en" ]; then
	    echo
	    echo "***************************************************************************"
	    echo "WARNING: "
	    echo "Java Runtime not bundled with this Greenstone installation."
	    echo "Using JAVA_HOME: $JAVA_HOME"
	    echo "(NOTE: this needs to be $MIN_DISPLAY_VERSION or higher.)"
	    echo "***************************************************************************"
	    echo
	fi
	echo "Java:"
	echo $javapath
	echo
	return 0
    fi
}

function no_java {
    MIN_DISPLAY_VERSION=${1};

    echo
    if [ "$gslang" = "es" ]; then
	echo "No se pudo localizar una versiСn apropiada de Java. Usted deberА "
	echo "instalar un Ambiente de EjecuciСn Java (versiСn $MIN_DISPLAY_VERSION o superior) "
	echo "antes de correr la Interfaz de la $PROGNAME."
    elif [ "$gslang" = "fr" ]; then
	echo "Une version adИquate de Java n'a pas pu Йtre localisИe."
	echo "Vous devez installer un Java Runtime Environment (version $MIN_DISPLAY_VERSION ou"
	echo "supИrieur) avant de dИmarrer $PROGNAME."
	echo "Si vous avez Java installИ sur votre ordinateur veuillez vИrifier la variable"
	echo "d'environnement JAVA_HOME."
    elif [ "$gslang" = "ru" ]; then
	echo "Не удалось определить местонахождение соответствующей версии Java."
	echo "Вы должны установить Java Runtime Environment (версию $MIN_DISPLAY_VERSION или выше)"
	echo "перед вводом библиотечного $PROGNAME."
    else
	echo "Failed to locate an appropriate version of Java. You must install a"
	echo "Java Runtime Environment (version $MIN_DISPLAY_VERSION or greater) before running the"
	echo "$PROGNAME."
	echo "If you have Java installed on your machine please set the environment variable JAVA_HOME."
    fi
    return 1
}

function set_java_exec {	
    SEARCH4J_EXECUTABLE=${1};
    MINIMUM_JAVA_VERSION=${2};
    MIN_DISPLAY_VERSION=${3};

    # Give search4j a hint to find Java depending on the platform
    # we now include a JRE with Mac (Mountain) Lion, because from Yosemite onwards there's no system Java on Macs
    HINT=`cd "$GSDLHOME";pwd`/packages/jre    
    
    # we can't use boolean operator -a to do the AND, since it doesn't "short-circuit" if the first test fails
    # see http://www.tldp.org/LDP/abs/html/comparison-ops.html
    if [ "$GSDLOS" = "darwin" ] && [ ! -d "$HINT" ]; then
        # http://java.dzone.com/articles/java-findingsetting
	# explains that /usr/libexec/java_home will print the default JDK
	# regardless of which Mac OS we're on. Tested on Maverick, Lion, Leopard
	# (run `/usr/libexec/java_home -v 1.7` to find a specific version)

	# run silently in case no system java installed, as it will result in a confusing message about there being no java
	# when we're still searching for java 
	macHINT=`/usr/libexec/java_home 2>&1`
	#HINT=/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home
        #/System/Library/Frameworks/JavaVM.framework/Home
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
    
    javapath="`"$SEARCH4J_EXECUTABLE" -e -p "$HINT" -m $MINIMUM_JAVA_VERSION`"
    javahome="`"$SEARCH4J_EXECUTABLE" -p "$HINT" -m $MINIMUM_JAVA_VERSION`"

    if [ "$?" != "0" ]; then
	
        OLDVER="`"$SEARCH4J_EXECUTABLE" -v -p "$HINT"`"
	
        if [ "$?" = "0" ]; then
	    
            if [ "$gslang" = "es" ]; then
                echo "La versiСn del Ambiente de EjecuciСn Java (JRE por sus siglas en "
                echo "inglИs) que usted tiene instalada es demasiado vieja para ejecutar "
                echo "la Interfaz de la $PROGNAME. Por favor instale "
                echo "una nueva versiСn del Ambiente de EjecuciСn Java (versiСn $MIN_DISPLAY_VERSION o "
                echo "posterior) y ejecute nuevamente este guiСn."
            elif [ "$gslang" = "fr" ]; then
                echo "La version de Java Runtime Environment que vous avez installИe est"
                echo "trop vielle pour faire fonctionner $PROGNAME."
                echo "Veuillez installer une nouvelle version du JRE (version $MIN_DISPLAY_VERSION ou plus"
                echo "rИcente) et redИmarrez le script."
            elif [ "$gslang" = "ru" ]; then
                echo "Версия Java Runtime Environment, которую Вы установили, очень стара,"
                echo "чтобы управлять библиотечным $PROGNAME. Пожалуйста, "
                echo "установите новую версию JRE (версию $MIN_DISPLAY_VERSION или более новую) и"
                echo "переустановите этот скрипт"
            else
                echo "The version of the Java Runtime Environment you have installed ($OLDVER)"
                echo "is too old to run the $PROGNAME. Please install a new"
                echo "version of the JRE (version $MIN_DISPLAY_VERSION or newer) and rerun this script."
            fi
            return 1
	    
        else
	    no_java "$MIN_DISPLAY_VERSION"
	    return $?
        fi
	
    fi
    echo "Java:"
    echo $javapath
    echo
    return 0
}


## ---- Check Java ----
# Some users may set this line manually
#JAVA_HOME=
gslang=$1
PROGNAME=$2
MINIMUM_JAVA_VERSION=1.4.0_00
MIN_DISPLAY_VERSION=1.4

# sus out search4j
# first look for compiled search4j executable inside the current folder
if [ -x search4j ]; then
    SEARCH4J_EXECUTABLE=search4j	
elif [ -x "$GSDLHOME/bin/$GSDLOS/search4j" ]; then
    SEARCH4J_EXECUTABLE="$GSDLHOME/bin/$GSDLOS/search4j"
elif [ -x "$GSDL3SRCHOME/bin/$GSDLOS/search4j" ]; then
    SEARCH4J_EXECUTABLE="$GSDL3SRCHOME/bin/search4j"
elif [ -x "../bin/$GSDLOS/search4j" ]; then
    SEARCH4J_EXECUTABLE=../bin/$GSDLOS/search4j
elif [ -x "../bin/search4j" ]; then
    SEARCH4J_EXECUTABLE=../bin/search4j
else
    echo "Couldn't determine the location of the search4j executable"
    echo "If you are running Greenstone2"
    echo "   * check GSDLHOME is set"
    echo "   * check bin/$GSDLOS/search4j exists"
    echo "   * check bin/$GSDLOS/search4j is executable"
    echo "If you are running Greenstone3"
    echo "   * check GSDL3SRCHOME is set"
    echo "   * check bin/search4j exists"
    echo "   * check bin/search4j is executable"
    echo "   * try running 'ant compile-search4j'"
fi

# Now run set_java_exec with search4j if we found one, else try javahome
if [ "x$SEARCH4J_EXECUTABLE" != "x" ]; then
    set_java_exec "$SEARCH4J_EXECUTABLE" "$MINIMUM_JAVA_VERSION" "$MIN_DISPLAY_VERSION"
    retval=$?
else
    try_java "$MIN_DISPLAY_VERSION"
    retval=$?
fi
return $retval
