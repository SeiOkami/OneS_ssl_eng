///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Returns info on the last version check of the valid period-end closing dates.
//
// Returns:
//  Structure:
//   * Date - Date - date and time of the last valid date check.
//
Function LastCheckOfEffectiveClosingDatesVersion() Export
	
	Return New Structure("Date", '00010101');
	
EndFunction

// Returns fields of the metadata object header.
//
// Parameters:
//  Table - String - Full name of a metadata object.
//
// Returns:
//  FixedStructure:
//    * Key - String - Field name.
//    * Value - Undefined
//
Function HeaderFields(Table) Export
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(StrReplace("SELECT * FROM #Table", "#Table", Table));
	
	HeaderFields = New Structure;
	For Each Column In QuerySchema.QueryBatch[0].Columns Do
		HeaderFields.Insert(Column.Alias);
	EndDo;
	
	Return New FixedStructure(HeaderFields);
	
EndFunction

#EndRegion
