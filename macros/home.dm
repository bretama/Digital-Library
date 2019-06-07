# this file must be UTF-8 encoded

package home

# set the title of the home page to be "greenstone digital library"
# in the currently chosen language

_pagetitle_ {_textdescrgreenstone_}

#######################################################################
# global navigation links
#######################################################################

# overridden here as we don't want 'home' links on this page

# home:helplink and home:preflink set in nav_css/ns4 macro files
_globallinks_ {_helplink_ _preflink_}

#######################################################################
# icons
#######################################################################

_iconmusiclibrary_ {<img src="_httpicontmusic_" border="1" alt="meldex music library" title="meldex music library">}

_imagecollection_ {<img src="_httpimg_/banner1.png" style="width:100%;height:100px;"

 alt="_textdescrgreenstone_">}

#######################################################################
# http macros 
#
# These contain the url without any quotes
#######################################################################

_httppagegsdl_ {_httppagex_(gsdl)}
_httppagehomepref_ {_httppagex_(homepref)}

#######################################################################
# images
#######################################################################

# Buttons for the pane after the collections and before the text

_button_ {<div class="homebutton"><span class="button"><a href="_1_">_2_</a></span></div>
}

_imagegli_ {_button_(_httppagegli_,_gli:textgli_)}

_imagecollector_ {_button_(_httppagecollector_,_collector:textcollector_)}



_imagedepositor_ {_button_(_httppagedepositor_,_depositor:textdepositor_)}

_imagetranslator_ {_button_(_httppagetranslator_,_gti:textgti_)}

_imageadmin_ {_button_(_httppagestatus_,_home:textadmin_)}

_imagegogreenstone_ {_button_(_home:httppagegsdl_,_home:textabgs_)}

_imagegodocs_ {_button_(_home:httppagedocs_,_home:textgsdocs_)}


#######################################################################
# page content                     
#######################################################################

# _homeextra_ is the automatically generated list of collections (in a table)
_content_ {
<div id="content">
<div class="divbar">
<p class="navbar">
_textdescrselcol_
</p>
</div>

<p>

<div class="section">
_homeextra_
</div>

<div class="divbar">&nbsp;</div>

<div class="section">
<table>
_textgogli_
_textgocollector_
_textgodepositor_
_textgotranslator_
_textgoadmin_
_textgogreenstone_
</table>
</div>

<div class="divbar">&nbsp;</div>

<div class="section">
_textaboutgreenstone_
</div>

<div class="divbar">&nbsp;</div>

</div>
}

_textaboutgreenstone_ {

<p>_gsdl:textgreenstone1_</p>
<p>_aimofsoftware_</p>
<p>_softwaredevel_</p>
<p>
<a href="http://nzdl.org"><b>_nzdltitle_</b></a><br>
_nzdldescr_</p>
_unescotitle_
<br>
_unescodescr_
_humaninfotitle_
<br>
_humaninfodescr_
</p>
}
# the _textgocollector_, _textgotranslator_, and _textgoadmin_ macros 
# may be overridden to be empty from within the receptionist if the 
# collector, translator, or admin facilities are disabled

_textgogli_ {
<tr valign=top>
<td valign=top>_imagegli_</td>
<td>_gli:textdescrgli_</td>
</tr>
}

_textgocollector_ {
<tr valign=top>
<td valign=top>_imagecollector_</td>
<td>_collector:textdescrcollector_</td>
</tr>
}

_textgodepositor_ {
<tr valign=top>
<td valign=top>_imagedepositor_</td>
<td>_depositor:textdescrdepositor_</td>
</tr>
}

_textgotranslator_ {
<tr valign=top>
<td valign=top>_imagetranslator_</td>
<td>_gti:textdescrtranslator_</td>
</tr>
}

_textgoadmin_ {
<tr valign=top>
<td valign=top>_imageadmin_</td>
<td>_textdescradmin_</td>
</tr>
}

_textgogreenstone_ {
<tr valign=top>
<td valign=top>_imagegogreenstone_</td>
<td>_textdescrgogreenstone_</td>
</tr>
}

_textgodocs_ {
<tr valign=top>
<td valign=top>_imagegodocs_</td>
<td>_textdescrgodocs_</td>
</tr>
}


package homepref
_pagetitle_ {_preferences:textpreferences_ - _textdescrgreenstone_}

_imagecollection_ {<a href="_httppagehome_"><img src="_httpimg_/banner1.png"  style="width:150%;height:100px;" alt="_textdescrgreenstone_" border="0"></a>}

_globallinks_ {_homelink_ _helplink_}

_pagescriptextra_ {_preferences:pagescriptextra_}

_content_ {
<div id="content">

<div class="divbar">&nbsp;</div>

<div class="section">
<form name="PrefForm" method="get" action="_gwcgi_">
<h3>_preferences:textpresentationprefs_</h3>

<table border="0">
<tr valign="top">
<td>_preferences:textlanguage_</td>
<td>_languageoption_</td>
</tr>
<tr valign="top">
<td>_preferences:textencoding_</td>
<td>_encodingoption_</td>
</tr>
<tr valign="top">
_preferences:formatoption_
</tr>
</table>
</div>

<div class="divbar">&nbsp;</div>

</div> <!-- \_homepref:content\_ -->
}
