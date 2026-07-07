///| Section properties parsing

///| Extracted from parser.mbt for better organization

///|
/// Parse PlcfSed to get section boundaries and properties
pub fn parse_sections(
  fib_reader : BinaryReader,
  fib_rgfc_lcb_start : Int,
  table_bytes : FixedArray[Byte],
  word_bytes : FixedArray[Byte],
) -> Array[SectionProperties] {
  let sections = Array::new()
  let fc_plcf_sed = fib_reader.u32(fib_rgfc_lcb_start + 6 * 8)
  let lcb_plcf_sed = fib_reader.u32(fib_rgfc_lcb_start + 6 * 8 + 4)

  if lcb_plcf_sed <= 0 || fc_plcf_sed + lcb_plcf_sed > table_bytes.length() {
    return sections
  }

  let sed_view = table_bytes.view(
    start=fc_plcf_sed,
    end=fc_plcf_sed + lcb_plcf_sed,
  )
  let sed_reader = BinaryReader::from_view(sed_view)
  // PlcfSed: (N+1) CPs + N Sed structures (12 bytes each)
  // Sed structure: fcSepx (4 bytes) + fnMpr (1 byte) + fcMpr (4 bytes) + fn (1 byte) + reserved (1 byte)
  let section_count_bytes = lcb_plcf_sed
  // Calculate N from: (N+1)*4 + N*12 = total_size => 16N + 4 = total_size => N = (total_size - 4) / 16
  let section_count = (section_count_bytes - 4) / 16

  if section_count <= 0 {
    return sections
  }

  // Read section boundary CPs
  let sed_cps = Array::new()
  for i in 0..<(section_count + 1) {
    sed_cps.push(sed_reader.u32(i * 4))
  }

  // Parse each section's SEPX for header/footer properties
  for s in 0..<section_count {
    let sed_offset = (section_count + 1) * 4 + s * 12
    let fc_sepx = sed_reader.u32(sed_offset)
    // fcSepx is an offset into the WordDocument stream
    // SEPX starts with 2-byte cb (size of grpprl) followed by Prl array

    let mut has_title_page = false
    let mut header_distance = 720
    let mut footer_distance = 720
    let mut break_type = 2
    let mut page_width = 12240 // 8.5 inches
    let mut page_height = 15840 // 11 inches
    let mut orientation = 0 // portrait
    let mut margin_top = 1440 // 1 inch
    let mut margin_bottom = 1440
    let mut margin_left = 1800 // 1.25 inches
    let mut margin_right = 1800
    let mut column_count = 1
    let mut column_spacing = 720 // 0.5 inch

    if fc_sepx > 0 && fc_sepx + 2 <= word_bytes.length() {
      let sepx_reader = BinaryReader::make(word_bytes)
      let cb = sepx_reader.u16(fc_sepx)
      let grpprl_start = fc_sepx + 2
      let grpprl_end = grpprl_start + cb
      let mut prl_offset = grpprl_start

      while prl_offset + 2 <= grpprl_end &&
            prl_offset + 2 <= word_bytes.length() {
        let sprm = sepx_reader.u16(prl_offset)
        let sprm_group = (sprm >> 13) & 0x7
        let sprm_opcode = (sprm >> 4) & 0x1FF
        let sprm_size = sprm.land(0xF)

        // Section SPRMs (group 3)
        if sprm_group == 3 {
          match sprm_opcode {
            0x09 =>
              if prl_offset + 3 <= grpprl_end {
                break_type = sepx_reader.u8(prl_offset + 2)
              }
            0x0A =>
              if prl_offset + 3 <= grpprl_end {
                has_title_page = sepx_reader.u8(prl_offset + 2) != 0
              }
            0x19 =>
              if prl_offset + 4 <= grpprl_end {
                page_width = sepx_reader.u16(prl_offset + 2)
              }
            0x1A =>
              if prl_offset + 4 <= grpprl_end {
                page_height = sepx_reader.u16(prl_offset + 2)
              }
            0x1B =>
              if prl_offset + 3 <= grpprl_end {
                orientation = sepx_reader.u8(prl_offset + 2)
              }
            0x12 =>
              if prl_offset + 3 <= grpprl_end {
                column_count = sepx_reader.u8(prl_offset + 2).land(0xFF) + 1
              }
            _ => ()
          }
        }

        // Signed YAS SPRMs for margins (group 3, opcode 0x23-0x26)
        if sprm_group == 3 && sprm_opcode >= 0x23 && sprm_opcode <= 0x26 {
          if prl_offset + 4 <= grpprl_end {
            let val = sepx_reader.u16(prl_offset + 2)
            match sprm_opcode {
              0x23 => margin_top = val
              0x24 => margin_bottom = val
              0x25 => margin_left = val
              0x26 => margin_right = val
              _ => ()
            }
          }
        }

        // YAS SPRMs for header/footer distances (group 3, opcode 0x17-0x18)
        if sprm_group == 3 {
          match sprm_opcode {
            0x17 =>
              if prl_offset + 4 <= grpprl_end {
                header_distance = sepx_reader.u16(prl_offset + 2)
              }
            0x18 =>
              if prl_offset + 4 <= grpprl_end {
                footer_distance = sepx_reader.u16(prl_offset + 2)
              }
            _ => ()
          }
        }

        // Column spacing (group 3, opcode 0x1B area)
        if sprm_group == 3 && sprm_opcode == 0x1B {
          if prl_offset + 4 <= grpprl_end {
            column_spacing = sepx_reader.u16(prl_offset + 2)
          }
        }

        // Advance to next Prl
        let operand_size = if sprm_size == 0xF { // variable size
          if prl_offset + 3 < word_bytes.length() {
            word_bytes[prl_offset + 2].to_int() + 3
          } else {
            3
          }
        } else if sprm_size == 0xE { // 2-byte size
          4
        } else if sprm_size == 0xD { // 4-byte size
          6
        } else if sprm_size == 0xC { // 3-byte size
          5
        } else if sprm_size >= 1 && sprm_size <= 3 { // 0, 1, 2, 3 bytes
          2 + sprm_size
        } else {
          2 // fallback
        }
        prl_offset += operand_size
      }
    }

    sections.push(SectionProperties::{
      index: s,
      has_title_page,
      header_distance,
      footer_distance,
      break_type,
      page_width,
      page_height,
      orientation,
      margin_top,
      margin_bottom,
      margin_left,
      margin_right,
      column_count,
      column_spacing,
    })
  }

  sections
}
