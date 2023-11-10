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

Var ObjectsTree;
Var AdditionDependencies;
Var DeletionDependencies;
Var StandardInterfaceComposition;

#EndRegion

#Region Internal

Function InitializeDataToSetUpStandardODataInterfaceComposition() Export
	
	// Filling in tree root rows by metadata object collections.
	AddTreeRootRow("Constant", NStr("en = 'Constants';"), 1, PictureLib.Constant);
	AddTreeRootRow("Catalog", NStr("en = 'Catalogs';"), 2, PictureLib.Catalog);
	AddTreeRootRow("Document", NStr("en = 'Documents';"), 3, PictureLib.Document);
	AddTreeRootRow("DocumentJournal", NStr("en = 'Document journals';"), 4, PictureLib.DocumentJournal);
	AddTreeRootRow("Enum", NStr("en = 'Enumeration';"), 5, PictureLib.Enum);
	AddTreeRootRow("ChartOfCharacteristicTypes", NStr("en = 'Charts of characteristic types';"), 6, PictureLib.ChartOfCharacteristicTypes);
	AddTreeRootRow("ChartOfAccounts", NStr("en = 'Charts of accounts';"), 7, PictureLib.ChartOfAccounts);
	AddTreeRootRow("ChartOfCalculationTypes", NStr("en = 'Charts of calculation types';"), 8, PictureLib.ChartOfCalculationTypes);
	AddTreeRootRow("InformationRegister", NStr("en = 'Information registers';"), 9, PictureLib.InformationRegister);
	AddTreeRootRow("AccumulationRegister", NStr("en = 'Accumulation registers';"), 10, PictureLib.AccumulationRegister);
	AddTreeRootRow("AccountingRegister", NStr("en = 'Accounting registers';"), 11, PictureLib.AccountingRegister);
	AddTreeRootRow("CalculationRegister", NStr("en = 'Calculation registers';"), 12, PictureLib.CalculationRegister);
	AddTreeRootRow("BusinessProcess", NStr("en = 'Business processes';"), 13, PictureLib.BusinessProcess);
	AddTreeRootRow("Task", NStr("en = 'Tasks';"), 14, PictureLib.Task);
	AddTreeRootRow("ExchangePlan", NStr("en = 'Exchange plans';"), 15, PictureLib.ExchangePlan);
	
	// Read the current content of the standard OData interface.
	SystemComposition = GetStandardODataInterfaceContent();
	StandardInterfaceComposition = New Array();
	For Each Item In SystemComposition Do
		StandardInterfaceComposition.Add(Item.FullName());
	EndDo;
	
	// Read the model of data to provide to the standard OData interface.
	Model = DataProcessors.SetUpStandardODataInterface.ModelOfDataToProvideForStandardODataInterface();
	
	// Populate nested tree rows by model metadata objects.
	For Each ModelItem In Model Do
		
		FullName = ModelItem.FullName;
		IsReadOnlyObject = Not ModelItem.Update;
		IsObjectIncludedInComposition = (StandardInterfaceComposition.Find(ModelItem.FullName) <> Undefined);
		Dependencies = ModelItem.Dependencies;
		
		If Common.MetadataObjectAvailableByFunctionalOptions(FullName) Then
			
			AddNestedTreeRow(FullName, IsReadOnlyObject,
				IsObjectIncludedInComposition, Dependencies);
			
		EndIf;
		
	EndDo;
	
	// Delete root rows from metadata collections that have no objects to include.
	LinesToDelete = New Array();
	For Each TreeRow In ObjectsTree.Rows Do
		If TreeRow.Rows.Count() = 0 Then
			LinesToDelete.Add(TreeRow);
		EndIf;
	EndDo;
	For Each RowToDelete In LinesToDelete Do
		ObjectsTree.Rows.Delete(RowToDelete);
	EndDo;
	
	// Sort nested rows by metadata object presentation.
	For Each NestedRow In ObjectsTree.Rows Do
		NestedRow.Rows.Sort("Presentation");
	EndDo;
	
	Result = New Structure();
	Result.Insert("ObjectsTree", ObjectsTree);
	Result.Insert("AdditionDependencies", AdditionDependencies);
	Result.Insert("DeletionDependencies", DeletionDependencies);
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Procedure AddNestedTreeRow(Val FullName, Val ReadOnly, Val Use, Val Dependencies)
	
	NameStructure = StrSplit(FullName, ".");
	ObjectClass = NameStructure[0];
	
	RowOwner = Undefined;
	For Each TreeRow In ObjectsTree.Rows Do
		If TreeRow.FullName = ObjectClass Then
			RowOwner = TreeRow;
			Break;
		EndIf;
	EndDo;
	
	If RowOwner = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown metadata object: %1';"), FullName);
	EndIf;
	
	NewRow = RowOwner.Rows.Add();
	
	NewRow.FullName = FullName;
	NewRow.Presentation = MetadataObjectPresentation(FullName);
	NewRow.Class = RowOwner.Class;
	NewRow.Picture = RowOwner.Picture;
	NewRow.Use = StandardInterfaceComposition.Find(FullName) <> Undefined;
	NewRow.Subordinated = ODataInterfaceInternal.IsRecordSet(FullName)
		And Not IsIndependentRecordSet(FullName);
	NewRow.ReadOnly = ReadOnly;
	NewRow.Use = Use;
	
	For Each ObjectDependency In Dependencies Do
		
		If Common.MetadataObjectAvailableByFunctionalOptions(ObjectDependency) Then
			
			// If add the MetadataObject object, then add the ObjectDependency object.
			String = AdditionDependencies.Add();
			String.ObjectName = FullName;
			String.DependentObjectName = ObjectDependency;
			
			// 
			String = DeletionDependencies.Add();
			String.ObjectName = ObjectDependency;
			String.DependentObjectName = FullName;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AddTreeRootRow(Val FullName, Val Presentation, Val Class, Val Picture)
	
	NewRow = ObjectsTree.Rows.Add();
	NewRow.FullName = FullName;
	NewRow.Presentation = Presentation;
	NewRow.Class = Class;
	NewRow.Picture = Picture;
	NewRow.Subordinated = False;
	NewRow.ReadOnly = False;
	NewRow.Root = True;
	
EndProcedure

// Returns a metadata object presentation.
//
// Parameters:
//  MetadataObject.
//
// Returns:
//   String - Metadata object presentation.
//
Function MetadataObjectPresentation(Val MetadataObject) Export
	
	MetadataObjectProperties1 = ODataInterfaceInternal.ConfigurationModelObjectProperties(
		ODataInterfaceInternalCached.ConfigurationDataModelDetails(), MetadataObject);
		
	Return MetadataObjectProperties1.Presentation;
	
EndFunction

// Checks whether the passed metadata object is an independent record set.
//
// Parameters:
//  MetadataObject - Metadata object being checked.
//
// Returns:
//   Boolean
//
Function IsIndependentRecordSet(Val MetadataObject) Export
	
	If TypeOf(MetadataObject) = Type("String") Then
		MetadataObject = Common.MetadataObjectByFullName(MetadataObject);
	EndIf;
	
	Return Common.IsInformationRegister(MetadataObject)
		And MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent;
	
EndFunction

#EndRegion

#Region Initialization

ObjectsTree = New ValueTree();
ObjectsTree.Columns.Add("FullName", New TypeDescription("String"));
ObjectsTree.Columns.Add("Presentation", New TypeDescription("String"));
ObjectsTree.Columns.Add("Class", New TypeDescription("Number", , New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
ObjectsTree.Columns.Add("Picture", New TypeDescription("Picture"));
ObjectsTree.Columns.Add("Use", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("Subordinated", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("ReadOnly", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("Root", New TypeDescription("Boolean"));

StandardInterfaceComposition = New Array();

AdditionDependencies = New ValueTable();
AdditionDependencies.Columns.Add("ObjectName", New TypeDescription("String"));
AdditionDependencies.Columns.Add("DependentObjectName", New TypeDescription("String"));

DeletionDependencies = New ValueTable();
DeletionDependencies.Columns.Add("ObjectName", New TypeDescription("String"));
DeletionDependencies.Columns.Add("DependentObjectName", New TypeDescription("String"));

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf