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
      if asset.asset_type == "image" && asset.bytes.length() > 0 && asset.id.has_prefix("asset-img-") {
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

///| Get image data URL from the stored ParseContext
///| Images are pre-processed during streamInit, so this just returns the data URL
pub fn worker_stream_extract_image(asset_index : Int) -> String {
  if _ctx_holder.length() == 0 { return "" }
  let ctx = _ctx_holder[0]
  if asset_index < 0 || asset_index >= ctx.assets.length() { return "" }
  ctx.assets[asset_index].data_url
}

///| Get all image data URLs in one batch — no per-image postMessage needed
///| Returns: count|||url0|||url1|||...|||urlN
pub fn worker_stream_get_all_images() -> String {
  if _ctx_holder.length() == 0 { return "0" }
  let ctx = _ctx_holder[0]
  let sb = StringBuilder::new()
  let mut count = 0
  for asset in ctx.assets {
    if asset.asset_type == "image" && asset.data_url.length() > 0 && !asset.data_url.has_prefix("data:image/svg+xml") {
      if count > 0 { sb <+ "|||" }
      sb <+ "\{asset.data_url}"
      count += 1
    }
  }
  "\{count}|||\{sb.to_string()}"
}

///| Release context after all work is done
pub fn worker_stream_release() -> String {
  while _ctx_holder.length() > 0 { ignore(_ctx_holder.unsafe_pop()) }
  "ok"
}
