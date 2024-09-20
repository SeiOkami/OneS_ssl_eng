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
Procedure CommitResultOfDistributionToRecipient(HistoryFields) Export
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ReportsDistributionHistory");
		LockItem.SetValue("ReportMailing", HistoryFields.ReportMailing);
		LockItem.SetValue("Recipient", HistoryFields.Recipient);
		LockItem.SetValue("StartDistribution", HistoryFields.StartDistribution);
		Block.Lock();
		
		RecordManager = CreateRecordManager();
		RecordManager.ReportMailing = HistoryFields.ReportMailing;
		RecordManager.Recipient      = HistoryFields.Recipient;
		RecordManager.StartDistribution  = HistoryFields.StartDistribution; 
		RecordManager.Account   = HistoryFields.Account;
		RecordManager.EMAddress         = HistoryFields.EMAddress;
		RecordManager.Period          = HistoryFields.Period;
		RecordManager.Read();
		
		RecordManager.Comment = ?(ValueIsFilled(RecordManager.Comment), RecordManager.Comment + Chars.LF
			+ HistoryFields.Comment, HistoryFields.Comment);
		FillPropertyValues(RecordManager, HistoryFields, , "Comment");

		RecordManager.Write(True);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

#EndRegion

#EndIf
