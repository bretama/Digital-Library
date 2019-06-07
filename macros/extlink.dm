# this file must be UTF-8 encoded

# If there are external links, call this function
_extlinkscript_ {

function follow_escaped_link (event, the_url) \{
  //http://stackoverflow.com/questions/8614438/preventdefault-inside-onclick-attribute-of-a-tag
  event.preventDefault();  

  //http://stackoverflow.com/questions/747641/what-is-the-difference-between-decodeuricomponent-and-decodeuri
  the_url = decodeURIComponent(the_url);
  var lastIndex = the_url.lastIndexOf("http://");
  if(the_url.indexOf("http://") !== lastIndex) \{
  	the_url = the_url.substring(lastIndex);
  \}
  location.href = the_url;
  
\}

}

package extlink

# override this to include _extlinkscript_
_globalscripts_{
<script language="javascript" type="text/javascript">
_extlinkscript_
</script>

}

_header_ {_htmlhead_}

_foundcontent_ {

<h3>_textextlink_</h3>

<p> _textextlinkcontent_
}

_notfoundcontent_ {

<h3>_textlinknotfound_</h3>

<p> _textlinknotfoundcontent_
}
