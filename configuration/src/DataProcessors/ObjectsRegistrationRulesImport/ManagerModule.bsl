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

// Initializes columns of object registration rule table.
//
// Parameters:
//  No.
// 
Function ORRTableInitialization() Export
	
	ObjectsRegistrationRules = New ValueTable;
	
	Columns = ObjectsRegistrationRules.Columns;
	
	Columns.Add("SettingObject1");
	
	Columns.Add("MetadataObjectName3", New TypeDescription("String"));
	Columns.Add("ExchangePlanName",      New TypeDescription("String"));
	
	Columns.Add("FlagAttributeName", New TypeDescription("String"));
	
	Columns.Add("QueryText",    New TypeDescription("String"));
	Columns.Add("ObjectProperties", New TypeDescription("Structure"));
	
	Columns.Add("ObjectPropertiesAsString", New TypeDescription("String"));
	
	// 
	Columns.Add("RuleByObjectPropertiesEmpty",     New TypeDescription("Boolean"));
	
	Columns.Add("FilterByExchangePlanProperties", New TypeDescription("ValueTree"));
	Columns.Add("FilterByObjectProperties",     New TypeDescription("ValueTree"));
	
	// 
	Columns.Add("BeforeProcess",            New TypeDescription("String"));
	Columns.Add("OnProcess",               New TypeDescription("String"));
	Columns.Add("OnProcessAdditional", New TypeDescription("String"));
	Columns.Add("AfterProcess",             New TypeDescription("String"));
	
	Columns.Add("HasBeforeProcessHandler",            New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandler",               New TypeDescription("Boolean"));
	Columns.Add("HasOnProcessHandlerAdditional", New TypeDescription("Boolean"));
	Columns.Add("HasAfterProcessHandler",             New TypeDescription("Boolean"));
	
	Return ObjectsRegistrationRules;
	
EndFunction

// Initializes columns of object registration rule table by properties.
//
// Parameters:
//  No.
// 
Function FilterByExchangePlanPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",            New TypeDescription("Boolean"));
	Columns.Add("BooleanGroupValue", New TypeDescription("String"));
	
	Columns.Add("ObjectProperty1",      New TypeDescription("String"));
	Columns.Add("ComparisonType",         New TypeDescription("String"));
	Columns.Add("IsConstantString",   New TypeDescription("Boolean"));
	Columns.Add("ObjectPropertyType",   New TypeDescription("String"));
	
	Columns.Add("NodeParameter",                New TypeDescription("String"));
	Columns.Add("NodeParameterTabularSection", New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // 
	
	Return TreePattern;
	
EndFunction

// Initializes columns of object registration rule table by properties.
//
// Parameters:
//  No.
// 
Function FilterByObjectPropertiesTableInitialization() Export
	
	TreePattern = New ValueTree;
	
	Columns = TreePattern.Columns;
	
	Columns.Add("IsFolder",           New TypeDescription("Boolean"));
	Columns.Add("IsANDOperator",        New TypeDescription("Boolean"));
	
	Columns.Add("ObjectProperty1",     New TypeDescription("String"));
	Columns.Add("ObjectPropertyKey", New TypeDescription("String"));
	Columns.Add("ComparisonType",        New TypeDescription("String"));
	Columns.Add("ObjectPropertyType",  New TypeDescription("String"));
	Columns.Add("FilterItemKind",   New TypeDescription("String"));
	
	Columns.Add("ConstantValue"); // 
	Columns.Add("PropertyValue");  // 
	
	Return TreePattern;
	
EndFunction

#EndRegion

#EndIf