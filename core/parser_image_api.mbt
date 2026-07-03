///| Deferred image processing API
///| Extracted from parser.mbt for better organization

///| Parse MS-DOC file with deferred image processing
///| Returns a DeferredParseResult that allows async image extraction
///| This is the fastest parse option - images are placeholders until extracted
pub fn parse_ms_doc_deferred(input : FixedArray[Byte]) -> DeferredParseResult raise {
  let result = parse_ms_doc(input)
  DeferredParseResult::{
    result,
    data_bytes: input,
    image_config: default_image_config(),
    image_cache: Map([], capacity=16),
  }
}

///| Parse MS-DOC file with deferred image processing and custom config
pub fn parse_ms_doc_deferred_with_config(
  input : FixedArray[Byte],
  config : ImageProcessorConfig,
) -> DeferredParseResult raise {
  let result = parse_ms_doc(input)
  DeferredParseResult::{
    result,
    data_bytes: input,
    image_config: config,
    image_cache: Map([], capacity=16),
  }
}

///| Extract a single image from a deferred parse result
///| Uses cache to avoid re-extracting the same image
pub fn extract_deferred_image(
  deferred : DeferredParseResult,
  asset_index : Int,
) -> Option[Asset] {
  if asset_index < 0 || asset_index >= deferred.result.assets.length() {
    return None
  }
  let asset = deferred.result.assets[asset_index]
  // Check if already processed (not a placeholder)
  if !asset.data_url.has_prefix("data:image/svg+xml;base64,") {
    return Some(asset)
  }
  // Check cache first
  match deferred.image_cache.get(asset_index) {
    Some(cached) => return Some(cached)
    None => ()
  }
  // Process raw image bytes if available
  if asset.bytes.length() > 0 {
    let processed = process_raw_image_asset(asset)
    deferred.image_cache.set(asset_index, processed)
    return Some(processed)
  }
  None
}

///| Extract all images from a deferred parse result
///| Returns a new array with processed images
pub fn extract_all_deferred_images(
  deferred : DeferredParseResult,
) -> Array[Asset] raise {
  let result : Array[Asset] = Array::new()
  let mut i = 0
  while i < deferred.result.assets.length() {
    match extract_deferred_image(deferred, i) {
      Some(processed) => result.push(processed)
      None => result.push(deferred.result.assets[i])
    }
    i += 1
  }
  result
}

///| Get the parse result from a deferred parse
pub fn get_deferred_result(deferred : DeferredParseResult) -> MsDocParseResult {
  deferred.result
}

///| Check if an asset is a placeholder (needs async extraction)
pub fn is_placeholder_asset(asset : Asset) -> Bool {
  // Asset is a placeholder if it has raw bytes but:
  // 1. data_url is a SVG placeholder, OR
  // 2. data_url is empty (not yet processed)
  asset.bytes.length() > 0 && (asset.data_url.has_prefix("data:image/svg+xml;base64,") || asset.data_url.length() == 0)
}

///| Count placeholder assets in a parse result
pub fn count_placeholder_assets(assets : Array[Asset]) -> Int {
  let mut count = 0
  for asset in assets {
    if is_placeholder_asset(asset) {
      count += 1
    }
  }
  count
}

///| Preload all images from a parse result (blocking)
///| Processes all raw image assets
///| Uses content-signature dedup to avoid redundant processing
pub fn preload_all_images(result : MsDocParseResult) -> Array[Asset] {
  let processed : Array[Asset] = Array::new()
  for i in 0..<result.assets.length() {
    let asset = result.assets[i]
    if asset.data_url.length() > 0 && !is_placeholder_asset(asset) {
      processed.push(asset)
    } else if asset.bytes.length() > 0 {
      match result.image_cache.get(i) {
        Some(cached) => processed.push(cached)
        None => {
          // Check content-signature dedup
          let sig = compute_asset_signature(asset.bytes)
          match result.content_dedup_cache.get(sig) {
            Some(cached) => {
              result.image_cache.set(i, cached)
              processed.push(cached)
            }
            None => {
              let p = process_raw_image_asset(asset)
              result.image_cache.set(i, p)
              result.content_dedup_cache.set(sig, p)
              processed.push(p)
            }
          }
        }
      }
    } else {
      processed.push(asset)
    }
  }
  processed
}

///| Extract image with fallback mechanism
///| Processes raw image bytes stored in asset during parse
///| Uses content-signature dedup to avoid redundant processing of identical images
pub fn extract_image_with_fallback(
  result : MsDocParseResult,
  asset_index : Int,
) -> Asset {
  if asset_index < 0 || asset_index >= result.assets.length() {
    return Asset::{ id: "", asset_type: "", name: "", mime: "", bytes: [], data_url: "", width: 0, height: 0 }
  }
  let asset = result.assets[asset_index]
  // If already has real data_url, return as-is
  if asset.data_url.length() > 0 && !is_placeholder_asset(asset) {
    return asset
  }
  // If has raw bytes, process them
  if asset.bytes.length() > 0 {
    // Check per-index cache first
    match result.image_cache.get(asset_index) {
      Some(cached) => return cached
      None => ()
    }
    // Check content-signature dedup cache
    let sig = compute_asset_signature(asset.bytes)
    match result.content_dedup_cache.get(sig) {
      Some(cached) => {
        // Same content already processed - reuse result
        result.image_cache.set(asset_index, cached)
        return cached
      }
      None => ()
    }
    // Process raw image
    let processed = process_raw_image_asset(asset)
    result.image_cache.set(asset_index, processed)
    result.content_dedup_cache.set(sig, processed)
    return processed
  }
  // Fallback: return placeholder
  asset
}
