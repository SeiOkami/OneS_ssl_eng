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
	
	If DigitalSignature.CommonSettings().CertificateIssueRequestAvailable
	   And Not Parameters.HideApplication Then
		Items.AddCertificateIssueRequest.Visible = True;
	Else
		Items.AddCertificateIssueRequest.Visible = False;
	EndIf;
	
	If Not DigitalSignature.AddEditDigitalSignatures() Then
		
		Items.AddToSignAndEncrypt.Title = NStr("en = 'Add to encrypt and decrypt...';");
		PurposeToSignAndEncrypt = "ToEncryptAndDecrypt";
		
	ElsIf Not DigitalSignature.UseEncryption()
		And Not Items.AddCertificateIssueRequest.Visible Then
	
		Cancel = True;
		Return;
		
	Else
		
		Items.AddToSignAndEncrypt.Title = NStr("en = 'Add to sign and encrypt...';");
		PurposeToSignAndEncrypt = "ToSignEncryptAndDecrypt";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddToSignAndEncrypt(Command)
	
	Close(PurposeToSignAndEncrypt);
	
EndProcedure

&AtClient
Procedure AddFromFiles(Command)
	
	Close("OnlyForEncryptionFromFiles");
	
EndProcedure

&AtClient
Procedure AddFromDirectory(Command)
	
	Close("OnlyForEncryptionFromDirectory");
	
EndProcedure

&AtClient
Procedure AddCertificateIssueRequest(Command)
	
	Close("CertificateIssueRequest");
	
EndProcedure

&AtClient
Procedure AddToEncryptOnly(Command)
	
	Close("ToEncryptOnly");
	
EndProcedure

#EndRegion
