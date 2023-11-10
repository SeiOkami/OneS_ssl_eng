///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Namespace of the current (used by the calling code) message interface version.
//
// Returns:
//   String - name space.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Control";
	
EndFunction

// The current (used by the calling code) message interface version.
//
// Returns:
//   String - 
//
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// The name of the application message interface.
//
// Returns:
//   String - 
//
Function Public() Export
	
	Return "ExchangeAdministrationControl";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(MessagesDataExchangeAdministrationControlMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesTranslationHandlers(Val HandlersArray) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentConnectionCompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "CorrespondentConnectionCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}CorrespondentConnectionFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentConnectionErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "CorrespondentConnectionFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function DataSynchronizationSettingsReceivedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingSyncSettingsCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}GettingSyncSettingsFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function DataSynchronizationSettingsReceivingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingSyncSettingsFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SynchronizationEnabledSuccessfullyMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "EnableSyncCompleted");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncCompleted message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SynchronizationDisabledMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DisableSyncCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}EnableSyncFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SynchronizationEnablingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "EnableSyncFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}DisableSyncFailed message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SynchronizationDisablingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DisableSyncFailed");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Control/a.b.c.d}SyncCompleted message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SynchronizationDoneMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SyncCompleted");
	
EndFunction

#EndRegion

#Region Private

// For internal use
//
Function GenerateMessageType(Val PackageToUse, Val Type)
	
	If PackageToUse = Undefined Then
		PackageToUse = Package();
	EndIf;
	
	Return XDTOFactory.Type(PackageToUse, Type);
	
EndFunction

#EndRegion
