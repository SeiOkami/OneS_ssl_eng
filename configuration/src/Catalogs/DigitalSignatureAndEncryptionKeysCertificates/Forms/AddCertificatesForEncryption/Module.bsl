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
	
	PlacedFiles = Parameters.PlacedFiles;
	
	ToSearchForIndividuals = New Array;
	
	If ValueIsFilled(PlacedFiles) Then
		
		For Each CertificateFile In PlacedFiles Do
			
			CertificateData = GetFromTempStorage(CertificateFile.Location);
		
			CryptoCertificate = DigitalSignatureInternal.CertificateFromBinaryData(CertificateData);
			If CryptoCertificate = Undefined Then
				NewRow = FilesAreNotCertificates.Add();
				If ValueIsFilled(CertificateFile.FullName) Then
					NewRow.PathToFile = CertificateFile.FullName;
				Else
					NewRow.PathToFile = CertificateFile.FileName;
				EndIf;
			Else
				CertificateProperties = DigitalSignature.CertificateProperties(CryptoCertificate);
				
				If Certificates.FindRows(New Structure("Thumbprint, ValidBefore", 
					CertificateProperties.Thumbprint, CertificateProperties.ValidBefore)).Count() > 0 Then
					Continue;
				EndIf;
				
				IssuedTo = DigitalSignatureInternalClientServer.ConvertIssuedToIntoFullName(CertificateProperties.IssuedTo); // String
				
				NewRow = Certificates.Add();
				NewRow.Presentation = CertificateProperties.Presentation;
				NewRow.IssuedTo = IssuedTo;
				NewRow.CertificateAddress = PutToTempStorage(CryptoCertificate.Unload(), UUID);
				NewRow.Thumbprint = CertificateProperties.Thumbprint;
				NewRow.ValidBefore = CertificateProperties.ValidBefore;
				
				ToSearchForIndividuals.Add(IssuedTo);
			EndIf;
		EndDo;
		
	EndIf;
	
	If Metadata.DefinedTypes.Individual.Type.ContainsType(Type("String")) Then
		Items.CertificatesIndividual.Visible = False;
	Else
		Items.CertificatesIndividual.ToolTip =
			Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.Individual.Tooltip;
	EndIf;
	
	PopulateCertificatesInTable();
	
	If Items.CertificatesIndividual.Visible And ToSearchForIndividuals.Count() > 0 Then
		
		Persons = DigitalSignatureInternal.GetIndividualsByCertificateFieldIssuedTo(ToSearchForIndividuals);
		For Each CurrentRow In Certificates Do
			
			If ValueIsFilled(CurrentRow.Individual) Then
				Continue;
			EndIf;
			
			ArrayOfValues = Persons.Get(CurrentRow.IssuedTo);
			If TypeOf(ArrayOfValues) = Type("Array") And ArrayOfValues.Count() = 1 Then
				CurrentRow.Individual = ArrayOfValues[0];
				CurrentRow.Refresh = True;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Items.FilesAreNotCertificates.Visible = FilesAreNotCertificates.Count() > 0;
	
	If Metadata.DefinedTypes.Organization.Type.ContainsType(Type("String")) Then
		Items.Organization.Visible = False;
	Else
		If Parameters.Property("Organization") Then
			Organization = Parameters.Organization;
		EndIf;
		
		Items.Organization.ToolTip =
			Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates.Attributes.Organization.Tooltip;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_DigitalSignatureAndEncryptionKeysCertificates" Then
		
		If Not Items.CertificatesIndividual.Visible Then
			Return;
		EndIf;
		
		Found4 = Certificates.FindRows(New Structure("Certificate", Source));
		
		If Found4.Count() = 0 Then
			Return;
		EndIf;
		
		IndividualOfCertificate = IndividualOfCertificate(Source);
		For Each CurrentRow In Found4 Do
			CurrentRow.Individual = IndividualOfCertificate;
			CurrentRow.Refresh = False;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CertificatesFormTableItemEventHandlers

&AtClient
Procedure CertificatesOnActivateRow(Item)
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.CertificatesCertificate.Visible = ValueIsFilled(CurrentData.Certificate);
	
	If ExtensionAttached = False Then
		PopulateCertificateDataDetailsAtServer(CurrentData.CertificateAddress);
	ElsIf ExtensionAttached = True Then
		FillCertificateDataDetails(True, CurrentData.CertificateAddress);
	Else
		DigitalSignatureClient.InstallExtension(False, New NotifyDescription(
			"FillCertificateDataDetails", ThisObject, CurrentData.CertificateAddress),
			NStr("en = 'To continue, install the cryptography extension.';"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificatesBeforeAddRow(Item, Cancel, Copy, Parent, IsFolder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure CertificatesIndividualAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	IndividualStartChoice(StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificatesIndividualStartChoice(Item, ChoiceData, StandardProcessing)
	
	IndividualStartChoice(StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificatesPresentationOnChange(Item)
	
	Items.Certificates.CurrentData.Refresh = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowCertificateData(Command)
	
	If Items.Certificates.CurrentData = Undefined Then
		Return;
	EndIf;
	
	AddressOfCertificate = Items.Certificates.CurrentData.CertificateAddress;
	DigitalSignatureClient.OpenCertificate(AddressOfCertificate, True);
	
EndProcedure

&AtClient
Async Procedure AddCertificatesToCatalog(Command)
	
	Success = AddCertificatesToCatalogAtServer();
	Notify("Write_DigitalSignatureAndEncryptionKeysCertificates");
	
	If Success Then
		Response = Await DoQueryBoxAsync(NStr("en = 'Certificates are added. Do you want to close the form?';"), QuestionDialogMode.YesNo);
		If Response = DialogReturnCode.Yes Then
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnCloseIndividualChoiceForm(Value, Var_Parameters) Export

	If Value = Undefined Then
		Return;
	EndIf;
	
	Items.Certificates.CurrentData.Individual = Value;
	Items.Certificates.CurrentData.Refresh = True;

EndProcedure

&AtServer
Procedure PopulateCertificatesInTable()
	
	Query = New Query;
	Query.SetParameter("Thumbprints", Certificates.Unload(, "Thumbprint"));
	
	Query.Text =
	"SELECT
	|	Thumbprints.Thumbprint
	|INTO Thumbprints
	|FROM
	|	&Thumbprints AS Thumbprints
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Certificates.Thumbprint,
	|	Certificates.Individual,
	|	Certificates.Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS Certificates
	|		INNER JOIN Thumbprints AS Thumbprints
	|		ON Certificates.Thumbprint = Thumbprints.Thumbprint";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CertificateRow = Certificates.FindRows(New Structure("Thumbprint", Selection.Thumbprint));
		For Each CurrentRow In CertificateRow Do
			
			If Items.CertificatesIndividual.Visible Then
				CurrentRow.Individual = Selection.Individual;
			EndIf;
			CurrentRow.Certificate     = Selection.Ref;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function IndividualOfCertificate(Certificate)
	
	Return Common.ObjectAttributeValue(Certificate, "Individual");
	
EndFunction

&AtClient
Procedure IndividualStartChoice(StandardProcessing)
	
	CurrentData = Items.Certificates.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.Certificate) And ValueIsFilled(CurrentData.Individual)
		And Not CurrentData.Refresh Then
			StandardProcessing = False;
			ShowValue(, CurrentData.Certificate);
		Return;
	EndIf;
	
	Result = DigitalSignatureInternalServerCall.GetIndividualsByCertificateFieldIssuedTo(
		CurrentData.IssuedTo);
		
	If Not Result.Property("Persons") Then
		Return;
	EndIf;
	
	Persons = Result.Persons.Get(CurrentData.IssuedTo);
	
	StandardProcessing = False;
	
	If Persons = Undefined Then
		ChoiceProcessing = New NotifyDescription("OnCloseIndividualChoiceForm", ThisObject);
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		OpenForm(Result.IndividualChoiceFormPath, FormParameters, ThisObject, , , , ChoiceProcessing,
			FormWindowOpeningMode.LockOwnerWindow);
		Return;
	EndIf;
	
	If Persons.Count() = 1 Then
		If CurrentData.Individual <> Persons[0] Then
			CurrentData.Individual = Persons[0];
		Else
			ChoiceProcessing = New NotifyDescription("OnCloseIndividualChoiceForm", ThisObject);
			FormParameters = New Structure;
			FormParameters.Insert("ChoiceMode", True);
			OpenForm(Result.IndividualChoiceFormPath, FormParameters, ThisObject, , , , ChoiceProcessing,
				FormWindowOpeningMode.LockOwnerWindow);
		EndIf;
		Return;
	EndIf;
	
	FixedSettings = New DataCompositionSettings;

	Filter = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.LeftValue = New DataCompositionField("Ref");
	Filter.ComparisonType = DataCompositionComparisonType.InList;
	Filter.RightValue = Persons;
	Filter.Use = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("FixedSettings", FixedSettings);
	FormParameters.Insert("FilterByReference_", True);
	FormParameters.Insert("ChoiceMode", True);

	ChoiceProcessing = New NotifyDescription("OnCloseIndividualChoiceForm", ThisObject);
	OpenForm(Result.IndividualChoiceFormPath, FormParameters, ThisObject, , , , ChoiceProcessing,
		FormWindowOpeningMode.LockOwnerWindow);
		
EndProcedure

&AtServer
Function AddCertificatesToCatalogAtServer()
	
	Success = True;
	
	For Each CurrentRow In Certificates Do
		
		CertificateParameters = New Structure;
		
		If ValueIsFilled(CurrentRow.Certificate) Then
			If CurrentRow.Refresh Then
				CertificateParameters.Insert("CertificateRef", CurrentRow.Certificate);
			Else
				Continue;
			EndIf;
		EndIf;
		
		CertificateParameters.Insert("Description", CurrentRow.Presentation);
		
		If Items.CertificatesIndividual.Visible And ValueIsFilled(CurrentRow.Individual) Then
			CertificateParameters.Insert("Individual", CurrentRow.Individual);
		EndIf;
		
		If ValueIsFilled(Organization) And Not ValueIsFilled(CurrentRow.Certificate) Then
			CertificateParameters.Insert("Organization", Organization);
		EndIf;
		
		Try
			
			CertificateRef = DigitalSignature.WriteCertificateToCatalog(CurrentRow.CertificateAddress, CertificateParameters);
			CurrentRow.Certificate = CertificateRef;
			CurrentRow.Refresh = False;
			
		Except
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save the %1 certificate: %2';"), CurrentRow.Presentation,
				ErrorProcessing.BriefErrorDescription(ErrorInfo()));
				
			RowIndex = Certificates.IndexOf(CurrentRow);
			Common.MessageToUser(ErrorMessage,, "Certificates[" + RowIndex + "].Presentation");
			Success = False;
			
		EndTry;
		
	EndDo;
	
	Return Success;
	
EndFunction

&AtClient
Async Procedure FillCertificateDataDetails(Result, CertificateAddress) Export
	
	If Result <> True Then
		ExtensionAttached = False;
		PopulateCertificateDataDetailsAtServer(CertificateAddress);
		Return;
	ElsIf ExtensionAttached <> True Then
		ExtensionAttached = True;
	EndIf;
	
	CryptoCertificate = New CryptoCertificate;
	Await CryptoCertificate.InitializeAsync(GetFromTempStorage(CertificateAddress));
	CertificateProperties = DigitalSignatureClient.CertificateProperties(CryptoCertificate);
	
	DigitalSignatureInternalClientServer.FillCertificateDataDetails(
		DetailsOfCertificateData, CertificateProperties);
	
EndProcedure

&AtServer
Procedure PopulateCertificateDataDetailsAtServer(CertificateAddress)
	
	CryptoCertificate = New CryptoCertificate(GetFromTempStorage(CertificateAddress));
	CertificateProperties = DigitalSignature.CertificateProperties(CryptoCertificate);
	
	DigitalSignatureInternalClientServer.FillCertificateDataDetails(
		DetailsOfCertificateData, CertificateProperties);
		
EndProcedure

#EndRegion