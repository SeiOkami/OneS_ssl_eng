///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ParametersToGet = New Structure("DumpsInformation, DumpInstances, DumpInstancesApproved");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
	DumpsInformation = MonitoringCenterParameters.DumpsInformation;
	Items.DumpsInformation.Height = StrLineCount(DumpsInformation);
	DumpsData = New Structure;
	DumpsData.Insert("DumpInstances", MonitoringCenterParameters.DumpInstances);
	DumpsData.Insert("DumpInstancesApproved", MonitoringCenterParameters.DumpInstancesApproved);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Yes(Command)
	Response = New Structure;
	Response.Insert("Approved", True);
	Response.Insert("DumpsInformation", DumpsInformation);
	Response.Insert("DoNotAskAgain", DoNotAskAgain);
	Response.Insert("DumpInstances", DumpsData.DumpInstances);
	Response.Insert("DumpInstancesApproved", DumpsData.DumpInstancesApproved);	
	SetMonitoringCenterParameters(Response);
	Close();
EndProcedure

&AtClient
Procedure None(Command)
	Response = New Structure;
	Response.Insert("Approved", False);
	Response.Insert("DoNotAskAgain", DoNotAskAgain);
	SetMonitoringCenterParameters(Response);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(Response)
	
	NewParameters = New Structure;
	
	If Response.Approved Then
		
		// The user does not want to be asked.
		If Response.DoNotAskAgain Then
			NewParameters.Insert("RequestConfirmationBeforeSending", False);
		EndIf;
		
		// Request for the current parameters as they might be changed.
		ParametersToGet = New Structure("DumpsInformation, DumpInstances");
		MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
		
		// 
		NewParameters.Insert("DumpInstancesApproved", Response.DumpInstancesApproved);
		For Each Record In Response.DumpInstances Do
			NewParameters.DumpInstancesApproved.Insert(Record.Key, Record.Value);
			MonitoringCenterParameters.DumpInstances.Delete(Record.Key);
		EndDo;
		
		NewParameters.Insert("DumpInstances", MonitoringCenterParameters.DumpInstances);
		
		// Clear parameters.
		If Response.DumpsInformation = MonitoringCenterParameters.DumpsInformation Then
			NewParameters.Insert("DumpsInformation", "");	
		EndIf;
		
	Else
		
		// The user does not want to be asked and they are not going to send anything.
		If Response.DoNotAskAgain Then
			NewParameters.Insert("SendDumpsFiles", 0);
			NewParameters.Insert("SendingResult", NStr("en = 'User refused to submit full dumps.';"));
			// 
			NewParameters.Insert("DumpsInformation", "");
			NewParameters.Insert("DumpInstances", New Map);
		EndIf;
		
	EndIf;    
	
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
	
EndProcedure

#EndRegion
