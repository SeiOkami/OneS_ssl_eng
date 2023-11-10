///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// The procedure shifts the edited collection row 
// so that collection rows remain ordered.
//
// Parameters:
//  RowsCollection - Array
//                 - FormDataCollection
//                 - ValueTable
//  OrderField - Name of the element the collection must be sorted by. 
//		
//  CurrentRow - Modified collection row.
//
Procedure RestoreCollectionRowOrderAfterEditing(RowsCollection, OrderField, CurrentRow) Export
	
	If RowsCollection.Count() < 2 Then
		Return;
	EndIf;
	
	If TypeOf(CurrentRow[OrderField]) <> Type("Date") 
		And Not ValueIsFilled(CurrentRow[OrderField]) Then
		Return;
	EndIf;
	
	SourceIndex = RowsCollection.IndexOf(CurrentRow);
	IndexResult = SourceIndex;
	
	// Select the direction in which to shift.
	Direction = 0;
	If SourceIndex = 0 Then
		// вниз
		Direction = 1;
	EndIf;
	If SourceIndex = RowsCollection.Count() - 1 Then
		// вверх
		Direction = -1;
	EndIf;
	
	If Direction = 0 Then
		If RowsCollection[SourceIndex][OrderField] > RowsCollection[IndexResult + 1][OrderField] Then
			// вниз
			Direction = 1;
		EndIf;
		If RowsCollection[SourceIndex][OrderField] < RowsCollection[IndexResult - 1][OrderField] Then
			// вверх
			Direction = -1;
		EndIf;
	EndIf;
	
	If Direction = 0 Then
		Return;
	EndIf;
	
	If Direction = 1 Then
		// Shift till the value in the current row is greater than in the following one.
		While IndexResult < RowsCollection.Count() - 1 
			And RowsCollection[SourceIndex][OrderField] > RowsCollection[IndexResult + 1][OrderField] Do
			IndexResult = IndexResult + 1;
		EndDo;
	Else
		// Shift till the value in the current row is less than in the previous one.
		While IndexResult > 0 
			And RowsCollection[SourceIndex][OrderField] < RowsCollection[IndexResult - 1][OrderField] Do
			IndexResult = IndexResult - 1;
		EndDo;
	EndIf;
	
	RowsCollection.Move(SourceIndex, IndexResult - SourceIndex);
	
EndProcedure

// Regenerates a fixed map by inserting the specified value into it.
//
Procedure InsertIntoFixedMap(FixedMap, Var_Key, Value) Export
	
	Map = New Map(FixedMap);
	Map.Insert(Var_Key, Value);
	FixedMap = New FixedMap(Map);
	
EndProcedure

// Removes value from the fixed map by the specified key.
//
Procedure DeleteFromFixedMap(FixedMap, Var_Key) Export
	
	Map = New Map(FixedMap);
	Map.Delete(Var_Key);
	FixedMap = New FixedMap(Map);
	
EndProcedure

#EndRegion
