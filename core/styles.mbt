///| Style definitions parser for MS-DOC files

///| Style STDF base (10-byte header per style)
struct StdfBase {
  stk : Int
  istd_base : Int
  cupx : Int
  istd_next : Int
}

///| STSHF header
struct StyleHeader {
  cb_stshi : Int
  cstd : Int
  cb_std_base_in_file : Int
  ftc_asci : Int
  ftc_fe : Int
  ftc_other : Int
}

///| Style definition
pub struct StyleDefinition {
  istd : Int
  name : String
  base_style : Int
  next_style : Int
  stk : Int
  cupx : Int
  para_properties : Array[DecodedProperty]
  char_properties : Array[DecodedProperty]
  table_properties : Array[DecodedProperty]
}

///| Style collection
pub struct StyleCollection {
  styles : Array[StyleDefinition]
  style_map : Map[Int, Int]
  count : Int
  header : Option[StyleHeader]
}

///| Resolved style (with merged properties from base styles)
pub struct ResolvedStyle {
  style_ids : Array[Int]
  para_props : Array[DecodedProperty]
  char_props : Array[DecodedProperty]
  table_props : Array[DecodedProperty]
}

///| Merge multiple property arrays, deduplicating by kind:name (last wins)
pub fn merge_property_arrays(arrays : Array[Array[DecodedProperty]]) -> Array[DecodedProperty] {
  let all = Array::new()
  for array in arrays {
    for prop in array {
      all.push(prop)
    }
  }
  // Use Map for O(1) dedup lookup instead of O(n) scan
  let seen = Map([], capacity=16)
  let result : Array[DecodedProperty] = Array::new()
  let mut i = all.length()
  while i > 0 {
    i -= 1
    let k = all[i].kind + ":" + all[i].name
    if !seen.contains(k) {
      seen.set(k, true)
      result.push(all[i])
    }
  }
  result
}

///| Split properties by kind - returns (para, char, table)
pub fn split_properties_by_kind(properties : Array[DecodedProperty]) -> (Array[DecodedProperty], Array[DecodedProperty], Array[DecodedProperty]) {
  let para = Array::new()
  let char = Array::new()
  let table = Array::new()
  for prop in properties {
    match prop.kind {
      "para" => para.push(prop)
      "char" => char.push(prop)
      "table" => table.push(prop)
      _ => ignore(prop)
    }
  }
  (para, char, table)
}

///| Parse Xstz string: u16 length, UTF-16LE chars, null terminator
fn parse_xstz(bytes : ArrayView[Byte], offset : Int) -> (String, Int) {
  if offset + 2 > bytes.length() {
    return ("", offset)
  }
  let reader = BinaryReader::from_view(bytes)
  let cch = reader.u16(offset)
  let chars_offset = offset + 2
  let byte_length = cch * 2
  let text = reader.utf16le(chars_offset, byte_length)
  let end = chars_offset + byte_length + 2
  (text, end)
}

///| Parse STDF base (10 bytes)
fn parse_stdf_base(bytes : ArrayView[Byte], offset : Int) -> StdfBase {
  let reader = BinaryReader::from_view(bytes)
  let w1 = reader.u16(offset)
  let w2 = reader.u16(offset + 2)
  let w3 = reader.u16(offset + 4)
  ignore(reader.u16(offset + 6))
  ignore(reader.u16(offset + 8))
  StdfBase::{
    stk: w2 & 0x000f,
    istd_base: w2 >> 4 & 0x0fff,
    cupx: w3 & 0x000f,
    istd_next: w3 >> 4 & 0x0fff,
  }
}

///| Parse PAPX UPX: 2-byte length, then 2-byte styleId + grpprl
///| Returns (cbUpx, styleId, properties, nextOffset)
fn parse_lp_upx_papx(bytes : ArrayView[Byte], offset : Int) -> (Int, Int, Array[DecodedProperty], Int) {
  let reader = BinaryReader::from_view(bytes)
  let cb_upx = reader.u16(offset)
  let start = offset + 2
  let end = start + cb_upx
  let safe_end = if end < bytes.length() { end } else { bytes.length() }
  let style_id = if safe_end >= start + 2 { reader.u16(start) } else { 0 }
  let properties = if safe_end > start + 2 {
    let grpprl_len = safe_end - start - 2
    let grpprl_view = bytes.view(start=start + 2, end=safe_end)
    decode_grpprl(grpprl_view)
  } else {
    []
  }
  let aligned = if safe_end % 2 == 0 { safe_end } else { safe_end + 1 }
  (cb_upx, style_id, properties, aligned)
}

///| Parse CHPX UPX: 2-byte length, then grpprl
///| Returns (cbUpx, properties, nextOffset)
fn parse_lp_upx_chpx(bytes : ArrayView[Byte], offset : Int) -> (Int, Array[DecodedProperty], Int) {
  let reader = BinaryReader::from_view(bytes)
  let cb_upx = reader.u16(offset)
  let start = offset + 2
  let end = start + cb_upx
  let safe_end = if end < bytes.length() { end } else { bytes.length() }
  let properties = if safe_end > start {
    let grpprl_view = bytes.view(start=start, end=safe_end)
    decode_grpprl(grpprl_view)
  } else {
    []
  }
  let aligned = if safe_end % 2 == 0 { safe_end } else { safe_end + 1 }
  (cb_upx, properties, aligned)
}

///| Parse TAPX UPX: same as CHPX
fn parse_lp_upx_tapx(bytes : ArrayView[Byte], offset : Int) -> (Int, Array[DecodedProperty], Int) {
  parse_lp_upx_chpx(bytes, offset)
}

///| Parse a single STD (Style Description)
fn parse_style_std(std_bytes : ArrayView[Byte], cb_std_base_in_file : Int, istd : Int) -> StyleDefinition {
  if std_bytes.length() == 0 {
    return StyleDefinition::{
      istd, name: "", base_style: 0x0fff, next_style: 0, stk: 1, cupx: 0,
      para_properties: [], char_properties: [], table_properties: [],
    }
  }
  let base_size = if cb_std_base_in_file > 0 { cb_std_base_in_file } else { 10 }
  let base_size = if base_size < 10 { 10 } else if base_size > std_bytes.length() { std_bytes.length() } else { base_size }
  let stdf_base = parse_stdf_base(std_bytes, 0)
  let mut offset = base_size
  let (name, name_end) = parse_xstz(std_bytes, offset)
  offset = name_end
  let mut para_props : Array[DecodedProperty] = []
  let mut char_props : Array[DecodedProperty] = []
  let mut table_props : Array[DecodedProperty] = []
  // stk=1: paragraph style (papx, chpx); stk=2: character style (chpx); stk=3: table style (tapx, papx, chpx)
  if stdf_base.stk == 1 {
    if stdf_base.cupx >= 1 && offset + 2 <= std_bytes.length() {
      let (_, _, props, next_off) = parse_lp_upx_papx(std_bytes, offset)
      para_props = props
      offset = next_off
    }
    if stdf_base.cupx >= 2 && offset + 2 <= std_bytes.length() {
      let (_, props, _) = parse_lp_upx_chpx(std_bytes, offset)
      char_props = props
    }
  } else if stdf_base.stk == 2 {
    if offset + 2 <= std_bytes.length() {
      let (_, props, _) = parse_lp_upx_chpx(std_bytes, offset)
      char_props = props
    }
  } else if stdf_base.stk == 3 {
    if stdf_base.cupx >= 1 && offset + 2 <= std_bytes.length() {
      let (_, props, next_off) = parse_lp_upx_tapx(std_bytes, offset)
      table_props = props
      offset = next_off
    }
    if stdf_base.cupx >= 2 && offset + 2 <= std_bytes.length() {
      let (_, _, props, next_off) = parse_lp_upx_papx(std_bytes, offset)
      para_props = props
      offset = next_off
    }
    if stdf_base.cupx >= 3 && offset + 2 <= std_bytes.length() {
      let (_, props, _) = parse_lp_upx_chpx(std_bytes, offset)
      char_props = props
    }
  }
  StyleDefinition::{
    istd, name, base_style: stdf_base.istd_base, next_style: stdf_base.istd_next,
    stk: stdf_base.stk, cupx: stdf_base.cupx,
    para_properties: para_props, char_properties: char_props, table_properties: table_props,
  }
}

///| Parse style definitions from STSHF bytes
pub fn parse_styles(
  stshf_bytes : ArrayView[Byte],
) -> StyleCollection {
  let styles = Array::new()
  if stshf_bytes.length() == 0 {
    return StyleCollection::{ styles, style_map: Map([], capacity=16), count: 0, header: None }
  }
  let reader = BinaryReader::from_view(stshf_bytes)
  let cb_stshi = reader.u16(0)
  let stshi_offset = 2
  if stshi_offset + cb_stshi > stshf_bytes.length() {
    return StyleCollection::{ styles, style_map: Map([], capacity=16), count: 0, header: None }
  }
  let cstd = reader.u16(stshi_offset)
  let cb_std_base_in_file = reader.u16(stshi_offset + 2)
  let ftc_asci = reader.u16(stshi_offset + 10)
  let ftc_fe = reader.u16(stshi_offset + 12)
  let ftc_other = reader.u16(stshi_offset + 14)
  let header = StyleHeader::{
    cb_stshi, cstd, cb_std_base_in_file, ftc_asci, ftc_fe, ftc_other,
  }
  let mut offset = 2 + cb_stshi
  for i in 0..<cstd {
    if offset + 2 > stshf_bytes.length() {
      break
    }
    let cb_std = reader.u16(offset)
    let std_start = offset + 2
    let std_end = std_start + cb_std
    if cb_std == 0 {
      styles.push(StyleDefinition::{
        istd: i, name: "", base_style: 0x0fff, next_style: 0, stk: 1, cupx: 0,
        para_properties: [], char_properties: [], table_properties: [],
      })
      let aligned_end = align_even(std_end)
      offset = aligned_end
      continue
    }
    let safe_end = if std_end < stshf_bytes.length() { std_end } else { stshf_bytes.length() }
    let std_view = stshf_bytes.view(start=std_start, end=safe_end)
    let style = parse_style_std(std_view, cb_std_base_in_file, i)
    // Debug: encode info in name for istd=0
    if i == 0 && style.name.length() == 0 {
      // Store debug info - the name being empty indicates parse_xstz failed
    }
    styles.push(style)
    offset = align_even(std_end)
  }
  let style_map = Map([], capacity=16)
  for i in 0..<styles.length() {
    style_map.set(styles[i].istd, i)
  }
  StyleCollection::{ styles, style_map, count: styles.length(), header: Some(header) }
}

