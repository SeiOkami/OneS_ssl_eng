///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Generates a signature file name from a template.
//
Function SignatureFileName(BaseName, CertificateOwner, SignatureFilesExtension, SeparatorRequired = True) Export
	
	Separator = ?(SeparatorRequired, " - ", " ");
	
	SignatureFileNameWithoutExtension = StringFunctionsClientServer.SubstituteParametersToString("%1%2%3",
		BaseName, Separator, CertificateOwner);
	
	If StrLen(SignatureFileNameWithoutExtension) > 120 Then
		SignatureFileNameWithoutExtension = DigitalSignatureInternalServerCall.AbbreviatedFileName(
			CommonClientServer.ReplaceProhibitedCharsInFileName(SignatureFileNameWithoutExtension), 120);
	EndIf;
	
	SignatureFileName = StringFunctionsClientServer.SubstituteParametersToString("%1.%2",
		SignatureFileNameWithoutExtension, SignatureFilesExtension);
	
	Return CommonClientServer.ReplaceProhibitedCharsInFileName(SignatureFileName);

EndFunction

// Generates a certificate file name from a template.
//
Function CertificateFileName(BaseName, CertificateOwner, CertificateFilesExtension, SeparatorRequired = True) Export
	
	If Not ValueIsFilled(CertificateOwner) Then
		CertificateFileNameWithoutExtension = BaseName;
	Else
		Separator = ?(SeparatorRequired, " - ", " ");
		CertificateFileNameWithoutExtension = StringFunctionsClientServer.SubstituteParametersToString("%1%2%3",
			BaseName, Separator, CertificateOwner);
	EndIf;
	
	If StrLen(CertificateFileNameWithoutExtension) > 120 Then
		CertificateFileNameWithoutExtension = DigitalSignatureInternalServerCall.AbbreviatedFileName(
			CommonClientServer.ReplaceProhibitedCharsInFileName(CertificateFileNameWithoutExtension), 120);
	EndIf;
	
	CertificateFileName = StringFunctionsClientServer.SubstituteParametersToString("%1.%2",
		CertificateFileNameWithoutExtension, CertificateFilesExtension);
	
	Return CommonClientServer.ReplaceProhibitedCharsInFileName(CertificateFileName);
	
EndFunction

// 
// 
// Returns:
//  Structure - 
//   * Valid_SSLyf - Boolean - 
//                 
//   * FoundintheListofCAs - Boolean -
//   * IsState - Boolean -
//                                
//   
//   * ThisIsQualifiedCertificate - Boolean -
//   * Warning - See WarningWhileVerifyingCertificateAuthorityCertificate
//
Function DefaultCAVerificationResult() Export
	
	Result = New Structure;
	Result.Insert("Valid_SSLyf", True);
	Result.Insert("FoundintheListofCAs", False);
	Result.Insert("IsState", False);
	Result.Insert("ThisIsQualifiedCertificate", False);
	Result.Insert("Warning", WarningWhileVerifyingCertificateAuthorityCertificate());
	
	Return Result;
	
EndFunction

// Returns:
//   Structure - 
//   * ErrorText - String
//   * PossibleReissue - Boolean -
//   * Cause - String -
//   * Decision - String -
//
Function WarningWhileVerifyingCertificateAuthorityCertificate() Export
	
	Warning = New Structure;
	Warning.Insert("ErrorText", "");
	Warning.Insert("PossibleReissue", False);
	Warning.Insert("Cause", "");
	Warning.Insert("Decision", "");
	Warning.Insert("AdditionalInfo", "");
	
	Return Warning;
	
EndFunction

// Returns:
//   Structure:
//   * ErrorText - String
//
Function ErrorTextFailedToDefineApp(Error) Export
	
	If ValueIsFilled(Error) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot determine an application for digital signatures automatically:
			|%1';"), Error);
	Else
		ErrorText = NStr("en = 'Cannot determine an application for digital signatures automatically.';");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Returns:
//   String
//    An array of See NewExtendedApplicationDetails
//
Function CryptoProvidersSearchResult(CryptoProvidersResult, ServerName = "") Export
	
	If ServerName = "" Then
		ServerName = NStr("en = 'On computer';");
	Else
		ServerName = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'On the %1 server';"), ServerName);
	EndIf;
	
	If CryptoProvidersResult = Undefined Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 cannot determine installed applications automatically.
						|Check the application settings.';"), ServerName);
	ElsIf CryptoProvidersResult.CheckCompleted Then
		If CryptoProvidersResult.Cryptoproviders.Count() > 0 Then
			Return CryptoProvidersResult.Cryptoproviders;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 no applications for digital signatures are installed.';"), ServerName);
		EndIf;
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 cannot determine installed applications automatically:
					|%2';"), ServerName, CryptoProvidersResult.Error);
	EndIf;
	
	Return ErrorText;
	
EndFunction

// 
// 
// Parameters:
//  CertificateAuthorityName - String -
//  Certificate  - BinaryData
//              - String
// 
// Returns:
//  Structure:
//   * InternalAddress - String -
//   * ExternalAddress - String -
//
Function RevocationListInternalAddress(CertificateAuthorityName, Certificate) Export
	
	Return DigitalSignatureClientServerLocalization.RevocationListInternalAddress(CertificateAuthorityName, Certificate);
	
EndFunction

// 
// 
// Parameters:
//  Data - BinaryData
//         - String - 
// 
// Returns:
//  Undefined, String - 
//
Function DefineDataType(Data) Export
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.DefineDataType");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
	// SEQUENCE (PKCS #7 ContentInfo).
	SkipBlockStart(DataAnalysis, 0, 16);
	
	If DataAnalysis.HasError Then
		Return Undefined;
	EndIf;

	// OBJECT IDENTIFIER (contentType).
	SkipBlockStart(DataAnalysis, 0, 6);
	
	If Not DataAnalysis.HasError Then
		DataSize = DataAnalysis.Parents[0].DataSize;
		If DataSize = 9 Then
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
			If BufferString = "2A864886F70D010702" Then // 1.2.840.113549.1.7.2 signedData (PKCS #7).
				Return "Signature";
			ElsIf BufferString = "2A864886F70D010703" Then // 1.2.840.113549.1.7.3 envelopedData (PKCS #7)
				Return "EncryptedData";
			EndIf;
		Else
			Return Undefined;
		EndIf;
	Else
		DataAnalysis = NewDataAnalysis(BinaryData);
		// SEQUENCE (PKCS #7 ContentInfo).
		SkipBlockStart(DataAnalysis, 0, 16);
			// SEQUENCE (tbsCertificate).
			SkipBlockStart(DataAnalysis, 0, 16);
		If DataAnalysis.HasError Then
			Return Undefined;
		EndIf;
		Return "Certificate";
	EndIf;
		
	Return Undefined;
	
EndFunction

// 
// 
// Parameters:
//  Certificates - Array of CryptoCertificate
// 
// Returns:
//  Array of CryptoCertificate - 
//
Function CertificatesInOrderToRoot(Certificates) Export
	
	By_Order = New Array;
	CertificatesBySubjects = New Map;
	CertificatesDetails = New Map;
	
	For Each Certificate In Certificates Do
		CertificatesDetails.Insert(Certificate, Certificate);
		By_Order.Add(Certificate);
		CertificatesBySubjects.Insert(IssuerKey(Certificate.Subject), Certificate);
	EndDo;
	
	For Counter = 1 To By_Order.Count() Do
		HasChanges = False;
		SortCertificates(
			By_Order, CertificatesDetails, CertificatesBySubjects, HasChanges); 
		If Not HasChanges Then
			Break;
		EndIf;
	EndDo;

	Return By_Order;
	
EndFunction

Function AppsRelevantAlgorithms() Export
	
	Return NamesOfSignatureAlgorithmsGOST_34_10_2012_256()
	
EndFunction

#EndRegion

#Region Private

// 
// 
// Returns:
//   See DigitalSignature.SignatureProperties
//
Function ResultOfReadSignatureProperties() Export
	
	Structure = New Structure;
	Structure.Insert("Success", Undefined);
	Structure.Insert("ErrorText", "");
	
	CommonClientServer.SupplementStructure(
		Structure, SignaturePropertiesUponReadAndVerify());
	Structure.Insert("Certificates", New Array);
		
	Return Structure;
	
EndFunction

Function SignaturePropertiesUponReadAndVerify() Export
	
	Structure = New Structure;
	Structure.Insert("SignatureType");
	Structure.Insert("DateActionLastTimestamp");
	Structure.Insert("DateSignedFromLabels");
	Structure.Insert("UnverifiedSignatureDate");
	Structure.Insert("ResultOfSignatureVerificationByMCHD");
	
	Structure.Insert("Certificate");
	Structure.Insert("Thumbprint");
	Structure.Insert("CertificateOwner");
	
	Return Structure;
	
EndFunction

Procedure SortCertificates(By_Order, CertificatesDetails, CertificatesBySubjects, HasChanges) Export
	
	For Each CertificateDetails In CertificatesDetails Do
		
		CertificateProperties = CertificateDetails.Key;
		Certificate = CertificateDetails.Value;
	
		IssuerKey = IssuerKey(CertificateProperties.Issuer);
		IssuerCertificate = CertificatesBySubjects.Get(IssuerKey);
		
		Position = By_Order.Find(Certificate);
		

		If CertificateProperties.Issuer.CN = CertificateProperties.Subject.CN
			And IssuerKey = IssuerKey(CertificateProperties.Subject)
			Or IssuerCertificate = Undefined Then

			If Position <> By_Order.UBound() Then
				By_Order.Delete(Position);
				By_Order.Add(Certificate);
				HasChanges = True;
			EndIf;
			Continue;
		EndIf;

		IssuerPosition = By_Order.Find(IssuerCertificate);
		If Position + 1 = IssuerPosition Then
			Continue;
		EndIf;
		
		By_Order.Delete(Position);
		HasChanges = True;
		IssuerPosition = By_Order.Find(IssuerCertificate);
		By_Order.Insert(IssuerPosition, Certificate);
		
	EndDo;
	
EndProcedure 

Function IssuerKey(IssuerOrSubject) Export
	Array = New Array;
	For Each KeyAndValue In IssuerOrSubject Do
		Array.Add(KeyAndValue.Key);
		Array.Add(KeyAndValue.Value);
	EndDo;
	Return IssuerOrSubject.CN + StrConcat(Array);
EndFunction

Function UsersCertificateString(User1, User2, UsersCount) Export
	
	UserRow = StrTemplate("%1, %2", User1, User2);
	If UsersCount > 2 Then
		UserRow = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 and other (total %2)';"), UserRow, Format(UsersCount, "NG=0"));
	EndIf;

	Return UserRow;
	
EndFunction

Function ApplicationDetailsByCryptoProviderName(CryptoProviderName, ApplicationsDetailsCollection, AppsAuto) Export
	
	ApplicationFound = False;
	
	If ValueIsFilled(AppsAuto) Then
		For Each ApplicationDetails In AppsAuto Do
			If ApplicationDetails.ApplicationName = CryptoProviderName Then
				ApplicationFound = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If Not ApplicationFound Then
		For Each ApplicationDetails In ApplicationsDetailsCollection Do
			If ApplicationDetails.ApplicationName = CryptoProviderName Then
				ApplicationFound = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If ApplicationFound Then
		Return ApplicationDetails;
	EndIf;
	
	ApplicationDetails = Undefined;
	
	If CryptoProviderName = "Crypto-Pro GOST R 34.10-2001 KC1 CSP"
	 Or CryptoProviderName = "Crypto-Pro GOST R 34.10-2001 KC2 CSP" Then
		
		ApplicationDetails = ApplicationDetailsByCryptoProviderName(
			"Crypto-Pro GOST R 34.10-2001 Cryptographic Service Provider", ApplicationsDetailsCollection, AppsAuto);
		
	ElsIf CryptoProviderName = "Crypto-Pro GOST R 34.10-2012 KC1 CSP"
	      Or CryptoProviderName = "Crypto-Pro GOST R 34.10-2012 KC2 CSP" Then
		
		ApplicationDetails = ApplicationDetailsByCryptoProviderName(
			"Crypto-Pro GOST R 34.10-2012 Cryptographic Service Provider", ApplicationsDetailsCollection, AppsAuto);
		
	ElsIf CryptoProviderName = "Crypto-Pro GOST R 34.10-2012 KC1 Strong CSP"
	      Or CryptoProviderName = "Crypto-Pro GOST R 34.10-2012 KC2 Strong CSP" Then
		
		ApplicationDetails = ApplicationDetailsByCryptoProviderName(
			"Crypto-Pro GOST R 34.10-2012 Strong Cryptographic Service Provider", ApplicationsDetailsCollection, AppsAuto);
	EndIf;
	
	Return ApplicationDetails;
	
EndFunction

Function CertificatePropertiesFromAddInResponse(AddInResponse) Export
	
	CertificateProperties = New Structure;
	CertificateProperties.Insert("AddressesOfRevocationLists", New Array);
	
	Try
		CertificatePropertiesResult = ReadAddInResponce(
			AddInResponse);
			
		AddressesOfRevocationLists = CertificatePropertiesResult.Get("crls");
		If ValueIsFilled(AddressesOfRevocationLists) Then
			CertificateProperties.AddressesOfRevocationLists = AddressesOfRevocationLists;
		EndIf;

		CertificateProperties.Insert("Issuer", CertificatePropertiesResult.Get("issuer_name"));
		CertificateProperties.Insert("AlgorithmOfPublicKey", CertificatePropertiesResult.Get(
			"public_key_algorithm"));
		CertificateProperties.Insert("SignAlgorithm", CertificatePropertiesResult.Get("signature_algorithm"));
		CertificateProperties.Insert("SerialNumber", CertificatePropertiesResult.Get("serial_number"));
		CertificateProperties.Insert("NameOfContainer", CertificatePropertiesResult.Get("container_name"));
		CertificateProperties.Insert("ApplicationDetails", CertificatePropertiesResult.Get("provider"));
		CertificateProperties.Insert("Certificate", CertificatePropertiesResult.Get("value"));
		CertificateProperties.Insert("PublicKey", CertificatePropertiesResult.Get("public_key"));

		Return CertificateProperties;

	Except

		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when reading the extended certificate properties:
				 | %1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;

EndFunction

Function CertificatesChainFromAddInResponse(AddInResponse, FormIdentifier) Export
	
	Result = New Structure("Certificates, Error", New Array, "");
	
	Try
		CertificatesResult = ReadAddInResponce(
			AddInResponse);
		CertificatesResult = CertificatesResult.Get("Certificates");
	Except
		
		Result.Error = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when receiving the certificate chain %1';"),
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return Result;
		
	EndTry;
		
	For Each CurrentCertificate In CertificatesResult Do
		
		CertificateDetails = New Structure;
		CertificateDetails.Insert("Subject", CurrentCertificate.Get("subject_name"));
		CertificateData = CurrentCertificate.Get("value");
		If FormIdentifier = Undefined Then
			CertificateDetails.Insert("CertificateData", CertificateData);
		Else
			CertificateDetails.Insert("CertificateData",
				PutToTempStorage(CertificateData, FormIdentifier));
		EndIf;
		
		CertificateDetails.Insert("Issuer", CurrentCertificate.Get("issuer_name"));
		CertificateDetails.Insert("PublicKey", CurrentCertificate.Get("public_key_"));
		
		Result.Certificates.Add(CertificateDetails);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function InstalledCryptoProvidersFromAddInResponse(AddInResponse, ApplicationsByNamesWithType, 
	CheckAtCleint = True) Export
	
	Try
		AllCryptoProviders = ReadAddInResponce(AddInResponse);
		Cryptoproviders = AllCryptoProviders.Get("providers");
	Except
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when reading the cryptographic service provider properties:
				 | %1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	If TypeOf(Cryptoproviders) <> Type("Array") Then
		Return New Array;
	EndIf;
	
	CryptoProvidersResult = New Array;
	For Each CurCryptoProvider In Cryptoproviders Do
		
		ExtendedApplicationDetails = ExtendedApplicationDetails(
			CurCryptoProvider, ApplicationsByNamesWithType, CheckAtCleint);
			
		If ExtendedApplicationDetails = Undefined Then
			Continue;
		EndIf;
		
		CryptoProvidersResult.Add(ExtendedApplicationDetails);
		
	EndDo;
	
	Return CryptoProvidersResult;
	
EndFunction

Function ReadAddInResponce(Text) Export
	
	#If WebClient Then
	Return DigitalSignatureInternalServerCall.ReadAddInResponce(Text);
	#Else
	Try
		JSONReader = New JSONReader;
		JSONReader.SetString(Text);
		Result = ReadJSON(JSONReader, True);
		JSONReader.Close();
	Except
		
		ErrorInfo = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot read the add-in response: %1
					|%2';"), Text, ErrorInfo);
		
	EndTry;
	
	Return Result;
	#EndIf
	
EndFunction

Function DefineApp(CertificateProperties,
			InstalledCryptoProviders, SearchOfAppsByPublicKey, ErrorDescription = "") Export
	
	If InstalledCryptoProviders.Count() = 0 Then
		ErrorDescription = NStr("en = 'No applications for digital signatures are installed';");
		Return Undefined;
	EndIf;
	
	AppsByPublicKey = SearchOfAppsByPublicKey.Get(CertificateProperties.AlgorithmOfPublicKey);
	
	If AppsByPublicKey = Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No appropriate applications are found by the public key of the %1 certificate';"),
			CertificateProperties.AlgorithmOfPublicKey);
		Return Undefined;
	EndIf;
	
	ApplicationFound = Undefined;
	
	For Each InstalledCryptoProvider In InstalledCryptoProviders Do
		
		If ApplicationNotUsed(InstalledCryptoProvider.UsageMode) Then
			Continue;
		EndIf;
		
		Application = AppsByPublicKey.Get(
			ApplicationSearchKeyByNameWithType(InstalledCryptoProvider.ApplicationName, InstalledCryptoProvider.ApplicationType));
		If Application = Undefined Then
			Continue;
		EndIf;
		
		// 
		If StrFind(Application, "CryptoPro") Then
			Return InstalledCryptoProvider;
		EndIf;
		
		// 
		If StrFind(Application, "MicrosoftEnhanced") Then
			Return InstalledCryptoProvider;
		EndIf;
		
		ApplicationFound = InstalledCryptoProvider;
		
	EndDo;
	
	If ApplicationFound = Undefined Then
		
		AlgorithmsIDs = IDsOfSignatureAlgorithms(True);
		SignAlgorithm = AlgorithmByOID(CertificateProperties.AlgorithmOfPublicKey, AlgorithmsIDs, False);
		
		ErrorTemplate = NStr("en = 'No application
			|with the %1 signing algorithm is supported';");
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
			TrimAll(StrSplit(SignAlgorithm, ",")[0]));
			
	EndIf;
	
	Return ApplicationFound;
	
EndFunction

Function ApplicationSearchKeyByNameWithType(Name, Type) Export
	
	Return StrTemplate("%1 (%2)", Name, Type);
	
EndFunction

//  Returns:
//   Structure - 
//     * ErrorDescription  - String - Full error details in case it was returned as String.
//     * ErrorTitle - String - an error title that matches the operation
//                                  when there is one operation (not filled in when there are several operations).
//     * Shared3           - Boolean - if True, then one error is common for all applications.
//     * ComputerName   - String - the computer name when executing the operation on the server side.
//     * Errors          - Array of See NewErrorProperties
//
Function NewErrorsDescription(ComputerName = "") Export
	
	LongDesc = New Structure;
	LongDesc.Insert("ErrorDescription",  "");
	LongDesc.Insert("ErrorTitle", "");
	LongDesc.Insert("Shared3",           False);
	LongDesc.Insert("ComputerName",   ComputerName);
	LongDesc.Insert("Errors",          New Array);
	
	Return LongDesc;
	
EndFunction

// Returns the execution error properties of one operation by one application.
//
// Returns:
//  Structure:
//   * ErrorTitle   - String - an error title that matches the operation
//                           when there are several operations (not filled in when there is one operation).
//   * LongDesc          - String - a short error presentation.
//   * FromException      - Boolean - a description contains a brief error description.
//   * NoExtension     - Boolean - the extension for working with the digital signature was not connected (installation is required).
//   * ToAdministrator   - Boolean - administrator rights are required to patch an error.
//   * Instruction        - Boolean - to correct, instruction on how to work with the digital signature applications is required.
//   * ApplicationsSetUp - Boolean - to fix an error, you need to configure the applications.
//   * Application         - CatalogRef.DigitalSignatureAndEncryptionApplications
//                       - String - if it is not
//                           filled in, it means an error common to all programs.
//   * NoAlgorithm      - Boolean - the crypto manager does not support the algorithm specified
//                                  for its creation in addition to the specified application.
//   * PathNotSpecified      - Boolean - the path required for Linux OS is not specified for the application.
//
Function NewErrorProperties() Export
	
	BlankApplication = PredefinedValue("Catalog.DigitalSignatureAndEncryptionApplications.EmptyRef");
	
	ErrorProperties = New Structure;
	ErrorProperties.Insert("ErrorTitle",   "");
	ErrorProperties.Insert("LongDesc",          "");
	ErrorProperties.Insert("FromException",      False);
	ErrorProperties.Insert("NotSupported",  False);
	ErrorProperties.Insert("NoExtension",     False);
	ErrorProperties.Insert("ToAdministrator",   False);
	ErrorProperties.Insert("Instruction",        False);
	ErrorProperties.Insert("ApplicationsSetUp", False);
	ErrorProperties.Insert("Application",         BlankApplication);
	ErrorProperties.Insert("NoAlgorithm",      False);
	ErrorProperties.Insert("PathNotSpecified",      False);
	
	Return ErrorProperties;
	
EndFunction

// Error message of the ExtraCryptoAPI call.
// 
// Parameters:
//  MethodName - String
//  ErrorInfo - String
// 
// Returns:
//  String
//
Function ErrorCallMethodComponents(MethodName, ErrorInfo) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error when calling method ""%1"" of add-in ""%2"".';"), MethodName, "ExtraCryptoAPI")
		+ Chars.LF + ErrorInfo;
	
EndFunction

// 
// 
// Parameters:
//  SignatureVerificationResult - See DigitalSignatureClientServer.SignatureVerificationResult
// 
// Returns:
//  String - 
//
Function ErrorTextForRevokedSignatureCertificate(SignatureVerificationResult) Export
	
	If ValueIsFilled(SignatureVerificationResult.DateSignedFromLabels) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The certificate is revoked. The signature is considered valid if the revocation occurred after %1. To determine the signature validity, request the revocation reason and date from the certificate authority that issued the certificate.';"),
			SignatureVerificationResult.DateSignedFromLabels);
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The certificate is revoked. The signature might have been valid as of signing date %1 if the revocation occurred later. To find out the revocation reason and date, contact the certificate authority that issued the certificate.';"),
			SignatureVerificationResult.UnverifiedSignatureDate);
	EndIf;
	
	Return ErrorText;
	
EndFunction


// For internal use only.
// 
// Parameters:
//  Application - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
//            - See DigitalSignatureInternalCached.ApplicationDetails
//            - See NewExtendedApplicationDetails
//  Errors - Array
//  ApplicationsDetailsCollection - Array of See DigitalSignatureInternalCached.ApplicationDetails
//  AppsAuto - Array of See NewExtendedApplicationDetails
//
// Returns:
//  Array of See DigitalSignatureInternalCached.ApplicationDetails
//
Function CryptoManagerApplicationsDetails(Application, Errors, Val ApplicationsDetailsCollection, Val AppsAuto = Undefined) Export
	
	If TypeOf(Application) = Type("Structure") Or TypeOf(Application) = Type("FixedStructure") Then
		
		ApplicationsDetailsCollection = New Array;
		ApplicationsDetailsCollection.Add(Application);
		Return ApplicationsDetailsCollection;
		
	ElsIf Application <> Undefined Then
		
		ApplicationFound = False;
		
		For Each ApplicationDetails In ApplicationsDetailsCollection Do
			
			If ApplicationDetails.Ref = Application Then
				
				If AreAutomaticSettingsUsed(ApplicationDetails.UsageMode)
					And ValueIsFilled(AppsAuto) Then
					
					For Each AppAuto In AppsAuto Do
						If AppAuto.ApplicationName = ApplicationDetails.ApplicationName
							And AppAuto.ApplicationType = ApplicationDetails.ApplicationType Then
							ApplicationsDetailsCollection = New Array;
							ApplicationsDetailsCollection.Add(AppAuto);
							Return ApplicationsDetailsCollection;
						EndIf;
					EndDo;
					
				EndIf;
				
				If ApplicationNotUsed(ApplicationDetails.UsageMode) Then
					Break;
				EndIf;
				
				ApplicationFound = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If Not ApplicationFound Then
			CryptoManagerAddError(Errors, Application,
				NStr("en = 'The application cannot be used.';"), True);
			Return Undefined;
		EndIf;
		
		ApplicationsDetailsCollection = New Array;
		ApplicationsDetailsCollection.Add(ApplicationDetails);
		
	ElsIf AppsAuto <> Undefined Then
		
		For Each ApplicationDetails In ApplicationsDetailsCollection Do
			If Not ValueIsFilled(ApplicationDetails.Id)
				And Not ApplicationNotUsed(ApplicationDetails.UsageMode) Then
				
				Found4 = Undefined;
				For Each AppAuto In AppsAuto Do
					If ApplicationDetails.ApplicationName = AppAuto.ApplicationName
						And ApplicationDetails.ApplicationType = AppAuto.ApplicationType Then
						Found4 = AppAuto;
						Break;
					EndIf;
				EndDo;
				
				If Found4 = Undefined Then
					NewDetails = NewExtendedApplicationDetails();
					FillPropertyValues(NewDetails, ApplicationDetails);
					NewDetails.AutoDetect = False;
					AppsAuto.Add(NewDetails);
				EndIf;
			EndIf;
		EndDo;
		
		Return AppsAuto;
		
	EndIf;
	
	Return ApplicationsDetailsCollection;
	
EndFunction

Function AreAutomaticSettingsUsed(UsageMode) Export

	Return UsageMode = PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.Automatically")
		
EndFunction

Function ApplicationNotUsed(UsageMode) Export

	Return UsageMode = PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.NotUsed")
		
EndFunction

// For internal use only.
// 
// Parameters:
//  ApplicationDetails - See DigitalSignatureInternalCached.ApplicationDetails
//  IsLinux - Boolean
//  Errors - Array
//  IsServer - Boolean
//  ApplicationsPathsAtLinuxServers -String
// 
// Returns:
//  Structure:
//   * ApplicationPath - String
//  Undefined
//
Function CryptoManagerApplicationProperties(ApplicationDetails, IsLinux, Errors, IsServer,
			DescriptionOfWay) Export
	
	If Not ValueIsFilled(ApplicationDetails.ApplicationName) Then
		CryptoManagerAddError(Errors, ApplicationDetails.Ref,
			NStr("en = 'Application name is not specified.';"), True);
		Return Undefined;
	EndIf;
	
	If Not ValueIsFilled(ApplicationDetails.ApplicationType) Then
		CryptoManagerAddError(Errors, ApplicationDetails.Ref,
			NStr("en = 'Application type is not specified.';"), True);
		Return Undefined;
	EndIf;
	
	ApplicationProperties1 = New Structure("ApplicationName, ApplicationPath, ApplicationType");
	
	ApplicationPath = "";
	AutoDetect = CommonClientServer.StructureProperty(ApplicationDetails, "AutoDetect", False);
	If IsLinux And Not AutoDetect Then
		If ValueIsFilled(DescriptionOfWay.ApplicationPath) And Not DescriptionOfWay.Exists Then
			If DescriptionOfWay.Property("ErrorText")
			   And ValueIsFilled(DescriptionOfWay.ErrorText) Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot determine the path to the application due to:
					           |%1';"), DescriptionOfWay.ErrorText);
			Else
				ThePathToTheModules = StrSplit(DescriptionOfWay.ApplicationPath, ":", False);
				If ThePathToTheModules.Count() = 1 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'File does not exist: ""%1"".';"), ThePathToTheModules[0]);
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'None of the files exists: ""%1"".';"),
						StrConcat(ThePathToTheModules, """, """));
				EndIf;
			EndIf;
		Else
			ErrorText = "";
			ApplicationPath = DescriptionOfWay.ApplicationPath;
		EndIf;
		If ValueIsFilled(ErrorText) Then
			CryptoManagerAddError(Errors,
				ApplicationDetails.Ref, ErrorText, IsServer);
			Return Undefined;
		EndIf;
	EndIf;
	
	ApplicationProperties1 = New Structure;
	ApplicationProperties1.Insert("ApplicationName",   ApplicationDetails.ApplicationName);
	ApplicationProperties1.Insert("ApplicationPath", ApplicationPath);
	ApplicationProperties1.Insert("ApplicationType",   ApplicationDetails.ApplicationType);
	
	Return ApplicationProperties1;
	
EndFunction

// For internal use only.
// Parameters:
//  ApplicationDetails - Structure:
//    * Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//  SignAlgorithms - Array of String
//  SignAlgorithm - String
//  Errors - Array of See NewErrorProperties
//  IsServer - Boolean
//  AddError1 - Boolean
// 
// Returns:
//  Boolean
//
Function CryptoManagerSignAlgorithmSupported(ApplicationDetails, Operation,
			SignAlgorithm, Errors, IsServer, AddError1) Export
	
	PossibleAlgorithms = StrSplit(SignAlgorithm, ",", False);
	
	For Each PossibleAlgorithm In PossibleAlgorithms Do
		PossibleAlgorithm = TrimAll(PossibleAlgorithm);
		
		If Upper(ApplicationDetails.SignAlgorithm) = Upper(PossibleAlgorithm)
		 Or (Operation = "CheckSignature" Or Operation = "CertificateCheck" Or Operation = "ExtensionValiditySignature" Or Operation = "Encryption")
		   And ApplicationDetails.SignatureVerificationAlgorithms.Find(PossibleAlgorithm) <> Undefined Then
			
			Return True;
		EndIf;
	EndDo;
	
	If Not AddError1 Then
		Return False;
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'The application does not support the signing algorithm %1.';"),
		TrimAll(StrSplit(PossibleAlgorithms, ",")[0]));
	
	CryptoManagerAddError(Errors, ApplicationDetails.Ref, ErrorText, IsServer, True);
	Errors[Errors.UBound()].NoAlgorithm = True;
	
	Return False;
	
EndFunction

// For internal use only.
// 
// Parameters:
//  ApplicationDetails - See DigitalSignatureInternalCached.ApplicationDetails
//  Manager - CryptoManager
//  Errors - Array
//
// Returns:
//  Boolean
//
Function CryptoManagerAlgorithmsSet(ApplicationDetails, Manager, Errors) Export
	
	If ApplicationDetails.ApplicationName = "Default" Then
		Return True;
	EndIf;
	
	If BackwardCompatibilityViolationInViPNetCSP44Bypassed(ApplicationDetails, Manager) Then
		Return True;
	EndIf;
	
	SignAlgorithm = String(ApplicationDetails.SignAlgorithm);
	Try
		Manager.SignAlgorithm = SignAlgorithm;
	Except
		Manager = Undefined;
		// 1C:Enterprise uses a vague message "Unknown crypto algorithm". Need to replace with a more specific message.
		CryptoManagerAddError(Errors, ApplicationDetails.Ref, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown signature algorithm ""%1"" is selected.';"), SignAlgorithm), True);
		Return False;
	EndTry;
	
	HashAlgorithm = String(ApplicationDetails.HashAlgorithm);
	Try
		Manager.HashAlgorithm = HashAlgorithm;
	Except
		Manager = Undefined;
		// 1C:Enterprise uses a vague message "Unknown crypto algorithm". Need to replace with a more specific message.
		CryptoManagerAddError(Errors, ApplicationDetails.Ref, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown hash algorithm ""%1"" is selected.';"), HashAlgorithm), True);
		Return False;
	EndTry;
	
	EncryptAlgorithm = String(ApplicationDetails.EncryptAlgorithm);
	Try
		Manager.EncryptAlgorithm = EncryptAlgorithm;
	Except
		Manager = Undefined;
		// 1C:Enterprise uses a vague message "Unknown crypto algorithm". Need to replace with a more specific message.
		CryptoManagerAddError(Errors, ApplicationDetails.Ref, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown encryption algorithm ""%1"" is selected.';"), EncryptAlgorithm), True);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

// For the CryptoManagerAlgorithmsSet function.
Function BackwardCompatibilityViolationInViPNetCSP44Bypassed(ApplicationDetails, Manager)
	
	SignAlgorithm     = String(ApplicationDetails.SignAlgorithm);
	HashAlgorithm = String(ApplicationDetails.HashAlgorithm);
	EncryptAlgorithm  = String(ApplicationDetails.EncryptAlgorithm);

#If WebClient Then
	
	If NamesOfSignatureAlgorithmsGOST_34_10_2012_256().Find(SignAlgorithm) <> Undefined Then
		SignAlgorithm = "1.2.643.7.1.1.1.1"; // ГОСТ 34.10-2012 256
	ElsIf NamesOfSignatureAlgorithmsGOST_34_10_2012_512().Find(SignAlgorithm) <> Undefined Then
		SignAlgorithm = "1.2.643.7.1.1.1.2"; // ГОСТ 34.10-2012 512
	EndIf;

	If NamesOfHashingAlgorithmsGOST_34_11_2012_256().Find(HashAlgorithm) <> Undefined Then
		HashAlgorithm = "1.2.643.7.1.1.2.2"; // ГОСТ 34.11-2012 256
	ElsIf NamesOfHashingAlgorithmsGOST_34_11_2012_512().Find(HashAlgorithm) <> Undefined Then
		HashAlgorithm = "1.2.643.7.1.1.2.3"; // ГОСТ 34.11-2012 512
	EndIf;

#Else
		If Not (ApplicationDetails.ApplicationName = "Infotecs GOST 2012/512 Cryptographic Service Provider"
			And ApplicationDetails.ApplicationType = 77) And Not (ApplicationDetails.ApplicationName = "Infotecs GOST 2012/1024 Cryptographic Service Provider"
			And ApplicationDetails.ApplicationType = 78) Then
			Return False;
		EndIf;
#EndIf

	AlgorithmsSet = True;
	Try
		Manager.SignAlgorithm     = SignAlgorithm;
		Manager.HashAlgorithm = HashAlgorithm;
		Manager.EncryptAlgorithm  = EncryptAlgorithm;
	Except
		AlgorithmsSet = False;
	EndTry;

	If AlgorithmsSet Then
		Return True;
	EndIf;
	
	If SignAlgorithm     = "GOST 34.10-2012 256"
	   And HashAlgorithm = "GOST 34.11-2012 256"
	   And EncryptAlgorithm  = "GOST 28147-89" Then
		
		SignAlgorithm     = "GR 34.10-2012 256";
		HashAlgorithm = "GR 34.11-2012 256";
		EncryptAlgorithm  = "GOST 28147-89";
		
	ElsIf SignAlgorithm     = "GR 34.10-2012 256"
	        And HashAlgorithm = "GR 34.11-2012 256"
	        And EncryptAlgorithm  = "GOST 28147-89" Then
	
		SignAlgorithm     = "GOST 34.10-2012 256";
		HashAlgorithm = "GOST 34.11-2012 256";
		EncryptAlgorithm  = "GOST 28147-89";
		
	ElsIf SignAlgorithm     = "GOST 34.10-2012 512"
	        And HashAlgorithm = "GOST 34.11-2012 512"
	        And EncryptAlgorithm  = "GOST 28147-89" Then
		
		SignAlgorithm     = "GR 34.10-2012 512";
		HashAlgorithm = "GR 34.11-2012 512";
		EncryptAlgorithm  = "GOST 28147-89";
		
	ElsIf SignAlgorithm     = "GR 34.10-2012 512"
	        And HashAlgorithm = "GR 34.11-2012 512"
	        And EncryptAlgorithm  = "GOST 28147-89" Then
	
		SignAlgorithm     = "GOST 34.10-2012 512";
		HashAlgorithm = "GOST 34.11-2012 512";
		EncryptAlgorithm  = "GOST 28147-89";
	Else
		Return False;
	EndIf;
	
	AlgorithmsSet = True;
	Try
		Manager.SignAlgorithm     = SignAlgorithm;
		Manager.HashAlgorithm = HashAlgorithm;
		Manager.EncryptAlgorithm  = EncryptAlgorithm;
	Except
		AlgorithmsSet = False;
	EndTry;
	
	Return AlgorithmsSet;
	
EndFunction

// For internal use only.
// 
// Parameters:
//  ApplicationDetails - See DigitalSignatureInternalCached.ApplicationDetails
//  Errors - Array
//  IsServer - Boolean
//
Procedure CryptoManagerApplicationNotFound(ApplicationDetails, Errors, IsServer) Export
	
	CryptoManagerAddError(Errors, ApplicationDetails.Ref,
		NStr("en = 'The application is not installed on the computer.';"), IsServer, True);
	
EndProcedure

// For internal use only.
// 
// Parameters:
//  ApplicationDetails - See DigitalSignatureInternalCached.ApplicationDetails
//  ApplicationNameReceived - String
//  Errors - Array
//  IsServer - Boolean
//
// Returns:
//  Boolean
//
Function CryptoManagerApplicationNameMaps(ApplicationDetails, ApplicationNameReceived, Errors, IsServer) Export
	
	If ApplicationNameReceived <> ApplicationDetails.ApplicationName Then
		CryptoManagerAddError(Errors, ApplicationDetails.Ref, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Another application with name ""%1"" received.';"), ApplicationNameReceived), IsServer, True);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// For internal use only.
//
// Parameters:
//  Errors    - Array of See NewErrorProperties
//  Application - CatalogRef.DigitalSignatureAndEncryptionApplications
//            - Structure - See NewExtendedApplicationDetails
//  LongDesc  - String
//  ToAdministrator - Boolean
//  Instruction   - Boolean
//  FromException - Boolean
//  PathNotSpecified - Boolean
//
Procedure CryptoManagerAddError(Errors, Application, LongDesc,
			ToAdministrator, Instruction = False, FromException = False, PathNotSpecified = False) Export
	
	ErrorProperties = NewErrorProperties();
	If TypeOf(Application) = Type("CatalogRef.DigitalSignatureAndEncryptionApplications") Then
		If ValueIsFilled(Application) Then
			ErrorProperties.Application = Application;
		EndIf;
	ElsIf TypeOf(Application) = Type("Structure") Then
		If ValueIsFilled(Application.Ref) Then
			ErrorProperties.Application = Application.Ref;
		Else
			ErrorProperties.Application = ?(ValueIsFilled(Application.Presentation), Application.Presentation,
				ApplicationSearchKeyByNameWithType(Application.ApplicationName, Application.ApplicationType));
		EndIf;
	EndIf;
	ErrorProperties.LongDesc          = LongDesc;
	ErrorProperties.ToAdministrator   = ToAdministrator;
	ErrorProperties.Instruction        = Instruction;
	ErrorProperties.FromException      = FromException;
	ErrorProperties.PathNotSpecified      = PathNotSpecified;
	ErrorProperties.ApplicationsSetUp = True;
	
	Errors.Add(ErrorProperties);
	
EndProcedure

// For internal use only.
//
// Parameters:
//  ErrorsDescription - See NewErrorsDescription
//  Application - CatalogRef.DigitalSignatureAndEncryptionApplications
//  SignAlgorithm - String
//  IsFullUser - Boolean
//  IsServer - Boolean
//
Procedure CryptoManagerFillErrorsPresentation(ErrorsDescription,
			Application, SignAlgorithm, IsFullUser, IsServer) Export
		
	If ErrorsDescription.Errors.Count() = 0 Then
		If Not ValueIsFilled(SignAlgorithm) Then
			ErrorText = NStr("en = 'Usage of no application is possible.';");
		Else
			ErrorTemplate = NStr("en = 'No application
			                          | with the %1 signing algorithm is supported.';");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				TrimAll(StrSplit(SignAlgorithm, ",")[0]));
		EndIf;
		ErrorsDescription.Shared3 = True;
		CryptoManagerAddError(ErrorsDescription.Errors,
			Undefined, ErrorText, True, True);
	EndIf;
	
	FillCommonErrorsPresentation(ErrorsDescription, IsFullUser);
	
EndProcedure

// For internal use only.
//
// Parameters:
//  ErrorsDescription - See NewErrorsDescription
//  IsFullUser - Boolean
//
Procedure FillCommonErrorsPresentation(ErrorsDescription, IsFullUser)
	
	DetailsParts = New Array;
	If ValueIsFilled(ErrorsDescription.ErrorTitle) Then
		DetailsParts.Add(ErrorsDescription.ErrorTitle);
	EndIf;
	
	ToAdministrator = False;
	For Each ErrorProperties In ErrorsDescription.Errors Do
		LongDesc = "";
		If ValueIsFilled(ErrorProperties.ErrorTitle) Then
			LongDesc = LongDesc + ErrorProperties.ErrorTitle + Chars.LF;
		EndIf;
		If ValueIsFilled(ErrorProperties.Application) Then
			LongDesc = LongDesc + String(ErrorProperties.Application) + ":" + Chars.LF;
		EndIf;
		DetailsParts.Add(LongDesc + ErrorProperties.LongDesc);
		ToAdministrator = ToAdministrator Or ErrorProperties.ToAdministrator;
	EndDo;
	ErrorDescription = StrConcat(DetailsParts, Chars.LF);
	
	If ToAdministrator And Not IsFullUser Then
		ErrorDescription = ErrorDescription + Chars.LF + Chars.LF
			+ NStr("en = 'Please contact the administrator.';");
	EndIf;
	
	ErrorsDescription.ErrorDescription = ErrorDescription;
	
EndProcedure

// Parameters:
//  ErrorTitle - String
//  ErrorsDescription - See NewErrorsDescription
//
Function TextOfTheProgramSearchError(Val ErrorTitle, ErrorsDescription) Export
	
	For Each Error In ErrorsDescription.Errors Do
		Break;
	EndDo;
	
	ErrorTitle = StrReplace(ErrorTitle, "%1", ErrorsDescription.ComputerName);
	Return ErrorTitle + " " + Error.LongDesc;
	
EndFunction

// For internal use only.
//
// Parameters:
//  Context - Structure:
//   * ApplicationDetails - Structure:
//      * Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//  Error - See NewErrorsDescription
//
// Returns:
//  CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
//
Function WriteCertificateToCatalog(Context, Error) Export
	
	Context.AdditionalParameters.Application = Context.ApplicationDetails.Ref;
	Try
		Certificate = DigitalSignatureInternalServerCall.WriteCertificateToCatalog(
			Context.CertificateData, Context.AdditionalParameters);
	Except
		Certificate = Undefined;
		Context.FormCaption = NStr("en = 'Cannot add certificate';");
		
		Error.Shared3 = True;
		Error.ErrorTitle = NStr("en = 'Couldn''t save the certificate due to:';");
		
		ErrorProperties = NewErrorProperties();
		ErrorProperties.LongDesc = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		Error.Errors.Add(ErrorProperties);
	EndTry;
	
	Return Certificate;
	
EndFunction

// For internal use only.
Function CertificateAddingErrorTitle(Operation, ComputerName = "") Export
	
	If ValueIsFilled(ComputerName) Then // IsServer flag.
		If Operation = "Signing" Then
			TitleTemplate1 = NStr("en = 'Cannot pass the signing check on the server %1 due to:';");
		ElsIf Operation = "Encryption" Then
			TitleTemplate1 = NStr("en = 'Cannot pass the encryption check on the server %1 due to:';");
		ElsIf Operation = "Details" Then
			TitleTemplate1 = NStr("en = 'Cannot pass the decryption check on the server %1 due to:';");
		EndIf;
		ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
			TitleTemplate1, ComputerName);
	Else
		If Operation = "Signing" Then
			ErrorTitle = NStr("en = 'Cannot pass the signing check on the computer due to:';");
		ElsIf Operation = "Encryption" Then
			ErrorTitle = NStr("en = 'Cannot pass the encryption check on the computer due to:';");
		ElsIf Operation = "Details" Then
			ErrorTitle = NStr("en = 'Cannot pass the decryption check on the computer due to:';");
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(ErrorTitle) Then
		CurrentErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect value of the Operation %1 parameter in the %2 procedure';"),
			Operation,
			"FillErrorAddingCertificate");
		Raise CurrentErrorText;
	EndIf;
	
	Return ErrorTitle;
	
EndFunction

// For internal use only.
//
// Parameters:
//  ErrorsDescription - See NewErrorsDescription
//  ApplicationDetails - Structure:
//   * Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//  Operation - String
//  ErrorText - String
//  IsFullUser - Boolean
//  BlankData - Boolean
//  ComputerName - String
//
Procedure FillErrorAddingCertificate(ErrorsDescription, ApplicationDetails, Operation,
			ErrorText, IsFullUser, BlankData = False, ComputerName = "") Export
	
	ErrorTitle = CertificateAddingErrorTitle(Operation, ComputerName);
	
	ErrorProperties = NewErrorProperties();
	ErrorProperties.LongDesc = ErrorText;
	ErrorProperties.Application = ApplicationDetails.Ref;
	
	If Not BlankData Then
		ErrorProperties.FromException = True;
		ErrorProperties.Instruction = True;
		ErrorProperties.ApplicationsSetUp = True;
	EndIf;
	
	If Not ValueIsFilled(ErrorsDescription.Errors) Then
		ErrorsDescription.ErrorTitle = ErrorTitle;
		
	ElsIf Not ValueIsFilled(ErrorsDescription.ErrorTitle) Then
		ErrorProperties.ErrorTitle = ErrorTitle;
		
	ElsIf ErrorsDescription.ErrorTitle <> ErrorTitle Then
		For Each CurrentProperties In ErrorsDescription.Errors Do
			CurrentProperties.ErrorTitle = ErrorsDescription.ErrorTitle;
		EndDo;
		ErrorsDescription.ErrorTitle = "";
		ErrorProperties.ErrorTitle = ErrorTitle;
	EndIf;
	
	ErrorsDescription.Errors.Add(ErrorProperties);
	
	FillCommonErrorsPresentation(ErrorsDescription, IsFullUser);
	
EndProcedure

// For internal use only.
Function CertificateCheckModes(IgnoreTimeValidity = False) Export
	
	CheckModesArray = New Array;
	
	#If WebClient Then
		CheckModesArray.Add(CryptoCertificateCheckMode.AllowTestCertificates);
	#EndIf
	
	If IgnoreTimeValidity Then
		CheckModesArray.Add(CryptoCertificateCheckMode.IgnoreTimeValidity);
	EndIf;
	
	Return CheckModesArray;
	
EndFunction

// For internal use only.
Function CertificateVerificationParametersInTheService(CommonSettings, CertificateCheckModes) Export
	
	If Not CommonSettings.YouCanCheckTheCertificateInTheCloudServiceWithTheFollowingParameters Then
		Return Undefined;
	EndIf;
	
	Modes = New Array;
	For Each Mode In CertificateCheckModes Do
		If Mode = CryptoCertificateCheckMode.IgnoreTimeValidity Then
			Modes.Add("IgnoreTimeValidity");
		ElsIf Mode = CryptoCertificateCheckMode.IgnoreSignatureValidity Then
			Modes.Add("IgnoreSignatureValidity");
		ElsIf Mode = CryptoCertificateCheckMode.IgnoreCertificateRevocationStatus Then
			Modes.Add("IgnoreCertificateRevocationStatus");
		ElsIf Mode = CryptoCertificateCheckMode.AllowTestCertificates Then
			Modes.Add("AllowTestCertificates");
		EndIf;
	EndDo;
	
	Return New Structure("CertificateVerificationMode", StrConcat(Modes, ","));
	
EndFunction

// For internal use only.
Function CertificateOverdue(Certificate, OnDate, TimeAddition) Export
	
	If Not ValueIsFilled(OnDate) Then
		Return "";
	EndIf;
	
	CertificateDates = CertificateDates(Certificate, TimeAddition);
	
	If CertificateDates.EndDate > BegOfDay(OnDate) Then
		Return "";
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Certificate is overdue on %1.';"), Format(BegOfDay(OnDate), "DLF=D"));
	
EndFunction

// For internal use only.
Function ServiceErrorTextCertificateInvalid() Export
	
	Return NStr("en = 'The service reported that the certificate is invalid.';");
	
EndFunction

// For internal use only.
//
// Returns:
//  String
//
Function ServiceErrorTextSignatureInvalid() Export
	
	Return NStr("en = 'The service reported that the signature is invalid.';");
	
EndFunction

// For internal use only.
Function StorageTypeToSearchCertificate(InPersonalStorageOnly) Export
	
	If TypeOf(InPersonalStorageOnly) = Type("CryptoCertificateStoreType") Then
		StoreType = InPersonalStorageOnly;
	ElsIf InPersonalStorageOnly Then
		StoreType = CryptoCertificateStoreType.PersonalCertificates;
	Else
		StoreType = Undefined; // 
	EndIf;
	
	Return StoreType;
	
EndFunction

// For internal use only.
Procedure AddCertificatesProperties(Table, CertificatesArray, NoFilter,
	TimeAddition, CurrentSessionDate, Parameters = Undefined) Export
	
	ThumbprintsOnly = False;
	InCloudService = False;
	CloudSignature = False;
	
	If Parameters <> Undefined Then
		If Parameters.Property("ThumbprintsOnly") Then
			ThumbprintsOnly = Parameters.ThumbprintsOnly;
		EndIf;
		If Parameters.Property("InCloudService") Then
			InCloudService = Parameters.InCloudService;
		EndIf;
		If Parameters.Property("CloudSignature") Then
			CloudSignature = Parameters.CloudSignature;
		EndIf;
	EndIf;
	
	If ThumbprintsOnly Then
		AlreadyAddedCertificatesThumbprints = Table;
		AtServer = False;
	Else
		AlreadyAddedCertificatesThumbprints = New Map; // 
		AtServer = TypeOf(Table) <> Type("Array");
	EndIf;
	
	For Each CurrentCertificate In CertificatesArray Do
		Thumbprint = Base64String(CurrentCertificate.Thumbprint);
		CertificateDates = CertificateDates(CurrentCertificate, TimeAddition);
		
		If CertificateDates.EndDate <= CurrentSessionDate Then
			If Not NoFilter Then
				Continue; // Skip overdue certificates.
			EndIf;
		EndIf;
		
		If AlreadyAddedCertificatesThumbprints.Get(Thumbprint) <> Undefined Then
			Continue;
		EndIf;
		AlreadyAddedCertificatesThumbprints.Insert(Thumbprint, True);
		
		If ThumbprintsOnly Then
			Continue;
		EndIf;
		
		LocationType = 1;
		If AtServer Then
			If CloudSignature Then
				LocationType = 3;
			ElsIf InCloudService Then
				LocationType = 4;
			Else
				LocationType = 2;
			EndIf;
			String = Table.Find(Thumbprint, "Thumbprint");
			If String <> Undefined Then
				If InCloudService Then
					String.InCloudService = True;
				EndIf;
				Continue; // Skipping certificates already added on the client.
			EndIf;
		EndIf;
		
		CertificateStatus = 2;
		If CertificateDates.EndDate <= CurrentSessionDate Then
			CertificateStatus = 4;
		ElsIf CertificateDates.EndDate <= CurrentSessionDate + 30*24*60*60 Then
			CertificateStatus = 3;
		EndIf;
		
		CertificateProperties = New Structure;
		CertificateProperties.Insert("Thumbprint", Thumbprint);
		CertificateProperties.Insert("Presentation",
			CertificatePresentation(CurrentCertificate, TimeAddition));
		CertificateProperties.Insert("IssuedBy", IssuerPresentation(CurrentCertificate));
		CertificateProperties.Insert("LocationType", LocationType);
		CertificateProperties.Insert("CertificateStatus", CertificateStatus);
		
		
		If TypeOf(Table) = Type("Array") Then
			Table.Add(CertificateProperties);
		Else
			If CloudSignature Then
				CertificateProperties.Insert("AtServer", False);
			ElsIf InCloudService Then
				CertificateProperties.Insert("InCloudService", True);
			ElsIf AtServer Then
				CertificateProperties.Insert("AtServer", True);
			EndIf;
			FillPropertyValues(Table.Add(), CertificateProperties);
		EndIf;
	EndDo;
	
EndProcedure

// For internal use only.
//
// Parameters:
//   Array - Array
//
Procedure AddCertificatesThumbprints(Array, CertificatesArray, TimeAddition, CurrentSessionDate) Export
	
	For Each CurrentCertificate In CertificatesArray Do
		Thumbprint = Base64String(CurrentCertificate.Thumbprint);
		If TypeOf(CurrentSessionDate) = Type("Date") Then
			CertificateDates = CertificateDates(CurrentCertificate, TimeAddition);
			
			If CertificateDates.EndDate <= CurrentSessionDate Then
				Continue; // Skipping overdue certificates.
			EndIf;
		EndIf;
		If Array.Find(Thumbprint) = Undefined Then
			Array.Add(Thumbprint);
		EndIf;
	EndDo;
	
EndProcedure

// For internal use only.
// 
// Parameters:
//  SignatureBinaryData - BinaryData, String -
//  CertificateProperties - See DigitalSignatureClient.CertificateProperties
//  Comment - String
//  AuthorizedUser - CatalogRef.Users
//  SignatureFileName - String - Signature file name.
//  SignatureParameters - See ParametersCryptoSignatures
//  
// Returns:
//  Structure:
//   * Signature - BinaryData
//   * SignatureSetBy - CatalogRef.Users
//   * Comment - String
//   * SignatureFileName - String 
//   * SignatureDate - Date -
//   * SignatureValidationDate - Date
//   * SignatureCorrect - Boolean
//   * Certificate - BinaryData
//   * Thumbprint - String
//   * CertificateOwner - String
//   * SignatureType - EnumRef.CryptographySignatureTypes
//   * DateActionLastTimestamp - Date
//   * DateSignedFromLabels - Date 
//   * UnverifiedSignatureDate - Date
//
Function SignatureProperties(SignatureBinaryData, CertificateProperties, Comment,
			AuthorizedUser, SignatureFileName = "", SignatureParameters = Undefined, IsVerificationRequired = False) Export
	
	SignatureProperties = New Structure;
	SignatureProperties.Insert("Signature",             SignatureBinaryData);
	SignatureProperties.Insert("SignatureSetBy", AuthorizedUser);
	SignatureProperties.Insert("Comment",         Comment);
	SignatureProperties.Insert("SignatureFileName",     SignatureFileName);
	SignatureProperties.Insert("SignatureDate",         Date('00010101')); // 
	SignatureProperties.Insert("SignatureValidationDate", Date('00010101')); // 
	SignatureProperties.Insert("SignatureCorrect",        False);             // 
	// 
	SignatureProperties.Insert("Certificate",          CertificateProperties.BinaryData);
	SignatureProperties.Insert("Thumbprint",           CertificateProperties.Thumbprint);
	SignatureProperties.Insert("CertificateOwner", CertificateProperties.IssuedTo);
	
	SignatureProperties.Insert("SignatureType");
	SignatureProperties.Insert("DateActionLastTimestamp");
	SignatureProperties.Insert("DateSignedFromLabels");
	SignatureProperties.Insert("UnverifiedSignatureDate");
	SignatureProperties.Insert("IsVerificationRequired", IsVerificationRequired);
	SignatureProperties.Insert("SignatureID");
	
	If SignatureParameters <> Undefined Then
		SignatureProperties.Insert("SignatureType", SignatureParameters.SignatureType);
		SignatureProperties.Insert("DateActionLastTimestamp", SignatureParameters.DateActionLastTimestamp);
		SignatureProperties.Insert("DateSignedFromLabels", SignatureParameters.DateSignedFromLabels);
		SignatureProperties.Insert("UnverifiedSignatureDate", SignatureParameters.UnverifiedSignatureDate);
	EndIf;
	
	Return SignatureProperties;
	
EndFunction

// For internal use only.
// Returns:
//  Date, Undefined - 
//
Function DateToVerifySignatureCertificate(SignatureParameters) Export
	
	If ValueIsFilled(CommonClientServer.StructureProperty(
		SignatureParameters, "DateSignedFromLabels", Undefined)) Then
		Return SignatureParameters.DateSignedFromLabels;
	EndIf;
	
	If ValueIsFilled(CommonClientServer.StructureProperty(
		SignatureParameters, "UnverifiedSignatureDate", Undefined)) Then
		Return SignatureParameters.UnverifiedSignatureDate;
	EndIf;
	
	Return Undefined;
	
EndFunction

// For internal use only.
// 
// Returns:
//  Structure - 
//   * SignatureType          - EnumRef.CryptographySignatureTypes
//   * DateActionLastTimestamp - Date, Undefined -
//   * DateSignedFromLabels - Date, Undefined -
//   * UnverifiedSignatureDate - Date -
//                                 - Undefined - 
//   * DateLastTimestamp - Date -
//   * Certificate   - CryptoCertificate -
//   * CertificateDetails - See DigitalSignatureClient.CertificateProperties.
//
Function ParametersCryptoSignatures(ContainerSignatures, TimeAddition, SessionDate) Export

	SignatureParameters = New Structure;
	
	SignatureParameters.Insert("SignatureType");
	SignatureParameters.Insert("DateActionLastTimestamp");
	SignatureParameters.Insert("CertificateLastTimestamp");
	SignatureParameters.Insert("DateSignedFromLabels");
	SignatureParameters.Insert("UnverifiedSignatureDate");
	SignatureParameters.Insert("DateLastTimestamp");
	SignatureParameters.Insert("CertificateDetails");
	SignatureParameters.Insert("Certificate");
		
	Signature = ContainerSignatures.Signatures[0];
	
	IsCertificateExists = IsCertificateExists(Signature.SignatureCertificate);
	
	If IsCertificateExists Then
		SignatureParameters.CertificateDetails = CertificateProperties(Signature.SignatureCertificate, TimeAddition);
	EndIf;
	
	DateSignedFromLabels = Date(3999, 12, 31);
	If ValueIsFilled(Signature.UnconfirmedTimeSignatures) Then
		SignatureParameters.UnverifiedSignatureDate = Signature.UnconfirmedTimeSignatures + TimeAddition;
	EndIf;
	
	SignatureParameters.SignatureType = CryptoSignatureType(Signature.SignatureType);
	DateActionLastTimestamp = Undefined;
	If Signature.SignatureTimestamp <> Undefined Then
		CertificateLastTimestamp = Signature.SignatureTimestamp.Signatures[0].SignatureCertificate; // CryptoCertificate
		DateActionLastTimestamp = CertificateLastTimestamp.ValidTo;
		DateSignedFromLabels = Min(DateSignedFromLabels, Signature.SignatureTimestamp.Date + TimeAddition);
		SignatureParameters.DateLastTimestamp = Signature.SignatureTimestamp.Date + TimeAddition;
	EndIf;
	
	If Signature.SignatureVerificationDataTimestamp <> Undefined Then
		CertificateLastTimestamp = Signature.SignatureVerificationDataTimestamp.Signatures[0].SignatureCertificate;  // CryptoCertificate
		DateActionLastTimestamp = CertificateLastTimestamp.ValidTo;
		DateSignedFromLabels = Min(DateSignedFromLabels, Signature.SignatureVerificationDataTimestamp.Date + TimeAddition);
		SignatureParameters.DateLastTimestamp = Signature.SignatureVerificationDataTimestamp.Date + TimeAddition;
	EndIf;
	
	If Signature.ArchiveTimestamps.Count() > 0 Then
		IndexLastLabels = Signature.ArchiveTimestamps.UBound();
		CertificateLastTimestamp = Signature.ArchiveTimestamps[IndexLastLabels].Signatures[0].SignatureCertificate; // CryptoCertificate
		DateActionLastTimestamp = CertificateLastTimestamp.ValidTo;
		DateSignedFromLabels = Min(DateSignedFromLabels, Signature.ArchiveTimestamps[0].Date + TimeAddition);
		SignatureParameters.DateLastTimestamp = Signature.ArchiveTimestamps[IndexLastLabels].Date;
	EndIf;
	
	If ValueIsFilled(DateActionLastTimestamp) Then
		SignatureParameters.DateActionLastTimestamp = DateActionLastTimestamp + TimeAddition; 
		SignatureParameters.CertificateLastTimestamp = CertificateLastTimestamp;
	ElsIf IsCertificateExists And SignatureParameters.CertificateDetails.ValidBefore < SessionDate Then
		SignatureParameters.DateActionLastTimestamp = SignatureParameters.CertificateDetails.ValidBefore;
		SignatureParameters.CertificateLastTimestamp = Signature.SignatureCertificate;
	ElsIf IsCertificateExists Then
		SignatureParameters.CertificateLastTimestamp = Signature.SignatureCertificate;
	EndIf;

	If DateSignedFromLabels <> Date(3999, 12, 31) Then
		SignatureParameters.DateSignedFromLabels = DateSignedFromLabels;
	EndIf;
		
	Return SignatureParameters;
	
EndFunction

// For internal use only.
Function CryptoSignatureType(SignatureTypeValue) Export
	
	#If MobileClient Then
	
	Return Undefined;
	
	#Else

	If TypeOf(SignatureTypeValue) = Type("CryptoSignatureType") Then
		If SignatureTypeValue = CryptoSignatureType.CAdESBES Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdEST Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESAv3 Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.ArchivalCAdESAv3");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESC Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.WithCompleteValidationDataReferencesCAdESC");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESXLongType2 Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.ExtendedLongCAdESXLongType2");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESAv2 Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.CAdESAv2");
		ElsIf SignatureTypeValue = CryptoSignatureType.CMS Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.NormalCMS");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESXLong Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLong");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESXLongType1 Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLongType1");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESXType1  Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType1");
		ElsIf SignatureTypeValue = CryptoSignatureType.CAdESXType2 Then
			Return PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType2");
		EndIf;
	Else
		If SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES") Then
			Return CryptoSignatureType.CAdESBES;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST") Then
			Return CryptoSignatureType.CAdEST;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.ArchivalCAdESAv3") Then
			Return CryptoSignatureType.CAdESAv3;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.WithCompleteValidationDataReferencesCAdESC") Then
			Return CryptoSignatureType.CAdESC;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.ExtendedLongCAdESXLongType2") Then
			Return CryptoSignatureType.CAdESXLongType2;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.CAdESAv2") Then
			Return CryptoSignatureType.CAdESAv2;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.NormalCMS") Then
			Return CryptoSignatureType.CMS;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLong") Then
			Return CryptoSignatureType.CAdESXLong;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLongType1") Then
			Return CryptoSignatureType.CAdESXLongType1;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType1") Then
			Return CryptoSignatureType.CAdESXType1;
		ElsIf SignatureTypeValue = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType2") Then
			Return CryptoSignatureType.CAdESXType2;
		EndIf;
	EndIf;
	
	Return Undefined;
	
	#EndIf
	
EndFunction

// For internal use only.
Function SignatureCreationSettings(SignatureType, TimestampServersAddresses) Export
	
	Result = New Structure("SignatureType, TimestampServersAddresses");
	Result.TimestampServersAddresses = TimestampServersAddresses;
	
	If Not ValueIsFilled(SignatureType) Then
		Result.SignatureType = CryptoSignatureType(
			PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES"));
		Return Result;
	EndIf;
	
	If SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST") 
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithCompleteValidationDataReferencesCAdESC")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ExtendedLongCAdESXLongType2")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ArchivalCAdESAv3") Then 
		
		If Result.TimestampServersAddresses.Count() = 0 Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'To create a signature of type ""%1"", fill in timestamp server addresses.';"), SignatureType);
		EndIf;
		
	ElsIf SignatureType <> PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES")
		And SignatureType <> PredefinedValue("Enum.CryptographySignatureTypes.NormalCMS") Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Creating a signature of type ""%1"" is not supported.';"), SignatureType);
	EndIf;
	
	Result.SignatureType = CryptoSignatureType(SignatureType);
	
	Return Result;
	
EndFunction

// For internal use only.
Function ToBeImproved(SignatureType, NewSignatureType) Export
	
	If NewSignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST")
		And SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES") Then
		Return True;
	EndIf;
	
	If NewSignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ArchivalCAdESAv3")
		And (SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithCompleteValidationDataReferencesCAdESC")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLong")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType1")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXType2")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.CAdESXLongType1")
		Or SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ExtendedLongCAdESXLongType2")) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For internal use only.
Function DataGettingErrorTitle(Operation) Export
	
	If Operation = "Signing" Then
		Return NStr("en = 'Cannot receive data for signing due to:';");
	ElsIf Operation = "Encryption" Then
		Return NStr("en = 'Cannot receive data to encrypt due to:';");
	ElsIf Operation = "ExtensionValiditySignature" Then
		Return NStr("en = 'Cannot receive the signature data to renew due to:';");
	Else
		Return NStr("en = 'Cannot receive data to decrypt due to:';");
	EndIf;
	
EndFunction

// For internal use only.
Function BlankSignatureData(SignatureData, ErrorDescription) Export
	
	If Not ValueIsFilled(SignatureData) Then
		ErrorDescription = NStr("en = 'Empty signature is generated.';");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For internal use only.
Function BlankEncryptedData(EncryptedData, ErrorDescription) Export
	
	If Not ValueIsFilled(EncryptedData) Then
		ErrorDescription = NStr("en = 'Empty encrypted data is generated.';");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For internal use only.
Function BlankDecryptedData(DecryptedData, ErrorDescription) Export
	
	If Not ValueIsFilled(DecryptedData) Then
		ErrorDescription = NStr("en = 'Empty decrypted data is generated.';");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// For internal use only.
Function GeneralDescriptionOfTheError(ErrorAtClient, ErrorAtServer, ErrorTitle = "") Export
	
	ErrorDetailsAtClient = SimplifiedErrorStructure(ErrorAtClient, ErrorTitle);
	ErrorDescriptionAtServer = SimplifiedErrorStructure(ErrorAtServer, ErrorTitle);
	
	If Not ValueIsFilled(ErrorDetailsAtClient.ErrorDescription)
	   And Not ValueIsFilled(ErrorDescriptionAtServer.ErrorDescription) Then
	
		GeneralDescriptionOfTheError = NStr("en = 'Unexpected error';");
		
	ElsIf Not ValueIsFilled(ErrorDetailsAtClient.ErrorDescription)
	      Or ErrorDetailsAtClient.NotSupported
	        And ValueIsFilled(ErrorDescriptionAtServer.ErrorDescription) Then
		
		If ValueIsFilled(ErrorDescriptionAtServer.ErrorTitle)
		   And ValueIsFilled(ErrorDescriptionAtServer.LongDesc) Then
		
			GeneralDescriptionOfTheError =
				  ErrorDescriptionAtServer.ErrorTitle
				+ Chars.LF + Chars.LF
				+ NStr("en = 'ON THE SERVER:';")
				+ Chars.LF + Chars.LF + ErrorDescriptionAtServer.LongDesc;
		Else
			GeneralDescriptionOfTheError =
				  NStr("en = 'ON THE SERVER:';")
				+ Chars.LF + Chars.LF + ErrorDescriptionAtServer.ErrorDescription;
		EndIf;
		
	ElsIf Not ValueIsFilled(ErrorDescriptionAtServer.ErrorDescription) Then
		GeneralDescriptionOfTheError = ErrorDetailsAtClient.ErrorDescription;
	Else
		If ErrorDetailsAtClient.ErrorTitle = ErrorDescriptionAtServer.ErrorTitle
		   And ValueIsFilled(ErrorDetailsAtClient.ErrorTitle) Then
			
			GeneralDescriptionOfTheError = ErrorDetailsAtClient.ErrorTitle + Chars.LF + Chars.LF;
			ErrorTextOnTheClient = ErrorDetailsAtClient.LongDesc;
			ErrorTextOnTheServer = ErrorDescriptionAtServer.LongDesc;
		Else
			GeneralDescriptionOfTheError = "";
			ErrorTextOnTheClient = ErrorDetailsAtClient.ErrorDescription;
			ErrorTextOnTheServer = ErrorDescriptionAtServer.ErrorDescription;
		EndIf;
		
		GeneralDescriptionOfTheError = GeneralDescriptionOfTheError
			+ NStr("en = 'ON THE SERVER:';")
			+ Chars.LF + Chars.LF + ErrorTextOnTheServer
			+ Chars.LF + Chars.LF
			+ NStr("en = 'ON THE COMPUTER:';")
			+ Chars.LF + Chars.LF + ErrorTextOnTheClient;
	EndIf;
	
	Return GeneralDescriptionOfTheError;
	
EndFunction

// For internal use only.
Function SigningDateUniversal(Data) Export
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.SignAlgorithm");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
		
	// SEQUENCE (PKCS #7 ContentInfo).
	SkipBlockStart(DataAnalysis, 0, 16);
		// OBJECT IDENTIFIER (contentType).
		SkipBlockStart(DataAnalysis, 0, 6);
			// 1.2.840.113549.1.7.2 signedData (PKCS #7).
			ToCheckTheDataBlock(DataAnalysis, "2A864886F70D010702");
			SkipTheParentBlock(DataAnalysis);
		// [0]CS             (content [0] EXPLICIT ANY DEFINED BY contentType OPTIONAL).
		SkipBlockStart(DataAnalysis, 2, 0);
			// SEQUENCE (content SignedData).
			SkipBlockStart(DataAnalysis, 0, 16);
				// INTEGER  (version          Version).
				SkipBlock(DataAnalysis, 0, 2);
				// SET      (digestAlgorithms DigestAlgorithmIdentifiers).
				SkipBlock(DataAnalysis, 0, 17);
				// SEQUENCE (contentInfo      ContentInfo).
				SkipBlock(DataAnalysis, 0, 16);
				// [0]CS    (certificates     [0] IMPLICIT ExtendedCertificatesAndCertificates OPTIONAL).
				SkipBlock(DataAnalysis, 2, 0, False);
				// [1]CS    (crls             [1] IMPLICIT CertificateRevocationLists OPTIONAL).
				SkipBlock(DataAnalysis, 2, 1, False);
				// SET      (signerInfos      SET OF SignerInfo).
				SkipBlockStart(DataAnalysis, 0, 17);
					// SEQUENCE (signerInfo SignerInfo).
					SkipBlockStart(DataAnalysis, 0, 16);
						// INTEGER  (version                   Version).
						SkipBlock(DataAnalysis, 0, 2);
						// SEQUENCE (issuerAndSerialNumber     IssuerAndSerialNumber).
						SkipBlock(DataAnalysis, 0, 16);
						// SEQUENCE (digestAlgorithm           DigestAlgorithmIdentifier).
						SkipBlock(DataAnalysis, 0, 16);
						// [0]CS    (authenticatedAttributes   [0] IMPLICIT Attributes OPTIONAL).
						SkipBlockStart(DataAnalysis, 2, 0);

	If DataAnalysis.HasError Then
		Return Undefined;
	EndIf;
	
	OffsetOfTheFollowing = DataAnalysis.Parents[0].OffsetOfTheFollowing;
	While DataAnalysis.Offset < OffsetOfTheFollowing Do
		
		// SEQUENCE (Attributes).
		SkipBlockStart(DataAnalysis, 0, 16);
		
		If DataAnalysis.HasError Then
			Return Undefined;
		EndIf; 
		
		// OBJECT IDENTIFIER
		SkipBlockStart(DataAnalysis, 0, 6);
		
		DataSize = DataAnalysis.Parents[0].DataSize;
		If DataSize = 0 Then
			WhenADataStructureErrorOccurs(DataAnalysis);
			Return Undefined;
		EndIf;
		
		If DataSize = 9 Then
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
			If BufferString = "2A864886F70D010905" Then // 1.2.840.113549.1.9.5 signingTime
				
				SigningDate = ReadDateFromClipboard(DataAnalysis.Buffer, DataAnalysis.Offset + 11);
				
				If ValueIsFilled(SigningDate) Then
					Return SigningDate;
				Else
					Return Undefined;
				EndIf;
				
			EndIf;
		EndIf; 
		SkipTheParentBlock(DataAnalysis); // OBJECT IDENTIFIER
		SkipTheParentBlock(DataAnalysis); // SEQUENCE
	EndDo;
	
	Return Undefined;
	
EndFunction

// For internal use only.
Function SignaturePropertiesFromBinaryData(Data, TimeAddition = Undefined, ShouldReadCertificates = False) Export
	
	SignatureProperties = New Structure;
	SignatureProperties.Insert("SignatureType", PredefinedValue("Enum.CryptographySignatureTypes.NormalCMS"));
	SignatureProperties.Insert("SigningDate");
	SignatureProperties.Insert("DateOfTimeStamp");
	SignatureProperties.Insert("Certificates", New Array);
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.SignaturePropertiesFromBinaryData");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
		
	// SEQUENCE (PKCS #7 ContentInfo).
	SkipBlockStart(DataAnalysis, 0, 16);
		// OBJECT IDENTIFIER (contentType).
		SkipBlockStart(DataAnalysis, 0, 6);
			// 1.2.840.113549.1.7.2 signedData (PKCS #7).
			ToCheckTheDataBlock(DataAnalysis, "2A864886F70D010702");
			If DataAnalysis.HasError Then
				SignatureProperties.SignatureType = Undefined;
				Return SignatureProperties;
			EndIf;
			SkipTheParentBlock(DataAnalysis);
		// [0]CS             (content [0] EXPLICIT ANY DEFINED BY contentType OPTIONAL).
		SkipBlockStart(DataAnalysis, 2, 0);
			// SEQUENCE (content SignedData).
			SkipBlockStart(DataAnalysis, 0, 16);
				// INTEGER  (version          Version).
				SkipBlock(DataAnalysis, 0, 2);
				// SET      (digestAlgorithms DigestAlgorithmIdentifiers).
				SkipBlock(DataAnalysis, 0, 17);
				// SEQUENCE (contentInfo      ContentInfo).
				SkipBlock(DataAnalysis, 0, 16);
				// [0]CS    (certificates [0] IMPLICIT CertificateSet OPTIONAL).
				If ShouldReadCertificates = False Then
					SkipBlock(DataAnalysis, 2, 0, False);
				Else
					If SkipBlockStart(DataAnalysis, 2, 0, False) Then
						// CertificateSet ::= SET OF Certificate Choices
						While True Do
							// Certificate
							Certificate = BlockRead(DataAnalysis, 0, 16);
							If Certificate = Undefined Then
								Break;
							EndIf;
							SignatureProperties.Certificates.Add(Certificate);
						EndDo;
						SkipTheParentBlock(DataAnalysis);
					EndIf;
				EndIf;
				// [1]CS    (crls             [1] IMPLICIT CertificateRevocationLists OPTIONAL).
				SkipBlock(DataAnalysis, 2, 1, False);
				// SET      (signerInfos      SET OF SignerInfo).
				SkipBlockStart(DataAnalysis, 0, 17);
					// SEQUENCE (signerInfo SignerInfo).
					SkipBlockStart(DataAnalysis, 0, 16);
						// INTEGER  (version                   Version).
						SkipBlock(DataAnalysis, 0, 2);
						// SEQUENCE (issuerAndSerialNumber     IssuerAndSerialNumber).
						SkipBlock(DataAnalysis, 0, 16);
						// SEQUENCE (digestAlgorithm           DigestAlgorithmIdentifier).
						SkipBlock(DataAnalysis, 0, 16);
						// [0]CS    (authenticatedAttributes   [0] IMPLICIT Attributes OPTIONAL).
						SkipBlockStart(DataAnalysis, 2, 0);

	If DataAnalysis.HasError Then
		Return SignatureProperties;
	EndIf;
	
	ThereIsMessageDigest = False; // 1.2.840.113549.1.9.4
	ThereIsContentType = False; // 1.2.840.113549.1.9.3
	ThereIsCertificateBranch = False; // 

	OffsetOfTheFollowing = DataAnalysis.Parents[0].OffsetOfTheFollowing;
	While DataAnalysis.Offset < OffsetOfTheFollowing And Not DataAnalysis.HasError Do
		
		// SEQUENCE (Attributes).
		SkipBlockStart(DataAnalysis, 0, 16);
		
		If DataAnalysis.HasError Then
			Break;
		EndIf; 
		
		// OBJECT IDENTIFIER
		SkipBlockStart(DataAnalysis, 0, 6);
		
		DataSize = DataAnalysis.Parents[0].DataSize;
		If DataSize = 0 Then
			WhenADataStructureErrorOccurs(DataAnalysis);
			Break;
		EndIf;
				
		If DataSize = 9 Then
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);

			If BufferString = "2A864886F70D010904" Then // 1.2.840.113549.1.9.4 messageDigest
				ThereIsMessageDigest = True;
			ElsIf BufferString = "2A864886F70D010903" Then // 1.2.840.113549.1.9.3 contentType
				ThereIsContentType = True;
			ElsIf BufferString = "2A864886F70D010905" Then // 1.2.840.113549.1.9.5 signingTime
				
				SigningDate = ReadDateFromClipboard(DataAnalysis.Buffer, DataAnalysis.Offset + 11);
				
				If ValueIsFilled(SigningDate) Then
					SignatureProperties.SigningDate = SigningDate + ?(ValueIsFilled(TimeAddition),
						TimeAddition, 0);
				EndIf;
				
			EndIf;
		
		ElsIf DataSize = 11 Then
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
			
			If BufferString = "2A864886F70D010910022F" Then // 1.2.840.113549.1.9.16.2.47 signingCertificateV2
				ThereIsCertificateBranch = True;
			ElsIf BufferString = "2A864886F70D010910020C" Then // 1.2.840.113549.1.9.16.2.12 signingCertificate
				ThereIsCertificateBranch = True;
			EndIf;
		EndIf;
		
		SkipTheParentBlock(DataAnalysis); // OBJECT IDENTIFIER
		SkipTheParentBlock(DataAnalysis); // SEQUENCE
	EndDo;
	
	If ThereIsCertificateBranch And ThereIsMessageDigest And ThereIsContentType Then
		SignatureProperties.SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.BasicCAdESBES");
	Else
		Return SignatureProperties;
	EndIf;
	
	SkipTheParentBlock(DataAnalysis); // [0]CS
	
	// SEQUENCE (digestEncryptionAlgorithm AlgorithmIdentifier).
	SkipBlock(DataAnalysis, 0, 16);
	// signature SignatureValue
	SkipBlock(DataAnalysis, 0, 4); 
	// [1]CS    (unsignedAttrs [1] IMPLICIT UnsignedAttributes OPTIONAL).
	SkipBlockStart(DataAnalysis, 2, 1);

	ThereIsTimestampBranch = False; // 1.2.840.113549.1.9.16.2.14 
	ThereIsBranchDescriptionOfCertificates = False; // 1.2.840.113549.1.9.16.2.21
	ThereIsBranchDescriptionOfReview = False; // 1.2.840.113549.1.9.16.2.22
	ThereIsBranchValueOfCertificates = False; // 1.2.840.113549.1.9.16.2.23
	ThereIsBranchReviewValue = False; // 1.2.840.113549.1.9.16.2.24
	ThereIsBranchListOfReviewServers = False; // 1.2.840.113549.1.9.16.2.26
	ThereIsArchiveBranch = False; // 0.4.0.1733.2.5
	
	OffsetOfTheFollowing = DataAnalysis.Parents[0].OffsetOfTheFollowing;
	While DataAnalysis.Offset < OffsetOfTheFollowing And Not DataAnalysis.HasError Do
		
		// SEQUENCE (Attributes).
		SkipBlockStart(DataAnalysis, 0, 16);

		If DataAnalysis.HasError Then
			Break;
		EndIf; 
		
		// OBJECT IDENTIFIER
		SkipBlockStart(DataAnalysis, 0, 6);

		DataSize = DataAnalysis.Parents[0].DataSize;
		If DataSize = 0 Then
			WhenADataStructureErrorOccurs(DataAnalysis);
			Break;
		EndIf;
		
		If DataSize = 11 Then
			
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
			If BufferString = "2A864886F70D010910020E" Then // 1.2.840.113549.1.9.16.2.14 timeStampToken
				
				ThereIsTimestampBranch = True;
				
				DataSize = DataAnalysis.Parents[1].DataSize - 13;
				
				// SET
				Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset + 11, DataSize);
				DateOfTimeStamp = ReadDateFromTimeStamp(Buffer);
				If ValueIsFilled(DateOfTimeStamp) Then
					SignatureProperties.DateOfTimeStamp = DateOfTimeStamp + ?(ValueIsFilled(TimeAddition),
						TimeAddition, 0);
				EndIf;
				
			ElsIf BufferString = "2A864886F70D0109100215" Then // 1.2.840.113549.1.9.16.2.21 certificateRefs
				ThereIsBranchDescriptionOfCertificates = True;	
			ElsIf BufferString = "2A864886F70D0109100216" Then // 1.2.840.113549.1.9.16.2.22 revocationRefs
				ThereIsBranchDescriptionOfReview = True;
			ElsIf BufferString = "2A864886F70D0109100217" Then // 1.2.840.113549.1.9.16.2.23 certValues
				ThereIsBranchValueOfCertificates = True;
			ElsIf BufferString = "2A864886F70D0109100218" Then // 1.2.840.113549.1.9.16.2.24 revocationValues
				ThereIsBranchReviewValue = True;
			ElsIf BufferString = "2A864886F70D010910021A" Then // 1.2.840.113549.1.9.16.2.26 certCRLTimestamp
				ThereIsBranchListOfReviewServers = True; 
			EndIf;
			
		EndIf;

		If DataSize = 6 Then
			Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
			BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
			If BufferString = "04008D450204" Then // 0.4.0.1733.2.4 archiveTimestampV3 attribute
				ThereIsArchiveBranch = True;
			EndIf;
		EndIf;

		SkipTheParentBlock(DataAnalysis); // OBJECT IDENTIFIER
		SkipTheParentBlock(DataAnalysis); // SEQUENCE
	EndDo;

	SignatureType = Undefined;
	If ThereIsArchiveBranch Then
		SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ArchivalCAdESAv3");
	ElsIf ThereIsTimestampBranch And ThereIsBranchDescriptionOfCertificates And ThereIsBranchDescriptionOfReview
		And ThereIsBranchValueOfCertificates And ThereIsBranchReviewValue And ThereIsBranchListOfReviewServers Then
		SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.ExtendedLongCAdESXLongType2");
	ElsIf ThereIsTimestampBranch And ThereIsBranchDescriptionOfCertificates And ThereIsBranchDescriptionOfReview Then
		SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithCompleteValidationDataReferencesCAdESC");
	ElsIf ThereIsTimestampBranch Then
		SignatureType = PredefinedValue("Enum.CryptographySignatureTypes.WithTimeCAdEST");
	EndIf;

	If ValueIsFilled(SignatureType) Then
		SignatureProperties.SignatureType = SignatureType;
	EndIf;
	
	Return SignatureProperties;
	
EndFunction

Function ReadDateFromClipboard(Buffer, Offset) Export
	
	Date_Type = GetHexStringFromBinaryDataBuffer(Buffer.Read(Offset, 2));
	If Date_Type = "170D" Then // UTCTime
		DateBuffer = Buffer.Read(Offset + 2, 12);
		DatePresentation = "20" + GetStringFromBinaryDataBuffer(DateBuffer);
	Else // GeneralizedTime
		DateBuffer = Buffer.Read(Offset + 2, 14);
		DatePresentation = GetStringFromBinaryDataBuffer(DateBuffer);
	EndIf;

	TypeDetails = New TypeDescription("Date");
	SigningDate = TypeDetails.AdjustValue(DatePresentation);
	Return SigningDate;
	
EndFunction

// 
Function ReadDateFromTimeStamp(Buffer)
	
	DataAnalysis = New Structure;
	DataAnalysis.Insert("HasError", False);
	DataAnalysis.Insert("ThisIsAnASN1EncodingError", False); // 
	DataAnalysis.Insert("ThisIsADataStructureError", False); // 
	DataAnalysis.Insert("Offset", 0);
	DataAnalysis.Insert("Parents", New Array);
	DataAnalysis.Insert("Buffer", Buffer);
	
	// SET
	SkipBlockStart(DataAnalysis, 0, 17);
	// SEQUENCE
	SkipBlockStart(DataAnalysis, 0, 16);
	// OBJECT IDENTIFIER signedData
	SkipBlock(DataAnalysis, 0, 6);
		// [0]
		SkipBlockStart(DataAnalysis, 2, 0);
			// SEQUENCE
			SkipBlockStart(DataAnalysis, 0, 16);
			// INTEGER  (version          Version).
			SkipBlock(DataAnalysis, 0, 2);
			// SET
			SkipBlock(DataAnalysis, 0, 17);
				// SEQUENCE
				SkipBlockStart(DataAnalysis, 0, 16); 
				// OBJECT IDENTIFIER
				SkipBlock(DataAnalysis, 0, 6); 
					// [0]
					SkipBlockStart(DataAnalysis, 2, 0);
						// OCTET STRING
						SkipBlockStart(DataAnalysis, 0, 4);
						// SEQUENCE
						SkipBlockStart(DataAnalysis, 0, 16);
						// INTEGER
						SkipBlock(DataAnalysis, 0, 2);
						// OBJECT IDENTIFIER
						SkipBlock(DataAnalysis, 0, 6);
						// SEQUENCE
						SkipBlock(DataAnalysis, 0, 16);
						// INTEGER
						SkipBlock(DataAnalysis, 0, 2);

	If DataAnalysis.HasError Then
		StampDate = Undefined;
	Else
		// GeneralizedTime
		DateBuffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset + 2, 14);
		DatePresentation = GetStringFromBinaryDataBuffer(DateBuffer);
		TypeDetails = New TypeDescription("Date");
		StampDate = TypeDetails.AdjustValue(DatePresentation);
	EndIf;
	
	Return StampDate;
	
EndFunction

// Finds the tag content in XML.
//
// Parameters:
//  Text                             - String - a searched XML text.
//  NameTag                           - String - a tag whose content is to be found.
//  IncludeStartEndTag - Boolean - flag shows whether the items found by the tag are required. 
//                                               This tag was used for the search, the default value is False.
//  SerialNumber                    - Number  - a position, from which the search starts, the default value is 1.
// 
// Returns:
//   String - String with removed new line characters and a carriage return.
//
Function FindInXML(Text, NameTag, IncludeStartEndTag = False, SerialNumber = 1) Export
	
	Result = Undefined;
	
	Begin    = "<"  + NameTag;
	Ending = "</" + NameTag + ">";
	
	Content = Mid(
		Text,
		StrFind(Text, Begin, SearchDirection.FromBegin, 1, SerialNumber),
		StrFind(Text, Ending, SearchDirection.FromBegin, 1, SerialNumber) + StrLen(Ending) - StrFind(Text, Begin, SearchDirection.FromBegin, 1, SerialNumber));
		
	If IncludeStartEndTag Then
		
		Result = TrimAll(Content);
		
	Else
		
		StartTag = Left(Content, StrFind(Content, ">"));
		Content = StrReplace(Content, StartTag, "");
		
		EndTag1 = Right(Content, StrLen(Content) - StrFind(Content, "<", SearchDirection.FromEnd) + 1);
		Content = StrReplace(Content, EndTag1, "");
		
		Result = TrimAll(Content);
		
	EndIf;
	
	Return Result;
	
EndFunction

// For internal use only.
Function CertificateFromSOAPEnvelope(SOAPEnvelope, AsBase64 = True) Export
	
	Base64Certificate = FindInXML(SOAPEnvelope, "wsse:BinarySecurityToken");
	
	If AsBase64 Then
		Return Base64Certificate;
	EndIf;
	
	Return Base64Value(Base64Certificate);
	
EndFunction

// See DigitalSignatureClient.CertificatePresentation.
Function CertificatePresentation(Certificate, TimeAddition) Export
	
	Presentation = "";
	DigitalSignatureClientServerLocalization.OnGetCertificatePresentation(Certificate, TimeAddition, Presentation);
	If IsBlankString(Presentation) Then
		CertificateDates = CertificateDates(Certificate, TimeAddition);
		Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, to %2';"),
			SubjectPresentation(Certificate),
			Format(CertificateDates.EndDate, "DF=MM.yyyy"));
	EndIf;	
	Return Presentation;
	
EndFunction

// See DigitalSignatureClient.SubjectPresentation.
Function SubjectPresentation(Certificate) Export 
	
	Presentation = "";
	DigitalSignatureClientServerLocalization.OnGetSubjectPresentation(Certificate, Presentation);
	If IsBlankString(Presentation) Then
		Subject = CertificateSubjectProperties(Certificate);
		If ValueIsFilled(Subject.CommonName) Then
			Presentation = Subject.CommonName;
		EndIf;
	EndIf;	
	Return Presentation;
	
EndFunction

// See DigitalSignatureClient.IssuerPresentation.
Function IssuerPresentation(Certificate) Export
	
	Issuer = CertificateIssuerProperties(Certificate);
	
	Presentation = "";
	
	If ValueIsFilled(Issuer.CommonName) Then
		Presentation = Issuer.CommonName;
	EndIf;
	
	If ValueIsFilled(Issuer.CommonName)
	   And ValueIsFilled(Issuer.Organization)
	   And StrFind(Issuer.CommonName, Issuer.Organization) = 0 Then
		
		Presentation = Issuer.CommonName + ", " + Issuer.Organization;
	EndIf;
	
	If ValueIsFilled(Issuer.Department) Then
		Presentation = Presentation + ", " + Issuer.Department;
	EndIf;
	
	Return Presentation;
	
EndFunction

Function CertificateProperties(Certificate, TimeAddition) Export
	
	CertificateDates = CertificateDates(Certificate, TimeAddition);
	
	Properties = New Structure;
	Properties.Insert("Thumbprint",      Base64String(Certificate.Thumbprint));
	Properties.Insert("SerialNumber",  Certificate.SerialNumber);
	Properties.Insert("Presentation",  CertificatePresentation(Certificate, TimeAddition));
	Properties.Insert("IssuedTo",      SubjectPresentation(Certificate));
	Properties.Insert("IssuedBy",       IssuerPresentation(Certificate));
	Properties.Insert("StartDate",     CertificateDates.StartDate);
	Properties.Insert("EndDate",  CertificateDates.EndDate);
	Properties.Insert("ValidBefore", CertificateDates.EndDate);
	Properties.Insert("Purpose",     GetPurpose(Certificate));
	Properties.Insert("Signing",     Certificate.UseToSign);
	Properties.Insert("Encryption",     Certificate.UseToEncrypt);
	
	Return Properties;
	
EndFunction

// Fills in the table of certificate description from four fields: IssuedTo, IssuedBy, ValidTo, Purpose.
Procedure FillCertificateDataDetails(Table, CertificateProperties) Export
	
	If CertificateProperties.Signing And CertificateProperties.Encryption Then
		Purpose = NStr("en = 'Data signing, Data encryption';");
		
	ElsIf CertificateProperties.Signing Then
		Purpose = NStr("en = 'Data signing';");
	Else
		Purpose = NStr("en = 'Data encryption';");
	EndIf;
	
	Table.Clear();
	String = Table.Add();
	String.Property = NStr("en = 'Owner:';");
	String.Value = TrimAll(CertificateProperties.IssuedTo);
	
	String = Table.Add();
	String.Property = NStr("en = 'Issued by:';");
	String.Value = TrimAll(CertificateProperties.IssuedBy);
	
	String = Table.Add();
	String.Property = NStr("en = 'Expiration date:';");
	String.Value = Format(CertificateProperties.ValidBefore, "DLF=D");
	
	String = Table.Add();
	String.Property = NStr("en = 'Purpose:';");
	String.Value = Purpose;
	
EndProcedure

Function CertificateSubjectProperties(Certificate) Export
	
	Subject = Certificate.Subject;
	
	Properties = New Structure;
	Properties.Insert("CommonName");
	Properties.Insert("Country");
	Properties.Insert("State");
	Properties.Insert("Locality");
	Properties.Insert("Street");
	Properties.Insert("Organization");
	Properties.Insert("Department");
	Properties.Insert("Email");
	Properties.Insert("LastName");
	Properties.Insert("Name");
	
	If Subject.Property("CN") Then
		Properties.CommonName = PrepareRow(Subject.CN);
	EndIf;
	
	If Subject.Property("C") Then
		Properties.Country = PrepareRow(Subject.C);
	EndIf;
	
	If Subject.Property("ST") Then
		Properties.State = PrepareRow(Subject.ST);
	EndIf;
	
	If Subject.Property("L") Then
		Properties.Locality = PrepareRow(Subject.L);
	EndIf;
	
	If Subject.Property("Street") Then
		Properties.Street = PrepareRow(Subject.Street);
	EndIf;
	
	If Subject.Property("O") Then
		Properties.Organization = PrepareRow(Subject.O);
	EndIf;
	
	If Subject.Property("OU") Then
		Properties.Department = PrepareRow(Subject.OU);
	EndIf;
	
	If Subject.Property("E") Then
		Properties.Email = PrepareRow(Subject.E);
	EndIf;
	
	Extensions = Undefined;
	DigitalSignatureClientServerLocalization.OnGetExtendedCertificateSubjectProperties(Subject, Extensions);
	If TypeOf(Extensions) = Type("Structure") Then
		CommonClientServer.SupplementStructure(Properties, Extensions, True);
	EndIf;
	
	Return Properties;
	
EndFunction

// See DigitalSignatureClient.CertificateIssuerProperties.
Function CertificateIssuerProperties(Certificate) Export
	
	Issuer = Certificate.Issuer;
	
	Properties = New Structure;
	Properties.Insert("CommonName");
	Properties.Insert("Country");
	Properties.Insert("State");
	Properties.Insert("Locality");
	Properties.Insert("Street");
	Properties.Insert("Organization");
	Properties.Insert("Department");
	Properties.Insert("Email");
	
	If Issuer.Property("CN") Then
		Properties.CommonName = PrepareRow(Issuer.CN);
	EndIf;
	
	If Issuer.Property("C") Then
		Properties.Country = PrepareRow(Issuer.C);
	EndIf;
	
	If Issuer.Property("ST") Then
		Properties.State = PrepareRow(Issuer.ST);
	EndIf;
	
	If Issuer.Property("L") Then
		Properties.Locality = PrepareRow(Issuer.L);
	EndIf;
	
	If Issuer.Property("Street") Then
		Properties.Street = PrepareRow(Issuer.Street);
	EndIf;
	
	If Issuer.Property("O") Then
		Properties.Organization = PrepareRow(Issuer.O);
	EndIf;
	
	If Issuer.Property("OU") Then
		Properties.Department = PrepareRow(Issuer.OU);
	EndIf;
	
	If Issuer.Property("E") Then
		Properties.Email = PrepareRow(Issuer.E);
	EndIf;
	
	Extensions = Undefined;
	DigitalSignatureClientServerLocalization.OnGetExtendedCertificateIssuerProperties(Issuer, Extensions);
	If TypeOf(Extensions) = Type("Structure") Then
		CommonClientServer.SupplementStructure(Properties, Extensions, True);
	EndIf;
	
	Return Properties;
	
EndFunction

// 
// 
// Parameters:
//   IssuedTo - Array of String
//             - String
//            
// Returns:
//   - Array of String -  
//   - String - 
//
Function ConvertIssuedToIntoFullName(IssuedTo) Export
	
	If TypeOf(IssuedTo) = Type("Array") Then
		For Each ItemIssuedTo In IssuedTo Do
			StringLength = StrFind(ItemIssuedTo, ",");
			ItemIssuedTo = TrimAll(?(StringLength = 0, ItemIssuedTo, Left(ItemIssuedTo, StringLength - 1)));
		EndDo; 
	Else	
		StringLength = StrFind(IssuedTo, ",");
		IssuedTo = TrimAll(?(StringLength = 0, IssuedTo, Left(IssuedTo, StringLength - 1)));
	EndIf;
	
	Return IssuedTo;
	
EndFunction

// Add-in connection details (ExtraCryptoAPI).
//
// Returns:
//  Structure:
//   * FullTemplateName - String
//   * ObjectName      - String
//
Function ComponentDetails() Export
	
	Parameters = New Structure;
	Parameters.Insert("ObjectName", "ExtraCryptoAPI");
	Parameters.Insert("FullTemplateName",
		"Catalog.DigitalSignatureAndEncryptionKeysCertificates.Template.ComponentExtraCryptoAPI");
	Return Parameters;
	
EndFunction

Function IdentifiersOfHashingAlgorithmsAndThePublicKey() Export
	
	IDs = New Array;
	
	Sets = SetsOfAlgorithmsForCreatingASignature();
	For Each Set In Sets Do
		IDs.Add("<" + Set.IDOfThePublicKeyAlgorithm + "> <" + Set.IdOfTheHashingAlgorithm + ">");
	EndDo;
	
	Return StrConcat(IDs, Chars.LF) + Chars.LF;
	
EndFunction

// See DigitalSignatureClient.XMLEnvelope.
Function XMLEnvelope(Parameters) Export
	
	If Parameters = Undefined Then
		Parameters = XMLEnvelopeParameters();
	EndIf;
	
	XMLEnvelope = Undefined;
	DigitalSignatureClientServerLocalization.OnReceivingXMLEnvelope(Parameters, XMLEnvelope);
	
	If XMLEnvelope = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 unknown value of the %2 parameter is specified in the %3 function';"),
				Parameters.Variant, "Variant", "XMLEnvelope");
		Raise ErrorText;
	EndIf;
	
	If ValueIsFilled(Parameters.XMLMessage) Then
		XMLEnvelope = StrReplace(XMLEnvelope, "%MessageXML%", TrimAll(Parameters.XMLMessage));
	EndIf;
	
	Return XMLEnvelope;
	
EndFunction

// See DigitalSignatureClient.XMLEnvelopeParameters.
Function XMLEnvelopeParameters() Export
	
	Result = New Structure;
	
	EnvelopVariant = "";
	DigitalSignatureClientServerLocalization.OnGetDefaultEnvelopeVariant(EnvelopVariant);
	
	Result.Insert("Variant", EnvelopVariant);
	Result.Insert("XMLMessage", "");
	
	Return Result;
	
EndFunction

// See DigitalSignatureClient.XMLDSigParameters.
Function XMLDSigParameters() Export
	
	SigningAlgorithmData = New Structure;
	
	SigningAlgorithmData.Insert("XPathSignedInfo",       "");
	SigningAlgorithmData.Insert("XPathTagToSign", "");
	
	SigningAlgorithmData.Insert("OIDOfPublicKeyAlgorithm", "");
	
	SigningAlgorithmData.Insert("SIgnatureAlgorithmName", "");
	SigningAlgorithmData.Insert("SignatureAlgorithmOID", "");
	
	SigningAlgorithmData.Insert("HashingAlgorithmName", "");
	SigningAlgorithmData.Insert("HashingAlgorithmOID", "");
	
	SigningAlgorithmData.Insert("SignAlgorithm",     "");
	SigningAlgorithmData.Insert("HashAlgorithm", "");
	
	Return SigningAlgorithmData;
	
EndFunction

Function XMLSignatureVerificationErrorText(SignatureCorrect, HashMaps) Export
	
	If SignatureCorrect Then
		ErrorText = NStr("en = 'Invalid signature (%1 is valid, %2 is invalid).';");
	ElsIf HashMaps Then
		ErrorText = NStr("en = 'Invalid signature (%1 is invalid, %2 is valid).';");
	Else
		ErrorText = NStr("en = 'Invalid signature (%1 is invalid, %2 is invalid).';");
	EndIf;
	Return StringFunctionsClientServer.SubstituteParametersToString(ErrorText, "SignatureValue", "DigestValue");
	
EndFunction

// Returns:
//   See ANewSetOfAlgorithmsForCreatingASignature
//  Undefined - if a set is not found.
//
Function ASetOfAlgorithmsForCreatingASignature(IDOfThePublicKeyAlgorithm)
	
	Sets = SetsOfAlgorithmsForCreatingASignature();
	For Each Set In Sets Do
		If Set.IDOfThePublicKeyAlgorithm = IDOfThePublicKeyAlgorithm Then
			Return Set;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

// Converts the binary data of the crypto certificate into
// the correctly formatted string in the Base64 format.
//
// Parameters:
//  CertificateData - BinaryData - the binary data of the crypto certificate.
// 
// Returns:
//  String - 
//
Function Base64CryptoCertificate(CertificateData) Export
	
	Base64Row = Base64String(CertificateData);
	
	Value = StrReplace(Base64Row, Chars.CR, "");
	Value = StrReplace(Value, Chars.LF, "");
	
	Return Value;
	
EndFunction

// Parameters:
//  Base64CryptoCertificate - String - the Base64 string.
//  SigningAlgorithmData    - See DigitalSignatureClient.XMLDSigParameters
//  RaiseException1           - Boolean
//  XMLEnvelopeProperties          - See DigitalSignatureInternal.XMLEnvelopeProperties
//  
// Returns:
//   String - 
//
Function CheckChooseSignAlgorithm(Base64CryptoCertificate, SigningAlgorithmData,
			RaiseException1 = False, XMLEnvelopeProperties = Undefined) Export
	
	OIDOfPublicKeyAlgorithm = CertificateSignAlgorithm(
		Base64Value(Base64CryptoCertificate),, True);
	
	If Not ValueIsFilled(OIDOfPublicKeyAlgorithm) Then
		ErrorText = NStr("en = 'Cannot get a public key algorithm from the certificate.';");
		If RaiseException1 Then
			Raise ErrorText;
		EndIf;
		Return ErrorText;
	EndIf;
	
	SigningAlgorithmData.Insert("SelectedSignatureAlgorithmOID",     Undefined);
	SigningAlgorithmData.Insert("SelectedHashAlgorithmOID", Undefined);
	SigningAlgorithmData.Insert("SelectedSignatureAlgorithm",          Undefined);
	SigningAlgorithmData.Insert("SelectedHashAlgorithm",      Undefined);
	
	OIDOfPublicKeyAlgorithms = StrSplit(SigningAlgorithmData.OIDOfPublicKeyAlgorithm, Chars.LF);
	SignAlgorithmsOID        = StrSplit(SigningAlgorithmData.SignatureAlgorithmOID,        Chars.LF);
	HashAlgorithmsOID    = StrSplit(SigningAlgorithmData.HashingAlgorithmOID,    Chars.LF);
	SignAlgorithms            = StrSplit(SigningAlgorithmData.SignAlgorithm,            Chars.LF);
	HashAlgorithms        = StrSplit(SigningAlgorithmData.HashAlgorithm,        Chars.LF);
	
	TheAlgorithmsAreSpecified = False;
	For IndexOf = 0 To OIDOfPublicKeyAlgorithms.Count() - 1 Do
		
		If OIDOfPublicKeyAlgorithm = OIDOfPublicKeyAlgorithms[IndexOf] Then
			
			SigningAlgorithmData.SelectedSignatureAlgorithmOID     = SignAlgorithmsOID[IndexOf];
			SigningAlgorithmData.SelectedHashAlgorithmOID = HashAlgorithmsOID[IndexOf];
			SigningAlgorithmData.SelectedSignatureAlgorithm          = SignAlgorithms[IndexOf];
			SigningAlgorithmData.SelectedHashAlgorithm      = HashAlgorithms[IndexOf];
			
			TheAlgorithmsAreSpecified = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not TheAlgorithmsAreSpecified Then
		SetOfAlgorithms = ASetOfAlgorithmsForCreatingASignature(
			OIDOfPublicKeyAlgorithm);
		
		If SetOfAlgorithms <> Undefined Then
			SigningAlgorithmData.SelectedSignatureAlgorithmOID     = SetOfAlgorithms.IDOfTheSignatureAlgorithm;
			SigningAlgorithmData.SelectedHashAlgorithmOID = SetOfAlgorithms.IdOfTheHashingAlgorithm;
			SigningAlgorithmData.SelectedSignatureAlgorithm          = SetOfAlgorithms.NameOfTheXMLSignatureAlgorithm;
			SigningAlgorithmData.SelectedHashAlgorithm      = SetOfAlgorithms.NameOfTheXMLHashingAlgorithm;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(SigningAlgorithmData.SelectedSignatureAlgorithmOID)
	 Or Not ValueIsFilled(SigningAlgorithmData.SelectedHashAlgorithmOID)
	 Or Not ValueIsFilled(SigningAlgorithmData.SelectedSignatureAlgorithm)
	 Or Not ValueIsFilled(SigningAlgorithmData.SelectedHashAlgorithm) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Signing and hash algorithms to create a signature
			           |that match the public key algorithm of the certificate (OID %1) are not specified.';"),
			OIDOfPublicKeyAlgorithm);
		
		If RaiseException1 Then
			Raise ErrorText;
		EndIf;
		Return ErrorText;
	EndIf;
	
	If TheAlgorithmsAreSpecified
	 Or XMLEnvelopeProperties = Undefined
	 Or Not XMLEnvelopeProperties.CheckSignature Then
		Return "";
	EndIf;
	
	If XMLEnvelopeProperties.SignAlgorithm.Id
	     <> SigningAlgorithmData.SelectedSignatureAlgorithmOID Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The specified signing algorithm
			           |%1 (%2 OID)
			           |in the XML document does not match the signing algorithm in the %3 OID certificate.';"),
			XMLEnvelopeProperties.SignAlgorithm.Name,
			XMLEnvelopeProperties.SignAlgorithm.Id,
			SigningAlgorithmData.SelectedSignatureAlgorithmOID);
		
		If RaiseException1 Then
			Raise ErrorText;
		EndIf;
		Return ErrorText;
	EndIf;
	
	Return "";
	
EndFunction

// See DigitalSignatureClient.CMSParameters.
Function CMSParameters() Export
	
	Parameters = New Structure;
	
	Parameters.Insert("SignatureType",   "CAdES-BES");
	Parameters.Insert("DetachedAddIn", False);
	Parameters.Insert("IncludeCertificatesInSignature",
		CryptoCertificateIncludeMode.IncludeWholeChain);
	
	Return Parameters;
	
EndFunction

Function AddInParametersCMSSign(CMSParameters, DataDetails) Export
	
	AddInParameters = New Structure;
	
	If TypeOf(DataDetails) = Type("String")
	   And IsTempStorageURL(DataDetails) Then
	
		Data = GetFromTempStorage(DataDetails);
	Else
		Data = DataDetails;
	EndIf;
	
	If CMSParameters.SignatureType = "CAdES-BES" Then
		AddInParameters.Insert("SignatureType", 0);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In add-in ""%3"", method ""%2"" has invalid parameter ""%1"".';"),
			"SignatureType", "CMSSign", "ExtraCryptoAPI");
	EndIf;
	
	If TypeOf(Data) = Type("String")
	 Or TypeOf(Data) = Type("BinaryData") Then
		
		AddInParameters.Insert("Data", Data);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In add-in ""%3"", method ""%2"" has invalid parameter ""%1"".';"),
			"Data", "CMSSign", "ExtraCryptoAPI");
	EndIf;
	
	If TypeOf(CMSParameters.DetachedAddIn) = Type("Boolean") Then
		AddInParameters.Insert("DetachedAddIn", CMSParameters.DetachedAddIn);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'In add-in ""%3"", method ""%2"" has invalid parameter ""%1"".';"),
			"DetachedAddIn", "CMSSign", "ExtraCryptoAPI");
	EndIf;
	
	//  0 - 
	//  
	// 
	AddInParameters.Insert("IncludeCertificatesInSignature", 17);
	If CMSParameters.IncludeCertificatesInSignature = "DontInclude"
		Or CMSParameters.IncludeCertificatesInSignature = CryptoCertificateIncludeMode.DontInclude Then
		
		AddInParameters.IncludeCertificatesInSignature = 0;
	ElsIf CMSParameters.IncludeCertificatesInSignature = "IncludeSubjectCertificate"
		Or CMSParameters.IncludeCertificatesInSignature = CryptoCertificateIncludeMode.IncludeSubjectCertificate Then
		
		AddInParameters.IncludeCertificatesInSignature = 1;
	EndIf;
	
	Return AddInParameters;
	
EndFunction

// Prepares a string to use as a file name.
Function PrepareStringForFileName(String, SpaceReplacement = Undefined) Export
	
	CharsReplacement = New Map;
	CharsReplacement.Insert("\", " ");
	CharsReplacement.Insert("/", " ");
	CharsReplacement.Insert("*", " ");
	CharsReplacement.Insert("<", " ");
	CharsReplacement.Insert(">", " ");
	CharsReplacement.Insert("|", " ");
	CharsReplacement.Insert(":", "");
	CharsReplacement.Insert("""", "");
	CharsReplacement.Insert("?", "");
	CharsReplacement.Insert(Chars.CR, "");
	CharsReplacement.Insert(Chars.LF, " ");
	CharsReplacement.Insert(Chars.Tab, " ");
	CharsReplacement.Insert(Chars.NBSp, " ");
	// 
	CharsReplacement.Insert(Char(171), "");
	CharsReplacement.Insert(Char(187), "");
	CharsReplacement.Insert(Char(8195), "");
	CharsReplacement.Insert(Char(8194), "");
	CharsReplacement.Insert(Char(8216), "");
	CharsReplacement.Insert(Char(8218), "");
	CharsReplacement.Insert(Char(8217), "");
	CharsReplacement.Insert(Char(8220), "");
	CharsReplacement.Insert(Char(8222), "");
	CharsReplacement.Insert(Char(8221), "");
	
	PreparedString = "";
	
	CharsCount = StrLen(String);
	
	For CharacterNumber = 1 To CharsCount Do
		Char = Mid(String, CharacterNumber, 1);
		If CharsReplacement[Char] <> Undefined Then
			Char = CharsReplacement[Char];
		EndIf;
		PreparedString = PreparedString + Char;
	EndDo;
	
	If SpaceReplacement <> Undefined Then
		PreparedString = StrReplace(SpaceReplacement, " ", SpaceReplacement);
	EndIf;
	
	Return TrimAll(PreparedString);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the CertificateOverdue, CertificatePresentation, and CertificateProperties functions.
//
// Parameters:
//   Certificate - CryptoCertificate
//
Function CertificateDates(Certificate, TimeAddition) Export
	
	CertificateDates = New Structure;
	CertificateDates.Insert("StartDate",    Certificate.ValidFrom    + TimeAddition);
	CertificateDates.Insert("EndDate", Certificate.ValidTo + TimeAddition);
	
	Return CertificateDates;
	
EndFunction

// For the CertificateProperties function.
Function GetPurpose(Certificate)
	
	If Not Certificate.Extensions.Property("EKU") Then
		Return "";
	EndIf;
	
	FixedPropertiesArray = Certificate.Extensions.EKU;
	
	Purpose = "";
	
	For IndexOf = 0 To FixedPropertiesArray.Count() - 1 Do
		Purpose = Purpose + FixedPropertiesArray.Get(IndexOf);
		Purpose = Purpose + Chars.LF;
	EndDo;
	
	Return PrepareRow(Purpose);
	
EndFunction

// Returns information records from certificate properties as String.
//
// Parameters:
//  CertificateProperties - See DigitalSignature.CertificateProperties
// 
// Returns:
//  String
//
Function DetailsCertificateString(CertificateProperties) Export
	
	InformationAboutCertificate = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Certificate: %1
			|Issued by: %2
			|Issued to: %3
			|Valid: from %4 to %5';"),
		String(CertificateProperties.SerialNumber),
		CertificateProperties.IssuedBy,
		CertificateProperties.IssuedTo,
		Format(CertificateProperties.StartDate,    "DLF=D"),
		Format(CertificateProperties.EndDate, "DLF=D"));
	
	Return InformationAboutCertificate;
	
EndFunction

// For the CertificateSubjectProperties and CertificateIssuerProperties functions.
Function PrepareRow(RowFromCertificate)
	
	Return TrimAll(CommonClientServer.ReplaceProhibitedXMLChars(RowFromCertificate));
	
EndFunction

// For the GeneralErrorDescription function.
Function SimplifiedErrorStructure(Error, ErrorTitle)
	
	SimplifiedStructure = New Structure;
	SimplifiedStructure.Insert("ErrorDescription",  "");
	SimplifiedStructure.Insert("ErrorTitle", "");
	SimplifiedStructure.Insert("LongDesc",        "");
	SimplifiedStructure.Insert("NotSupported", False);
	
	If TypeOf(Error) = Type("String") Then
		SimplifiedStructure.ErrorDescription = TrimAll(Error);
		Return SimplifiedStructure;
		
	ElsIf TypeOf(Error) <> Type("Structure") Then
		Return SimplifiedStructure;
	EndIf;
	
	If Error.Property("ErrorDescription") Then
		SimplifiedStructure.ErrorDescription = TrimAll(Error.ErrorDescription);
	EndIf;
	
	If Error.Property("ErrorTitle") Then
		If Error.Property("Errors") And Error.Errors.Count() = 1 Then
			If ErrorTitle <> Undefined Then
				SimplifiedStructure.ErrorTitle = Error.ErrorTitle;
			EndIf;
			ErrorProperties = Error.Errors[0]; // See NewErrorProperties
			LongDesc = "";
			If ValueIsFilled(ErrorProperties.Application) Then
				LongDesc = LongDesc + String(ErrorProperties.Application) + ":" + Chars.LF;
			EndIf;
			LongDesc = LongDesc + ErrorProperties.LongDesc;
			SimplifiedStructure.LongDesc = TrimAll(LongDesc);
			SimplifiedStructure.ErrorDescription = TrimAll(SimplifiedStructure.ErrorTitle + Chars.LF + LongDesc);
			If ErrorProperties.NotSupported Then
				SimplifiedStructure.NotSupported = True;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(ErrorTitle) Then
		SimplifiedStructure.ErrorTitle = ErrorTitle;
		SimplifiedStructure.LongDesc = SimplifiedStructure.ErrorDescription;
		SimplifiedStructure.ErrorDescription = ErrorTitle
			+ Chars.LF + SimplifiedStructure.ErrorDescription;
	EndIf;
	
	Return SimplifiedStructure;
	
EndFunction

// Returns the information about the computer being used.
//
// Returns:
//   String - 
//
Function DiagnosticsInformationOnComputer(ForTheClient = False) Export
	
	SysInfo = New SystemInfo;
	Viewer = ?(ForTheClient, SysInfo.UserAgentInformation, "");
	
	If Not IsBlankString(Viewer) Then
		Viewer = Chars.LF + NStr("en = 'Viewer:';") + " " + Viewer;
	EndIf;
	
	Return NStr("en = 'Operating system:';") + " " + SysInfo.OSVersion
		+ Chars.LF + NStr("en = 'Application version:';") + " " + SysInfo.AppVersion
		+ Chars.LF + NStr("en = 'Platform type:';") + " " + SysInfo.PlatformType
		+ Viewer;
	
EndFunction

Function DiagnosticInformationAboutTheProgram(Application, CryptoManager, ErrorDescription) Export
	
	If TypeOf(CryptoManager) = Type("CryptoManager") Then
		Result = NStr("en = 'OK';");
	Else
		ErrorText = "";
		If TypeOf(ErrorDescription) = Type("Structure")
		   And ErrorDescription.Property("Errors")
		   And TypeOf(ErrorDescription.Errors) = Type("Array")
		   And ErrorDescription.Errors.Count() > 0 Then
			
			Error = ErrorDescription.Errors[0]; // See NewErrorProperties
			ErrorText = Error.LongDesc;
		EndIf;
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error ""%1""';"), ErrorText);
	EndIf;
	
	Return Application.Presentation + " - " + Result + Chars.LF;
	
EndFunction

// For internal use only.
// 
// Parameters:
//  Cryptoprovider - Map -
//  ApplicationsByNamesWithType - See DigitalSignatureInternalCached.CommonSettings
//  CheckAtCleint - Boolean -
// 
// Returns:
//   See NewExtendedApplicationDetails
//
Function ExtendedApplicationDetails(Cryptoprovider, ApplicationsByNamesWithType, CheckAtCleint = True) Export
	
	ApplicationDetails = NewExtendedApplicationDetails();
	
	ApplicationType = Cryptoprovider.Get("type");
	If ApplicationType = 0 Then
		Return Undefined;
	EndIf;
	
	ApplicationDetails.ApplicationType = ApplicationType;
	ApplicationDetails.ApplicationName = Cryptoprovider.Get("name");
	
	Var_Key = ApplicationSearchKeyByNameWithType(ApplicationDetails.ApplicationName, ApplicationDetails.ApplicationType);
	ApplicationToSupply = ApplicationsByNamesWithType.Get(Var_Key);
	
	If ApplicationToSupply = Undefined Then
		Return Undefined;
	Else
		FillPropertyValues(ApplicationDetails, ApplicationToSupply);
	EndIf;
	
	If Not ValueIsFilled(ApplicationDetails.Presentation) Then
		ApplicationDetails.Presentation = Var_Key;
	EndIf;
	
	If CheckAtCleint Then
		ApplicationDetails.PathToAppAuto = Cryptoprovider.Get("path");
	Else
		ApplicationDetails.AppPathAtServerAuto = Cryptoprovider.Get("path");
	EndIf;
	
	ApplicationDetails.Version = Cryptoprovider.Get("version");
	ApplicationDetails.ILicenseInfo =  Cryptoprovider.Get("license");
	ApplicationDetails.AutoDetect = True;
	
	Return ApplicationDetails;
	
EndFunction

// For internal use only.
Procedure DoProcessAppsCheckResult(Cryptoproviders, Programs, IsConflictPossible, Context, HasAppsToCheck = False) Export
	
	InstalledPrograms = New Map;
	
	For Each CurCryptoProvider In Cryptoproviders Do
		
		Found1 = True; Presentation = Undefined;
		
		If ValueIsFilled(Context.SignAlgorithms) Then
			Found1 = False;
			For Each Algorithm In Context.SignAlgorithms Do
				Found1 = CryptoManagerSignAlgorithmSupported(CurCryptoProvider,
					?(Context.DataType = "Certificate","","CheckSignature"), Algorithm, Undefined, Context.IsServer, False);
				If Found1 Then
					Break;
				EndIf;
			EndDo;
		ElsIf ValueIsFilled(Context.AppsToCheck) Then
			Found1 = False;
			For Each Application In Context.AppsToCheck Do
				If Application.ApplicationName = CurCryptoProvider.ApplicationName
					And Application.ApplicationType = CurCryptoProvider.ApplicationType Then
					Presentation = Application.Presentation;
					Found1 = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If Not Found1 Then
			Continue;
		EndIf;
		
		If Context.ExtendedDescription Then
			ProgramVerificationResult = NewExtendedApplicationDetails();
		Else
			ProgramVerificationResult = ProgramVerificationResult();
		EndIf;
		
		FillPropertyValues(ProgramVerificationResult, CurCryptoProvider);
		ProgramVerificationResult.Presentation = 
			?(ValueIsFilled(Presentation), Presentation, CurCryptoProvider.Presentation);
		
		ProgramVerificationResult.Insert("Application", DigitalSignatureApplication(CurCryptoProvider));
		If Not IsBlankString(ProgramVerificationResult.Application) Then
			InstalledPrograms.Insert(ProgramVerificationResult.Application, True);
		EndIf;
		
		Programs.Add(ProgramVerificationResult);
		
	EndDo;
	
	If InstalledPrograms.Count() > 0 Then
		HasAppsToCheck = True;
		IsConflictPossible = InstalledPrograms.Count() > 1;
	EndIf;
	
EndProcedure

Function DigitalSignatureApplication(Cryptoprovider)
	
	
	Return "";
	
EndFunction

// For internal use only.
Function ProgramVerificationResult()
	
	Structure = New Structure;
	Structure.Insert("Presentation");
	Structure.Insert("Ref");
	Structure.Insert("ApplicationName");
	Structure.Insert("ApplicationType");
	Structure.Insert("Application");
	Structure.Insert("Version");
	Structure.Insert("ILicenseInfo");

	Return Structure;
	
EndFunction

// For internal use only.
Function PlacementOfTheCertificate(LocationType) Export
	
	Result = "Local_";
	GeneralPlacement = (LocationType - 1) % 4;
	
	If GeneralPlacement = 2 Then
		Result = "CloudSignature";
	ElsIf GeneralPlacement = 3 Then
		Result = "SignatureInTheServiceModel";
	EndIf;
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//   * Ref - 
//   * Presentation - String
//   * ApplicationName - String
//   * ApplicationType - Number
//   * SignAlgorithm - String
//   * HashAlgorithm - String
//   * EncryptAlgorithm - String
//   * Id - String
//   * ApplicationPath - String
//   * PathToAppAuto - String
//   * AppPathAtServerAuto - String
//   * Version - String -
//   * ILicenseInfo - Boolean -
//   * UsageMode - EnumRef.DigitalSignatureAppUsageModes
//   * AutoDetect - Boolean -
//
Function NewExtendedApplicationDetails() Export
	
	LongDesc = New Structure;
	LongDesc.Insert("Ref");
	LongDesc.Insert("Presentation");
	LongDesc.Insert("ApplicationName");
	LongDesc.Insert("ApplicationType");
	LongDesc.Insert("SignAlgorithm");
	LongDesc.Insert("HashAlgorithm");
	LongDesc.Insert("EncryptAlgorithm");
	LongDesc.Insert("Id");
	LongDesc.Insert("SignatureVerificationAlgorithms");
	
	LongDesc.Insert("PathToAppAuto", "");
	LongDesc.Insert("AppPathAtServerAuto", "");
	LongDesc.Insert("Version");
	LongDesc.Insert("ILicenseInfo", False);
	LongDesc.Insert("UsageMode", PredefinedValue(
		"Enum.DigitalSignatureAppUsageModes.Automatically"));
	LongDesc.Insert("AutoDetect", True);
	
	Return LongDesc;

EndFunction

#Region XMLScope

// Parameters:
//  XMLLine   - String
//  TagName - String
//
// Returns:
//   See XMLScopeProperties
//
Function XMLScope(XMLLine, TagName, NumberSingnature = 1) Export
	
	Result = XMLScopeProperties(TagName);
	
	// 
	// 
	IndicatesTheBeginningOfTheArea = "<" + TagName + " ";
	IndicatesTheEndOfTheArea = "</" + TagName + ">";
	
	Position = StrFind(XMLLine, IndicatesTheBeginningOfTheArea, , , NumberSingnature);
	If Position = 0 Then
		// 
		IndicatesTheBeginningOfTheArea = "<" + TagName;
		Position = StrFind(XMLLine, IndicatesTheBeginningOfTheArea, , , NumberSingnature);
		If Position = 0 Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 element is not found in the XML document.';"), TagName);
			Result.ErrorText = ErrorText;
		EndIf;
	EndIf;
	Result.StartPosition = Position;
	Text = Mid(XMLLine, Position);
	
	EntryNumber = 1;
	Position = StrFind(Text, IndicatesTheBeginningOfTheArea, , 2, EntryNumber);
	While Position <> 0 Do
		Position = StrFind(Text, IndicatesTheBeginningOfTheArea, , 2, EntryNumber);
		EntryNumber = EntryNumber + 1;
	EndDo;
	
	Position = StrFind(Text, IndicatesTheEndOfTheArea);
	If Position = 0 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 element end is not found in the XML document.';"), TagName);
		Result.ErrorText = ErrorText;
	EndIf;
	
	ThePositionOfTheNextArea = Position + StrLen(IndicatesTheEndOfTheArea);
	Result.Text = Mid(Text, 1, ThePositionOfTheNextArea - 1);
	Result.ThePositionOfTheNextArea = Result.StartPosition + ThePositionOfTheNextArea;
	
	Text = Mid(Text, 1, Position - 1);
	
	Position = StrFind(Text, ">");
	If Position = 0 Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The %1 element title end is not found in the XML document.';"), TagName);
		Result.ErrorText = ErrorText;
	EndIf;
	
	Result.Begin = Mid(Text, 1, Position);
	Result.End  = IndicatesTheEndOfTheArea;
	Result.Content = Mid(Text, Position + 1);
	
	Return Result;

EndFunction

// Parameters:
//  XMLScope - See XMLScopeProperties
//  Begin     - Undefined
//             - String
//
// Returns:
//  String
//
Function XMLAreaText(XMLScope, Begin = Undefined) Export
	
	PieceOfText = New Array;
	PieceOfText.Add(?(Begin = Undefined, XMLScope.Begin, Begin));
	PieceOfText.Add(XMLScope.Content);
	PieceOfText.Add(XMLScope.End);
	Result = StrConcat(PieceOfText);
	
	Return Result;
	
EndFunction

// Parameters:
//  XMLScope - See XMLScopeProperties
//  Algorithm   - See DigitalSignatureInternal.TheCanonizationAlgorithm
//  XMLText   - String
//
// Returns:
//  String
//
Function ExtendedBeginningOfTheXMLArea(XMLScope, Algorithm, XMLText) Export
	
	Result = New Structure("Begin, ErrorText", , "");
	
	If Algorithm.Kind = "c14n"
	 Or Algorithm.Kind = "smev" Then
		
		If XMLText = Undefined Then
			CurrentXMLScope = XMLScope;
		Else
			CurrentXMLScope = XMLScope(XMLText, XMLScope.TagName);
			If ValueIsFilled(CurrentXMLScope.ErrorText) Then
				Result.ErrorText = CurrentXMLScope.ErrorText;
				Return Result;
			EndIf;
			CurrentXMLScope.NamespacesUpToANode = XMLScope.NamespacesUpToANode;
		EndIf;
		Result.Begin = ExtendedStart(CurrentXMLScope);
	Else
		Result.Begin = XMLScope.Begin;
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  XMLScope - See XMLScopeProperties
//
// Returns:
//  String
//
Function ExtendedStart(XMLScope)
	
	If Not ValueIsFilled(XMLScope.NamespacesUpToANode) Then
		Return XMLScope.Begin;
	EndIf;
	
	Additional = New Array;
	For Each TheNameOfTheSpace In XMLScope.NamespacesUpToANode Do
		Position = StrFind(TheNameOfTheSpace, "=""");
		DeclaringASpace = Left(TheNameOfTheSpace, Position + 1);
		If StrFind(XMLScope.Begin, DeclaringASpace) > 0 Then
			Continue;
		EndIf;
		Additional.Add(TheNameOfTheSpace);
	EndDo;
	
	Result = Left(XMLScope.Begin, StrLen(XMLScope.TagName) + 1)
		+ " " + StrConcat(Additional, " ")
		+ " " + Mid(XMLScope.Begin, StrLen(XMLScope.TagName) + 2);
	
	Return Result;
	
EndFunction

// Parameters:
//  TagName - String
//
// Returns:
//  Structure:
//   * TagName - String
//   * ErrorText - String
//   * StartPosition - Number
//   * ThePositionOfTheNextArea - Number
//   * Begin      - String
//   * Content - String
//   * End - String
//   * NamespacesUpToANode - Array of String
//                            - Undefined
//
Function XMLScopeProperties(TagName)
	
	Result = New Structure;
	Result.Insert("TagName", TagName);
	Result.Insert("ErrorText", "");
	Result.Insert("StartPosition", 0);
	Result.Insert("ThePositionOfTheNextArea", 0);
	Result.Insert("Begin", "");
	Result.Insert("Content", "");
	Result.Insert("End", "");
	Result.Insert("Text", "");
	Result.Insert("NamespacesUpToANode");
	
	Return Result;
	
EndFunction

#EndRegion

#Region CertificateContents

Function CertificateAuthorityKeyID(Data) Export
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.CertificateAuthorityKeyID");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
	
	//	TBSCertificate  ::=  SEQUENCE  {
	//		version			[0] EXPLICIT Version DEFAULT v1,
	//		...
	//		extensions		[3] EXPLICIT Extensions OPTIONAL
	//							 -- If present, version MUST be v3
	
	// SEQUENCE (Certificate).
	SkipBlockStart(DataAnalysis, 0, 16);
		// SEQUENCE (tbsCertificate).
		SkipBlockStart(DataAnalysis, 0, 16);
			// [0] EXPLICIT (version).
			SkipBlockStart(DataAnalysis, 2, 0);
				// INTEGER {v1(0), v2(1), v3(2)}. 
				SkipBlockStart(DataAnalysis, 0, 2); 
				Integer = ToReadTheWholeStream(DataAnalysis);
				If Integer <> 2 Then
					Return Undefined;
				EndIf;
				SkipTheParentBlock(DataAnalysis);
			// version
			SkipTheParentBlock(DataAnalysis);
			// INTEGER  (serialNumber         CertificateSerialNumber).
			SkipBlock(DataAnalysis, 0, 2);
			// SEQUENCE (signature            AlgorithmIdentifier).
			SkipBlock(DataAnalysis, 0, 16);
			// SEQUENCE (issuer               Name).
			SkipBlock(DataAnalysis, 0, 16);
			// SEQUENCE (validity             Validity).
			SkipBlock(DataAnalysis, 0, 16);
			// SEQUENCE (subject              Name).
			SkipBlock(DataAnalysis, 0, 16);
			// SEQUENCE (subjectPublicKeyInfo SubjectPublicKeyInfo).
			SkipBlock(DataAnalysis, 0, 16);
			// [1] IMPLICIT UniqueIdentifier OPTIONAL (issuerUniqueID).
			SkipBlock(DataAnalysis, 2, 1, False);
			// [2] IMPLICIT UniqueIdentifier OPTIONAL (subjectUniqueID).
			SkipBlock(DataAnalysis, 2, 2, False);
			// [3] EXPLICIT SEQUENCE SIZE (1..MAX) OF Extension (extensions). 
			SkipBlockStart(DataAnalysis, 2, 3);
			If DataAnalysis.HasError Then
				Return Undefined;
			EndIf; 
				// SEQUENCE OF
				SkipBlockStart(DataAnalysis, 0, 16);
				OffsetOfTheFollowing = DataAnalysis.Parents[0].OffsetOfTheFollowing;
				While DataAnalysis.Offset < OffsetOfTheFollowing Do
					// SEQUENCE (extension).
					SkipBlockStart(DataAnalysis, 0, 16);
					If DataAnalysis.HasError Then
						Return Undefined;
					EndIf; 
						// OBJECT IDENTIFIER
						SkipBlockStart(DataAnalysis, 0, 6);
							
							DataSize = DataAnalysis.Parents[0].DataSize;
							If DataSize = 0 Then
								WhenADataStructureErrorOccurs(DataAnalysis);
								Return Undefined;
							EndIf;
							
							If DataSize = 3 Then
								Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
								BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
								
								If BufferString = "551D23" Then //2.5.29.35 authorityKeyIdentifier
									SkipTheParentBlock(DataAnalysis); // OBJECT IDENTIFIER
					
									// OCTET STRING
									SkipBlockStart(DataAnalysis, 0, 4);
									
									// AuthorityKeyIdentifier ::= SEQUENCE {
									//      keyIdentifier             [0] KeyIdentifier           OPTIONAL,
									//
									//   KeyIdentifier ::= OCTET STRING									
									
									// SEQUENCE
									SkipBlockStart(DataAnalysis, 0, 16);
									// [0]
									SkipBlockStart(DataAnalysis, 2, 0);
									
									If Not DataAnalysis.HasError Then
										DataSize = DataAnalysis.Parents[0].DataSize;
										Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
										Return GetHexStringFromBinaryDataBuffer(Buffer);
									EndIf;
									
									Return Undefined;
								EndIf;
							EndIf;
						SkipTheParentBlock(DataAnalysis); // OBJECT IDENTIFIER
					SkipTheParentBlock(DataAnalysis); // SEQUENCE
				EndDo;

	Return Undefined;

EndFunction

Function GeneratedSignAlgorithm(SignatureData, IncludingOID = False, OIDOnly = False) Export
	
	Return SignAlgorithm(SignatureData, False, IncludingOID, OIDOnly);
	
EndFunction

Function CertificateSignAlgorithm(CertificateData, IncludingOID = False, OIDOnly = False) Export
	
	Return SignAlgorithm(CertificateData, True, IncludingOID, OIDOnly);
	
EndFunction

Function SignAlgorithm(Data, IsCertificateData = Undefined, IncludingOID = False, OIDOnly = False)
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.SignAlgorithm");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
	
	If IsCertificateData Then
		// SEQUENCE (Certificate).
		SkipBlockStart(DataAnalysis, 0, 16);
			// SEQUENCE (tbsCertificate).
			SkipBlockStart(DataAnalysis, 0, 16);
				//          (version              [0]  EXPLICIT Version DEFAULT v1).
				SkipBlock(DataAnalysis, 2, 0);
				// INTEGER  (serialNumber         CertificateSerialNumber).
				SkipBlock(DataAnalysis, 0, 2);
				// SEQUENCE (signature            AlgorithmIdentifier).
				SkipBlock(DataAnalysis, 0, 16);
				// SEQUENCE (issuer               Name).
				SkipBlock(DataAnalysis, 0, 16);
				// SEQUENCE (validity             Validity).
				SkipBlock(DataAnalysis, 0, 16);
				// SEQUENCE (subject              Name).
				SkipBlock(DataAnalysis, 0, 16);
				// SEQUENCE (subjectPublicKeyInfo SubjectPublicKeyInfo).
				SkipBlockStart(DataAnalysis, 0, 16);
					// SEQUENCE (algorithm  AlgorithmIdentifier).
					SkipBlockStart(DataAnalysis, 0, 16);
						// OBJECT IDENTIFIER (algorithm).
						SkipBlockStart(DataAnalysis, 0, 6);
	Else
		// SEQUENCE (PKCS #7 ContentInfo).
		SkipBlockStart(DataAnalysis, 0, 16);
			// OBJECT IDENTIFIER (contentType).
			SkipBlockStart(DataAnalysis, 0, 6);
				// 1.2.840.113549.1.7.2 signedData (PKCS #7).
				ToCheckTheDataBlock(DataAnalysis, "2A864886F70D010702");
				SkipTheParentBlock(DataAnalysis);
			// [0]CS             (content [0] EXPLICIT ANY DEFINED BY contentType OPTIONAL).
			SkipBlockStart(DataAnalysis, 2, 0);
				// SEQUENCE (content SignedData).
				SkipBlockStart(DataAnalysis, 0, 16);
					// INTEGER  (version          Version).
					SkipBlock(DataAnalysis, 0, 2);
					// SET      (digestAlgorithms DigestAlgorithmIdentifiers).
					SkipBlock(DataAnalysis, 0, 17);
					// SEQUENCE (contentInfo      ContentInfo).
					SkipBlock(DataAnalysis, 0, 16);
					// [0]CS    (certificates     [0] IMPLICIT ExtendedCertificatesAndCertificates OPTIONAL).
					SkipBlock(DataAnalysis, 2, 0, False);
					// [1]CS    (crls             [1] IMPLICIT CertificateRevocationLists OPTIONAL).
					SkipBlock(DataAnalysis, 2, 1, False);
					// SET      (signerInfos      SET OF SignerInfo).
					SkipBlockStart(DataAnalysis, 0, 17);
						// SEQUENCE (signerInfo SignerInfo).
						SkipBlockStart(DataAnalysis, 0, 16);
							// INTEGER  (version                   Version).
							SkipBlock(DataAnalysis, 0, 2);
							// SEQUENCE (issuerAndSerialNumber     IssuerAndSerialNumber).
							SkipBlock(DataAnalysis, 0, 16);
							// SEQUENCE (digestAlgorithm           DigestAlgorithmIdentifier).
							SkipBlock(DataAnalysis, 0, 16);
							// [0]CS    (authenticatedAttributes   [0] IMPLICIT Attributes OPTIONAL).
							SkipBlock(DataAnalysis, 2, 0, False);
							// SEQUENCE (digestEncryptionAlgorithm AlgorithmIdentifier).
							SkipBlockStart(DataAnalysis, 0, 16);
								// OBJECT IDENTIFIER (algorithm).
								SkipBlockStart(DataAnalysis, 0, 6);
	EndIf;
	
	SignatureAlgorithmOID = ReadOID(DataAnalysis);
	If DataAnalysis.HasError Then
		Return "";
	EndIf;
	
	If OIDOnly Then
		Return SignatureAlgorithmOID;
	EndIf;
	
	AlgorithmsIDs = IDsOfSignatureAlgorithms(IsCertificateData);
	Algorithm = AlgorithmByOID(SignatureAlgorithmOID, AlgorithmsIDs, IncludingOID);
	
	Return Algorithm;
	
EndFunction

Function HashAlgorithm(Data, IncludingOID = False) Export
	
	BinaryData = BinaryDataFromTheData(Data,
		"DigitalSignatureInternalClientServer.HashAlgorithm");
	
	DataAnalysis = NewDataAnalysis(BinaryData);
	
	// SEQUENCE (PKCS #7 ContentInfo).
	SkipBlockStart(DataAnalysis, 0, 16);
		// OBJECT IDENTIFIER (contentType).
		SkipBlockStart(DataAnalysis, 0, 6);
			// 1.2.840.113549.1.7.2 signedData (PKCS #7).
			ToCheckTheDataBlock(DataAnalysis, "2A864886F70D010702");
			SkipTheParentBlock(DataAnalysis);
		// [0]CS             (content [0] EXPLICIT ANY DEFINED BY contentType OPTIONAL).
		SkipBlockStart(DataAnalysis, 2, 0);
			// SEQUENCE (content SignedData).
			SkipBlockStart(DataAnalysis, 0, 16);
				// INTEGER  (version          Version).
				SkipBlock(DataAnalysis, 0, 2);
				// SET      (digestAlgorithms DigestAlgorithmIdentifiers).
				SkipBlock(DataAnalysis, 0, 17);
				// SEQUENCE (contentInfo      ContentInfo).
				SkipBlock(DataAnalysis, 0, 16);
				// [0]CS    (certificates     [0] IMPLICIT ExtendedCertificatesAndCertificates OPTIONAL).
				SkipBlock(DataAnalysis, 2, 0, False);
				// [1]CS    (crls             [1] IMPLICIT CertificateRevocationLists OPTIONAL).
				SkipBlock(DataAnalysis, 2, 1, False);
				// SET      (signerInfos      SET OF SignerInfo).
				SkipBlockStart(DataAnalysis, 0, 17);
					// SEQUENCE (signerInfo SignerInfo).
					SkipBlockStart(DataAnalysis, 0, 16);
						// INTEGER  (version                   Version).
						SkipBlock(DataAnalysis, 0, 2);
						// SEQUENCE (issuerAndSerialNumber     IssuerAndSerialNumber).
						SkipBlock(DataAnalysis, 0, 16);
						// SEQUENCE (digestAlgorithm           DigestAlgorithmIdentifier).
						SkipBlockStart(DataAnalysis, 0, 16);
							// OBJECT IDENTIFIER (algorithm).
							SkipBlockStart(DataAnalysis, 0, 6);
	
	HashingAlgorithmOID = ReadOID(DataAnalysis);
	If DataAnalysis.HasError Then
		Return "";
	EndIf;
	
	AlgorithmsIDs = TheIdentifiersOfTheHashAlgorithms();
	Algorithm = AlgorithmByOID(HashingAlgorithmOID, AlgorithmsIDs, IncludingOID);
	
	Return Algorithm;
	
EndFunction

Function BinaryDataFromTheData(Data, FunctionName) Export
	
	ExpectedTypes = New Array;
	ExpectedTypes.Add(Type("BinaryData"));
	ExpectedTypes.Add(Type("String"));
	CommonClientServer.CheckParameter(
		FunctionName,
		"Data", Data, ExpectedTypes);
	
	If TypeOf(Data) = Type("String") Then
		If IsTempStorageURL(Data) Then
			BinaryData = GetFromTempStorage(Data);
		Else
			CommonClientServer.Validate(False,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Incorrect address of a temporary storage in the Data parameter:
					           |%1';") + Chars.LF, Data),
				FunctionName);
		EndIf;
		If TypeOf(BinaryData) <> Type("BinaryData") Then
			CommonClientServer.Validate(False,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invalid type of the ""%1"" value
					           |at the temporary storage address specified in the Data parameter';") + Chars.LF,
					String(TypeOf(BinaryData))),
				FunctionName);
		EndIf;
	Else
		BinaryData = Data;
	EndIf;
	
	Return BinaryData;
	
EndFunction

// Returns:
//  Structure:
//   * HasError - Boolean
//   * ThisIsAnASN1EncodingError - Boolean
//   * ThisIsADataStructureError - Boolean
//   * Offset - Number
//   * Parents - Array of Structure
//   * Buffer - BinaryDataBuffer
// 
Function NewDataAnalysis(BinaryData) Export
	
	DataAnalysis = New Structure;
	DataAnalysis.Insert("HasError", False);
	DataAnalysis.Insert("ThisIsAnASN1EncodingError", False); // 
	DataAnalysis.Insert("ThisIsADataStructureError", False); // 
	DataAnalysis.Insert("Offset", 0);
	DataAnalysis.Insert("Parents", New Array);
	DataAnalysis.Insert("Buffer", GetBinaryDataBufferFromBinaryData(BinaryData));
	
	Return DataAnalysis;
	
EndFunction

Function AlgorithmByOID(AlgorithmOID, AlgorithmsIDs, IncludingOID)
	
	AlgorithmName = AlgorithmsIDs.Get(AlgorithmOID);
	
	If AlgorithmName = Undefined Then
		If IncludingOID Then
			Return NStr("en = 'Unknown';") + " (OID " + AlgorithmOID + ")";
		EndIf;
		Return "";
	ElsIf IncludingOID Then
		Return StrSplit(AlgorithmName, ",", False)[0] + " (OID " + AlgorithmOID + ")";
	Else
		Return AlgorithmName;
	EndIf;
	
EndFunction

Function BlockRead(DataAnalysis, DataClass = Undefined, DataType = Undefined, RequiredBlock = False)
	
	If DataAnalysis.Parents.Count() > 0
		And DataAnalysis.Offset >= DataAnalysis.Parents[0].OffsetOfTheFollowing Then
		Return Undefined;
	EndIf;
	
	Offset = DataAnalysis.Offset;
	
	SkipTheBeginningOfABlockOrBlock(DataAnalysis, True, DataClass, DataType, RequiredBlock);
	If DataAnalysis.Offset = Offset Then
		Return Undefined;
	EndIf;
	
	BlockSize = DataAnalysis.Offset - Offset + DataAnalysis.Parents[0].DataSize;
	
	Buffer = DataAnalysis.Buffer.Read(Offset, BlockSize); // BinaryDataBuffer
	BlockRead = GetBinaryDataFromBinaryDataBuffer(Buffer);
	SkipTheParentBlock(DataAnalysis);
	
	Return BlockRead;
	
EndFunction

Function SkipBlockStart(DataAnalysis, DataClass = Undefined, DataType = Undefined, RequiredBlock = True) Export
	
	Offset = DataAnalysis.Offset;
	SkipTheBeginningOfABlockOrBlock(DataAnalysis, True, DataClass, DataType, RequiredBlock);
	
	Return DataAnalysis.Offset <> Offset;
	
EndFunction

Procedure SkipBlock(DataAnalysis, DataClass = Undefined, DataType = Undefined, RequiredBlock = True) Export
	
	If DataAnalysis.HasError Then
		Return;
	EndIf;
	
	If DataAnalysis.Parents.Count() = 0
	 Or Not DataAnalysis.Parents[0].HasAttachments Then
		
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	
	SkipTheBeginningOfABlockOrBlock(DataAnalysis, False, DataClass, DataType, RequiredBlock)
	
EndProcedure

Procedure SkipTheParentBlock(DataAnalysis) Export
	
	If DataAnalysis.HasError Then
		Return;
	EndIf;
	
	If DataAnalysis.Parents.Count() < 2
	 Or Not DataAnalysis.Parents[1].HasAttachments Then
		
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	
	If DataAnalysis.Parents[0].DataSize > 0 Then
		BytesLeft = DataAnalysis.Parents[0].OffsetOfTheFollowing - DataAnalysis.Offset;
		
		If BytesLeft > 0 Then
			ReadByte(DataAnalysis, BytesLeft);
			If DataAnalysis.HasError Then
				Return;
			EndIf;
		ElsIf BytesLeft < 0 Then
			IfTheEncodingErrorIsASN1(DataAnalysis);
			Return;
		EndIf;
	Else
		While True Do
			If EndOfABlockOfIndeterminateLength(DataAnalysis) Then
				If DataAnalysis.HasError Then
					Return;
				EndIf;
				DataAnalysis.Offset = DataAnalysis.Offset + 2;
				Break;
			EndIf;
			SkipBlock(DataAnalysis);
		EndDo;
	EndIf;
	
	DataAnalysis.Parents.Delete(0);
	
EndProcedure

Procedure ToCheckTheDataBlock(DataAnalysis, DataString1)
	
	If DataAnalysis.HasError Then
		Return;
	EndIf;
	
	If DataAnalysis.Parents.Count() = 0 Then
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	
	DataSize = DataAnalysis.Parents[0].DataSize;
	If DataSize = 0 Then
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	Buffer = DataAnalysis.Buffer.Read(DataAnalysis.Offset, DataSize); // BinaryDataBuffer
	
	If Buffer.Size <> DataSize Then
		IfTheEncodingErrorIsASN1(DataAnalysis);
		Return;
	EndIf;
	DataAnalysis.Offset = DataAnalysis.Offset + DataSize;
	
	BufferString = GetHexStringFromBinaryDataBuffer(Buffer);
	If DataString1 <> BufferString Then
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	
EndProcedure

Function ReadOID(DataAnalysis)
	
	If DataAnalysis.HasError Then
		Return Undefined;
	EndIf;
	
	If DataAnalysis.Parents.Count() = 0 Then
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return Undefined;
	EndIf;
	
	Integers = New Array;
	DataSize = DataAnalysis.Parents[0].DataSize;
	If DataSize = 0 Then
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return Undefined;
	EndIf;
	OffsetBoundary = DataAnalysis.Offset + DataSize;
	
	While DataAnalysis.Offset < OffsetBoundary Do
		Integer1 = ToReadTheWholeStream(DataAnalysis);
		If DataAnalysis.HasError Then
			Return Undefined;
		EndIf;
		Integers.Add(Integer1);
	EndDo;
	
	If DataAnalysis.Offset <> OffsetBoundary
	 Or Integers.Count() = 0 Then
		
		IfTheEncodingErrorIsASN1(DataAnalysis);
		Return Undefined;
	EndIf;
	
	SidNumber2 = Integers[0];
	If SidNumber2 < 40 Then
		SID1 = 0;
	ElsIf SidNumber2 < 80 Then
		SID1 = 1;
	Else
		SID1 = 2;
	EndIf;
	Integers[0] = SidNumber2 - SID1*40;
	Integers.Insert(0, SID1);
	
	StringsOfNumbers = New Array;
	For Each Integer1 In Integers Do
		StringsOfNumbers.Add(Format(Integer1, "NZ=0; NG="));
	EndDo;
	
	Return StrConcat(StringsOfNumbers, ".");
	
EndFunction

Procedure SkipTheBeginningOfABlockOrBlock(DataAnalysis, StartOfTheBlock,
			TheRequiredDataClass, RequiredDataType, RequiredBlock)
	
	If DataAnalysis.Parents.Count() > 0
	   And DataAnalysis.Offset >= DataAnalysis.Parents[0].OffsetOfTheFollowing Then
	
		WhenADataStructureErrorOccurs(DataAnalysis);
		Return;
	EndIf;
	
	TheDisplacementOfTheBlock = DataAnalysis.Offset;
	Byte = ReadByte(DataAnalysis);
	If DataAnalysis.HasError Then
		Return;
	EndIf;
	
	DataClass = BitwiseShiftRight(Byte, 6);
	DataType = Byte - DataClass * 64;
	HasAttachments = False;
	
	If DataType > 31 Then
		HasAttachments = True;
		DataType = DataType - 32;
	EndIf;
	
	If DataType > 30 Then
		DataType = ToReadTheWholeStream(DataAnalysis);
		If DataAnalysis.HasError Then
			Return;
		EndIf;
	EndIf;
	
	If TheRequiredDataClass <> Undefined
	   And TheRequiredDataClass <> DataClass
	 Or RequiredDataType <> Undefined
	   And RequiredDataType <> DataType Then
	
		If RequiredBlock Then
			WhenADataStructureErrorOccurs(DataAnalysis);
		Else
			DataAnalysis.Offset = TheDisplacementOfTheBlock;
		EndIf;
		Return;
	EndIf;
	
	DataSize = ToReadTheSizeData(DataAnalysis);
	If DataAnalysis.HasError Then
		Return;
	EndIf;
	
	If StartOfTheBlock Or HasAttachments And DataSize = 0 Then
		If DataSize = 0 Then
			If DataAnalysis.Parents.Count() = 0 Then
				If Not EndOfABlockOfIndeterminateLength(DataAnalysis, True) Then
					IfTheEncodingErrorIsASN1(DataAnalysis);
					Return;
				EndIf;
				OffsetOfTheFollowing = DataAnalysis.Buffer.Size - 2;
				DataSize = OffsetOfTheFollowing - DataAnalysis.Offset;
			Else
				// Для блока неопределенной длины СмещениеСледующего - 
				OffsetOfTheFollowing = DataAnalysis.Parents[0].OffsetOfTheFollowing;
			EndIf;
		Else
			OffsetOfTheFollowing = DataAnalysis.Offset + DataSize;
			If DataAnalysis.Parents.Count() = 0
			   And OffsetOfTheFollowing > DataAnalysis.Buffer.Size Then
				
				IfTheEncodingErrorIsASN1(DataAnalysis);
				Return;
			EndIf;
		EndIf;
		CurrentBlock = New Structure("HasAttachments, OffsetOfTheFollowing, DataSize",
			HasAttachments, OffsetOfTheFollowing, DataSize);
		DataAnalysis.Parents.Insert(0, CurrentBlock);
		If Not StartOfTheBlock Then
			SkipTheParentBlock(DataAnalysis);
		EndIf;
	Else
		If DataSize = 0 Then
			ReadTheEndOfABlockWithoutAttachmentsOfIndeterminateLength(DataAnalysis);
		Else
			ReadByte(DataAnalysis, DataSize);
		EndIf;
		If DataAnalysis.HasError Then
			Return;
		EndIf;
	EndIf;
	
EndProcedure

Function EndOfABlockOfIndeterminateLength(DataAnalysis, CommonBlock = False)
	
	Buffer = DataAnalysis.Buffer;
	
	If CommonBlock Then
		Offset = Buffer.Size - 2;
		If Offset < 2 Then
			IfTheEncodingErrorIsASN1(DataAnalysis);
			Return False;
		EndIf;
	Else
		Offset = DataAnalysis.Offset;
		If Offset + 2 > DataAnalysis.Parents[0].OffsetOfTheFollowing Then
			IfTheEncodingErrorIsASN1(DataAnalysis);
			Return False;
		EndIf;
	EndIf;
	
	Return Buffer[Offset] = 0 And Buffer[Offset + 1] = 0;
	
EndFunction

Procedure ReadTheEndOfABlockWithoutAttachmentsOfIndeterminateLength(DataAnalysis)
	
	ThePreviousByte = -1;
	Byte = -1;
	
	While True Do
		ThePreviousByte = Byte;
		Byte = ReadByte(DataAnalysis);
		If DataAnalysis.HasError Then
			Return;
		EndIf;
		If Byte = 0 And ThePreviousByte = 0 Then
			Break;
		EndIf;
	EndDo;
	
EndProcedure

Function ToReadTheWholeStream(DataAnalysis) Export
	
	Integer = 0;
	For Counter = 1 To 9 Do
		Byte = ReadByte(DataAnalysis);
		If DataAnalysis.HasError Then
			Return Undefined;
		EndIf;
		If Byte < 128 Then
			Integer = Integer * 128 + Byte;
			Break;
		Else
			Integer = Integer * 128 + (Byte - 128);
		EndIf;
	EndDo;
	
	If Counter > 8 Then
		IfTheEncodingErrorIsASN1(DataAnalysis);
		Return Undefined;
	EndIf;
	
	Return Integer;
	
EndFunction

Function ToReadTheSizeData(DataAnalysis)
	
	Byte = ReadByte(DataAnalysis);
	If DataAnalysis.HasError Then
		Return Undefined;
	EndIf;
	
	If Byte < 128 Then
		Return Byte;
	EndIf;
	
	NumberOfBytes = Byte - 128;
	If NumberOfBytes = 0 Or NumberOfBytes > 8 Then
		If Byte = 128 Then
			Return 0; // Block of undefined length.
		EndIf;
		IfTheEncodingErrorIsASN1(DataAnalysis);
		Return Undefined;
	EndIf;
	
	Integer = 0;
	For Counter = 1 To NumberOfBytes Do
		Byte = ReadByte(DataAnalysis);
		If DataAnalysis.HasError Then
			Return Undefined;
		EndIf;
		Integer = Integer * 256 + Byte;
	EndDo;
	
	Return Integer;
	
EndFunction

Function ReadByte(DataAnalysis, TimesCount = 1)
	
	If DataAnalysis.HasError Then
		Return Undefined;
	EndIf;
	
	If DataAnalysis.Offset + TimesCount <= DataAnalysis.Buffer.Size Then
		Byte = DataAnalysis.Buffer.Get(DataAnalysis.Offset + TimesCount - 1);
		DataAnalysis.Offset = DataAnalysis.Offset + TimesCount;
	Else
		Byte = Undefined;
		IfTheEncodingErrorIsASN1(DataAnalysis);
	EndIf;
	
	Return Byte;
	
EndFunction

Procedure IfTheEncodingErrorIsASN1(DataAnalysis)
	
	DataAnalysis.ThisIsAnASN1EncodingError = True;
	DataAnalysis.HasError = True;
	
EndProcedure

Procedure WhenADataStructureErrorOccurs(DataAnalysis) Export
	
	DataAnalysis.ThisIsADataStructureError = True;
	DataAnalysis.HasError = True;
	
EndProcedure

Function IDsOfSignatureAlgorithms(PublicKeyAlgorithmsOnly)
	
	AlgorithmsIDs = New Map;
	
	Sets = SetsOfAlgorithmsForCreatingASignature();
	For Each Set In Sets Do
		AlgorithmsIDs.Insert(Set.IDOfThePublicKeyAlgorithm,
			StrConcat(Set.SignatureAlgorithmNames, ", "));
		
		If PublicKeyAlgorithmsOnly Then
			Continue;
		EndIf;
		
		AlgorithmsIDs.Insert(Set.IDOfTheSignatureAlgorithm,
			StrConcat(Set.SignatureAlgorithmNames, ", "));
		
		If ValueIsFilled(Set.IDOfTheExchangeAlgorithm) Then
			AlgorithmsIDs.Insert(Set.IDOfTheExchangeAlgorithm,
				StrConcat(Set.SignatureAlgorithmNames, ", "));
		EndIf;
	EndDo;
	
	Return AlgorithmsIDs;
	
EndFunction

Function TheIdentifiersOfTheHashAlgorithms()
	
	AlgorithmsIDs = New Map;
	
	Sets = SetsOfAlgorithmsForCreatingASignature();
	For Each Set In Sets Do
		AlgorithmsIDs.Insert(Set.IdOfTheHashingAlgorithm,
			StrConcat(Set.HashAlgorithmNames, ", "));
	EndDo;
	
	Return AlgorithmsIDs;
	
EndFunction

// Returns:
//  Array of See ANewSetOfAlgorithmsForCreatingASignature
//
Function SetsOfAlgorithmsForCreatingASignature() Export
	
	Sets = New Array;
	
	// GOST 94
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.643.2.2.20";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.643.2.2.4";
	Properties.SignatureAlgorithmNames                = NamesOfSignatureAlgorithmsGOST_34_10_94();
	Properties.IdOfTheHashingAlgorithm    = "1.2.643.2.2.9";
	Properties.HashAlgorithmNames            = NamesOfHashingAlgorithmsGOST_34_11_94();
	Properties.NameOfTheXMLSignatureAlgorithm     = "http://www.w3.org/2001/04/xmldsig-more#gostr341094-gostr3411";
	Properties.NameOfTheXMLHashingAlgorithm = "http://www.w3.org/2001/04/xmldsig-more#gostr3411";
	Sets.Add(Properties);
	
	// GOST2001
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.643.2.2.19";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.643.2.2.3";
	Properties.SignatureAlgorithmNames                = NamesOfSignatureAlgorithmsGOST_34_10_2001();
	Properties.IdOfTheHashingAlgorithm    = "1.2.643.2.2.9";
	Properties.HashAlgorithmNames            = NamesOfHashingAlgorithmsGOST_34_11_94();
	Properties.NameOfTheXMLSignatureAlgorithm     = "http://www.w3.org/2001/04/xmldsig-more#gostr34102001-gostr3411";
	Properties.NameOfTheXMLHashingAlgorithm = "http://www.w3.org/2001/04/xmldsig-more#gostr3411";
	Sets.Add(Properties);
	
	// 
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.643.7.1.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.643.7.1.1.3.2";
	Properties.SignatureAlgorithmNames                = NamesOfSignatureAlgorithmsGOST_34_10_2012_256();
	Properties.IDOfTheExchangeAlgorithm         = "1.2.643.7.1.1.6.1";
	Properties.IdOfTheHashingAlgorithm    = "1.2.643.7.1.1.2.2";
	Properties.HashAlgorithmNames            = NamesOfHashingAlgorithmsGOST_34_11_2012_256();
	Properties.NameOfTheXMLSignatureAlgorithm     = "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34102012-gostr34112012-256";
	Properties.NameOfTheXMLHashingAlgorithm = "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34112012-256";
	Sets.Add(Properties);
	
	// 
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.643.7.1.1.1.2";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.643.7.1.1.3.3";
	Properties.SignatureAlgorithmNames                = NamesOfSignatureAlgorithmsGOST_34_10_2012_512();
	Properties.IDOfTheExchangeAlgorithm         = "1.2.643.7.1.1.6.2";
	Properties.IdOfTheHashingAlgorithm    = "1.2.643.7.1.1.2.3";
	Properties.HashAlgorithmNames            = NamesOfHashingAlgorithmsGOST_34_11_2012_512();
	Properties.NameOfTheXMLSignatureAlgorithm     = "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34102012-gostr34112012-512";
	Properties.NameOfTheXMLHashingAlgorithm = "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34112012-512";
	Sets.Add(Properties);
	
	// md2WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.2";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "1.2.840.113549.2.2";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("MD2");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// md4withRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.3";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "1.2.840.113549.2.4";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("MD4");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// md5WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.4";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "1.2.840.113549.2.5";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("MD5");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// sha1WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.5";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "1.3.14.3.2.26";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("SHA-1");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// sha256WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.11";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "2.16.840.1.101.3.4.2.1";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("SHA-256");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// sha384WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.12";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "2.16.840.1.101.3.4.2.2";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("SHA-384");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	// sha512WithRSAEncryption
	Properties = ANewSetOfAlgorithmsForCreatingASignature();
	Properties.IDOfThePublicKeyAlgorithm = "1.2.840.113549.1.1.1";
	Properties.IDOfTheSignatureAlgorithm        = "1.2.840.113549.1.1.13";
	Properties.SignatureAlgorithmNames                = CommonClientServer.ValueInArray("RSA_SIGN");
	Properties.IdOfTheHashingAlgorithm    = "2.16.840.1.101.3.4.2.3";
	Properties.HashAlgorithmNames            = CommonClientServer.ValueInArray("SHA-512");
	Properties.NameOfTheXMLSignatureAlgorithm     = "";
	Properties.NameOfTheXMLHashingAlgorithm = "";
	Sets.Add(Properties);
	
	Return Sets;
	
EndFunction

// Returns:
//  Structure:
//   * IDOfThePublicKeyAlgorithm - String
//   * IDOfTheSignatureAlgorithm - String
//   * SignatureAlgorithmNames - Array of String
//   * IdOfTheHashingAlgorithm - String
//   * HashAlgorithmNames - Array of String
//   * NameOfTheXMLSignatureAlgorithm - String
//   * NameOfTheXMLHashingAlgorithm - String
//    
Function ANewSetOfAlgorithmsForCreatingASignature()
	
	Properties = New Structure;
	Properties.Insert("IDOfThePublicKeyAlgorithm", "");
	Properties.Insert("IDOfTheSignatureAlgorithm", "");
	Properties.Insert("SignatureAlgorithmNames", New Array);
	Properties.Insert("IDOfTheExchangeAlgorithm", "");
	Properties.Insert("IdOfTheHashingAlgorithm", "");
	Properties.Insert("HashAlgorithmNames", New Array);
	Properties.Insert("NameOfTheXMLSignatureAlgorithm", "");
	Properties.Insert("NameOfTheXMLHashingAlgorithm", "");
	
	Return Properties;
	
EndFunction

Function NamesOfSignatureAlgorithmsGOST_34_10_94()
	
	Names = New Array;
	Names.Add("GOST 34.10-94"); // Представление.
	Names.Add("GOST R 34.10-94");
	
	Return Names;
	
EndFunction

Function NamesOfSignatureAlgorithmsGOST_34_10_2001()
	
	Names = New Array;
	Names.Add("GOST 34.10-2001"); // Представление.
	Names.Add("GOST R 34.10-2001");
	Names.Add("ECR3410-CP");
	
	Return Names;
	
EndFunction

Function NamesOfSignatureAlgorithmsGOST_34_10_2012_256()
	
	Names = New Array;
	Names.Add("GOST 34.10-2012 256"); // Представление.
	Names.Add("GR 34.10-2012 256");
	Names.Add("GOST 34.10-2012 256");
	Names.Add("GOST R 34.10-12 256");
	Names.Add("GOST3410-12-256");
	
	Return Names;
	
EndFunction

Function NamesOfSignatureAlgorithmsGOST_34_10_2012_512()
	
	Names = New Array;
	Names.Add("GOST 34.10-2012 512"); // Представление.
	Names.Add("GR 34.10-2012 512");
	Names.Add("GOST 34.10-2012 512");
	
	Return Names;
	
EndFunction

Function NamesOfHashingAlgorithmsGOST_34_11_94()
	
	Names = New Array;
	Names.Add("GOST 34.11-94"); // Представление.
	Names.Add("GOST R 34.11-94");
	Names.Add("RUS-HASH-CP");
	
	Return Names;
	
EndFunction

Function NamesOfHashingAlgorithmsGOST_34_11_2012_256()
	
	Names = New Array;
	Names.Add("GOST 34.11-2012 256"); // Представление.
	Names.Add("GR 34.11-2012 256");
	Names.Add("GOST 34.11-2012 256");
	Names.Add("GOST R 34.11-12 256");
	Names.Add("GOST3411-12-256");
	
	Return Names;
	
EndFunction

Function NamesOfHashingAlgorithmsGOST_34_11_2012_512()
	
	Names = New Array;
	Names.Add("GOST 34.11-2012 512"); // Представление.
	Names.Add("GR 34.11-2012 512");
	Names.Add("GOST 34.11-2012 512");
	
	Return Names;
	
EndFunction

Function IsCertificateExists(CryptoCertificate) Export
	
	If CryptoCertificate = Undefined Then
		Return False;
	EndIf;
	
	Try
		// 
		SerialNumber = CryptoCertificate.SerialNumber;
		Return True;
	Except
		Return False;
	EndTry;
	
EndFunction

#EndRegion

#EndRegion