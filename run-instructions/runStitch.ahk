;;; Constant header
#NoEnv
#include C:\Users\KeyencePC\Downloads\AutoStitch-Keyence-1.0.1\ahkStitch.ahk
 

;;; Options
options := getDefaultOptions()
options["insertScale"] := false
options["compress"] := false

;;; Method Selection Dialog
MsgBox, 0x23, Stitching Method, Choose stitching method:`n`n[Yes] = Keyence Composite (RGB in Keyence, skip ImageJ)`n[No] = ImageJ Merge (export all channels, merge in ImageJ)`n[Cancel] = Exit
IfMsgBox Yes
{
	options["saveIndividualChannels"] := false
}
IfMsgBox No
{
	options["saveIndividualChannels"] := true
}
IfMsgBox Cancel
{
	ExitApp
}


;;; Compression Dialog
MsgBox, 0x24, Compression, Compress original folders with 7zip?`n`n[Yes] = Create .zip archives to save space`n[No] = Keep original folders as is
IfMsgBox Yes
{
	options["compress"] := true
}
IfMsgBox No
{
	options["compress"] := false
}


;;; Run where you launched
inputDir := A_WorkingDir
outputDir := A_WorkingDir "\output"
stitchFolders(inputDir, outputDir, options)


;;; Pressing ESC ends the script anytime
ExitApp
return
Esc::ExitApp
return
