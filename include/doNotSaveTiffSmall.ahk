;when only jpg, not tiff is saved, tiffs need to be closed individually
doNotSaveTiffSmall(){

	; The active window
	winId := winExist("A")
	
	; Send the close sequence (alt+f, c)
	Sleep 500
	Send !f
	Sleep 500
	Send c
	Sleep 1000
	
	; Yes/No dialog
	; ahk_class #32770 is the standard class for dialogs
	WinWaitActive, ahk_class #32770, , 20
	if (ErrorLevel) {
		; If the window didn't appear, maybe it closed already?
		return
	}
	Sleep 500
	Send !n  ; Alt+N triggers the No button reliably
	
	WinWaitClose, ahk_class %winId%

}
