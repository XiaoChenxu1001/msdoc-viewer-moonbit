///| Streaming worker entry point for MS-DOC parsing
///| Supports chunk-based rendering for progressive HTML output
///| Uses Array as single-element mutable container for cross-call state

///| Global context holder (single-element array acts as mutable box)
let _ctx_holder : Array[@core.ParseContext] = Array::new()
let _css_holder : Array[String] = Array::new()
let _images_json_holder : Array[String] = Array::new()

///| Initialize streaming parse: parse document, store context, return metadata
///| Returns: "{total_blocks}|||CSS|||{css}|||IMAGES|||{images_json}"
pub fn worker_stream_init(input : FixedArray[Byte]) -> String {
  try {
    let ctx = @core.parse_init(input)
    let css = @core.render_css(ctx, "")
    let total = @core.get_block_count(ctx)

    // Build JSON array of image data URLs: [{"index":N,"data_url":"..."}]
    let images_sb = StringBuilder::new()
    images_sb <+ "["
    let mut first = true
    let mut idx = 0
    for url in ctx.image_data_urls {
      if url.length() > 0 && url.has_prefix("data:") {
        if !first {
          images_sb <+ ","
        }
        first = false
        // Escape the data_url for JSON (replace " with \")
        let escaped = url.replace(old = "\"", new = "\\\"")
        images_sb <+ "{\"index\":\{idx},\"data_url\":\"\{escaped}\"}"
      }
      idx += 1
    }
    images_sb <+ "]"

    // Clear previous state and store new
    while _ctx_holder.length() > 0 {
      ignore(_ctx_holder.unsafe_pop())
    }
    _ctx_holder.push(ctx)
    while _css_holder.length() > 0 {
      ignore(_css_holder.unsafe_pop())
    }
    _css_holder.push(css)
    while _images_json_holder.length() > 0 {
      ignore(_images_json_holder.unsafe_pop())
    }
    _images_json_holder.push(images_sb.to_string())
    "\{total}|||CSS|||\{css}|||IMAGES|||\{images_sb.to_string()}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///| Render a chunk of blocks
///| Returns: HTML fragment string
pub fn worker_stream_chunk(start : Int, count : Int) -> String {
  if _ctx_holder.length() == 0 {
    return "ERROR: No document loaded. Call worker_stream_init first."
  }
  @core.render_chunk(_ctx_holder[0], start, count)
}

///| Render footer content (headers, footers, footnotes, endnotes, comments)
///| Returns: HTML fragment string
pub fn worker_stream_footer() -> String {
  if _ctx_holder.length() == 0 {
    return "ERROR: No document loaded. Call worker_stream_init first."
  }
  let html = @core.render_footer_html(_ctx_holder[0])
  // Release context
  ignore(_ctx_holder.unsafe_pop())
  html
}

///| Get stored pre-extracted image data URLs as JSON
pub fn worker_stream_get_images_json() -> String {
  if _images_json_holder.length() == 0 {
    return "[]"
  }
  let result = _images_json_holder[0]
  ignore(_images_json_holder.unsafe_pop())
  result
}
