///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Deletes the last characters from the string if they are equal to the deletion substring
// as long as the last characters are not equal to the deletion substring.   
//
// Parameters:
//  IncomingString    - String - a string to be processed.
//  DeletionSubstring - String - a substring to be deleted from the string end.
//  Separator       - String - if the separator is specified, deletion is performed only 
//                        if the deletion substring is located entirely after the separator.
//
// Returns:
//   String  - 
//
Function DeleteLastCharsFromString(IncomingString, DeletionSubstring, Separator = Undefined) Export

	While Right(IncomingString, StrLen(DeletionSubstring)) = DeletionSubstring Do

		If Separator <> Undefined Then
			If Mid(IncomingString, StrLen(IncomingString) - StrLen(DeletionSubstring) - StrLen(Separator),
				StrLen(Separator)) = Separator Then
				Return IncomingString;
			EndIf;
		EndIf;
		IncomingString = Left(IncomingString, StrLen(IncomingString) - StrLen(DeletionSubstring));

	EndDo;

	Return IncomingString;

EndFunction

// Parameters:
//  Var_Key  - UUID - the key that will be used to generate the question name.
//
// Returns:
//  String
//
Function QuestionName(Val Var_Key) Export

	Return "DoQueryBox_" + StrReplace(Var_Key, "-", "_");

EndFunction

Procedure GenerateTreeNumbering(QuestionnaireTree, ConvertFormulation = False) Export

	If QuestionnaireTree.GetItems()[0].RowType = "Root" Then
		KeyTreeItems = QuestionnaireTree.GetItems()[0].GetItems();
	Else
		KeyTreeItems = QuestionnaireTree.GetItems();
	EndIf;

	GenerateTreeItemsNumbering(KeyTreeItems, 1, New Array, ConvertFormulation);

EndProcedure 

Procedure GenerateTreeItemsNumbering(TreeRows, RecursionLevel, ArrayFullCode,
	ConvertFormulation)

	If ArrayFullCode.Count() < RecursionLevel Then
		ArrayFullCode.Add(0);
	EndIf;

	For Each Item In TreeRows Do

		If Item.RowType = "Introduction" Or Item.RowType = "ClosingStatement" Then
			Continue;
		EndIf;

		ArrayFullCode[RecursionLevel - 1] = ArrayFullCode[RecursionLevel - 1] + 1;
		For Indus = RecursionLevel To ArrayFullCode.Count() - 1 Do
			ArrayFullCode[Indus] = 0;
		EndDo;

		FullCode = StrConcat(ArrayFullCode, ".");
		FullCode = DeleteLastCharsFromString(FullCode, ".0.", ".");

		Item.FullCode = FullCode;
		If ConvertFormulation Then
			Item.Wording = Item.FullCode + ". " + Item.Wording;
		EndIf;

		SubordinateTreeRowItems = Item.GetItems();
		If SubordinateTreeRowItems.Count() > 0 Then
			GenerateTreeItemsNumbering(SubordinateTreeRowItems, ?(Item.RowType = "DoQueryBox",
				RecursionLevel, RecursionLevel + 1), ArrayFullCode, ConvertFormulation);
		EndIf;

	EndDo;

EndProcedure

Function FindStringInFormDataTree(WhereToFind, Value, Column, SearchSubordinateItems) Export

	TreeItems = WhereToFind.GetItems();

	For Each TreeItem In TreeItems Do
		If TreeItem[Column] = Value Then
			Return TreeItem.GetID();
		ElsIf SearchSubordinateItems Then
			FoundRowID1 =  FindStringInFormDataTree(TreeItem, Value, Column,
				SearchSubordinateItems);
			If FoundRowID1 >= 0 Then
				Return FoundRowID1;
			EndIf;
		EndIf;

	EndDo;

	Return -1;

EndFunction

// Parameters:
//  IsSection  - Boolean - a section flag.
//  QuestionType - EnumRef.QuestionnaireTemplateQuestionTypes
//
// Returns:
//   Number
//
Function GetQuestionnaireTemplatePictureCode(IsSection, QuestionType = Undefined) Export

	If IsSection Then
		Return 1;
	ElsIf QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Basic") Then
		Return 2;
	ElsIf QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.QuestionWithCondition") Then
		Return 4;
	ElsIf QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Tabular") Then
		Return 3;
	ElsIf QuestionType = PredefinedValue("Enum.QuestionnaireTemplateQuestionTypes.Complex") Then
		Return 5;
	Else
		Return 0;
	EndIf;

EndFunction

// Parameters:
//   Form - ClientApplicationForm
//   QuestionnaireBodyVisibility - Boolean
//
Procedure SwitchQuestionnaireBodyGroupsVisibility(Form, QuestionnaireBodyVisibility) Export

	Form.Items.QuestionnaireBodyGroup.Visible = QuestionnaireBodyVisibility;
	Form.Items.WaitGroup.Visible   = Not QuestionnaireBodyVisibility;

	FooterPreviousSection = Form.Items.FooterPreviousSection; // FormField
	FooterPreviousSection.Enabled = QuestionnaireBodyVisibility;

	PreviousSection = Form.Items.PreviousSection; // FormField
	PreviousSection.Enabled = QuestionnaireBodyVisibility;

	FooterNextSection = Form.Items.FooterNextSection; // FormField
	FooterNextSection.Enabled = QuestionnaireBodyVisibility;

	NextSection = Form.Items.NextSection; // FormField
	NextSection.Enabled = QuestionnaireBodyVisibility;

EndProcedure

#EndRegion