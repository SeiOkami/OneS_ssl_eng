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
	
	AccountPasswordRecoveryAddress = Parameters.AccountPasswordRecoveryAddress;
	CloseOnSynchronizationDone           = Parameters.CloseOnSynchronizationDone;
	InfobaseNode                    = Parameters.InfobaseNode;
	ShouldExitApp                   = Parameters.ShouldExitApp;
	
	Parameters.Property("IsExchangeWithApplicationInService", ExchangeBetweenSaaSApplications);
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	If Not ValueIsFilled(InfobaseNode) Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			InfobaseNode = DataExchangeServer.MasterNode();
		Else
			DataExchangeServer.ReportError(NStr("en = 'Cannot open the form. The form parameters are not specified.';"), Cancel);
			Return;
		EndIf;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	CorrespondentDescription = String(InfobaseNode);

	TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(InfobaseNode);
	MessagesTransportKind = TransportSettings.DefaultExchangeMessagesTransportKind;
	CorrespondentEndpoint = TransportSettings.WSCorrespondentEndpoint;
	
	ExecuteDataSending = InformationRegisters.CommonInfobasesNodesSettings.ExecuteDataSending(InfobaseNode);
	
	SetPrivilegedMode(False);
	
	ExchangeViaInternalPublication = MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
		And ValueIsFilled(CorrespondentEndpoint);
	
	// Initialize user roles.
	DataExchangeAdministrationRoleAssigned = DataExchangeServer.HasRightsToAdministerExchanges();
	RoleAvailableFullAccess                     = Users.IsFullUser();
	
	NoLongSynchronizationPrompt = True;
	CheckVersionDifference       = Not ExchangeBetweenSaaSApplications;
	
	ConnectOverExternalConnection = (MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM);
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS")
		And DataExchangeServer.IsStandaloneWorkplace() Then
		
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		
		NoLongSynchronizationPrompt = Not ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag();
		CheckVersionDifference       = False;
		
	EndIf;
	
	// Set a form title.
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Synchronize data with %1';"), CorrespondentDescription);
	
	// 
	// 
	// 
	// 
	UseCurrentUserForAuthentication = False;
	UseSavedAuthenticationParameters    = False;
	SynchronizationPasswordSpecified                          = False;
	SyncPasswordSaved                       = False; // The password is saved in a safe storage (available in the background job)
	WSPassword                                          = "";
	
	If MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		If DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode) Then
			
			// It is DIB and WS exchange, using the current user and password from the session.
			UseCurrentUserForAuthentication = True;
			SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
			
		Else
			
			// 
			TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
			SynchronizationPasswordSpecified = TransportSettings.WSRememberPassword;
			If SynchronizationPasswordSpecified Then
				SyncPasswordSaved = True;
				UseSavedAuthenticationParameters = True;
			Else
				// Using the session data only if it is not available in the register.
				SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
				If SynchronizationPasswordSpecified Then
					UseSavedAuthenticationParameters = True;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	HasErrors = ((DataExchangeServer.MasterNode() = InfobaseNode) And ConfigurationChanged());
	
	BackgroundJobUseProgress = Not ExchangeBetweenSaaSApplications
		And Not ExchangeViaInternalPublication
		And Not (MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS);
		
	ActivePasswordPromptPage = Not HasErrors
		And (MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS)
		And Not (SynchronizationPasswordSpecified And NoLongSynchronizationPrompt)
		And Not ExchangeViaInternalPublication;
		
	Items.LongSyncWarningGroup.Visible = ActivePasswordPromptPage And Not NoLongSynchronizationPrompt;
	Items.PromptForPasswordGroup.Visible                     = ActivePasswordPromptPage And Not SynchronizationPasswordSpecified;
		
	WindowOptionsKey = ?(SynchronizationPasswordSpecified And NoLongSynchronizationPrompt,
		"SynchronizationPasswordSpecified", "") + "/" + ?(NoLongSynchronizationPrompt, "NoLongSynchronizationPrompt", "");
		
	FillNavigationTable();
	
	CheckWhetherTheExchangeCanBeStarted(InfobaseNode, IsNodeLocked);
	
	If ExchangeViaInternalPublication Then
		ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
		HasNodeScheduledExchange = ModuleDataExchangeInternalPublication.HasNodeScheduledExchange(
			InfobaseNode, 
			ScenarioUsingInternalPublication,
			IDOfExchangeViaInternalPublication);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsNodeLocked Then
		
		Step = 2;
		
	Else
		
		Step = 1;
		
	EndIf;
	
	SetNavigationNumber(Step);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If TimeConsumingOperation Then
		EndExecutingTimeConsumingOperation(IDBackgroundJob);
	EndIf;
	
	If ValueIsFilled(FormReopeningParameters)
		And FormReopeningParameters.Property("NewDataSynchronizationSetting") Then
		
		NewDataSynchronizationSetting = FormReopeningParameters.NewDataSynchronizationSetting;
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",                    NewDataSynchronizationSetting);
		FormParameters.Insert("AccountPasswordRecoveryAddress", AccountPasswordRecoveryAddress);
		
		OpeningParameters = New Structure;
		OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
		
		DataExchangeClient.OpenFormAfterCloseCurrentOne(ThisObject,
			"DataProcessor.DataExchangeExecution.Form.Form", FormParameters, OpeningParameters);
		
	Else
		SaveLongSynchronizationRequestFlag();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = EventLogFilterData(InfobaseNode);
	OpenForm("DataProcessor.EventLog.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	DataExchangeClient.InstallConfigurationUpdate(ShouldExitApp);
	
EndProcedure

&AtClient
Procedure RestartApplication(Command)

	Exit(False, True);

EndProcedure

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OpenInstructionHowToChangeDataSynchronizationPassword(AccountPasswordRecoveryAddress);
	
EndProcedure

&AtClient
Procedure ExecuteExchange(Command)
	
	ExecuteMoveNext();
	
EndProcedure

&AtClient
Procedure ContinueSync(Command)
	
	NavigationNumber = NavigationNumber - 1;
	SetNavigationNumber(NavigationNumber + 1);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// 
////////////////////////////////////////////////////////////////////////////////

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

&AtClient
Procedure ExecuteMoveNext()
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Procedure ChangeNavigationNumber(Iterator_SSLy)
	
	ClearMessages();
	SetNavigationNumber(NavigationNumber + Iterator_SSLy);
	
EndProcedure

&AtClient
Procedure SetNavigationNumber(Val Value)
	
	IsMoveNext = (Value > NavigationNumber);
	
	NavigationNumber = Value;
	
	If NavigationNumber < 0 Then
		NavigationNumber = 0;
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
	
	Items.DataExchangeExecution.CurrentPage = Items[NavigationRowCurrent.MainPageName];
	
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
				
				CalculationResult = Eval(ProcedureName);
				
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
				
				CalculationResult = Eval(ProcedureName);
				
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
		
		CalculationResult = Eval(ProcedureName);
		
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
		
		CalculationResult = Eval(ProcedureName);
		
		If Cancel Then
			
			If VersionDifferenceErrorOnGetData <> Undefined And VersionDifferenceErrorOnGetData.HasError Then
				
				ProcessVersionDifferenceError();
				Return;
				
			EndIf;
			
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

&AtServer
Function NavigationTableNewRow(MainPageName,
		OnOpenHandlerName = "",
		TimeConsumingOperation = False,
		TimeConsumingOperationHandlerName = "")
		
	NewRow = NavigationTable.Add();
	
	NewRow.NavigationNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	
	NewRow.OnNavigationToNextPageHandlerName = "";
	NewRow.OnSwitchToPreviousPageHandlerName = "";
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = TimeConsumingOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
	Return NewRow;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure RunMoveNext()
	
	GoToNext      = True;
	ExecuteMoveNext();
	
EndProcedure

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.DataExchangeExecution.CurrentPage = Items.ExchangeCompletion;
	Items.ExchangeCompletionStatus.CurrentPage = Items.VersionsDifferenceError;
	Items.ActionsPanel.CurrentPage = Items.ActionsContinueCancel;
	Items.ContinueSync.DefaultButton = True;
	Items.DecorationVersionsDifferenceError.Title = VersionDifferenceErrorOnGetData.ErrorText;
	
	CheckVersionDifference = False;
	
EndProcedure

&AtClient
Procedure SaveLongSynchronizationRequestFlag()
	
	Settings = Undefined;
	If SaveLongSynchronizationRequestFlagServer(Not NoLongSynchronizationPrompt, Settings) Then
		ChangedSettings = New Array;
		ChangedSettings.Add(Settings);
		Notify("UserSettingsChanged", ChangedSettings, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure InitializeDataProcessorVariables()
	
	// Initialize data processor variables.
	ProgressPercent                   = 0;
	MessageFileIDInService = "";
	TimeConsumingOperationID     = "";
	ProgressAdditionalInformation             = "";
	TimeConsumingOperation                  = False;
	TimeConsumingOperationCompleted         = False;
	TimeConsumingOperationCompletedWithError = False;
	
EndProcedure

&AtServer
Procedure CheckWhetherTransferToNewExchangeIsRequired()
	
	ArrayOfMessages = GetUserMessages(True);
	
	If ArrayOfMessages = Undefined Then
		Return;
	EndIf;
	
	Count = ArrayOfMessages.Count();
	If Count = 0 Then
		Return;
	EndIf;
	
	Message      = ArrayOfMessages[Count-1];
	MessageText = Message.Text;
	
	// A subsystem ID is deleted from the message if necessary.
	If StrStartsWith(MessageText, "{MigrationToNewExchangeDone}") Then
		
		MessageData = Common.ValueFromXMLString(MessageText);
		
		If MessageData <> Undefined
			And TypeOf(MessageData) = Type("Structure") Then
			
			ExchangePlanName                    = MessageData.ExchangePlanNameToMigrateToNewExchange;
			ExchangePlanNodeCode                = MessageData.Code;
			NewDataSynchronizationSetting = ExchangePlans[ExchangePlanName].FindByCode(ExchangePlanNodeCode);
			
			BackgroundJobCompleteResult.AdditionalResultData.Insert("FormReopeningParameters",
				New Structure("NewDataSynchronizationSetting", NewDataSynchronizationSetting));
				
			BackgroundJobCompleteResult.AdditionalResultData.Insert("ForceCloseForm", True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InitializeAuthenticationParameters(AuthenticationParameters)
	
	If UseSavedAuthenticationParameters Then
		If Not SyncPasswordSaved Then
			AuthenticationParameters = New Structure;
			AuthenticationParameters.Insert("UseCurrentUser", UseCurrentUserForAuthentication);
		EndIf;
	Else
		AuthenticationParameters = New Structure;
		AuthenticationParameters.Insert("UseCurrentUser", UseCurrentUserForAuthentication);
		If Not SynchronizationPasswordSpecified Then
			AuthenticationParameters.Insert("Password", WSPassword);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TestConnection(HasConnection)
	
	AuthenticationParameters = Undefined;
	InitializeAuthenticationParameters(AuthenticationParameters);
	
	TestConnectionAtServer(HasConnection, AuthenticationParameters);
	
EndProcedure

&AtServer
Procedure TestConnectionAtServer(HasConnection, AuthenticationParameters)
	
	SetPrivilegedMode(True);
	ConnectionParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	DataSyncDisabled = False;
	ErrorMessageToUser = "";
	SettingCompleted = True;
	DataReceivedForMapping = False;
	
	HasConnection = DataExchangeWebService.CorrespondentConnectionEstablished(InfobaseNode,
		ConnectionParameters, ErrorMessageToUser, SettingCompleted, DataReceivedForMapping);
	
	If Not HasConnection Then
		ErrorMessage = NStr("en = 'Cannot connect to the web application. Reason: ""%1.""
			|Ensure that:
			| - The password is correct.
			| - The connection address is correct.
			| - The application is available.
			| - Web app synchronization is configured.
			|Then, restart synchronization.';");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, ErrorMessageToUser);
		If ActivePasswordPromptPage Then
			Common.MessageToUser(ErrorMessage);
		EndIf;
		DataSyncDisabled = True;
	ElsIf Not SettingCompleted Then
		ErrorMessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To continue, set up synchronization in ""%1"". The data exchange is canceled.';"),
			CorrespondentDescription);
		DataSyncDisabled = True;
	ElsIf DataReceivedForMapping Then
		ErrorMessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'To continue, open %1 and import the data mapping message. The data exchange is canceled.';"),
			CorrespondentDescription);
		DataSyncDisabled = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(InfobaseNode)
	
	EventsToFilter = New Array;
	EventsToFilter.Add(DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport));
	EventsToFilter.Add(DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataExport));
	
	DataExchangeStatesImport = DataExchangeServer.DataExchangesStates(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	DataExchangeStatesExport = DataExchangeServer.DataExchangesStates(InfobaseNode, Enums.ActionsOnExchange.DataExport);
	
	Result = New Structure;
	Result.Insert("EventLogEvent", EventsToFilter);
	Result.Insert("StartDate",    Min(DataExchangeStatesImport.StartDate, DataExchangeStatesExport.StartDate));
	Result.Insert("EndDate", Max(DataExchangeStatesImport.EndDate, DataExchangeStatesExport.EndDate));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function SaveLongSynchronizationRequestFlagServer(Val Flag, Settings = Undefined)
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS")
		And DataExchangeServer.IsStandaloneWorkplace() Then
		
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		MustSave = Flag <> ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag();
		
		If MustSave Then
			ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag(Flag, Settings);
		EndIf;
		
	Else
		MustSave = False;
	EndIf;
	
	Return MustSave;
EndFunction

&AtServerNoContext
Procedure EndExecutingTimeConsumingOperation(JobID)
	TimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

&AtServerNoContext
Function UpdateInstallationRequired()
	
	Return DataExchangeServer.UpdateInstallationRequired();
	
EndFunction

&AtServerNoContext
Function IsRestartRequired()
	
	Return Catalogs.ExtensionsVersions.ExtensionsChangedDynamically();
	
EndFunction

&AtServerNoContext
Procedure CheckWhetherTheExchangeCanBeStarted(ExchangeNode, LockSet)
	
	Cancel = False;
	DataExchangeServer.CheckWhetherTheExchangeCanBeStarted(ExchangeNode, Cancel);
	
	LockSet = Not Cancel;
	
EndProcedure

&AtClient
Procedure CheckWhetherTheExchangeCanStartProcessingWaiting()
	
	CheckWhetherTheExchangeCanBeStarted(InfobaseNode, IsNodeLocked);
	
	If IsNodeLocked Then
		ChangeNavigationNumber(+1);
	Else
		AttachIdleHandler("CheckWhetherTheExchangeCanStartProcessingWaiting", 15, True);
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_PageDataExchangeJobCheck_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If HasNodeScheduledExchange Then
		
		If ValueIsFilled(ScenarioUsingInternalPublication) Then
			
			Template = NStr("en = 'Synchronization is already scheduled for node ""%1"" 
                           |in scenario ""%2"".
                           |
                           |Click Next to cancel the scenario
                           |and start synchronization by the node.';");
			MessageText = StrTemplate(Template, String(InfobaseNode), String(ScenarioUsingInternalPublication));	

		Else
			
			Template = NStr("en = 'Synchronization is already in progress for node ""%1"".
                           |
                           |Click Next to terminate the current synchronization
                           |and restart it';");
			MessageText = StrTemplate(Template, String(InfobaseNode));

		EndIf;
		
		Items.StatusTaskQueued.Title = MessageText;
		
	Else
		
		SkipPage = True;
		
	EndIf;
		
	Return Undefined;
	
EndFunction

&AtServer
Procedure CancelQueueAndResumeOnServer()
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.CancelTaskQueue(InfobaseNode, 
	    ScenarioUsingInternalPublication,
		IDOfExchangeViaInternalPublication);
	
EndProcedure

&AtClient
Procedure CancelQueueAndResume(Command)
	CancelQueueAndResumeOnServer();
	ExecuteMoveNext();
EndProcedure

&AtClient
Function PluggableWaitingForSynchronizationToStartProcessingALongOperation(Cancel, GoToNext)
	
	If Not IsNodeLocked Then
		GoToNext = False;
		
		AttachIdleHandler("CheckWhetherTheExchangeCanStartProcessingWaiting", 15, True);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataImportOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If DataSyncDisabled Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataImportTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If DataSyncDisabled Then
		GoToNext = True;
	Else
		GoToNext = False;
		
		BackgroundJobCurrentAction = 1;
		BackgroundJobStartClient(BackgroundJobCurrentAction,
			"DataProcessors.DataExchangeExecution.StartDataExchangeExecution",
			Cancel);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportOnOpen(Cancel, SkipPage, IsMoveNext)
	
	If DataSyncDisabled Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If DataSyncDisabled Then
		GoToNext = True;
	Else
		GoToNext = False;
		OnStartExportData(Cancel);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_DataExportTimeConsumingOperationProcessingCompletion(Cancel, GoToNext)
	
	If TimeConsumingOperationCompleted
		And Not TimeConsumingOperationCompletedWithError Then
		DataExchangeServerCall.RecordDataExportInTimeConsumingOperationMode(
			InfobaseNode,
			OperationStartDate);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OnStartExportData(Cancel)
	
	If ExchangeBetweenSaaSApplications Then
		ContinueWait = True;
		OnStartExportDataAtServer(ContinueWait);
		
		If ContinueWait Then
			DataExchangeClient.InitIdleHandlerParameters(
				DataExportIdleHandlerParameters);
				
			AttachIdleHandler("OnWaitForExportData",
				DataExportIdleHandlerParameters.CurrentInterval, True);
		Else
			OnCompleteDataExport();
		EndIf;
	ElsIf ExchangeViaInternalPublication Then
		OnStartExportDataViaInternalPublicationAtServer();
		
		DataExchangeClient.InitIdleHandlerParameters(
			DataExportIdleHandlerParameters);

		AttachIdleHandler("OnWaitDataExportViaInternalPublication",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		BackgroundJobCurrentAction = 2;
		BackgroundJobStartClient(BackgroundJobCurrentAction,
			"DataProcessors.DataExchangeExecution.StartDataExchangeExecution", Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForExportData()
	
	ContinueWait = False;
	OnWaitForExportDataAtServer(DataExportHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForExportData",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDataExport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataExport()
	
	DataExported1 = False;
	ErrorMessage = "";
	
	OnCompleteDataUnloadAtServer(DataExportHandlerParameters, DataExported1, ErrorMessage);
	
	TimeConsumingOperationCompleted = True;
	TimeConsumingOperationCompletedWithError = Not DataExported1;
	HasErrors = HasErrors Or Not DataExported1;
	OutputErrorDescriptionToUser = True;
	ErrorMessageToUser = ErrorMessage;
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtServer
Procedure OnStartExportDataAtServer(ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ExportSettings1 = New Structure;
	ExportSettings1.Insert("Peer",               InfobaseNode);
	ExportSettings1.Insert("CorrespondentDataArea", CorrespondentDataArea);
	
	DataExportHandlerParameters = Undefined;
	ModuleInteractiveExchangeWizard.OnStartExportData(ExportSettings1,
		DataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForExportDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnWaitForExportData(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteDataUnloadAtServer(HandlerParameters, DataExported1, ErrorMessage)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		DataExported1 = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard.OnCompleteDataExport(HandlerParameters, CompletionStatus);
	HandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		DataExported1 = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		DataExported1 = CompletionStatus.Result.DataExported1;
		
		If Not DataExported1 Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer 
Procedure OnStartExportDataViaInternalPublicationAtServer()
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.RunDataExchangeManually(InfobaseNode, ParametersOfExchangeViaInternalPublication);
	
EndProcedure	

&AtClient
Procedure OnWaitDataExportViaInternalPublication()
	
	ContinueWait = False;
	OnWaitDataExportViaInternalPublicationAtServer(ParametersOfExchangeViaInternalPublication, ContinueWait);
	
	If ContinueWait Then
		DataExchangeClient.UpdateIdleHandlerParameters(DataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitDataExportViaInternalPublication",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDataExportViaInternalPublication();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure OnWaitDataExportViaInternalPublicationAtServer(ExchangeParameters, ContinueWait)
	
	ModuleDataExchangeInternalPublication = Common.CommonModule("DataExchangeInternalPublication");
	ModuleDataExchangeInternalPublication.OnWaitForExportData(ExchangeParameters, ContinueWait);
	
EndProcedure

&AtClient
Procedure OnCompleteDataExportViaInternalPublication()
		
	HasErrors = HasErrors Or ParametersOfExchangeViaInternalPublication.Cancel;
		
	OutputErrorDescriptionToUser = True;
	ErrorMessageToUser = ParametersOfExchangeViaInternalPublication.ErrorMessage;
	
	ChangeNavigationNumber(+1);
	
EndProcedure

&AtClient
Function Attachable_ExchangeCompletionOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.ActionsPanel.CurrentPage = Items.ActionsClose;
	Items.FormClose.DefaultButton = True;
	
	ExchangeCompletedWithErrorPage = ?(DataExchangeAdministrationRoleAssigned,
		Items.ExchangeCompletedWithErrorForAdministrator,
		Items.ExchangeCompletedWithError);
	
	If DataSyncDisabled Then
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedWithConnectionError;
		
	ElsIf HasErrors Then
		
		If UpdateRequired Or UpdateInstallationRequired() Then
			
			If RoleAvailableFullAccess Then 
				Items.ActionsPanel.CurrentPage = Items.ActionsInstallClose;
				Items.InstallUpdate.DefaultButton = True;
			EndIf;
			
			Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedWithErrorUpdateRequired;
			
			Items.PanelUpdateRequired.CurrentPage = ?(RoleAvailableFullAccess, 
				Items.UpdateRequiredFullAccess, Items.UpdateRequiredRestrictedAccess);
				
			Items.UpdateRequiredTextFullAccess.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Items.UpdateRequiredTextFullAccess.Title, CorrespondentDescription);
				
			Items.UpdateRequiredTextRestrictedAccess.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Items.UpdateRequiredTextRestrictedAccess.Title, CorrespondentDescription);
				
		ElsIf IsRestartRequired() Then
				
			Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeIsCompletedWithErrorRebootIsRequired;
			Items.ActionsPanel.CurrentPage = Items.ActionsReload;
				
		ElsIf ErrorAssigningIDForNode Then
			
			Items.ExchangeCompletionStatus.CurrentPage = Items.ErrorIDAssignmentForNode;			
			
		Else
				
			Items.ExchangeCompletionStatus.CurrentPage = ExchangeCompletedWithErrorPage;
			
			If OutputErrorDescriptionToUser Then
				CommonClient.MessageToUser(ErrorMessageToUser);
			EndIf;
			
		EndIf;
		
	Else
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeSucceeded;
		
	EndIf;
	
	// 
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_ExchangeCompletionTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	Notify("DataExchangeCompleted");
	
	If CloseOnSynchronizationDone
		And Not DataSyncDisabled
		And Not HasErrors Then
		
		Close();
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Function Attachable_UserPasswordRequestOnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.ForgotPassword.Visible = Not IsBlankString(AccountPasswordRecoveryAddress);
	
	Items.ExecuteExchange.DefaultButton = True;
	
	Return Undefined;
	
EndFunction

&AtClient
Function Attachable_UserPasswordRequestOnGoNext(Cancel)
	
	If Not SynchronizationPasswordSpecified
		And IsBlankString(WSPassword) Then
		CommonClient.MessageToUser(NStr("en = 'Please enter the password.';"), , "WSPassword", , Cancel);
		Return Undefined;
	EndIf;
	
	SaveLongSynchronizationRequestFlag();
	
EndFunction

&AtClient
Function Attachable_ConnectionTestWaitingTimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If ConnectOverExternalConnection Then
		If CommonClient.FileInfobase() Then
			CommonClient.RegisterCOMConnector(False);
		EndIf;
		Return Undefined;
	EndIf;
	
	HasConnection = False;
	TestConnection(HasConnection);
	If HasConnection Then
		WSPassword = String(New UUID);
		UseSavedAuthenticationParameters = True;
		SynchronizationPasswordSpecified = True;
	Else
		If ActivePasswordPromptPage Then
			Cancel = True;
		EndIf;
	EndIf;
	GoToNext = Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure BackgroundJobStartClient(Action, JobName, Cancel)
	
	JobParameters = New Structure;
	JobParameters.Insert("JobName",                          JobName);
	JobParameters.Insert("Cancel",                               Cancel);
	JobParameters.Insert("InfobaseNode",              InfobaseNode);
	JobParameters.Insert("ExecuteImport1",                   BackgroundJobCurrentAction = 1);
	JobParameters.Insert("ExecuteExport2",                   BackgroundJobCurrentAction = 2);
	JobParameters.Insert("ExchangeMessagesTransportKind",        MessagesTransportKind);
	JobParameters.Insert("TimeConsumingOperation",                  TimeConsumingOperation);
	JobParameters.Insert("TimeConsumingOperationID",     TimeConsumingOperationID);
	JobParameters.Insert("MessageFileIDInService", MessageFileIDInService);
	
	Result = BackgroundJobStartAtServer(JobParameters, VersionDifferenceErrorOnGetData, CheckVersionDifference);
	
	If Result = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	If Result.Status = "Running" Then
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		If BackgroundJobUseProgress Then
			IdleParameters.OutputProgressBar     = True;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("BackgroundJobExecutionProgress", ThisObject);
			IdleParameters.Interval                       = 1;
		EndIf;
		
		CompletionNotification2 = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitCompletion(Result, CompletionNotification2, IdleParameters);
		
	Else
		BackgroundJobCompleteResult = Result;
		AttachIdleHandler("BackgroundJobExecutionResult", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	
	BackgroundJobCompleteResult = Result;
	BackgroundJobExecutionResult();
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ProgressStructure      = Progress.Progress;
		
		AdditionalProgressParameters = Undefined;
		If Not ProgressStructure.Property("AdditionalParameters", AdditionalProgressParameters) Then
			Return;
		EndIf;
		
		If Not AdditionalProgressParameters.Property("DataExchange") Then
			Return;
		EndIf;
		
		ProgressPercent       = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionResult()
	
	BackgroundJobGetResultAtServer();
	
	// 
	// 
	If TimeConsumingOperation Then
		RetryCountOnConnectionError = 0;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 0.1, True);
	Else
		AttachIdleHandler("TimeConsumingOperationCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationIdleHandler()
	
	TimeConsumingOperationCompletedWithError = False;
	ErrorMessage                   = "";
	
	AuthenticationParameters = Undefined;
	InitializeAuthenticationParameters(AuthenticationParameters);
	
	ActionState = TimeConsumingOperationStateForInfobaseNode(
		TimeConsumingOperationID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorMessage);
	
	If ActionState = Undefined
		And RetryCountOnConnectionError < 5 Then
		RetryCountOnConnectionError = RetryCountOnConnectionError + 1;
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
		Return;
	EndIf;
	
	If ActionState = "Active" Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 30, True);
	Else
		If ActionState <> "Completed" Then
			TimeConsumingOperationCompletedWithError = True;
			HasErrors                          = True;
		EndIf;
		
		TimeConsumingOperation              = False;
		TimeConsumingOperationCompleted     = True;
		TimeConsumingOperationID = "";
		
		AttachIdleHandler("TimeConsumingOperationCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationCompletion()
	
	If BackgroundJobUseProgress Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	If TimeConsumingOperationCompletedWithError Then
		MessageFileIDInService = "";
		DataExchangeServerCall.WriteExchangeFinishWithError(
			InfobaseNode,
			?(BackgroundJobCurrentAction = 1, "DataImport", "DataExport"),
			OperationStartDate,
			ErrorMessage);
	Else
		
		// 
		// 
		If BackgroundJobCurrentAction = 1 
			And ValueIsFilled(MessageFileIDInService) Then
				
			BackgroundJobStartClient(BackgroundJobCurrentAction,
				"DataProcessors.DataExchangeExecution.ImportFileDownloadedFromInternet",
				False);
				
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(MessageFileIDInService) Then
		AfterCompleteBackgroundJob();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCompleteBackgroundJob()
	
	// Data exchange has been updated to a later version. Close the form and open it with the new parameters.
	If BackgroundJobCompleteResult.AdditionalResultData.Property("ForceCloseForm") 
		And BackgroundJobCompleteResult.AdditionalResultData.ForceCloseForm Then
		FormReopeningParameters = BackgroundJobCompleteResult.AdditionalResultData.FormReopeningParameters;
		Close();
	EndIf;
	
	// Go further with a one second delay to display the progress bar 100%.
	AttachIdleHandler("RunMoveNext", 0.1, True);
	
EndProcedure

&AtServer
Function BackgroundJobStartAtServer(JobParameters, VersionDifferenceErrorOnGetData, CheckVersionDifference)
	
	If JobParameters.ExecuteImport1 Then
		
		If CheckVersionDifference Then
			DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
		EndIf;
		
		DescriptionTemplate1 = NStr("en = 'Importing data from %1';");
		
	Else
		DescriptionTemplate1 = NStr("en = 'Exporting data to %1';");
	EndIf;
	
	JobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		DescriptionTemplate1, JobParameters.InfobaseNode);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	ExecutionParameters.WaitCompletion = 0;
	
	OperationStartDate = CurrentSessionDate();
	JobParameters.Insert("OperationStartDate", OperationStartDate);
	
	AuthenticationParameters = Undefined;
	If Not SyncPasswordSaved Then
		If UseCurrentUserForAuthentication Then
			AuthenticationParameters = New Structure;
			AuthenticationParameters.Insert("UseCurrentUser", True);
			AuthenticationParameters.Insert("Password",
				DataExchangeServer.DataSynchronizationPassword(InfobaseNode));
		Else
			AuthenticationParameters = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
		EndIf;
	EndIf;
	JobParameters.Insert("AuthenticationParameters", AuthenticationParameters);
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		JobParameters.JobName,
		JobParameters,
		ExecutionParameters);
		
	IDBackgroundJob  = Result.JobID;
	BackgroundJobStorageAddress = Result.ResultAddress;
	
	Return Result;
	
EndFunction

&AtServer
Procedure BackgroundJobGetResultAtServer()
	
	If BackgroundJobCompleteResult = Undefined Then
		BackgroundJobCompleteResult = New Structure;
		BackgroundJobCompleteResult.Insert("Status", Undefined);
	EndIf;
	
	BackgroundJobCompleteResult.Insert("AdditionalResultData", New Structure());
	
	ErrorMessage = "";
	
	StandardErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot %1. See the Event log for details.';"),
		?(BackgroundJobCurrentAction = 1, NStr("en = 'receive data';"), NStr("en = 'send data';")));
	
	If BackgroundJobCompleteResult.Status = "Error" Then
		ErrorMessage = BackgroundJobCompleteResult.DetailErrorDescription;
		SetPrivilegedMode(True);
		DataExchangeServer.WriteExchangeFinishWithError(
			InfobaseNode,
			?(BackgroundJobCurrentAction = 1, "DataImport", "DataExport"),
			OperationStartDate,
			ErrorMessage);
		SetPrivilegedMode(False);
		
		ErrorText = NStr("en = 'Duplicate data synchronization settings are detected';", Common.DefaultLanguageCode()); 
		If Not IsBlankString(ErrorText) And StrFind(ErrorMessage, ErrorText) > 0 Then
			ErrorAssigningIDForNode = True;	
		EndIf;
				
	Else
		
		BackgroundExecutionResult = GetFromTempStorage(BackgroundJobStorageAddress);
		
		If BackgroundExecutionResult = Undefined Then
			ErrorMessage = StandardErrorPresentation;
		Else
			
			If BackgroundExecutionResult.ExecuteImport1 Then
				
				// Data on exchange rule version difference.
				VersionDifferenceErrorOnGetData = DataExchangeServer.VersionDifferenceErrorOnGetData();
				
				If VersionDifferenceErrorOnGetData <> Undefined
					And VersionDifferenceErrorOnGetData.HasError = True Then
					ErrorMessage = VersionDifferenceErrorOnGetData.ErrorText;
				EndIf;
				
				// Checking the transition to a new data exchange.
				CheckWhetherTransferToNewExchangeIsRequired();
				
				If BackgroundJobCompleteResult.AdditionalResultData.Property("FormReopeningParameters") Then
					Return;
				EndIf;
				
			EndIf;
			
			If BackgroundExecutionResult.Cancel And Not ValueIsFilled(ErrorMessage) Then
				ErrorMessage = StandardErrorPresentation;
			EndIf;
			
			FillPropertyValues(
				ThisObject,
				BackgroundExecutionResult,
				"TimeConsumingOperation, TimeConsumingOperationID, MessageFileIDInService");
			
			DeleteFromTempStorage(BackgroundJobStorageAddress);
			
		EndIf;
		
		BackgroundJobStorageAddress = Undefined;
		IDBackgroundJob  = Undefined;
		
	EndIf;
	
	// If errors occurred during data synchronization, record them.
	If ValueIsFilled(ErrorMessage) Then
		
		// If a long-running operation is started in the peer infobase, it must be completed.
		If Not TimeConsumingOperationCompleted Then
			EndExecutingTimeConsumingOperation(TimeConsumingOperationID);
		EndIf;
		
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		
		HasErrors = True;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function TimeConsumingOperationStateForInfobaseNode(
		TimeConsumingOperationID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorMessage)
		
	ActionState = Undefined;
	Try
		ActionState = DataExchangeInternal.TimeConsumingOperationStateForInfobaseNode(
			TimeConsumingOperationID,
			InfobaseNode,
			AuthenticationParameters,
			ErrorMessage);
	Except
		Information = ErrorInfo();
		ErrorMessage = ErrorProcessing.BriefErrorDescription(Information);
			
		WriteLogEvent(DataExchangeServer.DataExchangeEventLogEvent(),
			EventLogLevel.Error, , , ErrorProcessing.DetailErrorDescription(Information));
	EndTry;
		
	Return ActionState;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtServer
Procedure FillNavigationTable()
	
	NavigationTable.Clear();
	
	NavigationTableNewRow("PageDataSynchronizationUnavailable", "");
	
	If ExchangeViaInternalPublication Then
		NavigationTableNewRow("PageCheckExchangeTasks", "Attachable_PageDataExchangeJobCheck_OnOpen");	
	EndIf;

	NavigationTableNewRow("WaitForSynchronizationToStart", "", True, "PluggableWaitingForSynchronizationToStartProcessingALongOperation");
	
	// Initializing the current exchange scenario.
	If HasErrors Then
		
		NavigationTableNewRow("ExchangeCompletion", "Attachable_ExchangeCompletionOnOpen");
		
	Else
		
		If BackgroundJobUseProgress Then
			PageNameSynchronizationImport = "DataSynchronizationWaitProgressBarImport";
			PageNameSynchronizationExport = "DataSynchronizationWaitProgressBarExport";
		Else
			PageNameSynchronizationImport = "DataSynchronizationWait";
			PageNameSynchronizationExport = "DataSynchronizationWait";
		EndIf;
		
		If ExchangeBetweenSaaSApplications Or ExchangeViaInternalPublication Then
			// Send and receive.
			NavigationTableNewRow(PageNameSynchronizationExport, "Attachable_DataExportOnOpen", True, "Attachable_DataExportTimeConsumingOperationProcessing");
			NavigationTableNewRow(PageNameSynchronizationExport, , True, "Attachable_DataExportTimeConsumingOperationProcessingCompletion");
		Else
			
			If ActivePasswordPromptPage Then
				NavigationRow = NavigationTableNewRow("UserPasswordRequest", "Attachable_UserPasswordRequestOnOpen");
				NavigationRow.OnNavigationToNextPageHandlerName = "Attachable_UserPasswordRequestOnGoNext";
			EndIf;
			
			If MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
				Or MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
				NavigationTableNewRow("DataSynchronizationWait", , True, "Attachable_ConnectionTestWaitingTimeConsumingOperationProcessing");
			EndIf;
			
			If ExecuteDataSending Then
				// Send.
				NavigationTableNewRow(PageNameSynchronizationExport, "Attachable_DataExportOnOpen", True, "Attachable_DataExportTimeConsumingOperationProcessing");
				NavigationTableNewRow(PageNameSynchronizationExport, , True, "Attachable_DataExportTimeConsumingOperationProcessingCompletion");
			EndIf;
			
			// Receive.
			NavigationTableNewRow(PageNameSynchronizationImport, "Attachable_DataImportOnOpen", True, "Attachable_DataImportTimeConsumingOperationProcessing");
			// Send.
			NavigationTableNewRow(PageNameSynchronizationExport, "Attachable_DataExportOnOpen", True, "Attachable_DataExportTimeConsumingOperationProcessing");
			NavigationTableNewRow(PageNameSynchronizationExport, , True, "Attachable_DataExportTimeConsumingOperationProcessingCompletion");
			
		EndIf;
		
		// Complete.
		NavigationTableNewRow("ExchangeCompletion", "Attachable_ExchangeCompletionOnOpen", True, "Attachable_ExchangeCompletionTimeConsumingOperationProcessing");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationErrorAssigningAnIdToANodeURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("CommonForm.AdditionalDetails", New Structure("Title,TemplateName",
		NStr("en = 'Set predefined node code';"), "InstructionToSetCodeForPredefinedNode_en"));

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure StatusOfUnavailableSynchronizationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	If FormattedStringURL = "ExpectSynchronizationCapability" Then
		
		Step = NavigationNumber + 1;
		SetNavigationNumber(Step);
		
	EndIf;
	
EndProcedure


#EndRegion