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

Procedure CreateRecord(StatisticsOperation, StatisticsComment) Export
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.StatisticsOperationComments");
		LockItem.SetValue("OperationID", StatisticsOperation);
		LockItem.SetValue("CommentID", StatisticsComment);
		Block.Lock();
		
		If Not IsRecord(StatisticsOperation, StatisticsComment) Then
			RecordSet = CreateRecordSet();
			NewRecord1 = RecordSet.Add();
			NewRecord1.OperationID = StatisticsOperation; 
			NewRecord1.CommentID = StatisticsComment;
			
			RecordSet.DataExchange.Load = True;
			RecordSet.Write(False);
		EndIf;
				
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

Function IsRecord(StatisticsOperation, StatisticsComment)
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(*) AS RecordsCount
		|FROM
		|	InformationRegister.StatisticsOperationComments AS StatisticsOperationComments
		|WHERE
		|	StatisticsOperationComments.OperationID = &OperationID
		|	AND StatisticsOperationComments.CommentID = &CommentID
		|";
	
	Query.SetParameter("CommentID", StatisticsComment);
	Query.SetParameter("OperationID", StatisticsOperation);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	SelectionDetailRecords.Next();
	
	If SelectionDetailRecords.RecordsCount = 0 Then
		Return False;
	Else
		Return True;
	EndIf;
EndFunction

#EndRegion

#EndIf