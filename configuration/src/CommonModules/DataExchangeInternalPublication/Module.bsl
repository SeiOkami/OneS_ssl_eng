///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

Procedure RunDataExchangeByScenario(ExchangeScenarioCode) Export
	
	If Not ValueIsFilled(ExchangeScenarioCode) Then		
		Raise NStr("en = 'Data exchange scenario not specified.';");		
	EndIf;
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.DataSynchronization);
	
	Query = New Query;
	Query.SetParameter("Code", ExchangeScenarioCode);
	
	Query.Text = 
		"SELECT
		|	DataExchangeScenarios.Ref AS Ref
		|FROM
		|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
		|WHERE
		|	DataExchangeScenarios.Code = &Code
		|	AND NOT DataExchangeScenarios.DeletionMark";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Scenario = Selection.Ref;
		
	Else	
		
		MessageString = NStr("en = 'Data exchange scenario with code %1 is not found.';");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeScenarioCode);
		Raise MessageString;
		
	EndIf;
		
	DeleteObsoleteTasks(Scenario);
	
	If DisableScenarioOnDemand(Scenario) Then
		Return;
	EndIf;
	
	// 
	If Not IsTaskQueueCompleted(Scenario) Then
		Return;
	EndIf;
			
	FirstTask = Undefined;
	RunTaskByScenario(Scenario, FirstTask);
	
	RunTaskQueue(FirstTask);
		
EndProcedure

Procedure RunDataExchangeManually(Node, ExchangeParameters, ExportAddition = Undefined) Export
	
	DeleteObsoleteTasks(, True);
	
	ExchangeID = String(New UUID);
	
	ExchangeParameters = New Structure;
	ExchangeParameters.Insert("Node", Node);
	ExchangeParameters.Insert("ExchangeID", ExchangeID);
	ExchangeParameters.Insert("Cancel", False);
	ExchangeParameters.Insert("ErrorMessage", "");
	
	FirstTask = Undefined;
	PopulatesTasksForManualExchange(Node, ExchangeID, FirstTask, ExportAddition);

	ProcedureParameters = New Array;
	ProcedureParameters.Add(FirstTask);
	
	Var_Key = FirstTask.TaskID__;

	JobParameters = New Structure;
	JobParameters.Insert("Key", Left(Var_Key, 120));	
	JobParameters.Insert("MethodName"    , "DataExchangeInternalPublication.RunTaskQueue");
	JobParameters.Insert("DataArea", SessionParameters.DataAreaValue);
	JobParameters.Insert("Use", True);
	JobParameters.Insert("ScheduledStartTime", CurrentUniversalDate());
	JobParameters.Insert("Parameters", ProcedureParameters);

	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	ModuleJobsQueue.AddJob(JobParameters);
	
EndProcedure	

Procedure RunTaskQueue(Task, JobPrev = "") Export
	
	If TypeOf(Task) = Type("String") Then
		CurrTask = TaskByID(Task);
	Else
		CurrTask = Task;
	EndIf;
		
	Cancel = False;
	If CurrTask.TaskNumber = 1 Then
		
		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(CurrTask.InfobaseNode, CurrTask.Action, Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		DataExchangeServer.RecordExchangeStartInInformationRegister(ExchangeSettingsStructure);
		
		MessageString = NStr("en = 'Data exchange started. Node: %1.';", Common.DefaultLanguageCode());
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
		DataExchangeServer.WriteEventLogDataExchange(MessageString, ExchangeSettingsStructure);
	
	EndIf;
	
	// 
	ActionsInSource = New Array;
	ActionsInSource.Add(Enums.ActionsAtCancelInternalPublication.DataExport);
	ActionsInSource.Add(Enums.ActionsAtCancelInternalPublication.DataImport);
	ActionsInSource.Add(Enums.ActionsAtCancelInternalPublication.AdditionalRegistration);
	
	Cancel = False;
	While True Do
		
		ExchangeParameters = DataExchangeServer.ExchangeParameters();
		ExchangeParameters.Insert("TaskIDPrev", JobPrev);
		
		ExecuteTask(CurrTask, ExchangeParameters, Cancel);	
		
		If Not Cancel And ActionsInSource.Find(CurrTask.Action) <> Undefined Then
			
			JobPrev = CurrTask.TaskID__;
			CurrTask = NextTask(CurrTask.TaskID__);
			
		Else
			
			Break;
			
		EndIf;
		
		// 
		If CurrTask = Undefined Then
			Break;
		EndIf;
		
	EndDo;
		
EndProcedure

Function TaskByID(TaskID__) Export

	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tasks.CreationDate AS CreationDate,
		|	Tasks.Scenario AS Scenario,
		|	Tasks.InfobaseNode AS InfobaseNode,
		|	Tasks.TaskNumber AS TaskNumber,
		|	Tasks.TaskID__ AS TaskID__,
		|	Tasks.ExchangeID AS ExchangeID,
		|	Tasks.Action AS Action,
		|	Tasks.OperationSuccessful AS OperationSuccessful,
		|	Tasks.OperationFailed AS OperationFailed,
		|	Tasks.Error AS Error,
		|	Tasks.Parameters AS Parameters
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	Tasks.TaskID__ = &TaskID__";
	
	Query.SetParameter("TaskID__", TaskID__);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = StructureOfTask();
		FillPropertyValues(Result, Selection);
		Return Result;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function NextTask(TaskID__) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	TaskNxt.CreationDate AS CreationDate,
		|	TaskNxt.Scenario AS Scenario,
		|	TaskNxt.InfobaseNode AS InfobaseNode,
		|	TaskNxt.TaskNumber AS TaskNumber,
		|	TaskNxt.TaskID__ AS TaskID__,
		|	TaskNxt.ExchangeID AS ExchangeID,
		|	TaskNxt.Action AS Action,
		|	TaskNxt.OperationSuccessful AS OperationSuccessful,
		|	TaskNxt.OperationFailed AS OperationFailed,
		|	TaskNxt.Error AS Error,
		|	TaskNxt.Parameters AS Parameters
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Task
		|		INNER JOIN InformationRegister.DataExchangeTasksInternalPublication AS TaskNxt
		|		ON Task.ExchangeID = TaskNxt.ExchangeID
		|			AND (Task.TaskNumber + 1 = TaskNxt.TaskNumber)
		|WHERE
		|	Task.TaskID__ = &TaskID__";
	
	Query.SetParameter("TaskID__", TaskID__);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = StructureOfTask();
		FillPropertyValues(Result, Selection);
		Return Result;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function HasNodeScheduledExchange(Node, Scenario = "", ExchangeID = "") Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tasks.Scenario AS Scenario,
		|	Tasks.ExchangeID AS ExchangeID
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	Tasks.InfobaseNode = &Node
		|	AND NOT Tasks.OperationSuccessful
		|	AND NOT Tasks.OperationFailed
		|
		|ORDER BY
		|	Tasks.CreationDate DESC,
		|	Tasks.TaskNumber";
	
	Query.SetParameter("Node", Node);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Scenario = Selection.Scenario;
		ExchangeID = Selection.ExchangeID;
		
		Return Not IsTaskQueueCompleted(, Selection.ExchangeID);
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure CancelTaskQueue(Node, Scenario, ExchangeID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	Tasks.CreationDate AS CreationDate,
		|	Tasks.Scenario AS Scenario,
		|	Tasks.ExchangeID AS ExchangeID
		|INTO ttLastScenario
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	Tasks.ExchangeID = &ExchangeID
		|
		|ORDER BY
		|	CreationDate DESC
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tasks.CreationDate AS CreationDate,
		|	Tasks.InfobaseNode AS InfobaseNode,
		|	Tasks.TaskNumber AS TaskNumber,
		|	Tasks.ExchangeID AS ExchangeID,
		|	Tasks.TaskID__ AS TaskID__
		|FROM
		|	ttLastScenario AS ttLastScenario
		|		INNER JOIN InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|		ON ttLastScenario.CreationDate = Tasks.CreationDate
		|			AND ttLastScenario.ExchangeID = Tasks.ExchangeID
		|			AND (NOT Tasks.OperationSuccessful)
		|			AND (NOT Tasks.OperationFailed)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tasks.TaskID__ AS TaskID__,
		|	Tasks.Action AS Action,
		|	Tasks.OperationSuccessful AS OperationSuccessful,
		|	Tasks.OperationFailed AS OperationFailed
		|FROM
		|	ttLastScenario AS ttLastScenario
		|		LEFT JOIN InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|		ON ttLastScenario.CreationDate = Tasks.CreationDate
		|			AND ttLastScenario.ExchangeID = Tasks.ExchangeID";
	
	Query.SetParameter("ExchangeID", ExchangeID);
	
	Result = Query.ExecuteBatch();
		
	Selection = Result[1].Select();
	
	While Selection.Next() Do
		
		Record = InformationRegisters.DataExchangeTasksInternalPublication.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		
		If Record.Selected() Then
			Record.OperationFailed = True;
			Record.Error = NStr("en = 'Canceled by user';");
			Record.Write();
		EndIf;
		
	EndDo;
	
	SourceTasks = New Array;
	
	If TypeOf(Scenario) = Type("CatalogRef.DataExchangeScenarios") Then
		SourceTasks.Add(Scenario.GUIDScheduledJob);
	EndIf;
	
	DestinationTasks = New Array;
	
	Selection = Result[2].Select();
	
	While Selection.Next() Do
		
		If (Selection.Action = Enums.ActionsAtCancelInternalPublication.DataExportPeer
			Or Selection.Action = Enums.ActionsAtCancelInternalPublication.DataImportPeer)
			And Not Selection.OperationSuccessful Then
			
			DestinationTasks.Add(Selection.TaskID__);
			
		ElsIf Selection.Action = Enums.ActionsAtCancelInternalPublication.DataExport
			Or Selection.Action = Enums.ActionsAtCancelInternalPublication.DataImport
			Or Selection.Action = Enums.ActionsAtCancelInternalPublication.AdditionalRegistration Then
			
			SourceTasks.Add(Selection.TaskID__);
			
		EndIf;
		
		If Not Selection.OperationSuccessful Then
			Break;
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(True);
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	
	For Each TaskID__ In SourceTasks Do
		
		Filter = New Structure("Key", TaskID__); 
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
	
	If DestinationTasks.Count() > 0 Then
		
		Proxy = Undefined;
		ProxyParameters = New Structure;
		ExchangeSettingsStructure = Undefined;
		Cancel = False;
		Error = "";

		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(Node, "UserCanceledOperation", Cancel);
		ProxyInitialization(Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error);
		
		Proxy.StopTasks(XDTOSerializer.WriteXDTO(DestinationTasks),
			ExchangeSettingsStructure.TransportSettings.WSCorrespondentDataArea);
		
	EndIf;
	
EndProcedure

Procedure MarkTaskAsCompleted(Task, Error) Export
	
	If TypeOf(Task) = Type("String") Then
		CurrTask = TaskByID(Task);
	Else
		CurrTask = Task;
	EndIf;
	
	If ValueIsFilled(CurrTask) Then
		
		Record = InformationRegisters.DataExchangeTasksInternalPublication.CreateRecordManager();
		FillPropertyValues(Record, CurrTask);
		Record.Read();
			
		If Error = "" Then
			Record.OperationSuccessful = True;	
		Else
			Record.OperationFailed = True;
			Record.Error = Error;	
		EndIf;
		
		Record.Write();
		
	EndIf;
	
EndProcedure

Procedure OnWaitForExportData(ExchangeParameters, ContinueWait) Export
	
	Error = "";
	ContinueWait = Not IsTaskQueueCompleted(,ExchangeParameters.ExchangeID, Error);

	If Error <> "" Then
		ExchangeParameters.Cancel = True;
		ExchangeParameters.ErrorMessage = Error;
	EndIf;	
		
EndProcedure

Procedure NodeFormOnCreateAtServer(Form, Cancel) Export
	
	ModuleDataExchangeTransportSettings = InformationRegisters["DataExchangeTransportSettings"];
	TransportSettings = ModuleDataExchangeTransportSettings.TransportSettings(Form.Object.Ref);
	
	If TransportSettings <> Undefined Then
		SetFuncOptionsForNode(Form, TransportSettings);
		SetUpFormElementsForMigrationToWS(Form, TransportSettings);
	EndIf;
	
EndProcedure

#Region DestinationTasks

Procedure ExportToFileTransferServiceForInfobaseNode(ExchangePlanName, InfobaseNodeCode, TaskID__) Export
	
	SetPrivilegedMode(True);
	
	MessageFileName = CommonClientServer.GetFullFileName(
		DataExchangeServer.TempFilesStorageDirectory(),
		DataExchangeServer.UniqueExchangeMessageFileName());
	
	DataExchangeParameters = DataExchangeServer.DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = MessageFileName;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataExport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	ErrorPresentation = "";
	Try
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
		
		NameOfFileToPutInStorage = MessageFileName;

		NameOfFileToPutInStorage = CommonClientServer.GetFullFileName(
			DataExchangeServer.TempFilesStorageDirectory(),
			DataExchangeServer.UniqueExchangeMessageFileName("zip"));
		
		Archiver = New ZipFileWriter(NameOfFileToPutInStorage, , , , ZIPCompressionLevel.Maximum);
		Archiver.Add(MessageFileName);
		Archiver.Write();
		
	Except
				
		ErrorPresentation = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		CallingBack(ExchangePlanName, InfobaseNodeCode, TaskID__, ErrorPresentation);
		
		DeleteFiles(MessageFileName);
		Raise ErrorPresentation;
		
	EndTry;
	
	DeleteFiles(MessageFileName);
	
	DataExchangeServer.PutFileInStorage(NameOfFileToPutInStorage, TaskID__);
		
	CallingBack(ExchangePlanName, InfobaseNodeCode, TaskID__);
		
EndProcedure

Procedure ImportFromFileTransferServiceForInfobaseNode(ExchangePlanName, InfobaseNodeCode, TaskID__, FileID) Export
	
	SetPrivilegedMode(True);
	
	MessageFileName = DataExchangeServer.GetFileFromStorage(FileID);
	
	DataExchangeParameters = DataExchangeServer.DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.FullNameOfExchangeMessageFile = MessageFileName;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataImport;
	DataExchangeParameters.ExchangePlanName                = ExchangePlanName;
	DataExchangeParameters.InfobaseNodeCode     = InfobaseNodeCode;
	
	ErrorPresentation = "";
	Try
				
		DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
		
	Except
		
		ErrorPresentation = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		CallingBack(ExchangePlanName, InfobaseNodeCode, TaskID__, ErrorPresentation);
		
		DeleteFiles(MessageFileName);
		Raise ErrorPresentation;
		
	EndTry;
	
	DeleteFiles(MessageFileName);
	
	CallingBack(ExchangePlanName, InfobaseNodeCode, TaskID__);
	
EndProcedure

#EndRegion

#Region AvailabilityOfExchangeAdministrationManage_3_0_1_1

Function HasInServiceExchangeAdministrationManage_3_0_1_1() Export
	
	If Not Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	ConnectionParameters = New Structure;
	SetPrivilegedMode(True);
	ConnectionParameters.Insert("URL", ModuleSaaSOperations.InternalServiceManagerURL());
	ConnectionParameters.Insert("UserName", ModuleSaaSOperations.ServiceManagerInternalUserName());
	ConnectionParameters.Insert("Password", ModuleSaaSOperations.ServiceManagerInternalUserPassword());
	SetPrivilegedMode(False);
	
	Versions = Common.GetInterfaceVersions(ConnectionParameters, "ExchangeAdministrationManage");
	
	Return Versions.Find("3.0.1.1") <> Undefined;
	
EndFunction

#EndRegion

Function ExchangeSettingsForInfobaseNode(Node, Action, Cancel) Export
	
	If Action = Enums.ActionsAtCancelInternalPublication.DataImport
		Or Action = Enums.ActionsAtCancelInternalPublication.DataExportPeer Then		
		
		ActionOnExchange = Enums.ActionsOnExchange.DataImport;		
		
	ElsIf Action = Enums.ActionsAtCancelInternalPublication.DataExport 
		Or Action = Enums.ActionsAtCancelInternalPublication.DataImportPeer Then		
		
		ActionOnExchange = Enums.ActionsOnExchange.DataExport;
		
	Else
		
		ActionOnExchange = Action;
		
	EndIf;
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsForInfobaseNode(
		Node, ActionOnExchange, Enums.ExchangeMessagesTransportTypes.WS, False);
	
	If ExchangeSettingsStructure.Cancel Then
		// 
		DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
		Cancel = True;
		Return Undefined;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	
	Return ExchangeSettingsStructure;
	
EndFunction

#EndRegion

#Region Private

#Region Tasks

Procedure DeleteObsoleteTasks(Scenario = Undefined, ManualExchange = False)
	
	// 
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT TOP 5
		|	Tasks.CreationDate AS CreationDate
		|INTO TTDates
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	(&ManualExchange
		|				AND VALUETYPE(Tasks.Scenario) = TYPE(STRING)
		|			OR NOT &ManualExchange
		|				AND Tasks.Scenario = &Scenario)
		|
		|ORDER BY
		|	CreationDate DESC
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tasks.CreationDate AS CreationDate,
		|	Tasks.InfobaseNode AS InfobaseNode,
		|	Tasks.TaskNumber AS TaskNumber,
		|	Tasks.ExchangeID AS ExchangeID,
		|	Tasks.TaskID__ AS TaskID__
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	Tasks.Scenario = &Scenario
		|	AND NOT Tasks.CreationDate IN
		|				(SELECT
		|					TTDates.CreationDate
		|				FROM
		|					TTDates)";
	
	Query.SetParameter("Scenario", Scenario);
	Query.SetParameter("ManualExchange", ManualExchange);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		Record = InformationRegisters.DataExchangeTasksInternalPublication.CreateRecordManager();
		FillPropertyValues(Record, Selection);
		Record.Read();
		
		If Record.Selected() Then
			Record.Delete();
		EndIf;
		
	EndDo;
	
EndProcedure

Function DisableScenarioOnDemand(Scenario)
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT TOP 3
		|	Tasks.CreationDate AS CreationDate,
		|	Tasks.Scenario AS Scenario,
		|	Tasks.ExchangeID AS ExchangeID
		|INTO TTDates
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	Tasks.Scenario = &Scenario
		|
		|ORDER BY
		|	CreationDate DESC
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Tasks.CreationDate AS CreationDate
		|FROM
		|	TTDates AS TTDates
		|		INNER JOIN InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|		ON TTDates.CreationDate = Tasks.CreationDate
		|			AND TTDates.ExchangeID = Tasks.ExchangeID
		|			AND (Tasks.OperationFailed)";
	
	Query.SetParameter("Scenario", Scenario);
	
	Result = Query.Execute().Unload();
	
	If Result.Count() >= 3 Then
			
		ScenarioObject = Scenario.GetObject();
		ScenarioObject.UseScheduledJob = False;
		ScenarioObject.IsAutoDisabled = True;
		
		BeginTransaction();
		
		Try
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.DataExchangeScenarios");
			LockItem.SetValue("Ref", Scenario);
			LockItem.Mode = DataLockMode.Exclusive;
			Block.Lock();
			
			ScenarioObject.Write();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorMessage = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
			WriteLogEvent(EventLogEventScenarioDisabled(),
				EventLogLevel.Error, , , ErrorMessage);
			
		EndTry;
				
		Return True;
			
	EndIf;
	
	Return False;
	
EndFunction

Function IsTaskQueueCompleted(Scenario = "", ExchangeID = "", Error = "")
	
	//  
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Tasks.TaskID__ AS TaskID__,
		|	Tasks.InfobaseNode AS InfobaseNode,
		|	Tasks.TaskNumber AS TaskNumber,
		|	Tasks.Action AS Action,
		|	Tasks.OperationSuccessful AS OperationSuccessful,
		|	Tasks.OperationFailed AS OperationFailed,
		|	Tasks.Error AS Error
		|INTO TTTasks
		|FROM
		|	InformationRegister.DataExchangeTasksInternalPublication AS Tasks
		|WHERE
		|	(Tasks.Scenario = &Scenario
		|			OR Tasks.ExchangeID = &ExchangeID)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TTTasks.TaskID__ AS TaskID__,
		|	TTTasks.Action AS Action,
		|	TTTasks.Error AS Error
		|FROM
		|	TTTasks AS TTTasks
		|WHERE
		|	TTTasks.OperationFailed
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TRUE AS Completed2
		|FROM
		|	TTTasks AS TTTasks
		|
		|HAVING
		|	SUM(CASE
		|			WHEN TTTasks.OperationSuccessful
		|				THEN 1
		|			ELSE 0
		|		END) = MAX(TTTasks.TaskNumber)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TTTasks.TaskID__ AS TaskID__,
		|	TTTasks.InfobaseNode AS InfobaseNode,
		|	TTTasks.Action AS Action,
		|	TTTasks.TaskNumber AS TaskNumber
		|FROM
		|	TTTasks AS TTTasks
		|WHERE
		|	NOT TTTasks.OperationSuccessful
		|	AND NOT TTTasks.OperationFailed
		|
		|ORDER BY
		|	TaskNumber";
	
	Query.SetParameter("Scenario", Scenario);
	Query.SetParameter("ExchangeID", ExchangeID);
	
	Result = Query.ExecuteBatch();
	
	// 
	Selection = Result[1].Select();
	If Selection.Next() Then
		Error = Selection.Error;
		Return True;
	EndIf;
	
	// 
	Selection = Result[2].Select();
	If Selection.Next() Then
		Return True;
	EndIf;
	
	// 
	Selection = Result[3].Select();
	
	If Selection.Next() Then
		Return False
	EndIf;
		
	Return True;

EndFunction

Function StructureOfTask()
	
	Task = New Structure;
	Task.Insert("CreationDate");
	Task.Insert("Scenario");
	Task.Insert("InfobaseNode");
	Task.Insert("TaskNumber");
	Task.Insert("ExchangeID");
	Task.Insert("TaskID__");
	Task.Insert("Action");
	Task.Insert("OperationSuccessful");
	Task.Insert("OperationFailed");
	Task.Insert("Parameters");
	
	Return Task;
	
EndFunction

Procedure RunTaskByScenario(Scenario, FirstTask = Undefined) 
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ExchangeSettings.InfobaseNode AS InfobaseNode,
		|	ExchangeSettings.CurrentAction AS CurrentAction
		|FROM
		|	Catalog.DataExchangeScenarios.ExchangeSettings AS ExchangeSettings
		|WHERE
		|	ExchangeSettings.Ref = &Ref
		|
		|ORDER BY
		|	ExchangeSettings.LineNumber";
	
	Query.SetParameter("Ref", Scenario);
	
	Selection = Query.Execute().Select(); // ACC:1328 - 
	
	TaskNumber = 1;
	
	Record = StructureOfTask();
	Record.CreationDate = CurrentUniversalDate();
	Record.Scenario = Scenario;
	Record.OperationSuccessful = False;
	Record.OperationFailed = False;
	Record.ExchangeID = String(New UUID);
	
	Set = InformationRegisters.DataExchangeTasksInternalPublication.CreateRecordSet();
		
	While Selection.Next() Do
		
		Record.Insert("InfobaseNode", Selection.InfobaseNode);
		
		If Selection.CurrentAction = Enums.ActionsOnExchange.DataImport Then
			
			//
			Record.Action = Enums.ActionsAtCancelInternalPublication.DataExportPeer;
			Record.TaskID__ = String(New UUID);
			Record.TaskNumber = TaskNumber;
						
			NewRecord = Set.Add();
			FillPropertyValues(NewRecord, Record);
			
			If FirstTask = Undefined Then
				FirstTask = Common.CopyRecursive(Record, False);
			EndIf;
			
			TaskNumber = TaskNumber + 1;
			
			//
			Record.Action = Enums.ActionsAtCancelInternalPublication.DataImport;
			Record.TaskID__ = String(New UUID);
			Record.TaskNumber = TaskNumber;
			
			NewRecord = Set.Add();
			FillPropertyValues(NewRecord, Record);
			
			TaskNumber = TaskNumber + 1;
			
		Else
			
			//
			Record.Action = Enums.ActionsAtCancelInternalPublication.DataExport;
			Record.TaskID__ = String(New UUID);
			Record.TaskNumber = TaskNumber;
			
			NewRecord = Set.Add();
			FillPropertyValues(NewRecord, Record);
			
			If FirstTask = Undefined Then
				FirstTask = Common.CopyRecursive(Record, False);
			EndIf;
			
			TaskNumber = TaskNumber + 1;
			
			//
			Record.Action = Enums.ActionsAtCancelInternalPublication.DataImportPeer;
			Record.TaskID__ = String(New UUID);
			Record.TaskNumber = TaskNumber;
			
			NewRecord = Set.Add();
			FillPropertyValues(NewRecord, Record);
			
			TaskNumber = TaskNumber + 1;
			
		EndIf;
		
	EndDo;
	
	Set.Write(False);
	
EndProcedure

Procedure PopulatesTasksForManualExchange(InfobaseNode, ExchangeID, FirstTask, ExportAddition)
	
	Record = StructureOfTask();
	Record.CreationDate = CurrentUniversalDate();
	Record.InfobaseNode = InfobaseNode;
	Record.OperationSuccessful = False;
	Record.OperationFailed = False;
	Record.ExchangeID = ExchangeID;
		
	Set = InformationRegisters.DataExchangeTasksInternalPublication.CreateRecordSet();
	
	TaskNumber = 1;
			
	// 
	Record.Action = Enums.ActionsAtCancelInternalPublication.DataExportPeer;
	Record.TaskID__ = String(New UUID);
	Record.TaskNumber = TaskNumber;
	NewRecord = Set.Add();
	FillPropertyValues(NewRecord, Record);
	
	TaskNumber = TaskNumber + 1;
			
	FirstTask = Common.CopyRecursive(Record, False);
	
	// 
	Record.Action = Enums.ActionsAtCancelInternalPublication.DataImport;
	Record.TaskID__ = String(New UUID);
	Record.TaskNumber = TaskNumber;
	NewRecord = Set.Add();
	FillPropertyValues(NewRecord, Record);
	
	TaskNumber = TaskNumber + 1;
	
	// 
	If ExportAddition <> Undefined Then

		Record.Action = Enums.ActionsAtCancelInternalPublication.AdditionalRegistration;
		Record.TaskID__ = String(New UUID);
		Record.TaskNumber = TaskNumber;
		NewRecord = Set.Add();
		FillPropertyValues(NewRecord, Record);
		NewRecord.Parameters = New ValueStorage(ExportAddition);
		
		TaskNumber = TaskNumber + 1;
	
	EndIf;
		
	// 
	Record.Action = Enums.ActionsAtCancelInternalPublication.DataExport;
	Record.TaskID__ = String(New UUID);
	Record.TaskNumber = TaskNumber;
	NewRecord = Set.Add();
	FillPropertyValues(NewRecord, Record);
	
	TaskNumber = TaskNumber + 1;
		
	// 
	Record.Action = Enums.ActionsAtCancelInternalPublication.DataImportPeer;
	Record.TaskID__ = String(New UUID);
	Record.TaskNumber = TaskNumber;	
	NewRecord = Set.Add();
	FillPropertyValues(NewRecord, Record);	
			
	Set.Write(False);
	
EndProcedure

Procedure CallingBack(ExchangePlanName, InfobaseNodeCode, TaskID__, Error = "")
	
	Node = ExchangePlans[ExchangePlanName].FindByCode(InfobaseNodeCode);
	TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(Node);
	ErrorMessageString = "";
	
	Proxy = DataExchangeWebService.WSProxyForInfobaseNode(Node, ErrorMessageString);
	
	Proxy.Callback(TaskID__, Error, TransportSettings.WSCorrespondentDataArea);

EndProcedure

Procedure ExecuteTask(Task, ExchangeParameters, Cancel) Export
	
	// 
	If Task.OperationFailed Then
		Cancel = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Proxy = Undefined;
	ProxyParameters = New Structure;
	ExchangeSettingsStructure = Undefined;
	
	Error = "";
	Node = Task.InfobaseNode;
	Action = Task.Action;

	If Action = Enums.ActionsAtCancelInternalPublication.DataExportPeer Then
		
		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(Node, Action, Cancel);
		ProxyInitialization(Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error);
		RunTaskExportDataPeer(Task, Proxy, ExchangeSettingsStructure, Cancel, Error);
		MarkTaskAsCompleted(Task, Error);
		
	ElsIf Action = Enums.ActionsAtCancelInternalPublication.DataImport Then
		
		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(Node, Action, Cancel);
		ImportDataImportTask(Task, ExchangeParameters, ExchangeSettingsStructure, Cancel, Error);
		MarkTaskAsCompleted(Task, Error);
		DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
						
	ElsIf Action = Enums.ActionsAtCancelInternalPublication.DataExport Then
		
		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(Node, Action, Cancel);
		ProxyInitialization(Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error);
		PerformTaskDataExport(Task, Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error);
		MarkTaskAsCompleted(Task, Error);
		DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
								
	ElsIf Action = Enums.ActionsAtCancelInternalPublication.DataImportPeer Then
		
		ExchangeSettingsStructure = ExchangeSettingsForInfobaseNode(Node, Action, Cancel);
		ProxyInitialization(Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error);
		RunTaskImportDataPeer(Task, Proxy, ExchangeParameters, ExchangeSettingsStructure, Cancel, Error)
		
	ElsIf Action = Enums.ActionsAtCancelInternalPublication.AdditionalRegistration Then
		
		PerformTaskAdditionalRegistration(Task, Cancel, Error);	
		MarkTaskAsCompleted(Task, Error);
		
	EndIf;
				
EndProcedure

Procedure RunTaskExportDataPeer(Task, Proxy, ExchangeSettingsStructure, Cancel, Error)
	
	If Cancel Then
		Return;
	EndIf;
	
	Try
			
		Proxy.UploadDataInt(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode1,
			Task.TaskID__, ExchangeSettingsStructure.TransportSettings.WSCorrespondentDataArea);
								
	Except
		
		Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		Cancel = True;
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
			
	EndTry;

EndProcedure

Procedure ImportDataImportTask(Task, ExchangeParameters, ExchangeSettingsStructure, Cancel, Error)
	
	If Cancel Then
		Return;
	EndIf;

	Try
		
		UIDOfTheMessageFile = New UUID(ExchangeParameters.TaskIDPrev);
		FileExchangeMessages = DataExchangeWebService.GetFileFromStorageInService(UIDOfTheMessageFile,
			ExchangeSettingsStructure.InfobaseNode, 1024, ExchangeParameters.AuthenticationParameters);

		DataExchangeServer.ReadMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
		
	Except
		
		Cancel = True;
		Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;

	EndTry;
	
	If ExchangeResultCompletedWithError(ExchangeSettingsStructure, Cancel, Error) Then
		Return;
	EndIf;
	
	MessageRead = DataExchangeServer.ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult);
	
	If MessageRead And Common.SeparatedDataUsageAvailable() Then
		InformationRegisters.DataSyncEventHandlers.ExecuteHandlers(ExchangeSettingsStructure.InfobaseNode, "AfterGetData");
	EndIf;
	
	Try
		If Not IsBlankString(FileExchangeMessages) Then
			DeleteFiles(FileExchangeMessages);
		EndIf;
	Except
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;

EndProcedure

Procedure PerformTaskDataExport(Task, Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error)

	If Cancel Then
		Return;
	EndIf;

	TempDirectory = GetTempFileName();
	CreateDirectory(TempDirectory);
	
	FileExchangeMessages = CommonClientServer.GetFullFileName(TempDirectory, DataExchangeServer.UniqueExchangeMessageFileName());
	
	Try
		DataExchangeServer.WriteMessageWithNodeChanges(ExchangeSettingsStructure, FileExchangeMessages);
	Except
		Cancel = True;
		Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
	EndTry;
	
	If ExchangeResultCompletedWithError(ExchangeSettingsStructure, Cancel, Error) Then
		Return;
	EndIf;
		
	If DataExchangeServer.ExchangeExecutionResultCompleted(ExchangeSettingsStructure.ExchangeExecutionResult) And Not Cancel Then
		
		Try
			
			FileID = Task.TaskID__;
			
			DataExchangeWebService.PutFileInStorageInService(Proxy, ProxyParameters.CurrentVersion, ExchangeSettingsStructure, 
				FileExchangeMessages, ExchangeSettingsStructure.InfobaseNode, 1024, FileID);
				
			If ExchangeResultCompletedWithError(ExchangeSettingsStructure, Cancel, Error) Then
				Return;
			EndIf;
	    				
			Try
				DeleteFiles(TempDirectory);
			Except
				WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
					EventLogLevel.Error,,, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
			
		Except
			
			Cancel = True;
			Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
			DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
			ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
						
		EndTry;
		
	EndIf;
	
EndProcedure	

Procedure RunTaskImportDataPeer(Task, Proxy, ExchangeParameters, ExchangeSettingsStructure, Cancel, Error)
	
	If Cancel Then
		Return;
	EndIf;

	Try
		
		Proxy.DownloadDataInt(ExchangeSettingsStructure.ExchangePlanName, ExchangeSettingsStructure.CurrentExchangePlanNodeCode1,
			Task.TaskID__, ExchangeParameters.TaskIDPrev,
			ExchangeSettingsStructure.TransportSettings.WSCorrespondentDataArea);
		
	Except
		
		Cancel = True;
		Error = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error;
		
	EndTry;

EndProcedure	

Procedure PerformTaskAdditionalRegistration(Task, Cancel, Error)
	
	If Cancel Then
		Return;
	EndIf;

	ExportAddition = Task.Parameters.Get();
	
	ObjectExportAddition = DataProcessors.InteractiveExportChange.Create();
	FillPropertyValues(ObjectExportAddition, ExportAddition, , "AdditionalRegistration, AdditionalNodeScenarioRegistration");
	
	ObjectExportAddition.AllDocumentsFilterComposer.LoadSettings(ExportAddition.AllDocumentsSettingFilterComposer);
		
	DataExchangeServer.FillValueTable(ObjectExportAddition.AdditionalRegistration, ExportAddition.AdditionalRegistration);
	DataExchangeServer.FillValueTable(ObjectExportAddition.AdditionalNodeScenarioRegistration, ExportAddition.AdditionalNodeScenarioRegistration);
	
	If Not ExportAddition.AllDocumentsComposer = Undefined Then
		ObjectExportAddition.AllDocumentsComposerAddress = PutToTempStorage(ExportAddition.AllDocumentsComposer);
	EndIf;
	
	// 
	DataExchangeServer.InteractiveExportChangeSaveSettings(ObjectExportAddition, 
		DataExchangeServer.ExportAdditionSettingsAutoSavingName());
	
	// 
	Try
		DataExchangeServer.InteractiveExportChangeRegisterAdditionalData(ObjectExportAddition);
	Except
		
		Cancel = True;
		
		Information = ErrorInfo();
		
		Error = NStr("en = 'An issue occurred while adding data to export:';") 
			+ Chars.LF + ErrorProcessing.BriefErrorDescription(Information)
			+ Chars.LF + NStr("en = 'Edit filter criteria.';");
			
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogEvent(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
			
	EndTry;
	
EndProcedure

#EndRegion

#Region NodeFormSetup

Procedure SetFuncOptionsForNode(Form, TransportSettings)
	
	SetPrivilegedMode(True);
	
	Node = Form.Object.Ref;
	TransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
	
	UseScenarios = 
		TransportKind = Enums.ExchangeMessagesTransportTypes.WS
		And ValueIsFilled(TransportSettings.WSCorrespondentEndpoint);
		
	UseConnectionSettings = 
		TransportKind = Enums.ExchangeMessagesTransportTypes.WS	
		Or TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode;
		
	RecordingSettings = InformationRegisters.CommonInfobasesNodesSettings.CreateRecordManager();
	RecordingSettings.InfobaseNode = Node;
	RecordingSettings.Read();
	
	If RecordingSettings.UseScenariosInSaaS <> UseScenarios
		Or RecordingSettings.UseConnectionsSettingsInSaaS <> UseConnectionSettings Then
		
		RecordingSettings.UseScenariosInSaaS = UseScenarios;
		RecordingSettings.UseConnectionsSettingsInSaaS = UseConnectionSettings;
		
		RecordingSettings.Write();
		
	EndIf;
		
	Form.SetFormFunctionalOptionParameters(New Structure("GeneralSettingsNodes", Node))
	
EndProcedure

Procedure SetUpFormElementsForMigrationToWS(Form, TransportSettings)
	
	Items = Form.Items;
	NodeRef1 = Form.Object.Ref;
	
	IsExchangeOverWebService = 
		TransportSettings <> Undefined
		And (TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
		Or TransportSettings.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
		
	HasExchangeAdministrationManage_3_0_1_1 = HasInNodeExchangeAdministrationManage_3_0_1_1(NodeRef1) = True;
		
	If Not Users.IsFullUser()
		Or NodeRef1.IsEmpty()
		Or	IsExchangeOverWebService
		Or Not HasExchangeAdministrationManage_3_0_1_1
		Or Not DataExchangeCached.IsXDTOExchangePlan(NodeRef1)
		Or Not DataExchangeServer.SynchronizationSetupCompleted(NodeRef1) Then
		
		CommonClientServer.SetFormItemProperty(
			Form.Items,
			"FormCommonCommandMigrationToExchangeOverInternetWizardInternalPublication",
			"Visible",
			False);
			
		Return; 
				 
	EndIf;
	
	Items = Form.Items;
	
	CommonClientServer.SetFormItemProperty(
		Form.Items,
		"FormCommonCommandMigrationToExchangeOverInternetWizardInternalPublication",
		"LocationInCommandBar",
		ButtonLocationInCommandBar.InAdditionalSubmenu);
		
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Settings.InfobaseNode AS InfobaseNode,
		|	Settings.MigrationToWebService_Step AS MigrationToWebService_Step
		|FROM
		|	InformationRegister.CommonInfobasesNodesSettings AS Settings
		|WHERE
		|	Settings.InfobaseNode = &Node";
	
	Query.SetParameter("Node", NodeRef1);
		
	Selection = Query.Execute().Select();
								
	IsMigrationToWebServiceStillInProgress = Selection.Next() And Selection.MigrationToWebService_Step > 0;
	ShouldMutePromptToMigrateToWebService = DataExchangeInternalPublicationServerCall.SettingFlagShouldMutePromptToMigrateToWebService(NodeRef1);
	PanelText = "";
	
	If IsMigrationToWebServiceStillInProgress Then
		
		PanelText = 
			NStr("en = '<br>You have not completely switched to exchange over the Internet (web service). 
                  |<br> 
                  |<br>Use the <a href=ФормаПомощникПереходаНаИнтернетВнутренняяПубликация>wizard</a> to complete the operation.';"); 
			
	ElsIf Not ShouldMutePromptToMigrateToWebService Then
												
		PanelText = 
			NStr("en = 'For this synchronization, you can configure exchange over the Internet (web service). 
                  |<br>It allows you to speed up the exchange and set up a more flexible synchronization schedule. 
                  |<br>To switch to exchange using a web service, use the <a href=ФормаПомощникПереходаНаИнтернетВнутренняяПубликация>switch to Internet connection wizard</a>.
                  |<br><br>
                  |НеПредлагатьПерейтиНаВебСервис>Do not offer to switch to a web service again</a>. You can call the wizard in the <b>More<b> menu';");
									
	EndIf;
	
	If Not IsBlankString(PanelText) Then
		
		TagName = "InfoAboutMigrationToWebService"; 
		
		Group = Items.Insert(TagName, Type("FormGroup"), Form, Items.FormCommandBar);
		Group.Kind 			= FormGroupType.UsualGroup;
		Group.Group 	= ChildFormItemsGroup.AlwaysHorizontal;
		Group.BackColor 	= WebColors.PaleGreen;
		Group.ShowTitle = False;
		
		IndentDecoration = Items.Add("Indent" + TagName, Type("FormDecoration"), Group);
		IndentDecoration.Kind = FormDecorationType.Label;
		
		PictureDecoration = Items.Add("Picture" + TagName, Type("FormDecoration"), Group);
		PictureDecoration.Kind 		= FormDecorationType.Picture;
		PictureDecoration.Picture 	= PictureLib.Information;
		PictureDecoration.Height 	= 3;
		PictureDecoration.Width 	= 5;
		PictureDecoration.PictureSize = PictureSize.Proportionally;
		
		FormattedDoc = New FormattedDocument;
		FormattedDoc.SetHTML("<html>" + PanelText + "</html>", New Structure);
		
		LabelDecoration = Items.Add("Label" + TagName, Type("FormDecoration"), Group);
		LabelDecoration.Kind 						= FormDecorationType.Label;
		LabelDecoration.AutoMaxWidth 	= False;
		LabelDecoration.HorizontalStretch 	= True;
		LabelDecoration.Title 					= FormattedDoc.GetFormattedString();
		LabelDecoration.SetAction("URLProcessing", "Attachable_URLProcessing");
	
	EndIf;
		
EndProcedure

#EndRegion

#Region Other

Function HasInNodeExchangeAdministrationManage_3_0_1_1(Node)
	
	Available = InformationRegisters.XDTODataExchangeSettings.CorrespondentSettingValue(Node, "HasExchangeAdministrationManage_3_0_1_1");
	
	Return Available = True;
		
EndFunction

Procedure ProxyInitialization(Proxy, ProxyParameters, ExchangeSettingsStructure, Cancel, Error)
	
	If Cancel Then
		Return;
	EndIf;
	
	SetupStatus = Undefined;
	DataExchangeWebService.InitializeWSProxyToManageDataExchange(Proxy, ExchangeSettingsStructure,
		ProxyParameters, Cancel, SetupStatus, Error);
	
	If Cancel Then
		DataExchangeServer.WriteEventLogDataExchange(Error, ExchangeSettingsStructure, True);
		ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Canceled;
		DataExchangeServer.WriteExchangeFinish(ExchangeSettingsStructure);
	EndIf;

EndProcedure

Function EventLogEventScenarioDisabled()
	
	Return NStr("en = 'Data exchange.Disable scenario';", Common.DefaultLanguageCode());
	
EndFunction

Function ExchangeResultCompletedWithError(ExchangeSettingsStructure, Cancel, Error)
	
	If ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Error
		Or ExchangeSettingsStructure.ExchangeExecutionResult = Enums.ExchangeExecutionResults.ErrorMessageTransport Then
		
		Cancel = True;
		Error = ExchangeSettingsStructure.ErrorMessageString;
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#EndRegion