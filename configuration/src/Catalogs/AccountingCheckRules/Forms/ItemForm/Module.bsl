///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		Raise NStr("en = 'Interactive creation is prohibited.';");
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	Items.IndividualSchedulePresentation.Enabled = Not ReadOnly;
	Items.PresentationOfCommonSchedule.Enabled          = Not ReadOnly;
	
	CurrentCheckMetadata = CheckMetadata(Object.Id);
	SetImportanceFieldAccessibility(ThisObject, CurrentCheckMetadata);
	SetPathToHandlerProcedure(ThisObject, CurrentCheckMetadata);
	
	AccountingCheckRulesSettingAllowed = AccessRight("Update", Metadata.Catalogs.AccountingCheckRules);
	Items.FormExecuteCheck.Visible              = Users.IsFullUser(, False);
	Items.FormCustomizeStandardSettings.Visible = AccountingCheckRulesSettingAllowed;
	
	SetInitialScheduleSettings();
	IsSystemAdministrator = Users.IsFullUser(, True);
	If IsSystemAdministrator Then
		GenerateSchedules();
	Else
		Items.ScheduleGroup.Visible = False;
	EndIf;
		
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not ValueIsFilled(CurrentObject.Code) Then
		CurrentObject.SetNewCode();
	EndIf;
	
	If ValueIsFilled(IndividualScheduleAddress) Then
		CurrentObject.CheckRunSchedule = GetFromTempStorage(IndividualScheduleAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	AttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IndividualSchedulePresentationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	StorageData = GetFromTempStorage(FormattedStringURL);
	If StorageData = "AddJob" Then
		ScheduleDialog1    = New ScheduledJobDialog(New JobSchedule);
		ChangeNotification = New NotifyDescription("AddJobAtClientCompletion", ThisObject);
		ScheduleDialog1.Show(ChangeNotification);
	Else
		ScheduleDialog1    = New ScheduledJobDialog(StorageData);
		ChangeNotification = New NotifyDescription("ChangeTaskOnClientCompletion", ThisObject);
		ScheduleDialog1.Show(ChangeNotification);
	EndIf;
	
EndProcedure

&AtClient
Procedure RunsInBackgroundOnScheduleOnChange(Item)
	
	If RunsInBackgroundOnSchedule Then
		SetScheduleSettingsAtServer();
	Else
		HideScheduleSettingsAtServer();
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ScheduleSelectorOnChange(Item)
	
	SetScheduleSettingsAtServer();
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExecuteCheck(Command)
	
	If Not Write() Then
		Return;
	EndIf;	
	
	If Not Object.Use Then
		CompletionNotification2 = New NotifyDescription("ExecuteCheckAfterQuestion", ThisObject);
		ShowQueryBox(CompletionNotification2, NStr("en = 'Checkup is disabled. Check anyway?';"), QuestionDialogMode.YesNo);
		Return;
	EndIf;	
	
	ExecuteCheckAfterQuestion(DialogReturnCode.Yes, Undefined);
	
EndProcedure

&AtClient
Procedure CustomizeStandardSettings(Command)
	
	QueryText = NStr("en = 'Set standard settings?';");
	Handler = New NotifyDescription("SetStandardSettingsAtClient", ThisObject);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ClearCheckResults(Command)
	ClearCheckResultsAtServer();
	Message = NStr("en = 'The results of the previous checks are successfully cleared.';");
	CommonClient.MessageToUser(Message);
EndProcedure

#EndRegion

#Region Private

&AtServer
Function RunCheckAtServer()
	
	If TimeConsumingOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Run data integrity check ""%1""';"), Object.Description);
	
	Checks = New Array;
	Checks.Add(Object.Ref);
	Return TimeConsumingOperations.ExecuteProcedure(ExecutionParameters, "AccountingAuditInternal.ExecuteChecks", Checks);
	
EndFunction

&AtClient
Procedure ExecuteCheckAfterQuestion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;	
	
	TimeConsumingOperation = RunCheckAtServer();
	
	CompletionNotification2 = New NotifyDescription("ExecuteCheckCompletion", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.MessageText = NStr("en = 'Checking. This might take a while.';");
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtClient
Procedure ExecuteCheckCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	ElsIf Result.Status = "Completed2" Then
		ShowUserNotification(NStr("en = 'Scan completed';"),,
			NStr("en = 'Data integrity check completed successfully.';"));
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateSchedules()
	
	GenerateRowWithCommonSchedule();
	GenerateRowWithIndividualSchedule();
	
EndProcedure

&AtServer
Procedure GenerateRowWithIndividualSchedule()
	
	ScheduledJobID = Object.ScheduledJobID;
	SeparateScheduledJob      = Undefined;
	SeparateScheduledJobPresentation  = "";
	
	If ValueIsFilled(ScheduledJobID) Then
		SeparateScheduledJob = ScheduledJobsServer.Job(ScheduledJobID);
		If SeparateScheduledJob <> Undefined Then
			SeparateScheduledJobPresentation = String(SeparateScheduledJob.Schedule) + ". ";
		EndIf;
	EndIf;
	
	If Not Common.DataSeparationEnabled() Then
		
		If SeparateScheduledJob = Undefined Then
			Items.IndividualSchedulePresentation.Title = 
				New FormattedString(NStr("en = 'Set schedule';"), , , , PutToTempStorage("AddJob", UUID));
		Else
			Items.IndividualSchedulePresentation.Title = 
				New FormattedString(SeparateScheduledJobPresentation, , , , PutToTempStorage(SeparateScheduledJob.Schedule, UUID));
		EndIf;
		
	Else
		
		If SeparateScheduledJob = Undefined Then
			Items.IndividualSchedulePresentation.Title = 
				New FormattedString(SeparateScheduledJobPresentation + ". ", , StyleColors.HyperlinkColor);
		Else
			Items.IndividualSchedulePresentation.Title = 
				New FormattedString(SeparateScheduledJobPresentation, , StyleColors.HyperlinkColor);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateRowWithCommonSchedule()
	
	CommonScheduledJob = ScheduledJobsServer.Job(Metadata.ScheduledJobs.AccountingCheck);
	If CommonScheduledJob <> Undefined Then
		If Not Common.DataSeparationEnabled() Then
			CommonSchedulePresentation = String(CommonScheduledJob.Schedule);
		Else
			If Users.IsFullUser(, True) Then
				CommonSchedulePresentation = String(CommonScheduledJob.Template.Schedule.Get());
			EndIf;
		EndIf;
	Else
		CommonSchedulePresentation = NStr("en = 'The scheduled job is not available';");
	EndIf;
	
	Items.PresentationOfCommonSchedule.Title = 
		New FormattedString(CommonSchedulePresentation, , StyleColors.HyperlinkColor);
	
EndProcedure

&AtClient
Procedure ChangeTaskOnClientCompletion(Schedule, AdditionalParameters) Export
	ChangeJobAtServerCompletion(Schedule, AdditionalParameters);
EndProcedure

&AtServer
Procedure ChangeJobAtServerCompletion(Schedule, AdditionalParameters)
	
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	ScheduledJob = ScheduledJobsServer.Job(Object.ScheduledJobID);
	If ScheduledJob = Undefined Then
		AddJobAtServerCompletion(Schedule, AdditionalParameters);
	Else
		
		ScheduledJobsServer.ChangeJob(Object.ScheduledJobID, New Structure("Schedule", Schedule));
		Items.IndividualSchedulePresentation.Title = 
			New FormattedString(String(Schedule), , , , PutToTempStorage(Schedule, UUID));
		
		IndividualScheduleAddress = PutToTempStorage(New ValueStorage(CommonClientServer.ScheduleToStructure(Schedule)), UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddJobAtClientCompletion(Schedule, AdditionalParameters) Export
	AddJobAtServerCompletion(Schedule, AdditionalParameters);
EndProcedure

&AtServer
Procedure AddJobAtServerCompletion(Schedule, AdditionalParameters)
		
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	JobParameters = New Structure;
	JobParameters.Insert("Schedule",    Schedule);
	JobParameters.Insert("Use", True);
	JobParameters.Insert("Metadata",    Metadata.ScheduledJobs.AccountingCheck);
	
	ScheduledJob = ScheduledJobsServer.AddJob(JobParameters);
	
	Object.ScheduledJobID = String(ScheduledJob.UUID);
	
	JobParameters = New Structure;
	
	ParametersArray = New Array;
	ParametersArray.Add(String(ScheduledJob.UUID));
	
	JobParameters.Insert("Parameters", ParametersArray);
	ScheduledJobsServer.ChangeJob(ScheduledJob.UUID, JobParameters);
	
	Items.IndividualSchedulePresentation.Title =
		New FormattedString(String(Schedule), , , , PutToTempStorage(Schedule, UUID));
		
	IndividualScheduleAddress = PutToTempStorage(New ValueStorage(CommonClientServer.ScheduleToStructure(Schedule)), UUID);
	
EndProcedure

&AtServerNoContext
Function CheckMetadata(Id)
	
	CheckStructure = New Structure;
	Checks          = AccountingAuditInternalCached.AccountingChecks().Checks;
	CheckString    = Checks.Find(Id, "Id");
	
	If CheckString = Undefined Then
		Return Undefined;
	Else
		ChecksColumns = Checks.Columns;
		For Each CurrentColumn In ChecksColumns Do
			CheckStructure.Insert(CurrentColumn.Name, CheckString[CurrentColumn.Name]);
		EndDo;
	EndIf;
	
	Return CheckStructure;
	
EndFunction

&AtServerNoContext
Procedure SetImportanceFieldAccessibility(Form, CurrentCheckMetadata)
	Form.Items.IssueSeverity.Enabled = Not (CurrentCheckMetadata <> Undefined And CurrentCheckMetadata.ImportanceChangeDenied);
EndProcedure

&AtServerNoContext
Procedure SetPathToHandlerProcedure(Form, CurrentCheckMetadata)
	Form.HandlerProcedurePath = ?(CurrentCheckMetadata = Undefined, NStr("en = 'Handler is not defined';"), CurrentCheckMetadata.HandlerChecks);
EndProcedure

&AtServer
Procedure ClearCheckResultsAtServer()
	
	RecordSet = InformationRegisters.AccountingCheckResults.CreateRecordSet();
	RecordSet.Filter.CheckRule.Set(Object.Ref);
	RecordSet.Write(True);
	
EndProcedure

&AtClient
Procedure SetStandardSettingsAtClient(Response, ExecutionParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	SetStandardSettingsAtServer();
	Modified = True;
	
EndProcedure

&AtServer
Procedure SetStandardSettingsAtServer()
	
	CurrentCheckMetadata = CheckMetadata(Object.Id);
	If CurrentCheckMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Data integrity check with ID %1 does not exist.';"), Object.Id);
	EndIf;
		
	FillPropertyValues(Object, CurrentCheckMetadata, , "Id");
	Object.AccountingCheckIsChanged = False;
	
EndProcedure

&AtServer
Procedure SetScheduleSettingsAtServer()
	
	If ScheduleSelector = 0 Then
		
		If Object.RunMethod = Enums.CheckMethod.ByCommonSchedule Then
			
			ScheduleSelector = 1;
			
			Items.ScheduleSelector.Enabled                     = True;
			Items.IndividualSchedulePresentation.Enabled = False;
			Items.PresentationOfCommonSchedule.Enabled          = True;
			
		ElsIf Object.RunMethod = Enums.CheckMethod.OnSeparateSchedule Then
			
			ScheduleSelector = 2;
			
			Items.ScheduleSelector.Enabled                     = True;
			Items.IndividualSchedulePresentation.Enabled = True;
			Items.PresentationOfCommonSchedule.Enabled          = False;
			
		EndIf;
		
	ElsIf ScheduleSelector = 1 Then
		
		Object.RunMethod = Enums.CheckMethod.ByCommonSchedule;
		Items.ScheduleSelector.Enabled                     = True;
		Items.IndividualSchedulePresentation.Enabled = False;
		Items.PresentationOfCommonSchedule.Enabled          = True;
		
	ElsIf ScheduleSelector = 2 Then
		
		Object.RunMethod = Enums.CheckMethod.OnSeparateSchedule;
		Items.ScheduleSelector.Enabled                     = True;
		Items.IndividualSchedulePresentation.Enabled = True;
		Items.PresentationOfCommonSchedule.Enabled          = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure HideScheduleSettingsAtServer()
	
	Object.RunMethod = Enums.CheckMethod.Manually;
	Items.ScheduleSelector.Enabled                     = False;
	Items.IndividualSchedulePresentation.Enabled = False;
	Items.PresentationOfCommonSchedule.Enabled          = False;
	
EndProcedure

&AtServer
Procedure SetInitialScheduleSettings()
	
	If Object.RunMethod = Enums.CheckMethod.ByCommonSchedule Then
		
		RunsInBackgroundOnSchedule = True;
		ScheduleSelector           = 1;
		
		Items.ScheduleSelector.Enabled                     = True;
		Items.IndividualSchedulePresentation.Enabled = False;
		Items.PresentationOfCommonSchedule.Enabled          = True;
		
	ElsIf Object.RunMethod = Enums.CheckMethod.OnSeparateSchedule Then
		
		RunsInBackgroundOnSchedule = True;
		ScheduleSelector           = 2;
		
		Items.ScheduleSelector.Enabled                     = True;
		Items.IndividualSchedulePresentation.Enabled = True;
		Items.PresentationOfCommonSchedule.Enabled          = False;
		
	Else
		
		RunsInBackgroundOnSchedule = False;
		ScheduleSelector           = 1;
		
		Items.ScheduleSelector.Enabled                     = False;
		Items.IndividualSchedulePresentation.Enabled = False;
		Items.PresentationOfCommonSchedule.Enabled          = False
		
	EndIf;
	
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion