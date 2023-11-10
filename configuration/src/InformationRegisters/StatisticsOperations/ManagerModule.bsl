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

Function GetRef(Description) Export
	DataHashing = New DataHashing(HashFunction.SHA1);
	DataHashing.Append(Description);
	DescriptionHash = StrReplace(String(DataHashing.HashSum), " ", "");
	
	Ref = FindByHash(DescriptionHash);
	If Ref = Undefined Then
		Ref = CreateNew(Description, DescriptionHash);
	EndIf;
	
	Return Ref;
EndFunction

Function FindByHash(Hash)
	Query = New Query;
	Query.Text = "
	|SELECT TOP 1
	|	StatisticsOperations.OperationID
	|FROM
	|	InformationRegister.StatisticsOperations AS StatisticsOperations
	|WHERE
	|	StatisticsOperations.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", Hash);
    
    SetPrivilegedMode(True);
	Result = Query.Execute();
    SetPrivilegedMode(False);
    
	If Result.IsEmpty() Then
		Ref = Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		Ref = Selection.OperationID;
	EndIf;
	
	Return Ref;
EndFunction

Function CreateNew(Description, DescriptionHash)
	BeginTransaction();
	
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.StatisticsOperations");
		LockItem.SetValue("DescriptionHash", DescriptionHash);
		Block.Lock();
		
		Ref = FindByHash(DescriptionHash);
		
		If Ref = Undefined Then
			Ref = New UUID();
			
			RecordSet = CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			NewRecord1 = RecordSet.Add();
			NewRecord1.DescriptionHash = DescriptionHash;
			NewRecord1.OperationID = Ref;
			NewRecord1.Description = Description;
            
            SetPrivilegedMode(True);
			RecordSet.Write(False);
            SetPrivilegedMode(False);
            
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Ref;
EndFunction

Function NewCommentPossible(RefOperation) Export
	UniqueMaxCount = 100;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	StatisticsOperations.UniqueCommentsCount AS UniqueValueCount
		|FROM
		|	InformationRegister.StatisticsOperations AS StatisticsOperations
		|WHERE
		|	StatisticsOperations.OperationID = &OperationID";
		
	Query.SetParameter("OperationID", RefOperation);	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	SelectionDetailRecords.Next();
	UniqueValueCount = SelectionDetailRecords.UniqueValueCount;
	
	If UniqueValueCount = Undefined Then
		Return True;
	EndIf;
	
	If UniqueValueCount < UniqueMaxCount Then
		NewCommentPossible = True;
	Else
		NewCommentPossible = False;
	EndIf;
	
	Return NewCommentPossible;
EndFunction

Procedure IncreaseUniqueCommentsCount(RefOperation, RefComment) Export
	RecordSet = CreateRecordSet();
	RecordSet.Filter.OperationID.Set(RefOperation);
	RecordSet.Read();
	For Each CurRecord1 In RecordSet Do
		CurRecord1.UniqueCommentsCount = CurRecord1.UniqueCommentsCount + 1;
	EndDo;
	RecordSet.Write(True);
	
	InformationRegisters.StatisticsOperationComments.CreateRecord(RefOperation, RefComment); 
EndProcedure

#EndRegion

#EndIf