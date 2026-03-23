; ============================================================================
; Batch stitching for Keyence RGB mode
; Processes multiple folders without restarting Keyence each time
; ============================================================================
runStitchingBatch(folderList, outputDirPath, options) {
	; Keystroke settings
	SetKeyDelay, 20, 1
	
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
	
	; Click Load a Group button:
	ControlFocus, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer
	ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer, , LEFT, , , , NA 
	
	; Wait for Load a Group window
	WinWaitActive, Load a Group., , 6,
	if (ErrorLevel) {
		MsgBox, Timed out waiting for "Load a Group" window. Exiting ...
		ExitApp
	}
	
	; Process each folder
	for idx, folderInfo in folderList {
		inputDirPath := folderInfo["path"]
		currentName := folderInfo["name"]
		
		; Enter the path to the input file
		WinActivate, Load a Group.
		ControlFocus, Edit1, Load a Group.
		Sleep 250
		ControlSetText, Edit1, %inputDirPath%, Load a Group.,
		Sleep 250
		Send {Enter}
		Sleep 3000
		if (WinExist("Loading")) {
			WinWaitClose, Loading
		}
		WinWaitActive, Load a Group., , 3000
		WinActivate, Load a Group.
		
		; We only care about overlay in batch mode, no need to parse channel metadata
		
		; Configure checkboxes using pixel color detection
		; Checked color is roughly BLUE, Unchecked is GRAY.
		; We use a helper function isPixelBlue() to be robust against shade variations.
		
		; Ensure window is active and ready
		Sleep 500
		WinActivate, Load a Group.
		
		CoordMode, Pixel, Client
		CoordMode, Mouse, Client
		
		; CH1 - Uncheck if checked (Client: 588, 90)
		PixelGetColor, pixelColor, 588, 90, RGB
		if (isPixelBlue(pixelColor)) {
			Click, 588, 90
			Sleep 300
		}
		
		; CH2 - Uncheck if checked (Client: 902, 89)
		PixelGetColor, pixelColor, 902, 89, RGB
		if (isPixelBlue(pixelColor)) {
			Click, 902, 89
			Sleep 300
		}
		
		; CH3 - Uncheck if checked (Client: 589, 513)
		PixelGetColor, pixelColor, 589, 513, RGB
		if (isPixelBlue(pixelColor)) {
			Click, 589, 513
			Sleep 300
		}
		
		; Overlay - Check if unchecked (Client: 1150, 40)
		PixelGetColor, pixelColor, 1150, 40, RGB
		if (!isPixelBlue(pixelColor)) {
			Click, 1150, 40
			Sleep 300
		}
		
		; Click Load(L) to open Image Stitch window
		ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, Load a Group., , LEFT, , , , NA 
		
		; Wait for Image Stitch window
		WinWaitActive, Image Stitch, , 500
		
		; Wait for image to load
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
		}
		
		; Select uncompressed
		Control, Check, , WindowsForms10.BUTTON.app.0.1ca0192_r6_ad11, Image Stitch
		Sleep 1000 
		
		; Click Start Stitching
		ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad16, Image Stitch, , LEFT, , , , NA 
		
		; Wait for stitching to complete
		isLoading := True
		maxWait := 900  ; In seconds (900 = 15 minutes)
		while (isLoading and maxWait > 0) {
			samples := 2  ; Reduced from 8 for faster response
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
				sleep 500  ; Reduced from 1000
			}
			maxWait := (maxWait - samples*1)
		}
		if (maxWait == 0) {
			MsgBox Exiting app: timed out stitching %inputDirPath%
			ExitApp
		}
		
		; BZ-X800 Wide Image Viewer - Export the overlay
		userFormats := StrSplit(options["formats"], ",", " ")
		
		sleep 500  ; Reduced from 2000
		WinGetTitle, currentTitle, A
		if (currentTitle = "Overview Window") {
			currentWin := WinExist("A")
			WinClose, A
			WinWaitClose, ahk_id %currentWin%, , 20
			sleep 500  ; Reduced from 2000
		}
		WinGetTitle, currentTitle, A
		currentWin := WinExist("A")
		if (not RegexMatch(currentTitle, "BZ-X800 Wide Image Viewer .*ktf.*")) {
			MsgBox Lost track of the image window`nCurrent window title is %currentWin%`n Exiting now.
			ExitApp
		}
		
		; Export TIFF
		if (isInList("TIFF", userFormats)) {
			exportTiff(outputDirPath, currentName, "ovly")
		}
		WinWaitActive, ahk_id %currentWin% , , 20
		
		; Don't save KTF, just close
		doNotSaveKtf()
		WinWaitClose, ahk_id %currentWin%, , 240
		if (ErrorLevel) {
			MsgBox, Timed out waiting for WideImageViewer to close.
			ExitApp
		}
		
		; Close Image Stitch window
		WinWaitActive, Image Stitch, , 30
		WinClose, Image Stitch
		WinWaitClose, Image Stitch, , 30
		
		; Close Load a Group window
		WinClose, Load a Group.
		WinWaitClose, Load a Group., , 30
		
		; Re-open Load a Group (address bar will be highlighted)
		WinActivate, ahk_id %analyzerWinId%
		ControlFocus, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer
		ControlClick, WindowsForms10.BUTTON.app.0.1ca0192_r6_ad118, BZ-X800 Analyzer, , LEFT, , , , NA 
		
		; Wait for Load a Group window
		WinWaitActive, Load a Group., , 6,
		if (ErrorLevel) {
			MsgBox, Timed out waiting for "Load a Group" window to re-open. Exiting ...
			ExitApp
		}
	}
	
	; All folders done, keep windows open
	; WinClose, Load a Group.
	; WinWaitClose, Load a Group., , 30
	
	; Close the Analyzer
	; WinWaitActive, ahk_id %analyzerWinId%, , 5
	; WinActivate, ahk_id %analyzerWinId%
	; Sleep 500
	; WinClose, ahk_id %analyzerWinId%
	; WinWaitClose, ahk_id %analyzerWinId%,, 30
	; if (ErrorLevel) {
	; 	WinActivate, ahk_id %analyzerWinId%
	; 	Sleep 500
	; 	WinClose, ahk_id %analyzerWinId%
	; 	WinWaitClose, ahk_id %analyzerWinId%,, 30
	; }
	
	return true
}

; Helper function to check if a pixel color is "Blue-ish" (Checked)
; Returns true if Blue component is high and Red is low
isPixelBlue(colorHex) {
	; colorHex format is 0xRRGGBB
	if (colorHex = "" or StrLen(colorHex) != 8) {
		return false
	}
	
	; Extract RGB components
	Red   := "0x" . SubStr(colorHex, 3, 2)
	Green := "0x" . SubStr(colorHex, 5, 2)
	Blue  := "0x" . SubStr(colorHex, 7, 2)
	
	Red   := Red + 0
	Green := Green + 0
	Blue  := Blue + 0
	
	; Check if Blue is dominant (Checked color 0x196EBF -> R=25, G=110, B=191)
	; Unchecked color 0xEAEAEA -> R=234, G=234, B=234
	
	; Heuristic: Blue > 128 (0x80) AND Red < 128 (0x80)
	isBlue := (Blue > 128 and Red < 128)
	
	return isBlue
}
