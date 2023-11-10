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
	
	CloseOnOwnerClose = True;
	CloseOnChoice = False;
	
	Object.InfobaseNode = Parameters.InfobaseNode;
	
	SelectionTree = FormAttributeToValue("AvailableObjectKinds");
	SelectionTreeRows = SelectionTree.Rows;
	SelectionTreeRows.Clear();
	
	AllData = DataExchangeCached.ExchangePlanContent(Object.InfobaseNode.Metadata().Name);

	// Hiding items with DoNotExport set.
	NotExportMode = Enums.ExchangeObjectExportModes.NotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanComposition(Object.InfobaseNode);
	Position = AllData.Count() - 1;
	While Position >= 0 Do
		DataString1 = AllData[Position];
		If ExportModes[DataString1.FullMetadataName] = NotExportMode Then
			AllData.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	// 
	AllData.FillValues(-1, "PictureIndex");
	
	AddAllObjects(AllData, SelectionTreeRows);
	
	ValueToFormAttribute(SelectionTree, "AvailableObjectKinds");
	
	ColumnsToSelect = "";
	For Each Attribute In GetAttributes("AvailableObjectKinds") Do
		ColumnsToSelect = ColumnsToSelect + "," + Attribute.Name;
	EndDo;
	ColumnsToSelect = Mid(ColumnsToSelect, 2);
	
EndProcedure

#EndRegion

#Region AvailableObjectKindsFormTableItemEventHandlers

&AtClient
Procedure AvailableObjectKindsSelection(Item, RowSelected, Field, StandardProcessing)
	ExecuteSelection(RowSelected);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickAndClose(Command)
	ExecuteSelection();
	Close();
EndProcedure

&AtClient
Procedure Pick(Command)
	ExecuteSelection();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ThisObject(NewObject = Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteSelection(RowSelected = Undefined)
	
	FormTable = Items.AvailableObjectKinds;
	ChoiceData = New Array;
	
	If RowSelected = Undefined Then
		For Each String In FormTable.SelectedRows Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(String) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	ElsIf TypeOf(RowSelected) = Type("Array") Then
		For Each String In RowSelected Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(String) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	Else
		ChoiceItem = New Structure(ColumnsToSelect);
		FillPropertyValues(ChoiceItem, FormTable.RowData(RowSelected) );
		ChoiceData.Add(ChoiceItem);
	EndIf;
	
	NotifyChoice(ChoiceData);
EndProcedure

&AtServer
Procedure AddAllObjects(AllRefNodeData, DestinationRows)
	
	ThisDataProcessor = ThisObject();
	
	DocumentsGroup = DestinationRows.Add();
	DocumentsGroup.ListPresentation = ThisDataProcessor.AllDocumentsFilterGroupTitle();
	DocumentsGroup.FullMetadataName = ThisDataProcessor.AllDocumentsID();
	DocumentsGroup.PictureIndex = 7;
	
	CatalogGroup = DestinationRows.Add();
	CatalogGroup.ListPresentation = ThisDataProcessor.AllCatalogsFilterGroupTitle();
	CatalogGroup.FullMetadataName = ThisDataProcessor.AllCatalogsID();
	CatalogGroup.PictureIndex = 3;
	
	For Each String In AllRefNodeData Do
		If String.PeriodSelection Then
			FillPropertyValues(DocumentsGroup.Rows.Add(), String);
		Else
			FillPropertyValues(CatalogGroup.Rows.Add(), String);
		EndIf;
	EndDo;
	
	// Delete empty items.
	If DocumentsGroup.Rows.Count() = 0 Then
		DestinationRows.Delete(DocumentsGroup);
	EndIf;
	If CatalogGroup.Rows.Count() = 0 Then
		DestinationRows.Delete(CatalogGroup);
	EndIf;
	
EndProcedure

#EndRegion
