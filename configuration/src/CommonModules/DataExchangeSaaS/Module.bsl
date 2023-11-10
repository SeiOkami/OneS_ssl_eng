///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region SSLSubsystemsEventHandlers

// The "After determining recipients" handler.
// It is called when objects are registered in the exchange plan.
// Sets up a constant that shows whether data has been changed
// and sends a message about changes with the current data area number to the service manager.
//
// Parameters:
//   Data         - CatalogObject
//                  - DocumentObject - 
//   Recipients     - Array of ExchangePlanRef - exchange plan nodes.
//   ExchangePlanName - String - an exchange plan name, as it is set in Designer.
//
Procedure AfterDetermineRecipients(Data, Recipients, ExchangePlanName) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	If Common.DataSeparationEnabled() Then
		
		If Data.DataExchange.Load Then
			Return;
		EndIf;
		
		If Recipients.Count() > 0
			And DataExchangeSaaSCached.IsDataSynchronizationExchangePlan(ExchangePlanName)
			And Not Constants.DataChangesRecorded.Get() Then
			
			If ModuleSaaSOperations.SessionWithoutSeparators() Then
				
				SetDataChangeFlag();
			Else
				
				JobsFilter = New Structure;
				JobsFilter.Insert("MethodName", "DataExchangeSaaS.SetDataChangeFlag");
				JobsFilter.Insert("Key", "1");
				
				SetPrivilegedMode(True);
				TheTaskIsAlreadyRunning = BackgroundJobs.GetBackgroundJobs(JobsFilter).Count() > 0;
				If TheTaskIsAlreadyRunning Then
					
					Return;
					
				EndIf;
				
				Try
					BackgroundJobs.Execute("DataExchangeSaaS.SetDataChangeFlag",, "1");
				Except
					WriteLogEvent(NStr("en = 'Data exchange';", Common.DefaultLanguageCode()),
						EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				EndTry;
			EndIf;
			
		EndIf;
		
	Else
		
		// 
		// 
		If StandaloneModeInternal.IsStandaloneWorkplace()
			And Not ModuleSaaSOperations.IsSeparatedMetadataObject(Data.Metadata(),
				ModuleSaaSOperations.MainDataSeparator()) Then
			
			CommonClientServer.DeleteValueFromArray(Recipients, StandaloneModeInternal.ApplicationInSaaS());
		EndIf;
		
	EndIf;
	
EndProcedure

// Fills mapping of method names and their aliases for calling from a job queue.
//
// Parameters:
//   NamesAndAliasesMap - Map of KeyAndValue - method names and their aliases:
//     Key - Method alias, for example: ClearDataArea
//     Value - a name of the method to be called, for example, SaaS.ClearDataArea
//                You can specify Undefined as a value, in this case, the name is assumed 
//                to be the same as an alias.
//
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	NamesAndAliasesMap.Insert("DataExchangeSaaS.SetDataChangeFlag"); 
	NamesAndAliasesMap.Insert("DataExchangeSaaS.ExecuteDataExchange");
	NamesAndAliasesMap.Insert("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInFirstInfobase");
	NamesAndAliasesMap.Insert("DataExchangeSaaS.ExecuteDataExchangeScenarioActionInSecondInfobase");
	NamesAndAliasesMap.Insert("DataExchangeInternalPublication.RunDataExchangeByScenario");
	NamesAndAliasesMap.Insert("DataExchangeInternalPublication.RunTaskQueue");
	NamesAndAliasesMap.Insert("DataExchangeInternalPublication.ExportToFileTransferServiceForInfobaseNode");
	NamesAndAliasesMap.Insert("DataExchangeInternalPublication.ImportFromFileTransferServiceForInfobaseNode");

EndProcedure

// Generates the list of infobase parameters.
//
// Parameters:
//   ParametersTable - ValueTable - a table describing parameters. For column content details, 
//                                         See SaaSOperations.ПолучитьТаблицуПараметровИБ().
//
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInformationSecurityParameterTable(ParametersTable, "AccountPasswordRecoveryAddress");
	EndIf;
	
EndProcedure

// Fills in a structure with arrays of supported versions of the subsystems that can have versions.
// Subsystem names are used as structure keys.
// Implements the InterfaceVersion web service functionality.
// This procedure must return current version sets, therefore its body must be changed accordingly before use. See the example below. 
//
// Parameters:
//   SupportedVersionsStructure - Structure - subsystem names and their corresponding sets of supported versions.
//	                                 The structure key is the name of the subsystem,
//                                   and the value is an array of supported version names.
//
// Example:
//	 // FilesTransferService
//	 VersionsArray = New Array;
//	 VersionsArray.Add("1.0.1.1");	
//	 VersionsArray.Add("1.0.2.1"); 
//	 SupportedVersionsStructure.Insert("FilesTransferService", VersionsArray);
//	 // End FilesTransferService
//
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionsStructure) Export
	
	VersionsArray = New Array;
	VersionsArray.Add("2.0.1.6");
	VersionsArray.Add("2.1.1.7");
	VersionsArray.Add("2.1.2.1");
	VersionsArray.Add("2.1.5.17");
	VersionsArray.Add("2.1.6.1");
	VersionsArray.Add("2.4.5.1");
	SupportedVersionsStructure.Insert("DataExchangeSaaS", VersionsArray);
	
	VersionsArray = New Array();
	VersionsArray.Add("1.0.0.1");
	SupportedVersionsStructure.Insert("UpdatingRulesForRegisteringObjectsInServiceModel", VersionsArray);
	
EndProcedure

// Gets a list of message handlers that are processed by the library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - See the field list in MessageExchange.NewMessagesHandlersTable. 
// 
Procedure OnDefineMessagesChannelsHandlers(Handlers) Export
	
	DataExchangeMessagesMessageHandler.GetMessagesChannelsHandlers(Handlers);
	
EndProcedure

// Adds parameters of client logic upon system startup for the data exchange subsystem in SaaS mode.
//
// Parameters:
//   Parameters - Structure - names and values of the client startup parameters that should be set.
//                           For more information, See CommonOverridable.OnAddClientParametersOnStart.
//
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	SetPrivilegedMode(True);
	
	Parameters.Insert("IsStandaloneWorkplace",
		StandaloneModeInternal.IsStandaloneWorkplace());
	Parameters.Insert("SynchronizeDataWithWebApplicationOnStart",
		StandaloneModeInternal.SynchronizeDataWithWebApplicationOnStart());
	Parameters.Insert("SynchronizeDataWithWebApplicationOnExit",
		StandaloneModeInternal.SynchronizeDataWithWebApplicationOnExit());
	Parameters.Insert("StandaloneModeParameters", StandaloneModeParametersOnExit());
	
EndProcedure

// Fills parameter structures required by the
// application client code.
//
// Parameters:
//   Parameters   - Structure - a parameter structure.
//
Procedure OnAddClientParameters(Parameters) Export
	
	AddClientRunParameters(Parameters);
	
EndProcedure

// Fills in an array of types excluded from data import and export.
//
// Parameters:
//   Types - Array of MetadataObject - metadata objects excluded from export and import.
//
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Constants.DataForDeferredUpdate);
	Types.Add(Metadata.Constants.ORMCachedValuesRefreshDate);
	Types.Add(Metadata.Constants.DataChangesRecorded);
	Types.Add(Metadata.Constants.SubordinateDIBNodeSettings);
	Types.Add(Metadata.Constants.LastStandaloneWorkstationPrefix);
	
	ModuleExportImportData = Common.CommonModule("ExportImportData");
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.DataExchangeScenarios, ModuleExportImportData.ActionWithLinksDoNotUnloadObject());
		
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.DataExchangesSessions, ModuleExportImportData.ActionWithLinksDoNotUnloadObject());	
		
	ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
	CTLVersion = ModuleSaaSTechnology.LibraryVersion();
	
	Types.Add(Metadata.InformationRegisters.CommonInfobasesNodesSettings);
	Types.Add(Metadata.InformationRegisters.DataExchangeTransportSettings);
	Types.Add(Metadata.InformationRegisters.DataAreaExchangeTransportSettings);
	Types.Add(Metadata.InformationRegisters.DataAreasDataExchangeMessages);
	Types.Add(Metadata.InformationRegisters.DeleteDataExchangeResults);
	Types.Add(Metadata.InformationRegisters.DataAreaDataExchangeStates);
	Types.Add(Metadata.InformationRegisters.DataAreasSuccessfulDataExchangeStates);
		
	If CommonClientServer.CompareVersions(CTLVersion, "2.0.9.0") < 0 Then
		
		Types.Add(Metadata.InformationRegisters.ArchiveOfExchangeMessages);
		Types.Add(Metadata.InformationRegisters.ObjectsDataToRegisterInExchanges);
		Types.Add(Metadata.InformationRegisters.DataExchangeTasksInternalPublication);
		Types.Add(Metadata.InformationRegisters.CommonNodeDataChanges);
		Types.Add(Metadata.InformationRegisters.SynchronizationCircuit);
		Types.Add(Metadata.InformationRegisters.ExchangeMessageArchiveSettings);
		Types.Add(Metadata.InformationRegisters.XDTODataExchangeSettings);
		Types.Add(Metadata.InformationRegisters.DataSyncEventHandlers);
		Types.Add(Metadata.InformationRegisters.ObjectsUnregisteredDuringLoop);
		Types.Add(Metadata.InformationRegisters.PredefinedNodesAliases);
		Types.Add(Metadata.InformationRegisters.SynchronizedObjectPublicIDs);
		Types.Add(Metadata.InformationRegisters.DataExchangeResults);
		Types.Add(Metadata.InformationRegisters.SystemMessageExchangeSessions);
		Types.Add(Metadata.InformationRegisters.InfobaseObjectsMaps);

	EndIf;
	
EndProcedure

// Deletes exchange message files that are not deleted due to system failures.
// Files placed more than 24 hours ago are deleted (the files are calculated based on the universal current date)
// Analyzing РC.DataAreasDataExchangeMessages.
//
Procedure OnDeleteObsoleteExchangeMessages() Export
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageID AS MessageID,
	|	DataExchangeMessages.MessageFileName AS FileName,
	|	DataExchangeMessages.DataAreaAuxiliaryData AS DataAreaAuxiliaryData,
	|	DataExchangeMessages.MessageStoredDate AS MessageStoredDate
	|FROM
	|	InformationRegister.DataAreasDataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageStoredDate < &UpdateDate
	|
	|ORDER BY
	|	DataAreaAuxiliaryData";
	
	UniversalDate = CurrentUniversalDate();
	
	Query = New Query;
	Query.SetParameter("UpdateDate", UniversalDate - 60 * 60 * 24);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	SessionParameters.DataAreaUsage = True;
	DataAreaAuxiliaryData = Undefined;
	
	While Selection.Next() Do
		
		If DataAreaAuxiliaryData <> Selection.DataAreaAuxiliaryData Then
			
			DataAreaAuxiliaryData = Selection.DataAreaAuxiliaryData;
			SessionParameters.DataAreaValue = DataAreaAuxiliaryData;
			
		EndIf;
		
		CommonSettingsNode = Undefined;
		
		CommonSettingsQuery = New Query(
		"SELECT
		|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
		|WHERE
		|	CommonInfobasesNodesSettings.MessageForDataMapping = &MessageForDataMapping");
		CommonSettingsQuery.SetParameter("MessageForDataMapping", Selection.MessageID);
		
		CommonSettingsSelection = CommonSettingsQuery.Execute().Select();
		If CommonSettingsSelection.Next() Then
			If Not (Selection.MessageStoredDate < UniversalDate - 60 * 60 * 24 * 7) Then
				Continue;
			EndIf;
			
			CommonSettingsNode = CommonSettingsSelection.InfobaseNode;
		EndIf;
		
		MessageFileFullName = CommonClientServer.GetFullFileName(DataExchangeServer.TempFilesStorageDirectory(), Selection.FileName);
		
		MessageFile = New File(MessageFileFullName);
		
		If MessageFile.Exists() Then
			
			Try
				DeleteFiles(MessageFile.FullName);
			Except
				WriteLogEvent(NStr("en = 'Data exchange';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				Continue;
			EndTry;
		EndIf;
		
		// Deleting information about an exchange message file from the storage
		RecordStructure = New Structure;
		RecordStructure.Insert("MessageID", String(Selection.MessageID));
		InformationRegisters.DataAreasDataExchangeMessages.DeleteRecord(RecordStructure);
		
		If Not CommonSettingsNode = Undefined Then
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode",          CommonSettingsNode);
			RecordStructure.Insert("MessageForDataMapping", "");
			
			DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobasesNodesSettings");
		EndIf;
		
	EndDo;
	
	SessionParameters.DataAreaUsage = False;
	
EndProcedure

// Gets a file from the storage by the file ID.
// If a file with the specified ID is not found, an exception is thrown.
// If the file is found, its name is returned, and the information about the file is deleted from the storage.
//
// Parameters:
//  FileID - UUID - an ID of the file being received.
//  FileName           - String - a file name from the storage.
//
Procedure OnReceiveFileFromStorage(Val FileID, FileName) Export
	
	QueryText =
	"SELECT
	|	DataExchangeMessages.MessageFileName AS FileName
	|FROM
	|	InformationRegister.DataAreasDataExchangeMessages AS DataExchangeMessages
	|WHERE
	|	DataExchangeMessages.MessageID = &MessageID";
	
	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		LongDesc = NStr("en = 'The file with ID %1 is not found.';");
		Raise StringFunctionsClientServer.SubstituteParametersToString(LongDesc, String(FileID));
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	
	// Deleting information about an exchange message file from the storage
	RecordStructure = New Structure;
	RecordStructure.Insert("MessageID", String(FileID));
	InformationRegisters.DataAreasDataExchangeMessages.DeleteRecord(RecordStructure);
	
EndProcedure

// Saving a file to the storage
//
// Parameters:
//   RecordStructure - Structure - names and values of the DataAreasDataExchangeMessages information register dimensions.
//
Procedure OnPutFileToStorage(Val RecordStructure) Export
	
	InformationRegisters.DataAreasDataExchangeMessages.AddRecord(RecordStructure);
	
EndProcedure

// Deleting a file from storage
//
// Parameters:
//   RecordStructure - Structure - names and values of the DataAreasDataExchangeMessages information register dimensions.
//
Procedure OnDeleteFileFromStorage(Val RecordStructure) Export
	
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "DataAreasDataExchangeMessages");
	
EndProcedure

// Register built-in data handlers.
//
// When a new shared data notification is received, call procedures NewDataAvailable from modules registered with GetSuppliedDataHandlers.
// XDTODataObject Descriptor passed to the procedure.
// If NewDataAvailable sets Import to True,
//
// the data is imported, and the descriptor and the data file path are passed to the
// ProcessNewData procedure. The file is automatically deleted once the procedure is executed.
// If a file is not specified in the service manager, the parameter value is Undefined.
// 
//
// Parameters:
//   Handlers - ValueTable - Table to add handlers to. Has the following columns:
//        * DataKind - String - code of the data kind processed by the handler.
//        * HandlerCode - String - string(20) - used for recovery after a data processing error.
//        * Handler - CommonModule - a module that contains the following procedures:
//            NewDataAvailable(Descriptor, Import) Export
//            ProcessNewData(Descriptor, PathToFile) Export
//            DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// Handler that clears the UseDataSynchronization constant.
//
// Parameters:
//  Cancel - Boolean - indicates that the synchronization disabling is canceled.
//                   If its value is True, the synchronization is not disabled.
//
Procedure OnDisableDataSynchronization(Cancel) Export
	
	Constants.UseOfflineModeSaaS.Set(False);
	Constants.UseDataSynchronizationSaaSWithLocalApplication.Set(False);
	Constants.UseDataSynchronizationSaaSWithWebApplication.Set(False);
	
EndProcedure

#EndRegion

// 
// 
//	
//	
//	
//	
// 
// Parameters:
//  Object - Arbitrary -
//  Cancel - Boolean -
//
Procedure BeforeWriteCommonData(Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	ReadOnly = False;
	StandaloneModeInternal.DefineDataChangeCapability(Object.Metadata(), ReadOnly);
	
	If ReadOnly Then
		ErrorString = NStr("en = 'Standalone workstations don''t support modification of imported shared data (%1).
		|Please contact the administrator.';");
		ErrorString = StringFunctionsClientServer.SubstituteParametersToString(ErrorString, String(Object));
		Raise ErrorString;
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.DataSynchronizationWithWebApplication;
	Setting.UseExternalResources      = True;
	Setting.AvailableSaaS          = False;
	Setting.AvailableAtStandaloneWorkstation = True;
	
EndProcedure

Procedure ChangeTheIndicationOfTheNeedForDataExchangeInTheServiceModel(ItIsNecessaryToPerformAnExchange, AdditionalParameters = Undefined) Export
	
	ItIsNecessaryToPerformAnExchange = (ItIsNecessaryToPerformAnExchange = True); // 
	
	IdleInterval = 180; // 
	AttemptsNumber = 65; // 
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		
		If AdditionalParameters.Property("IdleInterval") Then
			
			IdleInterval = AdditionalParameters.IdleInterval;
			
		EndIf;
		
		If AdditionalParameters.Property("AttemptsNumber") Then
			
			AttemptsNumber = AdditionalParameters.AttemptsNumber;
			
		EndIf;
		
	EndIf;
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("Constant.DataChangesRecorded");
	LockItem.Mode = DataLockMode.Exclusive;
	
	TheValueOfTheConstantHasBeenChanged = False;
	For AttemptToChange = 1 To AttemptsNumber Do
		
		BeginTransaction();
		Try
			
			DataLock.Lock();
			Constants.DataChangesRecorded.Set(ItIsNecessaryToPerformAnExchange);
			TheValueOfTheConstantHasBeenChanged = True;
			
			CommitTransaction();
			Break;
			
		Except
			
			RollbackTransaction();
			If Common.SubsystemExists("CloudTechnology") Then
				
				ModuleCommonCTL = Common.CommonModule("CommonCTL");
				ModuleCommonCTL.Pause(IdleInterval);
				
			EndIf;
			
		EndTry
		
	EndDo;
	
	If Not TheValueOfTheConstantHasBeenChanged Then
		
		ExceptionText = NStr("en = 'Cannot lock the ""Data changes recorded"" constant.
			|Try again later.';", Common.DefaultLanguageCode());
		
		WriteLogEvent(DataSyncronizationLogEvent(),
			EventLogLevel.Error, , , ExceptionText);
		Raise ExceptionText;
		
	EndIf;
	
EndProcedure

// Enables the flag that shows whether the data is changed and sends a message about the change with the number of the current area
// to the service manager.
//
Procedure SetDataChangeFlag() Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	ModuleSaaSOperationsCTLCached = Common.CommonModule("SaaSOperationsCTLCached");
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	ModuleMessagesExchange = Common.CommonModule("MessagesExchange");
	
	SetPrivilegedMode(True);
	
	DataArea = ModuleSaaSOperations.SessionSeparatorValue();
	
	BeginTransaction();
	Try
		ModuleMessagesExchange.SendMessage("DataExchange\ManagingApplication\DataChangeFlag",
						New Structure("NodeCode", DataExchangeServer.ExchangePlanNodeCodeString(DataArea)),
						ModuleSaaSOperationsCTLCached.ServiceManagerEndpoint());
		
		ChangeTheIndicationOfTheNeedForDataExchangeInTheServiceModel(True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Fills in the passed array with the common modules used as
//  incoming message interface handlers.
//
// Parameters:
//  HandlersArray - Array - an array of handlers.
//
Procedure RecordingIncomingMessageInterfaces(HandlersArray) Export
	
	HandlersArray.Add(MessagesDataExchangeAdministrationControlInterface);
	HandlersArray.Add(MessagesDataExchangeAdministrationManagementInterface);
	HandlersArray.Add(DataExchangeMessagesControlInterface);
	HandlersArray.Add(DataExchangeMessagesManagementInterface);
	
	If Common.SubsystemExists("CloudTechnology") Then
		ModuleMessagesDistributedCommandsExecutionInterface = Common.CommonModule(
			"MessagesDistributedCommandExecutionInterface");
		HandlersArray.Add(ModuleMessagesDistributedCommandsExecutionInterface);
	EndIf;
	
EndProcedure

// Fills in the passed array with the common modules used as
//  outgoing message interface handlers.
//
// Parameters:
//  HandlersArray - Array - an array of handlers.
//
Procedure RecordingOutgoingMessageInterfaces(HandlersArray) Export
	
	HandlersArray.Add(MessagesDataExchangeAdministrationControlInterface);
	HandlersArray.Add(MessagesDataExchangeAdministrationManagementInterface);
	HandlersArray.Add(DataExchangeMessagesControlInterface);
	HandlersArray.Add(DataExchangeMessagesManagementInterface);
	
	If Common.SubsystemExists("CloudTechnology") Then
		ModuleMessagesDistributedCommandsExecutionInterface = Common.CommonModule(
			"MessagesDistributedCommandExecutionInterface");
		HandlersArray.Add(ModuleMessagesDistributedCommandsExecutionInterface);
	EndIf;
	
EndProcedure

// Infobase update handler.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
		
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlerManagement = True;
	Handler.Version = "*";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "DataExchangeSaaS.FillSeparatedDataHandlers";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "DataExchangeSaaS.SetPredefinedNodeCodes";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "DataExchangeSaaS.LockEndpoints";
	
EndProcedure

// Fills in separated data handler that depends on shared data change.
//
// Parameters:
//   Parameters - Structure - a handler parameter structure:
//     * SeparatedHandlers - ValueTable
//                              - Undefined - see details
//       of the NewUpdateHandlersTable function of the InfobaseUpdate common module.
//       Undefined is passed upon direct call (without using the infobase version
//       update functionality).
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.ExecutionMode = "Seamless";
		Handler.Procedure = "DataExchangeSaaS.SetPredefinedNodeCodes";
	EndIf;
	
EndProcedure

// Determines and sets a code and a predefined node description
// for each exchange plan used in the SaaS mode.
// The code is generated based on a separator value.
// Description - generated based on the application caption or, if the caption is blank, 
// based on the current data area presentation from the InformationRegister.DataAreas register.
//
Procedure SetPredefinedNodeCodes() Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeSaaSCached.IsDataSynchronizationExchangePlan(ExchangePlan.Name) Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			BeginTransaction();
			Try
			    Block = New DataLock;
			    LockItem = Block.Add(Common.TableNameByRef(ThisNode));
			    LockItem.SetValue("Ref", ThisNode);
			    Block.Lock();
				
				If IsBlankString(Common.ObjectAttributeValue(ThisNode, "Code")) Then
				
					LockDataForEdit(ThisNode);
					ThisNodeObject = ThisNode.GetObject();
					
					ThisNodeObject.Code = ExchangePlanNodeCodeInService(ModuleSaaSOperations.SessionSeparatorValue());
					ThisNodeObject.Description = TrimAll(GeneratePredefinedNodeDescription());
					ThisNodeObject.DataExchange.Load = True;
					ThisNodeObject.Write();
					
				EndIf;

			    CommitTransaction();
			Except
			    RollbackTransaction();
			    Raise;
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Locks all endpoints except for the service manager endpoint.
//
Procedure LockEndpoints() Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	ModuleSaaSOperationsCTLCached = Common.CommonModule("SaaSOperationsCTLCached");
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("ExchangePlan.MessagesExchange");
		Block.Lock();
		
		Query = New Query(
		"SELECT
		|	MessagesExchange.Ref AS Ref
		|FROM
		|	ExchangePlan.MessagesExchange AS MessagesExchange
		|WHERE
		|	NOT MessagesExchange.ThisNode
		|	AND MessagesExchange.Ref <> &ServiceManagerEndpoint
		|	AND NOT MessagesExchange.Locked");
		Query.SetParameter("ServiceManagerEndpoint", ModuleSaaSOperationsCTLCached.ServiceManagerEndpoint());
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			Endpoint = Selection.Ref.GetObject(); // ExchangePlanObject.MessagesExchange
			Endpoint.Locked = True;
			Endpoint.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use
//
Procedure OnSendDataToSlave(DataElement, ItemSend, Val InitialImageCreating, Recipient) Export
	
	If Recipient = Undefined Then
		
		//
		
	ElsIf ItemSend = DataItemSend.Delete
		Or ItemSend = DataItemSend.Ignore Then
		
		// No overriding for a standard data processor.
		
	ElsIf InitialImageCreating
		And Common.DataSeparationEnabled()
		And StandaloneModeInternal.IsStandaloneWorkstationNode(Recipient.Ref) Then
		
		ItemMetadata = DataElement.Metadata();
		
		MetadataProperties1 = Recipient.AdditionalProperties.MetadataProperties1.Get(ItemMetadata);
		If MetadataProperties1 = Undefined Then
			MetadataProperties1 = NewPropertiesOfStandaloneWorkstationMetadata(ItemMetadata);
			Recipient.AdditionalProperties.MetadataProperties1[ItemMetadata] = MetadataProperties1;
		EndIf;
		
		If MetadataProperties1.IsSeparatedMetadataObject Then
		
			ItemSend = DataItemSend.Ignore;
			
			If MetadataProperties1.IsSeparatedMetadataObjectAuxiliaryData Then
				
				If MetadataProperties1.IsRecordSet Then
					
					FilterElement = DataElement.Filter.Find("DataAreaAuxiliaryData");
					If FilterElement <> Undefined Then
						FilterElement.Value = 0;
					EndIf;
					
					For Each Record In DataElement Do
						Record[MetadataProperties1.AuxiliaryDataSeparator] = 0;
					EndDo;
					
				Else
					DataElement[MetadataProperties1.AuxiliaryDataSeparator] = 0;
				EndIf;
				
			EndIf;
			
			StandaloneModeInternal.OpenRecordInitialImageData(Recipient);
			StandaloneModeInternal.WriteInitialImageDataElement(DataElement, MetadataProperties1, Recipient);
			StandaloneModeInternal.CloseInitialImageDataWrite(Recipient);
			
		EndIf;
		
	EndIf;
	
EndProcedure

//

// For internal use
//
Procedure OnSendDataToMaster(DataElement, ItemSend, Recipient) Export
	
	If ItemSend = DataItemSend.Ignore Then
		//
	ElsIf StandaloneModeInternal.IsStandaloneWorkplace() Then
		
		If TypeOf(DataElement) = Type("ObjectDeletion") Then
			
			MetadataObject = DataElement.Ref.Metadata();
			
		Else
			
			MetadataObject = DataElement.Metadata();
			
		EndIf;
		
		If Common.SubsystemExists("CloudTechnology") Then
			
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			
			If Not ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject,
					ModuleSaaSOperations.MainDataSeparator()) Then
				
				ItemSend = DataItemSend.Ignore;
				
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// For internal use
//
Procedure OnReceiveDataFromSlave(DataElement, ItemReceive, SendBack, Sender) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		//
	ElsIf Common.DataSeparationEnabled() Then
		
		If TypeOf(DataElement) = Type("ObjectDeletion") Then
			
			MetadataObject = DataElement.Ref.Metadata();
			
		Else
			
			MetadataObject = DataElement.Metadata();
			
		EndIf;
		
		If Common.SubsystemExists("CloudTechnology") Then
			
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			
			If Not ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject,
					ModuleSaaSOperations.MainDataSeparator()) Then
				
				ItemReceive = DataItemReceive.Ignore;
				
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

//

// Generates an application name in SaaS mode.
//
Function GeneratePredefinedNodeDescription() Export
	
	DefaultApplicationName = NStr("en = 'Web application';");
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return DefaultApplicationName;
	EndIf;
		
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	ApplicationName = ModuleSaaSOperations.GetAppName();
	
	Return ?(IsBlankString(ApplicationName), DefaultApplicationName, ApplicationName);
EndFunction

// Generates an exchange plan node code for the specified data area.
//
// Parameters:
//   AreaNumber - Number - a separator value. 
//
// Returns:
//   String -  
//
Function ExchangePlanNodeCodeInService(Val AreaNumber) Export
	
	If TypeOf(AreaNumber) <> Type("Number") Then
		Raise NStr("en = 'Invalid type in parameter number [1].';");
	EndIf;
	
	Result = "S0[AreaNumber]";
	
	Return StrReplace(Result, "[AreaNumber]", Format(AreaNumber, "ND=7; NLZ=; NG=0"));
	
EndFunction

Procedure GetDataExchangesStates(TempTablesManager) Export
	
	Query = New Query(
	"SELECT
	|	DataExchangesStates.InfobaseNode AS InfobaseNode,
	|	DataExchangesStates.StartDate AS StartDate,
	|	DataExchangesStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted)
	|				OR DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed2)
	|			THEN CASE
	|					WHEN ISNULL(IssuesCount.Count, 0) > 0
	|						THEN 2
	|					ELSE 0
	|				END
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesImport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
	|		LEFT JOIN IssuesCount AS IssuesCount
	|		ON DataExchangesStates.InfobaseNode = IssuesCount.InfobaseNode
	|			AND DataExchangesStates.ActionOnExchange = IssuesCount.ActionOnExchange
	|WHERE
	|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangesStates.InfobaseNode AS InfobaseNode,
	|	DataExchangesStates.StartDate AS StartDate,
	|	DataExchangesStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 2
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed2)
	|			THEN CASE
	|					WHEN ISNULL(IssuesCount.Count, 0) > 0
	|						THEN 2
	|					ELSE 0
	|				END
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesExport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
	|		LEFT JOIN IssuesCount AS IssuesCount
	|		ON DataExchangesStates.InfobaseNode = IssuesCount.InfobaseNode
	|			AND DataExchangesStates.ActionOnExchange = IssuesCount.ActionOnExchange
	|WHERE
	|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangesStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesImport
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
	|WHERE
	|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangesStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesExport
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
	|WHERE
	|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)");
	
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure GetMessagesToMapData(TempTablesManager) Export
	
	Query = New Query(
	"SELECT
	|	CommonInfobasesNodesSettings.InfobaseNode AS InfobaseNode,
	|	CASE
	|		WHEN COUNT(CommonInfobasesNodesSettings.MessageForDataMapping) > 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS MessageReceivedForDataMapping,
	|	MAX(DataExchangeMessages.MessageStoredDate) AS LastMessageStoragePlacementDate
	|INTO MessagesForDataMapping
	|FROM
	|	InformationRegister.CommonInfobasesNodesSettings AS CommonInfobasesNodesSettings
	|		INNER JOIN InformationRegister.DataAreasDataExchangeMessages AS DataExchangeMessages
	|		ON (DataExchangeMessages.MessageID = CommonInfobasesNodesSettings.MessageForDataMapping)
	|
	|GROUP BY
	|	CommonInfobasesNodesSettings.InfobaseNode");
	
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

Procedure AdaptTheTextOfTheRequestAboutTheResultsOfTheExchangeInTheService(QueryText) Export
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		QueryText = StrReplace(QueryText,	"InformationRegister.DataExchangesStates", 
													"InformationRegister.DataAreaDataExchangeStates");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions

// Exports data in exchange between data areas.
//
// Parameters:
//  Cancel         - Boolean - a cancellation flag. It is set to True if an error occurs during the data export
//  Peer - ExchangePlanRef - an exchange plan node, for which data is being exported.
// 
Procedure RunDataExport(Cancel, Val Peer) Export
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport1 = False;
	ExchangeParameters.ExecuteExport2 = True;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Peer,
		ExchangeParameters, Cancel);
		
EndProcedure

// Imports data in exchange between data areas.
//
// Parameters:
//  Cancel         - Boolean - a cancellation flag. It is selected if an error occurs during the data import.
//  Peer - ExchangePlanRef - an exchange plan node, for which data is imported.
// 
Procedure RunDataImport(Cancel, Val Peer, MessageForDataMapping = False) Export
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport1 = True;
	ExchangeParameters.ExecuteExport2 = False;
	
	AdditionalParameters = New Structure;
	If MessageForDataMapping Then
		AdditionalParameters.Insert("MessageForDataMapping");
	EndIf;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Peer,
		ExchangeParameters, Cancel, AdditionalParameters);
		
EndProcedure

// Initiates data exchange between two infobases.
//
// Parameters:
//   DataExchangeScenario - ValueTable
//
Procedure ExecuteDataExchange(DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	// Resetting a cumulative data change flag for exchange
	ChangeTheIndicationOfTheNeedForDataExchangeInTheServiceModel(False);
	
	If DataExchangeScenario.Count() > 0 Then
		
		// Run the scenario.
		ExecuteDataExchangeScenarioActionInFirstInfobase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

// Executing an exchange scenario action set in a value table row for the first infobase among the infobases exchanging data.
//
// Parameters:
//   ScenarioRowIndex - Number - a row index in the DataExchangeScenario table.
//   DataExchangeScenario - ValueTable
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex, DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	If ScenarioRowIndex > DataExchangeScenario.Count() - 1 Then
		FinishDataExchangeScenarioExecution(ScenarioRowIndex, DataExchangeScenario);
		Return;
	EndIf;
	
	ActionToBeExecutedDetailsEL = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Running synchronization scenario… Step %1/%2.';"), ScenarioRowIndex + 1, DataExchangeScenario.Count())
		+ Chars.LF + DataExchangeScenarioRowDetails(ScenarioRowIndex, DataExchangeScenario);
	WriteLogEvent(DataSyncronizationLogEvent(),
		EventLogLevel.Information, , , ActionToBeExecutedDetailsEL);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	ResultingStructure = New Structure;
	ResultingStructure.Insert("Cancel",          False);
	ResultingStructure.Insert("StartDate",     CurrentSessionDate());
	ResultingStructure.Insert("CompletedOn", '00010101');
	ResultingStructure.Insert("Information",     "");
	
	InfobaseNode = Undefined;
	
	If ScenarioRow.InfobaseNumber = 1 Then
		
		Try
			InfobaseNode = FindInfobaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.InfobaseNodeCode);
			
			If Not DataExchangeServer.SynchronizationSetupCompleted(InfobaseNode) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Data synchronization setup in ""%1"" is not completed.';"),
					InfobaseNode);
			ElsIf DataExchangeServer.MessageWithDataForMappingReceived(InfobaseNode) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'A message that requires manual mapping has been imported to ""%1"".';"),
					InfobaseNode);
			ElsIf ScenarioRow.CurrentAction = "DataImport" Then
				RunDataImport(ResultingStructure.Cancel, InfobaseNode);
			ElsIf ScenarioRow.CurrentAction = "DataExport" Then
				RunDataExport(ResultingStructure.Cancel, InfobaseNode);
			Else
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Unknown action (%1) is detected during data exchange between data areas.';"),
					ScenarioRow.CurrentAction);
			EndIf;
		Except
			ResultingStructure.Cancel = True;
			ResultingStructure.Information = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			ResultingStructure.CompletedOn = CurrentSessionDate();
			
			WriteLogEvent(DataSyncronizationLogEvent(),
				EventLogLevel.Error, , , ActionToBeExecutedDetailsEL + Chars.LF + ResultingStructure.Information);
				
			FillPropertyValues(ScenarioRow, ResultingStructure);
				
			ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
			Return;
		EndTry;
		
		ResultingStructure.CompletedOn = CurrentSessionDate();
		
		FillPropertyValues(ScenarioRow, ResultingStructure);
		
		ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
		
	ElsIf ScenarioRow.InfobaseNumber = 2 Then
		
		Try
			InfobaseNode = FindInfobaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.ThisNodeCode);
			
			WSProxyDetails = CorrespondentWSProxyDetails(InfobaseNode);
			
			If WSProxyDetails.WSProxy = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot get WS proxy details for ""%1"".';"),
					InfobaseNode);
			Else
				DataExchangeScenarioParameter = ?(WSProxyDetails.XDTOSerializationSupported,
					XDTOSerializer.WriteXDTO(DataExchangeScenario),
					ValueToStringInternal(DataExchangeScenario));
					
				WSProxyDetails.WSProxy.StartExchangeExecutionInSecondDataBase(ScenarioRowIndex, DataExchangeScenarioParameter);
			EndIf;
		Except
			ResultingStructure.Cancel = True;
			ResultingStructure.Information = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			ResultingStructure.CompletedOn = CurrentSessionDate();
			
			WriteLogEvent(DataSyncronizationLogEvent(),
				EventLogLevel.Error, , , ActionToBeExecutedDetailsEL + Chars.LF + ResultingStructure.Information);
				
			FillPropertyValues(ScenarioRow, ResultingStructure);
				
			ExecuteDataExchangeScenarioActionInFirstInfobase(ScenarioRowIndex + 1, DataExchangeScenario);
		EndTry;
		
	EndIf;
	
EndProcedure

// Executing an exchange scenario action set in a value table row for the second infobase among the infobases exchanging data.
//
// Parameters:
//   ScenarioRowIndex - Number - a row index in the DataExchangeScenario table.
//   DataExchangeScenario - ValueTable
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfobase(ScenarioRowIndex, DataExchangeScenario) Export
	
	ActionToBeExecutedDetailsEL = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Running synchronization scenario… Step %1/%2.';"), ScenarioRowIndex + 1, DataExchangeScenario.Count())
		+ Chars.LF + DataExchangeScenarioRowDetails(ScenarioRowIndex, DataExchangeScenario);
	WriteLogEvent(DataSyncronizationLogEvent(),
		EventLogLevel.Information, , , ActionToBeExecutedDetailsEL);
	
	SetPrivilegedMode(True);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	If ScenarioRow.ExecutionQueueNumber = 1 Then
		// Resetting a cumulative data change flag for exchange.
		ChangeTheIndicationOfTheNeedForDataExchangeInTheServiceModel(False);
	EndIf;
	
	ResultingStructure = New Structure;
	ResultingStructure.Insert("Cancel",          False);
	ResultingStructure.Insert("StartDate",     CurrentSessionDate());
	ResultingStructure.Insert("CompletedOn", '00010101');
	ResultingStructure.Insert("Information",     "");
	
	InfobaseNode = Undefined;
	Try
		InfobaseNode = FindInfobaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.InfobaseNodeCode);
	Except
		ResultingStructure.Cancel = True;
		ResultingStructure.Information = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataSyncronizationLogEvent(),
			EventLogLevel.Error, , , ActionToBeExecutedDetailsEL + Chars.LF + ResultingStructure.Information);
			
		FinishDataExchangeScenarioExecution(ScenarioRowIndex, DataExchangeScenario, ResultingStructure);
		Return;
	EndTry;
	
	Try
		If Not DataExchangeServer.SynchronizationSetupCompleted(InfobaseNode) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Data synchronization setup in ""%1"" is not completed.';"),
				InfobaseNode);
		ElsIf DataExchangeServer.MessageWithDataForMappingReceived(InfobaseNode) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'A message that requires manual mapping has been imported to ""%1"".';"),
				InfobaseNode);
		ElsIf ScenarioRow.CurrentAction = "DataImport" Then
			RunDataImport(ResultingStructure.Cancel, InfobaseNode);
		ElsIf ScenarioRow.CurrentAction = "DataExport" Then
			RunDataExport(ResultingStructure.Cancel, InfobaseNode);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Unknown action (%1) is detected during data exchange.';"),
				ScenarioRow.CurrentAction);
		EndIf;
	Except
		ResultingStructure.Cancel = True;
		ResultingStructure.Information = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataSyncronizationLogEvent(),
			EventLogLevel.Error, , , ActionToBeExecutedDetailsEL + Chars.LF + ResultingStructure.Information);
	EndTry;
	ResultingStructure.CompletedOn = CurrentSessionDate();
	
	FillPropertyValues(ScenarioRow, ResultingStructure);
	
	// End of scenario.
	If ScenarioRowIndex = DataExchangeScenario.Count() - 1 Then
		FinishDataExchangeScenarioExecution(ScenarioRowIndex, DataExchangeScenario, ResultingStructure);
		Return;
	EndIf;
	
	Try
		WSProxyDetails = CorrespondentWSProxyDetails(InfobaseNode);
		
		If WSProxyDetails.WSProxy = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot get WS proxy details for ""%1"".';"),
				InfobaseNode);
		Else
			DataExchangeScenarioParameter = ?(WSProxyDetails.XDTOSerializationSupported,
				XDTOSerializer.WriteXDTO(DataExchangeScenario),
				ValueToStringInternal(DataExchangeScenario));
			
			WSProxyDetails.WSProxy.StartExchangeExecutionInFirstDataBase(ScenarioRowIndex + 1, DataExchangeScenarioParameter);
		EndIf;
	Except
		ResultingStructure.Cancel = True;
		ResultingStructure.Information = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		ResultingStructure.CompletedOn = CurrentSessionDate();
		
		WriteLogEvent(DataSyncronizationLogEvent(),
			EventLogLevel.Error, , , ActionToBeExecutedDetailsEL + Chars.LF + ResultingStructure.Information);
			
		FillPropertyValues(ScenarioRow, ResultingStructure);
			
		FinishDataExchangeScenarioExecution(ScenarioRowIndex, DataExchangeScenario, ResultingStructure);
	EndTry;
	
