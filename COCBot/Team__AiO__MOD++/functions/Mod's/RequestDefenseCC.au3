; #FUNCTION# ====================================================================================================================
; Name ..........: RequestDefenseCC.au3
; Description ...: Request defense CC
; Author ........: Demen
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2018
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func IsRequestDefense($bShield = True)
	; Legend trophy protection - Team AIO Mod++
	If $g_bLeagueAttack = True Then Return
	
	Local $bRequestDefense = False
	If $g_bRequestCCDefense Then
		Local $sTime = $g_iCmbRequestCCDefenseWhen ? _DateAdd('n', -(Int($g_iSinglePBForcedEarlyExitTime)), $g_sPBOriginalStartTime) : $g_asShieldStatus[2]
		If Not $g_iCmbRequestCCDefenseWhen And $g_asShieldStatus[0] = "none" Then
			$bRequestDefense = True
			If $bShield Then SetLog("No shield! Request troops for defense", $COLOR_INFO)
		ElseIf _DateIsValid($sTime) Then
			Local $iTime = Int(_DateDiff('n', _NowCalc(), $sTime))
			If $g_bDebugSetlog And $bShield Then SetDebugLog("IsRequestDefense->> $g_iCmbRequestCCDefenseWhen: " & $g_iCmbRequestCCDefenseWhen & " | " & "$sTime: " & $sTime & " | " & "$iTime: " & $iTime)
			If Not $g_iCmbRequestCCDefenseWhen And $g_asShieldStatus[0] = "shield" Then $iTime += 30
			If $bShield Then SetDebugLog(($g_iCmbRequestCCDefenseWhen ? "Personal Break time: " : "Guard time: ") & $sTime & "(" & $iTime & " minutes)")
			If $iTime <= $g_iRequestDefenseTime Then
				If $bShield Then SetLog(($g_iCmbRequestCCDefenseWhen ? "P.Break is about to come!" : "Guard is about to expire!") & " Request troops for defense", $COLOR_INFO)
				$bRequestDefense = True
			EndIf
		EndIf
		
		If $bRequestDefense Then
			If $g_bSaveCCTroopForDefense Then
				For $i = 0 To $g_iModeCount - 1
					If $g_abAttackDropCC[$i] Then $g_abAttackDropCC[$i] = False
				Next
				SetDebugLog("    Disable $g_abAttackDropCC (" & _ArrayToString($g_abAttackDropCC) & ")")
			EndIf
		Else
			If $g_bSaveCCTroopForDefense Then
				IniReadS($g_abAttackDropCC[$DB], $g_sProfileConfigPath, "attack", "DBDropCC", False, "Bool") ; ReadConfig_600_29_DB()
				IniReadS($g_abAttackDropCC[$LB], $g_sProfileConfigPath, "attack", "ABDropCC", False, "Bool") ;ReadConfig_600_29_LB()
				SetDebugLog("    Reloading $g_abAttackDropCC (" & _ArrayToString($g_abAttackDropCC) & ")")
			EndIf
		EndIf
	Else
		If $g_bDebugSetlog And $bShield Then SetDebugLog("IsRequestDefense->> $g_bRequestCCDefense: " & $g_bRequestCCDefense & " | " & "$g_bCanRequestCC: " & $g_bCanRequestCC)
	EndIf
	Return $bRequestDefense
EndFunc   ;==>IsRequestDefense

Func RemoveCCTroopBeforeDefenseRequest()
	If Not $g_bRequestCCDefense Or Not $g_bChkRemoveCCForDefense Then
		SetDebugLog("RemoveCCTroopBeforeDefenseRequest->> $g_bRequestCCDefense: " & $g_bRequestCCDefense & " | " & "$g_bCanRequestCC: " & $g_bCanRequestCC & " | " & "$g_bChkRemoveCCForDefense: " & $g_bChkRemoveCCForDefense)
		Return
	EndIf
	; CC troops
	Local $aTroopsToRemove[5] = [0, 0, 0, 0, 0] ; 5 cc troop slots
	Local $bNeedRemoveTroop = False
	If _ArrayMin($g_aiClanCastleTroopDefType) < $eTroopCount Then     ; avoid 3 slots are set = "any"
		For $i = 0 To 2
			If $g_aiCCDefenseTroopWaitQty[$i] = 0 And $g_aiClanCastleTroopDefType[$i] < $eTroopCount Then $g_aiCCTroopsExpectedForDef[$g_aiClanCastleTroopDefType[$i]] = 40 ; expect troop type only. Do not care about qty
		Next
		SetDebugLog("Getting current available troops in Clan Castle for Defense.")
		Local $aTroopWSlot = getArmyCCTroops(False, False, False, True, True, True) ; X-Coord, Troops name index, Quantity
		If IsArray($aTroopWSlot) Then
			For $i = 0 To $eTroopCount - 1
				Local $iUnwanted = $g_aiCurrentCCTroops[$i] - $g_aiCCTroopsExpectedForDef[$i]
				If $g_aiCurrentCCTroops[$i] > 0 Then SetDebugLog("Expecting " & $g_asTroopNames[$i] & ": " & $g_aiCCTroopsExpectedForDef[$i] & "x. Received: " & $g_aiCurrentCCTroops[$i])
				If $iUnwanted > 0 Then
					For $j = 0 To UBound($aTroopWSlot) - 1
						If $j > 4 Then ExitLoop
						If $aTroopWSlot[$j][1] = $i Then
							$aTroopsToRemove[$j] = _Min($aTroopWSlot[$j][2], $iUnwanted)
							$iUnwanted -= $aTroopsToRemove[$j]
							SetDebugLog(" - To remove: " & $g_asTroopNames[$i] & " " & $aTroopsToRemove[$j] & "x from Slot: " & $j)
						EndIf
					Next
					$bNeedRemoveTroop = True
				EndIf
			Next
		EndIf
	Else
		SetDebugLog("All 3 Combo Box are set to any no need to do anything for defense CC.")
	EndIf

	If $bNeedRemoveTroop Then
		RemoveCastleArmy($aTroopsToRemove)
		If _Sleep(1000) Then Return
	Else
		SetLog("No CC Troops Found To Remove For Defense.", $COLOR_INFO)
	EndIf

