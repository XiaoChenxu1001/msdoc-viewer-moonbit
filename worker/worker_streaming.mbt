///| Streaming worker entry point for MS-DOC parsing
///| Supports chunk-based rendering for progressive HTML output
///| Uses Array as single-element mutable container for cross-call state

///| Global context holder (single-element array acts as mutable box)
let _ctx_holder : Array[@core.ParseContext] = Array::new()
let _css_holder : Array[String] = Array::new()
let _image_count_holder : Array[Int] = Array::new()

///| Initialize streaming parse: parse document, store context, return metadata
///| Returns: "{total_blocks}|||CSS|||{css}|||IMAGES|||{image_count}"
///| Image data URLs are retrieved separately via worker_stream_get_image
pub fn worker_stream_init(input : FixedArray[Byte]) -> String {
  try {
    let ctx = @core.parse_init(input)
    let css = @core.render_css(ctx, "")
    let total = @core.get_block_count(ctx)
    // Count images that have real (non-placeholder) data URLs
    let mut image_count = 0
    for asset in ctx.assets {
      if asset.asset_type == "image" && asset.data_url.length() > 0 && !asset.data_url.has_prefix("data:image/svg+xml") {
        image_count += 1
      }
    }
    // Clear previous state and store new
    while _ctx_holder.length() > 0 { ignore(_ctx_holder.unsafe_pop()) }
    _ctx_holder.push(ctx)
    while _css_holder.length() > 0 { ignore(_css_holder.unsafe_pop()) }
    _css_holder.push(css)
    while _image_count_holder.length() > 0 { ignore(_image_count_holder.unsafe_pop()) }
    _image_count_holder.push(image_count)
    "\{total}|||CSS|||\{css}|||IMAGES|||\{image_count}"
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
///| NOTE: does NOT release context - call worker_stream_release() after images are fetched
pub fn worker_stream_footer() -> String {
  if _ctx_holder.length() == 0 {
    return "ERROR: No document loaded. Call worker_stream_init first."
  }
  @core.render_footer_html(_ctx_holder[0])
}

///| Release the streaming context (call after all images are fetched)
pub fn worker_stream_release() -> String {
  if _ctx_holder.length() > 0 {
    ignore(_ctx_holder.unsafe_pop())
  }
  "ok"
}

///| Get a single pre-extracted image data URL by asset index
///| Returns the data URL string for the image at the given index
///| Returns empty string if index is out of range or not an image
pub fn worker_stream_get_image(asset_index : Int) -> String {
  if _ctx_holder.length() == 0 { return "" }
  let ctx = _ctx_holder[0]
  if asset_index < 0 || asset_index >= ctx.assets.length() { return "" }
  let asset = ctx.assets[asset_index]
  if asset.data_url.has_prefix("data:image/svg+xml") { return "" }
  asset.data_url
}
