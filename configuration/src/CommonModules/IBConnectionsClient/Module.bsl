///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens the form for entering infobase and/or cluster administration parameters.
//
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - a handler that will be called once the administration
//	                                                   parameters are entered.
//  PromptForIBAdministrationParameters - Boolean - indicates whether the infobase administration parameters
//	                                                   must be entered.
//  PromptForClusterAdministrationParameters - Boolean - indicates whether the cluster administration parameters
//	                                                         must be entered.
//  AdministrationParameters - See StandardSubsystemsServer.AdministrationParameters.
//  Title - String - a form title that explains the purpose of requesting the administration parameters.
//  NoteLabel - String - a description of the action in whose context the administration parameters are requested.
//
Procedure ShowAdministrationParameters(OnCloseNotifyDescription, PromptForIBAdministrationParameters,
	PromptForClusterAdministrationParameters, AdministrationParameters = Undefined,
	Title = "", NoteLabel = "") Export
	
	FormParameters = New Structure;
	FormParameters.Insert("PromptForIBAdministrationParameters", PromptForIBAdministrationParameters);
	FormParameters.Insert("PromptForClusterAdministrationParameters", PromptForClusterAdministrationParameters);
	FormParameters.Insert("AdministrationParameters", AdministrationParameters);
	FormParameters.Insert("Title", Title);
	FormParameters.Insert("NoteLabel", NoteLabel);
	
	OpenForm("CommonForm.ApplicationAdministrationParameters", FormParameters,,,,,OnCloseNotifyDescription);
	
EndProcedure

// Sets and disables the session termination mode.
// On exit and before lock, all active users will be notified about the session termination
// and prompted
// to save their data.
// The current session closes last.
//
// Parameters:
//  ExitApplication - Boolean
//
Procedure SetTheUserShutdownMode(Val ExitApplication) Export
	
	SetUserTerminationInProgressFlag(ExitApplication);
	SetUserExitControl(Not ExitApplication);
	
	If ExitApplication Then
		CurrentMode = IBConnectionsServerCall.SessionLockParameters(True);
		EndUserSessions(CurrentMode);
	EndIf;
	
EndProcedure

// Indicates whether it is necessary to close the session with enabled
// application lock.
//
// Parameters:
//   Value - Boolean - True if closing the current session is not required.
//
Procedure SetTerminateAllSessionsExceptCurrentFlag(Value) Export
	
	ClientParameters().TerminateAllSessionsExceptCurrent = Value;
	
EndProcedure

#EndRegion

#Region Internal

// Sets the SessionTerminationInProgress variable to Value.
//
// Parameters:
//   Value - Boolean - a value being set.
//
Procedure SetUserTerminationInProgressFlag(Value) Export
	
	ClientParameters().SessionTerminationInProgress = Value;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// The procedure is called when a user works interactively with a data area.
//
// Parameters:
//  StartupParameters - Array - an array of strings separated with semicolons ";" in the start parameter
//                     passed to the configuration using the /C command line key.
//  Cancel            - Boolean - a return value. If True,
//                     the OnStart event processing is canceled.
//
Procedure LaunchParametersOnProcess(StartupParameters, Cancel) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	Cancel = Cancel Or ProcessStartParameters(StartupParameters);
	
EndProcedure

// See CommonClientOverridable.BeforeStart.
Procedure BeforeStart(Parameters) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If Not ClientParameters.Property("DataAreaSessionsLocked") Then
		Return;
	EndIf;
	
	Parameters.InteractiveHandler = New NotifyDescription(
		"BeforeStartInteractiveHandler", ThisObject);
	
EndProcedure

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	If Not IsSubsystemUsed()
	 Or Not CommonClient.SeparatedDataUsageAvailable()
	 Or GetClientConnectionSpeed() <> ClientConnectionSpeed.Normal Then
		Return;
	EndIf;
	
	LockMode = StandardSubsystemsClient.ClientParametersOnStart().SessionLockParameters;
	CurrentTime = LockMode.CurrentSessionDate;
	If LockMode.Use 
		 And (Not ValueIsFilled(LockMode.Begin) Or CurrentTime >= LockMode.Begin) 
		 And (Not ValueIsFilled(LockMode.End) Or CurrentTime <= LockMode.End) Then
		// 
		// 
		Return;
	EndIf;
	
	If StrFind(Upper(LaunchParameter), Upper("EndUserSessions")) > 0 Then
		Return;
	EndIf;
	
	SetUserExitControl(True);
	
	If LockMode.Use Then
		ClientParameters().DateOfLastLockMessage = CommonClient.SessionDate();
		SessionTerminationModeManagement(LockMode);
	EndIf;
	
EndProcedure

// Parameters:
//  Cancel - See CommonClientOverridable.BeforeExit.Cancel
//  Warnings - See CommonClientOverridable.BeforeExit.Warnings
//
Procedure BeforeExit(Cancel, Warnings) Export
	
	If SessionTerminationInProgress() Then
		WarningParameters = StandardSubsystemsClient.WarningOnExit();
		WarningParameters.HyperlinkText = NStr("en = 'User access';");
		WarningParameters.WarningText = NStr("en = 'User sessions are being closed from the current session.';");
		WarningParameters.OutputSingleWarning = True;
		
		Form = "DataProcessor.ApplicationLock.Form.InfobaseConnectionsLock";
		
		ActionOnClickHyperlink = WarningParameters.ActionOnClickHyperlink;
		ActionOnClickHyperlink.Form = Form;
		ActionOnClickHyperlink.ApplicationWarningForm = Form;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

// The procedure is called during an unsuccessful attempt to set exclusive mode in a file infobase.
//
// Parameters:
//  Notification - NotifyDescription - describes the object which must be passed control after closing this form.
//
Procedure OnOpenExclusiveModeSetErrorForm(Notification = Undefined, FormParameters = Undefined) Export
	
	OpenForm("DataProcessor.ApplicationLock.Form.ExclusiveModeSettingError", FormParameters,
		, , , , Notification);
	
EndProcedure

// Opens the user activity lock form.
//
Procedure OnOpenUserActivityLockForm(Notification = Undefined, FormParameters = Undefined) Export
	
	OpenForm("DataProcessor.ApplicationLock.Form.InfobaseConnectionsLock", FormParameters,
		, , , , Notification);
	
EndProcedure

// Replaces the default notification with a custom form containing the active user list.
//
// Parameters:
//  FormName - String - a return value.
//
Procedure OnDefineActiveUserForm(FormName) Export
	
	FormName = "DataProcessor.ActiveUsers.Form.ActiveUsers";
	
EndProcedure

// See StandardSubsystemsClient.OnReceiptServerNotification
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	CurrentSessionDate = '00010101';
	ServerNotificationsClient.TimeoutExpired("",,, CurrentSessionDate);
	
	ClientParameters = ClientParameters();
	ClientParameters.LockCheckLastDate = CurrentSessionDate;
	
	If Result.Use Then
		ClientParameters.DateOfLastLockMessage = CurrentSessionDate;
	Else
		ClientParameters.DateOfLastLockMessage = '00010101';
		ClearUserNotifications();
		Return;
	EndIf;
	
	If SessionTerminationInProgress() Then
		If Not IsProcedureEndUserSessionsRunning() Then
			CurrentMode = IBConnectionsServerCall.SessionLockParameters(True);
			EndUserSessions(CurrentMode);
		EndIf;
		
	ElsIf IsUserExitControlEnabled() Then
		SessionTerminationModeManagement(Result);
	EndIf;
	
EndProcedure

// Parameters:
//  Parameters - See CommonOverridable.ПередПериодическойОтправкойДанныхКлиентаНаСервер.Параметры
//  AreNotificationsReceived - Boolean -
//                                
//
Procedure BeforeRecurringClientDataSendToServer(Parameters, AreNotificationsReceived) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	CurrentSessionDate = '00010101';
	ServerNotificationsClient.TimeoutExpired("",,, CurrentSessionDate);
	
	ClientParameters = ClientParameters();
	
	If Not ValueIsFilled(ClientParameters.LockCheckLastDate)
	   And Not ValueIsFilled(ClientParameters.DateOfLastLockMessage) Then
		ClientParameters.LockCheckLastDate = CurrentSessionDate;
		Return;
	EndIf;
	
	If SessionTerminationInProgress() Then
		Interval = 60;
	ElsIf IsUserExitControlEnabled() Then
		If ClientParameters.DateOfLastLockMessage + 300 > CurrentSessionDate Then
			Interval = 60;
		ElsIf AreNotificationsReceived Then
			Return;
		Else
			Interval = 300;
		EndIf;
	Else
		Return;
	EndIf;
	
	If ClientParameters.LockCheckLastDate + Interval > CurrentSessionDate Then
		Return;
	EndIf;
	ClientParameters.LockCheckLastDate = CurrentSessionDate;
	
	ParameterName = "StandardSubsystems.UsersSessions.SessionsLock";
	Parameters.Insert(ParameterName, True);
	
EndProcedure

// See CommonClientOverridable.AfterRecurringReceiptOfClientDataOnServer
Procedure AfterRecurringReceiptOfClientDataOnServer(Results) Export
	
	ParameterName = "StandardSubsystems.UsersSessions.SessionsLock";
	Result = Results.Get(ParameterName);
	If Result = Undefined Then
		Return;
	EndIf;
	
	OnReceiptServerNotification(ParameterName, Result);
	
EndProcedure

#EndRegion

#Region Private

Function IsSubsystemUsed()
	
	// 
	Return Not CommonClient.DataSeparationEnabled();
	
EndFunction

// Returns:
//  Structure:
//   * TerminateAllSessionsExceptCurrent - Boolean
//   * SessionTerminationInProgress - Boolean
//   * ShouldControlUserExit - Boolean
//   * AdministrationParameters - See StandardSubsystemsServer.AdministrationParameters
//   * IsProcedureEndUserSessionsRunning - Boolean
//   * LockCheckLastDate - Date
//   * DateOfLastLockMessage - Date
//
Function ClientParameters()
	
	ParameterName = "StandardSubsystems.UserSessionTerminationParameters";
	ClientParameters = ApplicationParameters[ParameterName];
	If ClientParameters <> Undefined Then
		Return ClientParameters;
	EndIf;
	
	ClientParameters = New Structure;
	ClientParameters.Insert("TerminateAllSessionsExceptCurrent", False);
	ClientParameters.Insert("SessionTerminationInProgress", False);
	ClientParameters.Insert("ShouldControlUserExit", False);
	ClientParameters.Insert("AdministrationParameters", Undefined);
	ClientParameters.Insert("IsProcedureEndUserSessionsRunning", False);
	ClientParameters.Insert("LockCheckLastDate",    '00010101');
	ClientParameters.Insert("DateOfLastLockMessage", '00010101');
	
	ApplicationParameters.Insert(ParameterName, ClientParameters);
	Return ClientParameters;
	
EndFunction

Procedure SetUserExitControl(Value = True)
	
	ClientParameters().ShouldControlUserExit = Value;
	
EndProcedure

Function IsUserExitControlEnabled()
	
	Return ClientParameters().ShouldControlUserExit;
	
EndFunction

Procedure SetIsProcedureEndUserSessionsRunning(Value = True)
	
	ClientParameters().IsProcedureEndUserSessionsRunning = Value;
	
EndProcedure

Function IsProcedureEndUserSessionsRunning()
	
	Return ClientParameters().IsProcedureEndUserSessionsRunning;
	
EndFunction

// Terminate the current session if connections 
// to the database are blocked.
//
Procedure SessionTerminationModeManagement(CurrentMode)

	LockSet = CurrentMode.Use;
	
	If Not LockSet
	 Or CurrentMode.Property("Parameter")
	   And CurrentMode.Parameter = ServerNotificationsClient.SessionKey() Then
		Return;
	EndIf;
		
	LockBeginTime = CurrentMode.Begin;
	LockEndTime = CurrentMode.End;
	
	// 
	// 
	// 
	WaitTimeout    = CurrentMode.SessionTerminationTimeout;
	ExitWithConfirmationTimeout = WaitTimeout / 3;
	StopTimeoutSaaS = 60; // 
	StopTimeout        = 0; // 
	CurrentMoment             = CurrentMode.CurrentSessionDate;
	
	If LockEndTime <> '00010101' And CurrentMoment > LockEndTime Then
		Return;
	EndIf;
	
	LockBeginTimeDate  = Format(LockBeginTime, "DLF=DD");
	LockBeginTimeTime = Format(LockBeginTime, "DLF=T");
	
	MessageText = IBConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	Template = NStr("en = 'Please save your data. The application will be temporarily unavailable since %1, %2.
		|%3';");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(Template, LockBeginTimeDate, LockBeginTimeTime, MessageText);
	
	DataSeparationEnabled = CommonClient.DataSeparationEnabled();
	If Not DataSeparationEnabled
		And (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentMoment < StopTimeout) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, CurrentMode.RestartOnCompletion);
		
	ElsIf DataSeparationEnabled
		And (Not ValueIsFilled(LockBeginTime) Or LockBeginTime - CurrentMoment < StopTimeoutSaaS) Then
		
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False, False);
		
	ElsIf LockBeginTime - CurrentMoment <= ExitWithConfirmationTimeout Then
		
		AskOnTermination(MessageText, LockBeginTime);
		
	ElsIf LockBeginTime - CurrentMoment <= WaitTimeout Then
		
		ShowWarningOnExit(MessageText, LockBeginTime);
		
	EndIf;
	
EndProcedure

// Terminate active sessions if the timeout is exceeded, and then
// terminate the current session.
//
Procedure EndUserSessions(CurrentMode)

	LockBeginTime = CurrentMode.Begin;
	CurrentMoment = CurrentMode.CurrentSessionDate;
	SessionCount = CurrentMode.SessionCount;
	
	ClickNotification = New NotifyDescription("OpeningHandlerOfAppWorkBlockForm", ThisObject);
	
	If CurrentMoment < LockBeginTime Then
		MessageText = NStr("en = 'The application will be temporarily unavailable since %1.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, LockBeginTime);
		ShowUserNotification(NStr("en = 'Closing user sessions';"), 
			ClickNotification, MessageText, PictureLib.Information32);
		Notify("UsersSessions",
			New Structure("Status, SessionCount", "RefreshEnabled", SessionCount));
		Return;
	EndIf;
	
	If SessionCount <= 1 Then
		// 
		// 
		// 
		SetUserTerminationInProgressFlag(False);
		Notify("UsersSessions",
			New Structure("Status, SessionCount", "Done", SessionCount));
		TerminateThisSession();
		Return;
	EndIf; 
	
	LockSet = CurrentMode.Use;
	If Not LockSet Then
		Return;
	EndIf;
	
	// 
	If CommonClient.FileInfobase() Then
		Notify("UsersSessions",
			New Structure("Status, SessionCount", "RefreshEnabled", SessionCount));
		Return;
	EndIf;
	
	// 
	// 
	
	Try
		AdministrationParameters = SavedAdministrationParameters();
		If CommonClient.ClientConnectedOverWebServer() Then
			IBConnectionsServerCall.DeleteAllSessionsExceptCurrent(AdministrationParameters);
		Else 
			IBConnectionsClientServer.DeleteAllSessionsExceptCurrent(AdministrationParameters);
		EndIf;
		SaveAdministrationParameters(Undefined);
	Except
		SetUserTerminationInProgressFlag(False);
			ShowUserNotification(NStr("en = 'Closing user sessions';"),
			ClickNotification,
			NStr("en = 'Cannot close sessions. For more information, see the event log.';"),
			PictureLib.Warning32);
		EventLogClient.AddMessageForEventLog(EventLogEvent(),
			"Error", ErrorProcessing.DetailErrorDescription(ErrorInfo()),, True);
		Notify("UsersSessions",
			New Structure("Status,SessionCount", "Error", SessionCount));
		Return;
	EndTry;
	
	SetUserTerminationInProgressFlag(False);
	ShowUserNotification(NStr("en = 'Closing user sessions';"),
		ClickNotification,
		NStr("en = 'All user sessions are closed.';"),
		PictureLib.Information32);
	Notify("UsersSessions",
		New Structure("Status,SessionCount", "Done", SessionCount));
	TerminateThisSession();
	
EndProcedure

// Terminates the last remaining session of the administrator who initiated user session termination.
//
Procedure TerminateThisSession(OutputQuestion1 = True)
	
	SetUserTerminationInProgressFlag(False);
	
	If TerminateAllSessionsExceptCurrent() Then
		Return;
	EndIf;
	
	If Not OutputQuestion1 Then 
		Exit(False);
		Return;
	EndIf;
	
	SetIsProcedureEndUserSessionsRunning(True);
	
	Notification = New NotifyDescription("TerminateThisSessionCompletion", ThisObject);
	MessageText = NStr("en = 'User access to the application is denied. Do you want to close your session?';");
	Title = NStr("en = 'Close current session';");
	ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes, Title, DialogReturnCode.Yes);
	
EndProcedure

Procedure OpeningHandlerOfAppWorkBlockForm(Context) Export
	
	FullFormName = "DataProcessor.ApplicationLock.Form.InfobaseConnectionsLock";
	
	Windows = GetWindows();
	For Each Window In Windows Do
		For Each Form In Window.Content Do
			If Form.FormName = FullFormName And Form.IsOpen() Then
				Form.Activate();
				Return;
			EndIf;
		EndDo;
	EndDo;
	
	OpenForm(FullFormName);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Core subsystem event handlers.

Function SessionTerminationInProgress() Export
	
	Return ClientParameters().SessionTerminationInProgress;
	
EndFunction

Function TerminateAllSessionsExceptCurrent()
	
	Return ClientParameters().TerminateAllSessionsExceptCurrent;
	
EndFunction

Function SavedAdministrationParameters()
	
	Return ClientParameters().AdministrationParameters;
	
EndFunction

Procedure SaveAdministrationParameters(Value) Export
	
	ClientParameters().AdministrationParameters = Value;
	
EndProcedure

Procedure FillInClusterAdministrationParameters(StartupParameters)
	
	AdministrationParameters = IBConnectionsServerCall.AdministrationParameters();
	ParametersCount = StartupParameters.Count();
	
	If ParametersCount > 1 Then
		AdministrationParameters.ClusterAdministratorName = StartupParameters[1];
	EndIf;
	
	If ParametersCount > 2 Then
		AdministrationParameters.ClusterAdministratorPassword = StartupParameters[2];
	EndIf;
	
	SaveAdministrationParameters(AdministrationParameters);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Notification handlers.

// Suggests to remove the application lock and sign in, or to shut down the application.
Procedure BeforeStartInteractiveHandler(Parameters, Context) Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	QueryText   = ClientParameters.PromptToAuthorize;
	MessageText = ClientParameters.DataAreaSessionsLocked;
	
	If Not IsBlankString(QueryText) Then
		Buttons = New ValueList();
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Sign in';"));
		If ClientParameters.CanUnlock Then
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Remove lock and sign in';"));
		EndIf;
		Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel';"));
		
		ResponseHandler = New NotifyDescription(
			"AfterAnswerToPromptToAuthorizeOrUnlock", ThisObject, Parameters);
		
		ShowQueryBox(ResponseHandler, QueryText, Buttons, 15,
			DialogReturnCode.Cancel,, DialogReturnCode.Cancel);
		Return;
	Else
		Parameters.Cancel = True;
		ShowMessageBox(
			StandardSubsystemsClient.NotificationWithoutResult(Parameters.ContinuationHandler),
			MessageText, 15);
	EndIf;
	
EndProcedure

// Continues from the above procedure.
Procedure AfterAnswerToPromptToAuthorizeOrUnlock(Response, Parameters) Export
	
	If Response = DialogReturnCode.Yes Then // 
		
	ElsIf Response = DialogReturnCode.No Then // 
		IBConnectionsServerCall.SetDataAreaSessionLock(
			New Structure("Use", False));
	Else
		Parameters.Cancel = True;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

Procedure ShowWarningOnExit(MessageText, LockBeginTime)
	
	InformParameters = InformParameters(LockBeginTime);
	If Not InformParameters.IsNotificationDisplayed Then
		ShowUserNotification(NStr("en = 'The application will be closed';"),, MessageText,, 
			UserNotificationStatus.Important, "UserSessionsEndControl");
		InformParameters.IsNotificationDisplayed = True;
	EndIf;
	
	If Not InformParameters.ShowWarningOrQuestion Then
		Return;
	EndIf;
	
	ShowMessageBox(, MessageText, 30);
	
EndProcedure

// Returns:
//  Structure:
//   * IsNotificationDisplayed - Boolean
//   * ShowWarningOrQuestion - Boolean
//
Function InformParameters(LockBeginTime)
	
	ParameterName = "StandardSubsystems.WarningShownBeforeExit";
	Properties = ApplicationParameters[ParameterName];
	If Properties = Undefined Or Properties.LockBeginTime <> LockBeginTime Then
		Properties = New Structure;
		Properties.Insert("IsNotificationDisplayed", False);
		Properties.Insert("ShowWarningOrQuestion", False);
		Properties.Insert("LastQuestionOrWarningDate", '00010101');
		Properties.Insert("LockBeginTime", LockBeginTime);
		ApplicationParameters.Insert(ParameterName, Properties);
	EndIf;
	
	SessionDate = CommonClient.SessionDate();
	If Properties.LastQuestionOrWarningDate + 50 < SessionDate Then
		Properties.LastQuestionOrWarningDate = SessionDate;
		Properties.ShowWarningOrQuestion = True;
	Else
		Properties.ShowWarningOrQuestion = False;
	EndIf;
	
	Return Properties;
	
EndFunction

Procedure ClearUserNotifications()
	
	ParameterName = "StandardSubsystems.WarningShownBeforeExit";
	InformParameters = ApplicationParameters[ParameterName];
	If InformParameters = Undefined
	 Or Not InformParameters.IsNotificationDisplayed Then
		Return;
	EndIf;
	InformParameters.IsNotificationDisplayed = False;
	
	ShowUserNotification(NStr("en = 'Closing the application is canceled';"),, ,,
		UserNotificationStatus.Important, "UserSessionsEndControl");
	
EndProcedure

Procedure AskOnTermination(MessageText, LockBeginTime)
	
	InformParameters = InformParameters(LockBeginTime);
	If Not InformParameters.IsNotificationDisplayed Then
		ShowUserNotification(NStr("en = 'The application will be closed';"),, MessageText,,
			UserNotificationStatus.Important, "UserSessionsEndControl");
		InformParameters.IsNotificationDisplayed = True;
	EndIf;
	
	If Not InformParameters.ShowWarningOrQuestion Then
		Return;
	EndIf;
	
	QueryText = NStr("en = '%1
		|Do you want to exit?';");
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, MessageText);
	NotifyDescription = New NotifyDescription("AskOnTerminationCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, 30, DialogReturnCode.Yes);
	
EndProcedure

Procedure AskOnTerminationCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, False);
	EndIf;
	
EndProcedure

Procedure TerminateThisSessionCompletion(Response, Parameters) Export
	
	If Response <> DialogReturnCode.No Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(False);
	EndIf;
	
	SetIsProcedureEndUserSessionsRunning(False);
	
EndProcedure	

// Processes start parameters related to allowing or terminating infobase connections.
//
// Parameters:
//  LaunchParameterValue - String - main launch parameter.
//  StartupParameters          - Array of String -
//
// Returns:
//   Boolean   - 
//
Function ProcessStartParameters(Val StartupParameters)

	If Not CommonClient.SeparatedDataUsageAvailable() Then
		Return False;
	EndIf;
	
	// Process startup parameters for DisableUserAuthorisation and AllowUserAuthorization.
	ParameterNameAllowUsers = "AllowUserAuthorization";
	ParameterNameShutdownUsers = "EndUserSessions";
	If TheKeyIsContainedInTheStartupParameters(StartupParameters, ParameterNameAllowUsers) Then
		
		If Not IBConnectionsServerCall.AllowUserAuthorization() Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 parameter is ignored because you do not have administrative rights.';"),
				ParameterNameAllowUsers);
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		EventLogClient.AddMessageForEventLog(EventLogEvent(),,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application is started with parameter %1. The application will be closed.';"),
					ParameterNameAllowUsers), ,True);
		Exit(False);
		Return True;
		
	//  
	// 
	// 
	ElsIf TheKeyIsContainedInTheStartupParameters(StartupParameters, ParameterNameShutdownUsers) Then
		
		AdditionalParameters = AdditionalParametersForUserShutdown();
		
		LockSet = IBConnectionsServerCall.SetConnectionLock(
			AdditionalParameters.MessageText,
			AdditionalParameters.KeyCode,
			AdditionalParameters.WaitingForTheStartOfBlockingMin,
			AdditionalParameters.BlockingDurationMin);
		
		If Not LockSet Then 
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 parameter is ignored because you do not have administrative rights.';"),
				ParameterNameShutdownUsers);
			ShowMessageBox(,MessageText);
			Return False;
		EndIf;
		
		// Offset cluster administration parameters in case of startup with a key.
		LaunchParametersRefined = LaunchParametersRefined(StartupParameters, AdditionalParameters);
		FillInClusterAdministrationParameters(LaunchParametersRefined);
		
		SetUserTerminationInProgressFlag(True);
		CurrentMode = IBConnectionsServerCall.SessionLockParameters(True);
		EndUserSessions(CurrentMode);
		Return False; 
		
	EndIf;
	Return False;
	
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
//   String
//
Function EventLogEvent() Export
	
	Return NStr("en = 'User sessions';", CommonClient.DefaultLanguageCode());
	
EndFunction

#Region AdditionalParametersForUserShutdown

// Extracts the session lock parameters from the startup parameter.
//
// Returns:
//   Structure:
//     * ClusterAdministratorName    - String - a name of 1C server cluster administrator.
//     * ClusterAdministratorPassword - String - a password of 1C server cluster administrator.
//     * MessageText               - String - text to be used in the error message
//                                               displayed when someone attempts to connect
//                                               to a locked infobase.
//     * KeyCode                - String - string to be added to "/uc" command line parameter
//                                                or to "uc" connection string parameter
//                                               in order to establish connection to the infobase
//                                               regardless of the lock.
//                                               Cannot be used for data area session locks.
//     * WaitingForTheStartOfBlockingMin  - Number -  delay time of the lock start in minutes.
//     * BlockingDurationMin    - Number - lock duration in minutes.
//
Function AdditionalParametersForUserShutdown() 
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ClusterAdministratorName", "");
	AdditionalParameters.Insert("ClusterAdministratorPassword", "");
	AdditionalParameters.Insert("MessageText", "");
	AdditionalParameters.Insert("KeyCode", "KeyCode");
	AdditionalParameters.Insert("WaitingForTheStartOfBlockingMin", 0);
	AdditionalParameters.Insert("BlockingDurationMin", 0);
	
	AdditionalParametersExtracted = AdditionalUserShutdownParametersExtracted();
	
	For Each Parameter In AdditionalParameters Do 
		
		ParameterValue = Undefined;
		
		If AdditionalParametersExtracted.Property(Parameter.Key, ParameterValue)
			And ValueIsFilled(ParameterValue) Then 
			
			AdditionalParameters[Parameter.Key] = ParameterValue;
		EndIf;
		
	EndDo;
	
	Return AdditionalParameters;
	
EndFunction

Function AdditionalUserShutdownParametersExtracted()
	
	AdditionalParameters = New Structure;
	
	UserShutdownParameter = UserShutdownParameter();
	
	If Not ValueIsFilled(UserShutdownParameter) Then 
		Return AdditionalParameters;
	EndIf;
	
	InitialNumber = StrFind(UserShutdownParameter, "EndUserSessions")
		+ StrLen("EndUserSessions");
	
	AdditionalParametersByTheString = TrimAll(Mid(UserShutdownParameter, InitialNumber));
	CompositionOfAdditionalParameters = StrSplit(AdditionalParametersByTheString, ",");
	PreviousParameter = Undefined;
	
	For Each Parameter In CompositionOfAdditionalParameters Do 
		
		ParameterDetails = StrSplit(Parameter, "=");
		
		If ParameterDetails.Count() <> 2 Then 
			
			If PreviousParameter <> Undefined
				And ValueIsFilled(ParameterDetails[0]) Then 
				
				ParameterValue = AdditionalParameters[PreviousParameter] + "," + ParameterDetails[0];
				AdditionalParameters.Insert(PreviousParameter, ParameterValue);
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		AdditionalParameters.Insert(TrimAll(ParameterDetails[0]), TrimAll(ParameterDetails[1]));
		PreviousParameter = TrimAll(ParameterDetails[0]);
		
	EndDo;
	
	Return AdditionalUserShutdownParametersNormalized(AdditionalParameters);
	
EndFunction

Function UserShutdownParameter()
	
	CompositionOfLaunchParameters = StrSplit(LaunchParameter, ";", False);
	
	For Each Parameter In CompositionOfLaunchParameters Do 
		
		If StrStartsWith(TrimAll(Parameter), "EndUserSessions") Then 
			Return Parameter;
		EndIf;
		
	EndDo;
	
	Return "";
	
EndFunction

Function AdditionalUserShutdownParametersNormalized(AdditionalParameters)
	
	AdditionalParametersAreNormalized = New Structure;
	
	AdditionalParameterKeys = KeysForAdditionalUserShutdownParameters();
	
	For Each AdditionalParameter In AdditionalParameters Do 
		
		For Each AdditionalParameterKey In AdditionalParameterKeys Do 
			
			If StrStartsWith(AdditionalParameter.Key, AdditionalParameterKey.Key) Then 
				
				AdditionalParametersAreNormalized.Insert(
					AdditionalParameterKey.Value, AdditionalParameter.Value);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FormatAdditionalUserShutdownParameters(AdditionalParametersAreNormalized);
	
	Return AdditionalParametersAreNormalized;
	
EndFunction

Function KeysForAdditionalUserShutdownParameters()
	
	AdditionalParameterKeys = New Map;
	AdditionalParameterKeys.Insert("Name", "ClusterAdministratorName");
	AdditionalParameterKeys.Insert("Password", "ClusterAdministratorPassword");
	AdditionalParameterKeys.Insert("Message", "MessageText");
	AdditionalParameterKeys.Insert("Code", "KeyCode");
	AdditionalParameterKeys.Insert("Waiting", "WaitingForTheStartOfBlockingMin");
	AdditionalParameterKeys.Insert("Duration", "BlockingDurationMin");
	
	Return AdditionalParameterKeys;
	
EndFunction

Procedure FormatAdditionalUserShutdownParameters(AdditionalParameters)
	
	ParametersToBeFormatted = New Array;
	ParametersToBeFormatted.Add("WaitingForTheStartOfBlockingMin");
	ParametersToBeFormatted.Add("BlockingDurationMin");
	
	NumberDetails = New TypeDescription("Number");
	
	For Each Parameter In ParametersToBeFormatted Do 
		
		ParameterValue = Undefined;
		
		If Not AdditionalParameters.Property(Parameter, ParameterValue) Then 
			Continue;
		EndIf;
		
		AvailableCharacters = New Array;
		
		CharsCount = StrLen(ParameterValue);
		
		For CharacterNumber = 1 To CharsCount Do 
			
			Char = Mid(ParameterValue, CharacterNumber, 1);
			
			If StrFind("0123456789", Char) > 0 Then 
				AvailableCharacters.Add(Char);
			EndIf;
			
		EndDo;
		
		TheValueOfTheParameterIsNormalized = StrConcat(AvailableCharacters);
		
		If ValueIsFilled(TheValueOfTheParameterIsNormalized) Then 
			AdditionalParameters[Parameter] = NumberDetails.AdjustValue(TheValueOfTheParameterIsNormalized);
		Else
			AdditionalParameters[Parameter] = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

Function TheKeyIsContainedInTheStartupParameters(StartupParameters, Var_Key)
	
	For Each Parameter In StartupParameters Do 
		
		If StrStartsWith(TrimAll(Parameter), Var_Key) Then 
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function LaunchParametersRefined(StartupParameters, AdditionalParameters)
	
	ClusterAdministratorName = CommonClientServer.StructureProperty(
		AdditionalParameters, "ClusterAdministratorName");
	
	If Not ValueIsFilled(ClusterAdministratorName) Then 
		Return StartupParameters;
	EndIf;
	
	LaunchParametersRefined = New Array;
	LaunchParametersRefined.Add(StartupParameters[0]);
	LaunchParametersRefined.Add(ClusterAdministratorName);
	
	ClusterAdministratorPassword = CommonClientServer.StructureProperty(
		AdditionalParameters, "ClusterAdministratorPassword");
	
	If ValueIsFilled(ClusterAdministratorPassword) Then 
		LaunchParametersRefined.Add(ClusterAdministratorPassword);
	EndIf;
	
	Return LaunchParametersRefined;
	
EndFunction

#EndRegion
