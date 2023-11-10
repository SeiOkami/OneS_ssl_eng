///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

#Region TextExtraction

// Adds and removes records in the TextExtractionQueue information register on change
// state of file version text extraction.
//
// Parameters:
//  TextSource - DefinedType.AttachedFile - file with changed text extraction state.
//  TextExtractionState - EnumRef.FileTextExtractionStatuses - a new status.
//
Procedure UpdateTextExtractionQueueState(TextSource, TextExtractionState) Export
	
	If Not Common.SubsystemExists("CloudTechnology.Core") Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.TextExtractionQueue.CreateRecordSet();
	RecordSet.Filter.DataAreaAuxiliaryData.Set(ModuleSaaSOperations.SessionSeparatorValue());
	RecordSet.Filter.TextSource.Set(TextSource);
	
	If TextExtractionState = Enums.FileTextExtractionStatuses.NotExtracted
			Or TextExtractionState = Enums.FileTextExtractionStatuses.EmptyRef() Then
			
		Record = RecordSet.Add();
		Record.DataAreaAuxiliaryData = ModuleSaaSOperations.SessionSeparatorValue();
		Record.TextSource = TextSource;
			
	EndIf;
		
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region ConfigurationSubsystemsEventHandlers

// See JobsQueueOverridable.OnDefineHandlerAliases.
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export
	
	NamesAndAliasesMap.Insert("FilesOperationsInternal.ExtractTextFromFiles");
	NamesAndAliasesMap.Insert("FilesOperationsInternal.ClearExcessiveFiles");
	NamesAndAliasesMap.Insert("FilesOperationsInternal.ScheduledFileSynchronizationWebdav");
	
EndProcedure

// See JobsQueueOverridable.OnDefineScheduledJobsUsage.
Procedure OnDefineScheduledJobsUsage(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtractionPlanningSaaS";
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
		NewRow.Use = ModuleFullTextSearchServer.UseFullTextSearch();
	Else
		NewRow.Use = False;
	EndIf;
	
EndProcedure

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.CleanUpUnusedFiles.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.FilesSynchronization.Name);
	
EndProcedure

// See ODataInterfaceOverridable.OnPopulateDependantTablesForODataImportExport
Procedure OnPopulateDependantTablesForODataImportExport(Tables) Export
	
	DependentTables = FilesCatalogsAndStorageOptionObjects().StorageObjects;
	For Each DependentTable In DependentTables Do
		Tables.Add(DependentTable.Key);
	EndDo;
	
EndProcedure

// SaaSTechnology.ExportImportData

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.TextExtractionQueue);
	Types.Add(Metadata.Constants.VolumePathIgnoreRegionalSettings);
	
	TypesToExclude = FilesCatalogsAndStorageOptionObjects().StorageObjects;
	For Each IsExcludableType In TypesToExclude Do
		Types.Add(Common.MetadataObjectByFullName(IsExcludableType.Key));
	EndDo;
	
EndProcedure

// See ExportImportDataOverridable.OnRegisterDataExportHandlers.
Procedure OnRegisterDataExportHandlers(HandlersTable) Export
	
	FilesCatalogs = FilesCatalogsAndStorageOptionObjects().FilesCatalogs;
	For Each FilesCatalog In FilesCatalogs Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Common.MetadataObjectByFullName(FilesCatalog.Key);
		NewHandler.Handler = FilesOperationsInternalSaaS;
		NewHandler.BeforeExportObject = True;
		NewHandler.Version = "1.0.0.1";
		
	EndDo;
	
	If HandlersTable.Find(Metadata.Catalogs.Files, "MetadataObject") = Undefined Then
	
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Metadata.Catalogs.Files;
		NewHandler.Handler = FilesOperationsInternalSaaS;
		NewHandler.BeforeExportObject = True;
		NewHandler.Version = "1.0.0.1";
	
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnRegisterDataImportHandlers.
Procedure OnRegisterDataImportHandlers(HandlersTable) Export
	
	FilesCatalogs = FilesCatalogsAndStorageOptionObjects().FilesCatalogs;
	For Each FilesCatalog In FilesCatalogs Do
		
		NewHandler = HandlersTable.Add();
		NewHandler.MetadataObject = Common.MetadataObjectByFullName(FilesCatalog.Key);
		NewHandler.Handler = FilesOperationsInternalSaaS;
		NewHandler.BeforeImportObject = True;
		NewHandler.Version = "1.0.0.1";
		
	EndDo;
	
