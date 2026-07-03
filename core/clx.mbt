///| CLX / Piece Table parser for MS-DOC files

///| Piece in the piece table
pub struct Piece {
  index : Int
  compressed : Bool
  fc : Int
  cp_start : Int
  cp_end : Int
  actual_byte_start : Int
  byte_length : Int
  actual_byte_end : Int
}

///| Piece table
pub struct PieceTable {
  cps : Array[Int]
  pieces : Array[Piece]
}

///| CLX structure
pub struct CLX {
  pcdt_lcb : Int
  piece_table : PieceTable
}

fn cp1252_to_unicode(code : Int) -> Int {
  match code {
    0x82 => 0x201A
    0x83 => 0x0192
    0x84 => 0x201E
    0x85 => 0x2026
    0x86 => 0x2020
    0x87 => 0x2021
    0x88 => 0x02C6
    0x89 => 0x2030
    0x8A => 0x0160
    0x8B => 0x2039
    0x8C => 0x0152
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    0x98 => 0x02DC
    0x99 => 0x2122
    0x9A => 0x0161
    0x9B => 0x203A
    0x9C => 0x0153
    0x9F => 0x0178
    _ => code
  }
}

///| Decode compressed (Windows-1252) text from view (zero-copy)
fn decode_compressed_view(bytes : ArrayView[Byte]) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < bytes.length() {
    let code = cp1252_to_unicode(bytes[i].to_int())
    match code.to_char() {
      Some(c) => result <+ "\{c}"
      None => ignore(code)
    }
    i += 1
  }
  result.to_string()
}

///| Decode UTF-16LE text from view (zero-copy)
fn decode_unicode_view(bytes : ArrayView[Byte]) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i + 1 < bytes.length() {
    let lo = bytes[i].to_int()
    let hi = bytes[i + 1].to_int()
    let code = lo | (hi << 8)
    if code >= 0xD800 && code <= 0xDBFF && i + 3 < bytes.length() {
      let lo2 = bytes[i + 2].to_int()
      let hi2 = bytes[i + 3].to_int()
      let low_surrogate = lo2 | (hi2 << 8)
      if low_surrogate >= 0xDC00 && low_surrogate <= 0xDFFF {
        let supplementary = 0x10000 + ((code - 0xD800) << 10) + (low_surrogate - 0xDC00)
        match supplementary.to_char() {
          Some(c) => result <+ "\{c}"
          None => ignore(supplementary)
        }
        i += 4
        continue
      }
    }
    match code.to_char() {
      Some(c) => result <+ "\{c}"
      None => ignore(code)
    }
    i += 2
  }
  result.to_string()
}

///| Parse PlcPcd (piece table)
fn parse_plc_pcd(bytes : FixedArray[Byte]) -> PieceTable raise {
  if bytes.length() == 0 {
    raise CfbError("Empty PlcPcd")
  }
  let reader = BinaryReader::make(bytes)
  let pcd_count = (bytes.length() - 4) / 12

  // Read CP array
  let cps = Array::new()
  for i in 0..<(pcd_count + 1) {
    cps.push(reader.u32(i * 4))
  }

  // Read pieces
  let pieces = Array::new()
  let mut offset = (pcd_count + 1) * 4
  for i in 0..<pcd_count {
    let fc_raw = reader.u32(offset + 2)
    let compressed = (fc_raw & 0x40000000) != 0
    let fc = fc_raw & 0x3FFFFFFF
    let cp_start = if i < cps.length() { cps[i] } else { 0 }
    let cp_end = if i + 1 < cps.length() { cps[i + 1] } else { cp_start }
    let actual_byte_start = if compressed { fc / 2 } else { fc }
    let byte_length = if compressed { cp_end - cp_start } else { (cp_end - cp_start) * 2 }

    pieces.push(Piece::{
      index: i,
      compressed,
      fc,
      cp_start,
      cp_end,
      actual_byte_start,
      byte_length,
      actual_byte_end: actual_byte_start + byte_length,
    })
    offset += 8
  }

  PieceTable::{ cps, pieces }
}

///| Parse CLX structure
pub fn parse_clx(
  table_bytes : FixedArray[Byte],
  fc_clx : Int,
  lcb_clx : Int,
) -> CLX raise {
  if fc_clx < 0 || lcb_clx <= 0 || fc_clx + lcb_clx > table_bytes.length() {
    raise CfbError("FIB does not point to a valid CLX structure")
  }
  let clx_bytes = FixedArray::makei(lcb_clx, fn(i) { table_bytes[fc_clx + i] })
  let reader = BinaryReader::make(clx_bytes)

  // Find Pcdt marker
  let mut offset = 0
  while offset < clx_bytes.length() && reader.u8(offset) == 0x01 {
    let cb_grpprl = reader.u16(offset + 1)
    offset += 3 + cb_grpprl
  }

  if offset >= clx_bytes.length() || reader.u8(offset) != 0x02 {
    raise CfbError("CLX does not contain a Pcdt marker")
  }
  let lcb = reader.u32(offset + 1)
  let plc_pcd_bytes = FixedArray::makei(lcb, fn(i) { clx_bytes[offset + 5 + i] })
  let piece_table = parse_plc_pcd(plc_pcd_bytes)

  CLX::{
    pcdt_lcb: lcb,
    piece_table,
  }
}

///| Extract text from a piece (zero-copy via view)
pub fn extract_piece_text(
  word_bytes : FixedArray[Byte],
  piece : Piece,
) -> String {
  let view = word_bytes.view(start=piece.actual_byte_start, end=piece.actual_byte_end)
  if piece.compressed {
    decode_compressed_view(view)
  } else {
    decode_unicode_view(view)
  }
}

///| Build piece text cache
pub fn build_piece_text_cache(
  word_bytes : FixedArray[Byte],
  clx : CLX,
) -> Array[String] {
  let result = Array::new()
  for piece in clx.piece_table.pieces {
    result.push(extract_piece_text(word_bytes, piece))
  }
  result
}

///| Get text by character position range
pub fn get_text_by_cp(
  clx : CLX,
  piece_texts : Array[String],
  cp_start : Int,
  cp_end : Int,
) -> String {
  if cp_end <= cp_start {
    return ""
  }
  let result = StringBuilder::new()
  for i in 0..<clx.piece_table.pieces.length() {
    let piece = clx.piece_table.pieces[i]
    if piece.cp_end <= cp_start {
      continue
    }
    if piece.cp_start >= cp_end {
      break
    }
    let local_start = (if cp_start > piece.cp_start { cp_start } else { piece.cp_start }) - piece.cp_start
    let local_end = (if cp_end < piece.cp_end { cp_end } else { piece.cp_end }) - piece.cp_start
    if i < piece_texts.length() {
      let text = piece_texts[i]
      if local_start < text.length() && local_end <= text.length() {
        let s = text[local_start : local_end].to_owned()
        result <+ "\{s}"
      }
    }
  }
  result.to_string()
}

///| Split document text into paragraph ranges
pub fn split_paragraph_ranges(document_text : String) -> Array[(Int, Int, String)] {
  let ranges = Array::new()
  let mut start = 0
  let mut i = 0
  while i < String::length(document_text) {
    let ch = document_text[i]
    if ch == 0x0D || ch == 0x07 {
      let term = if ch == 0x0D { "\r" } else { "\u{0007}" }
      ranges.push((start, i + 1, term))
      start = i + 1
    }
    i += 1
  }
  if start < String::length(document_text) {
    ranges.push((start, String::length(document_text), ""))
  }
  ranges
}
