//! Wellen Bridge - Rust-Dart FFI bridge for wellen waveform library
//!
//! This crate provides a Flutter-compatible API to parse and read waveform files
//! (VCD, FST, GHW) using the wellen library.

mod api;
mod frb_generated;

pub use api::*;
