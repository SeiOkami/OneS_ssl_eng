///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Namespace of message interface version.
//
// Returns:
//   String - name space.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ExchangeAdministration/Manage";
	
EndFunction

// Message interface version supported by the handler.
//
// Returns:
//   String - 
//
Function Version() Export
	
	Return "2.1.2.1";
	
EndFunction

// Base type for version messages.
//
// Returns:
//   XDTOObjectType - 
//
Function BaseType() Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Raise NStr("en = 'There is no Service manager.';");
	EndIf;
	
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	Return ModuleMessagesSaaS.TypeBody();
	
EndFunction

// Processing incoming SaaS messages
//
// Parameters:
//   Message   - XDTODataObject - an incoming message.
//   Sender - ExchangePlanRef.MessagesExchange - exchange plan node that matches the message sender.
//   MessageProcessed - Boolean - indicates whether the message is successfully processed. The parameter value must be
//                         set to True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesDataExchangeAdministrationManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.ConnectCorrespondentMessage(Package()) Then
		ConnectCorrespondent(Message, Sender);
	ElsIf MessageType = Dictionary.SetTransportSettingsMessage(Package()) Then
		SetTransportSettings(Message, Sender);
	ElsIf MessageType = Dictionary.DeleteSynchronizationSettingMessage(Package()) Then
		DeleteSynchronizationSetting(Message, Sender);
	ElsIf MessageType = Dictionary.ExecuteDataSynchronizationMessage(Package()) Then
		RunSync(Message, Sender);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ConnectCorrespondent(Message, Sender)
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Return;
	EndIf;
	
	MessageExchangePlanName     = "MessagesExchange";
	ModuleMessagesExchange        = Common.CommonModule("MessagesExchange");
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	MessageExchangePlanManager = Common.ObjectManagerByFullName("ExchangePlan."
		+ MessageExchangePlanName);
	
	ThisMessageExchangeNode = MessageExchangePlanManager.ThisNode();
	
	Body = Message.Body;
	
	// Checking the endpoint.
	IsEndpoint = DataExchangeSaaS.EndpointsExchangePlanManager().FindByCode(Body.SenderId);
	
	If IsEndpoint.IsEmpty()
		Or IsEndpoint <> ThisMessageExchangeNode Then
		
		// Sending an error message to the service manager.
		ErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Endpoint does not match the expected one. Expected endpoint code %1. Current endpoint code %2. ';"),
			Body.SenderId,
			Common.ObjectAttributeValue(ThisMessageExchangeNode, "Code"));
			
		SendAResponseMessageAboutAConnectionError(Message, Sender, ErrorPresentation);	
		Return;
		
	EndIf;
	
	// Checking whether correspondent is connected.
	Peer = DataExchangeSaaS.EndpointsExchangePlanManager().FindByCode(Body.RecipientId);
	
	If Peer.IsEmpty() Then // 
		
		Cancel = False;
		ConnectedCorrespondent = Undefined;
		
		SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
		SenderConnectionSettings.WSWebServiceURL = Body.RecipientURL;
		SenderConnectionSettings.WSUserName = Body.RecipientUser;
		SenderConnectionSettings.WSPassword = Body.RecipientPassword;
		
		RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
		RecipientConnectionSettings.WSWebServiceURL = Body.SenderURL;
		RecipientConnectionSettings.WSUserName = Body.SenderUser;
		RecipientConnectionSettings.WSPassword = Body.SenderPassword;
		
		ModuleMessagesExchange.ConnectEndpoint(
									Cancel,
									SenderConnectionSettings,
									RecipientConnectionSettings,
									ConnectedCorrespondent,
									Body.RecipientName,
									Body.SenderName);
		
		If Cancel Then // 
			
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Peer infobase endpoint connection error. Endpoint ID: %1.';"),
				Body.RecipientId);
				
			SendAResponseMessageAboutAConnectionError(Message, Sender, ErrorPresentation);	
			Return;
			
		EndIf;
		
		ConnectedCorrespondentCode = Common.ObjectAttributeValue(ConnectedCorrespondent, "Code");
		
		If ConnectedCorrespondentCode <> Body.RecipientId Then
			
			// 
			// 
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Peer infobase endpoint connection error.
				|Unexpected endpoint ID.
				|Expected ID: %1.
				|Actual ID: %2.';"),
				Body.RecipientId,
				ConnectedCorrespondentCode);
			
			SendAResponseMessageAboutAConnectionError(Message, Sender, ErrorPresentation);	
			Return;
			
		EndIf;
		
		BeginTransaction();
		Try
		    Block = New DataLock;
		    LockItem = Block.Add(Common.TableNameByRef(ConnectedCorrespondent));
		    LockItem.SetValue("Ref", ConnectedCorrespondent);
		    Block.Lock();
		    
			LockDataForEdit(ConnectedCorrespondent);
			CorrespondentObject = ConnectedCorrespondent.GetObject(); // ExchangePlanObject.MessagesExchange
			
			CorrespondentObject.Locked = True;

		    CorrespondentObject.Write();

		    CommitTransaction();
		Except
		    RollbackTransaction();
		    Raise;
		EndTry;
		
	Else // 
		
		Cancel = False;
		
		SenderConnectionSettings = DataExchangeServer.WSParameterStructure();
		SenderConnectionSettings.WSWebServiceURL = Body.RecipientURL;
		SenderConnectionSettings.WSUserName = Body.RecipientUser;
		SenderConnectionSettings.WSPassword = Body.RecipientPassword;
		
		RecipientConnectionSettings = DataExchangeServer.WSParameterStructure();
		RecipientConnectionSettings.WSWebServiceURL = Body.SenderURL;
		RecipientConnectionSettings.WSUserName = Body.SenderUser;
		RecipientConnectionSettings.WSPassword = Body.SenderPassword;
		
		ModuleMessagesExchange.UpdateEndpointConnectionSettings(
									Cancel,
									Peer,
									SenderConnectionSettings,
									RecipientConnectionSettings);
		
		If Cancel Then // 
			
			ErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Endpoint connection failed.
				|This infobase endpoint ID: %1.
				|The peer infobase endpoint ID: %2.';"),
				Common.ObjectAttributeValue(ThisMessageExchangeNode, "Code"),
				Body.RecipientId);
				
			SendAResponseMessageAboutAConnectionError(Message, Sender, ErrorPresentation);	
			Return;
			
		EndIf;
		
		CorrespondentObject = Peer.GetObject();
		CorrespondentObject.Locked = True;
		CorrespondentObject.Write();
		
	EndIf;
	
	// Sending a message to the service manager about successful operation completion.
	BeginTransaction();
	Try
		ResponseMessage = ModuleMessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionCompletedMessage());
		ResponseMessage.Body.RecipientId = Body.RecipientId;
		ResponseMessage.Body.SenderId    = Body.SenderId;
		ModuleMessagesSaaS.SendMessage(ResponseMessage, Sender);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure SetTransportSettings(Message, Sender)
	
	Body = Message.Body;
	
	Peer = DataExchangeSaaS.EndpointsExchangePlanManager().FindByCode(Body.RecipientId);
	
	If Peer.IsEmpty() Then
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Endpoint with ID %1 is not found.';"),
			Body.RecipientId);
		Raise MessageString;
	EndIf;
	
	DataExchangeServer.SetDataImportTransactionItemsCount(Body.ImportTransactionQuantity);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("CorrespondentEndpoint", Peer);
	
	RecordStructure.Insert("FILEDataExchangeDirectory",       Body.FILE_ExchangeFolder);
	RecordStructure.Insert("FILECompressOutgoingMessageFile", Body.FILE_CompressExchangeMessage);
	
	RecordStructure.Insert("FTPCompressOutgoingMessageFile",                  Body.FTP_CompressExchangeMessage);
	RecordStructure.Insert("FTPConnectionMaxMessageSize", Body.FTP_MaxExchangeMessageSize);
	RecordStructure.Insert("FTPConnectionPassiveConnection",                   Body.FTP_PassiveMode);
	RecordStructure.Insert("FTPConnectionUser",                          Body.FTP_User);
	RecordStructure.Insert("FTPConnectionPort",                                  Body.FTP_Port);
	RecordStructure.Insert("FTPConnectionPath",                                  Body.FTP_ExchangeFolder);
	
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind",      Enums.ExchangeMessagesTransportTypes[Body.ExchangeTransport]);
	
	
	SetPrivilegedMode(True);
	Common.WriteDataToSecureStorage(Peer, Body.FTP_Password, "FTPConnectionDataAreasPassword");
	Common.WriteDataToSecureStorage(Peer, Body.ExchangeMessagePassword, "ArchivePasswordDataAreaExchangeMessages");
	SetPrivilegedMode(False);
	
	InformationRegisters.DataAreasExchangeTransportSettings.UpdateRecord(RecordStructure);
	
EndProcedure

Procedure DeleteSynchronizationSetting(Message, Sender)
	
	Body = Message.Body;
	DataExchangeSaaS.DeleteSynchronizationSetting(Body.ExchangePlan, Format(Body.CorrespondentZone, "ND=7; NLZ=; NG=0"));
	
EndProcedure

Procedure RunSync(Message, Sender)
	
	DataExchangeScenario = XDTOSerializer.ReadXDTO(Message.Body.Scenario);
	
	DataExchangeSaaS.ExecuteDataExchange(DataExchangeScenario);
	
EndProcedure

Function EventLogEventCorrespondentConnection()
	
	Return NStr("en = 'Data exchange.Peer infobase connection';", Common.DefaultLanguageCode());
	
EndFunction

Procedure SendAResponseMessageAboutAConnectionError(Message, Sender, ErrorPresentation)
	
	AttemptNumber = Undefined;
	If Message.IsSet("AdditionalInfo") Then
		AdditionalProperties = XDTOSerializer.ReadXDTO(Message.AdditionalInfo);
		AdditionalProperties.Property("AttemptNumber", AttemptNumber);
	EndIf;
	
	WriteLogEvent(EventLogEventCorrespondentConnection(),
		EventLogLevel.Error,,, ErrorPresentation);
	
	ModuleMessagesSaaS = Common.CommonModule("MessagesSaaS");
	
	ResponseMessage = ModuleMessagesSaaS.NewMessage(
		MessagesDataExchangeAdministrationControlInterface.CorrespondentConnectionErrorMessage());
		
	AdditionalProperties = New Structure;
	AdditionalProperties.Insert("AttemptNumber", AttemptNumber);
	ResponseMessage.AdditionalInfo = XDTOSerializer.WriteXDTO(AdditionalProperties);
	ResponseMessage.Body.RecipientId      = Message.Body.RecipientId;
	ResponseMessage.Body.SenderId         = Message.Body.SenderId;
	ResponseMessage.Body.ErrorDescription = ErrorPresentation;
	
	BeginTransaction();
	Try
		ModuleMessagesSaaS.SendMessage(ResponseMessage, Sender);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
