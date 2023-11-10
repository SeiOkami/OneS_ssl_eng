///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Parameters:
//   List - DynamicList
//   FilterValue - Boolean
//
Procedure SetFilterByDeletionMark(List, FilterValue) Export
	CommonClientServer.SetDynamicListFilterItem(List, "DeletionMark", False,,,
		FilterValue);
EndProcedure

// Generates the result of the MarkedObjectsDeletionClient.StartMarkedObjectsDeletion method call
//
// Returns:
//   Structure:
//   * DeletedItemsCount1 - Number
//   * NotDeletedItemsCount1 - Number
//   * ResultAddress - String
//   * Success - Boolean
//
Function NewDeletionResultsInfo() Export
	Result = New Structure;
	Result.Insert("Trash", New Array);
	Result.Insert("DeletedItemsCount1", 0);
	Result.Insert("NotDeletedItemsCount1", 0);
	Result.Insert("ResultAddress", "");
	Result.Insert("Success", False);
	Return Result;
EndFunction
#EndRegion