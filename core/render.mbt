///| HTML renderer for MS-DOC

///| Renders parsed MsDocParseResult to HTML+CSS output

///|
/// Escape HTML special characters (single-pass scan)
pub fn escape_html_text(text : String) -> String {
  // Check if any escaping is needed (fast path for plain text)
  let mut needs_escape = false
  let mut i = 0
  let len = String::length(text)
  while i < len {
    let ch = text[i].to_int()
    if ch == 0x26 || ch == 0x3C || ch == 0x3E || ch == 0x22 || ch == 0x27 {
      needs_escape = true
      break
    }
    i += 1
  }
  if !needs_escape {
    return text
  }
  // Single-pass escape
  let result = StringBuilder::new()
  i = 0
  while i < len {
    let ch = text[i].to_int()
    match ch {
      0x26 => result <+ "&amp;"
      0x3C => result <+ "&lt;"
      0x3E => result <+ "&gt;"
      0x22 => result <+ "&quot;"
      0x27 => result <+ "&#39;"
      _ =>
        match text[i].to_char() {
          Some(c) => result <+ "\{c}"
          None => ignore(ch)
        }
    }
    i += 1
  }
  result.to_string()
}

///|
/// Get default CSS styles matching JS reference
pub fn get_default_css() -> String {
  // Base styles
  ".msdoc-root{box-sizing:border-box;max-width:100%;padding:24px;background:#fff;color:#111;font:14px/1.6 -apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif}" +
  ".msdoc-root *{box-sizing:border-box}" +

  // Paragraph styles
  ".msdoc-paragraph{margin:0 0 8px;white-space:normal;word-break:break-word;overflow-wrap:anywhere}" +
  ".msdoc-paragraph:last-child{margin-bottom:0}" +

  // Table styles
  ".msdoc-table{margin:12px 0;border-collapse:collapse;border-spacing:0;max-width:100%}" +
  ".msdoc-table td,.msdoc-table th{padding:6px 8px;border:1px solid #d0d7de;vertical-align:top;word-break:break-word;overflow-wrap:anywhere}" +
  ".msdoc-table th{background:#f6f8fa;font-weight:600}" +

  // Link styles
  ".msdoc-link{color:#1a73e8;text-decoration:none}" +
  ".msdoc-link:hover{text-decoration:underline}" +

  // Image styles
  ".msdoc-image{display:inline-block;vertical-align:middle;max-width:100%;height:auto}" +

  // Attachment styles
  ".msdoc-attachment{display:inline-flex;align-items:center;gap:6px;padding:4px 8px;border:1px solid #d0d7de;border-radius:6px;background:#f6f8fa;color:#0969da;text-decoration:none}" +
  ".msdoc-attachments{margin-top:20px;padding-top:12px;border-top:1px solid #e5e7eb}" +
  ".msdoc-attachments-title{font-weight:600;margin-bottom:8px}" +

  // Form field styles
  ".msdoc-form-field{display:inline-block;margin:0 2px}" +
  ".msdoc-form-text{border:1px solid #999;padding:2px 4px;font-size:inherit;background:#f9f9f9;min-width:100px}" +
  ".msdoc-form-checkbox{margin:0 2px}" +
  ".msdoc-form-dropdown{border:1px solid #999;padding:2px 4px;font-size:inherit;background:#f9f9f9}" +

  // Page break
  ".msdoc-page-break{display:block;height:0;border-top:1px dashed #cbd5e1;margin:16px 0}" +

  // Textbox styles
  ".msdoc-textbox{border:1px solid #d0d7de;border-radius:4px;padding:12px;margin:12px 0;background:#f6f8fa;font-size:12px;white-space:pre-wrap}" +

  // Header/Footer styles
  ".msdoc-header-footer{margin:16px 0}" +
  ".msdoc-headers{margin-bottom:16px}" +
  ".msdoc-header{border-bottom:2px solid #d0d7de;padding:8px 0;margin:4px 0;font-size:12px;color:#666}" +
  ".msdoc-footers{margin-top:16px}" +
  ".msdoc-footer{border-top:2px solid #d0d7de;padding:8px 0;margin:4px 0;font-size:12px;color:#666}" +

  // Footnote/Endnote styles
  ".msdoc-footnotes,.msdoc-endnotes{margin-top:24px;padding-top:12px;border-top:1px solid #d0d7de}" +
  ".msdoc-footnotes-title,.msdoc-endnotes-title{font-weight:600;font-size:12px;margin-bottom:8px;color:#666}" +

  // Comment styles
  ".msdoc-comments{margin-top:24px;padding-top:12px;border-top:1px solid #ffc107}" +
  ".msdoc-comments-title{font-weight:600;font-size:12px;margin-bottom:8px;color:#856404}" +
  ".msdoc-comment{margin:8px 0;padding:8px;background:#fff3cd;border-radius:4px;border-left:3px solid #ffc107}" +
  ".msdoc-comment-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:4px}" +
  ".msdoc-comment-author{font-weight:600;font-size:12px;color:#856404}" +
  ".msdoc-comment-num{font-size:11px;color:#856404;opacity:0.7}" +
  ".msdoc-comment-text{font-size:13px;color:#333}" +
  ".msdoc-footnote,.msdoc-endnote{font-size:11px;margin:4px 0;line-height:1.5;color:#555}" +

  // Heading styles
  "h1{font-size:2em;font-weight:bold;margin:0.67em 0}" +
  "h2{font-size:1.5em;font-weight:bold;margin:0.75em 0}" +
  "h3{font-size:1.17em;font-weight:bold;margin:0.83em 0}" +
  "h4{font-size:1em;font-weight:bold;margin:1em 0}" +
  "h5{font-size:0.83em;font-weight:bold;margin:1.17em 0}" +
  "h6{font-size:0.67em;font-weight:bold;margin:1.67em 0}" +

  // Layer 1: Predefined formatting classes (covers ~70% of runs)
  ".msdoc-b{font-weight:700}" +
  ".msdoc-i{font-style:italic}" +
  ".msdoc-bi{font-weight:700;font-style:italic}" +
  ".msdoc-u-s{text-decoration-line:underline;text-decoration-style:solid}" +
  ".msdoc-u-d{text-decoration-line:underline;text-decoration-style:double}" +
  ".msdoc-u-t{text-decoration-line:underline;text-decoration-style:dotted}" +
  ".msdoc-u-da{text-decoration-line:underline;text-decoration-style:dashed}" +
  ".msdoc-u-w{text-decoration-line:underline;text-decoration-style:wavy}" +
  ".msdoc-strike{text-decoration-line:line-through}" +
  ".msdoc-sc{font-variant-caps:small-caps}" +
  ".msdoc-caps{text-transform:uppercase}" +
  ".msdoc-super{vertical-align:super}" +
  ".msdoc-sub{vertical-align:sub}" +

  // Layer 2: CSS variable run class (covers ~25% of runs with数值属性)
  ".msdoc-run{--fs:inherit;--ff:inherit;--cl:inherit;--bg:inherit}" +
  ".msdoc-run>span,.msdoc-run{font-size:var(--fs);font-family:var(--ff);color:var(--cl);background-color:var(--bg)}"
}

