///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// The handler of the CheckSharedObjectsOnWrite event subscription.
//
// Parameters:
//   Source - AnyRef - an event source.
//   Cancel    - Boolean - shows whether writing is canceled.
//
Procedure CheckSharedObjectsOnWrite(Source, Cancel) Export
	
	// 
	// 
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	ModuleSaaSOperations.CheckSharedObjectsOnWrite(Source, Cancel);
	
EndProcedure

// The handler of the CheckSharedRecordsSetsOnWrite event subscription.
//
// Parameters:
//   Source  - InformationRegisterRecordSet - an event source.
//   Cancel     - Boolean - indicates whether the record of set to the infobase is canceled.
//   Replacing - Boolean - a set record mode. True - writes with replacement of
//             the records set in the infobase. False - writes with
//             the addition of the current records set.
//
Procedure CheckSharedRecordsSetsOnWrite(Source, Cancel, Replacing) Export
	
	// 
	// 
	If Not Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	ModuleSaaSOperations.CheckSharedRecordsSetsOnWrite(Source, Cancel, Replacing);
	
EndProcedure

#EndRegion
