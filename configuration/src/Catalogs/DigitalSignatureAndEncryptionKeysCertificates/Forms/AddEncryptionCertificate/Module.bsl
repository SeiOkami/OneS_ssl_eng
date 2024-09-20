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
	
	DigitalSignatureInternal.SetVisibilityOfRefToAppsTroubleshootingGuide(Items.Instruction);
	
	HaveRightToAddInDirectory = AccessRight("Insert",
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates);
	
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
	
	CertificateAttributeParameters =
		DigitalSignatureInternal.NewParametersForCertificateDetails();
	
	If Parameters.Property("Organization") Then
		CertificateAttributeParameters.Insert("Organization", Parameters.Organization);
	EndIf;
	
	If ValueIsFilled(Parameters.CertificateDataAddress) Then
		CertificateData = GetFromTempStorage(Parameters.CertificateDataAddress);
		
		CryptoCertificate = DigitalSignatureInternal.CertificateFromBinaryData(CertificateData);
		If CryptoCertificate = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
		ShowCertificatePropertiesAdjustmentPage(ThisObject,
			CryptoCertificate,
			CryptoCertificate.Unload(),
			DigitalSignature.CertificateProperties(CryptoCertificate));
		
		Items.Back.Visible = False;
	Else
		If DigitalSignature.GenerateDigitalSignaturesAtServer() Then
			Items.CertificatesGroup.Title =
				NStr("en = 'Personal certificates on computer and on server';");
		EndIf;
		
		ErrorOnGetCertificatesAtClient = Parameters.ErrorOnGetCertificatesAtClient;
		UpdateCertificatesListAtServer(Parameters.CertificatesPropertiesAtClient);
	EndIf;
	
	If Metadata.DefinedTypes.Organization.Type.ContainsType(Type("String")) Then
		Items.CertificateCompany.Visible = False;
	Else
		CompanyTypeToDefineConfigured = True;
	EndIf;
	
	If Metadata.DefinedTypes.Individual.Type.ContainsType(Type("String")) Then
		Items.GroupInidividual.Visible = False;
	EndIf;
	
	Items.CertificateUser1.ToolTip =
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.User.Tooltip;
	
	Items.CertificateCompany.ToolTip =
		Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.Organization.Tooltip;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(Certificate) Then
		Cancel = True;
		Return;
	EndIf;
	
	If ValueIsFilled(AddressOfCertificate) Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers") Then
		
		RefreshReusableValues();
		If Items.Back.Visible Then
			UpdateCertificatesList();
		EndIf;
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
	
	DigitalSignatureClient.OpenCertificate(CurrentData.Thumbprint, Not CurrentData.IsRequest);
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	If Items.Certificates.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select certificates that you want to add.';"));
		Return;
	EndIf;
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData.IsRequest Then
		ShowMessageBox(,
			NStr("en = 'The application for issue for this certificate has not been processed yet.
			           |Open the application for certificate issue and perform the required steps.';"));
		UpdateCertificatesList();
		Return;
	EndIf;
	
	If Not HaveRightToAddInDirectory And Not CurrentData.Isinthedirectory Then
		ShowMessageBox(,
			NStr("en = 'Insufficient rights to use certificates that are not in the catalog.';"));
		Return;
	EndIf;
	
	Items.Next.Enabled = False;
	
	Account = Undefined;
	If DigitalSignatureInternalClientServer.PlacementOfTheCertificate(CurrentData.LocationType) = "CloudSignature" Then
		TheDSSCryptographyServiceModuleClientServer = CommonClient.CommonModule("DSSCryptographyServiceClientServer");
		TheDSSCryptographyServiceModuleInternalServerCall = CommonClient.CommonModule("DSSCryptographyServiceInternalServerCall");
		TheDSSCryptographyServiceModuleClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		
		CertificateThumbprint = TheDSSCryptographyServiceModuleClientServer.TransformFingerprint(CurrentData.Thumbprint);
		UserSettings = TheDSSCryptographyServiceModuleInternalServerCall.GetUserSettingsByCertificate(CertificateThumbprint);
		Account = UserSettings.Ref;

		OperationParametersList = New Structure;
		OperationParametersList.Insert("GetBinaryData", True);

		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", CertificateThumbprint);
		
		TheDSSCryptographyServiceModuleClient.FindCertificate(New NotifyDescription(
			"NextAfterSearchingForTheCertificateTheCloudSignature", ThisObject, Account), TheStructureOfTheSearch, OperationParametersList);
	
	ElsIf DigitalSignatureInternalClient.UseDigitalSignatureSaaS() And CurrentData.InCloudService Then
		TheStructureOfTheSearch = New Structure;
		TheStructureOfTheSearch.Insert("Thumbprint", Base64Value(CurrentData.Thumbprint));
		ModuleCertificateStoreClient = CommonClient.CommonModule("CertificatesStorageClient");
		ModuleCertificateStoreClient.FindCertificate(New NotifyDescription(
			"NextAfterCertificateSearchInCloudService", ThisObject), TheStructureOfTheSearch);
	Else
		DigitalSignatureInternalClient.GetCertificateByThumbprint(New NotifyDescription(
			"NextAfterCertificateSearch", ThisObject), CurrentData.Thumbprint, False, Undefined);
	EndIf;
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterCertificateSearch(Result, Context) Export
	
	If TypeOf(Result) = Type("CryptoCertificate") Then
		Result.BeginUnloading(New NotifyDescription(
			"NextAfterCertificateExport", ThisObject, Result));
		Return;
	EndIf;
	
	Context = New Structure;
	
	If Result.Property("CertificateNotFound") Then
		Context.Insert("ErrorDescription", NStr("en = 'The certificate is not installed on the computer (it might have been deleted).';"));
	Else
		Context.Insert("ErrorDescription", Result.ErrorDescription);
	EndIf;
	
	UpdateCertificatesList(New NotifyDescription(
		"NextAfterCertificatesListUpdate", ThisObject, Context));
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterSearchingForTheCertificateTheCloudSignature(Result, Context) Export
	
	If Not Result.Completed2 Then
		Context = New Structure;
		Context.Insert("ErrorDescription", Result.Error);
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
		Return;
	EndIf;
		
	If Not ValueIsFilled(Result.CertificateData) Then
		Context = New Structure;
		Context.Insert("ErrorDescription", NStr("en = 'The certificate does not exist in the service. It might have been deleted.';"));
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
		Return;
	EndIf;
		
	NextAfterCertificateExport(Result.CertificateData.Certificate, Result.CertificateData);
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterCertificateExport(ExportedData, CryptoCertificate) Export
	
	ShowCertificatePropertiesAdjustmentPage(ThisObject,
		CryptoCertificate,
		ExportedData,
		DigitalSignatureClient.CertificateProperties(CryptoCertificate));
	
EndProcedure

// Continues the Next procedure.
&AtClient
Procedure NextAfterCertificatesListUpdate(Result, Context) Export
	
	ShowMessageBox(, Context.ErrorDescription);
	Items.Next.Enabled = True;
	
EndProcedure

// Continues the Next procedure.
//
// Parameters:
//   Result - Structure:
//   * ErrorDescription - Structure:
//   ** LongDesc - String
//   Context - Structure
//
&AtClient
Procedure NextAfterCertificateSearchInCloudService(Result, Context) Export
	
	If Not Result.Completed2 Then
		Context = New Structure;
		Context.Insert("ErrorDescription", Result.ErrorDescription.LongDesc);
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
		Return;
	EndIf;
		
	If Not ValueIsFilled(Result.Certificate) Then
		Context = New Structure;
		Context.Insert("ErrorDescription", NStr("en = 'The certificate does not exist in the service. It might have been deleted.';"));
		UpdateCertificatesList(New NotifyDescription(
			"NextAfterCertificatesListUpdate", ThisObject, Context));
		Return;
	EndIf;
		
	NextAfterCertificateExport(Result.Certificate.Certificate, Result.Certificate);
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.Pages.CurrentPage = Items.CertificateSelectionPage;
	Items.Next.DefaultButton = True;
	
	UpdateCertificatesList();
	
EndProcedure

&AtClient
Procedure Add(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	AdditionalParameters = DigitalSignatureInternalClient.ParametersNotificationWhenWritingCertificate();
	If Not ValueIsFilled(Certificate) Then
		AdditionalParameters.IsNew = True;
	EndIf;
	
	WriteCertificateToCatalog();
	
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

&AtClientAtServerNoContext
Procedure ShowCertificatePropertiesAdjustmentPage(Form, CryptoCertificate, CertificateData, CertificateProperties)
	
	Items = Form.Items;
	
	Form.AddressOfCertificate = PutToTempStorage(CertificateData, Form.UUID);
	
	Form.ThumbprintOfCertificate = Base64String(CryptoCertificate.Thumbprint);
	
	DigitalSignatureInternalClientServer.FillCertificateDataDetails(
		Form.DetailsOfCertificateData, CertificateProperties);
	
	CertificateAttributeParameters = Form.CertificateAttributeParameters; // See DigitalSignatureInternal.NewParametersForCertificateDetails
	SavedProperties = SavedCertificateProperties(
		Form.ThumbprintOfCertificate,
		Form.AddressOfCertificate,
		CertificateAttributeParameters);
	
	If CertificateAttributeParameters.Property("Description") Then
		CertificateDescription = CertificateAttributeParameters.Description; 
		If CertificateDescription.ReadOnly Then
			Items.DescriptionCertificate.ReadOnly = True;
		EndIf;
	EndIf;
	
	If Form.CompanyTypeToDefineConfigured Then
		If CertificateAttributeParameters.Property("Organization") Then
			If Not CertificateAttributeParameters.Organization.Visible Then
				Items.CertificateCompany.Visible = False;
			ElsIf CertificateAttributeParameters.Organization.ReadOnly Then
				Items.CertificateCompany.ReadOnly = True;
			EndIf;
		EndIf;
	EndIf;
	
	Form.Certificate             = SavedProperties.Ref;
	Form.DescriptionCertificate = SavedProperties.Description;
	Form.CertificateUser1 = SavedProperties.User;
	Form.CertificateCompany  = SavedProperties.Organization;
	
	Items.Pages.CurrentPage   = Items.PromptForCertificatePropertiesPage;
	Items.Add.DefaultButton = True;
	Items.Next.Enabled          = True;
	
	String = ?(ValueIsFilled(Form.Certificate), NStr("en = 'Update';"), NStr("en = 'Add';"));
	If Items.Add.Title <> String Then
		Items.Add.Title = String;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SavedCertificateProperties(Val Thumbprint, Address, AttributesParameters)
	
	Return DigitalSignatureInternal.SavedCertificateProperties(Thumbprint, Address, AttributesParameters, True);
	
EndFunction

&AtClient
Procedure UpdateCertificatesList(Notification = Undefined)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	DigitalSignatureInternalClient.GetCertificatesPropertiesAtClient(New NotifyDescription(
		"UpdateCertificatesListFollowUp", ThisObject, Context), False, ShowAll);
	
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
	
	DigitalSignatureInternal.UpdateCertificatesList(Certificates, CertificatesPropertiesAtClient,
		True, False, ErrorGettingCertificatesAtServer, ShowAll);
	
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
		ValueIsFilled(ErrorOnGetCertificatesAtClient)
		And ValueIsFilled(ErrorOnGetCertificatesAtClient.ErrorDescription);
	
	Items.CertificatesUnavailableAtServerGroup.Visible =
		ValueIsFilled(ErrorGettingCertificatesAtServer)
		And ValueIsFilled(ErrorGettingCertificatesAtServer.ErrorDescription);
	
EndProcedure

&AtServer
Procedure WriteCertificateToCatalog()
	
	If ValueIsFilled(Account) Then
		DigitalSignatureInternal.WriteCertificateToCatalog(ThisObject, Account, True);
	Else	
		DigitalSignatureInternal.WriteCertificateToCatalog(ThisObject, , True);
	EndIf;	
	
EndProcedure

&AtClient
Procedure OnCloseIndividualChoiceForm(Value, Var_Parameters) Export

	If Value = Undefined Then
		Return;
	EndIf;
	
	CertificateIndividual = Value;

EndProcedure

#EndRegion
