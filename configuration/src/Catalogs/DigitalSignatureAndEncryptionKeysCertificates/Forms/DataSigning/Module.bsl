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
Var InternalData, PasswordProperties, DataDetails, ObjectForm, ProcessingAfterWarning, CurrentPresentationsList;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DigitalSignatureInternal.SetPasswordEntryNote(ThisObject, ,
		Items.AdvancedPasswordNote.Name);
	
	DigitalSignatureInternal.SetSigningEncryptionDecryptionForm(ThisObject);
	
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationServer = Common.CommonModule("DSSCryptographyServiceConfirmationServer");
		
		ModuleCryptographyServiceDSSConfirmationServer.PrepareGroupConfirmation(ThisObject, "Signing",
				"SignAndCommentGroup",
				"GroupContainer",
				"GroupContainer1",
				"ConfirmationCommandsGroup");
		ModuleCryptographyServiceDSSConfirmationServer.ConfirmationWhenChangingCertificate(ThisObject, Certificate);
	EndIf;
	
	SetSignatureType(Parameters.SignatureType);
	
	If Not DigitalSignature.AvailableAdvancedSignature() Then
		SignatureType = Undefined;
		Items.SignatureType.Visible = False;
	EndIf;
	
	RefreshVisibilityWarnings();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If InternalData = Undefined Then
		Cancel = True;
	EndIf;
	
	If ValueIsFilled(DefaultFieldNameToActivate) Then
		CurrentItem = Items[DefaultFieldNameToActivate];
	EndIf;
	
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationWhenOpening(ThisObject, Cancel, ValueIsFilled(Password) And RememberPassword, DataDetails);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	ClearFormVariables();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") Then
		AttachIdleHandler("OnChangeCertificatesList", 0.1, True);
		
	ElsIf Upper(EventName) = Upper("ConfirmationToPerformTheMainOperation") And Source = UUID Then
		If Parameter.Completed2 Then
			PackageData = CommonClientServer.StructureProperty(Parameter, "PackageData");
			DigitalSignatureInternalClient.SetThePropertiesOfTheCloudSignature(DataDetails, New Structure("PackageData", PackageData));
			CloudSignatureProperties = DigitalSignatureInternalClient.GetThePropertiesOfACloudSignature(DataDetails);
			NotificationOnConfirmation = CloudSignatureProperties.NotificationOnConfirmation;
			
			If NotificationOnConfirmation = Undefined Then
				SignData(New NotifyDescription("SignCompletion", ThisObject));
			Else
				ExecuteNotifyProcessing(NotificationOnConfirmation, ThisObject);
			EndIf;
		Else
			Items.Sign.Visible = True;
			Items.Sign.DefaultButton = True;
		EndIf;
		
	ElsIf Upper(EventName) = Upper("ConfirmationAuthorization") And Source = UUID Then
		DigitalSignatureInternalClient.GetCertificatesThumbprintsAtClient(
			New NotifyDescription("CertificateChoiceProcessingCompletion", ThisObject));
	
	ElsIf Upper(EventName) = Upper("ConfirmationPrepareData") And Source = UUID Then
		DigitalSignatureInternalClient.GetDataForACloudSignature(
			Parameter.HandlerNext, Parameter.TheFormContext, 
			Parameter.DataDetails, Parameter.Data, True);
	
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChoosingAuthorizationLetterWhenChanging(Item)
	
	Items.GroupPages.CurrentPage = ?(ByAuthorizationLetter, Items.AuthorizationLetterSelectionPage,
		Items.PageWithoutAuthorizationLetter);
	
	If Not ByAuthorizationLetter Then
		MachineReadableAuthorizationLetter = Undefined;
	Else
		AttachIdleHandler("Attachable_PickUpAuthorizationLetter", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureInternalClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, CurrentPresentationsList);
	
EndProcedure

&AtClient
Procedure CertificateOnChange(Item)
	
	DigitalSignatureInternalClient.GetCertificatesThumbprintsAtClient(
		New NotifyDescription("CertificateOnChangeCompletion", ThisObject));
	
EndProcedure

// Continues the CertificateOnChange procedure.
&AtClient
Procedure CertificateOnChangeCompletion(CertificatesThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificatesThumbprintsAtClient);
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties, New Structure("OnOpen", True));
	
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.CheckForCertificateError(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.FilterListOfMethods(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationOnChange(ThisObject, Items.Certificate, DataDetails, PasswordProperties.Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(CertificatesFilter) = Type("ValueList") And CertificatesFilter.Count() > 0 Then
		DigitalSignatureInternalClient.StartChooseCertificateAtSetFilter(ThisObject);
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SelectedCertificate", Certificate);
	FormParameters.Insert("ToEncryptAndDecrypt", False);
	FormParameters.Insert("ReturnPassword", True);
	If TypeOf(CertificatesFilter) <> Type("ValueList") Then
		FormParameters.Insert("FilterByCompany", CertificatesFilter);
	EndIf;
	FormParameters.Insert("ExecuteAtServer", ExecuteAtServer);
	
	DigitalSignatureInternalClient.SelectSigningOrDecryptionCertificate(FormParameters, Item);
	
EndProcedure

&AtClient
Procedure CertificateOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Certificate) Then
		DigitalSignatureClient.OpenCertificate(Certificate);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = True Then
		Certificate = InternalData["SelectedCertificate"];
		InternalData.Delete("SelectedCertificate");
	Else
		Certificate = ValueSelected;
	EndIf;
	
	DigitalSignatureInternalClient.GetCertificatesThumbprintsAtClient(
		New NotifyDescription("CertificateChoiceProcessingCompletion", ThisObject, ValueSelected));
	
EndProcedure

// Continues the CertificateChoiceProcessing procedure.
&AtClient
Procedure CertificateChoiceProcessingCompletion(CertificatesThumbprintsAtClient, ValueSelected) Export
	
	CertificateOnChangeAtServer(CertificatesThumbprintsAtClient);
	
	If ValueSelected = True
	   And InternalData["SelectedCertificatePassword"] <> Undefined Then
		
		DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
			InternalData, PasswordProperties,, InternalData["SelectedCertificatePassword"]);
		InternalData.Delete("SelectedCertificatePassword");
	Else
		DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	EndIf;
	
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationOnChange(ThisObject, Items.Certificate, DataDetails, PasswordProperties.Value);
		ModuleCryptographyServiceDSSConfirmationClient.CheckForCertificateError(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.FilterListOfMethods(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateAutoComplete(Item, Text, ChoiceData, Var_Parameters, Waiting, StandardProcessing)
	
	DigitalSignatureInternalClient.CertificatePickupFromSelectionList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificateTextEditEnd(Item, Text, ChoiceData, Var_Parameters, StandardProcessing)
	
	DigitalSignatureInternalClient.CertificatePickupFromSelectionList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("OnChangeAttributePassword", True));
	
EndProcedure

&AtClient
Procedure RememberPasswordOnChange(Item)
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("OnChangeAttributeRememberPassword", True));
	
EndProcedure

&AtClient
Procedure SpecifiedPasswordNoteClick(Item)
	
	DigitalSignatureInternalClient.SpecifiedPasswordNoteClick(ThisObject, Item, PasswordProperties);
	
EndProcedure

&AtClient
Procedure SpecifiedPasswordNoteExtendedTooltipURLProcessing(Item, Var_URL, StandardProcessing)
	
	DigitalSignatureInternalClient.SpecifiedPasswordNoteURLProcessing(
		ThisObject, Item, Var_URL, StandardProcessing, PasswordProperties);
	
EndProcedure

&AtClient
Procedure SignatureTypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Sign(Command)
	
	DataDetails.Insert("UserClickedSignButton", True);
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If DigitalSignatureInternalClient.ThisIsACloudSignatureOperation(ThisObject) Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		If ModuleCryptographyServiceDSSConfirmationClient.CheckingBeforePerformingOperation(ThisObject, PasswordProperties.Value) Then 
			ModuleCryptographyServiceDSSConfirmationClient.PerformInitialServiceOperation(ThisObject, DataDetails, PasswordProperties.Value);
		EndIf;
	Else
		If Not Items.Sign.Enabled Then
			Return;
		EndIf;
		
		Items.Sign.Enabled = False;
		
		SignData(New NotifyDescription("SignCompletion", ThisObject));
		
	EndIf;
	
EndProcedure

// Continues the Sign procedure.
&AtClient
Procedure SignCompletion(Result, Context) Export
	
	Items.Sign.Enabled = True;
	
	If Result = True Then
		Close(True);
	ElsIf DigitalSignatureInternalClient.ThisIsACloudSignatureOperation(ThisObject) Then
		Items.Sign.Visible = True;
		Items.Sign.DefaultButton = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetSignatureType(Val ParameterSignatureType)
	
	If Not TypeOf(ParameterSignatureType) = Type("Structure") Then
		
		NewParameterSignatureType = New Structure;
		NewParameterSignatureType.Insert("SignatureTypes", New Array);
		NewParameterSignatureType.Insert("Visible", False);
		NewParameterSignatureType.Insert("Enabled", False);
		NewParameterSignatureType.Insert("ChoosingAuthorizationLetter", False);
		If ValueIsFilled(ParameterSignatureType) Then
			NewParameterSignatureType.SignatureTypes.Add(ParameterSignatureType);
		EndIf;
		ParameterSignatureType = NewParameterSignatureType;
		
	EndIf;
	
	If ParameterSignatureType.SignatureTypes.Count() = 0 Then
		
		TypesList = New ValueList;
		DigitalSignatureInternal.FillListSignatureTypesCryptography(TypesList, "Signing",
			Constants.CryptoSignatureTypeDefault.Get());
		For Each Item In TypesList Do
			ParameterSignatureType.SignatureTypes.Add(Item.Value);
		EndDo;
		
		ParameterSignatureType.Enabled = ParameterSignatureType.SignatureTypes.Count() <> 1;
		ParameterSignatureType.Visible = ParameterSignatureType.SignatureTypes.Count() <> 1;
		
	EndIf;
	
	Items.SignatureType.ChoiceList.Clear();
	Items.SignatureType.ChoiceList.LoadValues(ParameterSignatureType.SignatureTypes);
	
	SignatureType = ParameterSignatureType.SignatureTypes[0];
	
	Items.SignatureType.Visible = ParameterSignatureType.Visible;
	Items.SignatureType.Enabled = ParameterSignatureType.Enabled;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadablePowersAttorney") Then
		Items.PowerOfAttorneyGroup.Visible = ParameterSignatureType.ChoosingAuthorizationLetter;
		If ParameterSignatureType.ChoosingAuthorizationLetter Then
			Items.GroupPages.CurrentPage = ?(ByAuthorizationLetter, Items.AuthorizationLetterSelectionPage,
				Items.PageWithoutAuthorizationLetter);
			If ByAuthorizationLetter Then
				PickUpAuthorizationLetter();
			EndIf;
		EndIf;
	Else
		Items.PowerOfAttorneyGroup.Visible = False;
	EndIf;
	
	If Items.SignatureType.Visible Then
		TypesList = New ValueList;
		DigitalSignatureInternal.FillListSignatureTypesCryptography(TypesList);
		
		ToolTipText = New Array;
		For Each ListItem In Items.SignatureType.ChoiceList Do
			Found4 = TypesList.FindByValue(ListItem.Value);
			If Found4 <> Undefined Then
				ToolTipText.Add(Found4.Presentation);
			EndIf;
		EndDo;
		
		Items.SignatureType.ExtendedTooltip.Title = StrConcat(ToolTipText, Chars.LF);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ErrorCertificateMarkedAsRevoked()
	
	Return DigitalSignatureInternal.ErrorCertificateMarkedAsRevoked()
	
EndFunction

&AtClient
Procedure ContinueOpening(Notification, CommonInternalData, ClientParameters) Export
	
	If ClientParameters = InternalData Then
		ClientParameters = New Structure("Certificate, PasswordProperties", Certificate, PasswordProperties);
		Return;
	EndIf;
	
	If ClientParameters.Property("SpecifiedContextOfOtherOperation") Then
		CertificateProperties = CommonInternalData;
		ClientParameters.DataDetails.OperationContext.ContinueOpening(Undefined, Undefined, CertificateProperties);
		If CertificateProperties.Certificate = Certificate Then
			PasswordProperties = CertificateProperties.PasswordProperties;
		EndIf;
	EndIf;
	
	DataDetails             = ClientParameters.DataDetails;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	InternalData = CommonInternalData;
	Context = New Structure("Notification", Notification);
	Notification = New NotifyDescription("ContinueOpening", ThisObject);
	
	DigitalSignatureInternalClient.ContinueOpeningStart(New NotifyDescription(
		"ContinueOpeningAfterStart", ThisObject, Context), ThisObject, ClientParameters);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterStart(Result, Context) Export
	
	If Result <> True Then
		ContinueOpeningCompletion(Context);
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("OnOpen", True);
	If PasswordProperties <> Undefined Then
		AdditionalParameters.Insert("OnSetPasswordFromAnotherOperation", True);
	EndIf;
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, AdditionalParameters);
	
	ModuleCryptographyServiceDSSConfirmationClient = Undefined;
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
	EndIf;
	
	If NoConfirmation
	   And (    AdditionalParameters.PasswordSpecified1
	      Or AdditionalParameters.EnterPasswordInDigitalSignatureApplication
	      Or CloudPasswordConfirmed) Then
		
		If ModuleCryptographyServiceDSSConfirmationClient <> Undefined Then
			If Not ModuleCryptographyServiceDSSConfirmationClient.CloudSignatureRequiresConfirmation(ThisObject, AdditionalParameters.PasswordSpecified1) Then
				ProcessingAfterWarning = Undefined;
				SignData(New NotifyDescription("ContinueOpeningAfterSignData", ThisObject, Context));
				Return;
			EndIf;
		Else	
			ProcessingAfterWarning = Undefined;
			SignData(New NotifyDescription("ContinueOpeningAfterSignData", ThisObject, Context));
			Return;
		EndIf;	
	EndIf;
	
	Open();
	
	If ModuleCryptographyServiceDSSConfirmationClient <> Undefined Then
		If ModuleCryptographyServiceDSSConfirmationClient.CheckingExecutionOfInitialOperation(ThisObject, NoConfirmation And AdditionalParameters.PasswordSpecified1) Then 
			ModuleCryptographyServiceDSSConfirmationClient.PerformInitialServiceOperation(ThisObject, DataDetails, PasswordProperties.Value);
		EndIf;
	EndIf;	
	
	ContinueOpeningCompletion(Context);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterSignData(Result, Context) Export
	
	ContinueOpeningCompletion(Context, Result = True);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningCompletion(Context, Result = Undefined)
	
	If Not IsOpen() Then
		ClearFormVariables();
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, Result);
	
EndProcedure

&AtServer
Procedure RefreshVisibilityWarnings()
	
	Items.GroupRecalled.Visible = CertificateRevoked;
	
	If ValueIsFilled(CertificationAuthorityAuditResult) Then
		Items.AdditionalDataGroup.Visible = Not CertificateRevoked And ValueIsFilled(
			CertificationAuthorityAuditResult.Warning.AdditionalInfo);
		Items.DecorationAdditionalInformation.Title =
			CertificationAuthorityAuditResult.Warning.AdditionalInfo;
	Else
		Items.AdditionalDataGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearFormVariables()
	
	DataDetails             = Undefined;
	ObjectForm               = Undefined;
	CurrentPresentationsList = Undefined;
	
EndProcedure

&AtClient
Function VariablesCleared()
	
	Return DataDetails = Undefined
		And ObjectForm = Undefined
		And CurrentPresentationsList = Undefined;
	
EndFunction

// CAC:78-off: to securely pass data between forms on the client without sending them to the server.
&AtClient
Procedure PerformSigning(ClientParameters, CompletionProcessing) Export
// ACC:78-
	
	DigitalSignatureInternalClient.RefreshFormBeforeSecondUse(ThisObject, ClientParameters);
	
	DataDetails             = ClientParameters.DataDetails;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	ProcessingAfterWarning = CompletionProcessing;
	
	Context = New Structure("CompletionProcessing", CompletionProcessing);
	SignData(New NotifyDescription("PerformSigningCompletion", ThisObject, Context));
	
EndProcedure

// Continues the ExecuteSigning procedure.
&AtClient
Procedure PerformSigningCompletion(Result, Context) Export
	
	ExecuteNotifyProcessing(Context.CompletionProcessing, Result);
	
EndProcedure

&AtClient
Procedure OnChangeCertificatesList()
	
	DigitalSignatureInternalClient.GetCertificatesThumbprintsAtClient(
		New NotifyDescription("OnChangeCertificatesListCompletion", ThisObject));
	
EndProcedure

// Continues the OnChangeCertificatesList procedure.
&AtClient
Procedure OnChangeCertificatesListCompletion(CertificatesThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificatesThumbprintsAtClient, True);
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("OnChangeCertificateProperties", True));
	
EndProcedure

&AtServer
Procedure CertificateOnChangeAtServer(CertificatesThumbprintsAtClient, CheckRef = False)
	
	If CheckRef
	   And ValueIsFilled(Certificate)
	   And Common.ObjectAttributeValue(Certificate, "Ref") <> Certificate Then
		
		Certificate = Undefined;
	EndIf;
	
	DigitalSignatureInternal.CertificateOnChangeAtServer(ThisObject, CertificatesThumbprintsAtClient);
	
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationServer = Common.CommonModule("DSSCryptographyServiceConfirmationServer");
		ModuleCryptographyServiceDSSConfirmationServer.ConfirmationWhenChangingCertificate(ThisObject, Certificate);
	EndIf;
	
	If ByAuthorizationLetter Then
		PickUpAuthorizationLetter();
	EndIf;
	
	RefreshVisibilityWarnings();
	
EndProcedure

&AtClient
Procedure Attachable_PickUpAuthorizationLetter()
	PickUpAuthorizationLetter()
EndProcedure

&AtServer
Procedure PickUpAuthorizationLetter()
	
	If Not Common.SubsystemExists("StandardSubsystems.MachineReadablePowersAttorney") Then
		Return;
	EndIf;
		
	MachineReadableAuthorizationLetter = Undefined;
	Items.MachineReadableAuthorizationLetter.ChoiceList.Clear();
	Items.MachineReadableAuthorizationLetter.ListChoiceMode = False;
	
	ModuleMachineReadableAuthorizationLettersOfFederalTaxService = Common.CommonModule("MachineReadableAuthorizationLettersOfFederalTaxService");
	CryptoCertificate = New CryptoCertificate(GetFromTempStorage(AddressOfCertificate));
	SelectionForAuthorizationLettersByCertificate = ModuleMachineReadableAuthorizationLettersOfFederalTaxService.SelectionForAuthorizationLettersByCertificate(CryptoCertificate);
	SelectedFields = New Array;
	SelectedFields.Add("MachineReadableAuthorizationLetter");
	SelectedFields.Add("Presentation");
	SelectedFields.Add("DateOfIssue1");
	LettersOfAuthority = ModuleMachineReadableAuthorizationLettersOfFederalTaxService.AuthorizationLettersWithSelection(SelectionForAuthorizationLettersByCertificate, SelectedFields);
	
	If LettersOfAuthority.Count() > 0 Then
		Items.MachineReadableAuthorizationLetter.ListChoiceMode = True;
		Items.MachineReadableAuthorizationLetter.ChoiceList.Clear();
		For Each String In LettersOfAuthority Do
			Items.MachineReadableAuthorizationLetter.ChoiceList.Add(String.MachineReadableAuthorizationLetter,
				StrTemplate("%1, %2", String.Presentation, Format(String.DateOfIssue1, "DLF=D")));
		EndDo;
		MachineReadableAuthorizationLetter = Items.MachineReadableAuthorizationLetter.ChoiceList[0].Value;
	EndIf;

EndProcedure

&AtClient
Procedure SignData(Notification)
	
	DataDetails.Insert("SignatureType", SignatureType);
	
	If DigitalSignatureInternalClient.ThisIsACloudSignatureOperation(ThisObject) Then
		DigitalSignatureInternalClient.SetThePropertiesOfTheCloudSignature(DataDetails,
			New Structure("Account, ConfirmationData", 
					DigitalSignatureInternalClient.GetDataCloudSignature(ThisObject, "UserSettings"),
					DigitalSignatureInternalClient.GetDataCloudSignature(ThisObject, "ConfirmationData")));
	Else	
		DigitalSignatureInternalClient.SetThePropertiesOfTheCloudSignature(DataDetails,
			New Structure("Account, ConfirmationData"));
	EndIf;	
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorAtClient", New Structure);
	Context.Insert("ErrorAtServer", New Structure);
	
	If CertificateExpiresOn < CommonClient.SessionDate() Then
		Context.ErrorAtClient.Insert("ErrorDescription",
			NStr("en = 'The selected certificate has expired.
			           |Select a different certificate.';"));
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer);
		Return;
	EndIf;

	If CertificateRevoked Then
		Context.ErrorAtClient.Insert("ErrorDescription",
			NStr("en = 'The certificate is marked in the application as revoked.
			|Please select another certificate.';"));
		AdditionalErrorData = New Structure("AdditionalDataChecksOnClient", ErrorCertificateMarkedAsRevoked());
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer,,AdditionalErrorData);
		Return;
	EndIf;
	
	If ValueIsFilled(CertificationAuthorityAuditResult)
		And Not CertificationAuthorityAuditResult.Valid_SSLyf Then
			
		SigningAllowed = CommonServerCall.CommonSettingsStorageLoad(
			Certificate, "AllowSigning", Undefined);
		
		If SigningAllowed = Undefined Then
			Notification = New NotifyDescription("SignDataAfterCAQuestionAnswered", ThisObject, Context);
			
			QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
			QuestionParameters.Picture = PictureLib.Warning32;
			QuestionParameters.Title = NStr("en = 'Request for permission to sign';");
			QuestionParameters.CheckBoxText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Remember my choice for certificate ""%1""';"), Certificate);
			
			Buttons = New ValueList;
			Buttons.Add(True, NStr("en = 'Allow signing';"));
			Buttons.Add(False,   NStr("en = 'Cancel signing';"));
			
			ErrorWarning = CertificationAuthorityAuditResult.Warning; // See DigitalSignatureInternalClientServer.WarningWhileVerifyingCertificateAuthorityCertificate
			StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorWarning.ErrorText, Buttons, QuestionParameters);
			Return;
		EndIf;
		
		SignDataAfterCAQuestionAnswered(SigningAllowed, Context);
		Return;
	EndIf;
	
	SignDataAfterCAQuestionAnswered(True, Context);
	
EndProcedure

// Continue the sign Data procedure.
&AtClient
Procedure SignDataAfterCAQuestionAnswered(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		NeverAskAgain = Result.NeverAskAgain;
		Result = Result.Value;
		
		If NeverAskAgain Then
			CommonServerCall.CommonSettingsStorageSave(
				Certificate, "AllowSigning", Result);
		EndIf;
		
	EndIf;
	
	If Result = Undefined Or Not Result Then
		ErrorWarning = CertificationAuthorityAuditResult.Warning; // See DigitalSignatureInternalClientServer.WarningWhileVerifyingCertificateAuthorityCertificate
		Context.ErrorAtClient.Insert("ErrorDescription", ErrorWarning.ErrorText);
		AdditionalErrorData = New Structure("AdditionalDataChecksOnClient", ErrorWarning);
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer, ,
			AdditionalErrorData);
		Return;
	EndIf;
	
	AdditionalInspectionParameters = DigitalSignatureInternalClient.AdditionalCertificateVerificationParameters();
	AdditionalInspectionParameters.ShowError = False;
	AdditionalInspectionParameters.ToVerifySignature = True;
	AdditionalInspectionParameters.MergeCertificateDataErrors = False;
	AdditionalInspectionParameters.PerformCAVerification = False;

	DigitalSignatureInternalClient.CheckCertificate(New NotifyDescription(
			"SignDataAfterSelectedCertificateVerified", ThisObject, Context),
		AddressOfCertificate,,, AdditionalInspectionParameters);
	
EndProcedure

// Continue the sign Data procedure.
&AtClient
Procedure SignDataAfterSelectedCertificateVerified(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then // 
		
		If Result.CertificateRevoked Then
			Context.ErrorAtClient.Insert("ErrorDescription", NStr("en = 'The certificate is revoked.
																	 |Select another certificate.';"));
			AdditionalErrorData = New Structure("AdditionalDataChecksOnClient",
				ErrorCertificateMarkedAsRevoked());
			HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer, ,
				AdditionalErrorData);
			Return;
		EndIf;
		
		Context.Insert("CertificateValid", False);
		Context.Insert("IsVerificationRequired", Result.IsVerificationRequired);
		
		Notification = New NotifyDescription("SignDataAfterInvalidSignatureWarning", ThisObject,
			New Structure("Context, CertificateVerificationResult", Context, Result));
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.Picture = PictureLib.Warning32;
		QuestionParameters.Title = NStr("en = 'The signature will be invalid';");
		QuestionParameters.PromptDontAskAgain = False;
		
		Buttons = New ValueList;
		Buttons.Add("CancelSigning",  NStr("en = 'Cancel signing';"));
		Buttons.Add("AllowSigning", NStr("en = 'Allow signing';"));
		Buttons.Add("ShowError",      NStr("en = 'Details...';"));
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The certificate has failed verification. A signature created by this certificate will be invalid.
				|
				|%1';"), DigitalSignatureInternalClientServer.GeneralDescriptionOfTheError(
			Result.ErrorDetailsAtClient, Result.ErrorDescriptionAtServer, Undefined));
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorText, Buttons, QuestionParameters);
		Return;
		
	EndIf;
	
	Context.Insert("CertificateValid",   True);
	Context.Insert("IsVerificationRequired", False);
	SignDataAfterInvalidSignatureWarning(New Structure("Value", "AllowSigning"), 
		New Structure("Context", Context));
	
EndProcedure

// Continue the sign Data procedure.
&AtClient
Procedure SignDataAfterInvalidSignatureWarning(Result, AdditionalParameters) Export
	
	Context = AdditionalParameters.Context;

	If Result = Undefined Or Result.Value = "CancelSigning" Or Result.Value = "ShowError" Then
		
		If ValueIsFilled(AdditionalParameters.CertificateVerificationResult.ErrorDetailsAtClient) Then
			Context.ErrorAtClient.Insert("ErrorDescription", AdditionalParameters.CertificateVerificationResult.ErrorDetailsAtClient);
		EndIf;
		If ValueIsFilled(AdditionalParameters.CertificateVerificationResult.ErrorDescriptionAtServer) Then
			Context.ErrorAtServer.Insert("ErrorDescription", AdditionalParameters.CertificateVerificationResult.ErrorDescriptionAtServer);
		EndIf;
		
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer,,,Result.Value = "ShowError");
		Return;
	
	EndIf;
		
	SelectedCertificate = New Structure;
	SelectedCertificate.Insert("Ref",    Certificate);
	SelectedCertificate.Insert("Thumbprint", ThumbprintOfCertificate);
	SelectedCertificate.Insert("Data",    AddressOfCertificate);
	DataDetails.Insert("SelectedCertificate",   SelectedCertificate);
	DataDetails.Insert("SelectedAuthorizationLetter", MachineReadableAuthorizationLetter);
	
	If DataDetails.Property("BeforeExecute")
	   And TypeOf(DataDetails.BeforeExecute) = Type("NotifyDescription") Then
		
		ExecutionParameters = New Structure;
		ExecutionParameters.Insert("DataDetails", DataDetails);
		ExecutionParameters.Insert("Notification", New NotifyDescription(
			"SignDataAfterProcesssingBeforeExecute", ThisObject, Context));
		
		ExecuteNotifyProcessing(DataDetails.BeforeExecute, ExecutionParameters);
	Else
		SignDataAfterProcesssingBeforeExecute(New Structure, Context);
	EndIf;
	
EndProcedure

// Continues the SignData procedure.
&AtClient
Procedure SignDataAfterProcesssingBeforeExecute(Result, Context) Export
	
	If VariablesCleared() Then
		Return;
	EndIf;
	
	If Result.Property("ErrorDescription") Then
		HandleError(Context.Notification, New Structure("ErrorDescription", Result.ErrorDescription), New Structure);
		Return;
	EndIf;
	
	Context.Insert("FormIdentifier", UUID);
	If TypeOf(ObjectForm) = Type("ClientApplicationForm") Then
		Context.FormIdentifier = ObjectForm.UUID;
	ElsIf TypeOf(ObjectForm) = Type("UUID") Then
		Context.FormIdentifier = ObjectForm;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("DataDetails",     DataDetails);
	ExecutionParameters.Insert("Form",              ThisObject);
	ExecutionParameters.Insert("FormIdentifier", Context.FormIdentifier);
	ExecutionParameters.Insert("PasswordValue",     PasswordProperties.Value);
	ExecutionParameters.Insert("AddressOfCertificate",    AddressOfCertificate);
	ExecutionParameters.Insert("CertificateValid",    Context.CertificateValid);
	ExecutionParameters.Insert("IsVerificationRequired",  Context.IsVerificationRequired);
	
	ExecutionParameters.Insert("FullDataPresentation",
		DigitalSignatureInternalClient.FullDataPresentation(ThisObject));
	ExecutionParameters.Insert("CurrentPresentationsList", CurrentPresentationsList);
	
	Context.Insert("ExecutionParameters", ExecutionParameters);
	
	If DigitalSignatureClient.GenerateDigitalSignaturesAtServer()
	   And ExecuteAtServer <> False Then
		
		If ValueIsFilled(CertificateAtServerErrorDescription) Then
			Result = New Structure("Error", CertificateAtServerErrorDescription);
			CertificateAtServerErrorDescription = New Structure;
			SignDataAfterExecutionAtServerSide(Result, Context);
		Else
			// 
			DigitalSignatureInternalClient.ExecuteAtSide(New NotifyDescription(
					"SignDataAfterExecutionAtServerSide", ThisObject, Context),
				"Signing", "AtServerSide", Context.ExecutionParameters);
		EndIf;
	Else
		SignDataAfterExecutionAtServerSide(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the SignData procedure.
&AtClient
Async Procedure SignDataAfterExecutionAtServerSide(Result, Context) Export
	
	If VariablesCleared() Then
		Return;
	EndIf;
	
	If Result <> Undefined Then
		SignDataAfterExecute(Result);
	EndIf;
	
	If Result <> Undefined And Not Result.Property("Error") Then
		SignDataAfterExecutionAtClientSide(New Structure, Context);
	Else
		If Result <> Undefined Then
			Context.ErrorAtServer = Result.Error;
			If ExecuteAtServer = True Then
				SignDataAfterExecutionAtClientSide(New Structure, Context);
				Return;
			EndIf;
		EndIf;
		
		// 
		DigitalSignatureInternalClient.ExecuteAtSide(New NotifyDescription(
				"SignDataAfterExecutionAtClientSide", ThisObject, Context),
			"Signing", "OnClientSide", Context.ExecutionParameters);
	EndIf;
	
EndProcedure

// Continues the SignData procedure.
&AtClient
Procedure SignDataAfterExecutionAtClientSide(Result, Context) Export
	
	If VariablesCleared() Then
		Return;
	EndIf;
	
	SignDataAfterExecute(Result);
	
	If Result.Property("Error") Then
		
		If DataDetails.Property("OperationContext") Then
			DataDetails.OperationContext = ThisObject;
		EndIf;
		
		Context.ErrorAtClient = Result.Error;
		UnsignedData = DigitalSignatureInternalClient.CurrentDataItemProperties(
			Context.ExecutionParameters);
			
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer, UnsignedData);
		Return;
		
	EndIf;
	
	If ValueIsFilled(DataPresentation)
	   And (Not DataDetails.Property("NotifyOnCompletion")
	      Or DataDetails.NotifyOnCompletion <> False) Then
		
		DigitalSignatureClient.ObjectSigningInfo(
			DigitalSignatureInternalClient.FullDataPresentation(ThisObject),
			CurrentPresentationsList.Count() > 1);
	EndIf;
	
	If DataDetails.Property("OperationContext") Then
		DataDetails.OperationContext = ThisObject;
	EndIf;
	
	If NotifyOfCertificateAboutToExpire Then
		FormOpenParameters = New Structure("Certificate", Certificate);
		ActionOnClick = New NotifyDescription("OpenNotificationFormNeedReplaceCertificate",
			DigitalSignatureInternalClient, FormOpenParameters);
		
		ShowUserNotification(
			NStr("en = 'You need to reissue the certificate';"), ActionOnClick, Certificate,
			PictureLib.Warning32, UserNotificationStatus.Important,
			Certificate);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

// Continues the SignData procedure.
&AtClient
Procedure SignDataAfterExecute(Result)
	
	If Result.Property("OperationStarted") Then
		DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject, InternalData,
			PasswordProperties, New Structure("OnOperationSuccess", True));
	EndIf;
	
	If Result.Property("HasProcessedDataItems") Then
		// 
		// 
		Items.Certificate.ReadOnly = True;
		Items.Comment.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure HandleError(Notification, ErrorAtClient, ErrorAtServer, UnsignedData = Undefined, AdditionalData = Undefined, ShowError_ = True)
	
	If DataDetails.Property("StopExecution") Then
		
		If ShowError_ Then
			
			If Not DataDetails.Property("ErrorDescription") Then
				DataDetails.Insert("ErrorDescription");
			EndIf;
		
		DataDetails.ErrorDescription = DigitalSignatureInternalClientServer.GeneralDescriptionOfTheError(
			ErrorAtClient, ErrorAtServer, NStr("en = 'Cannot sign documents due to:';"));

		EndIf;
		
		If IsOpen() Then
			Close(False);
		Else
			ExecuteNotifyProcessing(Notification, False);
		EndIf;
		
	Else
		
		If Not IsOpen() And ProcessingAfterWarning = Undefined Then
			Open();
		EndIf;
		
		If ShowError_ Then
			AdditionalParameters = New Structure;
			If ValueIsFilled(AdditionalData) Then
				For Each KeyAndValue In AdditionalData Do
					AdditionalParameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
				EndDo;
			EndIf;
			If UnsignedData <> Undefined Then
				AdditionalParameters.Insert("UnsignedData", UnsignedData);
			EndIf;
			AdditionalParameters.Insert("Certificate", Certificate);
			
			DigitalSignatureInternalClient.ShowApplicationCallError(
				NStr("en = 'Cannot sign documents';"), "", 
				ErrorAtClient, ErrorAtServer, AdditionalParameters, ProcessingAfterWarning);
		EndIf;
			
		ExecuteNotifyProcessing(Notification, False);
		
	EndIf;
	
EndProcedure


#EndRegion