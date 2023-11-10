///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Called in the event handler of the report form after executing the form code.
// See "ClientApplicationForm.OnCreateAtServer" in Syntax Assistant and ReportsClientOverridable.CommandHandler.
//
// Parameters:
//   Form - ClientApplicationForm - report form.
//         - ManagedFormExtensionForReports
//         - Structure:
//           * ReportSettings - See ReportsClientServer.DefaultReportSettings
//   Cancel - Boolean - indicates that the form creation is canceled.
//   StandardProcessing - Boolean - indicates whether standard (system) event processing is executed.
//
// Example:
//	//Adding a command with a handler to ReportsClientOverridable.CommandHandler:
//	Command = ReportForm.Commands.Add("MySpecialCommand");
//	Command.Action = Attachable_Command;
//	Command.Header = NStr("en = 'My command…'");
//	
//	Button = ReportForm.Items.Add(Command.Name, Type("FormButton"), ReportForm.Items.<SubmenuName>);
//	Button.CommandName = Command.Name;
//	
//	ReportForm.ConstantCommands.Add(CreateCommand.Name);
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	
	
EndProcedure

// Called in the event handler of the report form and the report settings form.
// See "Managed form extension for reports.BeforeLoadOptionAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - Report form or a report settings form.
//   NewDCSettings - DataCompositionSettings - settings to load into the settings composer.
//
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	
	
EndProcedure

//  
// 
// 
// 
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForReports
//        - Undefined - report form.
//  SettingProperties - Structure - details of the report setup that will be displayed in the report form where:
//      * DCField - DataCompositionField - Setting to be output.
//      * TypeDescription - TypeDescription - Type of a setting to be output.
//      * ValuesForSelection - ValueList - specify objects that will be offered to a user in the choice list.
//                            The parameter adds items to the list of objects previously selected by a user.
//                            However, do not assign a new value list to this parameter.
//      * SelectionValuesQuery - Query - specify a query to select objects that are required to be added into 
//                               ValuesForSelection. As the first column (with 0 index), select the object,
//                               that has to be added to the ValuesForSelection.Value.
//                               To disable autofilling, write a blank string
//                               to the SelectionValuesQuery.Text property.
//      * RestrictSelectionBySpecifiedValues - Boolean - specify True to restrict user selection
//                                                with values specified in ValuesForSelection (its final state).
//      * Type - String
//
// Example:
//   1. For all settings of the CatalogRef.Users type, hide and do not permit to select users marked for deletion, 
//   as well as unavailable and internal ones.
//
//   If SettingProperties.TypesDetails.ContainsType(Type("CatalogRef.Users")) Then
//     SettingProperties.RestrictSelectionBySpecifiedValues = True;
//     SettingProperties.ValuesForSelection.Clear();
//     SettingProperties.SelectionValuesQuery.Text =
//       "SELECT Reference FROM Catalog.Users
//       |WHERE NOT DeletionMark AND NOT Invalid AND NOT IsInternal";
//   EndIf;
//
//   2. Provide an additional value for selection for the Size setting.
//
//   If SettingProperties.DCField = New DataCompositionField("DataParameters.Size") Then
//     SettingProperties.ValuesForSelection.Add(10000000, NStr("en = 'Over 10 MB'"));
//   EndIf;
//
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
EndProcedure

// Allows to set a list of frequently used fields displayed in the submenu for context menu commands 
// "Insert field to the left", "Insert grouping below", etc.  
//
// Parameters:
//   Form - ClientApplicationForm - report form.
//   MainField - Array of String - names of frequently used report fields.
//
Procedure WhenDefiningTheMainFields(Form, MainField) Export 
	
	
	
EndProcedure

#EndRegion
