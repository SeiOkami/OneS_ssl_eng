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
	
	SetConditionalAppearance();
	
	CheckDataSynchronizationSettingPossibility(Cancel);
	If Cancel Then
		
		Return;
		
	EndIf;
	
	URL							= "e1cib/app/CommonForm.DataSyncSettings";
	HasRightsToAdministerExchanges			= DataExchangeServer.HasRightsToAdministerExchanges();
	HasViewEventLogRights		= AccessRight("EventLog", Metadata);
	HasConfigurationUpdateRights = AccessRight("UpdateDataBaseConfiguration", Metadata);
	IBPrefix									= DataExchangeServer.InfobasePrefix();
	SaaSModel								= Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable();
	
	TheVersioningSubsystemExists = Common.SubsystemExists("StandardSubsystems.ObjectsVersioning");
	
	ValuesCache = New Structure;
	ValuesCache.Insert("TheVersioningSubsystemExists", TheVersioningSubsystemExists);
	ValuesCache.Insert("RejectedConflictData", Undefined);
	ValuesCache.Insert("ConflictDataAccepted", Undefined);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase", Undefined);
	ValuesCache.Insert("RejectedDueToPeriodEndClosingDateObjectExistsInInfobase", Undefined);
	
	If TheVersioningSubsystemExists Then
		
		EnumManager = Enums["ObjectVersionTypes"];
		ValuesCache.RejectedConflictData = EnumManager.RejectedConflictData;
		ValuesCache.ConflictDataAccepted = EnumManager.ConflictDataAccepted;
		ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase = EnumManager.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
		ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase = EnumManager.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
		
	EndIf;
	
	SetFormItemsView();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateMonitorDataInteractively();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "DataExchangeCompleted"
		Or EventName = "Write_DataExchangeScenarios"
		Or EventName = "Write_ExchangePlanNode"
		Or EventName = "ObjectMappingWizardFormClosed"
		Or EventName = "DataExchangeResultFormClosed"
		Or EventName = "FormMigrationToExchangeOverInternetWizardClosed" Then
		
		UpdateMonitorDataInBackground();
		
	ElsIf EventName = "DataExchangeCreationWizardFormClosed" Then
		
		UpdateMonitorDataInteractively();
		
	ElsIf EventName = "ConstantsSet.DistributedInfobaseNodePrefix" Then
		
		IBPrefix = Parameter;
				
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ApplicationsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Field.Name = "ApplicationsListExportStatePicture"
		Or Field.Name = "ApplicationsListLastSuccessfulExportDatePresentation"
		Or Field.Name = "ApplicationsListSendingAWarning"
		Then
		
		RunACommandWithAPreliminaryCheck("OpenTheResultsOfSynchronizationOfTheUploadEvent");
		
	ElsIf Field.Name = "ApplicationsListImportStatePicture"
		Or Field.Name = "ApplicationsListLastSuccessfulImportDatePresentation"
		Or Field.Name = "ApplicationsListGettingAWarning"
		Then
		
		RunACommandWithAPreliminaryCheck("OpenTheResultsOfSynchronizationOfTheDownloadEvent");
		
	ElsIf Field.Name = "ApplicationsListCanMigrateToWS" Then
		
		CurrentData = Items.ApplicationsList.CurrentData;
		
		If CurrentData.CanMigrateToWS Then
		
			FormParameters = New Structure("ExchangeNode", CurrentData.InfobaseNode);
			OpenForm("DataProcessor.DataExchangeCreationWizard.Form.MigrationToExchangeOverInternet", 
				FormParameters, ThisForm,,,,, FormWindowOpeningMode.LockOwnerWindow);
				
		EndIf;
		
	Else
		
		RunACommandWithAPreliminaryCheck("ChangeSynchronizationSettings");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunSync(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure RunSyncWithAdditionalFilters(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure ChangeSynchronizationSettings(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure DataToSendComposition(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure ConfigureDataExchangeScenarios(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure DeleteSynchronizationSetting(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure ImportDataSyncRules(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure InitialDataExport(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure NewPredefinedNodeCode(Command)
	
	List = ExchangePlansWithIDSupport();
	
	If List.Count() = 0 Then
		
		ShowMessageBox(,NStr("en = 'No exchange plans available to set a new code';"));
				
	ElsIf List.Count() = 1 Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ExchangePlanName", List[0].Value);
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.NewPredefinedNodeCode",
			FormParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
			
	Else
		
		NotificationProcessing = New NotifyDescription("NewPredefinedNodeCodeCompletion", ThisObject);
		List.ShowChooseItem(NotificationProcessing, NStr("en = 'Select an exchange plan';"))	
	
	EndIf;
			
EndProcedure

&AtServer
Function ExchangePlansWithIDSupport()
	
	Result = New ValueList;
	
	For Each ExchangePlanName In DataExchangeCached.SSLExchangePlans() Do
		
		Node = ExchangePlans[ExchangePlanName].ThisNode();
		
		If DataExchangeServer.IsXDTOExchangePlan(Node)
			And DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(Node) Then
			
			Result.Add(ExchangePlanName, Metadata.ExchangePlans[ExchangePlanName]);
			
		EndIf;	
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure NewPredefinedNodeCodeCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlanName", Result.Value);

	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.NewPredefinedNodeCode",
		FormParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);

EndProcedure	

&AtClient
Procedure PreviousWarningsForm(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	RunACommandWithAPreliminaryCheck(Command.Name);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	DataExchangeClient.InstallConfigurationUpdate();
	
EndProcedure

#Region CommandsThatDoNotRequireCheckingForRelevance

&AtClient
Procedure RefreshScreen(Command)
	
	UpdateMonitorDataInteractively();
	
EndProcedure

&AtClient
Procedure CreateSyncSetting(Command)
	
	DataExchangeClient.OpenNewDataSynchronizationSettingForm(NewDataSynchronizationForm, NewDataSyncFormParameters);
	
EndProcedure

&AtClient
Procedure ChangeIBPrefix(Command)
	
	FormParameters = New Structure("Prefix", IBPrefix);
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.ChangeInfobaseNodePrefix",FormParameters,,,,,, 
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region ExecutingCommands

&AtClient
Procedure SynchronizationExecutionCommandProcessing(CurrentData, UseAddlFilters = False)
	Var DataToCompleteSetup;
	
	DescriptionOfTheApplicationString = New Structure;
	DescriptionOfTheApplicationString.Insert("InfobaseNode",			CurrentData.InfobaseNode);
	DescriptionOfTheApplicationString.Insert("ExchangePlanName",					CurrentData.ExchangePlanName);
	DescriptionOfTheApplicationString.Insert("CorrespondentVersion",			CurrentData.CorrespondentVersion);
	DescriptionOfTheApplicationString.Insert("ExternalSystem",					CurrentData.ExternalSystem);
	DescriptionOfTheApplicationString.Insert("CorrespondentDataArea",	CurrentData.DataArea);
	DescriptionOfTheApplicationString.Insert("IsExchangeWithApplicationInService",	CurrentData.IsExchangeWithApplicationInService);
	DescriptionOfTheApplicationString.Insert("StartDataExchangeFromCorrespondent",	CurrentData.StartDataExchangeFromCorrespondent);
	DescriptionOfTheApplicationString.Insert("InteractiveSendingAvailable",	CurrentData.InteractiveSendingAvailable);
	DescriptionOfTheApplicationString.Insert("DataExchangeOption",			CurrentData.DataExchangeOption);
	DescriptionOfTheApplicationString.Insert("UseAddlFilters",			UseAddlFilters);
	DescriptionOfTheApplicationString.Insert("ThisIsTheInitialUpload",			False);
	DescriptionOfTheApplicationString.Insert("ErrorDescription",					Undefined);
	
	ChecksResults = ServerChecksBeforeExecutingCommands(DescriptionOfTheApplicationString, DataToCompleteSetup, "Maximum");
	DescriptionOfTheApplicationString.Insert("MessageReceivedForDataMapping", ChecksResults.AMessageForMatchingWasReceived); 
	
	If ChecksResults.ContinueNewSynchronizationSetup Then
		
		FinishSettingUpSynchronizationInTheDialog(DescriptionOfTheApplicationString, DataToCompleteSetup);
		
	ElsIf DescriptionOfTheApplicationString.StartDataExchangeFromCorrespondent
		And Not ChecksResults.AMessageForMatchingWasReceived Then
		
		WarningTex = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Starting synchronization with %1 from this application is not supported.
				 |Please open %1 and start the synchronization from there.';", CommonClient.DefaultLanguageCode()),
			CurrentData.CorrespondentDescription);
			
			ShowMessageBox(,WarningTex);
		
	ElsIf Not DescriptionOfTheApplicationString.IsExchangeWithApplicationInService
		And Not ChecksResults.TheConversionRulesAreCompatible Then
		
		UserDialogWithIncompatibleRules(DescriptionOfTheApplicationString, ChecksResults.ErrorDescription);
		
	Else
		
		DataSynchronization(DescriptionOfTheApplicationString);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenSynchronizationParametersSettingForm(CurrentData)
	Var DataToCompleteSetup;
	
	DescriptionOfTheApplicationString = New Structure;
	DescriptionOfTheApplicationString.Insert("InfobaseNode",			CurrentData.InfobaseNode);
	DescriptionOfTheApplicationString.Insert("ExchangePlanName",					CurrentData.ExchangePlanName);
	DescriptionOfTheApplicationString.Insert("CorrespondentVersion",			CurrentData.CorrespondentVersion);
	DescriptionOfTheApplicationString.Insert("ExternalSystem",					CurrentData.ExternalSystem);
	DescriptionOfTheApplicationString.Insert("CorrespondentDataArea",	CurrentData.DataArea);
	DescriptionOfTheApplicationString.Insert("IsExchangeWithApplicationInService",	CurrentData.IsExchangeWithApplicationInService);
	DescriptionOfTheApplicationString.Insert("ThisIsTheInitialUpload",			True);
	
	ChecksResults = ServerChecksBeforeExecutingCommands(DescriptionOfTheApplicationString, DataToCompleteSetup, "Minimum");
	If ChecksResults.ContinueNewSynchronizationSetup Then
		
		OpenNewSynchronizationSetupWizardForm(DescriptionOfTheApplicationString, DataToCompleteSetup);
		
	Else
		
		WizardParameters = New Structure;
		WizardParameters.Insert("Key", DescriptionOfTheApplicationString.InfobaseNode);
		
		ClosingNotification1 = New NotifyDescription("AfterTheSynchronizationSettingsAreCompleted", ThisObject);
		
		NameOfFormToOpen_ = StrTemplate("ExchangePlan.%1.ObjectForm", DescriptionOfTheApplicationString.ExchangePlanName);
		OpenForm(NameOfFormToOpen_, WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterTheSynchronizationSettingsAreCompleted(ClosingResult, AdditionalParameters) Export
	
	AttachIdleHandler("UpdateMonitorDataInteractively", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenTheSynchronizationResults(CurrentRowData = Undefined, NameOfTheEventSet = "")
	
	ArrayOfExchangePlanNodes = New Array;
	For Each MonitorRow In ApplicationsList Do
		
		ArrayOfExchangePlanNodes.Add(MonitorRow.InfobaseNode);
		
	EndDo;
	
	SelectionOfExchangePlanNodes = New Array;
	If CurrentRowData <> Undefined Then
		
		SelectionOfExchangePlanNodes.Add(CurrentRowData.InfobaseNode);
		
	EndIf;
	
	SelectingTypesOfWarnings = New Array;
	If IsBlankString(NameOfTheEventSet)
		Or NameOfTheEventSet = "UploadEvents" Then
		
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.ApplicationAdministrativeError"));
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.ConvertedObjectValidationError"));
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnSendData"));
		
	EndIf;
	
	If IsBlankString(NameOfTheEventSet)
		Or NameOfTheEventSet = "DownloadEvents" Then
		
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.UnpostedDocument"));
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.BlankAttributes"));
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.HandlersCodeExecutionErrorOnGetData"));
		SelectingTypesOfWarnings.Add(PredefinedValue("Enum.DataExchangeIssuesTypes.IsExchangeMessageOutsideOfArchive"));
		
		If ValuesCache.TheVersioningSubsystemExists Then
			
			SelectingTypesOfWarnings.Add(ValuesCache.RejectedConflictData);
			SelectingTypesOfWarnings.Add(ValuesCache.ConflictDataAccepted);
			SelectingTypesOfWarnings.Add(ValuesCache.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
			SelectingTypesOfWarnings.Add(ValuesCache.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
			
		EndIf;
		
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ExchangeNodes", ArrayOfExchangePlanNodes);
	FormParameters.Insert("SelectionOfExchangeNodes", SelectionOfExchangePlanNodes);
	FormParameters.Insert("SelectingTypesOfWarnings", SelectingTypesOfWarnings);
	
	NotifyDescription = New NotifyDescription("AfterOpeningTheWarningsForm", ThisObject);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.SynchronizationWarnings", FormParameters, ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterOpeningTheWarningsForm(Result, AdditionalParameters) Export
	
	UpdateMonitorDataInteractively();
	
EndProcedure

&AtClient
Procedure DeleteTheSynchronizationSettings(CurrentData)
	
	If CurrentData.IsExchangeWithApplicationInService 
		And CurrentData.SynchronizationSetupInServiceManager Then
			
		ShowMessageBox(, NStr("en = 'To delete data synchronization settings, go to your cloud application personal account and
			| click ""Data synchronization"".';"));
		
	Else
		
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangeNode",                   CurrentData.InfobaseNode);
		WizardParameters.Insert("ExchangePlanName",               CurrentData.ExchangePlanName);
		WizardParameters.Insert("CorrespondentDataArea",  CurrentData.DataArea);
		WizardParameters.Insert("CorrespondentDescription",   CurrentData.CorrespondentDescription);
		WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		
		NameOfFormToOpen_ = "DataProcessor.DataExchangeCreationWizard.Form.DeleteSyncSetting";
		OpenForm(NameOfFormToOpen_, WizardParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadDataSynchronizationRules(CurrentData)
	
	If CurrentData.ConversionRulesAreUsed Then
		
		DataExchangeClient.ImportDataSyncRules(CurrentData.ExchangePlanName);
		
	Else
		
		RulesKind = PredefinedValue("Enum.DataExchangeRulesTypes.ObjectsRegistrationRules");
		
		Filter              = New Structure("ExchangePlanName, RulesKind", CurrentData.ExchangePlanName, RulesKind);
		FillingValues = New Structure("ExchangePlanName, RulesKind", CurrentData.ExchangePlanName, RulesKind);
		
		DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", 
			CurrentData.InfobaseNode, "ObjectsRegistrationRules");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteInitialDataExport(CurrentData)
	Var DataToCompleteSetup;
	
	DescriptionOfTheApplicationString = New Structure;
	DescriptionOfTheApplicationString.Insert("InfobaseNode",			CurrentData.InfobaseNode);
	DescriptionOfTheApplicationString.Insert("ExchangePlanName",					CurrentData.ExchangePlanName);
	DescriptionOfTheApplicationString.Insert("CorrespondentVersion",			CurrentData.CorrespondentVersion);
	DescriptionOfTheApplicationString.Insert("ExternalSystem",					CurrentData.ExternalSystem);
	DescriptionOfTheApplicationString.Insert("CorrespondentDataArea",	CurrentData.DataArea);
	DescriptionOfTheApplicationString.Insert("IsExchangeWithApplicationInService",	CurrentData.IsExchangeWithApplicationInService);
	DescriptionOfTheApplicationString.Insert("ThisIsTheInitialUpload",			True);
	
	ContinueNewSynchronizationSetup = Not SynchronizationSetupCompleted(DescriptionOfTheApplicationString, DataToCompleteSetup);
	If ContinueNewSynchronizationSetup Then
		
		FinishSettingUpSynchronizationInTheDialog(DescriptionOfTheApplicationString, DataToCompleteSetup);
		
	ElsIf Not CurrentData.InteractiveSendingAvailable Then
		
		ShowMessageBox(, NStr("en = 'Exporting data for mapping is not supported for the selected synchronization setup option.';"));
		
	Else
		
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangeNode", CurrentData.InfobaseNode);
		WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		WizardParameters.Insert("CorrespondentDataArea", CurrentData.DataArea);
		
		If DataToCompleteSetup.IsPassiveConnection Then
			
			WizardParameters.Insert("InitialExport", True);
			
		EndIf;
		
		ClosingNotification1 = New NotifyDescription("InitialDataExportCompletion", ThisObject);
		
		NameOfFormToOpen_ = "DataProcessor.InteractiveDataExchangeWizard.Form.ExportMappingData";
		OpenForm(NameOfFormToOpen_, WizardParameters, ThisObject, , , , ClosingNotification1, FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InitialDataExportCompletion(ClosingResult, AdditionalParameters) Export
	
	AttachIdleHandler("UpdateMonitorDataInteractively", 0.1, True);
	
EndProcedure

&AtClient
Procedure GoToEventsEventLog(CurrentData, ActionOnExchange)
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode, ThisObject, ActionOnExchange);
	
EndProcedure

&AtClient
Procedure ThePreviousFormOfSynchronizationWarnings()
	
	OpeningParameters		= New Structure;
	ArrayOfExchangePlanNodes	= New Array;
	
	For Each MonitorRow In ApplicationsList Do
		
		ArrayOfExchangePlanNodes.Add(MonitorRow.InfobaseNode);
		
	EndDo;
	
	OpeningParameters.Insert("ExchangeNodes", ArrayOfExchangePlanNodes);
	
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpeningParameters, ThisObject);
	
EndProcedure

// Start method of form commands
//
&AtClient
Procedure RunACommandWithAPreliminaryCheck(CommandByLine)
	
	CurrentData = CurrentApplicationsListData();
	If CurrentData = Undefined Then
		
		UpdateMonitorDataInteractively();
		Return;
		
	EndIf;
	
	If CommandByLine <> "DeleteSynchronizationSetting"
		And CurrentData.SynchronizationIsUnavailable Then
		
		MessageText = NStr("en = 'Synchronization is unavailable';");
		
		CommonClient.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If CommandByLine = "RunSync" Then
		
		SynchronizationExecutionCommandProcessing(CurrentData, False);
		
	ElsIf CommandByLine = "RunSyncWithAdditionalFilters" Then
		
		SynchronizationExecutionCommandProcessing(CurrentData, True);
		
	ElsIf CommandByLine = "ChangeSynchronizationSettings" Then
		
		OpenSynchronizationParametersSettingForm(CurrentData);
		
	ElsIf CommandByLine = "OpenTheResultsOfSynchronizationOfTheUploadEvent" Then
		
		OpenTheSynchronizationResults(CurrentData, "UploadEvents");
		
	ElsIf CommandByLine = "OpenTheResultsOfSynchronizationOfTheDownloadEvent" Then
		
		OpenTheSynchronizationResults(CurrentData, "DownloadEvents");
		
	ElsIf CommandByLine = "DataToSendComposition" Then
		
		DataExchangeClient.OpenCompositionOfDataToSend(CurrentData.InfobaseNode);
		
	ElsIf CommandByLine = "ConfigureDataExchangeScenarios" Then
		
		DataExchangeClient.SetExchangeExecutionScheduleCommandProcessing(CurrentData.InfobaseNode, ThisObject);
		
	ElsIf CommandByLine = "DeleteSynchronizationSetting" Then
		
		DeleteTheSynchronizationSettings(CurrentData);
		
	ElsIf CommandByLine = "ImportDataSyncRules" Then
		
		LoadDataSynchronizationRules(CurrentData);
		
	ElsIf CommandByLine = "InitialDataExport" Then
		
		ExecuteInitialDataExport(CurrentData);
		
	ElsIf CommandByLine = "GoToDataExportEventLog" Then
		
		GoToEventsEventLog(CurrentData, "DataExport");
		
	ElsIf CommandByLine = "GoToDataImportEventLog" Then
		
		GoToEventsEventLog(CurrentData, "DataImport");
		
	ElsIf CommandByLine = "PreviousWarningsForm" Then
		
		ThePreviousFormOfSynchronizationWarnings();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SynchronizationSetupCompleted(ApplicationRow, DataToCompleteSetup = Undefined)
	
	ModuleWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	SettingOptionDetails = ModuleWizard.SettingOptionDetailsStructure();
	
	SettingID = DataExchangeServer.SavedExchangePlanNodeSettingOption(ApplicationRow.InfobaseNode);
		
	If Not ApplicationRow.ExternalSystem Then
		SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ApplicationRow.ExchangePlanName,
			"CorrespondentConfigurationDescription,
			|NewDataExchangeCreationCommandTitle,
			|ExchangeCreateWizardTitle,
			|BriefExchangeInfo,
			|DetailedExchangeInformation",
			SettingID,
			ApplicationRow.CorrespondentVersion);
			
		FillPropertyValues(SettingOptionDetails, SettingsValuesForOption);
		SettingOptionDetails.CorrespondentDescription = SettingsValuesForOption.CorrespondentConfigurationDescription;
	EndIf;
	
	MessagesNumbers = Common.ObjectAttributesValues(ApplicationRow.InfobaseNode, "ReceivedNo, SentNo");
	TransportKind   = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ApplicationRow.InfobaseNode);
	
	If Not ValueIsFilled(TransportKind) Then
		
		TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode;
		
	EndIf;
	
	DataToCompleteSetup = New Structure;
	DataToCompleteSetup.Insert("SettingID",    SettingID);
	DataToCompleteSetup.Insert("SettingOptionDetails", SettingOptionDetails);
	DataToCompleteSetup.Insert("IsPassiveConnection",      TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
	
	Return DataExchangeServer.SynchronizationSetupCompleted(ApplicationRow.InfobaseNode)
		And Not (MessagesNumbers.ReceivedNo = 0
			And MessagesNumbers.SentNo = 0
			And DataExchangeServer.MessageWithDataForMappingReceived(ApplicationRow.InfobaseNode));
	
EndFunction

&AtServer
Function ServerChecksBeforeExecutingCommands(ApplicationRow, DataToCompleteSetup, VerificationOption = "")
	Var ErrorDescription;
	
	ChecksResults = New Structure;
	
	SettingCompleted = SynchronizationSetupCompleted(ApplicationRow, DataToCompleteSetup);
	ChecksResults.Insert("ContinueNewSynchronizationSetup", Not SettingCompleted);
	
	If VerificationOption <> "Minimum" Then
		
		AMessageForMatchingWasReceived = DataExchangeServer.MessageWithDataForMappingReceived(ApplicationRow.InfobaseNode);
		ChecksResults.Insert("AMessageForMatchingWasReceived", AMessageForMatchingWasReceived);
		
		TheConversionRulesAreCompatible = ConversionRulesCompatibleWithCurrentVersion(ApplicationRow.ExchangePlanName, ErrorDescription);
		ChecksResults.Insert("TheConversionRulesAreCompatible",			TheConversionRulesAreCompatible);
		ChecksResults.Insert("ErrorDescription",						ErrorDescription);
		
	EndIf;
	
	Return ChecksResults;
	
EndFunction

#EndRegion

#Region UpdatingTheListForm

&AtClient
Procedure OnCompleteMonitorDataUpdateInBackground()
	
	OnCompleteGettingApplicationsListAtServer();
	ExecuteCursorPositioning(ApplicationsListLineIndex);
	
	AttachIdleHandler("UpdateMonitorDataInBackground", 60, True);
	
EndProcedure

&AtClient
Procedure OnCompleteMonitorDataUpdate()
	
	OnCompleteGettingApplicationsListAtServer();
	ExecuteCursorPositioning(ApplicationsListLineIndex);
	
	Items.ApplicationsListPanel.CurrentPage = Items.ApplicationsListPage;
	Items.CommandBar.Enabled = True;
	
	AttachIdleHandler("UpdateMonitorDataInBackground", 60, True);
	
EndProcedure

&AtClient
Procedure OnWaitForMonitorDataUpdateInBackground()
	
	ContinueWait = False;
	OnWaitGettingApplicationsListAtServer(ParametersOfGetApplicationsListHandler, ContinueWait);
	
	If ContinueWait Then
		
		DataExchangeClient.UpdateIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		AttachIdleHandler("OnWaitForMonitorDataUpdateInBackground", ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
		
	Else
		
		ParametersOfGetApplicationsListIdleHandler = Undefined;
		OnCompleteMonitorDataUpdateInBackground();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForMonitorDataUpdate()
	
	ContinueWait = False;
	OnWaitGettingApplicationsListAtServer(ParametersOfGetApplicationsListHandler, ContinueWait);
	
	If ContinueWait Then
		
		DataExchangeClient.UpdateIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		AttachIdleHandler("OnWaitForMonitorDataUpdate", ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
		
	Else
		
		ParametersOfGetApplicationsListIdleHandler = Undefined;
		OnCompleteMonitorDataUpdate();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnStartMonitorDataUpdateInBackground()
	
	If Not ParametersOfGetApplicationsListIdleHandler = Undefined Then
		
		Return;
		
	EndIf;
	
	ParametersOfGetApplicationsListHandler = Undefined;
	ContinueWait = False;
	
	OnStartGettingApplicationsListAtServer(ParametersOfGetApplicationsListHandler, ContinueWait);
		
	If ContinueWait Then
		
		DataExchangeClient.InitIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		AttachIdleHandler("OnWaitForMonitorDataUpdateInBackground", ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
		
	Else
		
		OnCompleteMonitorDataUpdateInBackground();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnStartMonitorDataUpdate()
	
	If Not ParametersOfGetApplicationsListIdleHandler = Undefined Then
		
		Return;
		
	EndIf;
	
	ParametersOfGetApplicationsListHandler = Undefined;
	ContinueWait = False;
	
	OnStartGettingApplicationsListAtServer(ParametersOfGetApplicationsListHandler, ContinueWait);
		
	If ContinueWait Then
		
		Items.ApplicationsListPanel.CurrentPage = Items.PageWait;
		Items.CommandBar.Enabled = False;
		
		DataExchangeClient.InitIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		AttachIdleHandler("OnWaitForMonitorDataUpdate", ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
		
	Else
		
		OnCompleteMonitorDataUpdate();
		
	EndIf;
	
EndProcedure

// Start procedure for a manual list refresh.
//
&AtClient
Procedure UpdateMonitorDataInteractively()
	
	ApplicationsListLineIndex = GetCurrentRowIndex();
	
	If SaaSModel Then
		
		OnStartMonitorDataUpdate();
		
	Else
		
		RefreshApplicationsList();
		ExecuteCursorPositioning(ApplicationsListLineIndex);
		
		AttachIdleHandler("UpdateMonitorDataInBackground", 60, True);
		
	EndIf;
	
EndProcedure

// Start procedure for a manual list refresh.
//
&AtClient
Procedure UpdateMonitorDataInBackground()
	
	ApplicationsListLineIndex = GetCurrentRowIndex();
	
	UpdateSaaSApplications = SaaSModel;
	RefreshApplicationsList(UpdateSaaSApplications);
	
	If SaaSModel
		And UpdateSaaSApplications Then
		
		OnStartMonitorDataUpdateInBackground();
		
	Else
		
		ExecuteCursorPositioning(ApplicationsListLineIndex);
		
		AttachIdleHandler("UpdateMonitorDataInBackground", 60, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Synchronization

&AtClient
Procedure DataSynchronization(DescriptionOfTheApplicationString)
	
	TheResultOfAnAdditionalCheck = (DescriptionOfTheApplicationString.DataExchangeOption <> "Synchronization" Or DescriptionOfTheApplicationString.UseAddlFilters);
	
	If DescriptionOfTheApplicationString.MessageReceivedForDataMapping
		Or (DescriptionOfTheApplicationString.InteractiveSendingAvailable And TheResultOfAnAdditionalCheck)
		Then
		
		OpenInteractiveSynchronizationWizard(DescriptionOfTheApplicationString);
		
	Else
		
		OpenAutomaticSynchronizationWizard(DescriptionOfTheApplicationString);
		
	EndIf;
	
EndProcedure

// Start procedure of the interactive synchronization 
//
&AtClient
Procedure OpenInteractiveSynchronizationWizard(AdditionalParameters)
	
	ExportAdditionMode = AdditionalParameters.UseAddlFilters Or (AdditionalParameters.DataExchangeOption = "ReceiveAndSend");
	
	WizardParameters = New Structure;
	WizardParameters.Insert("IsExchangeWithApplicationInService", AdditionalParameters.IsExchangeWithApplicationInService);
	WizardParameters.Insert("CorrespondentDataArea",  AdditionalParameters.CorrespondentDataArea);
	WizardParameters.Insert("SendData", Not AdditionalParameters.StartDataExchangeFromCorrespondent);
	WizardParameters.Insert("ExportAdditionMode", ExportAdditionMode);
	WizardParameters.Insert("ScheduleSetup", False);
	
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters", WizardParameters);
	AuxiliaryParameters.Insert("ClosingNotification1", New NotifyDescription("AfterClosingTheExchangeAssistant", ThisObject, AdditionalParameters));
	
	DataExchangeClient.OpenObjectsMappingWizardCommandProcessing(AdditionalParameters.InfobaseNode, ThisObject, AuxiliaryParameters);
	
EndProcedure

// Start procedure of the automatic synchronization 
//
&AtClient
Procedure OpenAutomaticSynchronizationWizard(AdditionalParameters)
	
	WizardParameters = New Structure;	
	WizardParameters.Insert("IsExchangeWithApplicationInService", AdditionalParameters.IsExchangeWithApplicationInService);
	WizardParameters.Insert("CorrespondentDataArea",  AdditionalParameters.CorrespondentDataArea);
		
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters", WizardParameters);
	AuxiliaryParameters.Insert("ClosingNotification1", New NotifyDescription("AfterClosingTheExchangeAssistant", ThisObject, AdditionalParameters));
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(AdditionalParameters.InfobaseNode, ThisObject, , True, AuxiliaryParameters);
	
EndProcedure

&AtClient
Procedure AfterClosingTheExchangeAssistant(Result, AdditionalParameters) Export
	
	If Not AdditionalParameters.Property("InfobaseNode") Then
		
		Return;
		
	EndIf;
	
	FilterParameters = New Structure("InfobaseNode", AdditionalParameters.InfobaseNode);
	
	FoundRows = ApplicationsList.FindRows(FilterParameters);
	If FoundRows.Count() > 0 Then
		
		TheStructureOfTheHeaders = UpdateInformationAboutDataSynchronizationProblems(AdditionalParameters.InfobaseNode);
		FoundRows[0].SendWarning = TheStructureOfTheHeaders.HeaderOfSendingWarnings;
		FoundRows[0].GetWarning = TheStructureOfTheHeaders.TheHeaderOfTheReceiptWarnings;
		
	Else
		
		UpdateMonitorDataInteractively();
		
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Function GetCurrentRowIndex()
	
	// Function return value.
	RowIndex = Undefined;
	
	// Placing a mouse pointer upon updating the monitor.
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ApplicationsList.IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
	
EndFunction

&AtClient
Function CurrentApplicationsListData()
	
	CurrentData = Items.ApplicationsList.CurrentData;
	If CurrentData = Undefined Then
		
		Return CurrentData;
		
	EndIf;
	
	If Not ExchangeNodeExists(CurrentData.InfobaseNode) Then // 
		
		Return Undefined;
		
	EndIf;
	
	Return CurrentData;
	
EndFunction

&AtClient
Procedure ExecuteCursorPositioning(RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Check the cursor position after new data is received.
		If ApplicationsList.Count() <> 0 Then
			
			If RowIndex > ApplicationsList.Count() - 1 Then
				
				RowIndex = ApplicationsList.Count() - 1;
				
			EndIf;
			
			// 
			Items.ApplicationsList.CurrentRow = ApplicationsList[RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// If the row positioning failed, by default, set the cursor to the first row.
	If Items.ApplicationsList.CurrentRow = Undefined
		And ApplicationsList.Count() <> 0 Then
		
		Items.ApplicationsList.CurrentRow = ApplicationsList[0].GetID();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishSettingUpSynchronizationInTheDialog(DescriptionOfTheApplicationString, DataToCompleteSetup)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData", DescriptionOfTheApplicationString);
	AdditionalParameters.Insert("DataToCompleteSetup", DataToCompleteSetup);
	
	CompletionNotification = New NotifyDescription("QuestionContinueSynchronizationSetupCompletion", ThisObject, AdditionalParameters);
	
	If DescriptionOfTheApplicationString.ThisIsTheInitialUpload Then
		
		TextPart1 = NStr("en = 'Before exporting data for mapping, finish the synchronization setup.';", CommonClient.DefaultLanguageCode());
		
	Else
		
		TextPart1 = NStr("en = 'Before starting data synchronization, finish the synchronization setup.';", CommonClient.DefaultLanguageCode());
		
	EndIf;
	
	QueryText = TextPart1 + Chars.LF + NStr("en = 'Open the setup wizard form?';", CommonClient.DefaultLanguageCode());
	
	ShowQueryBox(CompletionNotification, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure QuestionContinueSynchronizationSetupCompletion(QuestionResult, AdditionalParameters) Export
	
	If Not QuestionResult = DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	OpenNewSynchronizationSetupWizardForm(AdditionalParameters.CurrentData, AdditionalParameters.DataToCompleteSetup);
	
EndProcedure

&AtClient
Procedure OpenNewSynchronizationSetupWizardForm(CurrentData, DataToCompleteSetup)
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangeNode",             CurrentData.InfobaseNode);
	WizardParameters.Insert("ExchangePlanName",         CurrentData.ExchangePlanName);
	WizardParameters.Insert("SettingID", DataToCompleteSetup.SettingID);
	WizardParameters.Insert("SettingOptionDetails", DataToCompleteSetup.SettingOptionDetails);
	
	If SaaSModel Then
		
		WizardParameters.Insert("CorrespondentDataArea",  CurrentData.CorrespondentDataArea);
		WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		
	EndIf;
	
	ClosingNotification1 = New NotifyDescription("AfterTheSynchronizationSettingsAreCompleted", ThisObject);
	
	If CurrentData.ExternalSystem Then
		
		BackgroundTaskSettings = BackgroundJobSettingsOptionsOfDataExchangeWithExternalSystems(CurrentData.InfobaseNode, UUID);
		If BackgroundTaskSettings <> Undefined Then
			
			WizardParameters.Insert("DataExchangeWithExternalSystem", True);
			OpenTheFormWaitingForTheEndOfTheConfiguration(BackgroundTaskSettings, WizardParameters);
			
		EndIf;
		
	Else
		
		WizardUniqueKey = StrTemplate("%1_%2_%3", WizardParameters.ExchangePlanName, WizardParameters.SettingID, WizardParameters.ExchangeNode.UUID());
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.SyncSetup",
			WizardParameters, ThisObject, WizardUniqueKey, , , ClosingNotification1, FormWindowOpeningMode.Independent);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteGettingSettingsOptionsOfDataExchangeWithExternalSystems(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		
		Return;
		
	EndIf;
	
	If Result.Status = "Completed2" Then
		
		Cancel = False;
		ErrorMessage = "";
		ProcessReceivingSettingsOptionsResultAtServer(Result.ResultAddress, Cancel, ErrorMessage, AdditionalParameters.WizardParameters);
			
		If Cancel Then
			
			ShowMessageBox(, ErrorMessage);
			
		Else
			
			NameOfFormToOpen_ = "DataProcessor.DataExchangeCreationWizard.Form.SyncSetup";
			OpenForm(NameOfFormToOpen_, AdditionalParameters.WizardParameters, ThisObject, , , , AdditionalParameters.ClosingNotification1, FormWindowOpeningMode.Independent);
			
		EndIf;
			
	ElsIf Result.Status = "Error" Then
		
		ShowMessageBox(, Result.BriefErrorDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UserDialogWithIncompatibleRules(DescriptionOfTheApplicationString, ErrorDescription)
	
	Buttons = New ValueList;
	Buttons.Add("GoToRuleImport",	NStr("en = 'Load rules';"));
	If ErrorDescription.ErrorKind <> "InvalidConfiguration" Then
		
		Buttons.Add("Continue", NStr("en = 'Continue';"));
		
	EndIf;
	Buttons.Add("Cancel", NStr("en = 'Cancel';"));
	
	FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
	FormParameters.Picture = ErrorDescription.Picture;
	FormParameters.PromptDontAskAgain = False;
	
	If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
		
		FormParameters.Title = NStr("en = 'Cannot perform data synchronization';", CommonClient.DefaultLanguageCode());
		
	Else
		
		FormParameters.Title = NStr("en = 'Data synchronization might be performed incorrectly';", CommonClient.DefaultLanguageCode());
		
	EndIf;
	
	Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, DescriptionOfTheApplicationString);
	
	StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
	
EndProcedure

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		
		Return;
		
	EndIf;
	
	If Result.Value = "Continue" Then
		
		DataSynchronization(AdditionalParameters);
		
	ElsIf Result.Value = "GoToRuleImport" Then
		
		DataExchangeClient.ImportDataSyncRules(AdditionalParameters.ExchangePlanName);
		
	EndIf; // No action is required if the value is "Cancel".
	
EndProcedure

&AtClient
Procedure OpenTheFormWaitingForTheEndOfTheConfiguration(BackgroundTaskSettings, DescriptionOfTheApplicationString)
	
	ClosingNotification1 = New NotifyDescription("AfterTheSynchronizationSettingsAreCompleted", ThisObject);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("WizardParameters",  DescriptionOfTheApplicationString);
	AdditionalParameters.Insert("ClosingNotification1", ClosingNotification1);
	
	CompletionNotification2 = New NotifyDescription("OnCompleteGettingSettingsOptionsOfDataExchangeWithExternalSystems", ThisObject, AdditionalParameters);

	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = True;
	
	TimeConsumingOperationsClient.WaitCompletion(BackgroundTaskSettings, CompletionNotification2, IdleParameters);
	
EndProcedure

&AtClient
Procedure RebootWarningDescriptionURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	Exit(False, True);
	
EndProcedure

&AtClient
Procedure WarnAboutLoopDetailsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("InformationRegister.SynchronizationCircuit.Form.SynchronizationLoop",,,,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure MigrationExchangeOverInternetInfoTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.InfoPanelMigrationToExchangeOverInternet.Visible = False;
	
	ModuleDataExchangeInternalPublicationServerCall = CommonClient.CommonModule("DataExchangeInternalPublicationServerCall");
	ModuleDataExchangeInternalPublicationServerCall.SettingFlagShouldMutePromptToMigrateToWebService(
		"DataSyncSettings", True);
	
EndProcedure

&AtServerNoContext
Function UpdateInformationAboutDataSynchronizationProblems(SynchronizationNode)
	
	SetPrivilegedMode(True);
	Return InformationRegisters.DataExchangeResults.TheNumberOfWarningsInDetail(SynchronizationNode);
	
EndFunction

&AtServerNoContext
Function BackgroundJobSettingsOptionsOfDataExchangeWithExternalSystems(ExchangeNode, UUID)
	
	BackgroundJob = Undefined;
	
	If Common.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
		ModuleWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
		SettingVariants = ModuleWizard.ExternalSystemsDataExchangeSettingsOptionDetails();
		
		ProcedureParameters = New Structure;
		ProcedureParameters.Insert("SettingVariants", SettingVariants);
		ProcedureParameters.Insert("ExchangeNode",       ExchangeNode);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = NStr("en = 'Get available setup options for data exchange with external systems';");
		ExecutionParameters.RunInBackground = True;
		
		BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
			"DataExchangeWithExternalSystems.OnGetDataExchangeSettingsOptions",
			ProcedureParameters,
			ExecutionParameters);
	EndIf;
	
	Return BackgroundJob;
	
EndFunction

&AtServerNoContext
Function DataSynchronizationState(ApplicationRow)
	
	State = New Structure;
	State.Insert("Presentation", "");
	State.Insert("Picture",      0);
	
	If Not ApplicationRow.SettingCompleted Then
		State.Presentation = NStr("en = 'Setup pending';");
		State.Picture = 3;
		
		If ApplicationRow.MessageReceivedForDataMapping Then
			State.Presentation = NStr("en = 'Setup pending, received data to map';");
		EndIf;
	Else
		If ApplicationRow.LastImportStartDate > ApplicationRow.LastImportEndDate Then
			State.Presentation = NStr("en = 'Importing data…';");
			State.Picture = 4;
		ElsIf ApplicationRow.LastExportStartDate > ApplicationRow.LastExportEndDate Then
			State.Presentation = NStr("en = 'Exporting data…';");
			State.Picture = 4;
		ElsIf Not ValueIsFilled(ApplicationRow.LastRunDate) Then
			State.Presentation = NStr("en = 'Not started yet';");
			
			If ApplicationRow.MessageReceivedForDataMapping Then
				State.Presentation = NStr("en = 'Received data to map';");
			EndIf;
		Else
			State.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Last started on: %1';"),
				ApplicationRow.LastStartDatePresentation);
				
			If ApplicationRow.MessageReceivedForDataMapping Then
				State.Presentation = NStr("en = 'Received data to map';");
			EndIf;
		EndIf;
	EndIf;
	
	Return State;
	
EndFunction

&AtServerNoContext
Function ExecutionResultPicture(ExecutionResult)
	
	If ExecutionResult = 2 Then
		Return 3; // Completed with warnings.
	ElsIf ExecutionResult = 1 Then
		Return 2; // Error
	ElsIf ExecutionResult = 0 Then
		Return 0; // Success
	EndIf;
	
	// 
	Return 0;
	
EndFunction

&AtServerNoContext
Function ExchangeNodeExists(ExchangeNode)
	
	Return Common.RefExists(ExchangeNode);
	
EndFunction

&AtServerNoContext
Procedure ProcessReceivingSettingsOptionsResultAtServer(ResultAddress, Cancel, ErrorMessage, WizardParameters)
	
	Result = GetFromTempStorage(ResultAddress);
	
	If Not ValueIsFilled(Result.ErrorCode) Then
		Filter = New Structure("ExchangePlanName, SettingID");
		FillPropertyValues(Filter, WizardParameters);
		
		SettingsOptionsRows = Result.SettingVariants.FindRows(Filter);
		If SettingsOptionsRows.Count() > 0 Then
			FillPropertyValues(WizardParameters.SettingOptionDetails, SettingsOptionsRows[0]);
		Else
			Cancel = True;
			ErrorMessage = NStr("en = 'There are no connections settings available for this service.';");
		EndIf;
	Else
		Cancel = True;
		If ValueIsFilled(Result.ErrorCode) Then
			ErrorMessage = Result.ErrorMessage;
		EndIf;
	EndIf;
	
	DeleteFromTempStorage(ResultAddress);
	
EndProcedure

&AtServerNoContext
Procedure OnStartGettingApplicationsListAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	WizardParameters = New Structure("Mode", "ConfiguredExchanges");
	
	ModuleSetupWizard.OnStartGetApplicationList(WizardParameters,
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitGettingApplicationsListAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnWaitForGetApplicationList(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Function ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Query.Text =
	"SELECT
	|	DataExchangeRules.RulesAreRead,
	|	DataExchangeRules.RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsConversionRules)";
	
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		RulesStructure = Selection.RulesAreRead.Get().Conversion; // Structure
		
		RulesInformation = New Structure;
		RulesInformation.Insert("ConfigurationName",              RulesStructure.Source);
		RulesInformation.Insert("ConfigurationVersion",           RulesStructure.SourceConfigurationVersion);
		RulesInformation.Insert("ConfigurationSynonymInRules", RulesStructure.SourceConfigurationSynonym);
		
		Return InformationRegisters.DataExchangeRules.ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription, RulesInformation);
		
	EndIf;
	
	Return True;
		
EndFunction

&AtServer
Procedure CheckDataSynchronizationSettingPossibility(Cancel = False)
	
	MessageText = "";
	If Common.DataSeparationEnabled() Then
		If Common.SeparatedDataUsageAvailable() Then
			ModuleDataExchangeSaaSCached = Common.CommonModule("DataExchangeSaaSCached");
			If Not ModuleDataExchangeSaaSCached.DataSynchronizationSupported() Then
		 		MessageText = NStr("en = 'This application does not support data synchronization setup.';");
				Cancel = True;
			EndIf;
		Else
			MessageText = NStr("en = 'Cannot configure data synchronization in shared mode.';");
			Cancel = True;
		EndIf;
	Else
		ExchangePlansList = DataExchangeCached.SSLExchangePlans();
		If ExchangePlansList.Count() = 0 Then
			MessageText = NStr("en = 'This application does not support data synchronization setup.';");
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel
		And Not IsBlankString(MessageText) Then
		Common.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// If a sync was configured but never run, apply faded font color.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePresentation1.Name);
	
	CommonClientServer.AddCompositionItem(Item.Filter, "ApplicationsList.StatePresentation", DataCompositionComparisonType.Equal, NStr("en = 'Not started yet';"));
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePresentation1.Name);
	
	CommonClientServer.AddCompositionItem(Item.Filter, "ApplicationsList.StatePresentation", DataCompositionComparisonType.Equal, NStr("en = 'Setup pending';"));
	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkRed);
	
	// Текст "н/д" и тусклый цвет шрифта для отсутствующего префикса программы-
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListCorrespondentPrefix.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.CorrespondentPrefix");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'n/a';"));
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePicture1.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.StatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListExportStatePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.ExportStatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListImportStatePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.ImportStatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	// 
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsList.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePresentation1.Name);
		
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.SynchronizationIsUnavailable");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtServer
Procedure OnCompleteGettingApplicationsListAtServer()
	
	SaaSApplications.Clear();
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If Not ModuleSetupWizard = Undefined Then
		CompletionStatus = Undefined;
		ModuleSetupWizard.OnCompleteGettingApplicationsList(
			ParametersOfGetApplicationsListHandler, CompletionStatus);
			
		If Not CompletionStatus.Cancel Then
			ApplicationsTable = CompletionStatus.Result;
			Columns = "Peer, DataArea, ApplicationDescription, HasExchangeAdministrationManage_3_0_1_1";
			SaaSApplications.Load(ApplicationsTable.Copy(,Columns));
		EndIf;
	EndIf;
	
	RefreshApplicationsList();
	
EndProcedure

&AtServer
Procedure SetFormItemsView()
	
	// 
	Items.ApplicationsListDataExchangeExecutionGroup.Enabled    = HasConfiguredExchanges;
	Items.ApplicationsListControlGroup.Enabled                 = HasRightsToAdministerExchanges And HasConfiguredExchanges;
	Items.ApplicationsListExchangeScheduleGroup.Enabled = HasRightsToAdministerExchanges And HasConfiguredExchanges;
	Items.ApplicationsListCreateSyncSetting.Enabled    = HasRightsToAdministerExchanges;
	Items.ApplicationsListEventsGroup.Enabled                    = HasViewEventLogRights And HasConfiguredExchanges;
	
	// 
	Items.ApplicationsListContextMenuDataExchangeExecutionGroup.Enabled = HasConfiguredExchanges;
	Items.ApplicationsListContextMenuControlGroup.Enabled  = HasRightsToAdministerExchanges And HasConfiguredExchanges;
	Items.ApplicationsListContextMenuEventsGroup.Enabled     = HasViewEventLogRights And HasConfiguredExchanges;
	
	// 
	Items.InfoPanelUpdateRequired.Visible = UpdateRequired;
	
	If HasConfigurationUpdateRights Then
		Items.RefereshRightPage.CurrentPage = Items.DataExchangePausedHasRightToUpdateInfo;
	Else
		Items.RefereshRightPage.CurrentPage = Items.InfoDataExchangePausedNoRightToUpdate;
	EndIf;
	
	Items.InfoPanelRestartRequired.Visible = 
		IsRestartRequired And ApplicationsList.Count() > 0 And Not SaaSModel;
	
	Items.InfoPanelLoopFound.Visible = IsLoopDetected;
		
	Items.ApplicationsListCanMigrateToWS.Visible = CanMigrateToWS;
	
	// Force disabling of visibility of commands of schedule setup and importing rules in SaaS.
	If SaaSModel Then
		
		Items.ApplicationsListExchangeScheduleGroup.Visible = False;
		
		ModuleDataExchangeInternalPublicationServerCall = Common.CommonModule("DataExchangeInternalPublicationServerCall");
		Items.InfoPanelMigrationToExchangeOverInternet.Visible = 
			CanMigrateToWS 
			And Not ModuleDataExchangeInternalPublicationServerCall.SettingFlagShouldMutePromptToMigrateToWebService("DataSyncSettings");
			
	Else
		
		Items.InfoPanelMigrationToExchangeOverInternet.Visible = False;
		
	EndIf;
	
	Items.InfoPanelDisabledScenarios.Visible = DisabledScenarios.Count() > 0;
	
	If DisabledScenarios.Count() = 1 Then
		
		Template = NStr("en = 'A scenario that was disabled due to execution errors is found: %1';");
		Text = StrTemplate(Template, DisabledScenarios[0].Value);
		Items.DisabledScenariosWarningDetails.Title = Text;
		
	ElsIf DisabledScenarios.Count() > 1 Then
		
		Template = NStr("en = 'Scenarios that were disabled due to execution errors are found: %1';");
		ArrayOfScenarios = DisabledScenarios.UnloadValues();
		Text = StrTemplate(Template, StrConcat(ArrayOfScenarios, ", "));
		Items.DisabledScenariosWarningDetails.Title = Text;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshApplicationsList(UpdateSaaSApplications = False)
	
	Items.ApplicationsListPanel.CurrentPage = Items.ApplicationsListPage;
	Items.CommandBar.Enabled = True;
	
	SSLExchangePlans = DataExchangeCached.SSLExchangePlans();
	
	ApplicationsBeforeUpdate = ApplicationsList.Unload(, "InfobaseNode").UnloadColumn("InfobaseNode");
	MonitorTable = DataExchangeServer.DataExchangeMonitorTable(SSLExchangePlans);
	ApplicationsAfterUpdate = MonitorTable.UnloadColumn("InfobaseNode");
	
	HasConfiguredExchanges = (ApplicationsAfterUpdate.Count() > 0);
	
	If UpdateSaaSApplications
		And HasConfiguredExchanges Then
		UpdateSaaSApplications = False;
		For Each Package In ApplicationsAfterUpdate Do
			If ApplicationsBeforeUpdate.Find(Package) = Undefined Then
				UpdateSaaSApplications = True;
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	ApplicationsList.Load(MonitorTable);
	
	CanMigrateToWS = False;
	
	For Each ApplicationRow In ApplicationsList Do
		
		SetPrivilegedMode(True);
		ApplicationRow.CorrespondentDescription = Common.ObjectAttributeValue(
			ApplicationRow.InfobaseNode, "Description");
		SetPrivilegedMode(False);
		
		SaaSApplicationRows = SaaSApplications.FindRows(
			New Structure("Peer", ApplicationRow.InfobaseNode));
			
		If SaaSApplicationRows.Count() > 0 Then
			SaaSApplicationRow = SaaSApplicationRows[0];
			
			ApplicationRow.IsExchangeWithApplicationInService = True;
			ApplicationRow.DataArea = SaaSApplicationRow.DataArea;
			ApplicationRow.CorrespondentDescription = SaaSApplicationRow.ApplicationDescription;
			ApplicationRow.CanMigrateToWS = SaaSApplicationRow.HasExchangeAdministrationManage_3_0_1_1
				And ApplicationRow.CanMigrateToWS;
				
		Else
			
			ApplicationRow.CanMigrateToWS = False;
			
		EndIf;
		
		If ApplicationRow.IsExchangeWithApplicationInService Then
			
			ApplicationRow.ApplicationOperationMode = 1;
			ApplicationRow.InteractiveSendingAvailable = True;
			
		Else
			
			TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(
				ApplicationRow.InfobaseNode);
			
			If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
				Or TransportKind = Enums.ExchangeMessagesTransportTypes.ExternalSystem Then
				ApplicationRow.ApplicationOperationMode = 1; // сервис
			Else
				ApplicationRow.ApplicationOperationMode = 0;
			EndIf;
				
			If Not ValueIsFilled(TransportKind)
				Or (TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode) Then
				// 
				ApplicationRow.StartDataExchangeFromCorrespondent = True;
			EndIf;
			
			ApplicationRow.ExternalSystem = (TransportKind = Enums.ExchangeMessagesTransportTypes.ExternalSystem);
			
			ApplicationRow.InteractiveSendingAvailable =
				Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ApplicationRow.ExchangePlanName)
				And Not DataExchangeCached.IsStandardDataExchangeNode(ApplicationRow.ExchangePlanName)
				And Not ApplicationRow.ExternalSystem;
			
		EndIf;
		
		ApplicationRow.InteractiveSendingAvailable = ApplicationRow.InteractiveSendingAvailable
			And Not (ApplicationRow.DataExchangeOption = "ReceiveOnly");
		
		SynchronizationState = DataSynchronizationState(ApplicationRow);
		ApplicationRow.StatePresentation = SynchronizationState.Presentation;
		ApplicationRow.StatePicture      = SynchronizationState.Picture;
		
		If ApplicationRow.SettingCompleted Then
			
			TheStructureOfTheHeaders = UpdateInformationAboutDataSynchronizationProblems(ApplicationRow.InfobaseNode);
			ApplicationRow.SendWarning = TheStructureOfTheHeaders.HeaderOfSendingWarnings;
			ApplicationRow.GetWarning = TheStructureOfTheHeaders.TheHeaderOfTheReceiptWarnings;
			
		EndIf;
		
		If ValueIsFilled(ApplicationRow.LastRunDate) Then
			ApplicationRow.ExportStatePicture = ExecutionResultPicture(ApplicationRow.LastDataExportResult);
			
			If Not ApplicationRow.MessageReceivedForDataMapping Then
				ApplicationRow.ImportStatePicture = ExecutionResultPicture(ApplicationRow.LastDataImportResult);
			EndIf;
		Else
			
			// 
			// 
			ApplicationRow.LastSuccessfulExportDatePresentation = "";
			ApplicationRow.LastSuccessfulImportDatePresentation = "";
			
		EndIf;
		
		If ApplicationRow.MessageReceivedForDataMapping Then
			// 
			ApplicationRow.LastSuccessfulImportDatePresentation = ApplicationRow.MessageDatePresentationForDataMapping;
			ApplicationRow.ImportStatePicture = 5;
		EndIf;
		
		ApplicationRow.ConversionRulesAreUsed = DataExchangeCached.HasExchangePlanTemplate(ApplicationRow.ExchangePlanName, "ExchangeRules");
		
		CanMigrateToWS = Max(CanMigrateToWS, ApplicationRow.CanMigrateToWS);
		
	EndDo;
	
	UpdateRequired = DataExchangeServer.UpdateInstallationRequired();
	
	If UpdateRequired Then
		IsRestartRequired = False;
	Else	
		IsRestartRequired = Catalogs.ExtensionsVersions.ExtensionsChangedDynamically();
	EndIf;
	
	IsLoopDetected = DataExchangeLoopControl.HasLoop();
	
	GetDisabledScenarios();
	
	SetFormItemsView();
	
EndProcedure

&AtServer
Procedure GetDisabledScenarios()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	DataExchangeScenarios.Ref AS Ref
		|FROM
		|	Catalog.DataExchangeScenarios AS DataExchangeScenarios
		|WHERE
		|	DataExchangeScenarios.IsAutoDisabled
		|	AND NOT DataExchangeScenarios.DeletionMark";
	
	Array = Query.Execute().Unload().UnloadColumn("Ref");
	DisabledScenarios.LoadValues(Array);
	
EndProcedure

#EndRegion