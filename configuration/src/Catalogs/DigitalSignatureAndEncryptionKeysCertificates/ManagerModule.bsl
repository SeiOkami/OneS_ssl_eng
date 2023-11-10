///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	NotAttributesToEdit = New Array;
	NotAttributesToEdit.Add("IssuedTo");
	NotAttributesToEdit.Add("Firm");
	NotAttributesToEdit.Add("LastName");
	NotAttributesToEdit.Add("Name");
	NotAttributesToEdit.Add("MiddleName");
	NotAttributesToEdit.Add("JobTitle");
	NotAttributesToEdit.Add("IssuedBy");
	NotAttributesToEdit.Add("ValidBefore");
	NotAttributesToEdit.Add("Signing");
	NotAttributesToEdit.Add("Encryption");
	NotAttributesToEdit.Add("Thumbprint");
	NotAttributesToEdit.Add("CertificateData");
	NotAttributesToEdit.Add("Application");
	NotAttributesToEdit.Add("Revoked");
	NotAttributesToEdit.Add("EnterPasswordInDigitalSignatureApplication");
	NotAttributesToEdit.Add("Organization");
	NotAttributesToEdit.Add("User");
	NotAttributesToEdit.Add("Added");
	
	If Metadata.DataProcessors.Find("ApplicationForNewQualifiedCertificateIssue") <> Undefined Then
		ProcessingApplicationForNewQualifiedCertificateIssue =
			Common.ObjectManagerByFullName(
				"DataProcessor.ApplicationForNewQualifiedCertificateIssue");
		ProcessingApplicationForNewQualifiedCertificateIssue.AttributesToSkipInBatchProcessing(
			NotAttributesToEdit);
	EndIf;
	
	Return NotAttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region EventsHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ListForm" Then
		StandardProcessing = False;
		Parameters.Insert("ShowCertificatesPage");
		SelectedForm = Metadata.CommonForms.DigitalSignatureAndEncryptionSettings;
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers objects, 
// for which it is necessary to update register records on the InfobaseUpdate exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ElectronicSignatureAndEncryptionKeyCertificatesUsers.Ref,
	|	COUNT(ElectronicSignatureAndEncryptionKeyCertificatesUsers.User) AS User
	|INTO OneUserInTableSection
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates.Users AS
	|		ElectronicSignatureAndEncryptionKeyCertificatesUsers
	|GROUP BY
	|	ElectronicSignatureAndEncryptionKeyCertificatesUsers.Ref
	|HAVING
	|	COUNT(ElectronicSignatureAndEncryptionKeyCertificatesUsers.User) = 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DigitalSignatureAndEncryptionKeysCertificates.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionKeysCertificates AS DigitalSignatureAndEncryptionKeysCertificates
	|		LEFT JOIN OneUserInTableSection AS OneUserInTableSection
	|		ON DigitalSignatureAndEncryptionKeysCertificates.Ref = OneUserInTableSection.Ref
	|WHERE
	|	DigitalSignatureAndEncryptionKeysCertificates.DeleteUserNotifiedOfExpirationDate
	|	OR &StatementCondition
	|	OR NOT OneUserInTableSection.Ref IS NULL";

	
	If DigitalSignature.CommonSettings().CertificateIssueRequestAvailable Then
		
		ModuleApplicationForIssuingANewQualifiedCertificate = Common.CommonModule(
			"DataProcessors.ApplicationForNewQualifiedCertificateIssue");
		Query.Text = StrReplace(Query.Text, "&StatementCondition",
			"DigitalSignatureAndEncryptionKeysCertificates.DeleteStatementStatement <> &EmptyRef");
		Query.SetParameter("EmptyRef", 
			ModuleApplicationForIssuingANewQualifiedCertificate.StatementStatusEmptyRef());
		
	Else
		Query.Text = StrReplace(Query.Text, "OR &StatementCondition", "");
	EndIf;

	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Update register records.
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue,
		"Catalog.DigitalSignatureAndEncryptionKeysCertificates");
	If Selection.Count() > 0 Then
		ProcessApplicationsAndCertificateAlerts(Selection);
	EndIf;

	ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue,
		"Catalog.DigitalSignatureAndEncryptionKeysCertificates");
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#Region Private

Procedure ProcessApplicationsAndCertificateAlerts(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;

	CertificateIssueRequestAvailable = DigitalSignature.CommonSettings().CertificateIssueRequestAvailable;
	
	If CertificateIssueRequestAvailable Then
		ProcessingApplicationForNewQualifiedCertificateIssue =
			Common.ObjectManagerByFullName(
				"DataProcessor.ApplicationForNewQualifiedCertificateIssue");
	EndIf;		
	
	While Selection.Next() Do

		RepresentationOfTheReference = String(Selection.Ref);

		BeginTransaction();
		Try

			Block = New DataLock;
			LockItem = Block.Add("Catalog.DigitalSignatureAndEncryptionKeysCertificates");
			LockItem.SetValue("Ref", Selection.Ref);
			LockItem.Mode = DataLockMode.Shared;
			Block.Lock();

			CertificateObject = Selection.Ref.GetObject(); // CatalogObject.DigitalSignatureAndEncryptionKeysCertificates
			
			// Transfer certificate update notifications into the information register.
			If CertificateObject.DeleteUserNotifiedOfExpirationDate Then
				AlertRecordset = InformationRegisters.CertificateUsersNotifications.CreateRecordSet();
				AlertRecordset.Filter.Certificate.Set(Selection.Ref);

				If CertificateObject.Users.Count() > 0 Then
					
					UsersTable = CertificateObject.Users.Unload();
					UsersTable.GroupBy("User");
					
					For Each UserString In UsersTable Do
						WriteAlertSet = AlertRecordset.Add();
						WriteAlertSet.Certificate = Selection.Ref;
						WriteAlertSet.User = UserString.User;
						WriteAlertSet.IsNotified = True;
					EndDo;
					
				ElsIf ValueIsFilled(CertificateObject.User) Then
					WriteAlertSet = AlertRecordset.Add();
					WriteAlertSet.Certificate = Selection.Ref;
					WriteAlertSet.User = CertificateObject.User;
					WriteAlertSet.IsNotified = True;
				EndIf;
				If AlertRecordset.Count() > 0 Then
					InfobaseUpdate.WriteRecordSet(AlertRecordset, True);
				EndIf;
				CertificateObject.DeleteUserNotifiedOfExpirationDate = False;
			EndIf;
			
			// Transfer request data into the information register.
			If CertificateIssueRequestAvailable
			   And ValueIsFilled(CertificateObject.DeleteStatementStatement) Then
				
				ProcessingApplicationForNewQualifiedCertificateIssue.ProcessDataForMigrationToNewVersion(
					CertificateObject);

			EndIf;
			
			If CertificateObject.Users.Count() = 1 Then
				CertificateObject.User = CertificateObject.Users[0].User;
				CertificateObject.Users.Clear();
			EndIf;

			InfobaseUpdate.WriteObject(CertificateObject);

			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();

		Except

			RollbackTransaction();
			// Если не удалось обработать какой-
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;

			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process certificate %1. Reason:
					 |%2';"), RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));

			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning, Selection.Ref.Metadata(), Selection.Ref, MessageText);

		EndTry;

	EndDo;

	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some certificates: %1';"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			Metadata.Catalogs.DigitalSignatureAndEncryptionKeysCertificates,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of certificates is processed: %1';"), ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
