///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Handler of DCS report user setting string activation.
//
// Parameters:
//   Report - FormDataCollectionItem - a tabular section row describing the report.
//       Properties for reading:
//         * FullName - String - a full name of a report. For example: Report.ReportName.
//         * VariantKey - String - a report option key.
//         * Report - CatalogRef.ReportsOptions - a report option reference.
//         * Presentation - String - report option name.
//       Properties for changing:
//         * ChangesMade - Boolean - set True when report user settings change.
//   DCSettingsComposer - DataCompositionSettingsComposer - all report settings.
//       Properties for changing:
//       * UserSettings - DataCompositionUserSettings - all user settings of report.
//       Other properties for reading only.
//   DCID - DataCompositionID - a report user setting ID.
//       Can be used to get user setting data. For example:
//       	DCUserSetting = DCSettingsComposer.FindByID(DCID).
//   ValueViewOnly - Boolean - a flag of capability for direct editing of the Value column.
//       If set to True, you have to define value choice handler in the OnSettingChoiceStart event.
//
Procedure OnActivateRowSettings(Report, DCSettingsComposer, DCID, ValueViewOnly) Export
	
EndProcedure

// Value choice start handler for the DCS report user setting string.
//
// Parameters:
//   Report - FormDataCollectionItem - a tabular section row describing the report.
//       Properties for reading:
//         * FullName - String - a full name of a report. For example: Report.ReportName.
//         * VariantKey - String - a report option key.
//         * Report - CatalogRef.ReportsOptions - a report option reference.
//         * Presentation - String - report option name.
//       Properties for changing:
//         * ChangesMade - Boolean - set True when report user settings change.
//   DCSettingsComposer - DataCompositionSettingsComposer - all report settings.
//       Properties for changing:
//       * UserSettings - DataCompositionUserSettings - all user settings of report.
//       Other properties for reading only.
//   DCID - DataCompositionID - a report user setting ID.
//       Can be used to get user setting data. For example:
//       	DCUserSetting = DCSettingsComposer.FindByID(DCID).
//   StandardProcessing - Boolean - if True, the standard selection dialog box will be used.
//       If you use own event handling, you have to set False.
//   Handler - NotifyDescription - a handler of applied form selection result.
//       As the 1st parameter (Result), the following types of values can be passed to the handler procedure:
//       Undefined - a user canceled the selection.
//       DataCompositionUserSettings - new report settings.
//
Procedure OnSettingChoiceStart(Report, DCSettingsComposer, DCID, StandardProcessing, Handler) Export
	
EndProcedure

// Value clear handler for the DCS report user setting string.
//
// Parameters:
//   Report - FormDataCollectionItem - a tabular section row describing the report.
//       Properties for reading:
//         * FullName - String - a full name of a report. For example: Report.ReportName.
//         * VariantKey - String - a report option key.
//         * Report - CatalogRef.ReportsOptions - a report option reference.
//         * Presentation - String - report option name.
//       Properties for changing:
//         * ChangesMade - Boolean - set True when report user settings change.
//   DCSettingsComposer - DataCompositionSettingsComposer - all report settings.
//       Properties for changing:
//       * UserSettings - DataCompositionUserSettings - all user settings of report.
//       Other properties for reading only.
//   DCID - DataCompositionID - a report user setting ID.
//       Can be used to get user setting data. For example:
//       	DCUserSetting = DCSettingsComposer.FindByID(DCID).
//   StandardProcessing - Boolean - if True, the setting value will be cleared.
//       If the setting value must not be cleared, you have to set False.
//
Procedure OnSettingsClear(Report, DCSettingsComposer, DCID, StandardProcessing) Export
	
EndProcedure

#EndRegion
