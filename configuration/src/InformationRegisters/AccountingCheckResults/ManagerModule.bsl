///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ListReadingAllowed(ObjectWithIssue)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = Metadata.InformationRegisters.AccountingCheckResults.FullName();
	
	AllIssuesProcessed = False;
	UniqueKey      = CommonClientServer.BlankUUID();
	While Not AllIssuesProcessed Do
		
		Query = New Query;
		Query.Text = "SELECT TOP 1000
			|	AccountingCheckResults.ObjectWithIssue AS ObjectWithIssue,
			|	AccountingCheckResults.CheckRule AS CheckRule,
			|	AccountingCheckResults.CheckKind AS CheckKind,
			|	AccountingCheckResults.UniqueKey AS UniqueKey
			|FROM
			|	InformationRegister.AccountingCheckResults AS AccountingCheckResults
			|WHERE
			|	AccountingCheckResults.UniqueKey > &UniqueKey
			|
			|ORDER BY
			|	UniqueKey";
		
		Query.SetParameter("UniqueKey", UniqueKey);
		Result = Query.Execute().Unload(); // @skip-
	
		InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
		
		RecordsCount = Result.Count();
		If RecordsCount < 1000 Then
			AllIssuesProcessed = True;
		EndIf;
		
		If RecordsCount > 0 Then
			UniqueKey = Result[RecordsCount - 1].UniqueKey;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.AccountingCheckResults;
	FullRegisterName     = RegisterMetadata.FullName();
	FilterPresentation   = NStr("en = 'Object with issues = ""%1""
		|Check rule = ""%2""
		|Check kind = ""%3""
		|Unique key = ""%4""';");
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		BeginTransaction();
		
		Try
			
			ObjectWithIssue = Selection.ObjectWithIssue;
			CheckRule  = Selection.CheckRule;
			CheckKind      = Selection.CheckKind;
			UniqueKey = Selection.UniqueKey;
			
			Block = New DataLock;
			LockItem = Block.Add(FullRegisterName);
			LockItem.SetValue("ObjectWithIssue", ObjectWithIssue);
			LockItem.SetValue("CheckRule",  CheckRule);
			LockItem.SetValue("CheckKind",      CheckKind);
			LockItem.SetValue("UniqueKey", UniqueKey);
			Block.Lock();
			
			RecordSet = CreateRecordSet();
			Filter = RecordSet.Filter;
			Filter.UniqueKey.Set(UniqueKey);
			Filter.ObjectWithIssue.Set(ObjectWithIssue);
			Filter.CheckRule.Set(CheckRule);
			Filter.CheckKind.Set(CheckKind);
			
			FilterPresentation = StringFunctionsClientServer.SubstituteParametersToString(FilterPresentation, ObjectWithIssue, CheckRule, CheckKind, UniqueKey);
			
			RecordSet.Read();
			For Each CurrentRecord In RecordSet Do
				
				If Not ValueIsFilled(CurrentRecord.Checksum) Then
					CurrentRecord.Checksum = AccountingAuditInternal.IssueChecksum(CurrentRecord);
				EndIf;
				
				If CurrentRecord.DeleteIgnoreIssue And Not CurrentRecord.IgnoreIssue Then
					CurrentRecord.IgnoreIssue = CurrentRecord.DeleteIgnoreIssue;
				EndIf;
				
			EndDo;
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process  data integrity check results with filter %2. Reason:
				|%3';"), FilterPresentation, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "InformationRegister.AccountingCheckResults") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some data integrity check results: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
			EventLogLevel.Information, Metadata.InformationRegisters.AccountingCheckResults, ,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of data integrity check results is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf