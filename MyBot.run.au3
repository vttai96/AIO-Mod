﻿; #FUNCTION# ====================================================================================================================
; Name ..........: MBR Bot
; Description ...: This file contains the initialization and main loop sequences f0r the MBR Bot
; Author ........:  (2014)
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2019
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

; AutoIt pragmas
#NoTrayIcon
#RequireAdmin
#AutoIt3Wrapper_UseX64=n ; Old bug
;#AutoIt3Wrapper_Res_HiDpi=Y ; HiDpi will be set during run-time!
;#AutoIt3Wrapper_Run_AU3Check=n ; enable when running in folder with umlauts!
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/rsln /MI=3
#AutoIt3Wrapper_Au3Check_Parameters=-w 1 -w 4 -w 6 -w 7
;~ #AutoIt3Wrapper_AU3Check_Stop_OnWarning=n


#include "MyBot.run.version.au3"
#pragma compile(ProductName, My Bot)
#pragma compile(Out, MyBot.run.exe) ; Required

; Enforce variable declarations
Opt("MustDeclareVars", 1)

Global $g_sBotTitle = "" ;~ Don't assign any title here, use Func UpdateBotTitle()
Global $g_hFrmBot = 0 ; The main GUI window

; MBR includes
#include "COCBot\MBR Global Variables.au3"
#include "COCBot\functions\Config\DelayTimes.au3"
#include "COCBot\GUI\MBR GUI Design Splash.au3"
#include "COCBot\functions\Config\ScreenCoordinates.au3"
#include "COCBot\Team__AiO__MOD++\functions\Config\ScreenCoordinates.au3" ; AIO Mod
#include "COCBot\functions\Config\ImageDirectories.au3"
#include "COCBot\Team__AiO__MOD++\functions\Config\ImageDirectories.au3" ; AIO Mod
#include "COCBot\functions\Other\ExtMsgBox.au3"
#include "COCBot\functions\Other\MBRFunc.au3"
#include "COCBot\functions\Other\DissociableFunc.au3"
#include "COCBot\functions\Android\Android.au3"
#include "COCBot\functions\Android\Distributors.au3"
#include "COCBot\MBR GUI Design.au3"
#include "COCBot\MBR GUI Control.au3"
#include "COCBot\MBR Functions.au3"
#include "COCBot\functions\Other\Multilanguage.au3"
; MBR References.au3 must be last include
#include "COCBot\MBR References.au3"

; Autoit Options
Opt("GUIResizeMode", $GUI_DOCKALL) ; Default resize mode for dock android support
Opt("GUIEventOptions", 1) ; Handle minimize and restore for dock android support
Opt("GUICloseOnESC", 0) ; Don't send the $GUI_EVENT_CLOSE message when ESC is pressed.
Opt("WinTitleMatchMode", 3) ; Window Title exact match mode
Opt("GUIOnEventMode", 1)
Opt("MouseClickDelay", GetClickUpDelay()) ;Default: 10 milliseconds
Opt("MouseClickDownDelay", GetClickDownDelay()) ;Default: 5 milliseconds
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)

; All executable code is in a function block, to detect coding errors, such as variable declaration scope problems
InitializeBot()

; Get All Emulators installed on machine.
getAllEmulators()

; Hand over control to main loop
MainLoop(CheckPrerequisites())

Func UpdateBotTitle()
	Local $sTitle = "My Bot " & $g_sBotVersion & " - " & "AiO++ MOD " & $g_sModVersion & " -" ; AIO Mod
	Local $sConsoleTitle ; Console title has also Android Emulator Name
	If $g_sBotTitle = "" Then
		$g_sBotTitle = $sTitle
		$sConsoleTitle = $sTitle
	Else
		$g_sBotTitle = $sTitle & " (" & ($g_sAndroidInstance <> "" ? $g_sAndroidInstance : $g_sAndroidEmulator) & ")" ;Do not change this. If you do, multiple instances will not work.
		$sConsoleTitle = $sTitle & " " & $g_sAndroidEmulator & " (" & ($g_sAndroidInstance <> "" ? $g_sAndroidInstance : $g_sAndroidEmulator) & ")"
	EndIf
	If $g_hFrmBot <> 0 Then
		; Update Bot Window Title also
		WinSetTitle($g_hFrmBot, "", $g_sBotTitle)
		GUICtrlSetData($g_hLblBotTitle, $g_sBotTitle)
	EndIf
	; Update Console Window (if it exists)
	DllCall("kernel32.dll", "bool", "SetConsoleTitle", "str", "Console " & $sConsoleTitle)
	; Update try icon title
	TraySetToolTip($g_sBotTitle)

	SetDebugLog("Bot title updated to: " & $g_sBotTitle)
EndFunc   ;==>UpdateBotTitle

Func InitializeBot()

	ProcessCommandLine()

	If FileExists(@ScriptDir & "\EnableMBRDebug.txt") Then ; Set developer mode
		$g_bDevMode = True
		$g_bDOCRDebugImages = True And $g_bDOCRDebugImages
		Local $aText = FileReadToArray(@ScriptDir & "\EnableMBRDebug.txt") ; check if special debug flags set inside EnableMBRDebug.txt file
		If Not @error Then
			For $l = 0 To UBound($aText) - 1
				If StringInStr($aText[$l], "DISABLEWATCHDOG", $STR_NOCASESENSEBASIC) <> 0 Then
					$g_bBotLaunchOption_NoWatchdog = True
					SetDebugLog("Watch Dog disabled by Developer Mode File Command", $COLOR_INFO)
				EndIf
			Next
		EndIf
	EndIf

	SetupProfileFolder() ; Setup profile folders

	SetLogCentered(" BOT LOG ") ; Initial text for log

	SetSwitchAccLog(_PadStringCenter(" SwitchAcc LOG ", 25, "="), $COLOR_BLACK, "Lucida Console", 8, False)

	DetectLanguage()
	If $g_iBotLaunchOption_Help Then
		ShowCommandLineHelp()
		Exit
	EndIf

	InitAndroidConfig()

	; early load of config
	Local $bConfigRead = FileExists($g_sProfileConfigPath)
	If $bConfigRead Or FileExists($g_sProfileBuildingPath) Then
		readConfig()
	EndIf

	Local $sAndroidInfo = ""
	; Disabled process priority tampering as not best practice
	;Local $iBotProcessPriority = _ProcessGetPriority(@AutoItPID)
	;ProcessSetPriority(@AutoItPID, $PROCESS_BELOWNORMAL) ;~ Boost launch time by increasing process priority (will be restored again when finished launching)

	_ITaskBar_Init(False)
	_Crypt_Startup()
	__GDIPlus_Startup() ; Start GDI+ Engine (incl. a new thread)
	TCPStartup() ; Start the TCP service.

	;InitAndroidConfig()
	CreateMainGUI() ; Just create the main window
	CreateSplashScreen() ; Create splash window

	; Ensure watchdog is launched (requires Bot Window for messaging)
	If Not $g_bBotLaunchOption_NoWatchdog Then LaunchWatchdog()

	InitializeMBR($sAndroidInfo, $bConfigRead)

	; Create GUI
	CreateMainGUIControls() ; Create all GUI Controls
	InitializeMainGUI() ; setup GUI Controls

	; Files/folders
	SetupFilesAndFolders()

	; Show main GUI
	ShowMainGUI()

	If $g_iBotLaunchOption_Dock Then
		If AndroidEmbed(True) And $g_iBotLaunchOption_Dock = 2 And $g_bCustomTitleBarActive Then
			BotShrinkExpandToggle()
		EndIf
	EndIf

	; Some final setup steps and checks
	FinalInitialization($sAndroidInfo)

	;ProcessSetPriority(@AutoItPID, $iBotProcessPriority) ;~ Restore process priority

EndFunc   ;==>InitializeBot

; #FUNCTION# ====================================================================================================================
; Name ..........: ProcessCommandLine
; Description ...: Handle command line parameters
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func ProcessCommandLine()

	; Handle Command Line Launch Options and fill $g_asCmdLine
	If $CmdLine[0] > 0 Then
		For $i = 1 To $CmdLine[0]
			Local $bOptionDetected = True
			Switch $CmdLine[$i]
				; terminate bot if it exists (by window title!)
				Case "/restart", "/r", "-restart", "-r"
					$g_bBotLaunchOption_Restart = True
				Case "/autostart", "/a", "-autostart", "-a"
					$g_bBotLaunchOption_Autostart = True
				Case "/nowatchdog", "/nwd", "-nowatchdog", "-nwd"
					$g_bBotLaunchOption_NoWatchdog = True
				Case "/dpiaware", "/da", "-dpiaware", "-da"
					$g_bBotLaunchOption_ForceDpiAware = True
				Case "/dock1", "/d1", "-dock1", "-d1", "/dock", "/d", "-dock", "-d"
					$g_iBotLaunchOption_Dock = 1
				Case "/dock2", "/d2", "-dock2", "-d2"
					$g_iBotLaunchOption_Dock = 2
				Case "/nobotslot", "/nbs", "-nobotslot", "-nbs"
					$g_bBotLaunchOption_NoBotSlot = True
				Case "/debug", "/debugmode", "/dev", "/dm", "-debug", "-debugmode", "-dev", "-dm"
					$g_bDevMode = True
					$g_bDOCRDebugImages = True And $g_bDOCRDebugImages
				Case "/minigui", "/mg", "-minigui", "-mg"
					$g_iGuiMode = 2
				Case "/nogui", "/ng", "-nogui", "-ng"
					$g_iGuiMode = 0
				Case "/hideandroid", "/ha", "-hideandroid", "-ha"
					$g_bBotLaunchOption_HideAndroid = True
				Case "/minimizebot", "/minbot", "/mb", "-minimizebot", "-minbot", "-mb"
					$g_bBotLaunchOption_MinimizeBot = True
				Case "/console", "/c", "-console", "-c"
					$g_iBotLaunchOption_Console = True
					ConsoleWindow()
				Case "/?", "/h", "/help", "-?", "-h", "-help"
					; show command line help and exit
					$g_iBotLaunchOption_Help = True
				Case Else
					If StringInStr($CmdLine[$i], "/guipid=") Then
						Local $guidpid = Int(StringMid($CmdLine[$i], 9))
						If ProcessExists($guidpid) Then
							$g_iGuiPID = $guidpid
						Else
							SetDebugLog("GUI Process doesn't exist: " & $guidpid)
						EndIf
					ElseIf StringInStr($CmdLine[$i], "/profiles=") = 1 Then
						Local $sProfilePath = StringMid($CmdLine[$i], 11)
						If StringInStr(FileGetAttrib($sProfilePath), "D") Then
							$g_sProfilePath = $sProfilePath
						Else
							SetLog("Profiles Path doesn't exist: " & $sProfilePath, $COLOR_ERROR) ;
						EndIf
					Else
						$bOptionDetected = False
						$g_asCmdLine[0] += 1
						ReDim $g_asCmdLine[$g_asCmdLine[0] + 1]
						$g_asCmdLine[$g_asCmdLine[0]] = $CmdLine[$i]
					EndIf
			EndSwitch
			If $bOptionDetected Then SetDebugLog("Command Line Option detected: " & $CmdLine[$i])
		Next
	EndIf

	; Handle Command Line Parameters
	If $g_asCmdLine[0] > 0 Then
		$g_sProfileCurrentName = StringRegExpReplace($g_asCmdLine[1], '[/:*?"<>|]', '_')
		If $g_asCmdLine[0] >= 2 Then
			If StringInStr($g_asCmdLine[2], "BlueStacks3") Or StringInStr($g_asCmdLine[2], "BlueStacks4") Then
				; BlueStacks v3 and v4 use same key as v2
				$g_asCmdLine[2] = "BlueStacks2"
			EndIf
		EndIf
	ElseIf FileExists($g_sProfilePath & "\profile.ini") Then
		$g_sProfileCurrentName = StringRegExpReplace(IniRead($g_sProfilePath & "\profile.ini", "general", "defaultprofile", ""), '[/:*?"<>|]', '_')
		If $g_sProfileCurrentName = "" Or Not FileExists($g_sProfilePath & "\" & $g_sProfileCurrentName) Then $g_sProfileCurrentName = "<No Profiles>"
	Else
		$g_sProfileCurrentName = "<No Profiles>"
	EndIf
EndFunc   ;==>ProcessCommandLine

; #FUNCTION# ====================================================================================================================
; Name ..........: InitializeAndroid
; Description ...: Initialize Android
; Syntax ........:
; Parameters ....: $bConfigRead - if config was already read and Android Emulator info loaded
; Return values .: None
; Author ........:
; Modified ......: cosote (Feb-2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func InitializeAndroid($bConfigRead)

	Local $s = GetTranslatedFileIni("MBR GUI Design - Loading", "StatusBar_Item_06", "Initializing Android...")
	SplashStep($s)

	If $g_bBotLaunchOption_Restart = False Then
		; Change Android type and update variable
		If $g_asCmdLine[0] > 1 Then
			; initialize Android config
			InitAndroidConfig(True)

			Local $i
			For $i = 0 To UBound($g_avAndroidAppConfig) - 1
				If StringCompare($g_avAndroidAppConfig[$i][0], $g_asCmdLine[2]) = 0 Then
					$g_iAndroidConfig = $i
					SplashStep($s & "(" & $g_avAndroidAppConfig[$i][0] & ")...", False)
					If $g_avAndroidAppConfig[$i][1] <> "" And $g_asCmdLine[0] > 2 Then
						; Use Instance Name
						UpdateAndroidConfig($g_asCmdLine[3])
					Else
						UpdateAndroidConfig()
					EndIf
					SplashStep($s & "(" & $g_avAndroidAppConfig[$i][0] & ")", False)
					ExitLoop
				EndIf
			Next
		EndIf

		SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "StatusBar_Item_07", "Detecting Android..."))
		If $g_asCmdLine[0] < 2 And Not $bConfigRead Then
			DetectRunningAndroid()
			If Not $g_bFoundRunningAndroid Then DetectInstalledAndroid()
		EndIf

	Else

		; just increase step
		SplashStep($s)

	EndIf

	CleanSecureFiles()

	GetCOCDistributors() ; load of distributors to prevent rare bot freeze during boot

EndFunc   ;==>InitializeAndroid

; #FUNCTION# ====================================================================================================================
; Name ..........: SetupProfileFolder
; Description ...: Populate profile-related globals
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func SetupProfileFolder()
	SetDebugLog("SetupProfileFolder: " & $g_sProfilePath & "\" & $g_sProfileCurrentName)
	$g_sProfileConfigPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\config.ini"
	$g_sProfileClanGamesPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\ClanGames_config.ini" ; Team__AiO__MOD
	$g_sProfileBuildingStatsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\stats_buildings.ini"
	$g_sProfileBuildingPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\building.ini"
	$g_sProfileLogsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Logs\"
	$g_sProfileLootsPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Loots\"
	$g_sProfileTempPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp\"
	$g_sProfileTempDebugPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp\Debug\"
	$g_sProfileDonateCapturePath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\'
	$g_sProfileDonateCaptureWhitelistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\White List\'
	$g_sProfileDonateCaptureBlacklistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\Black List\'
	$g_sProfileTempDebugDOCRPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp\Debug\DOCR\"
EndFunc   ;==>SetupProfileFolder

; #FUNCTION# ====================================================================================================================
; Name ..........: InitializeMBR
; Description ...: MBR setup routine
; Syntax ........:
; Parameters ....: $sAI - populated with AndroidInfo string in this function
;                  $bConfigRead - if config was already read and Android Emulator info loaded
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func InitializeMBR(ByRef $sAI, $bConfigRead)

	; license
	If Not FileExists(@ScriptDir & "\License.txt") Then
		Local $hDownload = InetGet("http://www.gnu.org/licenses/gpl-3.0.txt", @ScriptDir & "\License.txt")

		; Wait for the download to complete by monitoring when the 2nd index value of InetGetInfo returns True.
		Local $i = 0
		Do
			Sleep($DELAYDOWNLOADLICENSE)
			$i += 1
		Until InetGetInfo($hDownload, $INET_DOWNLOADCOMPLETE) Or $i > 25

		InetClose($hDownload)
	EndIf

	; multilanguage
	If Not FileExists(@ScriptDir & "\Languages") Then DirCreate(@ScriptDir & "\Languages")
	;DetectLanguage()
	_ReadFullIni()
	; must be called after language is detected
	TranslateTroopNames()
	InitializeCOCDistributors()

	; check for compiled x64 version
	Local $sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Compile_Script", "Don't Run/Compile the Script as (x64)! Try to Run/Compile the Script as (x86) to get the bot to work.\r\n" & _
			"If this message still appears, try to re-install AutoIt.")
	If @AutoItX64 = 1 Then
		DestroySplashScreen()
		MsgBox(0, "", $sMsg)
		__GDIPlus_Shutdown()
		Exit
	EndIf

	; Initialize Android emulator
	InitializeAndroid($bConfigRead)

	; Update Bot title
	UpdateBotTitle()
	UpdateSplashTitle($g_sBotTitle & GetTranslatedFileIni("MBR GUI Design - Loading", "Loading_Profile", ", Profile: %s", $g_sProfileCurrentName))

	If $g_bBotLaunchOption_Restart = True Then
		If CloseRunningBot($g_sBotTitle, True) Then
			SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "Closing_previous", "Closing previous bot..."), False)
			If CloseRunningBot($g_sBotTitle) = True Then
				; wait for Mutexes to get disposed
				Sleep(3000)
				; check if Android is running
				WinGetAndroidHandle()
			EndIf
		EndIf
	EndIf

	Local $cmdLineHelp = GetTranslatedFileIni("MBR GUI Design - Loading", "Commandline_multiple_Bots", "By using the commandline (or a shortcut) you can start multiple Bots:\r\n" & _
			"     MyBot.run.exe [ProfileName] [EmulatorName] [InstanceName]\r\n\r\n" & _
			"With the first command line parameter, specify the Profilename (you can create profiles on the Bot/Profiles tab, if a " & _
			"profilename contains a {space}, then enclose the profilename in double quotes). " & _
			"With the second, specify the name of the Emulator and with the third, an Android Instance (not for BlueStacks). \r\n" & _
			"Supported Emulators are MEmu, Nox, BlueStacks2, BlueStacks and iTools.\r\n\r\n" & _
			"Examples:\r\n" & _
			"     MyBot.run.exe MyVillage BlueStacks2\r\n" & _
			"     MyBot.run.exe ""My Second Village"" MEmu MEmu_1")

	$g_hMutex_BotTitle = CreateMutex($g_sBotTitle)
	$sAI = GetTranslatedFileIni("MBR GUI Design - Loading", "Android_instance_01", "%s", $g_sAndroidEmulator)
	Local $sAndroidInfo2 = GetTranslatedFileIni("MBR GUI Design - Loading", "Android_instance_02", "%s (instance %s)", $g_sAndroidEmulator, $g_sAndroidInstance)
	If $g_sAndroidInstance <> "" Then
		$sAI = $sAndroidInfo2
	EndIf

	; Check if we are already running for this instance
	$sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_01", "My Bot for %s is already running.\r\n\r\n", $sAI)
	If $g_hMutex_BotTitle = 0 Then
		SetDebugLog($g_sBotTitle & " is already running, exit now")
		DestroySplashScreen()
		MsgBox(BitOR($MB_OK, $MB_ICONINFORMATION, $MB_TOPMOST), $g_sBotTitle, $sMsg & $cmdLineHelp)
		__GDIPlus_Shutdown()
		Exit
	EndIf

	$sMsg = GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_02", "My Bot with Profile %s is already in use.\r\n\r\n", $g_sProfileCurrentName)
	; Check if we are already running for this profile
	If aquireProfileMutex() = 0 Then
		ReleaseMutex($g_hMutex_BotTitle)
		releaseProfilesMutex(True)
		DestroySplashScreen()
		MsgBox(BitOR($MB_OK, $MB_ICONINFORMATION, $MB_TOPMOST), $g_sBotTitle, $sMsg & $cmdLineHelp)
		__GDIPlus_Shutdown()
		Exit
	EndIf

	; Get mutex
	$g_hMutex_MyBot = CreateMutex("MyBot.run")
	$g_bOnlyInstance = $g_hMutex_MyBot <> 0 ; And False
	SetDebugLog("My Bot is " & ($g_bOnlyInstance ? "" : "not ") & "the only running instance")

EndFunc   ;==>InitializeMBR

; #FUNCTION# ====================================================================================================================
; Name ..........: SetupFilesAndFolders
; Description ...: Checks for presence of needed files and folders, cleans up and creates as required
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func SetupFilesAndFolders()

	;Migrate old shared_prefs locations
	Local $sOldProfiles = @MyDocumentsDir & "\MyBot.run-Profiles"
	If FileExists($sOldProfiles) = 1 And FileExists($g_sPrivateProfilePath) = 0 Then
		SetLog("Moving shared_prefs profiles folder")
		If DirMove($sOldProfiles, $g_sPrivateProfilePath) = 0 Then
			SetLog("Error moving folder " & $sOldProfiles, $COLOR_ERROR)
			SetLog("to new location " & $g_sPrivateProfilePath, $COLOR_ERROR)
			SetLog("Please resolve manually!", $COLOR_ERROR)
		Else
			SetLog("Moved shared_prefs profiles to " & $g_sPrivateProfilePath, $COLOR_SUCCESS)
		EndIf
	EndIf

	;DirCreate($sTemplates)
	DirCreate($g_sProfilePresetPath)
	DirCreate($g_sPrivateProfilePath & "\" & $g_sProfileCurrentName)
	DirCreate($g_sProfilePath & "\" & $g_sProfileCurrentName)
	DirCreate($g_sProfileLogsPath)
	DirCreate($g_sProfileLootsPath)
	DirCreate($g_sProfileTempPath)
	DirCreate($g_sProfileTempDebugPath)
	DirCreate($g_sProfileTempDebugDOCRPath) ; Dissociable - Team AIO Mod++

	$g_sProfileDonateCapturePath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\'
	$g_sProfileDonateCaptureWhitelistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\White List\'
	$g_sProfileDonateCaptureBlacklistPath = $g_sProfilePath & "\" & $g_sProfileCurrentName & '\Donate\Black List\'
	DirCreate($g_sProfileDonateCapturePath)
	DirCreate($g_sProfileDonateCaptureWhitelistPath)
	DirCreate($g_sProfileDonateCaptureBlacklistPath)

	;Migrate old bot without profile support to current one
	FileMove(@ScriptDir & "\*.ini", $g_sProfilePath & "\" & $g_sProfileCurrentName, $FC_OVERWRITE + $FC_CREATEPATH)
	DirCopy(@ScriptDir & "\Logs", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Logs", $FC_OVERWRITE + $FC_CREATEPATH)
	DirCopy(@ScriptDir & "\Loots", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Loots", $FC_OVERWRITE + $FC_CREATEPATH)
	DirCopy(@ScriptDir & "\Temp", $g_sProfilePath & "\" & $g_sProfileCurrentName & "\Temp", $FC_OVERWRITE + $FC_CREATEPATH)
	DirRemove(@ScriptDir & "\Logs", 1)
	DirRemove(@ScriptDir & "\Loots", 1)
	DirRemove(@ScriptDir & "\Temp", 1)

	;Setup profile if doesn't exist yet
	If FileExists($g_sProfileConfigPath) = 0 Then
		createProfile(True)
		applyConfig()
	EndIf

	If $g_bDeleteLogs Then DeleteFiles($g_sProfileLogsPath, "*.*", $g_iDeleteLogsDays, 0)
	If $g_bDeleteLoots Then DeleteFiles($g_sProfileLootsPath, "*.*", $g_iDeleteLootsDays, 0)
	If $g_bDeleteTemp Then
		DeleteFiles($g_sProfileTempPath, "*.*", $g_iDeleteTempDays, 0)
		DeleteFiles($g_sProfileTempDebugPath, "*.*", $g_iDeleteTempDays, 0, $FLTAR_RECUR)
	EndIf

	If $g_bDebugSetlog Then
		SetDebugLog("$g_sProfilePath = " & $g_sProfilePath)
		SetDebugLog("$g_sProfileCurrentName = " & $g_sProfileCurrentName)
		SetDebugLog("$g_sProfileLogsPath = " & $g_sProfileLogsPath)
	EndIf
EndFunc   ;==>SetupFilesAndFolders

; #FUNCTION# ====================================================================================================================
; Name ..........: FinalInitialization
; Description ...: Finalize various setup requirements
; Syntax ........:
; Parameters ....: $sAI: AndroidInfo for displaying in the log
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func FinalInitialization(Const $sAI)
	; check for VC2010, .NET software and MyBot Files and Folders
	Local $bCheckPrerequisitesOK = CheckPrerequisites(True)
	If $bCheckPrerequisitesOK Then
		MBRFunc(True) ; start MyBot.run.dll, after this point .net is initialized and threads popup all the time
		DissociableFunc(True)
		setAndroidPID() ; set Android PID
		SetBotGuiPID() ; set GUI PID
	EndIf

	If $g_bFoundRunningAndroid Then
		SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_03", "Found running %s %s", $g_sAndroidEmulator, $g_sAndroidVersion), $COLOR_SUCCESS)
	EndIf
	If $g_bFoundInstalledAndroid Then
		SetLog("Found installed " & $g_sAndroidEmulator & " " & $g_sAndroidVersion, $COLOR_SUCCESS)
	EndIf
	SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_04", "Android Emulator Configuration: %s", $sAI), $COLOR_SUCCESS)

	; reset GUI to wait for remote GUI in no GUI mode
	$g_iGuiPID = @AutoItPID

	; Remember time in Milliseconds bot launched
	$g_iBotLaunchTime = __TimerDiff($g_hBotLaunchTime)

	; wait for remote GUI to show when no GUI in this process
	If $g_iGuiMode = 0 Then
		SplashStep(GetTranslatedFileIni("MBR GUI Design - Loading", "Waiting_for_Remote_GUI", "Waiting for remote GUI..."))
		SetDebugLog("Wait for GUI Process...")

		Local $timer = __TimerInit()
		While $g_iGuiPID = @AutoItPID And __TimerDiff($timer) < 60000
			; wait for GUI Process updating $g_iGuiPID
			Sleep(50) ; must be Sleep as no run state!
		WEnd
		If $g_iGuiPID = @AutoItPID Then
			SetDebugLog("GUI Process not received, close bot")
			BotClose()
			$bCheckPrerequisitesOK = False
		Else
			SetDebugLog("Linked to GUI Process " & $g_iGuiPID)
		EndIf
	EndIf

	Local $aBotGitVersion = CheckModVersion(True) ; Update check without delay - Team AIO Mod++ - Must be Before Official CheckVersion()

	; destroy splash screen here (so we witness the 100% ;)
	DestroySplashScreen(False)
	If $bCheckPrerequisitesOK Then
		; only when bot can run, register with forum
		ForumAuthentication()
	EndIf

	; allow now other bots to launch
	DestroySplashScreen()

	#Region - Update check without delay - Team AIO Mod++
	If IsArray($aBotGitVersion) And UBound($aBotGitVersion) = 2 Then
		SetLog(" ")
		SetLog(" •  " & "AIO++ MOD " & $g_sModVersion, ($aBotGitVersion[1] = False) ? ($COLOR_SUCCESS) : ($COLOR_ERROR))
		SetLog(" •  " & "AIO++ MOD LAST VERSION " & $aBotGitVersion[0], ($aBotGitVersion[1] = False) ? ($COLOR_SUCCESS) : ($COLOR_ERROR))
		SetLog(" •  " & "Based On MBR " & $g_sBotVersion, $COLOR_INFO)
		SetLog(" •  " & "Create a New Profile", $COLOR_INFO)
		SetLog(" •  " & "AIO++ Gang : @vDragon, @Eloy, @Approchable-123, @Boldina, @Dissociable.", $COLOR_INFO)
		SetLog(" •  " & "Special Thanks: Nguyen, xbebenk, Chilly-Chill,", $COLOR_INFO)
		SetLog(" •  " & "Demen, Samkie, and ChacalGyn, all moders and MyBot/AIO++ Team.", $COLOR_INFO)
		SetLog(" ")
	EndIf
	#EndRegion - Update check without delay - Team AIO Mod++

	; InitializeVariables();initialize variables used in extrawindows
	CheckVersion() ; check latest version on mybot.run site
	UpdateMultiStats()
	If $g_bDebugSetlog Then
		SetDebugLog("Maximum of " & $g_iGlobalActiveBotsAllowed & " bots running at same time configured")
		SetDebugLog("MyBot.run launch time " & Round($g_iBotLaunchTime) & " ms.")
	EndIf

	If $g_bAndroidShieldEnabled = False Then
		SetLog(GetTranslatedFileIni("MBR GUI Design - Loading", "Msg_Android_instance_05", "Android Shield not available for %s", @OSVersion), $COLOR_ACTION)
	EndIf

	DisableProcessWindowsGhosting()

	UpdateMainGUI()

EndFunc   ;==>FinalInitialization

; #FUNCTION# ====================================================================================================================
; Name ..........: MainLoop
; Description ...: Main application loop
; Syntax ........:
; Parameters ....: None
; Return values .: None
; Author ........:
; Modified ......: CodeSlinger69 (2017)
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2017
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================
Func MainLoop($bCheckPrerequisitesOK = True)
	Local $iStartDelay = 0

	If $bCheckPrerequisitesOK And ($g_bAutoStart Or $g_bRestarted) Then
		Local $iDelay = $g_iAutoStartDelay
		If $g_bRestarted Then $iDelay = 0
		$iStartDelay = $iDelay * 1000
		$g_iBotAction = $eBotStart
		; check if android should be hidden
		If $g_bBotLaunchOption_HideAndroid Then $g_bIsHidden = True
		; check if bot should be minimized
		If $g_bBotLaunchOption_MinimizeBot Then BotMinimizeRequest()
	EndIf

	Local $hStarttime = _Timer_Init()

	; Check the Supported Emulator versions
	CheckEmuNewVersions()

	;Reset Telegram message
	NotifyGetLastMessageFromTelegram()
	$g_iTGLastRemote = $g_sTGLast_UID

	;the message maybe failed, not try again because efficiency
	NotifyRemoteBotisOnline()

	While 1
		_Sleep($DELAYSLEEP, True, False)

		Local $diffhStarttime = _Timer_Diff($hStarttime)

		If Not $g_bRunState And $g_bNotifyTGEnable And $g_bNotifyRemoteEnable And $diffhStarttime > 1000 * 15 Then ; 15seconds
			$hStarttime = _Timer_Init()
			NotifyRemoteControlProcBtnStart()
		EndIf

		Switch $g_iBotAction
			Case $eBotStart
				BotStart($iStartDelay)
				$iStartDelay = 0 ; don't autostart delay in future
				If $g_iBotAction = $eBotStart Then $g_iBotAction = $eBotNoAction

				; test error handling when bot started and then stopped
				; force app crash for debugging/testing purposes
				;DllCallAddress("NONE", 0)
				; force au3 script error for debugging/testing purposes
				;Local $iTmp = $iStartDelay[0]

			Case $eBotStop
				BotStop()
				If $g_iBotAction = $eBotStop Then $g_iBotAction = $eBotNoAction
				; Reset Telegram message
				$g_iTGLastRemote = $g_sTGLast_UID
			Case $eBotSearchMode
				BotSearchMode()
				If $g_iBotAction = $eBotSearchMode Then $g_iBotAction = $eBotNoAction
			Case $eBotClose
				BotClose()
		EndSwitch

	WEnd
EndFunc   ;==>MainLoop

Func runBot() ;Bot that runs everything in order
	Local $iWaitTime

	InitiateSwitchAcc()
	If ProfileSwitchAccountEnabled() And $g_bReMatchAcc Then
		SetLog("Rematching Account [" & $g_iNextAccount + 1 & "] with Profile [" & GUICtrlRead($g_ahCmbProfile[$g_iNextAccount]) & "]")
		SwitchCoCAcc($g_iNextAccount)
	EndIf

	If Not $g_bRunState Then Return
	If $g_bOnlyBuilderBase Then
		If isOnBuilderBase() Then SwitchBetweenBases()
		_ClanGames()
		SetLog("Let's play builder base only.")
		BuilderBase()
	Else
		FirstCheck()
	EndIf

	While 1
		; Custom - Team AIO Mod++
		If FileExists(@ScriptDir & "\EnableMBRDebug.txt") Then
			While (FileReadLine(@ScriptDir & "\EnableMBRDebug.txt") = "wait")
				If _SleepStatus(15000) Then Return
				If Not $g_bRunState Then Return
			WEnd
		EndIf

		;Restart bot after these seconds
		If $b_iAutoRestartDelay > 0 And __TimerDiff($g_hBotLaunchTime) > $b_iAutoRestartDelay * 1000 Then
			If RestartBot(False) Then Return
		EndIf

		PrepareDonateCC()
		If Not $g_bRunState Then Return
		$g_bRestart = False
		$g_bFullArmy = False
		$g_bIsFullArmywithHeroesAndSpells = False
		; Custom BB - Team AIO Mod++
		If $g_iCommandStop <> 8 Then $g_iCommandStop = -1
		If _Sleep($DELAYRUNBOT1) Then Return
		; Just in case of new profile! or BotDetectFirstTime() failed on Initiate()
		BotDetectFirstTime()
		If $g_bRestart Then ContinueLoop
		chkShieldStatus()
		If Not $g_bRunState Then Return
		If $g_bRestart Then ContinueLoop
		checkObstacles() ; trap common error messages also check for reconnecting animation
		If $g_bRestart Then ContinueLoop

		; Custom BB - Team AIO Mod++
		If isOnBuilderBase() Then SwitchBetweenBases()
		_ClanGames()

		If PlayBBOnly() Then
			SetLog("Let's play builder base only.")
			BuilderBase()
			If ProfileSwitchAccountEnabled() Then
				checkSwitchAcc() ; Forced to switch
			EndIf
			ContinueLoop
		EndIf

		#Region - GTFO - Team AIO Mod++
		If $g_bChkOnlyFarm = False Then
			MainGTFO()
			MainKickout()
		EndIf
		#EndRegion - GTFO - Team AIO Mod++

		If CheckAndroidReboot() Then ContinueLoop
		If Not $g_bIsClientSyncError Then ;ARCH:  was " And Not $g_bIsSearchLimit"
			SetDebugLog("ARCH: Top of loop", $COLOR_DEBUG)
			If $g_bIsSearchLimit Then SetLog("Search limit hit", $COLOR_INFO)
			checkMainScreen(False)
			If $g_bRestart Then ContinueLoop
			If _Sleep($DELAYRUNBOT3) Then Return
			VillageReport()
			CheckStopForWar() ; War Preparation - Team AIO Mod++
			ProfileSwitch()  ;  Team AIO Mod++
			CheckFarmSchedule()  ;  Team AIO Mod++
			If _Sleep($DELAYRUNBOT2) Then Return

			; AIO
			If botcommand() Then
				If $g_ifreebuildercount - ($g_bautoupgradewallsenable And $g_bupgradewallsavebuilder ? 1 : 0) - ReservedBuildersForHeroes() <= 0 Then
					SetLog("Lets use the Free Builders before check Halt Status!")
					_RunFunction("UpgradeAll")
					villagereport()
					If botcommand() Then btnstop()
				EndIf
			EndIf

			If Not $g_bRunState Then Return
			If $g_bOutOfGold And (Number($g_aiCurrentLoot[$eLootGold]) >= Number($g_iTxtRestartGold)) Then ; check if enough gold to begin searching again
				$g_bOutOfGold = False ; reset out of gold flag
				SetLog("Switching back to normal after no gold to search ...", $COLOR_SUCCESS)
				ContinueLoop ; Restart bot loop to reset $g_iCommandStop & $g_bTrainEnabled + $g_bDonationEnabled via BotCommand()
			EndIf
			If $g_bOutOfElixir And (Number($g_aiCurrentLoot[$eLootElixir]) >= Number($g_iTxtRestartElixir)) And (Number($g_aiCurrentLoot[$eLootDarkElixir]) >= Number($g_iTxtRestartDark)) Then ; check if enough elixir to begin searching again
				$g_bOutOfElixir = False ; reset out of elixir flag
				SetLog("Switching back to normal setting after no elixir to train ...", $COLOR_SUCCESS)
				ContinueLoop ; Restart bot loop to reset $g_iCommandStop & $g_bTrainEnabled + $g_bDonationEnabled via BotCommand()
			EndIf
			If _Sleep($DELAYRUNBOT5) Then Return
			checkMainScreen(False)
			If $g_bRestart Then ContinueLoop

			#Region - Request Early - Team AIO Mod++
			$g_bCanRequestCC = True
			If $g_bChkReqCCFirst Then RequestCCMain()
			#EndRegion - Request Early - Team AIO Mod++

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;Local $aRndFuncList = ['LabCheck', 'Collect', 'CheckTombs', 'CleanYard', 'CollectAchievements', 'CollectFreeMagicItems', 'DailyChallenge']
			If $g_bIsSearchLimit Or $g_bChkOnlyFarm Then
				Local $aRndFuncList = ['Collect', 'PetCheck']
			Else
				Local $aRndFuncList = ['Collect', 'CheckTombs', 'CleanYard', 'CollectAchievements', 'CollectFreeMagicItems', 'DailyChallenge', 'PetCheck', "ChatActions", "BotHumanization"] ; AIO Mod
			EndIf

			_ArrayShuffle($aRndFuncList)
			For $Index In $aRndFuncList
				If Not $g_bRunState Then Return
				_RunFunction($Index)
				If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
			Next
			villagereport(True, True)

			Local $iavailbldr = $g_ifreebuildercount - ($g_bautoupgradewallsenable And $g_bupgradewallsavebuilder ? 1 : 0)
			Local $reserved4heroes = ReservedBuildersForHeroes()

			If Int($iavailbldr) > 0 Then
				If ($g_iCommandStop = 0 Or $g_iCommandStop = 3) And profileswitchaccountenabled() And Not $g_abdonateonly[$g_icuraccount] Then
					If Int($reserved4heroes) > 0 Then
						Local $aRndFuncList = ["Laboratory", "UpgradeAll", "PetHouse"]
					Else
						Local $aRndFuncList = ["Laboratory", "UpgradeHeroes", "UpgradeBuilding", "PetHouse", "AutoUpgrade"]
					EndIf
					_ArrayShuffle($aRndFuncList)
					For $Index In $aRndFuncList
						If Not $g_bRunState Then Return
						_RunFunction($Index)
						If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
						If CheckAndroidReboot() Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
					Next
				EndIf
			EndIf

			If ($g_iCommandStop = 0 Or $g_iCommandStop = 3) And profileswitchaccountenabled() And Not $g_abdonateonly[$g_icuraccount] Then
				If $g_bChkOnlyFarm = False And $g_bautoupgradewallsenable And $g_bupgradewallsavebuilder Then
					_RunFunction("upgradewall")
					villagereport()
					$g_iCommandStop = -1
					If botcommand() Then
						If $g_ifreebuildercount - ($g_bautoupgradewallsenable And $g_bupgradewallsavebuilder ? 1 : 0) - ReservedBuildersForHeroes() <= 0 Then
							SetLog("Lets use the Free Builders before check Halt Status!")
							_RunFunction("UpgradeAll")
							villagereport()
							If botcommand() Then btnstop()
						EndIf
					EndIf
				EndIf
				checkswitchacc()
			EndIf
			;=================??????????????????????????????

			If Not $g_bChkOnlyFarm Then AddIdleTime() ; AIO Mod
			If Not $g_bRunState Then Return
			If $g_bRestart Then ContinueLoop
			If IsSearchAttackEnabled() Then ; if attack is disabled skip reporting, requesting, donating, training, and boosting
				If $g_bIsSearchLimit Or $g_bChkOnlyFarm Then
					Local $aRndFuncList = ['DonateCC,Train']
				Else
					Local $aRndFuncList = ['ReplayShare', 'NotifyReport', 'DonateCC,Train', 'RequestCC']
				EndIf
				_ArrayShuffle($aRndFuncList)
				For $Index In $aRndFuncList
					If Not $g_bRunState Then Return
					_RunFunction($Index)
					If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
					If CheckAndroidReboot() Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
				Next

				OneGemBoost() ; One gem boost - Team AIO Mod++
				If $g_bRestart Then ContinueLoop

				BoostEverything() ; 1st Check if is to use Training Potion
				If $g_bRestart Then ContinueLoop
				Local $aRndFuncList = ['BoostBarracks', 'BoostSpellFactory', 'BoostWorkshop', 'BoostKing', 'BoostQueen', 'BoostWarden', 'BoostChampion']
				_ArrayShuffle($aRndFuncList)
				For $Index In $aRndFuncList
					If Not $g_bRunState Then Return
					_RunFunction($Index)
					If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
					If CheckAndroidReboot() Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
				Next

				If Not $g_bRunState Then Return
				If $g_iUnbrkMode >= 1 Then
					If Unbreakable() Then ContinueLoop
					MainSXHandler() ; SuperXP / GoblinXP - Team AiO MOD++
				EndIf
				If $g_bRestart Then ContinueLoop
			Else
				BuilderBase()
				SetLog("Attacking Not Planned, Skipped.", $COLOR_WARNING)
				If ProfileSwitchAccountEnabled() Then
					$g_iCommandStop = 2
					checkSwitchAcc()
				EndIf
			EndIf
			; Train Donate only - force a donate cc every time
			If ($g_iCommandStop = 3 Or $g_iCommandStop = 0) Then _RunFunction('DonateCC,Train')
			If $g_bRestart Then ContinueLoop

			If $g_bChkOnlyFarm = False Then MainSXHandler() ; Super XP - Team AIO Mod++
			If Not $g_bChkOnlyFarm Or (isGoldFull() And isElixirFull()) Then
				If (isGoldFull() And isElixirFull()) And $g_bChkOnlyFarm Then SetLog("Only Farm but Resources Full, checking improvements.", $COLOR_INFO)
				Local $aRndFuncList = ["Laboratory", "UpgradeHeroes", "UpgradeBuilding", "PetHouse", "AutoUpgrade"]
				_ArrayShuffle($aRndFuncList)
				For $Index In $aRndFuncList
					If Not $g_bRunState Then Return
					_RunFunction($Index)
					If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
					If CheckAndroidReboot() Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
				Next
			EndIf

			;ARCH Trying it out here.
			If Not $g_bIsSearchLimit Then _ClanGames() ; move to here to pick event before going to BB.

			; Ensure, that wall upgrade is last of the upgrades

			If Not $g_bChkOnlyFarm Or (isGoldFull() And isElixirFull()) Then
				Local $aRndFuncList = ['UpgradeWall', 'BuilderBase'] ;Copied BuilderBase to AttackMain
				_ArrayShuffle($aRndFuncList)
				For $Index In $aRndFuncList
					If Not $g_bRunState Then Return
					_RunFunction($Index)
					If $g_bRestart Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
					If CheckAndroidReboot() Then ContinueLoop 2 ; must be level 2 due to loop-in-loop
				Next
				If Not $g_bRunState Then Return
			ElseIf (isGoldFull() And isElixirFull()) And $g_bChkOnlyFarm Then
				SetLog("Only Farm but resources full, checking walls.", $COLOR_INFO)
				_RunFunction('UpgradeWall')
			EndIf

			If $g_bFirstStart Then SetDebugLog("First loop completed!")

			$g_bFirstStart = False ; already finished first loop since bot started.
			If $g_bRunState = False Then Return

			If ProfileSwitchAccountEnabled() And ($g_iCommandStop = 0 Or $g_iCommandStop = 3 Or $g_abDonateOnly[$g_iCurAccount] Or $g_bForceSwitch) Then checkSwitchAcc()
			If IsSearchAttackEnabled() Then ; If attack scheduled has attack disabled now, stop wall upgrades, and attack.
				Idle()
				;$g_bFullArmy1 = $g_bFullArmy
				If _Sleep($DELAYRUNBOT3) Then Return
				If $g_bRestart = True Then ContinueLoop

				If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
					AttackMain()
					$g_bSkipFirstZoomout = False
					If $g_bOutOfGold Then
						SetLog("Switching to Halt Attack, Stay Online/Collect mode ...", $COLOR_ERROR)
						ContinueLoop
					EndIf
					If _Sleep($DELAYRUNBOT1) Then Return
					If $g_bRestart = True Then ContinueLoop
				EndIf
			Else
				If ProfileSwitchAccountEnabled() Then
					$g_iCommandStop = 2
					_RunFunction('DonateCC,Train')
					checkSwitchAcc()
				ElseIf Not $g_bChkOnlyFarm Then
					$iWaitTime = Random($DELAYWAITATTACK1, $DELAYWAITATTACK2)
					SetLog("Attacking Not Planned and Skipped, Waiting random " & StringFormat("%0.1f", $iWaitTime / 1000) & " Seconds", $COLOR_WARNING)
					If _SleepStatus($iWaitTime) Then Return False
				EndIf
			EndIf
		Else ;When error occurs directly goes to attack
			Local $sRestartText = $g_bIsSearchLimit ? " due search limit" : " after Out of Sync Error: Attack Now"
			SetLog("Restarted" & $sRestartText, $COLOR_INFO)
			;Use "CheckDonateOften" setting to run loop on hitting SearchLimit
			If $g_bIsSearchLimit And $g_bCheckDonateOften Then
				SetDebugLog("ARCH: Clearing booleans", $COLOR_DEBUG)
				$g_bIsClientSyncError = False
				$g_bRestart = False
			EndIf
			If _Sleep($DELAYRUNBOT3) Then Return
			;  OCR read current Village Trophies when OOS restart maybe due PB or else DropTrophy skips one attack cycle after OOS
			$g_aiCurrentLoot[$eLootTrophy] = Number(getTrophyMainScreen($aTrophies[0], $aTrophies[1]))
			If $g_bDebugSetlog Then SetDebugLog("Runbot Trophy Count: " & $g_aiCurrentLoot[$eLootTrophy], $COLOR_DEBUG)
			If Not $g_bIsSearchLimit Or Not $g_bCheckDonateOften Then AttackMain() ;If Search Limit hit, do main loop.
			SetDebugLog("ARCH: Not case on SearchLimit or CheckDonateOften", $COLOR_DEBUG)
			If Not $g_bRunState Then Return
			$g_bSkipFirstZoomout = False
			If $g_bOutOfGold Then
				SetLog("Switching to Halt Attack, Stay Online/Collect mode ...", $COLOR_ERROR)
				$g_bFirstStart = True
				$g_bIsClientSyncError = False ; reset fast restart flag to stop OOS mode and start collecting resources
				ContinueLoop
			EndIf
			If _Sleep($DELAYRUNBOT5) Then Return
			If $g_bRestart = True Then ContinueLoop
		EndIf
	WEnd
EndFunc   ;==>runBot

Func Idle() ;Sequence that runs until Full Army
	$g_bIdleState = True
	Local $Result = _Idle()
	$g_bIdleState = False
	Return $Result
EndFunc   ;==>Idle

Func _Idle() ;Sequence that runs until Full Army
	Local $TimeIdle = 0 ;In Seconds
	SetDebugLog("Func Idle ", $COLOR_DEBUG)

	While $g_bIsFullArmywithHeroesAndSpells = False

		CheckAndroidReboot()

		;Execute Notify Pending Actions
		NotifyPendingActions()
		If _Sleep($DELAYIDLE1) Then Return
		If $g_iCommandStop = -1 Then SetLog("====== Waiting for full army ======", $COLOR_SUCCESS)
		Local $hTimer = __TimerInit()
		; If Not $g_bChkOnlyFarm Then BotHumanization() ; Humanization - Team AiO MOD++

		If _Sleep($DELAYIDLE1) Then ExitLoop
		checkObstacles() ; trap common error messages also check for reconnecting animation
		checkMainScreen(False) ; required here due to many possible exits
		If ($g_iCommandStop = 3 Or $g_iCommandStop = 0) And $g_bTrainEnabled = True Then
			CheckArmyCamp(True, True)
			If _Sleep($DELAYIDLE1) Then Return
			If ($g_bIsFullArmywithHeroesAndSpells = False) Then
				SetLog("Army Camp is not full, Training Continues...", $COLOR_ACTION)
				$g_iCommandStop = 0
			EndIf
		EndIf
		If $g_bRestart Then ExitLoop
		If Random(0, $g_iCollectAtCount - 1, 1) = 0 Then ; This is prevent from collecting all the time which isn't needed anyway, chance to run is 1/$g_iCollectAtCount
			Local $aRndFuncList = ['Collect', 'CheckTombs', 'RequestCC', 'DonateCC', 'CleanYard']
			_ArrayShuffle($aRndFuncList)
			For $Index In $aRndFuncList
				If Not $g_bRunState Then Return
				_RunFunction($Index)
				If $g_bRestart Then ExitLoop
				If CheckAndroidReboot() Then ContinueLoop 2
			Next
			If Not $g_bRunState Then Return
			If $g_bRestart Then ExitLoop
			If _Sleep($DELAYIDLE1) Or Not $g_bRunState Then ExitLoop
		ElseIf $g_bCheckDonateOften Then
			_RunFunction('DonateCC')
			If Not $g_bRunState Then Return
			If $g_bRestart Then ExitLoop
			If _Sleep($DELAYIDLE1) Or Not $g_bRunState Then ExitLoop
		EndIf
		If Not $g_bChkOnlyFarm Then AddIdleTime()
		checkMainScreen(False) ; required here due to many possible exits
		If $g_iCommandStop = -1 Then
			If $g_iActualTrainSkip < $g_iMaxTrainSkip Then
				MainSXHandler() ; SuperXP / GoblinXP - Team AiO MOD++
				If CheckNeedOpenTrain($g_sTimeBeforeTrain) Then TrainSystem()
				If $g_bRestart = True Then ExitLoop
				If _Sleep($DELAYIDLE1) Then ExitLoop
				checkMainScreen(False)
				$g_iActualTrainSkip += 1
			Else
				SetLog("Humanize bot, prevent to delete and recreate troops " & $g_iActualTrainSkip + 1 & "/" & $g_iMaxTrainSkip, $color_blue)
				If $g_iActualTrainSkip >= $g_iMaxTrainSkip Then
					$g_iActualTrainSkip = 0
				EndIf
				CheckArmyCamp(True, True)
			EndIf
			If $g_bChkOnlyFarm = False Then MainSXHandler() ; Super XP - Team AIO Mod++
		EndIf
		If _Sleep($DELAYIDLE1) Then Return
		If $g_iCommandStop = 0 And $g_bTrainEnabled Then
			If Not ($g_bIsFullArmywithHeroesAndSpells) Then
				If $g_iActualTrainSkip < $g_iMaxTrainSkip Then
					#Region - Custom train - Team AIO Mod++
					If CheckNeedOpenTrain($g_sTimeBeforeTrain) Or (ProfileSwitchAccountEnabled() And $g_iActiveDonate And $g_bChkDonate) Then
						$g_bForceDoubleTrain = True ; Force double train before switch account.
						TrainSystem() ; force check trainsystem after donate and before switch account
					EndIf
					#EndRegion - Custom train - Team AIO Mod++
					If $g_bRestart Then ExitLoop
					If _Sleep($DELAYIDLE1) Then ExitLoop
					checkMainScreen(False)
					If Not $g_bRunState Then Return
					$g_iActualTrainSkip += 1
				Else
					If $g_iActualTrainSkip >= $g_iMaxTrainSkip Then
						$g_iActualTrainSkip = 0
					EndIf
					CheckArmyCamp(True, True)
					If Not $g_bRunState Then Return
				EndIf
			EndIf
			If $g_bIsFullArmywithHeroesAndSpells And $g_bTrainEnabled Then
				SetLog("Army Camp is full, stop Training", $COLOR_ACTION)
				$g_iCommandStop = 3
			EndIf
		EndIf
		If _Sleep($DELAYIDLE1) Then Return
		If $g_iCommandStop = -1 Then
			DropTrophy()
			If Not $g_bRunState Then Return
			If $g_bRestart Then ExitLoop
			;If $g_bFullArmy Then ExitLoop		; Never will reach to SmartWait4Train() to close coc while Heroes/Spells not ready 'if' Army is full, so better to be commented
			If _Sleep($DELAYIDLE1) Then ExitLoop
			checkMainScreen(False)
		EndIf
		If _Sleep($DELAYIDLE1) Then Return
		If $g_bRestart Then ExitLoop

		$TimeIdle += Round(__TimerDiff($hTimer) / 1000, 2) ;In Seconds
		SetLog("Time Idle: " & StringFormat("%02i", Floor(Floor($TimeIdle / 60) / 60)) & ":" & StringFormat("%02i", Floor(Mod(Floor($TimeIdle / 60), 60))) & ":" & StringFormat("%02i", Floor(Mod($TimeIdle, 60))))

		If $g_bOutOfGold Or $g_bOutOfElixir Then Return ; Halt mode due low resources, only 1 idle loop

		If ($g_iCommandStop = 3 Or $g_iCommandStop = 0) And $g_bTrainEnabled = False Then ExitLoop ; If training is not enabled, run only 1 idle loop

		; If $g_iCommandStop = -1 And $g_bChkOnlyFarm = False Then ; AIO Mod ; Check if closing bot/emulator while training and not in halt mode
		If $g_iCommandStop = -1 Then
			SmartWait4Train()
			If Not $g_bRunState Then Return
			If $g_bRestart Then ExitLoop ; if smart wait activated, exit to runbot in case user adjusted GUI or left emulator/bot in bad state
		EndIf

		; Custom schedule - Team AIO Mod++
		If ProfileSwitchAccountEnabled() Then CheckSwitchAcc()
		ClickAway()
		If IsSearchAttackEnabled() = False Then
			If Not ProfileSwitchAccountEnabled() Then
				$g_iCommandStop = 2
				SetLog("Attacking not planned, skipped.", $COLOR_WARNING)
				checkSwitchAcc() ; Forced to switch when in halt attack mode
			EndIf
			Return
		EndIf
	WEnd
EndFunc   ;==>_Idle

Func AttackMain($bFirstStart = False, $bCheckCG = True) ;Main control for attack functions
	If ProfileSwitchAccountEnabled() And $g_abDonateOnly[$g_iCurAccount] Then Return
	#Region - SuperXP / GoblinXP - Team AiO MOD++
	If $g_bEnableSuperXP = True And $g_iActivateOptionSX = 2 Then
		MainSXHandler()
		Return
	EndIf
	#EndRegion - SuperXP / GoblinXP - Team AiO MOD++
	ClickAway()
	If IsSearchAttackEnabled() Then
		If (IsSearchModeActive($DB) And checkCollectors(True, False)) Or IsSearchModeActive($LB) Then
			If ProfileSwitchAccountEnabled() And ($g_aiAttackedCountSwitch[$g_iCurAccount] <= $g_aiAttackedCountAcc[$g_iCurAccount] - 2) Then checkSwitchAcc()
			If $g_bUseCCBalanced Then ;launch profilereport() only if option balance D/R is activated
				ProfileReport()
				If Not $g_bRunState Then Return
				If _Sleep($DELAYATTACKMAIN1) Then Return
				checkMainScreen(False)
				If $g_bRestart Then Return
			EndIf
			If $g_bDropTrophyEnable And Number($g_aiCurrentLoot[$eLootTrophy]) > Number($g_iDropTrophyMax) Then ;If current trophy above max trophy, try drop first
				If Not $bFirstStart Then
					DropTrophy()
					If Not $g_bRunState Then Return
					$g_bIsClientSyncError = False ; reset OOS flag to prevent looping.
					If _Sleep($DELAYATTACKMAIN1) Then Return
					Return ; return to runbot, refill armycamps
				Else
					SetLog("Drop Trophy Enabled, but skipped on FirstStart", $COLOR_DEBUG)
				EndIf
			EndIf
			If $g_bDebugSetlog Then
				SetDebugLog(_PadStringCenter(" Hero status check" & BitAND($g_aiAttackUseHeroes[$DB], $g_aiSearchHeroWaitEnable[$DB], $g_iHeroAvailable) & "|" & $g_aiSearchHeroWaitEnable[$DB] & "|" & $g_iHeroAvailable, 54, "="), $COLOR_DEBUG)
				SetDebugLog(_PadStringCenter(" Hero status check" & BitAND($g_aiAttackUseHeroes[$LB], $g_aiSearchHeroWaitEnable[$LB], $g_iHeroAvailable) & "|" & $g_aiSearchHeroWaitEnable[$LB] & "|" & $g_iHeroAvailable, 54, "="), $COLOR_DEBUG)
				;SetLog("BullyMode: " & $g_abAttackTypeEnable[$TB] & ", Bully Hero: " & BitAND($g_aiAttackUseHeroes[$g_iAtkTBMode], $g_aiSearchHeroWaitEnable[$g_iAtkTBMode], $g_iHeroAvailable) & "|" & $g_aiSearchHeroWaitEnable[$g_iAtkTBMode] & "|" & $g_iHeroAvailable, $COLOR_DEBUG)
			EndIf

			; Custom BB - Team__AiO__MOD
			If $bCheckCG = True Then
				_ClanGames() ; Trying to do this above in the main loop
				ClickAway(Default, True)
			EndIf

			If $g_bUpdateSharedPrefs Then PullSharedPrefs()
			PrepareSearch()
			If Not $g_bRunState Then Return
			If $g_bOutOfGold Then Return ; Check flag for enough gold to search
			If $g_bRestart Then Return
			VillageSearch()
			If $g_bOutOfGold Then Return ; Check flag for enough gold to search
			If Not $g_bRunState Then Return
			If $g_bRestart Then Return
			PrepareAttack($g_iMatchMode)
			If Not $g_bRunState Then Return
			If $g_bRestart Then Return
			Attack()
			If Not $g_bRunState Then Return
			If $g_bRestart Then Return
			ReturnHome($g_bTakeLootSnapShot)
			If Not $g_bRunState Then Return
			If _Sleep($DELAYATTACKMAIN2) Then Return
			Return True
		Else
			SetLog("None of search condition match:", $COLOR_WARNING)
			SetLog("Search, Trophy or Army Camp % are out of range in search setting", $COLOR_WARNING)
			$g_bIsSearchLimit = False
			$g_bIsClientSyncError = False
			If ProfileSwitchAccountEnabled() Then checkSwitchAcc()
			SmartWait4Train()
		EndIf
	Else
		SetLog("Attacking Not Planned, Skipped..", $COLOR_WARNING)
		If ProfileSwitchAccountEnabled() Then
			$g_iCommandStop = 2
			checkSwitchAcc() ; Forced to switch when in halt attack mode
		EndIf
	EndIf
EndFunc   ;==>AttackMain

Func Attack() ;Selects which algorithm
	$g_bAttackActive = True
	SetLog(" ====== Start Attack ====== ", $COLOR_SUCCESS)
	If ($g_iMatchMode = $DB And $g_aiAttackAlgorithm[$DB] = 1) Or ($g_iMatchMode = $LB And $g_aiAttackAlgorithm[$LB] = 1) Then
		SetDebugLog("start scripted attack", $COLOR_ERROR)
		Algorithm_AttackCSV()
	ElseIf $g_iMatchMode = $DB And $g_aiAttackAlgorithm[$DB] = 2 Then
		SetDebugLog("start smart farm attack", $COLOR_ERROR)
		; Variable to return : $Return[3]  [0] = To attack InSide  [1] = Quant. Sides  [2] = Name Sides
		Local $Nside = ChkSmartFarm()
		If Not $g_bRunState Then Return
		AttackSmartFarm($Nside[1], $Nside[2])
	Else
		SetDebugLog("Start standard attack", $COLOR_ERROR)
		algorithm_AllTroops()
	EndIf
	$g_bAttackActive = False
EndFunc   ;==>Attack

#Region - Custom - Team AIO Mod++
Func _RunFunction($action)
	FuncEnter(_RunFunction)
	; ensure that builder base flag is false
	$g_bStayOnBuilderBase = False
	Local $Result = __RunFunction($action)
	; ensure that builder base flag is false
	$g_bStayOnBuilderBase = False
	Return FuncReturn($Result)
EndFunc   ;==>_RunFunction

Func __RunFunction($sAction)
	SetDebugLog("_RunFunction: " & $sAction & " BEGIN", $COLOR_DEBUG2)
	Switch $sAction
		;;;
		Case "UpgradeHeroes"
			If ($g_icmbboostbarracks = 0 Or $g_bFirstStart) And $g_bChkOnlyFarm = False Then
				If $g_bupgradekingenable Or $g_bupgradequeenenable Or $g_bupgradewardenenable Or $g_bupgradechampionenable Then
					cleanyard()
					upgradeheroes()
				EndIf
			EndIf
		Case "UpgradeAll"
			If ($g_icmbboostbarracks = 0 Or $g_bFirstStart) And $g_bChkOnlyFarm = False Then
				Local $iavailbldr = $g_ifreebuildercount - ($g_bautoupgradewallsenable And $g_bupgradewallsavebuilder ? 1 : 0) - ReservedBuildersForHeroes()
				Local $yes = False
				For $iz = 0 To UBound($g_avbuildingupgrades, 1) - 1
					If $g_abbuildingupgradeenable[$iz] = True Then
						$yes = True
					EndIf
				Next
				If $g_bupgradekingenable Or $g_bupgradequeenenable Or $g_bupgradewardenenable Or $g_bupgradechampionenable Or $g_bAutoUpgradeEnabled Or $yes Then
					cleanyard()
					upgradeheroes()
					autoupgrade(False)
					upgradebuilding()
				EndIf
			EndIf
		Case "AutoUpgrade"
			If ($g_icmbboostbarracks = 0 Or $g_bFirstStart) And $g_bChkOnlyFarm = False Then
				If $g_bAutoUpgradeEnabled Then
					cleanyard()
					autoupgrade(False)
				EndIf
			EndIf
		Case "UpgradeBuilding"
			If ($g_icmbboostbarracks = 0 Or $g_bFirstStart) And $g_bChkOnlyFarm = False Then
				Local $yes = False
				For $iz = 0 To UBound($g_avbuildingupgrades, 1) - 1
					If $g_abbuildingupgradeenable[$iz] = True Then
						$yes = True
					EndIf
				Next
				If $yes Then
					cleanyard()
					upgradebuilding()
				EndIf
			EndIf
			_sleep($delayrunbot3)
			;;;
		Case "Collect"
			Collect()
		Case "CheckTombs"
			CheckTombs()
		Case "CleanYard"
			CleanYard()
		Case "ReplayShare"
			ReplayShare($g_bShareAttackEnableNow)
		Case "NotifyReport"
			NotifyReport()
		Case "DonateCC"
			If $g_iActiveDonate And $g_bChkDonate And Not $g_bChkOnlyFarm Then ; Only farm - Team AIO Mod++
				; if in "Halt/Donate" don't skip near full army
				If (Not SkipDonateNearFullTroops(True) Or $g_iCommandStop = 3 Or $g_iCommandStop = 0) And BalanceDonRec(True) Then DonateCC()
			EndIf
		Case "DonateCC,Train"
			If $g_iActiveDonate And $g_bChkDonate And Not $g_bChkOnlyFarm Then ; Only farm - Team AIO Mod++
				If $g_bFirstStart Then
					getArmyTroopCapacity(True, False)
					If RandomSleep($DELAYRESPOND) Then Return
					getArmySpellCapacity(False, True)
				EndIf
				; if in "Halt/Donate" don't skip near full army
				If (Not SkipDonateNearFullTroops(True) Or $g_iCommandStop = 3 Or $g_iCommandStop = 0) And BalanceDonRec(True) Then DonateCC()

				If Not RandomSleep($DELAYRUNBOT1) Then checkMainScreen(False)
			EndIf
			If $g_bTrainEnabled Then ; check for training enabled in halt mode
				If $g_iActualTrainSkip < $g_iMaxTrainSkip Then
					TrainSystem()
				Else
					SetLog("Humanize bot, prevent to delete and recreate troops " & $g_iActualTrainSkip + 1 & "/" & $g_iMaxTrainSkip, $color_blue)
					$g_iActualTrainSkip = $g_iActualTrainSkip + 1
					If $g_iActualTrainSkip >= $g_iMaxTrainSkip Then
						$g_iActualTrainSkip = 0
					EndIf
					CheckOverviewFullArmy(True, False) ; use true parameter to open train overview window
					If RandomSleep($DELAYRESPOND) Then Return
					getArmySpells()
					If RandomSleep($DELAYRESPOND) Then Return
					getArmyHeroCount(False, True)
				EndIf
			Else
				If $g_bDebugSetlogTrain Then SetLog("Halt mode - training disabled", $COLOR_DEBUG)
			EndIf
		Case "BoostBarracks"
			BoostBarracks()
		Case "BoostSpellFactory"
			BoostSpellFactory()
		Case "BoostWorkshop"
			BoostWorkshop()
		Case "BoostKing"
			BoostKing()
		Case "BoostQueen"
			BoostQueen()
		Case "BoostWarden"
			BoostWarden()
		Case "BoostChampion"
			BoostChampion()
		Case "BoostEverything"
			BoostEverything()
		Case "DailyChallenge"
			DailyChallenges()
			; Case "LabCheck" ; xbebenk
			; LabGuiDisplay()
		Case "PetCheck"
			PetGuiDisplay()
		Case "RequestCC"
			#Region - Request Early - Team AIO Mod++
			If Not $g_bChkReqCCFirst Then RequestCCMain()
			#EndRegion - Request Early - Team AIO Mod++
		Case "Laboratory"
			Laboratory()
			checkMainScreen(False) ; xbebenk
		Case "UpgradeWall"
			$g_iNbrOfWallsUpped = 0
			UpgradeWall()
			; Custom BB - Team AIO Mod++
		Case "BuilderBase"
			Local $bReturn = PlayBBOnly()
			If Not ($g_icmbboostbarracks = 0) And $bReturn = False Then
				SetLog("There are not the conditions for you to play in the constructor base.", $COLOR_INFO)
				; SetLog("- Is first start? " & $g_bFirstStart, $COLOR_INFO)
				Local $bBoost = ($g_icmbboostbarracks = 0) ? (True) : (False)
				SetLog("- Is your army accelerated and would it be a waste? " & $bBoost, $COLOR_INFO)
				Return True
			EndIf
			BuilderBase()
		Case "CollectAchievements"
			CollectAchievements()
		Case "CollectFreeMagicItems"
			CollectMagicItems()
			; BotHumanization - Team AIO Mod++
		Case "BotHumanization"
			BotHumanization()
			; ChatActions - Team AIO Mod++
		Case "ChatActions"
			ChatActions()
		Case "PetHouse"
			PetHouse()
			; One Gem Boost - Team AiO MOD++
		Case "OneGemBoost"
			OneGemBoost()
		Case ""
			SetDebugLog("Function call doesn't support empty string, please review array size", $COLOR_ERROR)
		Case Else
			SetLog("Unknown function call: " & $sAction, $COLOR_ERROR)
	EndSwitch
	SetDebugLog("_RunFunction: " & $sAction & " END", $COLOR_DEBUG2)
EndFunc   ;==>__RunFunction
#EndRegion - Custom - Team AIO Mod++

; xbebenk.
Func FirstCheck()
	; Custom - Team AIO Mod++
	If $g_bChkOnlyFarm = False And $g_bChkSkipFirstAttack = True Then
		Setlog("FirstCheck skipped, SkipFirstAttack enabled.", $COLOR_INFO)
	ElseIf $g_bChkOnlyFarm = True Then
		Setlog("Only farm enabled.", $COLOR_INFO)
	Else
		SetLog("======== FirstCheck ========", $COLOR_ACTION)
	EndIf

	Local $bCheckCG = False
	If $g_bChkClanGamesEnabled Then
		SetLog("Check ClanGames", $COLOR_INFO)
		_ClanGames()
		If ByPassedForceBBAttackOnClanGames(False, True) Then
			SetLog("Forced BB Attack On ClanGames", $COLOR_INFO)
			BuilderBase()
		Else
			$bCheckCG = True
		EndIf
	EndIf
	; /////////////////////////////

	SetDebugLog("-- FirstCheck Loop --")
	If Not $g_bRunState Then Return

	If ProfileSwitchAccountEnabled() And $g_abDonateOnly[$g_iCurAccount] Then Return

	$g_bRestart = False
	$g_bFullArmy = False
	$g_iCommandStop = -1

	#cs - no se va a poner a verificar el nivel justo aca, cambia la logica con aio.
	;;;;;Check Town Hall level
	Local $iTownHallLevel = $g_iTownHallLevel
	SetDebugLog("Detecting Town Hall level", $COLOR_INFO)
	SetDebugLog("Town Hall level is currently saved as " & $g_iTownHallLevel, $COLOR_INFO)
	imglocTHSearch(False, True, True) ;Sets $g_iTownHallLevel
	SetDebugLog("Detected Town Hall level is " & $g_iTownHallLevel, $COLOR_INFO)
	If $g_iTownHallLevel = $iTownHallLevel Then
		SetDebugLog("Town Hall level has not changed", $COLOR_INFO)
	Else
		If $g_iTownHallLevel < $iTownHallLevel Then
			SetDebugLog("Bad town hall level read...saving bigger old value", $COLOR_ERROR)
			$g_iTownHallLevel = $iTownHallLevel
			saveConfig()
			applyConfig()
		Else
			SetDebugLog("Town Hall level has changed!", $COLOR_INFO)
			SetDebugLog("New Town hall level detected as " & $g_iTownHallLevel, $COLOR_INFO)
			saveConfig()
			applyConfig()
		EndIf
	EndIf
	;;;;;;;;;;;;;;;;;;;;;;;;;;
	#Ce

	VillageReport()
	If Not $g_bRunState Then Return

	If $g_bOutOfGold And (Number($g_aiCurrentLoot[$eLootGold]) >= Number($g_iTxtRestartGold)) Then ; check if enough gold to begin searching again
		$g_bOutOfGold = False ; reset out of gold flag
		SetLog("Switching back to normal after no gold to search ...", $COLOR_SUCCESS)
		Return ; Restart bot loop to reset $g_iCommandStop & $g_bTrainEnabled + $g_bDonationEnabled via BotCommand()
	EndIf

	If $g_bOutOfElixir And (Number($g_aiCurrentLoot[$eLootElixir]) >= Number($g_iTxtRestartElixir)) And (Number($g_aiCurrentLoot[$eLootDarkElixir]) >= Number($g_iTxtRestartDark)) Then ; check if enough elixir to begin searching again
		$g_bOutOfElixir = False ; reset out of gold flag
		SetLog("Switching back to normal setting after no elixir to train ...", $COLOR_SUCCESS)
		Return ; Restart bot loop to reset $g_iCommandStop & $g_bTrainEnabled + $g_bDonationEnabled via BotCommand()
	EndIf

	If _Sleep($DELAYRUNBOT5) Then Return
	checkMainScreen(False)
	If $g_bRestart Then Return

	If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
		; VERIFY THE TROOPS AND ATTACK IF IS FULL
		SetDebugLog("-- FirstCheck on Train --")
		TrainSystem()
		If Not $g_bRunState Then Return
		SetDebugLog("Are you ready? " & String($g_bIsFullArmywithHeroesAndSpells))
		If $g_bIsFullArmywithHeroesAndSpells Then
			; Just in case of new profile! or BotDetectFirstTime() failed on Initiate()
			; BotDetectFirstTime() ; justo aca?
			; Now the bot can attack
			If $g_iCommandStop <> 0 And $g_iCommandStop <> 3 Then
				Setlog("Before any other routine let's attack!", $COLOR_INFO)
				If Not $g_bRunState Then Return
				AttackMain(True, $bCheckCG)
				$g_bSkipFirstZoomout = False
				If $g_bOutOfGold Then
					SetLog("Switching to Halt Attack, Stay Online/Collect mode", $COLOR_ERROR)
					$g_bFirstStart = True ; reset First time flag to ensure army balancing when returns to training
					Return
				EndIf
				If _Sleep($DELAYRUNBOT1) Then Return
			EndIf
		Else ;mmmm makes sense...
			OneGemBoost() ; One gem boost - Team AIO Mod++
			If $g_bRestart Then Return
		EndIf
	EndIf
EndFunc   ;==>FirstCheck

Func SetSAtk($attack = False)

	If $attack = True Then
		$g_bTestSceneryAttack = True
	Else
		$g_bTestSceneryAttack = False
	EndIf
EndFunc   ;==>SetSAtk