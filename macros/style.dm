# this file must be UTF-8 encoded
#######################################################################
# PAGE STYLES 
#######################################################################

package Style

# to use this style system output
# _header_
# all your page content, then
# _footer_

# use the page parameter 'style' to choose the appropriate style

# Current values: "html" and "xhtml"
_compliance_ {html}

# the style system uses
# _pagetitle_  - what gets displayed at the top of the browser window
# _pagescriptextra_ - any extra javascript you want included in the header
# _pagebannerextra_ - anything extra you want displayed in the page banner
# _pagefooterextra_ - anything extra you want displayed in the footer

# defaults for the above macros
_pagetitle_ {_collectionname_}
_pagescriptfileextra_ {}
_pagescriptextra_ {}
_pagebannerextra_ {}
_pagefooterextra_ {}

# collection specific style and script may be set in collection's extra.dm
# using the following macros
_collectionspecificstyle_ {}
_collectionspecificscript_ {}

# it also relies on lots of Globals, the most important of these are:
# _cookie_ - put in the cgi header
# _globalscripts_ - javascript stuff
# _imagecollection_
# _imagehome_
# _imagehelp_
# _imagepref_
# _imagethispage_ (this is now not an image, but text. should be renamed?)
# _linkotherversion_

# _httpiconchalk_ - the image down the left of the page - is now done
# by the style sheet.

_header_ {_cgihead_
_htmlhead_(class="bgimage")_startspacer__pagebanner_
}

_header_[v=1] {_cgihead_
_htmlhead__pagebanner_
}

# _cgihead_ {Content-type: text/html
# _cookie_
#
# }	
_cgihead_{}


# any declarations relating to CSS that should go in the html head part.
# declarations containing images are done here so the path is correct
# at runtime.

_csslink_{
  <link rel="stylesheet" href="_cssfilelink_" type="text/css" 
   title="Greenstone Style" charset="UTF-8" _linktagend_
  <link rel="alternate stylesheet" href="_httpstyle_/style-print.css"
   type="text/css" title="Printer" charset="UTF-8" media="print, screen" _linktagend_
  <link rel="stylesheet" href="_httpstyle_/style-print.css" type="text/css" 
   title="Printer" charset="UTF-8" media="print" _linktagend_ 
  _cssfilelinkextra_ 
}

_cssheader_ {
_csslink_
<style type="text/css">
body.bgimage \{ background: url("_httpimages_/chalk.gif") scroll repeat-y left top; \}
div.navbar \{ background-image: url("_httpimages_/bg_green.png"); \}
div.divbar \{ background-image: url("_httpimages_/bg_green.png"); \}
a.navlink \{ background-image: url("_httpimages_/bg_off.png"); \}
a.navlink_sel \{ background-image: url("_httpimages_/bg_green.png"); \}
a.navlink:hover \{ background-image: url("_httpimages_/usabbnr.gif"); \}
p.bannertitle \{background-image: url("_httpimages_/banner_bg.png"); \}
p.collectiontitle \{background-image: url("_httpimages_/banner_bg1.png"); \}
</style>
_collectionspecificstyle_

}

# separate macro so it can be easily overridden for customised collections
_cssfilelink_ {_httpstyle_/style.css}

# separate macro so additional stylesheets (to those included by default) can be specified
_cssfilelinkextra_ {}

# Languages that should be displayed right-to-left
_htmlextra_ [l=ar] { dir=rtl }
_htmlextra_ [l=fa] { dir=rtl }
_htmlextra_ [l=he] { dir=rtl }
_htmlextra_ [l=ur] { dir=rtl }
_htmlextra_ [l=ps] { dir=rtl }
_htmlextra_ [l=prs] { dir=rtl }

# htmlhead uses:
# _1_ - extra parameters for the body tag
# _pagetitle_
# _globalscripts_
_htmlhead_ {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
"http://www.w3.org/TR/html4/loose.dtd">

<html_htmlextra_>
<head>
<title>_pagetitle_</title>
<meta name="Greenstone_version_number" content="_versionnum_" _metatagend_
_globalscripts_
_cssheader_
_document:documentheader_
</head>

<body _1_>
}

# Link and meta tags must be closed differently for HTML/XHTML validation
_linktagend_ {_If_("_compliance_" eq "xhtml",/>,>)}
_metatagend_ {_If_("_compliance_" eq "xhtml",/>,>)}

_spacerwidth_ {65}

# _startspacer_ is a spacer that gives pages a left-hand margin. 
# It must eventually be closed by _endspacer_.
_startspacer_ {
<div id="page">
}

# If you want to move the home/help/pref buttons, override this to be empty 
# and then explicitly include _globallinks_ somewhere else
# on the page
_optgloballinks_ {_globallinks_}

# _bannertitle_ is defined in nav_css/ns4.dm, and is either text or
# a banner image
_pagebanner_ {
<!-- page banner (\_style:pagebanner\_) -->
<div id="banner">
<div class="pageinfo"> 
<p class="bannerlinks">_optgloballinks_</p>
_bannertitle_
</div>
<div class="collectimage">_imagecollection_</div>
</div>
<div class="bannerextra">_pagebannerextra_</div>
<!-- end of page banner -->
_If_("_activateweb20_" eq "2",
  _If_("_activatetalkback_" eq "1",_talkback:uploadForm_)
)
}

_pagebanner_[v=1] {
<!-- page banner - text version [v=1] (\_style:pagebanner\_) -->
<center><h2><b><u>_imagecollection_</u></b></h2></center><p>
_optgloballinks_
_pagebannerextra_
<p>
<!-- end of page banner -->
_If_("_activateweb20_" eq "2",
  _If_("_activatetalkback_" eq "1",_talkback:uploadForm_)
)
}

# note we no longer close off one of the startspacer tables here!!
_footer_ {
_If_("_cgiargtalkback_" eq "1",_talkback:monitorUpload_)
<!-- page footer (\_style:footer\_) -->
_pagefooterextra_

<div style="margin-top:100px;background:#b3ffb3;height:50px;padding:10px;width:90%;position:fixed;bottom:0px;font-size:20pt;float:left;">
		<div style="float:left;" >
		visit:<a href="https://www.abiadicte.edu.et" style="text-decoration:none;">Abbiyi Addi CTE</a>
		   </div>
		  <div style="float:right;margin-left:30px;" >
		<u>Abiyi Addi digital library</u></br> &#169; 2018
		</div> 
 </div>

 
   
   


 _endspacer_
_htmlfooter_
}

# v=1 footer: not using startspacer in the header, so dont put it in the footer
_footer_ [v=1]{
_If_("_cgiargtalkback_" eq "1",_talkback:monitorUpload_)
<!-- page footer [v=1] (\_style:footer\_) -->
_pagefooterextra_
 Abiyi Addi digital library

_htmlfooter_
}

# close off anything opened by startspacer
_endspacer_ {	
</div> <!-- id=page -->
}	


_htmlfooter_ {
</body>
</html>
}

_loginscript_ {
   function appendUsernameArgs(id,addOn)
   \{
     var a=document.getElementById(id);
     var url = a.getAttribute("href");
     if (url == "") \{
       url = document.location.toString();
     \}

     //alert("url before = " + url);

     // clear out any earlier user name/authentication values
     url = url.replace(/(&|\\\\?)uan=\\d\{0,1\}/g,"");
     url = url.replace(/(&|\\\\?)un=[a-z0-9:\\-]*/g,"");
     url = url.replace(/(&|\\\\?)pw=[a-z0-9:\\-]*/g,"");

     //alert("url after = " + url);

     var gwcgi = "_gwcgi_";

     var tailUrl = url.substr(url.length-gwcgi.length);

     url += (tailUrl == "_gwcgi_") ? "?" : "&";
     url += addOn;

     //alert("url with add on = " + url);

     a.setAttribute("href",url);
   \}
}


# imagescript only used in nav_ns4.dm
_globalscripts_{
  <script type="text/javascript" src="_httpscript_/gsajaxapi.js"></script>

  <script language="javascript" type="text/javascript">
    function gsdefined(val) 
    \{
       return (typeof(val) != "undefined");
    \}

    var un = "_cgiargunJssafe_";
    var ky = "_cgiargkyJssafe_";
    var gsapi = new GSAjaxAPI("_gwcgi_","_cgiargcJssafe_","_cgiargunJssafe_","_cgiargkyJssafe_");
    
    // http://stackoverflow.com/questions/6312993/javascript-seconds-to-time-with-format-hhmmss
    // Call as: alert(timestamp.printTime());
    function formatTime(timestamp) \{
      var int_timestamp    = parseInt(timestamp, 10); // don't forget the second param
      var date = new Date(int_timestamp);
      return date.toLocaleDateString() + " " + date.toLocaleTimeString();   
   \}

    function loadUserComments() \{

        // don't bother loading comments if we're not on a document page (in which case there's no usercommentdiv)
        var usercommentdiv = document.getElementById("usercomments");
	if(usercommentdiv == undefined || usercommentdiv == null) \{
	return;
	\}

	// else, if we have a usercommentdiv, we would have a docid. Get toplevel section of the docid
	var doc_id = "_cgiargdJssafe_"; //escape("cgiargd");
	var period = doc_id.indexOf(".");
	if(period != -1) \{
	    doc_id = doc_id.substring(0, period);
	\}

	var username_rec = \{
	    metaname: "username",
	    metapos: "all"
	\};

	var timestamp_rec = \{
	    metaname: "usertimestamp",
	    metapos: "all"
	\};

	var comment_rec = \{
	    metaname: "usercomment",
	    metapos: "all"
	\};

	var doc_rec = \{
	    docid: doc_id,
	    metatable: [username_rec, timestamp_rec, comment_rec]	    
	\};

	var docArray = [doc_rec];
	//alert(JSON.stringify(docArray));

	var json_result_str = gsapi.getMetadataArray(docArray, "index");
//	alert(json_result_str);
	var result = JSON.parse(json_result_str);
	// result contains only one docrec (result[0]), since we asked for the usercomments of one docid
	var metatable = result[0].metatable;
//	alert(JSON.stringify(metatable));

	var i = 0;
	var looping = true;
	var print_heading = true;

	// metatable[0] = list of usernames, metatable[1] = list of timestamps, metatable[2] = list of comments	
	// the 3 lists/arrays should be of even length. Assuming this, loop as long as there's another username
	while(looping) \{
		var metaval_rec = metatable[0].metavals[i];
		if(metaval_rec == undefined) \{
		    looping = false;
		\} 
		else \{

		    if(print_heading) \{
		         var heading=document.createElement("div");
		       	 var attr=document.createAttribute("class");
		       	 attr.nodeValue="usercommentheading";
		       	 heading.setAttributeNode(attr);
		       	 var txt=document.createTextNode("_textusercommentssection_");
		       	 heading.appendChild(txt);
		      	 usercommentdiv.appendChild(heading);

 		         print_heading = false;
		    \}

    		    var username = metaval_rec.metavalue;
		    var timestamp = metatable[1].metavals[i].metavalue;  
		    var comment = metatable[2].metavals[i].metavalue; 

		    //alert("Comment: " + username + " " + timestamp + " " + comment);

		    // No need to sort by time, as the meta are already stored sorted 
		    // and hence retrieved in the right order by using the i (metapos) counter
		    // If sorting the array of comment records, which would be by timestamp, see
		    // https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/Array/sort

		     // for each usercomment, create a child div with the username, timestamp and comment
		     displayInUserCommentList(usercommentdiv, username, timestamp, comment);
		     
		     i++;
	     \}		
	\}

    \}


    function displayInUserCommentList(usercommentdiv, username, timestamp, comment) \{

    	var divgroup=document.createElement("div");
	var attr=document.createAttribute("class");
	attr.nodeValue="usercomment";
	divgroup.setAttributeNode(attr);

	var divuser=document.createElement("div");
	var divtime=document.createElement("div");
	var divcomment=document.createElement("div");

	
	divgroup.appendChild(divuser);
	var txt=document.createTextNode(username);
	divuser.appendChild(txt);

	divgroup.appendChild(divtime);
	txt=document.createTextNode(formatTime(timestamp)); // format timestamp for date/time display
	divtime.appendChild(txt);

	// any quotes and colons in the fields would have been protected for transmitting as JSON
	// so decode their entity values
	comment = comment.replace(/&quot;/gmi, '"');
	comment = comment.replace(/&58;/gmi, ':');

	divgroup.appendChild(divcomment);
	txt=document.createTextNode(comment);
	divcomment.appendChild(txt);

	usercommentdiv.appendChild(divgroup);
    	     
    \}

    // http://stackoverflow.com/questions/807878/javascript-that-executes-after-page-load
    // ensure we don't replace any other onLoad() functions, but append the loadUserComments() 
    // function to the existing onLoad handlers

    if(window.onload) {\
        var curronload = window.onload;
        var newonload = function() {\
            curronload();
            loadUserComments();
        \};
        window.onload = newonload;
    \} else {\
        window.onload = loadUserComments;
    \}
  </script>

_If_("_activatejquery_" eq "1",_jqueryScriptAndStyle_)

_If_("_activateweb20_" eq "2",
  _If_("_activateseaweed_" eq "1",_seaweedscript_)
  _If_("_activatetalkback_" eq "1",_talkbackscript_)
)
_If_(_pagescriptfileextra_,_pagescriptfileextra_)
<script language="javascript" type="text/javascript">
_loginscript_
_If_(_pagescriptextra_,_pagescriptextra_)
_collectionspecificscript_
_imagescript_
</script>
}

_globalscripts_ [v=1] {

_If_("_activatejquery_" eq "1",_jqueryScriptAndStyle_)

_If_("_activateweb20_" eq "2",
  <script type="text/javascript" src="_httpscript_/gsajaxapi.js"></script>
  _If_("_activateseaweed_" eq "1",_seaweedscript_)
  _If_("_activatetalkback_" eq "1",_talkbackscript_)
)
_If_(_pagescriptfileextra_,_pagescriptfileextra_)
<script language="javascript" type="text/javascript">
<!--
_loginscript_
_If_(_cgiargx_,_scriptdetach_)
_If_(_pagescriptextra_,_pagescriptextra_)
_collectionspecificscript_
// -->
</script>
}

_scriptdetach_ {
    function close\_detach() \{
	close();
    \}
}


_jqueryScriptAndStyle_ {
<link type="text/css" href="_httpstyle_/max-video/jquery-ui-1.8.4.custom.css" rel="stylesheet" />
<script type="text/javascript" src="_httpscript_/jquery-1.4.2.min.js"></script>
<script type="text/javascript" src="_httpscript_/jquery-ui-1.8.4.custom.min.js"></script>
}

