///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

#Region ForCallsFromOtherSubsystems

// Returns the current (used by the calling code) message interface version.
//
// Returns:
//   String
//
Function Version() Export
	
	Return "1.0.1.1";
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Returns a namespace of the current (used by the calling code) message interface version.
//
// Returns:
//   String
//
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Control/" + Version();
	
EndFunction

// Returns the name of the message API.
//
// Returns:
//   String
//
Function Public() Export
	
	Return "ApplicationExtensionsControl";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlersArray - Array - common modules or manager modules.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlersArray - Array - common modules or manager modules.
//
Procedure MessagesTranslationHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(MessagesAdditionalReportsAndDataProcessorsControlTranslationHandler_1_0_0_1);
	
EndProcedure

// Returns {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionInstalled message type
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function AdditionalReportOrDataProcessorInstalledMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionInstalled");
	
EndFunction

// Returns {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionDeleted message type
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function AdditionalReportOrDataProcessorDeletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionDeleted");
	
EndFunction

// Returns {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionInstallFailed message type
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function ErrorOfAdditionalReportOrDataProcessorInstallationMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionInstallFailed");
	
EndFunction

// Returns {http://www.1c.ru/1cFresh/ApplicationExtensions/Control/a.b.c.d}ExtensionDeleteFailed message type
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function ErrorOfAdditionalReportOrDataProcessorDeletionMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionDeleteFailed");
	
EndFunction

Function GenerateMessageType(Val PackageToUse, Val Type)
	
	If PackageToUse = Undefined Then
		PackageToUse = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageToUse, Type);
	
EndFunction

#EndRegion
