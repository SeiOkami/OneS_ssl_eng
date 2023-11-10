///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region SelectiveDataRegistration

// 
// 
//
// Returns:
//  String - 
//
Function SelectiveRegistrationModeDisabled() Export
	
	Return "Disabled";
	
EndFunction

// 
// 
//
// Returns:
//  String - 
//
Function SelectiveRegistrationModeModification() Export
	
	Return "Modified";
	
EndFunction

// 
// 
// 
// 
//
// Returns:
//  String - 
//
Function SelectiveRegistrationModeByXMLRules() Export
	
	Return "AccordingToXMLRules";
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region SelectiveDataRegistration

Function SelectiveObjectsRegistrationRulesTableInitialization() Export
	
	TypeDescriptionNumber = New TypeDescription("Number");
	StringTypeDetails = New TypeDescription("String");
	DetailsOfStructureType = New TypeDescription("Structure");
	
	ResultTable1 = New ValueTable;
	
	ResultTable1.Columns.Add("Order",                        TypeDescriptionNumber);
	ResultTable1.Columns.Add("ObjectName",                     StringTypeDetails);
	ResultTable1.Columns.Add("ObjectTypeString",              StringTypeDetails);
	ResultTable1.Columns.Add("ExchangePlanName",                 StringTypeDetails);
	ResultTable1.Columns.Add("TabularSectionName",              StringTypeDetails);
	ResultTable1.Columns.Add("RegistrationAttributes",           StringTypeDetails);
	ResultTable1.Columns.Add("RegistrationAttributesStructure", DetailsOfStructureType);
	
	ResultTable1.Indexes.Add("ObjectName, ObjectTypeString, ExchangePlanName, TabularSectionName");
	
	Return ResultTable1;
	
EndFunction

Function NewParametersOfExchangePlanDataSelectiveRegistration(ExchangePlanName) Export
	
	If DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName) Then
		
		Return New Structure;
		
	EndIf;
	
	SelectiveRegistrationParameters = New Structure;
	SelectiveRegistrationParameters.Insert("IsXDTOExchangePlan", False);
	SelectiveRegistrationParameters.Insert("RegistrationAttributesTable", Undefined);
	
	BeforeGenerateNewParametersOfExchangePlanDataSelectiveRegistration(SelectiveRegistrationParameters, ExchangePlanName);
	
	Return SelectiveRegistrationParameters;
	
EndFunction

Function ObjectModifiedForExchangePlan(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectToExport) Export
	
	Try
		
		ObjectIsModified = ObjectIsModified(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectToExport);
		
	Except
		
		TemplateRow = NStr("en = 'Cannot determining whether the object was modified: %1';", Common.DefaultLanguageCode());
		Raise StrTemplate(TemplateRow, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	Return ObjectIsModified;
	
EndFunction

Function DetermineObjectVersionsChanges(Object, RegistrationAttributesTableRow) Export
	
	If IsBlankString(RegistrationAttributesTableRow.TabularSectionName) Then // 
		
		RegistrationAttributesTableObjectVersionBeforeChange = HeaderRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow);
		
		RegistrationAttributesTableObjectVersionAfterChange = HeaderRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow);
		
	Else // 
		
		// 
		If Object.Metadata().TabularSections.Find(RegistrationAttributesTableRow.TabularSectionName) = Undefined Then
			Return False;
		EndIf;
		
		RegistrationAttributesTableObjectVersionBeforeChange = TabularSectionRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow);
		
		RegistrationAttributesTableObjectVersionAfterChange = TabularSectionRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow);
		
	EndIf;
	
	Return Not RegistrationAttributesTablesSimilar(RegistrationAttributesTableObjectVersionBeforeChange, RegistrationAttributesTableObjectVersionAfterChange, RegistrationAttributesTableRow);
	
EndFunction

#EndRegion

Function RegistrationRuleEventName() Export
	
	Return NStr("en = 'Data exchange.Object registration rules';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion

#Region Private

#Region SelectiveDataRegistration

Function ModificationFlagFromPCR(Source, ExchangePlanName, MetadataObject, RegistrationAttributesTable)
	
	If TypeOf(RegistrationAttributesTable) <> Type("ValueTable") Then
		
		// 
		Return True;
		
	EndIf;
	
	ObjectName = MetadataObject.FullName();
	
	ObjectSelectiveRegistrationAttributes = ObjectSelectiveRegistrationAttributes(RegistrationAttributesTable, ObjectName, ExchangePlanName);
	If ObjectSelectiveRegistrationAttributes.Count() = 0 Then
		
		// 
		// 
		Return True;
		
	EndIf;
	
	For Each TableRow In ObjectSelectiveRegistrationAttributes Do
		
		HasObjectsVersionsChanges = DetermineObjectVersionsChanges(Source, TableRow);
		If HasObjectsVersionsChanges Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	// 
	Return False;
	
EndFunction

Function ValueOfInfobaseObjectModificationProperty(Source)
	
	Try
		
		Return Source.Modified();
		
	Except
		
		Return True;
		
	EndTry;
	
EndFunction

Function DocumentPostingChanged(Source, WriteMode)
	
	Return (Source.Posted And WriteMode = DocumentWriteMode.UndoPosting)
	 Or (Not Source.Posted And WriteMode = DocumentWriteMode.Posting);
	
EndFunction

Function InitializeTablesOfCommonAttributes()
	
	CommonAttributeTable = New ValueTable;
	CommonAttributeTable.Columns.Add("CommonAttribute");
	CommonAttributeTable.Columns.Add("MetadataObject");
	
	CommonAttributeTable.Indexes.Add("CommonAttribute, MetadataObject");
	
	Return CommonAttributeTable;
	
EndFunction

Function ObjectRegistrationAttributesTableMetadata(CurrentObjetMetadata, RequiredTabularSectionName)
	
	MetaTest = New Structure("TabularSections, StandardTabularSections, RegisterRecords");
	FillPropertyValues(MetaTest, CurrentObjetMetadata);
	MetaTables = New Array;
	
	CandidateName = Upper(RequiredTabularSectionName);
	
	For Each KeyValue In MetaTest Do
		TableMetaCollection = KeyValue.Value; // 
		If TableMetaCollection <> Undefined Then
			
			For Each MetaTable In TableMetaCollection Do
				If Upper(MetaTable.Name) = CandidateName Then
					MetaTables.Add(MetaTable);
				EndIf;
			EndDo;
			
		EndIf;
	EndDo;
	If MetaTables.Count() > 0 Then
		Return MetaTables;
	EndIf;

	Return Undefined;
	
EndFunction

Function ObjectIsModified(Source, MetadataObject, ExchangePlanName, WriteMode, RecordObjectToExport)
	
	If RecordObjectToExport
		Or Source.IsNew()
		Or Source.DataExchange.Load Then
		
		// 
		// 
		// 
		// 
		// 
		Return True;
		
	ElsIf WriteMode <> Undefined
		And DocumentPostingChanged(Source, WriteMode) Then
		
		// 
		Return True;
		
	EndIf;
	
	SelectiveRegistrationMode = DataExchangeRegistrationCached.ExchangePlanDataSelectiveRegistrationMode(ExchangePlanName);
	If SelectiveRegistrationMode = SelectiveRegistrationModeDisabled() Then
		
		// 
		Return True;
		
	ElsIf SelectiveRegistrationMode = SelectiveRegistrationModeModification() Then
		
		Return ValueOfInfobaseObjectModificationProperty(Source);
		
	Else
		
		SelectiveRegistrationParameters = DataExchangeRegistrationCached.SelectiveRegistrationParametersByExchangeNodeName(ExchangePlanName);
		If TypeOf(SelectiveRegistrationParameters) = Type("Structure") Then
			
			Return ModificationFlagFromPCR(Source, ExchangePlanName, MetadataObject, SelectiveRegistrationParameters.RegistrationAttributesTable);
			
		Else
			
			// 
			
			
		EndIf;
		
	EndIf;
	
	// 
	// 
	Return True;
	
EndFunction

Function AttributeIsFoundInTabularSectionOfObjectRegistrationAttributes(MetadataTables, NameOfSoughtAttribute)
	
	MetaTest = New Structure("Attributes, StandardAttributes, Dimensions, Resources");
	FillPropertyValues(MetaTest, MetadataTables);
	
	CandidateName = Upper(NameOfSoughtAttribute);
	Correspondence = False;
	If TypeOf(MetadataTables) = Type("MetadataObject") And Common.IsAccountingRegister(MetadataTables) Then
		Correspondence = MetadataTables.Correspondence;
		// 
		// 
		If CandidateName = "EXTDIMENSIONDR" Or CandidateName = "EXTDIMENSIONCR"
			Or CandidateName = "ACCOUNTDR" Or CandidateName = "ACCOUNTCR" Then
			Return True;
		EndIf;
	EndIf;
	
	For Each KeyValue In MetaTest Do
		MetaCollectionOfAttribuutes = KeyValue.Value; // 
		
		If MetaCollectionOfAttribuutes <> Undefined Then
			
			For Each MetaAttribute In MetaCollectionOfAttribuutes Do
				
				If Upper(MetaAttribute.Name) = CandidateName Then
					Return True;
				EndIf;
				
				If (KeyValue.Key = "Dimensions" Or KeyValue.Key = "Resources") And Correspondence And Not MetaAttribute.Balance Then
					If Upper(MetaAttribute.Name) + "DR" = CandidateName
						Or Upper(MetaAttribute.Name) + "CR" = CandidateName Then
						Return True;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ObjectSelectiveRegistrationAttributes(RegistrationAttributesTable, ObjectName, ExchangePlanName)
	
	If RegistrationAttributesTable.Count() = 0 Then
		
		Return RegistrationAttributesTable;
		
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", ExchangePlanName);
	Filter.Insert("ObjectName",     ObjectName);
	
	TableOfSelectiveRegistrationAttributes = RegistrationAttributesTable.Copy(Filter);
	TableOfSelectiveRegistrationAttributes.Sort("Order Asc");
	
	Return TableOfSelectiveRegistrationAttributes;
	
EndFunction

Function HeaderRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow)
	
	QueryTextTemplate2 =
	"SELECT
	|	&RegistrationAttributes
	|FROM
	|	&MetadataTableName AS CurrentObject
	|WHERE
	|	CurrentObject.Ref = &Ref";
	
	QueryText = StrReplace(QueryTextTemplate2, "&RegistrationAttributes", RegistrationAttributesTableRow.RegistrationAttributes);
	QueryText = StrReplace(QueryText, "&MetadataTableName", RegistrationAttributesTableRow.ObjectName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	Return Query.Execute().Unload();
	
EndFunction

Function TabularSectionRegistrationAttributesBeforeChange(Object, RegistrationAttributesTableRow)
	
	QueryTextTemplate2 = 
	"SELECT
	|	&RegistrationAttributes
	|FROM
	|	&MetadataTableName AS CurrentObjectTabularSectionName
	|WHERE
	|	CurrentObjectTabularSectionName.Ref = &Ref";
	
	ReplacementString = StringFunctionsClientServer.SubstituteParametersToString("%1.%2", RegistrationAttributesTableRow.ObjectName, RegistrationAttributesTableRow.TabularSectionName);
	
	QueryText = StrReplace(QueryTextTemplate2, "&RegistrationAttributes", RegistrationAttributesTableRow.RegistrationAttributes);
	QueryText = StrReplace(QueryText, "&MetadataTableName", ReplacementString);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	Return Query.Execute().Unload();
	
EndFunction

Function HeaderRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow)
	
	RegistrationAttributesStructure = RegistrationAttributesTableRow.RegistrationAttributesStructure;
	
	RegistrationAttributesTable = New ValueTable;
	
	For Each RegistrationAttribute In RegistrationAttributesStructure Do
		
		RegistrationAttributesTable.Columns.Add(RegistrationAttribute.Key);
		
	EndDo;
	
	TableRow = RegistrationAttributesTable.Add();
	
	For Each RegistrationAttribute In RegistrationAttributesStructure Do
		
		TableRow[RegistrationAttribute.Key] = Object[RegistrationAttribute.Key];
		
	EndDo;
	
	Return RegistrationAttributesTable;
EndFunction

Function TabularSectionRegistrationAttributesAfterChange(Object, RegistrationAttributesTableRow)
	
	RegistrationAttributesTable = Object[RegistrationAttributesTableRow.TabularSectionName].Unload(, RegistrationAttributesTableRow.RegistrationAttributes);
	
	Return RegistrationAttributesTable;
	
EndFunction

Function RegistrationAttributesTablesSimilar(Table1, Table2, RegistrationAttributesTableRow)
	
	Table1.Columns.Add("ChangeRecordAttributeTableIterator");
	Table1.FillValues(+1, "ChangeRecordAttributeTableIterator");
	
	Table2.Columns.Add("ChangeRecordAttributeTableIterator");
	Table2.FillValues(-1, "ChangeRecordAttributeTableIterator");
	
	ResultTable1 = Table1.Copy();
	
	CommonClientServer.SupplementTable(Table2, ResultTable1);
	
	ResultTable1.GroupBy(RegistrationAttributesTableRow.RegistrationAttributes, "ChangeRecordAttributeTableIterator");
	
	SameRowsCount = ResultTable1.FindRows(New Structure ("ChangeRecordAttributeTableIterator", 0)).Count();
	
	TableRowsCount = ResultTable1.Count();
	
	Return SameRowsCount = TableRowsCount;
	
EndFunction

Function IsCommonAttribute(CommonAttribute, MDOName, CommonAttributeTable)
	
	SearchParameters = New Structure("CommonAttribute, MetadataObject", CommonAttribute, MDOName);
	FoundValues = CommonAttributeTable.FindRows(SearchParameters);
	
	If FoundValues.Count() > 0 Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure CheckObjectChangeRecordAttributes(RegistrationAttributesTable)
	
	For Each TableRow In RegistrationAttributesTable Do
		
		Try
			ObjectType = Type(TableRow.ObjectTypeString);
		Except
			
			MessageString = NStr("en = 'Undefined object type: %1';", Common.DefaultLanguageCode());
			MessageString = StrTemplate(MessageString, TableRow.ObjectTypeString);
			WriteToExecutionProtocol(MessageString);
			Continue;
			
		EndTry;
		
		MetadataObjectsList = Metadata.FindByType(ObjectType);
		
		// 
		If Not Common.IsRefTypeObject(MetadataObjectsList) Then
			Continue;
		EndIf;
		
		CommonAttributeTable = InitializeTablesOfCommonAttributes();
		FillCommonAttributeTable(CommonAttributeTable);
		
		If IsBlankString(TableRow.TabularSectionName) Then // 
			
			For Each Attribute In TableRow.RegistrationAttributesStructure Do
				
				If Common.IsTask(MetadataObjectsList) Then
					
					If Not (MetadataObjectsList.Attributes.Find(Attribute.Key) <> Undefined
						Or  MetadataObjectsList.AddressingAttributes.Find(Attribute.Key) <> Undefined
						Or  DataExchangeServer.IsStandardAttribute(MetadataObjectsList.StandardAttributes, Attribute.Key)
						Or  IsCommonAttribute(Attribute.Key, MetadataObjectsList.FullName(), CommonAttributeTable)) Then
						
						MessageString = NStr("en = 'Invalid header attributes of the ""%1"" object. Attribute ""%2"" does not exist.';");
						MessageString = StrTemplate(MessageString, String(MetadataObjectsList), Attribute.Key);
						WriteToExecutionProtocol(MessageString);
						
					EndIf;
					
				ElsIf Common.IsChartOfAccounts(MetadataObjectsList) Then
					
					If Not (MetadataObjectsList.Attributes.Find(Attribute.Key) <> Undefined
						Or  MetadataObjectsList.AccountingFlags.Find(Attribute.Key) <> Undefined
						Or  DataExchangeServer.IsStandardAttribute(MetadataObjectsList.StandardAttributes, Attribute.Key)
						Or  IsCommonAttribute(Attribute.Key, MetadataObjectsList.FullName(), CommonAttributeTable)) Then
						
						MessageString = NStr("en = 'Invalid header attributes of the ""%1"" object. Attribute ""%2"" does not exist.';");
						MessageString = StrTemplate(MessageString, String(MetadataObjectsList), Attribute.Key);
						WriteToExecutionProtocol(MessageString);
						
					EndIf;
					
				Else
					
					If Not (MetadataObjectsList.Attributes.Find(Attribute.Key) <> Undefined
						Or  DataExchangeServer.IsStandardAttribute(MetadataObjectsList.StandardAttributes, Attribute.Key)
						Or  IsCommonAttribute(Attribute.Key, MetadataObjectsList.FullName(), CommonAttributeTable)) Then
						
						MessageString = NStr("en = 'Invalid header attributes of the ""%1"" object. Attribute ""%2"" does not exist.';");
						MessageString = StrTemplate(MessageString, String(MetadataObjectsList), Attribute.Key);
						WriteToExecutionProtocol(MessageString);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		Else
			
			// 
			MetaTables = ObjectRegistrationAttributesTableMetadata(MetadataObjectsList, TableRow.TabularSectionName);
			If MetaTables = Undefined Then
				
				MessageString = NStr("en = 'The ""%1"" table (or a standard table, or a list of register records) of the ""%2"" object does not exist.';");
				WriteToExecutionProtocol(StrTemplate(MessageString, TableRow.TabularSectionName, MetadataObjectsList));
				Continue;
				
			EndIf;
			
			// 
			For Each Attribute In TableRow.RegistrationAttributesStructure Do
				
				PropsFound = False;
				For Each MetaTable In MetaTables Do
					PropsFound = AttributeIsFoundInTabularSectionOfObjectRegistrationAttributes(MetaTable, Attribute.Key);
					If PropsFound Then
						Break;
					EndIf;
				EndDo;
				
				If Not PropsFound Then
					
					MessageString = NStr("en = 'The ""%3"" attribute is not found in the ""%1"" table (or a standard table, or a list of register records) of the ""%2"" object.';");
					WriteToExecutionProtocol(StrTemplate(MessageString, TableRow.TabularSectionName, MetadataObjectsList, Attribute.Key));
					Break;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SupplementChangeRecordAttributeTable(RowsArray, RegistrationAttributesTable)
	
	TableRow = RegistrationAttributesTable.Add();
	
	ResultingStructure = New Structure;
	RegistrationAttributesAsString = "";
	
	For Each TableRowResult In RowsArray Do
		
		RegistrationAttributesStructure = TableRowResult.RegistrationAttributesStructure;
		For Each RegistrationAttribute In RegistrationAttributesStructure Do
			
			ResultingStructure.Insert(RegistrationAttribute.Key);
			RegistrationAttributesAsString = RegistrationAttributesAsString + RegistrationAttribute.Key + ", ";
			
		EndDo;
		
	EndDo;
	
	StringFunctionsClientServer.DeleteLastCharInString(RegistrationAttributesAsString, 2);
	
	TableRow.Order                        = RowsArray[0].Order;
	TableRow.ObjectName                     = RowsArray[0].ObjectName;
	TableRow.ObjectTypeString              = RowsArray[0].ObjectTypeString;
	TableRow.TabularSectionName              = RowsArray[0].TabularSectionName;
	TableRow.RegistrationAttributesStructure = ResultingStructure;
	TableRow.RegistrationAttributes           = RegistrationAttributesAsString;
	
EndProcedure

Procedure AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, TabularSectionName, Order, PropertiesTable, ResultTable1)
	
	RegistrationAttributesStructure = New Structure;
	
	PCRRowsArray = PropertiesTable.FindRows(New Structure("IsFolder", False));
	For Each PCR In PCRRowsArray Do
		
		PCRSource = PCR.Source;
		
		// 
		If IsBlankString(PCRSource)
			Or Left(PCRSource, 1) = "{" Then
			
			Continue;
		EndIf;
		
		Try
			RegistrationAttributesStructure.Insert(PCRSource);
		Except
			WriteLogEvent(NStr("en = 'Data exchange.Import conversion rules';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;
	
	TableRowResult = ResultTable1.Add();
	
	TableRowResult.Order                        = Order;
	TableRowResult.ObjectName                     = ObjectName;
	TableRowResult.ObjectTypeString              = ObjectTypeString;
	TableRowResult.TabularSectionName              = TabularSectionName;
	TableRowResult.RegistrationAttributesStructure = RegistrationAttributesStructure; 
	
EndProcedure

Procedure WriteToExecutionProtocol(ErrorText)
	
	DataProcessorObject = DataProcessors.InfobaseObjectConversion.Create();
	DataProcessorObject.WriteToExecutionProtocol(ErrorText);
	
EndProcedure

Procedure PopulateAttributesOfSelectiveRegistrationByOCRCollection(SelectiveRegistrationParameters, ExchangePlanName, ConversionRulesTable)
	
	If ConversionRulesTable.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	RegistrationAttributesTable = SelectiveObjectsRegistrationRulesTableInitialization();
	ResultTable1             = SelectiveObjectsRegistrationRulesTableInitialization();
	
	For Each OCR In ConversionRulesTable Do
		
		FillObjectChangeRecordAttributeTableDetailsByRule(OCR, ResultTable1);
		
	EndDo;
		
	ResultTableGroup = ResultTable1.Copy();
	ResultTableGroup.GroupBy("ObjectName, TabularSectionName");
	
	// 
	For Each TableRow In ResultTableGroup Do
		
		Filter = New Structure("ObjectName, TabularSectionName", TableRow.ObjectName, TableRow.TabularSectionName);
		ResultTableRowArray = ResultTable1.FindRows(Filter);
		SupplementChangeRecordAttributeTable(ResultTableRowArray, RegistrationAttributesTable);
		
	EndDo;
	
	DeleteChangeRecordAttributeTableRowsWithErrors(RegistrationAttributesTable);
	CheckObjectChangeRecordAttributes(RegistrationAttributesTable);
	
	// 
	RegistrationAttributesTable.FillValues(ExchangePlanName, "ExchangePlanName");
	
	SelectiveRegistrationParameters.RegistrationAttributesTable = RegistrationAttributesTable;
	
EndProcedure

Procedure FillObjectChangeRecordAttributeTableDetailsByRule(OCR, ResultTable1)
	
	ObjectName        = StrReplace(OCR.SourceType, "Ref", "");
	ObjectTypeString = OCR.SourceType;
	
	// 
	AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, "", -50, OCR.Properties, ResultTable1);
	
	// 
	AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, "", -50, OCR.SearchProperties, ResultTable1);
	
	// 
	AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, "", -50, OCR.DisabledProperties, ResultTable1);
	
	// 
	PGCRArray = OCR.Properties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR In PGCRArray Do
		
		// 
		AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.Order, PGCR.GroupRules, ResultTable1);
		
		// 
		AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.Order, PGCR.DisabledGroupRules, ResultTable1);
		
	EndDo;
	
	// 
	PGCRArray = OCR.DisabledProperties.FindRows(New Structure("IsFolder", True));
	
	For Each PGCR In PGCRArray Do
		
		// 
		AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.Order, PGCR.GroupRules, ResultTable1);
		
		// 
		AddRowToSelectiveRegistrationTable(ObjectTypeString, ObjectName, PGCR.Source, PGCR.Order, PGCR.DisabledGroupRules, ResultTable1);
		
	EndDo;
	
EndProcedure

Procedure FillCommonAttributeTable(CommonAttributeTable)
	
	If Metadata.CommonAttributes.Count() <> 0 Then
		
		CommonAttributeAutoUse = Metadata.ObjectProperties.CommonAttributeUse.Auto;
		CommonAttributeUse = Metadata.ObjectProperties.CommonAttributeUse.Use;
		
		For Each CommonAttribute In Metadata.CommonAttributes Do
			
			If CommonAttribute.DataSeparationUse = Undefined Then
				
				AutoUse = (CommonAttribute.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
				
				For Each Item In CommonAttribute.Content Do
					
					If Item.Use = CommonAttributeUse
						Or (Item.Use = CommonAttributeAutoUse And AutoUse) Then
						
						NewRow = CommonAttributeTable.Add();
						NewRow.CommonAttribute = CommonAttribute.Name;
						NewRow.MetadataObject = Item.Metadata.FullName();
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure BeforeGenerateNewParametersOfExchangePlanDataSelectiveRegistration(SelectiveRegistrationParameters, ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	If DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName) Then
		
		SelectiveRegistrationParameters.IsXDTOExchangePlan = True;
		
	Else
		
		SelectiveRegistrationParameters.IsXDTOExchangePlan = False;
		
		SelectiveRegistrationMode = DataExchangeRegistrationCached.ExchangePlanDataSelectiveRegistrationMode(ExchangePlanName);
		
		// 
		// 
		If SelectiveRegistrationMode = SelectiveRegistrationModeByXMLRules() Then
			
			RulesAreRead = InformationRegisters.DataExchangeRules.ParsedRulesOfObjectConversion(ExchangePlanName);
			If TypeOf(RulesAreRead) = Type("ValueStorage") Then
				
				StructureOfReadRules = RulesAreRead.Get();
				If StructureOfReadRules.Property("ConversionRulesTable")
					And TypeOf(StructureOfReadRules.ConversionRulesTable) = Type("ValueTable") Then
					
					PopulateAttributesOfSelectiveRegistrationByOCRCollection(SelectiveRegistrationParameters, ExchangePlanName, StructureOfReadRules.ConversionRulesTable);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteChangeRecordAttributeTableRowsWithErrors(RegistrationAttributesTable)
	
	CollectionItemsCount = RegistrationAttributesTable.Count();
	
	For ReverseIndex = 1 To CollectionItemsCount Do
		
		TableRow = RegistrationAttributesTable[CollectionItemsCount - ReverseIndex];
		
		// 
		If IsBlankString(TableRow.RegistrationAttributes) Then
			
			RegistrationAttributesTable.Delete(TableRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
