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
	If Not TotalsAndAggregatesManagementInternal.MustMoveTotalsBorder() Then
		Cancel = True; // 
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	TimeConsumingOperation = LongRunningOperationStartServer(UUID);
	
	WaitSettings = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	WaitSettings.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("TimeConsumingOperationCompletionClient", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, Handler, WaitSettings);
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function LongRunningOperationStartServer(UUID)
	MethodName = "DataProcessors.ShiftTotalsBoundary.ExecuteCommand";
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Totals and aggregates: Accelerated document posting and report generation';");
	StartSettings1.WaitCompletion = 0;
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, Undefined, StartSettings1);
EndFunction

&AtClient
Procedure TimeConsumingOperationCompletionClient(Operation, AdditionalParameters) Export
	
	Handler = New NotifyDescription("TimeConsumingOperationAfterOutputResult", ThisObject);
	If Operation = Undefined Then
		ExecuteNotifyProcessing(Handler, False);
		Return;
	EndIf;
	If Operation.Status = "Completed2" Then
		ShowUserNotification(NStr("en = 'Optimization completed successfully';"),,, PictureLib.Success32);
		ExecuteNotifyProcessing(Handler, True);
	Else
		Raise Operation.BriefErrorDescription;
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationAfterOutputResult(Result, AdditionalParameters) Export
	If OnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OnCloseNotifyDescription, Result); // Bypass call characteristic from OnOpen.
	EndIf;
	If IsOpen() Then
		Close(Result);
	EndIf;
EndProcedure

#EndRegion