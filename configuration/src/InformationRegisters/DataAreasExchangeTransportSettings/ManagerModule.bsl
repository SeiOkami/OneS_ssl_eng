///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates a register record by the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "DataAreasExchangeTransportSettings");
	
EndProcedure

Function TransportSettings(Val CorrespondentEndpoint) Export
	
	QueryText =
	"SELECT
	|	TransportSettings.FILEDataExchangeDirectory AS FILEDataExchangeDirectory,
	|	TransportSettings.FILECompressOutgoingMessageFile AS FILECompressOutgoingMessageFile,
	|	TransportSettings.FTPCompressOutgoingMessageFile AS FTPCompressOutgoingMessageFile,
	|	TransportSettings.FTPConnectionMaxMessageSize AS FTPConnectionMaxMessageSize,
	|	TransportSettings.FTPConnectionPassiveConnection AS FTPConnectionPassiveConnection,
	|	TransportSettings.FTPConnectionUser AS FTPConnectionUser,
	|	TransportSettings.FTPConnectionPort AS FTPConnectionPort,
	|	TransportSettings.FTPConnectionPath AS FTPConnectionPath,
	|	TransportSettings.DefaultExchangeMessagesTransportKind AS DefaultExchangeMessagesTransportKind
	|FROM
	|	InformationRegister.DataAreasExchangeTransportSettings AS TransportSettings
	|WHERE
	|	TransportSettings.CorrespondentEndpoint = &CorrespondentEndpoint";
	
	Query = New Query;
	Query.SetParameter("CorrespondentEndpoint", CorrespondentEndpoint);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Raise StrTemplate(NStr("en = 'Connection settings for the endpoint %1 are not set.';"),
			String(CorrespondentEndpoint));
	EndIf;
	
	Result = DataExchangeInternal.QueryResultToStructure(QueryResult);
	SetPrivilegedMode(True);
	Passwords = Common.ReadDataFromSecureStorage(
		CorrespondentEndpoint, "FTPConnectionDataAreasPassword,ArchivePasswordDataAreaExchangeMessages", True);
	SetPrivilegedMode(False);
	Result.Insert("ArchivePasswordExchangeMessages", Passwords.ArchivePasswordDataAreaExchangeMessages);
	Result.Insert("FTPConnectionPassword", Passwords.FTPConnectionDataAreasPassword);
	
	If Result.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
		
		FTPParameters = DataExchangeServer.FTPServerNameAndPath(Result.FTPConnectionPath);
		
		Result.Insert("FTPServer", FTPParameters.Server);
		Result.Insert("FTPPath",   FTPParameters.Path);
	Else
		Result.Insert("FTPServer", "");
		Result.Insert("FTPPath",   "");
	EndIf;
	
	DataExchangeServer.AddTransactionItemsCountToTransportSettings(Result);
	
	Return Result;
	
EndFunction

Function DefaultExchangeMessagesTransportKind(Peer) Export
	
	MessagesTransportKind = Undefined;
	
	Query = New Query(
	"SELECT
	|	DataAreasTransportSettings.DefaultExchangeMessagesTransportKind AS DefaultExchangeMessagesTransportKind
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaTransportSettings
	|		INNER JOIN InformationRegister.DataAreasExchangeTransportSettings AS DataAreasTransportSettings
	|		ON (DataAreasTransportSettings.CorrespondentEndpoint = DataAreaTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaTransportSettings.Peer = &Peer");
	Query.SetParameter("Peer", Peer);

	Selection = Query.Execute().Select();
	If Selection.Next() Then
		MessagesTransportKind = Selection.DefaultExchangeMessagesTransportKind;
	EndIf;
	
	Return MessagesTransportKind;
	
EndFunction
#EndRegion

#EndIf