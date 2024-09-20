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
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	Else
		Return;
	EndIf;
	
	AvailableAdvancedSignature = DigitalSignatureInternalCached.AvailableAdvancedSignature();
	
	If Not Common.DataSeparationEnabled()
		Or Common.SeparatedDataUsageAvailable() Then
		RefineSignaturesAutomatically = Constants.RefineSignaturesAutomatically.Get();
		AddTimestampsAutomatically = Constants.AddTimestampsAutomatically.Get();
	Else
		RefineSignaturesAutomatically = 0;
		AddTimestampsAutomatically = False;
	EndIf;
	
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, True);
	ReportSettings.DefineFormSettings = True;
	ReportSettings.LongDesc = NStr("en = 'Expiring signatures to be renewed.';");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "rawsignatures");
	OptionSettings.LongDesc = NStr("en = 'Displays signatures that are subject to enhancement (after their types are determined).';");
	OptionSettings.Enabled = AvailableAdvancedSignature And RefineSignaturesAutomatically <> 0;

	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "RequireImprovementSignatures");
	OptionSettings.LongDesc = NStr("en = 'Displays signatures to be enhanced.';");
	OptionSettings.Enabled = AvailableAdvancedSignature And RefineSignaturesAutomatically <> 0;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "RequiredAddArchiveTags");
	OptionSettings.LongDesc = NStr("en = 'Displays signatures that require archive timestamps.';");
	OptionSettings.Enabled = AvailableAdvancedSignature And AddTimestampsAutomatically;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ErrorsOnAutoRenewal");
	OptionSettings.LongDesc = NStr("en = 'Displays signatures that cannot be renewed automatically.';");
	OptionSettings.Enabled = AvailableAdvancedSignature
	 And (AddTimestampsAutomatically Or RefineSignaturesAutomatically = 1);
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf