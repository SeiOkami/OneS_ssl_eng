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

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Load = False) Export
	
	DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "SynchronizedObjectPublicIDs", Load);
	
EndProcedure

// Returns the flag indicating that the register contains a record by the passed filter.
//
// Parameters:
//   RecordStructure - Structure:
//     * InfobaseNode - ExchangePlanRef - an exchange plan node.
//     * Ref - DocumentRef
//              - ChartOfCharacteristicTypesRef
//              - CatalogRef - object reference.
//
// Returns:
//   Boolean - 
//
Function RecordIsInRegister(RecordStructure) Export
	
	Query = New Query(
	"SELECT TOP 1
	|	TRUE AS IsRecord
	|FROM
	|	InformationRegister.SynchronizedObjectPublicIDs AS PIR
	|WHERE
	|	PIR.InfobaseNode = &InfobaseNode
	|	AND PIR.Ref = &Ref");
	Query.SetParameter("InfobaseNode", RecordStructure.InfobaseNode);
	Query.SetParameter("Ref",                 RecordStructure.Ref);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

// Deletes a register record set based on the passed structure values.
Procedure DeleteRecord(RecordStructure, Load = False) Export
	
	DataExchangeInternal.DeleteRecordSetFromInformationRegister(RecordStructure, "SynchronizedObjectPublicIDs", Load);
	
EndProcedure

// Converts a reference to the current infobase object to string UUID presentation.
// If the SynchronizedObjectPublicIDs register has such a reference, UID from the register is returned.
// Otherwise UID of the passed reference is returned.
// 
// Parameters:
//  InfobaseNode - 
//  ObjectReference - 
//                   
//
// Returns:
//  String - 
//
Function PublicIDByObjectRef(InfobaseNode, ObjectReference) Export
	
	SetPrivilegedMode(True);
	
	// Defining a public reference through an object reference.
	Query = New Query(
	"SELECT
	|	PIR.Id AS Id
	|FROM
	|	InformationRegister.SynchronizedObjectPublicIDs AS PIR
	|WHERE
	|	PIR.InfobaseNode = &InfobaseNode
	|	AND PIR.Ref = &Ref");
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("Ref",                 ObjectReference);
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 1 Then
		Selection.Next();
		Return TrimAll(Selection.Id);
	ElsIf Selection.Count() > 1 Then
		RecordStructure = New Structure();
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("Ref",                 ObjectReference);
		DeleteRecord(RecordStructure, True);
	EndIf;
	
	Return TrimAll(ObjectReference.UUID());

EndFunction

#EndRegion

#EndIf