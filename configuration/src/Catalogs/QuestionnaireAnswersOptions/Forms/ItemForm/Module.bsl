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

	If Parameters.Property("Owner")
		And TypeOf(Parameters.Owner) = Type("ChartOfCharacteristicTypesRef.QuestionsForSurvey")
		And Not Parameters.Owner.IsEmpty() Then

		Object.Owner = Parameters.Owner;

	Else

		MessageText = NStr("en = 'This form is opened from the form of the item of the chart of characteristic types ""Survey questions"".';");
		Common.MessageToUser(MessageText);
		Cancel = True;
		Return;

	EndIf;

	If Parameters.Property("ReplyType") Then
		Items.OpenEndedQuestion.Visible = (Parameters.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor);
	Else
		Items.OpenEndedQuestion.Visible = (Object.Owner.ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor);
	EndIf;

	If Parameters.Property("Description") Then
		Object.Description = Parameters.Description;
	EndIf;

EndProcedure

#EndRegion