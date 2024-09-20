///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Returns:
//  ValueTableRow of See FormulasConstructorInternal.DescriptionOfFieldLists
//
Function FieldListSettings(Form, NameOfTheFieldList) Export
	
	Filter = New Structure("NameOfTheFieldList", NameOfTheFieldList);
	For Each FieldList In Form.ConnectedFieldLists.FindRows(Filter) Do
		Return FieldList;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function FormulaEditingOptions() Export
	
	Parameters = New Structure;
	Parameters.Insert("Formula");
	Parameters.Insert("Operands");
	Parameters.Insert("Operators");
	Parameters.Insert("OperandsDCSCollectionName");
	Parameters.Insert("OperatorsDCSCollectionName");
	Parameters.Insert("Description");
	Parameters.Insert("ForQuery");
	Parameters.Insert("BracketsOperands", True);
	
	Return Parameters;
	
EndFunction


#EndRegion