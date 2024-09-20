///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, True);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "");
	OptionSettings.LongDesc = 
		NStr("en = 'Information about the survey respondents,
		|and response statistics.';");
	OptionSettings.SearchSettings.FieldDescriptions = 
		NStr("en = 'Respondent
		|Survey
		|Question
		|Response';");
	OptionSettings.SearchSettings.FilterParameterDescriptions = 
		NStr("en = 'Survey
		|Report type';");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf