// worker_wrapper.js - Web Worker bridge for MoonBit compiled worker
// Loaded as a Web Worker script; bridges postMessage to MoonBit exports

import {
  worker_parse, worker_render, worker_parse_to_html,
  worker_extract_image, worker_extract_all_images,
  worker_stream_init, worker_stream_chunk, worker_stream_footer,
  worker_stream_get_images_json,
} from '../_build/js/release/build/worker/worker.js';

// Streaming state
let streamTotalBlocks = 0;
let streamChunkSize = 50;

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
        // Format: "{total_blocks}|||CSS|||{css}|||IMAGES|||{images_json}"
        const cssSep = initResult.indexOf('|||CSS|||');
        const imgSep = initResult.indexOf('|||IMAGES|||');
        streamTotalBlocks = parseInt(initResult.substring(0, cssSep), 10);
        const css = initResult.substring(cssSep + 9, imgSep);
        const imagesJson = initResult.substring(imgSep + 11);
        self.postMessage({ id, type, result: { totalBlocks: streamTotalBlocks, css, imagesJson } });

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
      // All body chunks done — get footer
      const footer = worker_stream_footer();
      self.postMessage({ id: initId, type: 'streamChunk', result: { done: true, footer } });
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
    setTimeout(sendNextChunk, 0);
  }

  // Start sending chunks after a brief yield
  setTimeout(sendNextChunk, 0);
}

self.postMessage({ type: 'ready' });