EndProcedure

// Deletes an exchange node in the current infobase.
//
Procedure DeleteSynchronizationSetting(ExchangePlanName, CorrespondentNodeCode) Export
	
	Peer = FindInfobaseNode(ExchangePlanName, CorrespondentNodeCode);
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Processing the message that will delete synchronization between ""%1"" and ""%2"".';"),
		ExchangePlanName, CorrespondentNodeCode);
	
	WriteLogEvent(EventLogEventDataSynchronizationSetup(),
		EventLogLevel.Information, , , MessageText);
	
	TransportSettings = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettings(Peer);
	
	If TransportSettings <> Undefined Then
		
		If TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
			
			If Not IsBlankString(TransportSettings.FILECommonInformationExchangeDirectory)
				And Not IsBlankString(TransportSettings.RelativeInformationExchangeDirectory) Then
				
				AbsoluteDataExchangeDirectory = CommonClientServer.GetFullFileName(
					TransportSettings.FILECommonInformationExchangeDirectory,
					TransportSettings.RelativeInformationExchangeDirectory);
				
				AbsoluteDirectory = New File(AbsoluteDataExchangeDirectory);
				
				Try
					DeleteFiles(AbsoluteDirectory.FullName);
				Except
					WriteLogEvent(EventLogEventDataSynchronizationSetup(),
						EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				EndTry;
				
			EndIf;
			
		ElsIf TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
			
			Try
				
				FTPSettings = DataExchangeServer.FTPConnectionSetup();
				FTPSettings.Server               = TransportSettings.FTPServer;
				FTPSettings.Port                 = TransportSettings.FTPConnectionPort;
				FTPSettings.UserName      = TransportSettings.FTPConnectionUser;
				FTPSettings.UserPassword   = TransportSettings.FTPConnectionPassword;
				FTPSettings.PassiveConnection  = TransportSettings.FTPConnectionPassiveConnection;
				FTPSettings.SecureConnection = DataExchangeServer.SecureConnection(TransportSettings.FTPConnectionPath);
				
				FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
				
				If DataExchangeServer.FTPDirectoryExist(TransportSettings.FTPPath, TransportSettings.RelativeInformationExchangeDirectory, FTPConnection) Then
					FTPConnection.Delete(TransportSettings.FTPPath);
				EndIf;
				
			Except
				WriteLogEvent(EventLogEventDataSynchronizationSetup(),
					EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		EndIf;
		
	EndIf;
	
	DeleteExchangePlanNode(Peer);
	
EndProcedure

Procedure DeleteExchangePlanNode(Ref) Export
	
	If Ref = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Block = New DataLock;
	    LockItem = Block.Add(Common.TableNameByRef(Ref));
	    LockItem.SetValue("Ref", Ref);
	    Block.Lock();
		
		Object = Ref.GetObject();
		
		If Object <> Undefined Then
			Object.AdditionalProperties.Insert("DeleteSyncSetting");
			Object.Delete();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEventDataSynchronizationSetup(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Function ExchangeMessagesDirectoryName(Val Code1, Val Code2)
	
	Return StringFunctionsClientServer.SubstituteParametersToString("Exchange %1-%2", Code1, Code2);
	
EndFunction

// Registers built-in data handlers.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers)
	
	Handler = Handlers.Add();
	Handler.DataKind = SuppliedDataKindID();
	Handler.HandlerCode = SuppliedDataKindID();
	Handler.Handler = DataExchangeSaaS;
	
	Handler = Handlers.Add();
	Handler.DataKind = IdOfTypeOfDataSuppliedRegistrationRules();
	Handler.HandlerCode = IdOfTypeOfDataSuppliedRegistrationRules();
	Handler.Handler = DataExchangeSaaS;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. 
// If it requires, select the Import check box.
// 
// Parameters:
//   Descriptor   - 
//   ToImport    - Boolean - a return value.
//
Procedure NewDataAvailable(Val Descriptor, ToImport) Export
	
	If Descriptor.DataType = SuppliedDataKindID()
		Or Descriptor.DataType = IdOfTypeOfDataSuppliedRegistrationRules() Then
		
		SuppliedRulesDetails = ParseSuppliedDataDescriptor(Descriptor);
		
		If SuppliedRulesDetails.ConfigurationName = Metadata.Name
			And SuppliedRulesDetails.ConfigurationVersion = Metadata.Version
			And Metadata.ExchangePlans.Find(SuppliedRulesDetails.ExchangePlanName) <> Undefined
			And DataExchangeCached.ExchangePlanUsedInSaaS(SuppliedRulesDetails.ExchangePlanName)
			And DataExchangeServer.IsSeparatedSSLExchangePlan(SuppliedRulesDetails.ExchangePlanName) Then // Rules are compatible with the infobase
			
			ToImport = True;
			
		Else
			
			ToImport = False;
			
			MessageText = NStr("en = 'The built-in exchange rules are not intended for the current configuration. They are intended for exchange plan %1 of configuration %2 v.%3';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
				SuppliedRulesDetails.ExchangePlanName, SuppliedRulesDetails.ConfigurationName, SuppliedRulesDetails.ConfigurationVersion);
			
			WriteLogEvent(NStr("en = 'Built-in data exchange rules.Import of built-in rules is canceled';",
				Common.DefaultLanguageCode()), EventLogLevel.Information,,, MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor   - 
//   PathToFile   - String, Undefined - Full name of the extracted file. 
//                  The file is automatically deleted once the procedure is completed.
//                  If a file is not specified, it is set to Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = SuppliedDataKindID()
		Or Descriptor.DataType = IdOfTypeOfDataSuppliedRegistrationRules() Then
		
		ProcessSuppliedExchangeRules(Descriptor, PathToFile, Descriptor.DataType);
		
	EndIf;
	
EndProcedure

// Runs if data processing is failed due to an error.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
EndProcedure

// Returns the ID of a built-in data kind for data exchange rules.
//
// Returns:
//   String
//
Function SuppliedDataKindID()
	
	Return "ER"; // Not localizable.
	
EndFunction

// Returns the ID of the supplied data type for data exchange rules
//
// Returns:
//   String
//
Function IdOfTypeOfDataSuppliedRegistrationRules()
	
	Return "RR"; // 
	
EndFunction

Function SuppliedRulesDetails()
	
	Return New Structure("ConfigurationName, ConfigurationVersion, ExchangePlanName, Use");
	
EndFunction

Function ParseSuppliedDataDescriptor(Descriptor)
	
	SuppliedRulesDetails = SuppliedRulesDetails();
	
	For Each SuppliedDataCharacteristic In Descriptor.Properties.Property Do
		
		SuppliedRulesDetails[SuppliedDataCharacteristic.Code] = SuppliedDataCharacteristic.Value;
		
	EndDo;
	
	Return SuppliedRulesDetails;
	
EndFunction

Procedure ProcessSuppliedExchangeRules(Descriptor, PathToFile, DataKind)
	
	SetPrivilegedMode(True);
	
	// Read the characteristics of a built-in data instance.
	SuppliedRulesDetails = ParseSuppliedDataDescriptor(Descriptor);
	ExchangePlanName = SuppliedRulesDetails.ExchangePlanName;
	
	If DataKind = IdOfTypeOfDataSuppliedRegistrationRules() Then
		
		If SuppliedRulesDetails.Use Then
			DataExchangeServer.DownloadSuppliedObjectRegistrationRules(ExchangePlanName, PathToFile);
		Else
			DataExchangeServer.DeleteSuppliedObjectRegistrationRules(ExchangePlanName);
		EndIf;
		
	Else
		
		If SuppliedRulesDetails.Use Then
			DataExchangeServer.ImportSuppliedRules(ExchangePlanName, PathToFile);
		Else
			DataExchangeServer.DeleteSuppliedRules(ExchangePlanName);
		EndIf;
		
	EndIf;
	
	DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
	RefreshReusableValues();
	
EndProcedure

// Returns:
//   ExchangePlanManager
// 
Function EndpointsExchangePlanManager() Export
	
	MetadataMessagesExchange = Metadata.FindByType(Metadata.DefinedTypes.MessagesQueueEndpoint.Type.Types()[0]).FullName();
	If MetadataMessagesExchange = Undefined Then
		Raise NStr("en = 'Endpoint exchange plan is not defined.';");
	EndIf;
	
	Return Common.ObjectManagerByFullName(MetadataMessagesExchange);
	
EndFunction

Procedure FinishDataExchangeScenarioExecution(ScenarioRowIndex, DataExchangeScenario, ResultingStructure = Undefined)
	
	WriteLogEvent(DataSyncronizationLogEvent(),
		EventLogLevel.Information, , , NStr("en = 'Finishing the synchronization scenario.';"));
		
	If Not ResultingStructure = Undefined Then
		ResultingStructure.CompletedOn = CurrentSessionDate();
		
		ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
		FillPropertyValues(ScenarioRow, ResultingStructure);
	EndIf;
	
	Try
		WSServiceProxy = DataExchangeSaaSCached.GetExchangeServiceWSProxy();
		WSServiceProxy.CommitExchange(XDTOSerializer.WriteXDTO(DataExchangeScenario));
	Except
		WriteLogEvent(DataSyncronizationLogEvent(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function DataExchangeScenarioRowDetails(ScenarioRowIndex, DataExchangeScenario)
	
	StringStructure = New Structure;
	StringStructure.Insert("ExecutionQueueNumber");
	StringStructure.Insert("InfobaseNumber");
	StringStructure.Insert("CurrentAction");
	StringStructure.Insert("Application1Code");
	StringStructure.Insert("Application2Code");
	StringStructure.Insert("Mode");
	
	FillPropertyValues(StringStructure, DataExchangeScenario[ScenarioRowIndex]);
	
	LongDesc = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'SequenceNumber: %1, Application: %2, Action: %3(%4), Mode: %5.';"),
		StringStructure.ExecutionQueueNumber,
		?(StringStructure.InfobaseNumber = 1, StringStructure.Application1Code, StringStructure.Application2Code),
		StringStructure.CurrentAction,
		?(StringStructure.InfobaseNumber = 1, StringStructure.Application2Code, StringStructure.Application1Code),
		StringStructure.Mode);
	
	Return LongDesc;
	
EndFunction

// Sends a message.
//
// Parameters:
//  Message - XDTODataObject - a message.
//
Function SendMessage(Val Message) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Raise NStr("en = 'There is no Service manager.';");
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	ModuleSaaSOperationsCTLCached = Common.CommonModule("SaaSOperationsCTLCached");
	
	Message.Body.Zone = ModuleSaaSOperations.SessionSeparatorValue();
	Message.Body.SessionId = InformationRegisters.SystemMessageExchangeSessions.NewSession();
	
	ModuleMessagesSaaS.SendMessage(Message,
		ModuleSaaSOperationsCTLCached.ServiceManagerEndpoint(),
		True);
	
	Return Message.Body.SessionId;
EndFunction

Function CorrespondentWSProxyDetails(Peer)
	
	LongDesc = New Structure;
	LongDesc.Insert("WSProxy",                       Undefined);
	LongDesc.Insert("XDTOSerializationSupported", True);
	
	CorrespondentVersions = CorrespondentVersions(Peer);
		
	If CorrespondentVersions.Find("2.4.5.1") <> Undefined Then
		
		LongDesc.WSProxy = DataExchangeSaaSCached.GetWSProxyOfCorrespondent_2_4_5_1(Peer);
		
	ElsIf CorrespondentVersions.Find("2.1.6.1") <> Undefined Then
		
		LongDesc.WSProxy = DataExchangeSaaSCached.GetWSProxyOfCorrespondent_2_1_6_1(Peer);
	
	ElsIf CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
		
		LongDesc.WSProxy = DataExchangeSaaSCached.GetWSProxyOfCorrespondent_2_0_1_6(Peer);
		
	Else
		
		LongDesc.WSProxy = DataExchangeSaaSCached.GetWSProxyOfCorrespondent(Peer);
		LongDesc.XDTOSerializationSupported = False;
		
	EndIf;
	
	Return LongDesc;
	
EndFunction

// For internal use
//
Procedure CreateExchangeSetting(ConnectionSettings,
			IsCorrespondent = False,
			SSL200CompatibilityMode = False,
			ThisNodeAlias = "") Export
			
	ThisNodeCode = Common.ObjectAttributeValue(ExchangePlans[ConnectionSettings.ExchangePlanName].ThisNode(), "Code");
	// Checking whether code is specified for the current node
	If IsBlankString(ThisNodeCode) Then
		// The node code is set in the infobase update handler
		MessageString = NStr("en = 'Code of the predefined exchange plan node %1 is not specified.';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ConnectionSettings.ExchangePlanName);
		Raise MessageString;
	EndIf;
	
	// Creating or updating a correspondent node
	Peer = ExchangePlans[ConnectionSettings.ExchangePlanName].FindByCode(ConnectionSettings.CorrespondentCode);
			
	BeginTransaction();
	Try
		If Not Peer.IsEmpty() Then
			Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(Peer));
		    LockItem.SetValue("Ref", Peer);
		    Block.Lock();
		EndIf;
		
		// Checking a prefix of the current infobase
		If IsBlankString(GetFunctionalOption("InfobasePrefix")) Then
			If IsBlankString(ConnectionSettings.Prefix) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'To continue data synchronization setup,
					|specify an infobase prefix in ""%1"".';"),
					Metadata.Synonym);
			EndIf;
				
			DataExchangeServer.SetInfobasePrefix(ConnectionSettings.Prefix);
		EndIf;
		
		CheckCode = False;
		
		If Peer.IsEmpty() Then
			CorrespondentObject = ExchangePlans[ConnectionSettings.ExchangePlanName].CreateNode();
			CorrespondentObject.Code = ConnectionSettings.CorrespondentCode;
			CheckCode = True;
		Else
			LockDataForEdit(Peer);
			CorrespondentObject = Peer.GetObject();
		EndIf;
		
		CorrespondentObject.Description = ConnectionSettings.CorrespondentDescription;
		
		DataExchangeEvents.SetNodeFilterValues(CorrespondentObject, ConnectionSettings.Settings);
		
		CorrespondentObject.SentNo = 0;
		CorrespondentObject.ReceivedNo     = 0;
		
		CorrespondentObject.RegisterChanges = True;
		
		CorrespondentObject.DataExchange.Load = True;
		CorrespondentObject.Write();
		
		If Not IsBlankString(ThisNodeAlias) Then
			RegisterManager = Common.CommonModule("InformationRegisters.PredefinedNodesAliases");
			VirtualCodes = RegisterManager.CreateRecordSet();
			VirtualCode = VirtualCodes.Add();
			VirtualCode.Peer = CorrespondentObject.Ref;
			VirtualCode.NodeCode       = ThisNodeAlias;
			
			VirtualCodes.Write();
		EndIf;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			
			DatabaseObjectsTable = DataExchangeXDTOServer.SupportedObjectsInFormat(ConnectionSettings.ExchangePlanName,
				"SendReceive", CorrespondentObject.Ref);
			CorrespondentObjectsTable = DatabaseObjectsTable.CopyColumns();
			
			For Each BaseObjectsRow In DatabaseObjectsTable Do
				CorrespondentObjectsRow = CorrespondentObjectsTable.Add();
				FillPropertyValues(CorrespondentObjectsRow, BaseObjectsRow, "Version, Object");
				CorrespondentObjectsRow.Send  = BaseObjectsRow.Receive;
				CorrespondentObjectsRow.Receive = BaseObjectsRow.Send;
			EndDo;
			
			XDTOSettingManager = Common.CommonModule("InformationRegisters.XDTODataExchangeSettings");
			XDTOSettingManager.UpdateSettings2(
				CorrespondentObject.Ref, "SupportedObjects", DatabaseObjectsTable);
			XDTOSettingManager.UpdateCorrespondentSettings(
				CorrespondentObject.Ref, "SupportedObjects", CorrespondentObjectsTable);
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode",       CorrespondentObject.Ref);
			RecordStructure.Insert("CorrespondentExchangePlanName", ConnectionSettings.ExchangePlanName);
			
			DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
		EndIf;
		
		// 
		InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
			CorrespondentObject.Ref,
			ConnectionSettings.Prefix);
			
		If Not DataExchangeServer.SynchronizationSetupCompleted(CorrespondentObject.Ref) Then
			DataExchangeServer.CompleteDataSynchronizationSetup(CorrespondentObject.Ref);
		EndIf;
		
		Peer = CorrespondentObject.Ref;
		
		ActualCorrespondentCode = Common.ObjectAttributeValue(Peer, "Code");
		
		If CheckCode And ConnectionSettings.CorrespondentCode <> ActualCorrespondentCode Then
			
			MessageString = NStr("en = 'Error assigning ID to a peer infobase node.
				|Assigned ID: %1.
				|Actual ID: %2.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
				ConnectionSettings.CorrespondentCode, ActualCorrespondentCode);
			Raise MessageString;
		EndIf;
		
		// Operations with transport settings.
		Parameters = New Structure;
		Parameters.Insert("Peer", Peer);
		Parameters.Insert("ThisNodeCode", ThisNodeCode);
		Parameters.Insert("CorrespondentCode", ConnectionSettings.CorrespondentCode);
		Parameters.Insert("CorrespondentEndpoint", ConnectionSettings.CorrespondentEndpoint);
		Parameters.Insert("IsCorrespondent", IsCorrespondent);
		Parameters.Insert("SSL200CompatibilityMode", SSL200CompatibilityMode);
		Parameters.Insert("ThisNodeAlias", ThisNodeAlias);
		
		UpdateDataAreaTransportSettings(Parameters);
		
		ConnectionSettings.Peer = Peer;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure CreateExchangeSetting_3_0_1_1(ConnectionSettings,
		IsCorrespondent = False,
		SSL200CompatibilityMode = False,
		ThisNodeAlias = "") Export
		
	ThisNodeCode = ConnectionSettings.SourceInfobaseID;
	
	// Checking whether code is specified for the current node.
	If IsBlankString(ThisNodeCode) Then
		// The node code is set in the infobase update handler.
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Code of the predefined exchange plan node %1 is not specified.';"),
			ConnectionSettings.ExchangePlanName);
	EndIf;
		
	SetPrefix = False;
	If IsBlankString(DataExchangeServer.InfobasePrefix()) Then
		If IsBlankString(ConnectionSettings.Prefix) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To continue data synchronization setup,
				|specify an infobase prefix in ""%1"".';"),
				Metadata.Synonym);
		EndIf;
		
		SetPrefix = True;
	Else
		ConnectionSettings.Prefix = DataExchangeServer.InfobasePrefix();
	EndIf;
	
	// Creating or updating a correspondent node.
	Peer = ExchangePlans[ConnectionSettings.ExchangePlanName].FindByCode(
		ConnectionSettings.DestinationInfobaseID);
	
	BeginTransaction();
	Try
		If Not Peer.IsEmpty() Then
			Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(Peer));
		    LockItem.SetValue("Ref", Peer);
		    Block.Lock();
		EndIf;
		
		If SetPrefix Then
			DataExchangeServer.SetInfobasePrefix(ConnectionSettings.Prefix);
		EndIf;
		
		CheckCode = False;
		If Peer.IsEmpty() Then
			CorrespondentObject = ExchangePlans[ConnectionSettings.ExchangePlanName].CreateNode();
			CorrespondentObject.Code = ConnectionSettings.DestinationInfobaseID;
			
			If Common.HasObjectAttribute("SettingsMode", CorrespondentObject.Metadata())
				And ConnectionSettings.Property("SettingID") Then
				CorrespondentObject.SettingsMode = ConnectionSettings.SettingID;
			EndIf;
			
			CheckCode = True;
		Else
			LockDataForEdit(Peer);
			CorrespondentObject = Peer.GetObject();
		EndIf;
		
		CorrespondentObject.Description = ConnectionSettings.CorrespondentDescription;
		
		If CheckCode Then
			CorrespondentObject.Fill(Undefined);
		EndIf;
		
		CorrespondentObject.SentNo = 0;
		CorrespondentObject.ReceivedNo     = 0;
		
		CorrespondentObject.RegisterChanges = True;
		
		// Exchange format version.
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
			And ConnectionSettings.Property("XDTOCorrespondentSettings") Then
			
			CorrespondentObject.ExchangeFormatVersion = DataExchangeXDTOServer.MaxCommonFormatVersion(
				ConnectionSettings.ExchangePlanName, ConnectionSettings.XDTOCorrespondentSettings.SupportedVersions);
				
		EndIf;
		
		CorrespondentObject.DataExchange.Load = True;
		CorrespondentObject.Write();
		
		Peer = CorrespondentObject.Ref;
		
		// XDTO correspondent settings.
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			
			If ConnectionSettings.Property("XDTOCorrespondentSettings") Then
				InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(Peer,
					"SupportedObjects",
					ConnectionSettings.XDTOCorrespondentSettings.SupportedObjects.Get());
			EndIf;
			
			InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(Peer,
				"CorrespondentDataArea",
				ConnectionSettings.CorrespondentDataArea);
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode",       Peer);
			RecordStructure.Insert("CorrespondentExchangePlanName", ConnectionSettings.ExchangePlanName);
			
			DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
			
		EndIf;
		
		// 
		InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
			Peer,
			ConnectionSettings.Prefix,
			ConnectionSettings.CorrespondentPrefix);
			
		If Not IsBlankString(ThisNodeAlias) Then
			RegisterManager = Common.CommonModule("InformationRegisters.PredefinedNodesAliases");
			VirtualCodes = RegisterManager.CreateRecordSet();
			VirtualCode = VirtualCodes.Add();
			VirtualCode.Peer = Peer;
			VirtualCode.NodeCode       = ThisNodeAlias;
			
			VirtualCodes.Write();
		EndIf;
		
		ActualCorrespondentCode = Common.ObjectAttributeValue(Peer, "Code");
		
		If CheckCode
			And ConnectionSettings.DestinationInfobaseID <> ActualCorrespondentCode Then
			MessageString = NStr("en = 'Error assigning ID to a peer infobase node.
				|Assigned ID: %1.
				|Actual ID: %2.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
				ConnectionSettings.DestinationInfobaseID,
				ActualCorrespondentCode);
			Raise MessageString;
		EndIf;
		
		// Operations with transport settings.
		Parameters = New Structure;
		Parameters.Insert("Peer", Peer);
		Parameters.Insert("ThisNodeCode", ThisNodeCode);
		Parameters.Insert("CorrespondentCode", ConnectionSettings.DestinationInfobaseID);
		Parameters.Insert("CorrespondentEndpoint", ConnectionSettings.CorrespondentEndpoint);
		Parameters.Insert("IsCorrespondent", IsCorrespondent);
		Parameters.Insert("SSL200CompatibilityMode", SSL200CompatibilityMode);
		Parameters.Insert("ThisNodeAlias", ThisNodeAlias);
		
		UpdateDataAreaTransportSettings(Parameters);
		
		ConnectionSettings.Peer = Peer;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateDataAreaTransportSettings(Parameters)
	
	Peer                = Parameters.Peer;
	ThisNodeCode                 = Parameters.ThisNodeCode;
	CorrespondentCode            = Parameters.CorrespondentCode;
	CorrespondentEndpoint  = Parameters.CorrespondentEndpoint;
	IsCorrespondent             = Parameters.IsCorrespondent;
	SSL200CompatibilityMode = Parameters.SSL200CompatibilityMode;
	ThisNodeAlias           = Parameters.ThisNodeAlias;
	
	If IsCorrespondent Then
		If Not IsBlankString(ThisNodeAlias) Then
			RelativeInformationExchangeDirectory = ExchangeMessagesDirectoryName(CorrespondentCode, ThisNodeAlias);
		Else
			RelativeInformationExchangeDirectory = ExchangeMessagesDirectoryName(CorrespondentCode, ThisNodeCode);
		EndIf;
	Else
		If Not IsBlankString(ThisNodeAlias) Then
			RelativeInformationExchangeDirectory = ExchangeMessagesDirectoryName(ThisNodeAlias, CorrespondentCode);
		Else
			RelativeInformationExchangeDirectory = ExchangeMessagesDirectoryName(ThisNodeCode, CorrespondentCode);
		EndIf;
	EndIf;
	
	TransportSettings = InformationRegisters.DataAreasExchangeTransportSettings.TransportSettings(CorrespondentEndpoint);
	
	If TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
		
		// Exchange using network directory
		
		FILECommonInformationExchangeDirectory = TrimAll(TransportSettings.FILEDataExchangeDirectory);
		
		If IsBlankString(FILECommonInformationExchangeDirectory) Then
			
			MessageString = NStr("en = 'The data exchange directory for the endpoint %1 is not specified.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(CorrespondentEndpoint));
			Raise MessageString;
		EndIf;
		
		CommonDirectory = New File(FILECommonInformationExchangeDirectory);
		
		If Not CommonDirectory.Exists() Then
			
			MessageString = NStr("en = 'The exchange directory %1 does not exist.';");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, FILECommonInformationExchangeDirectory);
			Raise MessageString;
		EndIf;
		
		If Not SSL200CompatibilityMode Then
			
			FILEAbsoluteDataExchangeDirectory = CommonClientServer.GetFullFileName(
				FILECommonInformationExchangeDirectory,
				RelativeInformationExchangeDirectory);
			
			// Creating a message exchange directory
			AbsoluteDirectory = New File(FILEAbsoluteDataExchangeDirectory);
			If Not AbsoluteDirectory.Exists() Then
				CreateDirectory(AbsoluteDirectory.FullName);
			EndIf;
			
			// Saving exchange message transfer settings for the current data area
			RecordStructure = New Structure;
			RecordStructure.Insert("Peer", Peer);
			RecordStructure.Insert("CorrespondentEndpoint", CorrespondentEndpoint);
			RecordStructure.Insert("DataExchangeDirectory", RelativeInformationExchangeDirectory);
			
			InformationRegisters.DataAreaExchangeTransportSettings.UpdateRecord(RecordStructure);
		EndIf;
		
	ElsIf TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
		
		// Data exchange over a  FTP server.
		
		FTPSettings = DataExchangeServer.FTPConnectionSetup();
		FTPSettings.Server               = TransportSettings.FTPServer;
		FTPSettings.Port                 = TransportSettings.FTPConnectionPort;
		FTPSettings.UserName      = TransportSettings.FTPConnectionUser;
		FTPSettings.UserPassword   = TransportSettings.FTPConnectionPassword;
		FTPSettings.PassiveConnection  = TransportSettings.FTPConnectionPassiveConnection;
		FTPSettings.SecureConnection = DataExchangeServer.SecureConnection(TransportSettings.FTPConnectionPath);
		
		FTPConnection = DataExchangeServer.FTPConnection(FTPSettings);
		
		AbsoluteDataExchangeDirectory = CommonClientServer.GetFullFileName(
			TransportSettings.FTPPath,
			RelativeInformationExchangeDirectory);
		If Not DataExchangeServer.FTPDirectoryExist(AbsoluteDataExchangeDirectory, RelativeInformationExchangeDirectory, FTPConnection) Then
			FTPConnection.CreateDirectory(AbsoluteDataExchangeDirectory);
		EndIf;
		
		// 
		RecordStructure = New Structure;
		RecordStructure.Insert("Peer", Peer);
		RecordStructure.Insert("CorrespondentEndpoint", CorrespondentEndpoint);
		RecordStructure.Insert("DataExchangeDirectory", RelativeInformationExchangeDirectory);
		
		InformationRegisters.DataAreaExchangeTransportSettings.UpdateRecord(RecordStructure);
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The endpoint %2 doesn''t support the exchange message transport type %1.';"),
			String(TransportSettings.DefaultExchangeMessagesTransportKind),
			String(CorrespondentEndpoint));
	EndIf;
		
EndProcedure

// Updates settings and sets default values for a node
//
Procedure UpdateExchangeSetting(
		Val Peer,
		Val DefaultNodeValues) Export
	
	BeginTransaction();
	Try
	    Block = New DataLock;
	    LockItem = Block.Add(Common.TableNameByRef(Peer));
	    LockItem.SetValue("Ref", Peer);
	    Block.Lock();
	    
		LockDataForEdit(Peer);
		CorrespondentObject = Peer.GetObject();

	    //  
		DataExchangeEvents.SetDefaultNodeValues(CorrespondentObject, DefaultNodeValues);
		
		CorrespondentObject.AdditionalProperties.Insert("GettingExchangeMessage");
		CorrespondentObject.Write();

	    CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;
	
EndProcedure

// Saves session data and sets the CompletedSuccessfully flag value to True
//
Procedure SaveSessionData(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = " "+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '{%1}';"), Presentation);
	EndIf;
	
	MessageString = NStr("en = 'Message exchange session %1 is completed. %2';",
		Common.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
		String(Message.Body.SessionId), Presentation);
	WriteLogEvent(EventLogEventSystemMessagesExchangeSessions(),
		EventLogLevel.Information,,, MessageString);
	InformationRegisters.SystemMessageExchangeSessions.SaveSessionData(Message.Body.SessionId, Message.Body.Data);
	
EndProcedure

// Sets the CompletedSuccessfully flag value to True for a session passed to the procedure
//
Procedure CommitSuccessfulSession(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '{%1}';"), Presentation);
	EndIf;
	
	MessageString = NStr("en = 'Message exchange session %1 is completed. %2';",
		Common.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
		String(Message.Body.SessionId), Presentation);
	WriteLogEvent(EventLogEventSystemMessagesExchangeSessions(),
		EventLogLevel.Information,,, MessageString);
	InformationRegisters.SystemMessageExchangeSessions.CommitSuccessfulSession(Message.Body.SessionId);
	
EndProcedure

// Sets the CompletedWithError flag value to False for a session passed to the procedure
//
Procedure CommitUnsuccessfulSession(Val Message, Val Presentation = "") Export
	
	If Not IsBlankString(Presentation) Then
		Presentation = " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '{%1}';"), Presentation);
	EndIf;
	
	MessageString = NStr("en = 'Message exchange failed. Session: %1. %2.
		|Error details from the peer infobase: %3';", Common.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
		String(Message.Body.SessionId), Presentation, Message.Body.ErrorDescription);
	WriteLogEvent(EventLogEventSystemMessagesExchangeSessions(),
		EventLogLevel.Error,,, MessageString);
		
	InformationRegisters.SystemMessageExchangeSessions.CommitUnsuccessfulSession(
		Message.Body.SessionId, Message.Body.ErrorDescription);
	
EndProcedure

// Returns a minimum required platform version
//
Function RequiredPlatformVersion() Export
	
	PlatformVersion = "";
	DataExchangeSaaSOverridable.OnDefineRequiredApplicationVersion(PlatformVersion);
	If ValueIsFilled(PlatformVersion) Then
		Return PlatformVersion;
	EndIf;
	
	SystemInfo = New SystemInfo;
	PlatformVersion = StrSplit(SystemInfo.AppVersion, ".");
	
	// 
	PlatformVersion.Delete(3);
	Return StrConcat(PlatformVersion, ".");
	
EndFunction

// Data synchronization setup event for the event log
//
Function EventLogEventDataSynchronizationSetup() Export
	
	Return NStr("en = 'Data exchange SaaS.Data synchronization setup';",
		Common.DefaultLanguageCode());
	
EndFunction

// Data synchronization monitor event for the event log
//
Function EventLogEventDataSynchronizationMonitor() Export
	
	Return NStr("en = 'Data exchange SaaS.Data synchronization monitor';",
		Common.DefaultLanguageCode());
	
EndFunction

// Data synchronization event for the event log
//
Function DataSyncronizationLogEvent() Export
	
	Return NStr("en = 'Data exchange SaaS.Data synchronization';",
		Common.DefaultLanguageCode());
	
EndFunction

Function EventLogEventSystemMessagesExchangeSessions()
	
	Return NStr("en = 'Data exchange SaaS.Message exchange sessions';",
		Common.DefaultLanguageCode());
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// Data exchange monitor procedures and functions

// For internal use
// 
Function DataExchangeMonitorTable(Val MethodExchangePlans, Val AdditionalExchangePlanProperties = "", Val OnlyFailedExchanges = False) Export
	
	QueryText = "SELECT
	|	DataExchangesStates.InfobaseNode AS InfobaseNode,
	|	DataExchangesStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed2)
	|			OR DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesImport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
	|WHERE
	|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangesStates.InfobaseNode AS InfobaseNode,
	|	DataExchangesStates.EndDate AS EndDate,
	|	CASE
	|		WHEN DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.Completed2)
	|			OR DataExchangesStates.ExchangeExecutionResult = VALUE(Enum.ExchangeExecutionResults.CompletedWithWarnings)
	|			THEN 0
	|		ELSE 1
	|	END AS ExchangeExecutionResult
	|INTO DataExchangeStatesExport
	|FROM
	|	InformationRegister.DataAreaDataExchangeStates AS DataExchangesStates
	|WHERE
	|	DataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangesStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesImport
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
	|WHERE
	|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SuccessfulDataExchangesStates.InfobaseNode AS InfobaseNode,
	|	SuccessfulDataExchangesStates.EndDate AS EndDate
	|INTO SuccessfulDataExchangeStatesExport
	|FROM
	|	InformationRegister.DataAreasSuccessfulDataExchangeStates AS SuccessfulDataExchangesStates
	|WHERE
	|	SuccessfulDataExchangesStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataExport)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangePlans.ExchangePlanName AS ExchangePlanName,
	|	ExchangePlans.InfobaseNode AS InfobaseNode,
	|	ExchangePlans.DataAreaMainData AS DataArea,
	|
	|	&AdditionalExchangePlanProperties,
	|
	|	ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) AS LastDataExportResult,
	|	ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) AS LastDataImportResult,
	|	DataExchangeStatesImport.EndDate AS LastImportDate,
	|	DataExchangeStatesExport.EndDate AS LastExportDate,
	|	SuccessfulDataExchangeStatesImport.EndDate AS LastSuccessfulImportDate,
	|	SuccessfulDataExchangeStatesExport.EndDate AS LastSuccessfulExportDate
	|FROM
	|	ConfigurationExchangePlans AS ExchangePlans
	|		LEFT JOIN DataExchangeStatesImport AS DataExchangeStatesImport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatesImport.InfobaseNode
	|		LEFT JOIN DataExchangeStatesExport AS DataExchangeStatesExport
	|		ON ExchangePlans.InfobaseNode = DataExchangeStatesExport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatesImport AS SuccessfulDataExchangeStatesImport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesImport.InfobaseNode
	|		LEFT JOIN SuccessfulDataExchangeStatesExport AS SuccessfulDataExchangeStatesExport
	|		ON ExchangePlans.InfobaseNode = SuccessfulDataExchangeStatesExport.InfobaseNode
	|
	|WHERE &Filter
	|
	|ORDER BY
	|	ExchangePlans.ExchangePlanName,
	|	ExchangePlans.Description";
	
	SetPrivilegedMode(True);
	
	TempTablesManager = New TempTablesManager;
	
	PrepareExchangePlansNodesDataForMonitor(TempTablesManager, MethodExchangePlans, AdditionalExchangePlanProperties);
	
	QueryText = StrReplace(QueryText, "&AdditionalExchangePlanProperties,",
		GetAdditionalPropertiesOfExchangePlanAsString(AdditionalExchangePlanProperties));
	
	If OnlyFailedExchanges Then
		Filter = "
			|WHERE
			|	    ISNULL(DataExchangeStatesExport.ExchangeExecutionResult, 0) <> 0
			|	OR ISNULL(DataExchangeStatesImport.ExchangeExecutionResult, 0) <> 0";
	Else
		Filter = "";
	EndIf;
	
	QueryText = StrReplace(QueryText, "WHERE &Filter", Filter);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	SynchronizationSettings = Query.Execute().Unload();
	SynchronizationSettings.Columns.Add("LastImportDatePresentation");
	SynchronizationSettings.Columns.Add("LastExportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulImportDatePresentation");
	SynchronizationSettings.Columns.Add("LastSuccessfulExportDatePresentation");
	
	For Each SyncSetup In SynchronizationSettings Do
		
		SyncSetup.LastImportDatePresentation         = DataExchangeServer.RelativeSynchronizationDate(SyncSetup.LastImportDate);
		SyncSetup.LastExportDatePresentation         = DataExchangeServer.RelativeSynchronizationDate(SyncSetup.LastExportDate);
		SyncSetup.LastSuccessfulImportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SyncSetup.LastSuccessfulImportDate);
		SyncSetup.LastSuccessfulExportDatePresentation = DataExchangeServer.RelativeSynchronizationDate(SyncSetup.LastSuccessfulExportDate);
		
	EndDo;
	
	Return SynchronizationSettings;
EndFunction

// For internal use
// 
Function GetAdditionalPropertiesOfExchangePlanAsString(Val PropertiesAsString)
	
	Result = "";
	
	Template = "ExchangePlans.[PropertyAsString] AS [PropertyAsString]";
	
	ArrayProperties = StrSplit(PropertiesAsString, ",", False);
	
	For Each PropertyAsString In ArrayProperties Do
		
		PropertyAsStringInQuery = StrReplace(Template, "[PropertyAsString]", PropertyAsString);
		
		Result = Result + PropertyAsStringInQuery + ", ";
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use
// 
Procedure PrepareExchangePlansNodesDataForMonitor(Val TempTablesManager, Val MethodExchangePlans, Val AdditionalExchangePlanProperties)
	
	AdditionalExchangePlanPropertiesAsString = ?(IsBlankString(AdditionalExchangePlanProperties), "", AdditionalExchangePlanProperties + ", ");
	
	Query = New Query;
	
	QueryTemplate = "
	|
	|UNION ALL
	|
	|////////////////////////////////////////////////////////"
	+
	"
	|SELECT
	|
	|	&AdditionalExchangePlanProperties,
	|
	|	Ref                      AS InfobaseNode,
	|	DataAreaMainData AS DataAreaMainData,
	|	Description                AS Description,
	|	""ExchangePlanNameSynonym""   AS ExchangePlanName
	|FROM
	|	&ExchangePlanName
	|WHERE
	|	RegisterChanges
	|	AND NOT DeletionMark
	|";
	
	QueryText = "";
	
	If MethodExchangePlans.Count() > 0 Then
		
		TextTemplate1 = "ExchangePlan.%1";
		
		For Each ExchangePlanName In MethodExchangePlans Do
			
			NameOfTheStringExchangePlan = StrTemplate(TextTemplate1, ExchangePlanName);
			
			ExchangePlanQueryText = StrReplace(QueryTemplate,              "&ExchangePlanName", NameOfTheStringExchangePlan);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "ExchangePlanNameSynonym", Metadata.ExchangePlans[ExchangePlanName].Synonym);
			ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "&AdditionalExchangePlanProperties,", AdditionalExchangePlanPropertiesAsString);
			
			// Deleting a join literal for the first table
			If IsBlankString(QueryText) Then
				
				ExchangePlanQueryText = StrReplace(ExchangePlanQueryText, "UNION ALL", "");
				
			EndIf;
			
			QueryText = QueryText + ExchangePlanQueryText;
			
		EndDo;
		
	Else
		
		AdditionalPropertiesWithoutDataSourceAsString = "";
		
		If Not IsBlankString(AdditionalExchangePlanProperties) Then
			
			AdditionalProperties = StrSplit(AdditionalExchangePlanProperties, ",");
			
			AdditionalPropertiesWithoutDataSource = New Array;
			
			For Each Property In AdditionalProperties Do
				
				AdditionalPropertiesWithoutDataSource.Add(StrReplace("UNDEFINED AS [Property]", "[Property]", Property));
				
			EndDo;
			
			AdditionalPropertiesWithoutDataSourceAsString = StrConcat(AdditionalPropertiesWithoutDataSource) + ", ";
			
		EndIf;
		
		QueryText = "
		|SELECT
		|
		|	&AdditionalPropertiesWithoutDataSourceAsString,
		|
		|	UNDEFINED AS InfobaseNode,
		|	0            AS DataAreaMainData,
		|	UNDEFINED AS Description,
		|	UNDEFINED AS ExchangePlanName
		|";
		
		QueryText = StrReplace(QueryText, "&AdditionalPropertiesWithoutDataSourceAsString,", AdditionalPropertiesWithoutDataSourceAsString);
		
	EndIf;
	
	QueryTextResult = "
	|////////////////////////////////////////////////////////
	|SELECT
	|
	|	&AdditionalExchangePlanProperties,
	|
	|	InfobaseNode,
	|	DataAreaMainData,
	|	Description,
	|	ExchangePlanName
	|INTO ConfigurationExchangePlans
	|FROM
	|	&QueryText
	|	AS NestedQuery
	|;
	|";
	
	RequestInsertionText = StrTemplate("(%1)", QueryText);
	QueryTextResult = StrReplace(QueryTextResult, "&QueryText", RequestInsertionText);
	QueryTextResult = StrReplace(QueryTextResult, "&AdditionalExchangePlanProperties,", AdditionalExchangePlanPropertiesAsString);
	
	Query.Text = QueryTextResult;
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

Function FindInfobaseNode(Val ExchangePlanName, Val NodeCode)
	
	DataArea = StringFunctionsClientServer.StringToNumber(NodeCode);
	
	NodeCodeWithPrefix = ExchangePlanNodeCodeInService(DataArea);
	
	// Searching for a node by S00000123 node code format.
	Result = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCodeWithPrefix);
	
	If Result = Undefined Then
		
		// 
		Result = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode);
		
	EndIf;
	
	If Result = Undefined
		And DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName) Then
		
		Query = New Query(
		"SELECT
		|	T.Ref AS ExchangeNode
		|FROM
		|	#ExchangePlanTable AS T
		|WHERE
		|	NOT T.ThisNode");
		
		Query.Text = StrReplace(Query.Text,
			"#ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			CorrespondentDataArea = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(Selection.ExchangeNode,
				"CorrespondentDataArea");
			
			If CorrespondentDataArea = DataArea Then
				Result = Selection.ExchangeNode;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Result = Undefined Then
		
		Message = NStr("en = 'Cannot find a node in the exchange plan %1. Node ID %2 or %3';");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ExchangePlanName, NodeCode, NodeCodeWithPrefix);
		
		Raise Message;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function CorrespondentVersions(Val InfobaseNode)
	
	SettingsStructure = InformationRegisters.DataAreaExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSWebServiceURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return Common.GetInterfaceVersions(ConnectionParameters, "DataExchangeSaaS");
EndFunction

// Returns the DataExchangeSaaS subsystem parameters that are required upon terminating
// user sessions.
//
// Returns:
//  Structure - parameters.
//
Function StandaloneModeParametersOnExit()
	
	ParametersOnExit = New Structure;
	
	If StandaloneModeInternal.IsStandaloneWorkplace() Then
		
		DataExchangeExecutionFormParameters = StandaloneModeInternal.DataExchangeExecutionFormParameters();
		SynchronizationWithServiceNotExecutedLongTime = StandaloneModeInternal.SynchronizationWithServiceNotExecutedLongTime();
		
	Else
		
		DataExchangeExecutionFormParameters = New Structure;
		SynchronizationWithServiceNotExecutedLongTime = False;
		
	EndIf;
	
	ParametersOnExit.Insert("DataExchangeExecutionFormParameters", DataExchangeExecutionFormParameters);
	ParametersOnExit.Insert("SynchronizationWithServiceNotExecutedLongTime", SynchronizationWithServiceNotExecutedLongTime);
	
	Return ParametersOnExit;
EndFunction

// Adds parameters of client logic for the data exchange subsystem in SaaS mode.
//
Procedure AddClientRunParameters(Parameters)
	
EndProcedure

Function NewPropertiesOfStandaloneWorkstationMetadata(ItemMetadata)
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	AuxiliaryDataSeparator = ModuleSaaSOperations.AuxiliaryDataSeparator();
	
	MetadataProperties1 = New Structure();
	MetadataProperties1.Insert(
		"IsSeparatedMetadataObject",
		ModuleSaaSOperations.IsSeparatedMetadataObject(ItemMetadata));
	MetadataProperties1.Insert(
		"IsSeparatedMetadataObjectAuxiliaryData",
		ModuleSaaSOperations.IsSeparatedMetadataObject(ItemMetadata, AuxiliaryDataSeparator));
	MetadataProperties1.Insert(
		"AuxiliaryDataSeparator",
		AuxiliaryDataSeparator);
	MetadataProperties1.Insert(
		"IsRecordSet",
		Common.IsRegister(ItemMetadata)
			Or Common.IsSequence(ItemMetadata)
			Or Common.BaseTypeNameByMetadataObject(ItemMetadata) = "Recalculations");
			
	Return MetadataProperties1;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Getting references to shared SaaS data pages

// Returns a reference address by ID
// For internal use.
//
Function RefAddressFromInformationCenter(Val Id)
	Result = "";
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return Result;
	EndIf;
	
	ModuleInformationCenterServer = Common.CommonModule("InformationCenterServer");
	
	SetPrivilegedMode(True);
	Try
		RefData = ModuleInformationCenterServer.ContextualLinkByID(Id);
	Except
		// 
		RefData = Undefined;
	EndTry;
	
	If RefData <> Undefined Then
		Result = RefData.Address;
	EndIf;
	
	Return Result;
EndFunction

// Returns an address of reference to an article of thin client setup
// For internal use.
//
Function ThinClientSetupGuideAddress() Export
	
	Return RefAddressFromInformationCenter("ThinClientSetupInstruction");
	
EndFunction

Procedure OnCreateStandaloneWorkstation() Export
	
	If UsersInternalSaaS.UserRegisteredAsShared(
			InfoBaseUsers.CurrentUser().UUID) Then
		
		Raise NStr("en = 'You can create a standalone workstation only under a separated user.
			|The current user is a shared user.';");
		
	EndIf;
	
EndProcedure

#EndRegion