///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// This procedure defines standard settings applied to subsystem objects.
//
// Parameters:
//   Settings - Structure - Collection of subsystem settings. Has the following attributes:
//       * OutputReportsInsteadOfOptions - Boolean - default for hyperlink output in the report panel:
//           True - report options are hidden by default, and reports are enabled and visible.
//           False - report options are visible by default, reports are disabled.
//           The default value is False.
//       * OutputDetails1 - Boolean - default for showing details in the report panel:
//           True - Default value. Show details as captions under options hyperlinks
//           False - output details as tooltips
//           The default value is True.
//       * Search - Structure - settings of report options search:
//           ** InputHint - String - a hint text is displayed in the search field when the search is not specified.
//               It is recommended to use frequently used terms of the applied configuration as an example.
//       * OtherReports - Structure - setting of the Other reports form:
//           ** CloseAfterChoice - Boolean - indicates whether the form is closed after selecting a report hyperlink.
//               True - close "Other reports" after selection.
//               False - do not close.
//               The default value is True.
//           ** ShowCheckBox - Boolean - indicates whether the CloseAfterChoice check box is visible.
//               True - whether to show "Close this window after moving to another report" check box.
//               False - hide the check box.
//               The default value is False.
//       * EditOptionsAllowed - Boolean - show advanced report settings
//               and commands of report option change.
//
// Example:
//	Settings.Search.InputHint = NStr("en = 'For example, cost'");
//	Settings.OtherReports.CloseAfterChoice = False;
//	Settings.OtherReports.ShowCheckBox = True;
//	Settings.OptionChangesAllowed = False;
//
Procedure OnDefineSettings(Settings) Export

	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Report layout settings.

// Determines command interface sections where report panels are provided.
// In Sections, it is necessary to add metadata of those subsystems of the first level
// in which commands of report panels call are placed.
//
// Parameters:
//  Sections - ValueList - sections in which the commands for opening the report panel are displayed:
//      * Value - MetadataObjectSubsystem
//                 - String - 
//                   
//      * Presentation - String - the report panel header in this section.
//
// Example:
//	Sections.Add(Metadata.Subsystems.Surveys, NStr("en = 'Survey reports'"));
//	Sections.Add(ReportsOptionsClientServer.HomePageID(), NStr("en = 'Main reports'"));
//
Procedure DefineSectionsWithReportOptions(Sections) Export
	
	
	
EndProcedure

// This procedure configures extended settings of configuration reports such as:
// - Report details.
// - Search fields: descriptions of fields, parameters, and filters (for reports that are not based on DCS).
// - Placement in the sections of command interface
//   (initial setup of report placement in subsystems is automatically determined from metadata,
//    its duplication is not required).
// - The Enabled flag (for context reports).
// - Output mode in report panels (with or without grouping by a report).
// - And so on.
// 
// Only settings of configuration reports (and report options) are configured in the procedure.
// To set up reports from configuration extensions, add them to the AttachableReportsAndDataProcessors subsystem.
//
// To configure the settings, use the following auxiliary procedures and functions:
//   ReportsOptions.ReportDetails, 
//   ReportsOptions.OptionDetails, 
//   ReportsOptions.SetOutputModeInReportPanels, 
//   ReportsOptions.SetUpReportInManagerModule.
//
// You can change the settings of all report options by modifying the report settings.
// If report option settings are retrieved explicitly, they become independent
// (they no longer inherit settings changes from the report).
//   
// Functional options of the predefined report option are merged to functional options of this report according to the following rules:
// (FO1_Report OR FO2_Report) And (FO3_Option OR FO4_Option).
// Only the functional options of the report are available for user report options,
// - they are disabled only with disabling the entire report.
//
// Parameters:
//   Settings - ValueTable - Collection of predefined report options, where:
//       * Report - CatalogRef.ExtensionObjectIDs
//               - CatalogRef.AdditionalReportsAndDataProcessors
//               - CatalogRef.MetadataObjectIDs
//               - String - 
//       * Metadata - MetadataObjectReport - report metadata.
//       * UsesDCS - Boolean - indicates whether the main DCS is used in the report.
//       * VariantKey - String - Report option ID.
//       * DetailsReceived - Boolean - Flag indicating that the string description is already received.
//       * Enabled              - Boolean -
//       * DefaultVisibility - Boolean - If False, the report option is hidden from the report panel by default.
//       * ShouldShowInOptionsSubmenu - Boolean -  
//                                                
//       * Description - String - report option name.
//       * LongDesc - String - clarifies a report purpose.
//       * Location - Map of KeyAndValue - settings describing report option placement in sections (subsystems), where:
//             ** Key - MetadataObject - Subsystem where a report or a report option is placed.
//             ** Value - String - settings of placement in the subsystem (group) - "", "Important", "SeeAlso".
//       * SearchSettings - Structure - additional settings related to the search of this report option where:
//             ** FieldDescriptions - String - names of report option fields.
//             ** FilterParameterDescriptions - String - names of report option settings.
//             ** Keywords - String - additional terminology (including specific or obsolete).
//             ** TemplatesNames - String - the parameter is used instead of FieldDescriptions.
//       * SystemInfo - Structure - another internal information.
//       * Type - String - List of type IDs.
//       * IsOption - Boolean - indicates whether report details are related to a report option.
//       * FunctionalOptions - Array of String - Collection of functional option IDs, where:
//       * GroupByReport - Boolean - indicates whether it is necessary to group options by a base report.
//       * MeasurementsKey - String - ID of report performance measurement.
//       * MainOption - String - ID of the main report option.
//       * DCSSettingsFormat - Boolean - indicates whether the settings in the DCS format are stored.
//       * DefineFormSettings - Boolean -
//           
//           
//           
//               
//               
//               //
//               
//               
//               
//               See ReportsClientServer.DefaultReportSettings
//               //
//               
//               	
//               
//
// Example:
//
//  // Adding report option to the subsystem.
//	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NameOfReport, "<OptionName>");
//	OptionSettings.Placement.Insert(Subsystems.SectionName.Subsystems.SubsystemName);
//
//  // Disabling report options.
//	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NameOfReport, "<OptionName>");
//	OptionSettings.Enabled = False;
//
//  // Disabling all report options except one.
//	ReportSettings = ReportsOptions.ReportDetails(Settings, Metadata.Reports.NameOfReport);
//	ReportSettings.Enabled = False;
//	OptionSettings = ReportsOptions.OptionDetails(Settings, ReportSettings, "<OptionName>");
//	OptionSettings.Enabled = True;
//
//  // Filling in the search settings - field descriptions, parameters and filters:
//	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NameOfReportWithoutSchema, "");
//	OptionSettings.SearchSettings.FieldDescriptions =
//		NStr("en = 'Counterparty
//		|Contract
//		|Responsible person
//		|Discount
//		|Date'");
//	OptionSettings.SearchSettings.FilterParameterDescriptions =
//		NStr("en = 'Period
//		|Responsible person
//		|Counterparty
//		|Contract'");
//
//  // Switching the output mode in report panels:
//  // Grouping report options by this report:
//	ReportsOptions.SetOutputModeInReportPanels(Settings, Metadata.Reports.NameOfReport, True);
//  // Without grouping by the report:
//	Report = ReportsOptions.ReportDetails(Settings, Metadata.Reports.NameOfReport);
//	ReportsOptions.SetOutputModeInReportPanels(Settings, Report, False);
//
Procedure CustomizeReportsOptions(Settings) Export

	
	
EndProcedure

// Registers changes in report option names.
// It is used when updating to keep reference integrity,
// in particular for saving user settings and mailing report settings.
// Old option name is reserved and cannot be used later.
// If there are several changes, each change must be registered
// by specifying the last (current) report option name in the relevant option name.
// Since the names of report options are not displayed in the user interface,
// it is recommended to set them in such a way that they would not be changed.
// Add to Changes the details of changes in names
// of the report options connected to the subsystem.
//
// Parameters:
//   Changes - ValueTable - Table of report option name changes. Columns:
//       * Report - MetadataObject - metadata of the report whose schema contains the changed option name.
//       * OldOptionName - String - old option name before changes.
//       * RelevantOptionName - String - current (last relevant) option name.
//
// Example:
//	Change = Changes.Add();
//	Change.Report = Metadata.Reports.<NameOfReport>;
//	Change.OldOptionName = "<OldOptionName>";
//	Change.RelevantOptionName = "<RelevantOptionName>";
//
Procedure RegisterChangesOfReportOptionsKeys(Changes) Export
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Report command settings.

// Determines configuration objects whose manager modules support the AddReportsCommands procedure
// describing context report opening commands.
// See the help for the AddReportsCommands procedure syntax. 
//
// Parameters:
//  Objects - Array - metadata objects (MetadataObject) with report commands.
//
Procedure DefineObjectsWithReportCommands(Objects) Export
	
EndProcedure

// Determining a list of global report commands.
// The event occurs when calling a re-use module.
//
// Parameters:
//  ReportsCommands - ValueTable - Table of commands to add to a submenu:
//   * Id - String   - Command ID.
//   * Presentation - String   - Command presentation in a form.
//   * Importance      - String   - Suffix of a submenu group in which the command is to be output.
//                                The following values are acceptable: "Important", "Ordinary", and "SeeAlso".
//   * Order       - Number    - Command position in the group. Can be customized workspace-wise.
//                                
//   * Picture      - Picture - Command icon.
//   * Shortcut - Shortcut - Shortcut for fast command call.
//   * ParameterType - TypeDescription - types of objects that the command is intended for.
//   * VisibilityInForms    - String - Comma-delimited names of the forms to add a command to.
//                                    Use to add different set of commands to different forms.
//   * FunctionalOptions - String - Comma-delimited names of functional options that affect the command visibility.
//   * VisibilityConditions    - Array - Defines the command conditional visibility.
//                                    To add conditions, use procedure AttachableCommands.AddCommandVisibilityCondition().
//                                    Use "And" to specify multiple conditions.
//                                    
//   * ChangesSelectedObjects - Boolean - Optional. Flag defining command availability for users
//                                         who have no right to edit the object can run the command.
//                                         If True, the button will be inactive. By default, False.
//                                         
//   * MultipleChoice - Boolean
//                        - Undefined - Optional. If True, the command supports multiple option choices.
//                                         In this case, the parameter passes a list of references.
//                                         By default, True.
//   * WriteMode - String - actions associated with object writing that are executed before the command handler where:
//                 "DoNotWrite" - do not write the object and pass the full form in the handler parameters
//                                  instead of references. In this mode, we recommend that you operate directly with a form
//                                  that is passed in the structure of parameter 2 of the command handler.
//                 "WriteNewOnly" - write only new objects.
//                 "Write"            - write only new and modified objects.
//                 "Post"             - post documents.
//                 Before writing or posting the object, users are asked for confirmation.
//                 Optional. Default value is "Write".
//   * FilesOperationsRequired - Boolean - If True, in the web client, users are prompted
//                                        to install 1C:Enterprise Extension.
//                                        Optional. The default value is False.
//   * Manager - String - Full name of the metadata object where the command was indicated.
//                         For example, "Report._DemoPurchaseLedger".
//   * FormName - String - Name of the form the command will open or receive.
//                         If Handler is not specified, the "Open" method is called.
//   * VariantKey - String - Name of the report option the command will open.
//   * FormParameterName - String - Name of the form parameter to pass a reference or a reference array to.
//   * FormParameters - Undefined
//                    - Structure - Parameters of the form specified in FormName.
//   * Handler - String - details of the procedure that handles the main action of the command.
//                  Format "<CommonModuleName>.<ProcedureName>" is used when the procedure is in a common module.
//                  Format "<ProcedureName>" is used in the following cases:
//                  1) If FormName is filled, a client procedure is expected in the specified form module.
//                  2) If FormName is not filled, a server procedure is expected in the manager module.
//   * AdditionalParameters - Structure - Handler parameters specified in Handler.
//
//  Parameters - Structure - Runtime context details:
//   * FormName - String - Form full name.
//   
//  StandardProcessing - Boolean - If False, the AddReportsCommands event of the object manager
//                                  is not called.
//
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
EndProcedure

#EndRegion
