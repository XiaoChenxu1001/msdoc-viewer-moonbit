// worker_wrapper.js - Web Worker bridge for MoonBit compiled worker

import {
  worker_parse, worker_render, worker_parse_to_html,
  worker_extract_image, worker_extract_all_images,
  worker_stream_init, worker_stream_chunk, worker_stream_footer,
  worker_stream_get_offsets, worker_stream_release,
} from '../_build/js/release/build/worker/worker.js';

let streamTotalBlocks = 0;
let streamChunkSize = 50;

self.onmessage = function(e) {
  const { type, data, id, offset, start, count, chunkSize } = e.data;

  try {
    let result;
    switch (type) {
      case 'parse':
        result = worker_parse(data);
        break;
      case 'render':
        result = worker_render(data);
        break;
      case 'parseToHtml':
        result = worker_parse_to_html(data);
        break;
      case 'extractImage':
        result = worker_extract_image(data, offset);
        break;
      case 'extractAllImages':
        result = worker_extract_all_images(data, JSON.stringify(offset));
        break;
      case 'streamInit': {
        streamChunkSize = chunkSize || 50;
        const initResult = worker_stream_init(data);
        // Format: "{total}|||CSS|||{css}|||OFFSETS|||{offsets}"
        const cssSep = initResult.indexOf('|||CSS|||');
        const offSep = initResult.indexOf('|||OFFSETS|||');
        streamTotalBlocks = parseInt(initResult.substring(0, cssSep), 10);
        const css = initResult.substring(cssSep + 9, offSep);
        const offsets = initResult.substring(offSep + 13);
        self.postMessage({ id, type, result: { totalBlocks: streamTotalBlocks, css, offsets } });
        autoStreamChunks(id);
        return;
      }
      case 'streamChunk': {
        result = worker_stream_chunk(start || 0, count || streamChunkSize);
        break;
      }
      case 'streamFooter': {
        result = worker_stream_footer();
        break;
      }
      case 'streamGetOffsets': {
        result = worker_stream_get_offsets();
        break;
      }
      case 'streamRelease': {
        result = worker_stream_release();
        break;
      }
      default:
        self.postMessage({ id, type, error: 'Unknown command: ' + type });
        return;
    }
    if (typeof result === 'string' && result.startsWith('ERROR:')) {
      self.postMessage({ id, type, error: result.substring(6).trim() });
    } else {
      self.postMessage({ id, type, result });
    }
  } catch (err) {
    self.postMessage({ id, type, error: err.message || String(err) });
  }
};

function autoStreamChunks(initId) {
  let currentStart = 0;
  function sendNextChunk() {
    if (currentStart >= streamTotalBlocks) {
      const footer = worker_stream_footer();
      self.postMessage({ id: initId, type: 'streamChunk', result: { done: true, footer } });
      return;
    }
    const end = Math.min(currentStart + streamChunkSize, streamTotalBlocks);
    const html = worker_stream_chunk(currentStart, end - currentStart);
    currentStart = end;
    self.postMessage({ id: initId, type: 'streamChunk', result: { html, current: currentStart, total: streamTotalBlocks } });
    setTimeout(sendNextChunk, 0);
  }
  setTimeout(sendNextChunk, 0);
}

self.postMessage({ type: 'ready' });
