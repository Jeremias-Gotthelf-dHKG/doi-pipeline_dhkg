<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform xmlns="http://www.w3.org/2005/xpath-functions"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xpath-default-namespace="http://datacite.org/schema/kernel-4"
  exclude-result-prefixes="xs xd"
  expand-text="true"
  version="3.0">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> May 6, 2025</xd:p>
      <xd:p><xd:b>Author:</xd:b> pd</xd:p>
      
      <xd:p>
        Preparing the JSON payload containing the base64-encoded DataCite XML representation of the DOI metadata.
      </xd:p>
    </xd:desc>
  </xd:doc>
  
  <xsl:output method="text" encoding="UTF-8"/>
  
  <xsl:mode name="to-json" on-no-match="shallow-skip"/>
  
  <xsl:param name="doi" as="xs:string"/>
  <xsl:param name="xml" as="xs:string"/>
  <xsl:param name="altId" as="xs:string" select="''"/>
  <xsl:param name="url" as="xs:string"/>
  <xsl:param name="event" as="xs:string"/>
  
  <xsl:template match="/">
    <xsl:variable name="payload">
      <map>
        <map key="data">
          <string key="type">dois</string>
          <map key="attributes">
            <string key="event">{$event}</string>
            <string key="doi">{$doi}</string>
            <string key="xml">{$xml}</string>
            <xsl:if test="$altId[normalize-space()]">
              <array key="alternateIdentifiers">
                <map>
                  <string key="alternateIdentifierType">Local project ID</string>
                  <string key="alternateIdentifier">{($altId => tokenize('/'))[last()] => substring-after('id=')}</string>
                </map>
              </array>
            </xsl:if>
            <string key="url">{$url => replace('/id.*','/') || ($url => tokenize('/'))[last()]}</string>
          </map>
        </map>
      </map>
    </xsl:variable>
    
    <xsl:sequence select="xml-to-json($payload)"/>
  </xsl:template>
  
</xsl:transform>