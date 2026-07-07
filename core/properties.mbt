///| Property state converters for MS-DOC files

///|
/// Character state
pub struct CharState {
  bold : Bool
  italic : Bool
  underline : Int
  strike : Bool
  double_strike : Bool
  font_size : Int
  font_family_id : Int
  font_family : String
  color : Int
  highlight : Int
  superscript : Bool
  subscript : Bool
  hidden : Bool
  small_caps : Bool
  caps : Bool
  outline : Bool
  shadow : Bool
  emboss : Bool
  imprint : Bool
  spacing : Int
  position_half_points : Int
  scale : Int
  picture_offset : Int
  rtl : Bool
  bold_bi : Bool
  italic_bi : Bool
  char_style_id : Int
  is_ole2 : Bool
  is_data : Bool
  is_object : Bool
}

///|
/// Paragraph state
pub struct ParaState {
  align : Int
  indent_left : Int
  indent_right : Int
  indent_first : Int
  space_before : Int
  space_after : Int
  line_spacing : Int
  keep_with_next : Bool
  keep_together : Bool
  page_break_before : Bool
  widow_control : Bool
  tab_stops : Array[Int]
  style_id : Int
  itap : Int
  table_row_end : Bool
  inner_table_cell : Bool
  inner_table_row_end : Bool
  in_table : Bool
  dtap : Int
  list_level : Int
  list_id : Int
  rtl_para : Bool
  adjust_right : Bool
  border_top : Int
  border_left : Int
  border_bottom : Int
  border_right : Int
  border_between : Int
  border_bar : Int
  shading : Int
  frame_left : Int
  frame_top : Int
  frame_width : Int
  frame_height : Int
  frame_position : Int
  frame_wrap : Int
  spacing_before_auto : Bool
  spacing_after_auto : Bool
  distance_from_text_y : Int
  distance_from_text_x : Int
  locked : Bool
  outline_level : Int
}

///|
/// Table state
pub struct TableState {
  style_id : Int
  indent : Int
  cell_margins : Array[Int]
  grid_columns : Array[Int]
  left_indent : Int
  row_height : Int
  alignment : Int
  table_width : Int
  def_table_bytes : Array[Byte]
  operations : Array[DecodedProperty]
  table_shading : Int
  cell_padding : Array[Int]
}

///|
/// Convert character properties to state
pub fn char_props_to_state(props : Array[Byte]) -> CharState {
  let view = props.view()
  let decoded = decode_grpprl(view)
  char_props_from_decoded(decoded)
}

///|
/// Convert decoded SPRMs to character state
pub fn char_props_from_decoded(decoded : Array[DecodedProperty]) -> CharState {
  let mut bold = false
  let mut italic = false
  let mut underline = 0
  let mut strike = false
  let mut double_strike = false
  let mut font_size = 21
  let mut font_family_id = 0
  let mut color = 0
  let mut highlight = 0
  let superscript = false
  let subscript = false
  let mut hidden = false
  let mut small_caps = false
  let mut caps = false
  let mut outline = false
  let mut shadow = false
  let mut emboss = false
  let mut imprint = false
  let mut spacing = 0
  let mut position_half_points = 0
  let mut scale = 100
  let mut picture_offset = 0
  let mut rtl = false
  let mut bold_bi = false
  let mut italic_bi = false
  let mut char_style_id = 0
  let mut is_ole2 = false
  let mut is_data = false
  let mut is_object = false

  for prop in decoded {
    match prop.name {
      "plain" => {
        bold = false
        italic = false
        strike = false
        underline = 0
        small_caps = false
        caps = false
      }
      "fBold" => bold = prop.value != 0
      "fItalic" => italic = prop.value != 0
      "fStrike" => strike = prop.value != 0
      "fDStrike" => double_strike = prop.value != 0
      "fOutline" => outline = prop.value != 0
      "fShadow" => shadow = prop.value != 0
      "fEmboss" => emboss = prop.value != 0
      "fImprint" => imprint = prop.value != 0
      "fSmallCaps" => small_caps = prop.value != 0
      "fCaps" => caps = prop.value != 0
      "fVanish" => hidden = prop.value != 0
      "fRtl" => rtl = prop.value != 0
      "fData" => is_data = prop.value != 0
      "fOle2" => is_ole2 = prop.value != 0
      "fObj" => is_object = prop.value != 0
      "fSpec" => ignore(prop.value)
      "fBoldBi" => bold_bi = prop.value != 0
      "fItalicBi" => italic_bi = prop.value != 0
      "kul" => underline = prop.value
      "hps" => font_size = prop.value
      "hpsBi" => font_size = prop.value
      "rgFtc0" => font_family_id = prop.value
      "rgFtc2" => font_family_id = prop.value
      "ico" => color = prop.value
      "highlight" => highlight = prop.value
      "hpsPos" => position_half_points = prop.value
      "dxaSpace" => spacing = prop.value
      "charScale" => scale = prop.value
      "cpicLocation" => picture_offset = prop.value
      "picLocation" => picture_offset = prop.value
      "istd" => char_style_id = prop.value
      _ => ignore(prop.value)
    }
  }

  CharState::{
    bold,
    italic,
    underline,
    strike,
    double_strike,
    font_size,
    font_family_id,
    font_family: "",
    color,
    highlight,
    superscript,
    subscript,
    hidden,
    small_caps,
    caps,
    outline,
    shadow,
    emboss,
    imprint,
    spacing,
    position_half_points,
    scale,
    picture_offset,
    rtl,
    bold_bi,
    italic_bi,
    char_style_id,
    is_ole2,
    is_data,
    is_object,
  }
}

///|
/// Convert paragraph properties to state
pub fn para_props_to_state(props : Array[Byte]) -> ParaState {
  let view = props.view()
  let decoded = decode_grpprl(view)
  para_props_from_decoded(decoded)
}

///|
/// Convert decoded SPRMs to paragraph state
pub fn para_props_from_decoded(decoded : Array[DecodedProperty]) -> ParaState {
  let mut align = 0
  let mut indent_left = 0
  let mut indent_right = 0
  let mut indent_first = 0
  let mut space_before = 0
  let mut space_after = 0
  let mut line_spacing = 240
  let mut keep_with_next = false
  let mut keep_together = false
  let mut page_break_before = false
  let mut widow_control = false
  let mut style_id = 0
  let mut itap = 0
  let mut table_row_end = false
  let mut inner_table_cell = false
  let mut inner_table_row_end = false
  let mut in_table = false
  let mut dtap = 0
  let mut list_level = 0
  let mut list_id = 0
  let mut rtl_para = false
  let mut adjust_right = false
  let mut border_top = 0
  let mut border_left = 0
  let mut border_bottom = 0
  let mut border_right = 0
  let mut border_between = 0
  let mut border_bar = 0
  let mut shading = 0
  let mut frame_left = 0
  let mut frame_top = 0
  let mut frame_width = 0
  let frame_height = 0
  let mut frame_position = 0
  let frame_wrap = 0
  let mut spacing_before_auto = false
  let mut spacing_after_auto = false
  let mut distance_from_text_y = 0
  let mut distance_from_text_x = 0
  let mut locked = false
  let mut outline_level = 9

  for prop in decoded {
    match prop.name {
      "istdPara" => style_id = prop.value
      "istd" => style_id = prop.value
      "jc" => align = prop.value
      "jc80" => align = prop.value
      "jc90" => align = prop.value
      "dyaBefore" => space_before = prop.value
      "dyaAfter" => space_after = prop.value
      "dyaLine" => {
        let raw16 = prop.value.land(0xFFFF)
        line_spacing = if raw16 > 0x7FFF { raw16 - 0x10000 } else { raw16 }
      }
      "dxaLeft" => indent_left = prop.value
      "dxaLeft80" => indent_left = prop.value
      "dxaRight" => indent_right = prop.value
      "dxaRight80" => indent_right = prop.value
      "dxaLeft1" => indent_first = prop.value
      "dxaLeft180" => indent_first = prop.value
      "fKeep" => keep_together = prop.value != 0
      "fKeepFollow" => keep_with_next = prop.value != 0
      "fPageBreakBefore" => page_break_before = prop.value != 0
      "fWidowControl" => widow_control = prop.value != 0
      "fInTable" => in_table = prop.value != 0
      "fTtp" => table_row_end = prop.value != 0
      "fInnerTableCell" => inner_table_cell = prop.value != 0
      "fInnerTableRowEnd" => inner_table_row_end = prop.value != 0
      "fBiDiPara" => rtl_para = prop.value != 0
      "fAdjustRight" => adjust_right = prop.value != 0
      "itap" => itap = prop.value
      "dtap" => dtap = prop.value
      "ilfo" => list_id = prop.value
      "ilvl" => list_level = prop.value
      "incLvl" => {
        list_level = prop.value.land(0x0f)
        style_id = prop.value.land(0x0f)
      }
      "brcTop" => border_top = prop.value
      "brcLeft" => border_left = prop.value
      "brcBottom" => border_bottom = prop.value
      "brcRight" => border_right = prop.value
      "brcBetween" => border_between = prop.value
      "brcBar" => border_bar = prop.value
      "shd" => shading = prop.value
      "shd80" => shading = prop.value
      "dxaAbs" => frame_left = prop.value
      "dyaAbs" => frame_top = prop.value
      "dxaWidth" => frame_width = prop.value
      "dyaFromText" => distance_from_text_y = prop.value
      "dxaFromText" => distance_from_text_x = prop.value
      "fLocked" => locked = prop.value != 0
      "outLvl" => outline_level = prop.value
      "fDyaBeforeAuto" => spacing_before_auto = prop.value != 0
      "fDyaAfterAuto" => spacing_after_auto = prop.value != 0
      "pc90" => frame_position = prop.value
      _ => ignore(prop.value)
    }
  }

  ParaState::{
    align,
    indent_left,
    indent_right,
    indent_first,
    space_before,
    space_after,
    line_spacing,
    keep_with_next,
    keep_together,
    page_break_before,
    widow_control,
    tab_stops: [],
    style_id,
    itap,
    table_row_end,
    inner_table_cell,
    inner_table_row_end,
    in_table,
    dtap,
    list_level,
    list_id,
    rtl_para,
    adjust_right,
    border_top,
    border_left,
    border_bottom,
    border_right,
    border_between,
    border_bar,
    shading,
    frame_left,
    frame_top,
    frame_width,
    frame_height,
    frame_position,
    frame_wrap,
    spacing_before_auto,
    spacing_after_auto,
    distance_from_text_y,
    distance_from_text_x,
    locked,
    outline_level,
  }
}

///|
/// Convert decoded table properties to state with style inheritance support
pub fn table_props_from_decoded(decoded : Array[DecodedProperty]) -> TableState {
  table_props_from_decoded_impl(decoded, [])
}

///|
/// Internal: extract table state from decoded properties
fn table_props_from_decoded_impl(
  decoded : Array[DecodedProperty],
  raw_bytes : Array[Byte],
) -> TableState {
  let mut style_id = 0
  let mut left_indent = 0
  let mut row_height = 0
  let mut alignment = 0
  let mut def_table_bytes : Array[Byte] = []
  let mut table_shading = 0
  let mut cell_padding_left = 0
  let mut cell_padding_right = 0
  let mut cell_padding_top = 0
  let mut cell_padding_bottom = 0

  // Extract raw defTable bytes by scanning the raw grpprl bytes
  if raw_bytes.length() > 0 {
    let mut offset = 0
    while offset + 2 <= raw_bytes.length() {
      let sprm = raw_bytes[offset].to_int() |
        (raw_bytes[offset + 1].to_int() << 8)
      let op_type = sprm.lsr(13).land(0x7)
      if sprm == 0xd608 {
        let cb = if offset + 4 <= raw_bytes.length() {
          raw_bytes[offset + 2].to_int() | (raw_bytes[offset + 3].to_int() << 8)
        } else {
          0
        }
        let total_skip = cb + 1
        if offset + 2 + total_skip <= raw_bytes.length() {
          let data_start = offset + 2
          def_table_bytes = Array::makei(total_skip, fn(i) {
            raw_bytes[data_start + i]
          })
        }
        offset += 2 + total_skip
      } else if op_type == 6 {
        let data_len = if offset + 2 < raw_bytes.length() {
          raw_bytes[offset + 2].to_int() + 1
        } else {
          0
        }
        offset += 2 + data_len
      } else {
        let operand_len = get_sprm_operand_length(sprm)
        offset += 2 + operand_len
      }
    }
  }

  let mut table_width = 0

  for prop in decoded {
    match prop.name {
      "jc90" => alignment = prop.value
      "dxaLeft90" => left_indent = prop.value
      "dyaRowHeight" => row_height = prop.value
      "istd90" => style_id = prop.value
      "tableWidth" => table_width = prop.value
      "setShdTable" => table_shading = prop.value
      "cellPadding" => {
        // Extract padding from packed value
        // w_width is in low 16 bits, grfbrc in bits 19-22
        let w_width = prop.value & 0xFFFF
        let grfbrc = (prop.value >> 19) & 0xF
        // grfbrc: 0x01=top, 0x02=left, 0x04=bottom, 0x08=right
        if (grfbrc & 0x01) != 0 {
          cell_padding_top = w_width
        }
        if (grfbrc & 0x02) != 0 {
          cell_padding_left = w_width
        }
        if (grfbrc & 0x04) != 0 {
          cell_padding_bottom = w_width
        }
        if (grfbrc & 0x08) != 0 {
          cell_padding_right = w_width
        }
      }
      "cellPaddingDefault" => {
        // Extract padding from packed value
        let w_width = prop.value & 0xFFFF
        let grfbrc = (prop.value >> 19) & 0xF
        if (grfbrc & 0x01) != 0 {
          cell_padding_top = w_width
        }
        if (grfbrc & 0x02) != 0 {
          cell_padding_left = w_width
        }
        if (grfbrc & 0x04) != 0 {
          cell_padding_bottom = w_width
        }
        if (grfbrc & 0x08) != 0 {
          cell_padding_right = w_width
        }
      }
      _ => ignore(prop.value)
    }
  }

  TableState::{
    style_id,
    indent: left_indent,
    cell_margins: [],
    grid_columns: [],
    left_indent,
    row_height,
    alignment,
    table_width,
    def_table_bytes,
    operations: decoded,
    table_shading,
    cell_padding: [
      cell_padding_top, cell_padding_left, cell_padding_bottom, cell_padding_right,
    ],
  }
}

///|
/// Table cell definition from defTable bytes
pub struct TableCellDef {
  index : Int
  width : Int
  left_boundary : Int
  right_boundary : Int
  merge : Int
  vert_merge : Int
  vert_align : Int
  borders : Array[Byte]
  shading : Array[Byte]
  fit_text : Bool
  no_wrap : Bool
  hide_mark : Bool
  text_flow : Int
}

///|
/// Apply a callback to a range of table cells
fn range_apply_cells(
  cells : Array[TableCellDef],
  first : Int,
  lim : Int,
  callback : (TableCellDef, Int) -> TableCellDef,
) -> Unit {
  let f = if first < 0 { 0 } else { first }
  let l = if lim < f { f } else { lim }
  let mut i = f
  while i < l && i < cells.length() {
    cells[i] = callback(cells[i], i)
    i += 1
  }
}

///|
/// Apply table state to cells
pub fn apply_table_state_to_cells(
  table_state : TableState,
) -> Array[TableCellDef] {
  let bytes = table_state.def_table_bytes
  if bytes.length() < 4 {
    return []
  }

  let reader = BinaryReader::from_view(bytes.view())
  let cb = reader.u16(0)
  let num_cols = reader.u8(2)

  if num_cols <= 0 || bytes.length() < cb + 1 {
    return []
  }

  // Read rgdxaCenter: (numCols+1) x i16
  let rgdxa_start = 3
  let cells = Array::new()

  let tc80_start = rgdxa_start + (num_cols + 1) * 2
  let tc_record_size = 20

  for i in 0..<num_cols {
    let left_boundary = reader.i16(rgdxa_start + i * 2)
    let right_boundary = reader.i16(rgdxa_start + (i + 1) * 2)
    let width = right_boundary - left_boundary

    let tc_offset = tc80_start + i * tc_record_size
    let tcgrf = reader.u16(tc_offset)
    let horz_merge = tcgrf.land(0x3)
    let vert_merge = tcgrf.lsr(5).land(0x3)
    let vert_align = tcgrf.lsr(7).land(0x3)
    let w_width = reader.u16(tc_offset + 2)

    let mut borders : Array[Byte] = []
    if tc_offset + 4 + 16 <= bytes.length() {
      borders = Array::makei(16, fn(j) { bytes[tc_offset + 4 + j] })
    }

    let shading : Array[Byte] = []
    let fit_text = false
    let no_wrap = false
    let text_flow = tcgrf.lsr(2).land(0x7)
    let hide_mark = tcgrf.land(0x4000) != 0

    cells.push(TableCellDef::{
      index: i,
      width: if w_width > 0 {
        w_width
      } else {
        width
      },
      left_boundary,
      right_boundary,
      merge: horz_merge,
      vert_merge,
      vert_align,
      borders,
      shading,
      fit_text,
      no_wrap,
      hide_mark,
      text_flow,
    })
  }

  // Helper to get range from operation (uses parsed range if available, else bit-pack)
  let get_range = fn(op : DecodedProperty) -> (Int, Int) {
    match op.range {
      Some(r) => (r.first, r.lim)
      None => (op.value.land(0xFF), op.value.lsr(8).land(0xFF))
    }
  }

  // Process operations from table state
  for op in table_state.operations {
    let (first, lim) = get_range(op)
    match op.name {
      "merge" =>
        range_apply_cells(cells, first, lim, fn(cell, idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: if idx == first {
              2
            } else {
              1
            },
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      "split" =>
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: 0,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      "cellWidth" => {
        // Use parsed range+width if available
        let width = match op.range {
          Some(_r) =>
            // value was packed as fts_width | (width << 8), extract width
            op.value.lsr(8)
          None => op.value.lsr(16)
        }
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "vertMerge" => {
        let vmerge = op.value.land(0xFF)
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: vmerge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "vertAlign" => {
        let valign = op.value.land(0xFF)
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: valign,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "setBrc" => {
        // Use parsed operand bytes if available, else fall back to bit-pack
        let new_brc : Array[Byte] = match op.operand_bytes {
          Some(brc) => brc
          None => {
            let brc = op.value.lsr(16)
            if brc == 0 {
              []
            } else {
              Array::makei(4, fn(j) { brc.lsr(j * 8).land(0xFF).to_byte() })
            }
          }
        }
        // Merge with existing borders: only overwrite non-zero bytes from new Brc80
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          let merged_borders : Array[Byte] = if new_brc.length() >= 4 &&
            cell.borders.length() >= 16 {
            // Apply new_brc to all 4 border sides (top/left/bottom/right), merging non-zero bytes
            Array::makei(16, fn(j) {
              let side_offset = j / 4 * 4
              let new_val = new_brc[j - side_offset]
              if new_val != 0 {
                new_val
              } else {
                cell.borders[j]
              }
            })
          } else if new_brc.length() >= 4 {
            new_brc
          } else {
            cell.borders
          }
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: merged_borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "setShd" => {
        let shd = op.value.land(0xFFFFFF)
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: Array::makei(4, fn(j) {
              shd.lsr(j * 8).land(0xFF).to_byte()
            }),
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "fitText" => {
        let fit = op.value != 0
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: fit,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "fCellNoWrap" => {
        let nowrap = op.value != 0
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: nowrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "dxaCol" => {
        let col_width = op.value.land(0xFFFF)
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: col_width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: cell.text_flow,
          }
        })
      }
      "textFlow" => {
        let tflow = op.value.land(0x7)
        range_apply_cells(cells, first, lim, fn(cell, _idx) {
          TableCellDef::{
            index: cell.index,
            width: cell.width,
            left_boundary: cell.left_boundary,
            right_boundary: cell.right_boundary,
            merge: cell.merge,
            vert_merge: cell.vert_merge,
            vert_align: cell.vert_align,
            borders: cell.borders,
            shading: cell.shading,
            fit_text: cell.fit_text,
            no_wrap: cell.no_wrap,
            hide_mark: cell.hide_mark,
            text_flow: tflow,
          }
        })
      }
      _ => ignore(op.value)
    }
  }

  cells
}

///|
/// CSS text align
pub fn css_text_align(value : Int) -> String {
  alignment_css(value)
}

///|
/// CSS underline
pub fn css_underline(value : Int) -> String {
  underline_name(value)
}

///|
/// CSS vertical align
pub fn css_vertical_align(value : Int) -> String {
  vertical_align_css(value)
}

///|
/// COLOR_INDEX_MAP - standard Word color index to hex
pub fn color_index_to_hex(index : Int) -> String {
  match index {
    0 => "#666"
    1 => "#000000"
    2 => "#0000ff"
    3 => "#00ffff"
    4 => "#00ff00"
    5 => "#ff00ff"
    6 => "#ff0000"
    7 => "#ffff00"
    8 => "#ffffff"
    9 => "#000080"
    10 => "#008080"
    11 => "#008000"
    12 => "#800080"
    13 => "#800000"
    14 => "#808000"
    15 => "#808080"
    16 => "#c0c0c0"
    _ => "#666"
  }
}

///|
/// HIGHLIGHT_COLOR_MAP - highlight index to background color
pub fn highlight_color_to_hex(index : Int) -> String {
  match index {
    0 => ""
    1 => "#000000"
    2 => "#0000FF"
    3 => "#00FFFF"
    4 => "#00FF00"
    5 => "#FF00FF"
    6 => "#FF0000"
    7 => "#FFFF00"
    8 => "#FFFFFF"
    9 => "#000080"
    10 => "#008080"
    11 => "#008000"
    12 => "#800080"
    13 => "#800000"
    14 => "#808000"
    15 => "#808080"
    16 => "#C0C0C0"
    _ => ""
  }
}
