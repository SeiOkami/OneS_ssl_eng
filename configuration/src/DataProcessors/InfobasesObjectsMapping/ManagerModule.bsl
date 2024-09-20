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

// Maps objects from the current infobase to objects from the source Infobase.
// Generates a mapping table to be displayed to the user.
// Detects the following types of object mapping:
// - objects mapped using references
// - objects mapped using InfobaseObjectsMaps information register data
// - objects mapped using unapproved mapping - mapping items that are not written to the infobase (current changes)
// - unmapped source objects
// - unmapped destination objects (of the current infobase).
//
Procedure MapObjects(Parameters, TempStorageAddress) Export
	
	PutToTempStorage(ObjectMappingResult(Parameters), TempStorageAddress);
	
EndProcedure

// Maps objects automatically using the mapping fields specified by the user (search fields).
// Compares mapping fields using strict equality.
// Generates a table of automatic mapping to be displayed to the user.
//
Procedure ExecuteAutomaticObjectMapping(Parameters, TempStorageAddress) Export
	
	PutToTempStorage(AutomaticObjectMappingResult(Parameters), TempStorageAddress);
	
EndProcedure

#EndRegion

#Region Private
// For internal use.
//
Function ObjectMappingResult(Parameters)
	
	ObjectsMapping = Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, ObjectsMapping);
	
	Cancel = False;
	
	// Applying the table of unapproved mapping items to the database.
	If Parameters.FormAttributes.ApplyOnlyUnapprovedRecordsTable Then
		
		ObjectsMapping.ApplyUnapprovedRecordsTable(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Errors occurred during object mapping.';");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Applying automatic object mapping result obtained by the user.
	If Parameters.FormAttributes.ApplyAutomaticMappingResult Then
		
		// Adding rows to the table of unapproved mapping items
		For Each TableRow In Parameters.AutomaticallyMappedObjectsTable Do
			
			FillPropertyValues(ObjectsMapping.UnapprovedMappingTable.Add(), TableRow);
			
		EndDo;
		
	EndIf;
	
	// Applying the table of unapproved mapping items to the database.
	If Parameters.FormAttributes.ApplyUnapprovedRecordsTable Then
		
		ObjectsMapping.ApplyUnapprovedRecordsTable(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Errors occurred during object mapping.';");
		EndIf;
		
	EndIf;
	
	// 
	ObjectsMapping.MapObjects(Cancel);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during object mapping.';");
	EndIf;
	
	Result = New Structure;
	Result.Insert("ObjectCountInSource",       ObjectsMapping.ObjectCountInSource());
	Result.Insert("ObjectCountInDestination",       ObjectsMapping.ObjectCountInDestination());
	Result.Insert("MappedObjectCount",   ObjectsMapping.MappedObjectCount());
	Result.Insert("UnmappedObjectsCount", ObjectsMapping.UnmappedObjectsCount());
	Result.Insert("MappedObjectPercentage",       ObjectsMapping.MappedObjectPercentage());
	Result.Insert("MappingTable",               ObjectsMapping.MappingTable());
	
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(ObjectsMapping));
	
	Return Result;
EndFunction

// For internal use.
//
Function AutomaticObjectMappingResult(Parameters)
	
	ObjectsMapping = Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, ObjectsMapping);
	
	// 
	ObjectsMapping.UsedFieldsList.Clear();
	CommonClientServer.SupplementTable(Parameters.FormAttributes.UsedFieldsList, ObjectsMapping.UsedFieldsList);
	
	// 
	ObjectsMapping.TableFieldsList.Clear();
	CommonClientServer.SupplementTable(Parameters.FormAttributes.TableFieldsList, ObjectsMapping.TableFieldsList);
	
	// 
	ObjectsMapping.UnapprovedMappingTable.Load(Parameters.UnapprovedMappingTable);
	
	Cancel = False;
	
	// 
	ObjectsMapping.ExecuteAutomaticObjectMapping(Cancel, Parameters.FormAttributes.MappingFieldsList);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during automatic object mapping.';");
	EndIf;
	
	Result = New Structure;
	Result.Insert("EmptyResult", ObjectsMapping.AutomaticallyMappedObjectsTable.Count() = 0);
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(ObjectsMapping));
	
	Return Result;
EndFunction

#EndRegion

#EndIf
