///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region FormCommandHandlers

&AtClient
Procedure Restart(Command)
	
	StandardSubsystemsClient.SkipExitConfirmation();
	Exit(True, True);
	
EndProcedure

&AtClient
Procedure RemindMeTomorrow(Command)
	
	RemindTomorrowOnServer();
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure RemindTomorrowOnServer()
	
	Common.SystemSettingsStorageSave("InfobaseUserRoleChangeControl",
		"DateRemindTomorrow", BegOfDay(CurrentSessionDate()) + 60*60*24);
	
EndProcedure

#EndRegion
