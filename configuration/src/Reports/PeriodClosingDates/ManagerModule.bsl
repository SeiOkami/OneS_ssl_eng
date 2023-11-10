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
	
	CustomizeForm(Form, FirstOption, SecondOption, Variant);
	
EndProcedure

// Calls the SetOption procedure.
Procedure CustomizeForm(Form, FirstOption, SecondOption, Variant) Export
	
	Items = Form.Items;
	
	If Variant = 0 Then
		Form.Parameters.GenerateOnOpen = True;
		Items.FormFirstOption.Title = FirstOption.Title;
		Items.FormSecondOption.Title = SecondOption.Title;
	Else
		FullReportName = "Report." + StrSplit(Form.FormName, ".", False)[1];
		
		// 
		Common.SystemSettingsStorageSave(
			FullReportName + "/" + Form.CurrentVariantKey + "/CurrentUserSettings",
			"",
			Form.Report.SettingsComposer.UserSettings);
	EndIf;
	
	If Variant = 0 Then
		If Form.CurrentVariantKey = FirstOption.Name Then
			Variant = 1;
		ElsIf Form.CurrentVariantKey = SecondOption.Name Then
			Variant = 2;
		EndIf;
	EndIf;
	
	If Variant = 0 Then
		Variant = 1;
	EndIf;
	
	If Variant = 1 Then
		Items.FormFirstOption.Check = True;
		Items.FormSecondOption.Check = False;
		Form.Title = FirstOption.Title;
		CurrentVariantKey = FirstOption.Name;
	Else
		Items.FormFirstOption.Check = False;
		Items.FormSecondOption.Check = True;
		Form.Title = SecondOption.Title;
		CurrentVariantKey = SecondOption.Name;
	EndIf;
	
	// 
	Form.SetCurrentVariant(CurrentVariantKey);
	
	// 
	Form.ComposeResult(ResultCompositionMode.Auto);
	
EndProcedure

Function FirstOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections And Not Properties.AllSectionsWithoutObjects Then
		VariantName = "PeriodClosingDatesByUsers";
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "PeriodClosingDatesByUsersWithoutObjects";
	Else
		VariantName = "PeriodClosingDatesByUsersWithoutSections";
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name", VariantName);
	
	OptionProperties.Insert("Title",
		NStr("en = 'Period-end closing dates by users';"));
	
	OptionProperties.Insert("LongDesc",
		NStr("en = 'Displays period-end closing dates grouped by users.';"));
	
	Return OptionProperties;
	
EndFunction

Function SecondOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections And Not Properties.AllSectionsWithoutObjects Then
		VariantName = "PeriodClosingDatesBySectionsObjectsForUsers";
		Title = NStr("en = 'Period-end closing dates by sections and objects';");
		OptionDetails =
			NStr("en = 'Displays period-end closing dates grouped by sections with objects.';");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "PeriodClosingDatesBySectionsForUsers";
		Title = NStr("en = 'Period-end closing dates by sections';");
		OptionDetails =
			NStr("en = 'Displays period-end closing dates grouped by sections.';");
	Else
		VariantName = "PeriodClosingDatesByObjectsForUsers";
		Title = NStr("en = 'Period-end closing dates by objects';");
		OptionDetails =
			NStr("en = 'Displays period-end closing dates grouped by objects.';");
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name",       VariantName);
	OptionProperties.Insert("Title", Title);
	OptionProperties.Insert("LongDesc",  OptionDetails);
	
	Return OptionProperties;
	
EndFunction

#EndRegion

#EndIf
