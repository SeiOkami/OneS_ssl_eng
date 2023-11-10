///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Backward compatibility.
// For calling from the OnInitialItemsFilling handler.
// Fills in columns called AttributeName_<LanguageCode> with text values for the specified language codes.
//
// Parameters:
//  Item        - ValueTableRow -
//  AttributeName   - String -  name of the prop. For Example, " Name"
//  InitialString - String - a string in the NStr format. For example, "ru" = 'Russian message'; en = 'English message'".
//  LanguagesCodes     - Array - codes of languages ​​in which you need to fill in the rows.
// 
// Example:
//
//  NationalLanguageSupportServer.FillMultilingualAttribute(Item, "Description", "ru = 'Russian message'; en =
//  'English message'", LanguageCodes);
//
Procedure FillMultilanguageAttribute(Item, AttributeName, InitialString, LanguagesCodes = Undefined) Export
	
	NationalLanguageSupportServer.FillMultilanguageAttribute(Item, AttributeName, InitialString, LanguagesCodes);
	
EndProcedure

// Backward compatibility.
// Called from the OnCreateAtServer handler of the object form. Adds the open button to the fields for entering
// multilanguage attributes on this form. Clicking the button opens a window for entering the attribute value in all
// configuration languages.
//
// Parameters:
//   Form  - ClientApplicationForm - object form.
//   Object - FormDataStructure:
//     * Ref - AnyRef
//  ObjectName - String - for list forms, the dynamic list name on the form. The default value is "List".
//                        For other forms, the main attribute name on the form. Use it
//                        if the name differs from the default ones: "Object", "Record", or "List".
//
Procedure OnCreateAtServer(Form, Object = Undefined, ObjectName = Undefined) Export
	
	NationalLanguageSupportServer.OnCreateAtServer(Form, Object, ObjectName);
	
EndProcedure

// Backward compatibility.
// It is called from the OnReadAtServer handler of the object form to fill in values of the multilanguage
// form attributes in the current user language.
//
// Parameters:
//  Form         - ClientApplicationForm - object form.
//  CurrentObject - Arbitrary - an object received in the OnReadAtServer form handler.
//  ObjectName - String - the main attribute name on the form. It is used
//                        if the name differs from the default: "Object", "Record", "List".
//
Procedure OnReadAtServer(Form, CurrentObject, ObjectName = Undefined) Export
	
	NationalLanguageSupportServer.OnReadAtServer(Form, CurrentObject, ObjectName);
	
EndProcedure

// Backward compatibility.
// It is called from the BeforeWriteAtServer handler of the object form or when programmatically recording an object
// to record multilingual attribute values in accordance with the current user language.
//
// Parameters:
//  CurrentObject - BusinessProcessObject
//                - DocumentObject
//                - TaskObject
//                - ChartOfCalculationTypesObject
//                - ChartOfCharacteristicTypesObject
//                - ExchangePlanObject
//                - ChartOfAccountsObject
//                - CatalogObject - the object being recorded.
//
Procedure BeforeWriteAtServer(CurrentObject) Export
	
	NationalLanguageSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

// Backward compatibility.
// It is called from the object module to fill in the multilingual
// attribute values of the object in the current user language.
//
// Parameters:
//  Object - BusinessProcessObject
//         - DocumentObject
//         - TaskObject
//         - ChartOfCalculationTypesObject
//         - ChartOfCharacteristicTypesObject
//         - ExchangePlanObject
//         - ChartOfAccountsObject
//         - CatalogObject - data object.
//
Procedure OnReadPresentationsAtServer(Object) Export
	
	NationalLanguageSupportServer.OnReadPresentationsAtServer(Object);

EndProcedure

// Backward compatibility.
// It is called from the ProcessGettingChoiceData handler to form a list during line input,
// automatic text selection and quick selection, as well as when the GetChoiceData method is executed.
// The list contains options in all languages, considering the attributes specified in the LineInput property.
//
// Parameters:
//  ChoiceData         - ValueList - data for the choice.
//  Parameters            - Structure - contains choice parameters.
//  StandardProcessing - Boolean  - this parameter stores the flag of whether the standard (system) event processing is executed.
//  MetadataObject     - MetadataObjectBusinessProcess
//                       - MetadataObjectDocument
//                       - MetadataObjectTask
//                       - MetadataObjectChartOfCalculationTypes
//                       - MetadataObjectChartOfCharacteristicTypes
//                       - MetadataObjectExchangePlan
//                       - MetadataObjectChartOfAccounts
//                       - MetadataObjectCatalog
//                       - MetadataObjectTable - 
//
Procedure ChoiceDataGetProcessing(ChoiceData, Val Parameters, StandardProcessing, MetadataObject) Export
	
	NationalLanguageSupportServer.ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing, MetadataObject);
	
EndProcedure

// Backward compatibility.
// Adds the current language code to a field in the query text.
// Field conversion examples:
//   - If FieldName value is "Properties.Title", the field is converted into "Properties.TitleLanguage1".
//   - If FieldName value is "Properties.Title AS Title", the field is converted into "Properties.TitleLanguage1 AS Title". 
//   
// 
// Parameters:
//  QueryText - String - Text of the query whose field is renamed.
//  FieldName - String - Name of the field to replace.
//
Procedure ChangeRequestFieldUnderCurrentLanguage(QueryText, FieldName) Export
	
	NationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, FieldName);
	
EndProcedure


#EndRegion
