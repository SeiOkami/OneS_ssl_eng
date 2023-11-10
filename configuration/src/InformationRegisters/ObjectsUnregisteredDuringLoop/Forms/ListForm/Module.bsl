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
	
	If Parameters.Property("InfobaseNode") Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "InfobaseNode", Parameters.InfobaseNode); 	
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RegisterEverything(Command)
		
	TimeConsumingOperation = StartRegistering();
	
	CompletionNotification2 = New NotifyDescription("ProcessResult", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters());

EndProcedure

&AtClient
Procedure RegisterSelected(Command)
	
	SelectedRows = Items.List.SelectedRows;
	If SelectedRows.Count() = 0 Then
		CommonClient.MessageToUser(NStr("en = 'To continue, select lines';"));
		Return;
	EndIf;
	
	ObjectsTable.Clear();
	For Each String In SelectedRows Do
		NewRow = ObjectsTable.Add();
		LineVals = Items.List.RowData(String);
		FillPropertyValues(NewRow, LineVals);
	EndDo;
	
	TimeConsumingOperation = StartRegisteringSelectedOne();
	
	CompletionNotification2 = New NotifyDescription("ProcessResult", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters());
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function IdleParameters()
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = "";
	IdleParameters.OutputProgressBar = False;
	IdleParameters.ExecutionProgressNotification = Undefined;
	IdleParameters.UserNotification.Show = False;
	IdleParameters.UserNotification.URL = Undefined;
	IdleParameters.OutputIdleWindow = True;
	IdleParameters.OutputMessages = False;
	
	Return IdleParameters;

EndFunction

&AtServer
Function StartRegisteringSelectedOne()
	
	Address = PutToTempStorage(ObjectsTable.Unload());
	
	Return TimeConsumingOperations.ExecuteProcedure(,
		"InformationRegisters.ObjectsUnregisteredDuringLoop.RegisterSelected",
		Address);
		
EndFunction

&AtServer
Function StartRegistering()
	
	Schema = Items.List.GetPerformingDataCompositionScheme();
	Settings = Items.List.GetPerformingDataCompositionSettings();

	Return TimeConsumingOperations.ExecuteProcedure(,
		"InformationRegisters.ObjectsUnregisteredDuringLoop.RegisterEverything", 
		Schema, Settings);
		
EndFunction

&AtClient
Procedure ProcessResult(Result, AdditionalParameters) Export
	
	If Result = Undefined Then 
		Return;
	EndIf;
		
	If Result.Status = "Error" Then
		ShowMessageBox(,Result.BriefErrorDescription);
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion