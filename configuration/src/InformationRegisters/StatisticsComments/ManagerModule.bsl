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

Function GetRef(Description, OperationRef) Export
	If Description <> Undefined Then 
		DataHashing = New DataHashing(HashFunction.SHA1);
		DataHashing.Append(Description);
		DescriptionHash = StrReplace(String(DataHashing.HashSum), " ", "");
		
		References = FindByHash(DescriptionHash, OperationRef);
		If References.RefComment = Undefined Then
			If InformationRegisters.StatisticsOperations.NewCommentPossible(OperationRef) Then
				Ref = CreateNew(Description, DescriptionHash, OperationRef);
			Else
				Ref = GetRefManyComments(OperationRef);
			EndIf;
		Else
			If References.RefOperationComment = Undefined Then
				If InformationRegisters.StatisticsOperations.NewCommentPossible(OperationRef) Then
					InformationRegisters.StatisticsOperationComments.CreateRecord(OperationRef, References.RefComment);
					Ref = References.RefComment;
					InformationRegisters.StatisticsOperations.IncreaseUniqueCommentsCount(OperationRef, Ref);
				Else
					Ref = GetRefManyComments(OperationRef);
				EndIf;
			Else
				Ref = References.RefComment;
			EndIf;
		EndIf;
	Else
		Ref = CommonClientServer.BlankUUID();
	EndIf;
		
	Return Ref;
EndFunction

Function GetRefManyComments(RefOperation)
	References = New Structure;
	References.Insert("RefComment", Undefined);
		
	BeginTransaction();
	Try
		DataHashing = New DataHashing(HashFunction.SHA1);
		TooManyComments = NStr("en = 'Too many comments';");
		DataHashing.Append(TooManyComments);
		DescriptionHash = StrReplace(String(DataHashing.HashSum), " ", "");
		
		References = FindByHash(DescriptionHash, RefOperation);
		If References.RefComment = Undefined Then
			Block = New DataLock;
			
			LockItem = Block.Add("InformationRegister.StatisticsComments");
			LockItem.SetValue("DescriptionHash", DescriptionHash);
						
			Block.Lock();
			
			References = FindByHash(DescriptionHash, RefOperation);
			
			If References.RefComment = Undefined Then
				References.RefComment = New UUID();
				
				RecordSet = CreateRecordSet();
				RecordSet.DataExchange.Load = True;
				NewRecord1 = RecordSet.Add();
				NewRecord1.DescriptionHash = DescriptionHash;
				NewRecord1.CommentID = References.RefComment;
				NewRecord1.Description = TooManyComments;
				RecordSet.Write(False);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return References.RefComment;
EndFunction

Function FindByHash(Hash, RefOperation)
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsComments.CommentID AS CommentID,
	|	ISNULL(StatisticsOperationComments.CommentID, UNDEFINED) AS OperationCommentID
	|FROM
	|	InformationRegister.StatisticsComments AS StatisticsComments
	|LEFT JOIN
	|	InformationRegister.StatisticsOperationComments AS StatisticsOperationComments
	|ON
	|	StatisticsOperationComments.OperationID = &OperationID
	|	AND StatisticsOperationComments.CommentID = StatisticsComments.CommentID
	|WHERE
	|	StatisticsComments.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", Hash);
	Query.SetParameter("OperationID", RefOperation);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		References = New Structure;
		References.Insert("RefComment", Undefined);
		References.Insert("RefOperationComment", Undefined);
	Else
		Selection = Result.Select();
		Selection.Next();
		
		References = New Structure;
		References.Insert("RefComment", Selection.CommentID);
		References.Insert("RefOperationComment", Selection.OperationCommentID);
	EndIf;
	
	Return References;
EndFunction

Function CreateNew(Description, DescriptionHash, OperationRef)
	BeginTransaction();
	
	Try
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.StatisticsComments");
		LockItem.SetValue("DescriptionHash", DescriptionHash);
				
		LockItem = Block.Add("InformationRegister.StatisticsOperations");
		LockItem.SetValue("OperationID", OperationRef);
				
		Block.Lock();
		
		References = FindByHash(DescriptionHash, OperationRef);
		
		If References.RefComment = Undefined Then
			Ref = New UUID();
			
			RecordSet = CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			NewRecord1 = RecordSet.Add();
			NewRecord1.DescriptionHash = DescriptionHash;
			NewRecord1.CommentID = Ref;
			NewRecord1.Description = Description;
			RecordSet.Write(False);
			
			InformationRegisters.StatisticsOperations.IncreaseUniqueCommentsCount(OperationRef, Ref);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Ref;
EndFunction

#EndRegion

#EndIf
