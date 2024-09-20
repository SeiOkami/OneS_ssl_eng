///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Variables

&AtClient
Var BackupInProgress;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Common.IsWindowsClient() Then
		Raise NStr("en = 'Set up data backup and restore using operating system tools or other third-party tools.';");
	EndIf;
	
	If Common.IsWebClient() Then
		Raise NStr("en = 'Web client does not support data backup.';");
	EndIf;
	
	If Not Common.FileInfobase() Then
		Raise NStr("en = 'In the client/server mode, you must back up data by the means of the DBMS.';");
	EndIf;
	
	BackupSettings1 = IBBackupServer.BackupSettings1();
	IBAdministratorPassword = BackupSettings1.IBAdministratorPassword;
	
	If Parameters.WorkMode = "ExecuteNow" Then
		Items.WizardPages.CurrentPage = Items.InformationAndBackupCreationPage;
		If Not IsBlankString(Parameters.Explanation) Then
			Items.WaitGroup.CurrentPage = Items.WaitingForStartPage;
			Items.WaitingForBackupLabel.Title = Parameters.Explanation;
		EndIf;
	ElsIf Parameters.WorkMode = "ExecuteOnExit" Then
		Items.WizardPages.CurrentPage = Items.InformationAndBackupCreationPage;
	ElsIf Parameters.WorkMode = "CompletedSuccessfully1" Then
		Items.WizardPages.CurrentPage = Items.BackupSuccessfulPage;
		BackupFileName = Parameters.BackupFileName;
	ElsIf Parameters.WorkMode = "NotCompleted2" Then
		Items.WizardPages.CurrentPage = Items.BackupCreationErrorsPage;
	EndIf;
	
	AutomaticRun = (Parameters.WorkMode = "ExecuteNow" Or Parameters.WorkMode = "ExecuteOnExit");
	
	If BackupSettings1.Property("ManualBackupsStorageDirectory")
		And Not IsBlankString(BackupSettings1.ManualBackupsStorageDirectory)
		And Not AutomaticRun Then
		Object.BackupDirectory = BackupSettings1.ManualBackupsStorageDirectory;
	Else
		Object.BackupDirectory = BackupSettings1.BackupStorageDirectory;
	EndIf;
	
	If BackupSettings1.LatestBackupDate = Date(1, 1, 1) Then
		TitleText = NStr("en = 'The infobase has never been backed up.';");
	Else
		TitleText = NStr("en = 'Most recent backup: %1';");
		LastBackupDate = Format(BackupSettings1.LatestBackupDate, "DLF=DDT");
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, LastBackupDate);
	EndIf;
	Items.LastBackupDateLabel.Title = TitleText;
	Items.AutomaticBackupGroup.Visible = Not BackupSettings1.CreateBackupAutomatically;
	Items.DonTWaitForSessionsToEnd.Visible = Common.DebugMode();
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
	ManualStart1 = (Items.WizardPages.CurrentPage = Items.BackupCreationPage);
	If ManualStart1 Then
		If InfobaseSessionsCount() > 1 Then
			Items.BackupStatusPages.CurrentPage = Items.ActiveUsersPage;
		EndIf;
		Items.Next.Title = NStr("en = 'Save backup';");
	EndIf;
	
	IBBackupServer.SetSettingValue("LastBackupManualStart", ManualStart1);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GoToPage3(Items.WizardPages.CurrentPage);
	
#If WebClient Then
	Items.UpdateComponentVersionLabel.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	CurrentPage = Items.WizardPages.CurrentPage;
	If CurrentPage <> Items.WizardPages.ChildItems.InformationAndBackupCreationPage Then
		Return;
	EndIf;
	
	WarningText = NStr("en = 'Do you want to cancel preparing for backup?';");
	CommonClient.ShowArbitraryFormClosingConfirmation(ThisObject,
		Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	DetachIdleHandler("Timeout2");
	DetachIdleHandler("CheckForSingleConnection");
	
	If BackupInProgress = True Then
		Return;
	EndIf;
	
	IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
	IBConnectionsClient.SetUserTerminationInProgressFlag(False);
	IBConnectionsServerCall.AllowUserAuthorization();
	
	If ProcessRunning() Then
		SetProcessRunning(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UsersSessions" And Parameter.SessionCount <= 1
		And ApplicationParameters["StandardSubsystems.IBBackupParameters"].ProcessRunning Then
			StartBackup();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsersListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUserList(, ThisObject);
	
EndProcedure

&AtClient
Procedure BackupDirectory2StartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectedPath = GetPath(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedPath) Then 
		Object.BackupDirectory = SelectedPath;
	EndIf;

EndProcedure

&AtClient
Procedure BackupFileNameOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	FileSystemClient.OpenExplorer(BackupFileName);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Next(Command)
	
	ClearMessages();
	
	If Not CheckAttributesFilling() Then
		Return;
	EndIf;
	
	CurrentWizardPage = Items.WizardPages.CurrentPage;
	If CurrentWizardPage = Items.WizardPages.ChildItems.BackupCreationPage Then
		GoToPage3(Items.InformationAndBackupCreationPage);
		SetBackupArchivePath(Object.BackupDirectory);
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

&AtClient
Procedure DonTWaitForSessionsToEnd(Command)
	StartBackup();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GoToPage3(NewPage)
	
	GoToNext = True;
	SubordinatePages = Items.WizardPages.ChildItems;
	If NewPage = SubordinatePages.InformationAndBackupCreationPage Then
		GoToInformationAndBackupPage(GoToNext);
	ElsIf NewPage = SubordinatePages.BackupCreationErrorsPage 
		Or NewPage = SubordinatePages.BackupSuccessfulPage Then
		GoToBackupResultsPage();
	EndIf;
	
	If Not GoToNext Then
		Return;
	EndIf;
	
	If NewPage <> Undefined Then
		Items.WizardPages.CurrentPage = NewPage;
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToInformationAndBackupPage(GoToNext)
	
	If Not CheckAttributesFilling() Then
		Return;
	EndIf;
	
	CheckForBlockingSessions();
	Notification = New NotifyDescription(
		"GoToPageBackupAfterInfobaseAccessCheck", ThisObject);
	IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword, Notification);
	
EndProcedure

&AtClient
Procedure GoToPageBackupAfterInfobaseAccessCheck(ConnectionResult, Context) Export
	
	If ConnectionResult.AddInAttachmentError Then
		Items.WizardPages.CurrentPage = Items.BackupCreationPage;
		Items.BackupStatusPages.CurrentPage = Items.ConnectionErrorPage;
		ConnectionErrorFound = ConnectionResult.BriefErrorDetails;
		Return;
	EndIf;
	
	SetBackupParemeters();
	SetProcessRunning(True);
	
	InfobaseSessionsCount = CheckForBlockingSessions();
	
	Items.Cancel.Enabled = True;
	Items.Next.Enabled = False;
	SetButtonTitleNext(True);
	
	IBConnectionsServerCall.SetConnectionLock(
		NStr("en = 'Backing up the infobase.';"),
		"Backup");
	
	If InfobaseSessionsCount = 1 Then
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(True);
		IBConnectionsClient.SetUserTerminationInProgressFlag(True);
		StartBackup();
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
Procedure GoToBackupResultsPage()
	
	Items.Next.Visible = False;
	Items.Cancel.Title = NStr("en = 'Close';");
	Items.Cancel.DefaultButton = True;
	
	Settings = BackupSettings1();
	IBBackupClient.FillGlobalVariableValues(Settings);
	
	ResetBackupFlag();
	
EndProcedure

&AtServerNoContext
Procedure ResetBackupFlag()
	
	IBBackupServer.ResetBackupFlag();
	
EndProcedure

&AtServer
Procedure SetBackupParemeters()
	
	Settings = IBBackupServer.BackupSettings1();
	Settings.Insert("IBAdministrator", IBAdministrator);
	Settings.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	IBBackupServer.SetBackupSettings(Settings);
	
EndProcedure

&AtServerNoContext
Function BackupSettings1()
	
	Return IBBackupServer.BackupSettings1();
	
EndFunction

&AtClient
Function CheckAttributesFilling()

#If WebClient Then
	MessageText = NStr("en = 'Web client does not support data backup.';");
	CommonClient.MessageToUser(MessageText);
	AttributesFilled = False;
#Else
	
	AttributesFilled = True;
	
	Object.BackupDirectory = TrimAll(Object.BackupDirectory);
	
	If IsBlankString(Object.BackupDirectory) Then
		MessageText = NStr("en = 'Backup directory is not provided.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		MessageText = NStr("en = 'The provided directory does not exist.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
	Else
		
		FileName = "test.test1From1";
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/" + FileName);
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient permissions when writing to the backup directory.
					|Cannot create test file %1 due to: %2';"),
				FileName, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
			CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
			AttributesFilled = False;
		EndTry;
		
		If AttributesFilled Then
			
			// CAC:280-off Exceptions are not processed as files are not deleted on this step.
			Try
				DeleteFiles(Object.BackupDirectory, "*.test1From1");
			Except
			EndTry;
			// ACC:280-on
			
		EndIf;
		
	EndIf;
	
	If PasswordRequired And IsBlankString(IBAdministratorPassword) Then
		MessageText = NStr("en = 'Administrator password is not set.';");
		CommonClient.MessageToUser(MessageText,, "IBAdministratorPassword");
		AttributesFilled = False;
	EndIf;

#EndIf
	
	Return AttributesFilled;
	
EndFunction

&AtClient
Procedure SetIdleHandlerOfBackupTimeout()
	
	AttachIdleHandler("Timeout2", 600, True);
	
EndProcedure

&AtClient
Procedure Timeout2()
	
	DetachIdleHandler("CheckForSingleConnection");
	QueryText = NStr("en = 'Cannot terminate all user sessions. Are you sure you still want to back up the data? The backup might contain errors.';");
	ExplanationText = NStr("en = 'Cannot terminate the user session.';");
	NotifyDescription = New NotifyDescription("Timeout2Completion", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, 30, DialogReturnCode.No, ExplanationText, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure Timeout2Completion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StartBackup();
	Else
		ClearMessages();
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
		CancelPreparation();
EndIf;
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.FailedLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1.
		|Preparation for backing up is canceled. Infobase is unlocked.';"),
		IBConnections.ActiveSessionsMessage());
	Items.WizardPages.CurrentPage = Items.BackupCreationErrorsPage;
	Items.GoToEventLog1.Visible = False;
	Items.Next.Visible = False;
	Items.Cancel.Title = NStr("en = 'Close';");
	Items.Cancel.DefaultButton = True;
	
	IBConnections.AllowUserAuthorization();
	
EndProcedure

&AtClient
Procedure SetIdleIdleHandlerOfBackupStart()
	
	AttachIdleHandler("CheckForSingleConnection", 5);
	
EndProcedure

&AtClient
Procedure CheckForSingleConnection()
	
	UsersCount = InfobaseSessionsCount();
	Items.ActiveUserCount.Title = String(UsersCount);
	If UsersCount = 1 Then
		StartBackup();
	Else
		CheckForBlockingSessions();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetButtonTitleNext(ThisButtonNext)
	
	Items.Next.Title = ?(ThisButtonNext, NStr("en = 'Next >';"), NStr("en = 'Finish';"));
	
EndProcedure

&AtClient
Function GetPath(DialogMode)
	
	Mode = DialogMode;
	OpenFileDialog = New FileDialog(Mode);
	If Mode = FileDialogMode.ChooseDirectory Then
		OpenFileDialog.Title= NStr("en = 'Select directory';");
	Else
		OpenFileDialog.Title= NStr("en = 'Select file';");
	EndIf;	
		
	If OpenFileDialog.Choose() Then
		If DialogMode = FileDialogMode.ChooseDirectory Then
			Return OpenFileDialog.Directory;
		Else
			Return OpenFileDialog.FullFileName;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure StartBackup()
	
#If Not WebClient And Not MobileClient Then
	
	IBBackupClient.DontStopScenariosExecution();
	
	MainScriptFileName = GenerateScriptFiles();
	
	EventLogClient.AddMessageForEventLog(
		IBBackupClient.EventLogEvent(),
		"Information", 
		NStr("en = 'Backing up the infobase backup:';") + " " + MainScriptFileName);
		
	If Parameters.WorkMode = "ExecuteNow" Or Parameters.WorkMode = "ExecuteOnExit" Then
		IBBackupClient.DeleteConfigurationBackups();
	EndIf;
	
	BackupInProgress = True;
	ForceCloseForm = True;
	
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// 

&AtServerNoContext
Procedure SetBackupArchivePath(Path)
	
	PathSettings = IBBackupServer.BackupSettings1();
	PathSettings.Insert("ManualBackupsStorageDirectory", Path);
	IBBackupServer.SetBackupSettings(PathSettings);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Procedures and functions of backup preparation.

#If Not WebClient And Not MobileClient Then

&AtClient
Function GenerateScriptFiles()
	
	BackupParameters = IBBackupClient.ClientBackupParameters();
	CreateDirectory(BackupParameters.TempFilesDirForUpdate);
	
	ScriptParameters = IBBackupClient.GeneralScriptParameters();
	ScriptParameters.BinDir = Parameters.BinDir;
	ScriptParameters.ApplicationFileName = BackupParameters.ApplicationFileName;
	ScriptParameters.EventLogEvent = BackupParameters.EventLogEvent;
	ScriptParameters.COMConnectorName = CommonClientServer.COMConnectorName();
	ScriptParameters.IsBaseConfigurationVersion = StandardSubsystemsClient.IsBaseConfigurationVersion();
	ScriptParameters.ScriptParameters = IBBackupClient.UpdateAdministratorAuthenticationParameters(IBAdministratorPassword);
	ScriptParameters.OneCEnterpriseStartupParameters = CommonInternalClient.EnterpriseStartupParametersFromScript();
	
	Scripts = GenerateScriptsText(ScriptParameters, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	
	// Auxiliary file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.Script);
	ScriptFileName = BackupParameters.TempFilesDirForUpdate + "main.js";
	ScriptFile.Write(ScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	// 
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.AddlBackupFile);
	ScriptFile.Write(BackupParameters.TempFilesDirForUpdate + "helpers.js", 
		IBBackupClient.IBBackupApplicationFilesEncoding());
	
	PictureLib.ExternalOperationSplash.Write(BackupParameters.TempFilesDirForUpdate + "splash.png");
	PictureLib.ExternalOperationSplashIcon.Write(BackupParameters.TempFilesDirForUpdate + "splash.ico");
	PictureLib.TimeConsumingOperation48.Write(BackupParameters.TempFilesDirForUpdate + "progress.gif");
	
	// Main splash file: splash.hta.
	MainScriptFileName = BackupParameters.TempFilesDirForUpdate + "splash.hta";
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(Scripts.BackupSplash);
	ScriptFile.Write(MainScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	LogFile1 = New TextDocument;
	LogFile1.Output = UseOutput.Enable;
	LogFile1.SetText(StandardSubsystemsClient.SupportInformation());
	LogFile1.Write(BackupParameters.TempFilesDirForUpdate + "templog.txt", TextEncoding.System);
	
	Return MainScriptFileName;
	
EndFunction

#EndIf

&AtServer
Function GenerateScriptsText(Val ScriptParameters, MessagesForEventLog)
	
	EventLog.WriteEventsToEventLog(MessagesForEventLog);
	
	Result = New Structure("Script, AddlBackupFile, BackupSplash");
	Result.Script = GenerateScriptText(ScriptParameters);
	Result.AddlBackupFile = DataProcessors.IBBackup.GetTemplate("AddlBackupFile").GetText();
	Result.BackupSplash = GenerateSplashText();
	Return Result;
	
EndFunction

&AtServer
Function GenerateScriptText(ScriptParameters)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.IBBackup.GetTemplate("BackupFileTemplate");
	
	Script = ScriptTemplate.GetArea("ParametersArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount());
	If StrStartsWith(Script.GetLine(Script.LineCount()), "#") Then
		Script.DeleteLine(Script.LineCount());
	EndIf;
	
	Text = ScriptTemplate.GetArea("BackupArea");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ScriptParameters)
		+ InsertScriptParameters(Text.GetText(), ScriptParameters);
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ScriptParameters)
	
	DirectoryName = CheckDirectoryForRootItemIndication(Object.BackupDirectory);
	
	TextParameters = IBBackupServer.PrepareCommonScriptParameters(ScriptParameters);
	TextParameters["[CreateDataBackup]"] = "true";
	TextParameters["[BackupDirectory]"] = IBBackupServer.PrepareText(DirectoryName + "\backup" + DirectoryStringFromDate());
	TextParameters["[RestoreInfobase]"] = "false";
	TextParameters["[ExecuteOnExit]"] = ?(Parameters.WorkMode = "ExecuteOnExit", "true", "false");
	
	Return IBBackupServer.SubstituteParametersToText(Text, TextParameters);
	
EndFunction

&AtServer
Function GenerateSplashText()
	
	TextTemplate1 = DataProcessors.IBBackup.GetTemplate("BackupSplash").GetText();
	
	TextParameters = New Map;
	TextParameters["[SplashTitle]"] = NStr("en = 'Creating infobase backup…';");
	TextParameters["[SplashText]"] = 
		NStr("en = 'Please wait.
			|<br /> Infobase backup is in progress.
			|<br /> It is recommended that you do not interrupt this operation.';");
	
	TextParameters["[Step1Initialization]"] = NStr("en = 'Initialization';");
	TextParameters["[Step2BackupCreation]"] = NStr("en = 'Creating infobase backup';");
	TextParameters["[Step3AwaitingCompletion]"] = NStr("en = 'Awaiting backup completion';");
	TextParameters["[Step4AllowConnections]"] = NStr("en = 'Allowing new connections';");
	TextParameters["[Step5Completion]"] = NStr("en = 'Completion';");
	TextParameters["[ProcessIsAborted]"] = NStr("en = 'Warning! The backup was interrupted and the infobase is still locked.';");
	TextParameters["[AbortedTooltip]"] = NStr("en = 'To unlock the infobase, use the server cluster console or run 1C:Enterprise.';");
	
	IBBackupServer.SetTheGeneralParametersOfTheScreenSaver(TextParameters);
	
	Return IBBackupServer.SubstituteParametersToText(TextTemplate1, TextParameters);
	
EndFunction

&AtServer
Function CheckDirectoryForRootItemIndication(DirectoryString)
	
	If StrEndsWith(DirectoryString, ":\") Then
		Return Left(DirectoryString, StrLen(DirectoryString) - 1) ;
	Else
		Return DirectoryString;
	EndIf;
	
EndFunction

&AtServer
Function DirectoryStringFromDate()
	
	ReturnString = "";
	DateNow = CurrentSessionDate();
	ReturnString = Format(DateNow, "DF = yyyy_MM_dd_HH_mm_ss");
	Return ReturnString;
	
EndFunction

&AtClient
Procedure UpdateComponentVersionLabelURLProcessing(Item, Var_URL, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.RegisterCOMConnector();
	
EndProcedure

&AtServerNoContext
Function InfobaseSessionsCount()
	
	Return IBConnections.InfobaseSessionsCount(False, False);
	
EndFunction

&AtClient
Function ProcessRunning()
	
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	If Settings = Undefined Then
		NewSettings1 = BackupSettings1();
		IBBackupClient.FillGlobalVariableValues(NewSettings1);
		Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	EndIf;	
	Return ?(Settings.ProcessRunning <> Undefined, Settings.ProcessRunning, False);
	
EndFunction

&AtClient
Procedure SetProcessRunning(Val ProcessRunning)
	
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	If Settings = Undefined Then
		NewSettings1 = BackupSettings1();
		IBBackupClient.FillGlobalVariableValues(NewSettings1);
		Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	EndIf;	
	Settings.ProcessRunning = ProcessRunning;
	IBBackupServerCall.SetSettingValue("ProcessRunning", ProcessRunning);
	
EndProcedure

#EndRegion
