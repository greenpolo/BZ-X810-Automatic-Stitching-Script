#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

MsgBox, 0, Coordinate Finder, Move your mouse over the checkboxes to see their coordinates.`n`nPress ESC to exit.

Loop
{
    CoordMode, Mouse, Client
    MouseGetPos, xpos, ypos
    ToolTip, X: %xpos% Y: %ypos%
    Sleep, 100
}

Esc::ExitApp
