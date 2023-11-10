///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Gets details of predefined property sets.
//
// Parameters:
//  Sets - ValueTree:
//     * Name           - String - a property set name. Generated from the full metadata
//          object name by replacing a period (".") by an underscore ("_").
//          For example, Document_SalesOrder.
//     * Id - UUID - a UUID of the predefined property set.
//          Should not be repeated in other property sets.
//          ID format Random UUID (Version 4).
//          To get an ID, in 1C:Enterprise mode calculate the value of
//          the "New UniqueID" platform constructor or use an online generator,
//          for example, https://www.uuidgenerator.net/version4.
//     * Used  - Undefined
//                     - Boolean - 
//          
//          
//     * IsFolder     - Boolean - True if the property set is a folder.
//
Procedure OnGetPredefinedPropertiesSets(Sets) Export
	
	
	
EndProcedure

// Gets descriptions of second-level property sets in different languages.
//
// Parameters:
//  Descriptions - Map of KeyAndValue - a set presentation in the passed language:
//     * Key     - String - a property set name. For example, Catalog_Partners_Common.
//     * Value - String - a set description for the passed language code.
//  LanguageCode - String - a language code. For example, "en".
//
// Example:
//  Descriptions["Catalog_Partners_Common"] = Nstr("ru='Общие'; en='General';", LanguageCode);
//
Procedure OnGetPropertiesSetsDescriptions(Descriptions, LanguageCode) Export
	
	
	
EndProcedure

// Fills object property sets. Usually required if there is more than one set.
//
// Parameters:
//  Object       - AnyRef      - a reference to an object with properties.
//               - ClientApplicationForm - 
//               - FormDataStructure - 
//
//  RefType    - Type - a type of the property owner reference.
//
//  PropertiesSets - ValueTable:
//     * Set - CatalogRef.AdditionalAttributesAndInfoSets
//     * SharedSet - Boolean - True if the property set contains properties
//                             common for all objects.
//    // Then, form item properties of the FormGroup type and the usual group kind
//    // or page that is created if there are more than one set excluding
//    // a blank set that describes properties of deleted attributes group.
//
//    / If the value is Undefined, use the default value.
//
//    // For any managed form group.
//     * Height                   - Number
//     * Title                - String
//     * ToolTip                - String
//     * VerticalStretch   - Boolean
//     * HorizontalStretch - Boolean
//     * ReadOnly           - Boolean
//     * TitleTextColor      - Color
//     * Width                   - Number
//     * TitleFont           - Font
//                    
//    // For usual group and page.
//     * Group              - ChildFormItemsGroup
//
//    // For usual group.
//     * Representation              - UsualGroupRepresentation
//
//    // For page.
//     * Picture                 - Picture
//     * ShowTitle      - Boolean
//
//  StandardProcessing - Boolean - an initial value is True. Indicates whether to get
//                         the default set when PropertiesSets.Count() is equal to zero.
//
//  AssignmentKey   - Undefined - (initial value) - specifies to calculate
//                      the assignment key automatically and add PurposeUseKey and WindowOptionsKey to
//                      form property values
//                      to save form changes (settings, position, and size)
//                      separately for different sets.
//                       For example, for each product kind - its own sets.
//
//                   - String - 
//                      
//                      
//                      
//
//                    
//                    
//                    
//                    
//
Procedure FillObjectPropertiesSets(Val Object, RefType, PropertiesSets, StandardProcessing, AssignmentKey) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemFilling
//
// Parameters:
//  LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//  Items   - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//  TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export
	
	
	
EndProcedure

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.
//
// Parameters:
//  Object                  - CatalogObject.PerformerRoles - Object to populate.
//  Data                  - ValueTableRow - object filling data.
//  AdditionalParameters - Structure:
//   * PredefinedData - ValueTable - data filled in the OnInitialItemFilling procedure.
//
Procedure OnInitialItemFilling(Object, Data, AdditionalParameters) Export
	
EndProcedure

#EndRegion

