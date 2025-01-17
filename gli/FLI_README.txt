FLI, the Fedora Librarian Interface:
____________________________________

A Purpose of FLI:
FLI is built on top of GLI. Just as with GLI, it allows you to drag-and-drop documents into a collection which it will then build. The building process of FLI is different in that it will export the documents into a Fedora repository.


B Some limitations and workarounds
- You need the Greenstone server to be running on the same machine as where your Fedora machine is running. This may or may not remain a requirement in the future.
- FLI will put documents into the Fedora repository (a process called "ingesting into Fedora"). If you happen to encounter some connection failure problems please try the following and also inform us of the context of your problem. To overcome such a problem, what you need to do is:
 * Stop the fedora server
 * Go to FEDORA_HOME/tomcat/conf/Catalina/localhost/
(where FEDORA_HOME is your Fedora installation folder)
 * Create a file containing this XML:
<?xml version='1.0' encoding='utf-8'?>
<Context docBase="/full/path/to/parent/folder/of/your/greenstone/collectdir" path="/gsdl"></Context>
Where this full path would be your 
- GSDLHOME/web/sites/localsite for Greenstone 3, and 
- just plain GSDLHOME for Greenstone 2. 
Note that in both cases, it has to be the full path to the parent directory of the "collect" directory.
 * restart the fedora server
 * Now you can run FLI as described below.


C Prerequisites for running FLI: 
- You need Greenstone 2 or 3
- You need Fedora installed (which would have required you to set the environment variables FEDORA_HOME, CATALINA_HOME and JAVA_HOME). Then add a new environment variable called FEDORA_VERSION and set it to the value of your Fedora installation's version number.
- You need the Greenstone server running on the same machine as where your Fedora server is installed.


D Running FLI:
- If you have more than one Greenstone installed (Greenstone 2 and Greenstone 3), then first run the setup file for the Greenstone installation you want to use, so that your Greenstone environment is set up. 
If you were on linux, you would have to source the setup scripts by going into the Greenstone installation directory and typing
	source setup.bash
if it is Greenstone 2.
And
	source gs3-setup.sh
if it is Greenstone 3.	
If you're on Windows you would run setup.bat in the Greenstone 2 folder or gs3-setup.bat in the Greenstone 3 folder.
- If you're using a linux xterm, you'd go into Greenstone's gli folder and type:
	./fli.sh
If you're on Windows, go into Greenstone's gli folder and double-click on fli.bat
- Once FLI starts up, it will ask you the Fedora server details and your Fedora username and password to access the Fedora repository.
- Drag and drop documents into a collection as before, go to the Build tab and press the Build button. Once the building is finished, pressing the preview button will open the browser onto the Fedora search page. 
- If you have other digital objects in your Fedora repository besides the content generated by Greenstone, you will have to type "greenstone:*" (or just "greenstone*") in the search box--with the quotes.
If your Fedora repository only contains documents built in FLI, then pressing just the search button should be fine.
