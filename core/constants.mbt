///| MS-DOC 控制字符常量

///|
/// 控制字符常量 (使用 Int 而非 UInt16，因为 MoonBit 常量限制)
pub const DOC_CONTROL_PARAGRAPH : Int = 0x000D

///|
pub const DOC_CONTROL_CELL_MARK : Int = 0x0007

///|
pub const DOC_CONTROL_PICTURE : Int = 0x0001

///|
pub const DOC_CONTROL_FIELD_START : Int = 0x0013

///|
pub const DOC_CONTROL_FIELD_SEPARATOR : Int = 0x0014

///|
pub const DOC_CONTROL_FIELD_END : Int = 0x0015

///|
pub const DOC_CONTROL_ANNOTATION_REF : Int = 0x0005

///|
pub const DOC_CONTROL_HARD_LINE_BREAK : Int = 0x000B

///|
pub const DOC_CONTROL_PAGE_BREAK : Int = 0x000C

///|
pub const DOC_CONTROL_NON_BREAKING_HYPHEN : Int = 0x001E

///|
pub const DOC_CONTROL_NON_REQUIRED_HYPHEN : Int = 0x001F

///|
/// 下划线类型映射
pub fn underline_name(value : Int) -> String {
  match value {
    0 => "none"
    1 => "single"
    2 => "word"
    3 => "double"
    4 => "dotted"
    5 => "hidden"
    6 => "thick"
    7 => "dash"
    9 => "dot-dash"
    10 => "dot-dot-dash"
    11 => "wave"
    16 => "dotted-heavy"
    17 => "dashed-heavy"
    18 => "dash-long"
    19 => "dash-long-heavy"
    20 => "dot-dash-heavy"
    21 => "dot-dot-dash-heavy"
    22 => "wavy-heavy"
    23 => "wavy-double"
    _ => "single"
  }
}

///|
/// 对齐方式映射
pub fn alignment_css(value : Int) -> String {
  match value {
    0 => "left"
    1 => "center"
    2 => "right"
    3 => "justify"
    4 => "distributed"
    _ => "left"
  }
}

///|
/// 垂直对齐映射
pub fn vertical_align_css(value : Int) -> String {
  match value {
    0 => "top"
    1 => "center"
    2 => "bottom"
    _ => "top"
  }
}

///|
/// 高亮颜色映射
pub fn highlight_color(index : Int) -> String {
  match index {
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
    _ => ""
  }
}

///|
/// 默认字体族映射
pub fn default_font_family(index : Int) -> String {
  match index {
    0 => "serif"
    _ => "serif"
  }
}

///|
/// 字段类型常量
pub const FIELD_TYPE_HYPERLINK : String = "hyperlink"

///|
pub const FIELD_TYPE_INCLUDE_PICTURE : String = "includePicture"

///|
pub const FIELD_TYPE_EMBED : String = "embed"

///|
pub const FIELD_TYPE_LINK : String = "link"

///|
/// CFB 特殊扇区 ID
pub const FREESECT : Int = 0xFFFFFFFF

///|
pub const ENDOFCHAIN : Int = 0xFFFFFFFE

///|
pub const FATSECT : Int = 0xFFFFFFFD

///|
pub const DIFSECT : Int = 0xFFFFFFFC

///|
pub const MAX_CHAIN_SECTORS : Int = 1 << 20

///|
pub const MINI_STREAM_CUTOFF : Int = 4096

///| 检查是否为特殊扇区 ID

///|
/// Check if a sector ID is a special (non-data) sector
pub fn is_special_sector_id(sid : Int) -> Bool {
  sid == FREESECT || sid == ENDOFCHAIN || sid == FATSECT || sid == DIFSECT
}

///|
/// CFB 错误类型
pub(all) suberror CfbError {
  CfbError(String)
}
