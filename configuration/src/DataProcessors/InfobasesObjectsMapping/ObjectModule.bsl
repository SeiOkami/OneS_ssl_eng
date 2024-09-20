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

Var MappingTableField;
Var ObjectMappingStatisticsField;
Var MappingDigestField;
Var UnlimitedLengthStringTypeField;

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Maps objects from the current infobase to objects from the source Infobase.
//  Generates a mapping table to be displayed to the user.
//  Detects the following types of object mapping:
// - objects mapped using references
// - objects mapped using InfobaseObjectsMaps information register data
// - objects mapped using unapproved mapping - mapping items that are not written to the infobase (current changes)
// - unmapped source objects
// - unmapped destination objects (of the current infobase).
//
// Parameters:
//     Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure MapObjects(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// Executing infobase object mapping.
	ExecuteInfobaseObjectMapping(Cancel);
	
EndProcedure

// Maps objects automatically using the mapping fields specified by the user (search fields).
//  Compares mapping fields using strict equality.
//  Generates a table of automatic mapping to be displayed to the user.
//
// Parameters:
//     Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//     MappingFieldsList - ValueList - a value list with fields
//                                                 that will be used to map objects.
// 
Procedure ExecuteAutomaticObjectMapping(Cancel, MappingFieldsList) Export
	
	SetPrivilegedMode(True);
	
	ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList);
	
EndProcedure

// Maps objects automatically using the default search fields.
// The list of mapping fields is equal to the list of used fields.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ExecuteDefaultAutomaticMapping(Cancel) Export
	
	SetPrivilegedMode(True);
	
	// 
	// 
	MappingFieldsList = UsedFieldsList.Copy();
	
	ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList);
	
	// Applying the automatic mapping result.
	ApplyUnapprovedRecordsTable(Cancel);
	
EndProcedure

// Writes unapproved mapping references (current changes) into the Infobase.
// Records are stored in the InfobaseObjectsMaps information register.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ApplyUnapprovedRecordsTable(Cancel) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	Try
		
		For Each TableRow In UnapprovedMappingTable Do
			
			If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
				
				If String(TableRow.SourceUUID.UUID()) = TableRow.DestinationUUID
					Or Not ValueIsFilled(TableRow.DestinationUUID) Then
					Continue;
				EndIf;
				
				RecordStructure = New Structure("Ref, Id");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				RecordStructure.Insert("Ref", TableRow.SourceUUID);
				RecordStructure.Insert("Id", TableRow.DestinationUUID);
				
				InformationRegisters.SynchronizedObjectPublicIDs.AddRecord(RecordStructure);
				
			Else
				
				RecordStructure = New Structure("SourceUUID, DestinationUUID, SourceType, DestinationType");
				
				RecordStructure.Insert("InfobaseNode", InfobaseNode);
				
				FillPropertyValues(RecordStructure, TableRow);
				
				InformationRegisters.InfobaseObjectsMaps.AddRecord(RecordStructure);
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Data exchange';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Cancel = True;
		Return;
	EndTry;
	
	UnapprovedMappingTable.Clear();
	
EndProcedure

// Retrieves object mapping statistic data.
// The MappingDigest() property is initialized.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure GetObjectMappingDigestInfo(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SourceTable2 = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Specifying a blank array of user fields because there is no need to select fields.
	UserFields = New Array;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable2, UserFields, TempTablesManager);
	
	// Getting object mapping digest data.
	GetMappingDigest(TempTablesManager);
	
	TempTablesManager.Close();
	
EndProcedure

// Imports data from an exchange message file to an infobase of the specified object types only.
//
// Parameters:
//      Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//      TablesToImport - Array - array of types to be imported from the exchange message; array element -
//                                    String.
// 
Procedure ExecuteDataImportForInfobase(Cancel, TablesToImport) Export
	
	SetPrivilegedMode(True);
	
	DataImportedSuccessfully = False;
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return;
	EndIf;
	
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	DataExchangeDataProcessor.ExecuteDataImportForInfobase(TablesToImport);
	
	// Deleting tables imported to the infobase from the data processor cache, because they are obsolete.
	For Each Item In TablesToImport Do
		DataExchangeDataProcessor.DataTablesExchangeMessages().Delete(Item);
	EndDo;
	
	If DataExchangeDataProcessor.FlagErrors() Then
		NString = NStr("en = 'Errors occurred while importing the exchange message: %1';");
		NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
		Common.MessageToUser(NString,,,, Cancel);
		Return;
	EndIf;
	
	DataImportedSuccessfully = Not DataExchangeDataProcessor.FlagErrors();
	
EndProcedure

// Data processor constructor
//
Procedure Designer() Export
	
	// 
	TableFieldsList.LoadValues(StrSplit(DestinationTableFields, ",", False));
	
	SearchFieldArray = StrSplit(DestinationTableSearchFields, ",", False);
	
	// Selecting search fields if they are not specified.
	If SearchFieldArray.Count() = 0 Then
		
		// For catalogs.
		AddSearchField(SearchFieldArray, "Description");
		AddSearchField(SearchFieldArray, "Code");
		AddSearchField(SearchFieldArray, "Owner");
		AddSearchField(SearchFieldArray, "Parent");
		
		// For documents and business processes
		AddSearchField(SearchFieldArray, "Date");
		AddSearchField(SearchFieldArray, "Number");
		
		// Popular search fields.
		AddSearchField(SearchFieldArray, "Organization");
		AddSearchField(SearchFieldArray, "TIN");
		AddSearchField(SearchFieldArray, "CRTR");
		
		If SearchFieldArray.Count() = 0 Then
			
			If TableFieldsList.Count() > 0 Then
				
				SearchFieldArray.Add(TableFieldsList[0].Value);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Deleting fields with indexes exceeding the specified limit from the search array.
	CheckMappingFieldCountInArray(SearchFieldArray);
	
	// Selecting search fields in TableFieldsList
	For Each Item In TableFieldsList Do
		
		If SearchFieldArray.Find(Item.Value) <> Undefined Then
			
			Item.Check = True;
			
		EndIf;
		
	EndDo;
	
	FillListWithAdditionalParameters(TableFieldsList);
	
	// Filling UsedFieldsList with selected items of TableFieldsList
	FillListWithSelectedItems(TableFieldsList, UsedFieldsList);
	
	// Generating the sorting table.
	FillSortTable(UsedFieldsList);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Object mapping table.
//
// Returns:
//      ValueTable - 
//
Function MappingTable() Export
	
	If TypeOf(MappingTableField) <> Type("ValueTable") Then
		
		MappingTableField = New ValueTable;
		
	EndIf;
	
	Return MappingTableField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties - mapping digest.

// Retrieves the number of objects of the current data type in the exchange message file.
//
// Returns:
//     Number - 
//
Function ObjectCountInSource() Export
	
	Return MappingDigest().ObjectCountInSource;
	
EndFunction

// Number of objects of the current data type in this infobase.
//
// Returns:
//     Number - 
//
Function ObjectCountInDestination() Export
	
	Return MappingDigest().ObjectCountInDestination;
	
EndFunction

// Number of objects that are mapped for the current data type.
//
// Returns:
//     Number - 
//
Function MappedObjectCount() Export
	
	Return MappingDigest().MappedObjectCount;
	
EndFunction

// Number of objects that are not mapped for the current data type.
//
// Returns:
//     Number - 
//
Function UnmappedObjectsCount() Export
	
	Return MappingDigest().UnmappedObjectsCount;
	
EndFunction

// Retrieves object mapping percentage for the current data type.
//
// Returns:
//     Number - 
//
Function MappedObjectPercentage() Export
	
	Return MappingDigest().MappedObjectPercentage;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving local properties.

Function MappingDigest()
	
	If TypeOf(MappingDigestField) <> Type("Structure") Then
		
		// 
		MappingDigestField = New Structure;
		MappingDigestField.Insert("ObjectCountInSource",       0);
		MappingDigestField.Insert("ObjectCountInDestination",       0);
		MappingDigestField.Insert("MappedObjectCount",   0);
		MappingDigestField.Insert("UnmappedObjectsCount", 0);
		MappingDigestField.Insert("MappedObjectPercentage",       0);
		
	EndIf;
	
	Return MappingDigestField;
	
EndFunction

Function ObjectMappingStatistics()
	
	If TypeOf(ObjectMappingStatisticsField) <> Type("Structure") Then
		
		// 
		ObjectMappingStatisticsField = New Structure;
		ObjectMappingStatisticsField.Insert("MappedByRegisterSourceObjectCount",    0);
		ObjectMappingStatisticsField.Insert("CountOfMappedByRegisterDestinationObjects",    0);
		ObjectMappingStatisticsField.Insert("MappedByUnapprovedRelationsObjectCount", 0);
		
	EndIf;
	
	Return ObjectMappingStatisticsField;
	
EndFunction

Function UnlimitedLengthStringType()
	
	If TypeOf(UnlimitedLengthStringTypeField) <> Type("TypeDescription") Then
		
		UnlimitedLengthStringTypeField = New TypeDescription("String",, New StringQualifiers(0));
		
	EndIf;
	
	Return UnlimitedLengthStringTypeField;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Get map table.

Procedure ExecuteInfobaseObjectMapping(Cancel)
	
	SourceTable2 = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user.
	UserFields = UsedFieldsList.UnloadValues();
	
	// The IsFolder field is always present for hierarchical catalogs.
	If UserFields.Find("IsFolder") = Undefined Then
		AddSearchField(UserFields, "IsFolder");
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable2, UserFields, TempTablesManager);
	
	// Getting object mapping digest data.
	GetMappingDigest(TempTablesManager);
	
	// 
	MappingTableField = ObjectMappingResult(SourceTable2, UserFields, TempTablesManager);
	
	TempTablesManager.Close();
	
	// Sort the table.
	ExecuteTableSortingAtServer();
	
	// Adding the SerialNumber field and filling it.
	AddNumberFieldToMappingTable();
	
EndProcedure

Procedure ExecuteAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList)
	
	SourceTable2 = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// 
	// 
	// 
	// 
	UserFields = New Array;
	
	For Each Item In UsedFieldsList Do
		
		UserFields.Add(Item.Value);
		
	EndDo;
	
	For Each Item In TableFieldsList Do
		
		If UserFields.Find(Item.Value) = Undefined Then
			
			UserFields.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	// The mapping field list is filled according to the order of elements in the UserFields array.
	MappingFieldListNew = New ValueList;
	
	For Each Item In UserFields Do
		
		ListItem = MappingFieldsList.FindByValue(Item);
		
		MappingFieldListNew.Add(Item, ListItem.Presentation, ListItem.Check);
		
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable2, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping.
	AutimaticMappingData(SourceTable2, MappingFieldListNew, UserFields, TempTablesManager);
	
	// 
	AutomaticallyMappedObjectsTable.Load(AutomaticallyMappedObjectsTableGet(TempTablesManager, UserFields));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure ExecuteDefaultAutomaticInfobaseObjectMapping(Cancel, MappingFieldsList)
	
	SourceTable2 = SourceInfobaseData(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting an array of fields that were selected by the user.
	UserFields = UsedFieldsList.UnloadValues();
	
	TempTablesManager = New TempTablesManager;
	
	// Getting object mapping tables (mapped, unmapped).
	ObjectsMappingData(SourceTable2, UserFields, TempTablesManager);
	
	// Getting the table of automatic mapping.
	AutimaticMappingData(SourceTable2, MappingFieldsList, UserFields, TempTablesManager);
	
	// 
	UnapprovedMappingTable.Load(MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager));
	
	TempTablesManager.Close();
	
EndProcedure

Procedure ObjectsMappingData(SourceTable2, UserFields, TempTablesManager)
	
	// 
	//
	// 
	// 
	// 
	//
	// 
	// 
	// 
	//
	// 
	//
	// 
	// 
	//
	//
	
	// 
	//  
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {SourceTable2}
	|SELECT
	|	
	|	&CUSTOMFIELDSSourceTable,
	|	
	|	SourceTableParameter.Ref                  AS Ref,
	|	SourceTableParameter.UUID AS UUID,
	|	&SourceType                                    AS ObjectType
	|INTO SourceTable2
	|FROM
	|	&SourceTableParameter AS SourceTableParameter
	|WHERE
	|	SourceTableParameter.UUID <> """"
	|INDEX BY
	|	Ref,
	|	UUID
	|;
	|";
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSSourceTable,",
		"#CUSTOMFIELDSSourceTable#");
	
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMapsRegisterTable}
			|SELECT
			|	Ref        AS SourceUUID,
			|	Id AS DestinationUUID,
			|	""#SourceType#"" AS DestinationType,
			|	""#ReceiverType#"" AS SourceType
			|INTO InfobaseObjectsMapsRegisterTable
			|FROM
			|	InformationRegister.SynchronizedObjectPublicIDs AS InfobaseObjectsMaps
			|WHERE
			|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
			|	AND InfobaseObjectsMaps.Ref = &EmulationOfTheReplacementString
			|
			|INDEX BY
			|	DestinationUUID
			|;
			|";
			
			QueryText = StrReplace(QueryText,
				"InfobaseObjectsMaps.Ref = &EmulationOfTheReplacementString",
				"VALUETYPE(InfobaseObjectsMaps.Ref) = TYPE(#DestinationTable1#)");
			
	Else
		
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {InfobaseObjectsMapsRegisterTable}
			|SELECT
			|	SourceUUID,
			|	DestinationUUID,
			|	DestinationType,
			|	SourceType
			|INTO InfobaseObjectsMapsRegisterTable
			|FROM
			|	InformationRegister.InfobaseObjectsMaps AS InfobaseObjectsMaps
			|WHERE
			|	  InfobaseObjectsMaps.InfobaseNode = &InfobaseNode
			|	AND InfobaseObjectsMaps.DestinationType = &SourceType
			|	AND InfobaseObjectsMaps.SourceType = &DestinationType
			|INDEX BY
			|	DestinationUUID,
			|	DestinationType,
			|	SourceType
			|;
			|";
			
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {UnapprovedMappingTable}
		|SELECT
		|	
		|	SourceUUID,
		|	DestinationUUID,
		|	DestinationType,
		|	SourceType
		|	
		|INTO UnapprovedMappingTable
		|FROM
		|	&UnapprovedMappingTable AS UnapprovedMappingTable
		|INDEX BY
		|	DestinationUUID,
		|	DestinationType
		|;
		|";
		
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	0 AS MappingStatus,               // сопоставленные объекты (0)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedSourceObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery,
			|		
			|		ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable1.Ref) AS Ref,
			|		
			|		&SourceTableIsFolder                      AS ThisIsTheSourceGroup,
			|		&InfobaseObjectsMapsIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable1.Ref)                  AS DestinationUUID,
			|		ISNULL(InfobaseObjectsMaps.DestinationUUID, SourceTable2.UUID) AS SourceUUID,
			|		ISNULL(InfobaseObjectsMaps.DestinationType, ""#SourceType#"")                                           AS SourceType,
			|		ISNULL(InfobaseObjectsMaps.SourceType, ""#ReceiverType#"")                                           AS DestinationType
			|	FROM
			|		SourceTable2 AS SourceTable2
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.DestinationUUID = SourceTable2.UUID
			|		AND InfobaseObjectsMaps.SourceUUID = &InfobaseObjectsMaps
			|	LEFT JOIN
			|		Catalog.DataExchangeScenarios AS DestinationTable1
			|	ON
			|		  SourceTable2.Ref = DestinationTable1.Ref
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		OR NOT DestinationTable1.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedDestinationObjectsTableByRegister}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	0 AS MappingStatus,               // сопоставленные объекты (0)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedDestinationObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery,
			|		
			|		DestinationTable1.Ref AS Ref,
			|	
			|		&DestinationTableIsFolder AS ThisIsTheSourceGroup,
			|		&DestinationTableIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUUID,
			|		InfobaseObjectsMaps.DestinationUUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		Catalog.DataExchangeScenarios AS DestinationTable1
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.SourceUUID = DestinationTable1.Ref
			|	LEFT JOIN
			|		MappedSourceObjectsTableByRegister AS MappedSourceObjectsTableByRegister
			|	ON
			|		MappedSourceObjectsTableByRegister.Ref = DestinationTable1.Ref
			|	
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		AND MappedSourceObjectsTableByRegister.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedMapping}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	3 AS MappingStatus,               // неутвержденные связи (3)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedObjectsTableByUnapprovedMapping
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery,
			|		
			|		UnapprovedMappingTable.SourceUUID AS Ref,
			|	
			|		&SourceTableIsFolder            AS ThisIsTheSourceGroup,
			|		&UnapprovedMappingTableIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		UnapprovedMappingTable.SourceUUID AS DestinationUUID,
			|		UnapprovedMappingTable.DestinationUUID AS SourceUUID,
			|		UnapprovedMappingTable.DestinationType AS SourceType,
			|		UnapprovedMappingTable.SourceType AS DestinationType
			|	FROM
			|		SourceTable2 AS SourceTable2
			|	LEFT JOIN
			|		UnapprovedMappingTable AS UnapprovedMappingTable
			|	ON
			|		  UnapprovedMappingTable.DestinationUUID = SourceTable2.UUID
			|		AND UnapprovedMappingTable.SourceUUID = &DestinationTable1
			|		
			|	WHERE
			|		NOT UnapprovedMappingTable.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|";
			
		QueryText = StrReplace(QueryText,
			"&CUSTOMFIELDSMappingTable,",
			"#CUSTOMFIELDSMappingTable#");
		
		QueryText = StrReplace(QueryText,
			"&ORDERFIELDDestination,",
			"#ORDERFIELDDestination#");
		
		QueryText = StrReplace(QueryText,
			"&CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery,",
			"#CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery#");
			
		QueryText = StrReplace(QueryText,
			"&SourceTableIsFolder",
			"#SourceTableIsFolder#");
		
		QueryText = StrReplace(QueryText,
			"&InfobaseObjectsMapsIsFolder",
			"#InfobaseObjectsMapsIsFolder#");
		
		QueryText = StrReplace(QueryText,
			"AND InfobaseObjectsMaps.SourceUUID = &InfobaseObjectsMaps",
			"AND VALUETYPE(InfobaseObjectsMaps.SourceUUID) = TYPE(#DestinationTable1#)");
		
		QueryText = StrReplace(QueryText,
			"Catalog.DataExchangeScenarios AS DestinationTable1",
			"#DestinationTable1# AS DestinationTable1");
			
		QueryText = StrReplace(QueryText,
			"&CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery,",
			"#CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery#");
		
		QueryText = StrReplace(QueryText,
			"&CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery,",
			"#CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery#");
		
		QueryText = StrReplace(QueryText,
			"&DestinationTableIsFolder",
			"#DestinationTableIsFolder#");
			
		QueryText = StrReplace(QueryText,
			"&CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery,",
			"#CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery#");
			
		QueryText = StrReplace(QueryText,
			"&UnapprovedMappingTableIsFolder",
			"#UnapprovedMappingTableIsFolder#");
		
		QueryText = StrReplace(QueryText,
			"UnapprovedMappingTable.SourceUUID = &DestinationTable1",
			"VALUETYPE(UnapprovedMappingTable.SourceUUID) = TYPE(#DestinationTable1#)");
		
	Else
		
		QueryText = QueryText + "
			|//////////////////////////////////////////////////////////////////////////////// {MappedSourceObjectsTableByRegister}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	0 AS MappingStatus,               // сопоставленные объекты (0)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedSourceObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery,
			|		
			|		InfobaseObjectsMaps.SourceUUID AS Ref,
			|		
			|		&SourceTableIsFolder                      AS ThisIsTheSourceGroup,
			|		&InfobaseObjectsMapsIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUUID,
			|		InfobaseObjectsMaps.DestinationUUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		SourceTable2 AS SourceTable2
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.DestinationUUID = SourceTable2.UUID
			|		AND InfobaseObjectsMaps.DestinationType                     = SourceTable2.ObjectType
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|//////////////////////////////////////////////////////////////////////////////// {MappedDestinationObjectsTableByRegister}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	0 AS MappingStatus,               // сопоставленные объекты (0)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedDestinationObjectsTableByRegister
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery,
			|		
			|		DestinationTable1.Ref AS Ref,
			|	
			|		&DestinationTableIsFolder AS ThisIsTheSourceGroup,
			|		&DestinationTableIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		InfobaseObjectsMaps.SourceUUID AS DestinationUUID,
			|		InfobaseObjectsMaps.DestinationUUID AS SourceUUID,
			|		InfobaseObjectsMaps.DestinationType                     AS SourceType,
			|		InfobaseObjectsMaps.SourceType                     AS DestinationType
			|	FROM
			|		Catalog.DataExchangeScenarios AS DestinationTable1
			|	LEFT JOIN
			|		InfobaseObjectsMapsRegisterTable AS InfobaseObjectsMaps
			|	ON
			|		  InfobaseObjectsMaps.SourceUUID = DestinationTable1.Ref
			|		AND InfobaseObjectsMaps.SourceType                     = &DestinationType
			|	LEFT JOIN
			|		MappedSourceObjectsTableByRegister AS MappedSourceObjectsTableByRegister
			|	ON
			|		MappedSourceObjectsTableByRegister.Ref = DestinationTable1.Ref
			|	
			|	WHERE
			|		NOT InfobaseObjectsMaps.SourceUUID IS NULL
			|		AND MappedSourceObjectsTableByRegister.Ref IS NULL
			|	) AS NestedQuery
			|;
			|
			|//////////////////////////////////////////////////////////////////////////////// {MappedObjectsTableByUnapprovedMapping}
			|SELECT
			|	
			|	&CUSTOMFIELDSMappingTable,
			|	
			|	&ORDERFIELDDestination,
			|	
			|	Ref,
			|	3 AS MappingStatus,               // неутвержденные связи (3)
			|	0 AS MappingStatusAdditional, // сопоставленные объекты (0)
			|	
			|	ThisIsTheSourceGroup,
			|	ThisIsTheReceiverGroup,
			|	
			|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|	SourceUUID,
			|	DestinationUUID,
			|	SourceType,
			|	DestinationType
			|INTO MappedObjectsTableByUnapprovedMapping
			|FROM
			|	(SELECT
			|	
			|		&CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery,
			|		
			|		UnapprovedMappingTable.SourceUUID AS Ref,
			|	
			|		&SourceTableIsFolder            AS ThisIsTheSourceGroup,
			|		&UnapprovedMappingTableIsFolder AS ThisIsTheReceiverGroup,
			|	
			|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
			|		UnapprovedMappingTable.SourceUUID AS DestinationUUID,
			|		UnapprovedMappingTable.DestinationUUID AS SourceUUID,
			|		UnapprovedMappingTable.DestinationType AS SourceType,
			|		UnapprovedMappingTable.SourceType AS DestinationType
			|	FROM
			|		SourceTable2 AS SourceTable2
			|	LEFT JOIN
			|		UnapprovedMappingTable AS UnapprovedMappingTable
			|	ON
			|		  UnapprovedMappingTable.DestinationUUID = SourceTable2.UUID
			|		AND UnapprovedMappingTable.DestinationType                     = SourceTable2.ObjectType
			|		
			|	WHERE
			|		NOT UnapprovedMappingTable.SourceUUID IS NULL
			|	) AS NestedQuery
			|;
			|";
			
			QueryText = StrReplace(QueryText,
				"&CUSTOMFIELDSMappingTable,",
				"#CUSTOMFIELDSMappingTable#");
			
			QueryText = StrReplace(QueryText,
				"&ORDERFIELDDestination,",
				"#ORDERFIELDDestination#");
			
			QueryText = StrReplace(QueryText,
				"&CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery,",
				"#CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery#");
			
			QueryText = StrReplace(QueryText,
				"&SourceTableIsFolder",
				"#SourceTableIsFolder#");
			
			QueryText = StrReplace(QueryText,
				"&InfobaseObjectsMapsIsFolder",
				"#InfobaseObjectsMapsIsFolder#");
			
			QueryText = StrReplace(QueryText,
				"&CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery,",
				"#CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery#");
			
			QueryText = StrReplace(QueryText,
				"&DestinationTableIsFolder",
				"#DestinationTableIsFolder#");
			
			QueryText = StrReplace(QueryText,
				"Catalog.DataExchangeScenarios AS DestinationTable1",
				"#DestinationTable1# AS DestinationTable1");
			
			QueryText = StrReplace(QueryText,
				"&CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery,",
				"#CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery#");
			
			QueryText = StrReplace(QueryText,
				"&UnapprovedMappingTableIsFolder",
				"#UnapprovedMappingTableIsFolder#");
			
	EndIf;
	
	QueryText = QueryText + "
		|//////////////////////////////////////////////////////////////////////////////// {TableOfMappedObjects}
		|SELECT
		|	
		|	&CUSTOMFIELDSMappingTable,
		|	
		|	&SortingFields,
		|	
		|	Ref,
		|	MappingStatus,
		|	MappingStatusAdditional,
		|	
		|	// {ИНДЕКС КАРТИНКИ}
		|	CASE WHEN ThisIsTheSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsTheReceiverGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheReceiverGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|	SourceUUID,
		|	DestinationUUID,
		|	SourceType,
		|	DestinationType
		|INTO TableOfMappedObjects
		|FROM
		|	(
		|	SELECT
		|	
		|		&CUSTOMFIELDSMappingTable,
		|	
		|		&SortingFields,
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsTheSourceGroup,
		|		ThisIsTheReceiverGroup,
		|	
		|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|		SourceUUID,
		|		DestinationUUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedSourceObjectsTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		&CUSTOMFIELDSMappingTable,
		|	
		|		&SortingFields,
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsTheSourceGroup,
		|		ThisIsTheReceiverGroup,
		|	
		|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|		SourceUUID,
		|		DestinationUUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedDestinationObjectsTableByRegister
		|	
		|	UNION ALL
		|	
		|	SELECT
		|	
		|		&CUSTOMFIELDSMappingTable,
		|	
		|		&SortingFields,
		|	
		|		Ref,
		|		MappingStatus,
		|		MappingStatusAdditional,
		|	
		|		ThisIsTheSourceGroup,
		|		ThisIsTheReceiverGroup,
		|	
		|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|		SourceUUID,
		|		DestinationUUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		MappedObjectsTableByUnapprovedMapping
		|	
		|	) AS NestedQuery
		|	
		|INDEX BY
		|	Ref
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	&CUSTOMFIELDSMappingTable,
		|	
		|	&ORDERFIELDSource,
		|	
		|	-1 AS MappingStatus,               // несопоставленные объекты источника (-1)
		|	 1 AS MappingStatusAdditional, // несопоставленные объекты (1)
		|	
		|	// {ИНДЕКС КАРТИНКИ}
		|	CASE WHEN ThisIsTheSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsTheReceiverGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheReceiverGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|	SourceUUID,
		|	DestinationUUID,
		|	SourceType,
		|	DestinationType
		|INTO UnmappedSourceObjectsTable
		|FROM
		|	(SELECT
		|		COUNT(*),
		|		ThisIsTheSourceGroup,
		|		ThisIsTheReceiverGroup,
		|		Ref,
		|		&CUSTOMFIELDSMappingTable,
		|		DestinationUUID,
		|		SourceUUID,
		|		SourceType,
		|		DestinationType
		|	FROM
		|		(SELECT
		|	
		|			&SourceTableIsFolder AS ThisIsTheSourceGroup,
		|			NULL                        AS ThisIsTheReceiverGroup,
		|		
		|			SourceTable2.Ref AS Ref,
		|		
		|			&CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery,
		|		
		|			// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|			NULL                                     AS DestinationUUID,
		|			SourceTable2.UUID AS SourceUUID,
		|			&SourceType                            AS SourceType,
		|			&DestinationType                            AS DestinationType
		|		FROM
		|			SourceTable2 AS SourceTable2
		|		LEFT JOIN
		|			TableOfMappedObjects AS TableOfMappedObjects
		|		ON
		|			SourceTable2.Ref = TableOfMappedObjects.Ref
		|		WHERE
		|			TableOfMappedObjects.SourceUUID IS NULL
		|
		|		UNION ALL
		|
		|		SELECT
		|			&SourceTableIsFolder,
		|			NULL,
		|		
		|			SourceTable2.Ref,
		|		
		|			&CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery1,
		|		
		|			// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|			NULL,
		|			SourceTable2.UUID,
		|			&SourceType,
		|			&DestinationType
		|		FROM
		|			SourceTable2 AS SourceTable2
		|		LEFT JOIN
		|			TableOfMappedObjects AS TableOfMappedObjects
		|		ON
		|			SourceTable2.UUID = TableOfMappedObjects.SourceUUID
		|		WHERE
		|			TableOfMappedObjects.Ref IS NULL
		|		) AS SubqueryPreview
		|	GROUP BY
		|		ThisIsTheSourceGroup,
		|		ThisIsTheReceiverGroup,
		|		Ref,
		|		&CUSTOMFIELDSMappingTable,
		|		DestinationUUID,
		|		SourceUUID,
		|		SourceType,
		|		DestinationType
		|	HAVING COUNT(*) > 1) AS NestedQuery
		|;
		|
		|//////////////////////////////////////////////////////////////////////////////// {UnmappedDestinationObjectsTable}
		|SELECT
		|	
		|	Ref,
		|	
		|	&CUSTOMFIELDSMappingTable,
		|	
		|	&ORDERFIELDDestination,
		|	
		|	1 AS MappingStatus,               // несопоставленные объекты приемника (1)
		|	1 AS MappingStatusAdditional, // несопоставленные объекты (1)
		|	
		|	// {ИНДЕКС КАРТИНКИ}
		|	CASE WHEN ThisIsTheSourceGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheSourceGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS SourcePictureIndex,
		|	
		|	CASE WHEN ThisIsTheReceiverGroup IS NULL
		|	THEN 0
		|	ELSE
		|		CASE WHEN ThisIsTheReceiverGroup = TRUE
		|		THEN 1
		|		ELSE 2
		|		END
		|	END AS DestinationPictureIndex,
		|	
		|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|	SourceUUID,
		|	DestinationUUID,
		|	SourceType,
		|	DestinationType
		|INTO UnmappedDestinationObjectsTable
		|FROM
		|	(SELECT
		|	
		|		DestinationTable1.Ref AS Ref,
		|	
		|		&CUSTOMFIELDSUnmappedDestinationObjectsTableNestedQuery,
		|		
		|		NULL                        AS ThisIsTheSourceGroup,
		|		&DestinationTableIsFolder AS ThisIsTheReceiverGroup,
		|		
		|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
		|		DestinationTable1.Ref       AS DestinationUUID,
		|		UNDEFINED                  AS SourceUUID,
		|		UNDEFINED                  AS SourceType,
		|		&DestinationType                 AS DestinationType
		|	FROM
		|		Catalog.DataExchangeScenarios AS DestinationTable1
		|	LEFT JOIN
		|		TableOfMappedObjects AS TableOfMappedObjects
		|	ON
		|		DestinationTable1.Ref = TableOfMappedObjects.Ref
		|	WHERE
		|		TableOfMappedObjects.DestinationUUID IS NULL
		|	) AS NestedQuery
		|;
		|
		|";
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSMappingTable,",
		"#CUSTOMFIELDSMappingTable#");
	
	QueryText = StrReplace(QueryText,
		"&SortingFields,",
		"#SortingFields#");
	
	QueryText = StrReplace(QueryText,
		"&ORDERFIELDSource,",
		"#ORDERFIELDSource#");
	
	QueryText = StrReplace(QueryText,
		"&SourceTableIsFolder",
		"#SourceTableIsFolder#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery,",
		"#CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery1,",
		"#CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery1#");
	
	QueryText = StrReplace(QueryText,
		"&ORDERFIELDDestination,",
		"#ORDERFIELDDestination#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSUnmappedDestinationObjectsTableNestedQuery,",
		"#CUSTOMFIELDSUnmappedDestinationObjectsTableNestedQuery#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSMappingTable,",
		"#CUSTOMFIELDSMappingTable#");
	
	QueryText = StrReplace(QueryText,
		"&DestinationTableIsFolder",
		"#DestinationTableIsFolder#");
	
	QueryText = StrReplace(QueryText,
		"Catalog.DataExchangeScenarios AS DestinationTable1",
		"#DestinationTable1# AS DestinationTable1");
	
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSSourceTable#", GetUserFields(UserFields, "SourceTableParameter.# AS #,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappedObjectsTableByRefNestedQuery#", GetUserFields(UserFields, "DestinationTable1.# AS DestinationFieldNN, SourceTable2.# AS SourceFieldNN,"));
	
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery#", GetUserFields(UserFields, "CAST(ISNULL(InfobaseObjectsMaps.SourceUUID, DestinationTable1.Ref) AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable2.# AS SourceFieldNN,"));
	Else
		QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappedSourceObjectsTableByRegisterNestedQuery#", GetUserFields(UserFields, "CAST(InfobaseObjectsMaps.SourceUUID AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable2.# AS SourceFieldNN,"));
	EndIf;
	
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappedDestinationObjectsTableByRegisterNestedQuery#", GetUserFields(UserFields, "DestinationTable1.# AS DestinationFieldNN, NULL AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappedObjectsTableByUnapprovedMappingNestedQuery#", GetUserFields(UserFields, "CAST(UnapprovedMappingTable.SourceUUID AS [DestinationTableName]).# AS DestinationFieldNN, SourceTable2.# AS SourceFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery#", GetUserFields(UserFields, "SourceTable2.# AS SourceFieldNN, NULL AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSUnmappedSourceObjectsTableNestedQuery1#", GetUserFields(UserFields, "SourceTable2.#, NULL,"));

	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSUnmappedDestinationObjectsTableNestedQuery#", GetUserFields(UserFields, "NULL AS SourceFieldNN, DestinationTable1.Ref.# AS DestinationFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#ORDERFIELDSource#", GetUserFields(UserFields, "SourceFieldNN AS SortFieldNN,"));
	QueryText = StrReplace(QueryText, "#ORDERFIELDDestination#", GetUserFields(UserFields, "DestinationFieldNN AS SortFieldNN,"));
	
	QueryText = StrReplace(QueryText, "#SortingFields#", GetUserFields(UserFields, "SortFieldNN,"));
	QueryText = StrReplace(QueryText, "#DestinationTable1#", DestinationTableName);
	
	If UserFields.Find("IsFolder") <> Undefined Then
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "SourceTable2.IsFolder");
		QueryText = StrReplace(QueryText, "#DestinationTableIsFolder#",            "DestinationTable1.IsFolder");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "CAST(UnapprovedMappingTable.SourceUUID AS [DestinationTableName]).IsFolder");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMapsIsFolder#", "CAST(InfobaseObjectsMaps.SourceUUID AS [DestinationTableName]).IsFolder");
		
	Else
		
		QueryText = StrReplace(QueryText, "#SourceTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#DestinationTableIsFolder#",            "NULL");
		QueryText = StrReplace(QueryText, "#UnapprovedMappingTableIsFolder#", "NULL");
		QueryText = StrReplace(QueryText, "#InfobaseObjectsMapsIsFolder#", "NULL");
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[DestinationTableName]", DestinationTableName);
	
	Query = New Query;
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("SourceTableParameter",    SourceTable2);
	Query.SetParameter("UnapprovedMappingTable", UnapprovedMappingTable.Unload());
	Query.SetParameter("SourceType",                SourceTypeString);
	Query.SetParameter("DestinationType",                DestinationTypeString);
	Query.SetParameter("InfobaseNode",      InfobaseNode);
	
	Query.Execute();

EndProcedure

Procedure AutimaticMappingData(SourceTable2, MappingFieldsList, UserFields, TempTablesManager)
	
	MarkedListItemArray = CommonClientServer.MarkedItems(MappingFieldsList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		AutimaticMappingDataByGUID(UserFields, TempTablesManager);
		
	Else
		
		AutimaticMappingDataByGUIDPlusBySearchFields(SourceTable2, MappingFieldsList, UserFields, TempTablesManager);
		
	EndIf;
	
EndProcedure

Procedure AutimaticMappingDataByGUID(UserFields, TempTablesManager)
	
	// 
	//
	// 
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	Ref,
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTable
	|FROM
	|	(SELECT
	|		
	|		UnmappedDestinationObjectsTable.Ref AS Ref,
	|		
	|		UnmappedDestinationObjectsTable.DestinationPictureIndex,
	|		UnmappedSourceObjectsTable.SourcePictureIndex,
	|		
	|		&CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery,
	|		
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		UnmappedSourceObjectsTable.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTable.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTable.DestinationUUID AS DestinationUUID,
	|		UnmappedDestinationObjectsTable.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTable AS UnmappedDestinationObjectsTable
	|	LEFT JOIN
	|		UnmappedSourceObjectsTable AS UnmappedSourceObjectsTable
	|	ON
	|		UnmappedDestinationObjectsTable.Ref = UnmappedSourceObjectsTable.Ref
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSMappingTable,",
		"#CUSTOMFIELDSMappingTable#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery,",
		"#CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery#");
	
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure AutimaticMappingDataByGUIDPlusBySearchFields(SourceTable2, MappingFieldsList, UserFields, TempTablesManager)
	
	// 
	//
	// 
	// 
	// 
	// 
	// 
	//
	// 
	// 
	// 
	
	// 
	//
	// 
	// 
	//
	// 
	
	QueryText = "
	|//////////////////////////////////////////////////////////////////////////////// {ТаблицаАвтоматическиСопоставленныхОбъектовПоGUID}
	|SELECT
	|	
	|	Ref,
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|INTO TableOfAutomaticallyMappedObjectsByGUID
	|FROM
	|	(SELECT
	|		
	|		UnmappedDestinationObjectsTable.Ref AS Ref,
	|		
	|		&CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery,
	|		
	|		UnmappedDestinationObjectsTable.DestinationPictureIndex,
	|		UnmappedSourceObjectsTable.SourcePictureIndex,
	|		
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		UnmappedSourceObjectsTable.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTable.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTable.DestinationUUID AS DestinationUUID,
	|		UnmappedDestinationObjectsTable.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTable AS UnmappedDestinationObjectsTable
	|	LEFT JOIN
	|		UnmappedSourceObjectsTable AS UnmappedSourceObjectsTable
	|	ON
	|		UnmappedDestinationObjectsTable.Ref = UnmappedSourceObjectsTable.Ref
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTable.Ref IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedDestinationObjectsTableByFields}
	|SELECT
	|	
	|	&CUSTOMFIELDSUnmappedObjectsTable,
	|	
	|	UnmappedObjectsTable.DestinationPictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	UnmappedObjectsTable.SourceUUID,
	|	UnmappedObjectsTable.DestinationUUID,
	|	UnmappedObjectsTable.SourceType,
	|	UnmappedObjectsTable.DestinationType
	|INTO UnmappedDestinationObjectsTableByFields
	|FROM
	|	UnmappedDestinationObjectsTable AS UnmappedObjectsTable
	|	LEFT JOIN
	|		TableOfAutomaticallyMappedObjectsByGUID AS TableOfAutomaticallyMappedObjectsByGUID
	|	ON
	|		UnmappedObjectsTable.Ref = TableOfAutomaticallyMappedObjectsByGUID.Ref
	|WHERE
	|	TableOfAutomaticallyMappedObjectsByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {UnmappedSourceObjectsTableByFields}
	|SELECT
	|	
	|	&CUSTOMFIELDSUnmappedObjectsTable,
	|	
	|	UnmappedObjectsTable.SourcePictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	UnmappedObjectsTable.SourceUUID,
	|	UnmappedObjectsTable.DestinationUUID,
	|	UnmappedObjectsTable.SourceType,
	|	UnmappedObjectsTable.DestinationType
	|INTO UnmappedSourceObjectsTableByFields
	|FROM
	|	UnmappedSourceObjectsTable AS UnmappedObjectsTable
	|	LEFT JOIN
	|		TableOfAutomaticallyMappedObjectsByGUID AS TableOfAutomaticallyMappedObjectsByGUID
	|	ON
	|		UnmappedObjectsTable.Ref = TableOfAutomaticallyMappedObjectsByGUID.Ref
	|WHERE
	|	TableOfAutomaticallyMappedObjectsByGUID.Ref IS NULL
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {ТаблицаАвтоматическиСопоставленныхОбъектовПолная} // содержит повторяющиеся записи для источника и приемника
	|SELECT
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|		
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|INTO TheTableOfAutomaticallyMappedObjectsIsComplete
	|FROM
	|	(SELECT
	|		
	|		&CUSTOMFIELDSAutomaticallyMappedObjectsTableFullNestedQuery,
	|		
	|		UnmappedDestinationObjectsTableByFields.DestinationPictureIndex,
	|		UnmappedSourceObjectsTableByFields.SourcePictureIndex,
	|		
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		UnmappedSourceObjectsTableByFields.SourceUUID AS SourceUUID,
	|		UnmappedSourceObjectsTableByFields.SourceType                     AS SourceType,
	|		UnmappedDestinationObjectsTableByFields.DestinationUUID AS DestinationUUID,
	|		UnmappedDestinationObjectsTableByFields.DestinationType                     AS DestinationType
	|	FROM
	|		UnmappedDestinationObjectsTableByFields AS UnmappedDestinationObjectsTableByFields
	|	LEFT JOIN
	|		UnmappedSourceObjectsTableByFields AS UnmappedSourceObjectsTableByFields
	|	ON
	|		&MAPPINGBYFIELDSCONDITION
	|	
	|	WHERE
	|		NOT UnmappedSourceObjectsTableByFields.SourceUUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {TableOfIncorrectlyMappedSourceObjects}
	|SELECT
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID
	|	
	|INTO TableOfIncorrectlyMappedSourceObjects
	|FROM
	|	(SELECT
	|	
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		SourceUUID
	|	FROM
	|		TheTableOfAutomaticallyMappedObjectsIsComplete
	|	GROUP BY
	|		SourceUUID
	|	HAVING
	|		COUNT(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|
	|//////////////////////////////////////////////////////////////////////////////// {TableOfIncorrectlyMappedReceiverObjects}
	|SELECT
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	DestinationUUID
	|	
	|INTO TableOfIncorrectlyMappedReceiverObjects
	|FROM
	|	(SELECT
	|	
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		DestinationUUID
	|	FROM
	|		TheTableOfAutomaticallyMappedObjectsIsComplete
	|	GROUP BY
	|		DestinationUUID
	|	HAVING
	|		COUNT(1) > 1
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {TableIsAutomaticallyMappedToObjectsInTheFields}
	|SELECT
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|INTO TableIsAutomaticallyMappedToObjectsInTheFields
	|FROM
	|	(SELECT
	|	
	|		&CUSTOMFIELDSMappingTable,
	|	
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.DestinationPictureIndex,
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.SourcePictureIndex,
	|	
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.SourceUUID,
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.DestinationUUID,
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.SourceType,
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.DestinationType
	|	FROM
	|		TheTableOfAutomaticallyMappedObjectsIsComplete AS TheTableOfAutomaticallyMappedObjectsIsComplete
	|	
	|	LEFT JOIN
	|		TableOfIncorrectlyMappedSourceObjects AS TableOfIncorrectlyMappedSourceObjects
	|	ON
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.SourceUUID = TableOfIncorrectlyMappedSourceObjects.SourceUUID
	|	
	|	LEFT JOIN
	|		TableOfIncorrectlyMappedReceiverObjects AS TableOfIncorrectlyMappedReceiverObjects
	|	ON
	|		TheTableOfAutomaticallyMappedObjectsIsComplete.DestinationUUID = TableOfIncorrectlyMappedReceiverObjects.DestinationUUID
	|	
	|	WHERE
	|		  TableOfIncorrectlyMappedSourceObjects.SourceUUID IS NULL
	|		AND TableOfIncorrectlyMappedReceiverObjects.DestinationUUID IS NULL
	|	
	|	) AS NestedQuery
	|;
	|
	|//////////////////////////////////////////////////////////////////////////////// {AutomaticallyMappedObjectsTable}
	|SELECT
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|INTO AutomaticallyMappedObjectsTable
	|FROM
	|	(
	|	SELECT
	|
	|		&CUSTOMFIELDSMappingTable,
	|		
	|		DestinationPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		SourceUUID,
	|		DestinationUUID,
	|		SourceType,
	|		DestinationType
	|	FROM
	|		TableIsAutomaticallyMappedToObjectsInTheFields
	|
	|	UNION ALL
	|
	|	SELECT
	|
	|		&CUSTOMFIELDSMappingTable,
	|		
	|		DestinationPictureIndex,
	|		SourcePictureIndex,
	|		
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		SourceUUID,
	|		DestinationUUID,
	|		SourceType,
	|		DestinationType
	|	FROM
	|		TableOfAutomaticallyMappedObjectsByGUID
	|
	|	) AS NestedQuery
	|;
	|";
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSMappingTable,",
		"#CUSTOMFIELDSMappingTable#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery,",
		"#CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSUnmappedObjectsTable,",
		"#CUSTOMFIELDSUnmappedObjectsTable#");
	
	QueryText = StrReplace(QueryText,
		"&CUSTOMFIELDSAutomaticallyMappedObjectsTableFullNestedQuery,",
		"#CUSTOMFIELDSAutomaticallyMappedObjectsTableFullNestedQuery#");
	
	QueryText = StrReplace(QueryText,
		"&MAPPINGBYFIELDSCONDITION",
		"#MAPPINGBYFIELDSCONDITION#");
	
	QueryText = StrReplace(QueryText, "#MAPPINGBYFIELDSCONDITION#", GetMappingByFieldsCondition(MappingFieldsList));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSMappingTable#", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSUnmappedObjectsTable#", GetUserFields(UserFields, "UnmappedObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSAutomaticallyMappedObjectsTableFullNestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTableByFields.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTableByFields.DestinationFieldNN AS DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "#CUSTOMFIELDSAutomaticallyMappedObjectsTableByGUIDNestedQuery#", GetUserFields(UserFields, "UnmappedSourceObjectsTable.SourceFieldNN AS SourceFieldNN, UnmappedDestinationObjectsTable.DestinationFieldNN AS DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Execute();
	
EndProcedure

Procedure ExecuteTableSortingAtServer()
	
	SortFields = GetSortingFieldsAtServer();
	
	If Not IsBlankString(SortFields) Then
		
		MappingTable().Sort(SortFields);
		
	EndIf;
	
EndProcedure

Procedure GetMappingDigest(TempTablesManager)
	
	// Getting information on the number of mapped objects.
	GetMappedObjectCount(TempTablesManager);
	
	MappingDigest().ObjectCountInSource = DataExchangeServer.TempInfobaseTableRecordCount("SourceTable2", TempTablesManager);
	MappingDigest().ObjectCountInDestination = DataExchangeServer.RecordsCountInInfobaseTable(DestinationTableName);
	
	MappedSourceObjectCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
	//
	MappedDestinationObjectsCount =   ObjectMappingStatistics().MappedByRegisterSourceObjectCount
												+ ObjectMappingStatistics().CountOfMappedByRegisterDestinationObjects
												+ ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount;
	
	UnmappedSourceObjectCount = Max(0, MappingDigest().ObjectCountInSource - MappedSourceObjectCount);
	UnmappedDestinationObjectsCount = Max(0, MappingDigest().ObjectCountInDestination - MappedDestinationObjectsCount);
	
	SourceObjectMappingPercent = ?(MappingDigest().ObjectCountInSource = 0, 0, 100 - Int(100 * UnmappedSourceObjectCount / MappingDigest().ObjectCountInSource));
	DestinationObjectsMappingPercent = ?(MappingDigest().ObjectCountInDestination = 0, 0, 100 - Int(100 * UnmappedDestinationObjectsCount / MappingDigest().ObjectCountInDestination));
	
	MappingDigest().MappedObjectPercentage = Max(SourceObjectMappingPercent, DestinationObjectsMappingPercent);
	
	MappingDigest().UnmappedObjectsCount = Min(UnmappedSourceObjectCount, UnmappedDestinationObjectsCount);
	
	MappingDigest().MappedObjectCount = MappedDestinationObjectsCount;
	
EndProcedure

Procedure GetMappedObjectCount(TempTablesManager)
	
	// Getting the number of mapped objects.
	QueryText = "
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	MappedSourceObjectsTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	MappedDestinationObjectsTableByRegister
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	MappedObjectsTableByUnapprovedMapping
	|;
	|/////////////////////////////////////////////////////////////////////////////
	|";
	
	Query = New Query;
	Query.Text                   = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	ObjectMappingStatistics().MappedByRegisterSourceObjectCount    = ResultsArray[0].Unload()[0]["Count"];
	ObjectMappingStatistics().CountOfMappedByRegisterDestinationObjects    = ResultsArray[1].Unload()[0]["Count"];
	ObjectMappingStatistics().MappedByUnapprovedRelationsObjectCount = ResultsArray[2].Unload()[0]["Count"];
	
EndProcedure

Procedure AddNumberFieldToMappingTable()
	
	MappingTable().Columns.Add("SerialNumber", New TypeDescription("Number"));
	
	For Each TableRow In MappingTable() Do
		
		TableRow.SerialNumber = MappingTable().IndexOf(TableRow);
		
	EndDo;
	
EndProcedure

Function MergeUnapprovedMappingTableAndAutomaticMappingTable(TempTablesManager)
	
	QueryText = "
	|SELECT
	|
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	(
	|	SELECT
	|
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		SourceUUID,
	|		DestinationUUID,
	|		SourceType,
	|		DestinationType
	|	FROM 
	|		UnapprovedMappingTable
	|
	|	UNION
	|
	|	SELECT
	|
	|		// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|		DestinationUUID AS SourceUUID,
	|		SourceUUID AS DestinationUUID,
	|		DestinationType                     AS SourceType,
	|		SourceType                     AS DestinationType
	|	FROM 
	|		AutomaticallyMappedObjectsTable
	|
	|	) AS NestedQuery
	|
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function AutomaticallyMappedObjectsTableGet(TempTablesManager, UserFields)
	
	QueryText = "
	|SELECT
	|	
	|	&CUSTOMFIELDSMappingTable,
	|	
	|	TRUE AS Check,
	|	
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|	
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	DestinationUUID AS SourceUUID,
	|	SourceUUID AS DestinationUUID,
	|	DestinationType                     AS SourceType,
	|	SourceType                     AS DestinationType
	|FROM
	|	AutomaticallyMappedObjectsTable
	|";
	
	QueryText = StrReplace(QueryText, "&CUSTOMFIELDSMappingTable,", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function ObjectMappingResult(SourceTable2, UserFields, TempTablesManager)
	
	QueryText = "
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|
	|	&CUSTOMFIELDSMappingTable,
	|
	|	&SortingFields,
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	SourcePictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	UnmappedSourceObjectsTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	&CUSTOMFIELDSMappingTable,
	|
	|	&SortingFields,
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	DestinationPictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	UnmappedDestinationObjectsTable
	|
	|UNION ALL
	|
	|SELECT
	|
	|	&CUSTOMFIELDSMappingTable,
	|
	|	&SortingFields,
	|
	|	MappingStatus,
	|	MappingStatusAdditional,
	|
	|	DestinationPictureIndex AS PictureIndex,
	|
	|	DestinationPictureIndex,
	|	SourcePictureIndex,
	|
	|	// {ДАННЫЕ РЕГИСТРА СОПОСТАВЛЕНИЯ}
	|	SourceUUID,
	|	DestinationUUID,
	|	SourceType,
	|	DestinationType
	|FROM
	|	TableOfMappedObjects
	|";
	
	QueryText = StrReplace(QueryText, "&CUSTOMFIELDSMappingTable,", GetUserFields(UserFields, "SourceFieldNN, DestinationFieldNN,"));
	QueryText = StrReplace(QueryText, "&SortingFields,", GetUserFields(UserFields, "SortFieldNN,"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

Function SourceInfobaseData(Cancel)
	
	// Function return value.
	DataTable = Undefined;
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return Undefined;
	EndIf;
	
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	DataTableKey = DataExchangeServer.DataTableKey(SourceTypeString, DestinationTypeString, IsObjectDeletion);
	
	// 
	DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
	
	// Importing the data table if it is not imported earlier
	If DataTable = Undefined Then
		
		TablesToImport = New Array;
		TablesToImport.Add(DataTableKey);
		
		// 
		DataExchangeDataProcessor.ExecuteDataImportIntoValueTable(TablesToImport);
		
		If DataExchangeDataProcessor.FlagErrors() Then
			
			NString = NStr("en = 'Errors occurred while importing the exchange message: %1';");
			NString = StringFunctionsClientServer.SubstituteParametersToString(NString, DataExchangeDataProcessor.ErrorMessageString());
			Common.MessageToUser(NString,,,, Cancel);
			Return Undefined;
		EndIf;
		
		DataTable = DataExchangeDataProcessor.DataTablesExchangeMessages().Get(DataTableKey);
		
	EndIf;
	
	If DataTable = Undefined Then
		
		Cancel = True;
		
	EndIf;
	
	Return DataTable;
EndFunction

Function GetUserFields(UserFields, FieldPattern)
	
	// Function return value.
	Result = "";
	
	For Each Field In UserFields Do
		
		FieldNumber = UserFields.Find(Field) + 1;
		
		CurrentField = StrReplace(FieldPattern, "#", Field);
		
		CurrentField = StrReplace(CurrentField, "NN", String(FieldNumber));
		
		Result = Result + Chars.LF + CurrentField;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function GetSortingFieldsAtServer()
	
	// Function return value.
	SortFields = "";
	
	FieldPattern = "SortFieldNN #SortDirection"; // 
	
	For Each TableRow In SortTable Do
		
		If TableRow.Use Then
			
			Separator = ?(IsBlankString(SortFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ListItem = UsedFieldsList.FindByValue(TableRow.FieldName);
			
			FieldIndex = UsedFieldsList.IndexOf(ListItem) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortDirection", SortDirectionStr);
			
			SortFields = SortFields + Separator + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortFields;
	
EndFunction

Function GetMappingByFieldsCondition(MappingFieldsList)
	
	// Function return value.
	Result = "";
	
	For Each Item In MappingFieldsList Do
		
		If Item.Check Then
			
			If StrFind(Item.Presentation, DataExchangeServer.UnlimitedLengthString()) > 0 Then
				
				FieldPattern = "SUBSTRING(UnmappedDestinationObjectsTableByFields.DestinationFieldNN, 0, 1024) = SUBSTRING(UnmappedSourceObjectsTableByFields.SourceFieldNN, 0, 1024)";
				
			Else
				
				FieldPattern = "UnmappedDestinationObjectsTableByFields.DestinationFieldNN = UnmappedSourceObjectsTableByFields.SourceFieldNN";
				
			EndIf;
			
			FieldNumber = MappingFieldsList.IndexOf(Item) + 1;
			
			CurrentField = StrReplace(FieldPattern, "NN", String(FieldNumber));
			
			OperationLiteral = ?(IsBlankString(Result), "", "And");
			
			Result = Result + Chars.LF + OperationLiteral + " " + CurrentField;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal auxiliary procedures and functions.

Procedure FillListWithSelectedItems(SourceList, DestinationList)
	
	DestinationList.Clear();
	
	For Each Item In SourceList Do
		
		If Item.Check Then
			
			DestinationList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillSortTable(SourceValueList)
	
	SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = SortTable.Add();
		
		TableRow.FieldName               = Item.Value;
		TableRow.Use         = IsFirstField; // 
		TableRow.SortDirection = True; // 
		
	EndDo;
	
EndProcedure

Procedure FillListWithAdditionalParameters(TableFieldsList)
	
	MetadataObject = Metadata.FindByType(Type(SourceTableObjectTypeName));
	
	FieldListToDelete = New Array;
	ValueStorageType = New TypeDescription("ValueStorage");
	
	For Each Item In TableFieldsList Do
		
		Attribute = MetadataObject.Attributes.Find(Item.Value);
		
		If  Attribute = Undefined
			And DataExchangeServer.IsStandardAttribute(MetadataObject.StandardAttributes, Item.Value) Then
			
			Attribute = MetadataObject.StandardAttributes[Item.Value];
			
		EndIf;
		
		If Attribute = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %2 attribute is not defined for the %1 metadata object.';"),
				MetadataObject.FullName(),
				String(Item.Value));
		EndIf;
			
		If Attribute.Type = ValueStorageType Then
			
			FieldListToDelete.Add(Item);
			Continue;
			
		EndIf;
		
		Presentation = "";
		
		If IsUnlimitedLengthString(Attribute) Then
			
			Presentation = StringFunctionsClientServer.SubstituteParametersToString("%1 %2",
				?(IsBlankString(Attribute.Synonym), Attribute.Name, TrimAll(Attribute.Synonym)),
				DataExchangeServer.UnlimitedLengthString());
		Else
			
			Presentation = TrimAll(Attribute.Synonym);
			
		EndIf;
		
		If IsBlankString(Presentation) Then
			
			Presentation = Attribute.Name;
			
		EndIf;
		
		Item.Presentation = Presentation;
		
	EndDo;
	
	For Each ItemToRemove In FieldListToDelete Do
		
		TableFieldsList.Delete(ItemToRemove);
		
	EndDo;
	
EndProcedure

Procedure CheckMappingFieldCountInArray(Array)
	
	If Array.Count() > DataExchangeServer.MaxObjectsMappingFieldsCount() Then
		
		Array.Delete(Array.UBound());
		
		CheckMappingFieldCountInArray(Array);
		
	EndIf;
	
EndProcedure

Procedure AddSearchField(Array, Value)
	
	Item = TableFieldsList.FindByValue(Value);
	
	If Item <> Undefined Then
		
		Array.Add(Item.Value);
		
	EndIf;
	
EndProcedure

Function IsUnlimitedLengthString(Attribute)
	
	Return Attribute.Type = UnlimitedLengthStringType();
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf