<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:java="http://xml.apache.org/xalan/java"
  extension-element-prefixes="java"
  xmlns:dict="http://xml.apache.org/xalan/java/Dictionary"
  exclude-result-prefixes="java dict">

  <xsl:output method="text" encoding="UTF-8"/>

  <!--<xsl:variable name="diction" select="java:Dictionary.new('en')"/>-->
    <xsl:variable name="diction" select="dict:new('en')"/>

  <xsl:template match="AutoText">
    <xsl:text>"</xsl:text><xsl:choose><xsl:when test="@key"><xsl:value-of select="java:get($diction, @key, @args)"/></xsl:when><xsl:otherwise><xsl:value-of select="@text"/></xsl:otherwise></xsl:choose><xsl:text>"</xsl:text>
  </xsl:template>

  <xsl:template match="Reference">
    <xsl:variable name="target" select="@target"/>
    <xsl:text>"</xsl:text><xsl:value-of select="/Document//Section[@name=$target]/Title/Text"/><xsl:text>"</xsl:text>
  </xsl:template>
  
</xsl:stylesheet>
