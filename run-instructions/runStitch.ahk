;;; Constant header
#NoEnv
#include C:\Users\KeyencePC\Downloads\AutoStitch-Keyence-1.0.1\ahkStitch.ahk
 

;;; Options
options := getDefaultOptions()

; Mode: Keyence Composite (Batch)
options["saveIndividualChannels"] := false
options["compress"] := false
options["shortName"] := true

;;; Run where you launched
inputDir := A_WorkingDir
outputDir := A_WorkingDir "\output"
stitchFolders(inputDir, outputDir, options)


;;; Pressing ESC ends the script anytime
ExitApp
return
Esc::ExitApp
return
