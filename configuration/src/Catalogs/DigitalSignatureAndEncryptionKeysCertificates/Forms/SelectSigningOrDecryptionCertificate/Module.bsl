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
Var InternalData, PasswordProperties;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DigitalSignatureInternal.SetVisibilityOfRefToAppsTroubleshootingGuide(Items.Instruction);
	
	HaveRightToAddInDirectory = AccessRight("Insert",
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates);
	IsFullUser = Users.IsFullUser(Users.CurrentUser());
	
	ConditionalAppearance.Items.Clear();
	If Not HaveRightToAddInDirectory Then
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		
		AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
		AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
		AppearanceColorItem.Use = True;

		AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
		AppearanceField.Field = New DataCompositionField("Certificates");
		AppearanceField.Use = True;

		FilterElement = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterElement.LeftValue = New DataCompositionField("Certificates.Isinthedirectory");
		FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
		FilterElement.RightValue = False;
		FilterElement.Use = True;
	EndIf;
	
	DigitalSignatureInternal.SetPasswordEntryNote(ThisObject,
		Items.CertificateEnterPasswordInElectronicSignatureProgram.Name,
		Items.AdvancedPasswordNote.Name);
	
	CertificateAttributeParameters =
		DigitalSignatureInternal.NewParametersForCertificateDetails();
	
	If Parameters.Property("Organization") Then
		CertificateAttributeParameters.Insert("Organization", Parameters.Organization);
	EndIf;
	ExecuteAtServer = Parameters.ExecuteAtServer;
	
	HasCloudSignature = DigitalSignatureInternal.UseCloudSignatureService();
	
	FilterByCompany = Parameters.FilterByCompany;
	
	If Parameters.CanAddToList Then
		CanAddToList = True;
		Items.Select.Title = NStr("en = 'Add';");
		
		Items.AdvancedPasswordNote.Title =
			NStr("en = 'Click Add to enter the password.';");
		
		PersonalListOnAdd = Parameters.PersonalListOnAdd;
		Items.ShowAll.ToolTip =
			NStr("en = 'Show all certificates without filter (for example, including added and overdue)';");
	EndIf;
	
	ToEncryptAndDecrypt = Parameters.ToEncryptAndDecrypt;
	ReturnPassword = Parameters.ReturnPassword;
	
	If ToEncryptAndDecrypt = True Then
		If Parameters.CanAddToList Then
			Title = NStr("en = 'Add a certificate to encrypt and decrypt data';");
		Else
			Title = NStr("en = 'Select certificate to encrypt and decrypt data';");
		EndIf;
	ElsIf ToEncryptAndDecrypt = False Then
		If Parameters.CanAddToList Then
			Title = NStr("en = 'Add a certificate to sign data';");
		EndIf;
	ElsIf DigitalSignature.UseEncryption() Then
		Title = NStr("en = 'Add a certificate to sign and encrypt data';");
	Else
		Title = NStr("en = 'Add a certificate to sign data';");
	EndIf;
	
	If DigitalSignature.GenerateDigitalSignaturesAtServer()
	   And ExecuteAtServer <> False
	 Or HasCloudSignature Then
		
		If ExecuteAtServer = True Then
			Items.CertificatesGroup.Title =
				NStr("en = 'Personal certificates on the server';");
		Else
			Items.CertificatesGroup.Title =
				NStr("en = 'Personal certificates on computer and on server';");
		EndIf;
	EndIf;
	
	HasCompanies = Not Metadata.DefinedTypes.Organization.Type.ContainsType(Type("String"));
	Items.CertificateCompany.Visible = HasCompanies;
	
	Items.CertificateUser1.ToolTip =
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.User.Tooltip;
	
	Items.CertificateCompany.ToolTip =
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.Organization.Tooltip;
	
	If Metadata.DefinedTypes.Individual.Type.ContainsType(Type("String")) Then
		Items.GroupInidividual.Visible = False;
	EndIf;
	
	If ValueIsFilled(Parameters.SelectedCertificateThumbprint) Then
		SelectedCertificateThumbprintNotFound = False;
		SelectedCertificateThumbprint = Parameters.SelectedCertificateThumbprint;
	Else
		SelectedCertificateThumbprint = Common.ObjectAttributeValue(
			Parameters.SelectedCertificate, "Thumbprint");
	EndIf;
	
	ErrorOnGetCertificatesAtClient = Parameters.ErrorOnGetCertificatesAtClient;
	UpdateCertificatesListAtServer(Parameters.CertificatesPropertiesAtClient);
	
	If ValueIsFilled(Parameters.SelectedCertificateThumbprint)
	   And Parameters.SelectedCertificateThumbprint <> SelectedCertificateThumbprint Then
		
		SelectedCertificateThumbprintNotFound = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If InternalData = Undefined Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers") Then
		
		RefreshReusableValues();
		UpdateCertificatesList();
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") Then
		UpdateCertificatesList();
		Return;
	EndIf;
	
	If Upper(EventName) = Upper("InstallCryptoExtension")
		Or Upper(EventName) = Upper("Installation_AddInExtraCryptoAPI") Then
		UpdateCertificatesList();
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// 
	DigitalSignatureInternal.CheckPresentationUniqueness(
		DescriptionCertificate, Certificate, "DescriptionCertificate", Cancel);
		
	// Validate company value population.
	If Items.CertificateCompany.Visible
	   And Not Items.CertificateCompany.ReadOnly
	   And Items.CertificateCompany.AutoMarkIncomplete = True
	   And Not ValueIsFilled(CertificateCompany) Then
		
		MessageText = NStr("en = 'Company is not populated.';");
		Common.MessageToUser(MessageText,, "CertificateCompany",, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	ReturnValue = New Structure;
	ReturnValue.Insert("Ref", Certificate);
	ReturnValue.Insert("Added", ValueIsFilled(Certificate));
	Close(ReturnValue);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CertificatesUnavailableAtClientLabelClick(Item)
	
	DigitalSignatureInternalClient.ShowApplicationCallError(
		NStr("en = 'Certificates not available on computer';"),
		"",
		ErrorOnGetCertificatesAtClient,
		New Structure);
	
EndProcedure

&AtClient
Procedure CertificatesUnavailableAtServerLabelClick(Item)
	
	DigitalSignatureInternalClient.ShowApplicationCallError(
		NStr("en = 'Certificates not available on server';"),
		"",
		New Structure,
		ErrorGettingCertificatesAtServer);
	
EndProcedure

&AtClient
Procedure ShowAll1OnChange(Item)
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure InstructionClick(Item)
	
	DigitalSignatureInternalClient.OpenInstructionOfWorkWithApplications();
	
EndProcedure

&AtClient
Procedure CertificateEnterPasswordInElectronicSignatureProgramOnChange(Item)
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("OnChangeCertificateProperties", True));
	
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
Procedure RequiresAuthenticationOfCloudSignatureLabelClick(Item)
	
	TheNotificationIsAsFollows = New NotifyDescription("RequiresAuthenticationOfTheCloudSignatureInscriptionAfterAuthentication", ThisObject);
	OperationParametersList = New Structure();
	OperationParametersList.Insert("AccountsList", AccountsList.UnloadValues());
	
	TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
	TheDSSCryptographyServiceModuleClient.VerifyingUserAuthentication(TheNotificationIsAsFollows, Undefined, OperationParametersList);
	
EndProcedure

&AtClient
Procedure RequiresAuthenticationOfTheCloudSignatureInscriptionAfterAuthentication(CallResult, AdditionalParameters) Export
	
	If CallResult.Completed2 Then
		UpdateCertificatesList();
	EndIf;
	
EndProcedure

#EndRegion

#Region CertificatesFormTableItemEventHandlers

&AtClient
Procedure CertificatesSelection(Item, RowSelected, Field, StandardProcessing)
	
	Next(Undefined);
	
EndProcedure

&AtClient
Procedure CertificatesOnActivateRow(Item)
	
	If Items.Certificates.CurrentData = Undefined Then
		SelectedCertificateThumbprint = "";
	Else
		SelectedCertificateThumbprint = Items.Certificates.CurrentData.Thumbprint;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure ShowCurrentCertificateData(Command)
	
	CurrentData = Items.Certificates.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.LocationType = 3 Then
		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		CertificateThumbprint = New Structure();
		CertificateThumbprint.Insert("Thumbprint", TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(CurrentData.Thumbprint));
		
		OperationParametersList = New Structure;
		OperationParametersList.Insert("GetBinaryData", True);
		
		CycleParameters = New Structure("IsRequest", CurrentData.IsRequest);
		
		TheNotificationIsAsFollows = New NotifyDescription("OpenTheCloudSignatureCertificate", ThisObject, CycleParameters);
		TheDSSCryptographyServiceModuleClient.FindCertificate(TheNotificationIsAsFollows, CertificateThumbprint, OperationParametersList);
	Else
		DigitalSignatureClient.OpenCertificate(CurrentData.Thumbprint, Not CurrentData.IsRequest);
	EndIf;
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	Items.Next.Enabled = False;
	
	GoToCurrentCertificateChoice(New NotifyDescription(
		"NextAfterGoToCurrentCertificateSelection", ThisObject));
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterGoToCurrentCertificateSelection(Result, Context) Export
	
	If Result = True Then
		Items.Next.Enabled = True;
		Return;
	EndIf;
	
	Context = Result;
	
	If Context.UpdateCertificatesList Then
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
	Else
		NextAfterCertificatesListUpdate(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterCertificatesListUpdate(Result, Context) Export
	
	ShowMessageBox(, Context.ErrorDescription);
	Items.Next.Enabled = True;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.MainPages.CurrentPage = Items.CertificateSelectionPage;
	Items.Next.DefaultButton = True;
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If CloudSignatureCertificate Then
		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		TheDSSCryptographyServiceModuleInternalServerCall = CommonClient.CommonModule("DSSCryptographyServiceInternalServerCall");
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		
		CertificateThumbprint = TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(SelectedCertificateThumbprint);
		UserSettings = TheDSSCryptographyServiceModuleInternalServerCall.GetUserSettingsByCertificate(CertificateThumbprint);
		
		OperationParametersList = New Structure();
		OperationParametersList.Insert("Account", UserSettings.Ref);
		OperationParametersList.Insert("CertificateThumbprint", CertificateThumbprint);
		
		TheDSSCryptographyServiceModuleClient.CheckCertificate(
			New NotifyDescription("SelectAfterVerifyingTheCloudSignatureCertificate", ThisObject, OperationParametersList),
			UserSettings,
			GetFromTempStorage(AddressOfCertificate));
	
	ElsIf CertificateInCloudService Then
		
		ModuleCryptographyServiceClient = CommonClient.CommonModule("CryptographyServiceClient");
		ModuleCryptographyServiceClient.CheckCertificate(
			New NotifyDescription("SelectAfterCertificateCheckInSaaSMode", ThisObject, Undefined),
			GetFromTempStorage(AddressOfCertificate));
		
	Else
		
		CertificateParameters = DigitalSignatureClient.CertificateRecordParameters();
		CertificateParameters.Description = DescriptionCertificate;
		CertificateParameters.User = CertificateUser1;
		CertificateParameters.Organization = CertificateCompany;
		CertificateParameters.EnterPasswordInDigitalSignatureApplication = CertificateEnterPasswordInElectronicSignatureProgram;
		
		DigitalSignatureClient.WriteCertificateToCatalog(
			New NotifyDescription("SelectAfterCertificateCheck", ThisObject, Undefined),
			AddressOfCertificate, PasswordProperties.Value, ToEncryptAndDecrypt, CertificateParameters);
		
	EndIf;
	
EndProcedure

// Continues the Select procedure.
&AtClient
Procedure SelectAfterCertificateCheck(Result, Context) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters = DigitalSignatureInternalClient.ParametersNotificationWhenWritingCertificate();
	
	If Not ValueIsFilled(Certificate) Then
		AdditionalParameters.IsNew = True;
		AdditionalParameters.Is_Specified = True;
	EndIf;
	
	Certificate = Result;
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject,
		InternalData, PasswordProperties, New Structure("OnOperationSuccess", True));
	
	NotifyChanged(Certificate);
	Notify("Write_DigitalSignatureAndEncryptionKeysCertificates",
		AdditionalParameters, Certificate);
		
	If ReturnPassword Then
		
		InternalData.Insert("SelectedCertificate", Certificate);
		If Not RememberPassword Then
			InternalData.Insert("SelectedCertificatePassword", PasswordProperties.Value);
		EndIf;
		
		NotifyChoice(True);
		
	Else
		NotifyChoice(Certificate);
	EndIf;
	
EndProcedure

// Continues the Select procedure.
&AtClient                                                                   
Procedure SelectAfterVerifyingTheCloudSignatureCertificate(Result, Context) Export
	
	AdditionalParameters = DigitalSignatureInternalClient.ParametersNotificationWhenWritingCertificate();
	If Not Result.Completed2 Then
		ErrorDescription = Result.Error;
	ElsIf Not Result.Result Then
		ErrorDescription = DigitalSignatureInternalClientServer.ServiceErrorTextCertificateInvalid();
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		If ToEncryptAndDecrypt = True Then
			FormCaption = NStr("en = 'Encryption and decryption check';");
		Else
			FormCaption = NStr("en = 'Digital signature verification';");
		EndIf;
		DigitalSignatureInternalClient.ShowApplicationCallError(
			FormCaption, "", New Structure("ErrorDescription", ErrorDescription), New Structure);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Certificate) Then
		AdditionalParameters.IsNew = True;
	EndIf;
	
	WriteTheCertificateToTheCloudSignatureDirectory(Context.Account);
	
	NotifyChanged(Certificate);
	Notify("Write_DigitalSignatureAndEncryptionKeysCertificates",
		AdditionalParameters, Certificate);
		
	NotifyChoice(Certificate);
	
EndProcedure

// Continues the Select procedure.
&AtClient
Procedure SelectAfterCertificateCheckInSaaSMode(Result, Context) Export
	
	AdditionalParameters = DigitalSignatureInternalClient.ParametersNotificationWhenWritingCertificate();
	If Not Result.Completed2 Then
		ErrorDescription = ErrorProcessing.BriefErrorDescription(Result.ErrorInfo);
	ElsIf Not Result.Valid1 Then
		ErrorDescription = DigitalSignatureInternalClientServer.ServiceErrorTextCertificateInvalid();
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		If ToEncryptAndDecrypt = True Then
			FormCaption = NStr("en = 'Encryption and decryption check';");
		Else
			FormCaption = NStr("en = 'Digital signature verification';");
		EndIf;
		AdditionalParameters = New Structure("Certificate", AddressOfCertificate);
		DigitalSignatureInternalClient.ShowApplicationCallError(FormCaption,
			"", New Structure("ErrorDescription", ErrorDescription), New Structure, AdditionalParameters);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Certificate) Then
		AdditionalParameters.IsNew = True;
	EndIf;
	
	WriteCertificateToCatalogSaaS();
	
	NotifyChanged(Certificate);
	Notify("Write_DigitalSignatureAndEncryptionKeysCertificates",
		AdditionalParameters, Certificate);
		
	NotifyChoice(Certificate);
	
EndProcedure

&AtClient
Procedure ShowCertificateData(Command)
	
	If ValueIsFilled(AddressOfCertificate) Then
		DigitalSignatureClient.OpenCertificate(AddressOfCertificate, True);
	Else
		DigitalSignatureClient.OpenCertificate(ThumbprintOfCertificate, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure PickIndividual(Command)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Property", NStr("en = 'Owner:';"));
	CertificateDataDetailsStrings = DetailsOfCertificateData.FindRows(FilterParameters);
	If CertificateDataDetailsStrings.Count() = 0 Then
		CommonClient.MessageToUser(NStr("en = 'An appropriate individual does not exist.';"));
		Return;
	EndIf;
	
	IssuedTo = CertificateDataDetailsStrings[0].Value;
	
	DigitalSignatureInternalClient.PickIndividualForCertificate(ThisObject, IssuedTo, CertificateIndividual);

EndProcedure

#EndRegion

#Region Private

// CAC:78-off: to securely pass data between forms on the client without sending them to the server.
&AtClient
Procedure ContinueOpening(Notification, CommonInternalData) Export
// ACC:78-
	
	InternalData = CommonInternalData;
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	If SelectedCertificateThumbprintNotFound = Undefined
	 Or SelectedCertificateThumbprintNotFound = True Then
		
		ContinueOpeningAfterGoToChooseCurrentCertificate(Undefined, Context);
	Else
		GoToCurrentCertificateChoice(New NotifyDescription(
			"ContinueOpeningAfterGoToChooseCurrentCertificate", ThisObject, Context));
	EndIf;
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterGoToChooseCurrentCertificate(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		NotifyChoice(False);
	Else
		Open();
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

&AtServer
Function FillCurrentCertificatePropertiesAtServer(Val Thumbprint, SavedProperties);
	
	CryptoCertificate = DigitalSignatureInternal.GetCertificateByThumbprint(Thumbprint, False);
	If CryptoCertificate = Undefined Then
		Return False;
	EndIf;
	
	AddressOfCertificate = PutToTempStorage(CryptoCertificate.Unload(),
		UUID);
	
	ThumbprintOfCertificate = Thumbprint;
	
	DigitalSignatureInternalClientServer.FillCertificateDataDetails(DetailsOfCertificateData,
		DigitalSignature.CertificateProperties(CryptoCertificate));
	
	SavedProperties = SavedCertificateProperties(Thumbprint,
		AddressOfCertificate, CertificateAttributeParameters);
	
	Return True;
	
EndFunction

&AtServerNoContext
Function SavedCertificateProperties(Val Thumbprint, Val Address, AttributesParameters)
	
	Return DigitalSignatureInternal.SavedCertificateProperties(Thumbprint, Address, AttributesParameters);
	
EndFunction

&AtClient
Procedure UpdateCertificatesList(Notification = Undefined)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	If DigitalSignatureClient.GenerateDigitalSignaturesAtServer()
	   And ExecuteAtServer = True Then
		
		Result = New Structure;
		Result.Insert("CertificatesPropertiesAtClient", New Array);
		Result.Insert("ErrorOnGetCertificatesAtClient", New Structure);
		
		UpdateCertificatesListFollowUp(Result, Context);
	Else
		DigitalSignatureInternalClient.GetCertificatesPropertiesAtClient(New NotifyDescription(
			"UpdateCertificatesListFollowUp", ThisObject, Context), True, ShowAll);
	EndIf;
	
EndProcedure

// Continues the UpdateCertificatesList procedure.
&AtClient
Procedure UpdateCertificatesListFollowUp(Result, Context) Export
	
	ErrorOnGetCertificatesAtClient = Result.ErrorOnGetCertificatesAtClient;
	
	UpdateCertificatesListAtServer(Result.CertificatesPropertiesAtClient);
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCertificatesListAtServer(Val CertificatesPropertiesAtClient)
	
	ErrorGettingCertificatesAtServer = New Structure;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FilterByCompany", FilterByCompany);
	AdditionalParameters.Insert("ExecuteAtServer", ExecuteAtServer);
	
	DigitalSignatureInternal.UpdateCertificatesList(Certificates, CertificatesPropertiesAtClient,
		CanAddToList, True, ErrorGettingCertificatesAtServer, ShowAll, AdditionalParameters);
	
	If ValueIsFilled(SelectedCertificateThumbprint)
	   And (    Items.Certificates.CurrentRow = Undefined
	      Or Certificates.FindByID(Items.Certificates.CurrentRow) = Undefined
	      Or Certificates.FindByID(Items.Certificates.CurrentRow).Thumbprint
	              <> SelectedCertificateThumbprint) Then
		
		Filter = New Structure("Thumbprint", SelectedCertificateThumbprint);
		Rows = Certificates.FindRows(Filter);
		If Rows.Count() > 0 Then
			Items.Certificates.CurrentRow = Rows[0].GetID();
		EndIf;
	EndIf;
	
	Items.CertificatesUnavailableAtClientGroup.Visible =
		ValueIsFilled(ErrorOnGetCertificatesAtClient);
	
	Items.CertificatesUnavailableAtServerGroup.Visible =
		ValueIsFilled(ErrorGettingCertificatesAtServer);
	
	AuthenticationVisibility = False;
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		TheDSSCryptographyServiceModuleInternal = Common.CommonModule("DSSCryptographyServiceInternal");
		AccountsList.LoadValues(TheDSSCryptographyServiceModuleInternal.AccountsWithoutCertificates());
		AuthenticationVisibility = AccountsList.Count() > 0;
	EndIf;
	
	Items.CloudSignatureAuthorizationGroup.Visible = AuthenticationVisibility;
	
	If Items.Certificates.CurrentRow = Undefined Then
		SelectedCertificateThumbprint = "";
	Else
		String = Certificates.FindByID(Items.Certificates.CurrentRow);
		SelectedCertificateThumbprint = ?(String = Undefined, "", String.Thumbprint);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenTheCloudSignatureCertificate(SearchResult, AdditionalParameters) Export
	
	If SearchResult.Completed2 Then
		DigitalSignatureClient.OpenCertificate(SearchResult.CertificateData.Certificate, Not AdditionalParameters.IsRequest);
	EndIf;	
	
EndProcedure	

&AtClient
Procedure GoToCurrentCertificateChoice(Notification)
	
	Result = New Structure;
	Result.Insert("ErrorDescription", "");
	Result.Insert("UpdateCertificatesList", False);
	
	If Items.Certificates.CurrentData = Undefined Then
		Result.ErrorDescription = NStr("en = 'Select a certificate to be used.';");
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData.IsRequest Then
		Result.UpdateCertificatesList = True;
		Result.ErrorDescription =
			NStr("en = 'The application for issue for this certificate has not been processed yet.
			           |Open the application for certificate issue and perform the required steps.';");
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	If Not HaveRightToAddInDirectory And Not CurrentData.Isinthedirectory Then
		Result.UpdateCertificatesList = True;
		Result.ErrorDescription =
			NStr("en = 'Insufficient rights to use certificates that are not in the catalog.';");
		ExecuteNotifyProcessing(Notification, Result);
		Return;
	EndIf;
	
	CertificateAtClient = CurrentData.AtClient;
	CertificateAtServer = CurrentData.AtServer;
	CertificateInCloudService = CurrentData.InCloudService;
	CloudSignatureCertificate = DigitalSignatureInternalClientServer.PlacementOfTheCertificate(CurrentData.LocationType) = "CloudSignature";
	
	Context = New Structure;
	Context.Insert("Notification",          Notification);
	Context.Insert("Result",           Result);
	Context.Insert("CurrentData",       CurrentData);
	Context.Insert("SavedProperties", Undefined);
	
	If CertificateAtServer Then
		If FillCurrentCertificatePropertiesAtServer(CurrentData.Thumbprint, Context.SavedProperties) Then
			GoToCurrentCertificateChoiceAfterFillCertificateProperties(Context);
		Else
			Result.ErrorDescription = NStr("en = 'Certificate does not exist on the server (it might have been deleted).';");
			Result.UpdateCertificatesList = True;
			ExecuteNotifyProcessing(Notification, Result);
		EndIf;
		Return;
	EndIf;
	
	If DigitalSignatureInternalClientServer.PlacementOfTheCertificate(CurrentData.LocationType) = "CloudSignature" Then
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		
		OperationParametersList = New Structure;
		OperationParametersList.Insert("GetBinaryData", True);

		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(CurrentData.Thumbprint));
		
		TheDSSCryptographyServiceModuleClient.FindCertificate(New NotifyDescription(
			"GoToTheCurrentCertificateSelectionAfterSearchingForTheCertificateInTheCloudSignature", ThisObject, Context), TheStructureOfTheSearch, OperationParametersList);
	
	ElsIf CurrentData.InCloudService Then
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", Base64Value(CurrentData.Thumbprint));
		ModuleCertificateStoreClient = CommonClient.CommonModule("CertificatesStorageClient");
		ModuleCertificateStoreClient.FindCertificate(New NotifyDescription(
			"GoToCurrentCertificateChoiceAfterCertificateSearchInCloudService", ThisObject, Context), TheStructureOfTheSearch);
	Else
		DigitalSignatureInternalClient.GetCertificateByThumbprint(
			New NotifyDescription("GoToCurrentCertificateChoiceAfterCertificateSearch", ThisObject, Context),
			CurrentData.Thumbprint, False, Undefined);
	EndIf;
	
EndProcedure

// Continues the GoToCurrentCertificateChoice procedure.
// 
// Parameters:
//   SearchResult - CryptoCertificate
//   Context - Structure
//
&AtClient
Procedure GoToCurrentCertificateChoiceAfterCertificateSearch(SearchResult, Context) Export
	
	If TypeOf(SearchResult) <> Type("CryptoCertificate") Then
		If SearchResult.Property("CertificateNotFound") Then
			Context.Result.ErrorDescription = NStr("en = 'The certificate is not installed on the computer (it might have been deleted).';");
		Else
			Context.Result.ErrorDescription = SearchResult.ErrorDescription;
		EndIf;
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	Context.Insert("CryptoCertificate", SearchResult);
	
	SearchResult.BeginUnloading(New NotifyDescription(
		"GoToCurrentCertificateChoiceAfterCertificateExport", ThisObject, Context));
	
EndProcedure

// Continues the GoToCurrentCertificateChoice procedure.
// 
// Parameters:
//   SearchResult - Structure:
//   * Completed2 - Boolean
//   * ErrorDescription - Structure:
//   ** LongDesc - String
//   Context - Structure
//
&AtClient
Procedure GoToCurrentCertificateChoiceAfterCertificateSearchInCloudService(SearchResult, Context) Export
	
	If Not SearchResult.Completed2 Then
		Context.Result.ErrorDescription = SearchResult.ErrorDescription.LongDesc;
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	If Not ValueIsFilled(SearchResult.Certificate) Then
		Context.Result.ErrorDescription = NStr("en = 'The certificate does not exist in the service. It might have been deleted.';");
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	Context.Insert("CryptoCertificate", SearchResult.Certificate);
	GoToCurrentCertificateChoiceAfterCertificateExport(SearchResult.Certificate.Certificate, Context);
	
EndProcedure

// Continues the GoToCurrentCertificateChoice procedure.
// 
// Parameters:
//   SearchResult - Structure:
//   * Completed2 - Boolean
//   * Error - String
//   Context - Structure
//
&AtClient
Procedure GoToTheCurrentCertificateSelectionAfterSearchingForTheCertificateInTheCloudSignature(SearchResult, Context) Export
	
	If Not SearchResult.Completed2 Then
		Context.Result.ErrorDescription = SearchResult.Error;
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	If Not ValueIsFilled(SearchResult.CertificateData) Then
		Context.Result.ErrorDescription = NStr("en = 'Certificate does not exist on the DSS server (it might have been deleted).';");
		Context.Result.UpdateCertificatesList = True;
		ExecuteNotifyProcessing(Context.Notification, Context.Result);
		Return;
	EndIf;
	
	Context.Insert("CryptoCertificate", SearchResult.CertificateData);
	GoToCurrentCertificateChoiceAfterCertificateExport(SearchResult.CertificateData.Certificate, Context);
	
EndProcedure

// Continues the GoToCurrentCertificateChoice procedure.
&AtClient
Procedure GoToCurrentCertificateChoiceAfterCertificateExport(ExportedData, Context) Export
	
	AddressOfCertificate = PutToTempStorage(ExportedData, UUID);
	
	ThumbprintOfCertificate = Context.CurrentData.Thumbprint;
	
	DigitalSignatureInternalClientServer.FillCertificateDataDetails(DetailsOfCertificateData,
		DigitalSignatureClient.CertificateProperties(Context.CryptoCertificate));
	
	Context.SavedProperties = SavedCertificateProperties(Context.CurrentData.Thumbprint,
		AddressOfCertificate, CertificateAttributeParameters);
		
	If ValueIsFilled(FilterByCompany) Then
		Context.SavedProperties.Insert("Organization", FilterByCompany);
	EndIf;
	
	GoToCurrentCertificateChoiceAfterFillCertificateProperties(Context);
	
EndProcedure

// Continues the GoToCurrentCertificateChoice procedure.
&AtClient
Procedure GoToCurrentCertificateChoiceAfterFillCertificateProperties(Context)
	
	If CertificateAttributeParameters.Property("Description") Then
		AttributesParameters = CertificateAttributeParameters; // See DigitalSignatureInternal.NewParametersForCertificateDetails
		If AttributesParameters.Description.ReadOnly Then
			Items.DescriptionCertificate.ReadOnly = True;
		EndIf;
	EndIf;
	
	If HasCompanies Then
		If CertificateAttributeParameters.Property("Organization") Then
			If Not CertificateAttributeParameters.Organization.Visible Then
				Items.CertificateCompany.Visible = False;
			ElsIf CertificateAttributeParameters.Organization.ReadOnly Then
				Items.CertificateCompany.ReadOnly = True;
			ElsIf CertificateAttributeParameters.Organization.FillChecking Then
				Items.CertificateCompany.AutoMarkIncomplete = True;
			EndIf;
		EndIf;
	EndIf;
	
	If CertificateAttributeParameters.Property("EnterPasswordInDigitalSignatureApplication") Then
		If Not CertificateAttributeParameters.EnterPasswordInDigitalSignatureApplication.Visible Then
			Items.CertificateEnterPasswordInElectronicSignatureProgram.Visible = False;
		ElsIf CertificateAttributeParameters.EnterPasswordInDigitalSignatureApplication.ReadOnly Then
			Items.CertificateEnterPasswordInElectronicSignatureProgram.ReadOnly = True;
		EndIf;
	EndIf;
	
	CertificateUser1 = UsersClient.CurrentUser();
	If Not IsFullUser Then
		Items.CertificateUser1.ReadOnly = True;
	EndIf;
	
	Certificate             = Context.SavedProperties.Ref;
	CertificateCompany  = Context.SavedProperties.Organization;
	DescriptionCertificate = Context.SavedProperties.Description;
	CertificateEnterPasswordInElectronicSignatureProgram = Context.SavedProperties.EnterPasswordInDigitalSignatureApplication;
	
	DigitalSignatureInternalClient.ProcessPasswordInForm(ThisObject, InternalData, PasswordProperties);
	
	Items.MainPages.CurrentPage = Items.PromptForCertificatePropertiesPage;
	Items.Select.DefaultButton = True;
	
	If CanAddToList Then
		String = ?(ValueIsFilled(Certificate), NStr("en = 'Update';"), NStr("en = 'Add';"));
		If Items.Select.Title <> String Then
			Items.Select.Title = String;
		EndIf;
	EndIf;
	
	If CertificateInCloudService Or CloudSignatureCertificate Then
		Items.GroupEnterPasswordInElectronicSignatureProgram.Visible = False;
	Else
		Items.GroupEnterPasswordInElectronicSignatureProgram.Visible = True;
		AttachIdleHandler("IdleHandlerActivateItemPassword", 0.1, True);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

&AtClient
Procedure IdleHandlerActivateItemPassword()
	
	CurrentItem = Items.Password;
	
EndProcedure

&AtServer
Procedure WriteCertificateToCatalogSaaS()
	
	BuiltinCryptoprovider = DigitalSignatureInternal.BuiltinCryptoprovider();
	CertificateEnterPasswordInElectronicSignatureProgram = False;
	
	DigitalSignatureInternal.WriteCertificateToCatalog(ThisObject, BuiltinCryptoprovider, False);
	
EndProcedure

&AtServer
Procedure WriteTheCertificateToTheCloudSignatureDirectory(Account)
	
	CertificateEnterPasswordInElectronicSignatureProgram = False;
	
	DigitalSignatureInternal.WriteCertificateToCatalog(ThisObject, Account, False);
	
EndProcedure

&AtClient
Procedure OnCloseIndividualChoiceForm(Value, Var_Parameters) Export

	If Value = Undefined Then
		Return;
	EndIf;
	
	CertificateIndividual = Value;

EndProcedure

#EndRegion
