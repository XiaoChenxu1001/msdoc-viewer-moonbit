///| Font Family Name (FFN) record
pub struct Font {
  index : Int
  cb_fn_m1 : Int
  ffid : Int
  weight : Int
  charset : Int
  ixch_sz_alt : Int
  panose : ArrayView[Byte]
  font_signature : ArrayView[Byte]
  name : String
  alt_name : String
}

///| STTBF_FFN header
pub struct FontsHeader {
  c_data : Int
  cb_extra : Int
}

///| Parsed fonts collection
pub struct FontsCollection {
  header : Option[FontsHeader]
  fonts : Array[Font]
}

///| Result of decode_utf16_z: string value and next read offset
pub struct Utf16ZResult {
  value : String
  next_offset : Int
}

///| Read a null-terminated UTF-16LE string starting at offset.
///| Returns the decoded string and the offset past the null terminator.
fn decode_utf16_z(bytes : FixedArray[Byte], offset : Int) -> Utf16ZResult {
  let mut end = offset
  while end + 1 < bytes.length() {
    if bytes[end] == 0 && bytes[end + 1] == 0 {
      break
    }
    end += 2
  }
  let byte_length = end - offset
  let reader = BinaryReader::make(bytes)
  let value = reader.utf16le(offset, byte_length)
  let next_offset = if end + 2 <= bytes.length() { end + 2 } else { bytes.length() }
  Utf16ZResult::{ value, next_offset }
}

///| Parse a single FFN (Font Family Name) record.
///| Returns null if record_bytes is empty.
fn parse_ffn(record_bytes : FixedArray[Byte], index : Int) -> Option[Font] {
  if record_bytes.length() == 0 {
    return None
  }
  let reader = BinaryReader::make(record_bytes)
  let cb_fn_m1 = reader.u8(0)
  let ffid = reader.u8(1)
  let weight = reader.u16(2)
  let charset = reader.u8(4)
  let ixch_sz_alt = reader.u8(5)
  let panose = reader.slice(6, 10)
  let font_signature = reader.slice(16, 24)
  let names_offset = 40
  let mut name = ""
  let mut alt_name = ""
  if record_bytes.length() > names_offset {
    let full_reader = BinaryReader::make(record_bytes)
    let full = full_reader.utf16z(names_offset, record_bytes.length() - names_offset)
    let parts = String::split(full, "\u{0000}")
    let non_empty = Array::new()
    for part in parts {
      if part.length() > 0 {
        non_empty.push(part.to_owned())
      }
    }
    if non_empty.length() > 0 {
      name = non_empty[0]
    }
    if non_empty.length() > 1 {
      alt_name = non_empty[1]
    }
    if String::length(alt_name) == 0 && ixch_sz_alt > 0 {
      let alt_offset = names_offset + ixch_sz_alt * 2
      if alt_offset + 2 <= record_bytes.length() {
        let result = decode_utf16_z(record_bytes, alt_offset)
        alt_name = result.value
      }
    }
  }
  Some(Font::{
    index,
    cb_fn_m1,
    ffid,
    weight,
    charset,
    ixch_sz_alt,
    panose,
    font_signature,
    name,
    alt_name,
  })
}

///| Parse STTBF_FFN from FIB.
///| table_bytes: the full Word document table bytes.
///| fib_rg_fc_lcb: the FIB FC/LCB table containing fc_sttbf_ffn and lcb_sttbf_ffn.
pub fn parse_fonts(
  table_bytes : FixedArray[Byte],
  fc_sttbf_ffn : Int,
  lcb_sttbf_ffn : Int,
) -> FontsCollection {
  if fc_sttbf_ffn < 0 || lcb_sttbf_ffn <= 0 || fc_sttbf_ffn + lcb_sttbf_ffn > table_bytes.length() {
    return FontsCollection::{
      header: None,
      fonts: [],
    }
  }
  let bytes = FixedArray::makei(
    lcb_sttbf_ffn,
    fn(i) { table_bytes[fc_sttbf_ffn + i] },
  )
  let reader = BinaryReader::make(bytes)
  let c_data = reader.u16(0)
  let cb_extra = reader.u16(2)
  let mut offset = 4
  let fonts = Array::new()
  let mut i = 0
  while i < c_data && offset < bytes.length() {
    let cb_fn_m1 = reader.u8(offset)
    let record_length = cb_fn_m1 + 1
    let actual_length = if offset + record_length <= bytes.length() {
      record_length
    } else {
      bytes.length() - offset
    }
    let record_bytes = FixedArray::makei(
      actual_length,
      fn(j) { bytes[offset + j] },
    )
    match parse_ffn(record_bytes, i) {
      Some(font) => fonts.push(font)
      None => ignore(i)
    }
    offset += record_length + cb_extra
    i += 1
  }
  FontsCollection::{
    header: Some(FontsHeader::{ c_data, cb_extra }),
    fonts,
  }
}

///| Look up a font by its index in the collection.
pub fn font_by_index(collection : FontsCollection, index : Int) -> Option[Font] {
  if index < 0 || index >= collection.fonts.length() {
    None
  } else {
    Some(collection.fonts[index])
  }
}

///| Parse fonts using raw FIB reader and FibRgFcLcb start offset
pub fn parse_fonts_from_fib(
  table_bytes : FixedArray[Byte],
  fib_reader : BinaryReader,
  fib_rgfc_lcb_start : Int,
) -> FontsCollection {
  // SttbfFfn is entry 15 in FibRgFcLcb
  let fc_sttbf_ffn = fib_reader.u32(fib_rgfc_lcb_start + 15 * 8)
  let lcb_sttbf_ffn = fib_reader.u32(fib_rgfc_lcb_start + 15 * 8 + 4)
  if fc_sttbf_ffn < 0 || lcb_sttbf_ffn <= 0 || fc_sttbf_ffn + lcb_sttbf_ffn > table_bytes.length() {
    return FontsCollection::{
      header: None,
      fonts: [],
    }
  }
  parse_fonts(table_bytes, fc_sttbf_ffn, lcb_sttbf_ffn)
}
