// worker_wrapper.js - Web Worker bridge for MoonBit compiled worker
// Loaded as a Web Worker script; bridges postMessage to MoonBit exports

import { worker_parse, worker_render, worker_parse_to_html, worker_extract_image, worker_extract_all_images } from '../_build/js/release/build/worker/worker.js';

self.onmessage = function(e) {
  const { type, data, id, offset, offsets } = e.data;

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

self.postMessage({ type: 'ready' });
