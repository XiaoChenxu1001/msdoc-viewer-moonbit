/**
 * parse-benchmark.mjs — 解析器性能基准测试
 * 
 * 用法:
 *   node test/parse-benchmark.mjs <file.doc>
 * 
 * 输出: 解析各阶段耗时、文本长度、段落数等指标
 */

import { readFileSync } from 'fs';
import { parse_ms_doc, render_ms_doc } from '../_build/js/release/build/core/core.js';

function unwrap(val) {
  if (val && typeof val === 'object' && '_0' in val) return val._0;
  return val;
}

const filePath = process.argv[2];
if (!filePath) {
  console.error('用法: node test/parse-benchmark.mjs <file.doc>');
  process.exit(1);
}

const data = new Uint8Array(readFileSync(filePath));
console.log(`文件: ${filePath}`);
console.log(`大小: ${(data.length / 1024).toFixed(1)} KB`);
console.log('');

// Warmup
unwrap(parse_ms_doc(data));

// Benchmark: parse only
const parseTimes = [];
for (let i = 0; i < 5; i++) {
  const t0 = performance.now();
  const parsed = unwrap(parse_ms_doc(data));
  const elapsed = performance.now() - t0;
  parseTimes.push(elapsed);
}

// Benchmark: render (includes parse)
const renderTimes = [];
let lastRendered = null;
for (let i = 0; i < 5; i++) {
  const t0 = performance.now();
  const rendered = unwrap(render_ms_doc(data));
  const elapsed = performance.now() - t0;
  renderTimes.push(elapsed);
  lastRendered = rendered;
}

// Get final parse result for stats
const parsed = unwrap(parse_ms_doc(data));

// Statistics
const avg = arr => arr.reduce((a, b) => a + b, 0) / arr.length;
const min = arr => Math.min(...arr);
const max = arr => Math.max(...arr);

console.log('=== 性能基准 ===');
console.log(`解析 (parse_ms_doc):`);
console.log(`  平均: ${avg(parseTimes).toFixed(1)} ms`);
console.log(`  最小: ${min(parseTimes).toFixed(1)} ms`);
console.log(`  最大: ${max(parseTimes).toFixed(1)} ms`);
console.log('');
console.log(`渲染 (render_ms_doc):`);
console.log(`  平均: ${avg(renderTimes).toFixed(1)} ms`);
console.log(`  最小: ${min(renderTimes).toFixed(1)} ms`);
console.log(`  最大: ${max(renderTimes).toFixed(1)} ms`);
console.log('');

console.log('=== 解析结果统计 ===');
console.log(`文本长度: ${parsed.text.length.toLocaleString()} 字符`);
console.log(`段落数: ${parsed.paragraphs.length}`);
console.log(`块数: ${parsed.blocks.length}`);
console.log(`  - 段落块: ${parsed.blocks.filter(b => b.paragraph).length}`);
console.log(`  - 表格块: ${parsed.blocks.filter(b => b.table).length}`);
console.log(`  - 附件块: ${parsed.blocks.filter(b => b.attachments).length}`);
console.log(`资产数: ${parsed.assets.length}`);
console.log(`文本框: ${parsed.textboxes.length}`);
console.log(`页眉: ${parsed.headers.length}`);
console.log(`页脚: ${parsed.footers.length}`);
console.log(`脚注: ${parsed.footnotes.length}`);
console.log(`尾注: ${parsed.endnotes.length}`);
console.log(`批注: ${parsed.comments.length}`);
console.log(`节数: ${parsed.sections.length}`);
console.log(`字体: ${parsed.fonts.length}`);
console.log(`样式: ${parsed.styles.length}`);
console.log('');

// Run count per paragraph
const totalRuns = parsed.paragraphs.reduce((sum, p) => sum + p.runs.length, 0);
console.log(`总 Run 数: ${totalRuns.toLocaleString()}`);
console.log(`平均每段 Run 数: ${(totalRuns / Math.max(parsed.paragraphs.length, 1)).toFixed(1)}`);

// HTML output size
if (lastRendered) {
  console.log('');
  console.log('=== HTML 输出大小 ===');
  console.log(`HTML: ${(lastRendered.html.length / 1024).toFixed(1)} KB (${lastRendered.html.length.toLocaleString()} chars)`);
  console.log(`CSS: ${(lastRendered.css.length / 1024).toFixed(1)} KB (${lastRendered.css.length.toLocaleString()} chars)`);
  console.log(`总计: ${((lastRendered.html.length + lastRendered.css.length) / 1024).toFixed(1)} KB`);
}
