///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Private

Function DeliveryStatus(MessageID) Export
	
	SendSMSMessage.CheckRights();
	
	If IsBlankString(MessageID) Then
		Return "Pending";
	EndIf;
	
	Result = Undefined;
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SendSMSMessage.SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	ModuleSMSMessageSendingViaProvider = SendSMSMessage.ModuleSMSMessageSendingViaProvider(SMSMessageSendingSettings.Provider);
	If ModuleSMSMessageSendingViaProvider <> Undefined Then
		Result = ModuleSMSMessageSendingViaProvider.DeliveryStatus(MessageID, SMSMessageSendingSettings);
	ElsIf ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		SendSMSMessageOverridable.DeliveryStatus(MessageID, SMSMessageSendingSettings.Provider,
			SMSMessageSendingSettings.Login, SMSMessageSendingSettings.Password, Result);
	Else // 
		Result = "Error";
	EndIf;
	
	Return Result;
	
EndFunction

Function CanSendSMSMessage() Export
	
	Return AccessRight("View", Metadata.CommonForms.SendSMSMessage) And SendSMSMessage.SMSMessageSendingSetupCompleted()
		Or Users.IsFullUser();
	
EndFunction

#EndRegion