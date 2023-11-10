///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Creates a structure to describe columns for a template of importing data from file.
//
// Parameters:
//  Name        -String - Column name.
//  Type       - TypeDescription - column type.
//  Title - String - Column header displayed in the template for import.
//  Width    - Number - column width.
//  ToolTip - String - a tooltip displayed in the column header.
// 
// Returns:
//  Structure - 
//    * Name                       - String - Column name.
//    * Title                 - String - Column header displayed in the template for import.
//    * Type                       - TypeDescription - column type.
//    * Width                    - Number - column width.
//    * ToolTip                 - String - a tooltip displayed in the column header.
//    * RequiredForm - Boolean - True if a column must contain values.
//    * Group                    - String - Column group name.
//    * Parent                  - String - used to connect a dynamic column with an attribute of the object tabular section.
//
Function TemplateColumnDetails(Name, Type, Title = Undefined, Width = 0, ToolTip = "") Export
	
	TemplateColumn = New Structure("Name, Type, Title, Width, Position, ToolTip, IsRequiredInfo, Group, Parent");
	TemplateColumn.Name = Name;
	TemplateColumn.Type = Type;
	TemplateColumn.Title = ?(ValueIsFilled(Title), Title, Name);
	TemplateColumn.Width = ?(Width = 0, 30, Width);
	TemplateColumn.ToolTip = ToolTip;
	TemplateColumn.Parent = Name;
	
	Return TemplateColumn;
	
EndFunction

// Returns a template column by its name.
//
// Parameters:
//  Name				 - String - Column name.
//  ColumnsList	 - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
// 
// Returns:
//   See TemplateColumnDetails
//            - — Undefined — if the column does not exist.
//
Function TemplateColumn(Name, ColumnsList) Export
	For Each Column In ColumnsList Do
		If Column.Name = Name Then
			Return Column;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Deletes a template column from the array.
//
// Parameters:
//  Name           - String - Column name.
//  ColumnsList - Array of See ImportDataFromFileClientServer.TemplateColumnDetails
//
Procedure DeleteTemplateColumn(Name, ColumnsList) Export
	
	For IndexOf = 0 To ColumnsList.Count() -1  Do
		If ColumnsList[IndexOf].Name = Name Then
			ColumnsList.Delete(IndexOf);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function ColumnsHaveGroup(Val ColumnsInformation) Export
	ColumnsGroups = New Map;
	For Each TableColumn2 In ColumnsInformation Do
		ColumnsGroups.Insert(TableColumn2.Group);
	EndDo;
	Return ?(ColumnsGroups.Count() > 1, True, False);
EndFunction

Function PresentationOfTextYesForBoolean() Export
	Return NStr("en = 'Yes';");
EndFunction

#EndRegion
