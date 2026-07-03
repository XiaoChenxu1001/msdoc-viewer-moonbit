///| MS-DOC field/hyperlink processing
///| Extracted from parser.mbt for better organization

///| Process field characters to extract hyperlink hrefs
///| Field context for stack-based field parsing (mirrors JS buildInlineNodes)
struct FieldCtx {
  instruction : StringBuilder
  is_hyperlink : Bool
  href : String
  reading_instruction : Bool
  display_start : Int
  last_emitted : Int
}

///| Result of decoding a field instruction
struct FieldInstructionResult {
  instr_type : String
  href : String
  target : String
  raw : String
}

///| A hyperlink field range in CP-space
struct FieldRange {
  start : Int
  end : Int
  href : String
}

///| Precompute hyperlink field ranges from paragraph text using stack-based parser
fn find_hyperlink_field_ranges(para_text : String) -> Array[FieldRange] {
  let ranges : Array[FieldRange] = Array::new()
  let field_stack : Array[FieldCtx] = Array::new()
  let text_len = String::length(para_text)

  let mut i = 0
  while i < text_len {
    let ch = para_text[i].to_int()

    if ch == 0x13 {
      field_stack.push(FieldCtx::{
        instruction: StringBuilder::new(),
        is_hyperlink: false,
        href: "",
        reading_instruction: true,
        display_start: -1,
        last_emitted: -1,
      })
      i += 1
      continue
    }

    if ch == 0x14 && field_stack.length() > 0 {
      let top_idx = field_stack.length() - 1
      let top = field_stack[top_idx]
      let instr_str = top.instruction.to_string()
      let instr_result = decode_field_instruction(instr_str)
      let is_hl = instr_result.instr_type == "hyperlink" && instr_result.href.length() > 0
      let new_href = if is_hl { instr_result.href } else { top.href }
      let new_is_hl = if is_hl { true } else { top.is_hyperlink }
      field_stack[top_idx] = FieldCtx::{
        instruction: top.instruction,
        is_hyperlink: new_is_hl,
        href: new_href,
        reading_instruction: false,
        display_start: i + 1,
        last_emitted: i + 1,
      }
      i += 1
      continue
    }

    if ch == 0x15 && field_stack.length() > 0 {
      let top_idx = field_stack.length() - 1
      let top = field_stack[top_idx]
      let effective_href = if top.reading_instruction {
        let instr_str = top.instruction.to_string()
        let instr_result = decode_field_instruction(instr_str)
        if instr_result.instr_type == "hyperlink" && instr_result.href.length() > 0 { instr_result.href } else { top.href }
      } else {
        top.href
      }
      let effective_is_hl = if top.reading_instruction {
        let instr_str = top.instruction.to_string()
        let instr_result = decode_field_instruction(instr_str)
        if instr_result.instr_type == "hyperlink" && instr_result.href.length() > 0 { true } else { top.is_hyperlink }
      } else {
        top.is_hyperlink
      }
      let field_display_start = top.display_start
      let field_last_emitted = top.last_emitted
      ignore(field_stack.pop())

      if effective_is_hl && effective_href.length() > 0 {
        let emit_from = if field_last_emitted >= 0 { field_last_emitted } else { field_display_start }
        if emit_from >= 0 && emit_from < i {
          ranges.push(FieldRange::{ start: emit_from, end: i, href: effective_href })
        }
      }

      i += 1
      continue
    }

    if field_stack.length() > 0 && field_stack[field_stack.length() - 1].reading_instruction {
      let top_idx2 = field_stack.length() - 1
      let top2 = field_stack[top_idx2]
      let new_instruction = match ch.to_char() {
        Some(c) => {
          let sb = top2.instruction
          sb <+ "\{c}"
          sb
        }
        None => top2.instruction
      }
      field_stack[top_idx2] = FieldCtx::{
        instruction: new_instruction,
        is_hyperlink: top2.is_hyperlink,
        href: top2.href,
        reading_instruction: top2.reading_instruction,
        display_start: top2.display_start,
        last_emitted: top2.last_emitted,
      }
      i += 1
      continue
    }

    i += 1
  }

  ranges
}

///| Strip field marker characters (0x13/0x14/0x15) from text
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

///| Offset field ranges from local paragraph positions to document-level CP positions
fn offset_field_ranges(ranges : Array[FieldRange], offset : Int) -> Array[FieldRange] {
  let result : Array[FieldRange] = Array::new()
  let mut i = 0
  while i < ranges.length() {
    let r = ranges[i]
    result.push(FieldRange::{ start: r.start + offset, end: r.end + offset, href: r.href })
    i += 1
  }
  result
}

///| Case-insensitive prefix match starting at offset
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

///| Extract first quoted string or first whitespace-delimited token from body
fn extract_quoted_or_first_token_from(body : String, start : Int) -> String {
  let len = String::length(body)
  // Try quoted string
  let mut i = start
  while i < len {
    if body[i] == 0x22 {
      let mut j = i + 1
      while j < len && body[j] != 0x22 { j += 1 }
      if j > i + 1 {
        return body[i + 1 : j].to_owned()
      }
    }
    i += 1
  }
  // Fall back to first whitespace-delimited token
  let mut s = start
  while s < len && body[s] <= 0x20 { s += 1 }
  if s >= len { return "" }
  let mut e = s
  while e < len && body[e] > 0x20 { e += 1 }
  if e > s {
    body[s : e].to_owned()
  } else {
    ""
  }
}

///| Decode a field instruction into type + value
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
    return FieldInstructionResult::{ instr_type: "unknown", href: "", target: "", raw: "" }
  }
  let raw = inst_str[start : len].to_owned()

  // HYPERLINK (9 chars)
  if remaining >= 9 && ci_eq_prefix(inst_str, start, "HYPERLINK") {
    let mut bs = start + 9
    while bs < len && inst_str[bs] <= 0x20 { bs += 1 }
    let href = extract_quoted_or_first_token_from(inst_str, bs)
    if href.length() > 0 {
      return FieldInstructionResult::{ instr_type: "hyperlink", href, target: "", raw }
    }
    return FieldInstructionResult::{ instr_type: "unknown", href: "", target: "", raw }
  }

  // INCLUDEPICTURE (14 chars)
  if remaining >= 14 && ci_eq_prefix(inst_str, start, "INCLUDEPICTURE") {
    let mut bs = start + 14
    while bs < len && inst_str[bs] <= 0x20 { bs += 1 }
    let target = extract_quoted_or_first_token_from(inst_str, bs)
    return FieldInstructionResult::{ instr_type: "includePicture", href: "", target, raw }
  }

  // EMBED (5 chars)
  if remaining >= 5 && ci_eq_prefix(inst_str, start, "EMBED") {
    return FieldInstructionResult::{ instr_type: "embed", href: "", target: "", raw }
  }

  // LINK (4 chars)
  if remaining >= 4 && ci_eq_prefix(inst_str, start, "LINK") {
    return FieldInstructionResult::{ instr_type: "link", href: "", target: "", raw }
  }

  FieldInstructionResult::{ instr_type: "unknown", href: "", target: "", raw }
}
