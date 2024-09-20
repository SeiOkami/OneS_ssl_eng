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
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	WorkSchedules.Ref AS Ref
		|FROM
		|	Catalog.Calendars AS WorkSchedules
		|WHERE
		|	NOT WorkSchedules.IsFolder";
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, Metadata.Catalogs.Calendars.FullName());
	
	Processed = 0;
	RecordsWithIssuesCount = 0;

	Block = New DataLock;
	LockItem = Block.Add("Catalog.Calendars");
	LockItem.Mode = DataLockMode.Shared;
	
	Selection.Reset();
	While Selection.Next() Do
		LockItem.SetValue("Ref", Selection.Ref);
		RepresentationOfTheReference = String(Selection.Ref);
		BeginTransaction();
		Try
			Block.Lock();
			ScheduleObject = Selection.Ref.GetObject();
			ScheduleObject.ConsiderNonWorkPeriods = True;
			InfobaseUpdate.WriteObject(ScheduleObject);
			Processed = Processed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process work schedule ""%1"" due to:
                      |%2';"), 
				RepresentationOfTheReference, 
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Warning,
				Metadata.Catalogs.Calendars, , 
				MessageText);
		EndTry;
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, Metadata.Catalogs.Calendars.FullName()) Then
		ProcessingCompleted = False;
	EndIf;
	
	ProcedureName = "Catalog.Calendars.ProcessDataForMigrationToNewVersion";
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 failed to process and skipped %2 records.';"), 
			ProcedureName,
			RecordsWithIssuesCount);
		Raise MessageText;
	EndIf;
	
	WriteLogEvent(
		InfobaseUpdate.EventLogEvent(), 
		EventLogLevel.Information, , ,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure %1 processed yet another batch of records: %2.';"),
			ProcedureName,
			Processed));
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf