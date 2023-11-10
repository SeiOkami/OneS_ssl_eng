///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Determines if classifier data update is necessary.
//
Function ClassifierUpToDate() Export
	
	DataProcessorName = "ImportBankClassifier";
	If Metadata.DataProcessors.Find(DataProcessorName) <> Undefined Then
		Return DataProcessors[DataProcessorName].ClassifierUpToDate();
	EndIf;
	
	Return True;
	
EndFunction

Function ClassifierEmpty()
	
	QueryText =
	"SELECT TOP 1
	|	BankClassifier.Ref AS Ref
	|FROM
	|	Catalog.BankClassifier AS BankClassifier";
	
	Query = New Query(QueryText);
	Return Query.Execute().IsEmpty();
	
EndFunction

Function PromptToImportClassifier() Export
	
	Return Not Common.DataSeparationEnabled() And ClassifierEmpty();
	
EndFunction

#EndRegion