///| Resolve a style by istd, merging base style properties recursively
pub fn resolve_style(style_map : StyleCollection, istd : Int) -> ResolvedStyle {
  let seen : Array[Bool] = Array::new()
  let result = resolve_style_inner(style_map, istd, seen)
  result
}

///| Pre-resolve all unique styles into a cache
pub fn pre_resolve_all_styles(style_map : StyleCollection) -> Map[Int, ResolvedStyle] {
  let cache : Map[Int, ResolvedStyle] = Map([], capacity=16)
  for style in style_map.styles {
    let istd = style.istd
    if !cache.contains(istd) {
      cache.set(istd, resolve_style(style_map, istd))
    }
  }
  cache
}

///| Resolve style from cache (O(1) lookup)
pub fn resolve_style_from_cache(cache : Map[Int, ResolvedStyle], istd : Int) -> ResolvedStyle {
  match cache.get(istd) {
    Some(cached) => cached
    None => ResolvedStyle::{
      style_ids: [], para_props: [], char_props: [], table_props: [],
    }
  }
}

///| Internal recursive style resolver with cycle detection
fn resolve_style_inner(style_map : StyleCollection, istd : Int, seen : Array[Bool]) -> ResolvedStyle {
  if istd < 0 || istd == 0x0fff {
    return ResolvedStyle::{
      style_ids: [], para_props: [], char_props: [], table_props: [],
    }
  }
  // Extend seen array if needed
  while seen.length() <= istd {
    seen.push(false)
  }
  if seen[istd] {
    return ResolvedStyle::{
      style_ids: [], para_props: [], char_props: [], table_props: [],
    }
  }
  let style_opt = get_style(style_map, istd)
  let current_style = match style_opt {
    Some(s) => s
    None => {
      return ResolvedStyle::{
        style_ids: [], para_props: [], char_props: [], table_props: [],
      }
    }
  }
  let is_empty = current_style.name == "" && current_style.base_style == 0x0fff && current_style.para_properties.length() == 0 && current_style.char_properties.length() == 0 && current_style.table_properties.length() == 0
  if is_empty {
    return ResolvedStyle::{
      style_ids: [], para_props: [], char_props: [], table_props: [],
    }
  }
  seen[istd] = true
  let base_resolved = resolve_style_inner(style_map, current_style.base_style, seen)
  let merged_para = Array::new()
  for p in base_resolved.para_props {
    merged_para.push(p)
  }
  for p in current_style.para_properties {
    merged_para.push(p)
  }
  let merged_char = Array::new()
  for p in base_resolved.char_props {
    merged_char.push(p)
  }
  for p in current_style.char_properties {
    merged_char.push(p)
  }
  let merged_table = Array::new()
  for p in base_resolved.table_props {
    merged_table.push(p)
  }
  for p in current_style.table_properties {
    merged_table.push(p)
  }
  let all_ids = Array::new()
  for id in base_resolved.style_ids {
    all_ids.push(id)
  }
  all_ids.push(istd)
  ResolvedStyle::{
    style_ids: all_ids,
    para_props: merge_property_arrays([merged_para]),
    char_props: merge_property_arrays([merged_char]),
    table_props: merge_property_arrays([merged_table]),
  }
}

///| Get style by istd (O(1) via Map lookup)
pub fn get_style(collection : StyleCollection, istd : Int) -> Option[StyleDefinition] {
  match collection.style_map.get(istd) {
    Some(idx) => {
      if idx >= 0 && idx < collection.styles.length() {
        Some(collection.styles[idx])
      } else {
        None
      }
    }
    None => None
  }
}

///| Get style by name
pub fn get_style_by_name(collection : StyleCollection, name : String) -> Option[StyleDefinition] {
  for style in collection.styles {
    if style.name == name {
      return Some(style)
    }
  }
  None
}
