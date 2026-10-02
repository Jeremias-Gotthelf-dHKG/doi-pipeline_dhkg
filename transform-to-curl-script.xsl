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
        Generation of auxiliary files such as mappings and scripts.
        
        For DataCite:
        - create-dois.sh 
        - update-dois.sh
        - delete-dois.sh
        
        For eXist-db:
        - insert-doi.xq: populate one existing idno element in a TEI file
        - insert-commentary-dois.xq: create one idno element per chapter div
        
        Lists/mappings:
        - file-list.txt
        - doi-list.txt
        
        The file doi-beacon.txt that serves as an input for some of the scripts is created in a distinct step.
      </xd:p>
    </xd:desc>
  </xd:doc>
  
  <xsl:output method="text" encoding="UTF-8"/>
  
  <xsl:mode on-no-match="shallow-skip"/>
   
  <xsl:param name="auth" as="xs:string"/>
  <xsl:param name="api_url" as="xs:string"/>
  <xsl:param name="base_url" as="xs:string"/>
  <xsl:param name="publicationYear" as="xs:string"/>
  
  <xsl:template match="/array">
    
    <xsl:result-document href="output/create-dois.sh" method="text" encoding="UTF-8"><![CDATA[#!/bin/bash

# Define the endpoint and headers
API_URL="]]>{$api_url}<![CDATA["
AUTH_HEADER="authorization: ]]>{$auth}<![CDATA["
CONTENT_TYPE_HEADER="Content-Type: application/vnd.api+json"

# Loop through each file in the list
while IFS= read -r file; do
  # Check if the file exists
  if [[ -f "$file" ]]; then
    # Run the curl command
    printf "\nProcessing file: $file"
    curl -X POST -H "$CONTENT_TYPE_HEADER" --header "$AUTH_HEADER" -d @"$file" "$API_URL"
  else
    echo "File not found: $file"
  fi
done < file-list.txt]]></xsl:result-document>
    
    <xsl:result-document href="output/update-dois.sh" method="text" encoding="UTF-8"><![CDATA[#!/bin/bash

# Define the endpoint and headers
API_URL="]]>{$api_url}<![CDATA["
AUTH_HEADER="authorization: ]]>{$auth}<![CDATA["
CONTENT_TYPE_HEADER="Content-Type: application/vnd.api+json"

# Loop through each file in the list
while IFS= read -r file; do
  # Check if the file exists
  if [[ -f "$file" ]]; then
    path="${{file#_json/}}"                            # e.g., 10.83481/883c9cec.json
    path_no_ext="${{path%.json}}"                      # e.g., 10.83481/883c9cec
    url="${{API_URL}}/${{path_no_ext}}"                  # Append to API_URL
    printf "\nProcessing file: $file (PUT to $url)"
    # Run the curl command
    curl -X PUT -H "$CONTENT_TYPE_HEADER" --header "$AUTH_HEADER" -d @"$file" "$url"
  else
    echo "File not found: $file"
  fi
done < file-list.txt]]></xsl:result-document>
    
    <xsl:result-document href="output/delete-dois.sh" method="text" encoding="UTF-8"><![CDATA[#!/bin/bash

# Define the base endpoint and headers
BASE_URL="]]>{$base_url}<![CDATA["
AUTH_HEADER="authorization: ]]>{$auth}<![CDATA["
CONTENT_TYPE_HEADER="Content-Type: text/plain"
ACCEPT_HEADER="accept: application/json"
CHARSET_HEADER="charset: UTF-8"

# Loop through each DOI in the list
while IFS= read -r doi; do
  # Check if the DOI is not empty
  if [[ -n "$doi" ]]; then
    # Run the curl command
    printf "\nProcessing DOI: $doi  "
    curl --request DELETE \
         --url "$BASE_URL/$doi" \
         --header "$CONTENT_TYPE_HEADER" \
         --header "$ACCEPT_HEADER" \
         --header "$AUTH_HEADER" \
         --header "$CHARSET_HEADER"
  else
    echo "Empty DOI encountered, skipping..."
  fi
done < doi-list.txt]]></xsl:result-document>
    
    <!-- NB: The implementation of the eXist-db update facility predates the corresponding 
      XQuery specification. For this reason updating/replacing a text value needs to use fhe 
      following custom eXist syntax. See also https://exist-db.org/exist/apps/doc/update_ext -->
    <xsl:result-document href="output/insert-doi.xq" expand-text="no"><![CDATA[xquery version "3.1";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: save this file in eXist and run/evaluate it (e.g. from exide) :)
(: $lookup and $file might need adjusting :)

let $lookup := unparsed-text-lines("/db/data/playground/doi-beacon.txt")[not(starts-with(.,'#'))][not(contains(.,'_EK'))]
let $publicationYear := ']]><xsl:sequence select="$publicationYear"/><![CDATA['

for $file in collection("/db/data/playground")
let $elements := $file//tei:TEI[@xml:id]//tei:idno[@type='DOI'][@subtype='dhkg']
(: return $elements :)
for $element in $elements
let $key := $element/ancestor::tei:TEI/@xml:id/replace(.,'\.$','')
(: let $value := ($lookup[substring-after(.,'|')=$key] => substring-before('|')) :)
let $matchedLine := $lookup[tokenize(., '\|')[last()] = $key]
let $value := $matchedLine => tokenize('\|') => head()
where $value
return (
    update value $element with 'https://doi.org/' || $value,
    if ($element/@when) then
        if (matches(normalize-space(string($element/@when)), '^\d{4}$')) then
            ()
        else
            update value $element/@when with $publicationYear
    else
        update insert attribute when {$publicationYear} into $element
)
]]></xsl:result-document>
    
    <!-- for commentary files, one idno per div is created and included (referencing the div in @corresp) -->
    <xsl:result-document href="output/insert-commentary-dois.xq" expand-text="no"><![CDATA[xquery version "3.1";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare default element namespace "http://www.tei-c.org/ns/1.0";

(: save this file in eXist and run/evaluate it (e.g. from exide) :)
(: $lookup and $file might need adjusting :)

let $lookup := unparsed-text-lines("/db/data/playground/doi-beacon.txt")[not(starts-with(.,'#'))][contains(.,'_EK')]
let $publicationYear := ']]><xsl:sequence select="$publicationYear"/><![CDATA['

for $file in collection("/db/data/playground")
let $placeholder := ($file//tei:TEI[@xml:id]//tei:idno[@type='DOI'][@subtype='dhkg'][not(@corresp)][not(normalize-space(.))])[1]
where $placeholder
let $new :=
  for $line in $lookup
  let $tokens  := tokenize($line, '\|')
  let $corresp := $tokens[2]
  where exists($file//tei:div[@xml:id = $corresp])
  return
    <idno type="DOI" subtype="dhkg" when="{$publicationYear}" corresp="#{$corresp}">{'https://doi.org/' || $tokens[1]}</idno>
where exists($new)
return (
  update insert $new preceding $placeholder,
  update delete $placeholder
)
]]></xsl:result-document>
    
    <xsl:result-document href="output/file-list.txt" method="text" encoding="UTF-8">
      <xsl:apply-templates select="string"/>
    </xsl:result-document>
    
    <xsl:result-document href="output/doi-list.txt" method="text" encoding="UTF-8">
      <xsl:text/>
      <xsl:sequence select="string ! (parse-json(.)?data?attributes?doi || '&#xA;')"/>
    </xsl:result-document>
    
  </xsl:template>
  
  <xsl:template match="string">
    <xsl:text>_json/</xsl:text>
    <xsl:sequence select="parse-json(.)?data?attributes?doi => normalize-space()"/>
    <xsl:text>.json&#xA;</xsl:text>
  </xsl:template>
  
</xsl:transform>
