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
Var AdministrationParameters;

&AtClient
Var PatchesFiles; // Array of TransferableFileDescription

&AtClient
Var FirstOpeningOfForm; // Boolean

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ConfigurationUpdate.HasRightsToInstallUpdate() Then
		Raise NStr("en = 'Insufficient rights to update the configuration. Please contact the administrator.';");
	ElsIf Users.IsExternalUserSession() Then
		Raise NStr("en = 'This operation is not available to external users.';");
	EndIf;
	
	If Not Common.IsWindowsClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	IsFileInfobase = Common.FileInfobase();
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	
	// 
	Object.UpdateResult = ConfigurationUpdate.ConfigurationUpdateSuccessful(ScriptDirectory);
	If Object.UpdateResult <> Undefined Then
		ConfigurationUpdate.ResetConfigurationUpdateStatus();
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		Items.EmailPanel.Visible = False;
	EndIf;
	
	Items.IssuesDiscoveredLabel.Visible = SystemCheckIssues();
	Items.ExtensionsAvailableLabel.Visible     = ConfigurationUpdate.WarnAboutExistingExtensions();
	
	Items.WarningsPanel.Visible = Items.IssuesDiscoveredLabel.Visible
		Or Items.ExtensionsAvailableLabel.Visible;
	
	// Checking every time the wizard is opened.
	ConfigurationChanged = ConfigurationChanged();
	LoadExtensions = LoadExtensionsThatChangeDataStructure();
	IsWebClient = Common.IsWebClient() Or Common.ClientConnectedOverWebServer();
	UpdateFileRequired = ?((ConfigurationChanged Or LoadExtensions) And Not IsWebClient, 0, 1);
	
	If Parameters.ShouldExitApp Then
		Items.UpdateRadioButtonsFile.Visible = False;
		Items.UpdateRadioButtonsServer.Visible = False;
		Items.UpdateDateTimeField.Visible = False;
		Items.ClickNextLabel.Visible = True;
	EndIf;
	
	If Parameters.IsConfigurationUpdateReceived Then
		Items.UpdateMethodFilePages.CurrentPage = Items.UpdateReceivedFromApplicationFilePage;
	EndIf;
	
	Items.ConfigurationIsUpdatedDuringDataExchangeWithMainNodeLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
		Items.ConfigurationIsUpdatedDuringDataExchangeWithMainNodeLabel.Title, ExchangePlans.MasterNode());
	
	SetPrivilegedMode(True);
	
	If IsBlankString(Parameters.SelectedFiles) Then 
		RestoreConfigurationUpdateSettings();
	Else 
		SelectedFiles = Parameters.SelectedFiles;
	EndIf;
	
	If IsFileInfobase And Object.UpdateMode > 1 Or Parameters.ShouldExitApp Then
		Object.UpdateMode = 0;
	EndIf;
	
	Items.FindAndInstallUpdates.Visible = Common.SubsystemExists("OnlineUserSupport.GetApplicationUpdates");
	
	If IsWebClient Then 
		SelectionOptionTitle = NStr("en = 'Specify a patch file:';");
		Items.UpdateFileRequiredRadioButtons.ChoiceList[1].Presentation = SelectionOptionTitle;
	EndIf;
	
	FillInformationPanel();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Result = ConfigurationUpdateClient.UpdatesInstallationSupported();
	If Not Result.Supported
		And Not Result.InstallationOfPatchesIsSupported Then
		
		ShowMessageBox(, Result.ErrorDescription);
		Cancel = True;
		Return;
	EndIf;
	
	FirstOpeningOfForm = True;
	
	DescriptionOfTheSelectedFiles = ?(ValueIsFilled(PatchesFilesAsString), PatchesFilesAsString, SelectedFiles);
	InitializePatchFiles(DescriptionOfTheSelectedFiles);
	
	If Parameters.RunUpdate Then
		ProceedToUpdateModeSelection();
		Return;
	EndIf;
	
	Pages    = Items.WizardPages.ChildItems;
	PageName = Pages.UpdateFile.Name;
	
	If IsSubordinateDIBNode Then
		If ConfigurationChanged Or LoadExtensions Then
			ProceedToUpdateModeSelection();
			Return;
		EndIf;
		PageName = Pages.NoUpdatesFound.Name;
	EndIf;
	
	BeforeOpenPage(Pages[PageName]);
	Items.WizardPages.CurrentPage = Pages[PageName];
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.ActiveUsers.Form.ActiveUsers") Then
		UpdateConnectionsInformation();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "LegitimateSoftware" And Not Parameter Then
		HandleBackButtonClick();
	ElsIf EventName = "AccountingAuditSuccessfulCheck" Then
		FillInformationPanel();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	ConfigurationUpdateClient.WriteEventsToEventLog();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UpdateFileRequiredRadioButtonsOnChange(Item)
	BeforeOpenPage();
EndProcedure

&AtClient
Procedure UpdateFileFieldStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("SelectUpdateFile", 0.1, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ActiveUsersDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	ShowActiveUsers();
EndProcedure

&AtClient
Procedure PatchInstallationErrorLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	LogFilter = New Structure;
	LogFilter.Insert("EventLogEvent", NStr("en = 'Patch.Install';"));
	EventLogClient.OpenEventLog(LogFilter);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure ActionsListLabelClick(Item)
	ShowActiveUsers();
EndProcedure

&AtClient
Procedure ActionsListLabel1Click(Item)
	ShowActiveUsers();
EndProcedure

&AtClient
Procedure ActionsListLabel3Click(Item)
	ShowActiveUsers();
EndProcedure

&AtClient
Procedure BackupLabelClick(Item)
	
	BackupParameters = New Structure;
	BackupParameters.Insert("CreateDataBackup",           Object.CreateDataBackup);
	BackupParameters.Insert("IBBackupDirectoryName",       Object.IBBackupDirectoryName);
	BackupParameters.Insert("RestoreInfobase", Object.RestoreInfobase);
	
	NotifyDescription = New NotifyDescription("AfterCloseBackupForm", ThisObject);
	ConfigurationUpdateClient.ShowBackup(BackupParameters, NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterCloseBackupForm(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		FillPropertyValues(Object, Result);
		Items.BackupFileLabel.Title = ConfigurationUpdateClient.BackupCreationTitle(Result);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure UpdateRadioButtonsOnChange(Item)
	BeforeOpenPage();
EndProcedure

&AtClient
Procedure EmailReportOnChange(Item)
	BeforeOpenPage();
EndProcedure

&AtClient
Procedure DeferredHandlersLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	InfobaseUpdateClient.ShowDeferredHandlers();
	
EndProcedure

&AtClient
Procedure IssuesDiscoveredLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.OpenIssuesReportFromUpdateProcessing(ThisObject, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure InformationLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.OpenAccountingChecksList();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtensionsAvailableLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	OpenForm("CommonForm.Extensions");
EndProcedure

&AtServer
Function SystemCheckIssues()
	
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		Return ModuleAccountingAuditInternal.SystemCheckIssues();
	EndIf;
	Return False;
	
EndFunction

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure BackButtonClick(Command)
	HandleBackButtonClick();
EndProcedure

&AtClient
Procedure NextButtonClick(Command)
	HandleNextButtonClick();
EndProcedure

&AtClient
Procedure FindAndInstallUpdates(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		Close();
		ModuleGetApplicationUpdatesClient = CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.UpdateProgram();
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillInformationPanel()
	
	Visible = False;
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		Information = ModuleAccountingAuditInternal.AccountingSystemChecksInformation();
		If Information.WarnSecondCheckRequired Then
			If ValueIsFilled(Information.LastCheckDate) Then
				ToolTip = NStr("en = 'Last system check was on %1.';");
				ToolTip = StringFunctionsClientServer.SubstituteParametersToString(ToolTip, 
					Format(Information.LastCheckDate, "DLF=D"));
			Else
				ToolTip = "";
			EndIf;
			Items.InformationLabel.ExtendedTooltip.Title = ToolTip;
			Visible = True;
		EndIf;
	EndIf;
	Items.InformationPanel.Visible = Visible;
EndProcedure

&AtClient
Procedure BeforeOpenPage(Val NewPage = Undefined)
	
	ParameterName = "StandardSubsystems.MessagesForEventLog";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New ValueList);
	EndIf;
	
	Pages = Items.WizardPages.ChildItems;
	If NewPage = Undefined Then
		NewPage = Items.WizardPages.CurrentPage;
	EndIf;
	
	BackButtonAvailable = True;
	NextButtonAvailable = True;
	CloseButtonAvailable = True;
	NextButtonFunction = True; // 
	CloseButtonFunction = True; // 
	
	Items.NextButton.Representation = ButtonRepresentation.Text;
	
	If NewPage = Pages.NoUpdatesFound Then
		
		NextButtonFunction = False;
		CloseButtonFunction = False;
		NextButtonAvailable = False;
		CurrentConfigurationDetails = StandardSubsystemsClient.ClientRunParameters().ConfigurationSynonym;
		CurrentConfigurationVersion = StandardSubsystemsClient.ClientRunParameters().ConfigurationVersion;
		
		If Not StandardSubsystemsClient.ClientRunParameters().IsMasterNode1 Then
			BackButtonAvailable = False;
		EndIf;
		
	ElsIf NewPage = Pages.SelectUpdateModeFile Then
		
		NextButtonFunction = (Object.UpdateMode = 0);// 
		
		UpdateConnectionsInformation(Pages.SelectUpdateModeFile);
		
		If Object.CreateDataBackup = 2 Then
			Object.RestoreInfobase = True;
		ElsIf Object.CreateDataBackup = 0 Then
			Object.RestoreInfobase = False;
		EndIf;
		
		Items.BackupFileLabel.Title = ConfigurationUpdateClient.BackupCreationTitle(Object);
		
		If Not StandardSubsystemsClient.ClientRunParameters().IsMasterNode1 Then
			BackButtonAvailable = False;
		EndIf;
	ElsIf NewPage = Pages.UpdateModeSelectionServer Then
		
		NextButtonFunction = (Object.UpdateMode = 0);// 
		Object.RestoreInfobase = False;
		
		RestartInformationPanelPages = Items.RestartInformationPages.ChildItems;
		Items.RestartInformationPages.CurrentPage = ?(Object.UpdateMode = 0,
			RestartInformationPanelPages.RestartNowPage,
			RestartInformationPanelPages.ScheduledRestartPage);
		
		UpdateConnectionsInformation(Pages.UpdateModeSelectionServer);
		
		Items.UpdateDateTimeField.Enabled = (Object.UpdateMode = 2);
		Items.Email.Enabled   = Object.EmailReport;
		
		If Not StandardSubsystemsClient.ClientRunParameters().IsMasterNode1 Then
			BackButtonAvailable = False;
		EndIf;
		
		If Object.UpdateMode = 2 Then 
			Items.NextButton.Representation = ButtonRepresentation.PictureAndText;
		EndIf;
		
	ElsIf NewPage = Pages.UpdateFile Then
		
		BackButtonAvailable = False;
		If UpdateFileRequired = 0 Then
			If ConfigurationChanged Or LoadExtensions Then
				Items.PagesUpdateFile.CurrentPage = Items.HasChanges;
			Else
				Items.PagesUpdateFile.CurrentPage = Items.NoChanges;
				NextButtonAvailable = False;
			EndIf;
		ElsIf UpdateFileRequired = 1 Then
			CurrentItem = Items.UpdateFileField;
			ThisIsATestClient = StrFind(CommonInternalClient.EnterpriseStartupParametersFromScript(), "TestClient") > 0;
			If FirstOpeningOfForm And IsBlankString(SelectedFiles) And Not ThisIsATestClient Then
				AttachIdleHandler("SelectUpdateFile", 0.1, True);
			EndIf;
		EndIf;
		Items.UpdateFromMainConfigurationPanel.Visible = UpdateFileRequired = 0;
		Items.UpdateFileField.Enabled                   = UpdateFileRequired = 1;
		Items.UpdateFileField.AutoMarkIncomplete     = UpdateFileRequired = 1;
		Items.UpdateFileRequiredRadioButtons.Enabled     = Not IsWebClient();
		Items.FindAndInstallUpdatesGroup.Visible        = Not IsWebClient();
		
	EndIf;
	
	ConfigurationUpdateClient.WriteEventsToEventLog();
	
	NextButton = Items.NextButton;
	CloseButton = Items.CloseButton;
	Items.BackButton.Enabled = BackButtonAvailable;
	NextButton.Enabled   = NextButtonAvailable;
	CloseButton.Enabled = CloseButtonAvailable;
	If NextButtonAvailable Then
		If Not NextButton.DefaultButton Then
			NextButton.DefaultButton = True;
		EndIf;
	ElsIf CloseButtonAvailable Then
		If Not CloseButton.DefaultButton Then
			CloseButton.DefaultButton = True;
		EndIf;
	EndIf;
	
	NextButton.Title = ?(NextButtonFunction, NStr("en = 'Next >';"), NStr("en = 'Finish';"));
	CloseButton.Title = ?(CloseButtonFunction, NStr("en = 'Cancel';"), NStr("en = 'Close';"));
	FirstOpeningOfForm = False;
	
EndProcedure

&AtClient
Procedure SelectUpdateFile()
	
	Items.UpdateFileField.ReadOnly = True;
	Items.NextButton.Enabled = False;
	Items.UpdateFromMainConfigurationPanel.Visible = True;
	Items.PagesUpdateFile.CurrentPage = Items.WaitForFileChoice;
	
	DialogProperties = PropertiesOfTheUpdateFileSelectionDialog();
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Title = DialogProperties.Title;
	ImportParameters.Dialog.Filter = DialogProperties.Filter;
	ImportParameters.Dialog.Directory = TheDirectoryOfTheUpdateFile(Items.UpdateFileField.EditText);
	
	FileSystemClient.ImportFiles(
		New NotifyDescription("AfterSelectingTheUpdateFiles", ThisObject),
		ImportParameters);
	
EndProcedure

&AtClient
Function PropertiesOfTheUpdateFileSelectionDialog()
	
	Properties = New Structure("Filter, Title");
	
#If WebClient Then
	
	Properties.Title = NStr("en = 'Select patches';");
	Properties.Filter = NStr("en = 'Patch files (*.cfe*;*.zip)|*.cfe*;*.zip';");
	
#Else
	
	If CommonClient.ClientConnectedOverWebServer() Then 
		
		Properties.Title = NStr("en = 'Select patches';");
		Properties.Filter = NStr("en = 'Patch files (*.cfe*;*.zip)|*.cfe*;*.zip';");
		
	Else
		
		Properties.Title = NStr("en = 'Select configuration updates';");
		
		DescriptionOfTheDialogFilter = New Array;
		
		DescriptionOfTheDialogFilter.Add(NStr("en = 'Configuration files (*.cf)|*.cf';"));
		DescriptionOfTheDialogFilter.Add(NStr("en = 'Update files(*.cfu)|*.cfu';"));
		
		DescriptionOfTheDialogFilter.Insert(0, NStr("en = 'All files (*.cf*;*.cfu;*.cfe;*.zip)|*.cf*;*.cfu;*.cfe;*.zip';"));
		DescriptionOfTheDialogFilter.Add(NStr("en = 'Patch files (*.cfe*;*.zip)|*.cfe*;*.zip';"));
		
		Properties.Filter = StrConcat(DescriptionOfTheDialogFilter, "|");
		
	EndIf;
	
#EndIf
	
	Return Properties;
	
EndFunction

&AtClient
Procedure AfterSelectingTheUpdateFiles(DescriptionOfTheSelectedFiles, AdditionalParameters) Export 
	
	If TypeOf(DescriptionOfTheSelectedFiles) = Type("Array") Then 
		ProcessUpdateFiles(DescriptionOfTheSelectedFiles);
	EndIf;

	Items.UpdateFileField.ReadOnly = False;
	Items.NextButton.Enabled = True;
	BeforeOpenPage();
	
EndProcedure

// Parameters:
//  DescriptionOfTheSelectedFiles - Array of Structure:
//    * Location - String
//    * Name - String 
//    * FileName - String
//
&AtClient
Procedure ProcessUpdateFiles(DescriptionOfTheSelectedFiles)
	
	InitializePatchFiles(DescriptionOfTheSelectedFiles, True);
	
	PatchesFilesNames = New Array;
	UpdateFileNames = New Array;
	
	For Each DescriptionOfTheSelectedFile In DescriptionOfTheSelectedFiles Do 
		
		If ThisIsTheFixFile(DescriptionOfTheSelectedFile.Name) Then 
			PatchesFilesNames.Add(DescriptionOfTheSelectedFile.Name);
		Else
			UpdateFileNames.Add(DescriptionOfTheSelectedFile.Name);
		EndIf;
		
	EndDo;
	
	FilesNames = CommonClient.CopyRecursive(PatchesFilesNames);
	
	If UpdateFileNames.Count() > 0 Then 
		FilesNames.Insert(0, UpdateFileNames[0]);
	EndIf;
	
	SelectedFiles = StrConcat(FilesNames, ",");
	
EndProcedure

// Parameters:
//  FilesDetails - String
//                 - Array of Structure:
//                     * Location - String
//                     * Name - String
//                     * FileName - String
//  Reinitialize - Boolean
//
&AtClient
Procedure InitializePatchFiles(FilesDetails, Reinitialize = False)
	
	If TypeOf(PatchesFiles) = Type("Array") And Not Reinitialize Then 
		Return;
	EndIf;
	
	PatchesFiles = New Array;
	If TypeOf(FilesDetails) = Type("Array") Then 
		For Each FileDetails In FilesDetails Do 
			If ThisIsTheFixFile(FileDetails.FileName) Then 
				PatchesFiles.Add(New TransferableFileDescription(FileDetails.Name, FileDetails.Location));
			EndIf;
		EndDo;
	ElsIf TypeOf(FilesDetails) = Type("String") Then 
		FilesNames = StrSplit(FilesDetails, ",");
		For Each FileName In FilesNames Do
			If ThisIsTheFixFile(FileName) Then
				PatchesFiles.Add(New TransferableFileDescription(FileName));
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function ThisIsTheFixFile(FileName)
	
	Return StrEndsWith(FileName, ".cfe") Or StrEndsWith(FileName, ".zip");
	
EndFunction

&AtClient
Function IsWebClient()
	
#If WebClient Then
	Return True;
#Else
	Return CommonClient.ClientConnectedOverWebServer();
#EndIf
	
EndFunction

&AtClient
Function PatchesFilesNames()
	
	PatchesFilesNames = New Array;
	
	For Each PatchFile In PatchesFiles Do 
		PatchesFilesNames.Add(PatchFile.Name);
	EndDo;
	
	Return PatchesFilesNames;
	
EndFunction

&AtClient
Procedure UpdateConnectionsInformation(CurrentPage = Undefined)
	
	If CurrentPage = Undefined Then
		CurrentPage = Items.WizardPages.CurrentPage;
	EndIf;
	
	ParameterName = "StandardSubsystems.MessagesForEventLog";
	If CurrentPage = Items.SelectUpdateModeFile Then
		
		ConnectionsInfo = IBConnectionsServerCall.ConnectionsInformation(False, ApplicationParameters[ParameterName]);
		Items.ConnectionsGroup.Visible = ConnectionsInfo.HasActiveConnections;
		
		If ConnectionsInfo.HasActiveConnections Then
			AllPages = Items.ActiveUsersPanel.ChildItems;
			If ConnectionsInfo.HasCOMConnections Then
				Items.ActiveUsersPanel.CurrentPage = AllPages.ActiveConnections;
			ElsIf ConnectionsInfo.HasDesignerConnection Then
				Items.ActiveUsersPanel.CurrentPage = AllPages.DesignerConnection;
			Else
				Items.ActiveUsersPanel.CurrentPage = AllPages.ActiveUsers;
			EndIf;
		EndIf;
		
	ElsIf CurrentPage = Items.UpdateModeSelectionServer Then
		
		PageSetup = SelectUpdateModePageParametersServer(ApplicationParameters[ParameterName]);
		Items.DeferredHandlersLabel.Visible = PageSetup.DeferredHandlersAvailable;
		
		ConnectionsInfo = PageSetup.ConnectionsInformation;
		ConnectionsPresent = ConnectionsInfo.HasActiveConnections And Object.UpdateMode = 0;
		Items.ConnectionsGroup1.Visible = ConnectionsPresent;
		If ConnectionsPresent Then
			AllPages = Items.ActiveUsersPanel1.ChildItems;
			Items.ActiveUsersPanel1.CurrentPage = ? (ConnectionsInfo.HasCOMConnections, 
				AllPages.ActiveConnections1, AllPages.ActiveUsers1);
		EndIf;
		
	ElsIf CurrentPage = Items.AfterInstallUpdates Then
		
		ConnectionsInfo = IBConnectionsServerCall.ConnectionsInformation(False, ApplicationParameters[ParameterName]);
		Items.ActiveUsersDecoration.Visible = ConnectionsInfo.HasActiveConnections;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InstallUpdate()
	
	ParametersOfUpdate = New Structure;
	ParametersOfUpdate.Insert("UpdateMode");
	ParametersOfUpdate.Insert("UpdateDateTime");
	ParametersOfUpdate.Insert("EmailReport");
	ParametersOfUpdate.Insert("Email");
	ParametersOfUpdate.Insert("SchedulerTaskCode");
	ParametersOfUpdate.Insert("CreateDataBackup");
	ParametersOfUpdate.Insert("IBBackupDirectoryName");
	ParametersOfUpdate.Insert("RestoreInfobase");
	ParametersOfUpdate.Insert("UpdateFileName");
	
	FillPropertyValues(ParametersOfUpdate, Object);
	ParametersOfUpdate.Insert("ShouldExitApp", Parameters.ShouldExitApp);
	ParametersOfUpdate.Insert("UpdateFileRequired", Boolean(UpdateFileRequired));
	ParametersOfUpdate.Insert("PatchesFiles", PatchesFilesNames());
	
	ParametersOfUpdate.Insert("ConfigurationChanged", ConfigurationChanged);
	ParametersOfUpdate.Insert("LoadExtensions", LoadExtensions);
	
	ConfigurationUpdateClient.InstallUpdate(ThisObject, ParametersOfUpdate, AdministrationParameters);
	
EndProcedure

&AtClient
Procedure HandleNextButtonClick()
	
	ClearMessages();
	CurrentPage = Items.WizardPages.CurrentPage;
	Pages = Items.WizardPages.ChildItems;
	
	If CurrentPage = Pages.UpdateFile Then
		NavigateFromUpdateFilePage();
	ElsIf CurrentPage = Pages.SelectUpdateModeFile
		Or CurrentPage = Pages.UpdateModeSelectionServer Then
		InstallUpdate();
	ElsIf CurrentPage = Pages.AfterInstallUpdates And RestartApplication Then
		Exit(True, True);
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure HandleBackButtonClick()
	
	Pages = Items.WizardPages.ChildItems;
	CurrentPage = Items.WizardPages.CurrentPage;
	NewCurrentPage = CurrentPage;
	
	If CurrentPage = Pages.SelectUpdateModeFile
		Or CurrentPage = Pages.UpdateModeSelectionServer Then
		NewCurrentPage = Pages.UpdateFile;
	EndIf;
	
	BeforeOpenPage(NewCurrentPage);
	Items.WizardPages.CurrentPage = NewCurrentPage;
	
EndProcedure

&AtClient
Procedure NavigateFromUpdateFilePage()
	
	InitializePatchFiles(SelectedFiles);
	
	Object.UpdateFileName = "";
	If Not IsBlankString(SourceConfigurations) Then
		DeleteFromTempStorage(SourceConfigurations);
		SourceConfigurations = "";
	EndIf;	
	
	SelectedFilesNames = StrSplit(SelectedFiles, ",");
	For Each FileName In SelectedFilesNames Do
		If Not ThisIsTheFixFile(FileName) Then
			If Not IsBlankString(Object.UpdateFileName) Then
				Raise NStr("en = 'Please select a single update file.';");
			EndIf;
			Object.UpdateFileName = FileName;
		EndIf;
	EndDo;
	
	If UpdateFileRequired = 1 Then
		If Not ValueIsFilled(SelectedFiles) Then
			CommonClient.MessageToUser(NStr("en = 'Please select an update file.';"),,"Object.UpdateFileName");
			CurrentItem = Items.UpdateFileField;
			Return;
		EndIf;
		If Not IsBlankString(Object.UpdateFileName) Then
			File = New File(Object.UpdateFileName);
			If Not File.Exists() Or Not File.IsFile() Then
				CommonClient.MessageToUser(NStr("en = 'The update file is not found.';"),,"Object.UpdateFileName");
				CurrentItem = Items.UpdateFileField;
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	Handler = New NotifyDescription("CheckUpdateFilesApplicability", ThisObject);
	FormParameters = New Structure("Key", "BeforeSelectUpdateFile");
	OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Handler);
	
EndProcedure

&AtClient
Procedure CheckUpdateFilesApplicability(Result, AdditionalParameters) Export
	
	If Result <> "Continue" Then
		Return;
	EndIf;

	If IsBlankString(Object.UpdateFileName) Then
		If UpdateFileRequired = 1 Then
			ProceedToPatchesInstallation();
		Else
			OnUpdateLegalityCheck();			
		EndIf;
		Return;
	EndIf;
	
	// Check applicability of update files only in a file infobase.
	If Not CommonClient.FileInfobase() Then
		OnUpdateLegalityCheck();
		Return;
	EndIf;	
		
	If Not IsConfigurationUpdateDeliveryFile(Object.UpdateFileName) Then
		OnUpdateLegalityCheck();
		Return;
	EndIf;
	
	Status(NStr("en = 'Checking applicability…';"), 75);
	UpdateInfo = CheckUpdateFileApplicability(Object.UpdateFileName, UUID);
	If Not IsBlankString(UpdateInfo.ErrorText) Then
		OnUpdateLegalityCheck();
		Return; // Cannot complete the check; the file is probably corrupted.
	EndIf;	
	
	If UpdateInfo.Compatible Then
		DeleteFromTempStorage(UpdateInfo.SourceConfigurations);
		OnUpdateLegalityCheck();
		Return;
	EndIf;
	
	SourceConfigurations = UpdateInfo.SourceConfigurations;
	OpenForm("DataProcessor.InstallUpdates.Form.IncompatibleUpdate",
	 	New Structure("SourceConfigurations", SourceConfigurations));
	
EndProcedure

&AtClient
Function IsConfigurationUpdateDeliveryFile(Val FileName)
	Return StrCompare(CommonClientServer.GetFileNameExtension(FileName), "cfu") = 0;
EndFunction	

&AtServerNoContext
Function CheckUpdateFileApplicability(Val FileName, Val FormIdentifier)
	Result = ConfigurationUpdate.UpdateInfo(FileName);
	Result.SourceConfigurations = PutToTempStorage(Result.SourceConfigurations, FormIdentifier);
	Return Result;	
EndFunction

&AtClient
Procedure ProceedToPatchesInstallation()
	
	NotifyDescription = New NotifyDescription("ContinueInstallUpdates", ThisObject);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Interactively = False;
	
	FilesToUpload = CommonClient.CopyRecursive(PatchesFiles);
	
	FileSystemClient.ImportFiles(NotifyDescription, ImportParameters, FilesToUpload);
	
EndProcedure

&AtClient
Procedure ContinueInstallUpdates(PlacedFiles, AdditionalParameters) Export
	
	InstallPatchesAtServer(PlacedFiles);
	
	Items.WizardPages.CurrentPage = Items.AfterInstallUpdates;
	Items.NextButton.Title = NStr("en = 'Finish';");
	
EndProcedure

&AtServer
Procedure InstallPatchesAtServer(PlacedFiles)
	
	ConnectionsInfo = IBConnectionsServerCall.ConnectionsInformation(False);
	Items.ActiveUsersDecoration.Visible = ConnectionsInfo.HasActiveConnections;
	
	Corrections = New Structure;
	Corrections.Insert("Set", PlacedFiles);
	Result = ConfigurationUpdate.InstallAndDeletePatches(Corrections);
	HasErrors = (Result.Unspecified <> 0);
	PatchesInstalled1 = Result.Installed.Count();
	Items.PatchInstallationError.Visible = HasErrors;
	Items.WarningsPanel.Visible = False;
	Items.InformationPanel.Visible     = False;
	
	If HasErrors Then
		If PatchesInstalled1 > 0 Then
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Patches installed: %1 out of %2. The changes will be applied after you restart the application.';"),
				PatchesInstalled1,
				PlacedFiles.Count());
			Items.PatchesInstalledDecoration.Title = LabelText;
			Items.DecorationPatchesInstalled.Visible = False;
		Else
			Items.PatchesInstalled.Visible = False;
			Items.PatchesInstalledDecoration.Visible = False;
			Return;
		EndIf;
	Else
		If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
			OperationName = "StandardSubsystems.ConfigurationUpdate.Patches1.ManualPatchInstallation";
			ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
			ModuleMonitoringCenter.WriteBusinessStatisticsOperation(OperationName, 1);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProceedToUpdateModeSelection(IsMoveNext = False)
	
	If AdministrationParameters = Undefined Then
		
		NotifyDescription = New NotifyDescription("AfterGetAdministrationParameters", ThisObject, IsMoveNext);
		FormCaption = NStr("en = 'Install update';");
		If IsFileInfobase Then
			NoteLabel = NStr("en = 'To install the update, enter
				|the infobase administration parameters';");
			PromptForClusterAdministrationParameters = False;
		Else
			NoteLabel = NStr("en = 'To install the update, enter
				|the server cluster and infobase administration parameters';");
			PromptForClusterAdministrationParameters = True;
		EndIf;
		
		IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, True, PromptForClusterAdministrationParameters,
			AdministrationParameters, FormCaption, NoteLabel);
		
	Else
		
		AfterGetAdministrationParameters(AdministrationParameters, IsMoveNext);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnUpdateLegalityCheck()
	
	If UpdateFileRequired = 1 Then
		If CommonClient.SubsystemExists("StandardSubsystems.SoftwareLicenseCheck") Then
			Notification = New NotifyDescription("OnUpdateLegalityCheckCompletion", ThisObject);
			ModuleSoftwareLicenseCheckClient = CommonClient.CommonModule("SoftwareLicenseCheckClient");
			ModuleSoftwareLicenseCheckClient.ShowLegitimateSoftwareCheck(Notification);
			Return;
		EndIf;
	EndIf;
	OnUpdateLegalityCheckCompletion(True, Undefined);
	
EndProcedure

&AtClient
Procedure OnUpdateLegalityCheckCompletion(UpdateAcquiredLegally, AdditionalParameters) Export
	
	If UpdateAcquiredLegally = True Then
		ProceedToUpdateModeSelection(True);
	Else
		HandleBackButtonClick();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGetAdministrationParameters(Result, IsMoveNext) Export
	
	If IsMoveNext Then
		Items.WizardPages.CurrentPage.Enabled = True;
	EndIf;
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		Pages = Items.WizardPages.ChildItems;
		NewCurrentPage = ?(IsFileInfobase, Pages.SelectUpdateModeFile, Pages.UpdateModeSelectionServer);
		SetAdministratorPassword(AdministrationParameters);
		
		BeforeOpenPage(NewCurrentPage);
		Items.WizardPages.CurrentPage = NewCurrentPage;
		
	Else
		
		WarningText = NStr("en = 'To install the update, enter the administration parameters.';");
		ShowMessageBox(, WarningText);
		
		MessageText = NStr("en = 'Cannot install the application update as the specified administrator name or password is invalid
			|(or other client/server infobase administration parameters are invalid).';");
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Error", MessageText);
		
	EndIf;
	
	ConfigurationUpdateClient.WriteEventsToEventLog();
	
EndProcedure

&AtClient
Procedure ShowActiveUsers()
	
	FormParameters = New Structure;
	FormParameters.Insert("NotifyOnClose", True);
	StandardSubsystemsClient.OpenActiveUserList(FormParameters, ThisObject);
	
EndProcedure

&AtServer
Function SelectUpdateModePageParametersServer(MessagesForEventLog)
	
	PageSetup = New Structure;
	PageSetup.Insert("DeferredHandlersAvailable", (InfobaseUpdateInternal.UncompletedHandlersStatus() = "UncompletedStatus"));
	PageSetup.Insert("ConnectionsInformation", IBConnections.ConnectionsInformation(False, MessagesForEventLog));
	Return PageSetup;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// 

// Returns a file directory (a partial path without a file name).
//
// Parameters:
//  PathToFile  - String - File path.
//
// Returns:
//   String   - 
//
&AtClient
Function TheDirectoryOfTheUpdateFile(Val PathToFile)
	
	CharPosition = StrFind(PathToFile, GetPathSeparator(), SearchDirection.FromEnd);
	
	If CharPosition > 1 Then
		Return Mid(PathToFile, 1, CharPosition - 1); 
	Else
		Return "";
	EndIf;
	
EndFunction

&AtServer
Procedure RestoreConfigurationUpdateSettings()
	
	Settings = ConfigurationUpdate.ConfigurationUpdateSettings();
	FillPropertyValues(Object, Settings);
	PatchesFilesAsString = StrConcat(Settings.PatchesFiles, ",");
	If ValueIsFilled(PatchesFilesAsString) Then
		SelectedFiles = Settings.UpdateFileName + "," + PatchesFilesAsString;
	Else
		SelectedFiles = Settings.UpdateFileName;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAdministratorPassword(AdministrationParameters)
	
	IBAdministrator = InfoBaseUsers.FindByName(AdministrationParameters.InfobaseAdministratorName);
	
	If Not IBAdministrator.StandardAuthentication Then
		
		IBAdministrator.StandardAuthentication = True;
		IBAdministrator.Password = AdministrationParameters.InfobaseAdministratorPassword;
		IBAdministrator.Write();
		
	EndIf;
	
EndProcedure

&AtServer
Function LoadExtensionsThatChangeDataStructure()

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ModuleDataExchangeInternal = Common.CommonModule("DataExchangeInternal");
		Return ModuleDataExchangeInternal.LoadExtensionsThatChangeDataStructure();
		
	Else
			
		Return False;
		
	EndIf;	

EndFunction

#EndRegion