///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region ExchangeInitialization

// Adds a row to the conversion rule table and initializes the value in the Properties column.
// It is used in the exchange manager module upon filling the table of object conversion rules.
//
// Parameters:
//  ConversionRules - See ConversionRulesCollection1
//
// Returns:
//  ValueTableRow - a row in the conversion rules table.
//
Function InitializeObjectConversionRule(ConversionRules) Export
	
	ConversionRule = ConversionRules.Add();
	ConversionRule.Properties = InitializePropertiesTableForConversionRule();
	Return ConversionRule;
	
EndFunction

// Initializes exchange components.
//
// Parameters:
//  ExchangeDirection - String - an exchange direction: "Sending" | "Receiving".
//
// Returns:
//   Structure - 
//     * ExchangeFormatVersion - String - exchange format version number.
//     * XMLSchema - String - an exchange format namespace.
//     * ExchangeManager - CommonModule - a module with conversion rules.
//     * CorrespondentNode - ExchangePlanRef - a reference to the exchange plan node.
//     * CorrespondentNodeObject - ExchangePlanObject - an exchange plan node object.
//     * ExchangeManagerFormatVersion - String - the number of a module format version with conversion rules.
//     * ExchangeDirection - String - "Sending" or "Receiving".
//     * IsExchangeViaExchangePlan - Boolean - indicates whether the exchange by the exchange plan is completed.
//     * FlagErrors - Boolean - indicates whether an error occurred upon the exchange operation.
//     * ErrorMessageString - String - details of an error occurred upon the exchange operation.
//     * EventLogMessageKey - String - name of an event to write error reports to the event log.
//     * UseHandshake - Boolean - indicates whether the confirmation is used for deleting the change registration.
//     * ExportedObjects - Array of AnyRef - a collection of exported objects.
//     * NotExportedObjects - Array of AnyRef - a collection of non-exported objects.
//     * ExportedByRefObjects - Array of AnyRef - a collection of objects exported "by reference".
//     * DocumentsForDeferredPosting - ValueTable - a collection of deferred posting documents:
//       ** DocumentRef - DocumentRef - document reference.
//       ** DocumentDate - Date - document date.
//     * SupportedXDTOObjects - Array of String - a collection of the format object IDs.
//     * ImportedObjects - ValueTable - a collection of imported objects:
//       ** HandlerName - String - handler name.
//       ** Object - CatalogObject
//                 - DocumentObject - 
//       ** Parameters - Arbitrary - arbitrary parameters.
//       ** ObjectReference - AnyRef - a reference to the imported object.
//     * DataProcessingRules - See DataProcessingRulesTable
//     * DataExchangeState - Structure - exchange state details:
//       ** InfobaseNode - ExchangePlanRef - an exchange plan node.
//       ** ActionOnExchange - EnumRef.ActionsOnExchange - action.
//       ** StartDate - Date - action start date.
//       ** EndDate - Date - action end date.
//       ** ExchangeExecutionResult - EnumRef.ExchangeExecutionResults
//                                    - Undefined - 
//           
//     * PackageHeaderDataTable - See NewDataBatchTitleTable
// 
Function InitializeExchangeComponents(ExchangeDirection) Export
	
	ExchangeComponents = New Structure;
	ExchangeComponents.Insert("ExchangeFormatVersion");
	ExchangeComponents.Insert("XMLSchema");
	ExchangeComponents.Insert("ExchangeManager");
	
	ExchangeComponents.Insert("FormatExtensionSchema");
	ExchangeComponents.Insert("FormatExtensions", New Map);
	
	ExchangeComponents.Insert("CorrespondentNode");
	ExchangeComponents.Insert("CorrespondentNodeObject");
	ExchangeComponents.Insert("ExchangeManagerFormatVersion");
		
	ExchangeComponents.Insert("ExchangeDirection", ExchangeDirection);
	ExchangeComponents.Insert("IsExchangeViaExchangePlan", True);
	ExchangeComponents.Insert("FlagErrors", False);
	ExchangeComponents.Insert("ErrorMessageString", "");
	ExchangeComponents.Insert("EventLogMessageKey", DataExchangeServer.DataExchangeEventLogEvent());
	ExchangeComponents.Insert("UseHandshake", True);
	
	ExchangeComponents.Insert("DataExchangeWithExternalSystem", False);
	ExchangeComponents.Insert("CorrespondentID",  "");
	
	ExchangeComponents.Insert("XDTOSettingsOnly", False);
	// 
	// 
	// 
	// See DataExchangeXDTOServer.FillSupportedXDTOObjects
	ExchangeComponents.Insert("SupportedXDTOObjects", New Array);
	
	DataExchangeState = New Structure;
	DataExchangeState.Insert("InfobaseNode");
	DataExchangeState.Insert("ActionOnExchange");
	DataExchangeState.Insert("StartDate", CurrentSessionDate());
	DataExchangeState.Insert("EndDate");
	DataExchangeState.Insert("ExchangeExecutionResult");
	ExchangeComponents.Insert("DataExchangeState", DataExchangeState);
	
	KeepDataProtocol = New Structure;
	KeepDataProtocol.Insert("DataProtocolFile", Undefined);
	KeepDataProtocol.Insert("OutputInfoMessagesToProtocol", False);
	KeepDataProtocol.Insert("AppendDataToExchangeLog", True);
	
	ExchangeComponents.Insert("KeepDataProtocol", KeepDataProtocol);
	
	ExchangeComponents.Insert("UseTransactions", True);
	
	// 
	// 
	// 
	// 
	ExchangeComponents.Insert("XDTOSettings", SettingsStructureXTDO());
	
	If ExchangeDirection = "Send" Then
		
		ExchangeComponents.Insert("ExportedObjects", New Array);
		ExchangeComponents.Insert("ObjectsToExportCount", 0);
		ExchangeComponents.Insert("ExportedObjectCounter", 0);
		ExchangeComponents.Insert("MapRegistrationOnRequest", New Map);
		ExchangeComponents.Insert("ExportedByRefObjects", New Array);
		
		ExchangeComponents.Insert("ExportScenario");
		
		ExchangeComponents.Insert("ObjectsRegistrationRulesTable");
		ExchangeComponents.Insert("ExchangePlanNodeProperties");
		
		ExchangeComponents.Insert("SkipObjectsWithSchemaCheckErrors", False);
		ExchangeComponents.Insert("NotExportedObjects", New Array);
		
	Else
		
		ExchangeComponents.Insert("IncomingMessageNumber");
		ExchangeComponents.Insert("MessageNumberReceivedByCorrespondent");
		
		ExchangeComponents.Insert("DataImportToInfobaseMode", True);
		ExchangeComponents.Insert("ImportedObjectCounter", 0);
		ExchangeComponents.Insert("ObjectCountPerTransaction", 0);
		ExchangeComponents.Insert("ObjectsToImportCount", 0);
		ExchangeComponents.Insert("ExchangeMessageFileSize", 0);
		
		DocumentsForDeferredPosting = New ValueTable;
		DocumentsForDeferredPosting.Columns.Add("DocumentRef");
		DocumentsForDeferredPosting.Columns.Add("DocumentDate", New TypeDescription("Date"));
		ExchangeComponents.Insert("DocumentsForDeferredPosting", DocumentsForDeferredPosting);
		
		ImportedObjects = New ValueTable;
		ImportedObjects.Columns.Add("HandlerName");
		ImportedObjects.Columns.Add("Object");
		ImportedObjects.Columns.Add("Parameters");
		ImportedObjects.Columns.Add("ObjectReference");
		ImportedObjects.Indexes.Add("ObjectReference");
		ExchangeComponents.Insert("ImportedObjects", ImportedObjects);
		
		ObjectsCreatedByRefsTable = New ValueTable();
		ObjectsCreatedByRefsTable.Columns.Add("ObjectReference");
		ObjectsCreatedByRefsTable.Columns.Add("DeleteObjectsCreatedByKeyProperties");
		ObjectsCreatedByRefsTable.Indexes.Add("ObjectReference");
		ExchangeComponents.Insert("ObjectsCreatedByRefsTable", ObjectsCreatedByRefsTable);
		
		ExchangeComponents.Insert("PackageHeaderDataTable", NewDataBatchTitleTable());
		ExchangeComponents.Insert("DataTablesExchangeMessages", New Map);
		
		ExchangeComponents.Insert("ObjectsForDeferredPosting", New Map);
		
		// 
		ExchangeComponents.Insert("XDTOCorrespondentSettings", SettingsStructureXTDO());
		
		ExchangeComponents.Insert("CorrespondentPrefix");
		
		ExchangeComponents.Insert("DeleteObjectsCreatedByKeyProperties", False);
		ExchangeComponents.Insert("ObjectsMarkedForDeletion",         New Array);
		
	EndIf;
	
	ExchangeComponents.Insert("RunMeasurements", False);
	ExchangeComponents.Insert("ExchangeSession", Undefined);
	ExchangeComponents.Insert("NameOfTemporaryMeasurementFile", "");
	ExchangeComponents.Insert("RecordingMeasurements", Undefined);
	ExchangeComponents.Insert("TableOfMeasurementsByEvents", DataExchangeValuationOfPerformance.TableOfMeasurementsByEvents());
	
	ExchangeComponents.Insert("UseCacheOfPublicIdentifiers", False);
	ExchangeComponents.Insert("CacheOfPublicIdentifiers", Undefined);
	
	ExchangeComponents.Insert("ExchangeViaProcessingUploadUploadED", False);
	
	Return ExchangeComponents;
	
EndFunction

// Initializes value tables with exchange rules and puts them to ExchangeComponents.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//
Procedure InitializeExchangeRulesTables(ExchangeComponents) Export
	
	ExchangeComponents.Insert("BaseFormatSchemas", New Map);
	ExchangeComponents.BaseFormatSchemas.Insert(ExchangeComponents.XMLSchema, True);
	ExchangeComponents.BaseFormatSchemas.Insert(XMLBasicSchema(), True);
	
	// Calculating a version of an exchange manager format. Rules generation depends on it.
	Try
		ExchangeComponents.Insert("ExchangeManagerFormatVersion", ExchangeComponents.ExchangeManager.ExchangeManagerFormatVersion());
	Except
		ExchangeComponents.Insert("ExchangeManagerFormatVersion", "1");
	EndTry;
	
	// 
	ExchangeComponents.Insert("DataProcessingRules",     DataProcessingRulesTable(ExchangeComponents));
	ExchangeComponents.Insert("ObjectsConversionRules", ConversionRulesTable(ExchangeComponents));
	
	ExchangeComponents.Insert("PredefinedDataConversionRules", PredefinedDataConversionRulesTable(ExchangeComponents));
	
	ExchangeComponents.Insert("ConversionParameters_SSLy", ConversionParametersStructure(ExchangeComponents.ExchangeManager));
	
EndProcedure

// Initializes a value table to store object property conversion rules.
//
// Returns:
//   ValueTable - 
//     * ConfigurationProperty - String
//     * FormatProperty - String
//     * PropertyConversionRule - String
//     * UsesConversionAlgorithm - Boolean
//     * KeyPropertyProcessing - Boolean
//     * SearchPropertyHandler - Boolean
//     * TSName - String
//
Function InitializePropertiesTableForConversionRule() Export
	
	PCRTable = New ValueTable;
	PCRTable.Columns.Add("ConfigurationProperty", New TypeDescription("String"));
	PCRTable.Columns.Add("FormatProperty",      New TypeDescription("String"));
	
	PCRTable.Columns.Add("PropertyConversionRule",      New TypeDescription("String",,New StringQualifiers(100)));
	PCRTable.Columns.Add("UsesConversionAlgorithm", New TypeDescription("Boolean"));
	
	PCRTable.Columns.Add("KeyPropertyProcessing",  New TypeDescription("Boolean"));
	PCRTable.Columns.Add("SearchPropertyHandler", New TypeDescription("Boolean"));
	
	PCRTable.Columns.Add("TSName", New TypeDescription("String"));
	
	PCRTable.Columns.Add("Namespace", New TypeDescription("String"));
	
	PCRTable.Indexes.Add("Namespace");

	Return PCRTable;
	
EndFunction

// Fills in a column with the tabular section properties with a blank value table with the certain columns.
// Used in the current module and exchange manager module upon filling the object conversion rules table.
//
// Parameters:
//  ConversionRule - ValueTableRow - an object conversion rule.
//  ColumnName - String - a name of a conversion rule table column being filled in.
//
Procedure InitializeTabularSectionsProperties(ConversionRule, ColumnName = "TabularSectionsProperties") Export
	TabularSectionsProperties = New ValueTable;
	TabularSectionsProperties.Columns.Add("TSConfigurations",          New TypeDescription("String"));
	TabularSectionsProperties.Columns.Add("FormatTS",               New TypeDescription("String"));
	TabularSectionsProperties.Columns.Add("Properties",                New TypeDescription("ValueTable"));
	TabularSectionsProperties.Columns.Add("UsesConversionAlgorithm", New TypeDescription("Boolean"));
	
	TabularSectionsProperties.Columns.Add("Namespace",        New TypeDescription("String"));
	TabularSectionsProperties.Indexes.Add("Namespace");
	
	ConversionRule[ColumnName] = TabularSectionsProperties;
EndProcedure

#EndRegion

#Region KeepProtocol
// Creates an object to write an exchange protocol and puts it in ExchangeComponents.
//
// Parameters:
//  ExchangeComponents        - Structure - contains all exchange rules and parameters.
//  ExchangeProtocolFileName - String - contains a full protocol file name.
//
Procedure InitializeKeepExchangeProtocol(ExchangeComponents, ExchangeProtocolFileName) Export
	
	ExchangeComponents.KeepDataProtocol.DataProtocolFile = Undefined;
	If Not IsBlankString(ExchangeProtocolFileName) Then
		
		// Attempting to write to an exchange protocol file.
		Try
			ExchangeComponents.KeepDataProtocol.DataProtocolFile = New TextWriter(
				ExchangeProtocolFileName,
				TextEncoding.UTF8,
				,
				ExchangeComponents.KeepDataProtocol.AppendDataToExchangeLog);
		Except
			
			MessageString = NStr("en = 'Cannot log to ""%1"". Error details: %2';",
				Common.DefaultLanguageCode());
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
				ExchangeProtocolFileName, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			WriteEventLogDataExchange1(MessageString, ExchangeComponents, EventLogLevel.Warning);
			
		EndTry;
		
	EndIf;
	
EndProcedure

// Finishing writing to the exchange protocol.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//
Procedure FinishKeepExchangeProtocol(ExchangeComponents) Export
	
	If ExchangeComponents.KeepDataProtocol.DataProtocolFile <> Undefined Then
		
		ExchangeComponents.KeepDataProtocol.DataProtocolFile.Close();
		ExchangeComponents.KeepDataProtocol.DataProtocolFile = Undefined;
		
	EndIf;
	
EndProcedure

// Writes to a protocol or displays messages of the specified structure.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ErrorCode        - Number
//                   - String
//                   - Structure - 
//                       See DataExchangeCached.СообщенияОбОшибках().
//                       
//                       
//                         * BriefErrorDescription - 
//                         * DetailErrorDescription - 
//                         * Level - EventLogLevel - Error severity level.
//  RecordStructure   - Structure - protocol record structure.
//  SetErrorFlag1 - Boolean - if true, then it is an error message. Setting ErrorFlag.
//  Level           - Number - a left indent, a number of tabs.
//  Align      - Number - an indent in the text to align the text displayed as Key - Value.
//  UnconditionalWriteToExchangeProtocol - Boolean - indicates that the information is written to the protocol unconditionally.
//
// Returns:
//  String - 
//
Function WriteToExecutionProtocol(ExchangeComponents,
		ErrorCode = "",
		RecordStructure = Undefined,
		SetErrorFlag1 = True,
		Level = 0,
		Align = 22,
		UnconditionalWriteToExchangeProtocol = False) Export
	
	DataProtocolFile = ExchangeComponents.KeepDataProtocol.DataProtocolFile;
	OutputInfoMessagesToProtocol = ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol;
	
	Indent = "";
	For Cnt = 0 To Level - 1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	BriefErrorDescription   = "";
	DetailErrorDescription = "";
	
	If TypeOf(ErrorCode) = Type("Number") Then
		
		ErrorsMessages = DataExchangeCached.ErrorsMessages();
		
		BriefErrorDescription   = ErrorsMessages[ErrorCode];
		DetailErrorDescription = ErrorsMessages[ErrorCode];
		
	ElsIf TypeOf(ErrorCode) = Type("Structure") Then
		
		ErrorCode.Property("BriefErrorDescription",   BriefErrorDescription);
		ErrorCode.Property("DetailErrorDescription", DetailErrorDescription);
		
	Else
		
		BriefErrorDescription   = ErrorCode;
		DetailErrorDescription = ErrorCode;
		
	EndIf;

	BriefErrorDescription   = Indent + String(BriefErrorDescription);
	DetailErrorDescription = Indent + String(DetailErrorDescription);
	
	If RecordStructure <> Undefined Then
		
		For Each Field In RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			
			BriefErrorDescription  = BriefErrorDescription + Chars.LF + Indent + Chars.Tab
				+ StringFunctionsClientServer.SupplementString(Field.Key, Align, " ", "Right") + " =  " + String(Value);
			DetailErrorDescription  = DetailErrorDescription + Chars.LF + Indent + Chars.Tab
				+ StringFunctionsClientServer.SupplementString(Field.Key, Align, " ", "Right") + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	ExchangeComponents.ErrorMessageString = BriefErrorDescription;
	
	If SetErrorFlag1 Then
		
		ExchangeComponents.FlagErrors = True;
		If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Undefined Then
			ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		EndIf;
		
	EndIf;
	
	If DataProtocolFile <> Undefined Then
		
		If SetErrorFlag1 Then
			
			DataProtocolFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag1
			Or UnconditionalWriteToExchangeProtocol
			Or OutputInfoMessagesToProtocol Then
			
			DataProtocolFile.WriteLine(Chars.LF + ExchangeComponents.ErrorMessageString);
		
		EndIf;
		
	EndIf;
	
	ELLevel = Undefined;
	If Not TypeOf(ErrorCode) = Type("Structure")
		Or Not ErrorCode.Property("Level", ELLevel)
		Or ELLevel = Undefined Then
		
		If ExchangeExecutionResultError(ExchangeComponents.DataExchangeState.ExchangeExecutionResult) Then
			ELLevel = EventLogLevel.Error;
		ElsIf ExchangeExecutionResultWarning(ExchangeComponents.DataExchangeState.ExchangeExecutionResult) Then
			ELLevel = EventLogLevel.Warning;
		Else
			ELLevel = EventLogLevel.Information;
		EndIf;
		
	EndIf;
	
	RefPosition = StrFind(DetailErrorDescription, "e1cib/data/");
	If RefPosition > 0 Then
		UIDPosition = StrFind(DetailErrorDescription, "?ref=");
		RefRow = Mid(DetailErrorDescription, RefPosition, UIDPosition - RefPosition + 37);
		FirstPoint = StrFind(RefRow, "e1cib/data/");
		SecondPoint = StrFind(RefRow, "?ref=");
		TypePresentation = Mid(RefRow, FirstPoint + 11, SecondPoint - FirstPoint - 11);
		ValueTemplate = ValueToStringInternal(PredefinedValue(TypePresentation + ".EmptyRef"));
		RefValue = StrReplace(ValueTemplate, "00000000000000000000000000000000", Mid(RefRow, SecondPoint + 5));
		ObjectReference = ValueFromStringInternal(RefValue);
	Else
		ObjectReference = Undefined;
	EndIf;
	
	// Registering an event in the event log.
	WriteEventLogDataExchange1(
		DetailErrorDescription,
		ExchangeComponents,
		ELLevel,
		ObjectReference);
	
	Return ExchangeComponents.ErrorMessageString;
	
EndFunction

#EndRegion

#Region ExchangeRulesSearch
// Searches for an object conversion rule by name.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  Name              - String - a rule name.
//
// Returns:
//  ValueTableRow - 
//
Function OCRByName(ExchangeComponents, Name) Export
	
	ConversionRule = ExchangeComponents.ObjectsConversionRules.Find(Name, "OCRName");
	
	If ConversionRule = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Object conversion rule ""%1"" is not found.';"), Name);
			
	Else
		Return ConversionRule;
	EndIf;

EndFunction

#EndRegion

#Region DataSending

// Exports data according to exchange rules and parameters.
//
// Parameters:
//  ExchangeComponents - See InitializeExchangeComponents
//
Procedure ExecuteDataExport(ExchangeComponents) Export
	
	NodeForExchange = ExchangeComponents.CorrespondentNode;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		ClearErrorsListOnExportData(NodeForExchange);
	EndIf;
	
	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeComponents.ExchangeManager.BeforeConvert(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, "BeforeConvert", "", ExchangeComponents, 
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Direction: %1.
			|Handler: %2.
			|
			|Handler execution error.
			|%3.';");
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"BeforeConvert",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Raise ErrorText;
			
	EndTry;
	
	SentNo = 0;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
	
		SentNo = Common.ObjectAttributeValue(NodeForExchange, "SentNo") + 1;
		
		ExecuteRegisteredDataExport(ExchangeComponents, SentNo);
		
	Else
		
		For Each String In ExchangeComponents.ExportScenario Do
			ProcessingRule = DPRByName(ExchangeComponents, String.DPRName);
			
			DataSelection = DataSelection(ExchangeComponents, ProcessingRule);
			For Each SelectionObject1 In DataSelection Do
				ExportSelectionObject(ExchangeComponents, SelectionObject1, ProcessingRule);
			EndDo;
		EndDo;
		
	EndIf;
	
	If ExchangeComponents.FlagErrors Then
		
		// 
		// 
		If ExchangeComponents.ExportedByRefObjects.Count() > 0 Then
			
			InformationRegisters.ObjectsDataToRegisterInExchanges.DeleteInformationAboutUploadingObjects(ExchangeComponents.ExportedByRefObjects, ExchangeComponents.CorrespondentNode);
			
		EndIf;
		
		Raise NStr("en = 'Errors generating data exchange message. For details, see Event log.';");
		
	EndIf;
	
	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeComponents.ExchangeManager.AfterConvert(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, "AfterConvert", "",ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|
				|Handler execution error.
				|%3.';");
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"AfterConvert",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		Raise ErrorText;
		
	EndTry;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		
		// Resetting the sent message number for non-exported objects.
		If ExchangeComponents.SkipObjectsWithSchemaCheckErrors Then
			For Each ObjectRef In ExchangeComponents.NotExportedObjects Do
				ExchangePlans.RecordChanges(NodeForExchange, ObjectRef);
			EndDo;
		EndIf;
		
		// Setting the sent message number for objects exported by reference.
		If ExchangeComponents.ExportedByRefObjects.Count() > 0 Then
			// Registering the selected exported by reference objects on the current node.
			For Each Item In ExchangeComponents.ExportedByRefObjects Do
				ExchangePlans.RecordChanges(NodeForExchange, Item);
			EndDo;
			
			DataExchangeServer.SelectChanges(NodeForExchange, SentNo, ExchangeComponents.ExportedByRefObjects);
		EndIf;
		
		BeginTransaction();
		Try
		    Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(NodeForExchange));
		    LockItem.SetValue("Ref", NodeForExchange);
		    Block.Lock();
		    
			LockDataForEdit(NodeForExchange);
			Recipient = NodeForExchange.GetObject();
			
			Recipient.SentNo = SentNo;
			Recipient.DataExchange.Load = True;

			Recipient.Write();

			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Body
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Message
	
	// Recording successful exchange completion.
	If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Undefined Then
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed2;
	EndIf;
	
	If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed2
		And (ExchangeComponents.SkipObjectsWithSchemaCheckErrors
			And ExchangeComponents.NotExportedObjects.Count() > 0) Then
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
	EndIf;
	
EndProcedure

// Exports an infobase object.
//
// Parameters:
//   ExchangeComponents - See DataExchangeXDTOServer.InitializeExchangeComponents
//   Object           - AnyRef - a reference to an infobase object.
//   ProcessingRule - ValueTableRow - a row of the table of data processing rules 
//                      matching the processing rule of the object type being exported.
//                      If the parameter is not specified, the rule is found by the object of metadata of an object being exported.
//
Procedure ExportSelectionObject(ExchangeComponents, Object, ProcessingRule = Undefined) Export
	
	ReferenceTypeObject = (TypeOf(Object) <> Type("Structure"))
		And Common.IsRefTypeObject(Object.Metadata());
		
	If (TypeOf(Object) <> Type("Structure"))
		And ProcessingRule = Undefined Then
		GetProcessingRuleForObject(ExchangeComponents, Object, ProcessingRule);
	EndIf;
	
	ExchangeComponents.ExportedObjects.Add(?(ReferenceTypeObject, Object.Ref, Object));
	
	// Process DPR.
	UsageOCR = New Structure;
	For Each CurrentOCR In ProcessingRule.OCRUsed Do
		UsageOCR.Insert(CurrentOCR, True);
	EndDo;
	
	AbortProcessing = False;
	SetErrorFlag = False;
	
	OnProcessDPR(
		ExchangeComponents,
		ProcessingRule,
		Object,
		UsageOCR,
		AbortProcessing);
	
	If AbortProcessing Then
		SetErrorFlag = True;
	EndIf;
	
	If Not AbortProcessing Then
		// Process OCR.
		SeveralOCR = (UsageOCR.Count() > 1);
		HasDataCleanupColumn = ExchangeComponents.DataProcessingRules.Columns.Find("DataClearing") <> Undefined;
		
		For Each CurrentOCR In UsageOCR Do
			ConversionRule = ExchangeComponents.ObjectsConversionRules.Find(CurrentOCR.Key, "OCRName");
			If ConversionRule = Undefined Then
				// An OCR not intended for the current data format  version can be specified.
				Continue;
			EndIf;
			
			If Not FormatObjectPassesXDTOFilter(ExchangeComponents, ConversionRule.FormatObject) Then
				Continue;
			EndIf;
			
			If Not CurrentOCR.Value Then
				// 
				// 
				If SeveralOCR
					And ReferenceTypeObject 
					And (Not HasDataCleanupColumn
						Or ProcessingRule.DataClearing) Then
					ExportDeletion(ExchangeComponents, Object.Ref, ConversionRule);
				EndIf;
				Continue;
			EndIf;
			
			SkipProcessing = False;
			Try
				// 2. Convert Data to Structure by conversion rules.
				BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
				
				XDTOData = XDTODataFromIBData(ExchangeComponents, Object, ConversionRule, Undefined);
				
				Event = "XDTODataFromIBData" + ConversionRule.OCRName;
				DataExchangeValuationOfPerformance.FinishMeasurement(
					BeginTime, Event, Object, ExchangeComponents,
					DataExchangeValuationOfPerformance.EventTypeLibrary());
				
				If XDTOData = Undefined Then
					Continue;
				EndIf;
				
				// 
				BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
				
				RefsFromObject = New Array;
				XDTODataObject = XDTODataObjectFromXDTOData(ExchangeComponents, XDTOData, ConversionRule.XDTOType, RefsFromObject, , ConversionRule.Extensions);
				
				Event = "XDTODataObjectFromXDTOData" + ConversionRule.OCRName;
				DataExchangeValuationOfPerformance.FinishMeasurement(
					BeginTime, Event, Object, ExchangeComponents, 
					DataExchangeValuationOfPerformance.EventTypeLibrary());
				
			Except
				SkipProcessing = True;
				SetErrorFlag   = True;
				
				ErrorDescription = OCRErrorDescription(
					ExchangeComponents.ExchangeDirection,
					ProcessingRule.Name,
					ConversionRule.OCRName,
					ObjectPresentationForProtocol(Object, ConversionRule.DataObject),
					ErrorInfo());
					
				RecordIssueOnProcessObject(ExchangeComponents,
					Object,
					Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData,
					ErrorDescription.DetailedPresentation,
					ErrorDescription.BriefPresentation);
			EndTry;
				
			If Not SkipProcessing Then
				CheckBySchemaError = False;
				CheckBySchemaErrorDescription = Undefined;
				
				Context = New Structure;
				Context.Insert("ExchangeDirection",    ExchangeComponents.ExchangeDirection);
				Context.Insert("DPRName",               ProcessingRule.Name);
				Context.Insert("OCRName",               ConversionRule.OCRName);
				Context.Insert("ObjectPresentation", ObjectPresentationForProtocol(Object, ConversionRule.DataObject));
				
				CheckXDTOObjectBySchema(XDTODataObject, ConversionRule.XDTOType, Context, CheckBySchemaError, CheckBySchemaErrorDescription);
				
				If CheckBySchemaError Then
					SkipProcessing = True;
					
					RecordIssueOnProcessObject(ExchangeComponents,
						Object,
						Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError,
						CheckBySchemaErrorDescription.DetailedPresentation,
						CheckBySchemaErrorDescription.BriefPresentation);
				EndIf;
			EndIf;
		
			If SkipProcessing Then
				AbortProcessing = True;
				Continue;
			EndIf;
			
			ExportObjectsByRef(ExchangeComponents, RefsFromObject);
			
			// 4. Записываем ОбъектXDTO в XML-file.
			XDTOFactory.WriteXML(ExchangeComponents.ExchangeFile, XDTODataObject);
		EndDo;
	EndIf;
	
	If AbortProcessing Then
		ExchangeComponents.NotExportedObjects.Add(?(ReferenceTypeObject, Object.Ref, Object));
	EndIf;
	
	If SetErrorFlag Then
		ExchangeComponents.FlagErrors = True;
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
	EndIf;
	
EndProcedure

// Converts a structure with data to an XDTO object of the specified type according to the rules.
//
// Parameters:
//   ExchangeComponents - Structure - contains all exchange rules and parameters.
//   Source         - Structure - a source of data to convert into XDTO object.
//   XDTOType          - String - an object type or an XDTO value type, to which the data is to be converted.
//   RefsFromObject  - Array of AnyRef - contains a general list of objects exported by references.
//   PropertiesAreFilled - Boolean - a parameter to define fullness of common composite properties.
//   Extensions       - Structure - for internal use.
//
// Returns:
//   XDTODataObject -  
// 
Function XDTODataObjectFromXDTOData(ExchangeComponents, Val Source, Val XDTOType, 
		RefsFromObject = Undefined, PropertiesAreFilled = False, Val Extensions = Undefined) Export
	
	If RefsFromObject = Undefined Then
		RefsFromObject = New Array;
	EndIf;
	
	Receiver = XDTOFactory.Create(XDTOType);
	
	SourceProperties = New Array;
	For Each Property In XDTOType.Properties Do
		SourceProperties.Add(Property);
	EndDo;
	
	NestedExtensions = New Map;
	NestedExtensions.Insert("ExtensionsOfKeyProperties", Undefined);
	NestedExtensions.Insert("ExtensionsOfTableParts", Undefined);
	
	AddPackagePropertiesFromExtensions(SourceProperties, ExchangeComponents, Extensions, NestedExtensions);
	
	For Each Property In SourceProperties Do
		
		Extensions = Undefined;
		IsBaseSchema = IsBaseSchema(ExchangeComponents, Property.NamespaceURI);
		
		PropertyValue = Undefined;
		PropertyFound = False;
		
		NameOfSourceProperty = BroadcastName(Property.Name, "en", Source);
		
		If TypeOf(Source) = Type("Structure") Then
			PropertyFound = Source.Property(NameOfSourceProperty, PropertyValue);
		ElsIf TypeOf(Source) = Type("ValueTableRow")
			And Source.Owner().Columns.Find(NameOfSourceProperty) <> Undefined Then
			PropertyFound = True;
			PropertyValue = Source[NameOfSourceProperty];
		EndIf;
		
		If TypeOf(PropertyValue) = Type("Structure") Then
			
			PropertyValue.Property("Extensions", Extensions);
			
		EndIf;
		
		PropertyType1 = Undefined;
		If TypeOf(Property.Type) = Type("XDTOValueType") Then
			PropertyType1 = "RegularProperty";
		ElsIf TypeOf(Property.Type) = Type("XDTOObjectType") Then
			
			If Property.Name = "AdditionalInfo" Then
				PropertyType1 = "AdditionalInfo";
			ElsIf IsObjectTable(Property) Then
				PropertyType1 = "Table";
			ElsIf Property.Name = ClassKeyFormatProperties()
				Or StrFind(Property.Type.Name, ClassKeyFormatProperties()) > 0 Then
				PropertyType1 = ClassKeyFormatProperties();
			Else
				If PropertyFound Then
					If TypeOf(PropertyValue) = Type("Structure") 
						And (PropertyValue.Property("Value")
							Or StrFind(Property.Type, CommonPropertiesClass()) > 0) Then
						PropertyType1 = "CommonCompositeProperty";
					Else
						PropertyType1 = "FlexibleTypeProperty";
					EndIf;
				Else
					PropertyType1 = "CommonCompositeProperty";
				EndIf;
			EndIf;
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Property <%1> has unknown type. Object type: %2';"),
				Property.Name,
				String(XDTOType));
		EndIf;
		
		Try
			If PropertyType1 = "CommonCompositeProperty" Then
				
				NestedPropertiesAreFilled = False;
				If TypeOf(Source) = Type("Structure") And PropertyFound Then
					XDTODataValue = XDTODataObjectFromXDTOData(ExchangeComponents, PropertyValue, 
						Property.Type, RefsFromObject, NestedPropertiesAreFilled, Extensions);
				Else
					XDTODataValue = XDTODataObjectFromXDTOData(ExchangeComponents, Source, 
						Property.Type, RefsFromObject, NestedPropertiesAreFilled, Extensions);
				EndIf;
				
				If Not NestedPropertiesAreFilled Then
					Continue;
				EndIf;
				
			Else
				
				If Not PropertyFound Then
					Continue;
				EndIf;
				
				// Value input validation.
				If PropertyValue = Null
					Or Not ValueIsFilled(PropertyValue) Then
					
					If Property.Nillable Then
						Receiver[Property.Name] = Undefined;
					EndIf;
					
					Continue;
					
				EndIf;
				
				XDTODataValue = Undefined;
				If PropertyType1 = ClassKeyFormatProperties() Then
					
					KeyPropertyExtension = InstallKeyPropertyExtension(NestedExtensions, Property.Type.Name);
					XDTODataValue = XDTODataObjectFromXDTOData(ExchangeComponents, PropertyValue, Property.Type, RefsFromObject, , KeyPropertyExtension);
					
				ElsIf PropertyType1 = "RegularProperty" Then
					
					PropertyValueType = Property.Type; // XDTOValueType
					
					If IsXDTORef(PropertyValueType) Then // Convert a reference.
						
						XDTODataValue = ConvertRefToXDTO(ExchangeComponents, PropertyValue, PropertyValueType);
						
						If RefsFromObject.Find(PropertyValue) = Undefined Then
							RefsFromObject.Add(PropertyValue);
						EndIf;
						
					ElsIf PropertyValueType.Facets <> Undefined
						And PropertyValueType.Facets.Enumerations <> Undefined
						And PropertyValueType.Facets.Enumerations.Count() > 0 Then // 
						XDTODataValue = ConvertEnumToXDTO(ExchangeComponents, PropertyValue, PropertyValueType);
					Else // 
						XDTODataValue = XDTOFactory.Create(PropertyValueType, PropertyValue);
					EndIf;
					
				ElsIf PropertyType1 = "AdditionalInfo" Then
					XDTODataValue = XDTOSerializer.WriteXDTO(PropertyValue);
					
				ElsIf PropertyType1 = "Table" Then
					
					XDTODataValue = XDTOFactory.Create(Property.Type);
					TableType = Property.Type.Properties[0].Type;
					StringPropertyName = Property.Type.Properties[0].Name;
					XDTOList = XDTODataValue[StringPropertyName]; // XDTOList
					ExpandingTabularPart = SetExtensionOfTablePartRow(NestedExtensions, Property.Name);
					
					For Each StringSource In PropertyValue Do
						
						DestinationString = XDTODataObjectFromXDTOData(ExchangeComponents, StringSource, TableType, RefsFromObject, False, ExpandingTabularPart);
						XDTOList.Add(DestinationString);
						
					EndDo;
					
				ElsIf PropertyType1 = "FlexibleTypeProperty" Then
					
					For Each FlexibleTypeProperty In Property.Type.Properties Do
						
						CompoundXDTOValue = Undefined;
						If TypeOf(PropertyValue) = Type("Structure")
							And PropertyValue.CompositePropertyType = FlexibleTypeProperty.Type Then
							
							// 
							CompoundXDTOValue = XDTODataObjectFromXDTOData(ExchangeComponents, PropertyValue, FlexibleTypeProperty.Type, RefsFromObject, , Extensions);
						// Simple composite type property and simple value.
						ElsIf (TypeOf(PropertyValue) = Type("String")
							And StrFind(FlexibleTypeProperty.Type.Name,"string")>0)
							Or (TypeOf(PropertyValue) = Type("Number")
							And StrFind(FlexibleTypeProperty.Type.Name,"decimal")>0)
							Or (TypeOf(PropertyValue) = Type("Boolean")
							And StrFind(FlexibleTypeProperty.Type.Name,"boolean")>0)
							Or (TypeOf(PropertyValue) = Type("Date")
							And StrFind(FlexibleTypeProperty.Type.Name,"date")>0) Then
							
							CompoundXDTOValue = PropertyValue;
							
						ElsIf TypeOf(PropertyValue) = Type("String")
							And TypeOf(FlexibleTypeProperty.Type) = Type("XDTOValueType")
							And FlexibleTypeProperty.Type.Facets <> Undefined Then
							If FlexibleTypeProperty.Type.Facets.Count() = 0 Then
								CompoundXDTOValue = PropertyValue;
							Else
								
								For Each Facet In FlexibleTypeProperty.Type.Facets Do
									If Facet.Value = PropertyValue Then
										CompoundXDTOValue = PropertyValue;
										Break;
									EndIf;
								EndDo;
								
							EndIf;
						EndIf;
						
						If CompoundXDTOValue <> Undefined Then
							Break;
						EndIf;
						
					EndDo;
					
					// If a value of the type not supported in the format is passed, do not pass.
					If CompoundXDTOValue = Undefined Then
						Continue;
					EndIf;
					
					XDTODataValue = XDTOFactory.Create(Property.Type);
					XDTODataValue.Set(FlexibleTypeProperty, CompoundXDTOValue);
				EndIf;
				
			EndIf;
		Except
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'XDTO object generation error. Property type: %1. Property name: %2.
				|
				|%3';"),
				PropertyType1,
				Property.Name,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If IsBaseSchema Or Property.NamespaceURI = Receiver.Type().NamespaceURI Then
			Receiver[Property.Name] = XDTODataValue;
		Else
			AppendXDTOObject(Receiver, Property, XDTODataValue);
		EndIf;

		PropertiesAreFilled = True;
		
	EndDo;
	
	Return Receiver;
EndFunction

// Converts infobase data into the structure with data according to rules.
//
// Parameters:
//   ExchangeComponents    - See InitializeExchangeComponents
//   Source            - AnyRef - a reference to an infobase object being exported.
//   ConversionRule  - ValueTableRow - a row of table of object conversion rules 
//                         according to which the conversion is carried out.
//   ExportStack        - Array of AnyRef - references to the objects being exported depending on nesting.
//
// Returns:
//   Structure - 
//
Function XDTODataFromIBData(ExchangeComponents, Source, Val ConversionRule, ExportStack = Undefined) Export
	
	Receiver = New Structure;
	
	If ExportStack = Undefined Then
		ExportStack = New Array;
	EndIf;
	
	If ConversionRule.IsReferenceType Then
		
		PositionInStack = ExportStack.Find(Source.Ref);
		
		// Checking whether the object is exported by reference to avoid looping.
		If PositionInStack <> Undefined Then
			
			If PositionInStack > 0 Then
				Return Undefined;
			ElsIf ExportStack.Count() > 1 Then
				// Search by iterating.
				FirstIteration = True;
				For Each StackItem In ExportStack Do
					If FirstIteration Then
						FirstIteration = False;
						Continue;
					EndIf;
					If StackItem = Source.Ref Then
						Return Undefined;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		ExportStack.Add(Source.Ref);
		
		If Not Common.RefExists(Source.Ref) Then
			Return Undefined;
		EndIf;
		
	Else
		ExportStack.Add(Source);
	EndIf;
	
	If ConversionRule.IsConstant Then
		
		ObjectType = ConversionRule.XDTOType; // XDTOObjectType
		
		If ObjectType.Properties.Count() = 1 Then
			
			Receiver.Insert(ObjectType.Properties[0].Name, Source.Value);
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'XML schema error. The destination object must have only one type.
				|Source type: %1
				|Destination type: %2';"),
				String(TypeOf(Source)),
				ConversionRule.XDTOType);
		EndIf;
		
	Else
		
		// PCR Execution, stage 1
		For Each PCR In ConversionRule.Properties Do
			
			If ConversionRule.DataObject <> Undefined
				And PCR.ConfigurationProperty = ""
				And PCR.UsesConversionAlgorithm Then
				Continue;
			EndIf;
			
			If ExportStack.Count() > 1 And Not PCR.KeyPropertyProcessing Then
				Continue;
			EndIf;
			
			ExportProperty(
				ExchangeComponents,
				Source,
				Receiver,
				PCR,
				ExportStack,
				1);
		EndDo;
		
		// PCR execution for tabular sections (direct conversion).
		If ExportStack.Count() = 1 Then
			For Each TSAndProperties In ConversionRule.TabularSectionsProperties Do
				If Not (ValueIsFilled(TSAndProperties.TSConfigurations) And ValueIsFilled(TSAndProperties.FormatTS)) Then
					Continue;
				EndIf;
				// Empty table.
				If Source[TSAndProperties.TSConfigurations].Count() = 0 Then
					Continue;
				EndIf;
				NewDestinationTS = CreateDestinationTSByPCR(TSAndProperties.Properties);
				For Each ConfigurationTSRow In Source[TSAndProperties.TSConfigurations] Do
					DestinationTSRow = NewDestinationTS.Add();
					For Each PCR In TSAndProperties.Properties Do
						If PCR.UsesConversionAlgorithm Then
							Continue;
						EndIf;
						ExportProperty(
							ExchangeComponents,
							ConfigurationTSRow,
							DestinationTSRow,
							PCR,
							ExportStack,
							1);
					EndDo;
				EndDo;
				Receiver.Insert(TSAndProperties.FormatTS, NewDestinationTS);
			EndDo;
		EndIf;
		
		// {Handler: OnSendData} Start
		If ConversionRule.HasHandlerOnSendData Then
			
			If Not Receiver.Property(KeyPropertiesClass()) Then
				Receiver.Insert(KeyPropertiesClass(), New Structure);
			EndIf;
			
			OnSendData(Source, Receiver, ConversionRule.OnSendData, ExchangeComponents, ExportStack);
			
			If Receiver = Undefined Then
				Return Undefined;
			EndIf;
			
			If ExportStack.Count() > 1 Then
				For Each KeyProperty In Receiver[KeyPropertiesClass()] Do
					Receiver.Insert(KeyProperty.Key, KeyProperty.Value);
				EndDo;
				Receiver.Delete(KeyPropertiesClass());
			EndIf;
			
			// PCR Execution, stage 2
			For Each PCR In ConversionRule.Properties Do
				If PCR.FormatProperty = "" 
					Or (ExportStack.Count() > 1 And Not PCR.KeyPropertyProcessing) Then
					Continue;
				EndIf;
				
				// Carrying out conversion if an instruction is included in the property.
				PropertyValue = Undefined;
				If ExportStack.Count() = 1 And PCR.KeyPropertyProcessing Then
					Receiver[KeyPropertiesClass()].Property(PCR.FormatProperty, PropertyValue);
				Else
					FormatPropertyName = TrimAll(PCR.FormatProperty);
					NestedProperties = StrSplit(FormatPropertyName,".",False);
					// A full property name is specified. The property is included in the common properties group.
					If NestedProperties.Count() > 1 Then
						GetNestedPropertiesValue(Receiver, NestedProperties, PropertyValue);
					Else
						Receiver.Property(FormatPropertyName, PropertyValue);
					EndIf;
				EndIf;
				If PropertyValue = Undefined Then
					Continue;
				EndIf;
				
				If PCR.UsesConversionAlgorithm Then
					
					If TypeOf(PropertyValue) = Type("Structure")
						And PropertyValue.Property("Value")
						And PropertyValue.Property("OCRName")
						Or PCR.PropertyConversionRule <> ""
						And TypeOf(PropertyValue) <> Type("Structure") Then
						
						ExportProperty(
							ExchangeComponents,
							Source,
							Receiver,
							PCR,
							ExportStack,
							2);
							
					EndIf;
						
				EndIf;
			EndDo;
			
			// Carrying out PCR for a tabular section
			If ExportStack.Count() = 1 Then
				
				// Generating a structure of new tabular sections by PCR.
				DestinationTSProperties = New Structure;
				For Each TSAndProperties In ConversionRule.TabularSectionsProperties Do
					
					DestinationTSName = TSAndProperties.FormatTS;
					
					If IsBlankString(DestinationTSName) Then
						Continue;
					EndIf;
					
					If Not DestinationTSProperties.Property(DestinationTSName) Then
						PCRTable = New ValueTable;
						PCRTable.Columns.Add("FormatProperty", New TypeDescription("String"));
						
						DestinationTSProperties.Insert(DestinationTSName, PCRTable);
					EndIf;
					
					PCRTable = DestinationTSProperties[DestinationTSName];
					For Each PCR In TSAndProperties.Properties Do
						RowProperty = PCRTable.Add();
						RowProperty.FormatProperty = PCR.FormatProperty;
					EndDo;
					
				EndDo;
				
				For Each TSAndProperties In ConversionRule.TabularSectionsProperties Do
					
					If Not TSAndProperties.UsesConversionAlgorithm Then
						Continue;
					EndIf;
					
					PCRForTS = TSAndProperties.Properties;
					DestinationTSName = TSAndProperties.FormatTS;
					
					DestinationTS = Undefined; // ValueTable
					If Not ValueIsFilled(DestinationTSName)
						Or Not Receiver.Property(DestinationTSName, DestinationTS) Then
						Continue;
					EndIf;
					
					// 
					NewDestinationTS = CreateDestinationTSByPCR(DestinationTSProperties[DestinationTSName]);
					
					// Removing excess columns that could be added to the destination.
					ColumnsToDelete = New Array;
					For Each Column In DestinationTS.Columns Do
						If NewDestinationTS.Columns.Find(Column.Name) = Undefined Then
							ColumnsToDelete.Add(Column);
						EndIf;
					EndDo;
					For Each Column In ColumnsToDelete Do
						DestinationTS.Columns.Delete(Column);
					EndDo;
					
					// Copying data to a new destination table.
					For Each DestinationTSRow1 In DestinationTS Do
						NewDestinationTSRow = NewDestinationTS.Add();
						FillPropertyValues(NewDestinationTSRow, DestinationTSRow1);
					EndDo;
					Receiver[DestinationTSName] = NewDestinationTS;
					
					For Each String In NewDestinationTS Do
						
						For Each PCR In PCRForTS Do
							
							If Not PCR.UsesConversionAlgorithm Then
								Continue;
							EndIf;
							
							ExportProperty(
								ExchangeComponents,
								Source,
								String,
								PCR,
								ExportStack,
								2);
								
						EndDo;
						
					EndDo;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		// {Handler: OnSendData} End
		
		If ExportStack.Count() > 1 Then
			Receiver.Insert("CompositePropertyType", ConversionRule.KeyPropertiesTypeOfXDTOObject);
			
			If IsBaseSchema(ExchangeComponents, ConversionRule.Namespace) And ConversionRule.Extensions.Count() Then
				For Each Extension In ConversionRule.Extensions Do
					If Extension.Value.KeyPropertiesTypeOfXDTOObject <> Undefined Then
						ExtensionData(Receiver, Extension.Key).Insert("CompositePropertyType",
							Extension.Value.KeyPropertiesTypeOfXDTOObject);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndIf;
	
	Return Receiver;
	
EndFunction

// Exports an infobase object property according to the rules.
//
// Parameters:
//  ExchangeComponents   - Structure - contains all exchange rules and parameters.
//  IBData           - AnyRef - a reference to an infobase object being exported.
//  PropertyRecipient - Structure - a recipient of data of the Structure type, in which the exported property value is to be stored.
//                     - ValueTableRow
//  PCR                - ValueTableRow - a row of the table of property conversion rules according to which
//                                               the conversion is carried out.
//  ExportStack       - Array of AnyRef - references to the objects being exported depending on nesting.
//  ExportStage       - Number - contains information about the export stage:
//     1 - exporting before OnSendData algorithm execution, 
//     2 - exporting before OnSendData algorithm execution.
//
Procedure ExportProperty(ExchangeComponents, IBData, PropertyRecipient, PCR, ExportStack, ExportStage = 1) Export
	// Format property is not specified. The current PCR is used only for export.
	If TrimAll(PCR.FormatProperty) = "" Then
		Return;
	EndIf;
	
	FormatPropertyName = TrimAll(PCR.FormatProperty);
	NestedProperties = StrSplit(FormatPropertyName,".",False);
	// A full property name is specified. The property is included in the common properties group.
	FullPropertyNameSpecified = False;
	If NestedProperties.Count() > 1 Then
		FullPropertyNameSpecified = True;
		FormatPropertyName = NestedProperties[NestedProperties.Count()-1];
	EndIf;
	
	PropertyValue = Undefined;
	If ExportStage = 1 Then
		If ValueIsFilled(PCR.ConfigurationProperty) Then
			PropertyValue = IBData[PCR.ConfigurationProperty];
		ElsIf TypeOf(IBData) = Type("Structure") Then
			// This PCR from OCR with a structure source.
			If FullPropertyNameSpecified Then
				GetNestedPropertiesValue(IBData, NestedProperties, PropertyValue);
			Else
				IBData.Property(FormatPropertyName, PropertyValue);
			EndIf;
			If PropertyValue = Undefined Then
				Return;
			EndIf;
		EndIf;
	Else
		
		If TypeOf(PropertyRecipient) = Type("ValueTableRow") Then
			TSColumns = PropertyRecipient.Owner().Columns;
			MaxLevel1 = NestedProperties.Count() - 1;
			If FullPropertyNameSpecified Then
				For Level = 0 To MaxLevel1 Do
					ColumnName = NestedProperties[Level];
					If TSColumns.Find(ColumnName) = Undefined Then
						Continue;
					EndIf;
					ValueInColumn = PropertyRecipient[ColumnName];
					If Level = MaxLevel1 Then
						PropertyValue = ValueInColumn;
					ElsIf TypeOf(ValueInColumn) = Type("Structure") Then
						// Nested property value is packed to the structure, which can be multilevel.
						NestedPropertySource = ValueInColumn;
						NestedPropertyValue = Undefined;
						For SubordinateLevel = Level + 1 To MaxLevel1 Do
							NestedPropertyName = NestedProperties[SubordinateLevel];
							If Not NestedPropertySource.Property(NestedPropertyName, NestedPropertyValue) Then
								Continue;
							EndIf;
							If SubordinateLevel = MaxLevel1 Then
								PropertyValue = NestedPropertyValue;
							ElsIf TypeOf(NestedPropertyValue) = Type("Structure") Then
								NestedPropertySource = NestedPropertyValue;
								NestedPropertyValue = Undefined;
							Else
								Break;
							EndIf;
						EndDo;
					EndIf;
				EndDo;
			Else
				If TSColumns.Find(FormatPropertyName) = Undefined Then
					Return;
				Else
					PropertyValue = PropertyRecipient[FormatPropertyName];
				EndIf;
			EndIf;
		Else
			If FullPropertyNameSpecified Then
				GetNestedPropertiesValue(IBData, NestedProperties, PropertyValue);
			Else
				PropertyRecipient.Property(FormatPropertyName, PropertyValue);
			EndIf;
			If PropertyValue = Undefined
				And Not (ExportStack.Count() = 1 And PropertyRecipient[KeyPropertiesClass()].Property(FormatPropertyName, PropertyValue)) Then
				Return;
			EndIf;
		EndIf;
		
	EndIf;
		
	PropertyConversionRule = PCR.PropertyConversionRule;
	
	// The value can be in the instruction format.
	If TypeOf(PropertyValue) = Type("Structure") Then
		If PropertyValue.Property("OCRName") Then
			PropertyConversionRule = PropertyValue.OCRName;
		EndIf;
		If PropertyValue.Property("Value") Then
			PropertyValue = PropertyValue.Value;
		EndIf;
	EndIf;
	
	If ValueIsFilled(PropertyValue) Then
	
		If TrimAll(PropertyConversionRule) <> "" Then
			
			PDCR = ExchangeComponents.PredefinedDataConversionRules.Find(PropertyConversionRule, "PDCRName");
			If PDCR <> Undefined Then
				
				If TypeOf(PropertyValue) = Type("String") Then
					Return;
				EndIf;
				
				PropertyValue = PDCR.ConvertValuesOnSend.Get(PropertyValue);
			
			Else
			
				ConversionRule = OCRByName(ExchangeComponents, PropertyConversionRule);
				
				ExportStackBranch = New Array;
				For Each Item In ExportStack Do
					ExportStackBranch.Add(Item);
				EndDo;
				
				PropertyValue = XDTODataFromIBData(
					ExchangeComponents,
					PropertyValue,
					ConversionRule,
					ExportStackBranch);
					
			EndIf;
			
		EndIf;
		
	Else
		PropertyValue = Undefined;
	EndIf;
	
	If ExportStack.Count() = 1 And PCR.KeyPropertyProcessing Then
		If Not PropertyRecipient.Property(KeyPropertiesClass()) Then
			PropertyRecipient.Insert(KeyPropertiesClass(), New Structure);
		EndIf;
		PropertyRecipient[KeyPropertiesClass()].Insert(FormatPropertyName, PropertyValue);
	Else
		If TypeOf(PropertyRecipient) = Type("ValueTableRow") Then
			If FullPropertyNameSpecified Then
				PutNestedPropertiesValue(PropertyRecipient, NestedProperties, PropertyValue, True);
			Else
				PropertyRecipient[FormatPropertyName] = PropertyValue;
			EndIf;
		Else
			If FullPropertyNameSpecified Then
				PutNestedPropertiesValue(PropertyRecipient, NestedProperties, PropertyValue, False);
			Else
				PropertyRecipient.Insert(FormatPropertyName, PropertyValue);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Opens an export data file, writes a file header according to the exchange format.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ExchangeFileName - String - exchange file name.
//
Procedure OpenExportFile(ExchangeComponents, ExchangeFileName = "") Export

	ExchangeFile = New XMLWriter;
	If ExchangeFileName <> "" Then
		ExchangeFile.OpenFile(ExchangeFileName);
	Else
		ExchangeFile.SetString();
	EndIf;
	ExchangeFile.WriteXMLDeclaration();
	
	WriteMessage1 = Undefined;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then

		WriteMessage1 = New Structure("ReceivedNo, MessageNo, Recipient");
		WriteMessage1.Recipient = ExchangeComponents.CorrespondentNode;
		
		If TransactionActive() Then
			Raise NStr("en = 'Cannot apply a data exchange lock to an active transaction.';");
		EndIf;
		
		// Setting a lock to the recipient node.
		Try
			LockDataForEdit(WriteMessage1.Recipient);
		Except
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot lock the data exchange.
				|The data exchange might be running in another session.
				|
				|Details:
				|%1';"),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		RecipientData = Common.ObjectAttributesValues(WriteMessage1.Recipient, "SentNo, ReceivedNo, Code");
		
		WriteMessage1.MessageNo = RecipientData.SentNo + 1;
		WriteMessage1.ReceivedNo = RecipientData.ReceivedNo;
		
	EndIf;
	
	HeaderParameters = ExchangeMessageHeaderParameters();
	
	HeaderParameters.ExchangeFormat                 = ExchangeComponents.XMLSchema;
	HeaderParameters.IsExchangeViaExchangePlan      = ExchangeComponents.IsExchangeViaExchangePlan;
	HeaderParameters.DataExchangeWithExternalSystem = ExchangeComponents.DataExchangeWithExternalSystem;
	HeaderParameters.ExchangeFormatVersion          = ExchangeComponents.ExchangeFormatVersion;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		
		HeaderParameters.CorrespondentNode = ExchangeComponents.CorrespondentNode;
		HeaderParameters.SenderID = DataExchangeServer.NodeIDForExchange(ExchangeComponents.CorrespondentNode);
		
		If Not ExchangeComponents.XDTOSettingsOnly Then
			HeaderParameters.MessageNo = WriteMessage1.MessageNo;
			HeaderParameters.ReceivedNo = WriteMessage1.ReceivedNo;
		EndIf;
		
		HeaderParameters.SupportedVersions  = ExchangeComponents.XDTOSettings.SupportedVersions;
		HeaderParameters.SupportedObjects = ExchangeComponents.XDTOSettings.SupportedObjects;
		
		If Not ExchangeComponents.DataExchangeWithExternalSystem Then
			HeaderParameters.ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
			HeaderParameters.PredefinedNodeAlias = DataExchangeServer.PredefinedNodeAlias(ExchangeComponents.CorrespondentNode);
			
			HeaderParameters.RecipientIdentifier  = DataExchangeServer.CorrespondentNodeIDForExchange(ExchangeComponents.CorrespondentNode);
			
			HeaderParameters.Prefix = DataExchangeServer.InfobasePrefix();
		EndIf;
		
		HeaderParameters.ExchangeViaProcessingUploadUploadED = ExchangeComponents.ExchangeViaProcessingUploadUploadED;
		
	EndIf;
	
	WriteExchangeMessageHeader(ExchangeFile, HeaderParameters);
	
	If Not ExchangeComponents.XDTOSettingsOnly Then
		// 
		ExchangeFile.WriteStartElement("Body");
		
		DeclareNamespaces(ExchangeFile, ExchangeComponents);
	EndIf;
	
	ExchangeComponents.Insert("ExchangeFile", ExchangeFile);
	
EndProcedure

#EndRegion

#Region GetData

// Returns an infobase object matching the received data.
// 
// Parameters:
//   ExchangeComponents - See DataExchangeXDTOServer.InitializeExchangeComponents
//   XDTOData       - Structure - a structure simulating XDTO object.
//
//   ConversionRule - ValueTableRow
//                      - Structure - 
//                        
//                        
//                          * ConversionRule - ValueTableRow - a row of object conversion rule table.
//                                                 Required property.
//                          * DeleteObjectsCreatedByKeyProperties - Boolean - indicates that you need to delete objects
//                                                                  created only by key property values.
//                                                                  Optional, the default value is False.
//
//   Action - String - defines a purpose of the infobase object receiving:
//                       "GetRef" - an object identification,
//                       "ConvertAndWrite" - a full object import.
//
// Returns:
//   - Объект - 
//              
//   - AnyRef - 
//                   
//
Function XDTOObjectStructureToIBData(ExchangeComponents, XDTOData, Val ConversionRule, Action = "ConvertAndWrite") Export
	
	DeleteObjectsCreatedByKeyProperties = ExchangeComponents.DeleteObjectsCreatedByKeyProperties;
	If TypeOf(ConversionRule) = Type("Structure") Then
		If ConversionRule.Property("DeleteObjectsCreatedByKeyProperties") Then
			DeleteObjectsCreatedByKeyProperties = ConversionRule.DeleteObjectsCreatedByKeyProperties;
		EndIf;
		ConversionRule = ConversionRule.ConversionRule;
	EndIf;
	
	IBData = Undefined;
	ReceivedData = InitializeReceivedData(ConversionRule);
	PropertiesComposition = "All";
	ReceivedDataRef = Undefined;
	XDTODataContainRef = XDTOData.Property(LinkClass());
	If ConversionRule.IsReferenceType Then
		ReceivedDataRef = ReceivedData.Ref;
		IdentificationOption = TrimAll(ConversionRule.IdentificationOption);
		If XDTODataContainRef
			And (IdentificationOption = "ByUUID"
				Or IdentificationOption = "FirstByUUIDThenBySearchFields") Then
			
			OriginalUIDIsString = XDTOData[LinkClass()].Value;
			
			ReceivedDataRef = ObjectRefByXDTODataObjectUUID(
				OriginalUIDIsString,
				ConversionRule.DataType,
				ExchangeComponents);
				
			ReceivedData.SetNewObjectRef(ReceivedDataRef);
			
			IBData = ReceivedDataRef.GetObject();
			
			If Action = "GetRef" Then
				
				If IBData <> Undefined Then
					// 
					// 
					// 
					WritePublicIDIfNecessary(
						IBData,
						ReceivedDataRef,
						XDTOData[LinkClass()].Value,
						ConversionRule,
						ExchangeComponents);
						
					Return IBData.Ref;
				ElsIf IdentificationOption = "ByUUID" Then
					// Задача: получение ссылки.
					// 
					// 
					
					Return ReceivedDataRef;
				EndIf;
				
			EndIf;
		Else
			ReceivedDataRef = ConversionRule.ObjectManager.GetRef(New UUID());
			ReceivedData.SetNewObjectRef(ReceivedDataRef);
		EndIf;
		// 
		PropertiesComposition = ?(Action = "GetRef" And DeleteObjectsCreatedByKeyProperties, "SearchProperties", "All");
	EndIf;
	
	// Converting properties not requiring the handler execution.
	ConversionOfXDTOObjectStructureProperties(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		1,
		PropertiesComposition);
		
	If Action = "GetRef" Then
		XDTOData = New Structure(KeyPropertiesClass(),
			Common.CopyRecursive(XDTOData));
	EndIf;
	
	OnConvertXDTOData(
		XDTOData,
		ReceivedData,
		ExchangeComponents,
		ConversionRule.OnConvertXDTOData);
		
	If Action = "GetRef" Then
		XDTOData = Common.CopyRecursive(XDTOData[KeyPropertiesClass()]);
	EndIf;
		
	ConversionOfXDTOObjectStructureProperties(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		2,
		PropertiesComposition);
		
	// As a result of property conversion, the object could be written if there is a circular reference.
	If ReceivedDataRef <> Undefined And Common.RefExists(ReceivedDataRef) Then
		IBData = ReceivedDataRef.GetObject();
	EndIf;
	
	If IBData = Undefined Then
		If ConversionRule.IsRegister Then
			// 
			IBData = Undefined;
		ElsIf IdentificationOption = "BySearchFields"
			Or IdentificationOption = "FirstByUUIDThenBySearchFields" Then
			
			IBData = ObjectRefByXDTOObjectProperties(
				ConversionRule,
				ReceivedData,
				XDTODataContainRef,
				ExchangeComponents,
				OriginalUIDIsString);
			If Not ValueIsFilled(IBData) Then
				IBData = Undefined;
			EndIf;
			
			// 
			// 
			If ConversionRule.HasHandlerSearchAlgorithm Then
				SearchAlgorithm(
					IBData,
					ReceivedData,
					ExchangeComponents,
					ConversionRule.SearchAlgorithm);
			EndIf;
			
			If IBData <> Undefined And ConversionRule.IsReferenceType Then
				If Action = "GetRef" Then
					// 
					// 
					// 
					If XDTODataContainRef Then
						WritePublicIDIfNecessary(
							IBData.GetObject(),
							IBData,
							XDTOData[LinkClass()].Value,
							ConversionRule,
							ExchangeComponents);
					EndIf;
					
					Return IBData;
				Else
					IBData = IBData.GetObject();
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	WriteObjectToIB1 = ?(Action = "ConvertAndWrite", True, False);
	
	If ExchangeComponents.DataImportToInfobaseMode
		And (IdentificationOption = "BySearchFields"
			Or IdentificationOption = "FirstByUUIDThenBySearchFields") Then
		// 
		// 
		WriteObjectToIB1 = True;
	EndIf;
	
	If WriteObjectToIB1 Then
		
		IsFullObjectImport = Action = "ConvertAndWrite"
			Or ConversionRule.AllowCreateObjectFromStructure
			Or (Action = "GetRef"
				And Not DeleteObjectsCreatedByKeyProperties
				And IBData = Undefined);
			
		If IsFullObjectImport
			And ConversionRule.HasHandlerBeforeWriteReceivedData Then
			
			// Full object import, deleting a temporary object.
			If IBData <> Undefined Then
				ObjectString = ExchangeComponents.ObjectsCreatedByRefsTable.Find(IBData.Ref, "ObjectReference");
				If ObjectString <> Undefined Then
					DataExchangeServer.SetDataExchangeLoad(IBData, True, False, ExchangeComponents.CorrespondentNode);
					DeleteObject(IBData, True, ExchangeComponents);
					IBData = Undefined;
					ReceivedData.SetNewObjectRef(ObjectString.ObjectReference);
				EndIf;
			EndIf;
			
			BeforeWriteReceivedData(
				ReceivedData,
				IBData,
				ExchangeComponents,
				ConversionRule.BeforeWriteReceivedData,
				ConversionRule.Properties);
			
		EndIf;
		
		If IBData = Undefined Then
			DataToWriteToIB = ReceivedData;
		Else
			If ReceivedData <> Undefined Then
				FillIBDataByReceivedData(IBData, ReceivedData, ConversionRule);
			EndIf;
			DataToWriteToIB = IBData;
		EndIf;
		
		If DataToWriteToIB = Undefined Then
			Return Undefined;
		EndIf;
		
		If ExchangeComponents.IsExchangeViaExchangePlan
			And ConversionRule.IsReferenceType
			And XDTODataContainRef Then
			
			WritePublicIDIfNecessary(
				IBData,
				?(DataToWriteToIB.IsNew(), DataToWriteToIB.GetNewObjectRef(), DataToWriteToIB.Ref),
				XDTOData[LinkClass()].Value,
				ConversionRule,
				ExchangeComponents);
				
		EndIf;
		
		If ConversionRule.IsReferenceType And IsFullObjectImport Then
			ExecuteNumberCodeGenerationIfNecessary(DataToWriteToIB);
		EndIf;
		
		If DeleteObjectsCreatedByKeyProperties Then
			DataToWriteToIB.AdditionalProperties.Insert("DeleteObjectsCreatedByKeyProperties");
		EndIf;
		
		If ExchangeComponents.IsExchangeViaExchangePlan And Not ConversionRule.IsRegister Then
			ItemReceive = DataItemReceive.Auto;
			SendBack = False;
			StandardSubsystemsServer.OnReceiveDataFromMaster(
				DataToWriteToIB, ItemReceive, SendBack, ExchangeComponents.CorrespondentNodeObject);
			DataToWriteToIB.AdditionalProperties.Insert("DataItemReceive", ItemReceive);
			
			If ItemReceive = DataItemReceive.Ignore Then
				Return DataToWriteToIB;
			EndIf;
		EndIf;
		
		If ConversionRule.IsReferenceType And DataToWriteToIB.DeletionMark Then
			DataToWriteToIB.DeletionMark = False;
		EndIf;
		
		If ConversionRule.IsDocument Then
			
			Try
				
				If ConversionRule.DocumentCanBePosted Then
				
					If DataToWriteToIB.Posted Then
						
						DataToWriteToIB.Posted = False;
						If Not DataToWriteToIB.IsNew()
							And Common.ObjectAttributeValue(DataToWriteToIB.Ref, "Posted") Then
							// Writing a new document version with posting cancellation.
							
							Result = UndoObjectPostingInIB(DataToWriteToIB, 
								ExchangeComponents.CorrespondentNode, ExchangeComponents);
							
						Else
							// Writing a new document version.
							WriteObjectToIB(ExchangeComponents, DataToWriteToIB, ConversionRule.DataType);
							If DataToWriteToIB = Undefined Then
								Return Undefined;
							EndIf;
						EndIf;
						
						TableRow = ExchangeComponents.DocumentsForDeferredPosting.Add();
						TableRow.DocumentRef = DataToWriteToIB.Ref;
						TableRow.DocumentDate  = DataToWriteToIB.Date;
						
					Else
						If DataToWriteToIB.IsNew() Then
							WriteObjectToIB(ExchangeComponents, DataToWriteToIB, ConversionRule.DataType);
							If DataToWriteToIB = Undefined Then
								Return Undefined;
							EndIf;
						Else
							
							UndoObjectPostingInIB(DataToWriteToIB, 
								ExchangeComponents.CorrespondentNode, ExchangeComponents);
						
						EndIf;
					EndIf;
					
				Else
					WriteObjectToIB(ExchangeComponents, DataToWriteToIB, ConversionRule.DataType);
					If DataToWriteToIB = Undefined Then
						Return Undefined;
					EndIf;
				EndIf;
				
			Except
				WriteToExecutionProtocol(ExchangeComponents, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		Else
			
			WriteObjectToIB(ExchangeComponents, DataToWriteToIB, ConversionRule.DataType);
			If DataToWriteToIB = Undefined Then
				Return Undefined;
			EndIf;
			If ConversionRule.IsReferenceType Then
				ExchangeComponents.ObjectsForDeferredPosting.Insert(
					DataToWriteToIB.Ref, 
					DataToWriteToIB.AdditionalProperties);
			EndIf;
		EndIf;
		
		RememberObjectForDeferredFilling(DataToWriteToIB, ConversionRule, ExchangeComponents);
		
	Else
		
		DataToWriteToIB = ReceivedData;
		
	EndIf;
	
	If ConversionRule.IsReferenceType Then
		// 
		//  
		// 
		// 
		// 
		ObjectsCreatedByRefsTable = ExchangeComponents.ObjectsCreatedByRefsTable;
			
		If Action = "GetRef"
			And WriteObjectToIB1
			And Not ConversionRule.AllowCreateObjectFromStructure Then
			
			ObjectString = ObjectsCreatedByRefsTable.Find(DataToWriteToIB.Ref, "ObjectReference");
			
			If ObjectString = Undefined Then
				NewRow = ObjectsCreatedByRefsTable.Add();
				NewRow.ObjectReference = DataToWriteToIB.Ref;
				NewRow.DeleteObjectsCreatedByKeyProperties = DeleteObjectsCreatedByKeyProperties;
			Else
				If Not DeleteObjectsCreatedByKeyProperties Then
					ObjectString.DeleteObjectsCreatedByKeyProperties = False;
				EndIf;
			EndIf;
			
		ElsIf Action = "ConvertAndWrite" Then
			
			ObjectString = ObjectsCreatedByRefsTable.Find(DataToWriteToIB.Ref, "ObjectReference");
			
			If ObjectString <> Undefined Then
				ObjectsCreatedByRefsTable.Delete(ObjectString);
			EndIf;
			
		EndIf;
	EndIf;
	
	Return DataToWriteToIB;
	
EndFunction

// Reads a data file upon import.
//
// Parameters:
//  ExchangeComponents - See InitializeExchangeComponents
//  TablesToImport - ValueTable - a table to import data to (upon interactive data mapping).
//
Procedure RunReadingData(ExchangeComponents, TablesToImport = Undefined) Export
	
	ExchangeComponents.ObjectsCreatedByRefsTable.Clear();
	
	If TypeOf(TablesToImport) = Type("ValueTable")
		And TablesToImport.Count() = 0 Then
		Return;
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan
		And ExchangeComponents.CorrespondentNodeObject = Undefined Then
		ExchangeComponents.CorrespondentNodeObject = ExchangeComponents.CorrespondentNode.GetObject();
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		ClearErrorsListOnDataImport(ExchangeComponents.CorrespondentNode);
	EndIf;
	
	Results = Undefined;
	ReadExchangeMessage(ExchangeComponents, Results, TablesToImport);
	
	If Not ExchangeComponents.FlagErrors
		And ExchangeComponents.DataImportToInfobaseMode Then
		
		DataExchangeInternal.DisableAccessKeysUpdate(True);
		Try
			ApplyObjectsDeletion(ExchangeComponents, Results.ArrayOfObjectsToDelete, Results.ArrayOfImportedObjects);
			DeleteTempObjectsCreatedByRefs(ExchangeComponents);
			DeferredObjectsFilling(ExchangeComponents);
		
			DataExchangeInternal.DisableAccessKeysUpdate(False);
		Except
			DataExchangeInternal.DisableAccessKeysUpdate(False);
			Raise;
		EndTry;
		
		ExchangeComponents.ObjectsMarkedForDeletion = Common.CopyRecursive(Results.ArrayOfObjectsToDelete);
		
		If Not ExchangeComponents.FlagErrors Then
			Try
				ExchangeComponents.ExchangeManager.AfterConvert(ExchangeComponents);
			Except
				
				ErrorDescriptionTemplate = NStr("en = 'Direction: %1.
					|Handler: %2.
					|
					|Handler execution error.
					|%3.';");
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
					ExchangeComponents.ExchangeDirection,
					"AfterConvert",
					ErrorProcessing.DetailErrorDescription(ErrorInfo())); 
				
				Raise ErrorText;
				
			EndTry;
				
			DataExchangeInternal.DisableAccessKeysUpdate(True);
			Try
				ExecuteDeferredDocumentsPosting(ExchangeComponents);
				DataExchangeServer.ExecuteDeferredObjectsWrite(
					ExchangeComponents.ObjectsForDeferredPosting, ExchangeComponents.CorrespondentNode, ExchangeComponents);
				
				DataExchangeInternal.DisableAccessKeysUpdate(False);	
			Except
				DataExchangeInternal.DisableAccessKeysUpdate(False);	
				Raise;
			EndTry;
				
		EndIf;
	EndIf;
	
	// Recording successful exchange completion.
	If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Undefined Then
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed2;
	EndIf;
	
EndProcedure

// Reads a data file upon import in the analysis mode (upon interactive data synchronization).
//
// Parameters:
//  ExchangeComponents - See InitializeExchangeComponents
//  AnalysisParameters - Structure - parameters of interactive data import.
//
Procedure ReadDataInAnalysisMode(ExchangeComponents, AnalysisParameters = Undefined) Export
	
	Results = Undefined;
	ReadExchangeMessage(ExchangeComponents, Results, , True);
	
	ApplyObjectsDeletion(ExchangeComponents, Results.ArrayOfObjectsToDelete, Results.ArrayOfImportedObjects);
	
EndProcedure

// Opens a data import file, writes a file header according to the exchange format.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ExchangeFileName - String - exchange file name.
//
Procedure OpenImportFile(ExchangeComponents, ExchangeFileName) Export
	
	IsExchangeViaExchangePlan = ExchangeComponents.IsExchangeViaExchangePlan;
	
	XMLReader = New XMLReader;
	
	ExchangeComponents.FlagErrors = True;
	
	StopCycle = False;
	While Not StopCycle Do
		StopCycle = True;
		
		Try
			XMLReader.OpenFile(ExchangeFileName);
			ExchangeComponents.Insert("ExchangeFile", XMLReader);
		Except
			ErrorMessageString = NStr("en = 'Data import error: %1';");
			ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteToExecutionProtocol(ExchangeComponents, ErrorMessageString);
			Break;
		EndTry;
		
		FillInCacheOfPublicIdentifiers(ExchangeComponents, ExchangeFileName, XMLReader);
		
		XMLReader.Read(); // Message
		If (XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.LocalName <> "Message") Then
			If MessageFromNotUpdatedSetting(XMLReader) Then
				ErrorMessageString = NStr("en = 'Getting data from a source where data synchronization settings
					|are not updated. You need to:
					|1) For the Internet transport type:
					|	- Repeat data synchronization later.
					|2) For the other transport types:
					|	- Synchronize data on the source side.
					|	 Then repeat data synchronization in this infobase.';");
				WriteToExecutionProtocol(ExchangeComponents, ErrorMessageString);
			Else
				WriteToExecutionProtocol(ExchangeComponents, 9);
			EndIf;
			Break;
		EndIf;
		
		XMLReader.Read(); // Header
		If XMLReader.NodeType <> XMLNodeType.StartElement
			Or XMLReader.LocalName <> "Header" Then
			WriteToExecutionProtocol(ExchangeComponents, 9);
			Break;
		EndIf;
		
		TitleXDTOMessages = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(XMLBasicSchema(), "Header"));
		
		StructureFormat = StrSplit(TitleXDTOMessages.Format, " ", False);
		
		FormatURI = StructureFormat[0];
		
		URIExtensions = "";
		If StructureFormat.Count() > 1 Then
			URIExtensions = StructureFormat[StructureFormat.UBound()];
		EndIf;
		
		If IsExchangeViaExchangePlan Then
			
			If Not TitleXDTOMessages.IsSet("Confirmation") Then
				WriteToExecutionProtocol(ExchangeComponents, 9);
				Break;
			EndIf;
			
			XDTOConfirmation = TitleXDTOMessages.Confirmation;
			
			ExchangePlanName = FindNameOfExchangePlanThroughUniversalFormat(ExchangeComponents, XDTOConfirmation); 
			If Not ValueIsFilled(ExchangePlanName) Then
				WriteToExecutionProtocol(ExchangeComponents, 177);
				Break;
			EndIf;
			
			ExchangePlanFormat = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeFormat");
			
			ExchangeComponents.XDTOSettingsOnly =
				Not DataExchangeServer.SynchronizationSetupCompleted(ExchangeComponents.CorrespondentNode)
					Or (FormatURI = ExchangePlanFormat);
			
			If XDTOConfirmation.MessageNo <> Undefined Then		
				ExchangeComponents.IncomingMessageNumber = XDTOConfirmation.MessageNo;
			Else
				ExchangeComponents.IncomingMessageNumber = 0;
			EndIf;
			If XDTOConfirmation.ReceivedNo <> Undefined Then
				ExchangeComponents.MessageNumberReceivedByCorrespondent = XDTOConfirmation.ReceivedNo;
			Else
				ExchangeComponents.MessageNumberReceivedByCorrespondent = 0;
			EndIf;
			
			FromWhomCode = XDTOConfirmation.From;
			ToWhomCode   = XDTOConfirmation.To;
			
			If Not ExchangeComponents.XDTOSettingsOnly Then
				ExchangeComponents.XMLSchema = FormatURI;
				
				IncludeNamespace(ExchangeComponents, URIExtensions, "ext");
				
				ExchangeFormat = ParseExchangeFormat(ExchangeComponents.XMLSchema);
				
				// Check the basic format.
				If ExchangePlanFormat <> ExchangeFormat.BasicFormat Then
					MessageString = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The exchange message format ""%1"" does not match the exchange plan format ""%2.""';"),
						ExchangeFormat.BasicFormat,
						ExchangePlanFormat);
					WriteToExecutionProtocol(ExchangeComponents, MessageString);
					Break;
				EndIf;
				
				// Checking a version of the exchange message format.
				If ExhangeFormatVersionsArray(ExchangeComponents.CorrespondentNode).Find(ExchangeFormat.Version) = Undefined Then
					MessageString = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Version %1 of exchange message format ""%2"" is not supported.';"),
						ExchangeFormat.Version, ExchangeFormat.BasicFormat);
					WriteToExecutionProtocol(ExchangeComponents, MessageString);
					Break;
				EndIf;
				
				ExchangeComponents.ExchangeFormatVersion = ExchangeFormat.Version;
				ExchangeComponents.ExchangeManager      = FormatVersionExchangeManager(ExchangeComponents.ExchangeFormatVersion,
					ExchangeComponents.CorrespondentNode);
					
				If ExchangeComponents.IncomingMessageNumber <= 0 Then
					ExchangeComponents.UseHandshake = False;
				EndIf;
					
				If Not ExchangeComponents.DataExchangeWithExternalSystem Then
					
					NewFromWhomCode = "";
					If TitleXDTOMessages.IsSet("NewFrom") Then
						NewFromWhomCode = TitleXDTOMessages.NewFrom;
					EndIf;
					
					RecipientFromMessage = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, ToWhomCode);
					If RecipientFromMessage <> ExchangePlans[ExchangePlanName].ThisNode() Then
						// Probably, a virtual code of the recipient is set.
						PredefinedNodeAlias = DataExchangeServer.PredefinedNodeAlias(ExchangeComponents.CorrespondentNode);
						If PredefinedNodeAlias <> ToWhomCode Then
							WriteToExecutionProtocol(ExchangeComponents, 178);
							Break;
						EndIf;
					EndIf;
					
					SenderFromMessage = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, FromWhomCode);
					If (SenderFromMessage = Undefined
							Or SenderFromMessage <> ExchangeComponents.CorrespondentNode)
						And ValueIsFilled(NewFromWhomCode) Then
						SenderFromMessage = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NewFromWhomCode);
					EndIf;
					
					If SenderFromMessage = Undefined
						Or SenderFromMessage <> ExchangeComponents.CorrespondentNode Then
						
						MessageString = NStr("en = 'Cannot find the exchange node for data import. Exchange plan: %1, ID: %2.';");
						MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangePlanName, FromWhomCode);
						WriteToExecutionProtocol(ExchangeComponents, MessageString);
						Break;
						
					EndIf;
				EndIf;
				
				If ExchangeComponents.UseHandshake Then
					
					ReceivedNo = Common.ObjectAttributeValue(ExchangeComponents.CorrespondentNode, "ReceivedNo");
					
					If ReceivedNo >= ExchangeComponents.IncomingMessageNumber Then
						// 
						ExchangeComponents.DataExchangeState.ExchangeExecutionResult =
							Enums.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted;
							
						WriteToExecutionProtocol(ExchangeComponents, 174,,,,, True);
						ExchangeComponents.XDTOSettingsOnly = True;
					Else
						// Adding public IDs for reference objects whose receiving was reported by the correspondent node.
						AddExportedObjectsToPublicIDsRegister(ExchangeComponents);
						
						// Удаляем регистрацию изменений, о получении которых отчитался узел-correspondent.
						ExchangePlans.DeleteChangeRecords(ExchangeComponents.CorrespondentNode, ExchangeComponents.MessageNumberReceivedByCorrespondent);
						
						// 
						InformationRegisters.CommonInfobasesNodesSettings.ClearInitialDataExportFlag(
							ExchangeComponents.CorrespondentNode, ExchangeComponents.MessageNumberReceivedByCorrespondent);
					EndIf;
					
				EndIf;
					
			EndIf;
			
			If ExchangeComponents.DataExchangeWithExternalSystem Then
				ExchangeComponents.CorrespondentID = FromWhomCode;
			EndIf;
			
			FillCorrespondentXDTOSettingsStructure(ExchangeComponents.XDTOCorrespondentSettings,
				TitleXDTOMessages, Not (FormatURI = ExchangePlanFormat), ExchangeComponents.CorrespondentNode);
				
			If TitleXDTOMessages.IsSet("Prefix") Then
				ExchangeComponents.CorrespondentPrefix = TitleXDTOMessages.Prefix;
			EndIf;
			
			DataExchangeLoopControl.ImportCircuitFromMessage(ExchangeComponents, TitleXDTOMessages);
			
			// 
			ExchangeComponents.Insert("CorrespondentSupportsDataExchangeID",
				VersionSupported(ExchangeComponents.XDTOCorrespondentSettings.SupportedVersions, VersionNumberWithDataExchangeIDSupport()));
				
		Else
				
			ExchangeComponents.XMLSchema = FormatURI;
			IncludeNamespace(ExchangeComponents, URIExtensions, "ext");
			
			ExchangeFormat = ParseExchangeFormat(ExchangeComponents.XMLSchema);
			
			ExchangeComponents.ExchangeFormatVersion = ExchangeFormat.Version;
			ExchangeComponents.ExchangeManager      = FormatVersionExchangeManager(ExchangeComponents.ExchangeFormatVersion);
			
		EndIf;
		
		If Not ExchangeComponents.XDTOSettingsOnly Then
			If XMLReader.NodeType <> XMLNodeType.StartElement
				Or XMLReader.LocalName <> "Body" Then
				WriteToExecutionProtocol(ExchangeComponents, 9);
				Break;
			EndIf;
			
			XMLReader.Read(); // Body
		EndIf;
		
		ExchangeComponents.FlagErrors = False;
		
	EndDo;
	
	If ExchangeComponents.FlagErrors Then
		XMLReader.Close();
	Else
		ExchangeComponents.Insert("ExchangeFile", XMLReader);
	EndIf;
	
EndProcedure

// Converts an XDTO object to the data structure.
//
// Parameters:
//  XDTODataObject - XDTODataObject - a value to be converted.
//  ExchangeComponents - See InitializeExchangeComponents
//
// Returns:
//  Structure - 
//    
//    
//
Function XDTODataObjectToStructure(XDTODataObject, ExchangeComponents) Export
	
	If Not NamespaceActive(ExchangeComponents, XDTODataObject.Type().NamespaceURI) Then
		Return Undefined;
	EndIf;
	
	Receiver = New Structure;
	
	For Each Property In XDTODataObject.Properties() Do
		
		ConvertXDTOPropertyToStructureItem(XDTODataObject, Property, Receiver, ExchangeComponents);
		
	EndDo;
	
	KeyPropertiesCopy = Undefined;
	LinkCopy = Undefined;
	If Receiver.Property(ClassKeyFormatProperties(), KeyPropertiesCopy)
		And TypeOf(KeyPropertiesCopy) = Type("Structure")
		And KeyPropertiesCopy.Property(FormatReferenceClass(), LinkCopy)
		Then
		
		Receiver.Insert(FormatReferenceClass(), LinkCopy);
		
	EndIf;
	
	Receiver = BroadcastStructure(Receiver, "en");
	
	Return Receiver;
EndFunction

// Converts a string UUID presentation to a reference to the current infobase object.
// First, the UUID is searched in the public IDs register.
// If search is completed successfully, a reference from the register is returned. Otherwise, 
// either a reference with the initial UUID is returned (if it is not mapped yet),
// or a new reference with a random UUID is generated.
// In both cases, a record is created in the public IDs register.
// 
// Parameters:
//  XDTOObjectUUID       - String - a unique XDTO object ID that requires 
//                                  receiving a reference of the matching infobase object.
//
//  IBObjectValueType - Type - a type of the infobase object, to which the reference to be received
//                               must match.
//
//  ExchangeComponents     - Structure - contains all necessary data initialized upon the
//                                     exchange start (such as OCR, PDCR, DPR, and other).
//
// Returns:
//   AnyRef - link to the information base object.
// 
Function ObjectRefByXDTODataObjectUUID(XDTOObjectUUID, IBObjectValueType, ExchangeComponents) Export
	
	SetPrivilegedMode(True);
	
	// Defining a reference to the object using a public reference.
	PublicRef = FindRefByPublicID(XDTOObjectUUID, ExchangeComponents, IBObjectValueType);
	If PublicRef <> Undefined Then
		// 
		Return PublicRef;
	EndIf;
	
	// Searching for a reference by the initial UUID.
	RefByUUID1 = RefByUUID1(IBObjectValueType, XDTOObjectUUID, ExchangeComponents);
	
	// 
	Return RefByUUID1;
	
EndFunction

// Writes an object to the infobase.
//
// Parameters:
//  ExchangeComponents - Structure - contains all necessary data initialized upon the 
//                exchange start (such as OCR, PDCR, DPR, and other).
//  Object - Arbitrary - CatalogObject, DocumentObject and another object to be written.
//  Type - String - object type as string.
//  WriteObject - Boolean - a variable takes the False value if the object is not written.
//  SendBack - Boolean - a service flag to set the object data exchange parameter.
//  UUIDAsString1 - String - a unique object ID as String.
// 
Procedure WriteObjectToIB(ExchangeComponents, Object, Type, WriteObject = False, Val SendBack = False, UUIDAsString1 = "") Export
	
	BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
	
	If Not WriteObjectAllowed(Object, ExchangeComponents) Then
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Attempt to modify shared data (%1: %2) in the separated mode.';"),
			Object.Metadata().FullName(), String(Object));

		If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Undefined
			Or ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed2 Then
			ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
		EndIf;
		
		ErrorCode = New Structure;
		ErrorCode.Insert("BriefErrorDescription",   ErrorMessageString);
		ErrorCode.Insert("DetailErrorDescription", ErrorMessageString);
		ErrorCode.Insert("Level",                      EventLogLevel.Warning);
		
		WriteToExecutionProtocol(ExchangeComponents, ErrorCode, , False);
		
		Object = Undefined;
		Return;
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		// 
		DataExchangeServer.SetDataExchangeLoad(Object,, SendBack, ExchangeComponents.CorrespondentNode);
	Else
		DataExchangeServer.SetDataExchangeLoad(Object,, SendBack);
	EndIf;
	
	// Checking for a deletion mark of the predefined item.
	RemoveDeletionMarkFromPredefinedItem(Object, Type, ExchangeComponents);
	
	BeginTransaction();
	Try
		
		// 
		Object.Write();
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		
		WriteObject = False;
		
		WP         = ExchangeProtocolRecord(26, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WP.Object  = Object;
		
		If Type <> Undefined Then
			WP.ObjectType = Type;
		EndIf;
		
		WriteToExecutionProtocol(ExchangeComponents, 26, WP);
		
		Raise ExchangeComponents.ErrorMessageString;
		
	EndTry;
	
	Event = "WriteObjectToIB" + Object.Metadata().FullName();
	DataExchangeValuationOfPerformance.FinishMeasurement(
		BeginTime, Event, Object, ExchangeComponents,
		DataExchangeValuationOfPerformance.EventTypeApplied());
	
EndProcedure

// Executes deferred posting of imported documents after importing all data.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//
Procedure ExecuteDeferredDocumentsPosting(ExchangeComponents) Export
	
	DataExchangeServer.ExecuteDeferredDocumentsPosting(
		ExchangeComponents.DocumentsForDeferredPosting,
		ExchangeComponents.CorrespondentNode,
		,
		ExchangeComponents);
	
EndProcedure

// Posts a document upon its import to the infobase.
//
// Parameters:
//  ExchangeComponents                         - Structure - contains all exchange rules and parameters.
//  Object                                   - DocumentObject - a document being imported.
//  RecordIssuesInExchangeResults - Boolean - issues must be registered.
//
Procedure ExecuteDocumentPostingOnImport(
		ExchangeComponents,
		Object,
		RecordIssuesInExchangeResults = True) Export
	
	DataExchangeServer.ExecuteDocumentPostingOnImport(
		ExchangeComponents.CorrespondentNode,
		Object.Ref,
		RecordIssuesInExchangeResults);
	
EndProcedure

// Cancels an infobase object posting.
//
// Parameters:
//  Object      - DocumentObject - a document to cancel posting.
//  Sender - ExchangePlanRef - a reference to the exchange plan node, which is the data sender.
//  ExchangeComponents - See InitializeExchangeComponents
//
// Returns:
//   Boolean - 
//
Function UndoObjectPostingInIB(Object, Sender, ExchangeComponents = Undefined) Export
	
	BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
	
	InformationRegisters.DataExchangeResults.RecordIssueResolved(Object,
		Enums.DataExchangeIssuesTypes.UnpostedDocument);
		
	// 
	Object.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
	//  
	// 
	// 
	If Not Object.AdditionalProperties.Property("DataSynchronizationViaAUniversalFormatDeletingRegisteredRecords") Then
		
		Object.AdditionalProperties.Insert("DataSynchronizationViaAUniversalFormatDeletingRegisteredRecords", True);
		
	EndIf;
	
	DocumentPostingCanceled = False;
	
	BeginTransaction();
	Try
		
		If Object.AdditionalProperties.Property("UseTheCancellationOfThePurificationRegisteredRecords")
			And Object.AdditionalProperties.UseTheCancellationOfThePurificationRegisteredRecords = True Then
			
			DataExchangeServer.SetDataExchangeLoad(Object, False, False, Sender);
			Object.Write(DocumentWriteMode.UndoPosting);
			
			DataExchangeServer.SetDataExchangeLoad(Object, True, False, Sender);
			
		Else
			
			// 
			DataExchangeServer.SetDataExchangeLoad(Object, True, False, Sender);
			
			// 
			Object.Posted = False;
			Object.Write();
			
			DataExchangeServer.DeleteDocumentRegisterRecords(Object);
			
		EndIf;
		
		Object.AdditionalProperties.Delete("DataSynchronizationViaAUniversalFormatDeletingRegisteredRecords");
		
		DocumentPostingCanceled = True;
		CommitTransaction();
	Except
		RollbackTransaction();
	EndTry;
	
	If ExchangeComponents <> Undefined Then
		Event = "UndoObjectPostingInIB" + Object.Metadata().FullName();
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, Event, Object, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeLibrary());
	EndIf;
	
	Return DocumentPostingCanceled;
	
EndFunction

// The procedure fills in the object tabular section according to the previous tabular section version (before importing data).
//
// Parameters:
//  ObjectTabularSectionAfterProcessing - TabularSection - a tabular section containing changed data.
//  ObjectTabularSectionBeforeProcessing    - ValueTable - a value table, object tabular section content before
//                                                          data import.
//  KeyFields                        - String - columns, by which search of rows in the tabular section is performed (a comma-separated
//                                        string).
//  ColumnsToInclude                 - String - other columns (excluding the key ones) with the values to be changed (a comma-separated
//                                        string).
//  ColumnsToExclude1                - String - columns with values not to be changed (comma-separated string).
//
Procedure FillObjectTabularSectionWithInitialData(
	ObjectTabularSectionAfterProcessing, 
	ObjectTabularSectionBeforeProcessing,
	Val KeyFields = "",
	ColumnsToInclude = "", 
	ColumnsToExclude1 = "") Export
	
	If TypeOf(KeyFields) = Type("String") Then
		If KeyFields = "" Then
			Return; // Cannot get mapping of new and old data without key fields.
		Else
			KeyFields = StrSplit(KeyFields, ",");
		EndIf;
	EndIf;
	
	OldAndCurrentTSDataMap = OldAndCurrentTSDataMap(
		ObjectTabularSectionAfterProcessing, 
		ObjectTabularSectionBeforeProcessing,
		KeyFields);
	
	For Each NewTSRow1 In ObjectTabularSectionAfterProcessing Do
		OldTSRow = OldAndCurrentTSDataMap.Get(NewTSRow1);
		If OldTSRow <> Undefined Then
			FillPropertyValues(NewTSRow1, OldTSRow, ColumnsToInclude, ColumnsToExclude1);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

// Returns a table of objects available for exchange of a format for the specified exchange plan.
// The list is generated according to exchange rules from the exchange manager modules by the matching versions.
//
// Parameters:
//  ExchangePlanName - String - an XDTO exchange plan name.
//  Mode          - String - a requested information type: "Sending" | "Receiving" | "SendingReceiving".
//                            "Sending" - all objects, for which sending is supported, will be returned;
//                            "Receiving" - all objects, for which receiving is supported, will be returned;
//                            "SendingReceiving" - all supported objects will be returned.
//                            "SendingReceiving" by default.
//  ExchangeNode     - ExchangePlanRef
//                 - Undefined - exchange plan node corresponding to the correspondent.
//
// Returns:
//  ValueTable - 
//    * Version    - String - a format version. For example "1.5".
//    * Object    - String - a format object name. For example, "Catalog.Products".
//    * Send  - Boolean - shows whether sending of the current format object is supported.
//    * Receive - Boolean - shows whether receiving of the current format object is supported.
//
Function SupportedObjectsInFormat(ExchangePlanName, Mode = "SendReceive", ExchangeNode = Undefined) Export
	ObjectsTable1 = New ValueTable;
	InitializeSupportedFormatObjectsTable(ObjectsTable1, Mode);
	
	ExchangePlanSettings = DataExchangeServer.ExchangePlanSettingValue(
		ExchangePlanName,
		"ExchangeFormatVersions, ExchangeFormatExtensions");
		
	SendingMode  = StrFind(Mode, "Send") > 0;
	ReceiptMode = StrFind(Mode, "Receive") > 0;
	
	For Each Version In ExchangePlanSettings.ExchangeFormatVersions Do
		
		VersionExtensions = New Array;
		For Each Extension In ExchangePlanSettings.ExchangeFormatExtensions Do
			If Extension.Value = Version.Key Then
				VersionExtensions.Add(Extension.Key);
			EndIf;
		EndDo;
		
		If VersionExtensions.Count() = 0 Then
			VersionExtensions.Add("");
		EndIf;
		
		For Each ExtensionSchema In VersionExtensions Do
			If SendingMode Then
				ExchangeComponents = InitializeExchangeComponents("Send");
				
				ExchangeComponents.ExchangeFormatVersion = Version.Key;
				ExchangeComponents.ExchangeManager = Version.Value;
				
				ExchangeComponents.XMLSchema = ExchangeFormat(ExchangePlanName, ExchangeComponents.ExchangeFormatVersion);
				IncludeNamespace(ExchangeComponents, ExtensionSchema, "ext");
				
				InitializeExchangeRulesTables(ExchangeComponents);
				
				FillSupportedFormatObjectsByExchangeComponents(ObjectsTable1, ExchangeComponents);
			EndIf;
			
			If ReceiptMode Then
				ExchangeComponents = InitializeExchangeComponents("Receive");
				
				ExchangeComponents.ExchangeFormatVersion = Version.Key;
				ExchangeComponents.ExchangeManager = Version.Value;
				
				ExchangeComponents.XMLSchema = ExchangeFormat(ExchangePlanName, ExchangeComponents.ExchangeFormatVersion);
				IncludeNamespace(ExchangeComponents, ExtensionSchema, "ext");
				
				InitializeExchangeRulesTables(ExchangeComponents);
				
				FillSupportedFormatObjectsByExchangeComponents(ObjectsTable1, ExchangeComponents);
			EndIf;
		EndDo;		
	EndDo;
	
	HasAlgorithm = DataExchangeServer.HasExchangePlanManagerAlgorithm(
		"OnDefineSupportedFormatObjects", ExchangePlanName);
	If HasAlgorithm Then
		ExchangePlans[ExchangePlanName].OnDefineSupportedFormatObjects(ObjectsTable1, Mode, ExchangeNode);
	EndIf;
	
	Return ObjectsTable1;
	
EndFunction

// Returns a table of format objects available for exchange for the specified correspondent.
//
// Parameters:
//  ExchangeNode - ExchangePlanRef - an XDTO exchange plan node of the specific correspondent.
//  Mode          - String - a requested information type: "Sending" | "Receiving" | "SendingReceiving".
//                            "Sending" - all objects, for which sending is supported, will be returned;
//                            "Receiving" - all objects, for which receiving is supported, will be returned;
//                            "SendingReceiving" - all supported objects will be returned.
//                            "SendingReceiving" by default.
//
// Returns:
//  ValueTable - 
//    * Version    - String - a format version. For example "1.5".
//    * Object    - String - a format object name. For example, "Catalog.Products".
//    * Send  - Boolean - shows whether sending of the current format object is supported by the correspondent.
//    * Receive - Boolean - shows whether receiving of the current format object is supported by the correspondent.
//
Function SupportedCorrespondentFormatObjects(ExchangeNode, Mode = "SendReceive") Export
	
	ObjectsTable1 = New ValueTable;
	InitializeSupportedFormatObjectsTable(ObjectsTable1, Mode);
	
	CorrespondentSettings = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(ExchangeNode, "SupportedObjects");
	
	If Not CorrespondentSettings = Undefined Then
		
		For Each CorrespondentSettingsRow In CorrespondentSettings Do
			
			If (StrFind(Mode, "Send") And CorrespondentSettingsRow.Send)
				Or (StrFind(Mode, "Receive") And CorrespondentSettingsRow.Receive) Then
				RowObjects = ObjectsTable1.Add();
				FillPropertyValues(RowObjects, CorrespondentSettingsRow);
			EndIf;
			
		EndDo;
		
	Else
		
		If Not DataExchangeServer.SynchronizationSetupCompleted(ExchangeNode) Then
			Return ObjectsTable1;
		EndIf;
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		
		DatabaseObjectsTable = SupportedObjectsInFormat(ExchangePlanName,
			"SendReceive", ?(ExchangeNode.IsEmpty(), Undefined, ExchangeNode));
		
		For Each BaseObjectsRow In DatabaseObjectsTable Do
			
			CorrespondentObjectsRow = ObjectsTable1.Add();
			FillPropertyValues(CorrespondentObjectsRow, BaseObjectsRow, "Version, Object");
			
			If StrFind(Mode, "Send") > 0 Then
				CorrespondentObjectsRow.Send = BaseObjectsRow.Receive;
			EndIf;
			If StrFind(Mode, "Receive") > 0 Then
				CorrespondentObjectsRow.Receive = BaseObjectsRow.Send;
			EndIf;
			
		EndDo;		
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
	HasAlgorithm = DataExchangeServer.HasExchangePlanManagerAlgorithm(
		"OnDefineFormatObjectsSupportedByCorrespondent", ExchangePlanName);
	If HasAlgorithm Then
		ExchangePlans[ExchangePlanName].OnDefineFormatObjectsSupportedByCorrespondent(ExchangeNode, ObjectsTable1, Mode);
	EndIf;
	
	ObjectsTable1.Indexes.Add("Object");
	
	Return ObjectsTable1;
	
EndFunction

// Returns skipping mode flag when exporting format objects that have not passed check by schema.
// It can be used to set a new mode value.
//
// Parameters:
//   InfobaseNode - ExchangePlanRef - an exchange plan node matching the correspondent.
//   NewValue - Boolean
//                 - Undefined - 
//                                  
//
// Returns:
//   Boolean - 
//
Function SkipObjectsWithSchemaCheckErrors(InfobaseNode, NewValue = Undefined) Export
	
	Mode = False;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.XDTODataExchangeSettings.CreateRecordManager();
	RecordManager.InfobaseNode = InfobaseNode;
	RecordManager.Read();
	
	If NewValue = Undefined Then
		If RecordManager.Selected() Then
			Mode = RecordManager.SkipObjectsWithSchemaCheckErrors;
		EndIf;
	Else
		RecordManager.SkipObjectsWithSchemaCheckErrors = NewValue;
		RecordManager.Write(True);
		
		Mode = NewValue;
	EndIf;
	
	Return Mode;
	
EndFunction

// Returns the property name that contains the key object properties 
//
// Returns:
//   String - 
//
Function KeyPropertiesClass() Export
	
	Return "KeyProperties";
	
EndFunction 

//  
//
// Returns:
//   String - 
//
Function ClassKeyFormatProperties() Export
	
	Return "КлючевыеСвойства"; // @Non-NLS
	
EndFunction

#EndRegion

#Region Internal

#Region ExchangeInitialization

// Creates a value table to store a data batch title.
//
// Returns:
//  ValueTable - 
//    * ObjectTypeString - String
//    * ObjectCountInSource - Number
//    * SearchFields - String
//    * TableFields - String
//    * SourceTypeString - String
//    * DestinationTypeString - String
//    * SynchronizeByID - Boolean
//    * IsObjectDeletion - Boolean
//    * IsClassifier - Boolean
//    * UsePreview - Boolean
//
Function NewDataBatchTitleTable() Export
	
	PackageHeaderDataTable = New ValueTable;
	Columns = PackageHeaderDataTable.Columns;
	
	Columns.Add("ObjectTypeString",            New TypeDescription("String"));
	Columns.Add("ObjectCountInSource", New TypeDescription("Number"));
	Columns.Add("SearchFields",                   New TypeDescription("String"));
	Columns.Add("TableFields",                  New TypeDescription("String"));
	
	Columns.Add("SourceTypeString", New TypeDescription("String"));
	Columns.Add("DestinationTypeString", New TypeDescription("String"));
	
	Columns.Add("SynchronizeByID", New TypeDescription("Boolean"));
	Columns.Add("IsObjectDeletion", New TypeDescription("Boolean"));
	Columns.Add("IsClassifier", New TypeDescription("Boolean"));
	Columns.Add("UsePreview", New TypeDescription("Boolean"));
	
	Return PackageHeaderDataTable;
	
EndFunction

// Gets object registration rules for the exchange plan.
//
// Returns:
//  ValueTable
//
Function ObjectsRegistrationRules(ExchangePlanNode) Export
	
	ObjectsRegistrationRules = DataExchangeEvents.ExchangePlanObjectsRegistrationRules(
		DataExchangeCached.GetExchangePlanName(ExchangePlanNode)); 
	ObjectsRegistrationRulesTable = ObjectsRegistrationRules.Copy(, "MetadataObjectName3, FlagAttributeName");
	ObjectsRegistrationRulesTable.Indexes.Add("MetadataObjectName3");
	
	Return ObjectsRegistrationRulesTable;
	
EndFunction

// Gets properties of an exchange plan node.
//
// Returns:
//  Структура (ключ соответствует имени свойства, а значение - 
//
Function ExchangePlanNodeProperties(Node) Export
	
	ExchangePlanNodeProperties = New Structure;
	
	// Get attribute names.
	AttributesNames = Common.AttributeNamesByType(Node, Type("EnumRef.ExchangeObjectExportModes"));
	
	// Get attribute values.
	If Not IsBlankString(AttributesNames) Then
		
		ExchangePlanNodeProperties = Common.ObjectAttributesValues(Node, AttributesNames);
		
	EndIf;
	
	Return ExchangePlanNodeProperties;
EndFunction

#EndRegion

#Region GetData

// The function checks whether the exchange message format complies with the EnterpriseData exchange format.
//
// Parameters:
//  XMLReader - XMLReader - an exchange message.
//
// Returns
//  True - the format matches the required format. False - the format does not match the required format.
//
Function CheckExchangeMessageFormat(XMLReader) Export
	
	If (XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Message") Then
		Return False;
	EndIf;
		
	XMLReader.Read(); // Header
	If XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Header" Then
		Return False;
	EndIf;
	
	Try
		TitleXDTOMessages = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(XMLBasicSchema(), "Header"));
	Except
		Return False;
	EndTry;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Body" Then
		Return False;
	EndIf;
	If Not TitleXDTOMessages.IsSet("Confirmation") Then
		Return False;
	EndIf;
	ExchangeComponents = New Structure("DataExchangeWithExternalSystem, CorrespondentNode", False, Undefined);
	XDTOConfirmation = TitleXDTOMessages.Confirmation;
	
	ExchangePlanName = FindNameOfExchangePlanThroughUniversalFormat(ExchangeComponents, XDTOConfirmation);
	If Not ValueIsFilled(ExchangePlanName) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

Procedure AfterOpenImportFile(ExchangeComponents, Cancel, InitializeRulesTables = True) Export
	
	If ExchangeComponents.FlagErrors Then
		FinishKeepExchangeProtocol(ExchangeComponents);
		If ExchangeComponents.Property("ExchangeFile") Then
			ExchangeComponents.ExchangeFile.Close();
		EndIf;
		Cancel = True;
		Return;
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		
		If ExchangeComponents.DataExchangeWithExternalSystem Then
			NodeIDChanged = False;
			InfoMessage  = "";
			
			BeginTransaction();
			Try
				Block = New DataLock;
				LockItem = Block.Add(Common.TableNameByRef(ExchangeComponents.CorrespondentNode));
				LockItem.SetValue("Ref", ExchangeComponents.CorrespondentNode);
				Block.Lock();
				
				CorrespondentNodeCode = TrimAll(Common.ObjectAttributeValue(ExchangeComponents.CorrespondentNode, "Code"));
				If ValueIsFilled(ExchangeComponents.CorrespondentID)
					And Not CorrespondentNodeCode = ExchangeComponents.CorrespondentID Then
					CorrespondentNodeObject = ExchangeComponents.CorrespondentNode.GetObject();
					CorrespondentNodeObject.Code = ExchangeComponents.CorrespondentID;
					CorrespondentNodeObject.DataExchange.Load = True;
					CorrespondentNodeObject.Write();
					
					NodeIDChanged = True;
					
					InfoMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The node ID has been changed from %1 to %2.';"),
						CorrespondentNodeCode,
						ExchangeComponents.CorrespondentID);
				EndIf;
			
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			
			If NodeIDChanged Then
				WriteToExecutionProtocol(ExchangeComponents, InfoMessage, , False, , , True);
			EndIf;
			
		EndIf;
		
		UpdateCorrespondentXDTOSettings(ExchangeComponents);
		RefreshCorrespondentPrefix(ExchangeComponents);
		
		If Not ExchangeComponents.XDTOSettingsOnly
			And InitializeRulesTables Then
			InitializeExchangeRulesTables(ExchangeComponents);
			FillXDTOSettingsStructure(ExchangeComponents);
			FillSupportedXDTOObjects(ExchangeComponents);
		EndIf;
	EndIf;
	
	If ExchangeComponents.XDTOSettingsOnly Then
		If ExchangeComponents.Property("ExchangeFile") Then
			ExchangeComponents.ExchangeFile.Close();
		EndIf;
		Cancel = True;
		Return;
	EndIf;
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
		
		If DataExchangeServer.HasExchangePlanManagerAlgorithm("DefaultValuesCheckHandler", ExchangePlanName) Then
			
			ErrorMessage = "";
			
			HandlerParameters = New Structure;
			HandlerParameters.Insert("Peer", ExchangeComponents.CorrespondentNode);
			HandlerParameters.Insert("SupportedXDTOObjects", ExchangeComponents.SupportedXDTOObjects);
			
			ExchangePlans[ExchangePlanName].DefaultValuesCheckHandler(Cancel, HandlerParameters, ErrorMessage);
			
			If Cancel Then
				WriteToExecutionProtocol(ExchangeComponents, ErrorMessage);
				FinishKeepExchangeProtocol(ExchangeComponents);
				Return;
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ExchangeFormatVersioningProceduresAndFunctions
// Returns a data exchange manager matching the specified exchange format version.
//
// Parameters:
//  FormatVersion - String
//  InfobaseNode - ExchangePlanRef - an exchange plan node, for which you need to get the exchange manager.
//                                              If the exchange via the format is executed without using the exchange plan,
//                                              InfobaseNode is not passed.
//
Function FormatVersionExchangeManager(Val FormatVersion, Val InfobaseNode = Undefined) Export
	
	Result = ExchangeFormatVersions(InfobaseNode).Get(FormatVersion);
	
	If Result = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Conversion manager for exchange format v.%1 is not specified.';"),
			FormatVersion);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a string with the exchange format.
// Exchange format includes: 
//  Basic format provided for the exchange plan.
//  Basic format version.
//
// Parameters:
//  ExchangePlanName - String
//  FormatVersion - String
//
Function ExchangeFormat(Val ExchangePlanName, Val FormatVersion) Export
	
	ExchangeFormat = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeFormat");
	
	If Not IsBlankString(FormatVersion) Then
		ExchangeFormat = ExchangeFormat + "/" + FormatVersion;
	EndIf;
	
	Return ExchangeFormat;
	
EndFunction

// Returns a string with a number of the exchange format version supported by the data recipient.
//
// Parameters:
//  Recipient - 
//
Function ExchangeFormatVersionOnImport(Val Recipient) Export
	
	Result = Common.ObjectAttributeValue(Recipient, "ExchangeFormatVersion");
	If Not ValueIsFilled(Result) Then
		
		// 
		Result = MinExchangeFormatVersion(Recipient);
		
	EndIf;
	
	Return TrimAll(Result);
EndFunction

// Returns a flag showing whether the node supports the format version, for which the node encoding
//  with UUID usage is provided.
//
Function VersionWithDataExchangeIDSupported(Val InfobaseNode) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	If InfobaseNode = ExchangePlans[ExchangePlanName].ThisNode()
		Or Not ValueIsFilled(InfobaseNode) Then
		SupportedVersions = ExhangeFormatVersionsArray(InfobaseNode);
	Else
		SupportedVersions = New Array;
		SupportedVersions.Add(Common.ObjectAttributeValue(InfobaseNode, "ExchangeFormatVersion"));
	EndIf;
	
	Return VersionSupported(SupportedVersions, VersionNumberWithDataExchangeIDSupport());
	
EndFunction

Function MaxCommonFormatVersion(ExchangePlanName, CorrespondentFormatVersions) Export
	
	MaxCommonVersion = "0.0";
	
	FormatVersions = ExhangeFormatVersionsArray(ExchangePlans[ExchangePlanName].ThisNode());
	
	For Each CorrespondentVersion In CorrespondentFormatVersions Do
		CorrespondentVersion = TrimAll(CorrespondentVersion);
		
		If FormatVersions.Find(CorrespondentVersion) = Undefined Then
			Continue;
		EndIf;
		
		If CompareVersions(CorrespondentVersion, MaxCommonVersion) >= 0 Then
			MaxCommonVersion = CorrespondentVersion;
		EndIf;
	EndDo;
	
	Return MaxCommonVersion;
	
EndFunction

#EndRegion

#Region Other

// The procedure adds an infobase object to the allowed object filter.
// Parameters:
//  Data     - 
//  Recipient - ExchangePlanRef - a reference to the exchange plan the object is being checked for.
//
Procedure AddObjectToAllowedObjectsFilter(Data, Recipient) Export
	
	InformationRegisters.ObjectsDataToRegisterInExchanges.AddObjectToAllowedObjectsFilter(Data, Recipient);
	
EndProcedure

// Returns an array of nodes the object was exported to earlier.
//
// Parameters:
//  Ref            - 
//  ExchangePlanName    - String - a name of the exchange plan as a metadata object used to determine nodes.
//  FlagAttributeName - String - a name of the exchange plan attribute used to set a node selection filter.
// Returns:
//  МассивУзлов - 
//                
//
Function NodesArrayToRegisterExportIfNecessary(Ref, ExchangePlanName, FlagAttributeName) Export
	
	TextTemplate1 = "ExchangePlan.%1";
	NameOfTheStringExchangePlan = StringFunctionsClientServer.SubstituteParametersToString(TextTemplate1, ExchangePlanName);
	
	TextTemplateField = "ExchangePlanHeader.%1";
	TheNameOfTheFlagSPropsAsAString = StringFunctionsClientServer.SubstituteParametersToString(TextTemplateField, FlagAttributeName);

	QueryText = "SELECT DISTINCT
	|	ExchangePlanHeader.Ref AS Node
	|FROM
	|	&ExchangePlanName AS ExchangePlanHeader
	|		LEFT JOIN InformationRegister.ObjectsDataToRegisterInExchanges AS ObjectsDataToRegisterInExchanges
	|		ON ExchangePlanHeader.Ref = ObjectsDataToRegisterInExchanges.InfobaseNode
	|		AND ObjectsDataToRegisterInExchanges.Ref = &Object
	|WHERE
	|	NOT ExchangePlanHeader.ThisNode
	|	AND &FlagAttributeName = VALUE(Enum.ExchangeObjectExportModes.ExportIfNecessary)
	|	AND NOT ExchangePlanHeader.DeletionMark
	|	AND ObjectsDataToRegisterInExchanges.Ref = &Object";
	
	QueryText = StrReplace(QueryText, "&ExchangePlanName", NameOfTheStringExchangePlan); //@Query-part-1
	QueryText = StrReplace(QueryText, "&FlagAttributeName", TheNameOfTheFlagSPropsAsAString);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Object",   Ref);
	
	NodesArray = Query.Execute().Unload().UnloadColumn("Node");
	
	Return NodesArray;
	
EndFunction

// Writes a message to the event log.
//
// Parameters:
//  Comment      - String - comment to write to the event log.
//  Level          - 
//  
//
Procedure WriteEventLogDataExchange1(Comment, ExchangeComponents, Level = Undefined, ObjectReference = Undefined) Export
	
	CorrespondentNode = ExchangeComponents.CorrespondentNode;
	EventLogMessageKey = ExchangeComponents.EventLogMessageKey;
	
	If Level = Undefined Then
		Level = EventLogLevel.Error;
	EndIf;
	
	MetadataObject = Undefined;
	
	If     CorrespondentNode <> Undefined
		And Not CorrespondentNode.IsEmpty() Then
		
		MetadataObject = CorrespondentNode.Metadata();
		
	EndIf;
	
	WriteLogEvent(EventLogMessageKey, Level, MetadataObject, ObjectReference, Comment);
	
EndProcedure

// Parameters:
//   ExchangeComponents - See DataExchangeXDTOServer.InitializeExchangeComponents
// 
Procedure FillSupportedXDTOObjects(ExchangeComponents) Export
	
	If Not ExchangeComponents.IsExchangeViaExchangePlan
		Or Not ValueIsFilled(ExchangeComponents.CorrespondentNode) Then
		Return;
	EndIf;
	
	If ExchangeComponents.ExchangeDirection = "Send" Then
		
		// 
		// 
		// 
		
		CorrespondentInfobaseObjectsTable = SupportedCorrespondentFormatObjects(ExchangeComponents.CorrespondentNode, "Receive");
		
	ElsIf ExchangeComponents.ExchangeDirection = "Receive" Then
		
		// 
		// 
		// 
		
		CorrespondentInfobaseObjectsTable = SupportedCorrespondentFormatObjects(ExchangeComponents.CorrespondentNode, "Send");
		
	Else
		
		Return;
		
	EndIf;
	
	FilterByVersionAndDirection = New Structure("Version", ExchangeComponents.ExchangeFormatVersion);
	FilterByVersionAndDirection.Insert(ExchangeComponents.ExchangeDirection, True);
	
	DatabaseObjectsTableByVersion = ExchangeComponents.XDTOSettings.SupportedObjects.Copy(FilterByVersionAndDirection);
	
	FilterByVersion = New Structure("Version", ExchangeComponents.ExchangeFormatVersion);
	
	CorrespondentInfobaseObjectsTableByVersion = CorrespondentInfobaseObjectsTable.Copy(FilterByVersion);
	
	For Each DatabaseObjectsByVersionRow In DatabaseObjectsTableByVersion Do
		If CorrespondentInfobaseObjectsTableByVersion.Find(DatabaseObjectsByVersionRow.Object, "Object") = Undefined Then
			Continue;
		EndIf;
		
		ExchangeComponents.SupportedXDTOObjects.Add(DatabaseObjectsByVersionRow.Object);
	EndDo;
	
EndProcedure

// Returns:
//   ValueTable - 
//     * Name - String
//     * FilterObjectFormat - String
//     * XDTORefType - XDTOValueType
//                     - XDTOObjectType
//     * SelectionObjectMetadata - MetadataObject
//     * DataSelection - String
//     * TableNameForSelection - String
//     * OnProcess - String
//     * OCRUsed - Array of String
// 
Function DataProcessingRulesTable(ExchangeComponents) Export
	
	XMLSchema = ExchangeComponents.XMLSchema;
	ExchangeManagerFormatVersion = ExchangeComponents.ExchangeManagerFormatVersion;
	
	// Initializing a table of data processing rules.
	DataProcessingRules = New ValueTable;
	DataProcessingRules.Columns.Add("Name");
	DataProcessingRules.Columns.Add("FilterObjectFormat");
	DataProcessingRules.Columns.Add("XDTORefType");
	DataProcessingRules.Columns.Add("SelectionObjectMetadata");
	DataProcessingRules.Columns.Add("DataSelection");
	DataProcessingRules.Columns.Add("TableNameForSelection");
	DataProcessingRules.Columns.Add("OnProcess",    New TypeDescription("String"));
	
	// ИспользуемыеПКО - 
	DataProcessingRules.Columns.Add("OCRUsed",    New TypeDescription("Array"));
	
	ExchangeComponents.ExchangeManager.FillInDataProcessingRules(ExchangeComponents.ExchangeDirection, DataProcessingRules);
	
	HasExtensions = False;
	If TypeOf(ExchangeComponents.FormatExtensions) = Type("Map") Then
		
		HasExtensions = (ExchangeComponents.FormatExtensions.Count() > 0);
		
	EndIf;
	
	RowsCount = DataProcessingRules.Count();
	For IterationNumber = 1 To RowsCount Do
		
		RowIndex = RowsCount - IterationNumber;
		DPR = DataProcessingRules.Get(RowIndex);
		
		If ExchangeComponents.ExchangeDirection = "Receive" Then
			
			XDTOType = XDTOFactory.Type(XMLSchema, DPR.FilterObjectFormat);
			If XDTOType = Undefined And HasExtensions Then
				
				TypeXDTOProcessingRulesFromPackageExtensionsXDTO(ExchangeComponents, DPR, XDTOType);
				
			EndIf;
			
			If XDTOType = Undefined Then
				
				DataProcessingRules.Delete(DPR);
				Continue;
				
			EndIf;
			
			KeyProperties = XDTOType.Properties.Get(ClassKeyFormatProperties());
			If KeyProperties <> Undefined Then
				
				KeyPropertiesTypeOfXDTOObject = KeyProperties.Type;
				PropertyXDTORef = KeyPropertiesTypeOfXDTOObject.Properties.Get(LinkClass());
				If PropertyXDTORef <> Undefined Then
					DPR.XDTORefType = PropertyXDTORef.Type;
				EndIf;
				
			EndIf;
			
		ElsIf DPR.SelectionObjectMetadata <> Undefined Then
			DPR.TableNameForSelection = DPR.SelectionObjectMetadata.FullName();
		EndIf;
		
	EndDo;
	
	If ExchangeComponents.ExchangeDirection = "Send" Then
		DataProcessingRules.Indexes.Add("Name");
		DataProcessingRules.Indexes.Add("SelectionObjectMetadata");
	Else
		DataProcessingRules.Indexes.Add("FilterObjectFormat");
		DataProcessingRules.Indexes.Add("XDTORefType");
	EndIf;
	
	Return DataProcessingRules;
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region ExchangeInitialization

// Parameters:
//   * ExchangeManagerFormatVersion - String
// 
// Returns:
//   ValueTable - 
//     * OCRName - String
//     * DataObject - Arbitrary
//     * FormatObject - String
//     * ReceivedDataTypeAsString - String
//     * ReceivedDataTableName - String
//     * ReceivedDataTypePresentation - String
//     * Properties - ValueTable
//     * SearchFields - Array of String
//     * ObjectPresentationFields - String
//     * ReceivedDataHeaderAttributes - Array of String
//     * OnSendData - String
//     * OnConvertXDTOData - String
//     * BeforeWriteReceivedData - String
//     * AfterImportAllData - String
//     * RuleForCatalogGroup - Boolean
//     * IdentificationOption - String
//     * AllowCreateObjectFromStructure - Arbitrary
//     * ProcessedTabularSectionsProperties - ValueTable
//     * TabularSectionsProperties - Structure
//                               -  ValueTable
// 
Function ConversionRulesCollection1(ExchangeManagerFormatVersion)
	
	// Initializing the data conversion rules table.
	ConversionRules = New ValueTable;
	ConversionRules.Columns.Add("OCRName", New TypeDescription("String"));
	ConversionRules.Columns.Add("DataObject");
	ConversionRules.Columns.Add("FormatObject",                         New TypeDescription("String"));
	ConversionRules.Columns.Add("ReceivedDataTypeAsString",            New TypeDescription("String",,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataTableName",            New TypeDescription("String",,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataTypePresentation",     New TypeDescription("String",,New StringQualifiers(300)));
	ConversionRules.Columns.Add("Properties",                              New TypeDescription("ValueTable"));
	ConversionRules.Columns.Add("SearchFields",                            New TypeDescription("Array"));
	ConversionRules.Columns.Add("ObjectPresentationFields",              New TypeDescription("String",,New StringQualifiers(300)));
	ConversionRules.Columns.Add("ReceivedDataHeaderAttributes",        New TypeDescription("Array"));
	ConversionRules.Columns.Add("OnSendData",                     New TypeDescription("String"));
	ConversionRules.Columns.Add("OnConvertXDTOData",              New TypeDescription("String"));
	ConversionRules.Columns.Add("BeforeWriteReceivedData",          New TypeDescription("String"));
	ConversionRules.Columns.Add("AfterImportAllData",               New TypeDescription("String"));
	ConversionRules.Columns.Add("RuleForCatalogGroup",           New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IdentificationOption",                  New TypeDescription("String",,New StringQualifiers(60)));
	ConversionRules.Columns.Add("SearchAlgorithm",                        New TypeDescription("String"));
	ConversionRules.Columns.Add("Extensions",                            New TypeDescription("Map"));
	ConversionRules.Columns.Add("Namespace",                      New TypeDescription("String"));
	ConversionRules.Columns.Add("AllowCreateObjectFromStructure");
	
	If ExchangeManagerFormatVersion = "1" Then
		TSPropertyTypesDetails = New TypeDescription("Structure");
		ConversionRules.Columns.Add("ProcessedTabularSectionsProperties", New TypeDescription("ValueTable"));
	Else
		TSPropertyTypesDetails = New TypeDescription("ValueTable");
	EndIf;
	ConversionRules.Columns.Add("TabularSectionsProperties", TSPropertyTypesDetails);
	
	Return ConversionRules;
	
EndFunction

Function ConversionRulesTable(ExchangeComponents)
	
	// Initializing the data conversion rules table.
	ConversionRules = ConversionRulesCollection1(ExchangeComponents.ExchangeManagerFormatVersion);
	
	ExchangeComponents.ExchangeManager.FillInObjectConversionRules(ExchangeComponents.ExchangeDirection, ConversionRules);
	
	If ExchangeComponents.ExchangeDirection = "Receive" Then
		
		// Selecting conversion rule strings with empty AllowCreateObjectFromStructure attribute.
		FilterParameters = New Structure("AllowCreateObjectFromStructure", Undefined);
		StringsToProcess = ConversionRules.FindRows(FilterParameters);
		
		// 
		// 
		// 
		//  
		//  
		// 
		// 
		For Each ProcessingString In StringsToProcess Do
			ProcessingString.AllowCreateObjectFromStructure = True;
			DataProcessingRulesString = ExchangeComponents.DataProcessingRules.Find(ProcessingString.FormatObject, "FilterObjectFormat");
			If DataProcessingRulesString <> Undefined Then
				UsedOCRArray = DataProcessingRulesString.OCRUsed;
				ProcessingString.AllowCreateObjectFromStructure = UsedOCRArray.Find(ProcessingString.OCRName) = Undefined;
			EndIf;
		EndDo;
		
	EndIf;
	
	// 
	ConversionRules.Columns.Add("XDTOType");
	ConversionRules.Columns.Add("XDTORefType");
	ConversionRules.Columns.Add("KeyPropertiesTypeOfXDTOObject");
	ConversionRules.Columns.Add("DataType");
	
	ConversionRules.Columns.Add("ObjectManager");
	ConversionRules.Columns.Add("FullName");
	
	ConversionRules.Columns.Add("IsDocument",               New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsRegister",                New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsCatalog",             New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsEnum",           New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsChartOfCharacteristicTypes", New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsBusinessProcess",          New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsTask",                 New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsChartOfAccounts",             New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsChartOfCalculationTypes",       New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("IsConstant",              New TypeDescription("Boolean"));
	
	ConversionRules.Columns.Add("DocumentCanBePosted", New TypeDescription("Boolean"));
	
	ConversionRules.Columns.Add("IsReferenceType", New TypeDescription("Boolean"));
	
	ConversionRules.Columns.Add("HasHandlerOnSendData",            New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerOnConvertXDTOData",     New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerBeforeWriteReceivedData", New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerAfterImportAllData",      New TypeDescription("Boolean"));
	ConversionRules.Columns.Add("HasHandlerSearchAlgorithm",               New TypeDescription("Boolean"));
	
	AllowDocumentPosting = Metadata.ObjectProperties.Posting.Allow;
	
	RowsCount = ConversionRules.Count();
	For IterationNumber = 1 To RowsCount Do
		
		RowIndex = RowsCount - IterationNumber;
		ConversionRule = ConversionRules.Get(RowIndex);
		
		IsBaseSchema  = IsBaseSchema(ExchangeComponents, ConversionRule.Namespace);
		Namespace = ?(IsBaseSchema, ExchangeComponents.XMLSchema, ConversionRule.Namespace);
		HasExtensions = ConversionRule.Extensions.Count() > 0;
		
		If ValueIsFilled(ConversionRule.FormatObject) Then
			ConversionRule.XDTOType = XDTOFactory.Type(Namespace, ConversionRule.FormatObject);
			
			If ConversionRule.XDTOType = Undefined And HasExtensions Then
				XDTOTypeConversionRulesFromPackageExtensionsXDTO(ConversionRule);
			EndIf;
			
			If ConversionRule.XDTOType = Undefined Then
				ConversionRules.Delete(ConversionRule);
				Continue;
			EndIf;
			
		EndIf;
		
		If IsBaseSchema And HasExtensions Then
			RemoveRedundantExtensionsConversionRules(ConversionRule);
		EndIf;
		
		If ExchangeComponents.ExchangeDirection = "Receive" Then
			
			ObjectMetadata = ConversionRule.DataObject; // 
		
			ConversionRule.ReceivedDataTableName = ObjectMetadata.FullName();
			ConversionRule.ReceivedDataTypePresentation = ObjectMetadata.Presentation();
			ConversionRule.ReceivedDataTypeAsString = DataTypeNameByMetadataObject(ConversionRule.DataObject);
		
			ConversionRule.ObjectPresentationFields = ?(ConversionRule.SearchFields.Count() = 0, "", ConversionRule.SearchFields[0]);
			
			// Attributes of the object of data to be received.
			ArrayAttributes = New Array;
			For Each Attribute In ObjectMetadata.StandardAttributes Do
				If Attribute.Name = "Description"
					Or Attribute.Name = "Code"
					Or Attribute.Name = "IsFolder"
					Or Attribute.Name = "Parent"
					Or Attribute.Name = "Owner"
					Or Attribute.Name = "Date"
					Or Attribute.Name = "Number" Then
					ArrayAttributes.Add(Attribute.Name);
				EndIf;
			EndDo;
			For Each Attribute In ObjectMetadata.Attributes Do
				ArrayAttributes.Add(Attribute.Name);
			EndDo;

			ConversionRule.ReceivedDataHeaderAttributes = ArrayAttributes;
			
			ConversionRule.HasHandlerOnConvertXDTOData     = Not IsBlankString(ConversionRule.OnConvertXDTOData);
			ConversionRule.HasHandlerBeforeWriteReceivedData = Not IsBlankString(ConversionRule.BeforeWriteReceivedData);
			ConversionRule.HasHandlerAfterImportAllData      = Not IsBlankString(ConversionRule.AfterImportAllData);
			ConversionRule.HasHandlerSearchAlgorithm               = Not IsBlankString(ConversionRule.SearchAlgorithm);
		Else
			ConversionRule.HasHandlerOnSendData            = Not IsBlankString(ConversionRule.OnSendData);
		EndIf;
		
		If ConversionRule.DataObject <> Undefined Then
			
			ConversionRule.FullName                  = ConversionRule.DataObject.FullName();
			ConversionRule.ObjectManager            = Common.ObjectManagerByFullName(ConversionRule.FullName);
			
			ConversionRule.IsRegister = False;
			ConversionRule.IsDocument = False;
			ConversionRule.IsCatalog = False;
			ConversionRule.IsEnum = False;
			ConversionRule.IsChartOfCharacteristicTypes = False;
			ConversionRule.IsBusinessProcess = False;
			ConversionRule.IsTask = False;
			ConversionRule.IsChartOfAccounts = False;
			ConversionRule.IsChartOfCalculationTypes = False;
			ConversionRule.IsConstant = False;
	
			If DataExchangeCached.IsCatalog(ConversionRule.FullName) Then
				ConversionRule.IsCatalog = True;
			ElsIf DataExchangeCached.IsDocument(ConversionRule.FullName) Then
				ConversionRule.IsDocument = True;
			ElsIf DataExchangeCached.IsEnum(ConversionRule.FullName) Then
				ConversionRule.IsEnum = True;
			ElsIf DataExchangeCached.IsRegister(ConversionRule.FullName) Then
				ConversionRule.IsRegister = True;
			ElsIf DataExchangeCached.IsChartOfCharacteristicTypes(ConversionRule.FullName) Then
				ConversionRule.IsChartOfCharacteristicTypes = True;
			ElsIf DataExchangeCached.IsBusinessProcess(ConversionRule.FullName) Then
				ConversionRule.IsBusinessProcess = True;
			ElsIf DataExchangeCached.IsTask(ConversionRule.FullName) Then
				ConversionRule.IsTask = True;
			ElsIf DataExchangeCached.IsChartOfAccounts(ConversionRule.FullName) Then
				ConversionRule.IsChartOfAccounts = True;
			ElsIf DataExchangeCached.IsChartOfCalculationTypes(ConversionRule.FullName) Then
				ConversionRule.IsChartOfCalculationTypes = True;
			ElsIf DataExchangeCached.IsConstant(ConversionRule.FullName) Then
				ConversionRule.IsConstant = True;
			EndIf;
			
			ConversionRule.DataType = Type(DataTypeNameByMetadataObject(ConversionRule.DataObject));
			
			If ConversionRule.IsDocument Then
				ConversionRule.DocumentCanBePosted = ConversionRule.DataObject.Posting = AllowDocumentPosting;
			EndIf;
			
		EndIf;
		
		ConversionRule.IsReferenceType = ConversionRule.IsDocument
			Or ConversionRule.IsCatalog
			Or ConversionRule.IsChartOfCharacteristicTypes
			Or ConversionRule.IsBusinessProcess
			Or ConversionRule.IsTask
			Or ConversionRule.IsChartOfAccounts
			Or ConversionRule.IsChartOfCalculationTypes;
		
		MarkKeyPropertiesOfConversionRule(ExchangeComponents, ConversionRule);
		
		If ConversionRule.IdentificationOption = "BySearchFields"
			Or ConversionRule.IdentificationOption = "FirstByUUIDThenBySearchFields" Then
			
			PCRTable = ConversionRule.Properties;
			For Each PCR In PCRTable Do
				
				If ValueIsFilled(ConversionRule.SearchFields) Then
					For Each SearchFieldsItem In ConversionRule.SearchFields Do
						SearchFieldsAsArray = StrSplit(SearchFieldsItem, ",");
						For Each FieldForSearch In SearchFieldsAsArray Do
							FieldForSearch = TrimAll(FieldForSearch);
							If FieldForSearch = PCR.ConfigurationProperty Then
								PCR.SearchPropertyHandler = True;
								Break;
							EndIf;
						EndDo;
					EndDo;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If ExchangeComponents.ExchangeManagerFormatVersion = "1" Then
			InitializeTabularSectionsProperties(ConversionRule, "ProcessedTabularSectionsProperties");
			For Each TS In ConversionRule.TabularSectionsProperties Do
				TabularSectionsPropertiesRow = ConversionRule.ProcessedTabularSectionsProperties.Add();
				TabularSectionsPropertiesRow.UsesConversionAlgorithm = True;
				TabularSectionsPropertiesRow.Properties = TS.Value;
				If ExchangeComponents.ExchangeDirection = "Receive" Then
					TabularSectionsPropertiesRow.TSConfigurations = TS.Key;
				Else
					TabularSectionsPropertiesRow.FormatTS = TS.Key;
				EndIf;
			EndDo;
		Else
			// Filling in information on conversion of tabular section properties.
			For Each PCRTS In ConversionRule.TabularSectionsProperties Do
				For Each PCR In PCRTS.Properties Do
					If PCR.UsesConversionAlgorithm Then
						PCRTS.UsesConversionAlgorithm = True;
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndIf;
	EndDo;
	
	If ExchangeComponents.ExchangeManagerFormatVersion = "1" Then
		ConversionRules.Columns.Delete(ConversionRules.Columns.TabularSectionsProperties);
		ConversionRules.Columns.Add("TabularSectionsProperties", New TypeDescription("ValueTable"));
		For Each ConversionRule In ConversionRules Do
			InitializeTabularSectionsProperties(ConversionRule);
			For Each TSProperty In ConversionRule.ProcessedTabularSectionsProperties Do
				TabularSectionsPropertiesRow = ConversionRule.TabularSectionsProperties.Add();
				FillPropertyValues(TabularSectionsPropertiesRow, TSProperty);
				For Each PCR In TabularSectionsPropertiesRow.Properties Do
					If PCR.UsesConversionAlgorithm Then
						TabularSectionsPropertiesRow.UsesConversionAlgorithm = True;
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
		ConversionRules.Columns.Delete(ConversionRules.Columns.ProcessedTabularSectionsProperties);
	EndIf;
	
	// 
	ConversionRules.Indexes.Add("OCRName");
	ConversionRules.Indexes.Add("DataType");
	ConversionRules.Indexes.Add("XDTOType");
	If ExchangeComponents.ExchangeDirection = "Receive" Then
		ConversionRules.Indexes.Add("XDTORefType");
	EndIf;
	
	Return ConversionRules;
	
EndFunction

Function PredefinedDataConversionRulesTable(ExchangeComponents)
	
	XMLSchema = ExchangeComponents.XMLSchema;
	ExchangeManagerFormatVersion = ExchangeComponents.ExchangeManagerFormatVersion;
	
	// Initializing the data conversion rules table.
	ConversionRules = New ValueTable;
	ConversionRules.Columns.Add("DataType");
	ConversionRules.Columns.Add("XDTOType");
	ConversionRules.Columns.Add("ConvertValuesOnReceipt");
	ConversionRules.Columns.Add("ConvertValuesOnSend");
	
	ConversionRules.Columns.Add("PDCRName", New TypeDescription("String"));
	
	ExchangeComponents.ExchangeManager.FillInRulesForConvertingPredefinedData(ExchangeComponents.ExchangeDirection, ConversionRules);

	BroadcastPredefinedData(ConversionRules);
	
	For Each ConversionRule In ConversionRules Do
		ConversionRule.XDTOType = XDTOFactory.Type(XMLSchema, ConversionRule.XDTOType);
		ConversionRule.DataType = Type(DataTypeNameByMetadataObject(ConversionRule.DataType));
	EndDo;
	
	ConversionRules.Indexes.Add("PDCRName");
	ConversionRules.Indexes.Add("DataType");
	ConversionRules.Indexes.Add("DataType,XDTOType");
	
	Return ConversionRules;
	
EndFunction

Function ConversionParametersStructure(ExchangeManager)
	// 
	//	
	//	
	ConversionParameters_SSLy = New Structure();
	ExchangeManager.FillInConversionParameters(ConversionParameters_SSLy);
	Return ConversionParameters_SSLy;
EndFunction

Procedure AfterInitializationOfTheExchangeComponents(ExchangeComponents) Export
	
	If TypeOf(ExchangeComponents) <> Type("Structure") Then
		
		Return;
		
	EndIf;
	
	// 
	// 
	// 
	If ExchangeComponents.Property("IsExchangeViaExchangePlan")
		And ExchangeComponents.Property("CorrespondentNode")
		And ExchangeComponents.Property("CorrespondentNodeObject") Then
		
		If ExchangeComponents.IsExchangeViaExchangePlan = True
			And ValueIsFilled(ExchangeComponents.CorrespondentNode)
			And ExchangeComponents.CorrespondentNodeObject = Undefined Then
			
			ExchangeComponents.CorrespondentNodeObject = ExchangeComponents.CorrespondentNode.GetObject();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// ACC:299-off - Called from rules
Procedure InitializeTheObjectConversionRuleExtension(ConversionRule, Val Namespace) Export
	
	StructureOfTheObjectConversionRuleExtension = New Structure;
	StructureOfTheObjectConversionRuleExtension.Insert("XDTOType");
	StructureOfTheObjectConversionRuleExtension.Insert("KeyPropertiesTypeOfXDTOObject");
	StructureOfTheObjectConversionRuleExtension.Insert("DataType");
	
	ConversionRule.Extensions.Insert(Namespace, StructureOfTheObjectConversionRuleExtension);
	
EndProcedure
// ACC:299-on

Procedure TypeXDTOProcessingRulesFromPackageExtensionsXDTO(ExchangeComponents, DPR, XDTOType)
	
	For Each ExtensionDetails In ExchangeComponents.FormatExtensions Do
		
		NamespaceExtensions = ExtensionDetails.Key;
		TypeOfXDTOExtension = XDTOFactory.Type(NamespaceExtensions, DPR.FilterObjectFormat);
		If TypeOfXDTOExtension <> Undefined Then
			
			// 
			XDTOType = TypeOfXDTOExtension;
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure XDTOTypeConversionRulesFromPackageExtensionsXDTO(ConversionRule)
	
	For Each FormatExtensionFromConversionRule In ConversionRule.Extensions Do
		
		NamespaceExtensions = FormatExtensionFromConversionRule.Key;
		ConversionRule.XDTOType = XDTOFactory.Type(NamespaceExtensions, ConversionRule.FormatObject);
		If ConversionRule.XDTOType <> Undefined Then
			
			// Confirmed that it belongs to the XDTO schema extension.
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure RemoveRedundantExtensionsConversionRules(ConversionRule)
	
	ExtensionsForDeletion = New Array;
	For Each PackageExtensionXDTO In ConversionRule.Extensions Do
		
		NamespaceFormatExtensions = PackageExtensionXDTO.Key;
		
		XDTOType = XDTOFactory.Type(NamespaceFormatExtensions, ConversionRule.FormatObject);
		If XDTOType = Undefined Then
			
			ExtensionsForDeletion.Add(NamespaceFormatExtensions);
			
		Else
			
			PackageExtensionXDTO.Value.XDTOType = XDTOType;
			
		EndIf;
		
	EndDo;
	
	For Each ExtensionForDeletion In ExtensionsForDeletion Do
		
		ConversionRule.Extensions.Delete(ExtensionForDeletion);
		
	EndDo;
	
EndProcedure
// ACC:299-on

Procedure MarkKeyPropertiesOfConversionRule(ExchangeComponents, ConversionRule)
	
	If Not ValueIsFilled(ConversionRule.FormatObject) Then
		
		Return;
		
	EndIf;
	
	KeyProperties = ConversionRule.XDTOType.Properties.Get(ClassKeyFormatProperties());
	If KeyProperties = Undefined Then
		
		Return;
		
	EndIf;
	
	KeyPropertiesTypeOfXDTOObject = KeyProperties.Type;
	ConversionRule.KeyPropertiesTypeOfXDTOObject = KeyPropertiesTypeOfXDTOObject;
	
	ArrayOfKeyProperties = New Array;
	FillXDTOObjectPropertiesList(KeyPropertiesTypeOfXDTOObject, ArrayOfKeyProperties);
	AddKeyPackagePropertiesFromExtensions(ConversionRule, KeyPropertiesTypeOfXDTOObject, ArrayOfKeyProperties);
	
	PCRToAdd = New Array;
	
	PCRTable = ConversionRule.Properties;
	For Each PCR In PCRTable Do
		
		FormatProperty = BroadcastName(PCR.FormatProperty, "ru", ConversionRule.XDTOType);
		
		If ArrayOfKeyProperties.Find(FormatProperty) <> Undefined Then
			PCR.KeyPropertyProcessing = True;
			
			If ConversionRule.XDTOType.Properties.Get(FormatProperty) <> Undefined Then
				PCRToAdd.Add(PCR);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For Each PCR In PCRToAdd Do
		NewPCR = PCRTable.Add();
		FillPropertyValues(NewPCR, PCR, , "KeyPropertyProcessing");
	EndDo;
	
	PropertyXDTORef = KeyPropertiesTypeOfXDTOObject.Properties.Get(FormatReferenceClass());
	If PropertyXDTORef <> Undefined Then
		
		ConversionRule.XDTORefType = PropertyXDTORef.Type;
		
		If ConversionRule.IsReferenceType
			And ExchangeComponents.ExchangeDirection = "Send" Then
			PCRForRef = PCRTable.Add();
			PCRForRef.ConfigurationProperty = LinkClass();
			PCRForRef.FormatProperty = LinkClass();
			PCRForRef.KeyPropertyProcessing = True;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataSending

Procedure AppendXDTOObject(XDTODataObject, Val Property, Val Value)
	
	If Not CommonClientServer.HasAttributeOrObjectProperty(XDTODataObject, Property.Name) Then
		
		XDTODataObject.Add(Property.Form, Property.NamespaceURI, Property.Name, Value);
		Return;
		
	EndIf;
	
	If IsObjectTable(Property) Then
		StringPropertyName = Property.Type.Properties[0].Name;
		For RowIndex = 0 To Value[StringPropertyName].Count() - 1 Do
			XDTORow = XDTODataObject[Property.Name][StringPropertyName].Get(RowIndex); // XDTODataObject 
			XDTOStringExtension = Value[StringPropertyName].Get(RowIndex);
			
			For Each StringProperty In XDTOStringExtension.Properties() Do
				If TypeOf(StringProperty.Type) = Type("XDTOValueType") Then
					StringPropertyValue = XDTOFactory.Create(StringProperty.Type,
						XDTOStringExtension.Get(StringProperty.Name));
				Else
					StringPropertyValue = XDTOStringExtension.Get(StringProperty.Name);
				EndIf;

				If StringPropertyValue = Undefined Then
					Continue;
				EndIf;
				
				XDTORow.Add(
					StringProperty.Form,
					StringProperty.NamespaceURI,
					StringProperty.Name,
					StringPropertyValue);
			EndDo;
		EndDo;
	ElsIf TypeOf(Property.Type) = Type("XDTOObjectType") Then
		For Each ChildProperty In Value.Properties() Do
			Subvalue = Value.Get(ChildProperty.Name);
			If Subvalue = Undefined Then
				Continue;
			EndIf;
			
			If TypeOf(ChildProperty.Type) = Type("XDTOValueType") Then
				AppendXDTOObject(XDTODataObject[Property.Name], ChildProperty, 
					XDTOFactory.Create(ChildProperty.Type, Subvalue));
			Else
				AppendXDTOObject(XDTODataObject[Property.Name], ChildProperty, Subvalue);
			EndIf;
		EndDo;
	EndIf;

EndProcedure

Procedure ExecuteRegisteredDataExport(ExchangeComponents, MessageNo)
		
	NodeForExchange = ExchangeComponents.CorrespondentNode;
	NodeForExchangeObject = NodeForExchange.GetObject();
	
	InitialDataExport = DataExchangeServer.InitialDataExportFlagIsSet(NodeForExchange);
	ObjectsToExportCount = 0;
	ChangesTable = FillInTableOfChanges(NodeForExchange, MessageNo, ObjectsToExportCount);
		
	ExchangeComponents.Insert("ObjectsToExportCount", ObjectsToExportCount);
		
	//  
	// 
	// 
	// 
	// 
	// 
	// 
	For Each ChangesRow In ChangesTable Do
		
		PDParameters = DataExchangeEvents.BatchRegistrationParameters();
		PDParameters.InitialImageCreating = InitialDataExport;
		
		If ChangesRow.ThereIsBatchRegistrationRule Then
			
			BeginTime = DataExchangeValuationOfPerformance.StartMeasurement(); 
			
			DataExchangeEvents.PerformBatchRegistrationForNode(NodeForExchange, ChangesRow.DataArray, PDParameters);
			
			DataExchangeValuationOfPerformance.FinishMeasurement(
				BeginTime, "BatchRegistrationOfObjects", ChangesRow.Type, ExchangeComponents,
				DataExchangeValuationOfPerformance.EventTypeApplied());
				
		EndIf;
				
		For Each Data In ChangesRow.DataArray Do
						
			Try
				If TypeOf(Data) = Type("ObjectDeletion") Then
					ExportDeletion(ExchangeComponents, Data.Ref);
				Else
					
					IsReference = ChangesRow.ThereIsBatchRegistrationRule;
					
					ItemSend = DataItemSend.Auto;
					
					BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
					
					If ChangesRow.ThereIsBatchRegistrationRule Then
						
						If PDParameters.ThereIsPRO_WithoutBatchRegistration 
							And PDParameters.LinksToBatchRegistrationFilter.Find(Data) = Undefined Then
							
							DataElement = ?(IsReference, Data.GetObject(), Data);
							DataElement.AdditionalProperties.Insert("CheckRegistrationBeforeUploading");
							DataExchangeEvents.OnSendDataToRecipient(DataElement, ItemSend, 
								InitialDataExport, NodeForExchangeObject, False);
								
						ElsIf Not PDParameters.ThereIsPRO_WithoutBatchRegistration 
							And PDParameters.LinksToBatchRegistrationFilter.Find(Data) = Undefined Then 
							
							If InitialDataExport Then
								ItemSend = DataItemSend.Ignore;
							Else
								ItemSend = DataItemSend.Delete;
							EndIf;
							
						EndIf;
						
					Else
						
						DataElement = ?(IsReference, Data.GetObject(), Data);
						DataElement.AdditionalProperties.Insert("CheckRegistrationBeforeUploading");
						DataExchangeEvents.OnSendDataToRecipient(DataElement, ItemSend, 
							InitialDataExport, NodeForExchangeObject, False);
						
					EndIf;
						
					DataExchangeValuationOfPerformance.FinishMeasurement(
						BeginTime, "ObjectRegistration", Data, ExchangeComponents,
						DataExchangeValuationOfPerformance.EventTypeLibrary());
					
					// Sending an empty record set upon the register deletion.
					If ItemSend = DataItemSend.Delete
						And Common.IsRegister(Data.Metadata()) Then
						ItemSend = DataItemSend.Auto;
					EndIf;
					
					If ItemSend = DataItemSend.Delete Then
						ExportDeletion(ExchangeComponents, Data.Ref);
					ElsIf ItemSend = DataItemSend.Ignore Then
						// 
						// 
						Continue;
					Else
						DataElement = ?(IsReference, Data.GetObject(), Data);
						ExportSelectionObject(ExchangeComponents, DataElement);
					EndIf;
				EndIf;
				
				ExchangeComponents.ExportedObjectCounter = ExchangeComponents.ExportedObjectCounter + 1;
				DataExchangeServer.CalculateExportPercent(ExchangeComponents.ExportedObjectCounter, ExchangeComponents.ObjectsToExportCount);
				
			Except
				Info = ErrorInfo();
				DataPresentation = ObjectPresentationForProtocol(Data);
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Event: %1.
					|Object: %2.
					|
					|%3';"),
					ExchangeComponents.ExchangeDirection,
					DataPresentation,
					ErrorProcessing.DetailErrorDescription(Info));
				EndTry;
				
		EndDo;
		
	EndDo;
	
EndProcedure

Function FillInTableOfChanges(NodeForExchange, MessageNo, ObjectsToExportCount)
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(NodeForExchange);
	
	// 
	ChangesSelection = ExchangePlans.SelectChanges(NodeForExchange, MessageNo);
		
	ChangesTable = New ValueTable;
	ChangesTable.Columns.Add("Type");
	ChangesTable.Columns.Add("DataArray", New TypeDescription("Array"));
	ChangesTable.Columns.Add("ThereIsBatchRegistrationRule", New TypeDescription("Boolean"));
		
	While ChangesSelection.Next() Do
		
		ObjectsToExportCount = ObjectsToExportCount + 1;
		
		Data = ChangesSelection.Get();
		Type = TypeOf(Data);
		ChangesRow = ChangesTable.Find(Type, "Type");
		
		If ChangesRow = Undefined Then 
			
			ChangesRow = ChangesTable.Add();
			ChangesRow.Type = Type;
			ChangesRow.ThereIsBatchRegistrationRule = ThereIsBatchRegistrationRule(Data, NodeForExchange);
			
		EndIf;
		
		If ChangesRow.ThereIsBatchRegistrationRule Then 
			ChangesRow.DataArray.Add(Data.Ref);
		Else
			ChangesRow.DataArray.Add(Data);
		EndIf;
		
	EndDo;
	
	Return ChangesTable;
	
EndFunction

Function ThereIsBatchRegistrationRule(Data, Node)
	
	Type = TypeOf(Data);
	
	If Type = Type("ObjectDeletion") Then
		Return False;
	EndIf;
	
	Result = False;
	If Common.IsRefTypeObject(Data.Metadata()) Then
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(Node);
		FullObjectName = Data.Metadata().FullName();
		
		Rules = DataExchangeEvents.ObjectRegistrationRules(ExchangePlanName, FullObjectName);
			
		For Each ORR In Rules Do
			If ORR.BatchExecutionOfHandlers Then
				Result = True;
				Break;
			EndIf;
		EndDo;
		
	EndIf;
		
	Return Result;
	
EndFunction

Procedure ExportObjectsByRef(ExchangeComponents, RefsFromObject)
	
	If Not ExchangeComponents.IsExchangeViaExchangePlan Then
		Return;
	EndIf;
			
	For Each RefValue In RefsFromObject Do
		
		If ExchangeComponents.ExportedObjects.Find(RefValue) = Undefined
			And ExportObjectIfNecessary(ExchangeComponents, RefValue) Then
			
			If Not InformationRegisters.ObjectsDataToRegisterInExchanges.ObjectIsInRegister(
				RefValue, ExchangeComponents.CorrespondentNode) Then
				
				ObjectToExportByRef = Undefined;
				
				If Common.RefExists(RefValue) Then
					ObjectToExportByRef = RefValue.GetObject();
				EndIf;
				
				If ObjectToExportByRef <> Undefined Then
					
					ExportSelectionObject(ExchangeComponents, ObjectToExportByRef);
					ExchangeComponents.ExportedByRefObjects.Add(RefValue);
					InformationRegisters.ObjectsDataToRegisterInExchanges.AddObjectToAllowedObjectsFilter(
						RefValue, ExchangeComponents.CorrespondentNode);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsXDTORef(Val Type)
	
	Return XDTOFactory.Type(XMLBasicSchema(), "Ref").IsDescendant(Type);
	
EndFunction

Function ExportObjectIfNecessary(ExchangeComponents, Object)
	
	MetadataObject = Metadata.FindByType(TypeOf(Object));
	
	If MetadataObject = Undefined Then
		Return False;
	EndIf;
	
	// Receiving a setting from cache.
	RegistrationOnRequest = ExchangeComponents.MapRegistrationOnRequest.Get(MetadataObject);
	If RegistrationOnRequest <> Undefined Then
		Return RegistrationOnRequest;
	EndIf;
	
	RegistrationOnRequest = False;
	
	Filter = New Structure("MetadataObjectName3", MetadataObject.FullName());
	RulesArray = ExchangeComponents.ObjectsRegistrationRulesTable.FindRows(Filter);
	
	For Each Rule In RulesArray Do
		
		If Not IsBlankString(Rule.FlagAttributeName) Then
			
			FlagAttributeValue = Undefined;
			ExchangeComponents.ExchangePlanNodeProperties.Property(Rule.FlagAttributeName, FlagAttributeValue);
			
			RegistrationOnRequest = (FlagAttributeValue = Enums.ExchangeObjectExportModes.ExportIfNecessary
				Or FlagAttributeValue = Enums.ExchangeObjectExportModes.EmptyRef());

			If RegistrationOnRequest Then
				Break;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// 
	ExchangeComponents.MapRegistrationOnRequest.Insert(MetadataObject, RegistrationOnRequest);
	Return RegistrationOnRequest;
	
EndFunction

Procedure WriteXDTOObjectDeletion(ExchangeComponents, Ref, XDTORefType)
	
	XDTOObjectUUID = InformationRegisters.SynchronizedObjectPublicIDs.PublicIDByObjectRef(
		ExchangeComponents.CorrespondentNode, Ref);
		
	If Not ValueIsFilled(XDTOObjectUUID) Then
		Return;
	EndIf;
	
	XMLSchema = ExchangeComponents.XMLSchema;
	XDTOType  = XDTOFactory.Type(XMLSchema, "УдалениеОбъекта");
	
	For Each Property In XDTOType.Properties[0].Type.Properties[0].Type.Properties Do
		If Property.Type = XDTORefType Then
			
			AnyRefXDTOValue = XDTOFactory.Create(Property.Type, XDTOObjectUUID);
			
			ObjectReference = XDTOFactory.Create(XDTOType.Properties[0].Type.Properties[0].Type); // XDTODataObject
			ObjectReference.Set(Property, AnyRefXDTOValue);
			
			AnyRefObject = XDTOFactory.Create(XDTOType.Properties[0].Type);
			AnyRefObject.СсылкаНаОбъект = ObjectReference;
			
			XDTOData = XDTOFactory.Create(XDTOType); // XDTODataObject
			XDTOData.СсылкаНаОбъект = XDTOFactory.Create(XDTOType.Properties[0].Type);
			XDTOData.Set(XDTOType.Properties[0], AnyRefObject);
			XDTOFactory.WriteXML(ExchangeComponents.ExchangeFile, XDTOData);
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//   ExchangeComponents - Structure - contains all key data for exchange (such as OCR, PDCR, DPR.).
//   Ref - 
//   ConversionRule  - 
//
Procedure ExportDeletion(ExchangeComponents, Ref, ConversionRule = Undefined)
	
	If ConversionRule <> Undefined Then
		// OCR was passed explicitly (when calling deletion for a specific OCR).
		If Not FormatObjectPassesXDTOFilter(ExchangeComponents, ConversionRule.FormatObject) Then
			Return;
		EndIf;
		
		WriteXDTOObjectDeletion(ExchangeComponents, Ref, ConversionRule.XDTORefType);
	Else
		
		// Search for OCR.
		OCRNamesArray = DPRByMetadataObject(ExchangeComponents, Ref.Metadata()).OCRUsed;
		
		// Array is used for collapsing OCR by XDTO types.
		ProcessedXDTORefsTypes = New Array;
		
		For Each ConversionRuleName In OCRNamesArray Do
			
			ConversionRule = ExchangeComponents.ObjectsConversionRules.Find(ConversionRuleName, "OCRName");
			
			If ConversionRule = Undefined Then
				// An OCR not intended for the current data format  version can be specified.
				Continue;
			EndIf;
			
			If Not FormatObjectPassesXDTOFilter(ExchangeComponents, ConversionRule.FormatObject) Then
				Continue;
			EndIf;
			
			// Collapsing OCR by an XDTO reference type.
			XDTORefType = ConversionRule.XDTORefType;
			If ProcessedXDTORefsTypes.Find(XDTORefType) = Undefined Then
				ProcessedXDTORefsTypes.Add(XDTORefType);
			Else
				Continue;
			EndIf;
			
			WriteXDTOObjectDeletion(ExchangeComponents, Ref, XDTORefType);
			
		EndDo;
		
	EndIf;
EndProcedure

Function ConvertEnumToXDTO(ExchangeComponents, EnumerationValue, XDTOEnumerationType)
	If TypeOf(EnumerationValue) = Type("String") Then
		
		FormatEnumerationValue = BroadcastEnumeration(EnumerationValue, "ru", XDTOEnumerationType);
		
		XDTODataValue = XDTOFactory.Create(XDTOEnumerationType, FormatEnumerationValue);
		
	Else
	
		PredefinedDataConversionRules = ExchangeComponents.PredefinedDataConversionRules;
		
		ConversionRule = FindConversionRuleForValue(
			PredefinedDataConversionRules, TypeOf(EnumerationValue), XDTOEnumerationType);
		
		XDTODataValue = XDTOFactory.Create(XDTOEnumerationType,
			XDTOEnumValue(ConversionRule.ConvertValuesOnSend, EnumerationValue));
		
	EndIf;
	Return XDTODataValue;
EndFunction

Function FindConversionRuleForValue(PredefinedDataConversionRules, Val Type, Val XDTOType = Undefined)
	
	If XDTOType = Undefined Then
		
		FoundRules = PredefinedDataConversionRules.FindRows(New Structure("DataType", Type));
		
		If FoundRules.Count() = 1 Then
			
			ConversionRule = FoundRules[0];
			
			Return ConversionRule;
			
		ElsIf FoundRules.Count() > 1 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Predefined data conversion rule error.
				|Multiple conversion rules are specified for source type ""%1"".';"),
				String(Type));
			
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Predefined data conversion rule error.
			|Conversion rule is not specified for source type ""%1"".';"),
			String(Type));
			
	Else
		
		FoundRules = PredefinedDataConversionRules.FindRows(New Structure("DataType, XDTOType", Type, XDTOType, False));
		
		If FoundRules.Count() = 1 Then
			
			ConversionRule = FoundRules[0];
			
			Return ConversionRule;
			
		ElsIf FoundRules.Count() > 1 Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Predefined data conversion rule error.
				|Multiple conversion rules are specified for source type ""%1"" and destination type ""%2"".';"),
				String(Type),
				String(XDTOType));
			
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Predefined data conversion rule error.
			|Conversion rule is not specified for source type ""%1"" and destination type ""%2"".';"),
			String(Type),
			String(XDTOType));
		
	EndIf;
	
EndFunction

Function XDTOEnumValue(Val ValuesConversions, Val Value)
	
	XDTODataValue = ValuesConversions.Get(Value);
	
	If XDTODataValue = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Predefined data conversion rule is not found.
			|Source value type: ""%1"".
			|Source value: ""%2""';"),
			TypeOf(Value),
			String(Value));
	EndIf;
	
	Return XDTODataValue;
EndFunction

Function ConvertRefToXDTO(ExchangeComponents, RefValue, XDTORefType)
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
	
		XDTOObjectUUID = InformationRegisters.SynchronizedObjectPublicIDs.PublicIDByObjectRef(
			ExchangeComponents.CorrespondentNode, RefValue);
		XDTODataValue = XDTOFactory.Create(XDTORefType, XDTOObjectUUID);
			
		Return XDTODataValue;
		
	Else
		Return TrimAll(RefValue.UUID());
	EndIf;
	
EndFunction

Function IsObjectTable(Val XDTOProperty)
	
	If TypeOf(XDTOProperty.Type) = Type("XDTOObjectType")
		And XDTOProperty.Type.Properties.Count() = 1 Then
		
		Return XDTOProperty.Type.Properties[0].UpperBound <> 1;
		
	EndIf;
	
	Return False;
EndFunction

Function IsObjectTableType(Val XDTOPropertyType)
	
	If TypeOf(XDTOPropertyType) = Type("XDTOObjectType")
		And XDTOPropertyType.Properties.Count() = 1 Then
		
		Return XDTOPropertyType.Properties[0].UpperBound <> 1;
		
	EndIf;
	
	Return False;
EndFunction

Procedure GetNestedPropertiesValue(PropertySource, NestedProperties, PropertyValue)
	CurrentPropertySource = PropertySource;
	CurrentPropertyValue = Undefined;
	For Level = 0 To NestedProperties.Count()-1 Do
		If Not CurrentPropertySource.Property(NestedProperties[Level], CurrentPropertyValue) Then
			Break;
		EndIf;
		If Level = NestedProperties.Count()-1 Then
			PropertyValue = CurrentPropertyValue;
		ElsIf TypeOf(CurrentPropertyValue) <> Type("Structure") Then
			Break;
		Else
			CurrentPropertySource = CurrentPropertyValue;
			CurrentPropertyValue = Undefined;
		EndIf;
	EndDo;
EndProcedure

Procedure PutNestedPropertiesValue(PropertyRecipient, NestedProperties, PropertyValue, IsTSRow)
	PropertyName = NestedProperties[0];
	NestedPropertiesValue = Undefined;
	If IsTSRow Then
		If PropertyRecipient.Owner().Columns.Find(PropertyName) = Undefined Then
			PropertyRecipient.Owner().Columns.Add(PropertyName);
		Else
			NestedPropertiesValue = PropertyRecipient[PropertyName];
		EndIf;
	Else
		If Not PropertyRecipient.Property(PropertyName, NestedPropertiesValue) Then
			PropertyRecipient.Insert(PropertyName);
		EndIf;
	EndIf;
	If NestedPropertiesValue = Undefined Then
		NestedPropertiesValue = New Structure;
	EndIf;
	NestedPropertiesStucture = NestedPropertiesValue;
	MaxLevel = NestedProperties.Count() - 1;
	For Level = 1 To MaxLevel Do
		NestedPropertyName = NestedProperties[Level];
		If Level = MaxLevel Then
			NestedPropertiesStucture.Insert(NestedPropertyName, PropertyValue);
			Break;
		EndIf;
		NestedPropertyRecipient = Undefined;
		NestedPropertiesStucture.Property(NestedPropertyName, NestedPropertyRecipient);
		If NestedPropertyRecipient = Undefined Then
			NestedPropertyRecipient = New Structure;
		EndIf;
		NestedPropertyRecipient.Insert(NestedPropertyName, New Structure);
		NestedPropertiesStucture = NestedPropertyRecipient;
	EndDo;
	PropertyRecipient[PropertyName] = NestedPropertiesValue;
EndProcedure

Function CreateDestinationTSByPCR(PCRForTS)
	
	NewDestinationTS = New ValueTable;
	For Each PCR In PCRForTS Do
		ColumnName = TrimAll(PCR.FormatProperty);
		// This might be PCR for nested properties.
		If StrFind(ColumnName, ".") > 0 Then
			NestedProperties = StrSplit(ColumnName,".",False);
			MaxIndex = NestedProperties.Count() - 1;
			For IndexOf = 0 To MaxIndex Do
				NestedPropertyName = NestedProperties[IndexOf];
				If NewDestinationTS.Columns.Find(NestedPropertyName) = Undefined Then
					NewDestinationTS.Columns.Add(NestedPropertyName);
				EndIf;
			EndDo;
		Else
			NewDestinationTS.Columns.Add(ColumnName);
		EndIf;
	EndDo;
	
	If NewDestinationTS.Columns.Count() > 0 Then

		NewDestinationTS.Columns.Add("Extensions");
		
	EndIf;
	
	Return NewDestinationTS;
	
EndFunction

Procedure ExportSupportedFormatObjects(Header, SupportedObjects, CorrespondentNode)
	
	AllVersionsTable = New ValueTable;
	AllVersionsTable.Columns.Add("Version", New TypeDescription("String"));
	
	For Each AvailableVersion In Header.AvailableVersion Do
		AllVersionsTableRow = AllVersionsTable.Add();
		AllVersionsTableRow.Version = AvailableVersion;
	EndDo;
	
	AllVersionsTable.Sort("Version");
	
	AllVersionsRow = StrConcat(AllVersionsTable.UnloadColumn("Version"), ",");
	
	SupportedObjectsTable = SupportedObjects.Copy();
	
	SupportedObjectsTable.Sort("Object, Version");
	
	AvailableXDTODataObjectsTypes = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "AvailableObjectTypes"));
	
	CurrentObject = Undefined;
	For Each SupportedObjectsRow In SupportedObjectsTable Do
		If CurrentObject = Undefined Then
			CreateNewObject = True;
		ElsIf CurrentObject.Name <> SupportedObjectsRow.Object Then
			
			If CurrentObject.Sending = AllVersionsRow Then
				CurrentObject.Sending = "*";
			EndIf;
			
			If CurrentObject.Receiving = AllVersionsRow Then
				CurrentObject.Receiving = "*";
			EndIf;
			
			AvailableXDTODataObjectsTypes.ObjectType.Add(CurrentObject);
			CreateNewObject = True;
		Else
			CreateNewObject = False;
		EndIf;
		
		If CreateNewObject Then
			CurrentObject = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "ObjectType"));
			CurrentObject.Name = SupportedObjectsRow.Object;
			
			CurrentObject.Sending   = "";
			CurrentObject.Receiving = "";
		EndIf;
		
		If SupportedObjectsRow.Send Then
			If IsBlankString(CurrentObject.Sending) Then
				CurrentObject.Sending = SupportedObjectsRow.Version;
			Else
				CurrentObject.Sending = CurrentObject.Sending + "," + SupportedObjectsRow.Version;
			EndIf;
		EndIf;
		
		If SupportedObjectsRow.Receive Then
			If IsBlankString(CurrentObject.Receiving) Then
				CurrentObject.Receiving = SupportedObjectsRow.Version;
			Else
				CurrentObject.Receiving = CurrentObject.Receiving + "," + SupportedObjectsRow.Version;
			EndIf;
		EndIf;
	EndDo;
	
	If CurrentObject <> Undefined Then
		If CurrentObject.Sending = AllVersionsRow Then
			CurrentObject.Sending = "*";
		EndIf;
		
		If CurrentObject.Receiving = AllVersionsRow Then
			CurrentObject.Receiving = "*";
		EndIf;
		
		AvailableXDTODataObjectsTypes.ObjectType.Add(CurrentObject);
	EndIf;
	
	If AvailableXDTODataObjectsTypes.ObjectType.Count() > 0 Then
		Header.AvailableObjectTypes = AvailableXDTODataObjectsTypes;
	Else
		Header.AvailableObjectTypes = Undefined;
	EndIf;
	
	InformationRegisters.XDTODataExchangeSettings.UpdateSettings2(
		CorrespondentNode, "SupportedObjects", SupportedObjectsTable);
	
EndProcedure

// A default structure of the message heading parameters.
// 
// Returns:
//   Structure - 
//     * ExchangeFormat - String - exchange format name.
//     * IsExchangeViaExchangePlan - Boolean - indicates an exchange via the exchange plan.
//     * DataExchangeWithExternalSystem - Boolean - indicates the exchange with the external system.
//     * ExchangeFormatVersion - String - exchange format version number.
//     * ExchangePlanName - String - name of the exchange plan metadata.
//     * PredefinedNodeAlias - String - a predefined node code before recoding.
//     * RecipientIdentifier - String - a message recipient node ID.
//     * SenderID - String - a message sender node ID.
//     * MessageNo - Number - a sent message number.
//     * ReceivedNo - Number - a number of the message imported by a peer.
//     * SupportedVersions - Array of String - a collection of supported format versions.
//     * SupportedObjects - ValueTable - a collection of supported format objects.
//     * Prefix - String - correspondent infobase prefix.
//     * CorrespondentNode - ExchangePlanRef
//                          - Undefined - the site plan of exchange.
//
Function ExchangeMessageHeaderParameters() Export
	
	HeaderParameters = New Structure;
	HeaderParameters.Insert("ExchangeFormat",            "");
	HeaderParameters.Insert("IsExchangeViaExchangePlan", False);
	HeaderParameters.Insert("DataExchangeWithExternalSystem", False);
	HeaderParameters.Insert("ExchangeFormatVersion",     "");
	
	HeaderParameters.Insert("ExchangePlanName",                 "");
	HeaderParameters.Insert("PredefinedNodeAlias", "");
	
	HeaderParameters.Insert("RecipientIdentifier", "");
	HeaderParameters.Insert("SenderID", "");
	
	HeaderParameters.Insert("MessageNo", 0);
	HeaderParameters.Insert("ReceivedNo", 0);
	
	HeaderParameters.Insert("SupportedVersions",  New Array);
	HeaderParameters.Insert("SupportedObjects", New ValueTable);
	
	HeaderParameters.Insert("Prefix", "");
	
	HeaderParameters.Insert("CorrespondentNode", Undefined);
	
	HeaderParameters.Insert("ExchangeViaProcessingUploadUploadED", False);
	
	Return HeaderParameters;
	
EndFunction

// Parameters:
//   ExchangeFile - XMLWriter - an object for writing a heading.
//   HeaderParameters - See DataExchangeXDTOServer.ExchangeMessageHeaderParameters
// 
Procedure WriteExchangeMessageHeader(ExchangeFile, HeaderParameters) Export
	
	// 
	ExchangeFile.WriteStartElement("Message");
	ExchangeFile.WriteNamespaceMapping("msg", "http://www.1c.ru/SSL/Exchange/Message");
	ExchangeFile.WriteNamespaceMapping("xs",  "http://www.w3.org/2001/XMLSchema");
	ExchangeFile.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	
	// Element <Header>.
	TitleXDTOMessages = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "Header"));
	
	TitleXDTOMessages.Format       = HeaderParameters.ExchangeFormat;
	TitleXDTOMessages.CreationDate = CurrentUniversalDate();
	
	AvailableXDTOVersions = TitleXDTOMessages.AvailableVersion; // XDTOList
	
	If HeaderParameters.IsExchangeViaExchangePlan Then
		
		XDTOConfirmation = XDTOFactory.Create(XDTOFactory.Type(XMLBasicSchema(), "Confirmation"));
		
		If HeaderParameters.DataExchangeWithExternalSystem Then
			XDTOConfirmation.From = HeaderParameters.SenderID;
		
			XDTOConfirmation.MessageNo  = HeaderParameters.MessageNo;
			XDTOConfirmation.ReceivedNo = HeaderParameters.ReceivedNo;
			
			TitleXDTOMessages.Confirmation = XDTOConfirmation;
			
			For Each FormatVersion In HeaderParameters.SupportedVersions Do
				AvailableXDTOVersions.Add(FormatVersion);
			EndDo;
			
			ExportSupportedFormatObjects(TitleXDTOMessages,
				HeaderParameters.SupportedObjects, HeaderParameters.CorrespondentNode);
		Else
			ExchangePlanName = BroadcastName(HeaderParameters.ExchangePlanName, "ru");
			XDTOConfirmation.ExchangePlan = ExchangePlanName;
			XDTOConfirmation.To           = HeaderParameters.RecipientIdentifier;
			
			If ValueIsFilled(HeaderParameters.PredefinedNodeAlias) Then
				// 
				XDTOConfirmation.From = HeaderParameters.PredefinedNodeAlias;
			Else
				XDTOConfirmation.From = HeaderParameters.SenderID;
			EndIf;
		
			XDTOConfirmation.MessageNo  = HeaderParameters.MessageNo;
			XDTOConfirmation.ReceivedNo = HeaderParameters.ReceivedNo;
			
			TitleXDTOMessages.Confirmation = XDTOConfirmation;
			
			For Each FormatVersion In HeaderParameters.SupportedVersions Do
				AvailableXDTOVersions.Add(FormatVersion);
			EndDo;
			
			If ValueIsFilled(HeaderParameters.PredefinedNodeAlias) Then
				// 
				// 
				TitleXDTOMessages.NewFrom = HeaderParameters.SenderID;
			EndIf;
			
			ExportSupportedFormatObjects(TitleXDTOMessages,
				HeaderParameters.SupportedObjects, HeaderParameters.CorrespondentNode);
			
			TitleXDTOMessages.Prefix = HeaderParameters.Prefix;
			
			If Not HeaderParameters.ExchangeViaProcessingUploadUploadED Then
				DataExchangeLoopControl.ExportCircuitToMessage(TitleXDTOMessages, HeaderParameters.ExchangePlanName);
			EndIf;
			
		EndIf;
		
	Else
		AvailableXDTOVersions.Add(HeaderParameters.ExchangeFormatVersion);
	EndIf;
	
	XDTOFactory.WriteXML(ExchangeFile, TitleXDTOMessages);
	
EndProcedure

// Parameters:
//   XDTODataObject - XDTODataObject
//   XDTOType - XDTOObjectType
//   Context - Structure
//   Cancel - Boolean
//   ErrorDescription - String
//
Procedure CheckXDTOObjectBySchema(XDTODataObject, XDTOType, Context, Cancel, ErrorDescription)
	
	DetailedPresentation        = "";
	UserPresentation1 = "";
	
	Try
		XDTODataObject.Validate();
	Except
		Cancel = True;
		DetailedPresentation = ErrorProcessing.DetailErrorDescription(ErrorInfo());
	EndTry;
	
	If Cancel Then
		ErrorsStack = New Array;
		FillXDTOObjectCheckErrors(XDTODataObject, XDTOType, ErrorsStack);
		
		If ErrorsStack.Count() > 0 Then
			UserPresentation1 = XDTOType.Name;
			For Each CurrentError In ErrorsStack Do
				UserPresentation1 = UserPresentation1 + Chars.LF + CurrentError;
			EndDo;
		EndIf;
	EndIf;
	
	ErrorDescription = New Structure("BriefPresentation, DetailedPresentation");
	
	UserErrorMessageTemplate =
	NStr("en = 'Cannot convert to ""%1"":
	|%2
	|
	|Details:
	|Direction: %3.
	|DPR: %4.
	|OCR: %5.
	|Object: %6.
	|
	|For more details, see the Event Log.';");
	
	EventLogErrorMessageTemplate = 
	NStr("en = 'Direction: %1.
	|DER: %2.
	|OCR: %3.
	|Object: %4.
	|
	|%5';");
	
	ErrorDescription.BriefPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		UserErrorMessageTemplate,
		XDTOType.Name,
		UserPresentation1,
		Context.ExchangeDirection,
		Context.DPRName,
		Context.OCRName,
		Context.ObjectPresentation);
	ErrorDescription.DetailedPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		EventLogErrorMessageTemplate,
		Context.ExchangeDirection,
		Context.DPRName,
		Context.OCRName,
		Context.ObjectPresentation,
		DetailedPresentation);
	
EndProcedure

Procedure FillXDTOObjectCheckErrors(XDTODataObject, XDTOObjectType, ErrorsStack, Val Level = 1)
	
	ToOutputError = (Level = 1);
	
	For Each Property In XDTOObjectType.Properties Do
		If Not XDTODataObject.IsSet(Property) Then
			If Property.LowerBound = 1
				And Not Property.Nillable Then
				Indent = StringFunctionsClientServer.GenerateCharacterString("  ", Level);
				ErrorMessage = Indent + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1: required field is blank.';"),
					Property.Name);
				ErrorsStack.Add(ErrorMessage);
			EndIf;
			Continue;
		Else
			XDTOPropertyValue = Undefined;
			IsXDTOList = False;
			If Property.UpperBound = 1 Then
				XDTOPropertyValue = XDTODataObject.GetXDTO(Property);
			Else
				XDTOPropertyValue = XDTODataObject.GetList(Property);
				IsXDTOList = True;
			EndIf;
			
			If XDTOPropertyValue = Undefined Then
				Continue;
			EndIf;
			
			If TypeOf(XDTOPropertyValue) = Type("XDTODataValue") Then
				Try
					Property.Type.Validate(XDTOPropertyValue.LexicalValue);
				Except
					Indent = StringFunctionsClientServer.GenerateCharacterString("  ", Level);
					ErrorMessage = Indent + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1: field value is invalid.';"),
						Property.Name);
					ErrorsStack.Add(ErrorMessage);
				EndTry;
			ElsIf IsXDTOList Then
				Cnt = 0;
				For Each XDTOListItem In XDTOPropertyValue Do
					Cnt = Cnt + 1;
					NewErrorsStack = New Array;
					FillXDTOObjectCheckErrors(XDTOListItem, Property.Type, NewErrorsStack, Level + 1);
					
					If NewErrorsStack.Count() > 0 Then
						Indent = StringFunctionsClientServer.GenerateCharacterString("  ", Level);
						ErrorMessage = Indent + Property.Name + "[" + XMLString(Cnt) + "]";
						ErrorsStack.Add(ErrorMessage);
						For Each NewError In NewErrorsStack Do
							ErrorsStack.Add(NewError);
						EndDo;
					EndIf;
				EndDo;
			Else
				NewErrorsStack = New Array;
				FillXDTOObjectCheckErrors(XDTOPropertyValue, Property.Type, NewErrorsStack, Level + 1);
				
				If NewErrorsStack.Count() > 0 Then
					Indent = StringFunctionsClientServer.GenerateCharacterString("  ", Level);
					ErrorMessage = Indent + Property.Name;
					ErrorsStack.Add(ErrorMessage);
					For Each NewError In NewErrorsStack Do
						ErrorsStack.Add(NewError);
					EndDo;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region GetData

#Region ObjectsConversion

#Region XDTOToStructureConversion

Procedure ConvertXDTOPropertyToStructureItem(Source, Property, Receiver,
	ExchangeComponents, NameForCompositeTypeProperty = "", PropertyType1 = Undefined)
	
	If Not Source.IsSet(Property) Then
		Return;
	EndIf;
	
	PropertyNamespace = Property.NamespaceURI;
	
	If Not NamespaceActive(ExchangeComponents, PropertyNamespace) Then
		Return;
	EndIf;
	
	PropertyName = ?(NameForCompositeTypeProperty = "", Property.Name, NameForCompositeTypeProperty);
	
	XDTODataValue = Source.GetXDTO(Property);
	If PropertyType1 <> Undefined Then
		
		XDTOValueType = PropertyType1;
		
	ElsIf XDTODataValue <> Undefined Then
		
		XDTOValueType = XDTOPropertyValueType(ExchangeComponents, Property, XDTODataValue);
		
	Else
		
		Return;
		
	EndIf;
	
	Try
		If TypeOf(XDTODataValue) = Type("XDTODataValue") Then
			
			ConvertSimpleProperty(Receiver, PropertyName, XDTODataValue, XDTOValueType);
			
		ElsIf TypeOf(XDTODataValue) = Type("XDTODataObject") Then
			
			// 
			// 
			// 
			// 
			// 
			// 
			
			XDTOValueClass = XDTOValueClassName(Property, XDTOValueType);
			
			If XDTOValueClass = ArbitraryDataClass() Then // 
				
				Value = XDTOSerializer.ReadXDTO(XDTODataValue);
				Receiver.Insert(PropertyName, Value);
				
			ElsIf XDTOValueClass = ObjectTableClass() Then
				
				ConvertObjectTable(Receiver, ExchangeComponents, PropertyName, Property, XDTOValueType, XDTODataValue);
				
			ElsIf XDTOValueClass = ClassKeyFormatProperties() Then
				
				ConvertKeyProperty(Receiver, ExchangeComponents, PropertyName, XDTOValueType, XDTODataValue);
				
			ElsIf XDTOValueClass = CommonPropertiesClass() Then 
				
				ConvertCommonProperty(Receiver, ExchangeComponents, PropertyName, XDTOValueType, XDTODataValue);
				
			Else
				
				ConvertCompositeProperty(Receiver, ExchangeComponents, PropertyName, XDTOValueType, XDTODataValue);
				
			EndIf;
		EndIf;
	Except
		ErrorPresentation = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'XDTO object reading error. Property: <%1>.';"), PropertyName)
			+ Chars.LF + Chars.LF + ErrorPresentation;
		Raise ErrorText;
	EndTry;
	
EndProcedure

Function ReadXDTOValue(XDTODataValue, PropertyType1 = Undefined)
	
	PropertyType1 = ?(PropertyType1 = Undefined, XDTODataValue.Type(), PropertyType1);
	
	If XDTODataValue = Undefined Then
		Return Undefined;
	EndIf;
	
	If IsXDTORef(PropertyType1) Then // Convert a reference.
		
		Value = ReadComplexTypeXDTOValue(XDTODataValue, "Ref", PropertyType1);
		
	ElsIf XDTODataValue.Type().Facets <> Undefined
		And XDTODataValue.Type().Facets.Enumerations <> Undefined
		And XDTODataValue.Type().Facets.Enumerations.Count() > 0 Then // 
		
		Value = ReadComplexTypeXDTOValue(XDTODataValue, "Enum", PropertyType1);
		
	Else // 
		
		Value = XDTODataValue.Value;
		
	EndIf;
	
	Return Value;
	
EndFunction

Function ReadComplexTypeXDTOValue(XDTODataValue, ComplicatedType, PropertyType1 = Undefined)

	PropertyType1 = ?(PropertyType1 = Undefined, XDTODataValue.Type(), PropertyType1);
		
	XDTOStructure = New Structure;
	XDTOStructure.Insert("IsReference", ComplicatedType = "Ref");
	XDTOStructure.Insert("IsEnum", ComplicatedType = "Enum");
	XDTOStructure.Insert("XDTOValueType", PropertyType1);
		
	If ComplicatedType = "Enum" Then
		Value = BroadcastName(XDTODataValue.Value, "en");
		XDTOStructure.Insert("Value", Value);
	Else
		XDTOStructure.Insert("Value", XDTODataValue.Value);
	EndIf;
	
	Return XDTOStructure;
	
EndFunction

// Parameters:
//   Table - ValueTable - a table for the columns initialization.
//   Type - XDTOObjectType - object type.
//
Procedure InitializeObjectTableColumnsByType(Table, Val Type)
	
	For Each Column In Type.Properties Do
		If StrFind(Column.Type.Name, CommonPropertiesClass()) > 0 Then
			InitializeObjectTableColumnsByType(Table, Column.Type);
		Else
			Table.Columns.Add(Column.Name);
		EndIf;
	EndDo;
	
EndProcedure

// Definition of the XDTO property type.
//
// If the property belongs to the base XDTO package, you can get the type by a direct access of the Type() method.
// If the passed property belongs to the XDTO package extension, the Type() method access returns AnyType.
// That is the type will not be identified. 
//
// To get the property type from the extension:
//  1. Get a name of the base object (the object to be extended).
//  2. Get the object from the extension by the base object name.
//  3. Select the property with a required name from the P2 object and read its type.
//
// Returns:
//  XDTOValueType - 
//
Function XDTOPropertyValueType(Val ExchangeComponents, Val XDTOProperty, XDTODataValue)
	
	Result = XDTODataValue.Type();
	If XDTOProperty.OwnerObject = Undefined Then
		
		// 
		// 
		Return Result;
		
	EndIf;
	
	PropertyNamespace = XDTOProperty.NamespaceURI;
	If IsBaseSchema(ExchangeComponents, PropertyNamespace) Then
		
		Return Result;
		
	EndIf;
	
	TypeOfThePropertyOwnerSXDTO = XDTOProperty.OwnerObject.Type();
	
	OwnerNamespace = TypeOfThePropertyOwnerSXDTO.NamespaceURI;
	If Not IsBaseSchema(ExchangeComponents, OwnerNamespace) Then
		
		// 
		Return Result;
		
	EndIf;
	
	TheXDTOObjectOfTheExtension = XDTOFactory.Type(PropertyNamespace, TypeOfThePropertyOwnerSXDTO.Name);
	If TheXDTOObjectOfTheExtension <> Undefined Then
		
		PropertyOfTheExtensionSXDTOObject = TheXDTOObjectOfTheExtension.Properties.Get(XDTOProperty.Name);
		If PropertyOfTheExtensionSXDTOObject <> Undefined Then
			
			Result = PropertyOfTheExtensionSXDTOObject.Type;
			
		EndIf;
		

	EndIf;
	
	Return Result;	
	
EndFunction

// Defining class for the property value.
// The class is used to select an algorithm of converting into a structure.
//
Function XDTOValueClassName(Val XDTOProperty, Val XDTOValueType)
	
	If XDTOProperty.Name = "AdditionalInfo" Then
		Return ArbitraryDataClass();
	ElsIf IsObjectTableType(XDTOValueType) Then
		Return ObjectTableClass();
	ElsIf StrFind(XDTOValueType.Name, KeyPropertiesClass()) > 0 Then
		Return KeyPropertiesClass();
	ElsIf StrFind(XDTOValueType.Name, ClassKeyFormatProperties()) > 0 Then
		Return ClassKeyFormatProperties();
	ElsIf StrFind(XDTOValueType.Name, CommonPropertiesClass()) > 0 Then
		Return CommonPropertiesClass();
	EndIf;
	
	Return CompositePropertiesClass();
	
EndFunction

// Encapsulation of algorithms of converting the XDTO object properties into the structure elements
//
Procedure ConvertSimpleProperty(Receiver,Val PropertyName, Val XDTODataValue, Val PropertyType1)
	
	Value = ReadXDTOValue(XDTODataValue, PropertyType1);
	
	If TypeOf(Receiver) = Type("Structure") Then
		Receiver.Insert(PropertyName, Value);
	Else
		
		If TypeOf(Receiver) = Type("ValueTableRow")
			And Receiver.Owner().Columns.Find(PropertyName) = Undefined Then
			Return;
		EndIf;
		
		Receiver[PropertyName] = Value;
	EndIf;
	
EndProcedure

Procedure ConvertObjectTable(Receiver, Val ExchangeComponents, Val PropertyName, Val XDTOProperty, Val XDTOValueType, Val XDTODataValue)
	
	// Initializing a value table displaying a tabular section of the object.
	Value = New ValueTable;
	InitializeObjectTableColumnsByType(Value, XDTOValueType.Properties[0].Type);
	
	// Append the table with the active extensions' properties.
	If IsBaseSchema(ExchangeComponents, XDTOProperty.NamespaceURI) Then
		
		ExtendObjectTableProperties(Value, XDTOProperty.OwnerType.Name, PropertyName, ExchangeComponents.FormatExtensions);
		
	EndIf;
	
	XDTOTabularSection = XDTODataValue.Строка;
	If TypeOf(XDTOTabularSection) <> Type("XDTOList") Then
		
		ArrayOfObjectsXDTO = New Array(1);
		ArrayOfObjectsXDTO[0] = XDTOTabularSection;
		
		XDTOTabularSection = ArrayOfObjectsXDTO;
		
	EndIf;
	
	RowXDTOValueType = XDTOValueType.Properties[0].Type;
	For Each XDTORow In XDTOTabularSection Do
		
		TSRow = Value.Add();
		For Each TSRowProperty In XDTORow.Properties() Do
			
			PropertyTypeRow = Undefined;
			
			IsBaseSchema = IsBaseSchema(ExchangeComponents, TSRowProperty.NamespaceURI);
			If IsBaseSchema Then
				
				PropertyTypeRow = TSRowProperty.Type;
				
			Else
				
				PropertyTypeRow = TypeOfNestedPropertyByNameFromFormatExtension(ExchangeComponents, RowXDTOValueType.Name, TSRowProperty.Name);
				
			EndIf;
			
			ConvertXDTOPropertyToStructureItem(XDTORow, TSRowProperty, TSRow, ExchangeComponents, , PropertyTypeRow);
			
		EndDo;
		
	EndDo;
	
	Receiver.Insert(PropertyName, Value);
	
EndProcedure

Procedure ConvertCommonProperty(Receiver, Val ExchangeComponents, Val PropertyName, Val XDTOValueType, Val XDTODataValue)

	If TypeOf(Receiver) = Type("Structure") Then 
		PropertiesGroupDestination = New Structure;
		For Each SubProperty In XDTODataValue.Properties() Do
			PropertyDetails = XDTOValueType.Properties.Get(SubProperty.Name);
			If PropertyDetails = Undefined Then
				Continue;
			EndIf;
			
			ConvertXDTOPropertyToStructureItem(XDTODataValue, SubProperty, PropertiesGroupDestination, ExchangeComponents,,PropertyDetails.Type);
			
		EndDo;
		Receiver.Insert(PropertyName, PropertiesGroupDestination);
		// 
		// 
		HasKeyProperties = Receiver.Property(KeyPropertiesClass());
		For Each GroupProperty In PropertiesGroupDestination Do
			SubpropertyName = GroupProperty.Key;
			If Not Receiver.Property(SubpropertyName)
				And Not (HasKeyProperties And Receiver[KeyPropertiesClass()].Property(SubpropertyName)) Then
				Receiver.Insert(SubpropertyName, GroupProperty.Value);
			EndIf;
		EndDo;
	Else
		
		For Each SubProperty In XDTODataValue.Properties() Do
			PropertyDetails = XDTOValueType.Properties.Get(SubProperty.Name);
			If PropertyDetails = Undefined Then
				Continue;
			EndIf;
			
			ConvertXDTOPropertyToStructureItem(XDTODataValue, SubProperty, Receiver, ExchangeComponents,,PropertyDetails.Type);
			
		EndDo;
		
	EndIf;
				
