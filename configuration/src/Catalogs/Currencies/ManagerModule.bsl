///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("RateSource");
	Result.Add("Markup");
	Result.Add("MainCurrency");
	Result.Add("RateCalculationFormula");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region Private

Function CurrencyCodes() Export
	
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS AlphabeticCode,
	|	Currencies.DescriptionFull AS Presentation
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource <> VALUE(Enum.RateSources.MarkupForOtherCurrencyRate)
	|	AND Currencies.RateSource <> VALUE(Enum.RateSources.CalculationByFormula)";
	
	Query = New Query(QueryText);
	Return Common.ValueTableToArray(Query.Execute().Unload());
	
EndFunction

#EndRegion

#EndIf