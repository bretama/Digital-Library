<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:java="http://xml.apache.org/xalan/java"
  xmlns:dict="http://xml.apache.org/xalan/java/Dictionary"
  extension-element-prefixes="java"
  exclude-result-prefixes="java dict">

  <xsl:output method="html" encoding="UTF-8"/>

 <!-- <xsl:variable name="diction" select="java:Dictionary.new('en')"/>-->
    <xsl:variable name="diction" select="dict:new('en')"/>

  <xsl:template match="Document">
    <xsl:for-each select="Section">
      <xsl:call-template name="processSection">
	<xsl:with-param name="sectionHead" select="position()"/>
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>


  <xsl:template match="Reference">
    <xsl:variable name="target" select="@target"/>
    <a href="{@target}.htm"><xsl:value-of select="/Document//Section[@name=$target]/Title/Text"/></a>
  </xsl:template>


  <xsl:template match="Section"/>


  <xsl:template match="Title"/>

  <xsl:template match="Text">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template name="processSection">
    <xsl:param name="sectionHead"/>

    <html>
      <head>
        <title>The Greenstone Librarian Interface - Help Pages</title>
      </head>
      <body bgcolor="#E0F0E0">
        <table border="2" bgcolor="#B0D0B0" cellpadding="5" cellspacing="0" width="100%">
          <tr>
            <td align="center" width="15%">
              <img height="45" src="../gatherer_medium.gif" width="45"/>
            </td>
            <td align="center" width="*">
              <a name="{@name}">
                <xsl:call-template name="processTitle">
                  <xsl:with-param name="sectionNumber" select="$sectionHead"/>
	          <xsl:with-param name="sectionTitle" select="Title"/>
                </xsl:call-template>
              </a>	    
            </td>
            <td align="center" width="15%">
              <img height="45" src="../gatherer_medium.gif" width="45"/>
            </td>
          </tr>
        </table>

        <xsl:apply-templates/>
      </body>
    </html>

    <xsl:for-each select="Section">
      <xsl:call-template name="processSection">
        <xsl:with-param name="sectionHead" select="concat($sectionHead, '.', position())"/>
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>


  <xsl:template name="processTitle">
    <xsl:param name="sectionNumber"/>
    <xsl:param name="sectionTitle"/>

    <font face="Verdana" size="5">
      <strong>
        <xsl:value-of select="concat($sectionNumber, ': ', $sectionTitle/Text)"/>
      </strong>
    </font>
  </xsl:template>

   <xsl:template match="span|img|table|b|br|td|tr|u|i">
    <xsl:copy><xsl:for-each select="@*"><xsl:copy/></xsl:for-each>
        <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="AutoText">
    <xsl:variable name="value"><xsl:choose><xsl:when test="@key"><xsl:value-of select="java:get($diction, @key, @args)"/></xsl:when><xsl:otherwise><xsl:value-of select="@text"/></xsl:otherwise></xsl:choose></xsl:variable>
    <xsl:choose>
      <xsl:when test="@type='button'">
	<b>&lt;<xsl:value-of select="$value"/>&gt;</b>
      </xsl:when>
      <xsl:when test="@type='quoted'">
	<xsl:text>"</xsl:text><xsl:value-of select="$value"/><xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:when test="@type='italics'">
	<i><xsl:value-of select="$value"/></i>
      </xsl:when>      
      <xsl:when test="@type='plain'">
	<xsl:value-of select="$value"/>
      </xsl:when>      
      <xsl:when test="@type='bold'">
	<b><xsl:value-of select="$value"/></b>
      </xsl:when>      
      <xsl:otherwise>
	<xsl:text>"</xsl:text><xsl:value-of select="$value"/><xsl:text>"</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
