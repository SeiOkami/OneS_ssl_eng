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

// Matches the Upload web service operation.
Function ExecuteExport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
	Return "";
	
EndFunction

// Matches the Download web service operation.
Function ExecuteImport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage.Get());
	
	Return "";
	
EndFunction

// Matches the UploadData web service operation.
Function RunDataExport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID;
	FileIDAsString = String(FileID);
	RunExportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);
	
	Return "";
	
EndFunction

// Matches the DownloadData web service operation.
Function RunDataImport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID(FileIDAsString);
	RunImportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);
	
	Return "";
	
EndFunction

// Matches the GetIBParameters web service operation.
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage)
	
	Result = DataExchangeServer.InfoBaseAdmParams(ExchangePlanName, NodeCode, ErrorMessage);
	Return XDTOSerializer.WriteXDTO(Result);
	
EndFunction

// Matches the CreateExchangeNode web service operation.
Function CreateDataExchangeNode(XDTOParameters)
	
	DataExchangeServer.CheckDataExchangeUsage(True);
	
	Parameters = XDTOSerializer.ReadXDTO(XDTOParameters);
	
	ConnectionSettings = Parameters.ConnectionSettings;
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Try
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(
			ConnectionSettings, Parameters.XMLParametersString, , True);
			
		ConnectionSettings.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
			
		ModuleSetupWizard.ConfigureDataExchange(
			ConnectionSettings);
	Except
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessage);
			
		Raise ErrorMessage;
	EndTry;
	
	Return "";
	
EndFunction

// Matches the RemoveExchangeNode web service operation.
Function DeleteDataExchangeNode(ExchangePlanName, NodeID)
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Exchange plan node ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, ExchangePlanName, NodeID);
	EndIf;
	
	DataExchangeServer.DeleteSynchronizationSetting(ExchangeNode);
	
	Return "";
	
EndFunction

// Matches the GetContinuousOperationStatus web service operation.
Function GetTimeConsumingOperationState(OperationID, ErrorMessageString)
	
	BackgroundJobStates = New Map;
	BackgroundJobStates.Insert(BackgroundJobState.Active,           "Active");
	BackgroundJobStates.Insert(BackgroundJobState.Completed,         "Completed");
	BackgroundJobStates.Insert(BackgroundJobState.Failed, "Failed");
	BackgroundJobStates.Insert(BackgroundJobState.Canceled,          "Canceled");
	
	SetPrivilegedMode(True);
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(OperationID));
	
	If BackgroundJob = Undefined Then
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No long-running operation with ID %1 was found.';"),
			OperationID);
		Return BackgroundJobStates.Get(BackgroundJobState.Canceled);
	EndIf;
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = ErrorProcessing.DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	Return BackgroundJobStates.Get(BackgroundJob.State);
EndFunction

// Matches the PrepareGetFile web service operation.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName1 = DataExchangeServer.GetFileFromStorage(FileId);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	SourceFileNameInTemporaryDirectory = CommonClientServer.GetFullFileName(TempDirectory, "data.zip");
	
	CreateDirectory(TempDirectory);
	
	MoveFile(SourceFileName1, SourceFileNameInTemporaryDirectory);
	
	If BlockSize <> 0 Then
		// Splitting a file into parts
		FilesNames = SplitFile(SourceFileNameInTemporaryDirectory, BlockSize * 1024);
		PartQuantity = FilesNames.Count();
		
		DeleteFiles(SourceFileNameInTemporaryDirectory);
	Else
		PartQuantity = 1;
		MoveFile(SourceFileNameInTemporaryDirectory, SourceFileNameInTemporaryDirectory + ".1");
	EndIf;
	
	Return "";
	
EndFunction

// Matches the GetFilePart web service operation.
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FilesNames = FindPartFile(TemporaryExportDirectory(TransferId), PartNumber);
	
	If FilesNames.Count() = 0 Then
		
		MessageTemplate = NStr("en = 'Part %1 of the transfer session with ID %2 is not found';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FilesNames.Count() > 1 Then
		
		MessageTemplate = NStr("en = 'Multiple parts %1 of the transfer session with ID %2 are not found';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	PartFileName = FilesNames[0].FullName;
	PartData = New BinaryData(PartFileName);
	
	Return "";
	
EndFunction

// Matches the ReleaseFile web service operation.
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return "";
	
EndFunction

// Matches the PutFilePart web service operation.
//
// Parameters:
//   TransferId - UUID - data transfer session UUID.
//   PartNumber - Number - the file part number.
//   PartData - BinaryData - the file part details.
//
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TempDirectory);
		
	EndIf;
	
	FileName = CommonClientServer.GetFullFileName(TempDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
	Return "";
	
EndFunction

// Matches the SaveFileFromParts web service operation.
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	PartsFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonClientServer.GetFullFileName(TempDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessageTemplate = NStr("en = 'Part %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
			Raise(MessageText);
		EndIf;
		
		PartsFilesToMerge.Add(FileName);
		
	EndDo;
	
	ArchiveName = CommonClientServer.GetFullFileName(TempDirectory, "data.zip");
	
	MergeFiles(PartsFilesToMerge, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(TempDirectory);
		Except
			WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
				EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("en = 'The archive file is empty.';"));
	EndIf;
	
	DumpDirectory = DataExchangeServer.TempFilesStorageDirectory();
	
	ArchiveItem = Dearchiver.Items.Get(0);
	FileName = CommonClientServer.GetFullFileName(DumpDirectory, ArchiveItem.Name);
	
	Dearchiver.Extract(ArchiveItem, DumpDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileInStorage(FileName);
	
	Try
		DeleteFiles(TempDirectory);
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return "";
	
EndFunction

// Matches the PutMessageForDataMatching web service operation.
Function PutMessageForDataMatching(ExchangePlanName, NodeID, FileID)
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Exchange plan node ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, ExchangePlanName, NodeID);
	EndIf;
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	DataExchangeInternal.PutMessageForDataMapping(ExchangeNode, FileID);
	
	//  
	// 
	// 
	// 
	MoveTheMessageFileForTheFileIB(FileID);
	
	Return "";
	
EndFunction

// Matches the Ping web service operation.
Function Ping()
	// 
	Return "";
EndFunction

// Matches the TestConnection web service operation.
Function TestConnection(ExchangePlanName, NodeCode, Result)
	
	// Checking whether a user has rights to perform the data exchange.
	Try
		DataExchangeServer.CheckCanSynchronizeData(True);
	Except
		Result = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Checking whether the infobase is locked for update.
	Try
		CheckInfobaseLockForUpdate();
	Except
		Result = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	SetPrivilegedMode(True);
	
	// Checking whether the exchange plan node exists (it might be deleted).
	NodeRef1 = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode);
	If NodeRef1 = Undefined
		Or Common.ObjectAttributeValue(NodeRef1, "DeletionMark") Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		ExchangePlanPresentation1 = Metadata.ExchangePlans[ExchangePlanName].Presentation();
			
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data synchronization setting ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, ExchangePlanPresentation1, NodeCode);
		
		Return False;
	EndIf;
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Procedure CheckInfobaseLockForUpdate()
	
	If ValueIsFilled(InfobaseUpdateInternal.InfobaseLockedForUpdate()) Then
		
		Raise NStr("en = 'Data synchronization is temporarily unavailable due to online application update.';");
		
	EndIf;
	
EndProcedure

Procedure RunExportDataInClientServerMode(ExchangePlanName,
														InfobaseNodeCode,
														FileID,
														TimeConsumingOperation,
														OperationID,
														TimeConsumingOperationAllowed)
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName,
		InfobaseNodeCode,
		NStr("en = 'Export';"));
	
	If HasActiveDataSynchronizationBackgroundJobs(BackgroundJobKey) Then
		Raise NStr("en = 'Data synchronization is already running.';");
	EndIf;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ExchangePlanName", ExchangePlanName);
	ProcedureParameters.Insert("InfobaseNodeCode", InfobaseNodeCode);
	ProcedureParameters.Insert("FileID", FileID);
	ProcedureParameters.Insert("UseCompression", True);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Export data via web service.';");
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	
	ExecutionParameters.RunNotInBackground1 = Not TimeConsumingOperationAllowed;
	ExecutionParameters.RunInBackground   = TimeConsumingOperationAllowed;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeWebService.ExportToFileTransferServiceForInfobaseNode",
		ProcedureParameters,
		ExecutionParameters);
		
	If BackgroundJob.Status = "Running" Then
		OperationID = String(BackgroundJob.JobID);
		TimeConsumingOperation = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed2" Then
		TimeConsumingOperation = False;
		Return;
	Else
		Message = NStr("en = 'Error exporting data via web service.';");
		If ValueIsFilled(BackgroundJob.DetailErrorDescription) Then
			Message = BackgroundJob.DetailErrorDescription;
		EndIf;
		
		WriteLogEvent(DataExchangeServer.ExportDataToFilesTransferServiceEventLogEvent(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
EndProcedure

Procedure RunImportDataInClientServerMode(ExchangePlanName,
													InfobaseNodeCode,
													FileID,
													TimeConsumingOperation,
													OperationID,
													TimeConsumingOperationAllowed)
	
													
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName,
		InfobaseNodeCode,
		NStr("en = 'Import';"));
	
	If HasActiveDataSynchronizationBackgroundJobs(BackgroundJobKey) Then
		Raise NStr("en = 'Data synchronization is already running.';");
	EndIf;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ExchangePlanName", ExchangePlanName);
	ProcedureParameters.Insert("InfobaseNodeCode", InfobaseNodeCode);
	ProcedureParameters.Insert("FileID", FileID);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Import data via web service.';");
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	
	ExecutionParameters.RunNotInBackground1 = Not TimeConsumingOperationAllowed;
	ExecutionParameters.RunInBackground   = TimeConsumingOperationAllowed;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeWebService.ImportFromFileTransferServiceForInfobaseNode",
		ProcedureParameters,
		ExecutionParameters);
		
	If BackgroundJob.Status = "Running" Then
		OperationID = String(BackgroundJob.JobID);
		TimeConsumingOperation = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed2" Then
		TimeConsumingOperation = False;
		Return;
	Else
		
		Message = NStr("en = 'Error importing data via web service.';");
		If ValueIsFilled(BackgroundJob.DetailErrorDescription) Then
			Message = BackgroundJob.DetailErrorDescription;
		EndIf;
		
		WriteLogEvent(DataExchangeServer.ImportDataFromFilesTransferServiceEventLogEvent(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
EndProcedure

Function ExportImportDataBackgroundJobKey(ExchangePlan, NodeCode, Action)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'ExchangePlan:%1 NodeCode:%2 Action:%3';"),
		ExchangePlan,
		NodeCode,
		Action);
	
EndFunction

Function HasActiveDataSynchronizationBackgroundJobs(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

Function GetPartFileName(PartNumber)
	
	Result = "data.zip.[n]";
	
	Return StrReplace(Result, "[n]", Format(PartNumber, "NG=0"));
EndFunction

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TempDirectory = "{SessionID}";
	TempDirectory = StrReplace(TempDirectory, "SessionID", String(SessionID));
	
	Result = CommonClientServer.GetFullFileName(DataExchangeServer.TempFilesStorageDirectory(), TempDirectory);
	
	Return Result;
EndFunction

Function FindPartFile(Val Directory, Val FileNumber)
	
	For DigitsCount = NumberDigitsCount(FileNumber) To 5 Do
		
		FormatString = StringFunctionsClientServer.SubstituteParametersToString("ND=%1; NLZ=; NG=0", String(DigitsCount));
		
		FileName = StringFunctionsClientServer.SubstituteParametersToString("data.zip.%1", Format(FileNumber, FormatString));
		
		FilesNames = FindFiles(Directory, FileName);
		
		If FilesNames.Count() > 0 Then
			
			Return FilesNames;
			
		EndIf;
		
	EndDo;
	
	Return New Array;
EndFunction

Function NumberDigitsCount(Val Number)
	
	Return StrLen(Format(Number, "NFD=0; NG=0"));
	
EndFunction

Procedure MoveTheMessageFileForTheFileIB(FileID)
	
	If Not Common.FileInfobase() Then
		Return;
	EndIf;
		
	QueryText =
		"SELECT
		|	DataExchangeMessages.MessageFileName AS FileName
		|FROM
		|	InformationRegister.DataExchangeMessages AS DataExchangeMessages
		|WHERE
		|	DataExchangeMessages.MessageID = &MessageID";

	Query = New Query;
	Query.SetParameter("MessageID", String(FileID));
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FileName = Selection.FileName;
	MessageFileName = CommonClientServer.GetFullFileName(DataExchangeServer.TempFilesStorageDirectory(), FileName);
	
	DirectoryName = DataExchangeServer.TheNameOfTheDirectoryToMapToTheFileInformationSystem();
	
	Directory = New File(DirectoryName);
	If Not Directory.Exists() Then
		CreateDirectory(DirectoryName);	
	EndIf;

	NameOfTheNewMessageFile = DataExchangeServer.TheFullNameOfTheFileToBeMappedIsFileInformationSystem(FileName);
	
	MoveFile(MessageFileName, NameOfTheNewMessageFile);	
	
EndProcedure
#EndRegion
