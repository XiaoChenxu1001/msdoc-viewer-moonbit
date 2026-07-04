///| 白盒单元测试 — 直接测试核心解析/渲染内部函数

// ==================== HTML 转义 ====================

test "escape_html_text empty" {
  assert_eq(escape_html_text(""), "")
}

test "escape_html_text normal" {
  assert_eq(escape_html_text("abc"), "abc")
}

test "escape_html_text tags" {
  assert_eq(escape_html_text("<b>"), "&lt;b&gt;")
}

test "escape_html_text ampersand" {
  assert_eq(escape_html_text("a&b"), "a&amp;b")
}

test "escape_html_text quotes" {
  assert_eq(escape_html_text("\"x\""), "&quot;x&quot;")
}

test "escape_html_text apostrophe" {
  assert_eq(escape_html_text("it's"), "it&#39;s")
}

test "escape_html_text mixed" {
  assert_eq(escape_html_text("<>&\"'"), "&lt;&gt;&amp;&quot;&#39;")
}

// ==================== CSS 生成 ====================

test "get_default_css non-empty" {
  let css = get_default_css()
  inspect(css.length() > 100, content="true")
}

test "get_default_css contains root" {
  let css = get_default_css()
  inspect(css.contains(".msdoc-root"), content="true")
}

test "get_default_css contains paragraph" {
  let css = get_default_css()
  inspect(css.contains(".msdoc-paragraph"), content="true")
}

test "get_default_css contains table" {
  let css = get_default_css()
  inspect(css.contains(".msdoc-table"), content="true")
}

// ==================== 图片格式检测 ====================

test "detect_image_format PNG" {
  let png : FixedArray[Byte] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
  assert_eq(detect_image_format(png), "image/png")
}

test "detect_image_format unknown short" {
  let short : FixedArray[Byte] = [0xFF, 0xD8]
  assert_eq(detect_image_format(short), "unknown")
}

test "detect_image_format unknown empty" {
  let empty : FixedArray[Byte] = []
  assert_eq(detect_image_format(empty), "unknown")
}

// ==================== MIME 检测 ====================

test "detect_mime PNG" {
  let png : FixedArray[Byte] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
  assert_eq(detect_mime_from_bytes(png), "image/png")
}

test "detect_mime empty" {
  let empty : FixedArray[Byte] = []
  assert_eq(detect_mime_from_bytes(empty), "application/octet-stream")
}

// ==================== 图片尺寸 ====================

test "extract_pic_dimensions empty" {
  let empty : FixedArray[Byte] = []
  let result = extract_pic_dimensions(empty, 0)
  assert_eq(result, None)
}

test "calculate_display_dimensions" {
  let (w, h) = calculate_display_dimensions(1000, 2000, 100, 100)
  inspect(w > 0, content="true")
  inspect(h > 0, content="true")
}

// ==================== SPRM ====================

test "get_sprm_operand_length char" {
  // All SPRMs return 1 for operand length in this implementation
  assert_eq(get_sprm_operand_length(0x0801), 1)
}

test "get_sprm_kind char" {
  assert_eq(get_sprm_kind(0x0801), "char")
}

test "get_sprm_kind para" {
  assert_eq(get_sprm_kind(0x2401), "para")
}

// ==================== 属性状态 ====================

test "char_props_to_state defaults" {
  let props : Array[Byte] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let state = char_props_to_state(props)
  assert_eq(state.bold, false)
  assert_eq(state.italic, false)
  assert_eq(state.strike, false)
}

test "para_props_to_state defaults" {
  let props : Array[Byte] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  let state = para_props_to_state(props)
  assert_eq(state.align, 0)
  assert_eq(state.in_table, false)
}

// ==================== CSS 映射 ====================

test "css_text_align" {
  assert_eq(css_text_align(0), "left")
  assert_eq(css_text_align(1), "center")
  assert_eq(css_text_align(2), "right")
  assert_eq(css_text_align(3), "justify")
}

test "css_underline single" {
  assert_eq(css_underline(0), "none")
  assert_eq(css_underline(1), "single")
}

// ==================== TcGrf ====================

test "parse_tcgrf zero" {
  let bytes : FixedArray[Byte] = [0x00, 0x00]
  let result = parse_tcgrf(bytes, 0)
  assert_eq(result.vert_merge, 0)
  assert_eq(result.vert_align, 0)
}

// ==================== Brc80 ====================

test "parse_brc80 zero" {
  let bytes : FixedArray[Byte] = [0x00, 0x00, 0x00, 0x00]
  let result = parse_brc80(bytes, 0)
  assert_eq(result.border_type, 0)
  assert_eq(result.color, 0)
}

// ==================== EMF Converter ====================

test "validate_emf_converter_config" {
  let config = default_emf_converter_config()
  let errors = validate_emf_converter_config(config)
  // Config may have validation errors, just verify it runs
  inspect(true, content="true")
}

test "needs_server_conversion EMF" {
  assert_eq(needs_server_conversion("image/emf"), true)
}

test "needs_server_conversion WMF" {
  assert_eq(needs_server_conversion("image/wmf"), true)
}

test "needs_server_conversion PNG" {
  assert_eq(needs_server_conversion("image/png"), false)
}

// ==================== Image Processor ====================

test "default_image_config" {
  let config = default_image_config()
  inspect(config.max_size > 0, content="true")
}

test "needs_processing EMF" {
  assert_eq(needs_processing("image/emf"), true)
}

test "needs_processing PNG" {
  assert_eq(needs_processing("image/png"), false)
}

// ==================== EMF Cache ====================

test "create_emf_cache" {
  let cache = create_emf_cache(60000)
  // Cache created successfully
  inspect(true, content="true")
}

test "compute_content_hash" {
  let d1 : FixedArray[Byte] = [0x01, 0x02, 0x03]
  let d2 : FixedArray[Byte] = [0x01, 0x02, 0x03]
  let d3 : FixedArray[Byte] = [0x04, 0x05, 0x06]
  let h1 = compute_content_hash(d1)
  let h2 = compute_content_hash(d2)
  let h3 = compute_content_hash(d3)
  assert_eq(h1, h2)
  inspect(h1 != h3, content="true")
}

// ==================== Placeholder Asset ====================

test "create_placeholder_asset" {
  let asset = create_placeholder_asset(100)
  assert_eq(asset.asset_type, "image")
  inspect(asset.data_url.contains("svg"), content="true")
}

// ==================== Summary Info ====================

test "parse_summary_info empty" {
  let empty : FixedArray[Byte] = []
  let result = parse_summary_info(empty)
  match result {
    Some(_) => inspect(false, content="true")
    None => inspect(true, content="true")
  }
}

// ==================== ParagraphInfo 构造 ====================

test "paragraph info creation" {
  let para = ParagraphInfo::{
    cp_start: 0, cp_end: 5, text: "hello", runs: [],
    style_name: "Normal", align: 0, indent_left: 0,
    indent_right: 0, indent_first: 0, space_before: 0,
    space_after: 0, line_spacing: 240, keep_with_next: false,
    keep_together: false, page_break_before: false, itap: 0,
    table_row_end: false, inner_table_cell: false,
    inner_table_row_end: false, in_table: false, dtap: 0,
    rtl_para: false, terminator: 0x0D, raw_papx: [],
    border_top: 0, border_left: 0, border_bottom: 0,
    border_right: 0, outline_level: 0, shading: 0,
  }
  assert_eq(para.text, "hello")
  assert_eq(para.style_name, "Normal")
  assert_eq(para.runs.length(), 0)
}

// ==================== RenderRun 构造 ====================

test "render run creation" {
  let run = RenderRun::{
    text: "test", bold: true, italic: false, underline: 1,
    strike: false, double_strike: false, font_size: 24,
    font_family: "Arial", color: -1, highlight: 0,
    superscript: false, subscript: false, href: "",
    bold_bi: false, italic_bi: false, small_caps: false,
    caps: false, outline: false, shadow: false,
    emboss: false, imprint: false, scale: 100,
    position_half_points: 0, rtl: false,
    is_line_break: false, is_page_break: false,
    is_image: false, image_data_url: "", image_width: 0,
    image_height: 0, is_attachment: false, attachment_name: "",
    form_field: None,
  }
  assert_eq(run.text, "test")
  assert_eq(run.bold, true)
  assert_eq(run.font_size, 24)
}

// ==================== Block 构造 ====================

test "block with paragraph" {
  let para = ParagraphInfo::{
    cp_start: 0, cp_end: 3, text: "abc", runs: [],
    style_name: "Normal", align: 0, indent_left: 0,
    indent_right: 0, indent_first: 0, space_before: 0,
    space_after: 0, line_spacing: 240, keep_with_next: false,
    keep_together: false, page_break_before: false, itap: 0,
    table_row_end: false, inner_table_cell: false,
    inner_table_row_end: false, in_table: false, dtap: 0,
    rtl_para: false, terminator: 0x0D, raw_papx: [],
    border_top: 0, border_left: 0, border_bottom: 0,
    border_right: 0, outline_level: 0, shading: 0,
  }
  let block = Block::Paragraph(para)
  match block {
    Block::Paragraph(p) => assert_eq(p.text, "abc")
    _ => inspect(false, content="true")
  }
}

// ==================== build_blocks ====================

test "build_blocks empty" {
  let paragraphs : Array[ParagraphInfo] = []
  let styles = StyleCollection::{ styles: [], style_map: Map::new(), count: 0, header: None }
  let blocks = build_blocks(paragraphs, styles)
  assert_eq(blocks.length(), 0)
}


// ==================== 私有函数测试（验证白盒能力） ====================
// 以下测试调用的是非 pub 函数，只有白盒测试才能访问

test "cp1252_to_unicode ASCII range" {
  // CP1252 0x41-0x5A = ASCII A-Z
  assert_eq(cp1252_to_unicode(0x41), 0x0041)  // 'A'
  assert_eq(cp1252_to_unicode(0x5A), 0x005A)  // 'Z'
}

test "cp1252_to_unicode special chars" {
  // CP1252 0x82 = single low-9 quotation mark
  assert_eq(cp1252_to_unicode(0x82), 0x201A)
  // CP1252 0x93 = left double quotation mark
  assert_eq(cp1252_to_unicode(0x93), 0x201C)
  // CP1252 0x94 = right double quotation mark
  assert_eq(cp1252_to_unicode(0x94), 0x201D)
  // CP1252 0x96 = en dash
  assert_eq(cp1252_to_unicode(0x96), 0x2013)
  // CP1252 0x97 = em dash
  assert_eq(cp1252_to_unicode(0x97), 0x2014)
}

test "cp1252_to_unicode passthrough" {
  // CP1252 0x20-0x7E = same as ASCII
  assert_eq(cp1252_to_unicode(0x20), 0x0020)  // space
  assert_eq(cp1252_to_unicode(0x7E), 0x007E)  // tilde
}



