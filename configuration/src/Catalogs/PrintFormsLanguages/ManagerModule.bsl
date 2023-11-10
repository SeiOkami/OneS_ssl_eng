///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure FillInTheSuppliedLanguages() Export
	
	LanguagesCodes = New Array;
	LanguagesCodes.Add(Common.DefaultLanguageCode());
	
	AddLanguages(LanguagesCodes);
	
EndProcedure

#EndRegion

#Region Private

Procedure AddLanguages(LanguagesCodes) Export
	
	For Each LanguageCode In LanguagesCodes Do
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.PrintFormsLanguages");
			LockItem.SetValue("Code", LanguageCode);
			Block.Lock();
			
			If Not ValueIsFilled(Catalogs.PrintFormsLanguages.FindByCode(LanguageCode)) Then
				Language = Catalogs.PrintFormsLanguages.CreateItem();
				Language.Code = LanguageCode;
				InfobaseUpdate.WriteData(Language);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	
	EndDo;
	
EndProcedure

Function AvailableLanguages(WithRegionalSettings = False, OnlyTheAdditional = False) Export
	
	QueryText =
	"SELECT
	|	PrintFormsLanguages.Code AS Code
	|FROM
	|	Catalog.PrintFormsLanguages AS PrintFormsLanguages
	|WHERE
	|	NOT PrintFormsLanguages.DeletionMark
	|	AND NOT PrintFormsLanguages.Code IN (&ExceptionsList)
	|
	|ORDER BY
	|	PrintFormsLanguages.AddlOrderingAttribute,
	|	PrintFormsLanguages.Ref";
	
	Query = New Query(QueryText);
	Query.SetParameter("ExceptionsList", ?(OnlyTheAdditional,
		StandardSubsystemsServer.ConfigurationLanguages(), New Array));
	
	Languages = Query.Execute().Unload();
	
	If Not WithRegionalSettings Then
		For Each Language In Languages Do
			Language.Code = StrSplit(Language.Code, "_", True)[0];
		EndDo;
		Languages.GroupBy("Code");
	EndIf;
	
	Return Languages.UnloadColumn("Code");
	
EndFunction

Function AdditionalLanguagesOfPrintedForms() Export
	
	Return AvailableLanguages(False, True);
	
EndFunction

Function ItIsAnAdditionalLanguageOfPrintedForms(LanguageCode) Export
	
	If Not ValueIsFilled(LanguageCode) Then
		Return False;
	EndIf;
	
	Return StandardSubsystemsServer.ConfigurationLanguages().Find(LanguageCode) = Undefined;
	
EndFunction

#EndRegion

#EndIf