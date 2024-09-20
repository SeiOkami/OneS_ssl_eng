///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Server call.
	ExchangePlanName = ExchangePlanName(CommandParameter);
	
	// Server call.
	RulesKind = PredefinedValue("Enum.DataExchangeRulesTypes.ObjectsConversionRules");
	
	Filter              = New Structure("ExchangePlanName, RulesKind", ExchangePlanName, RulesKind);
	FillingValues = New Structure("ExchangePlanName, RulesKind", ExchangePlanName, RulesKind);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", CommandExecuteParameters.Source, "ObjectsConversionRules");
	
EndProcedure

&AtServer
Function ExchangePlanName(Val InfobaseNode)
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
EndFunction

#EndRegion
