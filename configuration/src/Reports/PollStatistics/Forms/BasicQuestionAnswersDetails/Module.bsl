///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ProcessIncomingParameters() Then
		Cancel = True;
		Return;
	EndIf;
	
	TitleTemplate1 =  NStr("en = 'Responses to question %1 of survey %2, %3.';");
	Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, FullCode, SurveyDescription, Format(SurveyDate,"DLF=D"));
	
	GenerateReport();
	
EndProcedure

&AtClient
Procedure ReportOptionOnChange(Item)
	
	GenerateReport();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateReport()
	
	ReportTable.Clear();
	DCS = Reports.PollStatistics.GetTemplate("SimpleQuestions");
	Settings = DCS.SettingVariants[ReportVariant].Settings;
	
	DCS.Parameters.QuestionnaireTemplateQuestion.Value = QuestionnaireTemplateQuestion;
	DCS.Parameters.Survey.Value               = Survey;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DCS,Settings);
	
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(CompositionTemplate);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ReportTable);
	OutputProcessor.Output(DataCompositionProcessor);
	
	ReportTable.ShowGrid = False;
	ReportTable.ShowHeaders = False;
	
EndProcedure

&AtServer
Function ProcessIncomingParameters()

	If Parameters.Property("QuestionnaireTemplateQuestion") Then	
		QuestionnaireTemplateQuestion = Parameters.QuestionnaireTemplateQuestion; 
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("Survey") Then
		Survey =  Parameters.Survey; 
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("FullCode") Then
		FullCode =  Parameters.FullCode;
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("SurveyDescription") Then
		SurveyDescription =  Parameters.SurveyDescription;
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("SurveyDate") Then
		SurveyDate =  Parameters.SurveyDate;
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("ReportVariant") Then
		ReportVariant = Parameters.ReportVariant;
	Else
		Return True;
	EndIf;

	Return False;
	
EndFunction

#EndRegion
