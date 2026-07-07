///| FKP (Formatted Key Page) run reading

///| Extracted from parser.mbt for better organization

///|
/// Piece table entry for FC to CP mapping
pub struct PieceEntry {
  cp_start : Int
  cp_end : Int
  fc_start : Int
  fc_end : Int
  compressed : Bool
}

///| Convert FC to CP using piece table

///|
/// fc may be a raw FC value (with compressed bit 30 set) from FKP rgfc arrays
pub fn fc_to_cp(pieces : Array[PieceEntry], fc : Int) -> Int {
  let hinted_compressed = (fc & 0x40000000) != 0
  let fc_masked = fc & 0x3FFFFFFF
  let actual = if hinted_compressed { fc_masked / 2 } else { fc_masked }
  // Binary search for the piece containing this FC
  let mut lo = 0
  let mut hi = pieces.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    let p = pieces[mid]
    if actual < p.fc_start {
      hi = mid
    } else if actual > p.fc_end {
      lo = mid + 1
    } else {
      let offset = actual - p.fc_start
      let bytes_per_char = if p.compressed { 1 } else { 2 }
      let cp_offset = offset / bytes_per_char
      return p.cp_start + cp_offset
    }
  }
  // Not found fallback: try with raw value as actual byte offset
  let mut lo2 = 0
  let mut hi2 = pieces.length()
  while lo2 < hi2 {
    let mid = (lo2 + hi2) / 2
    let p = pieces[mid]
    if fc < p.fc_start {
      hi2 = mid
    } else if fc > p.fc_end {
      lo2 = mid + 1
    } else {
      let offset = fc - p.fc_start
      let bytes_per_char = if p.compressed { 1 } else { 2 }
      let cp_offset = offset / bytes_per_char
      return p.cp_start + cp_offset
    }
  }
  // Not found fallback: estimate
  if pieces.length() > 0 {
    let last = pieces[pieces.length() - 1]
    if actual >= last.fc_end {
      let offset = actual - last.fc_end
      let bytes_per_char = if last.compressed { 1 } else { 2 }
      return last.cp_end + offset / bytes_per_char
    }
  }
  fc / 2
}

///|
/// Simplified CHPX run reading
pub fn read_chpx_runs_fallback(
  word_bytes : FixedArray[Byte],
  table_bytes : FixedArray[Byte],
  main_story_end : Int,
  pieces : Array[PieceEntry],
) -> Array[ChpxRun] {
  let fib_reader = BinaryReader::make(word_bytes)
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  let fc_chpx = fib_reader.u32(fib_rgfc_lcb_start + 12 * 8)
  let lcb_chpx = fib_reader.u32(fib_rgfc_lcb_start + 12 * 8 + 4)
  if lcb_chpx <= 0 || fc_chpx < 0 {
    return []
  }

  let bytes_view = table_bytes.view(start=fc_chpx, end=fc_chpx + lcb_chpx)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb_chpx - 4) / 8
  if count <= 0 {
    return []
  }

  let pages : Array[Int] = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  let runs : Array[ChpxRun] = Array::new()
  for pn in pages {
    let offset : Int = pn * 512
    if offset + 512 > word_bytes.length() {
      continue
    }
    let page_reader = BinaryReader::from_view(
      word_bytes.view(start=offset, end=offset + 512),
    )
    let crun = page_reader.u8(511)
    if crun == 0 || crun > 200 {
      continue
    }

    let rgfc : Array[Int] = Array::new()
    for i in 0..<(crun + 1) {
      rgfc.push(page_reader.u32(i * 4))
    }

    let rgb_start = (crun + 1) * 4
    for i in 0..<crun {
      let fc_start = rgfc[i]
      let fc_end = rgfc[i + 1]
      let cp_start = fc_to_cp(pieces, fc_start)
      let cp_end = fc_to_cp(pieces, fc_end)
      if cp_start >= main_story_end {
        continue
      }
      let b = page_reader.u8(rgb_start + i)
      let chpx_offset = if b > 0 { offset + b * 2 } else { 0 }
      let properties = if chpx_offset > 0 {
        read_chpx_decoded(word_bytes, chpx_offset)
      } else {
        []
      }
      runs.push(ChpxRun::{
        cp_start,
        cp_end: if cp_end > main_story_end {
          main_story_end
        } else {
          cp_end
        },
        fc_start,
        fc_end,
        properties,
      })
    }
  }
  runs
}

///|
/// Simplified PAPX run reading
pub fn read_papx_runs_fallback(
  word_bytes : FixedArray[Byte],
  table_bytes : FixedArray[Byte],
  main_story_end : Int,
  pieces : Array[PieceEntry],
) -> Array[PapxRun] {
  let fib_reader = BinaryReader::make(word_bytes)
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  // PlcfBtePapx is entry 13 in FibRgFcLcb
  let fc_papx = fib_reader.u32(fib_rgfc_lcb_start + 13 * 8)
  let lcb_papx = fib_reader.u32(fib_rgfc_lcb_start + 13 * 8 + 4)
  if lcb_papx <= 0 || fc_papx < 0 {
    return []
  }

  let bytes_view = table_bytes.view(start=fc_papx, end=fc_papx + lcb_papx)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb_papx - 4) / 8
  if count <= 0 {
    return []
  }

  let pages : Array[Int] = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  // FKP pages are in the TABLE stream

  let runs : Array[PapxRun] = Array::new()
  for pn in pages {
    let offset : Int = pn * 512
    if offset + 512 > word_bytes.length() {
      continue
    }
    let page_reader = BinaryReader::from_view(
      word_bytes.view(start=offset, end=offset + 512),
    )
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
      let cp_start = fc_to_cp(pieces, fc_start)
      let cp_end = fc_to_cp(pieces, fc_end)
      if cp_start >= main_story_end {
        continue
      }
      let b_offset = page_reader.u8(bx_start + i * 13)
      let papx_offset = if b_offset > 0 { offset + b_offset * 2 } else { 0 }
      let (style_id, properties) = if papx_offset > 0 {
        read_papx_properties(word_bytes, papx_offset)
      } else {
        (0, [])
      }
      runs.push(PapxRun::{
        cp_start,
        cp_end: if cp_end > main_story_end {
          main_story_end
        } else {
          cp_end
        },
        fc_start,
        fc_end,
        style_id,
        properties,
        raw_offset: papx_offset,
      })
    }
  }
  runs
}
