///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Locking the infobase and terminating connections.

// Sets the infobase connection lock.
// If this function is called from a session with separator values set,
// it sets the data area session lock.
//
// Parameters:
//  MessageText           - String - text to be used in the error message
//                                      displayed when someone attempts to connect
//                                      to a locked infobase.
// 
//  KeyCode            - String - string to be added to "/uc" command line parameter
//                                       or to "uc" connection string parameter
//                                      in order to establish connection to the infobase
//                                      regardless of the lock.
//                                      Cannot be used for data area session locks.
//  WaitingForTheStartOfBlocking - Number -  delay time of the lock start in minutes.
//  LockDuration   - Number - lock duration in minutes.
//
// Returns:
//   Boolean   - 
//              
//
Function SetConnectionLock(Val MessageText = "", Val KeyCode = "KeyCode", // 
	Val WaitingForTheStartOfBlocking = 0, Val LockDuration = 0) Export
	
	If Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Return False;
		EndIf;
		
		Block = NewConnectionLockParameters();
		Block.Use = True;
		Block.Begin = CurrentSessionDate() + WaitingForTheStartOfBlocking * 60;
		Block.Message = GenerateLockMessage(MessageText, KeyCode);
		Block.Exclusive = Users.IsFullUser(, True);
		
		If LockDuration > 0 Then 
			Block.End = Block.Begin + LockDuration * 60;
		EndIf;
		
		SetDataAreaSessionLock(Block);
		
		Return True;
	Else
		If Not Users.IsFullUser(, True) Then
			Return False;
		EndIf;
		
		Block = New SessionsLock;
		Block.Use = True;
		Block.Begin = CurrentSessionDate() + WaitingForTheStartOfBlocking * 60;
		Block.KeyCode = KeyCode;
		Block.Parameter = ServerNotifications.SessionKey();
		Block.Message = GenerateLockMessage(MessageText, KeyCode);
		
		If LockDuration > 0 Then 
			Block.End = Block.Begin + LockDuration * 60;
		EndIf;
		
		SetSessionsLock(Block);
	
		SetPrivilegedMode(True);
		SendServerNotificationAboutLockSet();
		SetPrivilegedMode(False);
		
		Return True;
	EndIf;
	
EndFunction

// Determines whether connection lock is set for a batch 
// update of the infobase configuration.
//
// Returns:
//    Boolean - 
//
Function ConnectionsLocked() Export
	
	LockParameters = CurrentConnectionLockParameters();
	Return LockParameters.ConnectionsLocked;
	
EndFunction

// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//    GetSessionCount - Boolean - if True, then the SessionCount field
//                                         is filled in the returned structure.
//
// Returns:
//   Structure:
//     * Use       - Boolean - True if the lock is set, otherwise False. 
//     * Begin            - Date   - lock start date. 
//     * End             - Date   - lock end date. 
//     * Message         - String - message to user. 
//     * SessionTerminationTimeout - Number - interval in seconds.
//     * SessionCount - Number  - 0 if the GetSessionCount parameter value is False.
//     * CurrentSessionDate - Date   - a current session date.
//
Function SessionLockParameters(Val GetSessionCount = False) Export
	
	LockParameters = CurrentConnectionLockParameters();
	Return AdvancedSessionLockParameters(GetSessionCount, LockParameters);
	
EndFunction

// Removes the infobase lock.
//
// Returns:
//   Boolean   - 
//              
//
Function AllowUserAuthorization() Export
	
	If Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable() Then
		
		If Not Users.IsFullUser() Then
			Return False;
		EndIf;
		
		LockParameters = GetDataAreaSessionLock();
		If LockParameters.Use Then
			LockParameters.Use = False;
			SetDataAreaSessionLock(LockParameters);
		EndIf;
		Return True;
		
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Return False;
	EndIf;
	
	LockParameters = GetSessionsLock();
	If LockParameters.Use Then
		LockParameters.Use = False;
		
		SetSessionsLock(LockParameters);
		
		SetPrivilegedMode(True);
		SendServerNotificationAboutLockSet();
		SetPrivilegedMode(False);
	EndIf;
	
	Return True;
	
EndFunction

// Returns information about the current connections to the infobase.
// If necessary, writes a message to the event log.
//
// Parameters:
//    GetConnectionString - Boolean - add the connection string to the return value.
//    MessagesForEventLog - ValueList - if the parameter is not blank, the events from the list will be written
//                                                      to the event log.
//    ClusterPort - Number - a non-standard port of a server cluster.
//
// Returns:
//    Structure:
//        * HasActiveConnections - Boolean - indicates whether there are active connections.
//        * HasCOMConnections - Boolean - indicates whether there are COM connections.
//        * HasDesignerConnection - Boolean - indicates whether there is a Designer connection.
//        * HasActiveUsers - Boolean - indicates whether there are active users.
//        * InfoBaseConnectionString - String - an infobase connection string. The property is present
//                                                            only if the GetConnectionString parameter
//                                                            value is True.
//
Function ConnectionsInformation(GetConnectionString = False,
	MessagesForEventLog = Undefined, ClusterPort = 0) Export
	
	SetPrivilegedMode(True);
	
	Result = New Structure();
	Result.Insert("HasActiveConnections", False);
	Result.Insert("HasCOMConnections", False);
	Result.Insert("HasDesignerConnection", False);
	Result.Insert("HasActiveUsers", False);
	
	If InfoBaseUsers.GetUsers().Count() > 0 Then
		Result.HasActiveUsers = True;
	EndIf;
	
	If GetConnectionString Then
		Result.Insert("InfoBaseConnectionString", InfoBaseConnectionString());
	EndIf;
		
	EventLog.WriteEventsToEventLog(MessagesForEventLog);
	
	SessionsArray = GetInfoBaseSessions();
	If SessionsArray.Count() = 1 Then
		Return Result;
	EndIf;
	
	Result.HasActiveConnections = True;
	
	For Each Session In SessionsArray Do
		If Upper(Session.ApplicationName) = Upper("COMConnection") Then // 
			Result.HasCOMConnections = True;
		ElsIf Upper(Session.ApplicationName) = Upper("Designer") Then // Конфигуратор
			Result.HasDesignerConnection = True;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data area session lock.

// Gets an empty structure with data area session lock parameters.
// 
// Returns:
//   Structure:
//     * Begin         - Date   - time the lock became active.
//     * End          - Date   - time the lock ended.
//     * Message      - String - messages for users attempting to access the locked data area.
//     * Use    - Boolean - shows if the lock is set.
//     * Exclusive   - Boolean - the lock cannot be modified by the application administrator.
//
Function NewConnectionLockParameters() Export
	
	Result = New Structure;
	Result.Insert("End", Date(1,1,1));
	Result.Insert("Begin", Date(1,1,1));
	Result.Insert("Message", "");
	Result.Insert("Use", False);
	Result.Insert("Exclusive", False);
	
	Return Result;
	
EndFunction

// Sets the data area session lock.
// 
// Parameters:
//   Parameters         - See NewConnectionLockParameters
//   LocalTime - Boolean - lock beginning time and lock end time are specified in the local session time.
//                                If the parameter is False, they are specified in universal time.
//   DataArea - Number - number of the data area to be locked.
//     When calling this procedure from a session with separator values set, only a value
//       equal to the session separator value (or unspecified) can be passed.
//     When calling this procedure from a session with separator values not set, the parameter value must be specified.
//
Procedure SetDataAreaSessionLock(Val Parameters, Val LocalTime = True, Val DataArea = -1) Export
	
	If Not Users.IsFullUser() Then
		Raise NStr("en = 'Not enough rights to perform the operation.';");
	EndIf;
	
	// 
	ConnectionsLockParameters = NewConnectionLockParameters();
	FillPropertyValues(ConnectionsLockParameters, Parameters); 
	Parameters = ConnectionsLockParameters;
	 
	If Parameters.Exclusive And Not Users.IsFullUser(, True) Then
		Raise NStr("en = 'Not enough rights to perform the operation.';");
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		SessionSeparatorValue = ModuleSaaSOperations.SessionSeparatorValue();
		
		If DataArea = -1 Then
			DataArea = SessionSeparatorValue;
		ElsIf DataArea <> SessionSeparatorValue Then
			Raise NStr("en = 'Cannot set a session lock for a data area that is different from the session data area because the session uses separator values.';");
		EndIf;
		
	ElsIf DataArea = -1 Then
		Raise NStr("en = 'Cannot lock data area sessions because the data area is not specified.';");
	EndIf;
	
	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.DataAreaSessionLocks");
		LockItem.SetValue("DataAreaAuxiliaryData", DataArea);
		DataLock.Lock();
		
		LockSet1 = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
		LockSet1.Filter.DataAreaAuxiliaryData.Set(DataArea);
		LockSet1.Read();
		LockSet1.Clear();
		If Parameters.Use Then 
			Block = LockSet1.Add();
			Block.DataAreaAuxiliaryData = DataArea;
			Block.LockStart = ?(LocalTime And ValueIsFilled(Parameters.Begin), 
				ToUniversalTime(Parameters.Begin), Parameters.Begin);
			Block.LockEnd = ?(LocalTime And ValueIsFilled(Parameters.End), 
				ToUniversalTime(Parameters.End), Parameters.End);
			Block.LockMessage = Parameters.Message;
			Block.Exclusive = Parameters.Exclusive;
		EndIf;
		LockSet1.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SendServerNotificationAboutLockSet();
	
EndProcedure

// Gets information on the data area session lock.
// 
// Parameters:
//   LocalTime - Boolean - lock beginning time and lock end time are returned 
//                                in the local session time zone. If the parameter is False, 
//                                they are specified in universal time.
//
// Returns:
//   See NewConnectionLockParameters.
//
Function GetDataAreaSessionLock(Val LocalTime = True) Export
	
	Result = NewConnectionLockParameters();
	If Not Common.DataSeparationEnabled() Or Not Common.SeparatedDataUsageAvailable() Then
		Return Result;
	EndIf;
	
	If Not Users.IsFullUser() Then
		Raise NStr("en = 'Not enough rights to perform the operation.';");
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	LockSet1 = InformationRegisters.DataAreaSessionLocks.CreateRecordSet();
	LockSet1.Filter.DataAreaAuxiliaryData.Set(
		ModuleSaaSOperations.SessionSeparatorValue());
	LockSet1.Read();
	If LockSet1.Count() = 0 Then
		Return Result;
	EndIf;
	Block = LockSet1[0];
	Result.Begin = ?(LocalTime And ValueIsFilled(Block.LockStart), 
		ToLocalTime(Block.LockStart), Block.LockStart);
	Result.End = ?(LocalTime And ValueIsFilled(Block.LockEnd), 
		ToLocalTime(Block.LockEnd), Block.LockEnd);
	Result.Message = Block.LockMessage;
	Result.Exclusive = Block.Exclusive;
	Result.Use = True;
	If ValueIsFilled(Block.LockEnd) And CurrentSessionDate() > Block.LockEnd Then
		Result.Use = False;
	EndIf;
	Return Result;
	
EndFunction

#EndRegion

#Region Internal

Function IsSubsystemUsed() Export
	
	// 
	Return Not Common.DataSeparationEnabled();
	
EndFunction

// Returns a text string containing the active infobase connection list.
// The connection names are separated by line breaks.
//
// Parameters:
//  Message - String - string to pass.
//
// Returns:
//   String - 
//
Function ActiveSessionsMessage() Export
	
	Message = NStr("en = 'Cannot close sessions:';");
	CurrentSessionNumber = InfoBaseSessionNumber();
	For Each Session In GetInfoBaseSessions() Do
		If Session.SessionNumber <> CurrentSessionNumber Then
			Message = Message + Chars.LF + "• " + Session;
		EndIf;
	EndDo;
	
	Return Message;
	
EndFunction

// Gets the number of active infobase sessions.
//
// Parameters:
//   IncludeConsole - Boolean - if False, the server cluster console sessions are excluded.
//                               The server cluster console sessions do not prevent execution 
//                               of administrative operations (enabling the exclusive mode, and so on).
//
// Returns:
//   Number - 
//
Function InfobaseSessionsCount(IncludeConsole = True, IncludeBackgroundJobs = True) Export
	
	IBSessions = GetInfoBaseSessions();
	If IncludeConsole And IncludeBackgroundJobs Then
		Return IBSessions.Count();
	EndIf;
	
	Result = 0;
	
	For Each IBSession In IBSessions Do
		
		If Not IncludeConsole And IBSession.ApplicationName = "SrvrConsole"
			Or Not IncludeBackgroundJobs And IBSession.ApplicationName = "BackgroundJob" Then
			Continue;
		EndIf;
		
		Result = Result + 1;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Determines the number of infobase sessions and checks if there are sessions
// that cannot be forcibly disabled. Generates error message
// text.
//
Function BlockingSessionsInformation(MessageText = "") Export
	
	BlockingSessionsInformation = New Structure;
	
	CurrentSessionNumber = InfoBaseSessionNumber();
	InfobaseSessions = GetInfoBaseSessions();
	
	HasBlockingSessions = False;
	If Common.FileInfobase() Then
		ActiveSessionNames = "";
		For Each Session In InfobaseSessions Do
			If Session.SessionNumber <> CurrentSessionNumber
				And Session.ApplicationName <> "1CV8"
				And Session.ApplicationName <> "1CV8C"
				And Session.ApplicationName <> "WebClient" Then
				ActiveSessionNames = ActiveSessionNames + Chars.LF + "• " + Session;
				HasBlockingSessions = True;
			EndIf;
		EndDo;
	EndIf;
	
	BlockingSessionsInformation.Insert("HasBlockingSessions", HasBlockingSessions);
	BlockingSessionsInformation.Insert("SessionCount", InfobaseSessions.Count());
	
	If HasBlockingSessions Then
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'There are active sessions
			|that cannot be closed:
			|%1
			|%2';"),
			ActiveSessionNames, MessageText);
		BlockingSessionsInformation.Insert("MessageText", Message);
		
	EndIf;
	
	Return BlockingSessionsInformation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See SaaSOperationsOverridable.OnFillIIBParametersTable.
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.AddConstantToInformationSecurityParameterTable(ParametersTable, "LockMessageOnConfigurationUpdate");
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	LockParameters = CurrentConnectionLockParameters();
	Parameters.Insert("SessionLockParameters", New FixedStructure(AdvancedSessionLockParameters(False, LockParameters)));
	
	If Not LockParameters.ConnectionsLocked
		Or Not Common.DataSeparationEnabled()
		Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// The following code is intended for locked data areas only.
	If InfobaseUpdate.InfobaseUpdateInProgress() 
		And Users.IsFullUser() Then
		// 
		// 
		Return; 
	EndIf;
	
	CurrentMode = LockParameters.CurrentDataAreaMode;
	
	If ValueIsFilled(CurrentMode.End) Then
		If ValueIsFilled(CurrentMode.Message) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application administrator locked the application for the period from %1 to %2. Reason:
					|%3.';"), CurrentMode.Begin, CurrentMode.End, CurrentMode.Message);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application administrator locked the application for the period from %1 to %2 for scheduled maintenance.';"), 
				CurrentMode.Begin, CurrentMode.End);
		EndIf;		
	Else
		If ValueIsFilled(CurrentMode.Message) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application administrator locked the application at %1. Reason:
					|%2.';"), CurrentMode.Begin, CurrentMode.Message);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The application administrator locked the application at %1 due for scheduled maintenance.';"), 
				CurrentMode.Begin);
		EndIf;		
	EndIf;
	Parameters.Insert("DataAreaSessionsLocked", MessageText + Chars.LF + Chars.LF + NStr("en = 'The application is temporarily unavailable.';"));
	LogonMessageText = "";
	If Users.IsFullUser() Then
		LogonMessageText = MessageText + Chars.LF + Chars.LF + NStr("en = 'Do you want to sign in to the locked application?';");
	EndIf;
	Parameters.Insert("PromptToAuthorize", LogonMessageText);
	If (Users.IsFullUser() And Not CurrentMode.Exclusive) 
		Or Users.IsFullUser(, True) Then
		
		Parameters.Insert("CanUnlock", True);
	Else
		Parameters.Insert("CanUnlock", False);
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	Parameters.Insert("SessionLockParameters", New FixedStructure(SessionLockParameters()));
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.DataAreaSessionLocks);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("DataAdministration", Metadata)
		Or ModuleToDoListServer.UserTaskDisabled("SessionsLock") Then
		Return;
	EndIf;
	
	// 
	// 
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.ApplicationLock.FullName());
	
	LockParameters = SessionLockParameters(False);
	CurrentSessionDate = CurrentSessionDate();
	
	If LockParameters.Use Then
		If CurrentSessionDate < LockParameters.Begin Then
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Scheduled from %1 to %2';"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Scheduled from %1';"), Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = False;
		ElsIf LockParameters.End <> Date(1, 1, 1) And CurrentSessionDate > LockParameters.End And LockParameters.Begin <> Date(1, 1, 1) Then
			Importance = False;
			Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Inactive (expired on %1)';"), Format(LockParameters.End, "DLF=DT"));
		Else
			If LockParameters.End <> Date(1, 1, 1) Then
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'from %1 to %2';"),
					Format(LockParameters.Begin, "DLF=DT"), Format(LockParameters.End, "DLF=DT"));
			Else
				Message = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'from %1';"), 
					Format(LockParameters.Begin, "DLF=DT"));
			EndIf;
			Importance = True;
		EndIf;
	Else
		Message = NStr("en = 'Inactive';");
		Importance = False;
	EndIf;

	
	For Each Section In Sections Do
		
		ToDoItemID = "SessionsLock" + StrReplace(Section.FullName(), ".", "");
		
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = ToDoItemID;
		ToDoItem.HasToDoItems       = LockParameters.Use;
		ToDoItem.Presentation  = NStr("en = 'Deny user access';");
		ToDoItem.Form          = "DataProcessor.ApplicationLock.Form";
		ToDoItem.Important         = Importance;
		ToDoItem.Owner       = Section;
		
		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = "SessionLockDetails";
		ToDoItem.HasToDoItems       = LockParameters.Use;
		ToDoItem.Presentation  = Message;
		ToDoItem.Owner       = ToDoItemID; 
		
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddServerNotifications
Procedure OnAddServerNotifications(Notifications) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	Notification = ServerNotifications.NewServerNotification(
		"StandardSubsystems.UsersSessions.SessionsLock");
	Notification.NotificationSendModuleName  = "IBConnections";
	Notification.NotificationReceiptModuleName = "IBConnectionsClient";
	Notification.VerificationPeriod = 300;
	
	Notifications.Insert(Notification.Name, Notification);
	
EndProcedure

// See StandardSubsystemsServer.OnSendServerNotification
Procedure OnSendServerNotification(NameOfAlert, ParametersVariants) Export
	
	SendServerNotificationAboutLockSet(True);
	
EndProcedure

// See CommonOverridable.OnReceiptRecurringClientDataOnServer
Procedure OnReceiptRecurringClientDataOnServer(Parameters, Results) Export
	
	If Not IsSubsystemUsed() Then
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.UsersSessions.SessionsLock";
	SessionLockParameters = SessionsLockSettingsWhenSet();
	
	If SessionLockParameters <> Undefined
	   And SessionLockParameters.Use Then
		
		Results.Insert(ParameterName, SessionLockParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SendServerNotificationAboutLockSet(OnSendServerNotification = False) Export
	
	Try
		SessionLockParameters = SessionsLockSettingsWhenSet();
		If SessionLockParameters = Undefined Then
			SessionLockParameters = New Structure("Use", False);
		EndIf;
		
		If SessionLockParameters.Use
		 Or Not OnSendServerNotification Then
			
			ServerNotifications.SendServerNotification(
				"StandardSubsystems.UsersSessions.SessionsLock",
				SessionLockParameters, Undefined, Not OnSendServerNotification);
		EndIf;
	Except
		If OnSendServerNotification Then
			Raise;
		EndIf;
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

// Returns session lock message text.
//
// Parameters:
//  Message - String - message for the lock.
//  KeyCode - String - infobase access key code.
//
// Returns:
//   String - 
//
Function GenerateLockMessage(Val Message, Val KeyCode) Export
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	FileModeFlag = False;
	IBPath = IBConnectionsClientServer.InfobasePath(FileModeFlag, AdministrationParameters.ClusterPort);
	InfobasePathString = ?(FileModeFlag = True, "/F", "/S") + IBPath;
	MessageText = "";
	If Not IsBlankString(Message) Then
		MessageText = Message + Chars.LF + Chars.LF;
	EndIf;
	
	ParameterName = "AllowUserAuthorization";
	If Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable() Then
		MessageText = MessageText + NStr("en = '%1
			|To allow user access, you can open the application with parameter %2. For example:
			|http://<server web address>/?C=%2';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, 
			IBConnectionsClientServer.TextForAdministrator(), ParameterName);
	Else
		MessageText = MessageText + NStr("en = '%1
			|To allow user access, use the server cluster console or run 1C:Enterprise with the following parameters:
			|ENTERPRISE %2 /C%3 /UC%4';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, IBConnectionsClientServer.TextForAdministrator(),
			InfobasePathString, ParameterName, NStr("en = '<access code>';"));
	EndIf;
	
	Return MessageText;
	
EndFunction

// Returns the flag specifying whether a connection lock is set for a specific date.
//
// Parameters:
//  CurrentMode - SessionsLock - sessions lock.
//  CurrentDate - Date - date to check.
//
// Returns:
//  Boolean - 
//
Function ConnectionsLockedForDate(CurrentMode, CurrentDate)
	
	Return (CurrentMode.Use And CurrentMode.Begin <= CurrentDate 
		And (Not ValueIsFilled(CurrentMode.End) Or CurrentDate <= CurrentMode.End));
	
EndFunction

// See the description in the SessionLockParameters function.
//
// Parameters:
//    GetSessionCount - Boolean
//    LockParameters - See CurrentConnectionLockParameters
//
Function AdvancedSessionLockParameters(Val GetSessionCount, LockParameters)
	
	If LockParameters.IBConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentIBMode;
	ElsIf LockParameters.DataAreaConnectionLockSetForDate Then
		CurrentMode = LockParameters.CurrentDataAreaMode;
	ElsIf LockParameters.CurrentIBMode.Use Then
		CurrentMode = LockParameters.CurrentIBMode;
	Else
		CurrentMode = LockParameters.CurrentDataAreaMode;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Result = New Structure;
	Result.Insert("Use", CurrentMode.Use);
	Result.Insert("Begin", CurrentMode.Begin);
	Result.Insert("End", CurrentMode.End);
	Result.Insert("Message", CurrentMode.Message);
	Result.Insert("SessionTerminationTimeout", 15 * 60);
	Result.Insert("SessionCount", ?(GetSessionCount, InfobaseSessionsCount(), 0));
	Result.Insert("CurrentSessionDate", LockParameters.CurrentDate);
	Result.Insert("RestartOnCompletion", True);
	
	IBConnectionsOverridable.OnDetermineSessionLockParameters(Result);
	
	Return Result;
	
EndFunction

// Parameters:
//   ShouldReturnUndefinedIfUnspecified - Boolean
// 
// Returns:
//   Structure:
//   * IBConnectionLockSetForDate - Boolean
//   * CurrentDataAreaMode - See NewConnectionLockParameters
//   * CurrentIBMode - SessionsLock
//   * CurrentDate - Date
//
Function CurrentConnectionLockParameters(ShouldReturnUndefinedIfUnspecified = False)
	
	CurrentDate = CurrentDate(); // 
	
	SetPrivilegedMode(True);
	CurrentIBMode = GetSessionsLock();
	If ShouldReturnUndefinedIfUnspecified
	   And Not CurrentIBMode.Use
	   And Not Common.DataSeparationEnabled() Then
		Return Undefined;
	EndIf;
	CurrentDataAreaMode = GetDataAreaSessionLock();
	SetPrivilegedMode(False);
	
	IBLockedForDate = ConnectionsLockedForDate(CurrentIBMode, CurrentDate);
	AreaLockedAtDate = ConnectionsLockedForDate(CurrentDataAreaMode, CurrentDate);
	ConnectionsLocked = IBLockedForDate Or AreaLockedAtDate;
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDate", CurrentDate);
	Parameters.Insert("CurrentIBMode", CurrentIBMode);
	Parameters.Insert("CurrentDataAreaMode", CurrentDataAreaMode);
	Parameters.Insert("IBConnectionLockSetForDate", IBLockedForDate);
	Parameters.Insert("DataAreaConnectionLockSetForDate", AreaLockedAtDate);
	Parameters.Insert("ConnectionsLocked", ConnectionsLocked);
	
	Return Parameters;
	
EndFunction

// Returns:
//   See SessionLockParameters
//
Function SessionsLockSettingsWhenSet()
	
	LockParameters = CurrentConnectionLockParameters(True);
	If LockParameters = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = AdvancedSessionLockParameters(False, LockParameters);
	If LockParameters.IBConnectionLockSetForDate Then
		Result.Insert("Parameter", LockParameters.CurrentIBMode.Parameter);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a string constant for generating event log messages.
//
// Returns:
//   String - 
//
Function EventLogEvent() Export
	
	Return NStr("en = 'User sessions';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion
