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
	
	ReportSettings.DefineFormSettings = True;
	ReportSettings.Enabled = False;
	
	FirstOption = FirstOption();
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, FirstOption.Name);
	OptionSettings.Enabled  = True;
	OptionSettings.LongDesc = FirstOption.LongDesc;
	
	SecondOption = SecondOption();
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, SecondOption.Name);
	OptionSettings.Enabled  = True;
	OptionSettings.LongDesc = SecondOption.LongDesc;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType <> "Form" Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	SelectedForm = "ReportForm";
	
EndProcedure

#EndRegion

#Region Private

// Called from the report form.
Procedure SetOption(Form, Variant) Export
	
	FirstOption = FirstOption();
	SecondOption = SecondOption();
	
	Reports.PeriodClosingDates.CustomizeForm(Form, FirstOption, SecondOption, Variant);
	
EndProcedure

Function FirstOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections And Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportRestrictionDatesByInfobases";
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportRestrictionDatesByInfobasesWithoutObjects";
	Else
		VariantName = "ImportRestrictionDatesByInfobasesWithoutSections";
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name", VariantName);
	
	OptionProperties.Insert("Title",
		NStr("en = 'Data import restriction dates by infobases';"));
	
	OptionProperties.Insert("LongDesc",
		NStr("en = 'Displays data import restriction dates for objects grouped by infobases.';"));
	
	Return OptionProperties;
	
EndFunction

Function SecondOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections And Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportRestrictionDatesBySectionsObjectsForInfobases";
		Title = NStr("en = 'Data import restriction dates by sections and objects';");
		OptionDetails =
			NStr("en = 'Displays data import restriction dates grouped by sections with objects.';");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ImportRestrictionDatesBySectionsForInfobases";
		Title = NStr("en = 'Data import restriction dates by sections';");
		OptionDetails =
			NStr("en = 'Displays data import restriction dates grouped by sections.';");
	Else
		VariantName = "ImportRestrictionDatesByObjectsForInfobases";
		Title = NStr("en = 'Data import restriction dates by objects';");
		OptionDetails =
			NStr("en = 'Displays data import restriction dates grouped by objects.';");
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name",       VariantName);
	OptionProperties.Insert("Title", Title);
	OptionProperties.Insert("LongDesc",  OptionDetails);
	
	Return OptionProperties;
	
EndFunction

#EndRegion

#EndIf
