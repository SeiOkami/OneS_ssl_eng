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
	
	ErrorAtClient = Parameters.ErrorAtClient;
	
	If ValueIsFilled(Parameters.CertificateAddress) Then

		CertificateData = GetFromTempStorage(Parameters.CertificateAddress);
		If TypeOf(CertificateData) = Type("String") Then
			CertificateData = Base64Value(CertificateData);
		EndIf;
		Certificate = New CryptoCertificate(CertificateData);
		CertificateAddress = PutToTempStorage(CertificateData, UUID);
		
	ElsIf ValueIsFilled(Parameters.Ref) Then
		CertificateAddress = CertificateAddress(Parameters.Ref, UUID);
		
		If Not ValueIsFilled(CertificateAddress) Then
			ErrorAtServer = New Structure;
			ErrorAtServer.Insert("ErrorDescription", StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Certificate ""%1"",
				           |not found in the certificate catalog.';"), Parameters.Ref));
			Return;
		EndIf;
	Else // Thumbprint.
		CertificateAddress = CertificateAddress(Parameters.Thumbprint, UUID);
		
		If Not ValueIsFilled(CertificateAddress) Then
			ErrorAtServer = New Structure;
			ErrorAtServer.Insert("ErrorDescription", StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Certificate not found by thumbprint ""%1"".';"), Parameters.Thumbprint));
			Return;
		EndIf;
	EndIf;
	
	If CertificateData = Undefined Then
		CertificateData = GetFromTempStorage(CertificateAddress);
		Certificate = New CryptoCertificate(CertificateData);
	EndIf;
	
	CertificateProperties = DigitalSignature.CertificateProperties(Certificate);
	
	AssignmentSign = Certificate.UseToSign;
	AssignmentEncryption = Certificate.UseToEncrypt;
	
	Thumbprint      = CertificateProperties.Thumbprint;
	IssuedTo      = CertificateProperties.IssuedTo;
	IssuedBy       = CertificateProperties.IssuedBy;
	ValidBefore = CertificateProperties.EndDate;
	
	SignAlgorithm = DigitalSignatureInternalClientServer.CertificateSignAlgorithm(
		CertificateData, True);
	
	Items.SignAlgorithm.ToolTip =
		Metadata.Catalogs.DigitalSignatureAndEncryptionApplications.Attributes.SignAlgorithm.Tooltip;
		
	Items.GroupLicenseCryptoPro.Visible = DigitalSignatureInternal.ContainsEmbeddedLicenseCryptoPro(
		CertificateData);
	
	FillCertificatePurposeCodes(CertificateProperties.Purpose, AssignmentCodes);
	
	FillSubjectProperties(Certificate);
	FillIssuerProperties(Certificate);
	
	InternalFieldsGroup = "Overall";
	FillInternalCertificateFields();
	
	ComponentObject = Undefined;
	
	If DigitalSignature.CommonSettings().VerifyDigitalSignaturesOnTheServer
		Or DigitalSignature.CommonSettings().GenerateDigitalSignaturesAtServer Then
		
		ResultCertificatesChain = DigitalSignatureInternal.CertificatesChain(
			CertificateData, UUID, ComponentObject);
			
		If Not ValueIsFilled(ResultCertificatesChain.Error) Then
			For Each CurrentCertificate In ResultCertificatesChain.Certificates Do
				CryptoCertificate = New CryptoCertificate(
					Base64Value(GetFromTempStorage(CurrentCertificate.CertificateData)));
				NewRow = CertificationPath.Insert(0);
				NewRow.Presentation = DigitalSignature.CertificatePresentation(CryptoCertificate);
				NewRow.CertificateData = CurrentCertificate.CertificateData;
			EndDo;
			Items.GroupErrorGettingCertificatesChain.Visible = False;
		Else
			ErrorGettingCertificationPathAtServer = ResultCertificatesChain.Error;
			Items.GroupErrorGettingCertificatesChain.Visible = True;
		EndIf;
		
	EndIf;
	
	CertificatePropertiesExtended = DigitalSignatureInternal.CertificatePropertiesExtended(
		CertificateData, UUID, ComponentObject);
	ErrorGettingListOfRevocationListsAddresses = CertificatePropertiesExtended.Error;
	HasError = ValueIsFilled(CertificatePropertiesExtended.Error);
	Items.ErrorGettingListOfRevocationListsAddresses.Visible = HasError;
	Items.RevocationLists.Visible = Not HasError;
	If Not HasError Then
		For Each CurrentAddress In CertificatePropertiesExtended.CertificateProperties.AddressesOfRevocationLists Do
			NewRow = RevocationLists.Add();
			NewRow.Address = CurrentAddress;
		EndDo;
	EndIf;
		
	If Parameters.Property("OpeningFromCertificateItemForm") Then
		Items.FormSaveToFile.Visible = False;
		Items.FormValidate.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(ErrorAtServer) Then
		Cancel = True;
		DigitalSignatureInternalClient.ShowApplicationCallError(
			NStr("en = 'Cannot open the certificate';"), "", 
			ErrorAtClient, ErrorAtServer);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InternalFieldsGroupOnChange(Item)
	
	FillInternalCertificateFields();
	
EndProcedure

&AtClient
Procedure InternalFieldsGroupClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.PageRootCertificates 
		And (ValueIsFilled(ErrorGettingCertificationPathAtServer) Or CertificationPath.Count() = 0) Then
			
		PopulateRootCertificates();
		
	EndIf;
		
EndProcedure

&AtClient
Procedure DecorationErrorGettingCertificatesChainClick(Item)
	
	DigitalSignatureInternalClient.ShowApplicationCallError(
		NStr("en = 'Cannot receive a certification path';"), "", 
		New Structure("ErrorDescription", ErrorGettingCertificationPaths),
		New Structure("ErrorDescription", ErrorGettingCertificationPathAtServer));
		
EndProcedure

#EndRegion

#Region RevocationListsFormTableItemEventHandlers

&AtClient
Procedure RevocationListsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region RootCertificatesFormTableItemEventHandlers

&AtClient
Procedure RootCertificatesChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.CertificationPath.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CertificateAddress", CurrentData.CertificateData);

	OpenForm("CommonForm.Certificate", FormParameters);

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveToFile(Command)
	
	DigitalSignatureInternalClient.SaveCertificate(Undefined, CertificateAddress);
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	AdditionalInspectionParameters = DigitalSignatureInternalClient.AdditionalCertificateVerificationParameters();
	AdditionalInspectionParameters.MergeCertificateDataErrors = False;
	DigitalSignatureInternalClient.CheckCertificate(New NotifyDescription(
		"ValidateCompletion", ThisObject), CertificateAddress,,, AdditionalInspectionParameters);
	Items.FormValidate.Enabled = False;
	
EndProcedure

&AtClient
Procedure SetRevocationList(Command)
	
	RevocationListInstallationParameters = DigitalSignatureInternalClient.RevocationListInstallationParameters(CertificateAddress);
	DigitalSignatureInternalClient.SetListOfCertificateRevocation(RevocationListInstallationParameters);

EndProcedure

&AtClient
Procedure InstallCertificate(Command)
	
	CurrentData = Items.CertificationPath.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;

	BinaryData = Base64Value(GetFromTempStorage(CurrentData.CertificateData));
	CertificateInstallationParameters = DigitalSignatureInternalClient.CertificateInstallationParameters(
		PutToTempStorage(BinaryData, UUID));
		
	If CertificationPath.Count() > 1 Then
		
		If CurrentData.GetID() = CertificationPath[0].GetID() Then
			InstallationOptions = New ValueList;
			InstallationOptions.Add("ROOT", NStr("en = 'Trusted root certificates';"));
			InstallationOptions.Add("CA", NStr("en = 'Intermediate certificates';"));
			InstallationOptions.Add("MY", NStr("en = 'Personal certificate storage';"));
			InstallationOptions.Add("Container", NStr("en = 'Container and personal storage';"));
			CertificateInstallationParameters.InstallationOptions = InstallationOptions;
		ElsIf CurrentData.GetID() <> CertificationPath[CertificationPath.Count() - 1].GetID() Then
			InstallationOptions = New ValueList;
			InstallationOptions.Add("CA", NStr("en = 'Intermediate certificates';"));
			InstallationOptions.Add("ROOT", NStr("en = 'Trusted root certificates';"));
			InstallationOptions.Add("MY", NStr("en = 'Personal certificate storage';"));
			InstallationOptions.Add("Container", NStr("en = 'Container and personal storage';"));
			CertificateInstallationParameters.InstallationOptions = InstallationOptions;
		EndIf;
	EndIf;
	
	DigitalSignatureInternalClient.InstallCertificate(CertificateInstallationParameters);
	
EndProcedure

#EndRegion

#Region Private

// Continues the Check procedure.
&AtClient
Procedure ValidateCompletion(Result, Context) Export
	
	If Result = True Then
		ShowMessageBox(, NStr("en = 'Certificate is valid.';"));
	ElsIf Result <> Undefined Then
		
		AdditionalData = DigitalSignatureInternalClient.AdditionalDataForErrorClassifier();
		AdditionalData.CertificateData = CertificateAddress;
		
		WarningParameters = New Structure;
		WarningParameters.Insert("AdditionalData", AdditionalData);
		
		WarningParameters.Insert("WarningTitle",
			NStr("en = 'Certificate is invalid due to:';"));
		
		If TypeOf(Result) = Type("Structure") Then
			WarningParameters.Insert("ErrorTextClient",
				Result.ErrorDetailsAtClient);
			WarningParameters.Insert("ErrorTextServer",
				Result.ErrorDescriptionAtServer);
		Else
			WarningParameters.Insert("ErrorTextClient",
				Result);
		EndIf;
		OpenForm("CommonForm.ExtendedErrorPresentation",
			WarningParameters, ThisObject);
			
	EndIf;
	
	Items.FormValidate.Enabled = True;
	
EndProcedure

&AtServer
Procedure FillSubjectProperties(Certificate)
	
	Collection = DigitalSignature.CertificateSubjectProperties(Certificate);
	
	PropertiesPresentations = New Map;
	PropertiesPresentations["CommonName"] = NStr("en = 'Common name';");
	PropertiesPresentations["Country"] = NStr("en = 'Country';");
	PropertiesPresentations["State"] = NStr("en = 'State';");
	PropertiesPresentations["Locality"] = NStr("en = 'Locality';");
	PropertiesPresentations["Street"] = NStr("en = 'Street';");
	PropertiesPresentations["Organization"] = NStr("en = 'Company';");
	PropertiesPresentations["Department"] = NStr("en = 'Department';");
	PropertiesPresentations["Email"] = NStr("en = 'Email';");
	
	If Metadata.DataProcessors.Find("DigitalSignatureAndEncryptionApplications") <> Undefined Then
		CommonClientServer.SupplementMap(PropertiesPresentations,
			DataProcessors["DigitalSignatureAndEncryptionApplications"].PresentationOfCertificateSubjectProperties(), True);
	EndIf;
	
	For Each ListItem In PropertiesPresentations Do
		PropertyValue = CommonClientServer.StructureProperty(Collection, ListItem.Key);
		If Not ValueIsFilled(PropertyValue) Then
			Continue;
		EndIf;
		String = Subject.Add();
		String.Property = ListItem.Value;
		String.Value = PropertyValue;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillIssuerProperties(Certificate)
	
	Collection = DigitalSignature.CertificateIssuerProperties(Certificate);
	
	PropertiesPresentations = New Map;
	PropertiesPresentations["CommonName"] = NStr("en = 'Common name';");
	PropertiesPresentations["Country"] = NStr("en = 'Country';");
	PropertiesPresentations["State"] = NStr("en = 'State';");
	PropertiesPresentations["Locality"] = NStr("en = 'Locality';");
	PropertiesPresentations["Street"] = NStr("en = 'Street';");
	PropertiesPresentations["Organization"] = NStr("en = 'Company';");
	PropertiesPresentations["Department"] = NStr("en = 'Department';");
	PropertiesPresentations["Email"] = NStr("en = 'Email';");
	
	If Metadata.DataProcessors.Find("DigitalSignatureAndEncryptionApplications") <> Undefined Then
		CommonClientServer.SupplementMap(PropertiesPresentations,
			DataProcessors["DigitalSignatureAndEncryptionApplications"].CertificatePublisherPropertyPresentations(), True);
	EndIf;
	
	For Each ListItem In PropertiesPresentations Do
		PropertyValue = CommonClientServer.StructureProperty(Collection, ListItem.Key);
		If Not ValueIsFilled(PropertyValue) Then
			Continue;
		EndIf;
		String = Issuer.Add();
		String.Property = ListItem.Value;
		String.Value = PropertyValue;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillInternalCertificateFields()
	
	InternalContent.Clear();
	CertificateBinaryData = GetFromTempStorage(CertificateAddress);
	Certificate = New CryptoCertificate(CertificateBinaryData);
	
	If InternalFieldsGroup = "Overall" Then
		Items.InternalContentId.Visible = False;
		
		AddProperty(Certificate, "Version",                    NStr("en = 'Version';"));
		AddProperty(Certificate, "ValidFrom",                NStr("en = 'Start date';"));
		AddProperty(Certificate, "ValidTo",             NStr("en = 'End date';"));
		AddProperty(Certificate, "UseToSign",    NStr("en = 'Use for signature';"));
		AddProperty(Certificate, "UseToEncrypt", NStr("en = 'Use for encryption';"));
		AddProperty(Certificate, "PublicKey",              NStr("en = 'Public key';"), True);
		AddProperty(Certificate, "Thumbprint",                 NStr("en = 'Thumbprint';"), True);
		AddProperty(Certificate, "SerialNumber",             NStr("en = 'Serial number';"), True);
		
	ElsIf InternalFieldsGroup = "Extensions" Then
		Items.InternalContentId.Visible = False;
		
		Collection = Certificate.Extensions;
		For Each KeyAndValue In Collection Do
			AddProperty(Collection, KeyAndValue.Key, KeyAndValue.Key);
		EndDo;
	Else
		Items.InternalContentId.Visible = True;
		
		IDsNames = New ValueList;
		IDsNames.Add("OID2_5_4_3",              "CN");
		IDsNames.Add("OID2_5_4_6",              "C");
		IDsNames.Add("OID2_5_4_8",              "ST");
		IDsNames.Add("OID2_5_4_7",              "L");
		IDsNames.Add("OID2_5_4_9",              "Street");
		IDsNames.Add("OID2_5_4_10",             "O");
		IDsNames.Add("OID2_5_4_11",             "OU");
		IDsNames.Add("OID2_5_4_12",             "T");
		IDsNames.Add("OID1_2_840_113549_1_9_1", "E");
		
		IDsNames.Add("OID1_2_643_100_1",     "OGRN");
		IDsNames.Add("OID1_2_643_100_5",     "OGRNIP");
		IDsNames.Add("OID1_2_643_100_3",     "SNILS");
		IDsNames.Add("OID1_2_643_3_131_1_1", "INN");
		IDsNames.Add("OID1_2_643_100_4",     "INNLE");
		IDsNames.Add("OID2_5_4_4",           "SN");
		IDsNames.Add("OID2_5_4_42",          "GN");
		
		NamesAndIDs = New Map;
		Collection = Certificate[InternalFieldsGroup];
		
		For Each ListItem In IDsNames Do
			If Collection.Property(ListItem.Value) Then
				AddProperty(Collection, ListItem.Value, ListItem.Presentation);
			EndIf;
			NamesAndIDs.Insert(ListItem.Value, True);
			NamesAndIDs.Insert(ListItem.Presentation, True);
		EndDo;
		
		For Each KeyAndValue In Collection Do
			If NamesAndIDs.Get(KeyAndValue.Key) = Undefined Then
				AddProperty(Collection, KeyAndValue.Key, KeyAndValue.Key);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddProperty(PropertiesValues, Property, Presentation, Lowercase = Undefined)
	
	Value = PropertiesValues[Property];
	If TypeOf(Value) = Type("Date") Then
		Value = ToLocalTime(Value, SessionTimeZone());
	ElsIf TypeOf(Value) = Type("FixedArray") Then
		FixedArray = Value;
		Value = "";
		For Each ArrayElement In FixedArray Do
			Value = Value + ?(Value = "", "", Chars.LF) + TrimAll(ArrayElement);
		EndDo;
	EndIf;
	
	String = InternalContent.Add();
	If StrStartsWith(Property, "OID") Then
		String.Id = StrReplace(Mid(Property, 4), "_", ".");
		If Property <> Presentation Then
			String.Property = Presentation;
		EndIf;
	Else
		String.Property = Presentation;
	EndIf;
	
	If Lowercase = True Then
		String.Value = Lower(Value);
	Else
		String.Value = Value;
	EndIf;
	
EndProcedure

// Transforms certificate purposes into purpose codes.
//
// Parameters:
//  Purpose    - String - a multiline certificate purpose, for example:
//                           "Microsoft Encrypted File System (1.3.6.1.4.1.311.10.3.4)
//                           |E-mail Protection (1.3.6.1.5.5.7.3.4)
//                           |TLS Web Client Authentication (1.3.6.1.5.5.7.3.2)".
//  
//  PurposeCodes - String - purpose codes "1.3.6.1.4.1.311.10.3.4, 1.3.6.1.5.5.7.3.4, 1.3.6.1.5.5.7.3.2".
//
&AtServer
Procedure FillCertificatePurposeCodes(Purpose, PurposeCodes)
	
	SetPrivilegedMode(True);
	
	Codes = "";
	
	For IndexOf = 1 To StrLineCount(Purpose) Do
		
		String = StrGetLine(Purpose, IndexOf);
		CurrentCode = "";
		
		Position = StrFind(String, "(", SearchDirection.FromEnd);
		If Position <> 0 Then
			CurrentCode = Mid(String, Position + 1, StrLen(String) - Position - 1);
		EndIf;
		
		If ValueIsFilled(CurrentCode) Then
			Codes = Codes + ?(Codes = "", "", ", ") + TrimAll(CurrentCode);
		EndIf;
		
	EndDo;
	
	PurposeCodes = Codes;
	
EndProcedure

&AtClient
Procedure PopulateRootCertificates()
	
	DigitalSignatureInternalClient.GetCertificateChain(New NotifyDescription("AfterGotCertificatesChain", ThisObject),
		CertificateAddress, UUID);
	
EndProcedure

&AtClient
Async Procedure AfterGotCertificatesChain(Result, AdditionalParameters) Export
	
	If Not ValueIsFilled(Result.Error) Then
		For Each CurrentCertificate In Result.Certificates Do
			CryptoCertificate = New CryptoCertificate();
			CryptoCertificate.InitializeAsync(
				Base64Value(GetFromTempStorage(CurrentCertificate.CertificateData)));
			NewRow = CertificationPath.Insert(0);
			NewRow.Presentation = DigitalSignatureClient.CertificatePresentation(CryptoCertificate);
			NewRow.CertificateData = CurrentCertificate.CertificateData;
		EndDo;
		Items.GroupErrorGettingCertificatesChain.Visible = False;
	Else
		ErrorGettingCertificationPaths = Result.Error;
		Items.GroupErrorGettingCertificatesChain.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Function CertificateAddress(RefThumbprint, FormIdentifier = Undefined)
	
	CertificateData = Undefined;
	
	If TypeOf(RefThumbprint) = Type("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates") Then
		Store = Common.ObjectAttributeValue(RefThumbprint, "CertificateData");
		If TypeOf(Store) = Type("ValueStorage") Then
			CertificateData = Store.Get();
		EndIf;
	Else
		Query = New Query;
		Query.SetParameter("Thumbprint", RefThumbprint);
		Query.Text =
		"SELECT
		|	Certificates.CertificateData
		|FROM
		|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS Certificates
		|WHERE
		|	Certificates.Thumbprint = &Thumbprint";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			CertificateData = Selection.CertificateData.Get();
		Else
			Certificate = DigitalSignatureInternal.GetCertificateByThumbprint(RefThumbprint, False, False);
			If Certificate <> Undefined Then
				CertificateData = Certificate.Unload();
			EndIf;
		EndIf;
	EndIf;
	
	If TypeOf(CertificateData) = Type("BinaryData") Then
		Return PutToTempStorage(CertificateData, FormIdentifier);
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion
