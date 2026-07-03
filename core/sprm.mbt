///| SPRM (Single Property Modifier) decoder for MS-DOC files

///| Decoded property
pub struct DecodedProperty {
  name : String
  value : Int
  extra : String
  kind : String
  range : Option[ItcRange]
  operand_bytes : Option[Array[Byte]]
}

///| Column range (first, lim) from ItcFirstLim
pub struct ItcRange {
  first : Int
  lim : Int
}

///| Parsed Brc80 border record (4 bytes)
pub struct Brc80Data {
  raw : Int
  line_width : Int
  border_type : Int
  color : Int
}

///| Parsed Tcgrf cell flags (2 bytes)
pub struct TcgrfData {
  raw : Int
  horz_merge : Int
  text_flow : Int
  vert_merge : Int
  vert_align : Int
  fts_width : Int
  fit_text : Bool
  no_wrap : Bool
  hide_mark : Bool
}

///| Parsed Tc80 cell record (20 bytes)
pub struct Tc80Data {
  tcgrf : TcgrfData
  w_width : Int
  borders_top : Brc80Data
  borders_left : Brc80Data
  borders_bottom : Brc80Data
  borders_right : Brc80Data
}

///| Parsed TDefTable operand (sprmTDefTable 0xd608)
pub struct TDefTableOperand {
  cb : Int
  number_of_columns : Int
  rgdxa_center : Array[Int]
  cells : Array[Tc80Data]
}

///| Parsed range+value operand (for vertMerge, vertAlign, setShd, fitText, etc.)
pub struct RangeValueOperand {
  cb : Int
  range : ItcRange
  value : Int
}

///| Parsed range+width operand (for cellWidth, dxaCol, cellPadding, etc.)
pub struct RangeWidthOperand {
  cb : Int
  range : ItcRange
  fts_width : Int
  width : Int
}

///| Parsed range+brc operand (for setBrc)
pub struct RangeBrcOperand {
  cb : Int
  range : ItcRange
  border : Brc80Data
}

///| Parsed TTableWidth operand (for tableWidth, widthBefore, widthAfter)
pub struct TTableWidthOperand {
  fts_width : Int
  width : Int
}

///| Parse ItcFirstLim (2 bytes: first, lim)
pub fn parse_itc_first_lim(bytes : FixedArray[Byte], offset : Int) -> ItcRange {
  let first = if offset < bytes.length() { bytes[offset].to_int() } else { 0 }
  let lim = if offset + 1 < bytes.length() { bytes[offset + 1].to_int() } else { 0 }
  ItcRange::{ first, lim }
}

///| Parse ItcFirstLim from ArrayView (2 bytes: first, lim)
fn parse_itc_first_lim_bytes(bytes : ArrayView[Byte], offset : Int) -> ItcRange {
  let first = if offset < bytes.length() { bytes[offset].to_int() } else { 0 }
  let lim = if offset + 1 < bytes.length() { bytes[offset + 1].to_int() } else { 0 }
  ItcRange::{ first, lim }
}

///| Parse Brc80 border record (4 bytes)
pub fn parse_brc80(bytes : FixedArray[Byte], offset : Int) -> Brc80Data {
  if offset + 4 > bytes.length() {
    return Brc80Data::{ raw: 0, line_width: 0, border_type: 0, color: 0 }
  }
  let brc = bytes[offset].to_int() |
    (bytes[offset + 1].to_int() << 8) |
    (bytes[offset + 2].to_int() << 16) |
    (bytes[offset + 3].to_int() << 24)
  let line_width = brc & 0xff
  let border_type = brc >> 8 & 0xff
  let color = brc >> 16 & 0xff
  Brc80Data::{ raw: brc, line_width, border_type, color }
}

///| Parse Tcgrf cell flags (2 bytes)
pub fn parse_tcgrf(bytes : FixedArray[Byte], offset : Int) -> TcgrfData {
  let v = if offset + 2 <= bytes.length() {
    bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
  } else { 0 }
  TcgrfData::{
    raw: v,
    horz_merge: v & 0x3,
    text_flow: v >> 2 & 0x7,
    vert_merge: v >> 5 & 0x3,
    vert_align: v >> 7 & 0x3,
    fts_width: v >> 9 & 0x7,
    fit_text: (v & 1 << 12) != 0,
    no_wrap: (v & 1 << 13) != 0,
    hide_mark: (v & 1 << 14) != 0,
  }
}

///| Parse Tc80 cell record (20 bytes)
pub fn parse_tc80(bytes : FixedArray[Byte], offset : Int) -> Tc80Data {
  if offset + 20 > bytes.length() {
    return Tc80Data::{
      tcgrf: parse_tcgrf(bytes, 0),
      w_width: 0,
      borders_top: parse_brc80(bytes, 0),
      borders_left: parse_brc80(bytes, 0),
      borders_bottom: parse_brc80(bytes, 0),
      borders_right: parse_brc80(bytes, 0),
    }
  }
  Tc80Data::{
    tcgrf: parse_tcgrf(bytes, offset),
    w_width: if offset + 2 < bytes.length() {
      bytes[offset + 2].to_int() | (bytes[offset + 3].to_int() << 8)
    } else { 0 },
    borders_top: parse_brc80(bytes, offset + 4),
    borders_left: parse_brc80(bytes, offset + 8),
    borders_bottom: parse_brc80(bytes, offset + 12),
    borders_right: parse_brc80(bytes, offset + 16),
  }
}

///| Parse TDefTable operand (sprmTDefTable 0xd608)
/// operand bytes start with u16 cb, then numberOfColumns, rgdxaCenter, tc80 cells
pub fn parse_tdef_table_operand(bytes : FixedArray[Byte]) -> TDefTableOperand {
  if bytes.length() < 3 {
    return TDefTableOperand::{ cb: 0, number_of_columns: 0, rgdxa_center: [], cells: [] }
  }
  let cb = bytes[0].to_int() | (bytes[1].to_int() << 8)
  let num_cols = bytes[2].to_int()
  let rgdxa = Array::new()
  let mut offset = 3
  let mut i = 0
  while i < num_cols + 1 && offset + 2 <= bytes.length() {
    let val = bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
    rgdxa.push(if val >= 0x8000 { val - 0x10000 } else { val })
    offset += 2
    i += 1
  }
  let cells = Array::new()
  let mut j = 0
  while j < num_cols && offset + 20 <= bytes.length() {
    cells.push(parse_tc80(bytes, offset))
    offset += 20
    j += 1
  }
  TDefTableOperand::{ cb, number_of_columns: num_cols, rgdxa_center: rgdxa, cells }
}

///| Parse range+value operand (cb, first, lim, value)
/// Used by: vertMerge, vertAlign, setShd, setShdOdd, fitText, fCellNoWrap, textFlow
pub fn parse_range_value_operand(bytes : FixedArray[Byte]) -> RangeValueOperand {
  if bytes.length() < 1 {
    return RangeValueOperand::{ cb: 0, range: ItcRange::{ first: 0, lim: 0 }, value: 0 }
  }
  let cb = bytes[0].to_int()
  let range = parse_itc_first_lim(bytes, 1)
  let value = if bytes.length() > 3 { bytes[3].to_int() } else { 0 }
  RangeValueOperand::{ cb, range, value }
}

///| Parse range+width operand (cb, first, lim, ftsWidth, width)
/// Used by: cellWidth, dxaCol, cellPadding, cellPaddingDefault
pub fn parse_range_width_operand(bytes : FixedArray[Byte]) -> RangeWidthOperand {
  if bytes.length() < 1 {
    return RangeWidthOperand::{ cb: 0, range: ItcRange::{ first: 0, lim: 0 }, fts_width: 0, width: 0 }
  }
  let cb = bytes[0].to_int()
  let range = parse_itc_first_lim(bytes, 1)
  let fts_width = if bytes.length() > 3 { bytes[3].to_int() } else { 0 }
  let width = if bytes.length() > 5 {
    bytes[4].to_int() | (bytes[5].to_int() << 8)
  } else if bytes.length() > 4 {
    bytes[4].to_int()
  } else { 0 }
  RangeWidthOperand::{ cb, range, fts_width, width }
}

///| Parse range+brc operand (cb, first, lim, brc80)
/// Used by: setBrc, setBrc80
pub fn parse_range_brc_operand(bytes : FixedArray[Byte]) -> RangeBrcOperand {
  if bytes.length() < 1 {
    return RangeBrcOperand::{ cb: 0, range: ItcRange::{ first: 0, lim: 0 }, border: parse_brc80(bytes, 0) }
  }
  let cb = bytes[0].to_int()
  let range = parse_itc_first_lim(bytes, 1)
  let border = parse_brc80(bytes, 3)
  RangeBrcOperand::{ cb, range, border }
}

///| Parse TTableWidth operand (ftsWidth, width)
/// Used by: tableWidth, widthBefore, widthAfter
pub fn parse_ttable_width_operand(bytes : FixedArray[Byte]) -> TTableWidthOperand {
  let fts_width = if bytes.length() > 0 { bytes[0].to_int() } else { 0 }
  let width = if bytes.length() > 2 {
    bytes[1].to_int() | (bytes[2].to_int() << 8)
  } else if bytes.length() > 1 {
    bytes[1].to_int()
  } else { 0 }
  TTableWidthOperand::{ fts_width, width }
}

///| Check if SPRM uses variable-length operand (first byte = cb byte count)
fn is_variable_length_sprm(sprm : Int) -> Bool {
  match sprm {
    0xc601 | 0xc60d | 0xc615 | 0xd605 | 0xd608 | 0xd609 | 0xd60c | 0xd612 | 0xd613 | 0xd620 | 0xd62b | 0xd62c | 0xd62d | 0xd62e | 0xd62f | 0xd632 | 0xd633 | 0xd635 | 0x7623 | 0x7629 => true
    _ => false
  }
}

///| Get operand size for SPRM code
pub fn get_sprm_operand_length(sprm : Int) -> Int {
  let op_type = sprm >> 13 & 0x7
  match op_type {
    0 => 1
    1 => 1
    2 => 2
    3 => 4
    4 => 2
    5 => 2
    6 => 0
    7 => 3
    _ => 0
  }
}

///| Get the kind (para/char/table) from SPRM group bits (bits 10-12)
pub fn get_sprm_kind(sprm : Int) -> String {
  let group = sprm >> 10 & 0x7
  match group {
    1 => "para"
    2 => "char"
    5 => "table"
    _ => "unknown"
  }
}

