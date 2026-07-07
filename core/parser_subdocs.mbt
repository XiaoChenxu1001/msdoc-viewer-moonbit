///| Subdocument text extraction

///| Extracted from parser.mbt for better organization

///| Provides generic text extraction for all subdocument types

///| Batch extract all subdocument texts in a single pass over the piece table.

///|
/// Returns (textbox, header_textbox, header, footnote, endnote, comment) texts.
pub fn extract_all_subdocuments(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
  ccp_atn : Int,
  ccp_edn : Int,
  ccp_txbx : Int,
  ccp_hdr_txbx : Int,
) -> (String, String, String, String, String, String) {
  // Build contiguous CP ranges for each subdoc type
  let base = main_story_end
  let ranges : Array[(Int, Int)] = [
    (
      base + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn,
      base + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn + ccp_txbx,
    ),
    (
      base + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn + ccp_txbx,
      base + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn + ccp_txbx + ccp_hdr_txbx,
    ),
    (base + ccp_ftn, base + ccp_ftn + ccp_hdd),
    (base, base + ccp_ftn),
    (
      base + ccp_ftn + ccp_hdd + ccp_atn,
      base + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn,
    ),
    (base + ccp_ftn + ccp_hdd, base + ccp_ftn + ccp_hdd + ccp_atn),
  ]
  let active : Array[Bool] = [
    ccp_txbx > 0,
    ccp_hdr_txbx > 0,
    ccp_hdd > 0,
    ccp_ftn > 0,
    ccp_edn > 0,
    ccp_atn > 0,
  ]
  let sbs : Array[StringBuilder] = [
    StringBuilder::new(),
    StringBuilder::new(),
    StringBuilder::new(),
    StringBuilder::new(),
    StringBuilder::new(),
    StringBuilder::new(),
  ]

  // Single pass: for each piece, check overlap with each active range
  let mut piece_offset = (pcd_count + 1) * 4
  for i in 0..<pcd_count {
    let cp_s = cps[i]
    let cp_e = cps[i + 1]
    let fc_raw = plc_reader.u32(piece_offset + 2)
    let compressed = (fc_raw & 0x40000000) != 0
    let fc = fc_raw & 0x3FFFFFFF
    let mut ri = 0
    while ri < 6 {
      if active[ri] {
        let (r_start, r_end) = ranges[ri]
        if cp_s < r_end && cp_e > r_start {
          let overlap_start = if cp_s > r_start { cp_s } else { r_start }
          let overlap_end = if cp_e < r_end { cp_e } else { r_end }
          let cp_offset_in_piece = overlap_start - cp_s
          let actual_byte_start = if compressed {
            fc / 2 + cp_offset_in_piece
          } else {
            fc + cp_offset_in_piece * 2
          }
          let byte_length = if compressed {
            overlap_end - overlap_start
          } else {
            (overlap_end - overlap_start) * 2
          }
          let piece = Piece::{
            index: i,
            compressed,
            fc,
            cp_start: overlap_start,
            cp_end: overlap_end,
            actual_byte_start,
            byte_length,
            actual_byte_end: actual_byte_start + byte_length,
          }
          let piece_text = extract_piece_text(word_bytes, piece)
          sbs[ri].write_string(piece_text)
        }
      }
      ri += 1
    }
    piece_offset += 8
  }
  (
    sbs[0].to_string(),
    sbs[1].to_string(),
    sbs[2].to_string(),
    sbs[3].to_string(),
    sbs[4].to_string(),
    sbs[5].to_string(),
  )
}

///| Generic subdocument text extraction from piece table

///|
/// Extracts text from CP range [cp_start, cp_end) using piece table overlap detection
pub fn extract_subdocument_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  cp_start : Int,
  cp_end : Int,
) -> String {
  let sb = StringBuilder::new()
  let mut piece_offset = (pcd_count + 1) * 4
  for i in 0..<pcd_count {
    let cp_s = cps[i]
    let cp_e = cps[i + 1]
    // Check if piece overlaps with subdocument range
    if cp_s < cp_end && cp_e > cp_start {
      let overlap_start = if cp_s > cp_start { cp_s } else { cp_start }
      let overlap_end = if cp_e < cp_end { cp_e } else { cp_end }
      let fc_raw = plc_reader.u32(piece_offset + 2)
      let compressed = (fc_raw & 0x40000000) != 0
      let fc = fc_raw & 0x3FFFFFFF
      // Calculate byte offsets for the overlap range
      let cp_offset_in_piece = overlap_start - cp_s
      let actual_byte_start = if compressed {
        fc / 2 + cp_offset_in_piece
      } else {
        fc + cp_offset_in_piece * 2
      }
      let byte_length = if compressed {
        overlap_end - overlap_start
      } else {
        (overlap_end - overlap_start) * 2
      }
      let piece = Piece::{
        index: i,
        compressed,
        fc,
        cp_start: overlap_start,
        cp_end: overlap_end,
        actual_byte_start,
        byte_length,
        actual_byte_end: actual_byte_start + byte_length,
      }
      let piece_text = extract_piece_text(word_bytes, piece)
      sb.write_string(piece_text)
    }
    piece_offset += 8
  }
  sb.to_string()
}

///|
/// Extract footer subdocument text
pub fn extract_footnote_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
) -> String {
  if ccp_ftn <= 0 {
    return ""
  }
  let cp_start = main_story_end
  let cp_end = cp_start + ccp_ftn
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}

///|
/// Extract header/footer subdocument text
pub fn extract_header_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
) -> String {
  if ccp_hdd <= 0 {
    return ""
  }
  let cp_start = main_story_end + ccp_ftn
  let cp_end = cp_start + ccp_hdd
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}

///|
/// Extract endnote subdocument text
pub fn extract_endnote_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
  ccp_atn : Int,
  ccp_edn : Int,
) -> String {
  if ccp_edn <= 0 {
    return ""
  }
  let cp_start = main_story_end + ccp_ftn + ccp_hdd + ccp_atn
  let cp_end = cp_start + ccp_edn
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}

///|
/// Extract textbox subdocument text
pub fn extract_textbox_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
  ccp_atn : Int,
  ccp_edn : Int,
  ccp_txbx : Int,
) -> String {
  if ccp_txbx <= 0 {
    return ""
  }
  let cp_start = main_story_end + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn
  let cp_end = cp_start + ccp_txbx
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}

///| Extract header textbox subdocument text

///|
/// Header textboxes live after all other subdocuments including regular textboxes
pub fn extract_header_textbox_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
  ccp_atn : Int,
  ccp_edn : Int,
  ccp_txbx : Int,
  ccp_hdr_txbx : Int,
) -> String {
  if ccp_hdr_txbx <= 0 {
    return ""
  }
  let cp_start = main_story_end +
    ccp_ftn +
    ccp_hdd +
    ccp_atn +
    ccp_edn +
    ccp_txbx
  let cp_end = cp_start + ccp_hdr_txbx
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}

///| Extract comment (annotation) subdocument text

///|
/// Comments live in the CP range [ccpText + ccpFtn + ccpHdd, + ccpAtn)
pub fn extract_comment_text(
  word_bytes : FixedArray[Byte],
  cps : Array[Int],
  plc_reader : BinaryReader,
  pcd_count : Int,
  main_story_end : Int,
  ccp_ftn : Int,
  ccp_hdd : Int,
  ccp_atn : Int,
) -> String {
  if ccp_atn <= 0 {
    return ""
  }
  let cp_start = main_story_end + ccp_ftn + ccp_hdd
  let cp_end = cp_start + ccp_atn
  extract_subdocument_text(
    word_bytes, cps, plc_reader, pcd_count, cp_start, cp_end,
  )
}
