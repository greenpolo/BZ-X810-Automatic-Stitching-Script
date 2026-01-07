;#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
;SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
;SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
global STITCH_BASE_DIR
STITCH_BASE_DIR := "C:\Users\KeyencePC\Downloads\AutoStitch-Keyence-1.0.1"

; Includes cannot contain variables. Using the hardcoded install path here.
#include C:\Users\KeyencePC\Downloads\AutoStitch-Keyence-1.0.1
#include include\utils.ahk
#include include\runStitchingBatch.ahk
#include include\exportTiff.ahk
#include include\saveKtf.ahk


;#include %A_ScriptDir%\include\runMockStitching.ahk
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Default options for the application
;; 
;; These are stored in a dictionary and can be accessed using:
;; options["key"]
;;
getDefaultOptions() {
	global STITCH_BASE_DIR
	options := {}
	options["formats"] := "TIFF, TIFF compressed"
	options["shortName"]   := true
	options["saveIndividualChannels"] := false
	
	; Keys are case insensitive 
	options["keyenceAnalyzer"] := "C:\Program Files\Keyence\BZ-X800\Analyzer\BZ-X800_Analyzer.exe"
	
	options["metaBanner"] := "------- Auto Stitch Information -------"
	
	return %options%
}

stitchFolders(inputDir, outputDir, options) {

	title := "Image Stitcher"
	MsgBox, 0x21, %title%, Launching in %inputDir%.`nPressing ESC stops the script anytime.
	IfMsgBox Cancel
		ExitApp

	; Check binary files exist
	checkBinaries(options, ["keyenceAnalyzer"])

	;@ Creates output directory in userWorkDir
	FileCreateDir %outputDir%
	
	; Collect all folders with GCI files first
	folderList := []
	collectFoldersWithGci(inputDir, "", outputDir, "", options, folderList)
	
	; Process all folders in one batch
	if (folderList.MaxIndex() > 0) {
		runStitchingBatch(folderList, outputDir, options)
	} else {
		MsgBox, 0, %title%, No folders with .gci files found!
	}
	
	MsgBox, 0, %title%, Stitched all folders!
}




checkBinaries(ByRef options, keys) {
	; Check all the binaries defined exist
	For i, key in keys {
		if (not options.hasKey(key)) {
			MsgBox 0x10, Image Stitcher, Program file "%key%" is not defined.
			ExitApp
		}
		file := options[key]
		if (FileExist(file) = "") {
			MsgBox 0x10, Image Stitcher, Program file "%key%" does not exist: %file%
		}
	}
	return
}

; ============================================================================
; Helper function to collect all folders with GCI files for batch processing
; ============================================================================
collectFoldersWithGci(inputDir, prefix, outputDir, tmpDir, options, ByRef folderList, level := 1) {
	if (level > 4) {
		return
	}
	
	Loop, %inputDir%\*, 2
	{
		currentName := A_LoopFileName
		currentWorkDir := A_LoopFileLongPath
		
		if (currentWorkDir = outputDir or currentWorkDir = tmpDir) {
			continue
		}
		
		; Check if this folder has a .gci file
		hasGci := false
		Loop, Files, %currentWorkDir%\*.gci
		{
			hasGci := true
		}
		
		if (hasGci) {
			; Compose the output file name
			outputFileName := formatFileName(prefix, currentName, "__", options["shortName"])
			
			; Add to list
			folderInfo := {}
			folderInfo["path"] := currentWorkDir
			folderInfo["name"] := outputFileName
			folderList.Push(folderInfo)
		}
		
		; Recurse into subfolders
		nextPrefix := formatFileName(prefix, currentName, "__", options["shortName"])
		nextLevel := level + 1
		collectFoldersWithGci(currentWorkDir, nextPrefix, outputDir, tmpDir, options, folderList, nextLevel)
	}
}