EndProcedure

// Attached in the ExportImportDataOverridable.OnRegisterDataExportHandlers.
//
// Parameters:
//   Container - DataProcessorObject.ExportImportDataContainerManager
//   ObjectExportManager - DataProcessorObject.ExportImportDataInfobaseDataExportManager
//   Serializer - XDTOSerializer
//   Object - ConstantValueManager
//          - CatalogObject
//          - DocumentObject
//          - BusinessProcessObject
//          - TaskObject
//          - ChartOfAccountsObject
//          - ExchangePlanObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - SequenceRecordSet
//          - RecalculationRecordSet
//   Artifacts - Array of XDTODataObject
//   Cancel - Boolean
//
Procedure BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	If TypeOf(Object) = Type("CatalogObject.Files") Then
		ClearRefToFilesStorageVolume(Object);
		If Object.StoreVersions Then
			Return;
		EndIf;
	EndIf;
	
	If Object.IsFolder Then
		Return;
	EndIf;
	
	FilesCatalogs = FilesCatalogsAndStorageOptionObjects().FilesCatalogs;
	
	Handler = FilesCatalogs.Get(Object.Metadata().FullName());
	
	If Handler = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Handler %2 cannot handle
				|metadata object %1.';",
				Common.DefaultLanguageCode()),
			Object.Metadata().FullName(), "FilesOperationsInternalSaaS.BeforeExportObject()");
		
	EndIf;
	
	HandlerModule = Common.CommonModule(Handler);
	FileExtention = HandlerModule.FileExtention(Object);
	FileName = Container.CreateCustomFile(FileExtention);
	
	Try
		
		HandlerModule.ExportFile(Object, FileName);
		
		Artifact = XDTOFactory.Create(FileArtifactType());
		Artifact.RelativeFilePath = Container.GetRelativeFileName(FileName);
		Artifacts.Add(Artifact);
		
	Except
		
		ErrorInfo = ErrorInfo();
		
		If Common.SubsystemExists("CloudTechnology.Core") Then
		
			ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
			If CommonClientServer.CompareVersions(ModuleSaaSTechnology.LibraryVersion(), "2.0.2.15") >= 0 Then
				Warning = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Export of file %1 (type %2) is skipped due to 
					|%3';"),
					Object,
					Object.Metadata().FullName(),
					ErrorProcessing.BriefErrorDescription(ErrorInfo));
				
				Container.AddWarning(Warning);
			EndIf;
			
		EndIf;
		
		WriteLogEvent(
			NStr("en = 'Files.Export data to go to SaaS';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Object.Metadata(),
			Object.Ref,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
			
		Container.ExcludeFile(FileName);
		
	EndTry;
	
	ClearRefToFilesStorageVolume(Object);
	
EndProcedure

// Attached in the ExportImportDataOverridable.OnRegisterDataImportHandlers.
//
// Parameters:
//   Container - DataProcessorObject.ExportImportDataContainerManager
//   Object - ConstantValueManager
//          - CatalogObject
//          - DocumentObject
//          - BusinessProcessObject
//          - TaskObject
//          - ChartOfAccountsObject
//          - ExchangePlanObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - SequenceRecordSet
//          - RecalculationRecordSet
//   Artifacts - Array of XDTODataObject
//   Cancel - Boolean
//
Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	FilesCatalogs = FilesCatalogsAndStorageOptionObjects().FilesCatalogs;
	
	Handler = FilesCatalogs.Get(Object.Metadata().FullName());
	
	If Handler = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Handler %2 cannot handle
				|metadata object %1.';", Common.DefaultLanguageCode()),
			Object.Metadata().FullName(), "FilesOperationsInternalSaaS.BeforeExportObject()");
		
	EndIf;
	
	HandlerModule = Common.CommonModule(Handler);
	
	For Each Artifact In Artifacts Do
		
		If Artifact.Type() = FileArtifactType() Then
			
			HandlerModule.ImportFile_(Object, Container.GetFullFileName(Artifact.RelativeFilePath));
			
		EndIf;
		
	EndDo;
	
EndProcedure

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Private

// ACC:299-disable - event and infobase update handlers.

#Region InfobaseUpdate

// Fills text extraction queue for the current data area. Is used for initial filling on
// refresh.
//
Procedure FillTextExtractionQueue() Export
	
	IsSeparatedConfiguration = False;
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		IsSeparatedConfiguration = ModuleSaaSOperations.IsSeparatedConfiguration();
	EndIf;
	
	If Not IsSeparatedConfiguration Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = FilesOperationsInternal.QueryTextToExtractText(True);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		UpdateTextExtractionQueueState(Selection.Ref,
			Enums.FileTextExtractionStatuses.NotExtracted);
	EndDo;
	
EndProcedure

#EndRegion

// ACC:299-on

#Region TextExtraction

// Determines the list of data areas where text extraction is required and plans
// it using the job queue.
//
Procedure HandleTextExtractionQueue() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.TextExtractionPlanningSaaS);
	
	If Not Common.DataSeparationEnabled()
		Or Not Common.IsWindowsServer() Then
		Return;
	EndIf;
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	
	SeparatedMethodName = "FilesOperationsInternal.ExtractTextFromFiles";
	
	QueryText = 
	"SELECT DISTINCT
	|	TextExtractionQueue.DataAreaAuxiliaryData AS DataArea,
	|	CASE
	|		WHEN TimeZones.Value = """"
	|			THEN UNDEFINED
	|		ELSE ISNULL(TimeZones.Value, UNDEFINED)
	|	END AS TimeZone
	|FROM
	|	InformationRegister.TextExtractionQueue AS TextExtractionQueue
	|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
	|		LEFT JOIN InformationRegister.DataAreas AS DataAreas
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = DataAreas.DataAreaAuxiliaryData
	|WHERE
	|	NOT TextExtractionQueue.DataAreaAuxiliaryData IN (&DataAreasToProcess)
	|	AND DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
	Query = New Query(QueryText);
	Query.SetParameter("DataAreasToProcess", ModuleJobsQueue.GetTasks(
		New Structure("MethodName", SeparatedMethodName)));
		
	If TransactionActive() Then
		Raise(NStr("en = 'The transaction is active. Cannot execute a query in the transaction.';"));
	EndIf;
	
	AttemptsNumber = 0;
	
	Result = Undefined;
	While True Do
		Try
			Result = Query.Execute(); // 
			                                // 
			                                // 
			Break;
		Except
			AttemptsNumber = AttemptsNumber + 1;
			If AttemptsNumber = 5 Then
				Raise;
			EndIf;
		EndTry;
	EndDo;
		
	Selection = Result.Select();
	While Selection.Next() Do
		// Check for data area lock.
		If ModuleSaaSOperations.DataAreaLocked(Selection.DataArea) Then
			// The area is locked, proceeding to the next record.
			Continue;
		EndIf;
		
		NewJob = New Structure();
		NewJob.Insert("DataArea", Selection.DataArea);
		NewJob.Insert("ScheduledStartTime", ToLocalTime(CurrentUniversalDate(), Selection.TimeZone));
		NewJob.Insert("MethodName", SeparatedMethodName);
		ModuleJobsQueue.AddJob(NewJob);
	EndDo;
	
EndProcedure

#EndRegion

#Region Other

Function FileArtifactType()
	
	Return XDTOFactory.Type(Package(), "FileArtefact");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/Files/1.0.0.1";
	
EndFunction

Function FilesCatalogsAndStorageOptionObjects()
	
	Return FilesOperationsInternalSaaSCached.FilesCatalogsAndStorageOptionObjects();
	
EndFunction

Procedure ClearRefToFilesStorageVolume(Object)
	
	For Each ObjectAttribute In Object.Metadata().Attributes Do
		If ObjectAttribute.Type.ContainsType(Type("CatalogRef.FileStorageVolumes")) 
			And ValueIsFilled(Object[ObjectAttribute.Name]) Then
			Object[ObjectAttribute.Name] = Undefined;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
