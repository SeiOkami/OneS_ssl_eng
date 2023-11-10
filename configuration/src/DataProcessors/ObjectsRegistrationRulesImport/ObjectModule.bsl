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

Var Registration Export; // 
Var ObjectsRegistrationRules Export; // 
Var FlagErrors Export; // 

Var StringType;
Var BooleanType;
Var NumberType;
Var DateType;

Var BlankDateValue1;
Var FilterByExchangePlanPropertiesTreePattern;  // 
                                                // 
Var FilterByObjectPropertiesTreePattern;      // 
Var BooleanRootPropertiesGroupValue; // 
Var ErrorsMessages; // Соответствие. Ключ - 

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Performs a syntactic analysis of the XML file that contains registration rules. Fills collection values with data from the file;
// Prepares read rules for ORR mechanism (rule compilation).
//
// Parameters:
//  FileName         - String - full name of a rule file with rules in the local file system.
//  InformationOnly - Boolean - a flag showing whether the file title and rule information are the only data to be read;
//                              (the default value is False).
//
Procedure ImportRules(Val FileName, InformationOnly = False) Export
	
	FlagErrors = False;
	
	If IsBlankString(FileName) Then
		ReportProcessingError(4);
		Return;
	EndIf;
	
	// 
	Registration                             = RecordInitialization();
	ObjectsRegistrationRules              = DataProcessors.ObjectsRegistrationRulesImport.ORRTableInitialization();
	FilterByExchangePlanPropertiesTreePattern = DataProcessors.ObjectsRegistrationRulesImport.FilterByExchangePlanPropertiesTableInitialization();
	FilterByObjectPropertiesTreePattern     = DataProcessors.ObjectsRegistrationRulesImport.FilterByObjectPropertiesTableInitialization();
	
	// LOAD REGISTRATION RULES
	Try
		LoadRecordFromFile(FileName, InformationOnly);
	Except
		
		// Report about the error.
		ReportProcessingError(2, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Error reading rules from the file.
	If FlagErrors Then
		Return;
	EndIf;
	
	If InformationOnly Then
		Return;
	EndIf;
	
	// PREPARING RULES FOR ORR MECHANISM
	
	For Each ORR In ObjectsRegistrationRules Do
		
		PrepareRecordRuleByExchangePlanProperties(ORR);
		
		PrepareRegistrationRuleByObjectProperties(ORR);
		
	EndDo;
	
	ObjectsRegistrationRules.FillValues(Registration.ExchangePlanName, "ExchangePlanName");
	
EndProcedure

// Prepares a row with information about the rules based on the read data from the XML file.
//
// Returns:
//   String - 
//
Function RulesInformation() Export
	
	// Function return value.
	InfoString = "";
	
	If FlagErrors Then
		Return InfoString;
	EndIf;
	
	InfoString = NStr("en = 'Object registration rules in this infobase (%1) created on %2';");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(InfoString,
		GetConfigurationPresentationFromRegistrationRules(),
		Format(Registration.CreationDateTime, "DLF = дд"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Importing object registration rules (ORR).

Procedure LoadRecordFromFile(FileName, InformationOnly)
	
	// Opening the file for reading
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		ReportProcessingError(1, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	Try
		LoadRecord(Rules, InformationOnly);
	Except
		ReportProcessingError(2, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Imports registration rules according to the format.
//
// Parameters:
//  
Procedure LoadRecord(Rules, InformationOnly)
	
	If Not ((Rules.LocalName = "RecordRules") 
		And (Rules.NodeType = XMLNodeType.StartElement)) Then
		
		// Exchange rule format error.
		ReportProcessingError(3);
		
		Return;
		
	EndIf;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		// Registration attributes.
		If NodeName = "FormatVersion" Then
			
			Registration.FormatVersion = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ID_SSLy" Then
			
			Registration.ID_SSLy = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			Registration.Description = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "CreationDateTime" Then
			
			Registration.CreationDateTime = deElementValue(Rules, DateType);
			
		ElsIf NodeName = "ExchangePlan" Then
			
			// 
			Registration.ExchangePlanName = deAttribute(Rules, StringType, "Name");
			
			Registration.ExchangePlan = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Comment" Then
			
			Registration.Comment = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Configuration" Then
			
			// 
			Registration.PlatformVersion     = deAttribute(Rules, StringType, "PlatformVersion");
			Registration.ConfigurationVersion  = deAttribute(Rules, StringType, "ConfigurationVersion");
			Registration.ConfigurationSynonym = deAttribute(Rules, StringType, "ConfigurationSynonym");
			
			//  the name of the configuration
			Registration.Configuration = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectsRegistrationRules" Then
			
			If InformationOnly Then
				
				Break; // Breaking if only registration information is required.
				
			Else
				
				// Checking whether ORR are imported for the required exchange plan.
				CheckExchangePlanExists();
				
				If FlagErrors Then
					Break; // Rules contain wrong exchange plan.
				EndIf;
				
				ImportRegistrationRules(Rules);
				
			EndIf;
			
		ElsIf (NodeName = "RecordRules") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports registration rules according to the exchange rule format.
//
// Parameters:
//  Rules - XMLReader - an object of the XMLReader type.
//
Procedure ImportRegistrationRules(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf (NodeName = "ObjectsRegistrationRules") And (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//   RulesTable - ValueTable - a table of registration rules.
// 
Function NewRegistrationRule(RulesTable)
	
	Return RulesTable.Add();
	
EndFunction

// Imports the object registration rule.
//
// Parameters:
//  Rules  - XMLReader - an object of the XMLReader type.
//
Procedure LoadRecordRule(Rules)
	
	// Rules with the Disable flag must not be loaded.
	Disconnect = deAttribute(Rules, BooleanType, "Disconnect");
	If Disconnect Then
		deSkip(Rules);
		Return;
	EndIf;
	
	// Rules with errors must not be loaded.
	Valid = deAttribute(Rules, BooleanType, "Valid");
	If Not Valid Then
		deSkip(Rules);
		Return;
	EndIf;
	
	NewRow = NewRegistrationRule(ObjectsRegistrationRules);
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "SettingObject1" Then
			
			NewRow.SettingObject1 = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "MetadataObjectName3" Then
			
			NewRow.MetadataObjectName3 = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ExportModeAttribute" Then
			
			NewRow.FlagAttributeName = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "FilterByExchangePlanProperties" Then
			
			// 
			NewRow.FilterByExchangePlanProperties = FilterByExchangePlanPropertiesTreePattern.Copy();
			
			LoadFilterByExchangePlanPropertiesTree(Rules, NewRow.FilterByExchangePlanProperties);
			
		ElsIf NodeName = "FilterByObjectProperties" Then
			
			// 
			NewRow.FilterByObjectProperties = FilterByObjectPropertiesTreePattern.Copy();
			
			LoadFilterByObjectPropertiesTree(Rules, NewRow.FilterByObjectProperties);
			
		ElsIf NodeName = "BeforeProcess" Then
			
			NewRow.BeforeProcess = deElementValue(Rules, StringType);
			
			NewRow.HasBeforeProcessHandler = Not IsBlankString(NewRow.BeforeProcess);
			
		ElsIf NodeName = "OnProcess" Then
			
			NewRow.OnProcess = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandler = Not IsBlankString(NewRow.OnProcess);
			
		ElsIf NodeName = "OnProcessAdditional" Then
			
			NewRow.OnProcessAdditional = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandlerAdditional = Not IsBlankString(NewRow.OnProcessAdditional);
			
		ElsIf NodeName = "AfterProcess" Then
			
			NewRow.AfterProcess = deElementValue(Rules, StringType);
			
			NewRow.HasAfterProcessHandler = Not IsBlankString(NewRow.AfterProcess);
			
		ElsIf (NodeName = "Rule") And (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  Rules - XMLReader - an object of the XMLReader type.
//  ValueTree - ValueTree - a tree of the object registration rules.
//
Procedure LoadFilterByExchangePlanPropertiesTree(Rules, ValueTree) Export
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterElement" Then
			
			LoadExchangePlanFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadExchangePlanFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByExchangePlanProperties") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  Rules - XMLReader - an object of the XMLReader type.
//  ValueTree - ValueTree - a tree of the object registration rules.
//
Procedure LoadFilterByObjectPropertiesTree(Rules, ValueTree) Export
	
	VTRows = ValueTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterElement" Then
			
			LoadObjectFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadObjectFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByObjectProperties") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object registration rule by property.
//
// Parameters:
// 
Procedure LoadExchangePlanFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty1" Then
			
			If NewRow.IsConstantString Then
				
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType));
				
			Else
				
				NewRow.ObjectProperty1 = deElementValue(Rules, StringType);
				
			EndIf;
			
		ElsIf NodeName = "ExchangePlanProperty" Then
			
			// 
			// 
			// 
			// 
			// 
			FullPropertyDescription = deElementValue(Rules, StringType);
			
			ExchangePlanTabularSectionName = "";
			
			FirstBracketPosition = StrFind(FullPropertyDescription, "[");
			
			If FirstBracketPosition <> 0 Then
				
				SecondBracketPosition = StrFind(FullPropertyDescription, "]");
				
				ExchangePlanTabularSectionName = Mid(FullPropertyDescription, FirstBracketPosition + 1, SecondBracketPosition - FirstBracketPosition - 1);
				
				FullPropertyDescription = Mid(FullPropertyDescription, SecondBracketPosition + 2);
				
			EndIf;
			
			NewRow.NodeParameter                = FullPropertyDescription;
			NewRow.NodeParameterTabularSection = ExchangePlanTabularSectionName;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "IsConstantString" Then
			
			NewRow.IsConstantString = deElementValue(Rules, BooleanType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterElement") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object registration rule by property.
//
// Parameters:
// 
Procedure LoadObjectFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty1" Then
			
			NewRow.ObjectProperty1 = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ConstantValue" Then
			
			If IsBlankString(NewRow.FilterItemKind) Then
				
				NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue();
				
			EndIf;
			
			If NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue() Then
				
				// 
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType));
				
			ElsIf NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // String
				
			Else
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // String
				
			EndIf;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Kind" Then
			
			NewRow.FilterItemKind = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterElement") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object registration rule groups by property.
//
// Parameters:
//  Rules  - XMLReader - an object of the XMLReader type.
//  NewRow - ValueTreeRow - a row of the object registration rules tree.
//
Procedure LoadExchangePlanFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterElement" Then
			
			LoadExchangePlanFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.StartElement) Then
			
			LoadExchangePlanFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			NewRow.BooleanGroupValue = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

// Imports object registration rule groups by property.
//
// Parameters:
//  Rules  - XMLReader - an object of the XMLReader type.
//  NewRow - ValueTreeRow - a row of the object registration rules tree.
//
Procedure LoadObjectFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterElement" Then
			
			LoadObjectFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.StartElement) Then
			
			LoadObjectFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			BooleanGroupValue = deElementValue(Rules, StringType);
			
			NewRow.IsANDOperator = (BooleanGroupValue = "And");
			
		ElsIf (NodeName = "Group") And (NodeType = XMLNodeType.EndElement) Then
			
			Break; // Exit.
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

Procedure LoadRecordRuleGroup(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" And Rules.NodeType = XMLNodeType.StartElement Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf NodeName = "Group" And Rules.NodeType = XMLNodeType.EndElement Then
		
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by exchange plan properties.

Procedure PrepareRecordRuleByExchangePlanProperties(ORR) Export
	
	EmptyRule = (ORR.FilterByExchangePlanProperties.Rows.Count() = 0);
	
	ObjectProperties = New Structure;
	
	FieldSelectionText = "SELECT DISTINCT ExchangePlanMainTable.Ref AS Ref";
	
	// Table with data source (exchange plan tabular sections) names.
	DataTable = ORRData(ORR.FilterByExchangePlanProperties.Rows);
	
	TableDataText = GetDataTablesTextForORR(DataTable);
	
	If EmptyRule Then
		
		ConditionText = "True";
		
	Else
		
		ConditionText = GetPropertyGroupConditionText(ORR.FilterByExchangePlanProperties.Rows, BooleanRootPropertiesGroupValue, 0, ObjectProperties);
		
	EndIf;
	
	QueryText = FieldSelectionText + Chars.LF 
	             + "FROM"  + Chars.LF + TableDataText + Chars.LF // @query-part
	             + "WHERE" + Chars.LF + ConditionText
	             + Chars.LF + "[MandatoryConditions]";
	//
	
	// 
	ORR.QueryText    = QueryText;
	ORR.ObjectProperties = ObjectProperties;
	ORR.ObjectPropertiesAsString = GetObjectPropertiesAsString(ObjectProperties);
	
EndProcedure

Function GetPropertyGroupConditionText(GroupProperties, BooleanGroupValue, Val Offset, ObjectProperties)
	
	OffsetString = "";
	
	// Getting the offset string for the property group.
	For IterationNumber = 0 To Offset Do
		OffsetString = OffsetString + " ";
	EndDo;
	
	ConditionText = "";
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyGroupConditionText(RecordRuleByProperty.Rows, RecordRuleByProperty.BooleanGroupValue, Offset + 10, ObjectProperties);
			
		Else
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyConditionText(RecordRuleByProperty, ObjectProperties);
			
		EndIf;
		
	EndDo;
	
	ConditionText = "(" + ConditionText + Chars.LF 
				 + OffsetString + ")";
	
	Return ConditionText;
	
EndFunction

Function GetDataTablesTextForORR(DataTable)
	
	TableDataText = "ExchangePlan." + Registration.ExchangePlanName + " AS ExchangePlanMainTable";
	
	For Each TableRow In DataTable Do
		
		TableSynonym = Registration.ExchangePlanName + TableRow.Name;
		
		TableDataText = TableDataText + Chars.LF + Chars.LF + "LEFT JOIN" + Chars.LF
		                 + "ExchangePlan." + Registration.ExchangePlanName + "." + TableRow.Name + " AS " + TableSynonym + "" + Chars.LF
		                 + "On ExchangePlanMainTable.Ref = " + TableSynonym + ".Ref";
		
	EndDo;
	
	Return TableDataText;
	
EndFunction

Function ORRData(GroupProperties)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("Name");
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			// Retrieving a data table for the lowest hierarchical level
			GroupDataTable = ORRData(RecordRuleByProperty.Rows);
			
			// Adding received rows to the data table of the top hierarchical level
			For Each GroupTableRow In GroupDataTable Do
				
				FillPropertyValues(DataTable.Add(), GroupTableRow);
				
			EndDo;
			
		Else
			
			TableName = RecordRuleByProperty.NodeParameterTabularSection;
			
			// Skipping the empty table name as it is a node header property.
			If Not IsBlankString(TableName) Then
				
				TableRow = DataTable.Add();
				TableRow.Name = TableName;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// 
	DataTable.GroupBy("Name");
	
	Return DataTable;
	
EndFunction

Function GetPropertyConditionText(Rule, ObjectProperties)
	
	RuleComparisonKind = Rule.ComparisonType;
	
	// 
	// 
	// 
	InvertComparisonType(RuleComparisonKind);
	
	TextOperator = GetCompareOperatorText(RuleComparisonKind);
	
	TableSynonym = ?(IsBlankString(Rule.NodeParameterTabularSection),
	                              "ExchangePlanMainTable",
	                               Registration.ExchangePlanName + Rule.NodeParameterTabularSection);
	//
	
	// A query parameter or a constant value can be used as a literal
	//
	// Example:
	// ExchangePlanProperty <comparison type> &ObjectProperty_MyProperty
	// ExchangePlanProperty <comparison type> DATETIME(1987,10,19,0,0,0).
	
	If Rule.IsConstantString Then
		
		ConstantValueType = TypeOf(Rule.ConstantValue);
		
		If ConstantValueType = BooleanType Then // Boolean
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "BF=Ложь; BT=Истина");
			
		ElsIf ConstantValueType = NumberType Then // Number
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "NDS=.; NZ=0; NG=0; NN=1");
			
		ElsIf ConstantValueType = DateType Then // Date
			
			YearString     = Format(Year(Rule.ConstantValue),     "NZ=0; NG=0");
			MonthString   = Format(Month(Rule.ConstantValue),   "NZ=0; NG=0");
			DayString    = Format(Day(Rule.ConstantValue),    "NZ=0; NG=0");
			HourString     = Format(Hour(Rule.ConstantValue),     "NZ=0; NG=0");
			MinuteString  = Format(Minute(Rule.ConstantValue),  "NZ=0; NG=0");
			SecondString = Format(Second(Rule.ConstantValue), "NZ=0; NG=0");
			
			QueryParameterLiteral = "DATETIME("
			+ YearString + ","
			+ MonthString + ","
			+ DayString + ","
			+ HourString + ","
			+ MinuteString + ","
			+ SecondString
			+ ")";
			
		Else // String
			
			// 
			QueryParameterLiteral = """" + Rule.ConstantValue + """";
			
		EndIf;
		
	Else
		
		ObjectPropertyKey = StrReplace(Rule.ObjectProperty1, ".", "_");
		
		QueryParameterLiteral = "&ObjectProperty1_" + ObjectPropertyKey + "";
		
		ObjectProperties.Insert(ObjectPropertyKey, Rule.ObjectProperty1);
		
	EndIf;
	
	ConditionText = TableSynonym + "." + Rule.NodeParameter + " " + TextOperator + " " + QueryParameterLiteral;
	
	Return ConditionText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by object properties.

Procedure PrepareRegistrationRuleByObjectProperties(ORR)
	
	ORR.RuleByObjectPropertiesEmpty = (ORR.FilterByObjectProperties.Rows.Count() = 0);
	
	// Skipping the blank rule.
	If ORR.RuleByObjectPropertiesEmpty Then
		Return;
	EndIf;
	
	ObjectProperties = New Structure;
	
	FillObjectPropertyStructure(ORR.FilterByObjectProperties, ObjectProperties);
	
EndProcedure

Procedure FillObjectPropertyStructure(ValueTree, ObjectProperties)
	
	For Each TreeRow In ValueTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillObjectPropertyStructure(TreeRow, ObjectProperties);
			
		Else
			
			TreeRow.ObjectPropertyKey = StrReplace(TreeRow.ObjectProperty1, ".", "_");
			
			ObjectProperties.Insert(TreeRow.ObjectPropertyKey, TreeRow.ObjectProperty1);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal auxiliary procedures and functions.

Procedure ReportProcessingError(Code = -1, ErrorDescription = "")
	
	// 
	FlagErrors = True;
	
	If ErrorsMessages = Undefined Then
		ErrorsMessages = InitMessages();
	EndIf;
	
	MessageString = ErrorsMessages[Code];
	
	MessageString = ?(MessageString = Undefined, "", MessageString);
	
	If Not IsBlankString(ErrorDescription) Then
		
		MessageString = MessageString + Chars.LF + ErrorDescription;
		
	EndIf;
	
	WriteLogEvent(EventLogMessageKey(), EventLogLevel.Error,,, MessageString);
	
EndProcedure

Procedure InvertComparisonType(Var_ComparisonType)
	
	If      Var_ComparisonType = "Greater"         Then Var_ComparisonType = "Less";
	ElsIf Var_ComparisonType = "GreaterOrEqual" Then Var_ComparisonType = "LessOrEqual";
	ElsIf Var_ComparisonType = "Less"         Then Var_ComparisonType = "Greater";
	ElsIf Var_ComparisonType = "LessOrEqual" Then Var_ComparisonType = "GreaterOrEqual";
	EndIf;
	
EndProcedure

Procedure CheckExchangePlanExists()
	
	If TypeOf(Registration) <> Type("Structure") Then
		
		ReportProcessingError(0);
		Return;
		
	EndIf;
	
	If Registration.ExchangePlanName <> ExchangePlanNameForImport Then
		
		ErrorDescription = NStr("en = 'The exchange plan name specified in the registration rules (%1) does not match the exchange plan name whose data is imported (%2)';");
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, Registration.ExchangePlanName, ExchangePlanNameForImport);
		ReportProcessingError(5, ErrorDescription);
		
	EndIf;
	
EndProcedure

Function GetCompareOperatorText(Val Var_ComparisonType = "Equal")
	
	// Default return value.
	TextOperator = "=";
	
	If      Var_ComparisonType = "Equal"          Then TextOperator = "=";
	ElsIf Var_ComparisonType = "NotEqual"        Then TextOperator = "<>";
	ElsIf Var_ComparisonType = "Greater"         Then TextOperator = ">";
	ElsIf Var_ComparisonType = "GreaterOrEqual" Then TextOperator = ">=";
	ElsIf Var_ComparisonType = "Less"         Then TextOperator = "<";
	ElsIf Var_ComparisonType = "LessOrEqual" Then TextOperator = "<=";
	EndIf;
	
	Return TextOperator;
EndFunction

Function GetConfigurationPresentationFromRegistrationRules()
	
	ConfigurationName = "";
	Registration.Property("ConfigurationSynonym", ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Registration.Property("ConfigurationVersion", AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;
		
	EndIf;
	
	Return ConfigurationName;
		
EndFunction

Function GetObjectPropertiesAsString(ObjectProperties)
	
	Result = "";
	
	For Each Item In ObjectProperties Do
		
		Result = Result + Item.Value + " AS " + Item.Key + ", ";
		
	EndDo;
	
	// 
	StringFunctionsClientServer.DeleteLastCharInString(Result, 2);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For operations with the XMLReader object.

// Reads the attribute value by the name from the specified object, converts the value
// to the specified primitive type.
//
// Parameters:
//   Object      - XMLReader - an object positioned at the beginning of the item
//                 whose attribute is required.
//   Type         - Type - attribute type.
//   Name         - String - attribute name.
//
// Returns:
//   Arbitrary - 
//
Function deAttribute(Object, Type, Name)
	
	ValueStr = TrimR(Object.GetAttribute(Name));
	
	If Not IsBlankString(ValueStr) Then
		
		Return XMLValue(Type, ValueStr);
		
	Else
		If Type = StringType Then
			Return "";
			
		ElsIf Type = BooleanType Then
			Return False;
			
		ElsIf Type = NumberType Then
			Return 0;
			
		ElsIf Type = DateType Then
			Return BlankDateValue1;
			
		EndIf;
	EndIf;
	
EndFunction

// Reads the element text and converts the value to the specified type.
//
// Parameters:
//  Object           - XMLReader - an object whose data is read.
//  Type              - Type - type of the return value.
//  SearchByProperty - String - for reference types, you can specify a property
//                     to be used for searching the object: Code, Description, <AttributeName>, Name (predefined value).
//
// Returns:
//   Arbitrary - 
//
Function deElementValue(Object, Type, SearchByProperty="")

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeType.Text Then
			
			Value = TrimR(Object.Value);
			
		ElsIf (NodeName = Name) And (NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
	EndDo;
	
	Return XMLValue(Type, Value)
	
EndFunction

// Skips xml nodes to the end of the specified item (which is currently the default one).
//
// Parameters:
//  Object   - an object of the ReadXml type.
//  Name      - name of the node to skip elements to the end of.
//
Procedure deSkip(Object, Name = "")
	
	AttachmentsCount = 0; // 
	
	If IsBlankString(Name) Then
	
		Name = Object.LocalName;
	
	EndIf;
	
	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeName = Name Then
			
			If NodeType = XMLNodeType.EndElement Then
				
				If AttachmentsCount = 0 Then
					Break;
				Else
					AttachmentsCount = AttachmentsCount - 1;
				EndIf;
				
			ElsIf NodeType = XMLNodeType.StartElement Then
				
				AttachmentsCount = AttachmentsCount + 1;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions for retrieving properties.

Function EventLogMessageKey()
	
	Return DataExchangeServer.DataExchangeRulesImportEventLogEvent();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initializing attributes and modular variables.

// Initializes data processor attributes and module variables.
//
// Parameters:
//  No.
// 
Procedure InitAttributesAndModuleVariables()
	
	FlagErrors = False;
	
	// Типы
	StringType            = Type("String");
	BooleanType            = Type("Boolean");
	NumberType             = Type("Number");
	DateType              = Type("Date");
	
	BlankDateValue1 = Date('00010101');
	
	BooleanRootPropertiesGroupValue = "And"; // 
	
EndProcedure

// Initializes the registration structure.
//
// Parameters:
//  No.
// 
Function RecordInitialization()
	
	Registration = New Structure;
	Registration.Insert("FormatVersion",       "");
	Registration.Insert("ID_SSLy",                  "");
	Registration.Insert("Description",        "");
	Registration.Insert("CreationDateTime",   BlankDateValue1);
	Registration.Insert("ExchangePlan",          "");
	Registration.Insert("ExchangePlanName",      "");
	Registration.Insert("Comment",         "");
	
	// 
	Registration.Insert("PlatformVersion",     "");
	Registration.Insert("ConfigurationVersion",  "");
	Registration.Insert("ConfigurationSynonym", "");
	Registration.Insert("Configuration",        "");
	
	Return Registration;
	
EndFunction

// Initializes a variable that contains mapping of message codes and their description.
//
// Parameters:
//  No.
// 
Function InitMessages()
	
	Messages = New Map;
	DefaultLanguageCode = Common.DefaultLanguageCode();
	
	Messages.Insert(0, NStr("en = 'Internal error';", DefaultLanguageCode));
	Messages.Insert(1, NStr("en = 'Cannot open the exchange rules file.';", DefaultLanguageCode));
	Messages.Insert(2, NStr("en = 'Cannot load the exchange rules.';", DefaultLanguageCode));
	Messages.Insert(3, NStr("en = 'Exchange rule format error';", DefaultLanguageCode));
	Messages.Insert(4, NStr("en = 'Cannot get the exchange rules file.';", DefaultLanguageCode));
	Messages.Insert(5, NStr("en = 'The registration rules are not intended for the current exchange plan.';", DefaultLanguageCode));
	
	Return Messages;
	
EndFunction

#EndRegion

#Region Initialization

InitAttributesAndModuleVariables();

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf