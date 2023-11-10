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
Var JobActive;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StorageAddress = PutToTempStorage(Undefined, New UUID);
	StateStorageAddress = PutToTempStorage(Undefined, New UUID);
	
	Items.Close.Enabled = Not Parameters.CheckMode;
	
	StartRequestsProcessing(
		Parameters.IDs,
		Parameters.EnablingMode,
		Parameters.DisablingMode,
		Parameters.RecoveryMode,
		Parameters.CheckMode);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	JobActive = True;
	CheckIteration = 1;
	AttachRequestsProcessingIdleHandler(3);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If JobActive Then
		CancelRequestsProcessing(JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function StartRequestsProcessing(Val Queries, Val EnablingMode, DisablingMode, Val RecoveryMode, Val ApplicabilityCheckMode)
	
	If EnablingMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StateStorageAddress);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.ExternalResourcesPermissionsSetup.ExecuteUpdateRequestProcessing");
		MethodCallParameters.Add(JobParameters);
		
	ElsIf DisablingMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StateStorageAddress);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.ExternalResourcesPermissionsSetup.ExecuteDisableRequestProcessing");
		MethodCallParameters.Add(JobParameters);
		
	ElsIf RecoveryMode Then
		
		JobParameters = New Array();
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StateStorageAddress);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.ExternalResourcesPermissionsSetup.ExecuteRecoveryRequestProcessing");
		MethodCallParameters.Add(JobParameters);
		
	Else
		
		JobParameters = New Array();
		JobParameters.Add(Queries);
		JobParameters.Add(StorageAddress);
		JobParameters.Add(StateStorageAddress);
		
		MethodCallParameters = New Array();
		MethodCallParameters.Add("DataProcessors.ExternalResourcesPermissionsSetup.ExecuteRequestProcessing");
		MethodCallParameters.Add(JobParameters);
		
	EndIf;
	
	Job = BackgroundJobs.Execute("Common.ExecuteConfigurationMethod",
			MethodCallParameters,
			,
			NStr("en = 'Processing requests for external resources…';"));
	
	JobID = Job.UUID;
	
	Return StorageAddress;
	
EndFunction

&AtClient
Procedure CheckRequestsProcessing()
	
	Try
		Readiness = RequestsProcessed(JobID);
	Except
		JobActive = False;
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.Cancel);
		Close(Result);
		Raise;
	EndTry;
	
	If Readiness Then
		JobActive = False;
		EndRequestsProcessing();
	Else
		
		CheckIteration = CheckIteration + 1;
		
		If CheckIteration = 2 Then
			AttachRequestsProcessingIdleHandler(5);
		ElsIf CheckIteration = 3 Then
			AttachRequestsProcessingIdleHandler(8);
		Else
			AttachRequestsProcessingIdleHandler(10);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function RequestsProcessed(Val JobID)
	
	Job = BackgroundJobs.FindByUUID(JobID);
	
	If Job <> Undefined
		And Job.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	If Job = Undefined Then
		Raise(NStr("en = 'An unexpected error occurred while processing permission requests to use external resources.';"));
	EndIf;
	
	If Job.State = BackgroundJobState.Failed Then
		JobError = Job.ErrorInfo;
		If JobError <> Undefined Then
			Raise(ErrorProcessing.DetailErrorDescription(JobError));
		Else
			Raise(NStr("en = 'Cannot process permission requests to use external resources.';"));
		EndIf;
	ElsIf Job.State = BackgroundJobState.Canceled Then
		Raise(NStr("en = 'Cannot process permission requests to use external resources as the administrator canceled the job.';"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtClient
Procedure EndRequestsProcessing()
	
	JobActive = False;
	
	If IsOpen() Then
		
		Result = New Structure();
		Result.Insert("ReturnCode", DialogReturnCode.OK);
		Result.Insert("StateStorageAddress", StateStorageAddress);
		
		Close(Result);
		
	Else
		
		NotifyDescription = OnCloseNotifyDescription;
		If NotifyDescription <> Undefined Then
			ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.OK);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelRequestsProcessing(Val JobID)
	
	Job = BackgroundJobs.FindByUUID(JobID);
	
	If Job = Undefined Or Job.State <> BackgroundJobState.Active Then
		Return;
	EndIf;
	
	Try
		Job.Cancel();
	Except
		// The job might have been completed at that moment and no error occurred.
		WriteLogEvent(NStr("en = 'External resource permission setup.Cancel background job';", Common.DefaultLanguageCode()),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtClient
Procedure AttachRequestsProcessingIdleHandler(Val Interval)
	
	AttachIdleHandler("CheckRequestsProcessing", Interval, True);
	
EndProcedure

#EndRegion