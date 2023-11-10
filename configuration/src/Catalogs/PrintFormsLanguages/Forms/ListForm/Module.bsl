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
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	If Common.IsMobileClient() Then
		Items.FormCreate.Representation = ButtonRepresentation.Picture;
	EndIf;
	
	Fields = New Array;
	Fields.Add("Description");
	
	List.SetRestrictionsForUseInGroup(Fields);
	List.SetRestrictionsForUseInOrder(Fields);
	List.SetRestrictionsForUseInFilter(Fields);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AdditionalInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "GoToTheLayoutOfPrintedForms" Then
		StandardProcessing = False;
		OpenForm("InformationRegister.UserPrintTemplates.Form.PrintFormTemplates");
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServerNoContext
Procedure ListOnGetDataAtServer(TagName, Settings, Rows)
	
	For Each String In Rows Do
		String.Value.Data["Description"] = NationalLanguageSupportServer.LanguagePresentation(String.Value.Data["Code"]);
	EndDo;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, IsFolder, Parameter)
	
	Cancel = True;
	AddLanguage();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Create(Command)
	
	AddLanguage();
	
EndProcedure

#EndRegion

#Region Private

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// 

// Parameters:
//  SelectedLanguages - Array of Structure:
//   * Code - String
//   * Description - String
//
&AtClient
Procedure WhenSelectingALanguage(SelectedLanguages, AdditionalParameters) Export
	
	If SelectedLanguages = Undefined Then
		Return;
	EndIf;
	
	AddedLanguages = AddLanguages(SelectedLanguages);
	CommonClient.NotifyObjectsChanged(AddedLanguages);
	Items.List.CurrentRow = AddedLanguages[0];
	Items.List.SelectedRows.Clear();
	For Each Language In AddedLanguages Do
		Items.List.SelectedRows.Add(Language);
	EndDo;
	
EndProcedure

&AtServer
Function AddLanguages(SelectedLanguages)
	
	Result = New Array;
	For Each LanguageDetails In SelectedLanguages Do
		LanguageLink = Catalogs.PrintFormsLanguages.FindByCode(LanguageDetails.Code);
		If ValueIsFilled(LanguageLink) Then
			LanguageObject = LanguageLink.GetObject();
		Else
			LanguageObject = Catalogs.PrintFormsLanguages.CreateItem();
		EndIf;
		FillPropertyValues(LanguageObject, LanguageDetails);
		LanguageObject.DeletionMark = False;
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.PrintFormsLanguages");
		LockItem.SetValue("Code", LanguageObject.Code);
		
		BeginTransaction();
		Try
			Block.Lock();
			LanguageObject.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		Result.Add(LanguageObject.Ref);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AddLanguage()
	
	NotifyDescription = New NotifyDescription("WhenSelectingALanguage", ThisObject);
	OpenForm("Catalog.PrintFormsLanguages.Form.PickLanguageFromAvailableLanguagesList", , ThisObject, , , , NotifyDescription);
	
EndProcedure

#EndRegion
