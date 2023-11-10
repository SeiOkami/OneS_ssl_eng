///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2022, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Removes an infobase prefix and a company prefix from the ObjectNumber string.
// The ObjectNumber variable must comply with the following template: CCIB-XXX…XX or IB-XXX…XX, where:
//    CC - a company prefix.
//    IB - an infobase prefix.
//    "-" - a separator.
//    XXХ…XX - an object number/code.
// Also removes insignificant prefix characters (zeros).
//
// Parameters:
//    ObjectNumber - String - an object number or code from which prefixes are to be removed.
//    DeleteCompanyPrefix - Boolean - shows whether a company prefix is to be removed.
//                                         By default, it is equal to False.
//    DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//                                                By default, it is equal to False.
//
// Returns:
//     String - 
//
// Example:
//    DeletePrefixesFromObjectNumber("0FGL-000001234", True, True) = "000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", False, True) = "F-000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", True, False) = "GL-000001234"
//    DeletePrefixesFromObjectNumber("0FGL-000001234", False, False) = "FGL-000001234"
//
Function DeletePrefixesFromObjectNumber(Val ObjectNumber, DeleteCompanyPrefix = False, DeleteInfobasePrefix = False) Export

	Return ObjectsPrefixesClientServer.DeletePrefixesFromObjectNumber(ObjectNumber, DeleteCompanyPrefix, DeleteInfobasePrefix);

EndFunction

// Removes leading zeros from an object number.
// The ObjectNumber variable must comply with the following template: CCIB-XXX…XX or IB-XXX…XX, where:
// CC - a company prefix.
// IB - an infobase prefix.
// "-" - a separator.
// XXХ…XX - an object number/code.
//
// Parameters:
//    ObjectNumber - String - an object number or code from which leading zeroes are to be removed.
// 
// Returns:
//     String - 
//
Function DeleteLeadingZerosFromObjectNumber(Val ObjectNumber) Export

	Return ObjectsPrefixesClientServer.DeleteLeadingZerosFromObjectNumber(ObjectNumber);

EndFunction

// Removes all custom prefixes (all nonnumeric characters) from an object number.
// The ObjectNumber variable must comply with the following template: CCIB-XXX…XX or IB-XXX…XX, where:
// CC - a company prefix.
// IB - an infobase prefix.
// "-" - a separator.
// XXХ…XX - an object number/code.
//
// Parameters:
//     ObjectNumber - String - an object number or code from which leading zeroes are to be removed.
// 
// Returns:
//     String - 
//
Function DeleteCustomPrefixesFromObjectNumber(Val ObjectNumber) Export

	Return ObjectsPrefixesClientServer.DeleteCustomPrefixesFromObjectNumber(ObjectNumber);

EndFunction

// Gets a custom object number/code prefix.
// The ObjectNumber variable must comply with the following template: CCIB-AAH…XX or IB-AAH…XX, where:
// CC - a company prefix.
// IB - an infobase prefix.
// "-" - a separator.
// AA - a custom prefix.
// XX…XX - an object number/code.
//
// Parameters:
//    ObjectNumber - String - an object number or object code from which a custom prefix is to be received.
// 
// Returns:
//     String - 
//
Function CustomPrefix(Val ObjectNumber) Export

	Return ObjectsPrefixesClientServer.CustomPrefix(ObjectNumber);

EndFunction

// Gets a document number for printing, prefixes and leading zeros are removed from the number.
// Function:
//  removes a company prefix,
// removes an infobase prefix (optional),
// removes custom prefixes (optional),
// removes leading zeros from the object number.
//
// Parameters:
//    ObjectNumber - String - an object number or code that is converted for printing.
//    DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//    DeleteCustomPrefix - Boolean - shows whether a custom prefix is to be removed.
//
// Returns:
//     String - 
//
Function NumberForPrinting(Val ObjectNumber, DeleteInfobasePrefix = False, DeleteCustomPrefix = False) Export

	Return ObjectsPrefixesClientServer.NumberForPrinting(ObjectNumber, DeleteInfobasePrefix, DeleteCustomPrefix);

EndFunction

#EndRegion