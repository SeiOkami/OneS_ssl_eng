///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

// 
//   
//    
//    
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProcessOwnerFormParameters();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not ClosingInProgress And IsNewLine Then
		Notify("CancelEnterNewQuestionnaireTemplateLine");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure QuestionsQuestionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	AttributesQuestion = QuestionAttributes(ValueSelected);
	If AttributesQuestion.IsFolder Then
		Return;
	EndIf;
	
	CurItem = Questions.FindByID(Items.Questions.CurrentRow);
	CurItem.ElementaryQuestion = ValueSelected;
	
	CurItem.Presentation = AttributesQuestion.Presentation;
	CurItem.Wording  = AttributesQuestion.Wording;
	CurItem.ReplyType     = AttributesQuestion.ReplyType;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKButton(Command)
	
	ClosingInProgress = True;
	Notify("EndEditComplexQuestionParameters",GenerateParametersStructureToPassToOwner());
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function GenerateParametersStructureToPassToOwner()

	ParametersStructure = New Structure;
	
	QuestionsToReturn = New Array;
	For Each TableRow In Questions Do
		QuestionsToReturn.Add(TableRow.ElementaryQuestion);
	EndDo;
	ParametersStructure.Insert("Questions",QuestionsToReturn);
	ParametersStructure.Insert("Wording",Wording);
	ParametersStructure.Insert("ToolTip",ToolTip);
	ParametersStructure.Insert("HintPlacement",HintPlacement);

	Return ParametersStructure;

EndFunction

&AtServer
Procedure ProcessOwnerFormParameters()
	
	Wording               = Parameters.Wording;
	ToolTip                  = Parameters.ToolTip;
	HintPlacement = Parameters.HintPlacement;
	IsNewLine             = Parameters.IsNewLine;
	
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	|	Questions.ElementaryQuestion,
	|	Questions.LineNumber
	|INTO ElementaryQuestions
	|FROM
	|	&Questions AS Questions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ElementaryQuestions.ElementaryQuestion AS ElementaryQuestion,
	|	ISNULL(QuestionsForSurvey.Presentation, """""""") AS Presentation,
	|	ISNULL(QuestionsForSurvey.Wording, """""""") AS Wording,
	|	ISNULL(QuestionsForSurvey.ReplyType, """") AS ReplyType
	|FROM
	|	ElementaryQuestions AS ElementaryQuestions
	|		LEFT JOIN ChartOfCharacteristicTypes.QuestionsForSurvey AS QuestionsForSurvey
	|		ON ElementaryQuestions.ElementaryQuestion = QuestionsForSurvey.Ref
	|
	|ORDER BY
	|	ElementaryQuestions.LineNumber";
	
	Query.SetParameter("Questions", Parameters.ComplexQuestionComposition.Unload());
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then;
		Selection = Result.Select();
		While Selection.Next() Do
			
			NewRow = Questions.Add();
			FillPropertyValues(NewRow,Selection);
			
		EndDo;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function QuestionAttributes(DoQueryBox)
	
	Return Common.ObjectAttributesValues(DoQueryBox,"Presentation,Wording,IsFolder,ReplyType");
	
EndFunction

#EndRegion
