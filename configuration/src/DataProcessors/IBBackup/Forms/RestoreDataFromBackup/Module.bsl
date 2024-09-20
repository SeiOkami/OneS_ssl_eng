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
	
	If Not Common.IsWindowsClient() Then
		Raise NStr("en = 'Set up data backup and restore using operating system tools or other third-party tools.';");
	EndIf;
	
	If Common.IsWebClient()
		Or Common.IsMobileClient() Then
		Raise NStr("en = 'Web client and mobile client do not support data backup.';");
	EndIf;
	
	If Not Common.FileInfobase() Then
		Raise NStr("en = 'In the client/server mode, you must back up data by the means of the DBMS.';");
	EndIf;
	
	BackupSettings1 = IBBackupServer.BackupSettings1();
	IBAdministratorPassword = BackupSettings1.IBAdministratorPassword;
	Object.BackupDirectory = BackupSettings1.BackupStorageDirectory;
	
	If InfobaseSessionsCount() > 1 Then
		Items.RecoveryStatusPages.CurrentPage = Items.ActiveUsersPage;
	EndIf;
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
	Items.DonTWaitForSessionsToEnd.Visible = Common.DebugMode();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	Items.ComcntrGroupFileMode.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	CurrentPage = Items.DataImportPages.CurrentPage;
	If CurrentPage <> Items.DataImportPages.ChildItems.InformationAndBackupCreationPage Then
		Return;
	EndIf;
	
	WarningText = NStr("en = 'Do you want to cancel data restore preparations?';");
	CommonClient.ShowArbitraryFormClosingConfirmation(ThisObject,
		Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
	IBConnectionsClient.SetUserTerminationInProgressFlag(False);
	IBConnectionsServerCall.AllowUserAuthorization();
	
	DetachIdleHandler("Timeout2");
	DetachIdleHandler("CheckForSingleConnection");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UsersSessions" And Parameter.SessionCount <= 1
		And Items.DataImportPages.CurrentPage = Items.InformationAndBackupCreationPage Then
			StartDataRecovery();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BackupDirectory2StartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectBackupFile();
	
EndProcedure

&AtClient
Procedure UsersListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUserList(, ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateComponentVersionLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.RegisterCOMConnector();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FormCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	If Not CheckAttributesFilling() Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("FinishAfterCheckInfobaseAccess", ThisObject);
	
	IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword, Notification);
	
EndProcedure

&AtClient
Procedure DonTWaitForSessionsToEnd(Command)
	StartDataRecovery();
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FinishAfterCheckInfobaseAccess(ConnectionResult, Context) Export
	
	If ConnectionResult.AddInAttachmentError Then
		Items.RecoveryStatusPages.CurrentPage = Items.ConnectionErrorPage;
		ConnectionErrorFound = ConnectionResult.BriefErrorDetails;
		Return;
	EndIf;
	
	SetBackupParemeters();
	
	Pages = Items.DataImportPages;
	
	Pages.CurrentPage = Items.InformationAndBackupCreationPage; 
	Items.Close.Enabled = True;
	Items.Done.Enabled = False;
	
	InfobaseSessionsCount = CheckForBlockingSessions();
	
	IBConnectionsServerCall.SetConnectionLock(
		NStr("en = 'Restoring the infobase…';"),
		"Backup");
	
	If InfobaseSessionsCount = 1 Then
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(True);
		IBConnectionsClient.SetUserTerminationInProgressFlag(True);
		StartDataRecovery();
	Else
		IBConnectionsClient.SetTheUserShutdownMode(True);
		SetIdleIdleHandlerOfBackupStart();
		SetIdleHandlerOfBackupTimeout();
	EndIf;
	
EndProcedure

&AtServer
Function CheckForBlockingSessions()
	
	InfobaseSessionsCount = InfobaseSessionsCount();
	Items.ActiveUserCount.Title = InfobaseSessionsCount;
	
	BlockingSessionsInformation = IBConnections.BlockingSessionsInformation("");
	HasBlockingSessions = BlockingSessionsInformation.HasBlockingSessions;
	
	If HasBlockingSessions Then
		Items.ActiveSessionsDecoration.Title = BlockingSessionsInformation.MessageText;
	EndIf;
	
	Items.ActiveSessionsDecoration.Visible = HasBlockingSessions;
	Return InfobaseSessionsCount;
	
EndFunction

&AtClient
Procedure SetIdleHandlerOfBackupTimeout()
	
	AttachIdleHandler("Timeout2", 600, True);
	
EndProcedure

&AtClient
Procedure SetIdleIdleHandlerOfBackupStart() 
	
	AttachIdleHandler("CheckForSingleConnection", 5);
	
EndProcedure

&AtClient
Procedure SelectBackupFile()
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.Filter = NStr("en = 'Infobase backup (*.zip, *.1CD)|*.zip;*.1cd';");
	OpenFileDialog.Title= NStr("en = 'Select a backup file';");
	OpenFileDialog.CheckFileExist = True;
	
	If OpenFileDialog.Choose() Then
		
		Object.BackupImportFile = OpenFileDialog.FullFileName;
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckAttributesFilling()
	
#If WebClient Or MobileClient Then
	MessageText = NStr("en = 'Web client and mobile client do not support data backup.';");
	CommonClient.MessageToUser(MessageText);
	Return False;
#Else
	
	If PasswordRequired And IsBlankString(IBAdministratorPassword) Then
		MessageText = NStr("en = 'Administrator password is not set.';");
		CommonClient.MessageToUser(MessageText,, "IBAdministratorPassword");
		Return False;
	EndIf;
	
	Object.BackupImportFile = TrimAll(Object.BackupImportFile);
	FileName = TrimAll(Object.BackupImportFile);
	
	If IsBlankString(FileName) Then
		MessageText = NStr("en = 'Backup file is not provided.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
	EndIf;
	
	ArchiveFile1 = New File(FileName);
	If Upper(ArchiveFile1.Extension) <> ".ZIP" And Upper(ArchiveFile1.Extension) <> ".1CD"  Then
		
		MessageText = NStr("en = 'The selected file is not a backup file.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
		
	EndIf;
	
	If Upper(ArchiveFile1.Extension) = ".1CD" Then
		
		If Upper(ArchiveFile1.BaseName) <> "1CV8" Then
			MessageText = NStr("en = 'The selected file is not a valid backup file for this infobase. It contains another infobase name.';");
			CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
		EndIf;
		
	Else 
		
		Try
			ZipFile = New ZipFileReader(FileName);
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr(
					"en = 'The selected archive file with a backup is damaged or is not a ZIP archive (%1).';"),
					ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
		EndTry;
		
		If ZipFile.Items.Count() <> 1 Then
			
			MessageText = NStr("en = 'The selected file is not a valid backup file. It contains more than one file.';");
			CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
			
		EndIf;
		
		FileInArchive = ZipFile.Items[0];
		
		If Upper(FileInArchive.Extension) <> "1CD" Then
			
			MessageText = NStr("en = 'The selected file is not a valid backup file. It does not contain any infobase.';");
			CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
			
		EndIf;
		
		If Upper(FileInArchive.BaseName) <> "1CV8" Then
			
			MessageText = NStr("en = 'The selected file is not a valid backup file. The infobase name is not correct.';");
			CommonClient.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
#EndIf
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure Timeout2()
	
	DetachIdleHandler("CheckForSingleConnection");
	CancelPreparation();
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.FailedLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1.
		|Preparation for restoring data is canceled. Infobase is unlocked.';"),
		IBConnections.ActiveSessionsMessage());
	Items.DataImportPages.CurrentPage = Items.BackupCreationErrorsPage;
	Items.Done.Visible = False;
	Items.Close.Title = NStr("en = 'Close';");
	Items.Close.DefaultButton = True;
	
	IBConnections.AllowUserAuthorization();
	
EndProcedure

&AtClient
Procedure CheckForSingleConnection()
	
	If InfobaseSessionsCount() = 1 Then
		StartDataRecovery();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartDataRecovery() 
	
#If Not WebClient And Not MobileClient Then
	
	IBBackupClient.DontStopScenariosExecution();
	
	MainScriptFileName = GenerateScriptFiles();
	EventLogClient.AddMessageForEventLog(
		IBBackupClient.EventLogEvent(), 
		"Information",
		NStr("en = 'Restoring the infobase:';") + " " + MainScriptFileName);
	
	ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
	
	PathToLauncher = StandardSubsystemsClient.SystemApplicationsDirectory() + "mshta.exe";
	
	CommandLine1 = """%1"" ""%2"" [p1]%3[/p1]";
	CommandLine1 = StringFunctionsClientServer.SubstituteParametersToString(
		CommandLine1,
		PathToLauncher, 
		MainScriptFileName, 
		IBBackupClient.StringUnicode(IBAdministratorPassword));
	
	ApplicationStartupParameters = FileSystemClient.ApplicationStartupParameters();
	ApplicationStartupParameters.Notification = New NotifyDescription("AfterStartScript", ThisObject);
	ApplicationStartupParameters.WaitForCompletion = False;
	
	FileSystemClient.StartApplication(CommandLine1, ApplicationStartupParameters);
	
#EndIf
	
EndProcedure

&AtClient
Procedure AfterStartScript(Result, Context) Export
	
	If Result.ApplicationStarted Then
		Terminate();
	Else 
		ShowMessageBox(, Result.ErrorDescription);
	EndIf;
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of data recovery preparation.

#If Not WebClient And Not MobileClient Then

&AtClient
Function GenerateScriptFiles() 
	
	CopyingParameters = IBBackupClient.ClientBackupParameters();
	CreateDirectory(CopyingParameters.TempFilesDirForUpdate);
	
	ScriptParameters = IBBackupClient.GeneralScriptParameters();
	ScriptParameters.ApplicationFileName = CopyingParameters.ApplicationFileName;
	ScriptParameters.EventLogEvent = CopyingParameters.EventLogEvent;
	ScriptParameters.COMConnectorName = CommonClientServer.COMConnectorName();
	ScriptParameters.IsBaseConfigurationVersion = StandardSubsystemsClient.IsBaseConfigurationVersion();
	ScriptParameters.ScriptParameters = IBBackupClient.UpdateAdministratorAuthenticationParameters(IBAdministratorPassword);
	ScriptParameters.OneCEnterpriseStartupParameters = CommonInternalClient.EnterpriseStartupParametersFromScript();
	
	Scripts = GenerateScriptsText(ScriptParameters, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	
	// Auxiliary file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.Script);
	ScriptFileName = CopyingParameters.TempFilesDirForUpdate + "main.js";
	ScriptFile.Write(ScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	// 
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.AddlBackupFile);
	ScriptFile.Write(CopyingParameters.TempFilesDirForUpdate + "helpers.js", IBBackupClient.IBBackupApplicationFilesEncoding());
	
	PictureLib.ExternalOperationSplash.Write(CopyingParameters.TempFilesDirForUpdate + "splash.png");
	PictureLib.ExternalOperationSplashIcon.Write(CopyingParameters.TempFilesDirForUpdate + "splash.ico");
	PictureLib.TimeConsumingOperation48.Write(CopyingParameters.TempFilesDirForUpdate + "progress.gif");
	
	// Main splash file: splash.hta.
	MainScriptFileName = CopyingParameters.TempFilesDirForUpdate + "splash.hta";
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.RecoverySplash);
	ScriptFile.Write(MainScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	LogFile1 = New TextDocument;
	LogFile1.Output = UseOutput.Enable;
	LogFile1.SetText(StandardSubsystemsClient.SupportInformation());
	LogFile1.Write(CopyingParameters.TempFilesDirForUpdate + "templog.txt", TextEncoding.System);
	
	Return MainScriptFileName;
	
EndFunction

#EndIf

&AtServer
Function GenerateScriptsText(ScriptParameters, MessagesForEventLog)
	
	EventLog.WriteEventsToEventLog(MessagesForEventLog);
	
	Result = New Structure("Script, AddlBackupFile, RecoverySplash");
	Result.Script = GenerateScriptText(ScriptParameters);
	Result.AddlBackupFile = DataProcessors.IBBackup.GetTemplate("AddlBackupFile").GetText();
	Result.RecoverySplash = GenerateSplashText();
	Return Result;
	
EndFunction

&AtServer
Function GenerateScriptText(ScriptParameters)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.IBBackup.GetTemplate("LoadIBFileTemplate");
	
	Script = ScriptTemplate.GetArea("ParametersArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount());
	
	Text = ScriptTemplate.GetArea("BackupArea");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ScriptParameters)
		+ InsertScriptParameters(Text.GetText(), ScriptParameters);
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ScriptParameters)
	
	TextParameters = IBBackupServer.PrepareCommonScriptParameters(ScriptParameters);
	TextParameters["[BackupFile]"] = IBBackupServer.PrepareText(Object.BackupImportFile);
	// ACC:495-
	TextParameters["[TempFilesDir]"] = IBBackupServer.PrepareText(TempFilesDir()); 
	// ACC:495-
	Return IBBackupServer.SubstituteParametersToText(Text, TextParameters);
	
EndFunction

&AtServer
Function GenerateSplashText()
	
	TextTemplate1 = DataProcessors.IBBackup.GetTemplate("RecoverySplash").GetText();
	
	TextParameters = New Map;
	TextParameters["[SplashTitle]"] = NStr("en = 'Restoring data from backup…';");
	TextParameters["[SplashText]"] = 
		NStr("en = 'Please wait.
			|<br /> Restoring the database 
			|<br /> from a backup.
			|<br /> It is recommended that you do not interrupt this operation.';");
	
	TextParameters["[Step1Initialization]"] = NStr("en = 'Initializing';");
	TextParameters["[Step2DataRecovery]"] = NStr("en = 'Restoring data';");
	TextParameters["[Step3AwaitingCompletion]"] = NStr("en = 'Waiting for data restore to complete';");
	TextParameters["[Step4AllowConnections]"] = NStr("en = 'Allowing new connections';");
	TextParameters["[Step5Completion]"] = NStr("en = 'Completing';");
	TextParameters["[ProcessIsAborted]"] = NStr("en = 'Warning! The data restore was interrupted and the infobase is still locked.';");
	TextParameters["[AbortedTooltip]"] = NStr("en = 'To unlock the infobase, use the server cluster console or run 1C:Enterprise.';");
	
	IBBackupServer.SetTheGeneralParametersOfTheScreenSaver(TextParameters);
	
	Return IBBackupServer.SubstituteParametersToText(TextTemplate1, TextParameters);
	
EndFunction

&AtServer
Procedure SetBackupParemeters()
	
	BackupParameters = IBBackupServer.BackupSettings1();
	
	BackupParameters.Insert("IBAdministrator", IBAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	
	IBBackupServer.SetBackupSettings(BackupParameters);
	
EndProcedure

&AtServerNoContext
Function InfobaseSessionsCount()
	
	Return IBConnections.InfobaseSessionsCount(False, False);
	
EndFunction

#EndRegion
