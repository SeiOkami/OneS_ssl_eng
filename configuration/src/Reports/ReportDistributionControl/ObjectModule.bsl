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

// 

// To set up a report form.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	    
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.BeforeLoadVariantAtServer    = True; 
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.GenerateImmediately = True;    

EndProcedure

// See ReportsOverridable.OnCreateAtServer.
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	If Form.Parameters.VariantPresentation = "Details" Then
		Raise NStr("en = 'The selected action is unavailable in this report.';");
	EndIf;
	
	ReportsDistributionRef = Undefined;
	
	If Not Form.Parameters.Property("ReportMailing", ReportsDistributionRef)
		And Not Form.Parameters.Property("CommandParameter", ReportsDistributionRef)
		And Not ValueIsFilled(ReportsDistributionRef) Then 
		Return;
	EndIf;  
				
	DataParametersStructure = New Structure("ReportMailing", DataParameter(ReportsDistributionRef));
	SetDataParameters(SettingsComposer.Settings, DataParametersStructure);   
		
EndProcedure

// See ReportsOverridable.BeforeLoadVariantAtServer.
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("ReportMailing");
	If FoundParameter = Undefined Then
		Return;
	EndIf;
	
	ReportsDistributionRef = FoundParameter.Value;
	If Not ValueIsFilled(ReportsDistributionRef) Then 
		Return;
	EndIf;
		
	DataParametersStructure = New Structure;
	DataParametersStructure.Insert("ReportMailing", DataParameter(ReportsDistributionRef));  
	DataParametersStructure.Insert("Period", DataParameter(New StandardPeriod));  
		
	If ValueIsFilled(Form.OptionContext) Then 
		NewDCSettings.AdditionalProperties.Insert("ReportMailing", ReportsDistributionRef);
	EndIf;    
		
	SetDataParameters(NewDCSettings, DataParametersStructure);
	
EndProcedure

// 
//
// Parameters:
//   Context - Arbitrary
//   SchemaKey - String
//   VariantKey - String
//                - Undefined
//   NewDCSettings - DataCompositionSettings
//                    - Undefined
//   NewDCUserSettings - DataCompositionUserSettings
//                                    - Undefined
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, VariantKey, NewDCSettings, NewDCUserSettings) Export
		
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("ReportMailing");
	If FoundParameter = Undefined Then
		Return;
	EndIf;
	
	ReportsDistributionRef = FoundParameter.Value;
	If Not ValueIsFilled(ReportsDistributionRef) Then
		Return;
	EndIf;
	
	// 
	For Each Item In NewDCSettings.Filter.Items Do
		Item.Use = False;
		If Not ValueIsFilled(Item.UserSettingID) Then
			Continue;
		EndIf;	
		MatchingParameter = NewDCUserSettings.Items.Find(
			Item.UserSettingID);
			
		If MatchingParameter <> Undefined Then
			MatchingParameter.Use = False;
		EndIf;
	EndDo;
	
	LastDistributionParameters = ReportMailing.EventLogParameters(ReportsDistributionRef);
	
	DataParametersStructure = New Structure;

	If LastDistributionParameters <> Undefined Then
		Period  = New StandardPeriod;
		Period.StartDate = LastDistributionParameters.StartDate;
		Period.EndDate = LastDistributionParameters.EndDate;
		DataParametersStructure.Insert("Period", DataParameter(Period));
	EndIf;  	
	
	DataParametersStructure.Insert("Recipients", DataParameter(New ValueList(), False));
		
	SetDataParameters(NewDCSettings, DataParametersStructure, NewDCUserSettings);
			
EndProcedure 

// 

#EndRegion

#EndRegion
		
