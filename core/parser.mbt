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
      return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
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
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  let f_which_tbl_stm = if (flags & 0x0200) != 0 { 1 } else { 0 }

  // Get table stream name based on FIB
  let table_name = if f_which_tbl_stm == 1 { "1Table" } else { "0Table" }

  let table_bytes = match cfb_get_stream(container, table_name) {
    Some(bytes) => bytes
    None => {
      ignore(push_warning(warnings, "Table stream not found: " + table_name))
      return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
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
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
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
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
  }

  let lcb = clx_reader.u32(clx_offset + 1)
  let plc_pcd_view = clx_view.view(start=clx_offset + 5, end=clx_offset + 5 + lcb)

  // Parse PlcPcd
  let plc_reader = BinaryReader::from_view(plc_pcd_view)
  let pcd_count = (lcb - 4) / 12

  if pcd_count <= 0 {
    ignore(push_warning(warnings, "No pieces found"))
    return MsDocParseResult::{ text: "", paragraphs: [], blocks: [], warnings, assets: [], meta: None, fonts: [], styles: [], textboxes: [], headers: [], footers: [], footnotes: [], endnotes: [], raw_data: [], image_config: default_image_config(), image_cache: Map([], capacity=16), content_dedup_cache: Map([], capacity=16) }
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
  // Textbox subdocument starts after all other subdocuments: footnote + header + annotation + endnote
  let textbox_text = StringBuilder::new()
  if ccp_txbx > 0 {
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let ccp_hdd = fib_reader.u32(cslw_offset + 2 + 5 * 4)
    let ccp_atn = fib_reader.u32(cslw_offset + 2 + 7 * 4)
    let ccp_edn = fib_reader.u32(cslw_offset + 2 + 8 * 4)
    let textbox_cp_start = main_story_end + ccp_ftn + ccp_hdd + ccp_atn + ccp_edn
    let textbox_cp_end = textbox_cp_start + ccp_txbx
    let mut txbx_piece_offset = (pcd_count + 1) * 4
    for i in 0..<pcd_count {
      let cp_s = cps[i]
      let cp_e = cps[i + 1]
      // Check if piece overlaps with textbox range (not just starts within it)
      if cp_s < textbox_cp_end && cp_e > textbox_cp_start {
        // Calculate the overlap range
        let overlap_start = if cp_s > textbox_cp_start { cp_s } else { textbox_cp_start }
        let overlap_end = if cp_e < textbox_cp_end { cp_e } else { textbox_cp_end }
        let fc_raw = plc_reader.u32(txbx_piece_offset + 2)
        let compressed = (fc_raw & 0x40000000) != 0
        let fc = fc_raw & 0x3FFFFFFF
        // Calculate byte offsets for the overlap range
        let cp_offset_in_piece = overlap_start - cp_s
        let actual_byte_start = if compressed { (fc / 2) + cp_offset_in_piece } else { fc + cp_offset_in_piece * 2 }
        let byte_length = if compressed { overlap_end - overlap_start } else { (overlap_end - overlap_start) * 2 }
        let piece = Piece::{
          index: i, compressed, fc, cp_start: overlap_start, cp_end: overlap_end,
          actual_byte_start, byte_length,
          actual_byte_end: actual_byte_start + byte_length,
        }
        let piece_text = extract_piece_text(word_bytes, piece)
        textbox_text <+ "\{piece_text}"
      }
      txbx_piece_offset += 8
    }
  }

  let textbox_full = textbox_text.to_string()

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

  // Extract header/footer subdocument text
  let headers = Array::new()
  let footers = Array::new()
  let ccp_hdd = if cslw_offset + 2 + 5 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 5 * 4)
  } else { 0 }

  if ccp_hdd > 0 {
    // Header document starts after main story + footnote document
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let header_cp_start = main_story_end + ccp_ftn
    let header_cp_end = header_cp_start + ccp_hdd

    // Extract header document text from piece table
    let header_text = StringBuilder::new()
    let mut hdr_piece_offset = (pcd_count + 1) * 4
    for i in 0..<pcd_count {
      let cp_s = cps[i]
      let cp_e = cps[i + 1]
      if cp_s < header_cp_end && cp_e > header_cp_start {
        let overlap_start = if cp_s > header_cp_start { cp_s } else { header_cp_start }
        let overlap_end = if cp_e < header_cp_end { cp_e } else { header_cp_end }
        let fc_raw = plc_reader.u32(hdr_piece_offset + 2)
        let compressed = (fc_raw & 0x40000000) != 0
        let fc = fc_raw & 0x3FFFFFFF
        let cp_offset_in_piece = overlap_start - header_cp_start
        let actual_byte_start = if compressed { (fc / 2) + cp_offset_in_piece } else { fc + cp_offset_in_piece * 2 }
        let byte_length = if compressed { overlap_end - overlap_start } else { (overlap_end - overlap_start) * 2 }
        let piece = Piece::{
          index: i, compressed, fc, cp_start: overlap_start, cp_end: overlap_end,
          actual_byte_start, byte_length,
          actual_byte_end: actual_byte_start + byte_length,
        }
        let piece_text = extract_piece_text(word_bytes, piece)
        header_text <+ "\{piece_text}"
      }
      hdr_piece_offset += 8
    }

    let header_full = header_text.to_string()

    // Parse PlcfHdd to get story boundaries
    let fc_plcf_hdd = fib_reader.u32(fib_rgfc_lcb_start + 11 * 8)
    let lcb_plcf_hdd = fib_reader.u32(fib_rgfc_lcb_start + 11 * 8 + 4)

    if lcb_plcf_hdd > 0 && fc_plcf_hdd + lcb_plcf_hdd <= table_bytes.length() {
      let hdd_view = table_bytes.view(start=fc_plcf_hdd, end=fc_plcf_hdd + lcb_plcf_hdd)
      let hdd_reader = BinaryReader::from_view(hdd_view)
      // PlcfHdd contains (N+1) CPs and N empty 0-byte entries
      let story_count = (lcb_plcf_hdd - 4) / 4  // Each story has 1 CP entry (4 bytes)
      let hdd_cps = Array::new()
      for i in 0..<(story_count + 1) {
        hdd_cps.push(hdd_reader.u32(i * 4))
      }

      // Stories 0-5 are separator stories (footnote/endnote separators)
      // Stories 6+ are actual headers/footers (one per section)
      // Each section has up to 3 stories: first page, even page, odd page
      // But PlcfHdd structure is: first 6 are separators, then groups of 3 per section
      // Actually, the structure is simpler: each pair of CPs defines one story
      // Stories 0-5: separators, 6+: headers/footers

      // For now, extract all non-empty stories as headers
      for i in 0..<story_count {
        let cp_s = hdd_cps[i]
        let cp_e = hdd_cps[i + 1]
        if cp_e > cp_s && cp_s < header_full.length() {
          let actual_end = if cp_e > header_full.length() { header_full.length() } else { cp_e }
          let story_text = header_full[cp_s:actual_end].replace(old = "\r", new = "\n").trim().to_owned()
          if story_text.length() > 0 {
            // Stories 0-5 are separators, skip them for now
            if i >= 6 {
              let section_idx = (i - 6) / 3
              let story_type = (i - 6) % 3  // 0=first, 1=even, 2=odd
              // Simple heuristic: if story_type is 0 or 2, it's header; if 1, it's footer
              // Actually, we need section properties to determine this
              // For now, put all in headers
              headers.push(HeaderFooter::{
                text: story_text,
                story_type,
                section_index: section_idx,
              })
            }
          }
        }
      }
    }
  }

  // Extract footnote subdocument text
  let footnotes = Array::new()
  let ccp_ftn = if cslw_offset + 2 + 4 * 4 + 4 <= table_bytes.length() {
    fib_reader.u32(cslw_offset + 2 + 4 * 4)
  } else { 0 }

  if ccp_ftn > 0 {
    // Footnote document starts after main story
    let footnote_cp_start = main_story_end
    let footnote_cp_end = footnote_cp_start + ccp_ftn

    // Extract footnote document text from piece table
    let footnote_text = StringBuilder::new()
    let mut ftn_piece_offset = (pcd_count + 1) * 4
    for i in 0..<pcd_count {
      let cp_s = cps[i]
      let cp_e = cps[i + 1]
      if cp_s < footnote_cp_end && cp_e > footnote_cp_start {
        let overlap_start = if cp_s > footnote_cp_start { cp_s } else { footnote_cp_start }
        let overlap_end = if cp_e < footnote_cp_end { cp_e } else { footnote_cp_end }
        let fc_raw = plc_reader.u32(ftn_piece_offset + 2)
        let compressed = (fc_raw & 0x40000000) != 0
        let fc = fc_raw & 0x3FFFFFFF
        let cp_offset_in_piece = overlap_start - footnote_cp_start
        let actual_byte_start = if compressed { (fc / 2) + cp_offset_in_piece } else { fc + cp_offset_in_piece * 2 }
        let byte_length = if compressed { overlap_end - overlap_start } else { (overlap_end - overlap_start) * 2 }
        let piece = Piece::{
          index: i, compressed, fc, cp_start: overlap_start, cp_end: overlap_end,
          actual_byte_start, byte_length,
          actual_byte_end: actual_byte_start + byte_length,
        }
        let piece_text = extract_piece_text(word_bytes, piece)
        footnote_text <+ "\{piece_text}"
      }
      ftn_piece_offset += 8
    }

    let footnote_full = footnote_text.to_string()

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
    // Endnote document starts after main story + footnote + header + annotation
    let ccp_ftn = fib_reader.u32(cslw_offset + 2 + 4 * 4)
    let ccp_hdd = fib_reader.u32(cslw_offset + 2 + 5 * 4)
    let ccp_atn = fib_reader.u32(cslw_offset + 2 + 7 * 4)
    let endnote_cp_start = main_story_end + ccp_ftn + ccp_hdd + ccp_atn
    let endnote_cp_end = endnote_cp_start + ccp_edn

    // Extract endnote document text from piece table
    let endnote_text = StringBuilder::new()
    let mut edn_piece_offset = (pcd_count + 1) * 4
    for i in 0..<pcd_count {
      let cp_s = cps[i]
      let cp_e = cps[i + 1]
      if cp_s < endnote_cp_end && cp_e > endnote_cp_start {
        let overlap_start = if cp_s > endnote_cp_start { cp_s } else { endnote_cp_start }
        let overlap_end = if cp_e < endnote_cp_end { cp_e } else { endnote_cp_end }
        let fc_raw = plc_reader.u32(edn_piece_offset + 2)
        let compressed = (fc_raw & 0x40000000) != 0
        let fc = fc_raw & 0x3FFFFFFF
        let cp_offset_in_piece = overlap_start - endnote_cp_start
        let actual_byte_start = if compressed { (fc / 2) + cp_offset_in_piece } else { fc + cp_offset_in_piece * 2 }
        let byte_length = if compressed { overlap_end - overlap_start } else { (overlap_end - overlap_start) * 2 }
        let piece = Piece::{
          index: i, compressed, fc, cp_start: overlap_start, cp_end: overlap_end,
          actual_byte_start, byte_length,
          actual_byte_end: actual_byte_start + byte_length,
        }
        let piece_text = extract_piece_text(word_bytes, piece)
        endnote_text <+ "\{piece_text}"
      }
      edn_piece_offset += 8
    }

    let endnote_full = endnote_text.to_string()

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
    footnotes,
    endnotes,
    raw_data: input,
    image_config: default_image_config(),
    image_cache: Map([], capacity=16),
    content_dedup_cache: Map([], capacity=16),
  }
}


///| Get table depth from paragraph
fn get_para_table_depth(para : ParagraphInfo) -> Int {
  if !para.in_table { return 0 }
  if para.itap > 0 { para.itap }
  else if para.dtap > 0 { para.dtap }
  else { 1 }
}

///| Build blocks from paragraphs, grouping table paragraphs
fn build_blocks(paragraphs : Array[ParagraphInfo], styles : StyleCollection) -> Array[Block] {
  let blocks = Array::new()
  let mut index = 0
  while index < paragraphs.length() {
    let para = paragraphs[index]
    let depth = get_para_table_depth(para)
    if depth <= 0 {
      blocks.push(Block::{
        paragraph: Some(para),
        table: None,
        attachments: None,
      })
      index += 1
      continue
    }
    let table_paras = Array::new()
    while index < paragraphs.length() && get_para_table_depth(paragraphs[index]) > 0 {
      table_paras.push(paragraphs[index])
      index += 1
    }
    let table = build_table_block(table_paras, depth, styles)
    blocks.push(Block::{
      paragraph: None,
      table: Some(table),
      attachments: None,
    })
  }
  blocks
}

///| Build a table block from table paragraphs
fn build_table_block(paras : Array[ParagraphInfo], depth : Int, styles : StyleCollection) -> TableBlock {
  let rows = Array::new()
  let mut current_cell_paras = Array::new()
  let mut current_row_cells = Array::new()
  let mut pending_table_state : Option[TableState] = None

  for para in paras {
    // Detect table state with style inheritance (matches JS buildParagraphModel)
    if pending_table_state is None && para.itap >= 1 && para.raw_papx.length() > 0 {
      let raw_view = para.raw_papx.view()
      let decoded = decode_grpprl(raw_view)
      let direct_ts = table_props_from_decoded_impl(decoded, para.raw_papx)
      // Resolve table style inheritance
      let final_ts = if direct_ts.style_id > 0 {
        let resolved = resolve_style(styles, direct_ts.style_id)
        let merged = merge_property_arrays([resolved.table_props, decoded])
        let merged_ts = table_props_from_decoded(merged)
        // Preserve defTable bytes from direct scan (merged loses raw bytes)
        if merged_ts.def_table_bytes.length() == 0 && direct_ts.def_table_bytes.length() > 0 {
          TableState::{
            style_id: merged_ts.style_id,
            indent: merged_ts.indent,
            cell_margins: merged_ts.cell_margins,
            grid_columns: merged_ts.grid_columns,
            left_indent: merged_ts.left_indent,
            row_height: merged_ts.row_height,
            alignment: merged_ts.alignment,
            table_width: merged_ts.table_width,
            def_table_bytes: direct_ts.def_table_bytes,
            operations: merged_ts.operations,
            table_shading: merged_ts.table_shading,
            cell_padding: merged_ts.cell_padding,
          }
        } else {
          merged_ts
        }
      } else {
        direct_ts
      }
      if final_ts.def_table_bytes.length() > 0 {
        pending_table_state = Some(final_ts)
      }
    }

    current_cell_paras.push(para)

    let is_cell_end = para.terminator == b'\x07'
    let is_row_end = para.table_row_end || para.inner_table_row_end

    if is_cell_end {
      current_row_cells.push(DocTableCell::{
        paragraphs: current_cell_paras,
        meta: None,
        col_index: current_row_cells.length(),
        colspan: 1,
        rowspan: 1,
        hidden: false,
      })
      current_cell_paras = Array::new()

      if is_row_end {
        // Resolve table state with style inheritance (matches JS buildParagraphModel)
        let raw_view2 = para.raw_papx.view()
        let decoded2 = decode_grpprl(raw_view2)
        let direct_ts2 = table_props_from_decoded_impl(decoded2, para.raw_papx)
        let row_ts = if direct_ts2.style_id > 0 {
          let resolved2 = resolve_style(styles, direct_ts2.style_id)
          let merged2 = merge_property_arrays([resolved2.table_props, decoded2])
          let merged_ts2 = table_props_from_decoded(merged2)
          if merged_ts2.def_table_bytes.length() == 0 && direct_ts2.def_table_bytes.length() > 0 {
            TableState::{
              style_id: merged_ts2.style_id,
              indent: merged_ts2.indent,
              cell_margins: merged_ts2.cell_margins,
              grid_columns: merged_ts2.grid_columns,
              left_indent: merged_ts2.left_indent,
              row_height: merged_ts2.row_height,
              alignment: merged_ts2.alignment,
              table_width: merged_ts2.table_width,
              def_table_bytes: direct_ts2.def_table_bytes,
              operations: merged_ts2.operations,
              table_shading: merged_ts2.table_shading,
              cell_padding: merged_ts2.cell_padding,
            }
          } else {
            merged_ts2
          }
        } else {
          direct_ts2
        }
        let effective_ts = if row_ts.def_table_bytes.length() > 0 {
          pending_table_state = Some(row_ts)
          row_ts
        } else {
          match pending_table_state {
            Some(ts) => ts
            None => row_ts
          }
        }
        // Apply cell definitions to this row
        let cell_defs = apply_table_state_to_cells(effective_ts)
        // Prune empty trailing cells (matches JS: pendingRow.cells.pop() while empty)
          if cell_defs.length() > 0 && cell_defs.length() < current_row_cells.length() {
          while current_row_cells.length() > cell_defs.length() {
            let last_cell = current_row_cells[current_row_cells.length() - 1]
            let mut is_empty = true
            for p in last_cell.paragraphs {
              // Check if paragraph has meaningful content (not just control chars like 0x07)
              let mut has_content = false
              for r in p.runs {
                let mut has_non_control = false
                let mut ci2 = 0
                while ci2 < r.text.length() {
                  let tc = r.text[ci2].to_int()
                  if tc != 0x07 && tc != 0x13 && tc != 0x14 && tc != 0x15 {
                    has_non_control = true
                    break
                  }
                  ci2 += 1
                }
                if has_non_control || r.is_line_break || r.is_page_break || r.href.length() > 0 {
                  has_content = true
                  break
                }
              }
              if has_content {
                is_empty = false
                break
              }
            }
            if is_empty {
              ignore(current_row_cells.pop())
            } else {
              break
            }
          }
        }
        let final_cells = if cell_defs.length() > 0 {
          let new_cells = Array::new()
          let mut ci = 0
          while ci < current_row_cells.length() && ci < cell_defs.length() {
            let old_cell = current_row_cells[ci]
            new_cells.push(DocTableCell::{
              paragraphs: old_cell.paragraphs,
              meta: Some(cell_defs[ci]),
              col_index: old_cell.col_index,
              colspan: 1,
              rowspan: 1,
              hidden: false,
            })
            ci += 1
          }
          while ci < current_row_cells.length() {
            new_cells.push(current_row_cells[ci])
            ci += 1
          }
          new_cells
        } else {
          current_row_cells
        }
        rows.push(TableRow::{
          cells: final_cells,
          grid_width_twips: if cell_defs.length() > 0 { cell_defs[cell_defs.length() - 1].right_boundary - cell_defs[0].left_boundary } else { 0 },
          row_height: effective_ts.row_height,
        })
        current_row_cells = Array::new()
      }
    }
  }
  if current_cell_paras.length() > 0 {
    current_row_cells.push(DocTableCell::{
      paragraphs: current_cell_paras,
      meta: None,
      col_index: current_row_cells.length(),
      colspan: 1,
      rowspan: 1,
      hidden: false,
    })
  }
  if current_row_cells.length() > 0 {
    let last_rh = match pending_table_state {
      Some(ts) => ts.row_height
      None => 0
    }
    rows.push(TableRow::{
      cells: current_row_cells,
      grid_width_twips: 0,
      row_height: last_rh,
    })
  }

  if rows.length() == 0 {
    let cells = Array::new()
    for para in paras {
      cells.push(DocTableCell::{
        paragraphs: Array::makei(1, fn(_i) { para }),
        meta: None,
        col_index: cells.length(),
        colspan: 1,
        rowspan: 1,
        hidden: false,
      })
    }
    rows.push(TableRow::{
      cells,
      grid_width_twips: 0,
      row_height: 0,
    })
  }

  // Apply table state to remaining rows without meta (trailing row without row_end marker)
  match pending_table_state {
    Some(ts) => {
      let cell_defs = apply_table_state_to_cells(ts)
      if cell_defs.length() > 0 {
        for ri in 0..<rows.length() {
          let row = rows[ri]
          // Skip rows already processed (cells have meta from per-paragraph resolution)
          let already_processed = if row.cells.length() > 0 {
            match row.cells[0].meta {
              Some(_) => true
              None => false
            }
          } else { false }
          if already_processed { continue }
          if cell_defs.length() < row.cells.length() {
            while row.cells.length() > cell_defs.length() {
              let last_cell = row.cells[row.cells.length() - 1]
              let mut is_empty = true
              for p in last_cell.paragraphs {
                if p.text.length() > 0 || p.runs.length() > 0 {
                  is_empty = false
                  break
                }
              }
              if is_empty {
                ignore(row.cells.pop())
              } else {
                break
              }
            }
          }
          let new_cells = Array::new()
          let mut ci = 0
          let def_count = cell_defs.length()
          while ci < row.cells.length() && ci < def_count {
            let def = cell_defs[ci]
            let old_cell = row.cells[ci]
            ignore(def.right_boundary - def.left_boundary)
            new_cells.push(DocTableCell::{
              paragraphs: old_cell.paragraphs,
              meta: Some(def),
              col_index: old_cell.col_index,
              colspan: 1,
              rowspan: 1,
              hidden: false,
            })
            ci += 1
          }
          rows[ri] = TableRow::{
            cells: new_cells,
            grid_width_twips: if cell_defs.length() > 0 { cell_defs[cell_defs.length() - 1].right_boundary - cell_defs[0].left_boundary } else { 0 },
            row_height: rows[ri].row_height,
          }
        }
      }
    }
    None => ignore(0)
  }

  // Finalize merge grid (colspan, rowspan, hidden)
  finalize_table_grid(rows)

  TableBlock::{ rows, depth, table_state: pending_table_state }
}

///| Finalize table grid: compute horizontal merge (colspan) and vertical merge (rowspan)
fn finalize_table_grid(rows : Array[TableRow]) -> Unit {
  if rows.length() == 0 { return }

  // Find maximum column count across all rows
  let mut max_cols = 0
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut visible_count = 0
    for ci in 0..<row.cells.length() {
      if !row.cells[ci].hidden {
        visible_count += 1
      }
    }
    if visible_count > max_cols {
      max_cols = visible_count
    }
  }

  // Pass 1: Horizontal merge (colspan) based on merge values
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut ci = 0
    while ci < row.cells.length() {
      let cell = row.cells[ci]
      let merge_val = match cell.meta {
        Some(def) => def.merge
        None => 0
      }
      if merge_val == 1 {
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      } else if merge_val == 2 {
        let mut cs = 1
        let mut j = ci + 1
        while j < row.cells.length() {
          let next_cell = row.cells[j]
          let next_merge = match next_cell.meta {
            Some(def) => def.merge
            None => 0
          }
          if next_merge == 1 {
            rows[ri].cells[j] = DocTableCell::{
              paragraphs: next_cell.paragraphs,
              meta: next_cell.meta,
              col_index: next_cell.col_index,
              colspan: next_cell.colspan,
              rowspan: next_cell.rowspan,
              hidden: true,
            }
            cs = cs + 1
            j += 1
          } else {
            break
          }
        }
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      }
      ci += 1
    }
  }

  // Pass 2: Auto-colspan for rows with fewer cells than max_cols
  // When a row has fewer cells than max_cols, the last cell should span the remaining columns
  for ri in 0..<rows.length() {
    let row = rows[ri]
    let mut visible_count = 0
    for ci in 0..<row.cells.length() {
      if !row.cells[ci].hidden {
        visible_count += 1
      }
    }
    // If this row has fewer visible cells than max_cols, the last visible cell should span the difference
    if visible_count > 0 && visible_count < max_cols {
      let last_visible_idx = {
        let mut idx = -1
        for ci in 0..<row.cells.length() {
          if !row.cells[ci].hidden {
            idx = ci
          }
        }
        idx
      }
      if last_visible_idx >= 0 {
        let extra_cols = max_cols - visible_count
        let current_colspan = rows[ri].cells[last_visible_idx].colspan
        rows[ri].cells[last_visible_idx] = DocTableCell::{
          paragraphs: rows[ri].cells[last_visible_idx].paragraphs,
          meta: rows[ri].cells[last_visible_idx].meta,
          col_index: rows[ri].cells[last_visible_idx].col_index,
          colspan: current_colspan + extra_cols,
          rowspan: rows[ri].cells[last_visible_idx].rowspan,
          hidden: false,
        }
      }
    }
  }

  // Pass 3: Vertical merge (rowspan)
  for ri in 0..<rows.length() {
    let row = rows[ri]
    for ci in 0..<row.cells.length() {
      let cell = row.cells[ci]
      if cell.hidden { continue }
      let vmerge_val = match cell.meta {
        Some(def) => def.vert_merge
        None => 0
      }
      if vmerge_val == 1 {
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: cell.rowspan,
          hidden: true,
        }
      } else if vmerge_val > 1 {
        let mut rs = 1
        let mut k = ri + 1
        while k < rows.length() {
          let below_row = rows[k]
          let cell_col = cell.col_index
          let cell_span = cell.colspan
          let mut can_merge = true
          let mut col = cell_col
          while col < cell_col + cell_span {
            if col >= below_row.cells.length() {
              can_merge = false
              break
            }
            let below_cell = below_row.cells[col]
            let below_vmerge = match below_cell.meta {
              Some(def) => def.vert_merge
              None => 0
            }
            if below_vmerge != 1 {
              can_merge = false
              break
            }
            col += 1
          }
          if !can_merge { break }
          let mut col2 = cell_col
          while col2 < cell_col + cell_span {
            let below_cell = below_row.cells[col2]
            rows[k].cells[col2] = DocTableCell::{
              paragraphs: below_cell.paragraphs,
              meta: below_cell.meta,
              col_index: below_cell.col_index,
              colspan: below_cell.colspan,
              rowspan: below_cell.rowspan,
              hidden: true,
            }
            col2 += 1
          }
          rs = rs + 1
          k += 1
        }
        rows[ri].cells[ci] = DocTableCell::{
          paragraphs: cell.paragraphs,
          meta: cell.meta,
          col_index: cell.col_index,
          colspan: cell.colspan,
          rowspan: rs,
          hidden: false,
        }
      }
    }
  }
}

///| Simplified CHPX run reading
fn read_chpx_runs_fallback(word_bytes : FixedArray[Byte], table_bytes : FixedArray[Byte], main_story_end : Int, pieces : Array[PieceEntry]) -> Array[ChpxRun] {
  let fib_reader = BinaryReader::make(word_bytes)
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  let fc_chpx = fib_reader.u32(fib_rgfc_lcb_start + 12 * 8)
  let lcb_chpx = fib_reader.u32(fib_rgfc_lcb_start + 12 * 8 + 4)
  if lcb_chpx <= 0 || fc_chpx < 0 { return [] }

  let bytes_view = table_bytes.view(start=fc_chpx, end=fc_chpx + lcb_chpx)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb_chpx - 4) / 8
  if count <= 0 { return [] }

  let pages : Array[Int] = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  let runs : Array[ChpxRun] = Array::new()
  for pn in pages {
    let offset : Int = pn * 512
    if offset + 512 > word_bytes.length() { continue }
    let page_reader = BinaryReader::from_view(word_bytes.view(start=offset, end=offset + 512))
    let crun = page_reader.u8(511)
    if crun == 0 || crun > 200 { continue }

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
      if cp_start >= main_story_end { continue }
      let b = page_reader.u8(rgb_start + i)
      let chpx_offset = if b > 0 { offset + b * 2 } else { 0 }
      let properties = if chpx_offset > 0 { read_chpx_decoded(word_bytes, chpx_offset) } else { [] }
      runs.push(ChpxRun::{
        cp_start,
        cp_end: if cp_end > main_story_end { main_story_end } else { cp_end },
        fc_start,
        fc_end,
        properties,
      })
    }
  }
  runs
}

///| Simplified PAPX run reading
fn read_papx_runs_fallback(word_bytes : FixedArray[Byte], table_bytes : FixedArray[Byte], main_story_end : Int, pieces : Array[PieceEntry]) -> Array[PapxRun] {
  let fib_reader = BinaryReader::make(word_bytes)
  let csw = fib_reader.u16(32)
  let cslw_offset = 34 + csw * 2
  let cslw = fib_reader.u16(cslw_offset)
  let cb_rgfc_lcb_offset = cslw_offset + 2 + cslw * 4
  let fib_rgfc_lcb_start = cb_rgfc_lcb_offset + 2

  // PlcfBtePapx is entry 13 in FibRgFcLcb
  let fc_papx = fib_reader.u32(fib_rgfc_lcb_start + 13 * 8)
  let lcb_papx = fib_reader.u32(fib_rgfc_lcb_start + 13 * 8 + 4)
  if lcb_papx <= 0 || fc_papx < 0 { return [] }

  let bytes_view = table_bytes.view(start=fc_papx, end=fc_papx + lcb_papx)
  let reader = BinaryReader::from_view(bytes_view)
  let count = (lcb_papx - 4) / 8
  if count <= 0 { return [] }

  let pages : Array[Int] = Array::new()
  let pn_offset = (count + 1) * 4
  for i in 0..<count {
    pages.push(reader.u32(pn_offset + i * 4) & 0x3FFFFF)
  }

  // FKP pages are in the TABLE stream

  let runs : Array[PapxRun] = Array::new()
  for pn in pages {
    let offset : Int = pn * 512
    if offset + 512 > word_bytes.length() { continue }
    let page_reader = BinaryReader::from_view(word_bytes.view(start=offset, end=offset + 512))
    let cpara = page_reader.u8(511)
    if cpara > 0x1D { continue }

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
      if cp_start >= main_story_end { continue }
      let b_offset = page_reader.u8(bx_start + i * 13)
      let papx_offset = if b_offset > 0 { offset + b_offset * 2 } else { 0 }
      let (style_id, properties) = if papx_offset > 0 {
        read_papx_properties(word_bytes, papx_offset)
      } else {
        (0, [])
      }
      runs.push(PapxRun::{
        cp_start,
        cp_end: if cp_end > main_story_end { main_story_end } else { cp_end },
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

///| Piece table entry for FC to CP mapping
struct PieceEntry {
  cp_start : Int
  cp_end : Int
  fc_start : Int
  fc_end : Int
  compressed : Bool
}

///| Convert FC to CP using piece table
///| fc may be a raw FC value (with compressed bit 30 set) from FKP rgfc arrays
fn fc_to_cp(pieces : Array[PieceEntry], fc : Int) -> Int {
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
  // Not found 锟?fallback: try with raw value as actual byte offset
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
  // Not found 锟?fallback: estimate
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

///| Parse MS-DOC file with deferred image processing
///| Returns a DeferredParseResult that allows async image extraction
///| This is the fastest parse option 锟?images are placeholders until extracted
pub fn parse_ms_doc_deferred(input : FixedArray[Byte]) -> DeferredParseResult raise {
  let result = parse_ms_doc(input)
  DeferredParseResult::{
    result,
    data_bytes: input,
    image_config: default_image_config(),
    image_cache: Map([], capacity=16),
  }
}

///| Parse MS-DOC file with deferred image processing and custom config
pub fn parse_ms_doc_deferred_with_config(
  input : FixedArray[Byte],
  config : ImageProcessorConfig,
) -> DeferredParseResult raise {
  let result = parse_ms_doc(input)
  DeferredParseResult::{
    result,
    data_bytes: input,
    image_config: config,
    image_cache: Map([], capacity=16),
  }
}

///| Extract a single image from a deferred parse result
///| Uses cache to avoid re-extracting the same image
pub fn extract_deferred_image(
  deferred : DeferredParseResult,
  asset_index : Int,
) -> Option[Asset] {
  if asset_index < 0 || asset_index >= deferred.result.assets.length() {
    return None
  }
  let asset = deferred.result.assets[asset_index]
  // Check if already processed (not a placeholder)
  if !asset.data_url.has_prefix("data:image/svg+xml;base64,") {
    return Some(asset)
  }
  // Check cache first
  match deferred.image_cache.get(asset_index) {
    Some(cached) => return Some(cached)
    None => ()
  }
  // Process raw image bytes if available
  if asset.bytes.length() > 0 {
    let processed = process_raw_image_asset(asset)
    deferred.image_cache.set(asset_index, processed)
    return Some(processed)
  }
  None
}

///| Extract all images from a deferred parse result
///| Returns a new array with processed images
pub fn extract_all_deferred_images(
  deferred : DeferredParseResult,
) -> Array[Asset] raise {
  let result : Array[Asset] = Array::new()
  let mut i = 0
  while i < deferred.result.assets.length() {
    match extract_deferred_image(deferred, i) {
      Some(processed) => result.push(processed)
      None => result.push(deferred.result.assets[i])
    }
    i += 1
  }
  result
}

///| Get the parse result from a deferred parse
pub fn get_deferred_result(deferred : DeferredParseResult) -> MsDocParseResult {
  deferred.result
}

///| Check if an asset is a placeholder (needs async extraction)
pub fn is_placeholder_asset(asset : Asset) -> Bool {
  // Asset is a placeholder if it has raw bytes but:
  // 1. data_url is a SVG placeholder, OR
  // 2. data_url is empty (not yet processed)
  asset.bytes.length() > 0 && (asset.data_url.has_prefix("data:image/svg+xml;base64,") || asset.data_url.length() == 0)
}

///| Count placeholder assets in a parse result
pub fn count_placeholder_assets(assets : Array[Asset]) -> Int {
  let mut count = 0
  for asset in assets {
    if is_placeholder_asset(asset) {
      count += 1
    }
  }
  count
}

///| Preload all images from a parse result (blocking)
///| Processes all raw image assets
///| Uses content-signature dedup to avoid redundant processing
pub fn preload_all_images(result : MsDocParseResult) -> Array[Asset] {
  let processed : Array[Asset] = Array::new()
  for i in 0..<result.assets.length() {
    let asset = result.assets[i]
    if asset.data_url.length() > 0 && !is_placeholder_asset(asset) {
      processed.push(asset)
    } else if asset.bytes.length() > 0 {
      match result.image_cache.get(i) {
        Some(cached) => processed.push(cached)
        None => {
          // Check content-signature dedup
          let sig = compute_asset_signature(asset.bytes)
          match result.content_dedup_cache.get(sig) {
            Some(cached) => {
              result.image_cache.set(i, cached)
              processed.push(cached)
            }
            None => {
              let p = process_raw_image_asset(asset)
              result.image_cache.set(i, p)
              result.content_dedup_cache.set(sig, p)
              processed.push(p)
            }
          }
        }
      }
    } else {
      processed.push(asset)
    }
  }
  processed
}

///| Extract image with fallback mechanism
///| Processes raw image bytes stored in asset during parse
///| Uses content-signature dedup to avoid redundant processing of identical images
pub fn extract_image_with_fallback(
  result : MsDocParseResult,
  asset_index : Int,
) -> Asset {
  if asset_index < 0 || asset_index >= result.assets.length() {
    return Asset::{ id: "", asset_type: "", name: "", mime: "", bytes: [], data_url: "", width: 0, height: 0 }
  }
  let asset = result.assets[asset_index]
  // If already has real data_url, return as-is
  if asset.data_url.length() > 0 && !is_placeholder_asset(asset) {
    return asset
  }
  // If has raw bytes, process them
  if asset.bytes.length() > 0 {
    // Check per-index cache first
    match result.image_cache.get(asset_index) {
      Some(cached) => return cached
      None => ()
    }
    // Check content-signature dedup cache
    let sig = compute_asset_signature(asset.bytes)
    match result.content_dedup_cache.get(sig) {
      Some(cached) => {
        // Same content already processed 鈥?reuse result
        result.image_cache.set(asset_index, cached)
        return cached
      }
      None => ()
    }
    // Process raw image
    let processed = process_raw_image_asset(asset)
    result.image_cache.set(asset_index, processed)
    result.content_dedup_cache.set(sig, processed)
    return processed
  }
  // Fallback: return placeholder
  asset
}
