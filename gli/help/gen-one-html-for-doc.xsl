<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html" encoding="UTF-8"/>

  <xsl:template match="Document">
    <html>
      <head>
        <title>The Greenstone Librarian Interface - Help Pages</title>
      </head>
      <body bgcolor="#E0F0E0">
	<xsl:for-each select="Section">
	  <!-- Skip the first section -->
	  <xsl:if test="position() > 1">
	    <xsl:call-template name="processSection">
	      <xsl:with-param name="sectionHead" select="position()"/>
	    </xsl:call-template>
          </xsl:if>
	</xsl:for-each>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="Reference">
    <xsl:variable name="target" select="@target"/>
    <xsl:value-of select="/Document//Section[@name=$target]/Title/Text"/>
  </xsl:template>

  <xsl:template match="Section"/>

  <xsl:template match="Title"/>


  <xsl:template name="processSection">
    <xsl:param name="sectionHead"/>

    <xsl:if test="Title">
        <xsl:call-template name="processTitle">
          <xsl:with-param name="sectionNumber" select="$sectionHead"/>
	  <xsl:with-param name="sectionTitle" select="Title"/>
        </xsl:call-template>
    </xsl:if>

    <xsl:apply-templates/>

    <xsl:for-each select="Section">
      <xsl:call-template name="processSection">
        <xsl:with-param name="sectionHead" select="concat($sectionHead, '.', position())"/>
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>


  <xsl:template name="processTitle">
    <xsl:param name="sectionNumber"/>
    <xsl:param name="sectionTitle"/>

    <xsl:choose>
      <xsl:when test="contains($sectionNumber, '.')">
        <h4><xsl:value-of select="$sectionTitle/Text"/></h4>
      </xsl:when>
      <xsl:otherwise>
        <h3><xsl:value-of select="$sectionTitle/Text"/></h3>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="Text">
    <p><xsl:apply-templates/></p>
  </xsl:template>

</xsl:stylesheet>