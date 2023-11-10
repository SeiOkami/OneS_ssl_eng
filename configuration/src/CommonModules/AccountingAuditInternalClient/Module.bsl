///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Handler for double click, clicking Enter, or a hyperlink in a report form spreadsheet document.
// See "Form field extension for a spreadsheet document field.Choice" in Syntax Assistant.
//
// Parameters:
//   ReportForm          - ClientApplicationForm - a report form.
//   Item              - FormField        - spreadsheet document.
//   Area              - SpreadsheetDocumentRange - a selected value.
//   StandardProcessing - Boolean - indicates whether standard event processing is executed.
//
Procedure SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing) Export
	
	If ReportForm.ReportSettings.FullName <> "Report.AccountingCheckResults" Then
		Return;
	EndIf;
		
	Details = Area.Details;
	If TypeOf(Details) = Type("Structure") Then
		
		StandardProcessing = False;
		If Details.Property("Purpose") Then
			If Details.Purpose = "FixIssues" Then
				ResolveIssue(ReportForm, Details);
			ElsIf Details.Purpose = "OpenListForm" Then
				OpenProblemList(ReportForm, Details);
			EndIf;
		EndIf;
		
	EndIf;
		
EndProcedure

// Opens a report form with a filter by issues that impede the normal update of
// the infobase.
//
//  Parameters:
//     Form                - ClientApplicationForm - a managed form of an object with issues.
//     StandardProcessing - Boolean - a flag indicating whether
//                            the standard (system) event processing is executed is passed to this parameter.
//
// Example:
//    ModuleAccountingAuditInternalClient.OpenIssuesReportFromUpdateProcessing(ThisObject, StandardProcessing);
//
Procedure OpenIssuesReportFromUpdateProcessing(Form, StandardProcessing) Export
	
	StandardProcessing = False;
	OpenIssuesReport("SystemChecks");
	
EndProcedure

// See AccountingAuditClient.OpenIssuesReport.
Procedure OpenIssuesReport(ChecksKind, ExactMap = True) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("CheckKind", ChecksKind);
	FormParameters.Insert("ExactMap", ExactMap);
	
	OpenForm("Report.AccountingCheckResults.Form", FormParameters);
	
EndProcedure

// Opens the AccountingCheckRules catalog list form.
//
Procedure OpenAccountingChecksList() Export
	OpenForm("Catalog.AccountingCheckRules.ListForm");
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If Not ClientParameters.Property("AccountingAudit") Then
		Return;
	EndIf;
	Properties = ClientParameters.AccountingAudit;
	
	If Not Properties.NotifyOfAccountingIssues1
	 Or Not ValueIsFilled(Properties.AccountingIssuesCount) Then
		Return;
	EndIf;
	
	ApplicationParameters.Insert("StandardSubsystems.AccountingAudit.IssuesCount",
		Properties.AccountingIssuesCount);
	
	AttachIdleHandler("NotifyOfAccountingIssues", 30, True);
	
EndProcedure

// See ReportsClientOverridable.DetailProcessing.
Procedure OnProcessDetails(ReportForm, Item, Details, StandardProcessing) Export
	
	If ReportForm.ReportSettings.FullName = "Report.AccountingCheckResults" Then
		Details = ReportForm.ReportSpreadsheetDocument.CurrentArea.Details;
		Result = AccountingAuditServerCall.SelectedCellDetails(ReportForm.ReportDetailsData, ReportForm.ReportSpreadsheetDocument, Details);
		If Result <> Undefined Then
			StandardProcessing = False;
			ShowValue(, Result.ObjectWithIssue);
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//   ReportForm - ClientApplicationForm:
//    * ReportSpreadsheetDocument - SpreadsheetDocument
//   Command - FormCommand
//   Result - Boolean
// 
Procedure OnProcessCommand(ReportForm, Command, Result) Export
	
	If ReportForm.ReportSettings.FullName = "Report.AccountingCheckResults" Then
		UnsuccessfulActionText = NStr("en = 'Select a line with an object with issues.';");
		Details = ReportForm.ReportSpreadsheetDocument.CurrentArea.Details;
		If Command.Name = "AccountingAuditObjectChangeHistory" Then
			Result = AccountingAuditServerCall.DataForObjectChangeHistory(ReportForm.ReportDetailsData, ReportForm.ReportSpreadsheetDocument, Details);
			If Result <> Undefined Then
				If Result.ToVersion Then
					ModuleObjectsVersioningClient = CommonClient.CommonModule("ObjectsVersioningClient");
					ModuleObjectsVersioningClient.ShowChangeHistory(Result.Ref, ReportForm);
				Else
					Events = New Array;
					Events.Add("_$Data$_.Delete");
					Events.Add("_$Data$_.New");
					Events.Add("_$Data$_.Update");
					Filter = New Structure;
					Filter.Insert("Data", Result.Ref);
					Filter.Insert("EventLogEvent", Events);
					Filter.Insert("StartDate", BegOfMonth(CurrentDate())); // 
					EventLogClient.OpenEventLog(Filter);
				EndIf;
			Else
				ShowMessageBox(, UnsuccessfulActionText);
			EndIf;
		ElsIf Command.Name = "AccountingAuditIgnoreIssue" Then
			IssueIgnored = AccountingAuditServerCall.IgnoreIssue(ReportForm.ReportDetailsData, ReportForm.ReportSpreadsheetDocument, Details);
			If Not IssueIgnored Then
				ShowMessageBox(, UnsuccessfulActionText);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Opens a form for interactive user actions to resolve an issue.
//
// Parameters:
//   Form       - ClientApplicationForm - the AccountingCheckResults report form.
//   Details - Structure - additional information to correct an issue:
//      * Purpose                     - String - a purpose string ID of the decryption.
//      * CheckID          - String - a string check ID.
//      * GoToCorrectionHandler - String - a name of the export client procedure handler for correcting 
//                                                   an issue or a full name of the form being opened.
//      * CheckKind                    - CatalogRef.ChecksKinds - a check kind
//                                         that narrows the area of issue correction.
//
Procedure ResolveIssue(Form, Details)
	
	PatchParameters = New Structure;
	PatchParameters.Insert("CheckID", Details.CheckID);
	PatchParameters.Insert("CheckKind",           Details.CheckKind);
	
	GoToCorrectionHandler = Details.GoToCorrectionHandler;
	If StrStartsWith(GoToCorrectionHandler, "CommonForm.") Or StrFind(GoToCorrectionHandler, ".Form") > 0 Then
		OpenForm(GoToCorrectionHandler, PatchParameters, Form);
	Else
		HandlerCorrections = StringFunctionsClientServer.SplitStringIntoSubstringsArray(GoToCorrectionHandler, ".");
		
		ModuleCorrectionHandler  = CommonClient.CommonModule(HandlerCorrections[0]);
		ProcedureName = HandlerCorrections[1];
		
		ExecuteNotifyProcessing(New NotifyDescription(ProcedureName, ModuleCorrectionHandler), PatchParameters);
	EndIf;
	
EndProcedure

// Opens a list form (in case of a register - with the problem record set).
//
// Parameters:
//   Form                          - ClientApplicationForm - a report form.
//   Details - Structure - a structure containing the data for correcting the issue
//                 of the cell of the data integrity check report:
//      * Purpose         - String - a purpose string ID of the decryption.
//      * FullObjectName   - String - Full name of a metadata object.
//      * Filter              - Structure - a filter as a list.
//
Procedure OpenProblemList(Form, Details)
	
	UserSettings = New DataCompositionUserSettings;
	CompositionFilter           = UserSettings.Items.Add(Type("DataCompositionFilter"));
	
	RegisterForm = GetForm(Details.FullObjectName + ".ListForm", , Form);
	
	For Each SetFilterItem1 In Details.Filter Do
		
		FilterElement                = CompositionFilter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue  = New DataCompositionField(SetFilterItem1.Key);
		FilterElement.RightValue = SetFilterItem1.Value;
		FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
		FilterElement.Use  = True;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Field",          SetFilterItem1.Key);
		FilterParameters.Insert("Value",      SetFilterItem1.Value);
		FilterParameters.Insert("ComparisonType",  DataCompositionComparisonType.Equal);
		FilterParameters.Insert("Use", True);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ToUserSettings", True);
		AdditionalParameters.Insert("ReplaceCurrent",       True);
		
		AddFilter(RegisterForm.List.SettingsComposer, FilterParameters, AdditionalParameters);
		
	EndDo;
	
	RegisterForm.Open();
	
EndProcedure

// Adds a filter to the collection of the composer filters or group of selections
//
// Parameters:
//   StructureItem        - DataCompositionSettingsComposer
//                           - DataCompositionSettings - 
//   FilterParameters         - Structure - contains data composition filter parameters:
//     * Field                - String - a field name, by which a filter is added.
//     * Value            - Arbitrary - a filter value of data composition (Undefined by default).
//     * ComparisonType        - DataCompositionComparisonType - a comparison type of data composition (Undefined by default).
//     * Use       - Boolean - indicates that filter is used (True by default).
//   AdditionalParameters - Structure - contains additional parameters, listed below:
//     * ToUserSettings - Boolean - a flag of adding to data composition user settings (False by default).
//     * ReplaceCurrent       - Boolean - a flag of complete replacement of existing filter by field (True by default).
//
// Returns:
//   DataCompositionFilterItem - 
//
Function AddFilter(StructureItem, FilterParameters, AdditionalParameters = Undefined)
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ToUserSettings", False);
		AdditionalParameters.Insert("ReplaceCurrent",       True);
	Else
		If Not AdditionalParameters.Property("ToUserSettings") Then
			AdditionalParameters.Insert("ToUserSettings", False);
		EndIf;
		If Not AdditionalParameters.Property("ReplaceCurrent") Then
			AdditionalParameters.Insert("ReplaceCurrent", True);
		EndIf;
	EndIf;
	
	If TypeOf(FilterParameters.Field) = Type("String") Then
		NewField = New DataCompositionField(FilterParameters.Field);
	Else
		NewField = FilterParameters.Field;
	EndIf;
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Filter = StructureItem.Settings.Filter;
		
		If AdditionalParameters.ToUserSettings Then
			For Each SettingItem In StructureItem.UserSettings.Items Do
				If SettingItem.UserSettingID =
					StructureItem.Settings.Filter.UserSettingID Then
					Filter = SettingItem;
				EndIf;
			EndDo;
		EndIf;
	
	ElsIf TypeOf(StructureItem) = Type("DataCompositionSettings") Then
		Filter = StructureItem.Filter;
	Else
		Filter = StructureItem;
	EndIf;
	
	FilterElement = Undefined;
	If AdditionalParameters.ReplaceCurrent Then
		For Each Item In Filter.Items Do
	
			If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
				Continue;
			EndIf;
	
			If Item.LeftValue = NewField Then
				FilterElement = Item;
			EndIf;
	
		EndDo;
	EndIf;
	
	If FilterElement = Undefined Then
		FilterElement = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;
	FilterElement.Use  = FilterParameters.Use;
	FilterElement.LeftValue  = NewField;
	FilterElement.ComparisonType   = ?(FilterParameters.ComparisonType = Undefined, DataCompositionComparisonType.Equal,
		FilterParameters.ComparisonType);
	FilterElement.RightValue = FilterParameters.Value;
	
	Return FilterElement;
	
EndFunction

Procedure NotifyOfAccountingIssuesCases() Export
	
	IssuesCount = ApplicationParameters.Get(
		"StandardSubsystems.AccountingAudit.IssuesCount");
	
	If Not ValueIsFilled(IssuesCount) Then
		Return;
	EndIf;
	
	ShowUserNotification(
		NStr("en = 'Data integrity check';"),
		"e1cib/app/Report.AccountingCheckResults",
		NStr("en = 'Data integrity issues found';") + " (" + IssuesCount + ")",
		PictureLib.Warning32);
	
EndProcedure



#EndRegion