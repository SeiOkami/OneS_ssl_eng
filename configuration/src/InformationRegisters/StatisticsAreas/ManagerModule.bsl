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

Function GetRef(Description, ShouldCollectStatistics = False) Export
	DescriptionHash = DescriptionHash(Description);
	
	Ref = FindByHash(DescriptionHash);
	If Ref = Undefined Then
		Ref = CreateNew(Description, DescriptionHash, ShouldCollectStatistics);
	EndIf;
		
	Return Ref;
EndFunction

Function ShouldCollectStatistics(Description) Export
	DescriptionHash = DescriptionHash(Description);
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsAreas.ShouldCollectStatistics
	|FROM
	|	InformationRegister.StatisticsAreas AS StatisticsAreas
	|WHERE
	|	StatisticsAreas.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", DescriptionHash);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		ShouldCollectStatistics = False;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		ShouldCollectStatistics = Selection.ShouldCollectStatistics;
	EndIf;
	
	Return ShouldCollectStatistics
EndFunction

Function DescriptionHash(Description)
	DataHashing = New DataHashing(HashFunction.SHA1);
	DataHashing.Append(Description);
	DescriptionHash = StrReplace(String(DataHashing.HashSum), " ", "");
	
	Return DescriptionHash;
EndFunction

Function FindByHash(Hash)
	Query = New Query;
	Query.Text = "
	|SELECT
	|	StatisticsAreas.AreaID
	|FROM
	|	InformationRegister.StatisticsAreas AS StatisticsAreas
	|WHERE
	|	StatisticsAreas.DescriptionHash = &DescriptionHash
	|";
	Query.SetParameter("DescriptionHash", Hash);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Ref = Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		Ref = Selection.AreaID;
	EndIf;
	
	Return Ref;
EndFunction

Function CreateNew(Description, DescriptionHash, ShouldCollectStatistics)
	BeginTransaction();
	
	Try
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.StatisticsAreas");
		LockItem.SetValue("DescriptionHash", DescriptionHash);
				
		Block.Lock();
		
		Ref = FindByHash(DescriptionHash);
		
		If Ref = Undefined Then
			Ref = New UUID();
			
			RecordSet = CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			NewRecord1 = RecordSet.Add();
			NewRecord1.DescriptionHash = DescriptionHash;
			NewRecord1.AreaID = Ref;
			NewRecord1.Description = Description;
			NewRecord1.ShouldCollectStatistics = ShouldCollectStatistics;
			RecordSet.Write(False);
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
