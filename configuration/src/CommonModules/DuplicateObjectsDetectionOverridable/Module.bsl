///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Define metadata objects whose manager modules provide parametrization of duplicate search 
// algorithm using the DuplicatesSearchParameters, OnSearchForDuplicates, and 
// CanReplaceItems export procedures.
//
// Parameters:
//   Objects - Map of KeyAndValue - Objects whose manager modules contain export procedures:
//       * Key     - String - Full name of the metadata object attached to the "Duplicate cleaner" subsystem.
//                              For example, "Catalog.Counterparties".
//       * Value - String - names of export handler procedures defined in the manager module:
//                              "DuplicatesSearchParameters",
//                              "OnDuplicatesSearch",
//                              "CanReplaceItems".
//                              Every name must start with a new line.
//                              Empty string means that all procedures are determined in the manager module.
//
// Example:
//  1. All handler procedures are defined in the catalog:
//  Objects.Insert(Metadata.Catalogs.Counterparties.FullName(), "");
//
//  2. Only the DuplicatesSearchParameters and OnDuplicatesSearch procedures are defined:
//  Objects.Insert(Metadata.Catalogs.ProjectTasks.FullName(),"DuplicatesSearchParameters
//                   |OnDuplicatesSearch");
//
Procedure OnDefineObjectsWithSearchForDuplicates(Objects) Export
	
	
	
EndProcedure

// Identify the objects whose list forms
// will display commands for duplicate merging, reference replacement,
// See DuplicateObjectsDetectionClient.MergeSelectedItems and the DuplicateObjectsDetectionClient.ReplaceSelected command
// 
// Parameters:
//     Objects - Array of MetadataObject
//
// Example:
//	Objects.Add(Metadata.Catalogs._DemoProducts);
//	Objects.Add(Metadata.Catalogs._DemoCounterparties);
//
Procedure OnDefineObjectsWithReferenceReplacementDuplicatesMergeCommands(Objects) Export

	

EndProcedure

// Allows to additional check pairs of references on the possibility of replacing one with another.
// For example, you can prohibit to replace the products of different types on each other.
// Basic checks whether the replacement of groups and references of different types are prohibited are made before calling 
// this handler.
//
// Parameters:
//     MetadataObjectName - String - Full name of the reference metadata object whose items are being replaced.
//                                     For example, "Catalog.Counterparties".
//     ReplacementPairs - Map of KeyAndValue:
//       * Key - AnyRef - Value to be replaced.
//       * Value - AnyRef - Replacement value.
//     ReplacementParameters - Structure - Action to perform with the replaced items:
//        * DeletionMethod - String - Valid values:
//                         Directly - If the replaced reference has zero occurrences, delete it directly.
//                                             Mark - If the replaced reference has zero occurrences, mark it for deletion.
//                         With other values, the reference will not be changed.
//                                             
//                         
//     ProhibitedReplacements - Map of KeyAndValue:
//       * Key - AnyRef - Reference being replaced.
//       * Value - String - Explains why a replacement is invalid. If all replacements are valid, returns an empty map.
//
Procedure OnDefineItemsReplacementAvailability(Val MetadataObjectName, Val ReplacementPairs, Val ReplacementParameters, ProhibitedReplacements) Export
	
EndProcedure

// It is called to define application parameters for duplicate search.
// For example, for products catalog, you can prohibit the replacement of different types of products with each other.
//
// Parameters:
//     MetadataObjectName - String - a full name of reference metadata object whose items are replaced.
//                                     For example, "Catalog.Counterparties".
//     SearchParameters - Structure - duplicate search parameters (an output parameter):
//       * SearchRules - ValueTable - object comparison rules:
//         ** Attribute - String - an attribute name to compare.
//         ** Rule  - String - comparison rule: "Equals" - equity comparison, "Similarly" - rows similarity,
//                                "" - do not compare.
//       * StringsComparisonForSimilarity - Structure - rules of rows fuzzy search (rows comparison on similarity):
//          ** StringsMatchPercentage   - Number - minimum percentage of rows matches (from 0 to 100).
//                The match percentage is calculated based on the Damerau-Levenshtein distance, taking into account the common 
//                types of errors: different case of characters, random insertion, deletion of one character, 
//                replacement of one character by another. Also the word order in the rows does not matter. 
//                For example, the rows "first second word" and "word second first" have a 100% match.
//                Default value is 90.
//          ** SmallStringsMatchPercentage - Number - minimum percentage of small rows matches (from 0 to 100).
//                Default value is 80.
//          ** SmallStringsLength - Number - if a row length is less than or equal to the specified one, a row is considered small.
//                Default value is 30.
//          ** ExceptionWords - Array of String - a list of words that must be skipped when comparing similarity.
//                               For example, for companies and counterparties, it can be: IE, SUE, LLC, OJSC.
//       * FilterComposer - DataCompositionSettingsComposer - an initialized composer for 
//                             preliminary filter. Can be changed, for example, to refine the filters.
//       * ComparisonRestrictions - Array of Structure - details of applied restriction rules:
//         ** Presentation      - String - text details of a restriction rule.
//         ** AdditionalFields - String - a list of comma-separated attributes, the values of which
//                                          are required for analysis in the OnDuplicatesSearch.
//       * ItemsCountToCompare - Number -
//                                                   
//     AdditionalParameters - Arbitrary - Value passed when calling DuplicateObjectsDetection.FindItemDuplicates.
//                               When calling from the DuplicateObjectsDetection data processor, the value is Undefined.
//     StandardProcessing - Boolean - if the SearchParameters output parameter is filled in and a call of
//                            the OnDuplicatesSearch handler is required, set to False. Default value is True.
//
Procedure OnDefineDuplicatesSearchParameters(Val MetadataObjectName, SearchParameters, Val AdditionalParameters,
	StandardProcessing) Export
	
	
	
EndProcedure

// 
// 
//
// Parameters:
//     MetadataObjectName - String - a full name of reference metadata object whose items are replaced.
//                                     For example, "Catalog.Counterparties".
//     ItemsDuplicates - ValueTable -
//         * Ref1  - AnyRef - link to the first element.
//         * Ref2  - AnyRef - link to the second element.
//         * IsDuplicates - Boolean      - indicates that the candidates are duplicates. False by default. 
//                                    Can be set to True to mark duplicates.
//         * Fields1    - Structure   -
//                                    
//                                    
//             ** Code - String 
//             ** Description - String
//             ** DeletionMark - Boolean
//         * Fields2    - Structure   -
//             ** Code - String 
//             ** Description - String
//             ** DeletionMark - Boolean
//     AdditionalParameters - Arbitrary - Value passed when calling DuplicateObjectsDetection.FindItemDuplicates.
//                               When calling from the DuplicateObjectsDetection data processor, the value is Undefined.
//
Procedure OnSearchForDuplicates(Val MetadataObjectName, Val ItemsDuplicates, Val AdditionalParameters) Export
	
EndProcedure

#EndRegion
