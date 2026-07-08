///| CLX / Piece Table parser for MS-DOC files

///|
/// Piece in the piece table
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

///|
/// Piece table
///|
/// CLX structure
pub struct CLX {
}

///|
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

///|
/// Optimized: uses write_char instead of string interpolation
fn decode_compressed_view(bytes : ArrayView[Byte]) -> String {
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b = bytes[i].to_int()
    let code = cp1252_to_unicode(b)
    match code.to_char() {
      Some(c) => sb.write_char(if c == '\r' { '\n' } else { c })
      None => ignore(code)
    }
    i += 1
  }
  sb.to_string()
}

///| Decode UTF-16LE text from view (zero-copy)

///|
/// Optimized: uses write_char instead of string interpolation
fn decode_unicode_view(bytes : ArrayView[Byte]) -> String {
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i + 1 < len {
    let lo = bytes[i].to_int()
    let hi = bytes[i + 1].to_int()
    let code = lo | (hi << 8)
    if code >= 0xD800 && code <= 0xDBFF && i + 3 < len {
      let lo2 = bytes[i + 2].to_int()
      let hi2 = bytes[i + 3].to_int()
      let low_surrogate = lo2 | (hi2 << 8)
      if low_surrogate >= 0xDC00 && low_surrogate <= 0xDFFF {
        let supplementary = 0x10000 +
          ((code - 0xD800) << 10) +
          (low_surrogate - 0xDC00)
        match supplementary.to_char() {
          Some(c) => sb.write_char(if c == '\r' { '\n' } else { c })
          None => ignore(code)
        }
        i += 4
        continue
      }
    }
    match code.to_char() {
      Some(c) => sb.write_char(if c == '\r' { '\n' } else { c })
      None => ignore(code)
    }
    i += 2
  }
  sb.to_string()
}

///|
/// Extract text from a piece (zero-copy via view)
pub fn extract_piece_text(
  word_bytes : FixedArray[Byte],
  piece : Piece,
) -> String {
  let view = word_bytes.view(
    start=piece.actual_byte_start,
    end=piece.actual_byte_end,
  )
  if piece.compressed {
    decode_compressed_view(view)
  } else {
    decode_unicode_view(view)
  }
}
