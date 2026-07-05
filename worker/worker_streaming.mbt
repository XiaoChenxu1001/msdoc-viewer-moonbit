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

    // Collect asset indices for images (not CFB offsets)
    // These are indices into ctx.assets array for lazy processing
    let offsets = StringBuilder::new()
    let mut first = true
    let mut idx = 0
    for asset in ctx.assets {
      if asset.asset_type == "image" && asset.bytes.length() > 0 && asset.id.has_prefix("asset-img-") {
        if !first { offsets <+ "," }
        first = false
        offsets <+ "\{idx}"
      }
      idx += 1
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
///| Returns: "{asset_count}|||{html}|||{idx0},{idx1},..."
pub fn worker_stream_chunk(start : Int, count : Int) -> String {
  if _ctx_holder.length() == 0 { return "ERROR: No document loaded." }
  let result = @core.render_chunk(_ctx_holder[0], start, count)
  let idx_str = StringBuilder::new()
  let mut first = true
  for idx in result.asset_indices {
    if !first { idx_str <+ "," }
    first = false
    idx_str <+ "\{idx}"
  }
  "\{result.asset_indices.length()}|||\{result.html}|||\{idx_str.to_string()}"
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

///| Get image data URL from the stored ParseContext
///| Images are processed lazily on first access
pub fn worker_stream_extract_image(asset_index : Int) -> String {
  if _ctx_holder.length() == 0 { return "" }
  let ctx = _ctx_holder[0]
  @core.get_or_process_image(ctx, asset_index)
}

///| Get all image data URLs in one batch — processes lazily on access
///| Returns: count|||url0|||url1|||...|||urlN
pub fn worker_stream_get_all_images() -> String {
  if _ctx_holder.length() == 0 { return "0" }
  let ctx = _ctx_holder[0]
  let sb = StringBuilder::new()
  let mut count = 0
  let mut idx = 0
  for asset in ctx.assets {
    if asset.asset_type == "image" && asset.bytes.length() > 0 && asset.id.has_prefix("asset-img-") {
      // Process lazily using get_or_process_image
      let data_url = @core.get_or_process_image(ctx, idx)
      // Only include non-placeholder URLs
      if data_url.length() > 0 && !data_url.has_prefix("data:image/svg+xml") {
        if count > 0 { sb <+ "|||" }
        sb <+ "\{data_url}"
        count += 1
      }
    }
    idx += 1
  }
  "\{count}|||\{sb.to_string()}"
}

///| Release context after all work is done
pub fn worker_stream_release() -> String {
  while _ctx_holder.length() > 0 { ignore(_ctx_holder.unsafe_pop()) }
  "ok"
}
