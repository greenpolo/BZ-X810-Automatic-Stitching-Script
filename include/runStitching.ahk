
runStitching(inputDirPath, currentName, outputDirPath, options, imageInfo) {

	; Reset all image info fields
	imageInfo["date"] := "NA"
	imageInfo["objective lens in use"] := "NA"
	imageInfo["exposure time"] := "NA"

	; Keystroke settings
	SetKeyDelay, 20, 1

	; Only run on directories with a .gci file
	hasGci := false
	Loop, Files, %inputDirPath%\*.gci
	{
		hasGci := true
	}
	if (not hasGci) {
		return false
	}

	; Verify Keyence is not already running
	if (WinExist("BZ-X800 Analyzer")) {
		MsgBox 0x10, Image Stitcher, "Keyence Analyzer is already running. Close all windows before launching script"
		ExitApp
	}	

	; Start Keyence
	Run % options["keyenceAnalyzer"], , Max
	WinWaitActive, BZ-X800 Analyzer, ,30000
	sleep 1000
	analyzerWinId := WinExist("A")
	
    ;Click Load a Group button:
	ControlFocus, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer
	ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer, , LEFT, , , , NA 

;--------------------------------------------------------------------------------------
;@ Window: Load a Group.
	WinWaitActive, Load a Group., , 6,
	if (ErrorLevel) {
		MsgBox, Timed out waiting for "Load a Group" window. Exiting ...
		ExitApp
	}
	
	; Enter the path to the input file
	ControlFocus, Edit1, Load a Group.  ; Select address bar
	Sleep 250
	ControlSetText, Edit1, %inputDirPath%, Load a Group.,
	Sleep 250
	Send {Enter}                        ; Enter will load the preview
	Sleep 3000                          ; Wait
	if (WinExist("Loading")) {
		WinWaitClose, Loading
	}
	WinWaitActive, Load a Group., , 3000     ; Wait
	WinActivate, Load a Group.
	
	;Get all the image channels detected in the acquisition (overlay first).
	; getImageChannels also adds "ovly" when multi-channel and toggles the overlay box.
	detectedAll := getImageChannels(imageInfo)

	; The individual channels actually present (exclude the overlay pseudo-channel)
	detectedChannels := []
	for i, ch in detectedAll {
		if (ch != "ovly") {
			detectedChannels.Push(ch)
		}
	}

	; Filter to the channels the user selected to export (Setup GUI).
	; Order is preserved (overlay first), matching the viewer window order.
	exportSel := options["exportChannels"]
	allChannels := []
	for i, channel in detectedAll {
		want := true
		if (IsObject(exportSel) and exportSel.HasKey(channel)) {
			want := (exportSel[channel] = true or exportSel[channel] = 1)
		}
		if (want) {
			allChannels.Push(channel)
		}
	}
	; Safety: never produce nothing — fall back to everything detected
	if (allChannels.MaxIndex() = "" or allChannels.MaxIndex() = 0) {
		allChannels := detectedAll
	}

	; Set the Load-a-Group channel checkboxes to match the export selection.
	CoordMode, Mouse, Client
	CoordMode, Pixel, Client
	; Stabilize window before pixel sampling (getImageChannels did heavy input)
	WinActivate, Load a Group.
	Sleep 500
	Click, 300, 10  ; Click neutral area to clear any hover effects
	Sleep 500

	channelToCoord := {}
	channelToCoord["dapi"] := [590, 91]   ; CH1
	channelToCoord["gfp"]  := [904, 91]   ; CH2
	channelToCoord["rfp"]  := [590, 511]  ; CH3
	channelToCoord["bf"]   := [904, 513]  ; CH4 (if it exists)

	; Toggle each present channel's box: checked iff it is in the export list.
	For chName, coords in channelToCoord {
		if (not isInList(chName, detectedChannels)) {
			continue  ; channel not in this acquisition; leave its box alone
		}
		wantChecked := isInList(chName, allChannels)
		x := coords[1]
		y := coords[2]
		PixelGetColor, checkColor, %x%, %y%, RGB
		isChecked := isPixelBlue(checkColor)  ; Blue = CHECKED, Gray = UNCHECKED
		if (wantChecked and !isChecked) {
			Click, %x%, %y%
			Sleep 1000
		} else if (!wantChecked and isChecked) {
			Click, %x%, %y%
			Sleep 1000
		}
	}

	; Overlay checkbox (Load a Group, 1150,47): match the overlay selection.
	; getImageChannels may have checked it already; override to the user's choice.
	wantOvly := isInList("ovly", allChannels)
	PixelGetColor, ovlyColor, 1150, 47, RGB
	ovlyChecked := isPixelBlue(ovlyColor)
	if (wantOvly and !ovlyChecked) {
		Click, 1150, 47
		Sleep 2500
	} else if (!wantOvly and ovlyChecked) {
		Click, 1150, 47
		Sleep 2500
	}
	
    ;Open the "Image stitch" window and launch the layout procedure:
	ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, Load a Group., , LEFT, , , , NA 
	
;--------------------------------------------------------------------------------------	
;@ Window: Image stitch
	WinWaitActive, Image Stitch, , 500, , 
	
	; This block waits until the image is loaded
	; The loading will go back and forth between active windows. We check the loading
	; is complete by verifying the top window remains active for a few seconds.
	isLoading := True
	maxWait := 900  ; In seconds (900 = 15 minutes)
	while (isLoading and maxWait > 0) {
		samples := 4
		isLoading := False
		i = 0
		while (i < samples) {
			progressWinId := "ahk_class WindowsForms10.Window.208.app.0.1ca0192_r6_ad1"
			if (WinExist(progressWinId)) {
				isLoading := True
				WinWaitClose %progressWinId%
				Break
			}
			i := i + 1
			sleep 1000
		}
		maxWait := (maxWait - samples*1)
	}
	if (maxWait == 0) {
		MsgBox Exiting app: timed out loading %inputDirPath%
		ExitApp
	} else {
		;;; MsgBox Completed Loading
	}
	
	;Select uncompressed:
	Control, Check, , WindowsForms10.BUTTON.app.0.1ca0192_r6_ad11, Image Stitch
	Sleep 1000 
	
	;Left click on Start Stitching:
	ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad16, Image Stitch, , LEFT, , , , NA 
	
	; This block waits until the image is loaded
	; The loading will go back and forth between active windows.
	; The top window will be different at each time one channel completes
	; We verify all channels are done by checking the is no progress window
	isLoading := True
	maxWait := 900  ; In seconds (900 = 15 minutes)
	while (isLoading and maxWait > 0) {
		samples := 8
		isLoading := False
		i = 0
		while (i < samples) {
			progressWinId := "ahk_class WindowsForms10.Window.208.app.0.1ca0192_r6_ad1"
			if (WinExist(progressWinId)) {
				isLoading := True
				WinWaitClose %progressWinId%
				Break
			}
			i := i + 1
			sleep 1000
		}
		maxWait := (maxWait - samples*1)
	}
	if (maxWait == 0) {
		MsgBox Exiting app: timed out loading %inputDirPath%
		ExitApp
	} else {
		;;; MsgBox Completed Stitching
	}
	
;--------------------------------------------------------------------------------------
;@ Window: BZ-X800 Wide Image Viewer
	userFormats := StrSplit(options["formats"], ",", " ")

	for i, channel in allChannels {
		chLabel := channelLabel(channel, options)
		; Save BifTiff ?
		sleep 2000
		
		; Robust wait for Image Viewer
		foundViewer := false
		loopCount := 0
		maxLoops := 60 ; 30 seconds (500ms * 60)
		
		While (loopCount < maxLoops) {
			WinGetTitle, currentTitle, A
			currentWin := WinExist("A")
			
			if (currentTitle = "Overview Window") {
				WinClose, A
				WinWaitClose, ahk_id %currentWin%, , 20
				sleep 1000
				continue
			}
			
			if (RegexMatch(currentTitle, "BZ-X800 Wide Image Viewer .*ktf.*")) {
				foundViewer := true
				Break
			}
			
			; If "Save As" or other dialogs are stuck, maybe we should warn? 
			; For now, just wait.
			Sleep 500
			loopCount := loopCount + 1
		}
		
		if (!foundViewer) {
			WinGetTitle, currentTitle, A
			MsgBox Lost track of the image window`nCurrent window title is: %currentTitle%`nID: %currentWin%`n Exiting now.
			ExitApp
		}
		; MsgBox Processing channel %channel%, window %currentWin%
		; Optional: auto-level this channel in the viewer before exporting
		if (channelAutoLevel(channel, options)) {
			autoLevelCorrection(currentWin)
		}
		if (isInList("BigTIFF", userFormats)) {
			exportBigTiff(outputDirPath, currentName, chLabel)
		}
		WinWaitActive, ahk_id %currentWin% , , 20
		; Save Tiff ?
		if (isInList("TIFF", userFormats)) {
			exportTiff(outputDirPath, currentName, chLabel)
		}
		WinWaitActive, ahk_id %currentWin% , , 20
		; Save KTF ?
		if (isInList("Ktf", userFormats)) {
			saveKtf(outputDirPath, currentName, chLabel)
		} else {
			doNotSaveKtf()
		}
		WinWaitClose, ahk_id %currentWin%, , 240
		if (ErrorLevel) {
			MsgBox, Timed out waiting for channel %channel% window to close. Window [%currentWin%], title [%currentTitle%]
			ExitApp
		}
	}

;--------------------------------------------------------------------------------------
;@ Window: Image Stitch   
	confirmStitching(analyzerWinId)			

;--------------------------------------------------------------------------------------	
;@ Window: BZ-X800 Analyzer
	WinWaitActive, ahk_id %analyzerWinId%, , 30
	if (ErrorLevel) {
		MsgBox, Timed out waiting after confirming stitching. Exiting ...
		ExitApp
	}
	
	hasSizeInfo := False
	scaleBar := options["insertScale"]
	; Image size / calibration is only needed for a scale bar or the ImageJ merge.
	; Skip it otherwise so plain channel export doesn't do pointless Analyzer work.
	needMeta := (scaleBar = "yes" or scaleBar = true or options["imageJMerge"] = true)
	for i, channel in allChannels {
		chLabel := channelLabel(channel, options)
		; For the first image, get the size (only when something needs it)
		if (needMeta and hasSizeInfo = False) {
			imageWH := getImageSize()
			imageW := imageWH[1]
			imageH := imageWH[2]
			calibration := getCalibration()
			hasSizeInfo := True
			;MsgBox, imageW: %imageW%, imageH: %imageH%
			imageInfo["imageWum"] := imageW * calibration
			imageInfo["imageHum"] := imageH * calibration
			imageInfo["calibration"] := calibration
		}
		WinWaitActive, ahk_id %analyzerWinId%, , 5
		WinActivate, ahk_id %analyzerWinId%
	
		; Add scale bar
		scaleBar := options["insertScale"]
		if (scaleBar = "yes" or scaleBar = true){
			; Set the zoom to a known state
			zoom := 0.1
			setCanvas()
			addScaleBar(calibration, imageW, imageH, zoom, options)
		}
		WinWaitActive, ahk_id %analyzerWinId%, , 5
		WinActivate, ahk_id %analyzerWinId%
		
		; Save
		if (isInList("JPEG", userFormats)) {
			saveJpg(outputDirPath, currentName, chLabel)
		}
		; We never want to save the small tiff here (it's just a screenshot)
		; if (hasSizeInfo and options["saveSmallTiff"]) {
		; 	saveTiffSmall(outputDirPath, currentName, channel, analyzerWinId)
		; 	closeImage(analyzerWinId)
		; } else {
			doNotSaveTiffSmall()			
		; }
		WinWaitActive, ahk_id %analyzerWinId%, , 5
		WinActivate, ahk_id %analyzerWinId%
	}

	; Close the program
	WinWaitActive, ahk_id %analyzerWinId%, , 5
	WinActivate, ahk_id %analyzerWinId%
	Sleep 500
	WinClose, ahk_id %analyzerWinId%
	WinWaitClose, ahk_id %analyzerWinId%,, 30
	if (ErrorLevel) {
		; Retry with Force
		WinActivate, ahk_id %analyzerWinId%
		Sleep 500
		WinKill, ahk_id %analyzerWinId%
		WinWaitClose, ahk_id %analyzerWinId%,, 10
		if (ErrorLevel) {
			MsgBox, Timed out waiting for Analyzer to close. Exiting ...
			ExitApp
		}
	}
	
	; Return true when it generated images
	return true
} 