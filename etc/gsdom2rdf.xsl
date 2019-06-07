<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:java="http://xml.apache.org/xslt/java"
        extension-element-prefixes="java"
        exclude-result-prefixes="java">

  <xsl:output method="text"/>


  <xsl:template name="escapeQuote">
    <xsl:param name="pText" select="."/>
    
    <xsl:if test="string-length($pText) >0">
      <xsl:value-of select="substring-before(concat($pText, '&quot;'), '&quot;')"/>
      
      <xsl:if test="contains($pText, '&quot;')">
        <xsl:text>\"</xsl:text>
	
        <xsl:call-template name="escapeQuote">
          <xsl:with-param name="pText" select=
			  "substring-after($pText, '&quot;')"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>


  <xsl:variable name="docoid"><xsl:value-of select="/Section/Description/Metadata[@name='Identifier']"/></xsl:variable>

  <xsl:template match="/">
@prefix dc:        &lt;http://purl.org/dc/elements/1.1/&gt; .
@prefix vcard:     &lt;http://www.w3.org/2001/vcard-rdf/3.0#&gt; .

@prefix gsembedded:  &lt;http://greenstone.org/gsembedded#&gt; .
@prefix gsextracted: &lt;http://greenstone.org/gsextracted#&gt; .
@prefix :            &lt;@libraryurl@/collection/@collect@/document/&gt; .

      <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="/Section/Description">

:<xsl:value-of select="$docoid"/>

    dc:Relation.isPartOf &lt;@libraryurl@/collection/@collect@&gt; ;

    <xsl:for-each select="Metadata">

      <xsl:variable name="metaname" select="@name"/>
<!--
      <xsl:variable name="metavalRaw"><xsl:value-of select="text()/></xsl:variable>
      <xsl:variable name="metavalSingleLine"><xsl:value-of select="replace($metavalRaw,'\n',' ')"/></xsl:variable>
-->

      <xsl:variable name="metaval"><xsl:call-template name="escapeQuote"><xsl:with-param name="pText" select="text()"/></xsl:call-template></xsl:variable>
<!--
      <xsl:variable name="metaval"><xsl:value-of select="replace($metavalEsc, '\n', '&lt;br /&gt;')"/></xsl:variable>
-->
<!--
      <xsl:variable name="metaval"><xsl:value-of select="$metavalEsc/></xsl:variable>
-->

      <xsl:if test="starts-with($metaname,'dc.')">
	<xsl:variable name="metanameSuffix"><xsl:value-of select="substring($metaname,4)"/></xsl:variable>
	dc:<xsl:value-of select="$metanameSuffix"/><xsl:text> </xsl:text>&quot;<xsl:value-of select="$metaval"/>&quot;<xsl:text> ;</xsl:text>
      </xsl:if>

      <xsl:if test="starts-with($metaname,'ex.')">
	<xsl:variable name="metanameSuffix"><xsl:value-of select="substring($metaname,4)"/></xsl:variable>
	gsembedded:<xsl:value-of select="$metanameSuffix"/><xsl:text> </xsl:text>&quot;<xsl:value-of select="$metaval"/>&quot;<xsl:text> ;</xsl:text>
      </xsl:if>

      <xsl:if test="starts-with($metaname,'nz.')">
	<xsl:variable name="metanameSuffix"><xsl:value-of select="substring($metaname,4)"/></xsl:variable>
	gsembedded:<xsl:value-of select="$metanameSuffix"/><xsl:text> </xsl:text>&quot;<xsl:value-of select="$metaval"/>&quot;<xsl:text> ;</xsl:text>
      </xsl:if>

      <xsl:if test="starts-with($metaname,'hathi.')">
	<xsl:variable name="metanameSuffix"><xsl:value-of select="substring($metaname,4)"/></xsl:variable>
	gsembedded:<xsl:value-of select="$metanameSuffix"/><xsl:text> </xsl:text>&quot;<xsl:value-of select="$metaval"/>&quot;<xsl:text> ;</xsl:text>
      </xsl:if>

      <xsl:if test="not(contains($metaname,'.'))">
	gsextracted:<xsl:value-of select="$metaname"/><xsl:text> </xsl:text>&quot;<xsl:value-of select="$metaval"/>&quot;<xsl:text> ;</xsl:text>
      </xsl:if>
      
    </xsl:for-each>
    .
  </xsl:template>

  <!-- *** Update to include section level metadata -->

  <xsl:template match="/Section/Content">
    <!-- Full text is supressed for now -->
  </xsl:template>

</xsl:stylesheet>

