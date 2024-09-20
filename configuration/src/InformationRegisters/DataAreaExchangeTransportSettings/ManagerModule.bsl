///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Function TransportSettings(Val Peer) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Raise NStr("en = 'The manager of exchange message transport settings is not defined.';");
	EndIf;
	
	MessagesExchangeTransportSettingsRegisterName = "MessageExchangeTransportSettings";
	
	QueryText =
	"SELECT
	|	"""" AS FILEDataExchangeDirectory,
	|	"""" AS FTPConnectionPath,
	|	DataAreaTransportSettings.DataExchangeDirectory AS RelativeInformationExchangeDirectory,
	|	DataAreasTransportSettings.FILEDataExchangeDirectory AS FILECommonInformationExchangeDirectory,
	|	DataAreasTransportSettings.FILECompressOutgoingMessageFile,
	|	DataAreasTransportSettings.FTPConnectionPath AS FTPCommonInformationExchangeDirectory,
	|	DataAreasTransportSettings.FTPCompressOutgoingMessageFile,
	|	DataAreasTransportSettings.FTPConnectionMaxMessageSize,
	|	DataAreasTransportSettings.FTPConnectionPassiveConnection,
	|	DataAreasTransportSettings.FTPConnectionUser,
	|	DataAreasTransportSettings.FTPConnectionPort,
	|	DataAreasTransportSettings.DefaultExchangeMessagesTransportKind,
	|	DataAreasTransportSettings.CorrespondentEndpoint,
	|	TransportSettings.WebServiceAddress AS WSWebServiceURL,
	|	TransportSettings.UserName AS WSUserName,
	|	"""" AS WSCorrespondentDataArea,
	|	"""" AS WSCorrespondentEndpoint
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaTransportSettings
	|		LEFT JOIN InformationRegister.DataAreasExchangeTransportSettings AS DataAreasTransportSettings
	|		ON (DataAreasTransportSettings.CorrespondentEndpoint = DataAreaTransportSettings.CorrespondentEndpoint)
	|		LEFT JOIN #TransportSettingsTable AS TransportSettings
	|		ON (TransportSettings.Endpoint = DataAreaTransportSettings.CorrespondentEndpoint)
	|WHERE
	|	DataAreaTransportSettings.Peer = &Peer";
	QueryText = StrReplace(QueryText, "#TransportSettingsTable", "InformationRegister." + MessagesExchangeTransportSettingsRegisterName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Peer", Peer);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Result = DataExchangeInternal.QueryResultToStructure(QueryResult);
	
	SetPrivilegedMode(True);
	Passwords = Common.ReadDataFromSecureStorage(Result.CorrespondentEndpoint,
		"FTPConnectionDataAreasPassword,WSPassword, ArchivePasswordDataAreaExchangeMessages", True);
	SetPrivilegedMode(False);
	
	Result.Insert("WSPassword", Passwords.WSPassword);
	Result.Insert("FTPConnectionPassword", Passwords.FTPConnectionDataAreasPassword);
	Result.Insert("ArchivePasswordExchangeMessages", Passwords.ArchivePasswordDataAreaExchangeMessages);
	
	Result.FILEDataExchangeDirectory = CommonClientServer.GetFullFileName(
		Result.FILECommonInformationExchangeDirectory,
		Result.RelativeInformationExchangeDirectory);
	
	Result.FTPConnectionPath = CommonClientServer.GetFullFileName(
		Result.FTPCommonInformationExchangeDirectory,
		Result.RelativeInformationExchangeDirectory);
	
	Result.Insert("UseTempDirectoryToSendAndReceiveMessages", True);
	
	If Result.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
		
		FTPParameters = DataExchangeServer.FTPServerNameAndPath(Result.FTPConnectionPath);
		
		Result.Insert("FTPServer", FTPParameters.Server);
		Result.Insert("FTPPath",   FTPParameters.Path);
		
	Else
		Result.Insert("FTPServer", "");
		Result.Insert("FTPPath",   "");
	EndIf;
	
	DataExchangeInternal.AddTransactionItemsCountToTransportSettings(Result);
	
	Return Result;
EndFunction

Function TransportSettingsWS(Val Peer) Export
	
	If Not Common.SubsystemExists("CloudTechnology") Then
		Raise NStr("en = 'The manager of exchange message transport settings is not defined.';");
	EndIf;
	
	MessagesExchangeTransportSettingsRegisterName = "MessageExchangeTransportSettings";
	
	Query = New Query(
	"SELECT
	|	DataAreaTransportSettings.CorrespondentEndpoint AS CorrespondentEndpoint
	|FROM
	|	InformationRegister.DataAreaExchangeTransportSettings AS DataAreaTransportSettings
	|WHERE
	|	DataAreaTransportSettings.Peer = &Peer");
	Query.SetParameter("Peer", Peer);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Endpoint = Selection.CorrespondentEndpoint;
	
	TransportSettingManager = Common.ObjectManagerByFullName("InformationRegister."
		+ MessagesExchangeTransportSettingsRegisterName);
	SettingsStructure = TransportSettingManager.TransportSettingsWS(Endpoint);
	
	If Not ValueIsFilled(SettingsStructure.WSWebServiceURL) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Peer infobase ""%1"" connection is not set up.';"),
			String(Peer));
	EndIf;
	
	Return SettingsStructure;
	
EndFunction

// Updates a register record by the passed structure values
//
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "DataAreaExchangeTransportSettings");
	
EndProcedure

#EndRegion

#EndIf
