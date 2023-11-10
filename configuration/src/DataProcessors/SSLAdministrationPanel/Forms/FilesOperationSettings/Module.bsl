///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

// 
// 

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MaxFileSize = FilesOperations.MaxFileSizeCommon() / (1024*1024);
	MaxDataAreaFileSize = FilesOperations.MaxFileSize() / (1024*1024);
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If DataSeparationEnabled Then
		Items.MaxFileSize.MaxValue = MaxFileSize;
	EndIf;
	
	DenyUploadFilesByExtension = ConstantsSet.DenyUploadFilesByExtension;
	
	ParametersOfFilesStorageInIB = FilesOperationsInVolumesInternal.FilesStorageParametersInInfobase();
	If ParametersOfFilesStorageInIB <> Undefined Then
		IBFilesExtensions = ParametersOfFilesStorageInIB.FilesExtensions;
		MaxFileSizeInIB = ParametersOfFilesStorageInIB.MaximumSize / (1024*1024);
	EndIf;
	
	FilesOperationsInternal.FillListWithFilesTypes(Items.IBFilesExtensions.ChoiceList);
	
	IsSystemAdministrator = Users.IsFullUser(, True);
	Items.FilesStorageManagement.Visible = IsSystemAdministrator;
	Items.FilesVolumesManagementGroup.Visible = IsSystemAdministrator;
	Items.FilesSizeManagementInIBGroup.Visible = IsSystemAdministrator;
	Items.CommonParametersForAllDataAreas.Visible = IsSystemAdministrator And DataSeparationEnabled;
	Items.TextFilesExtensionsListGroup.Visible = Not DataSeparationEnabled;
	Items.IBFilesExtensionsManagementGroup.Visible = IsSystemAdministrator;
	
	If IsSystemAdministrator Then
		FilesStorageMethodValue = ConstantsSet.FilesStorageMethod;
		ConfigureSettingsOfStorageInVolumesAvailability();
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.FilesOperationSettingsOnCreateAtServer(ThisObject);
	
	If Common.IsMobileClient() Then
		
		Items.IndentFilesSizeInIB.Visible = False;
		Items.IndentIBFilesExtensions.Visible = False;
		Items.MaxFileSizeInIB.SpinButton = False;
		Items.IBFilesExtensions.TitleLocation = FormItemTitleLocation.Top;
		Items.TextFilesExtensionsList.TitleLocation = FormItemTitleLocation.Top;
		Items.FilesExtensionsListDocumentDataAreas.TitleLocation = FormItemTitleLocation.Top;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		RefreshApplicationInterface();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilesStorageMethodOnChange(Item)
	
	If ConstantsSet.FilesStorageMethod = FilesStorageMethodValue Then
		Return;
	EndIf;
	
	ConstantsSet.StoreFilesInVolumesOnHardDrive = ConstantsSet.FilesStorageMethod <> "InInfobase";
	
	NotificationProcessing = New NotifyDescription(
		"FilesStorageMethodOnChangeCompletion", ThisObject, Item);
	
	If FilesStorageMethodValue <> "InInfobase"
		And ConstantsSet.StoreFilesInVolumesOnHardDrive Then
		
		ExecuteNotifyProcessing(NotificationProcessing, DialogReturnCode.OK);
		Return;
	EndIf;
	
	Try
		
		RequestsForPermissionToUseExternalResources = PermissionRequestsToUseExternalResourcesOfFilesStorageVolumes(
			ConstantsSet.StoreFilesInVolumesOnHardDrive);
		
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
				RequestsForPermissionToUseExternalResources, ThisObject, NotificationProcessing);
		Else
			ExecuteNotifyProcessing(NotificationProcessing, DialogReturnCode.OK);
		EndIf;
		
	Except
		
		ConstantsSet.FilesStorageMethod = FilesStorageMethodValue;
		ConstantsSet.StoreFilesInVolumesOnHardDrive = FilesStorageMethodValue <> "InInfobase";
		Raise;
		
	EndTry;
	
EndProcedure

&AtClient
Procedure CreateSubdirectoriesWithOwnersNamesOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure IBFilesExtensionsOnChange(Item)
	
	OnChangeSettingsOfFilesStorageInIB();
	
EndProcedure

&AtClient
Procedure IBFilesExtensionsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	IBFilesExtensions = FilesOperationsInternalClient.ExtensionsByFileType(ValueSelected);
	OnChangeSettingsOfFilesStorageInIB();
	
EndProcedure

&AtClient
Procedure MaxFileSizeInIBOnChange(Item)
	
	OnChangeSettingsOfFilesStorageInIB();
	
EndProcedure

&AtClient
Procedure DenyUploadFilesByExtensionOnChange(Item)
	
	If Not DenyUploadFilesByExtension Then
		
		Notification = New NotifyDescription(
			"ProhibitFilesImportByExtensionAfterConfirm", ThisObject, New Structure("Item", Item));
		OpenForm("CommonForm.SecurityWarning",
			New Structure("Key", "OnChangeDeniedExtensionsList"), , , , , Notification);
		Return;
		
	EndIf;
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure SynchronizeFilesOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure DeniedDataAreaExtensionsListOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure MaxDataAreaFileSizeOnChange(Item)
	
	If MaxDataAreaFileSize = 0 Then
		
		MessageText = NStr("en = 'Please specify File size limit.';");
		CommonClient.MessageToUser(MessageText, ,"MaxDataAreaFileSize");
		Return;
		
	EndIf;
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure FilesExtensionsListDocumentDataAreasOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure TestFilesExtensionsListOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// 

&AtClient
Procedure MaxFileSizeOnChange(Item)
	
	If MaxFileSize = 0 Then
		
		MessageText = NStr("en = 'Please specify File size limit.';");
		CommonClient.MessageToUser(MessageText, ,"MaxFileSize");
		Return;
		
	EndIf;
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure DeniedExtensionsListOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure FilesExtensionsListOpenDocumentOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CatalogFiles(Command)
	
	OpenForm("Catalog.Files.ListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure CatalogFileStorageVolumes(Command)
	
	OpenForm("Catalog.FileStorageVolumes.ListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure FilesSynchronizationSetup(Command)
	
	OpenForm("InformationRegister.FileSynchronizationSettings.ListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure FileTransfer(Command)
	
	FilesOperationsInternalClient.MoveFiles();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FilesStorageMethodOnChangeCompletion(Response, Item) Export
	
	If Response <> DialogReturnCode.OK Then
		ConstantsSet.FilesStorageMethod = FilesStorageMethodValue;
		ConstantsSet.StoreFilesInVolumesOnHardDrive = FilesStorageMethodValue <> "InInfobase";
	Else
		
		If FilesStorageMethodValue = "InInfobase"
			And ConstantsSet.StoreFilesInVolumesOnHardDrive
			And Not HasFileStorageVolumes() Then
			
			ShowMessageBox(, NStr("en = 'Storing files to the hard disk drive is enabled but the volumes are not configured.
				|Files will be saved to the infobase until at least one file storage volume is configured.';"));
		EndIf;
		
		OnChangeFilesStorageMethodAtServer();
		RefreshReusableValues();
		AfterChangeAttribute("FilesStorageMethod", False);
		AfterChangeAttribute("StoreFilesInVolumesOnHardDrive");
		
	EndIf;
	
EndProcedure

// Parameters:
//  Result - Undefined
//            - String
//  AdditionalParameters - Structure:
//    * Item - FormField
//              - FormFieldExtensionForACheckBoxField
//
&AtClient
Procedure ProhibitFilesImportByExtensionAfterConfirm(Result, AdditionalParameters) Export
	
	If Result <> Undefined
		And Result = "Continue" Then
		
		Attachable_OnChangeAttribute(AdditionalParameters.Item);
	Else
		DenyUploadFilesByExtension = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeSettingsOfFilesStorageInIB()
	
	SetParametersOfFilesStorageInIB(
		New Structure("FilesExtensions, MaximumSize",
		IBFilesExtensions, MaxFileSizeInIB*1024*1024));
	
	RefreshReusableValues();
	AfterChangeAttribute("ParametersOfFilesStorageInIB", False);
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	AfterChangeAttribute(ConstantName, ShouldRefreshInterface);
	
EndProcedure

&AtClient
Procedure AfterChangeAttribute(ConstantName, ShouldRefreshInterface = True)
	
	If ShouldRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure OnChangeFilesStorageMethodAtServer()
	
	FilesStorageMethodValue = ConstantsSet.FilesStorageMethod;
	Constants.FilesStorageMethod.Set(ConstantsSet.FilesStorageMethod);
	Constants.StoreFilesInVolumesOnHardDrive.Set(ConstantsSet.StoreFilesInVolumesOnHardDrive);
	SetAvailability("ConstantsSet.FilesStorageMethod");
	
	RefreshReusableValues();
	
EndProcedure

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If DataPathAttribute = "ConstantsSet.FilesStorageMethod" Then
		ConfigureSettingsOfStorageInVolumesAvailability();
	EndIf;
	
	If DataPathAttribute = "DenyUploadFilesByExtension"
		Or DataPathAttribute = "" Then
		
		Items.DeniedDataAreaExtensionsList.Enabled = DenyUploadFilesByExtension;
	EndIf;
	
	If DataPathAttribute = "ConstantsSet.SynchronizeFiles"
		Or DataPathAttribute = "" Then
		
		Items.FileSynchronizationSettings.Enabled = ConstantsSet.SynchronizeFiles;
	EndIf;
	
EndProcedure

&AtServer
Procedure ConfigureSettingsOfStorageInVolumesAvailability()
	
	Items.FilesVolumesManagementGroup.Enabled = ConstantsSet.StoreFilesInVolumesOnHardDrive;
	Items.CatalogFileStorageVolumes.Enabled = ConstantsSet.StoreFilesInVolumesOnHardDrive;
	Items.CreateSubdirectoriesWithOwnersNames.Enabled = ConstantsSet.StoreFilesInVolumesOnHardDrive;
	Items.FilesSizeManagementInIBGroup.Enabled =
		ConstantsSet.FilesStorageMethod = "InInfobaseAndVolumesOnHardDrive";
	Items.IBFilesExtensionsManagementGroup.Enabled =
		ConstantsSet.FilesStorageMethod = "InInfobaseAndVolumesOnHardDrive";
	
EndProcedure

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		
		If DataPathAttribute = "MaxFileSize" Then
			ConstantsSet.MaxFileSize = MaxFileSize * (1024*1024);
			ConstantName = "MaxFileSize";
		ElsIf DataPathAttribute = "MaxDataAreaFileSize" Then
			
			If Not Common.DataSeparationEnabled() Then
				ConstantsSet.MaxFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaxFileSize";
			Else
				ConstantsSet.MaxDataAreaFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaxDataAreaFileSize";
			EndIf;
			
		ElsIf DataPathAttribute = "DenyUploadFilesByExtension" Then
			ConstantsSet.DenyUploadFilesByExtension = DenyUploadFilesByExtension;
			ConstantName = "DenyUploadFilesByExtension";
		EndIf;
		
	Else
		ConstantName = NameParts[1];
	EndIf;
	
	If IsBlankString(ConstantName) Then
		Return "";
	EndIf;
	
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServerNoContext
Procedure SetParametersOfFilesStorageInIB(StorageParameters)
	
	FilesOperationsInVolumesInternal.SetFilesStorageParametersInInfobase(StorageParameters);
	
EndProcedure

&AtServerNoContext
Function PermissionRequestsToUseExternalResourcesOfFilesStorageVolumes(Include)
	
	PermissionRequestsToUse = New Array;
	CatalogName = "FileStorageVolumes";
	
	If Include Then
		Catalogs[CatalogName].AddRequestsToUseExternalResourcesForAllVolumes(
			PermissionRequestsToUse);
	Else
		Catalogs[CatalogName].AddRequestsToStopUsingExternalResourcesForAllVolumes(
			PermissionRequestsToUse);
	EndIf;
	
	Return PermissionRequestsToUse;
	
EndFunction

&AtServerNoContext
Function HasFileStorageVolumes()
	
	Return FilesOperationsInVolumesInternal.HasFileStorageVolumes();
	
EndFunction

#EndRegion