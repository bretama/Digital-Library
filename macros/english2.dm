# this file must be UTF-8 encoded
######################################################################
#
# Language text and icon macros 
# -- this file contains text that is of less importance
######################################################################


######################################################################
# 'home' page
package home
######################################################################

#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_documents_ { documents. }
_lastupdate_ {Last updated}
_ago_ {days ago.}
_colnotbuilt_ {Collection not built.}




_aimofsoftware_{<h4> This digital library software is for <b><strong>abiyi addi college of teacher education and educational leadership.</strong></b> the aim of the software is to help students to get modern knowladge using modern technology. Text books and audio books are stored on the server and students can access the books as client. </h4>}




_softwaredevel_{
    
}

_nzdltitle_{}

_nzdldescr_{




}

_unescotitle_{}

_unescodescr_{


}

_humaninfotitle_{}
_humaninfodescr_{}

_textdescrselcol_ {select a collection}


######################################################################
# home help page
package homehelp
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_text4buts_ {There are four further buttons on the home page}

_textnocollections_ {
<p>There are currently no collections available to this Greenstone installation. 
To add some collections you may either
<ul><li>Use <a href="_httppagecollector_">The Collector</a> to build new collections
    <li>If you have a Greenstone cd-rom you may install collections from cd-rom
</ul>
}

_text1coll_ {This Greenstone installation contains 1 collection}

_textmorecolls_ {This Greenstone installation contains _1_ collections}

######################################################################
# external link package
package extlink
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textextlink_ {External Link}
_textlinknotfound_ {Internal Link not Found}

_textextlinkcontent_ {The link you have selected is external to any of your currently selected collections.
    If you still wish to view this link and your browser has access to 
    the Web, you can <a href="_nexturl_" onClick="follow\_escaped\_link(event, this.href)">go forward</a> to this page; otherwise 
    use your browser's "back" button to return to the previous document.}

_textlinknotfoundcontent_ {For reasons beyond our control, the internal link you have selected 
    does not exist.  This is probably due to an error in the source collection.
    Use your browsers "back" button to return to the previous document.}

# should have arguments of collection, collectionname and link
_foundintcontent_ {

<h3>Link to "_2_" collection</h3>

<p> The link you have selected is external to the "_collectionname_"
    collection (it links to the "_2_" collection).
    If you wish to view this link in the "_2_" collection you can 
    <a href="_httpdoc_&amp;c=_1_&amp;cl=_cgiargclUrlsafe_&amp;d=_3_">go forward</a> to this page; 
    otherwise use your browser's "back" button to return to the previous document.
}


######################################################################
# authentication page
package authen
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textGSDLtitle_ {Greenstone Digital Library}

_textusername_ {username}
_textpassword_ {password}

_textmustbelongtogroup_ {Note that you must belong to the "_cgiargugHtmlsafe_" group to access this page}

_textmessageinvalid_ {The page you have requested requires you to sign in.<br>
_If_(_cgiargug_,[_textmustbelongtogroup_]<br>)
Please enter your Greenstone username and password.}

_textmessagefailed_ {Either your username or password was incorrect.}

_textmessagedisabled_ {Sorry, your account has been disabled. Please contact
the webmaster for this site.}

_textmessagepermissiondenied_ {Sorry, you do not have permission to access this page.}

_textmessagestalekey_ {The link you have followed is now stale. 
Please enter your password to access this page.}



######################################################################
# collectoraction
package wizard

_textbild_ {Build collection}
_textbildsuc_ {Collection built successfully.}
_textviewbildsummary_ {
You may <a href="_httppagex_(bsummary)" target=_top>view the build
summary</a> of this collection for further details.
}
_textview_ {View collection}

_textbild1_ {
The collection is now being built: this might take some time. The building
status line below gives feedback on how the operation is progressing.
}

_textbild2_ {
To stop the building process at any time, click here.
<br>The collection you are working on will remain unchanged.
}

_textstopbuild_ {stop building}

_textbild3_ {
If you leave this page (and have not cancelled the building process with
the "stop building" button) the collection will continue to build and will
be installed upon successful completion.
}

_textbuildcancelled_ {Build cancelled}

_textbildcancel1_ {
The collection building process was cancelled. Use the yellow buttons below
to make changes to your collection or restart the building process.
}

_textbsupdate1_ {Building status update in 1 second}
_textbsupdate2_ {Building status update in}
_textseconds_ {seconds}

_textfailmsg11_ {
The collection could not be built as it contains no data. Make sure that at
least one of the directories or files you specified on the <i>source
data</i> page exists and is of a type or (in the case of a directory)
contains files of a type, that Greenstone can process.
}

_textfailmsg21_ {The collection could not be built (import.pl failed).}
_textfailmsg31_ {The collection could not be built (buildcol.pl failed).}
_textfailmsg41_ {The collection was built successfully but could not be installed.}
_textfailmsg71_ {An unexpected error occurred while attempting to build your collection}


_textblcont_ {The build log contains the following information:}

######################################################################
# collectoraction
package collector
######################################################################



#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textdefaultstructure_ {default structure}
_textmore_ {more}
_textinfo_ {Collection information}
_textsrce_ {Source data}
_textconf_ {Configure collection}
_textdel_ {Delete collection}
_textexpt_ {Export collection}

_textdownloadingfiles_ {Downloading files ...}
_textimportingcollection_ {Importing collection ...}
_textbuildingcollection_ {Building collection ...}
_textcreatingcollection_ {creating collection ...}

_textcollectorblurb_ {
<i>The pen is mightier than the sword!
<br>Building and distributing information collections carries responsibilities
that you may want to reflect on before you begin.
There are legal issues of copyright: being able to access documents doesn't
mean you can necessarily give them to others.
There are social issues:  collections should respect the customs of the
community out of which the documents arise.
And there are ethical issues: some things simply should not be made 
available to others.
<br>Be sensitive to the power of information and use it wisely.
</i>
}

_textcb1_ {
The Collector helps you to create new collections, modify or add to
existing ones, or delete collections.  To do this you will be guided through a
sequence of Web pages which request the information that is needed.
}

_textcb2_ {First, you must decide whether to}
_textcnc_ {create a new collection}
_textwec_ {work with an existing one, adding data to it or deleting it.}

_textcb3_ {
In order to build or modify digital library collections you must sign in.
This is to protect you from others logging in to your computer and altering
the information on it.  Note: for security reasons you will be
automatically logged out once a 30 minute period has elapsed since you
logged in.  If this happens, don't worry! -- you will be invited to log in
again and can continue from where you left off.
}

_textcb4_ {
Please enter your Greenstone username and password, and click the button to
sign in.
}

_textfsc_ {
First select the collection that you want to work with (write protected
collections won't appear in this list).
}

_textwtc_ {With the collection you have selected, you can}
_textamd_ {Add more data and rebuild the collection}
_textetc_ {Edit the collection configuration file and rebuild the collection}
_textdtc_ {Delete the collection entirely}
_textetcfcd_ {Export the collection for writing to a self-installing Windows CD-ROM}
_textcaec_ {Changing an existing collection}
_textnwec_ {No write-enabled collections are available for modifying}
_textcianc_ {Creating a new collection}
_texttsosn_ {The sequence of steps needed to create a new digital library collection is:}
_textsin_ {Specify its name (and associated information)}
_textswts_ {Specify where the source data comes from}
_textatco_ {Adjust the configuration options (advanced users only)}
_textbtc_ {"Build" the collection (see below)}
_textpvyh_ {Proudly view your handiwork.}

_texttfsiw_ {
The fourth step is where the computer does all the work.  In the "building"
process the computer makes all the indexes and gathers together any other
information that is required to make things work.  But first you have to
specify the information.
}

_textadab_ {
A diagram appears below that will help you keep track of where you are.
The green button is the one that you click to carry on in the sequence.  As
you go through the sequence, the buttons will change to yellow.  You can
return to a previous page by clicking on the corresponding yellow button in
the diagram.
}

_textwyar_ {
When you are ready, click the green "collection information" button to
begin creating your new digital library collection!
}

_textcnmbs_ {Collection name must be specified}
_texteambs_ {Email address must be specified}
_textpsea_ {Please specify email address in the form: username@domain}
_textdocmbs_ {Description of collection must be specified}

_textwcanc_ {
When creating a new collection you need to enter some preliminary
information about the source data.  This process is structured as a series
of Web pages, overseen by The Collector.  The bar at the bottom of the page
shows you the sequence of pages to be completed.
}

_texttfc_ {Title for collection:}

_texttctiasp_ {
The collection title is a short phrase used throughout the digital library
to identify the content of the collection.  Example titles include
"Computer Science Technical Reports" and "Humanity Development Library."
}

_textcea_ {Contact email address:}

_textteas_ {
This email address specifies the first point of contact for the collection.
If the Greenstone software detects a problem, a diagnostic report is sent
to this address.  Enter an email address in its full form:
<tt>name@domain</tt>.
}

_textatc_ {About this collection:}

_texttiasd_ {
This is a statement describing the principles governing what is included in
the collection.  It appears on the first page when the collection is
presented.
}

_textypits_ {
Your position in the sequence is indicated by an arrow underneath--in this
case, the "collection information" stage.  To proceed, click the green
"source data" button.
}

_srcebadsources_ {
<p>One or more of the input sources you specified is unavailable (marked
_iconcross_ below).

<p>This might be because
<ul>
<li>The file, FTP site or URL does not exist.
<li>You need to dial up your ISP first.
<li>You are trying to access a URL from behind a firewall (this is the case
if you normally have to present a username and password to access the
internet).
</ul>

<p>If this is a URL that you can see in your browser, it may be coming from
a locally cached copy. Unfortunately, locally cached copies are invisible
to our mirroring process. In this case we recommend that you download the
pages using your browser first.
}

_textymbyco_ {
<p>You may base your collection on either
<ul>
<li>The default structure
<dl><dd>The new collection may contain documents in the following formats:
HTML, plain text, "m-box" email, PDF, RTF, MS Word, PostScript, PowerPoint, 
Excel, images, CDS/ISIS. </dd></dl>
<li>An existing collection
<dl><dd>The files in your new collection must be exactly the same type as those
used to build the existing one.</dd></dl>
</ul>
}

_textbtco_ {Base the collection on}
_textand_ {Add new data}
_textad_ {Adding data:}

_texttftysb_ {
The files that you specify below will be added to the collection. Make sure
that you do not re-specify files that are already in the collection:
otherwise two copies will be included. Files are identified by their full
pathname, Web pages by their absolute Web address.
}

_textis_ {Input sources:}

_textddd1_ {
<p>If you use file:// or ftp:// to specify a file, that file will be
downloaded.

<p>If you use http:// it depends on whether the URL gives you a normal web
page in your browser, or a list of files.  If a page, that page will be
downloaded -- and so will all pages it links to, and all pages they link
to, etc. -- provided they reside on the same site, below the URL.

<p>If you use file:// or ftp:// to specify a folder or directory, or give a
http:// URL that leads to a list of files, everything in the folder and all
its sub-folders will be included in the collection.

<p>Click the "more sources" button to get more input boxes.
}

_textddd2_ {
<p>Click one of the green buttons. If you are an advanced user you may want
to adjust the collection configuration. Alternatively, go straight to the
building stage. Remember, you can always revisit an earlier stage by
clicking its yellow button.
}

_textconf1_ {
<p>The building and presentation of your collection are controlled by
specifications in a special "configuration file".  Advanced users may want
to alter the configuration settings.

<center><p><b>If you are not an advanced user, just go to the bottom of the
page.</b></center> 

<p>To alter the configuration settings, edit the data that appears below.
If you make a mistake, click on "Reset" to reinstate the original
configuration settings.
}

_textreset_ {Reset}


_texttryagain_ {
Please <a href="_httppagecollector_" target=_top>restart the collector</a>
and try again.
}


_textretcoll_ {Return to the collector}

_textdelperm_ {
Some or all of the _cgiargbc1dirnameHtmlsafe_ collection could not be
deleted. Possible causes are:
<ul>
<li> Greenstone does not have permission to delete the _gsdlhome_/collect/_cgiargbc1dirnameHtmlsafe_
directory.<br>
You may need to remove this directory manually to complete the removal of the _cgiargbc1dirnameHtmlsafe_
collection from this computer.</li>
<li>Greenstone can not run the program _gsdlhome_/bin/script/delcol.pl. Make sure that this file is readable and executable.</li>
</ul>
}

_textdelinv_ {
The _cgiargbc1dirnameHtmlsafe_ collection is protected or invalid. Deletion was cancelled.
}

_textdelsuc_ {The _cgiargbc1dirnameHtmlsafe_ collection was successfully deleted.}

_textclonefail_ {
The _cgiargclonecolHtmlsafe_ collection cound not be cloned. Possible causes are:
<ul>
<li> The _cgiargclonecolHtmlsafe_ collection doesn't exist
<li> The _cgiargclonecolHtmlsafe_ collection has no collect.cfg configuration file
<li> Greenstone does not have permission to read the collect.cfg configuration file
</ul>
}

_textcolerr_ {Collector error.}

_texttmpfail_ {
The collector failed to read from or write to a temporary file or
directory. Possible causes are:
<ul>
<li> Greenstone does not have read/write access to the _gsdlhome_/tmp
     directory.
</ul>
}

_textmkcolfail_ {
The collector failed to create the directory structure required by the new
collection (mkcol.pl failed). Possible causes are:
<ul>
<li> Greenstone does not have permission to write to the _gsdlhome_/tmp
     directory.
<li> mkcol.pl perl script errors.
</ul>
}

_textnocontent_ {
Collector error: no collection name was provided for the new collection. Try 
restarting the Collector from the beginning.
}

_textrestart_ {Restart the Collector}

_textreloaderror_ {
An error occurred while creating the new collection. This may have been due
to Greenstone getting confused by the use of your browser's "reload" or
"back" buttons (please try to avoid using these buttons while creating a
collection with the Collector).  It is recommended that you restart the
Collector from the beginning.
}

_textexptsuc_ {
The _cgiargbc1dirnameHtmlsafe_ collection was successfully exported to the
_gsdlhome_/tmp/exported\__cgiargbc1dirnameHtmlsafe_ directory.
}

_textexptfail_ {
<p>Failed to export the _cgiargbc1dirnameHtmlsafe_ collection.

<p>This is likely to be because Greenstone was installed without the
necessary components to support the "Export to CD-ROM" function.
<ul>

 <li>If you installed a Greenstone version earlier than 2.70w from a CD-ROM 
 these components won't have been installed unless you selected them 
 during a "Custom" install. You may add them to your installation by re-running 
 the installation procedure.

 <li>If you installed Greenstone from a web distribution you will need to
 download and install an additional package to enable this function. Please
 visit <a href="http://www.greenstone.org">http://www.greenstone.org</a> or
 <a
 href="https://list.scms.waikato.ac.nz/mailman/listinfo/greenstone-users">the mailing list</a>
 for further details.

</ul>
}

######################################################################
# depositoraction
package depositor
######################################################################


_textdepositorblurb_ {

<p> Please specify the following file information and click _textintro_ below. </p>

}

_textcaec_ {Adding to an Existing Collection}
_textbild_ {Deposit Item}
_textintro_ {Select File}
_textconfirm_ {Confirmation}
_textselect_ {Select Collection}
_textmeta_ {Specify Metadata}
_textselectoption_ {select collection ...}

_texttryagain_ {
Please <a href="_httppagedepositor_" target=_top>restart the depositor</a>
and try again.
}

_textselectcol_ {Select the collection to which you would like to add a new document.}
_textfilename_ {Filename}
_textfilesize_ {Filesize}

_textretcoll_ {Return to the depositor}


_texttmpfail_ {
The depositor failed to read from or write to a temporary file or
directory. Possible causes are:
<ul>
<li> Greenstone does not have read/write access to the _gsdlhome_/tmp
     directory.
</ul>
}


######################################################################
# 'gsdl' page
package gsdl
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------


_textgreenstone1_ {

}

_textexamplestitle_ {}
_textgreenstone2_ {







}


_texttechnicaltitle_{}
_texttechnical_{





}


_textcustomisationtitle_ {}

_textgreenstone5_ { 





}


_textdocumentationtitle_ {}
_textdocuments_ {
    



}

_textsupporttitle_ {}

_textsupport_ { 


  }

_textbugstitle_ {}
_textreport_ {




}

_textaboutgslong_ {}

_textgreenstone_ { 


}

_texttokilink_ {}
_texttokidesc1_ {


 }


######################################################################
# 'users' page
package userslistusers
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textlocu_ {List of current users}
_textuser_ {user}
_textas_ {account status}
_textgroups_ {groups}
_textcomment_ {comment}
_textadduser_ {add a new user}
_textedituser_ {edit}
_textdeleteuser_ {delete}


######################################################################
# 'users' page
package usersedituser
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------


_textedituser_ {Edit user information}
_textadduser_ {Add a new user}

_textaboutusername_ {
Usernames must be between 2 and 30 characters long. They can contain
alphanumeric characters, '.', and '_'.
}

_textaboutpassword_ {
Passwords must be between 3 and 8 characters long. They can contain any
normal printable ASCII characters.
}

_textoldpass_ {If this field is blank the old password will be kept.}
_textenabled_ {enabled}
_textdisabled_ {disabled}

_textaboutgroups_ {
Groups is a comma separated list, do not put spaces after the commas.
}
_textavailablegroups_ {
Predefined groups include administrator and others which assign rights for remote collection building using the Librarian Interface or the Depositor:
<ul>
<li><b>administrator</b>: Gives permission to access and change site configuration and user accounts.
<li><b>personal-collections-editor</b>: Gives permission to create new personal collections
<li><b>&lt;collection-name&gt;-collection-editor</b>: Gives permission to create and edit the "collection-name" collection, for example, reports-collection-editor.
<li><b>all-collections-editor</b>: Gives permission to create new personal and global collections and edit <b>all</b> collections. Also gives permission to use the Collector.
</ul>
}


######################################################################
# 'users' page
package usersdeleteuser
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textdeleteuser_ {Delete a user}
_textremwarn_ {Do you really want to permanently remove user <b>_cgiargumunHtmlsafe_</b>?}


######################################################################
# 'users' page
package userschangepasswd
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textchangepw_ {Change password}
_textoldpw_ {old password}
_textnewpw_ {new password}
_textretype_ {retype new password}


######################################################################
# 'users' page
package userschangepasswdok
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textsuccess_ {Your password was successfully changed.}


######################################################################
# 'users' page
package users
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textinvalidusername_ {The username is invalid.}
_textinvalidpassword_ {The password is invalid.}
_textemptypassword_ {Please enter an initial password for this user.}
_textuserexists_ {This user already exists, please enter another username.}

_textusernameempty_ {Please enter your username.}
_textpasswordempty_ {You must enter your old password.}
_textnewpass1empty_ {Enter your new password and then retype it.}
_textnewpassmismatch_ {The two versions of your new password did not match.}
_textnewinvalidpassword_ {You entered an invalid password.}
_textfailed_ {Either your username or password was incorrect.}


######################################################################
# 'status' pages
package status
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------


_textversion_ {Greenstone version number}
_textframebrowser_ {You must have a frame enabled browser to view this.}
_textusermanage_ {User management}
_textlistusers_ {list users}
_textaddusers_ {add a new user}
_textchangepasswd_ {change password}
_textinfo_ {Technical information}
_textgeneral_ {general}
_textarguments_ {arguments}
_textactions_ {actions}
_textbrowsers_ {browsers}
_textprotocols_ {protocols}
_textconfigfiles_ {Configuration files}
_textlogs_ {Logs}
_textusagelog_ {usage log}
_textinitlog_ {init log}
_texterrorlog_ {error log}
_textadminhome_ {admin home}
_textreturnhome_ {Greenstone home}
_titlewelcome_ { Administration }
_textmaas_ {Maintenance and administration services available include:}
_textvol_ {view on-line logs}
_textcmuc_ {create, maintain and update collections}
_textati_ {access technical information such as CGI arguments}

_texttsaa_ {
These services are accessed using the side navigation bar on the lefthand
side of the page.
}

_textcolstat_ {Collection Status}

_textcwoa_ {
Collections will only appear as "running" if their build.cfg
files exist, are readable, contain a valid builddate field (i.e. > 0),
and are in the collection's index directory (i.e. NOT the building
directory).
}

_textcafi_ {click <i>abbrev.</i> for information on a collection}
_textcctv_ {click <i>collection</i> to view a collection}
_textsubc_ {Submit Changes}
_texteom_ {Error opening main.cfg}
_textftum_ {Failed to update main.cfg}
_textmus_ {main.cfg updated successfully}


######################################################################
# 'bsummary' pages
package bsummary
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------

_textbsummary_ {Build log for "_collectionname_" collection}
_textflog_ {Fail log for "_collectionname_" collection}
_textilog_ {Import summary for "_collectionname_" collection}

############################################################################
#
# This stuff is only used by the usability (SEND FEEDBACK) stuff
#
############################################################################
package Global

# old cusab button
_linktextusab_ {SEND FEEDBACK}

_greenstoneusabilitytext_ {Greenstone Usability}

_textwhy_ {<p>Sending this report is a way of indicating you have found the web page you were viewing difficult or frustrating.}
_textextraforform_ {You do not have to fill out the form -- any information will help.}
_textprivacybasic_ {<p>The report will contain only information about the Greenstone web page you were viewing, and the technology you were using to view it (plus any optional information you provide).}
_textstillsend_ {Would you still like to send this report?}

_texterror_ {error}
_textyes_ {Yes}
_textno_ {No}
_textclosewindow_ {Close Window}
_textabout_ {About}
_textprivacy_ {Privacy}
_textsend_ {Send}
_textdontsend_ {Don\\'t Send}
_textoptionally_ {Optionally}

_textunderdev_ {Details preview will be available in the final version.}

_textviewdetails_ {View report details}
_textmoredetails_ {More details}
_texttrackreport_ {Track this report}
_textcharacterise_ {What kind of problem is it}
_textseverity_ {How bad is the problem}
 
_textbadrender_ {Page looks strange}
_textcontenterror_ {Content error}
_textstrangebehaviour_ {Strange behaviour}
_textunexpected_ {Something unexpected happened}
_textfunctionality_ {Hard to use}
_textother_ {Other}

_textcritical_ {Critical}
_textmajor_ {Serious}
_textmedium_ {Medium}
_textminor_ {Minor}
_texttrivial_ {Trivial}

_textwhatdoing_ {What were you trying to do?}
_textwhatexpected_ {What did you expect to happen?}
_textwhathappened_ {What actually happened?}

_cannotfindcgierror_ {<h2>Sorry!</h2>Can\\'t find the server programs for the "_linktextusab_" button.}

_textusabbanner_ {the Greenstone koru-style banner}


######################################################################
# GTI text strings
package gti
######################################################################


#------------------------------------------------------------
# text macros
#------------------------------------------------------------
	
_textgtierror_ {An error has occurred}

_textgtihome_ {
These pages help you improve Greenstone's multilingual language support. Using them, you can
<ul>
  <li>translate parts of Greenstone into a new language
  <li>update an existing language interface when the English language interface changes (eg. for new Greenstone facilities)
  <li>correct errors in existing translations
</ul>

You will be presented with a series of web pages, each containing
a phrase to translate.
You proceed by translating the language interface phrase by phrase.
Many phrases contain HTML formatting commands: you should not
attempt to translate these but preserve them intact in the translated
version. Words flanked by underscores (like _this_) should not be
translated either (they're Greenstone "macro" names).
<p>
If you are updating an existing language interface you will not be presented
with phrases for which a translation already exists. Sometimes a translation
exists but the English text has since been changed. In this case the current
translation will be provided and you should check and update this if necessary.
<p>
To correct a translation that has already been updated, use the "Correct existing translations" facility available for each part of Greenstone.
<p>
Each page ends with a "_textgtisubmit_" button. When you press it, changes are
made immediately to a separate Greenstone installation at nzdl.org. A button
is provided on each page to access this site.
}

_textgtiselecttlc_ {Please select your language}

#for status page
_textgtiviewstatus_ {Click to view the current translation status for all languages}
_textgtiviewstatusbutton_ {VIEW STATUS}
_textgtistatustable_ {List of current translation status for all languages}
_textgtilanguage_ {Language}
_textgtitotalnumberoftranslations_ {Total number of translations}

_textgtiselecttfk_ {Please select a file to work on}

_textgticoredm_ {Greenstone Interface (Core)}
_textgtiauxdm_ {Greenstone Interface (Auxiliary)}
_textgtiglidict_ {GLI Dictionary}
_textgtiglihelp_ {GLI Help}
_textgtiperlmodules_ {Perl Modules}
_textgtitutorials_ {Tutorial Exercises}
_textgtigreenorg_ {Greenstone.org}
_textgtigs3interface_ {Greenstone 3 Interface}
_textgtigsinstaller_ {Greenstone Installer}
_textgtigs3colcfg_ {GS3 demo collection-config strings}

#for greenstone manuals
_textgtidevmanual_ {Greenstone Developer's Manual}
_textgtiinstallmanual_ {Greenstone Installer's Manual}
_textgtipapermanual_ {Greenstone Manual for Paper to Collection}
_textgtiusermanual_ {Greenstone User's Manual}

_textgtienter_ {ENTER}

_textgticorrectexistingtranslations_ {Correct existing translations}
_textgtidownloadtargetfile_ {Download file}
_textgtiviewtargetfileinaction_ {View this file in action}
_textgtitranslatefileoffline_ {Translate this file offline}

_textgtinumchunksmatchingquery_ {Number of text fragments matching the query}

_textgtinumchunkstranslated_ {translations done}
_textgtinumchunksrequiringupdating_ {Of these, _1_ require updating}
_textgtinumchunksrequiringtranslation_ {translations remaining}

#for status page
_textgtinumchunkstranslated2_ {number of translations done}
_textgtinumchunksrequiringupdating2_ {number of translations requiring updating}
_textgtinumchunksrequiringtranslation2_ {number of translations remaining}

_textgtienterquery_ {Enter a word or phrase from the text fragment you want to correct}
_textgtifind_ {FIND}

_textgtitranslatingchunk_ {Translating text fragment <i>_1_</i>}
_textgtiupdatingchunk_ {Updating text fragment <i>_1_</i>}
_textgtisubmit_ {SUBMIT}

_textgtilastupdated_ {Last updated}

_textgtitranslationfilecomplete_ {Thank you for updating this file -- it is now complete!<p>You can download a copy of this file using the link above, and it will also be included in future releases of Greenstone.}

_textgtiofflinetranslation_ {
You can translate this part of Greenstone offline using a Microsoft Excel spreadsheet file:

<ol>
<li>Download either <a href="_gwcgi_?a=gti&amp;p=excel&amp;tct=work&amp;e=_compressedoptions_">this file</a> for all the remaining work, or <a href="_gwcgi_?a=gti&amp;p=excel&amp;tct=all&amp;e=_compressedoptions_">this file</a> for all the strings in this module.
<li>Open the downloaded file in Microsoft Excel (Office 2003/XP or more recent versions is required) and save as Microsoft Excel workbook (.xls) format.
<li>Enter the translations in the boxes provided.
<li>When you have finished translating all the strings, e-mail the .xls file to <a href="mailto:_gtiadministratoremail_">_gtiadministratoremail_</a>.
</ol>
}



############
# gli page
############
package gli

_textglilong_ {Abiyi Addi librarian interface}
_textglihelp_ {
<p>The Greenstone Librarian Interface (GLI) gives you access to Greenstone's functionality from an easy-to-use, 'point and click' interface. This allows you to collect sets of documents, import or assign metadata, and build them into a Greenstone collection.</p>

<p>Note that the GLI is run in conjunction with Greenstone, and assumes that it is installed in a subdirectory of your Greenstone installation. If you have downloaded one of the Greenstone distributions, or installed from a Greenstone CD-ROM, this will be the case.</p>

<h4>Running the GLI under Windows</h4>
 
Launch the librarian interface under Windows by selecting <i>Greenstone Digital Library</i> from the <i>Programs</i> section of the <i>Start</i> menu and choosing <i>Librarian Interface</i>. 

<h4>Running the GLI under Unix</h4>

To run the GLI under Unix, change to the <i>gli</i> directory in your Greenstone installation, then run the <i>gli.sh</i> script. 

<h4>Running the GLI under Mac OS X</h4>

In the finder, browse to <i>Applications</i> then <i>Greenstone</i> (if you installed Greenstone into the default location), and then launch the <i>GLI</i> application.
}
