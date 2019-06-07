---------------------------
A. THE apache.jar FILE
---------------------------

GLI's apache.jar is a custom jar file that collects together apache libraries necessary to compile, build and run GLI. There's no documentation on the various jar files that it contains, but I've guessed by inspecting the contents. 

Some of the contents are from xercesImpl.jar and xml-apis.jar, which may need to be kept up-to-date in tandem, since they are related and interdependent jar files as updates to xalan.jar for instance come with correspondingly updated xerces, xml-apis and other related jars.


Commit r29729 adds the contents of xml-apis.jar (sax) and xercesImpl.jar (both found in GS3/web/WEB-INF/lib else packages/tomcat/lib) into apache.jar, replacing the older xerces and xml-apis contained in apache.jar.
This update was necessary to handle commit r29687 where web.xml was split into web.xml and servlets.xml, with the former including the latter as an entity. GLI needs to use an EntityResolver to work with this, but the older xerces and xml-apis in apache.jar would still result in GLI failing to start, unable to parse web.xml because of the way in which servlets.xml was included. The xercesImpl and xml-apis jars in GS3/web/WEB-INF/lib (copied into packages/tomcat/lib) contain versions of these jars that do make the EntityResolver in GLI work.


---------------------------
CONTENTS OF apache.jar
---------------------------

Overview of the contents of apache.jar and whether they got updated in the upcoming commit 29729.

- javax: came with the updated version of xml-apis.jar
- license: came with the updated version of xml-apis.jar

- com: not sure where the contents came from, but they're not apache. Left them as-is.

- org:
	- w3c: replaced with w3c folder from xml-apis.jar from GS3/web/WEB-INF/lib (packages/tomcat/lib)	
		also added /org/w3c/dom/html/HTMLDOMImplementation.class of xercesImpl.jar in here, to replace the older version
	- xml: replaced with xml folder from xml-apis.jar from GS3/web/WEB-INF/lib (packages/tomcat/lib)
	- saxpath: left as-is. See jaxen below.
	- jaxen: left as-is. The latest version is 1.1.6 from jaxen.codehaus.org/releases.html, but it seems to be a separate project from apache's xerces and xml-apis and therefore not tightly connected with them. The latest version of jaxen includes saxpath, which means that jaxen and saxpath may be tightly connected to each other and require concurrent updating, even if they're not dependent on xerces and xml-apis and therefore not require concurrent updating with them.

	- apache: most of the contents, being the html, wml, xerces and xml folders have been replaced by their counterparts from the current version of xercesImpl.jar used in GS3/web/WEB-INF/lib (packages/tomcat/lib)
		- xmlcommons: replaced with org/apache/xmlcommons folder from xml-apis.jar from GS3/web/WEB-INF/lib (packages/tomcat/lib)
		- log4j: left as-is.
		- commons: left as-is. 
 			- codec: appears to be from commons-codec, 
			- logging: appears to be from commons-logging.
			- not sure where the 4 other subfolders of commons (beanutils, collections, digester, httpclient) are from. See commit message of http://trac.greenstone.org/log/gli/trunk/lib/apache.jar?rev=14319 for ideas.
		

Essentially, in commit 29729, the entire contents of GS3 web-lib's xml-apis.jar and xercesImpl.jar have been added to apache.jar after unzipping it, replacing earlier versions already present. The "javax" and "licence" toplevel folders of apache.jar are proper additions, deriving from xml-apis.jar. All other contents of apache.jar have been left as they were.


---------------------------
UPDATING apache.jar
---------------------------

After unzipping apache.jar, its contents were updated to use the later xerces and xml-apis as described above.

How to recreate the apache.jar:
> cd gli/lib/apache
> jar -cvf apache.jar *

The apache.jar file gets generated inside gli/lib/apache, move it into gli/lib. Then commit it.

Further changes to makejar.sh/bat, to mention the new javax subfolder, since it may also need to be unzipped from apache.jar along with the other contained libraries, so that xml-apis' javax too can be included in GLI.jar when this is generated, in case there is any dependence on javax in the rest of xml-apis' classes.




------------------------------------------------
B. THE jna.jar and jna-platform.jar FILES
------------------------------------------------

JNA = Java Native Access. These jar files are used by SafeProcess.java (in GLI and GS3 src code) to obtain the process ID of external processes launched by Java, so that on Windows, we can use the process ID to get the process IDs of subprocesses that were launched by our external process, and terminate them successfully. 

Generally, on Windows, process.destroy() only destroys the external process launched by Java. Not subprocesses.

SafeProcess now can terminate an external process and any subprocesses it launched, whereas formerly, on Windows, it would leave subprocesses running as orphans. This was noticed when GLI would run full-import.pl on a build, this would launch import.pl. When the build was cancelled through GLI, the full-import.pl script would be successfully terminated in Windows, but import.pl would still run to termination. A windows specific fix has been added for this, so that cancelling a build through GLI on Windows now does what Linux did by default on Java Process.destroy(): terminate any subprocesses launched by the process.


The official JNA source code project had been moved to Github when we discovered we needed it. However, the github JNA project hasn't yet made the jar files available, despite its GettingStarted documentation starting with an instruction to download the jna.jar. See https://github.com/java-native-access/jna/blob/master/www/GettingStarted.md

SafeProcess.java currently uses JNA version 4.1.0, which is from 2013. The jna-4.1.0.jar and jna-platform-4.1.0.jar were made available by the Maven MVN repository and were downloaded from https://mvnrepository.com/artifact/net.java.dev.jna/jna/4.1.0 and https://mvnrepository.com/artifact/net.java.dev.jna/jna-platform/4.1.0. See also https://mvnrepository.com/artifact/net.java.dev.jna/jna

The 2 JNA jar files were renamed to jna.jar and jna-platform.jar and were placed into gli/lib, for GLI's SafeProcess.java. This required an update to the gli/fli and makegli/makejar bash and batch scripts.
For the GS3 source code copy of SafeProcess.java, these files will be placed in web/WEB-INF/lib and may require an update to build.xml for compiling and running.

