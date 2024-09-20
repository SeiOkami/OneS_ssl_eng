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
	
	If ValueIsFilled(Object.Code) Then
		Language = NationalLanguageSupportServer.LanguagePresentation(Object.Code);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure LanguageStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("WhenSelectingALanguage", ThisObject);
	OpeningParameters = New Structure("Filter", Object.Code);
	
	OpenForm("Catalog.PrintFormsLanguages.Form.PickLanguageFromAvailableLanguagesList",
		OpeningParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  SelectedLanguages - Array of Structure:
//   * Code - String
//   * Description - String
//
&AtClient
Procedure WhenSelectingALanguage(SelectedLanguages, AdditionalParameters) Export
	
	If Not ValueIsFilled(SelectedLanguages) Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, SelectedLanguages[0]);
	Language = SelectedLanguages[0].Description;
	Modified = True;
	
EndProcedure

#EndRegion
