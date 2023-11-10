///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Creates a filter structure for its further transfer to the server
// and usage as filter parameters in dynamic lists of forms to be called.
//
Function CreateFilterParameterStructure(FilterType, LeftValue, Var_ComparisonType, RightValue) Export

	ReturnStructure = New Structure;
	ReturnStructure.Insert("FilterType", FilterType);
	ReturnStructure.Insert("LeftValue", LeftValue);
	ReturnStructure.Insert("ComparisonType", Var_ComparisonType);
	ReturnStructure.Insert("RightValue", RightValue);

	Return ReturnStructure;

EndFunction

// Parameters:
//  Respondent   - DefinedType.Respondent - an interviewee.
//  QuestionnaireTemplate - CatalogRef.QuestionnaireTemplates - a template used for interview.
//               - Undefined - 
//
Procedure StartInterview(Respondent, QuestionnaireTemplate = Undefined) Export

	If QuestionnaireTemplate = Undefined Then

		NotifyDescription = New NotifyDescription("StartInterviewWithTemplateChoiceCompletion", ThisObject, Respondent);

		ShowInputValue(NotifyDescription, Undefined, , Type("CatalogRef.QuestionnaireTemplates"));

	Else

		OpenInterviewForm(Respondent, QuestionnaireTemplate);

	EndIf;

EndProcedure

Procedure OpenInterviewForm(Respondent, QuestionnaireTemplate)

	FillingValues = New Structure;
	FillingValues.Insert("Respondent", Respondent);
	FillingValues.Insert("QuestionnaireTemplate", QuestionnaireTemplate);
	FillingValues.Insert("SurveyMode", PredefinedValue(
		"Enum.SurveyModes.Interview"));

	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	FormParameters.Insert("FillingFormOnly", True);

	QuestionnaireForm = OpenForm("Document.Questionnaire.ObjectForm", FormParameters);

	If QuestionnaireForm <> Undefined Then
		FillPropertyValues(QuestionnaireForm, FillingValues);
	EndIf;

EndProcedure

// StartInterviewWithTemplateChoice procedure execution result handler.
//
Procedure StartInterviewWithTemplateChoiceCompletion(SelectedTemplate, Respondent) Export

	If SelectedTemplate = Undefined Then
		Return;
	EndIf;

	OpenInterviewForm(Respondent, SelectedTemplate);

EndProcedure

Procedure OnChangeQuestion(Form, Item) Export

	QuestionName = Item.Name;

	If StrFind(QuestionName, "_Comment") <> 0 Then
		Return;
	EndIf;

	If StrFind(QuestionName, "_Table") <> 0 Then
		Return;
	EndIf;

	If StrFind(QuestionName, "_Response_") <> 0 Then
		Return;
	EndIf;

	If StrFind(QuestionName, "_Attribute_") <> 0 Then
		OnChangeQuestionWithAnswerOptions(Form, QuestionName);
		Return;
	EndIf;

	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(QuestionName, 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		SetHintForNumericalQuestion(Form, FoundRows[0], QuestionName);
		If FoundRows[0].IsRequired Then
			GroupDescription = QuestionName + "_Group";
			ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, ValueIsFilled(
				Form[QuestionName]));
		EndIf;
	EndIf;

EndProcedure

Procedure OnChangeRangeSlider(Form, Item) Export

	NameOfNumberAttribute = Left(Item.Name, StrFind(Item.Name, "_TrackBar") - 1);
	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(NameOfNumberAttribute, 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		IncrementStep = FoundRows[0].RangeSliderStep;
		Form[NameOfNumberAttribute] = FoundRows[0].MinValue + IncrementStep * Form[Item.Name
			+ "Attribute"];

		SetHintForNumericalQuestion(Form, FoundRows[0], NameOfNumberAttribute);

		If FoundRows[0].IsRequired Then
			GroupDescription = NameOfNumberAttribute + "_Group";
			ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, ValueIsFilled(
				Form[NameOfNumberAttribute]));
		EndIf;
	EndIf;

EndProcedure

Procedure NumberFieldAdjustment(Form, Item, Direction, StandardProcessing) Export

	StandardProcessing = False;

	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(Item.Name, 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		IncrementStep = FoundRows[0].RangeSliderStep;
		NewValue = Form[Item.Name] + Direction * IncrementStep;
		If Direction = 1 And NewValue > Item.MaxValue Then
			Form[Item.Name] = Item.MaxValue;
		ElsIf Direction = -1 And NewValue < Item.MinValue Then
			Form[Item.Name] = Item.MinValue;
		Else
			Form[Item.Name] = NewValue;
		EndIf;
		Form[Item.Name + "_RangeSliderAttribute"] = (Form[Item.Name]
			- FoundRows[0].MinValue) / IncrementStep;

		SetHintForNumericalQuestion(Form, FoundRows[0], Item.Name);

		If FoundRows[0].IsRequired Then
			GroupDescription = Item.Name + "_Group";
			ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, ValueIsFilled(
				Form[Item.Name]));
		EndIf;
	EndIf;

EndProcedure

Procedure OnChangeOfNumberField(Form, Item) Export

	If Form.Items.Find(Item.Name + "_TrackBar") = Undefined Then
		Return;
	EndIf;

	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(Item.Name, 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		IncrementStep = FoundRows[0].RangeSliderStep;
		Form[Item.Name + "_RangeSliderAttribute"] = (Form[Item.Name]
			- FoundRows[0].MinValue) / IncrementStep;

		SetHintForNumericalQuestion(Form, FoundRows[0], Item.Name);

		If FoundRows[0].IsRequired Then
			GroupDescription = Item.Name + "_Group";
			ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, ValueIsFilled(
				Form[Item.Name]));
		EndIf;
	EndIf;

EndProcedure

Procedure OnChangeFlagDoNotAnswerQuestion(Form, Item) Export

	QuestionName = Left(Item.Name, StrFind(Item.Name, "_ShouldUseRefusalToAnswer") - 1);

	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(QuestionName, 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		HighlightAnsweredQuestion(Form, FoundRows[0], QuestionName);
	EndIf;

EndProcedure

Procedure OnChangeQuestionWithAnswerOptions(Form, QuestionName)

	FoundRows = Form.SectionQuestionsTable.FindRows(New Structure("Composite",
		New UUID(StrReplace(Right(Left(QuestionName, 43), 36), "_", "-"))));

	If FoundRows.Count() > 0 Then
		DoQueryBox = FoundRows[0];
		If DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") Then
			OnChangeSingleChoiceQuestion(Form, DoQueryBox, QuestionName);
		ElsIf DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") Then
			OnChangeMultipleChoiceQuestion(Form, DoQueryBox, QuestionName);
		EndIf;
	EndIf;

EndProcedure

Procedure OnChangeSingleChoiceQuestion(Form, DoQueryBox, QuestionName)

	AnswersOptions = Form.PossibleAnswers.FindRows(New Structure("DoQueryBox", DoQueryBox.ElementaryQuestion));
	For Indus = 1 To AnswersOptions.Count() Do
		If Form[QuestionName] = AnswersOptions[Indus - 1].Response Then
			Form.Items[Left(QuestionName, 43) + "_TooltipBreakdown"].Title = AnswersOptions[Indus - 1].ToolTip;
		Else
			Form[Left(QuestionName, 43) + "_Attribute_" + Indus] = Undefined;
		EndIf;
	EndDo;

	If DoQueryBox.IsRequired Then
		GroupDescription = Left(QuestionName, 43) + "_Group";
		ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, True);
	EndIf;

EndProcedure

Procedure OnChangeMultipleChoiceQuestion(Form, DoQueryBox, QuestionName)

	AnswersOptions = Form.PossibleAnswers.FindRows(New Structure("DoQueryBox", DoQueryBox.ElementaryQuestion));
	AnswerExists = False;
	For Indus = 1 To AnswersOptions.Count() Do
		If Form[Left(QuestionName, 43) + "_Attribute_" + Indus] Then
			AnswerExists = True;
			Break;
		EndIf;
	EndDo;

	If DoQueryBox.IsRequired Then
		GroupDescription = Left(QuestionName, 43) + "_Group";
		ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, AnswerExists);
	EndIf;

EndProcedure

Procedure HighlightAnsweredQuestions(Form) Export

	For Each DoQueryBox In Form.SectionQuestionsTable Do
		If DoQueryBox.QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Basic")
			And DoQueryBox.IsRequired Then
			QuestionName = SurveysClientServer.QuestionName(DoQueryBox.Composite);
			HighlightAnsweredQuestion(Form, DoQueryBox, QuestionName);
		EndIf;
	EndDo;

EndProcedure

Procedure HighlightAnsweredQuestion(Form, DoQueryBox, QuestionName)

	IsUnanswered = False;
	If DoQueryBox.ShouldUseRefusalToAnswer Then
		IsUnanswered = Form[QuestionName + "_ShouldUseRefusalToAnswer"];
	EndIf;

	If DoQueryBox.ReplyType <> PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf")
		And DoQueryBox.ReplyType <> PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor")
		And DoQueryBox.ReplyType <> PredefinedValue("Enum.TypesOfAnswersToQuestion.Boolean") Then
		Form.Items[QuestionName].AutoMarkIncomplete = Not IsUnanswered;
	EndIf;

	If DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.Number")
		And DoQueryBox.ShouldShowRangeSlider Then
		Form.Items[QuestionName + "_TrackBar"].Enabled = Not IsUnanswered;
	EndIf;

	If DoQueryBox.CommentRequired Then
		Form.Items[QuestionName + "_Comment"].Enabled = Not IsUnanswered;
	EndIf;

	If DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor")
		Or DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") Then
		Form.Items[QuestionName + "GroupOptions"].Enabled = Not IsUnanswered;
		AnswerExists = HasAnswerToQuestionWithAnswerOptions(Form, DoQueryBox, QuestionName);
	Else
		Form.Items[QuestionName].Enabled = Not IsUnanswered;
		AnswerExists = ValueIsFilled(Form[QuestionName]);
	EndIf;

	If AnswerExists Then
		SetHintForNumericalQuestion(Form, DoQueryBox, QuestionName);
	EndIf;

	HighlightBackground = AnswerExists Or IsUnanswered;

	GroupDescription = QuestionName + "_Group";
	ChangeMandatoryQuestionGroupBackgroundColor(Form.Items[GroupDescription].BackColor, HighlightBackground);

EndProcedure

Function HasAnswerToQuestionWithAnswerOptions(Form, DoQueryBox, QuestionName)

	AnswersOptions = Form.PossibleAnswers.FindRows(New Structure("DoQueryBox", DoQueryBox.ElementaryQuestion));

	If DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.OneVariantOf") Then
		For Indus = 1 To AnswersOptions.Count() Do
			If ValueIsFilled(Form[QuestionName + "_Attribute_" + Indus]) Then
				Form.Items[Left(QuestionName, 43) + "_TooltipBreakdown"].Title = AnswersOptions[Indus
					- 1].ToolTip;
				Return True;
			EndIf;
		EndDo;
	ElsIf DoQueryBox.ReplyType = PredefinedValue("Enum.TypesOfAnswersToQuestion.MultipleOptionsFor") Then
		For Indus = 1 To AnswersOptions.Count() Do
			If Form[Left(QuestionName, 43) + "_Attribute_" + Indus] Then
				Return True;
			EndIf;
		EndDo;
	EndIf;

	Return False;

EndFunction

Procedure SetHintForNumericalQuestion(Form, DoQueryBox, QuestionName)

	If DoQueryBox.ReplyType <> PredefinedValue("Enum.TypesOfAnswersToQuestion.Number") Then
		Return;
	EndIf;

	If DoQueryBox.NumericalQuestionHintsRange.Count() = 0 Then
		Return;
	EndIf;

	ToolTipText = "";
	For Each Span In DoQueryBox.NumericalQuestionHintsRange Do
		If Form[QuestionName] <= Span.ValueUpTo Then
			ToolTipText = Span.ToolTip;
		EndIf;
	EndDo;

	Form.Items[QuestionName].ToolTip = ToolTipText;
	Form.Items[QuestionName + "_TooltipBreakdown"].Title = ToolTipText;

EndProcedure

Procedure ChangeMandatoryQuestionGroupBackgroundColor(QuestionGroupBackgroundColor, HighlightBackground)

	If HighlightBackground Then
		QuestionGroupBackgroundColor = CommonClient.StyleColor("PositiveValueBackColor");
	Else
		QuestionGroupBackgroundColor = New Color;
	EndIf;

EndProcedure

#EndRegion