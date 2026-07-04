import { worker_stream_init } from '../_build/js/release/build/worker/worker.js';
import { readFileSync } from 'fs';

const data = new Uint8Array(readFileSync('test/confidential/fixtures/test1.doc'));
const result = worker_stream_init(data);

const imgSep = result.indexOf('|||IMAGES|||');
const imgs = result.substring(imgSep + 13);

console.log('imgs length:', imgs.length);

// Check for issues
let nonAscii = [];
for (let i = 0; i < imgs.length; i++) {
  const c = imgs.charCodeAt(i);
  if (c > 127 || (c < 32 && c !== 10 && c !== 13)) {
    nonAscii.push({ pos: i, code: c });
  }
}
console.log('Non-ASCII/control chars:', nonAscii.length);
if (nonAscii.length > 0) console.log('First few:', nonAscii.slice(0, 10));

// Try JSON parse
try {
  const arr = JSON.parse(imgs);
  console.log('JSON parse OK, array length:', arr.length);
  arr.forEach((img, i) => {
    console.log(`  [${i}] index=${img.index}, url_len=${img.data_url.length}, prefix=${img.data_url.substring(0, 30)}`);
  });
} catch (e) {
  console.log('JSON parse FAILED:', e.message);
  // Show what's around the error
  const pos = parseInt(e.message.match(/position (\d+)/)?.[1] || '0');
  console.log('Around error pos:', JSON.stringify(imgs.substring(Math.max(0, pos - 20), pos + 20)));
}
