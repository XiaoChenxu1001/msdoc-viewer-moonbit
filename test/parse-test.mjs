/**
 * parse-test.mjs — 读取 .doc 文件，输出解析结果 JSON
 * 
 * 用法:
 *   node --experimental-vm-modules test/parse-test.mjs <file1.doc> [file2.doc ...]
 *   node --experimental-vm-modules test/parse-test.mjs test/confidential/fixtures/*.doc
 * 
 * 输出: 每个文件的解析结果 JSON（结构化数据，不含 HTML）
 */

import { readFileSync, readdirSync } from 'fs';
import { join, resolve } from 'path';
import { parse_ms_doc } from '../_build/js/release/build/core/core.js';

function unwrap(val) {
  if (val && typeof val === 'object' && '_0' in val) return val._0;
  return val;
}

function parseFile(filePath) {
  const data = new Uint8Array(readFileSync(filePath));
  const t0 = performance.now();
  const parsed = unwrap(parse_ms_doc(data));
  const elapsed = performance.now() - t0;

  // 提取结构化摘要（不含 raw_data / image_cache 等大字段）
  const summary = {
    file: filePath.split(/[/\\]/).pop(),
    file_size: data.length,
    parse_time_ms: Math.round(elapsed),

    // 文本
    text_length: parsed.text.length,
    text_preview: parsed.text.substring(0, 200),

    // 段落
    paragraph_count: parsed.paragraphs.length,
    paragraphs: parsed.paragraphs.slice(0, 5).map(p => ({
      text: p.text.substring(0, 100),
      style: p.style_name,
      align: p.align,
      runs: p.runs.length,
      indent_first: p.indent_first,
      space_before: p.space_before,
      space_after: p.space_after,
      in_table: p.in_table,
    })),

    // 块
    block_count: parsed.blocks.length,
    block_types: {
      paragraphs: parsed.blocks.filter(b => b.paragraph).length,
      tables: parsed.blocks.filter(b => b.table).length,
      attachments: parsed.blocks.filter(b => b.attachments).length,
    },

    // 表格
    table_summary: parsed.blocks
      .filter(b => b.table)
      .slice(0, 3)
      .map(b => ({
        rows: b.table.rows.length,
        cells: b.table.rows.reduce((sum, r) => sum + r.cells.length, 0),
        depth: b.table.depth,
      })),

    // 资源
    asset_count: parsed.assets.length,
    assets: parsed.assets.slice(0, 5).map(a => ({
      type: a.asset_type,
      name: a.name,
      mime: a.mime,
      bytes_length: a.bytes.length(),
      width: a.width,
      height: a.height,
      has_placeholder: a.data_url.startsWith('data:image/svg'),
    })),

    // 子文档
    textboxes: parsed.textboxes.length,
    headers: parsed.headers.length,
    footers: parsed.footers.length,
    sections: parsed.sections.length,
    footnotes: parsed.footnotes.length,
    endnotes: parsed.endnotes.length,
    comments: parsed.comments.length,
    fonts: parsed.fonts.length,
    styles: parsed.styles.length,

    // 摘要信息
    summary: parsed.summary ? {
      title: parsed.summary.title,
      author: parsed.summary.author,
      subject: parsed.summary.subject,
      creating_app: parsed.summary.creating_app,
    } : null,

    // 警告
    warnings: parsed.warnings,
  };

  return summary;
}

// 收集文件列表
let files = process.argv.slice(2);
if (files.length === 0) {
  // 默认扫描 fixtures 目录
  const fixturesDir = resolve('test/confidential/fixtures');
  try {
    files = readdirSync(fixturesDir)
      .filter(f => f.endsWith('.doc'))
      .map(f => join(fixturesDir, f));
  } catch {
    console.error('用法: node test/parse-test.mjs <file1.doc> [file2.doc ...]');
    console.error('或: 将 .doc 文件放入 test/confidential/fixtures/ 目录');
    process.exit(1);
  }
}

if (files.length === 0) {
  console.error('未找到 .doc 文件。请指定文件路径或将文件放入 test/confidential/fixtures/');
  process.exit(1);
}

console.log(`解析 ${files.length} 个文件...\n`);

const results = [];
for (const file of files) {
  try {
    const result = parseFile(file);
    results.push(result);
    console.log(`✓ ${result.file}: ${result.parse_time_ms}ms, ${result.paragraph_count} 段落, ${result.block_count} 块`);
  } catch (err) {
    console.error(`✗ ${file}: ${err.message}`);
    results.push({ file, error: err.message });
  }
}

// 输出完整 JSON
const outputPath = resolve('test/confidential/fixtures/parse-results.json');
const { writeFileSync, mkdirSync } = await import('fs');
try {
  mkdirSync(resolve('test/confidential/fixtures'), { recursive: true });
} catch {}
writeFileSync(outputPath, JSON.stringify(results, null, 2));
console.log(`\n完整结果已写入: ${outputPath}`);
