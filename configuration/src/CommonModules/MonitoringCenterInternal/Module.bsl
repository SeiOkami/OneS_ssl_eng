///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Gets a scheduled job by name.
//
// Parameters:
//  ScheduledJobName - String - a name of scheduled job.
//    CreateNew2 - Boolean - if missing, a new one is created.
//
Function GetScheduledJobExternalCall(ScheduledJobName, CreateNew2 = True) Export
	Return GetScheduledJob(ScheduledJobName, CreateNew2);
EndFunction

// Sets the default schedule of a scheduled job.
//
// Parameters:
//  ScheduledJobName - ScheduledJob.
//
Procedure SetDefaultScheduleExternalCall(Job) Export
	SetDefaultSchedule(Job);
EndProcedure

// Deletes a scheduled job by name.
//
// Parameters:
//  ScheduledJobName - String - a name of scheduled job.
//
Procedure DeleteScheduledJobExternalCall(ScheduledJobName) Export
	DeleteScheduledJob(ScheduledJobName);
EndProcedure

// Sets a value of the Monitoring center parameter.
//
// Parameters:
//  Parameter - String - a Monitoring center parameter key.
//                      See possible key values in the GetDefaultParameters procedure of the MonitoringCenterInternal module.
//  Value - Arbitrary - a Monitoring center parameter value.
//
Function SetMonitoringCenterParameterExternalCall(Parameter, Value) Export
	SetMonitoringCenterParameter(Parameter, Value);
	Return "Success";
EndFunction

// This function gets default Monitoring center parameters.
// Returns
//    Structure - a value of the MonitoringCenterParameters constant.
//
Function GetDefaultParametersExternalCall() Export
	Return GetDefaultParameters();
EndFunction

// This function gets Monitoring center parameters.
// Parameters:
//    Parameters - Structure - where keys are parameters whose values are to be got.
// Returns
//    Structure - a value of the MonitoringCenterParameters constant.
//
Function GetMonitoringCenterParametersExternalCall(Parameters = Undefined) Export
	Return GetMonitoringCenterParameters(Parameters);
EndFunction

// This function sets Monitoring center parameters.
// Parameters:
//    Parameters - Structure - parameters whose values are to be got.
//
Function SetMonitoringCenterParametersExternalCall(NewParameters) Export
	SetMonitoringCenterParameters(NewParameters);
	Return "Success";
EndFunction

Function StartDiscoveryPackageSending() Export
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitCompletion = 0;
	ProcedureParameters = New Structure("Iterator_SSLy, TestPackageSending, GetID", 0, False, True);
	RunResult = TimeConsumingOperations.ExecuteInBackground("MonitoringCenterInternal.SendTestPackage", ProcedureParameters, ExecutionParameters);
	Return RunResult;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.StatisticsDataCollectionAndSending;
	Dependence.UseExternalResources = True;
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ErrorReportCollectionAndSending;
	Dependence.UseExternalResources = True;
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "MonitoringCenterInternal.InitialFilling1";
	
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	Handler.Version = "2.4.1.7";
	Handler.Procedure = "MonitoringCenterInternal.AddInfobaseIDPermanent";
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() And Not SeparationByDataAreasEnabled() Then
		Handler = Handlers.Add();
		Handler.ExecutionMode = "Deferred";
		Handler.Version          = "2.4.4.79";
		Handler.Comment     = NStr("en = 'Enables sending application usage data to 1C company. You can disable this option in Administration — Online support and services — Monitoring center.';");
		Handler.Id   = New UUID("68c8c60c-5b23-436a-9555-a6f24a6b1ffd");
		Handler.Procedure       = "MonitoringCenterInternal.EnableSendingInfo";
		Handler.UpdateDataFillingProcedure = "MonitoringCenterInternal.EnableSendingInfoFilling";
		Handler.ObjectsToRead                     = "Constant.MonitoringCenterParameters";
		Handler.ObjectsToChange                   = "Constant.MonitoringCenterParameters, ScheduledJob.StatisticsDataCollectionAndSending";
	EndIf;

	Handler = Handlers.Add();
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	Handler.Version = "3.1.9.43";
	Handler.Procedure = "MonitoringCenterInternal.DisableEventLoggingOnUpdate";
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	ClientRunParameters = New Structure("SessionTimeZone, UserHash, RegisterBusinessStatistics,
											|PromptForFullDump, PromptForFullDumpDisplayed, DumpsInformation,
											|RequestForGettingDumps,SendingRequest,RequestForGettingContacts,
											|RequestForGettingContactsDisplayed");
	
	UserUUID = String(InfoBaseUsers.CurrentUser().UUID);
	SessionNumber = Format(InfoBaseSessionNumber(), "NG=0");
	UserHash = Common.CheckSumString(UserUUID + SessionNumber);
	
	RegisterBusinessStatistics = GetMonitoringCenterParameters("RegisterBusinessStatistics");
	RequestForGettingContacts = GetMonitoringCenterParameters("ContactInformationRequest") = 3;
	NotificationOfDumpsParameters = NotificationOfDumpsParameters();
	
	IsFullUser = Users.IsFullUser(, True);
	
	MonitoringCenterSettings = New Structure;
	// 
	MonitoringCenterSettings.Insert("EnableNotifications", True);
	MonitoringCenterOverridable.OnDefineSettings(MonitoringCenterSettings);
	
	ClientRunParameters.PromptForFullDump = IsFullUser And MonitoringCenterSettings.EnableNotifications;	
	ClientRunParameters.PromptForFullDumpDisplayed = False;
	ClientRunParameters.RequestForGettingDumps = NotificationOfDumpsParameters.RequestForGettingDumps;
	ClientRunParameters.SendingRequest = NotificationOfDumpsParameters.SendingRequest;
	ClientRunParameters.DumpsInformation = NotificationOfDumpsParameters.DumpsInformation;
	ClientRunParameters.SessionTimeZone = SessionTimeZone();
	ClientRunParameters.UserHash = UserHash;
	ClientRunParameters.RegisterBusinessStatistics = RegisterBusinessStatistics;
	ClientRunParameters.RequestForGettingContacts = RequestForGettingContacts;
	ClientRunParameters.RequestForGettingContactsDisplayed = False;
		
	Parameters.Insert("MonitoringCenter", New FixedStructure(ClientRunParameters));
	
	// Write a user activity in business statistics when starting the procedure.
	If RegisterBusinessStatistics Then
		WriteUserActivity(UserHash);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnReceiptRecurringClientDataOnServer
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
	CollectedPatameters = Parameters.Get("StandardSubsystems.MonitoringCenter");
	If CollectedPatameters = Undefined Then
		Return;
	EndIf;
	
	Result = New Map(CollectedPatameters);
	Results.Insert("StandardSubsystems.MonitoringCenter", Result);
	
	If CollectedPatameters["ClientInformation"]["ClientParameters"]["RegisterBusinessStatistics"] Then
	
		RegisterBusinessStatistics = GetMonitoringCenterParameters("RegisterBusinessStatistics");
		
		Result.Insert("RegisterBusinessStatistics", RegisterBusinessStatistics);
		
		BackgroundJobKey = "OnRecurringClientDataReceiptOnServerInBackground"
			+ CollectedPatameters["ClientInformation"]["ClientParameters"]["UserHash"];
		
		Filter = New Structure;
		Filter.Insert("Key", BackgroundJobKey);
		Filter.Insert("State", BackgroundJobState.Active);
		ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
		
		If ActiveBackgroundJobs.Count() = 0 Then
			
			BackgroundJobParameters = New Array;
			BackgroundJobParameters.Add(CollectedPatameters);
			BackgroundJobs.Execute("MonitoringCenterInternal.OnRecurringClientDataReceiptOnServerInBackground",
				BackgroundJobParameters,
				BackgroundJobKey,
				"MonitoringCenterInternal.OnReceiptRecurringClientDataOnServer");
		EndIf;
		
	EndIf;
	
	If CollectedPatameters["ClientInformation"]["ClientParameters"]["PromptForFullDump"] Then
		
		NotificationOfDumpsParameters = NotificationOfDumpsParameters();
		
		RequestForGettingDumps = NotificationOfDumpsParameters.RequestForGettingDumps
								And Not CollectedPatameters.Get("PromptForFullDumpDisplayed") = True;
		RequestForGettingContacts = GetMonitoringCenterParameters("ContactInformationRequest") = 3
								And Not CollectedPatameters.Get("RequestForGettingContactsDisplayed") = True;
		
		Result.Insert("RequestForGettingDumps", RequestForGettingDumps);
		Result.Insert("DumpsSendingRequest", NotificationOfDumpsParameters.SendingRequest);
		Result.Insert("DumpsInformation", NotificationOfDumpsParameters.DumpsInformation);
		Result.Insert("RequestForGettingContacts", RequestForGettingContacts);
		
	EndIf;
	
	MonitoringCenterParameters = New Structure("TestPackageSent,ApplicationInformationProcessingCenter,EnableMonitoringCenter");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If Not MonitoringCenterParameters.TestPackageSent And Not SeparationByDataAreasEnabled() Then
		// 
		If MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("TestPackageSent", True);
			SetPrivilegedMode(False);
		Else
			BackgroundJobKey = "TestPackageSending";
			
			Filter = New Structure;
			Filter.Insert("Key", BackgroundJobKey);
			Filter.Insert("State", BackgroundJobState.Active);
			ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
			If ActiveBackgroundJobs.Count() = 0 Then                                                                      
				ProcedureParameters = New Structure("Iterator_SSLy, TestPackageSending, GetID", 0, True, False);
				ParametersArray = New Array;
				ParametersArray.Add(ProcedureParameters);
				ParametersArray.Add(Undefined);				
				BackgroundJobs.Execute("MonitoringCenterInternal.SendTestPackage",
					ParametersArray,
					BackgroundJobKey,
					NStr("en = 'Monitoring center: send test package';"));
			EndIf;
		EndIf;
	EndIf;
	
	If Common.FileInfobase() Then
		MonitoringCenterParameters = New Structure("SendDumpsFiles,DumpOption,DumpCollectingEnd,FullDumpsCollectionEnabled");
		MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
			
		StartErrorReportsCollectionAndSending = Not MonitoringCenterParameters.SendDumpsFiles = 0
												And Not IsBlankString(MonitoringCenterParameters.DumpOption)
												And CurrentUniversalDate() < MonitoringCenterParameters.DumpCollectingEnd;
												
		If StartErrorReportsCollectionAndSending Then
			Id = CollectedPatameters["ClientInformation"]["ClientParameters"]["UserHash"];
			BackgroundJobKey = "CollectAndSendServerErrorReportsInBackground" + Id;
			
			Filter = New Structure;
			Filter.Insert("Key", BackgroundJobKey);
			Filter.Insert("State", BackgroundJobState.Active);
			ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
			
			If ActiveBackgroundJobs.Count() = 0 Then
				BackgroundJobParameters = New Array;
				BackgroundJobParameters.Add(True);
				BackgroundJobParameters.Add(Id);
				BackgroundJobs.Execute("MonitoringCenterInternal.CollectAndSendDumps",
					BackgroundJobParameters,
					BackgroundJobKey,
					NStr("en = 'Collect and send error reports';"));
				EndIf;
		Else
			If MonitoringCenterParameters.FullDumpsCollectionEnabled[ComputerName()] = True Then
				StopFullDumpsCollection();
			EndIf;
		EndIf;	
	EndIf;
		
EndProcedure

Procedure OnRecurringClientDataReceiptOnServerInBackground(Parameters) Export
	
	WriteClientScreensStatistics(Parameters);
	WriteSystemInformation(Parameters);
	WriteClientInformation(Parameters);
	WriteDataFromClient(Parameters);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	// Only system administrator is authorized to change a constant.
	If Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	
	Sections = ModuleToDoListServer.SectionsForObject("DataProcessor.MonitoringCenterSettings");
	If Sections.Count() = 0 Then
		// Not included to the command interface.
		AdministrationSection = Metadata.Subsystems.Find("Administration");
		If AdministrationSection = Undefined Then
			Return;
		EndIf;
		Sections.Add(AdministrationSection);
	EndIf;
	
	// 1. Process dump import request.
	RequestForGettingDumps = MonitoringCenterParameters.SendDumpsFiles = 2 And MonitoringCenterParameters.BasicChecksPassed;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "RequestForGettingDumps";
		ToDoItem.HasToDoItems       = RequestForGettingDumps;
		ToDoItem.Important         = True;
		ToDoItem.HideInSettings = True;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("en = 'Provide error reports';");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("en = 'Abnormal application terminations were registered. Please contact us on this issue.';");
		ToDoItem.FormParameters = New Structure("Variant", "Query");
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.RequestForErrorReportsCollectionAndSending";
	EndDo;

	// 2. Process dump export request.
	HasDumps1 = MonitoringCenterParameters.Property("DumpInstances") And MonitoringCenterParameters.DumpInstances.Count();
	SendingRequest = MonitoringCenterParameters.SendDumpsFiles = 1
						And Not IsBlankString(MonitoringCenterParameters.DumpOption)
						And HasDumps1
						And MonitoringCenterParameters.RequestConfirmationBeforeSending
						And MonitoringCenterParameters.DumpType = "3"
						And Not IsBlankString(MonitoringCenterParameters.DumpsInformation)
						And MonitoringCenterParameters.BasicChecksPassed;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "DumpsSendingRequest";
		ToDoItem.HasToDoItems       = SendingRequest;
		ToDoItem.Important         = False;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("en = 'Send error reports';");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("en = 'Crash reports are collected and prepared. Please approve reports submission.';");
		ToDoItem.FormParameters = New Structure;
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.RequestForSendingErrorReports";
	EndDo;
	
	// 3. Request contact information.
	HasContactInformationRequest = MonitoringCenterParameters.ContactInformationRequest = 3;
	For Each Section In Sections Do
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "ContactInformationRequest";
		ToDoItem.HasToDoItems       = HasContactInformationRequest;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = Section;
		ToDoItem.Presentation  = NStr("en = 'Inform of performance issues';");
		ToDoItem.Count     = 0;
		ToDoItem.ToolTip      = NStr("en = 'Performance issues are detected. Contact us on this issue.';");
		ToDoItem.FormParameters = New Structure("OnRequest", True);
		ToDoItem.Form          = "DataProcessor.MonitoringCenterSettings.Form.SendContactInformation";
	EndDo;
	
EndProcedure

Procedure DisableEventLogging() Export
	
	NewParameters = New Structure;
	NewParameters.Insert("RegisterSystemInformation", False);
	NewParameters.Insert("RegisterSubsystemVersions", False);
	NewParameters.Insert("RegisterDumps", False);
	NewParameters.Insert("RegisterBusinessStatistics", False);
	NewParameters.Insert("RegisterConfigurationStatistics", False);
	NewParameters.Insert("RegisterConfigurationSettings", False);
	NewParameters.Insert("RegisterPerformance", False);
	NewParameters.Insert("RegisterTechnologicalPerformance", False);
	SetMonitoringCenterParameters(NewParameters);
	
EndProcedure

#EndRegion

#Region Private

#Region WorkWithScheduledJobs

Function GetScheduledJob(ScheduledJobName, CreateNew2 = True)
	Result = Undefined;
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ScheduledJobName));
	If Jobs.Count() = 0 Then
		If CreateNew2 Then
			Job = ScheduledJobs.CreateScheduledJob(Metadata["ScheduledJobs"][ScheduledJobName]);
			Job.Use = True;
			Job.Write();
			Result = Job;
		EndIf;
	Else
		Result = Jobs[0];
	EndIf;
	
	Return Result;
EndFunction

Procedure SetDefaultSchedule(Job)
	Job.Schedule.DaysRepeatPeriod = 1;
	Job.Schedule.RepeatPeriodInDay = 600;
	Job.Write();
EndProcedure

Procedure DeleteScheduledJob(ScheduledJobName)
	SchedJob = GetScheduledJob(ScheduledJobName, False);
	If SchedJob <> Undefined Then
		SchedJob.Delete();
	EndIf;
EndProcedure

Procedure MonitoringCenterScheduledJob() Export
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.StatisticsDataCollectionAndSending);
	
	PerformanceMonitorRecordRequired = False;
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	StartDate2 = CurrentUniversalDate();
	MonitoringCenterParameters = New Structure();
	
	MonitoringCenterParameters.Insert("EnableMonitoringCenter");
	MonitoringCenterParameters.Insert("ApplicationInformationProcessingCenter");
	MonitoringCenterParameters.Insert("RegisterDumps");
	MonitoringCenterParameters.Insert("DumpRegistrationNextCreation");
	MonitoringCenterParameters.Insert("DumpRegistrationCreationPeriod");
	
	MonitoringCenterParameters.Insert("RegisterBusinessStatistics");
	MonitoringCenterParameters.Insert("BusinessStatisticsNextSnapshot");
	MonitoringCenterParameters.Insert("BusinessStatisticsSnapshotPeriod");
	
	MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsNextGeneration");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsGenerationPeriod");
	
	MonitoringCenterParameters.Insert("SendDataNextGeneration");
	MonitoringCenterParameters.Insert("SendDataGenerationPeriod");
	MonitoringCenterParameters.Insert("NotificationDate2");
	MonitoringCenterParameters.Insert("ForceSendMinidumps");
	MonitoringCenterParameters.Insert("UserResponseTimeout");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter) And IsMasterNode1() Then 
		If MonitoringCenterParameters.RegisterDumps And StartDate2 >= MonitoringCenterParameters.DumpRegistrationNextCreation Then
			Try
				DumpsRegistration();
			Except
				Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Register dumps';", 
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
				SetMonitoringCenterParameter("RegisterDumps", False);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.Error", 1, Comment);
			EndTry;
			
			MonitoringCenterParameters.DumpRegistrationNextCreation =
				CurrentUniversalDate() + MonitoringCenterParameters.DumpRegistrationCreationPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If MonitoringCenterParameters.RegisterBusinessStatistics And StartDate2 >= MonitoringCenterParameters.BusinessStatisticsNextSnapshot Then
			Try
				StatisticsOperationsRegistration();
			Except
				Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Register statistics operations';",
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.StatisticsOperationsRegistration.Error", 1, Comment);
			EndTry;
						
			MonitoringCenterParameters.BusinessStatisticsNextSnapshot =
			CurrentUniversalDate()
			+ MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If (MonitoringCenterParameters.RegisterConfigurationStatistics Or MonitoringCenterParameters.RegisterConfigurationSettings) And StartDate2 >= MonitoringCenterParameters.ConfigurationStatisticsNextGeneration Then
			Try
				CollectConfigurationStatistics1(New Structure("RegisterConfigurationStatistics, RegisterConfigurationSettings", MonitoringCenterParameters.RegisterConfigurationStatistics, MonitoringCenterParameters.RegisterConfigurationSettings));
			Except
				Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Collect configuration statistics';",
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.CollectConfigurationStatistics1.Error", 1, Comment);
			EndTry;
				
			MonitoringCenterParameters.ConfigurationStatisticsNextGeneration =
			CurrentUniversalDate()
			+ MonitoringCenterParameters.ConfigurationStatisticsGenerationPeriod;
			
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If StartDate2 >= MonitoringCenterParameters.SendDataNextGeneration Then
			Try
				CreatePackageToSend();
			Except
				Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Generate a package for sending';",
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.CreatePackageToSend.Error", 1, Comment);
			EndTry;
			
			Try
				HTTPResponse = SendMonitoringData();
				If HTTPResponse.StatusCode = 200 Then
					// Everything is OK.
				EndIf;
			Except
				Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Send monitoring data';",
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.SendMonitoringData.Error", 
					1, Comment);
			EndTry;
			
			MonitoringCenterParameters.SendDataNextGeneration = CurrentUniversalDate()
				+ GetMonitoringCenterParameters("SendDataGenerationPeriod");
				
			MonitoringCenterParameters.Delete("DumpRegistrationNextCreation");
			MonitoringCenterParameters.Delete("DumpRegistrationCreationPeriod");
			
			MonitoringCenterParameters.Delete("BusinessStatisticsNextSnapshot");
			MonitoringCenterParameters.Delete("BusinessStatisticsSnapshotPeriod");
			
			MonitoringCenterParameters.Delete("ConfigurationStatisticsNextGeneration");
			MonitoringCenterParameters.Delete("ConfigurationStatisticsGenerationPeriod");
			
			PerformanceMonitorRecordRequired = True;
			
			// Set additional error processing parameters.
			InstallAdditionalErrorHandlingInformation();
		EndIf;
		
		// 
		// 
		MonitoringCenterParameters.Delete("RegisterDumps");
		MonitoringCenterParameters.Delete("RegisterBusinessStatistics");
		MonitoringCenterParameters.Delete("RegisterConfigurationStatistics");
		MonitoringCenterParameters.Delete("RegisterConfigurationSettings");
		MonitoringCenterParameters.Delete("SendDataGenerationPeriod");
		
		SetMonitoringCenterParameters(MonitoringCenterParameters);
	Else
		DeleteScheduledJob("StatisticsDataCollectionAndSending");
	EndIf;
	
	// 
	MonitoringCenterParameters.Insert("SendDumpsFiles");
	MonitoringCenterParameters.Insert("DumpOption");
	MonitoringCenterParameters.Insert("DumpCollectingEnd");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	StartErrorReportsCollectionAndSending = Not MonitoringCenterParameters.SendDumpsFiles = 0
											And Not IsBlankString(MonitoringCenterParameters.DumpOption)
											And StartDate2 < MonitoringCenterParameters.DumpCollectingEnd;
	If StartErrorReportsCollectionAndSending Then
		
		If Not ValueIsFilled(MonitoringCenterParameters.NotificationDate2) Then
			// Set a notification date.
			SetMonitoringCenterParameter("NotificationDate2", StartDate2);
		ElsIf StartDate2 > MonitoringCenterParameters.NotificationDate2 + MonitoringCenterParameters.UserResponseTimeout * 86400
			And MonitoringCenterParameters.ForceSendMinidumps = 2 Then
			// Timeout is expired, enable a forced sending.
			SetMonitoringCenterParameter("ForceSendMinidumps", 1);	
			MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.ForcedMinidumpSendingEnabled", 1);
		EndIf;
		
		If Common.FileInfobase() Then
			// 
		Else    			
			// Check if the background job exists.			
			SchedJob = GetScheduledJob("ErrorReportCollectionAndSending", False);
			If SchedJob = Undefined Then
				SchedJob = GetScheduledJob("ErrorReportCollectionAndSending", True);
				SetDefaultSchedule(SchedJob);
			EndIf;                                      			
		EndIf;
	EndIf;											
	
	If PerformanceMonitorExists And PerformanceMonitorRecordRequired Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectAndSubmitStatisticalData", BeginTime);
	EndIf;
EndProcedure

#EndRegion

#Region WorkWithBusinessStatistics

Procedure ParseStatisticsOperationsBuffer(CurrentDate)
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("AggregationPeriodMinor, AggregationPeriod"));
	AggregationPeriod = MonitoringCenterParameters.AggregationPeriodMinor;
	DeletionPeriod = MonitoringCenterParameters.AggregationPeriod;
				
	ProcessRecordsUntil = Date(1, 1, 1) + Int((CurrentDate - Date(1, 1, 1))/AggregationPeriod)*AggregationPeriod;
			
	QueryResultOperations = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedOperationsRecords(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	QueryResultComment = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedRecordsComment(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	QueryResultAreas = InformationRegisters.StatisticsOperationsClipboard.GetAggregatedRecordsStatisticsAreas(ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
	BeginTransaction();
	Try
		InformationRegisters.MeasurementsStatisticsOperations.WriteMeasurements(QueryResultOperations);
		InformationRegisters.MeasurementsStatisticsComments.WriteMeasurements(QueryResultComment);
		InformationRegisters.MeasurementsStatisticsAreas.WriteMeasurements(QueryResultAreas);
		
		InformationRegisters.StatisticsOperationsClipboard.DeleteRecords(ProcessRecordsUntil);	
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteLogEvent(LogLogEventParseOperationBufferStatistics(), 
			EventLogLevel.Error, Metadata.InformationRegisters.StatisticsOperationsClipboard,, Error);
		Raise;
	EndTry;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterAnalyzeStatisticsOperationBuffer", BeginTime);
	EndIf;
EndProcedure

Procedure AggregateStatisticsOperationsMeasurements(CurrentDate)
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("AggregationPeriodMinor, AggregationPeriod, AggregationBoundary"));
	AggregationPeriod = MonitoringCenterParameters.AggregationPeriodMinor;
	DeletionPeriod = MonitoringCenterParameters.AggregationPeriod;
	
	AggregationBoundary = MonitoringCenterParameters.AggregationBoundary;
	ProcessRecordsUntil = Date(1, 1, 1) + Int((CurrentDate - Date(1, 1, 1))/AggregationPeriod)*AggregationPeriod;
	
	If ProcessRecordsUntil > AggregationBoundary Then
		BeginTransaction();
		Try
			QueryResultOperationsAggregated = InformationRegisters.MeasurementsStatisticsOperations.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			QueryResultCommentAggregated = InformationRegisters.MeasurementsStatisticsComments.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			QueryResultAreasAggregated = InformationRegisters.MeasurementsStatisticsAreas.GetAggregatedRecords(AggregationBoundary, ProcessRecordsUntil, AggregationPeriod, DeletionPeriod);
			
			InformationRegisters.MeasurementsStatisticsOperations.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			InformationRegisters.MeasurementsStatisticsComments.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			InformationRegisters.MeasurementsStatisticsAreas.DeleteRecords(AggregationBoundary, ProcessRecordsUntil);
			
			InformationRegisters.MeasurementsStatisticsOperations.WriteMeasurements(QueryResultOperationsAggregated);
			InformationRegisters.MeasurementsStatisticsComments.WriteMeasurements(QueryResultCommentAggregated);
			InformationRegisters.MeasurementsStatisticsAreas.WriteMeasurements(QueryResultAreasAggregated);
			
			SetMonitoringCenterParameter("AggregationBoundary", ProcessRecordsUntil);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Monitoring center.Aggregate measurements of statistics operations ';", 
				Common.DefaultLanguageCode()), EventLogLevel.Error,,, 
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
	EndIf;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterAggregateStatisticsOperationsMeasurements", BeginTime);
	EndIf;
EndProcedure

Procedure StatisticsOperationsRegistration()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	CurrentDate = CurrentUniversalDate();
	
	ParseStatisticsOperationsBuffer(CurrentDate);
	AggregateStatisticsOperationsMeasurements(CurrentDate);
	DeleteObsoleteStatisticsOperationsData();
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterStatisticsOperationRegistration", BeginTime);
	EndIf;
EndProcedure

Procedure DeleteObsoleteStatisticsOperationsData()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("LastPackageDate, DeletionPeriod"));
	
	LastPackageDate = MonitoringCenterParameters.LastPackageDate;
	DeletionPeriod = MonitoringCenterParameters.DeletionPeriod;
	
	DeletionBoundary = Date(1,1,1) + Int((LastPackageDate - Date(1,1,1))/DeletionPeriod) * DeletionPeriod;
	
	BeginTransaction();
	Try
		InformationRegisters.MeasurementsStatisticsOperations.DeleteRecords(Date(1,1,1), DeletionBoundary);
		InformationRegisters.MeasurementsStatisticsComments.DeleteRecords(Date(1,1,1), DeletionBoundary);
		InformationRegisters.MeasurementsStatisticsAreas.DeleteRecords(Date(1,1,1), DeletionBoundary);
		InformationRegisters.StatisticsMeasurements.DeleteRecords(Date(1,1,1), DeletionBoundary);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center.Delete obsolete data of statistics operations ';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error,,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterDeleteOutdatedStatisticsOperationData", BeginTime);
	EndIf;
EndProcedure

#EndRegion

#Region WorkWithJSON

