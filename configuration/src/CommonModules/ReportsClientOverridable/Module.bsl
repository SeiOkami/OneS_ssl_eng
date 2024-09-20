///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// It appears after report is generated: after background job is completed.
// Allows to override a data processor of report generation result.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//  ReportCreated - Boolean - True if the report has been successfully generated.
//
Procedure AfterGenerate(ReportForm, ReportCreated) Export
	
EndProcedure

// Spreadsheet document drill-down handler.
// See "Form field extension for a spreadsheet document field.DetailProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - Report form:
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   Item     - FormField        - Spreadsheet document.
//   Details - Arbitrary     - Drill-down value of a point, series, or chart value.
//   StandardProcessing - Boolean  - Flag indicating whether standard event processing is running.
//
Procedure DetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	
EndProcedure

// The handler of additional details (menu of a spreadsheet document of a report form).
// See "Form field extension for a spreadsheet document field.AdditionalDetailProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   Item     - FormField        - Spreadsheet document.
//   Details - Arbitrary     - details value of a point, series, or a chart value.
//   StandardProcessing - Boolean  - indicates whether standard (system) event processing is executed.
//
Procedure AdditionalDetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	
EndProcedure

// Handler of commands that were dynamically added and attached to the Attachable_Command handler.
// An example of adding a command See ReportsOverridable.ПриСозданииНаСервере().
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   Command     - FormCommand     - Command that was called.
//   Result   - Boolean           - True if the command call is processed.
//
Procedure HandlerCommands(ReportForm, Command, Result) Export
	
	
	
EndProcedure

// Handler that handles override parameters or value choice form.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   SelectionConditions - Structure:
//    * FieldName              - String - Name of a parameter or data composition item.
//    * LayoutItem    - DataCompositionAvailableParameter
//                           - DataCompositionFilterAvailableField - 
//    * AvailableTypes        - TypeDescription  - Selectable types.
//    * Marked           - ValueList - Previously selected values.
//    * ChoiceParameters      - Array of ChoiceParameter - Configured choice parameters.
// 
//   ClosingNotification1 - NotifyDescription - Choice result notification.
//                           Runs after a user selects an Array or ValueList item.
//
//   StandardProcessing - Boolean - If False, the standard form won't open.
//                                   In this case, open a custom form and run ClosingNotification.
//
Procedure AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing) Export
	
	
	
EndProcedure

// Handler of the subordinate form selection result.
// See "ClientApplicationForm.ChoiceProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   ValueSelected - Arbitrary     - Selection result in a subordinate form.
//   ChoiceSource    - ClientApplicationForm - Form where the choice is made.
//   Result         - Boolean           - True if the selection result is processed.
//
Procedure ChoiceProcessing(ReportForm, ValueSelected, ChoiceSource, Result) Export
	
EndProcedure

// Handler for double click, clicking Enter, or a hyperlink in a report form spreadsheet document.
// See "Form field extension for a spreadsheet document field.Choice" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   Item     - FormField        - Spreadsheet document.
//   Area     - SpreadsheetDocumentRange - Selected value.
//   StandardProcessing - Boolean - indicates whether standard event processing is executed.
//
Procedure SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing) Export
	
EndProcedure

// Handler of report form broadcast notification.
// See "ClientApplicationForm.NotificationProcessing" in Syntax Assistant.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   EventName  - String           - Event ID for receiving forms.
//   Parameter    - Arbitrary     - extended information about an event.
//   Source    - ClientApplicationForm
//               - Arbitrary - event source.
//   NotificationProcessed - Boolean - indicates that an event is processed.
//
Procedure NotificationProcessing(ReportForm, EventName, Parameter, Source, NotificationProcessed) Export
	
EndProcedure

// Handler of clicking the period selection button in a separate form.
//  If the configuration uses its own period selection dialog box,
//  set the StandardProcessing parameter to False
//  and return the selected period to ResultHandler.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - 
//                   * Report - ReportObject - Form data structure similar to the report object.
//
//   Period - StandardPeriod - Composer setting value that matches the selected period.
//
//   StandardProcessing - Boolean - If True, the standard period selection dialog box will be used.
//       If it is set to False, the standard dialog box will not open.
//
//   ResultHandler - NotifyDescription - a handler of period selection result.
//       The following type values can be passed to the ResultHandler as the result:
//       Undefined - user canceled the period input.
//       StandardPeriod - the selected period.
//
Procedure OnClickPeriodSelectionButton(ReportForm, Period, StandardProcessing, ResultHandler) Export
	
	
	
EndProcedure

#EndRegion
