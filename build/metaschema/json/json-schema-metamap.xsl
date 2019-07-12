<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    version="3.0" xmlns="http://www.w3.org/2005/xpath-functions"
    xpath-default-namespace="http://csrc.nist.gov/ns/oscal/metaschema/1.0" expand-text="true">

<!-- Purpose: Produce an XPath-JSON document representing JSON Schema declarations from Metaschema source data.
     The results are conformant to the rules for the XPath 3.1 definition of an XML format capable of being cast
     (using the xml-to-json() function) into JSON. -->
    
<!-- Note: this XSLT will only be used on its own for development and debugging.
     It is however imported by `produce-json-converter.xsl` and possibly other stylesheets. -->
    
    <xsl:strip-space elements="METASCHEMA define-assembly define-field model"/>
    
    <xsl:output indent="yes" method="xml"/>
    
    <xsl:template match="/" priority="2">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:variable name="home" select="/"/>
    
    <xsl:variable name="root-name" select="/METASCHEMA/@root/string(.)"/>
    
    <xsl:variable name="string-value-label">STRVALUE</xsl:variable>
    <xsl:variable name="markdown-value-label">RICHTEXT</xsl:variable>
    <xsl:variable name="markdown-multiline-label">PROSE</xsl:variable>
    
    <xsl:key name="definition-by-name" match="define-flag | define-field | define-assembly"
        use="@name"/>

    <!-- Produces composed metaschema (imports resolved) -->
    <xsl:import href="../lib/metaschema-compose.xsl"/>
    
    <xsl:template match="/METASCHEMA" expand-text="true">
        <map>
            <string key="$schema">http://json-schema.org/draft-07/schema#</string>
            <string key="$id">http://csrc.nist.gov/ns/oscal/{ $composed-metaschema/METASCHEMA/schema-version }/{ short-name }-schema.json</string>
            <xsl:for-each select="schema-name">
              <string key="$comment">{ . }: JSON Schema</string>
            </xsl:for-each>
            
            <xsl:apply-templates select="schema-version"/>
            <string key="type">object</string>
            <map key="definitions">
                <xsl:apply-templates select="$composed-metaschema/METASCHEMA/*"/>

                <!--<map key="prose">
                    <xsl:call-template name="string-or-array-of-strings"/>
                </map>-->
            </map>           
        <map key="properties">
            <!--<xsl:apply-templates mode="properties"/>-->
            <map key="{@root}">
                <string key="$ref">#/definitions/{ @root }</string>
            </map>
        </map>
        <!--<map key="propertyNames">
                <array key="enum">
                    <string>
                        <xsl:apply-templates mode="property-names"/></string>
                </array>
            </map>-->
        </map>
    </xsl:template>
    
    <!--<xsl:template name="string-or-array-of-strings">
        <array key="anyOf">
            <map>
                <string key="type">string</string>
            </map>
            <map>
                <string key="type">array</string>
                <map key="items">
                    <string key="type">string</string>
                </map>
            </map>
        </array>
    </xsl:template>-->

    <xsl:template match="METASCHEMA/schema-name | METASCHEMA/short-name | METASCHEMA/remarks | METASCHEMA/namespace | METASCHEMA/schema-version"/>
  
    <!-- Flag declarations are all handled at the point of invocation -->
    <xsl:template match="define-flag"/>
    
    <xsl:template match="define-assembly | define-field">
        <map key="{ @name }">
            <xsl:apply-templates select="formal-name, description"/>
            <string key="$id">#/definitions/{@name}</string>
            <string key="type">object</string>
            <xsl:variable name="properties" as="element()*">
                <xsl:apply-templates select="." mode="properties"/>
            </xsl:variable>
            <xsl:if test="exists($properties)">
            <map key="properties">
                <xsl:apply-templates select="." mode="properties"/>
            </map>
            </xsl:if>
            <xsl:call-template name="required-properties"/>
            <xsl:choose>
                <xsl:when test="exists(json-value-key)">
                    <xsl:variable name="value-key-name" select="json-value-key/@flag-name"/>
                    <xsl:variable name="all-properties"
                        select="flag[not(@name = $value-key-name)] | model//(field | assembly)"/>
                    <number key="minProperties">
                        <xsl:value-of select="count($all-properties[@required='yes' or @min-occurs &gt; 0] | self::define-field[not(@as='empty')])"/>
                    </number>
                    <number key="maxProperties">
                        <xsl:value-of select="count($all-properties | self::define-field[not(@as='empty')])"/>
                    </number>
                </xsl:when>
                <xsl:otherwise>
                    <boolean key="additionalProperties">false</boolean>
                </xsl:otherwise>
            </xsl:choose>
            
            <!--<map key="propertyNames">
                <array key="enum">
                    <xsl:apply-templates select="." mode="text-property"/>
                    <xsl:apply-templates select="flag, model" mode="property-name"/>
                </array>
            </map>-->
        </map>
    </xsl:template>
    
    <xsl:template name="required-properties">
        <xsl:variable name="value-string" as="element()?">
            <xsl:for-each select="self::define-field[not(@as-type='empty') and not( matches(json-value-key/@flag-name,'\S') )]">
                <string>
                    <xsl:apply-templates select="." mode="value-key"/>
                </string>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="requirements" as="element()*">
            <xsl:apply-templates mode="property-name"
                select="flag[@required = 'yes'][not(@name = ../(json-key | json-value-key)/@flag-name)] |
                model//*[@min-occurs &gt; 0]"/>
        </xsl:variable> 
        <xsl:if test="exists( ($value-string, $requirements) )">
            <array key="required">
                <xsl:copy-of select="$value-string, $requirements"/>
            </array>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="*" mode="text-property"/>
    
    <xsl:template match="define-field" mode="text-property">
        <string>
          <xsl:apply-templates select="." mode="value-key"/>
        </string>
    </xsl:template>
    
    <xsl:template match="define-field" mode="value-key">
        <xsl:value-of select="$string-value-label"/>
    </xsl:template>
    
    <xsl:template match="define-field[@as-type='markup-line']" mode="value-key">
        <xsl:value-of select="$markdown-value-label"/>
    </xsl:template>
    
    <xsl:template match="define-field[@as-type='markup-multiline']" mode="value-key">
        <xsl:value-of select="$markdown-multiline-label"/>
    </xsl:template>
    
<!-- empty fields have no values, hence no value keys; by producing nothing
        this template sees to it no declaration for it is produced either. -->
    <xsl:template match="define-field[@as-type='empty']" mode="value-key"/>
        
    <xsl:template priority="2" match="define-field[matches(json-value-key,'\S')]" mode="value-key">
        <xsl:value-of select="json-value-key"/>
    </xsl:template>
    
<!-- No property is declared for a value whose key is assigned by a json-value-key   -->
    <xsl:template priority="3" match="define-field[matches(json-value-key/@flag-name,'\S')]" mode="value-key"/>
        
    <!--<xsl:template priority="3" match="define-field[exists(flag/value-key)]" mode="text-key"/>-->
    
    <xsl:template match="define-assembly[exists(json-key)] | define-field[exists(json-key)]">
        <map key="{ @name }">
            <xsl:apply-templates select="formal-name, description"/>
            <string key="$id">#/definitions/{@name}</string>
            <string key="type">object</string>
            <map key="properties">
                <xsl:apply-templates select="." mode="properties"/>
            </map>
            <xsl:call-template name="required-properties"/>
            <boolean key="additionalProperties">false</boolean>
        </map>
    </xsl:template>
    
    <xsl:template match="define-field[empty(flag)]">
        <map key="{ @name }">
            <xsl:apply-templates select="formal-name, description"/>
            <string key="$id">#/definitions/{@name}</string>
            <xsl:apply-templates select="." mode="object-type"/>
        </map>
    </xsl:template>

    <xsl:template match="define-assembly" mode="properties">
        <!-- to be excluded, flags assigned to be keys -->
        <xsl:apply-templates mode="declaration" select="flag[not((@name|@ref) = ../json-key/@flag-name)], model"/>
    </xsl:template>

    <xsl:template match="formal-name">
        <string key="title">
            <xsl:apply-templates/>
        </string>
    </xsl:template>

    <xsl:template match="description">
        <string key="description">
            <xsl:value-of select="normalize-space(.)"/>
        </string>
    </xsl:template>

    <xsl:template match="remarks | example"/>
    
    <xsl:template match="assembly | field | flag" priority="2" mode="property-name">
        <string>
            <!--<xsl:value-of select="key('definition-by-name',@ref)/(@group-as,@name)[1]"/>-->
            <xsl:value-of select="(group-as/@name,@name,@ref)[1]"/>
        </string>
    </xsl:template>
    
    <xsl:template match="flag[exists(@name)]" mode="property-name">
        <string>
            <xsl:value-of select="@name"/>
        </string>
    </xsl:template>
    
<!-- Not yet implemented -->
    <xsl:template match="any" mode="property-name"/>
    
    <xsl:template match="prose" mode="property-name">
        <string>prose</string>
    </xsl:template>
    
    <xsl:template match="model | choice" priority="2" mode="property-name">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="define-field" mode="properties">
        <xsl:apply-templates mode="declaration" select="flag"/>
        <xsl:variable name="this-key" as="xs:string?">
            <xsl:apply-templates select="." mode="value-key"/>
        </xsl:variable>
        <xsl:if test="matches($this-key, '\S')">
            <map key="{$this-key}">
                <string key="type">string</string>
                <!--                
                <xsl:call-template name="string-or-array-of-strings"/>-->
            </map>
        </xsl:if>
    </xsl:template>

    <!--A flag declared as a key or value key gets no declaration since it
    will not show up in the JSON as a separate property -->
    
    <xsl:template mode="declaration" match="flag[(@name|@ref)=../(json-value-key|json-key)/@flag-name]"/>
        
    <xsl:template mode="declaration" match="flag">
        <map key="{(@name,@ref)[1]}">
            <xsl:apply-templates select="." mode="object-type"/>
            <xsl:apply-templates select="formal-name | description"/>
            <xsl:if test="empty(formal-name | description)">
                <xsl:apply-templates select="key('definition-by-name',@ref)/(formal-name | description)"/>
            </xsl:if>
            <xsl:apply-templates select="(valid-values,key('definition-by-name',@ref)/valid-values)[1]"/>    
        </map>
    </xsl:template>
    
    <!-- No restriction is introduced when allow others is 'yes' -->
    <xsl:template match="valid-values[@allow-other='yes']"/>
    
    <xsl:template match="valid-values">
        <xsl:param name="datatype" as="xs:string">string</xsl:param>
        <array key="enum">
            <xsl:apply-templates/>
        </array>
    </xsl:template>
    
    <xsl:template match="valid-values/value">
        <string>
            <xsl:apply-templates select="@name"/>
        </string>
    </xsl:template>

    <!-- irrespective of min-occurs and max-occurs, assemblies and fields designated
         with key flags are represented as objects, never arrays, as the key
         flag serves as a label -->
    <xsl:template mode="declaration" priority="5"
        match="assembly[group-as/@json-behavior='BY_KEY'][exists(key('definition-by-name',@ref)/json-key)] |
        field[group-as/@json-behavior='BY_KEY'][exists(key('definition-by-name',@ref)/json-key)]">
        <xsl:variable name="group-name" select="group-as/@name"/>
        <map key="{ $group-name }">
            <string key="type">object</string>
            <number key="minProperties">1</number>
            <map key="additionalProperties">
                <array key="allOf">
                    <map>
                <string key="type">object</string>
                <string key="$ref">#/definitions/{ @ref }</string>
                    </map>
                    <map>
                        <map key="not">
                            <string key="type">string</string>
                        </map>
                    </map>
                </array>
            </map>
        </map>
    </xsl:template>
    
    <!-- Always a map when max-occurs is 1 or implicit -->
    <xsl:template mode="declaration" priority="4"
        match="assembly[empty(@max-occurs) or number(@max-occurs) = 1 ] |
        field[empty(@max-occurs) or number(@max-occurs)= 1 ]">
        <map key="{@ref}">
            <xsl:apply-templates select="key('definition-by-name', @ref)" mode="object-type"/>
            <string key="$ref">#/definitions/{ @ref }</string>
        </map>
    </xsl:template>
    
    <!-- Otherwise, always an array when min-occurs is greater than 1 or whenever so designated -->
    <xsl:template mode="declaration" priority="3" expand-text="yes"
        match="assembly[number(@min-occurs) &gt; 1 ]     | field[number(@min-occurs) &gt; 1 ] |
               assembly[group-as/@json-behavior='ARRAY'] | field[group-as/@json-behavior='ARRAY']">
        <map key="{ group-as/@name }">
            <string key="type">array</string>
            <!-- despite @min-occurs = 0, we have a minimum of 1 since the array itself is optional -->
            <number key="minItems">{ max((@min-occurs/number(),1)) }</number>
            <!-- case for @max-occurs missing or 1 has matched the template above -->
            <xsl:for-each select="@max-occurs[not(. = 'unbounded')]">
                <number key="maxItems">{ . }</number>
            </xsl:for-each>
            <map key="items">
                <string key="$ref">#/definitions/{ @ref }</string>
            </map>
        </map>
    </xsl:template>
    
    <!-- Now matching when min-occurs is 1 or less, max-occurs is more than 1,
         and group-as/@json-behavior is not 'BY-KEY' or 'ARRAY' ... -->
    <xsl:template mode="declaration" match="assembly | field">
        <map key="{ group-as/@name }">
            <array key="anyOf">
                <map>
                    <string key="type">object</string>
                    <string key="$ref">#/definitions/{ @ref }</string>
                </map>
                <map>
                    <string key="type">array</string>
                    <xsl:if test="@max-occurs != 'unbounded'">
                        <string key="maxItems">{ @max-occurs }</string>
                    </xsl:if>
                    <map key="items">
                        <string key="$ref">#/definitions/{ @ref }</string>
                    </map>
                    <number key="minItems">2</number>
                </map>
            </array>
        </map>
    </xsl:template>

   <!-- <xsl:template mode="declaration" match="prose">
        <map key="prose">
            <string key="$ref">#/definitions/prose</string>
        </map>
    </xsl:template>-->
    
    
    <!--  elements that fall through are made objects in case they have properties  -->
    <xsl:template match="*" mode="object-type">
        <string key="type">object</string>
    </xsl:template>

    <xsl:template match="define-field[empty(flag)] | define-flag | flag" mode="object-type">
        <string key="type">string</string>
    </xsl:template>
    
    <xsl:template match="field | flag" priority="3" mode="object-type">
        <xsl:choose>
            <xsl:when test="exists(@as-type)">
                <xsl:next-match/>
            </xsl:when>
            <xsl:when test="exists(key('definition-by-name',@ref)/@as-type)">
                <xsl:apply-templates mode="#current" select="key('definition-by-name',@ref)"/>
            </xsl:when>
            <xsl:otherwise>
                <string key="type">string</string> 
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- currently working on flags but not on fields with flags? -->
    <xsl:template priority="2" match="*[@as-type='boolean']" mode="object-type">
        <string key="type">boolean</string>
    </xsl:template>
    
    <xsl:template priority="2" match="*[@as-type='integer']" mode="object-type">
        <string key="type">integer</string>
        <number key="multipleOf">1.0</number>
    </xsl:template>

    <xsl:template priority="2" match="*[@as-type='positiveInteger']" mode="object-type">
        <string key="type">integer</string>
        <number key="multipleOf">1.0</number>
        <number key="minimum">1</number>
    </xsl:template>    
    
    <xsl:template priority="2" match="*[@as-type='nonNegativeInteger']" mode="object-type">
        <string key="type">integer</string>
        <number key="multipleOf">1.0</number>
        <number key="minimum">0</number>
    </xsl:template>
    
    <!-- Types are listed in ../xml/produce-xsd.xsl and ../xml/oscal-datatypes.xsd -->
    
    <xsl:variable name="numeric-types" as="element()*">
        <type>decimal</type>
        <type>float</type>
        <type>double</type>
    </xsl:variable>
    
    <xsl:template priority="2" match="*[@as-type=$numeric-types]" mode="object-type">
        <string key="type">number</string>
    </xsl:template>
    
    <xsl:template priority="2.1" match="*[@as-type = $datatypes/*/@key]" mode="object-type">
        <xsl:copy-of select="key('datatypes-by-name',@as-type,$datatypes)/*"/>
    </xsl:template>
    
    <xsl:key name="datatypes-by-name" xpath-default-namespace="http://www.w3.org/2005/xpath-functions"
        match="map" use="@key"/>
    
    <xsl:variable name="datatypes" expand-text="false">
        <map key="date-with-timezone">
            <string key="type">string</string>
            <string key="format">date</string>
            <!--The xs:date with a required timezone.-->
            <!--<string key="pattern">.+[:Z].*</string>-->
        </map>
        <map key="dateTime-with-timezone">
            <string key="type">string</string>
            <string key="format">date-time</string>
            <!--The xs:dateTime with a required timezone.-->
            <string key="pattern">.+T.+(Z|[+-].+)</string>
        </map>
        <map key="email">
            <string key="type">string</string>
            <string key="format">email</string>
            <!---->
            <string key="pattern">.+@.+</string>
        </map>
        <map key="ip-v4-address">
            <string key="type">string</string>
            <string key="format">ipv4</string>
            <!--The ip-v4-address type specifies an IPv4 address in dot decimal notation.-->
            <string key="pattern">((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])</string>
        </map>
        <map key="ip-v6-address">
            <string key="type">string</string>
            <string key="format">ipv6</string>
            <!--The ip-v6-address type specifies an IPv6 address represented in 8 hextets separated by colons.This is based on the pattern provided here: https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses with some customizations.-->
            <string key="pattern">(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|[fF][eE]80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::([fF]{4}(:0{1,4}){0,1}:){0,1}((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3,3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]).){3,3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]))</string>
        </map>
        <map key="hostname">
            <string key="type">string</string>
            <string key="format">idn-hostname</string>
            <!---->
            <string key="pattern">.+</string>
        </map>
        <map key="uri">
            <string key="type">string</string>
            <string key="format">uri</string>
            <!---->
        </map>
        <map key="uri-reference">
            <string key="type">string</string>
            <string key="format">uri-reference</string>
            <!---->
        </map>
        <!-- Possibly add support for XSD types ID, IDREF, IDREFS, NCName, NMTOKENS ???        -->
    </xsl:variable>

</xsl:stylesheet>
