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
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	
	If DataSeparationEnabled Then
		Items.InformationDetails.Title = NStr("en = 'Patches are configured by the application administrator.';");
	ElsIf IsSubordinateDIBNode Then
		Items.InformationDetails.Title = NStr("en = 'Patches are managed in the master node.';");
	ElsIf Parameters.OnUpdate Then
		Items.InformationDetails.Title = NStr("en = 'Installed patches will be applied after the application restart.';");
	ElsIf Not Common.IsWindowsClient() Then
		Items.InformationPages.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.Corrections) Then
		If TypeOf(Parameters.Corrections) = Type("ValueList") Then
			Filter = Parameters.Corrections;
		ElsIf TypeOf(Parameters.Corrections) = Type("Array") Then
			Filter.LoadValues(Parameters.Corrections);
		EndIf;
	EndIf;
	
	OnUpdate = Parameters.OnUpdate;
	Items.InstalledPatchesClose.Visible = OnUpdate;
	
	If DataSeparationEnabled
		Or IsSubordinateDIBNode
		Or Not Common.IsWindowsClient()
		Or Parameters.OnUpdate Then
		Items.FormInstallPatch.Visible = False;
		Items.FormDeletePatch.Visible    = False;
		Items.InstalledPatchesExportAttachedPatches.Visible = False;
		Items.InstalledPatchesContextMenuAdd.Visible = False;
		Items.InstalledPatchesContextMenuDelete.Visible  = False;
		Items.InstalledPatchesAttach.Visible = False;
	EndIf;
	
	RefreshPatchesList();
	
	Items.InstalledPatchesApplicableTo.Visible = False;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationEventLogClick(Item)
	EventsArray = New Array;
	EventsArray.Add(NStr("en = 'Patch.Install';"));
	EventsArray.Add(NStr("en = 'Patch.Modify';"));
	EventsArray.Add(NStr("en = 'Patch.Delete';"));
	SelectionOfLogEvents = New Structure("EventLogEvent", EventsArray);
	EventLogClient.OpenEventLog(SelectionOfLogEvents);
EndProcedure

#EndRegion

#Region InstalledPatchesFormTableItemEventHandlers

&AtClient
Procedure InstalledPatchesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	If Not DataSeparationEnabled And Not IsSubordinateDIBNode Then
		DeleteExtensions(Item.SelectedRows);
	EndIf;
EndProcedure

&AtClient
Procedure InstalledPatchesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	If Not DataSeparationEnabled And Not IsSubordinateDIBNode Then
		Notification = New NotifyDescription("AfterInstallUpdates", ThisObject);
		OpenForm("DataProcessor.InstallUpdates.Form",,,,,, Notification);
	EndIf;
EndProcedure

&AtClient
Procedure InstalledPatchesAttachOnChange(Item)
	CurrentData = Items.InstalledPatches.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("RowID", CurrentData.GetID());
	
	ShowTimeConsumingOperation();
	AttachIdleHandler("InstalledPatchesAttachOnChangeCompletion", 0.1, True);
EndProcedure

&AtClient
Procedure InstalledPatchesAttachOnChangeCompletion()
	
	Try
		AttachInstalledPatchesOnChangeAtServer(Context.RowID);
	Except
		ErrorInfo = ErrorInfo();
		ShowMessageBox(, ErrorProcessing.BriefErrorDescription(ErrorInfo));
	EndTry;
	
	HideTimeConsumingOperation();
	
EndProcedure

&AtServer
Procedure AttachInstalledPatchesOnChangeAtServer(RowID)
	
	ListLine = InstalledPatches.FindByID(RowID);
	If ListLine = Undefined Then
		Return;
	EndIf;
	
	CurrentUsage = ListLine.Attach;
	Try
		Catalogs.ExtensionsVersions.ToggleExtensionUsage(ListLine.ExtensionID, CurrentUsage);
	Except
		ListLine.Attach = Not ListLine.Attach;
		RefreshPatchesList();
		
		Raise;
	EndTry;
	
	RefreshPatchesList();
	
EndProcedure

&AtClient
Procedure ShowTimeConsumingOperation()
	
	Items.InformationPages.CurrentPage= Items.TimeConsumingOperationPage;
	ReadOnly = True;
	
EndProcedure

&AtClient
Procedure HideTimeConsumingOperation()
	
	Items.InformationPages.CurrentPage = Items.InformationPage;
	ReadOnly = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveAs(Command)
	SavePatches();
EndProcedure

&AtClient
Procedure ExportAttachedPatches(Command)
	SavePatches(True);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshPatchesList()
	
	InstalledPatches.Clear();
	Items.InstalledPatchesPathToFile.Visible = False;
	
	SetPrivilegedMode(True);
	Extensions = ConfigurationExtensions.Get();
	SetPrivilegedMode(False);
	
	PatchesDetails = DescriptionOfInstalledFixes();
	
	For Each Extension In Extensions Do
		
		If Not ConfigurationUpdate.IsPatch(Extension) Then
			Continue;
		EndIf;
		
		If Filter.Count() <> 0 And Filter.FindByValue(Extension.Name) = Undefined Then
			Continue;
		EndIf;
		
		PatchProperties = ConfigurationUpdate.PatchProperties(Extension.Name);
		
		NewRow = InstalledPatches.Add();
		NewRow.Name = Extension.Name;
		NewRow.Checksum = Base64String(Extension.HashSum);
		NewRow.ExtensionID = Extension.UUID;
		NewRow.Attach = Extension.Active;
		NewRow.Version = Extension.Version;
		If PatchProperties = "ReadingError" Then
			NewRow.Status = 0;
		ElsIf PatchProperties <> Undefined Then
			NewRow.Status = 0;
			NewRow.LongDesc = PatchProperties.Description;
			NewRow.ApplicableTo = PatchApplicableTo(PatchProperties);
		Else
			LongDesc = PatchesDetails[Extension.Name];
			NewRow.Status = 1;
			NewRow.LongDesc = LongDesc;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function DescriptionOfInstalledFixes()
	
	If Not OnUpdate Then
		Return New Map;
	EndIf;
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	MethodParameters = New Array;
	MethodParameters.Add(StorageAddress);
	MethodParameters.Add(Filter.UnloadValues());
	MethodParameters.Add(True);
	BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
		"ConfigurationUpdate.NewPatchesDetails1",
		MethodParameters);
	BackgroundJob.WaitForExecutionCompletion(Undefined);
	
	NewPatchesDetails = GetFromTempStorage(StorageAddress);
	If TypeOf(NewPatchesDetails) <> Type("Map") Then
		NewPatchesDetails = New Map;
	EndIf;
	
	Return NewPatchesDetails;
	
EndFunction

&AtServer
Function PatchApplicableTo(PatchProperties)
	
	ApplicableTo = New Array;
	For Each String In PatchProperties.AppliedFor Do
		ApplicableTo.Add(String.ConfigurationName);
	EndDo;
	
	Return StrConcat(ApplicableTo, Chars.LF);
	
EndFunction

&AtClient
Procedure DeleteExtensions(SelectedRows)
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	ExtensionsIDs = New Array;
	For Each RowID In SelectedRows Do
		PatchString = InstalledPatches.FindByID(RowID);
		ExtensionsIDs.Add(PatchString.ExtensionID);
	EndDo;
	
	Context = New Structure;
	Context.Insert("ExtensionsIDs", ExtensionsIDs);
	
	Notification = New NotifyDescription("DeleteExtensionAfterConfirmation", ThisObject, Context);
	If ExtensionsIDs.Count() > 1 Then
		QueryText = NStr("en = 'Do you want to delete the selected patches?';");
	Else
		QueryText = NStr("en = 'Do you want to delete the patch?';");
	EndIf;
	
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteExtensionAfterConfirmation(Result, Context) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Handler = New NotifyDescription("DeleteExtensionFollowUp", ThisObject, Context);
		
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Queries = RequestsToRevokeExternalModuleUsagePermissions(Context.ExtensionsIDs);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, Handler);
		Else
			ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteExtensionFollowUp(Result, Context) Export
	
	If Result = DialogReturnCode.OK Then
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
		ErrorProcessing.ShowErrorInfo(ErrorInfo);
	EndTry;
	
EndProcedure

&AtServer
Procedure DeleteExtensionsAtServer(ExtensionsIDs)
	
	ErrorText = "";
	Catalogs.ExtensionsVersions.DeleteExtensions(ExtensionsIDs, ErrorText);
	
	RefreshPatchesList();
	
	If ValueIsFilled(ErrorText) Then
		Raise ErrorText;
	EndIf;
	
EndProcedure

&AtServer
Function RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs)
	
	Return Catalogs.ExtensionsVersions.RequestsToRevokeExternalModuleUsagePermissions(ExtensionsIDs);
	
EndFunction

&AtClient
Procedure AfterInstallUpdates(Result, AdditionalParameters) Export
	RefreshPatchesList();
EndProcedure

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

&AtClient
Procedure SavePatches(OnlyAttachedOnes = False)
	
	If OnlyAttachedOnes Then
		SelectedRows = AttachedPatchesIDs();
	Else
		SelectedRows = Items.InstalledPatches.SelectedRows;
	EndIf;
	
	NotifyDescription = New NotifyDescription("SaveAsCompletion", ThisObject, SelectedRows);
	
	If SelectedRows.Count() = 0 Then
		If OnlyAttachedOnes Then
			ShowMessageBox(, NStr("en = 'No attached patches.';"));
		EndIf;
		Return;
	ElsIf Not OnlyAttachedOnes And SelectedRows.Count() = 1 Then
		FilesToSave = SaveAtServer(SelectedRows);
	Else
		Title = NStr("en = 'Choose a directory to save the patch';");
		FileSystemClient.SelectDirectory(NotifyDescription, Title);
		Return;
	EndIf;
	
	If FilesToSave.Count() = 0 Then
		Return;
	EndIf;
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Choose a file to save the patch';");
	SavingParameters.Dialog.Filter    = NStr("en = '1C:Enterprise patch files (*.cfe)|*.cfe';") + "|" 
		+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	
	FileSystemClient.SaveFiles(Undefined, FilesToSave, SavingParameters);
	
EndProcedure 

&AtClient
Function AttachedPatchesIDs()
	
	ConnectedNow = New Array;
	For Each String In InstalledPatches Do
		If Not String.Attach Then
			Continue;
		EndIf;
		
		ConnectedNow.Add(String.GetID());
	EndDo;
	
	Return ConnectedNow;
EndFunction

&AtServer
Function SaveAtServer(RowsIDs, PathToDirectory = "")
	
	FilesToSave = New Array;
	For Each RowID In RowsIDs Do
		ListLine = InstalledPatches.FindByID(RowID);
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

#EndRegion