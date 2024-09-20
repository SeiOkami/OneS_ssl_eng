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
	
	AttributeTree = FormAttributeToValue("ObjectAttributes");
	ObjectAttributeCollection = AttributeTree.Rows;
	
	SelectedAllAttributes = Parameters.Filter.Count() = 0 Or Parameters.Filter[0] = "*";
	MetadataObject = Parameters.Ref.Metadata();
	For Each AttributeDetails In MetadataObject.Attributes Do
		Attribute = ObjectAttributeCollection.Add();
		FillPropertyValues(Attribute, AttributeDetails);
		Attribute.Check = SelectedAllAttributes Or Parameters.Filter.Find(AttributeDetails.Name) <> Undefined;
		Attribute.Synonym = AttributeDetails.Presentation();
	EndDo;
	
	ObjectAttributeCollection.Sort("Synonym");
	
	For Each TabularSectionDetails In MetadataObject.TabularSections Do
		TabularSection = ObjectAttributeCollection.Add();
		FillPropertyValues(TabularSection, TabularSectionDetails);
		SelectedAllTabularSection = SelectedAllAttributes Or Parameters.Filter.Find(TabularSectionDetails.Name + ".*") <> Undefined;
		HasSelectedItems = SelectedAllTabularSection;
		For Each AttributeDetails In TabularSectionDetails.Attributes Do
			Attribute = TabularSection.Rows.Add();
			FillPropertyValues(Attribute, AttributeDetails);
			Attribute.Synonym = AttributeDetails.Presentation();
			Attribute.Check = SelectedAllAttributes Or SelectedAllTabularSection Or Parameters.Filter.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined;
			HasSelectedItems = HasSelectedItems Or Attribute.Check;
		EndDo;
		TabularSection.Check = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllTabularSection), HasSelectedItems);
		TabularSection.Rows.Sort("Synonym");
	EndDo;
	
	ValueToFormAttribute(AttributeTree, "ObjectAttributes");
	
	ObjectsVersioningOverridable.OnSelectObjectAttributes(Parameters.Ref, ObjectAttributes);
EndProcedure

#EndRegion

#Region ObjectAttributesFormTableItemEventHandlers

&AtClient
Procedure ObjectAttributesCheckOnChange(Item)
	
	OnCheckChange(Items.ObjectAttributes, "Check");
	SetSelectionButtonAvailability();

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckAll(Command)
	SelectOrClearAll(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SelectOrClearAll(False);
EndProcedure

&AtClient
Procedure Select(Command)
	Result = New Structure;
	Result.Insert("SelectedAttributes", SelectedAttributes(ObjectAttributes.GetItems()));
	Result.Insert("SelectedItemsPresentation", SelectedAttributePresentation());

	Close(Result);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectOrClearAll(Check)
	For Each Attribute In ObjectAttributes.GetItems() Do 
		Attribute.Check = Check;
		For Each SubordinateAttribute In Attribute.GetItems() Do
			SubordinateAttribute.Check = Check;
		EndDo;
	EndDo;
	SetSelectionButtonAvailability();
EndProcedure

&AtClient
Function SelectedAttributes(AttributesCollection)
	Result = New Array;
	SelectedAllAttributes = True;
	
	For Each Attribute In AttributesCollection Do
		SubordinateAttributes = Attribute.GetItems();
		If SubordinateAttributes.Count() > 0 Then
			SelectedItemsList = SelectedAttributes(SubordinateAttributes);
			SelectedAllAttributes = SelectedAllAttributes And SelectedItemsList.Count() = 1 And SelectedItemsList[0] = "*";
			For Each SubordinateAttribute In SelectedItemsList Do
				Result.Add(Attribute.Name + "." + SubordinateAttribute);
			EndDo;
		Else
			SelectedAllAttributes = SelectedAllAttributes And Attribute.Check;
			If Attribute.Check Then
				Result.Add(Attribute.Name);
			EndIf;
		EndIf;
	EndDo;
	
	If SelectedAllAttributes Then
		Result.Clear();
		Result.Add("*");
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function SelectedAttributePresentation()
	Result = StrConcat(SelectedAttributeSynonyms(), ", ");
	If Result = "*" Then
		Result = NStr("en = 'All attributes';");
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SelectedAttributeSynonyms()
	Result = New Array;
	
	AttributesCollection = FormAttributeToValue("ObjectAttributes");
	
	SelectedAttributes = AttributesCollection.Rows.FindRows(New Structure("Check", 1));
	If SelectedAttributes.Count() = AttributesCollection.Rows.Count() Then
		Result.Add("*");
		Return Result;
	EndIf;
	
	For Each Attribute In SelectedAttributes Do
		Result.Add(Attribute.Synonym);
	EndDo;
	
	SelectedAttributes = AttributesCollection.Rows.FindRows(New Structure("Check", 2));
	For Each Attribute In SelectedAttributes Do
		SubordinateAttributes = Attribute.Rows;
		For Each SubordinateAttribute In SubordinateAttributes Do
			If SubordinateAttribute.Check Then
				Result.Add(Attribute.Synonym + "." + SubordinateAttribute.Synonym);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction


// Selects linked check boxes.
&AtClient
Procedure OnCheckChange(FormTree, CheckBoxName)
	
	CurrentData = FormTree.CurrentData;
	
	If CurrentData[CheckBoxName] = 2 Then
		CurrentData[CheckBoxName] = 0;
	EndIf;
	
	Check = CurrentData[CheckBoxName];
	
	// Update subordinate flags.
	For Each SubordinateAttribute In CurrentData.GetItems() Do
		SubordinateAttribute[CheckBoxName] = Check;
	EndDo;
	
	// Update the parent flag.
	Parent = CurrentData.GetParent();
	If Parent <> Undefined Then
		HasSelectedItems = False;
		SelectedAllItems = True;
		For Each Item In Parent.GetItems() Do
			HasSelectedItems = HasSelectedItems Or Item[CheckBoxName];
			SelectedAllItems = SelectedAllItems And Item[CheckBoxName];
		EndDo;
		Parent[CheckBoxName] = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
	EndIf;

EndProcedure

&AtClient
Procedure SetSelectionButtonAvailability()
	Items.ObjectAttributesSelect.Enabled = SelectedAttributes(ObjectAttributes.GetItems()).Count() > 0
EndProcedure

#EndRegion
