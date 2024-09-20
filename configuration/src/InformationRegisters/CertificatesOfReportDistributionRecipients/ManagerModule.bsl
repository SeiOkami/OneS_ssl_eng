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

// For internal use.
// 
Procedure SaveCertificateForDistributionRecipient(BulkEmailRecipient, CertificateToEncrypt) Export
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.CertificatesOfReportDistributionRecipients");
		LockItem.SetValue("BulkEmailRecipient", BulkEmailRecipient);
		Block.Lock();
		
		RecordManager = CreateRecordManager();
		RecordManager.BulkEmailRecipient= BulkEmailRecipient;
		RecordManager.Read();
		
		RecordManager.BulkEmailRecipient = BulkEmailRecipient;
		RecordManager.CertificateToEncrypt = CertificateToEncrypt;

		RecordManager.Write(True);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

#EndRegion

#EndIf
