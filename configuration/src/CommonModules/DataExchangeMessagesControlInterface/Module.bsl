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
	
	Return "http://www.1c.ru/SaaS/Exchange/Control";
	
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
	
	Return "ExchangeControl";
	
EndFunction

// Registers message handlers as message exchange channel handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesChannelsHandlers(Val HandlersArray) Export
	
	HandlersArray.Add(DataExchangeMessagesControlMessageHandler_2_1_2_1);
	
EndProcedure

// Registers message translation handlers.
//
// Parameters:
//   HandlersArray - Array of CommonModule - a collection of modules containing handlers.
//
Procedure MessagesTranslationHandlers(Val HandlersArray) Export
	
EndProcedure

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Completed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeSetupStep1CompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetupExchangeStep1Completed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Completed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeSetupStep2CompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetupExchangeStep2Completed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep1Failed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeSetupErrorStep1Message(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetupExchangeStep1Failed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}SetupExchangeStep2Failed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeSetupErrorStep2Message(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "SetupExchangeStep2Failed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}DownloadMessageCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeMessageImportCompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DownloadMessageCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}DownloadMessageFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function ExchangeMessageImportErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "DownloadMessageFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentDataGettingCompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingDataCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function GettingCommonDataOfCorrespondentNodeCompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingCommonNodsDataCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingDataFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentDataGettingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingDataFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCommonNodsDataFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentNodeCommonDataGettingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingCommonNodsDataFailed");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsCompleted
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function GettingCorrespondentAccountingParametersCompletedMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingCorrespondentParamsCompleted");
	
EndFunction

// Returns message type {http://www.1c.ru/SaaS/Exchange/Control/a.b.c.d}GettingCorrespondentParamsFailed
//
// Parameters:
//   PackageToUse - String - a namespace of the message interface version, for which
//                                the message type is being received.
//
// Returns:
//   XDTOObjectType - 
//
Function CorrespondentAccountingParametersGettingErrorMessage(Val PackageToUse = Undefined) Export
	
	Return GenerateMessageType(PackageToUse, "GettingCorrespondentParamsFailed");
	
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
