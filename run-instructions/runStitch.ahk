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

;;; Resume support: detect folders whose output already exists (manual or prior run).
;;; Build a path -> custom-name map (consulted by the skip checks during stitching),
;;; then count how many will be skipped and confirm with the user.
gCustomNameByPath := {}
alreadyStitchedCount := 0
for idx, fi in previewFolderList {
	gCustomNameByPath[fi["path"]] := fi["customName"]
	resolvedName := resolveOutputName(fi["path"], fi["name"])
	if (outputAlreadyStitched(outputDirForName(outputDir, resolvedName, options), resolvedName)) {
		alreadyStitchedCount += 1
	}
}
totalFolders := previewFolderList.MaxIndex()
if (totalFolders = "") {
	totalFolders := 0
}
if (alreadyStitchedCount > 0) {
	remainingFolders := totalFolders - alreadyStitchedCount
	MsgBox, 0x21, Resume, %alreadyStitchedCount% of %totalFolders% folder(s) already have output and will be skipped.`n%remainingFolders% folder(s) will be stitched.`n`nClick OK to continue or Cancel to abort.
	IfMsgBox Cancel
		ExitApp
}

;;; Stitch
stitchFolders(inputDir, outputDir, options)

;;; Post-stitch: rename output files to custom names (and route per-mouse)
renameOutputFiles(previewFolderList, outputDir, options)


;;; Pressing ESC ends the script anytime
ExitApp
return
Esc::ExitApp
return
