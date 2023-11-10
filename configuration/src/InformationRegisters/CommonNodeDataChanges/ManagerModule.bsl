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

Function SelectChanges(Val Node, Val MessageNo) Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Cannot select data changes in an active transaction.';");
	EndIf;
	
	Result = New Array;
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Block.Lock();
		
		QueryText =
		"SELECT
		|	CommonNodeDataChanges.InfobaseNode AS Node,
		|	CommonNodeDataChanges.MessageNo AS MessageNo
		|FROM
		|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
		|WHERE
		|	CommonNodeDataChanges.InfobaseNode = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Result.Add(Selection.Node);
			
			If Selection.MessageNo = 0 Then
				
				RecordStructure = New Structure;
				RecordStructure.Insert("InfobaseNode", Node);
				RecordStructure.Insert("MessageNo", MessageNo);
				AddRecord(RecordStructure);
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

Procedure RecordChanges(Val Node) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Block.Lock();
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Node);
		RecordStructure.Insert("MessageNo", 0);
		AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteChangeRecords(Val Node, Val MessageNo = Undefined) Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.SetValue("InfobaseNode", Node);
		Block.Lock();
		
		If MessageNo = Undefined Then
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.InfobaseNode = &Node";
			
		Else
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.InfobaseNode = &Node
			|	AND CommonNodeDataChanges.MessageNo <= &MessageNo
			|	AND CommonNodeDataChanges.MessageNo <> 0";
			
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.SetParameter("MessageNo", MessageNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", Node);
			DeleteRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure)
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

// Deletes a register record set based on the passed structure values.
Procedure DeleteRecord(RecordStructure)
	
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

#EndRegion

#EndIf