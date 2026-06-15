; ============================================================================
; Setup GUI — choose input/output folders and stitching options up front,
; replacing the old sequence of MsgBox prompts.
;
; Returns true to proceed (and fills options/inputDir/outputDir by reference)
; or false if the user cancels. Last-used values persist to settings.ini in
; the install directory (options["scriptDir"]) between runs.
;
; Callbacks are functions (not labels) to avoid top-level returns that would
; terminate the auto-execute section when this file is #included.
; ============================================================================

showSetupGui(ByRef options, ByRef inputDir, ByRef outputDir) {
	global  ; assume-global — needed for the GUI control variables

	SetupResult := ""
	SetupIniFile := options["scriptDir"] "\settings.ini"

	; ---- Load last-used settings (defaults provided so missing keys are safe) ----
	IniRead, iniInput,    %SetupIniFile%, paths,   input,       %A_Space%
	IniRead, iniOutput,   %SetupIniFile%, paths,   output,      %A_Space%
	IniRead, iniMerge,      %SetupIniFile%, options, imageJMerge, 0
	IniRead, iniPerMouse,   %SetupIniFile%, options, perMouseFolders, 0
	IniRead, iniCh1,  %SetupIniFile%, channels, ch1,     DAPI
	IniRead, iniCh2,  %SetupIniFile%, channels, ch2,     GFP
	IniRead, iniCh3,  %SetupIniFile%, channels, ch3,     RFP
	IniRead, iniCh4,  %SetupIniFile%, channels, ch4,     BF
	IniRead, iniOvly, %SetupIniFile%, channels, overlay, Overlay
	IniRead, iniExpCh1,  %SetupIniFile%, channels, exportCh1,  1
	IniRead, iniExpCh2,  %SetupIniFile%, channels, exportCh2,  1
	IniRead, iniExpCh3,  %SetupIniFile%, channels, exportCh3,  1
	IniRead, iniExpCh4,  %SetupIniFile%, channels, exportCh4,  1
	IniRead, iniExpOvly, %SetupIniFile%, channels, exportOvly, 1
	IniRead, iniAlCh1,   %SetupIniFile%, channels, autoCh1,    0
	IniRead, iniAlCh2,   %SetupIniFile%, channels, autoCh2,    0
	IniRead, iniAlCh3,   %SetupIniFile%, channels, autoCh3,    0
	IniRead, iniAlCh4,   %SetupIniFile%, channels, autoCh4,    0
	IniRead, iniAlOvly,  %SetupIniFile%, channels, autoOvly,   0
	IniRead, iniCompress, %SetupIniFile%, options, compress,    0
	IniRead, iniScale,    %SetupIniFile%, options, insertScale, 0
	IniRead, iniScaleLen, %SetupIniFile%, options, scaleLength, 1000
	IniRead, iniShort,    %SetupIniFile%, options, shortName,   1

	iniInput := Trim(iniInput)
	iniOutput := Trim(iniOutput)
	if (iniInput = "") {
		iniInput := A_WorkingDir
	}
	if (iniOutput = "" and iniInput != "") {
		iniOutput := iniInput "\output"
	}

	; ---- Build GUI ----
	Gui, Setup:Destroy
	Gui, Setup:+AlwaysOnTop -MaximizeBox
	Gui, Setup:Margin, 14, 12
	Gui, Setup:Font, s9

	; Input row
	Gui, Setup:Add, Text, xm w95, Input folder:
	Gui, Setup:Add, Edit, x+5 yp-3 w420 vSetupInputEdit, %iniInput%
	Gui, Setup:Add, Button, x+6 yp-1 w70 gSetupBrowseInput, Browse

	; Output row
	Gui, Setup:Add, Text, xm w95 y+12, Output folder:
	Gui, Setup:Add, Edit, x+5 yp-4 w420 vSetupOutputEdit, %iniOutput%
	Gui, Setup:Add, Button, x+6 yp-1 w70 gSetupBrowseOutput, Browse
	Gui, Setup:Add, Button, xm+100 y+4 w120 gSetupAutoOutput, Auto (input\output)
	cbPerMouse := (iniPerMouse = 1 or iniPerMouse = "true") ? "Checked" : ""
	Gui, Setup:Add, Checkbox, xm y+8 vSetupPerMouseCB %cbPerMouse%, Organize output into per-mouse subfolders (name prefix, e.g. M23_A_01 -> <output>\M23)

	; Channels: pick which to export, which to auto-level, and the filename label
	Gui, Setup:Add, Text, xm y+16, Channels  (Export = include in output;  Auto = apply viewer Auto+Apply before export)
	; Column headers
	Gui, Setup:Add, Text, xm+90 y+6 w55, Export
	Gui, Setup:Add, Text, xm+150 yp w40, Auto
	Gui, Setup:Add, Text, xm+200 yp w90, Label

	expCh1  := (iniExpCh1 = 0 or iniExpCh1 = "false")  ? "" : "Checked"
	expCh2  := (iniExpCh2 = 0 or iniExpCh2 = "false")  ? "" : "Checked"
	expCh3  := (iniExpCh3 = 0 or iniExpCh3 = "false")  ? "" : "Checked"
	expCh4  := (iniExpCh4 = 0 or iniExpCh4 = "false")  ? "" : "Checked"
	expOvly := (iniExpOvly = 0 or iniExpOvly = "false") ? "" : "Checked"
	alCh1  := (iniAlCh1 = 1 or iniAlCh1 = "true")  ? "Checked" : ""
	alCh2  := (iniAlCh2 = 1 or iniAlCh2 = "true")  ? "Checked" : ""
	alCh3  := (iniAlCh3 = 1 or iniAlCh3 = "true")  ? "Checked" : ""
	alCh4  := (iniAlCh4 = 1 or iniAlCh4 = "true")  ? "Checked" : ""
	alOvly := (iniAlOvly = 1 or iniAlOvly = "true") ? "Checked" : ""

	Gui, Setup:Add, Text, xm y+8 w70, CH1
	Gui, Setup:Add, Checkbox, xm+95 yp vSetupExpCh1 %expCh1%
	Gui, Setup:Add, Checkbox, xm+155 yp vSetupAlCh1 %alCh1%
	Gui, Setup:Add, Edit, xm+200 yp-3 w90 vSetupCh1, %iniCh1%
	Gui, Setup:Add, Text, xm y+10 w70, CH2
	Gui, Setup:Add, Checkbox, xm+95 yp vSetupExpCh2 %expCh2%
	Gui, Setup:Add, Checkbox, xm+155 yp vSetupAlCh2 %alCh2%
	Gui, Setup:Add, Edit, xm+200 yp-3 w90 vSetupCh2, %iniCh2%
	Gui, Setup:Add, Text, xm y+10 w70, CH3
	Gui, Setup:Add, Checkbox, xm+95 yp vSetupExpCh3 %expCh3%
	Gui, Setup:Add, Checkbox, xm+155 yp vSetupAlCh3 %alCh3%
	Gui, Setup:Add, Edit, xm+200 yp-3 w90 vSetupCh3, %iniCh3%
	Gui, Setup:Add, Text, xm y+10 w70, CH4
	Gui, Setup:Add, Checkbox, xm+95 yp vSetupExpCh4 %expCh4%
	Gui, Setup:Add, Checkbox, xm+155 yp vSetupAlCh4 %alCh4%
	Gui, Setup:Add, Edit, xm+200 yp-3 w90 vSetupCh4, %iniCh4%
	Gui, Setup:Add, Text, xm y+10 w70, Overlay
	Gui, Setup:Add, Checkbox, xm+95 yp vSetupExpOvly %expOvly%
	Gui, Setup:Add, Checkbox, xm+155 yp vSetupAlOvly %alOvly%
	Gui, Setup:Add, Edit, xm+200 yp-3 w90 vSetupOvly, %iniOvly%

	cbMerge := (iniMerge = 1 or iniMerge = "true") ? "Checked" : ""
	Gui, Setup:Add, Checkbox, xm y+12 vSetupMergeCB %cbMerge%, Also merge selected channels into a composite in ImageJ/Fiji

	; Options
	cbCompress := (iniCompress = 1 or iniCompress = "true") ? "Checked" : ""
	cbScale    := (iniScale = 1 or iniScale = "true") ? "Checked" : ""
	cbShort    := (iniShort = 1 or iniShort = "true") ? "Checked" : ""

	Gui, Setup:Add, Checkbox, xm y+16 vSetupCompressCB %cbCompress%, Compress original folders with 7-Zip after stitching
	Gui, Setup:Add, Checkbox, xm y+8 vSetupScaleCB %cbScale%, Burn in a scale bar
	Gui, Setup:Add, Text, x+14 yp+1 w105, Length (microns):
	Gui, Setup:Add, Edit, x+4 yp-3 w70 vSetupScaleLenEdit, %iniScaleLen%
	Gui, Setup:Add, Checkbox, xm y+8 vSetupShortNameCB %cbShort%, Use short output names (trim to last folder segment)

	; Folder count feedback
	Gui, Setup:Add, Text, xm y+16 w430 vSetupCountText, (scanning input...)
	Gui, Setup:Add, Button, x+10 yp-4 w70 gSetupRescan, Rescan

	; Action buttons
	Gui, Setup:Add, Button, xm y+18 w120 h30 gSetupContinue Default, Continue
	Gui, Setup:Add, Button, x+12 w90 h30 gSetupCancel, Cancel

	Gui, Setup:Show, , AutoStitch - Setup

	; Initial scan
	updateSetupCount()

	; Block until Continue or Cancel
	While (SetupResult = "") {
		Sleep 100
	}

	if (SetupResult = "cancel") {
		Gui, Setup:Destroy
		return false
	}

	; ---- Apply chosen values (globals were populated by Submit in SetupContinue) ----
	inputDir := Trim(SetupInputEdit)
	outputDir := Trim(SetupOutputEdit)
	if (outputDir = "") {
		outputDir := inputDir "\output"
	}

	exportChannels := {}
	exportChannels["dapi"] := SetupExpCh1 ? true : false
	exportChannels["gfp"]  := SetupExpCh2 ? true : false
	exportChannels["rfp"]  := SetupExpCh3 ? true : false
	exportChannels["bf"]   := SetupExpCh4 ? true : false
	exportChannels["ovly"] := SetupExpOvly ? true : false
	options["exportChannels"] := exportChannels
	autoLevelChannels := {}
	autoLevelChannels["dapi"] := SetupAlCh1 ? true : false
	autoLevelChannels["gfp"]  := SetupAlCh2 ? true : false
	autoLevelChannels["rfp"]  := SetupAlCh3 ? true : false
	autoLevelChannels["bf"]   := SetupAlCh4 ? true : false
	autoLevelChannels["ovly"] := SetupAlOvly ? true : false
	options["autoLevelChannels"] := autoLevelChannels
	options["imageJMerge"] := SetupMergeCB ? true : false
	chNames := {}
	chNames["dapi"] := Trim(SetupCh1)
	chNames["gfp"]  := Trim(SetupCh2)
	chNames["rfp"]  := Trim(SetupCh3)
	chNames["bf"]   := Trim(SetupCh4)
	chNames["ovly"] := Trim(SetupOvly)
	options["channelNames"] := chNames
	options["perMouseFolders"] := SetupPerMouseCB ? true : false
	options["compress"]     := SetupCompressCB ? true : false
	options["insertScale"]  := SetupScaleCB ? true : false
	sl := Trim(SetupScaleLenEdit)
	if (sl != "" and (sl + 0) > 0) {
		options["scaleLength"] := sl + 0
	}
	options["shortName"] := SetupShortNameCB ? true : false

	; ---- Persist for next run ----
	IniWrite, %inputDir%,  %SetupIniFile%, paths,   input
	IniWrite, %outputDir%, %SetupIniFile%, paths,   output
	IniWrite, % (options["imageJMerge"] ? 1 : 0), %SetupIniFile%, options, imageJMerge
	IniWrite, % (options["perMouseFolders"] ? 1 : 0), %SetupIniFile%, options, perMouseFolders
	IniWrite, % chNames["dapi"], %SetupIniFile%, channels, ch1
	IniWrite, % chNames["gfp"],  %SetupIniFile%, channels, ch2
	IniWrite, % chNames["rfp"],  %SetupIniFile%, channels, ch3
	IniWrite, % chNames["bf"],   %SetupIniFile%, channels, ch4
	IniWrite, % chNames["ovly"], %SetupIniFile%, channels, overlay
	IniWrite, % (exportChannels["dapi"] ? 1 : 0), %SetupIniFile%, channels, exportCh1
	IniWrite, % (exportChannels["gfp"]  ? 1 : 0), %SetupIniFile%, channels, exportCh2
	IniWrite, % (exportChannels["rfp"]  ? 1 : 0), %SetupIniFile%, channels, exportCh3
	IniWrite, % (exportChannels["bf"]   ? 1 : 0), %SetupIniFile%, channels, exportCh4
	IniWrite, % (exportChannels["ovly"] ? 1 : 0), %SetupIniFile%, channels, exportOvly
	IniWrite, % (autoLevelChannels["dapi"] ? 1 : 0), %SetupIniFile%, channels, autoCh1
	IniWrite, % (autoLevelChannels["gfp"]  ? 1 : 0), %SetupIniFile%, channels, autoCh2
	IniWrite, % (autoLevelChannels["rfp"]  ? 1 : 0), %SetupIniFile%, channels, autoCh3
	IniWrite, % (autoLevelChannels["bf"]   ? 1 : 0), %SetupIniFile%, channels, autoCh4
	IniWrite, % (autoLevelChannels["ovly"] ? 1 : 0), %SetupIniFile%, channels, autoOvly
	IniWrite, % (options["compress"] ? 1 : 0),    %SetupIniFile%, options, compress
	IniWrite, % (options["insertScale"] ? 1 : 0), %SetupIniFile%, options, insertScale
	IniWrite, % options["scaleLength"],           %SetupIniFile%, options, scaleLength
	IniWrite, % (options["shortName"] ? 1 : 0),   %SetupIniFile%, options, shortName

	Gui, Setup:Destroy
	return true
}

; ============================================================================
; Setup GUI callbacks
; ============================================================================

SetupBrowseInput() {
	global
	GuiControlGet, cur, Setup:, SetupInputEdit
	FileSelectFolder, sel, *%cur%, 3, Select the INPUT folder (contains your image subfolders)
	if (sel != "") {
		GuiControl, Setup:, SetupInputEdit, %sel%
		GuiControlGet, outCur, Setup:, SetupOutputEdit
		if (Trim(outCur) = "") {
			GuiControl, Setup:, SetupOutputEdit, %sel%\output
		}
	}
	updateSetupCount()
}

SetupBrowseOutput() {
	global
	GuiControlGet, cur, Setup:, SetupOutputEdit
	FileSelectFolder, sel, *%cur%, 3, Select the OUTPUT folder (where stitched images are written)
	if (sel != "") {
		GuiControl, Setup:, SetupOutputEdit, %sel%
	}
}

SetupAutoOutput() {
	global
	GuiControlGet, inDir, Setup:, SetupInputEdit
	inDir := Trim(inDir)
	if (inDir != "") {
		GuiControl, Setup:, SetupOutputEdit, %inDir%\output
	}
}

SetupRescan() {
	updateSetupCount()
}

SetupContinue() {
	global
	Gui, Setup:Submit, NoHide
	inDir := Trim(SetupInputEdit)
	if (inDir = "" or !InStr(FileExist(inDir), "D")) {
		MsgBox, 0x10, Setup, Input folder does not exist:`n%inDir%`n`nPlease choose a valid input folder.
		return
	}
	SetupResult := "ok"
}

SetupCancel() {
	global SetupResult
	SetupResult := "cancel"
}

SetupGuiClose() {
	global SetupResult
	SetupResult := "cancel"
}

SetupGuiEscape() {
	global SetupResult
	SetupResult := "cancel"
}

; Scan the current input folder and report how many .gci folders were found.
updateSetupCount() {
	global
	GuiControlGet, inDir, Setup:, SetupInputEdit
	inDir := Trim(inDir)
	cnt := 0
	if (inDir != "" and InStr(FileExist(inDir), "D")) {
		scanOpts := {}
		scanOpts["shortName"] := true
		tmpList := []
		collectFoldersWithGci(inDir, "", inDir "\output", inDir "\output\tmpdir", scanOpts, tmpList)
		cnt := tmpList.MaxIndex()
		if (cnt = "") {
			cnt := 0
		}
	}
	if (inDir = "" or !InStr(FileExist(inDir), "D")) {
		GuiControl, Setup:, SetupCountText, Input folder not found - check the path above.
	} else {
		GuiControl, Setup:, SetupCountText, % "Found " cnt " image folder(s) with .gci files in input."
	}
}
