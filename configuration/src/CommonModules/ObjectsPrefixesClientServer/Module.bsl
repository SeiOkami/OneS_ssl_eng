///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
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
	
	If Not NumberContainsStandardPrefix(ObjectNumber) Then
		Return ObjectNumber;
	EndIf;
	
	// Initially blank string of object number prefix.
	ObjectPrefix = "";
	
	NumberContainsFiveDigitPrefix = NumberContainsFiveDigitPrefix(ObjectNumber);
	
	If NumberContainsFiveDigitPrefix Then
		CompanyPrefix        = Left(ObjectNumber, 2);
		InfobasePrefix = Mid(ObjectNumber, 3, 2);
	Else
		CompanyPrefix = "";
		InfobasePrefix = Left(ObjectNumber, 2);
	EndIf;
	
	CompanyPrefix        = StringFunctionsClientServer.DeleteDuplicateChars(CompanyPrefix, "0");
	InfobasePrefix = StringFunctionsClientServer.DeleteDuplicateChars(InfobasePrefix, "0");
	
	// Add a company prefix.
	If Not DeleteCompanyPrefix Then
		
		ObjectPrefix = ObjectPrefix + CompanyPrefix;
		
	EndIf;
	
	// Adding an infobase prefix.
	If Not DeleteInfobasePrefix Then
		
		ObjectPrefix = ObjectPrefix + InfobasePrefix;
		
	EndIf;
	
	If Not IsBlankString(ObjectPrefix) Then
		
		ObjectPrefix = ObjectPrefix + "-";
		
	EndIf;
	
	Return ObjectPrefix + Mid(ObjectNumber, ?(NumberContainsFiveDigitPrefix, 6, 4));
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
	
	CustomPrefix = CustomPrefix(ObjectNumber);
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix = Left(ObjectNumber, 5);
			Number = Mid(ObjectNumber, 6 + StrLen(CustomPrefix));
		Else
			Prefix = Left(ObjectNumber, 3);
			Number = Mid(ObjectNumber, 4 + StrLen(CustomPrefix));
		EndIf;
		
	Else
		
		Prefix = "";
		Number = Mid(ObjectNumber, 1 + StrLen(CustomPrefix));
		
	EndIf;
	
	// 
	Number = StringFunctionsClientServer.DeleteDuplicateChars(Number, "0");
	
	Return Prefix + CustomPrefix + Number;
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
	
	NumericCharactersString = "0123456789";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			Prefix     = Left(ObjectNumber, 5);
			FullNumber = Mid(ObjectNumber, 6);
		Else
			Prefix     = Left(ObjectNumber, 3);
			FullNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	Else
		
		Prefix     = "";
		FullNumber = ObjectNumber;
		
	EndIf;
	
	Number = "";
	
	For IndexOf = 1 To StrLen(FullNumber) Do
		
		Char = Mid(FullNumber, IndexOf, 1);
		
		If StrFind(NumericCharactersString, Char) > 0 Then
			Number = Mid(FullNumber, IndexOf);
			Break;
		EndIf;
		
	EndDo;
	
	Return Prefix + Number;
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
	
	// Function return value (custom prefix).
	Result = "";
	
	If NumberContainsStandardPrefix(ObjectNumber) Then
		
		If NumberContainsFiveDigitPrefix(ObjectNumber) Then
			ObjectNumber = Mid(ObjectNumber, 6);
		Else
			ObjectNumber = Mid(ObjectNumber, 4);
		EndIf;
		
	EndIf;
	
	NumericCharactersString = "0123456789";
	
	For IndexOf = 1 To StrLen(ObjectNumber) Do
		
		Char = Mid(ObjectNumber, IndexOf, 1);
		
		If StrFind(NumericCharactersString, Char) > 0 Then
			Break;
		EndIf;
		
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
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
	
	// {Handler:- an owner object of contact information.
// FormStructureData - an object containing a tabular section with contact information. Supports
// hidden kinds of contact information only for already existing objects
// as it is impossible to set a reference for a new object.} Start
	StandardProcessing = True;
	
	ObjectsPrefixesClientServerOverridable.OnGetNumberForPrinting(ObjectNumber, StandardProcessing,
		DeleteInfobasePrefix, DeleteCustomPrefix);
	
	If StandardProcessing = False Then
		Return ObjectNumber;
	EndIf;
	// {Обработчик: ПриПолученииНомераНаПечать} Окончание
	
	ObjectNumber = TrimAll(ObjectNumber);
	
	// Removing custom prefixes from the object number.
	If DeleteCustomPrefix Then
		
		ObjectNumber = DeleteCustomPrefixesFromObjectNumber(ObjectNumber);
		
	EndIf;
	
	// 
	ObjectNumber = DeleteLeadingZerosFromObjectNumber(ObjectNumber);
	
	// 
	ObjectNumber = DeletePrefixesFromObjectNumber(ObjectNumber, True, DeleteInfobasePrefix);
	
	Return ObjectNumber;
EndFunction

#EndRegion

#Region Private

Function NumberContainsStandardPrefix(Val ObjectNumber)
	
	SeparatorPosition = StrFind(ObjectNumber, "-");
	
	Return (SeparatorPosition = 3 Or SeparatorPosition = 5);
	
EndFunction

Function NumberContainsFiveDigitPrefix(Val ObjectNumber)
	
	Return StrFind(ObjectNumber, "-") = 5;
	
EndFunction

#EndRegion
