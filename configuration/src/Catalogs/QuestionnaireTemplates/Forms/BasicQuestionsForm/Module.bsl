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
	
	FillPropertyValues(ThisObject, Parameters);
	If TreeRowType = "Section" Then
		
		Items.GroupMandatory.Visible       = False;
		Items.ElementaryQuestion.Visible       = False;
		Items.TooltipGroup.Visible          = False;
		Items.Wording.Title             = NStr("en = 'Section name';");
		Title                                   = NStr("en = 'Questionnaire template section';");
		
	EndIf;
	
	If Not ElementaryQuestion.IsEmpty() Then
		Items.Wording.ChoiceList.Add(Common.ObjectAttributeValue(ElementaryQuestion,"Wording"));
	EndIf;
	
	If QuestionType = Enums.QuestionnaireTemplateQuestionTypes.QuestionWithCondition Then
		ChoiceParameters = New Array;
		ChoiceParameters.Add(New ChoiceParameter("Filter.ReplyType",PredefinedValue("Enum.TypesOfAnswersToQuestion.Boolean")));
		Items.ElementaryQuestion.ChoiceParameters = New FixedArray(ChoiceParameters);
	EndIf;
	
	If ShouldUseRefusalToAnswer Then
		FlagMandatory = 2;
	ElsIf IsRequired Then
		FlagMandatory = 1;
	Else
		FlagMandatory = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailabilityOfAnswerRefusalStatementFlag();
	
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
Procedure ElementaryQuestionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AttributesQuestion = QuestionAttributes(ValueSelected);
	
	If IsBlankString(Wording)
		Or Wording = PreviousWording Then
		Wording = AttributesQuestion.Wording;
	EndIf;
	
	PreviousWording = AttributesQuestion.Wording;
	
EndProcedure

&AtClient
Procedure NotesStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClosingNotification1 = New NotifyDescription("NoteEditOnClose", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(ClosingNotification1, Item.EditText, NStr("en = 'Notes';"));

EndProcedure

&AtClient
Procedure FlagMandatoryOnChange(Item)
	
	If FlagMandatory = 0 Then
		IsRequired = False;
		ShouldUseRefusalToAnswer = False;
	ElsIf FlagMandatory = 1 Then
		IsRequired = True;
		ShouldUseRefusalToAnswer = False;
	ElsIf FlagMandatory = 2 Then
		IsRequired = True;
		ShouldUseRefusalToAnswer = True;
	EndIf;
	
	SetAvailabilityOfAnswerRefusalStatementFlag();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure MoveToTemplate(Command)
	
	Cancel = False;
	
	If Not ValueIsFilled(Wording) Then
		Cancel = True;
		CommonClient.MessageToUser(NStr("en = 'Wording not filled in';"),,"Wording");
	EndIf;
	
	If TreeRowType = "DoQueryBox" And (Not ValueIsFilled(ElementaryQuestion)) Then
		Cancel = True;
		CommonClient.MessageToUser(NStr("en = 'General question is not specified';"),,"ElementaryQuestion");
	EndIf; 
		
	If ShouldUseRefusalToAnswer And Not ValueIsFilled(RefusalToAnswerText) Then
		Cancel = True;
		CommonClient.MessageToUser(NStr("en = 'Wording not filled in';"),,"RefusalToAnswerText");
	EndIf;
		
	If Cancel Then
		Return;
	EndIf;
	
	ClosingInProgress = True;
	Notify("EndEditQuestionnaireTemplateLineParameters",GenerateParametersStructureToPassToOwner());
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function GenerateParametersStructureToPassToOwner()

	ReturnStructure = New Structure;
	ReturnStructure.Insert("IsRequired", IsRequired);
	ReturnStructure.Insert("Wording", Wording);
	ReturnStructure.Insert("ElementaryQuestion", ElementaryQuestion);
	ReturnStructure.Insert("Notes", Notes);
	ReturnStructure.Insert("IsNewLine", False);
	ReturnStructure.Insert("ToolTip", ToolTip);
	ReturnStructure.Insert("HintPlacement", HintPlacement);
	ReturnStructure.Insert("ShouldUseRefusalToAnswer", ShouldUseRefusalToAnswer);
	ReturnStructure.Insert("RefusalToAnswerText", ?(ShouldUseRefusalToAnswer,
		RefusalToAnswerText, ""));
	
	Return ReturnStructure;

EndFunction

&AtServerNoContext
Function QuestionAttributes(DoQueryBox)
	
	Return Common.ObjectAttributesValues(DoQueryBox,"IsFolder,ReplyType,Wording");
	
EndFunction

&AtClient
Procedure NoteEditOnClose(ReturnText, AdditionalParameters) Export
	
	If Notes <> ReturnText Then
		Notes = ReturnText;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAvailabilityOfAnswerRefusalStatementFlag()
	
	Items.RefusalToAnswerText.Enabled = ShouldUseRefusalToAnswer;
	
EndProcedure

#EndRegion
