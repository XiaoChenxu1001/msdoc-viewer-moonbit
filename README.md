# MS-DOC Viewer - MoonBit

High-performance MS-DOC (.doc binary Word) parser and renderer, compiled from MoonBit to JS, WASM, and WASM-GC backends.

## Features

- **Multi-target compilation**: JS (ESM), WASM (linear memory), WASM-GC backends
- **Web Worker support**: Offload parsing to background threads
- **WASM browser support**: Both WASM and WASM-GC run directly in browser
- **Modular architecture**: Core parser and worker packages
- **Rich content parsing**: Text, tables, images (PNG/JPEG/EMF/WMF), headers/footers, textboxes, footnotes/endnotes
- **OLE object extraction**: OLE10Native attachments, EPRINT streams, PSD-wrapped EMF
- **Document metadata**: Summary Information (title, author, subject)
- **Page layout**: Section properties (margins, orientation, columns)

## Multi-Target Build Architecture

One MoonBit source codebase, four build targets:

| Target | Command | Output | Browser | Node.js | WASM Runtime |
|--------|---------|--------|---------|---------|--------------|
| **JS** | `moon build --target js --release` | `core.js` (~375KB) | ✅ ESM | ✅ | — |
| **JS Worker** | `moon build --target js --release worker` | `worker.js` (~380KB) | ✅ Worker | — | — |
| **WASM** | `moon build --target wasm --release` | `core.wasm` (~133KB) | ✅ JS bridge | — | ✅ WASMtime |
| **WASM-GC** | `moon build --target wasm-gc --release` | `core.wasm` (~97KB) | ✅ JS string builtins | — | ✅ moon run |

Build all targets at once:

```bash
.\build.bat
```

### Which Target to Use?

- **Browser (simplest)**: JS target — direct ESM import, no bridge needed
- **Browser (threaded)**: JS Worker — parse in background thread, UI stays responsive
- **Browser (performance)**: WASM — linear memory, near-native computation speed
- **Browser (compact)**: WASM-GC — smallest binary, native JS string interop via `wasm:js-string` builtins

## Usage

### JS Target (Browser / Node.js)

```javascript
import { render_ms_doc } from './_build/js/release/build/core/core.js';

const buffer = await file.arrayBuffer();
const raw = render_ms_doc(new Uint8Array(buffer));
const result = raw._0 || raw; // unwrap raise result

document.getElementById('viewer').innerHTML = `
  <style>${result.css}</style>
  ${result.html}
`;
```

### Web Worker Target

```javascript
// worker_wrapper.js — bridges postMessage to MoonBit exports
import { worker_parse, worker_render, worker_parse_to_html }
  from '../_build/js/release/build/worker/worker.js';

self.onmessage = (e) => {
  const { type, data, id } = e.data;
  let result;
  switch(type) {
    case 'parse': result = worker_parse(data); break;
    case 'render': result = worker_render(data); break;
    case 'parseToHtml': result = worker_parse_to_html(data); break;
  }
  self.postMessage({ id, type, result });
};
self.postMessage({ type: 'ready' });
```

### WASM Target (Browser)

```javascript
const resp = await fetch('./_build/wasm/release/build/core/core.wasm');
const { instance } = await WebAssembly.instantiate(await resp.arrayBuffer());
const { memory, render_ms_doc } = instance.exports;

// Allocate bytes in fresh memory pages (avoids collision with MoonBit heap)
function allocBytes(data) {
  const pageSize = 65536;
  const headerSize = 8;
  const prevPages = memory.grow(Math.ceil((headerSize + data.length) / pageSize));
  const ptr = prevPages * pageSize + headerSize;
  const dv = new DataView(memory.buffer);
  dv.setInt32(ptr - 8, 1, true);           // refcount
  dv.setInt32(ptr - 4, data.length, true);  // length
  new Uint8Array(memory.buffer).set(data, ptr);
  return ptr;
}

// Read MoonBit String from linear memory (UTF-16)
function readString(ptr) {
  if (ptr <= 0) return '';
  const dv = new DataView(memory.buffer);
  const len = dv.getInt32(ptr - 4, true) & 0x0FFFFFFF;
  let str = '';
  for (let i = 0; i < len; i++) {
    str += String.fromCharCode(dv.getUint16(ptr + i * 2, true));
  }
  return str;
}

// Read RenderResult struct { html: String, css: String }
function readRenderResult(structPtr) {
  const dv = new DataView(memory.buffer);
  return {
    html: readString(dv.getInt32(structPtr, true)),
    css: readString(dv.getInt32(structPtr + 4, true)),
  };
}

// Call: returns (tag:i32, ptr:i32) — tag=1 success, tag=0 error
const inputPtr = allocBytes(uint8Array);
const [tag, resultPtr] = render_ms_doc(inputPtr);
if (tag === 1) {
  const result = readRenderResult(resultPtr);
  viewer.innerHTML = `<style>${result.css}</style>${result.html}`;
}
```

### WASM-GC Target (Browser + MoonBit Runtime)

```javascript
const resp = await fetch('./_build/wasm-gc/release/build/core/core.wasm');
const bytes = await resp.arrayBuffer();
const { instance } = await WebAssembly.instantiate(bytes, {}, {
  builtins: ['js-string'],           // wasm:js-string builtins (Chrome 112+)
  importedStringConstants: '_'       // string constant namespace
});

// Binary data passed as hex-encoded strings
const hex = uint8ArrayToHex(docBytes);
const result = instance.exports.render_ms_doc_wasm(hex);
// result is a native JS string: "CSS|||HTML"

const sep = result.indexOf('|||SEPARATOR|||');
const css = result.substring(0, sep);
const html = result.substring(sep + 15);
```

Also works with MoonBit's own runtime:

```bash
moon run --target wasm-gc test
```

## MoonBit WASM Linear Memory ABI

This section documents the calling convention for MoonBit's `wasm` (linear memory) target.

### Object Layout

All MoonBit objects in WASM linear memory follow this pattern:

```
┌─────────────┬─────────────┬──────────────────────────┐
│ refcount(i32)│ header(i32) │      data                │
│  at ptr - 8  │  at ptr - 4 │   starting at ptr         │
└─────────────┴─────────────┴──────────────────────────┘
```

- **refcount** (`ptr - 8`): Reference count (managed by MoonBit runtime)
- **header** (`ptr - 4`): Tag/type info (lower 8 bits) | length (upper 28 bits)
  - For arrays: `length & 0x0FFFFFFF` gives element count
  - For strings: same mask gives UTF-16 code unit count

### FixedArray[Byte] (Bytes)

```
ptr - 8: refcount (i32)
ptr - 4: byte_length (i32)
ptr + 0: raw bytes [byte0, byte1, ...]
```

### String

```
ptr - 8: refcount (i32)
ptr - 4: char_count (i32, number of UTF-16 code units)
ptr + 0: UTF-16LE data [char0_lo, char0_hi, char1_lo, char1_hi, ...]
```

Strings are **UTF-16 encoded** (2 bytes per character).

### Function Return Convention

Functions that can raise return `(tag: i32, result: i32)`:

- **tag = 0**: Error — `result` is an error string pointer
- **tag = 1**: Success — `result` is the return value pointer

### Key Differences Between WASM Targets

| Feature | WASM (linear memory) | WASM-GC |
|---------|---------------------|---------|
| Memory | Exported, JS-managed | Internal GC |
| String encoding | UTF-16 (2 bytes/char) | JS string (externref) |
| Object access | Direct memory read/write | Native JS string interop |
| Browser use | Via JS memory bridge | Via `wasm:js-string` builtins |
| FFI config | `export-memory-name: "memory"` | `use-js-builtin-string: true` |
| Browser compat | All modern | Chrome 112+, Firefox 120+, Safari 16.4+ |

## API Reference

### Core Functions

| Function | Input | Returns | Notes |
|----------|-------|---------|-------|
| `parse_ms_doc(bytes)` | `FixedArray[Byte]` | `MsDocParseResult` | Parses .doc, returns structured data |
| `render_ms_doc(bytes)` | `FixedArray[Byte]` | `RenderResult` | Parses and renders to HTML+CSS |
| `parse_ms_doc_to_html(bytes)` | `FixedArray[Byte]` | `String` | Returns HTML only |

### WASM-GC Bridge Functions

| Function | Input | Returns |
|----------|-------|---------|
| `render_ms_doc_wasm(hex)` | hex-encoded string | `"CSS\|\|\|HTML"` |
| `parse_ms_doc_to_html_wasm(hex)` | hex-encoded string | `"CSS\|\|\|HTML"` |
| `parse_ms_doc_wasm(hex)` | hex-encoded string | text content |

### Worker Functions

| Function | Input | Returns |
|----------|-------|---------|
| `worker_parse(bytes)` | `FixedArray[Byte]` | text string |
| `worker_render(bytes)` | `FixedArray[Byte]` | `"CSS\|\|\|HTML"` |
| `worker_parse_to_html(bytes)` | `FixedArray[Byte]` | `"CSS\|\|\|HTML"` |

## Building from Source

### Prerequisites

- [MoonBit](https://www.moonbitlang.com/) toolchain (tested with moon v0.1.20260608, moonc v0.10.0)

### Build

```powershell
.\build.bat                    # All targets
moon build --target js --release              # JS only
moon build --target js --release worker       # Worker only
moon build --target wasm --release            # WASM only
moon build --target wasm-gc --release         # WASM-GC only
moon test                                     # Run tests
```

### Run Demos

Serve the project root with any HTTP server, then open:

- `demo/index.html` — Landing page
- `demo/js.html` — JS target demo
- `demo/wasm.html` — WASM linear memory demo
- `demo/wasm-gc.html` — WASM-GC demo
- `demo/worker.html` — Web Worker demo

## Project Structure

```
msdoc-viewer-moonbit/
├── core/                    # Core parser + renderer (all targets)
│   ├── cfb.mbt              # CFB/OLE container parser
│   ├── fib.mbt              # File Information Block parser
│   ├── clx.mbt              # CLX / Piece Table parser
│   ├── parser.mbt           # Main MS-DOC parser
│   ├── render.mbt           # HTML/CSS renderer
│   ├── wasm_bridge.mbt      # WASM-GC hex-string bridge (conditional)
│   ├── moon.pkg             # Multi-target exports config
│   └── ...                  # binary, sprm, fkp, fonts, styles, etc.
├── worker/                  # Web Worker entry point
│   ├── worker_entry.mbt     # MoonBit worker logic
│   ├── worker_wrapper.js    # JS→MoonBit ESM bridge
│   └── moon.pkg             # is-main + JS exports
├── test/                    # Tests
│   ├── fixtures/            # Test .doc files (test1~test7.doc)
│   └── ...                  # Unit tests + WASM entry
├── demo/                    # Browser demos
│   ├── index.html           # Landing page
│   ├── js.html              # JS target demo
│   ├── wasm.html            # WASM demo
│   ├── wasm-gc.html         # WASM-GC demo
│   └── worker.html          # Web Worker demo
├── build.bat                # Multi-target build script
└── moon.mod.json            # MoonBit module config
```

## Architecture

The MS-DOC format uses a Compound File Binary (CFB) container with multiple streams:

1. **CFB Parser** — Extracts streams from OLE container
2. **FIB Parser** — Reads File Information Block
3. **CLX Parser** — Recovers text via Piece Table
4. **SPRM Decoder** — Decodes property modifiers
5. **FKP Reader** — Reads format/property key pages
6. **Styles Parser** — Parses style definitions
7. **Properties** — Converts properties to state objects
8. **Main Parser** — Orchestrates the full pipeline
9. **HTML Renderer** — Converts parsed data to HTML+CSS

## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
