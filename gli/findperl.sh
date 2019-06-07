# Exits with 1 if Perl is not on the PATH

##  ---- Check Perl exists ----
perlpath=

# Some users may set the above line manually
if [ "x$perlpath" = "x" ]; then
    # Check if Perl is on the search path
    perlpath=`which perl 2> /dev/null`
fi

# Check that a Perl executable has been found
echo "Perl:"
if [ ! -x "$perlpath" ] ; then
    echo
    if [ "$glilang" = "es" ]; then
    echo "La Interfaz de la $PROGNAME requiere Perl para "
    echo "poder operar, pero Иste no aparece en su sistema. Por favor asegЗrese "
    echo "de que Perl estА instalado y se encuentra en su ruta de bЗsqueda. A "
    echo "continuaciСn ejecute nuevamente este guiСn."
    elif [ "$glilang" = "fr" ]; then
    echo "$PROGNAME nИcessite Perl pour son fonctionnement,"
    echo "mais perl n'a pas pu Йtre dИtectИ dans votre systХme. Veuillez vous "
    echo "assurer que perl est installИ et est spИcifiИ dans votre chemin de "
    echo "recherche, puis redИmarrez ce script."
    elif [ "$glilang" = "ru" ]; then
    echo "Библиотечный $PROGNAME требует Perl, чтобы иметь возможность"
    echo "работать, но Perl не был в вашей системе. Пожалуйста, подтвердите, что "
    echo "Perl установлен и находится на вашем пути поиска, затем повторновведите"
    echo "этот скрипт."
    else
    echo "The $PROGNAME requires Perl in order to operate,"
    echo "but perl could not be detected on your system. Please ensure that perl"
    echo "is installed and is on your search path, then rerun this script."
    fi
    exit 1
fi
echo $perlpath
echo
