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
			|	AddIns.Ref AS Ref
			|FROM
			|	Catalog.CommonAddIns AS AddIns
			|WHERE
			|	AddIns.Id = &Id
			|
			|ORDER BY
			|	AddIns.VersionDate DESC";
	Else 
		Query.SetParameter("Version", Version);
		Query.Text = 
			"SELECT TOP 1
			|	AddIns.Ref AS Ref
			|FROM
			|	Catalog.CommonAddIns AS AddIns
			|WHERE
			|	AddIns.Id = &Id
			|	AND AddIns.Version = &Version";
		
	EndIf;
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then 
		Return EmptyRef();
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Result.Unload()[0].Ref;
	
EndFunction

#EndRegion

#EndIf