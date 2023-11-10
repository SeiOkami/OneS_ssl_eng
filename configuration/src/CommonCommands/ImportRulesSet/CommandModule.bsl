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
	
	ExchangePlanInfo = ExchangePlanInfo(CommandParameter);
	
	If ExchangePlanInfo.SeparatedMode Then
		CommonClient.MessageToUser(
			NStr("en = 'Cannot load data exchange rules in shared mode.';"));
		Return;
	EndIf;
	
	If ExchangePlanInfo.ConversionRulesAreUsed Then
		DataExchangeClient.ImportDataSyncRules(ExchangePlanInfo.ExchangePlanName);
	Else
		Filter              = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, ExchangePlanInfo.ORRRulesKind);
		FillingValues = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, ExchangePlanInfo.ORRRulesKind);
		
		DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", 
			CommandParameter, "ObjectsRegistrationRules");
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ExchangePlanInfo(Val InfobaseNode)
	
	Result = New Structure("SeparatedMode",
		Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable());
		
	If Not Result.SeparatedMode Then
		Result.Insert("ExchangePlanName",
			DataExchangeCached.GetExchangePlanName(InfobaseNode));
			
		Result.Insert("ConversionRulesAreUsed",
			DataExchangeCached.HasExchangePlanTemplate(Result.ExchangePlanName, "ExchangeRules"));
			
		Result.Insert("ORRRulesKind", Enums.DataExchangeRulesTypes.ObjectsRegistrationRules);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion