///| Streaming parse API for incremental rendering
///| Splits parsing from rendering to enable chunk-based HTML output

///| Parse MS-DOC and return a ParseContext for chunk-based rendering
///| Phase 1: does ALL parsing work (CFB, FIB, styles, paragraphs, blocks)
///| Also pre-extracts all images to avoid postMessage data transfer issues
///| Phase 2: render_chunk() / render_footer_html() consume the context
pub fn parse_init(input : FixedArray[Byte]) -> ParseContext raise {
  let result = parse_ms_doc(input)
  // Pre-extract all images so placeholder SVGs are replaced with real data URLs
  let deferred = DeferredParseResult::{
    result,
    data_bytes: input,
    image_config: default_image_config(),
    image_cache: Map([], capacity=16),
  }
  let processed_assets = extract_all_deferred_images(deferred)
  ParseContext::{
    blocks: result.blocks,
    text: result.text,
    paragraphs: result.paragraphs,
    textboxes: result.textboxes,
    headers: result.headers,
    footers: result.footers,
    sections: result.sections,
    footnotes: result.footnotes,
    endnotes: result.endnotes,
    comments: result.comments,
    assets: processed_assets,
    meta: result.meta,
    fonts: result.fonts,
    styles: result.styles,
    warnings: result.warnings,
  }
}

///| Render a chunk of blocks to HTML fragment
///| start: block index to start from (0-based)
///| count: number of blocks to render
///| Returns: HTML string fragment (no wrapper div)
pub fn render_chunk(ctx : ParseContext, start : Int, count : Int) -> String {
  let sb = StringBuilder::new()
  let block_count = ctx.blocks.length()
  let end_idx = if start + count > block_count { block_count } else { start + count }
  let mut textbox_render_index = 0
  for i in start..<end_idx {
    if i == start {
      for j in 0..<i {
        match ctx.blocks[j] {
          Block::Paragraph(para) => {
            if para.text.contains("MERGEFORMAT") && ctx.textboxes.length() > 0 {
              textbox_render_index += 1
            }
          }
          _ => ()
        }
      }
    }
    match ctx.blocks[i] {
      Block::Attachments(items) => {
        sb <+ "\{render_attachments_html(items)}"
      }
      Block::Table(table) => {
        sb <+ "\{render_table_html(table)}"
      }
      Block::Paragraph(para) => {
        let is_textbox_anchor = para.text.contains("MERGEFORMAT") && ctx.textboxes.length() > 0
        if is_textbox_anchor && textbox_render_index < ctx.textboxes.length() {
          let tb = ctx.textboxes[textbox_render_index]
          if tb.text.length() > 0 {
            sb <+ "<div class=\"msdoc-textbox\">\{escape_html_text(tb.text)}</div>"
          }
          textbox_render_index += 1
        } else {
          sb <+ "\{render_paragraph_html(para, false)}"
        }
      }
    }
  }
  sb.to_string()
}

///| Render footer content: headers, footers, footnotes, endnotes, comments
pub fn render_footer_html(ctx : ParseContext) -> String {
  let sb = StringBuilder::new()

  if ctx.headers.length() > 0 || ctx.footers.length() > 0 {
    sb <+ "<div class=\"msdoc-header-footer\">"
    if ctx.headers.length() > 0 {
      sb <+ "<div class=\"msdoc-headers\">"
      for hf in ctx.headers {
        if hf.text.length() > 0 {
          sb <+ "<div class=\"msdoc-header\">\{escape_html_text(hf.text)}</div>"
        }
      }
      sb <+ "</div>"
    }
    if ctx.footers.length() > 0 {
      sb <+ "<div class=\"msdoc-footers\">"
      for hf in ctx.footers {
        if hf.text.length() > 0 {
          sb <+ "<div class=\"msdoc-footer\">\{escape_html_text(hf.text)}</div>"
        }
      }
      sb <+ "</div>"
    }
    sb <+ "</div>"
  }

  if ctx.footnotes.length() > 0 {
    sb <+ "<div class=\"msdoc-footnotes\">"
    sb <+ "<div class=\"msdoc-footnotes-title\">Notes</div>"
    for ftn in ctx.footnotes {
      if ftn.text.length() > 0 {
        sb <+ "<div class=\"msdoc-footnote\">\{ftn.note_index}. \{escape_html_text(ftn.text)}</div>"
      }
    }
    sb <+ "</div>"
  }

  if ctx.endnotes.length() > 0 {
    sb <+ "<div class=\"msdoc-endnotes\">"
    sb <+ "<div class=\"msdoc-endnotes-title\">Endnotes</div>"
    for edn in ctx.endnotes {
      if edn.text.length() > 0 {
        sb <+ "<div class=\"msdoc-endnote\">\{edn.note_index}. \{escape_html_text(edn.text)}</div>"
      }
    }
    sb <+ "</div>"
  }

  if ctx.comments.length() > 0 {
    sb <+ "<div class=\"msdoc-comments\">"
    sb <+ "<div class=\"msdoc-comments-title\">Comments</div>"
    for c in ctx.comments {
      if c.text.length() > 0 {
        let author_display = if c.author.length() > 0 { escape_html_text(c.author) + ": " } else { "" }
        sb <+ "<div class=\"msdoc-comment\" data-comment-id=\"\{c.comment_index}\">"
        sb <+ "<div class=\"msdoc-comment-header\">"
        sb <+ "<span class=\"msdoc-comment-author\">\{author_display}</span>"
        sb <+ "<span class=\"msdoc-comment-num\">#\{c.comment_index}</span>"
        sb <+ "</div>"
        sb <+ "<div class=\"msdoc-comment-text\">\{escape_html_text(c.text)}</div>"
        sb <+ "</div>"
      }
    }
    sb <+ "</div>"
  }

  sb.to_string()
}

///| Generate CSS for the document
pub fn render_css(ctx : ParseContext, custom_css : String) -> String {
  let base_css = if custom_css.length() > 0 { custom_css } else { get_default_css() }
  if ctx.sections.length() > 0 {
    let sec = ctx.sections[0]
    let orient = if sec.orientation == 1 { " landscape" } else { "" }
    base_css + "\n@page{size:\{sec.page_width}twip \{sec.page_height}twip\{orient};margin:\{sec.margin_top}twip \{sec.margin_right}twip \{sec.margin_bottom}twip \{sec.margin_left}twip}"
  } else {
    base_css
  }
}

///| Get total block count
pub fn get_block_count(ctx : ParseContext) -> Int {
  ctx.blocks.length()
}
