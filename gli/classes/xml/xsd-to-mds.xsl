<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:xalan="http://xml.apache.org/xslt">

<!-- Change these values to match the desired namespace and metadata set name. -->	
<xsl:variable name="namespace">cdwalite</xsl:variable>
<xsl:variable name="setName">CDWALite</xsl:variable>

 <!-- for CDWALite, processing starts at this element. May be different for other metadata sets in XSD format. change "descriptiveMetadata" to appropriate root element-->
<xsl:variable name="startElement">descriptiveMetadata</xsl:variable>
	
	
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" xalan:indent-amount="4"/>
 <xsl:strip-space elements="*"/> 


<xsl:template match="xsd:element[@name=$startElement]">
	<xsl:call-template name="elements"/>
</xsl:template> 


<xsl:template name="elements">
<xsl:for-each select="xsd:complexType/xsd:sequence/xsd:element">
<xsl:variable name="elementName" select="substring-after(@ref, ':')"/>

<xsl:for-each select="ancestor::xsd:schema/xsd:element[@name=$elementName]">
<Element name="{@name}">
	<Language code="en">
	<Attribute name="label"><xsl:value-of select="@name"/></Attribute>
			<Attribute name="definition"><xsl:value-of select="xsd:annotation/xsd:documentation"/></Attribute>
			<Attribute name="comment"/>
		</Language>

<xsl:call-template name="elements"/>
</Element>
</xsl:for-each>
</xsl:for-each>
</xsl:template>
 

<xsl:template match="/">
 <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE MetadataSet SYSTEM "http://www.greenstone.org/dtd/MetadataSet/1.0/MetadataSet.dtd"></xsl:text>
<MetadataSet contact="" creator="" family="" lastchanged="" namespace="{$namespace}">
	<SetLanguage code="en">
		<Name><xsl:value-of select="$setName"/></Name>
		<Description/>
	</SetLanguage>
<xsl:apply-templates select="xsd:schema/xsd:element[@name=$startElement]"/>
</MetadataSet>

</xsl:template>
	
</xsl:stylesheet>