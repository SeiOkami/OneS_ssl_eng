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
	
	Return DataExchangeServer.GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

// Matches the GetIBData web service operation.
Function GetInfobaseData(FullTableName)
	
	Result = New Structure("MetadataObjectProperties, CorrespondentInfobaseTable");
	
	Result.MetadataObjectProperties = ValueToStringInternal(DataExchangeServer.MetadataObjectProperties(FullTableName));
	Result.CorrespondentInfobaseTable = ValueToStringInternal(DataExchangeServer.GetTableObjects(FullTableName));
	
	Return ValueToStringInternal(Result);
	
EndFunction

// Matches the GetCommonNodsData web service operation.
Function GetCommonNodesData(ExchangePlanName)
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// Matches the CreateExchange web service operation.
Function CreateDataExchange(ExchangePlanName, ParametersString1, FilterSettingAsString, DefaultValuesAsString)
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	// Creating an instance of exchange setup wizard data processor.
	DataExchangeCreationWizard = DataExchangeServer.ModuleDataExchangeCreationWizard().Create();
	DataExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
	
	Cancel = False;
	
	// 
	DataExchangeCreationWizard.ImportWizardParameters(Cancel, ParametersString1);
	
	If Cancel Then
		Message = NStr("en = 'Errors occurred in the peer infobase during the data exchange setup: %1';");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DataExchangeCreationWizard.ErrorMessageString());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
	DataExchangeCreationWizard.WizardRunOption = "ContinueDataExchangeSetup";
	DataExchangeCreationWizard.IsDistributedInfobaseSetup = False;
	DataExchangeCreationWizard.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS;
	DataExchangeCreationWizard.SourceInfobasePrefixIsSet = ?(DataExchangeCreationWizard.UsePrefixesForExchangeSettings,
										ValueIsFilled(GetFunctionalOption("InfobasePrefix")),
										ValueIsFilled(DataExchangeCreationWizard.SourceInfobaseID));
	
	// 
	DataExchangeCreationWizard.SetUpNewDataExchangeWebService(
											Cancel,
											ValueFromStringInternal(FilterSettingAsString),
											ValueFromStringInternal(DefaultValuesAsString));
	
	If Cancel Then
		Message = NStr("en = 'Errors occurred in the peer infobase during the data exchange setup: %1';");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, DataExchangeCreationWizard.ErrorMessageString());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
	Return "";
	
EndFunction

// Matches the UpdateExchange web service operation.
Function UpdateDataExchangeSettings(ExchangePlanName, NodeCode, DefaultValuesAsString)
	
	DataExchangeServer.ExternalConnectionUpdateDataExchangeSettings(ExchangePlanName, NodeCode, DefaultValuesAsString);
	
	Return "";
	
EndFunction

// Matches the RegisterOnlyCatalogData web service operation.
Function RecordOnlyCatalogChanges(ExchangePlanName, NodeCode, TimeConsumingOperation, OperationID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, TimeConsumingOperation, OperationID, True);
	
	Return "";
	
EndFunction

// Matches the RegisterAllDataExceptCatalogs web service operation.
Function RecordAllDataChangesButCatalogChanges(ExchangePlanName, NodeCode, TimeConsumingOperation, OperationID)
	
	RegisterDataForInitialExport(ExchangePlanName, NodeCode, TimeConsumingOperation, OperationID, False);
	
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

// Matches the GetFunctionalOption web service operation.
Function GetFunctionalOptionValue(Name)
	
	Return GetFunctionalOption(Name);
	
EndFunction

// Matches the PrepareGetFile web service operation.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName1 = DataExchangeServer.GetFileFromStorage(FileId);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	File = New File(SourceFileName1);
	
	SourceFileNameInTemporaryDirectory = CommonClientServer.GetFullFileName(TempDirectory, File.Name);
	SharedFileName = CommonClientServer.GetFullFileName(TempDirectory, "data.zip");
	
	CreateDirectory(TempDirectory);
	
	MoveFile(SourceFileName1, SourceFileNameInTemporaryDirectory);
	
	Archiver = New ZipFileWriter(SharedFileName,,,, ZIPCompressionLevel.Maximum);
	Archiver.Add(SourceFileNameInTemporaryDirectory);
	Archiver.Write();
	
	If BlockSize <> 0 Then
		// Splitting a file into parts
		FilesNames = SplitFile(SharedFileName, BlockSize * 1024);
		PartQuantity = FilesNames.Count();
	Else
		PartQuantity = 1;
		MoveFile(SharedFileName, SharedFileName + ".1");
	EndIf;
	
	Return "";
	
