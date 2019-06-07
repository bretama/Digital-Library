#!/bin/sh
glilang=en

##  -------- Clean up the Greenstone Librarian Interface directory --------

## ---- Remove class files ----
echo
if [ "$glilang" = "es" ]; then
    echo "Eliminando los archivos de clase de la Interfaz de la Biblioteca "
    echo "Digital Greenstone..."
elif [ "$glilang" = "fr" ]; then
    echo "Suppression des fichiers de classe de Greenstone Librarian Interface"
elif [ "$glilang" = "ru" ]; then
    echo "Удаление файлов класса библиотечного интерфейса Greenstone"
else
    echo "Removing the Greenstone Librarian Interface class files..."
fi

rm -rf GLI.jar
rm -rf classes/org/greenstone/gatherer/*

if [ "$glilang" = "es" ]; then
    echo "║Hecho!"
elif [ "$glilang" = "fr" ]; then
    echo "TerminИ!"
elif [ "$glilang" = "ru" ]; then
    echo "Выполнено!"
else
    echo "Done!"
fi
echo
