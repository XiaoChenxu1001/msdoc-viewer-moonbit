/**
 * EMF Converter Wrapper - Decoupled, pluggable design
 * 
 * This module provides a generic interface for EMF/WMF conversion.
 * Actual conversion backends are loaded on demand.
 * 
 * Usage:
 *   import { EmfConverter } from './emf_converter_wrapper.js';
 *   const converter = new EmfConverter();
 *   const svg = await converter.convert(emfBytes, 'image/emf');
 */

/**
 * EMF Converter Interface
 * Supports multiple backends: emftosvg, LibreOffice, server API
 */
export class EmfConverter {
  constructor(options = {}) {
    this.backends = new Map();
    this.defaultBackend = options.defaultBackend || 'emftosvg';
    this.serverUrl = options.serverUrl || null;
    this.enableCache = options.enableCache !== false;
    this.cache = new Map();
    
    // Register built-in backends
    this.registerBackend('emftosvg', this._createEmfToSvgBackend.bind(this));
    this.registerBackend('server', this._createServerBackend.bind(this));
    this.registerBackend('placeholder', this._createPlaceholderBackend.bind(this));
  }

  /**
   * Register a conversion backend
   * @param {string} name - Backend name
   * @param {Function} factory - Factory function that returns converter
   */
  registerBackend(name, factory) {
    this.backends.set(name, factory);
  }

  /**
   * Convert EMF/WMF to SVG
   * @param {Uint8Array} bytes - EMF/WMF bytes
   * @param {string} mime - MIME type (image/emf or image/wmf)
   * @param {Object} options - Conversion options
   * @returns {Promise<{svg: string, width: number, height: number, backend: string}>}
   */
  async convert(bytes, mime, options = {}) {
    // Check cache
    if (this.enableCache) {
      const cacheKey = this._computeCacheKey(bytes);
      const cached = this.cache.get(cacheKey);
      if (cached) {
        return { ...cached, fromCache: true };
      }
    }

    // Try configured backend
    const backendName = options.backend || this.defaultBackend;
    const result = await this._tryBackend(backendName, bytes, mime, options);
    
    if (result) {
      // Cache result
      if (this.enableCache) {
        const cacheKey = this._computeCacheKey(bytes);
        this.cache.set(cacheKey, result);
      }
      return { ...result, fromCache: false };
    }

    // Fallback to placeholder
    return this._createPlaceholderResult(bytes, mime);
  }

  /**
   * Try a specific backend
   */
  async _tryBackend(name, bytes, mime, options) {
    const factory = this.backends.get(name);
    if (!factory) {
      console.warn(`[EmfConverter] Backend '${name}' not registered`);
      return null;
    }

    try {
      const backend = await factory();
      return await backend.convert(bytes, mime, options);
    } catch (err) {
      console.warn(`[EmfConverter] Backend '${name}' failed:`, err.message);
      return null;
    }
  }

  /**
   * Create emftosvg backend (lazy loading)
   */
  async _createEmfToSvgBackend() {
    // Dynamic import - only loaded when needed
    // Support both ESM (browser) and CommonJS (Node.js)
    let EMFConverter;
    if (typeof require !== 'undefined') {
      // Node.js - use require
      const emftosvg = require('emftosvg');
      EMFConverter = emftosvg.EMFConverter;
    } else {
      // Browser - use dynamic import
      const emftosvg = await import('emftosvg');
      EMFConverter = emftosvg.EMFConverter;
    }
    
    const logger = (msg) => {
      // Silent by default
    };
    
    const converter = new EMFConverter(logger);
    
    return {
      async convert(bytes, mime, options) {
        if (mime === 'image/emf') {
          const result = await converter.convertEMFBuffer(bytes);
          if (result.returnValue === 0) {
            return {
              svg: result.svg,
              width: result.width,
              height: result.height,
              backend: 'emftosvg'
            };
          }
        }
        // WMF not supported by this backend
        return null;
      }
    };
  }

  /**
   * Create server backend (calls external API)
   */
  async _createServerBackend() {
    const serverUrl = this.serverUrl;
    if (!serverUrl) {
      throw new Error('Server URL not configured');
    }

    return {
      async convert(bytes, mime, options) {
        const response = await fetch(`${serverUrl}/api/convert/emf`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/octet-stream',
            'X-Target-Format': options?.format || 'svg',
            'Accept': 'application/json'
          },
          body: bytes
        });

        if (response.ok) {
          const data = await response.json();
          return {
            svg: data.svg || data.data,
            width: data.width,
            height: data.height,
            backend: 'server'
          };
        }
        return null;
      }
    };
  }

  /**
   * Create placeholder backend (returns SVG placeholder)
   */
  async _createPlaceholderBackend() {
    return {
      async convert(bytes, mime, options) {
        // Return null to trigger placeholder generation
        return null;
      }
    };
  }

  /**
   * Create placeholder result
   */
  _createPlaceholderResult(bytes, mime) {
    const format = mime === 'image/emf' ? 'EMF' : 'WMF';
    const size = bytes.length > 1024 ? `${(bytes.length / 1024).toFixed(1)}KB` : `${bytes.length}B`;
    
    // Try to extract dimensions from EMF header
    let width = 200, height = 150;
    if (bytes.length >= 40 && bytes[0] === 0x01 && bytes[1] === 0x00) {
      const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      const left = view.getInt32(8, true);
      const top = view.getInt32(12, true);
      const right = view.getInt32(16, true);
      const bottom = view.getInt32(20, true);
      width = Math.abs(right - left) || 200;
      height = Math.abs(bottom - top) || 150;
    }

    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <rect width="${width}" height="${height}" fill="#f6f8fa" stroke="#d0d7de" stroke-width="1" rx="4"/>
  <rect x="${width/2-30}" y="${height/2-35}" width="60" height="50" fill="#e1e4e8" stroke="#d0d7de" stroke-width="1" rx="2"/>
  <path d="M${width/2} ${height/2-20} L${width/2} ${height/2} M${width/2-8} ${height/2-8} L${width/2} ${height/2} L${width/2+8} ${height/2-8}" stroke="#666" stroke-width="2" fill="none"/>
  <text x="${width/2}" y="${height/2+15}" text-anchor="middle" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="11" fill="#24292e">${format}</text>
  <text x="${width/2}" y="${height/2+33}" text-anchor="middle" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="10" fill="#586069">${width}×${height}px · ${size}</text>
</svg>`;

    return {
      svg,
      width,
      height,
      backend: 'placeholder'
    };
  }

  /**
   * Compute cache key from bytes
   */
  _computeCacheKey(bytes) {
    let hash = 0;
    for (let i = 0; i < Math.min(bytes.length, 1024); i++) {
      hash = ((hash << 5) - hash + bytes[i]) | 0;
    }
    return hash.toString(36);
  }

  /**
   * Clear cache
   */
  clearCache() {
    this.cache.clear();
  }

  /**
   * Get cache size
   */
  get cacheSize() {
    return this.cache.size;
  }
}

/**
 * Global converter instance (singleton)
 */
let globalConverter = null;

/**
 * Get or create global converter
 * @param {Object} options - Converter options
 * @returns {EmfConverter}
 */
export function getEmfConverter(options) {
  if (!globalConverter) {
    globalConverter = new EmfConverter(options);
  }
  return globalConverter;
}

/**
 * Quick convert function
 * @param {Uint8Array} bytes - EMF/WMF bytes
 * @param {string} mime - MIME type
 * @returns {Promise<string>} SVG string
 */
export async function convertEmfToSvg(bytes, mime) {
  const converter = getEmfConverter();
  const result = await converter.convert(bytes, mime);
  return result.svg;
}

export default EmfConverter;
