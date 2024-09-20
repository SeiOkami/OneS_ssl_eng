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

// Returns the current (used by the calling code) message interface version
//
// Returns:
//   String
//
Function Version() Export
	
	Return "1.0.0.2";
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Returns a namespace of the current (used by the calling code) message interface version.
//
// Parameters:
//   Version - String - if the parameter is specified, the specified version is included in the namespace instead of the current one.
//
// Returns:
//   String
//
Function Package(Val Version = "") Export
	
	If IsBlankString(Version) Then
		Version = Version();
	EndIf;
	
	Return "http://www.1c.ru/1cFresh/ApplicationExtensions/Manifest/" + Version;
	
EndFunction

// Returns a name of the message API
//
// Returns:
//   String
//
Function Public() Export
	
	Return "ApplicationExtensionsCore";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//  HandlersArray - Array - common modules or manager modules.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
EndProcedure

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionAssignmentObject
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTODataObject
//
Function TypeRelatedObject(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionAssignmentObject");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionSubsystemsAssignment
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function AssignmentToSectionsType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionSubsystemsAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCatalogsAndDocumentsAssignment
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function AssignmentToCatalogsAndDocumentsType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionCatalogsAndDocumentsAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCommand
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function CommandType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionCommand");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionReportVariantAssignment
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function ReportOptionAssignmentType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionReportVariantAssignment");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionReportVariant
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function ReportOptionType1(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionReportVariant");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCommandSettings
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function CommandSettingsType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionCommandSettings");
	
EndFunction

// Returns type {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionManifest
//
// Parameters:
//  PackageToUse - String - a namespace of the message interface version, for which
//    the message type is being received.
//
// Returns:
//  XDTOObjectType
//
Function ManifestType(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExtensionManifest");
	
EndFunction

// Returns dictionary of mapping enumeration values AdditionalReportsAndDataProcessorsKinds
// of the XDTO type value {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionCategory
//
// Returns:
//  Structure
//
Function AdditionalReportsAndDataProcessorsKindsDictionary() Export
	
	Dictionary = New Structure();
	Manager = Enums.AdditionalReportsAndDataProcessorsKinds;
	
	Dictionary.Insert("AdditionalProcessor", Manager.AdditionalDataProcessor);
	Dictionary.Insert("AdditionalReport", Manager.AdditionalReport);
	Dictionary.Insert("ObjectFilling", Manager.ObjectFilling);
	Dictionary.Insert("Report", Manager.Report);
	Dictionary.Insert("PrintedForm", Manager.PrintForm);
	Dictionary.Insert("LinkedObjectCreation", Manager.RelatedObjectsCreation);
	Dictionary.Insert("TemplatesMessages", Manager.MessageTemplate);
	
	Return Dictionary;
	
EndFunction

// Returns dictionary of mapping enumeration values AdditionalDataProcessorsCallMethods
// of the XDTO type value {http://www.1c.ru/1cFresh/ApplicationExtensions/Core/a.b.c.d}ExtensionStartupType
//
// Returns:
//  Structure
//
Function AdditionalReportsAndDataProcessorsCallMethodsDictionary() Export
	
	Dictionary = New Structure();
	Manager = Enums.AdditionalDataProcessorsCallMethods;
	
	Dictionary.Insert("ClientCall", Manager.ClientMethodCall);
	Dictionary.Insert("ServerCall", Manager.ServerMethodCall);
	Dictionary.Insert("FormOpen", Manager.OpeningForm);
	Dictionary.Insert("FormFill", Manager.FillingForm);
	Dictionary.Insert("SafeModeExtension", Manager.SafeModeScenario);
	
	Return Dictionary;
	
EndFunction

Function GenerateMessageType(Val PackageToUse, Val Type)
		
	If PackageToUse = Undefined Then
		PackageToUse = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageToUse, Type);
	
EndFunction

#EndRegion