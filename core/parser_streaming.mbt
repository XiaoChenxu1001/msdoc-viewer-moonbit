///| Streaming parse API for incremental rendering
///| Splits parsing from rendering to enable chunk-based HTML output

///| Precompute textbox block indices: block_index -> textbox_index (-1 if not anchor)
fn precompute_textbox_indices(blocks : Array[Block], textboxes : Array[TextBox]) -> Array[Int] {
  let indices = Array::new()
  let mut tidx = 0
  for i in 0..<blocks.length() {
    match blocks[i] {
      Block::Paragraph(para) => {
        if para.text.contains("MERGEFORMAT") && textboxes.length() > 0 && tidx < textboxes.length() {
          indices.push(tidx)
          tidx += 1
        } else {
          indices.push(-1)
        }
      }
      _ => indices.push(-1)
    }
  }
  indices
}

///| Parse MS-DOC and return a ParseContext for chunk-based rendering
///| Phase 1: does ALL parsing work (CFB, FIB, styles, paragraphs, blocks)
///| Images are NOT processed during init -- they're processed lazily during render_chunk()
///| Phase 2: render_chunk() / render_footer_html() consume the context
pub fn parse_init(input : FixedArray[Byte]) -> ParseContext raise {
  let result = parse_ms_doc(input)
  let textbox_indices = precompute_textbox_indices(result.blocks, result.textboxes)
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
    assets: result.assets,
    meta: result.meta,
    fonts: result.fonts,
    styles: result.styles,
    warnings: result.warnings,
    image_cache: Map([], capacity=16),
    textbox_block_indices: textbox_indices,
  }
}

///| Get processed image data URL from cache, or process on-demand
///| This is the lazy image processing -- images are processed when first accessed
pub fn get_or_process_image(ctx : ParseContext, asset_index : Int) -> String {
  if asset_index < 0 || asset_index >= ctx.assets.length() { return "" }
  // Check cache first
  match ctx.image_cache.get(asset_index) {
    Some(cached) => return cached
    None => ()
  }
  let asset = ctx.assets[asset_index]
  // If already has real data URL (not placeholder), return as-is
  if asset.data_url.length() > 0 && !asset.data_url.has_prefix("data:image/svg+xml") {
    ctx.image_cache.set(asset_index, asset.data_url)
    return asset.data_url
  }
  // If has raw bytes, process them lazily
  if asset.bytes.length() > 0 {
    let processed = process_raw_image_asset(asset)
    ctx.image_cache.set(asset_index, processed.data_url)
    return processed.data_url
  }
  // Return original (placeholder or empty)
  asset.data_url
}

///| Render a chunk of blocks to HTML fragment
///| start: block index to start from (0-based)
///| count: number of blocks to render
///| Returns: ChunkResult with HTML and asset indices for concurrent image processing
pub fn render_chunk(ctx : ParseContext, start : Int, count : Int) -> ChunkResult {
  let sb = StringBuilder::new()
  let asset_indices = Array::new()
  let block_count = ctx.blocks.length()
  let end_idx = if start + count > block_count { block_count } else { start + count }
  // Use precomputed textbox indices instead of scanning all previous blocks
  for i in start..<end_idx {
    match ctx.blocks[i] {
      Block::Attachments(items) => {
        sb <+ "\{render_attachments_html(items)}"
      }
      Block::Table(table) => {
        sb <+ "\{render_table_html(table)}"
      }
      Block::Paragraph(para) => {
        // Use precomputed textbox index
        let textbox_idx = if i < ctx.textbox_block_indices.length() { ctx.textbox_block_indices[i] } else { -1 }
        if textbox_idx >= 0 && textbox_idx < ctx.textboxes.length() {
          let tb = ctx.textboxes[textbox_idx]
          if tb.text.length() > 0 {
            sb <+ "<div class=\"msdoc-textbox\">\{escape_html_text(tb.text)}</div>"
          }
        } else {
          // Collect asset indices from image runs in this paragraph
          for run in para.runs {
            if run.is_image && run.asset_index >= 0 {
              let is_placeholder = run.image_data_url.has_prefix("data:image/svg+xml")
              if is_placeholder {
                asset_indices.push(run.asset_index)
              }
            }
          }
          sb <+ "\{render_paragraph_html(para, false)}"
        }
      }
    }
  }
  ChunkResult::{ html: sb.to_string(), asset_indices }
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
