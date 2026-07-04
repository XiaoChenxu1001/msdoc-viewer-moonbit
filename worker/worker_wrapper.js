// worker_wrapper.js - Web Worker bridge for MoonBit compiled worker
// Loaded as a Web Worker script; bridges postMessage to MoonBit exports

import {
  worker_parse, worker_render, worker_parse_to_html,
  worker_extract_image, worker_extract_all_images,
  worker_stream_init, worker_stream_chunk, worker_stream_footer,
  worker_stream_get_offsets,
} from '../_build/js/release/build/worker/worker.js';

// Streaming state
let streamTotalBlocks = 0;
let streamChunkSize = 50;
let streamPendingResolve = null;

self.onmessage = function(e) {
  const { type, data, id, offset, offsets, start, count, chunkSize } = e.data;

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
        result = worker_extract_all_images(data, JSON.stringify(offsets));
        break;

      // --- Streaming API ---
      case 'streamInit': {
        streamChunkSize = chunkSize || 50;
        const initResult = worker_stream_init(data);
        // initResult format: "{total_blocks}|||CSS|||{css}"
        const parts = initResult.split('|||CSS|||');
        streamTotalBlocks = parseInt(parts[0], 10);
        const css = parts[1] || '';
        self.postMessage({ id, type, result: { totalBlocks: streamTotalBlocks, css } });

        // Auto-stream: send chunks progressively
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
      default:
        self.postMessage({ id, type, error: 'Unknown command: ' + type });
        return;
    }
    // Check if MoonBit returned an error string
    if (typeof result === 'string' && result.startsWith('ERROR:')) {
      self.postMessage({ id, type, error: result.substring(6).trim() });
    } else {
      self.postMessage({ id, type, result });
    }
  } catch (err) {
    self.postMessage({ id, type, error: err.message || String(err) });
  }
};

// Progressive chunk streaming with idle-time yielding
function autoStreamChunks(initId) {
  let currentStart = 0;
  const chunkSize = streamChunkSize;

  function sendNextChunk() {
    if (currentStart >= streamTotalBlocks) {
      // All body chunks done — get offsets before footer releases context
      const offsets = worker_stream_get_offsets();
      const footer = worker_stream_footer();
      self.postMessage({ id: initId, type: 'streamChunk', result: { done: true, footer, offsets } });
      return;
    }

    const end = Math.min(currentStart + chunkSize, streamTotalBlocks);
    const html = worker_stream_chunk(currentStart, end - currentStart);
    currentStart = end;

    self.postMessage({
      id: initId,
      type: 'streamChunk',
      result: { html, current: currentStart, total: streamTotalBlocks }
    });

    // Yield to event loop between chunks for responsiveness
    if (currentStart < streamTotalBlocks) {
      setTimeout(sendNextChunk, 0);
    } else {
      // Final: send footer
      const footer = worker_stream_footer();
      self.postMessage({ id: initId, type: 'streamChunk', result: { done: true, footer } });
    }
  }

  // Start sending chunks after a brief yield
  setTimeout(sendNextChunk, 0);
}

self.postMessage({ type: 'ready' });
