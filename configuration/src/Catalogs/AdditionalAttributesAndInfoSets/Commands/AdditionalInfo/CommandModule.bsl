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
	FormParameters = New Structure;
	FormParameters.Insert("PropertyKind",
		PredefinedValue("Enum.PropertiesKinds.AdditionalInfo"));
	OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		"AdditionalInfo",
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
EndProcedure

#EndRegion