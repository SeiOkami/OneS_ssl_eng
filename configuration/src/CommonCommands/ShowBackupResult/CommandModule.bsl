///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RunParameters = StandardSubsystemsClient.ClientRunParameters();
	BackupParameters = RunParameters.IBBackup;
	
	FormParameters = New Structure();
	
	If BackupParameters.Property("CopyingResult") Then
		FormParameters.Insert("WorkMode", ?(BackupParameters.CopyingResult = True, "CompletedSuccessfully1", "NotCompleted2"));
		FormParameters.Insert("BackupFileName", BackupParameters.BackupFileName);
	EndIf;
	
	OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
	
EndProcedure

#EndRegion
