///| CFB/OLE container parser for MS-DOC files

///| Convert ASCII uppercase to lowercase for case-insensitive map keys
fn ascii_to_lower(s : String) -> String {
  let len = String::length(s)
  let mut has_upper = false
  let mut i = 0
  while i < len {
    let ch = s[i].to_int()
    if ch >= 0x41 && ch <= 0x5A {
      has_upper = true
      break
    }
    i += 1
  }
  if !has_upper {
    return s
  }
  let sb = StringBuilder::new()
  i = 0
  while i < len {
    let ch = s[i].to_int()
    if ch >= 0x41 && ch <= 0x5A {
      match (ch + 0x20).to_char() {
        Some(c) => sb <+ "\{c}"
        None => match s[i].to_char() {
          Some(c) => sb <+ "\{c}"
          None => ignore(ch)
        }
      }
    } else {
      match s[i].to_char() {
        Some(c) => sb <+ "\{c}"
        None => ignore(ch)
      }
    }
    i += 1
  }
  sb.to_string()
}

///| CFB directory entry
pub struct CFBEntry {
  id : Int
  name : String
  object_type : Int
  color_flag : Int
  left_sibling_id : Int
  right_sibling_id : Int
  child_id : Int
  start_sector : Int
  stream_size : Int
}

///| CFB container result
pub struct CFBContainer {
  bytes : FixedArray[Byte]
  major_version : Int
  sector_size : Int
  mini_sector_size : Int
  mini_stream_cutoff_size : Int
  warnings : Array[String]
  entries : Array[CFBEntry]
  root_id : Int
  fat : Array[Int]
  mini_fat : Array[Int]
  root_stream_bytes : FixedArray[Byte]
  stream_map : Map[String, Int]
}

///| Read a sector at absolute position
fn read_sector_absolute(
  bytes : FixedArray[Byte],
  sector_size : Int,
  sid : Int,
) -> Option[FixedArray[Byte]] {
  let start = 512 + sid * sector_size
  let end = start + sector_size
  if start < 0 || end > bytes.length() {
    None
  } else {
    Some(FixedArray::makei(end - start, fn(i) { bytes[start + i] }))
  }
}

///| Collect sector chain following FAT
fn collect_chain(
  start_sid : Int,
  fat : Array[Int],
  limit : Int,
) -> Array[Int] {
  let chain = Array::new()
  let mut sid = start_sid
  let mut counter = 0
  while sid >= 0 && sid < fat.length() && !is_special_sector_id(sid) {
    chain.push(sid)
    let next = fat[sid]
    if is_special_sector_id(next) {
      break  // End of chain (ENDOFCHAIN/FREESECT/FATSECT/DIFSECT)
    }
    sid = next
    counter += 1
    if counter > limit {
      break
    }
  }
  chain
}

///| Read bytes from sector chain (optimized: no per-sector allocation)
fn read_chain_bytes(
  bytes : FixedArray[Byte],
  sector_size : Int,
  start_sid : Int,
  fat : Array[Int],
  warnings : Array[String],
) -> FixedArray[Byte] {
  if start_sid < 0 || is_special_sector_id(start_sid) {
    return FixedArray::make(0, b'\x00')
  }
  let chain = collect_chain(start_sid, fat, MAX_CHAIN_SECTORS)
  warnings.push("read_chain_bytes: chain length=\{chain.length()}")
  let out : FixedArray[Byte] = FixedArray::make(chain.length() * sector_size, b'\x00')
  let mut out_offset = 0
  let mut skipped = 0
  for sid in chain {
    let src_start = 512 + sid * sector_size
    let src_end = src_start + sector_size
    if src_start >= 0 && src_end <= bytes.length() {
      // Direct copy from source bytes — no intermediate sector allocation
      for i in 0..<sector_size {
        out[out_offset + i] = bytes[src_start + i]
      }
    } else {
      skipped += 1
    }
    out_offset += sector_size
  }
  if skipped > 0 {
    warnings.push("Skipped \{skipped} out-of-bounds sectors")
  }
  out
}

///| Decode UTF-16LE name string
fn decode_utf16le_name(reader : BinaryReader, entry_offset : Int, byte_length : Int) -> String {
  reader.utf16le(entry_offset, byte_length)
}

///| Parse CFB/OLE container
pub fn parse_cfb(
  input : FixedArray[Byte],
  warnings : Array[String],
) -> CFBContainer raise {
  let bytes = input
  let reader = BinaryReader::make(bytes)

  // Verify signature
  let signature = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]
  for i in 0..<8 {
    if reader.u8(i) != signature[i] {
      raise CfbError("Invalid CFB signature")
    }
  }

  let major_version = reader.u16(26)
  let sector_shift = reader.u16(30)
  let mini_sector_shift = reader.u16(32)
  let sector_size = 1 << sector_shift
  let mini_sector_size = 1 << mini_sector_shift
  let _num_dir_sectors = reader.u32(40)
  let num_fat_sectors = reader.u32(44)
  let first_dir_sector = reader.u32(48)
  warnings.push("Header: sectorShift=\{sector_shift} sectorSize=\{sector_size} numFatSectors=\{num_fat_sectors} firstDirSector=\{first_dir_sector}")
  let _transaction_signature = reader.u32(52)
  let mini_stream_cutoff_size = reader.u32(56)
  let first_mini_fat_sector = reader.u32(60)
  let num_mini_fat_sectors = reader.u32(64)
  let first_difat_sector = reader.u32(68)
  let num_difat_sectors = reader.u32(72)

  if mini_stream_cutoff_size != MINI_STREAM_CUTOFF {
    warnings.push("Mini stream cutoff unexpected: \{mini_stream_cutoff_size}")
  }

  // Read header DIFAT (109 entries)
  let header_difat = Array::new()
  for i in 0..<109 {
    let sid = reader.u32(76 + i * 4)
    if !is_special_sector_id(sid) && sid >= 0 {
      header_difat.push(sid)
    }
  }

  // Read extended DIFAT sectors
  let difat = header_difat
  let mut difat_sid = first_difat_sector
  let mut difat_count = 0
  while difat_sid != ENDOFCHAIN && difat_sid != FREESECT && difat_sid >= 0 {
    match read_sector_absolute(bytes, sector_size, difat_sid) {
      Some(sector) => {
        let sector_reader = BinaryReader::make(sector)
        let entries_per_difat_sector = sector_size / 4 - 1
        for i in 0..<entries_per_difat_sector {
          let sid = sector_reader.u32(i * 4)
          if !is_special_sector_id(sid) && sid >= 0 {
            difat.push(sid)
          }
        }
        difat_sid = sector_reader.u32(sector_size - 4)
        difat_count += 1
        if difat_count > num_difat_sectors + 4 {
          warnings.push("DIFAT chain exceeded declared count, stopping early")
          break
        }
      }
      None => break
    }
  }

  if num_fat_sectors > 0 && difat.length() < num_fat_sectors {
    warnings.push("FAT sector count mismatch: header says \{num_fat_sectors}, found \{difat.length()}")
  }

  // Build FAT table
  let fat = Array::new()
  for fat_sid in difat {
    match read_sector_absolute(bytes, sector_size, fat_sid) {
      Some(fat_sector) => {
        let fat_reader = BinaryReader::make(fat_sector)
        for i in 0..<(sector_size / 4) {
          fat.push(fat_reader.u32(i * 4))
        }
      }
      None => ignore(fat_sid)
    }
  }
  warnings.push("FAT length: \{fat.length()}, first few: \{if fat.length() > 0 { fat[0] } else { -1 }}, \{if fat.length() > 1 { fat[1] } else { -1 }}, \{if fat.length() > 2 { fat[2] } else { -1 }}")
  if first_dir_sector >= 0 && first_dir_sector < fat.length() {
    warnings.push("FAT[\{first_dir_sector}] = \{fat[first_dir_sector]}")
  } else {
    warnings.push("first_dir_sector \{first_dir_sector} out of FAT range (0-\{fat.length() - 1})")
  }

  // Read directory entries
  let directory_bytes = read_chain_bytes(bytes, sector_size, first_dir_sector, fat, warnings)
  warnings.push("Directory bytes length: \{directory_bytes.length()}")
  let directory_reader = BinaryReader::make(directory_bytes)
  let entries = Array::new()
  let mut offset = 0
  let mut id = 0
  while offset + 128 <= directory_bytes.length() {
    let name_length = directory_reader.u16(offset + 64)
    // Decode UTF-16LE name to ASCII
    // name_length is in bytes (including 2-byte null terminator)
    let name = if name_length > 2 {
      let byte_length = name_length - 2  // Subtract 2 for UTF-16LE null terminator
      if id < 5 {
        warnings.push("Entry[\{id}] name_length=\{name_length} byte_length=\{byte_length}")
      }
      decode_utf16le_name(directory_reader, offset, byte_length)
    } else {
      ""
    }
    let object_type = directory_reader.u8(offset + 66)
    if name == "" && object_type == 0 {
      offset += 128
      id += 1
      continue
    }
    let entry = CFBEntry::{
      id,
      name,
      object_type,
      color_flag: directory_reader.u8(offset + 67),
      left_sibling_id: directory_reader.i32(offset + 68),
      right_sibling_id: directory_reader.i32(offset + 72),
      child_id: directory_reader.i32(offset + 76),
      start_sector: directory_reader.u32(offset + 116),
      stream_size: directory_reader.u32(offset + 120),
    }
    entries.push(entry)
    offset += 128
    id += 1
  }
  warnings.push("Entries found: \{entries.length()}")

  // Find root entry and log all entries
  let mut root_id = 0
  for entry in entries {
    warnings.push("Entry[\{entry.id}]: name='\{entry.name}' type=\{entry.object_type}")
    if entry.object_type == 5 {
      root_id = entry.id
    }
  }

  // Read Mini-FAT sectors
  let mini_fat = Array::new()
  if num_mini_fat_sectors > 0 && first_mini_fat_sector >= 0 {
    let mini_fat_bytes = read_chain_bytes(bytes, sector_size, first_mini_fat_sector, fat, warnings)
    let mini_fat_reader = BinaryReader::make(mini_fat_bytes)
    let mut i = 0
    while i + 4 <= mini_fat_bytes.length() {
      mini_fat.push(mini_fat_reader.u32(i))
      i += 4
    }
  }

  // Read Root Entry's stream data (the Mini-Stream)
  let root_stream_bytes = if root_id >= 0 && root_id < entries.length() {
    let root = entries[root_id]
    read_chain_bytes(bytes, sector_size, root.start_sector, fat, warnings)
  } else {
    FixedArray::make(0, b'\x00')
  }

  // Build stream name → entry index map for O(1) lookups
  // Use lowercase ASCII for case-insensitive key matching
  let stream_map = Map([], capacity=entries.length())
  let mut entry_idx = 0
  for entry in entries {
    if entry.object_type == 2 || entry.object_type == 5 {
      let key = ascii_to_lower(entry.name)
      stream_map.set(key, entry_idx)
    }
    entry_idx += 1
  }

  CFBContainer::{
    bytes,
    major_version,
    sector_size,
    mini_sector_size,
    mini_stream_cutoff_size,
    warnings,
    entries,
    root_id,
    fat,
    mini_fat,
    root_stream_bytes,
    stream_map,
  }
}

