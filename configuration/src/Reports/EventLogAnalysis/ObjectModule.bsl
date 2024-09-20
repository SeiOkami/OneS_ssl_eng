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

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	Settings.Events.OnDefineSelectionParameters = True;
	Settings.Events.OnLoadVariantAtServer = True;
	Settings.EditOptionsAllowed = False;
EndProcedure

// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports:
//     * Report - FormDataStructure
//             - ReportObject
//   NewDCSettings - DataCompositionSettings
//
Procedure OnLoadVariantAtServer(Form, NewDCSettings) Export
	If EventLog.ServerTimeOffset() = 0 Then
		DCParameter = Form.Report.SettingsComposer.Settings.DataParameters.Items.Find("DatesInServerTimeZone");
		If TypeOf(DCParameter) = Type("DataCompositionSettingsParameterValue") Then
			DCParameter.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
	EndIf;
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters.SettingProperties
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	FieldName = String(SettingProperties.DCField);
	If FieldName = "DataParameters.HideScheduledJobs" Then
		ScheduledJobsArray = AllScheduledJobsList();
		SettingProperties.ValuesForSelection.Clear();
		For Each Item In ScheduledJobsArray Do
			SettingProperties.ValuesForSelection.Add(Item.UID, Item.Description);
		EndDo;
		SettingProperties.ValuesForSelection.SortByPresentation();
	EndIf;
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, ObjectDetailsData, StandardProcessing, StorageAddress)
	
	If Common.DataSeparationEnabled()
		Or Not Common.SeparatedDataUsageAvailable() Then
		Raise NStr("en = 'The report is not supported in the application on the Internet.';");
	EndIf;
	
	StandardProcessing = False;
	ReportSettings = SettingsComposer.GetSettings();
	Period = ReportSettings.DataParameters.Items.Find("Period").Value; // StandardPeriod
	ReportVariant = ReportSettings.DataParameters.Items.Find("ReportVariant").Value;
	DatesInServerTimeZone = ReportSettings.DataParameters.Items.Find("DatesInServerTimeZone").Value;
	If DatesInServerTimeZone Then
		ServerTimeOffset = 0;
	Else
		ServerTimeOffset = EventLog.ServerTimeOffset();
	EndIf;
	
	If ReportVariant <> "GanttChart" Then
		DataCompositionSchema.Parameters.DayPeriod.Use = DataCompositionParameterUse.Auto;
	EndIf;
	
	If ReportVariant = "EventLogMonitor" Then
		ReportGenerationResult = Reports.EventLogAnalysis.
			GenerateEventLogMonitorReport(Period.StartDate, Period.EndDate, ServerTimeOffset);
		// ReportIsBlank - Flag indicating whether the report has no data. Required for report distribution.
		ReportIsBlank = ReportGenerationResult.ReportIsBlank;
		SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportIsBlank);
		ResultDocument.Put(ReportGenerationResult.Report);
	ElsIf ReportVariant = "GanttChart" Then
		ScheduledJobsDuration(ReportSettings, ResultDocument, SettingsComposer, ServerTimeOffset);
	Else
		ReportParameters = UserActivityReportParameters(ReportSettings);
		ReportParameters.Insert("StartDate", Period.StartDate);
		ReportParameters.Insert("EndDate", Period.EndDate);
		ReportParameters.Insert("ReportVariant", ReportVariant);
		ReportParameters.Insert("DatesInServerTimeZone", DatesInServerTimeZone);
		If ReportVariant = "UsersActivityAnalysis" Then
			DataCompositionSchema.Parameters.User.Use = DataCompositionParameterUse.Auto;
		EndIf;
		
		TemplateComposer = New DataCompositionTemplateComposer;
		CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, ObjectDetailsData);
		CompositionProcessor = New DataCompositionProcessor;
		ReportData = Reports.EventLogAnalysis.EventLogData1(ReportParameters);
		SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportData.ReportIsBlank);
		ReportData.Delete("ReportIsBlank");
		CompositionProcessor.Initialize(CompositionTemplate, ReportData, ObjectDetailsData, True);
		OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
		OutputProcessor.SetDocument(ResultDocument);
		OutputProcessor.BeginOutput();
		ResultItem = CompositionProcessor.Next();
		While ResultItem <> Undefined Do
			OutputProcessor.OutputItem(ResultItem);
			ResultItem = CompositionProcessor.Next();
		EndDo;
		ResultDocument.ShowRowGroupLevel(1);
		OutputProcessor.EndOutput();
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	ReportVariant = ReportSettings.DataParameters.Items.Find("ReportVariant").Value;
	If ReportVariant = "GanttChart" Then
		DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
		SelectionStart = ReportSettings.DataParameters.Items.Find("SelectionStart");
		SelectionEnd = ReportSettings.DataParameters.Items.Find("SelectionEnd");
		
		If Not ValueIsFilled(DayPeriod.Date) Then
			Common.MessageToUser(
				NStr("en = 'The ""Day"" field is blank.';"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If ValueIsFilled(SelectionStart.Value)
		And ValueIsFilled(SelectionEnd.Value)
		And SelectionStart.Value > SelectionEnd.Value
		And SelectionStart.Use 
		And SelectionEnd.Use Then
			Common.MessageToUser(
				NStr("en = 'The beginning of the period must be earlier than the end of the period.';"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportVariant = "UserActivity" Then
		
		User = ReportSettings.DataParameters.Items.Find("User").Value;
		
		If Not ValueIsFilled(User) Then
			Common.MessageToUser(
				NStr("en = 'The ""User"" field is blank.';"), , );
			Cancel = True;
			Return;
		EndIf;
		
		If Reports.EventLogAnalysis.IBUserName(User) = Undefined Then
			Common.MessageToUser(
				NStr("en = 'Cannot create a report because the username is not specified.';"), , );
			Cancel = True;
			Return;
		EndIf;
		
	ElsIf ReportVariant = "UsersActivityAnalysis" Then
		
		UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
		
		If TypeOf(UsersAndGroups) = Type("CatalogRef.Users") Then
			
			If Reports.EventLogAnalysis.IBUserName(UsersAndGroups) = Undefined Then
				Common.MessageToUser(
					NStr("en = 'Cannot create a report because the username is not specified.';"), , );
				Cancel = True;
				Return;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(UsersAndGroups) Then
			Common.MessageToUser(
				NStr("en = 'The ""Users"" field is blank.';"), , );
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function UserActivityReportParameters(ReportSettings)
	
	UsersAndGroups = ReportSettings.DataParameters.Items.Find("UsersAndGroups").Value;
	User = ReportSettings.DataParameters.Items.Find("User").Value;
	OutputBusinessProcesses = ReportSettings.DataParameters.Items.Find("OutputBusinessProcesses");
	OutputTasks = ReportSettings.DataParameters.Items.Find("OutputTasks");
	OutputCatalogs = ReportSettings.DataParameters.Items.Find("OutputCatalogs");
	OutputDocuments = ReportSettings.DataParameters.Items.Find("OutputDocuments");
	
	If Not OutputBusinessProcesses.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputBusinessProcesses", False);
	EndIf;
	If Not OutputTasks.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputTasks", False);
	EndIf;
	If Not OutputCatalogs.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputCatalogs", False);
	EndIf;
	If Not OutputDocuments.Use Then
		ReportSettings.DataParameters.SetParameterValue("OutputDocuments", False);
	EndIf;		
	
	ReportParameters = New Structure;
	ReportParameters.Insert("UsersAndGroups", UsersAndGroups);
	ReportParameters.Insert("User", User);
	ReportParameters.Insert("OutputBusinessProcesses", OutputBusinessProcesses.Value);
	ReportParameters.Insert("OutputTasks", OutputTasks.Value);
	ReportParameters.Insert("OutputCatalogs", OutputCatalogs.Value);
	ReportParameters.Insert("OutputDocuments", OutputDocuments.Value);
	
	Return ReportParameters;
EndFunction

Procedure ScheduledJobsDuration(ReportSettings, ResultDocument, Var_SettingsComposer, ServerTimeOffset)
	OutputTitle = ReportSettings.OutputParameters.Items.Find("TitleOutput");
	FilterOutput = ReportSettings.OutputParameters.Items.Find("FilterOutput");
	ReportHeader = ReportSettings.OutputParameters.Items.Find("Title");
	DayPeriod = ReportSettings.DataParameters.Items.Find("DayPeriod").Value;
	SelectionStart = ReportSettings.DataParameters.Items.Find("SelectionStart");
	SelectionEnd = ReportSettings.DataParameters.Items.Find("SelectionEnd");
	MinScheduledJobSessionDuration = ReportSettings.DataParameters.Items.Find(
																"MinScheduledJobSessionDuration");
	DisplayBackgroundJobs = ReportSettings.DataParameters.Items.Find("DisplayBackgroundJobs");
	HideScheduledJobs = ReportSettings.DataParameters.Items.Find("HideScheduledJobs");
	ConcurrentSessionsSize = ReportSettings.DataParameters.Items.Find("ConcurrentSessionsSize");
	
	// Checking for parameter usage flag.
	If Not MinScheduledJobSessionDuration.Use Then
		ReportSettings.DataParameters.SetParameterValue("MinScheduledJobSessionDuration", 0);
	EndIf;
	If Not DisplayBackgroundJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("DisplayBackgroundJobs", False);
	EndIf;
	If Not HideScheduledJobs.Use Then
		ReportSettings.DataParameters.SetParameterValue("HideScheduledJobs", "");
	EndIf;
	If Not ConcurrentSessionsSize.Use Then
		ReportSettings.DataParameters.SetParameterValue("ConcurrentSessionsSize", 0);
	EndIf;
		
	If Not ValueIsFilled(SelectionStart.Value) Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	ElsIf Not SelectionStart.Use Then
		DayPeriodStartDate = BegOfDay(DayPeriod);
	Else
		DayPeriodStartDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(SelectionStart.Value, "DLF=T"));
	EndIf;
	
	If Not ValueIsFilled(SelectionEnd.Value) Then
		DayPeriodEndDate = EndOfDay(DayPeriod);
	ElsIf Not SelectionEnd.Use Then
		DayPeriodEndDate = EndOfDay(DayPeriod);
	Else
		DayPeriodEndDate = Date(Format(DayPeriod.Date, "DLF=D") + " " + Format(SelectionEnd.Value, "DLF=T"));
	EndIf;
	
	FillParameters = New Structure;
	FillParameters.Insert("StartDate", DayPeriodStartDate);
	FillParameters.Insert("EndDate", DayPeriodEndDate);
	FillParameters.Insert("ConcurrentSessionsSize", ConcurrentSessionsSize.Value);
	FillParameters.Insert("MinScheduledJobSessionDuration", 
								  MinScheduledJobSessionDuration.Value);
	FillParameters.Insert("DisplayBackgroundJobs", DisplayBackgroundJobs.Value);
	FillParameters.Insert("OutputTitle", OutputTitle);
	FillParameters.Insert("FilterOutput", FilterOutput);
	FillParameters.Insert("ReportHeader", ReportHeader);
	FillParameters.Insert("HideScheduledJobs", HideScheduledJobs.Value);
	FillParameters.Insert("ServerTimeOffset", ServerTimeOffset);
	
	ReportGenerationResult =
		Reports.EventLogAnalysis.GenerateScheduledJobsDurationReport(FillParameters);
	Var_SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", ReportGenerationResult.ReportIsBlank);
	ResultDocument.Put(ReportGenerationResult.Report);
EndProcedure

// Returns:
//  Array of Structure:
//    * UID - UUID
//    * Description - String
//
Function AllScheduledJobsList()
	SetPrivilegedMode(True);
	ScheduledJobsList = ScheduledJobsServer.FindJobs(New Structure);
	ScheduledJobsArray = New Array;
	For Each Item In ScheduledJobsList Do
		If Item.Description <> "" Then
			ScheduledJobsArray.Add(New Structure("UID, Description", Item.UUID, 
																			Item.Description));
		ElsIf Item.Metadata.Synonym <> "" Then
			ScheduledJobsArray.Add(New Structure("UID, Description", Item.UUID,
																			Item.Metadata.Synonym));
		EndIf;
	EndDo;
	
	Return ScheduledJobsArray;
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf