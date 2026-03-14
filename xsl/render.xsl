<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:f="urn:reed:functions"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="tei f xs">

  <xsl:template match="text()" mode="render">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="tei:div" mode="render">
    <div class="tei-div tei-div-{@type}">
      <xsl:apply-templates mode="render"/>
    </div>
  </xsl:template>

  <xsl:template match="tei:ab" mode="render">
    <p class="tei-ab">
      <xsl:apply-templates mode="render"/>
    </p>
  </xsl:template>

  <xsl:template match="tei:p" mode="render">
    <p>
      <xsl:apply-templates mode="render"/>
    </p>
  </xsl:template>

  <xsl:template match="tei:head" mode="render">
    <h3 class="tei-head">
      <xsl:apply-templates mode="render"/>
    </h3>
  </xsl:template>

  <xsl:template match="tei:pb" mode="render">
    <span class="tei-pb">[folio <xsl:value-of select="@n"/>]</span>
  </xsl:template>

  <xsl:template match="tei:lb" mode="render">
    <br/>
  </xsl:template>

  <xsl:template match="tei:hi" mode="render">
    <span class="tei-hi tei-hi-{@rend}">
      <xsl:apply-templates mode="render"/>
    </span>
  </xsl:template>

  <xsl:template match="tei:ex" mode="render">
    <span class="tei-ex">
      <xsl:apply-templates mode="render"/>
    </span>
  </xsl:template>

  <xsl:template match="tei:del" mode="render">
    <del>
      <xsl:apply-templates mode="render"/>
    </del>
  </xsl:template>

  <xsl:template match="tei:gap" mode="render">
    <span class="tei-gap">[…]</span>
  </xsl:template>

  <xsl:template match="tei:damage" mode="render">
    <span class="tei-damage">
      <xsl:apply-templates mode="render"/>
    </span>
  </xsl:template>

  <xsl:template match="tei:handShift" mode="render">
    <span class="tei-handshift">⟨hand shift⟩</span>
  </xsl:template>

  <xsl:template match="tei:note[@type = ('foot', 'marginal')]" mode="render">
    <xsl:variable name="kind" select="string(@type)" as="xs:string"/>
    <xsl:variable name="number" as="xs:integer"
      select="count(preceding::tei:note[@type = $kind][ancestor::tei:text[1] is current()/ancestor::tei:text[1]]) + 1"/>
    <xsl:variable name="label" select="if ($kind = 'foot') then concat('Footnote ', $number) else concat('Marginal note ', $number)" as="xs:string"/>
    <button type="button" class="note-ref note-ref-{$kind}" data-note-kind="{$kind}" data-note-label="{$label}" data-note-content="{normalize-space(string-join(descendant-or-self::text(), ' '))}">
      <xsl:choose>
        <xsl:when test="$kind = 'foot'">[fn <xsl:value-of select="$number"/>]</xsl:when>
        <xsl:otherwise>[marg. <xsl:value-of select="$number"/>]</xsl:otherwise>
      </xsl:choose>
    </button>
  </xsl:template>

  <xsl:template match="tei:note" mode="render">
    <span class="tei-note tei-note-{@type}">
      <xsl:apply-templates mode="render"/>
    </span>
  </xsl:template>

  <xsl:template match="tei:rs" mode="render">
    <xsl:variable name="entity-id" select="f:eats-id(@ref)" as="xs:string?"/>
    <xsl:choose>
      <xsl:when test="exists($entity-id)">
        <a href="../entities/{$entity-id}.html" class="entity-link" data-entity-id="{$entity-id}">
          <xsl:apply-templates mode="render"/>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <span class="entity-link unresolved" data-ref="{@ref}">
          <xsl:apply-templates mode="render"/>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="render">
    <span class="tei-{local-name()}">
      <xsl:apply-templates mode="render"/>
    </span>
  </xsl:template>

</xsl:stylesheet>
