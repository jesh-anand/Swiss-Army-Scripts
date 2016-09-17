;^ = Ctrl
;+ = Shift
;! = Alt
;# = Windows Key

SetTitleMatchMode RegEx ;

;--	Activating Window with Windows+Key

^!d::WinActivate Notepad
^!e::WinActivate Eclipse

;--	Launching programs with Ctrl+Shift+Key

^+d::Run C:\Windows\system32\notepad.exe
