///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Private

// Prepares the ExchangeComponents structure.
// Parameters:
//   ExchangeDirection - String - Sending or Receiving.
//   ExchangeFormatVersionOnImport1 - String - a format version to be used on data import.
//
// Returns:
//   Structure - 
//
Function ExchangeComponents(ExchangeDirection, ExchangeFormatVersionOnImport1 = "", FormatExtensionOnImport = "") 
	
	ExchangeComponents     = DataExchangeXDTOServer.InitializeExchangeComponents(ExchangeDirection);
	CurrFormatVersion     = ?(ExchangeDirection = "Send", FormatVersion, ExchangeFormatVersionOnImport1);
	CurrentFormatExtension = ?(ExchangeDirection = "Send", FormatExtension, FormatExtensionOnImport);
	If ValueIsFilled(ExchangeNode) And ExchangeDirection = "Send" Then
		ExchangeComponents.IsExchangeViaExchangePlan = True;
		ExchangeComponents.CorrespondentNode = ExchangeNode;
		ExchangeComponents.ObjectsRegistrationRulesTable = DataExchangeXDTOServer.ObjectsRegistrationRules(ExchangeNode);
		ExchangeComponents.ExchangePlanNodeProperties = DataExchangeXDTOServer.ExchangePlanNodeProperties(ExchangeNode);
		ExchangeComponents.ExchangeViaProcessingUploadUploadED = True;
	Else
		ExchangeComponents.IsExchangeViaExchangePlan = False;
	EndIf;
	ExchangeComponents.EventLogMessageKey = NStr("en = 'Clipboard data transfer';", Common.DefaultLanguageCode());
	ExchangeComponents.ExchangeFormatVersion = CurrFormatVersion;
	ExchangeComponents.XMLSchema = "http://v8.1c.ru/edi/edi_stnd/EnterpriseData/" + CurrFormatVersion;
	DataExchangeXDTOServer.IncludeNamespace(ExchangeComponents, CurrentFormatExtension, "ext");
	
	ExchangeManagerInternal = False;
	If Common.DataSeparationEnabled() Then
		ExchangeManagerInternal = True;
	ElsIf ValueIsFilled(PathToExportExchangeManager)
		Or ValueIsFilled(PathToImportExchangeManager) Then
		Raise
			NStr("en = 'The external data processor (debugger) is not supported.';");
	ElsIf ValueIsFilled(ExchangeNode)
		And Common.HasObjectAttribute("ExchangeManagerPath", ExchangeNode.Metadata()) Then
		ExchangeManagerPath = Common.ObjectAttributeValue(ExchangeNode, "ExchangeManagerPath");
		If ValueIsFilled(ExchangeManagerPath) Then
			Raise
				NStr("en = 'The external data processor (debugger) is not supported.';");
		Else
			ExchangeManagerInternal = True;
		EndIf;
	Else
		ExchangeManagerInternal = True;
	EndIf;
	If ExchangeManagerInternal Then
		ExchangeFormatVersions = New Map;
		DataExchangeOverridable.OnGetAvailableFormatVersions(ExchangeFormatVersions);
		ExchangeComponents.ExchangeManager = ExchangeFormatVersions.Get(CurrFormatVersion);
		If ExchangeComponents.ExchangeManager = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The exchange format version is not supported: %1.';"), CurrFormatVersion);
		EndIf;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		DataExchangeXDTOServer.FillXDTOSettingsStructure(ExchangeComponents);
		DataExchangeXDTOServer.FillSupportedXDTOObjects(ExchangeComponents);
	EndIf;
	
	DataExchangeXDTOServer.AfterInitializationOfTheExchangeComponents(ExchangeComponents);
	
	Return ExchangeComponents;
	
EndFunction

// Exports data according to the settings.
// Parameters:
//   ParametersStructure - Structure - processing parameters:
//    * ExportLocation - Number - 0 (to a file), 1 (to a text).
//    * IsBackgroundJob - Boolean - indicates that the background job procedure is called.
//      Structure contains data to fill in the object attributes upon running from the background job.
//   AddressToPlaceResult - String - address in temporary storage.
// 
// Returns:
//   String - 
//
Function ExportToXMLResult(ParametersStructure, AddressToPlaceResult = Undefined) Export
	
	ExportLocation = ParametersStructure.ExportLocation;
	
	If ParametersStructure.Property("IsBackgroundJob") Then
		FillPropertyValues(ThisObject, ParametersStructure);
	EndIf;
	
	ListExportAddition.Clear();
	FillListOfObjectsToExport();
	
	ExportResult = ExportDataToXML();
	
	If ExportResult.HasErrors Then
		MessageText = NStr("en = 'Operation execution errors';") + ": "
			+ Chars.LF + ExportResult.ErrorText
			+ Chars.LF + NStr("en = 'Some data might not be exported.';");
		Common.MessageToUser(MessageText);
	ElsIf Not ExportResult.HasExportedObjects Then
		MessageText = NStr("en = 'There are no objects to export.';");
		Common.MessageToUser(MessageText);
	EndIf;
	
	If ExportLocation = 0 Then
		// Into file.
		TX = New TextDocument;
		TX.SetText(ExportResult.ExportText);
		AddressOnServer = GetTempFileName("xml");
		TX.Write(AddressOnServer);
		
		If AddressToPlaceResult = Undefined Then
			StorageAddress = PutToTempStorage(New BinaryData(AddressOnServer));
		Else
			PutToTempStorage(New BinaryData(AddressOnServer), AddressToPlaceResult);
			StorageAddress = AddressToPlaceResult;
		EndIf;
		DeleteFiles(AddressOnServer);
	Else
		// Into text.
		If AddressToPlaceResult = Undefined Then
			StorageAddress = PutToTempStorage(ExportResult.ExportText);
		Else
			PutToTempStorage(ExportResult.ExportText, AddressToPlaceResult);
			StorageAddress = AddressToPlaceResult;
		EndIf;
	EndIf;
	
	Return StorageAddress;
	
EndFunction

// Exports objects by settings specified in the data processor attributes and returns the export result.
// 
// Returns:
//   Structure - 
//     * ExportText - String - an exchange message text.
//     * HasExportedObjects - Boolean - True if at least one object is exported.
//     * HasErrors - Boolean - True if errors occurred during export.
//     * ErrorText - String - an error text on import.
//     * ExportedObjects - Array - an array of exported objects by data processor settings.
//     * ExportedByRefObjects - Array - an array of exported objects by references.
//
Function ExportDataToXML()
	
	ExchangeComponents = ExchangeComponents("Send");
	
	// 
	DataExchangeXDTOServer.OpenExportFile(ExchangeComponents);
	
	HasExportedObjects      = False;
	HasErrorsBeforeConversion = False;
	
	SetPrivilegedMode(True);
	
	Try
		ExchangeComponents.ExchangeManager.BeforeConvert(ExchangeComponents);
	Except
		HasErrorsBeforeConversion = True;
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Event: %1.
				|Handler: BeforeConvert.
				|
				|Handler execution error.
				|%2.';"),
			ExchangeComponents.ExchangeDirection,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorText);
	EndTry;
	
	If ValueIsFilled(ExchangeNode)
		And Not HasErrorsBeforeConversion Then
		
		ExchangePlanContent = ExchangeNode.Metadata().Content;
		
		// Inner join with the main table is required to exclude dead reference from the export.
		QueryTextTemplate2 =
		"SELECT 
		|	ChangesTable.Ref
		|FROM 
		|	&FullNameOfTheChangeMetadataTable AS ChangesTable
		|		INNER JOIN &FullNameOfTheMetadataTable AS MainTable
		|		ON MainTable.Ref = ChangesTable.Ref
		|WHERE ChangesTable.Node = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", ExchangeNode);
		
		For Each CompositionItem In ExchangePlanContent Do
			
			If Not Common.IsRefTypeObject(CompositionItem.Metadata) Then
				
				Continue;
				
			EndIf;
			
			FullObjectName = CompositionItem.Metadata.FullName();
			ProcessingRule = ExchangeComponents.DataProcessingRules.Find(CompositionItem.Metadata, "SelectionObjectMetadata");
			If ProcessingRule = Undefined Then
				
				Continue;
				
			EndIf;
			
			FullNameOfTheChangeObject = StringFunctionsClientServer.SubstituteParametersToString("%1.Changes", FullObjectName);
			QueryText = StrReplace(QueryTextTemplate2, "&FullNameOfTheChangeMetadataTable", FullNameOfTheChangeObject);
			Query.Text = StrReplace(QueryText, "&FullNameOfTheMetadataTable", FullObjectName);
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				DataExchangeXDTOServer.ExportSelectionObject(ExchangeComponents, Selection.Ref.GetObject(), ProcessingRule);
				HasExportedObjects = HasExportedObjects Or Not ExchangeComponents.FlagErrors;
			EndDo;
		EndDo;
	EndIf;
	
	If ListExportAddition.Count() > 0 Then
		For Each ListItem In ListExportAddition Do
			ExportRef = ListItem.Value;
			ExportRefMetadata = ExportRef.Metadata();
			ProcessingRule = ExchangeComponents.DataProcessingRules.Find(ExportRefMetadata, "SelectionObjectMetadata");
			If ProcessingRule = Undefined Then
				Continue;
			EndIf;
			If Common.IsRefTypeObject(ExportRefMetadata) Then
				ObjectForExport = ExportRef.GetObject();
			Else
				ObjectForExport = ExportRef;
			EndIf;
			DataExchangeXDTOServer.ExportSelectionObject(ExchangeComponents, ObjectForExport, ProcessingRule);
			HasExportedObjects = True;
		EndDo;
	EndIf;
	
	If Not HasErrorsBeforeConversion Then
		Try
			ExchangeComponents.ExchangeManager.AfterConvert(ExchangeComponents);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Event: %1.
					|Handler: AfterConvert.
					|
					|Handler execution error.
					|%2.';"),
				ExchangeComponents.ExchangeDirection,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorText);
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Body
	ExchangeComponents.ExchangeFile.WriteEndElement(); // Message
	
	ExportText = ExchangeComponents.ExchangeFile.Close();
	
	ExportResult = New Structure;
	ExportResult.Insert("ExportText",              ExportText);
	ExportResult.Insert("HasExportedObjects",     HasExportedObjects);
	ExportResult.Insert("HasErrors",                 ExchangeComponents.FlagErrors);
	ExportResult.Insert("ErrorText",                ExchangeComponents.ErrorMessageString);
	ExportResult.Insert("ExportedObjects",         ExchangeComponents.ExportedObjects);
	ExportResult.Insert("ExportedByRefObjects", ExchangeComponents.ExportedByRefObjects);
	
	Return ExportResult;
	
EndFunction

// Imports a message.
// Parameters:
//   ParametersStructure - Structure:
//    * XMLText - String - a message to export (on export from the text).
//    * AddressOnServer - String - a name of temporary file with export data (on export from the file)
//   ResultAddress - String - address of the result on start from the background job.
//
Procedure MessageImport(ParametersStructure, ResultAddress) Export
	
	XMLReader = New XMLReader;
	
	If ParametersStructure.Property("IsBackgroundJob") Then
		
		FillPropertyValues(ThisObject, ParametersStructure);
		
	EndIf;
	
	AddressOnServer = "";
	If ParametersStructure.Property("AddressOnServer", AddressOnServer) Then
		
		XMLReader.OpenFile(ParametersStructure.AddressOnServer);
		
	Else
		
		XMLReader.SetString(ParametersStructure.XMLText);
		
	EndIf;
	
	ImportResult1 = ImportDataFromXML(XMLReader);
	XMLReader.Close();
	
	Try
		
		If ValueIsFilled(AddressOnServer) Then
		
			DeleteFiles(AddressOnServer);
			
		EndIf;
		
	Except
		
		LogEvent = DataExchangeServer.DataExchangeEventLogEvent();
		ErrorDescription = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(LogEvent, EventLogLevel.Error, , , ErrorDescription);
		
	EndTry;
	
	If ImportResult1.HasErrors Then
		
		Raise ImportResult1.ErrorText;
		
	EndIf;

EndProcedure

// Imports data from the exchange message.
//
// Parameters:
//  XMLReader	 - XMLReader - the XMLReader object initialized by the exchange message.
// 
// Returns:
//   Structure:
//    * HasErrors - Boolean - a flag showing that errors occurred while importing the exchange message.
//    * ErrorText - String - an error message text.
//    * ImportedObjects - Array - an imported objects array.
//
Function ImportDataFromXML(XMLReader)
	
	ImportResult1 = New Structure;
	ImportResult1.Insert("HasErrors", False);
	ImportResult1.Insert("ErrorText", "");
	ImportResult1.Insert("ImportedObjects", New Array);
	
	XMLReader.Read(); // Message
	XMLReader.Read(); // Header
	TitleXDTOMessages = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type("http://www.1c.ru/SSL/Exchange/Message", "Header"));
	If XMLReader.NodeType <> XMLNodeType.StartElement
		Or XMLReader.LocalName <> "Body" Then
		
		ImportResult1.HasErrors = True;
		ImportResult1.ErrorText = NStr("en = 'Cannot read the import message. Invalid message format.';");
		
		Return ImportResult1;
	EndIf;
	
	FormatStructure = StrSplit(TitleXDTOMessages.Format, " ", False);
	
	ExchangeFormat = ParseExchangeFormat(FormatStructure[0]);
	FormatVersionForImport = ExchangeFormat.Version;
	FormatExtensionForImport = "";
	
	If FormatStructure.Count() > 0 Then
		FormatExtensionForImport = FormatStructure[FormatStructure.UBound()];
	EndIf;
	
	ExchangeComponents = ExchangeComponents("Receive", FormatVersionForImport, FormatExtensionForImport);
	
	XMLReader.Read(); // Body
	ExchangeComponents.Insert("ExchangeFile", XMLReader);
	
	SetPrivilegedMode(True);
	DataExchangeInternal.DisableAccessKeysUpdate(True);
	Try
		DataExchangeXDTOServer.RunReadingData(ExchangeComponents);
		DataExchangeInternal.DisableAccessKeysUpdate(False);
	Except
		DataExchangeInternal.DisableAccessKeysUpdate(False);
		Raise;
	EndTry;
	SetPrivilegedMode(False);
	
	If ExchangeComponents.FlagErrors Then
		ImportResult1.HasErrors = True;
		ImportResult1.ErrorText = ExchangeComponents.ErrorMessageString;
	EndIf;
	
	ImportResult1.ImportedObjects = ExchangeComponents.ImportedObjects.UnloadColumn("ObjectReference");
	
	Return ImportResult1;
	
EndFunction

