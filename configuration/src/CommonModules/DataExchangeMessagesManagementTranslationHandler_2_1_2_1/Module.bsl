///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Version number, from which the translation by handler is used.
//
// Returns:
//   String - 
//
Function SourceVersion() Export
	
	Return "3.0.1.1";
	
EndFunction

// Namespace of the version, from which the translation by handler is used.
//
// Returns:
//   String - name space.
//
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage/3.0.1.1";
	
EndFunction

// Version number, to which the translation by handler is used.
//
// Returns:
//   String - 
//
Function ResultingVersion() Export
	
	Return "2.1.2.1";
	
EndFunction

// Namespace of the version, to which the translation by handler is used.
//
// Returns:
//   String - name space.
//
Function ResultingVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/Exchange/Manage";
	
EndFunction

// Handler of standard translation processing execution check.
//
// Parameters:
//   SourceMessage    - XDTODataObject - a message being translated.
//   StandardProcessing - Boolean - set
//                          this parameter to False within this procedure to cancel standard translation processing.
//                          The function is called instead of the standard translation processing
//                          MessageTranslation() of the translation handler.
//
Procedure BeforeTranslate(Val SourceMessage, StandardProcessing) Export
	
	BodyType = SourceMessage.Type();
	
	If BodyType = Interface().SetUpExchangeStep1Message(SourceVersionPackage()) Then
		StandardProcessing = False;
	ElsIf BodyType = Interface().ImportExchangeMessageMessage(SourceVersionPackage()) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Handler of execution of an arbitrary message translation. It is only called
// if the StandardProcessing parameter of the BeforeTranslation procedure
// was set to False.
//
// Parameters:
//   SourceMessage - XDTODataObject - a message being translated.
//
// Returns:
//   XDTODataObject - 
//
Function MessageTranslation(Val SourceMessage) Export
	
	BodyType = SourceMessage.Type();
	
	If BodyType = Interface().SetUpExchangeStep1Message(SourceVersionPackage()) Then
		Return TranslateMessageConfigureExchangeStep1(SourceMessage);
	ElsIf BodyType = Interface().ImportExchangeMessageMessage(SourceVersionPackage()) Then
		Return TranslateMessageImportExchangeMessage(SourceMessage);
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function Interface()
	
	Return DataExchangeMessagesManagementInterface;
	
EndFunction

Function TranslateMessageConfigureExchangeStep1(Val SourceMessage)
	
	Result = XDTOFactory.Create(
		Interface().SetUpExchangeStep1Message(ResultingVersionPackage()));
		
	Result.SessionId = SourceMessage.SessionId;
	Result.Zone      = SourceMessage.Zone;
	
	Result.CorrespondentZone = SourceMessage.CorrespondentZone;
	
	Result.ExchangePlan = SourceMessage.ExchangePlan;
	Result.CorrespondentCode = SourceMessage.CorrespondentCode;
	Result.CorrespondentName = SourceMessage.CorrespondentName;
	Result.Code = SourceMessage.Code;
	Result.EndPoint = SourceMessage.EndPoint;
	
	If SourceMessage.IsSet("XDTOSettings") Then
		XDTOSettings = XDTOSerializer.ReadXDTO(SourceMessage.XDTOSettings);
		
		FiltersSettings = New Structure;
		FiltersSettings.Insert("XDTOCorrespondentSettings", XDTOSettings);
		
		Result.FilterSettings = XDTOSerializer.WriteXDTO(FiltersSettings);
	Else
		Result.FilterSettings = XDTOSerializer.WriteXDTO(New Structure);
	EndIf;
	
	Return Result;
	
EndFunction

Function TranslateMessageImportExchangeMessage(Val SourceMessage)
	
	Result = XDTOFactory.Create(
		Interface().ImportExchangeMessageMessage(ResultingVersionPackage()));
		
	Result.SessionId = SourceMessage.SessionId;
	Result.Zone      = SourceMessage.Zone;
	
	Result.CorrespondentZone = SourceMessage.CorrespondentZone;
	
	Result.ExchangePlan = SourceMessage.ExchangePlan;
	Result.CorrespondentCode = SourceMessage.CorrespondentCode;
	
	Return Result;
	
EndFunction

#EndRegion
