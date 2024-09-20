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
Var InternalData, DataDetails, ObjectForm, ProcessingAfterWarning, CurrentPresentationsList;

#EndRegion

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Parameters.CertificatesSet) Then
		SpecifiedImmutableCertificateSet = True;
		FillEncryptionCertificatesFromSet(Parameters.CertificatesSet);
		If CertificatesSet.Count() = 0 And Parameters.ChangeSet Then
			// 
			// 
			SpecifiedImmutableCertificateSet = False;
		EndIf;
	EndIf;
	
	DigitalSignatureInternal.SetSigningEncryptionDecryptionForm(ThisObject, True);
	
	If SpecifiedImmutableCertificateSet Then
		Items.Certificate.Visible = False;
		Items.EncryptionCertificatesGroup.Title = Items.GroupSpecifiedCertificatesSet.Title;
		Items.EncryptionCertificates.ReadOnly = True;
		Items.EncryptionCertificatesPick.Enabled = False;
		FillEncryptionApplicationAtServer();
	EndIf;
	
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationServer = Common.CommonModule("DSSCryptographyServiceConfirmationServer");
		ModuleCryptographyServiceDSSConfirmationServer.PrepareGroupConfirmation(ThisObject, "Encryption",
				"SelectFromCatalog",
				"GroupContainer",
				,
				"ConfirmationCommandsGroup");
		ModuleCryptographyServiceDSSConfirmationServer.ConfirmationWhenChangingCertificate(ThisObject, GetTheMainCertificate());
	EndIf;
	
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
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationWhenOpening(ThisObject, Cancel, False, DataDetails);
	EndIf;
	
	AttachIdleHandler("PopulateEncryptionAppWaitHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	ClearFormVariables();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionApplications")
	 Or Upper(EventName) = Upper("Write_PathsToDigitalSignatureAndEncryptionApplicationsOnLinuxServers")
	 Or Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") Then
		
		If SpecifiedImmutableCertificateSet Then
			AttachIdleHandler("RefillEncryptionApplication", 0.1, True);
			Return;
		EndIf;
	EndIf;
	
	If Upper(EventName) = Upper("Write_DigitalSignatureAndEncryptionKeysCertificates") Then
		AttachIdleHandler("OnChangeCertificatesList", 0.1, True);
	EndIf;
	
	If Upper(EventName) = Upper("ConfirmationToPerformTheMainOperation") And Source = UUID Then
		If Parameter.Completed2 Then
			CloudSignatureProperties = DigitalSignatureInternalClient.GetThePropertiesOfACloudSignature(DataDetails);
			NotificationOnConfirmation = CloudSignatureProperties.NotificationOnConfirmation;
			If NotificationOnConfirmation = Undefined Then
				EncryptData(New NotifyDescription("EncryptCompletion", ThisObject));
			Else
				ExecuteNotifyProcessing(NotificationOnConfirmation, ThisObject);
			EndIf;
		EndIf;
		
	ElsIf Upper(EventName) = Upper("ConfirmationPrepareData") And Source = UUID Then
		DigitalSignatureInternalClient.GetDataForACloudSignature(
			Parameter.HandlerNext, Parameter.TheFormContext, 
			Parameter.DataDetails, Parameter.Data, True);
	
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

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
	
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.CheckForCertificateError(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.FilterListOfMethods(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationOnChange(ThisObject, Items.Certificate, DataDetails, "");
	EndIf;
	
	FillEncryptionApplication();
	
EndProcedure

&AtClient
Procedure CertificateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("SelectedCertificate", Certificate);
	FormParameters.Insert("ToEncryptAndDecrypt", True);
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
	
	Certificate = ValueSelected;
	
	DigitalSignatureInternalClient.GetCertificatesThumbprintsAtClient(
		New NotifyDescription("CertificateChoiceProcessingCompletion", ThisObject));
	
EndProcedure

// Continues the CertificateChoiceProcessing procedure.
&AtClient
Procedure CertificateChoiceProcessingCompletion(CertificatesThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificatesThumbprintsAtClient);
	
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		ModuleCryptographyServiceDSSConfirmationClient.CheckForCertificateError(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.FilterListOfMethods(ThisObject);
		ModuleCryptographyServiceDSSConfirmationClient.ConfirmationOnChange(ThisObject, Items.Certificate, DataDetails, "");
	EndIf;
	
	FillEncryptionApplication();
	
EndProcedure

&AtClient
Procedure CertificateAutoComplete(Item, Text, ChoiceData, Var_Parameters, Waiting, StandardProcessing)
	
	DigitalSignatureInternalClient.CertificatePickupFromSelectionList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificateTextEditEnd(Item, Text, ChoiceData, Var_Parameters, StandardProcessing)
	
	DigitalSignatureInternalClient.CertificatePickupFromSelectionList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region EncryptionCertificatesFormTableItemEventHandlers

&AtClient
Procedure EncryptionCertificatesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each Value In ValueSelected Do
		Filter = New Structure("Certificate", Value);
		Rows = EncryptionCertificates.FindRows(Filter);
		If Rows.Count() > 0 Then
			Continue;
		EndIf;
		EncryptionCertificates.Add().Certificate = Value;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Pick(Command)
	
	OpenForm("Catalog.DigitalSignatureAndEncryptionKeysCertificates.Form.SelectEncryptionCertificates",
		, Items.EncryptionCertificates);
	
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	If Items.EncryptionOptions.CurrentPage = Items.SelectFromCatalog Then
		CurrentData = Items.EncryptionCertificates.CurrentData;
	Else
		CurrentData = Items.CertificatesSet.CurrentData;
	EndIf;
	
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If Items.EncryptionOptions.CurrentPage = Items.SelectFromCatalog Then
		DigitalSignatureClient.OpenCertificate(CurrentData.Certificate);
	Else
		DigitalSignatureClient.OpenCertificate(CurrentData.DataAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not SpecifiedImmutableCertificateSet
	   And Not CheckFilling() Then
		
		Return;
	EndIf;
	
	If DigitalSignatureInternalClient.ThisIsACloudSignatureOperation(ThisObject) Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
		If ModuleCryptographyServiceDSSConfirmationClient.CheckingBeforePerformingOperation(ThisObject, "") Then 
			ModuleCryptographyServiceDSSConfirmationClient.PerformInitialServiceOperation(ThisObject, DataDetails, "");
		EndIf;
		
	Else	
		If Not Items.FormEncrypt.Enabled Then
			Return;
		EndIf;
	
		Items.FormEncrypt.Enabled = False;
		
		EncryptData(New NotifyDescription("EncryptCompletion", ThisObject));
	EndIf;	
	
EndProcedure

// Continues the Encrypt procedure.
&AtClient
Procedure EncryptCompletion(Result, Context) Export
	
	Items.FormEncrypt.Enabled = True;
	
	If Result = True And IsOpen() Then
		Close(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillEncryptionCertificatesFromSet(CertificatesSetDetails)
	
	If Common.IsReference(TypeOf(CertificatesSetDetails)) Then
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.CheckReadAllowed(CertificatesSetDetails);
		EndIf;
		Query = New Query;
		Query.SetParameter("Ref", CertificatesSetDetails);
		Query.Text =
		"SELECT
		|	EncryptionCertificates.Certificate AS Certificate
		|FROM
		|	InformationRegister.EncryptionCertificates AS EncryptionCertificates
		|WHERE
		|	EncryptionCertificates.EncryptedObject = &Ref";
		SetPrivilegedMode(True);
		Selection = Query.Execute().Select();
		SetPrivilegedMode(False);
		CertificatesArray = New Array;
		While Selection.Next() Do
			CertificatesArray.Add(Selection.Certificate.Get());
		EndDo;
	Else
		If TypeOf(CertificatesSetDetails) = Type("String") Then
			CertificatesArray = GetFromTempStorage(CertificatesSetDetails);
		Else
			CertificatesArray = CertificatesSetDetails;
		EndIf;
		AddedCertificates = New Map;
		For Each CurrentCertificate In CertificatesArray Do
			If TypeOf(CurrentCertificate) = Type("CatalogRef.DigitalSignatureAndEncryptionKeysCertificates") Then
				If AddedCertificates.Get(CurrentCertificate) = Undefined Then
					AddedCertificates.Insert(CurrentCertificate, True);
					EncryptionCertificates.Add().Certificate = CurrentCertificate;
				EndIf;
			Else
				EncryptionCertificates.Clear();
				Break;
			EndIf;
		EndDo;
		If EncryptionCertificates.Count() > 0
		 Or CertificatesArray.Count() = 0 Then
			Return;
		EndIf;
	EndIf;
	
	CertificateTable = New ValueTable;
	CertificateTable.Columns.Add("Ref");
	CertificateTable.Columns.Add("Thumbprint");
	CertificateTable.Columns.Add("Presentation");
	CertificateTable.Columns.Add("IssuedTo");
	CertificateTable.Columns.Add("Data");
	
	References = New Array;
	Thumbprints = New Array;
	For Each CertificateDetails In CertificatesArray Do
		NewRow = CertificateTable.Add();
		If TypeOf(CertificateDetails) = Type("BinaryData") Then
			CryptoCertificate = New CryptoCertificate(CertificateDetails);
			CertificateProperties = DigitalSignature.CertificateProperties(CryptoCertificate);
			NewRow.Presentation = CertificateProperties.Presentation;
			NewRow.IssuedTo     = CertificateProperties.IssuedTo;
			NewRow.Thumbprint     = CertificateProperties.Thumbprint;
			NewRow.Data        = CertificateDetails;
			Thumbprints.Add(CertificateProperties.Thumbprint);
		Else
			NewRow.Ref = CertificateDetails;
			References.Add(CertificateDetails);
		EndIf;
	EndDo;
	CertificateTable.Indexes.Add("Ref");
	CertificateTable.Indexes.Add("Thumbprint");
	
	Query = New Query;
	Query.SetParameter("References", References);
	Query.SetParameter("Thumbprints", Thumbprints);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Thumbprint AS Thumbprint,
	|	Certificates.Description AS Presentation,
	|	Certificates.CertificateData AS CertificateData
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS Certificates
	|WHERE
	|	(Certificates.Ref IN (&References)
	|			OR Certificates.Thumbprint IN (&Thumbprints))";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Rows = CertificateTable.FindRows(New Structure("Ref", Selection.Ref));
		For Each String In Rows Do
			CertificateData = Selection.CertificateData.Get();
			If TypeOf(CertificateData) <> Type("BinaryData") Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" certificate data does not exist in the catalog.';"), Selection.Presentation);
			EndIf;
			Try
				CryptoCertificate = New CryptoCertificate(CertificateData);
			Except
				ErrorInfo = ErrorInfo();
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""%1"" certificate data in the catalog is incorrect due to:
					           |%2';"),
					Selection.Presentation,
					ErrorProcessing.BriefErrorDescription(ErrorInfo));
			EndTry;
			CertificateProperties = DigitalSignature.CertificateProperties(CryptoCertificate);
			String.Thumbprint     = Selection.Thumbprint;
			String.Presentation = Selection.Presentation;
			String.IssuedTo     = CertificateProperties.IssuedTo;
			String.Data        = CertificateData;
		EndDo;
		Rows = CertificateTable.FindRows(New Structure("Thumbprint", Selection.Thumbprint));
		For Each String In Rows Do
			String.Ref        = Selection.Ref;
			String.Presentation = Selection.Presentation;
		EndDo;
	EndDo;
	
	// Delete duplicates.
	AllThumbprints = New Map;
	IndexOf = CertificateTable.Count() - 1;
	While IndexOf >= 0 Do
		String = CertificateTable[IndexOf];
		If AllThumbprints.Get(String.Thumbprint) = Undefined Then
			AllThumbprints.Insert(String.Thumbprint, True);
		Else
			CertificateTable.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Filter = New Structure("Ref", Undefined);
	AllCertificatesInCatalog = CertificateTable.FindRows(Filter).Count() = 0;
	
	If AllCertificatesInCatalog Then
		For Each String In CertificateTable Do
			EncryptionCertificates.Add().Certificate = String.Ref;
		EndDo;
	Else
		CertificatesProperties = New Array;
		For Each String In CertificateTable Do
			NewRow = CertificatesSet.Add();
			FillPropertyValues(NewRow, String);
			NewRow.DataAddress = PutToTempStorage(String.Data, UUID);
			Properties = New Structure;
			Properties.Insert("Thumbprint",     String.Thumbprint);
			Properties.Insert("Presentation", String.IssuedTo);
			Properties.Insert("Certificate",    String.Data);
			CertificatesProperties.Add(Properties);
		EndDo;
		
		CertificatesPropertiesAddress = PutToTempStorage(CertificatesProperties, UUID);
		Items.EncryptionOptions.CurrentPage = Items.SpecifiedCertificatesSet;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefillEncryptionApplication()
	
	FillEncryptionApplicationAtServer();
	FillEncryptionApplication();
	
EndProcedure

&AtServer
Procedure FillEncryptionApplicationAtServer()
	
	CertificateApp = Undefined;
	AppAuto = Undefined;
	AppAutoAtServer = Undefined;
	
	If CertificatesSet.Count() > 0 Then
		AddressOfCertificate = CertificatesSet[0].DataAddress;
	Else
		Try
			AttributesValues = Common.ObjectAttributesValues(
				EncryptionCertificates[0].Certificate, "Application, CertificateData");
			
			If ValueIsFilled(AttributesValues.Application) Then
				CertificateApp = AttributesValues.Application;
				Return;
			EndIf;
			
			CertificateBinaryData = AttributesValues.CertificateData.Get();
			CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
		Except
			ErrorInfo = ErrorInfo();
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot receive the ""%1"" certificate data
				           |from the infobase due to:
				           |%2';"),
				EncryptionCertificates[0].Certificate,
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
		AddressOfCertificate = PutToTempStorage(CertificateBinaryData, UUID);
	EndIf;
	
	If Not DigitalSignature.GenerateDigitalSignaturesAtServer() Then
		Return;
	EndIf;
	
	CertificateBinaryData = GetFromTempStorage(AddressOfCertificate);
	CryptoCertificate = New CryptoCertificate(CertificateBinaryData);
	TestData = TestBinaryData();
	
	CertificateApplicationResult = DigitalSignatureInternal.AppForCertificate(CertificateBinaryData,
		Undefined);
	If ValueIsFilled(CertificateApplicationResult.Application) Then
		AppAutoAtServer = CertificateApplicationResult.Application;
		Return;
	Else
		ErrorText = DigitalSignatureInternalClientServer.ErrorTextFailedToDefineApp(
			CertificateApplicationResult.Error);
		CertificateAtServerErrorDescription.Insert("ErrorDescription", ErrorText);
	EndIf;
	
	ApplicationsDetailsCollection = DigitalSignature.CommonSettings().ApplicationsDetailsCollection;
	SignAlgorithm = DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateBinaryData);
	
	For Each ApplicationDetails In ApplicationsDetailsCollection Do
		
		CreationParameters = DigitalSignatureInternal.CryptoManagerCreationParameters();
		CreationParameters.Application = ApplicationDetails.Ref;
		CreationParameters.SignAlgorithm = SignAlgorithm;
		
		CryptoManager = DigitalSignatureInternal.CryptoManager("Encryption", CreationParameters);
		
		If CryptoManager = Undefined Then
			Continue;
		EndIf;
		Try
			EncryptedTestData = CryptoManager.Encrypt(TestData, CryptoCertificate);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
		If ErrorInfo = Undefined And ValueIsFilled(EncryptedTestData) Then
			CertificateApp = ApplicationDetails.Ref;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function TestBinaryData()
	
	Return PictureLib.KeyCertificate.GetBinaryData();
	
EndFunction

&AtClient
Procedure PopulateEncryptionAppWaitHandler()
	FillEncryptionApplication();
EndProcedure

&AtClient
Async Procedure FillEncryptionApplication(Notification = Undefined)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	
	If ValueIsFilled(CertificateApp) Then
		FillEncryptionApplicationAfterLoop(Context);
		Return;
	EndIf;
	
	If Not IsTempStorageURL(AddressOfCertificate) Then
		FillEncryptionApplicationAfterLoop(Context);
		Return;
	EndIf;
	
	ResultCertificateApplication = Await DigitalSignatureInternalClient.AppForCertificate(
		AddressOfCertificate, Undefined, Undefined, True);
	If ValueIsFilled(ResultCertificateApplication.Application) Then
		AppAuto = ResultCertificateApplication.Application;
		FillEncryptionApplicationAfterLoop(Context);
		Return;
	EndIf;
	
	CertificateData = GetFromTempStorage(AddressOfCertificate);
	Context.Insert("SignAlgorithm",
		DigitalSignatureInternalClientServer.CertificateSignAlgorithm(CertificateData));
		
	ApplicationsDetailsCollection = DigitalSignatureClient.CommonSettings().ApplicationsDetailsCollection;
	
	If ApplicationsDetailsCollection.Count() = 0 Then
		FillEncryptionApplicationAfterLoop(Context);
		Return;
	EndIf;
	
	Context.Insert("ApplicationsDetailsCollection", ApplicationsDetailsCollection);
	
	CryptoCertificate = New CryptoCertificate;
	CryptoCertificate.BeginInitialization(New NotifyDescription(
			"FillEncryptionApplicationAfterInitializeCertificate", ThisObject, Context),
		CertificateData);
	
EndProcedure

// Continues the FillEncryptionApplication procedure.
&AtClient
Procedure FillEncryptionApplicationAfterInitializeCertificate(CryptoCertificate, Context) Export
	
	Context.Insert("EncryptionCertificate", CryptoCertificate);
	Context.Insert("TestData", TestBinaryData());
	
	Context.Insert("IndexOf", -1);
	FillEncryptionApplicationLoopStart(Context);
	
EndProcedure

// Continues the FillEncryptionApplication procedure.
//
// Parameters:
//   Context - Structure:
//     * ApplicationDetails - Structure:
//      ** Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//
&AtClient
Procedure FillEncryptionApplicationLoopStart(Context)
	
	If Context.ApplicationsDetailsCollection.Count() <= Context.IndexOf + 1 Then
		FillEncryptionApplicationAfterLoop(Context);
		Return;
	EndIf;
	Context.IndexOf = Context.IndexOf + 1;
	Context.Insert("ApplicationDetails", Context.ApplicationsDetailsCollection[Context.IndexOf]);
	
	If Not Context.Property("SignAlgorithm") Then
		Context.Insert("SignAlgorithm", "");
	EndIf;
	
	CreationParameters = DigitalSignatureInternalClient.CryptoManagerCreationParameters();
	CreationParameters.Application = Context.ApplicationDetails.Ref;
	CreationParameters.ShowError = False;
	CreationParameters.SignAlgorithm = Context.SignAlgorithm;
	
	DigitalSignatureInternalClient.CreateCryptoManager(New NotifyDescription(
			"FillEncryptionApplicationAfterCreateCryptoManager", ThisObject, Context),
		"Encryption", CreationParameters);
	
EndProcedure

// Continues the FillEncryptionApplication procedure.
//
// Parameters:
//  CryptoManager - CryptoManager
//                       - Undefined
//  Context - Structure:
//     * ApplicationDetails - Structure:
//         ** Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//
&AtClient
Procedure FillEncryptionApplicationAfterCreateCryptoManager(CryptoManager, Context) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		FillEncryptionApplicationLoopStart(Context);
		Return;
	EndIf;
		
	CryptoManager.BeginEncrypting(New NotifyDescription(
			"FillEncryptionApplicationAfterEncryption", ThisObject, Context,
			"FillEncryptionProgramAfterEncryptionError", ThisObject),
		Context.TestData, Context.EncryptionCertificate);
	
EndProcedure

// Continues the FillEncryptionApplication procedure.
&AtClient
Procedure FillEncryptionProgramAfterEncryptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	FillEncryptionApplicationLoopStart(Context);
	
EndProcedure

// Continues the FillEncryptionApplication procedure.
//
// Parameters:
//  EncryptedData - BinaryData
//                      - Undefined
//  Context - Structure:
//     * ApplicationDetails - Structure:
//         ** Ref - CatalogRef.DigitalSignatureAndEncryptionApplications
//
&AtClient
Procedure FillEncryptionApplicationAfterEncryption(EncryptedData, Context) Export
	
	If Not ValueIsFilled(EncryptedData) Then
		FillEncryptionApplicationLoopStart(Context);
		Return;
	EndIf;
	
	CertificateApp = Context.ApplicationDetails.Ref;
	FillEncryptionApplicationAfterLoop(Context);
	
EndProcedure

// Continues the CreateCryptoManager procedure.
&AtClient
Procedure FillEncryptionApplicationAfterLoop(Context)
	
	If Context.Notification <> Undefined Then
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueOpening(Notification, CommonInternalData, ClientParameters) Export
	
	DataDetails             = ClientParameters.DataDetails;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	InternalData = CommonInternalData;
	Context = New Structure("Notification", Notification);
	Notification = New NotifyDescription("ContinueOpening", ThisObject);
	
	DigitalSignatureInternalClient.ContinueOpeningStart(New NotifyDescription(
		"ContinueOpeningAfterStart", ThisObject, Context), ThisObject, ClientParameters, True);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterStart(Result, Context) Export
	
	If Result <> True Then
		ContinueOpeningCompletion(Context);
		Return;
	EndIf;
	
	If SpecifiedImmutableCertificateSet Then
		FillEncryptionApplication(New NotifyDescription(
			"ContinueOpeningAfterFillApplication", ThisObject, Context));
	Else
		ContinueOpeningAfterFillApplication(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterFillApplication(Result, Context) Export
	
	ModuleCryptographyServiceDSSConfirmationClient = Undefined;
	If DigitalSignatureInternalClient.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationClient = CommonClient.CommonModule("DSSCryptographyServiceClient");
	EndIf;
	
	If NoConfirmation Then
		If ModuleCryptographyServiceDSSConfirmationClient <> Undefined Then
			RequiresConfirmation = ModuleCryptographyServiceDSSConfirmationClient.CloudSignatureRequiresConfirmation(ThisObject);
			If Not RequiresConfirmation Then
				ProcessingAfterWarning = Undefined;
				EncryptData(New NotifyDescription("ContinueOpeningAfterDataEncryption", ThisObject, Context));
				Return;
			EndIf;	
		Else	
			ProcessingAfterWarning = Undefined;
			EncryptData(New NotifyDescription("ContinueOpeningAfterDataEncryption", ThisObject, Context));
			Return;
		EndIf;	
	EndIf;
	
	Open();
	
	If ModuleCryptographyServiceDSSConfirmationClient <> Undefined Then
		If ModuleCryptographyServiceDSSConfirmationClient.CheckingExecutionOfInitialOperation(ThisObject, NoConfirmation) Then 
			ModuleCryptographyServiceDSSConfirmationClient.PerformInitialServiceOperation(ThisObject, DataDetails, "");
		EndIf;
	EndIf;
	
	ContinueOpeningCompletion(Context);
	
EndProcedure

// Continues the ContinueOpening procedure.
&AtClient
Procedure ContinueOpeningAfterDataEncryption(Result, Context) Export
	
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
Procedure ExecuteEncryption(ClientParameters, CompletionProcessing) Export
// ACC:78-
	
	DigitalSignatureInternalClient.RefreshFormBeforeSecondUse(ThisObject, ClientParameters);
	
	DataDetails             = ClientParameters.DataDetails;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	ProcessingAfterWarning = CompletionProcessing;
	
	Context = New Structure("CompletionProcessing", CompletionProcessing);
	EncryptData(New NotifyDescription("ExecuteEncryptionCompletion", ThisObject, Context));
	
EndProcedure

// Continues the ExecuteEncryption procedure.
&AtClient
Procedure ExecuteEncryptionCompletion(Result, Context) Export
	
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
	
EndProcedure

&AtServer
Procedure CertificateOnChangeAtServer(CertificatesThumbprintsAtClient, CheckRef = False)
	
	If CheckRef
	   And ValueIsFilled(Certificate)
	   And Common.ObjectAttributeValue(Certificate, "Ref") <> Certificate Then
		
		Certificate = Undefined;
	EndIf;
	
	DigitalSignatureInternal.CertificateOnChangeAtServer(ThisObject, CertificatesThumbprintsAtClient, True);
	
	If DigitalSignatureInternal.UseCloudSignatureService() Then
		ModuleCryptographyServiceDSSConfirmationServer = Common.CommonModule("DSSCryptographyServiceConfirmationServer");
		ModuleCryptographyServiceDSSConfirmationServer.ConfirmationWhenChangingCertificate(ThisObject, GetTheMainCertificate());
	EndIf;
	
EndProcedure

&AtClient
Async Procedure EncryptData(Notification)
	
	If DigitalSignatureInternalClient.ThisIsACloudSignatureOperation(ThisObject) Then
		DigitalSignatureInternalClient.SetThePropertiesOfTheCloudSignature(DataDetails, 
			New Structure("Account", 
				DigitalSignatureInternalClient.GetDataCloudSignature(ThisObject, "UserSettings")));
	Else	
		DigitalSignatureInternalClient.SetThePropertiesOfTheCloudSignature(DataDetails, New Structure("Account"));
	EndIf;
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorAtClient", New Structure);
	Context.Insert("ErrorAtServer", New Structure);
	
	If ValueIsFilled(Certificate) Then
		If Not ValueIsFilled(CertificateApp)
			And Not ValueIsFilled(AppAuto) And Not ValueIsFilled(AppAutoAtServer) Then
			Context.ErrorAtClient.Insert("ErrorDescription",
				NStr("en = 'An application for the private key of the selected personal certificate is not specified or cannot be determined automatically.
				           |Select another certificate.';"));
			HandleError(Notification, Context.ErrorAtClient, Context.ErrorAtServer);
			Return;
		EndIf;
	EndIf;
	
	Context.Insert("FormIdentifier", UUID);
	If TypeOf(ObjectForm) = Type("ClientApplicationForm") Then
		Context.FormIdentifier = ObjectForm.UUID;
	ElsIf TypeOf(ObjectForm) = Type("UUID") Then
		Context.FormIdentifier = ObjectForm;
	EndIf;
	
	If CertificatesSet.Count() = 0 Then
		References = New Array;
		ExcludePersonalCertificate = False;
		If Items.Certificate.Visible And ValueIsFilled(Certificate) Then
			References.Add(Certificate);
			ExcludePersonalCertificate = True;
		EndIf;
		For Each String In EncryptionCertificates Do
			If Not ExcludePersonalCertificate Or String.Certificate <> Certificate Then
				References.Add(String.Certificate);
			EndIf;
		EndDo;
		DataDetails.Insert("EncryptionCertificates", CertificatesProperties(References, Context.FormIdentifier));
	Else
		DataDetails.Insert("EncryptionCertificates", CertificatesPropertiesAddress);
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("DataDetails",     DataDetails);
	ExecutionParameters.Insert("Form",              ThisObject);
	ExecutionParameters.Insert("FormIdentifier", Context.FormIdentifier);
	ExecutionParameters.Insert("AddressOfCertificate",    AddressOfCertificate); // 
	
	Context.Insert("ExecutionParameters", ExecutionParameters);
	
	If DigitalSignatureClient.GenerateDigitalSignaturesAtServer()
	   And ExecuteAtServer <> False Then
		
		If ValueIsFilled(CertificateAtServerErrorDescription) Then
			Result = New Structure("Error", CertificateAtServerErrorDescription);
			CertificateAtServerErrorDescription = New Structure;
			EncryptDataAfterExecuteAtServerSide(Result, Context);
		Else
			// 
			DigitalSignatureInternalClient.ExecuteAtSide(New NotifyDescription(
					"EncryptDataAfterExecuteAtServerSide", ThisObject, Context),
				"Encryption", "AtServerSide", Context.ExecutionParameters);
		EndIf;
	Else
		EncryptDataAfterExecuteAtServerSide(Undefined, Context);
	EndIf;
	
EndProcedure

// Continues the EncryptData procedure.
&AtClient
Async Procedure EncryptDataAfterExecuteAtServerSide(Result, Context) Export
	
	If VariablesCleared() Then
		Return;
	EndIf;
	
	If Result <> Undefined Then
		EncryptDataAfterExecute(Result);
	EndIf;
	
	If Result <> Undefined And Not Result.Property("Error") Then
		EncryptDataAfterExecuteAtClientSide(New Structure, Context);
	Else
		If Result <> Undefined Then
			Context.ErrorAtServer = Result.Error;
			If ExecuteAtServer = True Then
				EncryptDataAfterExecuteAtClientSide(New Structure, Context);
				Return;
			EndIf;
		EndIf;
		
		// 
		DigitalSignatureInternalClient.ExecuteAtSide(New NotifyDescription(
				"EncryptDataAfterExecuteAtClientSide", ThisObject, Context),
			"Encryption", "OnClientSide", Context.ExecutionParameters);
	EndIf;
	
EndProcedure

// Continues the EncryptData procedure.
&AtClient
Procedure EncryptDataAfterExecuteAtClientSide(Result, Context) Export
	
	If VariablesCleared() Then
		Return;
	EndIf;
	
	EncryptDataAfterExecute(Result);
	
	If Result.Property("Error") Then
		Context.ErrorAtClient = Result.Error;
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer);
		Return;
	EndIf;
	
	If Not WriteEncryptionCertificates(Context.FormIdentifier, Context.ErrorAtClient) Then
		HandleError(Context.Notification, Context.ErrorAtClient, Context.ErrorAtServer);
		Return;
	EndIf;
	
	If ValueIsFilled(DataPresentation)
	   And (Not DataDetails.Property("NotifyOnCompletion")
	      Or DataDetails.NotifyOnCompletion <> False) Then
		
		DigitalSignatureClient.InformOfObjectEncryption(
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

// Continues the EncryptData procedure.
&AtClient
Procedure EncryptDataAfterExecute(Result)
	
	If Result.Property("HasProcessedDataItems") Then
		// 
		// 
		Items.Certificate.ReadOnly = True;
		Items.EncryptionCertificates.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CertificatesProperties(Val References, Val FormIdentifier)
	
	Query = New Query;
	Query.SetParameter("References", References);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Description AS Description,
	|	Certificates.Application,
	|	Certificates.CertificateData
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS Certificates
	|WHERE
	|	Certificates.Ref IN(&References)";
	
	Selection = Query.Execute().Select();
	CertificatesProperties = New Array;
	
	While Selection.Next() Do
		
		CertificateData = Selection.CertificateData.Get();
		If TypeOf(CertificateData) <> Type("BinaryData") Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The ""%1"" certificate data does not exist in the catalog.';"),
				Selection.Description);
		EndIf;
		
		Try
			CryptoCertificate = New CryptoCertificate(CertificateData);
		Except
			ErrorInfo = ErrorInfo();
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""%1"" certificate data in the catalog is incorrect due to:
				           |%2';"),
				Selection.Description,
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
		CertificateProperties = DigitalSignature.CertificateProperties(CryptoCertificate);
		
		Properties = New Structure;
		Properties.Insert("Thumbprint",     CertificateProperties.Thumbprint);
		Properties.Insert("Presentation", CertificateProperties.IssuedTo);
		Properties.Insert("Certificate",    CertificateData);
		
		CertificatesProperties.Add(Properties);
	EndDo;
	
	Return PutToTempStorage(CertificatesProperties, FormIdentifier);
	
EndFunction


&AtClient
Function WriteEncryptionCertificates(FormIdentifier, Error)
	
	ObjectsDetails = New Array;
	If DataDetails.Property("Data") Then
		AddObjectDetails(ObjectsDetails, DataDetails);
	Else
		For Each DataElement In DataDetails.DataSet Do
			AddObjectDetails(ObjectsDetails, DataElement);
		EndDo;
	EndIf;
	
	CertificatesAddress = DataDetails.EncryptionCertificates;
	
	Error = New Structure;
	WriteEncryptionCertificatesAtServer(ObjectsDetails, CertificatesAddress, FormIdentifier, Error);
	
	Return Not ValueIsFilled(Error);
	
EndFunction

// Returns:
//   Structure:
//     * Ref - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
//
&AtClient
Function ObjectDetails(DataElement)
	
	ObjectVersion = Undefined;
	DataElement.Property("ObjectVersion", ObjectVersion);
	
	ObjectDetails = New Structure;
	ObjectDetails.Insert("Ref", DataElement.Object);
	ObjectDetails.Insert("Version", ObjectVersion);
	
	Return ObjectDetails;
	
EndFunction

&AtClient
Procedure AddObjectDetails(ObjectsDetails, DataElement)
	
	If Not DataElement.Property("Object") Then
		Return;
	EndIf;
	
	ObjectsDetails.Add(ObjectDetails(DataElement));
	
EndProcedure

// Parameters:
//   ObjectsDetails - Array of See ObjectDetails
//
&AtServerNoContext
Procedure WriteEncryptionCertificatesAtServer(ObjectsDetails, CertificatesAddress, FormIdentifier, Error)
	
	CertificatesProperties = GetFromTempStorage(CertificatesAddress);
	
	BeginTransaction();
	Try
		For Each ObjectDetails In ObjectsDetails Do
			DigitalSignature.WriteEncryptionCertificates(ObjectDetails.Ref,
				CertificatesProperties, FormIdentifier, ObjectDetails.Version);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		Error.Insert("ErrorDescription", NStr("en = 'Cannot save the encryption certificates due to:';")
			+ Chars.LF + ErrorProcessing.BriefErrorDescription(ErrorInfo));
	EndTry;
	
EndProcedure

&AtClient
Procedure HandleError(Notification, ErrorAtClient, ErrorAtServer)
	
	If DataDetails.Property("StopExecution") Then
		
		If Not DataDetails.Property("ErrorDescription") Then
			DataDetails.Insert("ErrorDescription");
		EndIf;
		
		DataDetails.ErrorDescription = DigitalSignatureInternalClientServer.GeneralDescriptionOfTheError(
			ErrorAtClient, ErrorAtServer, NStr("en = 'Cannot encrypt data due to:';"));
		
		If IsOpen() Then
			Close(False);
		Else
			ExecuteNotifyProcessing(Notification, False);
		EndIf;
		
	Else
		
		If Not IsOpen() And ProcessingAfterWarning = Undefined Then
			Open();
		EndIf;
		
		AllCertificates = New Array;
		AllCertificates.Add(Certificate);
		For Each String In EncryptionCertificates Do
			If Not ValueIsFilled(String.Certificate)
			 Or AllCertificates.Find(String.Certificate) <> Undefined Then
				Continue;
			EndIf;
			AllCertificates.Add(String.Certificate);
		EndDo;
		AdditionalParameters = New Structure("Certificate", AllCertificates);
		
		DigitalSignatureInternalClient.ShowApplicationCallError(
			NStr("en = 'Cannot encrypt data';"), "",
			ErrorAtClient, ErrorAtServer, AdditionalParameters, ProcessingAfterWarning);
		
		ExecuteNotifyProcessing(Notification, False);
		
	EndIf;
	
EndProcedure

&AtServer
Function GetTheMainCertificate()
	
	Result = Undefined;
	If SpecifiedImmutableCertificateSet Then
		If EncryptionCertificates.Count() > 0 Then
			Result = EncryptionCertificates[0].Certificate;
		EndIf;	
	Else
		Result = Certificate;
	EndIf;
	
	Return Result;
	
EndFunction


#EndRegion

