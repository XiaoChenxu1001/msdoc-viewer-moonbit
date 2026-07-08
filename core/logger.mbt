///|
/// Log level enum
pub enum LogLevel {
  Warn
} derive(Compare, Eq)

///|
/// Convert log level to int for comparison
fn log_level_to_int(level : LogLevel) -> Int {
  match level {
    Warn => 3
  }
}

///|
/// Logger struct
pub struct Logger {
  mut level : LogLevel
  tag : String
}

///|
/// Create logger with tag
pub fn Logger::make(tag : String) -> Logger {
  { level: Warn, tag }
}

///|
/// Set log level
pub fn Logger::set_level(self : Logger, level : LogLevel) -> Unit {
  self.level = level
}

///|
/// Check if should log at level
pub fn Logger::should_log(self : Logger, level : LogLevel) -> Bool {
  log_level_to_int(level) >= log_level_to_int(self.level)
}

///|
/// Get noop logger
pub fn noop_logger() -> Logger {
  Logger::make("")
}
