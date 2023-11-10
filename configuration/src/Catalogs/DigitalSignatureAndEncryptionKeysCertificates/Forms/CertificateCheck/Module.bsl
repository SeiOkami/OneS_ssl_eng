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
Var InternalData, ClientParameters, PasswordProperties, ContextExecutionParameters;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.SupportInformation.Title = DigitalSignatureInternal.InfoHeadingForSupport();
	
	DigitalSignatureInternal.SetPasswordEntryNote(
		ThisObject, , Items.AdvancedPasswordNote.Name);
	
	Certificate = Parameters.Certificate;
	CheckOnSelection = Parameters.CheckOnSelection;
	
	If ValueIsFilled(Parameters.FormCaption) Then
		AutoTitle = False;
		Title = Parameters.FormCaption;
	EndIf;
	
	If CheckOnSelection Then
		Items.FormClose.Title = NStr("en = 'Cancel';");
		Items.FormValidate.Title = NStr("en = 'Check and continue';");
	EndIf;
	
	EnterPassword = True;
	StandardChecks = True;
	MergeResults = ?(Parameters.MergeResults = "MergeByAnd"
		Or Parameters.MergeResults = "MergeByOr",
		Parameters.MergeResults, "DontMerge");
	
	If Parameters.CheckResult <> Undefined Then
		CheckCompleted = True;
		ChecksAtClient = Parameters.CheckResult.ChecksAtClient;
		ChecksAtServer = Parameters.CheckResult.ChecksAtServer;
		AdditionalDataChecksOnServer = CommonClientServer.StructureProperty(
			Parameters.CheckResult, "AdditionalDataChecksOnServer", New Structure);
		AdditionalDataChecksOnClient = CommonClientServer.StructureProperty(
			Parameters.CheckResult, "AdditionalDataChecksOnClient", New Structure);
	EndIf;
	
	Checks = New ValueTable;
	Checks.Columns.Add("Name",           New TypeDescription("String"));
	Checks.Columns.Add("Presentation", New TypeDescription("String"));
	Checks.Columns.Add("ToolTip",     New TypeDescription("String"));
	
	DigitalSignatureOverridable.OnCreateFormCertificateCheck(
		Parameters.Certificate, Checks, Parameters.AdditionalChecksParameters,
		StandardChecks, EnterPassword);
		
	For Each Validation In Checks Do
		
		Var_Group = FormGroupWithoutDisplay(
			"Group" + Validation.Name, Items.AdditionalChecksGroup);
		
		AddPicture(Validation.Name + "AtClientPicture", Var_Group);
		AddPicture(Validation.Name + "AtServerPicture", Var_Group);
		
		ResultAndDecisionGroup = FormGroupWithoutDisplay(
			Validation.Name + "ResultAndDecision", Var_Group,
			ChildFormItemsGroup.Vertical);
			
		Label = Items.Add(Validation.Name + "Label",
			Type("FormDecoration"), ResultAndDecisionGroup);
		Label.Title = Validation.Presentation;
		Label.ExtendedTooltip.Title = Validation.ToolTip;
		Label.SetAction("Click", "Attachable_LabelClick");
		
		AddItemsDescriptionsErrors(Validation.Name, ResultAndDecisionGroup);
		AddItemsDescriptionsErrors(Validation.Name, ResultAndDecisionGroup, True);
		
		FillPropertyValues(AdditionalChecks.Add(), Validation);
		
		If ChecksAtClient <> Undefined Then
			OutputCheckResult(Validation.Name);
		EndIf;
		
		If ChecksAtServer <> Undefined Then
			OutputCheckResult(Validation.Name, True);
		EndIf;
		
	EndDo;
	
	If Not StandardChecks Then
		
		If AdditionalChecks.Count() = 0 Then
			Raise
				NStr("en = 'Standard checks for checking the certificate are disabled,
				|at that additional checks are not specified.';");
		EndIf;
			
		Items.GeneralChecksGroup.Visible = False;
		Items.OperationsCheckGroup.Visible = False;
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "CustomChecks");
		
	Else
		
		For Each Validation In StandardChecks() Do
			Items[Validation + "ErrorClient"].Visible = False;
			Items[Validation + "DecisionClientLabel"].Visible = False;
			Items[Validation + "ErrorServer"].Visible = False;
			Items[Validation + "DecisionServerLabel"].Visible = False;
			Items[Validation + "Label"].Title =
				StandardItemTitle(Validation + "Label");
			
			If ChecksAtClient <> Undefined Then
				OutputCheckResult(Validation);
			EndIf;
			
			If ChecksAtServer <> Undefined Then
				OutputCheckResult(Validation, True);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	CertificateProperties = Common.ObjectAttributesValues(Certificate,
		"CertificateData, Application, EnterPasswordInDigitalSignatureApplication, Thumbprint, Revoked");
		
	Revoked = CertificateProperties.Revoked;
	
	Application = CertificateProperties.Application;
	CertificateAddress = PutToTempStorage(
		CertificateProperties.CertificateData.Get(), UUID);
	CertificateEnterPasswordInElectronicSignatureProgram = CertificateProperties.EnterPasswordInDigitalSignatureApplication;
	
	ThisServiceAccount = TypeOf(Application) = DigitalSignatureInternal.ServiceProgramTypeSignatures()
						And DigitalSignatureInternal.UseCloudSignatureService();
	IsBuiltInCryptoProvider = Application = DigitalSignatureInternal.BuiltinCryptoprovider();
	
	HaveServiceAccount = DigitalSignatureInternal.UseCloudSignatureService()
			And DigitalSignatureInternalServerCall.TheCloudSignatureServiceIsConfigured();
	HasBuiltinCryptoprovider = DigitalSignatureInternal.UseDigitalSignatureSaaS();
		
	If ThisServiceAccount Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		TheDSSCryptographyServiceModuleClientServer = Common.CommonModule("DSSCryptographyServiceClientServer");
		CertificateData = TheDSSCryptographyServiceModuleInternal.GetCertificateDataByFingerprint(
								TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(CertificateProperties.Thumbprint));
		If CertificateData = Undefined Or CertificateData.Account <> Application Then
			Raise TheDSSCryptographyServiceModuleInternal.GetErrorDescription(Undefined, "SomeoneElseSCertificate");
		EndIf;
		
		ModuleCryptographyServiceDSSConfirmationServer = Common.CommonModule("DSSCryptographyServiceConfirmationServer");
		ModuleCryptographyServiceDSSConfirmationServer.PrepareGroupConfirmation(ThisObject, "Validation", "", "");
		ModuleCryptographyServiceDSSConfirmationServer.ConfirmationWhenChangingCertificate(ThisObject, Certificate);
		
	ElsIf IsBuiltInCryptoProvider 
		Or (Not StandardChecks And Not EnterPassword) Then
		Items.PasswordEntryGroup.Visible = False;
		
	EndIf;
	
	RefreshVisibilityAtServer();
	
	If StandardChecks Then
		FirstCheckName = ?(Items.LegalCertificateGroup.Visible,
			"LegalCertificate", "CertificateExists");
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.AssistanceRequiredGroup.Behavior = UsualGroupBehavior.Collapsible;
	EndIf;
	Items.WarningDecoration.Visible = False;
	
	StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If InternalData = Undefined Then
		Cancel = True;
	EndIf;
	
	If ThisServiceAccount Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationWhenOpening(ThisObject, Cancel, ValueIsFilled(Password) And RememberPassword);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") And Source = Certificate Then
		UpdateCertificateInformation();
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("Installation_AddInExtraCryptoAPI") Then
		Items.WarningDecoration.Visible = True;
		Items.WarningDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The %1 add-in is installed, check again.';"), "ExtraCryptoAPI");
	EndIf;
	
	// When changing usage settings.
	If Upper(EventName) <> Upper("Write_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("VerifyDigitalSignaturesOnTheServer")
		Or Upper(Source) = Upper("GenerateDigitalSignaturesAtServer") Then
		
		AttachIdleHandler("OnChangeSigningOrEncryptionUsage", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_LabelClick(Item)
	
	TagName = Left(Item.Name, StrLen(Item.Name) - StrLen("Label"));
	ErrorName = TagName + "Error";
	
	WarningParameters = New Structure;
	WarningParameters.Insert("WarningTitle",
		StandardItemTitle(Item.Name));
	WarningParameters.Insert("ErrorTextClient",
		ChecksAtClient[ErrorName]);
	WarningParameters.Insert("ErrorTextServer",
		?(OperationsAtServer Or HasBuiltinCryptoprovider Or HaveServiceAccount, 
			ChecksAtServer[ErrorName], ""));
			
	WarningParameters.Insert("AdditionalData", AdditionalData(TagName));
	
	OpenForm("CommonForm.ExtendedErrorPresentation",
		WarningParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	DigitalSignatureInternalClient.HandleNaviLinkClassifier(Item,
		FormattedStringURL, StandardProcessing, AdditionalData());
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
Procedure SupportInformationURLProcessing(Item, Var_URL, StandardProcessing)
	
	StandardProcessing = False;

	If Var_URL = "TypicalIssues" Then
		DigitalSignatureClient.OpenInstructionOnTypicalProblemsOnWorkWithApplications();
		Return;
	EndIf;
	
	If Not CheckCompleted Then
		ShowMessageBox(,
			NStr("en = 'To gather technical information about the issue, check the certificate.';"));
		Return;
	EndIf;
	
	ChecksContent = StandardChecks();
	For Each Validation In AdditionalChecks Do
		ChecksContent.Add(Validation.Name);
	EndDo;
	
	ErrorsText = "";
	FilesDetails = New Array;
	DigitalSignatureInternalServerCall.AddADescriptionOfAdditionalData(
		New Structure("Certificate", Certificate), FilesDetails, ErrorsText);
	
	ErrorsText = ErrorsText + NStr("en = 'Check result on client';") + ":" + Chars.LF;
	SupplementTextWithErrors(ErrorsText, ChecksContent);
	
	ErrorsText = ErrorsText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Check result on server ""%1"":';"), ServerName) + Chars.LF;
	SupplementTextWithErrors(ErrorsText, ChecksContent, True);
	
	DigitalSignatureInternalClient.GenerateTechnicalInformation(
		ErrorsText, Undefined, FilesDetails);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Validate(Command)
	
	Items.WarningDecoration.Visible = False;
	Items.FormValidate.Enabled = False;
	Items.FormValidate.Representation = ButtonRepresentation.PictureAndText;
	CheckCertificate(New NotifyDescription("ValidateCompletion", ThisObject));
	
EndProcedure

#EndRegion

#Region Private

// Continues the Check procedure.
&AtClient
Procedure ValidateCompletion(NotDefined, Context) Export
	
	Items.FormValidate.Enabled = True;
	Items.FormValidate.Representation = ButtonRepresentation.Text;
	
	If Not CheckOnSelection Then
		Return;
	EndIf;
	
	If ClientParameters.Result.ChecksPassed Then
		Close(True);
	Else
		ShowCannotContinueWarning();
	EndIf;
	
EndProcedure

// CAC:78-off: to securely pass data between forms on the client without sending them to the server.
&AtClient
Procedure ContinueOpening(Notification, CommonInternalData, IncomingClientParameters) Export
// ACC:78-
	
	InternalData = CommonInternalData;
	ClientParameters = IncomingClientParameters;
	ClientParameters.Insert("Result");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("OnOpen", True);
	If ClientParameters.Property("SpecifiedContextOfOtherOperation") Then
		
		CertificateProperties = CommonInternalData;
		ClientParameters.OperationContext.ContinueOpening(
			Undefined, Undefined, CertificateProperties);
		
		If CertificateProperties.Certificate = Certificate Then
			PasswordProperties = CertificateProperties.PasswordProperties;
		EndIf;
		
		AdditionalParameters.Insert("PasswordSpecified1");
		AdditionalParameters.Insert("OnSetPasswordFromAnotherOperation", True);
		
	EndIf;
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, AdditionalParameters);
	
	Items.RememberPassword.Enabled = Items.Password.Enabled;
	If Not Items.Password.Enabled Then
		CurrentItem = Items.FormValidate;
	EndIf;
	
	If ClientParameters.Property("NoConfirmation")
		And ClientParameters.NoConfirmation
		And (AdditionalParameters.PasswordSpecified1
		Or AdditionalParameters.EnterPasswordInDigitalSignatureApplication) Then
		
		If Not ClientParameters.Property("ResultProcessing")
			Or TypeOf(ClientParameters.ResultProcessing) <> Type("NotifyDescription") Then
			
			Open();
		EndIf;
		
		Context = New Structure("Notification", Notification);
		CheckCertificate(New NotifyDescription(
			"ContinueOpeningAfterCertificateCheck", ThisObject, Context));
		
		Return;
		
	EndIf;
	
	Open();
	
	ExecuteNotifyProcessing(Notification);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterCertificateCheck(Result, Context) Export
	
	If ClientParameters.Result.ChecksPassed Then
		ExecuteNotifyProcessing(Context.Notification, True);
		Return;
	EndIf;
	
	If Not IsOpen()
		And Not (ClientParameters.Property("DontShowResults")
		And ClientParameters.DontShowResults) Then
		
		Open();
	EndIf;
	
	If CheckOnSelection Then
		ShowCannotContinueWarning();
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

&AtClient
Procedure OnChangeSigningOrEncryptionUsage()
	
	RefreshVisibilityAtServer()
	
EndProcedure

&AtClient
Procedure ShowCannotContinueWarning()
	
	ShowMessageBox(,
		NStr("en = 'Cannot continue as not all required checks are passed.';"));
	
EndProcedure

&AtClient
Procedure CheckCertificate(Notification)
	
	PasswordAccepted = False;
	ChecksAtClient = New Structure;
	ChecksAtServer = New Structure;
	AdditionalDataChecksOnClient = New Structure;
	AdditionalDataChecksOnServer = New Structure;
	
	// Clearing the previous check results.
	If StandardChecks Then
		
		BasicChecks = StandardChecks();
		If Not IsBuiltInCryptoProvider Then
			BasicChecks.Add("ProgramExists");
		EndIf;
		
		For Each Validation In BasicChecks Do
			SetItem(ThisObject, Validation, False, , , MergeResults);
			SetItem(ThisObject, Validation, True, , , MergeResults);
		EndDo;
		
	EndIf;
	
	For Each Validation In AdditionalChecks Do
		SetItem(ThisObject, Validation.Name, False, , , MergeResults);
		SetItem(ThisObject, Validation.Name, True, , , MergeResults);
	EndDo;
	
	Context = New Structure("Notification", Notification);
	
	CheckAtClientSide(New NotifyDescription(
		"CheckCertificateAfterCheckAtClient", ThisObject, Context));
	
EndProcedure

// Continues the CheckCertificate procedure.
&AtClient
Procedure CheckCertificateAfterCheckAtClient(Result, Context) Export
	
	If IsBuiltInCryptoProvider Or ThisServiceAccount Then
		
		If OperationsAtServer Then
			CheckAtServerSideAdditionalChecks(PasswordProperties.Value);
		EndIf;
		
		If StandardChecks Then
			Notification = New NotifyDescription("VerifyCertificateAfterVerificationOnClientServer", ThisObject,
				Context);
			NewContext = New Structure;
			NewContext.Insert("ServiceCertificateCheckOnClient", True);
			NewContext.Insert("ValidationInServiceInsteadofValidationOnServer", False);
			CheckAtClientSide(Notification, NewContext);
		Else
			VerifyCertificateAfterVerificationOnClientServer(Result, Context);
		EndIf;
		
	Else
		
		ValidateInServiceInsteadofValidateOnServer = StandardChecks
			And VerifyDigitalSignaturesOnTheServer
			And (HasBuiltinCryptoprovider Or HaveServiceAccount)
			And Not OperationsAtServer;
		
		If ValidateInServiceInsteadofValidateOnServer Then
			
			If OperationsAtServer Then
				CheckAtServerSideAdditionalChecks(PasswordProperties.Value);
			EndIf;
			
			If StandardChecks And TheOperationIsActive() Then
				Notification = New NotifyDescription("VerifyCertificateAfterVerificationOnClientServer", ThisObject,
					Context);
				NewContext = New Structure;
				NewContext.Insert("ValidationInServiceInsteadofValidationOnServer", True);
				NewContext.Insert("ServiceCertificateCheckOnClient", False);
				CheckAtClientSide(Notification, NewContext);
			Else
				VerifyCertificateAfterVerificationOnClientServer(Result, Context);
			EndIf;
			
		Else
			If OperationsAtServer Then
				If StandardChecks Then
					CheckAtServerSide(PasswordProperties.Value);
				Else
					CheckAtServerSideAdditionalChecks(PasswordProperties.Value);
				EndIf;
			EndIf;
			VerifyCertificateAfterVerificationOnClientServer(Result, Context);
		EndIf;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure VerifyCertificateAfterVerificationOnClientServer(Result, Context) Export
	
	If PasswordAccepted Then
		DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
			InternalData, PasswordProperties, New Structure("OnOperationSuccess", True));
	EndIf;
	
	Result = New Structure;
	Result.Insert("ChecksPassed", False);
	Result.Insert("ChecksAtClient", ChecksAtClient);
	Result.Insert("ChecksAtServer", ChecksAtServer);
	Result.Insert("AdditionalDataChecksOnClient", AdditionalDataChecksOnClient);
	Result.Insert("AdditionalDataChecksOnServer", AdditionalDataChecksOnServer);
	
	ClientParameters.Insert("Result", Result);
	
	If ClientParameters.Property("ResultProcessing")
	   And TypeOf(ClientParameters.ResultProcessing) = Type("NotifyDescription") Then
		
		ExecuteNotifyProcessing(ClientParameters.ResultProcessing, Result.ChecksPassed);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

#Region CheckAtCleint

&AtClient
Procedure CheckAtClientSide(Notification, Context = Undefined)
	
	CheckCompleted = True;
	If Context = Undefined Then
		Context = New Structure;
		Context.Insert("ValidationInServiceInsteadofValidationOnServer", False);
		Context.Insert("ServiceCertificateCheckOnClient", False);
	EndIf;
	
	Context.Insert("Notification", Notification);
	
	If StandardChecks Then
		DigitalSignatureClient.InstallExtension(False, New NotifyDescription(
			"CheckAtClientSideAfterAttachCryptoExtension", ThisObject, Context),
			NStr("en = 'To continue, install the cryptography extension.';"));
	Else
		Context.Insert("CryptoManager", Undefined);
		CheckAtClientSideAdditionalChecks(Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterAttachCryptoExtension(Attached, Context) Export
	
	CertificateData = GetFromTempStorage(CertificateAddress);
	Context.Insert("SignAlgorithm",
		DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateData));
	
	If Attached <> True Then
		
		CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
		CreationParameters.ShowError = False;
		CreationParameters.SignAlgorithm = Context.SignAlgorithm;
		
		DigitalSignatureInternalClient.CreateCryptoManager(New NotifyDescription(
				"CheckAtClientSideAfterAttemptToCreateCryptoManager", ThisObject, Context),
			"CertificateCheck", CreationParameters);
		
		Return;
		
	EndIf;
	
	// 
	Context.Insert("CertificateData", CertificateData);
	
	CryptoCertificate = New CryptoCertificate;
	CryptoCertificate.BeginInitialization(New NotifyDescription(
			"CheckAtClientSideAfterInitializeCertificate", ThisObject, Context,
			"CheckAtClientSideAfterCertificateInitializationError", ThisObject),
		Context.CertificateData);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterAttemptToCreateCryptoManager(Result, Context) Export
	
	SetItem(ThisObject, FirstCheckName, False, Result, False, MergeResults);
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCertificateInitializationError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	SetItem(ThisObject, FirstCheckName, False, ErrorDescription, True, MergeResults);
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterInitializeCertificate(CryptoCertificate, Context) Export
	
	Context.Insert("CryptoCertificate", CryptoCertificate);
	
	// Verified certificate.
	CheckLegalCertificateAtClient(Context);
	
	Context.Insert("ThisOperationInService", False);
	
	// Availability of a certificate in the personal list.
	If ThisServiceAccount And Not Context.ServiceCertificateCheckOnClient Then
		
		Context.Insert("ThisOperationInService", True);
		TheNotificationIsAsFollows = New NotifyDescription("VerifyOnTheClientSideAfterAuthorizationInTheCloudSignature", ThisObject, Context);
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClient.VerifyingUserAuthentication(TheNotificationIsAsFollows, Application);
		
	ElsIf HaveServiceAccount And Context.ValidationInServiceInsteadofValidationOnServer Then
		
		Context.Insert("ThisOperationInService", True);
		Context.Insert("UserSettings", Undefined);
		TheNotificationIsAsFollows = New NotifyDescription(
				"VerifyOnTheClientSideAfterVerifyingTheCloudSignatureCertificate", ThisObject, Context);
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClient.CheckCertificate(TheNotificationIsAsFollows, Context.UserSettings, Context.CertificateData);
		
	ElsIf IsBuiltInCryptoProvider And Not Context.ServiceCertificateCheckOnClient Then
		
		Context.Insert("ThisOperationInService", True);
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", Context.CryptoCertificate.Thumbprint);
		ModuleCertificateStoreClient = CommonClient.CommonModule("CertificatesStorageClient");
		ModuleCertificateStoreClient.FindCertificate(New NotifyDescription(
			"CheckAtClientSideAfterCertificateSearchInSaaSMode", ThisObject, Context), TheStructureOfTheSearch);
	ElsIf HasBuiltinCryptoprovider And Context.ValidationInServiceInsteadofValidationOnServer Then
		
		Context.Insert("ThisOperationInService", True);
		// Checking certificate data.
		ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
			
		ModuleCryptographyServiceClient.CheckCertificate(New NotifyDescription(
			"CheckAtClientSideAfterCertificateCheckInSaaSMode", ThisObject, Context),
			Context.CertificateData);
	Else
		If Context.ServiceCertificateCheckOnClient Then
			CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
			CreationParameters.SignAlgorithm = Context.SignAlgorithm;
			CreationParameters.ShowError = False;
	
			// 
			DigitalSignatureInternalClient.CreateCryptoManager(
				New NotifyDescription("CheckAtClientSideAfterCreateAnyCryptoManager",
				ThisObject, Context), "CertificateCheck", CreationParameters);
		Else
			DigitalSignatureInternalClient.GetCertificateByThumbprint(New NotifyDescription(
				"CheckAtClientSideAfterCertificateSearch", ThisObject, Context),
				Base64String(Context.CryptoCertificate.Thumbprint), True, Undefined);
		EndIf;	
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckLegalCertificateAtClient(Context)
	
	If Not Items.LegalCertificateGroup.Visible
	 Or Context.CryptoCertificate.Subject.Property("SN") Then
		
		ErrorDescription = "";
	Else
		ErrorDescription = NStr("en = 'The ""SN"" field is not found in the certificate subject description.';");
	EndIf;
	SetItem(ThisObject, "LegalCertificate", False, ErrorDescription, , MergeResults);

EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoCertificate") Then
		SetItem(ThisObject, "CertificateExists", False, "", , MergeResults);
	Else
		SetItem(ThisObject, "CertificateExists", False,
			?(TypeOf(Result) = Type("String"), Result, Result.ErrorDescription) + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot check signing, created signature and decryption.';"),
			True, MergeResults);
	EndIf;
	
	CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
	CreationParameters.SignAlgorithm = Context.SignAlgorithm;
	CreationParameters.ShowError = False;
	
	// 
	DigitalSignatureInternalClient.CreateCryptoManager(New NotifyDescription(
		"CheckAtClientSideAfterCreateAnyCryptoManager", ThisObject, Context),
		"CertificateCheck", CreationParameters);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  Result - Structure:
//   * ErrorDescription - Structure:
//      ** LongDesc - String
//
&AtClient
Procedure CheckAtClientSideAfterCertificateSearchInSaaSMode(Result, Context) Export
	
	ErrorDescription = "";
	If Not Result.Completed2 Then
		ErrorDescription = Result.ErrorDescription.LongDesc;
	ElsIf Not ValueIsFilled(Result.Certificate) Then
		ErrorDescription = NStr("en = 'The certificate does not exist in the service. It might have been deleted.';");
	EndIf;
	If Not IsBlankString(ErrorDescription) Then
		ErrorDescription = ErrorDescription + Chars.LF
			+ NStr("en = 'Cannot check signing, created signature and decryption.';");
	EndIf;
	SetItem(ThisObject, "CertificateExists", True, ErrorDescription, , MergeResults);
	
	// If the certificate is not found in the certificate storage, checks stop.
	If Not IsBlankString(ErrorDescription) Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	// Checking certificate data.
	ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
		
	ModuleCryptographyServiceClient.CheckCertificate(New NotifyDescription(
			"CheckAtClientSideAfterCertificateCheckInSaaSMode", ThisObject, Context),
			Result.Certificate.Certificate);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCreateAnyCryptoManager(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoManager") Then
		AdditionalInspectionParameters = DigitalSignatureInternalClient.AdditionalCertificateVerificationParameters();
		AdditionalInspectionParameters.PerformCAVerification = False;
		AdditionalInspectionParameters.MergeCertificateDataErrors = False;
		AdditionalInspectionParameters.CheckInServiceAfterError = False;
		DigitalSignatureInternalClient.CheckCertificate(New NotifyDescription(
				"CheckAtClientSideAfterCertificateCheck", ThisObject, Context),
			Context.CryptoCertificate, Result,,AdditionalInspectionParameters);
	Else
		CheckAtClientSideAfterCertificateCheck(Result, Context)
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Async Procedure CheckAtClientSideAfterCertificateCheck(Result, Context) Export
	
	If Result = True Then
		ErrorDetailsAtClient = "";
	ElsIf TypeOf(Result) = Type("Structure") Then
		ErrorDetailsAtClient = Result.ErrorDetailsAtClient;
	Else
		ErrorDetailsAtClient = Result;
	EndIf;
	
	SetItem(ThisObject, "CertificateData", False, ErrorDetailsAtClient, True, MergeResults);
	
	If Context.ServiceCertificateCheckOnClient Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	// Application availability.
	If ValueIsFilled(Application) Then
		
		CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
		CreationParameters.Application = Application;
		CreationParameters.ShowError = False;
		CreationParameters.InteractiveMode = CertificateEnterPasswordInElectronicSignatureProgram;
		
		DigitalSignatureInternalClient.CreateCryptoManager(New NotifyDescription(
				"CheckAtClientSideAfterCreateCryptoManager", ThisObject, Context),
			"CertificateCheck", CreationParameters);
		
	Else
		
		AppAutoAtClientResult = Await DigitalSignatureInternalClient.AppForCertificate(
			CertificateAddress);
		AppAutoAtClient = AppAutoAtClientResult.Application;
		If AppAutoAtClientResult.Application = Undefined Then
			ErrorDescription = DigitalSignatureInternalClientServer.ErrorTextFailedToDefineApp(
				AppAutoAtClientResult.Error);
			CheckAtClientSideAfterCreateCryptoManager(ErrorDescription, Context);
		Else
			CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
			CreationParameters.Application = AppAutoAtClient;
			CreationParameters.ShowError = False;
			CreationParameters.InteractiveMode = CertificateEnterPasswordInElectronicSignatureProgram;

			DigitalSignatureInternalClient.CreateCryptoManager(
				New NotifyDescription("CheckAtClientSideAfterCreateCryptoManager", ThisObject,
				Context), "CertificateCheck", CreationParameters);
		EndIf;
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  Result - Structure:
//   * ErrorInfo - Structure:
//      ** LongDesc - String
//  Context - Structure
//
&AtClient
Procedure CheckAtClientSideAfterCertificateCheckInSaaSMode(Result, Context) Export
	
	If Result.Completed2 And Result.Valid1 Then
		ErrorDescription = "";
	Else
		ErrorDescription = Result.ErrorInfo.LongDesc;
	EndIf;
	
	SetItem(ThisObject, "CertificateData", True, ErrorDescription, True, MergeResults);
	
	If Context.ValidationInServiceInsteadofValidationOnServer Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	// Application availability.
	If ValueIsFilled(Application) Then
		CheckAtClientSideInSaaSMode("CryptographyService", Context);
	Else
		ErrorDescription = NStr("en = 'Application for private key was not specified in the certificate.';");
		CheckAtClientSideAfterCreateCryptoManager(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCreateCryptoManager(Result, Context) Export
	
	Context.Insert("CryptoManager", Undefined);
	
	If TypeOf(Result) = Type("CryptoManager") Then
		Context.CryptoManager = Result;
		ErrorDescription = "";
	Else
		ErrorDescription = Result + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot verify signing, signature, 
			             |decryption and encryption. ';");
	EndIf;
	SetItem(ThisObject, "ProgramExists", Context.ThisOperationInService, ErrorDescription, True, MergeResults);
	
	If Context.CryptoManager = Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	If Not DigitalSignatureInternalClient.InteractiveCryptographyModeUsed(Context.CryptoManager) Then
		Context.CryptoManager.PrivateKeyAccessPassword = PasswordProperties.Value;
	EndIf;
	
	ErrorDescription = "";
	AdditionalCheckOnthePossibilityofSigning(Context.CryptoCertificate, False, ErrorDescription);
	
	// Signing
	If ChecksAtClient.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		Context.CryptoManager.BeginSigning(New NotifyDescription(
				"CheckAtClientSideAfterSigning", ThisObject, Context,
				"CheckAtClientSideAfterSigningError", ThisObject),
			Context.CertificateData, Context.CryptoCertificate);
	Else
		CheckAtClientSideAfterSigning(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideInSaaSMode(Result, Context)
	
	Context.Insert("CryptoManager", Undefined);
	
	If TypeOf(Result) = Type("String") And Result = "CryptographyService" Then
		Context.CryptoManager = Result;
		ErrorDescription = "";
	Else
		ErrorDescription = Result + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot verify signing, signature, 
			             |decryption and encryption. ';");
	EndIf;
	SetItem(ThisObject, "ProgramExists", True, ErrorDescription, True, MergeResults);
	
	If Context.CryptoManager = Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	ErrorDescription = "";
	AdditionalCheckOnthePossibilityofSigning(Context.CryptoCertificate, True, ErrorDescription);
	
	// Signing.
	If ChecksAtClient.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
		ModuleCryptographyServiceClient.Sign(New NotifyDescription(
				"CheckAtClientSideAfterSigningSaaS", ThisObject, Context,
				"CheckAtClientSideAfterSigningError", ThisObject),
			Context.CertificateData, Context.CertificateData);
	Else
		CheckAtClientSideAfterSigningSaaS(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterSigningError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckAtClientSideAfterSigning(ErrorProcessing.BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterSigning(SignatureData, Context) Export
	
	If SignatureData <> Null Then
		If TypeOf(SignatureData) = Type("String") Then
			ErrorDescription = SignatureData;
		Else
			ErrorDescription = "";
			DigitalSignatureInternalClientServer.BlankSignatureData(SignatureData, ErrorDescription);
		EndIf;
		If Not ValueIsFilled(ErrorDescription) Then
			PasswordAccepted = True;
		EndIf;
		SetItem(ThisObject, "Signing", Context.ThisOperationInService, ErrorDescription, True, MergeResults);
	EndIf;
	
	// Check the signature.
	If SignatureData <> Null And ChecksAtClient.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		Context.CryptoManager.BeginVerifyingSignature(New NotifyDescription(
				"CheckAtClientSideAfterCheckSignature", ThisObject, Context,
				"CheckAtClientSideAfterCheckSignatureError", ThisObject),
			Context.CertificateData, SignatureData);
	Else
		CheckAtClientSideAfterCheckSignature(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  SignatureData - Structure:
//   * ErrorInfo - Structure:
//      ** LongDesc - String
//  Context - Structure
//
&AtClient
Procedure CheckAtClientSideAfterSigningSaaS(SignatureData, Context) Export
	
	If TypeOf(SignatureData) = Type("Structure") Then
		If Not SignatureData.Completed2 Then
			ErrorDescription = SignatureData.ErrorInfo.LongDesc;
		Else
			ErrorDescription = "";
			SignatureData = SignatureData.Signature;
			DigitalSignatureInternalClientServer.BlankSignatureData(SignatureData, ErrorDescription);
		EndIf;
		If Not ValueIsFilled(ErrorDescription) Then
			PasswordAccepted = True;
		EndIf;
		SetItem(ThisObject, "Signing", True, ErrorDescription, True, MergeResults);
	EndIf;
	
	// Check the signature.
	If SignatureData <> Null And ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
		ModuleCryptographyServiceClient.VerifySignature(New NotifyDescription(
					"CheckAtClientSideAfterCheckSignatureInSaaSMode", ThisObject, Context,
					"CheckAtClientSideAfterCheckSignatureError", ThisObject),
				SignatureData, Context.CertificateData);
	Else
		CheckAtClientSideAfterCheckSignatureInSaaSMode(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCheckSignatureError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckAtClientSideAfterCheckSignature(ErrorProcessing.BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterCheckSignature(Certificate, Context) Export
	
	If Certificate <> Null Then
		If TypeOf(Certificate) = Type("String") Then
			ErrorDescription = Certificate;
		Else
			ErrorDescription = "";
		EndIf;
		SetItem(ThisObject, "CheckSignature", False, ErrorDescription, True, MergeResults);
	EndIf;
	
	Context.CryptoManager.BeginEncrypting(New NotifyDescription(
			"CheckAtClientSideAfterEncryption", ThisObject, Context,
			"CheckAtClientSideAfterEncryptionError", ThisObject),
		Context.CertificateData, Context.CryptoCertificate);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  Result - Structure:
//   * ErrorInfo - Structure:
//      ** LongDesc - String
//  Context - Structure
//
&AtClient
Procedure CheckAtClientSideAfterCheckSignatureInSaaSMode(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		If Not Result.Completed2 Then
			ErrorDescription = Result.ErrorInfo.LongDesc;
		Else
			ErrorDescription = "";
		EndIf;
		SetItem(ThisObject, "CheckSignature", True, ErrorDescription, True, MergeResults);
	EndIf;
	
	ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
	ModuleCryptographyServiceClient.Encrypt(New NotifyDescription(
			"CheckAtClientSideAfterEncryptionInSaaSMode", ThisObject, Context,
			"CheckAtClientSideAfterEncryptionError", ThisObject),
			Context.CertificateData, Context.CertificateData);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterEncryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckAtClientSideAfterEncryption(ErrorProcessing.BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterEncryption(EncryptedData, Context) Export
	
	If TypeOf(EncryptedData) = Type("String") Then
		ErrorDescription = EncryptedData;
	Else
		ErrorDescription = "";
		DigitalSignatureInternalClientServer.BlankEncryptedData(EncryptedData, ErrorDescription);
	EndIf;
	SetItem(ThisObject, "Encryption", Context.ThisOperationInService, ErrorDescription, True, MergeResults);
	
	// Decryption.
	If ChecksAtClient.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		Context.CryptoManager.BeginDecrypting(New NotifyDescription(
				"CheckAtClientSideAfterDecryption", ThisObject, Context,
				"CheckAtClientSideAfterDecryptionError", ThisObject),
			EncryptedData);
	Else
		CheckAtClientSideAfterDecryption(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  Result - Structure:
//   * ErrorInfo - Structure:
//      ** LongDesc - String
//  Context - Structure
//
&AtClient
Procedure CheckAtClientSideAfterEncryptionInSaaSMode(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		If Not Result.Completed2 Then
			ErrorDescription = Result.ErrorInfo.LongDesc;
		Else
			ErrorDescription = "";
			EncryptedData = Result.EncryptedData;
			DigitalSignatureInternalClientServer.BlankEncryptedData(EncryptedData, ErrorDescription);
		EndIf;
	EndIf;
	SetItem(ThisObject, "Encryption", True, ErrorDescription, True, MergeResults);
	
	// Decryption.
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
		ModuleCryptographyServiceClient.Decrypt(New NotifyDescription(
				"CheckAtClientSideAfterDecryptionInSaaSMode", ThisObject, Context,
				"CheckAtClientSideAfterDecryptionError", ThisObject),
			Result.EncryptedData);
	Else
		CheckAtClientSideAfterDecryptionInSaaSMode(Null, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterDecryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	CheckAtClientSideAfterDecryption(ErrorProcessing.BriefErrorDescription(ErrorInfo), Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterDecryption(DecryptedData, Context) Export
	
	If DecryptedData <> Null Then
		If TypeOf(DecryptedData) = Type("String") Then
			ErrorDescription = DecryptedData;
		Else
			ErrorDescription = "";
			DigitalSignatureInternalClientServer.BlankDecryptedData(DecryptedData, ErrorDescription);
		EndIf;
		SetItem(ThisObject, "Details", Context.ThisOperationInService, ErrorDescription, True, MergeResults);
	EndIf;
	
	CheckAtClientSideAdditionalChecks(Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
// 
// Parameters:
//  Result - Structure:
//   * ErrorInfo - Structure:
//      ** LongDesc - String
//  Context - Structure
//
&AtClient
Procedure CheckAtClientSideAfterDecryptionInSaaSMode(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		If Not Result.Completed2 Then
			ErrorDescription = Result.ErrorInfo.LongDesc;
		Else
			ErrorDescription = "";
			DigitalSignatureInternalClientServer.BlankDecryptedData(Result.DecryptedData, ErrorDescription);
		EndIf;
		SetItem(ThisObject, "Details", True, ErrorDescription, True, MergeResults);
	EndIf;
	
	CheckAtClientSideAdditionalChecks(Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAdditionalChecks(Context)
	
	// 
	Context.Insert("IndexOf", -1);
	
	CheckAtClientSideLoopStart(Context);
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideAfterAdditionalCheck(NotDefined, Context) Export
	
	ExecutionParameters = ContextExecutionParameters.Get(Context);
	ContextExecutionParameters.Delete(Context);
	
	SetItem(ThisObject, Context.ListItem.Name, False,
		ExecutionParameters.ErrorDescription,
		ExecutionParameters.IsWarning <> True,
		MergeResults);
	
	CheckAtClientSideLoopStart(Context);
	
EndProcedure

#EndRegion

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckAtClientSideLoopStart(Context)
	
	If AdditionalChecks.Count() <= Context.IndexOf + 1 Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ListItem", AdditionalChecks[Context.IndexOf]);
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("Certificate",           Certificate);
	ExecutionParameters.Insert("Validation",             Context.ListItem.Name);
	ExecutionParameters.Insert("CryptoManager", Context.CryptoManager);
	ExecutionParameters.Insert("ErrorDescription",       "");
	ExecutionParameters.Insert("IsWarning",    False);
	ExecutionParameters.Insert("WaitForContinue",   False);
	ExecutionParameters.Insert("Password",               ?(EnterPassword, PasswordProperties.Value, Undefined));
	ExecutionParameters.Insert("ChecksResults",   ChecksAtClient);
	ExecutionParameters.Insert("Notification",           New NotifyDescription(
		"CheckAtClientSideAfterAdditionalCheck", ThisObject, Context));
	
	If TypeOf(ContextExecutionParameters) <> Type("Map") Then
		ContextExecutionParameters = New Map;
	EndIf;
	ContextExecutionParameters.Insert(Context, ExecutionParameters);
	
	Try
		DigitalSignatureClientOverridable.OnAdditionalCertificateCheck(ExecutionParameters);
	Except
		ErrorInfo = ErrorInfo();
		ExecutionParameters.WaitForContinue = False;
		ExecutionParameters.ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	EndTry;
	
	If ExecutionParameters.WaitForContinue <> True Then
		CheckAtClientSideAfterAdditionalCheck(Undefined, Context);
	EndIf;
	
EndProcedure

#Region ClientVerificationCloudSignature

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterAuthorizationInTheCloudSignature(CallResult, Context) Export
	
	If Not CallResult.Completed2 Then
		ErrorDescription = CallResult.Error;
	EndIf;
	
	// If authentication failed, stop the checks.
	If Not IsBlankString(ErrorDescription) Then
		Return;
	EndIf;
	
	Context.Insert("UserSettings", CallResult.UserSettings);
	
	TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
	TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
	
	TheStructureOfTheSearch = New Structure;
	TheStructureOfTheSearch.Insert("Thumbprint", TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(Context.CryptoCertificate.Thumbprint));
	TheDSSCryptographyServiceModuleClient.FindCertificate(New NotifyDescription(
		"CheckOnTheClientSideAfterSearchingForTheCloudSignatureCertificate", ThisObject, Context), TheStructureOfTheSearch);
	
EndProcedure
		
// Continues the CheckAtClientSide procedure.
&AtClient
Procedure CheckOnTheClientSideAfterSearchingForTheCloudSignatureCertificate(CallResult, Context) Export
	
	ErrorDescription = "";
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf Not CallResult.Completed2 Then
		ErrorDescription = CallResult.Error;
	ElsIf Not ValueIsFilled(CallResult.CertificateData) Then
		ErrorDescription = NStr("en = 'The certificate does not exist in the service. It might have been deleted.';");
	EndIf;
	
	If Not IsBlankString(ErrorDescription) Then
		ErrorDescription = ErrorDescription + Chars.LF
			+ NStr("en = 'Cannot check signing, created signature and decryption.';");
	EndIf;
	SetItem(ThisObject, "CertificateExists", True, ErrorDescription, , MergeResults);
	
	If Not IsBlankString(ErrorDescription) Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	// Checking certificate data.
	HandlerNext = New NotifyDescription(
			"VerifyOnTheClientSideAfterVerifyingTheCloudSignatureCertificate", ThisObject, Context);
	
	TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
	TheDSSCryptographyServiceModuleClient.CheckCertificate(HandlerNext, Context.UserSettings,
		CallResult.CertificateData.Certificate);
	
EndProcedure
		
// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterVerifyingTheCloudSignatureCertificate(Result, Context) Export
	
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf Result.Completed2 And Result.Result Then
		ErrorDescription = "";
	Else
		ErrorDescription = DigitalSignatureInternalClient.ErrorTextCloudSignature("CertificateCheck",
			Result, True);
	EndIf;
	
	SetItem(ThisObject, "CertificateData", True, ErrorDescription, True, MergeResults);
	
	If Context.ValidationInServiceInsteadofValidationOnServer Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	// Application availability.
	If ValueIsFilled(Application) Then
		VerifyClientSideCloudSignature("CloudSignature", Context);
	Else
		ErrorDescription = NStr("en = 'Application for private key was not specified in the certificate.';");
		CheckAtClientSideAfterCreateCryptoManager(ErrorDescription, Context);
	EndIf;
	
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyClientSideCloudSignature(Result, Context)
	
	Context.Insert("CryptoManager", Undefined);
	
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf TypeOf(Result) = Type("String") And Result = "CloudSignature" Then
		Context.CryptoManager = Result;
		ErrorDescription = "";
	Else
		ErrorDescription = Result + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot verify signing, signature, 
			             |decryption and encryption.';");
	EndIf;
	SetItem(ThisObject, "ProgramExists", True, ErrorDescription, True, MergeResults);
	
	If Context.CryptoManager = Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	ErrorDescription = "";
	AdditionalCheckOnthePossibilityofSigning(Context.CryptoCertificate, True, ErrorDescription);
	
	// Signing
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then

		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		
		HandlerNext = New NotifyDescription(
				"VerifyOnTheClientSideAfterSigningCloudSignature", ThisObject, Context,
				"CheckAtClientSideAfterSigningError", ThisObject);
		
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(Context.CryptoCertificate.Thumbprint));
		
		PINCodeValue = ?(ValueIsFilled(PasswordProperties.Value), PasswordProperties.Value, Undefined);
		OperationParametersList = New Structure;
		OperationParametersList.Insert("Pin", TheDSSCryptographyServiceModuleClient.PreparePasswordObject(PINCodeValue));
		
		TheDSSCryptographyServiceModuleClient.Sign(
				HandlerNext,
				Context.UserSettings,
				Context.CertificateData,
				,
				TheStructureOfTheSearch,
				OperationParametersList);
				
	Else
		VerifyOnTheClientSideAfterSigningCloudSignature(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterSigningCloudSignature(CallResult, Context) Export
	
	ErrorDescription = Undefined;
	
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf CallResult <> Undefined Then
		If Not CallResult.Completed2 Then
			ErrorDescription = CallResult.Error;
		Else
			SignatureData = CallResult.Result;
			ErrorDescription = "";
			DigitalSignatureInternalClientServer.BlankSignatureData(SignatureData, ErrorDescription);
		EndIf;
		
		If Not ValueIsFilled(ErrorDescription) Then
			PasswordAccepted = True;
		EndIf;
	EndIf;
	
	SetItem(ThisObject, "Signing", True, ErrorDescription, True, MergeResults);
	
	// Check the signature.
	If CallResult <> Undefined And ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		HandlerNext = New NotifyDescription(
					"VerifyOnTheClientSideAfterVerifyingTheSignatureCloudSignature", ThisObject, Context,
					"CheckAtClientSideAfterCheckSignatureError", ThisObject);
		
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClient.VerifySignature(HandlerNext, 
						Context.UserSettings, 
						SignatureData,
						Context.CertificateData,
						"CMS");
	Else
		VerifyOnTheClientSideAfterVerifyingTheSignatureCloudSignature(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterVerifyingTheSignatureCloudSignature(CallResult, Context) Export
	
	ErrorDescription = Undefined;
	
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf CallResult <> Undefined Then
		If Not CallResult.Completed2 Then
			ErrorDescription = DigitalSignatureInternalClient.ErrorTextCloudSignature(
				"CheckSignature", CallResult, True);
		Else
			ErrorDescription = "";
		EndIf;
		SetItem(ThisObject, "CheckSignature", True, ErrorDescription, True, MergeResults);
	EndIf;
	
	If Not ValueIsFilled(ErrorDescription) Then
		HandlerNext = New NotifyDescription(
				"VerifyOnTheClientSideAfterEncryptionCloudSignature", ThisObject, Context,
				"CheckAtClientSideAfterEncryptionError", ThisObject);
		
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClient.Encrypt(HandlerNext,
				Context.UserSettings,
				Context.CertificateData,
				Context.CertificateData);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterEncryptionCloudSignature(CallResult, Context) Export
	
	ErrorDescription = Undefined;
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf CallResult <> Undefined Then
		If Not CallResult.Completed2 Then
			ErrorDescription = CallResult.Error;
		Else
			ErrorDescription = "";
		EndIf;
	EndIf;
	SetItem(ThisObject, "Encryption", True, ErrorDescription, True, MergeResults);
	
	// Decryption.
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		HandlerNext = New NotifyDescription(
				"VerifyOnTheClientSideAfterDecryptingTheCloudSignature", ThisObject, Context,
				"CheckAtClientSideAfterDecryptionError", ThisObject);
		
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(Context.CryptoCertificate.Thumbprint));
		
		PINCodeValue = ?(ValueIsFilled(PasswordProperties.Value), PasswordProperties.Value, Undefined);
		OperationParametersList = New Structure;
		OperationParametersList.Insert("Pin", TheDSSCryptographyServiceModuleClient.PreparePasswordObject(PINCodeValue));
		
		TheDSSCryptographyServiceModuleClient.Decrypt(HandlerNext, Context.UserSettings, CallResult.Result, , TheStructureOfTheSearch, OperationParametersList);
	Else
		VerifyOnTheClientSideAfterDecryptingTheCloudSignature(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the CheckAtClientSide procedure.
&AtClient
Procedure VerifyOnTheClientSideAfterDecryptingTheCloudSignature(CallResult, Context) Export
	
	ErrorDescription = Undefined;
	If Not TheOperationIsActive() Then
		ErrorDescription = NStr("en = 'Check form is closed.';");
	ElsIf CallResult <> Undefined Then
		If Not CallResult.Completed2 Then
			ErrorDescription = CallResult.Error;
		Else
			ErrorDescription = "";
			DigitalSignatureInternalClientServer.BlankDecryptedData(CallResult.Result, ErrorDescription);
		EndIf;
		SetItem(ThisObject, "Details", True, ErrorDescription, True, MergeResults);
	EndIf;
	
	CheckAtClientSideAdditionalChecks(Context);
	
EndProcedure

&AtClient
Function TheOperationIsActive()
	
	Result = IsOpen();
	Return Result;
	
EndFunction	

#EndRegion

#Region CheckAtServer

&AtServer
Procedure CheckAtServerSide(Val PasswordValue)
	
	CheckCompleted = True;
	
	ServerName = ComputerName();
	
	CertificateData = GetFromTempStorage(CertificateAddress);
	SignAlgorithm = DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateData);
	
	Try
		CryptoCertificate = New CryptoCertificate(CertificateData);
	Except
		SetItem(ThisObject, FirstCheckName, True,
			ErrorProcessing.BriefErrorDescription(ErrorInfo()), True, MergeResults);
		Return;
	EndTry;
	
	// Verified certificate.
	CheckLegalCertificateAtServer(CryptoCertificate);
	
	// Availability of a certificate in the personal list.
	Result = New Structure;
	DigitalSignatureInternal.GetCertificateByThumbprint(
		Base64String(CryptoCertificate.Thumbprint), True, False, , Result);
	
	ErrorDescription = "";
	If ValueIsFilled(Result) Then
		ErrorDescription = Result.ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot check signing, created signature and decryption.';");
	EndIf;
	SetItem(ThisObject, "CertificateExists", True, ErrorDescription, , MergeResults);
	
	// Check certificate data.
	CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
	CreationParameters.SignAlgorithm = SignAlgorithm;
	
	CryptoManager = DigitalSignatureInternal.CryptoManager(
		"CertificateCheck", CreationParameters);
	
	ErrorDescription = CreationParameters.ErrorDescription;
	If Not ValueIsFilled(ErrorDescription) Then
		AdditionalCertificateVerificationParameters = 
			DigitalSignatureInternal.AdditionalCertificateVerificationParameters();
		AdditionalCertificateVerificationParameters.PerformCAVerification = False;
		DigitalSignatureInternal.CheckCertificate(CryptoManager, CryptoCertificate, ErrorDescription,,AdditionalCertificateVerificationParameters);
	EndIf;
	
	SetItem(ThisObject, "CertificateData", True, ErrorDescription, True, MergeResults);
	
	// Application availability.
	If ValueIsFilled(Application) Then
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.Application = Application;
		
		CryptoManager = DigitalSignatureInternal.CryptoManager("CertificateCheck", CreationParameters);
		ErrorDescription = CreationParameters.ErrorDescription;
	Else
		
		AppAutoAtServerResult = DigitalSignatureInternal.AppForCertificate(CertificateAddress);
		AppAutoAtServer = AppAutoAtServerResult.Application;
		
		If AppAutoAtServerResult.Application = Undefined Then
			ErrorDescription = DigitalSignatureInternalClientServer.ErrorTextFailedToDefineApp(
				AppAutoAtServerResult.Error);
			CryptoManager = Undefined;
		Else
			CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
			CreationParameters.Application = AppAutoAtServer;
			CryptoManager = DigitalSignatureInternal.CryptoManager("CertificateCheck", CreationParameters);
			ErrorDescription = CreationParameters.ErrorDescription;
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		
		ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en = 'Cannot verify signing, signature, 
			|decryption and encryption. ';");
		
	EndIf;
	SetItem(ThisObject, "ProgramExists", True, ErrorDescription, True, MergeResults);
	
	If CryptoManager = Undefined Then
		Return;
	EndIf;
	
	CryptoManager.PrivateKeyAccessPassword = PasswordValue;
	
	ErrorDescription = "";
	
	If Revoked Then
		ErrorDescription = DigitalSignatureInternal.ErrorCertificateMarkedAsRevoked();
		SetItem(ThisObject, "Signing", True, ErrorDescription, True, MergeResults);
	Else
		ResultCheckCA = DigitalSignatureInternal.ResultofCertificateAuthorityVerification(
			CryptoCertificate);
		If Not ResultCheckCA.Valid_SSLyf Then
			SigningAllowed = Common.CommonSettingsStorageLoad(
				Certificate, "AllowSigning", Undefined);
			If SigningAllowed = Undefined Or Not SigningAllowed Then
				ErrorDescription = ResultCheckCA.Warning.ErrorText;
				SetItem(ThisObject, "Signing", True, ResultCheckCA.Warning, True,
					MergeResults);
			EndIf;
		EndIf;
	EndIf;
	
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		SignatureData = CheckSigningArServer(CryptoManager, CertificateData, CryptoCertificate, ErrorDescription);
	EndIf;
	
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		CheckSignatureAtServer(CryptoManager, CertificateData, SignatureData);
	EndIf;
	
	ErrorDescription = "";
	EncryptedData = CheckEncryptionAtServer(CryptoManager, CertificateData, CryptoCertificate, ErrorDescription); 
	
	If ChecksAtServer.CertificateExists = True And Not ValueIsFilled(ErrorDescription) Then
		CheckDecryptionAtServer(CryptoManager, EncryptedData);
	EndIf;
	
	CheckAtServerSideAdditionalChecks(PasswordValue, CryptoManager);
	
EndProcedure

&AtServer
Procedure CheckLegalCertificateAtServer(CryptoCertificate)
	
	ErrorDescription = "";
	If Items.LegalCertificateGroup.Visible
		And Not CryptoCertificate.Subject.Property("SN") Then
		
		ErrorDescription = NStr("en = 'The ""SN"" field is not found in the certificate subject description.';");
	EndIf;
	SetItem(ThisObject, "LegalCertificate", True, ErrorDescription, , MergeResults);

EndProcedure

&AtServer
Function CheckSigningArServer(CryptoManager, CertificateData, CryptoCertificate, ErrorDescription)
	
	Try
		SignatureData = CryptoManager.Sign(CertificateData, CryptoCertificate);
		DigitalSignatureInternalClientServer.BlankSignatureData(SignatureData, ErrorDescription);
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PasswordAccepted = Not ValueIsFilled(ErrorDescription);
	SetItem(ThisObject, "Signing", True, ErrorDescription, True, MergeResults);
	Return SignatureData;
	
EndFunction

&AtServer
Procedure CheckSignatureAtServer(CryptoManager, CertificateData, SignatureData)
	
	ErrorDescription = "";
	Try
		CryptoManager.VerifySignature(CertificateData, SignatureData);
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	SetItem(ThisObject, "CheckSignature", True, ErrorDescription, True, MergeResults);
	
EndProcedure

&AtServer
Function CheckEncryptionAtServer(CryptoManager, CertificateData, CryptoCertificate, ErrorDescription)
	
	Try
		EncryptedData = CryptoManager.Encrypt(CertificateData, CryptoCertificate);
		DigitalSignatureInternalClientServer.BlankEncryptedData(EncryptedData, ErrorDescription);
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	SetItem(ThisObject, "Encryption", True, ErrorDescription, True, MergeResults);
	
	Return EncryptedData;
	
EndFunction

&AtServer
Procedure CheckDecryptionAtServer(CryptoManager, EncryptedData)
	
	ErrorDescription = "";
	Try
		DecryptedData = CryptoManager.Decrypt(EncryptedData);
		DigitalSignatureInternalClientServer.BlankDecryptedData(DecryptedData, ErrorDescription);
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	SetItem(ThisObject, "Details", True, ErrorDescription, True, MergeResults);
	
EndProcedure

&AtServer
Procedure CheckAtServerSideAdditionalChecks(PasswordValue, CryptoManager = Undefined)
	
	ServerName = ComputerName();
	
	// Additional checks.
	For Each ListItem In AdditionalChecks Do
		
		ErrorDescription = "";
		IsWarning = False;
		Try
			ExecutionParameters = New Structure;
			ExecutionParameters.Insert("Certificate",           Certificate);
			ExecutionParameters.Insert("Validation",             ListItem.Name);
			ExecutionParameters.Insert("CryptoManager", CryptoManager);
			ExecutionParameters.Insert("ErrorDescription",       ErrorDescription);
			ExecutionParameters.Insert("IsWarning",    IsWarning);
			ExecutionParameters.Insert("Password",               ?(EnterPassword, PasswordValue, Undefined));
			ExecutionParameters.Insert("ChecksResults",   ChecksAtServer);
			
			DigitalSignatureOverridable.OnAdditionalCertificateCheck(ExecutionParameters);
			
			ErrorDescription    = ExecutionParameters.ErrorDescription;
			IsWarning = ExecutionParameters.IsWarning;
		Except
			ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		
		SetItem(ThisObject, ListItem.Name, True,
			ErrorDescription, IsWarning <> True, MergeResults);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormItemsManagement

&AtServer
Procedure AddPicture(TagName, Parent, Picture = Undefined)
	
	Decoration = Items.Add(TagName, Type("FormDecoration"), Parent);
	Decoration.Type = FormDecorationType.Picture;
	Decoration.Width = 2;
	Decoration.Height = 1;
	Decoration.Picture = ?(Picture = Undefined, New Picture, Picture);
	Decoration.PictureSize = PictureSize.AutoSize;
	
EndProcedure

&AtServer
Procedure AddItemsDescriptionsErrors(CheckName, Parent, AtServer = False)
	
	ErrorGroupClient = FormGroupWithoutDisplay(
			CheckName + ?(AtServer, "ErrorServer", "ErrorClient"), Parent,
			ChildFormItemsGroup.AlwaysHorizontal);
	ErrorGroupClient.Visible = False;
		
	AddPicture(CheckName + ?(AtServer, "ErrorServerImage", "ErrorClientPicture"),
		ErrorGroupClient, PictureLib[?(AtServer, "ComputerServer", "ComputerClient")]);
	Label = Items.Add(CheckName + ?(AtServer, "ErrorServerInscription", "ErrorClientInscription"),
		Type("FormDecoration"), ErrorGroupClient);
	Label.TextColor = StyleColors.NoteText;
	Label = Items.Add(CheckName + ?(AtServer, "DecisionServerLabel", "DecisionClientLabel"),
		Type("FormDecoration"), Parent);
	Label.TextColor = StyleColors.NoteText;
	Label.SetAction("URLProcessing", "Attachable_LabelURLProcessing");
	
EndProcedure

&AtServer
Function FormGroupWithoutDisplay(GroupName, Parent, Grouping = Undefined)
	
	Var_Group = Items.Add(GroupName, Type("FormGroup"), Parent);
	Var_Group.Type = FormGroupType.UsualGroup;
	Var_Group.Representation = UsualGroupRepresentation.None;
	Var_Group.ShowTitle = False;
	
	Var_Group.Group = ?(Grouping = Undefined,
		ChildFormItemsGroup.AlwaysHorizontal, Grouping);
		
	Return Var_Group;
	
EndFunction

&AtServer
Procedure RefreshVisibilityAtServer()
	
	OperationsAtServer = (DigitalSignature.VerifyDigitalSignaturesOnTheServer()
		Or DigitalSignature.GenerateDigitalSignaturesAtServer());
		
	VerifyDigitalSignaturesOnTheServer = Constants.VerifyDigitalSignaturesOnTheServer.Get();
		
	CheckInService = (IsBuiltInCryptoProvider Or ThisServiceAccount 
		Or VerifyDigitalSignaturesOnTheServer And (HaveServiceAccount Or HasBuiltinCryptoprovider));
		
	VisibilityCheckOnServer = OperationsAtServer Or CheckInService;
	VisibilityColumnsOnServer = VisibilityCheckOnServer And MergeResults <> "MergeByAnd" And MergeResults <> "MergeByOr";
	
	Items.HeaderGroup.Visible = VisibilityCheckOnServer;
	
	For Each Validation In StandardChecks() Do
		Items[Validation + "ErrorClientPicture"].Visible = VisibilityCheckOnServer;
		Items[Validation + "AtServerPicture"].Visible = VisibilityColumnsOnServer;
	EndDo;
	
	For Each Validation In AdditionalChecks Do
		Items[Validation.Name + "ErrorClientPicture"].Visible = VisibilityCheckOnServer;
		Items[Validation.Name + "AtServerPicture"].Visible = VisibilityColumnsOnServer;
	EndDo;
	
	Items.ChecksOnServerPicture.Visible = VisibilityColumnsOnServer;
	Items.ChecksOnClientPicture.Visible = VisibilityColumnsOnServer;
	
EndProcedure

&AtServer
Procedure OutputCheckResult(Validation, AtServer = False)
	
	ChecksResults = ThisObject[?(AtServer, "ChecksAtServer", "ChecksAtClient")];
	Additional_DataChecks = ThisObject[?(AtServer, "AdditionalDataChecksOnServer", "AdditionalDataChecksOnClient")];
	
	If ChecksResults <> Undefined Then
		
		CheckResult = ChecksResults[Validation];
		If CheckResult = Undefined Then
			SetItem(ThisObject, Validation, AtServer, , , MergeResults);
		Else
			
			ErrorsOnCheck = ?(ChecksResults.Property(Validation + "Error"),
				ChecksResults[Validation + "Error"], "");
				
			If Additional_DataChecks.Property(Validation) Then
				Structure = Additional_DataChecks[Validation];
				Structure.Insert("ErrorText", ErrorsOnCheck);
				SetItem(ThisObject, Validation, AtServer,
					Structure, Not CheckResult, MergeResults);
			Else
				SetItem(ThisObject, Validation, AtServer,
					ErrorsOnCheck, Not CheckResult, MergeResults);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetItem(Form, StartElement, AtServer,
	ErrorDescription = Undefined, IsError = False, MergeResults = "DontMerge")
	
	ItemLabel = Form.Items[StartElement + "Label"]; // 
	
	If MergeResults = "MergeByAnd"
		Or MergeResults = "MergeByOr" Then
		
		ItemPicture1 = Form.Items[StartElement + "AtClientPicture"]; // FormDecoration
		
	Else
		ItemPicture1 = Form.Items[StartElement
			+ ?(AtServer, "AtServerPicture", "AtClientPicture")]; // FormDecoration
	EndIf;
	
	Checks = Form[?(AtServer, "ChecksAtServer", "ChecksAtClient")];
	SecondContextChecks = Form[?(AtServer, "ChecksAtClient", "ChecksAtServer")];
	
	SecondContextCheckValue = Undefined;
	If TypeOf(SecondContextChecks) = Type("Structure")
		And SecondContextChecks.Property(StartElement) Then
		
		SecondContextCheckValue = SecondContextChecks[StartElement];
	EndIf;
	
	WarningAfterCheckingUC = Undefined;
	If TypeOf(ErrorDescription) = Type("Structure") Then
		WarningAfterCheckingUC = ErrorDescription;
		ErrorDescription = WarningAfterCheckingUC.ErrorText;
		Additional_DataChecks = Form[?(AtServer, "AdditionalDataChecksOnServer", "AdditionalDataChecksOnClient")];
		Additional_DataChecks.Insert(StartElement,
			New Structure("Cause, Decision", WarningAfterCheckingUC.Cause, WarningAfterCheckingUC.Decision));
		Form[?(AtServer, "AdditionalDataChecksOnServer", "AdditionalDataChecksOnClient")] = Additional_DataChecks;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		
		CheckValue = False;
		CheckResult = CheckValue;
		If MergeResults = "MergeByOr"
			And SecondContextCheckValue <> Undefined Then
			
			CheckResult = False Or SecondContextCheckValue;
		EndIf;
		
		If Not CheckResult Then
			ErrorGroup = Form.Items[StartElement + ?(AtServer, "ErrorServer", "ErrorClient")];
			ErrorGroup.Visible = True;
			ItemPicture1.Picture = ?(IsError,
				PictureLib.CertificateCheckError,
				PictureLib.CertificateCheckWarning);
			
			ItemPicture1.ToolTip = ErrorDescription;
			ItemLabel.Hyperlink = True;
			
			ElementInscriptionError = Form.Items[StartElement + ?(AtServer, "ErrorServer", "ErrorClient") + "Label"]; // 
			ElementInscriptionError.Title = ErrorDescription;
		
			If WarningAfterCheckingUC = Undefined Then
				KnownErrorDescription = ClassifierError(ErrorDescription, AtServer);
				IsKnownError = KnownErrorDescription <> Undefined;
				
				LabelNameSolution = StartElement + ?(AtServer, "DecisionServerLabel", "DecisionClientLabel");
				Form.Items[LabelNameSolution].Visible = IsKnownError;
				If IsKnownError Then
					Form.Items[LabelNameSolution].Title = KnownErrorDescription.Decision;
				EndIf;
			Else
				LabelNameSolution = StartElement + ?(AtServer, "DecisionServerLabel", "DecisionClientLabel");
				Form.Items[LabelNameSolution].Visible = True;
				Form.Items[LabelNameSolution].Title = WarningAfterCheckingUC.Decision;
			EndIf;
		EndIf;
		
	Else
		
		ErrorGroup = Form.Items[StartElement + ?(AtServer, "ErrorServer", "ErrorClient")];
		ItemDecision = Form.Items[StartElement
			+ ?(AtServer, "DecisionServerLabel", "DecisionClientLabel")];
		CheckValue = ?(ErrorDescription = Undefined, Undefined, True);
		
		If (MergeResults = "MergeByAnd"
			Or MergeResults = "MergeByOr") Then
			
			If CheckValue = Undefined
				And SecondContextCheckValue = Undefined Then
				
				ErrorGroup.Visible = False;
				ItemDecision.Visible = False;
				ItemPicture1.Picture = PictureLib.NoCertificateCheckPerformed;
				ItemPicture1.ToolTip = NStr("en = 'No check was performed.';");
				ItemLabel.Hyperlink = False;
				ItemLabel.Title = ItemTitle(
					Form.AdditionalChecks, ItemLabel.Name);
				
			ElsIf CheckValue = Undefined
				And SecondContextCheckValue <> Undefined Then
				
				Checks.Insert(StartElement, CheckValue);
				Checks.Insert(StartElement + "Error",
					?(ErrorDescription = Undefined, "", ErrorDescription));
				Return;
				
			ElsIf CheckValue <> Undefined
				And SecondContextCheckValue = Undefined Then
				
				ErrorGroup.Visible = False;
				ItemDecision.Visible = False;
				ItemPicture1.Picture = PictureLib.CertificateCheckSuccess;
				ItemPicture1.ToolTip = NStr("en = 'Check succeeded.';");
				ItemLabel.Hyperlink = False;
				ItemLabel.Title = ItemTitle(
					Form.AdditionalChecks, ItemLabel.Name);
			Else
				CheckResult = ?(MergeResults = "MergeByAnd",
					CheckValue And SecondContextCheckValue,
					CheckValue Or SecondContextCheckValue);
					
				If CheckResult Then
					ErrorGroup.Visible = False;
					ItemDecision.Visible = False;
					ItemPicture1.Picture = PictureLib.CertificateCheckSuccess;
					ItemPicture1.ToolTip = NStr("en = 'Check succeeded.';");
					ItemLabel.Hyperlink = False;
					ItemLabel.Title = ItemTitle(
						Form.AdditionalChecks, ItemLabel.Name);
				EndIf;
			EndIf;
		Else
			ItemPicture1.Picture = ?(ErrorDescription = Undefined,
				PictureLib.NoCertificateCheckPerformed,
				PictureLib.CertificateCheckSuccess);
			ItemPicture1.ToolTip = ?(ErrorDescription = Undefined,
				NStr("en = 'No check was performed.';"),
				NStr("en = 'Check succeeded.';"));
			
			If SecondContextChecks = Undefined
				Or Not SecondContextChecks.Property(StartElement + "Error")
				Or IsBlankString(SecondContextChecks[StartElement + "Error"]) Then
				
				ErrorGroup.Visible = False;
				ItemDecision.Visible = False;
				ItemLabel.Hyperlink = False;
				ItemLabel.Title = ItemTitle(
					Form.AdditionalChecks, ItemLabel.Name);
			EndIf;
		EndIf;
	EndIf;
	
	Checks.Insert(StartElement, CheckValue);
	Checks.Insert(StartElement + "Error",
		?(ErrorDescription = Undefined, "", ErrorDescription));
		
EndProcedure

&AtClientAtServerNoContext
Function ItemTitle(AdditionalChecks, TagName)
	
	ItemTitle = StandardItemTitle(TagName);
	If Not IsBlankString(ItemTitle) Then
		Return ItemTitle;
	EndIf;
		
	For Each Validation In AdditionalChecks Do
		
		If Validation.Name + "Label" = TagName Then
			Return Validation.Presentation;
		EndIf;
		
	EndDo;
	
	Return "";
	
EndFunction

&AtClientAtServerNoContext
Function StandardItemTitle(TagName)
	
	If TagName = "LegalCertificateLabel" Then
		Return NStr("en = 'Compliance with legislation of the Russian Federation';");
		
	ElsIf TagName = "CertificateExistsLabel" Then
		Return NStr("en = 'Existence of certificate in the private list';");
		
	ElsIf TagName = "CertificateDataLabel" Then
		Return NStr("en = 'Certificate data accuracy';");
		
	ElsIf TagName = "ProgramExistsLabel" Then
		Return NStr("en = 'Existence of application for signing and decryption';");
		
	ElsIf TagName = "SigningLabel" Then
		Return NStr("en = 'Data signing';");
		
	ElsIf TagName = "CheckSignatureLabel" Then
		Return NStr("en = 'Check created signature';");
		
	ElsIf TagName = "EncryptionLabel" Then
		Return NStr("en = 'Data encryption';");
		
	ElsIf TagName = "DetailsLabel" Then
		Return NStr("en = 'Data decryption';");
	Else
		Return "";
	EndIf;
	
EndFunction

#EndRegion

&AtClient
Procedure SupplementTextWithErrors(ErrorsText, Checks, AtServer = False)
	
	ChecksContent = ThisObject[?(AtServer, "ChecksAtServer", "ChecksAtClient")];
	For Each Validation In Checks Do
		
		If ChecksContent = Undefined Then
			ErrorsText = ErrorsText + Validation + ": "
				+ NStr("en = 'Not performed as it is not necessary (not configured)';") + Chars.LF;
		Else
			
			CheckResult = ?(ChecksContent.Property(Validation),
				ChecksAtClient[Validation], Undefined);
			
			CheckErrorText = ?(ChecksContent.Property(Validation + "Error"),
				TrimAll(ChecksAtClient[Validation + "Error"]), "");
			
			ErrorsText = ErrorsText + Validation + ": "
				+ ?(CheckResult = Undefined, NStr("en = 'Not performed because of previous errors';"),
				Format(CheckResult, NStr("en = 'BF=Error; BT=Success';")))
				+ ?(IsBlankString(CheckErrorText), "", " """ + CheckErrorText + """") + Chars.LF;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ClassifierError(ErrorDescription, ErrorAtServer)
	
	Return DigitalSignatureInternal.ClassifierError(ErrorDescription, ErrorAtServer);
	
EndFunction

&AtClientAtServerNoContext
Function StandardChecks()
	
	StandardChecks = New Array;
	StandardChecks.Add("LegalCertificate");
	StandardChecks.Add("CertificateExists");
	StandardChecks.Add("CertificateData");
	StandardChecks.Add("ProgramExists");
	StandardChecks.Add("Signing");
	StandardChecks.Add("CheckSignature");
	StandardChecks.Add("Encryption");
	StandardChecks.Add("Details");
	
	Return StandardChecks;
	
EndFunction

&AtClient
Function AdditionalData(ErrorName = Undefined)
	
	AdditionalData = DigitalSignatureInternalClient.AdditionalDataForErrorClassifier();
	AdditionalData.Certificate = Certificate;
	AdditionalData.CertificateData = CertificateAddress;

	If ErrorName <> Undefined Then
		AdditionalData.AdditionalDataChecksOnClient = 
			CommonClientServer.StructureProperty(AdditionalDataChecksOnClient, ErrorName, Undefined);
		AdditionalData.AdditionalDataChecksOnServer =
			CommonClientServer.StructureProperty(AdditionalDataChecksOnServer, ErrorName, Undefined);
	EndIf;
	
	Return AdditionalData;
	
EndFunction

&AtClient
Procedure AdditionalCheckOnthePossibilityofSigning(CryptoCertificate, ExecutionSide, ErrorDescription)
	
	If Revoked Then
		ErrorCertificateMarkedAsRevoked = ErrorCertificateMarkedAsRevoked();
		ErrorDescription = ErrorCertificateMarkedAsRevoked.ErrorText;
		SetItem(ThisObject, "Signing", ExecutionSide, ErrorCertificateMarkedAsRevoked, True, MergeResults);
	Else
		
		ResultofCertificateAuthorityVerification = DigitalSignatureInternalClient.ResultofCertificateAuthorityVerification(CryptoCertificate);
		
		If Not ResultofCertificateAuthorityVerification.Valid_SSLyf Then
			
			SigningAllowed = CommonServerCall.CommonSettingsStorageLoad(
				Certificate, "AllowSigning", Undefined);
		
			If SigningAllowed = Undefined Or Not SigningAllowed Then
				ErrorDescription = ResultofCertificateAuthorityVerification.Warning.ErrorText;
				SetItem(ThisObject, "Signing", ExecutionSide, ResultofCertificateAuthorityVerification.Warning, True,
					MergeResults);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ErrorCertificateMarkedAsRevoked()
	
	Return DigitalSignatureInternal.ErrorCertificateMarkedAsRevoked()
	
EndFunction 

&AtServer
Procedure UpdateCertificateInformation()
	
	CertificateProperties = Common.ObjectAttributesValues(Certificate,
		"Application, EnterPasswordInDigitalSignatureApplication, Revoked");
	
	Revoked = CertificateProperties.Revoked;
	Application = CertificateProperties.Application;
	CertificateEnterPasswordInElectronicSignatureProgram = CertificateProperties.EnterPasswordInDigitalSignatureApplication;

EndProcedure

#EndRegion