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
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesVersions.Ref
		|FROM
		|	Catalog.FilesVersions AS FilesVersions
		|		LEFT JOIN InformationRegister.BinaryFilesData AS BinaryFilesData
		|		ON FilesVersions.Ref = BinaryFilesData.File
		|WHERE
		|	BinaryFilesData.File IS NULL
		|	AND FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase)
		|
		|ORDER BY
		|	FilesVersions.UniversalModificationDate DESC";
	
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BinaryFilesData.File AS Ref
	|FROM
	|	InformationRegister.BinaryFilesData AS BinaryFilesData
	|WHERE
	|	VALUETYPE(BinaryFilesData.File) = &FileType";
	
	Query.SetParameter("FileType", TypeOf(Catalogs.Files.EmptyRef()));
	
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

// Update register records.
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.FilesVersions");
	If Selection.Count() > 0 Then
		MoveBinaryFileDataToTheDataRegisterBinaryFileData(Selection);
	EndIf;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.Files");
	If Selection.Count() > 0 Then
		ToCreateTheMissingVersionFile(Selection);
	EndIf;
	
	ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.FilesVersions")
		And InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.Files");
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#Region Private

Procedure MoveBinaryFileDataToTheDataRegisterBinaryFileData(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.DeleteStoredVersionFiles");
			DataLockItem.SetValue("FileVersion", Selection.Ref);
			DataLockItem.Mode = DataLockMode.Shared;
			DataLock.Lock();
			
			WriteFileVersionManager = InformationRegisters.DeleteStoredVersionFiles.CreateRecordManager();
			WriteFileVersionManager.FileVersion = Selection.Ref;
			WriteFileVersionManager.Read();
			
			BinaryData = WriteFileVersionManager.StoredFile.Get();
			
			RecordSet = CreateRecordSet();
			RecordSet.Filter.File.Set(Selection.Ref);
			
			SetRecord = RecordSet.Add();
			SetRecord.File = Selection.Ref;
			SetRecord.FileBinaryData = New ValueStorage(BinaryData, New Deflation(9));
			InfobaseUpdate.WriteRecordSet(RecordSet, True);
			
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			// Если не удалось обработать какой-
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process binary data of file %1. Reason:
				|%2';"), 
				Selection.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some binary data of the file: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.FilesVersions,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of binary data of files is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

Procedure ToCreateTheMissingVersionFile(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.Files");
		LockItem.SetValue("Ref", Selection.Ref);
		
		LockItem = Block.Add("InformationRegister.BinaryFilesData");
		LockItem.SetValue("File", Selection.Ref);
		
		BeginTransaction();
		Try
			Block.Lock();
			
			FileObject1 = Selection.Ref.GetObject(); // CatalogObject.Files
			
			If FileObject1 <> Undefined Then
				
				Version = Catalogs.FilesVersions.CreateItem();
				Version.SetNewCode();
				
				PropertiesSet = "Author,Owner,UniversalModificationDate,CreationDate,PictureIndex,
				|Description,DeletionMark, PathToFile,Size,Extension,TextExtractionStatus, TextStorage, FileStorageType, Volume";
				
				FillPropertyValues(Version, FileObject1, PropertiesSet);
				Version.VersionNumber = 1;
				Version.Owner = Selection.Ref;
				
				InfobaseUpdate.WriteObject(Version);
				
				FileObject1.CurrentVersion = Version.Ref;
				InfobaseUpdate.WriteObject(FileObject1);
				
				BinaryFilesData = InformationRegisters.BinaryFilesData.CreateRecordManager();
				BinaryFilesData.File = Selection.Ref;
				BinaryFilesData.Read();
				BinaryFilesData.File = Version.Ref;
				BinaryFilesData.Write();
				
			EndIf;
			
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			
			RollbackTransaction();
			// Если не удалось обработать какой-
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process file %1. Reason:
				|%2';"), 
				Selection.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Selection.Ref.Metadata(), Selection.Ref, MessageText);
			
		EndTry;
		
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some files: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.FilesVersions,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of files is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion


#EndIf
