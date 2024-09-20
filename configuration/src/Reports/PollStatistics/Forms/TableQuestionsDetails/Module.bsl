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
	
	BasicQuestionsFormulations = New Map;
	
	If ProcessIncomingParameters(BasicQuestionsFormulations) Then
		Cancel = True;
		Return;
	EndIf;
	
	GenerateReport(BasicQuestionsFormulations);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateReport(BasicQuestionsFormulations)

	ReportTable.Clear();
	
	QueryResult = ExecuteQueryOnQuestionnareQuestion();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Template = Reports.PollStatistics.GetTemplate("AnswersTemplate");
	
	Area = Template.GetArea("DoQueryBox");
	Area.Parameters.QuestionWording = Wording;
	ReportTable.Put(Area,1);
	
	AnswersTree = QueryResult.Unload(QueryResultIteration.ByGroups);
	For Each TreeRow In AnswersTree.Rows Do
		OutputToRespondentsDocument(TreeRow,Template,BasicQuestionsFormulations);
	EndDo;

EndProcedure

&AtServer
Procedure OutputToRespondentsDocument(TreeRow,Template, BasicQuestionsFormulations)

	Area = Template.GetArea("Respondent");
	Area.Parameters.Respondent = TreeRow.Respondent;
	ReportTable.Put(Area,1);
	
	ReportTable.StartRowGroup(TreeRow.Respondent);
	OutputTabularAnswer(TreeRow,Template,BasicQuestionsFormulations);
	ReportTable.EndRowGroup();

EndProcedure

&AtServer
Procedure OutputTabularAnswer(TreeRow,Template,BasicQuestionsFormulations)

	If TabularQuestionType = Enums.TabularQuestionTypes.Composite Then
		
		OutputAnswerCompositeTabularQuestion(TreeRow,Template,BasicQuestionsFormulations);
		
	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then
		
		OutputAnswerPredefinedAnswersInColumnsTabularQuestion(TreeRow,Template, BasicQuestionsFormulations);
		
	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows Then
		
		OutputAnswerPredefinedAnswersInRowsTabularQuestion(TreeRow,Template, BasicQuestionsFormulations);
		
	ElsIf TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then
		
		OutputAnswerPredefinedAnswersInRowsAndColumnsTabularQuestion(TreeRow,Template);
		
	EndIf;

EndProcedure

&AtServer
Procedure OutputAnswerCompositeTabularQuestion(TreeRow,Template, BasicQuestionsFormulations)
	
	FirstColumn = True;
	
	For Each DoQueryBox In TableQuestionComposition Do
		
		If FirstColumn Then
			Area = Template.GetArea("Indent");
			ReportTable.Put(Area);
			FirstColumn = False;
		EndIf;
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = BasicQuestionsFormulations.Get(DoQueryBox.ElementaryQuestion);
		ReportTable.Join(Area);
		
	EndDo; 
	
	FirstColumn = True;
	
	For Each TreeRowCell In TreeRow.Rows Do
		
		FirstColumn = True;
		
		For Each TabularQuestionContentRow In TableQuestionComposition Do
			
			FoundRow = TreeRowCell.Rows.Find(TabularQuestionContentRow.ElementaryQuestion,"ElementaryQuestion");
			
			If FirstColumn Then
				Area = Template.GetArea("Indent");
				ReportTable.Put(Area);
				FirstColumn = False;
			EndIf;
			
			Area = Template.GetArea("TableQuestionCell");
			Area.Parameters.Value = ?(FoundRow = Undefined,"",FoundRow.Response);
			ReportTable.Join(Area);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure OutputAnswerPredefinedAnswersInColumnsTabularQuestion(TreeRow,Template, BasicQuestionsFormulations)

	Area = Template.GetArea("Indent");
	ReportTable.Put(Area);
	
	Area = Template.GetArea("TableQuestionHeaderItem");
	ReportTable.Join(Area);
	
	For Each Response In PredefinedAnswers Do
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = Response.Response;
		ReportTable.Join(Area);
		
	EndDo;	
	
	For RowsIndex = 2 To TableQuestionComposition.Count() Do
		
		Area = Template.GetArea("Indent");
		ReportTable.Put(Area);
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = BasicQuestionsFormulations.Get(TableQuestionComposition[RowsIndex - 1].ElementaryQuestion);
		ReportTable.Join(Area);
		
		For ColumnsIndex = 1 To PredefinedAnswers.Count() Do
			
			FilterStructure1 = New Structure;
			FilterStructure1.Insert("ElementaryQuestion", TableQuestionComposition[RowsIndex-1].ElementaryQuestion);
			FilterStructure1.Insert("CellNumber",ColumnsIndex);
			FoundRows = TreeRow.Rows.FindRows(FilterStructure1,True);
			
			Area = Template.GetArea("TableQuestionCell");
			If FoundRows.Count() > 0 Then
				Area.Parameters.Value = FoundRows[0].Response;
			EndIf;
			ReportTable.Join(Area);
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure OutputAnswerPredefinedAnswersInRowsTabularQuestion(TreeRow,Template, BasicQuestionsFormulations)

	FirstColumn = True;
	
	For Each DoQueryBox In TableQuestionComposition Do
		
		If FirstColumn Then
			Area = Template.GetArea("Indent");
			ReportTable.Put(Area);
			FirstColumn = False;
		EndIf;
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = BasicQuestionsFormulations.Get(DoQueryBox.ElementaryQuestion);
		ReportTable.Join(Area);
		
	EndDo;
	
	For Each TreeRowCell In TreeRow.Rows Do
		
		FirstColumn = True;
		
		For ColumnsIndex = 1 To TableQuestionComposition.Count() Do
			
			If FirstColumn Then
				
				Area = Template.GetArea("Indent");
				ReportTable.Put(Area);
				FirstColumn = False;
				
				Area = Template.GetArea("TableQuestionCellItemPredefinedAnswer");
				Area.Parameters.Value = PredefinedAnswers[TreeRowCell.CellNumber - 1].Response;
				ReportTable.Join(Area);
				
			Else
				
				FoundRow = TreeRowCell.Rows.Find(TableQuestionComposition[ColumnsIndex - 1].ElementaryQuestion,"ElementaryQuestion");
				
				Area = Template.GetArea("TableQuestionCell");
				Area.Parameters.Value = ?(FoundRow = Undefined,"",FoundRow.Response);

				ReportTable.Join(Area);
				
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure OutputAnswerPredefinedAnswersInRowsAndColumnsTabularQuestion(TreeRow,Template)
	
	ColumnsAnswers = PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",TableQuestionComposition[1].ElementaryQuestion));
	RowsAnswers = PredefinedAnswers.FindRows(New Structure("ElementaryQuestion",TableQuestionComposition[0].ElementaryQuestion));
	
	If ColumnsAnswers.Count() = 0 And RowsAnswers.Count() = 0 Then
		Return;
	EndIf;
	
	Area = Template.GetArea("Indent");
	ReportTable.Put(Area);
	
	Area = Template.GetArea("TableQuestionHeaderItem");
	ReportTable.Join(Area);
	
	For Each Response In ColumnsAnswers Do
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = Response.Response;
		ReportTable.Join(Area);
		
	EndDo;
	
	For RowIndex = 1 To RowsAnswers.Count()  Do
		
		Area = Template.GetArea("Indent");
		ReportTable.Put(Area);
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = RowsAnswers[RowIndex - 1].Response;
		ReportTable.Join(Area);
		
		For ColumnIndex = 1 To ColumnsAnswers.Count() Do
			
			FilterStructure1 = New Structure;
			FilterStructure1.Insert("CellNumber", ColumnIndex + (RowIndex-1) * ColumnsAnswers.Count());
			FilterStructure1.Insert("ElementaryQuestion",TableQuestionComposition[2].ElementaryQuestion);
			FoundRows = TreeRow.Rows.FindRows(FilterStructure1,True);
			
			Area = Template.GetArea("TableQuestionCell");
			If FoundRows.Count() > 0 Then
				Area.Parameters.Value = FoundRows[0].Response;
			EndIf;
			ReportTable.Join(Area);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Function ExecuteQueryOnQuestionnareQuestion()
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	ISNULL(DocumentQuestionnaire.Respondent, UNDEFINED) AS Respondent,
	|	QuestionnaireQuestionAnswers.CellNumber                  AS CellNumber,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion           AS ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.Response
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|		LEFT JOIN Document.Questionnaire AS DocumentQuestionnaire
	|		ON QuestionnaireQuestionAnswers.Questionnaire = DocumentQuestionnaire.Ref
	|WHERE
	|	QuestionnaireQuestionAnswers.DoQueryBox = &TemplateQuestion
	|	AND DocumentQuestionnaire.Survey = &Survey
	|
	|ORDER BY
	|	Respondent,
	|	CellNumber
	|TOTALS BY
	|	Respondent,
	|	CellNumber";
	
	Query.SetParameter("TemplateQuestion",QuestionnaireTemplateQuestion);
	Query.SetParameter("Survey",Survey);
	
	Return Query.Execute();
	
EndFunction

&AtServer
Function ProcessIncomingParameters(BasicQuestionsFormulations)

	If Parameters.Property("QuestionnaireTemplateQuestion") Then
		QuestionnaireTemplateQuestion = Parameters.QuestionnaireTemplateQuestion;
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("Survey") Then
		Survey = Parameters.Survey; 
	Else
		Return True;
	EndIf;
	
	If Parameters.Property("FullCode") Then
		FullCode =  Parameters.FullCode;
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
	
	TemplateQuestionsAttributes = Common.ObjectAttributesValues(QuestionnaireTemplateQuestion,
		"TabularQuestionType,TableQuestionComposition,PredefinedAnswers,Wording");
	Wording           = TemplateQuestionsAttributes.Wording;
	TabularQuestionType   = TemplateQuestionsAttributes.TabularQuestionType;
	TableQuestionComposition.Load(TemplateQuestionsAttributes.TableQuestionComposition.Unload());
	PredefinedAnswers.Load(TemplateQuestionsAttributes.PredefinedAnswers.Unload());
	GetBasicQuestionsFormulations(BasicQuestionsFormulations);
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Responses to question %1 of survey %2, %3.';"), FullCode, SurveyDescription, Format(SurveyDate, "DLF=D"));
	
	Return False;

EndFunction

&AtServer
Procedure GetBasicQuestionsFormulations(BasicQuestionsFormulations)
	
	Query = New Query;
	Query.Text = "SELECT
	|	QuestionsForSurvey.Ref,
	|	QuestionsForSurvey.Wording,
	|	QuestionsForSurvey.ShowAggregatedValuesInReports
	|FROM
	|	ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|WHERE
	|	QuestionsForSurvey.Ref IN(&QuestionsArray)";
	
	Query.SetParameter("QuestionsArray",TableQuestionComposition.Unload().UnloadColumn("ElementaryQuestion"));
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		BasicQuestionsFormulations.Insert(Selection.Ref,Selection.Wording);
	EndDo;
	
EndProcedure

#EndRegion
