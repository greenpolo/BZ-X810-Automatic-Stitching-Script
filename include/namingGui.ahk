; ============================================================================
; Naming GUI — Shows detected folders and lets user assign custom output names
; Called before stitching; renameOutputFiles() called after stitching
;
; Two ways to assign names:
;   1) "Paste names..." — paste the output-name column from your tracking
;      spreadsheet; names are applied to the detected folders top-to-bottom.
;      This is the primary workflow and accommodates any naming scheme.
;   2) Per-row edit boxes — type a name, or use "Fill below" to auto-increment
;      a trailing _NN number down the list.
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
	rowHeight := 30
	labelW := 280
	editW := 280
	btnW := 80
	guiW := 720
	contentH := NamingFolderCount * rowHeight + 20

	; Cap the visible panel to the screen so long sessions (~30 sections) fit
	visibleCap := A_ScreenHeight - 220
	if (visibleCap < 200) {
		visibleCap := 200
	}
	visibleH := contentH
	if (visibleH > visibleCap) {
		visibleH := visibleCap
	}

	toolbarH := 38
	panelY := toolbarH + 5
	btnY := panelY + visibleH + 12
	winH := btnY + 44

	; Destroy any previous instance
	Gui, NamingMain:Destroy
	Gui, NamingScroll:Destroy

	; Outer window
	Gui, NamingMain:+Resize -MaximizeBox +HwndNamingMainHwnd
	Gui, NamingMain:Margin, 10, 10

	; Top toolbar: paste-from-spreadsheet entry point
	Gui, NamingMain:Add, Button, x10 y8 w120 h26 gPasteNamesClicked, Paste names...
	Gui, NamingMain:Add, Text, x140 y13 w560 h20, Paste your spreadsheet's output-name column to fill all rows in order.

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
	Gui, NamingScroll:Show, x5 y%panelY% w%guiW% h%visibleH%

	; OK and Skip buttons on the main window
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
; Paste-from-spreadsheet: fill all rows from a pasted column of names
; ============================================================================

PasteNamesClicked() {
	global
	Gui, NamingPaste:Destroy
	Gui, NamingPaste:+AlwaysOnTop +ToolWindow +Owner%NamingMainHwnd%
	Gui, NamingPaste:Margin, 12, 12
	Gui, NamingPaste:Add, Text, w560, Paste the output-name column from your spreadsheet (one name per row).`nYou can paste several columns at once — the name column is detected automatically and a header row is ignored.`nNames are applied to the folders top-to-bottom; leave a row blank to skip that folder.
	Gui, NamingPaste:Add, Edit, w560 h320 vNamingPasteText -Wrap +VScroll +HScroll
	Gui, NamingPaste:Add, Button, x12 w110 gNamingPasteOK Default, Apply
	Gui, NamingPaste:Add, Button, x+10 w110 gNamingPasteCancel, Cancel
	Gui, NamingPaste:Show, , Paste Names
}

NamingPasteOK() {
	global
	Gui, NamingPaste:Submit, NoHide
	applyPastedNames(NamingPasteText)
	Gui, NamingPaste:Destroy
}

NamingPasteCancel() {
	Gui, NamingPaste:Destroy
}

NamingPasteGuiClose() {
	Gui, NamingPaste:Destroy
}

; Write the parsed names into the per-row edit boxes, top-to-bottom.
applyPastedNames(rawText) {
	global  ; NamingFolderCount and the dynamic NamingEdit vars

	names := parsePastedNames(rawText)
	cnt := names.MaxIndex()
	if (cnt = "" or cnt = 0) {
		MsgBox, 0x40, Paste Names, No names were found in the pasted text.
		return
	}

	Loop, %NamingFolderCount% {
		idx := A_Index
		val := (idx <= cnt) ? names[idx] : ""
		GuiControl, NamingScroll:, NamingEdit%idx%, %val%
	}

	if (cnt != NamingFolderCount) {
		MsgBox, 0x30, Paste Names, Pasted %cnt% name(s) but there are %NamingFolderCount% folder(s).`n`nNames were applied top-to-bottom. Please check the rows line up before clicking OK.
	}
}

; Parse pasted clipboard text into an ordered list of output names.
; Handles a plain one-name-per-line list or a multi-column TSV block copied
; from a spreadsheet, auto-detecting the column that holds the output names
; (cells shaped like "M01_A_01") and dropping a leading header/blank row.
parsePastedNames(rawText) {
	; Name shape: word chars / hyphens ending in _<digits>, e.g. M01_A_01
	namePattern := "i)^[\w\-]+_\d+$"

	; Normalize newlines
	StringReplace, rawText, rawText, `r`n, `n, All
	StringReplace, rawText, rawText, `r, `n, All
	lines := StrSplit(rawText, "`n")

	; Split each line into tab-separated columns, tracking the widest row
	hasTab := false
	maxCols := 1
	rows := []
	for i, ln in lines {
		if (InStr(ln, "`t")) {
			hasTab := true
		}
		cols := StrSplit(ln, "`t")
		rows.Push(cols)
		if (cols.MaxIndex() > maxCols) {
			maxCols := cols.MaxIndex()
		}
	}

	; Choose the source column: the one with the most name-shaped cells
	chosenCol := 1
	if (hasTab) {
		bestScore := -1
		Loop, %maxCols% {
			c := A_Index
			score := 0
			for i, cols in rows {
				v := (c <= cols.MaxIndex()) ? Trim(cols[c]) : ""
				if (RegExMatch(v, namePattern)) {
					score += 1
				}
			}
			if (score > bestScore) {
				bestScore := score
				chosenCol := c
			}
		}
		; No column looked like names — fall back to the last column
		if (bestScore <= 0) {
			chosenCol := maxCols
		}
	}

	; Extract the chosen column from every row
	names := []
	for i, cols in rows {
		v := (chosenCol <= cols.MaxIndex()) ? Trim(cols[chosenCol]) : ""
		names.Push(v)
	}

	; Trim trailing blank rows
	While (names.MaxIndex() >= 1 and Trim(names[names.MaxIndex()]) = "") {
		names.Pop()
	}

	; If we have a name-shaped anchor, drop leading header/blank rows up to it.
	; (Mid-list blanks are preserved so alignment with the folders is kept.)
	anyNumbered := false
	for i, nm in names {
		if (RegExMatch(nm, namePattern)) {
			anyNumbered := true
			break
		}
	}
	if (anyNumbered) {
		While (names.MaxIndex() >= 1 and !RegExMatch(names[1], namePattern)) {
			names.RemoveAt(1)
		}
	}

	return names
}

; ============================================================================
; Rename output files after stitching completes
; ============================================================================
renameOutputFiles(ByRef folderList, outputDir, options) {
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
					; Per-mouse routing: send the renamed file to baseOutput\<mouse>
					destDir := outputDirForName(outputDir, newPrefix, options)
					; Strip _ovly suffix only if it won't collide with an existing file
					strippedName := RegExReplace(newFileName, "_ovly(\.[^.]+)$", "$1")
					if (strippedName != newFileName and FileExist(destDir "\" strippedName) = "") {
						newFileName := strippedName
					}
					FileCreateDir %destDir%
					newFilePath := destDir "\" newFileName
					FileMove, %filePath%, %newFilePath%
				}
			}
		}
	}
}
