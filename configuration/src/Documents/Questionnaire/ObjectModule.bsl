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

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	SetPrivilegedMode(True);
	
	RegisterRecords.QuestionnaireQuestionAnswers.Write = True;
	
	Query = New Query;
	Query.Text = "SELECT
	|	TableComposition.DoQueryBox,
	|	TableComposition.ElementaryQuestion,
	|	TableComposition.CellNumber,
	|	TableComposition.Response,
	|	TableComposition.OpenAnswer,
	|	TableComposition.LineNumber,
	|	TableComposition.IsUnanswered AS IsUnanswered
	|INTO Content
	|FROM
	|	&TableComposition AS TableComposition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Content.DoQueryBox,
	|	Content.ElementaryQuestion,
	|	Content.CellNumber,
	|	CASE
	|		WHEN NOT Content.IsUnanswered
	|			THEN Content.Response
	|	END AS Response,
	|	Content.OpenAnswer,
	|	TRUE AS Active,
	|	&Ref AS Recorder,
	|	&Ref AS Questionnaire,
	|	Content.LineNumber AS LineNumber,
	|	Content.IsUnanswered AS IsUnanswered
	|FROM
	|	Content AS Content";
	
	Query.SetParameter("TableComposition",Content);
	Query.SetParameter("Ref",Ref);
	
	RegisterRecords.QuestionnaireQuestionAnswers.Load(Query.Execute().Unload());
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If FillingData <> Undefined Then
		FillPropertyValues(ThisObject,FillingData);
	EndIf;
	
	If SurveyMode = Enums.SurveyModes.Interview Then
		Interviewer = Users.CurrentUser();
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SurveyMode = Enums.SurveyModes.Interview Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Survey"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("QuestionnaireTemplate"));
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf