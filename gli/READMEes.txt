Interfaz de la Biblioteca Digital Greenstone
--------------------------------------------

Esta carpeta contiene la Interfaz de la Biblioteca Digital Greenstone (GLI
por sus siglas en inglés), una herramienta que le ayudará a crear y 
construir bibliotecas digitales por medio de Greenstone. La GLI le da 
acceso a las funciones de Greenstone desde una interfaz fácil de usar con 
la que solo tiene que apuntar y hacer click.

Para poder usar la GLI usted necesita una versión adecuada del Ambiente 
de Ejecución Java (versión 1.4.0 o posterior). Si aún no la tiene, podrá 
bajarla desde http://java.sun.com/j2se/downloads.html.

Recuerde que la GLI se ejecuta junto con los programas Greenstone, por 
lo que se asume que estará instalada en un subdirectorio de Greenstone. 
Si usted ya bajó de la Web una de las versiones de Greenstone o la instaló  
desde un CD-ROM, entonces éste será el caso.


-- Ejecución de la GLI bajo Windows --

Para correr la GLI bajo Windows explore la carpeta GLI que se encuentra 
en su instalación Greenstone (por medio de Windows Explorer) y haga 
doble click en el archivo gli.bat. Este archivo verificará que Greenstone, 
Perl y el Ambiente de Ejecución Java están instalados. A continuación 
inicie la Interfaz de la Biblioteca Digital Greenstone.


-- Ejecución de la GLI bajo UNIX --

Para correr la GLI bajo UNIX cambie al directorio GLI que se encuentra en 
su instalación Greenstone y ejecute el guión gli.sh. Este guión 
verificará que Greenstone, Perl y el Ambiente de Ejecución Java están 
instalados (asegúrese de que están en su ruta de búsqueda). A 
continuación inicie la Interfaz de la Biblioteca Digital Greenstone.


Por favor informe sobre cualquier problema que tenga al correr o usar la 
Interfaz de la Biblioteca Digital a la siguiente dirección:
greenstone@cs.waikato.ac.nz.


-- Compilación de la GLI --

Si usted ha bajado la versión con el código fuente de Greenstone o ha 
obtenido la GLI por medio de SVN, entonces tendrá el código fuente 
(Java) de la Interfaz de la Biblioteca Digital. Para compilarlo se necesita 
una versión adecuada del Kit de Desarrollo de Software Java (versión 
1.4.0 o posterior). Usted puede bajarlo desde 
http://java.sun.com/j2se/downloads.html.

Para compilar este código fuente ejecute los archivos makegli.bat 
(Windows) o makegli.sh (UNIX). Una vez que haya hecho esto usted 
podrá correr la GLI usando las instrucciones que aparecen arriba.
