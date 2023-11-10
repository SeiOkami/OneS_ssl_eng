///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Opens a form to merge items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ItemsToMerge - FormTable
//                          - Array of AnyRef
//                          - ValueList - 
//                            
//     AdditionalParameters - See AttachableCommandsClient.CommandExecuteParameters 
//
Procedure MergeSelectedItems(Val ItemsToMerge, AdditionalParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefSet", ReferencesArrray(ItemsToMerge));
	
	FormOpenParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(FormOpenParameters, AdditionalParameters);
	EndIf;

	OpenForm(
		"DataProcessor.ReplaceAndMergeItems.Form.ItemsMerge",
		FormParameters,
		FormOpenParameters.Owner,
		FormOpenParameters.Uniqueness,
		FormOpenParameters.Window,
		FormOpenParameters.URL,
		FormOpenParameters.OnCloseNotifyDescription,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

// Opens a form to replace and delete items of catalogs, charts of characteristic types, calculation types, and accounts.
//
// Parameters:
//     ReplacedItems - FormTable
//                        - Array
//                        - ValueList - 
//                          
//     AdditionalParameters - See AttachableCommandsClient.CommandExecuteParameters 
//
Procedure ReplaceSelected(Val ReplacedItems, AdditionalParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("RefSet", ReferencesArrray(ReplacedItems));
	FormParameters.Insert("OpenByScenario");
	
	FormOpenParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	If AdditionalParameters <> Undefined Then
		FillPropertyValues(FormOpenParameters, AdditionalParameters);
	EndIf;

	OpenForm(
		"DataProcessor.ReplaceAndMergeItems.Form.ItemsReplacement",
		FormParameters,
		FormOpenParameters.Owner,
		FormOpenParameters.Uniqueness,
		FormOpenParameters.Window,
		FormOpenParameters.URL,
		FormOpenParameters.OnCloseNotifyDescription,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

// Opens the reference occurrence report.
// The report doesn't include auxiliary data, such as record sets with the master dimension.
//
// Parameters:
//     Items - FormTable
//              - FormDataCollection
//              - Array of AnyRef
//              - ValueList - 
//         
//     OpeningParameters - Structure - Form opening parameters. Contains a set of optional fields.
//         Owner, Uniqueness, Window, URL, OnCloseNotifyDetails, WindowOpeningMode corresponding to the OpenForm parameters.
//         
// 
Procedure ShowUsageInstances(Val Items, Val OpeningParameters = Undefined) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure);
	FormParameters.Filter.Insert("RefSet", ReferencesArrray(Items));
	
	FormOpenParameters = New Structure("Owner, Uniqueness, Window, URL, OnCloseNotifyDescription, WindowOpeningMode");
	If OpeningParameters <> Undefined Then
		FillPropertyValues(FormOpenParameters, OpeningParameters);
	EndIf;
	
	OpenForm(
		"Report.SearchForReferences.Form",
		FormParameters,
		FormOpenParameters.Owner,
		FormOpenParameters.Uniqueness,
		FormOpenParameters.Window,
		FormOpenParameters.URL,
		FormOpenParameters.OnCloseNotifyDescription,
		FormOpenParameters.WindowOpeningMode);
	
EndProcedure

#EndRegion

#Region Internal

Function DuplicateObjectsDetectionDataProcessorFormName() Export
	Return "DataProcessor.DuplicateObjectsDetection.Form.SearchForDuplicates";
EndFunction

#EndRegion

#Region Private

// Parameters:
//   Items - FormDataCollection:
//          * Ref - AnyRef
// 	         - ValueList of AnyRef
// 	         - FormTable
//              * Ref - AnyRef
// 	         - Array of AnyRef
// Returns:
//   ValueList, Array of AnyRef, ValueList.
//
Function ReferencesArrray(Val Items)
	
	ParameterType = TypeOf(Items);
	
	If TypeOf(Items) = Type("FormTable") Then
		
		References = New Array;
		For Each Item In Items.SelectedRows Do 
			RowData = Items.RowData(Item);
			If RowData <> Undefined Then
				References.Add(RowData.Ref);
			EndIf;
		EndDo;
		
	ElsIf TypeOf(Items) = Type("FormDataCollection") Then
		
		References = New Array;
		For Each RowData In Items Do
			References.Add(RowData.Ref);
		EndDo;
		
	ElsIf ParameterType = Type("ValueList") Then
		
		References = New Array;
		For Each Item In Items Do
			References.Add(Item.Value);
		EndDo;
		
	Else
		References = Items;
		
	EndIf;
	
	Return References;
EndFunction

#EndRegion
