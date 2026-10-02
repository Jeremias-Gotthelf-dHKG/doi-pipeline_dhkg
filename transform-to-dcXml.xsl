<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:telota="http://www.telota.de"
  xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
  xpath-default-namespace="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="xs telota xd"
  expand-text="true"
  version="3.0">
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> May 5, 2025</xd:p>
      <xd:p><xd:b>Author:</xd:b> pd</xd:p>
      
      <xd:p>
        Creating the DOI metadata from TEI input.
      </xd:p>
    </xd:desc>
  </xd:doc>
  
  <xsl:mode on-no-match="shallow-skip"/>
  <xsl:mode name="title" on-no-match="shallow-copy"/>
  
  <xsl:output indent="true"/>
  
  <xsl:param name="TEI"/>
  <xsl:param name="DOI-prefix" as="xs:string"/>
  <xsl:param name="DOI" select="''"/>
  <xsl:param name="publicationYear" as="xs:string"/>
  <xsl:param name="seriesInformation" as="xs:string"/>
  
  <xsl:template match="/">
    <!-- for both edited documents and commentary the whole TEI context is passed through the template logic;
    -->
    <xsl:choose>
      <xsl:when test="/TEI">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:when test="/div">
        <xsl:apply-templates select="$TEI">
          <xsl:with-param name="chapter" select="/"/>
        </xsl:apply-templates>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="TEI">
    <xsl:param name="chapter"/>
    <xsl:variable name="commentary" as="xs:boolean" select="if ($chapter) then true() else false()"/>
    <!--<xsl:comment>
      <xsl:sequence select="@telota:doctype"/>
      <xsl:sequence select="@resourceId"/>
    </xsl:comment>-->
    <!--<xsl:variable name="resource" as="xs:string" select="'https://hkg2.germ.unibe.ch/edition/id='||@xml:id => replace('(.+?)\.?$','$1')"/>-->
    <xsl:variable name="DOI" as="xs:string">
      <xsl:choose>
        <xsl:when test="$commentary">{$DOI}</xsl:when>
        <xsl:when test="//idno[@type='DOI' and @subtype='dhkg'][matches(.,'\S')]">{//idno[@type='DOI' and @subtype='dhkg']}</xsl:when>
        <xsl:otherwise>{$DOI-prefix}/{@hash}</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="$commentary">
          <xsl:apply-templates select="//fileDesc/titleStmt/title/title" mode="title"/>
          <xsl:if test="//fileDesc/titleStmt/title/title">
            <xsl:text>: </xsl:text>
          </xsl:if>
          <xsl:if test="$chapter/div/head[matches(@n,'\S')]">
            <xsl:apply-templates select="$chapter/div/head/@n/data()" mode="title"/>
            <xsl:text>. </xsl:text>
          </xsl:if>
          <xsl:apply-templates select="$chapter/div/head" mode="title"/>
        </xsl:when>
        <xsl:when test="@telota:doctype='gotthelf_manuskript' or @telota:doctype='gotthelf_brief'">
          <xsl:apply-templates select="//msContents/msItem/title" mode="title"/>
        </xsl:when>
        <xsl:when test="@telota:doctype='gotthelf_drucktext'">
          <xsl:apply-templates select="(//biblStruct/analytic/title, //biblStruct/monogr/title)[1]" mode="title"/>
        </xsl:when>
        <xsl:otherwise>FML</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <resource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://datacite.org/schema/kernel-4" xsi:schemaLocation="http://datacite.org/schema/kernel-4 https://schema.datacite.org/meta/kernel-4/metadata.xsd">
      <identifier identifierType="DOI">{$DOI}</identifier>
        <creators>
          <xsl:if test="$commentary">
            <creator>
              <creatorName nameType="Personal">{//fileDesc/titleStmt/author[@type='introduction']}</creatorName>
            </creator>
          </xsl:if>
          
          <xsl:for-each select="//respStmt[matches(resp,'Herausgeber(in)?\sdHKG')]">
            <creator>
              <creatorName nameType="Personal">{name/forename} {name/surname}</creatorName>
              
              <xsl:choose>
                <xsl:when test="name[contains(@ref,'0000-0002-5186-4445')]">
                  <givenName>Christian von</givenName>
                  <familyName>Zimmermann</familyName>
                </xsl:when>
                <xsl:otherwise>
                  <givenName>{name/forename}</givenName>
                  <familyName>{name/surname}</familyName>
                </xsl:otherwise>
              </xsl:choose>
              <!--<nameIdentifier nameIdentifierScheme="ORCID" schemeURI="https://orcid.org">https://orcid.org/0000-9999-0000-1111</nameIdentifier>-->
            </creator>
          </xsl:for-each>
        </creators>
        <titles>
            <title>{$title => normalize-space()}</title>
        </titles>
        <publisher>{//addrLine[matches(.,'Forschungsstelle(.|\s)+Gotthelf')]=>normalize-space()} (dHKG)</publisher>
        <publicationYear>{$publicationYear}</publicationYear>
        <rightsList>
          <rights xml:lang="en" schemeURI="https://spdx.org/licenses/" rightsIdentifierScheme="SPDX" rightsIdentifier="{//availability/licence/text() => substring-before(';') => replace('\s','-')}" rightsURI="{//availability/licence/@target}">{//availability/licence/text()}</rights>
        </rightsList>
        <descriptions>
          <description descriptionType="Other">{$seriesInformation}</description><!-- SeriesInformation has side-effects in Fabrica -->
        </descriptions>
        <resourceType resourceTypeGeneral="Text">Digital Scholarly Edition</resourceType>
    </resource>
  </xsl:template>

  <xsl:template match="title|head" mode="title">
    <xsl:apply-templates mode="title"/>
  </xsl:template>

  <xsl:template match="supplied" mode="title">
    <xsl:text>‹</xsl:text>
    <xsl:apply-templates mode="title"/>
    <xsl:text>›</xsl:text>
  </xsl:template>
  
  <xsl:template match="q" mode="title">
    <xsl:apply-templates mode="title"/>
  </xsl:template>

  <xsl:template match="hi[@rend='sup_']" mode="title">
    <xsl:text>FML sup_</xsl:text>
    <xsl:apply-templates mode="title"/>
    <xsl:text>FML sup_</xsl:text>
  </xsl:template>
  <xsl:template match="text()" mode="title">{. => replace('\s+',' ')}</xsl:template>
  
</xsl:transform>
