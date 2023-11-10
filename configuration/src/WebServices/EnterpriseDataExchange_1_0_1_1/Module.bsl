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

Function ConnectionCheckUp(ExchangePlanName, ExchangePlanNodeCode, ErrorMessage)
	
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
	
	SetPrivilegedMode(True);
	
	// Checking whether the exchange plan node exists (it might be deleted).
	If ExchangePlans[ExchangePlanName].FindByCode(ExchangePlanNodeCode).IsEmpty() Then
		
		ErrorMessage = NStr("en = 'Presetting not found. Please contact with application administrator.';", Common.DefaultLanguageCode());
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

// ConfirmGettingFile
//
Function ConfirmDataExported(FileID, ConfirmFileReceipt, ErrorMessage)
	
	ErrorMessage = "";
	
	Try
		DeleteFiles(DataExchangeInternal.TemporaryExportDirectory(FileID));
	Except
		
		ErrorMessage = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
	EndTry;
		
	Return "";	
		
EndFunction

Function GetDataImportResult(BackgroundJobIdentifier, ErrorMessage)
	
	Return DataExchangeInternal.GetDataReceiptExecutionStatus(BackgroundJobIdentifier, ErrorMessage);
	
EndFunction

Function GetPrepareDataToExportResult(BackgroundJobIdentifier, ErrorMessage)
	
	Return DataExchangeInternal.GetExecutionStatusOfDataPreparationForSending(BackgroundJobIdentifier, ErrorMessage);
	
EndFunction

// PutFilePart
//
Function ImportFilePart(FileID, FilePartToImportNumber, FilePartToImport, ErrorMessage)
	
	Return DataExchangeInternal.ImportFilePart(FileID, FilePartToImportNumber, FilePartToImport, ErrorMessage);
	
EndFunction

Function ExportFilePart(FileID, FilePartToExportNumber, ErrorMessage)
	
	Return DataExchangeInternal.ExportFilePart(FileID, FilePartToExportNumber, ErrorMessage);
	
EndFunction

// PutData
//
Function ImportDataToInfobase(ExchangePlanName, ExchangePlanNodeCode, FileID, BackgroundJobIdentifier, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.ExchangePlanName                         = ExchangePlanName;
	ParametersStructure.ExchangePlanNodeCode                     = ExchangePlanNodeCode;
	ParametersStructure.TempStorageFileID = DataExchangeInternal.PrepareFileForImport(FileID, ErrorMessage);
	ParametersStructure.NameOfTheWEBService                          = "EnterpriseDataExchange_1_0_1_1";
	
	// Importing data to the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Import data in the infobase using the ""Enterprise Data Exchange"" web service';");
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

// PrepareDataForGetting
//
Function PrepareDataToImport(ExchangePlanName, ExchangePlanNodeCode, FilePartSize, BackgroundJobIdentifier, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.ExchangePlanName                         = ExchangePlanName;
	ParametersStructure.ExchangePlanNodeCode                     = ExchangePlanNodeCode;
	ParametersStructure.FilePartSize                       = FilePartSize;
	ParametersStructure.TempStorageFileID = New UUID();
	ParametersStructure.NameOfTheWEBService                          = "EnterpriseDataExchange_1_0_1_1";
	
	// Preparing data to export from the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Prepare for data export from infobase via ""Enterprise Data Exchange"" web service';");
	ExecutionParameters.BackgroundJobKey = String(New UUID);
	
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.RunInBackground    = True;

	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeInternal.PrepareDataForExportFromInfobase",
		ProcedureParameters,
		ExecutionParameters);
	BackgroundJobIdentifier = String(BackgroundJob.JobID);
	
	Return "";
	
EndFunction

#EndRegion