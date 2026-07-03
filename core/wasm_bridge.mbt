///| WASM-GC bridge functions
///| Wraps core functions with String-based ABI for WASM-GC export
///| Binary data is passed as hex-encoded strings

///| Decode hex string to bytes
fn hex_decode(input : String) -> FixedArray[Byte] {
  let len = input.length()
  let byte_len = len / 2
  let arr = FixedArray::make(byte_len, b'\x00')
  let mut i = 0
  for c in input {
    if i >= byte_len * 2 {
      break
    }
    let code = c.to_int()
    let val = if code >= 48 && code <= 57 {
      code - 48
    } else if code >= 97 && code <= 102 {
      code - 97 + 10
    } else if code >= 65 && code <= 70 {
      code - 65 + 10
    } else {
      0
    }
    let idx = i / 2
    if idx < byte_len {
      if i % 2 == 0 {
        arr[idx] = (val * 16).to_byte()
      } else {
        arr[idx] = (arr[idx].to_int() + val).to_byte()
      }
    }
    i = i + 1
  }
  arr
}

///| WASM-GC export: parse and render to HTML (hex-encoded doc bytes)
///| Returns "CSS|||SEPARATOR|||HTML" on success, or "ERROR: message" on failure
pub fn parse_ms_doc_to_html_wasm(input : String) -> String {
  try {
    let bytes = hex_decode(input)
    let result = render_ms_doc(bytes)
    "\{result.css}|||SEPARATOR|||\{result.html}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///| WASM-GC export: render doc to HTML (hex-encoded doc bytes)
pub fn render_ms_doc_wasm(input : String) -> String {
  try {
    let bytes = hex_decode(input)
    let result = render_ms_doc(bytes)
    "\{result.css}|||SEPARATOR|||\{result.html}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///| WASM-GC export: parse doc text (hex-encoded doc bytes)
pub fn parse_ms_doc_wasm(input : String) -> String {
  try {
    let bytes = hex_decode(input)
    parse_ms_doc(bytes).text
  } catch {
    e => "ERROR: \{e}"
  }
}

///| WASM-GC export: extract all images from doc (hex-encoded doc bytes)
///| Returns JSON array of {index, data_url} for each placeholder image
pub fn extract_wasm_images(hex_input : String) -> String {
  try {
    let bytes = hex_decode(hex_input)
    let parsed = parse_ms_doc(bytes)
    let sb = StringBuilder::new()
    sb <+ "["
    let mut first = true
    let mut i = 0
    while i < parsed.assets.length() {
      let asset = parsed.assets[i]
      if is_placeholder_asset(asset) && asset.bytes.length() > 0 {
        let processed = process_raw_image_asset(asset)
        if !first { sb <+ "," }
        first = false
        let prefix = "{\"index\":"
        let mid = ",\"data_url\":\""
        let suffix = "\"}"
        sb <+ "\{prefix}\{i}\{mid}\{processed.data_url}\{suffix}"
      }
      i += 1
    }
    sb <+ "]"
    sb.to_string()
  } catch {
    e => "ERROR: \{e}"
  }
}
