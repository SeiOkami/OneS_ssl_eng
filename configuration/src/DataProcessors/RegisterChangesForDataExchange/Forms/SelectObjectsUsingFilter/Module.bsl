///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataTableName = Parameters.TableName;
	CurrentObject = ThisObject();
	TableHeading  = "";
	
	// Determining what kind of table is passed to the procedure.
	LongDesc = CurrentObject.MetadataCharacteristics(DataTableName);
	MetaInfo = LongDesc.Metadata;
	Title = MetaInfo.Presentation();
	
	// List and columns.
	StructureOfData = "";
	If LongDesc.IsReference Then
		TableHeading = MetaInfo.ObjectPresentation;
		If IsBlankString(TableHeading) Then
			TableHeading = Title;
		EndIf;
		
		DataList.CustomQuery = False;
		
		ListProperties = DynamicListPropertiesStructure();
		ListProperties.DynamicDataRead = True;
		ListProperties.MainTable = DataTableName;
		
		SetDynamicListProperties(Items.DataList, ListProperties);
		
		Field = DataList.Filter.FilterAvailableFields.Items.Find(New DataCompositionField("Ref"));
		ColumnsTable1 = New ValueTable;
		Columns = ColumnsTable1.Columns;
		Columns.Add("Ref", Field.ValueType, TableHeading);
		StructureOfData = "Ref";
		
		DataFormKey = "Ref";
		
	ElsIf LongDesc.IsRecordsSet Then
		Columns = CurrentObject.RecordSetDimensions(MetaInfo);
		For Each CurrentColumnItem In Columns Do
			StructureOfData = StructureOfData + "," + CurrentColumnItem.Name;
		EndDo;
		StructureOfData = Mid(StructureOfData, 2);
		
		DataList.CustomQuery = True;
		
		QueryTextTemplate2 = 
		"SELECT DISTINCT
		|	&NamesOfFieldsAndDetails
		|FROM
		|	&MetadataTableName AS MetadataTableName";
		
		QueryText = StrReplace(QueryTextTemplate2, "&NamesOfFieldsAndDetails", StructureOfData);
		QueryText = StrReplace(QueryText, "&MetadataTableName", DataTableName);
		
		ListProperties = DynamicListPropertiesStructure();
		ListProperties.DynamicDataRead = True;
		ListProperties.QueryText = QueryText;
		
		SetDynamicListProperties(Items.DataList, ListProperties);
		
		If LongDesc.IsSequence Then
			DataFormKey = "Recorder";
		Else
			DataFormKey = New Structure(StructureOfData);
		EndIf;
			
	Else
		// 
		Return;
	EndIf;
	
	CurrentObject.AddColumnsToFormTable(
		Items.DataList, 
		"Order, Filter, Group, StandardPicture, Parameters, ConditionalAppearance",
		Columns);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
//

&AtClient
Procedure FilterOnChange(Item)
	
	Items.DataList.Refresh();
	
EndProcedure

#EndRegion

#Region DataListFormTableItemEventHandlers
//

&AtClient
Procedure DataListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	OpenCurrentObjectForm();
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure OpenCurrentObject(Command)
	OpenCurrentObjectForm();
EndProcedure

&AtClient
Procedure SelectFilteredValues(Command)
	MakeChoice(True);
EndProcedure

&AtClient
Procedure SelectCurrentRow(Command)
	MakeChoice(False);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDynamicListProperties(List, ParametersStructure)
	
	Form = List.Parent;
	
	While TypeOf(Form) <> Type("ClientApplicationForm") Do
		Form = Form.Parent;
	EndDo;
	
	DynamicList = Form[List.DataPath];
	QueryText = ParametersStructure.QueryText;
	
	If Not IsBlankString(QueryText) Then
		DynamicList.QueryText = QueryText;
	EndIf;
	
	MainTable = ParametersStructure.MainTable;
	
	If Not IsBlankString(MainTable) Then
		DynamicList.MainTable = MainTable;
	EndIf;
	
	DynamicDataRead = ParametersStructure.DynamicDataRead;
	
	If TypeOf(DynamicDataRead) = Type("Boolean") Then
		DynamicList.DynamicDataRead = DynamicDataRead;
	EndIf;
	
EndProcedure

&AtServer
Function DynamicListPropertiesStructure()
	
	Return New Structure("QueryText, MainTable, DynamicDataRead");
	
EndFunction

&AtClient
Procedure OpenCurrentObjectForm()
	CurParameters = CurrentObjectFormParameters(Items.DataList.CurrentData);
	If CurParameters <> Undefined Then
		OpenForm(CurParameters.FormName, CurParameters.Key);
	EndIf;
EndProcedure

&AtClient
Procedure MakeChoice(WholeFilterResult = True)
	
	If WholeFilterResult Then
		Data = AllSelectedItems();
	Else
		Data = New Array;
		For Each CurRow In Items.DataList.SelectedRows Do
			Item = New Structure(StructureOfData);
			FillPropertyValues(Item, Items.DataList.RowData(CurRow));
			Data.Add(Item);
		EndDo;
	EndIf;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("TableName", Parameters.TableName);
	ParametersStructure.Insert("ChoiceData", Data);
	ParametersStructure.Insert("ChoiceAction", Parameters.ChoiceAction);
	ParametersStructure.Insert("FieldsStructure", StructureOfData);
	NotifyChoice(ParametersStructure);
EndProcedure

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CurrentObjectFormParameters(Val Data)
	
	If Data = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(DataFormKey) = Type("String") Then
		Value = Data[DataFormKey];
		CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
	Else
		// The structure contains dimension names.
		If Data.Property("Recorder") Then
			Value = Data.Recorder;
			CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
		Else

			FillPropertyValues(DataFormKey, Data);
			CurFormName = Parameters.TableName + ".RecordForm";
			
			Position = StrFind(Parameters.TableName, ".");
			Manager = InformationRegisters[Mid(Parameters.TableName, Position + 1)];			
			
			DataProcessorObject = ThisObject();
			Set = Manager.CreateRecordSet();                              
			
			For Each KeyValue In DataFormKey Do
				DataProcessorObject.SetFilterItemValue(Set.Filter, KeyValue.Key, KeyValue.Value);
			EndDo;
			
			Set.Read();
						
			Var_Key = New Structure;
			For Each SetColumn In Set.Unload().Columns Do
				ColumnName = SetColumn.Name;
				Var_Key.Insert(ColumnName, Set[0][ColumnName]);
			EndDo;
			
			Value = Manager.CreateRecordKey(Var_Key);
			
		EndIf;
		
	EndIf;
	Result = New Structure("FormName", CurFormName);
	Result.Insert("Key", New Structure("Key", Value));
	Return Result;
EndFunction

&AtServer
Function AllSelectedItems()
	
	Data = ThisObject().DynamicListCurrentData(DataList);
	
	Result = New Array();
	For Each CurRow In Data Do
		Item = New Structure(StructureOfData);
		FillPropertyValues(Item, CurRow);
		Result.Add(Item);
	EndDo;
	
	Return Result;
EndFunction	

#EndRegion
