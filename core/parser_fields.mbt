///| MS-DOC field/hyperlink processing

///| Extracted from parser.mbt for better organization

///| Process field characters to extract hyperlink hrefs

///|
/// Result of decoding a field instruction
priv struct FieldInstructionResult {
  instr_type : String
  href : String
}

///|
/// A hyperlink field range in CP-space
///|
/// Strip field markers and trim trailing \r/\u{0007} in a single pass
fn strip_field_markers_and_trim(text : String) -> String {
  let len = String::length(text)
  // Fast path: no markers and no trailing terminator
  let mut has_markers = false
  let mut has_trailing = false
  let mut i = 0
  while i < len {
    let ch = text[i].to_int()
    if ch == 0x13 || ch == 0x14 || ch == 0x15 {
      has_markers = true
    }
    i += 1
  }
  if len > 0 {
    let last_ch = text[len - 1].to_int()
    has_trailing = last_ch == 0x0D || last_ch == 0x07
  }
  if !has_markers && !has_trailing {
    return text
  }
  // Determine effective end (skip trailing terminator)
  let effective_end = if has_trailing { len - 1 } else { len }
  if !has_markers {
    // Only need to trim — just slice
    return text[0:effective_end].to_owned()
  }
  // Slow path: strip markers, skip trailing terminator
  let sb = StringBuilder::new()
  i = 0
  while i < effective_end {
    let ch = text[i].to_int()
    if ch != 0x13 && ch != 0x14 && ch != 0x15 {
      match text[i].to_char() {
        Some(c) => sb <+ "\{c}"
        None => ignore(ch)
      }
    }
    i += 1
  }
  sb.to_string()
}

///|
/// Strip field marker characters (0x13/0x14/0x15) from text
fn strip_field_markers(text : String) -> String {
  // Fast path: check if any markers exist
  let len = String::length(text)
  let mut has_markers = false
  let mut i = 0
  while i < len {
    let ch = text[i].to_int()
    if ch == 0x13 || ch == 0x14 || ch == 0x15 {
      has_markers = true
      break
    }
    i += 1
  }
  if !has_markers {
    return text
  }
  // Slow path: strip markers
  let sb = StringBuilder::new()
  i = 0
  while i < len {
    let ch = text[i].to_int()
    if ch != 0x13 && ch != 0x14 && ch != 0x15 {
      match text[i].to_char() {
        Some(c) => sb <+ "\{c}"
        None => ignore(ch)
      }
    }
    i += 1
  }
  sb.to_string()
}

///|
/// Case-insensitive prefix match starting at offset
fn ci_eq_prefix(s : String, offset : Int, prefix : String) -> Bool {
  let plen = String::length(prefix)
  let mut i = 0
  while i < plen {
    let ch = s[offset + i]
    let pch = prefix[i]
    if ch != pch && ch != pch + 32 && ch != pch - 32 {
      return false
    }
    i += 1
  }
  true
}

///|
/// Extract first quoted string or first whitespace-delimited token from body
fn extract_quoted_or_first_token_from(body : String, start : Int) -> String {
  let len = String::length(body)
  // Try quoted string
  let mut i = start
  while i < len {
    if body[i] == 0x22 {
      let mut j = i + 1
      while j < len && body[j] != 0x22 {
        j += 1
      }
      if j > i + 1 {
        return body[i + 1:j].to_owned()
      }
    }
    i += 1
  }
  // Fall back to first whitespace-delimited token
  let mut s = start
  while s < len && body[s] <= 0x20 {
    s += 1
  }
  if s >= len {
    return ""
  }
  let mut e = s
  while e < len && body[e] > 0x20 {
    e += 1
  }
  if e > s {
    body[s:e].to_owned()
  } else {
    ""
  }
}

///|
/// Decode a field instruction into type + value
fn decode_field_instruction(instruction : String) -> FieldInstructionResult {
  let len = String::length(instruction)
  // Normalize internal whitespace: replace control chars and multiple spaces with single space
  let normalized = StringBuilder::new()
  let mut prev_space = false
  let mut i = 0
  while i < len {
    let code = instruction[i].to_int()
    if code <= 0x20 {
      if !prev_space {
        normalized <+ " "
        prev_space = true
      }
    } else {
      normalized <+ "\{instruction[i].to_char().unwrap()}"
      prev_space = false
    }
    i += 1
  }
  let inst_str = normalized.to_string()
  let len = String::length(inst_str)
  // Skip leading whitespace
  let mut start = 0
  while start < len && inst_str[start] <= 0x20 {
    start += 1
  }
  let remaining = len - start
  if remaining == 0 {
    return FieldInstructionResult::{
      instr_type: "unknown",
      href: "",
    }
  }
  let _raw = inst_str[start:len].to_owned()

  // HYPERLINK (9 chars)
  if remaining >= 9 && ci_eq_prefix(inst_str, start, "HYPERLINK") {
    let mut bs = start + 9
    while bs < len && inst_str[bs] <= 0x20 {
      bs += 1
    }
    let href = extract_quoted_or_first_token_from(inst_str, bs)
    if href.length() > 0 {
      return FieldInstructionResult::{
        instr_type: "hyperlink",
        href,
      }
    }
    return FieldInstructionResult::{
      instr_type: "unknown",
      href: "",
    }
  }

  // INCLUDEPICTURE (14 chars)
  if remaining >= 14 && ci_eq_prefix(inst_str, start, "INCLUDEPICTURE") {
    let mut bs = start + 14
    while bs < len && inst_str[bs] <= 0x20 {
      bs += 1
    }
    let _target = extract_quoted_or_first_token_from(inst_str, bs)
    return FieldInstructionResult::{
      instr_type: "includePicture",
      href: "",
    }
  }

  // EMBED (5 chars)
  if remaining >= 5 && ci_eq_prefix(inst_str, start, "EMBED") {
    return FieldInstructionResult::{
      instr_type: "embed",
      href: "",
    }
  }

  // LINK (4 chars)
  if remaining >= 4 && ci_eq_prefix(inst_str, start, "LINK") {
    return FieldInstructionResult::{
      instr_type: "link",
      href: "",
    }
  }

  // FORMTEXT (8 chars)
  if remaining >= 8 && ci_eq_prefix(inst_str, start, "FORMTEXT") {
    return FieldInstructionResult::{
      instr_type: "formtext",
      href: "",
    }
  }

  // FORMCHECKBOX (12 chars)
  if remaining >= 12 && ci_eq_prefix(inst_str, start, "FORMCHECKBOX") {
    return FieldInstructionResult::{
      instr_type: "formcheckbox",
      href: "",
    }
  }

  // FORMDROPDOWN (12 chars)
  if remaining >= 12 && ci_eq_prefix(inst_str, start, "FORMDROPDOWN") {
    return FieldInstructionResult::{
      instr_type: "formdropdown",
      href: "",
    }
  }

  FieldInstructionResult::{ instr_type: "unknown", href: "" }
}
