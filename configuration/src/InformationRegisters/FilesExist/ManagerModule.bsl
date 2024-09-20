///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers objects, 
// for which it is necessary to update register records on the InfobaseUpdate exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AllFilesOwnersProcessed = False;
	Ref = "";
	While Not AllFilesOwnersProcessed Do
		
		Query = New Query;
		Query.Text =
			"SELECT DISTINCT TOP 1000
			|	Files.Ref AS Ref
			|FROM
			|	Catalog.Files AS Files
			|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
			|		ON Files.FileOwner = FilesExist.ObjectWithFiles
			|WHERE
			|	FilesExist.ObjectWithFiles IS NULL 
			|	AND Files.Ref > &Ref
			|
			|ORDER BY
			|	Ref";
			
		Query.SetParameter("Ref", Ref);
		// 
		ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref"); 
	
		InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
		
		RefsCount = ReferencesArrray.Count();
		If RefsCount < 1000 Then
			AllFilesOwnersProcessed = True;
		EndIf;
		
		If RefsCount > 0 Then
			Ref = ReferencesArrray[RefsCount-1];
		EndIf;
		
	EndDo;
	
EndProcedure

// Update register records.
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.Files");
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		FileOwner = Common.ObjectAttributeValue(Selection.Ref, "FileOwner");
		If Not ValueIsFilled(FileOwner) Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			Continue;
		EndIf;
		RepresentationOfTheReference = String(Selection.Ref);
		BeginTransaction();
		Try
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.Files");
			LockItem.SetValue("Ref", Selection.Ref);
			LockItem.Mode = DataLockMode.Shared;
			Block.Lock();
			
			RecordSetFilesExist = CreateRecordSet();
			RecordSetFilesExist.Filter.ObjectWithFiles.Set(FileOwner);
			
			FilesExistSetRecord                      = RecordSetFilesExist.Add();
			FilesExistSetRecord.ObjectWithFiles       = FileOwner;
			FilesExistSetRecord.HasFiles            = True;
			FilesExistSetRecord.ObjectID = FilesOperationsInternal.GetNextObjectID();
			InfobaseUpdate.WriteRecordSet(RecordSetFilesExist, True);
			
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			// Если не удалось обработать какой-
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process information records about availability of files %1. Reason:
					|%2';"), 
				RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.Files") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) information records about availability of files: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
			EventLogLevel.Information, , ,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of information records about availability of files is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf

