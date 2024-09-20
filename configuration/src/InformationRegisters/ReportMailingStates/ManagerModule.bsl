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
Procedure FixMailingStart(BulkEmail) Export
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ReportMailingStates");
		LockItem.SetValue("BulkEmail", BulkEmail);
		Block.Lock();
		
		RecordManager = CreateRecordManager();
		RecordManager.BulkEmail = BulkEmail;
		RecordManager.Read();
		
		RecordManager.BulkEmail = BulkEmail;
		RecordManager.LastRunStart = CurrentSessionDate();
		// На случай если ЗафиксироватьРезультатВыполненияРассылки не будет вызван из-
		RecordManager.LastRunCompletion = RecordManager.LastRunStart + 30 * 60; 
		RecordManager.SessionNumber = InfoBaseSessionNumber();
		RecordManager.Executed = False;
		RecordManager.WithErrors = True;
		
		RecordManager.Write(True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

// For internal use.
// 
Procedure FixMailingExecutionResult(BulkEmail, ExecutionResult) Export
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ReportMailingStates");
		LockItem.SetValue("BulkEmail", BulkEmail);
		Block.Lock();
		
		RecordManager = CreateRecordManager();
		RecordManager.BulkEmail = BulkEmail;
		RecordManager.Read();
		
		RecordManager.BulkEmail = BulkEmail;
		RecordManager.WithErrors = ExecutionResult.HadErrors Or ExecutionResult.HasWarnings;
		RecordManager.Executed = ExecutionResult.ExecutedToFolder
			Or ExecutionResult.ExecutedToNetworkDirectory
			Or ExecutionResult.ExecutedAtFTP
			Or ExecutionResult.ExecutedByEmail
			Or Not RecordManager.WithErrors;
		If RecordManager.Executed Then
			RecordManager.SuccessfulStart = RecordManager.LastRunStart;
		EndIf;
		RecordManager.LastRunCompletion = CurrentSessionDate();
		
		RecordManager.Write(True);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

#EndRegion

#EndIf
