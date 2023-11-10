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

Var ObjectsEnabledByOption Export;

#EndRegion

#Region Public

// Returns a value tree that contains data required to select a node. The tree has two levels: 
// exchange plan -> exchange nodes. Internal nodes are not included in the tree. 
//
// Parameters:
//    DataObject - AnyRef
//                 - Structure - 
//                   
//    TableName   - String - if DataObject is a structure, then the table name is for records set.
//
// Returns:
//    ValueTree:
//        * Description                  - String - presentation of exchange plan or exchange node.
//        * PictureIndex                - Number  - 1 = exchange plan 2 = node 3 = node marked for deletion.
//        * AutoRecordPictureIndex - Number  - if the DataObject parameter is not specified, it is Undefined.
//                                                   Else: 0 = none, 1 = prohibited, 2 = enabled, Undefined for
//                                                   the exchange plan.
//        * ExchangePlanName1                 - String - node exchange plan.
//        * Ref                        - ExchangePlanRef - a node reference, Undefined for the exchange plan.
//        * Code                           - Number
//                                        - String - 
//        * SentNo            - Number - node data.
//        * ReceivedNo                - Number - node data.
//        * MessageNo                - Number
//                                        - Null - 
//        * NotExported                 - Boolean
//                                        - Null - 
//        * Check                       - Boolean       - if object is specified, 0 = no registration, 1 = there is a registration, else it is
//                                                         always 0.
//        * InitialMark               - Boolean       - similar to the Mark column.
//        * RowID           - Number        - index of the added row (the tree is iterated from top to bottom from left to
//                                                         right).
//
Function GenerateNodeTree(DataObject = Undefined, TableName = Undefined) Export
	
	Tree = New ValueTree; // See GenerateNodeTree
	Columns = Tree.Columns;
	Rows  = Tree.Rows;
	
	Columns.Add("Description");
	Columns.Add("PictureIndex");
	Columns.Add("AutoRecordPictureIndex");
	Columns.Add("ExchangePlanName1");
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("SentNo");
	Columns.Add("ReceivedNo");
	Columns.Add("MessageNo");
	Columns.Add("NotExported");
	Columns.Add("Check");
	Columns.Add("InitialMark");
	Columns.Add("RowID");
	
	SubqueryText = "";
	
	Query = New Query;
	If DataObject = Undefined Then
		
		MetaObject = Undefined;
		QueryText = 
		"SELECT
		|	REFPRESENTATION(ExchangePlan.Ref) AS Description,
		|	CASE
		|		WHEN ExchangePlan.DeletionMark
		|			THEN 2
		|		ELSE 1
		|	END AS PictureIndex,
		|	""&TextRepresentationOfTheExchangePlan"" AS ExchangePlanName1,
		|	ExchangePlan.Code AS Code,
		|	ExchangePlan.Ref AS Ref,
		|	ExchangePlan.SentNo AS SentNo,
		|	ExchangePlan.ReceivedNo AS ReceivedNo,
		|	NULL AS MessageNo,
		|	NULL AS NotExported,
		|	0 AS NodeChangeCount
		|FROM
		|	&ExchangePlanTableName AS ExchangePlan
		|WHERE
		|	NOT ExchangePlan.ThisNode";
		
	Else
		
		If TypeOf(DataObject) = Type("Structure") Then
			
			For Each KeyValue In DataObject Do
				
				CurName = KeyValue.Key;
				SubqueryText = SubqueryText + "
					|AND ChangesTable." + CurName + " = &" + CurName;
				Query.SetParameter(CurName, DataObject[CurName]);
				
			EndDo;
			
			CurTableName = TableName;
			MetaObject    = MetadataByFullName(TableName);
			
		ElsIf TypeOf(DataObject) = Type("String") Then
			
			CurTableName = DataObject;
			MetaObject    = MetadataByFullName(DataObject);
			
		Else
			
			SubqueryText = "
				|AND ChangesTable.Ref = &RegistrationObject";
			Query.SetParameter("RegistrationObject", DataObject);
			
			MetaObject    = DataObject.Metadata();
			CurTableName = MetaObject.FullName();
			
		EndIf;
		
		QueryText = 
		"SELECT
		|	REFPRESENTATION(ExchangePlan.Ref) AS Description,
		|	CASE
		|		WHEN ExchangePlan.DeletionMark
		|			THEN 2
		|		ELSE 1
		|	END AS PictureIndex,
		|	""&TextRepresentationOfTheExchangePlan"" AS ExchangePlanName1,
		|	ExchangePlan.Code AS Code,
		|	ExchangePlan.Ref AS Ref,
		|	ExchangePlan.SentNo AS SentNo,
		|	ExchangePlan.ReceivedNo AS ReceivedNo,
		|	ChangesTable.MessageNo AS MessageNo,
		|	CASE
		|		WHEN ChangesTable.MessageNo IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS NotExported,
		|	COUNT(ChangesTable.Node) AS NodeChangeCount
		|FROM
		|	&ExchangePlanTableName AS ExchangePlan
		|		LEFT JOIN Catalog.DataExchangeScenarios.Changes AS ChangesTable
		|		ON ExchangePlan.Ref = ChangesTable.Node
		|			AND &ConditionsForTablesUnion
		|WHERE
		|	NOT ExchangePlan.ThisNode
		|
		|GROUP BY
		|	ExchangePlan.Ref,
		|	ChangesTable.MessageNo,
		|	CASE
		|		WHEN ExchangePlan.DeletionMark
		|			THEN 2
		|		ELSE 1
		|	END,
		|	ExchangePlan.Code,
		|	ExchangePlan.SentNo,
		|	ExchangePlan.ReceivedNo,
		|	CASE
		|		WHEN ChangesTable.MessageNo IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END";
		
	EndIf;
	
	CurRowNumber = 0;
	For Each Meta In Metadata.ExchangePlans Do
		
		If Not AccessRight("Read", Meta) Then
			Continue;
		EndIf;
	
		PlanName = Meta.Name;
		AutoRecord = Undefined;
		If MetaObject <> Undefined Then
			CompositionItem = Meta.Content.Find(MetaObject);
			If CompositionItem = Undefined Then
				// The object is not included in the current exchange plan.
				Continue;
			EndIf;
			AutoRecord = ?(CompositionItem.AutoRecord = AutoChangeRecord.Deny, 1, 2);
		EndIf;
		
		PlanName = Meta.Name;
		
		Query.Text = StrReplace(QueryText, "&TextRepresentationOfTheExchangePlan", PlanName);
		Query.Text = StrReplace(Query.Text, "&ExchangePlanTableName", SubstituteParametersToString("ExchangePlan.%1", PlanName));
		Query.Text = StrReplace(Query.Text, "Catalog.DataExchangeScenarios", CurTableName);
		Query.Text = StrReplace(Query.Text, "AND &ConditionsForTablesUnion", SubqueryText);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			PlanRow = Rows.Add();
			PlanRow.Description   = Meta.Presentation();
			PlanRow.PictureIndex = 0;
			PlanRow.ExchangePlanName1  = PlanName;
			
			PlanRow.RowID = CurRowNumber;
			CurRowNumber = CurRowNumber + 1;
			
			// Sorting by presentation cannot be applied in a query.
			TempTable = Result.Unload();
			TempTable.Sort("Description");
			For Each NodeRow In TempTable Do;
				NewRow = PlanRow.Rows.Add();
				FillPropertyValues(NewRow, NodeRow);
				
				NewRow.InitialMark = ?(NodeRow.NodeChangeCount > 0, 1, 0);
				NewRow.Check         = NewRow.InitialMark;
				
				NewRow.AutoRecordPictureIndex = AutoRecord;
				
				NewRow.RowID = CurRowNumber;
				CurRowNumber = CurRowNumber + 1;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return Tree;
	
EndFunction

// Returns the structure that describes the exchange plan metadata.
// Objects not included in the exchange plan are excluded.
//
// Parameters:
//    ExchangePlanName - String           - name of the exchange plan metadata that is used to generate a configuration tree.
//                   - ExchangePlanRef - 
//                   - Undefined     - 
//
// Returns: 
//    Structure - 
//         * NamesStructure              - Structure - Key - metadata group (constants, catalogs and so on),
//                                                    value is an array of full names.
//         * PresentationsStructure     - Structure - Key - metadata group (constants, catalogs and so on),
//                                                    value is an array of full names.
//         * AutoRecordStructure   - Structure - metadata group (constants, catalogs and so on),
//                                                    value is an array of autorecord flags on the node.
//         * Tree                     - See MetadataObjectsTree
//
Function GenerateMetadataStructure(ExchangePlanName = Undefined) Export
	
	Tree = MetadataObjectsTree();
	
	// Root.
	RootRow1 = Tree.Rows.Add();
	RootRow1.Description = Metadata.Presentation();
	RootRow1.PictureIndex = 0;
	RootRow1.RowID = 0;
	
	// Parameters.
	CurParameters = New Structure;
	CurParameters.Insert("NamesStructure", New Structure);
	CurParameters.Insert("PresentationsStructure", New Structure);
	CurParameters.Insert("AutoRecordStructure", New Structure);
	CurParameters.Insert("Rows", RootRow1.Rows);
	
	If ExchangePlanName = Undefined Then
		ExchangePlan = Undefined;
	ElsIf TypeOf(ExchangePlanName) = Type("String") Then
		ExchangePlan = Metadata.ExchangePlans[ExchangePlanName];
	Else
		ExchangePlan = ExchangePlanName.Metadata();
	EndIf;
	CurParameters.Insert("ExchangePlan", ExchangePlan);
	
	// 
	// 
	// 
	If ExchangePlan <> Undefined
		And ExchangePlan.DistributedInfoBase
		And ConfigurationSupportsSSL Then
		
		ORMSubscriptionsComposition = New Array;
		
		SubscriptionNamePrefix = ExchangePlan.Name + "Registration";
		
		For Each Subscription In Metadata.EventSubscriptions Do
			
			If Not StrStartsWith(Subscription.Name, SubscriptionNamePrefix) Then
				Continue;
			EndIf;
			
			For Each SourceType In Subscription.Source.Types() Do
				SourceMetadata = Metadata.FindByType(SourceType);
				If ORMSubscriptionsComposition.Find(SourceMetadata) = Undefined Then
					ORMSubscriptionsComposition.Add(SourceMetadata);
				EndIf;
			EndDo;
			
		EndDo;
		
		CurParameters.Insert("ORMSubscriptionsComposition", ORMSubscriptionsComposition);
	EndIf;
	
	Result = New Structure();
	Result.Insert("Tree", Tree);
	Result.Insert("NamesStructure", CurParameters.NamesStructure);
	Result.Insert("PresentationsStructure", CurParameters.PresentationsStructure);
	Result.Insert("AutoRecordStructure", CurParameters.AutoRecordStructure);

	CurRowNumber = 1;
	GenerateMetadataLevel(CurRowNumber, CurParameters, 1,  2,  False,   "Constants",               NStr("en = 'Constants';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 3,  4,  True, "Catalogs",             NStr("en = 'Catalogs';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 5,  6,  True, "Sequences",      NStr("en = 'Sequences';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 7,  8,  True, "Documents",               NStr("en = 'Documents';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 9,  10, True, "ChartsOfCharacteristicTypes", NStr("en = 'Charts of characteristic types';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 11, 12, True, "ChartsOfAccounts",             NStr("en = 'Charts of accounts';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 13, 14, True, "ChartsOfCalculationTypes",       NStr("en = 'Charts of calculation types';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 15, 16, True, "InformationRegisters",        NStr("en = 'Information registers';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 17, 18, True, "AccumulationRegisters",      NStr("en = 'Accumulation registers';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 19, 20, True, "AccountingRegisters",     NStr("en = 'Accounting registers';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 21, 22, True, "CalculationRegisters",         NStr("en = 'Calculation registers';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 23, 24, True, "BusinessProcesses",          NStr("en = 'Business processes';"));
	GenerateMetadataLevel(CurRowNumber, CurParameters, 25, 26, True, "Tasks",                  NStr("en = 'Tasks';"));
	
	Return Result;
EndFunction

// Calculates the number of changes in metadata objects for an exchange node.
//
// Parameters:
//     TablesList - Structure
//                  - Array of Structure - 
//                    
//     NodesList  - ExchangePlanRef
//                  - Array of ExchangePlanRef - 
//
// Returns:
//     ValueTable:
//         * MetaFullName           - String - a full name of metadata that needs the number calculated.
//         * ExchangeNode              - ExchangePlanRef - a reference to an exchange node for which the count is calculated.
//         * ChangeCount     - Number - contains the overall count of changes.
//         * ExportedCount   - Number - contains the number of exported changes.
//         * NotExportedCount - Number - contains the number of not exported changes.
//
Function GetChangeCount(TablesList, NodesList) Export
	
	Result = New ValueTable;
	Columns = Result.Columns;
	Columns.Add("MetaFullName");
	Columns.Add("ExchangeNode");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	
	Result.Indexes.Add("MetaFullName");
	Result.Indexes.Add("ExchangeNode");
	
	Query = New Query;
	Query.SetParameter("NodesList", NodesList);
	
	// TableList can contain an array, structure, or map that contains multiple arrays.
	If TablesList = Undefined Then
		Return Result;
	ElsIf TypeOf(TablesList) = Type("Array") Then
		Source = New Structure("_", TablesList);
	Else
		Source = TablesList;
	EndIf;
	
	QueryTextTemplate2 = 
	"SELECT
	|	""&MetadataTableView"" AS MetaFullName,
	|	MetadataTableName.Node AS ExchangeNode,
	|	COUNT(*) AS ChangeCount,
	|	COUNT(MetadataTableName.MessageNo) AS ExportedCount,
	|	COUNT(*) - COUNT(MetadataTableName.MessageNo) AS NotExportedCount
	|FROM
	|	Catalog.DataExchangeScenarios.Changes AS MetadataTableName
	|WHERE
	|	MetadataTableName.Node IN (&NodesList)
	|GROUP BY
	|	MetadataTableName.Node";
	
	// Reading data in portions, each portion contains 200 tables processed in a query.
	Text = "";
	Number = 0;
	For Each KeyValue In Source Do
		If TypeOf(KeyValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		For Each Item In KeyValue.Value Do
			If IsBlankString(Item) Then
				Continue;
			EndIf;
			
			If Not AccessRight("Read", Metadata.FindByFullName(Item)) Then
				Continue;
			EndIf;
			
			SubqueryText = StrReplace(QueryTextTemplate2, "&MetadataTableView", TrimAll(Item));
			SubqueryText = StrReplace(SubqueryText, "Catalog.DataExchangeScenarios", TrimAll(Item));
			
			If IsBlankString(Text) Then
				
				Text = SubqueryText;
				
			Else
				
				Text = Text + Chars.LF + "UNION ALL" + Chars.LF + SubqueryText;
			
			EndIf;
			
			Number = Number + 1;
			If Number = 200	Then
				Query.Text = Text;
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					FillPropertyValues(Result.Add(), Selection);
				EndDo;
				Text = "";
				Number = 0;
			EndIf;
			
		EndDo;
	EndDo;
	
	// Read what is unread.
	If Text <> "" Then
		Query.Text = Text;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			FillPropertyValues(Result.Add(), Selection);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Returns a metadata object by full name. An empty string means the whole configuration.
//
// Parameters:
//    NameOfMetadataObjects - String - a metadata object name, for example, "Catalog.Currencies" or "Constants".
//
// Returns:
//    MetadataObject - 
//
Function MetadataByFullName(NameOfMetadataObjects) Export
	
	If IsBlankString(NameOfMetadataObjects) Then
		// 
		Return Metadata;
	EndIf;
		
	Value = Metadata.FindByFullName(NameOfMetadataObjects);
	If Value = Undefined Then
		Value = Metadata[NameOfMetadataObjects];
	EndIf;
	
	Return Value;
EndFunction

// Returns the object registration flag on the node.
//
// Parameters:
//    Node              - ExchangePlanRef - an exchange plan node for which we receive information, 
//    RegistrationObject - String
//                      - AnyRef
//                      - Structure - 
//                        
//    TableName        - String - if RegistrationObject is a structure, then contains a table name for dimensions set.
//
// Returns:
//    Boolean - 
//
Function ObjectRegisteredForNode(Node, RegistrationObject, TableName = Undefined) Export
	ParameterType = TypeOf(RegistrationObject);
	If ParameterType = Type("String") Then
		// Constant as metadata.
		LongDesc = MetadataCharacteristics(RegistrationObject);
		CurrentObject = LongDesc.Manager.CreateValueManager();
		
	ElsIf ParameterType = Type("Structure") Then
		// Набор измерений, ИмяТаблицы - 
		LongDesc = MetadataCharacteristics(TableName);
		CurrentObject = LongDesc.Manager.CreateRecordSet();
		For Each KeyValue In RegistrationObject Do
			SetFilterItemValue(CurrentObject.Filter, KeyValue.Key, KeyValue.Value);
		EndDo;
		
	Else
		CurrentObject = RegistrationObject;
	EndIf;
	
	Return ExchangePlans.IsChangeRecorded(Node, CurrentObject);
EndFunction

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AdditionalReportsAndDataProcessors

// Returns data about an external data processor.
//
// Returns:
//   See AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo
//
Function ExternalDataProcessorInfo() Export
	
	Info = New Structure;
	
	Info.Insert("Kind",             "RelatedObjectsCreation");
	Info.Insert("Commands",         New ValueTable);
	Info.Insert("SafeMode", True);
	Info.Insert("Purpose",      New Array);
	
	Info.Insert("Description", NStr("en = 'Data registration manager';"));
	Info.Insert("Version",       "1.0");
	Info.Insert("SSLVersion",    "1.2.1.4");
	Info.Insert("Information",    NStr("en = 'The data processor is intended for managing registration of objects at exchange nodes before exporting data. When used in configurations with SSL version 2.1.2.0 or later, it manages data migration restrictions.';"));
	
	Info.Purpose.Add("ExchangePlans.*");
	Info.Purpose.Add("Constants.*");
	Info.Purpose.Add("Catalogs.*");
	Info.Purpose.Add("Documents.*");
	Info.Purpose.Add("Sequences.*");
	Info.Purpose.Add("ChartsOfCharacteristicTypes.*");
	Info.Purpose.Add("ChartsOfAccounts.*");
	Info.Purpose.Add("ChartsOfCalculationTypes.*");
	Info.Purpose.Add("InformationRegisters.*");
	Info.Purpose.Add("AccumulationRegisters.*");
	Info.Purpose.Add("AccountingRegisters.*");
	Info.Purpose.Add("CalculationRegisters.*");
	Info.Purpose.Add("BusinessProcesses.*");
	Info.Purpose.Add("Tasks.*");
	
	Columns = Info.Commands.Columns;
	StringType = New TypeDescription("String");
	Columns.Add("Presentation", StringType);
	Columns.Add("Id", StringType);
	Columns.Add("Use", StringType);
	Columns.Add("Modifier",   StringType);
	Columns.Add("ShouldShowUserNotification", New TypeDescription("Boolean"));
	
	// The only command. Determine what to do by type of the passed item.
	Command = Info.Commands.Add();
	Command.Presentation = NStr("en = 'Change item registration state';");
	Command.Id = "OpenRegistrationEditingForm";
	Command.Use = "ClientMethodCall";
	
	Return Info;
EndFunction

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region Private

// Runs registration change according to the passed parameters.
// Parameters:
//     JobParameters - Structure - parameters to change registration:
//         * Command                 - Boolean - True if you need to add, False if you need to delete.
//         * NoAutoRegistration - Boolean - True if you do not need to analyze the autorecord flag.
//         * Node                    - ExchangePlanRef - a reference to the exchange plan node.
//         * Data                  - AnyRef
//                                   - String
//                                   - Structure - 
//         * TableName              - String - if Data is a structure, then contains a table name.
//     StorageAddress - Arbitrary - temporary storage address to save the result on start in a background job.
//
// Returns: 
//     Structure:
//         * Total   - Number - a total object count.
//         * Success - Number - a number of objects that are processed.
//         * Command - 
//
Function ChangeRegistration(JobParameters, StorageAddress = Undefined) Export
	TableName = Undefined;
	JobParameters.Property("TableName", TableName);
	
	ConfigurationSupportsSSL       = JobParameters.ConfigurationSupportsSSL;
	RegisterWithSSLMethodsAvailable  = JobParameters.RegisterWithSSLMethodsAvailable;
	DIBModeAvailable                 = JobParameters.DIBModeAvailable;
	ObjectExportControlSetting = JobParameters.ObjectExportControlSetting;
	BatchRegistrationIsAvailable       = JobParameters.BatchRegistrationIsAvailable;
	
	ExecutionResult = EditRegistrationAtServer(JobParameters.Command, JobParameters.NoAutoRegistration, 
		JobParameters.Node, JobParameters.Data, TableName, JobParameters.MetadataNamesStructure);
		
	If StorageAddress <> Undefined Then
		PutToTempStorage(ExecutionResult, StorageAddress);
	EndIf;
	
	Return ExecutionResult;
EndFunction

// Returns the beginning of the full form name to open by the passed object.
//
// Parameters:
//    CurrentObject - String, DynamicList - whose form name is required. 
// Returns:
//    String - full name of the form.
//
Function GetFormName(CurrentObject = Undefined) Export
	
	Type = TypeOf(CurrentObject);
	If Type = Type("DynamicList") Then
		Return CurrentObject.MainTable + ".";
	ElsIf Type = Type("String") Then
		Return CurrentObject + ".";
	EndIf;
	
	Meta = ?(CurrentObject = Undefined, Metadata(), CurrentObject.Metadata());
	Return Meta.FullName() + ".";
EndFunction	

// Recursive update of hierarchy marks, which can have 3 states, in a tree row. 
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure ChangeMark(RowData) Export
	RowData.Check = RowData.Check % 2;
	SetMarksDown(RowData);
	SetMarksUp(RowData);
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row. 
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure SetMarksDown(RowData) Export
	Value = RowData.Check;
	For Each Child In RowData.GetItems() Do
		Child.Check = Value;
		SetMarksDown(Child);
	EndDo;
EndProcedure

// Recursive update of hierarchy marks, which can have 3 states, in a tree row. 
//
// Parameters:
//    RowData - FormDataTreeItem - a mark is stored in the Mark numeric column.
//
Procedure SetMarksUp(RowData) Export
	RowParent = RowData.GetParent();
	If RowParent <> Undefined Then
		AllTrue = True;
		NotAllFalse = False;
		For Each Child In RowParent.GetItems() Do
			AllTrue = AllTrue And (Child.Check = 1);
			NotAllFalse = NotAllFalse Or Boolean(Child.Check);
		EndDo;
		If AllTrue Then
			RowParent.Check = 1;
		ElsIf NotAllFalse Then
			RowParent.Check = 2;
		Else
			RowParent.Check = 0;
		EndIf;
		SetMarksUp(RowParent);
	EndIf;
EndProcedure

// Exchange node attribute reading.
//
// Parameters:
//    Ref - ExchangePlanRef - a reference to the exchange node.
//    Data - String - a list of attribute names to read, separated by commas.
//
// Returns:
//    Structure    - 
//
Function GetExchangeNodeParameters(Ref, Data) Export
	
	Result = New Structure(Data);
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = 
	"SELECT
	|	&AttributesNames
	|FROM
	|	&MetadataTableName AS MetadataTableName
	|WHERE
	|	MetadataTableName.Ref = &Ref";
	
	Query.Text = StrReplace(Query.Text, "&AttributesNames", Data);
	
	ExchangePlanName = Ref.Metadata().Name;
	Query.Text = StrReplace(Query.Text, "&MetadataTableName", SubstituteParametersToString("ExchangePlan.%1", ExchangePlanName));

	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
	
EndFunction

// Exchange node attribute writing.
//
// Parameters:
//    Ref - ExchangePlanRef - a reference to the exchange node.
//    Data - Structure - contains node attribute values.
//
Procedure SetExchangeNodeParameters(Ref, Data) Export
	
	NodeObject = Ref.GetObject();
	If NodeObject = Undefined Then
		// 
		Return;
	EndIf;
	
	NodeMetadata = NodeObject.Metadata();
	
	BeginTransaction();
	Try
	    Block = New DataLock;
	    LockItem = Block.Add(NodeMetadata.FullName());
	    LockItem.SetValue("Ref", Ref);
	    Block.Lock();
	    
		LockDataForEdit(Ref);
		NodeObject = Ref.GetObject();
		
		Changed = False;
		For Each Item In Data Do
			If NodeObject[Item.Key] = Item.Value Then
				Continue;
			EndIf;
			
			NodeObject[Item.Key] = Item.Value;
			Changed = True;
		EndDo;
		
		If Changed Then
			NodeObject.DataExchange.Load = True;
			NodeObject.Write();
		EndIf;

	    CommitTransaction();
	Except
	    RollbackTransaction();
	    Raise;
	EndTry;
	
EndProcedure

// Returns data details by the full table name/full metadata name or metadata.
//
// Parameters:
//   MetadataTableName - String - table name, for example "Catalog.Currencies".
//
// Returns:
//    Structure - 
//      * IsSequence - Boolean - a sequence flag.
//      * IsCollection - Boolean - a value collection flag.
//      * IsConstant - Boolean - a constant flag.
//      * IsReference - Boolean - a flag indicating a reference data type.
//      * IsRecordsSet - Boolean - a flag indicating a register record set
//      * Manager - CatalogManager, DocumentManager, и т.п. - table value manager.
//      * TableName - String - table name.
//
Function MetadataCharacteristics(MetadataTableName) Export
	
	IsSequence = False;
	IsCollection          = False;
	IsConstant          = False;
	IsReference             = False;
	IsRecordsSet              = False;
	Manager              = Undefined;
	TableName            = "";
	
	If TypeOf(MetadataTableName) = Type("String") Then
		Meta = MetadataByFullName(MetadataTableName);
		TableName = MetadataTableName;
	ElsIf TypeOf(MetadataTableName) = Type("Type") Then
		Meta = Metadata.FindByType(MetadataTableName);
		TableName = Meta.FullName();
	Else
		Meta = MetadataTableName;
		TableName = Meta.FullName();
	EndIf;
	
	If Meta = Metadata.Constants Then
		IsCollection = True;
		IsConstant = True;
		Manager     = Constants;
		
	ElsIf Meta = Metadata.Catalogs Then
		IsCollection = True;
		IsReference    = True;
		Manager      = Catalogs;
		
	ElsIf Meta = Metadata.Documents Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Documents;
		
	ElsIf Meta = Metadata.Enums Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Enums;
		
	ElsIf Meta = Metadata.ChartsOfCharacteristicTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCharacteristicTypes;
		
	ElsIf Meta = Metadata.ChartsOfAccounts Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfAccounts;
		
	ElsIf Meta = Metadata.ChartsOfCalculationTypes Then
		IsCollection = True;
		IsReference    = True;
		Manager     = ChartsOfCalculationTypes;
		
	ElsIf Meta = Metadata.BusinessProcesses Then
		IsCollection = True;
		IsReference    = True;
		Manager     = BusinessProcesses;
		
	ElsIf Meta = Metadata.Tasks Then
		IsCollection = True;
		IsReference    = True;
		Manager     = Tasks;
		
	ElsIf Meta = Metadata.Sequences Then
		IsRecordsSet              = True;
		IsSequence = True;
		IsCollection          = True;
		Manager              = Sequences;
		
	ElsIf Meta = Metadata.InformationRegisters Then
		IsCollection = True;
		IsRecordsSet     = True;
		Manager 	 = InformationRegisters;
		
	ElsIf Meta = Metadata.AccumulationRegisters Then
		IsCollection = True;
		IsRecordsSet     = True;
		Manager     = AccumulationRegisters;
		
	ElsIf Meta = Metadata.AccountingRegisters Then
		IsCollection = True;
		IsRecordsSet     = True;
		Manager     = AccountingRegisters;
		
	ElsIf Meta = Metadata.CalculationRegisters Then
		IsCollection = True;
		IsRecordsSet     = True;
		Manager     = CalculationRegisters;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		IsConstant = True;
		Manager     = Constants[Meta.Name];
		
	ElsIf Metadata.Catalogs.Contains(Meta) Then
		IsReference = True;
		Manager  = Catalogs[Meta.Name];
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		IsReference = True;
		Manager  = Documents[Meta.Name];
		
	ElsIf Metadata.Sequences.Contains(Meta) Then
		IsRecordsSet              = True;
		IsSequence = True;
		Manager              = Sequences[Meta.Name];
		
	ElsIf Metadata.Enums.Contains(Meta) Then
		IsReference = True;
		Manager  = Enums[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		IsReference = True;
		Manager = ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		IsReference = True;
		Manager  = ChartsOfCalculationTypes[Meta.Name];
		
	ElsIf Metadata.InformationRegisters.Contains(Meta) Then
		IsRecordsSet = True;
		Manager = InformationRegisters[Meta.Name];
		
	ElsIf Metadata.AccumulationRegisters.Contains(Meta) Then
		IsRecordsSet = True;
		Manager = AccumulationRegisters[Meta.Name];
		
	ElsIf Metadata.AccountingRegisters.Contains(Meta) Then
		IsRecordsSet = True;
		Manager = AccountingRegisters[Meta.Name];
		
	ElsIf Metadata.CalculationRegisters.Contains(Meta) Then
		IsRecordsSet = True;
		Manager = CalculationRegisters[Meta.Name];
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		IsReference = True;
		Manager = BusinessProcesses[Meta.Name];
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		IsReference = True;
		Manager = Tasks[Meta.Name];
		
	Else
		MetaParent = Meta.Parent();
		If MetaParent <> Undefined And Metadata.CalculationRegisters.Contains(MetaParent) Then
			// Перерасчет
			IsRecordsSet = True;
			Manager = CalculationRegisters[MetaParent.Name].Recalculations[Meta.Name];
		EndIf;
		
	EndIf;
	Result = New Structure();
	Result.Insert("TableName", TableName);
	Result.Insert("Metadata", Meta);
	Result.Insert("Manager", Manager);
	Result.Insert("IsRecordsSet", IsRecordsSet);
	Result.Insert("IsReference", IsReference);
	Result.Insert("IsConstant", IsConstant);
	Result.Insert("IsSequence", IsSequence);
	Result.Insert("IsCollection", IsCollection);
	Return Result;
	
EndFunction

// Returns a table describing dimensions for data set change record.
//
// Parameters:
//    TableName   - String - table name, for example "InformationRegister.ExchangeRates".
//    AllDimensions - Boolean - a flag showing whether all dimensions 
//                            are got for the information register, not just basic and master dimensions.
//
// Returns:
//    ValueTable:
//         * Name         - String - a dimension name.
//         * ValueType - TypeDescription - types.
//         * Title   - String - dimension presentation.
//
Function RecordSetDimensions(TableName, AllDimensions = False) Export
	
	If TypeOf(TableName) = Type("String") Then
		Meta = MetadataByFullName(TableName);
	Else
		Meta = TableName;
	EndIf;
	
	// Specify key fields.
	Dimensions = New ValueTable;
	Columns = Dimensions.Columns;
	Columns.Add("Name");
	Columns.Add("ValueType");
	Columns.Add("Title");
	
	If Not AllDimensions Then
		// Data be register.
		NotConsider = "#MessageNo#Node#";
		For Each MetaCommon In Metadata.CommonAttributes Do
			NotConsider = NotConsider + "#" + MetaCommon.Name + "#" ;
		EndDo;
		
		QueryTextTemplate2 = 
		"SELECT
		|	*
		|FROM
		|	&MetadataTableName AS MetadataTableName
		|WHERE
		|	FALSE";
		
		MetadataTableName = Meta.FullName() + ".Changes";
		QueryText = StrReplace(QueryTextTemplate2, "&MetadataTableName", MetadataTableName);
		
		Query = New Query(QueryText);
		EmptyResult = Query.Execute();
		For Each ResultColumn In EmptyResult.Columns Do
			ColumnName = ResultColumn.Name;
			If StrFind(NotConsider, "#" + ColumnName + "#") = 0 Then
				String = Dimensions.Add();
				String.Name         = ColumnName;
				String.ValueType = ResultColumn.ValueType;
				
				MetaDimension = Meta.Dimensions.Find(ColumnName);
				String.Title = ?(MetaDimension = Undefined, ColumnName, MetaDimension.Presentation());
			EndIf;
		EndDo;
		
		Return Dimensions;
		
	EndIf;
	
	// All dimensions.
	
	IsInformationRegister = Metadata.InformationRegisters.Contains(Meta);
	
	// Recorder
	If Metadata.AccumulationRegisters.Contains(Meta)
	 Or Metadata.AccountingRegisters.Contains(Meta)
	 Or Metadata.CalculationRegisters.Contains(Meta)
	 Or (IsInformationRegister And Meta.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate)
	 Or Metadata.Sequences.Contains(Meta) Then
		String = Dimensions.Add();
		String.Name         = "Recorder";
		String.ValueType = Documents.AllRefsType();
		String.Title   = NStr("en = 'Recorder';");
	EndIf;
	
	// Period
	If IsInformationRegister And Meta.MainFilterOnPeriod Then
		String = Dimensions.Add();
		String.Name         = "Period";
		String.ValueType = New TypeDescription("Date");
		String.Title   = NStr("en = 'Period';");
	EndIf;
	
	// Dimensions
	If IsInformationRegister Then
		For Each MetaDimension In Meta.Dimensions Do
			String = Dimensions.Add();
			String.Name         = MetaDimension.Name;
			String.ValueType = MetaDimension.Type;
			String.Title   = MetaDimension.Presentation();
		EndDo;
	EndIf;
	
	// Recalculate.
	If Metadata.CalculationRegisters.Contains(Meta.Parent()) Then
		String = Dimensions.Add();
		String.Name         = "RecalculationObject";
		String.ValueType = Documents.AllRefsType();
		String.Title   = NStr("en = 'Recalculation object';");
	EndIf;
	
	Return Dimensions;
EndFunction

// Adds columns to the FormTable.
//
// Parameters:
//    FormTable   - ЭлементФормы - an item linked to an attribute. The data columns are added to this attribute.
//    SaveNames - String - a list of column names, separated by commas.
//    Add      - Array - contains structures that describe columns to be added (Name, ValueType, Title).
//    ColumnGroup  - ЭлементФормы - a column group where the columns are added.
//
Procedure AddColumnsToFormTable(FormTable, SaveNames, Add, ColumnGroup = Undefined) Export
	
	Form = FormItemForm(FormTable);
	FormItems = Form.Items;
	TableAttributeName = FormTable.DataPath;
	
	ToSave = New Structure(SaveNames);
	DataPathsToSave = New Map;
	For Each Item In ToSave Do
		DataPathsToSave.Insert(TableAttributeName + "." + Item.Key, True);
	EndDo;
	
	IsDynamicList = False;
	For Each Attribute In Form.GetAttributes() Do
		If Attribute.Name = TableAttributeName And Attribute.ValueType.ContainsType(Type("DynamicList")) Then
			IsDynamicList = True;
			Break;
		EndIf;
	EndDo;

	// If TableForm is not a dynamic list.
	If Not IsDynamicList Then
		NamesToDelete = New Array;
		
		// Deleting attributes that are not included in SaveNames.
		For Each Attribute In Form.GetAttributes(TableAttributeName) Do
			CurName = Attribute.Name;
			If Not ToSave.Property(CurName) Then
				NamesToDelete.Add(Attribute.Path + "." + CurName);
			EndIf;
		EndDo;
		
		ItemsToAdd = New Array;
		For Each Column In Add Do
			CurName = Column.Name;
			If Not ToSave.Property(CurName) Then
				ItemsToAdd.Add( New FormAttribute(CurName, Column.ValueType, TableAttributeName, Column.Title) );
			EndIf;
		EndDo;
		
		Form.ChangeAttributes(ItemsToAdd, NamesToDelete);
	EndIf;
	
	// Delete items.
	Parent = ?(ColumnGroup = Undefined, FormTable, ColumnGroup);
	
	ShouldDelete = New Array;
	For Each Item In Parent.ChildItems Do
		ShouldDelete.Add(Item);
	EndDo;
	For Each Item In ShouldDelete Do
		If TypeOf(Item) <> Type("FormGroup") And DataPathsToSave[Item.DataPath] = Undefined Then
			FormItems.Delete(Item);
		EndIf;
	EndDo;
	
	// Create items.
	Prefix = FormTable.Name;
	For Each Column In Add Do
		CurName = Column.Name;
		FormItem = FormItems.Insert(Prefix + CurName, Type("FormField"), Parent); // FormField
		FormItem.Type = FormFieldType.InputField;
		FormItem.DataPath = TableAttributeName + "." + CurName;
		FormItem.Title = Column.Title;
	EndDo;
	
EndProcedure	

// Returns a detailed object presentation.
//
// Parameters:
//    - 
//
// Returns:
//      String - representation of objects.
//
Function RepresentationOfTheReference(ObjectToGetPresentation) Export
	
	If TypeOf(ObjectToGetPresentation) = Type("String") Then
		// Metadata. 
		Meta = Metadata.FindByFullName(ObjectToGetPresentation);
		Result = Meta.Presentation();
		If Metadata.Constants.Contains(Meta) Then
			Result = Result + " (constant)";
		EndIf;
		Return Result;
	EndIf;
	
	// Ссылка
	Result = "";
	ModuleCommon = CommonModuleCommonUse();
	If ModuleCommon <> Undefined Then
		Result = ModuleCommon.SubjectString(ObjectToGetPresentation);
	EndIf;
	
	If IsBlankString(Result) And ObjectToGetPresentation <> Undefined And Not ObjectToGetPresentation.IsEmpty() Then
		Meta = ObjectToGetPresentation.Metadata();
		If Metadata.Documents.Contains(Meta) Then
			Result = String(ObjectToGetPresentation);
		Else
			Presentation = Meta.ObjectPresentation;
			If IsBlankString(Presentation) Then
				Presentation = Meta.Presentation();
			EndIf;
			Result = String(ObjectToGetPresentation);
			If Not IsBlankString(Presentation) Then
				Result = Result + " (" + Presentation + ")";
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(Result) Then
		Result = NStr("en = 'not specified';");
	EndIf;
	
	Return Result;
EndFunction

// Returns a flag specifying whether the infobase runs in file mode.
// Returns:
//       Boolean - 
//
Function IsFileInfobase() Export
	Return StrFind(InfoBaseConnectionString(), "File=") > 0;
EndFunction

//  Reads current data from the dynamic list by its setting and returns it as a values table.
//
// Parameters:
//   DataSource - DynamicList - form attribute.
//
// Returns:
//   ValueTable - 
//
Function DynamicListCurrentData(DataSource) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	Set = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = DataSource.QueryText;
	Set.AutoFillAvailableFields = True;
	Set.DataSource = Source.Name;
	Set.Name = Source.Name;
	
	SettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(SettingsSource);
	
	CurSettings = Composer.Settings;
	
	// Selected fields.
	For Each Item In CurSettings.Selection.SelectionAvailableFields.Items Do
		If Not Item.Folder Then
			Field = CurSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			Field.Use = True;
			Field.Field = Item.Field;
		EndIf;
	EndDo;
	Group = CurSettings.Structure.Add(Type("DataCompositionGroup"));
	Group.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));

	// Filter.
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.Filter);
	CopyDataCompositionFilter(CurSettings.Filter, DataSource.SettingsComposer.GetSettings().Filter);

	// Display.
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionSchema, CurSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template);
	Output  = New DataCompositionResultValueCollectionOutputProcessor;
	
	Result = New ValueTable;
	Output.SetObject(Result); 
	Output.Output(Processor);
	
	Return Result;
EndFunction

// Reading settings from the common storage.
// Parameters:
//      SettingsKey - String - a key for reading settings.
//
Procedure ReadSettings(SettingsKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = CommonSettingsStorage.Load(ObjectKey);
	If TypeOf(CurrentSettings) <> Type("Map") Then
		// Умолчания
		CurrentSettings = New Map;
		CurrentSettings.Insert("RegisterRecordAutoRecordSetting",            False);
		CurrentSettings.Insert("SequenceAutoRecordSetting", False);
		CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting",      "");
		CurrentSettings.Insert("ObjectExportControlSetting",           True); // 
		CurrentSettings.Insert("MessageNumberOptionSetting",              0);     // 
	EndIf;
	
	RegisterRecordAutoRecordSetting            = CurrentSettings["RegisterRecordAutoRecordSetting"];
	SequenceAutoRecordSetting = CurrentSettings["SequenceAutoRecordSetting"];
	QueryExternalDataProcessorAddressSetting      = CurrentSettings["QueryExternalDataProcessorAddressSetting"];
	ObjectExportControlSetting           = CurrentSettings["ObjectExportControlSetting"];
	MessageNumberOptionSetting             = CurrentSettings["MessageNumberOptionSetting"];

	CheckSettingsCorrectness(SettingsKey);
EndProcedure

// Setting SSL support flags.
//
Procedure ReadSSLSupportFlags() Export
	ConfigurationSupportsSSL = SSLRequiredVersionAvailable();
	
	If ConfigurationSupportsSSL Then
		// Performing registration with an external registration interface.
		RegisterWithSSLMethodsAvailable = SSLRequiredVersionAvailable("2.1.5.11");
		DIBModeAvailable                = SSLRequiredVersionAvailable("2.1.3.25");
		AsynchronousRegistrationAvailable    = SSLRequiredVersionAvailable("2.3.5.34");
	Else
		RegisterWithSSLMethodsAvailable = False;
		DIBModeAvailable                = False;
		AsynchronousRegistrationAvailable    = False;
	EndIf;
EndProcedure

Procedure ReadSignsOfBSDSupport() Export
	
	BatchRegistrationIsAvailable = DSL_RequiredVersionIsAvailable("1.0.3.1"); 
	
EndProcedure

// Writing settings to the common storage.
//
// Parameters:
//      SettingsKey - String - a key for saving settings.
//
Procedure ShouldSaveSettings(SettingsKey = "") Export
	
	ObjectKey = Metadata().FullName() + ".Form.Form";
	
	CurrentSettings = New Map;
	CurrentSettings.Insert("RegisterRecordAutoRecordSetting",            RegisterRecordAutoRecordSetting);
	CurrentSettings.Insert("SequenceAutoRecordSetting", SequenceAutoRecordSetting);
	CurrentSettings.Insert("QueryExternalDataProcessorAddressSetting",      QueryExternalDataProcessorAddressSetting);
	CurrentSettings.Insert("ObjectExportControlSetting",           ObjectExportControlSetting);
	CurrentSettings.Insert("MessageNumberOptionSetting",             MessageNumberOptionSetting);
	
	CommonSettingsStorage.Save(ObjectKey, "", CurrentSettings)
EndProcedure	

// Checking settings. Incorrect settings are reset.
//
// Parameters:
//      SettingsKey - String - a key of setting to check.
// Returns:
//     Structure - 
//                 
//
Function CheckSettingsCorrectness(SettingsKey = "") Export
	
	Result = New Structure("HasErrors,
		|RegisterRecordAutoRecordSetting, SequenceAutoRecordSetting, 
		|QueryExternalDataProcessorAddressSetting, ObjectExportControlSetting,
		|MessageNumberOptionSetting",
		False);
		
	// Checking whether an external data processor is available.
	If IsBlankString(QueryExternalDataProcessorAddressSetting) Then
		// Setting an empty string value to the QueryExternalDataProcessorAddressSetting.
		QueryExternalDataProcessorAddressSetting = "";
		
	ElsIf Lower(Right(TrimAll(QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		// Setting an empty string value to the QueryExternalDataProcessorAddressSetting.
		QueryExternalDataProcessorAddressSetting = "";
			
	Else
		// Use built-in console
		If Metadata.DataProcessors.Find(QueryExternalDataProcessorAddressSetting) = Undefined Then
			Text = NStr("en = 'Data processor %1is not found in the configuration';");
			Result.QueryExternalDataProcessorAddressSetting = StrReplace(Text, "%1", QueryExternalDataProcessorAddressSetting);
			
			Result.HasErrors = True;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Changes registration for a passed object.
//
// Parameters:
//     Command                 - Boolean - True if you need to add, False if you need to delete.
//     NoAutoRegistration - Boolean - True if you do not need to analyze the autorecord flag.
//     Node                    - ExchangePlanRef - a reference to the exchange plan node.
//     Data                  - AnyRef
//                             - String
//                             - Structure - 
//     TableName              - String - if Data is a structure, then contains a table name.
//
// Returns: 
//     Structure:
//         * Total   - Number - a total object count.
//         * Success - Number - a number of objects that are processed.
//         * Command - 
//
Function EditRegistrationAtServer(Command, NoAutoRegistration, Node, Data, TableName = Undefined, MetadataNamesStructure = Undefined) Export
	
	ReadSettings();
	Result = New Structure("Total, Success", 0, 0);
	
	// This flag is required only when adding registration results to the Result structure. The flag value can be True only if the configuration supports SSL.
	SSLFilterRequired = TypeOf(Command) = Type("Boolean") And Command And ConfigurationSupportsSSL And ObjectExportControlSetting;
	
	If TypeOf(Data) = Type("Array") Then
		
		RegistrationDetails = New Array;
			
		ThisIsRegistrationByFilter = False;
		
		If Command
			And ValueIsFilled(TableName)
			And BatchRegistrationIsAvailable Then
		
			LongDesc = MetadataCharacteristics(TableName);
			ThisIsRegistrationByFilter = LongDesc.IsReference;
			
		EndIf;
			
		If ThisIsRegistrationByFilter Then
			
			ModuleDataExchangeEvents = CommonModuleEventDataExchange();
			
			PDParameters = ModuleDataExchangeEvents.BatchRegistrationParameters();
			
			ReferencesArrray = New Array;
			For Each ArrayElement In Data Do
				ReferencesArrray.Add(ArrayElement.Ref);
			EndDo;
			
			ModuleDataExchangeEvents.PerformBatchRegistrationForNode(Node, ReferencesArrray, PDParameters);
			
			For Each Ref In PDParameters.LinksToBatchRegistrationFilter Do
				Result.Total = Result.Total + 1;
				Result.Success = Result.Success + 1;
				ExchangePlans.RecordChanges(Node, Ref);
			EndDo;
			
			If PDParameters.ThereIsPRO_WithoutBatchRegistration Then
				For Each Ref In PDParameters.LinksNotByBatchRegistrationFilter Do
					StructureOfData = New Structure("Ref", Ref);
					RegistrationDetails.Add(StructureOfData);
				EndDo;
			EndIf;
			
		Else
		
			RegistrationDetails = Data;
		
		EndIf;
		
	Else
		RegistrationDetails = New Array;
		RegistrationDetails.Add(Data);
	EndIf;
	
	For Each Item In RegistrationDetails Do
		
		Type = TypeOf(Item);
		Values = New Array;
		
		If Item = Undefined Then
			// Entire configuration.
			
			If TypeOf(Command) = Type("Boolean") And Command Then
				// Adding registration in parts.
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Constants", TableName, MetadataNamesStructure));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Catalogs", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Documents", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Sequences", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfCharacteristicTypes", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfAccounts", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "ChartsOfCalculationTypes", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "InformationRegisters", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "AccumulationRegisters", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "AccountingRegisters", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "CalculationRegisters", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "BusinessProcesses", TableName));
				AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, "Tasks", TableName));
				Continue;
			EndIf;
			
			// Удаление регистрации - 
			Values.Add(Undefined);
			
		ElsIf Type = Type("String") Then
			// 
			LongDesc = MetadataCharacteristics(Item);
			If SSLFilterRequired Then
				AddResults(Result, SSLMetadataChangesRegistration(Node, LongDesc, NoAutoRegistration, MetadataNamesStructure));
				Continue;
				
			ElsIf NoAutoRegistration Then
				If LongDesc.IsCollection Then
					For Each Meta In LongDesc.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = LongDesc.Metadata;
					CompositionItem = Node.Metadata().Content.Find(Meta);
					If CompositionItem = Undefined Then
						Continue;
					EndIf;
					// Константа?
					Values.Add(LongDesc.Metadata);
				EndIf;
				
			Else
				// Excluding inappropriate objects.
				If LongDesc.IsCollection Then
					// Register metadata objects one-by-one.
					For Each Meta In LongDesc.Metadata Do
						AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, Meta.FullName(), TableName) );
					EndDo;
					Continue;
				Else
					Meta = LongDesc.Metadata;
					CompositionItem = Node.Metadata().Content.Find(Meta);
					If CompositionItem = Undefined Or CompositionItem.AutoRecord <> AutoChangeRecord.Allow Then
						Continue;
					EndIf;
					// Константа?
					Values.Add(LongDesc.Metadata);
				EndIf;
			EndIf;
			
			// Adding additional registration objects, Values[0] - specific metadata with the Item name.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration) Do
				Values.Add(CurItem);
			EndDo;
			
		ElsIf Type = Type("Structure") Then
			// 
			LongDesc = MetadataCharacteristics(TableName);
			If LongDesc.IsReference Then
				ItemRef1 = Undefined;
				If Item.Property("Ref", ItemRef1) Then
					AddResults(Result, EditRegistrationAtServer(Command, NoAutoRegistration, Node, ItemRef1));
				EndIf;
				Continue;
			EndIf;
			// Specific record set is passed, auto record settings do not matter.
			If SSLFilterRequired Then
				AddResults(Result, SSLSetChangesRegistration(Node, Item, LongDesc) );
				Continue;
			EndIf;
			
			Set = LongDesc.Manager.CreateRecordSet();
			For Each KeyValue In Item Do
				SetFilterItemValue(Set.Filter, KeyValue.Key, KeyValue.Value);
			EndDo;
			
			For Each Filter In Set.Filter Do
				If Not Filter.Use Then
					Filter.Use = True;
				EndIf;
			EndDo;
			
			Values.Add(Set);
			// Add additional registration objects.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration, TableName) Do
				Values.Add(CurItem);
			EndDo;
			
		Else
			// Specific reference is passed, auto record settings do not matter.
			If SSLFilterRequired Then
				AddResults(Result, SSLRefChangesRegistration(Node, Item) );
				Continue;
				
			EndIf;
			Values.Add(Item);
			// Add additional registration objects.
			For Each CurItem In GetAdditionalRegistrationObjects(Item, Node, NoAutoRegistration) Do
				Values.Add(CurItem);
			EndDo;
			
		EndIf;
		
		// 
		For Each CurValue In Values Do
			ExecuteObjectRegistrationCommand(Command, Node, CurValue);
			Result.Success = Result.Success + 1;
			Result.Total   = Result.Total   + 1;
		EndDo;
		
	EndDo; // 
	Result.Insert("Command", Command);
	Return Result;
EndFunction

// Copies data composition filter to existing data.
//
Procedure CopyDataCompositionFilter(DestinationGroup1, SourceGroup) 
	
	SourceCollection = SourceGroup.Items;
	DestinationCollection = DestinationGroup1.Items;
	For Each Item In SourceCollection Do
		ElementType  = TypeOf(Item);
		NewItem = DestinationCollection.Add(ElementType);
		
		FillPropertyValues(NewItem, Item);
		If ElementType = Type("DataCompositionFilterItemGroup") Then
			CopyDataCompositionFilter(NewItem, Item) 
		EndIf;
		
	EndDo;
	
EndProcedure

// Performs direct action with the target object.
//
Procedure ExecuteObjectRegistrationCommand(Val Command, Val Node, Val RegistrationObject)
	
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			// Register.
			If MessageNumberOptionSetting = 1 Then
				// 
				Command = 1 + Node.SentNo;
			Else
				// Register an object as a new one.
				RecordChanges(Node, RegistrationObject);
			EndIf;
		Else
			// 
			ExchangePlans.DeleteChangeRecords(Node, RegistrationObject);
		EndIf;
	EndIf;
	
	If TypeOf(Command) = Type("Number") Then
		// A single registration with a specified message number.
		If Command = 0 Then
			// Similarly if a new object is being registered.
			RecordChanges(Node, RegistrationObject)
		Else
			// 
			ExchangePlans.RecordChanges(Node, RegistrationObject);
			Selection = ExchangePlans.SelectChanges(Node, Command, RegistrationObject);
			While Selection.Next() Do
				// Selecting changes to set a data exchange message number.
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure RecordChanges(Val Node, Val RegistrationObject)
	
	If Not RegisterWithSSLMethodsAvailable
		Or Not IsSSLExchangePlanNode(Node) Then
		ExchangePlans.RecordChanges(Node, RegistrationObject);
		Return;
	EndIf;
		
	// To register the changes using SSL tools, additional actions are required.
	ModuleDataExchangeEvents = CommonModuleEventDataExchange();
	
	// RegistrationObject contains a metadata object or an infobase object.
	If TypeOf(RegistrationObject) = Type("MetadataObject") Then
		Characteristics = MetadataCharacteristics(RegistrationObject);
		If Characteristics.IsReference Then
			
			Selection = Characteristics.Manager.Select();
			While Selection.Next() Do
				ModuleDataExchangeEvents.RecordDataChanges(Node, Selection.Ref, ObjectExportControlSetting);
			EndDo;
			
		ElsIf Characteristics.IsRecordsSet Then
			For Each RegisterDimension In RegistrationObject.Dimensions Do
				If InvalidRegisterDimensionName(RegisterDimension) Then
					Return;
				EndIf;
			EndDo;
			
			DimensionFields = "";
			For Each String In RecordSetDimensions(Characteristics.TableName) Do
				DimensionFields = DimensionFields + "," + String.Name
			EndDo;
			
			DimensionFields = Mid(DimensionFields, 2);
			If IsBlankString(DimensionFields) Then
				
				// 
				// 
				ExchangePlans.RecordChanges(Node, RegistrationObject);
				
			Else
				
				QueryTextTemplate2 = 
				"SELECT DISTINCT
				|	&FieldsNames
				|FROM
				|	&MetadataTableName AS MetadataTableName";
				
				QueryText = StrReplace(QueryTextTemplate2, "&FieldsNames", DimensionFields);
				QueryText = StrReplace(QueryText, "&MetadataTableName", Characteristics.TableName);
				
				Query = New Query(QueryText);
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					Data = New Structure(DimensionFields);
					FillPropertyValues(Data, Selection);
					SSLSetChangesRegistration(Node, Data, Characteristics);
				EndDo;
				
			EndIf;
			
		ElsIf Characteristics.IsConstant Then
			Selection = Characteristics.Manager.CreateValueManager();
			ModuleDataExchangeEvents.RecordDataChanges(Node, Selection, ObjectExportControlSetting);
		EndIf;
		Return;
	EndIf;
	
	// 
	ModuleDataExchangeEvents.RecordDataChanges(Node, RegistrationObject, ObjectExportControlSetting);
EndProcedure

// Parameters:
//   Dimension - MetadataObject
//
// Returns:
//   Boolean - 
//            
//
Function InvalidRegisterDimensionName(Dimension)
	
	Return Upper(Dimension.Name) = "NODE"
		Or Upper(Dimension.Name) = "NODE";
	
EndFunction

// Returns a managed form that contains a passed form item.
//
// Parameters:
//  FormItem - FormItems
// Returns:
//  FormItems
//
Function FormItemForm(FormItem)
	Result = FormItem;
	FormTypes = New TypeDescription("ClientApplicationForm");
	While Not FormTypes.ContainsType(TypeOf(Result)) Do
		Result = Result.Parent;
	EndDo;
	Return Result;
EndFunction

// Internal, for generating a metadata group (for example, catalogs) in a metadata tree.
//
Procedure GenerateMetadataLevel(CurrentRowNumber1, Parameters, PictureIndex, NodePictureIndex, AddSubordinate, MetaName, MetaPresentation1)
	
	LevelPresentation1 = New Array;
	AutoRecords     = New Array;
	LevelNames         = New Array;
	
	AllRows = Parameters.Rows;
	MetaPlan  = Parameters.ExchangePlan;
	
	ORMSubscriptionsComposition = Undefined;
	CheckORMSubscriptionsContent = Parameters.Property("ORMSubscriptionsComposition", ORMSubscriptionsComposition);
	
	GroupString = AllRows.Add();
	GroupString.RowID = CurrentRowNumber1;
	
	GroupString.MetaFullName  = MetaName;
	GroupString.Description   = MetaPresentation1;
	GroupString.PictureIndex = PictureIndex;
	
	Rows = GroupString.Rows;
	HadSubordinate = False;
	
	For Each Meta In Metadata[MetaName] Do
		
		If MetaPlan = Undefined Then
			// An exchange plan is not specified
			
			If Not MetadataObjectAvailableByFunctionalOptions(Meta) Then
				Continue;
			EndIf;
			
			HadSubordinate = True;
			MetaFullName   = Meta.FullName();
			Description    = Meta.Presentation();
			
			If AddSubordinate Then
				
				NewString = Rows.Add();
				NewString.MetaFullName  = MetaFullName;
				NewString.Description   = Description ;
				NewString.PictureIndex = NodePictureIndex;
				
				CurrentRowNumber1 = CurrentRowNumber1 + 1;
				NewString.RowID = CurrentRowNumber1;
				
			EndIf;
			
			LevelNames.Add(MetaFullName);
			LevelPresentation1.Add(Description);
			
		Else
			
			Item = MetaPlan.Content.Find(Meta);
			
			If Item <> Undefined And AccessRight("Read", Meta) Then
				
				If ConfigurationSupportsSSL
					And CheckORMSubscriptionsContent
					And ORMSubscriptionsComposition.Find(Meta) = Undefined Then
					Continue;
				EndIf;
				
				If Not MetadataObjectAvailableByFunctionalOptions(Meta) Then
					Continue;
				EndIf;
				
				HadSubordinate = True;
				MetaFullName   = Meta.FullName();
				Description    = Meta.Presentation();
				AutoRecord = ?(Item.AutoRecord = AutoChangeRecord.Deny, 1, 2);
				
				If AddSubordinate Then
					
					NewString = Rows.Add();
					NewString.MetaFullName   = MetaFullName;
					NewString.Description    = Description ;
					NewString.PictureIndex  = NodePictureIndex;
					NewString.AutoRecord = AutoRecord;
					
					CurrentRowNumber1 = CurrentRowNumber1 + 1;
					NewString.RowID = CurrentRowNumber1;
					
				EndIf;
				
				LevelNames.Add(MetaFullName);
				LevelPresentation1.Add(Description);
				AutoRecords.Add(AutoRecord);
				
			EndIf;
		EndIf;
		
	EndDo;
	
	If HadSubordinate Then
		Rows.Sort("Description");
		Parameters.NamesStructure.Insert(MetaName, LevelNames);
		Parameters.PresentationsStructure.Insert(MetaName, LevelPresentation1);
		If Not AddSubordinate Then
			Parameters.AutoRecordStructure.Insert(MetaName, AutoRecords);
		EndIf;
	Else
		// 
		AllRows.Delete(GroupString);
	EndIf;
	
EndProcedure

// Determines whether the metadata object is available by functional options.
//
// Parameters:
//   MetadataObject - MetadataObject - Metadata object being checked.
//
// Returns: 
//  Boolean - 
//
Function MetadataObjectAvailableByFunctionalOptions(MetadataObject)
	
	If Not ValueIsFilled(ObjectsEnabledByOption) Then
		ObjectsEnabledByOption = ObjectsEnabledByOption();
	EndIf;
	
	Return ObjectsEnabledByOption[MetadataObject] <> False;
	
EndFunction

// Metadata object availability by functional options.
Function ObjectsEnabledByOption()
	
	Parameters = New Structure();
	
	ObjectsEnabled = New Map;
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		Value = -1;
		
		For Each Item In FunctionalOption.Content Do
			
			If Value = -1 Then
				Value = GetFunctionalOption(FunctionalOption.Name, Parameters);
			EndIf;
			
			If Value = True Then
				ObjectsEnabled.Insert(Item.Object, True);
			Else
				If ObjectsEnabled[Item.Object] = Undefined Then
					ObjectsEnabled.Insert(Item.Object, False);
				EndIf;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return ObjectsEnabled;
	
EndFunction

// Accumulating registration results.
//
Procedure AddResults(Receiver, Source)
	Receiver.Success = Receiver.Success + Source.Success;
	Receiver.Total   = Receiver.Total   + Source.Total;
EndProcedure	

// Returns the array of additional objects being registered according to check boxes.
//
Function GetAdditionalRegistrationObjects(RegistrationObject, AutoRecordControlNode, WithoutAutoRecord, TableName = Undefined)
	Result = New Array;
	
	// Analyzing global parameters.
	If (Not RegisterRecordAutoRecordSetting) And (Not SequenceAutoRecordSetting) Then
		Return Result;
	EndIf;
	
	ValueType = TypeOf(RegistrationObject);
	NamePassed = ValueType = Type("String");
	If NamePassed Then
		LongDesc = MetadataCharacteristics(RegistrationObject);
	ElsIf ValueType = Type("Structure") Then
		LongDesc = MetadataCharacteristics(TableName);
		If LongDesc.IsSequence Then
			Return Result;
		EndIf;
	Else
		LongDesc = MetadataCharacteristics(RegistrationObject.Metadata());
	EndIf;
	
	MetaObject = LongDesc.Metadata;
	
	// Collection recursively.	
	If LongDesc.IsCollection Then
		For Each Meta In MetaObject Do
			AdditionalSet = GetAdditionalRegistrationObjects(Meta.FullName(), AutoRecordControlNode, WithoutAutoRecord, TableName);
			For Each Item In AdditionalSet Do
				Result.Add(Item);
			EndDo;
		EndDo;
		Return Result;
	EndIf;
	
	// Single
	NodeContent = AutoRecordControlNode.Metadata().Content;
	
	// Documents. May affect sequences and register records.
	If Metadata.Documents.Contains(MetaObject) Then
		
		If RegisterRecordAutoRecordSetting Then
			For Each Meta In MetaObject.RegisterRecords Do
				
				CompositionItem = NodeContent.Find(Meta);
				If CompositionItem <> Undefined And (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
					If NamePassed Then
						Result.Add(Meta);
					Else
						LongDesc = MetadataCharacteristics(Meta);
						Set = LongDesc.Manager.CreateRecordSet();
						SetFilterItemValue(Set.Filter, "Recorder", RegistrationObject);
						Set.Read();
						Result.Add(Set);
						// 
						AdditionalSet = GetAdditionalRegistrationObjects(Set, AutoRecordControlNode, WithoutAutoRecord, TableName);
						For Each Item In AdditionalSet Do
							Result.Add(Item);
						EndDo;
					EndIf;
				EndIf;
				
			EndDo;
		EndIf;
		
		If SequenceAutoRecordSetting Then
			For Each Meta In Metadata.Sequences Do
				
				LongDesc = MetadataCharacteristics(Meta);
				If Meta.Documents.Contains(MetaObject) Then
					// 
					CompositionItem = NodeContent.Find(Meta);
					If CompositionItem <> Undefined And (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
						// Registering data for the current node.
						If NamePassed Then
							Result.Add(Meta);
						Else
							Set = LongDesc.Manager.CreateRecordSet();
							SetFilterItemValue(Set.Filter, "Recorder", RegistrationObject);
							Set.Read();
							Result.Add(Set);
						EndIf;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	// Register records. May affect sequences.
	ElsIf SequenceAutoRecordSetting And (
		Metadata.InformationRegisters.Contains(MetaObject)
		Or Metadata.AccumulationRegisters.Contains(MetaObject)
		Or Metadata.AccountingRegisters.Contains(MetaObject)
		Or Metadata.CalculationRegisters.Contains(MetaObject)) Then
		For Each Meta In Metadata.Sequences Do
			If Meta.RegisterRecords.Contains(MetaObject) Then
				// 
				CompositionItem = NodeContent.Find(Meta);
				If CompositionItem <> Undefined And (WithoutAutoRecord Or CompositionItem.AutoRecord = AutoChangeRecord.Allow) Then
					Result.Add(Meta);
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	Return Result;
EndFunction

// Converts a string value to a number value
//
// Parameters:
//     Text - String - string presentation of a number.
// 
// Returns:
//     Number        - 
//     
//
Function StringToNumber(Val Text)
	NumberText = TrimAll(StrReplace(Text, Chars.NBSp, ""));
	
	If IsBlankString(NumberText) 
		Or NumberText = "0" Then
		Return 0;
	EndIf;
	
	// Leading zeroes.
	Position = 1;
	While Mid(NumberText, Position, 1) = "0" Do
		Position = Position + 1;
	EndDo;
	NumberText = Mid(NumberText, Position);
	
	// Checking whether there is a default result.
	If NumberText = "0" Then
		Result = 0;
	Else
		NumberType = New TypeDescription("Number");
		Result = NumberType.AdjustValue(NumberText);
		If Result = 0 Then
			// 
			Result = Undefined;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Returns the DataExchangeEvents common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleEventDataExchange()
	If Metadata.CommonModules.Find("DataExchangeEvents") = Undefined Then
		Return Undefined;
	EndIf;
	
	// 
	Return Eval("DataExchangeEvents");
EndFunction

// Returns the StandardSubsystemsServer common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleStandardSubsystemsServer()
	If Metadata.CommonModules.Find("StandardSubsystemsServer") = Undefined Then
		Return Undefined;
	EndIf;
	
	// 
	Return Eval("StandardSubsystemsServer");
EndFunction

// Returns the common module of the standard subsystem Server, or Undefined if it is not included in the configuration.
//
Function GeneralModuleStandardSubsystemsOfRepeatIsp()
	If Metadata.CommonModules.Find("StandardSubsystemsCached") = Undefined Then
		Return Undefined;
	EndIf;
	
	// 
	Return Eval("StandardSubsystemsCached");
EndFunction

// Returns the CommonUse common module or Undefined if there is no such module in the configuration.
//
Function CommonModuleCommonUse()
	If Metadata.CommonModules.Find("Common") = Undefined Then
		Return Undefined;
	EndIf;
	
	// 
	Return Eval("Common");
EndFunction

Function IsSSLExchangePlanNode(Node)
	
	If Metadata.CommonModules.Find("DataExchangeCached") = Undefined Then
		Return False;
	EndIf;
	
	ModuleDataExchangeCached = Eval("DataExchangeCached");
	
	Return ModuleDataExchangeCached.SSLExchangePlans().Find(ModuleDataExchangeCached.GetExchangePlanName(Node)) <> Undefined;
	
EndFunction

// Returns the flag showing that SSL in the current configuration provides functionality.
//
Function SSLRequiredVersionAvailable(Val Version = Undefined)
	
	CurrentVersion = Undefined;
	ModuleStandardSubsystemsServer = CommonModuleStandardSubsystemsServer();
	If ModuleStandardSubsystemsServer <> Undefined Then
		Try
			CurrentVersion = ModuleStandardSubsystemsServer.LibraryVersion();
		Except
			CurrentVersion = Undefined;
		EndTry;
	EndIf;
	
	If CurrentVersion = Undefined Then
		// 
		Return False
	EndIf;
	CurrentVersion = StrReplace(CurrentVersion, ".", Chars.LF);
	
	NeededVersion = StrReplace(?(Version = Undefined, "2.2.2", Version), ".", Chars.LF);
	
	For IndexOf = 1 To StrLineCount(NeededVersion) Do
		
		CurrentVersionPart = StringToNumber(StrGetLine(CurrentVersion, IndexOf));
		RequiredVersionPart  = StringToNumber(StrGetLine(NeededVersion,  IndexOf));
		
		If CurrentVersionPart = Undefined Then
			Return False;
			
		ElsIf CurrentVersionPart > RequiredVersionPart Then
			Return True;
			
		ElsIf CurrentVersionPart < RequiredVersionPart Then
			Return False;
			
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// 
//
Function DSL_RequiredVersionIsAvailable(Val Version = Undefined)
	
	CurrentVersion = Undefined;
	ModuleStandardSubsystemsOfRepeatIsp = GeneralModuleStandardSubsystemsOfRepeatIsp();
	If ModuleStandardSubsystemsOfRepeatIsp <> Undefined Then
		Try
			CurrentVersion = StandardSubsystemsCached.SubsystemsDetails().ByNames["DataSyncLibrary"].Version
		Except
			CurrentVersion = Undefined;
		EndTry;
	EndIf;
	
	If CurrentVersion = Undefined Then
		// 
		Return False
	EndIf;
	CurrentVersion = StrReplace(CurrentVersion, ".", Chars.LF);
	
	NeededVersion = StrReplace(?(Version = Undefined, "2.2.2", Version), ".", Chars.LF);
	
	For IndexOf = 1 To StrLineCount(NeededVersion) Do
		
		CurrentVersionPart = StringToNumber(StrGetLine(CurrentVersion, IndexOf));
		RequiredVersionPart  = StringToNumber(StrGetLine(NeededVersion,  IndexOf));
		
		If CurrentVersionPart = Undefined Then
			Return False;
			
		ElsIf CurrentVersionPart > RequiredVersionPart Then
			Return True;
			
		ElsIf CurrentVersionPart < RequiredVersionPart Then
			Return False;
			
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// Returns the flag of object control in SSL.
//
Function SSLObjectExportControl(Node, RegistrationObject)
	
	Send = DataItemSend.Auto;
	ModuleDataExchangeEvents = CommonModuleEventDataExchange();
	If ModuleDataExchangeEvents <> Undefined Then
		ModuleDataExchangeEvents.OnSendDataToRecipient(RegistrationObject, Send, , Node);
		Return Send = DataItemSend.Auto;
	EndIf;
	
	// 
	Return True;
EndFunction

// Checks whether a reference change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSLRefChangesRegistration(Node, Ref, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(Ref.Metadata()));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		// 
		Result.Total = 1;
		RegistrationObject = Ref.GetObject();
		// RegistrationObject value is Undefined if a passed reference is invalid.
		If RegistrationObject = Undefined Or SSLObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, Ref);
			Result.Success = 1;
		EndIf;
		RegistrationObject = Undefined;
	EndIf;	
	
	// Add additional registration objects.
	If Result.Success > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Ref, Node, NoAutoRegistration) Do
			Result.Total = Result.Total + 1;
			If SSLObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Success = Result.Success + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a record set change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSLSetChangesRegistration(Node, FieldsStructure, LongDesc, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(LongDesc.Metadata));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		Set = LongDesc.Manager.CreateRecordSet();
		For Each KeyValue In FieldsStructure Do
			SetFilterItemValue(Set.Filter, KeyValue.Key, KeyValue.Value);
		EndDo;
		Set.Read();
		
		If SSLObjectExportControl(Node, Set) Then
			ExecuteObjectRegistrationCommand(True, Node, Set);
			Result.Success = 1;
		EndIf;
		
	EndIf;
	
	// Add additional registration objects.
	If Result.Success > 0 Then
		For Each Item In GetAdditionalRegistrationObjects(Set, Node, NoAutoRegistration) Do
			Result.Total = Result.Total + 1;
			If SSLObjectExportControl(Node, Item) Then
				ExecuteObjectRegistrationCommand(True, Node, Item);
				Result.Success = Result.Success + 1;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a constant change can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSLConstantChangesRegistration(Node, LongDesc, NoAutoRegistration = True)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If NoAutoRegistration Then
		NodeContent = Undefined;
	Else
		NodeContent = Node.Metadata().Content;
	EndIf;
	
	CompositionItem = ?(NodeContent = Undefined, Undefined, NodeContent.Find(LongDesc.Metadata));
	If CompositionItem = Undefined Or CompositionItem.AutoRecord = AutoChangeRecord.Allow Then
		Result.Total = 1;
		
		RegistrationObject = LongDesc.Manager.CreateValueManager();
		
		If SSLObjectExportControl(Node, RegistrationObject) Then
			ExecuteObjectRegistrationCommand(True, Node, RegistrationObject);
			Result.Success = 1;
		EndIf;
		
	EndIf;	
	
	Return Result;
EndFunction

// Checks whether a metadata set can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSLMetadataChangesRegistration(Node, LongDesc, NoAutoRegistration, MetadataNamesStructure)
	
	Result = New Structure("Total, Success", 0, 0);
	
	If TypeOf(MetadataNamesStructure) = Type("Structure")
		And LongDesc.IsConstant
		And Not MetadataNamesStructure.Property("Constants") Then
		
		// 
		Return Result;
		
	EndIf;
	
	If MetadataNamesStructure <> Undefined
		And LongDesc.IsConstant 
		And Not LongDesc.IsCollection 
		And MetadataNamesStructure.Constants.Find(LongDesc.TableName) = Undefined Then
		
		Return Result;

	EndIf;
	
	If LongDesc.IsCollection Then
		For Each MetaKind In LongDesc.Metadata Do
			CurDetails = MetadataCharacteristics(MetaKind);
			AddResults(Result, SSLMetadataChangesRegistration(Node, CurDetails, NoAutoRegistration, MetadataNamesStructure));
		EndDo;
	Else;
		AddResults(Result, SSLMetadataObjectChangesRegistration(Node, LongDesc, NoAutoRegistration) );
	EndIf;
	
	Return Result;
EndFunction

// Checks whether a metadata object can be registered in SSL.
// Returns the structure with the Total and Done fields that describes registration quantity.
//
Function SSLMetadataObjectChangesRegistration(Node, LongDesc, NoAutoRegistration)
	
	Result = New Structure("Total, Success", 0, 0);
	
	CompositionItem = Node.Metadata().Content.Find(LongDesc.Metadata);
	If CompositionItem = Undefined Then
		// 
		Return Result;
	EndIf;
	
	If (Not NoAutoRegistration) And CompositionItem.AutoRecord <> AutoChangeRecord.Allow Then
		// 
		Return Result;
	EndIf;
	
	CurTableName = LongDesc.TableName;
	If LongDesc.IsConstant Then
		AddResults(Result, SSLConstantChangesRegistration(Node, LongDesc) );
		Return Result;
		
	ElsIf LongDesc.IsReference Then
		DimensionFields = "Ref";
		
	ElsIf LongDesc.IsRecordsSet Then
		DimensionFields = "";
		For Each String In RecordSetDimensions(CurTableName) Do
			DimensionFields = DimensionFields + "," + String.Name
		EndDo;
		DimensionFields = Mid(DimensionFields, 2);
		If IsBlankString(DimensionFields) Then
			// 
			// 
			ExchangePlans.RecordChanges(Node, LongDesc.Metadata);
			
			// To calculate the result.
			QueryTextTemplate2 = 
			"SELECT
			|	COUNT(*) AS Count
			|FROM
			|	&MetadataTableName AS MetadataTableName";
			
			QueryText = StrReplace(QueryTextTemplate2, "&MetadataTableName", CurTableName);
			
			Query = New Query(QueryText);
			Selection = Query.Execute().Select();
			Selection.Next();
			Result.Total = Selection.Count;
			Result.Success = Selection.Count;
			Return Result;
			
		EndIf;
	Else
		Return Result;
	EndIf;
	
	QueryTextTemplate2 =
	"SELECT DISTINCT
	|	&NamesOfFieldsOrDetails
	|FROM
	|	&MetadataTableName AS MetadataTableName";
	
	QueryText = StrReplace(QueryTextTemplate2, "&NamesOfFieldsOrDetails", DimensionFields);
	QueryText = StrReplace(QueryText, "&MetadataTableName", CurTableName);
	Query = New Query(QueryText);
		
	If LongDesc.IsReference And BatchRegistrationIsAvailable Then
		
		ModuleDataExchangeEvents = CommonModuleEventDataExchange();
		
		ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
		PDParameters = ModuleDataExchangeEvents.BatchRegistrationParameters();
		
		ModuleDataExchangeEvents.PerformBatchRegistrationForNode(Node, ReferencesArrray, PDParameters);
		
		For Each Ref In PDParameters.LinksToBatchRegistrationFilter Do
			Result.Success = Result.Success + 1;
			ExchangePlans.RecordChanges(Node, Ref);
		EndDo;
		
		If PDParameters.ThereIsPRO_WithoutBatchRegistration Then
			For Each Ref In PDParameters.LinksNotByBatchRegistrationFilter Do
				AddResults(Result, SSLRefChangesRegistration(Node, Ref, NoAutoRegistration));
			EndDo;
		EndIf;
		
		Result.Total = ReferencesArrray.Count();
		
		Return Result;
		
	EndIf;
		
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If LongDesc.IsRecordsSet Then
			Data = New Structure(DimensionFields);
			FillPropertyValues(Data, Selection);
			AddResults(Result, SSLSetChangesRegistration(Node, Data, LongDesc) );
		ElsIf LongDesc.IsReference Then
			AddResults(Result, SSLRefChangesRegistration(Node, Selection.Ref, NoAutoRegistration) );
		EndIf;
	EndDo;
		
	Return Result;
	
EndFunction

// Updating and registering MOID data for the passed node.
//
Function SSLUpdateAndRegisterMasterNodeMetadataObjectID(Val Node) Export
	
	Result = New Structure("Total, Success", 0 , 0);
	
	MetaNodeExchangePlan = Node.Metadata();
	
	If (Not DIBModeAvailable)                                      // Current SSL version does not support MOID.
		Or (ExchangePlans.MasterNode() <> Undefined)              // Current infobase is a subordinate node.
		Or (Not MetaNodeExchangePlan.DistributedInfoBase) Then // Узел-
		Return Result;
	EndIf;
	
	// Registering everything for DIB without SSL rule control.
	
	// Register changes for the MetadataObjectIDs catalog.
	MetaCatalog = Metadata.Catalogs["MetadataObjectIDs"];
	If MetaNodeExchangePlan.Content.Contains(MetaCatalog) Then
		ExchangePlans.RecordChanges(Node, MetaCatalog);
		
		Query = New Query("SELECT COUNT(Ref) AS ItemCount FROM Catalog.MetadataObjectIDs");
		Result.Success = Query.Execute().Unload()[0].ItemCount;
	EndIf;
	
	// 
	Result.Success = Result.Success 
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.Catalogs)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCharacteristicTypes)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfAccounts)
		+ RegisterPredefinedObjectChangeForNode(Node, Metadata.ChartsOfCalculationTypes);
	
	Result.Total = Result.Success;
	Result.Insert("Command", True);
	
	Return Result;
EndFunction

Function RegisterPredefinedObjectChangeForNode(Val Node, Val MetadataCollection)
	
	NodeContent = Node.Metadata().Content;
	Result  = 0;
	Query     = New Query;
	
	QueryTextTemplate2 = 
	"SELECT
	|	MetadataTableName.Ref
	|FROM
	|	&MetadataTableName AS MetadataTableName
	|WHERE
	|	MetadataTableName.Predefined";
	
	For Each MetadataObject In MetadataCollection Do
		If NodeContent.Contains(MetadataObject) Then
			
			QueryText = StrReplace(QueryTextTemplate2, "&MetadataTableName", MetadataObject.FullName());
			Query.Text = QueryText;
			Selection = Query.Execute().Select();
			
			Result = Result + Selection.Count();
			
			// Registering for DIB without SSL rule control.
			While Selection.Next() Do
				ExchangePlans.RecordChanges(Node, Selection.Ref);
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//   Filter - Filter - custom filter.
//   ItemKey - String - a filter item name.
//   ElementValue - Arbitrary - filter item value.
// 
Procedure SetFilterItemValue(Filter, ItemKey, ElementValue) Export
	
	FilterElement = Filter.Find(ItemKey);
	If FilterElement <> Undefined Then
		FilterElement.Set(ElementValue);
	EndIf;
	
EndProcedure

// Returns:
//   ValueTree:
//     * Description        - String - object metadata kind presentation.
//     * MetaFullName       - String - Full name of a metadata object.
//     * PictureIndex      - Number  - depends on metadata.
//     * Check             - Undefined - it is further used to store marks
//     * RowID - Number  - index of the added row (the tree is iterated from top to bottom from left to right).
//     * AutoRecord     - Boolean - if ExchangePlanName is specified, the parameter can contain the following values (for leaves): 1 - allowed,
//                                      2-prohibited. Else Undefined.
//     * ChangeCount        - Number - a number of changed records.
//     * ExportedCount      - Number - a number of exported records.
//     * NotExportedCount    - Number - a number of non-exported records.
//     * ChangeCountString - Number - string representation of the number of changed records.
//
Function MetadataObjectsTree()
	Tree = New ValueTree;
	Columns = Tree.Columns;
	
	Columns.Add("Description");
	Columns.Add("MetaFullName");
	Columns.Add("PictureIndex");
	Columns.Add("Check");
	Columns.Add("RowID");
	
	Columns.Add("AutoRecord");
	Columns.Add("ChangeCount");
	Columns.Add("ExportedCount");
	Columns.Add("NotExportedCount");
	Columns.Add("ChangeCountString");
	
	Return Tree;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone mode support.

Function SubstituteParametersToString(Val SubstitutionString, Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf