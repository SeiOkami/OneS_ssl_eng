///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Procedure OnChangeRetainReportDistributionHistory() Export
	
	If GetFunctionalOption("RetainReportDistributionHistory") Then
		SetScheduledJobUsage(Metadata.ScheduledJobs.GetStatusesOfEmailMessages, True);
		SetScheduledJobUsage(Metadata.ScheduledJobs.ReportDistributionHistoryClearUp, True);
	Else
		SetScheduledJobUsage(Metadata.ScheduledJobs.ReportDistributionHistoryClearUp, False);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// For internal use.
//
// Parameters:
//   RecipientsParameters - Structure
//
// Returns:
//   Structure:
//     * Recipients - Map
//     * HadCriticalErrors - Boolean
//     * Text - String
//     * More - String
//
Function GenerateMailingRecipientsList(Val RecipientsParameters) Export
	LogParameters = New Structure("EventName, Metadata, Data, ErrorsArray, HadErrors");
	LogParameters.EventName   = NStr("en = 'Report distribution. Generating recipient list';", Common.DefaultLanguageCode());
	LogParameters.ErrorsArray = New Array;
	LogParameters.HadErrors   = False;
	LogParameters.Data       = RecipientsParameters.Ref;
	LogParameters.Metadata   = Metadata.Catalogs.ReportMailings;
	
	ExecutionResult = New Structure("Recipients, HadCriticalErrors, Text, More");
	ExecutionResult.Recipients = ReportMailing.GenerateMailingRecipientsList(RecipientsParameters, LogParameters);
	ExecutionResult.HadCriticalErrors = ExecutionResult.Recipients.Count() = 0;
	
	If ExecutionResult.HadCriticalErrors Then
		ExecutionResult.Text = ReportMailing.MessagesToUserString(LogParameters.ErrorsArray, False);
	EndIf;
	
	Return ExecutionResult;
EndFunction

// Runs background job.
Function RunBackgroundJob1(Val MethodParameters, Val UUID) Export
	MethodName = "ReportMailing.SendBulkEmailsInBackgroundJob";
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Report distribution. Running in the background';");
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings1);
EndFunction

// 
Function RunBackgroundJobToSendSMSWithPasswords(Val MethodParameters, Val UUID) Export
	MethodName = "ReportMailing.SendBulkSMSMessagesWithReportDistributionArchivePasswordsInBackgroundJob";
	                             
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Report distributions: Send text messages with passwords in the background';");
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings1);
EndFunction  

// 
Function RunBackgroundJobToClearUpReportDistributionHistory(Val MethodParameters, Val UUID) Export
	MethodName = "ReportMailing.ClearUpReportDistributionHistoryInBackgroundJob";
	
	StartSettings1 = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings1.BackgroundJobDescription = NStr("en = 'Report distributions: Clear the report distribution history';");
	
	Return TimeConsumingOperations.ExecuteInBackground(MethodName, MethodParameters, StartSettings1);
EndFunction

Procedure SetScheduledJobUsage(MetadataJob1, Use)         
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", MetadataJob1);
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	If JobsList.Count() = 0 Then
		JobParameters = New Structure;
		JobParameters.Insert("Use", Use);
		JobParameters.Insert("Metadata", MetadataJob1);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure("Use", Use);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion
