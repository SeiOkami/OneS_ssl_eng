///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Called to get versioned spreadsheet documents when writing the object version.
// When the object version report requires
// replacing technical object tabular section by its spreadsheet document presentation, the spreadsheet document is attached to the object version.
//
// Parameters:
//  Ref             - AnyRef - versioned configuration object.
//  SpreadsheetDocuments - Structure:
//   * Key     - String    - spreadsheet document name;
//   * Value - Structure:
//    ** Description - String            - a spreadsheet document description.
//    ** Data       - SpreadsheetDocument - versioned spreadsheet document.
//
Procedure OnReceiveObjectSpreadsheetDocuments(Ref, SpreadsheetDocuments) Export
	
EndProcedure

// Called after parsing the object version that is read from the register.
//  This can be used for additional processing of the version parsing result.
// 
// Parameters:
//  Ref    - AnyRef - versioned configuration object.
//  Result - Structure - result of parsing the version by the versioning subsystem.
//
Procedure AfterParsingObjectVersion(Ref, Result) Export
	
EndProcedure

// Called after defining object attributes from form 
// InformationRegister.ObjectsVersions.SelectObjectAttributes.
// 
// Parameters:
//  Ref           - AnyRef       - versioned configuration object.
//  AttributeTree - FormDataTree - object attribute tree.
//
Procedure OnSelectObjectAttributes(Ref, AttributeTree) Export
	
EndProcedure

// Called upon receiving object attribute presentation.
// 
// Parameters:
//  Ref                - AnyRef - versioned configuration object.
//  AttributeName          - String      - AttributeName as it is set in Designer.
//  AttributeDescription - String      - an output parameter. You can overwrite the retrieved synonym.
//  Visible             - Boolean      - display attribute in version reports.
//
Procedure OnDetermineObjectAttributeDescription(Ref, AttributeName, AttributeDescription, Visible) Export
	
EndProcedure

// Supplements the object with attributes that are stored separately from the object or in the internal part of the object
// that is not displayed in reports.
//
// Parameters:
//  Object - CatalogObject
//         - DocumentObject
//         - ChartOfCalculationTypesObject
//         - ChartOfAccountsObject
//         - ChartOfCharacteristicTypesObject -
//           
//  AdditionalAttributes - ValueTable - collection of additional attributes that are to be saved
//                                              with the object version:
//   * Id - Arbitrary - a unique attribute ID. Required to restore from the object version
//                                    in case the attribute value is stored separately from the object.
//   * Description - String - an attribute description.
//   * Value - Arbitrary - Attribute value.
//
Procedure OnPrepareObjectData(Object, AdditionalAttributes) Export 
	
	
	
EndProcedure

// Restores object attributes values stored separately from the object.
//
// Parameters:
//  Object - CatalogObject
//         - DocumentObject
//         - ChartOfCalculationTypesObject
//         - ChartOfAccountsObject
//         - ChartOfCharacteristicTypesObject -
//           
//   * Ref - AnyRef
//  AdditionalAttributes - ValueTable - collection of additional attributes that were saved
//                                              with the object version:
//   * Id - Arbitrary - a unique attribute ID.
//   * Description - String - an attribute description.
//   * Value - Arbitrary - Attribute value.
//
Procedure OnRestoreObjectVersion(Object, AdditionalAttributes) Export
	
	
	
EndProcedure

#EndRegion