# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AutoStitch-Keyence automates image stitching for Keyence BZ-X800 microscopes using AutoHotkey v1.x. It drives the Keyence Analyzer GUI, exports stitched TIFFs, and optionally post-processes them in Fiji/ImageJ. All GUI automation relies on window class names (`WindowsForms10.*`) and hardcoded pixel coordinates for checkbox detection.

## Running the Script

Copy `run-instructions/runStitch.ahk` to the directory containing image folders, then double-click it. The script processes all subfolders (up to 4 levels deep) that contain `.gci` files and places output in an `output/` subdirectory.

## Two Stitching Modes

A startup dialog in `runStitch.ahk` lets the user choose:

1. **Keyence Composite (RGB)** — `saveIndividualChannels = false`. Uses `runStitchingBatch()` in `include/runStitchingBatch.ahk`. Opens Keyence once, unchecks CH1/CH2/CH3 (overlay only), processes all folders in sequence without restarting the Analyzer. Skips ImageJ entirely. The Analyzer is left open when done.

2. **ImageJ Merge** — `saveIndividualChannels = true`. Uses `runStitching()` in `include/runStitching.ahk` called recursively from `ahkStitch.ahk:stitchFoldersRecursive()`. Exports all individual channels, then runs `imagej/postprocess.py` (Jython) headless in Fiji to extract color planes, build multi-channel hyperstacks, set spatial calibration, and save as multi-page TIFF. Restarts Keyence per folder.

## Architecture

```
run-instructions/runStitch.ahk   ← Entry point: sets options, calls stitchFolders()
  └── ahkStitch.ahk              ← Core orchestrator: includes all modules, defines
      │                              stitchFolders(), stitchFoldersRecursive(),
      │                              collectFoldersWithGci(), getDefaultOptions()
      └── include/                ← One function per file (AHK v1 pattern)
          ├── runStitching.ahk       Per-folder stitching (ImageJ mode)
          ├── runStitchingBatch.ahk  Batch stitching (Keyence RGB mode) + isPixelBlue()
          ├── runPost.ahk            Launches Fiji headless with postprocess.py
          ├── getImageChannels.ahk   Reads channel metadata from "Load a Group" table
          ├── exportTiff.ahk         Drives "Export in original scale" Save As dialog
          ├── confirmStitching.ahk   Closes Image Stitch → Load a Group → Analyzer
          ├── closeImage.ahk         Closes image via File → Close in Analyzer
          ├── utils.ahk              formatFileName(), sendClipboard(), isInList(), etc.
          └── (others)               Scale bar, KTF save, JPEG save, canvas, calibration
imagej/
  ├── postprocess.py              Jython script for Fiji (channel merge + calibration)
  └── postprocess_legacy.py       Older version of the above
```

## Key Configuration (ahkStitch.ahk)

- **Lines 6, 9**: `STITCH_BASE_DIR` and `#include` path — must match the installation directory
- **Lines 65-67**: Paths to external binaries (Keyence Analyzer, Fiji/ImageJ, 7-Zip)
- **Line 3 of runStitch.ahk**: `#include` path to `ahkStitch.ahk` — must also match

All three paths must be updated together when moving the installation.

## External Dependencies

- **AutoHotkey v1.x** (NOT v2 — syntax is incompatible)
- **Keyence BZ-X800 Analyzer** with stitching add-on (requires USB dongle)
- **Fiji/ImageJ** — must have "Run single instance listener" disabled (Edit → Options → Misc) for headless mode to work
- **7-Zip** (`7zG.exe`) — only used when compression is enabled

## Important Constraints

- GUI automation uses hardcoded pixel coordinates for checkbox toggling (CH1: 590,91; CH2: 904,91; CH3: 590,511 in Client coords). These break if the "Load a Group" window layout changes.
- `isPixelBlue()` in `runStitchingBatch.ahk` determines checked/unchecked state by testing if Blue > 128 and Red < 128 (checked = blue ~0x196EBF, unchecked = gray ~0xEAEAEA).
- Channel names are hardcoded: CH1=dapi, CH2=gfp, CH3=rfp, CH4=bf. These map to the microscope's Multi-Color acquisition order.
- Window class names like `WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118` are specific to the Keyence software version. A Keyence update may change them.
- The `#include` directive in AHK v1 does not support variables — paths must be hardcoded strings.
- Multi-Point acquisition (up to 3 slides) uses `#`-delimited naming in the folder name to assign per-slide output names (see `formatFileName()` in `utils.ahk`).
