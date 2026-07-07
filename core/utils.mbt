///| 工具函数模块

///|
/// 限制值在范围内
pub fn clamp(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
/// 对齐到偶数
pub fn align_even(value : Int) -> Int {
  if value % 2 == 0 {
    value
  } else {
    value + 1
  }
}

///|
/// 字节转 Base64
pub fn bytes_to_base64(bytes : FixedArray[Byte]) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let sb = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b0 = bytes[i].to_int() & 0xFF
    let b1 = if i + 1 < len { bytes[i + 1].to_int() & 0xFF } else { 0 }
    let b2 = if i + 2 < len { bytes[i + 2].to_int() & 0xFF } else { 0 }
    let tri = (b0 << 16) | (b1 << 8) | b2
    let idx0 = (tri >> 18) & 0x3F
    let idx1 = (tri >> 12) & 0x3F
    let idx2 = (tri >> 6) & 0x3F
    let idx3 = tri & 0x3F
    let c0 = alphabet[idx0].to_int()
    let c1 = alphabet[idx1].to_int()
    let c2 = if i + 1 < len { alphabet[idx2].to_int() } else { 0x3D }
    let c3 = if i + 2 < len { alphabet[idx3].to_int() } else { 0x3D }
    sb <+
      "\{c0.to_char().unwrap()}\{c1.to_char().unwrap()}\{c2.to_char().unwrap()}\{c3.to_char().unwrap()}"
    i += 3
  }
  sb.to_string()
}

///|
/// 字节转 Data URL
pub fn data_url_from_bytes(bytes : FixedArray[Byte], mime : String) -> String {
  "data:\{mime};base64,\{bytes_to_base64(bytes)}"
}

///|
/// 文本转 slug
pub fn slugify(text : String) -> String {
  let result = StringBuilder::new()
  let mut i = 0
  while i < String::length(text) {
    let ch = text[i]
    if (ch >= 0x61 && ch <= 0x7A) ||
      (ch >= 0x30 && ch <= 0x39) ||
      ch == 0x2D ||
      (ch >= 0x4E00 && ch <= 0x9FA5) {
      match ch.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => ignore(ch)
      }
    } else if ch >= 0x41 && ch <= 0x5A {
      // Uppercase ASCII → lowercase
      let lower = ch + 0x20
      match lower.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => ignore(ch)
      }
    } else if ch > 0x20 {
      result <+ "-"
    }
    i += 1
  }
  let output = result.to_string()
  if output.length() == 0 {
    "item"
  } else {
    output
  }
}

///|
/// 推送警告
pub fn push_warning(target : Array[String], message : String) -> String {
  target.push(message)
  message
}

///|
/// Twips 转像素 (truncates)
pub fn twips_to_px(twips : Int, px_per_inch : Int) -> Int? {
  Some(twips * px_per_inch / 1440)
}

///| Twips 转像素 (rounded, for CSS output)

///|
/// Matches JS: (twips / 1440) * 96
pub fn twips_to_px_rounded(twips : Int) -> Int {
  // Use integer math to avoid overflow, support negative values
  let abs_twips = if twips < 0 { 0 - twips } else { twips }
  let abs_px = (abs_twips * 96 + 720) / 1440
  if twips < 0 {
    0 - abs_px
  } else {
    abs_px
  }
}

///|
/// Points 转像素
pub fn points_to_px(points : Int, px_per_inch : Int) -> Int? {
  if points < 0 {
    None
  } else {
    Some(points * px_per_inch / 72)
  }
}
