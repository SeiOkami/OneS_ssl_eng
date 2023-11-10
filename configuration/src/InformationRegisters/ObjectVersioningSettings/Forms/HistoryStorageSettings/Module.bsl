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
	
	FillObjectTypesInValueTree();
	FillChoiceLists();
	
	Items.Clear.Visible = False;
	Items.Schedule.Title = CurrentSchedule();
	DeleteObsoleteVersionsAutomatically = AutomaticClearingEnabled();
	Items.Schedule.Enabled = DeleteObsoleteVersionsAutomatically;
	Items.SetUpSchedule.Enabled = DeleteObsoleteVersionsAutomatically;
	Items.ObsoleteVersionsInformation.Title = StatusTextCalculation();
	
	ShowCleanupScheduleSetting = Not Common.DataSeparationEnabled();
	Items.Schedule.Visible = ShowCleanupScheduleSetting;
	Items.SetUpSchedule.Visible = ShowCleanupScheduleSetting;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateObsoleteVersionsInfo();
EndProcedure

#EndRegion

#Region MetadataObjectsTreeFormTableItemEventHandlers

&AtClient
Procedure MetadataObjectsTreeBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() = Undefined Then
		Cancel = True;
	EndIf;
	
	If Item.CurrentItem = Items.VersioningMode Then
		FillChoiceList(Items.MetadataObjectsTree.CurrentItem);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingOnChange(Item)
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	SaveCurrentObjectSettings(CurrentData.ObjectType, CurrentData.VersioningMode, CurrentData.VersionLifetime);
	UpdateObsoleteVersionsInfo();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetVersioningOptionDontVersionize(Command)
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectsVersioningOptions.DontVersionize"));	
	
EndProcedure

&AtClient
Procedure SetVersioningModeOnWrite(Command)
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectsVersioningOptions.VersionizeOnWrite"));	
	
EndProcedure

&AtClient
Procedure SetVersioningOptionOnPost(Command)
	
	If DocumentsThatCannotBePostedSelected() Then
		ShowMessageBox(, NStr("en = 'Documents that cannot be posted are applied with the ""on write"" versioning mode.';"));
	EndIf;
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectsVersioningOptions.VersionizeOnPost"));	
	
EndProcedure

&AtClient
Procedure ApplyDefaultSettings(Command)
	
	SetSelectedRowsVersioningMode(Undefined);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillObjectTypesInValueTree();
	UpdateObsoleteVersionsInfo();
	For Each Item In MetadataObjectsTree.GetItems() Do
		Items.MetadataObjectsTree.Expand(Item.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure Clear(Command)
	CancelBackgroundJob1();
	RunScheduledJob();
	StartUpdateObsoleteVersionsInformation();
	AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
EndProcedure

&AtClient
Procedure LastWeek(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.LastWeek"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure LastMonth(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.LastMonth"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure LastThreeMonths(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.LastThreeMonths"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure LastSixMonths(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.LastSixMonths"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure LastYear(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.LastYear"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure Indefinitely(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionsLifetimes.Indefinitely"));
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtClient
Procedure VersionizeOnStart(Command)
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectsVersioningOptions.VersionizeOnStart"));
EndProcedure

&AtClient
Procedure SetUpSchedule(Command)
	ScheduleDialog1 = New ScheduledJobDialog(CurrentSchedule());
	NotifyDescription = New NotifyDescription("SetUpScheduleCompletion", ThisObject);
	ScheduleDialog1.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure StoredObjectsVersionsCountAndSize(Command)
	OpenForm("Report.ObjectVersionsAnalysis.ObjectForm");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillChoiceList(Item)
	
	TreeRow = Items.MetadataObjectsTree.CurrentData;
	
	Item.ChoiceList.Clear();
	
	If TreeRow.ObjectClass = "DocumentsClass" And TreeRow.BeingPosted Then
		ChoiceList = SelectionListDocuments;
	ElsIf TreeRow.ObjectClass = "BusinessProcessesClass" Then
		ChoiceList = SelectionListBusinessProcesses;
	Else
		ChoiceList = SelectionListCatalogs;
	EndIf;
	
	For Each ListItem In ChoiceList Do
		Item.ChoiceList.Add(ListItem.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillObjectTypesInValueTree()
	
	VersioningSettings = CurrentVersioningSettings();
	
	MOTree = FormAttributeToValue("MetadataObjectsTree");
	MOTree.Rows.Clear();
	
	//  
	// 
	TypesArray = Metadata.CommonCommands.ChangeHistory.CommandParameterType.Types();
	HasBusinessProcesses = False;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	CatalogsNode = Undefined;
	DocumentsNode = Undefined;
	BusinessProcessesNode = Undefined;
	
	For Each Type In TypesArray Do
		If Type = Type("CatalogRef.MetadataObjectIDs") Then
			Continue;
		EndIf;
		If AllCatalogs.ContainsType(Type) Then
			If CatalogsNode = Undefined Then
				CatalogsNode = MOTree.Rows.Add();
				CatalogsNode.ObjectDescriptionSynonym = NStr("en = 'Catalogs';");
				CatalogsNode.ObjectClass = "01ClassReferencesRoot";
				CatalogsNode.PictureCode = 2;
			EndIf;
			NewTableRow = CatalogsNode.Rows.Add();
			NewTableRow.PictureCode = 19;
			NewTableRow.ObjectClass = "CatalogsClass";
		ElsIf AllDocuments.ContainsType(Type) Then
			If DocumentsNode = Undefined Then
				DocumentsNode = MOTree.Rows.Add();
				DocumentsNode.ObjectDescriptionSynonym = NStr("en = 'Documents';");
				DocumentsNode.ObjectClass = "02ClassDocumentsRoot";
				DocumentsNode.PictureCode = 3;
			EndIf;
			NewTableRow = DocumentsNode.Rows.Add();
			NewTableRow.PictureCode = 20;
			NewTableRow.ObjectClass = "DocumentsClass";
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			If BusinessProcessesNode = Undefined Then
				BusinessProcessesNode = MOTree.Rows.Add();
				BusinessProcessesNode.ObjectDescriptionSynonym = NStr("en = 'Business processes';");
				BusinessProcessesNode.ObjectClass = "03BusinessProcessesRoot";
				BusinessProcessesNode.ObjectType = "BusinessProcesses";
			EndIf;
			NewTableRow = BusinessProcessesNode.Rows.Add();
			NewTableRow.ObjectClass = "BusinessProcessesClass";
			HasBusinessProcesses = True;
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			GroupName = "04ChartsAccountsRoot";
			GroupPresentation = NStr("en = 'Charts of accounts';");
			GroupObjectsType = "ChartsOfAccounts";
			Var_Group = MOTree.Rows.Find(GroupName, "ObjectClass");
			If Var_Group = Undefined Then
				Var_Group = MOTree.Rows.Add();
				Var_Group.ObjectDescriptionSynonym = GroupPresentation;
				Var_Group.ObjectClass = GroupName;
				Var_Group.ObjectType = GroupObjectsType;
			EndIf;
			NewTableRow = Var_Group.Rows.Add();
			NewTableRow.ObjectClass = "ChartsOfAccountsClass";
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			GroupName = "05PlansViewsCharacteristicsRoot";
			GroupPresentation = NStr("en = 'Charts of characteristic types';");
			GroupObjectsType = "ChartsOfCharacteristicTypes";
			Var_Group = MOTree.Rows.Find(GroupName, "ObjectClass");
			If Var_Group = Undefined Then
				Var_Group = MOTree.Rows.Add();
				Var_Group.ObjectDescriptionSynonym = GroupPresentation;
				Var_Group.ObjectClass = GroupName;
				Var_Group.ObjectType = GroupObjectsType;
			EndIf;
			NewTableRow = Var_Group.Rows.Add();
			NewTableRow.ObjectClass = "ChartsOfCharacteristicTypesClass";
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			GroupName = "06PlansCalculationTypesRoot";
			GroupPresentation = NStr("en = 'Charts of calculation types';");
			GroupObjectsType = "ChartsOfCalculationTypes";
			Var_Group = MOTree.Rows.Find(GroupName, "ObjectClass");
			If Var_Group = Undefined Then
				Var_Group = MOTree.Rows.Add();
				Var_Group.ObjectDescriptionSynonym = GroupPresentation;
				Var_Group.ObjectClass = GroupName;
				Var_Group.ObjectType = GroupObjectsType;
			EndIf;
			NewTableRow = Var_Group.Rows.Add();
			NewTableRow.ObjectClass = "ClassPlansOfCalculationTypes";
		EndIf;
		ObjectMetadata = Metadata.FindByType(Type);
		NewTableRow.ObjectType = Common.MetadataObjectID(Type);
		NewTableRow.ObjectDescriptionSynonym = ObjectMetadata.Synonym;
		
		FoundSettings = VersioningSettings.FindRows(New Structure("ObjectType", NewTableRow.ObjectType));
		If FoundSettings.Count() > 0 Then
			NewTableRow.VersioningMode = FoundSettings[0].VersioningMode;
			NewTableRow.VersionLifetime = FoundSettings[0].VersionLifetime;
			If Not ValueIsFilled(FoundSettings[0].VersionLifetime) Then
				NewTableRow.VersionLifetime = Enums.VersionsLifetimes.Indefinitely;
			EndIf;
		Else
			NewTableRow.VersioningMode = Enums.ObjectsVersioningOptions.DontVersionize;
			NewTableRow.VersionLifetime = Enums.VersionsLifetimes.Indefinitely;
		EndIf;
		
		If NewTableRow.ObjectClass = "DocumentsClass" Then
			NewTableRow.BeingPosted = ? (ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow, True, False);
		EndIf;
	EndDo;
	MOTree.Rows.Sort("ObjectClass");
	For Each TopLevelNode In MOTree.Rows Do
		TopLevelNode.Rows.Sort("ObjectDescriptionSynonym");
	EndDo;
	ValueToFormAttribute(MOTree, "MetadataObjectsTree");
	
	Items.FormVersionizeOnStart.Visible = HasBusinessProcesses;
EndProcedure

&AtClient
Function DocumentsThatCannotBePostedSelected()
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.ObjectClass = "DocumentsClass" And Not TreeItem.BeingPosted Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure SetSelectedRowsVersioningMode(Val VersioningMode)
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then 
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetTreeItemVersioningMode(TreeChildItem, VersioningMode);
			EndDo;
		Else
			SetTreeItemVersioningMode(TreeItem, VersioningMode);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTreeItemVersioningMode(TreeItem, Val VersioningMode)
	
	If VersioningMode = Undefined Then
		If TreeItem.ObjectClass = "DocumentsClass" Then
			VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnPost;
		ElsIf TreeItem.GetParent().ObjectType = "BusinessProcesses" Then
			VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnStart;
		Else
			VersioningMode = Enums.ObjectsVersioningOptions.DontVersionize;
		EndIf;
	EndIf;
	
	If VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnPost
		And Not TreeItem.BeingPosted 
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnStart
		And TreeItem.ObjectClass <> "BusinessProcessesClass" Then
			VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnWrite;
	EndIf;
	
	TreeItem.VersioningMode = VersioningMode;
	
	SaveCurrentObjectSettings(TreeItem.ObjectType, VersioningMode, TreeItem.VersionLifetime);
	
EndProcedure

&AtServer
Procedure SetSelectedObjectsVersionStoringDuration(VersionLifetime)
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetSelectedObjectVersionStoringDuration(TreeChildItem, VersionLifetime);
			EndDo;
		Else
			SetSelectedObjectVersionStoringDuration(TreeItem, VersionLifetime);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetSelectedObjectVersionStoringDuration(SelectedObject, VersionLifetime)
	
	SelectedObject.VersionLifetime = VersionLifetime;
	SaveCurrentObjectSettings(SelectedObject.ObjectType, SelectedObject.VersioningMode, VersionLifetime);
	
EndProcedure

&AtServer
Procedure SaveCurrentObjectSettings(ObjectType, VersioningMode, VersionLifetime)
	ObjectsVersioning.SaveObjectVersioningConfiguration(ObjectType, VersioningMode, VersionLifetime);
EndProcedure

&AtServer
Function CurrentVersioningSettings()
	SetPrivilegedMode(True);
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType AS ObjectType,
	|	ObjectVersioningSettings.Variant AS VersioningMode,
	|	ObjectVersioningSettings.VersionLifetime AS VersionLifetime
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings";
	Query = New Query(QueryText);
	Return Query.Execute().Unload();
EndFunction

&AtClient
Procedure SetUpScheduleCompletion(Schedule, AdditionalParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	SetScheduledJobParameter("Schedule", Schedule);
	Items.Schedule.Title = Schedule;
EndProcedure

&AtServer
Function CurrentSchedule()
	Return GetScheduledJobParameter("Schedule", New JobSchedule);
EndFunction

&AtClient
Procedure DeleteObsoleteVersionsAutomaticallyOnChange(Item)
	SetScheduledJobParameter("Use", DeleteObsoleteVersionsAutomatically);
	Items.Schedule.Enabled = DeleteObsoleteVersionsAutomatically;
	Items.SetUpSchedule.Enabled = DeleteObsoleteVersionsAutomatically;
EndProcedure

&AtServer
Procedure SetScheduledJobParameter(ParameterName, ParameterValue)
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	If JobsList.Count() = 0 Then
		JobParameters = New Structure;
		JobParameters.Insert(ParameterName, ParameterValue);
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure(ParameterName, ParameterValue);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;
EndProcedure

&AtServer
Function GetScheduledJobParameter(ParameterName, DefaultValue)
	JobParameters = New Structure;
	If Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.ClearingObsoleteObjectVersions.MethodName);
	Else
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	For Each Job In JobsList Do
		Return Job[ParameterName];
	EndDo;
	
	Return DefaultValue;
EndFunction

&AtClient
Procedure CheckBackgroundJobExecution()
	If ValueIsFilled(BackgroundJobIdentifier) And Not JobCompleted(BackgroundJobIdentifier) Then
		AttachIdleHandler("CheckBackgroundJobExecution", 5, True);
	Else
		BackgroundJobIdentifier = "";
		If CurrentBackgroundJob = "Calculation1" Then
			OutputObsoleteVersionsInfo();
			Return;
		EndIf;
		CurrentBackgroundJob = "";
		UpdateObsoleteVersionsInfo();
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobIdentifier)
	Return TimeConsumingOperations.JobCompleted(BackgroundJobIdentifier);
EndFunction

&AtServerNoContext
Procedure CancelJobExecution(BackgroundJobIdentifier)
	If ValueIsFilled(BackgroundJobIdentifier) Then 
		TimeConsumingOperations.CancelJobExecution(BackgroundJobIdentifier);
	EndIf;
EndProcedure

&AtServer
Procedure RunScheduledJob()
	
	ScheduledJobMetadata1 = Metadata.ScheduledJobs.ClearingObsoleteObjectVersions;
	
	Filter = New Structure;
	MethodName = ScheduledJobMetadata1.MethodName;
	Filter.Insert("MethodName", MethodName);
	
	Filter.Insert("State", BackgroundJobState.Active);
	CleanupBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If CleanupBackgroundJobs.Count() > 0 Then
		BackgroundJobIdentifier = CleanupBackgroundJobs[0].UUID;
	Else
		JobParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		JobParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Manual start: %1';"), ScheduledJobMetadata1.Synonym);
		JobResult = TimeConsumingOperations.ExecuteProcedure(JobParameters, ScheduledJobMetadata1.MethodName);
		If ValueIsFilled(JobResult.JobID) Then
			BackgroundJobIdentifier = JobResult.JobID;
		EndIf;
	EndIf;
	
	CurrentBackgroundJob = "Clearing";
	
EndProcedure

&AtClient
Procedure UpdateObsoleteVersionsInfo()
	DetachIdleHandler("StartUpdateObsoleteVersionsInformation");
	If CurrentBackgroundJob = "Calculation1" And ValueIsFilled(BackgroundJobIdentifier) Then
		CancelBackgroundJob1();
	EndIf;
	AttachIdleHandler("StartUpdateObsoleteVersionsInformation", 2, True);
EndProcedure

&AtClient
Procedure CancelBackgroundJob1()
	CancelJobExecution(BackgroundJobIdentifier);
	DetachIdleHandler("CheckBackgroundJobExecution");
	CurrentBackgroundJob = "";
	BackgroundJobIdentifier = "";
EndProcedure

&AtClient
Procedure StartUpdateObsoleteVersionsInformation()
	
	Items.Clear.Visible = CurrentBackgroundJob <> "Clearing";
	If ValueIsFilled(BackgroundJobIdentifier) Then
		If CurrentBackgroundJob = "Calculation1" Then
			Items.ObsoleteVersionsInformation.Title = StatusTextCalculation();
		Else
			Items.ObsoleteVersionsInformation.Title = StatusTextCleanup();
		EndIf;
		Return;
	EndIf;
	
	Items.ObsoleteVersionsInformation.Title = StatusTextCalculation();
	TimeConsumingOperation = SerachForObsoleteVersions();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	
	NotifyDescription = New NotifyDescription("OnCompleteSearchForObsoleteVersions", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	
EndProcedure

&AtClient
Procedure OnCompleteSearchForObsoleteVersions(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		EventLogClient.AddMessageForEventLog(NStr("en = 'Search for outdated versions';", CommonClient.DefaultLanguageCode()),
			"Error", Result.DetailErrorDescription, , True);
		Raise Result.BriefErrorDescription;
	EndIf;

	BackgroundJobIdentifier = "";
	OutputObsoleteVersionsInfo();
	
EndProcedure

&AtClientAtServerNoContext
Function StatusTextCalculation()
	Return NStr("en = 'Searching for outdated versions…';");
EndFunction

&AtClientAtServerNoContext
Function StatusTextCleanup()
	Return NStr("en = 'Cleaning up outdated versions…';");
EndFunction

&AtServer
Function SerachForObsoleteVersions()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Search for outdated versions';");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteFunction(ExecutionParameters,
		"ObjectsVersioning.ObsoleteVersionsInformation");
	
	CurrentBackgroundJob = "Calculation1";
	BackgroundJobIdentifier = TimeConsumingOperation.JobID;
	ResultAddress = TimeConsumingOperation.ResultAddress;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtClient
Procedure OutputObsoleteVersionsInfo()
	
	ObsoleteVersionsInformation = GetFromTempStorage(ResultAddress);
	If ObsoleteVersionsInformation = Undefined Then
		Return;
	EndIf;
	
	Items.Clear.Visible = ObsoleteVersionsInformation.DataSize > 0;
	If ObsoleteVersionsInformation.DataSize > 0 Then
		Items.ObsoleteVersionsInformation.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Total outdated versions: %1 (%2)';"),
			ObsoleteVersionsInformation.VersionsCount,
			ObsoleteVersionsInformation.DataSizeString);
	Else
		Items.ObsoleteVersionsInformation.Title = NStr("en = 'Total outdated versions: none';");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillChoiceLists()
	
	SelectionListCatalogs = New ValueList;
	SelectionListCatalogs.Add(Enums.ObjectsVersioningOptions.VersionizeOnWrite);
	SelectionListCatalogs.Add(Enums.ObjectsVersioningOptions.DontVersionize);
	
	SelectionListDocuments = New ValueList;
	SelectionListDocuments.Add(Enums.ObjectsVersioningOptions.VersionizeOnWrite);
	SelectionListDocuments.Add(Enums.ObjectsVersioningOptions.VersionizeOnPost);
	SelectionListDocuments.Add(Enums.ObjectsVersioningOptions.DontVersionize);
	
	SelectionListBusinessProcesses = New ValueList;
	SelectionListBusinessProcesses.Add(Enums.ObjectsVersioningOptions.VersionizeOnWrite);
	SelectionListBusinessProcesses.Add(Enums.ObjectsVersioningOptions.VersionizeOnStart);
	SelectionListBusinessProcesses.Add(Enums.ObjectsVersioningOptions.DontVersionize);
	
EndProcedure

&AtServer
Function AutomaticClearingEnabled()
	Return GetScheduledJobParameter("Use", False);
EndFunction

#EndRegion
