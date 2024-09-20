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
Procedure GoToSettingsClick(Item)
	Close();
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.MonitoringCenterSettings");
EndProcedure

&AtClient
Procedure Yes(Command)
	NewParameters = New Structure("SendDumpsFiles", 1);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure None(Command)
	NewParameters = New Structure("SendDumpsFiles", 0);
	NewParameters.Insert("SendingResult", NStr("en = 'User refused to submit full dumps.';"));
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

#EndRegion

