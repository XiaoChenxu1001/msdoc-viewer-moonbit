///| Image processor strategy interface and implementations

///| Supports multiple strategies for handling unsupported image formats (EMF, WMF, etc.)

///|
/// Image processing strategy type
pub enum ImageStrategy {
  /// Convert to SVG using emf2svg/wmf2svg (default)
  EmfToSvg
  /// Extract embedded bitmap from EMF/WMF
  ExtractBitmap
  /// Render to Canvas and export as PNG
  CanvasRender
  /// Show placeholder with download link
  DownloadLink
  /// Keep original format as-is (for native/platform rendering)
  KeepOriginal
  /// Custom strategy with handler function
  Custom(String)
} derive(Show, Eq)

///|
/// Image processing result
pub struct ImageProcessResult {
  /// Processed image bytes (PNG, JPEG, SVG, etc.)
  bytes : FixedArray[Byte]
  /// MIME type of processed image
  mime : String
  /// Whether processing succeeded
  success : Bool
  /// Error message if failed
  error : String
  /// Fallback data URL if original format preserved
  fallback_url : String
}

///|
/// Image processor configuration
pub struct ImageProcessorConfig {
  /// Primary strategy to use
  primary : ImageStrategy
  /// Whether to try fallback strategies
  enable_fallback : Bool
  /// Maximum image size to process (bytes)
  max_size : Int
  /// Custom MIME type mappings
  mime_overrides : Map[String, String]
}

///|
/// Default configuration
pub fn default_image_config() -> ImageProcessorConfig {
  ImageProcessorConfig::{
    primary: ImageStrategy::EmfToSvg,
    enable_fallback: true,
    max_size: 8 * 1024 * 1024, // 8MB
    mime_overrides: Map([], capacity=16),
  }
}

///|
/// Check if MIME type needs processing (not web-supported)
pub fn needs_processing(mime : String) -> Bool {
  match mime {
    "image/emf" | "image/wmf" | "application/octet-stream" => true
    _ => false
  }
}

///|
/// Process image with configured strategy
pub fn process_image(
  bytes : FixedArray[Byte],
  mime : String,
  config : ImageProcessorConfig,
) -> ImageProcessResult {
  // Check if processing is needed
  if !needs_processing(mime) {
    return ImageProcessResult::{
      bytes,
      mime,
      success: true,
      error: "",
      fallback_url: "",
    }
  }

  // Check size limit
  if bytes.length() > config.max_size {
    return ImageProcessResult::{
      bytes: FixedArray::make(0, 0x0),
      mime: "unknown",
      success: false,
      error: "Image too large: \{bytes.length()} bytes exceeds limit \{config.max_size}",
      fallback_url: "",
    }
  }

  // Fast-path: EMF/WMF use ExtractBitmap (WASM conversion handled at JS layer)
  if mime == "image/emf" || mime == "image/wmf" {
    let result = try_extract_bitmap(bytes, mime)
    if result.success {
      return result
    }
  }

  // Try primary strategy
  let result = try_strategy(bytes, mime, config.primary)
  if result.success {
    return result
  }

  // Try fallback strategies if enabled
  if config.enable_fallback {
    let fallbacks = [
      ImageStrategy::ExtractBitmap,
      ImageStrategy::CanvasRender,
      ImageStrategy::DownloadLink,
      ImageStrategy::KeepOriginal,
    ]
    for strategy in fallbacks {
      if strategy != config.primary {
        let fallback_result = try_strategy(bytes, mime, strategy)
        if fallback_result.success {
          return fallback_result
        }
      }
    }
  }

  // All strategies failed - return enhanced placeholder
  let placeholder_url = if mime == "image/emf" || mime == "image/wmf" {
    create_emf_placeholder_url(bytes, mime)
  } else {
    create_download_placeholder(bytes, mime)
  }
  ImageProcessResult::{
    bytes: FixedArray::make(0, 0x0),
    mime: "unknown",
    success: false,
    error: "All image processing strategies failed",
    fallback_url: placeholder_url,
  }
}

///|
/// Try a specific strategy
fn try_strategy(
  bytes : FixedArray[Byte],
  mime : String,
  strategy : ImageStrategy,
) -> ImageProcessResult {
  match strategy {
    ImageStrategy::EmfToSvg => try_emf_to_svg(bytes, mime)
    ImageStrategy::ExtractBitmap => try_extract_bitmap(bytes, mime)
    ImageStrategy::CanvasRender => try_canvas_render(bytes, mime)
    ImageStrategy::DownloadLink => create_download_result(bytes, mime)
    ImageStrategy::KeepOriginal => try_keep_original(bytes, mime)
    ImageStrategy::Custom(name) =>
      ImageProcessResult::{
        bytes: FixedArray::make(0, 0x0),
        mime: "unknown",
        success: false,
        error: "Custom strategy '\{name}' not implemented",
        fallback_url: "",
      }
  }
}

///| Try to convert EMF/WMF to SVG using JavaScript bridge

///|
/// This function is called from JavaScript layer via emf_js_bridge.js
fn try_emf_to_svg(
  bytes : FixedArray[Byte],
  mime : String,
) -> ImageProcessResult {
  // Check if this is actually EMF/WMF
  if mime != "image/emf" && mime != "image/wmf" {
    return ImageProcessResult::{
      bytes: FixedArray::make(0, 0x0),
      mime: "unknown",
      success: false,
      error: "Not EMF/WMF format",
      fallback_url: "",
    }
  }

  // EMF to SVG conversion is handled at the JavaScript layer
  // This function returns failure to trigger the fallback mechanism
  // The actual conversion happens in emf_js_bridge.js when called from JavaScript
  ImageProcessResult::{
    bytes: FixedArray::make(0, 0x0),
    mime: "unknown",
    success: false,
    error: "EMF to SVG conversion delegated to JavaScript layer",
    fallback_url: "",
  }
}

///|
/// Try to extract embedded bitmap from EMF/WMF
fn try_extract_bitmap(
  bytes : FixedArray[Byte],
  mime : String,
) -> ImageProcessResult {
  // Check if this is actually EMF/WMF
  if mime != "image/emf" && mime != "image/wmf" {
    return ImageProcessResult::{
      bytes: FixedArray::make(0, 0x0),
      mime: "unknown",
      success: false,
      error: "Not EMF/WMF format",
      fallback_url: "",
    }
  }

  // Search for PNG signature (0x89 0x50 0x4E 0x47)
  let mut i = 0
  while i + 4 <= bytes.length() {
    if bytes[i] == 0x89 &&
      bytes[i + 1] == 0x50 &&
      bytes[i + 2] == 0x4E &&
      bytes[i + 3] == 0x47 {
      let png_end = find_png_end(bytes, i)
      let png_bytes = FixedArray::makei(png_end - i, fn(j) { bytes[i + j] })
      return ImageProcessResult::{
        bytes: png_bytes,
        mime: "image/png",
        success: true,
        error: "",
        fallback_url: "",
      }
    }
    i += 1
  }

  // Search for JPEG signature (0xFF 0xD8 0xFF)
  i = 0
  while i + 3 <= bytes.length() {
    if bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF {
      let jpeg_end = find_jpeg_end(bytes, i)
      let jpeg_bytes = FixedArray::makei(jpeg_end - i, fn(j) { bytes[i + j] })
      return ImageProcessResult::{
        bytes: jpeg_bytes,
        mime: "image/jpeg",
        success: true,
        error: "",
        fallback_url: "",
      }
    }
    i += 1
  }

  // Search for BMP signature (0x42 0x4D)
  i = 0
  while i + 2 <= bytes.length() {
    if bytes[i] == 0x42 && bytes[i + 1] == 0x4D {
      // BMP file: read size from header (bytes 2-5, little-endian)
      if i + 6 <= bytes.length() {
        let bmp_size = bytes[i + 2].to_int() |
          (bytes[i + 3].to_int() << 8) |
          (bytes[i + 4].to_int() << 16) |
          (bytes[i + 5].to_int() << 24)
        if bmp_size > 0 && i + bmp_size <= bytes.length() {
          let bmp_bytes = FixedArray::makei(bmp_size, fn(j) { bytes[i + j] })
          return ImageProcessResult::{
            bytes: bmp_bytes,
            mime: "image/bmp",
            success: true,
            error: "",
            fallback_url: "",
          }
        }
      }
    }
    i += 1
  }

  // Search for GIF signature (0x47 0x49 0x46)
  i = 0
  while i + 3 <= bytes.length() {
    if bytes[i] == 0x47 && bytes[i + 1] == 0x49 && bytes[i + 2] == 0x46 {
      // GIF file: find trailer (0x3B)
      let mut j = i + 3
      while j < bytes.length() {
        if bytes[j] == 0x3B {
          let gif_bytes = FixedArray::makei(j - i + 1, fn(k) { bytes[i + k] })
          return ImageProcessResult::{
            bytes: gif_bytes,
            mime: "image/gif",
            success: true,
            error: "",
            fallback_url: "",
          }
        }
        j += 1
      }
    }
    i += 1
  }

  // No embedded bitmap found
  ImageProcessResult::{
    bytes: FixedArray::make(0, 0x0),
    mime: "unknown",
    success: false,
    error: "No embedded bitmap found in EMF/WMF",
    fallback_url: "",
  }
}

///| Try to render to Canvas and export as PNG

///|
/// This is a placeholder - actual implementation requires Canvas API
fn try_canvas_render(
  bytes : FixedArray[Byte],
  mime : String,
) -> ImageProcessResult {
  // TODO: Implement Canvas-based rendering
  // This would require:
  // 1. Create off-screen canvas
  // 2. Parse EMF/WMF and render to canvas
  // 3. Export canvas as PNG
  // For now, return failure to trigger fallback
  ImageProcessResult::{
    bytes: FixedArray::make(0, 0x0),
    mime: "unknown",
    success: false,
    error: "Canvas rendering not yet implemented",
    fallback_url: "",
  }
}

///| Keep original format as-is

///|
/// Useful for native/platform rendering (e.g., Windows) that natively support EMF/WMF
fn try_keep_original(
  bytes : FixedArray[Byte],
  mime : String,
) -> ImageProcessResult {
  // Simply pass through the original bytes and MIME type
  ImageProcessResult::{
    bytes,
    mime,
    success: true,
    error: "",
    fallback_url: "",
  }
}

///|
/// Create download link result
fn create_download_result(
  bytes : FixedArray[Byte],
  mime : String,
) -> ImageProcessResult {
  // Use enhanced EMF placeholder for EMF/WMF, regular placeholder for others
  let placeholder_svg = if mime == "image/emf" || mime == "image/wmf" {
    create_emf_placeholder(bytes, mime)
  } else {
    create_download_placeholder_svg(bytes.length(), mime)
  }
  let svg_bytes = string_to_bytes(placeholder_svg)

  ImageProcessResult::{
    bytes: svg_bytes,
    mime: "image/svg+xml",
    success: true,
    error: "",
    fallback_url: "",
  }
}

///|
/// Create download placeholder SVG with enhanced info
fn create_download_placeholder_svg(size : Int, mime : String) -> String {
  let size_display = if size > 1024 { "\{size / 1024}KB" } else { "\{size}B" }

  // Get format name from mime type
  let format_name = if mime == "image/png" {
    "PNG"
  } else if mime == "image/jpeg" {
    "JPEG"
  } else if mime == "image/gif" {
    "GIF"
  } else if mime == "image/bmp" {
    "BMP"
  } else if mime == "image/emf" {
    "EMF"
  } else if mime == "image/wmf" {
    "WMF"
  } else {
    "IMG"
  }

  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"200\" height=\"150\" viewBox=\"0 0 200 150\">" +
  "<rect width=\"200\" height=\"150\" fill=\"#f6f8fa\" stroke=\"#d0d7de\" stroke-width=\"1\" rx=\"4\"/>" +
  "<rect x=\"70\" y=\"30\" width=\"60\" height=\"50\" fill=\"#e1e4e8\" stroke=\"#d0d7de\" stroke-width=\"1\" rx=\"2\"/>" +
  "<path d=\"M100 45 L100 65 M92 57 L100 65 L108 57\" stroke=\"#666\" stroke-width=\"2\" fill=\"none\"/>" +
  "<text x=\"100\" y=\"100\" text-anchor=\"middle\" font-family=\"-apple-system,BlinkMacSystemFont,sans-serif\" font-size=\"11\" fill=\"#24292e\">" +
  "\{format_name}</text>" +
  "<text x=\"100\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system,BlinkMacSystemFont,sans-serif\" font-size=\"10\" fill=\"#586069\">" +
  "\{size_display}</text>" +
  "<text x=\"100\" y=\"138\" text-anchor=\"middle\" font-family=\"-apple-system,BlinkMacSystemFont,sans-serif\" font-size=\"10\" fill=\"#0366d6\">" +
  "Download</text>" +
  "</svg>"
}

///|
/// Create download placeholder (returns data URL)
fn create_download_placeholder(
  bytes : FixedArray[Byte],
  mime : String,
) -> String {
  let svg = create_download_placeholder_svg(bytes.length(), mime)
  let svg_bytes = string_to_bytes(svg)
  data_url_from_bytes(svg_bytes, "image/svg+xml")
}

///| Create EMF/WMF placeholder with dimensions and info

///|
/// This is a generic function that works across all target formats
pub fn create_emf_placeholder(
  bytes : FixedArray[Byte],
  mime : String,
) -> String {
  // Extract dimensions from EMF header
  let (width, height) = if bytes.length() >= 40 &&
    bytes[0] == 0x01 &&
    bytes[1] == 0x00 {
    // EMF format: read bounds from header
    let reader = BinaryReader::make(bytes)
    let left = reader.i32(8)
    let top = reader.i32(12)
    let right = reader.i32(16)
    let bottom = reader.i32(20)
    let w = right - left
    let h = bottom - top
    if w > 0 && h > 0 {
      (w, h)
    } else {
      (200, 150)
    }
  } else {
    (200, 150)
  }

  let size_display = if bytes.length() > 1024 {
    "\{bytes.length() / 1024}KB"
  } else {
    "\{bytes.length()}B"
  }

  let format_name = if mime == "image/emf" {
    "EMF"
  } else if mime == "image/wmf" {
    "WMF"
  } else {
    "IMG"
  }

  // Create SVG placeholder with actual dimensions
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}\" height=\"\{height}\" viewBox=\"0 0 \{width} \{height}\">" +
  "<rect width=\"\{width}\" height=\"\{height}\" fill=\"#f6f8fa\" stroke=\"#d0d7de\" stroke-width=\"1\" rx=\"4\"/>" +
  "<rect x=\"\{width / 2 - 30}\" y=\"\{height / 2 - 35}\" width=\"60\" height=\"50\" fill=\"#e1e4e8\" stroke=\"#d0d7de\" stroke-width=\"1\" rx=\"2\"/>" +
  "<path d=\"M\{width / 2} \{height / 2 - 20} L\{width / 2} \{height / 2} M\{width / 2 - 8} \{height / 2 - 8} L\{width / 2} \{height / 2} L\{width / 2 + 8} \{height / 2 - 8}\" stroke=\"#666\" stroke-width=\"2\" fill=\"none\"/>" +
  "<text x=\"\{width / 2}\" y=\"\{height / 2 + 15}\" text-anchor=\"middle\" font-family=\"-apple-system,BlinkMacSystemFont,sans-serif\" font-size=\"11\" fill=\"#24292e\">" +
  "\{format_name}</text>" +
  "<text x=\"\{width / 2}\" y=\"\{height / 2 + 33}\" text-anchor=\"middle\" font-family=\"-apple-system,BlinkMacSystemFont,sans-serif\" font-size=\"10\" fill=\"#586069\">" +
  "\{width}×\{height}px · \{size_display}</text>" +
  "</svg>"
}

///|
/// Create EMF placeholder data URL
pub fn create_emf_placeholder_url(
  bytes : FixedArray[Byte],
  mime : String,
) -> String {
  let svg = create_emf_placeholder(bytes, mime)
  let svg_bytes = string_to_bytes(svg)
  data_url_from_bytes(svg_bytes, "image/svg+xml")
}

///|
/// Convert string to bytes (UTF-8)
fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let len = String::length(s)
  FixedArray::makei(len, fn(i) { s[i].to_byte() })
}
