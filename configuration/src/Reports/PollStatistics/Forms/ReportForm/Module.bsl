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
	
	ReportKind = "ResponsesAnalysis";
	
	Survey = CommonClientServer.StructureProperty(Parameters, "Survey");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(Survey) Then
		Generate(Commands.Generate);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportTable1DetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If Details.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular") Then
		
		OpenStructure = New Structure;
		OpenStructure.Insert("Survey", Survey);
		OpenStructure.Insert("QuestionnaireTemplateQuestion", Details.TemplateQuestion);
		OpenStructure.Insert("FullCode", Details.FullCode);
		OpenStructure.Insert("SurveyDescription", SurveyDescription);
		OpenStructure.Insert("SurveyDate", SurveyDate);
		
		OpenForm("Report.PollStatistics.Form.TableQuestionsDetails", OpenStructure, ThisObject);
		
	Else
		
		OpenStructure = New Structure;
		OpenStructure.Insert("Survey", Survey);
		OpenStructure.Insert("QuestionnaireTemplateQuestion", Details.TemplateQuestion);
		OpenStructure.Insert("ReportVariant", "Respondents");
		OpenStructure.Insert("FullCode", Details.FullCode);
		OpenStructure.Insert("SurveyDescription", SurveyDescription);
		OpenStructure.Insert("SurveyDate", SurveyDate);
		
		OpenForm("Report.PollStatistics.Form.BasicQuestionAnswersDetails", OpenStructure, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Generate(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	GenerateReport();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateReport()
	
	FormAttributeToValue("Report").GenerateReport(ReportTable, Survey, ReportKind);
	AttributesSurvey     = Common.ObjectAttributesValues(Survey,"Description, Date");
	SurveyDescription = AttributesSurvey.Description;
	SurveyDate         = AttributesSurvey.Date;
	
EndProcedure

#EndRegion
