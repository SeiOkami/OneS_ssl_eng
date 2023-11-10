///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Peer = CommandParameter;
	SettingID = "";
	
	If DataExchangeWithExternalSystem(Peer, SettingID) Then
		If CommonClient.SubsystemExists("OnlineUserSupport.ОбменДаннымиСВнешнимиСистемами") Then
			
			Context = New Structure;
			Context.Insert("SettingID", SettingID);
			Context.Insert("Peer", Peer);
			Context.Insert("Mode", "EditConnectionParameters");
			
			Cancel = False;
			WizardFormName  = "";
			WizardParameters = New Structure;
			
			ModuleDataExchangeWithExternalSystemsClient = CommonClient.CommonModule("DataExchangeWithExternalSystemsClient");
			ModuleDataExchangeWithExternalSystemsClient.BeforeSettingConnectionSettings(
				Context, Cancel, WizardFormName, WizardParameters);
			
			If Not Cancel Then
				OpenForm(WizardFormName,
					WizardParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	Filter              = New Structure("Peer", Peer);
	FillingValues = New Structure("Peer", Peer);
		
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", CommandExecuteParameters.Source);
	
EndProcedure

&AtServer
Function DataExchangeWithExternalSystem(Peer, SettingID = "")
	
	TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(Peer);
	
	SettingID = DataExchangeServer.SavedExchangePlanNodeSettingOption(Peer);
	
	Return TransportKind = Enums.ExchangeMessagesTransportTypes.ExternalSystem;
	
EndFunction

#EndRegion