///| Decode a single SPRM (uses ArrayView for zero-copy operand)
pub fn decode_sprm(sprm : Int, operand : ArrayView[Byte]) -> DecodedProperty {
  let name = match sprm {
    0x0800 => "fRMarkDel"
    0x0801 => "fRMark"
    0x0802 => "fFldVanish"
    0x6a03 => "picLocation"
    0x4804 => "ibstRMark"
    0x6805 => "dttmRMark"
    0x0806 => "fData"
    0x080a => "fOle2"
    0x2a0c => "highlight"
    0x4a30 => "istd"
    0x2a33 => "plain"
    0x0835 => "fBold"
    0x0836 => "fItalic"
    0x0837 => "fStrike"
    0x0838 => "fOutline"
    0x0839 => "fShadow"
    0x083a => "fSmallCaps"
    0x083b => "fCaps"
    0x083c => "fVanish"
    0x2a3e => "kul"
    0x8840 => "dxaSpace"
    0x2a42 => "ico"
    0x4a43 => "hps"
    0x4845 => "hpsPos"
    0x6a09 => "symbol"
    0x484b => "hpsKern"
    0x4a4f => "rgFtc0"
    0x4a50 => "rgFtc1"
    0x4a51 => "rgFtc2"
    0x4852 => "charScale"
    0x2a53 => "fDStrike"
    0x0854 => "fImprint"
    0x0855 => "fSpec"
    0x0856 => "fObj"
    0x0858 => "fEmboss"
    0x085a => "fBiDi"
    0x085c => "fBoldBi"
    0x085d => "fItalicBi"
    0x4a5e => "ftcBi"
    0x4a60 => "icoBi"
    0x4a61 => "hpsBi"
    0x4600 => "istdPara"
    0xc601 => "istdPermute"
    0x2602 => "incLvl"
    0x2403 => "jc80"
    0x2405 => "fKeep"
    0x2406 => "fKeepFollow"
    0x2407 => "fPageBreakBefore"
    0x260a => "ilvl"
    0x460b => "ilfo"
    0xc60d => "chgTabsPapx"
    0x840e => "dxaRight80"
    0x840f => "dxaLeft80"
    0x4610 => "nest80"
    0x8411 => "dxaLeft180"
    0x6412 => "dyaLine"
    0xa413 => "dyaBefore"
    0xa414 => "dyaAfter"
    0xc615 => "chgTabs"
    0x2416 => "fInTable"
    0x2417 => "fTtp"
    0x8418 => "dxaAbs"
    0x8419 => "dyaAbs"
    0x841a => "dxaWidth"
    0x261b => "pc"
    0x2423 => "wr"
    0x6424 => "brcTop80"
    0x6425 => "brcLeft80"
    0x6426 => "brcBottom80"
    0x6427 => "brcRight80"
    0x6428 => "brcBetween80"
    0x6629 => "brcBar80"
    0x442b => "wHeightAbs"
    0x442c => "dcs"
    0x442d => "shd80"
    0x842e => "dyaFromText"
    0x842f => "dxaFromText"
    0x2430 => "fLocked"
    0x2431 => "fWidowControl"
    0x2441 => "fBiDiPara"
    0x6646 => "hugePapx"
    0x2448 => "fAdjustRight"
    0x2640 => "outLvl"
    0x6649 => "itap"
    0x664a => "dtap"
    0x244b => "fInnerTableCell"
    0x244c => "fInnerTtp"
    0xc64d => "shd"
    0xc64e => "brcTop"
    0xc64f => "brcLeft"
    0xc650 => "brcBottom"
    0xc651 => "brcRight"
    0xc652 => "brcBetween"
    0xc653 => "brcBar"
    0x4455 => "dxcRight"
    0x4456 => "dxcLeft"
    0x4457 => "dxcLeft1"
    0x4458 => "dylBefore"
    0x4459 => "dylAfter"
    0x245b => "fDyaBeforeAuto"
    0x245c => "fDyaAfterAuto"
    0x845d => "dxaRight"
    0x845e => "dxaLeft"
    0x465f => "nest"
    0x8460 => "dxaLeft1"
    0x2461 => "jc"
    0x5400 => "jc90"
    0x9601 => "dxaLeft90"
    0x9602 => "dxaGapHalf90"
    0x3403 => "fcantSplit90"
    0x3404 => "tableHeader"
    0xd605 => "tableBorders80"
    0x9407 => "dyaRowHeight"
    0xd608 => "defTable"
    0xd609 => "defTableShd80"
    0x740a => "tlp"
    0x560b => "fBiDiTable"
    0xd60c => "defTableShd3rd"
    0x360d => "pc90"
    0x940e => "dxaAbs90"
    0x940f => "dyaAbs90"
    0x9410 => "dxaFromText90"
    0x9411 => "dyaFromText90"
    0xd612 => "defTableShd"
    0xd613 => "tableBorders"
    0xf614 => "tableWidth"
    0x3615 => "fAutofit"
    0xf617 => "widthBefore"
    0xf618 => "widthAfter"
    0xd620 => "setBrc80"
    0x7621 => "insert"
    0x5622 => "delete"
    0x7623 => "dxaCol"
    0x5624 => "merge"
    0x5625 => "split"
    0x7629 => "textFlow"
    0xd62b => "vertMerge"
    0xd62c => "vertAlign"
    0xd62d => "setShd"
    0xd62e => "setShdOdd"
    0xd62f => "setBrc"
    0xd632 => "cellPadding"
    0xd633 => "cellPaddingDefault"
    0xd635 => "cellWidth"
    0xf636 => "fitText"
    0xd639 => "fCellNoWrap"
    0x563a => "istd90"
    0xd660 => "setShdTable"
    _ => "unknown"
  }
  // Helper to read signed 16-bit integer (matching JS DataView.getInt16)
  let i16 = fn(bytes : ArrayView[Byte], offset : Int) -> Int {
    let raw = bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
    if raw > 0x7FFF { raw - 0x10000 } else { raw }
  }
  let value = if operand.length() >= 4 {
    operand[0].to_int() | (operand[1].to_int() << 8) | (operand[2].to_int() << 16) | (operand[3].to_int() << 24)
  } else if operand.length() >= 2 {
    i16(operand, 0)
  } else if operand.length() >= 1 {
    operand[0].to_int()
  } else {
    0
  }
  let kind = get_sprm_kind(sprm)
  // For table SPRMs with structured operands, parse properly
  if kind == "table" && operand.length() > 0 {
    // Helper to read i16 from ArrayView
    let i16v = fn(b : ArrayView[Byte], off : Int) -> Int {
      if off + 2 <= b.length() {
        let raw = b[off].to_int() | (b[off + 1].to_int() << 8)
        if raw > 0x7FFF { raw - 0x10000 } else { raw }
      } else { 0 }
    }
    // Helper to read u16 from ArrayView
    let u16v = fn(b : ArrayView[Byte], off : Int) -> Int {
      if off + 2 <= b.length() { b[off].to_int() | (b[off + 1].to_int() << 8) } else { 0 }
    }
    // Parse ItcRange from ArrayView
    let range_from_view = fn(b : ArrayView[Byte], off : Int) -> ItcRange {
      let first = if off < b.length() { b[off].to_int() } else { 0 }
      let lim = if off + 1 < b.length() { b[off + 1].to_int() } else { 0 }
      ItcRange::{ first, lim }
    }
    return match sprm {
      // merge (0x5624) and split (0x5625): cb, first, lim
      0x5624 | 0x5625 => {
        let range = range_from_view(operand, 1)
        let val = if operand.length() > 3 { operand[3].to_int() } else { 0 }
        DecodedProperty::{ name, value: val, extra: "", kind, range: Some(range), operand_bytes: None }
      }
      // vertMerge (0xd62b), vertAlign (0xd62c), setShd (0xd62d), setShdOdd (0xd62e),
      // fitText (0xf636), fCellNoWrap (0xd639): cb, first, lim, value(1-4 bytes)
      0xd62b | 0xd62c | 0xd62d | 0xd62e | 0xf636 | 0xd639 => {
        let range = range_from_view(operand, 1)
        let val = if operand.length() > 3 { operand[3].to_int() } else { 0 }
        DecodedProperty::{ name, value: val, extra: "", kind, range: Some(range), operand_bytes: None }
      }
      // cellWidth (0xd635), dxaCol (0x7623): cb, first, lim, ftsWidth, width
      0xd635 | 0x7623 => {
        let range = range_from_view(operand, 1)
        let fts = if operand.length() > 3 { operand[3].to_int() } else { 0 }
        let width = if operand.length() > 5 { u16v(operand, 4) } else { 0 }
        let packed = fts | (width << 8)
        DecodedProperty::{ name, value: packed, extra: "", kind, range: Some(range), operand_bytes: None }
      }
      // setBrc (0xd62f), setBrc80 (0xd620): cb, first, lim, brc80(4 bytes)
      0xd62f | 0xd620 => {
        let range = range_from_view(operand, 1)
        let brc_raw = if operand.length() >= 7 {
          operand[3].to_int() | (operand[4].to_int() << 8) | (operand[5].to_int() << 16) | (operand[6].to_int() << 24)
        } else { 0 }
        let brc_bytes : Array[Byte] = if operand.length() >= 7 {
          [operand[3], operand[4], operand[5], operand[6]]
        } else { [] }
        DecodedProperty::{ name, value: brc_raw, extra: "", kind, range: Some(range), operand_bytes: Some(brc_bytes) }
      }
      // insert (0x7621): cb, first, lim, count(2 bytes)
      0x7621 => {
        let range = range_from_view(operand, 1)
        let count = if operand.length() > 4 { u16v(operand, 3) } else if operand.length() > 3 { operand[3].to_int() } else { 0 }
        DecodedProperty::{ name, value: count, extra: "", kind, range: Some(range), operand_bytes: None }
      }
      // delete (0x5622): cb, first, lim
      0x5622 => {
        let range = range_from_view(operand, 1)
        DecodedProperty::{ name, value: 0, extra: "", kind, range: Some(range), operand_bytes: None }
      }
      // tableWidth (0xf614), widthBefore (0xf617), widthAfter (0xf618): ftsWidth, width
      0xf614 | 0xf617 | 0xf618 => {
        let fts = if operand.length() > 0 { operand[0].to_int() } else { 0 }
        let width = if operand.length() > 2 { u16v(operand, 1) } else { 0 }
        DecodedProperty::{ name, value: width, extra: "", kind, range: None, operand_bytes: None }
      }
      // dyaRowHeight (0x9407): 2-byte signed value
      0x9407 => {
        let val = i16v(operand, 0)
        DecodedProperty::{ name, value: val, extra: "", kind, range: None, operand_bytes: None }
      }
      // cellPadding (0xd632) and cellPaddingDefault (0xd634): CSSAOperand
      // cb(1), itcFirst(1), itcLim(1), grfbrc(1), ftsWidth(1), wWidth(2)
      0xd632 | 0xd634 => {
        let itc_first = if operand.length() > 1 { operand[1].to_int() } else { 0 }
        let itc_lim = if operand.length() > 2 { operand[2].to_int() } else { 0 }
        let grfbrc = if operand.length() > 3 { operand[3].to_int() } else { 0 }
        let fts_width = if operand.length() > 4 { operand[4].to_int() } else { 0 }
        let w_width = if operand.length() > 6 {
          operand[5].to_int() | (operand[6].to_int() << 8)
        } else if operand.length() > 5 { operand[5].to_int() } else { 0 }
        // Pack into value: w_width (low 16 bits) | fts_width (bits 16-18) | grfbrc (bits 19-22)
        let packed = w_width | (fts_width << 16) | (grfbrc << 19)
        DecodedProperty::{ name, value: packed, extra: "", kind, range: Some(ItcRange::{ first: itc_first, lim: itc_lim }), operand_bytes: None }
      }
      // setShdTable (0xd660): SHDOperand - background shading for entire table
      0xd660 => {
        // SHDOperand: cb(1), shd(2 bytes: ipat + ico)
        let color_idx = if operand.length() > 1 { operand[1].to_int() & 0x3F } else { 0 }
        DecodedProperty::{ name, value: color_idx, extra: "", kind, range: None, operand_bytes: None }
      }
      // Other table SPRMs: use default flat parsing
      _ => {
        let value = if operand.length() >= 4 {
          operand[0].to_int() | (operand[1].to_int() << 8) | (operand[2].to_int() << 16) | (operand[3].to_int() << 24)
        } else if operand.length() >= 2 {
          i16(operand, 0)
        } else if operand.length() >= 1 {
          operand[0].to_int()
        } else { 0 }
        DecodedProperty::{ name, value, extra: "", kind, range: None, operand_bytes: None }
      }
    }
  }
  let value = if operand.length() >= 4 {
    operand[0].to_int() | (operand[1].to_int() << 8) | (operand[2].to_int() << 16) | (operand[3].to_int() << 24)
  } else if operand.length() >= 2 {
    i16(operand, 0)
  } else if operand.length() >= 1 {
    operand[0].to_int()
  } else {
    0
  }
  DecodedProperty::{ name, value, extra: "", kind, range: None, operand_bytes: None }
}

///| Decode GRPPRL (array of SPRMs)
pub fn decode_grpprl(grpprl : ArrayView[Byte]) -> Array[DecodedProperty] {
  let properties = Array::new()
  let mut offset = 0
  while offset + 2 <= grpprl.length() {
    let sprm = grpprl[offset].to_int() | (grpprl[offset + 1].to_int() << 8)
    let op_type = sprm >> 13 & 0x7
    let operand_len = get_sprm_operand_length(sprm)

    if sprm == 0xd608 {
      // defTable uses u16 cb (not single byte)
      let cb = if offset + 4 <= grpprl.length() {
        grpprl[offset + 2].to_int() | (grpprl[offset + 3].to_int() << 8)
      } else { 0 }
      let total_skip = cb + 1
      if offset + 2 + total_skip <= grpprl.length() {
        let operand = grpprl.view(start=offset + 2, end=offset + 2 + total_skip)
        properties.push(decode_sprm(sprm, operand))
      }
      offset += 2 + total_skip
    } else if is_variable_length_sprm(sprm) {
      let cb = if offset + 2 < grpprl.length() {
        grpprl[offset + 2].to_int()
      } else {
        0
      }
      let total_skip = cb + 1
      let data_start = offset + 2 + 1
      if offset + 2 + total_skip <= grpprl.length() {
        let operand = grpprl.view(start=data_start, end=data_start + cb)
        properties.push(decode_sprm(sprm, operand))
      }
      offset += 2 + total_skip
    } else if op_type == 6 {
      let data_len = if offset + 2 < grpprl.length() {
        grpprl[offset + 2].to_int() + 1
      } else {
        0
      }
      let skip = 1 + data_len
      let data_start = offset + 2 + 1

      if skip > 0 && offset + 2 + skip <= grpprl.length() {
        let operand = grpprl.view(start=data_start, end=data_start + data_len)
        properties.push(decode_sprm(sprm, operand))
      }
      offset += 2 + skip
    } else {
      let operand = if operand_len > 0 && offset + 2 + operand_len <= grpprl.length() {
        grpprl.view(start=offset + 2, end=offset + 2 + operand_len)
      } else {
        grpprl.view(start=0, end=0)
      }
      properties.push(decode_sprm(sprm, operand))
      offset += 2 + operand_len
    }
  }
  properties
}
