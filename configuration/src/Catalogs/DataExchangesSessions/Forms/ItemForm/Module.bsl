///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region FormCommandHandlers

&AtClient
Procedure PerformanceMeasurements(Command)
	
	FileAddress = GetFileAddressOnServer();
	Title = NStr("en = 'Save file';");
		
	FileName = NStr("en = 'Samples.zip';", CommonClient.DefaultLanguageCode());
		
	DialogParameters = New GetFilesDialogParameters(Title, True);
	BeginGetFileFromServer(FileAddress, FileName, DialogParameters);

EndProcedure

&AtServer
Function GetFileAddressOnServer()
	
	BinaryData = FormAttributeToValue("Object").PerformanceMeasurements.Get();	
	Address = PutToTempStorage(BinaryData);
	
	Return Address;
	
EndFunction

#EndRegion
