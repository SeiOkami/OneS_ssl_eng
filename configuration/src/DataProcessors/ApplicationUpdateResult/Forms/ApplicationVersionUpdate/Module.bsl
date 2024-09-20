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
Var ContinuationParameters;
&AtClient
Var UpdateExecutionResult;
&AtClient
Var CompletionProcessing;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IBUpdateInProgress = True;
	UpdateStartTime = CurrentSessionDate();
	
	ClientServer  = Not Common.FileInfobase();
	Box       = Not Common.DataSeparationEnabled();
	
	ExecutionProgress = 5;
	
	DataUpdateMode = InfobaseUpdateInternal.DataUpdateMode();
	
	UpdateApplicationParametersOnly =
		Not InfobaseUpdate.InfobaseUpdateRequired();
	
	If UpdateApplicationParametersOnly Then
		Title = NStr("en = 'Application parameters update';");
		Items.RunMode.CurrentPage = Items.ApplicationParametersUpdate;
		
	ElsIf DataUpdateMode = "InitialFilling" Then
		Title = NStr("en = 'Initial data population';");
		Items.RunMode.CurrentPage = Items.InitialFilling;
		
	ElsIf DataUpdateMode = "MigrationFromAnotherApplication" Then
		Title = NStr("en = 'Migration from another application';");
		Items.RunMode.CurrentPage = Items.MigrationFromAnotherApplication;
		Items.MigrationFromAnotherApplicationMessageText.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.MigrationFromAnotherApplicationMessageText.Title, Metadata.Synonym);
	Else
		Title = NStr("en = 'Application update';");
		Items.RunMode.CurrentPage = Items.ApplicationVersionUpdate;
		Items.NewConfigurationVersionMessageText.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.NewConfigurationVersionMessageText.Title, Metadata.Version);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If IBUpdateInProgress Then
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TechnicalInformationClick(Item)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ShouldNotRunInBackground", True);
	FilterParameters.Insert("StartDate", UpdateStartTime);
	EventLogClient.OpenEventLog(FilterParameters);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ImportUpdateApplicationParameters(Var_Parameters) Export
	
	ContinuationParameters = Var_Parameters;
	AttachIdleHandler("StartApplicationParametersImport", 0.1, True);
	
EndProcedure

&AtClient
Procedure StartApplicationParametersImport()
	
	ExecutionResult = ImportApplicationParametersInBackground();
	
	If TypeOf(ExecutionResult) = Type("Structure")
		And ExecutionResult.Property("ErrorDeletingFixes") Then
		FailedUpdateMessage(ExecutionResult, Undefined);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure("BriefErrorDescription, DetailErrorDescription");
	
	If ExecutionResult = "SessionRestartRequired" Then
		Terminate(True);
		
	ElsIf ExecutionResult = "ImportApplicationParametersNotRequired" Then
		Result = New Structure("Status", ExecutionResult);
		StartUpdateApplicationParameters(Result, AdditionalParameters);
		Return;
		
	ElsIf ExecutionResult = "ApplicationParametersImportAndUpdateNotRequired" Then
		Result = New Structure("Status", ExecutionResult);
		StartUpdateExtensionVersionParameters(Result, AdditionalParameters);
		Return;
	EndIf;
	
	CompletionNotification2 = New NotifyDescription("StartUpdateApplicationParameters",
		ThisObject, AdditionalParameters);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.Interval = 1;
	IdleParameters.OutputProgressBar = True;
	IdleParameters.ExecutionProgressNotification = New NotifyDescription("ApplicationParametersUpdateProgress", ThisObject); 
	TimeConsumingOperationsClient.WaitCompletion(ExecutionResult, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtServer
Function ImportApplicationParametersInBackground()
	
	RefreshReusableValues();
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable() Then
		
		Return "ApplicationParametersImportAndUpdateNotRequired";
	EndIf;
	
	StartupParameters = StandardSubsystemsServer.ClientParametersAtServer().Get("LaunchParameter");
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate")
		And StrFind(StartupParameters, "UpdateAndExit") = 0 Then
		// 
		// 
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
		Try
			Result = ModuleConfigurationUpdate.PatchesChanged();
		Except
			ErrorInfo = ErrorInfo();
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("ErrorDeletingFixes");
			AdditionalParameters.Insert("BriefErrorDescription",   ErrorProcessing.BriefErrorDescription(ErrorInfo));
			AdditionalParameters.Insert("DetailErrorDescription", ErrorProcessing.DetailErrorDescription(ErrorInfo));
			Return AdditionalParameters;
		EndTry;
		If Result.HasChanges Then
			Return "SessionRestartRequired";
		EndIf;
	EndIf;
	
	If Not InformationRegisters.ApplicationRuntimeParameters.NeedToImportApplicationParameters() Then
		Return "ImportApplicationParametersNotRequired";
	EndIf;
	
	// 
	Return InformationRegisters.ApplicationRuntimeParameters.ImportApplicationParametersInBackground(0,
		UUID, True);
	
EndFunction

&AtClient
Procedure ApplicationParametersUpdateProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Status <> "Running" Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		
		If UpdateApplicationParametersOnly Then
			ExecutionProgress = 5 + (90 * Progress.Progress.Percent / 100);
		Else
			ExecutionProgress = 5 + (5 * Progress.Progress.Percent / 100);
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Procedure StartUpdateApplicationParameters(Result, AdditionalParameters) Export
	
	Try
		ProcessedResult = ProcessedTimeConsumingOperationResult(Result,
			"ImportApplicationParameters");
	Except
		ErrorInfo = ErrorInfo();
		ProcessedResult = New Structure;
		ProcessedResult.Insert("BriefErrorDescription",
			ErrorProcessing.BriefErrorDescription(ErrorInfo));
		ProcessedResult.Insert("DetailErrorDescription",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
	EndTry;
	
	If ValueIsFilled(ProcessedResult.BriefErrorDescription) Then
		FailedUpdateMessage(ProcessedResult, Undefined);
		Return;
	EndIf;
	
	ExecutionResult = UpdateApplicationParametersInBackground();
	
	AdditionalParameters = New Structure("BriefErrorDescription, DetailErrorDescription");
	
	CompletionNotification2 = New NotifyDescription("StartUpdateExtensionVersionParameters",
		ThisObject, AdditionalParameters);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.Interval = 1;
	IdleParameters.OutputProgressBar = True;
	IdleParameters.ExecutionProgressNotification = New NotifyDescription("ApplicationParametersUpdateProgress", ThisObject); 
	TimeConsumingOperationsClient.WaitCompletion(ExecutionResult, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtServer
Function UpdateApplicationParametersInBackground()
	
	// 
	Return InformationRegisters.ApplicationRuntimeParameters.UpdateApplicationParametersInBackground(0,
		UUID, True);
	
EndFunction

&AtClient
Procedure StartUpdateExtensionVersionParameters(Result, AdditionalParameters) Export
	
	Try
		ProcessedResult = ProcessedTimeConsumingOperationResult(Result,
			"ApplicationParametersUpdate");
	Except
		ErrorInfo = ErrorInfo();
		ProcessedResult = New Structure;
		ProcessedResult.Insert("BriefErrorDescription",
			ErrorProcessing.BriefErrorDescription(ErrorInfo));
		ProcessedResult.Insert("DetailErrorDescription",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
	EndTry;
	
	If ValueIsFilled(ProcessedResult.BriefErrorDescription) Then
		FailedUpdateMessage(ProcessedResult, Undefined);
		Return;
	EndIf;
	
	ExecutionResult = UpdateExtensionVersionParametersInBackground();
	
	If ExecutionResult = "ExtensionVersionParametersUpdateNotRequired" Then
		Result = New Structure("Status", ExecutionResult);
		CompleteUpdatingApplicationParameters(Result, AdditionalParameters);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure("BriefErrorDescription, DetailErrorDescription");
	
	CompletionNotification2 = New NotifyDescription("CompleteUpdatingApplicationParameters",
		ThisObject, AdditionalParameters);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.Interval = 1;
	IdleParameters.OutputProgressBar = True;
	IdleParameters.ExecutionProgressNotification = New NotifyDescription("ApplicationParametersUpdateProgress", ThisObject); 
	TimeConsumingOperationsClient.WaitCompletion(ExecutionResult, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtServer
Function UpdateExtensionVersionParametersInBackground()
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return "ExtensionVersionParametersUpdateNotRequired";
	EndIf;
	
	// 
	Return InformationRegisters.ApplicationRuntimeParameters.UpdateExtensionVersionParametersInBackground(0,
		UUID, True);
	
EndFunction

&AtClient
Procedure CompleteUpdatingApplicationParameters(Result, AdditionalParameters) Export
	
	Try
		ProcessedResult = ProcessedTimeConsumingOperationResult(Result,
			"ExtensionVersionParametersUpdate");
	Except
		ErrorInfo = ErrorInfo();
		ProcessedResult = New Structure;
		ProcessedResult.Insert("BriefErrorDescription",
			ErrorProcessing.BriefErrorDescription(ErrorInfo));
		ProcessedResult.Insert("DetailErrorDescription",
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
	EndTry;
	
	If ValueIsFilled(ProcessedResult.BriefErrorDescription) Then
		FailedUpdateMessage(ProcessedResult, Undefined);
		Return;
	EndIf;
	
	ContinuationParameters.RetrievedClientParameters.Insert("ApplicationParametersUpdateRequired");
	ContinuationParameters.Insert("CountOfReceivedClientParameters",
		ContinuationParameters.RetrievedClientParameters.Count());
	
	RefreshReusableValues();
	
	Try
		ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	Except
		ErrorInfo = ErrorInfo();
		AdditionalParameters.Insert("BriefErrorDescription", ErrorProcessing.BriefErrorDescription(ErrorInfo));
		AdditionalParameters.Insert("DetailErrorDescription", ErrorProcessing.DetailErrorDescription(ErrorInfo));
		FailedUpdateMessage(AdditionalParameters, Undefined);
		Return;
	EndTry;
	
	If Not UpdateApplicationParametersOnly
	   And CommonClient.SeparatedDataUsageAvailable() Then
		
		ExecuteNotifyProcessing(ContinuationParameters.ContinuationHandler);
		Return;
	EndIf;
		
	If ClientParameters.Property("SharedInfobaseDataUpdateRequired") Then
		Try
			InfobaseUpdateInternalServerCall.UpdateInfobase(True);
		Except
			ErrorInfo = ErrorInfo();
			AdditionalParameters.Insert("BriefErrorDescription",   ErrorProcessing.BriefErrorDescription(ErrorInfo));
			AdditionalParameters.Insert("DetailErrorDescription", ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EndTry;
		If ValueIsFilled(AdditionalParameters.BriefErrorDescription) Then
			FailedUpdateMessage(AdditionalParameters, Undefined);
			Return;
		EndIf;
	EndIf;
	
	If IBLock <> Undefined
		And IBLock.Property("RemoveFileInfobaseLock") Then
		InfobaseUpdateInternalServerCall.RemoveFileInfobaseLock();
	EndIf;
	CloseForm(False, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UpdateInfobase1() Export
	
	ExecutionProgress = 10;
	AttachIdleHandler("StartInfobaseUpdate1", 0.1, True);
	
EndProcedure

&AtClient
Procedure StartInfobaseUpdate1()
	
	UpdateStartTime = CommonClient.SessionDate();
	
	IBUpdateResult = UpdateInfobaseInBackground();
	
	If Not IBUpdateResult.Property("ResultAddress") Then
		CompleteInfobaseUpdate(IBUpdateResult, Undefined);
		Return;
	EndIf;
	
	If ClientServer And Box Then
		ContinuationProcedure = "RegisterDataForDeferredUpdate";
	Else
		ContinuationProcedure = "CompleteInfobaseUpdate";
	EndIf;
	
	CompletionNotification2 = New NotifyDescription(ContinuationProcedure, ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputProgressBar = True;
	IdleParameters.OutputMessages = True;
	IdleParameters.ExecutionProgressNotification = New NotifyDescription("InfobaseUpdateProgress", ThisObject); 
	TimeConsumingOperationsClient.WaitCompletion(IBUpdateResult, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtServer
Function UpdateInfobaseInBackground()
	
	Result = InfobaseUpdateInternal.UpdateInfobaseInBackground(UUID, IBLock);
	IBLock = Result.IBLock;
	Return Result;
	
EndFunction

// Parameters:
//  Progress - Undefined
//           - Structure:
//               * AdditionalParameters - Structure
//  AdditionalParameters - Undefined
//
&AtClient
Procedure InfobaseUpdateProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Status = "Error" Then
		Return;
	EndIf;
	
	If Progress.Property("AdditionalParameters")
		And Progress.AdditionalParameters.Property("DataExchange") Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ExecutionProgress = 10 + (90 * Progress.Progress.Percent / 100);
	EndIf;
	ProcessRegistrationRuleError(Progress.Messages);
	
EndProcedure

&AtClient
Procedure CompleteInfobaseUpdate(Result, AdditionalParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		HandlersExecutionFlag = IBLock.Error;
		
	ElsIf Result.Status = "Completed2"  Then
		
		ReviseRuntimeResult(Result.ResultAddress,
			Result.BriefErrorDescription,
			Result.DetailErrorDescription,
			HandlersExecutionFlag,
			ExecutionProgress);
		
		ProcessRegistrationRuleError(Result.Messages);
		
	Else // ошибка
		HandlersExecutionFlag = IBLock.Error;
	EndIf;
	
	If HandlersExecutionFlag = "LockScheduledJobsExecution" Then
		RestartWithScheduledJobExecutionLock();
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DocumentUpdatesDetails", Undefined);
	AdditionalParameters.Insert("BriefErrorDescription", Result.BriefErrorDescription);
	AdditionalParameters.Insert("DetailErrorDescription", Result.DetailErrorDescription);
	AdditionalParameters.Insert("UpdateStartTime", UpdateStartTime);
	AdditionalParameters.Insert("UpdateEndTime", CommonClient.SessionDate());
	AdditionalParameters.Insert("HandlersExecutionFlag", HandlersExecutionFlag);
	
	If HandlersExecutionFlag = "ExclusiveModeSettingError" Then
		
		UpdateInfobaseWhenCannotSetExclusiveMode(AdditionalParameters);
		Return;
		
	EndIf;
	
	RemoveFileInfobaseLock = False;
	If IBLock.Property("RemoveFileInfobaseLock", RemoveFileInfobaseLock) Then
		
		If RemoveFileInfobaseLock Then
			InfobaseUpdateInternalServerCall.RemoveFileInfobaseLock();
		EndIf;
		
	EndIf;
	
	UpdateInfobase1Completion(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ProcessRegistrationRuleError(UserMessages)
	
	If UserMessages <> Undefined Then
		For Each UserMessage In UserMessages Do
			
			BeginningOfTheLine = "DataExchange=";
			If StrStartsWith(UserMessage.Text, BeginningOfTheLine) Then
				ExchangePlanName = Mid(UserMessage.Text, StrLen(BeginningOfTheLine) + 1);
			EndIf;
			
		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure UpdateInfobaseWhenCannotSetExclusiveMode(AdditionalParameters)
	
	If AdditionalParameters.HandlersExecutionFlag <> "ExclusiveModeSettingError" Then
		UpdateInfobase1Completion(AdditionalParameters);
		Return;
	EndIf;
	
	If Not CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		FailedUpdateMessage(AdditionalParameters, Undefined);
		Return;
	EndIf;
	
	// Opening a form for disabling active sessions.
	Notification = New NotifyDescription("UpdateInfobaseWhenCannotSetExclusiveModeCompletion",
		ThisObject, AdditionalParameters);
	
	ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
	ModuleIBConnectionsClient.OnOpenExclusiveModeSetErrorForm(Notification);
	
EndProcedure

&AtClient
Procedure UpdateInfobaseWhenCannotSetExclusiveModeCompletion(Cancel, AdditionalParameters) Export
	
	If Cancel <> False Then
		CloseForm(True, False);
		Return;
	EndIf;
	
	SetIBLockParametersWhenCannotSetExclusiveMode();
	StartInfobaseUpdate1();
	
EndProcedure

&AtClient
Procedure SetIBLockParametersWhenCannotSetExclusiveMode()
	
	If IBLock = Undefined Then
		IBLock = New Structure;
	EndIf;
	
	IBLock.Insert("Use", False);
	IBLock.Insert("RemoveFileInfobaseLock", True);
	IBLock.Insert("Error", Undefined);
	IBLock.Insert("SeamlessUpdate", Undefined);
	IBLock.Insert("RecordKey", Undefined);
	IBLock.Insert("DebugMode", Undefined);
	
EndProcedure

&AtClient
Procedure UpdateInfobase1Completion(AdditionalParameters)
	
	If ValueIsFilled(AdditionalParameters.BriefErrorDescription) Then
		
		UpdateEndTime = CommonClient.SessionDate();
		FailedUpdateMessage(AdditionalParameters, UpdateEndTime);
		Return;
		
	EndIf;
	
	UpdateInfobase1CompletionServer(AdditionalParameters);
	RefreshReusableValues();
	
	CloseForm(False, False);
	
EndProcedure

&AtServer
Procedure UpdateInfobase1CompletionServer(AdditionalParameters)
	
	// Если обновление ИБ завершилось - 
	InfobaseUpdateInternal.UnlockIB(IBLock);
	InfobaseUpdateInternal.WriteUpdateExecutionTime(
		AdditionalParameters.UpdateStartTime, AdditionalParameters.UpdateEndTime);
	
	InfobaseUpdateInternal.SetInfobaseUpdateStartup(False);
	SessionParameters.IBUpdateInProgress = False;
	
EndProcedure

&AtClient
Procedure CloseForm(Cancel, Restart)
	
	IBUpdateInProgress = False;
	Close(New Structure("Cancel, Restart", Cancel, Restart));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure RegisterDataForDeferredUpdate(Result, AdditionalParameters) Export
	
	UpdateResult = GetFromTempStorage(Result.ResultAddress);
	
	CompletionProcessing = New NotifyDescription("CompleteInfobaseUpdate", ThisObject, Result);
	UpdateExecutionResult = Result;
	If Result.Status <> "Completed2"
		Or (TypeOf(UpdateResult) = Type("Structure")
			And UpdateResult.Property("BriefErrorDescription")
			And UpdateResult.Property("DetailErrorDescription")) Then
		ExecuteNotifyProcessing(CompletionProcessing, UpdateExecutionResult);
		Return;
	EndIf;
	
	RegistrationState = FillDataForParallelDeferredUpdate();
	If RegistrationState.Status <> "Running" Then
		FillPropertyValues(UpdateExecutionResult, RegistrationState, "Status,BriefErrorDescription,DetailErrorDescription");
		ExecuteNotifyProcessing(CompletionProcessing, UpdateExecutionResult);
	Else
		JobID = RegistrationState.JobID;
		AttachIdleHandler("Attachable_CheckDeferredHandlerFillingProcedures", 5);
	EndIf;
	
EndProcedure

&AtServer
Function FillDataForParallelDeferredUpdate()
	
	// Clearing the InfobaseUpdate exchange plan.
	If Not (StandardSubsystemsCached.DIBUsed("WithFilter") And Common.IsSubordinateDIBNode()) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	InfobaseUpdate.Ref AS Node
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	NOT InfobaseUpdate.ThisNode";
		
		Upload0 = Query.Execute().Unload();
		ExchangeNodes = Upload0.UnloadColumn("Node");
		
		For Each CompositionItem In Metadata.ExchangePlans.InfobaseUpdate.Content Do
			ExchangePlans.DeleteChangeRecords(ExchangeNodes, CompositionItem.Metadata);
		EndDo;
	EndIf;
	
	LibraryDetailsList    = StandardSubsystemsCached.SubsystemsDetails().ByNames;
	ProcessedLibraries = New Array;
	
	TotalProcedureCount = 0;
	Handlers = InfobaseUpdateInternal.HandlersForDeferredDataRegistration(True);
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	SubsystemVersionsAtStartUpdates = UpdateInfo.SubsystemVersionsAtStartUpdates;
	For Each Handler In Handlers Do
		If ProcessedLibraries.Find(Handler.LibraryName) <> Undefined Then
			Continue;
		EndIf;
		
		If LibraryDetailsList[Handler.LibraryName].DeferredHandlersExecutionMode <> "Parallel" Then
			InfobaseUpdateInternal.CanlcelDeferredUpdateHandlersRegistration(Handler.LibraryName, True);
			ProcessedLibraries.Add(Handler.LibraryName);
			Continue;
		EndIf;
		SubsystemVersionAtStartUpdates = SubsystemVersionsAtStartUpdates[Handler.LibraryName];
		
		ParallelSinceVersion = LibraryDetailsList[Handler.LibraryName].ParallelDeferredUpdateFromVersion;
		
		If ValueIsFilled(ParallelSinceVersion)
			And Not StrStartsWith(Handler.Version, "DebuggingTheHandler")
			And (Handler.Version = "*"
				Or Handler.Version <> "*"
				And CommonClientServer.CompareVersions(Handler.Version, ParallelSinceVersion) < 0) Then
			Continue;
		EndIf;
		
		DataToProcessDetails = InfobaseUpdateInternal.NewDataToProcessDetails(
			Handler.Multithreaded,
			True);
		If Handler.Multithreaded Then
			DataToProcessDetails.SelectionParameters =
				InfobaseUpdate.AdditionalMultithreadProcessingDataSelectionParameters();
		EndIf;
		
		DataToProcessDetails.HandlerName = Handler.HandlerName;
		DataToProcessDetails.Queue = Handler.DeferredProcessingQueue;
		DataToProcessDetails.UpToDateData = InfobaseUpdate.UpToDateDataSelectionParameters();
		DataToProcessDetails.FillingProcedure = Handler.UpdateDataFillingProcedure;
		DataToProcessDetails.SubsystemVersionAtStartUpdates = SubsystemVersionAtStartUpdates;
		
		DataToProcessDetails = New ValueStorage(DataToProcessDetails, New Deflation(9));
		InfobaseUpdateInternal.HandlerProperty(Handler.HandlerName, "DataToProcess", DataToProcessDetails);
		
		TotalProcedureCount = TotalProcedureCount + 1;
	EndDo;
	
	If Not Common.IsSubordinateDIBNode()
		And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		ModuleDataExchangeServer.ResetConstantValueWithChangesForSubordinateDIBNodeWithFilters();
	EndIf;
	
	RegistrationProgress = New Structure;
	RegistrationProgress.Insert("InitialProgress", ExecutionProgress);
	RegistrationProgress.Insert("TotalProcedureCount", TotalProcedureCount);
	RegistrationProgress.Insert("ProceduresCompleted", 0);
	
	// 
	InfobaseUpdateInternal.UnlockIB(IBLock);
	
	Return StartDeferredHandlerFillingProcedures();
	
EndFunction

&AtClient
Procedure Attachable_CheckDeferredHandlerFillingProcedures()
	
	Result = CheckDeferredHandlerFillingProcedures();
	
	If Result.Status <> "Running" Then
		FillPropertyValues(UpdateExecutionResult, Result);
		ExecuteNotifyProcessing(CompletionProcessing, UpdateExecutionResult);
		DetachIdleHandler("Attachable_CheckDeferredHandlerFillingProcedures");
	EndIf;
	
EndProcedure

&AtServer
Function StartDeferredHandlerFillingProcedures()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Manage multi-threaded registration of deferred update data';");
	
	ProcedureName = "InfobaseUpdateInternal.StartDeferredHandlerDataRegistration";
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName, UUID, ExecutionParameters);
	
	Return CheckDeferredHandlerFillingProcedures(ExecutionResult);
	
EndFunction

&AtServer
Function CheckDeferredHandlerFillingProcedures(ControllingBackgroundJobExecutionResult = Undefined)
	
	If ControllingBackgroundJobExecutionResult = Undefined Then
		ControllingBackgroundJobExecutionResult = TimeConsumingOperations.ActionCompleted(JobID);
	EndIf;
	
	Status = ControllingBackgroundJobExecutionResult.Status;
	
	If Status = "Completed2" Then
		InfobaseUpdateInternal.CanlcelDeferredUpdateHandlersRegistration();
	ElsIf Status = "Error" Or Status = "Canceled" Then
		Groups = InfobaseUpdateInternal.NewDetailsOfDeferredUpdateDataRegistrationThreadsGroups();
		InfobaseUpdateInternal.CancelAllThreadsExecution(Groups);
		Return ControllingBackgroundJobExecutionResult;
	EndIf;
	
	// Refresh progress.
	ProceduresCompleted = 0;
	Handlers = InfobaseUpdateInternal.HandlersForDeferredDataRegistration();
	For Each Handler In Handlers Do
		DataToProcessDetails = Handler.DataToProcess.Get();
		If DataToProcessDetails.Status = "Completed2" Then
			ProceduresCompleted = ProceduresCompleted + 1;
		EndIf;
	EndDo;
	
	RegistrationProgress.ProceduresCompleted = ProceduresCompleted;
	If RegistrationProgress.TotalProcedureCount <> 0 Then
		ProgressIncrement = RegistrationProgress.ProceduresCompleted / RegistrationProgress.TotalProcedureCount * (100 - RegistrationProgress.InitialProgress);
	Else
		ProgressIncrement = 0;
	EndIf;
	ExecutionProgress = ExecutionProgress + ProgressIncrement;
	
	Return ControllingBackgroundJobExecutionResult;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure BeginClose() Export
	
	AttachIdleHandler("ContinueClosing", 0.1, True);
	
EndProcedure

&AtClient
Procedure ContinueClosing() Export
	
	IBUpdateInProgress = False;
	
	CloseForm(False, False);
	
EndProcedure

&AtClient
Procedure FailedUpdateMessage(AdditionalParameters, UpdateEndTime)
	
	NotifyDescription = New NotifyDescription("UpdateInfobaseActionsOnError", ThisObject);
	
	FormParameters = New Structure;
	FormParameters.Insert("BriefErrorDescription",   AdditionalParameters.BriefErrorDescription);
	FormParameters.Insert("DetailErrorDescription", AdditionalParameters.DetailErrorDescription);
	FormParameters.Insert("UpdateStartTime",      UpdateStartTime);
	FormParameters.Insert("UpdateEndTime",   UpdateEndTime);
	
	If ValueIsFilled(ExchangePlanName) Then
		
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		NameOfFormToOpen_ = ModuleDataExchangeClient.FailedUpdateMessageFormName();
		FormParameters.Insert("ExchangePlanName", ExchangePlanName);
		
	Else	
		NameOfFormToOpen_ = "DataProcessor.ApplicationUpdateResult.Form.FailedUpdateMessage";
	
	EndIf;
	
	OpenForm(NameOfFormToOpen_, FormParameters,,,,,NotifyDescription);
	
EndProcedure

&AtClient
Procedure UpdateInfobaseActionsOnError(ExitApplication, AdditionalParameters) Export
	
	If IBLock <> Undefined
		And IBLock.Property("RemoveFileInfobaseLock") Then
		InfobaseUpdateInternalServerCall.RemoveFileInfobaseLock();
	EndIf;
	
	If ExitApplication <> False Then
		CloseForm(True, False);
	Else
		CloseForm(True, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure RestartWithScheduledJobExecutionLock()
	
	NewStartupParameter = LaunchParameter + ";ScheduledJobsDisabled2";
	NewStartupParameter = "/AllowExecuteScheduledJobs -Off " + "/C """ + NewStartupParameter + """";
	Terminate(True, NewStartupParameter);
	
EndProcedure

&AtServerNoContext
Procedure ReviseRuntimeResult(ResultAddress, BriefErrorDescription,
			DetailErrorDescription, HandlersExecutionFlag, ExecutionProgress)
		
	UpdateResult = GetFromTempStorage(ResultAddress);
	If TypeOf(UpdateResult) = Type("Structure") Then
		If UpdateResult.Property("BriefErrorDescription")
			And UpdateResult.Property("DetailErrorDescription") Then
			BriefErrorDescription = UpdateResult.BriefErrorDescription;
			DetailErrorDescription = UpdateResult.DetailErrorDescription;
		Else
			HandlersExecutionFlag = UpdateResult.Result;
			ExecutionProgress = 100;
		EndIf;
	Else
		HandlersExecutionFlag = UpdateResult;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ProcessedTimeConsumingOperationResult(Result, Operation)
	
	Return InformationRegisters.ApplicationRuntimeParameters.ProcessedTimeConsumingOperationResult(Result, Operation);
	
EndFunction

#EndRegion
