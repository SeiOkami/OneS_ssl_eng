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
//
// 
// See ObjectAttributesLock.DescriptionOfAttributeToLock
//
// 
// 
//
// Parameters:
//   Objects - Map of KeyAndValue:
//     * Key - String - a full name of the metadata object attached to the subsystem;
//     * Value - String - empty string.
//
// Example:
//   
//
//   
//   // See ObjectAttributesLockOverridable.OnDefineLockedAttributes.LockedAttributes
//   
//   	
//   	
//   	
//   	
//   	
//   	
//   	
//   	
//   	
//   
//
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	
	
	
EndProcedure

// Allows overriding the list of locked attributes specified in the object manager module.
//
// Parameters:
//   MetadataObjectName - String - for example, "Catalog.Files".
//   LockedAttributes - Array of See ObjectAttributesLock.DescriptionOfAttributeToLock
//
Procedure OnDefineLockedAttributes(MetadataObjectName, LockedAttributes) Export
	
EndProcedure

#EndRegion
