///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// For internal use.
//
Procedure ExportConnectionSettingsForSubordinateDIBNode(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	XMLLine = "";
	Try
		XMLLine = ConnectionSettingsInXML(ConnectionSettings);
	Except
		Raise;
	EndTry;
		
	Constants.SubordinateDIBNodeSettings.Set(XMLLine);
	ExchangePlans.RecordChanges(ConnectionSettings.InfobaseNode,
		Metadata.Constants.SubordinateDIBNodeSettings);
	
EndProcedure

#Region CheckConnectionToCorrespondent

// For internal use.
//
Procedure OnStartTestConnection(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = BackgroundJobKey(ConnectionSettings.ExchangePlanName,			
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Checking connection %1';"), ConnectionSettings.ExchangeMessagesTransportKind));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 connection check is already in progress.';"), ConnectionSettings.ExchangeMessagesTransportKind);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Check connection to peer: %1.';"), ConnectionSettings.ExchangeMessagesTransportKind);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.TestCorrespondentConnection",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnWaitForTestConnection(HandlerParameters, ContinueWait = True) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnCompleteConnectionTest(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region SaveConnectionSettings
// For internal use.
//
Procedure OnStartSaveConnectionSettings(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = BackgroundJobKey(ConnectionSettings.ExchangePlanName,
		NStr("en = 'Save connection settings';"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Saving connection settings for ""%1"" is already in progress.';"), ConnectionSettings.ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Save connection settings: %1';"), ConnectionSettings.ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.SaveConnectionSettings1",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForSaveConnectionSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteConnectionSettingsSaving(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region SaveSynchronizationSettings

// For internal use.
//
Procedure OnStartSaveSynchronizationSettings(SynchronizationSettings, HandlerParameters, ContinueWait = True) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(SynchronizationSettings.ExchangeNode);
	
	BackgroundJobKey = BackgroundJobKey(ExchangePlanName,
		NStr("en = 'Save data synchronization settings';"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Saving data synchronization settings for ""%1"" is already in progress.';"), ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("SynchronizationSettings", SynchronizationSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Save data synchronization settings: %1';"), ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.SaveSynchronizationSettings1",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForSaveSynchronizationSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteSaveSynchronizationSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region DeleteDataSynchronizationSetting

// For internal use.
//
Procedure OnStartDeleteSynchronizationSettings(DeletionSettings, HandlerParameters, ContinueWait = True) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(DeletionSettings.ExchangeNode);
	
	BackgroundJobKey = BackgroundJobKey(ExchangePlanName,
		NStr("en = 'Delete data synchronization settings';"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Deletion of data synchronization settings for ""%1"" is already in progress.';"), ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DeletionSettings", DeletionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Delete data synchronization settings: %1';"), ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.DeleteSynchronizationSetting",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForDeleteSynchronizationSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteSynchronizationSettingsDeletion(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region DataRegistrationForInitialExport

// For internal use.
//
Procedure OnStartRecordDataForInitialExport(RegistrationSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Register data for initial export (%1)';"),
		RegistrationSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data registration for initial export to ""%1"" is already running.';"),
			RegistrationSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("RegistrationSettings", RegistrationSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Register data for initial export (%1)';"),
		RegistrationSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.RegisterDataForInitialExport",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForRecordDataForInitialExport(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteDataRecordingForInitialExport(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region XDTOSettingsImport

// For internal use.
//
Procedure OnStartImportXDTOSettings(ImportSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Import XDTO settings (%1)';"),
		ImportSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Import of XDTO settings for ""%1"" is already in progress.';"),
			ImportSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ImportSettings", ImportSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Import XDTO settings (%1)';"),
		ImportSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground1    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.ImportXDTOCorrespondentSettings",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForImportXDTOSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteImportXDTOSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region MigrationToWebService

Procedure ChangeNodeTransportInWS(Node, Endpoint, CorrespondentDataArea) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Peer", Node);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	RecordStructure.Insert("WSCorrespondentEndpoint", Endpoint);
	RecordStructure.Insert("WSRememberPassword", True);
	RecordStructure.Insert("WSCorrespondentDataArea", CorrespondentDataArea);
	RecordStructure.Insert("WSUseLargeVolumeDataTransfer", True);
		
	Try
	
		InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
		RecordStructure = New Structure("Peer", Node);
		DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure,"DataAreaExchangeTransportSettings");
	
	Except
		
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeWebService.EventLogEventTransportChangedOnWS(),
			EventLogLevel.Error, , , ErrorMessage);
		
		Raise ErrorMessage;
		
	EndTry;
		
EndProcedure

Procedure ChangeTransportOfPeerNodeOnWS(Node, Endpoint, CorrespondentEndpoint, DataArea) Export
		
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsForInfobaseNode(
		Node, "ChangeOfPeerNodeTransport", Undefined, False);

	SetPrivilegedMode(True);
	
	ModuleMessagesExchangeTransportSettings = Common.CommonModule("InformationRegisters.MessageExchangeTransportSettings");
	AuthenticationSettingsStructure = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(CorrespondentEndpoint);
	
	EndpointCode = Common.ObjectAttributeValue(Endpoint,"Code");
	
	SetPrivilegedMode(False);
	
	Try
		
		InterfaceVersions = DataExchangeCached.CorrespondentVersions(AuthenticationSettingsStructure);
		
	Except
		
		ErrorMessageInCorrespondent = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessageInCorrespondent);
		
		Raise ErrorMessageInCorrespondent;
		
	EndTry;
	
	ErrorMessageString = "";
	Proxy = Undefined;
	If InterfaceVersions.Find("3.0.2.1") <> Undefined Then   
		Proxy = DataExchangeServer.GetWSProxy_3_0_2_1(AuthenticationSettingsStructure, ErrorMessageString);
	EndIf;
			
	CorrespondentNodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangeSettingsStructure.ExchangePlanName);
	CorrespondentDataArea = SessionParameters["DataAreaValue"];
	
	Parameters = New Structure;
	Parameters.Insert("ExchangePlanName", ExchangeSettingsStructure.ExchangePlanName);
	Parameters.Insert("CorrespondentNodeCode", CorrespondentNodeCode);
	Parameters.Insert("CorrespondentEndpoint", EndpointCode);
	Parameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	
	Try
		
		Proxy.ChangeNodeTransportToWSInt(XDTOSerializer.WriteXDTO(Parameters), DataArea);
		 
	Except
		
		ErrorMessageInCorrespondent = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessageInCorrespondent);
		
		Raise ErrorMessageInCorrespondent;
		
	EndTry;
		
EndProcedure

#EndRegion

Function DataExchangeSettingsFormatVersion() Export
	
	Return "1.2";
	
EndFunction

// For internal use.
//
Procedure OnStartGetDataExchangeSettingOptions(UUID, HandlerParameters, ContinueWait) Export
	
	StandardSettingsTable = Undefined;
	OnGetAvailableDataSynchronizationSettings(StandardSettingsTable);
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("ResultAddressDefaultSettings", PutToTempStorage(StandardSettingsTable, UUID));
	
	If Common.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
		ContinueWait = True;
		
		SettingVariants = ExternalSystemsDataExchangeSettingsOptionDetails();
		
		ProcedureParameters = New Structure;
		ProcedureParameters.Insert("SettingVariants", SettingVariants);
		ProcedureParameters.Insert("ExchangeNode",       Undefined);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = NStr("en = 'Get available setup options for data exchange with external systems';");
		ExecutionParameters.WaitCompletion = 0;
		ExecutionParameters.RunInBackground    = True;
		
		BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
			"DataExchangeWithExternalSystems.OnGetDataExchangeSettingsOptions",
			ProcedureParameters,
			ExecutionParameters);
			
		HandlerParameterExternalSystems = Undefined;	
		OnStartTimeConsumingOperation(BackgroundJob, HandlerParameterExternalSystems, ContinueWait);
		
		HandlerParameters.Insert("HandlerParameterExternalSystems", HandlerParameterExternalSystems);
		
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure OnWaitForGetDataExchangeSettingOptions(HandlerParameters, ContinueWait) Export
	
	If HandlerParameters.Property("HandlerParameterExternalSystems") Then
		OnWaitTimeConsumingOperation(HandlerParameters.HandlerParameterExternalSystems, ContinueWait);
	Else
		ContinueWait = False;
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure OnCompleteGettingDataExchangeSettingsOptions(HandlerParameters, Result) Export
	
	Result = New Structure;
	Result.Insert("ExchangeDefaultSettings", GetFromTempStorage(HandlerParameters.ResultAddressDefaultSettings));
	
	If HandlerParameters.Property("HandlerParameterExternalSystems") Then
		
		SettingsExternalSystems = New Structure;
		SettingsExternalSystems.Insert("ErrorCode"); // 
		SettingsExternalSystems.Insert("ErrorMessage");
		SettingsExternalSystems.Insert("SettingVariants");
		
		CompletionStatusExternalSystems = Undefined;
		OnCompleteTimeConsumingOperation(HandlerParameters.HandlerParameterExternalSystems, CompletionStatusExternalSystems);
		
		If CompletionStatusExternalSystems.Cancel Then
			SettingsExternalSystems.ErrorCode = "BackgroundJobError";
			SettingsExternalSystems.ErrorMessage = CompletionStatusExternalSystems.ErrorMessage;
		Else
			FillPropertyValues(SettingsExternalSystems, CompletionStatusExternalSystems.Result);
		EndIf;
		
		Result.Insert("SettingsExternalSystems", SettingsExternalSystems);
		
	EndIf;
	
EndProcedure

Function ExternalSystemsDataExchangeSettingsOptionDetails() Export
	
	SettingVariants = New ValueTable;
	SettingVariants.Columns.Add("ExchangePlanName",                                 New TypeDescription("String"));
	SettingVariants.Columns.Add("SettingID",                         New TypeDescription("String"));
	SettingVariants.Columns.Add("NewDataExchangeCreationCommandTitle", New TypeDescription("String"));
	SettingVariants.Columns.Add("BriefExchangeInfo",                      New TypeDescription("FormattedString"));
	SettingVariants.Columns.Add("DetailedExchangeInformation",                    New TypeDescription("String"));
	SettingVariants.Columns.Add("ExchangeCreateWizardTitle",               New TypeDescription("String"));
	SettingVariants.Columns.Add("CorrespondentDescription",                     New TypeDescription("String"));
	SettingVariants.Columns.Add("ConnectionParameters");
	
	Return SettingVariants;
	
EndFunction

Function SettingOptionDetailsStructure() Export
	
	SettingOptionDetails = New Structure;
	SettingOptionDetails.Insert("NewDataExchangeCreationCommandTitle", "");
	SettingOptionDetails.Insert("BriefExchangeInfo", New FormattedString(""));
	SettingOptionDetails.Insert("DetailedExchangeInformation", "");
	SettingOptionDetails.Insert("ExchangeCreateWizardTitle", "");
	SettingOptionDetails.Insert("CorrespondentDescription", "");
	
	Return SettingOptionDetails;
	
EndFunction

#EndRegion

#Region Private

#Region TimeConsumingOperations1

// For internal use.
//
Procedure OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait = True)
	
	InitializeTimeConsumingOperationHandlerParameters(HandlerParameters, BackgroundJob);
	
	If BackgroundJob.Status = "Running" Then
		HandlerParameters.ResultAddress       = BackgroundJob.ResultAddress;
		HandlerParameters.OperationID = BackgroundJob.JobID;
		HandlerParameters.TimeConsumingOperation    = True;
		
		ContinueWait = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed2" Then
		HandlerParameters.ResultAddress    = BackgroundJob.ResultAddress;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	Else
		HandlerParameters.ErrorMessage = BackgroundJob.BriefErrorDescription;
		If ValueIsFilled(BackgroundJob.DetailErrorDescription) Then
			WriteLogEvent(
				DataExchangeServer.DataExchangeEventLogEvent(), 
				EventLogLevel.Error,
				Metadata.DataProcessors.DataExchangeCreationWizard,
				,
				BackgroundJob.DetailErrorDescription);
		EndIf;
		
		HandlerParameters.Cancel = True;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait = True)
	
	If HandlerParameters.Cancel
		Or Not HandlerParameters.TimeConsumingOperation Then
		ContinueWait = False;
		Return;
	EndIf;
	
	JobCompleted = False;
	Try
		JobCompleted = TimeConsumingOperations.JobCompleted(HandlerParameters.OperationID);
	Except
		HandlerParameters.Cancel             = True;
		HandlerParameters.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , HandlerParameters.ErrorMessage);
	EndTry;
		
	If HandlerParameters.Cancel Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = Not JobCompleted;
	
EndProcedure

// For internal use.
//
Procedure OnCompleteTimeConsumingOperation(HandlerParameters,
		CompletionStatus = Undefined)
	
	CompletionStatus = New Structure;
	CompletionStatus.Insert("Cancel",             False);
	CompletionStatus.Insert("ErrorMessage", "");
	CompletionStatus.Insert("Result",         Undefined);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		CompletionStatus.Result = GetFromTempStorage(HandlerParameters.ResultAddress);
	EndIf;
	
	HandlerParameters = Undefined;
		
EndProcedure

Procedure InitializeTimeConsumingOperationHandlerParameters(HandlerParameters, BackgroundJob)
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("BackgroundJob",          BackgroundJob);
	HandlerParameters.Insert("Cancel",                   False);
	HandlerParameters.Insert("ErrorMessage",       "");
	HandlerParameters.Insert("TimeConsumingOperation",      False);
	HandlerParameters.Insert("OperationID",   Undefined);
	HandlerParameters.Insert("ResultAddress",         Undefined);
	HandlerParameters.Insert("AdditionalParameters", New Structure);
	
EndProcedure

Function BackgroundJobKey(ExchangePlanName, Action)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Exchange plan: %1, action: %2';"), ExchangePlanName, Action);
	
EndFunction

Function HasActiveBackgroundJobs(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key",      BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

#EndRegion

Procedure OnGetAvailableDataSynchronizationSettings(SettingsTable1)
	
	SettingsTable1 = New ValueTable;
	SettingsTable1.Columns.Add("ExchangePlanName",                                 New TypeDescription("String"));
	SettingsTable1.Columns.Add("SettingID",                         New TypeDescription("String"));
	SettingsTable1.Columns.Add("CorrespondentConfigurationName",                  New TypeDescription("String"));
	SettingsTable1.Columns.Add("CorrespondentConfigurationDescription",         New TypeDescription("String"));
	SettingsTable1.Columns.Add("NewDataExchangeCreationCommandTitle", New TypeDescription("String"));
	SettingsTable1.Columns.Add("ExchangeCreateWizardTitle",               New TypeDescription("String"));
	SettingsTable1.Columns.Add("BriefExchangeInfo",                      New TypeDescription("String"));
	SettingsTable1.Columns.Add("DetailedExchangeInformation",                    New TypeDescription("String"));
	SettingsTable1.Columns.Add("IsDIBExchangePlan",                               New TypeDescription("Boolean"));
	SettingsTable1.Columns.Add("IsXDTOExchangePlan",                              New TypeDescription("Boolean"));
	SettingsTable1.Columns.Add("ExchangePlanNameToMigrateToNewExchange",          New TypeDescription("String"));
	
	ExchangePlansList = ExchangePlansForSynchronizationSetup();
	
	For Each ExchangePlanName In ExchangePlansList Do
		
		FillTableWithExchangePlanSettingsOptions(SettingsTable1, ExchangePlanName);

	EndDo;
	
	DeleteObsoleteSettingsOptionsSaaS(SettingsTable1);
	
EndProcedure

Function ExchangePlansForSynchronizationSetup()
	
	ExchangePlansList = New Array;
	
	IsFullUser = Users.IsFullUser(, True);
	
	SaaSModel = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
	
	If SaaSModel Then
		ModuleDataExchangeSaaSCached = Common.CommonModule("DataExchangeSaaSCached");
		ExchangePlansList = ModuleDataExchangeSaaSCached.DataSynchronizationExchangePlans();
	Else
		ExchangePlansList = DataExchangeCached.SSLExchangePlans();
	EndIf;
	
	For Indus = -ExchangePlansList.UBound() To 0 Do
		
		ExchangePlanName = ExchangePlansList[-Indus];
		
		If (Not IsFullUser
				And DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName))
			Or Not DataExchangeCached.ExchangePlanUsageAvailable(ExchangePlanName) Then
			// 
			ExchangePlansList.Delete(-Indus);
		EndIf;
		
	EndDo;
	
	Return ExchangePlansList;
	
EndFunction

Procedure FillTableWithExchangePlanSettingsOptions(SettingsTable1, ExchangePlanName)
	
	ExchangeSettings = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"ExchangeSettingsOptions, ExchangePlanNameToMigrateToNewExchange");
	
	For Each SettingsMode In ExchangeSettings.ExchangeSettingsOptions Do
		PredefinedSetting = SettingsMode.SettingID;
		
		SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
			"UseDataExchangeCreationWizard,
			|CorrespondentConfigurationName,
			|CorrespondentConfigurationDescription,
			|NewDataExchangeCreationCommandTitle,
			|ExchangeCreateWizardTitle,
			|BriefExchangeInfo,
			|DetailedExchangeInformation",
			PredefinedSetting);
			
		If Not SettingsValuesForOption.UseDataExchangeCreationWizard Then
			Continue;
		EndIf;
		
		SettingString = SettingsTable1.Add();
		FillPropertyValues(SettingString, SettingsValuesForOption);
		
		SettingString.ExchangePlanName = ExchangePlanName;
		SettingString.SettingID = PredefinedSetting;
		SettingString.IsDIBExchangePlan  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
		SettingString.IsXDTOExchangePlan = DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName);
		SettingString.ExchangePlanNameToMigrateToNewExchange = ExchangeSettings.ExchangePlanNameToMigrateToNewExchange;
		
	EndDo;
	
EndProcedure

Procedure DeleteObsoleteSettingsOptionsSaaS(SettingsTable1)
	
	SaaSModel = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
		
	If Not SaaSModel Then
		Return;
	EndIf;
	
	XTDOExchangePlans     = New Array;
	ObsoleteSettings = New Array;
	
	For Each SettingString In SettingsTable1 Do
		If SettingString.IsXDTOExchangePlan Then
			If XTDOExchangePlans.Find(SettingString.ExchangePlanName) = Undefined Then
				XTDOExchangePlans.Add(SettingString.ExchangePlanName);
			EndIf;
			Continue;
		EndIf;
		If Not ValueIsFilled(SettingString.ExchangePlanNameToMigrateToNewExchange) Then
			Continue;
		EndIf;
		ObsoleteSettings.Add(SettingString);
	EndDo;
	
	XDTOSettingsTable = SettingsTable1.Copy(New Structure("IsXDTOExchangePlan", True));
	
	SettingsForDelete = New Array;
	For Each SettingString In ObsoleteSettings Do
		For Each XTDOExchangePlan In XTDOExchangePlans Do
			SettingsMode = DataExchangeServer.ExchangeSetupOptionForCorrespondent(
				XTDOExchangePlan, SettingString.CorrespondentConfigurationName);
			If Not ValueIsFilled(SettingsMode) Then
				Continue;
			EndIf;
			XDTOSettings = XDTOSettingsTable.FindRows(New Structure("SettingID", SettingsMode));	
			If XDTOSettings.Count() > 0 Then
				SettingsForDelete.Add(SettingString);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	For Cnt = 1 To SettingsForDelete.Count() Do
		SettingsTable1.Delete(SettingsForDelete[Cnt - 1]);
	EndDo;
	
EndProcedure

Procedure OnConnectToCorrespondent(Cancel, ExchangePlanName, Val CorrespondentVersion, ErrorMessage = "")
	
	If Not ValueIsFilled(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;

	Try
		DataExchangeServer.OnConnectToCorrespondent(ExchangePlanName, CorrespondentVersion);
	Except
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Event handler error: OnConnectToCorrespondent. Details: %1%2';"),
				Chars.LF, ErrorMessage));
				
		Cancel = True;
	EndTry;
	
EndProcedure

Procedure TestCorrespondentConnection(Parameters, ResultAddress) Export
	
	ConnectionSettings = Undefined;
	Parameters.Property("ConnectionSettings", ConnectionSettings);
	
	CheckResult = New Structure;
	CheckResult.Insert("ConnectionIsSet", False);
	CheckResult.Insert("ConnectionAllowed",   False);
	CheckResult.Insert("InterfaceVersions",       Undefined);
	CheckResult.Insert("ErrorMessage",      "");
	
	CheckResult.Insert("CorrespondentParametersReceived", False);
	CheckResult.Insert("CorrespondentParameters",         Undefined);
	
	CheckResult.Insert("ThisNodeExistsInPeerInfobase", False);
	CheckResult.Insert("ThisInfobaseHasPeerInfobaseNode", False);
	CheckResult.Insert("NodeToDelete", Undefined);
	
	CheckResult.Insert("CorrespondentExchangePlanName", ConnectionSettings.CorrespondentExchangePlanName);
	
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
		
		ExternalConnection = Result.Join;
		If ExternalConnection = Undefined Then
			CheckResult.ErrorMessage = Result.BriefErrorDetails;
			CheckResult.ConnectionIsSet = False;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		CheckResult.InterfaceVersions = DataExchangeServer.InterfaceVersionsThroughExternalConnection(ExternalConnection);
		
		If CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined
			Or CheckResult.InterfaceVersions.Find("3.0.2.1") <> Undefined 
			Or CheckResult.InterfaceVersions.Find("3.0.2.2") Then 
			
			ErrorMessage = "";
			
			If CheckResult.InterfaceVersions.Find("3.0.2.2") <> Undefined Then
				
				AdditionalParameters = New Structure;
				If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
					AdditionalParameters.Insert("IsXDTOExchangePlan", True);
				EndIf;
				
				InfoBaseAdmParams = ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_3_0_2_2(
					ConnectionSettings.ExchangePlanName,
					ConnectionSettings.SourceInfobaseID,
					ErrorMessage,
					AdditionalParameters);
			Else
				InfoBaseAdmParams = ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(
					ConnectionSettings.ExchangePlanName, ConnectionSettings.SourceInfobaseID, ErrorMessage);
			EndIf;
				
			CorrespondentParameters = Common.ValueFromXMLString(InfoBaseAdmParams);
			If Not CorrespondentParameters.ExchangePlanExists Then
				CheckResult.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Exchange plan ""%1"" is not found in the peer application.
					|Ensure that the following data is correct:
					|- The application type selected in the exchange settings.
					|- The application location specified in the connection settings.';"),
					ConnectionSettings.ExchangePlanName);
					
				PutToTempStorage(CheckResult, ResultAddress);
				Return;
			EndIf;
							
			CheckResult.CorrespondentParametersReceived = True;
			CheckResult.CorrespondentParameters = CorrespondentParameters;
			
			CheckResult.CorrespondentExchangePlanName = CorrespondentParameters.ExchangePlanName;
			
		Else
			
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = NStr("en = 'The peer infobase does not support version 3.0.1.1 of the DataExchange interface.
			|To set up the connection, update the peer infobase configuration or start setting up from it.';");
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
			
		EndIf;
		
		Cancel = False;
		ErrorMessage = "";
		
		OnConnectToCorrespondent(Cancel, ConnectionSettings.ExchangePlanName,
			CheckResult.CorrespondentParameters.ConfigurationVersion, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckForDuplicateSyncs(ConnectionSettings, CorrespondentParameters, CheckResult, ResultAddress);

		CheckResult.ConnectionAllowed = True;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		AuthenticationSettingsStructure = AuthenticationSettingsStructure(ConnectionSettings);
		
		Try
			CheckResult.InterfaceVersions = DataExchangeCached.CorrespondentVersions(AuthenticationSettingsStructure);
		Except
			Information = ErrorInfo();
			CheckResult.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
			CheckResult.ConnectionIsSet = False;
			
			WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
				EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndTry;
		
		ErrorMessageString = "";
		WSProxy = Undefined;
		If CheckResult.InterfaceVersions.Find("3.0.2.2") <> Undefined Then   
			WSProxy = DataExchangeServer.GetWSProxy_3_0_2_2(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "3.0.2.2";
		ElsIf CheckResult.InterfaceVersions.Find("3.0.2.1") <> Undefined Then
			WSProxy = DataExchangeServer.GetWSProxy_3_0_2_1(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "3.0.2.1"
		ElsIf CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			WSProxy = DataExchangeServer.GetWSProxy_3_0_1_1(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "3.0.1.1";
		ElsIf CheckResult.InterfaceVersions.Find("2.1.1.7") <> Undefined Then
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "2.1.1.7";
		ElsIf CheckResult.InterfaceVersions.Find("2.0.1.6") <> Undefined Then
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "2.0.1.6";
		Else
			WSProxy = DataExchangeServer.GetWSProxy(AuthenticationSettingsStructure, ErrorMessageString);
			CurrentVersion = "0.0.0.0";
		EndIf;
		
		If WSProxy = Undefined Then
			CheckResult.ConnectionIsSet = False;
			CheckResult.ErrorMessage = ErrorMessageString;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		
		If CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined 
			Or CheckResult.InterfaceVersions.Find("3.0.2.1") <> Undefined 
			Or CheckResult.InterfaceVersions.Find("3.0.2.2") <> Undefined Then
			
			ErrorMessage = "";
			
			AdditionalParameters = New Structure;
			If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
				AdditionalParameters.Insert("IsXDTOExchangePlan", True);
			EndIf;
			
			InfoBaseAdmParams = DataExchangeWebService.GetParametersOfInfobase(WSProxy, CurrentVersion,
				ConnectionSettings.CorrespondentExchangePlanName,
				ConnectionSettings.SourceInfobaseID,
				ErrorMessage,
				ConnectionSettings.WSCorrespondentDataArea,
				AdditionalParameters);
  
			CorrespondentParameters = XDTOSerializer.ReadXDTO(InfoBaseAdmParams);
			If Not CorrespondentParameters.ExchangePlanExists Then
				CheckResult.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Exchange plan ""%1"" is not found in the peer application.
					|Ensure that the following data is correct:
					|- The application type selected in the exchange settings.
					|- The web application address.';"),
					ConnectionSettings.CorrespondentExchangePlanName);
				
				PutToTempStorage(CheckResult, ResultAddress);
				Return;
			EndIf;
			
			CheckResult.CorrespondentParametersReceived = True;
			CheckResult.CorrespondentParameters = CorrespondentParameters;
			
			CheckResult.CorrespondentExchangePlanName = CorrespondentParameters.ExchangePlanName;
			
		Else
			
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = 
				NStr("en = 'The peer infobase does not support the DataExchange interface version 3.0.1.1 or 3.0.2.1.
				      |To set up the connection, update the peer infobase configuration or start setting up from it.';");
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
			
		EndIf;
		
		Cancel = False;
		ErrorMessage = "";
		
		OnConnectToCorrespondent(Cancel, ConnectionSettings.ExchangePlanName,
			CheckResult.CorrespondentParameters.ConfigurationVersion, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckForDuplicateSyncs(ConnectionSettings, CorrespondentParameters, CheckResult, ResultAddress);	

		CheckResult.ConnectionAllowed = True;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		
		Cancel = False;
		ErrorMessage = "";
		
		DataExchangeServer.CheckExchangeMessageTransportDataProcessorAttachment(Cancel,
			ConnectionSettings, ConnectionSettings.ExchangeMessagesTransportKind, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionIsSet = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		CheckResult.ConnectionAllowed   = True;
		
	EndIf;
	
	PutToTempStorage(CheckResult, ResultAddress);
	
EndProcedure

Procedure CheckForDuplicateSyncs(ConnectionSettings, CorrespondentParameters, CheckResult, ResultAddress)
	
	If ConnectionSettings.SourceInfobaseID = "" Then
		Return;
	EndIf;
	
	ManagerExchangePlan = ExchangePlans[ConnectionSettings.ExchangePlanName];
	ThisNode = ManagerExchangePlan.ThisNode();
	If DataExchangeServer.IsXDTOExchangePlan(ThisNode)
		And DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(ThisNode) Then
		
		NodeRef1 = ManagerExchangePlan.FindByCode(CorrespondentParameters.ThisNodeCode);		
		
		If Not NodeRef1.IsEmpty() Then
			CheckResult.ThisInfobaseHasPeerInfobaseNode = True;
			CheckResult.NodeToDelete = NodeRef1;	
		EndIf;
		
		CheckResult.ThisNodeExistsInPeerInfobase = CorrespondentParameters.NodeExists;	
			
		If CheckResult.ThisNodeExistsInPeerInfobase 
			Or CheckResult.ThisInfobaseHasPeerInfobaseNode Then
			CheckResult.ErrorMessage = NStr("en = 'Duplicate synchronization settings are detected';");	
		EndIf;
						
	EndIf;
	
EndProcedure

Procedure SaveConnectionSettings1(Parameters, ResultAddress) Export
	
	ConnectionSettings = Undefined;
	Parameters.Property("ConnectionSettings", ConnectionSettings);
	
	Result = New Structure;
	Result.Insert("ConnectionSettingsSaved", False);
	Result.Insert("HasDataToMap",    False); // Только для offline-
	Result.Insert("ExchangeNode",                    Undefined);
	Result.Insert("ErrorMessage",             "");
	Result.Insert("XMLConnectionSettingsString",  "");
	
	Cancel = False;
	
	// Fix sync settings duplicates.
	If ConnectionSettings.FixDuplicateSynchronizationSettings Then
		
		ManagerExchangePlan = ExchangePlans[ConnectionSettings.ExchangePlanName];
		
		If ConnectionSettings.ThisNodeExistsInPeerInfobase Then
						
			BeginTransaction();
			Try
				
				ThisNode = ManagerExchangePlan.ThisNode();
				
				DataLock = New DataLock;
				
				DataLockItem = DataLock.Add("ExchangePlan." + ConnectionSettings.ExchangePlanName);
				DataLockItem.SetValue("Ref", ThisNode);
						
				DataLock.Lock();

				NewCode = String(New UUID);
				
				ExchangeNodeObject = ThisNode.GetObject();
				ExchangeNodeObject.Code = NewCode;
				ExchangeNodeObject.DataExchange.Load = True;
				ExchangeNodeObject.Write();
								
				ConnectionSettings.SourceInfobaseID 	= NewCode;
				ConnectionSettings.PredefinedNodeCode 					= NewCode;
				
				CommitTransaction();
				
			Except

				RollbackTransaction();
				
				Cancel = True;
				
				Information = ErrorInfo();
				Result.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
							
				WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
				
				PutToTempStorage(Result, ResultAddress);

			EndTry;
		
		EndIf;
		
		NodeRef1 = ManagerExchangePlan.FindByCode(ConnectionSettings.DestinationInfobaseID);		
		TheNodeExistsInThisDatabase = Not NodeRef1.IsEmpty();
		
		If TheNodeExistsInThisDatabase And ConnectionSettings.ThisInfobaseHasPeerInfobaseNode Then
	
			Try
				
				DataExchangeServer.DeleteSynchronizationSetting(NodeRef1);
				
			Except
				
				Cancel = True;
				
				Information = ErrorInfo();
				Result.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
					
				WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
					
				PutToTempStorage(Result, ResultAddress);
				
			EndTry;
								
		EndIf;
				
	EndIf;
	
	If Cancel Then
		PutToTempStorage(Result, ResultAddress);
		Return;
	EndIf;
	
	// 1. Save the node and connection settings to the infobase.
	Try
		ConfigureDataExchange(ConnectionSettings);
	Except
		Cancel = True;
		Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
	
	If Cancel Then
		PutToTempStorage(Result, ResultAddress);
		Return;
	EndIf;
	
	// 2. Save connection settings for peer infobase.
	If Not ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
		If DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName) Then
			ExportConnectionSettingsForSubordinateDIBNode(ConnectionSettings);
		Else
			Result.XMLConnectionSettingsString = ConnectionSettingsInXML(ConnectionSettings);
		EndIf;
	EndIf;
	
	// 
	//    
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		Connection = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
		Result.ErrorMessage = Connection.DetailedErrorDetails;
		ExternalConnection           = Connection.Join;
		
		If ExternalConnection = Undefined Then
			Cancel = True;
		Else
			
			CorrespondentConnectionSettings = ExternalConnection.DataProcessors.DataExchangeCreationWizard.Create();
			
			CorrespondentConnectionSettings.WizardRunOption   = "ContinueDataExchangeSetup";
			CorrespondentConnectionSettings.ExchangeSetupOption = ConnectionSettings.ExchangeSetupOption;
			
			CorrespondentConnectionSettings.ExchangePlanName               = ConnectionSettings.CorrespondentExchangePlanName;
			CorrespondentConnectionSettings.CorrespondentExchangePlanName = ConnectionSettings.ExchangePlanName;
			CorrespondentConnectionSettings.ExchangeFormat                 = ConnectionSettings.ExchangeFormat;
			
			CorrespondentConnectionSettings.UsePrefixesForExchangeSettings =
				ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings;
			
			CorrespondentConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
				ConnectionSettings.UsePrefixesForExchangeSettings;
				
			CorrespondentConnectionSettings.SourceInfobasePrefix = ConnectionSettings.DestinationInfobasePrefix;
			CorrespondentConnectionSettings.DestinationInfobasePrefix = ConnectionSettings.SourceInfobasePrefix;
			
			Try
			
				ExternalConnection.DataProcessors.DataExchangeCreationWizard.FillConnectionSettingsFromXMLString(
					CorrespondentConnectionSettings, Result.XMLConnectionSettingsString);
					
			Except
				Cancel = True;
				Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
					EventLogLevel.Error, , , Result.ErrorMessage);
			EndTry;
				
			If Not Cancel Then
			
				If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
					CorrespondentConnectionSettings.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
					
					ObjectsTable1 = DataExchangeXDTOServer.SupportedObjectsInFormat(
						ConnectionSettings.ExchangePlanName, "SendReceive", ConnectionSettings.InfobaseNode);
					
					StorageString = XDTOSerializer.XMLString(
						New ValueStorage(ObjectsTable1, New Deflation(9)));
						
					CorrespondentConnectionSettings.SupportedObjectsInFormat = ExternalConnection.XDTOSerializer.XMLValue(
						ExternalConnection.NewObject("TypeDescription", "ValueStorage").Types().Get(0), StorageString);
				EndIf;
					
				Try
					
					ExternalConnection.DataExchangeServer.CheckDataExchangeUsage(True);
					
					ExternalConnection.DataProcessors.DataExchangeCreationWizard.ConfigureDataExchange(
						CorrespondentConnectionSettings);
				Except
					Cancel = True;
					Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
					
			EndIf;
				
		EndIf;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		AuthenticationSettingsStructure = AuthenticationSettingsStructure(ConnectionSettings);
		AdditionalParameters = New Structure("AuthenticationSettingsStructure", AuthenticationSettingsStructure);
	
		ErrorMessage = "";
		WSProxy = DataExchangeWebService.WSProxyForInfobaseNode(ConnectionSettings.InfobaseNode, 
			ErrorMessage, AdditionalParameters);
		
		If WSProxy = Undefined Then
			Cancel = True;
		Else
			CorrespondentConnectionSettings = New Structure;
			For Each SettingItem In ConnectionSettings Do
				CorrespondentConnectionSettings.Insert(SettingItem.Key);
			EndDo;
			
			CorrespondentConnectionSettings.WizardRunOption   = "ContinueDataExchangeSetup";
			CorrespondentConnectionSettings.ExchangeSetupOption = ConnectionSettings.ExchangeSetupOption;
			
			CorrespondentConnectionSettings.ExchangePlanName               = ConnectionSettings.CorrespondentExchangePlanName;
			CorrespondentConnectionSettings.CorrespondentExchangePlanName = ConnectionSettings.ExchangePlanName;
			CorrespondentConnectionSettings.ExchangeFormat                 = ConnectionSettings.ExchangeFormat;
			
			CorrespondentConnectionSettings.UsePrefixesForExchangeSettings =
				ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings;
			
			CorrespondentConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
				ConnectionSettings.UsePrefixesForExchangeSettings;
				
			CorrespondentConnectionSettings.SourceInfobasePrefix = ConnectionSettings.DestinationInfobasePrefix;
			CorrespondentConnectionSettings.DestinationInfobasePrefix = ConnectionSettings.SourceInfobasePrefix;
			
			If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
				CorrespondentConnectionSettings.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
				
				ObjectsTable1 = DataExchangeXDTOServer.SupportedObjectsInFormat(
						ConnectionSettings.ExchangePlanName, "SendReceive", ConnectionSettings.InfobaseNode);
				
				CorrespondentConnectionSettings.SupportedObjectsInFormat = New ValueStorage(ObjectsTable1, New Deflation(9));
			EndIf;
			
			If ValueIsFilled(ConnectionSettings.WSEndpoint) Then
				SetPrivilegedMode(True);
				CorrespondentConnectionSettings.WSCorrespondentEndpoint = 
					Common.ObjectAttributeValue(ConnectionSettings.WSEndpoint, "Code");
				SetPrivilegedMode(False);
				CorrespondentConnectionSettings.WSCorrespondentDataArea = ConnectionSettings.WSDataArea;
			EndIf;
			
			ConnectionParameters = New Structure;
			ConnectionParameters.Insert("ConnectionSettings", CorrespondentConnectionSettings);
			ConnectionParameters.Insert("XMLParametersString",  Result.XMLConnectionSettingsString);
			
			Try
				DataExchangeWebService.CreateExchangeNode(WSProxy, AdditionalParameters.CurrentVersion, 
					ConnectionParameters, ConnectionSettings.WSCorrespondentDataArea);
			Except
				Cancel = True;
				Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
					EventLogLevel.Error, , , Result.ErrorMessage);
			EndTry;
			
		EndIf;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			
			If ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
				// Getting an exchange message with XDTO settings.
				ExchangeParameters = DataExchangeServer.ExchangeParameters();
				ExchangeParameters.ExecuteImport1 = True;
				ExchangeParameters.ExecuteExport2 = False;
				ExchangeParameters.ExchangeMessagesTransportKind = ConnectionSettings.ExchangeMessagesTransportKind;
				
				// 
				// 
				CancelReceipt = False;
				AdditionalParameters = New Structure;
				Try
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
						ConnectionSettings.InfobaseNode, ExchangeParameters, CancelReceipt, AdditionalParameters);
				Except
					// Возникновение исключения - 
					// 
					Cancel = True; 
					Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
				
				If AdditionalParameters.Property("DataReceivedForMapping") Then
					Result.HasDataToMap = AdditionalParameters.DataReceivedForMapping;
				EndIf;
			Else
				// 
				ExchangeParameters = DataExchangeServer.ExchangeParameters();
				ExchangeParameters.ExecuteImport1 = False;
				ExchangeParameters.ExecuteExport2 = True;
				ExchangeParameters.ExchangeMessagesTransportKind = ConnectionSettings.ExchangeMessagesTransportKind;
				
				Try
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
						ConnectionSettings.InfobaseNode, ExchangeParameters, Cancel);
				Except
					Cancel = True;
					Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
			EndIf;
			
		ElsIf Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName)
			And Not DataExchangeCached.IsStandardDataExchangeNode(ConnectionSettings.ExchangePlanName) Then
			
			ExchangeSettingsStructure = DataExchangeCached.TransportSettingsOfExchangePlanNode(
				ConnectionSettings.InfobaseNode, ConnectionSettings.ExchangeMessagesTransportKind);
				
			ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
			
			If ExchangeMessageTransportDataProcessor.ConnectionIsSet() Then
				
				Result.HasDataToMap = ExchangeMessageTransportDataProcessor.GetMessage(True);
				
				If Not Result.HasDataToMap Then
					// Probably the message can be received if you apply the virtual code (alias) of the node.
					Transliteration = Undefined;
					If ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
						ExchangeSettingsStructure.TransportSettings.Property("FILETransliterateExchangeMessageFileNames", Transliteration);
					ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
						ExchangeSettingsStructure.TransportSettings.Property("EMAILTransliterateExchangeMessageFileNames", Transliteration);
					ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
						ExchangeSettingsStructure.TransportSettings.Property("FTPTransliterateExchangeMessageFileNames", Transliteration);
					EndIf;
					Transliteration = ?(Transliteration = Undefined, False, Transliteration);
					
					FileNameTemplatePrevious = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNameTemplate;
					ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNameTemplate = DataExchangeServer.MessageFileNameTemplate(
						ExchangeSettingsStructure.CurrentExchangePlanNode,
						ExchangeSettingsStructure.InfobaseNode,
						False,
						Transliteration, 
						True);
						
					If FileNameTemplatePrevious <> ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNameTemplate Then
						Result.HasDataToMap = ExchangeMessageTransportDataProcessor.GetMessage(True);
					EndIf;
					
				EndIf;
				
			EndIf;
				
		EndIf;
		
	EndIf;
	
	If Not Cancel Then
		Result.ConnectionSettingsSaved = True;
		Result.ExchangeNode = ConnectionSettings.InfobaseNode;
	Else
		DataExchangeServer.DeleteSynchronizationSetting(ConnectionSettings.InfobaseNode);
		
		Result.ConnectionSettingsSaved = False;
		Result.ExchangeNode = Undefined;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure ImportXDTOCorrespondentSettings(Parameters, ResultAddress) Export
	
	ImportSettings = Undefined;
	Parameters.Property("ImportSettings", ImportSettings);
	
	Result = New Structure;
	Result.Insert("SettingsImported",             True);
	Result.Insert("DataReceivedForMapping", False);
	Result.Insert("ErrorMessage",              "");
	
	// Getting an exchange message with XDTO settings.
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport1 = True;
	ExchangeParameters.ExecuteExport2 = False;
	ExchangeParameters.ExchangeMessagesTransportKind =
		InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ImportSettings.ExchangeNode);
		
	AdditionalParameters = New Structure;
	
	Cancel = False;
	Try
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
			ImportSettings.ExchangeNode, ExchangeParameters, Cancel, AdditionalParameters);
	Except
		Cancel = True;
		Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
		
	If Cancel Then
		Result.SettingsImported = False; 
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("en = 'Cannot get peer application parameters.';");
		EndIf;
	Else
		CorrespondentSettings = DataExchangeXDTOServer.SupportedCorrespondentFormatObjects(
			ImportSettings.ExchangeNode, "SendReceive");
		Result.SettingsImported = (CorrespondentSettings.Count() > 0);
		
		If Result.SettingsImported Then
			If AdditionalParameters.Property("DataReceivedForMapping") Then
				Result.DataReceivedForMapping = AdditionalParameters.DataReceivedForMapping;
			EndIf;
		EndIf;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure SaveSynchronizationSettings1(Parameters, ResultAddress) Export
	
	SynchronizationSettings = Undefined;
	Parameters.Property("SynchronizationSettings", SynchronizationSettings);
	
	Result = New Structure;
	Result.Insert("SettingsSaved", True);
	Result.Insert("ErrorMessage",  "");
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(SynchronizationSettings.ExchangeNode);
	
	If DataExchangeServer.HasExchangePlanManagerAlgorithm("OnSaveDataSynchronizationSettings", ExchangePlanName) Then
		BeginTransaction();
		Try
			Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(SynchronizationSettings.ExchangeNode));
		    LockItem.SetValue("Ref", SynchronizationSettings.ExchangeNode);
		    Block.Lock();
			
			ObjectNode = SynchronizationSettings.ExchangeNode.GetObject(); // ExchangePlanObject
			ExchangePlans[ExchangePlanName].OnSaveDataSynchronizationSettings(ObjectNode,
				SynchronizationSettings.FillingData);
			ObjectNode.Write();
			
			If Not DataExchangeServer.SynchronizationSetupCompleted(SynchronizationSettings.ExchangeNode) Then
				DataExchangeServer.CompleteDataSynchronizationSetup(SynchronizationSettings.ExchangeNode);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			Result.SettingsSaved = False;
			Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessage);
		EndTry;
	Else
		If Not DataExchangeServer.SynchronizationSetupCompleted(SynchronizationSettings.ExchangeNode) Then
			DataExchangeServer.CompleteDataSynchronizationSetup(SynchronizationSettings.ExchangeNode);
		EndIf;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure ConfigureDataExchange(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating/updating the exchange plan node.
		CreateUpdateExchangePlanNodes(ConnectionSettings);
		
		// Loading message transport settings.
		If ValueIsFilled(ConnectionSettings.ExchangeMessagesTransportKind) Then
			// For online exchange when setting from the box the transport kind will not be filled in and is not required.
			UpdateDataExchangeTransportSettings(ConnectionSettings);
		EndIf;
		
		// Updating the infobase prefix constant value.
		If IsBlankString(GetFunctionalOption("InfobasePrefix"))
			And Not IsBlankString(ConnectionSettings.SourceInfobasePrefix) Then
			
			DataExchangeServer.SetInfobasePrefix(ConnectionSettings.SourceInfobasePrefix);
			
		EndIf;
		
		If DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName)
			And ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
			
			Constants.SubordinateDIBNodeSetupCompleted.Set(True);
			Constants.UseDataSynchronization.Set(True);
			Constants.NotUseSeparationByDataAreas.Set(True);
			
			DataExchangeServer.SetDefaultDataImportTransactionItemsCount();
			
			// 
			DataExchangeServer.UpdateDataExchangeRules();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteSynchronizationSetting(Parameters, ResultAddress) Export
	
	DeletionSettings = Undefined;
	Parameters.Property("DeletionSettings", DeletionSettings);
	
	Result = New Structure;
	Result.Insert("SettingDeleted",                 True);
	Result.Insert("SettingDeletedInCorrespondent",  DeletionSettings.DeleteSettingItemInCorrespondent);
	Result.Insert("ErrorMessage",                "");
	Result.Insert("ErrorMessageInCorrespondent", "");
	
	// 1. Optional: Delete the sync setting in the peer application.
	If DeletionSettings.DeleteSettingItemInCorrespondent Then
		DeleteSynchronizationSettingInCorrespondent(DeletionSettings, Result);
		If Not Result.SettingDeletedInCorrespondent Then
			Result.SettingDeleted = False;
			Result.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot delete the synchronization setting in %1: %2.
				|
				|Try to delete it later or clear the ""Also delete the setting in…"" check box.';"),
				String(DeletionSettings.ExchangeNode),
				Result.ErrorMessageInCorrespondent);
				
			PutToTempStorage(Result, ResultAddress);
			Return;
		EndIf;
	EndIf;
	
	// 2. Delete the sync setting in this application.
	Try
		DataExchangeServer.DeleteSynchronizationSetting(DeletionSettings.ExchangeNode);
	Except
		Information = ErrorInfo();
		Result.SettingDeleted  = False;
		Result.ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
		
		WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure DeleteSynchronizationSettingInCorrespondent(DeletionSettings, Result)
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(DeletionSettings.ExchangeNode);
	CorrespondentExchangePlanName =
		DataExchangeCached.GetNameOfCorrespondentExchangePlan(DeletionSettings.ExchangeNode);
		
	NodeID = DataExchangeServer.NodeIDForExchange(DeletionSettings.ExchangeNode);
		
	TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(
		DeletionSettings.ExchangeNode);
		
	If TransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(
			DeletionSettings.ExchangeNode, TransportKind);
		ConnectionResult = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
	
		ExternalConnection = ConnectionResult.Join;
		If ExternalConnection = Undefined Then
			Result.ErrorMessageInCorrespondent = ConnectionResult.DetailedErrorDetails;
			Result.SettingDeletedInCorrespondent = False;
			Return;
		EndIf;
		
		CorrespondentNode = ExternalConnection.DataExchangeServer.ExchangePlanNodeByCode(CorrespondentExchangePlanName,
			NodeID);
			
		If CorrespondentNode = Undefined Then
			Result.ErrorMessageInCorrespondent = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Exchange plan node ""%1"" is not found in the peer application by code ""%2"".';"),
				CorrespondentExchangePlanName, NodeID);
			Result.SettingDeletedInCorrespondent = False;
			Return;
		EndIf;
		
		Try
			ExternalConnection.DataExchangeServer.DeleteSynchronizationSetting(CorrespondentNode);
		Except
			Result.SettingDeletedInCorrespondent = False;
			Result.ErrorMessageInCorrespondent = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
		EndTry;
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(
			DeletionSettings.ExchangeNode);
			
		ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsForInfobaseNode(
			DeletionSettings.ExchangeNode, "NodeDeletion", Undefined, False);

		ExchangeSettingsStructure.EventLogMessageKey = DataExchangeServer.DataExchangeDeletionEventLogEvent();
		ExchangeSettingsStructure.ActionOnExchange = Undefined;
		
		ProxyParameters = New Structure;
		ProxyParameters.Insert("AuthenticationParameters", Undefined);
		ProxyParameters.Insert("MinVersion",       "3.0.1.1");
			
		WSProxy = Undefined;
		Cancel = False;
		SetupStatus = Undefined;
		ErrorMessage  = "";
		DataExchangeWebService.InitializeWSProxyToManageDataExchange(
			WSProxy, ExchangeSettingsStructure, ProxyParameters, Cancel, SetupStatus, ErrorMessage);
		
		If Cancel Then
			Result.ErrorMessageInCorrespondent = ErrorMessage;
			Result.SettingDeletedInCorrespondent  = False;
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
			Return;
		EndIf;
		
		Try
			DataExchangeWebService.DeleteExchangeNode(WSProxy, ProxyParameters.CurrentVersion, ExchangeSettingsStructure); 
		Except
			Result.SettingDeletedInCorrespondent = False;
			Result.ErrorMessageInCorrespondent = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
		EndTry;
			
	ElsIf TransportKind = Enums.ExchangeMessagesTransportTypes.ExternalSystem Then
		If Common.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
			
			Context = New Structure;
			Context.Insert("Peer", DeletionSettings.ExchangeNode);
			
			ModuleDataExchangeWithExternalSystems = Common.CommonModule("DataExchangeWithExternalSystems");
			
			Try
				ModuleDataExchangeWithExternalSystems.WhenDeletingSyncSetting(Context);
			Except
				Information = ErrorInfo();
				
				Result.SettingDeletedInCorrespondent  = False;
				Result.ErrorMessageInCorrespondent = ErrorProcessing.BriefErrorDescription(Information);
				
				WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
			EndTry;
			
		EndIf;
		
	Else
		Result.SettingDeletedInCorrespondent = False;
		Result.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Deletion of synchronization settings in the peer application is not supported for the ""%1"" connection type.';"),
			TransportKind);
	EndIf;
	
EndProcedure

Procedure RegisterDataForInitialExport(Parameters, ResultAddress) Export
	
	RegistrationSettings = Undefined;
	Parameters.Property("RegistrationSettings", RegistrationSettings);
	
	Result = New Structure;
	Result.Insert("DataRegistered", True);
	Result.Insert("ErrorMessage",      "");
	
	ReceivedNo = Common.ObjectAttributeValue(RegistrationSettings.ExchangeNode, "ReceivedNo");
	
	Try
		DataExchangeServer.RegisterDataForInitialExport(RegistrationSettings.ExchangeNode, , ReceivedNo = 0);
	Except
		Result.DataRegistered = False;
		Result.ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.RegisterDataForInitialExportEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Function NodeCode(ConnectionSettings)
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		Return ConnectionSettings.SourceInfobasePrefix;
			
	Else
		
		Return ConnectionSettings.SourceInfobaseID;
		
	EndIf;
	
EndFunction

Function CorrespondentNodeCode(ConnectionSettings)
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		Return ConnectionSettings.DestinationInfobasePrefix;
			
	Else
		
		Return ConnectionSettings.DestinationInfobaseID;
		
	EndIf;
	
EndFunction

Procedure CreateUpdateExchangePlanNodes(ConnectionSettings)
	
	ThisNodeCode  = NodeCode(ConnectionSettings);
	NewNodeCode = CorrespondentNodeCode(ConnectionSettings);
	RestoreExchangeSettings = TypeOf(ConnectionSettings) = Type("Structure") 
		And ConnectionSettings.Property("RestoreExchangeSettings")
		And StrFind(ConnectionSettings.RestoreExchangeSettings, "Restoration");
		
	ManagerExchangePlan = ExchangePlans[ConnectionSettings.ExchangePlanName]; // ExchangePlanManager
	
	// Refreshing predefined node code of this base if it is not filled in.
	ThisNode = ManagerExchangePlan.ThisNode();
	
	BeginTransaction();
	Try
	    Block = New DataLock;
	    LockItem = Block.Add("ExchangePlan." + ConnectionSettings.ExchangePlanName);
	    LockItem.SetValue("Ref", ThisNode);
	    Block.Lock();
		
		ThisNodeProperties = Common.ObjectAttributesValues(ThisNode, "Code, Description");
		ThisNodeCodeInDatabase          = ThisNodeProperties.Code;
		ThisNodeDescriptionInBase = ThisNodeProperties.Description;
		
		UpdateCode          = False;
		UpdateDescription = False;
		
		If IsBlankString(ThisNodeCodeInDatabase) Then
			UpdateCode          = True;
			UpdateDescription = True;
		ElsIf ThisNodeCodeInDatabase <> ThisNodeCode Then
			If Not Common.DataSeparationEnabled()
				And Not DataExchangeServer.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
				And (ConnectionSettings.UsePrefixesForExchangeSettings
					Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings)
				And DataExchangeServer.ExchangePlanNodes(ConnectionSettings.ExchangePlanName).Count() = 0 Then
				
				UpdateCode = True;
				
			EndIf;
		EndIf;
			
		If RestoreExchangeSettings Then
			UpdateCode = True;
		EndIf;
		
		If Not UpdateDescription
			And Not Common.DataSeparationEnabled()
			And ThisNodeDescriptionInBase <> ConnectionSettings.ThisInfobaseDescription Then
			UpdateDescription = True;
		EndIf;
		
		If UpdateCode Or UpdateDescription Then
			ThisNodeObject = ThisNode.GetObject();
			If UpdateCode Then
				ThisNodeObject.Code = ThisNodeCode;
				ThisNodeCodeInDatabase  = ThisNodeCode;
			EndIf;
			If UpdateDescription Then
				ThisNodeObject.Description = ConnectionSettings.ThisInfobaseDescription;
			EndIf;
			ThisNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
			ThisNodeObject.Write();
		EndIf;
	    
		CommitTransaction();
	Except
	    RollbackTransaction();
		Raise;
	EndTry;
	
	CreateNewNode = False;
	
	// Get the peer infobase's node.
	If DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName)
		And ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
		
		MasterNode = DataExchangeServer.MasterNode();
		
		If MasterNode = Undefined Then
			
			Raise NStr("en = 'The master node is not defined.
							|Probably this infobase is not a subordinate DIB node.';");
		EndIf;
		
		NewNode = MasterNode.GetObject();
		
		// 
		ThisNodeObject = ThisNode.GetObject();
		
		MetadataOfExchangePlan = NewNode.Metadata();
		SharedDataString = DataExchangeServer.ExchangePlanSettingValue(ConnectionSettings.ExchangePlanName,
			"CommonNodeData", ConnectionSettings.ExchangeSetupOption);
		
		SharedData = StrSplit(SharedDataString, ", ", False);
		For Each ItemCommonData In SharedData Do
			If MetadataOfExchangePlan.TabularSections.Find(ItemCommonData) = Undefined Then
				FillPropertyValues(NewNode, ThisNodeObject, ItemCommonData);
			Else
				NewNode[ItemCommonData].Load(ThisNodeObject[ItemCommonData].Unload());
			EndIf;
		EndDo;
	Else
		// Create or update a node.
		NewNodeRef = ManagerExchangePlan.FindByCode(NewNodeCode);
		
		CreateNewNode = NewNodeRef.IsEmpty();
		
		If CreateNewNode Then
			NewNode = ManagerExchangePlan.CreateNode();
			NewNode.Code = NewNodeCode;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 application prefix value is not unique (""%2""). A synchronization setting with the specified prefix already exists.
				|To continue, specify a unique infobase prefix different from the current one in %1.';"),
				ConnectionSettings.SecondInfobaseDescription, NewNodeCode);
		EndIf;
		
		NewNode.Description = ConnectionSettings.SecondInfobaseDescription;
		
		If Common.HasObjectAttribute("SettingsMode", Metadata.ExchangePlans[ConnectionSettings.ExchangePlanName]) Then
			NewNode.SettingsMode = ConnectionSettings.ExchangeSetupOption;
		EndIf;
		
		If CreateNewNode Then
			NewNode.Fill(Undefined);
		EndIf;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			If ValueIsFilled(ConnectionSettings.ExchangeFormatVersion) Then
				NewNode.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
			EndIf;
		EndIf;
		
	EndIf;
	
	// 
	NewNode.SentNo = 0;
	NewNode.ReceivedNo     = 0;
	
	If RestoreExchangeSettings Then
		NewNode.SentNo = ConnectionSettings.ReceivedNo;
		NewNode.ReceivedNo = ConnectionSettings.SentNo;
	EndIf;
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable()
		And DataExchangeServer.IsSeparatedSSLExchangePlan(ConnectionSettings.ExchangePlanName) Then
		
		NewNode.RegisterChanges = True;
		
	EndIf;
	
	If ValueIsFilled(ConnectionSettings.RefToNew) Then
		NewNode.SetNewObjectRef(ConnectionSettings.RefToNew);
	EndIf;
	
	NewNode.DataExchange.Load = True;
	NewNode.Write();
	
	If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
		If ConnectionSettings.SupportedObjectsInFormat <> Undefined Then
			InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(NewNode.Ref,
				"SupportedObjects", ConnectionSettings.SupportedObjectsInFormat.Get());
		EndIf;
		
		DataExchangeLoopControl.UpdateCircuit(ConnectionSettings.ExchangePlanName);

		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode",       NewNode.Ref);
		RecordStructure.Insert("CorrespondentExchangePlanName", ConnectionSettings.CorrespondentExchangePlanName);
		
		DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
	EndIf;
	
	ConnectionSettings.InfobaseNode = NewNode.Ref;
	
	// 
	InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
		ConnectionSettings.InfobaseNode,
		?(ConnectionSettings.UsePrefixesForExchangeSettings
			Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings, ConnectionSettings.SourceInfobasePrefix, ""),
		ConnectionSettings.DestinationInfobasePrefix);
		
	InformationRegisters.CommonInfobasesNodesSettings.SetNameOfCorrespondentExchangePlan(
		ConnectionSettings.InfobaseNode,
		ConnectionSettings.CorrespondentExchangePlanName);
			
	If CreateNewNode
		And Not Common.DataSeparationEnabled() Then
		DataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	
	If ThisNodeCode <> ThisNodeCodeInDatabase
		And DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
		And (ConnectionSettings.UsePrefixesForExchangeSettings
			Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings) Then
		// Node in the correspondent base needs recoding.
		StructureTemporaryCode = New Structure;
		StructureTemporaryCode.Insert("Peer", ConnectionSettings.InfobaseNode);
		StructureTemporaryCode.Insert("NodeCode",       ThisNodeCode);
		
		DataExchangeInternal.AddRecordToInformationRegister(StructureTemporaryCode, "PredefinedNodesAliases");
	EndIf;

EndProcedure

Procedure UpdateDataExchangeTransportSettings(ConnectionSettings)
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Peer",                           ConnectionSettings.InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", ConnectionSettings.ExchangeMessagesTransportKind);
	
	RecordStructure.Insert("COMOperatingSystemAuthentication");
	RecordStructure.Insert("COMInfobaseOperatingMode");
	RecordStructure.Insert("COM1CEnterpriseServerSideInfobaseName");
	RecordStructure.Insert("COMUserName");
	RecordStructure.Insert("COM1CEnterpriseServerName");
	RecordStructure.Insert("COMInfobaseDirectory");
	RecordStructure.Insert("COMUserPassword");
	
	RecordStructure.Insert("EMAILMaxMessageSize");
	RecordStructure.Insert("EMAILCompressOutgoingMessageFile");
	RecordStructure.Insert("EMAILAccount");
	RecordStructure.Insert("EMAILTransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("FILEDataExchangeDirectory");
	RecordStructure.Insert("FILECompressOutgoingMessageFile");
	RecordStructure.Insert("FILETransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("FTPCompressOutgoingMessageFile");
	RecordStructure.Insert("FTPConnectionMaxMessageSize");
	RecordStructure.Insert("FTPConnectionPassword");
	RecordStructure.Insert("FTPConnectionPassiveConnection");
	RecordStructure.Insert("FTPConnectionUser");
	RecordStructure.Insert("FTPConnectionPort");
	RecordStructure.Insert("FTPConnectionPath");
	RecordStructure.Insert("FTPTransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("WSWebServiceURL");
	RecordStructure.Insert("WSUserName");
	RecordStructure.Insert("WSPassword");
	RecordStructure.Insert("WSRememberPassword");

	RecordStructure.Insert("WSCorrespondentDataArea");
	RecordStructure.Insert("WSCorrespondentEndpoint");
			
	RecordStructure.Insert("WSUseLargeVolumeDataTransfer", True);
	
	RecordStructure.Insert("ArchivePasswordExchangeMessages");
	
	FillPropertyValues(RecordStructure, ConnectionSettings);
	
	InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Function AuthenticationSettingsStructure(ConnectionSettings)
	
	Result = New Structure("WSWebServiceURL,WSUserName,WSPassword");
	
	If ValueIsFilled(ConnectionSettings.WSCorrespondentEndpoint) Then
		
		SetPrivilegedMode(True);
		
		ModuleMessagesExchangeTransportSettings = Common.CommonModule("InformationRegisters.MessageExchangeTransportSettings");
		Settings = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(ConnectionSettings.WSCorrespondentEndpoint);
		
		SetPrivilegedMode(False);
		
		FillPropertyValues(Result, Settings);
		
	Else
		
		FillPropertyValues(Result, ConnectionSettings);
		
	EndIf;
	
	Return Result;
	
EndFunction

#Region SettingsInXMLFormat

Procedure FillConnectionSettingsFromConstant(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	StringForConnection = Constants.SubordinateDIBNodeSettings.Get();
	
	FillConnectionSettingsFromXMLString(ConnectionSettings, StringForConnection);
	
EndProcedure

Procedure FillConnectionSettingsFromXMLString(ConnectionSettings,
		FileNameXMLString, IsFile = False, IsOnlineConnection = False) Export
	
	SettingsStructure = Undefined;
	Try
		ReadConnectionSettingsFromXMLToStructure(SettingsStructure, FileNameXMLString, IsFile);
	Except
		Raise;
	EndTry;
	
	CorrectSettingsFile = False;
	ExchangePlanNameInSettings = "";
	
	If SettingsStructure.Property("ExchangePlanName", ExchangePlanNameInSettings)
		And SettingsStructure.ExchangePlanName = ConnectionSettings.ExchangePlanName Then
		
		CorrectSettingsFile = True;
		
	ElsIf DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then 
		
		FoundExchangePlan = DataExchangeServer.FindNameOfExchangePlanThroughUniversalFormat(SettingsStructure.ExchangePlanName);
		CorrectSettingsFile = ValueIsFilled(FoundExchangePlan)
		
	EndIf;
	
	If Not CorrectSettingsFile Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The file does not contain connection settings for the selected data exchange.
			|Exchange ""%1"" is selected,
			|while the file contains settings for exchange ""%2"".';"),
			ConnectionSettings.ExchangePlanName, ExchangePlanNameInSettings);
	EndIf;
	
	If Not ValueIsFilled(ConnectionSettings.CorrespondentExchangePlanName) Then
		ConnectionSettings.CorrespondentExchangePlanName = SettingsStructure.ExchangePlanName;
	EndIf;
	
	FillPropertyValues(ConnectionSettings, SettingsStructure, , "ExchangePlanName, SourceInfobasePrefix");
	
	If Not IsOnlineConnection
		Or Not ValueIsFilled(ConnectionSettings.UsePrefixesForExchangeSettings) Then
		EmptyRefOfExchangePlan = ExchangePlans[ConnectionSettings.ExchangePlanName].EmptyRef();
		
		ConnectionSettings.UsePrefixesForExchangeSettings = 
			Not DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
				Or Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(EmptyRefOfExchangePlan);
	EndIf;
	
	ExchangeMessagesTransportKind = "";
	If SettingsStructure.Property("ExchangeMessagesTransportKind", ExchangeMessagesTransportKind) 
		And TypeOf(ExchangeMessagesTransportKind) = Type("String") Then
		
		NameOfTypeOfTransport = DataExchangeFormatTranslationCached.BroadcastName(SettingsStructure.ExchangeMessagesTransportKind, "en");
		ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes[NameOfTypeOfTransport];
		
	EndIf;
	
	If Not IsOnlineConnection Then
		SecondInfobaseNewNodeCode = Undefined;		
		SettingsStructure.Property("SecondInfobaseNewNodeCode", SecondInfobaseNewNodeCode);
		
		ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
			ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings
				Or (ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup"
					And DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
					And ValueIsFilled(SecondInfobaseNewNodeCode)
					And StrLen(SecondInfobaseNewNodeCode) <> 36);
	EndIf;
			
	If Not ConnectionSettings.UsePrefixesForExchangeSettings
		And Not ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		SettingsStructure.Property("PredefinedNodeCode", ConnectionSettings.SourceInfobaseID);
		SettingsStructure.Property("SecondInfobaseNewNodeCode",  ConnectionSettings.DestinationInfobaseID);
		
	Else
		
		SettingsStructure.Property("SourceInfobasePrefix", ConnectionSettings.SourceInfobasePrefix);
		SettingsStructure.Property("SecondInfobaseNewNodeCode",            ConnectionSettings.DestinationInfobasePrefix);
		
	EndIf;
	
	If ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup"
		And (ConnectionSettings.UsePrefixesForExchangeSettings
			Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings) Then
		
		IBPrefix = GetFunctionalOption("InfobasePrefix");
		If Not IsBlankString(IBPrefix)
			And IBPrefix <> ConnectionSettings.SourceInfobasePrefix Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application prefix specified during setup (""%1"") does not match the prefix in this application (""%2"").
				|To continue, start the setup from another application and specify the correct prefix (""%2"").';"),
				ConnectionSettings.SourceInfobasePrefix, IBPrefix);
			
		EndIf;
		
	EndIf;
	
	EmailAccount = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations")
		And SettingsStructure.Property("EmailAccount", EmailAccount)
		And EmailAccount <> Undefined Then
		
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		ThisInfobaseAccount = ModuleEmailOperationsInternal.ThisInfobaseAccountByCorrespondentAccountData(
			EmailAccount);
		ConnectionSettings.EMAILAccount = ThisInfobaseAccount.Ref;
		
	EndIf;
	
	// Supporting the exchange settings file of the 1.0 version format.
	If ConnectionSettings.ExchangeDataSettingsFileFormatVersion = "1.0" Then
		
		ConnectionSettings.ThisInfobaseDescription    = NStr("en = 'This infobase';");
		SettingsStructure.Property("DataExchangeExecutionSettingsDescription", ConnectionSettings.SecondInfobaseDescription);
		SettingsStructure.Property("NewNodeCode", ConnectionSettings.SecondInfobaseNewNodeCode);
		
	EndIf;
		
EndProcedure

Function ConnectionSettingsInXML(ConnectionSettings, FileName = "", TypeOfTheCoding = "UTF-8") Export
	
	XMLWriter = New XMLWriter;
	
	If IsBlankString(FileName) Then
		XMLWriter.SetString(TypeOfTheCoding);
	Else
		XMLWriter.OpenFile(FileName, TypeOfTheCoding);
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		
		CorrespondentNode = ConnectionSettings.InfobaseNode;
		
		HeaderParameters = DataExchangeXDTOServer.ExchangeMessageHeaderParameters();
	
		HeaderParameters.ExchangeFormat            = ConnectionSettings.ExchangeFormat;
		HeaderParameters.IsExchangeViaExchangePlan = True;
		
	 	HeaderParameters.ExchangePlanName = ConnectionSettings.ExchangePlanName;
		HeaderParameters.PredefinedNodeAlias = DataExchangeServer.PredefinedNodeAlias(CorrespondentNode);
		
		HeaderParameters.RecipientIdentifier  = DataExchangeServer.CorrespondentNodeIDForExchange(CorrespondentNode);
		HeaderParameters.SenderID = DataExchangeServer.NodeIDForExchange(CorrespondentNode);
		
		FormatVersions = DataExchangeServer.ExchangePlanSettingValue(ConnectionSettings.ExchangePlanName, "ExchangeFormatVersions");
		For Each FormatVersion In FormatVersions Do
			HeaderParameters.SupportedVersions.Add(FormatVersion.Key);
		EndDo;
			
		HeaderParameters.SupportedObjects = DataExchangeXDTOServer.SupportedObjectsInFormat(
			ConnectionSettings.ExchangePlanName, "SendReceive", CorrespondentNode);
		
		HeaderParameters.Prefix = DataExchangeServer.InfobasePrefix();
		
		HeaderParameters.CorrespondentNode = CorrespondentNode;
	
		DataExchangeXDTOServer.WriteExchangeMessageHeader(XMLWriter, HeaderParameters);
		
	Else
		XMLWriter.WriteStartElement("SetupParameters");
		XMLWriter.WriteAttribute("FormatVersion", DataExchangeSettingsFormatVersion());
		
		XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
		XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
		XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
		
		WriteConnectionParameters(XMLWriter, ConnectionSettings);
		
		If ConnectionSettings.UseTransportParametersEMAIL Then
			WriteEmailAccount(XMLWriter, ConnectionSettings);
		EndIf;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			WriteXDTOExchangeParameters(XMLWriter, ConnectionSettings.ExchangePlanName);
		EndIf;
		
		XMLWriter.WriteEndElement(); // ПараметрыНастройки
	EndIf;
	
	Return XMLWriter.Close();
	
EndFunction

Procedure WriteConnectionParameters(XMLWriter, ConnectionSettings)
	
	XMLWriter.WriteStartElement("MainExchangeParameters");

	ExchangePlanName = DataExchangeFormatTranslationCached.BroadcastName(ConnectionSettings.ExchangePlanName, "ru");
	AddXMLRecord(XMLWriter, ExchangePlanName,                              "ИмяПланаОбмена"); // @Non-NLS
	
	AddXMLRecord(XMLWriter, ConnectionSettings.ThisInfobaseDescription,   "НаименованиеВторойБазы"); // @Non-NLS
	AddXMLRecord(XMLWriter, ConnectionSettings.SecondInfobaseDescription, "НаименованиеЭтойБазы"); // @Non-NLS
	
	AddXMLRecord(XMLWriter, NodeCode(ConnectionSettings), "КодНовогоУзлаВторойБазы"); // @Non-NLS
	AddXMLRecord(XMLWriter, ConnectionSettings.DestinationInfobasePrefix, "ПрефиксИнформационнойБазыИсточника"); // @Non-NLS
	
	// Exchange message transport settings.
	If ValueIsFilled(ConnectionSettings.ExchangeMessagesTransportKind)
		And ConnectionSettings.ExchangeMessagesTransportKind <> Enums.ExchangeMessagesTransportTypes.WS Then
		NameOfTypeOfTransport = EnumerationValueName(ConnectionSettings.ExchangeMessagesTransportKind);
		NameOfTypeOfTransport = DataExchangeFormatTranslationCached.BroadcastName(NameOfTypeOfTransport, "ru");
		AddXMLRecord(XMLWriter, NameOfTypeOfTransport, "ВидТранспортаСообщенийОбмена"); // @Non-NLS
	Else
		AddXMLRecord(XMLWriter, Undefined, "ВидТранспортаСообщенийОбмена"); // @Non-NLS
	EndIf;
	AddXMLRecord(XMLWriter, ConnectionSettings.ArchivePasswordExchangeMessages,  "ПарольАрхиваСообщенияОбмена"); // @Non-NLS
	
	If ConnectionSettings.UseTransportParametersEMAIL Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILMaxMessageSize, "EMAILМаксимальныйДопустимыйРазмерСообщения"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILCompressOutgoingMessageFile,        "EMAILСжиматьФайлИсходящегоСообщения"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILAccount,                         "EMAILУчетнаяЗапись"); // @Non-NLS
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersFILE Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.FILEDataExchangeDirectory,       "FILEКаталогОбменаИнформацией"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FILECompressOutgoingMessageFile, "FILEСжиматьФайлИсходящегоСообщения"); // @Non-NLS
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersFTP Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPCompressOutgoingMessageFile,                  "FTPСжиматьФайлИсходящегоСообщения"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionMaxMessageSize, "FTPСоединениеМаксимальныйДопустимыйРазмерСообщения"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPassword,                                "FTPСоединениеПароль"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPassiveConnection,                   "FTPСоединениеПассивноеСоединение"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionUser,                          "FTPСоединениеПользователь"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPort,                                  "FTPСоединениеПорт"); // @Non-NLS
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPath,                                  "FTPСоединениеПуть"); // @Non-NLS
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersCOM Then
		
		IBConnectionParameters = CommonClientServer.GetConnectionParametersFromInfobaseConnectionString(
			InfoBaseConnectionString());
		
		InfobaseOperatingMode             = IBConnectionParameters.InfobaseOperatingMode;
		NameOfInfobaseOn1CEnterpriseServer = IBConnectionParameters.NameOfInfobaseOn1CEnterpriseServer;
		NameOf1CEnterpriseServer                     = IBConnectionParameters.NameOf1CEnterpriseServer;
		InfobaseDirectory                   = IBConnectionParameters.InfobaseDirectory;
		
		IBUser   = InfoBaseUsers.CurrentUser();
		OSAuthentication = IBUser.OSAuthentication;
		UserName  = IBUser.Name;
		
		AddXMLRecord(XMLWriter, InfobaseOperatingMode,             "COMВариантРаботыИнформационнойБазы"); // @Non-NLS
		AddXMLRecord(XMLWriter, NameOfInfobaseOn1CEnterpriseServer, "COMИмяИнформационнойБазыНаСервере1СПредприятия"); // @Non-NLS
		AddXMLRecord(XMLWriter, NameOf1CEnterpriseServer,                     "COMИмяСервера1СПредприятия"); // @Non-NLS
		AddXMLRecord(XMLWriter, InfobaseDirectory,                   "COMКаталогИнформационнойБазы"); // @Non-NLS
		AddXMLRecord(XMLWriter, OSAuthentication,                            "COMАутентификацияОперационнойСистемы"); // @Non-NLS
		AddXMLRecord(XMLWriter, UserName,                             "COMUserName");
		
	EndIf;
	
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersEMAIL, "ИспользоватьПараметрыТранспортаEMAIL"); // @Non-NLS
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersFILE,  "ИспользоватьПараметрыТранспортаFILE"); // @Non-NLS
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersFTP,   "ИспользоватьПараметрыТранспортаFTP"); // @Non-NLS
	
	// Supporting the exchange settings file of the 1.0 version format.
	AddXMLRecord(XMLWriter, ConnectionSettings.ThisInfobaseDescription, "НаименованиеНастройкиВыполненияОбмена"); // @Non-NLS
	
	AddXMLRecord(XMLWriter, NodeCode(ConnectionSettings), "КодНовогоУзла"); // @Non-NLS
	
	IBNodeCode = Common.ObjectAttributeValue(ConnectionSettings.InfobaseNode, "Код"); // @Non-NLS
	
	AddXMLRecord(XMLWriter, IBNodeCode, "КодПредопределенногоУзла"); // @Non-NLS
	
	SentNo = ConnectionSettings.InfobaseNode.SentNo;
	If SentNo > 0 Then
		AddXMLRecord(XMLWriter, SentNo, "НомерОтправленного"); // @Non-NLS
	EndIf;
	
	ReceivedNo = ConnectionSettings.InfobaseNode.ReceivedNo;
	If ReceivedNo > 0 Then
		AddXMLRecord(XMLWriter, ReceivedNo, "НомерПринятого"); // @Non-NLS
	EndIf;
	
	XMLWriter.WriteEndElement(); // ОсновныеПараметрыОбмена
	
EndProcedure

Function EnumerationValueName(Value) Export

	MetadataObjectsList = Value.Metadata();
	
	EnumManager = Enums[MetadataObjectsList.Name];
	ValueIndex = EnumManager.IndexOf(Value);

	Return MetadataObjectsList.EnumValues.Get(ValueIndex).Name;

EndFunction

Procedure WriteEmailAccount(XMLWriter, ConnectionSettings)
	
	EMAILAccount = Undefined;
	If ValueIsFilled(ConnectionSettings.EMAILAccount) Then
		EMAILAccount = ConnectionSettings.EMAILAccount.GetObject();
	EndIf;
	
	XMLWriter.WriteStartElement("EmailAccount");
	WriteXML(XMLWriter, EMAILAccount);
	XMLWriter.WriteEndElement(); // УчетнаяЗаписьЭлектроннойПочты
	
EndProcedure

Procedure WriteXDTOExchangeParameters(XMLWriter, ExchangePlanName)
	
	XMLWriter.WriteStartElement("XDTOExchangeParameters");
	
	ExchangeFormat = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeFormat");
	
	WriteXML(XMLWriter, ExchangeFormat, "ExchangeFormat", XMLTypeAssignment.Explicit);
	
	XMLWriter.WriteEndElement(); // ПараметрыОбменаXDTO
	
EndProcedure

Procedure AddXMLRecord(XMLWriter, Value, FullName)
	
	WriteXML(XMLWriter, Value, FullName, XMLTypeAssignment.Explicit);
	
EndProcedure

Procedure ReadConnectionSettingsFromXMLToStructure(SettingsStructure, FileNameXMLString, IsFile)
	
	SettingsStructure = New Structure;
	
	XMLReader = New XMLReader;
	If IsFile Then
		XMLReader.OpenFile(FileNameXMLString);
	Else
		XMLReader.SetString(FileNameXMLString);
	EndIf;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement 
			And XMLReader.Name = "SetupParameters" Then
			
			FormatVersion = XMLReader.GetAttribute("FormatVersion");
			SettingsStructure.Insert("ExchangeDataSettingsFileFormatVersion",
				?(FormatVersion = Undefined, "1.0", FormatVersion));
			
		ElsIf XMLReader.NodeType = XMLNodeType.StartElement 
			And XMLReader.Name = "MainExchangeParameters" Then
			
			ReadDataToStructure(SettingsStructure, XMLReader);
			
		ElsIf XMLReader.NodeType = XMLNodeType.StartElement 
			And XMLReader.Name = "EmailAccount" Then
			
			If SettingsStructure.Property("UseTransportParametersEMAIL")
				And SettingsStructure.UseTransportParametersEMAIL Then
				
				If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
					
					// 
					XMLReader.Read(); // 
					
					ReadEmailData(SettingsStructure, XMLReader);
					
					XMLReader.Read(); // 
					
				Else
					
					XMLReader.Skip();
					
				EndIf;
				
			EndIf;
			
		ElsIf XMLReader.NodeType = XMLNodeType.StartElement 
			And XMLReader.Name = "XDTOExchangeParameters" Then
			
			ReadXDTOExchangeParameters(SettingsStructure, XMLReader);
			
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure ReadDataToStructure(SettingsStructure, XMLReader)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("en = 'XML file parsing error.';");
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
				
		NodeName = DataExchangeFormatTranslationCached.BroadcastName(XMLReader.Name, "en"); 
		
		Try
			SettingsStructure.Insert(NodeName, ReadXML(XMLReader));
		Except
			
			For Cnt = 0 To XMLReader.AttributeCount() Do
				XMLReader.Read();
			EndDo;
	
		EndTry;
		
	EndDo;
		
	XMLReader.Read();
	
EndProcedure

Procedure ReadEmailData(SettingsStructure, XMLReader)
	
	EmailAccountStructure = New Structure;
	
	StandardAttributes = New Structure;
	StandardAttributes.Insert("Description","Description");
	StandardAttributes.Insert("PredefinedDataName","PredefinedDataName");
	
	While True Do
		
		Var_Key = "";
		Value = "";
		
		While XMLReader.Read() Do
			
			If XMLReader.NodeType = XMLNodeType.StartElement Then
				
				Var_Key = XMLReader.Name;
				
				If StandardAttributes.Property(Var_Key) Then
					Var_Key = StandardAttributes[Var_Key];
				EndIf;
				
			ElsIf XMLReader.NodeType = XMLNodeType.Text Then
				
				Value = XMLReader.Value;
				
			ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
				
				Break;
				
			EndIf;
			
		EndDo;
		
		If XMLReader.Name = "CatalogObject.EmailAccounts" And XMLReader.NodeType = XMLNodeType.EndElement Then
			Break;
		EndIf;
					
		EmailAccountStructure.Insert(Var_Key, Value);
			
	EndDo;
	
	CatalogName = "EmailAccounts";
	Manager = Common.ObjectManagerByFullName("Catalog." + CatalogName);
	EmailAccount = Manager.CreateItem();
	EmailAccount.Description = EmailAccountStructure.Description;
	If EmailAccountStructure.Property("PredefinedDataName") Then
		EmailAccount.PredefinedDataName = EmailAccountStructure.PredefinedDataName;
	EndIf;
	
	For Each Attribute In Metadata.Catalogs[CatalogName].Attributes Do
		
		If Not EmailAccountStructure.Property(Attribute.Name) Then
			Continue;
		EndIf;
		
		EmailAccount[Attribute.Name] = EmailAccountStructure[Attribute.Name];
		
	EndDo;
		
	SettingsStructure.Insert("EmailAccount", EmailAccount);
	
EndProcedure

Procedure ReadXDTOExchangeParameters(SettingsStructure, XMLReader)
	
	XDTOExchangeParameters = New Structure;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		Var_Key = XMLReader.Name;
		XDTOExchangeParameters.Insert(Var_Key, ReadXML(XMLReader));
		
	EndDo;
	
	SettingsStructure.Insert("XDTOExchangeParameters", XDTOExchangeParameters);
	
EndProcedure

Function XDTOCorrespondentSettingsFromXML(FileNameXMLString, IsFile, ExchangeNode) Export
	
	XMLReader = New XMLReader;
	If IsFile Then
		XMLReader.OpenFile(FileNameXMLString);
	Else
		XMLReader.SetString(FileNameXMLString);
	EndIf;
	
	XMLReader.Read(); // Message
	XMLReader.Read(); // Header
	
	TitleXDTOMessages = XDTOFactory.ReadXML(XMLReader,
		XDTOFactory.Type("http://www.1c.ru/SSL/Exchange/Message", XMLReader.LocalName));
		
	SettingsStructure = DataExchangeXDTOServer.SettingsStructureXTDO();
	DataExchangeXDTOServer.FillCorrespondentXDTOSettingsStructure(SettingsStructure, TitleXDTOMessages, , ExchangeNode);
	
	// Checking if the sender UID corresponds to the format.
	UID = TitleXDTOMessages.Confirmation.From;
	Try
		UID = New UUID(UID);
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The sender ID %1 in the EnterpriseData settings file does not match the expected GUID format.';"),
			UID);
	EndTry;
	
	SettingsStructure.Insert("SenderID", TitleXDTOMessages.Confirmation.From);
		
	XMLReader.Close();
	
	Return SettingsStructure;
	
EndFunction

#EndRegion

#EndRegion

#EndIf