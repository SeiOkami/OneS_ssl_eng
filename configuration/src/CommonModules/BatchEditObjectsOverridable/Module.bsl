///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// 
// 
// See BatchEditObjectsClient.ChangeSelectedItems
// 
// Parameters:
//  Objects - Array of MetadataObject
//
// Example:
//	Objects.Add(Metadata.Catalogs._DemoProducts);
//	Objects.Add(Metadata.Catalogs._DemoCounterparties);
//
Procedure OnDefineObjectsWithBatchObjectsModificationCommand(Objects) Export

	

EndProcedure

// Defining metadata objects, in whose manager modules group 
// attribute editing is prohibited.
//
// Parameters:
//   Objects - Map of KeyAndValue - set the key to the full name of the metadata object
//                            attached to the "Bulk edit" subsystem. 
//                            In addition, the value can include export function names:
//                            "AttributesToSkipInBatchProcessing",
//                            "AttributesToEditInBatchProcessing".
//                            Every name must start with a new line.
//                            In case there is a "*", the manager module has both functions specified.
//
// Example: 
//   Objects.Insert(Metadata.Documents.PurchaserOrders.FullName(), "*"); // both functions are defined.
//   Objects.Insert(Metadata.BusinessProcesses.JobWithRoleBasedAddressing.FullName(), "AttributesToEditInBatchProcessing");
//   Objects.Insert(Metadata.Catalogs.Partners.FullName(), "AttributesToEditInBatchProcessing
//		|AttributesToSkipInBatchProcessing");
//
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	
	
	
EndProcedure

// 
// 
// 
// 
// 
// Parameters:
//  Object - MetadataObject -
//  AttributesToEdit - Undefined, Array of String -
//                                                            
//  AttributesToSkip - Undefined, Array of String -
// 
Procedure OnDefineEditableObjectAttributes(Object, AttributesToEdit, AttributesToSkip) Export

EndProcedure

#EndRegion
