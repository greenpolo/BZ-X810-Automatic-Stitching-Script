; ============================================================================
; Naming GUI — Shows detected folders and lets user assign custom output names
; Called before stitching; renameOutputFiles() called after stitching
;
; All callbacks are functions (not labels) to avoid top-level return statements
; that would terminate the auto-execute section when this file is #included.
; ============================================================================

showNamingGui(ByRef folderList) {
	global  ; assume-global — needed for dynamic GUI control variables (NamingEdit1, NamingEdit2, ...)

	NamingFolderCount := folderList.MaxIndex()
	if (NamingFolderCount = "" or NamingFolderCount = 0) {
		return
	}

	NamingGuiResult := ""

	; Calculate dimensions
	rowHeight := 35
	labelW := 280
	editW := 280
	btnW := 80
	guiW := 720
	contentH := NamingFolderCount * rowHeight + 20
	visibleH := 450
	if (contentH < visibleH) {
		visibleH := contentH
	}
	winH := visibleH + 70

	; Destroy any previous instance
	Gui, NamingMain:Destroy
	Gui, NamingScroll:Destroy

	; Outer window
	Gui, NamingMain:+Resize -MaximizeBox +HwndNamingMainHwnd
	Gui, NamingMain:Margin, 10, 10

	; Scrollable child panel parented to main window via HWND
	Gui, NamingScroll:+Parent%NamingMainHwnd% -Caption +Border
	Gui, NamingScroll:Margin, 5, 5

	; Build rows
	Loop, %NamingFolderCount% {
		idx := A_Index
		folderInfo := folderList[idx]
		autoName := folderInfo["name"]
		yPos := (idx - 1) * rowHeight + 5

		; Label showing the auto-generated name
		Gui, NamingScroll:Add, Text, x5 y%yPos% w%labelW% h20, %autoName%

		; Edit box for custom name
		editX := labelW + 10
		Gui, NamingScroll:Add, Edit, x%editX% y%yPos% w%editW% h22 vNamingEdit%idx%

		; Fill below button — vNamingBtn%idx% lets the callback identify the row
		btnX := editX + editW + 5
		Gui, NamingScroll:Add, Button, x%btnX% y%yPos% w%btnW% h22 vNamingBtn%idx% gFillBelowClicked, Fill below
	}

	; Show child panel inside main window
	Gui, NamingScroll:Show, x5 y5 w%guiW% h%contentH%

	; OK and Skip buttons on the main window
	btnY := visibleH + 15
	okX := guiW // 2 - 90
	skipX := guiW // 2 + 10
	Gui, NamingMain:Add, Button, x%okX% y%btnY% w80 h28 gNamingOK Default, OK
	Gui, NamingMain:Add, Button, x%skipX% y%btnY% w80 h28 gNamingSkip, Skip

	; Show main window
	totalW := guiW + 30
	Gui, NamingMain:Show, w%totalW% h%winH%, Name Your Images

	; Block until user clicks OK or Skip
	While (NamingGuiResult = "") {
		Sleep 100
	}

	if (NamingGuiResult = "ok") {
		; Read edit values back into folderList
		Gui, NamingScroll:Submit, NoHide
		Loop, %NamingFolderCount% {
			idx := A_Index
			customName := NamingEdit%idx%
			customName := Trim(customName)
			folderList[idx]["customName"] := customName
		}

		; Validate: check for duplicates among non-blank names
		seen := {}
		Loop, %NamingFolderCount% {
			idx := A_Index
			cn := folderList[idx]["customName"]
			if (cn != "") {
				if (seen.HasKey(cn)) {
					MsgBox, 0x30, Naming Warning, Duplicate name detected: "%cn%"`nPlease fix duplicates.
					NamingGuiResult := ""
					While (NamingGuiResult = "") {
						Sleep 100
					}
					if (NamingGuiResult = "ok") {
						Gui, NamingScroll:Submit, NoHide
						Loop, %NamingFolderCount% {
							j := A_Index
							val := NamingEdit%j%
							folderList[j]["customName"] := Trim(val)
						}
					}
					break
				}
				seen[cn] := true
			}
		}

		; Validate: illegal filename characters
		Loop, %NamingFolderCount% {
			idx := A_Index
			cn := folderList[idx]["customName"]
			if (cn != "" and RegExMatch(cn, "[\\/:*?""<>|]")) {
				MsgBox, 0x10, Naming Error, Invalid characters in name: "%cn%"`nRemove \ / : * ? " < > | characters.
				folderList[idx]["customName"] := ""
			}
		}
	}

	Gui, NamingMain:Destroy
	Gui, NamingScroll:Destroy
}

; ============================================================================
; GUI callback functions (no top-level labels/returns)
; ============================================================================

NamingOK() {
	global NamingGuiResult
	NamingGuiResult := "ok"
}

NamingSkip() {
	global NamingGuiResult
	NamingGuiResult := "skip"
}

NamingMainGuiClose() {
	global NamingGuiResult
	NamingGuiResult := "skip"
}

FillBelowClicked() {
	global  ; assume-global — needed for dynamic NamingEdit variables

	Gui, NamingScroll:Submit, NoHide

	; A_GuiControl is the v-variable name of the clicked button, e.g. "NamingBtn3"
	; Extract the row index from it
	clickedIdx := SubStr(A_GuiControl, 10)  ; strip "NamingBtn" (9 chars)
	clickedIdx := clickedIdx + 0  ; force numeric

	if (clickedIdx < 1 or clickedIdx > NamingFolderCount) {
		return
	}

	; Get the text from the clicked row's edit
	baseText := NamingEdit%clickedIdx%
	if (baseText = "") {
		return
	}

	; Parse trailing _XX number from the typed text
	; e.g. "M03_15" -> prefix "M03", startNum 15, width 2
	if (RegExMatch(baseText, "O)^(.+?)_(\d+)$", m)) {
		prefix := m.Value(1)
		startNum := m.Value(2) + 0  ; force numeric
		numWidth := StrLen(m.Value(2))  ; preserve zero-pad width
	} else {
		; No trailing number — fall back to appending _01, _02, ...
		prefix := baseText
		startNum := 0
		numWidth := 2
	}

	; Fill all rows below by incrementing the number
	nextNum := startNum + 1
	idx := clickedIdx + 1
	While (idx <= NamingFolderCount) {
		numStr := Format("{:0" numWidth "}", nextNum)
		fillText := prefix "_" numStr
		GuiControl, NamingScroll:, NamingEdit%idx%, %fillText%
		nextNum := nextNum + 1
		idx := idx + 1
	}
}

; ============================================================================
; Rename output files after stitching completes
; ============================================================================
renameOutputFiles(ByRef folderList, outputDir) {
	if (folderList.MaxIndex() = "" or folderList.MaxIndex() = 0) {
		return
	}

	; Build rename pairs: oldPrefix -> newPrefix
	renamePairs := []
	Loop, % folderList.MaxIndex() {
		idx := A_Index
		folderInfo := folderList[idx]
		customName := folderInfo["customName"]
		autoName := folderInfo["name"]

		if (customName = "" or customName = autoName) {
			continue
		}

		pair := {}
		pair["old"] := autoName
		pair["new"] := customName
		renamePairs.Push(pair)
	}

	if (renamePairs.MaxIndex() = "" or renamePairs.MaxIndex() = 0) {
		return
	}

	; Sort by old prefix length (longest first) to avoid substring collisions
	n := renamePairs.MaxIndex()
	Loop, % n - 1 {
		i := A_Index
		j := i + 1
		While (j <= n) {
			if (StrLen(renamePairs[j]["old"]) > StrLen(renamePairs[i]["old"])) {
				tmp := renamePairs[i]
				renamePairs[i] := renamePairs[j]
				renamePairs[j] := tmp
			}
			j := j + 1
		}
	}

	; Rename files in output directory
	for idx, pair in renamePairs {
		oldPrefix := pair["old"]
		newPrefix := pair["new"]

		Loop, %outputDir%\*.*
		{
			fileName := A_LoopFileName
			filePath := A_LoopFileLongPath

			if (SubStr(fileName, 1, StrLen(oldPrefix)) = oldPrefix) {
				nextChar := SubStr(fileName, StrLen(oldPrefix) + 1, 1)
				if (nextChar = "_" or nextChar = "." or nextChar = "") {
					newFileName := newPrefix . SubStr(fileName, StrLen(oldPrefix) + 1)
					; Strip _ovly suffix (e.g. "name_ovly.tif" -> "name.tif")
					newFileName := RegExReplace(newFileName, "_ovly(\.[^.]+)$", "$1")
					newFilePath := outputDir "\" newFileName
					FileMove, %filePath%, %newFilePath%
				}
			}
		}
	}
}
