///| WASM linear memory bridge for image extraction
///| Extracts all images from a parsed document and returns JSON

///| Extract all images from document data (WASM linear memory ABI)
///| Input: pointer to FixedArray[Byte] in linear memory
///| Returns: (tag, String pointer) — tag=1 success, tag=0 error
///| The string is a JSON array of {index, data_url} for each placeholder image
pub fn extract_all_images_sync(input : FixedArray[Byte]) -> String raise {
  let parsed = parse_ms_doc(input)
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
}
