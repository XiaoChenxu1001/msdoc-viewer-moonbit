///| MS-DOC parser - orchestrates all modules

///| Parse MS-DOC file
pub fn parse_ms_doc(input : FixedArray[Byte]) -> MsDocParseResult raise {
  let warnings = Array::new()

  // Parse CFB container
  let container = parse_cfb(input, warnings)

  // Get WordDocument stream
  let word_bytes = match cfb_get_stream(container, "WordDocument") {
    Some(bytes) => bytes
    None => {
      ignore(push_warning(warnings, "WordDocument stream not found"))
      return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
    }
  }

  // Parse FIB header inline for structure offsets
  let fib_reader = BinaryReader::make(word_bytes)
  let w_ident = fib_reader.u16(0)
  let n_fib = fib_reader.u16(2)
  let flags = fib_reader.u16(10)

  // Check for encryption (bit 8 of flags at offset 10)
  if (flags & 0x0100) != 0 {
    ignore(push_warning(warnings, "Encrypted .doc file detected, not supported"))
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  let f_which_tbl_stm = if (flags & 0x0200) != 0 { 1 } else { 0 }

  // Get table stream name based on FIB
  let table_name = if f_which_tbl_stm == 1 { "1Table" } else { "0Table" }

  let table_bytes = match cfb_get_stream(container, table_name) {
    Some(bytes) => bytes
    None => {
      ignore(push_warning(warnings, "Table stream not found: " + table_name))
      return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
    }
  }

  // Read FIB section sizes
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  // Get ccpText from fibRgLw (index 3, 4 bytes each)
  let main_story_end = {
    let ccp_text_offset = cslw_offset + 2 + 3 * 4
    fib_reader.u32(ccp_text_offset)
  }

  // Clx is entry 33 in FibRgFcLcb
  let fc_clx = fib_reader.u32(fib_rgfc_lcb_start + 33 * 8)
  let lcb_clx = fib_reader.u32(fib_rgfc_lcb_start + 33 * 8 + 4)

  if lcb_clx <= 0 {
    ignore(push_warning(warnings, "No CLX data"))
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  // Read CLX bytes from table stream (zero-copy view)
  let clx_view = table_bytes.view(start=fc_clx, end=fc_clx + lcb_clx)

  // Parse piece table - find Pcdt marker (0x02)
  let clx_reader = BinaryReader::from_view(clx_view)
  let mut clx_offset = 0
  while clx_offset < clx_view.length() && clx_reader.u8(clx_offset) == 0x01 {
    let cb_grpprl = clx_reader.u16(clx_offset + 1)
    clx_offset += 3 + cb_grpprl
  }

  if clx_offset >= clx_view.length() || clx_reader.u8(clx_offset) != 0x02 {
    ignore(push_warning(warnings, "CLX does not contain Pcdt marker"))
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  let lcb = clx_reader.u32(clx_offset + 1)
  let plc_pcd_view = clx_view.view(start=clx_offset + 5, end=clx_offset + 5 + lcb)

  // Parse PlcPcd
  let plc_reader = BinaryReader::from_view(plc_pcd_view)
  let pcd_count = (lcb - 4) / 12

  if pcd_count <= 0 {
    ignore(push_warning(warnings, "No pieces found"))
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], sections: [], footnotes: [], endnotes: [], summary: None, comments: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  // Read CP array
  let cps = Array::new()
  for i in 0..<(pcd_count + 1) {
    cps.push(plc_reader.u32(i * 4))
  }

  // Extract text from each piece using clx decode functions
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

  // Split into paragraphs
  let full_text = document_text.to_string()
  // Replace \r with \n in full_text (single pass, no per-char string interpolation)
  let clean_full_text = full_text.replace(old = "\r", new = "\n")

  // Extract textbox subdocument text
  let textboxes = Array::new()
  let ccp_txbx = if cslw_offset + 2 + 9 * 4 + 4 <= word_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 9 * 4)
  } else { 0 }
  let fc_plcftxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 56 * 8)
  let lcb_plcftxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 56 * 8 + 4)

  // Extract textbox subdocument text from piece table
  let textbox_full = if ccp_txbx > 0 {
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let ccp_hdd = fib_reader.u32(cslw_offset + 2 + 5 * 4)
    let ccp_atn = fib_reader.u32(cslw_offset + 2 + 7 * 4)
    let ccp_edn = fib_reader.u32(cslw_offset + 2 + 8 * 4)
    extract_textbox_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn, ccp_hdd, ccp_atn, ccp_edn, ccp_txbx)
  } else {
    ""
  }

  // Try to parse PlcftxbxTxt for individual textbox boundaries
  if textbox_full.length() > 0 && lcb_plcftxbx_txt > 0 && fc_plcftxbx_txt + lcb_plcftxbx_txt <= table_bytes.length() {
    let txbx_view = table_bytes.view(start=fc_plcftxbx_txt, end=fc_plcftxbx_txt + lcb_plcftxbx_txt)
    let txbx_reader = BinaryReader::from_view(txbx_view)
    let txbx_count = if lcb_plcftxbx_txt >= 4 { (lcb_plcftxbx_txt - 4) / 26 } else { 0 }

    if txbx_count > 0 {
      let txbx_cps = Array::new()
      for i in 0..<(txbx_count + 1) {
        txbx_cps.push(txbx_reader.u32(i * 4))
      }
      let ftxbxs_offset = (txbx_count + 1) * 4
      for i in 0..<txbx_count {
        let ftxbxs_base = ftxbxs_offset + i * 22
        let f_reusable = txbx_reader.u16(ftxbxs_base + 8)
        // lid is at offset 14 (after 8-byte ftxbxsunion + 2-byte fReusable + 4-byte itxbxsDest)
        let lid = txbx_reader.u32(ftxbxs_base + 14)

        if f_reusable == 0 {
          let cp_s = txbx_cps[i]
          let cp_e_raw = txbx_cps[i + 1]
          // Clamp cp_e to the actual textbox subdocument length
          let cp_e = if cp_e_raw > textbox_full.length() { textbox_full.length() } else { cp_e_raw }
          if cp_s >= 0 && cp_s < cp_e && cp_e <= textbox_full.length() {
            let raw_text = textbox_full[cp_s:cp_e]
            // Offset CPs by main_story_end so they're in the same coordinate space as main document paragraphs
            let mut text_start = 0
            let raw_len = raw_text.length()
            while text_start < raw_len {
              let ch = raw_text[text_start]
              if ch.to_int() >= 0x20 || ch.to_int() == 0x0D { break }
              text_start += 1
            }
            let mut text_end = raw_len
            while text_end > text_start {
              let ch = raw_text[text_end - 1]
              if ch.to_int() >= 0x20 || ch.to_int() == 0x0D { break }
              text_end -= 1
            }
            let tb_text = raw_text[text_start:text_end].replace(old = "\r", new = "\n").trim().to_owned()
            if tb_text.length() > 0 {
              textboxes.push(TextBox::{
                shape_id: lid,
                text: tb_text,
                cp_start: main_story_end + cp_s,
                cp_end: main_story_end + cp_e,
              })
            }
          }
        }
      }
    }
  }

  // Fallback: if PlcftxbxTxt parsing failed, split textbox text by \r into entries
  if textboxes.length() == 0 && textbox_full.length() > 0 {
    let mut cp_offset = main_story_end
    let mut seg_start = 0
    let full_len = textbox_full.length()
    while seg_start < full_len {
      let mut seg_end = seg_start
      while seg_end < full_len {
        if textbox_full[seg_end].to_int() == 0x0D {
          break
        }
        seg_end += 1
      }
      let mut text_start = seg_start
      while text_start < seg_end {
        let ch = textbox_full[text_start].to_int()
        if ch >= 0x20 || ch == 0x0D { break }
        text_start += 1
      }
      if text_start < seg_end {
        let tb_text = textbox_full[text_start:seg_end].trim().to_owned()
        if tb_text.length() > 0 {
          textboxes.push(TextBox::{
            shape_id: -1,
            text: tb_text,
            cp_start: cp_offset + text_start,
            cp_end: cp_offset + seg_end,
          })
        }
      }
      cp_offset += (seg_end - seg_start)
      seg_start = if seg_end < full_len { seg_end + 1 } else { full_len }
    }
  }

  // Extract header textbox subdocument text
  let ccp_hdr_txbx = if cslw_offset + 2 + 10 * 4 + 4 <= word_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 10 * 4)
  } else { 0 }
  let fc_plcfhdrtxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 58 * 8)
  let lcb_plcfhdrtxbx_txt = fib_reader.u32(fib_rgfc_lcb_start + 58 * 8 + 4)

  // Extract header textbox subdocument text from piece table
  let hdr_txbx_full = if ccp_hdr_txbx > 0 {
    let ccp_ftn_h = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let ccp_hdd_h = fib_reader.u32(cslw_offset + 2 + 5 * 4)
    let ccp_atn_h = fib_reader.u32(cslw_offset + 2 + 7 * 4)
    let ccp_edn_h = fib_reader.u32(cslw_offset + 2 + 8 * 4)
    let ccp_txbx_h = fib_reader.u32(cslw_offset + 2 + 9 * 4)
    extract_header_textbox_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn_h, ccp_hdd_h, ccp_atn_h, ccp_edn_h, ccp_txbx_h, ccp_hdr_txbx)
  } else {
    ""
  }

  // Parse PlcfHdrtxbxTxt for individual header textbox boundaries
  if hdr_txbx_full.length() > 0 && lcb_plcfhdrtxbx_txt > 0 && fc_plcfhdrtxbx_txt + lcb_plcfhdrtxbx_txt <= table_bytes.length() {
    let hdr_txbx_view = table_bytes.view(start=fc_plcfhdrtxbx_txt, end=fc_plcfhdrtxbx_txt + lcb_plcfhdrtxbx_txt)
    let hdr_txbx_reader = BinaryReader::from_view(hdr_txbx_view)
    let hdr_txbx_count = if lcb_plcfhdrtxbx_txt >= 4 { (lcb_plcfhdrtxbx_txt - 4) / 26 } else { 0 }

    if hdr_txbx_count > 0 {
      let hdr_txbx_cps = Array::new()
      for i in 0..<(hdr_txbx_count + 1) {
        hdr_txbx_cps.push(hdr_txbx_reader.u32(i * 4))
      }
      let hdr_ftxbxs_offset = (hdr_txbx_count + 1) * 4
      for i in 0..<hdr_txbx_count {
        let ftxbxs_base = hdr_ftxbxs_offset + i * 22
        let f_reusable = hdr_txbx_reader.u16(ftxbxs_base + 8)
        let lid = hdr_txbx_reader.u32(ftxbxs_base + 14)

        if f_reusable == 0 {
          let cp_s = hdr_txbx_cps[i]
          let cp_e_raw = hdr_txbx_cps[i + 1]
          let cp_e = if cp_e_raw > hdr_txbx_full.length() { hdr_txbx_full.length() } else { cp_e_raw }
          if cp_s >= 0 && cp_s < cp_e && cp_e <= hdr_txbx_full.length() {
            let raw_text = hdr_txbx_full[cp_s:cp_e]
            let mut text_start = 0
            let raw_len = raw_text.length()
            while text_start < raw_len {
              let ch = raw_text[text_start]
              if ch.to_int() >= 0x20 || ch.to_int() == 0x0D { break }
              text_start += 1
            }
            let mut text_end = raw_len
            while text_end > text_start {
              let ch = raw_text[text_end - 1]
              if ch.to_int() >= 0x20 || ch.to_int() == 0x0D { break }
              text_end -= 1
            }
            let tb_text = raw_text[text_start:text_end].replace(old = "\r", new = "\n").trim().to_owned()
            if tb_text.length() > 0 {
              // Compute CP offset: main_story_end + all subdocument sizes before header textbox
              let hdr_txbx_cp_offset = main_story_end + fib_reader.u32(cslw_offset + 2 + 4 * 4) + fib_reader.u32(cslw_offset + 2 + 5 * 4) + fib_reader.u32(cslw_offset + 2 + 7 * 4) + fib_reader.u32(cslw_offset + 2 + 8 * 4) + fib_reader.u32(cslw_offset + 2 + 9 * 4)
              textboxes.push(TextBox::{
                shape_id: lid,
                text: tb_text,
                cp_start: hdr_txbx_cp_offset + cp_s,
                cp_end: hdr_txbx_cp_offset + cp_e,
              })
            }
          }
        }
      }
    }
  }

  // Parse DopBase.fFacingPages for even/odd header/footer control
  let fc_dop = fib_reader.u32(fib_rgfc_lcb_start + 31 * 8)
  let lcb_dop = fib_reader.u32(fib_rgfc_lcb_start + 31 * 8 + 4)
  let mut has_facing_pages = false
  if lcb_dop > 0 && fc_dop > 0 && fc_dop + 1 <= table_bytes.length() {
    let dop_reader = BinaryReader::make(table_bytes)
    // DopBase first byte: bit 0 = fFacingPages
    has_facing_pages = (dop_reader.u8(fc_dop).land(0x01)) != 0
  }

  // Extract header/footer subdocument text
  let headers = Array::new()
  let footers = Array::new()
  let ccp_hdd = if cslw_offset + 2 + 5 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 5 * 4)
  } else { 0 }

  if ccp_hdd > 0 {
    // Header document starts after main story + footnote document
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)

    // Extract header document text from piece table
    let header_full = extract_header_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn, ccp_hdd)

    // Parse PlcfHdd to get story boundaries
    let fc_plcf_hdd = fib_reader.u32(fib_rgfc_lcb_start + 11 * 8)
    let lcb_plcf_hdd = fib_reader.u32(fib_rgfc_lcb_start + 11 * 8 + 4)

    if lcb_plcf_hdd > 0 && fc_plcf_hdd + lcb_plcf_hdd <= table_bytes.length() {
      let hdd_view = table_bytes.view(start=fc_plcf_hdd, end=fc_plcf_hdd + lcb_plcf_hdd)
      let hdd_reader = BinaryReader::from_view(hdd_view)
      // PlcfHdd contains (N+1) CPs and N 0-byte entries, total size = (N+1)*4
      let story_count = (lcb_plcf_hdd / 4) - 1
      let hdd_cps = Array::new()
      for i in 0..<(story_count + 1) {
        hdd_cps.push(hdd_reader.u32(i * 4))
      }

      // Stories 0-5 are separator stories (footnote/endnote separators)
      // Stories 6+ are grouped in sets of 6 per section:
      //   [0] even-page header, [1] odd-page header
      //   [2] even-page footer, [3] odd-page footer
      //   [4] first-page header, [5] first-page footer
      for i in 0..<story_count {
        let cp_s = hdd_cps[i]
        let cp_e = hdd_cps[i + 1]
        if cp_e > cp_s && cp_s < header_full.length() {
          let actual_end = if cp_e > header_full.length() { header_full.length() } else { cp_e }
          let story_text = strip_field_markers(header_full[cp_s:actual_end].replace(old = "\r", new = "\n").trim().to_owned())
          if story_text.length() > 0 && i >= 6 {
            let relative_idx = i - 6
            let section_idx = relative_idx / 6
            let story_slot = relative_idx % 6
            // story_slot: 0=even header, 1=odd header, 2=even footer, 3=odd footer, 4=first header, 5=first footer
            // Skip even-page stories if fFacingPages is not set
            let skip_even = !has_facing_pages && (story_slot == 0 || story_slot == 2)
            if !skip_even {
              let is_footer = story_slot == 2 || story_slot == 3 || story_slot == 5
              let hf = HeaderFooter::{
                text: story_text,
                story_type: story_slot,
                section_index: section_idx,
              }
              if is_footer {
                footers.push(hf)
              } else {
                headers.push(hf)
              }
            }
          }
        }
      }
    }
  }

  // Parse PlcfSed to get section boundaries and properties
  let sections = parse_sections(fib_reader, fib_rgfc_lcb_start, table_bytes, word_bytes)

  // Extract footnote subdocument text
  let footnotes = Array::new()
  let ccp_ftn = if cslw_offset + 2 + 4 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 4 * 4)
  } else { 0 }

  if ccp_ftn > 0 {
    // Extract footnote document text from piece table
    let footnote_full = extract_footnote_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn)

    // Parse PlcffndTxt to get individual footnote boundaries
    let fc_plcffnd_txt = fib_reader.u32(fib_rgfc_lcb_start + 3 * 8)
    let lcb_plcffnd_txt = fib_reader.u32(fib_rgfc_lcb_start + 3 * 8 + 4)

    if lcb_plcffnd_txt > 0 && fc_plcffnd_txt + lcb_plcffnd_txt <= table_bytes.length() {
      let ftn_view = table_bytes.view(start=fc_plcffnd_txt, end=fc_plcffnd_txt + lcb_plcffnd_txt)
      let ftn_reader = BinaryReader::from_view(ftn_view)
      // PlcffndTxt contains (N+1) CPs for N footnotes
      let ftn_count = (lcb_plcffnd_txt - 4) / 4
      let ftn_cps = Array::new()
      for i in 0..<(ftn_count + 1) {
        ftn_cps.push(ftn_reader.u32(i * 4))
      }

      // Extract each footnote
      for i in 0..<ftn_count {
        let cp_s = ftn_cps[i]
        let cp_e = ftn_cps[i + 1]
        if cp_e > cp_s && cp_s < footnote_full.length() {
          let actual_end = if cp_e > footnote_full.length() { footnote_full.length() } else { cp_e }
          let ftn_text = footnote_full[cp_s:actual_end].replace(old = "\r", new = "\n").trim().to_owned()
          if ftn_text.length() > 0 {
            footnotes.push(Footnote::{
              text: ftn_text,
              ref_cp: 0,  // Will be set later when we find the reference mark
              note_index: i + 1,
              is_endnote: false,
            })
          }
        }
      }
    }
  }

  // Extract endnote subdocument text
  let endnotes = Array::new()
  let ccp_edn = if cslw_offset + 2 + 8 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 8 * 4)
  } else { 0 }

  if ccp_edn > 0 {
    // Extract endnote document text from piece table
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let ccp_hdd = fib_reader.u32(cslw_offset + 2 + 5 * 4)
    let ccp_atn = fib_reader.u32(cslw_offset + 2 + 7 * 4)
    let endnote_full = extract_endnote_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn, ccp_hdd, ccp_atn, ccp_edn)

    // Parse PlcfendTxt to get individual endnote boundaries
    let fc_plcfend_txt = fib_reader.u32(fib_rgfc_lcb_start + 47 * 8)
    let lcb_plcfend_txt = fib_reader.u32(fib_rgfc_lcb_start + 47 * 8 + 4)

    if lcb_plcfend_txt > 0 && fc_plcfend_txt + lcb_plcfend_txt <= table_bytes.length() {
      let edn_view = table_bytes.view(start=fc_plcfend_txt, end=fc_plcfend_txt + lcb_plcfend_txt)
      let edn_reader = BinaryReader::from_view(edn_view)
      // PlcfendTxt contains (N+1) CPs for N endnotes
      let edn_count = (lcb_plcfend_txt - 4) / 4
      let edn_cps = Array::new()
      for i in 0..<(edn_count + 1) {
        edn_cps.push(edn_reader.u32(i * 4))
      }

      // Extract each endnote
      for i in 0..<edn_count {
        let cp_s = edn_cps[i]
        let cp_e = edn_cps[i + 1]
        if cp_e > cp_s && cp_s < endnote_full.length() {
          let actual_end = if cp_e > endnote_full.length() { endnote_full.length() } else { cp_e }
          let edn_text = endnote_full[cp_s:actual_end].replace(old = "\r", new = "\n").trim().to_owned()
          if edn_text.length() > 0 {
            endnotes.push(Footnote::{
              text: edn_text,
              ref_cp: 0,  // Will be set later when we find the reference mark
              note_index: i + 1,
              is_endnote: true,
            })
          }
        }
      }
    }
  }

  // Extract comment (annotation) subdocument text
  let comments = Array::new()
  let ccp_atn = if cslw_offset + 2 + 7 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 7 * 4)
  } else { 0 }

  if ccp_atn > 0 {
    // Extract comment document text from piece table
    let comment_full = extract_comment_text(word_bytes, cps, plc_reader, pcd_count, main_story_end, ccp_ftn, ccp_hdd, ccp_atn)

    // Parse PlcfandTxt to get individual comment text boundaries
    let fc_plcfand_txt = fib_reader.u32(fib_rgfc_lcb_start + 5 * 8)
    let lcb_plcfand_txt = fib_reader.u32(fib_rgfc_lcb_start + 5 * 8 + 4)

    // Parse PlcfandRef to get anchor positions in main document
    let fc_plcfand_ref = fib_reader.u32(fib_rgfc_lcb_start + 4 * 8)
    let lcb_plcfand_ref = fib_reader.u32(fib_rgfc_lcb_start + 4 * 8 + 4)

    // Parse GrpXstAtnOwners for author names
    let fc_grpxstatnowners = fib_reader.u32(fib_rgfc_lcb_start + 36 * 8)
    let lcb_grpxstatnowners = fib_reader.u32(fib_rgfc_lcb_start + 36 * 8 + 4)

    let has_atn_txt = lcb_plcfand_txt > 0 && fc_plcfand_txt + lcb_plcfand_txt <= table_bytes.length()
    let has_atn_ref = lcb_plcfand_ref > 0 && fc_plcfand_ref + lcb_plcfand_ref <= table_bytes.length()

    if has_atn_txt && has_atn_ref {
      let atn_txt_view = table_bytes.view(start=fc_plcfand_txt, end=fc_plcfand_txt + lcb_plcfand_txt)
      let atn_txt_reader = BinaryReader::from_view(atn_txt_view)
      let atn_ref_view = table_bytes.view(start=fc_plcfand_ref, end=fc_plcfand_ref + lcb_plcfand_ref)
      let atn_ref_reader = BinaryReader::from_view(atn_ref_view)

      // PlcfandTxt: (N+1) CPs for N comments (zero-byte data elements)
      let atn_count = (lcb_plcfand_txt - 4) / 4
      let atn_txt_cps = Array::new()
      for i in 0..<(atn_count + 1) {
        atn_txt_cps.push(atn_txt_reader.u32(i * 4))
      }

      // PlcfandRef: (N+1) CPs + N ATRDPre10 (30 bytes each)
      let atn_ref_cps = Array::new()
      for i in 0..<(atn_count + 1) {
        atn_ref_cps.push(atn_ref_reader.u32(i * 4))
      }

      // Parse author names from GrpXstAtnOwners (STTB format)
      let authors = Array::new()
      if lcb_grpxstatnowners > 0 && fc_grpxstatnowners + lcb_grpxstatnowners <= table_bytes.length() {
        let owners_view = table_bytes.view(start=fc_grpxstatnowners, end=fc_grpxstatnowners + lcb_grpxstatnowners)
        let owners_reader = BinaryReader::from_view(owners_view)
        if lcb_grpxstatnowners >= 6 {
          let f_extend = owners_reader.u16(0)
          let c_data = owners_reader.u16(2)
          if f_extend == 0xFFFF {
            let mut offset = 6
            for _i in 0..<c_data.min(100) {
              if offset + 2 > lcb_grpxstatnowners { break }
              let cch = owners_reader.u16(offset)
              offset += 2
              if cch > 0 && offset + cch * 2 <= lcb_grpxstatnowners {
                let name = owners_reader.utf16le(offset, cch * 2)
                authors.push(name)
              } else {
                authors.push("")
              }
              offset += cch * 2
              if offset < lcb_grpxstatnowners {
                let cb_extra = owners_reader.u8(offset)
                offset += 1 + cb_extra
              }
            }
          }
        }
      }

      // Extract each comment
      for i in 0..<atn_count {
        let cp_s = atn_txt_cps[i]
        let cp_e = atn_txt_cps[i + 1]
        if cp_e > cp_s && cp_s < comment_full.length() {
          let actual_end = if cp_e > comment_full.length() { comment_full.length() } else { cp_e }
          let comment_text = comment_full[cp_s:actual_end].replace(old = "\r", new = "\n").trim().to_owned()
          if comment_text.length() > 0 {
            let anchor_cp = if i < atn_ref_cps.length() { atn_ref_cps[i] } else { 0 }
            let author = if i < authors.length() { authors[i] } else { "" }
            comments.push(Comment::{
              anchor_cp,
              text: comment_text,
              author,
              comment_index: i + 1,
              parent_index: -1,
            })
          }
        }
      }
    }
  }

  // Read CHPX and PAPX runs for formatting
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

  // Parse style definitions for style resolution
  // Stshf is entry 1 in FibRgFcLcb
  let stshf_fc = fib_reader.u32(fib_rgfc_lcb_start + 1 * 8)
  let stshf_lcb = fib_reader.u32(fib_rgfc_lcb_start + 1 * 8 + 4)
  let styles = if stshf_lcb > 0 {
    let stshf_view = table_bytes.view(start=stshf_fc, end=stshf_fc + stshf_lcb)
    parse_styles(stshf_view)
  } else {
    StyleCollection::{ styles: [], style_map: Map([], capacity=16), count: 0, header: None }
  }
  {
    let normal_opt = get_style(styles, 0)
    match normal_opt {
      Some(normal) => ignore(normal)
      None => ignore(0)
    }
  }

  // Parse font family names
  let fonts = parse_fonts_from_fib(table_bytes, fib_reader, fib_rgfc_lcb_start)

  // Pre-resolve all styles into cache for O(1) lookup in paragraph loop
  let style_cache = pre_resolve_all_styles(styles)

  // Extract object pool and Data stream for picture resolution (mirrors JS lines 502-508)
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

  // Build paragraphs with formatting
  // JS: uses PAPX runs directly as paragraph boundaries (splitParagraphRanges fallback)
  let paragraphs = Array::new()
  let mut chpx_cursor = 0
  if papx_runs.length() > 0 {
    // Use PAPX runs as paragraph boundaries (faithful JS approach)
    let mut ri = 0
    while ri < papx_runs.length() {
      let run = papx_runs[ri]
      let cp_start = run.cp_start
      let mut cp_end = run.cp_end
      // Clamp to document text length
      if cp_start > String::length(clean_full_text) {
        ri += 1
        continue
      }
      if cp_end > String::length(clean_full_text) {
        cp_end = String::length(clean_full_text)
      }
      if cp_start >= cp_end {
        ri += 1
        continue
      }
      let para_text = clean_full_text[cp_start : cp_end].to_owned()
      let papx_result = resolve_papx_run(run, styles, style_cache)
      let para_state = papx_result.para_state
      let (segments, new_cursor) = build_char_segments(chpx_runs, para_text, cp_start, cp_end, papx_result.resolved_char_props, fonts, styles, chpx_cursor, style_cache)
      chpx_cursor = new_cursor
      let runs = process_inline_fields(segments, resolver)
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
      // Determine terminator from last non-field-marker character
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
  } else {
    // Fallback: scan text for paragraph terminators (original approach)
    let mut start = 0
    let mut i = 0
    while i < String::length(clean_full_text) {
      let ch = clean_full_text[i]
      if ch == '\n' || ch == 0x07 {
        let para_text = clean_full_text[start : i].to_owned()
        let papx_result = find_papx_state_and_props(papx_runs, start, i, styles, style_cache)
        let para_state = papx_result.para_state
        let (segments, new_cursor) = build_char_segments(chpx_runs, para_text, start, i, papx_result.resolved_char_props, fonts, styles, chpx_cursor, style_cache)
        chpx_cursor = new_cursor
        let runs = process_inline_fields(segments, resolver)
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
        let terminator_byte = if ch == 0x07 { b'\x07' } else { b'\r' }
        paragraphs.push(ParagraphInfo::{
          cp_start: start,
          cp_end: i,
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
        start = i + 1
      }
      i += 1
    }
    // Add last paragraph
    if start < String::length(clean_full_text) {
      let para_text = clean_full_text[start : String::length(clean_full_text)].to_owned()
      let papx_result = find_papx_state_and_props(papx_runs, start, String::length(clean_full_text), styles, style_cache)
      let para_state = papx_result.para_state
      let (segments, _) = build_char_segments(chpx_runs, para_text, start, String::length(clean_full_text), papx_result.resolved_char_props, fonts, styles, chpx_cursor, style_cache)
      let runs = process_inline_fields(segments, resolver)
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
      paragraphs.push(ParagraphInfo::{
        cp_start: start,
        cp_end: String::length(clean_full_text),
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
        terminator: 0x0D,
        raw_papx: papx_result.raw_props,
        border_top: para_state.border_top,
        border_left: para_state.border_left,
        border_bottom: para_state.border_bottom,
        border_right: para_state.border_right,
        outline_level: para_state.outline_level,
        shading: para_state.shading,
      })
    }
  }

  // Build blocks from paragraphs (detect tables)
  let blocks = build_blocks(paragraphs, styles)

  // Collect unused object pool entries as trailing attachments (mirrors JS lines 519-527)
  let trailing_attachments : Array[Asset] = Array::new()
  resolver.object_pool.each(fn(entry_name, asset) {
    if asset.asset_type == "attachment" {
      let found = resolver.used_names.get(entry_name)
      if found is None {
        trailing_attachments.push(asset)
      }
    }
  })
  for attachment in trailing_attachments {
    resolver.assets.push(attachment)
  }

  if trailing_attachments.length() > 0 {
    blocks.push(Block::{
      paragraph: None,
      table: None,
      attachments: Some(trailing_attachments),
    })
  }

  // Extract EPRINT images from OLE objects (Visio drawings, etc.)
  // These are separate from picture records and need to be added to assets
  for entry in object_pool {
    let asset = entry.1
    if asset.asset_type == "image" && asset.mime == "image/emf" {
      resolver.assets.push(asset)
    }
  }

  // Fallback: check if offset 0 in Data stream is an orphan picture record
  // (CHPX may not reference it, but it contains valid image data)
  if data_bytes.length() > 68 {
    let lcb0 = BinaryReader::make(data_bytes).i32(0)
    let cb0 = BinaryReader::make(data_bytes).u16(4)
    if lcb0 > 100 && cb0 > 0 && cb0 < lcb0 && lcb0 <= data_bytes.length() {
      // Check if offset 0 is already in assets
      let already_extracted = resolver.assets.any(fn(a) { a.id.contains("asset-img-0") })
      if !already_extracted {
        match extract_raw_image_asset(data_bytes, 0) {
          Some(raw) => {
            if raw.mime != "application/octet-stream" {
              // Use dimensions from PICMID if available, otherwise extract from image bytes
              let (w, h) = if raw.width > 0 && raw.height > 0 {
                (raw.width, raw.height)
              } else {
                extract_image_dimensions(raw.bytes)
              }
              let asset = Asset::{
                id: "asset-img-0",
                asset_type: "image",
                name: "image",
                mime: raw.mime,
                bytes: raw.bytes,
                data_url: create_loading_placeholder(raw.mime, raw.bytes.length()),
                width: w,
                height: h,
              }
              resolver.assets.push(asset)
            }
          }
          None => ()
        }
      }
    }
  }

  let font_infos : Array[FontInfo] = Array::new()
  for f in fonts.fonts {
    font_infos.push(FontInfo::{ name: f.name, alt_name: f.alt_name })
  }

  let style_infos : Array[StyleInfo] = Array::new()
  for s in styles.styles {
    style_infos.push(StyleInfo::{
      istd: s.istd,
      name: s.name,
      style_type: s.stk,
      based_on: s.base_style,
      next_style: s.next_style,
    })
  }

  let meta = ParseMeta::{
    fib_w_ident: w_ident,
    fib_n_fib: n_fib,
    fib_which_tbl_stm: f_which_tbl_stm != 0,
    fib_complex: (flags & 0x0004) != 0,
    fib_encrypted: (flags & 0x0100) != 0,
    ccp_text: main_story_end,
    count_paragraphs: paragraphs.length(),
    count_blocks: blocks.length(),
    count_assets: resolver.assets.length(),
    count_styles: styles.count,
    count_fonts: fonts.fonts.length(),
  }

  // Parse Summary Information stream for document metadata
  // Stream name is \005SummaryInformation (0x0005 prefix + "SummaryInformation")
  let summary = match cfb_get_stream(container, "SummaryInformation") {
    Some(bytes) => parse_summary_info(bytes)
    None => None
  }

  MsDocParseResult::{
    text: clean_full_text,
    paragraphs,
    blocks,
    warnings,
    assets: resolver.assets,
    meta: Some(meta),
    fonts: font_infos,
    styles: style_infos,
    textboxes,
    headers,
    footers,
    sections,
    footnotes,
    endnotes,
    summary,
    comments,
    raw_data: input,
    image_config: default_image_config(),
    image_cache: Map([], capacity=16),
    content_dedup_cache: Map([], capacity=16),
  }
}
