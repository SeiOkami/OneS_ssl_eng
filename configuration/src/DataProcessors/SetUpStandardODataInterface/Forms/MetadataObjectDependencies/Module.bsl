///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MetadataObject = Common.MetadataObjectByFullName(Parameters.FullObjectName);
	
	If Common.IsConstant(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'constant';");
	ElsIf Common.IsCatalog(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'catalog';");
	ElsIf Common.IsDocument(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'document';");
	ElsIf ODataInterfaceInternal.IsSequenceRecordSet(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'sequence';");
	ElsIf Common.IsDocumentJournal(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'document journal';");
	ElsIf Common.IsEnum(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'enumeration';");
	ElsIf Common.IsChartOfCharacteristicTypes(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'chart of characteristic types';");
	ElsIf Common.IsChartOfAccounts(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'chart of accounts';");
	ElsIf Common.IsChartOfCalculationTypes(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'chart of calculation types';");
	ElsIf Common.IsInformationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'information register';");
	ElsIf Common.IsAccumulationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'accumulation register';");
	ElsIf Common.IsAccountingRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'accounting register';");
	ElsIf Common.IsCalculationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'calculation register';");
	ElsIf ODataInterfaceInternal.IsRecalculationRecordSet(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'recalculation';");
	ElsIf Common.IsBusinessProcess(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'business process';");
	ElsIf Common.IsTask(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'task';");
	ElsIf Common.IsExchangePlan(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'exchange plan';");
	EndIf;
	
	If Parameters.Create Then
		
		Items.GroupPageHeader.CurrentPage = Items.PageHeaderAddGroup;
		Items.PagesFooterGroup.CurrentPage = Items.PageFooterAddGroup;
		Items.TitleHeaderAddDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.TitleHeaderAddDecoration.Title,
			ObjectTypePresentation,
			MetadataObject.Presentation());
		
	Else
		
		Items.GroupPageHeader.CurrentPage = Items.PageHeaderDeletionGroup;
		Items.PagesFooterGroup.CurrentPage = Items.PageFooterDeleteGroup;
		Items.TitleHeaderDeletionDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.TitleHeaderDeletionDecoration.Title,
			ObjectTypePresentation,
			MetadataObject.Presentation());
		
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		Title, MetadataObject.Presentation());
	
	// Populate tree.
	
	Tree = New ValueTree();
	
	Tree.Columns.Add("FullName", New TypeDescription("String"));
	Tree.Columns.Add("Presentation", New TypeDescription("String"));
	Tree.Columns.Add("Class", New TypeDescription("Number", , New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
	Tree.Columns.Add("Picture", New TypeDescription("Picture"));
	
	AddTreeRootRow(Tree, "Constant", NStr("en = 'Constants';"), 1, PictureLib.Constant);
	AddTreeRootRow(Tree, "Catalog", NStr("en = 'Catalogs';"), 2, PictureLib.Catalog);
	AddTreeRootRow(Tree, "Document", NStr("en = 'Documents';"), 3, PictureLib.Document);
	AddTreeRootRow(Tree, "DocumentJournal", NStr("en = 'Document journals';"), 4, PictureLib.DocumentJournal);
	AddTreeRootRow(Tree, "Enum", NStr("en = 'Enumeration';"), 5, PictureLib.Enum);
	AddTreeRootRow(Tree, "ChartOfCharacteristicTypes", NStr("en = 'Charts of characteristic types';"), 6, PictureLib.ChartOfCharacteristicTypes);
	AddTreeRootRow(Tree, "ChartOfAccounts", NStr("en = 'Charts of accounts';"), 7, PictureLib.ChartOfAccounts);
	AddTreeRootRow(Tree, "ChartOfCalculationTypes", NStr("en = 'Charts of calculation types';"), 8, PictureLib.ChartOfCalculationTypes);
	AddTreeRootRow(Tree, "InformationRegister", NStr("en = 'Information registers';"), 9, PictureLib.InformationRegister);
	AddTreeRootRow(Tree, "AccumulationRegister", NStr("en = 'Accumulation registers';"), 10, PictureLib.AccumulationRegister);
	AddTreeRootRow(Tree, "AccountingRegister", NStr("en = 'Accounting registers';"), 11, PictureLib.AccountingRegister);
	AddTreeRootRow(Tree, "CalculationRegister", NStr("en = 'Calculation registers';"), 12, PictureLib.CalculationRegister);
	AddTreeRootRow(Tree, "BusinessProcess", NStr("en = 'Business processes';"), 13, PictureLib.BusinessProcess);
	AddTreeRootRow(Tree, "Task", NStr("en = 'Tasks';"), 14, PictureLib.Task);
	AddTreeRootRow(Tree, "ExchangePlan", NStr("en = 'Exchange plans';"), 15, PictureLib.ExchangePlan);
	
	For Each Dependence In Parameters.ObjectDependencies Do
		AddNestedTreeRow(Tree, Common.MetadataObjectByFullName(Dependence));
	EndDo;
	
	Tree.Columns.Delete(Tree.Columns["FullName"]);
	Tree.Columns.Delete(Tree.Columns["Class"]);
	
	LinesToDelete = New Array();
	For Each TreeRow In Tree.Rows Do
		If TreeRow.Rows.Count() = 0 Then
			LinesToDelete.Add(TreeRow);
		Else
			TreeRow.Rows.Sort("Presentation");
		EndIf;
	EndDo;
	For Each RowToDelete In LinesToDelete Do
		Tree.Rows.Delete(RowToDelete);
	EndDo;
	
	ValueToFormAttribute(Tree, "MetadataObjects");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddTreeRootRow(Tree,Val FullName, Val Presentation, Val Class, Val Picture)
	
	NewRow = Tree.Rows.Add();
	NewRow.FullName = FullName;
	NewRow.Presentation = Presentation;
	NewRow.Class = Class;
	NewRow.Picture = Picture;
	
EndProcedure

&AtServer
Procedure AddNestedTreeRow(Tree, Val MetadataObject)
	
	FullName = MetadataObject.FullName();
	
	NameStructure = StrSplit(FullName, ".");
	ObjectClass = NameStructure[0];
	
	RowOwner = Undefined;
	For Each TreeRow In Tree.Rows Do
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
	
	NewRow.Presentation = MetadataObject.Presentation();
	NewRow.Class = RowOwner.Class;
	NewRow.Picture = RowOwner.Picture;
	
EndProcedure

#EndRegion