///| EMF/WMF Server-side converter configuration

///| Defines configuration for server-side image conversion

///|
/// Target format for conversion
pub enum EmfTargetFormat {
  Svg
  Png
  Jpeg
} derive(Show, Eq)

///|
/// EMF converter configuration
pub struct EmfConverterConfig {
  /// Whether server-side conversion is enabled
  enabled : Bool
  /// Server URL for EMF conversion API
  server_url : String
  /// Target format for conversion
  target_format : EmfTargetFormat
  /// Request timeout in milliseconds
  timeout_ms : Int
  /// Whether to fallback to placeholder on failure
  fallback_to_placeholder : Bool
  /// Whether to cache conversion results
  enable_cache : Bool
  /// Cache expiry time in milliseconds
  cache_expiry_ms : Int
  /// Maximum file size for conversion (bytes)
  max_file_size : Int
}

///|
/// Default configuration (disabled)
pub fn default_emf_converter_config() -> EmfConverterConfig {
  EmfConverterConfig::{
    enabled: false,
    server_url: "",
    target_format: EmfTargetFormat::Svg,
    timeout_ms: 5000,
    fallback_to_placeholder: true,
    enable_cache: true,
    cache_expiry_ms: 24 * 60 * 60 * 1000, // 24 hours
    max_file_size: 10 * 1024 * 1024, // 10MB
  }
}

///|
/// Create configuration with server URL
pub fn create_emf_converter_config(server_url : String) -> EmfConverterConfig {
  EmfConverterConfig::{
    enabled: true,
    server_url,
    target_format: EmfTargetFormat::Svg,
    timeout_ms: 5000,
    fallback_to_placeholder: true,
    enable_cache: true,
    cache_expiry_ms: 24 * 60 * 60 * 1000,
    max_file_size: 10 * 1024 * 1024,
  }
}

///|
/// Validate configuration
pub fn validate_emf_converter_config(
  config : EmfConverterConfig,
) -> Array[String] {
  let errors = Array::new()

  if config.enabled && config.server_url.length() == 0 {
    errors.push("Server URL is required when enabled")
  }

  if config.timeout_ms < 1000 {
    errors.push("Timeout must be at least 1000ms")
  }

  if config.max_file_size < 1024 {
    errors.push("Max file size must be at least 1KB")
  }

  if config.cache_expiry_ms < 0 {
    errors.push("Cache expiry must be non-negative")
  }

  errors
}

///|
/// Check if a MIME type needs server-side conversion
pub fn needs_server_conversion(mime : String) -> Bool {
  match mime {
    "image/emf" | "image/wmf" => true
    _ => false
  }
}

///|
/// Get target format as string
pub fn target_format_to_string(format : EmfTargetFormat) -> String {
  match format {
    EmfTargetFormat::Svg => "svg"
    EmfTargetFormat::Png => "png"
    EmfTargetFormat::Jpeg => "jpeg"
  }
}

///|
/// Parse target format from string
pub fn parse_target_format(s : String) -> EmfTargetFormat? {
  if s == "svg" {
    Some(EmfTargetFormat::Svg)
  } else if s == "png" {
    Some(EmfTargetFormat::Png)
  } else if s == "jpeg" {
    Some(EmfTargetFormat::Jpeg)
  } else {
    None
  }
}
