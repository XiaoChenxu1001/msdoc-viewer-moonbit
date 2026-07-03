///| Object/Picture extractor for MS-DOC files

///| Asset type
pub struct Asset {
  id : String
  asset_type : String
  name : String
  mime : String
  bytes : FixedArray[Byte]
  data_url : String
  width : Int
  height : Int
}

///| Attachment result from OLE10 parsing
struct OLE10Info {
  label : String
  original_path : String
  temp_path : String
  data_size : Int
  bytes : FixedArray[Byte]
}

///| Object storage info
struct ObjectStorageInfo {
  attachment : Option[Asset]
  object_data : Option[FixedArray[Byte]]
}

///| Detect image format from bytes
pub fn detect_image_format(bytes : FixedArray[Byte]) -> String {
  if bytes.length() < 8 {
    return "unknown"
  }
  if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
    return "image/png"
  }
  if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
    return "image/jpeg"
  }
  if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
    return "image/gif"
  }
  if bytes[0] == 0x42 && bytes[1] == 0x4D {
    return "image/bmp"
  }
  if bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00 {
    return "image/tiff"
  }
  if bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A {
    return "image/tiff"
  }
  if bytes[0] == 0x01 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x00 {
    return "image/emf"
  }
  if bytes[0] == 0xD7 && bytes[1] == 0xCD && bytes[2] == 0xC6 && bytes[3] == 0x9A {
    return "image/wmf"
  }
  "unknown"
}

///| Detect MIME type from file magic bytes (broader than detect_image_format)
pub fn detect_mime_from_bytes(bytes : FixedArray[Byte]) -> String {
  if bytes.length() < 4 {
    return "application/octet-stream"
  }
  // Images
  let img = detect_image_format(bytes)
  if img != "unknown" {
    return img
  }
  // PDF: %PDF
  if bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46 {
    return "application/pdf"
  }
  // ZIP (covers OOXML, JAR, etc.): PK..
  if bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04 {
    return "application/zip"
  }
  // RAR: Rar!..
  if bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21 {
    return "application/x-rar-compressed"
  }
  // 7z: 7z..
  if bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF {
    return "application/x-7z-compressed"
  }
  // GZIP: ..
  if bytes[0] == 0x1F && bytes[1] == 0x8B {
    return "application/gzip"
  }
  // MS Office OLE2 (DOC/XLS/PPT): D0 CF 11 E0
  if bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0 {
    return "application/vnd.ms-object"
  }
  // OpenDocument (ODF): PK + mimetype
  if bytes.length() >= 30 && bytes[0] == 0x50 && bytes[1] == 0x4B {
    if bytes[26] == 0x6D && bytes[27] == 0x69 && bytes[28] == 0x74 && bytes[29] == 0x65 {
      return "application/vnd.oasis.opendocument.*"
    }
  }
  // TrueType font: offset 0 has specific tags
  if bytes[0] == 0x00 && bytes[1] == 0x01 && bytes[2] == 0x00 && bytes[3] == 0x00 {
    return "font/ttf"
  }
  // OpenType font: OTTO
  if bytes[0] == 0x4F && bytes[1] == 0x54 && bytes[2] == 0x54 && bytes[3] == 0x4F {
    return "font/otf"
  }
  "application/octet-stream"
}

///| Extract image dimensions from PICF/PICMID structure
///| PICF is 68 bytes, PICMID starts at offset 36
///| Returns (width_twips, height_twips, mx, my) or None if not available
pub fn extract_pic_dimensions(bytes : FixedArray[Byte], offset : Int) -> Option[(Int, Int, Int, Int)] {
  if offset + 68 > bytes.length() {
    return None
  }
  let reader = BinaryReader::make(bytes)
  let cb_header = reader.u16(offset + 4)
  if cb_header != 0x44 { // PICF header must be 68 bytes
    return None
  }
  // PICMID starts at offset 36 within PICF
  let picmid_offset = offset + 36
  let dxa_goal = reader.i16(picmid_offset) // Width in twips
  let dya_goal = reader.i16(picmid_offset + 2) // Height in twips
  let mx = reader.u16(picmid_offset + 4) // Width scaling ratio (tenths of percent)
  let my = reader.u16(picmid_offset + 6) // Height scaling ratio (tenths of percent)
  if dxa_goal > 0 && dya_goal > 0 {
    Some((dxa_goal, dya_goal, mx, my))
  } else {
    None
  }
}

///| Calculate display dimensions from PICMID values
///| width = dxa_goal * mx / 1000, height = dya_goal * my / 1000
///| Returns (width_twips, height_twips)
pub fn calculate_display_dimensions(dxa_goal : Int, dya_goal : Int, mx : Int, my : Int) -> (Int, Int) {
  let width = if mx > 0 { dxa_goal * mx / 1000 } else { dxa_goal }
  let height = if my > 0 { dya_goal * my / 1000 } else { dya_goal }
  (width, height)
}

///| Extract image dimensions from raw image bytes (PNG, JPEG, EMF)
///| Returns (width_px, height_px) or (0, 0) if unable to extract
pub fn extract_image_dimensions(bytes : FixedArray[Byte]) -> (Int, Int) {
  if bytes.length() < 8 {
    return (0, 0)
  }
  // PNG signature: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
  if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
    return extract_png_dimensions(bytes)
  }
  // JPEG: 0xFF 0xD8 0xFF
  if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
    return extract_jpeg_dimensions(bytes)
  }
  // EMF: 0x01 0x00 0x00 0x00
  if bytes[0] == 0x01 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x00 {
    return extract_emf_dimensions(bytes)
  }
  // BMP: 0x42 0x4D
  if bytes[0] == 0x42 && bytes[1] == 0x4D && bytes.length() >= 26 {
    let reader = BinaryReader::make(bytes)
    let width = reader.i32(18)
    let height = reader.i32(22)
    if width > 0 && height > 0 {
      return (width, height.abs())
    }
  }
  (0, 0)
}

///| Extract dimensions from PNG IHDR chunk
///| PNG signature (8 bytes) + chunk length (4 bytes) + "IHDR" (4 bytes) + width (4 bytes) + height (4 bytes)
fn extract_png_dimensions(bytes : FixedArray[Byte]) -> (Int, Int) {
  if bytes.length() < 24 {
    return (0, 0)
  }
  // Skip 8-byte signature, 4-byte chunk length, 4-byte "IHDR"
  let offset = 16
  let reader = BinaryReader::make(bytes)
  let width = reader.i32(offset)
  let height = reader.i32(offset + 4)
  if width > 0 && height > 0 {
    (width, height)
  } else {
    (0, 0)
  }
}

///| Extract dimensions from JPEG SOF marker
///| Scans for SOF0 (0xFFC0) or SOF2 (0xFFC2) marker
fn extract_jpeg_dimensions(bytes : FixedArray[Byte]) -> (Int, Int) {
  let mut i = 2
  while i + 9 < bytes.length() {
    // Look for SOF markers: 0xFFC0 or 0xFFC2 (progressive)
    if bytes[i] == 0xFF && (bytes[i + 1] == 0xC0 || bytes[i + 1] == 0xC2) {
      let reader = BinaryReader::make(bytes)
      // Skip marker (2 bytes) + length (2 bytes) + precision (1 byte)
      let height = reader.u16(i + 5)
      let width = reader.u16(i + 7)
      if width > 0 && height > 0 {
        return (width, height)
      }
    }
    // Skip to next marker
    if bytes[i] == 0xFF && bytes[i + 1] != 0x00 && bytes[i + 1] != 0xFF {
      if i + 3 < bytes.length() {
        let segment_length = (bytes[i + 2].to_int()) * 256 + (bytes[i + 3].to_int())
        i += 2 + segment_length
      } else {
        break
      }
    } else {
      i += 1
    }
  }
  (0, 0)
}

///| Extract dimensions from EMF header (EMR_HEADER record)
///| EMR_HEADER: iType (4 bytes) + nSize (4 bytes) + rclBounds (16 bytes)
///| rclBounds: left (4 bytes) + top (4 bytes) + right (4 bytes) + bottom (4 bytes)
fn extract_emf_dimensions(bytes : FixedArray[Byte]) -> (Int, Int) {
  if bytes.length() < 40 {
    return (0, 0)
  }
  let reader = BinaryReader::make(bytes)
  let i_type = reader.i32(0)
  // EMR_HEADER = 1
  if i_type != 1 {
    return (0, 0)
  }
  // rclBounds starts at offset 8 (after iType + nSize)
  let left = reader.i32(8)
  let top = reader.i32(12)
  let right = reader.i32(16)
  let bottom = reader.i32(20)
  let width = right - left
  let height = bottom - top
  if width > 0 && height > 0 {
    (width, height)
  } else {
    (0, 0)
  }
}

///| Find PNG IEND marker end
fn find_png_end(bytes : FixedArray[Byte], start : Int) -> Int {
  let mut i = start + 8
  while i + 8 <= bytes.length() {
    if bytes[i] == 0x49 && bytes[i + 1] == 0x45 && bytes[i + 2] == 0x4E && bytes[i + 3] == 0x44 {
      return i + 8
    }
    i += 1
  }
  bytes.length()
}

///| Find JPEG EOI marker end
fn find_jpeg_end(bytes : FixedArray[Byte], start : Int) -> Int {
  let mut i = start + 2
  while i + 1 < bytes.length() {
    if bytes[i] == 0xFF && bytes[i + 1] == 0xD9 {
      return i + 2
    }
    i += 1
  }
  bytes.length()
}

///| Find GIF trailer end
fn find_gif_end(bytes : FixedArray[Byte], start : Int) -> Int {
  let mut i = start + 6
  while i < bytes.length() {
    if bytes[i] == 0x3B {
      return i + 1
    }
    i += 1
  }
  bytes.length()
}

///| Find BMP end from file size field
fn find_bmp_end(bytes : FixedArray[Byte], start : Int) -> Int {
  if start + 6 <= bytes.length() {
    let reader = BinaryReader::make(bytes)
    let size = reader.u32(start + 2)
    if size > 0 && start + size <= bytes.length() {
      return start + size
    }
  }
  bytes.length()
}

///| Find EMF end from record size field
fn find_emf_end(bytes : FixedArray[Byte], start : Int) -> Int {
  if start + 48 <= bytes.length() {
    let reader = BinaryReader::make(bytes)
    let size = reader.u32(start + 40)
    if size > 0 && start + size <= bytes.length() {
      return start + size
    }
  }
  bytes.length()
}

///| Detect image segment in bytes, scanning for magic bytes
struct ImageSegment {
  mime : String
  start : Int
  end : Int
}

///| Scan for image magic bytes and determine image boundaries
///| Only extracts embedded raster images (PNG, JPEG, GIF, BMP, TIFF)
///| Does NOT extract standalone EMF/WMF — those come from ObjectPool EPRINT streams
pub fn detect_image_segment(bytes : FixedArray[Byte]) -> Option[ImageSegment] {
  if bytes.length() < 4 { return None }
  // Check BMP/TIFF at position 0 only (avoid false positives in OLE data)
  if bytes[0] == 0x42 && bytes[1] == 0x4D {
    let end = find_bmp_end(bytes, 0)
    return Some(ImageSegment::{ mime: "image/bmp", start: 0, end })
  }
  if bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00 {
    return Some(ImageSegment::{ mime: "image/tiff", start: 0, end: bytes.length() })
  }
  if bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A {
    return Some(ImageSegment::{ mime: "image/tiff", start: 0, end: bytes.length() })
  }
  // Scan entire body for embedded PNG/JPEG/GIF
  let mut i = 0
  while i + 4 < bytes.length() {
    if bytes[i] == 0x89 && bytes[i + 1] == 0x50 && bytes[i + 2] == 0x4E && bytes[i + 3] == 0x47 {
      let end = find_png_end(bytes, i)
      return Some(ImageSegment::{ mime: "image/png", start: i, end })
    }
    if bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF {
      let end = find_jpeg_end(bytes, i)
      return Some(ImageSegment::{ mime: "image/jpeg", start: i, end })
    }
    if bytes[i] == 0x47 && bytes[i + 1] == 0x49 && bytes[i + 2] == 0x46 && bytes[i + 3] == 0x38 {
      let end = find_gif_end(bytes, i)
      return Some(ImageSegment::{ mime: "image/gif", start: i, end })
    }
    i += 1
  }
  // No embedded raster found — return None (standalone EMF/WMF not extracted here)
  None
}

///| Extract picture asset from data bytes with picture offset
pub fn extract_picture_asset(
  data_bytes : FixedArray[Byte],
  picture_offset : Int,
) -> Option[Asset] {
  extract_picture_asset_with_config(data_bytes, picture_offset, default_image_config())
}

///| Extract picture asset with custom image processor config
///| When defer=true, skips base64 encoding and uses placeholder (for async processing)
pub fn extract_picture_asset_with_config(
  data_bytes : FixedArray[Byte],
  picture_offset : Int,
  config : ImageProcessorConfig,
) -> Option[Asset] {
  extract_picture_asset_impl(data_bytes, picture_offset, config, false)
}

///| Extract picture asset with deferred processing (skip base64, use placeholder)
pub fn extract_picture_asset_deferred(
  data_bytes : FixedArray[Byte],
  picture_offset : Int,
) -> Option[Asset] {
  extract_picture_asset_impl(data_bytes, picture_offset, default_image_config(), true)
}

///| Create a minimal placeholder asset without reading CFB streams
///| This is the fastest option for parse time — defers ALL image work to render time
pub fn create_placeholder_asset(picture_offset : Int) -> Asset {
  // Create a valid SVG placeholder with base64 encoding to avoid HTML escaping issues
  let placeholder_svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"200\" height=\"150\" viewBox=\"0 0 200 150\">" +
    "<rect width=\"200\" height=\"150\" fill=\"#f8f9fa\" stroke=\"#dee2e6\" stroke-width=\"1\"/>" +
    "<text x=\"100\" y=\"70\" text-anchor=\"middle\" font-family=\"system-ui\" font-size=\"11\" fill=\"#6c757d\">" +
    "Loading image...</text>" +
    "<text x=\"100\" y=\"90\" text-anchor=\"middle\" font-family=\"system-ui\" font-size=\"10\" fill=\"#adb5bd\">" +
    "offset: \{picture_offset.to_string()}</text>" +
    "</svg>"
  // Use base64 encoding for the SVG to avoid HTML escaping issues
  let svg_bytes = string_to_bytes(placeholder_svg)
  let base64_svg = bytes_to_base64(svg_bytes)
  Asset::{
    id: "asset-img-\{picture_offset.to_string()}",
    asset_type: "image",
    name: "image",
    mime: "image/svg+xml",
    bytes: [],
    data_url: "data:image/svg+xml;base64,\{base64_svg}",
    width: 200,
    height: 150,
  }
}

///| Image extraction context for async processing
///| Holds the raw document data needed to extract images after initial parse
pub struct ImageExtractor {
  data_bytes : FixedArray[Byte]
  config : ImageProcessorConfig
}

///| Create an image extractor from raw document data
pub fn create_image_extractor(data_bytes : FixedArray[Byte]) -> ImageExtractor {
  ImageExtractor::{
    data_bytes,
    config: default_image_config(),
  }
}

///| Create an image extractor with custom config
pub fn create_image_extractor_with_config(data_bytes : FixedArray[Byte], config : ImageProcessorConfig) -> ImageExtractor {
  ImageExtractor::{
    data_bytes,
    config,
  }
}

///| Extract a single image from the document data
///| Returns the processed asset with real data URL, or None if extraction fails
pub fn extract_image(extractor : ImageExtractor, picture_offset : Int) -> Option[Asset] {
  extract_picture_asset_with_config(extractor.data_bytes, picture_offset, extractor.config)
}

///| Internal implementation for picture asset extraction
fn extract_picture_asset_impl(
  data_bytes : FixedArray[Byte],
  picture_offset : Int,
  config : ImageProcessorConfig,
  is_deferred : Bool,
) -> Option[Asset] {
  if picture_offset < 0 || picture_offset + 68 > data_bytes.length() {
    return None
  }
  let reader = BinaryReader::make(data_bytes)
  let lcb = reader.i32(picture_offset)
  let cb_header = reader.u16(picture_offset + 4)
  let total = if lcb > 0 && picture_offset + lcb <= data_bytes.length() {
    lcb
  } else {
    let remaining = data_bytes.length() - picture_offset
    if remaining < 8 * 1024 * 1024 { remaining } else { 8 * 1024 * 1024 }
  }
  let picture_chunk = FixedArray::makei(total, fn(i) { data_bytes[picture_offset + i] })
  let body_start = if cb_header > 0 && cb_header < picture_chunk.length() {
    cb_header
  } else {
    if 68 < picture_chunk.length() { 68 } else { picture_chunk.length() }
  }
  
  // Extract image dimensions from PICMID structure
  let (img_width, img_height) = match extract_pic_dimensions(data_bytes, picture_offset) {
    Some((dxa_goal, dya_goal, mx, my)) => {
      let (w, h) = calculate_display_dimensions(dxa_goal, dya_goal, mx, my)
      (w, h)
    }
    None => (0, 0)
  }
  
  // Scan the entire picture chunk for image format (not just body)
  // This ensures we detect EMF headers even if they're in the header section
  let segment_data = picture_chunk
  match detect_image_segment(segment_data) {
    Some(segment) => {
      // Use the entire picture chunk as image data (don't rely on find_emf_end)
      // This ensures we get the complete image data
      let image_bytes = picture_chunk

      // If deferred, skip processing and use placeholder
      if is_deferred {
        let placeholder = create_loading_placeholder(segment.mime, image_bytes.length())
        return Some(Asset::{
          id: "asset-img",
          asset_type: "image",
          name: "image",
          mime: segment.mime,
          bytes: image_bytes,
          data_url: placeholder,
          width: img_width,
          height: img_height,
        })
      }

      // Process image through image processor
      let process_result = process_image(image_bytes, segment.mime, config)

      if process_result.success {
        // Use processed image
        Some(Asset::{
          id: "asset-img",
          asset_type: "image",
          name: "image",
          mime: process_result.mime,
          bytes: process_result.bytes,
          data_url: data_url_from_bytes(process_result.bytes, process_result.mime),
          width: img_width,
          height: img_height,
        })
      } else if process_result.fallback_url.length() > 0 {
        // Use fallback URL (download placeholder)
        Some(Asset::{
          id: "asset-img",
          asset_type: "image",
          name: "image",
          mime: "image/svg+xml",
          bytes: FixedArray::make(0, 0x0),
          data_url: process_result.fallback_url,
          width: img_width,
          height: img_height,
        })
      } else {
        // Processing failed - generate SVG placeholder for EMF/WMF
        let fallback_url = if segment.mime == "image/emf" || segment.mime == "image/wmf" {
          create_emf_placeholder_url(image_bytes, segment.mime)
        } else {
          create_download_placeholder(image_bytes, segment.mime)
        }
        Some(Asset::{
          id: "asset-img",
          asset_type: "image",
          name: "image",
          mime: "image/svg+xml",
          bytes: FixedArray::make(0, 0x0),
          data_url: fallback_url,
          width: img_width,
          height: img_height,
        })
      }
    }
    None => {
      if is_deferred {
        let placeholder = create_loading_placeholder("application/octet-stream", picture_chunk.length())
        return Some(Asset::{
          id: "asset-img",
          asset_type: "image",
          name: "image",
          mime: "application/octet-stream",
          bytes: picture_chunk,
          data_url: placeholder,
          width: img_width,
          height: img_height,
        })
      }
      Some(Asset::{
        id: "asset-img",
        asset_type: "image",
        name: "image",
        mime: "application/octet-stream",
        bytes: picture_chunk,
        data_url: data_url_from_bytes(picture_chunk, "application/octet-stream"),
        width: img_width,
        height: img_height,
      })
    }
  }
}

///| Extract raw image asset without processing (for deferred processing)
///| Returns asset with raw bytes and detected mime type, but no processed data_url
pub fn extract_raw_image_asset(
  data_bytes : FixedArray[Byte],
  picture_offset : Int,
) -> Option[Asset] {
  if picture_offset < 0 || picture_offset + 68 > data_bytes.length() {
    return None
  }
  let reader = BinaryReader::make(data_bytes)
  let lcb = reader.i32(picture_offset)
  let cb_header = reader.u16(picture_offset + 4)

  // Detect NilPICFAndBinData: cbHeader=0x44 and 62 ignored bytes are all zero
  // Per MS-DOC §2.9.158: cbHeader MUST be 0x44, followed by 62 zero bytes
  if cb_header == 0x44 && picture_offset + 68 <= data_bytes.length() {
    let mut all_zero = true
    for i in 0..<62 {
      if data_bytes[picture_offset + 6 + i] != 0 {
        all_zero = false
        break
      }
    }
    if all_zero {
      // This is NilPICFAndBinData (binary data for hyperlink/form field/addin)
      // Return as attachment with detected MIME type
      let bin_start = picture_offset + 68
      let bin_size = if lcb > 68 && bin_start + (lcb - 68) <= data_bytes.length() {
        lcb - 68
      } else {
        0
      }
      if bin_size > 0 {
        let bin_data = FixedArray::makei(bin_size, fn(i) { data_bytes[bin_start + i] })
        let detected_mime = detect_mime_from_bytes(bin_data)
        return Some(Asset::{
          id: "asset-bin-\{picture_offset.to_string()}",
          asset_type: "attachment",
          name: "binary-data",
          mime: detected_mime,
          bytes: bin_data,
          data_url: data_url_from_bytes(bin_data, detected_mime),
          width: 0,
          height: 0,
        })
      }
      return None
    }
  }

  let total = if lcb > 0 && picture_offset + lcb <= data_bytes.length() {
    lcb
  } else {
    let remaining = data_bytes.length() - picture_offset
    if remaining < 8 * 1024 * 1024 { remaining } else { 8 * 1024 * 1024 }
  }
  let picture_chunk = FixedArray::makei(total, fn(i) { data_bytes[picture_offset + i] })
  let body_start = if cb_header > 0 && cb_header < picture_chunk.length() {
    cb_header
  } else {
    if 68 < picture_chunk.length() { 68 } else { picture_chunk.length() }
  }
  
  // Extract image dimensions from PICMID structure
  let pic_dims = match extract_pic_dimensions(data_bytes, picture_offset) {
    Some((dxa_goal, dya_goal, mx, my)) => {
      calculate_display_dimensions(dxa_goal, dya_goal, mx, my)
    }
    None => (0, 0)
  }
  let mut img_width = pic_dims.0
  let mut img_height = pic_dims.1

  // Fix #3: Scan body only (skip header) — matches JS reference
  let body_data = FixedArray::makei(picture_chunk.length() - body_start, fn(i) { picture_chunk[body_start + i] })

  // If PICMID dimensions not available, try extracting from image bytes
  if img_width == 0 || img_height == 0 {
    let (w, h) = extract_image_dimensions(body_data)
    if w > 0 && h > 0 {
      img_width = w
      img_height = h
    }
  }

  // Check for OLE object header (0x0f 0x00 0x04 0xf0) — text boxes and other OLE objects
  let is_ole = body_data.length() >= 4 && body_data[0] == 0x0f && body_data[1] == 0x00 && body_data[2] == 0x04 && body_data[3] == 0xf0

  if is_ole {
    // OLE object — search for embedded EMF in the body
    let mut emf_start = -1
    for i in 0..<(body_data.length() - 3) {
      if body_data[i] == 0x01 && body_data[i + 1] == 0x00 && body_data[i + 2] == 0x00 && body_data[i + 3] == 0x00 {
        emf_start = i
        break
      }
    }
    if emf_start >= 0 {
      // Found EMF signature — now check for embedded PNG/JPEG in the EMF
      let emf_data = FixedArray::makei(body_data.length() - emf_start, fn(i) { body_data[emf_start + i] })
      let embedded_segment = detect_image_segment(emf_data)
      
      match embedded_segment {
        Some(segment) => {
          // Found embedded PNG/JPEG in EMF — extract just the image
          let start = emf_start + segment.start
          let end = emf_start + segment.end
          let image_bytes = FixedArray::makei(end - start, fn(i) { body_data[start + i] })
          return Some(Asset::{
            id: "asset-img-\{picture_offset.to_string()}",
            asset_type: "image",
            name: "image",
            mime: segment.mime,
            bytes: image_bytes,
            data_url: "",
            width: img_width,
            height: img_height,
          })
        }
        None => {
          // No embedded image — extract EMF record based on nSize field
          let emf_bytes = if emf_start + 8 <= body_data.length() {
            // Read nSize from EMF header (little-endian, at offset 4)
            let n_size = (body_data[emf_start + 4].to_int()) | (body_data[emf_start + 5].to_int() << 8) |
                         (body_data[emf_start + 6].to_int() << 16) | (body_data[emf_start + 7].to_int() << 24)
            // nSize must be valid and divisible by 4
            if n_size > 0 && n_size % 4 == 0 && emf_start + n_size <= body_data.length() {
              FixedArray::makei(n_size, fn(i) { body_data[emf_start + i] })
            } else {
              // Fallback: use all remaining bytes
              FixedArray::makei(body_data.length() - emf_start, fn(i) { body_data[emf_start + i] })
            }
          } else {
            FixedArray::makei(body_data.length() - emf_start, fn(i) { body_data[emf_start + i] })
          }
          return Some(Asset::{
            id: "asset-img-\{picture_offset.to_string()}",
            asset_type: "image",
            name: "image",
            mime: "image/emf",
            bytes: emf_bytes,
            data_url: "",
            width: img_width,
            height: img_height,
          })
        }
      }
    } else {
      return Some(Asset::{
        id: "asset-img-\{picture_offset.to_string()}",
        asset_type: "image",
        name: "image",
        mime: "application/octet-stream",
        bytes: body_data,
        data_url: "",
        width: img_width,
        height: img_height,
      })
    }
  }

  match detect_image_segment(body_data) {
    Some(segment) => {
      // Fix #4: Return only the image segment bytes — matches JS reference
      let start = body_start + segment.start
      let end = if body_start + segment.end < picture_chunk.length() { body_start + segment.end } else { picture_chunk.length() }
      let image_bytes = FixedArray::makei(end - start, fn(i) { picture_chunk[start + i] })
      Some(Asset::{
        id: "asset-img-\{picture_offset.to_string()}",
        asset_type: "image",
        name: "image",
        mime: segment.mime,
        bytes: image_bytes,
        data_url: "",
        width: img_width,
        height: img_height,
      })
    }
    None => {
      // No embedded PNG/JPEG/GIF/BMP found — check if this is a standalone EMF/WMF
      if body_data.length() >= 4 && body_data[0] == 0x01 && body_data[1] == 0x00 && body_data[2] == 0x00 && body_data[3] == 0x00 {
        // Standalone EMF — return body as EMF format
        Some(Asset::{
          id: "asset-img-\{picture_offset.to_string()}",
          asset_type: "image",
          name: "image",
          mime: "image/emf",
          bytes: body_data,
          data_url: "",
          width: img_width,
          height: img_height,
        })
      } else if body_data.length() >= 4 && body_data[0] == 0xD7 && body_data[1] == 0xCD && body_data[2] == 0xC6 && body_data[3] == 0x9A {
        // Standalone WMF — return body as WMF format
        Some(Asset::{
          id: "asset-img-\{picture_offset.to_string()}",
          asset_type: "image",
          name: "image",
          mime: "image/wmf",
          bytes: body_data,
          data_url: "",
          width: img_width,
          height: img_height,
        })
      } else {
        Some(Asset::{
          id: "asset-img-\{picture_offset.to_string()}",
          asset_type: "image",
          name: "image",
          mime: "application/octet-stream",
          bytes: picture_chunk,
          data_url: "",
          width: img_width,
          height: img_height,
        })
      }
    }
  }
}

///| Process a raw image asset (EMF→SVG conversion + base64 encoding)
///| Use this for async image processing after initial parse
pub fn process_raw_image_asset(asset : Asset) -> Asset {
  if asset.bytes.length() == 0 {
    return asset
  }
  // Process image through image processor
  let process_result = process_image(asset.bytes, asset.mime, default_image_config())
  if process_result.success {
    Asset::{
      id: asset.id,
      asset_type: asset.asset_type,
      name: asset.name,
      mime: process_result.mime,
      bytes: process_result.bytes,
      data_url: data_url_from_bytes(process_result.bytes, process_result.mime),
      width: asset.width,
      height: asset.height,
    }
  } else if process_result.fallback_url.length() > 0 {
    Asset::{
      id: asset.id,
      asset_type: asset.asset_type,
      name: asset.name,
      mime: "image/svg+xml",
      bytes: FixedArray::make(0, 0x0),
      data_url: process_result.fallback_url,
      width: asset.width,
      height: asset.height,
    }
  } else {
    // Processing failed - generate SVG placeholder for EMF/WMF
    let fallback_url = if asset.mime == "image/emf" || asset.mime == "image/wmf" {
      create_emf_placeholder_url(asset.bytes, asset.mime)
    } else {
      create_download_placeholder(asset.bytes, asset.mime)
    }
    Asset::{
      id: asset.id,
      asset_type: asset.asset_type,
      name: asset.name,
      mime: "image/svg+xml",
      bytes: FixedArray::make(0, 0x0),
      data_url: fallback_url,
      width: asset.width,
      height: asset.height,
    }
  }
}

///| Process all raw image assets in a parse result
///| Returns new array with processed images
pub fn process_all_raw_images(assets : Array[Asset]) -> Array[Asset] {
  let processed : Array[Asset] = Array::new()
  for asset in assets {
    if asset.data_url.length() == 0 && asset.bytes.length() > 0 {
      // Raw image that needs processing
      processed.push(process_raw_image_asset(asset))
    } else {
      // Already processed or placeholder
      processed.push(asset)
    }
  }
  processed
}

///| Create a loading placeholder SVG for deferred image processing
fn create_loading_placeholder(mime : String, size : Int) -> String {
  let size_kb = size / 1024
  let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"200\" height=\"150\" viewBox=\"0 0 200 150\">" +
    "<rect width=\"200\" height=\"150\" fill=\"#f8f9fa\" stroke=\"#dee2e6\" stroke-width=\"1\"/>" +
    "<text x=\"100\" y=\"70\" text-anchor=\"middle\" font-family=\"system-ui\" font-size=\"11\" fill=\"#6c757d\">" +
    "Loading image...</text>" +
    "<text x=\"100\" y=\"90\" text-anchor=\"middle\" font-family=\"system-ui\" font-size=\"10\" fill=\"#adb5bd\">" +
    "\{mime} (\{size_kb} KB)</text>" +
    "</svg>"
  // Use base64 encoding to avoid HTML escaping issues
  let svg_bytes = string_to_bytes(svg)
  let base64_svg = bytes_to_base64(svg_bytes)
  "data:image/svg+xml;base64,\{base64_svg}"
}

///| Process a single asset image and return the data URL
///| Use this for async image processing after initial parse
pub fn process_asset_image(asset : Asset) -> String {
  if asset.data_url.length() > 0 && !asset.data_url.has_prefix("data:image/svg+xml;base64,") {
    // Already has a real data URL
    return asset.data_url
  }
  if asset.bytes.length() == 0 {
    return asset.data_url
  }
  // Process the image
  let process_result = process_image(asset.bytes, asset.mime, default_image_config())
  if process_result.success {
    data_url_from_bytes(process_result.bytes, process_result.mime)
  } else if process_result.fallback_url.length() > 0 {
    process_result.fallback_url
  } else {
    data_url_from_bytes(asset.bytes, asset.mime)
  }
}

///| Process all deferred images in a parse result
///| Returns an array of (index, data_url) pairs for updating
pub fn process_all_asset_images(assets : Array[Asset]) -> Array[Asset] {
  let processed : Array[Asset] = Array::new()
  for asset in assets {
    let new_url = process_asset_image(asset)
    processed.push(Asset::{
      id: asset.id,
      asset_type: asset.asset_type,
      name: asset.name,
      mime: asset.mime,
      bytes: asset.bytes,
      data_url: new_url,
      width: asset.width,
      height: asset.height,
    })
  }
  processed
}

///| Read a null-terminated C string from bytes (Latin-1/Windows-1252)
fn read_c_string(bytes : FixedArray[Byte], offset : Int) -> (String, Int) {
  let mut end = offset
  while end < bytes.length() && bytes[end] != 0 {
    end += 1
  }
  let reader = BinaryReader::make(bytes)
  let value = reader.latin1(offset, end - offset)
  (value, end + 1)
}

///| Parse OLE10Native compound document
pub fn parse_ole10_native(bytes : FixedArray[Byte]) -> Option[OLE10Info] {
  if bytes.length() < 20 {
    return None
  }
  let variants = [4, 6]
  for start in variants {
    let mut offset = start
    let (label, next1) = read_c_string(bytes, offset)
    offset = next1
    let (original_path, next2) = read_c_string(bytes, offset)
    offset = next2
    let (temp_path, next3) = read_c_string(bytes, offset)
    offset = next3
    if offset + 4 > bytes.length() {
      continue
    }
    let reader = BinaryReader::make(bytes)
    let data_size = reader.u32(offset)
    offset += 4
    if data_size > 0 && offset + data_size <= bytes.length() {
      let data_bytes = FixedArray::makei(data_size, fn(i) { bytes[offset + i] })
      return Some(OLE10Info::{
        label,
        original_path,
        temp_path,
        data_size,
        bytes: data_bytes,
      })
    }
  }
  None
}

///| Parsed HFD (Hyperlink Field Data) result
struct HFDInfo {
  is_new_window : Bool
  has_location : Bool
  has_tooltip : Bool
  url : String
}

///| Parse HFD (Hyperlink Field Data) structure from binData
///| Per MS-DOC §2.9.115: bits(1) + clsid(16) + hyperlink(variable)
///| Simple implementation: scans for printable URL string
pub fn parse_hfd(bytes : FixedArray[Byte]) -> Option[HFDInfo] {
  if bytes.length() < 17 {
    return None
  }
  // bits byte
  let bits = bytes[0].to_int()
  let is_new_window = (bits.land(0x01)) != 0
  let has_location = (bits.land(0x08)) != 0
  let has_tooltip = (bits.land(0x10)) != 0

  // Skip clsid (16 bytes), start scanning from offset 17
  // Hyperlink Object contains URL as a string — scan for printable sequence
  let mut url_start = -1
  let mut url_end = -1
  for i in 17..<bytes.length() {
    let b = bytes[i].to_int()
    // URL typically starts with http/https/ftp or file://
    if url_start < 0 {
      // Look for start of printable ASCII sequence (>= 0x20, < 0x7F)
      if b >= 0x20 && b < 0x7F {
        url_start = i
      }
    } else {
      // End of URL: non-printable or control char
      if b < 0x20 || b >= 0x7F {
        url_end = i
        break
      }
    }
  }
  if url_start >= 0 && url_end > url_start {
    let reader = BinaryReader::make(bytes)
    let url = reader.latin1(url_start, url_end - url_start)
    // Validate it looks like a URL or file path
    if url.length() > 3 {
      return Some(HFDInfo::{
        is_new_window,
        has_location,
        has_tooltip,
        url,
      })
    }
  }
  None
}

///| Parsed FFData (Form Field Data) result
struct FFDataInfo {
  field_type : String  // "text", "checkbox", "dropdown"
  name : String
  default_text : String
  checked : Bool
  selected_index : Int
}

///| Read an Xstz (length-prefixed string with null terminator) from bytes
///| Xstz = 2-byte cch + cch bytes of string data + null terminator
fn read_xstz(bytes : FixedArray[Byte], offset : Int) -> (String, Int) {
  if offset + 2 > bytes.length() {
    return ("", offset)
  }
  let cch = (bytes[offset].to_int()) | (bytes[offset + 1].to_int() << 8)
  let str_start = offset + 2
  let str_end = str_start + cch
  if str_end > bytes.length() {
    return ("", offset)
  }
  let reader = BinaryReader::make(bytes)
  let value = reader.latin1(str_start, cch)
  // Skip null terminator if present
  let next = if str_end < bytes.length() && bytes[str_end] == 0 {
    str_end + 1
  } else {
    str_end
  }
  (value, next)
}

///| Parse FFData (Form Field Data) structure from binData
///| Per MS-DOC §2.9.78: version(4) + bits(2) + cch(2) + hps(2) + xstzName + xstzTextDef + ...
pub fn parse_ffdata(bytes : FixedArray[Byte]) -> Option[FFDataInfo] {
  if bytes.length() < 10 {
    return None
  }
  let reader = BinaryReader::make(bytes)
  // version (4 bytes) — MUST be 0xFFFFFFFF
  let version = reader.u32(0)
  if version != 0xFFFFFFFF {
    return None
  }
  // bits (2 bytes) — FFDataBits
  let bits_val = reader.u16(4)
  let i_type = bits_val.land(0x3)  // bits 0-1: 0=text, 1=checkbox, 2=dropdown
  let i_res = (bits_val.lsr(2)).land(0x1F)  // bits 2-6: current value

  // cch (2 bytes) — max length (for text fields)
  // hps (2 bytes) — checkbox size (for checkbox fields)
  // Skip to xstzName at offset 10
  let (name, next1) = read_xstz(bytes, 10)

  let mut default_text = ""
  let mut checked = false
  let mut selected_index = 0

  if i_type == 0 {
    // Text field — xstzTextDef follows name
    let (text_def, _) = read_xstz(bytes, next1)
    default_text = text_def
  } else if i_type == 1 {
    // Checkbox — wDef (2 bytes) follows name
    checked = i_res == 1
  } else if i_type == 2 {
    // Dropdown — wDef (2 bytes) follows name
    selected_index = i_res
  }

  let field_type = if i_type == 0 { "text" } else if i_type == 1 { "checkbox" } else { "dropdown" }

  Some(FFDataInfo::{
    field_type,
    name,
    default_text,
    checked,
    selected_index,
  })
}

///| Check if a stream name matches a pattern (handles control-char prefixes)
fn stream_name_matches(entry : CFBEntry, pattern : String) -> Bool {
  // Case-insensitive match: compare uppercase versions
  let upper_pattern = pattern.to_upper()
  if entry.name.contains(upper_pattern) {
    return true
  }
  if entry.name.length() > 1 {
    let stripped = entry.name[1 : entry.name.length()].to_owned()
    if stripped.contains(upper_pattern) {
      return true
    }
  }
  false
}

///| Read object storage from CFB container
fn read_object_storage(
  container : CFBContainer,
  entry : CFBEntry,
) -> ObjectStorageInfo {
  let children = cfb_list_children(container, entry)
  let mut attachment : Option[Asset] = None
  let mut object_data : Option[FixedArray[Byte]] = None

  for child in children {
    if child.object_type == 2 || child.object_type == 5 {
      if stream_name_matches(child, "ole10native") {
        match cfb_get_stream_by_id(container, child.id) {
          Some(bytes) => {
            match parse_ole10_native(bytes) {
              Some(native_info) => {
                let detected_mime = detect_mime_from_bytes(native_info.bytes)
                attachment = Some(Asset::{
                  id: "asset-ole",
                  asset_type: "attachment",
                  name: native_info.label,
                  mime: detected_mime,
                  bytes: native_info.bytes,
                  data_url: data_url_from_bytes(native_info.bytes, detected_mime),
                  width: 0,
                  height: 0,
                })
                return ObjectStorageInfo::{
                  attachment,
                  object_data: None,
                }
              }
              None => ignore(bytes)
            }
          }
          None => ignore(child)
        }
      }

      if stream_name_matches(child, "package") || stream_name_matches(child, "contents") || stream_name_matches(child, "content") {
        match cfb_get_stream_by_id(container, child.id) {
          Some(bytes) => {
            if attachment is None {
              // Check for PSD-wrapped EMF: 5-byte PSD header ("8BPS\0") followed by EMF
              let is_psd_emf = bytes.length() >= 9 && bytes[0] == 0x38 && bytes[1] == 0x42 && bytes[2] == 0x50 && bytes[3] == 0x53 && bytes[4] == 0x00 && bytes[5] == 0x01 && bytes[6] == 0x00 && bytes[7] == 0x00 && bytes[8] == 0x00

              // Check for direct EMF: magic bytes 01 00 00 00
              let is_direct_emf = bytes.length() >= 4 && bytes[0] == 0x01 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x00

              if is_psd_emf {
                // PSD-wrapped EMF: skip 5-byte PSD header, extract EMF
                let emf_bytes = FixedArray::makei(bytes.length() - 5, fn(i) { bytes[i + 5] })
                let (w, h) = extract_image_dimensions(emf_bytes)
                attachment = Some(Asset::{
                  id: "asset-cnt-\{entry.name}",
                  asset_type: "image",
                  name: entry.name,
                  mime: "image/emf",
                  bytes: emf_bytes,
                  data_url: "",
                  width: w,
                  height: h,
                })
              } else if is_direct_emf {
                // Direct EMF in CONTENTS stream
                let (w, h) = extract_image_dimensions(bytes)
                attachment = Some(Asset::{
                  id: "asset-cnt-\{entry.name}",
                  asset_type: "image",
                  name: entry.name,
                  mime: "image/emf",
                  bytes: bytes,
                  data_url: "",
                  width: w,
                  height: h,
                })
              } else {
                // Not EMF — detect MIME type from magic bytes
                let detected_mime = detect_mime_from_bytes(bytes)
                attachment = Some(Asset::{
                  id: "asset-pkg-\{entry.name}",
                  asset_type: "attachment",
                  name: "\{entry.name}.bin",
                  mime: detected_mime,
                  bytes: bytes,
                  data_url: data_url_from_bytes(bytes, detected_mime),
                  width: 0,
                  height: 0,
                })
              }
            }
          }
          None => ignore(child)
        }
      }

      if stream_name_matches(child, "objinfo") || stream_name_matches(child, "ObjInfo") {
        object_data = cfb_get_stream_by_id(container, child.id)
      }

      // EPRINT streams contain EMF images from OLE objects (e.g., Visio drawings)
      if stream_name_matches(child, "EPRINT") {
        match cfb_get_stream_by_id(container, child.id) {
          Some(bytes) => {
            if attachment is None {
              // Check if it's an EMF file
              let mime = if bytes.length() >= 4 && bytes[0] == 0x01 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x00 {
                "image/emf"
              } else {
                "application/octet-stream"
              }
              let (w, h) = if mime != "application/octet-stream" {
                extract_image_dimensions(bytes)
              } else {
                (0, 0)
              }
              attachment = Some(Asset::{
                id: "asset-eprint-\{entry.name}",
                asset_type: "image",
                name: entry.name,
                mime,
                bytes,
                data_url: "",
                width: w,
                height: h,
              })
            }
          }
          None => ignore(child)
        }
      }
    }
  }

  ObjectStorageInfo::{
    attachment,
    object_data,
  }
}

///| Extract object pool from CFB container
pub fn extract_object_pool(container : CFBContainer) -> Map[String, Asset] {
  let map = Map([], capacity=16)

  let pool_entry = match cfb_find_entry(container, "ObjectPool") {
    Some(e) => e
    None => return map
  }

  if pool_entry.object_type != 1 {
    return map
  }

  let children = cfb_list_children(container, pool_entry)

  for child in children {
    if child.object_type == 1 {
      let info = read_object_storage(container, child)
      match info.attachment {
        Some(asset) => {
          map.set(child.name, asset)
        }
        None => {
          match info.object_data {
            Some(data) => {
              map.set(child.name, Asset::{
                id: "obj-\{child.name}",
                asset_type: "object",
                name: child.name,
                mime: "application/octet-stream",
                bytes: data,
                data_url: data_url_from_bytes(data, "application/octet-stream"),
                width: 0,
                height: 0,
              })
            }
            None => ignore(child)
          }
        }
      }
    }
  }

  map
}
