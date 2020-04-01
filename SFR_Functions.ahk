#Warn
#NoEnv
SetWorkingDir ,% A_ScriptDir
; ==================================================================================================================================
; Function taken from https://www.autohotkey.com/boards/viewtopic.php?t=18939&p=302675
; Shows a dialog to select a folder.
; Depending on the OS version the function will use either the built-in FileSelectFolder command (XP and previous)
; or the Common Item Dialog (Vista and later).
; Parameter:
;     StartingFolder -  the full path of a folder which will be preselected.
;     Prompt         -  a text used as window title (Common Item Dialog) or as text displayed withing the dialog.
;     ----------------  Common Item Dialog only:
;     OwnerHwnd      -  HWND of the Gui which owns the dialog. If you pass a valid HWND the dialog will become modal.
;     BtnLabel       -  a text to be used as caption for the apply button.
;  Return values:
;     On success the function returns the full path of selected folder; otherwise it returns an empty string.
; MSDN:
;     Common Item Dialog -> msdn.microsoft.com/en-us/library/bb776913%28v=vs.85%29.aspx
;     IFileDialog        -> msdn.microsoft.com/en-us/library/bb775966%28v=vs.85%29.aspx
;     IShellItem         -> msdn.microsoft.com/en-us/library/bb761140%28v=vs.85%29.aspx
; ==================================================================================================================================
SelectFolderEx(StartingFolder := "", Prompt := "", OwnerHwnd := 0, OkBtnLabel := "") {
	Local ShellItem:= StrPtr:= FolderItem:= ""
	Static OsVersion := DllCall("GetVersion", "UChar")
		, IID_IShellItem := 0
		, InitIID := VarSetCapacity(IID_IShellItem, 16, 0)
				  & DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
		, Show := A_PtrSize * 3
		, SetOptions := A_PtrSize * 9
		, SetFolder := A_PtrSize * 12
		, SetTitle := A_PtrSize * 17
		, SetOkButtonLabel := A_PtrSize * 18
		, GetResult := A_PtrSize * 20
	SelectedFolder := ""
	If (OsVersion < 6) { ; IFileDialog requires Win Vista+, so revert to FileSelectFolder
	  FileSelectFolder, SelectedFolder, *%StartingFolder%, 3, %Prompt%
	  Return SelectedFolder
	}
	OwnerHwnd := DllCall("IsWindow", "Ptr", OwnerHwnd, "UInt") ? OwnerHwnd : 0
	If !(FileDialog := ComObjCreate("{DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7}", "{42f85136-db7e-439c-85f1-e4075d135fc8}"))
	  Return ""
	VTBL := NumGet(FileDialog + 0, "UPtr")
	; FOS_CREATEPROMPT | FOS_NOCHANGEDIR | FOS_PICKFOLDERS
	DllCall(NumGet(VTBL + SetOptions, "UPtr"), "Ptr", FileDialog, "UInt", 0x00002028, "UInt")
	If (StartingFolder <> "")
	  If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", StartingFolder, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", FolderItem)
		 DllCall(NumGet(VTBL + SetFolder, "UPtr"), "Ptr", FileDialog, "Ptr", FolderItem, "UInt")
	If (Prompt <> "")
	  DllCall(NumGet(VTBL + SetTitle, "UPtr"), "Ptr", FileDialog, "WStr", Prompt, "UInt")
	If (OkBtnLabel <> "")
	  DllCall(NumGet(VTBL + SetOkButtonLabel, "UPtr"), "Ptr", FileDialog, "WStr", OkBtnLabel, "UInt")
	If !DllCall(NumGet(VTBL + Show, "UPtr"), "Ptr", FileDialog, "Ptr", OwnerHwnd, "UInt") {
	  If !DllCall(NumGet(VTBL + GetResult, "UPtr"), "Ptr", FileDialog, "PtrP", ShellItem, "UInt") {
		 GetDisplayName := NumGet(NumGet(ShellItem + 0, "UPtr"), A_PtrSize * 5, "UPtr")
		 If !DllCall(GetDisplayName, "Ptr", ShellItem, "UInt", 0x80028000, "PtrP", StrPtr) ; SIGDN_DESKTOPABSOLUTEPARSING
			SelectedFolder := StrGet(StrPtr, "UTF-16"), DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
		 ObjRelease(ShellItem)
		}  
	}
	If (FolderItem)
	  ObjRelease(FolderItem)
	ObjRelease(FileDialog)
	Return SelectedFolder
}
; ==================================================================================================================================

UpdateTVg(FileToReplace:=""){ ; Updates the TreeView for the game directory
	While (settings.gCurrentFilePaths.Count()) { ; delete all the current file paths
		for l in settings.gCurrentFilePaths
			settings.gCurrentFilePaths.Delete(l)
	}
	; Empty the TreeView
	Gui, TreeView, TVg
	TV_Delete()
	; Refill the TreeView with the files of the current directory and store their full paths
	GuiControl, -Redraw, TVg ; for performance purposes
	Loop, Files, % settings.gSaveDir "\*.sgd"  ; Get all files in the directory, including subfolders
	{
		AddedID := TV_Add(A_LoopFileName,, "Icon1")
		settings.gCurrentFilePaths[A_LoopFileName] := A_LoopFileLongPath ; Save the file paths and use their names as keys
		if (A_LoopFileName == FileToReplace) ; Get id of the game save to have to be selected after the TreeView is drawn
			IDToSelect := AddedID
	}
	GuiControl, +Redraw, TVg
	if (FileToReplace)
		TV_Modify(IDToSelect, "+Select")
}
; ==================================================================================================================================

UpdateTVp(BackupName:=""){ ; Updates the TreeView for the personal directory
	IDToSelect := ""
	While (settings.pCurrentFilePaths.Count()) {
		for l in settings.pCurrentFilePaths
			settings.pCurrentFilePaths.Delete(l)
	}
	Gui, TreeView, TVp
	TV_Delete()
	GuiControl, -Redraw, TVp
	Loop, Files, % settings.pSaveDir "\*.*", D  ; Get all sub-folders in the directory
	{
		Parent := TV_Add(A_LoopFileName,, "Icon2")
		settings.pCurrentFilePaths[A_LoopFileName] := A_LoopFileLongPath
		Loop, Files, % A_LoopFileLongPath "\*.sgd" 
		{
			id := TV_Add(A_LoopFileName, Parent, "Icon1")
			if (A_LoopFileName == BackupName . ".sgd")
				IDToSelect := id
			settings.pCurrentFilePaths[A_LoopFileName] := A_LoopFileLongPath ; Save the file paths and use their names as keys
		}
	}
	Loop, Files, % settings.pSaveDir "\*.sgd"
	{
		id := TV_Add(A_LoopFileName,, "Icon1")
		if (A_LoopFileName == BackupName . ".sgd" && !IDToSelect)
			IDToSelect := id
		settings.pCurrentFilePaths[A_LoopFileName] := A_LoopFileLongPath
	}
	GuiControl, +Redraw, TVp
	if (BackupName){
		TV_Modify(IDToSelect, "+Select +VisFirst" )
		SetTimer, CheckFiles, Off
		Sleep, 1000
		SetTimer, CheckFiles, On
	}
}
; ==================================================================================================================================

UpdateDirs(key){ ; Function that is called when the user chooses an option in the saved games DropDownList
	; Takes the choice the user made as a parameter to use to retrieve the path to the saved directories
	settings.gSaveDir := settings.SavedDirs[key][1]
	settings.pSaveDir := settings.SavedDirs[key][2]
	; Update relevant text then update TreeViews
	GuiControl, Text, ptext, % "Current personal directory: " settings.pSaveDir
	GuiControl, Text, gtext, % "Current game directory: " settings.gSaveDir
	UpdateTVg()
	UpdateTVp()
}
; ==================================================================================================================================

CheckFiles(){
	gOldTime := pOldTime := A_Now ; Get the current time to compare it to the last modified time of the folders
	Gui, Main:Default ; Ensures the corrct gui window will be acted on when the update functions are called
	FileGetTime, gNewTime, % settings.gSaveDir
	if ((gNewTime -= gOldTime, DHMS) > -2){
		UpdateTVg()
	}
	FileGetTime, pNewTime, % settings.pSaveDir
	if ((pNewTime -= pOldTime, DHMS) > -2){
		UpdateTVp()
	}
}
; ==================================================================================================================================

SaveDir(gdir, pdir){ ; takes currently selected game and personal directories as parameters
	Gui, Main:+OwnDialogs
	loop {
		InputBox, name, Savefile Replacer, Name the directory,, 200, 150
		for k in settings.SavedDirs { ; check if the name is already saved and warns the user (not case sensitive)
			if (k == name){
				MsgBox, 48, Savefile Replacer, % "The name: """ k """ already exists please choose another one."
				name := ""
				break
			}
		}		
	} until (name || ErrorLevel)
	if (ErrorLevel == 1)
		return ""
	; Update the directories in the settings
	settings.gSaveDir := gdir
	settings.pSaveDir := pdir
	settings.SavedDirs[name] := [gdir, pdir] ; Use the name as a key with it's value being a small array that holds both directories
	return name
}

SpecialCaseAK(FileName, FileToReplaceWith){
	if (InStr(FileName, "0x")){
		if (settings.gCurrentFilePaths.HasKey("BAK1Save0x0.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save0x0.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save0x1.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save0x1.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save0x2.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save0x2.sgd"], 1
	} else if (InStr(FileName, "1x")){
		if (settings.gCurrentFilePaths.HasKey("BAK1Save1x0.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save1x0.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save1x1.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save1x1.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save1x2.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save1x2.sgd"], 1
	} else if (InStr(FileName, "2x")){
		if (settings.gCurrentFilePaths.HasKey("BAK1Save2x0.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save2x0.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save2x1.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save2x1.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save2x2.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save2x2.sgd"], 1
	} else if (InStr(FileName, "3x")){
		if (settings.gCurrentFilePaths.HasKey("BAK1Save3x0.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save3x0.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save3x1.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save3x1.sgd"], 1
		if (settings.gCurrentFilePaths.HasKey("BAK1Save3x2.sgd"))
			FileCopy, % settings.pCurrentFilePaths[FileToReplaceWith], % settings.gCurrentFilePaths["BAK1Save3x2.sgd"], 1
	}
}
