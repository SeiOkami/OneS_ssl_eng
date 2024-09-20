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
	
	Items.List.MultipleChoice = Not ValueIsFilled(Parameters.Filter);
	
	If ValueIsFilled(Parameters.Filter) Then
		Filter = StrSplit(Parameters.Filter, "_", True)[0];
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr(
			"en = 'Select regional settings for the %1 language';"),
			NationalLanguageSupportServer.LanguagePresentation(Filter));
	EndIf;
	
	FillInTheListOfAvailableLanguages(Collapse);
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	Close(SelectedLanguages());
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	Close(SelectedLanguages());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillInTheListOfAvailableLanguages(GroupBy = True)
	
	List.Clear();
	
	Filter = StrSplit(Parameters.Filter, "_", True)[0];
	
	For Each Language In GetAvailableLocaleCodes() Do
		If ValueIsFilled(Filter) And Not StrStartsWith(Language, Filter) Then
			Continue;
		EndIf;
		
		Presentation = LocaleCodePresentation(Language);
		StringParts1 = StrSplit(Presentation, " ", True);
		StringParts1[0] = Title(StringParts1[0]);
		Presentation = StrConcat(StringParts1, " ");
		
		If StrFind(Language, "_") And GroupBy Then
			LanguageDetails = List.FindRows(New Structure("Code", StrSplit(Language, "_", True)[0]))[0];
			Presentation = Mid(Presentation, StrLen(LanguageDetails.Description) + 1);
			
			Countries = StrSplit(LanguageDetails.Countries, ",", False);
			
			StartPosition = StrFind(Presentation, "(");
			If StartPosition > 0 Then
				EndPosition1 = StrFind(Presentation, ")", SearchDirection.FromEnd);
				If EndPosition1 > 0 Then
					ListOfCountriesByLine = Mid(Presentation, StartPosition + 1, EndPosition1 - StartPosition - 1);
					LanguageCountries = StrSplit(ListOfCountriesByLine, ",", False);
					For Each Country In LanguageCountries Do
						Country = TrimAll(Country);
						If Countries.Find(Country) = Undefined Then
							Countries.Add(Country);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
			
			LanguageDetails.Countries = StrConcat(Countries, ",");
			LanguageDetails.SearchString = SearchString(LanguageDetails.Description) + " " + LanguageDetails.Code + " " + SearchString(LanguageDetails.Countries);
		Else
			LanguageDetails = List.Add();
			LanguageDetails.Code = Language;
			LanguageDetails.Description = Presentation;
			LanguageDetails.SearchString = SearchString(LanguageDetails.Description) + " " + LanguageDetails.Code;
		EndIf;
		
	EndDo;
	
	For Each LanguageDetails In List Do
		LanguageDetails.Countries = StrReplace(LanguageDetails.Countries, ",", ", ");
	EndDo;
	
	List.Sort("SearchString");
	
EndProcedure

&AtServer
Function SearchString(String)
	Return StrConcat(StrSplit(String, "(), ", False), " ");
EndFunction

&AtClient
Function SelectedLanguages()
	
	Result = New Array;
	For Each SelectedRow In Items.List.SelectedRows Do
		TheSelectedLanguage = List.FindByID(SelectedRow);
		Result.Add(New Structure("Code,Description", TheSelectedLanguage.Code, TheSelectedLanguage.Description));
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
