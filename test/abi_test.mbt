///| Minimal ABI test for WASM linear memory

///| Test function: returns the length of input bytes
pub fn test_len(input : FixedArray[Byte]) -> Int {
  input.length()
}

///| Test function: echoes first byte
pub fn test_echo(input : FixedArray[Byte]) -> Int {
  if input.length() > 0 {
    input[0].to_int()
  } else {
    -1
  }
}

///| Test function: creates a string from bytes
pub fn test_str(input : FixedArray[Byte]) -> String {
  "hello from wasm"
}

fn main {
  println("ABI test loaded")
}
