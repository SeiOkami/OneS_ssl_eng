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

Function GetLastPackage()
	Query = New Query;
	Query.Text = "
	|SELECT
	|	ISNULL(MAX(PackagesToSend.PackageNumber), 0) AS LastPackage1
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|";
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.LastPackage1;	
EndFunction

Procedure WriteNewPackage(RecordDate, JSONStructure, NextPackageNumber) Export
	JSONStructure.Insert("pn", Format(NextPackageNumber, "NZ=0; NG=0"));
	JSONStructure.Insert("application", String(Metadata.Name));
	JSONStructure.Insert("applicationVersion", String(Metadata.Version));
	
	PackageBody = MonitoringCenterInternal.JSONStructureToString(JSONStructure);
	MD5Hash = New DataHashing(HashFunction.MD5);
	MD5Hash.Append(PackageBody + "hashSalt");
	PackageHash = MD5Hash.HashSum;
	PackageHash = StrReplace(String(PackageHash), " ", "");
	
	RecordSet = CreateRecordSet();
	NewRecord1 = RecordSet.Add();
	NewRecord1.Period = RecordDate;
	NewRecord1.PackageNumber = NextPackageNumber;
	NewRecord1.PackageBody = PackageBody;
	NewRecord1.PackageHash = PackageHash;
	
	RecordSet.DataExchange.Load = True;
	RecordSet.Write(False);
EndProcedure

Procedure DeleteOldPackages() Export
	Query = New Query;
	Query.Text = "
	|SELECT
	|	COUNT(*) AS TotalPackageCount
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|";
	PackagesToSend = MonitoringCenterInternal.GetMonitoringCenterParameters("PackagesToSend");
		
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	TotalPackageCount = Selection.TotalPackageCount;
	
	If TotalPackageCount > PackagesToSend Then
		LastPackage = GetLastPackage();
		
		Query.Text = "SELECT TOP 1000
		|	PackagesToSend.PackageNumber AS PackageNumber
		|FROM
		|	InformationRegister.PackagesToSend AS PackagesToSend
		|WHERE
		|	PackagesToSend.PackageNumber < &LastPackage
		|ORDER BY
		|	PackagesToSend.PackageNumber DESC
		|";
		
		Query.Text = StrReplace(Query.Text, "1000", Format(TotalPackageCount - PackagesToSend, "NG=")); 
		
		Query.SetParameter("LastPackage", LastPackage);
		Result = Query.Execute();
		Selection = Result.Select();
		
		BeginTransaction();
		Try
			RecordSet = CreateRecordSet();
			While Selection.Next() Do
				RecordSet.Filter.PackageNumber.Set(Selection.PackageNumber);
				RecordSet.Write(True);
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()), 
				EventLogLevel.Error, Metadata.InformationRegisters.PackagesToSend,, 
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise;
		EndTry;
		
	EndIf;
EndProcedure

Procedure DeletePackage(PackageNumber) Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber AS PackageNumber
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|WHERE
	|	PackagesToSend.PackageNumber = &PackageNumber
	|";
	
	Query.SetParameter("PackageNumber", PackageNumber);
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	Try
		RecordSet = CreateRecordSet();
		While Selection.Next() Do
			RecordSet.Filter.PackageNumber.Set(Selection.PackageNumber);
			RecordSet.Write(True);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Monitoring center';", Common.DefaultLanguageCode()), 
			EventLogLevel.Error, Metadata.InformationRegisters.PackagesToSend,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
EndProcedure

Function GetPackage(PackageNumber) Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber,
	|	PackagesToSend.PackageBody,
	|	PackagesToSend.PackageHash
	|FROM
	|	InformationRegister.PackagesToSend AS PackagesToSend
	|WHERE
	|	PackagesToSend.PackageNumber = &PackageNumber
	|";
		
	Query.SetParameter("PackageNumber", PackageNumber);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Package = Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		
		Package = New Structure;
		Package.Insert("PackageNumber", Selection.PackageNumber);
		Package.Insert("PackageBody", Selection.PackageBody);
		Package.Insert("PackageHash", Selection.PackageHash);	
	EndIf;
	
	Return Package;
EndFunction

Function GetPackagesNumbers() Export
	Query = New Query;
	
	Query.Text = "
	|SELECT
	|	PackagesToSend.PackageNumber
    |FROM
    |	InformationRegister.PackagesToSend AS PackagesToSend
    |ORDER BY
    |	PackagesToSend.PackageNumber
	|";
	
	Result = Query.Execute();
	PackagesNumbers = New Array;
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		While Selection.Next() Do
			PackagesNumbers.Add(Selection.PackageNumber);
		EndDo;
	EndIf;
	
	Return PackagesNumbers;
EndFunction

Procedure Clear() Export
    
    RecordSet = CreateRecordSet();
    RecordSet.Write(True);
    
EndProcedure

#EndRegion

#EndIf