///| Read a stream from the Mini-Stream (optimized: no extra trim copy)
fn read_mini_stream(
  container : CFBContainer,
  entry : CFBEntry,
) -> FixedArray[Byte] {
  if entry.start_sector < 0 || container.mini_fat.length() == 0 {
    return FixedArray::make(0, b'\x00')
  }
  let chain = collect_chain(entry.start_sector, container.mini_fat, MAX_CHAIN_SECTORS)
  let result_len = if entry.stream_size > 0 && entry.stream_size < chain.length() * container.mini_sector_size {
    entry.stream_size
  } else {
    chain.length() * container.mini_sector_size
  }
  let out : FixedArray[Byte] = FixedArray::make(result_len, b'\x00')
  let mut out_offset = 0
  for mini_sid in chain {
    if out_offset >= result_len { break }
    let src_start = mini_sid * container.mini_sector_size
    let src_end = src_start + container.mini_sector_size
    if src_end > container.root_stream_bytes.length() { break }
    let copy_len = if result_len - out_offset < container.mini_sector_size { result_len - out_offset } else { container.mini_sector_size }
    let mut ci = 0
    while ci < copy_len {
      out[out_offset + ci] = container.root_stream_bytes[src_start + ci]
      ci += 1
    }
    out_offset += container.mini_sector_size
  }
  out
}

///| Get stream bytes for an entry by index
pub fn cfb_get_stream_by_id(
  container : CFBContainer,
  entry_id : Int,
) -> Option[FixedArray[Byte]] {
  if entry_id < 0 || entry_id >= container.entries.length() {
    return None
  }
  let entry = container.entries[entry_id]
  if entry.object_type != 2 && entry.object_type != 5 {
    return None
  }
  if entry.object_type == 5 {
    return Some(container.root_stream_bytes)
  }
  if entry.stream_size < container.mini_stream_cutoff_size && entry.start_sector >= 0 && container.mini_fat.length() > 0 {
    return Some(read_mini_stream(container, entry))
  }
  Some(read_chain_bytes(
    container.bytes,
    container.sector_size,
    entry.start_sector,
    container.fat,
    container.warnings,
  ))
}

///| Find a directory entry by exact name (case-insensitive)
pub fn cfb_find_entry_exact(
  container : CFBContainer,
  name : String,
) -> Option[CFBEntry] {
  for entry in container.entries {
    if entry.name.equal_ignore_ascii_case(name) {
      return Some(entry)
    }
  }
  None
}

///| Find a directory entry by name (exact or contains match)
pub fn cfb_find_entry(
  container : CFBContainer,
  name : String,
) -> Option[CFBEntry] {
  match cfb_find_entry_exact(container, name) {
    Some(entry) => Some(entry)
    None => {
      for entry in container.entries {
        if entry.name.contains(name) {
          return Some(entry)
        }
      }
      None
    }
  }
}

///| Walk the sibling tree in-order, collecting entries
fn cfb_walk_siblings(
  container : CFBContainer,
  entry_id : Int,
  result : Array[CFBEntry],
) -> Unit {
  if entry_id < 0 || entry_id >= container.entries.length() {
    return
  }
  let entry = container.entries[entry_id]
  cfb_walk_siblings(container, entry.left_sibling_id, result)
  result.push(entry)
  cfb_walk_siblings(container, entry.right_sibling_id, result)
}

///| List children of a directory entry by walking the child/sibling tree
pub fn cfb_list_children(
  container : CFBContainer,
  parent : CFBEntry,
) -> Array[CFBEntry] {
  let result = Array::new()
  cfb_walk_siblings(container, parent.child_id, result)
  result
}

///| Resolve a directory entry by path (e.g. "/WordDocument", "/ObjectPool/00000001")
pub fn cfb_get_entry(
  container : CFBContainer,
  path : String,
) -> Option[CFBEntry] {
  if path == "/" {
    return if container.root_id >= 0 && container.root_id < container.entries.length() {
      Some(container.entries[container.root_id])
    } else {
      None
    }
  }
  let parts = path.split("/")
  let mut current_id = container.root_id
  for part in parts {
    let part_str = part.to_owned()
    if part_str == "" {
      continue
    }
    if current_id < 0 || current_id >= container.entries.length() {
      return None
    }
    let children = cfb_list_children(container, container.entries[current_id])
    let mut found = false
    for child in children {
      if child.name.equal_ignore_ascii_case(part_str) {
        current_id = child.id
        found = true
        break
      }
    }
    if !found {
      return None
    }
  }
  if current_id >= 0 && current_id < container.entries.length() {
    Some(container.entries[current_id])
  } else {
    None
  }
}

///| Find an entry by name using DFS from root
pub fn cfb_find_by_name(
  container : CFBContainer,
  name : String,
) -> Option[CFBEntry] {
  if container.root_id < 0 || container.root_id >= container.entries.length() {
    return None
  }
  let root = container.entries[container.root_id]
  let stack : Array[CFBEntry] = [root]
  let mut visited = 0
  while stack.length() > 0 {
    visited += 1
    if visited > container.entries.length() {
      break
    }
    let entry = stack.unsafe_pop()
    if entry.name == name {
      return Some(entry)
    }
    let children = cfb_list_children(container, entry)
    for child in children {
      stack.push(child)
    }
  }
  None
}

///| Get stream bytes by name (exact match via map, then fallback to substring)
pub fn cfb_get_stream(
  container : CFBContainer,
  name : String,
) -> Option[FixedArray[Byte]] {
  // Fast path: O(1) map lookup for exact case-insensitive match
  let lower_name = ascii_to_lower(name)
  match container.stream_map.get(lower_name) {
    Some(entry_idx) => {
      let entry = container.entries[entry_idx]
      if entry.object_type == 5 {
        return Some(container.root_stream_bytes)
      }
      if entry.stream_size < container.mini_stream_cutoff_size && entry.start_sector >= 0 && container.mini_fat.length() > 0 {
        return Some(read_mini_stream(container, entry))
      }
      return Some(read_chain_bytes(
        container.bytes,
        container.sector_size,
        entry.start_sector,
        container.fat,
        container.warnings,
      ))
    }
    None => ()
  }
  // Slow path: substring match (for streams like "CONTENTS" inside ObjectPool)
  for entry in container.entries {
    if entry.name.contains(name) && (entry.object_type == 2 || entry.object_type == 5) {
      if entry.object_type == 5 {
        return Some(container.root_stream_bytes)
      }
      if entry.stream_size < container.mini_stream_cutoff_size && entry.start_sector >= 0 && container.mini_fat.length() > 0 {
        return Some(read_mini_stream(container, entry))
      }
      return Some(read_chain_bytes(
        container.bytes,
        container.sector_size,
        entry.start_sector,
        container.fat,
        container.warnings,
      ))
    }
  }
  None
}
