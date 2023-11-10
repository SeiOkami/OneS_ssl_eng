///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns the current setting of digital signature usage.
//
// Returns:
//  Boolean - 
//
Function UseDigitalSignature() Export
	
	Return CommonSettings().UseDigitalSignature;
	
EndFunction

// Returns the current signature upgrade availability setting.
//
// Returns:
//  Boolean - 
//
Function AvailableAdvancedSignature() Export
	
	Return DigitalSignatureInternalCached.AvailableAdvancedSignature();

EndFunction

// Returns the current setting of encryption usage.
//
// Returns:
//  Boolean - 
//
Function UseEncryption() Export
	
	Return CommonSettings().UseEncryption;
	
EndFunction

// Returns the current setting of digital signature check on the server.
//
// Returns:
//  Boolean - 
//
Function VerifyDigitalSignaturesOnTheServer() Export
	
	Return CommonSettings().VerifyDigitalSignaturesOnTheServer;
	
EndFunction

// Returns the current setting of digital signature creation on the server.
// The setting also involves encryption and decryption on the server.
//
// Returns:
//  Boolean - 
//
Function GenerateDigitalSignaturesAtServer() Export
	
	Return CommonSettings().GenerateDigitalSignaturesAtServer;
	
EndFunction

// Gets object signatures and returns them.
//
// Parameters:
//  Object - DefinedType.SignedObject - a reference to the signed object.
//             The object must have the SignedWithDS attribute.
//
//  SequenceNumber - Number
//                  - Array of Number
//
// Returns:
//  Array of See DigitalSignatureClientServer.NewSignatureProperties 
//
Function SetSignatures(Object, SequenceNumber = Undefined) Export
	
	CheckParameterObject(Object, "DigitalSignature.SetSignatures", True);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckReadAllowed(Object);
	EndIf;
	
	If Common.IsReference(TypeOf(Object)) Then
		ObjectRef = Object;
	Else
		ObjectRef = Object.Ref;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	DigitalSignatures.Signature AS Signature,
		|	DigitalSignatures.SequenceNumber AS SequenceNumber,
		|	DigitalSignatures.SignatureSetBy AS SignatureSetBy,
		|	DigitalSignatures.Comment AS Comment,
		|	DigitalSignatures.SignatureFileName AS SignatureFileName,
		|	DigitalSignatures.SignatureDate AS SignatureDate,
		|	DigitalSignatures.SignatureValidationDate AS SignatureValidationDate,
		|	DigitalSignatures.SignatureCorrect AS SignatureCorrect,
		|	DigitalSignatures.Certificate AS Certificate,
		|	DigitalSignatures.Thumbprint AS Thumbprint,
		|	DigitalSignatures.CertificateOwner AS CertificateOwner,
		|	DigitalSignatures.SignatureType AS SignatureType,
		|	DigitalSignatures.IsVerificationRequired AS IsVerificationRequired,
		|	DigitalSignatures.DateActionLastTimestamp AS DateActionLastTimestamp,
		|	DigitalSignatures.SignatureID AS SignatureID
		|FROM
		|	InformationRegister.DigitalSignatures AS DigitalSignatures
		|WHERE
		|	DigitalSignatures.SignedObject = &SignedObject
		|	AND DigitalSignatures.SequenceNumber IN(&SequenceNumber)
		|
		|ORDER BY
		|	SequenceNumber";
	
	Query.SetParameter("SignedObject", ObjectRef);
	
	If SequenceNumber = Undefined Then
		Query.Text = StrReplace(Query.Text, "AND DigitalSignatures.SequenceNumber IN(&SequenceNumber)", "");
	Else
		Query.SetParameter("SequenceNumber", SequenceNumber);
	EndIf;
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	DigitalSignaturesArray = New Array;
	While SelectionDetailRecords.Next() Do
		SignatureProperties = DigitalSignatureClientServer.NewSignatureProperties();
		SignatureProperties.SignedObject = Object;
		FillPropertyValues(SignatureProperties, SelectionDetailRecords);
		SignatureProperties.Signature = SignatureProperties.Signature.Get();
		DigitalSignaturesArray.Add(SignatureProperties);
	EndDo;
	
	Return DigitalSignaturesArray;
	
EndFunction

// Adds a signature to an object and writes it.
// Sets the True value for the SignedWithDS attribute.
// 
// Parameters:
//  Object - DefinedType.SignedObject - an object will be received,
//               locked, changed, or written by reference. The object must have the SignedWithDS attribute.
//           Or immediately pass an object of the type specified above, then it
//           will be changed without locking and writing.
//
//  SignatureProperties - String - a temporary storage address that contains the structure described below.
//                  - Structure - See DigitalSignatureClientServer.NewSignatureProperties.
//                  - Array of String
//                  - Array of See DigitalSignatureClientServer.NewSignatureProperties.
//
//  FormIdentifier - UUID - a form ID that is used for lock
//                       if an object reference is passed.
//
//  ObjectVersion      - String - an object data version, if an object reference is passed that is used 
//                       to lock an object before writing it, considering that signing
//                       is performed on the client and the object could be changed during it.
//
//  WrittenObject   - Arbitrary - an object that was received and written if a reference was passed.
//
Procedure AddSignature(Object, Val SignatureProperties, FormIdentifier = Undefined,
			ObjectVersion = Undefined, WrittenObject = Undefined) Export
	
	CheckParameterObject(Object, "DigitalSignature.AddSignature");
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckChangeAllowed(Object);
	EndIf;
	
	If TypeOf(SignatureProperties) = Type("String") Then
		SignatureProperties = GetFromTempStorage(SignatureProperties);
		
	ElsIf TypeOf(SignatureProperties) = Type("Array") Then
		LastItemIndex = SignatureProperties.Count()-1;
		For IndexOf = 0 To LastItemIndex Do
			If TypeOf(SignatureProperties[IndexOf]) = Type("String") Then
				SignatureProperties[IndexOf] = GetFromTempStorage(SignatureProperties[IndexOf]);
			EndIf;
		EndDo;
	EndIf;
	
	IsReference = Common.IsReference(TypeOf(Object));
	
	BeginTransaction();
	Try
		
		If IsReference Then
			LockDataForEdit(Object, ObjectVersion, FormIdentifier);
			DataObject = Object.GetObject();
		Else
			DataObject = Object;
		EndIf;
		
		Block = New DataLock;
		LockItem = Block.Add(DataObject.Metadata().FullName());
		LockItem.SetValue("Ref", DataObject.Ref);
		
		Block.Lock();
		
		EventLogMessage = "";
		
		AddSignatureRows(DataObject, SignatureProperties, EventLogMessage);
		
		If Not DataObject.SignedWithDS
		   And (TypeOf(SignatureProperties) <> Type("Array")
		      Or SignatureProperties.Count() > 0) Then
			
			DataObject.SignedWithDS = True;
		EndIf;
		
		If IsReference Then
			// 
			DataObject.AdditionalProperties.Insert("WriteSignedObject", True);
			If DataObject.Modified() Then
				DataObject.Write();
			EndIf;
			UnlockDataForEdit(Object.Ref, FormIdentifier);
			WrittenObject = DataObject;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		If ValueIsFilled(EventLogMessage) Then
			WriteLogEvent(
				NStr("en = 'Digital signature. An error occurred while adding a signature';", Common.DefaultLanguageCode()),
				EventLogLevel.Information,
				Object.Metadata(),
				Object.Ref,
				EventLogMessage + "
				|
				|" + ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
		Raise;
	EndTry;
	
EndProcedure

// Updates an object signature.
// 
// Parameters:
//  Object - DefinedType.SignedObject - - a reference to a signed object
//             to refresh a signature for.
//
//  SignatureProperties - String - a temporary storage address that contains the structure described below.
//                  - Structure - See DigitalSignatureClientServer.NewSignatureProperties.
//  UpdateByOrderNumber - Boolean -
//                                
//
Procedure UpdateSignature(Object, Val SignatureProperties, UpdateByOrderNumber = False) Export
	
	CheckParameterObject(Object, "DigitalSignature.UpdateSignature", True);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckChangeAllowed(Object);
	EndIf;
	
	If TypeOf(SignatureProperties) = Type("String") Then
		SignatureProperties = GetFromTempStorage(SignatureProperties);
	EndIf;
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.DigitalSignatures");
	LockItem.SetValue("SignedObject", Object);
	
	BeginTransaction();
	Try
		Block.Lock();
		If UpdateByOrderNumber Then
			ObjectSignatures = SetSignatures(Object, SignatureProperties.SequenceNumber);
		Else
			ObjectSignatures = SetSignatures(Object);
		EndIf;
		For Each ObjectSignature In ObjectSignatures Do
			SignatureBinaryData = ObjectSignature.Signature;
			If UpdateByOrderNumber And ObjectSignature.SequenceNumber = SignatureProperties.SequenceNumber 
				// If binary data matches, the signature must be refreshed.
				Or SignatureBinaryData = SignatureProperties.Signature Then
					
				RecordSet = InformationRegisters.DigitalSignatures.CreateRecordSet();
				RecordSet.Filter.SequenceNumber.Set(ObjectSignature.SequenceNumber);
				RecordSet.Filter.SignedObject.Set(Object);
				RecordSet.AdditionalProperties.Insert("UpdatingSignature");
				RecordSet.Read();
				
				SignatureToRefresh = RecordSet[0];
				
				If UpdateByOrderNumber Then
					For Each KeyAndValue In SignatureProperties Do
						If KeyAndValue.Key = "Certificate"
							Or KeyAndValue.Key = "SignedObject"
							Or KeyAndValue.Key = "SignatureDate"
							Or KeyAndValue.Key = "SequenceNumber"
							Or KeyAndValue.Key = "ResultOfSignatureVerificationByMCHD" Then
							Continue;
						EndIf;
						If KeyAndValue.Value <> Undefined Then
							If KeyAndValue.Key = "Signature" Then
								SignatureToRefresh.Signature = New ValueStorage(KeyAndValue.Value);
							Else
								SignatureToRefresh[KeyAndValue.Key] = KeyAndValue.Value;
							EndIf;
						EndIf;
					EndDo;
				Else
					
					For Each KeyAndValue In SignatureProperties Do
						If KeyAndValue.Key = "Certificate"
							Or KeyAndValue.Key = "Signature"
							Or KeyAndValue.Key = "ResultOfSignatureVerificationByMCHD" Then
							Continue;
						EndIf;
						
						If KeyAndValue.Value <> Undefined Then
							SignatureToRefresh[KeyAndValue.Key] = KeyAndValue.Value;
						EndIf;
					EndDo;
					
				EndIf;
				
				If ValueIsFilled(SignatureProperties.Certificate) And Not ValueIsFilled(
					SignatureToRefresh.Certificate.Get()) Then

					If TypeOf(SignatureProperties.Certificate) = Type("ValueStorage") Then
						SignatureToRefresh.Certificate = SignatureProperties.Certificate;
					Else
						SignatureToRefresh.Certificate = New ValueStorage(SignatureProperties.Certificate,
							New Deflation(9));
					EndIf;

				EndIf;
				
				RecordSet.Write(True);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Deletes an object signature and writes it.
// 
// Parameters:
//  Object - DefinedType.SignedObject - an object will be received,
//               locked, changed, or written by reference. The object must have the SignedWithDS attribute.
//           Or immediately pass an object of the type specified above, then it
//           will be changed without locking and writing.
// 
//  SequenceNumber      - Number - a signature sequence number.
//                       - Array - 
//
//  FormIdentifier - UUID - a form ID that is used for lock
//                       if an object reference is passed.
//
//  ObjectVersion      - String - an object data version, if an object reference is passed that is used 
//                       to lock an object before writing it, considering that signing
//                       is performed on the client and the object could be changed during it.
//
//  WrittenObject   - Arbitrary - an object that was received and written if a reference was passed.
//
Procedure DeleteSignature(Object, SequenceNumber, FormIdentifier = Undefined,
			ObjectVersion = Undefined, WrittenObject = Undefined) Export
	
	CheckParameterObject(Object, "DigitalSignature.DeleteSignature");
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckChangeAllowed(Object);
	EndIf;
	
	IsReference = Common.IsReference(TypeOf(Object));
	BeginTransaction();
	Try
		If IsReference Then
			LockDataForEdit(Object, ObjectVersion, FormIdentifier);
			DataObject = Object.GetObject();
		Else
			DataObject = Object;
		EndIf;
		
		Block = New DataLock;
		LockItem = Block.Add(DataObject.Metadata().FullName());
		LockItem.SetValue("Ref", DataObject.Ref);
		Block.Lock();
		
		EventLogMessage = "";
		
		DeleteSignatureRows(DataObject, SequenceNumber, EventLogMessage);
		
		RefreshSignaturesNumbering(DataObject);
		
		If IsReference Then
			// 
			DataObject.AdditionalProperties.Insert("WriteSignedObject", True);
			If DataObject.Modified() Then
				DataObject.Write();
			EndIf;
			UnlockDataForEdit(Object.Ref, FormIdentifier);
			WrittenObject = DataObject;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		If ValueIsFilled(EventLogMessage) Then
			WriteLogEvent(
				NStr("en = 'Digital signature.Signature deletion error';", Common.DefaultLanguageCode()),
				EventLogLevel.Information,
				Object.Metadata(),
				Object.Ref,
				EventLogMessage + "
				|
				|" + ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndIf;
		Raise;
	EndTry;
	
EndProcedure

// Gets an array of encryption certificates.
// Parameters:
//  Object - DefinedType.SignedObject - a reference to the encrypted object.
//
// Returns:
//   Array - array of structures.
//
Function EncryptionCertificates(Object) Export
	
	CheckParameterObject(Object, "DigitalSignature.EncryptionCertificates", True);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckReadAllowed(Object);
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	EncryptionCertificates.Presentation,
		|	EncryptionCertificates.Thumbprint,
		|	EncryptionCertificates.Certificate,
		|	EncryptionCertificates.SequenceNumber AS SequenceNumber
		|FROM
		|	InformationRegister.EncryptionCertificates AS EncryptionCertificates
		|WHERE
		|	EncryptionCertificates.EncryptedObject = &EncryptedObject
		|
		|ORDER BY
		|	SequenceNumber";
	
	Query.SetParameter("EncryptedObject", Object);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	EncryptionCertificatesArray = New Array;
	While SelectionDetailRecords.Next() Do
		ThumbprintStructure = New Structure;
		ThumbprintStructure.Insert("Thumbprint",       SelectionDetailRecords.Thumbprint);
		ThumbprintStructure.Insert("Presentation",   SelectionDetailRecords.Presentation);
		ThumbprintStructure.Insert("Certificate",      SelectionDetailRecords.Certificate.Get());
		ThumbprintStructure.Insert("SequenceNumber", SelectionDetailRecords.SequenceNumber);
		EncryptionCertificatesArray.Add(ThumbprintStructure);
	EndDo;
	
	Return EncryptionCertificatesArray;

EndFunction

// Places encryption certificates to the information register and writes an object.
// Sets the Encrypted attribute by the presence of certificates in the EncryptionCertificate information register.
// 
// Parameters:
//  Object - DefinedType.SignedObject - an object will be received,
//               locked, changed, or written by reference. The object must have the Encrypted attribute.
//           Or immediately pass an object of the type specified above, then it
//           will be changed without locking and writing.
//
//  EncryptionCertificates - String - a temporary storage address that contains the array described below.
//                        - Array - 
//                             * Thumbprint     - String - a certificate thumbprint in the Base64 string format.
//                             * Presentation - String - a saved subject presentation
//                                                  got from certificate binary data.
//                             * Certificate    - BinaryData - contains export of the certificate
//                                                  that was used for encryption.
//
//  FormIdentifier - UUID - a form ID that is used for lock
//                       if an object reference is passed.
//
//  ObjectVersion      - String - an object data version, if an object reference is passed that is used 
//                       to lock an object before writing it, considering that signing
//                       is performed on the client and the object could be changed during it.
//
//  WrittenObject   - Arbitrary - an object that was received and written if a reference was passed.
//
Procedure WriteEncryptionCertificates(Object, Val EncryptionCertificates, FormIdentifier = Undefined,
	ObjectVersion = Undefined, WrittenObject = Undefined) Export
	
	CheckParameterObject(Object, "DigitalSignature.WriteEncryptionCertificates", False);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.CheckChangeAllowed(Object);
	EndIf;
	
	IsReference = Common.IsReference(TypeOf(Object));
	ObjectRef = ?(IsReference, Object, Object.Ref);
	
	If TypeOf(EncryptionCertificates) = Type("String") Then
		EncryptionCertificates = GetFromTempStorage(EncryptionCertificates);
	EndIf;
	
	BeginTransaction();
	Try
		If IsReference Then
			LockDataForEdit(ObjectRef, ObjectVersion, FormIdentifier);
			DataObject = Object.GetObject();//  
		Else
			DataObject = Object;
		EndIf;
		
		SetPrivilegedMode(True);
		RecordSet = InformationRegisters.EncryptionCertificates.CreateRecordSet();
		RecordSet.Filter.EncryptedObject.Set(DataObject.Ref);
		SequenceNumber = 1;
		For Each EncryptionCertificate In EncryptionCertificates Do
			NewCertificate = RecordSet.Add();
			NewCertificate.EncryptedObject = DataObject.Ref;
			FillPropertyValues(NewCertificate, EncryptionCertificate);
			NewCertificate.SequenceNumber = SequenceNumber;
			SequenceNumber = SequenceNumber + 1;
		EndDo;
		
		DataObject.Encrypted = RecordSet.Count() > 0;
		
		RecordSet.Write();
		If IsReference Then
			UnlockDataForEdit(ObjectRef, FormIdentifier);
			WrittenObject = DataObject;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns the date extracted from the signature binary data or Undefined.
//
// Parameters:
//  Signature - BinaryData - signature data to extract a date from.
//  CastToSessionTimeZone - Boolean - cast the universal time to the session time.
//
// Returns:
//  Date - 
//  
//
Function SigningDate(Signature, CastToSessionTimeZone = True) Export
	
	SigningDate = DigitalSignatureInternalClientServer.SigningDateUniversal(Signature);
	
	If SigningDate = Undefined Then
		Return Undefined;
	EndIf;
	
	If CastToSessionTimeZone Then
		SigningDate = ToLocalTime(SigningDate, SessionTimeZone());
	EndIf;
	
	Return SigningDate;
	
EndFunction

// Searches for a certificate in the catalog and returns a reference if the certificate is found.
//
// Parameters:
//  Certificate - CryptoCertificate - a certificate.
//             - BinaryData - binary data of the certificate.
//             - String - 
//             - String      - 
//
// Returns:
//  Undefined - 
//  
//
Function CertificateRef(Val Certificate) Export
	
	If TypeOf(Certificate) = Type("String") And IsTempStorageURL(Certificate) Then
		Certificate = GetFromTempStorage(Certificate);
	EndIf;
	
	If TypeOf(Certificate) = Type("BinaryData") Then
		Certificate = New CryptoCertificate(Certificate);
	EndIf;
	
	If TypeOf(Certificate) = Type("CryptoCertificate") Then
		ThumbprintAsString = Base64String(Certificate.Thumbprint);
	Else
		ThumbprintAsString = String(Certificate);
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Thumbprint", ThumbprintAsString);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS Certificates
	|WHERE
	|	Certificates.Thumbprint = &Thumbprint";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Allows you to create and update the DigitalSignatureAndEncryptionKeysCertificates catalog item
// by the specified crypto certificate.
// To add a certificate at the client See DigitalSignatureClient.ToAddCertificate.
//
// Parameters:
//  Certificate - CryptoCertificate - a certificate.
//             - BinaryData - binary data of the certificate.
//             - String - 
//
//  AdditionalParameters - Undefined - without additional parameters.
//                          - Structure - 
//      * Description - String - a certificate presentation in the list.
//
//      * User - CatalogRef.Users - a user who owns the certificate.
//                       The value is used when receiving a list of personal user certificates
//                       in the forms of signing and data encryption.
//
//      * Organization     - DefinedType.Organization - a company that owns the certificate.
//      * Individual  - DefinedType.Individual -
//
//      * Application - CatalogRef.DigitalSignatureAndEncryptionApplications - an application
//                      that is required for signature and encryption.
//
//      * EnterPasswordInDigitalSignatureApplication - Boolean - Flag "Protect digital signature application with password".
//                      True is required if a certificate was installed on the computer with strong private key protection.
//                      Meaning that only a blank password is supported at 1C:Enterprise level.
//                      The password is requested by the operating system, which rejects empty passwords from 1C:Enterprise.
//                      
//
// Returns:
//  CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - link to the certificate.
// 
Function WriteCertificateToCatalog(Val Certificate, AdditionalParameters = Undefined) Export
	
	If TypeOf(AdditionalParameters) <> Type("Structure") Then
		AdditionalParameters = New Structure;
	EndIf;
	
	If TypeOf(Certificate) = Type("String") And IsTempStorageURL(Certificate) Then
		CertificateBinaryData = GetFromTempStorage(Certificate);
	
	ElsIf TypeOf(Certificate) = Type("BinaryData") Then
		CertificateBinaryData = Certificate;
	EndIf;
	
	If CertificateBinaryData = Undefined Then
		CryptoCertificate = Certificate;
		CertificateBinaryData = CryptoCertificate.Unload();
	Else
		CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	EndIf;
	
	If AdditionalParameters.Property("CertificateRef") Then
		CertificateReference = AdditionalParameters.CertificateRef;
	Else
		CertificateReference = CertificateRef(Certificate);
	EndIf;
	
	AccessRightInsert = AccessRight("Insert", Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates);
	
	If Not AccessRightInsert And Not ValueIsFilled(CertificateReference) Then
		Raise(NStr("en = 'Insufficient rights to use certificates that are not in the catalog.';"));
	EndIf;
	
	AllowedFieldsToChange = Undefined;
	If Not AccessRightInsert Then
		AllowedFieldsToChange = New Array;
		AllowedFieldsToChange.Add("Organization");
		AllowedFieldsToChange.Add("User");
		AllowedFieldsToChange.Add("Application");
		AllowedFieldsToChange.Add("EnterPasswordInDigitalSignatureApplication");
		SetPrivilegedMode(True);
	EndIf;
		
	BeginTransaction();
	Try
		
		If ValueIsFilled(CertificateReference) Then
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.DigitalSignatureAndEncryptionKeysCertificates");
			LockItem.SetValue("Ref", CertificateReference);
			
			Block.Lock();
			
			CertificateObject = CertificateReference.GetObject();
			UpdateValue(CertificateObject.DeletionMark, False);
			
		Else
			CertificateObject = Catalogs.DigitalSignatureAndEncryptionKeysCertificates.CreateItem();
			CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
			CertificateObject.Thumbprint = Base64String(CryptoCertificate.Thumbprint);
			
			CertificateObject.Added = Users.AuthorizedUser();
		EndIf;
		
		If CertificateObject.CertificateData.Get() <> CertificateBinaryData Then
			If AccessRightInsert Then
				CertificateObject.CertificateData = New ValueStorage(CertificateBinaryData);
			Else
				RollbackTransaction();
				Raise(NStr("en = 'Insufficient rights to modify certificate data.';"));
			EndIf;
		EndIf;
		
		If AccessRightInsert Then
			CertificateProperties = CertificateProperties(CryptoCertificate);
			UpdateValue(CertificateObject.Signing,     CertificateProperties.Signing);
			UpdateValue(CertificateObject.Encryption,     CertificateProperties.Encryption);
			UpdateValue(CertificateObject.IssuedTo,      CertificateProperties.IssuedTo);
			UpdateValue(CertificateObject.IssuedBy,       CertificateProperties.IssuedBy);
			UpdateValue(CertificateObject.ValidBefore, CertificateProperties.EndDate);
			
			SubjectProperties = CertificateSubjectProperties(CryptoCertificate);
			
			If SubjectProperties.Property("MiddleName") Then
				NameAndPatronymicOfSubject = ?(ValueIsFilled(SubjectProperties.Name), SubjectProperties.Name, "")
					+ ?(ValueIsFilled(SubjectProperties.MiddleName), " " + SubjectProperties.MiddleName, "");
				NameAndPatronymicOfCertificate = ?(ValueIsFilled(CertificateObject.Name), CertificateObject.Name, "")
					+ ?(ValueIsFilled(CertificateObject.MiddleName), " " + CertificateObject.MiddleName, "");
				If NameAndPatronymicOfSubject <> NameAndPatronymicOfCertificate Then
					UpdateValue(CertificateObject.Name, SubjectProperties.Name, True);
					UpdateValue(CertificateObject.MiddleName, SubjectProperties.MiddleName, True);
				EndIf;
			Else
				UpdateValue(CertificateObject.Name, SubjectProperties.Name, True);
			EndIf;
			
			UpdateValue(CertificateObject.LastName,   SubjectProperties.LastName,     True);
			UpdateValue(CertificateObject.Firm,     SubjectProperties.Organization, True);
			
			If SubjectProperties.Property("JobTitle") Then
				UpdateValue(CertificateObject.JobTitle, SubjectProperties.JobTitle,   True);
			EndIf;
		EndIf;
		
		If CertificateObject.IsNew()
		   And Not AdditionalParameters.Property("Description") Then
			
			AdditionalParameters.Insert("Description",
				CertificatePresentation(CryptoCertificate));
		EndIf;
		
		For Each KeyAndValue In AdditionalParameters Do
			
			If KeyAndValue.Key = "CertificateRef" Then
				Continue;
			EndIf;
			
			If AllowedFieldsToChange <> Undefined 
			   And AllowedFieldsToChange.Find(KeyAndValue.Key) = Undefined Then
				Continue;
			EndIf;
			
			If KeyAndValue.Key = "User" Then
				If ValueIsFilled(KeyAndValue.Value) Then
					If ValueIsFilled(CertificateObject.User) And CertificateObject.User <> KeyAndValue.Value Then
						AddAUserToTheCertificate(CertificateObject.User, CertificateObject.Users);
						AddAUserToTheCertificate(KeyAndValue.Value, CertificateObject.Users);
						CertificateObject.User = Undefined;
					ElsIf CertificateObject.Users.Count() > 0 Then
						AddAUserToTheCertificate(KeyAndValue.Value, CertificateObject.Users);
					Else
						UpdateValue(CertificateObject[KeyAndValue.Key], KeyAndValue.Value);
					EndIf;
				EndIf;
			Else
				UpdateValue(CertificateObject[KeyAndValue.Key], KeyAndValue.Value);
			EndIf;
		EndDo;
		
		If CertificateObject.Modified() Then
			CertificateObject.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return CertificateObject.Ref;
	
EndFunction

// Returns a spreadsheet document that contains a digital signature visualization stamp.
//
// Parameters:
//  Certificate   - CryptoCertificate - a certificate the document is signed with.
//  SignatureDate  - Date - a date of signing the document.
//  MarkText - String - a text that appears directly below the stamp and describes
//                          the location of the original document.
//  CompanyLogo - Picture - if it is not specified, the standard picture will be used.
//
// Returns:
//  SpreadsheetDocument - 
//
Function DigitalSignatureVisualizationStamp(Certificate, SignatureDate = Undefined, 
	MarkText = "", CompanyLogo = Undefined) Export
	
	If CompanyLogo = Undefined And Common.SubsystemExists("StandardSubsystems.Copmanies") Then
		ModuleOrganizationServer = Common.CommonModule("CompaniesServer");
		CertificateReference = CertificateRef(Certificate);
		If ValueIsFilled(CertificateReference) Then
			Organization = Common.ObjectAttributeValue(CertificateReference, "Organization");
			If ValueIsFilled(Organization) Then
				AdditionalInfo = ModuleOrganizationServer.AdditionalOrganizationInformation(
					Organization, , SignatureDate);
				If AdditionalInfo.Property("OrganizationSLogoForAnElectronicSignatureStamp") Then
					CompanyLogo = AdditionalInfo.OrganizationSLogoForAnElectronicSignatureStamp;
				EndIf;		
			EndIf;	
		EndIf;	
	EndIf;	
	
	CertificateProperties = CertificateProperties(Certificate);
	
	ActionPeriod = NStr("en = 'from %1 to %2';");
	ActionPeriod = StringFunctionsClientServer.SubstituteParametersToString(ActionPeriod,
		Format(CertificateProperties.StartDate,    "DLF=D"),
		Format(CertificateProperties.EndDate, "DLF=D"));
	
	StampParameters = New Structure;
	StampParameters.Insert("SignatureDate", SignatureDate);
	StampParameters.Insert("CertificateNumber", CertificateProperties.SerialNumber);
	StampParameters.Insert("CertificateIssuedBy", CertificateProperties.IssuedBy);
	StampParameters.Insert("CertificateRecipient", CertificateProperties.IssuedTo);
	StampParameters.Insert("ValidityPeriod", ActionPeriod);
	StampParameters.Insert("MarkText", MarkText);
	
	Stamp = Catalogs.DigitalSignatureAndEncryptionKeysCertificates.GetTemplate("Stamp");
	FillPropertyValues(Stamp.Parameters, StampParameters);
	If CompanyLogo <> Undefined Then
		Stamp.Areas.Picture.Picture = CompanyLogo;
	EndIf;
	
	Return Stamp;
	
EndFunction

// Places stamps to the passed spreadsheet document.
//
// Parameters:
//  Document        - SpreadsheetDocument - a spreadsheet document to add stamps to.
//  StampsDetails - Array - an array of spreadsheet documents that contain stamps got
//                             by the DigitalSignature.DigitalSignatureVisualizationStamp function.
//                             In this case, the passed stamps will be output to the end of the document
//                             if the template of the spreadsheet document to be signed does not define areas
//                             for placing stamps that meet the following conditions:
//                               a) the stamp output area of two columns and seven rows, with
//                                  an arbitrary column width,
//                               b) the area name is specified as DSStamp + stamp sequence number,
//                                  for example, DSStamp1 and so on.
//                             In this case, stamps will be output in the specified areas, in the
//                             order in which the document was signed.
//                  - Map of KeyAndValue - 
//                       * Key     - String - an area name, where the stump must be put. For such an area,
//                                    an arbitrary column width 
//                                    different from the column width of the rest of the document, must be set.
//                       * Value - SpreadsheetDocument - a stamp got by the
//                                       DigitalSignature.DigitalSignatureVisualizationStamp function.
//  CellSize         - Structure - allows you to change stamp size and has the following properties:
//                       * LeftColumn  - Number - width of the left stamp column that contains property titles.
//                                                 The default value is 10.
//                       * RightColumn - Number - width of the right stamp column that contains property titles.
//                                                 The default value is 30.
//
Procedure AddStampsToSpreadsheetDocument(Document, StampsDetails, CellSize = Undefined) Export
	
	If CellSize = Undefined Then
		CellSize = New Structure;
		CellSize.Insert("LeftColumn", 10);
		CellSize.Insert("RightColumn", 30);
	EndIf;
	
	If TypeOf(StampsDetails) = Type("Array") Then
		
		StampIndex = 1; StampCount = StampsDetails.Count();
		
		StampColumnsWidth = 3 + CellSize.LeftColumn + CellSize.RightColumn;
		
		StampsCountByWidth = Undefined;
		StampNumberInRow = 0; StampsRowWidth = 0; TableWidth = 0;
		
		For Each Stamp In StampsDetails Do
			AreaName = "DSStamp" + String(StampIndex);
			AreaFound = Document.Areas.Find(AreaName) <> Undefined;
			
			If AreaFound Then
				Document.InsertArea(Stamp.Areas.Stamp, Document.Areas[AreaName],, True);
				Document.Areas.StampLeftColumn.ColumnWidth  = CellSize.LeftColumn;
				Document.Areas.StampRightColumn.ColumnWidth = CellSize.RightColumn;
			Else
				StampNumberInRow = StampNumberInRow + 1;
				
				StampWidth = Stamp.Areas.Stamp.Right;
				StampTop = Stamp.Areas.Stamp.Top;
				BottomStamp = Stamp.Areas.Stamp.Bottom;
				StampHeight = BottomStamp - StampTop;
				
				If StampNumberInRow = 1 Or StampNumberInRow > StampsCountByWidth Then
					
					If StampsCountByWidth = Undefined Then
						
						For TableWidth = 1 To Document.TableWidth Do
							
							Area = Document.Area(, TableWidth,, TableWidth);
							StampsRowWidth = StampsRowWidth + Area.ColumnWidth;
							If Area.PageBottom Then
								Break;
							EndIf;
							
							If TableWidth = Document.TableWidth Then
								
								StampsRowWidth = 0;
								TableHeight = Min(Document.TableHeight, 100);
								
								For ColumnNumberBackward = 1 To TableWidth Do
									
									ColumnNumber = TableWidth - ColumnNumberBackward + 1;
									
									For RowNumberBackward = 1 To TableHeight Do
										
										LineNumber = Document.TableHeight - RowNumberBackward + 1;
										
										TableCellArea = Document.Area(LineNumber, ColumnNumber);
										
										If IsBlankString(TableCellArea.Text)
											And TableCellArea.Left = ColumnNumber
											And TableCellArea.Top = LineNumber
											And TableCellArea.RightBorder.LineType = SpreadsheetDocumentCellLineType.None
											And TableCellArea.BottomBorder.LineType = SpreadsheetDocumentCellLineType.None
											And TableCellArea.TopBorder.LineType = SpreadsheetDocumentCellLineType.None
											Then
											Continue;
										EndIf;
										
										SpreadsheetDocument = New SpreadsheetDocument;
										Area = Document.GetArea(LineNumber, 1, LineNumber, ColumnNumber);
										SpreadsheetDocument.Put(Area);
										
										For SpreadsheetColumnNumber = 1 To ColumnNumber Do
											Area = SpreadsheetDocument.Area(1, SpreadsheetColumnNumber, 1,
												SpreadsheetColumnNumber);
											StampsRowWidth = StampsRowWidth + Area.ColumnWidth;
										EndDo;
										
										Break;
									EndDo;
									
									If StampsRowWidth <> 0 Then
										Break;
									EndIf;
								EndDo;
								
								Break;
							EndIf;
						EndDo;
						StampsCountByWidth = Max(1, Int(StampsRowWidth/StampColumnsWidth));
					EndIf;
						
					StartingWidth = 1; StampNumberInRow = 1;
					
					AreasToCheckByHeight = New Array;
					AreasToCheckByHeight.Add(Stamp.GetArea("Indent"));
					AreasToCheckByHeight.Add(Stamp.GetArea("RowsAreaStamp"));
					If Not Common.SpreadsheetDocumentFitsPage(Document, AreasToCheckByHeight, True) Then
						Document.PutHorizontalPageBreak();
					EndIf;
					
					Document.Put(Stamp.GetArea("Indent"));
					
					HeightStart = Document.TableHeight;
					HeightEnd = Document.TableHeight + StampHeight;
					
					Document.Area(HeightStart, StartingWidth, HeightEnd, TableWidth).UndoMerge();
					// 
					Document.Area(HeightStart, , HeightEnd).CreateFormatOfRows();
					
					RemainingWidth = StampsRowWidth;
					
				EndIf;
				
				FinalWidth = StartingWidth - 1 + StampWidth;
				
				// Insert the area from the stamp layout in the gap.
				SourceArea = Stamp.Area(StampTop, 1, BottomStamp, StampWidth);
				ReceivingArea = Document.Area(HeightStart, StartingWidth, HeightEnd, FinalWidth);
				Document.InsertArea(SourceArea, ReceivingArea, , True);
				
				Document.Areas.StampLeftColumn.ColumnWidth  = CellSize.LeftColumn;
				Document.Areas.StampRightColumn.ColumnWidth = CellSize.RightColumn;
				Document.Areas.StampIndent.ColumnWidth       = 3;
					
				StartingWidth = FinalWidth + 1;
				
				If RemainingWidth > StampColumnsWidth Or StampIndex = StampCount Then
					
					RemainingWidth = RemainingWidth - StampColumnsWidth;
					
					If RemainingWidth < StampColumnsWidth Or StampIndex = StampCount Then
						If StartingWidth < TableWidth Then
							Document.Area(HeightStart, StartingWidth, HeightEnd, TableWidth).ColumnWidth = 0;
						EndIf;
						If RemainingWidth > 0 Then
							Document.Area(HeightStart, StartingWidth, HeightEnd, StartingWidth).ColumnWidth = RemainingWidth;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			StampIndex = StampIndex + 1;
		EndDo;

	Else
		For Each StampDetails In StampsDetails Do
			AreaName = StampDetails.Key;
			Stamp      = StampDetails.Value;
			AreaFound = Document.Areas.Find(AreaName) <> Undefined;
			If AreaFound Then
				Document.InsertArea(Stamp.Areas.Stamp, Document.Areas[AreaName],, True);
				Document.Areas.StampLeftColumn.ColumnWidth  = CellSize.LeftColumn;
				Document.Areas.StampRightColumn.ColumnWidth = CellSize.RightColumn;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// See DigitalSignatureClient.CertificatePresentation.
Function CertificatePresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificatePresentation(Certificate, DigitalSignatureInternal.TimeAddition());
	
EndFunction

// See DigitalSignatureClient.SubjectPresentation.
Function SubjectPresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.SubjectPresentation(Certificate);
	
EndFunction

// See DigitalSignatureClient.IssuerPresentation.
Function IssuerPresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.IssuerPresentation(Certificate);
	
EndFunction

// See DigitalSignatureClient.CertificateProperties.
Function CertificateProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateProperties(Certificate, DigitalSignatureInternal.TimeAddition());
	
EndFunction

// See DigitalSignatureClient.CertificateSubjectProperties.
Function CertificateSubjectProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateSubjectProperties(Certificate);
	
EndFunction

// See DigitalSignatureClient.CertificateIssuerProperties.
Function CertificateIssuerProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateIssuerProperties(Certificate);
	
EndFunction

// Searches for the error text in the classifier of standard issues upon using a digital signature and,
// if it finds it, returns the reasons of its occurrence and methods to fix it.
//
// Parameters:
//   TextToSearchInClassifier - String - the text by which a search is being carried out in the classifier.
//   ErrorAtServer               - Boolean -
//                                   
//
// Returns:
//   Undefined - 
//   
//     * Cause          - String - possible causes of an error.
//     * Decision          - String - possible methods to fix the occurred error.
//     * Remedy - String - the ID of the method of the automatic error fixing.
//     * Ref           - String - the anchor ID in the article on the ITS website.
//
Function ClassifierError(TextToSearchInClassifier, ErrorAtServer = False) Export
	
	Result = DigitalSignatureInternal.ClassifierError(TextToSearchInClassifier, ErrorAtServer);
	
	If Result = Undefined Then
		Return Undefined;
	EndIf;
	
	Structure = New Structure("Cause, Decision, Remedy, Ref");
	FillPropertyValues(Structure, Result);
	
	Return Structure;
	
EndFunction

// Upgrades the signature to the given type if possible.
// Adds an archive timestamp to the archived signature (CAdES-A).
// 
// Parameters:
//  Signature                      - BinaryData - binary data of the electronic signature.
//  SignatureType                   - EnumRef.CryptographySignatureTypes - Signature type to upgrade to.
//                                  If the actual SignatureType is the same or higher, no actions are performed.
//                                  
//  AddArchiveTimestamp - Boolean -
//                                   
//  AdditionalParameters - Structure:
//                             * CryptoManager - Undefined -
//                                                    - CryptoManager - 
//                             * ShouldIgnoreCertificateValidityPeriod  - Boolean - 
//                                                      
//                          - Undefined - get a cryptography Manager for verifying
//                                 electronic signatures, as configured by the administrator.
//                          - CryptoManager - 
// 
// Returns:
//  Structure:
//   * Success - Boolean - True if upgrade was successful or wasn't needed.
//   * ErrorText - String - If False, a value is assigned.
//   * SignatureProperties - See DigitalSignatureClientServer.NewSignatureProperties.
//
Function EnhanceSignature(Signature, SignatureType, AddArchiveTimestamp = False,
	AdditionalParameters = Undefined) Export
	
	EnhancementParameters = New Structure;
	EnhancementParameters.Insert("CryptoManager", Undefined);
	EnhancementParameters.Insert("ShouldIgnoreCertificateValidityPeriod", False);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(EnhancementParameters, AdditionalParameters);
	Else
		EnhancementParameters.CryptoManager = AdditionalParameters;
	EndIf;
	
	CryptoManager = EnhancementParameters.CryptoManager;
	
	Result = New Structure("Success, ErrorText, SignatureProperties", False);

	If CryptoManager = Undefined Then
		
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.SignAlgorithm =
			DigitalSignatureInternalClientServer.GeneratedSignAlgorithm(Signature);
		
		CryptoManager = DigitalSignatureInternal.CryptoManager(
			"ExtensionValiditySignature", CreationParameters);
		
		If CryptoManager = Undefined Then
			Result.ErrorText = CreationParameters.ErrorDescription;
			Return Result;
		EndIf;
		
		CryptoManager.TimestampServersAddresses = CommonSettings().TimestampServersAddresses;

	EndIf;
	
	SignatureProperties = DigitalSignatureClientServer.NewSignatureProperties();
	
	Try
		ContainerSignatures = CryptoManager.GetCryptoSignaturesContainer(Signature);
	Except
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot read the signature data: %1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return Result;
	EndTry;
	
	ParametersCryptoSignatures = DigitalSignatureInternalClientServer.ParametersCryptoSignatures(ContainerSignatures,
		DigitalSignatureInternal.TimeAddition(), CurrentSessionDate());
		
	If ParametersCryptoSignatures.CertificateLastTimestamp = Undefined Then
		Result.ErrorText = NStr("en = 'Cannot get the signature certificate';");
		Return Result;
	EndIf;
	
	SignatureProperties.SignatureType = ParametersCryptoSignatures.SignatureType;
	SignatureProperties.DateActionLastTimestamp = ParametersCryptoSignatures.DateActionLastTimestamp; 
	
	Result.SignatureProperties = SignatureProperties;
	
	If Not EnhancementParameters.ShouldIgnoreCertificateValidityPeriod
		And ValueIsFilled(ParametersCryptoSignatures.DateActionLastTimestamp)
		And ParametersCryptoSignatures.DateActionLastTimestamp < CurrentSessionDate() Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The signature expired: %1';"), ParametersCryptoSignatures.DateActionLastTimestamp);
		Return Result;
	EndIf;
	
	ErrorDescription = "";
	CertificateVerificationResult = CheckCertificate(CryptoManager,
		ParametersCryptoSignatures.CertificateLastTimestamp, ErrorDescription);
	If CertificateVerificationResult Then
		If ValueIsFilled(SignatureType) And DigitalSignatureInternalClientServer.ToBeImproved(
			ParametersCryptoSignatures.SignatureType, SignatureType) Then
			Try
				ResultBinaryData = CryptoManager.EnhanceSignature(Signature,
					DigitalSignatureInternalClientServer.CryptoSignatureType(SignatureType));
			Except
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Couldn''t enhance the signature: %1';"), ErrorProcessing.BriefErrorDescription(
					ErrorInfo()));
				Return Result;
			EndTry;
		ElsIf AddArchiveTimestamp And (ParametersCryptoSignatures.SignatureType
			= Enums.CryptographySignatureTypes.ArchivalCAdESAv3 Or ParametersCryptoSignatures.SignatureType
			= Enums.CryptographySignatureTypes.CAdESAv2) Then
			Try
				ResultBinaryData = CryptoManager.AddArchiveTimestamp(Signature);
			Except
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot add an archive timestamp to the signature: %1';"), ErrorProcessing.BriefErrorDescription(
					ErrorInfo()));
				Return Result;
			EndTry;
		Else // 
			Result.Success = True;
			Return Result;
		EndIf;
	Else
		CertificateProperties = CertificateProperties(ParametersCryptoSignatures.CertificateLastTimestamp);
		InformationAboutCertificate = DigitalSignatureInternalClientServer.DetailsCertificateString(
				CertificateProperties);
				
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The signature certificate is invalid: %1
				|%2';"), ErrorDescription, InformationAboutCertificate);
		Return Result;
	EndIf;
	
	Try
		ContainerSignatures = CryptoManager.GetCryptoSignaturesContainer(ResultBinaryData);
	Except
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t read the enhanced signature data: %1';"), ErrorProcessing.BriefErrorDescription(
			ErrorInfo()));
		Return Result;
	EndTry;

	ParametersCryptoSignatures = DigitalSignatureInternalClientServer.ParametersCryptoSignatures(
			ContainerSignatures, DigitalSignatureInternal.TimeAddition(), CurrentSessionDate());
	
	CertificateVerificationResult = CheckCertificate(CryptoManager,
		ParametersCryptoSignatures.CertificateLastTimestamp, ErrorDescription);

	If CertificateVerificationResult Then
		SignatureProperties.Signature = ResultBinaryData;
		SignatureProperties.SignatureType = ParametersCryptoSignatures.SignatureType;
		SignatureProperties.DateActionLastTimestamp = ParametersCryptoSignatures.DateActionLastTimestamp;
		Result.SignatureProperties = SignatureProperties;
	Else
		CertificateProperties = CertificateProperties(ParametersCryptoSignatures.CertificateLastTimestamp);
		InformationAboutCertificate = DigitalSignatureInternalClientServer.DetailsCertificateString(
				CertificateProperties);

		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The certificate of the received timestamp is invalid: %1
					 |%2';"), ErrorDescription, InformationAboutCertificate);

		Raise ErrorDescription;
	EndIf;
	
	Result.Success = True;
	Return Result;
	
EndFunction

// Upgrades the object signature to the given type if applicable.
// Adds an archived timestamp to the archived signature (CAdES-A).
// Updates object signature data (Signature type, Validity period of the last timestamp).
// 
// Parameters:
//  SignedObject - DefinedType.SignedObject - Reference to the signature for upgrade and update lock.
//           
//
//  SequenceNumber - Number - serial number of the signature.
//
//  SignatureType      - EnumRef.CryptographySignatureTypes - Signature type to upgrade to.
//                    If the actual SignatureType is the same or higher, no actions are performed.
//                    
//
//  AddArchiveTimestamp - Boolean - If True and SignatureType and actual SignatureType are archived, add a timestamp.
//                           
//
//  FormIdentifier - UUID - a form ID that is used for lock
//                      if an object reference is passed.
//
//  AdditionalParameters - Structure:
//                             * CryptoManager - Undefined, CryptoManager -
//                             * ShouldIgnoreCertificateValidityPeriod  - Boolean - 
//                                                      
//                          - Undefined - get a cryptography Manager for verifying
//                                 electronic signatures, as configured by the administrator.
//                          - CryptoManager - 
//
// Returns:
//  Structure:
//   * Success - Boolean - True if upgrade was successful or wasn't needed.
//   * ErrorText - String - If False, a value is assigned.
//   * SignatureProperties - See DigitalSignatureClientServer.NewSignatureProperties
//   
Function ImproveObjectSignature(SignedObject, SequenceNumber, SignatureType, AddArchiveTimestamp = False,
			FormIdentifier = Undefined, AdditionalParameters = Undefined) Export
			
			
	EnhancementParameters = New Structure;
	EnhancementParameters.Insert("CryptoManager", Undefined);
	EnhancementParameters.Insert("ShouldIgnoreCertificateValidityPeriod", False);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(EnhancementParameters, AdditionalParameters);
	Else
		EnhancementParameters.CryptoManager = AdditionalParameters;
	EndIf;

	Result = New Structure("Success, ErrorText, SignatureProperties", False);
	
	SetSignatures = SetSignatures(SignedObject, SequenceNumber);
	
	If SetSignatures.Count() = 0 Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot find a signature with sequence number %1 for %2';"), SequenceNumber, SignedObject);
		Return Result;
	EndIf;
		
	SignatureProperties = SetSignatures[0];
	Signature = SignatureProperties.Signature;
	
	Result = EnhanceSignature(Signature, SignatureType, AddArchiveTimestamp, EnhancementParameters);
		
	If Result.SignatureProperties = Undefined Then
		Return Result;
	EndIf;
	
	Result.SignatureProperties.SignedObject = SignedObject;
	Result.SignatureProperties.SequenceNumber = SequenceNumber;

	If Result.SignatureProperties.Signature = Undefined Then
		// Signature wasn't upgraded. But the data may require an update.
		If SignatureProperties.SignatureType = Result.SignatureProperties.SignatureType
			And SignatureProperties.DateActionLastTimestamp = Result.SignatureProperties.DateActionLastTimestamp Then
			Return Result;
		EndIf;
	EndIf;
	
	ErrorPresentation = DigitalSignatureInternal.UpdateAdvancedSignature(
		Result.SignatureProperties);
	
	If ValueIsFilled(ErrorPresentation) Then
		Result.ErrorText = ErrorPresentation;
		Result.Success = False;
		Result.SignatureProperties = Undefined;
		Return Result;
	EndIf;
	
	If ValueIsFilled(Result.SignatureProperties.Signature) Then
		DigitalSignatureInternal.RegisterImprovementSignaturesInJournal(Result.SignatureProperties);
	EndIf;
	
	Return Result;
	
EndFunction

#Region ForCallsFromOtherSubsystems

// These procedures and functions are intended for integration with 1C:Electronic document library.

// Returns the crypto manager (on the server) for the specified application.
//
// Parameters:
//  Operation       - String - if it is not blank, it needs to contain one of rows that determine
//                   the operation to insert into the error description: Signing, SignatureCheck, Encryption,
//                   Decryption, CertificateCheck, and GetCertificates.
//
//  ShowError - Boolean - if True, throw an exception that contains the error description.
//
//  ErrorDescription - String - an error description that is returned when the function returns Undefined.
//
//  Application      - Undefined - returns a crypto manager of the first
//                   application from the catalog for which it was possible to create it.
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - 
//                   
//                 - Structure - See NewApplicationDetails.
//                 - BinaryData - 
//                 - String - 
//
// Returns:
//   CryptoManager - 
//   
//
Function CryptoManager(Operation, ShowError = True, ErrorDescription = "", Application = Undefined) Export
	
	CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
	CreationParameters.Application = Application;
	CreationParameters.ShowError = ShowError;
	
	Result = DigitalSignatureInternal.CryptoManager(Operation, CreationParameters);
	
	If Result = Undefined Then
		ErrorDescription = CreationParameters.ErrorDescription;
	EndIf;
	
	Return Result;
	
EndFunction

//  
// 
//
// Parameters:
//   Signature - BinaryData -
//   ShouldReadCertificates - Boolean -
//                                   
//
// Returns:
//   Structure:
//       * Success       - Boolean, Undefined -
//                                              
//       * ErrorText - String -
//       * SignatureType  - EnumRef.CryptographySignatureTypes
//       * DateActionLastTimestamp - Date, Undefined -
//       * DateSignedFromLabels - Date, Undefined -
//               
//       * UnverifiedSignatureDate - Date -
//                                     - Undefined - 
//       * Certificate  - BinaryData -
//       * Thumbprint           - String - the thumbprint of the certificate in Base64 string format.
//       * CertificateOwner - String - the subject representation obtained from the certificate's binary data. 
//       * Certificates - Array of BinaryData -
//
Function SignatureProperties(Signature, ShouldReadCertificates = True) Export
	
	Return DigitalSignatureInternal.SignatureProperties(Signature, ShouldReadCertificates)
	
EndFunction

// 
// 
// Parameters:
//  CheckParameters - 
//   
//                          See DigitalSignatureInternalClientServer.AppsRelevantAlgorithms
//                          
//                          
//                               
//                          
//  Returns:
//    Structure:
//     * CheckCompleted - Boolean -
//                 
//     * Error - String - error text.
//     * Programs - Array of Structure:
//        ** ApplicationName  - String  -
//        ** ApplicationType  - Number  -
//        ** Name           - String  -
//             
//        ** Version        - String -
//        ** ILicenseInfo      - Boolean -
//     * IsConflictPossible - Boolean -
//             
//
Function CheckCryptographyAppsInstallation(CheckParameters = Undefined) Export
	
	Context = New Structure;
	Context.Insert("AppsToCheck", Undefined);
	Context.Insert("ExtendedDescription", False);
	Context.Insert("SignAlgorithms", New Array);
	Context.Insert("DataType", Undefined);
	Context.Insert("IsServer", True);
	
	If TypeOf(CheckParameters) = Type("Structure") Then
		FillPropertyValues(Context, CheckParameters);
	EndIf;
	
	If Context.AppsToCheck <> Undefined Then
		If Context.AppsToCheck = True Then
			Context.AppsToCheck = Undefined;
			Context.SignAlgorithms = DigitalSignatureInternalClientServer.AppsRelevantAlgorithms();
			Context.DataType = "Certificate";
		ElsIf TypeOf(Context.AppsToCheck) = Type("BinaryData")
			Or TypeOf(Context.AppsToCheck) = Type("String") Then
			BinaryData = DigitalSignatureInternalClientServer.BinaryDataFromTheData(
				Context.AppsToCheck, "DigitalSignature.CheckCryptographyAppsInstallation");
			Context.AppsToCheck = Undefined;
			Context.DataType = DigitalSignatureInternalClientServer.DefineDataType(BinaryData);
			If Context.DataType = "Certificate" Then
				SignAlgorithm = DigitalSignatureInternalClientServer.CertificateSignAlgorithm(BinaryData);
			ElsIf Context.DataType = "Signature" Then
				SignAlgorithm = DigitalSignatureInternalClientServer.GeneratedSignAlgorithm(BinaryData);
			Else
				Raise NStr("en = 'Data to search for a cryptography application is not a certificate or a signature.';");
			EndIf;
			Context.SignAlgorithms.Add(SignAlgorithm);
		EndIf;
	EndIf;
	
	Result = DigitalSignatureInternalCached.InstalledCryptoProviders();
	
	CheckResult = New Structure("Error, CheckCompleted");
	CheckResult.Insert("Programs", New Array);
	CheckResult.Insert("IsConflictPossible", False);
	FillPropertyValues(CheckResult, Result);
	If Not CheckResult.CheckCompleted Then
		Return CheckResult;
	EndIf;
	
	DigitalSignatureInternalClientServer.DoProcessAppsCheckResult(Result.Cryptoproviders,
		CheckResult.Programs, CheckResult.IsConflictPossible, Context);
		
	Return CheckResult;
	
EndFunction

// Checks the validity of the signature and the certificate.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   CryptoManager - Undefined - get a crypto manager to check
//                          digital signatures as it was configured by the administrator.
//                        - CryptoManager - 
//
//   RawData       - BinaryData - binary data that was signed.
//                        - String         - 
//                        - String         - 
//                                           
//                        - Structure:
//                           * XMLEnvelope       - String - the signed XMLEnvelope,
//                                                         see also the XMLEnvelope function.
//                           * XMLDSigParameters - See DigitalSignature.XMLDSigParameters
//                        - Structure:
//                           * CMSParameters - See DigitalSignature.CMSParameters
//                           * Data  - String - an arbitrary string for signing,
//                                     - BinaryData - 
//
//   Signature              - BinaryData - digital signature binary data.
//                        - String         - 
//                        - String         - 
//                                           
//                        - Undefined   - 
//
//   ErrorDescription       - Null - raise an exception if an error occurs during the check.
//                        - String - 
// 
//   OnDate               - Date -
//                          
//                          
//                          
//   ResultStructure   - See DigitalSignatureClientServer.SignatureVerificationResult.
//
// Returns:
//  Boolean - 
//           
//                   
//
Function VerifySignature(CryptoManager, RawData, Signature, ErrorDescription = Null, OnDate = Undefined, ResultStructure = Undefined) Export

	CheckResult = False;
	
	RaiseException1 = ErrorDescription = Null;
	
	SourceDataToCheck = RawData;
	If TypeOf(RawData) = Type("String") And IsTempStorageURL(RawData) Then
		SourceDataToCheck = GetFromTempStorage(RawData);
	EndIf;
	
	IsXMLDSig = TypeOf(SourceDataToCheck) = Type("Structure")
		And SourceDataToCheck.Property("XMLDSigParameters");
	
	If IsXMLDSig Then
		If Not SourceDataToCheck.Property("XMLEnvelope") Then
			SourceDataToCheck = New Structure(New FixedStructure(SourceDataToCheck));
			SourceDataToCheck.Insert("XMLEnvelope", SourceDataToCheck.SOAPEnvelope);
		EndIf;
		XMLEnvelopeProperties = DigitalSignatureInternal.XMLEnvelopeProperties(
			SourceDataToCheck.XMLEnvelope, SourceDataToCheck.XMLDSigParameters, True);
		If XMLEnvelopeProperties <> Undefined
		   And ValueIsFilled(XMLEnvelopeProperties.ErrorText) Then
			ErrorDescription = XMLEnvelopeProperties.ErrorText;
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise ErrorDescription;
			EndIf;
			Return CheckResult;
		EndIf;
	EndIf;
	
	IsCMS = TypeOf(SourceDataToCheck) = Type("Structure")
		And SourceDataToCheck.Property("CMSParameters");
	
	If TypeOf(Signature) = Type("String") And IsTempStorageURL(Signature) Then
		SignatureToCheck = GetFromTempStorage(Signature);
	Else
		SignatureToCheck = Signature;
	EndIf;
	
	CryptoManagerToCheck = CryptoManager;
	
	If CryptoManagerToCheck = Undefined Then
		UseDigitalSignatureSaaS = Not IsXMLDSig And Not IsCMS
			And DigitalSignatureInternal.UseDigitalSignatureSaaS();
		
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.ShowError = RaiseException1 And Not UseDigitalSignatureSaaS;
		If TypeOf(SignatureToCheck) = Type("BinaryData") Then
			CreationParameters.SignAlgorithm =
				DigitalSignatureInternalClientServer.GeneratedSignAlgorithm(SignatureToCheck);
		ElsIf IsXMLDSig Then
			If XMLEnvelopeProperties = Undefined Then
				CertificateData = DigitalSignatureInternalClientServer.CertificateFromSOAPEnvelope(
					SourceDataToCheck.XMLEnvelope, False);
			Else
				CertificateData = Base64Value(XMLEnvelopeProperties.Certificate.CertificateValue);
			EndIf;
			
			CreationParameters.SignAlgorithm =
				DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateData);
		EndIf;
		
		CryptoManagerToCheck = DigitalSignatureInternal.CryptoManager(
			"CheckSignature", CreationParameters);
		
		If CryptoManagerToCheck = Undefined Then
			ErrorDescription = CreationParameters.ErrorDescription;
			If Not UseDigitalSignatureSaaS Then
				If ResultStructure <> Undefined Then
					FillSignatureVerificationResult(ErrorDescription, ResultStructure, True);
				EndIf;
				If RaiseException1 Then
					Raise ErrorDescription;
				EndIf;
				Return CheckResult;
			EndIf;
		EndIf;
		
	EndIf;
	
	If IsXMLDSig Then
		Try
			Result = DigitalSignatureInternal.VerifySignature(
				SourceDataToCheck.XMLEnvelope,
				SourceDataToCheck.XMLDSigParameters,
				CryptoManagerToCheck,
				XMLEnvelopeProperties);
		Except
			ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise;
			EndIf;
			Return CheckResult;
		EndTry;
		Certificate     = Result.Certificate;
		DateToVerifySignatureCertificate = Result.SigningDate;
		
		If ResultStructure <> Undefined Then
			ResultStructure.UnverifiedSignatureDate = DateToVerifySignatureCertificate;
			CertificateProperties = CertificateProperties(Certificate);
			ResultStructure.Certificate = Certificate.Unload();
			ResultStructure.Thumbprint = CertificateProperties.Thumbprint;
			ResultStructure.CertificateOwner = CertificateProperties.IssuedTo;
		EndIf;
		
	ElsIf IsCMS Then
		Try
			Result = DigitalSignatureInternal.CheckCMSSignature(
				SignatureToCheck,
				SourceDataToCheck.Data,
				SourceDataToCheck.CMSParameters,
				CryptoManagerToCheck);
		Except
			ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise;
			EndIf;
			Return CheckResult;
		EndTry;
		
		Certificate     = Result.Certificate;
		DateToVerifySignatureCertificate = Result.SigningDate;
		
		If ResultStructure <> Undefined Then
			SignatureProperties = DigitalSignatureInternal.SignaturePropertiesFromBinaryData(SignatureToCheck, False);
			CertificateProperties = CertificateProperties(Certificate);
			SignatureProperties.Certificate = Certificate.Unload();
			SignatureProperties.Thumbprint = CertificateProperties.Thumbprint;
			SignatureProperties.CertificateOwner = CertificateProperties.IssuedTo;
			FillPropertyValues(ResultStructure, SignatureProperties);
		EndIf;
		
	ElsIf CryptoManagerToCheck = Undefined
	      Or CryptoManagerToCheck = "CryptographyService" Then
		
		ModuleCryptographyService = Common.CommonModule("CryptographyService");
		
		Try
			Result = ModuleCryptographyService.VerifySignature(SignatureToCheck, SourceDataToCheck);
		Except
			ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			FillSignatureVerificationResult(ErrorDescription, ResultStructure, True);
			If RaiseException1 Then
				Raise;
			EndIf;
			Return CheckResult;
		EndTry;
		
		SignatureProperties = DigitalSignatureInternal.SignaturePropertiesFromBinaryData(SignatureToCheck, True);
		If ResultStructure <> Undefined Then
			FillPropertyValues(ResultStructure, SignatureProperties);
		EndIf;
		
		If Not SignatureProperties.Success Then
			ErrorDescription = SignatureProperties.ErrorText;
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise ErrorDescription;
			EndIf;
			Return CheckResult;
		EndIf;
		
		If SignatureProperties.Certificate = Undefined Then
			ErrorDescription = NStr("en = 'The certificate does not exist in signature data.';");
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise ErrorDescription;
			EndIf;
			Return CheckResult;
		EndIf;
		
		If Not Result Then
			ErrorDescription = DigitalSignatureInternalClientServer.ServiceErrorTextSignatureInvalid();
			FillSignatureVerificationResult(ErrorDescription, ResultStructure);
			If RaiseException1 Then
				Raise ErrorDescription;
			EndIf;
			Return CheckResult;
		EndIf;
		
		DateToVerifySignatureCertificate = DigitalSignatureInternalClientServer.DateToVerifySignatureCertificate(SignatureProperties);
		If Not ValueIsFilled(DateToVerifySignatureCertificate) Then
			DateToVerifySignatureCertificate = OnDate;
		EndIf;
	Else
		Certificate = Undefined;
		
		SignatureVerificationError = "";
		Try
			CryptoManagerToCheck.VerifySignature(SourceDataToCheck, SignatureToCheck, Certificate);
		Except
			SignatureVerificationError = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		EndTry;
		
		If CommonSettings().AvailableAdvancedSignature Then
			SignatureProperties = DigitalSignatureInternal.SignaturePropertiesReadByCryptoManager(
				SignatureToCheck, CryptoManagerToCheck, False);
		Else
			SignatureProperties = DigitalSignatureInternal.SignaturePropertiesFromBinaryData(SignatureToCheck, False);
		EndIf;
		
		If ResultStructure <> Undefined Then
			FillPropertyValues(ResultStructure, SignatureProperties);
			If DigitalSignatureInternalClientServer.IsCertificateExists(Certificate) Then
				CertificateProperties = CertificateProperties(Certificate);
				ResultStructure.Certificate = Certificate.Unload();
				ResultStructure.Thumbprint = CertificateProperties.Thumbprint;
				ResultStructure.CertificateOwner = CertificateProperties.IssuedTo;
			EndIf;
		EndIf;
		
		If Not IsBlankString(SignatureVerificationError) Then
			ErrorDescription = SignatureVerificationError;
			FillSignatureVerificationResult(ErrorDescription, ResultStructure, IsSignatureVerificationRequired(ErrorDescription, ResultStructure));
			If RaiseException1 Then
				Raise ErrorDescription;
			EndIf;
			Return CheckResult;
		EndIf;
		
		DateToVerifySignatureCertificate = DigitalSignatureInternalClientServer.DateToVerifySignatureCertificate(SignatureProperties);
		If Not ValueIsFilled(DateToVerifySignatureCertificate) Then
			DateToVerifySignatureCertificate = OnDate;
		EndIf;
		
	EndIf;
	
	If RaiseException1 Then
		ErrorDescription = Null;
	EndIf;
	
	AdditionalParameters = DigitalSignatureInternal.AdditionalCertificateVerificationParameters();
	AdditionalParameters.ToVerifySignature = True;
		
	CertificateVerificationResult = DigitalSignatureInternal.CheckCertificate(
		CryptoManagerToCheck, Certificate, ErrorDescription, DateToVerifySignatureCertificate, AdditionalParameters);
		
	CertificateRevoked = IsSignatureCertificateRevoked(ErrorDescription, ResultStructure);
	If Not CertificateRevoked Then
		FillSignatureVerificationResult(CertificateVerificationResult, ResultStructure, IsSignatureVerificationRequired(ErrorDescription, ResultStructure));
	Else
		FillSignatureVerificationResult(CertificateVerificationResult, ResultStructure, False, True);
	EndIf;
	
	Return CertificateVerificationResult;
	
EndFunction

// Checks the crypto certificate validity.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   CryptoManager - Undefined - get the crypto manager automatically.
//                        - CryptoManager - 
//
//   Certificate           - CryptoCertificate - a certificate.
//                        - BinaryData - binary data of the certificate.
//                        - String - 
//
//   ErrorDescription       - Null - raise an exception if an error occurs during the check.
//                        - String - 
//
//   OnDate               - Date - check the certificate on the specified date.
//                          If parameter is not specified or a blank date is specified,
//                          check on the current session date.
//
// Returns:
//  Boolean - 
//           
//
Function CheckCertificate(CryptoManager, Certificate, ErrorDescription = Null, OnDate = Undefined) Export
	
	Return DigitalSignatureInternal.CheckCertificate(CryptoManager, Certificate, ErrorDescription, OnDate);
	
EndFunction

// Finds a certificate on the computer by a thumbprint string.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   Thumbprint              - String - a Base64 coded certificate thumbprint.
//   InPersonalStorageOnly - Boolean - if True, search in the personal storage, otherwise, search everywhere.
//
// Returns:
//   CryptoCertificate - 
//   
//
Function GetCertificateByThumbprint(Thumbprint, InPersonalStorageOnly) Export
	
	Return DigitalSignatureInternal.GetCertificateByThumbprint(Thumbprint, InPersonalStorageOnly);
	
EndFunction

// Populates the DigitalSignatureAndEncryptionApplications catalog. For example, during an infobase update.
// Supports only 1C:Enterprise tools (CryptoManager).
//
// Bundled with ViPNet and CryptoPro.
// If an application with the given name and type already exists, its properties will be updated.
// The new property values are not validated.
//
// You can use the provided application details stored in ApplicationsSettingsToSupply of the DigitalSignatureAndEncryptionApplications catalog manager module.
// 
// 
//
// Parameters:
//  ApplicationsDetails - Array - contains values of See DigitalSignature.NewApplicationDetails.
//                              Structure properties type:
//   * ApplicationName  - String - a unique application name given by its developer,
//                       for example, Signal-COM CPGOST Cryptographic Provider.
//   * ApplicationType  - Number - Number that defines the application type and complements the application name.
//                       If Name and Type of an application are specified or you need to update individual properties, then the following parameters are required.
//
//   
//   
//
//   * Presentation       - String - an application name that a user will see,
//                             for example, Signal-COM CSP (RFC 4357).
//   * SignAlgorithm     - String - a name of the signature algorithm that
//                             the specified application supports, for example, ECR3410-CP.
//   * HashAlgorithm - String - a name of the data hash algorithm that
//                             the specified application supports, for example, ENG-HASH-CP. The algorithm is used to create
//                             data on signature generation with the signing algorithm.
//   * EncryptAlgorithm  - String - a name of the encryption algorithm that the
//                             specified application supports, for example, GOST28147.
//
// Example:
//	ApplicationsDetails = New Array;
//	
//	// Filling in additional application Signal-COM CSP (RFC 4357).
//	ApplicationDetails = DigitalSignature.NewApplicationDetails();
//	ApplicationDetails.ApplicationName = Signal-COM CPGOST Cryptographic Provider;
//	ApplicationDetails.ApplicationType = 75;
//	ApplicationsDetails.Add(ApplicationDetails);
//	
//	// Modifies the proprietary ViPNet CSP algorithm.
//	ApplicationDetails = DigitalSignature.NewApplicationDetails();
//	ApplicationDetails.ApplicationName = Infotecs Cryptographic Service Provider;
//	ApplicationDetails.ApplicationType = 2;
//	ApplicationDetails.SignAlgorithm = GOST R 34.10-2001;
//	ApplicationsDetails.Add(ApplicationDetails);
//	
//	DigitalSignature.FillApplicationsList(ApplicationsDetails);
//
Procedure FillApplicationsList(ApplicationsDetails) Export
	
	SettingsToSupply = Catalogs.DigitalSignatureAndEncryptionApplications.ApplicationsSettingsToSupply();
	
	InfobaseUpdateInProgress =
		    InfobaseUpdate.InfobaseUpdateInProgress()
		Or InfobaseUpdate.IsCallFromUpdateHandler();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Programs.Ref AS Ref,
	|	Programs.ApplicationName,
	|	Programs.ApplicationType
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS Programs";
	
	Block = New DataLock;
	Block.Add("Catalog.DigitalSignatureAndEncryptionApplications");
	
	BeginTransaction();
	Try
		Block.Lock();
		Upload0 = Query.Execute().Unload();
		
		For Each ApplicationDetails In ApplicationsDetails Do
			Filter = New Structure;
			Filter.Insert("ApplicationName", ApplicationDetails.ApplicationName);
			Filter.Insert("ApplicationType", ApplicationDetails.ApplicationType);
			
			Rows = Upload0.FindRows(Filter);
			If Rows.Count() > 0 Then
				ApplicationObject = Rows[0].Ref.GetObject();
			Else
				ApplicationObject = Catalogs.DigitalSignatureAndEncryptionApplications.CreateItem();
			EndIf;
			
			UpdateValue(ApplicationObject.DeletionMark, False);
			If Not ValueIsFilled(ApplicationObject.UsageMode) Then
				UpdateValue(ApplicationObject.UsageMode, Enums.DigitalSignatureAppUsageModes.SetupDone);
			EndIf;
			
			Rows = SettingsToSupply.FindRows(Filter);
			For Each KeyAndValue In ApplicationDetails Do
				FieldName = ?(KeyAndValue.Key = "Presentation", "Description", KeyAndValue.Key);
				If KeyAndValue.Value <> Undefined Then
					UpdateValue(ApplicationObject[FieldName], KeyAndValue.Value, True);
				ElsIf Rows.Count() > 0 Then
					UpdateValue(ApplicationObject[FieldName], Rows[0][KeyAndValue.Key], True);
				EndIf;
			EndDo;
			
			If Not ApplicationObject.Modified() Then
				Continue;
			EndIf;
			
			If InfobaseUpdateInProgress Then
				InfobaseUpdate.WriteData(ApplicationObject);
			Else
				ApplicationObject.Write();
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// To use in the DigitalSignature.FillApplicationsList procedure.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//  ApplicationName - String - a name of the digital signature and encryption application.
//  ApplicationType - String - an application type.
//
// Returns:
//  Structure -  
//              
//
Function NewApplicationDetails(ApplicationName = Undefined, ApplicationType = Undefined) Export
	
	ApplicationDetails = New Structure;
	ApplicationDetails.Insert("ApplicationName", ApplicationName);
	ApplicationDetails.Insert("ApplicationType", ApplicationType);
	ApplicationDetails.Insert("Presentation");
	ApplicationDetails.Insert("SignAlgorithm");
	ApplicationDetails.Insert("HashAlgorithm");
	ApplicationDetails.Insert("EncryptAlgorithm");
	
	Return ApplicationDetails;
	
EndFunction

// See DigitalSignatureClient.XMLEnvelope.
Function XMLEnvelope(Parameters) Export
	
	Return DigitalSignatureInternalClientServer.XMLEnvelope(Parameters);
	
EndFunction

// See DigitalSignatureClient.XMLEnvelopeParameters.
Function XMLEnvelopeParameters() Export
	
	Return DigitalSignatureInternalClientServer.XMLEnvelopeParameters();
	
EndFunction

// See DigitalSignatureClient.XMLDSigParameters.
Function XMLDSigParameters() Export
	
	Return DigitalSignatureInternalClientServer.XMLDSigParameters();
	
EndFunction

// See DigitalSignatureClient.CMSParameters.
Function CMSParameters() Export
	
	Return DigitalSignatureInternalClientServer.CMSParameters();
	
EndFunction

// 
// 
// Parameters:
//  Certificate - CryptoCertificate
//  OnDate - Undefined, Date -
//  ThisVerificationSignature - Boolean -
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
//   * Warning - Structure -
//                       ** ErrorText - String
//                       ** PossibleReissue - Boolean -
//                       ** Cause - String -
//                       ** Decision - String -
//
Function ResultofCertificateAuthorityVerification(Certificate, OnDate = Undefined, ThisVerificationSignature = False) Export
	
	Return DigitalSignatureInternal.ResultofCertificateAuthorityVerification(Certificate, OnDate, ThisVerificationSignature);
	
EndFunction

#EndRegion

// Returns the availability of creating an application for
// qualified certificates issue for companies and individuals.
// It is required to hide commands using the AddCertificate
// procedure of the DigitalSignatureClient common module
// in the application creation mode.
//
// Returns:
//  Structure:
//   * ForIndividuals - Boolean
//   * ForHeadsLegalEntities - Boolean
//   * ForEmployeesLegalEntities - Boolean
//   * ForSoleProprietors - Boolean
//
Function AvailabilityOfCreatingAnApplication() Export
	
	If Metadata.CommonModules.Find("DigitalSignatureInternalLocalization") = Undefined Then
		TheApplicationIsAvailable = CommonSettings().CertificateIssueRequestAvailable;
		AvailabilityOfCreatingAnApplication = New Structure;
		AvailabilityOfCreatingAnApplication.Insert("ForIndividuals", TheApplicationIsAvailable);
		AvailabilityOfCreatingAnApplication.Insert("ForHeadsLegalEntities", TheApplicationIsAvailable);
		AvailabilityOfCreatingAnApplication.Insert("ForEmployeesLegalEntities", TheApplicationIsAvailable);
		AvailabilityOfCreatingAnApplication.Insert("ForSoleProprietors", TheApplicationIsAvailable);
		Return AvailabilityOfCreatingAnApplication;
	EndIf;
	
	ModuleDigitalSignatureInternalLocalization = Common.CommonModule("DigitalSignatureInternalLocalization");
	Return ModuleDigitalSignatureInternalLocalization.AvailabilityOfCreatingAnApplication();
	
EndFunction

#EndRegion

#Region Internal

// 
// 
// Parameters:
//  SignatureData - BinaryData
//                - String - 
// 
// Returns:
//  BinaryData - 
//
Function DEREncodedSignature(SignatureData) Export
	
	BinaryData = DigitalSignatureInternalClientServer.BinaryDataFromTheData(SignatureData,
		"DigitalSignature.DEREncodedSignature");
	
	TempFileFullName = GetTempFileName();
	BinaryData.Write(TempFileFullName);
	Text = New TextDocument;
	Text.Read(TempFileFullName);
	
	Try
		DeleteFiles(TempFileFullName);
	Except
		WriteLogEvent(
			NStr("en = 'Электронная подпись.Удаление временного файла';",
				Common.DefaultLanguageCode()),
			EventLogLevel.Error, , ,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Base64Row = Undefined;
	If Text.LineCount() > 3 And StrStartsWith(Text.GetLine(1), "-----BEGIN")
		And StrStartsWith(Text.GetLine(Text.LineCount()), "-----END") Then
		Text.DeleteLine(1);
		Text.DeleteLine(Text.LineCount());
		Base64Row = Text.GetText();
	ElsIf StrStartsWith(Text.GetLine(1), "MI") Then
		Base64Row = Text.GetText();
	EndIf;
	
	If Base64Row <> Undefined Then
		Try
			BinaryData = Base64Value(Base64Row);
		Except
			ErrorInfo = ErrorInfo();
			Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Не удалось получить данные из файла подписи по причине:
						|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
	EndIf;
	
	Return BinaryData;
	
EndFunction

// Returns the encrypted data viewability flag.
//
// Returns:
//  Boolean - 
//
Function DataDecryption() Export
	
	Return EncryptAndDecryptData()
		Or UseEncryption() And Users.RolesAvailable("DataDecryption");
		
EndFunction

// Returns the data encryption availability flag.
//
// Returns:
//  Boolean - 
//
Function EncryptAndDecryptData() Export
	
	Return UseEncryption() And Users.RolesAvailable("EncryptAndDecryptData");
	
EndFunction

// Returns the digital signature availability flag.
//
// Returns:
//  Boolean - 
//
Function AddEditDigitalSignatures() Export
	
	// ACC:515-
	// 
	Return UseDigitalSignature() And Users.RolesAvailable("AddEditDigitalSignatures");
	// ACC:515-on
	
EndFunction

// Returns the flag of manageability of certificate validity period notifications and certificate delivery reminders.
// 
//
// Returns:
//  Boolean - 
//
Function ManageAlertsCertificates() Export
	
	Return AccessRight("Update", Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates)
		Or AddEditDigitalSignatures() Or DataDecryption();
	
EndFunction


// Returns the current user settings to work with the digital signature.
//
// Returns:
//   Structure - 
//       * ActionsOnSavingWithDS - String - what to do when saving files with a digital signature:
//           Ask - show the signature selection dialog box to save a signature.
//           SaveAllSignatures - all signatures, always.
//       * PathsToDigitalSignatureAndEncryptionApplications - Map of KeyAndValue:
//           ** Key     - CatalogRef.DigitalSignatureAndEncryptionApplications - an application.
//           ** Value - String - an application path on the user computer.
//       * SignatureFilesExtension - String - an extension for DS files.
//       * EncryptedFilesExtension - String - an extension for encrypted files.
//
// See also:
//   CommonForm.DigitalSignatureAndEncryptionSettings - a location to determine these parameters and
//   their text descriptions.
//
Function PersonalSettings() Export
	
	PersonalSettings = New Structure;
	// 
	PersonalSettings.Insert("ActionsOnSavingWithDS", "Prompt");
	PersonalSettings.Insert("PathsToDigitalSignatureAndEncryptionApplications", New Map);
	PersonalSettings.Insert("SignatureFilesExtension", "p7s");
	PersonalSettings.Insert("EncryptedFilesExtension", "p7m");
	PersonalSettings.Insert("SaveCertificateWithSignature", False);
	
	SubsystemKey = DigitalSignatureInternal.SettingsStorageKey();
	
	For Each KeyAndValue In PersonalSettings Do
		SavedValue = Common.CommonSettingsStorageLoad(SubsystemKey,
			KeyAndValue.Key);
		
		If ValueIsFilled(SavedValue)
		   And TypeOf(KeyAndValue.Value) = TypeOf(SavedValue) Then
			
			PersonalSettings.Insert(KeyAndValue.Key, SavedValue);
		EndIf;
	EndDo;
	
	Return PersonalSettings;
	
EndFunction

// 
// 
// Parameters:
//  Data - BinaryData
//  Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
// 
// Returns:
//  BinaryData
//
Function Encrypt(Data, Certificate) Export
	
	If Not CommonSettings().UseEncryption Then
		Raise NStr("en = 'Encryption is not enabled in the application.';");
	EndIf;
	
	ErrorList = New Array;

	AttributesValues = Common.ObjectAttributesValues(
		Certificate, "Application, CertificateData");
	
	Application = AttributesValues.Application;
	
	Try
		CertificateBinaryData = AttributesValues.CertificateData.Get();
		CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	Except
		ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot receive the ""%1"" certificate data
			           |from the infobase due to:
			           |%2';"),
			Certificate,
			ErrorDescription);
	EndTry;
	
	CryptoManager = Undefined;
	
	If ValueIsFilled(AttributesValues.Application) Then
		
		If TypeOf(AttributesValues.Application) = DigitalSignatureInternal.ServiceProgramTypeSignatures() Then
			
			Return DigitalSignatureInternal.EncryptInCloudSignatureService(
				Data, CertificateBinaryData, AttributesValues.Application);
		
		ElsIf Application = DigitalSignatureInternal.BuiltinCryptoprovider() Then
			
			Return DigitalSignatureInternal.EncryptByBuiltInCryptoProvider(
				Data, CertificateBinaryData);
			
		ElsIf Not Common.DataSeparationEnabled()
			And (CommonSettings().GenerateDigitalSignaturesAtServer Or Common.FileInfobase())
			Then

			CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
			CreationParameters.Application = AttributesValues.Application;
			CreationParameters.ErrorDescription = "";
			CryptoManager = DigitalSignatureInternal.CryptoManager("Encryption",
				CreationParameters);

			ErrorAtServer = CreationParameters.ErrorDescription;
			If ValueIsFilled(ErrorAtServer) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot encrypt with the ""%1"" certificate:
						 |%2';"), Certificate, ErrorAtServer);
			EndIf;

			If CryptoManager = Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot encrypt with the ""%1"" certificate:
						|Cannot create a crypto manager';"), Certificate);
			EndIf;

			Try
				ResultBinaryData = DigitalSignatureInternal.Encrypt(Data, CryptoCertificate,
					CryptoManager);
				Return ResultBinaryData;
			Except
				ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot encrypt with the ""%1"" certificate:
						 |%2';"), Certificate, ErrorDescription);
			EndTry;
			
		EndIf;
		
		ErrorList.Add(NStr("en = 'Encryption on the server is unavailable.';"));

	EndIf;
	
	SignAlgorithm = DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateBinaryData);
	
	If Not Common.DataSeparationEnabled() And (CommonSettings().GenerateDigitalSignaturesAtServer
		Or Common.FileInfobase()) Then
	
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.ErrorDescription = "";
		CreationParameters.SignAlgorithm = SignAlgorithm;
			
		CryptoManager = DigitalSignatureInternal.CryptoManager("Encryption", CreationParameters);
		
		ErrorDescription = CreationParameters.ErrorDescription;
		
		If Not ValueIsFilled(ErrorDescription) Then
			
			If CryptoManager = Undefined Then
				ErrorDescription = NStr("en = 'Cannot create a crypto manager';");
			Else

				Try
					ResultBinaryData = DigitalSignatureInternal.Encrypt(Data, CryptoCertificate,
						CryptoManager);
					Return ResultBinaryData;
				Except
					ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
				EndTry;

			EndIf;
			
		EndIf;
		
		ErrorList.Add(ErrorDescription);
		
	EndIf;
	
	CanBeEncryptedInCloud = StrFind(SignAlgorithm, "GOST 34.10") <> 0;
	
	If CanBeEncryptedInCloud Then
		
		If CommonSettings().ThisistheServiceModelwithEnhancementAvailable Then
			Try
				ResultBinaryData = DigitalSignatureInternal.EncryptInCloudSignatureService(Data,
				CertificateBinaryData);
				Return ResultBinaryData;
			Except
				ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
				ErrorList.Add(ErrorDescription);
			EndTry;
		EndIf;
		
		If DigitalSignatureInternal.UseDigitalSignatureSaaS() Then
			Try
				ResultBinaryData = DigitalSignatureInternal.EncryptByBuiltInCryptoProvider(Data, CertificateBinaryData);
				Return ResultBinaryData;
			Except
				ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
				ErrorList.Add(ErrorDescription);
			EndTry;
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(ErrorList) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot encrypt with the ""%1"" certificate:
					 |%2';"), Certificate, StrConcat(ErrorList, Chars.LF));
	EndIf;

	Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot encrypt with the ""%1"" certificate';"), Certificate);
EndFunction

#Region ScheduledJobsHandlers


// Scheduled job.
Procedure ExtendSignatureValidity() Export
	
	Common.OnStartExecuteScheduledJob(
			Metadata.ScheduledJobs.ExtendSignatureValidity);
	
	If Not UseDigitalSignature() Or Not AvailableAdvancedSignature() Then
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		If Not CommonSettings().ThisistheServiceModelwithEnhancementAvailable Then
			Return;
		Else
			ServiceAccountSettings = DigitalSignatureInternal.ServiceAccountSettingsToImproveSignatures();
			If ValueIsFilled(ServiceAccountSettings.Error) Then
				Raise(ServiceAccountSettings.Error);
			EndIf;
		EndIf;
		CryptoSignatureTypeDefault = Constants.CryptoSignatureTypeDefault.Get();
		If CryptoSignatureTypeDefault <> Enums.CryptographySignatureTypes.WithTimeCAdEST Then
			DigitalSignatureInternal.ChangeRegulatoryTaskExtensionCredibilitySignatures(,False,CryptoSignatureTypeDefault);
			Return;
		EndIf;
		RequiredAddArchiveTags = False;
	Else
		RequiredAddArchiveTags = Constants.AddTimestampsAutomatically.Get();
		CryptoSignatureTypeDefault = Constants.CryptoSignatureTypeDefault.Get();
	EndIf;
	
	RequireImprovementSignatures = Constants.RefineSignaturesAutomatically.Get() = 1;
	
	If (Not RequireImprovementSignatures
		Or (CryptoSignatureTypeDefault <> Enums.CryptographySignatureTypes.WithTimeCAdEST
		And CryptoSignatureTypeDefault <> Enums.CryptographySignatureTypes.ArchivalCAdESAv3))
		And Not RequiredAddArchiveTags Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("SignatureType");
	ExecutionParameters.Insert("RequiredAddArchiveTags");
	ExecutionParameters.Insert("TimestampServersAddresses");
	ExecutionParameters.Insert("ParametersSignatureCAdEST");
	ExecutionParameters.Insert("ServiceAccountDSS");
	
	If Not Common.DataSeparationEnabled() Then
		If RequireImprovementSignatures Or RequiredAddArchiveTags Then
			TimestampServersAddresses = CommonSettings().TimestampServersAddresses;
			If TimestampServersAddresses.Count() = 0 Then
				Raise NStr("en = 'Timestamp server addresses are not specified.';");
			EndIf;
		EndIf;
		ExecutionParameters.TimestampServersAddresses = TimestampServersAddresses;
	Else
		ExecutionParameters.ServiceAccountDSS = ServiceAccountSettings.ServiceAccountDSS;
		ExecutionParameters.ParametersSignatureCAdEST = ServiceAccountSettings.ParametersSignatureCAdEST;
	EndIf;
	
	If RequireImprovementSignatures Then
		ExecutionParameters.Insert("SignatureType", CryptoSignatureTypeDefault);
	EndIf;
	ExecutionParameters.Insert("RequiredAddArchiveTags", RequiredAddArchiveTags);

	// For now, determining the initial signature type is not supported.
	If ExecutionParameters.ServiceAccountDSS = Undefined Then
		// Process unprocessed signatures with the highest priority.
		QueryOptions = New Structure;
		QueryOptions.Insert("ScheduledJob", True);
		QueryOptions.Insert("rawsignatures", True);
		DigitalSignatureInternal.ExecuteDataProcessingRegularTask(QueryOptions, ExecutionParameters);
	EndIf;
	
	If RequireImprovementSignatures
		And (CryptoSignatureTypeDefault = Enums.CryptographySignatureTypes.WithTimeCAdEST
			Or CryptoSignatureTypeDefault = Enums.CryptographySignatureTypes.ArchivalCAdESAv3) Then
		
		QueryOptions = New Structure;
		QueryOptions.Insert("ScheduledJob", True);
		QueryOptions.Insert("RequireImprovementSignatures", RequireImprovementSignatures);
		QueryOptions.Insert("RefineToType", CryptoSignatureTypeDefault);
		
		DigitalSignatureInternal.ExecuteDataProcessingRegularTask(QueryOptions, ExecutionParameters);
	EndIf;
	
	If RequiredAddArchiveTags Then
		QueryOptions = New Structure;
		QueryOptions.Insert("ScheduledJob", True);
		QueryOptions.Insert("RequiredAddArchiveTags", RequiredAddArchiveTags);
		
		DigitalSignatureInternal.ExecuteDataProcessingRegularTask(QueryOptions, ExecutionParameters);
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region Private

// Returns common settings of all users to work with the digital signature.
//
// Returns: 
//   FixedStructure - 
//     * UseDigitalSignature       - Boolean - if True, digital signatures are used.
//     * UseEncryption               - Boolean - if True, encryption is used.
//     * VerifyDigitalSignaturesOnTheServer - Boolean - if True, digital signatures and
//                                                       certificates are checked on the server.
//     * GenerateDigitalSignaturesAtServer - Boolean - if True, digital signatures are created
//                                                       on the server, and if creation failed, they are created on the client.
//
//     * ApplicationsDetailsCollection - FixedArray of See DigitalSignatureInternalCached.ApplicationDetails -
//                          information about supported cryptography applications.
//
//     * DescriptionsOfTheProgramsOnTheLink - FixedMap of KeyAndValue:
//         ** Key - CatalogRef.DigitalSignatureAndEncryptionApplications
//         ** Value - See DigitalSignatureInternalCached.ApplicationDetails
//
// See also:
//   CommonForm.DigitalSignatureAndEncryptionSettings - a location to determine these parameters and
//   their text descriptions.
//
Function CommonSettings() Export
	
	Return DigitalSignatureInternalCached.CommonSettings();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the procedure, add a Signature.
Procedure AddSignatureRows(DataObject, PropertiesSignatures, EventLogMessage)
	
	SetPrivilegedMode(True);

	SequenceNumber = 1;

	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(DigitalSignatures.SignedObject) AS LastSequenceNumber
	|FROM
	|	InformationRegister.DigitalSignatures AS DigitalSignatures
	|WHERE
	|	DigitalSignatures.SignedObject = &SignedObject";

	Query.SetParameter("SignedObject", DataObject.Ref);

	QueryResult = Query.Execute();

	SelectionDetailRecords = QueryResult.Select();

	While SelectionDetailRecords.Next() Do
		SequenceNumber = SelectionDetailRecords.LastSequenceNumber + 1;
	EndDo;

	If TypeOf(PropertiesSignatures) = Type("Array") Then
		SignaturePropertiesArray = PropertiesSignatures;
	Else
		SignaturePropertiesArray = CommonClientServer.ValueInArray(PropertiesSignatures);
	EndIf;

	For Each SignatureProperties In SignaturePropertiesArray Do

		NewRecord = InformationRegisters.DigitalSignatures.CreateRecordManager();
		
		NewSignatureProperties = DigitalSignatureClientServer.NewSignatureProperties();
		FillPropertyValues(NewSignatureProperties, SignatureProperties);
		FillPropertyValues(NewRecord, SignatureProperties, , "Signature, Certificate");

		NewRecord.SignedObject = DataObject.Ref;
		NewRecord.Signature    = New ValueStorage(SignatureProperties.Signature, New Deflation(9));
		If TypeOf(SignatureProperties.Certificate) = Type("ValueStorage") Then
			NewRecord.Certificate = SignatureProperties.Certificate;
		Else
			NewRecord.Certificate = New ValueStorage(SignatureProperties.Certificate, New Deflation(9));
		EndIf;

		NewRecord.SequenceNumber = SequenceNumber;

		If Not ValueIsFilled(NewRecord.SignatureSetBy) Then
			NewRecord.SignatureSetBy = Users.AuthorizedUser();
		EndIf;

		SignatureDate = Undefined;
		If ValueIsFilled(CommonClientServer.StructureProperty(
				SignatureProperties, "UnverifiedSignatureDate", Undefined)) Then
			SignatureDate = SignatureProperties.UnverifiedSignatureDate;
		ElsIf ValueIsFilled(NewRecord.SignatureType) Then
			SignatureDate = SigningDate(SignatureProperties.Signature);
		Else
			SignatureParameters = DigitalSignatureInternalClientServer.SignaturePropertiesFromBinaryData(
				SignatureProperties.Signature, DigitalSignatureInternal.TimeAddition());
			If ValueIsFilled(SignatureParameters.SigningDate) Then
				SignatureDate = SignatureParameters.SigningDate;
			EndIf;
			NewRecord.SignatureType = SignatureParameters.SignatureType;
		EndIf;

		If SignatureDate <> Undefined Then
			NewRecord.SignatureDate = SignatureDate;

		ElsIf Not ValueIsFilled(NewRecord.SignatureDate) Then
			NewRecord.SignatureDate = CurrentSessionDate();
		EndIf;
		
		If Not ValueIsFilled(NewRecord.SignatureID) Then
			NewRecord.SignatureID = New UUID;
		EndIf;

		EventLogMessage = DigitalSignatureInternal.SignatureInfoForEventLog(
				NewRecord.SignatureDate, SignatureProperties);

		NewRecord.Write();
		

		WriteLogEvent(
				NStr("en = 'Digital signature.Add signature';", Common.DefaultLanguageCode()),
			EventLogLevel.Information, DataObject.Metadata(), DataObject.Ref,
			EventLogMessage, EventLogEntryTransactionMode.Transactional);

		SequenceNumber = SequenceNumber + 1;
	EndDo;
	
EndProcedure

// For the delete Signature procedure.
Procedure DeleteSignatureRows(SignedObject, SequenceNumbers, EventLogMessage)
	
	HasRightsToDeleteOthersSignatures = Users.IsFullUser() 
		Or Users.RolesAvailable("RemoveDigitalSignatures");

	SetPrivilegedMode(True);

	If TypeOf(SequenceNumbers) = Type("Array") Then
		SequenceNumbersArray = SequenceNumbers;
	Else
		SequenceNumbersArray = CommonClientServer.ValueInArray(SequenceNumbers);
	EndIf;

	Query = New Query;
	
	If Common.SubsystemExists("StandardSubsystems.MachineReadablePowersAttorney") Then
		ModuleMachineReadableAuthorizationLettersOfFederalTaxServiceInternal = Common.CommonModule("MachineReadableAuthorizationLettersOfFederalTaxServiceInternal");
		Query.Text = ModuleMachineReadableAuthorizationLettersOfFederalTaxServiceInternal.QueryTextForDeletingElectronicSignatures();
	Else
		Query.Text =
			"SELECT
			|	DigitalSignatures.SequenceNumber AS SequenceNumber,
			|	DigitalSignatures.SignedObject AS SignedObject,
			|	0 AS ThereAreSignaturesOnMCHD
			|FROM
			|	InformationRegister.DigitalSignatures AS DigitalSignatures
			|WHERE
			|	DigitalSignatures.SequenceNumber IN(&SequenceNumbersArray)
			|	AND DigitalSignatures.SignedObject = &SignedObject
			|
			|ORDER BY
			|	SequenceNumber DESC";
	EndIf;

	Query.SetParameter("SequenceNumbersArray", SequenceNumbersArray);
	Query.SetParameter("SignedObject", SignedObject.Ref);

	QueryResult = Query.Execute();

	SelectionDetailRecords = QueryResult.Select();

	If SelectionDetailRecords.Count() <> SequenceNumbersArray.Count() Then
		Raise NStr("en = 'A signature row does not exist.';");
	EndIf;

	While SelectionDetailRecords.Next() Do
		RecordManager = InformationRegisters.DigitalSignatures.CreateRecordManager();
		FillPropertyValues(RecordManager, SelectionDetailRecords);

		RecordManager.Read();

		HasRights = HasRightsToDeleteOthersSignatures Or RecordManager.SignatureSetBy
			= Users.AuthorizedUser();

		SignatureProperties = New Structure;
		SignatureProperties.Insert("Certificate", RecordManager.Certificate.Get());
		SignatureProperties.Insert("CertificateOwner", RecordManager.CertificateOwner);

		EventLogMessage = DigitalSignatureInternal.SignatureInfoForEventLog(
			RecordManager.SignatureDate, SignatureProperties);

		If HasRights Then
			RecordManager.Delete();
		Else
			Raise NStr("en = 'Insufficient rights to delete the signature.';");
		EndIf;
		
		If SelectionDetailRecords.ThereAreSignaturesOnMCHD > 0 Then
			ModuleMachineReadableAuthorizationLettersOfFederalTaxServiceInternal.DeleteMachineReadableSignatureAuthorizationLetter(
				SignedObject.Ref, SelectionDetailRecords.SignatureID);
		EndIf;

		WriteLogEvent(
		NStr("en = 'Digital signature.Delete signature';", Common.DefaultLanguageCode()),
			EventLogLevel.Information, SignedObject.Metadata(), SignedObject.Ref,
			EventLogMessage, EventLogEntryTransactionMode.Transactional);

	EndDo;
	
EndProcedure

// For the DeleteSignature procedure.
Procedure RefreshSignaturesNumbering(SignedObject)
	
	SetPrivilegedMode(True);
	
	SignedWithDS = False;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.DigitalSignatures");
	LockItem.SetValue("SignedObject", SignedObject.Ref);
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		RecordSet = InformationRegisters.DigitalSignatures.CreateRecordSet();
		RecordSet.Filter.SignedObject.Set(SignedObject.Ref);
		RecordSet.Read();
		
		SequenceNumber = 1;
		For Each ObjectDigitalSignature In RecordSet Do
			ObjectDigitalSignature.SequenceNumber = SequenceNumber;
			SequenceNumber = SequenceNumber + 1;
			SignedWithDS = True;
		EndDo;
		
		If SignedObject.SignedWithDS <> SignedWithDS Then
			SignedObject.SignedWithDS = SignedWithDS;
		EndIf;
		
		RecordSet.Write(True);
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SetPrivilegedMode(False);
	
EndProcedure

// For the WriteCertificateToCatalog procedure.
Procedure UpdateValue(PreviousValue2, NewValue, SkipNotDefinedValues = False)
	
	If NewValue = Undefined And SkipNotDefinedValues Then
		Return;
	EndIf;
	
	If PreviousValue2 <> NewValue Then
		PreviousValue2 = NewValue;
	EndIf;
	
EndProcedure

// For the WriteCertificateToCatalog procedure.
// 
// Parameters:
//  User - CatalogRef.Users - a user
//  Users - CatalogTabularSection.DigitalSignatureAndEncryptionKeysCertificates.Users - users
//
Procedure AddAUserToTheCertificate(User, Users)
	
	If Users.Find(User, "User") = Undefined Then
		Users.Add().User = User;
	EndIf;
	
EndProcedure

Procedure CheckParameterObject(Object, ProcedureName, RefsOnly = False)
	
	CommonClientServer.CheckParameter(ProcedureName, "Object", Object,
		DigitalSignatureInternalCached.OwnersTypes(RefsOnly));
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.CheckFileProcessed(Object, ProcedureName);
	EndIf;
	
EndProcedure

Procedure FillSignatureVerificationResult(
	Result, ResultStructure = Undefined, IsVerificationRequired = Undefined, CertificateRevoked = False)
	
	If ResultStructure <> Undefined Then
				
		ResultStructure.Result = Result;
		
		If Result = True Then
			ResultStructure.SignatureCorrect = True;
			ResultStructure.IsVerificationRequired = False;
			Return;
		EndIf;
		
		If IsVerificationRequired <> Undefined Then
			ResultStructure.IsVerificationRequired = IsVerificationRequired;
		EndIf;
		
		If ResultStructure.IsVerificationRequired = False Then
			
			If CertificateRevoked Then
				ResultStructure.Result = DigitalSignatureInternalClientServer.ErrorTextForRevokedSignatureCertificate(
					ResultStructure);
			EndIf;
			ResultStructure.CertificateRevoked = CertificateRevoked;
			ResultStructure.IsVerificationRequired = IsVerificationRequired;
			
			ResultStructure.SignatureCorrect = False;
		EndIf;
		
	EndIf;
	
EndProcedure

Function IsSignatureVerificationRequired(ErrorDescription, ResultStructure)
	
	IsVerificationRequired = Undefined;
	If ValueIsFilled(ErrorDescription) And ResultStructure <> Undefined Then
		ClassifierError = DigitalSignatureInternal.ClassifierError(ErrorDescription, True);
		If ClassifierError <> Undefined Then
			IsVerificationRequired = ClassifierError.IsCheckRequired;
		EndIf;
	EndIf;
	
	Return IsVerificationRequired;
	
EndFunction

Function IsSignatureCertificateRevoked(ErrorDescription, ResultStructure)
	
	CertificateRevoked = False;
	If ValueIsFilled(ErrorDescription) And ResultStructure <> Undefined Then
		ClassifierError = DigitalSignatureInternal.ClassifierError(ErrorDescription, True);
		If ClassifierError <> Undefined Then
			CertificateRevoked = ClassifierError.CertificateRevoked;
		EndIf;
	EndIf;
	
	Return CertificateRevoked;
	
EndFunction

#EndRegion