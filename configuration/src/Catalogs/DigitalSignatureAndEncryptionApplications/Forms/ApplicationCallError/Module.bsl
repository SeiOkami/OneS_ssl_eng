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
	
	Items.SupportInformation.Title = DigitalSignatureInternal.InfoHeadingForSupport();
	
	DigitalSignatureInternal.ToSetTheTitleOfTheBug(ThisObject,
		Parameters.FormCaption);
	
	IsFullUser = Users.IsFullUser(,, False);
	
	ErrorAtClient = Parameters.ErrorAtClient;
	ErrorAtServer = Parameters.ErrorAtServer;
	
	AddErrors(ErrorAtClient);
	AddErrors(ErrorAtServer, True);
	
	Items.ErrorsPicture.Visible =
		  Errors.FindRows(New Structure("ErrorAtServer", False)).Count() <> 0
		And Errors.FindRows(New Structure("ErrorAtServer", True)).Count() <> 0;
	
	Items.Errors.HeightInTableRows = Min(Errors.Count(), 3);
	
	ErrorDescription = DigitalSignatureInternalClientServer.GeneralDescriptionOfTheError(
		ErrorAtClient, ErrorAtServer);
	
	ShowInstruction                = Parameters.ShowInstruction;
	ShowOpenApplicationsSettings = Parameters.ShowOpenApplicationsSettings;
	ShowExtensionInstallation       = Parameters.ShowExtensionInstallation;
	
	DetermineCapabilities(ShowInstruction, ShowOpenApplicationsSettings, ShowExtensionInstallation,
		ErrorAtClient, IsFullUser);
	
	DetermineCapabilities(ShowInstruction, ShowOpenApplicationsSettings, ShowExtensionInstallation,
		ErrorAtServer, IsFullUser);
	
	If Not ShowInstruction Then
		Items.Instruction.Visible = False;
	EndIf;
	
	ShowExtensionInstallation = ShowExtensionInstallation And Not Parameters.ExtensionAttached;
	
	If Not ShowExtensionInstallation Then
		Items.FormInstallExtension.Visible = False;
	EndIf;
	
	If Not ShowOpenApplicationsSettings Then
		Items.FormOpenApplicationsSettings.Visible = False;
	EndIf;
	
	AdditionalData = Parameters.AdditionalData;
	
	If ValueIsFilled(AdditionalData)
	   And TypeOf(AdditionalData.UnsignedData) = Type("Structure") Then
		
		DigitalSignatureInternal.RegisterDataSigningInLog(
			AdditionalData.UnsignedData, ErrorDescription);
		
		AdditionalData.UnsignedData = Undefined;
	EndIf;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Errors.Count() = 1
	 Or Errors.Count() = 2
	   And Errors[0].ErrorAtServer <> Errors[1].ErrorAtServer Then
		
		Cancel = True;
		
		Notification = New NotifyDescription("OnOpenFollowUp", ThisObject);
		StandardSubsystemsClient.StartProcessingNotification(Notification);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SupportInformationURLProcessing(Item, Var_URL, StandardProcessing)
	
	StandardProcessing = False;
	
	If Var_URL = "TypicalIssues" Then
		DigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications();
	Else
	
		ErrorsText = "";
		FilesDetails = New Array;
		If ValueIsFilled(AdditionalData) Then
			DigitalSignatureInternalServerCall.AddADescriptionOfAdditionalData(
				AdditionalData, FilesDetails, ErrorsText);
		EndIf;
		
		ErrorsText = ErrorsText + ErrorDescription;
		DigitalSignatureInternalClient.GenerateTechnicalInformation(ErrorsText, , FilesDetails);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ErrorsFormTableItemEventHandlers

&AtClient
Procedure ErrorsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Field = Items.ErrorsDetails Then
		
		CurrentData = Items.Errors.CurrentData;
		
		ErrorParameters = New Structure;
		ErrorParameters.Insert("WarningTitle", Title);
		ErrorParameters.Insert(?(CurrentData.ErrorAtServer,
			"ErrorTextServer", "ErrorTextClient"), CurrentData.DetailsWithTitle);
			
		If ValueIsFilled(AdditionalData) Then
			ErrorParameters.Insert("AdditionalData", AdditionalData);
		EndIf;
		
		OpenForm("CommonForm.ExtendedErrorPresentation", ErrorParameters, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenApplicationsSettings(Command)
	
	Close();
	DigitalSignatureClient.OpenDigitalSignatureAndEncryptionSettings("Programs");
	
EndProcedure

&AtClient
Procedure InstallExtension(Command)
	
	DigitalSignatureClient.InstallExtension(True);
	Close();
	
EndProcedure

#EndRegion

#Region Private

// Continues the OnOpen procedure.
&AtClient
Procedure OnOpenFollowUp(Result, Context) Export
	
	ErrorParameters = New Structure;
	ErrorParameters.Insert("WarningTitle", Title);
	ErrorParameters.Insert(?(Errors[0].ErrorAtServer,
		"ErrorTextServer", "ErrorTextClient"), Errors[0].DetailsWithTitle);
	
	If Errors.Count() > 1 Then
		ErrorParameters.Insert(?(Errors[1].ErrorAtServer,
			"ErrorTextServer", "ErrorTextClient"), Errors[1].DetailsWithTitle);
	EndIf;
	
	ErrorParameters.Insert("ShowNeedHelp", True);
	ErrorParameters.Insert("ShowInstruction", ShowInstruction);
	ErrorParameters.Insert("ShowOpenApplicationsSettings", ShowOpenApplicationsSettings);
	ErrorParameters.Insert("ShowExtensionInstallation", ShowExtensionInstallation);
	ErrorParameters.Insert("ErrorDescription", ErrorDescription);
	ErrorParameters.Insert("AdditionalData", AdditionalData);
	
	ContinuationHandler = OnCloseNotifyDescription;
	OnCloseNotifyDescription = Undefined;
	OpenForm("CommonForm.ExtendedErrorPresentation", ErrorParameters, ThisObject,,,, ContinuationHandler);
	
EndProcedure

&AtServer
Procedure DetermineCapabilities(Instruction, ApplicationsSetUp, Extension, Error, IsFullUser)
	
	DetermineCapabilitiesByProperties(Instruction, ApplicationsSetUp, Extension, Error, IsFullUser);
	
	If Not Error.Property("Errors")
		Or TypeOf(Error.Errors) <> Type("Array") Then
		
		Return;
	EndIf;
	
	For Each CurrentError In Error.Errors Do
		DetermineCapabilitiesByProperties(Instruction, ApplicationsSetUp,
			Extension, CurrentError, IsFullUser);
	EndDo;
	
EndProcedure

&AtServer
Procedure DetermineCapabilitiesByProperties(Instruction, ApplicationsSetUp, Extension, Error, IsFullUser)
	
	If Error.Property("ApplicationsSetUp")
		And Error.ApplicationsSetUp = True Then
		
		ApplicationsSetUp = IsFullUser
			Or Not Error.Property("ToAdministrator")
			Or Error.ToAdministrator <> True;
		
	EndIf;
	
	If Error.Property("Instruction")
		And Error.Instruction = True Then
		
		Instruction = True;
	EndIf;
	
	If Error.Property("NoExtension")
		And Error.NoExtension = True Then
		
		Extension = True;
	EndIf;
	
EndProcedure

// Parameters:
//   ErrorsDescription - FormDataCollection:
//   * Errors - Array of Structure
//   ErrorAtServer - Boolean
//
&AtServer
Procedure AddErrors(ErrorsDescription, ErrorAtServer = False)
	
	If Not ValueIsFilled(ErrorsDescription) Then
		Return;
	EndIf;
	
	If ErrorsDescription.Property("Errors")
		And TypeOf(ErrorsDescription.Errors) = Type("Array")
		And ErrorsDescription.Errors.Count() > 0 Then
		
		ErrorsProperties = ErrorsDescription.Errors; // Array of See DigitalSignatureInternalClientServer.NewErrorProperties
		For Each ErrorProperties In ErrorsProperties Do
			
			DetailsWithTitle = "";
			If ValueIsFilled(ErrorProperties.ErrorTitle) Then
				DetailsWithTitle = ErrorProperties.ErrorTitle + Chars.LF;
			ElsIf ValueIsFilled(ErrorsDescription.ErrorTitle) Then
				DetailsWithTitle = ErrorsDescription.ErrorTitle + Chars.LF;
			EndIf;
			LongDesc = "";
			If ValueIsFilled(ErrorProperties.Application) Then
				LongDesc = LongDesc + String(ErrorProperties.Application) + ":" + Chars.LF;
			EndIf;
			LongDesc = LongDesc + ErrorProperties.LongDesc;
			DetailsWithTitle = DetailsWithTitle + LongDesc;
			
			ErrorString = Errors.Add();
			ErrorString.Cause = LongDesc;
			ErrorString.DetailsWithTitle = DetailsWithTitle;
			ErrorString.MoreDetails = NStr("en = 'Details';") + "...";
			ErrorString.ErrorAtServer = ErrorAtServer;
			ErrorString.Picture = ?(ErrorAtServer,
				PictureLib.ComputerServer,
				PictureLib.ComputerClient);
			
		EndDo;
	Else
		ErrorString = Errors.Add();
		ErrorString.Cause = ErrorsDescription.ErrorDescription;
		ErrorString.DetailsWithTitle = ErrorsDescription.ErrorDescription;
		ErrorString.MoreDetails = NStr("en = 'Details';") + "...";
		ErrorString.ErrorAtServer = ErrorAtServer;
		ErrorString.Picture = ?(ErrorAtServer,
			PictureLib.ComputerServer,
			PictureLib.ComputerClient);
	EndIf;
	
EndProcedure

#EndRegion
