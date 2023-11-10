///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Returns the version number that the handler is intended to broadcast from.
//
// Returns:
//   String
//
Function SourceVersion() Export
	
	Return "3.0.1.1";
	
EndFunction

// Returns a namespace of the version, from which the translation by handler is used.
//
// Returns:
//   String
//
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage/" + SourceVersion();
	
EndFunction

// Returns the version number that the handler is intended to translate to.
//
// Returns:
//   String
//
Function ResultingVersion() Export
	
	Return "2.1.2.1";
	
EndFunction

// Returns a namespace of the version, to which the translation by handler is used.
//
// Returns:
//   String
//
Function ResultingVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
EndFunction

// Handler for checking the execution of standard translation processing
//
// Parameters:
//  SourceMessage - XDTODataObject - broadcast message,
//  StandardProcessing - Boolean - set
//    this parameter to False within this procedure to cancel standard translation processing.
//    The function is called instead of the standard translation processing
//    MessageTranslation() of the translation handler.
//
Procedure BeforeTranslate(Val SourceMessage, StandardProcessing) Export
	
EndProcedure

// Handler of execution of an arbitrary message translation. It is only called
//  if the StandardProcessing parameter of the BeforeTranslation procedure
//  was set to False.
//
// Parameters:
//  SourceMessage - XDTODataObject - broadcast message.
//
// Returns:
//  XDTODataObject - 
//
Function MessageTranslation(Val SourceMessage) Export
	
EndFunction

#EndRegion




