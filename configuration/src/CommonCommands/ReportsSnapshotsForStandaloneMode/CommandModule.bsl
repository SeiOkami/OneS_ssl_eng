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

#If MobileClient Then
	OpenForm("InformationRegister.ReportsSnapshots.Form.ReportViewForm");
#Else
	CommonClient.MessageToUser(NStr(
			"en = 'This command is used in the mobile client.';"));
#EndIf

EndProcedure

#EndRegion