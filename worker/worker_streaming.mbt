///| Streaming worker entry point for MS-DOC parsing
///| Supports chunk-based rendering for progressive HTML output
///| Uses Array as single-element mutable container for cross-call state

///| Global context holder (single-element array acts as mutable box)
let _ctx_holder : Array[@core.ParseContext] = Array::new()
let _css_holder : Array[String] = Array::new()
let _offsets_holder : Array[String] = Array::new()

///| Initialize streaming parse: parse document, store context, return metadata
///| Returns: "{total_blocks}|||CSS|||{css}"
pub fn worker_stream_init(input : FixedArray[Byte]) -> String {
  try {
    let ctx = @core.parse_init(input)
    let css = @core.render_css(ctx, "")
    let total = @core.get_block_count(ctx)

    // Collect asset CFB offsets for image extraction
    let offsets = StringBuilder::new()
    let mut first = true
    for asset in ctx.assets {
      if asset.asset_type == "image" && asset.bytes.length() > 0 {
        if asset.id.length() > 10 {
          if !first {
            offsets <+ ","
          }
          first = false
          offsets <+ "\{asset.id[10 : asset.id.length()]}"
        }
      }
    }

    // Clear previous state and store new
    while _ctx_holder.length() > 0 {
      ignore(_ctx_holder.unsafe_pop())
    }
    _ctx_holder.push(ctx)
    while _css_holder.length() > 0 {
      ignore(_css_holder.unsafe_pop())
    }
    _css_holder.push(css)
    while _offsets_holder.length() > 0 {
      ignore(_offsets_holder.unsafe_pop())
    }
    _offsets_holder.push(offsets.to_string())
    "\{total}|||CSS|||\{css}"
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

///| Get stored asset offsets (comma-separated CFB offsets for image extraction)
///| Must be called before worker_stream_footer() releases the context
pub fn worker_stream_get_offsets() -> String {
  if _offsets_holder.length() == 0 {
    return ""
  }
  let result = _offsets_holder[0]
  ignore(_offsets_holder.unsafe_pop())
  result
}