EndFunction

// Matches the GetFilePart web service operation.
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileName = "data.zip.[n]";
	FileName = StrReplace(FileName, "[n]", Format(PartNumber, "NG=0"));
	
	FilesNames = FindFiles(TemporaryExportDirectory(TransferId), FileName);
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

// Matches the PutFileIntoStorage web service operation.
Function PutFileIntoStorage(FileName, FileId)
	
	SetPrivilegedMode(True);
	
	FileId = DataExchangeServer.PutFileInStorage(FileName);
	
	Return "";
	
EndFunction

// Matches the GetFileFromStorage web service operation.
Function GetFileFromStorage(FileId)
	
	SetPrivilegedMode(True);
	
	SourceFileName1 = DataExchangeServer.GetFileFromStorage(FileId);
	
	File = New File(SourceFileName1);
	
	Return File.Name;
	
EndFunction

// Matches the FileExists web service operation.
Function FileExists(FileName)
	
	SetPrivilegedMode(True);
	
	TempFileFullName = CommonClientServer.GetFullFileName(DataExchangeServer.TempFilesStorageDirectory(), FileName);
	
	File = New File(TempFileFullName);
	
	Return File.Exists();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Procedure CheckInfobaseLockForUpdate()
	
	IBLockedForUpdate = InfobaseUpdateInternal.InfobaseLockedForUpdate();
	If ValueIsFilled(IBLockedForUpdate) Then
		Raise IBLockedForUpdate;
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

Procedure RegisterDataForInitialExport(Val ExchangePlanName, Val NodeCode, TimeConsumingOperation, OperationID, CatalogsOnly)
	
	SetPrivilegedMode(True);
	
	InfobaseNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode);
	
	If Not ValueIsFilled(InfobaseNode) Then
		Message = NStr("en = 'Node not found. Exchange plan: %1. Node ID: %2';");
		Message = StringFunctionsClientServer.SubstituteParametersToString(Message, ExchangePlanName, NodeCode);
		Raise Message;
	EndIf;
	
	If Common.FileInfobase() Then
		
		If CatalogsOnly Then
			
			DataExchangeServer.RegisterOnlyCatalogsForInitialExport(InfobaseNode);
			
		Else
			
			DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport(InfobaseNode);
			
		EndIf;
		
	Else
		
		If CatalogsOnly Then
			MethodName = "DataExchangeServer.RegisterCatalogsOnlyForInitialBackgroundExport";
			JobDescription = NStr("en = 'Register catalog changes for initial export.';");
		Else
			MethodName = "DataExchangeServer.RegisterAllDataExceptCatalogsForInitialBackgroundExport";
			JobDescription = NStr("en = 'Register all data changes except for catalogs for initial export.';");
		EndIf;
		
		ProcedureParameters = New Structure;
		ProcedureParameters.Insert("InfobaseNode", InfobaseNode);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
		ExecutionParameters.BackgroundJobDescription = JobDescription;
		
		ExecutionParameters.RunInBackground = True;
		
		BackgroundJob = TimeConsumingOperations.ExecuteInBackground(MethodName, ProcedureParameters, ExecutionParameters);
			
		If BackgroundJob.Status = "Running" Then
			OperationID = String(BackgroundJob.JobID);
			TimeConsumingOperation = True;
		ElsIf BackgroundJob.Status = "Completed2" Then
			TimeConsumingOperation = False;
		Else
			If ValueIsFilled(BackgroundJob.DetailErrorDescription) Then
				Raise BackgroundJob.DetailErrorDescription;
			EndIf;
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Background job error: %1.';"),
				JobDescription);
		EndIf;
		
	EndIf;
	
EndProcedure

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

#EndRegion
