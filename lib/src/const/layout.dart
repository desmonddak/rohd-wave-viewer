// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause

/// Layout-related constants used across the app.
const double waveformLeftOffset =
    12.0; // pixels; tweak this to shift timescale/waveforms/marker

/// Standard height for a single signal row (waveform row, selection row, value row)
const double signalRowHeight = 40.0;

/// Height for the signal tab container (header for a row)
// Keep the tab/container height consistent with the waveform row height so
// selection/value rows align with waveform rows. If a different visual
// density is desired, change `signalRowHeight` instead.
const double signalTabContainerHeight = signalRowHeight;
