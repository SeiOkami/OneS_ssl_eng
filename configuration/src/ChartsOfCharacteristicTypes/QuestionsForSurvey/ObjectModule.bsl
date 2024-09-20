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

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	NotCheckedAttributeArray = New Array();
	
	If Not CommentRequired Then
		NotCheckedAttributeArray.Add("CommentNote");
	EndIf;
	
	If (ReplyType <> Enums.TypesOfAnswersToQuestion.String)
		And (ReplyType <> Enums.TypesOfAnswersToQuestion.Number) Then
		NotCheckedAttributeArray.Add("Length");
	EndIf;
	If ReplyType <> Enums.TypesOfAnswersToQuestion.InfobaseValue Then
		NotCheckedAttributeArray.Add("ValueType");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributeArray);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
	If Not IsFolder Then
		ClearUnnecessaryAttributes();
		SetCCTType();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// The procedure clears values of unnecessary attributes.
// This situation occurs when the user changes the answer type upon editing.
//
Procedure ClearUnnecessaryAttributes()
	
	If ((ReplyType <> Enums.TypesOfAnswersToQuestion.Number) And (ReplyType <> Enums.TypesOfAnswersToQuestion.String)  And (ReplyType <> Enums.TypesOfAnswersToQuestion.Text))
	   And (Length <> 0)Then
		
		Length = 0;
		
	EndIf;
	
	If (ReplyType <> Enums.TypesOfAnswersToQuestion.Number) Then	
		
		MinValue       = 0;
		MaxValue      = 0;
		ShowAggregatedValuesInReports = False;
		ShouldShowRangeSlider = False;
		RangeSliderStep = 0;
		
	EndIf;
	
	If ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
		CommentRequired = False;
		CommentNote = "";
	EndIf;
	
	If Not ShouldShowHintForNumericalQuestions Then
		NumericalQuestionHintsRange.Clear();
	EndIf;
	
EndProcedure

// Sets a CCT value type depending on the answer type.
Procedure SetCCTType()
	
	If ReplyType = Enums.TypesOfAnswersToQuestion.String Or ReplyType = Enums.TypesOfAnswersToQuestion.Text Then
		ValueType = New TypeDescription("String", , New StringQualifiers(Length));
	ElsIf ReplyType = Enums.TypesOfAnswersToQuestion.Number Then
		ValueType = New TypeDescription("Number",, New NumberQualifiers(?(Length = 0, 15, Length), Accuracy));
	ElsIf ReplyType = Enums.TypesOfAnswersToQuestion.Date Then
		ValueType = New TypeDescription("Date", New DateQualifiers(DateFractions.Date));
	ElsIf ReplyType = Enums.TypesOfAnswersToQuestion.Boolean Then
		ValueType = New TypeDescription("Boolean");
	ElsIf ReplyType = Enums.TypesOfAnswersToQuestion.OneVariantOf
		  Or ReplyType = Enums.TypesOfAnswersToQuestion.MultipleOptionsFor Then
		ValueType =  New TypeDescription("CatalogRef.QuestionnaireAnswersOptions");
	EndIf;

EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf