///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
#Region Private

// 
// 
// 
// Parameters:
//  Certificate - CatalogRef.DigitalSignatureAndEncryptionKeysCertificates
// 
// Returns:
//  Boolean - 
//
Function UserAlerted(Certificate) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	CertificateUsersNotifications.IsNotified
	|FROM
	|	InformationRegister.CertificateUsersNotifications AS CertificateUsersNotifications
	|WHERE
	|	CertificateUsersNotifications.Certificate = &Certificate
	|	AND CertificateUsersNotifications.User = &User";

	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Certificate", Certificate);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	SelectionDetailRecords = QueryResult.Select();
	If SelectionDetailRecords.Next() Then
		Return SelectionDetailRecords.IsNotified;
	EndIf;

	Return False;

EndFunction

#EndRegion
#EndIf