#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("ReportMailing");
	If FoundParameter = Undefined
		Or Not ValueIsFilled(FoundParameter.Value) Then
		Return;
	EndIf;
	
	ReportsDistributionRef = FoundParameter.Value;
	
	FoundParameter = FindUserSettingsParameter(SettingsComposer.UserSettings.Items, "Period");
	If FoundParameter <> Undefined And FoundParameter.Value <> Undefined Then
		Period = FoundParameter.Value;
	Else
		Period = New StandardPeriod;
	EndIf;  
	
	AdditionalParameters = New Structure; 
	
	FoundParameter = FindUserSettingsParameter(SettingsComposer.UserSettings.Items, "Recipients");
	If FoundParameter <> Undefined And FoundParameter.Value <> Undefined Then
		AdditionalParameters.Insert("Recipients", DataParameter(FoundParameter.Value, FoundParameter.Use));
	Else
		AdditionalParameters.Insert("Recipients", DataParameter(New ValueList, False));
	EndIf;  
	
	ResultDocument.Clear();
	
	ReportData = ReportDistributionHistoryData(ReportsDistributionRef, Period, AdditionalParameters); 
	
	DistributionResultsString = StringFunctionsClientServer.SubstituteParametersToString(
	NStr("en = 'Sent: %1. Not sent: %2. Total: %3';"), ReportData.Sent, ReportData.NotSent, ReportData.Total);	
	SettingsComposer.Settings.DataParameters.SetParameterValue("DistributionResultsString", DistributionResultsString);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Settings = SettingsComposer.GetSettings();
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("ReportDistributionHistoryData", ReportData.DistributionHistory);
				
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Function ReportDistributionHistoryData(BulkEmail, Period, AdditionalParameters)
	
	Query = New Query;
	QueryText =
		"SELECT ALLOWED
		|	ReportsDistributionHistory.ReportMailing AS ReportMailing,
		|	ReportsDistributionHistory.Recipient AS Recipient,
		|	ReportsDistributionHistory.Executed AS Success,
		|	ReportsDistributionHistory.Comment AS Comment,
		|	ReportsDistributionHistory.StartDistribution AS StartDistribution,
		|	ReportsDistributionHistory.OutgoingEmail AS OutgoingEmail,
		|	ReportsDistributionHistory.MethodOfObtaining AS MethodOfObtaining,
		|	ReportsDistributionHistory.Period AS Sent,
		|	ReportsDistributionHistory.DeliveryDate AS DeliveryDate,
		|	ReportsDistributionHistory.EMAddress AS EMAddress,
		|	ReportsDistributionHistory.Status AS Status
		|FROM
		|	InformationRegister.ReportsDistributionHistory AS ReportsDistributionHistory
		|WHERE
		|	ReportsDistributionHistory.ReportMailing = &ReportMailing
		|	AND ReportsDistributionHistory.Period BETWEEN &StartDate AND &EndDate";

	Query.SetParameter("ReportMailing", BulkEmail);
	Query.SetParameter("StartDate", Period.StartDate);
	Query.SetParameter("EndDate", ?(ValueIsFilled(Period.EndDate),Period.EndDate,'39991231235959'));
	
	If AdditionalParameters.Recipients.Use Then
		QueryText = QueryText + " AND ReportsDistributionHistory.Recipient IN (&Recipients)";
		Query.SetParameter("Recipients", AdditionalParameters.Recipients.ParameterValue); 
	EndIf;
	
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	DistributionHistory = New ValueTable;
	DistributionHistory.Columns.Add("ReportMailing", New TypeDescription("CatalogRef.ReportMailings")); 
	DistributionHistory.Columns.Add("Recipient", Metadata.DefinedTypes.BulkEmailRecipient.Type);
	DistributionHistory.Columns.Add("Sent", New TypeDescription("Date"));
	DistributionHistory.Columns.Add("EMAddress", New TypeDescription("String", , New StringQualifiers(100)));
	DistributionHistory.Columns.Add("Success", New TypeDescription("Boolean"));
	DistributionHistory.Columns.Add("Comment", New TypeDescription("String"));
	DistributionHistory.Columns.Add("SessionNumber",New TypeDescription("String",,,New NumberQualifiers(25)));
	DistributionHistory.Columns.Add("StartDistribution", New TypeDescription("Date"));
	DistributionHistory.Columns.Add("DeliveryDate", New TypeDescription("Date"));
	DistributionHistory.Columns.Add("MethodOfObtaining", New TypeDescription("String", , New StringQualifiers(500)));
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		DistributionHistory.Columns.Add("OutgoingEmail", New TypeDescription("DocumentRef.OutgoingEmail"));   
	Else
		DistributionHistory.Columns.Add("OutgoingEmail", New TypeDescription("String", , New StringQualifiers(10)));
	EndIf;
		
	While Selection.Next() Do

		RowFilter = New Structure;
		RowFilter.Insert("ReportMailing", Selection.ReportMailing);
		RowFilter.Insert("Recipient", Selection.Recipient);
		RowFilter.Insert("StartDistribution", Selection.StartDistribution);
		RowFilter.Insert("EMAddress", Selection.EMAddress);

		LinesOfHistory = DistributionHistory.FindRows(RowFilter);

		If LinesOfHistory.Count() > 0 Then
			HistoryRow = LinesOfHistory[0];
			HistoryRow.Sent = Max(HistoryRow.Sent, Selection.Sent);
			HistoryRow.Success = Max(HistoryRow.Success, Selection.Success);
			If Selection.Status = Enums.EmailMessagesStatuses.NotDelivered Then
				HistoryRow.Success = False;
			EndIf;
			HistoryRow.Comment = ?(ValueIsFilled(HistoryRow.Comment), HistoryRow.Comment
				+ Chars.LF + Selection.Comment, Selection.Comment);
			If ValueIsFilled(Selection.OutgoingEmail) Then
				HistoryRow.OutgoingEmail = Selection.OutgoingEmail;
			EndIf;
			If ValueIsFilled(Selection.DeliveryDate) Then
				HistoryRow.DeliveryDate = Selection.DeliveryDate;
			EndIf;
		Else
			HistoryRow = DistributionHistory.Add();
			FillPropertyValues(HistoryRow, Selection);
		EndIf;

	EndDo;
		
	Sent = 0;
	NotSent = 0;
	For Each HistoryField In DistributionHistory Do
		If HistoryField.Success Then
			Sent = Sent + 1;
		Else
			NotSent = NotSent + 1;
		EndIf;
	EndDo;
	
	ReportData = New Structure;
	ReportData.Insert("DistributionHistory", DistributionHistory);
	ReportData.Insert("Sent", Sent);
	ReportData.Insert("NotSent", NotSent);
	ReportData.Insert("Total", Sent + NotSent);
	
	Return ReportData;
	
EndFunction

Procedure SetDataParameters(Settings, ParameterValues, UserSettings = Undefined)
	
	DataParameters = Settings.DataParameters.Items;
	
	For Each ParameterValue In ParameterValues Do 
		
		DataParameter = DataParameters.Find(ParameterValue.Key);
		
		If DataParameter = Undefined Then
             Continue;
		EndIf;
		
		DataParameter.Use = ParameterValue.Value.Use;
		DataParameter.Value = ParameterValue.Value.ParameterValue;
		
		If Not ValueIsFilled(DataParameter.UserSettingID)
			Or TypeOf(UserSettings) <> Type("DataCompositionUserSettings") Then 
			Continue;
		EndIf;
		
		MatchingParameter = UserSettings.Items.Find(
			DataParameter.UserSettingID);
		
		If MatchingParameter <> Undefined Then 
			FillPropertyValues(MatchingParameter, DataParameter, "Use, Value");
		EndIf;
		
	EndDo;
	
EndProcedure

Function DataParameter(ParameterValue, Use = True)

	Return New Structure("ParameterValue, Use", ParameterValue, Use);
	
EndFunction

Function FindUserSettingsParameter(UserSettingsElements, ParameterName)   
	
	DesiredParameter = New DataCompositionParameter(ParameterName);

	For Each Item In UserSettingsElements Do 
		If TypeOf(Item) = Type("DataCompositionSettingsParameterValue") And Item.Parameter = DesiredParameter Then
			Return Item;    
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf