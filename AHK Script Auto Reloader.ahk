/*
  AHK Script Auto Reloader
  
  
  Monitor running AHK scripts, and reloads them automatically when the AHK file is updated.

	This is a utility script that can help while developing other scripts.  Whenever any script is saved, it will be reloaded and
	started automatically.
	For each script, use the GUI to decide if it should be restarted only if it changes, or if any AHK file in the same folder
	is updated.

	The script basically uses the technique described by skrommel in https://autohotkey.com/board/topic/122-automatic-reload-of-changed-script/ and the example from https://www.autohotkey.com/docs/misc/SendMessage.htm

	Uri - V1.0 -  3/2021

*/

global VERSION:="1.0"

#NoEnv  
SetWorkingDir %A_ScriptDir%
#Persistent
#SingleInstance, force
SetBatchLines, -1
#Warn  All, MsgBox

DetectHiddenWindows, On

try menu, tray, Icon,AHK Script Auto Reloader.png
Menu, Tray, Tip, AHK Script Auto Reloader %VERSION%
Menu, Tray, add, Open Auto Reloader, gui
Menu, tray, Default, Open Auto Reloader


global INIFILE := "Auto Script Reloader.INI"

global scriptNameToID := {}

global scriptIDtoisActive := {}
global scriptIDtoisFolderMonitored := {}

global scriptIDtoIsActiveHWND := {}
global scriptIDtoIsFolderMonitoredHWND := {}

global lastModDateForID := {}
global scriptsCount:=0


;Read last config:
Loop, 
{
	IniRead, isActive, %INIFILE%, General, isActive%A_Index%
	If (isActive=="ERROR") {
		Break
	}
	scriptIDtoisActive[A_Index]:=isActive
	IniRead, name, %INIFILE%, General, scriptName%A_Index%
	IniRead, isMonitoringFolder, %INIFILE%, General, isMonitoringFolder%A_Index%
	scriptIDtoisFolderMonitored[A_Index] := isMonitoringFolder
	scriptNameToID[name]:=A_Index
}


SetTimer,checkAndRestartScripts, 2000


;Timed job, to check if any script file was updated.
checkAndRestartScripts() {

	global scriptNameToID 

	global scriptIDtoisActive 
	global scriptIDtoisFolderMonitored

	WinGet, runningScripts, List, ahk_class AutoHotkey
	toolTipText:=""
	Loop % runningScripts {

		WinGetTitle, title, % "ahk_id" runningScripts%A_Index%
		if (InSTR(title,"Script Auto Reloader")) {
			continue
		}
		
		;should restart?
		scriptFile:=Substr(title,1,InSTR(title," - AutoHotKey"))
		cleanScriptFile:=RegexReplace(scriptFile, "[\W]", "")
		id:=scriptNameToID[cleanScriptFile]
		if (id=="") {
			continue
		}
		if (scriptIDtoisActive[id]!=1) {
			continue
		}			
		
		FileGetTime, t, %scriptFile%

		;should check the entire folder?
		if (scriptIDtoisFolderMonitored[id]==1) {
			;all *AHK in this folder.  't' will be the timestamp of the newest file
			SplitPath, scriptFile,,scriptFolder
			Loop Files, %scriptFolder%\*.ahk, F 
			{
				FileGetTime, t1, %A_LoopFileLongPath%
				if (t1>t) {
					t:=t1
				}
			}
		}
		
		if (lastModDateForID[id]=="") {
			;first cycle. store current timestamp
			lastModDateForID[id]:=t
		} else {
			;Not first cycle. see if timestamp has changed
		
			if (lastModDateForID[id] < t) {
				;Change !
				lastModDateForID[id]:=t
				toolTipText.="Restarting script " scriptFile "`n"
				PostMessage, 0x0111, 65303,,, % "ahk_id" . runningScripts%A_Index%

			}
		}
	}
	if(StrLen(ToolTipText)>0) {
		ToolTipText:="AHK Script Auto Reloader: `n" . ToolTipText
		Tooltip, % ToolTipText, % A_ScreenWidth - 200, 100
		SetTimer, RemoveToolTip, -5000
	}
}



gui() {	
	global scriptNameToID 

	global scriptIDtoisActive 
	global scriptIDtoisFolderMonitored

	global scriptIDtoIsActiveHWND 
	global scriptIDtoIsFolderMonitoredHWND 

	global scriptsCount

	
	Gui, Font, S10 CDefault, Verdana
	;Gui +Resize +MinSize400x200
	Gui Add, text,, Monitoring AHK Scripts:

	WinGet, runningScripts, List, ahk_class AutoHotkey
	Loop % runningScripts {

		WinGetTitle, title, % "ahk_id" runningScripts%A_Index%
		scriptFile:=Substr(title,1,InSTR(title," - AutoHotKey"))
		if (InSTR(title,"Script Auto Reloader")) {
			;Ignore this script
			continue
		}


		cleanScriptFile:=RegexReplace(scriptFile, "[\W]", "")
		id:=scriptNameToID[cleanScriptFile]
		if (id=="") {
			scriptsCount++
			scriptNameToID[cleanScriptFile]:=scriptsCount
			id:=scriptsCount
		}
			
		isChecked:=scriptIDtoisActive[id]
		if (isChecked=="") {
			isChecked:=0
		}
		Gui Add, CheckBox, x30 y+10 w100 Checked%isChecked% hwnd_h, Monitor	
		scriptIDtoIsActiveHWND[id]:=_h
		gui, add, text, x+10 w800, % title

		isChecked:=scriptIDtoisFolderMonitored[id]
		Gui Add, CheckBox, x+10 w140 Checked%isChecked% hwnd_h, Monitor Folder	
		scriptIDtoIsFolderMonitoredHWND[id]:=_h

	}	
	
	Gui Add, Text, x30 w900 y+20, Each script marked with "Monitor" will be restarted whenever the .AHK file changes.
	Gui Add, Text, x30 w900 y+10, "Monitor Folder" will cause the script to be restarted whenever any .AHK file in the same folder is updated.
	
	Gui Add, Button, x800 y+20 w80 gbuttonOK, OK
	
	gui, show,, AHK Script Auto Reloader	

	return
	
GuiEscape:	
	Gui, Destroy
	return

	
buttonOK:
GuiClose:
	for scriptName,id in scriptNameToID {
		hwnd := scriptIDtoIsActiveHWND[id]
		ControlGet isChecked, Checked,,, ahk_id %hwnd%
		scriptIDtoisActive[id] := isChecked

		;Get value of "is folder monitored" checkbox
		_h := scriptIDtoIsFolderMonitoredHWND[id]
		ControlGet isChecked, Checked,,, ahk_id %_h%	
		scriptIDtoisFolderMonitored[id] := isChecked
		
		
		INIWRITE, % scriptIDtoisActive[id] , %INIFILE% ,General, isActive%ID%
		INIWRITE, % scriptIDtoisFolderMonitored[id] , %INIFILE% ,General, isMonitoringFolder%ID%
		INIWRITE, % scriptName , %INIFILE% ,General, scriptName%ID%
		
	}

	Gui, Submit, NoHide ; Get the info entered in the GUI
	Gui, Destroy
	return


}




RemoveToolTip() {
	ToolTip
}
