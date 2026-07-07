///| FKP (Formatted Key Page) reader for MS-DOC files

///|
/// CHPX run (character formatting)
pub struct ChpxRun {
  cp_start : Int
  cp_end : Int
  fc_start : Int
  fc_end : Int
  properties : Array[DecodedProperty]
}

///|
/// PAPX run (paragraph formatting)
pub struct PapxRun {
  cp_start : Int
  cp_end : Int
  fc_start : Int
  fc_end : Int
  style_id : Int
  properties : Array[Byte]
  raw_offset : Int
}

///|
/// Read CHPX properties from word bytes and decode
pub fn read_chpx_properties(
  word_bytes : FixedArray[Byte],
  offset : Int,
) -> Array[Byte] {
  if offset < 0 || offset >= word_bytes.length() {
    return []
  }
  let cb = word_bytes[offset].to_int()
  if cb == 0 {
    return []
  }
  let start = offset + 1
  let end = if start + cb < word_bytes.length() {
    start + cb
  } else {
    word_bytes.length()
  }
  let result = Array::new()
  let mut i = start
  while i < end {
    result.push(word_bytes[i])
    i += 1
  }
  result
}

///|
/// Read and decode CHPX properties directly
pub fn read_chpx_decoded(
  word_bytes : FixedArray[Byte],
  offset : Int,
) -> Array[DecodedProperty] {
  if offset < 0 || offset >= word_bytes.length() {
    return []
  }
  let cb = word_bytes[offset].to_int()
  if cb == 0 {
    return []
  }
  let start = offset + 1
  let end = if start + cb < word_bytes.length() {
    start + cb
  } else {
    word_bytes.length()
  }
  let view = word_bytes.view(start~, end~)
  decode_grpprl(view)
}

///|
/// Read PAPX properties from word bytes
pub fn read_papx_properties(
  word_bytes : FixedArray[Byte],
  offset : Int,
) -> (Int, Array[Byte]) {
  if offset < 0 || offset >= word_bytes.length() {
    return (0, [])
  }
  let reader = BinaryReader::make(word_bytes)
  let cb = reader.u8(offset)
  if cb == 0 && !reader.ensure(offset + 1, 1) {
    return (0, [])
  }
  let body_start = if cb == 0 { offset + 2 } else { offset + 1 }
  let body_size = if cb == 0 { reader.u8(offset + 1) * 2 } else { cb - 1 }
  let ensure_size = if body_size > 2 { body_size } else { 2 }
  if !reader.ensure(body_start, ensure_size) {
    return (0, [])
  }
  let style_id = reader.u16(body_start)
  let props_start = body_start + 2
  let props_end_raw = body_start + body_size
  let props_end = if props_end_raw < word_bytes.length() {
    props_end_raw
  } else {
    word_bytes.length()
  }
  let properties = Array::new()
  let mut i = props_start
  while i < props_end {
    properties.push(word_bytes[i])
    i += 1
  }
  (style_id, properties)
}

///|
/// Read CHPX runs
pub fn read_chpx_runs(
  word_bytes : FixedArray[Byte],
  table_bytes : FixedArray[Byte],
  fib : FIB,
  clx : CLX,
) -> Array[ChpxRun] {
  let fc = fib.fib_rg_fc_lcb.fc_plcf_bte_chpx
  let lcb = fib.fib_rg_fc_lcb.lcb_plcf_bte_chpx
  if fc < 0 || lcb <= 0 {
    return []
  }

  // Read PlcBte (zero-copy view)
  let bytes_view = table_bytes.view(start=fc, end=fc + lcb)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb - 4) / 8
  if count <= 0 {
    return []
  }

  let a_fc = Array::new()
  for i in 0..<(count + 1) {
    a_fc.push(reader.u32(i * 4))
  }

  let pages = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  // Read FKP pages
  let runs = Array::new()
  for pn in pages {
    let offset = pn * 512
    if offset + 512 > word_bytes.length() {
      continue
    }
    let page_view = word_bytes.view(start=offset, end=offset + 512)
    let page_reader = BinaryReader::from_view(page_view)
    let crun = page_reader.u8(511)
    if crun == 0 || crun > 100 {
      continue
    }

    let rgfc = Array::new()
    for i in 0..<(crun + 1) {
      rgfc.push(page_reader.u32(i * 4))
    }

    let rgb_start = (crun + 1) * 4
    for i in 0..<crun {
      let fc_start = rgfc[i]
      let fc_end = rgfc[i + 1]
      let b = page_reader.u8(rgb_start + i)
      let chpx_offset = if b > 0 { offset + b * 2 } else { 0 }
      let properties = if chpx_offset > 0 {
        read_chpx_decoded(word_bytes, chpx_offset)
      } else {
        []
      }

      // Simple CP mapping (without full fcToCp for now)
      let cp_start = fc_start
      let cp_end = fc_end

      runs.push(ChpxRun::{ cp_start, cp_end, fc_start, fc_end, properties })
    }
  }

  // Sort runs by cp_start using insertion sort (nearly-sorted data)
  let mut si = 1
  while si < runs.length() {
    let key = runs[si]
    let mut sj = si - 1
    while sj >= 0 && runs[sj].cp_start > key.cp_start {
      runs[sj + 1] = runs[sj]
      sj -= 1
    }
    runs[sj + 1] = key
    si += 1
  }

  runs
}

///|
/// Read PAPX runs
pub fn read_papx_runs(
  word_bytes : FixedArray[Byte],
  table_bytes : FixedArray[Byte],
  fib : FIB,
  clx : CLX,
) -> Array[PapxRun] {
  let fc = fib.fib_rg_fc_lcb.fc_plcf_bte_papx
  let lcb = fib.fib_rg_fc_lcb.lcb_plcf_bte_papx
  if fc < 0 || lcb <= 0 {
    return []
  }

  // Read PlcBte (zero-copy view)
  let bytes_view = table_bytes.view(start=fc, end=fc + lcb)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb - 4) / 8
  if count <= 0 {
    return []
  }

  let a_fc = Array::new()
  for i in 0..<(count + 1) {
    a_fc.push(reader.u32(i * 4))
  }

  let pages = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  // Read FKP pages
  let runs = Array::new()
  for pn in pages {
    let offset = pn * 512
    if offset + 512 > word_bytes.length() {
      continue
    }
    let page_view = word_bytes.view(start=offset, end=offset + 512)
    let page_reader = BinaryReader::from_view(page_view)
    let cpara = page_reader.u8(511)
    if cpara > 0x1D {
      continue
    }

    let rgfc = Array::new()
    for i in 0..<(cpara + 1) {
      rgfc.push(page_reader.u32(i * 4))
    }

    let bx_start = (cpara + 1) * 4
    for i in 0..<cpara {
      let fc_start = rgfc[i]
      let fc_end = rgfc[i + 1]
      let b_offset = page_reader.u8(bx_start + i * 13)
      let papx_offset = if b_offset > 0 { offset + b_offset * 2 } else { 0 }
      let (style_id, properties) = if papx_offset > 0 {
        read_papx_properties(word_bytes, papx_offset)
      } else {
        (0, [])
      }

      // Simple CP mapping (without full fcToCp for now)
      let cp_start = fc_start
      let cp_end = fc_end

      runs.push(PapxRun::{
        cp_start,
        cp_end,
        fc_start,
        fc_end,
        style_id,
        properties,
        raw_offset: papx_offset,
      })
    }
  }

  // Sort runs by cp_start using insertion sort (nearly-sorted data)
  let mut si = 1
  while si < runs.length() {
    let key = runs[si]
    let mut sj = si - 1
    while sj >= 0 && runs[sj].cp_start > key.cp_start {
      runs[sj + 1] = runs[sj]
      sj -= 1
    }
    runs[sj + 1] = key
    si += 1
  }

  runs
}
