///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Procedure SetSettingValue(TagName, ElementValue) Export
	
	IBBackupServer.SetSettingValue(TagName, ElementValue);
	
EndProcedure

Function NextAutomaticCopyingDate(DeferBackup = False) Export
	
	Settings = IBBackupServer.BackupSettings1();
	
	CurrentDate = CurrentSessionDate();
	
	CopyingSchedule = Settings.CopyingSchedule;
	RepeatPeriodInDay = CopyingSchedule.RepeatPeriodInDay;
	DaysRepeatPeriod = CopyingSchedule.DaysRepeatPeriod;
	
	If DeferBackup Then
		Value = CurrentDate + 60 * 15;
	ElsIf RepeatPeriodInDay <> 0 Then
		Value = CurrentDate + RepeatPeriodInDay;
	ElsIf DaysRepeatPeriod <> 0 Then
		Value = CurrentDate + DaysRepeatPeriod * 3600 * 24;
	Else
		Value = BegOfDay(EndOfDay(CurrentDate) + 1);
	EndIf;
	Settings.MinDateOfNextAutomaticBackup = Value;
	IBBackupServer.SetBackupSettings(Settings);
	
	Return Value;
	
EndFunction

Procedure SetLastNotificationDate(NotificationDate1) Export
	
	IBBackupServer.SetLastNotificationDate(NotificationDate1);
	
EndProcedure

#EndRegion
