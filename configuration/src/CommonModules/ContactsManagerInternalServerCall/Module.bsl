///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Parses contact information presentation and returns an XML string containing parsed field values.
//
//  Parameters:
//      Text        - String - a contact information presentation
//      ExpectedType - CatalogRef.ContactInformationKinds
//                   - EnumRef.ContactInformationTypes - 
//                     
//
//  Returns:
//      String - JSON
//
Function ContactsByPresentation(Val Text, Val ExpectedKind) Export
	Return ContactsManager.ContactsByPresentation(Text, ExpectedKind);
EndFunction

// Returns a composition string from a contact information value.
//
//  Parameters:
//      XMLData - String - XML of contact information data.
//
//  Returns:
//      String - 
//      
//
Function ContactInformationCompositionString(Val XMLData) Export;
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		Return ModuleContactsManagerLocalization.ContactInformationCompositionString(XMLData);
	EndIf;
	
	Return "";
	
EndFunction

// Parameters:
//  Data - See ContactsManagerClientServer.ContactInformationDetails
// 
// Returns:
//  Structure:
//    * XMLData1 - String 
//    * ContactInformationType - EnumRef.ContactInformationTypes
//                              - Undefined
//
Function TransformContactInformationXML(Val Data) Export
	
	If ContactsManagerInternalCached.IsLocalizationModuleAvailable() Then
		ModuleContactsManagerLocalization = Common.CommonModule("ContactsManagerLocalization");
		Return ModuleContactsManagerLocalization.TransformContactInformationXML(Data);
	EndIf;
	
	Return New Structure("ContactInformationType, XMLData1", Undefined, "");
	
EndFunction

// Returns the found reference or creates a new world country record and returns a reference to it.
// 
// Parameters:
//  CountryCode - String 
// 
// Returns:
//   See ContactsManager.WorldCountryByCodeOrDescription
//
Function WorldCountryByClassifierData(Val CountryCode) Export
	
	Return ContactsManager.WorldCountryByCodeOrDescription(CountryCode);
	
EndFunction

// Fills in a collection with references to found or created world country records.
//
Procedure WorldCountriesCollectionByClassifierData(Collection) Export
	
	For Each KeyValue In Collection Do
		Collection[KeyValue.Key] =  ContactsManager.WorldCountryByCodeOrDescription(KeyValue.Value.Code);
	EndDo;
	
EndProcedure

// Fills in the list of address options upon automatic completion by the text entered by the user.
//
Procedure AutoCompleteAddress(Val Text, ChoiceData) Export
	
	ContactsManagerInternal.AutoCompleteAddress(Text, ChoiceData);
	
EndProcedure

#EndRegion
