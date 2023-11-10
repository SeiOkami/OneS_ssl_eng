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
	
	Items.MoveAllFilesToVolumes.Visible = Common.SubsystemExists("StandardSubsystems.FilesOperations");
	
	If Common.IsMobileClient() Then
		Items.ListComment.Visible = False;
		Items.ListMaximumSize.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetClearDeletionMark(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StartDeletionMarkChange(Items.List.CurrentData);
	
EndProcedure

&AtClient
Procedure MoveFiles(Command)
	
	FilesOperationsInternalClient.MoveFiles();
	
EndProcedure

&AtClient
Procedure CheckIntegrity(Command)
	
	CurrentData = Items.List.CurrentData;
	If Not StandardSubsystemsClient.IsDynamicListItem(CurrentData) Then
		Return;
	EndIf;
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	ReportParameters.Insert("Filter", New Structure("Volume", CurrentData.Ref));
	
	OpenForm("Report.VolumeIntegrityCheck.ObjectForm", ReportParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure StartDeletionMarkChange(CurrentData)
	
	If CurrentData.DeletionMark Then
		QueryText = NStr("en = 'Do you want to clear the deletion mark from ""%1""?';");
	Else
		QueryText = NStr("en = 'Do you want to mark ""%1"" for deletion?';");
	EndIf;
	
	QuestionContent = New Array;
	QuestionContent.Add(PictureLib.DoQueryBox32);
	QuestionContent.Add(StringFunctionsClientServer.SubstituteParametersToString(
		QueryText, CurrentData.Description));
	
	ShowQueryBox(
		New NotifyDescription("ContinueDeletionMarkChange", ThisObject, CurrentData),
		New FormattedString(QuestionContent),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ContinueDeletionMarkChange(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Volume = Items.List.CurrentData.Ref;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Volume", Items.List.CurrentData.Ref);
	AdditionalParameters.Insert("DeletionMark", Undefined);
	AdditionalParameters.Insert("Queries", New Array());
	AdditionalParameters.Insert("FormIdentifier", UUID);
	
	PrepareSetClearDeletionMark(Volume, AdditionalParameters);
	
	ContinuationNotification = New NotifyDescription(
		"ContinueSetClearDeletionMark", ThisObject, AdditionalParameters);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			AdditionalParameters.Queries, ThisObject, ContinuationNotification);
	Else
		ExecuteNotifyProcessing(ContinuationNotification, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure PrepareSetClearDeletionMark(Volume, AdditionalParameters)
	
	LockDataForEdit(Volume, , AdditionalParameters.FormIdentifier);
	
	VolumeProperties = Common.ObjectAttributesValues(
		Volume, "DeletionMark,FullPathWindows,FullPathLinux");
	
	AdditionalParameters.DeletionMark = VolumeProperties.DeletionMark;
	
	If AdditionalParameters.DeletionMark Then
		// Deletion mark is set, and it is to be cleared.
		
		Query = Catalogs.FileStorageVolumes.RequestToUseExternalResourcesForVolume(
			Volume, VolumeProperties.FullPathWindows, VolumeProperties.FullPathLinux);
	Else
		// Deletion mark is not set, and it is to be set.
		If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
			Query = ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(Volume)
		EndIf;
	EndIf;
	
	AdditionalParameters.Queries.Add(Query);
	
EndProcedure

&AtClient
Procedure ContinueSetClearDeletionMark(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		EndSetClearDeletionMark(AdditionalParameters);
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure EndSetClearDeletionMark(AdditionalParameters)
	
	BeginTransaction();
	Try
	
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.Catalogs.FileStorageVolumes.FullName());
		DataLockItem.SetValue("Ref", AdditionalParameters.Volume);
		DataLock.Lock();
		
		Object = AdditionalParameters.Volume.GetObject();
		Object.SetDeletionMark(Not AdditionalParameters.DeletionMark);
		Object.Write();
		
		UnlockDataForEdit(
		AdditionalParameters.Volume, AdditionalParameters.FormIdentifier);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion