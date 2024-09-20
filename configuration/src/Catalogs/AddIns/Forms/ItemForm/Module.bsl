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
Var AdditionalInformation;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = Object.Ref.IsEmpty();
	
	If IsNew Then
		Parameters.ShowImportFromFileDialogOnOpen = True;
	EndIf;
	
	SetVisibilityAvailability();
	
	If Not AccessRight("Edit", Metadata.Catalogs.AddIns) Then
		
		Items.FormUpdateFromFile.Visible = False;
		Items.FormSaveAs.Visible = False;
		Items.PerformUpdateFrom1CITSPortal.Visible = False;
	
	EndIf;
	
	If Not AddInsInternal.CanImportFromPortal() Then 
		
		Items.UpdateFrom1CITSPortal.Visible = False;
		Items.PerformUpdateFrom1CITSPortal.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.ShowImportFromFileDialogOnOpen Then
		AttachIdleHandler("ImportAddInFromFile", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// If the "Reread" command is called, delete add-in data clipboard
	If IsTempStorageURL(ComponentBinaryDataAddress) Then
		DeleteFromTempStorage(ComponentBinaryDataAddress);
	EndIf;
	
	ComponentBinaryDataAddress = Undefined;
	SetVisibilityAvailability();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// If there is binary add-in data to be saved, add them to AdditionalProperties.
	If IsTempStorageURL(ComponentBinaryDataAddress) Then
		ComponentBinaryData = GetFromTempStorage(ComponentBinaryDataAddress);
		CurrentObject.AdditionalProperties.Insert("ComponentBinaryData", ComponentBinaryData);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Saved = True; // 
	Parameters.ShowImportFromFileDialogOnOpen = False; // Preventing closing form on error.
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetVisibilityAvailability();
	
	AddInsInternal.NotifyAllSessionsAboutAddInChange();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then 
		Return;
	EndIf;
	
	If Not Modified Then
		StandardProcessing = False;
		
		CloseParameter = AddInsInternalClient.AddInImportResult();
		CloseParameter.Imported1 = Saved;
		CloseParameter.Id = Object.Id;
		CloseParameter.Version = Object.Version;
		CloseParameter.Description  = Object.Description;
		CloseParameter.AdditionalInformation = AdditionalInformation;
		
		Close(CloseParameter);
	EndIf;	
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseOnChange(Item)
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure UpdateFrom1CITSPortalOnChange(Item)
	
	SetVisibilityAvailability();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateFromThePortal(Command)
	
	If Modified Then
		Notification = New NotifyDescription("AfterCloseQuestionWriteObject", ThisObject);
		ShowQueryBox(Notification, 
			NStr("en = 'Before checking for updates, save the changes. Save the changes?';"),
			QuestionDialogMode.YesNo);
	Else 
		StartAddInUpdateFromPortal();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateFromFile(Command)
	
	Parameters.FileThatWasPut = Undefined;
	ClearMessages();
	ImportAddInFromFile();
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If IsTempStorageURL(ComponentBinaryDataAddress) Then
		ShowMessageBox(, NStr("en = 'Save the catalog item before saving the add-in.';"));
	Else 
		ClearMessages();
		AddInsInternalClient.SaveAddInToFile(Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure SupportedClientApplications(Command)
	
	Attributes = New Structure;
	Attributes.Insert("Windows_x86");
	Attributes.Insert("Windows_x86_64");
	Attributes.Insert("Linux_x86");
	Attributes.Insert("Linux_x86_64");
	Attributes.Insert("Windows_x86_Firefox");
	Attributes.Insert("Linux_x86_Firefox");
	Attributes.Insert("Linux_x86_64_Firefox");
	Attributes.Insert("Windows_x86_MSIE");
	Attributes.Insert("Windows_x86_64_MSIE");
	Attributes.Insert("Windows_x86_Chrome");
	Attributes.Insert("Linux_x86_Chrome");
	Attributes.Insert("Linux_x86_64_Chrome");
	Attributes.Insert("MacOS_x86_64");
	Attributes.Insert("MacOS_x86_64_Safari");
	Attributes.Insert("MacOS_x86_64_Chrome");
	Attributes.Insert("MacOS_x86_64_Firefox");
	Attributes.Insert("Windows_x86_YandexBrowser");
	Attributes.Insert("Windows_x86_64_YandexBrowser");
	Attributes.Insert("Linux_x86_YandexBrowser");
	Attributes.Insert("Linux_x86_64_YandexBrowser");
	Attributes.Insert("MacOS_x86_64_YandexBrowser");
	
	FillPropertyValues(Attributes, Object);
	
	FormParameters = New Structure;
	FormParameters.Insert("SupportedClients", Attributes);
	
	OpenForm("CommonForm.SupportedClientApplications", FormParameters);
	
EndProcedure

#EndRegion

#Region Private

#Region ClientLogic

&AtClient
Procedure ImportAddInFromFile()
	
	If Parameters.FileThatWasPut <> Undefined Then
		ImportAddInAfterPutFile(Parameters.FileThatWasPut, Undefined);
		Return;
	EndIf;
	
	Notification = New NotifyDescription("ImportAddInAfterSecurityWarning", ThisObject);
	FormParameters = New Structure("Key", "BeforeAddAddIn");
	OpenForm("CommonForm.SecurityWarning", FormParameters,,,,, Notification);
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
&AtClient
Procedure ImportAddInAfterSecurityWarning(Response, Context) Export
	
	//  
	// 
	// 
	// 
	If Response <> "Continue" Then
		ImportAddInOnErrorDisplay();
		Return;
	EndIf;
	
	Notification = New NotifyDescription("ImportAddInAfterPutFile", ThisObject, Context);
	ImportParameters = FileSystemClient.FileImportParameters();
	
	ImportParameters.Dialog.Filter    = NStr("en = 'Add-in (*.zip)|*.zip';")+"|"
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	ImportParameters.Dialog.Title = NStr("en = 'Select an add-in file';");
	ImportParameters.FormIdentifier = UUID;
	FileSystemClient.ImportFile_(Notification, ImportParameters, Object.FileName);

EndProcedure

// ImportAComponentFromAFile procedure continuation.
&AtClient
Procedure ImportAddInAfterPutFile(FileThatWasPut, Context) Export
	
	If FileThatWasPut = Undefined Then
		ImportAddInOnErrorDisplay(NStr("en = 'Cannot import an add-in file.';"));
		Return;
	EndIf;
	
	ImportParameters = New Structure;
	ImportParameters.Insert("FileStorageAddress", FileThatWasPut.Location);
	ImportParameters.Insert("FileName",            FileNameOnly(FileThatWasPut.Name));
	
	Result = ImportAddInFromFileOnServer(ImportParameters);
	If Result.Imported1 And IsTempStorageURL(ComponentBinaryDataAddress)Then
		AdditionalInformation = Result.AdditionalInformation;
		Modified = True;
	Else 
		ImportAddInOnErrorDisplay(Result.ErrorDescription, Result.ErrorInfo);
	EndIf;
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
&AtClient
Procedure ImportAddInOnErrorDisplay(ErrorDescription = "", ErrorInfo = Undefined)
	
	If IsBlankString(ErrorDescription) Then 
		ImportAddInAfterErrorDisplay(Undefined);
	Else 
		Notification = New NotifyDescription("ImportAddInAfterErrorDisplay", ThisObject);
		
		StringWithWarning = NStr("en = '%1
			|Specify a ZIP archive with an add-in.
			|For more information, see <a href = ""%2"">Add-in Development Technology</a> (in Russian).';")
			+ ?(ErrorInfo = Undefined, "",
				Chars.LF + ErrorProcessing.BriefErrorDescription(ErrorInfo));
		
		StringWithWarning = StringFunctionsClient.FormattedString(StringWithWarning, ErrorDescription,
			"https://its.1c.eu/db/metod8dev/content/3221");
		
		ShowMessageBox(Notification, StringWithWarning);
	EndIf;
	
EndProcedure

// ImportAComponentFromAFile procedure continuation.
&AtClient
Procedure ImportAddInAfterErrorDisplay(AdditionalParameters) Export
	
	// Opened via application interface.
	If Parameters.ShowImportFromFileDialogOnOpen Then 
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCloseQuestionWriteObject(QuestionResult, Context) Export 
	
	If QuestionResult = DialogReturnCode.Yes Then 
		Write();
		StartAddInUpdateFromPortal();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartAddInUpdateFromPortal()
	
	IsNew = Object.Ref.IsEmpty();
	If IsNew Then 
		Return;
	EndIf;
	
	UnlockFormDataForEdit();
	
	AddInsToUpdate = New Array;
	AddInsToUpdate.Add(Object.Ref);
	
	Notification = New NotifyDescription("AfterUpdateAddInFromPortal", ThisObject);
	AddInsInternalClient.UpdateAddInsFromPortal(Notification, AddInsToUpdate);
	
EndProcedure

&AtClient
Procedure AfterUpdateAddInFromPortal(Result, AdditionalParameters) Export
	
	UpdateCardAfterAddInUpdateFromPortal();
	
EndProcedure

#EndRegion

#Region ServerLogic

// Server logic of the ImportAddInFromFile procedure.
&AtServer
Function ImportAddInFromFileOnServer(ImportParameters)
	
	If Not Users.IsFullUser(,, False) Then
		Raise NStr("en = 'Insufficient rights to import an add-in.';");
	EndIf;
	
	ObjectOfCatalog = FormAttributeToValue("Object");
	
	BinaryData = GetFromTempStorage(ImportParameters.FileStorageAddress);
	Information = AddInsInternal.InformationOnAddInFromFile(BinaryData,, 
		Parameters.AdditionalInformationSearchParameters);
	
	Result = AddInImportResult();
	
	If Not Information.Disassembled Then 
		Result.ErrorDescription = Information.ErrorDescription;
		Result.ErrorInfo = Information.ErrorInfo;
		Return Result;
	EndIf;
	
	If ValueIsFilled(ObjectOfCatalog.Id)
		And ValueIsFilled(Information.Attributes.Id) Then 
		
		If ObjectOfCatalog.Id <> Information.Attributes.Id Then 
			Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update the add-in as IDs are different.
					|Expected ID is %1, and ID of the add-in to be imported is %2.';"),
				ObjectOfCatalog.Id, Information.Attributes.Id);
			Return Result;
		EndIf;
		
	EndIf;
	
	FillPropertyValues(ObjectOfCatalog, Information.Attributes,, "Id"); // According to manifest data.
	If Not ValueIsFilled(ObjectOfCatalog.Id) Then 
		ObjectOfCatalog.Id = Information.Attributes.Id;
	EndIf;
	ObjectOfCatalog.FileName =  ImportParameters.FileName;          // 
	ComponentBinaryDataAddress = PutToTempStorage(Information.BinaryData,
		UUID);
	
	ObjectOfCatalog.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Imported from file %1.%2.';"),
		ObjectOfCatalog.FileName,
		CurrentSessionDate());
	
	ValueToFormAttribute(ObjectOfCatalog, "Object");
	
	Modified = True;
	SetVisibilityAvailability();
	
	Result.Imported1 = True;
	Result.AdditionalInformation = Information.AdditionalInformation;
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function AddInImportResult()
	
	Result = New Structure;
	Result.Insert("Imported1", False);
	Result.Insert("ErrorDescription", "");
	Result.Insert("ErrorInfo", Undefined);
	Result.Insert("AdditionalInformation", New Map);
	
	Return Result;
	
EndFunction

// Server logic of add-in update from the website.
&AtServer
Procedure UpdateCardAfterAddInUpdateFromPortal()
	
	Read();
	Modified = False;
	SetVisibilityAvailability();
	
EndProcedure

#EndRegion

#Region Presentation

&AtServer
Procedure SetVisibilityAvailability()
	
	CatalogObject = FormAttributeToValue("Object");
	IsNew = Object.Ref.IsEmpty();
	
	Items.Information.Visible = ValueIsFilled(Object.ErrorDescription);
	
	// WarningDisplayOnEditParameters
	DisplayWarning = WarningOnEditRepresentation.Show;
	NotDisplayWarning = WarningOnEditRepresentation.DontShow;
	If ValueIsFilled(Object.Description) Then
		Items.Description.WarningOnEditRepresentation = DisplayWarning;
	Else
		Items.Description.WarningOnEditRepresentation = NotDisplayWarning;
	EndIf;
	If ValueIsFilled(Object.Id) Then 
		Items.Id.WarningOnEditRepresentation = DisplayWarning;
	Else 
		Items.Id.WarningOnEditRepresentation = NotDisplayWarning;
	EndIf;
	If ValueIsFilled(Object.Version) Then 
		Items.Version.WarningOnEditRepresentation = DisplayWarning;
	Else 
		Items.Version.WarningOnEditRepresentation = NotDisplayWarning;
	EndIf;
	
	// 
	Items.FormSaveAs.Enabled = Not IsNew;
	
	// Dependence of using and automatic update.
	ComponentIsDisabled = (Object.Use = Enums.AddInUsageOptions.isDisabled);
	Items.UpdateFrom1CITSPortal.Enabled = Not ComponentIsDisabled And CatalogObject.ThisIsTheLatestVersionComponent();
	
	Items.PerformUpdateFrom1CITSPortal.Enabled = Object.UpdateFrom1CITSPortal;
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Function FileNameOnly(SelectedFileName)
	
	// It's crucial to use it on the client, as GetPathSeparator() on the server can be different.
	SubstringsArray = StrSplit(SelectedFileName, GetPathSeparator(), False);
	Return SubstringsArray.Get(SubstringsArray.UBound());
	
EndFunction

#EndRegion

#EndRegion