EndProcedure

Procedure ConvertKeyProperty(Receiver, Val ExchangeComponents, Val PropertyName, Val XDTOValueType, Val XDTODataValue)
	
	Value = New Structure("IsKeyPropertiesSet");
	Value.Insert("ValueType", StrReplace(XDTOValueType.Name, ClassKeyFormatProperties(), ""));

	For Each KeyProperty In XDTODataValue.Properties() Do
		PropertyDetails = XDTOValueType.Properties.Get(KeyProperty.Name);
		If PropertyDetails = Undefined Then
			Continue;
		EndIf;
		
		ConvertXDTOPropertyToStructureItem(XDTODataValue, KeyProperty, Value, ExchangeComponents,,PropertyDetails.Type);
	EndDo;
	
	AddThePropertiesOfActiveExtensionsToTheTable(ExchangeComponents, XDTOValueType, XDTODataValue, Value);
	
	If TypeOf(Receiver) = Type("Structure") Then
		Receiver.Insert(PropertyName, Value);
	Else
		Receiver[PropertyName] = Value;
	EndIf;

EndProcedure

Procedure ConvertCompositeProperty(Receiver, Val ExchangeComponents, Val PropertyName, Val XDTOValueType, Val XDTODataValue)

	Value = Undefined;
	For Each SubProperty In XDTODataValue.Properties() Do
		
		PropertyDetails = XDTOValueType.Properties.Get(SubProperty.Name);
		If PropertyDetails = Undefined Then
			Continue;
		EndIf;

		If Not XDTODataValue.IsSet(SubProperty) Then
			Continue;
		EndIf;
		
		ConvertXDTOPropertyToStructureItem(XDTODataValue, SubProperty, Receiver, ExchangeComponents, PropertyName, PropertyDetails.Type);
		Break;
		
	EndDo;

EndProcedure

// Formalization of the property value classes
//
Function CommonPropertiesClass()
	
	Return "ОбщиеСвойства"; // @Non-NLS
	
EndFunction

Function CompositePropertiesClass()
	
	Return "СоставныеСвойства"; // @Non-NLS
	
EndFunction

Function ArbitraryDataClass()
	
	Return "ПроизвольныеДанные"; // @Non-NLS
	
EndFunction

Function ObjectTableClass()
	
	Return "ТаблицаОбъекта"; // @Non-NLS
	
EndFunction

Function LinkClass()

	Return "Ref";
	
EndFunction

Function FormatReferenceClass()

	Return "Ссылка"; // @Non-NLS
	
EndFunction

#EndRegion

#Region StructureConversionToIBData

Procedure ConversionOfXDTOObjectStructureProperties(
		ExchangeComponents,
		XDTOData,
		ReceivedData,
		ConversionRule,
		StageNumber = 1,
		PropertiesComposition = "All")
	
	Try
		For Each PCR In ConversionRule.Properties Do
			
			If PropertiesComposition = "SearchProperties"
				And Not PCR.SearchPropertyHandler Then
				Continue;
			EndIf;
			
			ConversionOfXDTOObjectStructureProperty(
				ExchangeComponents,
				XDTOData,
				ReceivedData.AdditionalProperties,
				ReceivedData,
				PCR,
				StageNumber);
			
		EndDo;
			
		If PropertiesComposition = "SearchProperties" Then
			Return;
		EndIf;
		
		// Convert tables.
		For Each TS In ConversionRule.TabularSectionsProperties Do
			
			If StageNumber = 1 And ValueIsFilled(TS.TSConfigurations) And ValueIsFilled(TS.FormatTS) Then
				
				// 
				FormatTS = Undefined; // ValueTable
				If Not XDTOData.Property(TS.FormatTS, FormatTS) Then
					Continue;
				ElsIf FormatTS.Count() = 0 Then
					Continue;
				EndIf;
				
				TSColumnsArray = New Array;
				For Each TSColumn In FormatTS.Columns Do
					TSColumnsArray.Add(TSColumn.Name);
				EndDo;
				
				ColumnsNamesAsString = StrConcat(TSColumnsArray, ",");
				For LineNumber = 1 To FormatTS.Count() Do
					
					XDTORowData = FormatTS[LineNumber - 1];
					TSRow = ReceivedData[TS.TSConfigurations].Add();
					XDTORowDataStructure = New Structure(ColumnsNamesAsString);
					FillPropertyValues(XDTORowDataStructure, XDTORowData);
					
					For Each PCR In TS.Properties Do
						If PCR.UsesConversionAlgorithm Then
							Continue;
						EndIf;
						ConversionOfXDTOObjectStructureProperty(
							ExchangeComponents,
							XDTORowDataStructure,
							ReceivedData.AdditionalProperties,
							TSRow,
							PCR,
							StageNumber);
					EndDo;
					
				EndDo;
				
			EndIf;
			
			If StageNumber = 2 And TS.UsesConversionAlgorithm
				And ValueIsFilled(TS.TSConfigurations)
				And ReceivedData.AdditionalProperties.Property(TS.TSConfigurations) Then
 				StructuresArrayWithRowsData = ReceivedData.AdditionalProperties[TS.TSConfigurations];
				ConfigurationTSRowsCount = ReceivedData[TS.TSConfigurations].Count();
				
				For LineNumber = 1 To StructuresArrayWithRowsData.Count() Do
					
					// The string might have been added upon direct conversion.
					If LineNumber <= ConfigurationTSRowsCount Then
						TSRow = ReceivedData[TS.TSConfigurations][LineNumber - 1];
					Else
						TSRow = ReceivedData[TS.TSConfigurations].Add();
					EndIf;
					
					For Each PCR In TS.Properties Do
						
						If Not PCR.UsesConversionAlgorithm Then
							Continue;
						EndIf;
						
						ConversionOfXDTOObjectStructureProperty(
							ExchangeComponents,
							XDTOData,
							ReceivedData.AdditionalProperties,
							TSRow,
							PCR,
							StageNumber, 
							TS.TSConfigurations);
						
					EndDo;
					
				EndDo;
			EndIf;
			
		EndDo;
	Except
		ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Event: %1.
				|Object: %2.
				|
				|Property conversion error.
				|%3.';"),
			ExchangeComponents.ExchangeDirection,
			ObjectPresentationForProtocol(ReceivedData),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise ErrorText;
	EndTry;
	
EndProcedure

Procedure ConversionOfXDTOObjectStructureProperty(
		ExchangeComponents,
		XDTOData,
		AdditionalProperties,
		DataTarget,
		PCR,
		StageNumber = 1,
		TSName = "")
	// PCR with only format property specified is being processed. It is used only upon export.
	If TrimAll(PCR.ConfigurationProperty) = "" Then
		Return;
	EndIf;
	
	PropertyConversionRule = PCR.PropertyConversionRule;
	
	PropertyValue = "";
	Try
		If StageNumber = 1 Then
			
			If Not ValueIsFilled(PCR.FormatProperty) Then
				Return;
			EndIf;
			
			If PCR.KeyPropertyProcessing
				And Not XDTOData.Property("IsKeyPropertiesSet") Then
				DataSource = XDTOData[KeyPropertiesClass()];
			Else
				DataSource = XDTOData;
			EndIf;
			
			FormatPropertyName = TrimAll(PCR.FormatProperty);
			PointPosition = StrFind(FormatPropertyName, ".");
			// A full property name is specified. The property is included in the common properties group.
			If PointPosition > 0 Then
				NestedProperties = StrSplit(FormatPropertyName,".",False);
				GetNestedPropertiesValue(DataSource, NestedProperties, PropertyValue);
			Else
				
				If Not DataSource.Property(FormatPropertyName, PropertyValue)
					And Not PCR.KeyPropertyProcessing 
					And Not PCR.UsesConversionAlgorithm
					Then
					
					If DataTarget.AdditionalProperties.Property("PropertiesThatAreMissingInTheReceivedData") Then
						
						DataTarget.AdditionalProperties.PropertiesThatAreMissingInTheReceivedData = DataTarget.AdditionalProperties.PropertiesThatAreMissingInTheReceivedData + "," + FormatPropertyName;
						
					Else
						
						DataTarget.AdditionalProperties.Insert("PropertiesThatAreMissingInTheReceivedData", FormatPropertyName);
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		ElsIf StageNumber = 2 Then
			
			If StageNumber = 2 And Not PCR.UsesConversionAlgorithm Then
				Return;
			EndIf;
			
			// 
			// 
			// 
			// 
			If ValueIsFilled(TSName) Then
				DataSource = AdditionalProperties[TSName][DataTarget.LineNumber - 1];
			Else
				DataSource = AdditionalProperties;
			EndIf;
			
			If DataSource.Property(PCR.ConfigurationProperty) Then
				PropertyValue = DataSource[PCR.ConfigurationProperty];
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(PropertyValue) Then
			Return;
		EndIf;
		
		DeleteObjectsCreatedByKeyProperties = ExchangeComponents.DeleteObjectsCreatedByKeyProperties;
		If TypeOf(PropertyValue) = Type("Structure")
			And PropertyValue.Property("OCRName")
			And PropertyValue.Property("Value") Then
			
			// Instruction is the value.
			If PropertyValue.Property("DeleteObjectsCreatedByKeyProperties") Then
				DeleteObjectsCreatedByKeyProperties = PropertyValue.DeleteObjectsCreatedByKeyProperties;
			EndIf;
			
			PropertyConversionRule = PropertyValue.OCRName;
			PropertyValue           = PropertyValue.Value;
			
		EndIf;
		
		If TypeOf(PropertyValue) = Type("Structure") Then
			If Not ValueIsFilled(PropertyConversionRule) Then
				Return;
			EndIf;
			
			PDCR = ExchangeComponents.PredefinedDataConversionRules.Find(PropertyConversionRule, "PDCRName");
			If PDCR <> Undefined Then
				
				Value = PDCR.ConvertValuesOnReceipt.Get(PropertyValue.Value);
				DataTarget[PCR.ConfigurationProperty] = Value;
				Return;
				
			Else
				PropertyConversionRule = OCRByName(ExchangeComponents, PropertyConversionRule);
			EndIf;
		Else
			// Конвертацию простых свойств выполняем только на 1-
			DataTarget[PCR.ConfigurationProperty] = PropertyValue;
			Return;
		EndIf;
		
		ConversionRule = New Structure("ConversionRule, DeleteObjectsCreatedByKeyProperties",
			PropertyConversionRule, DeleteObjectsCreatedByKeyProperties);
		DataToWriteToIB = XDTOObjectStructureToIBData(ExchangeComponents, PropertyValue, ConversionRule, "GetRef");
		
		If DataToWriteToIB <> Undefined Then
			DataTarget[PCR.ConfigurationProperty] = DataToWriteToIB.Ref;
		EndIf;
		
	Except
		ErrorPresentation = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'XDTO object property conversion error. Property: <%1>.';"), PCR.ConfigurationProperty)
			+ Chars.LF + Chars.LF + ErrorPresentation;
		Raise ErrorText;
	EndTry;
	
EndProcedure

Function ObjectRefByXDTOObjectProperties(ConversionRule, ReceivedData, XDTODataContainRef, ExchangeComponents, OriginalUIDIsString = "")

	ExchangeNode = ExchangeComponents.CorrespondentNode;
	
	Result = Undefined;
	// 
	//	
	If ConversionRule.SearchFields = Undefined
		Or TypeOf(ConversionRule.SearchFields) <> Type("Array") Then
		Return Result;
	EndIf;
	
	For Each SearchAttempt In ConversionRule.SearchFields Do
		SearchFields = New Structure(SearchAttempt);
		FillPropertyValues(SearchFields, ReceivedData);
		
		// 
		// 
		// 
		// 
		// 
		HasBlankFields = False;
		For Each FieldForSearch In SearchFields Do
			If Not ValueIsFilled(FieldForSearch.Value) Then
				If (ConversionRule.IsCatalog Or ConversionRule.IsChartOfCharacteristicTypes)
					And FieldForSearch.Key = "Parent" Then
					Continue;
				EndIf;
				
				HasBlankFields = True;
				Break;
			EndIf;
		EndDo;
		If HasBlankFields Then
			// Going to the next search option.
			Continue;
		EndIf;
		
		IdentificationOption = TrimAll(ConversionRule.IdentificationOption);
		AnalyzePublicIDs = IdentificationOption = "FirstByUUIDThenBySearchFields"
			And XDTODataContainRef
			And ValueIsFilled(ExchangeNode);
			
		SearchByQuery = False;
		If AnalyzePublicIDs Then
			SearchByQuery = True;
		Else
			// Perhaps, the search can be carried out by platform methods.
			If ConversionRule.IsDocument
				And SearchFields.Count() = 2
				And SearchFields.Property("Date")
				And SearchFields.Property("Number") Then
				Result = ConversionRule.ObjectManager.FindByNumber(SearchFields.Number, SearchFields.Date);
				Result = ?(Result.IsEmpty(), Undefined, Result);
			ElsIf ConversionRule.IsCatalog
				And SearchFields.Count() = 1
				And SearchFields.Property("Description") Then
				Result = ConversionRule.ObjectManager.FindByDescription(SearchFields.Description, True);
			ElsIf ConversionRule.IsCatalog
				And SearchFields.Count() = 1
				And SearchFields.Property("Code") Then
				Result = ConversionRule.ObjectManager.FindByCode(SearchFields.Code);
			Else
				SearchByQuery = True;
			EndIf;
		EndIf;
		
		If SearchByQuery Then
			Query = New Query;
			
			QueryText =
			"SELECT
			|	Table.Ref AS Ref
			|FROM
			|	&FullName AS Table
			|WHERE
			|	&FilterCriterion";
			
			Filter = New Array;
			
			For Each FieldForSearch In SearchFields Do
				
				If DataExchangeCached.IsStringAttributeOfUnlimitedLength(ConversionRule.FullName, FieldForSearch.Key) Then
					
					FilterAsString = "CAST(Table.[Key] AS STRING([StringLength])) = &[Key]";
					FilterAsString = StrReplace(FilterAsString, "[Key]", FieldForSearch.Key);
					FilterAsString = StrReplace(FilterAsString, "[StringLength]", Format(StrLen(FieldForSearch.Value), "NG=0"));
					Filter.Add(FilterAsString);
					
				Else
					
					Filter.Add(StrReplace("Table.[Key] = &[Key]", "[Key]", FieldForSearch.Key));
					
				EndIf;
				
				Query.SetParameter(FieldForSearch.Key, FieldForSearch.Value);
				
			EndDo;
			
			FilterCriterion = StrConcat(Filter, " And ");
			
			UseCacheOfPublicIdentifiers = ExchangeComponents.UseCacheOfPublicIdentifiers;
			If AnalyzePublicIDs And Not UseCacheOfPublicIdentifiers Then
				
				// Excluding the objects mapped earlier from the search.
				If Not IsBlankString(OriginalUIDIsString) Then
					
					JoinText = " LEFT JOIN InformationRegister.SynchronizedObjectPublicIDs AS PublicIDs
					|	ON PublicIDs.Ref = Table.Ref 
					|		AND PublicIDs.InfobaseNode = &ExchangeNode 
					|		AND PublicIDs.Id <> &OriginalUIDIsString";
					
					Query.SetParameter("OriginalUIDIsString", OriginalUIDIsString);
					
				Else
					
					JoinText = " LEFT JOIN InformationRegister.SynchronizedObjectPublicIDs AS PublicIDs
						|	ON PublicIDs.Ref = Table.Ref 
						|		AND PublicIDs.InfobaseNode = &ExchangeNode";
					
				EndIf;
				
				FilterCriterion = FilterCriterion + Chars.LF + " AND PublicIDs.Ref IS null";
				QueryText = StrReplace(QueryText,  "WHERE", JoinText + Chars.LF + "	WHERE");
				Query.SetParameter("ExchangeNode", ExchangeNode);
				
			EndIf;
			
			QueryText = StrReplace(QueryText, "&FilterCriterion", FilterCriterion);
			QueryText = StrReplace(QueryText, "&FullName", ConversionRule.FullName);
			Query.Text = QueryText;
			
			QueryResult = Query.Execute();
			
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
								
				If UseCacheOfPublicIdentifiers Then
					RecordStructure = New Structure("Ref", Selection.Ref);
					
					If AnalyzePublicIDs 
						And EntryIsInCacheOfPublicIdentifiers(RecordStructure, ExchangeComponents) Then
						Continue;
					EndIf;
				EndIf;
				
				Result = Selection.Ref;
				
			EndIf;
			
		EndIf;
		If ValueIsFilled(Result) Then
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillIBDataByReceivedData(IBData, ReceivedData, ConversionRule)
	
	PropertiesThatAreMissingInTheReceivedData = New Array;
	If ReceivedData.AdditionalProperties.Property("PropertiesThatAreMissingInTheReceivedData") Then
		
		PropertiesThatAreMissingInTheReceivedData = StrSplit(ReceivedData.AdditionalProperties.PropertiesThatAreMissingInTheReceivedData, ",", False);
		
	EndIf;
	
	CopyFields = ConversionRule.Properties.UnloadColumn("ConfigurationProperty");
	If CopyFields.Count() > 0 Then
		
		For FieldNumber = 0 To CopyFields.UBound() Do
			
			CopyFields[FieldNumber] = TrimAll(CopyFields[FieldNumber]);
			
		EndDo;
		
		For NumberOfTheMissingField = 0 To PropertiesThatAreMissingInTheReceivedData.UBound() Do
			
			PropertiesThatAreMissingInTheReceivedData[NumberOfTheMissingField] = TrimAll(PropertiesThatAreMissingInTheReceivedData[NumberOfTheMissingField]);
			
			IndexOfTheMissingField = CopyFields.Find(PropertiesThatAreMissingInTheReceivedData[NumberOfTheMissingField]);
			If IndexOfTheMissingField <> Undefined Then
				
				CopyFields.Delete(IndexOfTheMissingField);
				
			EndIf;
			
		EndDo;
		
		FieldsCopied = StrConcat(CopyFields, ",");
		FieldsExcluded = StrConcat(PropertiesThatAreMissingInTheReceivedData, ",");
		
		FillPropertyValues(IBData, ReceivedData, FieldsCopied, FieldsExcluded);
		
	EndIf;
	
	For Each TSConversions In ConversionRule.TabularSectionsProperties Do
		
		TSName = TSConversions.TSConfigurations;
		
		If IsBlankString(TSName) Then
			Continue;
		EndIf;
		
		IBData[TSName].Clear();
		IBData[TSName].Load(ReceivedData[TSName].Unload());
		
	EndDo;
	
EndProcedure

Function InitializeReceivedData(ConversionRule)
	
	ReceivedData = Undefined;
	
	If ConversionRule.IsDocument Then
		ReceivedData = ConversionRule.ObjectManager.CreateDocument();
	ElsIf ConversionRule.IsCatalog
		Or ConversionRule.IsChartOfCharacteristicTypes Then
		ObjectManager = ConversionRule.ObjectManager; //CatalogManager
		If ConversionRule.RuleForCatalogGroup Then
			ReceivedData = ObjectManager.CreateFolder();
		Else
			ReceivedData = ObjectManager.CreateItem();
		EndIf;
	ElsIf ConversionRule.IsRegister Then
		ReceivedData = ConversionRule.ObjectManager.CreateRecordSet();
	ElsIf ConversionRule.IsBusinessProcess Then
		ReceivedData = ConversionRule.ObjectManager.CreateBusinessProcess();
	ElsIf ConversionRule.IsTask Then
		ReceivedData = ConversionRule.ObjectManager.CreateTask();
	ElsIf ConversionRule.IsChartOfAccounts Then
		ReceivedData = ConversionRule.ObjectManager.CreateAccount();
	ElsIf ConversionRule.IsChartOfCalculationTypes Then
		ReceivedData = ConversionRule.ObjectManager.CreateCalculationType();
	EndIf;
	
	Return ReceivedData;
	
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ExecuteNumberCodeGenerationIfNecessary(Object)
	
	ObjectTypeName = Common.ObjectKindByType(TypeOf(Object.Ref));
	
	// Using the document type, checking whether a code or a number is filled in.
	If ObjectTypeName = "Document"
		Or ObjectTypeName = "BusinessProcess"
		Or ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes" Then
		
		If Not ValueIsFilled(Object.Code)
			And Object.Metadata().Autonumbering Then
			
			Object.SetNewCode();
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RemoveDeletionMarkFromPredefinedItem(Object, ObjectType, ExchangeComponents)
	
	MarkPredefined = New Structure("DeletionMark, Predefined", False, False);
	FillPropertyValues(MarkPredefined, Object);
	
	If MarkPredefined.DeletionMark
		And MarkPredefined.Predefined Then
			
		Object.DeletionMark = False;
		
		// Adding the event log entry.
		WP            = ExchangeProtocolRecord(80);
		WP.ObjectType = ObjectType;
		WP.Object     = String(Object);
		
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult =
			Enums.ExchangeExecutionResults.CompletedWithWarnings;
		WriteToExecutionProtocol(ExchangeComponents, 80, WP, False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DeferredOperations
// Parameters:
//   DataToWriteToIB - CatalogObject
//                      - DocumentObject - 
//   ConversionRule - ValueTableRow - a string with a conversion rule.
//   ExchangeComponents - See DataExchangeXDTOServer.InitializeExchangeComponents
//
Procedure RememberObjectForDeferredFilling(DataToWriteToIB, ConversionRule, ExchangeComponents)
	
	If ConversionRule.HasHandlerAfterImportAllData Then
		
		// Adding the object data to the deferred processing table.
		NewRow = ExchangeComponents.ImportedObjects.Add();
		NewRow.HandlerName = ConversionRule.AfterImportAllData;
		NewRow.Object         = DataToWriteToIB;
		NewRow.ObjectReference = DataToWriteToIB.Ref;
		
	EndIf;
	
EndProcedure

Procedure DeleteTempObjectsCreatedByRefs(ExchangeComponents) Export
	
	ObjectsCreatedByRefsTable = ExchangeComponents.ObjectsCreatedByRefsTable;
	
	RowsObjectsToDelete = ObjectsCreatedByRefsTable.FindRows(New Structure("DeleteObjectsCreatedByKeyProperties", True));
	
	For Each TableRow In RowsObjectsToDelete Do
		
		ObjectReference = TableRow.ObjectReference;
		
		// Deleting an object reference from the deferred object filling table.
		DeferredFillingTableRow = ExchangeComponents.ImportedObjects.Find(ObjectReference, "ObjectReference");
		If DeferredFillingTableRow <> Undefined Then
			ExchangeComponents.ImportedObjects.Delete(DeferredFillingTableRow);
		EndIf;
		
		If ValueIsFilled(ObjectReference) Then
			
			ObjectCreatedByRef = ObjectReference.GetObject();
			If ObjectCreatedByRef <> Undefined Then
				
				DataExchangeServer.SetDataExchangeLoad(ObjectCreatedByRef, True, False, ExchangeComponents.CorrespondentNode);
				DeleteObject(ObjectCreatedByRef, True, ExchangeComponents);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ObjectsCreatedByRefsTable.Clear();
	
EndProcedure

Procedure DeferredObjectsFilling(ExchangeComponents)
	
	ConversionParameters_SSLy = ExchangeComponents.ConversionParameters_SSLy;
	ImportedObjects   = ExchangeComponents.ImportedObjects;
	
	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeComponents.ExchangeManager.BeforeDeferredFilling(ExchangeComponents);
		
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, "BeforeDeferredFilling", "",ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Direction: %1.
			|Handler: %2.
			|
			|Handler execution error.
			|%3.';");
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"BeforeDeferredFilling",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Raise ErrorText;
		
	EndTry;
	
	For Each TableRow In ImportedObjects Do
		
		If TableRow.Object.IsNew() Then
			Continue;
		EndIf;
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ObjectStringPresentation = ObjectPresentationForProtocol(TableRow.Object.Ref);
		
		BeginTransaction();
		Try
		    Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(TableRow.Object.Ref));
		    LockItem.SetValue("Ref", TableRow.Object.Ref);
		    Block.Lock();
		    
			Object = TableRow.Object.Ref.GetObject();
			
			// Transfer additional properties.
			For Each Property In TableRow.Object.AdditionalProperties Do
				Object.AdditionalProperties.Insert(Property.Key, Property.Value);
			EndDo;
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("Object",              Object);
			ParametersStructure.Insert("ExchangeComponents",    ExchangeComponents);
			ParametersStructure.Insert("ObjectIsModified", True);
			
			ExchangeComponents.ExchangeManager.ExecuteManagerModuleProcedure(TableRow.HandlerName, ParametersStructure);
			
			If ParametersStructure.ObjectIsModified Then
				DataExchangeServer.SetDataExchangeLoad(Object, True, False, ExchangeComponents.CorrespondentNode);
				Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
				
				Object.Write();
				
			EndIf;

		    CommitTransaction();
		Except
		    RollbackTransaction();
			
			ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|Object: %3.
				|
				|Handler execution error.
				|%4.';");
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
				ExchangeComponents.ExchangeDirection,
				"DeferredObjectsFilling",
				ObjectStringPresentation,
				ErrorProcessing.DetailErrorDescription(ErrorInfo())); 
			
			Raise ErrorText;
		EndTry;
		
		Event = "DeferredObjectsFilling" + TableRow.Object.Metadata().FullName();
			DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, Event, Object, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	EndDo;

EndProcedure

#EndRegion

#Region Other

Function NamespaceActive(Val ExchangeComponents, Val Namespace)
	
	Return IsBaseSchema(ExchangeComponents, Namespace)
		Or ExchangeComponents.FormatExtensions.Get(Namespace) <> Undefined;
	
EndFunction

Procedure IncludeNamespace(ExchangeComponents, Val Namespace, Val Alias = "") Export
	
	If IsBlankString(Namespace) Then
		Return;
	EndIf;
	
	ExchangeComponents.FormatExtensions.Insert(Namespace, Alias);
	
EndProcedure

Function IsBaseSchema(Val ExchangeComponents, Val Namespace)
	
	Return IsBlankString(Namespace) 
		Or ExchangeComponents.BaseFormatSchemas.Get(Namespace) <> Undefined;
		
EndFunction

Function ExtensionData(XDTOData, Val Namespace, Val CreateDataArea = True)
	
	If IsBlankString(Namespace) Then
		Return XDTOData;
	EndIf;
	
	If Not XDTOData.Property("Extensions") Then
		If Not CreateDataArea Then
			Return Undefined;
		EndIf;
			
		XDTOData.Insert("Extensions", New Map);
	EndIf;
	
	XDTOExtensionData = XDTOData.Extensions.Get(Namespace);
	If XDTOExtensionData = Undefined Then
		XDTOData.Extensions.Insert(Namespace, New Structure);
		
		XDTOExtensionData = XDTOData.Extensions.Get(Namespace);
	EndIf;
	
	Return XDTOExtensionData;
	
EndFunction

Procedure DeclareNamespaces(ExchangeFile, Val ExchangeComponents)
	
	ExchangeFile.WriteNamespaceMapping("", ExchangeComponents.XMLSchema);
	
	Counter = 1;
	UsedAliases = New Structure;
	For Each Namespace In ExchangeComponents.FormatExtensions Do
		If IsBlankString(Namespace.Value) 
			Or UsedAliases.Property(Namespace.Value) Then
			
			Namespace.Value = StrReplace("ex%1", "%1", XMLString(Counter));
			
			Counter = Counter + 1;
		EndIf;
			
		ExchangeFile.WriteNamespaceMapping(Namespace.Value, Namespace.Key);
		
		UsedAliases.Insert(Namespace.Value);
	EndDo;
	
EndProcedure

Procedure TableColumnByFieldFromExtension(ObjectTable, ColumnName)
	
	If ObjectTable.Columns.Find(ColumnName) <> Undefined Then
		
		Return;
		
	EndIf;
	
	ObjectTable.Columns.Add(ColumnName);
	
EndProcedure

Procedure ExtendObjectTableProperties(ObjectTable, Val ObjectName, Val ObjectTableName, Val FormatExtensions)
	
	If FormatExtensions.Count() < 1 Then
		
		Return;
		
	EndIf;
	
	ExtensionStringTemplate = "%1.%2.String";
	For Each Extension In FormatExtensions Do
		
		TypeTablePartString = XDTOFactory.Type(Extension.Key, StrTemplate(ExtensionStringTemplate, ObjectName, ObjectTableName));
		If TypeTablePartString = Undefined Then
			
			Continue;
			
		EndIf;
		
		For Each FieldFromExtension In TypeTablePartString.Properties Do
		
			If StrFind(FieldFromExtension.Type.Name, KeyPropertiesClass()) > 0 Then
				
				For Each SubordinateFieldFromTheExtension In FieldFromExtension.Type.Properties Do
					
					TableColumnByFieldFromExtension(ObjectTable, SubordinateFieldFromTheExtension.Name);
					
				EndDo;
				
			Else
				
				TableColumnByFieldFromExtension(ObjectTable, FieldFromExtension.Name);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure ReadExchangeMessage(ExchangeComponents, Results, TablesToImport = Undefined, AnalysisMode = False)
	
	Try
		ExchangeComponents.ExchangeManager.BeforeConvert(ExchangeComponents);
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Direction: %1.
			|Handler: %2.
			|
			|Handler execution error.
			|%3.';");
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"BeforeConvert",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Raise ErrorText;
		
	EndTry;
		
	ArrayOfObjectsToDelete   = New Array;
	ArrayOfImportedObjects = New Array;
		
	Results = New Structure;	
	Results.Insert("ArrayOfObjectsToDelete",   ArrayOfObjectsToDelete);
	Results.Insert("ArrayOfImportedObjects", ArrayOfImportedObjects);
	
	SetErrorFlag = False;
		
	While ExchangeComponents.ExchangeFile.NodeType = XMLNodeType.StartElement Do
		
		UpdateImportedObjectsCounter(ExchangeComponents);
		
		XDTOObjectType = XDTOFactory.Type(ExchangeComponents.ExchangeFile.NamespaceURI, ExchangeComponents.ExchangeFile.LocalName);
		XDTODataObject     = XDTOFactory.ReadXML(ExchangeComponents.ExchangeFile, XDTOObjectType); // 
		
		If XDTOObjectType = Undefined Then
			
			// 
			// 
			// 
			//  
			//  
			// 
			Continue;
			
		ElsIf XDTOObjectType.Name = "ObjectDeletion" Then
			
			// Importing a flag of object deletion - a specific logic.
			ReadDeletion(ExchangeComponents, XDTODataObject, ArrayOfObjectsToDelete, TablesToImport);
			Continue;
			
		EndIf;
		
		// Process DPR.
		ProcessingRule = DPRByXDTOObjectType(ExchangeComponents, XDTOObjectType.Name, True);
		
		If Not ValueIsFilled(ProcessingRule) Then
			Continue;
		EndIf;
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		// Converting XDTOObject to Structure.
		XDTOData = XDTODataObjectToStructure(XDTODataObject, ExchangeComponents);
		
		UsageOCR = New Structure;
		For Each OCRName In ProcessingRule.OCRUsed Do
			UsageOCR.Insert(OCRName, True);
		EndDo;
		
		Event = "XDTODataObjectToStructure" + XDTODataObject.Type().Name;
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime,Event, XDTOData, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeLibrary());
		
		AbortProcessing = False;
		
		OnProcessDPR(
			ExchangeComponents,
			ProcessingRule,
			XDTOData,
			UsageOCR,
			AbortProcessing);
		
		If AbortProcessing Then
			SetErrorFlag = True;
			Continue;
		EndIf;
		
		For Each CurrentOCR In UsageOCR Do
			Try
				ConversionRule = OCRByName(ExchangeComponents, CurrentOCR.Key);
			Except
				SetErrorFlag   = True;
				
				ErrorDescription = DPRErrorDescription(
					ExchangeComponents.ExchangeDirection,
					ProcessingRule.Name,
					XDTOObjectPresentationForProtocol(XDTOObjectType),
					ErrorInfo());
					
				RecordIssueOnProcessObject(ExchangeComponents,
					XDTOData,
					Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData,
					ErrorDescription.DetailedPresentation,
					ErrorDescription.BriefPresentation);
					
				Continue;
			EndTry;
			
			If Not FormatObjectPassesXDTOFilter(ExchangeComponents, ConversionRule.FormatObject) Then
				Continue;
			EndIf;
			
			If Not ObjectPassesTablesToImportFilter(
					TablesToImport, XDTOObjectType.Name, ConversionRule.ReceivedDataTypeAsString) Then
				Continue;
			EndIf;
			
			SynchronizeByID = SearchByID(ConversionRule.IdentificationOption)
				And XDTOData.Property(LinkClass());
				
			If Not CurrentOCR.Value Then
				If SynchronizeByID Then
					SupplementListOfObjectsForDeletion(ExchangeComponents,
						ConversionRule.DataType, XDTOData[LinkClass()].Value, ArrayOfObjectsToDelete);
				EndIf;
				Continue;
			EndIf;
			
			If AnalysisMode Then
				AddObjectToPackageTitleDataTable(ExchangeComponents,
					ConversionRule, XDTOObjectType.Name, SynchronizeByID);
				
				If SynchronizeByID Then
					ArrayOfImportedObjects.Add(
						ObjectRefByXDTODataObjectUUID(XDTOData[LinkClass()].Value, ConversionRule.DataType, ExchangeComponents));
				EndIf;
			Else
				If ExchangeComponents.DataImportToInfobaseMode
					Or TablesToImport <> Undefined Then
					
					DataToWriteToIB = Undefined;
					Try
						DataToWriteToIB = XDTOObjectStructureToIBData(
							ExchangeComponents,
							XDTOData,
							ConversionRule,
							?(ExchangeComponents.DataImportToInfobaseMode, "ConvertAndWrite", "Convert"));
					Except
						SetErrorFlag  = True;
						
						ErrorDescription = OCRErrorDescription(
							ExchangeComponents.ExchangeDirection,
							ProcessingRule.Name,
							ConversionRule.OCRName,
							XDTOObjectPresentationForProtocol(XDTOObjectType),
							ErrorInfo());
							
						RecordIssueOnProcessObject(ExchangeComponents,
							XDTOData,
							Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData,
							ErrorDescription.DetailedPresentation,
							ErrorDescription.BriefPresentation);
							
						Continue;
					EndTry;
						
				EndIf;
				
				If DataToWriteToIB = Undefined Then
					Continue;
				EndIf;
				
				If ExchangeComponents.DataImportToInfobaseMode Then
					
					If SearchByID(ConversionRule.IdentificationOption) Then
						ArrayOfImportedObjects.Add(DataToWriteToIB.Ref);
					EndIf;
					
				ElsIf TablesToImport <> Undefined Then
					
					ExecuteNumberCodeGenerationIfNecessary(DataToWriteToIB);
					
					DataTableKey = DataExchangeServer.DataTableKey(
						XDTOObjectType.Name, ConversionRule.ReceivedDataTypeAsString, False);
					ExchangeMessageDataTable = ExchangeComponents.DataTablesExchangeMessages.Get(DataTableKey); // ValueTable
					
					UUIDAsString1 = "";
					TableRow = Undefined;
					If XDTOData.Property(LinkClass()) Then
						UUIDAsString1 = XDTOData[LinkClass()].Value;
						TableRow = ExchangeMessageDataTable.Find(UUIDAsString1, "UUID");
					EndIf;
					
					If TableRow = Undefined Then
						TableRow = ExchangeMessageDataTable.Add();
						
						TableRow.TypeAsString              = ConversionRule.ReceivedDataTypeAsString;
						TableRow.UUID = UUIDAsString1;
					EndIf;
					
					// Filling in object property values.
					FillPropertyValues(TableRow, DataToWriteToIB);
					
					ObjectReference = Undefined;
					If SynchronizeByID Then
						ObjectReference = ObjectRefByXDTODataObjectUUID(XDTOData[LinkClass()].Value,
							ConversionRule.DataType, ExchangeComponents);
					Else
						ObjectReference = Undefined;
					EndIf;
					TableRow["Ref"] = ObjectReference;
					
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If SetErrorFlag Then
		ExchangeComponents.FlagErrors = True;
		ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
	EndIf;
	
EndProcedure

Procedure AddObjectToPackageTitleDataTable(ExchangeComponents,
		ConversionRule, XDTOObjectType, SynchronizeByID)
	
	TableRow = ExchangeComponents.PackageHeaderDataTable.Add();
					
	TableRow.ObjectTypeString = ConversionRule.ReceivedDataTypeAsString;
	TableRow.ObjectCountInSource = 1;
	
	TableRow.DestinationTypeString = ConversionRule.ReceivedDataTypeAsString;
	TableRow.SourceTypeString = XDTOObjectType;
	
	TableRow.SearchFields  = ConversionRule.ObjectPresentationFields;
	TableRow.TableFields = StrConcat(ConversionRule.ReceivedDataHeaderAttributes, ",");
	
	TableRow.SynchronizeByID = SynchronizeByID;
		
	TableRow.UsePreview = TableRow.SynchronizeByID;
	TableRow.IsClassifier                    = ConversionRule.IdentificationOption = "FirstByUUIDThenBySearchFields";
	TableRow.IsObjectDeletion = False;
	
EndProcedure

Function OldAndCurrentTSDataMap(ObjectTabularSectionAfterProcessing, ObjectTabularSectionBeforeProcessing, KeyFieldsArray)
	
	NewAndOldTSRowsMap = New Map;
	
	For Each NewTSRow1 In ObjectTabularSectionAfterProcessing Do
		
		FoundRowOfOldTS = Undefined;
		
		TheStructureOfTheSearch = New Structure;
		For Each KeyField_SSLy In KeyFieldsArray Do
			TheStructureOfTheSearch.Insert(KeyField_SSLy, NewTSRow1[KeyField_SSLy]);
		EndDo;
		
		FoundRowsOfNewTS = ObjectTabularSectionAfterProcessing.FindRows(TheStructureOfTheSearch);
		
		If FoundRowsOfNewTS.Count() = 1 Then
			
			FoundRowsOfOldTS = ObjectTabularSectionBeforeProcessing.FindRows(TheStructureOfTheSearch);
			
			If FoundRowsOfOldTS.Count() = 1 Then
				FoundRowOfOldTS = FoundRowsOfOldTS[0];
			EndIf;
			
		EndIf;
		
		NewAndOldTSRowsMap.Insert(NewTSRow1, FoundRowOfOldTS);
		
	EndDo;
	
	Return NewAndOldTSRowsMap;
	
EndFunction

Function ParseExchangeFormat(Val ExchangeFormat)
	
	Result = New Structure("BasicFormat, Version");
	
	FormatItems = StrSplit(ExchangeFormat, "/");
	
	If FormatItems.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Non-canonical exchange format name: ""%1""';"), ExchangeFormat);
	EndIf;
	
	Result.Version = FormatItems[FormatItems.UBound()];
	
	CheckVersion(Result.Version);
	
	FormatItems.Delete(FormatItems.UBound());
	
	Result.BasicFormat = StrConcat(FormatItems, "/");
	
	Return Result;
EndFunction

Function RefByUUID1(IBObjectValueType, XDTOObjectUUID, ExchangeComponents)
	
	ExchangeNode = ExchangeComponents.CorrespondentNode;
	
	TypesArray = New Array;
	TypesArray.Add(IBObjectValueType);
	TypeDescription = New TypeDescription(TypesArray);
	EmptyRef = TypeDescription.AdjustValue();

	MetadataObjectManager = Common.ObjectManagerByRef(EmptyRef);
	
	FoundRef = MetadataObjectManager.GetRef(New UUID(XDTOObjectUUID));
	If Not ValueIsFilled(ExchangeNode)
		Or FoundRef.IsEmpty()
		Or Not Common.RefExists(FoundRef) Then
		Return FoundRef;
	EndIf;
	RecordStructure = New Structure;
	RecordStructure.Insert("Ref", FoundRef);
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	
	UseCacheOfPublicIdentifiers = ExchangeComponents.UseCacheOfPublicIdentifiers;
	
	If Not UseCacheOfPublicIdentifiers 
		And Not InformationRegisters.SynchronizedObjectPublicIDs.RecordIsInRegister(RecordStructure) Then
		
		Return FoundRef;
		
	ElsIf UseCacheOfPublicIdentifiers 
		And Not EntryIsInCacheOfPublicIdentifiers(RecordStructure, ExchangeComponents) Then
		
		Return FoundRef;
		
	EndIf;
	
	// This UUID is already assigned to another object. Create a link with another UUID.
	NewRef = MetadataObjectManager.GetRef();
	
	Return NewRef;
	
EndFunction

Function FindRefByPublicID(XDTOObjectUUID, ExchangeComponents, IBObjectValueType)
		
	CorrespondentNode = ExchangeComponents.CorrespondentNode;
	
	If Not ValueIsFilled(CorrespondentNode) Then
		Return Undefined;
	EndIf;
	
	BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
	
	If Not ExchangeComponents.UseCacheOfPublicIdentifiers Then
	
		Query = New Query(
			"SELECT
			|	PIR.Ref AS Ref
			|FROM
			|	InformationRegister.SynchronizedObjectPublicIDs AS PIR
			|WHERE
			|	PIR.InfobaseNode = &InfobaseNode
			|	AND PIR.Id = &Id");
		
		Query.SetParameter("InfobaseNode", CorrespondentNode);
		Query.SetParameter("Id",          XDTOObjectUUID);
				
		Result = Query.Execute().Unload();
			
	Else
	
		CacheOfPublicIdentifiers = ExchangeComponents.CacheOfPublicIdentifiers;
		
		Filter = New Structure("Id", XDTOObjectUUID);
		Result = CacheOfPublicIdentifiers.FindRows(Filter);
		
	EndIf;
	
	FoundRef    = Undefined;
	IncorrectRefs = New Array;
	DeleteAllRecords   = False;
	
	For Each String In Result Do
			
		If TypeOf(String.Ref) <> IBObjectValueType Then
			Continue;
		EndIf;
		
		If FoundRef = Undefined Then
			FoundRef = String.Ref;
		ElsIf Common.RefExists(String.Ref) Then
			If Common.RefExists(FoundRef) Then
				DeleteAllRecords = True;
				FoundRef  = Undefined;
				Break;
			Else
				// 
				IncorrectRefs.Add(FoundRef);
				
				FoundRef = String.Ref;
			EndIf;
		Else
			// 
			IncorrectRefs.Add(String.Ref);
		EndIf;
		
	EndDo;
	
	DataExchangeValuationOfPerformance.FinishMeasurement(
		BeginTime, "RefsSearch", "", ExchangeComponents,
		DataExchangeValuationOfPerformance.EventTypeLibrary());
		
	If FoundRef <> Undefined
		And IncorrectRefs.Count() > 0
		And Not Common.RefExists(FoundRef) Then
		DeleteAllRecords = True;
		FoundRef  = Undefined;
	EndIf;
	
	If DeleteAllRecords Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Id",          XDTOObjectUUID);
		RecordStructure.Insert("InfobaseNode", CorrespondentNode);
		
		InformationRegisters.SynchronizedObjectPublicIDs.DeleteRecord(RecordStructure, True);
		
		DeleteEntryFromPublicIdCache(RecordStructure, ExchangeComponents);
		
	ElsIf IncorrectRefs.Count() > 0 Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Id",          XDTOObjectUUID);
		RecordStructure.Insert("InfobaseNode", CorrespondentNode);
		
		For Each Ref In IncorrectRefs Do
			RecordStructure.Insert("Ref", Ref);
			InformationRegisters.SynchronizedObjectPublicIDs.DeleteRecord(RecordStructure, True);
			
			DeleteEntryFromPublicIdCache(RecordStructure, ExchangeComponents);
		EndDo;
		
	EndIf;
	
	Return FoundRef;
	
EndFunction

// Reading and processing data on object deletion.
//
// Parameters:
//  ExchangeComponents        - Structure - contains all exchange rules and parameters.
//  XDTODataObject              - XDTODataObject - an object of ObjectDeletion XDTO package that contains information about
//                            deleted infobase object.
//  ArrayOfObjectsToDelete - Array of AnyRef - an array to store a reference to the object to delete.
//                            The actual deletion of objects happens
//                            after importing all data and analyzing them. The references imported as other
//                            XDTODataObjects are not deleted).
//  TablesToImport      - ValueTable - a collection of the data tables being imported.
//
Procedure ReadDeletion(ExchangeComponents, XDTODataObject, ArrayOfObjectsToDelete, TablesToImport = Undefined)
	
	XDTORefType = Undefined;
	
	If Not XDTODataObject.IsSet("ObjectReference") Then
		Return;
	EndIf;
	
	For Each XDTOProperty In XDTODataObject.СсылкаНаОбъект.СсылкаНаОбъект.Properties() Do
		
		If Not XDTODataObject.СсылкаНаОбъект.СсылкаНаОбъект.IsSet(XDTOProperty) Then
			Continue;
		EndIf;
		
		XDTOPropertyValue = XDTODataObject.СсылкаНаОбъект.СсылкаНаОбъект.GetXDTO(XDTOProperty);
		XDTORefValue   = ReadComplexTypeXDTOValue(XDTOPropertyValue, "Ref", XDTOPropertyValue.Type());
		
		// 
		XDTORefType = XDTORefValue.XDTOValueType;
		UUIDAsString1 = XDTORefValue.Value;
		Break;
		
	EndDo;
	
	If XDTORefType = Undefined Then
		Return;
	EndIf;
	
	// Search for DPR.
	DPR = DPRByXDTORefType(ExchangeComponents, XDTORefType, True);
	
	If Not ValueIsFilled(DPR) Then
		Return;
	EndIf;
		
	OCRNamesArray = DPR.OCRUsed;
	
	For Each ConversionRuleName In OCRNamesArray Do
		
		ConversionRule = ExchangeComponents.ObjectsConversionRules.Find(ConversionRuleName, "OCRName");
		If ConversionRule = Undefined Then
			
			Continue;
			
		EndIf;
		
		If Not FormatObjectPassesXDTOFilter(ExchangeComponents, ConversionRule.FormatObject) Then
			Continue;
		EndIf;
		
		If ConversionRule.IdentificationOption = "FirstByUUIDThenBySearchFields"
			Or ConversionRule.IdentificationOption = "ByUUID" Then
			
			If Not ObjectPassesTablesToImportFilter(
					TablesToImport, XDTODataObject.Type().Name, ConversionRule.ReceivedDataTypeAsString) Then
				Continue;
			EndIf;
			
			SupplementListOfObjectsForDeletion(ExchangeComponents,
				ConversionRule.DataType, UUIDAsString1, ArrayOfObjectsToDelete);
			
		EndIf;
	EndDo;
	
EndProcedure

Procedure ApplyObjectsDeletion(ExchangeComponents, ArrayOfObjectsToDelete, ArrayOfImportedObjects)
	
	For Each ImportedObject In ArrayOfImportedObjects Do
		While ArrayOfObjectsToDelete.Find(ImportedObject) <> Undefined Do
			ArrayOfObjectsToDelete.Delete(ArrayOfObjectsToDelete.Find(ImportedObject));
		EndDo;
	EndDo;
	
	ProhibitDocumentPosting = Metadata.ObjectProperties.Posting.Deny;
	
	For Each ElementToDelete In ArrayOfObjectsToDelete Do
		
		// Delete the reference.
		Object = ElementToDelete.GetObject();
		If Object = Undefined Then
			Continue;
		EndIf;
		
		If ExchangeComponents.DataImportToInfobaseMode Then
			
			If ExchangeComponents.IsExchangeViaExchangePlan
				And DataExchangeEvents.ImportRestricted(Object, ExchangeComponents.CorrespondentNodeObject) Then
				
				Continue; // 
				
			EndIf;
			
			ObjectMetadata = Object.Metadata();
			If Metadata.Documents.Contains(ObjectMetadata) Then
				If Object.Posted Then
					
					HasResult = UndoObjectPostingInIB(Object, 
						ExchangeComponents.CorrespondentNode, ExchangeComponents);
					
					If Not HasResult Then
						Continue;
					EndIf;
				ElsIf ObjectMetadata.Posting = ProhibitDocumentPosting Then
					MakeDocumentRegisterRecordsInactive(Object, ExchangeComponents);
				EndIf;
			EndIf;
			DataExchangeServer.SetDataExchangeLoad(Object, True, False, ExchangeComponents.CorrespondentNode);
			DeleteObject(Object, False, ExchangeComponents);
		Else
			
			ReceivedDataTypeAsString = DataTypeNameByMetadataObject(Object.Metadata());
			
			TableRow = ExchangeComponents.PackageHeaderDataTable.Add();
			
			TableRow.ObjectTypeString = ReceivedDataTypeAsString;
			TableRow.ObjectCountInSource = 1;
			TableRow.DestinationTypeString = ReceivedDataTypeAsString;
			TableRow.IsObjectDeletion = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteObject(Object, DeleteDirectly, ExchangeComponents)
	
	If Not WriteObjectAllowed(Object, ExchangeComponents) Then
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
			?(DeleteDirectly,
				NStr("en = 'Attempting to delete shared data (%1: %2) in separated mode.';"),
				NStr("en = 'Attempting to mark shared data (%1: %2) for deletion in separated mode.';")),
			Object.Metadata().FullName(),
			String(Object));

		If ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Undefined
			Or ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed2 Then
			ExchangeComponents.DataExchangeState.ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings;
		EndIf;
		
		ErrorCode = New Structure;
		ErrorCode.Insert("BriefErrorDescription",   ErrorMessageString);
		ErrorCode.Insert("DetailErrorDescription", ErrorMessageString);
		ErrorCode.Insert("Level",                      EventLogLevel.Warning);
		
		WriteToExecutionProtocol(ExchangeComponents, ErrorCode, , False);
		
		Return;
	EndIf;
	
	Predefined = False;
	If CommonClientServer.HasAttributeOrObjectProperty(Object, "Predefined") Then
		Predefined = Object.Predefined;
	EndIf;
	
	If Predefined Then
		Return;
	EndIf;
	
	If DeleteDirectly Then
		Object.Delete();
	Else
		SetObjectDeletionMark(Object);
	EndIf;
	
EndProcedure

// Sets deletion mark.
//
// Parameters:
//  Object          - 
//  
//  
//
Procedure SetObjectDeletionMark(Object)
	
	If Object.AdditionalProperties.Property("DataImportRestrictionFound") Then
		Return;
	EndIf;
	ObjectMetadata = Object.Metadata();
	If Common.IsDocument(ObjectMetadata) Then
		DataExchangeServer.SetDataExchangeLoad(Object, False);
		InformationRegisters.DataExchangeResults.RecordIssueResolved(Object,
			Enums.DataExchangeIssuesTypes.UnpostedDocument);
	EndIf;
	
	DataExchangeServer.SetDataExchangeLoad(Object);
	
	// For hierarchical objects, a deletion mark is set only for a particular object.
	If Common.IsCatalog(ObjectMetadata)
		Or Common.IsChartOfCharacteristicTypes(ObjectMetadata)
		Or Common.IsChartOfAccounts(ObjectMetadata) Then
		Object.SetDeletionMark(True, False);
	Else
		Object.SetDeletionMark(True);
	EndIf;
	
EndProcedure

Function MessageFromNotUpdatedSetting(XMLReader)
	If XMLReader.NodeType = XMLNodeType.StartElement
		And XMLReader.LocalName = "ExchangeFile" Then
		While XMLReader.ReadAttribute() Do
			If XMLReader.LocalName = "FormatVersion" 
				Or XMLReader.LocalName = "SourceConfigurationVersion" Then
				Return True;
			EndIf;
		EndDo;
	EndIf;
	Return False;
EndFunction

// Removes the flag of document register records activity.
//
// Parameters:
//  Object      - DocumentObject -
//  
//
// Returns:
//   Boolean - 
//
Function MakeDocumentRegisterRecordsInactive(Object, ExchangeComponents)
	
	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		For Each Movement In Object.RegisterRecords Do
			
			Movement.Read();
			HasChanges = False;
			For Each String In Movement Do
				
				If String.Active = False Then
					Continue;
				EndIf;
				
				String.Active   = False;
				HasChanges = True;
				
			EndDo;
			
			If HasChanges Then
				Movement.Write = True;
				DataExchangeServer.SetDataExchangeLoad(Movement, True, False, ExchangeComponents.CorrespondentNode);
				Movement.Write();
			EndIf;
			
		EndDo;
		
		Event = "ClearingDocumentRegisteredRecords." + Object.Metadata().FullName();
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, Event, Object, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Procedure RefreshCorrespondentPrefix(ExchangeComponents)
	
	If ValueIsFilled(ExchangeComponents.CorrespondentPrefix) Then
		Prefixes = InformationRegisters.CommonInfobasesNodesSettings.NodePrefixes(ExchangeComponents.CorrespondentNode);
		If Not ValueIsFilled(Prefixes.CorrespondentPrefix) Then
			InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
				ExchangeComponents.CorrespondentNode, , ExchangeComponents.CorrespondentPrefix);
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//   ExchangeComponents - See DataExchangeXDTOServer.InitializeExchangeComponents
//
Procedure UpdateCorrespondentXDTOSettings(ExchangeComponents)
	
	// Checking the possibility to upgrade the correspondent to a later version.
	CorrespondentVersionNumber  = Common.ObjectAttributeValue(ExchangeComponents.CorrespondentNode, "ExchangeFormatVersion");
	MaxCommonVersion    = MaxCommonFormatVersion(
		DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode),
		ExchangeComponents.XDTOCorrespondentSettings.SupportedVersions);
		
	If MaxCommonVersion <> CorrespondentVersionNumber Then
		BeginTransaction();
		Try
		    Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(ExchangeComponents.CorrespondentNode));
		    LockItem.SetValue("Ref", ExchangeComponents.CorrespondentNode);
		    Block.Lock();
		    
			LockDataForEdit(ExchangeComponents.CorrespondentNode);
			CorrespondentNodeObject = ExchangeComponents.CorrespondentNode.GetObject();
			
			CorrespondentNodeObject.ExchangeFormatVersion = MaxCommonVersion;

			CorrespondentNodeObject.Write();
			
			CommitTransaction();
		Except
		    RollbackTransaction();
		    Raise;
		EndTry;
		
		WriteToExecutionProtocol(ExchangeComponents, 
			NStr("en = 'Exchange format version has been changed.';"), , False, , , True);
	EndIf;
	
	InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(ExchangeComponents.CorrespondentNode,
		"SupportedObjects",
		ExchangeComponents.XDTOCorrespondentSettings.SupportedObjects);
	InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(ExchangeComponents.CorrespondentNode,
		"SupportedExtensions",
		ExchangeComponents.XDTOCorrespondentSettings.SupportedExtensions);
	
EndProcedure

Procedure FillXDTOSettingsStructure(ExchangeComponents) Export
	
	If Not ExchangeComponents.IsExchangeViaExchangePlan
		Or Not ValueIsFilled(ExchangeComponents.CorrespondentNode) Then
		Return;
	EndIf;
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
	
	ExchangeComponents.XDTOSettings.Format = ExchangeFormat(ExchangePlanName, "");
	
	If ExchangeComponents.ExchangeDirection = "Send" Then
		ExchangeComponents.XDTOSettings.SupportedObjects = SupportedObjectsInFormat(
			ExchangePlanName, "SendReceive", ExchangeComponents.CorrespondentNode);
	Else
		ObjectsTable1 = New ValueTable;
		InitializeSupportedFormatObjectsTable(ObjectsTable1, ExchangeComponents.ExchangeDirection);
		
		FillSupportedFormatObjectsByExchangeComponents(ObjectsTable1, ExchangeComponents);
		
		HasAlgorithm = DataExchangeServer.HasExchangePlanManagerAlgorithm(
			"OnDefineSupportedFormatObjects", ExchangePlanName);
		If HasAlgorithm Then
			ExchangePlans[ExchangePlanName].OnDefineSupportedFormatObjects(
				ObjectsTable1, ExchangeComponents.ExchangeDirection, ExchangeComponents.CorrespondentNode);
		EndIf;
		
		ExchangeComponents.XDTOSettings.SupportedObjects = ObjectsTable1;
	EndIf;
	
	ExchangeComponents.XDTOSettings.SupportedVersions = ExhangeFormatVersionsArray(ExchangeComponents.CorrespondentNode);
	
EndProcedure

// Parameters:
//   SettingsStructure - Structure:
//     * Format - String - an exchange format name.
//     * SupportedVersions - Array of String - a collection of supported format versions.
//     * SupportedObjects - See SupportedObjectsInFormat
//   Header - XDTODataObject - an exchange message heading.
//   FormatContainsVersion - Boolean - True if the format string contains a version number.
//   ExchangeNode - ExchangePlanRef
//              - Undefined - the site plan of exchange.
//
Procedure FillCorrespondentXDTOSettingsStructure(SettingsStructure,
		Header, FormatContainsVersion = True, ExchangeNode = Undefined) Export
	
	If FormatContainsVersion Then
		ExchangeFormat = ParseExchangeFormat(Header.Format);
		SettingsStructure.Format = ExchangeFormat.BasicFormat;
	Else
		SettingsStructure.Format = Header.Format;
	EndIf;
	
	For Each AvailableVersion In Header.AvailableVersion Do
		SettingsStructure.SupportedVersions.Add(AvailableVersion);
	EndDo;
	
	If Not Header.IsSet("AvailableObjectTypes")
		And Not ExchangeNode = Undefined
		And FormatContainsVersion Then
		// 
		// 
		// 
		// 
		// 
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		
		DatabaseObjectsTable = SupportedObjectsInFormat(ExchangePlanName,
			"SendReceive", ?(ExchangeNode.IsEmpty(), Undefined, ExchangeNode));
		
		For Each Version In SettingsStructure.SupportedVersions Do
			FilterByVersion = New Structure("Version", Version);
			
			BaseObjectsStrings = DatabaseObjectsTable.FindRows(FilterByVersion);
			For Each BaseObjectsRow In BaseObjectsStrings Do
				
				CorrespondentObjectsRow = SettingsStructure.SupportedObjects.Add();
				FillPropertyValues(CorrespondentObjectsRow, BaseObjectsRow, "Version, Object");
				CorrespondentObjectsRow.Send = BaseObjectsRow.Receive;
				CorrespondentObjectsRow.Receive = BaseObjectsRow.Send;
				
			EndDo;
		EndDo;
		
		Return;
	EndIf;
	
	If Header.AvailableObjectTypes <> Undefined Then
		
		For Each ObjectType In Header.AvailableObjectTypes.ObjectType Do
		
			Send  = New Array;
			Receive = New Array;
			
			If Not IsBlankString(ObjectType.Sending) Then
				
				If ObjectType.Sending = "*" Then
					For Each Version In SettingsStructure.SupportedVersions Do
						Send.Add(TrimAll(Version));
					EndDo;
				Else
					For Each Version In StrSplit(ObjectType.Sending, ",", False) Do
						Send.Add(TrimAll(Version));
					EndDo;
				EndIf;
				
			EndIf;
			
			If Not IsBlankString(ObjectType.Receiving) Then
				
				If ObjectType.Receiving = "*" Then
					For Each Version In SettingsStructure.SupportedVersions Do
						Receive.Add(TrimAll(Version));
					EndDo;
				Else
					For Each Version In StrSplit(ObjectType.Receiving, ",", False) Do
						Receive.Add(TrimAll(Version));
					EndDo;
				EndIf;
				
			EndIf;
			
			For Each Version In Send Do
				
				StringObject = SettingsStructure.SupportedObjects.Add();
				StringObject.Object = ObjectType.Name;
				StringObject.Version = Version;
				StringObject.Send = True;
				
				IndexOf = Receive.Find(Version);
				If Not IndexOf = Undefined Then
					StringObject.Receive = True;
					Receive.Delete(IndexOf);
				EndIf;
				
			EndDo;
			
			For Each Version In Receive Do
				
				StringObject = SettingsStructure.SupportedObjects.Add();
				StringObject.Object = ObjectType.Name;
				StringObject.Version = Version;
				StringObject.Receive = True;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	If TypeOf(Header) = Type("XDTODataObject")
		And Header.Properties().Get("AvailableExtensions") <> Undefined // 
		And Header.AvailableExtensions <> Undefined						// 
		Then
		
		For Each Extension In Header.AvailableExtensions.Extension Do
			
			SettingsStructure.SupportedExtensions.Insert(Extension.Namespace, Extension.BaseVersion);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function WriteObjectAllowed(Object, ExchangeComponents)
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaSOperations") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(Object.Metadata());
		Else
			IsSeparatedMetadataObject = False;
		EndIf;
		
		If Not IsSeparatedMetadataObject Then
		
			Return False;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region ExchangeRulesSearch

Function DPRByXDTORefType(ExchangeComponents, XDTORefType, ReturnEmptyValue = False)
	
	ProcessingRule = ExchangeComponents.DataProcessingRules.Find(XDTORefType, "XDTORefType");
	If ProcessingRule = Undefined Then
		
		If ReturnEmptyValue Then
			Return ProcessingRule;
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot find a DPR for an XDTO reference type.
					|XDTO reference type: %1.
					|Error details: %2';"),
				String(XDTORefType),
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
		EndIf;
		
	Else
		Return ProcessingRule;
	EndIf;
	
EndFunction

Function DPRByXDTOObjectType(ExchangeComponents, XDTOObjectType, ReturnEmptyValue = False)
	
	ProcessingRule = ExchangeComponents.DataProcessingRules.Find(XDTOObjectType, "FilterObjectFormat");
	If ProcessingRule = Undefined Then
		
		If ReturnEmptyValue Then
			Return ProcessingRule;
		Else
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot find a DER for an XDTO object type.
					|XDTO object type: %1.
					|Error details: %2';"),
				String(XDTOObjectType),
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
		EndIf;
		
	Else
		Return ProcessingRule;
	EndIf;
	
EndFunction

Function DPRByMetadataObject(ExchangeComponents, MetadataObject)
	
	ProcessingRule = ExchangeComponents.DataProcessingRules.Find(MetadataObject, "SelectionObjectMetadata");
	
	If ProcessingRule = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot find a DER for a metadata object.
			|Metadata object: %3.';"),
			String(MetadataObject));
	EndIf;
	
	Return ProcessingRule;

EndFunction

Function DPRByName(ExchangeComponents, Name)
	
	ProcessingRule = ExchangeComponents.DataProcessingRules.Find(Name, "Name");
	
	If ProcessingRule = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot find a DER with name ""%1""';"), Name);
			
	Else
		Return ProcessingRule;
	EndIf;

EndFunction

Procedure GetProcessingRuleForObject(ExchangeComponents, Object, ProcessingRule)
	
	Try
		ProcessingRule = DPRByMetadataObject(ExchangeComponents, Object.Metadata());
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Event: %1.
			|Object: %2.
			|
			|%3.';"),
			ExchangeComponents.ExchangeDirection,
			ObjectPresentationForProtocol(Object),
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

#EndRegion

#Region DataProcessingRulesEventHandlers
// Wrapper procedure for DPR OnProcess handler call.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ProcessingRule - 
//  DataProcessorObject2  - 
//                      
//                     
//  UsageOCR - Structure - that determines which OCRs are used to export the object.
//                     Keys correspond the OCR names, 
//                     values indicate whether an OCR is used for a specific processing object.
//
Procedure OnProcessDPR(ExchangeComponents, ProcessingRule, Val DataProcessorObject2, UsageOCR, Cancel = False)
	
	If Not ValueIsFilled(ProcessingRule.OnProcess) Then
		Return;
	EndIf;
		
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("DataProcessorObject2",  DataProcessorObject2);
	ParametersStructure.Insert("UsageOCR", UsageOCR);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);

	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeManager.ExecuteManagerModuleProcedure(ProcessingRule.OnProcess, ParametersStructure);
		
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, ProcessingRule.OnProcess, DataProcessorObject2, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
	
	Except
		Cancel = True;
		
		ErrorDescription = DPRErrorDescription(
			ExchangeComponents.ExchangeDirection,
			ProcessingRule.Name,
			ObjectPresentationForProtocol(DataProcessorObject2, ProcessingRule.SelectionObjectMetadata),
			ErrorInfo());
		
		RecordIssueOnProcessObject(ExchangeComponents,
			DataProcessorObject2,
			?(ExchangeComponents.ExchangeDirection = "Send",
				Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData,
				Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData),
			ErrorDescription.DetailedPresentation,
			ErrorDescription.BriefPresentation);
	EndTry;
	
	DataProcessorObject2  = ParametersStructure.DataProcessorObject2;
	UsageOCR = ParametersStructure.UsageOCR;
	ExchangeComponents = ParametersStructure.ExchangeComponents;
	
EndProcedure

// Wrapper function for DPR DataSelection handler call.
//
// Parameters:
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ProcessingRule - ValueTableRow - a row of data processing rules that corresponds the DPR to process.
//
// Returns:
//  Arbitrary - 
//
Function DataSelection(ExchangeComponents, ProcessingRule)
	
	SelectionAlgorithm = ProcessingRule.DataSelection;
	If ValueIsFilled(SelectionAlgorithm) Then
		
		ExchangeManager = ExchangeComponents.ExchangeManager;
		ParametersStructure = New Structure();
		ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
		
		Try
			DataSelection = ExchangeManager.PerformManagerModuleFunction(ProcessingRule.DataSelection, ParametersStructure);
		Except
			
			ErrorDescriptionTemplate = NStr("en = 'Event: %1.
					|Handler: %2.
					|DPR: %3.
					|
					|Handler execution error.
					|%4.';");
			
			ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
				ExchangeComponents.ExchangeDirection,
				"DataSelection",
				ProcessingRule.Name,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			Raise ErrorText;
			
		EndTry;
		
	Else
		
		QueryText =
		"SELECT
		|	AliasOfTheMetadataTable.Ref
		|FROM
		|	&MetadataTableName AS AliasOfTheMetadataTable";
		
		QueryText = StrReplace(QueryText, "&MetadataTableName", ProcessingRule.TableNameForSelection);
		
		Query = New Query(QueryText);
		DataSelection = Query.Execute().Unload().UnloadColumn("Ref");
		
	EndIf;
	
	Return DataSelection;
	
EndFunction

#EndRegion

#Region ConversionRulesEventHandlers
// Wrapper function for calling OCR handler OnSendData.
//
// Parameters:
//  IBData         - 
//                     
//  XDTOData       - Structure - to which data is exported. Its content is identical to XDTO object content.
//  HandlerName   - String - a handler procedure name in the manager module.
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  ExportStack     - Array - contains references to objects being exported considering nesting.
//
Procedure OnSendData(IBData, XDTOData, Val HandlerName, ExchangeComponents, ExportStack)
		
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("IBData", IBData);
	ParametersStructure.Insert("XDTOData", XDTOData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
	ParametersStructure.Insert("ExportStack", ExportStack);

	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeManager.ExecuteManagerModuleProcedure(HandlerName, ParametersStructure);
		
		DataExchangeValuationOfPerformance.FinishMeasurement( 
			BeginTime, HandlerName, IBData, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|Object: %3.
				|
				|Handler execution error.
				|%4.';");
		
		ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"OnSendData",
			ObjectPresentationForProtocol(IBData),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		Raise ErrorText;
		
	EndTry;
	
	XDTOData       = ParametersStructure.XDTOData;
	ExchangeComponents = ParametersStructure.ExchangeComponents;
	ExportStack     = ParametersStructure.ExportStack;
	
EndProcedure

// Wrapper function for calling OCR handler OnConvertXDTOData.
//
// Parameters:
//  ReceivedData - 
//  
//  ExchangeComponents - Structure - contains all exchange rules and parameters.
//  HandlerName   - String - a handler procedure name in the manager module.
//
Procedure OnConvertXDTOData(XDTOData, ReceivedData, ExchangeComponents, Val HandlerName)
	
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("XDTOData", XDTOData);
	ParametersStructure.Insert("ReceivedData", ReceivedData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
	
	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeManager.ExecuteManagerModuleProcedure(HandlerName, ParametersStructure);
		
		DataExchangeValuationOfPerformance.FinishMeasurement( 
			BeginTime, HandlerName, ReceivedData, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|Object: %3.
				|
				|Handler execution error.
				|%4.';");
		
		ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"OnConvertXDTOData",
			ObjectPresentationForProtocol(ReceivedData),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		Raise ErrorText;
		
	EndTry;
	
	XDTOData               = ParametersStructure.XDTOData;
	ReceivedData         = ParametersStructure.ReceivedData;
	ExchangeComponents         = ParametersStructure.ExchangeComponents;
	
EndProcedure

// Wrapper function for calling OCR handler BeforeWriteReceivedData.
//
// Parameters:
//  ReceivedData   - 
//  IBData           - 
//                       
//  ExchangeComponents   - Structure - contains all exchange rules and parameters.
//  HandlerName     - String - a handler procedure name in the manager module.
//  PropertiesConversion - ValueTable - object properties conversion rules.
//                       It is used to determine the composition of properties that are to be transferred from ReceivedData to
//                       InfobaseData.
//
Procedure BeforeWriteReceivedData(ReceivedData, IBData, ExchangeComponents, HandlerName, PropertiesConversion)

	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("IBData", IBData);
	ParametersStructure.Insert("ReceivedData", ReceivedData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);
	ParametersStructure.Insert("PropertiesConversion", PropertiesConversion);

	Try
		
		BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
		ExchangeManager.ExecuteManagerModuleProcedure(HandlerName, ParametersStructure);
		
		DataExchangeValuationOfPerformance.FinishMeasurement(
			BeginTime, HandlerName, IBData, ExchangeComponents,
			DataExchangeValuationOfPerformance.EventTypeRule());
		
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|Object: %3.
				|
				|Handler execution error.
				|%4.';");
		
		ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"BeforeWriteReceivedData",
			ObjectPresentationForProtocol(?(IBData <> Undefined, IBData, ReceivedData)),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		Raise ErrorText;
		
	EndTry;
	
	IBData                 = ParametersStructure.IBData;
	ReceivedData         = ParametersStructure.ReceivedData;
	ExchangeComponents         = ParametersStructure.ExchangeComponents;
	PropertiesConversion       = ParametersStructure.PropertiesConversion;
	
EndProcedure

Procedure SearchAlgorithm(IBData, Val ReceivedData, Val ExchangeComponents, Val HandlerName)
	
	ExchangeManager = ExchangeComponents.ExchangeManager;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("IBData", IBData);
	ParametersStructure.Insert("ReceivedData", ReceivedData);
	ParametersStructure.Insert("ExchangeComponents", ExchangeComponents);

	Try
		ExchangeManager.ExecuteManagerModuleProcedure(HandlerName, ParametersStructure);
	Except
		
		ErrorDescriptionTemplate = NStr("en = 'Event: %1.
				|Handler: %2.
				|Object: %3.
				|
				|Handler execution error.
				|%4.';");
		
		ErrorText = Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
			ExchangeComponents.ExchangeDirection,
			"SearchAlgorithm",
			ObjectPresentationForProtocol(?(IBData <> Undefined, IBData, ReceivedData)),
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
		Raise ErrorText;
		
	EndTry;
	
	IBData                 = ParametersStructure.IBData;
	ReceivedData         = ParametersStructure.ReceivedData;
	ExchangeComponents         = ParametersStructure.ExchangeComponents;
	
EndProcedure

#EndRegion

#EndRegion

#Region KeepProtocol

// Returns a Structure type object containing all possible fields of
// the execution protocol record (such as error messages and others).
//
// Parameters:
//  ErrorMessageCode - String - contains an error code.
//  ErrorString        - String - contains a module line where an error occurred.
//
// Returns:
//  Structure - 
//
Function ExchangeProtocolRecord(ErrorMessageCode = "", Val ErrorString = "")

	ErrorStructure = New Structure(
		"ObjectType,
		|Object,
		|ErrorDescription,
		|ModulePosition,
		|ErrorMessageCode");
	
	ModuleString = SplitWithSeparator(ErrorString, "{");
	If IsBlankString(ErrorString) Then
		ErrorDescription = TrimAll(SplitWithSeparator(ModuleString, "}:"));
	Else
		ErrorDescription = ErrorString;
		ModuleString   = "{" + ModuleString;
	EndIf;
	
	If ErrorDescription <> "" Then
		ErrorStructure.ErrorDescription = ErrorDescription;
		ErrorStructure.ModulePosition  = ModuleString;
	EndIf;
	
	If ErrorStructure.ErrorMessageCode <> "" Then
		
		ErrorStructure.ErrorMessageCode = ErrorMessageCode;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction

Function ExchangeExecutionResultError(ExchangeExecutionResult)
	
	Return ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error
		Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.ErrorMessageTransport;
	
EndFunction

Function ExchangeExecutionResultWarning(ExchangeExecutionResult)
	
	Return ExchangeExecutionResult = Enums.ExchangeExecutionResults.CompletedWithWarnings
		Or ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted;
	
EndFunction

// The function generates the object presentation to be written to the exchange protocol.
//
// Parameters:
//   Object - AnyRef - a reference to any MDO;
//          - Объект - 
//          - XDTODataObject - 
//          - Structure
//   StructurePresentationMetadata - MetadataObject - metadata of the object the presentation is generated for.
//
// Returns:
//   String - 
//
Function ObjectPresentationForProtocol(Object, StructurePresentationMetadata = Undefined)
	
	ObjectType           = TypeOf(Object);
	ObjectMetadata    = Metadata.FindByType(ObjectType);
	ObjectPresentation = String(Object);
	URL  = "";
	
	If ObjectMetadata <> Undefined
		And Common.IsRefTypeObject(ObjectMetadata)
		And ValueIsFilled(Object.Ref) Then
		URL = GetURL(Object.Ref);
	Else
		
		If ObjectType = Type("XDTODataObject") Then
			
			PropertiesCollection = Object.Properties();
			ObjectPresentation = "";
			ObjectType = Object.Type().Name;
			
			If PropertiesCollection.Count() > 0 And PropertiesCollection.Get(KeyPropertiesClass()) <> Undefined Then
				KeyProperties = Object.Get(KeyPropertiesClass());
				
				Attributes = New Structure("Наименование, Код, КодВПрограмме, Номер, Дата"); // @Non-NLS
				FillPropertyValues(Attributes, KeyProperties);
				
				ObjectPresentation = PropertiesCollectionPresentationForProtocol(Attributes);
			EndIf;
			
		ElsIf ObjectType = Type("Structure") Then
			
			GenerateStructurePresentation = True;
			If Object.Property("Ref")
				And ValueIsFilled(Object.Ref) Then
				ObjectType = TypeOf(Object.Ref);
				If Common.IsReference(ObjectType) Then
					ObjectPresentation = String(Object.Ref);
					URL  = GetURL(Object.Ref);
					
					GenerateStructurePresentation = False;
				EndIf;
			EndIf;
			
			If GenerateStructurePresentation Then
				ObjectType = String(TypeOf(Object));
				If Not StructurePresentationMetadata = Undefined Then
					ObjectType = ObjectType + "<" + StructurePresentationMetadata.Presentation() + ">";
				EndIf;
				
				ObjectPresentation = PropertiesCollectionPresentationForProtocol(Object);
			EndIf;
			
		EndIf;
	EndIf;
	
	ObjectPresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, %2 (%3)';"),
		ObjectType, ObjectPresentation, URL);
	
	Return ObjectPresentation;
	
EndFunction

Function PropertiesCollectionPresentationForProtocol(PropertiesCollection)
	
	Presentation = String(PropertiesCollection);
	
	PresentationItems = New Array;
				
	PropertyValue = Undefined;
	
	If PropertiesCollection.Property("Наименование", PropertyValue) // @Non-NLS
		And ValueIsFilled(PropertyValue) Then
		PresentationItems.Add(TrimAll(PropertyValue));
	EndIf;
	
	If PropertiesCollection.Property("Код", PropertyValue) // @Non-NLS
		And ValueIsFilled(PropertyValue) Then
		PresentationItems.Add("(" + TrimAll(PropertyValue) + ")");
	ElsIf PropertiesCollection.Property("КодВПрограмме", PropertyValue) // @Non-NLS
		And ValueIsFilled(PropertyValue) Then
		PresentationItems.Add("(" + TrimAll(PropertyValue) + ")");
	EndIf;
	
	If PropertiesCollection.Property("Номер", PropertyValue) // @Non-NLS
		And ValueIsFilled(PropertyValue) Then
		
		DatePropertyValue = Undefined;
		If PropertiesCollection.Property("Дата", DatePropertyValue) // @Non-NLS
			And ValueIsFilled(DatePropertyValue) Then
			PresentationItems.Add(
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '#%1, %2';"), PropertyValue, Format(DatePropertyValue, "DLF=D")));
		Else
			PresentationItems.Add(
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '#%1';"), PropertyValue));
		EndIf;
		
	ElsIf PropertiesCollection.Property("Дата", PropertyValue) // @Non-NLS
		And ValueIsFilled(PropertyValue) Then
		
		PresentationItems.Add(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = ', %1';"), PropertyValue));
		
	EndIf;
	
	If PresentationItems.Count() > 0 Then
		Presentation = StrConcat(PresentationItems, " ");
	EndIf;
	
	Return Presentation;
	
EndFunction

Function XDTOObjectPresentationForProtocol(XDTOObjectType)
	
	Return XDTOObjectType.Name;
	
EndFunction

#EndRegion

#Region DataExchangeResults

Function DPRErrorDescription(ExchangeDirection, DPRName, ObjectPresentation, Information)
	
	Result = New Structure("BriefPresentation, DetailedPresentation");
	
	ErrorDescriptionTemplate = NStr("en = 'Event: %1.
		|Handler: %2.
		|DPR: %3.
		|Object: %4.
		|
		|Handler execution error.
		|%5.';");
	
	Result.BriefPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorDescriptionTemplate,
		ExchangeDirection,
		"OnProcessDPR",
		DPRName,
		ObjectPresentation,
		ErrorProcessing.BriefErrorDescription(Information));
		
	Result.DetailedPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorDescriptionTemplate,
		ExchangeDirection,
		"OnProcessDPR",
		DPRName,
		ObjectPresentation,
		ErrorProcessing.DetailErrorDescription(Information));
	
	Return Result;
	
EndFunction

Function OCRErrorDescription(ExchangeDirection, DPRName, OCRName, ObjectPresentation, Information)
	
	Result = New Structure("BriefPresentation, DetailedPresentation");
	
	ErrorDescriptionTemplate = NStr("en = 'Direction: %1.
		|DPR: %2.
		|OCR: %3.
		|Object: %4.
		|
		|%5';");
	
	Result.BriefPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorDescriptionTemplate,
		ExchangeDirection,
		DPRName,
		OCRName,
		ObjectPresentation,
		ErrorProcessing.BriefErrorDescription(Information));
		
	Result.DetailedPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorDescriptionTemplate,
		ExchangeDirection,
		DPRName,
		OCRName,
		ObjectPresentation,
		ErrorProcessing.DetailErrorDescription(Information));
		
	Return Result;
	
EndFunction

Procedure RecordIssueOnProcessObject(ExchangeComponents,
		DataProcessorObject2, IssueType, DetailedPresentation, BriefPresentation = "")
	
	ErrorCode = New Structure("Level", ErrorLevelByErrorType(ExchangeComponents, IssueType));
	ErrorCode.Insert("DetailErrorDescription", DetailedPresentation);
	ErrorCode.Insert("BriefErrorDescription",
		?(IsBlankString(BriefPresentation), DetailedPresentation, BriefPresentation));
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		If ExchangeComponents.ExchangeDirection = "Send" Then
			WriteToExecutionProtocol(ExchangeComponents, ErrorCode, , Not ExchangeComponents.SkipObjectsWithSchemaCheckErrors);
			WriteObjectProcessingErrorOnSend(
				DataProcessorObject2,
				ExchangeComponents.CorrespondentNode,
				ErrorCode.BriefErrorDescription,
				IssueType);
		Else
			WriteToExecutionProtocol(ExchangeComponents, ErrorCode);
		EndIf;
	Else
		WriteToExecutionProtocol(ExchangeComponents, ErrorCode);
	EndIf;
	
EndProcedure

Procedure WriteObjectProcessingErrorOnSend(DataProcessorObject2, InfobaseNode, Cause, IssueType)
	
	If TypeOf(DataProcessorObject2) = Type("Structure") Then
		Return;
	EndIf;
	
	If Common.IsRefTypeObject(DataProcessorObject2.Metadata()) Then
		InformationRegisters.DataExchangeResults.RecordDocumentCheckError(
			DataProcessorObject2.Ref,
			InfobaseNode,
			Cause,
			IssueType);
	Else
		InformationRegisters.DataExchangeResults.RecordDocumentCheckError(
			DataProcessorObject2,
			InfobaseNode,
			Cause,
			IssueType);
	EndIf;

EndProcedure

Procedure ClearErrorsListOnExportData(InfobaseNode)
	
	InformationRegisters.DataExchangeResults.ClearIssuesOnSend(InfobaseNode);
	
EndProcedure

Procedure ClearErrorsListOnDataImport(InfobaseNode)
	
	InformationRegisters.DataExchangeResults.ClearIssuesOnGet(InfobaseNode);
	
EndProcedure

Function ErrorLevelByErrorType(ExchangeComponents, IssueType)
	
	If IssueType = Enums.DataExchangeIssuesTypes.ConvertedObjectValidationError Then
		Return ?(ExchangeComponents.IsExchangeViaExchangePlan
				And ExchangeComponents.SkipObjectsWithSchemaCheckErrors,
			EventLogLevel.Warning, EventLogLevel.Error);
	ElsIf IssueType = Enums.DataExchangeIssuesTypes.ApplicationAdministrativeError
		Or IssueType = Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData
		Or IssueType = Enums.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData Then
		Return EventLogLevel.Error;
	ElsIf IssueType = Enums.DataExchangeIssuesTypes.BlankAttributes
		Or IssueType = Enums.DataExchangeIssuesTypes.UnpostedDocument Then
		Return EventLogLevel.Warning;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ExchangeFormatVersioningProceduresAndFunctions

Function ExchangeFormatVersions(Val InfobaseNode)
	
	ExchangeFormatVersions = New Map;
	ExchangePlanName = "";
	
	If ValueIsFilled(InfobaseNode) Then
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
		ExchangeFormatVersions = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeFormatVersions");
	Else
		DataExchangeOverridable.OnGetAvailableFormatVersions(ExchangeFormatVersions);
	EndIf;
	
	If ExchangeFormatVersions.Count() = 0 Then
		If ValueIsFilled(InfobaseNode) Then
			
			ErrorDescriptionTemplate = NStr("en = 'Exchange format versions not set.
				|Exchange plan name: %1
				|Procedure: %2';");
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
				ExchangePlanName,
				"GetExchangeFormatVersions(<ExchangeFormatVersions>)");
			
			Raise ErrorText;
			
		Else
			
			ErrorDescriptionTemplate = NStr("en = 'Exchange format versions not set.
				|Procedure: %1';");
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,
				"DataExchangeOverridable.OnGetAvailableFormatVersions(<ExchangeFormatVersions>)");
			
			Raise ErrorText;
			
		EndIf;
	EndIf;
	
	Result = New Map;
	
	For Each Version In ExchangeFormatVersions Do
		
		Result.Insert(TrimAll(Version.Key), Version.Value);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function SortFormatVersions(Val FormatVersions)
	
	Result = New ValueTable;
	Result.Columns.Add("Version");
	
	For Each Version In FormatVersions Do
		
		Result.Add().Version = Version.Key;
		
	EndDo;
	
	Result.Sort("Version Desc");
	
	Return Result.UnloadColumn("Version");
EndFunction

Procedure CheckVersion(Val Version)
	
	Versions = StrSplit(Version, ".");
	
	If Versions.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Non-canonical presentation of the exchange format v.%1.';"), Version);
	EndIf;
	
EndProcedure

Function MinExchangeFormatVersion(Val InfobaseNode)
	
	Result = Undefined;
	
	FormatVersions = ExchangeFormatVersions(InfobaseNode);
	
	For Each FormatVersion In FormatVersions Do
		
		If Result = Undefined Then
			Result = FormatVersion.Key;
			Continue;
		EndIf;
		If CompareVersions(TrimAll(Result), TrimAll(FormatVersion.Key)) > 0 Then
			Result = FormatVersion.Key;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Receives an array of exchange format versions sorted in descending order.
// Parameters:
//  InfobaseNode - ссылка на узел-correspondent.
//
Function ExhangeFormatVersionsArray(Val InfobaseNode) Export
	
	Return SortFormatVersions(ExchangeFormatVersions(InfobaseNode));
	
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - a number of version in either 0.0.0 or 0.0 format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number   - 
//             
//
Function CompareVersions(Val VersionString1, Val VersionString2)
	
	String1 = ?(IsBlankString(VersionString1), "0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	
	ErrorDescriptionTemplate = NStr("en = 'Invalid %1 parameter format: %2';");
	
	If Version1.Count() < 2 Or Version1.Count() > 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,"VersionString1", VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() < 2 Or Version2.Count() > 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorDescriptionTemplate,"VersionString2", VersionString2);
	EndIf;
	
	Result = 0;
	If TrimAll(VersionString1) = TrimAll(VersionString2) Then
		Return 0;
	EndIf;
	
	// The last digit can be beta which is the minimal version incompatible with any other version.
	If Version1.Count() = 3 And TrimAll(Version1[2]) = "beta" Then
		Return -1;
	ElsIf Version2.Count() = 3 And TrimAll(Version2[2]) = "beta" Then
		Return 1;
	EndIf;
	// When comparing, the first two digits are considered (always a number).
	For Digit = 0 To 1 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

Function VersionSupported(SupportedVersions, VersionToCheck)
	
	Result = False;
	
	For Each SupportedVersion In SupportedVersions Do
		If CompareVersions(SupportedVersion, VersionToCheck) >= 0 Then
			Result = True;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Other

Function SettingsStructureXTDO() Export
	
	Result = New Structure;
	
	Result.Insert("Format",                   "");
	Result.Insert("SupportedVersions",     New Array);
	Result.Insert("SupportedExtensions", New Map);
	Result.Insert("SupportedObjects",    New ValueTable);
	
	InitializeSupportedFormatObjectsTable(Result.SupportedObjects, "SendReceive");
		
	Return Result;
	
EndFunction

// Splits a string into two parts: before the separator substring and after it.
//
// Parameters:
//  Page1          - the string to parse;
//  Separator  - подстрока-separator:
//  Mode        - 0 - separator is not included in the returned substrings;
//                 1 - separator is included in the left substring;
//                 2 - separator is included in the right substring.
//
// Returns:
//  Правая часть строки - 
// 
Function SplitWithSeparator(Page1, Val Separator, Mode=0)

	RightPart         = "";
	SeparatorPos      = StrFind(Page1, Separator);
	SeparatorLength    = StrLen(Separator);
	If SeparatorPos > 0 Then
		RightPart	 = Mid(Page1, SeparatorPos + ?(Mode=2, 0, SeparatorLength));
		Page1          = TrimAll(Left(Page1, SeparatorPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction

// Returns a string presentation of the type which is expected for the data
// corresponding to the passed metadata object.
// It can be used as a value of the Type() embedded function parameter.
//
// Parameters:
//  MetadataObject - MetadataObject - to use for identifying the type name;
//
// Returns:
//  String - 
//
Function DataTypeNameByMetadataObject(Val MetadataObject)
	
	LiteralsOfType = StrSplit(MetadataObject.FullName(), ".");
	TableType = LiteralsOfType[0];
	
	If TableType = "Constant" Then
		
		TypeNameTemplate = "[TableType]ValueManager.[TableName]";
		
	ElsIf TableType = "InformationRegister"
		Or TableType = "AccumulationRegister"
		Or TableType = "AccountingRegister"
		Or TableType = "CalculationRegister" Then
		
		TypeNameTemplate = "[TableType]RecordSet.[TableName]";
		
	Else
		TypeNameTemplate = "[TableType]Ref.[TableName]";
	EndIf;
	
	TypeNameTemplate = StrReplace(TypeNameTemplate, "[TableType]", LiteralsOfType[0]);
	Result = StrReplace(TypeNameTemplate, "[TableName]", LiteralsOfType[1]);
	Return Result;
	
EndFunction

Procedure WritePublicIDIfNecessary(
		DataToWriteToIB,
		ReceivedDataRef,
		UUIDAsString,
		ConversionRule,
		ExchangeComponents)
		
	ExchangeNode = ExchangeComponents.CorrespondentNode;
	
	IdentificationOption = TrimAll(ConversionRule.IdentificationOption);
	If Not (IdentificationOption = "FirstByUUIDThenBySearchFields"
		Or IdentificationOption = "ByUUID")
		Or Not ValueIsFilled(ExchangeNode) Then
		Return;
	EndIf;
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", ExchangeNode);
	RecordStructure.Insert("Ref", ?(DataToWriteToIB = Undefined, ReceivedDataRef, DataToWriteToIB.Ref));

	UseCacheOfPublicIdentifiers = ExchangeComponents.UseCacheOfPublicIdentifiers;
	
	If Not UseCacheOfPublicIdentifiers
		And DataToWriteToIB <> Undefined
		And InformationRegisters.SynchronizedObjectPublicIDs.RecordIsInRegister(RecordStructure) Then
		
		Return;

	ElsIf UseCacheOfPublicIdentifiers
		And DataToWriteToIB <> Undefined
		And EntryIsInCacheOfPublicIdentifiers(RecordStructure, ExchangeComponents) Then
		
		Return;
		
	EndIf;
		
	PublicId = ?(ValueIsFilled(UUIDAsString), UUIDAsString, ReceivedDataRef.UUID());
	RecordStructure.Insert("Id", PublicId);
		
	InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure, True);
	
	AddEntryToPublicIdCache(RecordStructure, ExchangeComponents);
	
EndProcedure

Procedure AddExportedObjectsToPublicIDsRegister(ExchangeComponents)
	
	NodeForExchange = ExchangeComponents.CorrespondentNode;
	ExchangePlanContent = NodeForExchange.Metadata().Content;
	
	QueryTextTemplate2 = 
	"SELECT 
	|	ChangesTable.Ref
	|FROM 
	|	&MetadataTableName AS ChangesTable
	|LEFT JOIN 
	|	InformationRegister.SynchronizedObjectPublicIDs AS PublicIDs
	|ON PublicIDs.InfobaseNode = &Node AND PublicIDs.Ref = ChangesTable.Ref
	|WHERE ChangesTable.Node = &Node AND ChangesTable.MessageNo <= &MessageNo
	|	AND PublicIDs.Id IS NULL";
	
	For Each CompositionItem In ExchangePlanContent Do
		
		If Not Common.IsRefTypeObject(CompositionItem.Metadata) Then
			
			Continue;
			
		EndIf;
		
		MetadataTableName = StringFunctionsClientServer.SubstituteParametersToString("%1.Changes", CompositionItem.Metadata.FullName());
		QueryText = StrReplace(QueryTextTemplate2, "&MetadataTableName", MetadataTableName);
		
		Query = New Query(QueryText);
		Query.SetParameter("Node", NodeForExchange);
		Query.SetParameter("MessageNo", ExchangeComponents.MessageNumberReceivedByCorrespondent);
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("Ref", Selection.Ref);
			RecordStructure.Insert("InfobaseNode", ExchangeComponents.CorrespondentNode);
			RecordStructure.Insert("Id", Selection.Ref.UUID());
			InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure, True);
			
			AddEntryToPublicIdCache(RecordStructure, ExchangeComponents);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function XMLBasicSchema()
	
	Return "http://www.1c.ru/SSL/Exchange/Message";
	
EndFunction

Function VersionNumberWithDataExchangeIDSupport()
	Return "1.5";
EndFunction

Procedure InitializeSupportedFormatObjectsTable(ObjectsTable1, Mode)
	
	ObjectsTable1.Columns.Add("Version", New TypeDescription("String"));
	ObjectsTable1.Columns.Add("Object", New TypeDescription("String"));
	
	If StrFind(Mode, "Send") Then
		ObjectsTable1.Columns.Add("Send", New TypeDescription("Boolean"));
	EndIf;
	
	If StrFind(Mode, "Receive") Then
		ObjectsTable1.Columns.Add("Receive", New TypeDescription("Boolean"));
	EndIf;
	
	ObjectsTable1.Indexes.Add("Version, Object");
	
EndProcedure

Procedure FillSupportedFormatObjectsByExchangeComponents(ObjectsTable1, ExchangeComponents)
	
	If ExchangeComponents.ExchangeDirection = "Send" Then
		
		For Each ConversionRule In ExchangeComponents.ObjectsConversionRules Do
			
			ObjectType = ConversionRule.XDTOType; // XDTOObjectType
			
			Filter = New Structure;
			Filter.Insert("Version", ExchangeComponents.ExchangeFormatVersion);
			Filter.Insert("Object", ObjectType.Name);
			
			RowsObjects = ObjectsTable1.FindRows(Filter);
			If RowsObjects.Count() = 0 Then
				RowObjects = ObjectsTable1.Add();
				FillPropertyValues(RowObjects, Filter);
			Else
				RowObjects = RowsObjects[0];
			EndIf;
			
			RowObjects.Send = True;
			
		EndDo;
		
	ElsIf ExchangeComponents.ExchangeDirection = "Receive" Then
		
		For Each ProcessingRule In ExchangeComponents.DataProcessingRules Do
			
			Filter = New Structure;
			Filter.Insert("Version", ExchangeComponents.ExchangeFormatVersion);
			Filter.Insert("Object", ProcessingRule.FilterObjectFormat);
			
			RowsObjects = ObjectsTable1.FindRows(Filter);
			If RowsObjects.Count() = 0 Then
				RowObjects = ObjectsTable1.Add();
				FillPropertyValues(RowObjects, Filter);
			Else
				RowObjects = RowsObjects[0];
			EndIf;
			
			RowObjects.Receive = True;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function FormatObjectPassesXDTOFilter(ExchangeComponents, FormatObject)
	
	Return Not ExchangeComponents.IsExchangeViaExchangePlan
		Or ExchangeComponents.SupportedXDTOObjects.Find(FormatObject) <> Undefined;
	
EndFunction
	
Function ObjectPassesTablesToImportFilter(TablesToImport, DataTypeOnSend, DataTypeOnGet)
	
	If TablesToImport = Undefined Then
		Return True;
	EndIf;
	
	DataTableKey = DataExchangeServer.DataTableKey(DataTypeOnSend, DataTypeOnGet, False);
	
	Return TablesToImport.Find(DataTableKey) <> Undefined;
	
EndFunction

Function SearchByID(Val IdentificationOption)
	
	IdentificationOption = TrimAll(IdentificationOption);
	
	Return (IdentificationOption = "FirstByUUIDThenBySearchFields")
		Or (IdentificationOption = "ByUUID");
									
EndFunction
	
Procedure SupplementListOfObjectsForDeletion(ExchangeComponents, DataType, UUID, ArrayOfObjectsToDelete)
	
	RefForDeletion = ObjectRefByXDTODataObjectUUID(UUID,
		DataType, ExchangeComponents);
	If ArrayOfObjectsToDelete.Find(RefForDeletion) = Undefined Then
		ArrayOfObjectsToDelete.Add(RefForDeletion);
	EndIf;
	
EndProcedure

Procedure UpdateImportedObjectsCounter(ExchangeComponents)
	
	ExchangeComponents.ImportedObjectCounter = ExchangeComponents.ImportedObjectCounter + 1;
	DataExchangeServer.CalculateImportPercent(ExchangeComponents.ImportedObjectCounter,
		ExchangeComponents.ObjectsToImportCount, ExchangeComponents.ExchangeMessageFileSize);
	
EndProcedure

// Parameters:
//   XDTOObjectType - XDTOObjectType
//   Properties - Array of String
// 
Procedure FillXDTOObjectPropertiesList(XDTOObjectType, Properties)
	
	For Each ChildProperty In XDTOObjectType.Properties Do
		If TypeOf(ChildProperty.Type) = Type("XDTOObjectType")
			And StrStartsWith(ChildProperty.Type.Name, CommonPropertiesClass()) Then
			FillXDTOObjectPropertiesList(ChildProperty.Type, Properties);
		Else
			Properties.Add(ChildProperty.Name);
		EndIf;
	EndDo;
	
EndProcedure

Function FindNameOfExchangePlanThroughUniversalFormat(ExchangeComponents, XDTOConfirmation)

	If ExchangeComponents.DataExchangeWithExternalSystem Then
		Return DataExchangeCached.GetExchangePlanName(ExchangeComponents.CorrespondentNode);
	EndIf;
	
	If ValueIsFilled(ExchangeComponents.CorrespondentNode) Then
		
		Return DataExchangeServer.FindNameOfExchangePlanThroughUniversalFormat(XDTOConfirmation.ExchangePlan);
		
	Else
		
		ExchangePlanName = BroadcastName(XDTOConfirmation.ExchangePlan, "en");
		ExchangePlanName = Metadata.ExchangePlans.Find(ExchangePlanName);
		
	EndIf;
	
EndFunction

#EndRegion

#Region FormatBroadcast

Function BroadcastName(IshdnoeName, DirectionOfTranslation, AvailableNames = Undefined)
	
	If Metadata.ScriptVariant = Metadata.ObjectProperties.ScriptVariant.Russian Then
		Return IshdnoeName;
	EndIf;
	
	NewName = DataExchangeFormatTranslationCached.BroadcastName(IshdnoeName, DirectionOfTranslation);
	
	If TypeOf(NewName) = Type("String") Then
		
		Return NewName;
		
	ElsIf AvailableNames <> Undefined Then
		
		ArrayOfAvailableNames = New Array;
		
		If TypeOf(AvailableNames) = Type("Structure") Then
			For Each KeyAndValue In AvailableNames Do
				ArrayOfAvailableNames.Add(KeyAndValue.Key);
			EndDo;
		ElsIf TypeOf(AvailableNames) = Type("XDTOObjectType") Then
			For Each Property In AvailableNames.Properties Do
				ArrayOfAvailableNames.Add(Property.Name);
			EndDo;
		EndIf;
		
		For Each Name In NewName Do
			If ArrayOfAvailableNames.Find(Name) <> Undefined Then
				Return Name;
			EndIf;
		EndDo;
		
	Else
		
		Return NewName[0];
		
	EndIf;
	
EndFunction

Function BroadcastEnumeration(Name, DirectionOfTranslation, XDTOType)
	
	If Metadata.ScriptVariant = Metadata.ObjectProperties.ScriptVariant.Russian Then
		Return Name;
	EndIf;
	
	NewName = DataExchangeFormatTranslationCached.BroadcastName(Name, DirectionOfTranslation);
	
	If TypeOf(NewName) = Type("String") Then
		
		Return NewName;
		
	Else
		
		For Each Facet In XDTOType.Facets Do
			If NewName.Find(Facet.Value) <> Undefined Then
				Return Facet.Value; 
				Break;
			EndIf;
		EndDo;
	
	EndIf;
	
EndFunction

Function BroadcastStructure(Source, DirectionOfTranslation)
	
	If Metadata.ScriptVariant = Metadata.ObjectProperties.ScriptVariant.Russian Then
		Return Source;
	EndIf;
	
	If TypeOf(Source) = Type("Structure") Then
		
		Result = New Structure;
		
		For Each KeyAndValue In Source Do
			Var_Key = BroadcastName(KeyAndValue.Key, DirectionOfTranslation);
			Result.Insert(Var_Key, BroadcastStructure(KeyAndValue.Value, DirectionOfTranslation));
		EndDo;
		
		Return Result;
		
	ElsIf TypeOf(Source) = Type("Array") Then
		
		Result = New Array;
		
		For Each Ellie In Source Do
			Result.Add(BroadcastStructure(Ellie, DirectionOfTranslation));
		EndDo;
		
		Return Result;
		
	ElsIf TypeOf(Source) = Type("ValueTable") Then
		
		Result = Source.Copy();
		
		FirstColumn = True;
		
		For Each Column In Result.Columns Do
			
			Column.Name = BroadcastName(Column.Name, DirectionOfTranslation);
				
			For Each String In Result Do
				String[Column.Name] = BroadcastStructure(String[Column.Name], DirectionOfTranslation);
			EndDo;
			
		EndDo;
		
		Return Result;
		
	Else
		
		Return Source;
		
	EndIf;
	
EndFunction

Procedure BroadcastPredefinedData(ConversionRules)

	If Metadata.ScriptVariant = Metadata.ObjectProperties.ScriptVariant.Russian Then
		Return;
	EndIf;
	
	For Each String In ConversionRules Do
		
		If ValueIsFilled(String.ConvertValuesOnSend) Then
			
			ValuesWhenSending = New Map;
			
			For Each KeyAndValue In String.ConvertValuesOnSend Do
				ValuesWhenSending.Insert(KeyAndValue.Key, BroadcastName(KeyAndValue.Value, "ru"));
			EndDo;
			
			String.ConvertValuesOnSend = ValuesWhenSending;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region CacheOfPublicIdentifiers

Procedure FillInCacheOfPublicIdentifiers(ExchangeComponents, ExchangeFileName, XMLReader)
	
	If Not ExchangeComponents.UseCacheOfPublicIdentifiers Then
		Return;
	EndIf;
	
	BeginTime = DataExchangeValuationOfPerformance.StartMeasurement();
		
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(ExchangeComponents.ExchangeFile);
	
	Dereferencer = New DOMNamespaceResolver("ab",
		"http://v8.1c.ru/edi/edi_stnd/EnterpriseData/" + ExchangeComponents.ExchangeFormatVersion);
	Expression = "//ab:Ref";
	
	Result = DOMDocument.EvaluateXPathExpression(Expression, DOMDocument, Dereferencer);
	
	RefsCache = New ValueTable;
	RefsCache.Columns.Add("Id", New TypeDescription("String",,,, New StringQualifiers(36)));
	
	Types = New Array();
	Types.Add(TypeOf(ExchangeComponents.CorrespondentNode));
	RefsCache.Columns.Add("InfobaseNode", New TypeDescription(Types));
	
	While True Do
		
		FieldNode_ = Result.IterateNext();
		If FieldNode_ = Undefined Then
			Break;
		EndIf;
		
		NewRow = RefsCache.Add();
		NewRow.Id = FieldNode_.TextContent;
		NewRow.InfobaseNode = ExchangeComponents.CorrespondentNode;
		
	EndDo;
	
	RefsCache.GroupBy("Id, InfobaseNode");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	RefsCache.Id AS Id,
		|	RefsCache.InfobaseNode AS InfobaseNode
		|INTO RefsCache
		|FROM
		|	&RefsCache AS RefsCache
		|
		|INDEX BY
		|	Id,
		|	InfobaseNode
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IDs.Id AS Id,
		|	IDs.Ref AS Ref
		|FROM
		|	RefsCache AS RefsCache
		|		INNER JOIN InformationRegister.SynchronizedObjectPublicIDs AS IDs
		|		ON RefsCache.Id = IDs.Id
		|			AND RefsCache.InfobaseNode = IDs.InfobaseNode";
	
	Query.SetParameter("RefsCache", RefsCache);
	
	CacheOfPublicIdentifiers = Query.Execute().Unload();
	CacheOfPublicIdentifiers.Indexes.Add("Id");
	CacheOfPublicIdentifiers.Indexes.Add("Ref");
	
	ExchangeComponents.CacheOfPublicIdentifiers = CacheOfPublicIdentifiers ;
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(ExchangeFileName);
	ExchangeComponents.Insert("ExchangeFile", XMLReader);
	
	DataExchangeValuationOfPerformance.FinishMeasurement(
		BeginTime, "RefsSearch", "", ExchangeComponents, 
		DataExchangeValuationOfPerformance.EventTypeLibrary());
	
EndProcedure

Procedure DeleteEntryFromPublicIdCache(RecordStructure, ExchangeComponents)

	If Not ExchangeComponents.UseCacheOfPublicIdentifiers Then
		Return;
	EndIf;
	
	TheStructureOfTheSearch = New Structure();
	
	If RecordStructure.Property("Ref") Then
		TheStructureOfTheSearch.Insert("Ref", RecordStructure.Ref);
	EndIf;
	
	If RecordStructure.Property("Id") Then
		TheStructureOfTheSearch.Insert("Id", RecordStructure.Id);
	EndIf;
	
	CacheOfPublicIdentifiers = ExchangeComponents.CacheOfPublicIdentifiers;
	SearchResult = CacheOfPublicIdentifiers.FindRows(TheStructureOfTheSearch);
	
	For Each String In SearchResult Do
		CacheOfPublicIdentifiers.Delete(String);
	EndDo;
	
EndProcedure

Function EntryIsInCacheOfPublicIdentifiers(RecordStructure, ExchangeComponents)
	
	TheStructureOfTheSearch = New Structure();
	
	If RecordStructure.Property("Ref") Then
		TheStructureOfTheSearch.Insert("Ref", RecordStructure.Ref);
	EndIf;
	
	If RecordStructure.Property("Id") Then
		TheStructureOfTheSearch.Insert("Id", RecordStructure.Id);
	EndIf;
	
	SearchResult = ExchangeComponents.CacheOfPublicIdentifiers.FindRows(TheStructureOfTheSearch);
	
	Return SearchResult.Count() > 0; 
	
EndFunction

Procedure AddEntryToPublicIdCache(RecordStructure, ExchangeComponents)
	
	If Not ExchangeComponents.UseCacheOfPublicIdentifiers Then
		Return;
	EndIf;
	
	NewRow = ExchangeComponents.CacheOfPublicIdentifiers.Add();
	FillPropertyValues(NewRow, RecordStructure);
		
EndProcedure

#EndRegion

#Region EnterpriseDataFormatExtensions

Function AvailableFormatExtensions(ExchangeFormatVersion) Export
	
	Result = New Map;
	ExtensionsCollection = New Map;
	
	DataExchangeOverridable.OnGetAvailableFormatExtensions(ExtensionsCollection);
	
	ExtensionCounter = 1;
	For Each KeyValue In ExtensionsCollection Do
		
		If ExchangeFormatVersion <> KeyValue.Value Then
			
			Continue;
			
		EndIf;
		
		Result.Insert(KeyValue.Key, StrTemplate("ext%1", XMLString(ExtensionCounter)));
		ExtensionCounter = ExtensionCounter + 1;
		
	EndDo;

	Return Result;
	
EndFunction

Function TypeOfNestedPropertyByNameFromFormatExtension(ExchangeComponents, NameOfBaseProperty, NameOfExpandableProperty)
	
	ExtendedTSRowProperty = Undefined;
	For Each ExtensionDetails In ExchangeComponents.FormatExtensions Do
		
		TypeFromExtension = XDTOFactory.Type(ExtensionDetails.Key, NameOfBaseProperty);
		If TypeFromExtension = Undefined Then
			
			Continue;
			
		EndIf;
		
		ExtendedTSRowProperty = TypeFromExtension.Properties.Get(NameOfExpandableProperty);
		Break;
		
	EndDo;
	
	If ExtendedTSRowProperty <> Undefined Then
		
		Return ExtendedTSRowProperty.Type;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function SetExtensionOfTablePartRow(NestedExtensions, TabularSectionName)
	
	If TypeOf(NestedExtensions) = Type("Map") Then
		
		ExtensionsOfTableParts = NestedExtensions.Get("ExtensionsOfTableParts");
		If ExtensionsOfTableParts <> Undefined Then
			
			Return ExtensionsOfTableParts.Get(TabularSectionName);
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function InstallKeyPropertyExtension(NestedExtensions, NameOfKeyProperty)
	
	If TypeOf(NestedExtensions) = Type("Map") Then
		
		ExtensionsOfKeyProperties = NestedExtensions.Get("ExtensionsOfKeyProperties");
		If ExtensionsOfKeyProperties <> Undefined Then
			
			Return ExtensionsOfKeyProperties.Get(NameOfKeyProperty);
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure AddPackagePropertiesFromExtensions(SourceProperties, ExchangeComponents, Extensions, NestedExtensions)
	
	If Extensions = Undefined Then
		
		Return;
		
	EndIf;
	
	// 
	// 
	For Each Extension In Extensions Do
		
		If ExchangeComponents.FormatExtensions.Get(Extension.Key) = Undefined Then
			
			Continue;
			
		EndIf;
		
		ExtendedXDTOType = Undefined;
		TheNecessaryPropertiesAreMissing = True;
		If Extension.Value.Property("XDTOType", ExtendedXDTOType) Then
			
			TheNecessaryPropertiesAreMissing = False;
			
		ElsIf Extension.Value.Property("CompositePropertyType", ExtendedXDTOType) Then
			
			TheNecessaryPropertiesAreMissing = False;
			
		EndIf;
		
		If TheNecessaryPropertiesAreMissing
			Or ExtendedXDTOType = Undefined Then
			
			Continue;
			
		EndIf;
		
		For Each Property In ExtendedXDTOType.Properties Do
			
			If Property.NamespaceURI <> Extension.Key Then
				
				If IsObjectTable(Property) Then
					
					ExtensionsOfTablePartsByMainExtensions(Property, Extension, NestedExtensions["ExtensionsOfTableParts"]);
					
				ElsIf Property.Name = ClassKeyFormatProperties()
					Or StrFind(Property.Type.Name, ClassKeyFormatProperties()) > 0 Then
					
					ExtensionsOfKeyPropertiesByMajorExtensions(Property, Extension, NestedExtensions["ExtensionsOfKeyProperties"]);
					
				EndIf;
					
				Continue;
				
			EndIf;
				
			SourceProperties.Add(Property);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure AddKeyPackagePropertiesFromExtensions(ConversionRule, KeyPropertiesTypeOfXDTOObject, ArrayOfKeyProperties)
	
	If ConversionRule.Extensions.Count() < 1 Then
		
		Return;
		
	EndIf;
	
	For Each Extension In ConversionRule.Extensions Do
		
		ExtendedObjectTypeXDTO = XDTOFactory.Type(Extension.Key, KeyPropertiesTypeOfXDTOObject.Name);
		If ExtendedObjectTypeXDTO = Undefined Then
			
			Continue;
			
		EndIf;
		
		For Each PropertyFromPackageExtension In ExtendedObjectTypeXDTO.Properties Do
			
			If Extension.Key <> PropertyFromPackageExtension.NamespaceURI
				Or ArrayOfKeyProperties.Find(PropertyFromPackageExtension.Name) <> Undefined Then
				
				Continue;
				
			EndIf;
			
			If TypeOf(PropertyFromPackageExtension.Type) = Type("XDTOObjectType")
				And StrStartsWith(PropertyFromPackageExtension.Type.Name, CommonPropertiesClass()) Then
				
				AddKeyPackagePropertiesFromExtensions(ConversionRule, PropertyFromPackageExtension.Type, ArrayOfKeyProperties);
				
			Else
				
				ArrayOfKeyProperties.Add(PropertyFromPackageExtension.Name);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure AddThePropertiesOfActiveExtensionsToTheTable(ExchangeComponents, XDTOValueType, XDTODataValue, Value)
	
	If Not IsBaseSchema(ExchangeComponents, XDTOValueType.NamespaceURI)
		Or ExchangeComponents.FormatExtensions.Count() = 0 Then
		
		Return;
		
	EndIf;
	

	For Each Extension In ExchangeComponents.FormatExtensions Do
		
		ExtensionOfTheValueTypeXDTO = XDTOFactory.Type(Extension.Key, XDTOValueType.Name);
		If ExtensionOfTheValueTypeXDTO = Undefined Then
			
			Continue;
			
		EndIf;
		
		For Each KeyProperty In XDTODataValue.Properties() Do
			
			PropertyDetails = ExtensionOfTheValueTypeXDTO.Properties.Get(KeyProperty.Name);
			If PropertyDetails = Undefined Then
				
				Continue;
				
			EndIf;
			
			ConvertXDTOPropertyToStructureItem(XDTODataValue, KeyProperty, Value, ExchangeComponents,,PropertyDetails.Type);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure ExtensionsOfKeyPropertiesByMajorExtensions(Property, Extension, ExtensionsOfKeyProperties)
	
	ExtendedKeyPropertiesTypeXDTO = XDTOFactory.Type(Extension.Key, Property.Type.Name);
	If ExtendedKeyPropertiesTypeXDTO = Undefined Then
		
		Return;
		
	EndIf;
	
	If ExtensionsOfKeyProperties = Undefined Then
		
		ExtensionsOfKeyProperties = New Map;
		
	EndIf;
	
	StructureOfTheObjectConversionRuleExtension = New Structure;
	StructureOfTheObjectConversionRuleExtension.Insert("XDTOType", ExtendedKeyPropertiesTypeXDTO);
	StructureOfTheObjectConversionRuleExtension.Insert("KeyPropertiesTypeOfXDTOObject");
	StructureOfTheObjectConversionRuleExtension.Insert("DataType");
	
	DescriptionOfKeyPropertyExtension = New Map;
	DescriptionOfKeyPropertyExtension.Insert(Extension.Key, StructureOfTheObjectConversionRuleExtension);
	
	ExtensionsOfKeyProperties.Insert(Property.Type.Name, DescriptionOfKeyPropertyExtension);
	
EndProcedure

Procedure ExtensionsOfTablePartsByMainExtensions(Property, Extension, ExtensionsOfTableParts)
	
	ExtendedTablePartTypeXDTO = XDTOFactory.Type(Extension.Key, Property.Type.Properties[0].Type.Name);
	If ExtendedTablePartTypeXDTO = Undefined Then
		
		Return;
		
	EndIf;
	
	If ExtensionsOfTableParts = Undefined Then
		
		ExtensionsOfTableParts = New Map;
		
	EndIf;
	
	StructureOfTheObjectConversionRuleExtension = New Structure;
	StructureOfTheObjectConversionRuleExtension.Insert("XDTOType", ExtendedTablePartTypeXDTO);
	StructureOfTheObjectConversionRuleExtension.Insert("KeyPropertiesTypeOfXDTOObject");
	StructureOfTheObjectConversionRuleExtension.Insert("DataType");
	
	DescriptionOfExtensionOfTablePart = New Map;
	DescriptionOfExtensionOfTablePart.Insert(Extension.Key, StructureOfTheObjectConversionRuleExtension);
	
	ExtensionsOfTableParts.Insert(Property.Name, DescriptionOfExtensionOfTablePart);
	
EndProcedure

#EndRegion

#EndRegion