///|
/// Render attachments block to HTML
fn render_attachments_html(items : Array[Asset]) -> String {
  let result = StringBuilder::new()
  result <+ "<section class=\"msdoc-attachments\">"
  result <+ "<div class=\"msdoc-attachments-title\">Embedded attachments</div>"
  result <+ "<ul>"
  for item in items {
    let data_url = if item.data_url.length() > 0 {
      item.data_url
    } else {
      data_url_from_bytes(item.bytes, item.mime)
    }
    let label = if item.name.length() > 0 { item.name } else { "embedded-file" }
    result <+
      "<li><a href=\"\{data_url}\" class=\"msdoc-attachment\" download=\"\{escape_html_text(label)}\">\{escape_html_text(label)}</a></li>"
  }
  result <+ "</ul>"
  result <+ "</section>"
  result.to_string()
}

///|
/// Parse and render MS-DOC to HTML (convenience function)
pub fn render_ms_doc(input : FixedArray[Byte]) -> RenderResult raise {
  let parsed = parse_ms_doc(input)
  render_parsed(parsed)
}

///|
/// Parse and render MS-DOC with custom CSS override
pub fn render_ms_doc_with_css(
  input : FixedArray[Byte],
  custom_css : String,
) -> RenderResult raise {
  let parsed = parse_ms_doc(input)
  render_parsed_with_css(parsed, custom_css)
}

///|
/// Parse MS-DOC and return HTML string directly
pub fn parse_ms_doc_to_html(input : FixedArray[Byte]) -> String raise {
  let result = render_ms_doc(input)
  result.html
}

///|
/// Render parsed result to HTML
pub fn render_parsed(parsed : MsDocParseResult) -> RenderResult {
  render_parsed_with_css(parsed, "")
}

///|
/// Render parsed result to HTML with optional custom CSS
pub fn render_parsed_with_css(
  parsed : MsDocParseResult,
  custom_css : String,
) -> RenderResult {
  // Generate CSS: use custom if provided, else default
  let base_css = if custom_css.length() > 0 {
    custom_css
  } else {
    get_default_css()
  }

  // Append section properties as @page CSS if available
  let css = if parsed.sections.length() > 0 {
    let sec = parsed.sections[0]
    let orient = if sec.orientation == 1 { " landscape" } else { "" }
    base_css +
    "\n@page{size:\{sec.page_width}twip \{sec.page_height}twip\{orient};margin:\{sec.margin_top}twip \{sec.margin_right}twip \{sec.margin_bottom}twip \{sec.margin_left}twip}"
  } else {
    base_css
  }

  // Generate HTML
  let html = StringBuilder::new()
  html <+ "<div class=\"msdoc-root\">"
  // Track textbox rendering state across paragraphs
  let mut textbox_render_index = 0
  for block in parsed.blocks {
    match block {
      Block::Attachments(items) => html <+ "\{render_attachments_html(items)}"
      Block::Table(table) => html <+ "\{render_table_html(table)}"
      Block::Paragraph(para) => {
        // Check if this is a textbox anchor paragraph (contains MERGEFORMAT field)
        let is_textbox_anchor = para.text.contains("MERGEFORMAT") &&
          parsed.textboxes.length() > 0
        if is_textbox_anchor && textbox_render_index < parsed.textboxes.length() {
          // Render the next textbox content
          let tb = parsed.textboxes[textbox_render_index]
          if tb.text.length() > 0 {
            html <+
              "<div class=\"msdoc-textbox\">\{escape_html_text(tb.text)}</div>"
          }
          textbox_render_index += 1
        } else {
          html <+ "\{render_paragraph_html(para, false)}"
        }
      }
    }
  }

  // Render headers and footers
  if parsed.headers.length() > 0 || parsed.footers.length() > 0 {
    html <+ "<div class=\"msdoc-header-footer\">"
    if parsed.headers.length() > 0 {
      html <+ "<div class=\"msdoc-headers\">"
      for hf in parsed.headers {
        if hf.text.length() > 0 {
          html <+
            "<div class=\"msdoc-header\">\{escape_html_text(hf.text)}</div>"
        }
      }
      html <+ "</div>"
    }
    if parsed.footers.length() > 0 {
      html <+ "<div class=\"msdoc-footers\">"
      for hf in parsed.footers {
        if hf.text.length() > 0 {
          html <+
            "<div class=\"msdoc-footer\">\{escape_html_text(hf.text)}</div>"
        }
      }
      html <+ "</div>"
    }
    html <+ "</div>"
  }

  // Render footnotes
  if parsed.footnotes.length() > 0 {
    html <+ "<div class=\"msdoc-footnotes\">"
    html <+ "<div class=\"msdoc-footnotes-title\">Notes</div>"
    for ftn in parsed.footnotes {
      if ftn.text.length() > 0 {
        html <+
          "<div class=\"msdoc-footnote\">\{ftn.note_index}. \{escape_html_text(ftn.text)}</div>"
      }
    }
    html <+ "</div>"
  }

  // Render endnotes
  if parsed.endnotes.length() > 0 {
    html <+ "<div class=\"msdoc-endnotes\">"
    html <+ "<div class=\"msdoc-endnotes-title\">Endnotes</div>"
    for edn in parsed.endnotes {
      if edn.text.length() > 0 {
        html <+
          "<div class=\"msdoc-endnote\">\{edn.note_index}. \{escape_html_text(edn.text)}</div>"
      }
    }
    html <+ "</div>"
  }

  // Render comments
  if parsed.comments.length() > 0 {
    html <+ "<div class=\"msdoc-comments\">"
    html <+ "<div class=\"msdoc-comments-title\">Comments</div>"
    for c in parsed.comments {
      if c.text.length() > 0 {
        let author_display = if c.author.length() > 0 {
          escape_html_text(c.author) + ": "
        } else {
          ""
        }
        html <+
          "<div class=\"msdoc-comment\" data-comment-id=\"\{c.comment_index}\">"
        html <+ "<div class=\"msdoc-comment-header\">"
        html <+ "<span class=\"msdoc-comment-author\">\{author_display}</span>"
        html <+ "<span class=\"msdoc-comment-num\">#\{c.comment_index}</span>"
        html <+ "</div>"
        html <+
          "<div class=\"msdoc-comment-text\">\{escape_html_text(c.text)}</div>"
        html <+ "</div>"
      }
    }
    html <+ "</div>"
  }

  html <+ "</div>"

  RenderResult::{
    html: html.to_string(),
    css,
    warnings: parsed.warnings,
    assets: parsed.assets,
    meta: parsed.meta,
  }
}

///|
/// Convert border object to CSS border string (faithful port of JS borderToCss)
fn border_to_css(line_width : Int, border_type : Int, color : Int) -> String {
  let lw = if line_width <= 0 { 8 } else { line_width }
  let width = {
    let raw = lw * 13333 / (8 * 10000)
    if raw < 1 {
      1
    } else {
      raw
    }
  }
  let bstyle = if border_type == 6 {
    "double"
  } else if border_type == 3 {
    "dotted"
  } else if border_type == 2 {
    "dashed"
  } else {
    "solid"
  }
  let color_hex = if color > 0 { color_index_to_hex(color) } else { "#666" }
  "\{width}px \{bstyle} \{color_hex}"
}

///|
/// Render a single paragraph to HTML
fn render_paragraph_html(para : ParagraphInfo, inline : Bool) -> String {
  let style = StringBuilder::new()

  // text-align from alignment (always emit to match JS output)
  let align_str = css_text_align(para.align)
  style <+ "text-align:\{align_str};"

  // margin-top/bottom from spacingBefore/After via twips_to_px
  if para.space_before > 0 {
    let px = twips_to_px_rounded(para.space_before)
    style <+ "margin-top:\{px}px;"
  }
  if para.space_after > 0 {
    let px = twips_to_px_rounded(para.space_after)
    style <+ "margin-bottom:\{px}px;"
  }

  // margin-left/right from leftIndent/rightIndent via twips_to_px
  if para.indent_left != 0 {
    let px = twips_to_px_rounded(para.indent_left)
    style <+ "margin-left:\{px}px;"
  }
  if para.indent_right != 0 {
    let px = twips_to_px_rounded(para.indent_right)
    style <+ "margin-right:\{px}px;"
  }

  // text-indent from firstLineIndent
  if para.indent_first != 0 {
    let px = twips_to_px_rounded(para.indent_first)
    style <+ "text-indent:\{px}px;"
  }

  // background-color from paragraph shading (Shd80: color index in bits 0-5)
  if para.shading != 0 {
    let color_index = para.shading.land(0x3F)
    if color_index > 0 && color_index < 17 {
      style <+ "background-color:\{color_index_to_hex(color_index)};"
    }
  }

  // line-height from lineSpacing: abs(lineSpacing)/240, clamped to min 1
  if para.line_spacing != 0 && para.line_spacing != 240 {
    let abs_ls = if para.line_spacing < 0 {
      0 - para.line_spacing
    } else {
      para.line_spacing
    }
    let ls_int = abs_ls / 240
    let ls_frac = (abs_ls % 240 * 10 + 120) / 240
    let ls_final = if ls_int < 1 { 1 } else { ls_int }
    if ls_frac >= 5 {
      style <+ "line-height:\{ls_final}.5;"
    } else {
      style <+ "line-height:\{ls_final};"
    }
  }

  // break-inside: avoid from keepLines (keep_together)
  if para.keep_together {
    style <+ "break-inside:avoid;"
  }

  // break-after: avoid from keepNext (keep_with_next)
  if para.keep_with_next {
    style <+ "break-after:avoid;"
  }

  // break-before: page from pageBreakBefore
  if para.page_break_before {
    style <+ "break-before:page;"
  }

  // direction: rtl from rtlPara
  if para.rtl_para {
    style <+ "direction:rtl;"
  }

  // Paragraph borders
  if para.border_top != 0 {
    let lw = para.border_top & 0xFF
    let bt = (para.border_top >> 8) & 0xF
    let bc = (para.border_top >> 16) & 0x3F
    let css = border_to_css(lw, bt, bc)
    style <+ "border-top:\{css};"
  }
  if para.border_left != 0 {
    let lw = para.border_left & 0xFF
    let bt = (para.border_left >> 8) & 0xF
    let bc = (para.border_left >> 16) & 0x3F
    let css = border_to_css(lw, bt, bc)
    style <+ "border-left:\{css};"
  }
  if para.border_bottom != 0 {
    let lw = para.border_bottom & 0xFF
    let bt = (para.border_bottom >> 8) & 0xF
    let bc = (para.border_bottom >> 16) & 0x3F
    let css = border_to_css(lw, bt, bc)
    style <+ "border-bottom:\{css};"
  }
  if para.border_right != 0 {
    let lw = para.border_right & 0xFF
    let bt = (para.border_right >> 8) & 0xF
    let bc = (para.border_right >> 16) & 0x3F
    let css = border_to_css(lw, bt, bc)
    style <+ "border-right:\{css};"
  }

  let style_str = style.to_string()
  // Build CSS class list
  let classes = StringBuilder::new()
  classes <+ "msdoc-paragraph"
  if para.style_name.length() > 0 {
    let slug = slugify(para.style_name)
    if slug.length() > 0 {
      classes <+ " msdoc-style-\{slug}"
    }
  }
  let class_str = classes.to_string()
  let result = StringBuilder::new()
  // Use heading tags for outline levels 0-8 (h1-h9)
  let tag = if inline {
    "div"
  } else if para.outline_level >= 0 && para.outline_level <= 8 {
    "h\{para.outline_level + 1}"
  } else {
    "p"
  }
  if style_str.length() > 0 {
    result <+ "<\{tag} class=\"\{class_str}\" style=\"\{style_str}\">"
  } else {
    result <+ "<\{tag} class=\"\{class_str}\">"
  }

  // Render runs
  if para.runs.length() > 0 {
    for run in para.runs {
      result <+ "\{render_run_html(run)}"
    }
  } else {
    let body = escape_html_text(para.text)
    if body.length() > 0 {
      result <+ "\{body}"
    } else {
      result <+ "<br>"
    }
  }

  result <+ "</\{tag}>"
  result.to_string()
}

///|
/// Render a text run to HTML with inline styles (faithful port of JS inlineStyleToCss)
fn render_run_html(run : RenderRun) -> String {
  // line break: emit <br>
  if run.is_line_break {
    return "<br>"
  }
  // page break: emit <span class="msdoc-page-break"></span>
  if run.is_page_break {
    return "<span class=\"msdoc-page-break\"></span>"
  }
  // image: emit <img> with data URL, wrapped in <a> if hyperlinked
  if run.is_image {
    if run.image_data_url.length() > 0 {
      // Check if it's a placeholder SVG
      let is_placeholder = run.image_data_url.has_prefix("data:image/svg+xml")
      // Check if it's EMF format (browser can't render)
      let is_emf = run.image_data_url.has_prefix("data:image/emf")
      if is_emf {
        // EMF: render as SVG placeholder with info (already converted by image processor)
        // Fall through to regular img rendering
      }
      let placeholder_attr = if is_placeholder {
        " data-placeholder=\"true\""
      } else {
        ""
      }
      let asset_attr = if run.asset_index >= 0 {
        " data-asset-index=\"\{run.asset_index}\""
      } else {
        ""
      }
      let size_attr = if run.image_width > 0 && run.image_height > 0 {
        " width=\"\{run.image_width}\" height=\"\{run.image_height}\""
      } else {
        ""
      }
      let img = "<img src=\"\{run.image_data_url}\" class=\"msdoc-image\" alt=\"image\" style=\"display:inline-block;vertical-align:middle;max-width:100%;height:auto;\"\{size_attr}\{placeholder_attr}\{asset_attr}>"
      if run.href.length() > 0 {
        return "<a class=\"msdoc-link\" href=\"\{escape_html_text(run.href)}\" target=\"_blank\" rel=\"noreferrer noopener\">\{img}</a>"
      }
      return img
    }
    return ""
  }
  // attachment: emit <a> with download
  if run.is_attachment {
    if run.image_data_url.length() > 0 {
      let label = if run.attachment_name.length() > 0 {
        run.attachment_name
      } else {
        "embedded-file"
      }
      if run.href.length() > 0 {
        return "<a href=\"\{run.image_data_url}\" class=\"msdoc-attachment\" download=\"\{escape_html_text(label)}\">\{escape_html_text(label)}</a>"
      }
      return "<a href=\"\{run.image_data_url}\" class=\"msdoc-attachment\" download=\"\{escape_html_text(label)}\">\{escape_html_text(label)}</a>"
    }
    return ""
  }
  // form field: emit appropriate HTML form element
  match run.form_field {
    Some(ff) => {
      match ff.field_type {
        "text" => {
          let val = if ff.default_value.length() > 0 {
            escape_html_text(ff.default_value)
          } else {
            ""
          }
          return "<span class=\"msdoc-form-field\"><input type=\"text\" value=\"\{val}\" class=\"msdoc-form-text\" readonly></span>"
        }
        "checkbox" => {
          let checked_attr = if ff.checked { " checked" } else { "" }
          return "<span class=\"msdoc-form-field\"><input type=\"checkbox\" class=\"msdoc-form-checkbox\" disabled\{checked_attr}></span>"
        }
        "dropdown" => {
          let options = StringBuilder::new()
          if ff.items.length() > 0 {
            for i in 0..<ff.items.length() {
              let selected = if i == ff.selected_index {
                " selected"
              } else {
                ""
              }
              options <+
                "<option\{selected}>\{escape_html_text(ff.items[i])}</option>"
            }
          }
          return "<span class=\"msdoc-form-field\"><select class=\"msdoc-form-dropdown\" disabled>\{options}</select></span>"
        }
        _ => ()
      }
      return ""
    }
    None => ()
  }

  // === Build formatting: CSS class for common combos, inline for rest ===
  let is_bold = run.bold || run.bold_bi
  let is_italic = run.italic || run.italic_bi
  let is_strike = run.strike || run.double_strike
  let is_underline = run.underline > 0 &&
    underline_name(run.underline) != "none" &&
    underline_name(run.underline) != "hidden"

  // Layer 1: Try predefined CSS class for common formatting combos
  let mut used_class = ""
  if is_bold &&
    is_italic &&
    !is_strike &&
    !is_underline &&
    !run.small_caps &&
    !run.caps &&
    run.scale == 100 &&
    run.position_half_points == 0 &&
    !run.superscript &&
    !run.subscript &&
    !run.outline &&
    !run.shadow &&
    !run.emboss &&
    !run.imprint &&
    !run.rtl {
    used_class = "msdoc-bi"
  } else if is_bold &&
    !is_italic &&
    !is_strike &&
    !is_underline &&
    !run.small_caps &&
    !run.caps &&
    run.scale == 100 &&
    run.position_half_points == 0 &&
    !run.superscript &&
    !run.subscript &&
    !run.outline &&
    !run.shadow &&
    !run.emboss &&
    !run.imprint &&
    !run.rtl {
    used_class = "msdoc-b"
  } else if is_italic &&
    !is_bold &&
    !is_strike &&
    !is_underline &&
    !run.small_caps &&
    !run.caps &&
    run.scale == 100 &&
    run.position_half_points == 0 &&
    !run.superscript &&
    !run.subscript &&
    !run.outline &&
    !run.shadow &&
    !run.emboss &&
    !run.imprint &&
    !run.rtl {
    used_class = "msdoc-i"
  }

  // Layer 2+3: Inline style for everything else
  let style = StringBuilder::new()

  if used_class == "" {
    // No class match — full inline style (original approach)
    if is_bold {
      style <+ "font-weight:700;"
    }
    if is_italic {
      style <+ "font-style:italic;"
    }
    if is_strike || is_underline {
      let deco_line = StringBuilder::new()
      let mut deco_style_val = ""
      if is_strike {
        deco_line <+ "line-through"
      }
      if is_underline {
        let name = underline_name(run.underline)
        deco_line <+ "underline"
        deco_style_val = if name == "double" || name == "wavy-double" {
          "double"
        } else if name == "dotted" ||
          name == "dot-dash" ||
          name == "dot-dot-dash" ||
          name == "dotted-heavy" ||
          name == "dot-dash-heavy" ||
          name == "dot-dot-dash-heavy" {
          "dotted"
        } else if name == "dash" ||
          name == "dashed-heavy" ||
          name == "dash-long" ||
          name == "dash-long-heavy" {
          "dashed"
        } else if name == "wave" || name == "wavy-heavy" {
          "wavy"
        } else {
          "solid"
        }
      }
      if deco_line.to_string().length() > 0 {
        style <+ "text-decoration-line:\{deco_line};"
      }
      if deco_style_val.length() > 0 {
        style <+ "text-decoration-style:\{deco_style_val};"
      }
    }
    // font-size
    if run.font_size > 0 {
      let pt_int = run.font_size / 2
      let pt_frac = run.font_size % 2
      if pt_frac != 0 {
        style <+ "font-size:\{pt_int}.5pt;"
      } else {
        style <+ "font-size:\{pt_int}pt;"
      }
    }
    // font-family
    if run.font_family.length() > 0 {
      let escaped_font = run.font_family.replace(old="'", new="\\'")
      style <+ "font-family:'\{escaped_font}',sans-serif;"
    }
    // color
    if run.color > 0 {
      style <+ "color:\{color_index_to_hex(run.color)};"
    }
    // highlight
    if run.highlight > 0 {
      let hex = highlight_color_to_hex(run.highlight)
      if hex.length() > 0 {
        style <+ "background-color:\{hex};"
      }
    }
    // small caps
    if run.small_caps {
      style <+ "font-variant-caps:small-caps;"
    }
    // uppercase
    if run.caps {
      style <+ "text-transform:uppercase;"
    }
    // vertical-align
    if run.position_half_points > 0 || run.superscript {
      style <+ "vertical-align:super;"
    } else if run.position_half_points < 0 || run.subscript {
      style <+ "vertical-align:sub;"
    }
  } else {
    // Class match — only add non-class properties inline
    if run.font_size > 0 {
      let pt_int = run.font_size / 2
      let pt_frac = run.font_size % 2
      if pt_frac != 0 {
        style <+ "font-size:\{pt_int}.5pt;"
      } else {
        style <+ "font-size:\{pt_int}pt;"
      }
    }
    if run.font_family.length() > 0 {
      let escaped_font = run.font_family.replace(old="'", new="\\'")
      style <+ "font-family:'\{escaped_font}',sans-serif;"
    }
    if run.color > 0 {
      style <+ "color:\{color_index_to_hex(run.color)};"
    }
    if run.highlight > 0 {
      let hex = highlight_color_to_hex(run.highlight)
      if hex.length() > 0 {
        style <+ "background-color:\{hex};"
      }
    }
  }

  // Scale (always inline)
  if run.scale != 100 && run.scale > 0 {
    let int_part = run.scale / 100
    let frac_part = run.scale % 100
    style <+ "display:inline-block;"
    if frac_part == 0 {
      style <+ "transform:scaleX(\{int_part});"
    } else {
      style <+ "transform:scaleX(\{int_part}.\{frac_part});"
    }
    style <+ "transform-origin:left center;"
  }

  // text-shadow
  let mut text_shadow = ""
  if run.outline {
    text_shadow = "0 0 0.02em currentColor"
  }
  if run.shadow || run.emboss || run.imprint {
    if text_shadow.length() > 0 {
      text_shadow = "\{text_shadow},0.06em 0.06em 0.08em rgba(0,0,0,.25)"
    } else {
      text_shadow = "0.06em 0.06em 0.08em rgba(0,0,0,.25)"
    }
  }
  if text_shadow.length() > 0 {
    style <+ "text-shadow:\{text_shadow};"
  }

  // RTL
  if run.rtl {
    style <+ "direction:rtl;"
  }

  // white-space
  style <+ "white-space:break-spaces;"

  // === Build final HTML ===
  let style_str = style.to_string()
  let escaped_text = escape_html_text(run.text)
  let inner = if used_class.length() > 0 {
    if style_str.length() > 0 {
      "<span class=\"\{used_class}\" style=\"\{style_str}\">\{escaped_text}</span>"
    } else {
      "<span class=\"\{used_class}\">\{escaped_text}</span>"
    }
  } else if style_str.length() > 0 {
    "<span style=\"\{style_str}\">\{escaped_text}</span>"
  } else {
    escaped_text
  }
  if run.href.length() > 0 {
    "<a class=\"msdoc-link\" href=\"\{escape_html_text(run.href)}\" target=\"_blank\" rel=\"noreferrer noopener\">\{inner}</a>"
  } else {
    inner
  }
}

///|
/// Render a table block to HTML
fn render_table_html(table : TableBlock) -> String {
  let result = StringBuilder::new()
  let depth_class = "msdoc-table-depth-\{table.depth}"

  // Compute table width and margin from table_state
  let mut table_width_px = 0
  let mut table_margin_left_px = 0
  let mut table_alignment = ""
  let mut table_bg_color = ""
  match table.table_state {
    Some(ts) => {
      if ts.row_height > 0 {
        ignore(ts.row_height)
      }
      // Use grid width from first row, or fall back to tableWidth SPRM
      if table.rows.length() > 0 && table.rows[0].grid_width_twips > 0 {
        table_width_px = twips_to_px_rounded(table.rows[0].grid_width_twips)
      } else if ts.table_width > 0 {
        table_width_px = twips_to_px_rounded(ts.table_width)
      }
      if ts.left_indent > 0 {
        table_margin_left_px = twips_to_px_rounded(ts.left_indent)
      }
      // Table alignment (0=left, 1=center, 2=right)
      table_alignment = match ts.alignment {
        0 => "left"
        1 => "center"
        2 => "right"
        _ => ""
      }
      // Table background shading
      if ts.table_shading > 0 {
        table_bg_color = color_index_to_hex(ts.table_shading)
      }
    }
    None => ignore(0)
  }

  let mut table_style = "border-collapse:collapse;table-layout:fixed;"
  if table_width_px > 0 {
    table_style = "\{table_style}width:\{table_width_px}px;"
  } else {
    table_style = "\{table_style}width:100%;"
  }
  if table_margin_left_px > 0 {
    table_style = "\{table_style}margin-left:\{table_margin_left_px}px;"
  }
  if table_alignment.length() > 0 {
    if table_alignment == "center" {
      table_style = "\{table_style}margin-left:auto;margin-right:auto;"
    } else if table_alignment == "right" {
      table_style = "\{table_style}margin-left:auto;margin-right:0;"
    }
    // left alignment uses the margin-left from left_indent (already set above)
  }
  if table_bg_color.length() > 0 {
    table_style = "\{table_style}background-color:\{table_bg_color};"
  }

  result <+
    "<table class=\"msdoc-table \{depth_class}\" style=\"\{table_style}\">"
  result <+ "<tbody>"
  for row in table.rows {
    // Per-row height: use row.row_height if available, else table-level
    // Negative dyaRowHeight means "at least" (minimum) — take absolute value
    let mut row_height_px = 0
    let rh = if row.row_height < 0 { -row.row_height } else { row.row_height }
    if rh > 0 {
      row_height_px = twips_to_px_rounded(rh)
    } else {
      match table.table_state {
        Some(ts) => {
          let ts_rh = if ts.row_height < 0 {
            -ts.row_height
          } else {
            ts.row_height
          }
          if ts_rh > 0 {
            row_height_px = twips_to_px_rounded(ts_rh)
          }
        }
        None => ignore(0)
      }
    }
    let row_style = if row_height_px > 0 {
      "height:\{row_height_px}px"
    } else {
      ""
    }
    if row_style.length() > 0 {
      result <+ "<tr class=\"msdoc-row\" style=\"\{row_style}\">"
    } else {
      result <+ "<tr class=\"msdoc-row\">"
    }
    for cell in row.cells {
      if cell.hidden {
        continue
      }

      let cell_style = StringBuilder::new()

      // Cell width from meta
      match cell.meta {
        Some(def) => {
          let width = def.right_boundary - def.left_boundary
          if width > 0 {
            let width_px = twips_to_px_rounded(width)
            cell_style <+ "width:\{width_px}px;"
          }
          // Vertical align
          let va = match def.vert_align {
            0 => "top"
            1 => "middle"
            2 => "bottom"
            _ => "top"
          }
          cell_style <+ "vertical-align:\{va};"

          // Borders from cell meta (brc80 format)
          if def.borders.length() >= 4 {
            // Helper to convert brc80 to CSS border string
            let brc_to_css = fn(
              line_width : Int,
              border_type : Int,
              color_idx : Int,
            ) -> String? {
              // Match JS formula: Math.max(1, Math.round(((lineWidth ?? 8) / 8) * 1.3333))
              let lw = if line_width <= 0 { 8 } else { line_width }
              let width_px = {
                let w = (lw * 13333 + 40000) / 80000
                if w < 1 {
                  1
                } else {
                  w
                }
              }
              let css_style = match border_type {
                2 => "dashed"
                3 => "dotted"
                6 => "double"
                _ => "solid"
              }
              let hex = color_index_to_hex(color_idx)
              let css_color = hex
              Some("\{width_px}px \{css_style} \{css_color}")
            }

            if def.borders.length() >= 16 {
              // 16 bytes: 4 borders (top, left, bottom, right), each 4 bytes (brc80)
              let top_border = brc_to_css(
                def.borders[0].to_int(),
                def.borders[1].to_int(),
                def.borders[2].to_int(),
              )
              let left_border = brc_to_css(
                def.borders[4].to_int(),
                def.borders[5].to_int(),
                def.borders[6].to_int(),
              )
              let bottom_border = brc_to_css(
                def.borders[8].to_int(),
                def.borders[9].to_int(),
                def.borders[10].to_int(),
              )
              let right_border = brc_to_css(
                def.borders[12].to_int(),
                def.borders[13].to_int(),
                def.borders[14].to_int(),
              )
              match top_border {
                Some(v) => cell_style <+ "border-top:\{v};"
                None => ignore(0)
              }
              match left_border {
                Some(v) => cell_style <+ "border-left:\{v};"
                None => ignore(0)
              }
              match bottom_border {
                Some(v) => cell_style <+ "border-bottom:\{v};"
                None => ignore(0)
              }
              match right_border {
                Some(v) => cell_style <+ "border-right:\{v};"
                None => ignore(0)
              }
            } else {
              // 4 bytes: single brc80 value applied to all borders
              let border_css = brc_to_css(
                def.borders[0].to_int(),
                def.borders[1].to_int(),
                def.borders[2].to_int(),
              )
              match border_css {
                Some(v) => {
                  cell_style <+ "border-top:\{v};"
                  cell_style <+ "border-left:\{v};"
                  cell_style <+ "border-bottom:\{v};"
                  cell_style <+ "border-right:\{v};"
                }
                None => ignore(0)
              }
            }
          }
          // Cell shading (background color) via color index lookup
          if def.shading.length() >= 1 {
            let color_index = def.shading[0].to_int()
            if color_index > 0 {
              cell_style <+
                "background-color:\{color_index_to_hex(color_index)};"
            }
          }

          // Cell padding from table state (if available)
          match table.table_state {
            Some(ts) =>
              if ts.cell_padding.length() >= 4 {
                let pt = ts.cell_padding[0]
                let pl = ts.cell_padding[1]
                let pb = ts.cell_padding[2]
                let pr = ts.cell_padding[3]
                if pt > 0 || pl > 0 || pb > 0 || pr > 0 {
                  let pt_px = if pt > 0 { twips_to_px_rounded(pt) } else { 0 }
                  let pl_px = if pl > 0 { twips_to_px_rounded(pl) } else { 0 }
                  let pb_px = if pb > 0 { twips_to_px_rounded(pb) } else { 0 }
                  let pr_px = if pr > 0 { twips_to_px_rounded(pr) } else { 0 }
                  cell_style <+
                    "padding:\{pt_px}px \{pr_px}px \{pb_px}px \{pl_px}px;"
                }
              }
            None => ignore(0)
          }

          // Cell fitText (text-align: justify)
          if def.fit_text {
            cell_style <+ "text-align:justify;"
          }

          // Cell noWrap (white-space: nowrap)
          if def.no_wrap {
            cell_style <+ "white-space:nowrap;"
          }
        }
        None => ignore(0)
      }

      let cs = cell.colspan
      let rs = cell.rowspan
      let colspan_attr = if cs > 1 { " colspan=\"\{cs}\"" } else { "" }
      let rowspan_attr = if rs > 1 { " rowspan=\"\{rs}\"" } else { "" }
      let style_str = cell_style.to_string()
      let style_attr = if style_str.length() > 0 {
        " style=\"\{style_str}\""
      } else {
        ""
      }

      result <+
        "<td class=\"msdoc-cell\"\{colspan_attr}\{rowspan_attr}\{style_attr}>"
      if cell.paragraphs.length() > 0 {
        for para in cell.paragraphs {
          result <+ "\{render_paragraph_html(para, true)}"
        }
      } else {
        result <+ "<div class=\"msdoc-paragraph\"><br></div>"
      }
      result <+ "</td>"
    }
    result <+ "</tr>"
  }
  result <+ "</tbody>"
  result <+ "</table>"
  result.to_string()
}