// Fills the list of the metadata objects available to export according to exchange components.
Procedure FillExportRules() Export
	ExchangeComponents = ExchangeComponents("Send");
	ExportRulesTable.Rows.Clear();
	TreeNodeCatalogs = ExportRulesTable.Rows.Add();
	TreeNodeCatalogs.IsFolder = True;
	TreeNodeCatalogs.Description = NStr("en = 'Catalogs';");
	
	TreeNodeDocuments = ExportRulesTable.Rows.Add();
	TreeNodeDocuments.IsFolder = True;
	TreeNodeDocuments.Description = NStr("en = 'Documents';");
	TreeNodeDocuments.FilterByPeriod = True;

	CCTTreeNode = ExportRulesTable.Rows.Add();
	CCTTreeNode.IsFolder = True;
	CCTTreeNode.Description = NStr("en = 'Charts of characteristic types';");
	
	For Each DPRRow In ExchangeComponents.DataProcessingRules Do
		CurrMetadata = DPRRow.SelectionObjectMetadata;
		If CurrMetadata = Undefined Then
			Continue;
		EndIf;
		
		CurName = CurrMetadata.Name;
		CurrSynonym = CurrMetadata.Synonym;
		FullMDNameAsString = "";
		NewString = Undefined;
		If Metadata.Catalogs.Contains(CurrMetadata) Then
			NewString = TreeNodeCatalogs.Rows.Add();
			FullMDNameAsString = "Catalog." + CurName;
			Presentation = NStr("en = '""%1"" catalog';");
		ElsIf Metadata.Documents.Contains(CurrMetadata) Then
			NewString = TreeNodeDocuments.Rows.Add();
			NewString.FilterByPeriod = True;
			FullMDNameAsString = "Document." + CurName;
			Presentation = NStr("en = '""%1"" document';");
		ElsIf  Metadata.ChartsOfCharacteristicTypes.Contains(CurrMetadata) Then
			NewString = CCTTreeNode.Rows.Add();
			FullMDNameAsString = "ChartOfCharacteristicTypes." + CurName;
			Presentation = NStr("en = '""%1"" chart of characteristic types';");
		Else
			// Export of other metadata objects is not supported.
			Continue;
		EndIf;
		Presentation = StrReplace(Presentation, "%1", CurrSynonym);
		NewString.IsFolder = False;
		NewString.Description = CurrSynonym;
		NewString.FullMetadataName = FullMDNameAsString;
		NewString.Presentation = Presentation;
		StructureFilter = New Structure("FullMetadataName", FullMDNameAsString);
		Filter_Settings = AdditionalRegistration.FindRows(StructureFilter);
		NewString.FilterPresentation = "";
		If Filter_Settings.Count() > 0 Then
			NewString.Enable = True;
			For Each CurSetting In Filter_Settings Do
				If ValueIsFilled(CurSetting.FilterAsString) Then
					NewString.FilterPresentation = NewString.FilterPresentation + ", "+ TrimAll(CurSetting.FilterAsString);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	// Remove extra branches.
	If TreeNodeCatalogs.Rows.Count() = 0 Then
		ExportRulesTable.Rows.Delete(TreeNodeCatalogs);
	EndIf;
	If TreeNodeDocuments.Rows.Count() = 0 Then
		ExportRulesTable.Rows.Delete(TreeNodeDocuments);
	EndIf;
	If CCTTreeNode.Rows.Count() = 0 Then
		ExportRulesTable.Rows.Delete(CCTTreeNode);
	EndIf;
EndProcedure

//  Returns a filters composer for a single metadata kind.
//
//  Parameters:
//      FullMetadataName  - String - a table name for filling composer settings. Perhaps there will be 
//                                      IDs for all documents or all catalogs
//                                      or reference to the group.
//      Presentation        - String - object presentation in the filter.
//      Filter                - DataCompositionFilter - a composition filter for filling.
//      SchemaSavingAddress - String
//                           - UUID - 
//                             
//
// Returns:
//      DataCompositionSettingsComposer - 
//
Function SettingsComposerByTableName(FullMetadataName, Presentation = Undefined, Filter = Undefined, SchemaSavingAddress = Undefined) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
	
	For Each TableName In TablesToAdd Do
		AddSetToCompositionSchema(CompositionSchema, TableName, Presentation);
	EndDo;
	
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	
	If Filter <> Undefined Then
		AddDataCompositionFilterValues(Composer.Settings.Filter.Items, Filter.Items);
		Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
	Return Composer;
EndFunction

// Returns a name array of metadata tables according to the FullMetadataName composite parameter type.
//
// Parameters:
//      FullMetadataName - String
//                          - ValueTree - 
//                            
//                            
//
// Returns:
//      Array - metadata names.
//
Function EnlargedMetadataGroupComposition(FullMetadataName) 
	MetadataIteration = False;
	CompositionTables = New Array;
	If TypeOf(FullMetadataName) <> Type("String") Then
		// Value tree with a filter group. The root is the description, the rows are metadata names.
		For Each GroupRow In FullMetadataName.Rows Do
			For Each GroupCompositionRow In GroupRow.Rows Do
				CompositionTables.Add(GroupCompositionRow.FullMetadataName);
			EndDo;
		EndDo;
		
	ElsIf FullMetadataName = "AllDocuments" Then
		MetadataIteration = True;
		MetaObjects = Metadata.Documents;
	ElsIf FullMetadataName = "AllCatalogs" Then
		MetadataIteration = True;
		MetaObjects = Metadata.Catalogs;
	ElsIf FullMetadataName = "AllChartsOfCharacteristicTypes" Then
		MetadataIteration = True;
		MetaObjects = Metadata.ChartsOfCharacteristicTypes;
	Else
		// 
		CompositionTables.Add(FullMetadataName);
	EndIf;
	If MetadataIteration Then
		For Each MetaObject In MetaObjects Do
			CompositionTables.Add(MetaObject.FullName());
		EndDo;
	EndIf;
	
	Return CompositionTables;
EndFunction

// Returns period and filter details as string.
//
//  Parameters:
//      Period - StandardPeriod     - a period to describe filter.
//      Filter  - DataCompositionFilter - a data composition filter to describe.
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
//  Returns:
//   String - 
//
Function FilterPresentation(Period, Filter, Val EmptyFilterDetails = Undefined) Export
	OurFilter = ?(TypeOf(Filter)=Type("DataCompositionSettingsComposer"), Filter.Settings.Filter, Filter);
	
	PeriodAsString = ?(ValueIsFilled(Period), String(Period), "");
	FilterAsString  = String(OurFilter);
	
	If IsBlankString(FilterAsString) Then
		If EmptyFilterDetails=Undefined Then
			FilterAsString = NStr("en = 'All objects';");
		Else
			FilterAsString = EmptyFilterDetails;
		EndIf;
	EndIf;
	
	If Not IsBlankString(PeriodAsString) Then
		FilterAsString =  PeriodAsString + ", " + FilterAsString;
	EndIf;
	
	Return FilterAsString;
EndFunction

// Adds a filter to the filter end with possible fields adjustment.
//
//  Parameters:
//      DestinationItems - DataCompositionFilterItemCollection - destination.
//      SourceItems - DataCompositionFilterItemCollection - source.
//      FieldsMap - Map - data for fields adjustment:
//                          Key - an initial path to the field data, Value - a path 
//                          for the result. For example, to replace type fields.
//                          "Ref.Description" -> "ObjectRef.Description"
//                          pass New Structure("Ref", "ObjectRef").
//
Procedure AddDataCompositionFilterValues(DestinationItems, SourceItems, FieldsMap = Undefined) 
	
	For Each Item In SourceItems Do
		
		Type=TypeOf(Item);
		FilterElement = DestinationItems.Add(Type);
		FillPropertyValues(FilterElement, Item);
		If Type=Type("DataCompositionFilterItemGroup") Then
			AddDataCompositionFilterValues(FilterElement.Items, Item.Items, FieldsMap);
			
		ElsIf FieldsMap<>Undefined Then
			SourceFieldAsString = Item.LeftValue;
			For Each KeyValue In FieldsMap Do
				ControlNewField     = Lower(KeyValue.Key);
				ControlLength     = 1 + StrLen(ControlNewField);
				ControlSourceField = Lower(Left(SourceFieldAsString, ControlLength));
				If ControlSourceField=ControlNewField Then
					FilterElement.LeftValue = New DataCompositionField(KeyValue.Value);
					Break;
				ElsIf ControlSourceField=ControlNewField + "." Then
					FilterElement.LeftValue = New DataCompositionField(KeyValue.Value + Mid(SourceFieldAsString, ControlLength));
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Prepares a list of objects to be exported in accordance with the settings.
Procedure FillListOfObjectsToExport() 
	SetPrivilegedMode(True);
	// 
	// 
	// 
	MetadataArrayWithoutFilters = New Array;
	MetadataArrayFilterByPeriod = New Array;
	For Each String In AdditionalRegistration Do
		FullMetadataName = String.FullMetadataName;
		CurrentFilter = String.Filter; // DataCompositionFilter
		If CurrentFilter.Items.Count() = 0 Then
			If String.PeriodSelection And ValueIsFilled(AllDocumentsFilterPeriod) Then
				MetadataArrayWithoutFilters.Add(FullMetadataName);
			Else
				MetadataArrayFilterByPeriod.Add(FullMetadataName);
			EndIf;
		Else
			ArrayFilter = New Array;
			ArrayFilter.Add(FullMetadataName);
			AddListOfObjectsToExport(ArrayFilter);
		EndIf;
	EndDo;
	If MetadataArrayWithoutFilters.Count() > 0 Then
		AddListOfObjectsToExport(MetadataArrayWithoutFilters);
	EndIf;
	If MetadataArrayFilterByPeriod.Count() > 0 Then
		AddListOfObjectsToExport(MetadataArrayFilterByPeriod);
	EndIf;
EndProcedure

// Returns an extended object presentation.
// Parameters:
//  ParameterObject - Arbitrary - a string with a full metadata name or a metadata object.
// Returns:
//  String - representation of objects.
//
Function ObjectPresentation(ParameterObject) 
	
	If ParameterObject = Undefined Then
		Return "";
	EndIf;
	ObjectMetadata = ?(TypeOf(ParameterObject) = Type("String"), Metadata.FindByFullName(ParameterObject), ParameterObject);
	
	// There can be no presentation attributes, iterating through structure.
	Presentation = New Structure("ExtendedObjectPresentation, ObjectPresentation");
	FillPropertyValues(Presentation, ObjectMetadata);
	If Not IsBlankString(Presentation.ExtendedObjectPresentation) Then
		Return Presentation.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Presentation.ObjectPresentation) Then
		Return Presentation.ObjectPresentation;
	EndIf;
	
	Return ObjectMetadata.Presentation();
EndFunction

//  Sets the data sets to the schema and initializes the composer.
//  Is based on attribute values:
//    "AdditionalRegistration", "AllDocumentsFilterPeriod", "AllDocumentsFilterComposer".
//
//  Parameters:
//      MetadataNamesList - Array - metadata names (trees of restriction group values, internal
//                                      IDs
//                                      of "All documents" or "All regulatory data") that serve as a basis for the composition schema. 
//                                      If it is Undefined, all metadata types from node content are used.
//
//      SchemaSavingAddress - String
//                           - UUID - 
//                             
//
//  Returns:
//      Structure:
//         * NodeCompositionMetadataTable - ValueTable - node content description.
//         * CompositionSchema - DataCompositionSchema - an initialized value.
//         * SettingsComposer - DataCompositionSettingsComposer - an initialized value.
//
Function InitializeComposer(MetadataNamesList = Undefined, SchemaSavingAddress = Undefined)
	
	CompositionSchema = GetTemplate("DataCompositionSchema");
	DataSource = CompositionSchema.DataSources.Get(0).Name;

	// Sets for each metadata type included in the exchange.
	SetItemsChanges = CompositionSchema.DataSets.Find("ChangeRecords").Items;
	While SetItemsChanges.Count() > 1 Do
		// [0] - 
		SetItemsChanges.Delete(SetItemsChanges[1]);
	EndDo;
	AdditionalChangesTable = AdditionalRegistration;
	
	QueryTextTemplate2 = "SELECT ALLOWED
	|	AliasOfTheMetadataTable.Ref AS ObjectRef,
	|	&NameOfTableToAddType         AS ObjectType
	|FROM
	|	&NameOfTableToAdd AS AliasOfTheMetadataTable";
	
	// Additional changes.
	For Each String In AdditionalChangesTable Do
		FullMetadataName = String.FullMetadataName;
		CurrentFilter = String.Filter; // DataCompositionFilter
		
		If MetadataNamesList <> Undefined Then
			If MetadataNamesList.Find(FullMetadataName) = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
		For Each NameOfTableToAdd In TablesToAdd Do
			SetName = "More_" + StrReplace(NameOfTableToAdd, ".", "_");
			Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.DataSource = DataSource;
			Set.AutoFillAvailableFields = True;
			Set.Name = SetName;
			
			ReplacementString = StringFunctionsClientServer.SubstituteParametersToString("Type(%1)", NameOfTableToAdd);
			QueryText = StrReplace(QueryTextTemplate2, "&NameOfTableToAddType", ReplacementString);
			QueryText = StrReplace(QueryText, "&NameOfTableToAdd", NameOfTableToAdd);
			Set.Query = QueryText;
				
			// Adding additional sets to receive data of their filter tabular sections.
			AddingOptions = New Structure;
			AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
			AddingOptions.Insert("CompositionSchema",       CompositionSchema);
			AddTabularSectionCompositionAdditionalSets(CurrentFilter.Items, AddingOptions);
			
		EndDo;
	EndDo;
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If AdditionalChangesTable.Count() > 0 Then 
		
		SettingsRoot = SettingsComposer.Settings;
		
		// Adding additional data filter settings.
		FilterGroup = SettingsRoot.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterGroup.Use = True;
		FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItems1 = FilterGroup.Items;
		
		For Each String In AdditionalChangesTable Do
			FullMetadataName = String.FullMetadataName;
			CurrentFilter = String.Filter; // DataCompositionFilter
			FilterPeriod1 = String.Period; // StandardPeriod
			
			If MetadataNamesList <> Undefined Then
				If MetadataNamesList.Find(FullMetadataName) = Undefined Then
					Continue;
				EndIf;
			EndIf;
			
			If CurrentFilter.Items.Count() = 0
				And (Not String.PeriodSelection Or Not ValueIsFilled(AllDocumentsFilterPeriod)) Then
				Continue;
			EndIf;
			
			TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
			For Each NameOfTableToAdd In TablesToAdd Do
				
				FilterGroup = FilterItems1.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.Use = True;
				
				If String.PeriodSelection Or FullMetadataName = "AllDocuments" Then
					If ValueIsFilled(AllDocumentsFilterPeriod) Then
						StartDate = AllDocumentsFilterPeriod.StartDate;
						EndDate = AllDocumentsFilterPeriod.EndDate;
					Else
						StartDate    = FilterPeriod1.StartDate;
						EndDate = FilterPeriod1.EndDate;
					EndIf;
					If StartDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "ObjectRef.Date", DataCompositionComparisonType.GreaterOrEqual, StartDate);
					EndIf;
					If EndDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "ObjectRef.Date", DataCompositionComparisonType.LessOrEqual, EndDate);
					EndIf;
					
				EndIf;

				// Добавляем элементы отбора с коррекцией полей "Ссылка" -
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				AddTabularSectionCompositionAdditionalFilters(
					FilterGroup.Items, CurrentFilter.Items, AddingOptions);
			EndDo;
		EndDo;
		
	EndIf;
	
	Return New Structure("CompositionSchema,SettingsComposer", 
		CompositionSchema, SettingsComposer);
EndFunction

//  Adds a data set with one Reference field by the table name in the composition schema.
//
//  Parameters:
//      DataCompositionSchema - DataCompositionSchema - the schema that is being added to.
//      
//      
//
Procedure AddSetToCompositionSchema(DataCompositionSchema, TableName, Presentation = Undefined)
	
	QueryTextTemplate2 = "SELECT MDTableAlias.Ref FROM &MetadataTableName AS MDTableAlias";
	
	Set = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = StrReplace(QueryTextTemplate2, "&MetadataTableName", TableName);
	Set.AutoFillAvailableFields = True;
	Set.DataSource = DataCompositionSchema.DataSources.Get(0).Name;
	Set.Name = "Set" + Format(DataCompositionSchema.DataSets.Count()-1, "NZ=; NG=");
	
	Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	Field.Field = "Ref";
	Field.Title = ?(Presentation=Undefined, ObjectPresentation(TableName), Presentation);
	
EndProcedure

//  Adds a single filter item to the list.
//
//  Parameters:
//      FilterItems1  - DataCompositionFilterItem - a reference to the object to check.
//      DataPathField - String - data path of the filter item.
//      Var_ComparisonType    - DataCompositionComparisonType - a type of comparison for item to be added.
//      Value        - Arbitrary - a comparison value for item to be added.
//      Presentation    -String - optional field presentation.
//      
Procedure AddFilterItem(FilterItems1, DataPathField, Var_ComparisonType, Value, Presentation = Undefined)
	
	Item = FilterItems1.Add(Type("DataCompositionFilterItem"));
	Item.Use  = True;
	Item.LeftValue  = New DataCompositionField(DataPathField);
	Item.ComparisonType   = Var_ComparisonType;
	Item.RightValue = Value;
	
	If Presentation<>Undefined Then
		Item.Presentation = Presentation;
	EndIf;
EndProcedure

Procedure AddTabularSectionCompositionAdditionalSets(SourceItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	CompositionSchema       = AddingOptions.CompositionSchema;
	
	SharedSet = CompositionSchema.DataSets.Find("ChangeRecords");
	DataSource = CompositionSchema.DataSources.Get(0).Name; 
	
	ObjectMetadata = Metadata.FindByFullName(NameOfTableToAdd);
	If ObjectMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Invalid metadata name: ""%1"".';"),
				NameOfTableToAdd);
	EndIf;
	
	QueryTextTemplate2 = 
	"SELECT ALLOWED
	|	Ref                    AS ObjectRef,
	|	&NameOfTableToAddType AS ObjectType
	|	,&AllFieldsOfTheTablePartOfTheRequestField 
	|FROM
	|	&VirtualTableSource";
	
	For Each Item In SourceItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			AddTabularSectionCompositionAdditionalSets(Item.Items, AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = Item.LeftValue;
		If StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
		ElsIf StrStartsWith(FieldName, "ObjectRef.") Then
			FieldName = Mid(FieldName, 14);
		Else
			Continue;
		EndIf;
			
		Position = StrFind(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		TabularSectionMetadata = ObjectMetadata.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Filter of header attributes can be retrieved by reference.
			Continue;
		ElsIf TabularSectionMetadata = Undefined Then
			// The tabular section does not match the conditions.
			Continue;
		EndIf;
		
		// The table that matches the conditions.
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// Redirecting to the parent table.
			Continue;
		EndIf;
		
		Alias = StrReplace(NameOfTableToAdd, ".", "") + TableName;
		SetName = "More_" + Alias;
		Set = SharedSet.Items.Find(SetName);
		If Set <> Undefined Then
			Continue;
		EndIf;
		
		Set = SharedSet.Items.Add(Type("DataCompositionSchemaDataSetQuery"));
		Set.AutoFillAvailableFields = True;
		Set.DataSource = DataSource;
		Set.Name = SetName;
		
		AllTabularSectionFields = TabularSectionAttributesForQuery(TabularSectionMetadata, Alias);
		
		ReplacementString = StringFunctionsClientServer.SubstituteParametersToString("TYPE(%1)", NameOfTableToAdd);
		ReplacementRowTable = StringFunctionsClientServer.SubstituteParametersToString("%1.%2", NameOfTableToAdd, TableName);
		QueryText = StrReplace(QueryTextTemplate2, "&NameOfTableToAddType", ReplacementString);
		QueryText = StrReplace(QueryText, ",&AllFieldsOfTheTablePartOfTheRequestField", AllTabularSectionFields.QueryFields);
		QueryText = StrReplace(QueryText, "&VirtualTableSource", ReplacementRowTable);
		Set.Query = QueryText;
			
		For Each FieldName In AllTabularSectionFields.FieldsNames Do
			Field = Set.Fields.Find(FieldName);
			If Field = Undefined Then
				Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
				Field.DataPath = FieldName;
				Field.Field        = FieldName;
			EndIf;
			Field.AttributeUseRestriction.Condition = True;
			Field.AttributeUseRestriction.Field    = True;
			Field.UseRestriction.Condition = True;
			Field.UseRestriction.Field    = True;
		EndDo;
		
	EndDo;
		
EndProcedure

Procedure AddTabularSectionCompositionAdditionalFilters(DestinationItems, SourceItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	MetaObject1 = Metadata.FindByFullName(NameOfTableToAdd);
	
	For Each Item In SourceItems Do
		// The analysis script fragment is similar to the script fragment in the AddTabularSectionCompositionAdditionalSets procedure.
		
		Type = TypeOf(Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			// Copy filter item.
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			
			AddTabularSectionCompositionAdditionalFilters(
				FilterElement.Items, Item.Items, AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = String(Item.LeftValue);
		If FieldName = "Ref" Then
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			FilterElement.LeftValue = New DataCompositionField("ObjectRef");
			Continue;
			
		ElsIf StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
			
		ElsIf StrStartsWith(FieldName, "ObjectRef.") Then
			FieldName = Mid(FieldName, 14);
			
		Else
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			Continue;
			
		EndIf;
			
		Position = StrFind(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		MetaTabularSection = MetaObject1.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// 
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			FilterElement.LeftValue = New DataCompositionField("ObjectRef." + FieldName);
			Continue;
			
		ElsIf MetaTabularSection = Undefined Then
			// 
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			FilterElement.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterElement.Use  = True;
			FilterElement.RightValue = "";
			
			Continue;
		EndIf;
		
		// Setting up filter for a tabular section
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// 
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			FilterElement.LeftValue = New DataCompositionField("ObjectRef." + Mid(DataPath, 8));
			
		ElsIf DataPath <> "LineNumber" And DataPath <> "Ref"
			And MetaTabularSection.Attributes.Find(DataPath) = Undefined Then
			// 
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			FilterElement.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterElement.Use  = True;
			FilterElement.RightValue = "";
			
		Else
			// 
			FilterElement = DestinationItems.Add(Type);
			FillPropertyValues(FilterElement, Item);
			DataPath = StrReplace(NameOfTableToAdd + TableName, ".", "") + DataPath;
			FilterElement.LeftValue = New DataCompositionField(DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use only.
//
// Parameters:
//   MetaTabularSection - MetadataObjectTabularSection - table metadata.
//   Prefix - String - an attribute name prefix.
//
Function TabularSectionAttributesForQuery(Val MetaTabularSection, Val Prefix = "")
	
	QueryFields = ", LineNumber AS " + Prefix + "LineNumber
	              |, Ref      AS " + Prefix + "Ref
	              |";
	
	FieldsNames  = New Array;
	FieldsNames.Add(Prefix + "LineNumber");
	FieldsNames.Add(Prefix + "Ref");
	
	For Each MetaAttribute In MetaTabularSection.Attributes Do
		Name       = MetaAttribute.Name;
		Alias = Prefix + Name;
		QueryFields = QueryFields + ", " + Name + " AS " + Alias + Chars.LF;
		FieldsNames.Add(Alias);
	EndDo;
	
	Return New Structure("QueryFields, FieldsNames", QueryFields, FieldsNames);
EndFunction

Function ParseExchangeFormat(Val ExchangeFormat)
	
	Result = New Structure("BasicFormat, Version");
	
	FormatItems = StrSplit(ExchangeFormat, "/");
	
	If FormatItems.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Noncanonical exchange format name: ""%1"".';"), ExchangeFormat);
	EndIf;
	
	Result.Version = FormatItems[FormatItems.UBound()];
	
	Versions = StrSplit(Result.Version, ".");
	
	If Versions.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Non-canonical presentation of the exchange format v.%1.';"), Result.Version);
	EndIf;
	
	FormatItems.Delete(FormatItems.UBound());
	
	Result.BasicFormat = StrConcat(FormatItems, "/");
	
	Return Result;
EndFunction

Procedure AddListOfObjectsToExport(MetadataArrayFilter)
	CompositionData = InitializeComposer(MetadataArrayFilter);
	
	// Save filter settings.
	FiltersSettings = CompositionData.SettingsComposer.GetSettings();
	
	// 
	CompositionData.SettingsComposer.LoadSettings(
		CompositionData.CompositionSchema.SettingVariants["UserData1"].Settings);
	
	// Restore filters.
	AddDataCompositionFilterValues(CompositionData.SettingsComposer.Settings.Filter.Items, 
		FiltersSettings.Filter.Items);
	
	ComposerSettings = CompositionData.SettingsComposer.GetSettings();

	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, ComposerSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, , , True);
	
	Output = New DataCompositionResultValueCollectionOutputProcessor;
	Output.SetObject(New ValueTable);
	ResultCollection = Output.Output(Processor);
	For Each SpecificationRow In ResultCollection Do
		If ValueIsFilled(SpecificationRow.ObjectRef) Then
			ListExportAddition.Add(SpecificationRow.ObjectRef);
		EndIf;
	EndDo;
EndProcedure

#EndRegion
#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf