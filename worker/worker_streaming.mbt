///| Streaming worker entry point for MS-DOC parsing
///| Uses Array as single-element mutable container for cross-call state

///| Global context holder
let _ctx_holder : Array[@core.ParseContext] = Array::new()
let _css_holder : Array[String] = Array::new()
let _offsets_holder : Array[String] = Array::new()

///| Initialize streaming parse, return metadata + image offsets
///| Returns: "{total}|||CSS|||{css}|||OFFSETS|||{offsets}"
pub fn worker_stream_init(input : FixedArray[Byte]) -> String {
  try {
    let ctx = @core.parse_init(input)
    let css = @core.render_css(ctx, "")
    let total = @core.get_block_count(ctx)

    // Collect CFB offsets for image extraction
    let offsets = StringBuilder::new()
    let mut first = true
    for asset in ctx.assets {
      if asset.asset_type == "image" && asset.bytes.length() > 0 && asset.id.length() > 10 {
        if !first { offsets <+ "," }
        first = false
        offsets <+ "\{asset.id[10 : asset.id.length()]}"
      }
    }

    while _ctx_holder.length() > 0 { ignore(_ctx_holder.unsafe_pop()) }
    _ctx_holder.push(ctx)
    while _css_holder.length() > 0 { ignore(_css_holder.unsafe_pop()) }
    _css_holder.push(css)
    while _offsets_holder.length() > 0 { ignore(_offsets_holder.unsafe_pop()) }
    _offsets_holder.push(offsets.to_string())
    "\{total}|||CSS|||\{css}|||OFFSETS|||\{offsets.to_string()}"
  } catch {
    e => "ERROR: \{e}"
  }
}

///| Render a chunk of blocks
pub fn worker_stream_chunk(start : Int, count : Int) -> String {
  if _ctx_holder.length() == 0 { return "ERROR: No document loaded." }
  @core.render_chunk(_ctx_holder[0], start, count)
}

///| Render footer content (headers, footers, footnotes, endnotes, comments)
pub fn worker_stream_footer() -> String {
  if _ctx_holder.length() == 0 { return "ERROR: No document loaded." }
  @core.render_footer_html(_ctx_holder[0])
}

///| Get stored image offsets string
pub fn worker_stream_get_offsets() -> String {
  if _offsets_holder.length() == 0 { return "" }
  let result = _offsets_holder[0]
  ignore(_offsets_holder.unsafe_pop())
  result
}

///| Release context after all work is done
pub fn worker_stream_release() -> String {
  while _ctx_holder.length() > 0 { ignore(_ctx_holder.unsafe_pop()) }
  "ok"
}
