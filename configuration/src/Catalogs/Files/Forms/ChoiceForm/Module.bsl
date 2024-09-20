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
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FilesFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else
		If Parameters.SelectTemplate1 Then
			
			DefinePossibilityAddFilesTemplates();
			
			TemplateSelectionMode = Parameters.SelectTemplate1;
			
			CommonClientServer.SetDynamicListFilterItem(
				Folders, "Ref", Catalogs.FilesFolders.Templates,
				DataCompositionComparisonType.InHierarchy, , True);
			
			Items.Folders.CurrentRow = Catalogs.FilesFolders.Templates;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		EndIf;
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
	If ValueIsFilled(Parameters.CurrentRow) Then 
		Items.Folders.CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	OnChangeUseSignOrEncryptionAtServer();
	
	If Common.IsMobileClient() Then
		Items.Folders.TitleLocation = FormItemTitleLocation.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" And Parameter.Property("IsNew") And Parameter.IsNew Then
		
		If Parameter <> Undefined Then
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = Items.Folders.CurrentRow Then
					Items.List.Refresh();
					
					CreatedFile = Undefined;
					If Parameter.Property("File", CreatedFile) Then
						Items.List.CurrentRow = CreatedFile;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		Items.List.Refresh();
		
	EndIf;
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		And (    Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If MobileClient Then
	SetFoldersTreeTitle();
#EndIf

EndProcedure

#EndRegion

#Region FoldersFormTableItemEventHandlers

&AtClient
Procedure FoldersOnActivateRow(Item)
	
	AttachIdleHandler("IdleHandler", 0.2, True);
	
#If MobileClient Then
	AttachIdleHandler("SetFoldersTreeTitle", 0.1, True);
	CurrentItem = Items.List;
#EndIf

EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	If Not Copy Then
		AddFileToApplication();
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AppendFile(Command)
	
	AddFileToApplication();
	
EndProcedure

&AtClient
Procedure AddFileToApplication()
	
	If TemplateSelectionMode Then
		
		FilesOperationsInternalClient.AddFileFromFileSystem(Items.Folders.CurrentRow, ThisObject);
		
	Else
		
		DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
		If DCParameterValue = Undefined Then
			FileOwner = Undefined;
		Else
			FileOwner = DCParameterValue.Value;
		EndIf;
		FilesOperationsInternalClient.AppendFile(Undefined, FileOwner, ThisObject);
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

// The procedure updates the Files list.
&AtClient
Procedure IdleHandler()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	
EndProcedure

&AtClient
Procedure SetFoldersTreeTitle()
	
	Items.Folders.Title = ?(Items.Folders.CurrentData = Undefined, "",
		Items.Folders.CurrentData.Description);
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
EndProcedure

&AtServer
Procedure DefinePossibilityAddFilesTemplates()
	
	Var HasRightAddFiles, ModuleAccessManagement;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		HasRightAddFiles = ModuleAccessManagement.HasRight("AddFilesAllowed", Catalogs.FilesFolders.Templates);
	Else
		HasRightAddFiles = AccessRight("Insert", Metadata.Catalogs.Files) And AccessRight("Read", Metadata.Catalogs.FilesFolders);
	EndIf;
	
	If Not HasRightAddFiles Then
		Items.AppendFile.Visible = False;
	EndIf;

EndProcedure

#EndRegion
