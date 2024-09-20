///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens backup form.
//
// Parameters:
//    Parameters - Structure - backup form parameters.
//
Procedure OpenBackupForm(Parameters = Undefined) Export
	
	OpenForm("DataProcessor.IBBackup.Form.DataBackup", Parameters);
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.OnStart.
Procedure OnStart(Parameters) Export
	
	If CommonClient.DataSeparationEnabled()
	 Or Not BackupAvailable() Then
		Return;
	EndIf;
	
	Settings = StandardSubsystemsClient.ClientParametersOnStart().IBBackup;
	If Not ValueIsFilled(Settings) Then
		Return;
	EndIf;
	
	FillGlobalVariableValues(Settings);
	CheckIBBackup(Settings);
	If Settings.RestorePerformed Then
		NotificationText1 = NStr("en = 'Data successfully restored.';");
		ShowUserNotification(NStr("en = 'Data is restored.';"), , NotificationText1);
	EndIf;
	
	NotificationOption = Settings.NotificationParameter1;
	If NotificationOption = "DontNotify" Then
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ToDoList") Then
		ShowWarning = False;
		IBBackupClientOverridable.OnDetermineBackupWarningRequired(ShowWarning);
	Else
		ShowWarning = True;
	EndIf;
	
	If ShowWarning
		And (NotificationOption = "Overdue" Or NotificationOption = "NotConfiguredYet") Then
		NotifyUserOfBackup(NotificationOption);
	EndIf;
	
	AttachIdleBackupHandler();
	
EndProcedure

// Parameters:
//  Cancel - See CommonClientOverridable.BeforeExit.Cancel
//  Warnings - See CommonClientOverridable.BeforeExit.Warnings
//
Procedure BeforeExit(Cancel, Warnings) Export
	
	#If WebClient Or MobileClient Then
		Return;
	#EndIf
	
	If Not CommonClient.IsWindowsClient()
	 Or Not CommonClient.FileInfobase()
	 Or CommonClient.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Parameters = StandardSubsystemsClient.ClientParameter();
	
	If Not Parameters.IBBackupOnExit.NotificationRolesAvailable
		Or Not Parameters.IBBackupOnExit.ExecuteOnExit1 Then
		Return;
	EndIf;
	
	WarningParameters = StandardSubsystemsClient.WarningOnExit();
	WarningParameters.CheckBoxText = NStr("en = 'Back up';");
	WarningParameters.Priority = 50;
	WarningParameters.WarningText = NStr("en = 'Back up on exit has not been done.';");
	
	ActionIfFlagSet = WarningParameters.ActionIfFlagSet;
	ActionIfFlagSet.Form = "DataProcessor.IBBackup.Form.DataBackup";
	FormParameters = New Structure();
	FormParameters.Insert("WorkMode", "ExecuteOnExit");
	ActionIfFlagSet.FormParameters = FormParameters;
	
	Warnings.Add(WarningParameters);
	
EndProcedure

// See SSLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode.
Procedure OnCheckIfCanBackUpInUserMode(Result) Export
	
	If CommonClient.FileInfobase() Then
		Result = True;
	EndIf;
	
EndProcedure

// See SSLSubsystemsIntegrationClient.OnPromptUserForBackup.
Procedure OnPromptUserForBackup() Export
	
	OpenBackupForm();
	
EndProcedure

#EndRegion

#Region Private

Procedure FillGlobalVariableValues(Settings) Export
	
	Result = New Structure;
	Result.Insert("ProcessRunning");
	Result.Insert("MinDateOfNextAutomaticBackup");
	Result.Insert("LatestBackupDate");
	Result.Insert("NotificationParameter1");
	FillPropertyValues(Result, Settings);
	Result.Insert("ScheduleValue1", CommonClientServer.StructureToSchedule(Settings.CopyingSchedule));
	ApplicationParameters.Insert("StandardSubsystems.IBBackupParameters", Result);
	
EndProcedure

// Checks whether it is necessary to start automatic backup
// during user working, as well as repeat notification after ignoring the initial one.
//
Procedure StartIdleHandler() Export
	
	If Not BackupAvailable() Then
		Return;
	EndIf;
	
	If CommonClient.FileInfobase()
	   And NecessityOfAutomaticBackup() Then
		
		PerformABackup();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ToDoList") Then
		ShowWarning = False;
		IBBackupClientOverridable.OnDetermineBackupWarningRequired(ShowWarning);
	Else
		ShowWarning = True;
	EndIf;
	
	NotificationOption = ApplicationParameters["StandardSubsystems.IBBackupParameters"].NotificationParameter1;
	If ShowWarning
		And (NotificationOption = "Overdue" Or NotificationOption = "NotConfiguredYet") Then
		NotifyUserOfBackup(NotificationOption);
	EndIf;
	
EndProcedure

// Checks whether the automatic backup is required.
//
// Returns:
//   Boolean - 
//
Function NecessityOfAutomaticBackup()
	
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	If Settings = Undefined Then
		Return False;
	EndIf;
	
	ScheduleValue1 = Undefined;
	If Settings.ProcessRunning
		Or Not Settings.Property("MinDateOfNextAutomaticBackup")
		Or Not Settings.Property("ScheduleValue1", ScheduleValue1)
		Or Not Settings.Property("LatestBackupDate") Then
		Return False;
	EndIf;
	If ScheduleValue1 = Undefined Then
		Return False;
	EndIf;
	
	CheckDate = CommonClient.SessionDate();
	NextCopyingDate = Settings.MinDateOfNextAutomaticBackup;
	If NextCopyingDate = '29990101' Or NextCopyingDate > CheckDate Then
		Return False;
	EndIf;
	
	Return ScheduleValue1.ExecutionRequired(CheckDate, Settings.LatestBackupDate);
EndFunction

// Starts backup on schedule.
// 
Procedure PerformABackup()
	
	Buttons = New ValueList;
	Buttons.Add("Yes", NStr("en = 'Yes';"));
	Buttons.Add("None", NStr("en = 'No';"));
	Buttons.Add("Snooze", NStr("en = 'Snooze for 15 minutes';"));
	
	DescriptionOfTheAlert = New NotifyDescription("PerformABackupCompletion", ThisObject);
	ShowQueryBox(DescriptionOfTheAlert, NStr("en = 'Scheduled backup is all set to start.
		|Do you want to start it now?';"),
		Buttons, 30, "Yes", NStr("en = 'Scheduled backup';"), "Yes");
	
EndProcedure

Procedure PerformABackupCompletion(QuestionResult, AdditionalParameters) Export
	
	ExecuteBackup = QuestionResult = "Yes" Or QuestionResult = DialogReturnCode.Timeout;
	DeferBackup = QuestionResult = "Snooze";
	
	NextDate = IBBackupServerCall.NextAutomaticCopyingDate(DeferBackup);
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	Settings.MinDateOfNextAutomaticBackup = NextDate;
	
	If ExecuteBackup Then
		FormParameters = New Structure("WorkMode", "ExecuteNow");
		OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
	EndIf;
	
EndProcedure

// Checks on application startup whether it is the first start after backup. 
// If yes, it displays a handler form with backup results.
//
// Parameters:
//  Parameters - Structure - backup parameters.
//
Procedure CheckIBBackup(Parameters)
	
	If Not Parameters.BackupCreated1 Then
		Return;
	EndIf;
	
	If Parameters.LastBackupManualStart Then
		
		FormParameters = New Structure();
		FormParameters.Insert("WorkMode", ?(Parameters.CopyingResult, "CompletedSuccessfully1", "NotCompleted2"));
		FormParameters.Insert("BackupFileName", Parameters.BackupFileName);
		OpenForm("DataProcessor.IBBackup.Form.DataBackup", FormParameters);
		
	Else
		
		ShowUserNotification(NStr("en = 'Backup';"),
			"e1cib/command/CommonCommand.ShowBackupResult",
			NStr("en = 'Backup successful';"), PictureLib.Information32);
		IBBackupServerCall.SetSettingValue("BackupCreated1", False);
		
	EndIf;
	
EndProcedure

// Shows a notification according to results of backup parameters analysis.
//
// Parameters: 
//   NotificationOption - String - check result for notifications.
//
Procedure NotifyUserOfBackup(NotificationOption)
	
	ExplanationText = "";
	If NotificationOption = "Overdue" Then
		
		ExplanationText = NStr("en = 'Automatic backup has not been done.';"); 
		ShowUserNotification(NStr("en = 'Backup';"),
			"e1cib/app/DataProcessor.IBBackup", ExplanationText, PictureLib.Warning32);
		
	ElsIf NotificationOption = "NotConfiguredYet" Then
		
		SettingsFormName = "e1cib/app/DataProcessor.IBBackupSetup/";
		ExplanationText = NStr("en = 'It is recommended that you set up infobase backup.';"); 
		ShowUserNotification(NStr("en = 'Backup';"),
			SettingsFormName, ExplanationText, PictureLib.Warning32);
			
	EndIf;
	
	CurrentDate = CommonClient.SessionDate();
	IBBackupServerCall.SetLastNotificationDate(CurrentDate);
	
EndProcedure

// Returns an event type of the event log for the current subsystem.
//
// Returns:
//   String - 
//
Function EventLogEvent() Export
	
	Return NStr("en = 'Infobase backup';", CommonClient.DefaultLanguageCode());
	
EndFunction

// Getting user authentication parameters for update.
// Creates a virtual user if necessary.
//
// Returns:
//  Structure - parameters of a virtual user.
//
Function UpdateAdministratorAuthenticationParameters(AdministratorPassword) Export
	
	Result = New Structure("UserName, UserPassword, StringForConnection, InfoBaseConnectionString");
	
	CurrentConnections = IBConnectionsServerCall.ConnectionsInformation(True,
		ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	Result.InfoBaseConnectionString = CurrentConnections.InfoBaseConnectionString;
	If Not CurrentConnections.HasActiveUsers Then
		Return Result;
	EndIf;
	
	Result.UserName    = StandardSubsystemsClient.ClientParametersOnStart().UserCurrentName;
	Result.UserPassword = StringUnicode(AdministratorPassword);
	Result.StringForConnection  = "Usr=""{0}"";Pwd=""{1}""";
	Return Result;
	
EndFunction

Function StringUnicode(String) Export
	
	Result = "";
	
	For CharacterNumber = 1 To StrLen(String) Do
		
		Char = Format(CharCode(Mid(String, CharacterNumber, 1)), "NG=0");
		Char = StringFunctionsClientServer.SupplementString(Char, 4);
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Checks whether an add-in can be attached to the infobase.
//
Procedure CheckAccessToInfobase(AdministratorPassword, Val Notification) Export
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("AdministratorPassword", AdministratorPassword);
	
	Notification = New NotifyDescription("CheckAccessToInfobaseAfterCOMRegistration", ThisObject, Context);
	CommonClient.RegisterCOMConnector(False, Notification);
	
EndProcedure

Procedure CheckAccessToInfobaseAfterCOMRegistration(IsRegistered, Context) Export
	
	Notification = Context.Notification;
	AdministratorPassword = Context.AdministratorPassword;
	
	ConnectionResult = ConnectionResult();
	
	If IsRegistered Then 
		
		ClientParametersOnStart = StandardSubsystemsClient.ClientParametersOnStart();
		
		ConnectionParameters = CommonClientServer.ParametersStructureForExternalConnection();
		ConnectionParameters.InfobaseDirectory = StrSplit(InfoBaseConnectionString(), """")[1];
		ConnectionParameters.UserName = ClientParametersOnStart.UserCurrentName;
		ConnectionParameters.UserPassword = AdministratorPassword;
		
		Result = CommonClient.EstablishExternalConnectionWithInfobase(ConnectionParameters);
		
		If Result.AddInAttachmentError Then
			EventLogClient.AddMessageForEventLog(
				EventLogEvent(),"Error", Result.DetailedErrorDetails, , True);
		EndIf;
		
		FillPropertyValues(ConnectionResult, Result);
		
		Result.Join = Undefined; // 
		
	EndIf;
	
	ExecuteNotifyProcessing(Notification, ConnectionResult);
	
EndProcedure

Function ConnectionResult()
	
	Result = New Structure;
	Result.Insert("AddInAttachmentError", False);
	Result.Insert("BriefErrorDetails", "");
	
	Return Result;
	
EndFunction

// Attaching a global idle handler.
//
Procedure AttachIdleBackupHandler() Export
	
	AttachIdleHandler("BackupActionsHandler", 60);
	
EndProcedure

// Disable global idle handler.
//
Procedure DisableBackupIdleHandler() Export
	
	DetachIdleHandler("BackupActionsHandler");
	
EndProcedure

Function NumberOfSecondsInPeriod(Period, PeriodType)
	
	If PeriodType = "Day" Then
		Multiplier = 3600 * 24;
	ElsIf PeriodType = "Week" Then
		Multiplier = 3600 * 24 * 7; 
	ElsIf PeriodType = "Month" Then
		Multiplier = 3600 * 24 * 30;
	ElsIf PeriodType = "Year" Then
		Multiplier = 3600 * 24 * 365;
	EndIf;
	
	Return Multiplier * Period;
	
EndFunction

#If Not WebClient And Not MobileClient Then

Procedure DeleteConfigurationBackups() Export
	
	FixedIBBackupParameters = StandardSubsystemsClient.ClientRunParameters().IBBackup;
	StorageDirectory = FixedIBBackupParameters.BackupStorageDirectory;
	DeletionParameters = FixedIBBackupParameters.DeletionParameters;
	If DeletionParameters.RestrictionType = "StoreAll" Or StorageDirectory = Undefined Then
		Return;
	EndIf;
		
	// CAC:566-off code will never be executed in browser.
	Try
		File = New File(StorageDirectory);
		If Not File.IsDirectory() Then
			Return;
		EndIf;
		
		BackupFiles = FindFiles(StorageDirectory, "backup????_??_??_??_??_??*", False);
		DeletedFileList = New Array;
		
		If DeletionParameters.RestrictionType = "ByPeriod" Then
			For Each ItemFile In BackupFiles Do
				CurrentDate = CommonClient.SessionDate();
				ValueInSeconds = NumberOfSecondsInPeriod(DeletionParameters.ValueInUOMs, 
					DeletionParameters.PeriodUOM);
				Deletion1 = ((CurrentDate - ValueInSeconds) > ItemFile.GetModificationTime());
				If Deletion1 Then
					DeletedFileList.Add(ItemFile.FullName);
				EndIf;
			EndDo;
			
		ElsIf BackupFiles.Count() > DeletionParameters.CopiesCount Then
			ListOfFiles = New ValueList;
			ListOfFiles.LoadValues(BackupFiles);
			
			For Each File In ListOfFiles Do
				File.Presentation = File.Value.FullName;
				File.Value = File.Value.GetModificationTime();
			EndDo;
			
			ListOfFiles.SortByValue(SortDirection.Asc);
			
			For IndexOf = 0 To ListOfFiles.Count() - DeletionParameters.CopiesCount - 1 Do
				DeletedFileList.Add(ListOfFiles[IndexOf].Presentation);
			EndDo;
		EndIf;
		
		For Each DeletedFile In DeletedFileList Do
			Try
				DeleteFiles(DeletedFile);
			Except
				EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
					NStr("en = 'Failed to clean up backup storage directory.';") + Chars.LF 
					+ ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
			EndTry;
		EndDo;
		
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			NStr("en = 'Failed to clean up backup storage directory.';") + Chars.LF 
			+ ErrorProcessing.DetailErrorDescription(ErrorInfo()),,True);
	EndTry;
	
	// ACC:566-on
	
EndProcedure

Function IBBackupApplicationFilesEncoding() Export
	
	// wscript.exe может работать только с файлами в кодировке UTF-16 LE.
	Return TextEncoding.UTF16;
	
EndFunction

// Returns backup script parameters.
//
// Returns:
//   Structure - 
//
Function ClientBackupParameters() Export
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("ApplicationFileName", StandardSubsystemsClient.ApplicationExecutableFileName());
	ParametersStructure.Insert("EventLogEvent", NStr("en = 'Infobase backup';"));
	
	//  
	// 
	TempFilesDirForUpdate = TempFilesDir() + "1Cv8Backup." + Format(CommonClient.SessionDate(), "DF=yyMMddHHmmss") + "\";
	ParametersStructure.Insert("TempFilesDirForUpdate", TempFilesDirForUpdate);
	
	Return ParametersStructure;
	
EndFunction

Procedure DontStopScenariosExecution() Export
	
	Shell = New COMObject("Wscript.Shell");
	Shell.RegWrite("HKCU\Software\Microsoft\Internet Explorer\Styles\MaxScriptStatements", 1107296255, "REG_DWORD");

EndProcedure

#EndIf

Function BackupAvailable()
	
#If WebClient Or MobileClient Then
	Return False;
#Else
	Return CommonClient.IsWindowsClient();
#EndIf
	
EndFunction

// Returns:
//  Structure:
//    * BinDir - String
//    * ApplicationFileName - String
//    * EventLogEvent - String
//    * COMConnectorName - String
//    * IsBaseConfigurationVersion - String
//    * ScriptParameters - String
//    * OneCEnterpriseStartupParameters - String
//
Function GeneralScriptParameters() Export
	
	ScriptParameters = New Structure;
	ScriptParameters.Insert("BinDir"            , "");
	ScriptParameters.Insert("ApplicationFileName"           , "");
	ScriptParameters.Insert("EventLogEvent"   , "");
	ScriptParameters.Insert("COMConnectorName"           , "");
	ScriptParameters.Insert("IsBaseConfigurationVersion", "");
	ScriptParameters.Insert("ScriptParameters"            , "");
	ScriptParameters.Insert("OneCEnterpriseStartupParameters" , "");
	Return ScriptParameters;
	
EndFunction	

#EndRegion
