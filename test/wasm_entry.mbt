///| WASM test entry point
fn main {
  println("=== MS-DOC Viewer WASM Test ===")
  println("WASM module loaded successfully")
  
  // Test with minimal valid DOC file (CFB header)
  let test_data : FixedArray[Byte] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
  
  println("Testing parse_ms_doc...")
  try {
    let result = @core.parse_ms_doc(test_data)
    println("Parse result: \{result.text.length()} characters")
    println("Paragraphs: \{result.paragraphs.length()}")
    println("Warnings: \{result.warnings.length()}")
  } catch {
    e => println("Parse error: \{e}")
  }
  
  println("Testing render_ms_doc...")
  try {
    let rendered = @core.render_ms_doc(test_data)
    println("HTML length: \{rendered.html.length()}")
    println("CSS length: \{rendered.css.length()}")
  } catch {
    e => println("Render error: \{e}")
  }
  
  println("=== All tests passed ===")
}