Function GenerateJSONStructure(SectionName1, Data, AdditionalParameters = Undefined)
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Map;
	EndIf;
	
	StartDate = AdditionalParameters["StartDate"];
	EndDate = AdditionalParameters["EndDate"];
	AddlParameters = AdditionalParameters["AddlParameters"];
	IndexColumns = AdditionalParameters["IndexColumns"];
	
	If TypeOf(Data) = Type("QueryResult") Then
		JSONStructure = GenerateJSONStructureQueryResult(SectionName1, Data, StartDate, EndDate, AddlParameters, IndexColumns);
	ElsIf TypeOf(Data) = Type("ValueTable") Then
		JSONStructure = GenerateJSONStructureValueTable(SectionName1, Data, StartDate, EndDate, AddlParameters, IndexColumns);
	EndIf;
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureQueryResult(SectionName1, Data, StartDate, EndDate, AddlParameters, IndexColumns)
	JSONStructure = New Map;
	
	Section3 = New Structure;
	
	
	If StartDate <> Undefined Then
		Section3.Insert("date_start", StartDate);
	EndIf;
	
	If EndDate <> Undefined Then
		Section3.Insert("date_end", EndDate);
	EndIf;
	
	If AddlParameters <> Undefined Then
		For Each Parameter In AddlParameters Do
			Section3.Insert(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
			
	Rows = New Array;
	Selection = Data.Select();
	// Used to store data structure.
	CollectionsStructures = New Structure;
	// Used to store collection data as a key field - attributes with values.
	CollectionsMaps = New Map; 
	// List of columns to exclude from the dataset. Send the columns' data to CollectionsMaps.
	ColumnsToExclude = New Map;
	If IndexColumns <> Undefined Then
		ValuesIndexes = New Map;
		For Each CurColumn In IndexColumns Do
			ValuesIndexes.Insert(CurColumn.Key, New Map);
			If CurColumn.Value.Count() Then
				CollectionsMaps.Insert(CurColumn.Key, New Map);
				ObjectStructure = New Structure;
				For Each Record In CurColumn.Value Do
					ObjectStructure.Insert(Record.Key);
					ColumnsToExclude.Insert(Record.Key, True);
				EndDo;
				CollectionsStructures.Insert(CurColumn.Key, ObjectStructure);
			EndIf;
		EndDo;
	EndIf;
	
	Columns = New Array;
	For Each CurColumn In Data.Columns Do
		If ColumnsToExclude[CurColumn.Name] = True Then
			Continue;
		EndIf;
		Columns.Add(CurColumn.Name);
	EndDo;
	Section3.Insert("columns", Columns);
	
	While Selection.Next() Do
		String = New Array;
		For Each CurColumn In Columns Do
			ValueToAdd1 = Selection[CurColumn];
			If IndexColumns <> Undefined And IndexColumns[CurColumn] <> Undefined Then
				If IndexColumns[CurColumn][ValueToAdd1] = Undefined Then
					ValueIndex = IndexColumns[CurColumn].Count() + 1;
					IndexColumns[CurColumn].Insert(ValueToAdd1, ValueIndex);
					ValuesIndexes[CurColumn].Insert(Format(ValueIndex, "NG=0"), ValueToAdd1);
				EndIf;
				
				ValueToAdd1 = IndexColumns[CurColumn][ValueToAdd1];
			EndIf;
			
			If CollectionsStructures.Property(CurColumn) 
				And CollectionsMaps[CurColumn][Selection[CurColumn]] = Undefined Then
				ObjectMap = New Map;
				For Each Record In CollectionsStructures[CurColumn] Do
					ObjectMap.Insert(Record.Key, Selection[Record.Key]);
				EndDo;
				CollectionsMaps[CurColumn].Insert(Selection[CurColumn], ObjectMap);
			EndIf;
			
			String.Add(ValueToAdd1);
		EndDo;
		Rows.Add(String);
	EndDo;
	
	For Each Record In CollectionsMaps Do
		Section3.Insert(Record.Key, Record.Value);
	EndDo;
	Section3.Insert("columnsValueIndex", ValuesIndexes);
	Section3.Insert("rows", Rows);		
	
	JSONStructure.Insert(SectionName1, Section3);
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureValueTable(SectionName1, Data, StartDate, EndDate, AddlParameters, IndexColumns)
	JSONStructure = New Map;
	
	Section3 = New Structure;
	
	
	If StartDate <> Undefined Then
		Section3.Insert("date_start", StartDate);
	EndIf;
	
	If EndDate <> Undefined Then
		Section3.Insert("date_end", EndDate);
	EndIf;
	
	If AddlParameters <> Undefined Then
		For Each Parameter In AddlParameters Do
			Section3.Insert(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
			
	Rows = New Array;
	// Used to store data structure.
	CollectionsStructures = New Structure;
	// Used to store collection data as a key field - attributes with values.
	CollectionsMaps = New Map; 
	// List of columns to exclude from the dataset. Send the columns' data to CollectionsMaps.
	ColumnsToExclude = New Map;
	If IndexColumns <> Undefined Then
		ValuesIndexes = New Map;
		For Each CurColumn In IndexColumns Do
			ValuesIndexes.Insert(CurColumn.Key, New Map);
			If CurColumn.Value.Count() Then
				CollectionsMaps.Insert(CurColumn.Key, New Map);
				ObjectStructure = New Structure;
				For Each Record In CurColumn.Value Do
					ObjectStructure.Insert(Record.Key);
					ColumnsToExclude.Insert(Record.Key, True);
				EndDo;
				CollectionsStructures.Insert(CurColumn.Key, ObjectStructure);
			EndIf;
		EndDo;
	EndIf;
	
	Columns = New Array;
	For Each CurColumn In Data.Columns Do
		If ColumnsToExclude[CurColumn.Name] = True Then
			Continue;
		EndIf;
		Columns.Add(CurColumn.Name);
	EndDo;
	Section3.Insert("columns", Columns);
	
	For Each Selection In Data Do
		String = New Array;
		For Each CurColumn In Columns Do
			ValueToAdd1 = Selection[CurColumn];
			If IndexColumns <> Undefined And IndexColumns[CurColumn] <> Undefined Then
				If IndexColumns[CurColumn][ValueToAdd1] = Undefined Then
					ValueIndex = IndexColumns[CurColumn].Count() + 1;
					IndexColumns[CurColumn].Insert(ValueToAdd1, ValueIndex);
					ValuesIndexes[CurColumn].Insert(Format(ValueIndex, "NG=0"), ValueToAdd1);
				EndIf;
				
				ValueToAdd1 = IndexColumns[CurColumn][ValueToAdd1];
			EndIf;
			
			If CollectionsStructures.Property(CurColumn) 
				And CollectionsMaps[CurColumn][Selection[CurColumn]] = Undefined Then
				ObjectMap = New Map;
				For Each Record In CollectionsStructures[CurColumn] Do
					ObjectMap.Insert(Record.Key, Selection[Record.Key]);
				EndDo;
				CollectionsMaps[CurColumn].Insert(Selection[CurColumn], ObjectMap);
			EndIf;
			
			String.Add(ValueToAdd1);
		EndDo;
		Rows.Add(String);
	EndDo;
	
	For Each Record In CollectionsMaps Do
		Section3.Insert(Record.Key, Record.Value);
	EndDo;
	Section3.Insert("columnsValueIndex", ValuesIndexes);
	Section3.Insert("rows", Rows);		
	
	JSONStructure.Insert(SectionName1, Section3);
	
	Return JSONStructure;
EndFunction

Function GenerateJSONStructureForSending(Parameters)
	StartDate = Parameters.StartDate;
	EndDate = Parameters.EndDate;
	
	TopDumpsQuantity = Parameters.TopDumpsQuantity;
	TopApdex = Parameters.TopApdex;
	TopApdexTech = Parameters.TopApdexTech;
	DeletionPeriod = Parameters.DeletionPeriod;
	
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("InfoBaseID");
	MonitoringCenterParameters.Insert("InfobaseIDPermanent");
	MonitoringCenterParameters.Insert("RegisterSystemInformation");
	MonitoringCenterParameters.Insert("RegisterSubsystemVersions");
	MonitoringCenterParameters.Insert("RegisterDumps");
	MonitoringCenterParameters.Insert("RegisterBusinessStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
	MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
	MonitoringCenterParameters.Insert("RegisterPerformance");
	MonitoringCenterParameters.Insert("RegisterTechnologicalPerformance");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsNextSending");
	MonitoringCenterParameters.Insert("ConfigurationStatisticsSendingPeriod");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	ShouldSendConfigurationStatistics = Parameters.StartDate2 >= MonitoringCenterParameters.ConfigurationStatisticsNextSending;
	
	If MonitoringCenterParameters.RegisterSystemInformation Then
		Info = GetSystemInformation1();
	EndIf;
	
	If MonitoringCenterParameters.RegisterSubsystemVersions And ShouldSendConfigurationStatistics Then
		Subsystems = SubsystemsVersions();
	EndIf;
	
	
	If MonitoringCenterParameters.RegisterDumps Then
		TopDumps = InformationRegisters.PlatformDumps.GetTopOptions(StartDate, EndDate, TopDumpsQuantity,, True);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		DUMPSSection = GenerateJSONStructure("dumps", TopDumps, AdditionalParameters);
	EndIf;
	
	If MonitoringCenterParameters.RegisterBusinessStatistics Then
		
		QueryResult = InformationRegisters.MeasurementsStatisticsOperations.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSection = GenerateJSONStructure("OperationStatistics", QueryResult, AdditionalParameters);
		StatisticsOperationsSection["OperationStatistics"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.MeasurementsStatisticsComments.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		IndexColumns.Insert("StatisticsComment", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsCommentsSection = GenerateJSONStructure("CommentsStatistics", QueryResult, AdditionalParameters);
		
		StatisticsCommentsSection["CommentsStatistics"]["columnsValueIndex"].Delete("StatisticsOperation");
		StatisticsCommentsSection["CommentsStatistics"]["columnsValueIndex"].Delete("Period");
		StatisticsCommentsSection["CommentsStatistics"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.MeasurementsStatisticsAreas.GetMeasurements(StartDate, EndDate, DeletionPeriod);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		IndexColumns.Insert("StatisticsArea", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("StartDate", StartDate);
		AdditionalParameters.Insert("EndDate", EndDate);
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsAreasSection = GenerateJSONStructure("StatisticalAreas", QueryResult, AdditionalParameters);
		StatisticsAreasSection["StatisticalAreas"]["columnsValueIndex"].Delete("StatisticsOperation");
		StatisticsAreasSection["StatisticalAreas"]["columnsValueIndex"].Delete("Period");
		StatisticsAreasSection["StatisticalAreas"].Insert("AggregationPeriod", DeletionPeriod);
		
		QueryResult = InformationRegisters.StatisticsMeasurements.GetHourMeasurements(StartDate, EndDate);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSectionClientHour = GenerateJSONStructure("OperationStatisticsClientHour", QueryResult, AdditionalParameters);
		
		QueryResult = InformationRegisters.StatisticsMeasurements.GetDayMeasurements(StartDate, EndDate);
		IndexColumns = New Map;
		IndexColumns.Insert("StatisticsOperation", New Map);
		IndexColumns.Insert("Period", New Map);
		
		AdditionalParameters = New Map;
		AdditionalParameters.Insert("IndexColumns", IndexColumns);
		StatisticsOperationsSectionClientDay = GenerateJSONStructure("OperationStatisticsClientDay", QueryResult, AdditionalParameters);
		
	EndIf;
	
	SeparationByDataAreasEnabled = SeparationByDataAreasEnabled();
	
	#Region StatisticsConfigurationSection
	If MonitoringCenterParameters.RegisterConfigurationStatistics And ShouldSendConfigurationStatistics Then
		If SeparationByDataAreasEnabled Then
			QueryResultNames = InformationRegisters.ConfigurationStatistics.GetStatisticsNames(0);
			ValueTableNames = QueryResultNames.Unload();
			
			Array = New Array;
			KCH_10_0 = New NumberQualifiers(10, 0, AllowedSign.Nonnegative);
			Array.Add(Type("Number"));
			TypesDetailsNumber_10_0 = New TypeDescription(Array, KCH_10_0,,,);
			ValueTableNames.Columns.Add("RowIndex", TypesDetailsNumber_10_0);
			MetadataNamesStructure = New Map;
			For Each CurRow In ValueTableNames Do
				RowIndex = ValueTableNames.IndexOf(CurRow);
				CurRow.RowIndex = RowIndex;
				MetadataNamesStructure.Insert(RowIndex, CurRow.StatisticsOperationDescription); 
			EndDo;
			
			ConfigurationStatisticsSection = New Structure("StatisticsConfiguration", New Structure);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("MetadataName", Metadata.Name);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("MetadataIndexName", New Map);
			For Each CurRow In ValueTableNames Do
				ConfigurationStatisticsSection.StatisticsConfiguration.MetadataIndexName.Insert(String(CurRow.RowIndex), CurRow.StatisticsOperationDescription);
			EndDo;
						
			ConfigurationStatisticsSection.StatisticsConfiguration.Insert("StatisticsConfigurationByRegions", New Map);
			DataAreasResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasResult.Select();
			While Selection.Next() Do
				DataAreaRow = String(Selection.DataArea);
				DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaRow);
				
				If InformationRegisters.StatisticsAreas.ShouldCollectStatistics(DataAreaRow) Then
					QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(0, ValueTableNames, DataAreaRef);
					AreaConfigurationStatistics = GenerateJSONStructure(DataAreaRow, QueryResult);
					ConfigurationStatisticsSection.StatisticsConfiguration.StatisticsConfigurationByRegions.Insert(DataAreaRow, AreaConfigurationStatistics[DataAreaRow]); 
				EndIf;
			EndDo;
			DataOnUsedExtensions = New Structure;
		Else
			QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(0);
			AddlParameters = New Structure("MetadataName", Metadata.Name);
			AddlParameters.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			AddlParameters.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			AddlParameters.Insert("CompatibilityMode", String(Metadata.CompatibilityMode));
			AddlParameters.Insert("InterfaceCompatibilityMode", String(Metadata.InterfaceCompatibilityMode));
			AddlParameters.Insert("ModalityUseMode", String(Metadata.ModalityUseMode));
			DataOnUsedExtensions = DataOnUsedExtensions();
			DataOnRolesUsage = DataOnRolesUsage();
			AddlParameters.Insert("UsingExtensions", DataOnUsedExtensions.ExtensionsUsage);
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("AddlParameters", AddlParameters);
			ConfigurationStatisticsSection = GenerateJSONStructure("StatisticsConfiguration", QueryResult, AdditionalParameters);
		EndIf;
	EndIf;
	#EndRegion
	
	#Region OptionsSection
	If MonitoringCenterParameters.RegisterConfigurationSettings And ShouldSendConfigurationStatistics Then
		If SeparationByDataAreasEnabled Then
			QueryResultNames = InformationRegisters.ConfigurationStatistics.GetStatisticsNames(1);
			ValueTableNames = QueryResultNames.Unload();
			
			Array = New Array;
			KCH_10_0 = New NumberQualifiers(10, 0, AllowedSign.Nonnegative);
			Array.Add(Type("Number"));
			TypesDetailsNumber_10_0 = New TypeDescription(Array, KCH_10_0,,,);
			ValueTableNames.Columns.Add("RowIndex", TypesDetailsNumber_10_0);
			MetadataNamesStructure = New Map;
			For Each CurRow In ValueTableNames Do
				RowIndex = ValueTableNames.IndexOf(CurRow);
				CurRow.RowIndex = RowIndex;
				MetadataNamesStructure.Insert(RowIndex, CurRow.StatisticsOperationDescription); 
			EndDo;
			
			ConfigurationSettingSection = New Structure("Options", New Structure);
			ConfigurationSettingSection.Options.Insert("MetadataName", Metadata.Name);
			ConfigurationSettingSection.Options.Insert("WorkingMode", ?(Common.FileInfobase(), "F", "S"));
			ConfigurationSettingSection.Options.Insert("DivisionByRegions", SeparationByDataAreasEnabled);
			ConfigurationSettingSection.Options.Insert("MetadataIndexName", New Map);
			For Each CurRow In ValueTableNames Do
				ConfigurationSettingSection.Options.MetadataIndexName.Insert(String(CurRow.RowIndex), CurRow.StatisticsOperationDescription);
			EndDo;
			
			ConfigurationSettingSection.Options.Insert("OptionsByRegions", New Map);
			DataAreasResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasResult.Select();
			While Selection.Next() Do
				DataAreaRow = String(Selection.DataArea);
				DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaRow);
				
				If InformationRegisters.StatisticsAreas.ShouldCollectStatistics(DataAreaRow) Then
					QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(1, ValueTableNames, DataAreaRef);
					AreaConfigurationStatistics = GenerateJSONStructure(DataAreaRow, QueryResult);
					ConfigurationSettingSection.Options.OptionsByRegions.Insert(DataAreaRow, AreaConfigurationStatistics[DataAreaRow]); 
				EndIf;
			EndDo;
		Else
			QueryResult = InformationRegisters.ConfigurationStatistics.GetStatistics(1);
			AddlParameters = New Structure("MetadataName", Metadata.Name);
			AddlParameters.Insert("WorkingMode", ?(Common.FileInfobase(), 0, 1));
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("AddlParameters", AddlParameters);
			ConfigurationSettingSection = GenerateJSONStructure("Options", QueryResult, AdditionalParameters);
		EndIf;
	EndIf;
	#EndRegion
		
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitorInternal = Common.CommonModule("PerformanceMonitorInternal");
		
		If MonitoringCenterParameters.RegisterPerformance Then
			QueryResult = ModulePerformanceMonitorInternal.GetAPDEXTop(StartDate, EndDate, DeletionPeriod, TopApdex);
			IndexColumns = New Map;
			IndexColumns.Insert("Period", New Map);
			KeyOperationCollection = New Map;
			KeyOperationCollection.Insert("KOD");
			KeyOperationCollection.Insert("KON");
			IndexColumns.Insert("KOHash", KeyOperationCollection);
						
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("EndDate", AddlParameters);
			AdditionalParameters.Insert("IndexColumns", IndexColumns);
			TopAPDEXSection = GenerateJSONStructure("TopApdex", QueryResult, AdditionalParameters);	
			TopAPDEXSection["TopApdex"].Insert("AggregationPeriod", DeletionPeriod);
		EndIf;
		
		If MonitoringCenterParameters.RegisterTechnologicalPerformance Then
			QueryResult = ModulePerformanceMonitorInternal.GetTopTechnologicalAPDEX(StartDate, EndDate, DeletionPeriod, TopApdexTech);
			IndexColumns = New Map;
			IndexColumns.Insert("Period", New Map);
			KeyOperationCollection = New Map;
			KeyOperationCollection.Insert("KOD");
			KeyOperationCollection.Insert("KON");
			IndexColumns.Insert("KOHash", KeyOperationCollection);
			
			AdditionalParameters = New Map;
			AdditionalParameters.Insert("StartDate", StartDate);
			AdditionalParameters.Insert("EndDate", AddlParameters);
			AdditionalParameters.Insert("IndexColumns", IndexColumns);
			TopAPDEXSectionInternal = GenerateJSONStructure("TopApdexTechnology", QueryResult, AdditionalParameters);
			TopAPDEXSectionInternal["TopApdexTechnology"].Insert("AggregationPeriod", DeletionPeriod);
		EndIf;
	EndIf;
	
	InfoBaseID = String(MonitoringCenterParameters.InfoBaseID);
	InfobaseIDPermanent = String(MonitoringCenterParameters.InfobaseIDPermanent);
	JSONStructure = New Structure;
	JSONStructure.Insert("id",  InfoBaseID);
	JSONStructure.Insert("idConst",  InfobaseIDPermanent);
	JSONStructure.Insert("versionPacket",  "1.0.10.0");
	JSONStructure.Insert("datePacket",  CurrentUniversalDate());
	
	If MonitoringCenterParameters.RegisterSystemInformation Then
		JSONStructure.Insert("info",  Info);
	EndIf;
	
	If MonitoringCenterParameters.RegisterSubsystemVersions And ShouldSendConfigurationStatistics Then
		JSONStructure.Insert("versions",  Subsystems);
	EndIf;
		
	If MonitoringCenterParameters.RegisterDumps Then
		JSONStructure.Insert("dumps", DUMPSSection["dumps"]);
		DataOnFullDumps = New Structure;
		DataOnFullDumps.Insert("sendingResult", Parameters.SendingResult);
		DataOnFullDumps.Insert("sendDumps", Parameters.SendDumpsFiles);
		DataOnFullDumps.Insert("askBeforeSending", Parameters.RequestConfirmationBeforeSending);
		JSONStructure.Insert("FullDumps", DataOnFullDumps);		
	EndIf;
	
	If MonitoringCenterParameters.RegisterBusinessStatistics Then
		BusinessStatistics = New Structure;
		BusinessStatistics.Insert("OperationStatistics", StatisticsOperationsSection["OperationStatistics"]);
		BusinessStatistics.Insert("CommentsStatistics", StatisticsCommentsSection["CommentsStatistics"]);
		BusinessStatistics.Insert("StatisticalAreas", StatisticsAreasSection["StatisticalAreas"]);
		BusinessStatistics.Insert("OperationStatisticsClientHour", StatisticsOperationsSectionClientHour["OperationStatisticsClientHour"]);
		BusinessStatistics.Insert("OperationStatisticsClientDay", StatisticsOperationsSectionClientDay["OperationStatisticsClientDay"]);
		JSONStructure.Insert("business", BusinessStatistics);
	EndIf;
	
		If MonitoringCenterParameters.RegisterConfigurationStatistics And ShouldSendConfigurationStatistics Then
		JSONStructure.Insert("config", ConfigurationStatisticsSection["StatisticsConfiguration"]);
		JSONStructure.Insert("extensionsInfo", DataOnUsedExtensions);
		JSONStructure.Insert("statisticOfRoles", DataOnRolesUsage);
	EndIf;
	
	If MonitoringCenterParameters.RegisterConfigurationSettings And ShouldSendConfigurationStatistics Then
		JSONStructure.Insert("options", ConfigurationSettingSection["Options"]);
	EndIf;
		
	If PerformanceMonitorExists Then
		If MonitoringCenterParameters.RegisterPerformance Then
			JSONStructure.Insert("perf", TopAPDEXSection["TopApdex"]);
		EndIf;
		
		If MonitoringCenterParameters.RegisterTechnologicalPerformance Then
			JSONStructure.Insert("internal_perf", TopAPDEXSectionInternal["TopApdexTechnology"]);
		EndIf;
	EndIf;
	
	If Parameters.ContactInformationChanged 
		And (Parameters.ContactInformationRequest = 0 
		Or Parameters.ContactInformationRequest = 1) Then
		ContactInformation = New Structure;
		ContactInformation.Insert("ContactInformationRequest", Parameters.ContactInformationRequest);
		ContactInformation.Insert("ContactInformation", Parameters.ContactInformation);
		ContactInformation.Insert("ContactInformationComment1", Parameters.ContactInformationComment1);
		ContactInformation.Insert("PortalUsername", Parameters.PortalUsername);
		JSONStructure.Insert("contacts", ContactInformation);		
	EndIf;
	
	If ShouldSendConfigurationStatistics Then		
		SetMonitoringCenterParameter("ConfigurationStatisticsNextSending", Parameters.StartDate2 + MonitoringCenterParameters.ConfigurationStatisticsSendingPeriod);				
	EndIf;
			
	Return JSONStructure;
EndFunction

Function JSONStructureToString(JSONStructure) Export
	JSONWriter = New JSONWriter;
	JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
	WriteJSON(JSONWriter, JSONStructure);
		
	Return JSONWriter.Close();
EndFunction

#EndRegion

#Region WorkWithHTTPService

Function HTTPServiceSendDataInternal(Parameters)
	
	SecureConnection = Undefined;
	If Parameters.SecureConnection Then
		SecureConnection = CommonClientServer.NewSecureConnection();
	EndIf;
	
	InternetProxy = Undefined;
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownload = Common.CommonModule("GetFilesFromInternet");
		InternetProxy = ModuleNetworkDownload.GetProxy("https");
	EndIf;
	
	HTTPConnection = New HTTPConnection(
		Parameters.Server, Parameters.Port,,,
		InternetProxy,
		Parameters.Timeout, 
		SecureConnection);
	
	HTTPRequest = New HTTPRequest(Parameters.ResourceAddress);
	
	If Parameters.DataType = "Text" Then
		HTTPRequest.SetBodyFromString(Parameters.Data);
	ElsIf Parameters.DataType = "ZIP" Then
		ArchiveFileName = WriteDataToArchive(Parameters.Data);
		BinaryDataOfArchive = New BinaryData(ArchiveFileName);
		HTTPRequest.SetBodyFromBinaryData(BinaryDataOfArchive);
	ElsIf Parameters.DataType = "BinaryData" Then
		BinaryDataOfArchive = New BinaryData(Parameters.Data);
		HTTPRequest.SetBodyFromBinaryData(BinaryDataOfArchive);
	EndIf;
	
	Try
		If Parameters.Method = "POST" Then
			HTTPResponse = HTTPConnection.Post(HTTPRequest);
		ElsIf Parameters.Method = "GET" Then
			HTTPResponse = HTTPConnection.Get(HTTPRequest);
		EndIf;
		
		HTTPResponseStructure = HTTPResponseToStructure(HTTPResponse);
		
		If HTTPResponseStructure.StatusCode = 200 Then
			If Parameters.DataType = "ZIP" Then
				DeleteFiles(ArchiveFileName);
			ElsIf Parameters.DataType = "BinaryData" Then
				DeleteFiles(Parameters.Data);
			EndIf;
		EndIf;
	Except
		HTTPResponseStructure = New Structure("StatusCode", 105);
	EndTry;
	
	Return HTTPResponseStructure;
EndFunction

Function WriteDataToArchive(Data)
	DataFileName = GetTempFileName("txt");
	ArchiveFileName = GetTempFileName("zip");
	
	TextWriter = New TextWriter(DataFileName);
	TextWriter.Write(Data);
	TextWriter.Close();
	
	ZipArchive = New ZipFileWriter(ArchiveFileName,,,ZIPCompressionMethod.Deflate,ZIPCompressionLevel.Maximum);
	ZipArchive.Add(DataFileName, ZIPStorePathMode.DontStorePath);
	ZipArchive.Write();
	
	DeleteFiles(DataFileName);
	
	Return ArchiveFileName; 
EndFunction

Function HTTPResponseToStructure(Response)
	Result = New Structure;
	
	Result.Insert("StatusCode", Response.StatusCode);
	Result.Insert("Headers",  New Map);
	For Each Parameter In Response.Headers Do
		Result.Headers.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	HTTPHeaders = HTTPHeadersInLowercase(Response.Headers);
	If HTTPHeaders["content-type"] <> Undefined Then
		MIMEType = HTTPHeaders["content-type"];
		If StrFind(MIMEType, "text/plain") > 0 Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		ElsIf StrFind(MIMEType, "text/html") > 0 Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		ElsIf StrFind(MIMEType, "application/json") Then
			Body = Response.GetBodyAsString();
			Result.Insert("Body", Body);
		Else
			Body = "Not known ContentType = " + MIMEType + ". See. <Function HTTPResponseToStructure(Response) Export>";
			Result.Insert("Body", Body);
		EndIf;
	EndIf;	
	
	Return Result;
EndFunction

Function HTTPHeadersInLowercase(Headers)
	
	Result = New Map;
	For Each Title In Headers Do
		Result.Insert(Lower(Title.Key), Title.Value);
	EndDo;
	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithDumpsRegistration

Procedure DumpsRegistration()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	DumpType = GetMonitoringCenterParameters("DumpType");
	DumpsDirectory = GetDumpsDirectory(DumpType);
	
	If DumpsDirectory.Path <> Undefined Then
		// Check if it is necessary to notify Administrator of process failure.
		CheckIfNotificationOfDumpsIsRequired(DumpsDirectory.Path);
		If DumpsDirectory.DeleteDumps Then
			DumpsToDelete = InformationRegisters.PlatformDumps.GetDumpsToDelete();
			
			For Each DumpToDelete In DumpsToDelete Do
				File = New File(DumpToDelete.FileName);
				If File.Exists() Then
					Try
						DeleteFiles(File.FullName);
						DumpToDelete.FileName = "";
						InformationRegisters.PlatformDumps.ChangeRecord(DumpToDelete);
					Except
						WriteLogEvent(EventLogEventMonitoringCenterDumpDeletion(), 
							EventLogLevel.Error,,,
							ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					EndTry;
				Else
					DumpToDelete.FileName = "";
					InformationRegisters.PlatformDumps.ChangeRecord(DumpToDelete);
				EndIf;
			EndDo;
		EndIf;
		
		DumpsFiles = FindFiles(DumpsDirectory.Path, "*.mdmp");
		DumpsFilesNames = New Array;
		For Each DumpFile In DumpsFiles Do
			DumpsFilesNames.Add(DumpFile.FullName);
		EndDo;
		
		DumpsFilesRegistered = InformationRegisters.PlatformDumps.GetRegisteredDumps(DumpsFilesNames);
		
		For Each DumpFile In DumpsFiles Do
			If DumpsFilesRegistered[DumpFile.FullName] = Undefined Then 
				DumpNew = New Structure;
				DumpStructure = DumpDetails(DumpFile.Name);
				
				DumpNew.Insert("RegistrationDate", CurrentUniversalDateInMilliseconds());
				DumpNew.Insert("DumpOption", DumpStructure.Process_ + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset);
				DumpNew.Insert("PlatformVersion", PlatformVersionToNumber(DumpStructure.PlatformVersion));
				DumpNew.Insert("FileName", DumpFile.FullName);
				
				InformationRegisters.PlatformDumps.ChangeRecord(DumpNew);
			EndIf;
		EndDo;
	Else
		SetMonitoringCenterParameter("RegisterDumps", False);
	EndIf;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterDumpRegistration", BeginTime);
	EndIf;
EndProcedure

#EndRegion

#Region WorkWithConfigurationStatistics

Procedure CollectConfigurationStatistics1(MonitoringCenterParameters = Undefined)
	If MonitoringCenterParameters = Undefined Then
		MonitoringCenterParameters.Insert("RegisterConfigurationStatistics");
		MonitoringCenterParameters.Insert("RegisterConfigurationSettings");
		MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	EndIf;
	
	// 
	// 
	// 
	//
	#Region BaseConfigurationStatistics
	
	If MonitoringCenterParameters.RegisterConfigurationStatistics Or  MonitoringCenterParameters.RegisterConfigurationSettings Then
		
		PerformanceMonitorRecordRequired = False;
		
		InformationRegisters.ConfigurationStatistics.ClearConfigurationStatistics();
		
		PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
			BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
		EndIf;
		
		If MonitoringCenterParameters.RegisterConfigurationStatistics Then
			InformationRegisters.ConfigurationStatistics.WriteConfigurationStatistics();
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If MonitoringCenterParameters.RegisterConfigurationSettings Then
			InformationRegisters.ConfigurationStatistics.WriteConfigurationSettings();
			GetFullTextSearchUsageStatistics();
			PerformanceMonitorRecordRequired = True;
		EndIf;
		
		If PerformanceMonitorExists And PerformanceMonitorRecordRequired Then
			ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectConfigurationStatisticalDataBasic", BeginTime);
		EndIf;
	EndIf;
	
	#EndRegion
	
	// 
	// 
	// 
	//
	#Region ConfigurationStatisticsStandardSubsystems
	
	If MonitoringCenterParameters.RegisterConfigurationStatistics Then
		If PerformanceMonitorExists Then
			BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
		EndIf;
		
		SeparationByDataAreasEnabled = SeparationByDataAreasEnabled();
		If SeparationByDataAreasEnabled Then
			DataAreasQueryResult = InformationRegisters.ConfigurationStatistics.GetDataAreasQueryResult();
			Selection = DataAreasQueryResult.Select();
			While Selection.Next() Do
				DataAreaRow = String(Selection.DataArea);
				If InformationRegisters.StatisticsAreas.ShouldCollectStatistics(DataAreaRow) Then
					Try
						SignInToDataArea(Selection.DataArea);
					Except
						WriteLogEvent(NStr("en = 'Monitoring center.Configuration statistics overridable ';", 
							Common.DefaultLanguageCode()), EventLogLevel.Error,,,
							NStr("en = 'Couldn''t set session separation. Data area';", Common.DefaultLanguageCode()) 
								+ " = " + Format(Selection.DataArea, "NG=0") + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo()));
						SignOutOfDataArea();
						Continue;
					EndTry;
					
					SSLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
					MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters();
					SignOutOfDataArea();
				EndIf;
			EndDo;
		Else
			SSLSubsystemsIntegration.OnCollectConfigurationStatisticsParameters();
			MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters();
		EndIf;
		
		If PerformanceMonitorExists Then
			ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterCollectConfigurationStatisticalDataStandardSubsystems", BeginTime);
		EndIf;
	EndIf;
	
	#EndRegion
	
EndProcedure

#EndRegion

#Region WorkWithPackagesToSend

Procedure CreatePackageToSend()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	CurDate = CurrentUniversalDate(); 
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	
	Parameters = New Structure;
	Parameters.Insert("StartDate", Date(1,1,1) + Int((MonitoringCenterParameters.LastPackageDate - Date(1,1,1))/MonitoringCenterParameters.DeletionPeriod) * MonitoringCenterParameters.DeletionPeriod);
	Parameters.Insert("EndDate", Date(1,1,1) + Int((CurDate - Date(1,1,1))/MonitoringCenterParameters.DeletionPeriod) * MonitoringCenterParameters.DeletionPeriod - 1);
	Parameters.Insert("StartDate2", CurDate);
	Parameters.Insert("TopDumpsQuantity", 5);
	Parameters.Insert("TopApdex", MonitoringCenterParameters.TopApdex);
	Parameters.Insert("TopApdexTech", MonitoringCenterParameters.TopApdexTech);
	Parameters.Insert("DeletionPeriod", MonitoringCenterParameters.DeletionPeriod);
	Parameters.Insert("SendingResult", MonitoringCenterParameters.SendingResult);
	Parameters.Insert("SendDumpsFiles", MonitoringCenterParameters.SendDumpsFiles);
	Parameters.Insert("RequestConfirmationBeforeSending", MonitoringCenterParameters.RequestConfirmationBeforeSending);
	// 
	Parameters.Insert("ContactInformationRequest", MonitoringCenterParameters.ContactInformationRequest);
	Parameters.Insert("ContactInformation", MonitoringCenterParameters.ContactInformation);
	Parameters.Insert("ContactInformationComment1", MonitoringCenterParameters.ContactInformationComment1);
	Parameters.Insert("PortalUsername", MonitoringCenterParameters.PortalUsername);
	Parameters.Insert("ContactInformationChanged", MonitoringCenterParameters.ContactInformationChanged);
		
	BeginTransaction();
	Try
		JSONStructure = GenerateJSONStructureForSending(Parameters);
		InformationRegisters.PackagesToSend.WriteNewPackage(CurDate, JSONStructure, MonitoringCenterParameters.LastPackageNumber + 1);
		
		MonitoringCenterParametersRecord = New Structure("LastPackageDate, LastPackageNumber");
		MonitoringCenterParametersRecord.LastPackageDate = CurDate;
		MonitoringCenterParametersRecord.LastPackageNumber = MonitoringCenterParameters.LastPackageNumber + 1;
		SetMonitoringCenterParameters(MonitoringCenterParametersRecord);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center.Generate a package for sending';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error,,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	InformationRegisters.PackagesToSend.DeleteOldPackages();
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterGeneratePackageToSend", BeginTime);
	EndIf;
EndProcedure

Function SendMonitoringData(TestPackage = False)
	Parameters = GetSendServiceParameters();
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	NumbersOfPackagesToSend = InformationRegisters.PackagesToSend.GetPackagesNumbers();
	For Each PackageNumber In NumbersOfPackagesToSend Do
		Package = InformationRegisters.PackagesToSend.GetPackage(PackageNumber);
		If Package <> Undefined Then
						
			PackageHash = Package.PackageHash;
			PackageForSendingNumber = Format(Package.PackageNumber, "NZ=0; NG=0");
			Id = String(Parameters.InfoBaseID);
			
			ResourceAddress = Parameters.ResourceAddress;
			If Right(ResourceAddress, 1) <> "/" Then
				ResourceAddress = ResourceAddress + "/";
			EndIf;
			ResourceAddress = ResourceAddress + Id + "/" + PackageForSendingNumber + "/" + PackageHash;
			
			HTTPParameters = New Structure;
			HTTPParameters.Insert("Server", Parameters.Server);
			HTTPParameters.Insert("ResourceAddress", ResourceAddress);
			HTTPParameters.Insert("Data", Package.PackageBody);
			HTTPParameters.Insert("Port", Parameters.Port);
			HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
			HTTPParameters.Insert("Method", "POST");
			HTTPParameters.Insert("DataType", "Text");
			HTTPParameters.Insert("Timeout", 60);
			
			HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
			
			If HTTPResponse.StatusCode = 200 Then
				AnswerParameters = Common.JSONValue(HTTPResponse.Body, , False);
				If Not TestPackage Then
					SetSendingParameters(AnswerParameters);
				Else
					If AnswerParameters.Property("foundCopy") And AnswerParameters.foundCopy Then
						PerformActionsOnDetectCopy();
					Else
						SetMonitoringCenterParameter("DiscoveryPackageSent", True);
					EndIf;						
				EndIf;
				InformationRegisters.PackagesToSend.DeletePackage(PackageNumber);
			Else
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterSubmitMonitoringData", BeginTime);
	EndIf;
	
	Return HTTPResponse;
EndFunction

#EndRegion

#Region WorkWithMonitoringCenterParameters

Function RunPerformanceMeasurements()
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitorServerCallCached = Common.CommonModule("PerformanceMonitorServerCallCached");
		RunPerformanceMeasurements = ModulePerformanceMonitorServerCallCached.RunPerformanceMeasurements();
	Else
		RunPerformanceMeasurements = Undefined;
	EndIf;
	
	Return RunPerformanceMeasurements;
EndFunction

Function GetDefaultParameters()
	ConstantParameters = New Structure;
	
	// 
	//
	ConstantParameters.Insert("EnableMonitoringCenter", False);
	
	// 
	// 
	//
	ConstantParameters.Insert("ApplicationInformationProcessingCenter", False);
	
	// Infobase ID.
	//
	InfoBaseID = New UUID();
	ConstantParameters.Insert("InfoBaseID", InfoBaseID);
	ConstantParameters.Insert("InfobaseIDPermanent", InfoBaseID);
	
	// 
	//
	ConstantParameters.Insert("RegisterSystemInformation", False);
	
	// 
	//
	ConstantParameters.Insert("RegisterSubsystemVersions", False);
	
	// 
	//
	ConstantParameters.Insert("DumpRegistrationNextCreation", Date(1,1,1));
	ConstantParameters.Insert("DumpRegistrationCreationPeriod", 600);
	ConstantParameters.Insert("RegisterDumps", False);
	
	// 
	//
	ConstantParameters.Insert("AggregationPeriodMinor", 60);
	ConstantParameters.Insert("AggregationPeriod", 600);
	ConstantParameters.Insert("DeletionPeriod", 3600);
	ConstantParameters.Insert("AggregationBoundary", Date(1,1,1));
	ConstantParameters.Insert("BusinessStatisticsNextSnapshot", Date(1,1,1));
	ConstantParameters.Insert("BusinessStatisticsSnapshotPeriod", 600);
	ConstantParameters.Insert("RegisterBusinessStatistics", False);
	
	// 
	//
	ConstantParameters.Insert("ConfigurationStatisticsNextGeneration", Date(1,1,1));
	ConstantParameters.Insert("ConfigurationStatisticsGenerationPeriod", 86400);
	ConstantParameters.Insert("RegisterConfigurationStatistics", False);
	ConstantParameters.Insert("RegisterConfigurationSettings", False);
	
	// 
	// 	
	// 	
	// 	
	// 	
	//
	ConstantParameters.Insert("PerformanceMonitorEnabled", 0);
	
	ConstantParameters.Insert("RegisterPerformance", False);
	ConstantParameters.Insert("TopApdex", 10);
	ConstantParameters.Insert("RegisterTechnologicalPerformance", False);
	ConstantParameters.Insert("TopApdexTech", 10);
	ConstantParameters.Insert("RunPerformanceMeasurements", RunPerformanceMeasurements());
	
	// 
	//
	ConstantParameters.Insert("SendDataNextGeneration", Date(1,1,1));
	ConstantParameters.Insert("SendDataGenerationPeriod", 607800);
	ConstantParameters.Insert("LastPackageDate", Date(1,1,1));
	ConstantParameters.Insert("ConfigurationStatisticsNextSending", Date(2010,1,1));
	ConstantParameters.Insert("ConfigurationStatisticsSendingPeriod", 607800);	
	ConstantParameters.Insert("LastPackageNumber", 0);
	ConstantParameters.Insert("PackagesToSend", 3);
	ConstantParameters.Insert("Server", "pult.1c.com");
	ConstantParameters.Insert("ResourceAddress", "pult/v1/packet/");
	ConstantParameters.Insert("DumpsResourceAddress", "pult/v1/dump/");
	ConstantParameters.Insert("Port", 443);
	ConstantParameters.Insert("SecureConnection", True);
	
	// 
	//
	// 
	//	
	//  
	//  
	ConstantParameters.Insert("SendDumpsFiles", 2);
	ConstantParameters.Insert("DumpOption", "");
	// 
	// 
	ConstantParameters.Insert("BasicChecksPassed", False); 
	ConstantParameters.Insert("RequestConfirmationBeforeSending", True);
	ConstantParameters.Insert("SendingResult", "");
	ConstantParameters.Insert("DumpsInformation", ""); // 
	ConstantParameters.Insert("SpaceReserveDisabled", 40);
	ConstantParameters.Insert("SpaceReserveEnabled", 20);
	ConstantParameters.Insert("DumpCollectingEnd", Date(2017,1,1));
	// Хранит список компьютеров, где включен сбор полных, (а иногда - 
	ConstantParameters.Insert("FullDumpsCollectionEnabled", New Map);
	ConstantParameters.Insert("DumpInstances", New Map);
	ConstantParameters.Insert("DumpInstancesApproved", New Map);
	// 
	ConstantParameters.Insert("DumpsCheckDepth", 604800);
	ConstantParameters.Insert("MinDumpsCount", 10000);
	ConstantParameters.Insert("DumpCheckNext", Date(1,1,1));
	ConstantParameters.Insert("DumpsCheckFrequency", 14400);
	// Определяет тип собираемых дампов. По умолчанию - 
	ConstantParameters.Insert("DumpType", "0"); // "0" - 
	
	// 
	ConstantParameters.Insert("UserResponseTimeout", 14); // 
	ConstantParameters.Insert("ForceSendMinidumps", 0); // 
	ConstantParameters.Insert("NotificationDate2", Date(1,1,1)); // 
	
	
	// 
	//
	ConstantParameters.Insert("TestPackageSent", False);
	ConstantParameters.Insert("TestPackageSendingAttemptCount", 0);
	
	// 
	//
	ConstantParameters.Insert("DiscoveryPackageSent", False);
	
	// 
	//
	ConstantParameters.Insert("SetErrorHandlingSettingsForcibly", False); // УстановитьНастройкиОбработкиОшибокПринудительно.
	ConstantParameters.Insert("ErrorMessageDisplayVariant", "Auto"); // ErrorMessageDisplayVariant
	ConstantParameters.Insert("ErrorRegistrationServiceURL", ""); // АдресСервисаРегистрацииОшибок.
	ConstantParameters.Insert("SendReport", "Auto"); // ОтправлятьОтчет.
	ConstantParameters.Insert("IncludeDetailErrorDescriptionInReport", "Auto"); // ВключатьПодробныйТекстОшибкиВОтчет.
	ConstantParameters.Insert("IncludeInfobaseInformationInReport", "Auto"); // ВключатьСведенияОбИнформационнойБазеВОтчет.
	
	// 
	//
	// 
	//	
	//  
	//  
	//  
	ConstantParameters.Insert("ContactInformationRequest", 2);
	ConstantParameters.Insert("ContactInformation", "");
	ConstantParameters.Insert("ContactInformationComment1", "");
	ConstantParameters.Insert("PortalUsername", "");
	ConstantParameters.Insert("ContactInformationChanged", False);
	
	Return ConstantParameters; 
EndFunction

Function GetMonitoringCenterParameters(Parameters = Undefined) Export
	ConstantParameters = Constants.MonitoringCenterParameters.Get().Get();
	If ConstantParameters = Undefined Then
		ConstantParameters = New Structure;
	EndIf;
	
	DefaultParameters = GetDefaultParameters();
	
	For Each CurParameter In DefaultParameters Do
		If Not ConstantParameters.Property(CurParameter.Key) Then
			ConstantParameters.Insert(CurParameter.Key, CurParameter.Value);
		EndIf;
	EndDo;
	
	If ConstantParameters = Undefined Then
		ConstantParameters = DefaultParameters;
	EndIf;
	
	If Parameters = Undefined Then
		Parameters = ConstantParameters;
	Else
		If TypeOf(Parameters) = Type("Structure") Then
			For Each CurParameter In Parameters Do
				Parameters[CurParameter.Key] = ConstantParameters[CurParameter.Key];
			EndDo;
		ElsIf TypeOf(Parameters) = Type("String") Then
			Parameters = ConstantParameters[Parameters];
		EndIf;
	EndIf;
	
	ConstantParameters.Insert("RunPerformanceMeasurements", RunPerformanceMeasurements());
	
	Return Parameters;
EndFunction

Function SetSendingParameters(Parameters)
	SendOptions = New Structure;
	SendOptions.Insert("PerformanceMonitorEnabled");
	SendOptions.Insert("RunPerformanceMeasurements");
	SendOptions.Insert("SetErrorHandlingSettingsForcibly");
	GetMonitoringCenterParameters(SendOptions);
	
	SendOptions.Insert("RegisterSystemInformation", False);
	SendOptions.Insert("RegisterSubsystemVersions", False);
	SendOptions.Insert("RegisterDumps", False);
	SendOptions.Insert("RegisterBusinessStatistics", False);
	SendOptions.Insert("RegisterConfigurationStatistics", False);
	SendOptions.Insert("RegisterConfigurationSettings", False);
	SendOptions.Insert("RegisterPerformance", False);
	SendOptions.Insert("RegisterTechnologicalPerformance", False);
	SendOptions.Insert("SendingResult", ""); // 
	SendOptions.Insert("DiscoveryPackageSent", True); // 
	SendOptions.Insert("ContactInformationChanged", False);  // 
	
	ParametersMap = New Structure;
	ParametersMap.Insert("info", "RegisterSystemInformation");
	ParametersMap.Insert("versions", "RegisterSubsystemVersions");
	ParametersMap.Insert("dumps", "RegisterDumps");
	ParametersMap.Insert("business", "RegisterBusinessStatistics");
	ParametersMap.Insert("config", "RegisterConfigurationStatistics");
	ParametersMap.Insert("options", "RegisterConfigurationSettings");
	ParametersMap.Insert("perf", "RegisterPerformance");
	ParametersMap.Insert("internal_perf", "RegisterTechnologicalPerformance");
	
	Settings = Parameters.packetProperties;
	For Each CurSetting In Settings Do
		If ParametersMap.Property(CurSetting) Then
			Var_Key = ParametersMap[CurSetting];
			
			If SendOptions.Property(Var_Key) Then
				SendOptions[Var_Key] = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Parameters.Property("settings") Then
		NewSettings = Parameters.settings;
		NewSettings = StrReplace(NewSettings, ";", Chars.LF);
		DefaultSettings = GetDefaultParameters();
		For CurRow = 1 To StrLineCount(NewSettings) Do
			CurSetting = StrGetLine(NewSettings, CurRow);
			CurSetting = StrReplace(CurSetting, "=", Chars.LF);
			
			Var_Key = StrGetLine(CurSetting, 1);
			Var_Key = KeyForIncomingSettings(Var_Key);
			Value = StrGetLine(CurSetting, 2);
			
			If DefaultSettings.Property(Var_Key) Then
				If TypeOf(DefaultSettings[Var_Key]) = Type("Number") Then
					DetailsNumber = New TypeDescription("Number");
					CastedValue = DetailsNumber.AdjustValue(Value);
					If Format(CastedValue, "NZ=0; NG=") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("String") Then
					SendOptions.Insert(Var_Key, Value);
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("Boolean") Then
					DetailsBoolean = New TypeDescription("Boolean");
					CastedValue = DetailsBoolean.AdjustValue(Value);
					If Format(CastedValue, "BF=false; BT=true") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				ElsIf TypeOf(DefaultSettings[Var_Key]) = Type("Date") Then
					DetailsDate = New TypeDescription("Date");
					CastedValue = DetailsDate.AdjustValue(Value);
					If Format(CastedValue, "DF=yyyyMMddHHmmss") = Value Then
						SendOptions.Insert(Var_Key, CastedValue);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If Parameters.Property("deliveryIntervalHours") Then
		SendOptions.Insert("SendDataGenerationPeriod", Parameters.deliveryIntervalHours * 60 * 60);
	EndIf;
	
	If SendOptions["RegisterPerformance"] Or SendOptions["RegisterTechnologicalPerformance"] Then
		// There is no Performance monitor subsystem.
		If SendOptions.RunPerformanceMeasurements = Undefined Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// Disabled.
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 1;
		// Enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		// If it was enabled by Monitoring center, and disabled after that, then stop collecting.
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 3;
		// Enabled by Monitoring center.
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 1;
		// It was enabled by Performance monitor and then disabled.
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 3;
		// Enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		// Initially, was disabled. Then, was enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 3 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		EndIf;
	Else
		// There is no Performance monitor subsystem.
		If SendOptions.RunPerformanceMeasurements = Undefined Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// Disabled.
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// Enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 0 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		// Enabled by Monitoring center.
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// Enabled by Monitoring center.
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// It was enabled by Performance monitor and then disabled.
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And Not SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 0;
		// Enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 2 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		// Initially, was disabled. Then, was enabled by Performance monitor.
		ElsIf SendOptions.PerformanceMonitorEnabled = 3 And SendOptions.RunPerformanceMeasurements Then
			SendOptions.PerformanceMonitorEnabled = 2;
		EndIf;
	EndIf;
	
	If Parameters.Property("foundCopy") And Parameters.foundCopy Then
		PerformActionsOnDetectCopy();
		SendOptions.Insert("DiscoveryPackageSent", False);
	EndIf;
	
	// Error processing settings.
	// 	
	SavedSendingParameters = New Structure;
	SavedSendingParameters.Insert("SetErrorHandlingSettingsForcibly");
	SavedSendingParameters.Insert("ErrorMessageDisplayVariant"); 
	SavedSendingParameters.Insert("ErrorRegistrationServiceURL");
	SavedSendingParameters.Insert("SendReport");
	SavedSendingParameters.Insert("IncludeDetailErrorDescriptionInReport");
	SavedSendingParameters.Insert("IncludeInfobaseInformationInReport");
	GetMonitoringCenterParameters(SavedSendingParameters);
	ProcessingResult = SettingErrorHandlingSettings(SavedSendingParameters, SendOptions);
	For Each KeyAndRecord In ProcessingResult Do
		SendOptions.Insert(KeyAndRecord.Key, KeyAndRecord.Value);	
	EndDo;

	BeginTransaction();
	Try
		If SendOptions.PerformanceMonitorEnabled = 0 And Not SendOptions.RunPerformanceMeasurements = Undefined Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
			ModulePerformanceMonitor.EnablePerformanceMeasurements(False);
		ElsIf SendOptions.PerformanceMonitorEnabled = 1 And Not SendOptions.RunPerformanceMeasurements = Undefined Then
			ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");	
			ModulePerformanceMonitor.EnablePerformanceMeasurements(True);
		EndIf;
		
		SetMonitoringCenterParameters(SendOptions);
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center.Set sending parameters';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error,,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Return SendOptions;
	
EndFunction

Function KeyForIncomingSettings(Var_Key)
	Map = New Map;
	Map.Insert("SetErrorProcessingSettingsForcibly","SetErrorHandlingSettingsForcibly");
	Map.Insert("ErrorMessageDisplayVariant","ErrorMessageDisplayVariant");
	Map.Insert("ErrorRegistrationServiceURL","ErrorRegistrationServiceURL");
	Map.Insert("SendReport","SendReport");
	Map.Insert("IncludeDetailErrorDescriptionInReport","IncludeDetailErrorDescriptionInReport");
	Map.Insert("IncludeInfobaseInformationInReport","IncludeInfobaseInformationInReport");	
	Value = Map.Get(Var_Key);
	If Value = Undefined Then
		Return Var_Key
	EndIf;
	Return Value;
EndFunction

Procedure SetMonitoringCenterParameters(NewParameters)
	
	Block = New DataLock;
	Block.Add("Constant.MonitoringCenterParameters");
	
	BeginTransaction();
	
	Try
		Block.Lock();
		Parameters = GetMonitoringCenterParameters();
		
		If NewParameters.Property("RunPerformanceMeasurements") Then
			NewParameters.Delete("RunPerformanceMeasurements");
		EndIf;
				
		For Each CurParameter In NewParameters Do
			If Not Parameters.Property(CurParameter.Key) Then
				Parameters.Insert(CurParameter.Key);
			EndIf;
			
			Parameters[CurParameter.Key] = CurParameter.Value;
		EndDo;
		
		Store = New ValueStorage(Parameters);
		Constants.MonitoringCenterParameters.Set(Store);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center.Set Monitoring center parameters';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error, 
			Metadata.Constants.MonitoringCenterParameters,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteMonitoringCenterParameters()
	Try
		Parameters = New Structure;
		Store = New ValueStorage(Parameters);
		Constants.MonitoringCenterParameters.Set(Store);
	Except
		WriteLogEvent(NStr("en = 'Monitoring center.Delete Monitoring center parameters';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error, 
			Metadata.Constants.MonitoringCenterParameters,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
EndProcedure

Procedure SetMonitoringCenterParameter(Parameter, Value)
	
	Block = New DataLock;
	Block.Add("Constant.MonitoringCenterParameters");
	
	BeginTransaction();
	Try
		Block.Lock();
		Parameters = GetMonitoringCenterParameters();
		
		If Not Parameters.Property(Parameter) Then
			Parameters.Insert(Parameter);
		EndIf;
		
		Parameters[Parameter] = Value;
		Store = New ValueStorage(Parameters);
		Constants.MonitoringCenterParameters.Set(Store);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center.Set Monitoring center parameters';", 
			Common.DefaultLanguageCode()), EventLogLevel.Error, 
			Metadata.Constants.MonitoringCenterParameters,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function GetSendServiceParameters()
	ServiceParameters = New Structure;
	
	ServiceParameters.Insert("EnableMonitoringCenter");
	ServiceParameters.Insert("ApplicationInformationProcessingCenter");
	ServiceParameters.Insert("InfoBaseID");
	ServiceParameters.Insert("Server");
	ServiceParameters.Insert("ResourceAddress");
	ServiceParameters.Insert("DumpsResourceAddress");
	ServiceParameters.Insert("Port");
	ServiceParameters.Insert("SecureConnection");
	
	GetMonitoringCenterParameters(ServiceParameters);
	
	If ServiceParameters.EnableMonitoringCenter And Not ServiceParameters.ApplicationInformationProcessingCenter Then
		DefaultServiceParameters = GetDefaultParameters();
		
		ServiceParameters.Insert("Server", DefaultServiceParameters.Server);
		ServiceParameters.Insert("ResourceAddress", DefaultServiceParameters.ResourceAddress);
		ServiceParameters.Insert("DumpsResourceAddress", DefaultServiceParameters.DumpsResourceAddress);
		ServiceParameters.Insert("Port", DefaultServiceParameters.Port);
		ServiceParameters.Insert("SecureConnection", DefaultServiceParameters.SecureConnection);
	EndIf;
	
	ServiceParameters.Delete("EnableMonitoringCenter");
	ServiceParameters.Delete("ApplicationInformationProcessingCenter");
	
	Return ServiceParameters;
EndFunction

#EndRegion

#Region WorkWithSettingsFile

// If the service is not available, collect full dumps. This is an export function for testing carried out by the data processor.
// Returns
//    Structure - contains a path to a dumps directory and dumps deletion flag.
//
Function GetDumpsDirectory(DumpType = "0", StopCollectingFull = False) Export
	SettingsDirectory = GetTechnologicalLogSettingsDirectory();
	DumpsDirectory = FindDumpsDirectory(SettingsDirectory, DumpType, StopCollectingFull);
	
	Return DumpsDirectory;
EndFunction

Function GeneratePathWithSeparator(Path)
	If ValueIsFilled(Path) Then
		PathSeparator = GetServerPathSeparator();
		If Right(Path, 1) <> PathSeparator Then
			Path = Path + PathSeparator;
		EndIf;
	EndIf;
	
	Return Path;
EndFunction

Function FindDumpsDirectory(SettingsDirectory, DumpType, StopCollectingFull) 
	DumpsDirectory = New Structure("Path, DeleteDumps, ErrorDescription", "", False, "");
	
	SettingsFileName = "logcfg.xml";
	DirectoryPath = GeneratePathWithSeparator(SettingsDirectory.Path);
	
	FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled")[ComputerName()];
		
	File = New File(DirectoryPath + SettingsFileName);
	If File.Exists() Then
		Try
			XMLReader = New XMLReader;
			XMLReader.OpenFile(File.FullName, New XMLReaderSettings(,,,,,,,True, True));
			While XMLReader.Read() Do
				If XMLReader.NodeType = XMLNodeType.StartElement And XMLReader.HasName And Upper(XMLReader.Name) = "DUMP" Then
					DumpsParameters = New Structure;
					If XMLReader.AttributeCount() > 0 Then
						While XMLReader.ReadAttribute() Do
							DumpsParameters.Insert(XMLReader.LocalName, XMLReader.Value);
						EndDo;
					EndIf;
				EndIf;
			EndDo;
		Except
			Message = NStr("en = 'An error occurred when reading a setting file of the technological log';");
			Message = Message + " """ +File.FullName + """." + Chars.LF;
			Message = Message + NStr("en = 'The file is likely corrupt. Cannot register dumps. Delete the corrupt file or reset settings.';");
			WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()), 
				EventLogLevel.Warning,,, Message);
			
			DumpsDirectory.Path = Undefined;
			DumpsDirectory.ErrorDescription = NStr("en = 'An error occurred when reading a setting file of the technological log';");
			Return DumpsDirectory;
		EndTry;
		
		If DumpsParameters <> Undefined Then
			If Not DumpsParameters.Property("location") Or Not DumpsParameters.Property("create") Or Not DumpsParameters.Property("type") Then
				Message = NStr("en = 'Dump collection section error in the setting file of technological log';");
				Message = Message + " """ + File.FullName + """." + Chars.LF;
				Message = Message + NStr("en = 'Cannot register dumps. Remove the file or restore the settings.';");
				XMLReader.Close();
				WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()), 
					EventLogLevel.Warning,,, Message);
				
				DumpsDirectory.Path = Undefined;
				DumpsDirectory.ErrorDescription = NStr("en = 'Dump collection section error in the setting file of technological log';");
				Return DumpsDirectory;
			EndIf;
		EndIf;
				
		If DumpsParameters <> Undefined Then
			DumpsDirectory.Path = GeneratePathWithSeparator(DumpsParameters.Location);
			If StrFind(DumpsDirectory.Path, "80af5716-b134-4b1c-a38d-4658d1ac4196") > 0 And Not FullDumpsCollectionEnabled = True Then
				DumpsDirectory.DeleteDumps = True;
			EndIf;
			XMLReader.Close();
			
			If StrFind(DumpsDirectory.Path, "80af5716-b134-4b1c-a38d-4658d1ac4196") > 0 Then
				If DumpsParameters.type <> DumpType Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				ElsIf Not DumpsParameters.Property("externaldump") Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				ElsIf DumpsParameters.externaldump <> "1" Then
					CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
				EndIf;
			EndIf;
		Else
			XMLReader.Close();
			CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType);
		EndIf;
			
	Else
		DumpsDirectory.Path = CreateDumpsCollectionSettingsFile(DirectoryPath, DumpType);
		If Not FullDumpsCollectionEnabled = True Then
			DumpsDirectory.DeleteDumps = True;
		EndIf;
		If DumpsDirectory.Path = Undefined Then
			DumpsDirectory.ErrorDescription = NStr("en = 'An error occurred while creating the setting file of the technological log. Cannot register dumps.';");
		EndIf;
	EndIf;
	
	Return DumpsDirectory;
EndFunction

Procedure CreateDumpsCollectionSection(File, XMLReader, DumpsDirectory, DumpType)
	
	Id = "80af5716-b134-4b1c-a38d-4658d1ac4196";
	
	XMLReader.OpenFile(File.FullName, New XMLReaderSettings(,,,,,,,False, False));
	
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(XMLReader);
	DOMDocument.Normalize();
	XMLReader.Close();
		If DOMDocument.HasChildNodes() Then
		FirstChild = DOMDocument.FirstChild;
		If Upper(FirstChild.NodeName) = "CONFIG" Then
			DefaultPath = StrFind(DumpsDirectory.Path, Id) > 0;
			If IsBlankString(DumpsDirectory.Path) Or DefaultPath Then
				DumpsDirectory.Path = GeneratePathWithSeparator(GeneratePathWithSeparator(TempFilesDir() + "Dumps") + Id);
			EndIf;
			DumpsDirectory.DeleteDumps = True;
			
			ItemsDumps = DOMDocument.GetElementByTagName("dump");
			If ItemsDumps.Count() = 0 Then
				
				ItemDumps = DOMDocument.CreateElement("dump");
				ItemDumps.SetAttribute("location", DumpsDirectory.Path);
				ItemDumps.SetAttribute("create", "1");
				ItemDumps.SetAttribute("type", DumpType);
				ItemDumps.SetAttribute("externaldump", "1");
				FirstChild.AppendChild(ItemDumps);
			Else
				For Each CurItem In ItemsDumps Do
					CurItem.SetAttribute("externaldump", "1");
					CurItem.SetAttribute("type", DumpType);
					CurItem.SetAttribute("location", DumpsDirectory.Path);
				EndDo;
			EndIf;
			
			Try
				XMLWriter = New XMLWriter;
				DOMWriter = New DOMWriter; 
				XMLWriter.OpenFile(File.FullName, New XMLWriterSettings(,,True,True));
				DOMWriter.Write(DOMDocument, XMLWriter);
				XMLWriter.Close();
			Except
				Message = NStr("en = 'An error occurred while saving the setting file of the technological log. Cannot register dumps.';");
				Message = Message + " """ +File.FullName + """." + Chars.LF;
				Message = Message + ErrorProcessing.DetailErrorDescription(ErrorInfo());
				WriteLogEvent(NStr("en = 'Monitoring center.Register dumps';", 
					Common.DefaultLanguageCode()), EventLogLevel.Warning,,, Message);
				
				DumpsDirectory.Path = Undefined;
				DumpsDirectory.ErrorDescription = NStr("en = 'An error occurred while saving the setting file of the technological log. Cannot register dumps.';");
			EndTry;
		EndIf;
	EndIf;
EndProcedure

// This function generates a path to a dumps directory.
// The dumps directory is cleared automatically using the DumpsRegistration method. 
// 
// Parameters:
//    DirectoryPath - String - a path to a directory where a setting file of technological log is stored.
// 
// Returns:
//    String
//
Function CreateDumpsCollectionSettingsFile(DirectoryPath, DumpType)
	SettingsFileName = "logcfg.xml";
	
	Id = "80af5716-b134-4b1c-a38d-4658d1ac4196";
	DumpsDirectory = GeneratePathWithSeparator(GeneratePathWithSeparator(TempFilesDir() + "Dumps") + Id);
	
	Try
		XMLWriter = New XMLWriter;
		XMLWriter.OpenFile(DirectoryPath + SettingsFileName);
		DumpsCollection =
		"<config xmlns=""http://v8.1c.ru/v8/tech-log"">
		|	<dump location=""" + DumpsDirectory + """ create=""1"" type=""" + DumpType + """ externaldump=""1""/>
		|</config>";
		XMLWriter.WriteRaw(DumpsCollection);
		XMLWriter.Close();
	Except
		Message = NStr("en = 'An error occurred while creating the setting file of the technological log. Cannot register dumps.';");
		Message = Message + " """ +DirectoryPath + SettingsFileName + """." + Chars.LF;
		Message = Message + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()), 
			EventLogLevel.Warning,,, Message);
		
		DumpsDirectory = Undefined;
		
	EndTry;
	
	Return DumpsDirectory;
EndFunction

Function GetTechnologicalLogSettingsDirectory()
	SettingsDirectory = New Structure("Path, Exists, ErrorDescription", "", False, "");
	
	// Directories where it was searched are required as a protection from looping.
	SettingsDirectories = New Array;
	
	SettingsFileName = "logcfg.xml";
	SettingsConfigurationFileName = "conf.cfg";
	
	BinDir = GeneratePathWithSeparator(BinDir());
		
	SearchForDirectory = True;
	Counter = 0;
	DirectoryPath = GeneratePathWithSeparator(BinDir + "conf");
	While SearchForDirectory = True Do
		// Check if it was searched in the current directory (protection from looping).
		If SettingsDirectories.Find(DirectoryPath) <> Undefined Then
			SettingsDirectory.Path = "";
			SettingsDirectory.Exists = False;
			SettingsDirectory.ErrorDescription = NStr("en = 'Circular ref is found';", Common.DefaultLanguageCode());
			
			SearchForDirectory = False;
		Else
			FullSettingsFileName = DirectoryPath + SettingsFileName;
			SettingsFile = New File(FullSettingsFileName);
			If SettingsFile.Exists() Then
				SettingsDirectory.Path = DirectoryPath;
				SettingsDirectory.Exists = True;
				SettingsDirectory.ErrorDescription = "";
				
				SearchForDirectory = False;
			Else
				SettingsDirectories.Add(DirectoryPath);
				
				FullSettingsConfigurationFileName = DirectoryPath + SettingsConfigurationFileName;
				SettingsConfigurationFile = New File(FullSettingsConfigurationFileName);
				If SettingsConfigurationFile.Exists() Then
					DirectoryPath = GetDirectoryFromSettingsConfigurationFile(SettingsConfigurationFile);
					If DirectoryPath.Exists Then
						DirectoryPath = GeneratePathWithSeparator(DirectoryPath.Path);
					Else
						SettingsDirectory.Path = DirectoryPath.Path;
						SettingsDirectory.Exists = DirectoryPath.Exists;
						SettingsDirectory.ErrorDescription = DirectoryPath.ErrorDescription;
						
						SearchForDirectory = False;
					EndIf;
				Else
					SettingsDirectory.Path = "";
					SettingsDirectory.Exists = False;
					SettingsDirectory.ErrorDescription = NStr("en = 'The setting configuration file does not exist in the directory.';", 
						Common.DefaultLanguageCode()) + " " + DirectoryPath;
					
					SearchForDirectory = False;
				EndIf;
			EndIf;
		EndIf;
		
		Counter = Counter + 1;
		
		If Counter >= 100 Then
			SearchForDirectory = False;
		EndIf;
	EndDo;
	
	Return SettingsDirectory;
EndFunction

Function GetDirectoryFromSettingsConfigurationFile(SettingsConfigurationFile)
	SettingsDirectory = New Structure("Path, Exists, ErrorDescription", "", False, "");
	
	SearchString = "ConfLocation=";
	SearchStringLength = StrLen(SearchString);
	
	Text = New TextReader(SettingsConfigurationFile.FullName);
	Data = Text.Read();
	
	SearchIndex = StrFind(Data, SearchString);
	If SearchIndex > 0 Then
		DataBuffer1 = Right(Data, StrLen(Data) - (SearchIndex + SearchStringLength - 1));
		SearchIndex = StrFind(DataBuffer1, Chars.LF);
		If SearchIndex > 0 Then
			SettingsDirectory.Path = GeneratePathWithSeparator(Left(DataBuffer1, SearchIndex - 1));
		Else
			SettingsDirectory.Path = GeneratePathWithSeparator(DataBuffer1);
		EndIf;
		SettingsDirectory.Exists = True;
		SettingsDirectory.ErrorDescription = "";
	Else
		SettingsDirectory.Path = GeneratePathWithSeparator(SettingsConfigurationFile.Path);
		SettingsDirectory.Exists = False;
		SettingsDirectory.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Section %1 is not found in file %2';", Common.DefaultLanguageCode()),
			"ConfLocation", SettingsConfigurationFile.FullName);
	EndIf;
		
	Return SettingsDirectory;
EndFunction

#EndRegion

#Region WorkWithDumps

Function DumpDetails(Val FileName)
	FileName = StrReplace(FileName, "_", Chars.LF);
	
	DumpStructure = New Structure;
	If StrLineCount(FileName) >= 3  Then
		DumpStructure.Insert("Process_", StrGetLine(FileName, 1));
		DumpStructure.Insert("PlatformVersion", StrGetLine(FileName, 2));
		DumpStructure.Insert("Offset", StrGetLine(FileName, 3));
	Else
		SysInfo = New SystemInfo;
		DumpStructure.Insert("Process_", "userdump");
		DumpStructure.Insert("PlatformVersion", SysInfo.AppVersion);
		DumpStructure.Insert("Offset", "ffffffff");
	EndIf;
	
	Return DumpStructure;
EndFunction

Function PlatformVersionToNumber(Version) Export
	PlatformVersion = StrReplace(Version, ".", Chars.LF);
	PlatformVersionNumber = Number(Left(StrGetLine(PlatformVersion, 1) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 2) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 3) + "000000", 6)
		+ Left(StrGetLine(PlatformVersion, 4) + "000000", 6));
	
	Return PlatformVersionNumber;
EndFunction

#EndRegion

#Region WorkWithSystemInformation
Function GetSystemInformation1()
	SysInfo = New SystemInfo;
	
	Result = New Structure;
	Result.Insert("computerName", Common.CheckSumString(ComputerName()));
	Result.Insert("osInfo", String(SysInfo.OSVersion));
	Result.Insert("platformVersion", String(SysInfo.AppVersion));
	Result.Insert("clientID", String(SysInfo.ClientID));
	Result.Insert("ram", String(SysInfo.RAM));
	Result.Insert("cpu", String(SysInfo.Processor));
	Result.Insert("applicationArchitecture", String(SysInfo.PlatformType));
	Result.Insert("currentLanguage", String(CurrentLanguage()));
	Result.Insert("currentLocalizationCode", String(CurrentLocaleCode()));
	Result.Insert("currentSystemLanguage", String(CurrentSystemLanguage()));
	Result.Insert("currentRunMode", String(CurrentRunMode()));
	Result.Insert("sessionTimeZone", String(SessionTimeZone()));
	
	Return Result;
EndFunction

Function SubsystemsVersions()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemsVersions.SubsystemName AS SubsystemName,
	|	SubsystemsVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	Result = Query.Execute();
	
	Subsystems = New Structure;
	Selection = Result.Select();
	While Selection.Next() Do
		Subsystems.Insert(Selection.SubsystemName, Selection.Version);
	EndDo;
	
	Return Subsystems;
EndFunction

#EndRegion

#Region WorkWithConfigurationExtensions

Function DataOnUsedExtensions()

	ExtensionStructure = New Structure;
	                   	
	ExtensionsArray = ConfigurationExtensions.Get();
	ExtensionsUsed = ExtensionsArray.Count()>0;
	ExtensionStructure.Insert("ExtensionsUsage", ExtensionsUsed);
	
	If Not ExtensionsUsed Then
		Return ExtensionStructure;
	EndIf;
	
	ExtensionsDetailsArray = New Array;	
	For Each Extension In ExtensionsArray Do
		ExtensionDetails = New Structure("Name, Version, Purpose, SafeMode, UnsafeActionProtection, Synonym");
		FillPropertyValues(ExtensionDetails, Extension);
		ExtensionDetails.Insert("UnsafeActionProtection", ?(ExtensionDetails.UnsafeActionProtection = Undefined, False, ExtensionDetails.UnsafeActionProtection.UnsafeOperationWarnings));
		ExtensionDetails.Insert("Purpose", String(ExtensionDetails.Purpose));		
		ExtensionsDetailsArray.Add(ExtensionDetails);
	EndDo;
	
	ExtensionStructure.Insert("ExtensionsDetails1", ExtensionsDetailsArray);	
	
	ExtensionsMetadata = New Map;
	MetadataDetails = MetadataDetails();
	For Each StrWrite In MetadataDetails Do
		AddExtensionsInformation(StrWrite.Key, StrWrite.Value, ExtensionsMetadata);
	EndDo;
	
	ExtensionStructure.Insert("ExtensionsMetadata", ExtensionsMetadata);
	
	Return ExtensionStructure;
	
EndFunction

Procedure AddExtensionsInformation(ObjectClass, ObjectArchitecture, ExtensionsMetadata)
	For Each MetadataObject In Metadata[ObjectClass] Do
		// 
		For Each StructureItem In ObjectArchitecture Do
			If StructureItem.Value = "Recursively" Then
				AddExtensionsInformationRecursively(MetadataObject, StructureItem.Key, ObjectArchitecture, ExtensionsMetadata);
			EndIf;
			For Each SubordinateObject In MetadataObject[StructureItem.Key] Do
				ObjectExtension = SubordinateObject.ConfigurationExtension(); // ConfigurationExtension
				If ObjectExtension = Undefined Then
					Continue;
				EndIf;		
				ExtensionsMetadata.Insert(SubordinateObject.FullName(), ObjectExtension.Name);
			EndDo;
		EndDo;
		
		ObjectExtension = MetadataObject.ConfigurationExtension(); // ConfigurationExtension
		If ObjectExtension = Undefined Then
			If MetadataObject.ChangedByConfigurationExtensions() Then
				ExtensionsMetadata.Insert(MetadataObject.FullName(), True);		
			EndIf;
			Continue;
		EndIf;		
		ExtensionsMetadata.Insert(MetadataObject.FullName(), ObjectExtension.Name);
	EndDo;

EndProcedure

Procedure AddExtensionsInformationRecursively(Object, RecursiveAttributeName, ObjectArchitecture, ExtensionsMetadata)
	For Each RecursiveObject In Object[RecursiveAttributeName] Do
		For Each StructureItem In ObjectArchitecture Do
			If StructureItem.Value = "Recursively" Then
				AddExtensionsInformationRecursively(RecursiveObject, StructureItem.Key, ObjectArchitecture, ExtensionsMetadata);
			EndIf;
			For Each SubordinateObject In RecursiveObject[StructureItem.Key] Do
				ObjectExtension = SubordinateObject.ConfigurationExtension(); // ConfigurationExtension
				If ObjectExtension = Undefined Then
					Continue;
				EndIf;		
				ExtensionsMetadata.Insert(SubordinateObject.FullName(), ObjectExtension.Name);
			EndDo;
		EndDo;
		
		ObjectExtension = RecursiveObject.ConfigurationExtension(); // ConfigurationExtension
		If ObjectExtension = Undefined Then
			Continue;
		EndIf;		
		ExtensionsMetadata.Insert(RecursiveObject.FullName(), ObjectExtension.Name);	
	EndDo;
EndProcedure
 
Function MetadataDetails()
	MetadataDetails = New Map;
	MetadataDetails.Insert("Subsystems", New Structure("Subsystems", "Recursively"));
	MetadataDetails.Insert("CommonModules", New Structure);
	MetadataDetails.Insert("SessionParameters", New Structure);
	MetadataDetails.Insert("CommonAttributes", New Structure);
	MetadataDetails.Insert("CommonAttributes", New Structure);
	MetadataDetails.Insert("ExchangePlans", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("FilterCriteria", New Structure("Forms, Commands"));
	MetadataDetails.Insert("EventSubscriptions", New Structure);
	MetadataDetails.Insert("ScheduledJobs", New Structure);
	MetadataDetails.Insert("FunctionalOptions", New Structure);
	MetadataDetails.Insert("FunctionalOptionsParameters", New Structure);
	MetadataDetails.Insert("DefinedTypes", New Structure);
	MetadataDetails.Insert("SettingsStorages", New Structure("Forms, Templates"));
	MetadataDetails.Insert("CommonForms", New Structure);
	MetadataDetails.Insert("CommonCommands", New Structure);
	MetadataDetails.Insert("CommandGroups", New Structure);
	MetadataDetails.Insert("CommonTemplates", New Structure);
	MetadataDetails.Insert("CommonPictures", New Structure);
	MetadataDetails.Insert("XDTOPackages", New Structure);
	MetadataDetails.Insert("WebServices", New Structure);
	MetadataDetails.Insert("HTTPServices", New Structure);
	MetadataDetails.Insert("WSReferences", New Structure);
	MetadataDetails.Insert("StyleItems", New Structure);
	MetadataDetails.Insert("Languages", New Structure);	
	MetadataDetails.Insert("Constants", New Structure);
	MetadataDetails.Insert("Catalogs", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("Documents", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("DocumentJournals", New Structure("Columns, Forms, Commands, Templates"));
	MetadataDetails.Insert("Enums", New Structure("EnumValues, Forms, Commands, Templates"));
	MetadataDetails.Insert("Reports", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("DataProcessors", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfCharacteristicTypes", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfAccounts", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("ChartsOfCalculationTypes", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("InformationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("AccumulationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("AccountingRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("CalculationRegisters", New Structure("Dimensions, Resources, Attributes, Forms, Commands, Templates"));
	MetadataDetails.Insert("BusinessProcesses", New Structure("Attributes, TabularSections, Forms, Commands, Templates"));
	MetadataDetails.Insert("Tasks", New Structure("AddressingAttributes, Attributes, TabularSections, Forms, Commands, Templates"));
	
	Return MetadataDetails;
EndFunction

#EndRegion

#Region WorkWithAccessRightsSubsystem

Function DataOnRolesUsage()
	DataOnRolesUsage = New Structure;
	
	// Get data on role usage.	
	Query = New Query(AccessManagementInternal.RolesUsageQueryText());
	Query.SetParameter("EmptyUID", CommonClientServer.BlankUUID());
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	ResultPackage = Query.ExecuteBatch();
	
	// Generating structure: roles by access group profiles.
	IndexColumns = New Map;
	IndexColumns.Insert("ProfileUID", New Map);
	IndexColumns.Insert("RoleName", New Map);	
	AdditionalParameters = New Map;
	AdditionalParameters.Insert("IndexColumns", IndexColumns);
	
	ProfilesRoles = ResultPackage[8].Unload();
	ProfilesRoles.Columns.Add("ProfileUID", New TypeDescription("String"));
	For Each String In ProfilesRoles Do
		String.ProfileUID = String(String.Profile.UUID());
	EndDo;
	ProfilesRoles.Columns.Delete("Profile");
	
	ProfilesRolesStructure = GenerateJSONStructure("RolesOfProfiles", ProfilesRoles, AdditionalParameters);
	DataOnRolesUsage.Insert("RolesOfProfiles", ProfilesRolesStructure["RolesOfProfiles"]);
	
	// 
	IndexColumns = New Map;
	IndexColumns.Insert("ProfileUID", New Map);	
	IndexColumns.Insert("Description", New Map);
	IndexColumns.Insert("SuppliedDataID", New Map);
	AdditionalParameters = New Map;
	AdditionalParameters.Insert("IndexColumns", IndexColumns);
	
	ProfilesData = ResultPackage[7].Unload();
	ProfilesData.Columns.Add("ProfileUID", New TypeDescription("String"));
	ProfilesData.Columns.Add("SuppliedDataIDRow", New TypeDescription("String"));
	For Each String In ProfilesData Do
		String.SuppliedDataIDRow = String(String.SuppliedDataID);
		String.ProfileUID = String(String.Profile.UUID());
	EndDo;
	ProfilesData.Columns.Delete("SuppliedDataID");
	ProfilesData.Columns.SuppliedDataIDRow.Name = "SuppliedDataID";
	ProfilesData.Columns.Delete("Profile");
	
	Profiles = GenerateJSONStructure("Profiles", ProfilesData, AdditionalParameters);
	DataOnRolesUsage.Insert("Profiles", Profiles["Profiles"]);
	
	Return DataOnRolesUsage;
EndFunction

#EndRegion


#Region WorkInSeparationByDataAreasMode

Function SeparationByDataAreasEnabled() Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SeparationByDataAreasEnabled = ModuleSaaSOperations.DataSeparationEnabled();
	Else
		SeparationByDataAreasEnabled = False;
	EndIf;
	
	Return SeparationByDataAreasEnabled;
	
EndFunction

#EndRegion

#Region WorkInDIBMode

Function IsMasterNode1()
	SetPrivilegedMode(True);
	
	Return Not ExchangePlans.MasterNode() <> Undefined;
EndFunction

#EndRegion

#Region CommonFunctions

Function EventLogEventMonitoringCenterDumpDeletion()
	Return NStr("en = 'Monitoring center.Removing the dump';", Common.DefaultLanguageCode());
EndFunction

Function LogLogEventParseOperationBufferStatistics()
	Return NStr("en = 'Monitoring center.Parse the buffer of statistics operations';", Common.DefaultLanguageCode());
EndFunction
#EndRegion

#Region ClientInformation

Procedure WriteClientScreensStatistics(Parameters)
	
	Screens = Parameters["ClientInformation"]["ClientScreens"]; 
	UserHash = Parameters["ClientInformation"]["ClientParameters"]["UserHash"];
	
	For Each CurScreen In Screens Do
		
		StatisticsOperationName = "ClientStatistics.SystemInformation.MonitorResolotion." + CurScreen;
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
		
		StatisticsOperationName = StatisticsOperationName + "." + Parameters["ClientInformation"]["SystemInformation"]["UserAgentInformation"]; 
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
		
	EndDo;
	
	MonitorCountString = Format(Screens.Count(), "NG=0");
	MonitoringCenter.WriteBusinessStatisticsOperationDay("ClientStatistics.SystemInformation.MonitorCount." + MonitorCountString, UserHash, 1);
	
EndProcedure

Procedure WriteSystemInformation(Parameters)
	
	UserHash = Parameters["ClientInformation"]["ClientParameters"]["UserHash"];
	
	For Each CurSystemInfo In Parameters["ClientInformation"]["SystemInformation"] Do
		StatisticsOperationName = "ClientStatistics.SystemInformation." + CurSystemInfo.Key + "." + CurSystemInfo.Value;
		MonitoringCenter.WriteBusinessStatisticsOperationDay(StatisticsOperationName, UserHash, 1);
	EndDo;
	
EndProcedure

Procedure WriteClientInformation(Parameters)
	
	UserHash = Parameters["ClientInformation"]["ClientParameters"]["UserHash"];
	
	WriteUserActivity(UserHash);
	
	StatisticsOperationName = "ClientStatistics.ActiveWindows";
	Value =  Parameters["ClientInformation"]["ActiveWindows"];
	MonitoringCenter.WriteBusinessStatisticsOperationHour(StatisticsOperationName, UserHash, Value);
	
EndProcedure

Procedure WriteUserActivity(UserHash)
	StatisticsOperationName = "ClientStatistics.ActiveUsers";
	MonitoringCenter.WriteBusinessStatisticsOperationHour(StatisticsOperationName, UserHash, 1);
EndProcedure

Procedure WriteDataFromClient(Parameters)
	
	CurDate = CurrentUniversalDate();
	
	Measurements = Parameters["Measurements"];
	For Each MeasurementsOfType In Measurements Do
		
		EntryType = MeasurementsOfType.Key;
		
		If EntryType = 0 Then
			WriteDataFromClientExact(MeasurementsOfType.Value);
		Else
			WriteDataFromClientUnique(MeasurementsOfType.Value, EntryType, CurDate);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteDataFromClientExact(Measurements)
	
	InformationRegisters.StatisticsOperationsClipboard.DoWriteBusinessStatisticsOperations(Measurements);
			
EndProcedure

Procedure WriteDataFromClientUnique(Measurements, EntryType, CurDate)
	
	If EntryType = 1 Then
		RecordPeriod = BegOfHour(CurDate);
	ElsIf EntryType = 2 Then
		RecordPeriod = BegOfDay(CurDate);
	EndIf;
	
	WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
	For Each CurMeasurement In Measurements Do
		
		WriteParameters.OperationName = CurMeasurement.Value.StatisticsOperation;
		WriteParameters.UniqueKey = CurMeasurement.Value.Key;
		WriteParameters.Value = CurMeasurement.Value.Value;
		WriteParameters.Replace = CurMeasurement.Value.Replace;
		WriteParameters.EntryType = EntryType;
		WriteParameters.RecordPeriod = RecordPeriod;
		
		WriteBusinessStatisticsOperationInternal(WriteParameters);	
		
	EndDo;
	
EndProcedure

#EndRegion

Procedure InitialFilling1() Export
	
	If SeparationByDataAreasEnabled() Then
		Return;
	EndIf;
	
	CurDate = CurrentUniversalDate();
	
	DeleteMonitoringCenterParameters();
	MonitoringCenterParameters = GetDefaultParameters();
	
	If Common.FileInfobase() Then
		MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod = 3600;
	EndIf;
	
	MonitoringCenterParameters.DumpRegistrationNextCreation = CurDate + MonitoringCenterParameters.DumpRegistrationCreationPeriod;
	MonitoringCenterParameters.BusinessStatisticsNextSnapshot = CurDate + MonitoringCenterParameters.BusinessStatisticsSnapshotPeriod;
	MonitoringCenterParameters.ConfigurationStatisticsNextGeneration = CurDate + MonitoringCenterParameters.ConfigurationStatisticsGenerationPeriod;
	
	RNG = New RandomNumberGenerator(CurrentUniversalDateInMilliseconds());
	SendingDelta = RNG.RandomNumber(0, 86400);
	MonitoringCenterParameters.SendDataNextGeneration = CurDate + SendingDelta;
	
	MonitoringCenterParameters.AggregationPeriodMinor = 600;
	MonitoringCenterParameters.AggregationPeriod = 3600;
	MonitoringCenterParameters.DeletionPeriod = 86400;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		MonitoringCenterParameters.EnableMonitoringCenter = True;
	EndIf;
	
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		SchedJob = GetScheduledJob("StatisticsDataCollectionAndSending", True);
		SetDefaultSchedule(SchedJob);
	EndIf;
	
EndProcedure

Procedure AddInfobaseIDPermanent() Export
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	MonitoringCenterParameters.Insert("InfobaseIDPermanent", MonitoringCenterParameters.InfoBaseID);
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
EndProcedure

Procedure EnableSendingInfo(Parameters) Export
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter"));
	// If it is already enabled, do nothing.
	If MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter Then
		Parameters.ProcessingCompleted = True;
		Return;
	EndIf;
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", True, False);
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	SchedJob = GetScheduledJob("StatisticsDataCollectionAndSending", True);
	SetDefaultSchedule(SchedJob);
	
	Parameters.ProcessingCompleted = True;
EndProcedure

Procedure EnableSendingInfoFilling(Parameters) Export
	
EndProcedure

Procedure DisableEventLoggingOnUpdate() Export
	MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter"));	
	If Not MonitoringCenterParameters.EnableMonitoringCenter And Not MonitoringCenterParameters.ApplicationInformationProcessingCenter Then
		// 
		DisableEventLogging();
	EndIf;
EndProcedure

Procedure WriteBusinessStatisticsOperationInternal(WriteParameters) Export
	
	RecordPeriod = WriteParameters.RecordPeriod;
	EntryType = WriteParameters.EntryType;
	Var_Key = WriteParameters.UniqueKey;
	StatisticsOperation = MonitoringCenterCached.GetStatisticsOperationRef(WriteParameters.OperationName);
	Value = WriteParameters.Value;
	Replace = WriteParameters.Replace;
	
	InformationRegisters.StatisticsMeasurements.WriteBusinessStatisticsOperation(RecordPeriod, EntryType, Var_Key, StatisticsOperation, Value, Replace);
	
EndProcedure

Procedure PerformActionsOnDetectCopy()
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
	MonitoringCenterParameters.InfoBaseID = New UUID();
	MonitoringCenterParameters.LastPackageNumber = 0;
	
	SetMonitoringCenterParameters(MonitoringCenterParameters);
	
	InformationRegisters.PackagesToSend.Clear();
	
EndProcedure

Procedure SignInToDataArea(Val DataArea)
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.SignInToDataArea(DataArea);
	EndIf;
	
EndProcedure

Procedure SignOutOfDataArea()
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.SignOutOfDataArea();
	EndIf;
	
EndProcedure

Function NotificationOfDumpsParameters()
	ParametersToGet1 = New Structure;
	ParametersToGet1.Insert("SendDumpsFiles");
	ParametersToGet1.Insert("BasicChecksPassed");
	ParametersToGet1.Insert("DumpInstances");
	ParametersToGet1.Insert("DumpOption");
	ParametersToGet1.Insert("DumpType");
	ParametersToGet1.Insert("RequestConfirmationBeforeSending");
	ParametersToGet1.Insert("DumpsInformation");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(ParametersToGet1);
	
	RequestForGettingDumps = MonitoringCenterParameters.SendDumpsFiles = 2
								And MonitoringCenterParameters.BasicChecksPassed;
									
	HasDumps1 = MonitoringCenterParameters.Property("DumpInstances") And MonitoringCenterParameters.DumpInstances.Count();
	SendingRequest = MonitoringCenterParameters.SendDumpsFiles = 1
						And Not IsBlankString(MonitoringCenterParameters.DumpOption)
						And HasDumps1
						And MonitoringCenterParameters.RequestConfirmationBeforeSending
						And MonitoringCenterParameters.DumpType = "3"
						And Not IsBlankString(MonitoringCenterParameters.DumpsInformation)
						And MonitoringCenterParameters.BasicChecksPassed;
						
	NotificationOfDumpsParameters = New Structure;
	NotificationOfDumpsParameters.Insert("RequestForGettingDumps", RequestForGettingDumps);
	NotificationOfDumpsParameters.Insert("SendingRequest", SendingRequest);
	NotificationOfDumpsParameters.Insert("DumpsInformation", MonitoringCenterParameters.DumpsInformation);
	
	Return NotificationOfDumpsParameters;
EndFunction

#Region DumpsCollectionAndSending

// In client/server mode, the function is called by scheduled job DumpsCollectionAndSending.
// From it, two background jobs are started: DumpsCollection and DumpsSending.
//
Procedure CollectAndSendDumps(FromClientAtServer = False, JobID = "") Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ErrorReportCollectionAndSending);
	
	DumpsCollectionAndSendingParameters = GetMonitoringCenterParameters();
	DumpOption = DumpsCollectionAndSendingParameters.DumpOption;
	ComputerName = ComputerName();
	DumpTypeChanged = False;
	
	// Check if dump collection is allowed.
	If DumpsCollectionAndSendingParameters.SendDumpsFiles = 0 Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("en = 'User refused to submit dumps.';"));
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	
	// Check if collection of full dumps was requested.
	If IsBlankString(DumpOption) Then
		Return;
	EndIf;
	
	// Check if it is a time to disconnect.
	If CurrentSessionDate() >= DumpsCollectionAndSendingParameters.DumpCollectingEnd Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("en = 'Dump collection timed out.';"));	
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	
	// Collect full dumps only in the master node.
	If Not IsMasterNode1() Then 
		Return;
	EndIf;
	
	DumpRequirement = DumpIsRequired(DumpOption, DumpOption);
	// If the dump is not required, disable dumps collection.
	If Not DumpRequirement.Required2 Then
		StopFullDumpsCollection();
		Return;
	Else  		
		// 
		// 
		If DumpRequirement.DumpType <> DumpsCollectionAndSendingParameters.DumpType 
			And (DumpRequirement.DumpType = "0" 
				Or DumpsCollectionAndSendingParameters.SendDumpsFiles = 1 
				And DumpRequirement.DumpType = "3") Then			
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("DumpType", DumpRequirement.DumpType);
			DumpsCollectionAndSendingParameters.DumpType = DumpRequirement.DumpType;
			SetPrivilegedMode(False);
			DumpTypeChanged = True;
		EndIf;   		
	EndIf;
	
	// 
	// 
	DumpType = DumpsCollectionAndSendingParameters.DumpType;
	DumpsDirectory = GetDumpsDirectory(DumpType);
	DumpsCollectionAndSendingParameters.Insert("DumpsDirectory", DumpsDirectory.Path);
	If DumpsDirectory.Path = Undefined Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", DumpsDirectory.ErrorDescription);
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;	
	Else
		If DumpsCollectionAndSendingParameters.SendDumpsFiles = 1
			Or DumpsCollectionAndSendingParameters.ForceSendMinidumps = 1
			And DumpsCollectionAndSendingParameters.DumpType = "0" Then
			DumpsCollectionAndSendingParameters.FullDumpsCollectionEnabled.Insert(ComputerName, True);
		EndIf;
	EndIf;                                  
	
	// Get data about free space on the hard drive where dumps are collected.
	SeparatorPosition = StrFind(DumpsDirectory.Path, GetServerPathSeparator());
	If SeparatorPosition = 0 Then
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("SendingResult", NStr("en = 'Cannot determine the drive letter';"));
		SetPrivilegedMode(False);
		StopFullDumpsCollection();
		Return;
	EndIf;
	DriveLetter = Left(DumpsDirectory.Path, SeparatorPosition-1);
		                                    	
	// If dump collection is enabled.
	If DumpsCollectionAndSendingParameters.FullDumpsCollectionEnabled[ComputerName] = True Then
		
		If IsBlankString(JobID) Then
			JobID = "ExecutionAtServer";
		EndIf;
		
		// If the dump type is changed, it is necessary to clear a dumps directory.
		If DumpTypeChanged Then
			FilesDeleted(DumpsDirectory.Path);
		Else
			// Import dumps.
			CollectDumps(DumpsCollectionAndSendingParameters);
		EndIf;
		
		// Export dumps.
		SendDumps(DumpsCollectionAndSendingParameters);
		
		MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer);
		If Not MeasurementResult.Success Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", MeasurementResult.ErrorDescription);
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		// 
		// 
		If MeasurementResult.Value/1024 < DumpsCollectionAndSendingParameters.SpaceReserveEnabled
			And DumpType = "3" Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", NStr("en = 'There is not enough free space to store dumps. Dump collection will be disabled.';"));	
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled");
		FullDumpsCollectionEnabled.Insert(ComputerName, True);
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(New Structure("BasicChecksPassed, FullDumpsCollectionEnabled, SendingResult", True, FullDumpsCollectionEnabled, ""));
		SetPrivilegedMode(False);
		
	Else
		// 
		MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer);
		If Not MeasurementResult.Success Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", MeasurementResult.ErrorDescription);
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		// Check if there is enough free space for collecting full dumps.
		If MeasurementResult.Value/1024 < DumpsCollectionAndSendingParameters.SpaceReserveDisabled
			And DumpType = "3" Then
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("SendingResult", NStr("en = 'There is not enough free space to collect dumps.';"));	
			SetPrivilegedMode(False);
			StopFullDumpsCollection();
			Return;
		EndIf;
		
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(New Structure("BasicChecksPassed, SendingResult", True, ""));
		SetPrivilegedMode(False);
				
		// Automatically generates the current user task in OnFillToDoList.
		
	EndIf;
	
	// Deletes obsolete dumps files, except for requested ones.
	DeleteObsoleteFiles(DumpOption, DumpsDirectory.Path);
			
EndProcedure

Procedure CollectDumps(Parameters)
	
	// Get a dumps storage directory.
	DumpsDirectory = Parameters.DumpsDirectory;
	
	PropertyName = ?(Parameters.RequestConfirmationBeforeSending And Parameters.DumpType = "3", "DumpInstances", "DumpInstancesApproved");
	
	If Not Parameters.Property(PropertyName) Then
		Parameters.Insert(PropertyName, New Map);	
	EndIf;
	
	ComputerName = ComputerName();
		
	// Search for dumps in the directory.
	DumpsFiles = FindFiles(DumpsDirectory, "*.mdmp");
	HasChanges = False;
	// Iterate through the found dumps.
	For Each DumpFile In DumpsFiles Do	    
		
		// If the dumps have a zero offset, delete them immediately.
		If StrFind(DumpFile.BaseName, "00000000") > 0 Then
			FilesDeleted(DumpFile.FullName);
			Continue;
		EndIf;
		
		DumpStructure = DumpDetails(DumpFile.Name);
	 	
		DumpOption = DumpStructure.Process_ + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset;
						
		// If a dump has a non-zero offset, check if this dump is to be sent and if it matches the requested one.
		DumpRequirement = DumpIsRequired(DumpOption, Parameters.DumpOption, Parameters.DumpType);
		If DumpRequirement.Required2 Then
			
			ArchiveName = DumpsDirectory + DumpOption + ".zip"; 
			
			// Archive the dump and write information on it (name + size).
			ZipFileWriter = New ZipFileWriter();
			ZipFileWriter.Open(ArchiveName,,,ZIPCompressionMethod.Deflate);
			ZipFileWriter.Add(DumpFile.FullName);
			ZipFileWriter.Write();
			
			ArchiveFile1 = New File(ArchiveName);
			Size = Round(ArchiveFile1.Size()/1024/1024,3); // 
			
			DumpData = New Structure;
			DumpData.Insert("FullName", ArchiveName);
			DumpData.Insert("Size", Size);
			DumpData.Insert("ComputerName", ComputerName);
			
			Parameters[PropertyName].Insert(DumpOption, DumpData);
			
			HasChanges = True;
			
		EndIf;
		
		// Delete the original dump.
		FilesDeleted(DumpFile.FullName);
		
	EndDo;
	
	If HasChanges Then 
		MonitoringCenterParameters = GetMonitoringCenterParameters(New Structure(PropertyName));
		For Each Record In Parameters[PropertyName] Do
			MonitoringCenterParameters[PropertyName].Insert(Record.Key, Record.Value);	
		EndDo;
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter(PropertyName, MonitoringCenterParameters[PropertyName]);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Procedure SendDumps(Parameters)
	
	Parameters.Insert("DumpInstancesApproved", GetMonitoringCenterParameters("DumpInstancesApproved"));
	
	If Parameters.RequestConfirmationBeforeSending And Parameters.DumpType = "3" Then
		
		If Parameters.Property("DumpInstances") And Parameters.DumpInstances.Count() Then
	
			TemplateRequestForSending = NStr("en = 'Error reports (%1) are ready to be sent.
		                             |Total data volume: %2 MB.
		                             |Send the files for analysis to 1C company?';");	
			
			TotalSpace = 0;
			TotalPieces = 0;
						
			For Each Record In Parameters.DumpInstances Do
				
				DumpOption = Record.Key;
				DumpData = Record.Value; // Structure
				
				// Ask the Monitoring center service if this dump is required.
				DumpRequirement = DumpIsRequired(DumpOption, Parameters.DumpOption, Parameters.DumpType);
				If DumpRequirement.Required2 Then
					TotalPieces = TotalPieces + 1;
					TotalSpace = TotalSpace + DumpData.Size;
				Else
					FilesDeleted(DumpData.FullName);
				EndIf;
				
			EndDo;
			
			// Ask the user if they want to send dumps.
			RequestForSending = StringFunctionsClientServer.SubstituteParametersToString(TemplateRequestForSending, TotalPieces, Format(TotalSpace,"NFD=; NZ=0"));
			SetPrivilegedMode(True);
			SetMonitoringCenterParameter("DumpsInformation", RequestForSending);
			SetPrivilegedMode(False);
			
		EndIf;
		
	Else
		For Each Record In Parameters.DumpInstances Do
			Parameters.DumpInstancesApproved.Insert(Record.Key, Record.Value);
		EndDo;
		
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("DumpInstancesApproved", Parameters.DumpInstancesApproved);
		SetPrivilegedMode(False);
		
	EndIf;             
	
	ComputerName = ComputerName();
	RequiredDump = Parameters.DumpOption;
	
	// Send dumps.
	ArrayOfSent = New Array;
	For Each Record In Parameters.DumpInstancesApproved Do
		// It is reasonable to check if we are using the required machine.
		If ComputerName <> Record.Value.ComputerName Then
			Continue;
		EndIf;
		If DumpSending(Record.Key, Record.Value, RequiredDump, Parameters.DumpType) Then
			ArrayOfSent.Add(Record.Key);
		EndIf;
	EndDo;
	
	// Remove sent dumps from the constant.
	HasChanges = False;
	Parameters.Insert("DumpInstancesApproved", GetMonitoringCenterParameters("DumpInstancesApproved"));
	For Each Item In ArrayOfSent Do
		Parameters.DumpInstancesApproved.Delete(Item);
		HasChanges = True;
	EndDo;
	If HasChanges Then 
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("DumpInstancesApproved", Parameters.DumpInstancesApproved);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

Procedure StopFullDumpsCollection()
	
	Stopped2 = True;
	
	// Clear dumps collection parameters.
	NewParameters = New Structure;
	NewParameters.Insert("DumpOption", "");
	NewParameters.Insert("DumpInstances", New Map);
	NewParameters.Insert("DumpInstancesApproved", New Map);
	NewParameters.Insert("DumpsInformation", "");
	NewParameters.Insert("DumpType", "0");
	NewParameters.Insert("NotificationDate2", Date(1,1,1));
	NewParameters.Insert("BasicChecksPassed", False);
	
	Try
		SetPrivilegedMode(True);
		SetMonitoringCenterParameters(NewParameters);
		SetPrivilegedMode(False);
	Except
		// 
		Stopped2 = False;
	EndTry;
	
	// Change logcfg.
	DumpsDirectory = GetDumpsDirectory("0", True);
	If DumpsDirectory.Path = Undefined Then
		// 
		Stopped2 = False;
	EndIf;
	// Delete dump files.
	If DumpsDirectory.Path <> Undefined Then
		If Not FilesDeleted(DumpsDirectory.Path) Then
			// 
			Stopped2 = False;	
		EndIf;
	EndIf;	 
	
	If Stopped2 Then
		FullDumpsCollectionEnabled = GetMonitoringCenterParameters("FullDumpsCollectionEnabled");
		FullDumpsCollectionEnabled.Delete(ComputerName());
		SetPrivilegedMode(True);
		SetMonitoringCenterParameter("FullDumpsCollectionEnabled", FullDumpsCollectionEnabled); 
		SetPrivilegedMode(False);
		DeleteScheduledJob("ErrorReportCollectionAndSending");
	EndIf;
	
EndProcedure

Procedure DeleteObsoleteFiles(RequiredDump, PathToDirectory)
	
	FilesArray = FindFiles(PathToDirectory,"*");
	For Each File In FilesArray Do             		
		DumpStructure = DumpDetails(File.Name);	 	
		DumpOption = DumpStructure.Process_ + "_" + DumpStructure.PlatformVersion + "_" + DumpStructure.Offset;
		If DumpOption = RequiredDump Then
			Continue;
		EndIf;
		
		// Delete a file that is older than three days.
		If File.Exists() And CurrentSessionDate() - File.GetModificationTime() > 3*86400 Then
			FilesDeleted(File.FullName);
		EndIf;
		
	EndDo;
	
EndProcedure

Function FreeSpaceOnHardDrive(DriveLetter, FromClientAtServer)
	
	QueryResult = New Structure;
	QueryResult.Insert("Value", 0);
	QueryResult.Insert("Success", True);
	QueryResult.Insert("ErrorDescription", ""); 
	
	CommandLine = "typeperf ""\LogicalDisk(" + DriveLetter + ")\Free Megabytes"" -sc 1";
	
	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	ApplicationStartupParameters.ExecutionEncoding = "OEM";
	
	RunResult = FileSystem.StartApplication(CommandLine, ApplicationStartupParameters);
	
	ErrorStream = RunResult.ErrorStream;
	OutputStream = RunResult.OutputStream;
	
	If ValueIsFilled(ErrorStream) Then 
		QueryResult.Success = False;
		QueryResult.ErrorDescription = NStr("en = 'typeperf command error.';");
	Else 
		RowsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(OutputStream, Chars.LF, True, True);
		If RowsArray.Count() >= 2 Then
			SearchRow = RowsArray[1];
			SubstringsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SearchRow, ",", True, True);
			If SubstringsArray.Count() >= 2 Then
				SearchRow = SubstringsArray[1];
				SearchRow = StrReplace(SearchRow,"""","");
				Try
					QueryResult.Value = Number(SearchRow);
					MonitoringCenter.WriteBusinessStatisticsOperationDay(
						"ClientStatistics.SystemInformation.FreeOnDisk." + DriveLetter, "", QueryResult.Value, True);
				Except
					QueryResult.Success = False;
					QueryResult.ErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				EndTry;
			EndIf;
		Else
			QueryResult.Success = False;
			QueryResult.ErrorDescription = NStr("en = 'Cannot parse the result typeperf';");
		EndIf;
	EndIf;
	
	Return QueryResult;
	
EndFunction

// This function returns whether the dump is to be collected.
// If the dump type is specified, the function returns only whether the dump is to be collected.
// If the dump type is not specified, the function returns the dump type and whether the dump is to be collected.
// If the service is not available, collect full dumps.
//
Function DumpIsRequired(DumpOption, RequestedDump, DumpType = "")
	
	Result = New Structure("Required2, DumpType", False, DumpType);
	RequiredDumps = RequiredDumps(DumpOption);
	
	// 
	// 
	If Not RequiredDumps.RequestSuccessful Then
		If DumpOption = RequestedDump Then
			Result.Required2 = True;
			Result.DumpType = "3";
		EndIf;
	Else
		// Check upon collecting and sending the dump.
		If Not IsBlankString(DumpType) Then
			If DumpType = "0" And RequiredDumps.MiniDump Then
				Result.Required2 = True;
			ElsIf DumpType = "3" And RequiredDumps.FullDump Then
				Result.Required2 = True;
			EndIf;
		Else
			// In case when the type of the dump being collected is to be determined.
			If RequiredDumps.MiniDump Then
				Result.Required2 = True;
				Result.DumpType = "0";
			ElsIf RequiredDumps.FullDump Then
				Result.Required2 = True;
				Result.DumpType = "3";
			EndIf;
		EndIf;
	EndIf;  
	
	Return Result;
	
EndFunction

// Returns required dump types by a dump option.
//
Function RequiredDumps(DumpOption)
	Result = New Structure("RequestSuccessful, MiniDump, FullDump", False, False, False);
	
	// Access the HTTP service.
	Parameters = GetSendServiceParameters(); 
		
	// Define whether the dump is up-to-date. 	
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	GUID = String(Parameters.InfoBaseID);
	ResourceAddress = ResourceAddress + "IsDumpNeeded" + "/" + GUID + "/" + DumpOption + "/json";
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", "");
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "GET");
	HTTPParameters.Insert("DataType", "");
	HTTPParameters.Insert("Timeout", 60);
	
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		Response = Common.JSONValue(HTTPResponse.Body, , False);
		Result.MiniDump = Response.MiniDump;
		Result.FullDump = Response.FullDump;
		Result.RequestSuccessful = True;
	EndIf;
	
	Return Result;
EndFunction 

Function CanLoadDump(DumpOption, DumpType)
	
	Result = False;
	
	// Access the HTTP service.
	Parameters = GetSendServiceParameters(); 
		
	// Define whether the dump is relevant. 	
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	GUID = String(Parameters.InfoBaseID);
	ResourceAddress = ResourceAddress + "CanLoadDump" + "/" + GUID + "/" + DumpOption + "/" + DumpType;
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", "");
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "GET");
	HTTPParameters.Insert("DataType", "");
	HTTPParameters.Insert("Timeout", 60);
	
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		Result = HTTPResponse.Body = "true";
	EndIf;
		
	Return Result;
	
EndFunction

Function DumpSending(DumpOption, Data, RequiredDump, DumpType)
	
	SendingResult = False;
	
	// 
	// 
	// 
	File = New File(Data.FullName);
	If Not File.Exists() Then
		Return True;
	EndIf;
	
	// Check if the dump is still relevant. If not, delete it.
	DumpRequirement = DumpIsRequired(DumpOption, RequiredDump, DumpType);
	If Not DumpRequirement.Required2 Then
		FilesDeleted(Data.FullName);
		Return True;
	EndIf;
	
	// Check whether the server allows us to load the dump, it might take some time.
	If Not CanLoadDump(DumpOption, DumpType) Then
		Return False;
	EndIf;
	
	Parameters = GetSendServiceParameters();
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	// Send the dump via the HTTP service.
	GUID = String(Parameters.InfoBaseID);
	Hash = New DataHashing(HashFunction.CRC32);
	Hash.AppendFile(Data.FullName);
	DumpHashSum = Format(Hash.HashSum,"NG=0"); 
	
	ResourceAddress = Parameters.DumpsResourceAddress;
	If Right(ResourceAddress, 1) <> "/" Then
		ResourceAddress = ResourceAddress + "/";
	EndIf;
	
	ResourceAddress = ResourceAddress + "LoadDump" + "/" + GUID + "/" + DumpOption + "/" + DumpHashSum + "/" + DumpType;
	
	HTTPParameters = New Structure;
	HTTPParameters.Insert("Server", Parameters.Server);
	HTTPParameters.Insert("ResourceAddress", ResourceAddress);
	HTTPParameters.Insert("Data", Data.FullName);
	HTTPParameters.Insert("Port", Parameters.Port);
	HTTPParameters.Insert("SecureConnection", Parameters.SecureConnection);	
	HTTPParameters.Insert("Method", "POST");
	HTTPParameters.Insert("DataType", "BinaryData");
	HTTPParameters.Insert("Timeout", 0);
	
	// Archive is deleted upon successful sending.
	HTTPResponse = HTTPServiceSendDataInternal(HTTPParameters);
	
	If HTTPResponse.StatusCode = 200 Then
		SendingResult = HTTPResponse.Body = "true";	
	EndIf;
		
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterSubmitErrorReport", BeginTime);
	EndIf;
	
	Return SendingResult;
		
EndFunction

Function FilesDeleted(Path, Mask = "")
	Try
		DeleteFiles(Path, Mask)
	Except
		Return False;
	EndTry;
	Return True;
EndFunction

Procedure CheckIfNotificationOfDumpsIsRequired(DumpsDirectoryPath)
	
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("SendDumpsFiles");
	MonitoringCenterParameters.Insert("DumpOption");
	MonitoringCenterParameters.Insert("DumpCollectingEnd");
	MonitoringCenterParameters.Insert("DumpsCheckDepth");
	MonitoringCenterParameters.Insert("MinDumpsCount");
	MonitoringCenterParameters.Insert("DumpCheckNext");
	MonitoringCenterParameters.Insert("DumpsCheckFrequency");
	MonitoringCenterParameters.Insert("DumpType");
	MonitoringCenterParameters.Insert("SpaceReserveDisabled");
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	// Administrator refused to collect and send dumps.
	If MonitoringCenterParameters.SendDumpsFiles = 0 Then
		Return;
	EndIf;
	
	CurrentDate = CurrentUniversalDate();
	// Dumps collection is already enabled, checks are not required.
	If Not MonitoringCenterParameters.SendDumpsFiles = 0
		And Not IsBlankString(MonitoringCenterParameters.DumpOption)
		And CurrentDate < MonitoringCenterParameters.DumpCollectingEnd Then
		Return;
	EndIf;  
	
	// If the time for the next check did not come.
	If MonitoringCenterParameters.DumpCheckNext > CurrentDate Then
		Return;
	EndIf;
	
	SetMonitoringCenterParameter("DumpCheckNext", CurrentDate + MonitoringCenterParameters.DumpsCheckFrequency);
	
	StartDate = CurrentDate - MonitoringCenterParameters.DumpsCheckDepth;
	
	SysInfo = New SystemInfo;
	
	TopDumps = InformationRegisters.PlatformDumps.GetTopOptions(StartDate, CurrentDate, 10, SysInfo.AppVersion);
	For Each String In TopDumps Do
		// If the number of dumps exceeds the minimum one, check whether the dump is required.
		If String.OptionsCount >=	MonitoringCenterParameters.MinDumpsCount Then
			// If the dump is required, initiate its collection.
			DumpRequirement = DumpIsRequired(String.DumpOption, "");
			If DumpRequirement.Required2 Then
				If DumpRequirement.DumpType = "3" Then
					// For a full dump, check if there is enough space.
					SeparatorPosition = StrFind(DumpsDirectoryPath, GetServerPathSeparator());
					If SeparatorPosition = 0 Then
						Continue;	
					EndIf;
					DriveLetter = Left(DumpsDirectoryPath, SeparatorPosition-1);
					MeasurementResult = FreeSpaceOnHardDrive(DriveLetter, False);
					If Not MeasurementResult.Success Then
						Continue;
					EndIf;
					If MeasurementResult.Value/1024 < MonitoringCenterParameters.SpaceReserveDisabled Then
						Continue;
					EndIf;
				EndIf;
				
			    // Set dumps collection parameters.
				NewParameters = New Structure;
				NewParameters.Insert("DumpOption", String.DumpOption);
				NewParameters.Insert("DumpCollectingEnd", BegOfDay(CurrentDate)+30*86400);
				// Until the user agrees, cannot enable collection of full dumps.
				If MonitoringCenterParameters.SendDumpsFiles = 1 Then
					NewParameters.Insert("DumpType", DumpRequirement.DumpType);
				Else
					NewParameters.Insert("DumpType", "0");
				EndIf;
				SetMonitoringCenterParameters(NewParameters);
				MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.DumpsRegistration.NotifyAdministrator", 1);
								
				// Abort collection traversal as collecting of dumps is requested from Administrator.
				Break;
				
			EndIf;
		Else
			// Abort collection traversal if the number of dumps is less than the minimum one.
			Break;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region TestPackageSending

// This procedure sends a test package to Monitoring center.
// Parameters:
//  ExecutionParameters        - Structure:
//   * Iterator_SSLy          	   - Number - upon an external call, it must be equal to zero.
//   * TestPackageSending - Boolean
//   * GetID - Boolean
//
Procedure SendTestPackage(ExecutionParameters, ResultAddress) Export
	
	SetPrivilegedMode(True);
	
	ExecutionResult = New Structure("Success, BriefErrorDescription", True, "");
	
	PerformanceMonitorExists = Common.SubsystemExists("StandardSubsystems.PerformanceMonitor");
	If PerformanceMonitorExists Then
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	// Disable parameters to prevent excessive data from being sent.
	DisableEventLogging();
	
	StartDate2 = CurrentUniversalDate();
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("TestPackageSent");
	MonitoringCenterParameters.Insert("TestPackageSendingAttemptCount");
	MonitoringCenterParameters.Insert("SendDataNextGeneration");
	MonitoringCenterParameters.Insert("SendDataGenerationPeriod");
	MonitoringCenterParameters.Insert("EnableMonitoringCenter");
	MonitoringCenterParameters.Insert("ApplicationInformationProcessingCenter");
	MonitoringCenterParameters.Insert("DiscoveryPackageSent");
	
	MonitoringCenterParameters = GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	If TestPackageSendingPossible(MonitoringCenterParameters, StartDate2) And ExecutionParameters.TestPackageSending
		Or GetIDPossible(MonitoringCenterParameters) And ExecutionParameters.GetID Then
		
		Try
			CreatePackageToSend();
		Except
			ExecutionResult.Success = False;
			ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while generating the package.';");
			Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("en = 'Monitoring center.Generate a test package for sending';",
				Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
		EndTry;
		
		Try
			HTTPResponse = SendMonitoringData(ExecutionParameters.TestPackageSending);
			If HTTPResponse.StatusCode = 200 Then
				MonitoringCenterParameters.TestPackageSent = True;
			Else
				ExecutionResult.Success = False;
				ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while sending a package.';");
				Template = NStr("en = 'An HTTP error occurred while sending a package. Code %1';");
				Comment = StringFunctionsClientServer.SubstituteParametersToString(Template, HTTPResponse.StatusCode); 
				WriteLogEvent(NStr("en = 'Monitoring center.Send monitoring test data';",
					Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
			EndIf;
		Except
			ExecutionResult.Success = False;
			ExecutionResult.BriefErrorDescription = NStr("en = 'An error occurred while sending a package.';");
			Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			WriteLogEvent(NStr("en = 'Monitoring center.Send monitoring test data';",
				Common.DefaultLanguageCode()), EventLogLevel.Error,,, Comment);
			MonitoringCenter.WriteBusinessStatisticsOperation("MonitoringCenter.SendMonitoringData.Error", 
				1, Comment);
		EndTry;
		
		If ExecutionResult.Success Then
			ExecutionParameters.Insert("Iterator_SSLy", ExecutionParameters.Iterator_SSLy + 1);
		EndIf;
		
		DiscoveryPackageSent = GetMonitoringCenterParameters("DiscoveryPackageSent");
		
		If ExecutionResult.Success And Not DiscoveryPackageSent And ExecutionParameters.Iterator_SSLy < 2 Then
			// ID is changed, send the package again.
			SendTestPackage(ExecutionParameters, ResultAddress);
		ElsIf ExecutionResult.Success And DiscoveryPackageSent Then	
		
			If ExecutionParameters.GetID Then
				// Send the package with data in one hour.
				SetMonitoringCenterParameter("SendDataNextGeneration", CurrentUniversalDate() + 3600); 
				PutToTempStorage(ExecutionResult, ResultAddress);
				If PerformanceMonitorExists Then
					ModulePerformanceMonitor.EndTimeMeasurement("MonitoringCenterHandshake", BeginTime);
				EndIf;
			EndIf; 			
		ElsIf ExecutionParameters.GetID And Not ExecutionResult.Success Then
			PutToTempStorage(ExecutionResult, ResultAddress);		
		EndIf;
		
		If ExecutionParameters.TestPackageSending Then
			MonitoringCenterParameters.SendDataNextGeneration = CurrentUniversalDate()
			+ GetMonitoringCenterParameters("SendDataGenerationPeriod");
			MonitoringCenterParameters.TestPackageSendingAttemptCount = MonitoringCenterParameters.TestPackageSendingAttemptCount + 1;
			
			MonitoringCenterParameters.Delete("SendDataGenerationPeriod");
			MonitoringCenterParameters.Delete("EnableMonitoringCenter");
			MonitoringCenterParameters.Delete("ApplicationInformationProcessingCenter");
			MonitoringCenterParameters.Delete("DiscoveryPackageSent");
			
			SetMonitoringCenterParameters(MonitoringCenterParameters);
		EndIf;
		
	ElsIf ExecutionParameters.GetID And MonitoringCenterParameters.DiscoveryPackageSent Then
		PutToTempStorage(ExecutionResult, ResultAddress);	
	EndIf;
		
	SetPrivilegedMode(False);
	
EndProcedure

Function TestPackageSendingPossible(MonitoringCenterParameters, StartDate2)
	Return Not MonitoringCenterParameters.TestPackageSent And MonitoringCenterParameters.TestPackageSendingAttemptCount < 3
		And IsMasterNode1() And StartDate2 >= MonitoringCenterParameters.SendDataNextGeneration;
EndFunction
	
Function GetIDPossible(MonitoringCenterParameters)
	Return (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter)
		And IsMasterNode1() And MonitoringCenterParameters.DiscoveryPackageSent = False;
EndFunction

#EndRegion

#Region ConfiguringErrorHandling

Procedure InstallAdditionalErrorHandlingInformation() Export
	InfoBaseID = MonitoringCenter.InfoBaseID();
	// If no ID is specified, don't perform actions.
	If Not ValueIsFilled(InfoBaseID) Then
		Return;
	EndIf;
	If Common.DataSeparationEnabled() And Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		DataArea = ModuleSaaSOperations.SessionSeparatorValue();
	Else
		DataArea = 0;
	EndIf;
	Parameters = New Structure("TheCodeIsExecuted,ErrorProcessing", False, Undefined);
	CodeToExecute = "Parameters.ErrorProcessing = ErrorProcessing;					   
						|Parameters.TheCodeIsExecuted = True;";	
	// 
	// 
	Try
		Common.ExecuteInSafeMode(CodeToExecute, Parameters);
	Except
		// Don't throw an exception.
	EndTry;
	If Parameters.TheCodeIsExecuted Then		
		Try
			If SafeMode() = True Then
				SetSafeModeDisabled(True);
			EndIf;
			SetPrivilegedMode(True);
			CommonSettings = Parameters.ErrorProcessing.GetCommonSettings();					   
			SetPrivilegedMode(False);
			AdditionalInformation = New Structure;
			If ValueIsFilled(CommonSettings.AdditionalReportInformation) Then
				// Считаем, что внутри json. Если нет, то кто-
				AdditionalInformation = Common.JSONValue(CommonSettings.AdditionalReportInformation, , False);
			EndIf;
			If AdditionalInformation.Property("guid") 
				And AdditionalInformation.guid = InfoBaseID Then
				Return;
			EndIf;
			AdditionalInformation.Insert("guid", InfoBaseID);
			AdditionalInformation.Insert("region", DataArea);
			JSONWriter = New JSONWriter;
			JSONWriter.SetString(New JSONWriterSettings(JSONLineBreak.None));
			WriteJSON(JSONWriter, AdditionalInformation);                                  	
			CommonSettings.AdditionalReportInformation = JSONWriter.Close();
			SetPrivilegedMode(True);
			Parameters.ErrorProcessing.SetCommonSettings(CommonSettings);
			SetPrivilegedMode(False);			
		Except
			// Don't throw an exception.
		EndTry;		
	EndIf;
	// ACC:280-on
EndProcedure

Function SettingErrorHandlingSettings(SavedParameters1, ReceivedParameters)
	
	ProcessingResult = New Structure;
	
	Parameters = New Structure;
	Parameters.Insert("TheCodeIsExecuted", False);
	Parameters.Insert("ErrorProcessing", Undefined);
	Parameters.Insert("ErrorReportingMode", Undefined);
	Parameters.Insert("ErrorMessageDisplayVariant", Undefined);
	CodeToExecute = "Parameters.ErrorProcessing = ErrorProcessing;					   
						|Parameters.TheCodeIsExecuted = True;
						|Parameters.ErrorReportingMode = ErrorReportingMode;
						|Parameters.ErrorMessageDisplayVariant = ErrorMessageDisplayVariant;";	   				
	// 
	// 
	Try
		Common.ExecuteInSafeMode(CodeToExecute, Parameters);
	Except
		// Don't throw an exception.
	EndTry;
	If Parameters.TheCodeIsExecuted Then		
		Try
			If SafeMode() = True Then
				SetSafeModeDisabled(True);
			EndIf;
			SetPrivilegedMode(True);
			CommonSettings = Parameters.ErrorProcessing.GetCommonSettings();					   
			EnumerationModeOfSendingErrorInformation = Parameters.ErrorReportingMode;
			EnumerationOfTheErrorMessageDisplayOption = Parameters.ErrorMessageDisplayVariant;
			SetPrivilegedMode(False);
			If CommonSettings.ErrorRegistrationServiceURL = SavedParameters1.ErrorRegistrationServiceURL
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings.ErrorRegistrationServiceURL = ReceivedParameters.ErrorRegistrationServiceURL;
			EndIf;
			// ACC:1036-off
			If CommonSettings.SendReport = EnumerationModeOfSendingErrorInformation[SavedParameters1.SendReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings.SendReport = EnumerationModeOfSendingErrorInformation[ReceivedParameters.SendReport];				
			EndIf;
			// ACC:1036-on
			If CommonSettings.MessageDisplayVariant = EnumerationOfTheErrorMessageDisplayOption[SavedParameters1.ErrorMessageDisplayVariant]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings.MessageDisplayVariant = EnumerationOfTheErrorMessageDisplayOption[ReceivedParameters.ErrorMessageDisplayVariant];
				// Message text.
				ParametersForTheMessageText = New Structure("CommonSettings", CommonSettings);
				CodeToExecute = "MessageString = New FormattedString(NStr(""ru = 'K unfortunately, appeared unforeseen situation'""), StyleFonts.ExtraLargeTextFont);
					|ErrorMessageTexts = New ErrorMessageTexts(MessageString, MessageString);
					|Parameters.CommonSettings.ErrorMessageTexts_SSLy.Insert(ErrorCategory.OtherError, ErrorMessageTexts);";
				Common.ExecuteInSafeMode(CodeToExecute, ParametersForTheMessageText);
			EndIf;
			If CommonSettings.IncludeDetailErrorDescriptionInReport = EnumerationModeOfSendingErrorInformation[SavedParameters1.IncludeDetailErrorDescriptionInReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings.IncludeDetailErrorDescriptionInReport = EnumerationModeOfSendingErrorInformation[ReceivedParameters.IncludeDetailErrorDescriptionInReport];
			EndIf;
			If CommonSettings.IncludeInfobaseInformationInReport = EnumerationModeOfSendingErrorInformation[SavedParameters1.IncludeInfobaseInformationInReport]
				Or ReceivedParameters.SetErrorHandlingSettingsForcibly Then
				CommonSettings.IncludeInfobaseInformationInReport = EnumerationModeOfSendingErrorInformation[ReceivedParameters.IncludeInfobaseInformationInReport];
			EndIf;			
						
			SetPrivilegedMode(True);
			Parameters.ErrorProcessing.SetCommonSettings(CommonSettings);
			SetPrivilegedMode(False);	
			
			ProcessingResult.Insert("SetErrorHandlingSettingsForcibly", ReceivedParameters.SetErrorHandlingSettingsForcibly);
			ProcessingResult.Insert("ErrorMessageDisplayVariant", ReceivedParameters.ErrorMessageDisplayVariant);
			ProcessingResult.Insert("ErrorRegistrationServiceURL", ReceivedParameters.ErrorRegistrationServiceURL);
			ProcessingResult.Insert("SendReport", ReceivedParameters.SendReport);
			ProcessingResult.Insert("IncludeDetailErrorDescriptionInReport", ReceivedParameters.IncludeDetailErrorDescriptionInReport);
			ProcessingResult.Insert("IncludeInfobaseInformationInReport", ReceivedParameters.IncludeInfobaseInformationInReport);
		Except
			// Don't throw an exception.
		EndTry;		
	EndIf;
	// ACC:280-
	Return ProcessingResult;
	
EndFunction

#EndRegion

#Region FullTextSearchUsageData

Procedure GetFullTextSearchUsageStatistics()
	If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Disable Then
		Return;
	EndIf;
	IndexRelevanceHourCount = Round((CurrentSessionDate() - FullTextSearch.UpdateDate())/3600);                              
	MinPlatformVersion = "8.3.22.1000";
	SystemInfo = New SystemInfo;
	If CommonClientServer.CompareVersions(SystemInfo.AppVersion, MinPlatformVersion) > 0 Then
		IdentifiedFullTextSearchVersion = Common.CalculateInSafeMode("?(FullTextSearch.GetFullTextSearchVersion() = FullTextSearchVersion.Version1,1,2)");
		MonitoringCenter.WriteConfigurationObjectStatistics("FullTextSearch.Version", IdentifiedFullTextSearchVersion); 
	EndIf;
	MonitoringCenter.WriteConfigurationObjectStatistics("FullTextSearch.IndexRelevanceHourCount", IndexRelevanceHourCount);   
EndProcedure

#EndRegion

#EndRegion
