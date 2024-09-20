///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Information on add-in by ID and version.
//
// Parameters:
//  Id - String - Add-in identification code.
//  Version - String - Add-in version. 
//
// Returns:
//  Structure:
//      * Exists - Boolean - shows whether the component is absent.
//      * EditingAvailable - Boolean - indicates that the area administrator can change the add-in.
//      * ErrorDescription - String - brief error message.
//      * Id - String - the add-in identification code.
//      * Version - String - Add-in version.
//      * Description - String - component description and short info.
//
// Example:
//
//  Result = AddInServerCall.InformationOnAddIn("InputDevice", "8.1.7.10");
//
//  If Result.Exists Then
//      ID = Result.ID;
//      Version        = Result.Version;
//      Description = Result.Description;
//  Else
//      CommonClientServer.MessageToUser(Result.ErrorDetails);
//  EndIf;
//
Function AddInInformation(Id, Version = Undefined) Export
	
	Result = ResultInformationOnComponent();
	Result.Id = Id;
	
	Information = AddInsInternal.SavedAddInInformation(Id, Version);
	
	If Information.State = "NotFound1" Then
		Result.ErrorDescription = NStr("en = 'The add-in does not exist';");
		Return Result;
	EndIf;
	
	If Information.State = "DisabledByAdministrator" Then
		Result.ErrorDescription = NStr("en = 'Add-in is disabled';");
		Return Result;
	EndIf;
	
	Result.Exists = True;
	Result.EditingAvailable = True;
	
	If Information.State = "FoundInSharedStorage" Then
		Result.EditingAvailable = False;
	EndIf;
	
	Result.Version = Information.Attributes.Version;
	Result.Description = Information.Attributes.Description;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function ResultInformationOnComponent()
	
	Result = New Structure;
	Result.Insert("Exists", False);
	Result.Insert("EditingAvailable", False);
	Result.Insert("Id", "");
	Result.Insert("Version", "");
	Result.Insert("Description", "");
	Result.Insert("ErrorDescription", "");
	
	Return Result;
	
EndFunction

#EndRegion