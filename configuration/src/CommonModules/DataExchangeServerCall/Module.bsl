///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Sets the ORMCachedValuesRefreshDate constant value.
// The value is set to the current date of the computer (server).
// On changing the value of this constant, cached values become outdated 
// for the data exchange subsystem and require re-initialization.
// 
Procedure ResetObjectsRegistrationMechanismCache() Export
	
	DataExchangeInternal.ResetObjectsRegistrationMechanismCache();
	
EndProcedure

#EndRegion

#Region Internal

// Returns background job state.
// This function is used to implement long-running operations.
//
// Parameters:
//  JobID - UUID - ID of the background job to receive
//                                                   state for.
// 
// Returns:
//  String - 
//   
//   
//   
//
Function JobState(Val JobID) Export
	
	Try
		Result = ?(TimeConsumingOperations.JobCompleted(JobID), "Completed", "Active");
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

// Deletes data synchronization settings item.
//
Procedure DeleteSynchronizationSetting(Val InfobaseNode) Export
	
	DataExchangeServer.DeleteSynchronizationSetting(InfobaseNode);
	
EndProcedure

#EndRegion

#Region Private

// Executes data exchange process separately for each exchange setting line.
// Data exchange process consists of two stages:
// - Exchange initialization - preparation of data exchange subsystem to perform data exchange
// - Data exchange - a process of reading a message file and then importing this data to infobase 
//                          or exporting changes to the message file.
// The initialization stage is performed once per session and is saved to the session cache at server 
// until the session is restarted or cached values of data exchange subsystem are reset.
// Cached values are reset when data that affects data exchange process is changed
// (transport settings, exchange settings, filter settings on exchange plan nodes).
//
// The exchange can be executed completely for all scenario lines
// or can be executed for a single row of the exchange scenario TS.
//
// Parameters:
//  Cancel                     - Boolean - a cancellation flag. It appears when scenario execution errors occur.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - a catalog item
//                              whose attribute values are used to perform data exchange.
//  LineNumber               - Number - a number of the line to use for performing data exchange.
//                              If it is not specified, all lines are involved in data exchange.
// 
Procedure ExecuteDataExchangeByDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber = Undefined) Export
	
	DataExchangeServer.ExecuteDataExchangeByDataExchangeScenario(Cancel, ExchangeExecutionSettings, LineNumber);
	
EndProcedure

// Records that data exchange is completed.
//
Procedure RecordDataExportInTimeConsumingOperationMode(Val InfobaseNode, Val StartDate) Export
	
	SetPrivilegedMode(True);
	
	ActionOnExchange = Enums.ActionsOnExchange.DataExport;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Completed2);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", DataExchangeServer.EventLogMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode));
	
	DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
	
EndProcedure

// Records data exchange crash.
//
Procedure WriteExchangeFinishWithError(Val InfobaseNode,
												Val ActionOnExchange,
												Val StartDate,
												Val ErrorMessageString) Export
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.WriteExchangeFinishWithError(InfobaseNode,
											ActionOnExchange,
											StartDate,
											ErrorMessageString);
EndProcedure

// Returns the flag of whether a register record set is empty.
//
Function RegisterRecordSetIsEmpty(RecordStructure, RegisterName) Export
	
	// 
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet(); // InformationRegisterRecordSet
	
	For Each FilterElement In RecordSet.Filter Do
		FilterValue = Undefined;
		If RecordStructure.Property(FilterElement.Name, FilterValue) Then
			FilterElement.Set(FilterValue);
		EndIf;
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet.Count() = 0;
	
EndFunction

// Returns the event log message key by the specified action string.
//
Function EventLogMessageKeyByActionString(InfobaseNode, ActionOnStringExchange) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange[ActionOnStringExchange]);
	
EndFunction

// Returns the structure that contains event log filter data.
//
Function EventLogFilterData(InfobaseNode, Val ActionOnExchange) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangesStates = DataExchangeServer.DataExchangesStates(InfobaseNode, ActionOnExchange);
	
	Filter = New Structure;
	Filter.Insert("EventLogEvent", DataExchangeServer.EventLogMessageKey(InfobaseNode, ActionOnExchange));
	Filter.Insert("StartDate",                DataExchangesStates.StartDate);
	Filter.Insert("EndDate",             DataExchangesStates.EndDate);
	
	Return Filter;
	
EndFunction

// Returns an array of all reference types available in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Return DataExchangeCached.AllConfigurationReferenceTypes();
	
EndFunction

Function DataExchangeOption(Val Peer) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.DataExchangeOption(Peer);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange in a privileged mode.

// Returns a list of metadata objects prohibited to export.
// Export is prohibited if a table is marked as DoNotExport in the rules of exchange plan objects registration.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - a reference to the exchange plan node being analyzed.
//
// Returns:
//     Array - 
//
Function NotExportedNodeObjectsMetadataNames(Val InfobaseNode) Export
	Result = New Array;
	
	NotExportMode = Enums.ExchangeObjectExportModes.NotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanComposition(InfobaseNode);
	For Each KeyValue In ExportModes Do
		If KeyValue.Value=NotExportMode Then
			Result.Add(KeyValue.Key);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Checks if the specified exchange node is the master node.
