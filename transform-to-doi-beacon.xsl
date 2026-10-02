<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xpath-default-namespace="http://www.w3.org/2005/xpath-functions"
  exclude-result-prefixes="xs xd"
  expand-text="true"
  version="3.0">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> May 13, 2025</xd:p>
      <xd:p><xd:b>Author:</xd:b> pd</xd:p>
      
      <xd:p>
        Generating a DOI beacon file (cf. https://gbv.github.io/beaconspec/beacon.html) containing
        information on the relation between DOI and TEI IDs/frontend slugs.
        This beacon is used for the data integration into TEI files.
        The scripted creation/modification of DOI entries relies on file-list.txt.
      </xd:p>
    </xd:desc>
  </xd:doc>
    
  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:mode on-no-match="shallow-skip"/>
  
  <xsl:param name="mode" select="'test'"/>
  
  <xsl:template match="/array">
    
    <xsl:result-document href="output/doi-beacon.txt" method="text" encoding="UTF-8">
      <xsl:text>#FORMAT: BEACON&#xA;</xsl:text>
      <xsl:text>#PREFIX: https://doi.org/&#xA;</xsl:text>
      <xsl:choose>
        <xsl:when test="matches($mode,'[pP][rR][oO][dD]')">
          <xsl:text>#TARGET: https://gotthelf-digital.ch/edition/id={ID}&#xA;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>#TARGET: https://hkg2.germ.unibe.ch/edition/id={ID}&#xA;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>#ANNOTATION: http://purl.org/dc/terms/identifier&#xA;</xsl:text>
      <xsl:text>#CONTACT: Peter Dängeli &lt;peter.daengeli@unibe.ch&gt;&#xA;</xsl:text>
      <xsl:text>#INSTITUTION: dHKG + DSL&#xA;</xsl:text>
      <xsl:text>#TIMESTAMP: {current-dateTime()}&#xA;</xsl:text>
      
      <!-- anything else?: https://de.wikipedia.org/wiki/Wikipedia:BEACON/Format -->
      
      <xsl:apply-templates select="string"/>
    </xsl:result-document>
    
  </xsl:template>
  
  <xsl:template match="string">
    <xsl:sequence select="parse-json(.)?data?attributes?doi||'|'||
      parse-json(.)?data?attributes?alternateIdentifiers?*?alternateIdentifier||'|'||
      parse-json(.)?data?attributes?url => substring-after('id=') => normalize-space()"/>
    <xsl:text>&#xA;</xsl:text>
  </xsl:template>
  
</xsl:transform>
