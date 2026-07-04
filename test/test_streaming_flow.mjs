///| Unit test for streaming parse + image extraction flow
///| Run: node test/test_streaming_flow.mjs
import { worker_stream_init, worker_stream_chunk, worker_stream_footer,
         worker_stream_get_offsets, worker_stream_release,
         worker_extract_image } from '../_build/js/release/build/worker/worker.js';
import { readFileSync } from 'fs';

const TEST_FILE = 'test/confidential/fixtures/test6.doc';
const data = new Uint8Array(readFileSync(TEST_FILE));

console.log(`=== Streaming Flow Test (${TEST_FILE}, ${data.length} bytes) ===\n`);

// Step 1: parse_init
console.log('--- Step 1: streamInit ---');
const initResult = worker_stream_init(data);
const cssSep = initResult.indexOf('|||CSS|||');
const offSep = initResult.indexOf('|||OFFSETS|||');
const totalBlocks = parseInt(initResult.substring(0, cssSep), 10);
const css = initResult.substring(cssSep + 9, offSep);
const offsetsStr = initResult.substring(offSep + 13);
const offsets = offsetsStr.length > 0 ? offsetsStr.split(',').map(Number) : [];
console.log(`  totalBlocks: ${totalBlocks}`);
console.log(`  css length: ${css.length}`);
console.log(`  offsets string: "${offsetsStr}"`);
console.log(`  parsed offsets: [${offsets.join(', ')}]`);
console.log(`  offsets valid: ${offsets.every(o => !isNaN(o) && o >= 0)}`);

// Step 2: render chunks
console.log('\n--- Step 2: render chunks ---');
const CHUNK_SIZE = 20;
let html = '';
for (let start = 0; start < totalBlocks; start += CHUNK_SIZE) {
  const chunk = worker_stream_chunk(start, Math.min(CHUNK_SIZE, totalBlocks - start));
  html += chunk;
}
console.log(`  total HTML length: ${html.length}`);
console.log(`  has <img tags: ${html.includes('<img')}`);
console.log(`  placeholder images: ${(html.match(/data:image\/svg\+xml/g) || []).length}`);

// Step 3: footer
console.log('\n--- Step 3: footer ---');
const footer = worker_stream_footer();
console.log(`  footer length: ${footer.length}`);

// Step 4: extract images using same offsets
console.log('\n--- Step 4: extractImage ---');
let successCount = 0;
let failCount = 0;
for (let i = 0; i < offsets.length; i++) {
  const offset = offsets[i];
  if (isNaN(offset) || offset < 0) {
    console.log(`  [${i}] offset=${offset} SKIP (invalid)`);
    failCount++;
    continue;
  }
  const result = worker_extract_image(data, offset);
  const isReal = result.startsWith('data:') && !result.includes('svg+xml');
  const isEmpty = result.startsWith('data:application/octet-stream;base64,');
  if (isReal && !isEmpty) {
    console.log(`  [${i}] offset=${offset} OK (${result.length} chars)`);
    successCount++;
  } else {
    console.log(`  [${i}] offset=${offset} FAIL: starts_with="${result.substring(0, 50)}"`);
    failCount++;
  }
}
console.log(`  Results: ${successCount} OK, ${failCount} FAIL`);

// Step 5: release
console.log('\n--- Step 5: release ---');
const releaseResult = worker_stream_release();
console.log(`  release: ${releaseResult}`);

// Step 6: verify extractImage after release still works (it uses its own CFB parse)
console.log('\n--- Step 6: extractImage after release ---');
if (offsets.length > 0 && !isNaN(offsets[0])) {
  const afterRelease = worker_extract_image(data, offsets[0]);
  const afterOk = afterRelease.startsWith('data:') && !afterRelease.includes('svg+xml') && afterRelease.length > 100;
  console.log(`  extractImage after release: ${afterOk ? 'OK' : 'FAIL'} (${afterRelease.length} chars)`);
}

console.log('\n=== Test Complete ===');
const allPassed = totalBlocks > 0 && css.length > 0 && offsets.length > 0 &&
  offsets.every(o => !isNaN(o) && o >= 0) && successCount > 0 && failCount === 0;
console.log(`Overall: ${allPassed ? 'PASS' : 'FAIL'}`);
process.exit(allPassed ? 0 : 1);
