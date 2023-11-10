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
	
	FormParameters = New Structure("", );
	OpenForm("Catalog.DataExchangesSessions.ListForm",
		FormParameters, CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
		
EndProcedure

#EndRegion
