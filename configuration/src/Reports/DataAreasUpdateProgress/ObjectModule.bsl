///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	UpdateInformation1 = UpdateInformation1();
	
	StandardProcessing = False;
	DCSettings = SettingsComposer.GetSettings();
	ExternalDataSets = New Structure("SummaryInformation, AreasWithIssues",
		UpdateInformation1.SummaryInformation, UpdateInformation1.HandlersInformation);
	
	DCTemplateComposer = New DataCompositionTemplateComposer;
	DCTemplate = DCTemplateComposer.Execute(DataCompositionSchema, DCSettings, DetailsData);
	
	DCProcessor = New DataCompositionProcessor;
	DCProcessor.Initialize(DCTemplate, ExternalDataSets, DetailsData);
	
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	DCResultOutputProcessor.SetDocument(ResultDocument);
	DCResultOutputProcessor.Output(DCProcessor);
	
	ResultDocument.ShowRowGroupLevel(2);
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", UpdateInformation1.SummaryInformation.Count() = 0);
	
EndProcedure

#EndRegion

#Region Private

Function UpdateInformation1()
	
	UpdateProgress = InfobaseUpdate.DataAreasUpdateProgress("Deferred2");
	SummaryInformation = New ValueTable;
	SummaryInformation.Columns.Add("Updated3");
	SummaryInformation.Columns.Add("Running");
	SummaryInformation.Columns.Add("Waiting1");
	SummaryInformation.Columns.Add("Issues");
	
	If UpdateProgress <> Undefined Then
		String = SummaryInformation.Add();
		FillPropertyValues(String, UpdateProgress);
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("ExecutionModes", CommonClientServer.ValueInArray("Deferred"));
	Filter.Insert("Statuses", CommonClientServer.ValueInArray("Error"));
	HandlersInformation = InfobaseUpdate.UpdateHandlers(Filter);
	
	Result = New Structure;
	Result.Insert("SummaryInformation", SummaryInformation);
	Result.Insert("HandlersInformation", HandlersInformation);
	
	Return Result;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf