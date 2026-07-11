///| Run building and inline field processing for MS-DOC parser

///|
/// Default CharState with standard formatting defaults
fn default_char_state() -> CharState {
  CharState::{
    bold: false,
    italic: false,
    underline: 0,
    strike: false,
    double_strike: false,
    font_size: 21,
    font_family_id: 0,
    font_family: "",
    color: 0,
    highlight: 0,
    superscript: false,
    subscript: false,
    hidden: false,
    small_caps: false,
    caps: false,
    outline: false,
    shadow: false,
    emboss: false,
    imprint: false,
    spacing: 0,
    position_half_points: 0,
    scale: 100,
    picture_offset: 0,
    rtl: false,
    bold_bi: false,
    italic_bi: false,
    char_style_id: 0,
    is_ole2: false,
    is_data: false,
    is_object: false,
  }
}

///|
/// Resolve font name from font family ID
fn resolve_font_name(state : CharState, fonts : FontsCollection) -> String {
  if state.font_family_id > 0 {
    match font_by_index(fonts, state.font_family_id) {
      Some(font) => font.name
      None => state.font_family
    }
  } else {
    state.font_family
  }
}

///|
/// Resolve a single PAPX run by merging its direct properties with the style chain
fn resolve_papx_run(
  run : PapxRun,
  styles : StyleCollection,
  style_cache : Map[Int, ResolvedStyle],
) -> PapxResult {
  let view = run.properties.view()
  let direct_decoded = decode_grpprl(view)
  let style_id = if run.style_id > 0 {
    run.style_id
  } else {
    let mut sid = 0
    for prop in direct_decoded {
      if prop.name == "istdPara" || prop.name == "istd" {
        sid = prop.value
      }
    }
    sid
  }
  let resolved = resolve_style_from_cache(style_cache, style_id)
  let all_para = Array::new()
  for p in resolved.para_props {
    all_para.push(p)
  }
  for p in direct_decoded {
    all_para.push(p)
  }
  let para_state = para_props_from_decoded(all_para)
  let resolved_style_name = match get_style(styles, style_id) {
    Some(s) => s.name
    None => ""
  }
  PapxResult::{
    para_state,
    raw_props: run.properties,
    resolved_char_props: resolved.char_props,
    style_name: resolved_style_name,
  }
}

///|
/// Find matching PAPX state with raw properties
fn find_papx_state_and_props(
  runs : Array[PapxRun],
  cp_start : Int,
  cp_end : Int,
  styles : StyleCollection,
  style_cache : Map[Int, ResolvedStyle],
) -> PapxResult {
  let mut best : PapxResult? = None
  let mut best_dist = 999999999
  for run in runs {
    if run.cp_start <= cp_end && run.cp_end >= cp_end {
      return resolve_papx_run(run, styles, style_cache)
    }
    if run.cp_start < cp_end && run.cp_end > cp_start {
      return resolve_papx_run(run, styles, style_cache)
    }
    let dist = if run.cp_start > cp_end {
      run.cp_start - cp_end
    } else {
      cp_end - run.cp_end
    }
    if dist < best_dist {
      best_dist = dist
      best = Some(resolve_papx_run(run, styles, style_cache))
    }
  }
  match best {
    Some(result) => result
    None =>
      PapxResult::{
        para_state: ParaState::{
          align: 0,
          indent_left: 0,
          indent_right: 0,
          indent_first: 0,
          space_before: 0,
          space_after: 0,
          line_spacing: 240,
          keep_with_next: false,
          keep_together: false,
          page_break_before: false,
          widow_control: true,
          tab_stops: [],
          style_id: 0,
          itap: 0,
          table_row_end: false,
          inner_table_cell: false,
          inner_table_row_end: false,
          in_table: false,
          dtap: 0,
          list_level: 0,
          list_id: 0,
          rtl_para: false,
          adjust_right: false,
          border_top: 0,
          border_left: 0,
          border_bottom: 0,
          border_right: 0,
          border_between: 0,
          border_bar: 0,
          shading: 0,
          frame_left: 0,
          frame_top: 0,
          frame_width: 0,
          frame_height: 0,
          frame_position: 0,
          frame_wrap: 0,
          spacing_before_auto: false,
          spacing_after_auto: false,
          distance_from_text_y: 0,
          distance_from_text_x: 0,
          locked: false,
          outline_level: 9,
        },
        raw_props: [],
        resolved_char_props: [],
        style_name: "",
      }
  }
}

///|
priv struct PapxResult {
  para_state : ParaState
  raw_props : Array[Byte]
  resolved_char_props : Array[DecodedProperty]
  style_name : String
}

///|
/// Shallow equality check for CharState (mirrors JS shallowEqual)
fn shallow_equal_char_state(a : CharState, b : CharState) -> Bool {
  a.bold == b.bold &&
  a.italic == b.italic &&
  a.underline == b.underline &&
  a.strike == b.strike &&
  a.double_strike == b.double_strike &&
  a.font_size == b.font_size &&
  a.font_family_id == b.font_family_id &&
  a.font_family == b.font_family &&
  a.color == b.color &&
  a.highlight == b.highlight &&
  a.superscript == b.superscript &&
  a.subscript == b.subscript &&
  a.hidden == b.hidden &&
  a.small_caps == b.small_caps &&
  a.caps == b.caps &&
  a.outline == b.outline &&
  a.shadow == b.shadow &&
  a.emboss == b.emboss &&
  a.imprint == b.imprint &&
  a.spacing == b.spacing &&
  a.position_half_points == b.position_half_points &&
  a.scale == b.scale &&
  a.picture_offset == b.picture_offset &&
  a.rtl == b.rtl &&
  a.bold_bi == b.bold_bi &&
  a.italic_bi == b.italic_bi &&
  a.char_style_id == b.char_style_id &&
  a.is_ole2 == b.is_ole2 &&
  a.is_data == b.is_data &&
  a.is_object == b.is_object
}

///|
/// Character segment with formatting state (mirrors JS segment object)
priv struct CharSegment {
  cp_start : Int
  text : String
  state : CharState
}

///|
/// Build character segments from CHPX runs (mirrors JS buildCharSegments)
fn build_char_segments(
  chpx_runs : Array[ChpxRun],
  para_text : String,
  para_cp_start : Int,
  para_cp_end : Int,
  base_char_props : Array[DecodedProperty],
  fonts : FontsCollection,
  _styles : StyleCollection,
  cursor : Int,
  style_cache : Map[Int, ResolvedStyle],
) -> (Array[CharSegment], Int) {
  let segments : Array[CharSegment] = Array::new()
  let text_len = String::length(para_text)
  // Cursor-based overlap collection — O(N+M) total across all paragraphs
  // Skip runs that ended before this paragraph starts
  let overlapping : Array[ChpxRun] = Array::new()
  let mut c = cursor
  while c < chpx_runs.length() && chpx_runs[c].cp_end <= para_cp_start {
    c += 1
  }
  // Collect runs that overlap this paragraph (runs may span multiple paragraphs)
  let mut ci = c
  while ci < chpx_runs.length() && chpx_runs[ci].cp_start < para_cp_end {
    if chpx_runs[ci].cp_end > para_cp_start {
      overlapping.push(chpx_runs[ci])
    }
    ci += 1
  }

  // Build boundary points
  let boundaries : Array[Int] = Array::new()
  boundaries.push(para_cp_start)
  boundaries.push(para_cp_end)
  for r in overlapping {
    let s = if r.cp_start > para_cp_start { r.cp_start } else { para_cp_start }
    let e = if r.cp_end < para_cp_end { r.cp_end } else { para_cp_end }
    if s > para_cp_start && s < para_cp_end {
      boundaries.push(s)
    }
    if e > para_cp_start && e < para_cp_end {
      boundaries.push(e)
    }
  }
  // Sort boundaries using insertion sort
  {
    let mut i = 1
    while i < boundaries.length() {
      let key = boundaries[i]
      let mut j = i - 1
      while j >= 0 && boundaries[j] > key {
        boundaries[j + 1] = boundaries[j]
        j -= 1
      }
      boundaries[j + 1] = key
      i += 1
    }
  }

  // Build segments from boundary pairs
  let mut bi = 0
  while bi < boundaries.length() - 1 {
    let seg_cp_start = boundaries[bi]
    let seg_cp_end = boundaries[bi + 1]
    if seg_cp_end > seg_cp_start {
      let offset = seg_cp_start - para_cp_start
      let len = seg_cp_end - seg_cp_start
      if offset >= 0 && offset + len <= text_len {
        let seg_text = para_text[offset:offset + len].to_owned()
        if seg_text.length() > 0 {
          // Find covering CHPX run
          let mut covering : ChpxRun? = None
          for r in overlapping {
            if r.cp_start <= seg_cp_start && r.cp_end >= seg_cp_end {
              covering = Some(r)
              break
            }
          }
          let direct_state = match covering {
            Some(r) => {
              let direct_decoded = r.properties
              // Resolve charStyleId if present (mirrors JS lines 228-229)
              let mut char_style_id = 0
              for prop in direct_decoded {
                if prop.name == "istd" {
                  char_style_id = prop.value
                }
              }
              let char_style_props = if char_style_id > 0 {
                let resolved = resolve_style_from_cache(
                  style_cache, char_style_id,
                )
                resolved.char_props
              } else {
                []
              }
              let all_char : Array[DecodedProperty] = Array::new()
              for p in base_char_props {
                all_char.push(p)
              }
              for p in char_style_props {
                all_char.push(p)
              }
              for p in direct_decoded {
                all_char.push(p)
              }
              char_props_from_decoded(all_char)
            }
            None =>
              if base_char_props.length() > 0 {
                char_props_from_decoded(base_char_props)
              } else {
                default_char_state()
              }
          }
          let resolved_font = resolve_font_name(direct_state, fonts)
          let final_state = CharState::{
            bold: direct_state.bold,
            italic: direct_state.italic,
            underline: direct_state.underline,
            strike: direct_state.strike,
            double_strike: direct_state.double_strike,
            font_size: direct_state.font_size,
            font_family_id: direct_state.font_family_id,
            font_family: resolved_font,
            color: direct_state.color,
            highlight: direct_state.highlight,
            superscript: direct_state.superscript,
            subscript: direct_state.subscript,
            hidden: direct_state.hidden,
            small_caps: direct_state.small_caps,
            caps: direct_state.caps,
            outline: direct_state.outline,
            shadow: direct_state.shadow,
            emboss: direct_state.emboss,
            imprint: direct_state.imprint,
            spacing: direct_state.spacing,
            position_half_points: direct_state.position_half_points,
            scale: direct_state.scale,
            picture_offset: direct_state.picture_offset,
            rtl: direct_state.rtl,
            bold_bi: direct_state.bold_bi,
            italic_bi: direct_state.italic_bi,
            char_style_id: direct_state.char_style_id,
            is_ole2: direct_state.is_ole2,
            is_data: direct_state.is_data,
            is_object: direct_state.is_object,
          }
          let last_idx = segments.length() - 1
          if last_idx >= 0 &&
            shallow_equal_char_state(segments[last_idx].state, final_state) {
            segments[last_idx] = CharSegment::{
              cp_start: segments[last_idx].cp_start,
              text: segments[last_idx].text + seg_text,
              state: final_state,
            }
          } else {
            segments.push(CharSegment::{
              cp_start: seg_cp_start,
              text: seg_text,
              state: final_state,
            })
          }
        }
      }
    }
    bi += 1
  }

  // Fallback: if no segments, create one from the full text
  if segments.length() == 0 && text_len > 0 {
    let state = if base_char_props.length() > 0 {
      char_props_from_decoded(base_char_props)
    } else {
      default_char_state()
    }
    let resolved_font = resolve_font_name(state, fonts)
    let final_state = CharState::{
      bold: state.bold,
      italic: state.italic,
      underline: state.underline,
      strike: state.strike,
      double_strike: state.double_strike,
      font_size: state.font_size,
      font_family_id: state.font_family_id,
      font_family: resolved_font,
      color: state.color,
      highlight: state.highlight,
      superscript: state.superscript,
      subscript: state.subscript,
      hidden: state.hidden,
      small_caps: state.small_caps,
      caps: state.caps,
      outline: state.outline,
      shadow: state.shadow,
      emboss: state.emboss,
      imprint: state.imprint,
      spacing: state.spacing,
      position_half_points: state.position_half_points,
      scale: state.scale,
      picture_offset: state.picture_offset,
      rtl: state.rtl,
      bold_bi: state.bold_bi,
      italic_bi: state.italic_bi,
      char_style_id: state.char_style_id,
      is_ole2: state.is_ole2,
      is_data: state.is_data,
      is_object: state.is_object,
    }
    segments.push(CharSegment::{
      cp_start: para_cp_start,
      text: para_text,
      state: final_state,
    })
  }

  (segments, c)
}

///|
/// Asset resolver for picture characters (mirrors JS createAssetResolver)
struct AssetResolver {
  data_bytes : FixedArray[Byte]
  object_pool : Map[String, Asset]
  assets : Array[Asset]
  asset_cache : Map[String, Asset?]
  used_names : Map[String, Unit]
  content_dedup : Map[String, Int]
}

///|
/// Compute content signature from asset bytes (first 32 bytes as hex)
fn compute_asset_signature(bytes : FixedArray[Byte]) -> String {
  let len = if bytes.length() < 32 { bytes.length() } else { 32 }
  let sb = StringBuilder::new()
  let hex_chars = "0123456789abcdef"
  let mut i = 0
  while i < len {
    let b = bytes[i].to_int()
    let hi = (b >> 4) & 0xF
    let lo = b & 0xF
    match hex_chars[hi].to_char() {
      Some(c) => sb <+ "\{c}"
      None => ()
    }
    match hex_chars[lo].to_char() {
      Some(c) => sb <+ "\{c}"
      None => ()
    }
    i += 1
  }
  sb.to_string()
}

///|
/// Look up object pool entry by picture offset (mirrors JS getObjectPoolInfo)
fn get_object_pool_info(
  object_pool : Map[String, Asset],
  picture_offset : Int,
) -> Asset? {
  let decimal_key = "_\{picture_offset.to_string()}"
  match object_pool.get(decimal_key) {
    Some(asset) => return Some(asset)
    None => ()
  }
  // Try hex lowercase
  let hex_lower = int_to_hex_lower(picture_offset)
  let hex_key = "_\{hex_lower}"
  match object_pool.get(hex_key) {
    Some(asset) => return Some(asset)
    None => ()
  }
  // Try hex uppercase
  let hex_upper = int_to_hex_upper(picture_offset)
  let hex_upper_key = "_\{hex_upper}"
  match object_pool.get(hex_upper_key) {
    Some(asset) => return Some(asset)
    None => ()
  }
  None
}

///|
/// Convert int to hex string (lowercase)
fn int_to_hex_lower(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let hex_chars = "0123456789abcdef"
  let sb = StringBuilder::new()
  let mut v = value
  while v > 0 {
    let digit = v & 0xF
    let c = hex_chars[digit].to_char()
    match c {
      Some(ch) => {
        let s = ch.to_string()
        sb <+ "\{s}"
      }
      None => ignore(digit)
    }
    v = v >> 4
  }
  // Reverse the string
  let result = sb.to_string()
  let len = String::length(result)
  let reversed = StringBuilder::new()
  let mut i = len - 1
  while i >= 0 {
    reversed <+ "\{result[i]}"
    i -= 1
  }
  reversed.to_string()
}

///|
/// Convert int to hex string (uppercase)
fn int_to_hex_upper(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let hex_chars = "0123456789ABCDEF"
  let sb = StringBuilder::new()
  let mut v = value
  while v > 0 {
    let digit = v & 0xF
    let c = hex_chars[digit].to_char()
    match c {
      Some(ch) => {
        let s = ch.to_string()
        sb <+ "\{s}"
      }
      None => ignore(digit)
    }
    v = v >> 4
  }
  let result = sb.to_string()
  let len = String::length(result)
  let reversed = StringBuilder::new()
  let mut i = len - 1
  while i >= 0 {
    reversed <+ "\{result[i]}"
    i -= 1
  }
  reversed.to_string()
}

///|
/// Resolve an asset from charState (mirrors JS resolveAsset)
fn resolve_asset_for_picture(
  resolver : AssetResolver,
  char_state : CharState,
) -> Asset? {
  let picture_offset = char_state.picture_offset
  if picture_offset <= 0 {
    return None
  }

  // Check cache
  let cache_key = picture_offset.to_string()
  let cached = resolver.asset_cache.get(cache_key)
  match cached {
    Some(v) => v
    None => {
      // Step 1: If OLE flags set, check ObjectPool for attachment (matches JS resolveAsset)
      let pool_asset = if char_state.is_ole2 ||
        char_state.is_data ||
        char_state.is_object {
        get_object_pool_info(resolver.object_pool, picture_offset)
      } else {
        None
      }

      // Step 2: If ObjectPool has attachment, use it (text boxes, embedded docs)
      match pool_asset {
        Some(pool) => {
          let asset = Asset::{
            id: pool.id,
            asset_type: "attachment",
            name: pool.name,
            mime: pool.mime,
            bytes: pool.bytes,
            data_url: pool.data_url,
            width: pool.width,
            height: pool.height,
          }
          resolver.assets.push(asset)
          resolver.asset_cache.set(cache_key, Some(asset))
          return Some(asset)
        }
        None => ()
      }

      // Step 3: No ObjectPool attachment — try Data stream extraction
      let raw_asset = if resolver.data_bytes.length() > 0 {
        extract_raw_image_asset(resolver.data_bytes, picture_offset)
      } else {
        None
      }

      // Step 4: Filter octet-stream (matches JS resolveAsset line 101)
      // JS: if (extracted && extracted.mime !== 'application/octet-stream') asset = extracted;
      let has_ole_flags = char_state.is_ole2 ||
        char_state.is_data ||
        char_state.is_object
      let result_asset = match raw_asset {
        Some(raw) =>
          if raw.mime == "application/octet-stream" {
            // Octet-stream: check ObjectPool for attachment (matches JS lines 104-106)
            match pool_asset {
              Some(pool) => {
                let asset = Asset::{
                  id: pool.id,
                  asset_type: "attachment",
                  name: pool.name,
                  mime: pool.mime,
                  bytes: pool.bytes,
                  data_url: pool.data_url,
                  width: pool.width,
                  height: pool.height,
                }
                Some(asset)
              }
              None =>
                // No ObjectPool attachment — use extracted as fallback (matches JS lines 108-110)
                Some(create_placeholder_asset(picture_offset))
            }
          } else if has_ole_flags && raw.mime == "application/octet-stream" {
            Some(create_placeholder_asset(picture_offset))
          } else {
            // Step 5: Content dedup — check if same image already extracted
            let sig = compute_asset_signature(raw.bytes)
            match resolver.content_dedup.get(sig) {
              Some(first_idx) => {
                // Same content already exists — create entry sharing same bytes
                let first_asset = resolver.assets[first_idx]
                Some(Asset::{
                  id: "asset-img-\{picture_offset.to_string()}",
                  asset_type: "image",
                  name: "image",
                  mime: first_asset.mime,
                  bytes: first_asset.bytes,
                  data_url: first_asset.data_url,
                  width: first_asset.width,
                  height: first_asset.height,
                })
              }
              None => {
                // New unique content — register signature
                let new_asset = Asset::{
                  id: "asset-img-\{picture_offset.to_string()}",
                  asset_type: "image",
                  name: "image",
                  mime: raw.mime,
                  bytes: raw.bytes,
                  data_url: create_loading_placeholder(
                    raw.mime,
                    raw.bytes.length(),
                  ),
                  width: 0,
                  height: 0,
                }
                resolver.content_dedup.set(sig, resolver.assets.length())
                Some(new_asset)
              }
            }
          }
        None =>
          // No extraction — check ObjectPool (matches JS lines 112-114)
          match pool_asset {
            Some(pool) => {
              let asset = Asset::{
                id: pool.id,
                asset_type: "attachment",
                name: pool.name,
                mime: pool.mime,
                bytes: pool.bytes,
                data_url: pool.data_url,
                width: pool.width,
                height: pool.height,
              }
              Some(asset)
            }
            None => Some(create_placeholder_asset(picture_offset))
          }
      }

      match result_asset {
        Some(asset) => {
          resolver.assets.push(asset)
          resolver.asset_cache.set(cache_key, Some(asset))
          Some(asset)
        }
        None => {
          resolver.asset_cache.set(cache_key, None)
          None
        }
      }
    }
  }
}

///|
/// Field context for inline field processing (mirrors JS buildInlineNodes)
priv struct InlineFieldCtx {
  instruction : StringBuilder
  parsed_href : String
  reading_instruction : Bool
  runs : Array[RenderRun]
}

///|
/// Convert CharState to a RenderRun with given text (avoids 35-field copy everywhere)
fn state_to_run(text : String, state : CharState, href : String) -> RenderRun {
  RenderRun::{
    text,
    bold: state.bold,
    italic: state.italic,
    underline: state.underline,
    strike: state.strike,
    double_strike: state.double_strike,
    font_size: state.font_size,
    font_family: state.font_family,
    color: state.color,
    highlight: state.highlight,
    superscript: state.superscript,
    subscript: state.subscript,
    href,
    bold_bi: state.bold_bi,
    italic_bi: state.italic_bi,
    small_caps: state.small_caps,
    caps: state.caps,
    outline: state.outline,
    shadow: state.shadow,
    emboss: state.emboss,
    imprint: state.imprint,
    scale: state.scale,
    position_half_points: state.position_half_points,
    rtl: state.rtl,
    is_line_break: false,
    is_page_break: false,
    is_image: false,
    image_data_url: "",
    image_width: 0,
    image_height: 0,
    is_attachment: false,
    attachment_name: "",
    form_field: None,
  asset_index: -1,
  }
}

///|
/// Check if segment text contains any control characters (0x00-0x1F)
fn has_control_chars(text : String) -> Bool {
  let len = String::length(text)
  let mut i = 0
  while i < len {
    let ch = text[i].to_int()
    if ch < 0x20 {
      return true
    }
    i += 1
  }
  false
}

///| Process segments, handling field markers inline

///| Fast path: segments without control chars → single RenderRun (O(1))

///|
/// Slow path: segments with control chars → per-character processing
fn process_inline_fields(
  segments : Array[CharSegment],
  resolver : AssetResolver,
) -> Array[RenderRun] {
  let output : Array[RenderRun] = Array::new()
  let field_stack : Array[InlineFieldCtx] = Array::new()

  for segment in segments {
    if segment.text.length() == 0 || segment.state.hidden {
      continue
    }

    // FAST PATH: no control characters → create a single RenderRun directly
    if !has_control_chars(segment.text) && field_stack.length() == 0 {
      output.push(state_to_run(segment.text, segment.state, ""))
      continue
    }

    // SLOW PATH: has control characters or inside a field → per-character processing
    let seg_text = segment.text
    let seg_len = String::length(seg_text)
    let mut ci = 0
    while ci < seg_len {
      let ch = seg_text[ci].to_int()

      // normalizePlainTextChar: normalize special control characters
      if ch == 0x1E {
        // nonBreakingHyphen → '-'
        let fixed_ch = 0x2D
        let fixed_char = match fixed_ch.to_char() {
          Some(c) => c
          None => {
            ci += 1
            continue
          }
        }
        let fixed_text = "\{fixed_char}"
        if field_stack.length() > 0 {
          let top_idx = field_stack.length() - 1
          let top = field_stack[top_idx]
          if top.runs.length() > 0 {
            let last_idx = top.runs.length() - 1
            let last = top.runs[last_idx]
            if !last.is_line_break &&
              !last.is_page_break &&
              !last.is_image &&
              !last.is_attachment &&
              last.href == "" {
              let merged_text = last.text + fixed_text
              top.runs[last_idx] = RenderRun::{
                text: merged_text,
                bold: last.bold,
                italic: last.italic,
                underline: last.underline,
                strike: last.strike,
                double_strike: last.double_strike,
                font_size: last.font_size,
                font_family: last.font_family,
                color: last.color,
                highlight: last.highlight,
                superscript: last.superscript,
                subscript: last.subscript,
                href: last.href,
                bold_bi: last.bold_bi,
                italic_bi: last.italic_bi,
                small_caps: last.small_caps,
                caps: last.caps,
                outline: last.outline,
                shadow: last.shadow,
                emboss: last.emboss,
                imprint: last.imprint,
                scale: last.scale,
                position_half_points: last.position_half_points,
                rtl: last.rtl,
                is_line_break: false,
                is_page_break: false,
                is_image: false,
                image_data_url: "",
                image_width: 0,
                image_height: 0,
                is_attachment: false,
                attachment_name: "",
                form_field: None,
              asset_index: -1,
              }
              ci += 1
              continue
            }
          }
          let new_run = RenderRun::{
            text: fixed_text,
            bold: segment.state.bold,
            italic: segment.state.italic,
            underline: segment.state.underline,
            strike: segment.state.strike,
            double_strike: segment.state.double_strike,
            font_size: segment.state.font_size,
            font_family: segment.state.font_family,
            color: segment.state.color,
            highlight: segment.state.highlight,
            superscript: segment.state.superscript,
            subscript: segment.state.subscript,
            href: "",
            bold_bi: segment.state.bold_bi,
            italic_bi: segment.state.italic_bi,
            small_caps: segment.state.small_caps,
            caps: segment.state.caps,
            outline: segment.state.outline,
            shadow: segment.state.shadow,
            emboss: segment.state.emboss,
            imprint: segment.state.imprint,
            scale: segment.state.scale,
            position_half_points: segment.state.position_half_points,
            rtl: segment.state.rtl,
            is_line_break: false,
            is_page_break: false,
            is_image: false,
            image_data_url: "",
            image_width: 0,
            image_height: 0,
            is_attachment: false,
            attachment_name: "",
            form_field: None,
          asset_index: -1,
          }
          field_stack[top_idx].runs.push(new_run)
        } else {
          if output.length() > 0 {
            let last_idx = output.length() - 1
            let last = output[last_idx]
            if !last.is_line_break &&
              !last.is_page_break &&
              !last.is_image &&
              !last.is_attachment &&
              last.href == "" {
              let merged_text = last.text + fixed_text
              output[last_idx] = RenderRun::{
                text: merged_text,
                bold: last.bold,
                italic: last.italic,
                underline: last.underline,
                strike: last.strike,
                double_strike: last.double_strike,
                font_size: last.font_size,
                font_family: last.font_family,
                color: last.color,
                highlight: last.highlight,
                superscript: last.superscript,
                subscript: last.subscript,
                href: last.href,
                bold_bi: last.bold_bi,
                italic_bi: last.italic_bi,
                small_caps: last.small_caps,
                caps: last.caps,
                outline: last.outline,
                shadow: last.shadow,
                emboss: last.emboss,
                imprint: last.imprint,
                scale: last.scale,
                position_half_points: last.position_half_points,
                rtl: last.rtl,
                is_line_break: false,
                is_page_break: false,
                is_image: false,
                image_data_url: "",
                image_width: 0,
                image_height: 0,
                is_attachment: false,
                attachment_name: "",
                form_field: None,
              asset_index: -1,
              }
              ci += 1
              continue
            }
          }
          output.push(RenderRun::{
            text: fixed_text,
            bold: segment.state.bold,
            italic: segment.state.italic,
            underline: segment.state.underline,
            strike: segment.state.strike,
            double_strike: segment.state.double_strike,
            font_size: segment.state.font_size,
            font_family: segment.state.font_family,
            color: segment.state.color,
            highlight: segment.state.highlight,
            superscript: segment.state.superscript,
            subscript: segment.state.subscript,
            href: "",
            bold_bi: segment.state.bold_bi,
            italic_bi: segment.state.italic_bi,
            small_caps: segment.state.small_caps,
            caps: segment.state.caps,
            outline: segment.state.outline,
            shadow: segment.state.shadow,
            emboss: segment.state.emboss,
            imprint: segment.state.imprint,
            scale: segment.state.scale,
            position_half_points: segment.state.position_half_points,
            rtl: segment.state.rtl,
            is_line_break: false,
            is_page_break: false,
            is_image: false,
            image_data_url: "",
            image_width: 0,
            image_height: 0,
            is_attachment: false,
            attachment_name: "",
            form_field: None,
          asset_index: -1,
          })
        }
        ci += 1
        continue
      }
      if ch == 0x1F || ch == 0x05 || ch == DOC_CONTROL_CELL_MARK {
        // nonRequiredHyphen, annotationRef, and cellMark → skip
        ci += 1
        continue
      }

      // fieldEnd (0x15) without matching fieldStart → skip
      if ch == 0x15 && field_stack.length() == 0 {
        ci += 1
        continue
      }

      // fieldStart (0x13): push new field context
      if ch == 0x13 {
        field_stack.push(InlineFieldCtx::{
          instruction: StringBuilder::new(),
          parsed_href: "",
          reading_instruction: true,
          runs: Array::new(),
        })
        ci += 1
        continue
      }

      // fieldSeparator (0x14): decode instruction
      if ch == 0x14 && field_stack.length() > 0 {
        let top_idx = field_stack.length() - 1
        let top = field_stack[top_idx]
        let instr_str = top.instruction.to_string()
        let instr_result = decode_field_instruction(instr_str)
        let is_hl = instr_result.instr_type == "hyperlink" &&
          instr_result.href.length() > 0
        // Detect form field types
        let _is_form_field = instr_result.instr_type == "formtext" ||
          instr_result.instr_type == "formcheckbox" ||
          instr_result.instr_type == "formdropdown"
        let _form_field_type = if instr_result.instr_type == "formtext" {
          "text"
        } else if instr_result.instr_type == "formcheckbox" {
          "checkbox"
        } else if instr_result.instr_type == "formdropdown" {
          "dropdown"
        } else {
          ""
        }
        field_stack[top_idx] = InlineFieldCtx::{
          instruction: top.instruction,
          parsed_href: if is_hl {
            instr_result.href
          } else {
            ""
          },
          reading_instruction: false,
          runs: top.runs,
        }
        ci += 1
        continue
      }

      // fieldEnd (0x15): pop field, apply href, emit to parent
      if ch == 0x15 && field_stack.length() > 0 {
        let current = match field_stack.pop() {
          Some(v) => v
          None => {
            ci += 1
            continue
          }
        }
        let effective_href = if current.reading_instruction {
          let instr_str = current.instruction.to_string()
          let instr_result = decode_field_instruction(instr_str)
          let is_hl = instr_result.instr_type == "hyperlink" &&
            instr_result.href.length() > 0
          if is_hl {
            instr_result.href
          } else {
            current.parsed_href
          }
        } else {
          current.parsed_href
        }
        // Apply href to all runs in this field if it's a hyperlink
        if effective_href.length() > 0 {
          let href = effective_href
          let mut ri = 0
          while ri < current.runs.length() {
            let old_run = current.runs[ri]
            if !old_run.is_line_break && !old_run.is_page_break {
              current.runs[ri] = RenderRun::{
                text: old_run.text,
                bold: old_run.bold,
                italic: old_run.italic,
                underline: old_run.underline,
                strike: old_run.strike,
                double_strike: old_run.double_strike,
                font_size: old_run.font_size,
                font_family: old_run.font_family,
                color: old_run.color,
                highlight: old_run.highlight,
                superscript: old_run.superscript,
                subscript: old_run.subscript,
                href,
                bold_bi: old_run.bold_bi,
                italic_bi: old_run.italic_bi,
                small_caps: old_run.small_caps,
                caps: old_run.caps,
                outline: old_run.outline,
                shadow: old_run.shadow,
                emboss: old_run.emboss,
                imprint: old_run.imprint,
                scale: old_run.scale,
                position_half_points: old_run.position_half_points,
                rtl: old_run.rtl,
                is_line_break: old_run.is_line_break,
                is_page_break: old_run.is_page_break,
                is_image: old_run.is_image,
                image_data_url: old_run.image_data_url,
                image_width: old_run.image_width,
                image_height: old_run.image_height,
                is_attachment: old_run.is_attachment,
                attachment_name: old_run.attachment_name,
                form_field: None,
              asset_index: -1,
              }
            }
            ri += 1
          }
        }
        // Apply form field data to runs if it's a form field
        let instr_for_form = if current.reading_instruction {
          let instr_str2 = current.instruction.to_string()
          let instr_result2 = decode_field_instruction(instr_str2)
          instr_result2.instr_type
        } else {
          let instr_str2 = current.instruction.to_string()
          let instr_result2 = decode_field_instruction(instr_str2)
          instr_result2.instr_type
        }
        if instr_for_form == "formtext" ||
          instr_for_form == "formcheckbox" ||
          instr_for_form == "formdropdown" {
          let ff_type = if instr_for_form == "formtext" {
            "text"
          } else if instr_for_form == "formcheckbox" {
            "checkbox"
          } else {
            "dropdown"
          }
          let ff = FormFieldData::{
            field_type: ff_type,
            name: "",
            default_value: "",
            checked: false,
            selected_index: 0,
            items: [],
          }
          let mut ri2 = 0
          while ri2 < current.runs.length() {
            let old_run = current.runs[ri2]
            current.runs[ri2] = RenderRun::{
              text: old_run.text,
              bold: old_run.bold,
              italic: old_run.italic,
              underline: old_run.underline,
              strike: old_run.strike,
              double_strike: old_run.double_strike,
              font_size: old_run.font_size,
              font_family: old_run.font_family,
              color: old_run.color,
              highlight: old_run.highlight,
              superscript: old_run.superscript,
              subscript: old_run.subscript,
              href: old_run.href,
              bold_bi: old_run.bold_bi,
              italic_bi: old_run.italic_bi,
              small_caps: old_run.small_caps,
              caps: old_run.caps,
              outline: old_run.outline,
              shadow: old_run.shadow,
              emboss: old_run.emboss,
              imprint: old_run.imprint,
              scale: old_run.scale,
              position_half_points: old_run.position_half_points,
              rtl: old_run.rtl,
              is_line_break: old_run.is_line_break,
              is_page_break: old_run.is_page_break,
              is_image: old_run.is_image,
              image_data_url: old_run.image_data_url,
              image_width: old_run.image_width,
              image_height: old_run.image_height,
              is_attachment: old_run.is_attachment,
              attachment_name: old_run.attachment_name,
              form_field: Some(ff),
            asset_index: -1,
            }
            ri2 += 1
          }
        }
        // Emit runs to parent (field stack or output)
        let mut ri = 0
        while ri < current.runs.length() {
          let run = current.runs[ri]
          if field_stack.length() > 0 {
            let parent_idx = field_stack.length() - 1
            field_stack[parent_idx].runs.push(run)
          } else {
            output.push(run)
          }
          ri += 1
        }
        ci += 1
        continue
      }

      // If inside a field reading instruction, accumulate char
      if field_stack.length() > 0 &&
        field_stack[field_stack.length() - 1].reading_instruction {
        let top_idx2 = field_stack.length() - 1
        let top2 = field_stack[top_idx2]
        let new_instruction = match ch.to_char() {
          Some(c) => {
            let sb = top2.instruction
            sb <+ "\{c}"
            sb
          }
          None => top2.instruction
        }
        field_stack[top_idx2] = InlineFieldCtx::{
          instruction: new_instruction,
          parsed_href: top2.parsed_href,
          reading_instruction: top2.reading_instruction,
          runs: top2.runs,
        }
        ci += 1
        continue
      }

      // hardLineBreak (0x0B): emit line break run
      if ch == 0x0B {
        let br_run = RenderRun::{
          text: "",
          bold: false,
          italic: false,
          underline: 0,
          strike: false,
          double_strike: false,
          font_size: segment.state.font_size,
          font_family: segment.state.font_family,
          color: 0,
          highlight: 0,
          superscript: false,
          subscript: false,
          href: "",
          bold_bi: false,
          italic_bi: false,
          small_caps: false,
          caps: false,
          outline: false,
          shadow: false,
          emboss: false,
          imprint: false,
          scale: 100,
          position_half_points: 0,
          rtl: false,
          is_line_break: true,
          is_page_break: false,
          is_image: false,
          image_data_url: "",
          image_width: 0,
          image_height: 0,
          is_attachment: false,
          attachment_name: "",
          form_field: None,
        asset_index: -1,
        }
        if field_stack.length() > 0 {
          let top_idx3 = field_stack.length() - 1
          let top3 = field_stack[top_idx3]
          let _new_len = top3.runs.length() + 1
          field_stack[top_idx3].runs.push(br_run)
        } else {
          output.push(br_run)
        }
        ci += 1
        continue
      }

      // pageBreak (0x0C): emit page break run
      if ch == 0x0C {
        let pb_run = RenderRun::{
          text: "",
          bold: false,
          italic: false,
          underline: 0,
          strike: false,
          double_strike: false,
          font_size: segment.state.font_size,
          font_family: segment.state.font_family,
          color: 0,
          highlight: 0,
          superscript: false,
          subscript: false,
          href: "",
          bold_bi: false,
          italic_bi: false,
          small_caps: false,
          caps: false,
          outline: false,
          shadow: false,
          emboss: false,
          imprint: false,
          scale: 100,
          position_half_points: 0,
          rtl: false,
          is_line_break: false,
          is_page_break: true,
          is_image: false,
          image_data_url: "",
          image_width: 0,
          image_height: 0,
          is_attachment: false,
          attachment_name: "",
          form_field: None,
        asset_index: -1,
        }
        if field_stack.length() > 0 {
          field_stack[field_stack.length() - 1].runs.push(pb_run)
        } else {
          output.push(pb_run)
        }
        ci += 1
        continue
      }

      // picture (0x01): resolve asset from object pool / Data stream
      if ch == DOC_CONTROL_PICTURE {
        let asset = resolve_asset_for_picture(resolver, segment.state)
        match asset {
          Some(a) => {
            // Find asset index in resolver.assets by id match
            let mut asset_idx = -1
            {
              let mut ai = resolver.assets.length() - 1
              while ai >= 0 {
                if resolver.assets[ai].id == a.id { asset_idx = ai; break }
                ai -= 1
              }
            }
            let img_run = RenderRun::{
              text: "",
              bold: segment.state.bold,
              italic: segment.state.italic,
              underline: segment.state.underline,
              strike: segment.state.strike,
              double_strike: segment.state.double_strike,
              font_size: segment.state.font_size,
              font_family: segment.state.font_family,
              color: segment.state.color,
              highlight: segment.state.highlight,
              superscript: segment.state.superscript,
              subscript: segment.state.subscript,
              href: "",
              bold_bi: segment.state.bold_bi,
              italic_bi: segment.state.italic_bi,
              small_caps: segment.state.small_caps,
              caps: segment.state.caps,
              outline: segment.state.outline,
              shadow: segment.state.shadow,
              emboss: segment.state.emboss,
              imprint: segment.state.imprint,
              scale: segment.state.scale,
              position_half_points: segment.state.position_half_points,
              rtl: segment.state.rtl,
              is_line_break: false,
              is_page_break: false,
              is_image: a.asset_type == "image",
              image_data_url: a.data_url,
              image_width: a.width,
              image_height: a.height,
              is_attachment: a.asset_type == "attachment",
              attachment_name: a.id,
              form_field: None,
              asset_index: asset_idx,
            }
            if field_stack.length() > 0 {
              field_stack[field_stack.length() - 1].runs.push(img_run)
            } else {
              output.push(img_run)
            }
          }
          None => ()
        }
        ci += 1
        continue
      }

      // Regular character: create or extend a text run
      let ch_char = match ch.to_char() {
        Some(c) => c
        None => {
          ci += 1
          continue
        }
      }
      let ch_text = "\{ch_char}"

      // Try to merge with last run in current target
      if field_stack.length() > 0 {
        let top_idx5 = field_stack.length() - 1
        let top5 = field_stack[top_idx5]
        if top5.runs.length() > 0 {
          let last_idx = top5.runs.length() - 1
          let last = top5.runs[last_idx]
          if !last.is_line_break &&
            !last.is_page_break &&
            !last.is_image &&
            !last.is_attachment &&
            last.href == "" &&
            last.bold == segment.state.bold &&
            last.italic == segment.state.italic &&
            last.underline == segment.state.underline &&
            last.strike == segment.state.strike &&
            last.double_strike == segment.state.double_strike &&
            last.font_size == segment.state.font_size &&
            last.font_family == segment.state.font_family &&
            last.color == segment.state.color &&
            last.highlight == segment.state.highlight &&
            last.superscript == segment.state.superscript &&
            last.subscript == segment.state.subscript &&
            last.bold_bi == segment.state.bold_bi &&
            last.italic_bi == segment.state.italic_bi &&
            last.small_caps == segment.state.small_caps &&
            last.caps == segment.state.caps &&
            last.outline == segment.state.outline &&
            last.shadow == segment.state.shadow &&
            last.emboss == segment.state.emboss &&
            last.imprint == segment.state.imprint &&
            last.scale == segment.state.scale &&
            last.position_half_points == segment.state.position_half_points &&
            last.rtl == segment.state.rtl {
            let merged_text = last.text + ch_text
            top5.runs[last_idx] = RenderRun::{
              text: merged_text,
              bold: last.bold,
              italic: last.italic,
              underline: last.underline,
              strike: last.strike,
              double_strike: last.double_strike,
              font_size: last.font_size,
              font_family: last.font_family,
              color: last.color,
              highlight: last.highlight,
              superscript: last.superscript,
              subscript: last.subscript,
              href: last.href,
              bold_bi: last.bold_bi,
              italic_bi: last.italic_bi,
              small_caps: last.small_caps,
              caps: last.caps,
              outline: last.outline,
              shadow: last.shadow,
              emboss: last.emboss,
              imprint: last.imprint,
              scale: last.scale,
              position_half_points: last.position_half_points,
              rtl: last.rtl,
              is_line_break: false,
              is_page_break: false,
              is_image: false,
              image_data_url: "",
              image_width: 0,
              image_height: 0,
              is_attachment: false,
              attachment_name: "",
              form_field: None,
            asset_index: -1,
            }
            ci += 1
            continue
          }
        }
        // Create new run in field context
        let new_run = state_to_run(ch_text, segment.state, "")
        field_stack[field_stack.length() - 1].runs.push(new_run)
      } else {
        // No field context: merge with last output run or create new
        if output.length() > 0 {
          let last_idx = output.length() - 1
          let last = output[last_idx]
          if !last.is_line_break &&
            !last.is_page_break &&
            !last.is_image &&
            !last.is_attachment &&
            last.href == "" &&
            last.bold == segment.state.bold &&
            last.italic == segment.state.italic &&
            last.underline == segment.state.underline &&
            last.strike == segment.state.strike &&
            last.double_strike == segment.state.double_strike &&
            last.font_size == segment.state.font_size &&
            last.font_family == segment.state.font_family &&
            last.color == segment.state.color &&
            last.highlight == segment.state.highlight &&
            last.superscript == segment.state.superscript &&
            last.subscript == segment.state.subscript &&
            last.bold_bi == segment.state.bold_bi &&
            last.italic_bi == segment.state.italic_bi &&
            last.small_caps == segment.state.small_caps &&
            last.caps == segment.state.caps &&
            last.outline == segment.state.outline &&
            last.shadow == segment.state.shadow &&
            last.emboss == segment.state.emboss &&
            last.imprint == segment.state.imprint &&
            last.scale == segment.state.scale &&
            last.position_half_points == segment.state.position_half_points &&
            last.rtl == segment.state.rtl {
            let merged_text = last.text + ch_text
            output[last_idx] = RenderRun::{
              text: merged_text,
              bold: last.bold,
              italic: last.italic,
              underline: last.underline,
              strike: last.strike,
              double_strike: last.double_strike,
              font_size: last.font_size,
              font_family: last.font_family,
              color: last.color,
              highlight: last.highlight,
              superscript: last.superscript,
              subscript: last.subscript,
              href: last.href,
              bold_bi: last.bold_bi,
              italic_bi: last.italic_bi,
              small_caps: last.small_caps,
              caps: last.caps,
              outline: last.outline,
              shadow: last.shadow,
              emboss: last.emboss,
              imprint: last.imprint,
              scale: last.scale,
              position_half_points: last.position_half_points,
              rtl: last.rtl,
              is_line_break: false,
              is_page_break: false,
              is_image: false,
              image_data_url: "",
              image_width: 0,
              image_height: 0,
              is_attachment: false,
              attachment_name: "",
              form_field: None,
            asset_index: -1,
            }
            ci += 1
            continue
          }
        }
        output.push(state_to_run(ch_text, segment.state, ""))
      }

      ci += 1
    }
  }

  // Drain remaining unclosed fields
  while field_stack.length() > 0 {
    let current = match field_stack.pop() {
      Some(v) => v
      None => break
    }
    let mut ri = 0
    while ri < current.runs.length() {
      let run = current.runs[ri]
      if field_stack.length() > 0 {
        field_stack[field_stack.length() - 1].runs.push(run)
      } else {
        output.push(run)
      }
      ri += 1
    }
  }

  output
}

///|
/// Merge adjacent runs with identical formatting (faithful port of JS mergeTextNode)
fn merge_adjacent_runs(runs : Array[RenderRun]) -> Array[RenderRun] {
  if runs.length() == 0 {
    return runs
  }
  let merged : Array[RenderRun] = Array::new()
  merged.push(runs[0])
  let mut ri = 1
  while ri < runs.length() {
    let prev = merged[merged.length() - 1]
    let curr = runs[ri]
    if curr.is_line_break ||
      curr.is_page_break ||
      prev.is_line_break ||
      prev.is_page_break {
      merged.push(curr)
    } else if !prev.is_image &&
      !curr.is_image &&
      !prev.is_attachment &&
      !curr.is_attachment &&
      prev.bold == curr.bold &&
      prev.italic == curr.italic &&
      prev.underline == curr.underline &&
      prev.strike == curr.strike &&
      prev.double_strike == curr.double_strike &&
      prev.font_size == curr.font_size &&
      prev.font_family == curr.font_family &&
      prev.color == curr.color &&
      prev.highlight == curr.highlight &&
      prev.superscript == curr.superscript &&
      prev.subscript == curr.subscript &&
      prev.href == curr.href &&
      prev.bold_bi == curr.bold_bi &&
      prev.italic_bi == curr.italic_bi &&
      prev.small_caps == curr.small_caps &&
      prev.caps == curr.caps &&
      prev.outline == curr.outline &&
      prev.shadow == curr.shadow &&
      prev.emboss == curr.emboss &&
      prev.imprint == curr.imprint &&
      prev.scale == curr.scale &&
      prev.position_half_points == curr.position_half_points &&
      prev.rtl == curr.rtl {
      merged[merged.length() - 1] = RenderRun::{
        text: prev.text + curr.text,
        bold: prev.bold,
        italic: prev.italic,
        underline: prev.underline,
        strike: prev.strike,
        double_strike: prev.double_strike,
        font_size: prev.font_size,
        font_family: prev.font_family,
        color: prev.color,
        highlight: prev.highlight,
        superscript: prev.superscript,
        subscript: prev.subscript,
        href: prev.href,
        bold_bi: prev.bold_bi,
        italic_bi: prev.italic_bi,
        small_caps: prev.small_caps,
        caps: prev.caps,
        outline: prev.outline,
        shadow: prev.shadow,
        emboss: prev.emboss,
        imprint: prev.imprint,
        scale: prev.scale,
        position_half_points: prev.position_half_points,
        rtl: prev.rtl,
        is_line_break: false,
        is_page_break: false,
        is_image: false,
        image_data_url: "",
        image_width: 0,
        image_height: 0,
        is_attachment: false,
        attachment_name: "",
        form_field: None,
      asset_index: -1,
      }
    } else {
      merged.push(curr)
    }
    ri += 1
  }
  merged
}