//
// Parameters:
//   InfobaseNode - ExchangePlanRef - a reference to the exchange plan node
//       to be checked if it is master node.
//
// Returns:
//   Boolean
//
Function IsMasterNode(Val InfobaseNode) Export
	
	Return ExchangePlans.MasterNode() = InfobaseNode;
	
EndFunction

// Creates a query for clearing node permissions (on deleting).
//
Function RequestToClearPermissionsToUseExternalResources(Val InfobaseNode) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	Query = ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(InfobaseNode);
	Return CommonClientServer.ValueInArray(Query);
	
EndFunction

Procedure DownloadExtensions() Export
	
	If Not Users.IsFullUser(, True, False) Then
		Return;
	EndIf;
	
	InfobaseNode = ExchangePlans.MasterNode();
		
	If InfobaseNode <> Undefined Then
		
		DataExchangeServer.DisableDataExchangeMessageImportRepeatBeforeStart();
		
		SetPrivilegedMode(True);
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("ImportPermitted", True);
		DataExchangeServer.SetDataExchangeMessageImportModeBeforeStart("DownloadingExtensions", True);
		SetPrivilegedMode(False);
		
		// 
		DataExchangeServer.UpdateDataExchangeRules();
		
		TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
					
		ExchangeParameters = DataExchangeServer.ExchangeParameters();
		ExchangeParameters.ExchangeMessagesTransportKind = TransportKind;
		ExchangeParameters.ExecuteImport1 = True;
		ExchangeParameters.ExecuteExport2 = False;		
		ExchangeParameters.TimeConsumingOperationAllowed = False;
		ExchangeParameters.ParametersOnly = True;
						
		Cancel = False;
		Try			
			
			DataExchangeServer.ExecuteDataExchangeForInfobaseNode(InfobaseNode, ExchangeParameters, Cancel);
			
		Except
			
			ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			EventLogEvent = NStr("en = 'Data exchange.Load extension';", Common.DefaultLanguageCode());
			WriteLogEvent(EventLogEvent, EventLogLevel.Error, , , ErrorMessage);
						
		EndTry;
			
		DataExchangeInternal.DisableLoadingExtensionsThatChangeTheDataStructure();	
		
	EndIf;
	
EndProcedure

// Parameters:
//   ObjectNode - ExchangePlanObject
//
Function CheckTheNeedForADeferredNodeEntry(Val ObjectNode) Export
	
	PropertiesToExclude = New Array;
	PropertiesToExclude.Add("SentNo");
	PropertiesToExclude.Add("ReceivedNo");
	PropertiesToExclude.Add("DeletionMark");
	PropertiesToExclude.Add("Code");
	PropertiesToExclude.Add("Description");
	
	If Common.DataSeparationEnabled() Then
		FullMetadataName = ObjectNode.Ref.Metadata().FullName();
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		
		MainDataSeparator        = ModuleSaaSOperations.MainDataSeparator();
		AuxiliaryDataSeparator = ModuleSaaSOperations.AuxiliaryDataSeparator();
		
		If ModuleSaaSOperations.IsSeparatedMetadataObject(FullMetadataName, MainDataSeparator) Then
			PropertiesToExclude.Add(MainDataSeparator);
		EndIf;
		
		If ModuleSaaSOperations.IsSeparatedMetadataObject(FullMetadataName, AuxiliaryDataSeparator) Then
			PropertiesToExclude.Add(AuxiliaryDataSeparator);
		EndIf;
		
	EndIf;
	
	NodeType = Type("ExchangePlanObject." + ObjectNode.Ref.Metadata().Name);
	NodeBeforeWrite = FormDataToValue(ObjectNode, NodeType); //ExchangePlanObject
		
	Result = New Structure;
	Result.Insert("ALongTermOperationIsRequired"	, False);
	Result.Insert("ThereIsAnActiveBackgroundTask" 	, False);
	Result.Insert("NodeStructureAddress"				, Undefined);
	
	If Not ObjectNode.Ref.IsEmpty()
		And Not ObjectNode.ThisNode
		And DataExchangeEvents.DataDiffers1(NodeBeforeWrite, ObjectNode.Ref.GetObject(), , StrConcat(PropertiesToExclude, ","))
		And DataExchangeInternal.ChangesRegistered(ObjectNode.Ref) Then
		
		Result.ALongTermOperationIsRequired = True;
		
		//
		Filter = New Structure;
		Filter.Insert("Key",      "DeferredNodeWriting");
		Filter.Insert("State", BackgroundJobState.Active);

		ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
		Result.ThereIsAnActiveBackgroundTask = ActiveBackgroundJobs.Count() > 0;
		
		//
		NodeStructure = New Structure;
	
		NodeMetadata = NodeBeforeWrite.Ref.Metadata();
		
		For Each Attribute In NodeMetadata.Attributes Do
			NodeStructure.Insert(Attribute.Name, NodeBeforeWrite[Attribute.Name]);			
		EndDo;
		
		For Each Table In NodeMetadata.TabularSections Do		
			Tab = NodeBeforeWrite[Table.Name].Unload();
			NodeStructure.Insert(Table.Name, Tab);				
		EndDo;
		
		Result.NodeStructureAddress = PutToTempStorage(NodeStructure, New UUID);
					
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion