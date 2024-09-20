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
Var WriteSettings, NextDate;

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
	
	BackupSettings1 = IBBackupServer.BackupSettings1();
	
	Object.ExecutionOption = BackupSettings1.ExecutionOption;
	Object.CreateBackupAutomatically = BackupSettings1.CreateBackupAutomatically;
	Object.BackupConfigured = BackupSettings1.BackupConfigured;
	
	If Not Object.BackupConfigured Then
		Object.CreateBackupAutomatically = True;
	EndIf;
	IsBaseConfigurationVersion = StandardSubsystemsServer.IsBaseConfigurationVersion();
	Items.Normal.Visible = Not IsBaseConfigurationVersion;
	Items.Basic.Visible = IsBaseConfigurationVersion;
	
	IBAdministratorPassword = BackupSettings1.IBAdministratorPassword;
	Schedule = CommonClientServer.StructureToSchedule(BackupSettings1.CopyingSchedule);
	Items.ModifySchedule.Title = String(Schedule);
	Object.BackupDirectory = BackupSettings1.BackupStorageDirectory;
	
	// Filling settings for storing old copies.
	
	FillPropertyValues(Object, BackupSettings1.DeletionParameters);
	
	UpdateBackupDirectoryRestrictionType(ThisObject);
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		Items.InfobaseAdministratorAuthorization.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	If Settings = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	NextDate = Settings.MinDateOfNextAutomaticBackup;
	Settings.MinDateOfNextAutomaticBackup = '29990101';
	WriteSettings = False;
	
	
#If WebClient Then
	Items.UpdateComponentVersionLabel.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If WriteSettings Then
		ParameterName = "IBBackupOnExit";
		ParametersOnExit = New Structure(StandardSubsystemsClient.ClientParameter(ParameterName));
		ParametersOnExit.ExecuteOnExit1 = Object.CreateBackupAutomatically
			And Object.ExecutionOption = "OnExit";
		ParametersOnExit = New FixedStructure(ParametersOnExit);
		StandardSubsystemsClient.SetClientParameter(ParameterName, ParametersOnExit);
	Else
		Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
		Settings.MinDateOfNextAutomaticBackup = NextDate;
	EndIf;
	
	If Exit Then
		Return;
	EndIf;
	
	Notify("BackupSettingsFormClosed");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CreateBackupAutomaticallyOnChange(Item)
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure BackupDirectoryRestrictionTypeOnChange(Item)
	
	
	UpdateBackupDirectoryRestrictionType(ThisObject);
	
EndProcedure

&AtClient
Procedure BackupDirectory2StartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.Title= NStr("en = 'Choose a directory to save backups to';");
	OpenFileDialog.Directory = Items.PathToBackupDirectory.EditText;
	
	If OpenFileDialog.Choose() Then
		Object.BackupDirectory = OpenFileDialog.Directory;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLogLabelClick(Item)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

&AtClient
Procedure BackupOptionOnChange(Item)
	
	Items.ModifySchedule.Enabled = (Object.ExecutionOption = "Schedule3");
	
EndProcedure

&AtClient
Procedure BackupRetentionPeriodUnitOfMeasurementClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UpdateComponentVersionLabelURLProcessing(Item, Var_URL, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.RegisterCOMConnector();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Done(Command)
	
	WriteSettings = True;
	GoFromSettingPage();
	
EndProcedure

&AtClient
Procedure ModifySchedule(Command)
	
	ScheduleDialog1 = New ScheduledJobDialog(Schedule);
	NotifyDescription = New NotifyDescription("ModifyScheduleCompletion", ThisObject);
	ScheduleDialog1.Show(NotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GoFromSettingPage()
	
	Settings = ApplicationParameters["StandardSubsystems.IBBackupParameters"];
	CurrentUser = UsersClient.CurrentUser();
	
	If Object.CreateBackupAutomatically Then
		
		If Not CheckDirectoryWithBackups() Then
			Return;
		EndIf;
		
		Context = New Structure;
		Context.Insert("IBBackupParameters", Settings);
		Context.Insert("CurrentUser", CurrentUser);
		
		Notification = New NotifyDescription(
			"NavigateFromSettingPageAfterCheckAccessToInfobase", ThisObject, Context);
		
		IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword, Notification);
		Return;
	EndIf;
		
	StopNotificationService(CurrentUser);
	IBBackupClient.DisableBackupIdleHandler();
	Settings.MinDateOfNextAutomaticBackup = '29990101';
	Settings.NotificationParameter1 = "DontNotify";
	
	RefreshReusableValues();
	Close();
	
EndProcedure

&AtClient
Procedure NavigateFromSettingPageAfterCheckAccessToInfobase(ConnectionResult, Context) Export
	
	IBBackupParameters = Context.IBBackupParameters;
	CurrentUser = Context.CurrentUser;
	
	If ConnectionResult.AddInAttachmentError Then
		Items.WizardPages.CurrentPage = Items.AdditionalSettings;
		ConnectionErrorFound = ConnectionResult.BriefErrorDetails;
		Return;
	EndIf;
	
	WriteSettings(CurrentUser);
	
	If Object.ExecutionOption = "Schedule3" Then
		CurrentDate = CommonClient.SessionDate();
		IBBackupParameters.MinDateOfNextAutomaticBackup = CurrentDate;
		IBBackupParameters.LatestBackupDate = CurrentDate;
		IBBackupParameters.ScheduleValue1 = Schedule;
	ElsIf Object.ExecutionOption = "OnExit" Then
		IBBackupParameters.MinDateOfNextAutomaticBackup = '29990101';
	EndIf;
	
	IBBackupClient.AttachIdleBackupHandler();
	
	SettingsFormName = "e1cib/app/DataProcessor.IBBackupSetup/";
	
	ShowUserNotification(NStr("en = 'Backup';"), SettingsFormName,
		NStr("en = 'Backup is all set up.';"));
	
	IBBackupParameters.NotificationParameter1 = "DontNotify";
	
	RefreshReusableValues();
	Close();
	
EndProcedure

&AtClient
Function CheckDirectoryWithBackups()
	
#If WebClient Or MobileClient Then
	MessageText = NStr("en = 'Cannot perform the operation in web client or mobile client.
		|Start thin client.';");
	CommonClient.MessageToUser(MessageText);
	AttributesFilled = False;
#Else
	AttributesFilled = True;
	
	If IsBlankString(Object.BackupDirectory) Then
		
		MessageText = NStr("en = 'Select a folder for backup.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		
		MessageText = NStr("en = 'Non-existent folder is specified.';");
		CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	Else
		
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/test.test1From1");
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = NStr("en = 'Cannot access the backup folder.';");
			CommonClient.MessageToUser(MessageText,, "Object.BackupDirectory");
			AttributesFilled = False;
		EndTry;
		
		If AttributesFilled Then
			
			Try
				DeleteFiles(Object.BackupDirectory, "*.test1From1");
			Except
				// 
			EndTry;
			
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

&AtServerNoContext
Procedure StopNotificationService(CurrentUser)
	// Stops notifications of backup.
	BackupSettings1 = IBBackupServer.BackupSettings1();
	BackupSettings1.CreateBackupAutomatically = False;
	BackupSettings1.BackupConfigured = True;
	BackupSettings1.MinDateOfNextAutomaticBackup = '29990101';
	IBBackupServer.SetBackupSettings(BackupSettings1, CurrentUser);
EndProcedure

&AtServer
Procedure WriteSettings(CurrentUser)
	
	IsBaseConfigurationVersion = StandardSubsystemsServer.IsBaseConfigurationVersion();
	If IsBaseConfigurationVersion Then
		Object.ExecutionOption = "OnExit";
	EndIf;
	
	Settings = IBBackupServer.BackupParameters();
	
	Settings.Insert("IBAdministrator", IBAdministrator);
	Settings.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	Settings.LastNotificationDate = Date('29990101');
	Settings.BackupStorageDirectory = Object.BackupDirectory;
	Settings.ExecutionOption = Object.ExecutionOption;
	Settings.CreateBackupAutomatically = Object.CreateBackupAutomatically;
	Settings.BackupConfigured = True;
	
	FillPropertyValues(Settings.DeletionParameters, Object);
	
	If Object.ExecutionOption = "Schedule3" Then
		
		ScheduleStructure = CommonClientServer.ScheduleToStructure(Schedule);
		Settings.CopyingSchedule = ScheduleStructure;
		Settings.MinDateOfNextAutomaticBackup = CurrentSessionDate();
		Settings.LatestBackupDate = CurrentSessionDate();
		
	ElsIf Object.ExecutionOption = "OnExit" Then
		
		Settings.MinDateOfNextAutomaticBackup = '29990101';
		
	EndIf;
	
	IBBackupServer.SetBackupSettings(Settings, CurrentUser);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateBackupDirectoryRestrictionType(Form)
	
	Form.Items.GroupStoreLastBackupsForPeriod.Enabled = (Form.Object.RestrictionType = "ByPeriod");
	Form.Items.BackupsCountInDirectoryGroup.Enabled = (Form.Object.RestrictionType = "ByCount");
	
EndProcedure

&AtClient
Procedure ModifyScheduleCompletion(ScheduleResult, AdditionalParameters) Export
	
	If ScheduleResult = Undefined Then
		Return;
	EndIf;
	
	Schedule = ScheduleResult;
	Items.ModifySchedule.Title = String(Schedule);
	
EndProcedure

/////////////////////////////////////////////////////////
// 

&AtServer
Procedure SetVisibilityAvailability()
	
	Items.ModifySchedule.Enabled = (Object.ExecutionOption = "Schedule3");
	
	BackupAvailable = Object.CreateBackupAutomatically;
	Items.GroupParameters.Enabled = BackupAvailable;
	Items.SelectAutomaticBackupOption.Enabled = BackupAvailable;
	
EndProcedure

#EndRegion
