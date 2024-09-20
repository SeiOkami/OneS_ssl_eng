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
	If FilesOperationsClient.ScanAvailable() Then
		AddingFromScannerParameters = FilesOperationsClient.AddingFromScannerParameters();
		AddingFromScannerParameters.OwnerForm = ThisObject;
		AddingFromScannerParameters.ResultHandler = New NotifyDescription("ScanSheetCompletion", ThisObject);
		AddingFromScannerParameters.ResultType = FilesOperationsClient.ConversionResultTypeFileName();
		AddingFromScannerParameters.OneFileOnly = True; 
		FilesOperationsClient.AddFromScanner(AddingFromScannerParameters);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ScanSheetCompletion(Result, Context) Export
	If Result <> Undefined Then 
		FileSystemClient.OpenFile(Result.FileName);
	EndIf;	
EndProcedure

#EndRegion