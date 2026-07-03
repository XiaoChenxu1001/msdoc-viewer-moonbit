///| Binary reader for parsing binary file formats.
///| Uses ArrayView for zero-copy slicing.
pub struct BinaryReader {
  bytes : ArrayView[Byte]
  length : Int
}

///| Create a BinaryReader from a FixedArray (converts to view, zero-copy)
pub fn BinaryReader::make(bytes : FixedArray[Byte]) -> BinaryReader {
  let view = bytes.view()
  { bytes: view, length: view.length() }
}

///| Create a BinaryReader directly from an ArrayView (zero-copy)
pub fn BinaryReader::from_view(view : ArrayView[Byte]) -> BinaryReader {
  { bytes: view, length: view.length() }
}

///|
pub fn BinaryReader::ensure(self : BinaryReader, offset : Int, size : Int) -> Bool {
  offset >= 0 && offset + size <= self.length
}

///|
pub fn BinaryReader::u8(self : BinaryReader, offset : Int) -> Int {
  if self.ensure(offset, 1) {
    self.bytes[offset].to_int()
  } else {
    0
  }
}

///|
pub fn BinaryReader::i8(self : BinaryReader, offset : Int) -> Int {
  let raw = self.u8(offset)
  if raw >= 0x80 { raw - 0x100 } else { raw }
}

///|
pub fn BinaryReader::u16(self : BinaryReader, offset : Int) -> Int {
  if self.ensure(offset, 2) {
    self.bytes[offset].to_int() | (self.bytes[offset + 1].to_int() << 8)
  } else {
    0
  }
}

///|
pub fn BinaryReader::i16(self : BinaryReader, offset : Int) -> Int {
  let raw = self.u16(offset)
  if raw >= 0x8000 { raw - 0x10000 } else { raw }
}

///|
pub fn BinaryReader::u32(self : BinaryReader, offset : Int) -> Int {
  if self.ensure(offset, 4) {
    self.bytes[offset].to_int() |
    (self.bytes[offset + 1].to_int() << 8) |
    (self.bytes[offset + 2].to_int() << 16) |
    (self.bytes[offset + 3].to_int() << 24)
  } else {
    0
  }
}

///|
pub fn BinaryReader::i32(self : BinaryReader, offset : Int) -> Int {
  self.u32(offset)
}

///|
pub fn BinaryReader::u64(self : BinaryReader, offset : Int) -> Int64 {
  let lo = self.u32(offset).to_int64()
  let hi = self.u32(offset + 4).to_int64()
  hi * 0x100000000L + lo
}

///| Get a zero-copy view of a byte range (no allocation)
pub fn BinaryReader::slice(self : BinaryReader, offset : Int, length : Int) -> ArrayView[Byte] {
  if self.ensure(offset, length) {
    self.bytes.view(start=offset, end=offset + length)
  } else {
    self.bytes.view(start=0, end=0)
  }
}

///|
test "BinaryReader u8" {
  let data : FixedArray[Byte] = [0x42, 0xFF, 0x00, 0x00]
  let reader = BinaryReader::make(data)
  assert_eq(reader.u8(0), 0x42)
  assert_eq(reader.u8(1), 0xFF)
  assert_eq(reader.u8(10), 0)
}

///|
test "BinaryReader u16 little-endian" {
  let data : FixedArray[Byte] = [0x34, 0x12]
  let reader = BinaryReader::make(data)
  assert_eq(reader.u16(0), 0x1234)
}

///|
test "BinaryReader u32 little-endian" {
  let data : FixedArray[Byte] = [0x78, 0x56, 0x34, 0x12]
  let reader = BinaryReader::make(data)
  assert_eq(reader.u32(0), 0x12345678)
}

///|
test "BinaryReader i32 signed" {
  let data : FixedArray[Byte] = [0x00, 0x00, 0x00, 0x80]
  let reader = BinaryReader::make(data)
  assert_eq(reader.i32(0), -2147483648)
}

///|
test "BinaryReader slice" {
  let data : FixedArray[Byte] = [0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00]
  let reader = BinaryReader::make(data)
  let s = reader.slice(1, 3)
  assert_eq(s.length(), 3)
  assert_eq(s[0].to_int(), 0x02)
  assert_eq(s[1].to_int(), 0x03)
  assert_eq(s[2].to_int(), 0x04)
}

///| 读取 UTF-16LE 字符串
pub fn BinaryReader::utf16le(self : BinaryReader, offset : Int, byte_length : Int) -> String {
  if !self.ensure(offset, byte_length) {
    return ""
  }
  let result = StringBuilder::new()
  let mut i = 0
  while i + 1 < byte_length {
    let lo = self.bytes[offset + i].to_int()
    let hi = self.bytes[offset + i + 1].to_int()
    let code = lo | (hi << 8)
    // Handle surrogate pairs
    if code >= 0xD800 && code <= 0xDBFF && i + 4 <= byte_length {
      let lo2 = self.bytes[offset + i + 2].to_int()
      let hi2 = self.bytes[offset + i + 3].to_int()
      let code2 = lo2 | (hi2 << 8)
      if code2 >= 0xDC00 && code2 <= 0xDFFF {
        let full = 0x10000 + (code - 0xD800) * 0x400 + (code2 - 0xDC00)
        match full.to_char() {
          Some(c) => result <+ "\{c.to_string()}"
          None => ignore(full)
        }
        i += 4
        continue
      }
    }
    // Null code units are preserved (use utf16z for null-terminated strings)
    if code == 0 {
      result <+ "\u{0000}"
    } else {
      match code.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => ignore(code)
      }
    }
    i += 2
  }
  result.to_string()
}

///| 读取 Latin1/Windows-1252 字符串
pub fn BinaryReader::latin1(self : BinaryReader, offset : Int, byte_length : Int) -> String {
  if !self.ensure(offset, byte_length) {
    return ""
  }
  let result = StringBuilder::new()
  let mut i = 0
  while i < byte_length {
    let code = self.bytes[offset + i].to_int()
    if code >= 0x20 && code < 0x7F {
      match code.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => ignore(code)
      }
    } else if code >= 0x80 {
      let unicode = cp1252_to_unicode(code)
      match unicode.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => result <+ "?"
      }
    }
    // 0x00-0x1F (control chars) are skipped
    i += 1
  }
  result.to_string()
}

///| 读取 ASCII 字符串
pub fn BinaryReader::ascii(self : BinaryReader, offset : Int, byte_length : Int) -> String {
  if !self.ensure(offset, byte_length) {
    return ""
  }
  let result = StringBuilder::new()
  let mut i = 0
  while i < byte_length {
    let code = self.bytes[offset + i].to_int()
    if code >= 0x20 && code < 0x7F {
      match code.to_char() {
        Some(c) => {
          let s = c.to_string()
          result <+ "\{s}"
        }
        None => ignore(code)
      }
    }
    i += 1
  }
  result.to_string()
}

///| 读取 UTF-16Z 字符串 (以 null 结尾)
pub fn BinaryReader::utf16z(self : BinaryReader, offset : Int, byte_length : Int) -> String {
  if !self.ensure(offset, byte_length) {
    return ""
  }
  // 查找 null 终止符
  let mut end = byte_length
  let mut i = 0
  while i + 1 < byte_length {
    if self.bytes[offset + i] == 0 && self.bytes[offset + i + 1] == 0 {
      end = i
      break
    }
    i += 2
  }
  self.utf16le(offset, end)
}

///| 读取数组
pub fn BinaryReader::array[T](self : BinaryReader, offset : Int, count : Int, read_fn : (BinaryReader, Int) -> T) -> Array[T] {
  let out = Array::new()
  let mut i = 0
  while i < count {
    out.push(read_fn(self, offset + i))
    i += 1
  }
  out
}
