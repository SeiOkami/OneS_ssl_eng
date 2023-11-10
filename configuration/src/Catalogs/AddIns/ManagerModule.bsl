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

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region Private

// Returns a reference to the add-in catalog by ID and version.
//
// Parameters:
//  Id - String - Add-in object ID.
//  Version        - String - Add-in version.
//
// Returns:
//  CatalogRef.AddIns - 
//
Function FindByID(Id, Version = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("Id", Id);
	
	If Not ValueIsFilled(Version) Then 
		Query.Text = 
			"SELECT TOP 1
			|	AddIns.Id AS Id,
			|	AddIns.VersionDate AS VersionDate,
			|	CASE
			|		WHEN AddIns.Use = VALUE(Enum.AddInUsageOptions.Used)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS Use,
			|	AddIns.Ref AS Ref
			|FROM
			|	Catalog.AddIns AS AddIns
			|WHERE
			|	AddIns.Id = &Id
			|
			|ORDER BY
			|	Use DESC,
			|	VersionDate DESC";
	Else 
		Query.SetParameter("Version", Version);
		Query.Text = 
			"SELECT TOP 1
			|	AddIns.Ref AS Ref,
			|	CASE
			|		WHEN AddIns.Use = VALUE(Enum.AddInUsageOptions.Used)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS Use
			|FROM
			|	Catalog.AddIns AS AddIns
			|WHERE
			|	AddIns.Id = &Id
			|	AND AddIns.Version = &Version
			|
			|ORDER BY
			|	Use DESC";
		
	EndIf;
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then 
		Return EmptyRef();
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Result.Unload()[0].Ref;
	
EndFunction

#Region UpdateHandlers

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText ="SELECT
	|	AddIns.Ref
	|FROM
	|	Catalog.AddIns AS AddIns";
	
	Query = New Query(QueryText);
	
	InfobaseUpdate.MarkForProcessing(Parameters, Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

// Update handler to v.3.1.6.48: update:
// - Populates compatibility attributes for MacOS browsers in the "Add-ins" catalog.
//
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.AddIns");
	If Selection.Count() > 0 Then
		ProcessExternalComponents(Selection);
	EndIf;

	ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue,
		"Catalog.AddIns");
	Parameters.ProcessingCompleted = ProcessingCompleted;
			
EndProcedure

// Parameters:
//   Selection - QueryResultSelection:
//     * Ref - CatalogRef.AddIns
//
Procedure ProcessExternalComponents(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;

	While Selection.Next() Do

		AddInAttributes = Common.ObjectAttributesValues(Selection.Ref,
			"AddInStorage, MacOS_x86_64_Safari, MacOS_x86_64_Chrome, MacOS_x86_64_Firefox");
		If TypeOf(AddInAttributes.AddInStorage) <> Type("ValueStorage") Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			Continue;
		EndIf;
			
		ComponentBinaryData = AddInAttributes.AddInStorage.Get();
		
		If TypeOf(ComponentBinaryData) <> Type("BinaryData") Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			Continue;
		EndIf;
		
		InformationOnAddInFromFile = AddInsInternal.InformationOnAddInFromFile(
			ComponentBinaryData, False);
		If Not InformationOnAddInFromFile.Disassembled Then
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			Continue;
		EndIf;
		
		Attributes = InformationOnAddInFromFile.Attributes;
		
		If AddInAttributes.MacOS_x86_64_Safari = ?(Attributes.MacOS_x86_64_Safari = Undefined, False,
				Attributes.MacOS_x86_64_Safari)
			And AddInAttributes.MacOS_x86_64_Chrome = ?(Attributes.MacOS_x86_64_Chrome = Undefined, False,
				Attributes.MacOS_x86_64_Chrome)
			And AddInAttributes.MacOS_x86_64_Firefox = ?(Attributes.MacOS_x86_64_Firefox = Undefined, False,
				Attributes.MacOS_x86_64_Firefox) Then
			
			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			Continue;
		EndIf;
		RepresentationOfTheReference = String(Selection.Ref);
		BeginTransaction();
		Try

			Block = New DataLock;
			LockItem = Block.Add("Catalog.AddIns");
			LockItem.SetValue("Ref", Selection.Ref);
			LockItem.Mode = DataLockMode.Shared;
			Block.Lock();

			ComponentObject_SSLs = Selection.Ref.GetObject(); // CatalogObject.AddIns
			ComponentObject_SSLs.MacOS_x86_64_Safari = Attributes.MacOS_x86_64_Safari;
			ComponentObject_SSLs.MacOS_x86_64_Chrome = Attributes.MacOS_x86_64_Chrome;
			ComponentObject_SSLs.MacOS_x86_64_Firefox = Attributes.MacOS_x86_64_Firefox;
			InfobaseUpdate.WriteObject(ComponentObject_SSLs);

			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();

		Except

			RollbackTransaction();
			// 
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;

			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process the %1 add-in due to:
					 |%2';"), RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));

			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning, Selection.Ref.Metadata(), Selection.Ref, MessageText);

		EndTry;

	EndDo;

	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process some add-ins (skipped): %1';"),
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information, Metadata.Catalogs.AddIns,,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Yet another batch of add-ins is processed: %1';"),
			ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf