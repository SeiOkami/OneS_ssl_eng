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
	
	ActiveFilter = Parameters.ActiveFilter;
	DataSeparationMap = New Map;
	If ActiveFilter.Count() > 0 Then
		
		For Each SessionSeparator In ActiveFilter Do
			DataSeparationArray = StrSplit(SessionSeparator.Value, "=", False);
			DataSeparationMap.Insert(DataSeparationArray[0], DataSeparationArray[1]);
		EndDo;
		
	EndIf;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		TableRow = SessionDataSeparation.Add();
		TableRow.Separator = CommonAttribute.Name;
		TableRow.SeparatorPresentation = CommonAttribute.Synonym;
		SeparatorValue = DataSeparationMap[CommonAttribute.Name];
		If SeparatorValue <> Undefined Then
			TableRow.CheckBox = True;
			TableRow.SeparatorValue = DataSeparationMap[CommonAttribute.Name];
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	Result = New ValueList;
	For Each TableRow In SessionDataSeparation Do
		If TableRow.CheckBox Then
			SeparatorValue = TableRow.Separator + "=" + TableRow.SeparatorValue;
			SeparatorPresentation = TableRow.SeparatorPresentation + " = " + TableRow.SeparatorValue;
			Result.Add(SeparatorValue, SeparatorPresentation);
		EndIf;
	EndDo;
	
	Notify("EventLogFilterItemValueChoice",
		Result,
		FormOwner);
	
	Close();
EndProcedure

&AtClient
Procedure SelectAllCommand(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = True;
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = False;
	EndDo;
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

#EndRegion