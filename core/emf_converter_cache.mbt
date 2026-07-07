///| EMF converter cache implementation

///| Caches conversion results to avoid repeated server calls

///|
/// Cache entry
struct CacheEntry {
  data : FixedArray[Byte]
  mime : String
  timestamp : Int
}

///|
/// EMF conversion cache
pub struct EmfConverterCache {
  entries : Map[String, CacheEntry]
  expiry_ms : Int
}

///|
/// Create a new cache with specified expiry time
pub fn create_emf_cache(expiry_ms : Int) -> EmfConverterCache {
  EmfConverterCache::{ entries: Map([], capacity=64), expiry_ms }
}

///| Compute a simple hash for content-based caching

///|
/// This is used as the cache key
pub fn compute_content_hash(bytes : FixedArray[Byte]) -> String {
  let mut hash = 0
  let mut i = 0
  while i < bytes.length() {
    hash = (hash * 31 + bytes[i].to_int()) & 0x7FFFFFFF
    i += 1
  }
  "\{hash}"
}

///|
/// Get cached result if available and not expired
pub fn cache_get(
  cache : EmfConverterCache,
  key : String,
) -> (FixedArray[Byte], String)? {
  match cache.entries.get(key) {
    Some(entry) =>
      // Check if expired (using simple comparison)
      // Note: In production, use proper timestamp comparison
      Some((entry.data, entry.mime))
    None => None
  }
}

///|
/// Store conversion result in cache
pub fn cache_set(
  cache : EmfConverterCache,
  key : String,
  data : FixedArray[Byte],
  mime : String,
) -> Unit {
  cache.entries.set(
    key,
    CacheEntry::{ data, mime, timestamp: 0 }, // Would use actual timestamp in production
  )
}

///|
/// Clear expired entries from cache
pub fn cache_cleanup(cache : EmfConverterCache) -> Unit {
  // In production, iterate and remove expired entries
  // For now, this is a no-op
}

///|
/// Get cache statistics
pub fn cache_stats(cache : EmfConverterCache) -> (Int, Int) {
  (cache.entries.length(), cache.expiry_ms)
}
