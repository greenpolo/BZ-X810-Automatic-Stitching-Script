;;; Constant header
#NoEnv
#include C:\Users\KeyencePC\Projects\BZ-X810-Automatic-Stitching-Script\ahkStitch.ahk


;;; Options (binaries + constants); folders & toggles come from the Setup GUI
options := getDefaultOptions()

;;; Setup GUI: pick input/output folders and stitching options
inputDir := ""
outputDir := ""
if (!showSetupGui(options, inputDir, outputDir)) {
	ExitApp
}

;;; Pre-stitch: collect folders and show naming GUI
previewFolderList := []
tmpDir := outputDir "\tmpdir"
collectFoldersWithGci(inputDir, "", outputDir, tmpDir, options, previewFolderList)
showNamingGui(previewFolderList)

;;; Build a path -> custom-name map (consulted by the skip checks during stitching),
;;; then tally what will run. Only named folders are stitched; among those, any
;;; whose output already exists (manual or prior run) are skipped (resume support).
gCustomNameByPath := {}
namedCount := 0
alreadyStitchedCount := 0
toStitchCount := 0
for idx, fi in previewFolderList {
	gCustomNameByPath[fi["path"]] := fi["customName"]
	if (Trim(fi["customName"]) = "") {
		continue  ; unnamed -> skipped
	}
	namedCount += 1
	resolvedName := resolveOutputName(fi["path"], fi["name"])
	if (outputAlreadyStitched(outputDirForName(outputDir, resolvedName, options), resolvedName)) {
		alreadyStitchedCount += 1
	} else {
		toStitchCount += 1
	}
}
totalFolders := previewFolderList.MaxIndex()
if (totalFolders = "") {
	totalFolders := 0
}
unnamedCount := totalFolders - namedCount

;;; Nothing named -> nothing to do. Tell the user how to queue folders.
if (toStitchCount = 0) {
	MsgBox, 0x30, Nothing to stitch, No folders are queued for stitching.`n`nName the folders you want to stitch in the "Name Your Images" window — unnamed folders are skipped.
	ExitApp
}

;;; Confirm the plan (named/skipped breakdown) before launching Keyence.
confirmMsg := toStitchCount " folder(s) will be stitched."
if (unnamedCount > 0) {
	confirmMsg .= "`n" unnamedCount " unnamed folder(s) will be skipped."
}
if (alreadyStitchedCount > 0) {
	confirmMsg .= "`n" alreadyStitchedCount " already-stitched folder(s) will be skipped."
}
confirmMsg .= "`n`nClick OK to continue or Cancel to abort."
MsgBox, 0x21, Stitch, %confirmMsg%
IfMsgBox Cancel
	ExitApp

;;; Stitch
stitchFolders(inputDir, outputDir, options)

;;; Post-stitch: rename output files to custom names (and route per-mouse)
renameOutputFiles(previewFolderList, outputDir, options)


;;; Pressing ESC ends the script anytime
ExitApp
return
Esc::ExitApp
return
