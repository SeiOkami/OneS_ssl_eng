///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var DataImportDataProcessorField;

#EndRegion

#Region Public

#Region ExportProperties1

// Function for retrieving property: the result of data exchange.
//  Returns:
//      EnumRef.ExchangeExecutionResults - the result of the data exchange.
//
Function ExchangeExecutionResult() Export
	
	If ExchangeComponents = Undefined Then
		Return Enums.ExchangeExecutionResults.Canceled;
	EndIf;
	
	ExchangeExecutionResult = ExchangeComponents.DataExchangeState.ExchangeExecutionResult;
	If ExchangeExecutionResult = Undefined Then
		Return Enums.ExchangeExecutionResults.Completed2;
	EndIf;
	
	Return ExchangeExecutionResult;
	
EndFunction

// Function for retrieving property: the result of data exchange.
//
//  Returns: 
//      String - the result of the data exchange.
//
Function ExchangeExecutionResultString() Export
	
	Return Common.EnumerationValueName(ExchangeExecutionResult());
	
EndFunction


// Function for retrieving property: the number of imported objects.
//
//  Returns:
//      Number - 
//
Function ImportedObjectCounter() Export
	
	If ExchangeComponents = Undefined Then
		Return 0;
	EndIf;
	
	Return ExchangeComponents.ImportedObjectCounter;
	
EndFunction

// Function for retrieving property: the amount of exported objects.
//
//  Returns:
//      Number - 
//
Function ExportedObjectCounter() Export
	
	If ExchangeComponents = Undefined Then
		Return 0;
	EndIf;
	
	Return ExchangeComponents.ExportedObjectCounter;
	
EndFunction

// Function for retrieving properties: a data exchange error message string.
//
//  Returns:
//      String - 
//
Function ErrorMessageString() Export
	
	If ExchangeComponents = Undefined Then
		Return "";
	EndIf;
	
	Return ExchangeComponents.ErrorMessageString;
	
EndFunction

// Function for retrieving property: a flag that shows a data exchange execution error.
//
//  Returns:
//     Boolean - 
//
Function FlagErrors() Export
	
	Return ExchangeComponents.FlagErrors;
	
EndFunction

// Function for retrieving property: a number of data exchange message.
//
//  Returns:
//      Number - 
//
Function MessageNo() Export
	
	Return ExchangeComponents.IncomingMessageNumber;
	
EndFunction

// Function for retrieving properties: a value table with incoming exchange message statistics and extra information.
//
//  Returns:
//      ValueTable - 
//
Function PackageHeaderDataTable() Export
	
	If ExchangeComponents = Undefined Then
		Return DataExchangeXDTOServer.NewDataBatchTitleTable();
	Else
		Return ExchangeComponents.PackageHeaderDataTable;
	EndIf;
	
EndFunction

// Function for retrieving properties: map with data tables of the received data exchange message.
//
//  Returns:
//      Map - 
//
Function DataTablesExchangeMessages() Export
	
	If ExchangeComponents = Undefined Then
		Return New Map;
	Else
		Return ExchangeComponents.DataTablesExchangeMessages;
	EndIf;
	
EndFunction

#EndRegion

#Region DataExport

// Run data export
// -- All objects are exported to one file.
//
// Parameters:
//      DataProcessorForDataImport - DataProcessorObject.ConvertXTDOObjects - a data processor for import in COM connection.
//
Procedure RunDataExport(DataProcessorForDataImport = Undefined) Export
	
	DataImportDataProcessorField = DataProcessorForDataImport;
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Send");
		
	#Region SettingExchangeComponentsForNodeOperations
	ExchangeComponents.CorrespondentNode = NodeForExchange;
	
	DataExchangeValuationOfPerformance.Initialize(ExchangeComponents);
	
	ExchangeComponents.XDTOSettingsOnly = Not DataExchangeServer.SynchronizationSetupCompleted(
		ExchangeComponents.CorrespondentNode);
	If Not ExchangeComponents.XDTOSettingsOnly Then
		ExchangeComponents.ExchangeFormatVersion = Common.ObjectAttributeValue(
			ExchangeComponents.CorrespondentNode, "ExchangeFormatVersion");
	EndIf;
		
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
	ExchangeComponents.XMLSchema = DataExchangeXDTOServer.ExchangeFormat(ExchangePlanName, ExchangeComponents.ExchangeFormatVersion);
	
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
	
	If Not ExchangeComponents.XDTOSettingsOnly Then
		
		ExchangeComponents.ExchangeManager = DataExchangeXDTOServer.FormatVersionExchangeManager(
			ExchangeComponents.ExchangeFormatVersion, ExchangeComponents.CorrespondentNode);
		
		ExchangeComponents.ObjectsRegistrationRulesTable = DataExchangeXDTOServer.ObjectsRegistrationRules(
			ExchangeComponents.CorrespondentNode);
		ExchangeComponents.ExchangePlanNodeProperties = DataExchangeXDTOServer.ExchangePlanNodeProperties(
			ExchangeComponents.CorrespondentNode);
			
		DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
		DataExchangeXDTOServer.FillXDTOSettingsStructure(ExchangeComponents);
		DataExchangeXDTOServer.FillSupportedXDTOObjects(ExchangeComponents);
		
		ExchangeComponents.SkipObjectsWithSchemaCheckErrors = DataExchangeXDTOServer.SkipObjectsWithSchemaCheckErrors(
			ExchangeComponents.CorrespondentNode);
		
	Else
		
		DataExchangeXDTOServer.FillXDTOSettingsStructure(ExchangeComponents);
		
	EndIf;
	
	FormatExtensionsToExchangeComponents(ExchangeComponents);
	
	#EndRegion
	
	If Not ExchangeComponents.XDTOSettingsOnly Then
		ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
		ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
		
		DataExchangeXDTOServer.InitializeKeepExchangeProtocol(ExchangeComponents, ExchangeProtocolFileName);
	EndIf;
	
	Cancel = False;
	If SetExchangePlanNodeLock
		And ExchangeComponents.IsExchangeViaExchangePlan Then
		
		DataExchangeServer.BlockTheExchangeNode(ExchangeComponents.CorrespondentNode, Cancel);
		
	EndIf;
	
	If Cancel = True Then
		
		Return;
		
	EndIf;
	
	// 
	DataExchangeXDTOServer.OpenExportFile(ExchangeComponents, ExchangeFileName);
	
	Try
		AfterOpenExportFile(Cancel);
		// DATA EXPORT
		If Not Cancel Then
			DataExchangeXDTOServer.ExecuteDataExport(ExchangeComponents);
		EndIf;
	Except
		Info = ErrorInfo();
		ErrorCode = New Structure("BriefErrorDescription, DetailErrorDescription",
			ErrorProcessing.BriefErrorDescription(Info), ErrorProcessing.DetailErrorDescription(Info));
		
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorCode);
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		
		ExchangeComponents.ExchangeFile = Undefined;
		Cancel = True;
	EndTry;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		UnlockDataForEdit(ExchangeComponents.CorrespondentNode);
	EndIf;
	
	If ExchangeComponents.FlagErrors Then

		Try
			DeleteFiles(ExchangeFileName);
		Except
			WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));	
		EndTry;
	
	EndIf;
	
	If Cancel Then
		
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		
		Return;
		
	EndIf;
	
	XMLExportData = ExchangeComponents.ExchangeFile.Close();
	
	DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
	
	DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
	
	If IsExchangeOverExternalConnection() Then
		If DataProcessorForDataImport().DataImportMode = "ImportMessageForDataMapping" Then
			If Not ExchangeComponents.FlagErrors Then
				DataProcessorForDataImport().PutMessageForDataMapping(XMLExportData);
			Else
				DataProcessorForDataImport().PutMessageForDataMapping(Undefined);
			EndIf;
		Else
			If Not ExchangeComponents.FlagErrors Then
				If Common.HasObjectAttribute("DataImportedOverExternalConnection", DataProcessorForDataImport().Metadata())
					And DataProcessorForDataImport().DataImportedOverExternalConnection Then
					DataProcessorForDataImport().ToDownloadTheMessageDataExchange(XMLExportData);
				Else
					TempFileName = GetTempFileName("xml");
				
					TextDocument = New TextDocument;
					TextDocument.AddLine(XMLExportData);
					TextDocument.Write(TempFileName,,Chars.LF);
					
					DataProcessorForDataImport().ExchangeFileName = TempFileName;
					DataProcessorForDataImport().RunDataImport();
				
					DeleteFiles(TempFileName);
				EndIf;
			Else
				DataProcessorForDataImport().ExchangeFileName = "";
				DataProcessorForDataImport().RunDataImport();
			EndIf;
		EndIf;
	EndIf;
	
	If SetExchangePlanNodeLock
		And ExchangeComponents.IsExchangeViaExchangePlan Then
		
		DataExchangeServer.UnblockTheExchangeNode(ExchangeComponents.CorrespondentNode, Cancel);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region DataImport

// Imports data from the exchange message file.
// Data is imported to the infobase.
//
// Parameters:
//  ImportParameters - Structure
//                    - Undefined - the service parameter. Not intended for use.
//
Procedure RunDataImport(ImportParameters = Undefined) Export
	
	If ImportParameters = Undefined Then
		ImportParameters = New Structure;
	EndIf;
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Receive");
		
	ExchangeComponents.CorrespondentNode = ExchangeNodeDataImport;
	ExchangeComponents.UseCacheOfPublicIdentifiers = 
		DataExchangeCached.UseCacheOfPublicIdentifiers(ExchangeNodeDataImport.Metadata().Name);
	
	DataExchangeValuationOfPerformance.Initialize(ExchangeComponents);

	DataExchangeWithExternalSystem = Undefined;
	If ImportParameters.Property("DataExchangeWithExternalSystem", DataExchangeWithExternalSystem) Then
		ExchangeComponents.DataExchangeWithExternalSystem = DataExchangeWithExternalSystem;
	EndIf;
	
	DataImportMode = "ImportToInfobase";
	
	ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
	ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
	
	DataExchangeXDTOServer.InitializeKeepExchangeProtocol(ExchangeComponents, ExchangeProtocolFileName);
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
	
	If IsBlankString(ExchangeFileName) Then
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, 15);
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		Return;
	EndIf;
	
	If ContinueOnError Then
		UseTransactions = False;
		ExchangeComponents.UseTransactions = False;
	EndIf;
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	// Format extension can be initialized following reading the format version from a message file.
	FormatExtensionsToExchangeComponents(ExchangeComponents);
	
	Cancel = False;
	AfterOpenImportFile(Cancel);
	If SetExchangePlanNodeLock
		And ExchangeComponents.IsExchangeViaExchangePlan Then
		
		DataExchangeServer.BlockTheExchangeNode(ExchangeComponents.CorrespondentNode, Cancel);
		
	EndIf;
	
	If Cancel Then
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		Return;
	EndIf;
	
	DataAnalysisResultToExport = DataExchangeServer.DataAnalysisResultToExport(ExchangeFileName, True);
	DataAnalysisResultToExport.Insert("CorrespondentSupportsDataExchangeID",
											ExchangeComponents.CorrespondentSupportsDataExchangeID);
	ExchangeComponents.Insert("ExchangeMessageFileSize", DataAnalysisResultToExport.ExchangeMessageFileSize);
	ExchangeComponents.Insert("ObjectsToImportCount", DataAnalysisResultToExport.ObjectsToImportCount);
	
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	Try
		DataExchangeXDTOServer.RunReadingData(ExchangeComponents);
		DataExchangeInternal.DisableAccessKeysUpdate(False);
	Except
		DataExchangeInternal.DisableAccessKeysUpdate(False);
		Information = ErrorInfo();
		MessageString = NStr("en = 'Data import error: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString, ErrorProcessing.DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, MessageString, , , , , True);
		ExchangeComponents.FlagErrors = True;
	EndTry;
	
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	Try
		DataExchangeXDTOServer.DeleteTempObjectsCreatedByRefs(ExchangeComponents);
		DataExchangeInternal.DisableAccessKeysUpdate(False);
	Except
		DataExchangeInternal.DisableAccessKeysUpdate(False);
		Information = ErrorInfo();
		MessageString = NStr("en = 'Cannot delete temporary objects created by references: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString, ErrorProcessing.DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, MessageString, , , , , True);
		ExchangeComponents.FlagErrors = True;
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	If Not ExchangeComponents.FlagErrors Then
		// Checking data From / NewFrom.
		CheckNodesCodes(DataAnalysisResultToExport, ExchangeComponents.CorrespondentNode);
		
		// Writing information on the incoming message number.
		BeginTransaction();
		Try
			DataLock = New DataLock;
			
			DataLockItem = DataLock.Add("ExchangePlan." + DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode));
			DataLockItem.SetValue("Ref", ExchangeComponents.CorrespondentNode);
			
			DataLock.Lock();
	
			NodeObject = ExchangeComponents.CorrespondentNode.GetObject();
			NodeObject.ReceivedNo = ExchangeComponents.IncomingMessageNumber;
			NodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
			NodeObject.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
	DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
	
	DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
	
	If SetExchangePlanNodeLock
		And ExchangeComponents.IsExchangeViaExchangePlan Then
		
		DataExchangeServer.UnblockTheExchangeNode(ExchangeComponents.CorrespondentNode, Cancel);
		
	EndIf;
	
EndProcedure

// Imports data from an exchange message file to an infobase of the specified object types only.
//
// Parameters:
//  TablesToImport - Array of String - array of types to be imported from the exchange message.
//                       For example, to import from the exchange message the "Demo:Counterparties" catalog items only:
//                         TablesToImport = New Array;
//                         TablesToImport.Add("CatalogRef._DemoCounterparties");
//                       You can receive the list of all types that are contained in the current exchange message
//                       by calling the ExecuteExchangeMessageAnalysis() procedure.
// 
Procedure ExecuteDataImportForInfobase(TablesToImport) Export
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Receive");
	ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
	ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
	ExchangeComponents.CorrespondentNode = ExchangeNodeDataImport;
	
	ExchangeComponents.UseCacheOfPublicIdentifiers = 
		DataExchangeCached.UseCacheOfPublicIdentifiers(ExchangeNodeDataImport.Metadata().Name);
		
	DataExchangeValuationOfPerformance.Initialize(ExchangeComponents);
	
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
	
	DataImportMode = "ImportToInfobase";
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	Cancel = False;
	AfterOpenImportFile(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Record in the event log.
	MessageString = NStr("en = 'Data exchange started. Node: %1.';", Common.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, String(ExchangeNodeDataImport));
	DataExchangeXDTOServer.WriteEventLogDataExchange1(MessageString, ExchangeComponents, EventLogLevel.Information);
	
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	Try
		DataExchangeXDTOServer.RunReadingData(ExchangeComponents, TablesToImport);
	Except
		Information = ErrorInfo();
		MessageString = NStr("en = 'Data import error: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString, ErrorProcessing.DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteEventLogDataExchange1(MessageString, ExchangeComponents, EventLogLevel.Error);
	EndTry;
	
	Try
		DataExchangeXDTOServer.DeleteTempObjectsCreatedByRefs(ExchangeComponents);
	Except
		Information = ErrorInfo();
		MessageString = NStr("en = 'Cannot delete temporary objects created by references: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString, ErrorProcessing.DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteEventLogDataExchange1(MessageString, ExchangeComponents, EventLogLevel.Error);
	EndTry;
	DataExchangeInternal.DisableAccessKeysUpdate(False);
	
	// 
	MessageString = NStr("en = 'Action to execute: %1;
		|Completion status: %2;
		|Objects processed: %3.';",
		Common.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
					ExchangeComponents.DataExchangeState.ExchangeExecutionResult,
					Enums.ActionsOnExchange.DataImport,
					Format(ExchangeComponents.ImportedObjectCounter, "NG=0"));
	
	DataExchangeXDTOServer.WriteEventLogDataExchange1(MessageString, ExchangeComponents, EventLogLevel.Information);
	ExchangeComponents.ExchangeFile.Close();
	
EndProcedure

// Performs sequential reading of the exchange message file while:
//  - registration of changes by the number of the incoming receipt is deleted
//  - exchange rules are imported
//  - information on data types is imported
//  - data mapping information is read and recorded to the infobase
//  - information on objects types and their amount is collected.
//
// Parameters:
//      AnalysisParameters - Structure - not used, left for the compatibility purposes.
// 
Procedure ExecuteExchangeMessageAnalysis(AnalysisParameters = Undefined) Export
	
	DataImportMode = "ImportToValueTable";
	UseTransactions = False;
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Receive");
	ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
	ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
	ExchangeComponents.CorrespondentNode = ExchangeNodeDataImport;
	ExchangeComponents.DataImportToInfobaseMode = False;
	
	ExchangeComponents.UseCacheOfPublicIdentifiers = 
		DataExchangeCached.UseCacheOfPublicIdentifiers(ExchangeNodeDataImport.Metadata().Name);
		
	DataExchangeValuationOfPerformance.Initialize(ExchangeComponents, True);
	
	DataExchangeXDTOServer.InitializeKeepExchangeProtocol(ExchangeComponents, ExchangeProtocolFileName);
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
		
	If IsBlankString(ExchangeFileName) Then
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, 15);
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		Return;
	EndIf;
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	// Format extension can be initialized following reading the format version from a message file.
	FormatExtensionsToExchangeComponents(ExchangeComponents);
	
	Cancel = False;
	AfterOpenImportFile(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	Try
		
		// 
		DataExchangeXDTOServer.ReadDataInAnalysisMode(ExchangeComponents, AnalysisParameters);
		
		PackageHeaderDataTable = ExchangeComponents.PackageHeaderDataTable; // ValueTable
		
		// Generate a temporary data table.
		TemporaryPackageHeaderDataTable = PackageHeaderDataTable.Copy(, "SourceTypeString, DestinationTypeString, SearchFields, TableFields");
		TemporaryPackageHeaderDataTable.GroupBy("SourceTypeString, DestinationTypeString, SearchFields, TableFields");
		
		// 
		PackageHeaderDataTable.GroupBy(
			"ObjectTypeString, SourceTypeString, DestinationTypeString, SynchronizeByID, IsClassifier, IsObjectDeletion, UsePreview",
			"ObjectCountInSource");
		
		PackageHeaderDataTable.Columns.Add("SearchFields",  New TypeDescription("String"));
		PackageHeaderDataTable.Columns.Add("TableFields", New TypeDescription("String"));
		
		For Each TableRow In PackageHeaderDataTable Do
			
			Filter = New Structure;
			Filter.Insert("SourceTypeString", TableRow.SourceTypeString);
			Filter.Insert("DestinationTypeString", TableRow.DestinationTypeString);
			
			TemporaryTableRows = TemporaryPackageHeaderDataTable.FindRows(Filter);
			
			TableRow.SearchFields  = TemporaryTableRows[0].SearchFields;
			TableRow.TableFields = TemporaryTableRows[0].TableFields;
			
		EndDo;
		
	Except
		MessageString = NStr("en = 'Data analysis error: %1';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, MessageString,,,,,True);
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
EndProcedure

// Imports data from the exchange message file to values table of specified objects types.
//
// Parameters:
//  TablesToImport - Array of String - an array of types to be imported from the exchange message.
//                       For example, to import from the exchange message the "Demo:Counterparties" catalog items only:
//                         TablesToImport = New Array;
//                         TablesToImport.Add("CatalogRef._DemoCounterparties");
//                       You can receive the list of all types that are contained in the current exchange message
//                       by calling the ExecuteExchangeMessageAnalysis() procedure.
// 
Procedure ExecuteDataImportIntoValueTable(TablesToImport) Export
	
	DataImportMode = "ImportToValueTable";
	UseTransactions = False;
	
	InitializeRulesTables = (ExchangeComponents = Undefined);
	
	If ExchangeComponents = Undefined Then
		
		ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Receive");
		ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
		ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
		ExchangeComponents.CorrespondentNode = ExchangeNodeDataImport;
		
		ExchangeComponents.UseCacheOfPublicIdentifiers = 
			DataExchangeCached.UseCacheOfPublicIdentifiers(ExchangeNodeDataImport.Metadata().Name);
			
		DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.Initialize(ExchangeComponents);
		
	EndIf;
	
	DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, ExchangeFileName);
	
	// Format extension can be initialized following reading the format version from a message file.
	FormatExtensionsToExchangeComponents(ExchangeComponents);
	
	Cancel = False;
	AfterOpenImportFile(Cancel, InitializeRulesTables);
	
	If Cancel Then
		Return;
	EndIf;
	
	ExchangeComponents.DataImportToInfobaseMode = False;
	
	// Initialize data tables of the data exchange message.
	For Each DataTableKey In TablesToImport Do
		
		SubstringsArray = StrSplit(DataTableKey, "#");
		
		ObjectType = SubstringsArray[1];
		
		ExchangeComponents.DataTablesExchangeMessages.Insert(DataTableKey, InitExchangeMessageDataTable(Type(ObjectType)));
		
	EndDo;
	
	DataExchangeXDTOServer.RunReadingData(ExchangeComponents, TablesToImport);
	
	DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
	
	ExchangeComponents.ExchangeFile.Close();
		
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Stores an exchange file to a file storage service for subsequent mapping.
// Data is not imported.
//
Procedure PutMessageForDataMapping(XMLExportData) Export
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents("Receive");
	
	ExchangeComponents.CorrespondentNode = ExchangeNodeDataImport;
	
	ExchangeComponents.EventLogMessageKey = EventLogMessageKey;
	ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
	
	ExchangeComponents.UseCacheOfPublicIdentifiers = 
		DataExchangeCached.UseCacheOfPublicIdentifiers(ExchangeNodeDataImport.Metadata().Name);
		
	DataExchangeXDTOServer.InitializeKeepExchangeProtocol(ExchangeComponents, ExchangeProtocolFileName);
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
	
	If Not ValueIsFilled(XMLExportData) Then
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, 15);
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		
		FileID = "";
	Else
		DumpDirectory = DataExchangeServer.TempFilesStorageDirectory();
		TempFileName = DataExchangeServer.UniqueExchangeMessageFileName();
		
		TempFileFullName = CommonClientServer.GetFullFileName(
			DumpDirectory, TempFileName);
			
		TextDocument = New TextDocument;
		TextDocument.AddLine(XMLExportData);
		TextDocument.Write(TempFileFullName, , Chars.LF);
		
		FileID = DataExchangeServer.PutFileInStorage(TempFileFullName);
	EndIf;
	
	DataExchangeInternal.PutMessageForDataMapping(ExchangeNodeDataImport, FileID);
	
EndProcedure

Procedure ToDownloadTheMessageDataExchange(XMLExportData) Export
	
	ExchangeFileName = GetTempFileName("xml");
				
	TextDocument = New TextDocument;
	TextDocument.AddLine(XMLExportData);
	TextDocument.Write(ExchangeFileName, , Chars.LF);
	
	InformationRegisters.ArchiveOfExchangeMessages.PackMessageToArchive(ExchangeNodeDataImport, ExchangeFileName);
	
	RunDataImport();
	
	DeleteFiles(ExchangeFileName);
	
EndProcedure

#EndRegion

#Region Private

#Region Other

Function InitExchangeMessageDataTable(ObjectType)
	
	ExchangeMessageDataTable = New ValueTable;
	
	Columns = ExchangeMessageDataTable.Columns;
	
	// 
	Columns.Add("UUID", New TypeDescription("String",, New StringQualifiers(36)));
	Columns.Add("TypeAsString",              New TypeDescription("String",, New StringQualifiers(255)));
	
	MetadataObject = Metadata.FindByType(ObjectType);
	
	// Getting a description of all metadata object fields from the configuration.
	ObjectPropertiesDescriptionTable = Common.ObjectPropertiesDetails(MetadataObject, "Name, Type");
	
	For Each PropertyDetails In ObjectPropertiesDescriptionTable Do
		
		Columns.Add(PropertyDetails.Name, PropertyDetails.Type);
		
	EndDo;
	
	ExchangeMessageDataTable.Indexes.Add("UUID");
	
	Return ExchangeMessageDataTable;
	
EndFunction

Function DataProcessorForDataImport()
	
	Return DataImportDataProcessorField;
	
EndFunction

Function IsExchangeOverExternalConnection()
	
	Return DataProcessorForDataImport() <> Undefined;
	
EndFunction

Procedure AfterOpenImportFile(Cancel = False, InitializeRulesTables = True)
	
	DataExchangeXDTOServer.AfterOpenImportFile(ExchangeComponents, Cancel, InitializeRulesTables);
	
EndProcedure

Procedure AfterOpenExportFile(Cancel = False)
	
	If ExchangeComponents.FlagErrors Then
		ExchangeComponents.ExchangeFile = Undefined;
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
		Cancel = True;
		Return;
	EndIf;
	
	If ExchangeComponents.XDTOSettingsOnly Then
		// 
		ExchangeComponents.ExchangeFile.WriteEndElement(); // Message
		ExchangeComponents.ExchangeFile.Close();
		Cancel = True;
		Return;
	EndIf;
	
	ExchangePlanName = "";
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan
		And DataExchangeServer.HasExchangePlanManagerAlgorithm("DataTransferLimitsCheckHandler", ExchangePlanName) Then
		
		ErrorMessage = "";
		
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Peer", ExchangeComponents.CorrespondentNode);
		HandlerParameters.Insert("SupportedXDTOObjects", ExchangeComponents.SupportedXDTOObjects);
		
		ExchangePlans[ExchangePlanName].DataTransferLimitsCheckHandler(Cancel, HandlerParameters, ErrorMessage);
		
		If Cancel Then
			DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorMessage);
			DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
			DataExchangeValuationOfPerformance.ExitApp(ExchangeComponents);
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  DataAnalysisResultToExport - Structure - see details of the DataExchangeServer.DataAnalysisResultToExport
//  InfobaseNode - ExchangePlanRef
// 
Procedure CheckNodesCodes(DataAnalysisResultToExport, InfobaseNode)
	
	If Not DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		
		DataLockItem = DataLock.Add("ExchangePlan." + DataExchangeCached.GetExchangePlanName(InfobaseNode));
		DataLockItem.SetValue("Ref", InfobaseNode);
		
		DataLockItem = DataLock.Add("InformationRegister.PredefinedNodesAliases");
		DataLockItem.SetValue("Peer", InfobaseNode);
		
		DataLock.Lock();

		IBNodeCode = Common.ObjectAttributeValue(InfobaseNode, "Code");
		If ValueIsFilled(DataAnalysisResultToExport.NewFrom) Then
			CorrespondentNodeRecoded = (IBNodeCode = DataAnalysisResultToExport.NewFrom);
			If Not CorrespondentNodeRecoded
				And DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(InfobaseNode) Then
				
				ExchangeNodeObject = InfobaseNode.GetObject();
				
				NewNodeRef = ExchangePlans[InfobaseNode.Metadata().Name].FindByCode(DataAnalysisResultToExport.NewFrom);		
				CreateNewNode = NewNodeRef.IsEmpty();
		
				If CreateNewNode Then				
					
					ExchangeNodeObject.Code = DataAnalysisResultToExport.NewFrom;
					ExchangeNodeObject.DataExchange.Load = True;
					ExchangeNodeObject.Write();
				
					CorrespondentNodeRecoded = True;
					
				Else
					
					ExceptionText = NStr("en = 'Duplicate data synchronization settings are detected.
                                |To fix the error, go to the peer infobase.
                                |Open the ""Data synchronization settings"" form.
								|In the ""More actions"" menu, select ""New predefined node code…"".
								|Select the exchange plan you want to fix.
                                |Read the information on the form and click ""Set new code"".
                                |Then retry the synchronization (or create a new exchange setting).';");
		
					Raise ExceptionText;
		
				EndIf;	
					
			EndIf;
		Else
			CorrespondentNodeRecoded = True;
		EndIf;
		
		If CorrespondentNodeRecoded Then
			PredefinedNodeAlias = DataExchangeServer.PredefinedNodeAlias(InfobaseNode);
			If ValueIsFilled(PredefinedNodeAlias)
				And DataAnalysisResultToExport.CorrespondentSupportsDataExchangeID Then
				// Probably, it's time to delete the record. Check the "To" section.
				ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
				PredefinedNodeCode = DataExchangeServer.PredefinedExchangePlanNodeCode(ExchangePlanName);
				If TrimAll(PredefinedNodeCode) = DataAnalysisResultToExport.To Then
					DataExchangeInternal.DeleteRecordSetFromInformationRegister(
						New Structure("Peer", InfobaseNode),
						"PredefinedNodesAliases");
				EndIf;
			EndIf;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure FormatExtensionsToExchangeComponents(ExchangeComponents)
	
	AvailableFormatExtensions = DataExchangeXDTOServer.AvailableFormatExtensions(ExchangeComponents.ExchangeFormatVersion);
	For Each ExpandingTheExchangeFormat In AvailableFormatExtensions Do
		
		DataExchangeXDTOServer.IncludeNamespace(ExchangeComponents,
			ExpandingTheExchangeFormat.Key,
			ExpandingTheExchangeFormat.Value);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Initialization

Parameters = New Structure;

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf