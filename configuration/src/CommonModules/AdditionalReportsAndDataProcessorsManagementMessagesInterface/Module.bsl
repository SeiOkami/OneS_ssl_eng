///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns a namespace of the current (used by the calling code) message interface version.
//
// Returns:
//   String
//
Function Package() Export
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Management/" + Version();
	
EndFunction

// Returns the current (used by the calling code) message interface version.
//
// Returns:
//   String
//
Function Version() Export
	
	Return "1.0.1.2";
	
EndFunction

// Returns the name of the message API.
//
// Returns:
//   String
//
Function Public() Export
	
	Return "ApplicationExtensionsManagement";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlersArray - Array - common modules or manager modules.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(AdditionalReportsAndDataProcessorsManagementMessagesMessageHandler_1_0_1_1);
	HandlersArray.Add(AdditionalReportsAndDataProcessorsManagementMessagesMessageHandler_1_0_1_2);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//  HandlersArray - Array - common modules or manager modules.
//
Procedure MessagesTranslationHandlers(Val HandlersArray) Export
	
	
	
EndProcedure

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}InstallExtension
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageSetAdditionalReportOrDataProcessor(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "InstallExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}ExtensionCommandSettings
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function AdditionalReportOrDataProcessorCommandSettingType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionCommandSettings");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DeleteExtension
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageDeleteAdditionalReportOrDataProcessor(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DeleteExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DisableExtension
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageDisableAdditionalReportOrDataProcessor(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DisableExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}EnableExtension
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageEnableAdditionalReportOrDataProcessor(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "EnableExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}DropExtension
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageWithdrawAdditionalReportOrDataProcessor(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DropExtension");
	
EndFunction

// Returns message type {http://www.1c.ru/1cFresh/ApplicationExtensions/Management/a.b.c.d}SetExtensionSecurityProfile
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function MessageSetAdditionalReportOrDataProcessorExecutionModeInDataArea(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetExtensionSecurityProfile");
	
EndFunction

#EndRegion

#Region Private

Function GenerateMessageType(Val PackageToUse, Val Type)
	
	If PackageToUse = Undefined Then
		PackageToUse = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageToUse, Type);
	
EndFunction

#EndRegion