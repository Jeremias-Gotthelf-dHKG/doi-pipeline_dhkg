<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:telota="http://www.telota.de"
  name="DOI-pipeline"
  version="3.0">
  
  <p:documentation>
    Pipeline to generate DOIs and scripts for submission to the repository and integration into source data (TEI).
    
    Invoke the pipeline with a command such as 
    
    java -jar /path-to/xmlcalabash-app-3*.jar pipeline.xpl user=UNIBE.DHKG-TEST pw="**redacted**" event=publish (testing)
    java -jar /path-to/xmlcalabash-app-3*.jar pipeline.xpl user=UNIBE.DHKG pw="**redacted**" event=publish mode=prod (production)
  </p:documentation>

  <p:input port="source" href="input-data.zip">
    <p:documentation>Source document, i.e. a ZIP file containing data files.</p:documentation>
  </p:input>
  <p:output port="result" serialization="map{ 'indent': true() }"/>

  <p:option name="mode" static="true" select="'test'">
    <p:documentation>Pipeline mode. Test ("test") or production ("prod") run. Selects appropriate DOI prefix and API URL.</p:documentation>
  </p:option>
  
  <p:option name="user" required="true">
    <p:documentation>User name. Supply when invoking the pipeline ("user").</p:documentation>
  </p:option>
  <p:option name="pw" required="true">
    <p:documentation>Password. Supply when invoking the pipeline ("pw"). Escape/quote as needed depending on the shell.</p:documentation>
  </p:option>
  
  <p:option name="event" required="false" select="''">
    <p:documentation>Event (DataCite API). Omit/leave empty (defaults to "draft"), or set "register" (target status: registered), 
      "publish" (target status: findable), or "hide" (target status: registered), 
      cf. https://support.datacite.org/docs/updating-metadata-with-the-rest-api#changing-the-doi-state.</p:documentation>
  </p:option><!-- publish / hide / draft register -->
  
  <p:variable name="publicationYear" select="'2026'">
    <p:documentation>Publication year. Used for DataCite entry, but also recorded in TEI files (@when).</p:documentation>
  </p:variable>
  
  <p:variable name="seriesInformation" select="'Jeremias Gotthelf, digitale Historisch-kritische Gesamtausgabe der Werke und Briefe (dHKG)'"/>
  
  <!-- Testing -->
  <p:variable name="host" select="'https://hkg2.germ.unibe.ch/edition/id='" use-when="not(matches($mode,'[pP][rR][oO][dD]'))"/>
  <p:variable name="DOI-prefix" select="'10.83481'" use-when="not(matches($mode,'[pP][rR][oO][dD]'))"/>
  <p:option name="api_url" select="'https://api.test.datacite.org/dois'" use-when="not(matches($mode,'[pP][rR][oO][dD]'))"/>
  <p:option name="base_url" select="'https://mds.test.datacite.org/doi'" use-when="not(matches($mode,'[pP][rR][oO][dD]'))"/>
  
  <!-- Production -->
  <p:variable name="host" select="'https://gotthelf-digital.ch/edition/id='" use-when="matches($mode,'[pP][rR][oO][dD]')"/>  
  <p:variable name="DOI-prefix" select="'10.82565'" use-when="matches($mode,'[pP][rR][oO][dD]')"/>
  <p:option name="api_url" select="'https://api.datacite.org/dois'" use-when="matches($mode,'[pP][rR][oO][dD]')"/>
  <p:option name="base_url" select="'https://mds.datacite.org/doi'" use-when="matches($mode,'[pP][rR][oO][dD]')"/>
  
  <p:variable name="user_pw" select="($user,$pw) => string-join(':')"/>
  <p:variable name="rule" select="'==============================================='"/>
  <p:variable name="newline" select="'&#xA;'"/>

  <p:unarchive message="{$rule||$newline||'Getting ready.'||$newline||$rule||$newline||'Unzipping…'||$newline||$rule}" name="unzip">
    <p:with-input pipe="source"/>
    <p:with-option name="include-filter" select="('\.xml$')"/>
    <!-- drop files starting with period and Literaturverzeichnisse (LV) -->
    <p:with-option name="exclude-filter" select="'(/\.)|(_LV.*\.xml)'"/>
  </p:unarchive>

  <p:message select="{$rule||$newline}
    {if (matches($mode,'[pP][rR][oO][dD]')) 
    then 'Pipeline starting in production mode.' 
    else 'Pipeline starting in test mode.'}
    {$newline||$rule}"/>
  
  <p:wrap-sequence wrapper="wrapper">
    <p:with-input pipe="result@unzip"/>
  </p:wrap-sequence>

  <p:group name="encoding-group">
    <p:output port="encoded-result"/>
    <p:encode name="base64">
      <p:with-input>
        <p:inline content-type="text/plain">{$user_pw}</p:inline>
      </p:with-input>
    </p:encode>
  </p:group>
  
  <p:variable name="encoded-string" select="//text()" pipe="encoded-result"/>
  <p:variable name="auth" select="'Basic ' || $encoded-string"/>

  <p:for-each name="iterate-on-files" message="{$rule||$newline||'Iterating over files…'||$newline||$rule}">
    
    <p:with-input pipe="result@unzip" select="*:TEI[not(.//*:msDesc[@type='sammelhandschrift']) and not(@telota:doctype='gotthelf_kommentar')]"/>
    
    <!-- deriving the resource's URL/ID and hash it -->
    <p:variable name="resourceId" select="$host||/*:TEI/@xml:id"/>
    <p:add-attribute match="/*:TEI" attribute-name="resourceId" attribute-value="{ $resourceId }"/>
    <p:add-attribute match="/*:TEI" attribute-name="hash" attribute-value=""/>
    <p:hash algorithm="crc" version="32" value="{ $resourceId }" match="/*:TEI/@hash"/>
    
    <p:store href="output/_tei-debug/{ $resourceId }.xml" serialization="map { 'indent': true() }"/>

    <!-- extract values and create DataCite XML -->
    <p:xslt name="transform-to-dcXml">
      <p:with-input port="stylesheet" href="transform-to-dcXml.xsl"/>
      <p:with-option name="parameters" select="map { 
        'DOI-prefix': $DOI-prefix, 
        'publicationYear': $publicationYear,
        'seriesInformation': $seriesInformation}"/>
    </p:xslt>
    
    <p:variable name="doi" pipe="result@transform-to-dcXml" select="//*:identifier[@identifierType='DOI']
         => string() => normalize-space() => replace('^https?://(www\.)?doi\.org/', '')"/>
    <p:message select="{'  DOI '||$doi||'…'}"/>
    <p:store href="output/_xml/{ $doi }.xml" serialization="map { 'indent': true() }"/>
      
    <!-- validate files? -->
    <!--<p:validate-with-xml-schema>
      <p:with-input pipe="result@transform-to-dcXml"/>
      <p:with-input port="schema" href="https://schema.datacite.org/meta/kernel-4/metadata.xsd"/>
      <p:with-option name="use-location-hints" select="true()"/>
    </p:validate-with-xml-schema>-->
      
    <!-- base64 encoding -->
    <p:encode name="base64">
      <p:with-input pipe="result@transform-to-dcXml"/>
    </p:encode>
    
    <p:variable name="base64" pipe="result@base64" select="."/>
    <p:xslt name="transform-to-dcXmlJson">
      <p:with-input pipe="result@transform-to-dcXml"/>
      <p:with-input port="stylesheet" href="transform-to-dcXmlJson.xsl"/>
      <p:with-option name="parameters" select="map { 
        'doi': $doi,
        'xml': $base64,
        'altId': $resourceId,
        'url' : $resourceId  => replace('(.+?)\.?$','$1'),
        'event': $event}"/>
    </p:xslt>
    <p:store href="output/_json/{ $doi }.json" serialization="map { 'indent': true() }"/>
    
  </p:for-each>
  
  <p:for-each name="iterate-on-files-commentary" message="{$rule||$newline||'Iterating over files… (commentary)'||$newline||$rule}">
    
    <p:with-input pipe="result@unzip" select="*:TEI[@telota:doctype='gotthelf_kommentar']"/>
    <p:variable name="TEI" select="/*:TEI"/>
        
    <p:for-each name="iterate-on-chapter-divs">
      
      <!-- Other than for edited documents, DOIs for commentaries are assigned at the level of chapters. -->
      <!-- We only handle EK comments; and we exclude Materialien (sourceList) and illustrations. -->
      <p:with-input select=".//*:div[@type='chapter'][contains(@xml:id,'_EK')][not(@subtype=('sourceList','illustrations'))]"/>
      <p:variable name="chapter-id" select="/*:div/@xml:id"/>
      
      <!-- deriving the resource's URL/ID and hash it -->
      <p:variable name="resourceId" select="$host||$chapter-id"/>
      <p:add-attribute match="/*:div" attribute-name="resourceId" attribute-value="{ $resourceId }"/>
      <p:add-attribute match="/*:div" attribute-name="hash" attribute-value=""/>
      
      <p:hash algorithm="crc" version="32" value="{ $chapter-id }" match="/*:div/@hash"/>
      <p:variable name="doi" select="/*:div/@hash"/>
      
      <p:store href="output/_tei-debug/{ $resourceId }.xml" serialization="map { 'indent': true() }"/>
  
      <!-- extract values and create DataCite XML -->
      <p:xslt name="transform-to-dcXml-commentary">
        <p:with-input port="stylesheet" href="transform-to-dcXml.xsl"/>
        <p:with-option name="parameters" select="map { 
          'TEI': $TEI,
          'DOI-prefix': $DOI-prefix,
          'DOI' : $doi,
          'publicationYear': $publicationYear,
          'seriesInformation': $seriesInformation}"/>
      </p:xslt>
      <p:message select="{'  DOI '||$DOI-prefix||'/'||$doi||'…'}"/>
      <p:store href="output/_xml/{ $DOI-prefix }/{ $doi }.xml" serialization="map { 'indent': true() }"/>
      
      <!-- base64 encoding -->
      <p:encode name="base64">
        <p:with-input pipe="result@transform-to-dcXml-commentary"/>
      </p:encode>
      
      <!-- resourceId is used for the DOI beacon; for commentaries the @xml:id is not the same as the URL segment
           status 20250919: @xml:id="ERF_EK.c1" URL: https://gotthelf-digital.ch/edition/id=ERF_EK_1
           status 20261001: implemented simple heuristic; last segment to number
           status 20261002: added an annotation to DOI-beacon (second field) that carries the @xml:id of the chapter div
      -->
      <p:variable name="base64" pipe="result@base64" select="."/>
      <p:xslt name="transform-to-dcXmlJson">
        <p:with-input pipe="result@transform-to-dcXml-commentary"/>
        <p:with-input port="stylesheet" href="transform-to-dcXmlJson.xsl"/>
        <p:with-option name="parameters" select="map { 
          'doi': $DOI-prefix||'/'||$doi,
          'xml': $base64,
          'altId': $resourceId,
          (: reduce segments after '_EK' to numeric segment :)
          'url' : ($resourceId => replace('(.*_EK).*','$1'), $resourceId => replace('^(.*)?(\d+)$','$2')) => string-join('_'),
          'event': $event}"/>
      </p:xslt>
      <p:store href="output/_json/{ $DOI-prefix }/{ $doi }.json" serialization="map { 'indent': true() }"/>
      
    </p:for-each>
  </p:for-each>
  
  <p:json-join>
    <p:with-input port="source">
      <p:pipe step="iterate-on-files"/>
      <p:pipe step="iterate-on-files-commentary"/>
    </p:with-input>
  </p:json-join>
  
  <p:cast-content-type content-type="text/xml" name="datacite-response-xml"/>
  <p:store href="output/_debug/datacite-response-xml.xml" serialization="map { 'indent': true() }"/>
  
  <p:xslt name="transform-to-doi-beacon">
    <p:with-input pipe="result@datacite-response-xml"/>
    <p:with-input port="stylesheet" href="transform-to-doi-beacon.xsl"/>
    <p:with-option name="parameters" select="map {'mode' : $mode}"/>
  </p:xslt>
  <p:store href="output/doi-beacon.txt">
    <p:with-input pipe="secondary@transform-to-doi-beacon"/>
  </p:store>

  <p:xslt name="transform-to-curl-script" message="{$rule||$newline||'Generating scripts…'||$newline||$rule}">
    <p:with-input pipe="result@datacite-response-xml"/>
    <p:with-input port="stylesheet" href="transform-to-curl-script.xsl"/>
    <p:with-option name="parameters" select="map { 
      'auth': $auth,
      'api_url': $api_url,
      'base_url': $base_url,
      'publicationYear': $publicationYear}"/>
  </p:xslt>
  
  <p:for-each name="store-script" message="{$rule||$newline||'Storing scripts…'||$newline||$rule}">
    <p:with-input pipe="secondary@transform-to-curl-script"/>
    <p:store href="{base-uri(/)}"/>
  </p:for-each>
  
  <!-- make scripts executable -->
  <p:os-exec name="chmod-script" depends="store-script" command="chmod" message="{$rule||$newline||'Making scripts executable…'||$newline||$rule}">
    <p:with-option name="args" select="('+x', 'output/create-dois.sh', 'output/update-dois.sh', 'output/delete-dois.sh')"/>
    <p:with-input port="source">
      <p:empty/>
    </p:with-input>
  </p:os-exec>
  
  <!-- execute DOI creation/update; too risky -->
<!--  <p:os-exec depends="chmod-script" command="./update-dois.sh">
    <p:with-input port="source">
      <p:empty/>
    </p:with-input>
  </p:os-exec>
-->

  <p:wrap-sequence wrapper="results" message="{$rule||$newline||'Done.'||$newline||$rule}"/>
  
</p:declare-step>