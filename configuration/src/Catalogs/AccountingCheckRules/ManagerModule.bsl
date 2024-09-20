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

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query(
	"SELECT
	|	AccountingCheckRules.Ref AS Ref
	|FROM
	|	Catalog.AccountingCheckRules AS AccountingCheckRules
	|WHERE
	|	AccountingCheckRules.Use
	|	AND AccountingCheckRules.Id IN(&ChecksIDs)");
	
	AccountingChecks = AccountingAuditInternalCached.AccountingChecks().Checks;
	FilterParameters = New Structure;
	FilterParameters.Insert("isDisabled", True);
	DisabledChecks = AccountingChecks.FindRows(FilterParameters);
	
	ChecksIDs = New Array;
	For Each DisabledCheck In DisabledChecks Do
		ChecksIDs.Add(DisabledCheck.Id);
	EndDo;
	
	Query.SetParameter("ChecksIDs", ChecksIDs);
	References = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, References);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	MetadataObject = Metadata.Catalogs.AccountingCheckRules;
	FullObjectName = MetadataObject.FullName();
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	CheckToDIsable = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, FullObjectName);
	While CheckToDIsable.Next() Do
		CheckToDisableRef = CheckToDIsable.Ref;
		RepresentationOfTheReference = String(CheckToDisableRef);
		BeginTransaction();
		
		Try
			
			Block = New DataLock;
			LockItem = Block.Add(FullObjectName);
			LockItem.SetValue("Ref", CheckToDisableRef);
			
			Block.Lock();
			
			CheckToDisableObject = CheckToDisableRef.GetObject();
			CheckToDisableObject.Use = False;
			ObjectsProcessed = ObjectsProcessed + 1;
			
			InfobaseUpdate.WriteData(CheckToDisableObject);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process check rule %1. Reason:
				|%2';"), 
				RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning,
				MetadataObject,
				CheckToDisableRef,
				Comment);
				
			EndTry;
			
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullObjectName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some check rules: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
			EventLogLevel.Information, , ,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Yet another batch of check rules is processed: %1';"),
			ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf