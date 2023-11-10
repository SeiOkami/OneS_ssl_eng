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

// Signs data, returns a signature, and adds the signature to an object, if specified.
//
// A common method to process property values with the NotifyDescription type in the DataDetails parameter.
//  When processing a notification, the parameter structure is passed to it.
//  This structure always has a Notification property of the NotifyDescription type, which needs to be processed to continue.
//  In addition, the structure always has the DataDetails property received when calling the procedure.
//  When calling a notification, the structure must be passed as a value. If an error occurs during the asynchronous
//  execution, add the ErrorDetails property of String type to this structure.
// 
// Parameters:
//  DataDetails - Structure:
//    * Operation             - String - a title of the data signing form, for example, File signing.
//    * DataTitle      - String - a title of an item or a data set, for example, File.
//    * NotifyOnCompletion  - Boolean - (optional) - if False, no notification of successful
//                           completion of the operation will be shown to present the data indicated next to the title.
//    * ShowComment  - Boolean - (optional) - allows adding a comment in the
//                           data signing form. False if not specified.
//    * CertificatesFilter    - Array - (optional) - contains references to the catalog items.
//                           DigitalSignatureAndEncryptionCertificates that can be selected
//                           by the user. The filter locks the ability to select other certificates
//                           from the personal storage.
//                           - Structure:
//                             * Organization - DefinedType.Organization - contains a reference to the company,
//                                 by which the filter will be set in the list of user certificates.
//    * NoConfirmation     - Boolean - (Optional) - Skip user confirmation if
//                           there is only one certificate in the CertificatesFilter property and:
//                           a) Either the certificate has the flag "Protect digital signature application with password",
//                           b) Or a user has memorized the certificate password for the time of the session,
//                           c) Or a password has been set earlier by the SetCertificatePassword method.
//                           If an error occurs upon signing, the form will be opened with the ability to enter the password.
//                           The ShowComment parameter is ignored.
//    * BeforeExecute     - NotifyDescription -
//                           
//                           
//                           
//                           
//                           
//                           
//    * ExecuteAtServer   - Undefined
//                           - Boolean - 
//                           
//                           
//                           
//                           
//                           
//    * AdditionalActionParameters - Arbitrary - (optional) - if specified, it is passed
//                           to the server to the BeforeOperationStart procedure of the
//                           DigitalSignatureOverridable common module as InputParameters.
//    * OperationContext     - Undefined -
//                           
//                            
//                           
//                           
//                           
//                           - Arbitrary - 
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//    * StopExecution - Arbitrary - if the property exists and an
//                           error occurs during asynchronous execution, execution stops without displaying the operation form or with closing this form
//                           if it was opened.
//
//    Option 1.
//    * Data              - BinaryData - data for signing.
//                          - String - 
//                          - NotifyDescription - 
//                          
//                          
//                          - Structure:
//                             * XMLEnvelope       - See DigitalSignatureClient.XMLEnvelope
//                             * XMLDSigParameters - See DigitalSignatureClient.XMLDSigParameters
//                          - Structure:
//                             * CMSParameters - See DigitalSignatureClient.CMSParameters
//                             * Data  - String - an arbitrary string for signing,
//                                       - BinaryData - 
//    * Object              - AnyRef - (optional) - a reference to an object to be signed.
//                          If not specified, a signature is not required.
//                          - NotifyDescription - 
//                          
//                          
//                          
//                          
//    * ObjectVersion       - String - (optional) - an object data version to check and
//                          lock the object before adding the signature.
//    * Presentation       - AnyRef - (optional), if the parameter is not specified,
//                                  the presentation is calculated by the Object property value.
//                          - String
//                          - Structure:
//                             ** Value      - AnyRef
//                                              - NotifyDescription - 
//                             ** Presentation - String - - a value presentation.
//    Option 2.
//    * DataSet         - Array - structures with properties described in Option 1.
//    * SetPresentation - String - presentations of several data set items, for example, Files (%1).
//                          To this presentation, the number of items is filled in parameter %1.
//                          Click the hyperlink to open the list.
//                          If the data set has 1 item, value
//                          in the Presentation property of the DataSet property is used. If not specified,
//                          the presentation is calculated by the Object property value of a data set item.
//    * PresentationsList - ValueList
//                          - Array - 
//                          
//                          
//                          
//
//  Form - ClientApplicationForm - a form, from which you need to get an UUID
//                                that will be used when locking an object.
//        - UUID - 
//                                
//        - Undefined     - 
//
//  ResultProcessing - NotifyDescription -
//     
//     
//     
//               
//     
//     
//               
//               
//               
//     
//         
//         
//         
//     
//     
//               
//                       See DigitalSignatureClientServer.NewSignatureProperties
//               
//                       
//  SignatureParameters - See NewSignatureType
//
Procedure Sign(DataDetails, Form = Undefined, ResultProcessing = Undefined, SignatureParameters = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDetails", DataDetails);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("RegularlyCompletion",
		DigitalSignatureInternalClient, ClientParameters);
	
	If DataDetails.Property("OperationContext")
	   And TypeOf(DataDetails.OperationContext) = Type("ClientApplicationForm") Then
		
		DigitalSignatureInternalClient.ExtendStoringOperationContext(DataDetails);
		FormNameBeginning = "Catalog.DigitalSignatureAndEncryptionKeysCertificates.Form.";
		
		If DataDetails.OperationContext.FormName = FormNameBeginning + "DataSigning" Then
			DataDetails.OperationContext.PerformSigning(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
		If DataDetails.OperationContext.FormName = FormNameBeginning + "DataDecryption" Then
			ClientParameters.Insert("SpecifiedContextOfOtherOperation");
		EndIf;
	EndIf;
	
	ServerParameters1 = New Structure;
	ServerParameters1.Insert("Operation",            NStr("en = 'Data signing';"));
	ServerParameters1.Insert("DataTitle",     NStr("en = 'Data';"));
	ServerParameters1.Insert("ShowComment", False);
	ServerParameters1.Insert("CertificatesFilter");
	ServerParameters1.Insert("ExecuteAtServer");
	ServerParameters1.Insert("AdditionalActionParameters");
	ServerParameters1.Insert("NotifyOfCertificateAboutToExpire", True);
	FillPropertyValues(ServerParameters1, DataDetails);
	
	ServerParameters1.Insert("SignatureType", SignatureParameters);
	
	DigitalSignatureInternalClient.OpenNewForm("DataSigning",
		ClientParameters, ServerParameters1, CompletionProcessing);
	
EndProcedure

// 
// 
// 
// Parameters:
//  SignatureType - EnumRef.CryptographySignatureTypes
// 
// Returns:
//  Structure:
//   * SignatureTypes - Array -
//   * Visible - Boolean -
//   * Enabled - Boolean -
//   * ChoosingAuthorizationLetter - Boolean -
//
Function NewSignatureType(SignatureType = Undefined) Export
	
	Structure = New Structure;
	Structure.Insert("SignatureTypes", New Array);
	Structure.Insert("Visible", False);
	Structure.Insert("Enabled", False);
	Structure.Insert("ChoosingAuthorizationLetter", False);
	
	If ValueIsFilled(SignatureType) Then
		Structure.SignatureTypes.Add(SignatureType);
	EndIf;
	
	Return Structure;
	
EndFunction

// It prompts the user to select signature files to add to the object, and adds them.
//
// A common method to process property values with the NotifyDescription type in the DataDetails parameter.
//  When processing a notification, the parameter structure is passed to it.
//  This structure always has a Notification property of the NotifyDescription type, which needs to be processed to continue.
//  In addition, the structure always has the DataDetails property received when calling the procedure.
//  When calling a notification, the structure must be passed as a value. If an error occurs during the asynchronous
//  execution, add the ErrorDetails property of String type to this structure.
// 
// Parameters:
//  DataDetails - Structure:
//    * DataTitle      - String - a data item title, for example, File.
//    * ShowComment  - Boolean - (optional) - allows adding a comment in the
//                             data signing form. False if not specified.
//    * Object               - AnyRef - (optional) - a reference to an object to be signed.
//                           - NotifyDescription - 
//                             
//                             
//    * ObjectVersion        - String - (optional) - an object data version to check and
//                             lock the object before adding the signature.
//    * Presentation        - AnyRef
//                           - String - 
//                             
//    * Data               - BinaryData - (optional) - data to check the signature.
//                           - String - 
//                           - NotifyDescription - 
//                             
//
//  Form - ClientApplicationForm - a form, from which you need to get an UUID
//        that will be used when locking an object.
//        - UUID - 
//        
//        - Undefined - 
//
//  ResultProcessing - NotifyDescription -
//     Required for non-standard result processing, for example, if the Object and / or Form parameter is not specified.
//     Required for non-standard result processing, for example, if the Object and / or Form parameter is not specified.
//     # Success - Boolean - True if everything is successfully completed.
//     #Cancel - Boolean - True if the user canceled the operation interactively.
//     # Signatures - Array - an array that contains the following elements:
//       ## SignatureProperties - String - a temporary storage address that contains the structure described below.
//                          = Structure - a detailed signature description:
//           ### Comment - String - a comment if it was entered upon signing.
//           ### SignatureSetBy - CatalogRef.Users - a user who
//                                   signed the infobase object.
//           ### Comment - String - a comment if it was entered upon signing.
//           ### SignatureFileName - String - a name of the file from which the signature was added.
//           ### SignatureDate - Date - a signature date. It makes sense
//                                   when the date cannot be extracted from signature data. If the date is not
//                                   specified or blank, the current session date is used.
//           ### SignatureValidationDate - Date - a date of signature check after adding from file.
//                                   If the Data property is not specified in the DataDetails parameter,
//                                   it returns a blank date.
//           ### SignatureCorrect - Boolean - a signature check result after adding from file.
//                                    If the Data property is not specified in the DataDetails parameter,
//                                    it returns False.
//
//           Derivative properties:
//           ### Certificate - BinaryData - contains export of the certificate
//                                   that was used for signing (it is in the signature).
//           ### Thumbprint - String - a certificate thumbprint in the Base64 string format.
//           ### CertificateOwner - String - a subject presentation received from the certificate binary data.
//
Procedure AddSignatureFromFile(DataDetails, Form = Undefined, ResultProcessing = Undefined) Export
	
	DataDetails.Insert("Success", False);
	
	ServerParameters1 = New Structure;
	ServerParameters1.Insert("DataTitle", NStr("en = 'Data';"));
	ServerParameters1.Insert("ShowComment", False);
	FillPropertyValues(ServerParameters1, DataDetails);
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDetails",      DataDetails);
	ClientParameters.Insert("Form",               Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	DigitalSignatureInternalClient.SetDataPresentation(ClientParameters, ServerParameters1);
	
	AdditionForm = OpenForm("CommonForm.AddDigitalSignatureFromFile", ServerParameters1,,,,,
		New NotifyDescription("RegularlyCompletion", DigitalSignatureInternalClient, ClientParameters));
	
	If AdditionForm = Undefined Then
		If ResultProcessing <> Undefined Then
			ExecuteNotifyProcessing(ResultProcessing, DataDetails);
		EndIf;
		Return;
	EndIf;
	
	AdditionForm.ClientParameters = ClientParameters;
	
	Context = New Structure;
	Context.Insert("ResultProcessing", ResultProcessing);
	Context.Insert("AdditionForm", AdditionForm);
	Context.Insert("CheckCryptoManagerAtClient", True);
	Context.Insert("DataDetails", DataDetails);
	
	If (VerifyDigitalSignaturesOnTheServer()
		Or GenerateDigitalSignaturesAtServer())
		And Not ValueIsFilled(AdditionForm.CryptographyManagerOnServerErrorDescription) Then
		
		Context.CheckCryptoManagerAtClient = False;
		DigitalSignatureInternalClient.AddSignatureFromFileAfterCreateCryptoManager(
			Undefined, Context);
	Else
		
		CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
		CreationParameters.ShowError = Undefined;
		
		DigitalSignatureInternalClient.CreateCryptoManager(
			New NotifyDescription("AddSignatureFromFileAfterCreateCryptoManager",
				DigitalSignatureInternalClient, Context),
			"", CreationParameters);
			
	EndIf;
	
EndProcedure

// It prompts the user to select signatures to save together with the object data.
//
// A common method to process property values with the NotifyDescription type in the DataDetails parameter.
//  When processing a notification, the parameter structure is passed to it.
//  This structure always has a Notification property of the NotifyDescription type, which needs to be processed to continue.
//  In addition, the structure always has the DataDetails property received when calling the procedure.
//  When calling a notification, the structure must be passed as a value. If an error occurs during the asynchronous
//  execution, add the ErrorDetails property of String type to this structure.
// 
// Parameters:
//  DataDetails - Structure:
//    * DataTitle      - String - a data item title, for example, File.
//    * ShowComment  - Boolean - (optional) - allows adding a comment in the
//                           data signing form. False if not specified.
//    * Presentation        - AnyRef
//                           - String - 
//                           
//    * Object               - AnyRef - a reference to object, from which you need to get the signature list.
//                           - String - 
//                           
//    * Data               - NotifyDescription - a handler for saving data and receiving the full file
//                           name with a path (after saving it), returned in the FullFileName property
//                           of the String type for saving digital signatures (see the common approach above).
//                           If the file system extension is not attached, return
//                           file name without a path.
//                           If the property will not be inserted or filled, it means canceling
//                           the continuation, and ResultProcessing with the False result will be called.
//
//                           For a batch request for permissions from the web client user to save the file of data
//                           and signatures, you need to insert the PermissionsProcessingRequest parameter of the NotifyDescription type.
//                           The procedure will get a structure with the following properties:
//                              # Calls               - Array - with details of calls to save signatures.
//                              # ContinuationHandler - NotifyDescription - a procedure to be executed
//                                                     after requesting permissions, the procedure parameters are the same as
//                                                     the notification for the BeginRequestingUserPermission method has.
//                                                     If the permission is not received, everything is canceled.
//
//  ResultProcessing - NotifyDescription -
//     The parameter is passed to the result of the type: Boolean - True if everything was successful.
//
Procedure SaveDataWithSignature(DataDetails, ResultProcessing = Undefined) Export
	
	DigitalSignatureInternalClient.SaveDataWithSignature(DataDetails, ResultProcessing);
	
EndProcedure

// Checks the validity of the signature and the certificate..
// The certificate is always checked on the server if the administrator
// had set the check of digital signatures on the server.
//
// Parameters:
//   Notification           - NotifyDescription -
//             
//             
//             
//             See DigitalSignatureClientServer.SignatureVerificationResult
//             
//   RawData       - BinaryData - binary data that was signed.
//                          Mathematical check is executed on the client side, even when
//                          the administrator has set the check of digital signatures on the server
//                          if the crypto manager is specified or it was received without an error.
//                          Performance and security increase when the signature is checked
//                          in the decrypted file (it will not be passed to the server).
//                        - String - 
//                        - Structure:
//                           * XMLEnvelope       - String - the signed XMLEnvelope,
//                                                         see also the XMLEnvelope function.
//                           * XMLDSigParameters - See DigitalSignatureClient.XMLDSigParameters
//                        - Structure:
//                           * CMSParameters - See DigitalSignatureClient.CMSParameters
//                           * Data  - String - an arbitrary string for signing,
//                                     - BinaryData - 
//   Signature              - BinaryData - digital signature binary data.
//                        - String         - 
//                        - Undefined   - 
//   CryptoManager - Undefined - get crypto manager by default
//                          (manager of the first application in the list, as configured by the administrator).
//                        - CryptoManager - 
//   OnDate               - Date -
//                          
//                          
//                          
//   CheckParameters    - See SignatureVerificationParameters
//                        
//
Procedure VerifySignature(Notification, RawData, Signature,
	CryptoManager = Undefined,
	OnDate = Undefined,
	CheckParameters = Undefined) Export
	
	DigitalSignatureInternalClient.VerifySignature(
		Notification, RawData, Signature, CryptoManager, OnDate, CheckParameters);
	
EndProcedure

// 
// 
// Returns:
//  Structure:
//   * ShowCryptoManagerCreationError - Boolean - 
//              
//   * ResultAsStructure - See DigitalSignatureClientServer.SignatureVerificationResult
//
Function SignatureVerificationParameters() Export
	
	Structure = New Structure;
	Structure.Insert("ShowCryptoManagerCreationError", True);
	Structure.Insert("ResultAsStructure", False);
	Return Structure;
	
EndFunction

// Encrypts data, returns encryption certificates, and adds them to an object, if specified.
// 
// A common method to process property values with the NotifyDescription type in the DataDetails parameter.
//  When processing a notification, the parameter structure is passed to it.
//  This structure always has a Notification property of the NotifyDescription type, which needs to be processed to continue.
//  In addition, the structure always has the DataDetails property received when calling the procedure.
//  When calling a notification, the structure must be passed as a value. If an error occurs during the asynchronous
//  execution, add the ErrorDetails property of String type to this structure.
// 
// Parameters:
//  DataDetails - Structure:
//    * Operation             - String - a data encryption form title, for example, File encryption.
//    * DataTitle      - String - a title of an item or a data set, for example, File.
//    * NotifyOnCompletion  - Boolean - (optional) - if False, no notification of successful
//                           completion of the operation will be shown to present the data indicated next to the title.
//    * CertificatesSet    - String - (optional) the address of temporary storage that contains an array, described below.
//                           - Array - 
//                           
//                           
//                           - AnyRef - 
//    * ChangeSet        - Boolean - if True and CertificatesSet is specified and contains only references
//                           to certificates, you will be able to change the content of certificates.
//    * NoConfirmation     - Boolean - (optional) - skip user confirmation
//                           if the CertificatesFilter property is specified.
//    * ExecuteAtServer   - Undefined
//                           - Boolean - 
//                           
//                           
//                           
//                           
//                           
//    * OperationContext     - Undefined - (optional) - if specified, the property will be
//                           set to a specific value of an arbitrary type, which allows you to
//                           execute an action with the same encryption certificates again (the user
//                           is not asked to confirm the action).
//                           - Arbitrary - 
//                           
//                           
//                           
//                           
//    * StopExecution - Arbitrary - if the property exists and an
//                           error occurs during asynchronous execution, execution stops without displaying the operation form or with closing this form
//                           if it was opened.
//
//    Option 1.
//    * Data                - BinaryData - data to encrypt.
//                            - String - 
//                            - NotifyDescription - 
//                            
//    * ResultPlacement  - Undefined - (optional) - describes where to place the encrypted data.
//                            If it is not specified or Undefined, use the ResultProcessing parameter.
//                            - NotifyDescription - 
//                            
//                            
//                            
//                            
//    * Object                - AnyRef - (optional) - a reference to the object that needs to be encrypted.
//                            f not specified, encryption certificates are not required.
//    * ObjectVersion         - String - (optional) - version of the object data to check and
//                            lock the object before adding the encryption certificates.
//    * Presentation       - AnyRef - (optional), if the parameter is not specified,
//                                  the presentation is calculated by the Object property value.
//                          - String
//                          - Structure:
//                             ** Value      - AnyRef
//                                              - NotifyDescription - 
//                             ** Presentation - String - - a value presentation.
//
//    Option 2.
//    * DataSet           - Array - structures with properties described in Option 1.
//    * SetPresentation   - String - presentations of several data set items, for example, Files (%1).
//                            To this presentation, the number of items is filled in parameter %1.
//                            Click the hyperlink to open the list.
//                            If the data set has 1 item, value
//                            in the Presentation property of the DataSet property is used. If not specified,
//                            the presentation is calculated by the Object property value of a data set item.
//    * PresentationsList   - ValueList
//                            - Array - 
//                            
//                            
//                            
//
//  Form - ClientApplicationForm  - a form to provide a UUID used to
//        store encrypted data to a temporary storage.
//        - UUID - 
//        
//        - Undefined      - 
//
//  ResultProcessing - NotifyDescription -
//     It is required for non-standard result processing, if the Form and/or the ResultPlacement parameter is not specified.
//     The result gets the DataDetails parameter, to which the following properties are added in case of a success:
//     # Success - Boolean - True if everything is successfully completed. If Success = False, the partial completion
//               is defined by having the SignatureProperties property. If there is, the step is completed.
//     # Cancel - Boolean - True if the user canceled the operation interactively.
//     # EncryptionCertificates - String - a temporary storage address that contains the array described below.
//                             = Array - placed before starting encryption and after this it is not changed.
//                                ## Value - Structure
//                                   ### Thumbprint - String - a certificate thumbprint in the Base64 string format.
//                                   ### Presentation - String - a saved subject presentation
//                                                       got from certificate binary data.
//                                   ### Certificate - BinaryData - contains export of the certificate
//                                                       that was used for encryption.
//     # EncryptedData - BinaryData - an encryption result.
//                             Check the property in the DataSet parameter when passing it.
//                           = String - the address of temporary storage that contains the encryption result.
//
Procedure Encrypt(DataDetails, Form = Undefined, ResultProcessing = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDetails", DataDetails);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("RegularlyCompletion",
		DigitalSignatureInternalClient, ClientParameters);
	
	If DataDetails.Property("OperationContext")
	   And TypeOf(DataDetails.OperationContext) = Type("ClientApplicationForm") Then
		
		DigitalSignatureInternalClient.ExtendStoringOperationContext(DataDetails);
		FormNameBeginning = "Catalog.DigitalSignatureAndEncryptionKeysCertificates.Form.";
		
		If DataDetails.OperationContext.FormName = FormNameBeginning + "DataEncryption" Then
			DataDetails.OperationContext.ExecuteEncryption(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
	EndIf;
	
	ServerParameters1 = New Structure;
	ServerParameters1.Insert("Operation",            NStr("en = 'Data encryption';"));
	ServerParameters1.Insert("DataTitle",     NStr("en = 'Data';"));
	ServerParameters1.Insert("CertificatesSet");
	ServerParameters1.Insert("ChangeSet");
	ServerParameters1.Insert("ExecuteAtServer");
	FillPropertyValues(ServerParameters1, DataDetails);
	
	DigitalSignatureInternalClient.OpenNewForm("DataEncryption",
		ClientParameters, ServerParameters1, CompletionProcessing);
	
EndProcedure

// Decrypts data, returns it and places into object if it is specified.
// 
// A common method to process property values with the NotifyDescription type in the DataDetails parameter.
//  When processing a notification, the parameter structure is passed to it.
//  This structure always has a Notification property of the NotifyDescription type, which needs to be processed to continue.
//  In addition, the structure always has the DataDetails property received when calling the procedure.
//  When calling a notification, the structure must be passed as a value. If an error occurs during the asynchronous
//  execution, add the ErrorDetails property of String type to this structure.
// 
// Parameters:
//  DataDetails - Structure:
//    * Operation             - String - a data decryption form title, for example, File decryption.
//    * DataTitle      - String - a title of an item or a data set, for example, File.
//    * NotifyOnCompletion  - Boolean - (optional) - if False, no notification of successful
//                           completion of the operation will be shown to present the data indicated next to the title.
//    * CertificatesFilter    - Array - (optional) - contains references to the catalog items.
//                           DigitalSignatureAndEncryptionCertificates that can be selected
//                           by the user. The filter locks the ability to select other certificates
//                           from the personal storage.
//    * NoConfirmation     - Boolean - (Optional)
//                           - Skip user confirmation if CertificatesFilter property has one certificate and:
//                           a) Either the certificate has the flag "Protect digital signature application with password",
//                           b) Or a user has memorized the certificate password for the time of the session,
//                           c) Or a password has been set earlier by the SetCertificatePassword method.
//                           If an error occurs during decryption, a form opens where the user can enter the password.
//                           
//    * IsAuthentication    - Boolean - (optional) - if True, show the OK button
//                           instead of the Decrypt button. And some labels will be corrected.
//                           Besides, the ReportCompletion parameter is set to False.
//    * BeforeExecute     - NotifyDescription - (optional) - details of the additional
//                           data preparation handler, after selecting the certificate, by which the data will be decrypted.
//                           In this handler you can fill the Data parameter if it is required.
//                           DataDetails already has
//                           the SelectedCertificate parameter in the moment of call (see below). Consider the common approach (see above).
//    * ExecuteAtServer   - Undefined
//                           - Boolean - 
//                           
//                           
//                           
//                           
//                           
//    * AdditionalActionParameters - Arbitrary - (optional) - if specified, it is passed
//                           to the server to the BeforeOperationStart common module procedure.
//                           DigitalSignatureOverridable common module as InputParameters.
//    * OperationContext     - Undefined -
//                           
//                            
//                           
//                           
//                           
//                           - Arbitrary - 
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//                           
//    * StopExecution - Arbitrary - if the property exists and an
//                           error occurs during asynchronous execution, execution stops without displaying the operation form or with closing this form
//                           if it was opened.
// 
//    Option 1.
//    * Data                - BinaryData - data to decrypt.
//                            - String - 
//                            - NotifyDescription - 
//                            
//                            
//    * ResultPlacement  - Undefined - (optional) - describes where to place the decrypted data.
//                            If it is not specified or Undefined, use the ResultProcessing parameter.
//                            - NotifyDescription - 
//                            
//                            
//                            
//                            
//    * Object                - AnyRef - (optional) - a reference to the object to be decrypted,
//                            as well as clear records from the EncryptionCertificates
//                            information register after decryption is completed successfully.
//                            If not specified, you do not need to get certificates from an object and clear them.
//                            - String - 
//                              
//                                 
//                                 
//                                                     
//                                 
//                                                     
//    * Presentation       - AnyRef - (optional), if the parameter is not specified,
//                                  the presentation is calculated by the Object property value.
//                          - String
//                          - Structure:
//                             ** Value      - AnyRef
//                                              - NotifyDescription - 
//                             ** Presentation - String - - a value presentation.
// 
//    Option 2.
//    * DataSet           - Array - structures with properties described in Option 1.
//    * SetPresentation   - String - presentations of several data set items, for example, Files (%1).
//                            To this presentation, the number of items is filled in parameter %1.
//                            Click the hyperlink to open the list.
//                            If the data set has 1 item, value
//                            in the Presentation property of the DataSet property is used. If not specified,
//                            the presentation is calculated by the Object property value of a data set item.
//    * PresentationsList   - ValueList
//                            - Array - 
//                            
//                            
//                            
//    * EncryptionCertificates - Array - (optional) values, like the Object parameter has. It is used
//                            to extract encryption certificate lists for items that are specified
//                            in the PresentationsList parameter (the order needs to correspond to it).
//                            When specified, the Object parameter is not used.
//
//  Form - ClientApplicationForm - a form to provide a UUID used to
//        store decrypted data to a temporary storage.
//        - UUID - 
//        
//        - Undefined - 
//
//  ResultProcessing - NotifyDescription -
//     It is required for non-standard result processing, if the Form and/or the ResultPlacement parameter is not specified.
//     The result gets the DataDetails parameter, to which the following properties are added in case of a success:
//     # Success - Boolean - True if everything is successfully completed. If Success = False, the partial completion
//               is defined by having the SignatureProperties property. If there is, the step is completed.
//     # Cancel - Boolean - True if the user canceled the operation interactively.
//     # SelectedCertificate - Structure - contains the following certificate properties:
//         ## Ref - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - a reference to the certificate.
//         ## Thumbprint - String - a certificate thumbprint in the Base64 string format.
//         ## Data - String - an address of a temporary storage that contains certificate binary data.
//     # DecryptedData - BinaryData - a decryption result.
//                               Check the property in the DataSet parameter when passing it.
//                            = String - an address of a temporary storage that contains the decryption result.
//
Procedure Decrypt(DataDetails, Form = Undefined, ResultProcessing = Undefined) Export
	
	ClientParameters = New Structure;
	ClientParameters.Insert("DataDetails", DataDetails);
	ClientParameters.Insert("Form", Form);
	ClientParameters.Insert("ResultProcessing", ResultProcessing);
	
	CompletionProcessing = New NotifyDescription("RegularlyCompletion",
		DigitalSignatureInternalClient, ClientParameters);
	
	If DataDetails.Property("OperationContext")
	   And TypeOf(DataDetails.OperationContext) = Type("ClientApplicationForm") Then
		
		DigitalSignatureInternalClient.ExtendStoringOperationContext(DataDetails);
		FormNameBeginning = "Catalog.DigitalSignatureAndEncryptionKeysCertificates.Form.";
		
		If DataDetails.OperationContext.FormName = FormNameBeginning + "DataDecryption" Then
			DataDetails.OperationContext.ExecuteDecryption(ClientParameters, CompletionProcessing);
			Return;
		EndIf;
		If DataDetails.OperationContext.FormName = FormNameBeginning + "DataSigning" Then
			ClientParameters.Insert("SpecifiedContextOfOtherOperation");
		EndIf;
	EndIf;
	
	ServerParameters1 = New Structure;
	ServerParameters1.Insert("Operation",            NStr("en = 'Data decryption';"));
	ServerParameters1.Insert("DataTitle",     NStr("en = 'Data';"));
	ServerParameters1.Insert("CertificatesFilter");
	ServerParameters1.Insert("EncryptionCertificates");
	ServerParameters1.Insert("IsAuthentication");
	ServerParameters1.Insert("ExecuteAtServer");
	ServerParameters1.Insert("AdditionalActionParameters");
	ServerParameters1.Insert("AllowRememberPassword");
	FillPropertyValues(ServerParameters1, DataDetails);
	
	If DataDetails.Property("Data") Then
		If TypeOf(ServerParameters1.EncryptionCertificates) <> Type("Array")
		   And DataDetails.Property("Object") Then
			
			ServerParameters1.Insert("EncryptionCertificates", DataDetails.Object);
		EndIf;
		
	ElsIf TypeOf(ServerParameters1.EncryptionCertificates) <> Type("Array") Then
		
		ServerParameters1.Insert("EncryptionCertificates", New Array);
		For Each DataElement In DataDetails.DataSet Do
			If DataElement.Property("Object") Then
				ServerParameters1.EncryptionCertificates.Add(DataElement.Object);
			Else
				ServerParameters1.EncryptionCertificates.Add(Undefined);
			EndIf;
		EndDo;
	EndIf;
	
	DigitalSignatureInternalClient.OpenNewForm("DataDecryption",
		ClientParameters, ServerParameters1, CompletionProcessing);
	
EndProcedure

// Upgrades the signatures to the given type.
//
// Parameters:
//  DataDetails - Structure:
//    * SignatureType          - EnumRef.CryptographySignatureTypes - Signature type to upgrade to.
//                           If the actual SignatureType is the same or higher, no actions are performed.
//                           
//    * AddArchiveTimestamp - Boolean - If True and SignatureType and actual SignatureType are archived, add a timestamp.
//                           
//   
//    * Signature             - BinaryData - Signature data.
//                          - String - 
//                          - Structure:
//                             ** SignedObject - AnyRef - Reference to the object whose signatures will be upgraded.
//                             ** SequenceNumber - Number - a signature sequence number.
//                                                - Array - 
//                                                - Undefined - 
//                             ** Signature - BinaryData - (Optional) Signature data.
//                                        Applicable if the signature sequence number is numeric.
//                                        - String - 
//                                                         
//                          - Array of BinaryData
//                          - Array of String - 
//                          - Array of Structure - 
//   
//    * Presentation       - AnyRef - (Optional) If not specified, the presentation is generated using the Object and SequenceNumber property values.
//                                  
//                          - String
//                          - Structure:
//                             ** Value      - AnyRef
//                                              - NotifyDescription - 
//                             ** Presentation - String - Value presentation.
//                          - ValueList
//                          - Array - 
//                          
//                          
//                          
//
//  Form - ClientApplicationForm - a form, from which you need to get an UUID
//                                that will be used when locking an object.
//        - UUID - 
//                                
//
//  AbortArrayProcessingOnError  - Boolean -
//  ShouldIgnoreCertificateValidityPeriod - Boolean -
//                                                 
//
//  
//     
//     
//     
//               
//     
//     
//                          
//                                     
//                          
//                          
//                          
//                                
//                          
//                                
//                          See DigitalSignatureClientServer.NewSignatureProperties
//                             
//                          
//                           
//                        
//
Procedure EnhanceSignature(DataDetails, Form, ResultProcessing = Undefined,
	AbortArrayProcessingOnError = True, ShouldIgnoreCertificateValidityPeriod = False) Export
	
	Context = New Structure;
	Context.Insert("ResultProcessing", ResultProcessing);
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("DataDetails",      DataDetails);
	If TypeOf(Form) = Type("ClientApplicationForm") Then
		ExecutionParameters.Insert("FormIdentifier", Form.UUID);
	Else
		ExecutionParameters.Insert("FormIdentifier", Form);
	EndIf;
	ExecutionParameters.Insert("AbortArrayProcessingOnError",  AbortArrayProcessingOnError);
	ExecutionParameters.Insert("ShouldIgnoreCertificateValidityPeriod", ShouldIgnoreCertificateValidityPeriod);
		
	Context.Insert("ExecutionParameters", ExecutionParameters);
	
	DigitalSignatureInternalClient.EnhanceSignature(Context);

EndProcedure

// Checks the crypto certificate validity.
//
// Parameters:
//   Notification           - NotifyDescription - a notification about the execution result of the following types:
//             = Boolean       - True if the check is completed successfully.
//             = String       - a description of a certificate check error.
//             = Undefined - cannot get the crypto manager (because it is not specified).
//
//   Certificate           - CryptoCertificate - a certificate.
//                        - BinaryData - binary data of the certificate.
//                        - String - 
//
//   CryptoManager - Undefined - get the crypto manager automatically.
//                        - CryptoManager - 
//                          
//
//   OnDate               - Date - check the certificate on the specified date.
//                          If parameter is not specified or a blank date is specified,
//                          check on the current session date.
//
Procedure CheckCertificate(Notification, Certificate, CryptoManager = Undefined, OnDate = Undefined) Export
	
	DigitalSignatureInternalClient.CheckCertificate(Notification, Certificate, CryptoManager, OnDate);
	
EndProcedure

// Opens the CertificateCheck form and returns the check result.
//
// Parameters:
//  Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - a certificate being checked.
//
//  AdditionalParameters - Undefined - an ordinary certificate check.
//                          - Structure - 
//    * FormOwner          - ClientApplicationForm - another form.
//    * FormCaption         - String - if specified, it replaces the form title.
//    * CheckOnSelection      - Boolean - if True, the Check button will be called
//                             "Check and continue", and the Close button will be called "Cancel".
//    * ResultProcessing    - NotifyDescription - it is called immediately after the check,
//                             Result.ChecksPassed (see below) is passed to the procedure with the initial value False.
//                             If True is not set in the CheckOnChoose mode,
//                             the form will not be closed after a return from the notification procedure and
//                             a warning that it is impossible to continue will be shown.
//    * NoConfirmation       - Boolean - if it is set to True and you have a password,
//                             the check will be executed immediately without opening the form.
//                             If the mode is CheckOnChoose and the ResultProcessing parameter is set,
//                             the form will not open if the ChecksPassed parameter is set to True.
//    * CompletionProcessing    - NotifyDescription - it is called when the form is closed,
//                             the Undefined or the ChecksPassed value are passed as its result (see below).
//    * OperationContext       - Arbitrary - if you pass the context returned by the Sign procedure,
//                             Decrypt procedure, the password entered for the certificate can be used
//                             as if the password had been saved for the duration of session.
//                             When recalling the WithoutConfirmation parameter is considered equal to True.
//    * DontShowResults - Boolean - if a parameter takes the True value and the OperationContext parameter
//                             contains the context of the previous operation, the check results will not be shown
//                             to the user.
//    * Result              - Undefined - a check was never performed.
//                             - Structure - 
//         * ChecksPassed  - Boolean - a return value. Is set in the procedure of the ResultProcessing parameter.
//         * ChecksAtServer - Undefined - a check was not executed on the server:
//                             - Structure - 
//         * ChecksAtClient - Structure:
//             * CertificateExists  - Boolean
//                                   - Undefined - 
//                                     
//                                     
//                                     
//             * CertificateData   - Boolean
//                                   - Undefined - 
//             * ProgramExists    - Boolean
//                                   - Undefined - 
//             * Signing          - Boolean
//                                   - Undefined - 
//             * CheckSignature     - Boolean
//                                   - Undefined - 
//             * Encryption          - Boolean
//                                   - Undefined - 
//             * Details         - Boolean
//                                   - Undefined - 
//             
//                                     
//                                     
//             
//                                    
//
//    * AdditionalChecksParameters - Arbitrary - parameters that are passed to the procedure named
//        OnCreateFormCertificateCheck of the DigitalSignatureOverridable common module.
//
Procedure CheckCatalogCertificate(Certificate, AdditionalParameters = Undefined) Export
	
	DigitalSignatureInternalClient.CheckCatalogCertificate(Certificate, AdditionalParameters);
	
EndProcedure

// Shows the dialog box for installing an extension to use digital signature and encryption.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   WithoutQuestion - Boolean - if True is set, the question will not be shown.
//                It is required if the user clicked Install extension.
//
//   ResultHandler - NotifyDescription - details of the procedure that gets the ExtensionInstalled
//      selection result of the following types:
//       = Boolean
//          True - The user confirmed the installation, the extension was successfully attached after installation.
//          False   - The user confirmed the installation, but the extension could not be attached after the installation.
//       = Undefined - The user refused to install.
//
//   QueryText     - String - a question text.
//   QuestionTitle - String - a question title.
//
//
Procedure InstallExtension(WithoutQuestion, ResultHandler = Undefined, QueryText = "", QuestionTitle = "") Export
	
	DigitalSignatureInternalClient.InstallExtension(WithoutQuestion, ResultHandler, QueryText, QuestionTitle);
	
EndProcedure

// Opens or activates the form of setting digital signature and encryption.
// 
// Parameters:
//  Page - String - allowed rows are Certificates, Settings, and Applications.
//
Procedure OpenDigitalSignatureAndEncryptionSettings(Page = "Certificates") Export
	
	FormParameters = New Structure;
	If Page = "Certificates" Then
		FormParameters.Insert("ShowCertificatesPage");
		
	ElsIf Page = "Settings" Then
		FormParameters.Insert("ShowSettingsPage");
		
	ElsIf Page = "Programs" Then
		FormParameters.Insert("ShowApplicationsPage");
	EndIf;
	
	Form = OpenForm("CommonForm.DigitalSignatureAndEncryptionSettings", FormParameters);
	
	// When re-opening the form, additional actions are required.
	If Page = "Certificates" Then
		Form.Items.Pages.CurrentPage = Form.Items.CertificatesPage;
		
	ElsIf Page = "Settings" Then
		Form.Items.Pages.CurrentPage = Form.Items.SettingsPage;
		
	ElsIf Page = "Programs" Then
		Form.Items.Pages.CurrentPage = Form.Items.ApplicationPage;
	EndIf;
	
	Form.Open();
	
EndProcedure

// Opens a reference to the "How to work with digital signature and encryption applications" ITS section.
//
Procedure OpenInstructionOfWorkWithApplications() Export
	
	DigitalSignatureInternalClient.OpenInstructionOfWorkWithApplications();
	
EndProcedure

// 
// 
//
// Parameters:
//   SectionName - String - a reference to the error in the instruction.
//
Procedure OpenInstructionOnTypicalProblemsOnWorkWithApplications(SectionName = "") Export
	
	URL = "";
	DigitalSignatureClientServerLocalization.OnDefiningRefToAppsTroubleshootingGuide(
		URL, SectionName);
	
	If Not IsBlankString(URL) Then
		FileSystemClient.OpenURL(URL);
	EndIf;
	
EndProcedure

// Returns the date extracted from the signature binary data or Undefined.
//
// Parameters:
//  Notification - NotifyDescription - it is called to pass the return value of the types:
//                 = Date - a successfully extracted signature date,
//                 = Undefined - cannot extract date from signature data.
//  Signature - BinaryData - signature data to extract a date from.
//  CastToSessionTimeZone - Boolean - cast the universal time to the session time.
//
Procedure SigningDate(Notification, Signature, CastToSessionTimeZone = True) Export
	
	SigningDate = DigitalSignatureInternalClientServer.SigningDateUniversal(Signature);
	
	If SigningDate = Undefined Then
		ExecuteNotifyProcessing(Notification, Undefined);
		Return;
	EndIf;
	
	If CastToSessionTimeZone Then
		SigningDate = SigningDate + (CommonClient.SessionDate()
			- CommonClient.UniversalDate());
	EndIf;
	
	ExecuteNotifyProcessing(Notification, SigningDate);
	
EndProcedure
	
// Returns a certificate presentation in the directory, generated
// from the subject presentation (IssuedTo) and certificate expiration date.
//
// Parameters:
//   Certificate   - CryptoCertificate - a crypto certificate.
//
// Returns:
//  String - 
//
Function CertificatePresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificatePresentation(Certificate,
		DigitalSignatureInternalClient.TimeAddition());
	
EndFunction

// Returns the certificate subject presentation (IssuedTo).
//
// Parameters:
//   Certificate - CryptoCertificate - a crypto certificate.
//
// Returns:
//   String   - 
//              
//              
//              
//
Function SubjectPresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.SubjectPresentation(Certificate);
	
EndFunction

// Returns a presentation of the certificate issuer (IssuedBy).
//
// Parameters:
//   Certificate - CryptoCertificate - a crypto certificate.
//
// Returns:
//   String - 
//            
//
Function IssuerPresentation(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.IssuerPresentation(Certificate);
	
EndFunction

// Returns main certificate properties as a structure.
//
// Parameters:
//   Certificate - CryptoCertificate - a crypto certificate.
//
// Returns:
//   Structure:
//    * Thumbprint      - String - a certificate thumbprint in the Base64 string format.
//    * SerialNumber  - BinaryData - a property of the SerialNumber certificate.
//    * Presentation  - See DigitalSignatureClient.CertificatePresentation.
//    * IssuedTo      - See DigitalSignatureClient.SubjectPresentation.
//    * IssuedBy       - See DigitalSignatureClient.IssuerPresentation.
//    * StartDate     - Date   - a StartDate certificate property in the session time zone.
//    * EndDate  - Date   - an EndDate certificate property in the session time zone.
//    * Purpose     - String - an extended property details of the EKU certificate.
//    * Signing     - Boolean - the UseToSign certificate property.
//    * Encryption     - Boolean - the UseToEncrypt certificate property.
//
Function CertificateProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateProperties(Certificate,
		DigitalSignatureInternalClient.TimeAddition());
	
EndFunction

// Returns properties of the crypto certificate subject.
//
// Parameters:
//   Certificate - CryptoCertificate - a certificate to return the subject properties for.
//
// Returns:
//  Structure - 
//     * CommonName         - String - (64) - it is extracted from the CN field - it is an alias of the certificate authority.
//                          LE: depends on type of the last DS owner.
//                              a) Company name
//                              b) Automated system name
//                              c) other displayed name as the information system requires.
//                          Individual: FullName.
//                        - Undefined - 
//
//     * Country           - String - (2) - it is extracted from the C field - the two-symbol country code
//                          according to ISO 3166-1:1997 (GOST 7.67-2003).
//                        - Undefined - 
//
//     * State           - String - (128) - it is extracted from the S field - the RF region name.
//                          LE - by the location address.
//                          Individual - by the registration address.
//                        - Undefined - 
//
//     * Locality  - String - (128) - extracted from the L field - a locality description.
//                          LE - by the location address.
//                          Individual - by the registration address.
//                        - Undefined - 
//
//     * Street            - String - (128) - it is extracted from the Street field - the street, house, and office names.
//                          LE - by the location address.
//                          Individual - by the registration address.
//                        - Undefined - 
//
//     * Organization      - String - (64) - extracted from the O field.
//                          LE - a full or short company name.
//                        - Undefined - 
//
//     * Department    - String - (64) - it is extracted from the OU field.
//                          LE - in case of issuing the DS to official responsible - the company department.
//                              Department is a territorial structural unit of a large company,
//                              which is not usually filled in the certificate.
//                        - Undefined - 
//
//     * Email - String - (128) - extracted from the E field (an email address).
//                          LE - an official responsible email address.
//                          Individual - email address of an individual.
//                        - Undefined - 
//
//     * JobTitle        - String - (64) - extracted from the T field.
//                          LE - in case of issuing the DS to an official responsible - their position.
//                        - Undefined - 
//
//     * OGRN             - String - (64) - extracted from the OGRN field.
//                          LE - a company's OGRN.
//                        - Undefined - 
//
//     * OGRNIE           - String - (64) - extracted from the OGRNIP field.
//                          IE - an OGRN of an individual entrepreneur.
//                        - Undefined - 
//
//     * SNILS            - String - (64) - extracted from the SNILS field.
//                          Individual - a SNILS number
//                          LE - not required, in case of issuing the DS to official responsible - their SNILS number.
//                        - Undefined - 
//
//     * TIN              - String - (12) - extracted from the INN field.
//                          Individual - a TIN.
//                          IE - a TIN.
//                          LE - not required, but can be filled in in old certificates.
//                        - Undefined - 
//
//     * TINEntity            - String - (10) - extracted from the INNLE field.
//                          LE - required, but may be absent in old certificates.
//                        - Undefined - 
//
//     * LastName          - String - (64) - extracted from the SN field (if the field is filled in).
//                        - Undefined - 
//
//     * Name              - String - (64) - extracted from the GN field (if the field is filled in).
//                        - Undefined - 
//
//     * MiddleName         - String - (64) - extracted from the GN field (if the field is filled in).
//                        - Undefined - 
//
Function CertificateSubjectProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateSubjectProperties(Certificate);
	
EndFunction

// Returns properties of the crypto certificate issuer. 
//
// Parameters:
//   Certificate - CryptoCertificate - a certificate to return the issuer properties for.
//
// Returns:
//  Structure - 
//              
//     * CommonName         - String - (64) - it is extracted from the CN field - it is an alias of the certificate authority.
//                        - Undefined - 
//
//     * Country           - String - (2) - it is extracted from the C field - the two-symbol country code
//                          according to ISO 3166-1:1997 (GOST 7.67-2003).
//                        - Undefined - 
//
//     * State           - String - (128) - it is extracted from the S field - it is the RF region name
//                          by the location address of hardware and software complex certificate authority.
//                        - Undefined - 
//
//     * Locality  - String - (128) - it is extracted from the L field - the description of the locality
//                          by the location address of hardware and software complex certificate authority.
//                        - Undefined - 
//
//     * Street            - String - (128) - it is extracted from the S field - it is the name of the street, house, and office
//                          by the location address of hardware and software complex certificate authority.
//                        - Undefined - 
//
//     * Organization      - String - (64) - a full or short name of the company is extracted from the O field.
//                        - Undefined - 
//
//     * Department    - String - (64) - extracted from the OU field (a company department).
//                            Department is a territorial structural unit of a large company,
//                            which is not usually filled in the certificate.
//                        - Undefined - 
//
//     * Email - String - (128) - it is extracted from the E field. It is an email address of the certificate authority.
//                        - Undefined - 
//
//     * OGRN             - String - (13) - extracted from the OGRN field - a certificate authority's OGRN.
//                        - Undefined - 
//
//     * TIN              - String - (12) - extracted from the INN field - a TIN of the certificate authority company.
//                          LE - not required, but may be present in old certificates.
//                        - Undefined - 
//
//     * TINEntity            - String - (10) - extracted from the INNLE field - a TIN of the certificate authority company.
//                          LE - required, but may be absent in old certificates.
//                        - Undefined - 
//
Function CertificateIssuerProperties(Certificate) Export
	
	Return DigitalSignatureInternalClientServer.CertificateIssuerProperties(Certificate);
	
EndFunction

// 
// 
// 
// 
//
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
//
// 
// 
//  
//   
//   
//  
//   
//   
//  
//   
//   
//  
//  
//   
//  
//   
//
// 
// 
// 
//   
//
// Parameters:
//  Parameters - See DigitalSignatureClient.XMLEnvelopeParameters
//            - Undefined - use default parameters.
//
// Returns:
//  String
//
// Example:
//	EnvelopeParameters = DigitalSignatureClient.XMLEnvelopeParameters();
//	EnvelopeParameters.Option = "furs.mark.crpt.ru_v1";
//	EnvelopeParameters.XMLMessage =
//	"    <getProductDetailsResponse xmlns=""http://warehouse.example.com/ws"">
//	|      <getProductDetailsResult>
//	|       <productID>12345</productID>
//	|       <productName>Faceted glass</productName>
//	|       <description>Faceted glass. 250 мл.</description>
//	|       <price>9.95</price>
//	|       <currency>
//	|         <code>840</code>
//	|         <alpha3>USD</alpha3>
//	|         <sign>$</sign>
//	|         <name>US dollar</name>
//	|         <accuracy>2</accuracy>
//	|       </currency>
//	|       <inStock>true</inStock>
//	|     </getProductDetailsResult>
//	|   </getProductDetailsResponse>";
//	
//	XMLEnvelope = DigitalSignatureClient.XMLEnvelope(Parameters);
//
Function XMLEnvelope(Parameters = Undefined) Export
	
	Return DigitalSignatureInternalClientServer.XMLEnvelope(Parameters);
	
EndFunction

// Returns the parameters that can be set for the XML envelope.
//
// Returns:
//  Structure:
//   * Variant - String - an option of the standard XML template for exchange with a service:
//                 "furs.mark.crpt.ru_v1" (initial value) or "dmdk.goznak.ru_v1".
//                 Other formats are possible if they meet the requirements
//                 specified in the details of the XMLEnvelope function.
//
//   * XMLMessage - String - a message in the XML format that is inserted into the template.
//                             If it is not filled in, the %MessageXML% parameter remains.
//
Function XMLEnvelopeParameters() Export
	
	Return DigitalSignatureInternalClientServer.XMLEnvelopeParameters();
	
EndFunction

// Generates a property structure for configuring the non-standard processing
// of the XML envelope and signing and hashing algorithms.
//
// It is recommended that you do not fill in the XPathSignedInfo and the XPathTagToSign parameters,
// the XPathSignedInfo parameter is calculated using canonicalization algorithms,
// and the XPathTagToSign parameter is calculated by reference
// in the URI attribute of the SignedInfo.Reference item of the XML envelope.
// The parameters are left for backward compatibility. If specified, it works the same way:
// the parameters are not extracted from the XML envelope and they are not controlled, while
// the envelope must contain canonicalization algorithms and have certificate placement
// items, as in the "furs.mark.crpt.ru_v1" envelope option.
//
// It is not required to fill in the algorithms for using certificates
// with public key algorithms GOST 94, GOST 2001, GOST 2012/256, and GOST 2012/512.
// Signing and hashing algorithms are calculated using the public key algorithm
// extracted from the certificate that is used for signing. First
// by the passed table, then if the table is not filled in or mapping
// is not found, by the internal mapping table (recommended).
//
// Returns:
//  Structure:
//   * XPathSignedInfo         - String - by default: "(//. | //@* | //namespace::*)[ancestor-or-self::*[local-name()='SignedInfo']]".
//   * XPathTagToSign   - String - by default: "(//. | //@* | //namespace::*)[ancestor-or-self::soap:Body]".
//
//   * OIDOfPublicKeyAlgorithm - String - for example, "1.2.643.2.2.19" + Chars.LF + "1.2.643.7.1.1.1.1" + …
//   * SIgnatureAlgorithmName        - String - for example, "GOST R 34.10-2001" + Chars.LF + "GOST R 34.11-2012" + …
//   * SignatureAlgorithmOID        - String - for example, 1.2.643.2.2.3" + Chars.LF + "1.2.643.7.1.1.3.2" + …
//   * HashingAlgorithmName    - String - for example, "GOST R 34.11-94" + Chars.LF + "GOST R 34.11-12" + …
//   * HashingAlgorithmOID    - String - for example, "1.2.643.2.2.9" + Chars.LF + "1.2.643.7.1.1.2.2" + …
//   * SignAlgorithm            - String - for example, "http://www.w3.org/2001/04/xmldsig-more#gostr34102001-gostr3411"
//                                      + Chars.LF +
//                                      "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34102012-gostr34112012-256" + …
//   * HashAlgorithm        - String - for example, "http://www.w3.org/2001/04/xmldsig-more#gostr3411"+ Chars.LF +
//                                      "urn:ietf:params:xml:ns:cpxmlsec:algorithms:gostr34112012-256" + …
//
Function XMLDSigParameters() Export
	
	Return DigitalSignatureInternalClientServer.XMLDSigParameters();
	
EndFunction

// Generates property structures to sign data in the CMS format.
// 
// Returns:
//  Structure:
//   * SignatureType                    - String - "CAdES-BES" - other options are not used yet.
//   * DetachedAddIn                  - Boolean - False (default) - include data in a signature container.
//                                   True - do not include data in a signature container.
//   * IncludeCertificatesInSignature - CryptoCertificateIncludeMode - determines the length of the chain of
//                                   certificates included in the signature. The IncludeChainWithoutRoot value
//                                   is not supported and is considered equal to the IncludeWholeChain value.
//
Function CMSParameters() Export
	
	Return DigitalSignatureInternalClientServer.CMSParameters();
	
EndFunction

#Region WriteCertificateToCatalog1

// Initializes the parameters structure to add a certificate
// to the DigitalSignatureAndEncryptionKeysCertificates catalog.
// To use in the WriteCertificateToCatalog procedure.
//
// Returns:
//   Structure:
//      * Description  - String - a certificate presentation in the list.
//                      The default value is "".
//      * User  - CatalogRef.Users - a user who owns the certificate.
//                      The value is used when receiving a list of personal user certificates
//                      in the forms of signing and data encryption.
//                      The default value is Undefined.
//      * Organization   - DefinedType.Organization - a company that owns the certificate.
//                      The default value is Undefined.
//      * Application     - CatalogRef.DigitalSignatureAndEncryptionApplications - an application that
//                      is required for signature and encryption.
//                      The default value is Undefined.
//      * EnterPasswordInDigitalSignatureApplication - Boolean - Flag "Protect digital signature application with password".
//                      True is required if a certificate was installed on the computer with strong private key protection.
//                      Meaning that only a blank password is supported at 1C:Enterprise level.
//                      The password is requested by the operating system, which rejects empty passwords from 1C:Enterprise.
//                      By default, False.
//                      
//
Function CertificateRecordParameters() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Description", "");
	AdditionalParameters.Insert("User", Undefined);
	AdditionalParameters.Insert("Organization", Undefined);
	AdditionalParameters.Insert("Application", Undefined);
	AdditionalParameters.Insert("EnterPasswordInDigitalSignatureApplication", False);
	
	Return AdditionalParameters;
	
EndFunction

// Checks the certificate and if check is successful, adds a new or updates an existing certificate
// in the DigitalSignatureAndEncryptionKeysCertificates catalog. If the check fails, displays
// information about the errors that have occurred.F
// To add a certificate at the server, see DigitalSignature.WriteCertificateToCatalog.
//
// Parameters:
//   CompletionHandler - NotifyDescription - called after adding a certificate
//                           to pass the return value of the types:
//       = Undefined - an error occurred while checking or adding the certificate.
//       = CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - an added certificate.
//   Certificate              - BinaryData - certificate binary data.
//                           - String - 
//                           
//   CertificatePassword       - String - a certificate password for checking private key operations.
//   ToEncrypt           - Boolean - determines components of checks
//                           performed before adding a certificate. If the parameter takes the True value,
//                           encryption and decryption are checked, otherwise signing and signature are checked.
//   AdditionalParameters - Undefined - without additional parameters.
//                           - See CertificateRecordParameters
//
Procedure WriteCertificateToCatalog(CompletionHandler,
	Certificate,
	CertificatePassword,
	ToEncrypt = False,
	AdditionalParameters = Undefined) Export
	
	Context = New Structure;
	Context.Insert("CertificatePassword", CertificatePassword);
	Context.Insert("ToEncrypt", ToEncrypt);
	Context.Insert("AdditionalParameters", ?(AdditionalParameters = Undefined,
		CertificateRecordParameters(), AdditionalParameters));
	Context.Insert("FormCaption", ?(Context.ToEncrypt = True,
		NStr("en = 'Cannot check encryption and decryption.';"),
		NStr("en = 'Cannot check if it is digitally signed.';")));
	Context.Insert("ApplicationErrorTitle",
		DigitalSignatureInternalClientServer.CertificateAddingErrorTitle(
			?(Context.ToEncrypt = True, "Encryption", "Signing")));
		
	Context.Insert("CertificateData", Certificate);
	Context.Insert("SignAlgorithm",
		DigitalSignatureInternalClientServer.CertificateSignAlgorithm(Certificate));
		
	If TypeOf(Context.CertificateData) = Type("String")
		And IsTempStorageURL(Context.CertificateData) Then
		
		Context.CertificateData = GetFromTempStorage(Context.CertificateData);
	EndIf;
	
	If CommonSettings().VerifyDigitalSignaturesOnTheServer Then
		
		CertificateRef = DigitalSignatureInternalServerCall.WriteCertificateAfterCheck(Context);
		If CertificateRef <> Undefined Then
			ExecuteNotifyProcessing(CompletionHandler, CertificateRef);
			Return;
		EndIf;
		
	EndIf;
	
	Context.Insert("CompletionHandler", CompletionHandler);
	
	CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
	CreationParameters.ShowError = Undefined;
	CreationParameters.SignAlgorithm = Context.SignAlgorithm;
	
	DigitalSignatureInternalClient.CreateCryptoManager(
		New NotifyDescription("AddCertificateAfterCreateCryptoManager",
		DigitalSignatureInternalClient, Context), "", CreationParameters);
	
EndProcedure

#EndRegion

#Region InteractiveCertificateAddition

// Initializes a parameter structure for interactively adding a certificate.
// If the CreateApplication parameter is True and the FromPersonalStorage parameter is False, opens a new application
// for certificate issue.
// If the CreateApplication parameter is False and the FromPersonalStorage parameter is True, adds a certificate
// from the personal storage.
// If the CreateApplication parameter is True and the FromPersonalStorage parameter is True, opens a window for
// choosing certificate addition method.
// For usage in DigitalSignatureClient.AddCertificate
//
// Returns:
//   Structure:
//      * ToPersonalList      - Boolean - if the parameter takes the True value, the user attribute
//                           will be filled in by the current user, otherwise the attribute will not be filled in.
//                           The default value is False.
//      * Organization        - DefinedType.Organization - a company that owns the certificate.
//                           The default value is Undefined.
//                           In the case when the parameter is used to create an application, then the value
//                           is passed to the OnFillCompanyAttributesInApplicationForCertificate procedure
//                           of the CertificateRequestOverridable common module without change, and after the call
//                           it cast to the types of the CompanyType property.
//      * CreateRequest   - Boolean - if the parameter takes the True value, adds the ability
//                           to create a new application for certificate issue.
//                           The default value is True.
//      * FromPersonalStorage - Boolean - if the parameter takes the True value, adds the ability to
//                           select a certificate from the installed certificates in the personal storage.
//                           The default value is True.
//      * Individual     - CatalogRef - the individual for whom you need to create an application
//                           for certificate issue (when it is filled in, it has priority over the company).
//                           The default value is Undefined.
//                           The value is passed to the OnFillOwnerAttributesInApplicationForCertificate procedure
//                           of the CertificateRequestOverridable common module without change, and after the call
//                           is cast to the types of the OwnerType property.
//
Function CertificateAddingOptions() Export
	
	AddingOptions = New Structure;
	AddingOptions.Insert("ToPersonalList", False);
	AddingOptions.Insert("Organization", Undefined);
	AddingOptions.Insert("CreateRequest", True);
	AddingOptions.Insert("FromPersonalStorage", True);
	AddingOptions.Insert("Individual", Undefined);
	
	Return AddingOptions;
	
EndFunction

// Interactively adds a certificate from installed on the computer or creates an application for certificate issue.
//
// Parameters:
//   CompletionHandler - NotifyDescription - called after adding a certificate with a value of one of the types:
//      = Undefined - an error occurred while checking or adding the certificate.
//      = Structure:
//          # Ref - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - an added certificate.
//          # Added - Boolean - indicates that the certificate has been successfully added. If a certificate is added
//                      using an application for a new qualified certificate issue, the flag takes
//                      the False value until the application is executed and the certificate is installed on 
//                      the computer.
//   AddingOptions - Undefined - without additional parameters.
//                       - See DigitalSignatureClient.CertificateAddingOptions
//
// Example:
//  1) Adding a certificate from installed in the personal storage:
//  AddingOptions = DigitalSignatureClient.CertificateAddingOptions();
//  AddingOptions.CreateApplication = False;
//  DigitalSignatureClient.AddCertificate(, AddingOptions);
//  
//  2) Creation of an application for certificate issue:
//  AddingOptions = DigitalSignatureClient.CertificateAddingOptions();
//  AddingOptions.FromPersonalStorage = False;
//  DigitalSignatureClient.AddCertificate(, AddingOptions);
//  
//  3) Interactive selection of certificate addition method:
//  DigitalSignatureClient.AddCertificate();
//
Procedure ToAddCertificate(CompletionHandler = Undefined, AddingOptions = Undefined) Export
	
	If AddingOptions = Undefined Then
		AddingOptions = CertificateAddingOptions();
	EndIf;
	
	InteractiveSelectionParameters = New Structure("ToPersonalList, Organization, Individual");
	FillPropertyValues(InteractiveSelectionParameters, AddingOptions);
	
	If Not AddingOptions.CreateRequest
		And Not AddingOptions.FromPersonalStorage Then
		
		Return;
	EndIf;
	
	InteractiveSelectionParameters.Insert("HideApplication",
		AddingOptions.FromPersonalStorage And Not AddingOptions.CreateRequest);
	InteractiveSelectionParameters.Insert("CreateRequest",
		AddingOptions.CreateRequest And Not AddingOptions.FromPersonalStorage);
	
	DigitalSignatureInternalClient.ToAddCertificate(InteractiveSelectionParameters, CompletionHandler);
	
EndProcedure

#EndRegion

#Region ForCallsFromOtherSubsystems

// These procedures and functions are intended for integration with 1C:Electronic document library.

// 
//
// Parameters:
//  Notification     - NotifyDescription - a notification about the execution result of the following types:
//                   = CryptoManager - the initialized crypto manager.
//                   = String - a description of a crypto manager creation error.
//
//  Operation       - String - if it is not blank, it needs to contain one of rows that determine
//                   the operation to insert into the error description: Signing, SignatureCheck, Encryption,
//                   Decryption, CertificateCheck, and GetCertificates.
//
//  ShowError - Boolean - if True, the ApplicationCallError form will open,
//                   from which you can go to the list of installed applications
//                   in the personal settings form on the "Installed applications" page,
//                   where you can see why the application could not be used,
//                   and open the installation instructions.
//
//  Application      - Undefined -
//                   
//                 - CatalogRef.DigitalSignatureAndEncryptionApplications - 
//                   
//                 - Structure - See DigitalSignature.NewApplicationDetails.
//                 - BinaryData - 
//                 - String - 
//
Procedure CreateCryptoManager(Notification, Operation, ShowError = True, Application = Undefined) Export
	
	If TypeOf(Operation) <> Type("String") Then
		Operation = "";
	EndIf;
	
	If ShowError <> True Then
		ShowError = False;
	EndIf;
	
	CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
	CreationParameters.Application = Application;
	CreationParameters.ShowError = ShowError;
	
	DigitalSignatureInternalClient.CreateCryptoManager(Notification, Operation, CreationParameters);
	
EndProcedure

// Finds a certificate on the computer by a thumbprint string.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   Notification           - NotifyDescription - a notification about the execution result of the following types:
//     = CryptoCertificate - a found certificate.
//     = Undefined           - the certificate does not exist in the storage.
//     = String                 - a text of the crypto manager creation error (or other error).
//
//   Thumbprint              - String - a Base64 coded certificate thumbprint.
//   InPersonalStorageOnly - Boolean - if True, search in the personal storage, otherwise, search everywhere.
//   ShowError         - Boolean - if False, hide the error text to be returned.
//
Procedure GetCertificateByThumbprint(Notification, Thumbprint, InPersonalStorageOnly, ShowError = True) Export
	
	If TypeOf(ShowError) <> Type("Boolean") Then
		ShowError = True;
	EndIf;
	
	DigitalSignatureInternalClient.GetCertificateByThumbprint(Notification,
		Thumbprint, InPersonalStorageOnly, ShowError);
	
EndProcedure

// Gets certificate thumbprints of the OS user on the computer.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//  Notification     - NotifyDescription - it is called to pass the return value of the following types:
//                     = Map - Key - a thumbprint in the Base64 string format, and Value is True,
//                     = String - a text of the crypto manager creation error (or other error).
//
//  OnlyPersonal   - Boolean - if False, recipient certificates are added to the personal certificates.
//
//  ShowError - Boolean - show the crypto manager creation error.
//
Procedure GetCertificatesThumbprints(Notification, OnlyPersonal, ShowError = True) Export
	
	DigitalSignatureInternalClient.GetCertificatesThumbprints(Notification, OnlyPersonal, ShowError);
	
EndProcedure

//  The procedure checks whether the certificate is in the personal storage, its expiration date whether the current user
//  is specified in the certificate or no one is specified, and also that the application for working with the certificate is filled.
//
//  Parameters:
//   Notification - NotifyDescription - a notification with the result of the type:
//     = Array Of Structure:
//            # Ref - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - a reference to the certificate.
//            # Description - String - a certificate presentation in the list.
//            # Thumbprint    - String - a certificate thumbprint in the Base64 string format.
//            # Data       - String - an address of a temporary storage that contains certificate binary data.
//            # Company  - TypeToDefine.Company - a company that owns the certificate.
//   Filter - Undefined - use default values for the structure properties that are specified below.
//         - Structure:
//                 * CheckExpirationDate - Boolean - if there is no property, it is True.
//                 * CertificatesWithFilledProgramOnly - Boolean - if there is no property, it is True.
//                         In the query to the catalog, only those certificates are selected
//                         that have the Application field filled in.
//                 * IncludeCertificatesWithBlankUser - Boolean - if there is no property, it is True.
//                         In the query to the catalog, not only those certificates are selected, for which the User field
//                         matches the current user, but also those for which it is not filled.
//                 * Organization - DefinedType.Organization - if there is a property and it is filled in,
//                         only certificates with the Company field that matches
//                         the specified one are selected in the catalog query.
//
Procedure FindValidPersonalCertificates(Notification, Filter = Undefined) Export
	
	FilterTypesArray = New Array;
	FilterTypesArray.Add(Type("Structure"));
	FilterTypesArray.Add(Type("Undefined"));
	
	CommonClientServer.CheckParameter("DigitalSignatureClient.FindValidPersonalCertificates",
		"Filter", Filter, FilterTypesArray);
	
	CommonClientServer.CheckParameter("DigitalSignatureClient.FindValidPersonalCertificates",
		"Notification", Notification, Type("NotifyDescription"));
	
	DigitalSignatureInternalClient.FindValidPersonalCertificates(Notification, Filter);
	
EndProcedure

// Searches for installed applications both on the client and on the server.
// For operations using platform tools only (CryptoManager).
//
// Parameters:
//   Notification - NotifyDescription - a notification with the result of the type:
//     = Array - with the Structure values with the properties like the DigitalSignature.NewApplicationDetails
//                and with the additional properties:
//       # Set                 = Boolean - if True, it is set either at the client or at the server.
//       # CheckResultAtClient - String - if a string is blank, then it is set, otherwise, error details.
//       # CheckResultAtServer - String - if a string is blank, then it is set, otherwise, error details.
//                                     = Undefined - the check was not performed.
//
//   ApplicationsDetails   - Undefined - check only known applications that are populated with the
//                                 DigitalSignature.FillApplicationsList procedure, if an empty array is passed.
//                      - Array - 
//                                 
//                                 
//
//   CheckAtServer1 - Undefined - check at the server if signing or encryption at the server is enabled.
//                      - Boolean - 
//                                 
//
Procedure FindInstalledPrograms(Notification, ApplicationsDetails = Undefined, CheckAtServer1 = Undefined) Export
	
	If ApplicationsDetails = Undefined Then
		ApplicationsDetails = New Array;
	EndIf;
	
	TypesArrayCheckAtServer = New Array;
	TypesArrayCheckAtServer.Add(Type("Boolean"));
	TypesArrayCheckAtServer.Add(Type("Undefined"));
	
	CommonClientServer.CheckParameter("DigitalSignatureClient.FindInstalledPrograms", "CheckAtServer1", 
		CheckAtServer1, TypesArrayCheckAtServer);
		
	CommonClientServer.CheckParameter("DigitalSignatureClient.FindInstalledPrograms", "Notification", 
		Notification, Type("NotifyDescription"));
		
	CommonClientServer.CheckParameter("DigitalSignatureClient.FindInstalledPrograms", "ApplicationsDetails", 
		ApplicationsDetails, Type("Array"));
	
	DigitalSignatureInternalClient.FindInstalledPrograms(Notification, ApplicationsDetails, CheckAtServer1);
	
EndProcedure

// 
// 
// Parameters:
//  Form - ClientApplicationForm
//  CheckParameters - 
//    
//      
//       
//      
//   
//      
//      See DigitalSignatureInternalClientServer.AppsRelevantAlgorithms
//      
//      
//      
//   
//        
//   
//        
//   
//                                                 
//  CompletionNotification2 - NotifyDescription -
//     
//     
//                           
//     
//     
//          
//          
//          
//             
//          
//          
//     
//                                            
//     
//     
//     
//     
//
Procedure CheckCryptographyAppsInstallation(Form, CheckParameters = Undefined, CompletionNotification2 = Undefined) Export
	
	DigitalSignatureInternalClient.CheckCryptographyAppsInstallation(Form, CheckParameters, CompletionNotification2);
	
EndProcedure

// False if not specified.
// For operations using platform tools only (CryptoManager).
//
// Setting a password allows the user not to enter the password during the next
// operation, which is useful when performing a package of operations.
// If a password is set for the certificate, the RememberPassword check box
// in the DataSigning and DataDecryption forms becomes hidden.
// To cancel the set password, set the password value to Undefined.
//
// Parameters:
//  CertificateReference - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - a certificate
//                        for which password is being set.
//
//  Password           - String - a password to be set. It can be blank.
//                   - Undefined - 
//
//  PasswordNote   - Structure - with the note properties under the password instead of the RememberPassword check box:
//     * ExplanationText       - String - - text only.
//     * HyperlinkNote - Boolean - if True, then call ActionProcessing by clicking the note.
//     * ToolTipText       - String
//                            - FormattedString - 
//     * ProcessAction    - NotifyDescription - calls a procedure in which the value of the type:
//        = Structure:
//          # Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - reference
//                         to the selected certificate;
//          # Action   - String - "NoteClick" or the tooltip URL.
// 
Procedure SetCertificatePassword(CertificateReference, Password, PasswordNote = Undefined) Export
	
	DigitalSignatureInternalClient.SetCertificatePassword(CertificateReference, Password, PasswordNote);
	
EndProcedure

// 
// 
// 
//
// Parameters:
//  CertificateReference - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates -
//                        
//
// Returns:
//  Boolean - 
//
Function CertificatePasswordIsSet(CertificateReference) Export
	
	Return DigitalSignatureInternalClient.CertificatePasswordIsSet(CertificateReference);
	
EndFunction

// Overrides the usual certificate choice from the catalog to certificate selection
// from the personal storage with password confirmation and automatic addition to the catalog
// if there is no certificate in the catalog yet.
//
// Parameters:
//  Item    - FormField - a form item, where the selected value will be passed.
//  Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - the current value
//               selected in the Item field required to select the matching list line.
//
//  StandardProcessing - Boolean - the StartChoice event standard parameter that you need to reset to False.
//  
//  ToEncryptAndDecrypt - Boolean - manages the choice form title. The initial value is False.
//                              False is to sign, True is to encrypt and decrypt.
//                            - Undefined - 
//
Procedure CertificateStartChoiceWithConfirmation(Item, Certificate, StandardProcessing, ToEncryptAndDecrypt = False) Export
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("SelectedCertificate", Certificate);
	FormParameters.Insert("ToEncryptAndDecrypt", ToEncryptAndDecrypt);
	
	DigitalSignatureInternalClient.SelectSigningOrDecryptionCertificate(FormParameters, Item);
	
EndProcedure

// Shows the certificate check result executed in the background mode.
//
// Parameters:
//   Certificate           - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - the certificate
//                        for which a check was executed.
//   Result            - See DigitalSignatureClient.CheckCatalogCertificate.AdditionalParameters.Результат
//   FormOwner        - ClientApplicationForm - the owner of the certificate check form that is being opened.
//   Title            - String - the title of the certificate check form that is being opened.
//   MergeResults - String - determines the method of the check result representation in the client/server
//                        mode when using a digital signature on the server. It can be
//                        DontMerge, MergeByAnd, MergeByOr. If it is 
//                        MergeByAnd or MergeByOr, the check results will be merged with 
//                        the corresponding condition. Otherwise, the results will be displayed
//                        separately for client and server checks.
//   CompletionProcessing  - NotifyDescription - contains details of the procedure that will be called after
//                        closing the certificate check form.
//
Procedure ShowCertificateCheckResult(Certificate, Result, FormOwner,
	Title = "", MergeResults = "DontMerge", CompletionProcessing = Undefined) Export
	
	DigitalSignatureInternalClient.ShowCertificateCheckResult(
		Certificate, Result, FormOwner, Title, MergeResults, CompletionProcessing);
	
EndProcedure

// 
// 
// Parameters:
//  Certificate - BinaryData
//             - String - 
//             - String - 
//             - CryptoCertificate
//
Procedure InstallRootCertificate(Certificate) Export
	
	Parameters = DigitalSignatureInternalClient.CertificateInstallationParameters(Certificate);
	DigitalSignatureInternalClient.InstallRootCertificate(Parameters);
	
EndProcedure

// 
// 
// Parameters:
//  Notification - NotifyDescription -
//                                    
//                                   
//    
//     
//     
//                                  
//     
//                                                   
//     
//             - Undefined - 
//     
//     
//     
//      
//     
//  Signature - BinaryData -
//          - String - 
//          - Array of String
//          - Array of BinaryData
//  ShouldReadCertificates - Boolean -
//
Procedure ReadSignatureProperties(Notification, Signature, ShouldReadCertificates = True) Export

	DigitalSignatureInternalClient.ReadSignatureProperties(Notification, Signature, ShouldReadCertificates);

EndProcedure

// 

// 
// 
// Parameters:
//  Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
//
Procedure NotifyAboutCertificateExpiring(Certificate) Export
	
	Result = DigitalSignatureInternalServerCall.CertificateCustomSettings(Certificate);

	If ValueIsFilled(Result.CertificateRef) And Not Result.IsNotified Then
		
		FormOpenParameters = New Structure("Certificate", Certificate);
		ActionOnClick = New NotifyDescription("OpenNotificationFormNeedReplaceCertificate",
			DigitalSignatureInternalClient, FormOpenParameters);
		ShowUserNotification(NStr("en = 'You need to reissue the certificate';"), ActionOnClick, Certificate,
			PictureLib.Warning32, UserNotificationStatus.Important, Certificate);

	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

// Opens the DS view form.
Procedure OpenSignature(CurrentData) Export
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SignatureProperties = New Structure(
		"SignatureDate, Comment, CertificateOwner, Thumbprint,
		|SignatureAddress, SignatureSetBy, CertificateAddress,
		|Status, ErrorDescription, SignatureCorrect, SignatureValidationDate, SignatureType, DateActionLastTimestamp,
		|Object, SequenceNumber, IsVerificationRequired");
	
	FillPropertyValues(SignatureProperties, CurrentData);
	
	FormParameters = New Structure("SignatureProperties", SignatureProperties);
	OpenForm("CommonForm.DigitalSignature", FormParameters);
	
EndProcedure

Procedure OpenRenewalFormActionsSignatures(Form, RenewalOptions, FollowUpHandler = Undefined) Export
	
	OpenForm("CommonForm.RenewDigitalSignatures", RenewalOptions,
		Form,,,,FollowUpHandler, FormWindowOpeningMode.LockOwnerWindow);
		
EndProcedure

// Opens the RenewDigitalSignatures report form.
// 
// Parameters:
//  ExtensionMode - String - Report options: 
//   UnprocessedSignatures, IsSignatureUpdateRequired, 
//   IsArchiveMarksRequried, AreErrorsOccurredDuringAutomaticRenewal.
//
Procedure OpenReportExtendValidityofElectronicSignatures(ExtensionMode) Export
	
	OpenForm("Report.RenewDigitalSignatures.Form", 
		New Structure("ExtensionMode", ExtensionMode));
	
EndProcedure


// 
Procedure SaveSignature(SignatureAddress) Export
	
	DigitalSignatureInternalClient.SaveSignature(SignatureAddress);
	
EndProcedure

// Opens the certificate data view form.
//
// Parameters:
//  CertificateData - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates - a reference to the certificate.
//                    - CryptoCertificate - 
//                    - BinaryData - binary data of the certificate.
//                    - String - 
//                    - String - 
//
//  OpenData     - Boolean - open the certificate data and not the form of catalog item.
//                      If not a reference is passed to the catalog item and the catalog item
//                      could not be found by thumbprint, the certificate data will be opened.
//
Procedure OpenCertificate(CertificateData, OpenData = False) Export
	
	DigitalSignatureInternalClient.OpenCertificate(CertificateData, OpenData);
	
EndProcedure

// It reports the signing once it is completed.
//
// Parameters:
//  DataPresentation - Arbitrary - a reference to the object, to which
//                          digital signature is added.
//  IsPluralForm     - Boolean - determines the type of message and whether there are multiple items
//                          or one item.
//  FromFile             - Boolean - determines the type of message to add
//                          a digital signature or a file.
//
Procedure ObjectSigningInfo(DataPresentation, IsPluralForm = False, FromFile = False) Export
	
	If FromFile Then
		If IsPluralForm Then
			MessageText = NStr("en = 'Signatures from files added:';");
		Else
			MessageText = NStr("en = 'Signature from file is added:';");
		EndIf;
	Else
		If IsPluralForm Then
			MessageText = NStr("en = 'Digitally signed:';");
		Else
			MessageText = NStr("en = 'Digitally signed:';");
		EndIf;
	EndIf;
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

// Reports completion at the end of encryption.
//
// Parameters:
//  DataPresentation - Arbitrary - a reference to an object
//                          whose data is encrypted.
//  IsPluralForm     - Boolean - determines the type of message and whether there are multiple items
//                          or one item.
//
Procedure InformOfObjectEncryption(DataPresentation, IsPluralForm = False) Export
	
	MessageText = NStr("en = 'Encrypted:';");
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

// Reports completion at the end of decryption.
//
// Parameters:
//  DataPresentation - Arbitrary - a reference to an object
//                          whose data is decrypted.
//  IsPluralForm     - Boolean - determines the type of message and whether there are multiple items
//                          or one item.
//
Procedure InformOfObjectDecryption(DataPresentation, IsPluralForm = False) Export
	
	MessageText = NStr("en = 'Decrypted:';");
	
	ShowUserNotification(MessageText, , DataPresentation);
	
EndProcedure

// See DigitalSignature.PersonalSettings.
Function PersonalSettings() Export
	
	Return StandardSubsystemsClient.ClientRunParameters().DigitalSignature.PersonalSettings;
	
EndFunction

#EndRegion

#Region Private

// See DigitalSignature.CommonSettings.
Function CommonSettings() Export
	
	Return StandardSubsystemsClient.ClientRunParameters().DigitalSignature.CommonSettings;
	
EndFunction

#EndRegion
