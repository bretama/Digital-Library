<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" encoding="UTF-8"/>

  <xsl:template match="Document">
    <Document>
    <xsl:for-each select="Section">
      <xsl:call-template name="processSection"/>
    </xsl:for-each>
    </Document>
  </xsl:template>

  <xsl:template name="processSection">
    <Section name="{@name}">
      <xsl:for-each select="Title">
        <Title>
          <xsl:apply-templates select="Text"/>
        </Title>
      </xsl:for-each>

      <xsl:for-each select="Section">
        <xsl:call-template name="processSection"/>
      </xsl:for-each>
    </Section>
  </xsl:template>
</xsl:stylesheet>