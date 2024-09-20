///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Generates a spreadsheet document with the report.
//
// Parameters:
//  ReportTable - SpreadsheetDocument - a document, in which data is output.
//  Survey  - DocumentRef.PollPurpose - a survey, on which the report is generated.
//  ReportKind - String - it can take the AnswersAnalysis and RespondersAnalysis values.
//
Procedure GenerateReport(ReportTable,Survey,ReportKind) Export
	
	ReportTable.Clear();
	
	If ReportKind ="ResponsesAnalysis" Then
		
		GenerateAnswersAnalysisReport(ReportTable,Survey);
		
	ElsIf ReportKind = "RespondersAnalysis" Then
		
		GenerateRespondersAnalysisReport(ReportTable,Survey);
		
	Else
		
		Return;
		
	EndIf;
	
EndProcedure

#Region ResponsesAnalysis

// Parameters:
//  ReportTable - SpreadsheetDocument
//  Survey - DocumentRef.PollPurpose
//
Procedure GenerateAnswersAnalysisReport(ReportTable, Survey)
	
	AttributesSurvey = Common.ObjectAttributesValues(Survey, "QuestionnaireTemplate,StartDate,EndDate,Presentation");
	QuestionnaireTemplate = AttributesSurvey.QuestionnaireTemplate;
	QuestionsPresentations = Surveys.PresentationOfQuestionChartGeneralQuestions(QuestionnaireTemplate);
	
	QueryResult = ExecuteQueryByQuestionnaireTemplateQuestions(Survey,QuestionnaireTemplate);
	If QueryResult.IsEmpty() Then
		Return;	
	EndIf;
	
	Template = GetTemplate("AnswersTemplate");
	
	Area = Template.GetArea("Title"); // SpreadsheetDocument
	Area.Parameters.Title = QuestionnaireTemplate.Title;
	Area.Parameters.Survey     = SurveyPresentationForHeader(AttributesSurvey);
	ReportTable.Put(Area,1);
	
	Area = Template.GetArea("IsBlankString");
	ReportTable.Put(Area,1);
	ReportTable.StartRowGroup("Annotation");
	
	Area = Template.GetArea("Annotation");
	ReportTable.Put(Area,2);
	ReportTable.EndRowGroup();
	
	Area = Template.GetArea("IsBlankString");
	ReportTable.Put(Area,1);
	
	QuestionnaireTree = QueryResult.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	If QuestionnaireTree.Rows.Count() > 0 Then
		OutputToSpreadsheetDocument(QuestionnaireTree.Rows,ReportTable,Template,1,New Array, QuestionsPresentations);
	EndIf;
	
EndProcedure 

// It is called recursively, generates full code and calls procedures for outputting questions and sections.
//
// Parameters:
//  TreeRows    - ValueTreeRowCollection - tree rows, for which the action is executed.
//  ReportTable   - SpreadsheetDocument - a document, in which the data is output.
//  Template           - SpreadsheetDocument - a template used to output the data.
//  RecursionLevel - Number             - the current recursion level.
//  ArrayFullCode - Array            - - used to generate a full code of processed rows.
// 
Procedure OutputToSpreadsheetDocument(TreeRows,ReportTable,Template,RecursionLevel,ArrayFullCode, QuestionsPresentations)
	
	If ArrayFullCode.Count() < RecursionLevel Then
		ArrayFullCode.Add(0);
	EndIf;
	
	For Each TreeRow In TreeRows Do
		
		ArrayFullCode[RecursionLevel-1] = ArrayFullCode[RecursionLevel-1] + 1;
		For Indus = RecursionLevel To ArrayFullCode.Count()-1 Do
			ArrayFullCode[Indus] = 0;
		EndDo;
		
		FullCode = StrConcat(ArrayFullCode,".");
		FullCode = SurveysClientServer.DeleteLastCharsFromString(FullCode,"0.",".");
		
		If TreeRow.IsSection Then
			OutputSection(ReportTable,TreeRow,Template,FullCode);
			If TreeRow.Rows.Count() > 0 Then
				OutputToSpreadsheetDocument(TreeRow.Rows,ReportTable,Template,RecursionLevel + 1,ArrayFullCode,QuestionsPresentations);
			EndIf
		Else
			OutputQuestion(ReportTable,TreeRow,Template,FullCode, QuestionsPresentations);
		EndIf;
		ReportTable.EndRowGroup();
		
	EndDo;
	
EndProcedure

// Parameters:
//  ReportTable - SpreadsheetDocument - a document, in which information is output.
//  TreeRow  - ValueTreeRow - a current row with data:
//   * Description - String
//  Template         - SpreadsheetDocument - a template used to output information.
//  FullCode     - String - a full code of a row to be output in the report.
// 
Procedure OutputSection(ReportTable,TreeRow,Template,FullCode)
	
	Area = Template.GetArea("Section");
	Area.Parameters.SectionName = FullCode + " " + TreeRow.Description;
	ReportTable.Put(Area);
	ReportTable.StartRowGroup("FullCode_" + TreeRow.Description);
	
EndProcedure

// Parameters:
//  ReportTable - SpreadsheetDocument - a document, in which information is output.
//  TreeRow  - ValueTreeRow - a current row with data:
//   * Description - String
//  Template         - SpreadsheetDocument - a template used to output information.
//  FullCode - String - a full code of a row to be output in the report.
//
Procedure OutputQuestion(ReportTable,TreeRow,Template,FullCode, QuestionsPresentations)
	
	Area = Template.GetArea("DoQueryBox");
	Area.Parameters.QuestionWording = FullCode + " " + TreeRow.Description;
	ReportTable.Put(Area);
	ReportTable.StartRowGroup("FullCode_" + TreeRow.Description);
	
	If TreeRow.Rows.Count() > 0 Then		
		
		If TreeRow.QuestionType = Enums.QuestionnaireTemplateQuestionTypes.Tabular Then
			
			OutputAnswerTabularQuestion(ReportTable,TreeRow,Template,FullCode,QuestionsPresentations);
			
		Else	
			
			OutputAnswerSimpleQuestion(ReportTable,TreeRow,Template,FullCode);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//  QuestionsPresentations - Map - contains information on the formulation and the Aggregate in reports flag. 
// 
Procedure OutputAnswerTabularQuestion(ReportTable, TreeRow, Template, FullCode, QuestionsPresentations)
	
	If TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.Composite Then
		
		OutputAnswerCompositeTabularQuestion(ReportTable,TreeRow.Rows[0],Template,FullCode, QuestionsPresentations);
		
	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInColumns Then
		
		OutputAnswerPredefinedAnswersInColumnsTabularQuestion(ReportTable,TreeRow,Template,FullCode,QuestionsPresentations);
		
	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRows Then
		
		OutputAnswerPredefinedAnswersInRowsTabularQuestion(ReportTable,TreeRow,Template,FullCode,QuestionsPresentations);
		
	ElsIf TreeRow.TabularQuestionType = Enums.TabularQuestionTypes.PredefinedAnswersInRowsAndColumns Then
		
		OutputAnswerPredefinedAnswersInRowsAndColumnsTabularQuestion(ReportTable,TreeRow,Template,FullCode, QuestionsPresentations);
		
	EndIf;
	
EndProcedure

// Outputs answers from a question chart with predefined answers in columns into a report table.
//
// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//  QuestionsPresentations - Map - contains information on the formulation and the Aggregate in reports flag. 
//
Procedure OutputAnswerPredefinedAnswersInColumnsTabularQuestion(ReportTable, TreeRow, Template, FullCode, QuestionsPresentations)
	
	TreeRowDetails = TreeRow.Rows[0];
	
	Area = Template.GetArea("Indent");
	ReportTable.Put(Area);
	
	Area = Template.GetArea("TableQuestionHeaderItem");
	ReportTable.Join(Area);
	
	TreeRowDetails.PredefinedAnswers.Sort("LineNumber Asc");
	TreeRowDetails.TableQuestionComposition.Sort("LineNumber Asc");
	For Each Response In TreeRowDetails.PredefinedAnswers Do
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = Response.Response;
		ReportTable.Join(Area);
		
	EndDo;
	
	For RowsIndex = 2 To TreeRowDetails.TableQuestionComposition.Count() Do
		
		Area = Template.GetArea("Indent");
		ReportTable.Put(Area);
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = QuestionsPresentations.Get(TreeRowDetails.TableQuestionComposition[RowsIndex - 1].ElementaryQuestion).Wording;
		ReportTable.Join(Area);
		
		For ColumnsIndex = 1 To TreeRowDetails.PredefinedAnswers.Count() Do
			
			FilterStructure1 = New Structure;
			FilterStructure1.Insert("ElementaryQuestionRegister",TreeRowDetails.TableQuestionComposition[RowsIndex-1].ElementaryQuestion);
			FilterStructure1.Insert("CellNumber",ColumnsIndex);
			FoundRows = TreeRow.Rows.FindRows(FilterStructure1);
			
			Area = Template.GetArea("TableQuestionCell");
			If FoundRows.Count() > 0 Then
				If TypeOf(FoundRows[0].AnswerOption) <> Type("Boolean") Then
					Area.Parameters.Value = AggregateValuesToString(FoundRows[0],QuestionsPresentations.Get(TreeRowDetails.TableQuestionComposition[RowsIndex-1].ElementaryQuestion).ShowAggregatedValuesInReports);
					Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
				Else
					For Each FoundRow In FoundRows Do
						If FoundRow.AnswerOption = True Then
							Area.Parameters.Value = FoundRow.Count;
							Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
			ReportTable.Join(Area);
			
		EndDo;
		
	EndDo;
		
EndProcedure

// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//  QuestionsPresentations - Map - contains information on the formulation and the Aggregate in reports flag. 
//
Procedure OutputAnswerPredefinedAnswersInRowsTabularQuestion(ReportTable, TreeRow, Template, FullCode, QuestionsPresentations)
	
	FirstColumn = True;
	TreeRowDetails = TreeRow.Rows[0];
	TreeRowDetails.PredefinedAnswers.Sort("LineNumber Asc");
	TreeRowDetails.TableQuestionComposition.Sort("LineNumber Asc");
	
	For Each DoQueryBox In TreeRowDetails.TableQuestionComposition Do
		
		If FirstColumn Then
			Area = Template.GetArea("Indent");
			ReportTable.Put(Area);
			FirstColumn = False;
		EndIf;
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = QuestionsPresentations.Get(DoQueryBox.ElementaryQuestion).Wording;
		ReportTable.Join(Area); 
		
	EndDo;
	
	For RowsIndex = 1 To TreeRowDetails.PredefinedAnswers.Count() Do
		
		FirstColumn = True;
		
		For ColumnsIndex = 1 To TreeRowDetails.TableQuestionComposition.Count() Do
			
			If FirstColumn Then
				
				Area = Template.GetArea("Indent");
				ReportTable.Put(Area);
				FirstColumn = False;
				
				Area = Template.GetArea("TableQuestionCellItemPredefinedAnswer");
				Area.Parameters.Value = TreeRowDetails.PredefinedAnswers[RowsIndex -1].Response;
				ReportTable.Join(Area);
				
			Else
				
				FilterStructure1 = New Structure;
				FilterStructure1.Insert("ElementaryQuestionRegister",TreeRowDetails.TableQuestionComposition[ColumnsIndex-1].ElementaryQuestion);
				FilterStructure1.Insert("CellNumber",RowsIndex);
				FoundRows = TreeRow.Rows.FindRows(FilterStructure1);
				
				Area = Template.GetArea("TableQuestionCell");
				If FoundRows.Count() > 0 Then
					If TypeOf(FoundRows[0].AnswerOption) <> Type("Boolean") Then
						Area.Parameters.Value = AggregateValuesToString(FoundRows[0],QuestionsPresentations.Get(TreeRowDetails.TableQuestionComposition[ColumnsIndex-1].ElementaryQuestion).ShowAggregatedValuesInReports);
						Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRowDetails.TemplateQuestion,TreeRowDetails.QuestionType,FullCode);
					Else
						For Each FoundRow In FoundRows Do
							If FoundRow.AnswerOption = True Then
								Area.Parameters.Value = FoundRow.Count;
								Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRowDetails.TemplateQuestion,TreeRowDetails.QuestionType,FullCode);
							EndIf;
						EndDo;
					EndIf;
				EndIf;
				ReportTable.Join(Area);
				
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

// Outputs answers from a question chart with predefined answers in rows and columns into a report table.
//
// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//  QuestionsPresentations - Map - contains information on the formulation and the Aggregate in reports flag. 
//
Procedure OutputAnswerPredefinedAnswersInRowsAndColumnsTabularQuestion(ReportTable, TreeRow, Template, FullCode, QuestionsPresentations)
	
	TreeRowDetails = TreeRow.Rows[0];
	
	TreeRowDetails.PredefinedAnswers.Sort("LineNumber Asc");
	TreeRowDetails.TableQuestionComposition.Sort("LineNumber Asc");

	If TreeRowDetails.TableQuestionComposition.Count() <> 3 Then
		Return;
	EndIf;
	
	ShowAggregatedValuesInReports = QuestionsPresentations.Get(TreeRowDetails.TableQuestionComposition[2].ElementaryQuestion).ShowAggregatedValuesInReports;
	
	ColumnsAnswers = TreeRowDetails.PredefinedAnswers.FindRows(New Structure("ElementaryQuestionAnswer",TreeRowDetails.TableQuestionComposition[1].ElementaryQuestion));
	RowsAnswers = TreeRowDetails.PredefinedAnswers.FindRows(New Structure("ElementaryQuestionAnswer",TreeRowDetails.TableQuestionComposition[0].ElementaryQuestion));
	
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
			FilterStructure1.Insert("ElementaryQuestionRegister",TreeRowDetails.TableQuestionComposition[2].ElementaryQuestion);
			FoundRows = TreeRow.Rows.FindRows(FilterStructure1);
			
			Area = Template.GetArea("TableQuestionCell");
			If FoundRows.Count() > 0 Then
				If TypeOf(FoundRows[0].AnswerOption) <> Type("Boolean") Then
					Area.Parameters.Value = AggregateValuesToString(FoundRows[0],ShowAggregatedValuesInReports);
					Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
				Else
					For Each FoundRow In FoundRows Do
						If FoundRow.AnswerOption = True Then
							Area.Parameters.Value = FoundRow.Count;
							Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
			ReportTable.Join(Area);
		EndDo;
		
	EndDo;
	
EndProcedure

// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//  QuestionsPresentations - Map - contains information on the formulation and the Aggregate in reports flag.
//
Procedure OutputAnswerCompositeTabularQuestion(ReportTable, TreeRow, Template, FullCode, QuestionsPresentations)
	
	FirstColumn = True;
	
	TreeRow.TableQuestionComposition.Sort("LineNumber Asc");
	For Each DoQueryBox In TreeRow.TableQuestionComposition Do
		
		If FirstColumn Then
			Area = Template.GetArea("Indent");
			ReportTable.Put(Area);
			FirstColumn = False;
		EndIf;
		
		Area = Template.GetArea("TableQuestionHeaderItem");
		Area.Parameters.Value = QuestionsPresentations.Get(DoQueryBox.ElementaryQuestion).Wording;
		ReportTable.Join(Area); 
		
	EndDo;
	
	For RowsIndex = 1 To 3 Do
		
		FirstColumn = True;
		
		For ColumnsIndex = 1 To TreeRow.TableQuestionComposition.Count() Do
			
			If FirstColumn Then
				Area = Template.GetArea("Indent");
				ReportTable.Put(Area);
				FirstColumn = False;
			EndIf;
			
			Area = Template.GetArea("TableQuestionCell");
			Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
			ReportTable.Join(Area);
			
		EndDo;
	EndDo;
	
EndProcedure

// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//
Procedure OutputAnswerSimpleQuestion(ReportTable, TreeRow, Template, FullCode)
	
	TreeRowDetails = TreeRow.Rows[0];
	
	If TreeRowDetails.ReplyType = Enums.TypesOfAnswersToQuestion.Boolean
		Or TreeRowDetails.ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf
		Or TreeRowDetails.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
		
		OutputAnswerAnswersOptions(ReportTable,TreeRow,Template,FullCode);
		
	Else
		
		Area = Template.GetArea("AnswerToSimpleQuestion");
		Area.Parameters.Value = AggregateValuesToString(TreeRowDetails);
		Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
		ReportTable.Put(Area);
		
	EndIf;
	
EndProcedure

// Параметры:
// Parameters:
//  ReportTable         - SpreadsheetDocument - a document, in which information is output.
//  TreeRow          - ValueTreeRow - a current row with data.
//  Template                 - SpreadsheetDocument - a template used to output information.
//  FullCode             - String - a full code of a row to be output in the report.
//
Procedure OutputAnswerAnswersOptions(ReportTable,TreeRow,Template,FullCode)
	
	If TreeRow.Rows[0].ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then
		
		Area = Template.GetArea("AnswersOptions");
		Area.Parameters.AnswerOption = NStr("en = 'Yes';");
		FoundRow = TreeRow.Rows.Find(True,"AnswerOption");
		If FoundRow <> Undefined Then
			Area.Parameters.Value = FoundRow.Count;
			Area.Parameters.Details =New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
		EndIf;
		ReportTable.Put(Area);
		
		Area = Template.GetArea("AnswersOptions");
		Area.Parameters.AnswerOption = NStr("en = 'No';");
		FoundRow = TreeRow.Rows.Find(False,"AnswerOption");
		If FoundRow <> Undefined Then
			Area.Parameters.Value = FoundRow.Count;
			Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
		EndIf;
		ReportTable.Put(Area);
		
	Else	
		
		For Each DetailsRow In TreeRow.Rows Do
			
			Area = Template.GetArea("AnswersOptions");
			Area.Parameters.AnswerOption = DetailsRow.AnswerOption;
			Area.Parameters.Value = DetailsRow.Count;
			Area.Parameters.Details = New Structure("TemplateQuestion,QuestionType,FullCode",TreeRow.TemplateQuestion,TreeRow.QuestionType,FullCode);
			ReportTable.Put(Area);
			
		EndDo;
	EndIf;
	
EndProcedure

// Parameters:
//  Survey  - DocumentRef.PollPurpose - a survey on which the query is created.
//  QuestionnaireTemplate - CatalogRef.QuestionnaireTemplates - used for the survey.
//
// Returns:
//   QueryResult   - result of the executed request.
//
Function ExecuteQueryByQuestionnaireTemplateQuestions(Survey,QuestionnaireTemplate)
	
	Query = New Query;
	Query.Text = " 
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox AS DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion AS ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber AS CellNumber,
	|	QuestionnaireQuestionAnswers.Response AS AnswerOption,
	|	COUNT(QuestionnaireQuestionAnswers.Response) AS DifferentItemsCount
	|INTO RegisterDataBooleanResponseOptions
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) IN (TYPE(BOOLEAN), TYPE(Catalog.QuestionnaireAnswersOptions))
	|			
	|GROUP BY
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber,
	|	QuestionnaireQuestionAnswers.Response
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox AS DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion AS ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber AS CellNumber,
	|	NULL AS AnswerOption,
	|	MIN(QuestionnaireQuestionAnswers.Response) AS Minimum,
	|	MAX(QuestionnaireQuestionAnswers.Response) AS Maximum,
	|	AVG(CAST(QuestionnaireQuestionAnswers.Response AS NUMBER)) AS Mean,
	|	SUM(CAST(QuestionnaireQuestionAnswers.Response AS NUMBER)) AS Sum,
	|	COUNT(QuestionnaireQuestionAnswers.Response) AS DifferentItemsCount
	|INTO RegisterData
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) = TYPE(NUMBER)
	|	AND QuestionnaireQuestionAnswers.IsUnanswered = FALSE
	|GROUP BY
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber
	|
	|UNION ALL
	|
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber,
	|	NULL,
	|	MIN(QuestionnaireQuestionAnswers.Response),
	|	MAX(QuestionnaireQuestionAnswers.Response),
	|	AVG(0),
	|	SUM(0),
	|	COUNT(QuestionnaireQuestionAnswers.Response)
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) = TYPE(DATE)
	|	AND QuestionnaireQuestionAnswers.IsUnanswered = FALSE
	|
	|GROUP BY
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber
	|
	|UNION ALL
	|
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber,
	|	QuestionnaireQuestionAnswers.Response,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	COUNT(QuestionnaireQuestionAnswers.Response)
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) = TYPE(BOOLEAN)
	|	
	|GROUP BY
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber,
	|	QuestionnaireQuestionAnswers.Response
	|			
	|UNION ALL
	|
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	COUNT(QuestionnaireQuestionAnswers.Response)
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) <> TYPE(BOOLEAN)
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) <> TYPE(DATE)
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) <> TYPE(NUMBER)
	|	AND VALUETYPE(QuestionnaireQuestionAnswers.Response) <> TYPE(Catalog.QuestionnaireAnswersOptions)
	|	AND QuestionnaireQuestionAnswers.IsUnanswered = FALSE
	|	
	|GROUP BY
	|	QuestionnaireQuestionAnswers.DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireTemplateQuestions.Presentation AS Wording,
	|	QuestionnaireTemplateQuestions.IsFolder AS IsSection,
	|	ISNULL(QuestionsForSurvey.ReplyType, VALUE(Enum.TypesOfAnswersToQuestion.EmptyRef)) AS ReplyType,
	|	QuestionnaireTemplateQuestions.Ref AS Ref,
	|	ISNULL(QuestionsForSurvey.ShowAggregatedValuesInReports, FALSE) AS ShowAggregatedValuesInReports
	|INTO QuestionnaireTemplateQuestions
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|	LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON QuestionnaireTemplateQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|WHERE
	|	QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|	AND (NOT QuestionnaireTemplateQuestions.IsFolder)
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireTemplateQuestions.IsSection AS IsSection,
	|	QuestionnaireTemplateQuestions.ReplyType AS ReplyType,
	|	QuestionnaireTemplateQuestions.Ref AS Ref,
	|	QuestionnaireTemplateQuestions.ShowAggregatedValuesInReports AS ShowAggregatedValuesInReports
	|INTO QuestionnaireTemplateQuestionsOptions
	|FROM 
	|	QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|WHERE
	|	QuestionnaireTemplateQuestions.ReplyType <> VALUE(Enum.TypesOfAnswersToQuestion.OneVariantOf)
	|AND QuestionnaireTemplateQuestions.ReplyType <> VALUE(Enum.TypesOfAnswersToQuestion.MultipleOptionsFor)
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireTemplateQuestions.Presentation AS Wording,
	|	QuestionnaireTemplateQuestions.IsFolder AS IsSection,
	|	ISNULL(QuestionsForSurvey.ReplyType, VALUE(Enum.TypesOfAnswersToQuestion.EmptyRef)) AS ReplyType,
	|	QuestionnaireTemplateQuestions.Ref AS Ref,
	|	QuestionnaireAnswersOptions.Ref AS AnswerOption,
	|	ISNULL(QuestionsForSurvey.ShowAggregatedValuesInReports, FALSE) AS ShowAggregatedValuesInReports,
	|	QuestionnaireAnswersOptions.AddlOrderingAttribute AS Code,
	|	QuestionnaireTemplateQuestions.ElementaryQuestion AS ElementaryQuestion
	|INTO QuestionnaireTemplateQuestionsQuestions
	|FROM
	|	Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|	LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|	LEFT JOIN Catalog.QuestionnaireAnswersOptions AS QuestionnaireAnswersOptions
	|		ON QuestionsForSurvey.Ref = QuestionnaireAnswersOptions.Owner
	|		ON QuestionnaireTemplateQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|WHERE
	|	QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|	AND (NOT QuestionnaireTemplateQuestions.IsFolder)
	|	AND QuestionsForSurvey.ReplyType IN (VALUE(Enum.TypesOfAnswersToQuestion.OneVariantOf), VALUE(Enum.TypesOfAnswersToQuestion.MultipleOptionsFor))
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireQuestionAnswers.DoQueryBox AS DoQueryBox,
	|	QuestionnaireQuestionAnswers.ElementaryQuestion AS ElementaryQuestion,
	|	QuestionnaireQuestionAnswers.CellNumber AS CellNumber,
	|	QuestionnaireQuestionAnswers.Response AS Response
	|INTO AnswersToTableQuestions
	|FROM
	|	InformationRegister.QuestionnaireQuestionAnswers AS QuestionnaireQuestionAnswers
	|	LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON QuestionnaireQuestionAnswers.ElementaryQuestion = QuestionsForSurvey.Ref
	|	LEFT JOIN Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|		ON QuestionnaireQuestionAnswers.DoQueryBox = QuestionnaireTemplateQuestions.Ref
	|WHERE
	|	QuestionnaireQuestionAnswers.Questionnaire.Survey = &Survey
	|	AND (NOT QuestionnaireTemplateQuestions.TabularQuestionType = VALUE(Enum.TabularQuestionTypes.Composite))
	|	AND QuestionnaireTemplateQuestions.QuestionType = VALUE(Enum.QuestionnaireTemplateQuestionTypes.Tabular)
	|	AND QuestionsForSurvey.ReplyType IN (VALUE(Enum.TypesOfAnswersToQuestion.BOOLEAN), VALUE(Enum.TypesOfAnswersToQuestion.OneVariantOf), VALUE(Enum.TypesOfAnswersToQuestion.MultipleOptionsFor))
	|;
	|////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	QuestionnaireTemplateQuestions.Wording AS Description,
	|	QuestionnaireTemplateQuestions.Ref AS TemplateQuestion,
	|	QuestionnaireTemplateQuestions.IsFolder AS IsSection,
	|	MainQuery.ElementaryQuestionRegister,
	|	MainQuery.CellNumber AS CellNumber,
	|	MainQuery.AnswerOption,
	|	ISNULL(MainQuery.DifferentItemsCount, 0) AS Count,
	|	ISNULL(MainQuery.Minimum, 0) AS Minimum,
	|	ISNULL(MainQuery.Maximum, 0) AS Maximum,
	|	ISNULL(MainQuery.Mean, 0) AS Mean,
	|	ISNULL(MainQuery.Sum, 0) AS Sum,
	|	MainQuery.ReplyType,
	|	QuestionnaireTemplateQuestions.QuestionType,
	|	QuestionnaireTemplateQuestions.TabularQuestionType,
	|	QuestionnaireTemplateQuestions.TableQuestionComposition.(
	|		LineNumber,
	|		ElementaryQuestion
	|	),
	|	QuestionnaireTemplateQuestions.PredefinedAnswers.(
	|		LineNumber AS LineNumber,
	|		ElementaryQuestion AS ElementaryQuestionAnswer,
	|		Response
	|	),
	|	MainQuery.ShowAggregatedValuesInReports
	|{SELECT
	|	ElementaryQuestion.*}
	|FROM
	|	(SELECT
	|		QuestionnaireTemplateQuestionsOptions.Ref                    AS TemplateQuestion,
	|		QuestionnaireTemplateQuestionsOptions.IsSection                 AS IsSection,
	|		RegisterData.ElementaryQuestion                      AS ElementaryQuestionRegister,
	|		RegisterData.CellNumber                             AS CellNumber,
	|		RegisterData.AnswerOption                           AS AnswerOption,
	|		RegisterData.DifferentItemsCount                     AS DifferentItemsCount,
	|		RegisterData.Minimum                                 AS Minimum,
	|		RegisterData.Maximum                                AS Maximum,
	|		RegisterData.Mean                                 AS Mean,
	|		RegisterData.Sum                                   AS Sum,
	|		QuestionnaireTemplateQuestionsOptions.ReplyType                 AS ReplyType,
	|		QuestionnaireTemplateQuestionsOptions.ShowAggregatedValuesInReports AS ShowAggregatedValuesInReports,
	|		0 AS                                                  ResponseOptionCode
	|	FROM
	|		QuestionnaireTemplateQuestionsOptions AS QuestionnaireTemplateQuestionsOptions
	|			LEFT JOIN RegisterData AS RegisterData
	|			ON QuestionnaireTemplateQuestionsOptions.Ref = RegisterData.DoQueryBox
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		QuestionnaireTemplateQuestionsQuestions.Ref,
	|		QuestionnaireTemplateQuestionsQuestions.IsSection,
	|		ISNULL(RegisterDataBooleanResponseOptions.ElementaryQuestion, QuestionnaireTemplateQuestionsQuestions.ElementaryQuestion),
	|		RegisterDataBooleanResponseOptions.CellNumber,
	|		QuestionnaireTemplateQuestionsQuestions.AnswerOption,
	|		RegisterDataBooleanResponseOptions.DifferentItemsCount,
	|		NULL,
	|		NULL,
	|		NULL,
	|		NULL,
	|		QuestionnaireTemplateQuestionsQuestions.ReplyType,
	|		QuestionnaireTemplateQuestionsQuestions.ShowAggregatedValuesInReports,
	|		QuestionnaireTemplateQuestionsQuestions.Code
	|	FROM
	|		QuestionnaireTemplateQuestionsQuestions AS QuestionnaireTemplateQuestionsQuestions
	|			LEFT JOIN RegisterDataBooleanResponseOptions AS RegisterDataBooleanResponseOptions
	|			ON QuestionnaireTemplateQuestionsQuestions.Ref = RegisterDataBooleanResponseOptions.DoQueryBox
	|				AND QuestionnaireTemplateQuestionsQuestions.AnswerOption = RegisterDataBooleanResponseOptions.AnswerOption
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref,
	|		QuestionnaireTemplateQuestions.IsFolder,
	|		QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion,
	|		AnswersToTableQuestions.CellNumber,
	|		NULL,
	|		COUNT(DISTINCT AnswersToTableQuestions.Response),
	|		NULL,
	|		NULL,
	|		NULL,
	|		NULL,
	|		NULL,
	|		NULL,
	|		NULL
	|	FROM
	|		Catalog.QuestionnaireTemplateQuestions.TableQuestionComposition AS QuestionnaireTemplateQuestionsCompositionOfTableQuestion
	|			LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|			ON QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion = QuestionsForSurvey.Ref
	|			LEFT JOIN AnswersToTableQuestions AS AnswersToTableQuestions
	|			ON QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref = AnswersToTableQuestions.DoQueryBox
	|				AND QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion = AnswersToTableQuestions.ElementaryQuestion
	|			LEFT JOIN Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|			ON QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref = QuestionnaireTemplateQuestions.Ref
	|	WHERE
	|		QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref IN
	|				(SELECT
	|					QuestionnaireTemplateQuestions.Ref
	|				FROM
	|					Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|				WHERE
	|					QuestionnaireTemplateQuestions.QuestionType = VALUE(Enum.QuestionnaireTemplateQuestionTypes.Tabular)
	|					AND QuestionnaireTemplateQuestions.Owner = &QuestionnaireTemplate
	|					AND (NOT QuestionnaireTemplateQuestions.TabularQuestionType = VALUE(Enum.TabularQuestionTypes.Composite)))
	|		AND QuestionsForSurvey.ReplyType IN (VALUE(Enum.TypesOfAnswersToQuestion.BOOLEAN), VALUE(Enum.TypesOfAnswersToQuestion.OneVariantOf), VALUE(Enum.TypesOfAnswersToQuestion.MultipleOptionsFor))
	|	
	|	GROUP BY
	|		QuestionnaireTemplateQuestionsCompositionOfTableQuestion.Ref,
	|		QuestionnaireTemplateQuestions.IsFolder,
	|		QuestionnaireTemplateQuestionsCompositionOfTableQuestion.ElementaryQuestion,
	|		AnswersToTableQuestions.CellNumber) AS MainQuery
	|		LEFT JOIN Catalog.QuestionnaireTemplateQuestions AS QuestionnaireTemplateQuestions
	|		ON MainQuery.TemplateQuestion = QuestionnaireTemplateQuestions.Ref
	|
	|ORDER BY
	|	TemplateQuestion,
	|	MainQuery.ResponseOptionCode,
	|	CellNumber
	|TOTALS BY
	|	TemplateQuestion HIERARCHY";
	
	Query.SetParameter("Survey", Survey);
	Query.SetParameter("QuestionnaireTemplate",QuestionnaireTemplate);
	
	Return Query.Execute();
	
EndFunction

// Parameters:
//   TreeRow - ValueTreeRow
//
// Returns:
//   String
//
Function AggregateValuesToString(TreeRow,ShowAggregatedValuesInReports = Undefined)
	
	If TypeOf(TreeRow.Maximum) = Type("Date") Then
		Maximum = Format(TreeRow.Maximum, "DLF=D");
	Else
		Maximum = Format(Round(TreeRow.Maximum,2),"NDS=.");
	EndIf;
	
	If TypeOf(TreeRow.Minimum) = Type("Date") Then
		Minimum = Format(TreeRow.Minimum, "DLF=D");
	Else
		Minimum = Format(Round(TreeRow.Minimum,2),"NDS=.");
	EndIf;
	
	Count = Format(TreeRow.Count,"NDS=.");
	Mean    = Format(Round(TreeRow.Mean,2),"NDS=.");
	Sum      = Format(Round(TreeRow.Sum,2),"NDS=.");
	
	SlashString = " / ";
	
	ReturnString = "" + ?(IsBlankString(Count),"",Count) + Chars.LF 
	+ ?(IsBlankString(Minimum),"",Minimum + SlashString)+ ?(IsBlankString(Maximum),"",Maximum + SlashString) + ?(IsBlankString(Mean),"",Mean)
	+ ?(?(ShowAggregatedValuesInReports = Undefined,TreeRow.ShowAggregatedValuesInReports,ShowAggregatedValuesInReports),Chars.LF + ?(IsBlankString(Sum) = "∑ 0","","∑ " + Sum),"");
	
	SurveysClientServer.DeleteLastCharsFromString(ReturnString,SlashString);
	
	Return ReturnString;
	
EndFunction

#EndRegion

#Region RespondersAnalysis

// Parameters:
//  ReportTable - SpreadsheetDocument - Spreadsheet document to output the report to.
//  Survey         - DocumentRef.PollPurpose - a survey for which the report is created.
//
Procedure GenerateRespondersAnalysisReport(ReportTable,Survey)

	AttributesSurvey = Common.ObjectAttributesValues(Survey,"QuestionnaireTemplate,RespondentsType,FreeSurvey,StartDate,EndDate,Presentation");
	
	If AttributesSurvey.FreeSurvey Then
		QueryResult = ExecuteQueryOnFreeFormSurveysRespondents(Survey, AttributesSurvey.RespondentsType);
	Else
		QueryResult = ExecuteQueryOnSurveysRespondentsWithSpecificCompositionOfRespondents(Survey);
	EndIf;
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	OutputRespondersQueryResultToSpreadsheetDocument(QueryResult,AttributesSurvey,ReportTable);

EndProcedure

// Parameters:
//  QueryResult - QueryResult  - query execution result.
//  AttributesSurvey   - Structure - contains values of the SurveyPurpose attributes.
//  ReportTable   - SpreadsheetDocument - Spreadsheet document to output the report to.
//
Procedure OutputRespondersQueryResultToSpreadsheetDocument(QueryResult,AttributesSurvey,ReportTable)
	
	Template = GetTemplate("AnsweredTemplate");
	
	Area = Template.GetArea("Title");// SpreadsheetDocument
	Area.Parameters.Title = AttributesSurvey.QuestionnaireTemplate.Title;
	Area.Parameters.Survey 	= SurveyPresentationForHeader(AttributesSurvey);
	ReportTable.Put(Area,1);
	
	OverallSelection = QueryResult.Select(QueryResultIteration.ByGroups);
	While OverallSelection.Next() Do
		
		OutputRespondentsRowToSpreadsheetDocument(OverallSelection,Template,ReportTable,"Overall");
		ReportTable.StartRowGroup("Overall");
		
		AnsweredSelection = OverallSelection.Select(QueryResultIteration.ByGroups);
		While AnsweredSelection.Next() Do
			OutputRespondentsRowToSpreadsheetDocument(AnsweredSelection,Template,ReportTable,"TotalResponse");
			ReportTable.StartRowGroup("AnsweredTotal");
			DetailsSelection = AnsweredSelection.Select();
			While DetailsSelection.Next() Do
				OutputRespondentsRowToSpreadsheetDocument(DetailsSelection,Template,ReportTable,"Respondent");
			EndDo;
			ReportTable.EndRowGroup();
		EndDo;
		ReportTable.EndRowGroup();
	EndDo;
	
EndProcedure

// Parameters:
//  Selection       - QueryResultSelection - a selection containing the data to be displayed in the report.
//  Template         - SpreadsheetDocument - Spreadsheet document containing the report template.
//  ReportTable - SpreadsheetDocument - Spreadsheet document to output the string to.
//  AreaName    - String - a name of the template area to be used for output.
//
Procedure OutputRespondentsRowToSpreadsheetDocument(Selection,Template,ReportTable,AreaName);
	
	Area = Template.GetArea(AreaName);
	If Selection.RecordType() = QueryRecordType.Overall Then
		Area.Parameters.Count = Selection.Respondent;
	ElsIf Selection.RecordType() = QueryRecordType.GroupTotal Then
		Area.Parameters.Count = Selection.Respondent;
		Area.Parameters.replied    = Selection.Answered_SSLy;
	Else
		Area.Parameters.Respondent = Selection.Respondent;
	EndIf;
	ReportTable.Put(Area);
	
EndProcedure

// Parameters:
//  Survey - DocumentRef.PollPurpose - a survey for which the report is created.
//  
// Returns:
//   QueryResult
//
Function ExecuteQueryOnSurveysRespondentsWithSpecificCompositionOfRespondents(Survey)
	
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	Questionnaire.Respondent,
	|	Questionnaire.Posted
	|INTO RespondentsThatAnswered
	|FROM
	|	Document.Questionnaire AS Questionnaire
	|WHERE
	|	Questionnaire.Survey = &Survey
	|	AND (NOT Questionnaire.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN RespondentsThatAnswered.Respondent IS NULL 
	|			THEN &NotFilled2
	|		ELSE CASE
	|				WHEN RespondentsThatAnswered.Posted
	|					THEN &Filled2
	|				ELSE &StartedFilling
	|			END
	|	END AS Answered_SSLy,
	|	PurposeOfSurveysRespondents.Respondent AS Respondent
	|FROM
	|	Document.PollPurpose.Respondents AS PurposeOfSurveysRespondents
	|		LEFT JOIN RespondentsThatAnswered AS RespondentsThatAnswered
	|		ON (RespondentsThatAnswered.Respondent = PurposeOfSurveysRespondents.Respondent)
	|WHERE
	|	PurposeOfSurveysRespondents.Ref = &Survey
	|
	|ORDER BY
	|	Answered_SSLy,
	|	Respondent
	|TOTALS
	|	COUNT(DISTINCT Respondent)
	|BY
	|	OVERALL,
	|	Answered_SSLy";
	
	Query.SetParameter("Survey",Survey);
	Query.SetParameter("Filled2",NStr("en = 'Respondent';"));
	Query.SetParameter("StartedFilling",NStr("en = 'Started filling';"));
	Query.SetParameter("NotFilled2",NStr("en = 'Not filled';"));
	
	Return Query.Execute();
	
EndFunction

// Parameters:
//  Survey           - DocumentRef.PollPurpose - a survey for which the report is created.
//  RespondentsType - CatalogRef - an empty reference to the catalog the elements 
//                    of which are respondents for this survey.
// Returns:
//   QueryResult
//
Function ExecuteQueryOnFreeFormSurveysRespondents(Survey,RespondentsType)
	
	RespondentTypeMetadata = RespondentsType.Metadata();
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	CatalogTable.Ref
	|INTO CatalogData
	|FROM
	|	&CatalogTable AS CatalogTable
	|WHERE
	|	(NOT CatalogTable.DeletionMark)
	|	AND &IsFolder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Questionnaire.Respondent,
	|	Questionnaire.Posted
	|INTO RespondentsThatAnswered
	|FROM
	|	Document.Questionnaire AS Questionnaire
	|WHERE
	|	(NOT Questionnaire.DeletionMark)
	|	AND Questionnaire.Survey = &Survey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN RespondentsThatAnswered.Respondent IS NULL 
	|			THEN &NotFilled2
	|		ELSE CASE
	|				WHEN RespondentsThatAnswered.Posted
	|					THEN &Filled2
	|				ELSE &StartedFilling
	|			END
	|	END AS Answered_SSLy,
	|	CatalogData.Ref AS Respondent
	|FROM
	|	CatalogData AS CatalogData
	|		LEFT JOIN RespondentsThatAnswered AS RespondentsThatAnswered
	|		ON CatalogData.Ref = RespondentsThatAnswered.Respondent
	|
	|ORDER BY
	|	Answered_SSLy,
	|   Respondent
	|TOTALS
	|	COUNT(DISTINCT Respondent)
	|BY
	|	OVERALL,
	|	Answered_SSLy";
	
	Query.Text = StrReplace(Query.Text, "&CatalogTable", RespondentTypeMetadata.FullName());
	Query.Text = StrReplace(Query.Text, "&IsFolder", 
		?(RespondentTypeMetadata.Hierarchical And RespondentTypeMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems,
	         "NOT CatalogTable.IsFolder", "TRUE"));
	
	Query.SetParameter("Survey",Survey);
	Query.SetParameter("Filled2",NStr("en = 'Respondent';"));
	Query.SetParameter("StartedFilling",NStr("en = 'Started filling';"));
	Query.SetParameter("NotFilled2",NStr("en = 'Not filled';"));
	
	Return Query.Execute();
	
EndFunction

#EndRegion

#Region Other

Function SurveyPresentationForHeader(AttributesSurvey)
	
	If AttributesSurvey.StartDate <> Date(1, 1, 1) And AttributesSurvey.EndDate <> Date(1, 1, 1) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A survey is held from %1 to %2 on a basis of a document %3.';"),
			Format(AttributesSurvey.StartDate, "DLF=DD"), Format(AttributesSurvey.EndDate, "DLF=DD"),
			AttributesSurvey.Presentation);
	ElsIf AttributesSurvey.StartDate <> Date(1, 1, 1) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A survey is held from %1 on a basis of a document %2.';"),
			Format(AttributesSurvey.StartDate, "DLF=DD"), 
			AttributesSurvey.Presentation);
	ElsIf AttributesSurvey.EndDate <> Date(1, 1, 1) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A survey is held until %1 on a basis of a document %2.';"),
			Format(AttributesSurvey.EndDate, "DLF=DD"), 
			AttributesSurvey.Presentation);
	Else
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A survey is held on a basis of a document %1.';"),
			AttributesSurvey.Presentation);
	EndIf; 
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf