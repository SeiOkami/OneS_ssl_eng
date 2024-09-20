///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Returns a reference for the key operation by name.
// If a key operation with the specified name is not found in the catalog, 
// creates a new item.
//
// Parameters:
//  KeyOperationName - String - Key operation name.
//  IsFailed - Boolean - Error flag.
//
// Returns:
//  CatalogRef.KeyOperations
//
Function GetKeyOperationByName(KeyOperationName, TimeConsuming = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
		           |	KeyOperations.Ref AS Ref
		           |FROM
		           |	Catalog.KeyOperations AS KeyOperations
		           |WHERE
		           |	KeyOperations.NameHash = &NameHash
		           |
		           |ORDER BY
		           |	Ref";
	
	MD5Hash = New DataHashing(HashFunction.MD5);
	MD5Hash.Append(KeyOperationName);
	NameHash = MD5Hash.HashSum;
	NameHash = StrReplace(String(NameHash), " ", "");			   
					   
	Query.SetParameter("NameHash", NameHash);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		KeyOperationRef = PerformanceMonitor.CreateKeyOperation(KeyOperationName, 1, TimeConsuming);
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		KeyOperationRef = Selection.Ref;
	EndIf;
	
	Return KeyOperationRef;
	
EndFunction

#Region StandardSubsystemsCachedCopy

// Returns a map of the "functional" subsystem names and the True value.
// A subsystem is considered functional if its "Include in command interface" check box is cleared.
//
Function SubsystemsNames() Export
	
	DisabledSubsystems = PerformanceMonitorInternal.CommonCoreParameters().DisabledSubsystems;
	
	Names = New Map;
	InsertSubordinateSubsystemNames(Names, Metadata, DisabledSubsystems);
	
	Return New FixedMap(Names);
	
EndFunction

Procedure InsertSubordinateSubsystemNames(Names, ParentSubsystem, DisabledSubsystems, ParentSubsystemName = "")
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		If CurrentSubsystem.IncludeInCommandInterface Then
			Continue;
		EndIf;
		
		CurrentSubsystemName = ParentSubsystemName + CurrentSubsystem.Name;
		If DisabledSubsystems.Get(CurrentSubsystemName) = True Then
			Continue;
		Else
			Names.Insert(CurrentSubsystemName, True);
		EndIf;
		
		If CurrentSubsystem.Subsystems.Count() = 0 Then
			Continue;
		EndIf;
		
		InsertSubordinateSubsystemNames(Names, CurrentSubsystem, DisabledSubsystems, CurrentSubsystemName + ".");
	EndDo;
	
EndProcedure

#EndRegion

#Region CommonCachedCopy

// Returns an array of the separators that are in the configuration.
//
// Returns:
//   FixedArray of String - 
//  
//
Function ConfigurationSeparators() Export
	
	SeparatorArray = New Array;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			SeparatorArray.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	
	Return New FixedArray(SeparatorArray);
	
EndFunction

#EndRegion

#EndRegion