///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var FormClosing, AccumulatedMessages;

&AtClient
Var StandardCloseAlert;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MessageText = NStr("en = 'Please wait…';");
	If Not IsBlankString(Parameters.MessageText) Then
		MessageText = Parameters.MessageText + Chars.LF + MessageText;
		Items.TimeConsumingOperationNoteTextDecoration.Title = MessageText;
	EndIf;
	
	If ValueIsFilled(Parameters.Title) Then
		Items.MessageOperation.Title = Parameters.Title;
		Items.MessageOperation.ShowTitle = True;
	Else
		Items.MessageOperation.ShowTitle = False;
	EndIf;
	
	If ValueIsFilled(Parameters.JobID) Then
		JobID = Parameters.JobID;
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ModuleTimeConsumingOperationsClient = CommonClient.CommonModule("TimeConsumingOperationsClient");
	StandardCloseAlert = OnCloseNotifyDescription <> Undefined
	   And OnCloseNotifyDescription.Module = ModuleTimeConsumingOperationsClient;
	
	If Parameters.OutputIdleWindow Then
		FormClosing = False;
		Status = "Running";
		AccumulatedMessages = New Array;
		
		TimeConsumingOperation = New Structure;
		TimeConsumingOperation.Insert("Status", Status);
		TimeConsumingOperation.Insert("JobID", Parameters.JobID);
		TimeConsumingOperation.Insert("Messages", New FixedArray(New Array));
		TimeConsumingOperation.Insert("ResultAddress", Parameters.ResultAddress);
		TimeConsumingOperation.Insert("AdditionalResultAddress", Parameters.AdditionalResultAddress);
		
		CompletionNotification2 = New NotifyDescription("OnCompleteTimeConsumingOperation", ThisObject);
		NotificationAboutProgress  = New NotifyDescription("OnGetLongRunningOperationProgress", ThisObject);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(FormOwner);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.Interval = Parameters.Interval;
		IdleParameters.ExecutionProgressNotification = NotificationAboutProgress;
		
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Status <> "Running"
	 Or StandardCloseAlert Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_CancelJob", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	FormClosing = True;
	DetachIdleHandler("Attachable_CancelJob");
	
	If Exit Then
		Return;
	EndIf;
	
	If Status <> "Running" Then
		Return;
	EndIf;
	
	If StandardCloseAlert Then
		TimeConsumingOperation = CheckJobAndCancelIfRunning(JobID);
		FinishLongRunningOperationAndCloseForm(TimeConsumingOperation);
	Else
		CancelJobExecution(JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnGetLongRunningOperationProgress(TimeConsumingOperation, AdditionalParameters) Export
	
	If FormClosing Or Not IsOpen() Then
		Return;
	EndIf;
	
	If Parameters.OutputProgressBar
	   And TimeConsumingOperation.Progress <> Undefined Then
		
		Percent = 0;
		If TimeConsumingOperation.Progress.Property("Percent", Percent) Then
			Items.DecorationPercent.Visible = True;
			Items.DecorationPercent.Title = String(Percent) + "%";
		EndIf;
		
		Text = "";
		If TimeConsumingOperation.Progress.Property("Text", Text) Then
			Items.TimeConsumingOperationNoteTextDecoration.Title = TrimAll(Text);
		EndIf;
		
	EndIf;
	
	If TimeConsumingOperation.Messages = Undefined Then
		Return;
	EndIf;
	
	TimeConsumingOperationsClient.ProcessMessagesToUser(TimeConsumingOperation.Messages,
		AccumulatedMessages, Parameters.OutputMessages, FormOwner);
	
EndProcedure

&AtClient
Procedure OnCompleteTimeConsumingOperation(TimeConsumingOperation, AdditionalParameters) Export
	
	If FormClosing Or Not IsOpen() Then
		Return;
	EndIf;
	
	FinishLongRunningOperationAndCloseForm(TimeConsumingOperation);
	
EndProcedure

&AtClient
Procedure FinishLongRunningOperationAndCloseForm(TimeConsumingOperation)
	
	AdditionalParameters = ?(StandardCloseAlert,
		OnCloseNotifyDescription.AdditionalParameters, Undefined);
	
	If TimeConsumingOperation = Undefined Then
		Status = "Canceled";
	Else
		Status = TimeConsumingOperation.Status;
	EndIf;
	
	If Status = "Canceled" Then
		If StandardCloseAlert Then
			AdditionalParameters.Result = Undefined;
			If Not FormClosing Then
				Close();
			EndIf;
		Else
			Close(Undefined);
		EndIf;
		Return;
	EndIf;
	
	If Parameters.MustReceiveResult Then
		If Status = "Completed2" Then
			TimeConsumingOperation.Insert("Result", GetFromTempStorage(Parameters.ResultAddress));
		Else
			TimeConsumingOperation.Insert("Result", Undefined);
		EndIf;
	EndIf;
	
	If Status = "Completed2" Then
		
		ShowNotification();
		If ReturnResultToChoiceProcessing() Then
			NotifyChoice(TimeConsumingOperation.Result);
			Return;
		EndIf;
		Result = ExecutionResult(TimeConsumingOperation);
		If StandardCloseAlert Then
			AdditionalParameters.Result = Result;
			If Not FormClosing Then
				Close();
			EndIf;
		Else
			Close(Result);
		EndIf;
		
	ElsIf Status = "Error" Then
		
		Result = ExecutionResult(TimeConsumingOperation);
		If StandardCloseAlert Then
			AdditionalParameters.Result = Result;
			If Not FormClosing Then
				Close();
			EndIf;
		Else
			Close(Result);
		EndIf;
		If ReturnResultToChoiceProcessing() Then
			Raise TimeConsumingOperation.BriefErrorDescription;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CancelJob()
	
	FormClosing = True;
	
	TimeConsumingOperation = CheckJobAndCancelIfRunning(JobID);
	FinishLongRunningOperationAndCloseForm(TimeConsumingOperation);
	
EndProcedure

&AtClient
Procedure ShowNotification()
	
	If Parameters.UserNotification = Undefined Then
		Return;
	EndIf;
	
	TimeConsumingOperationsClient.ShowNotification(Parameters.UserNotification, FormOwner);
	
EndProcedure

&AtServerNoContext
Function CheckJobAndCancelIfRunning(JobID)
	
	TimeConsumingOperation = TimeConsumingOperations.ActionCompleted(JobID);
	
	If TimeConsumingOperation.Status = "Running" Then
		CancelJobExecution(JobID);
		TimeConsumingOperation.Status = "Canceled";
	EndIf;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtServerNoContext
Procedure CancelJobExecution(JobID)
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
EndProcedure

&AtClient
Function ExecutionResult(TimeConsumingOperation)
	
	Result = New Structure;
	Result.Insert("Status", TimeConsumingOperation.Status);
	Result.Insert("ResultAddress", Parameters.ResultAddress);
	Result.Insert("AdditionalResultAddress", Parameters.AdditionalResultAddress);
	Result.Insert("BriefErrorDescription", TimeConsumingOperation.BriefErrorDescription);
	Result.Insert("DetailErrorDescription", TimeConsumingOperation.DetailErrorDescription);
	Result.Insert("Messages", New FixedArray(
		?(AccumulatedMessages = Undefined, New Array, AccumulatedMessages)));
	
	If Parameters.MustReceiveResult Then
		Result.Insert("Result", TimeConsumingOperation.Result);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function ReturnResultToChoiceProcessing()
	
	CompletionNotification2 = ?(StandardCloseAlert,
		OnCloseNotifyDescription.AdditionalParameters.CompletionNotification2,
		OnCloseNotifyDescription);
	
	Return CompletionNotification2 = Undefined
		And Parameters.MustReceiveResult
		And TypeOf(FormOwner) = Type("ClientApplicationForm");
	
EndFunction

#EndRegion