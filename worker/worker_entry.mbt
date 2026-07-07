///| Web Worker entry point for MS-DOC parsing

///| This file is the MoonBit logic; the actual Worker setup is in worker_wrapper.js

///|
/// Parse MS-DOC and return text content
pub fn worker_parse(input : FixedArray[Byte]) -> String {
  try {
    let result = @core.parse_ms_doc(input)
    result.text
  } catch {
    e => "ERROR: \{e}"
  }
}

///|
/// Render MS-DOC to HTML+CSS
pub fn worker_render(input : FixedArray[Byte]) -> String {
  try {
    let parsed = @core.parse_ms_doc(input)
    let result = @core.render_parsed(parsed)
    // Collect asset CFB offsets for image extraction
    let offsets = StringBuilder::new()
    let mut first = true
    for asset in parsed.assets {
      if asset.asset_type == "image" && asset.bytes.length() > 0 {
        // Asset ID format: "asset-img-{offset}"
        if asset.id.length() > 10 {
          if !first {
            offsets <+ ","
          }
          first = false
          offsets <+ "\{asset.id[10 : asset.id.length()]}"
        }
      }
    }
    "\{result.css}|||SEPARATOR|||\{result.html}|||ASSETS|||\{offsets.to_string()}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///|
/// Parse and render MS-DOC to HTML
pub fn worker_parse_to_html(input : FixedArray[Byte]) -> String {
  try {
    let result = @core.render_ms_doc(input)
    "\{result.css}|||SEPARATOR|||\{result.html}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///| Extract a single image from document data

///|
/// Returns base64 data URL or error
pub fn worker_extract_image(
  input : FixedArray[Byte],
  picture_offset : Int,
) -> String {
  try {
    let warnings = Array::new()
    let container = @core.parse_cfb(input, warnings)
    let data_bytes = match @core.cfb_get_stream(container, "Data") {
      Some(bytes) => bytes
      None => return "ERROR: Data stream not found"
    }
    let extractor = @core.create_image_extractor(data_bytes)
    match @core.extract_image(extractor, picture_offset) {
      Some(asset) => asset.data_url
      None => "ERROR: Image extraction failed"
    }
  } catch {
    e => "ERROR: \{e}"
  }
}

///| Extract all images from document data in parallel batches

///|
/// Returns JSON array of {offset, data_url} pairs
pub fn worker_extract_all_images(
  input : FixedArray[Byte],
  offsets_json : String,
) -> String {
  try {
    let warnings = Array::new()
    let container = @core.parse_cfb(input, warnings)
    let data_bytes = match @core.cfb_get_stream(container, "Data") {
      Some(bytes) => bytes
      None => return "[]"
    }
    let extractor = @core.create_image_extractor(data_bytes)
    let sb = StringBuilder::new()
    sb <+ "["
    // Parse offsets from JSON array string (simple parser)
    let mut first = true
    let mut i = 0
    let len = String::length(offsets_json)
    while i < len {
      // Skip non-digit characters
      while i < len && (offsets_json[i] < '0' || offsets_json[i] > '9') {
        i += 1
      }
      if i >= len {
        break
      }
      // Parse number
      let mut num = 0
      while i < len && offsets_json[i] >= '0' && offsets_json[i] <= '9' {
        num = num * 10 + (offsets_json[i].to_int() - 48)
        i += 1
      }
      // Extract image
      let oPrefix = "{\"offset\":"
      let oMid = ",\"data_url\":\""
      let oSuffix = "\"}"
      match @core.extract_image(extractor, num) {
        Some(asset) => {
          if !first {
            sb <+ ","
          }
          first = false
          sb <+ "\{oPrefix}\{num}\{oMid}\{asset.data_url}\{oSuffix}"
        }
        None => {
          if !first {
            sb <+ ","
          }
          first = false
          sb <+ "\{oPrefix}\{num}\{oMid}\{oSuffix}"
        }
      }
    }
    sb <+ "]"
    sb.to_string()
  } catch {
    e => "ERROR: \{e}"
  }
}

///|
fn main {
  println("MS-DOC Worker logic loaded")
}
