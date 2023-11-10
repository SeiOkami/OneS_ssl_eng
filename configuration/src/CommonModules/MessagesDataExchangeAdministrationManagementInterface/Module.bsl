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
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage/" + Version();
	
EndFunction

// The current (used by the calling code) message interface version.
//
// Returns:
//   String - 
//
Function Version() Export
	
	Return "3.0.1.1";
	
EndFunction

// The name of the application message interface.
//
// Returns:
//   String - 
//
Function Public() Export
	
	Return "ExchangeAdministrationManage";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(MessagesDataExchangeAdministrationManagementMessageHandler_2_1_2_1);
	HandlersArray.Add(MessagesDataExchangeAdministrationManagementMessageHandler_3_0_1_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesTranslationHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(MessagesDataExchangeAdministrationManagementTranslation_2_1_2_1);
	
EndProcedure

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ConnectCorrespondent message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ConnectCorrespondentMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ConnectCorrespondent");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}SetTransportParams message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function SetTransportSettingsMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetTransportParams");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}GetSyncSettings message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function GetDataSynchronizationSettingsMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GetSyncSettings");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DeleteSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function DeleteSynchronizationSettingMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DeleteSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}EnableSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function EnableSynchronizationMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "EnableSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}DisableSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function DisableSynchronizationMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DisableSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function PushSynchronizationMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "PushSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}PushTwoApplicationSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function PushSynchronizationBetweenTwoApplicationsMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "PushTwoApplicationSync");
	
EndFunction

// Returns {http://www.1c.ru/SaaS/ExchangeAdministration/Manage/a.b.c.d}ExecuteSync message type
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExecuteDataSynchronizationMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "ExecuteSync");
	
EndFunction

// 
//
// Parameters:
//  PackageToUse - String - namespace of the message interface version for which
//    the message type is obtained.
//
// Returns:
//  ТипXDTO
//
Function MessageDisableSyncOverSM(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DisableSyncInSM");
	
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
