///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Starts data exchange and is used in the background job.
//
// Parameters:
//   JobParameters - Structure - parameters required to execute the procedure.
//   StorageAddress   - String - address of the temporary storage.
//
Procedure StartDataExchangeExecution(JobParameters, StorageAddress) Export
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	
	FillPropertyValues(ExchangeParameters, JobParameters,
		"ExchangeMessagesTransportKind,ExecuteImport1,ExecuteExport2");
		
	If JobParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		ExchangeParameters.TimeConsumingOperation          = JobParameters.TimeConsumingOperation;
		ExchangeParameters.TimeConsumingOperationAllowed = True;
		ExchangeParameters.OperationID       = JobParameters.TimeConsumingOperationID;
		ExchangeParameters.FileID          = JobParameters.MessageFileIDInService;
		ExchangeParameters.AuthenticationParameters     = JobParameters.AuthenticationParameters;
		ExchangeParameters.TheTimeoutOnTheServer   = 15;
		
	EndIf;
	
	DataExchangeServer.CheckWhetherTheExchangeCanBeStarted(JobParameters.InfobaseNode, JobParameters.Cancel);
	
	If Not JobParameters.Cancel Then
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
			JobParameters.InfobaseNode,
			ExchangeParameters,
			JobParameters.Cancel);
			
		If JobParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
			
			JobParameters.TimeConsumingOperation                  = ExchangeParameters.TimeConsumingOperation;
			JobParameters.TimeConsumingOperationID     = ExchangeParameters.OperationID;
			JobParameters.AuthenticationParameters             = ExchangeParameters.AuthenticationParameters;
			
			If ValueIsFilled(JobParameters.TimeConsumingOperationID) Then
				// 
				JobParameters.MessageFileIDInService = ExchangeParameters.FileID;
			Else
				// 
				JobParameters.MessageFileIDInService = "";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	PutToTempStorage(JobParameters, StorageAddress);
	
EndProcedure

// Starts importing a file received from the Internet. It is used in a background job.
//
// Parameters:
//   JobParameters - Structure - parameters required to execute the procedure.
//   StorageAddress   - String - address of the temporary storage.
//
Procedure ImportFileDownloadedFromInternet(JobParameters, StorageAddress) Export
	
	DataExchangeWebService.ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
		JobParameters.Cancel,
		JobParameters.InfobaseNode,
		JobParameters.MessageFileIDInService,
		JobParameters.OperationStartDate,
		JobParameters.AuthenticationParameters);
		
	JobParameters.MessageFileIDInService = "";
	PutToTempStorage(JobParameters, StorageAddress);
	
EndProcedure

#EndRegion

#EndIf