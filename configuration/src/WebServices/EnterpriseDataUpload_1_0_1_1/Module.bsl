///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private
////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers.

Function Ping()
	Return "";
EndFunction

Function ConnectionCheckUp(ErrorMessage)
	
	ErrorMessage = "";
	
	// Checking whether a user has rights to perform the data exchange.
	Try
		DataExchangeInternal.CheckCanSynchronizeData();
	Except
		ErrorMessage = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Checking whether the infobase is locked for update.
	Try
		DataExchangeInternal.CheckInfobaseLockForUpdate();
	Except
		ErrorMessage = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function GetDataImportResult(BackgroundJobIdentifier, ErrorMessage)
	
	Return DataExchangeInternal.GetDataReceiptExecutionStatus(BackgroundJobIdentifier, ErrorMessage);
	
EndFunction

// PutFilePart
//
Function ImportFilePart(FileID, FilePartToImportNumber, FilePartToImport, ErrorMessage)
	
	Return DataExchangeInternal.ImportFilePart(FileID, FilePartToImportNumber, FilePartToImport, ErrorMessage);
	
EndFunction

// PutData
//
Function ImportDataToInfobase(FileID, BackgroundJobIdentifier, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.TempStorageFileID = DataExchangeInternal.PrepareFileForImport(FileID, ErrorMessage);
	ParametersStructure.NameOfTheWEBService                          = "EnterpriseDataUpload_1_0_1_1";
	
	// Importing to the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Import data to the infobase using the ""Enterprise Data Upload"" web service';");
	ExecutionParameters.BackgroundJobKey = String(New UUID);
	
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.RunInBackground    = True;

	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeInternal.ImportXDTODateToInfobase",
		ProcedureParameters,
		ExecutionParameters);
	BackgroundJobIdentifier = String(BackgroundJob.JobID);
	
	Return "";
	
EndFunction

#EndRegion