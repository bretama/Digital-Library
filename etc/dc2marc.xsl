<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      	 xmlns:xsltutil="xalan://org.nzdl.gsdl.ApplyXSLTUtil"
         exclude-result-prefixes="xsltutil">

  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="mapping" />	

  <xsl:template match="/">
     <collection xmlns="http://www.loc.gov/MARC21/slim">
           <xsl:apply-templates select="/MARCXML/MetadataList"/>
      </collection>
 </xsl:template>
 
  <xsl:template match="MetadataList">
       <xsl:variable name="lang" >
       	<xsl:choose>      
           <xsl:when test="Metadata[@name='dc.Language']">
                <xsl:value-of select="Metadata[@name='dc.Language']"/>                    
            </xsl:when>            
            <!-- comment out this if you want to test dls.Language as well
             <xsl:when test="Metadata[@name='dls.Language']">
                <xsl:value-of select="Metadata[@name='dls.Language']"/>                    
             </xsl:when>
            -->
            <xsl:when test="Metadata[@name='Language']">
                  <xsl:value-of select="Metadata[@name='Language']"/>
            </xsl:when>           
           <!-- the defualt language is english --> 
            <xsl:otherwise>
                 <xsl:value-of select="en"/>	
             </xsl:otherwise>
           </xsl:choose>   
       </xsl:variable>	
      <xsl:variable name="item" select="$mapping/stopwords[@lang=$lang]/item"/>
      <record xmlns="http://www.loc.gov/MARC21/slim">
	  <xsl:apply-templates select="$mapping/leader">
	     <xsl:with-param name="source" select="." />   
	  </xsl:apply-templates>                 
          <xsl:apply-templates select="$mapping/controlfield[@required='true']" /> 
      	  <xsl:apply-templates select="$mapping/MarcField" >
	      <xsl:with-param name="source" select="." /> 
              <xsl:with-param name="item" select="$item" />   
	  </xsl:apply-templates>                       
      </record>   
  </xsl:template>

  <xsl:template match="leader">
     <xsl:param  name="source" />	
      <leader xmlns="http://www.loc.gov/MARC21/slim">
         <xsl:for-each select="*">
           <xsl:choose>
             <xsl:when test="@pos='3' and count($source/Metadata[@name='dc.Type'])=1">
                <xsl:apply-templates select="$mapping/recordTypeMapping/type[1]" mode="mapping-type" >
                  <xsl:with-param name="dctype" select="$source/Metadata[@name='dc.Type'][1]/text()"/>     
                </xsl:apply-templates>
            </xsl:when> 
            <xsl:when test="@pos='3' and count($source/Metadata[@name='dc.Type'])=2
                                     and $source/Metadata[@name='dc.Type' and text()='collection']">
                <xsl:apply-templates select="$mapping/recordTypeMapping/type[1]" mode="mapping-type" >
                  <xsl:with-param name="dctype" select="$source/Metadata[@name='dc.Type' and text()!='collection']/text()"/>
                </xsl:apply-templates>                     
            </xsl:when> 
             <xsl:when test="@pos='3' and count($source/Metadata[@name='dc.Type'])=2" >
                <xsl:apply-templates select="$mapping/recordTypeMapping/type[1]" mode="mapping-type" >
                  <xsl:with-param name="dctype" select="$source/Metadata[@name='dc.Type'][1]"/>
                </xsl:apply-templates>                     
            </xsl:when>   
            <xsl:when test="@pos='3' and count($source/Metadata[@name='dc.Type'])>2 ">
                  <xsl:value-of select="'m'"/>
            </xsl:when> 
            <xsl:when test="@pos='4' and $source/Metadata[@name='dc.Type' and text()='collection']">
                <xsl:value-of select="'c'"/>
            </xsl:when>
            <xsl:otherwise>
                 <xsl:value-of select="@value"/>	
             </xsl:otherwise>
           </xsl:choose>      
         </xsl:for-each>
       </leader>  
  </xsl:template>

    
  <xsl:template match="type" mode="mapping-type">
   <xsl:param name="dctype" />  
     <xsl:variable name="typename" select="@name"/>    
      <xsl:choose>     
           <xsl:when test="$dctype=$typename or count(following-sibling::*)=0">
               <xsl:choose>
                 <xsl:when test="count(following-sibling::*) !=0 ">
                     <xsl:value-of select="@mapping"/>                                      
                 </xsl:when>                                      
                 <xsl:otherwise>
                       <xsl:value-of select="'a'"/>  
                 </xsl:otherwise>               
               </xsl:choose> 
           </xsl:when>
         <xsl:otherwise>
             <xsl:apply-templates select="following-sibling::*[1]" mode="mapping-type" >
                <xsl:with-param name="dctype" select="$dctype" />                   
             </xsl:apply-templates>
         </xsl:otherwise>
      </xsl:choose>
  </xsl:template>
 
  <xsl:template match="controlfield">
     <controlfield tag="{@tag}" xmlns="http://www.loc.gov/MARC21/slim"><xsl:value-of select="@value"/></controlfield>  
  </xsl:template>
 
 
  <xsl:template match="MarcField">
   <xsl:param  name="source" />  
   <xsl:param  name="item" /> 
   <xsl:variable name="this" select="."/> 
   <xsl:choose>
      <xsl:when test="@multiple='true'">
        <xsl:variable name="meta" select="subfield[1]/@meta"/>       
        <xsl:for-each select="$source/Metadata[@name=$meta]">
         <xsl:apply-templates select="$this/subfield[1]" mode="testing"> 
                <xsl:with-param name="pos" select="position()"/> 
	        <xsl:with-param name="source" select="$source"/>
                <xsl:with-param name="item" select="$item"/> 
            </xsl:apply-templates>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="@repeat='true'">
        <xsl:variable name="meta" select="subfield[1]/@meta"/>
        <xsl:for-each select="$source/Metadata[@name=$meta][position()!=1]">
           <xsl:apply-templates select="$this/subfield[1]" mode="testing"> 
               <xsl:with-param name="pos" select="position()+1"/> 
	       <xsl:with-param name="source" select="$source"/>
               <xsl:with-param name="item" select="$item"/>  
            </xsl:apply-templates>
        </xsl:for-each>
      </xsl:when>
       <xsl:otherwise>
         <xsl:apply-templates select="subfield[1]" mode="testing">
           <xsl:with-param name="pos" select="'0'"/> 
	   <xsl:with-param name="source" select="$source"/> 
           <xsl:with-param name="item" select="$item"/>  
         </xsl:apply-templates>
       </xsl:otherwise> 
    </xsl:choose>        
  </xsl:template>
  
  <xsl:template match="subfield" mode="testing">
     <xsl:param name="pos"/>
     <xsl:param  name="source" /> 
     <xsl:param  name="item" />
     <xsl:variable name="meta" select="@meta"/>
     <xsl:choose>     
       <xsl:when test="count($source/Metadata[@name=$meta]) >0">
          <datafield xmlns="http://www.loc.gov/MARC21/slim">
             <xsl:apply-templates select="../@*" mode="mapping-attribute">
               <xsl:with-param name="source" select="$source"/>
                <xsl:with-param name="item" select="$item"/>
             </xsl:apply-templates>                                      
             <xsl:apply-templates select="../subfield[not(@nonfiling)]" >                       
               <xsl:with-param name="pos" select="$pos"/> 
               <xsl:with-param name="source" select="$source"/>
             </xsl:apply-templates>   
         </datafield>
       </xsl:when>
       <xsl:otherwise>
             <xsl:apply-templates select="following-sibling::*[1]" mode="testing" >
                    <xsl:with-param name="pos" select="$pos"/> 
            	    <xsl:with-param name="source" select="$source"/>
                    <xsl:with-param name="item" select="$item"/>
             </xsl:apply-templates> 
         </xsl:otherwise>
      </xsl:choose>       
  </xsl:template>
  

  <xsl:template match="@*" mode="mapping-attribute" >
     <xsl:param name="source" />
     <xsl:param name="item" /> 	
     <xsl:variable name="name" select="name()"/>
     <xsl:variable name="value" select="."/>
     <xsl:choose> 
     <xsl:when test="starts-with($name,'ind') and $value='nonfiling'">
         <xsl:variable name="meta" select="../subfield[@nonfiling='true']/@meta"/>
         <xsl:variable name="content" select="$source/Metadata[@name=$meta]/text()"/>  
         <xsl:apply-templates select="$item[1]" mode="mapping-item">
             <xsl:with-param name='name' select="$name"/>
             <xsl:with-param name='content' select="$content"/>
             <xsl:with-param name='subfield' select="../subfield[@nonfiling='true']"/>
	     <xsl:with-param name='source' select="$source"/>
         </xsl:apply-templates>     
      </xsl:when>
      <xsl:otherwise>      
        <xsl:if test="starts-with($name,'ind') or starts-with($name,'tag') ">
          <xsl:call-template name="addAttribute" >
             <xsl:with-param name='name' select="$name"/>
             <xsl:with-param name='value' select="$value"/>         
          </xsl:call-template>    
        </xsl:if>
      </xsl:otherwise>   
    </xsl:choose> 
 </xsl:template>

  
 <xsl:template match="item" mode="mapping-item">
     <xsl:param name="name" />
     <xsl:param name="content" />
     <xsl:param name="subfield" />
     <xsl:param name="source" />

  <xsl:variable name="itemname" select="@name"/>
  <xsl:variable name="lowercasecontent" select="xsltutil:toLowerCase($content)"/>		
      <xsl:choose>     
           <xsl:when test="starts-with($lowercasecontent,$itemname) or count(following-sibling::*)=0">
               <xsl:choose>
                 <xsl:when test="starts-with($lowercasecontent,$itemname)" >              
                      <xsl:call-template name="addAttribute" >
                         <xsl:with-param name="name" select="$name"/>
                         <xsl:with-param name="value" select="@length"/>         
                      </xsl:call-template>          
                      <xsl:apply-templates select="$subfield" >
                         <xsl:with-param name="length" select="@length" />
                         <xsl:with-param name="content" select="$content" />
	                 <xsl:with-param name="source" select="$source" />                  
                      </xsl:apply-templates>
                 </xsl:when>                                      
                 <xsl:otherwise>
                      <xsl:call-template name="addAttribute" >
                          <xsl:with-param name="name" select="$name"/>
                          <xsl:with-param name="value" select="'0'"/>         
                      </xsl:call-template>          
                      <xsl:apply-templates select="$subfield" >
                          <xsl:with-param name="length" select="'0'" />
                          <xsl:with-param name="content" select="$content" />
                          <xsl:with-param name="source" select="$source" />                   
                      </xsl:apply-templates>  
                 </xsl:otherwise>               
               </xsl:choose> 
           </xsl:when>
         <xsl:otherwise>
             <xsl:apply-templates select="following-sibling::*[1]" mode="mapping-item" >
                <xsl:with-param name="name" select="$name" />
                <xsl:with-param name="content" select="$content" />
                <xsl:with-param name="subfield" select="$subfield" />
	        <xsl:with-param name="source" select="$source" />     
             </xsl:apply-templates>
         </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  
  <xsl:template name="addAttribute">
      <xsl:param name="value" />
      <xsl:param name="name" />
      <xsl:attribute name="{$name}"><xsl:value-of select="$value"/></xsl:attribute>
  </xsl:template>

 

  <xsl:template match="subfield">
     <xsl:param name="length" />
     <xsl:param name="content" />
     <xsl:param name="pos" />         
     <xsl:param name="source" />
     <xsl:variable name="meta" select="@meta" />
     <xsl:variable name="punc" select="@punc" /> 
     <xsl:if test="$source/Metadata[@name=$meta]">
      <xsl:choose>
        <xsl:when test="@nonfiling='true'">
          <subfield code="{@code}" xmlns="http://www.loc.gov/MARC21/slim"><xsl:value-of select="$content"/><xsl:value-of select="@punc"/></subfield>
        </xsl:when>
        <xsl:when test="$pos >0">
           <subfield code="{@code}" xmlns="http://www.loc.gov/MARC21/slim">
                <xsl:value-of select="$source/Metadata[@name=$meta][$pos]"/><xsl:value-of select="$punc"/>
           </subfield>
        </xsl:when>
        <xsl:otherwise>
           <subfield code="{@code}" xmlns="http://www.loc.gov/MARC21/slim">
                <xsl:value-of select="$source/Metadata[@name=$meta]"/><xsl:value-of select="$punc"/>
           </subfield> 
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>         
  </xsl:template>
  
</xsl:stylesheet>
