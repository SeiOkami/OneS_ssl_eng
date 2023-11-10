///////////////////////////////////////////////////////////////////////////////////////////////////////
// 
//  
// 
// 
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 

// Corresponds to the Upload operation.
Function ExecuteExport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage, DataArea)
	
	SignInToDataArea(DataArea);
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// Corresponds to the UploadData operation.
Function RunDataExport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed,
								DataArea)
								
	SignInToDataArea(DataArea);								
								
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID;
	FileIDAsString = String(FileID);
	
	RunExportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// 
Function RunDataExportInternalPublication(ExchangePlanName,
													InfobaseNodeCode,
													TaskID__,
													DataArea)
														
	SetPrivilegedMode(True);
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
		
	ExportDataInClientServerModeInternalPublication(
		ExchangePlanName, InfobaseNodeCode, TaskID__, DataArea);
		
	Return "";
	
EndFunction

// Corresponds to the Download operation.
Function ExecuteImport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage, DataArea)
	
	SignInToDataArea(DataArea);
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage.Get());
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// Corresponds to the DownloadData operation.
Function RunDataImport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed,
								DataArea)
								
	SignInToDataArea(DataArea);
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID(FileIDAsString);
	
	RunImportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);	
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// 
Function RunDataImportInternalPublication(ExchangePlanName,
													InfobaseNodeCode,
													TaskID__,
													FileIDAsString,
													DataArea)
													
	SetPrivilegedMode(True);
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID(FileIDAsString);
	
	ImportDataInClientServerModeInternalPublication(
		ExchangePlanName,	InfobaseNodeCode, TaskID__, FileID, DataArea);	

	Return "";
	
EndFunction

// Corresponds to the GetIBParameters operation.
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage, DataArea, AdditionalXDTOParameters) 
	
	SignInToDataArea(DataArea);
	
	AdditionalParameters = XDTOSerializer.ReadXDTO(AdditionalXDTOParameters);
	
	Result = DataExchangeServer.InfoBaseAdmParams(ExchangePlanName, NodeCode, ErrorMessage, AdditionalParameters);
	
	SignOutOfDataArea(DataArea);
	
	Return XDTOSerializer.WriteXDTO(Result);
	
EndFunction

// Corresponds to the CreateExchangeNode operation.
Function CreateDataExchangeNode(XDTOParameters, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
	  	
	DataExchangeServer.CheckDataExchangeUsage(True);
	
	Parameters = XDTOSerializer.ReadXDTO(XDTOParameters);
	
	ConnectionSettings = Parameters.ConnectionSettings;
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Try
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(
			ConnectionSettings, Parameters.XMLParametersString, , True);
			
		If ValueIsFilled(ConnectionSettings.WSCorrespondentEndpoint) Then
			ConnectionSettings.WSCorrespondentEndpoint = 
				ExchangePlans["MessagesExchange"].FindByCode(ConnectionSettings.WSCorrespondentEndpoint);
			ConnectionSettings.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);	
		Else	
			ConnectionSettings.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
		EndIf;
			
		ModuleSetupWizard.ConfigureDataExchange(
			ConnectionSettings);
	Except
		ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , ErrorMessage);
			
		Raise ErrorMessage;
	EndTry;
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// Corresponds to the RemoveExchangeNode operation.
Function DeleteDataExchangeNode(ExchangePlanName, NodeID, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
		
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Exchange plan node ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, ExchangePlanName, NodeID);
	EndIf;
	
	DataExchangeServer.DeleteSynchronizationSetting(ExchangeNode);
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// Corresponds to the GetContinuousOperationStatus operation.
Function GetTimeConsumingOperationState(OperationID, ErrorMessageString, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
		
	BackgroundJobStates = New Map;
	BackgroundJobStates.Insert(BackgroundJobState.Active,           "Active");
	BackgroundJobStates.Insert(BackgroundJobState.Completed,         "Completed");
	BackgroundJobStates.Insert(BackgroundJobState.Failed, "Failed");
	BackgroundJobStates.Insert(BackgroundJobState.Canceled,          "Canceled");
		
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(OperationID));
	
	If BackgroundJob = Undefined Then
		
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No long-running operation with ID %1 was found.';"),
			OperationID);
			
		SignOutOfDataArea(DataArea);
		
		Return BackgroundJobStates.Get(BackgroundJobState.Canceled);
		
	EndIf;
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = ErrorProcessing.DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	SignOutOfDataArea(DataArea);
	
	Return BackgroundJobStates.Get(BackgroundJob.State);
	
EndFunction

// Corresponds to the PrepareGetFile operation.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity, Zone)
	
	SignInToDataArea(Zone);
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	SourceFileName1 = DataExchangeServer.GetFileFromStorage(FileId);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	SourceFileNameInTemporaryDirectory = CommonClientServer.GetFullFileName(TempDirectory, "data.zip");
	
	CreateDirectory(TempDirectory);
	
	MoveFile(SourceFileName1, SourceFileNameInTemporaryDirectory);
	
	If BlockSize <> 0 Then
		// 
		FilesNames = SplitFile(SourceFileNameInTemporaryDirectory, BlockSize * 1024);
		PartQuantity = FilesNames.Count();
		
		DeleteFiles(SourceFileNameInTemporaryDirectory);
	Else
		PartQuantity = 1;
		MoveFile(SourceFileNameInTemporaryDirectory, SourceFileNameInTemporaryDirectory + ".1");
	EndIf;
	
	SignOutOfDataArea(Zone);
		
	Return "";
	
EndFunction

// Corresponds to the GetFilePart operation.
Function GetFilePart(TransferId, PartNumber, PartData, Zone)
	
	SignInToDataArea(Zone);
	
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
	
	SignOutOfDataArea(Zone);
	
	Return "";
	
EndFunction

// Corresponds to the ReleaseFile operation.
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return "";
	
EndFunction

// Corresponds to the PutFilePart operation.
//
// Parameters:
//   TransferId - UUID - unique ID of the data transfer session.
//   PartNumber - Number - part number of the file.
//   PartData - BinaryData - data part of the file.
//
Function PutFilePart(TransferId, PartNumber, PartData, Zone)
	
	SignInToDataArea(Zone);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TempDirectory);
		
	EndIf;
	
	FileName = CommonClientServer.GetFullFileName(TempDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
	SignOutOfDataArea(Zone);
	
	Return "";
	
EndFunction

// Corresponds to the SaveFileFromParts operation.
Function SaveFileFromParts(TransferId, PartQuantity, FileId, Zone)
	
	SignInToDataArea(Zone);
	
	SetPrivilegedMode(True);
	
	TempDirectory = TemporaryExportDirectory(TransferId);
	
	PartsFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonClientServer.GetFullFileName(TempDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessageTemplate = NStr("en = 'Part %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					|and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';");
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
		
		SignOutOfDataArea(Zone);
		Raise(NStr("en = 'The archive file is empty.';"));
		
	EndIf;
	
	DumpDirectory = DataExchangeServer.TempFilesStorageDirectory();
	
	ArchiveItem = Dearchiver.Items.Get(0);
	FileName = CommonClientServer.GetFullFileName(DumpDirectory, ArchiveItem.Name);
	
	Dearchiver.Extract(ArchiveItem, DumpDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileInStorage(FileName, FileId);
	
	Try
		DeleteFiles(TempDirectory);
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));	
	EndTry;	
	
	SignOutOfDataArea(Zone);
	
	Return "";
	
EndFunction

// Corresponds to the PutMessageForDataMatching operation.
Function PutMessageForDataMatching(ExchangePlanName, NodeID, FileID, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		SignOutOfDataArea(DataArea);	
			
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
	
	SignOutOfDataArea(DataArea);
	
	Return "";
	
EndFunction

// Corresponds to the Ping operation.
Function Ping()
	// 
	Return "";
EndFunction

// Corresponds to the TestConnection operation.
Function TestConnection(ExchangePlanName, NodeCode, Result, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
	
	// 
	Try
		DataExchangeServer.CheckCanSynchronizeData(True);
	Except
		Result = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// 
	Try
		CheckInfobaseLockForUpdate();
	Except
		Result = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// 
	NodeRef1 = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode); 
	If NodeRef1 = Undefined
		Or Common.ObjectAttributeValue(NodeRef1, "DeletionMark") Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		ExchangePlanPresentation1 = Metadata.ExchangePlans[ExchangePlanName].Presentation();
			
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data synchronization setting ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, ExchangePlanPresentation1, NodeCode);
			
		SignOutOfDataArea(DataArea);
			
		Return False;
	EndIf;
	
	SignOutOfDataArea(DataArea);
		
	Return True;
EndFunction

// 
Function ChangeNodeTransportToWSInt(XDTOParameters, DataArea)
	
	SignInToDataArea(DataArea);
	
	SetPrivilegedMode(True);
	
	Parameters = XDTOSerializer.ReadXDTO(XDTOParameters);
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(Parameters.ExchangePlanName, Parameters.CorrespondentNodeCode);
		
	If ExchangeNode = Undefined Then
		
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Exchange plan node ""%2"" with ID %3 is not found in %1.';"),
			ApplicationPresentation, Parameters.ExchangePlanName, Parameters.CorrespondentNodeCode);
			
	EndIf;
		
	Endpoint = ExchangePlans["MessagesExchange"].FindByCode(Parameters.CorrespondentEndpoint);	
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Peer", ExchangeNode);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	RecordStructure.Insert("WSCorrespondentEndpoint", Endpoint);
	RecordStructure.Insert("WSCorrespondentDataArea", Parameters.CorrespondentDataArea);
	RecordStructure.Insert("WSUseLargeVolumeDataTransfer", True);
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Change the transport for node ""%1"" of exchange plan ""%2"" in data area %3 to ""Internet connection"".';"),
		Parameters.CorrespondentNodeCode, Parameters.ExchangePlanName, DataArea);
			
	WriteLogEvent(DataExchangeWebService.EventLogEventTransportChangedOnWS(),
		EventLogLevel.Information, , , MessageText);
	
	InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
	RecordStructure = New Structure("Peer", ExchangeNode);
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "DataAreaExchangeTransportSettings");
	
	SignOutOfDataArea(DataArea);
	
EndFunction

// 
Function Callback(TaskID, Error, Zone)
	
	SignInToDataArea(Zone);
	
	SetPrivilegedMode(True);
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");	
	ModuleDataExchangeInternalPublication.MarkTaskAsCompleted(TaskID, Error);
		
	If Error = "" Then
		
		Task = ModuleDataExchangeInternalPublication.NextTask(TaskID);
		JobPrev = TaskID;
		
		If Task = Undefined Then
			Return "";	
		EndIf;
		
		ProcedureParameters = New Array;
		ProcedureParameters.Add(Task);
		ProcedureParameters.Add(JobPrev);

		Var_Key = Task.TaskID__;

		JobParameters = New Structure;
		JobParameters.Insert("Key", Left(Var_Key, 120));	
		JobParameters.Insert("MethodName"    , "DataExchangeInternalPublication.RunTaskQueue");
		JobParameters.Insert("DataArea", Zone);
		JobParameters.Insert("Use", True);
		JobParameters.Insert("ScheduledStartTime", CurrentSessionDate());
		JobParameters.Insert("Parameters", ProcedureParameters);

		ModuleJobsQueue = Common.CommonModule("JobsQueue");
		ModuleJobsQueue.AddJob(JobParameters);
	
	Else
		
		Task = ModuleDataExchangeInternalPublication.TaskByID(TaskID);
		
		Cancel = False;
		ExchangeSettingsStructure = 
			ModuleDataExchangeInternalPublication.ExchangeSettingsForInfobaseNode(Task.InfobaseNode, Task.Action, Cancel);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
		
	EndIf;
	
	SignOutOfDataArea(Zone);
	
EndFunction

// 
Function TaskStatus(TaskID)
	
	SetPrivilegedMode(True);
	
	JobParameters = New Structure("Key", TaskID);
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	Jobs = ModuleJobsQueue.GetTasks(JobParameters);
	
	If Jobs.Count() > 0 Then
		
		State = Jobs[0].Id.JobState;
		
		MetadataObjectsList = State.Metadata();
		EnumManager = Enums[MetadataObjectsList.Name];
		ValueIndex = EnumManager.IndexOf(State);

		Return MetadataObjectsList.EnumValues.Get(ValueIndex).Name;
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// 
Function StopTasks(TasksID, Zone)
	
	SignInToDataArea(Zone);
	
	SetPrivilegedMode(True);
	
	TasksIDs = XDTOSerializer.ReadXDTO(TasksID);
	
	For Each TaskID__ In TasksIDs Do
		
		Filter = New Structure("Key", TaskID__);
		ModuleJobsQueue = Common.CommonModule("JobsQueue");
		Jobs = ModuleJobsQueue.GetTasks(Filter);
		
		If Jobs.Count() = 0 Then
			Continue;
		EndIf;	
			
		BackgrJobUUID = Jobs[0].Id.ActiveBackgroundJob;
			
		If Not ValueIsFilled(BackgrJobUUID) Then
			Continue;
		EndIf;
		
		BackgroundJob = BackgroundJobs.FindByUUID(BackgrJobUUID);
		If BackgroundJob <> Undefined Then
			BackgroundJob.Cancel();
		EndIf;
		
	EndDo;
	
	SignOutOfDataArea(Zone);
	
	Return "";
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

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

Procedure ExportDataInClientServerModeInternalPublication(ExchangePlanName,
		InfobaseNodeCode, TaskID__, DataArea)
			
	ProcedureParameters = New Array;
	ProcedureParameters.Add(ExchangePlanName);
	ProcedureParameters.Add(InfobaseNodeCode);
	ProcedureParameters.Add(TaskID__);
	
	Var_Key = TaskID__;
	
	JobParameters = New Structure;
	JobParameters.Insert("Key", Left(Var_Key, 120));
	JobParameters.Insert("MethodName"    , "DataExchangeInternalPublication.ExportToFileTransferServiceForInfobaseNode");
	JobParameters.Insert("DataArea", DataArea);
	JobParameters.Insert("Use", True);
	JobParameters.Insert("ScheduledStartTime", CurrentSessionDate());
	JobParameters.Insert("Parameters", ProcedureParameters);
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	ModuleJobsQueue.AddJob(JobParameters);
	
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

Procedure ImportDataInClientServerModeInternalPublication(ExchangePlanName,
		InfobaseNodeCode, TaskID__, FileID, DataArea)
		
	ProcedureParameters = New Array;
	ProcedureParameters.Add(ExchangePlanName);
	ProcedureParameters.Add(InfobaseNodeCode);
	ProcedureParameters.Add(TaskID__);
	ProcedureParameters.Add(FileID);
	
	Var_Key = TaskID__;
	
	JobParameters = New Structure;
	JobParameters.Insert("Key", Left(Var_Key, 120));
	JobParameters.Insert("MethodName"    , "DataExchangeInternalPublication.ImportFromFileTransferServiceForInfobaseNode");
	JobParameters.Insert("DataArea", DataArea);
	JobParameters.Insert("Use", True);
	JobParameters.Insert("ScheduledStartTime", CurrentSessionDate());
	JobParameters.Insert("Parameters", ProcedureParameters);
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	ModuleJobsQueue.AddJob(JobParameters);
	
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

Procedure SignInToDataArea(DataArea)
	
	If DataArea = 0 
		Or Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
		
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");

	ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
	CTLVersion = ModuleSaaSTechnology.LibraryVersion();

	If CommonClientServer.CompareVersions(CTLVersion, "2.0.7.46") >= 0 Then
		ModuleSaaSOperations.SignInToDataArea(DataArea); //
	Else
		ModuleSaaSOperations.SetSessionSeparation(True, DataArea);
	EndIf;
	
EndProcedure

Procedure SignOutOfDataArea(DataArea)
	
	If DataArea = 0 
		Or Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
		
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");

	ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
	CTLVersion = ModuleSaaSTechnology.LibraryVersion();

	If CommonClientServer.CompareVersions(CTLVersion, "2.0.7.46") >= 0 Then
		ModuleSaaSOperations.SignOutOfDataArea(); //
	Else
		ModuleSaaSOperations.SetSessionSeparation(False);
	EndIf;
	
EndProcedure


#EndRegion
