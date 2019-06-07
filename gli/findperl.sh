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
    echo "poder operar, pero �ste no aparece en su sistema. Por favor aseg�rese "
    echo "de que Perl est� instalado y se encuentra en su ruta de b�squeda. A "
    echo "continuaci�n ejecute nuevamente este gui�n."
    elif [ "$glilang" = "fr" ]; then
    echo "$PROGNAME n�cessite Perl pour son fonctionnement,"
    echo "mais perl n'a pas pu �tre d�tect� dans votre syst�me. Veuillez vous "
    echo "assurer que perl est install� et est sp�cifi� dans votre chemin de "
    echo "recherche, puis red�marrez ce script."
    elif [ "$glilang" = "ru" ]; then
    echo "������������ $PROGNAME ������� Perl, ����� ����� �����������"
    echo "��������, �� Perl �� ��� � ����� �������. ����������, �����������, ��� "
    echo "Perl ���������� � ��������� �� ����� ���� ������, ����� ���������������"
    echo "���� ������."
    else
    echo "The $PROGNAME requires Perl in order to operate,"
    echo "but perl could not be detected on your system. Please ensure that perl"
    echo "is installed and is on your search path, then rerun this script."
    fi
    exit 1
fi
echo $perlpath
echo
