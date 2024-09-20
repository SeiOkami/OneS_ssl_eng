///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

// Parameters:
//  Id - String
//  Version - String
//         - Undefined
//  ThePathToTheLayoutToSearchForTheLatestVersion - 
//
// Returns:
//   See AddInsInternal.SavedAddInInformation
//
Function SavedAddInInformation(Id, Version = Undefined, ThePathToTheLayoutToSearchForTheLatestVersion = Undefined) Export
	
	Result = AddInsInternal.SavedAddInInformation(Id, Version, ThePathToTheLayoutToSearchForTheLatestVersion);
	If Result.State = "FoundInStorage" Or Result.State = "FoundInSharedStorage" Then 
		Version = Result.Attributes.Version;
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For the %1 ID (version %2), the %3 add-in (version %4) is received from the catalog.
			|Status: %5';"), 
			Id, ?(Version <> Undefined, Version, NStr("en = 'not specified';")), Result.Attributes.Description, 
			Result.Attributes.Version, Result.State);
		WriteLogEvent(NStr("en = 'Add-ins';", Common.DefaultLanguageCode()),
			EventLogLevel.Information,, Result.Ref, MessageText);
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For the %1 ID (version %2), there is no appropriate add-in in the catalog.
			|Status: %3';"),
			Id, ?(Version <> Undefined, Version, NStr("en = 'not specified';")), Result.State);
		WriteLogEvent(NStr("en = 'Add-ins';", Common.DefaultLanguageCode()),
			EventLogLevel.Information,,, MessageText);
	EndIf;
	Return Result;
	
EndFunction

// 
// 
// Parameters:
//  References References
// 
// Returns:
//  Array of Structure:
//   * Location - String
//   * FileName - String
//
Function AddInsFilesDetails(References) Export
	
	Array = New Array;
	
	ObjectsAttributesValues = Common.ObjectsAttributesValues(References, "FileName, Id");
	For Each KeyAndValue In ObjectsAttributesValues Do
		Structure = New Structure;
		Structure.Insert("Location", GetURL(KeyAndValue.Key, "AddInStorage"));
		FileName = KeyAndValue.Value.FileName;
		If Not ValueIsFilled(FileName) Then
			FileName = KeyAndValue.Value.Id + ".zip";
		EndIf;
		Structure.Insert("Name", FileName);
		Array.Add(Structure);
	EndDo;
	
	Return Array;
	
EndFunction

#EndRegion

