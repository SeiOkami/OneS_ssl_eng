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
	
	ArrayOfSaveFormatsRestrictions = StrSplit(Parameters.RestrictionOfSaveFormats, ",", False);
	
	For Each SaveFormat In PrintManagement.SpreadsheetDocumentSaveFormatsSettings() Do
		If Not ArrayOfSaveFormatsRestrictions.Count()
			Or ArrayOfSaveFormatsRestrictions.Find(SaveFormat.Extension) <> Undefined Then
				SelectedSaveFormats.Add(String(SaveFormat.SpreadsheetDocumentFileType), String(SaveFormat.Ref), False, SaveFormat.Picture);
		EndIf;
	EndDo;
	
	Items.AttachmentFormat.Visible = SelectedSaveFormats.Count() > 1;
	
	RecipientsList = Parameters.Recipients;
	If TypeOf(RecipientsList) = Type("String") Then
		FillRecipientsTableFromRow(RecipientsList);
	ElsIf TypeOf(RecipientsList) = Type("ValueList") Then
		FillRecipientsTableFromValueList(RecipientsList);
	ElsIf TypeOf(RecipientsList) = Type("Array") Then
		FillRecipientsTableFromStructuresArray(RecipientsList);
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		Items.Sign.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	SaveFormatsFromSettings = Settings["SelectedSaveFormats"];
	If SaveFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SelectedSaveFormats Do 
			FormatFromSettings = SaveFormatsFromSettings.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SelectedSaveFormats");
	EndIf;
	
	If Common.IsMobileClient() Then
		Settings["Sign"] = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatSelection();
	GeneratePresentationForSelectedFormats();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectAttachmentFormat") Then
		
		If ValueSelected <> DialogReturnCode.Cancel And ValueSelected <> Undefined Then
			SetFormatSelection(ValueSelected.SaveFormats);
			PackToArchive = ValueSelected.PackToArchive;
			TransliterateFilesNames = ValueSelected.TransliterateFilesNames;
			Sign = ValueSelected.Sign;
			GeneratePresentationForSelectedFormats();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	StandardProcessing = False;
	OpeningParameters = New Structure;
	OpeningParameters.Insert("FormatSettings", SelectedFormatSettings());
	OpenForm("CommonForm.SelectAttachmentFormat", OpeningParameters, ThisObject);
EndProcedure

#EndRegion

#Region RecipientsFormTableItemEventHandlers

&AtClient
Procedure RecipientsBeforeRowChange(Item, Cancel)
	Cancel = True;
	Selected = Not Items.Recipients.CurrentData.Selected;
	For Each SelectedRow In Items.Recipients.SelectedRows Do
		Recipient = Recipients.FindByID(SelectedRow);
		Recipient.Selected = Selected;
	EndDo;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	SelectionResult = SelectedFormatSettings();
	NotifyChoice(SelectionResult);
EndProcedure

&AtClient
Procedure SelectAllRecipients(Command)
	SetSelectionForAllRecipients(True);
EndProcedure

&AtClient
Procedure CancelSelectAll(Command)
	SetSelectionForAllRecipients(False);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillRecipientsTableFromRow(Val RecipientsList)
	
	RecipientsList = CommonClientServer.EmailsFromString(RecipientsList);
	
	For Each Recipient In RecipientsList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Address;
		NewRecipient.Presentation = Recipient.Alias;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientsTableFromValueList(RecipientsList)
	
	For Each Recipient In RecipientsList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Value;
		NewRecipient.Presentation = Recipient.Presentation;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientsTableFromStructuresArray(RecipientsList)
	
	For Each Recipient In RecipientsList Do
		NewRecipient = Recipients.Add();
		FillPropertyValues(NewRecipient, Recipient);
		NewRecipient.AddressPresentation = NewRecipient.Address;
		If Not IsBlankString(Recipient.EmailAddressKind) Then
			NewRecipient.AddressPresentation = NewRecipient.AddressPresentation + " (" + Recipient.EmailAddressKind + ")";
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetFormatSelection(Val SaveFormats = Undefined)
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SaveFormats <> Undefined Then
			SelectedFormat.Check = SaveFormats.Find(SelectedFormat.Value) <> Undefined;
		EndIf;
			
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedSaveFormats[0].Check = True; // The default choice is the first in the list.
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	AttachmentFormat = "";
	FormatsCount = 0;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(AttachmentFormat) Then
				AttachmentFormat = AttachmentFormat + ", ";
			EndIf;
			AttachmentFormat = AttachmentFormat + SelectedFormat.Presentation;
			FormatsCount = FormatsCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SaveFormats = New Array;
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			SaveFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;	
	
	Result = CommonInternalClient.PrintFormFormatSettings();
	Result.Insert("PackToArchive", PackToArchive);
	Result.Insert("SaveFormats", SaveFormats);
	Result.Insert("Recipients", SelectedRecipients());
	Result.Insert("TransliterateFilesNames", TransliterateFilesNames);
	Result.Insert("Sign", Sign);
	Return Result;
	
EndFunction

&AtClient
Function SelectedRecipients()
	Result = New Array;
	For Each SelectedRecipient In Recipients Do
		If SelectedRecipient.Selected Then
			RecipientStructure1 = New Structure("Address,Presentation,ContactInformationSource,EmailAddressKind");
			FillPropertyValues(RecipientStructure1, SelectedRecipient);
			Result.Add(RecipientStructure1);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure SetSelectionForAllRecipients(Case)
	For Each Recipient In Recipients Do
		Recipient.Selected = Case;
	EndDo;
EndProcedure

#EndRegion
