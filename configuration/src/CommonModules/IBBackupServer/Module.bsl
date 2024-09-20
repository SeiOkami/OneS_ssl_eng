///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Saves backup parameters.
//
Procedure SetBackupSettings(Val Settings, Val User = Undefined) Export
	If Not ValueIsFilled(Settings) Then
		Settings = NewBackupSettings();
	EndIf;	
	Common.CommonSettingsStorageSave("BackupParameters", "", Settings);
	If User <> Undefined Then
		CopyingParameters = New Structure("User", User);
		Constants.BackupParameters.Set(New ValueStorage(CopyingParameters));
	EndIf;
EndProcedure

// Returns the current backup setting as String.
// Two options of using functions: passing all parameters, or without parameters.
//
Function CurrentBackupSetting() Export
	
	BackupSettings1 = BackupSettings1();
	If BackupSettings1 = Undefined Then
		Return NStr("en = 'To set up backup, contact your administrator.';");
	EndIf;
	
	CurrentSetting = NStr("en = 'Backup is not set up. Configure backup settings to prevent data loss.';");
	
	If Common.FileInfobase() Then
		
		If BackupSettings1.CreateBackupAutomatically Then
			
			If BackupSettings1.ExecutionOption = "OnExit" Then
				CurrentSetting = NStr("en = 'Backups are created automatically on exit.';");
			ElsIf BackupSettings1.ExecutionOption = "Schedule3" Then // 
				Schedule = CommonClientServer.StructureToSchedule(BackupSettings1.CopyingSchedule);
				If Not IsBlankString(Schedule) Then
					CurrentSetting = NStr("en = 'Backups are created on schedule: %1.';");
					CurrentSetting = StringFunctionsClientServer.SubstituteParametersToString(CurrentSetting, Schedule);
				EndIf;
			EndIf;
			
		Else
			
			If BackupSettings1.BackupConfigured Then
				CurrentSetting = NStr("en = 'Backups are created by third-party backup tools.';");
			EndIf;
			
		EndIf;
		
	Else
		
		CurrentSetting = NStr("en = 'Backups are created by the means of DBMS.';");
		
	EndIf;
	
	Return CurrentSetting;
	
EndFunction

// Link for substitution in a formatted string for opening infobase backup data processor.
//
// Returns:
//   String - navigation links.
//
Function BackupDataProcessorURL() Export
	
	Return "e1cib/app/DataProcessor.IBBackup";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	If Common.IsWebClient()
		Or Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	DisabledNotificationOfBackupSettings = ModuleToDoListServer.UserTaskDisabled("SetUpBackup");
	DisabledNotificationOfBackupExecution = ModuleToDoListServer.UserTaskDisabled("ExecuteBackup");
	
	If Not AccessRight("View", Metadata.DataProcessors.IBBackupSetup)
		Or (DisabledNotificationOfBackupSettings
			And DisabledNotificationOfBackupExecution) Then
		Return;
	EndIf;
	
	BackupSettings1 = BackupSettings1();
	If BackupSettings1 = Undefined Then
		Return;
	EndIf;
	
	NotificationOption = BackupSettings1.NotificationParameter1;
	
	// 
	// 
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.IBBackupSetup.FullName());
	
	For Each Section In Sections Do
		
		If Not DisabledNotificationOfBackupSettings Then
			
			BackupSettingFormName = ?(Common.FileInfobase(),
				"DataProcessor.IBBackupSetup.Form.BackupSetup",
				"DataProcessor.IBBackupSetup.Form.BackupSetupClientServer");
			
			ToDoItem = ToDoList.Add();
			ToDoItem.Id  = "SetUpBackup" + StrReplace(Section.FullName(), ".", "");
			ToDoItem.HasToDoItems       = NotificationOption = "NotConfiguredYet";
			ToDoItem.Presentation  = NStr("en = 'Set up backup';");
			ToDoItem.Important         = True;
			ToDoItem.Form          = BackupSettingFormName;
			ToDoItem.Owner       = Section;
		EndIf;
		
		If Not DisabledNotificationOfBackupExecution Then
			ToDoItem = ToDoList.Add();
			ToDoItem.Id  = "ExecuteBackup" + StrReplace(Section.FullName(), ".", "");
			ToDoItem.HasToDoItems       = NotificationOption = "Overdue";
			ToDoItem.Presentation  = NStr("en = 'Backup required';");
			ToDoItem.Important         = True;
			ToDoItem.Form          = "DataProcessor.IBBackup.Form.DataBackup";
			ToDoItem.Owner       = Section;
		EndIf;
		
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart.
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("IBBackup", BackupSettings1(True));
	Parameters.Insert("IBBackupOnExit", ParametersOnExit1());
	
EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("IBBackup", BackupSettings1());
	
EndProcedure

// See SafeModeManagerOverridable.OnEnableSecurityProfiles.
Procedure OnEnableSecurityProfiles() Export
	
	Settings = BackupSettings1();
	If Settings = Undefined Then
		Return;
	EndIf;
	
	If Settings.Property("IBAdministratorPassword") Then
		Settings.IBAdministratorPassword = "";
		SetBackupSettings(Settings);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns IBBackup subsystem parameters that are required on user
// exit.
//
// Returns:
//  Structure - parameters.
//
Function ParametersOnExit1()
	
	BackupSettings1 = BackupSettings1();
	ExecuteOnExit1 = ?(BackupSettings1 = Undefined, False,
		BackupSettings1.CreateBackupAutomatically
		And BackupSettings1.ExecutionOption = "OnExit");
	
	ParametersOnExit = New Structure;
	ParametersOnExit.Insert("NotificationRolesAvailable",   Users.IsFullUser(,True));
	ParametersOnExit.Insert("ExecuteOnExit1", ExecuteOnExit1);
	
	Return ParametersOnExit;
	
EndFunction

// Returns the default automatic backup settings.
//
Function NewBackupSettings()
	
	Parameters = New Structure;
	
	Parameters.Insert("CreateBackupAutomatically", False);
	Parameters.Insert("BackupConfigured", False);
	
	Parameters.Insert("LastNotificationDate", '00010101');
	Parameters.Insert("LatestBackupDate", '00010101');
	Parameters.Insert("MinDateOfNextAutomaticBackup", '29990101');
	
	Parameters.Insert("CopyingSchedule", CommonClientServer.ScheduleToStructure(New JobSchedule));
	Parameters.Insert("BackupStorageDirectory", "");
	Parameters.Insert("ManualBackupsStorageDirectory", ""); // 
	Parameters.Insert("BackupCreated1", False);
	Parameters.Insert("RestorePerformed", False);
	Parameters.Insert("CopyingResult", Undefined);
	Parameters.Insert("BackupFileName", "");
	Parameters.Insert("ExecutionOption", "Schedule3");
	Parameters.Insert("ProcessRunning", False);
	Parameters.Insert("IBAdministrator", "");
	Parameters.Insert("IBAdministratorPassword", "");
	Parameters.Insert("DeletionParameters", DefaultBackupDeletionParameters());
	Parameters.Insert("LastBackupManualStart", True);
	
	Return Parameters;
	
EndFunction

// Returns saved backup parameters.
//
// Returns:
//   Structure - backup settings.
//
Function BackupParameters() Export
	
	Parameters = Common.CommonSettingsStorageLoad("BackupParameters", "");
	If Parameters = Undefined Then
		Parameters = NewBackupSettings();
		SetBackupSettings(Parameters);
	Else
		SupplementBackupParameters(Parameters);
	EndIf;
	Return Parameters;
	
EndFunction

// Parameters:
//  BackupParameters - Structure - infobase backup parameters.
//
Procedure SupplementBackupParameters(BackupParameters)
	
	ParametersChanged = False;
	
	Parameters = NewBackupSettings();
	For Each StructureItem In Parameters Do
		ValueFound = Undefined;
		If BackupParameters.Property(StructureItem.Key, ValueFound) Then
			If ValueFound = Undefined And StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		Else
			If StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Not ParametersChanged Then 
		Return;
	EndIf;
	
	SetBackupSettings(BackupParameters);
	
EndProcedure

// Returns:
//   Boolean - 
//
Function NecessityOfAutomaticBackup()
	
	If Not Common.FileInfobase() Then
		Return False;
	EndIf;
	
	Parameters = BackupParameters();
	If Parameters = Undefined Then
		Return False;
	EndIf;
	Schedule = Parameters.CopyingSchedule;
	If Schedule = Undefined Then
		Return False;
	EndIf;
	
	If Parameters.Property("ProcessRunning") And Parameters.ProcessRunning Then
		Return False;
	EndIf;
	
	CheckDate = CurrentSessionDate();
	NextCopyingDate = Parameters.MinDateOfNextAutomaticBackup;
	If NextCopyingDate = '29990101' Or NextCopyingDate > CheckDate Then
		Return False;
	EndIf;
	
	CheckStartDate = Parameters.LatestBackupDate;
	ScheduleValue1 = CommonClientServer.StructureToSchedule(Schedule);
	Return ScheduleValue1.ExecutionRequired(CheckDate, CheckStartDate);
	
EndFunction

Procedure ResetBackupFlag() Export
	
	Settings = BackupSettings1();
	Settings.BackupCreated1 = False;
	SetBackupSettings(Settings);
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		OperationName = "StandardSubsystems.IBBackup.BackupCreated";
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation(OperationName, 1);
	EndIf;
	
EndProcedure

// Parameters: 
//  NotificationDate1 - Date - date and time the user was last notified of required
//	                         backup.
//
Procedure SetLastNotificationDate(NotificationDate1) Export
	
	Settings = BackupParameters();
	Settings.LastNotificationDate = NotificationDate1;
	SetBackupSettings(Settings);
	
EndProcedure

// Parameters: 
//  TagName - String - a parameter name.
//   ElementValue - Arbitrary - a parameter value.
//
Procedure SetSettingValue(TagName, ElementValue) Export
	
	Settings = BackupParameters();
	Settings.Insert(TagName, ElementValue);
	SetBackupSettings(Settings);
	
EndProcedure

// Parameters: 
//  WorkStart - Boolean - shows that the call is performed on application start.
//
// Returns:
//  Structure - backup settings.
//
Function BackupSettings1(WorkStart = False) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return Undefined; 
	EndIf;
	
	If Not Users.IsFullUser(,True) Then
		Return Undefined; 
	EndIf;
	
	Result = BackupParameters();
	
	// Defining a user notification option
	NotificationOption = "DontNotify";
	NotifyOfBackupNecessity = CurrentSessionDate() >= (Result.LastNotificationDate + 3600 * 24);
	If IsInfobaseBackupSubsystemUsed() Then
		If Result.CreateBackupAutomatically Then
			NotificationOption = ?(NecessityOfAutomaticBackup(), "Overdue", "Configured");
		ElsIf Not Result.BackupConfigured Then
			If NotifyOfBackupNecessity Then	
				BackupSettings1 = Constants.BackupParameters.Get().Get();
				If BackupSettings1 <> Undefined
					And BackupSettings1.User <> Users.CurrentUser() Then
					NotificationOption = "DontNotify";
				Else
					NotificationOption = "NotConfiguredYet";
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	Result.Insert("NotificationParameter1", NotificationOption);
	
	If Result.BackupCreated1 And Result.CopyingResult  Then
		CurrentSessionDate = CurrentSessionDate();
		Result.LatestBackupDate = CurrentSessionDate;
		// Save the date of the last backup to common settings storage.
		Settings = BackupParameters();
		Settings.LatestBackupDate = CurrentSessionDate;
		SetBackupSettings(Settings);
	EndIf;
	
	If Result.RestorePerformed Then
		UpdateRestoreResult();
	EndIf;
	
	If WorkStart And Result.ProcessRunning Then
		Result.ProcessRunning = False;
		SetSettingValue("ProcessRunning", False);
	EndIf;
	
	Return Result;
	
EndFunction

// 
// 
//
// Returns:
//  Boolean
//
Function IsInfobaseBackupSubsystemUsed()
	
	If Common.SubsystemExists("OnlineUserSupport.CloudArchive20") Then
		ModuleCloudArchive20 = Common.CommonModule("CloudArchive20");
		Return ModuleCloudArchive20.IsInfobaseBackupSubsystemUsed();
	EndIf;
	
	Return True;
	
EndFunction

Procedure UpdateRestoreResult()
	
	Settings = BackupParameters();
	Settings.RestorePerformed = False;
	SetBackupSettings(Settings);
	
EndProcedure

Function UserInformation() Export
	
	UserInformation = New Structure("Name, PasswordRequired", "", False);
	UsedUsers = InfoBaseUsers.GetUsers().Count() > 0;
	
	If Not UsedUsers Then
		Return UserInformation;
	EndIf;
	
	CurrentUser = StandardSubsystemsServer.CurrentUser();
	PasswordRequired = CurrentUser.PasswordIsSet And CurrentUser.StandardAuthentication;
	
	UserInformation.Name = CurrentUser.Name;
	UserInformation.PasswordRequired = PasswordRequired;
	
	Return UserInformation;
	
EndFunction

// Writes a flag indicating that backup has been done.
// Called from the script via COM connection.
// 
// Parameters:
//  Result - Boolean - the result of copying.
//  BackupFileName - String - a backup file name.
//
Procedure FinishBackup(Result, BackupFileName =  "") Export
	
	Settings = BackupSettings1();
	Settings.BackupCreated1 = True;
	Settings.CopyingResult = Result;
	Settings.BackupFileName = BackupFileName;
	SetBackupSettings(Settings);
	
EndProcedure

// Writes a flag that indicates executed restoration from the backup.
// Called from the script via COM connection.
//
// Parameters:
//  Result - Boolean - a restore result.
//
Procedure CompleteRestore(Result) Export
	
	Settings = BackupSettings1();
	Settings.RestorePerformed = True;
	SetBackupSettings(Settings);
	
EndProcedure

Function DefaultBackupDeletionParameters()
	
	DeletionParameters = New Structure;
	DeletionParameters.Insert("RestrictionType", "ByPeriod");
	DeletionParameters.Insert("CopiesCount", 10);
	DeletionParameters.Insert("PeriodUOM", "Month");
	DeletionParameters.Insert("ValueInUOMs", 6);
	Return DeletionParameters;
	
EndFunction

// Parameters:
//   ScriptParameters - See IBBackupClient.GeneralScriptParameters.
//
Function PrepareCommonScriptParameters(Val ScriptParameters) Export
	
	ConnectionParameters = ScriptParameters.ScriptParameters;
	InfoBaseConnectionString = ConnectionParameters.InfoBaseConnectionString + ConnectionParameters.StringForConnection;
	
	If StrEndsWith(InfoBaseConnectionString, ";") Then
		InfoBaseConnectionString = Left(InfoBaseConnectionString, StrLen(InfoBaseConnectionString) - 1);
	EndIf;
	
	BinDir = ?(IsBlankString(ScriptParameters.BinDir), BinDir(), ScriptParameters.BinDir);
	NameOfExecutableApplicationFile = BinDir + ScriptParameters.ApplicationFileName;
	
	// Determining path to the infobase.
	FileModeFlag = Undefined;
	InfobasePath = IBConnectionsClientServer.InfobasePath(FileModeFlag, 0);
	
	InfobasePathParameter = ?(FileModeFlag, "/F", "/S") + InfobasePath; 
	InfobasePathString	= ?(FileModeFlag, InfobasePath, "");
	
	TextParameters = New Map;
	TextParameters["[NameOfExecutableApplicationFile]"] = PrepareText(NameOfExecutableApplicationFile);
	TextParameters["[InfobasePathParameter]"] = PrepareText(InfobasePathParameter);
	TextParameters["[InfobaseFilePathString]"] = PrepareText(
		CommonClientServer.AddLastPathSeparator(StrReplace(InfobasePathString, """", "")));
	TextParameters["[InfoBaseConnectionString]"] = PrepareText(InfoBaseConnectionString);
	TextParameters["[AdministratorName]"] = PrepareText(UserName());
	TextParameters["[EventLogEvent]"] = PrepareText(ScriptParameters.EventLogEvent);
	TextParameters["[CreateDataBackup]"] = "true";
	TextParameters["[COMConnectorName]"] = PrepareText(ScriptParameters.COMConnectorName);
	TextParameters["[UseCOMConnector]"] = ?(ScriptParameters.IsBaseConfigurationVersion, "false", "true");
	TextParameters["[OneCEnterpriseStartupParameters]"] = PrepareText(ScriptParameters.OneCEnterpriseStartupParameters);
	TextParameters["[UnlockCode1]"] = "Backup";
	
	Return TextParameters;
	
EndFunction

Function SubstituteParametersToText(Val Text, Val TextParameters) Export
	
	Result = Text;	
	CommonClientServer.SupplementMap(TextParameters, ScriptMessages());
	
	For Each TextParameter In TextParameters Do
		Result = StrReplace(Result, TextParameter.Key, TextParameter.Value);
	EndDo;
	
	Return Result; 
	
EndFunction

Function PrepareText(Val Text) Export 
	
	Text = StrReplace(Text, "\", "\\");
	Text = StrReplace(Text, """", "\""");
	Text = StrReplace(Text, "'", "\'");
	Return "'" + Text + "'";
	
EndFunction

Function ScriptMessages()
	
	Messages = New Map;
	
	// 
	Messages["[TheStartOfStartupMessage]"] = NStr("en = 'Starting: {0}; parameters: {1}; window: {2}; waiting: {3}';");
	Messages["[ExceptionDetailsMessage]"] = NStr("en = 'Exception at the application start: {0}, {1}';");
	Messages["[MessageLaunchResult]"] = NStr("en = 'Return code: {0}';");
	Messages["[StartupFailureMessage]"] = NStr("en = 'The executable file does not exist: {0}';");
	Messages["[MessageLogging1S]"] = NStr("en = 'Exception when writing Event log: {0}, {1}';");
	Messages["[TheMessageIsThePathToTheScriptFile]"] = NStr("en = 'Script file: {0}';");
	Messages["[MessagePathToTheBackupFile]"] = NStr("en = 'Backup file: {0}';");
	Messages["[TheMessageIsTheResultOfCreatingABackupCopyOfTheDatabase]"] = NStr("en = 'Backed up';");
	Messages["[TheMessageFailureToCreateABackupCopyOfTheDatabase]"] = NStr("en = 'Cannot back up the infobase';");
	Messages["[TheMessageTheBeginningOfTheConnectionSessionWithTheDatabase]"] = NStr("en = 'External infobase connection session started';");
	Messages["[MessageOSBitnessUndefined]"] = NStr("en = '<Undefined>';");
	Messages["[MessageCOMConnectorVersion]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Version %1: {0} {1}';"), "comcntr.dll");
	Messages["[TheMessageConnectionFailureWithTheDatabase]"] = NStr("en = 'Exception during COM connection creation at the step: {0}, {1}, {2}';");
	Messages["[TheMessageLoggingFailure1S]"] = NStr("en = 'Exception when writing data to Event log: {0}, {1}';");
	Messages["[TheMessageFailureWhenCallingCompleteBackup]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Exception when calling %1: {0}, {1}';"), "IBBackupServer.FinishBackup");
	Messages["[TheMessageDatabaseBackupResult]"] = NStr("en = 'Infobase is backed up.';");
	Messages["[TheMessageDatabaseBackupFailure]"] = NStr("en = 'An unexpected error occurred while backing up the infobase.';");
	Messages["[TheMessageDatabaseParameters]"] = NStr("en = 'Infobase parameters: {0}.';");
	Messages["[MessageBackupLogging1S]"] = NStr("en = 'The backup protocol is saved to the event log.';");
	Messages["[LoggingFailureMessage]"] = NStr("en = 'Exception when writing data to Event log: {0}, {1}';");
	Messages["[MessageBackupFileSizeInMb]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Infobase ""%1"" file size: {0} MB';"), "1Cv8.1CD");
	Messages["[TheMessageFailedToCompressTheBackupFileINZIP]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Infobase ""%1"" file size exceeds 2 GB. It won''t be compressed to a ZIP archive';"), "1Cv8.1CD");
	Messages["[TheMessageTheBeginningOfCreatingABackupCopyOfTheDatabase]"] = NStr("en = 'Backup started…';");
	Messages["[TheMessageFailureToCreateABackupCopyOfTheDatabaseInDetail]"] = NStr("en = 'Exception when backing up the infobase: {0}, {1}';");
	Messages["[TheMessageAssumptionOfADatabaseBackupError]"] = NStr("en = 'After 15 minutes of runtime, no backup file has been created (size is {0} byte). Probably, an error has occurred. Back up is canceled.';");
	Messages["[MessageErrorDeletingTheLockFile]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'The ""%1"" lock file is not deleted: {0}, {1}';"), "1Cv8.CDN");
	
	// 
	Messages["[SplashScreenMessageStepError]"] = NStr("en = 'An error occurred. Error code: {0}. For more information, see the previous record.';");
	
	// 
	Messages["[TheMessageFailureWhenCallingCompleteRecovery]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Exception when calling %1: {0}, {1}';"), "IBBackupServer.CompleteRestore");
	Messages["[TheMessageDatabaseRecoveryResult]"] = NStr("en = 'Infobase is restored.';");
	Messages["[DatabaseRecoveryFailureMessage]"] = NStr("en = 'An unexpected error occurred while restoring the infobase.';");
	Messages["[MessageRecoveryLogging1S]"] = NStr("en = 'The restore protocol is saved to the event log.';");
	Messages["[TheMessageFailureToTransferTheDatabaseFileToATemporaryDirectory]"] = NStr("en = 'The infobase file is not transferred to a temporary directory. The application might have active sessions: {0}, {1}.';");
	Messages["[MessageAttemptToTransferADatabaseFileToATemporaryDirectory]"] = NStr("en = 'Attempting to transfer an infobase file to a temporary directory ({0} out of 5): {1}, {2}.';");
	Messages["[TheMessageDatabaseRecoveryFailureInDetail]"] = NStr("en = 'Exception when restoring an infobase from a backup: {0}, {1}.';");
	
	Return Messages;
	
EndFunction

Procedure SetTheGeneralParametersOfTheScreenSaver(Parameters) Export 
	
	Parameters["[ProductName]"] = NStr("en = '1C:ENTERPRISE 8.3';");
	Parameters["[Copyright_SSLy]"] = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '© 1C Company, 1996-%1';"), Format(Year(CurrentSessionDate()), "NG=0"));
	
EndProcedure

#EndRegion
