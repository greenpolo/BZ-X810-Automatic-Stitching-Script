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

;;; Stitch
stitchFolders(inputDir, outputDir, options)

;;; Post-stitch: rename output files to custom names
renameOutputFiles(previewFolderList, outputDir)


;;; Pressing ESC ends the script anytime
ExitApp
return
Esc::ExitApp
return
