globalThis.fetch = async function() { throw new Error('no fetch in inspection'); };
require('../web/pkg/wellen_bridge.js');
const names = Object.getOwnPropertyNames(globalThis).filter(k => /wellen|rohd|frb|load_waveform|wasm/i.test(k));
console.log('Matched global names:', names);
// Also print keys of wellen_bridge if present
if (globalThis.wellen_bridge) {
  console.log('globalThis.wellen_bridge keys:', Object.keys(globalThis.wellen_bridge));
}
if (globalThis.frbgen_rohd_wellen_wire__crate__api__load_waveform_from_bytes) {
  console.log('Low-level binding exists:', 'frbgen_rohd_wellen_wire__crate__api__load_waveform_from_bytes');
}
