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

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// SaaSTechnology.ExportImportData

// Returns the catalog attributes
// that naturally form a catalog item key.
//
// Returns:
//  Array - Array of attribute names used to generate a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Code");
	Result.Add("CorrAccount");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf
