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
Var CurrentContext;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	URL = "e1cib/app/CommonForm.Extensions";
	
	If Not AccessRight("Administration", Metadata) Then
		Items.ExtensionsListSafeModeFlag.ReadOnly = True;
	EndIf;
	
	If Not AccessRight("ConfigurationExtensionsAdministration", Metadata) Then
		Items.ExtensionsListUpdate.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
		Items.ExtensionsList.ReadOnly = True;
		Items.ExtensionsListAdd.Visible = False;
		Items.ExtensionsListDelete.Visible = False;
		Items.ExtensionsListUpdateFromFile.Visible = False;
		Items.ExtensionsListSaveAs.Visible = False;
		Items.ExtensionsListContextMenuAdd.Visible = False;
		Items.ExtensionsListContextMenuDelete.Visible = False;
		Items.ExtensionsListContextMenuUpdateFromFile.Visible = False;
		Items.ExtensionsListContextMenuSaveAs.Visible = False;
	EndIf;
	
	Items.ExtensionsListCommon.Visible = Common.DataSeparationEnabled() And AccessRight("Administration", Metadata);
	Items.ExtensionsListReceivedFromMasterDIBNode.Visible = Common.IsSubordinateDIBNode();
	Items.ExtensionsListPassToSubordinateDIBNodes.Visible = Common.IsDistributedInfobase();
	
	Items.FormInstalledPatches1.Visible = 
		Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate");
	
	UpdateList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCommandBarButtonAvailability()
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "LoggedOffFromDataArea" 
		Or EventName = "LoggedOnToDataArea" Then
		
		AttachIdleHandler("UpdateListIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WarningDetails1URLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	Exit(False, True);
EndProcedure

#EndRegion

#Region ExtensionsListFormTableItemEventHandlers

&AtClient
Procedure ExtensionsListOnActivateRow(Item)
	
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure ExtensionsListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	LoadExtension(Undefined, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	DeleteExtensions(Item.SelectedRows);
	
EndProcedure

&AtClient
Procedure ExtensionsListSafeModeFlagOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowID", CurrentExtension.GetID());
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("ExtensionsListSafeModeFlagOnChangeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowID", CurrentExtension.GetID());
	
	If Not CurrentExtension.Attach
	   And IsExtensionWithData(CurrentExtension.ExtensionID) Then
		
		Notification = New NotifyDescription("DetachExtensionAfterConfirmation", ThisObject, Context);
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", "BeforeDisableExtensionWithData");
		
		OpenForm("CommonForm.SecurityWarning", FormParameters,,,,, Notification)
	Else
		ExtensionsListAttachOnChangeFollowUp(Context);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtensionsListPassToSubordinateDIBNodesOnChange(Item)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	ExtensionsListSendToSubordinateDIBNodesOnChangeAtServer(CurrentExtension.GetID());
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateList();
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	SelectedRows = Items.ExtensionsList.SelectedRows;
	NotifyDescription = New NotifyDescription("SaveAsCompletion", ThisObject, SelectedRows);
	
	If SelectedRows.Count() = 0 Then
		Return;
	ElsIf SelectedRows.Count() = 1 Then
		FilesToSave = SaveAtServer(SelectedRows);
	Else
		Title = NStr("en = 'Select directory';");
		FileSystemClient.SelectDirectory(NotifyDescription, Title);
		Return;
	EndIf;
	
	If FilesToSave.Count() = 0 Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Select file';");
	SavingParameters.Dialog.Filter    = NStr("en = 'Configuration extension files (*.cfe)|*.cfe';") + "|"
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	CurrentExtension = Items.ExtensionsList.CurrentData;
	
	If CurrentExtension = Undefined Then
		Return;
	EndIf;
	
	LoadExtension(Items.ExtensionsList.SelectedRows);
	
EndProcedure

&AtClient
Procedure ShowEventsBackgroundUpdateSettingsExtensionsJob(Command)
	
	EventFilter = New Structure;
	EventFilter.Insert("EventLogEvent", ParameterFillingEventName());
	
	EventLogClient.OpenEventLog(EventFilter, ThisObject);
	
EndProcedure

&AtClient
Procedure RunUpdateSettingsExtensionsWorkInBackground(Command)
	
	WarningText = "";
	RunUpdateSettingsExtensionsWorkInBackgroundOnServer(WarningText);
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure DeleteObsoleteParametersWorkExtensions(Command)
	
	DeleteDeprecatedSettingsExtensionsWorkOnServer();
	ShowMessageBox(, NStr("en = 'Obsolete versions of extension parameters are deleted.';"));
	
EndProcedure

&AtClient
Procedure InstalledPatches(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.ShowInstalledPatches();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateListIdleHandler()
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure UpdateList(AfterAdd = False)
	
	If AfterAdd Then
		CurrentRowIndex = ExtensionsList.Count();
	Else
		CurrentRowIndex = 0;
		CurrentRowID = Items.ExtensionsList.CurrentRow;
		If CurrentRowID <> Undefined Then
			String = ExtensionsList.FindByID(CurrentRowID);
			If String <> Undefined Then
				CurrentRowIndex = ExtensionsList.IndexOf(String);
			EndIf;
		EndIf;
	EndIf;
	
	ExtensionsList.Clear();
	
	SetPrivilegedMode(True);
	Extensions = ConfigurationExtensions.Get();
	AttachedExtensions = ExtensionsIDs(ConfigurationExtensionsSource.SessionApplied);
	DetachedExtensions  = ExtensionsIDs(ConfigurationExtensionsSource.SessionDisabled);
	SetPrivilegedMode(False);
	
	ModuleConfigurationUpdate = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then 
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
	EndIf;
	
	DontOutputCommonExtensions = Common.DataSeparationEnabled() And Not AccessRight("Administration", Metadata);
	SerialNumber = 1;
	For Each Extension In Extensions Do
		
		If DontOutputCommonExtensions 
			And (Extension.Scope = ConfigurationExtensionScope.InfoBase) Then
			Continue;
		EndIf;
			
		If ModuleConfigurationUpdate <> Undefined And ModuleConfigurationUpdate.IsPatch(Extension) Then 
			Continue;
		EndIf;
			
		ExtensionItem = ExtensionsList.Add();
		ExtensionItem.ExtensionID = Extension.UUID;
		ExtensionItem.Name = Extension.Name;
		ExtensionItem.Version = Extension.Version;
		ExtensionItem.Checksum = Base64String(Extension.HashSum);
		ExtensionItem.Synonym = Extension.Synonym;
		ExtensionItem.Purpose = Extension.Purpose;
		ExtensionItem.SafeMode = Extension.SafeMode;
		ExtensionItem.Attach = Extension.Active;
		ExtensionItem.ReceivedFromMasterDIBNode = Extension.MasterNode <> Undefined;
		ExtensionItem.PassToSubordinateDIBNodes = Extension.UsedInDistributedInfoBase;
		ExtensionItem.SerialNumber = SerialNumber;
		
		ExtensionItem.Common = (Extension.Scope = ConfigurationExtensionScope.InfoBase);
		
		ExtensionItem.AssignmentPriority =
			?(Extension.Purpose = Metadata.ObjectProperties.ConfigurationExtensionPurpose.Patch, 1,
			?(Extension.Purpose = Metadata.ObjectProperties.ConfigurationExtensionPurpose.Customization, 2, 3));
		
		ExtensionKey = Extension.Name + Extension.HashSum + Extension.Scope;	
		If AttachedExtensions[ExtensionKey] <> Undefined Then
			ExtensionItem.Attached = 0;
			ExtensionItem.ActivationState = NStr("en = 'Attached';");
		ElsIf DetachedExtensions[ExtensionKey] <> Undefined Then
			ExtensionItem.Attached = 2;
			ExtensionItem.ActivationState = NStr("en = 'Detached';");
		Else
			ExtensionItem.Attached = 1;
			ExtensionItem.ActivationState = NStr("en = 'Restart required';");
		EndIf;	
			
		If IsBlankString(ExtensionItem.Synonym) Then
			ExtensionItem.Synonym = ExtensionItem.Name;
		EndIf;
		
		If TypeOf(Extension.SafeMode) = Type("Boolean") Then
			ExtensionItem.SafeModeFlag = Extension.SafeMode;
		Else
			ExtensionItem.SafeModeFlag = True;
		EndIf;
		SerialNumber = SerialNumber + 1;
	EndDo;
	ExtensionsList.Sort("ReceivedFromMasterDIBNode DESC, AssignmentPriority, Common DESC, SerialNumber");
	
	If CurrentRowIndex >= ExtensionsList.Count() Then
		CurrentRowIndex = ExtensionsList.Count() - 1;
	EndIf;
	If CurrentRowIndex >= 0 Then
		Items.ExtensionsList.CurrentRow = ExtensionsList.Get(
			CurrentRowIndex).GetID();
	EndIf;
	
	SetPrivilegedMode(True);
	InstalledExtensions = Catalogs.ExtensionsVersions.InstalledExtensions();
	ExtensionsStateChanged = 
		(SessionParameters.InstalledExtensions.MainState <> InstalledExtensions.MainState);
	Items.WarningGroup.Visible = ExtensionsStateChanged;
	SetPrivilegedMode(False);
	
	// Updating the form attribute for conditional formatting.
	IsSharedUserInArea = IsSharedUserInArea();
	
	Items.WarningDetails.Visible = Not IsSharedUserInArea;
	Items.WarningDetails2.Visible = IsSharedUserInArea;
	
EndProcedure

&AtServer
Function ExtensionsIDs(ExtensionSource)
	
	Extensions = ConfigurationExtensions.Get(, ExtensionSource);
	IDs = New Map;
	
	For Each Extension In Extensions Do
		IDs.Insert(Extension.Name + Extension.HashSum + Extension.Scope, True);
	EndDo;
	
	Return IDs;
	
EndFunction

&AtClient
Procedure SaveAsCompletion(PathToDirectory, SelectedRows) Export
	
	FilesToSave = SaveAtServer(SelectedRows, PathToDirectory);
	
	If FilesToSave.Count() = 0 Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Interactively     = False;
	
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);
	
EndProcedure

&AtServer
Function SaveAtServer(RowsIDs, PathToDirectory = "")
	
	FilesToSave = New Array;
	For Each RowID In RowsIDs Do
		ListLine = ExtensionsList.FindByID(RowID);
		ExtensionID = ListLine.ExtensionID;
		Extension = FindExtension(ExtensionID);
	
		If Extension <> Undefined Then
			If ValueIsFilled(PathToDirectory) Then
				Prefix = PathToDirectory + GetPathSeparator();
			Else
				Prefix = "";
			EndIf;
			Name = Prefix + Extension.Name + "_" + Extension.Version + ".cfe";
			Location = PutToTempStorage(Extension.GetData(), UUID);
			TransferableFileDescription = New TransferableFileDescription(Name, Location);
			FilesToSave.Add(TransferableFileDescription);
		EndIf;
	EndDo;
	
	Return FilesToSave;
	
EndFunction

&AtServerNoContext
Function FindExtension(ExtensionID)
	
	Return Catalogs.ExtensionsVersions.FindExtension(ExtensionID);
	
EndFunction

&AtServer
Procedure RunUpdateSettingsExtensionsWorkInBackgroundOnServer(WarningText)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ExtensionVersionParameters.EnableFillingExtensionsWorkParameters();
	
	WarningText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '1. Scheduled job
		           |""%1"" is enabled and started.
		           |
		           |2. See the result in the event log in the events
		           |""%2"",
		           |for example, by clicking
		           |""%3"" in the More menu.';"),
		InformationRegisters.ExtensionVersionParameters.TaskNameFillingParameters(),
		InformationRegisters.ExtensionVersionParameters.ParameterFillingEventName(),
		Commands.Find("RunUpdateSettingsExtensionsWorkInBackground").Title);
		
EndProcedure

&AtServer
Procedure DeleteDeprecatedSettingsExtensionsWorkOnServer()
	
	SetPrivilegedMode(True);
	Catalogs.ExtensionsVersions.DeleteObsoleteParametersVersions();
	
EndProcedure

&AtClient
Procedure DeleteExtensions(SelectedRows)
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	ExtensionsIDs = New Array;
	RowsToSkip = New Array;
	
	For Each RowID In SelectedRows Do
		ExtensionRow = ExtensionsList.FindByID(RowID);
		
		If ExtensionRow.Common
		   And IsSharedUserInArea
		 Or ExtensionRow.ReceivedFromMasterDIBNode Then
			
			RowsToSkip.Add(RowID);
			Continue;
		EndIf;
		ExtensionsIDs.Add(ExtensionRow.ExtensionID);
	EndDo;
	
	For Each RowID In RowsToSkip Do
		SelectedRows.Delete(SelectedRows.Find(RowID));
	EndDo;
	
	If ExtensionsIDs.Count() = 0 Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ExtensionsIDs", ExtensionsIDs);
	
	Notification = New NotifyDescription("DeleteExtensionAfterConfirmation", ThisObject, Context);
	
	FormParameters = New Structure;
	FormParameters.Insert("MultipleChoice", ExtensionsIDs.Count() > 1);
	
	If HasExtensionWithData(ExtensionsIDs) Then
		FormParameters.Insert("Key", "BeforeDeleteExtensionWithData");
	Else
		FormParameters.Insert("Key", "BeforeDeleteExtensionWithoutData");
	EndIf;
	
	OpenForm("CommonForm.SecurityWarning", FormParameters,,,,, Notification)
	
EndProcedure

&AtClient
Procedure DeleteExtensionAfterConfirmation(Result, Context) Export
	
	If Result <> "Continue" Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("DeleteExtensionFollowUp", ThisObject, Context);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = RequestsToRevokeExternalModuleUsagePermissions(Context.ExtensionsIDs);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, Notification);
	Else
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionFollowUp(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
		ShowTimeConsumingOperation();
		CurrentContext = Context;
		AttachIdleHandler("DeleteExtensionCompletion", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionCompletion()
	
	Context = CurrentContext;
	
	Try
		DeleteExtensionsAtServer(Context.ExtensionsIDs);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtServer
Procedure DeleteExtensionsAtServer(ExtensionsIDs)
	
	ErrorText = "";
	Catalogs.ExtensionsVersions.DeleteExtensions(ExtensionsIDs, ErrorText);
	
	UpdateList();
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

&AtClient
Procedure DetachExtensionAfterConfirmation(Result, Context) Export
	
	If Result <> "Continue" Then
		
		ListLine = ExtensionsList.FindByID(Context.RowID);
		If ListLine = Undefined Then
			Return;
		EndIf;
		
		ListLine.Attach = Not ListLine.Attach;
		Return;
	EndIf;
	
	ExtensionsListAttachOnChangeFollowUp(Context);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChangeFollowUp(Context)
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("ExtensionsListAttachOnChangeCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListAttachOnChangeCompletion()
	
	Context = CurrentContext;
	
	Try
		ExtensionsListAttachOnChangeAtServer(Context.RowID);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtClient
Procedure ExtensionsListSafeModeFlagOnChangeCompletion()
	
	Context = CurrentContext;
	
	Try
		ExtensionListSafeModeFlagOnChangeAtServer(Context.RowID);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
EndProcedure

&AtServer
Function RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs)
	
	Return Catalogs.ExtensionsVersions.RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs);
	
EndFunction

&AtClient
Procedure ShowTimeConsumingOperation()
	
	Items.RefreshPages.CurrentPage = Items.TimeConsumingOperationPage;
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure HideTimeConsumingOperation()
	
	Items.RefreshPages.CurrentPage = Items.ExtensionsListPage;
	SetCommandBarButtonAvailability();
	
EndProcedure

&AtClient
Procedure LoadExtension(Val ExtensionID, MultipleChoice = False)
	
	Context = New Structure;
	Context.Insert("ExtensionID", ExtensionID);
	Context.Insert("MultipleChoice", MultipleChoice);
	Context.Insert("SelectedRows", ExtensionID);
	Notification = New NotifyDescription("LoadExtensionAfterConfirmation", ThisObject, Context);
	
	FormParameters = New Structure("Key", "BeforeAddExtensions");
	
	OpenForm("CommonForm.SecurityWarning", FormParameters,,,,, Notification);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterConfirmation(Response, Context) Export
	If Response <> "Continue" Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("LoadExtensionAfterPutFiles", ThisObject, Context);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.Dialog.Filter = NStr("en = 'Configuration extensions';")+ " (*.cfe)|*.cfe";
	ImportParameters.Dialog.Title = NStr("en = 'Select configuration extension file';");
	ImportParameters.Dialog.CheckFileExist = True;
	
	ImportParameters.FormIdentifier = UUID;
	FileSystemClient.ImportFiles(Notification, ImportParameters);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterPutFiles(PlacedFiles, Context) Export
	
	If PlacedFiles = Undefined
	 Or PlacedFiles.Count() = 0 Then
		
		Return;
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		
		If SelectedFilesContainOnlyPatches(PlacedFiles, ModuleConfigurationUpdateClient) Then 
			
			BackupParameters = New Structure;
			BackupParameters.Insert("SelectedFiles", SelectedFilesByDetails(PlacedFiles));
			ModuleConfigurationUpdateClient.ShowUpdateSearchAndInstallation(BackupParameters);
			Return;
			
		ElsIf SelectedFilesContainPatches(PlacedFiles, ModuleConfigurationUpdateClient) Then 
			ShowMessageBox(,
				NStr("en = 'The selected files cannot contain both patches and extensions of other types.';"));
			Return;
		EndIf;
	EndIf;
	
	Context.Insert("PlacedFiles", PlacedFiles);
	
	ClosingNotification1 = New NotifyDescription(
		"LoadExtensionContinuation", ThisObject, Context);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		
		PermissionsRequests = New Array;
		Try
			AddPermissionRequest(PermissionsRequests, PlacedFiles, Context.ExtensionID);
		Except
			ErrorInfo = ErrorInfo();
			ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Return;
		EndTry;
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			PermissionsRequests, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

// Parameters:
//  PlacedFiles - Array of TransferredFileDescription
//  ModuleConfigurationUpdateClient - CommonModule
//
// Returns:
//  Boolean
//
&AtClient
Function SelectedFilesContainPatches(PlacedFiles, ModuleConfigurationUpdateClient)
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		If ModuleConfigurationUpdateClient.IsPatch(File.Name) Then 
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Parameters:
//  PlacedFiles - Array of TransferredFileDescription
//  ModuleConfigurationUpdateClient - CommonModule
//
// Returns:
//  Boolean
//
&AtClient
Function SelectedFilesContainOnlyPatches(PlacedFiles, ModuleConfigurationUpdateClient)
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		If Not ModuleConfigurationUpdateClient.IsPatch(File.Name) Then 
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Parameters:
//   PlacedFiles - Array of TransferredFileDescription
//
// Returns:
//  String
//
&AtClient
Function SelectedFilesByDetails(PlacedFiles)
	
	ListOfFiles = New Array;
	
	For Each FileThatWasPut In PlacedFiles Do 
		File = New File(FileThatWasPut.Name);
		ListOfFiles.Add(File.FullName);
	EndDo;
	
	Return StrConcat(ListOfFiles, ", ");
	
EndFunction

&AtClient
Procedure LoadExtensionContinuation(Result, Context) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("LoadExtensionCompletion", 0.1, True);
	
EndProcedure

&AtClient
Procedure LoadExtensionCompletion()
	
	Context = CurrentContext;
	
	UnattachedExtensions = "";
	ExtensionsChanged = False;
	If Context.Property("NameReplacementConfirmed") Then
		NameReplacementConfirmation = Undefined;
	Else
		NameReplacementConfirmation = New Structure("OldName, NewName", "", "");
	EndIf;
	Try
		ChangeExtensionsAtServer(Context.PlacedFiles,
			Context.SelectedRows, UnattachedExtensions, ExtensionsChanged, NameReplacementConfirmation);
	Except
		ErrorInfo = ErrorInfo();
		AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return;
	EndTry;
	AttachIdleHandler("HideTimeConsumingOperation", 0.1, True);
	
	If Not Context.Property("NameReplacementConfirmed")
	   And ValueIsFilled(NameReplacementConfirmation.OldName) Then
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Extension ""%1"" will be replaced with extension ""%2"".
			           |
			           |If extension ""%2"" is not an update for extension ""%1"",
			           |refuse to replace it and add extension ""%2"" as a new one.
			           |Note: if you cannot add extension ""%2"" because of extension ""%1"",
			           |delete extension ""%1"" before adding extension ""%2"".';"),
			NameReplacementConfirmation.OldName,
			NameReplacementConfirmation.NewName);
			
		CompletionHandler = New NotifyDescription(
			"LoadExtensionAfterQuestionNameReplacement", ThisObject, Context);
		
		Buttons = New ValueList;
		Buttons.Add("Replace",   NStr("en = 'Replace';"));
		Buttons.Add("NotReplace", NStr("en = 'Do not replace';"));
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.DefaultButton = "NotReplace";
		QuestionParameters.PromptDontAskAgain = False;
		
		StandardSubsystemsClient.ShowQuestionToUser(CompletionHandler,
			QueryText, Buttons, QuestionParameters);
		Return;
	EndIf;
	
	If Not ExtensionsChanged Then
		Return;
	EndIf;
	
	If Context.ExtensionID = Undefined Then
		If Context.PlacedFiles.Count() > 1 Then
			NotificationText1 = NStr("en = 'Configuration extensions added';");
		Else
			NotificationText1 = NStr("en = 'Configuration extension added';");
		EndIf;
	Else
		NotificationText1 = NStr("en = 'Configuration extension updated';");
	EndIf;
	
	ShowUserNotification(NotificationText1);
	
	If Not ValueIsFilled(UnattachedExtensions) Then
		Return;
	EndIf;
	
	If Context.PlacedFiles.Count() > 1 Then
		If StrFind(UnattachedExtensions, ",") > 0 Then
			WarningText = NStr("en = 'Cannot attach the following extensions:';");
		Else
			WarningText = NStr("en = 'Cannot attach the extension:';");
		EndIf;
		WarningText = WarningText + " " + UnattachedExtensions;
	Else
		WarningText = NStr("en = 'Cannot attach an extension.';");
	EndIf;
	
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure LoadExtensionAfterQuestionNameReplacement(Result, Context) Export
	
	If Result = Undefined
	 Or Result.Value <> "Replace" Then
		Return;
	EndIf;
	
	Context.Insert("NameReplacementConfirmed");
	
	ShowTimeConsumingOperation();
	CurrentContext = Context;
	AttachIdleHandler("LoadExtensionCompletion", 0.1, True);
	
EndProcedure

&AtServer
Procedure ChangeExtensionsAtServer(PlacedFiles, RowsIDs,
			UnattachedExtensions, ExtensionsChanged, NameReplacementConfirmation)
	
	Extension = Undefined;
	
	SelectedExtensions = New Structure;
	If RowsIDs <> Undefined Then
		For Each FileThatWasPut In PlacedFiles Do
			BinaryData = GetFromTempStorage(FileThatWasPut.Location);
			ExtensionDetails = New ConfigurationDescription(BinaryData);
			SelectedExtensions.Insert(ExtensionDetails.Name, BinaryData);
		EndDo;
	EndIf;
	
	ExtensionsToCheck = New Map;
	AddedExtensions = New Array;
	SourceExtensions    = New Map;
	
	ErrorText = "";
	AddedExtensionFileName = Undefined;
	Try
		If RowsIDs <> Undefined Then
			For Each RowID In RowsIDs Do
				TableRow = ExtensionsList.FindByID(RowID);
				ExtensionID = TableRow.ExtensionID;
				Extension = FindExtension(ExtensionID);
				If Extension = Undefined Then
					Continue;
				EndIf;
				
				PreviousExtensionName = Extension.Name;
				NewExtensionName = PreviousExtensionName;
				
				If Not SelectedExtensions.Property(PreviousExtensionName) Then
					If RowsIDs.Count() <> 1 Then
						Continue;
					ElsIf NameReplacementConfirmation <> Undefined Then
						NameReplacementConfirmation.OldName = PreviousExtensionName;
						NameReplacementConfirmation.NewName = ExtensionDetails.Name;
						Return;
					Else
						NewExtensionName = ExtensionDetails.Name;
					EndIf;
				EndIf;
				
				ExtensionData = Extension.GetData();
				SourceExtensions.Insert(PreviousExtensionName, ExtensionData);
				
				DisableSecurityWarnings(Extension);
				DisableMainRolesUsageForAllUsers(Extension);
				NewBinaryData = SelectedExtensions[NewExtensionName];
				Errors = Extension.CheckCanApply(NewBinaryData, False);
				For Each Error In Errors Do
					If Error.Severity <> ConfigurationExtensionApplicationIssueSeverity.Critical Then
						Continue;
					EndIf;
					ErrorText = ErrorText + Chars.LF + Error.Description;
				EndDo;
				
				If ValueIsFilled(ErrorText) Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot apply the extension. Reason:
						           |%1';"),
						ErrorText);
					Break;
				Else
					Extension.Write(NewBinaryData);
					Extension = FindExtension(ExtensionID);
					ExtensionsToCheck.Insert(Extension.Name, Extension.Synonym);
				EndIf;
			EndDo;
		Else
			For Each FileThatWasPut In PlacedFiles Do
				FileBinaryData = GetFromTempStorage(FileThatWasPut.Location);
				ExtensionDetails = New ConfigurationDescription(FileBinaryData);
				Filter = New Structure("Name", ExtensionDetails.Name);
				Extensions = ConfigurationExtensions.Get(Filter);
				If Extensions.Count() > 0 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot add extension ""%1""
						           | from file %2, 
						           |as an extension with this name already exists.';"),
						ExtensionDetails.Name,
						FileThatWasPut.Name);
					Break;
				EndIf;
			EndDo;
			If Not ValueIsFilled(ErrorText) Then
				For Each FileThatWasPut In PlacedFiles Do
					FileBinaryData = GetFromTempStorage(FileThatWasPut.Location);
					ExtensionDetails = New ConfigurationDescription(FileBinaryData);
					Extension = ConfigurationExtensions.Create();
					DisableSecurityWarnings(Extension);
					DisableMainRolesUsageForAllUsers(Extension);
					AddedExtensionFileName = FileThatWasPut.Name;
					Extension.Write(FileBinaryData);
					AddedExtensionFileName = Undefined;
					Extension = FindExtension(String(Extension.UUID));
					AddedExtensions.Insert(0, Extension);
					ExtensionsToCheck.Insert(Extension.Name, Extension.Synonym);
				EndDo;
			EndIf;
		EndIf;
	Except
		ErrorInfo = ErrorInfo();
		If RowsIDs <> Undefined Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update the extension. Reason:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
			
		ElsIf ValueIsFilled(AddedExtensionFileName) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add extension ""%1""
				           | from file %2. Reason:
				           |%3';"),
				ExtensionDetails.Name,
				AddedExtensionFileName,
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot add the extension. Reason:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
	EndTry;
	
	If Not ValueIsFilled(ErrorText) Then
		Try
			InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters(ExtensionsToCheck, UnattachedExtensions);
			ExtensionsChanged = True;
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the added extensions:
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		RecoveryErrorInformation = Undefined;
		RecoveryPerformed = False;
		Try
			If RowsIDs <> Undefined Then
				For Each ExtensionToCheck In ExtensionsToCheck Do
					ExtensionData = SourceExtensions[ExtensionToCheck.Key];
					Extension = FindExtension(ExtensionID);
					If Extension = Undefined Then
						Extension = ConfigurationExtensions.Create();
					EndIf;
					DisableSecurityWarnings(Extension);
					DisableMainRolesUsageForAllUsers(Extension);
					Extension.Write(ExtensionData);
				EndDo;
				RecoveryPerformed = True;
			Else
				For Each AddedExtension In AddedExtensions Do
					Filter = New Structure("Name", AddedExtension.Name);
					Extensions = ConfigurationExtensions.Get(Filter);
					For Each Extension In Extensions Do
						If Extension.HashSum = AddedExtension.HashSum Then
							Extension.Delete();
							RecoveryPerformed = True;
						EndIf;
					EndDo;
				EndDo;
			EndIf;
		Except
			RecoveryErrorInformation = ErrorInfo();
			If RowsIDs <> Undefined Then
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'An unexpected error occurred while restoring the changed extension:
						           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
			Else
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'An unexpected error occurred while trying to delete the added extensions:
						           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
			EndIf;
		EndTry;
		If RecoveryPerformed
		   And RecoveryErrorInformation = Undefined Then
			
			If RowsIDs <> Undefined Then
				If ExtensionsToCheck.Count() > 0 Then
					ErrorText = ErrorText + Chars.LF + Chars.LF
						+ NStr("en = 'The modified extension is restored.';");
				Else
					ErrorText = ErrorText + Chars.LF + Chars.LF
						+ NStr("en = 'The extension is not modified.';");
				EndIf;
			Else
				ErrorText = ErrorText + Chars.LF + Chars.LF
					+ NStr("en = 'The added extensions are deleted.';");
			EndIf;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
	UpdateList(ExtensionID = Undefined);
	
EndProcedure

&AtServer
Procedure ExtensionListSafeModeFlagOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	Extension = FindExtension(ListLine.ExtensionID);
	
	If Extension = Undefined
	 Or Extension.SafeMode = ListLine.SafeModeFlag Then
		
		UpdateList();
		Return;
	EndIf;
	
	Extension.SafeMode = ListLine.SafeModeFlag;
	DisableSecurityWarnings(Extension);
	DisableMainRolesUsageForAllUsers(Extension);
	Try
		Extension.Write();
	Except
		ListLine.SafeModeFlag = Not ListLine.SafeModeFlag;
		Raise;
	EndTry;
	
	Try
		InformationRegisters.ExtensionVersionParameters.UpdateExtensionParameters();
	Except
		ErrorInfo = ErrorInfo();
		If Extension.SafeMode Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the extensions (after enabling the safe mode):
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'An unexpected error occurred while preparing the extensions (after disabling the safe mode):
				           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
	EndTry;
	
	If ValueIsFilled(ErrorText) Then
		RecoveryErrorInformation = Undefined;
		Try
			Extension.SafeMode = Not Extension.SafeMode;
			Extension.Write();
		Except
			RecoveryErrorInformation = ErrorInfo();
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An unexpected error occurred when trying to cancel the change of the safe extension mode check box:
					           |%1';"), ErrorProcessing.BriefErrorDescription(RecoveryErrorInformation));
		EndTry;
		If RecoveryErrorInformation = Undefined Then
			ListLine.SafeModeFlag = Extension.SafeMode;
			ErrorText = ErrorText + Chars.LF + Chars.LF
				+ NStr("en = 'The change of the ""Safe mode"" extension parameter is canceled.';");
		EndIf;
	EndIf;
	
	UpdateList();
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function HasExtensionWithData(ExtensionsIDs)
	
	For Each ExtensionID In ExtensionsIDs Do
		If IsExtensionWithData(ExtensionID) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServerNoContext
Function IsExtensionWithData(ExtensionID)
	
	Extension = FindExtension(ExtensionID);
	
	If Extension = Undefined Then
		Return False;
	EndIf;
	
	Return Extension.ModifiesDataStructure();
	
EndFunction

&AtServer
Procedure ExtensionsListAttachOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	CurrentUsage = ListLine.Attach;
	Try
		Catalogs.ExtensionsVersions.ToggleExtensionUsage(ListLine.ExtensionID, CurrentUsage);
	Except
		ListLine.Attach = Not ListLine.Attach;
		UpdateList();
		
		Raise;
	EndTry;
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure ExtensionsListSendToSubordinateDIBNodesOnChangeAtServer(RowID)
	
	ListLine = ExtensionsList.FindByID(RowID);
	
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	Extension = FindExtension(ListLine.ExtensionID);
	
	If Extension <> Undefined Then
	
		If Extension.UsedInDistributedInfoBase <> ListLine.PassToSubordinateDIBNodes Then
			Extension.UsedInDistributedInfoBase = ListLine.PassToSubordinateDIBNodes;
			
			DisableSecurityWarnings(Extension);
			DisableMainRolesUsageForAllUsers(Extension);
			Try
				Extension.Write();
			Except
				ListLine.PassToSubordinateDIBNodes = Not ListLine.PassToSubordinateDIBNodes;
				Raise;
			EndTry;
		EndIf;
		
	EndIf;
	
	UpdateList();
	
EndProcedure

&AtServer
Procedure AddPermissionRequest(PermissionsRequests, PlacedFiles, ExtensionID = Undefined)
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	If Not ModuleSafeModeManager.UseSecurityProfiles() Then
		Return;
	EndIf;
	Permissions = New Array;
	
	For Each FileThatWasPut In PlacedFiles Do
		UpdatedExtensionData = Undefined;
		RecoveryRequired = False;
		Try
			If ExtensionID = Undefined Then
				TemporaryExtension = ConfigurationExtensions.Create();
			Else
				TemporaryExtension = FindExtension(ExtensionID);
				If TemporaryExtension = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'An extension with the %1 ID does not exist in the application. It might have been deleted in another session.';"),
						ExtensionID);
				EndIf;
				UpdatedExtensionData = TemporaryExtension.GetData();
			EndIf;
			DisableSecurityWarnings(TemporaryExtension);
			DisableMainRolesUsageForAllUsers(TemporaryExtension);
			ExtensionData = GetFromTempStorage(FileThatWasPut.Location);
			TemporaryExtension.Write(ExtensionData);
			RecoveryRequired = True;
			TemporaryExtension = FindExtension(String(TemporaryExtension.UUID));
			TemporaryExtensionProperties = New Structure;
			TemporaryExtensionProperties.Insert("Name",      TemporaryExtension.Name);
			TemporaryExtensionProperties.Insert("HashSum", TemporaryExtension.HashSum);
			If ExtensionID = Undefined Then
				TemporaryExtension.Delete();
			Else
				TemporaryExtension = FindExtension(ExtensionID);
				If TemporaryExtension = Undefined Then
					TemporaryExtension = ConfigurationExtensions.Create();
				EndIf;
				DisableSecurityWarnings(TemporaryExtension);
				DisableMainRolesUsageForAllUsers(TemporaryExtension);
				TemporaryExtension.Write(UpdatedExtensionData);
			EndIf;
			RecoveryRequired = False;
			
			Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
				TemporaryExtensionProperties.Name, Base64String(TemporaryExtensionProperties.HashSum)));
				
		Except
			ErrorInfo = ErrorInfo();
			If ExtensionID = Undefined Then
				If PlacedFiles.Count() > 1 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot add extensions from the file
							           |""%1""
							           |when receiving permissions due to:
							           |%2';"),
							FileThatWasPut.Name,
							ErrorProcessing.BriefErrorDescription(ErrorInfo));
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Cannot add the extension when receiving permissions due to:
							           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
				EndIf;
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot update the extension when receiving permissions due to:
						           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
			EndIf;
			If RecoveryRequired Then
				Try
					If ExtensionID = Undefined Then
						TemporaryExtension.Delete();
					Else
						TemporaryExtension = FindExtension(ExtensionID);
						If TemporaryExtension = Undefined Then
							TemporaryExtension = ConfigurationExtensions.Create();
						EndIf;
						DisableSecurityWarnings(TemporaryExtension);
						DisableMainRolesUsageForAllUsers(TemporaryExtension);
						TemporaryExtension.Write(UpdatedExtensionData);
					EndIf;
				Except
					ErrorInfo = ErrorInfo();
					If ExtensionID = Undefined Then 
						If PlacedFiles.Count() > 1 Then
							ErrorText = ErrorText + Chars.LF + Chars.LF
								+ StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = 'Cannot delete the added extension from the file when receiving permissions
									           |%1
									           |due to:
									           |%2';"),
									FileThatWasPut.Name,
									ErrorProcessing.BriefErrorDescription(ErrorInfo));
						Else
							ErrorText = ErrorText + Chars.LF + Chars.LF
								+ StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = 'An unexpected error occurred when trying to delete the temporarily added extension:
									           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
						EndIf;
					Else
						ErrorText = ErrorText + Chars.LF + Chars.LF
							+ StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'An unexpected error occurred when trying to restore the temporarily changed extension:
								           |%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
					EndIf;
				EndTry;
			EndIf;
			Raise ErrorText;
		EndTry;
	EndDo;
	
	InstalledExtensions = ConfigurationExtensions.Get();
	For Each Extension In InstalledExtensions Do
		Permissions.Add(ModuleSafeModeManager.PermissionToUseExternalModule(
			Extension.Name, Base64String(Extension.HashSum)));
	EndDo;
	
	PermissionsRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(Permissions,
		Common.MetadataObjectID("InformationRegister.ExtensionVersionParameters")));
	
EndProcedure

&AtServer
Procedure DisableSecurityWarnings(Extension)
	
	Catalogs.ExtensionsVersions.DisableSecurityWarnings(Extension);
	
EndProcedure

&AtServer
Procedure DisableMainRolesUsageForAllUsers(Extension)
	
	Catalogs.ExtensionsVersions.DisableMainRolesUsageForAllUsers(Extension);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Setting ViewOnly appearance parameter for common extensions and extensions passed from the master node to the subordinate DIB node.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListAttach.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListSafeModeFlag.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExtensionsListPassToSubordinateDIBNodes.Name);
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItemGroupCommon = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroupCommon.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemGroupCommon.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExtensionsList.Common");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FilterItemGroupCommon.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IsSharedUserInArea");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExtensionsList.ReceivedFromMasterDIBNode");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
EndProcedure

&AtClient
Procedure SetCommandBarButtonAvailability()
	
	If Items.RefreshPages.CurrentPage = Items.TimeConsumingOperationPage Then 
		
		Items.ExtensionsListAdd.Enabled = False;
		Items.ExtensionsListDelete.Enabled = False;
		Items.ExtensionsListUpdateFromFile.Enabled = False;
		
		Items.ExtensionsListContextMenuAdd.Enabled = False;
		Items.ExtensionsListContextMenuDelete.Enabled = False;
		Items.ExtensionsListContextMenuUpdateFromFile.Enabled = False;
		
	ElsIf Items.RefreshPages.CurrentPage = Items.ExtensionsListPage Then 
		
		OneRowSelected = Items.ExtensionsList.SelectedRows.Count() = 1;
		
		CanEdit1 = True;
		If OneRowSelected Then 
			CurrentExtension = Items.ExtensionsList.CurrentData;
			
			CanEdit1 = (Not CurrentExtension.Common 
				Or Not IsSharedUserInArea())
				And Not CurrentExtension.ReceivedFromMasterDIBNode;
		EndIf;
		
		Items.ExtensionsListAdd.Enabled = True;
		Items.ExtensionsListDelete.Enabled = CanEdit1;
		Items.ExtensionsListUpdateFromFile.Enabled = CanEdit1;
		
		Items.ExtensionsListContextMenuAdd.Enabled = True;
		Items.ExtensionsListContextMenuDelete.Enabled = CanEdit1;
		Items.ExtensionsListContextMenuUpdateFromFile.Enabled = OneRowSelected And CanEdit1;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsSharedUserInArea()
	
	Return StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters();
		
EndFunction

&AtServerNoContext
Function ParameterFillingEventName()
	
	Return InformationRegisters.ExtensionVersionParameters.ParameterFillingEventName();
	
EndFunction

#EndRegion