///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure;
	FormParameters.Insert("PropertyKind",
		PredefinedValue("Enum.PropertiesKinds.Labels"));
	OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		"Labels",
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
EndProcedure

#EndRegion