///| Benchmark wrapper — measures parse and render phases separately

///| Parse only
pub fn bench_parse(input : FixedArray[Byte]) -> MsDocParseResult raise {
  parse_ms_doc(input)
}

///| Render only (re-parses internally)
pub fn bench_render(input : FixedArray[Byte]) -> RenderResult raise {
  render_ms_doc(input)
}

///| Phase 1: CFB parsing only
pub fn bench_cfb_parse(input : FixedArray[Byte]) -> CFBContainer raise {
  let warnings : Array[String] = []
  parse_cfb(input, warnings)
}

///| Phase 2: Object pool extraction (requires CFB container)
pub fn bench_extract_object_pool(container : CFBContainer) -> Map[String, Asset] {
  extract_object_pool(container)
}

///| Phase 3: Get Data stream from CFB
pub fn bench_get_data_stream(container : CFBContainer) -> FixedArray[Byte] {
  match cfb_get_stream(container, "Data") {
    Some(bytes) => bytes
    None => []
  }
}

///| Phase 4: Count object pool entries (for diagnostics)
pub fn bench_count_pool_entries(container : CFBContainer) -> Int {
  let pool_entry = match cfb_find_entry(container, "ObjectPool") {
    Some(e) => e
    None => return 0
  }
  if pool_entry.object_type != 1 {
    return 0
  }
  let children = cfb_list_children(container, pool_entry)
  children.length()
}

///| Phase 5: Get table stream bytes
pub fn bench_get_table_stream(container : CFBContainer) -> FixedArray[Byte] {
  let flags = BinaryReader::make(container.bytes).u16(10)
  let table_name = if (flags & 0x0200) != 0 { "1Table" } else { "0Table" }
  match cfb_get_stream(container, table_name) {
    Some(bytes) => bytes
    None => []
  }
}

///| Phase 6: Count CFB entries (diagnostics)
pub fn bench_count_cfb_entries(container : CFBContainer) -> Int {
  container.entries.length()
}

///| Phase 7: Get WordDocument stream
pub fn bench_get_word_doc_stream(container : CFBContainer) -> FixedArray[Byte] {
  match cfb_get_stream(container, "WordDocument") {
    Some(bytes) => bytes
    None => []
  }
}

///| Full parse intermediate state for sub-phase benchmarking
pub struct ParseIntermediate {
  word_bytes : FixedArray[Byte]
  table_bytes : FixedArray[Byte]
  container : CFBContainer
  clean_full_text : String
  main_story_end : Int
  fib_rgfc_lcb_start : Int
  fib_reader : BinaryReader
  pcd_count : Int
  cps : Array[Int]
  plc_reader : BinaryReader
  chpx_runs : Array[ChpxRun]
  papx_runs : Array[PapxRun]
  styles : StyleCollection
  fonts : FontsCollection
  data_bytes : FixedArray[Byte]
  object_pool : Map[String, Asset]
  resolver : AssetResolver
  style_cache : Map[Int, ResolvedStyle]
}

///| Parse up to paragraph loop start (returns all intermediate data)
pub fn bench_parse_intermediate(input : FixedArray[Byte]) -> ParseIntermediate raise {
  let warnings : Array[String] = []
  let container = parse_cfb(input, warnings)
  let word_bytes = match cfb_get_stream(container, "WordDocument") {
    Some(bytes) => bytes
    None => raise CfbError("WordDocument not found")
  }
  let fib_reader = BinaryReader::make(word_bytes)
  let flags = fib_reader.u16(10)
  if (flags & 0x0100) != 0 {
    raise CfbError("Encrypted")
  }
  let f_which_tbl_stm = if (flags & 0x0200) != 0 { 1 } else { 0 }
  let table_name = if f_which_tbl_stm == 1 { "1Table" } else { "0Table" }
  let table_bytes = match cfb_get_stream(container, table_name) {
    Some(bytes) => bytes
    None => raise CfbError("Table stream not found")
  }
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2
  let ccp_text_offset = cslw_offset + 2 + 3 * 4
  let main_story_end = fib_reader.u32(ccp_text_offset)
  let fc_clx = fib_reader.u32(fib_rgfc_lcb_start + 33 * 8)
  let lcb_clx = fib_reader.u32(fib_rgfc_lcb_start + 33 * 8 + 4)
  if lcb_clx <= 0 {
    raise CfbError("No CLX data")
  }
  let clx_view = table_bytes.view(start=fc_clx, end=fc_clx + lcb_clx)
  let clx_reader = BinaryReader::from_view(clx_view)
  let mut clx_offset = 0
  while clx_offset < clx_view.length() && clx_reader.u8(clx_offset) == 0x01 {
    let cb_grpprl = clx_reader.u16(clx_offset + 1)
    clx_offset += 3 + cb_grpprl
  }
  if clx_offset >= clx_view.length() || clx_reader.u8(clx_offset) != 0x02 {
    raise CfbError("No Pcdt marker")
  }
  let lcb = clx_reader.u32(clx_offset + 1)
  let plc_pcd_view = clx_view.view(start=clx_offset + 5, end=clx_offset + 5 + lcb)
  let plc_reader = BinaryReader::from_view(plc_pcd_view)
  let pcd_count = (lcb - 4) / 12
  if pcd_count <= 0 {
    raise CfbError("No pieces")
  }
  let cps = Array::new()
  for i in 0..<(pcd_count + 1) {
    cps.push(plc_reader.u32(i * 4))
  }
  let document_text = StringBuilder::new()
  let mut piece_offset = (pcd_count + 1) * 4
  for i in 0..<pcd_count {
    let fc_raw = plc_reader.u32(piece_offset + 2)
    let compressed = (fc_raw & 0x40000000) != 0
    let fc = fc_raw & 0x3FFFFFFF
    let cp_start = cps[i]
    let cp_end = cps[i + 1]
    if cp_start >= main_story_end {
      piece_offset += 8
      continue
    }
    let actual_byte_start = if compressed { fc / 2 } else { fc }
    let byte_length = if compressed { cp_end - cp_start } else { (cp_end - cp_start) * 2 }
    let piece = Piece::{
      index: i, compressed, fc, cp_start, cp_end,
      actual_byte_start, byte_length,
      actual_byte_end: actual_byte_start + byte_length,
    }
    let piece_text = extract_piece_text(word_bytes, piece)
    document_text <+ "\{piece_text}"
    piece_offset += 8
  }
  let full_text = document_text.to_string()
  let clean_full_text = full_text.replace(old = "\r", new = "\n")
  let piece_entries = Array::new()
  {
    let mut pe = 0
    while pe < pcd_count {
      let fc_raw = plc_reader.u32((pcd_count + 1) * 4 + pe * 8 + 2)
      let compressed = (fc_raw & 0x40000000) != 0
      let fc = fc_raw & 0x3FFFFFFF
      let byte_start = if compressed { fc / 2 } else { fc }
      let cp_len = cps[pe + 1] - cps[pe]
      let bytes_per_char = if compressed { 1 } else { 2 }
      let byte_end = byte_start + cp_len * bytes_per_char
      piece_entries.push(PieceEntry::{
        cp_start: cps[pe],
        cp_end: cps[pe + 1],
        fc_start: byte_start,
        fc_end: byte_end,
        compressed,
      })
      pe += 1
    }
  }
  let chpx_runs = read_chpx_runs_fallback(word_bytes, table_bytes, main_story_end, piece_entries)
  let papx_runs = read_papx_runs_fallback(word_bytes, table_bytes, main_story_end, piece_entries)
  let stshf_fc = fib_reader.u32(fib_rgfc_lcb_start + 1 * 8)
  let stshf_lcb = fib_reader.u32(fib_rgfc_lcb_start + 1 * 8 + 4)
  let styles = if stshf_lcb > 0 {
    let stshf_view = table_bytes.view(start=stshf_fc, end=stshf_fc + stshf_lcb)
    parse_styles(stshf_view)
  } else {
    StyleCollection::{ styles: [], style_map: Map([], capacity=16), count: 0, header: None }
  }
  let fonts = parse_fonts_from_fib(table_bytes, fib_reader, fib_rgfc_lcb_start)
  let object_pool = extract_object_pool(container)
  let data_bytes = match cfb_get_stream(container, "Data") {
    Some(bytes) => bytes
    None => []
  }
  let resolver = AssetResolver::{
    data_bytes,
    object_pool,
    assets: Array::new(),
    asset_cache: Map([], capacity=16),
    used_names: Map([], capacity=16),
    content_dedup: Map([], capacity=16),
  }
  let style_cache = pre_resolve_all_styles(styles)
  ParseIntermediate::{
    word_bytes,
    table_bytes,
    container,
    clean_full_text,
    main_story_end,
    fib_rgfc_lcb_start,
    fib_reader,
    pcd_count,
    cps,
    plc_reader,
    chpx_runs,
    papx_runs,
    styles,
    fonts,
    data_bytes,
    object_pool,
    resolver,
    style_cache,
  }
}

///| Phase: Paragraph loop only (given pre-parsed intermediate state)
pub fn bench_paragraph_loop(intermediate : ParseIntermediate) -> Array[ParagraphInfo] {
  let paragraphs = Array::new()
  let mut chpx_cursor = 0
  if intermediate.papx_runs.length() > 0 {
    let mut ri = 0
    while ri < intermediate.papx_runs.length() {
      let run = intermediate.papx_runs[ri]
      let cp_start = run.cp_start
      let mut cp_end = run.cp_end
      if cp_start > String::length(intermediate.clean_full_text) {
        ri += 1
        continue
      }
      if cp_end > String::length(intermediate.clean_full_text) {
        cp_end = String::length(intermediate.clean_full_text)
      }
      if cp_start >= cp_end {
        ri += 1
        continue
      }
      let para_text = intermediate.clean_full_text[cp_start : cp_end].to_owned()
      let papx_result = resolve_papx_run(run, intermediate.styles, intermediate.style_cache)
      let para_state = papx_result.para_state
      let (segments, new_cursor) = build_char_segments(intermediate.chpx_runs, para_text, cp_start, cp_end, papx_result.resolved_char_props, intermediate.fonts, intermediate.styles, chpx_cursor, intermediate.style_cache)
      chpx_cursor = new_cursor
      let runs = process_inline_fields(segments, intermediate.resolver)
      let merged_runs = merge_adjacent_runs(runs)
      let clean_para_text = strip_field_markers(para_text)
      let clean_para_text = {
        let len = String::length(clean_para_text)
        if len > 0 {
          let last_ch = clean_para_text[len - 1].to_int()
          if last_ch == 0x0D || last_ch == 0x07 {
            clean_para_text[0 : len - 1].to_owned()
          } else {
            clean_para_text
          }
        } else {
          clean_para_text
        }
      }
      let mut last_ch : Int = 0x0D
      let mut ti = String::length(para_text) - 1
      while ti >= 0 {
        let tc = para_text[ti].to_int()
        if tc != 0x13 && tc != 0x14 && tc != 0x15 {
          last_ch = tc
          break
        }
        ti -= 1
      }
      let terminator_byte = if last_ch == 0x07 { b'\x07' } else { b'\r' }
      paragraphs.push(ParagraphInfo::{
        cp_start,
        cp_end,
        text: clean_para_text,
        runs: merged_runs,
        style_name: papx_result.style_name,
        align: para_state.align,
        indent_left: para_state.indent_left,
        indent_right: para_state.indent_right,
        indent_first: para_state.indent_first,
        space_before: para_state.space_before,
        space_after: para_state.space_after,
        line_spacing: para_state.line_spacing,
        keep_with_next: para_state.keep_with_next,
        keep_together: para_state.keep_together,
        page_break_before: para_state.page_break_before,
        itap: para_state.itap,
        table_row_end: para_state.table_row_end,
        inner_table_cell: para_state.inner_table_cell,
        inner_table_row_end: para_state.inner_table_row_end,
        in_table: para_state.in_table,
        dtap: para_state.dtap,
        rtl_para: para_state.rtl_para,
        terminator: terminator_byte,
        raw_papx: papx_result.raw_props,
        border_top: para_state.border_top,
        border_left: para_state.border_left,
        border_bottom: para_state.border_bottom,
        border_right: para_state.border_right,
        outline_level: para_state.outline_level,
        shading: para_state.shading,
      })
      ri += 1
    }
  }
  paragraphs
}

///| Count of paragraphs, runs etc
pub struct ParseDiagnostics {
  para_count : Int
  chpx_run_count : Int
  papx_run_count : Int
  text_length : Int
  asset_count : Int
  block_count : Int
}

///| Get diagnostics from a parse result
pub fn bench_get_diagnostics(result : MsDocParseResult) -> ParseDiagnostics {
  ParseDiagnostics::{
    para_count: result.paragraphs.length(),
    chpx_run_count: 0,
    papx_run_count: 0,
    text_length: String::length(result.text),
    asset_count: result.assets.length(),
    block_count: result.blocks.length(),
  }
}

///| Get textbox count from a parse result
pub fn bench_get_textbox_count(result : MsDocParseResult) -> Int {
  result.textboxes.length()
}

///| Get textbox info as string
pub fn bench_get_textbox_info(result : MsDocParseResult) -> String {
  let sb = StringBuilder::new()
  sb <+ "Textboxes: \{result.textboxes.length()}\n"
  for i in 0..<result.textboxes.length() {
    let tb = result.textboxes[i]
    let text_preview = if String::length(tb.text) > 50 { tb.text[0:50].to_string() + "..." } else { tb.text }
    sb <+ "  TB[\{i}]: shape_id=\{tb.shape_id}, cp=\{tb.cp_start}..\{tb.cp_end}, text=\{text_preview}\n"
  }
  sb <+ "Text length: \{String::length(result.text)}\n"
  sb <+ "Paragraphs: \{result.paragraphs.length()}\n"
  if result.paragraphs.length() > 0 {
    let last = result.paragraphs[result.paragraphs.length() - 1]
    sb <+ "Last para cp_end: \{last.cp_end}\n"
  }
  // Count MERGEFORMAT paragraphs
  let mut merge_count = 0
  for p in result.paragraphs {
    if String::contains(p.text, "MERGEFORMAT") {
      merge_count += 1
    }
  }
  sb <+ "MERGEFORMAT paragraphs: \{merge_count}\n"
  sb <+ "Warnings (\{result.warnings.length()}):\n"
  for w in result.warnings {
    sb <+ "  \{w}\n"
  }
  sb.to_string()
}

///| Diagnose textbox extraction from raw FIB
pub fn bench_diagnose_txbx(input : FixedArray[Byte]) -> String raise {
  let sb = StringBuilder::new()
  let warnings = Array::new()
  let container = parse_cfb(input, warnings)
  let word_bytes = match cfb_get_stream(container, "WordDocument") {
    Some(bytes) => bytes
    None => { return "WordDocument stream not found" }
  }
  let flags = BinaryReader::make(word_bytes).u16(10)
  let f_which_tbl_stm = if (flags & 0x0200) != 0 { 1 } else { 0 }
  let table_name = if f_which_tbl_stm == 1 { "1Table" } else { "0Table" }
  let table_bytes = match cfb_get_stream(container, table_name) {
    Some(bytes) => bytes
    None => { return "Table stream not found" }
  }

  let fib_reader = BinaryReader::make(word_bytes)
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  sb <+ "FIB csw=\{csw}, cslw=\{cslw}\n"
  sb <+ "fib_rgfc_lcb_start=\{fib_rgfc_lcb_start}\n"
  sb <+ "table_bytes length=\{table_bytes.length()}\n"

  // Read FIBRgLw values
  let ccp_text = fib_reader.u32(cslw_offset + 2 + 3 * 4)
  let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
  let ccp_hdd = fib_reader.u32(cslw_offset + 2 + 5 * 4)
  let ccp_atn = fib_reader.u32(cslw_offset + 2 + 7 * 4)
  let ccp_edn = fib_reader.u32(cslw_offset + 2 + 8 * 4)
  let ccp_txbx = fib_reader.u32(cslw_offset + 2 + 9 * 4)
  let ccp_hdr_txbx = fib_reader.u32(cslw_offset + 2 + 10 * 4)
  sb <+ "FIBRgLw: ccpText=\{ccp_text}, ccpFtn=\{ccp_ftn}, ccpHdd=\{ccp_hdd}, ccpAtn=\{ccp_atn}, ccpEdn=\{ccp_edn}, ccpTxbx=\{ccp_txbx}, ccpHdrTxbx=\{ccp_hdr_txbx}\n"

  // Read FibRgFcLcb values for textboxes
  let fc_plcftxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 56 * 8)
  let lcb_plcftxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 56 * 8 + 4)
  let fc_plcf_fld_txbx = fib_reader.u32(fib_rgfc_lcb_start + 57 * 8)
  let lcb_plcf_fld_txbx = fib_reader.u32(fib_rgfc_lcb_start + 57 * 8 + 4)
  sb <+ "FibRgFcLcb[56] fcPlcftxbxTxt=\{fc_plcftxbx_txt}, lcbPlcftxbxTxt=\{lcb_plcftxbx_txt}\n"
  sb <+ "FibRgFcLcb[57] fcPlcfFldTxbx=\{fc_plcf_fld_txbx}, lcbPlcfFldTxbx=\{lcb_plcf_fld_txbx}\n"

  // Also check FibRgFcLcb for plcfSpa (index 40/41)
  let fc_plc_spa_mom = fib_reader.u32(fib_rgfc_lcb_start + 40 * 8)
  let lcb_plc_spa_mom = fib_reader.u32(fib_rgfc_lcb_start + 40 * 8 + 4)
  sb <+ "FibRgFcLcb[40] fcPlcSpaMom=\{fc_plc_spa_mom}, lcbPlcSpaMom=\{lcb_plc_spa_mom}\n"

  // Try to parse PlcftxbxTxt
  if ccp_txbx > 0 && lcb_plcftxbx_txt > 0 && fc_plcftxbx_txt + lcb_plcftxbx_txt <= table_bytes.length() {
    let txbx_view = table_bytes.view(start=fc_plcftxbx_txt, end=fc_plcftxbx_txt + lcb_plcftxbx_txt)
    let txbx_reader = BinaryReader::from_view(txbx_view)
    let txbx_count = if lcb_plcftxbx_txt >= 4 { (lcb_plcftxbx_txt - 4) / 26 } else { 0 }
    sb <+ "PlcftxbxTxt: count=\{txbx_count}, lcb=\{lcb_plcftxbx_txt}\n"

    if txbx_count > 0 {
      let txbx_cps = Array::new()
      for i in 0..<(txbx_count + 1) {
        txbx_cps.push(txbx_reader.u32(i * 4))
      }
      sb <+ "CPs: \{txbx_cps}\n"

      let ftxbxs_offset = (txbx_count + 1) * 4
      for i in 0..<txbx_count {
        let ftxbxs_base = ftxbxs_offset + i * 22
        let f_reusable = txbx_reader.u16(ftxbxs_base + 8)
        let lid = txbx_reader.u32(ftxbxs_base + 12)
        sb <+ "  FTXBXS[\{i}]: fReusable=\{f_reusable}, lid=\{lid}, cp=\{txbx_cps[i]}..\{txbx_cps[i + 1]}\n"
      }
    }
  } else {
    sb <+ "PlcftxbxTxt: skipped (ccpTxbx=\{ccp_txbx}, lcb=\{lcb_plcftxbx_txt}, fc+lcb=\{fc_plcftxbx_txt + lcb_plcftxbx_txt}, table_len=\{table_bytes.length()})\n"
  }

  sb.to_string()
}

///| Phase: Only resolve_papx_run for all paragraphs
pub fn bench_resolve_all_papx(intermediate : ParseIntermediate) -> Int {
  let mut count = 0
  for run in intermediate.papx_runs {
    let cp_start = run.cp_start
    let cp_end = if run.cp_end > String::length(intermediate.clean_full_text) {
      String::length(intermediate.clean_full_text)
    } else {
      run.cp_end
    }
    if cp_start >= cp_end { continue }
    ignore(resolve_papx_run(run, intermediate.styles, intermediate.style_cache))
    count += 1
  }
  count
}

///| Phase: Only build_char_segments for all paragraphs
pub fn bench_build_all_segments(intermediate : ParseIntermediate) -> Int {
  let mut total_segments = 0
  let mut chpx_cursor = 0
  for run in intermediate.papx_runs {
    let cp_start = run.cp_start
    let cp_end = if run.cp_end > String::length(intermediate.clean_full_text) {
      String::length(intermediate.clean_full_text)
    } else {
      run.cp_end
    }
    if cp_start >= cp_end { continue }
    let para_text = intermediate.clean_full_text[cp_start : cp_end].to_owned()
    let papx_result = resolve_papx_run(run, intermediate.styles, intermediate.style_cache)
    let (segments, new_cursor) = build_char_segments(intermediate.chpx_runs, para_text, cp_start, cp_end, papx_result.resolved_char_props, intermediate.fonts, intermediate.styles, chpx_cursor, intermediate.style_cache)
    chpx_cursor = new_cursor
    total_segments += segments.length()
  }
  total_segments
}

///| Phase: Only process_inline_fields for all paragraphs (with pre-built segments)
pub fn bench_process_all_fields(intermediate : ParseIntermediate) -> Int {
  let mut total_runs = 0
  let mut chpx_cursor = 0
  for run in intermediate.papx_runs {
    let cp_start = run.cp_start
    let cp_end = if run.cp_end > String::length(intermediate.clean_full_text) {
      String::length(intermediate.clean_full_text)
    } else {
      run.cp_end
    }
    if cp_start >= cp_end { continue }
    let para_text = intermediate.clean_full_text[cp_start : cp_end].to_owned()
    let papx_result = resolve_papx_run(run, intermediate.styles, intermediate.style_cache)
    let (segments, new_cursor) = build_char_segments(intermediate.chpx_runs, para_text, cp_start, cp_end, papx_result.resolved_char_props, intermediate.fonts, intermediate.styles, chpx_cursor, intermediate.style_cache)
    chpx_cursor = new_cursor
    let runs = process_inline_fields(segments, intermediate.resolver)
    total_runs += runs.length()
  }
  total_runs
}

///| Create KeepOriginal config (skip all image processing)
pub fn bench_config_keep_original() -> ImageProcessorConfig {
  ImageProcessorConfig::{
    primary: ImageStrategy::KeepOriginal,
    enable_fallback: false,
    max_size: 8 * 1024 * 1024,
    mime_overrides: Map([], capacity=16),
  }
}

///| Create DownloadLink config (use placeholder)
pub fn bench_config_download_link() -> ImageProcessorConfig {
  ImageProcessorConfig::{
    primary: ImageStrategy::DownloadLink,
    enable_fallback: false,
    max_size: 8 * 1024 * 1024,
    mime_overrides: Map([], capacity=16),
  }
}

///| Create ExtractBitmap config
pub fn bench_config_extract_bitmap() -> ImageProcessorConfig {
  ImageProcessorConfig::{
    primary: ImageStrategy::ExtractBitmap,
    enable_fallback: false,
    max_size: 8 * 1024 * 1024,
    mime_overrides: Map([], capacity=16),
  }
}

///| Create default config
pub fn bench_config_default() -> ImageProcessorConfig {
  default_image_config()
}
