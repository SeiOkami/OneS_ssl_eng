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
	
	GetIDJobState = "";
	
	If Parameters.Property("JobID") Then
		JobID = Parameters.JobID;
		JobResultAddress = Parameters.JobResultAddress;
		If ValueIsFilled(JobID) Then
			GetIDJobState = JobCompleted(JobID);
		EndIf;
	EndIf;  	
	
	MonitoringCenterID = MonitoringCenterID();
	If Not IsBlankString(MonitoringCenterID) Then
		Id = MonitoringCenterID;
	Else
		// Идентификатора нет по какой-
		Items.IDGroup.CurrentPage = Items.GetIDPage;
	EndIf;
	
	ParametersToGet = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
	SendErrorsInformation = MonitoringCenterParameters.SendDumpsFiles;
	If SendErrorsInformation = 2 Then
		Items.SendErrorsInformation.ThreeState = True;
	EndIf;
	RequestConfirmationBeforeSending = MonitoringCenterParameters.RequestConfirmationBeforeSending;
	HintContent = Items.SendErrorsInformationExtendedTooltip.Title;
	If Common.FileInfobase() Then                                   		
		Items.SendErrorsInformationExtendedTooltip.Title = StrReplace(HintContent,"%1","");
	Else
		Items.SendErrorsInformationExtendedTooltip.Title = StrReplace(HintContent,"%1"," " + NStr("en = 'on 1C server';"));
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	VisibilityParameters = New Structure("Status, ResultAddress", GetIDJobState, JobResultAddress);
	If Not IsBlankString(GetIDJobState) And IsBlankString(Id) Then
		SetItemsVisibility(VisibilityParameters);
	EndIf;
EndProcedure

&AtClient
Procedure SendErrorsInformationOnChange(Item)
	Item.ThreeState = False;
EndProcedure

#EndRegion


#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	NewParameters = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending", 
										SendErrorsInformation, RequestConfirmationBeforeSending);
	SetMonitoringCenterParameters(NewParameters);
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	NewParameters = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending", 
										SendErrorsInformation, RequestConfirmationBeforeSending);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure GetID(Command)
	RunResult = DiscoveryPackageSending();
	JobID = RunResult.JobID;
	JobResultAddress = RunResult.ResultAddress;
	GetIDJobState = "Running";
	Notification = New NotifyDescription("AfterUpdateID", MonitoringCenterClient);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	TimeConsumingOperationsClient.WaitCompletion(RunResult, Notification, IdleParameters);
	
	// Outputs the status of getting ID.
	VisibilityParameters = New Structure("Status, ResultAddress", GetIDJobState, JobResultAddress);
	SetItemsVisibility(VisibilityParameters);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "IDUpdateMonitoringCenter" And Parameter <> Undefined Then
		SetItemsVisibility(Parameter);	
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

&AtServerNoContext
Function MonitoringCenterID()
	Return MonitoringCenter.InfoBaseID();
EndFunction

&AtClient
Procedure UpdateParameters()
	MonitoringCenterID = MonitoringCenterID();
	If Not IsBlankString(MonitoringCenterID) Then
		Id = MonitoringCenterID;
	EndIf;                                                                     	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	ExecutionResult = "Running";
	Try
		JobCompleted = TimeConsumingOperations.JobCompleted(JobID);
		If JobCompleted Then 
			ExecutionResult = "Completed2";
		Else
			ExecutionResult = "Running";
		EndIf;
	Except
		ExecutionResult = "Error";
	EndTry;
	Return ExecutionResult;
EndFunction

&AtServerNoContext
Function DiscoveryPackageSending()
	// Send a discovery package.
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitCompletion = 0;
	ProcedureParameters = New Structure("Iterator_SSLy, TestPackageSending, GetID", 0, False, True);
	Return TimeConsumingOperations.ExecuteInBackground("MonitoringCenterInternal.SendTestPackage", ProcedureParameters, ExecutionParameters);
EndFunction

&AtClient
Procedure SetItemsVisibility(VisibilityParameters)
	ExecutionResult = GetFromTempStorage(VisibilityParameters.ResultAddress);
	If VisibilityParameters.Status = "Running" Then
		Items.ProgressDetails.Title = NStr("en = 'Receiving ID';");		
		Items.ProgressDetails.Visible = True;
		Items.Progress.Picture = PictureLib.TimeConsumingOperation16;
		Items.Progress.Visible = True;
		Items.IDGroup.Visible = False;	
	ElsIf VisibilityParameters.Status = "Completed2" And ExecutionResult.Success Then
		Items.ProgressDetails.Title = NStr("en = 'ID is received successfully';");		
		Items.ProgressDetails.Visible = False;
		Items.Progress.Visible = False;
		Items.IDGroup.Visible = True;
		Items.IDGroup.CurrentPage = Items.IDPage;
		UpdateParameters();
	ElsIf VisibilityParameters.Status = "Completed2" And Not ExecutionResult.Success Or VisibilityParameters.Status = "Error" Then
		If VisibilityParameters.Status = "Error" Then
			Explanation = NStr("en = 'An unexpected error occurred.';");
		Else
			Explanation = ExecutionResult.BriefErrorDescription;
		EndIf;
		TitleTemplate1 = NStr("en = 'Cannot receive ID. %1 For more information, see the event log';");
		Items.ProgressDetails.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, Explanation);		
		Items.ProgressDetails.Visible = True;
		Items.Progress.Picture = PictureLib.Warning;
		Items.Progress.Visible = True;
		Items.IDGroup.Visible = True;
		Items.IDGroup.CurrentPage = Items.GetIDPage;
	EndIf;
EndProcedure

#EndRegion

