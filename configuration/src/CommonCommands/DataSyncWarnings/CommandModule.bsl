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
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ArrayOfExchangePlanNodes", New Array);
	OpeningParameters.Insert("SelectionByDateOfOccurrence", Date(1,1,1));
	OpeningParameters.Insert("SelectionOfExchangeNodes", New Array);
	OpeningParameters.Insert("SelectingTypesOfWarnings", New Array); 
	OpeningParameters.Insert("OnlyHiddenRecords", True);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.SynchronizationWarnings", OpeningParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
