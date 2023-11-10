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
	
	ExchangePlanName     = Parameters.ExchangePlanName;
	ExchangePlanSynonym = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	
	ObjectsConversionRules = Enums.DataExchangeRulesTypes.ObjectsConversionRules;
	ObjectsRegistrationRules = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	
	WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Error,,,
		Parameters.DetailErrorDescription);
		
	Items.ErrorMessageText.Title = StringFunctions.FormattedString(
		StringFunctionsClientServer.SubstituteParametersToString(Items.ErrorMessageText.Title,
			ExchangePlanSynonym,
			Parameters.BriefErrorDescription));
	
	RulesFromFile = InformationRegisters.DataExchangeRules.RulesFromFileUsed(ExchangePlanName, True);
	
	If RulesFromFile.ConversionRules And RulesFromFile.RecordRules Then
		RulesType = NStr("en = 'conversions and registrations';");
	ElsIf RulesFromFile.ConversionRules Then
		RulesType = NStr("en = 'conversions';");
	ElsIf RulesFromFile.RecordRules Then
		RulesType = NStr("en = 'registrations';");
	EndIf;
	
	Items.RulesTextFromFile.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.RulesTextFromFile.Title, ExchangePlanSynonym, RulesType);
	
	UpdateStartTime = Parameters.UpdateStartTime;
	If Parameters.UpdateEndTime = Undefined Then
		UpdateEndTime = CurrentSessionDate();
	Else
		UpdateEndTime = Parameters.UpdateEndTime;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExitApplication(Command)
	Close(True);
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", UpdateStartTime);
	FormParameters.Insert("EndDate", UpdateEndTime);
	FormParameters.Insert("ShouldNotRunInBackground", True);
	EventLogClient.OpenEventLog(FormParameters);
	
EndProcedure

&AtClient
Procedure Restart(Command)
	Close(False);
EndProcedure

&AtClient
Procedure ImportRulesSet(Command)
	
	DataExchangeClient.ImportDataSyncRules(ExchangePlanName);
	
EndProcedure

#EndRegion