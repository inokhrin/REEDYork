<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:eats="http://eats.artefact.org.nz/ns/eatsml/"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:f="urn:reed:functions"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="tei eats map f xs"
  expand-text="yes">

  <xsl:include href="render.xsl"/>

  <xsl:output method="xml" indent="yes"/>

  <xsl:param name="taxonomy-uri" as="xs:string" select="'../taxonomy.xml'"/>
  <xsl:param name="entities-uri" as="xs:string" select="'../entities 2025 06 16.xml'"/>
  <xsl:param name="output-dir" as="xs:string" select="'../site'"/>
  <xsl:param name="strict" as="xs:boolean" select="true()"/>

  <xsl:variable name="taxonomy-doc" as="document-node()" select="doc(resolve-uri($taxonomy-uri, static-base-uri()))"/>
  <xsl:variable name="entities-doc" as="document-node()" select="doc(resolve-uri($entities-uri, static-base-uri()))"/>
  <xsl:variable name="records" as="element(tei:text)*" select="/tei:TEI/tei:text/tei:group/tei:text[@type='record']"/>
  <xsl:variable name="taxonomy-entries" as="element(tei:msDesc)*" select="$taxonomy-doc//tei:msDesc[@xml:id]"/>

  <xsl:variable name="taxonomy-duplicates" as="xs:string*"
    select="for $id in distinct-values($taxonomy-entries/@xml:id)
            return if (count($taxonomy-entries[@xml:id = $id]) gt 1) then $id else ()"/>

  <xsl:variable name="taxonomy-codes-used" as="xs:string*"
    select="distinct-values(
      for $record in $records
      return
        let $ana := string(($record/tei:body/tei:head/tei:seg/@ana)[1]),
            $code := f:taxonomy-code($ana)
        return if (exists($code)) then $code else ()
    )"/>

  <xsl:variable name="taxonomy-missing" as="xs:string*"
    select="for $code in $taxonomy-codes-used
            return if (empty($taxonomy-entries[@xml:id = $code])) then $code else ()"/>

  <xsl:variable name="bad-taxonomy-ana" as="element(tei:text)*"
    select="$records[
      tei:body/tei:head/tei:seg
      and not(matches(normalize-space(string((tei:body/tei:head/tei:seg/@ana)[1])), '^taxon:[A-Za-z0-9._-]+$'))
    ]"/>

  <xsl:variable name="entity-type-index" as="map(xs:string, xs:string)">
    <xsl:map>
      <xsl:for-each select="$entities-doc/eats:collection/eats:entity_types/eats:entity_type">
        <xsl:map-entry key="string(@xml:id)" select="normalize-space(string(eats:name))"/>
      </xsl:for-each>
    </xsl:map>
  </xsl:variable>

  <xsl:variable name="entity-relationship-type-index" as="map(xs:string, xs:string)">
    <xsl:map>
      <xsl:for-each select="$entities-doc/eats:collection/eats:entity_relationship_types/eats:entity_relationship_type">
        <xsl:map-entry key="string(@xml:id)" select="normalize-space(string(eats:name))"/>
      </xsl:for-each>
    </xsl:map>
  </xsl:variable>

  <xsl:variable name="entity-relationship-type-reverse-index" as="map(xs:string, xs:string)">
    <xsl:map>
      <xsl:for-each select="$entities-doc/eats:collection/eats:entity_relationship_types/eats:entity_relationship_type">
        <xsl:map-entry key="string(@xml:id)" select="normalize-space(string((eats:reverse_name, eats:name)[1]))"/>
      </xsl:for-each>
    </xsl:map>
  </xsl:variable>

  <xsl:variable name="unresolved-entity-refs" as="xs:string*"
    select="distinct-values(
      for $ref in $records//tei:rs/@ref ! string(.)
      return
        let $id := f:eats-id($ref)
        return if (empty($id) or empty($entities-doc//eats:entity[@eats_id = $id])) then $ref else ()
    )"/>

  <xsl:variable name="all-entity-ids" as="xs:string*"
    select="distinct-values(
      for $rs in $records//tei:rs[@ref]
      return
        let $id := f:eats-id(string($rs/@ref))
        return if (exists($id) and exists($entities-doc//eats:entity[@eats_id = $id])) then $id else ()
    )"/>

  <xsl:function name="f:output-base" as="xs:anyURI">
    <xsl:sequence select="
      if (ends-with($output-dir, '/'))
      then resolve-uri($output-dir, static-base-uri())
      else resolve-uri(concat($output-dir, '/'), static-base-uri())
    "/>
  </xsl:function>

  <xsl:function name="f:out" as="xs:anyURI">
    <xsl:param name="relative-path" as="xs:string"/>
    <xsl:sequence select="resolve-uri($relative-path, f:output-base())"/>
  </xsl:function>

  <xsl:function name="f:eats-id" as="xs:string?">
    <xsl:param name="raw-ref" as="xs:string?"/>
    <xsl:variable name="ref" select="normalize-space($raw-ref)" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="matches($ref, '^eats:\d+$')">
        <xsl:sequence select="substring-after($ref, 'eats:')"/>
      </xsl:when>
      <xsl:when test="matches($ref, '^\d+$')">
        <xsl:sequence select="$ref"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:taxonomy-code" as="xs:string?">
    <xsl:param name="ana" as="xs:string?"/>
    <xsl:variable name="trimmed" select="normalize-space($ana)" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="matches($trimmed, '^taxon:[A-Za-z0-9._-]+$')">
        <xsl:sequence select="substring-after($trimmed, 'taxon:')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:record-date-key" as="xs:string">
    <xsl:param name="record" as="element(tei:text)"/>
    <xsl:variable name="date" select="($record/tei:body/tei:head/tei:date)[1]" as="element(tei:date)?"/>
    <xsl:sequence select="
      if (exists($date/@when-iso)) then string($date/@when-iso)
      else if (exists($date/@from-iso)) then string($date/@from-iso)
      else if (normalize-space(string($date)) != '') then normalize-space(string($date))
      else '9999'
    "/>
  </xsl:function>

  <xsl:function name="f:entity-name" as="xs:string">
    <xsl:param name="entity" as="element(eats:entity)?"/>
    <xsl:variable name="preferred" select="($entity/eats:names/eats:name[@is_preferred = 'true'], $entity/eats:names/eats:name)[1]" as="element(eats:name)?"/>
    <xsl:variable name="candidate" as="xs:string" select="normalize-space(string((
      $preferred/eats:display_form[normalize-space(.) != ''],
      $preferred/eats:assembled_form[normalize-space(.) != '']
    )[1]))"/>
    <xsl:sequence select="if ($candidate != '') then $candidate else concat('Entity ', string($entity/@eats_id))"/>
  </xsl:function>

  <xsl:function name="f:record-year-label" as="xs:string">
    <xsl:param name="record" as="element(tei:text)"/>
    <xsl:variable name="date" select="($record/tei:body/tei:head/tei:date)[1]" as="element(tei:date)?"/>
    <xsl:variable name="raw" select="string(($date/@when-iso, $date/@from-iso, normalize-space(string($date)))[1])" as="xs:string"/>
    <xsl:sequence select="if (matches($raw, '\d{4}')) then replace($raw, '^.*?(\d{4}).*$', '$1') else 'undated'"/>
  </xsl:function>

  <xsl:function name="f:repository-label" as="xs:string?">
    <xsl:param name="taxon" as="element(tei:msDesc)?"/>
    <xsl:variable name="raw" select="string(($taxon/tei:msIdentifier/tei:repository/@sameAs, $taxon/tei:msIdentifier/tei:repository)[1])"/>
    <xsl:sequence select="if (normalize-space($raw) != '') then replace(normalize-space($raw), '^#', '') else ()"/>
  </xsl:function>

  <xsl:template match="/">
    <xsl:message
      select="concat('[REEDYork:XSL] Build started. records=', count($records), ', entities=', count($all-entity-ids), ', strict=', $strict, '. output-dir=', string(f:output-base()))"/>

    <xsl:message select="'[REEDYork:XSL] Writing QA report: reports/qa.xml'"/>
    <xsl:call-template name="write-qa-report"/>

    <xsl:if test="$strict and (exists($taxonomy-duplicates) or exists($taxonomy-missing))">
      <xsl:message terminate="yes"
        select="concat(
          'Build halted: taxonomy validation failed. Duplicates=',
          count($taxonomy-duplicates),
          ', Missing codes=',
          count($taxonomy-missing),
          '. See site/reports/qa.xml.'
        )"/>
    </xsl:if>

      <xsl:message select="'[REEDYork:XSL] Writing index page: index.html'"/>
    <xsl:call-template name="write-index-page"/>
      <xsl:message select="concat('[REEDYork:XSL] Writing record pages: ', count($records))"/>
    <xsl:call-template name="write-record-pages"/>
      <xsl:message select="concat('[REEDYork:XSL] Writing entity pages: ', count($all-entity-ids))"/>
    <xsl:call-template name="write-entity-pages"/>

      <xsl:message select="'[REEDYork:XSL] Build complete.'"/>

    <build summary="ok" records="{count($records)}" entities="{count($all-entity-ids)}"/>
  </xsl:template>

  <xsl:template name="write-qa-report">
    <xsl:result-document href="{f:out('reports/qa.xml')}" method="xml" indent="yes">
      <qa-report>
        <summary records="{count($records)}" taxonomy-duplicates="{count($taxonomy-duplicates)}" taxonomy-missing="{count($taxonomy-missing)}" bad-taxonomy-ana="{count($bad-taxonomy-ana)}" unresolved-entity-refs="{count($unresolved-entity-refs)}"/>
        <taxonomy-duplicates>
          <xsl:for-each select="$taxonomy-duplicates">
            <duplicate code="{.}"/>
          </xsl:for-each>
        </taxonomy-duplicates>
        <taxonomy-missing>
          <xsl:for-each select="$taxonomy-missing">
            <missing code="{.}"/>
          </xsl:for-each>
        </taxonomy-missing>
        <bad-taxonomy-ana>
          <xsl:for-each select="$bad-taxonomy-ana">
            <record xml-id="{@xml:id}" ana="{string((tei:body/tei:head/tei:seg/@ana)[1])}"/>
          </xsl:for-each>
        </bad-taxonomy-ana>
        <unresolved-entity-refs>
          <xsl:for-each select="$unresolved-entity-refs">
            <ref value="{.}"/>
          </xsl:for-each>
        </unresolved-entity-refs>
      </qa-report>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="write-index-page">
    <xsl:result-document href="{f:out('index.html')}" method="html" html-version="5" indent="yes">
      <html lang="en">
        <head>
          <meta charset="utf-8"/>
          <title>REED York Records</title>
          <link rel="stylesheet" href="assets/style.css"/>
        </head>
        <body>
          <div class="container">
            <h1>REED York Records</h1>
            <p class="small">Generated from TEI records in yorkc.xml.</p>
            <ul class="record-list">
              <xsl:for-each select="$records">
                <xsl:sort select="f:record-date-key(.)"/>
                <xsl:variable name="record-id" select="string(@xml:id)"/>
                <xsl:variable name="head" select="tei:body/tei:head[1]" as="element(tei:head)?"/>
                <xsl:variable name="places" select="string-join($head/tei:rs ! normalize-space(string(.)), ', ')"/>
                <xsl:variable name="date-label" select="normalize-space(string(($head/tei:date)[1]))"/>
                <xsl:variable name="year-label" select="f:record-year-label(.)"/>
                <xsl:variable name="code" select="f:taxonomy-code(string(($head/tei:seg/@ana)[1]))" as="xs:string?"/>
                <xsl:variable name="taxon" select="($taxonomy-entries[@xml:id = $code])[1]" as="element(tei:msDesc)?"/>
                <xsl:variable name="taxon-name" select="normalize-space(string(($taxon/tei:msIdentifier/tei:msName)[1]))"/>
                <li>
                  <div class="record-title"><a href="records/{$record-id}.html">{if ($taxon-name != '') then concat($taxon-name, ' — ', $year-label) else concat($record-id, ' — ', $year-label)}</a></div>
                  <div class="record-id small">{$record-id}</div>
                  <div class="meta">
                    <xsl:if test="$places != ''">{$places}</xsl:if>
                    <xsl:if test="$date-label != ''">
                      <xsl:text> — </xsl:text>{$date-label}
                    </xsl:if>
                  </div>
                  <xsl:if test="exists($code)">
                    <div>
                      <span class="badge">{$code}</span>
                      <xsl:if test="$taxon-name != ''">
                        <span>{$taxon-name}</span>
                      </xsl:if>
                    </div>
                  </xsl:if>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </body>
      </html>
    </xsl:result-document>
  </xsl:template>

  <xsl:template name="write-record-pages">
    <xsl:for-each select="$records">
      <xsl:variable name="record" select="." as="element(tei:text)"/>
      <xsl:variable name="record-id" select="string(@xml:id)"/>
      <xsl:variable name="head" select="tei:body/tei:head[1]" as="element(tei:head)?"/>
      <xsl:variable name="code" select="f:taxonomy-code(string(($head/tei:seg/@ana)[1]))" as="xs:string?"/>
      <xsl:variable name="taxon" select="($taxonomy-entries[@xml:id = $code])[1]" as="element(tei:msDesc)?"/>
      <xsl:variable name="taxon-name" select="normalize-space(string(($taxon/tei:msIdentifier/tei:msName)[1]))"/>
      <xsl:variable name="taxon-eddesc" select="normalize-space(string(($taxon/tei:ab[@type='edDesc'])[1]))"/>
      <xsl:variable name="taxon-techdesc" select="normalize-space(string(($taxon/tei:ab[@type='techDesc'])[1]))"/>
      <xsl:variable name="taxon-shelfmark" select="normalize-space(string(($taxon/tei:msIdentifier/tei:idno[@type = 'shelfmark'])[1]))"/>
      <xsl:variable name="taxon-settlement" select="normalize-space(string(($taxon/tei:msIdentifier/tei:settlement)[1]))"/>
      <xsl:variable name="taxon-repository" select="f:repository-label($taxon)"/>
      <xsl:variable name="places" select="string-join($head/tei:rs ! normalize-space(string(.)), ', ')"/>
      <xsl:variable name="date-label" select="normalize-space(string(($head/tei:date)[1]))"/>
      <xsl:variable name="year-label" select="f:record-year-label($record)"/>
      <xsl:variable name="footnotes" select="$record//tei:note[@type = 'foot']" as="element(tei:note)*"/>
      <xsl:variable name="marginalia" select="$record//tei:note[@type = 'marginal']" as="element(tei:note)*"/>
      <xsl:variable name="endnotes" select="$record/tei:body/tei:div[@type = 'endnote']" as="element(tei:div)*"/>
      <xsl:variable name="entity-ids" as="xs:string*"
        select="distinct-values(
          for $rs in $record//tei:rs[@ref]
          return
            let $id := f:eats-id(string($rs/@ref))
            return if (exists($id) and exists($entities-doc//eats:entity[@eats_id = $id])) then $id else ()
        )"/>

      <xsl:result-document href="{f:out(concat('records/', $record-id, '.html'))}" method="html" html-version="5" indent="yes">
        <html lang="en">
          <head>
            <meta charset="utf-8"/>
            <title>{if ($taxon-name != '') then concat($taxon-name, ' — ', $year-label) else $record-id}</title>
            <link rel="stylesheet" href="../assets/style.css"/>
            <script defer="defer" src="../assets/site.js"></script>
          </head>
          <body>
            <div class="container">
              <nav class="breadcrumbs"><a href="../index.html">← Records</a></nav>
              <h1>{if ($taxon-name != '') then concat($taxon-name, ' — ', $year-label) else $record-id}</h1>
              <p class="small">{$record-id}</p>
              <div class="meta">
                <xsl:if test="$places != ''">{$places}</xsl:if>
                <xsl:if test="$date-label != ''">
                  <xsl:text> — </xsl:text>{$date-label}
                </xsl:if>
              </div>
              <xsl:if test="exists($code)">
                <details class="box">
                  <summary>Source description</summary>
                  <div><span class="badge">{$code}</span> <strong>{$taxon-name}</strong></div>
                  <div class="entity-meta">
                    <xsl:if test="$taxon-settlement != ''">
                      <div><strong>Settlement:</strong> {$taxon-settlement}</div>
                    </xsl:if>
                    <xsl:if test="exists($taxon-repository)">
                      <div><strong>Repository:</strong> {$taxon-repository}</div>
                    </xsl:if>
                    <xsl:if test="$taxon-shelfmark != ''">
                      <div><strong>Shelfmark:</strong> {$taxon-shelfmark}</div>
                    </xsl:if>
                  </div>
                  <xsl:if test="$taxon-eddesc != ''">
                    <p>{$taxon-eddesc}</p>
                  </xsl:if>
                  <xsl:if test="$taxon-techdesc != ''">
                    <p><strong>Technical description:</strong> {$taxon-techdesc}</p>
                  </xsl:if>
                </details>
              </xsl:if>

              <h2>Transcription</h2>
              <div class="content">
                <xsl:apply-templates select="$record/tei:body/tei:div[@type = 'transcription']" mode="render"/>
              </div>

              <xsl:if test="exists($record/tei:body/tei:div[@type = 'translation'])">
                <h2>Translation</h2>
                <div class="content">
                  <xsl:apply-templates select="$record/tei:body/tei:div[@type = 'translation']" mode="render"/>
                </div>
              </xsl:if>

              <xsl:if test="exists($entity-ids)">
                <details class="box">
                  <summary>Entities ({count($entity-ids)})</summary>
                  <ul>
                    <xsl:for-each select="$entity-ids">
                      <xsl:sort select="number(.)" data-type="number"/>
                      <xsl:variable name="entity" select="($entities-doc//eats:entity[@eats_id = current()])[1]" as="element(eats:entity)?"/>
                      <li><a href="../entities/{.}.html">{f:entity-name($entity)}</a> <span class="small">(eats:{.})</span></li>
                    </xsl:for-each>
                  </ul>
                </details>
              </xsl:if>

              <xsl:if test="exists($marginalia)">
                <details class="box notes-panel">
                  <summary>Marginalia ({count($marginalia)})</summary>
                  <ol class="note-list">
                    <xsl:for-each select="$marginalia">
                      <li id="marginal-{position()}"><xsl:apply-templates select="node()" mode="render"/></li>
                    </xsl:for-each>
                  </ol>
                </details>
              </xsl:if>

              <xsl:if test="exists($footnotes)">
                <details class="box notes-panel">
                  <summary>Footnotes ({count($footnotes)})</summary>
                  <ol class="note-list">
                    <xsl:for-each select="$footnotes">
                      <li id="footnote-{position()}"><xsl:apply-templates select="node()" mode="render"/></li>
                    </xsl:for-each>
                  </ol>
                </details>
              </xsl:if>

              <xsl:if test="exists($endnotes)">
                <details class="box notes-panel">
                  <summary>Endnotes ({count($endnotes)})</summary>
                  <div class="content">
                    <xsl:apply-templates select="$endnotes" mode="render"/>
                  </div>
                </details>
              </xsl:if>
            </div>
          </body>
        </html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="write-entity-pages">
    <xsl:variable name="entity-ids" as="xs:string*" select="$all-entity-ids"/>

    <xsl:for-each select="$entity-ids">
      <xsl:sort select="number(.)" data-type="number"/>
      <xsl:variable name="entity-id" select="." as="xs:string"/>
      <xsl:variable name="entity" select="($entities-doc//eats:entity[@eats_id = $entity-id])[1]" as="element(eats:entity)?"/>
      <xsl:variable name="name" select="f:entity-name($entity)"/>
      <xsl:variable name="record-refs" as="element(tei:text)*"
        select="$records[.//tei:rs[@ref][f:eats-id(string(@ref)) = $entity-id]]"/>
      <xsl:variable name="types" as="xs:string*"
        select="for $type-id in $entity/eats:entity_types/eats:entity_type/@entity_type ! string(.)
                return map:get($entity-type-index, $type-id)"/>
      <xsl:variable name="date-labels" as="xs:string*"
        select="$entity/eats:existences/eats:existence/eats:dates/eats:date/eats:assembled_form ! normalize-space(string(.))[. != '']"/>
      <xsl:variable name="relationships" select="$entity/eats:entity_relationships/eats:entity_relationship" as="element(eats:entity_relationship)*"/>

      <xsl:result-document href="{f:out(concat('entities/', $entity-id, '.html'))}" method="html" html-version="5" indent="yes">
        <html lang="en">
          <head>
            <meta charset="utf-8"/>
            <title>{$name}</title>
            <link rel="stylesheet" href="../assets/style.css"/>
            <script defer="defer" src="../assets/site.js"></script>
          </head>
          <body>
            <div class="container">
              <nav class="breadcrumbs"><a href="../index.html">← Records</a></nav>
              <h1>{$name}</h1>
              <p class="meta">eats:{$entity-id}</p>

              <div class="box entity-meta">
                <xsl:if test="exists($types[normalize-space(.) != ''])">
                  <div><strong>Types:</strong> <xsl:value-of select="string-join($types[normalize-space(.) != ''], ', ')"/></div>
                </xsl:if>
                <xsl:if test="exists($date-labels)">
                  <div><strong>Dates:</strong> <xsl:value-of select="string-join($date-labels, '; ')"/></div>
                </xsl:if>
                <xsl:if test="normalize-space($entity-id) != ''">
                  <div><strong>eREED URL:</strong> <a href="{concat('https://ereed.org/entities/', $entity-id, '/')}">{concat('https://ereed.org/entities/', $entity-id, '/')}</a></div>
                </xsl:if>
              </div>

              <xsl:if test="exists($entity/eats:names/eats:name[position() gt 1])">
                <h2>Alternate names</h2>
                <ul>
                  <xsl:for-each select="$entity/eats:names/eats:name[position() gt 1]">
                    <xsl:variable name="alt" select="normalize-space(string((eats:display_form[normalize-space(.) != ''], eats:assembled_form[normalize-space(.) != ''])[1]))"/>
                    <xsl:if test="$alt != ''">
                      <li>{$alt}</li>
                    </xsl:if>
                  </xsl:for-each>
                </ul>
              </xsl:if>

              <xsl:if test="exists($entity/eats:notes/eats:note)">
                <h2>Notes</h2>
                <div class="box">
                  <xsl:for-each select="$entity/eats:notes/eats:note">
                    <p><xsl:value-of select="normalize-space(.)"/></p>
                  </xsl:for-each>
                </div>
              </xsl:if>

              <xsl:if test="exists($entity/eats:subject_identifiers/eats:subject_identifier)">
                <xsl:comment>Identifiers intentionally hidden</xsl:comment>
              </xsl:if>

              <xsl:if test="exists($relationships)">
                <h2>Related entities</h2>
                <table class="table">
                  <thead>
                    <tr>
                      <th>Relationship</th>
                      <th>Entity</th>
                    </tr>
                  </thead>
                  <tbody>
                    <xsl:for-each select="$relationships">
                      <xsl:variable name="is-domain" select="string(@domain_entity) = concat('entity-', $entity-id)"/>
                      <xsl:variable name="related-id" select="if ($is-domain) then substring-after(string(@range_entity), 'entity-') else substring-after(string(@domain_entity), 'entity-')"/>
                      <xsl:variable name="related-entity" select="($entities-doc//eats:entity[@eats_id = $related-id])[1]" as="element(eats:entity)?"/>
                      <xsl:variable name="relationship-label" as="xs:string"
                        select="
                          if ($is-domain)
                          then map:get($entity-relationship-type-index, string(@entity_relationship_type))
                          else map:get($entity-relationship-type-reverse-index, string(@entity_relationship_type))
                        "/>
                      <tr>
                        <td>{$relationship-label}</td>
                        <td>
                          <xsl:choose>
                            <xsl:when test="exists($related-entity)">
                              <a href="../entities/{$related-id}.html">{f:entity-name($related-entity)}</a>
                              <span class="small"> (eats:{$related-id})</span>
                            </xsl:when>
                            <xsl:otherwise>
                              <span class="unresolved">Entity {$related-id}</span>
                            </xsl:otherwise>
                          </xsl:choose>
                        </td>
                      </tr>
                    </xsl:for-each>
                  </tbody>
                </table>
              </xsl:if>

              <h2>Referenced in records</h2>
              <table class="table">
                <thead>
                  <tr>
                    <th>Record</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  <xsl:for-each select="$record-refs">
                    <xsl:sort select="f:record-date-key(.)"/>
                    <xsl:variable name="rid" select="string(@xml:id)"/>
                    <tr>
                      <td><a href="../records/{$rid}.html">{$rid}</a></td>
                      <td>{normalize-space(string((tei:body/tei:head/tei:date)[1]))}</td>
                    </tr>
                  </xsl:for-each>
                </tbody>
              </table>
            </div>
          </body>
        </html>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
