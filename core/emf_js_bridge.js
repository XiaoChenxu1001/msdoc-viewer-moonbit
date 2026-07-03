/**
 * EMF Converter JavaScript Bridge
 * 
 * This module provides the JavaScript-side integration for EMF conversion.
 * It's loaded separately from the MoonBit core to keep the core lean.
 * 
 * The bridge:
 * 1. Checks if emftosvg is available
 * 2. Converts EMF/WMF to SVG on demand
 * 3. Returns results to MoonBit via data URL
 */

import { EmfConverter } from './emf_converter_wrapper.js';

// Singleton converter instance
let converter = null;

/**
 * Initialize the EMF converter
 * @param {Object} options - { serverUrl, enableCache }
 */
export function initEmfConverter(options = {}) {
  converter = new EmfConverter(options);
  console.log('[EMF Bridge] Converter initialized');
  return true;
}

/**
 * Convert EMF/WMF bytes to SVG data URL
 * This is called from MoonBit via JavaScript interop
 * 
 * @param {Uint8Array} bytes - EMF/WMF bytes
 * @param {string} mime - 'image/emf' or 'image/wmf'
 * @returns {string} SVG data URL or empty string on failure
 */
export async function convertEmfToDataUrl(bytes, mime) {
  if (!converter) {
    converter = new EmfConverter();
  }

  try {
    const result = await converter.convert(bytes, mime);
    
    // Convert SVG to data URL
    const svgBytes = new TextEncoder().encode(result.svg);
    const base64 = btoa(String.fromCharCode(...svgBytes));
    return `data:image/svg+xml;base64,${base64}`;
  } catch (err) {
    console.warn('[EMF Bridge] Conversion failed:', err.message);
    return '';
  }
}

/**
 * Convert EMF/WMF bytes to SVG string
 * @param {Uint8Array} bytes - EMF/WMF bytes
 * @param {string} mime - 'image/emf' or 'image/wmf'
 * @returns {Object} { svg, width, height, backend }
 */
export async function convertEmfToSvg(bytes, mime) {
  if (!converter) {
    converter = new EmfConverter();
  }

  return await converter.convert(bytes, mime);
}

/**
 * Check if EMF conversion is available
 * @returns {boolean}
 */
export function isEmfConversionAvailable() {
  return true; // Placeholder backend is always available
}

/**
 * Check if emftosvg library is loaded
 * @returns {boolean}
 */
export function isEmfToSvgLoaded() {
  try {
    return typeof EMFConverter !== 'undefined';
  } catch {
    return false;
  }
}

// Export for MoonBit FFI
window.__emf_bridge = {
  init: initEmfConverter,
  convertToDataUrl: convertEmfToDataUrl,
  convertToSvg: convertEmfToSvg,
  isAvailable: isEmfConversionAvailable,
  isLoaded: isEmfToSvgLoaded
};