EndFunc   ;==>RemoveCCTroopBeforeDefenseRequest

; #FUNCTION# ====================================================================================================================
; Name ..........: -
; Description ...: Request from chat
; Author ........: Boldina (2021)
; Modified ......:
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2021
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func RequestFromChat()
	Local $aReqGem[4] = [98, 695, 0xD7F57F]
	Local $aReqOk[4] = [56, 695, 0xD7F57F]
	Local $aReqGrayedOut[4] = [56, 695, 0xE0E0E0]
	
	Local $bCanRequest = False
	If OpenClanChat() Then
		If _Sleep(3000) Then Return
		
		If _Wait4PixelArray($aChatTab) Then
			_CaptureRegion()
			Select
				Case _ColorCheck(Hex($aReqGem[2], 6), _GetPixelColor($aReqGem[0], $aReqGem[1], False), 25)
					$bCanRequest = False
				Case _ColorCheck(Hex($aReqOk[2], 6), _GetPixelColor($aReqOk[0], $aReqOk[1], False), 25)
					$bCanRequest = True
				Case _ColorCheck(Hex($aReqGrayedOut[2], 6), _GetPixelColor($aReqGrayedOut[0], $aReqGrayedOut[1], False), 25)
					$bCanRequest = False
			EndSelect
			
			If $bCanRequest Then
				SetLog("Requesting Clan Castle reinforcements from chat.", $COLOR_SUCCESS)
				Local $aRequestButtonPos[2] = [$aReqOk[0] - 5, $aReqOk[1] + 5]
				_makerequest($aRequestButtonPos)
				
				If _Wait4PixelGoneArray($aChatTab) Then
					ClickAway("Right", True)
				EndIf
			EndIf
			
		Else
			
			; error here
		EndIf
	Else
		; error here
	EndIf
	
	CloseClanChat()
	
	Return $bCanRequest
EndFunc   ;==>RequestFromChat

Func RequestCCMain()
	If Int($g_iTownHallLevel) < 3 And Int($g_iTownHallLevel) > 0 Then Return
	
	Local $bRequestDefense = IsRequestDefense()
	If (Not $g_bRequestTroopsEnable Or Not $g_bDonationEnabled) And Not $bRequestDefense Then
		Return
	EndIf

	If Not $g_bRunState Then Return

	If $g_bRequestTroopsEnable And Not $bRequestDefense Then ; Check if it's time to request troops for defense (Demen)
		Local $hour = StringSplit(_NowTime(4), ":", $STR_NOCOUNT)
		If Not $g_abRequestCCHours[$hour[0]] Then
			SetLog("Request Clan Castle troops not planned, Skipped..", $COLOR_ACTION)
			Return ; exit func if no planned donate checkmarks
		EndIf
	EndIf

	If _Sleep($DELAYREQUESTCC1) Then Return
	checkAttackDisable($g_iTaBChkIdle) ; Early Take-A-Break detection
	
	Local $bType = False
	For $i = 0 To 2
		If $g_abRequestType[$i] > 0 Then
			$bType = True
			ExitLoop
		EndIf
	Next
	
	Local $bRequestCCByPass = False
	If $g_bChkRequestFromChat = False Then
		$bRequestCCByPass = True
	Else
		If $bRequestDefense = True Then
			If $g_bChkRemoveCCForDefense = True Then
				$bRequestCCByPass = True
			EndIf
		Else
			If $g_bDonationEnabled = True And $bType = True Then
				$bRequestCCByPass = True
			EndIf
		EndIf
	EndIf
	
	If Not $g_bRunState Then Return
	
	If _Sleep(1500) Then Return
	
	If $bRequestCCByPass = True Then
		SetLog("Request from chat impossible.", $COLOR_INFO)
		RequestCC()
	Else
		SetLog("Checking if it is possible to request reinforcements from the chat.", $COLOR_ACTION)
		RequestFromChat()
	EndIf

	If Not $g_bRunState Then Return

	CheckMainScreen(False, False)
EndFunc   ;==>RequestCCMain
