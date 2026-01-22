# AutoStitch-Keyence (Batch RGB Edition)
Automated batch stitching for Keyence BZ-X800 microscope images.

Adapted from: https://github.com/majanne/AutoStitch-Keyence?

## Features
* **Keyence Composite Batch Mode**: Stitches multiple image folders in one continuous run without restarting the Analyzer software.
* **Streamlined Workflow**: 
    * Automatically unchecks individual channels (CH1, CH2, CH3) and checks "Overlay".
    * Exports only the composite RGB image directly from Keyence Analyzer.
    * Skips legacy post-processing (ImageJ) for maximum speed.
* **Robust UI Automation**: Uses advanced color detection to verify checkbox states.


## Software Requirements
* [AutoHotkey v1.1+](https://www.autohotkey.com/)
* [Keyence BZ-X800 Analyzer](https://www.keyence.com/landing/microscope/lp_fluorescence.jsp) (with Stitching Module)

## Installation
1. Download this script repository to a folder (e.g., `C:\Tools\AutoStitch-Keyence\`).
2. **Configuration**:
   * Open `ahkStitch.ahk` in a text editor.
   * Verify lines 6 and 9 match your installation folder path:
     ```autohotkey
     STITCH_BASE_DIR := "C:\Tools\AutoStitch-Keyence"
     #include C:\Tools\AutoStitch-Keyence
     ```
   * The script is configured for the standard path: `C:\Program Files\Keyence\BZ-X800\Analyzer\BZ-X800_Analyzer.exe`.
   * If your installation is different, edit the path in `ahkStitch.ahk`:
     ```autohotkey
     options["keyenceAnalyzer"] := "C:\Your\Custom\Path\BZ-X800_Analyzer.exe"
     ```
3. Edit `run-instructions\runStitch.ahk`:
   * Update line 3 to point to your `ahkStitch.ahk` location:
     ```autohotkey
     #include C:\Tools\AutoStitch-Keyence\ahkStitch.ahk
     ```

## Usage
1. Copy the file `run-instructions\runStitch.ahk` (or the whole `run-instructions` folder) into the directory containing your image folders.
2. Double-click `runStitch.ahk`.
3. The script will:
   * Launch Keyence Analyzer (if not open).
   * Search for all subfolders containing `.gci` files.
   * Process them sequentially, exporting the stitched overlay to an `output` folder.














