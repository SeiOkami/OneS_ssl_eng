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
	
	CheckCanUseForm(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	InitializeFormAttributes();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetNavigationNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If InitialExport Then
		WarningText = NStr("en = 'Do you want to cancel the initial data export?';");
	Else
		WarningText = NStr("en = 'Do you want to cancel the data export?';");
	EndIf;
	
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	Notify("DataExchangeCompleted");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeNavigationNumber(-1);
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	CloseParameter = Undefined;
	If DataExportCompleted Then
		CloseParameter = ExchangeNode;
	EndIf;
	
	ForceCloseForm = True;
	Close(CloseParameter);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ConnectionSettings(Command)
	
	Filter              = New Structure("Peer", ExchangeNode);
	FillingValues = New Structure("Peer", ExchangeNode);
	
	ClosingNotification1 = New NotifyDescription("ConnectionSettingsCompletion", ThisObject);
	
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(
		Filter,
		FillingValues,
		"DataExchangeTransportSettings",
		ThisObject,
		,
		,
		ClosingNotification1);
	
EndProcedure

#EndRegion

#Region Private

#Region ConnectionParametersCheck

&AtClient
Procedure OnStartTestConnection()
	
	ContinueWait = True;
	
	If ConnectOverExternalConnection Then
		If CommonClient.FileInfobase() Then
			CommonClient.RegisterCOMConnector(False);
		EndIf;
	EndIf;
	
	OnStartTestConnectionAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForTestConnection",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionTest();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForTestConnection()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForTestConnection",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionTest();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionTest()
	
	OnCompleteConnectionTestAtServer();
	
	If TransportSettingAvailable
		And Not ConnectionCheckCompleted Then
		SetNavigationNumber(2); // Set up connection.
	Else
		ChangeNavigationNumber(+1);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartTestConnectionAtServer(ContinueWait)
	
	If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
		And (PromptForPassword Or ValueIsFilled(Endpoint)) Then
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode, WSPassword);
	Else
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeNode, TransportKind);
	EndIf;
	ConnectionSettings.Insert("ExchangeMessagesTransportKind", TransportKind);
	
	ConnectionSettings.Insert("ExchangePlanName", DataExchangeCached.GetExchangePlanName(ExchangeNode));
	ConnectionSettings.Insert("CorrespondentExchangePlanName", 
		DataExchangeCached.GetNameOfCorrespondentExchangePlan(ExchangeNode));
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ModuleSetupWizard.OnStartTestConnection(
		ConnectionSettings, ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForTestConnection(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteConnectionTestAtServer()
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteConnectionTest(
		ConnectionCheckHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.ConnectionIsSet
			And CompletionStatus.Result.ConnectionAllowed;
			
		If Not ConnectionCheckCompleted
			And Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ConnectionSettingsCompletion(Result, AdditionalParameters) Export
	
	InitializeTransportParameters();
	
EndProcedure

#EndRegion

#Region ChangeRecords

&AtClient
Procedure OnStartChangeRegistration()
	
	ContinueWait = True;
	OnStartChangesRegistrationAtServer(ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.InitIdleHandlerParameters(
			DataRegistrationIdleHandlerParametersForInitialExport);
			
		AttachIdleHandler("OnWaitForChangeRegistration",
			DataRegistrationIdleHandlerParametersForInitialExport.CurrentInterval, True);
	Else
		OnCompleteChangeRegistration();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForChangeRegistration()
	
	ContinueWait = False;
	OnWaitForChangeRegistrationAtServer(DataRegistrationHandlerParametersForInitialExport, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataRegistrationIdleHandlerParametersForInitialExport);
		
		AttachIdleHandler("OnWaitForChangeRegistration",
			DataRegistrationIdleHandlerParametersForInitialExport.CurrentInterval, True);
	Else
		DataRegistrationIdleHandlerParametersForInitialExport = Undefined;
		OnCompleteChangeRegistration();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteChangeRegistration()
	
	OnCompleteChangeRegistrationAtServer();
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtServer
Procedure OnStartChangesRegistrationAtServer(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	RegistrationSettings = New Structure;
	RegistrationSettings.Insert("ExchangeNode", ExchangeNode);
	
	ModuleSetupWizard.OnStartRecordDataForInitialExport(
		RegistrationSettings, DataRegistrationHandlerParametersForInitialExport, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitForChangeRegistrationAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForRecordDataForInitialExport(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteChangeRegistrationAtServer()
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteDataRecordingForInitialExport(
		DataRegistrationHandlerParametersForInitialExport, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ChangesRegistrationCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		ChangesRegistrationCompleted = CompletionStatus.Result.DataRegistered;
			
		If Not ChangesRegistrationCompleted
			And Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region DataExport

&AtClient
Procedure OnStartExportDataForMapping()
	
	ProgressPercent = 0;
	
	ContinueWait = True;
	OnStartDataExportToMapAtServer(ContinueWait);
	
	If ContinueWait Then
		
		If IsExchangeWithApplicationInService Then
			DataExchangeClient.InitIdleHandlerParameters(
				MappingDataExportIdleHandlerParameters);
				
			AttachIdleHandler("OnWaitForExportDataForMapping",
				MappingDataExportIdleHandlerParameters.CurrentInterval, True);
		Else
			CompletionNotification2 = New NotifyDescription("ExportMappingDataCompletion", ThisObject);
		
			IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
			IdleParameters.OutputIdleWindow = False;
			IdleParameters.OutputProgressBar = UseProgress;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("DataExportForMappingProgress", ThisObject);
			
			TimeConsumingOperationsClient.WaitCompletion(MappingDataExportHandlerParameters.BackgroundJob,
				CompletionNotification2, IdleParameters);
		EndIf;
			
	Else
			
		OnCompleteDataExportForMapping();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForExportDataForMapping()
	
	ContinueWait = False;
	OnWaitDataExportToMapAtServer(MappingDataExportHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(MappingDataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForExportDataForMapping",
			MappingDataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		MappingDataExportIdleHandlerParameters = Undefined;
		OnCompleteDataExportForMapping();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataExportForMapping()
	
	ProgressPercent = 100;
	
	OnCompleteDataExportForMappingAtServer();
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure ExportMappingDataCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		OnCompleteDataExportForMapping();
	EndIf;
	
EndProcedure

&AtClient
Procedure DataExportForMappingProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	ProgressStructure = Progress.Progress;
	If ProgressStructure <> Undefined Then
		ProgressPercent = ProgressStructure.Percent;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartDataExportToMapAtServer(ContinueWait)
	
	ExportSettings1 = New Structure;
	
	If IsExchangeWithApplicationInService Then
		ExportSettings1.Insert("Peer", ExchangeNode);
		ExportSettings1.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	Else
		ExportSettings1.Insert("ExchangeNode", ExchangeNode);
		ExportSettings1.Insert("TransportKind", TransportKind);
		
		If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
			And PromptForPassword Then
			ExportSettings1.Insert("WSPassword", WSPassword);
		EndIf;
		
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	EndIf;
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnStartExportDataForMapping(
		ExportSettings1, MappingDataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitDataExportToMapAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnWaitForExportDataForMapping(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteDataExportForMappingAtServer()
	
	If IsExchangeWithApplicationInService Then
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	Else
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	EndIf;
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		DataExportCompleted = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard.OnCompleteDataExportForMapping(
		MappingDataExportHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		DataExportCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		DataExportCompleted = CompletionStatus.Result.DataExported1;
			
		If Not DataExportCompleted
			And Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormInitializationOnCreate

&AtServer
Procedure CheckCanUseForm(Cancel = False)
	
	// It is required to pass the parameters of data export execution.
	If Not Parameters.Property("ExchangeNode") Then
		MessageText = NStr("en = 'The form cannot be opened manually.';");
		Common.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	If DataExchangeCached.IsDistributedInfobaseNode(Parameters.ExchangeNode) Then
		MessageText = NStr("en = 'Initial export is not supported for distributed infobase nodes.';");
		Common.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	ExchangeNode = Parameters.ExchangeNode;
	
	If Parameters.Property("InitialExport") Then
		DataExportMode = "InitialExport";
		InitialExport = True;
	Else
		DataExportMode = "StandardExport";
	EndIf;
	
	ApplicationDescription = String(ExchangeNode);
	
	Parameters.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	InitializeTransportParameters();
		
	SetApplicationDescriptionInFormLabels();
	
EndProcedure

&AtServer
Procedure InitializeTransportParameters()
	
	TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeNode);
	TransportSettings.Property("DefaultExchangeMessagesTransportKind", TransportKind);
	TransportSettings.Property("WSCorrespondentEndpoint", Endpoint);
	
	If Not ValueIsFilled(TransportKind) Then
		TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode;
	EndIf;
	
	ConnectOverExternalConnection = (TransportKind = Enums.ExchangeMessagesTransportTypes.COM);
	
	UseProgress = Not IsExchangeWithApplicationInService
		And Not TransportKind = Enums.ExchangeMessagesTransportTypes.WS
		And Not TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode;
		
	PromptForPassword              = False;
	ConnectionCheckCompleted = False;
	DataExportCompleted      = False;
	
	TransportSettingAvailable  = Not (IsExchangeWithApplicationInService
		Or TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
	
	If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
			
		TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode);
		
		PromptForPassword = Not (TransportSettings.WSRememberPassword
			Or DataExchangeServer.DataSynchronizationPasswordSpecified(ExchangeNode));
			
	ElsIf TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
			
		ConnectionCheckCompleted = True;
		DataExportCompleted      = True;
		
	EndIf;
	
	FillNavigationTable();
	
EndProcedure

&AtServer
Procedure SetApplicationDescriptionInFormLabels()
	
	Items.PasswordLabelDecoration.Title = 
		StrTemplate(Items.PasswordLabelDecoration.Title, ApplicationDescription);
	
	Items.DataExportNoProgressBarLabelDecoration.Title = 
		StrTemplate(Items.DataExportNoProgressBarLabelDecoration.Title, ApplicationDescription);
	
	Items.DataExportProgressLabelDecoration.Title = 
		StrTemplate(Items.DataExportProgressLabelDecoration.Title, ApplicationDescription);
	
	Items.ExportCompletedLabelDecoration.Title =
		StrTemplate(Items.ExportCompletedLabelDecoration.Title, ApplicationDescription);
	
EndProcedure

#EndRegion

#Region WizardScenarios

&AtServer
Function AddNavigationTableRow(MainPageName, NavigationPageName, DecorationPageName = "")
	
	NavigationsString = NavigationTable.Add();
	NavigationsString.NavigationNumber = NavigationTable.Count();
	NavigationsString.MainPageName = MainPageName;
	NavigationsString.NavigationPageName = NavigationPageName;
	NavigationsString.DecorationPageName = DecorationPageName;
	
	Return NavigationsString;
	
EndFunction

&AtServer
Procedure FillNavigationTable()
	
	NavigationTable.Clear();
	
	NewNavigation = AddNavigationTableRow("StartPage", "PageNavigationStart");
	NewNavigation.OnOpenHandlerName = "Attachable_BeginningPageOnOpen1";
	
	If TransportSettingAvailable Then
		NewNavigation = AddNavigationTableRow("ConnectionSettingsPage", "PageNavigationFollowUp");
		NewNavigation.OnOpenHandlerName = "Attachable_ConnectionSettingsPageOnOpen";
	EndIf;
	
	If PromptForPassword Then
		NewNavigation = AddNavigationTableRow("PasswordRequestPage", "PageNavigationFollowUp");
		NewNavigation.OnNavigationToNextPageHandlerName = "Attachable_PasswordRequestPageOnGoNext";
	EndIf;
	
	If Not TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		NewNavigation = AddNavigationTableRow("ConnectionTestPage", "PageNavigationWait");
		NewNavigation.TimeConsumingOperation = True;
		NewNavigation.TimeConsumingOperationHandlerName = "Attachable_ConnectionCheckPageTimeConsumingOperation";
	EndIf;
	
	NewNavigation = AddNavigationTableRow("ChangeRecordingPage", "PageNavigationWait");
	NewNavigation.OnOpenHandlerName = "Attachable_ChangeRegistrationPageOnOpen";
	NewNavigation.TimeConsumingOperation = True;
	NewNavigation.TimeConsumingOperationHandlerName = "Attachable_ChangeRegistrationPageTimeConsumingOperation";
	
	If Not TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		If UseProgress Then
			NewNavigation = AddNavigationTableRow("ExportDataProgressPage", "PageNavigationWait");
		Else
			NewNavigation = AddNavigationTableRow("ExportDataWithoutProgressPage", "PageNavigationWait");
		EndIf;
		NewNavigation.OnOpenHandlerName = "Attachable_DataExportPageOnOpen";
		NewNavigation.TimeConsumingOperation = True;
		NewNavigation.TimeConsumingOperationHandlerName = "Attachable_DataExportPageTimeConsumingOperation";
	EndIf;
	
	NewNavigation = AddNavigationTableRow("EndPage", "PageNavigationEnd");
	NewNavigation.OnOpenHandlerName = "Attachable_EndPageOnOpen";
	
EndProcedure

#EndRegion

#Region NavigationEventHandlers

&AtClient
Function Attachable_BeginningPageOnOpen1(Cancel, SkipPage, IsMoveNext)
	
	Items.DataExportMode.Enabled = Not InitialExport;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionSettingsPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	SkipPage = IsMoveNext;
	
	Return Undefined;
		
EndFunction

&AtClient
Function Attachable_PasswordRequestPageOnGoNext(Cancel)
	
	If Not PromptForPassword Then
		Return Undefined;
	EndIf;
	
	If IsBlankString(WSPassword) Then
		CommonClient.MessageToUser(
			NStr("en = 'Please enter the password.';"), , "WSPassword", , Cancel);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckPageTimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartTestConnection();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ChangeRegistrationPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If Not ConnectionCheckCompleted Then
		SkipPage = True;
		Return Undefined;
	Else
		If DataExportMode = "StandardExport" Then
			SkipPage = True;
			ChangesRegistrationCompleted = True;
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ChangeRegistrationPageTimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartChangeRegistration();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	SkipPage = Not ConnectionCheckCompleted
		Or Not ChangesRegistrationCompleted;
		
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportPageTimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartExportDataForMapping();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_EndPageOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If Not ConnectionCheckCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.CompletionPageConnectionCheckError;
	ElsIf Not ChangesRegistrationCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.ChangesRegistrationErrorPage;
	ElsIf Not DataExportCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.DataExportErrorPage;
	Else
		Items.CompletionStatusPanel.CurrentPage = Items.SuccessfulCompletionPage;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region AdditionalNavigationHandlers

&AtClient
Procedure ChangeNavigationNumber(Iterator_SSLy)
	
	ClearMessages();
	
	SetNavigationNumber(NavigationNumber + Iterator_SSLy);
	
EndProcedure

&AtClient
Procedure SetNavigationNumber(Val Value)
	
	IsMoveNext = (Value > NavigationNumber);
	
	NavigationNumber = Value;
	
	If NavigationNumber < 1 Then
		
		NavigationNumber = 1;
		
	EndIf;
	
	NavigationNumberOnChange(IsMoveNext);
	
EndProcedure

&AtClient
Procedure NavigationNumberOnChange(Val IsMoveNext)
	
	// Executing navigation event handlers.
	ExecuteNavigationEventHandlers(IsMoveNext);
	
	// Setting page view.
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	Items.PanelMain.CurrentPage  = Items[NavigationRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[NavigationRowCurrent.NavigationPageName];
	
	Items.NavigationPanel.CurrentPage.Enabled = Not (IsMoveNext And NavigationRowCurrent.TimeConsumingOperation);
	
	// Setting the default button.
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		ConfirmButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If ConfirmButton <> Undefined Then
			
			ConfirmButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsMoveNext And NavigationRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteNavigationEventHandlers(Val IsMoveNext)
	
	// Navigation event handlers.
	If IsMoveNext Then
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber - 1));
		
		If NavigationRows.Count() > 0 Then
			NavigationRow = NavigationRows[0];
		
			// OnNavigationToNextPage handler.
			If Not IsBlankString(NavigationRow.OnNavigationToNextPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnNavigationToNextPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetNavigationNumber(NavigationNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	Else
		
		NavigationRows = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber + 1));
		
		If NavigationRows.Count() > 0 Then
			NavigationRow = NavigationRows[0];
		
			// OnNavigationToPreviousPage handler.
			If Not IsBlankString(NavigationRow.OnSwitchToPreviousPageHandlerName)
				And Not NavigationRow.TimeConsumingOperation Then
				
				ProcedureName = "[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRow.OnSwitchToPreviousPageHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetNavigationNumber(NavigationNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	EndIf;
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	If NavigationRowCurrent.TimeConsumingOperation And Not IsMoveNext Then
		
		SetNavigationNumber(NavigationNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(NavigationRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, SkipPage, IsMoveNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsMoveNext Then
				
				SetNavigationNumber(NavigationNumber + 1);
				
				Return;
				
			Else
				
				SetNavigationNumber(NavigationNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTimeConsumingOperationHandler()
	
	NavigationRowsCurrent = NavigationTable.FindRows(New Structure("NavigationNumber", NavigationNumber));
	
	If NavigationRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'The page to display is not specified.';");
	EndIf;
	
	NavigationRowCurrent = NavigationRowsCurrent[0];
	
	// TimeConsumingOperationProcessing handler.
	If Not IsBlankString(NavigationRowCurrent.TimeConsumingOperationHandlerName) Then
		
		ProcedureName = "[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationRowCurrent.TimeConsumingOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetNavigationNumber(NavigationNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetNavigationNumber(NavigationNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetNavigationNumber(NavigationNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			And StrFind(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion
