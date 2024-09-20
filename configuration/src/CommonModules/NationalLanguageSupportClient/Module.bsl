///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Input field OnOpen event handler of the form to open the attribute value input form in different languages.
//
// Parameters:
//  Form   - ClientApplicationForm - a form that contains multilanguage attributes.
//  Object  - FormDataStructure:
//   * Ref - AnyRef
//  Item - FormField - a form item for which the input form will be opened in different languages.
//  StandardProcessing - Boolean - indicates whether standard (system) event processing is executed.
//
Procedure OnOpen(Form, Object, Item, StandardProcessing) Export
	
	StandardProcessing = False;
	DataPath = Form.MultilanguageAttributesParameters[Item.Name];
	
	PointPosition = StrFind(DataPath, ".");
	AttributeName = ?(PointPosition > 0, Mid(DataPath, PointPosition + 1), DataPath);
	
	FormParameters = New Structure;
	FormParameters.Insert("Object",          Object);
	FormParameters.Insert("AttributeName",    AttributeName);
	FormParameters.Insert("ValueCurrent", Item.EditText);
	FormParameters.Insert("ReadOnly",  Item.ReadOnly);
	
	If Object.Property("Presentations") Then
		FormParameters.Insert("Presentations", Object.Presentations);
	Else
		Presentations = New Structure();
		
		Presentations.Insert(AttributeName, Object[AttributeName]);
		Presentations.Insert(AttributeName + "Language1", Object[AttributeName + "Language1"]);
		Presentations.Insert(AttributeName + "Language2", Object[AttributeName + "Language2"]);
		
		FormParameters.Insert("AttributesValues", Presentations);
		
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form",        Form);
	AdditionalParameters.Insert("Object",       Object);
	AdditionalParameters.Insert("AttributeName", AttributeName);
	
	Notification = New NotifyDescription("AfterInputStringsInDifferentLanguages", NationalLanguageSupportClient, AdditionalParameters);
	OpenForm("CommonForm.InputInMultipleLanguages", FormParameters,,,,, Notification);
	
EndProcedure

#EndRegion

#Region Internal

Procedure OpenTheRegionalSettingsForm(NotifyDescription = Undefined, Parameters = Undefined) Export
	
	OpenForm("CommonForm.RegionalSettings", Parameters, , , , , NotifyDescription);
	
EndProcedure

#EndRegion


#Region Private

Procedure AfterInputStringsInDifferentLanguages(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	If Result.Modified Then
		AdditionalParameters.Form.Modified = True;
	EndIf;
	
	Object = AdditionalParameters.Object;
	If Result.StorageInTabularSection Then
		
		For Each Presentation In Result.ValuesInDifferentLanguages Do
			Filter = New Structure("LanguageCode", Presentation.LanguageCode);
			FoundRows = Object.Presentations.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				If IsBlankString(Presentation.AttributeValue) 
					And StrCompare(Result.DefaultLanguage, Presentation.LanguageCode) <> 0 Then
						Object.Presentations.Delete(FoundRows[0]);
					Continue;
				EndIf;
				PresentationsRow = FoundRows[0];
			Else
				PresentationsRow = Object.Presentations.Add();
				PresentationsRow.LanguageCode = Presentation.LanguageCode;
			EndIf;
			PresentationsRow[AdditionalParameters.AttributeName] = Presentation.AttributeValue;
			
		EndDo;
		
	EndIf;
	
	For Each Presentation In Result.ValuesInDifferentLanguages Do
		If ValueIsFilled(Presentation.Suffix) Then
			PropsNameInAnotherLanguage = AdditionalParameters.AttributeName + Presentation.Suffix;
			If Object.Property(PropsNameInAnotherLanguage) Then
				Object[PropsNameInAnotherLanguage]= Presentation.AttributeValue;
			EndIf;
		EndIf;
	EndDo;
		
	If Result.Property("StringInCurrentLanguage") Then
		Object[AdditionalParameters.AttributeName] = Result.StringInCurrentLanguage;
	EndIf;
	
	Notify("AfterInputStringsInDifferentLanguages", AdditionalParameters.Form);
	
EndProcedure

#EndRegion
