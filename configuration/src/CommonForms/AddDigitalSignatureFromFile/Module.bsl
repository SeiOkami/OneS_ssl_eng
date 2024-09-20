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
Var ClientParameters Export;

&AtClient
Var DataDetails, ObjectForm, CurrentPresentationsList;

&AtClient
Var DataRepresentationRefreshed;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If ValueIsFilled(Parameters.DataTitle) Then
		Items.DataPresentation.Title = Parameters.DataTitle;
	Else
		Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	DataPresentation = Parameters.DataPresentation;
	Items.DataPresentation.Hyperlink = Parameters.DataPresentationCanOpen;
	
	If Not ValueIsFilled(DataPresentation) Then
		Items.DataPresentation.Visible = False;
	EndIf;
	
	If Not Parameters.ShowComment Then
		Items.Signatures.Header = False;
		Items.SignaturesComment.Visible = False;
	EndIf;
	
	CryptographyManagerOnServerErrorDescription = New Structure;
	
	If DigitalSignature.VerifyDigitalSignaturesOnTheServer()
	 Or DigitalSignature.GenerateDigitalSignaturesAtServer() Then
		
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.ErrorDescription = New Structure;
		
		DigitalSignatureInternal.CryptoManager("", CreationParameters);
		CryptographyManagerOnServerErrorDescription = CreationParameters.ErrorDescription;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ClientParameters = Undefined Then
		Cancel = True;
	Else
		DataDetails             = ClientParameters.DataDetails;
		ObjectForm               = ClientParameters.Form;
		CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
		AttachIdleHandler("AfterOpen", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureInternalClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, CurrentPresentationsList);
	
EndProcedure

#EndRegion

#Region SignaturesFormTableItemEventHandlers

&AtClient
Procedure SignaturesBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	
	If DataRepresentationRefreshed = True Then
		SelectFile(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SignaturesPathToFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectFile();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If Signatures.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No signature file is selected';"));
		Return;
	EndIf;
	
	If Not DataDetails.Property("Object") Then
		DataDetails.Insert("Signatures", SignaturesArray());
		Close(True);
		Return;
	EndIf;
	
	If TypeOf(DataDetails.Object) <> Type("NotifyDescription") Then
		ObjectVersion = Undefined;
		DataDetails.Property("ObjectVersion", ObjectVersion);
		SignaturesArray = Undefined;
		Try
			AddSignature(DataDetails.Object, ObjectVersion, SignaturesArray);
		Except
			ErrorInfo = ErrorInfo();
			OKCompletion(New Structure("ErrorDescription", ErrorProcessing.BriefErrorDescription(ErrorInfo)));
			Return;
		EndTry;
		DataDetails.Insert("Signatures", SignaturesArray);
		NotifyChanged(DataDetails.Object);
	Else
		DataDetails.Insert("Signatures", SignaturesArray());
		
		ExecutionParameters = New Structure;
		ExecutionParameters.Insert("DataDetails", DataDetails);
		ExecutionParameters.Insert("Notification", New NotifyDescription("OKCompletion", ThisObject));
		
		Try
			ExecuteNotifyProcessing(DataDetails.Object, ExecutionParameters);
			Return;
		Except
			ErrorInfo = ErrorInfo();
			OKCompletion(New Structure("ErrorDescription", ErrorProcessing.BriefErrorDescription(ErrorInfo)));
			Return;
		EndTry;
	EndIf;
	
	OKCompletion(New Structure);
	
EndProcedure

// Continues the OK procedure.
&AtClient
Procedure OKCompletion(Result, Context = Undefined) Export
	
	If Result.Property("ErrorDescription") Then
		DataDetails.Delete("Signatures");
		
		Error = New Structure("ErrorDescription",
			NStr("en = 'Cannot save the signature due to:';") + Chars.LF + Result.ErrorDescription);
			
		DigitalSignatureInternalClient.ShowApplicationCallError(
			NStr("en = 'Cannot add a digital signature from the file';"), "", Error, New Structure);
		Return;
	EndIf;
	
	If ValueIsFilled(DataPresentation) Then
		DigitalSignatureClient.ObjectSigningInfo(
			DigitalSignatureInternalClient.FullDataPresentation(ThisObject),, True);
	EndIf;
	
	Close(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterOpen()
	
	DataRepresentationRefreshed = True;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignaturesPathToFile.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Signatures.PathToFile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
EndProcedure

&AtClient
Procedure SelectFile(AddNewRow = False)
	
	Context = New Structure;
	Context.Insert("AddNewRow", AddNewRow);
	
	Notification = New NotifyDescription("SelectFileAfterPutFiles", ThisObject, Context);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Dialog.Title = NStr("en = 'Select a digital signature file';");
	ImportParameters.Dialog.Filter = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Signature files (*.%1)|*.%1';"),
		DigitalSignatureClient.PersonalSettings().SignatureFilesExtension);
	ImportParameters.Dialog.Filter = ImportParameters.Dialog.Filter + "|" + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	
	If Not AddNewRow Then
		ImportParameters.Dialog.FullFileName = Items.Signatures.CurrentData.PathToFile;
	EndIf;
	
	FileSystemClient.ImportFile_(Notification, ImportParameters);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure SelectFileAfterPutFiles(FileThatWasPut, Context) Export
	
	If FileThatWasPut = Undefined Then
		Return;
	EndIf;
	
	NameContent = CommonClientServer.ParseFullFileName(FileThatWasPut.Name);
	
	Context.Insert("Address",               FileThatWasPut.Location);
	Context.Insert("FileName",            NameContent.Name);
	Context.Insert("ErrorAtServer",     New Structure);
	Context.Insert("SignatureData",       Undefined);
	Context.Insert("SignatureDate",         Undefined);
	Context.Insert("SignaturePropertiesAddress", Undefined);
	
	Success = AddRowAtServer(Context.Address, Context.FileName, Context.AddNewRow,
		Context.ErrorAtServer, Context.SignatureData, Context.SignatureDate, Context.SignaturePropertiesAddress);
	
	If Success Then
		SelectFileAfterAddRow(Context);
		Return;
	EndIf;
	
	CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
	CreationParameters.SignAlgorithm = DigitalSignatureInternalClientServer.GeneratedSignAlgorithm(Context.SignatureData);
	CreationParameters.ShowError = Undefined;
	
	DigitalSignatureInternalClient.CreateCryptoManager(New NotifyDescription(
			"ChooseFileAfterCreateCryptoManager", ThisObject, Context),
		"", CreationParameters);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure ChooseFileAfterCreateCryptoManager(CryptoManager, Context) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();  
		CreationParameters.ShowError = Undefined;
		DigitalSignatureInternalClient.ReadSignatureProperties(New NotifyDescription(
			"SelectFileAfterSignaturePropertiesRead", ThisObject, Context),
			Context.SignatureData, True, False);
		Return;
	EndIf;
	
	Context.Insert("CryptoManager", CryptoManager);
	
	If DigitalSignatureClient.CommonSettings().AvailableAdvancedSignature Then
		CryptoManager.BeginGettingCryptoSignaturesContainer(New NotifyDescription(
			"SelectFileAfterGettingContainerSignature", ThisObject, Context,
			"SelectFileAfterReceivingSignatureContainerError", ThisObject), Context.SignatureData);
		Return;
	EndIf;
	
	Context.Insert("SignatureParameters", Undefined);
	CryptoManager.BeginGettingCertificatesFromSignature(New NotifyDescription(
		"ChooseFilesAfterGetCertificatesFromSignature", ThisObject, Context,
		"SelectFileAfterGetCertificateFromSignatureError", ThisObject), Context.SignatureData);
	
EndProcedure

// Continue the select File procedure.
&AtClient
Procedure SelectFileAfterSignaturePropertiesRead(Result, Context) Export
	
	If Result.Success = False Then
		ShowError(Result.ErrorText, Context.ErrorAtServer);
		Return;
	EndIf;
	
	Context.Insert("CryptoManager", Undefined);
	Context.Insert("SignatureParameters", Result);
	
	If Result.Certificate <> Undefined Then
		
		CertificateProperties = New Structure;
		CertificateProperties.Insert("BinaryData", Result.Certificate);
		CertificateProperties.Insert("Thumbprint", Result.Thumbprint);
		CertificateProperties.Insert("IssuedTo", Result.CertificateOwner);
		
		SignatureProperties = DigitalSignatureInternalClientServer.SignatureProperties(Context.SignatureData,
			CertificateProperties, "", UsersClient.AuthorizedUser(), Context.FileName,
			Context.SignatureParameters, True);

		AddRow(ThisObject, Context.AddNewRow, SignatureProperties, Context.FileName,
			Context.SignaturePropertiesAddress);

		SelectFileAfterAddRow(Context);
	Else
		ErrorAtClient = New Structure("ErrorDescription", NStr("en = 'The signature file contains no certificates.';"));

		ShowError(ErrorAtClient, Context.ErrorAtServer);
	EndIf;
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure SelectFileAfterReceivingSignatureContainerError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorAtClient = New Structure("ErrorDescription", StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot receive the signature container from the signature file due to:
		           |%1';"),
		ErrorProcessing.BriefErrorDescription(ErrorInfo)));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ShowInstruction", True);
	AdditionalParameters.Insert("Signature", Context.SignatureData);
	
	ShowError(ErrorAtClient, Context.ErrorAtServer, AdditionalParameters);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure SelectFileAfterGettingContainerSignature(ContainerSignatures, Context) Export
	
	SessionDate = CommonClient.SessionDate();
	TimeAddition = SessionDate - CommonClient.UniversalDate();
	SignatureParameters = DigitalSignatureInternalClientServer.ParametersCryptoSignatures(
		ContainerSignatures, TimeAddition, SessionDate);
			
	Context.Insert("SignatureParameters", SignatureParameters);
	SignatureDate = SignatureParameters.UnverifiedSignatureDate;
	If ValueIsFilled(SignatureDate) Then
		Context.Insert("SignatureDate", SignatureDate);
	EndIf;
	
	Certificates = New Array;
	If SignatureParameters.CertificateDetails <> Undefined Then
		Certificates.Add(ContainerSignatures.Signatures[0].SignatureCertificate);
	EndIf;

	ChooseFilesAfterGetCertificatesFromSignature(Certificates, Context);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure SelectFileAfterGetCertificateFromSignatureError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorAtClient = New Structure("ErrorDescription", StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot receive the certificates from the signature file due to:
		           |%1';"),
		ErrorProcessing.BriefErrorDescription(ErrorInfo)));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ShowInstruction", True);
	AdditionalParameters.Insert("Signature", Context.SignatureData);
	
	ShowError(ErrorAtClient, Context.ErrorAtServer, AdditionalParameters);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure ChooseFilesAfterGetCertificatesFromSignature(Certificates, Context) Export
	
	If Certificates.Count() = 0 Then
		ErrorAtClient = New Structure("ErrorDescription",
			NStr("en = 'The signature file contains no certificates.';"));
		
		ShowError(ErrorAtClient, Context.ErrorAtServer);
		Return;
	EndIf;
	
	Try
		If Certificates.Count() = 1 Then
			Certificate = Certificates[0];
		ElsIf Certificates.Count() > 1 Then
			Certificate = DigitalSignatureInternalClientServer.CertificatesInOrderToRoot(Certificates)[0];
		EndIf;
	Except
		ErrorAtClient = New Structure("ErrorDescription",
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		ShowError(ErrorAtClient, Context.ErrorAtServer);
		Return;
	EndTry;
	
	Context.Insert("Certificate", Certificate);
	
	CurrentCertificate = Context.Certificate; // CryptoCertificate
	CurrentCertificate.BeginUnloading(New NotifyDescription(
		"ChooseFileAfterCertificateExport", ThisObject, Context));
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure ChooseFileAfterCertificateExport(CertificateData, Context) Export
	
	CertificateProperties = DigitalSignatureClient.CertificateProperties(Context.Certificate);
	CertificateProperties.Insert("BinaryData", CertificateData);
	
	SignatureProperties = DigitalSignatureInternalClientServer.SignatureProperties(Context.SignatureData,
		CertificateProperties, "", UsersClient.AuthorizedUser(), Context.FileName, Context.SignatureParameters);
	
	AddRow(ThisObject, Context.AddNewRow, SignatureProperties,
		Context.FileName, Context.SignaturePropertiesAddress);
	
	SelectFileAfterAddRow(Context);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure SelectFileAfterAddRow(Context)
	
	If Not DataDetails.Property("Data") Then
		Return; // If data is not specified, the signature cannot be checked.
	EndIf;
	
	DigitalSignatureInternalClient.GetDataFromDataDetails(New NotifyDescription(
			"ChooseFileAfterGetData", ThisObject, Context),
		ThisObject, DataDetails, DataDetails.Data, True);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure ChooseFileAfterGetData(Result, Context) Export
	
	If TypeOf(Result) = Type("Structure") Then
		Return; // Cannot get data. Signature check is impossible.
	EndIf;
	
	DigitalSignatureInternalClient.VerifySignature(New NotifyDescription(
			"ChooseFileAfterCheckSignature", ThisObject, Context),
		Result, Context.SignatureData, , Context.SignatureDate, False);
	
EndProcedure

// Continues the SelectFile procedure.
&AtClient
Procedure ChooseFileAfterCheckSignature(Result, Context) Export
	
	If Result = Undefined Then
		Return; // Cannot check the signature.
	EndIf;
	
	UpdateCheckSignatureResult(Context.SignaturePropertiesAddress, Result = True);
	
EndProcedure

&AtServer
Procedure UpdateCheckSignatureResult(SignaturePropertiesAddress, SignatureCorrect)
	
	CurrentSessionDate = CurrentSessionDate();
	SignatureProperties = GetFromTempStorage(SignaturePropertiesAddress);
	
	If ValueIsFilled(CommonClientServer.StructureProperty(
		SignatureProperties, "UnverifiedSignatureDate", Undefined)) Then
		SignatureDate = SignatureProperties.UnverifiedSignatureDate;
	EndIf;
	
	If Not ValueIsFilled(SignatureDate) Then
		If Not ValueIsFilled(SignatureProperties.SignatureDate) Then
			SignatureProperties.SignatureDate = CurrentSessionDate;
		EndIf;
	Else
		SignatureProperties.SignatureDate = SignatureDate;
	EndIf;

	SignatureProperties.SignatureValidationDate = CurrentSessionDate;
	SignatureProperties.SignatureCorrect = SignatureCorrect;
	
	PutToTempStorage(SignatureProperties, SignaturePropertiesAddress);
	
EndProcedure

&AtServer
Function AddRowAtServer(Address, FileName, AddNewRow, ErrorAtServer,
			SignatureData, SignatureDate, SignaturePropertiesAddress)
	
	Try
		SignatureData = DigitalSignature.DEREncodedSignature(Address);
	Except
		ErrorInfo = ErrorInfo();
		ErrorAtServer.Insert("ErrorDescription", ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return False;
	EndTry;
	
	SignatureDate = DigitalSignature.SigningDate(SignatureData);
	
	If Not DigitalSignature.VerifyDigitalSignaturesOnTheServer()
		And Not DigitalSignature.GenerateDigitalSignaturesAtServer() Then
		
		Return False;
	EndIf;
	
	CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
	CreationParameters.ErrorDescription = ErrorAtServer;
	CreationParameters.SignAlgorithm = DigitalSignatureInternalClientServer.GeneratedSignAlgorithm(SignatureData);
	
	CryptoManager = DigitalSignatureInternal.CryptoManager("", CreationParameters);
	
	ErrorAtServer = CreationParameters.ErrorDescription;
	If CryptoManager = Undefined Then
		Return False;
	EndIf;
	
	SignatureParameters = Undefined;
	If DigitalSignature.CommonSettings().AvailableAdvancedSignature Then
		ContainerSignatures = CryptoManager.GetCryptoSignaturesContainer(SignatureData);
		SignatureParameters = DigitalSignatureInternalClientServer.ParametersCryptoSignatures(ContainerSignatures,
			DigitalSignatureInternal.TimeAddition(), CurrentSessionDate());
		
		If ValueIsFilled(SignatureParameters.UnverifiedSignatureDate) Then
			SignatureDate = SignatureParameters.UnverifiedSignatureDate;
		EndIf;
	EndIf;
	
	If SignatureParameters = Undefined Then
		
		Try
			
			Certificates = CryptoManager.GetCertificatesFromSignature(SignatureData);
			
			If Certificates.Count() = 0 Then
				Raise NStr("en = 'The signature file contains no certificates.';");
			EndIf;
			
			If Certificates.Count() = 1 Then
				Certificate = Certificates[0];
			ElsIf Certificates.Count() > 1 Then
				CertificatesData = New Array;
				For Each Certificate In Certificates Do
					CertificatesData.Add(Certificate.Unload());
				EndDo;
			
				CertificateBinaryData = DigitalSignatureInternal.CertificatesInOrderToRoot(
						CertificatesData)[0];
				Certificate = New CryptoCertificate(CertificateBinaryData);
			EndIf;
			
		Except
			ErrorInfo = ErrorInfo();
			ErrorAtServer.Insert("ErrorDescription", StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot receive the certificates from the signature file due to:
				           |%1';"),
				ErrorProcessing.BriefErrorDescription(ErrorInfo)));
			Return False;
		EndTry;
		
		CertificateProperties = DigitalSignature.CertificateProperties(Certificate);
		
	Else
		
		CertificateProperties = SignatureParameters.CertificateDetails;
		Certificate = ContainerSignatures.Signatures[0].SignatureCertificate;
	EndIf;
	
	CertificateProperties.Insert("BinaryData", Certificate.Unload());
	
	SignatureProperties = DigitalSignatureInternalClientServer.SignatureProperties(SignatureData,
		CertificateProperties, "", Users.AuthorizedUser(), FileName, SignatureParameters);
	
	AddRow(ThisObject, AddNewRow, SignatureProperties, FileName, SignaturePropertiesAddress);
	
	Return True;
	
EndFunction

&AtClientAtServerNoContext
Procedure AddRow(Form, AddNewRow, SignatureProperties, FileName, SignaturePropertiesAddress)
	
	SignaturePropertiesAddress = PutToTempStorage(SignatureProperties, Form.UUID);
	
	If AddNewRow Then
		CurrentData = Form.Signatures.Add();
	Else
		CurrentData = Form.Signatures.FindByID(Form.Items.Signatures.CurrentRow);
	EndIf;
	
	CurrentData.PathToFile = FileName;
	CurrentData.SignaturePropertiesAddress = SignaturePropertiesAddress;
	
EndProcedure

&AtServer
Function SignaturesArray()
	
	SignaturesArray = New Array;
	
	For Each String In Signatures Do
		
		SignatureProperties = GetFromTempStorage(String.SignaturePropertiesAddress);
		SignatureProperties.Insert("Comment", String.Comment);
		
		SignaturesArray.Add(PutToTempStorage(SignatureProperties, UUID));
	EndDo;
	
	Return SignaturesArray;
	
EndFunction

&AtServer
Procedure AddSignature(ObjectReference, ObjectVersion, SignaturesArray)
	
	SignaturesArray = SignaturesArray();
	
	DigitalSignature.AddSignature(ObjectReference,
		SignaturesArray, UUID, ObjectVersion);
	
EndProcedure

&AtClient
Procedure ShowError(ErrorAtClient, ErrorAtServer, AdditionalParameters = Undefined)
	
	DigitalSignatureInternalClient.ShowApplicationCallError(
		NStr("en = 'Cannot receive a signature from the file';"),
		"", ErrorAtClient, ErrorAtServer, AdditionalParameters);
	
EndProcedure

#EndRegion